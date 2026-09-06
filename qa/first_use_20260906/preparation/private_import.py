"""One controlled import of an approved private mirror. Default: prepare only; no engine."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

sys.dont_write_bytecode = True
from prepare import HERE, ROOT, regular, require, save, sha, verify_class_entry

COPY_PLAN_SHA = 'cb051680f879c5cbf47fd44536c127eddaa1e393ea799afff2d9692c28537ed5'
ENTRY_BEFORE_SHA = '8fce3951700ca2ebc6469f18ef283f31c06720ef344c7459f91dd1f15bb0cf26'
METADATA = {'_first_use/materialization_receipt.json', '_first_use/post_import_pins.json', '_first_use/run_once.json'}
PLAN_PATH = HERE / 'private_import_plan_entry01.json'
TOOL_NAMES = ('prepare.py', 'transforms.py', 'run_entry.py', 'private_import.py', 'driver.gd.in', 'ledger.gd.in')


def digest(value):
    return sha(json.dumps(value, sort_keys=True, ensure_ascii=False).encode())


def no_link(path):
    info = path.lstat()
    require(not stat.S_ISLNK(info.st_mode) and not (getattr(info, 'st_file_attributes', 0) & 0x400), 'Link/reparse point refused: ' + str(path))


def source_manifest(mirror):
    """Enumerate ALL private source paths twice; no rglob error swallowing or unknown root gaps."""
    def enumerate_paths():
        no_link(mirror)
        require(mirror.is_dir(), 'Private source root missing')
        files, directories = [], []
        def scan_error(error):
            raise RuntimeError('Source enumeration failed: ' + str(error))
        for current, dirs, names in os.walk(mirror, onerror=scan_error, followlinks=False):
            base = Path(current)
            for name in dirs + names: no_link(base / name)
            if base == mirror and '.godot' in dirs: dirs.remove('.godot')
            directories.extend((base / name).relative_to(mirror).as_posix() for name in dirs)
            for name in names:
                relative = (base / name).relative_to(mirror).as_posix()
                if relative not in METADATA:
                    regular(base / name, mirror)
                    files.append(relative)
        return sorted(files), sorted(directories)
    first = enumerate_paths()
    rows = {}
    for name in first[0]:
        raw = (mirror / name).read_bytes()
        rows[name] = {'bytes': len(raw), 'sha256': sha(raw)}
    require(first == enumerate_paths(), 'Source path set changed during enumeration/hash')
    return {'source_files': rows, 'directories': first[1]}


def missing_uids(before):
    # Current copied snapshot has .gd sidecars only; do not permit arbitrary *.uid.
    rows = before['source_files']
    return {name + '.uid': name for name in rows if name.endswith('.gd') and name + '.uid' not in rows}


def canonical_uid(raw):
    match = re.fullmatch(rb'uid://([a-y0-8]{1,13})(?:\r?\n)?', raw)
    require(match is not None, 'Invalid generated UID bytes')
    digits = match.group(1)
    value = 0
    for digit in digits: value = value * 34 + b'abcdefghijklmnopqrstuvwxy012345678'.index(digit)
    require(value <= 0x7fffffffffffffff and (len(digits) == 1 or digits[0] != ord('a')), 'Noncanonical/out-of-range generated UID')


def accept_sources(mirror, before, allowances):
    require(allowances == missing_uids(before), 'Missing UID allowance differs from precise original source derivation')
    after = source_manifest(mirror)
    expected = dict(before['source_files'])
    generated = {}
    for name, script in allowances.items():
        if name in after['source_files']:
            canonical_uid((mirror / name).read_bytes())
            expected[name] = after['source_files'][name]
            generated[name] = dict(expected[name], source_script=script, source_script_sha256=before['source_files'][script]['sha256'])
    require(after['source_files'] == expected and after['directories'] == before['directories'], 'Import changed existing source/metadata or added undeclared paths/directories')
    return after, generated


def class_cache_pin(mirror, declarations):
    path = mirror / '.godot/global_script_class_cache.cfg'
    regular(path, mirror)
    raw = path.read_bytes()
    text = raw.decode('utf-8-sig')
    entries = re.findall(r'\{[^{}]*\}', text, re.S)
    # Godot may rewrite formatting; accept the actual serialized raw bytes only after semantic proof.
    require(re.fullmatch(r'\s*list\s*=\s*\[\s*\]\s*', re.sub(r'\{[^{}]*\}\s*,?\s*', '', text, flags=re.S)) is not None, 'Unsupported derived class cache structure')
    expected = {row['path']: (row['class'], row['base']) for row in declarations}
    found, classes = {}, set()
    for entry in entries:
        paths = re.findall(r'"path":\s*"res://([^"]+)"', entry)
        require(len(paths) == 1 and paths[0] in expected and paths[0] not in found, 'Unknown/duplicate derived class path')
        name = paths[0]
        regular(mirror / name, mirror)
        proof = verify_class_entry(entry, name, (mirror / name).read_bytes())
        require((proof['class'], proof['base']) == expected[name] and proof['class'] not in classes, 'Derived class/base differs from frozen declarations')
        found[name] = (proof['class'], proof['base']); classes.add(proof['class'])
    require(found == expected, 'Derived class cache dropped frozen class declarations')
    return {'path': '.godot/global_script_class_cache.cfg', 'bytes': len(raw), 'sha256': sha(raw)}


def cache_pins(mirror, associations):
    """Check every nonignored source MD5 and destination MD5, then freeze actual new raw bytes."""
    rows, proofs = {}, []
    for item in associations:
        regular(mirror / item['source'], mirror)
        source_md5 = hashlib.md5((mirror / item['source']).read_bytes()).hexdigest()
        require(source_md5 == item['source_md5'], 'Frozen import source MD5 changed: ' + item['source'])
        # This reviewed snapshot consists of png/svg with exactly one output and one MD5.
        require(len(item['destinations']) == len(item['md5_sidecars']) == 1, 'Unsupported importer output count')
        dest, sidecar = item['destinations'][0], item['md5_sidecars'][0]
        for name in (dest, sidecar):
            require(name.startswith('.godot/imported/'), 'Importer output escaped cache root')
            regular(mirror / name, mirror)
            raw = (mirror / name).read_bytes()
            rows[name] = {'path': name, 'bytes': len(raw), 'sha256': sha(raw)}
        md5_text = (mirror / sidecar).read_text(encoding='utf-8-sig')
        source_fields = re.findall(r'^source_md5="([0-9a-f]{32})"\s*$', md5_text, re.M)
        dest_fields = re.findall(r'^dest_md5="([0-9a-f]{32})"\s*$', md5_text, re.M)
        dest_md5 = hashlib.md5((mirror / dest).read_bytes()).hexdigest()
        require(source_fields == [source_md5] and dest_fields == [dest_md5], 'Imported source/destination MD5 mismatch: ' + item['source'])
        proofs.append({'source': item['source'], 'source_md5': source_md5, 'destination': dest, 'destination_md5': dest_md5})
    return [rows[name] for name in sorted(rows)], proofs


def executable(path):
    path = path.resolve()
    require(path.suffix.lower() == '.exe' and re.search(r'[._-]console\.exe$', path.name, re.I) is None, 'Use actual non-console Godot .exe; console forwarding child ownership is not accepted')
    no_link(path)
    require(path.is_file(), 'Godot executable missing')
    with path.open('rb') as handle: require(handle.read(2) == b'MZ', 'Not a Windows executable')
    return path


def read_json(path):
    regular(path, HERE)
    return json.loads(path.read_text(encoding='utf-8'))


def tool_pins():
    return {name: sha((HERE / name).read_bytes()) for name in TOOL_NAMES}


def prepare_import(mirror):
    import run_entry
    require(mirror == (HERE / 'mirror_cb051680f879_entry01').resolve(), 'This approval covers only entry01')
    require(not PLAN_PATH.exists(), 'Private import plan already exists; no silent replacement')
    receipt_path = mirror / '_first_use/materialization_receipt.json'
    receipt = read_json(receipt_path)
    copy_plan = read_json(HERE / 'plan.json')
    copy_digest = copy_plan.pop('plan_sha256')
    require(copy_digest == COPY_PLAN_SHA == digest(copy_plan) == receipt['plan_sha256'], 'Approved copy plan/receipt mismatch')
    require(receipt['complete'] and Path(receipt['mirror']).resolve() == mirror, 'Incomplete/moved materialization')
    # Verify original pins without claiming pending reimport is complete.
    initial = dict(receipt); initial['needs_reimport'] = []
    run_entry.mirror_sources(mirror, initial)
    before = source_manifest(mirror)
    require(before['source_files'] == receipt['source_files'], 'Materialized source mismatch')
    derived = class_cache_pin(mirror, receipt['class_cache_frozen_declarations'])
    require(derived == receipt['derived_cache_files'][0], 'Initial derived cache differs from materialization')
    for item in receipt['needs_reimport']:
        for name in item['destinations'] + item['md5_sidecars']:
            require(not (mirror / name).exists(), 'Old mismatched cache unexpectedly copied: ' + name)
    result = {'schema': 1, 'status': 'PREPARED_NO_GODOT', 'mirror': str(mirror), 'snapshot': receipt['snapshot'],
              'copy_plan_sha256': COPY_PLAN_SHA, 'copy_plan_file_sha256': sha((HERE / 'plan.json').read_bytes()),
              'materialization_receipt_sha256': sha(receipt_path.read_bytes()), 'source_before': before,
              'missing_script_uids': missing_uids(before), 'tool_pins': tool_pins(),
              'run_entry_change': {'before_sha256': ENTRY_BEFORE_SHA, 'after_sha256': sha((HERE / 'run_entry.py').read_bytes()),
                                   'reason': 'Remove HOME/USERPROFILE/TMP/TEMP/XDG overrides; strict enumeration, actual non-console exe, verified post-import pins'},
              'engine_policy': 'Explicit non-console Windows exe; bounded headless editor import; shared exclusive lock',
              'environment_overrides': ['APPDATA', 'LOCALAPPDATA', 'CAMPAIGN_QA', 'POLISH_*', 'FIRST_USE_*'],
              'production_mutated': False, 'godot_run': False}
    result['import_plan_sha256'] = digest(result)
    save(PLAN_PATH, result)
    return result


def verify_plan(plan):
    bare = dict(plan); given = bare.pop('import_plan_sha256')
    require(given == digest(bare), 'Import plan digest changed')
    require(plan['copy_plan_sha256'] == COPY_PLAN_SHA and tool_pins() == plan['tool_pins'], 'Import preparation tools changed since separate plan')
    require(sha((HERE / 'plan.json').read_bytes()) == plan['copy_plan_file_sha256'], 'Original copy plan bytes changed')
    mirror = Path(plan['mirror']).resolve()
    require(mirror == (HERE / 'mirror_cb051680f879_entry01').resolve(), 'Import target changed')
    receipt_path = mirror / '_first_use/materialization_receipt.json'
    require(sha(receipt_path.read_bytes()) == plan['materialization_receipt_sha256'], 'Original materialization receipt changed')
    return mirror, read_json(receipt_path)


def import_once(plan, exe, timeout):
    import run_entry
    require(os.name == 'nt' and 30 <= timeout <= 600, 'Windows and bounded 30..600 second timeout required')
    mirror, original = verify_plan(plan)
    exe = executable(exe)
    require(source_manifest(mirror) == plan['source_before'], 'Preimport source drift')
    initial = dict(original); initial['needs_reimport'] = []
    run_entry.mirror_sources(mirror, initial)
    lock = ROOT / '.godot/redraw_rejection_source.lock'
    require(not lock.exists() and not run_entry.godot_process_ids(), 'Shared Godot/source slot occupied')
    no_link(lock.parent)
    output = HERE / 'imports' / plan['import_plan_sha256'][:12]
    require(not output.exists(), 'This import was already attempted; preserve receipt and review explicitly')
    output.mkdir(parents=True)
    token = str(os.getpid()) + '|' + str(output)
    descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    os.write(descriptor, token.encode()); os.close(descriptor)
    result = {'schema': 1, 'complete': False, 'import_plan_sha256': plan['import_plan_sha256'],
              'plan_sha256': COPY_PLAN_SHA, 'materialization_receipt_sha256': plan['materialization_receipt_sha256'],
              'mirror': str(mirror), 'source_before_sha256': digest(plan['source_before']),
              'engine_raw_sha256': sha(exe.read_bytes()), 'engine_name': exe.name, 'timeout_seconds': timeout,
              'production_mutated': False, 'godot_run': False, 'post_import_pins_written': False}
    child, pending_pins = None, None
    try:
        env = run_entry.environment(mirror, output, 'clockless')
        argv = [str(exe), '--headless', '--editor', '--import', '--path', str(mirror), '--log-file', str(output / 'engine.log')]
        with (output / 'process.log').open('wb') as log:
            require(lock.is_file() and lock.read_text(encoding='utf-8') == token, 'Shared lock ownership changed before Popen')
            verify_plan(plan)
            require(source_manifest(mirror) == plan['source_before'], 'Source changed immediately before import')
            require(not run_entry.godot_process_ids(), 'Another Godot appeared before import Popen')
            child = subprocess.Popen(argv, cwd=mirror, env=env, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            result.update(pid=child.pid, godot_run=True)
            try: result['exit_code'] = child.wait(timeout=timeout)
            except BaseException:
                child.kill()
                result['exit_code'] = child.wait(timeout=30)
                raise
        log_text = (output / 'process.log').read_text(encoding='utf-8', errors='replace')
        if (output / 'engine.log').exists(): log_text += '\n' + (output / 'engine.log').read_text(encoding='utf-8', errors='replace')
        result['engine_errors'] = bool(re.search(r'SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b', log_text, re.M))
        require(result['exit_code'] == 0 and not result['engine_errors'], 'Private import exit/log failure')
        after, generated = accept_sources(mirror, plan['source_before'], plan['missing_script_uids'])
        derived = class_cache_pin(mirror, original['class_cache_frozen_declarations'])
        copy_plan = read_json(HERE / 'plan.json')
        cache_rows, proofs = cache_pins(mirror, copy_plan['import_associations'])
        result.update(source_after_sha256=digest(after), generated_uids=generated,
                      derived_cache_before=original['derived_cache_files'][0], derived_cache_after=derived,
                      imported_cache_files=cache_rows, import_proofs=proofs)
        pending_pins = dict(original)
        pending_pins.update(source_files=after['source_files'], source_directories=after['directories'],
                            import_cache_files=cache_rows, derived_cache_files=[derived],
                            private_import_required_before_diagnostic=False, generated_uid_proofs=generated,
                            import_plan_sha256=plan['import_plan_sha256'], materialization_receipt_sha256=plan['materialization_receipt_sha256'])
    except BaseException as error:
        result.update(error_type=type(error).__name__, error=str(error))
    finally:
        try: exited = child is None or child.poll() is not None
        except BaseException as error:
            exited = False; result['owned_child_poll_error'] = type(error).__name__
        result['owned_child_exit_confirmed'] = exited
        try:
            result['remaining_godot_pids'] = run_entry.godot_process_ids()
            idle = not result['remaining_godot_pids']
        except BaseException as error:
            idle = False; result['process_scan_error'] = str(error)
        try:
            verify_plan(plan)
            final_source, _ = accept_sources(mirror, plan['source_before'], plan['missing_script_uids'])
            result['source_final_sha256'] = digest(final_source)
            if pending_pins is not None:
                require(final_source['source_files'] == pending_pins['source_files'], 'Source drift after import validation')
                require(class_cache_pin(mirror, original['class_cache_frozen_declarations']) == pending_pins['derived_cache_files'][0], 'Derived cache drift after import validation')
                require(cache_pins(mirror, read_json(HERE / 'plan.json')['import_associations'])[0] == pending_pins['import_cache_files'], 'Importer cache drift after validation')
        except BaseException as error:
            pending_pins = None; result['final_verification_error'] = str(error)
        try: owned = lock.is_file() and lock.read_text(encoding='utf-8') == token
        except BaseException: owned = False
        result['lock_preserved'] = not (exited and idle and owned)
        result['complete'] = bool(pending_pins is not None and exited and idle and owned and 'error' not in result)
        if result['complete']:
            completion = {'complete': True, 'owned_child_exit_confirmed': True, 'exit_code': 0,
                          'engine_errors': False, 'plan_sha256': COPY_PLAN_SHA}
            pending_pins['private_import_completion'] = completion
            pending_pins['pins_sha256'] = digest(pending_pins)
            result['post_import_pins_sha256'] = pending_pins['pins_sha256']
            save(mirror / '_first_use/post_import_pins.json', pending_pins)
            result['post_import_pins_written'] = True
        save(output / 'import_receipt.json', result)
        if not result['lock_preserved']: lock.unlink()
    print(json.dumps({'complete': result['complete'], 'output': str(output), 'lock_preserved': result['lock_preserved']}))
    return 0 if result['complete'] else 1


def load_entry_pins(mirror, original):
    path = mirror / '_first_use/post_import_pins.json'
    if not path.exists(): return original
    plan = read_json(PLAN_PATH)
    checked_mirror, checked_original = verify_plan(plan)
    require(checked_mirror == mirror and checked_original == original, 'Entry original source receipt mismatch')
    pins = read_json(path)
    bare = dict(pins); given = bare.pop('pins_sha256')
    require(given == digest(bare) and pins['import_plan_sha256'] == plan['import_plan_sha256'], 'Postimport pins digest/plan mismatch')
    receipt = read_json(HERE / 'imports' / plan['import_plan_sha256'][:12] / 'import_receipt.json')
    require(receipt.get('complete') is True and receipt.get('owned_child_exit_confirmed') is True
            and receipt.get('exit_code') == 0 and receipt.get('engine_errors') is False
            and receipt.get('post_import_pins_sha256') == given and receipt.get('import_plan_sha256') == plan['import_plan_sha256'],
            'Postimport pins do not link to successful owned-process import receipt')
    return pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('prepare', 'run'), nargs='?', default='prepare')
    parser.add_argument('--mirror', type=Path, default=HERE / 'mirror_cb051680f879_entry01')
    parser.add_argument('--godot', type=Path)
    parser.add_argument('--accept-import-plan-sha256', default='')
    parser.add_argument('--timeout-seconds', type=int, default=600)
    args = parser.parse_args()
    if args.mode == 'prepare':
        plan = prepare_import(args.mirror.resolve())
        print(json.dumps({'import_plan_sha256': plan['import_plan_sha256'], 'missing_uid_count': len(plan['missing_script_uids']), 'godot_run': False}))
        return 0
    plan = read_json(PLAN_PATH)
    require(args.accept_import_plan_sha256 == plan['import_plan_sha256'] and args.godot is not None, 'Explicit new import plan SHA and actual non-console Godot executable required')
    return import_once(plan, args.godot, args.timeout_seconds)


if __name__ == '__main__': sys.exit(main())
