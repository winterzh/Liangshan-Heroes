"""Frozen gameplay RNG QA: default read-only preflight; --run owns writer then reader."""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import types

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SELF = Path(__file__).resolve()
LOCK = ROOT / '.godot/redraw_rejection_source.lock'
PINS_SHA = 'b4ebb9ff07b39249410d069420d3a27849adf9ca102670e642f4c76e1fe809d4'
CONTRACT_SHA = '66c678c8e5e06e34f74b55dccf89e40a59d2cb67373bad19327641d94e020012'
ENGINE_SHA = 'ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00'
HELPER = ROOT / 'scratchpad/separation_sections_diag/frozen/process_safety.py'
HELPER_SHA = '7983b00449f8d606e4f1be55ca13596239fbc8b47c3894ff3c31da03757835a1'
GUARD = ROOT / 'tools/run_reduced_effects_qa.py'
GUARD_SHA = '1cecf1c3e6bb7c15992e6955fcad67e959cf836a198e9ceca28d744a1a573c0c'
PROJECT_NAME = 'Gameplay RNG QA'
PROJECT = b'config_version=5\n\n[application]\nconfig/name="Gameplay RNG QA"\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
ERROR = re.compile(r'SCRIPT ERROR|^\s*ERROR:|^\s*WARNING:|\bFAIL\b|Unicode parsing error|Parse Error|Parser Error', re.M | re.I)
MAX_JSON = 1048576


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def no_links(path):
    for item in [path] + list(path.parents):
        if item.exists() or item.is_symlink():
            stat = item.lstat()
            need(not item.is_symlink() and not getattr(stat, 'st_file_attributes', 0) & 0x400,
                 'Link/reparse path refused: ' + str(item))


def file_sha(path):
    no_links(path)
    with path.open('rb') as file:
        value = hashlib.sha256()
        for block in iter(lambda: file.read(1048576), b''):
            value.update(block)
    return value.hexdigest()


def json_value(raw):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            need(key not in result, 'Duplicate JSON key: ' + key)
            result[key] = value
        return result
    def invalid_constant(value):
        raise RuntimeError('Non-finite JSON constant: ' + value)
    need(0 < len(raw) <= MAX_JSON, 'Empty/oversized JSON')
    return json.loads(raw.decode('utf-8'), object_pairs_hook=unique, parse_constant=invalid_constant)


def read(path):
    no_links(path)
    return json_value(path.read_bytes())


def save(path, value):
    no_links(path)
    with path.open('xb') as file:
        file.write((json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))


def load_helper(path, expected, name):
    need(file_sha(path) == expected, 'Frozen helper drift: ' + str(path))
    raw = path.read_bytes()
    need(digest(raw) == expected, 'Helper changed while reading')
    module = types.ModuleType(name)
    module.__file__ = str(path)
    exec(compile(raw.decode('utf-8-sig'), str(path), 'exec'), module.__dict__)
    return module


def frozen(self_sha):
    need(file_sha(SELF) == self_sha, 'Runner changed during execution')
    need(file_sha(HERE / 'pins.json') == PINS_SHA, 'Frozen RNG pins drift')
    need(file_sha(HERE / 'qa_contract.json') == CONTRACT_SHA, 'Frozen QA contract drift')
    need(file_sha(HELPER) == HELPER_SHA and file_sha(GUARD) == GUARD_SHA, 'Helper source drift')
    pins = read(HERE / 'pins.json')
    for row in pins['runtime_sources'] + pins['supporting_files']:
        path = ROOT / row['path']
        need(not Path(row['path']).is_absolute() and ROOT in path.resolve().parents, 'Pin path escaped checkout')
        need(path.stat().st_size == row['bytes'] and file_sha(path) == row['raw_sha256'], 'Frozen source drift: ' + row['path'])
    return {row['path']: row['raw_sha256'] for row in pins['runtime_sources']}


