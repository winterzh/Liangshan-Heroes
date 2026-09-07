"""Recover only hash-addressed campaign evidence; never modify historical files or art.

Default is a read-only inventory. --write copies verified bytes to a dedicated
contract folder and records the original reference and its unchanged owner hash.
No source-directory recursion/copy, image processing, Git or Godot operations.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
DEST = Path('tools/contracts/art_provenance_recovery_20260907')
OLD_WORKSPACE = 'C:/Users/rsb/Desktop/AI项目/水浒/'
MANIFESTS = (
    'assets/campaign/lin_chong_p0_direction4_manifest.json',
    'assets/campaign/yezhulin_remaining_p0_direction4_manifest.json',
    'assets/campaign/huangnigang_p0_direction4_manifest.json',
    'assets/campaign/ordinary_officials_p0_direction4_manifest.json',
    'assets/campaign/jiangzhou_prisoners_p0_direction4_manifest.json',
    'assets/campaign/li_kui_jiangzhou_direction4_manifest.json',
    'assets/direction4/lianhuanma_p0_direction4_manifest.json',
    'assets/campaign/daming_prisoners_rect_rebuild_direction4_manifest.json',
    'assets/campaign/daming_lu_rescued_p0_direction4_manifest.json',
    'assets/campaign/gao_qiu_captured_direction4_manifest.json',
    'assets/campaign/gao_flagship_direction4_manifest.json',
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize(value):
    return str(value).replace('\\', '/').removeprefix('//?/')


def pairs(value, owner, pointer='$'):
    """Only named file/hash pairs, plus documented identical-raw-image aliases."""
    found = []
    if isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(item, str) or not re.search(r'\.(png|json|txt|zip|md)$', item, re.I):
                continue
            if key in ('production_path',) or (key == 'path' and item.startswith('assets/')):
                continue
            stem = re.sub(r'_(path|file)$', '', key)
            candidates = [key + '_sha256', stem + '_sha256']
            if key in ('path', 'file'): candidates += ['sha256']
            if key == 'source_file': candidates += ['source_sha256']
            if key == 'codex_imagegen_original': candidates += ['raw_sha256']
            expected = next((value[k].lower() for k in candidates
                             if isinstance(value.get(k), str) and re.fullmatch('[0-9a-fA-F]{64}', value[k])), None)
            if expected:
                found.append({'original': normalize(item), 'sha256': expected,
                              'owner': owner, 'pointer': pointer + '.' + key})
            if key == 'raw_source_path' and expected:
                original = value.get('generation_origin', {}).get('generated_image_path')
                if original:
                    found.append({'original': normalize(original), 'sha256': expected,
                                  'owner': owner, 'pointer': pointer + '.generation_origin.generated_image_path'})
        for key, item in value.items():
            found.extend(pairs(item, owner, pointer + '.' + key))
    elif isinstance(value, list):
        for index, item in enumerate(value): found.extend(pairs(item, owner, f'{pointer}[{index}]'))
    return found


def candidates(history, original):
    """Translate known legacy roots; never search unrelated user directories."""
    relative = normalize(original)
    if relative.startswith(OLD_WORKSPACE): relative = relative[len(OLD_WORKSPACE):]
    elif re.match(r'^[A-Za-z]:|^/', relative): return []
    if '..' in PurePosixPath(relative).parts: return []
    raw = [history / relative, history / 'Liangshan-Heroes' / relative]
    if relative.startswith('Liangshan-Heroes/'):
        raw.append(history / 'Liangshan-Heroes' / relative[len('Liangshan-Heroes/'):])
    return [p for p in raw if p.resolve().is_relative_to(history.resolve())]


def run(history, write=False):
    history = history.resolve()
    requirements, owners = [], {}
    for relative in MANIFESTS:
        path = ROOT / relative
        owners[relative] = digest(path)
        requirements += pairs(json.loads(path.read_text(encoding='utf-8')), relative)
    # Every alias must independently name a frozen hash. Reuse an already found
    # raw copy only when its bytes match that same historical expected hash.
    found_by_sha = {}
    direct, missing = [], []
    for row in requirements:
        matches = [p for p in candidates(history, row['original'])
                   if p.is_file() and not p.is_symlink() and digest(p) == row['sha256']]
        if matches:
            found_by_sha[row['sha256']] = matches[0]
            direct.append((row, matches[0]))
        else: missing.append(row)
    unresolved = []
    for row in missing:
        path = found_by_sha.get(row['sha256'])
        if path: direct.append((row, path))
        else: unresolved.append(row)
    entries, copied = {}, {}
    for row, path in direct:
        key = row['original']
        if key in entries and entries[key]['sha256'] != row['sha256']:
            raise ValueError('Conflicting historical hashes for ' + key)
        destination = DEST / 'files' / row['sha256'] / path.name
        target = ROOT / destination
        if write:
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() and digest(target) != row['sha256']:
                raise ValueError('Refuse to replace an existing recovery file: ' + str(target))
            if not target.exists(): target.write_bytes(path.read_bytes())
            if digest(target) != row['sha256']: raise ValueError('Copy verification failed')
        entry = entries.setdefault(key, {'original': key, 'target': destination.as_posix(),
                                       'sha256': row['sha256'], 'owners': [],
                                       'recovered_from': path.relative_to(history).as_posix()})
        entry['owners'].append({'manifest': row['owner'], 'manifest_sha256': owners[row['owner']],
                                'pointer': row['pointer']})
        copied[destination.as_posix()] = path.stat().st_size
    # Four old Lin Chong groups used directory existence as their backup gate,
    # without recording a backup-manifest hash. Preserve only the predecessor
    # PNGs explicitly named by those groups; their hashes are new migration
    # observations, clearly distinguished from pre-existing frozen source hashes.
    directories = []
    for relative in MANIFESTS:
        data = json.loads((ROOT / relative).read_text(encoding='utf-8'))
        for record in [data] + data.get('groups', []):
            original = record.get('backup_path')
            if not original: continue
            paths = [p for p in candidates(history, original) if p.is_dir()]
            if not paths: continue
            source_dir = paths[0]
            required = []
            if record.get('backup_manifest'):
                expected = record.get('backup_manifest_sha256', '').lower()
                file = source_dir / 'backup_manifest.json'
                if file.is_file() and digest(file) == expected:
                    required.append((file, 'backup_manifest.json', 'historical_manifest_sha256'))
            else:
                for output in record.get('outputs', []):
                    name = output.get('path', '')
                    file = source_dir / name
                    if (name.startswith('assets/campaign/anim/') and '..' not in PurePosixPath(name).parts
                            and file.resolve().is_relative_to(source_dir.resolve())
                            and file.is_file() and not file.is_symlink()):
                        required.append((file, name, 'new_migration_observation_of_original_predecessor'))
            destination = DEST / 'directories' / hashlib.sha256(normalize(original).encode()).hexdigest()[:16]
            files = []
            if not required and not record.get('backup_manifest'):
                # Some groups introduced entirely new paths and the old backup
                # holds only unrelated pre-existing documentation. Retain a
                # read-only existence/inventory receipt instead of those files.
                inventory = {'kind': 'observed_legacy_backup_directory',
                             'original': normalize(original), 'observed_during': '2026-09-07 migration',
                             'not_a_historical_20260902_hash_record': True,
                             'files': [{'path': p.relative_to(source_dir).as_posix(), 'sha256': digest(p), 'bytes': p.stat().st_size}
                                       for p in sorted(source_dir.rglob('*')) if p.is_file() and not p.is_symlink()]}
                if not inventory['files']: continue
                payload = (json.dumps(inventory, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
                target = ROOT / destination / 'observed_directory.json'
                if write:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if target.exists() and target.read_bytes() != payload:
                        raise ValueError('Refuse to rewrite the frozen directory observation')
                    target.write_bytes(payload)
                files.append({'path': (destination / 'observed_directory.json').as_posix(),
                              'sha256': hashlib.sha256(payload).hexdigest(),
                              'hash_basis': 'new_migration_observation_only',
                              'recovered_from': source_dir.relative_to(history).as_posix()})
                copied[files[-1]['path']] = len(payload)
            for file, name, basis in required:
                target = ROOT / destination / name
                expected = digest(file)
                if write:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if target.exists() and digest(target) != expected: raise ValueError('Directory evidence drift')
                    if not target.exists(): target.write_bytes(file.read_bytes())
                files.append({'path': (destination / name).as_posix(), 'sha256': expected,
                              'hash_basis': basis, 'recovered_from': file.relative_to(history).as_posix()})
                copied[(destination / name).as_posix()] = file.stat().st_size
            directories.append({'original': normalize(original), 'target': destination.as_posix(),
                                'owner': relative, 'owner_sha256': owners[relative], 'files': files})
    report = {'schema_version': 1, 'kind': 'fixed_hash_campaign_evidence_recovery',
              'production_modified': False, 'historical_files_modified': False,
              'source_manifests': owners, 'entries': sorted(entries.values(), key=lambda r: r['original']),
              'directories': directories, 'unresolved': unresolved,
              'summary': {'requirements': len(requirements), 'recovered_references': len(entries),
                          'unique_files': len(copied), 'bytes': sum(copied.values()),
                          'unresolved_references': len(unresolved)}}
    if write:
        target = ROOT / DEST / 'mapping.json'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', type=Path, required=True)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    report = run(args.history, args.write)
    print(json.dumps({'written': args.write, **report['summary'], 'unresolved': report['unresolved']}, ensure_ascii=False, indent=2))


if __name__ == '__main__': main()
