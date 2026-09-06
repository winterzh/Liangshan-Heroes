"""Read-only preflight by default. --run exports one private PCK, then owns writer/reader."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import types

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SELF = Path(__file__).resolve()
BASE = ROOT / 'scratchpad/run_gameplay_rng_r1/run_qa.py'
BASE_SHA = '8f9c82100bf8b635abd74f9a79b31335e72df404f30c62f3f490458af3e0e1ad'
PINS_SHA = 'f7a4f9269df1711bbf6375cbadb311677b5f631969c218566f29b9d8b5ea2f68'
PROJECT_NAME = 'Gameplay RNG Runtime PCK QA'
CONTENT_VERSION = 'rng-runtime-fixture-v1'
PREFIX = '[gameplay-rng-runtime-pck QA] '
MAPPING = {
    'scripts/run_state_value_codec.gd': 'scripts/run_state_value_codec.gd',
    'scratchpad/run_gameplay_rng_runtime/gameplay_rng.gd': 'scratchpad/run_gameplay_rng_runtime/gameplay_rng.gd',
    'scratchpad/run_gameplay_rng_runtime/pck_driver_r1.gd': 'pck_driver.gd',
    'scratchpad/run_gameplay_rng_runtime/pck_project.godot': 'project.godot',
    'scratchpad/run_gameplay_rng_runtime/pck_main.tscn': 'main.tscn',
    'scratchpad/run_gameplay_rng_runtime/pck_export_presets.cfg': 'export_presets.cfg',
}


def base():
    raw = BASE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASE_SHA:
        raise RuntimeError('Reviewed common lifecycle helpers changed')
    result = types.ModuleType('frozen_rng_common')
    result.__file__ = str(BASE)
    exec(compile(raw.decode('utf-8-sig'), str(BASE), 'exec'), result.__dict__)
    result.no_links(BASE)
    return result


def frozen(b, self_sha):
    b.need(b.file_sha(SELF) == self_sha and b.file_sha(BASE) == BASE_SHA, 'Runner/helper drift')
    b.need(b.file_sha(HERE / 'pins_pck_r1.json') == PINS_SHA, 'Runtime pins drift')
    pins = b.read(HERE / 'pins_pck_r1.json')
    rows = pins['runtime_sources'] + pins['supporting_files']
    for row in rows:
        path = ROOT / row['path']
        b.need(not Path(row['path']).is_absolute() and ROOT in path.resolve().parents, 'Pin escaped checkout')
        b.need(path.stat().st_size == row['bytes'] and b.file_sha(path) == row['raw_sha256'], 'Pinned source drift: ' + row['path'])
    entries = {row['path']: row['raw_sha256'] for row in rows}
    b.need(set(MAPPING) <= set(entries), 'PCK copy not covered by pins')
    return {destination: entries[source] for source, destination in MAPPING.items()}


def command(b, safety, argv, output, env, timeout):
    """Same owned-Popen/interrupt/final poll boundary as frozen process_safety.run_godot.

    Only command construction and report parsing are outside that existing lifecycle;
    export has no GD report. Every stage still leaves its real handle receipt and log.
    """
    safety.require_exclusive_godot()
    process = None
    code, failure, cleanup_error = None, None, None
    confirmed = False
    began = time.monotonic()
    with output.with_suffix('.log').open('xb') as log:
        try:
            process = subprocess.Popen(argv, cwd=output.parent, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            safety.ACTIVE_GODOT_PROCESS = process
            while process.poll() is None:
                # A partial UTF8 code point may span writes; final decoding stays strict.
                partial = output.with_suffix('.log').read_bytes()
                b.need(len(partial) <= 16 * 1048576, 'Oversized engine log')
                if b.ERROR.search(partial.decode('utf-8', errors='ignore')):
                    raise RuntimeError('Owned Godot emitted a strict error; stop this exact child')
                if time.monotonic() - began >= timeout:
                    raise subprocess.TimeoutExpired(argv, timeout)
                time.sleep(0.1)
            code = process.returncode
        except BaseException as error:
            failure = error
            if process is not None:
                try:
                    if process.poll() is None:
                        process.kill()
                    code = process.wait(timeout=safety.CHILD_EXIT_TIMEOUT)
                except BaseException as stop_error:
                    cleanup_error = type(stop_error).__name__ + ': ' + str(stop_error)
        finally:
            if process is not None:
                try:
                    final_code = process.poll()
                    confirmed = final_code is not None
                    if confirmed:
                        code = final_code
                        safety.ACTIVE_GODOT_PROCESS = None
                except BaseException as poll_error:
                    cleanup_error = type(poll_error).__name__ + ': ' + str(poll_error)
    receipt = {'command': argv, 'child_pid': process.pid if process is not None else None,
               'child_started': process is not None, 'child_exit_confirmed': confirmed,
               'exit_code': code, 'exception': type(failure).__name__ + ': ' + str(failure) if failure else None,
               'cleanup_error': cleanup_error, 'timed_out': isinstance(failure, subprocess.TimeoutExpired),
               'wall_seconds': time.monotonic() - began}
    b.save(output, receipt)
    if failure is not None:
        raise failure
    b.need(confirmed and cleanup_error is None, 'Child exit is not confirmed; retain lock')
    safety.require_exclusive_godot()
    raw = output.with_suffix('.log').read_bytes()
    b.need(len(raw) <= 16 * 1048576, 'Oversized engine log')
    console = raw.decode('utf-8')
    b.need(code == 0 and not b.ERROR.search(console), 'Strict actual-engine stage failure')
    return receipt, console


def validate(b, report, manifest, process, console):
    for key, expected in [('suite', 'gameplay-rng-runtime-pck'), ('stage', manifest['stage']),
                          ('run_id', manifest['run_id']), ('engine_binary_sha256', b.ENGINE_SHA),
                          ('pack_sha256', manifest['pack_sha256']), ('content_version', CONTENT_VERSION)]:
        b.need(report.get(key) == expected, 'PCK report identity mismatch: ' + key)
    b.need(type(report.get('process_id')) is int and report['process_id'] == process['child_pid'], 'Actual PCK child PID mismatch')
    b.need(Path(report['actual_user_dir']).resolve() == Path(manifest['private_user']).resolve(), 'Private PCK user path mismatch')
    b.need(report.get('passed') is True and report.get('complete') is True and report.get('failures') == [], 'PCK report did not complete')
    b.need(report.get('production_rng_migrated') is False and report.get('battle_resume_tested') is False, 'Overstated PCK scope')
    rows = report.get('checks', [])
    expected_count = 24 if manifest['stage'] == 'writer' else 33
    b.need(len(rows) == expected_count and report.get('check_count') == expected_count, 'PCK matrix count mismatch')
    b.need(all(type(row.get('passed')) is bool and row['passed'] is True and isinstance(row.get('label'), str) for row in rows), 'Failed PCK check')
    b.need(len(set(row['label'] for row in rows)) == expected_count, 'Duplicate PCK check label')
    markers = [line[len(PREFIX):] for line in console.splitlines() if line.startswith(PREFIX)]
    b.need(len(markers) == 1 and b.json_value(markers[0].encode()) == report, 'PCK stdout/report mismatch')
    version = report.get('engine', {})
    b.need([version.get(name) for name in ['major', 'minor', 'patch']] == [4, 6, 3] and version.get('hash'), 'PCK engine version absent')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--godot', required=True)
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args()
    b = base()
    b.need(30 <= args.timeout <= 240, 'Per-stage timeout must be 30..240 seconds')
    self_sha = b.file_sha(SELF)
    expected = frozen(b, self_sha)
    exe = Path(args.godot).resolve()
    b.need(exe.suffix.lower() == '.exe' and exe.name.lower().startswith('godot')
           and not re.search(r'[._-]console\.exe$', exe.name, re.I), 'Actual non-console Godot executable required')
    b.need(b.file_sha(exe) == b.ENGINE_SHA, 'Unreviewed actual executable')
    if not args.run:
        print(json.dumps({'preflight': True, 'writes': False, 'godot_run': False, 'pck_tested': False,
                          'private_copy': expected, 'runner_sha256': self_sha, 'engine_sha256': b.ENGINE_SHA}))
        return 0
    safety = b.load_helper(b.HELPER, b.HELPER_SHA, 'rng_pck_process_safety')
    guard = b.load_helper(b.GUARD, b.GUARD_SHA, 'rng_pck_source_guard')
    safety.require_exclusive_godot()
    b.no_links(b.LOCK)
    b.need(not b.LOCK.exists(), 'Shared engine lock is occupied')
    appdata = Path(os.environ['APPDATA']).resolve()
    real_users = {'production': appdata / 'Godot/app_userdata' / guard.project_name(ROOT),
                  'qa_name_in_real_appdata': appdata / 'Godot/app_userdata' / PROJECT_NAME}
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = HERE / 'pck_runs_r1' / stamp
    b.no_links(out)
    out.mkdir(parents=True, exist_ok=False)
    token = str(os.getpid()) + '|' + str(out)
    b.LOCK.parent.mkdir(exist_ok=True)
    with b.LOCK.open('x', encoding='utf-8') as lock:
        lock.write(token)
    result = {'schema': 1, 'suite': 'gameplay-rng-runtime-pck', 'complete': False, 'pck_tested': False,
              'lock_released': False, 'runner_sha256': self_sha, 'pins_sha256': PINS_SHA,
              'base_helper_sha256': BASE_SHA, 'process_safety_sha256': b.HELPER_SHA,
              'source_guard_sha256': b.GUARD_SHA, 'engine_binary_sha256': b.ENGINE_SHA,
              'content_version': CONTENT_VERSION, 'stages': {}, 'production_rng_migrated': False,
              'battle_resume_tested': False}
    source, protected = None, None
    attempts = []
    project, launch, pack = out / 'project', out / 'empty_launch', out / 'runtime.pck'
    pack_sha, writer_sha, handoff_sha = '', '', ''
    try:
        safety.require_exclusive_godot()
        source = guard.source_receipt(ROOT)
        protected = {name: b.tree(path) for name, path in real_users.items()}
        b.save(out / 'sources_before.json', source)
        b.save(out / 'players_before.json', protected)
        project.mkdir()
        launch.mkdir()
        for src, destination in MAPPING.items():
            raw = (ROOT / src).read_bytes()
            b.need(b.digest(raw) == expected[destination], 'Source changed during small copy')
            path = project / destination
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        b.save(out / 'private_sources_before.json', b.private_sources(project, expected))
        original_idle = safety.require_exclusive_godot
        def guard_boundary():
            original_idle()
            b.need(b.LOCK.read_text(encoding='utf-8') == token, 'Shared lock ownership changed')
            frozen(b, self_sha)
            b.need(b.file_sha(exe) == b.ENGINE_SHA, 'Actual executable changed')
            b.private_sources(project, expected)
            b.need(b.tree(launch)['files'] == {} and b.tree(launch)['directories'] == ['.'], 'Empty PCK launch directory gained files')
            b.need({name: b.tree(path) for name, path in real_users.items()} == protected, 'Real player profile changed')
            if pack_sha:
                b.need(b.file_sha(pack) == pack_sha, 'PCK changed after export')
        safety.require_exclusive_godot = guard_boundary
        writer = None
        private_exported = None
        for stage in ['export', 'writer', 'reader']:
            b.need(guard.source_receipt(ROOT) == source, 'Production source changed before stage')
            profile = out / 'private_profile' / stage
            user = profile / 'appdata/Godot/app_userdata' / PROJECT_NAME
            user.mkdir(parents=True, exist_ok=False)
            (profile / 'localappdata').mkdir()
            (profile / 'temp').mkdir()
            env = os.environ.copy()
            for key in list(env):
                if key.startswith(('GODOT_', 'GAMEPLAY_RNG_', 'POLISH_', 'PERF_', 'UNIT_', 'RUN_', 'STORE_',
                                   'INVENTORY_', 'BATTLE_FOG_', 'VALUE_CODEC_', 'FIRST_USE_', 'REDRAW_',
                                   'REDUCED_EFFECTS_', 'SEPARATION_', 'CHASE_PATH_', 'ANIM_LOAD_')):
                    env.pop(key)
            env.update(APPDATA=str(profile / 'appdata'), LOCALAPPDATA=str(profile / 'localappdata'),
                       TEMP=str(profile / 'temp'), TMP=str(profile / 'temp'))
            if stage == 'export':
                argv = [str(exe), '--headless', '--path', str(project), '--editor', '--export-pack', 'RNG QA PCK', str(pack), '--quit']
            else:
                b.need(private_exported == b.private_sources(project, expected), 'Private build source changed after export')
                if stage == 'reader':
                    b.need(writer is not None and b.file_sha(out / 'handoff.json') == handoff_sha
                           and b.file_sha(out / 'writer_report.json') == writer_sha, 'Writer inputs changed')
                manifest = {'run_id': stamp, 'run_dir': str(out), 'stage': stage, 'private_user': str(user),
                            'report': str(out / (stage + '_report.json')), 'engine_binary_sha256': b.ENGINE_SHA,
                            'pack_path': str(pack), 'pack_sha256': pack_sha, 'handoff_sha256': handoff_sha,
                            'writer_report_sha256': writer_sha}
                manifest_path = out / (stage + '_manifest.json')
                b.save(manifest_path, manifest)
                manifest_sha = b.file_sha(manifest_path)
                env['GAMEPLAY_RNG_PCK_MANIFEST'] = str(manifest_path)
                argv = [str(exe), '--headless', '--path', str(launch), '--main-pack', str(pack)]
            b.save(out / (stage + '_environment.json'), {key: env[key] for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']
                   + (['GAMEPLAY_RNG_PCK_MANIFEST'] if stage != 'export' else [])})
            guard_boundary()
            attempts.append(stage)
            process, console = command(b, safety, argv, out / (stage + '_process.json'), env, args.timeout)
            if stage == 'export':
                b.need(pack.is_file() and pack.stat().st_size > 0, 'Export produced no PCK')
                pack_sha = b.file_sha(pack)
                private_exported = b.private_sources(project, expected)
                b.save(out / 'private_sources_after_export.json', private_exported)
                result['pack_sha256'] = pack_sha
                result['pack_bytes'] = pack.stat().st_size
            else:
                report_path = out / (stage + '_report.json')
                report = b.read(report_path)
                b.need(b.file_sha(manifest_path) == manifest_sha == report.get('manifest_sha256'), 'PCK manifest changed')
                validate(b, report, manifest, process, console)
                b.need(report['handoff_sha256'] == b.file_sha(out / 'handoff.json'), 'Handoff SHA differs from report')
                if stage == 'writer':
                    writer = report
                    handoff_sha, writer_sha = b.file_sha(out / 'handoff.json'), b.file_sha(report_path)
                else:
                    b.need(report['process_id'] != writer['process_id'] and report['engine'] == writer['engine'], 'Distinct-process/same-engine contract failed')
                    b.need(b.file_sha(out / 'writer_report.json') == writer_sha and b.file_sha(out / 'handoff.json') == handoff_sha, 'Reader changed writer files')
                result['stages'][stage] = {'checks': report['check_count'], 'report_sha256': b.file_sha(report_path)}
            result['stages'].setdefault(stage, {})
            result['stages'][stage].update(child_pid=process['child_pid'], child_exit_confirmed=True, exit_code=0,
                                           process_sha256=b.file_sha(out / (stage + '_process.json')),
                                           log_sha256=b.file_sha(out / (stage + '_process.log')))
        result.update(complete=True, pck_tested=True, independent_process_continuation_tested=True,
                      handoff_sha256=handoff_sha, writer_report_sha256=writer_sha)
    except BaseException as error:
        result.update(complete=False, error=type(error).__name__ + ': ' + str(error))
    finally:
        try:
            for stage in attempts:
                process = b.read(out / (stage + '_process.json'))
                b.need(process.get('child_started') is False or process.get('child_exit_confirmed') is True, 'Unconfirmed child; retain lock')
            safety.require_exclusive_godot()
            frozen(b, self_sha)
            after = guard.source_receipt(ROOT)
            players = {name: b.tree(path) for name, path in real_users.items()}
            b.need(source is not None and after == source, 'Production source changed; retain lock')
            b.need(protected is not None and players == protected, 'Player data changed; retain lock')
            b.need(b.file_sha(exe) == b.ENGINE_SHA, 'Executable changed; retain lock')
            b.save(out / 'sources_after.json', after)
            b.save(out / 'players_after.json', players)
            b.save(out / 'private_sources_after.json', b.private_sources(project, expected))
            b.need(b.LOCK.read_text(encoding='utf-8') == token, 'Shared lock changed; retain lock')
            b.LOCK.unlink()
            result.update(lock_released=True, source_unchanged=True, player_unchanged=True)
        except BaseException as error:
            result.update(complete=False, final_guard_error=type(error).__name__ + ': ' + str(error))
        b.save(out / 'receipt.json', result)
        print(json.dumps({'run': str(out), 'complete': result['complete'], 'lock_released': result['lock_released']}))
    return 0 if result['complete'] and result['lock_released'] else 2


if __name__ == '__main__':
    sys.exit(main())