def tree(directory, skip_cache=False):
    """Exact small profile/private-project enumeration; inaccessible paths fail closed."""
    no_links(directory)
    if not directory.exists():
        return {'exists': False, 'directories': [], 'files': {}}
    need(directory.is_dir(), 'Expected directory: ' + str(directory))
    def listing():
        files, folders = [], []
        def failed(error):
            raise error
        for parent, dirs, names in os.walk(directory, onerror=failed, followlinks=False):
            for name in dirs + names:
                no_links(Path(parent) / name)
            if skip_cache and Path(parent) == directory and '.godot' in dirs:
                dirs.remove('.godot')
            folders.append(Path(parent).relative_to(directory).as_posix())
            files.extend((Path(parent) / name).relative_to(directory).as_posix() for name in names)
        return sorted(files), sorted(folders)
    files, folders = listing()
    hashes = {name: file_sha(directory / name) for name in files}
    need(listing() == (files, folders), 'Path set changed while hashing: ' + str(directory))
    return {'exists': True, 'directories': folders, 'files': hashes}


def private_sources(project, expected):
    snapshot = tree(project, skip_cache=True)
    hashes = snapshot['files']
    need(all(hashes.get(name) == value for name, value in expected.items()), 'Private runtime bytes changed')
    extras = set(hashes) - set(expected)
    allowed_uids = {name + '.uid' for name in expected if name.endswith('.gd')}
    need(extras <= allowed_uids, 'Unexpected private source files: ' + str(sorted(extras - allowed_uids)))
    for name in extras:
        need(re.fullmatch(rb'uid://[a-z0-9]{1,32}\r?\n?', (project / name).read_bytes()) is not None,
             'Unexpected generated UID syntax: ' + name)
    return snapshot


