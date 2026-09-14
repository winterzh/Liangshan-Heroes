"""Verify and archive this release's local evidence; never upload or publish.

Run only after the native QA, candidate builder and explicit 11-case smoke finish.
Every destination is new. Original receipts are never rewritten. Player data
and packaged binaries are never copied into the repository evidence archive.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import zipfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
from run_steam_integration_qa import LOCK, native_dependencies, resolve_profile_root, sources
from build_steam_candidate import allowed
from contracts.run_content_identity_20260907.build_identity import DERIVED
from contracts.run_content_identity_20260907.probe_runner import LABELS

QA_DEFAULT = ROOT / '.godot/steam_integration_qa/20260914_081008_cd74022b'

UPLOAD_DEFAULT = Path('E:/CodexTemp/steam_release_20260914/upload')
EXPECTED_SOURCE_HEAD = '50558b053998f8dbad2f54aae27b5610f8ac61ec'
QA_TOOLS = {'tools/steam_integration_qa.gd', 'tools/steam_integration_suite.gd',
            'tools/steam_catalog_export.gd', 'tools/steam_fake_api.gd'}
VENDOR = {
    'libgodotsteam.windows.template_release.x86_64.dll': 'vendor/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll',
    'steam_api64.dll': 'vendor/godotsteam/win64/steam_api64.dll',
    'steam_stats_reader.dll': 'vendor/steam_stats_reader/win64/steam_stats_reader.dll',
    'GODOTSTEAM_LICENSE.txt': 'vendor/godotsteam/license.md',
    'STEAM_STATS_READER_GODOT_CPP_LICENSE.txt': 'vendor/steam_stats_reader/GODOT_CPP_LICENSE.md',
}
EXE = 'LiangshanHeroes.exe'
MEMBERS = set(VENDOR) | {EXE}
BINARIES = {EXE} | {name for name in VENDOR if name.endswith('.dll')}
CASE_NAMES = [f'level{i}' for i in range(1, 9)] + ['defense', 'cleanup', 'main_menu']
ERROR = re.compile(r'SCRIPT ERROR|Parse Error|ERROR:|Failed loading resource|Assertion failed')


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def directory(path, parent=None):
    path = Path(path)
    if not path.is_absolute():
        path = ROOT / path
    resolve_profile_root(path)  # Check raw ancestry before resolving links.
    need(path.is_dir(), 'Missing input directory: ' + str(path))
    path = path.resolve()
    if parent is not None:
        path.relative_to(Path(parent).resolve())
    return path


def regular(path):
    path = Path(path)
    resolve_profile_root(path.parent)
    need(path.is_file() and not path.is_symlink(), 'Missing/linked input: ' + str(path))
    need(not (getattr(path.lstat(), 'st_file_attributes', 0) & 0x400), 'Reparse input: ' + str(path))
    return path


def relative(name):
    need(isinstance(name, str) and bool(name) and '\\' not in name, 'Invalid source path')
    path = PurePosixPath(name)
    need(not path.is_absolute() and path.as_posix() == name and
         all(part not in ('', '.', '..') and ':' not in part for part in path.parts), 'Unsafe source path: ' + name)
    return Path(*path.parts)


def stream_identity(stream):
    digest, sha1, size = hashlib.sha256(), hashlib.sha1(), 0
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(block)
        sha1.update(block)
        size += len(block)
    return {'bytes': size, 'sha256': digest.hexdigest(), 'sha1': sha1.hexdigest()}


def identity(path):
    with regular(path).open('rb') as file:
        return stream_identity(file)


def read(path):
    return json.loads(regular(path).read_text(encoding='utf-8'))


def rows_by_path(rows, label):
    need(isinstance(rows, list) and rows, label + ': empty rows')
    result = {}
    for row in rows:
        relative(row['path'])
        need(row['path'] not in result, label + ': duplicate path')
        need(re.fullmatch(r'[0-9a-f]{64}', row.get('sha256', '')) is not None, label + ': invalid SHA256')
        result[row['path']] = row
    return result


def matches(actual, recorded, label):
    need(type(recorded.get('bytes')) is int and actual['bytes'] == recorded['bytes'] and
         actual['sha256'] == recorded.get('sha256'), label + ': size/SHA256 mismatch')


def passed_checks(report, count, label, key='name'):
    rows = report.get('checks', [])
    need(report.get('passed') is True and type(count) is int and count > 0 and len(rows) == count,
         label + ': missing/incorrect check count')
    need(all(isinstance(row.get(key), str) and row[key] and row.get('passed') is True for row in rows),
         label + ': failed/malformed check')
    return count


def steps_passed(proof, names, label):
    rows = proof.get('steps', [])
    need([row.get('name') for row in rows] == names, label + ': unexpected steps')
    need(all(type(row.get('exit_code')) is int and row['exit_code'] == 0 and not row.get('errors') for row in rows),
         label + ': process failure')


def clean_log(path):
    text = regular(path).read_text(encoding='utf-8', errors='replace')
    need(not ERROR.search(text), 'Strict error in ' + str(path))
    return text


def current_sources(qa, candidate, source_head):
    need(source_head == EXPECTED_SOURCE_HEAD, 'Unexpected release source commit')
    need(subprocess.run(['git', 'merge-base', '--is-ancestor', source_head, 'HEAD'], cwd=ROOT,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0,
         'Tested source commit is not an ancestor of current HEAD')
    qa_rows = rows_by_path(qa['source_files'], 'Native QA sources')
    runtime = set(sources())
    need(set(qa_rows) == runtime | QA_TOOLS, 'Current/native QA source inventory mismatch')
    candidate_rows = rows_by_path(candidate['source_files'], 'Candidate sources')
    need(set(candidate_rows) == {name for name in runtime if allowed(name) and name != DERIVED},
         'Candidate runtime inventory mismatch')
    for name, row in qa_rows.items():
        need(identity(ROOT / relative(name))['sha256'] == row['sha256'], 'Source changed: ' + name)
        if name in candidate_rows:
            need(candidate_rows[name] == row, 'QA/candidate source row differs: ' + name)
    return {'native_qa_source_files': len(qa_rows), 'candidate_source_files': len(candidate_rows)}


def check_identity(candidate_dir, candidate, name, source_mode, exe_sha):
    folder = candidate_dir / name
    process = read(folder / 'process_receipt.json')
    report = read(folder / 'report.json')
    manifest = read(folder / 'manifest.json')
    need(candidate.get(name) == process, name + ': candidate/process receipt mismatch')
    need(all(process.get(key) is True for key in ('complete', 'child_started', 'child_exit_confirmed', 'lock_owned_by_caller')),
         name + ': incomplete process')
    need(process.get('exit_code') == 0 and process.get('source_mode') is source_mode and
         process.get('pack_sha256') == (None if source_mode else exe_sha), name + ': wrong process/pack')
    need(process.get('report_sha256') == identity(folder / 'report.json')['sha256'], name + ': report SHA mismatch')
    need(report.get('complete') is True and report.get('suite') == 'content-identity' and
         report.get('run_id') == name and type(report.get('process_id')) is int and
         report['process_id'] > 0 and report['process_id'] == process.get('child_pid'), name + ': report/PID mismatch')
    need(report.get('manifest_sha256') == identity(folder / 'manifest.json')['sha256'], name + ': manifest SHA mismatch')
    count = passed_checks(report, process.get('check_count'), name, 'label')
    need(count == len(LABELS) == report.get('check_count') and {row['label'] for row in report['checks']} == LABELS,
         name + ': incomplete identity checks')
    need(manifest.get('run_id') == name and manifest.get('source_mode') is source_mode and manifest.get('native_expected') is True,
         name + ': manifest mode mismatch')
    need(Path(manifest['report']).resolve() == (folder / 'report.json').resolve(), name + ': report path mismatch')
    private = Path(manifest['private_user']).resolve()
    private.relative_to((folder / 'private_profile').resolve())
    need(Path(report['actual_user_dir']).resolve() == private, name + ': private user path mismatch')
    expected = candidate['content_identity']['identity']
    value = report['identity']
    for key in ('source_sha256', 'rules_sha256', 'provider_sha256', 'optional_content'):
        need(value.get(key) == manifest.get(key) == expected[key], name + ': identity mismatch: ' + key)
    need(value.get('engine_binary_sha256') == manifest.get('engine_binary_sha256') == process.get('engine_binary_sha256') == candidate['godot_sha256'],
         name + ': engine mismatch')
    need(value.get('source_mode') is source_mode and value.get('ok') is True and value.get('save_eligible') is True and
         value.get('content_version') == 'source-v1:' + expected['source_sha256'], name + ': ineligible identity')
    need(report.get('full_battle_resume_tested') is False and report.get('release_process_tested') is False and
         process.get('release_process_tested') is False, name + ': expanded scope claim')
    log = clean_log(folder / 'report.log')
    marked = [json.loads(line[len('CONTENT_IDENTITY_REPORT '):]) for line in log.splitlines() if line.startswith('CONTENT_IDENTITY_REPORT ')]
    need(marked == [report], name + ': stdout/report mismatch')
    expected_tools = {ROOT / 'tools/contracts/run_content_identity_20260907' / file
                      for file in ('probe_runner.py', 'build_identity.py', 'pck_probe.gd')}
    need({Path(path) for path in process['sources']} == expected_tools, name + ': probe source inventory mismatch')
    for path, digest in process['sources'].items():
        need(identity(Path(path))['sha256'] == digest, name + ': probe source changed')
    return count


def verify_zip(candidate_dir, proof):
    outputs = rows_by_path(proof['outputs'], 'Candidate outputs')
    need(set(outputs) == BINARIES, 'Candidate must have exactly four binary outputs')
    windows = directory(candidate_dir / 'windows')
    need({path.relative_to(windows).as_posix() for path in windows.rglob('*') if path.is_file()} == BINARIES,
         'Unexpected candidate Windows files')
    actual = {}
    for name, row in outputs.items():
        actual[name] = identity(windows / name)
        matches(actual[name], row, name)
    for name, vendor_path in VENDOR.items():
        vendor = identity(ROOT / vendor_path)
        if name in actual:
            need(actual[name] == vendor, 'Vendor binary differs: ' + name)
        else:
            actual[name] = vendor
    archive = proof['archive']
    need(archive.get('passed') is True and archive.get('path') == 'LiangshanHeroes_Steam_candidate.zip', 'Invalid archive proof')
    path = candidate_dir / archive['path']
    zip_id = identity(path)
    matches(zip_id, archive, 'Archive')
    recorded = rows_by_path(archive['members'], 'Archive members')
    need(set(recorded) == MEMBERS, 'Archive receipt must contain exactly six members')
    members = []
    with zipfile.ZipFile(path) as packed:
        infos = packed.infolist()
        need(len(infos) == 6 and {info.filename for info in infos} == MEMBERS, 'ZIP must contain exactly six unique flat members')
        for info in sorted(infos, key=lambda item: item.filename):
            need(not info.is_dir(), 'ZIP directory not allowed')
            with packed.open(info) as file:
                member = stream_identity(file)
            need(member['bytes'] == info.file_size and member == actual[info.filename], 'ZIP payload differs: ' + info.filename)
            matches(member, recorded[info.filename], 'ZIP member ' + info.filename)
            members.append({'path': info.filename, **member})
    return path, zip_id, members


def same_bytes(source, target):
    with regular(source).open('rb') as left, regular(target).open('rb') as right:
        while True:
            a, b = left.read(1024 * 1024), right.read(1024 * 1024)
            if a != b:
                return False
            if not a:
                return True


def copy_new(source, destination, expected):
    resolve_profile_root(destination.parent)
    destination.parent.mkdir(parents=True, exist_ok=True)
    resolve_profile_root(destination.parent)
    with regular(source).open('rb') as input_file, destination.open('xb') as output:
        shutil.copyfileobj(input_file, output, 1024 * 1024)
    need(identity(destination) == expected and same_bytes(source, destination), 'Copy differs: ' + str(destination))


def write_new(path, value):
    with path.open('x', encoding='utf-8') as file:
        file.write(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qa-run', type=Path, default=QA_DEFAULT)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--smoke', type=Path, required=True, help='Successful smoke_* directory from this release helper')
    parser.add_argument('--upload-root', type=Path, default=UPLOAD_DEFAULT, help='New absolute upload directory; never overwritten')
    args = parser.parse_args()
    need(not LOCK.exists(), 'Shared source/engine lock is still held')
    qa_dir = directory(args.qa_run, ROOT / '.godot/steam_integration_qa')
    candidate_dir = directory(args.candidate, ROOT / '.godot/steam_candidates')
    smoke_dir = directory(args.smoke, HERE)
    need(smoke_dir.parent == HERE and smoke_dir.name.startswith('smoke_'), 'Expected this release helper smoke directory')
    upload = resolve_profile_root(args.upload_root)
    need(not upload.exists(), 'Upload directory already exists; refusing reuse')
    destinations = [(qa_dir, HERE / 'source_qa' / qa_dir.name, ['receipt.json', 'report.json', 'import.log', 'catalog.log', 'contracts.log']),
                    (candidate_dir, HERE / 'candidate' / candidate_dir.name,
                     ['receipt.json', 'verification_report.json', 'package_report.json', 'content_identity_generation.json',
                      'package_script_inputs.json', 'import.log', 'export.log', 'package.log', 'exe_smoke.log'] +
                     [stage + '/' + file for stage in ('source_identity_probe', 'content_identity_probe')
                      for file in ('report.json', 'process_receipt.json', 'report.log')])]
    for _, destination, _ in destinations:
        resolve_profile_root(destination)
        need(not destination.exists(), 'Evidence directory already exists: ' + str(destination))
    for name in ('candidate_delivery.json', 'evidence_copy_manifest.json'):
        need(not (HERE / name).exists() and not (HERE / name).is_symlink(), 'Refusing to overwrite ' + name)
    qa, qa_report = read(qa_dir / 'receipt.json'), read(qa_dir / 'report.json')
    candidate = read(candidate_dir / 'receipt.json')
    verification, package = read(candidate_dir / 'verification_report.json'), read(candidate_dir / 'package_report.json')
    smoke = read(smoke_dir / 'receipt.json')
    need(qa.get('complete') is True and qa.get('native') is True and candidate.get('complete') is True,
         'Native QA/candidate is incomplete')
    need(candidate.get('kind') == 'windows_steam_feature_candidate' and candidate.get('uploaded') is False and
         candidate.get('live_steam_tested') is False, 'Unexpected candidate kind/publication scope')
    qa_checks = passed_checks(qa_report, qa.get('checks'), 'Native QA')
    need(qa_checks == 185, 'Expected this release native QA 185 checks')
    pinned = native_dependencies()
    need(qa.get('native_dependencies') == candidate.get('native_dependencies') == pinned, 'Native provenance mismatch')
    need((ROOT / candidate['qa_run']).resolve() == qa_dir and
         candidate.get('qa_receipt_sha256') == identity(qa_dir / 'receipt.json')['sha256'], 'Candidate is bound to another QA receipt')
    head = qa['source_head']
    need(candidate.get('source_head') == smoke.get('source_head') == head, 'Source HEAD mismatch between runs')
    inventory = current_sources(qa, candidate, head)
    for key, file in [('builder_sha256', 'tools/build_steam_candidate.py'), ('probe_sha256', 'tools/steam_package_probe.gd')]:
        need(candidate.get(key) == identity(ROOT / file)['sha256'], 'Builder/probe source changed')
    need(verification.get('verifier_sha256') == identity(ROOT / 'tools/steam_candidate_verification.py')['sha256'], 'Verifier source changed')
    steps_passed(qa, ['import', 'catalog', 'contracts'], 'Native QA')
    steps_passed(candidate, ['import', 'export', 'package', 'exe_smoke'], 'Candidate')
    steps_passed(verification, ['package', 'exe_smoke'], 'Verifier')
    need(verification.get('complete') is True and candidate.get('verification') == verification and
         candidate.get('identity_probe_exit_unconfirmed') is False, 'Candidate verification incomplete')
    package_checks = passed_checks(package, candidate.get('checks'), 'Package')
    need(verification.get('checks') == package_checks, 'Verifier/package check count mismatch')
    need(package.get('steam_initialized') is False and package.get('steam_write_calls') == 0, 'Package probe unexpectedly initialized/wrote Steam')
    scripts = read(candidate_dir / 'package_script_inputs.json')
    expected_scripts = sorted({row['path'] for row in candidate['source_files'] if row['path'].startswith('scripts/') and row['path'].endswith('.gd')} | {DERIVED})
    script_sha = identity(candidate_dir / 'package_script_inputs.json')['sha256']
    need(scripts == expected_scripts and verification.get('script_count') == len(scripts) == package['scripts']['scripts'] and
         script_sha == verification.get('script_inputs_sha256') == package['scripts']['manifest_sha256'], 'Packaged script inventory mismatch')
    catalog_sha = identity(ROOT / 'assets/localization/catalog.json')['sha256']
    need(catalog_sha == candidate['localization_catalog_sha256'] == package['localization']['catalog_sha256'] == package['localization']['expected_catalog_sha256'],
         'Packaged localization mismatch')
    need(candidate['content_identity'] == read(candidate_dir / 'content_identity_generation.json'), 'Generated identity receipt mismatch')
    zip_path, zip_id, members = verify_zip(candidate_dir, candidate)
    member_map = {row['path']: row for row in members}
    modules = verification.get('modules', [])
    need(type(verification.get('release_pid')) is int and verification['release_pid'] > 0 and
         len(modules) == 3 and {row['ModuleName'] for row in modules} == BINARIES - {EXE}, 'Missing loaded native process/modules')
    for module in modules:
        name = module['ModuleName']
        need(Path(module['FileName']).resolve() == (candidate_dir / 'windows' / name).resolve() and
             module['sha256'] == member_map[name]['sha256'], 'Loaded native module mismatch')
    identity_counts = {name: check_identity(candidate_dir, candidate, name, mode, member_map[EXE]['sha256'])
                       for name, mode in [('source_identity_probe', True), ('content_identity_probe', False)]}
    need(all(smoke.get(key) is True for key in ('complete', 'source_unchanged', 'players_unchanged', 'exe_unchanged', 'child_exit_confirmed', 'lock_released')) and
         smoke.get('exe_sha256') == member_map[EXE]['sha256'] and 'error' not in smoke and 'guard_error' not in smoke, 'Smoke guards failed or wrong EXE')
    cases = smoke.get('cases', [])
    need([row.get('name') for row in cases] == CASE_NAMES, 'Missing/duplicate smoke cases')
    for row in cases:
        name = row['name']
        need(row.get('passed') is True and row.get('child_exit_confirmed') is True and row.get('exit_code') == 0 and
             type(row.get('pid')) is int and row['pid'] > 0 and row.get('errors') == [], 'Smoke case failed: ' + name)
        log = clean_log(smoke_dir / (name + '.console.log'))
        clean_log(smoke_dir / (name + '.godot.log'))
        marker = '[smoke] ' + name if name.startswith('level') else {'defense': '[defense_hard_fix]', 'cleanup': '[final_cleanup]', 'main_menu': ''}[name]
        line = next((line for line in log.splitlines() if marker and marker in line), '')
        need(row.get('marker') == line and (not marker or bool(line)), 'Smoke marker mismatch: ' + name)
        if name in ('defense', 'cleanup'):
            need('ALL=true' in line, 'Smoke assertion failed: ' + name)
    copies = []
    for source_root, destination, whitelist in destinations:
        for name in whitelist:
            source = source_root / relative(name)
            if source.suffix == '.log':
                clean_log(source)
            copies.append({'source': source, 'destination': destination / relative(name), 'identity': identity(source)})
    # The smoke helper already writes into this evidence directory; reference it in place.
    smoke_evidence = []
    for name in ['receipt.json'] + [case + suffix for case in CASE_NAMES for suffix in ('.console.log', '.godot.log')]:
        path = smoke_dir / name
        smoke_evidence.append({'source': path.relative_to(ROOT).as_posix(),
                               'path': path.relative_to(HERE).as_posix(), 'copied': False, **identity(path)})
    need(not LOCK.exists(), 'Engine/source lock became occupied')
    need(str(upload).isascii(), 'Upload path must be absolute ASCII for the browser')
    upload.mkdir(parents=True, exist_ok=False)
    resolve_profile_root(upload)
    upload_zip = upload / zip_path.name
    copy_new(zip_path, upload_zip, zip_id)
    manifest_rows = []
    for row in copies:
        copy_new(row['source'], row['destination'], row['identity'])
        manifest_rows.append({'source': row['source'].relative_to(ROOT).as_posix(),
                              'path': row['destination'].relative_to(HERE).as_posix(), 'copied': True, **row['identity']})
    # Recheck original evidence and production after copying; no raw receipt is rewritten.
    for row in copies:
        need(identity(row['source']) == row['identity'], 'Original evidence changed during collection')
    for row in smoke_evidence:
        matches(identity(HERE / row['path']), row, 'Original smoke evidence')
    need(identity(zip_path) == zip_id and same_bytes(zip_path, upload_zip), 'Archive changed during collection')
    need(native_dependencies() == pinned and current_sources(qa, candidate, head) == inventory and not LOCK.exists(), 'Source/native/lock changed during collection')
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    delivery = {'schema': 1, 'complete': True, 'scope': 'local_candidate_preparation_only', 'created_at_utc': timestamp,
                'app_id': 5088120, 'depot_id': 5088121, 'candidate': candidate_dir.name, 'source_head': head,
                'qa_run': qa_dir.relative_to(ROOT).as_posix(), 'smoke_run': smoke_dir.relative_to(ROOT).as_posix(),
                'archive': {'path': zip_path.name, 'source': zip_path.relative_to(ROOT).as_posix(), 'upload_copy': str(upload_zip), **zip_id},
                'members': members, 'member_count': 6, 'verified_against_candidate_receipt': True,
                'upload_copy_byte_identical': True, 'checks': {'native_qa': qa_checks, 'package': package_checks,
                **identity_counts, 'actual_exe_smoke_cases': 11}, **inventory,
                'uploaded': False, 'server_verified': False, 'default_active': False, 'live_steam_tested': False,
                'limits': ['Local offline preparation only; no Steam upload or branch activation.',
                           'Eleven EXE smoke cases cover startup/assertions, not full campaign completion or menu interaction.',
                           'Identity probes do not claim full battle resume or release process testing.']}
    write_new(HERE / 'candidate_delivery.json', delivery)
    manifest = {'schema': 1, 'complete': True, 'created_at_utc': timestamp, 'source_head': head,
                'collector_sha256': identity(Path(__file__))['sha256'], 'files': manifest_rows + smoke_evidence,
                'file_count': len(manifest_rows) + len(smoke_evidence), 'copied_file_count': len(manifest_rows),
                'smoke_reference_file_count': len(smoke_evidence),
                'candidate_delivery': identity(HERE / 'candidate_delivery.json'), 'original_evidence_unchanged': True,
                'copy_policy': 'Exact named JSON/log files only; no player inventories, identity manifests, profiles, project caches or packaged binaries.',
                'upload_zip': {'path': str(upload_zip), **zip_id}, 'uploaded': False, 'default_active': False}
    write_new(HERE / 'evidence_copy_manifest.json', manifest)
    print(json.dumps({'complete': True, 'scope': delivery['scope'], 'evidence_files': len(manifest_rows),
                      'smoke_files_referenced': len(smoke_evidence),
                      'delivery': str(HERE / 'candidate_delivery.json'), 'upload_zip': str(upload_zip),
                      'uploaded': False, 'default_active': False}, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'complete': False, 'error': type(error).__name__ + ': ' + str(error)}, ensure_ascii=False), file=sys.stderr)
        sys.exit(1)
