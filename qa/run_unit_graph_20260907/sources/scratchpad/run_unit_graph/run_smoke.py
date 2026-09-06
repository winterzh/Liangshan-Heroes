"""Real continuous effect restore smoke; each --run has a fresh private user profile."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import types

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'scratchpad/run_gameplay_rng_r1/run_qa.py'
BASE_SHA = '8f9c82100bf8b635abd74f9a79b31335e72df404f30c62f3f490458af3e0e1ad'


def execute(util, safety, exe, entry, out, env):
    """Keep the exact child handle; stop promptly on its own parser/error output."""
    safety.require_exclusive_godot()
    command = [str(exe), '--path', str(ROOT), '--headless', '--script',
               'res://scratchpad/run_unit_graph/' + entry]
    actual_entry = command[-1].removeprefix('res://')
    manifest = util.read(out / 'manifest.json')
    util.need(manifest['source_sha256'].get(actual_entry) == util.file_sha(ROOT / actual_entry),
              'Executed entry must be pinned by the runtime manifest')
    process = None
    failure = cleanup = None
    confirmed = False
    started = time.monotonic()
    log_path = out / 'report.log'
    with log_path.open('xb') as log:
        try:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log,
                                       stderr=subprocess.STDOUT,
                                       creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            safety.ACTIVE_GODOT_PROCESS = process
            while process.poll() is None:
                if util.ERROR.search(log_path.read_bytes().decode('utf-8', errors='ignore')):
                    raise RuntimeError('Owned Godot emitted an error; see report.log')
                if time.monotonic() - started >= 120:
                    raise subprocess.TimeoutExpired(command, 120)
                time.sleep(0.1)
            util.need(process.returncode == 0, 'Owned Godot returned nonzero')
        except BaseException as error:
            failure = error
        finally:
            if process is not None:
                try:
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=30)
                    confirmed = process.poll() is not None
                    if confirmed:
                        safety.ACTIVE_GODOT_PROCESS = None
                except BaseException as error:
                    cleanup = type(error).__name__ + ': ' + str(error)
    util.save(out / 'report_process.json', {
        'command': command, 'child_pid': process.pid if process else None,
        'child_started': process is not None, 'child_exit_confirmed': confirmed,
        'exit_code': process.returncode if process else None,
        'wall_seconds': time.monotonic() - started,
        'timed_out': isinstance(failure, subprocess.TimeoutExpired),
        'exception': type(failure).__name__ + ': ' + str(failure) if failure else None,
        'cleanup_error': cleanup, 'scope': 'actual component restore smoke; not complete Battle resume'})
    if failure is not None:
        raise failure
    util.need(confirmed and cleanup is None, 'Owned child exit unconfirmed')
    safety.require_exclusive_godot()
    return util.read(out / 'report.json')


def main():
    import hashlib
    raw = BASE.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == BASE_SHA, 'Reviewed lifecycle utilities drifted'
    util = types.ModuleType('restore_util')
    util.__file__ = str(BASE)
    exec(compile(raw.decode('utf-8'), str(BASE), 'exec'), util.__dict__)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--godot', required=True)
    parser.add_argument('--suite', choices=['unit-graph'], default='unit-graph')
    args = parser.parse_args()
    exe = Path(args.godot).resolve()
    util.need(util.file_sha(exe) == util.ENGINE_SHA, 'Wrong engine')
    names = ['scripts/unit.gd', 'scripts/hero_inventory.gd', 'scripts/game_map.gd',
             'scripts/run_state_value_codec.gd', 'scripts/battle.gd', 'project.godot']
    entry = 'graph_smoke.gd'
    names += ['scripts/run_unit_state.gd', 'scripts/run_graph_identity.gd',
              'scratchpad/run_unit_graph/unit_graph.gd',
              'scratchpad/run_unit_graph/' + entry]
    hashes = {name: util.file_sha(ROOT / name) for name in names}
    runner_sha = util.file_sha(Path(__file__))
    if not args.run:
        print(json.dumps({'preflight': True, 'godot_run': False, 'runtime_sources': hashes}))
        return 0
    guard = util.load_helper(util.GUARD, util.GUARD_SHA, 'restore_source_guard')
    safety = util.load_helper(util.HELPER, util.HELPER_SHA, 'restore_process_safety')
    safety.ROOT = ROOT
    safety.ERROR = util.ERROR
    safety.require_exclusive_godot()
    util.need(not util.LOCK.exists(), 'Shared engine lock occupied')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out = HERE / 'runs' / stamp
    out.mkdir(parents=True, exist_ok=False)
    token = str(os.getpid()) + '|' + str(out)
    with util.LOCK.open('x', encoding='utf-8') as file:
        file.write(token)
    suite = args.suite
    result = {'suite': suite, 'complete': False, 'godot_run': False,
              'lock_released': False, 'runner_sha256': runner_sha,
              'engine_sha256': util.ENGINE_SHA, 'source_sha256': hashes,
              'battle_resume_tested': False, 'menu_continue_implemented': False}
    source = protected = None
    real_user = Path(os.environ['APPDATA']) / 'Godot/app_userdata' / guard.project_name(ROOT)
    try:
        source = guard.source_receipt(ROOT)
        protected = util.tree(real_user)
        util.save(out / 'sources_before.json', source)
        util.save(out / 'players_before.json', protected)
        profile = out / 'private_profile'
        user = profile / 'appdata/Godot/app_userdata' / guard.project_name(ROOT)
        user.mkdir(parents=True, exist_ok=False)
        (profile / 'localappdata').mkdir()
        (profile / 'temp').mkdir()
        env, controls = guard.environment(source, out, profile, user)
        for key in list(env):
            if key.startswith(('UNIT_ADAPTER_', 'UNIT_REFERENCES_', 'INVENTORY_QA_',
                               'BATTLE_FOG_QA_', 'RUN_RESTORE_', 'GAMEPLAY_RNG_',
                               'VALUE_CODEC_', 'STORE_QA_', 'REDRAW_', 'REDUCED_EFFECTS_',
                               'FIRST_USE_', 'SEPARATION_', 'CHASE_PATH_', 'ANIM_LOAD_')):
                env.pop(key)
        env.update(TEMP=str(profile / 'temp'), TMP=str(profile / 'temp'))
        manifest = {'run_id': stamp, 'private_user': str(user),
                    'report': str(out / 'report.json'), 'source_sha256': hashes}
        util.save(out / 'manifest.json', manifest)
        manifest_sha = util.file_sha(out / 'manifest.json')
        env['RUN_RESTORE_QA_MANIFEST'] = str(out / 'manifest.json')
        util.save(out / 'environment.json', {'private_user': str(user), 'controls': controls})
        original_idle = safety.require_exclusive_godot

        def launch_guard():
            original_idle()
            util.need(util.LOCK.read_text(encoding='utf-8') == token, 'Lock ownership drift')
            util.need(util.tree(real_user) == protected, 'Real player directory drift')
            util.need(all(util.file_sha(ROOT / name) == value for name, value in hashes.items()), 'Runtime changed')
            util.need(util.file_sha(Path(__file__)) == runner_sha, 'Runner changed')

        safety.require_exclusive_godot = launch_guard
        launch_guard()
        result['godot_run'] = True
        report = execute(util, safety, exe, entry, out, env)
        process = util.read(out / 'report_process.json')
        log = (out / 'report.log').read_bytes().decode('utf-8')
        prefix = '[' + suite + ' QA] '
        marked = [json.loads(line[len(prefix):]) for line in log.splitlines() if line.startswith(prefix)]
        util.need(marked == [report] and not util.ERROR.search(log), 'Strict log or stdout mismatch')
        util.need(report.get('suite') == suite and report.get('run_id') == stamp, 'Wrong run')
        util.need(report.get('process_id') == process['child_pid'], 'PID mismatch')
        util.need(Path(report.get('actual_user_dir', '')).resolve() == user.resolve(), 'user:// mismatch')
        util.need(report.get('source_sha256') == hashes, 'Source report mismatch')
        checks = report.get('checks', [])
        util.need(report.get('complete') is True and report.get('passed') is True
                  and checks and report.get('failures') == []
                  and all(row.get('passed') is True for row in checks), 'Failed checks')
        util.need(util.file_sha(out / 'manifest.json') == manifest_sha, 'Manifest drift')
        result.update(complete=True, checks=len(checks), process_id=process['child_pid'],
                      report_sha256=util.file_sha(out / 'report.json'))
    except BaseException as error:
        result.update(complete=False, error=type(error).__name__ + ': ' + str(error))
    finally:
        try:
            safety.require_exclusive_godot()
            if (out / 'report_process.json').exists():
                process = util.read(out / 'report_process.json')
                util.need(not process['child_started'] or process['child_exit_confirmed'], 'Owned child still running')
            after = guard.source_receipt(ROOT)
            players_after = util.tree(real_user)
            util.need(source is not None and after == source, 'Source guard failed')
            util.need(protected is not None and players_after == protected, 'Player guard failed')
            util.need(util.file_sha(Path(__file__)) == runner_sha, 'Runner changed')
            util.need(all(util.file_sha(ROOT / name) == value for name, value in hashes.items()), 'Runtime changed')
            util.need(util.LOCK.read_text(encoding='utf-8') == token, 'Lock ownership changed')
            util.save(out / 'sources_after.json', after)
            util.save(out / 'players_after.json', players_after)
            util.LOCK.unlink()
            result.update(lock_released=True, source_unchanged=True, player_unchanged=True)
        except BaseException as error:
            result.update(complete=False, final_guard_error=type(error).__name__ + ': ' + str(error))
        util.save(out / 'receipt.json', result)
        print(json.dumps({'run': str(out), 'complete': result['complete'], 'lock_released': result['lock_released']}))
    return 0 if result['complete'] and result['lock_released'] else 1


if __name__ == '__main__':
    sys.exit(main())