def validate(report, manifest, manifest_sha, process, contract):
    need(isinstance(report, dict), 'Report is not an object')
    for key, expected in [('suite', 'gameplay-rng'), ('stage', manifest['stage']), ('run_id', manifest['run_id']),
                          ('manifest_sha256', manifest_sha), ('engine_binary_sha256', ENGINE_SHA)]:
        need(report.get(key) == expected, 'Report identity mismatch: ' + key)
    need(type(report.get('process_id')) is int and report['process_id'] == process['child_pid'], 'Report actual PID mismatch')
    need(isinstance(report.get('actual_user_dir'), str) and Path(report['actual_user_dir']).resolve() == Path(manifest['private_user']).resolve(), 'Wrong actual user://')
    need(report.get('source_sha256') == manifest['source_sha256'] == report.get('source_after_sha256'), 'Runtime source identity mismatch')
    need(set(contract['required_identity']) <= set(report), 'Missing report identity fields')
    for field in contract['required_true_report_fields']:
        need(report.get(field) is True, 'Missing successful result: ' + field)
    for field in contract['required_false_report_fields']:
        need(report.get(field) is False, 'Unsupported scope claim: ' + field)
    need(report.get('independent_process_continuation_tested') is contract['independent_process_continuation_tested'][manifest['stage']], 'Wrong cross-process scope')
    checks = report.get('checks')
    need(isinstance(checks, list) and 0 < len(checks) <= 5000 and report.get('failures') == [], 'Missing/failed checks')
    need(all(isinstance(row, dict) and row.get('passed') is True and isinstance(row.get('label'), str) and row['label']
             and row.get('group') in contract['allowed_check_groups'] for row in checks), 'Invalid or failed check row')
    need(type(report.get('check_count')) is int and report['check_count'] == len(checks), 'Check count mismatch')
    groups = dict(Counter(row['group'] for row in checks))
    need(report.get('check_groups') == groups and all(type(value) is int for value in report['check_groups'].values()), 'Check group mismatch')
    need(groups.get('source') == contract['expected_completed_source_groups'][manifest['stage']], 'Source group count mismatch')
    labels = Counter(row['label'] for row in checks)
    required = contract['required_common_labels_once'] + contract['required_' + manifest['stage'] + '_labels_once']
    required += [prefix + str(index) for prefix in contract['required_seven_indexed_labels'][manifest['stage']]
                 for index in contract['indexed_label_suffixes']]
    required += [prefix + name for prefix in ['source before ', 'source after '] for name in manifest['source_sha256']]
    for label in required:
        need(labels[label] == 1, 'Required check missing/duplicated: ' + label)
    engine = report.get('engine', {})
    need(all(type(engine.get(key)) is int for key in ['major', 'minor', 'patch'])
         and [engine[key] for key in ['major', 'minor', 'patch']] == [4, 6, 3]
         and isinstance(engine.get('hash'), str) and engine['hash'], 'Unexpected engine version identity')
    need(isinstance(report.get('handoff_sha256'), str) and re.fullmatch('[0-9a-f]{64}', report['handoff_sha256']), 'Missing handoff SHA')
    return {'check_count': len(checks), 'check_groups': groups, 'source_hash_checks': 6, 'other_checks': len(checks) - 6}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--godot', required=True)
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    need(30 <= args.timeout <= 240, 'Per-stage timeout must be 30..240 seconds')
    self_sha = file_sha(SELF)
    runtime = frozen(self_sha)
    contract = read(HERE / 'qa_contract.json')
    need(set(runtime) == set(contract['manifest_source_paths']), 'Runtime/contract source set mismatch')
    exe = Path(args.godot).resolve()
    need(exe.suffix.lower() == '.exe' and exe.name.lower().startswith('godot')
         and not re.search(r'[._-]console\.exe$', exe.name, re.I), 'Actual non-console Godot exe required')
    need(file_sha(exe) == ENGINE_SHA, 'Unexpected Godot executable SHA')
    if not args.run:
        print(json.dumps({'preflight': True, 'runtime_sources': runtime, 'runner_sha256': self_sha,
                          'engine_sha256': ENGINE_SHA, 'godot_run': False, 'writes': False}))
        return 0
    safety = load_helper(HELPER, HELPER_SHA, 'rng_process_safety')
    guard = load_helper(GUARD, GUARD_SHA, 'rng_source_guard')
    safety.require_exclusive_godot()
    no_links(LOCK)
    need(not LOCK.exists(), 'Shared Godot lock occupied')
    appdata = Path(os.environ['APPDATA']).resolve()
    real_users = {'production': appdata / 'Godot/app_userdata' / guard.project_name(ROOT),
                  'qa_name_in_real_appdata': appdata / 'Godot/app_userdata' / PROJECT_NAME}
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = HERE / 'runs' / stamp
    no_links(out)
    out.mkdir(parents=True, exist_ok=False)
    token = str(os.getpid()) + '|' + str(out)
    LOCK.parent.mkdir(exist_ok=True)
    with LOCK.open('x', encoding='utf-8') as file:
        file.write(token)
    result = {'schema': 1, 'suite': 'gameplay-rng', 'complete': False, 'lock_released': False,
              'godot_run': False, 'runner_sha256': self_sha, 'pins_sha256': PINS_SHA, 'qa_contract_sha256': CONTRACT_SHA,
              'engine_sha256': ENGINE_SHA, 'process_safety_sha256': HELPER_SHA, 'source_guard_sha256': GUARD_SHA,
              'stages': {}, 'battle_resume_tested': False, 'production_rng_migrated': False, 'restore_ready': False}
    source = None
    protected = None
    attempts = []
    project = out / 'project'
    expected = dict(runtime, **{'project.godot': digest(PROJECT)})
    try:
        safety.require_exclusive_godot()
        frozen(self_sha)
        source = guard.source_receipt(ROOT)
        protected = {name: tree(path) for name, path in real_users.items()}
        save(out / 'sources_before.json', source)
        save(out / 'players_before.json', protected)
        project.mkdir()
        for name, value in runtime.items():
            raw = (ROOT / name).read_bytes()
            need(digest(raw) == value, 'Source drift during private copy')
            destination = project / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
        (project / 'project.godot').write_bytes(PROJECT)
        save(out / 'private_sources_before.json', private_sources(project, expected))
        safety.ROOT = project
        safety.ERROR = ERROR
        original_idle = safety.require_exclusive_godot
        def before_launch_or_after_exit():
            original_idle()
            need(LOCK.read_text(encoding='utf-8') == token, 'Shared lock ownership changed')
            frozen(self_sha)
            private_sources(project, expected)
            need({name: tree(path) for name, path in real_users.items()} == protected, 'Real player profile changed')
        # The reviewed helper invokes this immediately before its actual Popen, and after confirmed exit.
        safety.require_exclusive_godot = before_launch_or_after_exit
        writer = None
        writer_private = None
        handoff_sha = ''
        writer_sha = ''
        for stage in ['writer', 'reader']:
            need(guard.source_receipt(ROOT) == source and file_sha(exe) == ENGINE_SHA, 'Source/engine drift before stage')
            if stage == 'reader':
                need(writer is not None and result['stages']['writer']['child_exit_confirmed'], 'Writer must finish before reader')
                need(file_sha(out / 'handoff.json') == handoff_sha and file_sha(out / 'writer_report.json') == writer_sha, 'Writer artifact drift')
                need(private_sources(project, expected) == writer_private, 'Private sources changed between stages')
            profile = out / 'private_profile' / stage
            user = profile / 'appdata/Godot/app_userdata' / PROJECT_NAME
            user.mkdir(parents=True, exist_ok=False)
            (profile / 'localappdata').mkdir()
            (profile / 'temp').mkdir()
            report_path = out / (stage + '_report.json')
            manifest = {'run_id': stamp, 'run_dir': str(out), 'stage': stage, 'private_user': str(user),
                        'report': str(report_path), 'source_sha256': runtime, 'engine_binary_sha256': ENGINE_SHA,
                        'handoff_sha256': handoff_sha, 'writer_report_sha256': writer_sha}
            manifest_path = out / (stage + '_manifest.json')
            save(manifest_path, manifest)
            manifest_sha = file_sha(manifest_path)
            env = os.environ.copy()
            for key in list(env):
                if key.startswith(('GODOT_', 'GAMEPLAY_RNG_', 'POLISH_', 'PERF_', 'UNIT_ADAPTER_', 'UNIT_REFERENCES_',
                                   'INVENTORY_QA_', 'BATTLE_FOG_QA_', 'VALUE_CODEC_', 'STORE_QA_', 'FIRST_USE_',
                                   'REDRAW_', 'REDUCED_EFFECTS_', 'SEPARATION_', 'CHASE_PATH_', 'ANIM_LOAD_')):
                    env.pop(key)
            env.update(APPDATA=str(profile / 'appdata'), LOCALAPPDATA=str(profile / 'localappdata'),
                       TEMP=str(profile / 'temp'), TMP=str(profile / 'temp'), GAMEPLAY_RNG_QA_MANIFEST=str(manifest_path))
            save(out / (stage + '_environment.json'), {key: env[key] for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP', 'GAMEPLAY_RNG_QA_MANIFEST']})
            before_launch_or_after_exit()
            attempts.append(stage)
            safety.run_godot(str(exe), project / contract['entry'].removeprefix('res://'), report_path,
                             env, args.timeout, headless=True, validity_key='passed')
            process = read(out / (stage + '_report_process.json'))
            need(process.get('child_started') is True and process.get('child_exit_confirmed') is True
                 and type(process.get('child_pid')) is int and process['exit_code'] == 0
                 and process.get('exception') is None and process.get('cleanup_error') is None, 'Exact child lifecycle failed')
            result['godot_run'] = True
            need(file_sha(manifest_path) == manifest_sha, 'Manifest changed during stage')
            log_path = out / (stage + '_report.log')
            need(log_path.stat().st_size <= 16 * 1048576, 'Unexpected log size')
            log_raw = log_path.read_bytes()
            log = log_raw.decode('utf-8')
            need(not ERROR.search(log), 'Strict engine diagnostics rejected')
            report = read(report_path)
            markers = [line[len(contract['stdout_report_prefix']):] for line in log.splitlines() if line.startswith(contract['stdout_report_prefix'])]
            need(len(markers) == 1 and json_value(markers[0].encode('utf-8')) == report, 'Sole stdout JSON differs from sidecar')
            counts = validate(report, manifest, manifest_sha, process, contract)
            need(report['handoff_sha256'] == file_sha(out / 'handoff.json'), 'Handoff file differs from report')
            if stage == 'writer':
                writer = report
                handoff_sha = file_sha(out / 'handoff.json')
                writer_sha = file_sha(report_path)
                need(isinstance(read(out / 'handoff.json'), dict), 'Writer handoff is not a JSON tree')
                writer_private = private_sources(project, expected)
                save(out / 'private_sources_after_writer.json', writer_private)
            else:
                need(report['process_id'] != writer['process_id'] and report['engine'] == writer['engine'], 'Distinct process/same engine contract failed')
                need(file_sha(out / 'handoff.json') == handoff_sha and file_sha(out / 'writer_report.json') == writer_sha, 'Reader changed writer inputs')
                need(private_sources(project, expected) == writer_private, 'Reader changed private source or generated UID bytes')
            result['stages'][stage] = dict(counts, child_pid=process['child_pid'], child_exit_confirmed=True,
                                          exit_code=process['exit_code'], report_sha256=file_sha(report_path),
                                          manifest_sha256=manifest_sha, log_sha256=digest(log_raw))
            save(out / (stage + '_validated.json'), result['stages'][stage])
        result.update(complete=True, handoff_sha256=handoff_sha, writer_report_sha256=writer_sha,
                      independent_process_continuation_tested=True)
    except BaseException as error:
        result.update(complete=False, error=type(error).__name__ + ': ' + str(error))
    finally:
        try:
            # Preserve the helper's original process receipts, including unsuccessful attempts.
            for stage in attempts:
                process = read(out / (stage + '_report_process.json'))
                result['godot_run'] = result['godot_run'] or process.get('child_started') is True
                need(process.get('child_started') is False or process.get('child_exit_confirmed') is True, 'Unconfirmed owned child; retain lock')
            safety.require_exclusive_godot()
            frozen(self_sha)
            need(file_sha(exe) == ENGINE_SHA, 'Engine changed during run; retain lock')
            after = guard.source_receipt(ROOT)
            player_after = {name: tree(path) for name, path in real_users.items()}
            need(source is not None and after == source, 'Production source changed; retain lock')
            need(protected is not None and player_after == protected, 'Real player files changed; retain lock')
            save(out / 'sources_after.json', after)
            save(out / 'players_after.json', player_after)
            save(out / 'private_sources_after.json', private_sources(project, expected))
            need(LOCK.read_text(encoding='utf-8') == token, 'Lock ownership changed; retain lock')
            result.update(source_unchanged=True, player_unchanged=True, source_files=len(after['raw_file_sha256']))
            LOCK.unlink()
            result['lock_released'] = True
        except BaseException as error:
            result.update(complete=False, final_guard_error=type(error).__name__ + ': ' + str(error))
        save(out / 'receipt.json', result)
        print(json.dumps({'run': str(out), 'complete': result['complete'], 'godot_run': result['godot_run'], 'lock_released': result['lock_released']}))
    return 0 if result['complete'] and result['lock_released'] else 2


if __name__ == '__main__':
    sys.exit(main())
