"""One explicit native rendered 10-second entry, in an already prepared mirror only.

No source checkout writes, no Git, no automatic copies/rebases/repetitions.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
from prepare import HERE, ROOT, ROOTS, TOOLS, regular, require, save, sha
from private_import import executable, load_entry_pins, source_manifest


def mirror_sources(mirror, receipt):
    if receipt.get('needs_reimport'):
        completed = receipt.get('private_import_completion', {})
        require(not receipt.get('private_import_required_before_diagnostic', True) and completed.get('complete') is True
                and completed.get('owned_child_exit_confirmed') is True and completed.get('exit_code') == 0
                and completed.get('engine_errors') is False and completed.get('plan_sha256') == receipt['plan_sha256'],
                'Private headless import and cache freeze not completed; diagnostic entry remains blocked')
        pinned_cache = {row['path'] for row in receipt['import_cache_files']}
        for item in receipt['needs_reimport']:
            require(set(item['destinations'] + item['md5_sidecars']) <= pinned_cache, 'Reimported outputs lack frozen cache hashes: ' + item['source'])
            for name in item['md5_sidecars']:
                path = mirror / name; regular(path, mirror)
                match = re.search(r'^source_md5="([0-9a-f]{32})"', path.read_text(encoding='utf-8-sig'), re.M)
                require(match is not None and match.group(1) == item['expected']['md5'], 'Reimport cache does not match frozen raw source: ' + name)
    expected = receipt['source_files']
    observed = {}
    manifest = source_manifest(mirror)
    require(manifest['source_files'] == expected, 'Mirror source path set/bytes changed')
    if 'source_directories' in receipt:
        require(manifest['directories'] == receipt['source_directories'], 'Mirror source directory set changed')
    for name, row in expected.items():
        path = mirror / name
        regular(path, mirror)
        raw = path.read_bytes()
        require(len(raw) == row['bytes'] and sha(raw) == row['sha256'], 'Mirror source bytes changed: ' + name)
        observed[name] = row
    for row in receipt['import_cache_files']:
        path = mirror / row['path']; regular(path, mirror)
        require(sha(path.read_bytes()) == row['sha256'], 'Copied import artifact changed: ' + row['path'])
    derived = receipt.get('derived_cache_files', [])
    require([row['path'] for row in derived] == ['.godot/global_script_class_cache.cfg'], 'Required derived class cache pin absent')
    for row in derived:
        path = mirror / row['path']; regular(path, mirror)
        raw = path.read_bytes()
        require(len(raw) == row['bytes'] and sha(raw) == row['sha256'], 'Derived class cache changed: ' + row['path'])
        observed[row['path']] = row
    return sha(json.dumps(observed, sort_keys=True).encode())


def godot_process_ids():
    code = "@(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.Name -like '*Godot*.exe' } | ForEach-Object { [int]$_.ProcessId }) | ConvertTo-Json -Compress"
    raw = subprocess.check_output(['powershell', '-NoProfile', '-Command', code], text=True, timeout=20).strip()
    if not raw: return []
    value = json.loads(raw)
    return value if isinstance(value, list) else [value]


def environment(mirror, run, mode):
    env = os.environ.copy()
    exact = set()
    for path in (mirror / 'scripts').rglob('*.gd'):
        exact.update(re.findall(r'OS\.(?:get_environment|has_environment)\(\s*["\']([A-Z0-9_]+)["\']', path.read_text(encoding='utf-8-sig')))
    for key in list(env):
        if key in exact or key.startswith(('PERF_', 'POLISH_', 'DEF_', 'RTS_TEST_', 'YF_', 'FIRST_USE_')):
            env.pop(key)
    profile = run / 'profile'
    for key, leaf in [('APPDATA', 'roaming'), ('LOCALAPPDATA', 'local')]:
        folder = profile / leaf; folder.mkdir(parents=True, exist_ok=True)
        env[key] = str(folder)
    env.update({'CAMPAIGN_QA': '1', 'POLISH_CASE': 'defense200', 'POLISH_CAMERA': 'fixed',
                'POLISH_SECONDS': '10', 'POLISH_OUT': str(run / 'report.json'),
                'FIRST_USE_MODE': mode, 'FIRST_USE_PROFILE_ROOT': str(profile)})
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mirror', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--mode', choices=('timed', 'clockless'), default='timed')
    parser.add_argument('--timeout-seconds', type=int, default=180)
    args = parser.parse_args()
    require(os.name == 'nt', 'Profile isolation verified for Windows; no fallback on other OS')
    mirror = args.mirror.resolve()
    require(mirror.is_relative_to(HERE.resolve()) and mirror.name.startswith('mirror_'), 'Only isolated draft mirror paths are accepted')
    regular(mirror / '_first_use/materialization_receipt.json', HERE)
    receipt = json.loads((mirror / '_first_use/materialization_receipt.json').read_text(encoding='utf-8'))
    require(receipt.get('complete') and Path(receipt['mirror']).resolve() == mirror, 'Incomplete or moved mirror')
    receipt = load_entry_pins(mirror, receipt)
    exe = executable(args.godot)
    require(30 <= args.timeout_seconds <= 600, 'Bounded timeout required')
    lock = ROOT / '.godot/redraw_rejection_source.lock'
    require(not lock.exists(), 'Shared Godot/source slot occupied; wait for exclusive handoff')
    require(not godot_process_ids(), 'Another Godot process exists; wait for exclusive handoff')
    before = mirror_sources(mirror, receipt)
    marker = mirror / '_first_use/run_once.json'
    require(not marker.exists(), 'Mirror already used; materialize a fresh instance for every entry/control')
    run = HERE / 'runs' / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ') + '_' + args.mode)
    lock_token = str(os.getpid()) + '|' + str(run)
    descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    os.write(descriptor, lock_token.encode()); os.close(descriptor)
    result = {'schema': 1, 'snapshot': receipt['snapshot'], 'mode': args.mode, 'mirror': str(mirror),
              'source_before': before, 'production_mutated': False, 'requested_seconds': 10,
              'native_profile_copied': False, 'repeats': 1, 'performance_acceptance': False}
    child = None
    exited = False
    try:
        run.mkdir(parents=True)
        save(marker, {'run': str(run), 'mode': args.mode})
        env = environment(mirror, run, args.mode)
        argv = [str(exe), '--path', str(mirror), '--rendering-method', 'forward_plus',
                '--rendering-driver', 'vulkan', '--resolution', '1440x900', '--disable-vsync',
                '--script', 'res://_first_use/driver.gd', '--log-file', str(run / 'engine.log')]
        # Do not serialize the inherited environment or local executable path.
        save(run / 'running_receipt.json', result)
        with (run / 'process.log').open('wb') as log:
            require(lock.is_file() and lock.read_text(encoding='utf-8') == lock_token, 'Shared lock ownership changed before Popen')
            require(not godot_process_ids(), 'Another Godot appeared before Popen; do not launch')
            child = subprocess.Popen(argv, cwd=mirror, env=env, stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            result['pid'] = child.pid
            try:
                result['exit_code'] = child.wait(timeout=args.timeout_seconds)
                exited = True
            except BaseException:
                child.kill()
                result['exit_code'] = child.wait(timeout=30)
                exited = child.poll() is not None
                raise
        result['source_after'] = mirror_sources(mirror, receipt)
        result['source_unchanged'] = result['source_before'] == result['source_after']
        log_text = (run / 'process.log').read_text(encoding='utf-8', errors='replace')
        if (run / 'engine.log').exists():
            log_text += '\n' + (run / 'engine.log').read_text(encoding='utf-8', errors='replace')
        result['engine_errors'] = bool(re.search(r'SCRIPT ERROR|^ERROR:|\bFAIL\b', log_text, re.M))
        report_path = run / 'report.json'
        report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
        result['integrity_passed'] = bool(report.get('integrity_passed'))
        result['sample_complete'] = bool(report.get('sample_complete'))
        result['first_use_valid'] = bool(report.get('first_use', {}).get('valid'))
        result['passed'] = result.get('exit_code') == 0 and not result['engine_errors'] and result['source_unchanged'] and result['integrity_passed'] and result['sample_complete'] and result['first_use_valid']
    except BaseException as error:
        result['passed'] = False
        result['error_type'] = type(error).__name__
        result['error'] = str(error)
    finally:
        try:
            exited = child is None or child.poll() is not None
        except BaseException as error:
            exited = False
            result['owned_child_poll_error'] = type(error).__name__
        result['owned_child_exit_confirmed'] = exited
        try:
            result['remaining_godot_pids'] = godot_process_ids()
            no_godot = not result['remaining_godot_pids']
        except BaseException as error:
            no_godot = False
            result['process_scan_error'] = type(error).__name__
        if not exited or not no_godot: result['passed'] = False
        try:
            result['source_after'] = mirror_sources(mirror, receipt)
            result['source_unchanged'] = result['source_after'] == before
        except BaseException as error:
            result['source_unchanged'] = False
            result['source_verification_error'] = str(error)
        if not result['source_unchanged']: result['passed'] = False
        owned_lock = lock.is_file() and lock.read_text(encoding='utf-8') == lock_token
        result['lock_preserved'] = not (exited and no_godot and owned_lock)
        if not owned_lock: result['passed'] = False
        result['artifacts_preserved'] = True
        run.mkdir(parents=True, exist_ok=True)
        save(run / 'completion_receipt.json', result)
        if not result['lock_preserved']: lock.unlink()
    print(json.dumps({'run': str(run), 'passed': result.get('passed', False), 'lock_preserved': result['lock_preserved']}, ensure_ascii=True))
    return 0 if result.get('passed') else 1


if __name__ == '__main__': sys.exit(main())
