"""DRAFT. Explicit read-only Git plan, then explicit isolated materialization.

No Godot execution, source mutation, Git writes, junctions, hardlinks or deletion.
Default inventory only reads workspace sizes; it does NOT claim a Git snapshot.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

sys.dont_write_bytecode = True
from transforms import PINS, driver, instrument, normalized, require, sha

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REF = '4baafc1'
ROOTS = ('scripts', 'scenes', 'assets', 'shaders', 'resources', 'data', 'addons', 'content', 'scenarios')
TOOLS = ('tools/polish_performance_probe.gd', 'tools/zhujiazhuang_rts_test.gd')
# Explicitly reviewed provenance-only boundary in 4baafc1; never infer from live markers.
IGNORE_MARKERS = {'assets/campaign/source/.gdignore': '9e8e5ec4e9a53531c71fdc65feb2f05b2f7b929d'}
EXCLUDED = ['.git/**', 'docs/**', 'qa/**', 'scratchpad/**', 'build/**', 'exports/**',
            'untracked production files', 'all normal user profiles', 'godot.local.txt',
            '.godot/editor/**', '.godot/shader_cache/**', '.godot/uid_cache.bin',
            'unreferenced .godot/imported/**', 'tools except the two inherited M1 scripts']


def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))


def relative_safe(name):
    p = PurePosixPath(name)
    require(not p.is_absolute() and '..' not in p.parts and '\\' not in name and ':' not in name,
            'Unsafe relative path: ' + name)
    return p


def regular(path, root):
    root = root.resolve()
    require(path.resolve().is_relative_to(root), 'Path escaped read root: ' + str(path))
    cursor = path
    while cursor != root:
        require(not cursor.is_symlink() and not (cursor.exists() and getattr(cursor.stat(), 'st_file_attributes', 0) & 0x400),
                'Symlink/reparse point rejected: ' + str(cursor))
        cursor = cursor.parent
    require(path.is_file(), 'Required regular file missing: ' + str(path))


def selected(path):
    return path == 'project.godot' or path in TOOLS or path.split('/')[0] in ROOTS or ('/' not in path and path.startswith('icon.'))


def git(*args):
    # Future explicit plan/materialize modes only; no fetch/checkout/index writes.
    return subprocess.check_output(['git', '-c', 'core.quotepath=false', *args], cwd=ROOT)


def blob(raw):
    return hashlib.sha1(('blob %d\0' % len(raw)).encode() + raw).hexdigest()


def verify_class_entry(entry, path, raw):
    """Only accept the simple top-level declarations used by this frozen project."""
    source = normalized(raw).decode('utf-8-sig')
    declared = re.findall(r'^class_name[ \t]+([A-Za-z_]\w*)[ \t]*(?:#.*)?$', source, re.M)
    bases = re.findall(r'^extends[ \t]+([A-Za-z_]\w*)[ \t]*(?:#.*)?$', source, re.M)
    require(len(declared) == 1, 'Missing/unsupported frozen class declaration: ' + path)
    require(len(bases) <= 1 and (bases or not re.search(r'^extends\b', source, re.M)),
            'Unsupported frozen class base: ' + path)
    base = bases[0] if bases else 'RefCounted'
    for field, expected in (('class', declared[0]), ('base', base)):
        found = re.findall(r'"' + field + r'":\s*&?"([^"]+)"', entry)
        require(found == [expected], 'Class cache ' + field + ' differs from frozen declaration: ' + path)
    return {'path': path, 'class': declared[0], 'base': base, 'source_blob_oid': blob(raw)}


def source_digests(path, size):
    regular(path, ROOT)
    require(path.stat().st_size == size, 'Cache source size differs from snapshot: ' + str(path))
    git_sha = hashlib.sha1(('blob %d\0' % size).encode())
    md5 = hashlib.md5()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            git_sha.update(chunk)
            md5.update(chunk)
    return git_sha.hexdigest(), md5.hexdigest()


def ignored_by(name, markers):
    path = relative_safe(name)
    for marker in sorted(markers, key=lambda value: len(PurePosixPath(value).parts)):
        if PurePosixPath(marker).parent in path.parents:
            return marker
    return None


def frozen_ignore_markers(rows):
    found = {name for name in rows if PurePosixPath(name).name == '.gdignore'}
    require(found == set(IGNORE_MARKERS), 'Frozen ignore-marker boundary changed; explicit review required')
    result = {}
    for name, expected in IGNORE_MARKERS.items():
        require(rows[name]['blob_oid'] == expected, 'Frozen ignore-marker blob drift: ' + name)
        raw = git('cat-file', 'blob', expected)
        require(blob(raw) == expected, 'Frozen ignore-marker content mismatch: ' + name)
        local = ROOT / name; regular(local, ROOT)
        live_raw = local.read_bytes()
        require(normalized(live_raw) == normalized(raw), 'Live ignore-marker content differs from frozen source after LF normalization: ' + name)
        result[name] = {'path': name, 'blob_oid': expected, 'raw_sha256': sha(raw), 'bytes': len(raw),
                        'lf_sha256': sha(normalized(raw)), 'live_raw_sha256': sha(live_raw),
                        'live_lf_sha256': sha(normalized(live_raw)), 'live_bytes': len(live_raw),
                        'line_endings_only_difference': live_raw != raw, 'text_comparison': 'CRLF to LF only; contents and exact frozen Git blob remain pinned',
                        'reason': 'Godot 4.6 skips this directory and descendants at import scan; provenance source files remain copied.'}
    return result


def reject_ignored_reference(path, text, markers):
    for marker in markers:
        prefix = PurePosixPath(marker).parent.as_posix()
        pattern = re.escape(prefix) + r'''(?=/|["']|$)'''
        require(re.search(pattern, text) is None, 'Runtime text refers to ignored source directory; review required: ' + path + ' -> ' + prefix)


def inventory():
    """Metadata-only preview now; authoritative plan must later read pinned Git."""
    rows = []
    for directory in ROOTS:
        if not (ROOT / directory).exists(): continue
        for path in sorted((ROOT / directory).rglob('*')):
            if path.is_file():
                regular(path, ROOT)
                rows.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size})
    for name in ('project.godot', *TOOLS):
        path = ROOT / name
        regular(path, ROOT)
        rows.append({'path': name, 'bytes': path.stat().st_size})
    caches = []
    base = ROOT / '.godot/imported'
    if base.exists():
        for path in sorted(base.iterdir()):
            if path.is_file():
                regular(path, ROOT)
                caches.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size})
    result = {'schema': 1, 'status': 'WORKSPACE_SIZE_PREVIEW_NOT_GIT_PROVENANCE',
              'intended_snapshot': REF, 'git_executed': False, 'godot_executed': False,
              'bulk_copied': False, 'source_rows': rows, 'source_bytes_upper_bound': sum(x['bytes'] for x in rows),
              'import_cache_rows_upper_bound': caches, 'import_cache_bytes_upper_bound': sum(x['bytes'] for x in caches),
              'exclusions': EXCLUDED,
              'next': 'Explicit plan reads Git tree/blob IDs and selects only validated referenced import artifacts before any materialization.'}
    save(HERE / 'inventory_preview.json', result)
    return result


def plan():
    commit = git('rev-parse', REF + '^{commit}').decode().strip()
    require(re.fullmatch(r'[0-9a-f]{40}', commit) and commit.startswith(REF), 'Unexpected snapshot')
    rows = {}
    for line in git('ls-tree', '-r', '-l', '-z', '--full-tree', commit).split(b'\0'):
        if not line: continue
        info, raw_path = line.split(b'\t', 1)
        path = raw_path.decode('utf-8')
        if not selected(path): continue
        relative_safe(path)
        mode, kind, oid, size = info.decode().split()
        require(mode in ('100644', '100755') and kind == 'blob', 'Non-regular snapshot member: ' + path)
        rows[path] = {'path': path, 'blob_oid': oid, 'bytes': int(size), 'mode': mode}
    require(all(name in rows for name in ('project.godot', *TOOLS, *PINS)), 'Missing pinned sources')
    for name, expected in PINS.items():
        raw = git('cat-file', 'blob', rows[name]['blob_oid'])
        require(sha(normalized(raw)) == expected, 'Snapshot method/source pin mismatch: ' + name)
    ignored_markers = frozen_ignore_markers(rows)
    ignored_files = [dict(row, ignored_by=ignored_by(name, ignored_markers),
                         ignored_import_reason='Frozen .gdignore covers this provenance path; retain source blob, require no importer artifact.')
                     for name, row in rows.items() if ignored_by(name, ignored_markers)]
    audited = []
    for path, row in rows.items():
        if ignored_by(path, ignored_markers): continue
        if not (path == 'project.godot' or path.endswith(('.gd', '.tscn', '.tres', '.gdshader'))): continue
        text = git('cat-file', 'blob', row['blob_oid']).decode('utf-8-sig')
        reject_ignored_reference(path, text, ignored_markers)
        audited.append(path)
    cache_rows = {}
    imports = []
    ignored_imports = []
    needs_reimport = []
    # Only remaps present in the Git snapshot are accepted. No invented imports.
    for path, row in rows.items():
        if not path.endswith('.import'): continue
        remap = git('cat-file', 'blob', row['blob_oid']).decode('utf-8-sig')
        source_match = re.search(r'^source_file="res://([^"\r\n]+)"', remap, re.M)
        destinations = sorted(set(re.findall(r'"res://(\.godot/imported/[^"\r\n]+)"', remap)))
        require(source_match is not None and destinations, 'Incomplete import remap: ' + path)
        source = source_match.group(1)
        require(source in rows, 'Import source absent from Git snapshot: ' + source)
        marker = ignored_by(path, ignored_markers)
        require(marker == ignored_by(source, ignored_markers), 'Import remap crosses frozen ignored boundary: ' + path)
        if marker is not None:
            ignored_imports.append({'remap': path, 'remap_blob_oid': row['blob_oid'], 'source': source,
                                    'source_blob_oid': rows[source]['blob_oid'], 'ignored_by': marker,
                                    'destinations_not_copied': destinations,
                                    'reason': 'Frozen ignored provenance subtree; source/remap retained, importer outputs not required.'})
            continue
        reasons = []
        source_path = ROOT / source
        live_source = {'present': source_path.exists()}
        if source_path.exists():
            regular(source_path, ROOT)
            live_size = source_path.stat().st_size
            source_oid, source_md5 = source_digests(source_path, live_size)
            live_source.update(bytes=live_size, blob_oid=source_oid, md5=source_md5)
            source_matches = live_size == rows[source]['bytes'] and source_oid == rows[source]['blob_oid']
        else:
            source_matches = False
        if not source_matches: reasons.append('live_source_bytes_differ_or_missing')
        frozen_raw = git('cat-file', 'blob', rows[source]['blob_oid']) if not source_matches else None
        expected_md5 = hashlib.md5(frozen_raw).hexdigest() if frozen_raw is not None else source_md5
        # Options and each artifact must agree before any existing cache is copied.
        live_remap = ROOT / path
        regular(live_remap, ROOT)
        live_remap_raw = live_remap.read_bytes()
        if normalized(live_remap_raw) != normalized(remap.encode('utf-8')): reasons.append('live_import_options_differ')
        md5_paths = sorted(set(re.sub(r'(-[0-9a-f]{32})\..+$', r'\1.md5', x) for x in destinations))
        require(all(name.endswith('.md5') for name in md5_paths), 'Unknown imported MD5 sidecar naming')
        cache_evidence = {}
        for name in md5_paths:
            relative_safe(name)
            local = ROOT / name
            if not local.exists():
                reasons.append('missing_source_md5_sidecar:' + name)
                continue
            regular(local, ROOT)
            md5_text = local.read_text(encoding='utf-8-sig')
            match = re.search(r'^source_md5="([0-9a-f]{32})"', md5_text, re.M)
            cache_evidence[name] = {'source_md5': match.group(1) if match else None}
            if match is None or match.group(1) != expected_md5: reasons.append('cache_source_md5_differs_from_frozen:' + name)
        resource_cache_rows = {}
        for name in destinations + md5_paths:
            relative_safe(name)
            require(name.startswith('.godot/imported/'), 'Unexpected imported destination')
            local = ROOT / name
            if not local.exists():
                cache_evidence.setdefault(name, {})['present'] = False
                reasons.append('missing_import_artifact:' + name)
                continue
            regular(local, ROOT)
            raw = local.read_bytes()
            cache_evidence.setdefault(name, {}).update(present=True, bytes=len(raw), sha256=sha(raw))
            resource_cache_rows[name] = {'path': name, 'bytes': len(raw), 'sha256': sha(raw)}
        association = {'remap': path, 'source': source, 'source_blob_oid': rows[source]['blob_oid'],
                       'source_md5': expected_md5, 'destinations': destinations, 'md5_sidecars': md5_paths}
        if reasons:
            if frozen_raw is None: frozen_raw = git('cat-file', 'blob', rows[source]['blob_oid'])
            require(blob(frozen_raw) == rows[source]['blob_oid'], 'Reimport source is not the frozen blob: ' + source)
            if source_path.exists(): live_source['sha256'] = sha(source_path.read_bytes())
            association.update(status='needs_reimport', reasons=sorted(set(reasons)),
                expected={'bytes':len(frozen_raw),'blob_oid':rows[source]['blob_oid'],'sha256':sha(frozen_raw),'md5':expected_md5},
                live=live_source, live_remap_sha256=sha(live_remap_raw), cache=cache_evidence,
                old_cache_copied=False, next='Bounded exclusive headless import in private mirror, then freeze/validate generated cache before diagnostic')
            needs_reimport.append(association)
        else:
            cache_rows.update(resource_cache_rows)
            association['status'] = 'existing_cache_source_verified'
        imports.append(association)
    # Fonts/textures without committed remaps require an explicit reviewed plan revision.
    importable = ('.png', '.jpg', '.jpeg', '.webp', '.svg', '.ttf', '.otf', '.wav', '.ogg', '.mp3', '.glb', '.gltf')
    uncovered = [name for name in rows if name.lower().endswith(importable) and name + '.import' not in rows and not ignored_by(name, ignored_markers)]
    require(not uncovered, 'Snapshot importable source lacks tracked remap: ' + ', '.join(uncovered[:12]))
    class_path = ROOT / '.godot/global_script_class_cache.cfg'
    regular(class_path, ROOT)
    class_raw = class_path.read_bytes()
    class_text = class_raw.decode('utf-8-sig')
    entries = re.findall(r'\{[^{}]*\}', class_text)
    kept = []
    class_proofs = []
    seen_paths = set(); seen_classes = set()
    for entry in entries:
        paths = re.findall(r'"path":\s*"res://([^"]+)"', entry)
        require(len(paths) == 1, 'Unrecognized class cache entry')
        if paths[0] not in rows: continue
        path = paths[0]
        raw = git('cat-file', 'blob', rows[path]['blob_oid'])
        require(blob(raw) == rows[path]['blob_oid'], 'Frozen class source blob mismatch: ' + path)
        proof = verify_class_entry(entry, path, raw)
        require(path not in seen_paths and proof['class'] not in seen_classes, 'Duplicate global class cache entry: ' + path)
        seen_paths.add(path); seen_classes.add(proof['class'])
        kept.append(entry); class_proofs.append(proof)
    require(kept, 'No valid global classes in copied cache')
    class_output = ('list=[' + ', '.join(kept) + ']\n').encode()
    generated_inputs = {p.name: sha(p.read_bytes()) for p in (HERE / 'transforms.py', HERE / 'driver.gd.in', HERE / 'ledger.gd.in', Path(__file__))}
    result = {'schema': 1, 'status': 'PLAN_ONLY_NO_BULK_COPY', 'snapshot': commit,
              'source_files': list(rows.values()), 'source_bytes': sum(x['bytes'] for x in rows.values()),
              'cache_files': list(cache_rows.values()), 'cache_bytes': sum(x['bytes'] for x in cache_rows.values()),
              'import_associations': imports, 'class_cache_input_sha256': sha(class_raw),
              'frozen_ignore_markers': ignored_markers, 'ignored_source_files_retained': ignored_files,
              'ignored_imports': ignored_imports,
              'needs_reimport': needs_reimport, 'private_import_required_before_diagnostic': bool(needs_reimport),
              'ignored_runtime_reference_audit': {'files': audited, 'hits': [], 'scope': 'Frozen project/GDScript/scene/resource/shader literal prefix audit, not a general proof against arbitrary dynamic path construction'},
              'class_cache_output_sha256': sha(class_output), 'class_cache_output': class_output.decode(),
              'class_cache_frozen_declarations': class_proofs,
              'generated_inputs': generated_inputs, 'exclusions': EXCLUDED,
              'method_pins': PINS, 'snapshot_is_not_future_v2': True,
              'no_source_writes': True, 'no_git_writes': True, 'no_godot_run': True}
    result['plan_sha256'] = sha(json.dumps(result, sort_keys=True, ensure_ascii=False).encode())
    save(HERE / 'plan.json', result)
    return result


def materialize(plan_path, accepted_digest, instance='entry01'):
    regular(plan_path, HERE)
    p = json.loads(plan_path.read_text(encoding='utf-8'))
    given = p.pop('plan_sha256')
    require(given == accepted_digest == sha(json.dumps(p, sort_keys=True, ensure_ascii=False).encode()), 'Plan digest not explicitly accepted or altered')
    p['plan_sha256'] = given
    require(p['snapshot'].startswith(REF), 'Wrong snapshot')
    for name, digest in p['generated_inputs'].items():
        require(sha((HERE / name).read_bytes()) == digest, 'Preparation code changed since plan: ' + name)
    require(re.fullmatch(r'[a-z0-9_]{1,32}', instance) is not None, 'Invalid isolated instance name')
    destination = HERE / ('mirror_' + given[:12] + '_' + instance)
    require(destination.resolve().is_relative_to(HERE.resolve()) and not destination.exists(), 'Destination exists or escaped; no overwrite/deletion allowed')
    total = p['source_bytes'] + p['cache_bytes']
    require(total <= 2 * 1024**3, 'Copy exceeds 2 GiB hard limit; revise plan explicitly')
    destination.mkdir()
    source_receipt = {}
    transforms = {}
    try:
        for row in p['source_files']:
            name = row['path']; relative_safe(name)
            raw = git('cat-file', 'blob', row['blob_oid'])
            require(len(raw) == row['bytes'] and blob(raw) == row['blob_oid'], 'Snapshot blob mismatch: ' + name)
            if name in ('scripts/sfx.gd', 'scripts/art_db.gd'):
                raw, transforms[name] = instrument(name, raw)
            if name == 'project.godot':
                text = raw.decode('utf-8-sig')
                require(text.count('[autoload]') == 1, 'Autoload section drift')
                text = text.replace('[autoload]', '[autoload]\n\nFirstUseDiag="*res://_first_use/ledger.gd"', 1)
                raw = text.encode('utf-8')
            output = destination / name
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(raw)
            source_receipt[name] = {'bytes': len(raw), 'sha256': sha(raw)}
        for row in p['cache_files']:
            name = row['path']; relative_safe(name)
            local = ROOT / name; regular(local, ROOT)
            raw = local.read_bytes()
            require(len(raw) == row['bytes'] and sha(raw) == row['sha256'], 'Import cache changed after plan: ' + name)
            output = destination / name
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(raw)
        cache = destination / '.godot/global_script_class_cache.cfg'
        cache.parent.mkdir(exist_ok=True)
        class_raw = p['class_cache_output'].encode('utf-8')
        require(sha(class_raw) == p['class_cache_output_sha256'], 'Derived class cache output digest differs from plan')
        cache.write_bytes(class_raw)
        derived_cache = {'path': '.godot/global_script_class_cache.cfg', 'bytes': len(class_raw), 'sha256': sha(class_raw)}
        generated = destination / '_first_use'; generated.mkdir()
        sources = {'_first_use/ledger.gd': (HERE / 'ledger.gd.in').read_bytes(),
                   '_first_use/driver.gd': driver((destination / TOOLS[0]).read_bytes(), (HERE / 'driver.gd.in').read_text(encoding='utf-8'))}
        for name, raw in sources.items():
            (destination / name).write_bytes(raw)
            source_receipt[name] = {'bytes': len(raw), 'sha256': sha(raw)}
        receipt = {'schema': 1, 'complete': True, 'snapshot': p['snapshot'], 'plan_sha256': given,
                   'mirror': str(destination), 'source_files': source_receipt, 'method_transforms': transforms,
                    'import_cache_files': p['cache_files'], 'production_mutated': False, 'godot_run': False,
                    'derived_cache_files': [derived_cache], 'class_cache_frozen_declarations': p['class_cache_frozen_declarations'],
                    'frozen_ignore_markers': p['frozen_ignore_markers'], 'ignored_imports': p['ignored_imports'],
                    'ignored_source_files_retained': p['ignored_source_files_retained'],
                    'needs_reimport': p['needs_reimport'], 'private_import_required_before_diagnostic': bool(p['needs_reimport']),
                   'excluded_cache_note': 'No editor/shader/UID cache or normal profile copied; GPU warm state is not guaranteed.'}
        save(destination / '_first_use/materialization_receipt.json', receipt)
        return receipt
    except BaseException as error:
        save(destination / 'materialization_failed.json', {'complete': False, 'error_type': type(error).__name__, 'error': str(error), 'preserved': True})
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('inventory', 'plan', 'materialize'), nargs='?', default='inventory')
    parser.add_argument('--plan', type=Path, default=HERE / 'plan.json')
    parser.add_argument('--accept-plan-sha256', default='')
    parser.add_argument('--instance', default='entry01')
    args = parser.parse_args()
    if args.mode == 'inventory': result = inventory()
    elif args.mode == 'plan': result = plan()
    else: result = materialize(args.plan.resolve(), args.accept_plan_sha256, args.instance)
    print(json.dumps({key: result[key] for key in ('status', 'snapshot', 'plan_sha256', 'source_bytes', 'cache_bytes', 'mirror', 'complete') if key in result}, ensure_ascii=True))


if __name__ == '__main__': main()
