"""Probe an already imported private source project or an actual exported PCK/EXE.

Default is read-only preflight. --run creates only a private host/profile/report.
No export, import, Git, production patching, or player-directory writes.
run_locked is also the narrow hook for an existing builder that already owns the lock.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import types

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = next(p for p in [HERE] + list(HERE.parents) if (p / 'project.godot').is_file() and (p / 'scripts/battle.gd').is_file())
BASE = ROOT / 'qa/run_gameplay_rng_20260907/sources/run_gameplay_rng_r1/run_qa.py.txt'
BASE_SHA = '8f9c82100bf8b635abd74f9a79b31335e72df404f30c62f3f490458af3e0e1ad'
LABELS = {'provider_resolved', 'save_identity_eligible', 'expected_source_mode', 'host_source_digest',
          'host_rules_digest', 'host_provider_digest', 'actual_executing_binary', 'exact_optional_content',
          'private_user', 'native_present_when_expected'}


def utilities():
    import hashlib
    raw = BASE.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASE_SHA: raise RuntimeError('Reviewed utility drift')
    util = types.ModuleType('identity_probe_util')
    util.__file__ = str(BASE)
    exec(compile(raw.decode('utf-8'), str(BASE), 'exec'), util.__dict__)
    # Exact archived bytes; only their checkout-relative data paths are rebound.
    util.ROOT = ROOT
    util.LOCK = ROOT / '.godot/redraw_rejection_source.lock'
    util.HELPER = ROOT / 'qa/run_gameplay_rng_20260907/dependencies/scratchpad/separation_sections_diag/frozen/process_safety.py.txt'
    util.GUARD = ROOT / 'qa/run_gameplay_rng_20260907/dependencies/tools/run_reduced_effects_qa.py.txt'
    return util


def generator(util):
    path = HERE / 'build_identity.py'
    return util.load_helper(path, util.file_sha(path), 'identity_input_generator')


def run_locked(project, pack, engine, out, env, expected, before_launch, probe_path=None):
    """Caller retains shared lock and source/player guards. This owns only its exact child."""
    util = utilities()
    safety = util.load_helper(util.HELPER, util.HELPER_SHA, 'identity_process_safety')
    probe_path = Path(probe_path or HERE / 'pck_probe.gd')
    project, out, engine = Path(project), Path(out), Path(engine)
    util.need(callable(before_launch), 'An owning source/player/lock guard is required')
    engine_sha = util.file_sha(engine)
    util.need(engine_sha == util.ENGINE_SHA and not engine.name.lower().endswith(('_console.exe', '.console.exe')), 'Actual frozen non-console editor required')
    out.mkdir(parents=True, exist_ok=False)
    frozen = {str(path): util.file_sha(path) for path in [Path(__file__), HERE / 'build_identity.py', probe_path]}
    receipt = {'complete': False, 'child_started': False, 'child_exit_confirmed': False, 'lock_owned_by_caller': True,
               'source_mode': pack is None, 'engine_binary_sha256': engine_sha, 'utility_sha256': BASE_SHA,
               'process_safety_sha256': util.HELPER_SHA, 'sources': frozen, 'release_process_tested': False}
    process = None
    try:
        before_launch()
        actual_engine = engine
        if pack is not None:
            host = out / 'probe_host'
            host.mkdir()
            actual_engine = host / 'Godot.exe'
            shutil.copyfile(engine, actual_engine)
            util.need(util.file_sha(actual_engine) == engine_sha, 'Private editor copy drift')
            for row in expected['native_files']:
                if not row['path'].endswith('.dll'): continue
                src = project / row['path']
                util.need(util.file_sha(src) == row['sha256'], 'Native staging bytes changed')
                dst = host / src.name
                util.need(not dst.exists(), 'Duplicate native basename')
                shutil.copyfile(src, dst)
                util.need(util.file_sha(dst) == row['sha256'], 'Native private copy drift')
        profile = out / 'private_profile'
        child_env = env.copy()
        for key in list(child_env):
            if key.endswith(('_TEST', '_QA', '_QA_MANIFEST', '_AUDIT')) or key in {'LEVEL', 'SCENARIO', 'CUSTOM_DEFENSE', 'SKIRMISH', 'SKIRMISH_AI', 'ARENA'}:
                child_env.pop(key)
        for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']:
            folder = profile / key.lower()
            folder.mkdir(parents=True)
            child_env[key] = str(folder)
        # Only subprocess environment changes. Never override HOME/CODEX_HOME.
        guard = util.load_helper(util.GUARD, util.GUARD_SHA, 'identity_project_name')
        user = profile / 'appdata/Godot/app_userdata' / guard.project_name(project)
        user.mkdir(parents=True)
        manifest = {key: expected[key] for key in ['source_sha256', 'rules_sha256', 'provider_sha256', 'optional_content']}
        manifest.update(run_id=out.name, source_mode=pack is None, engine_binary_sha256=engine_sha,
                        private_user=str(user), report=str(out / 'report.json'), native_expected=bool(expected['native_files']))
        util.save(out / 'manifest.json', manifest)
        manifest_sha = util.file_sha(out / 'manifest.json')
        child_env.update(STEAM_DISABLED='1', CAMPAIGN_QA='1', CONTENT_UPDATE_NO_AUTO='1',
                         CONTENT_IDENTITY_PROBE_MANIFEST=str(out / 'manifest.json'))
        command = [str(actual_engine), '--headless']
        command += ['--main-pack', str(pack)] if pack is not None else ['--path', str(project)]
        command += ['--script', str(probe_path)]
        receipt['command'] = command
        receipt['pack_sha256'] = util.file_sha(Path(pack)) if pack else None
        before_launch()
        util.need(all(util.file_sha(Path(p)) == s for p, s in frozen.items()), 'Probe source drift')
        safety.require_exclusive_godot()
        started = time.monotonic()
        with (out / 'report.log').open('xb') as log:
            try:
                process = subprocess.Popen(command, cwd=Path(pack).parent if pack else project, env=child_env,
                                           stdout=log, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                safety.ACTIVE_GODOT_PROCESS = process
                receipt.update(child_started=True, child_pid=process.pid)
                while process.poll() is None:
                    if util.ERROR.search((out / 'report.log').read_bytes().decode('utf-8', errors='ignore')):
                        raise RuntimeError('Owned probe emitted a strict diagnostic')
                    if time.monotonic() - started > 300: raise subprocess.TimeoutExpired(command, 300)
                    time.sleep(0.1)
            finally:
                if process is not None:
                    if process.poll() is None: process.kill()
                    process.wait(timeout=30)
                    receipt.update(child_exit_confirmed=process.poll() is not None, exit_code=process.returncode,
                                   wall_seconds=time.monotonic() - started)
                    if receipt['child_exit_confirmed']: safety.ACTIVE_GODOT_PROCESS = None
        util.need(receipt['child_exit_confirmed'] and process.returncode == 0, 'Child failed or exit unconfirmed')
        safety.require_exclusive_godot()
        before_launch()
        util.need(util.file_sha(actual_engine) == engine_sha and util.file_sha(out / 'manifest.json') == manifest_sha, 'Engine/manifest drift')
        if pack: util.need(util.file_sha(Path(pack)) == receipt['pack_sha256'], 'Pack changed during probe')
        report = util.read(out / 'report.json')
        log = (out / 'report.log').read_bytes().decode('utf-8')
        prefix = 'CONTENT_IDENTITY_REPORT '
        marked = [util.json_value(line[len(prefix):].encode('utf-8')) for line in log.splitlines() if line.startswith(prefix)]
        util.need(marked == [report] and not util.ERROR.search(log), 'Strict stdout/report mismatch')
        util.need(report.get('complete') is True and report.get('passed') is True and report.get('suite') == 'content-identity', 'Probe failure')
        util.need(report.get('run_id') == out.name and report.get('process_id') == process.pid and report.get('manifest_sha256') == manifest_sha, 'Probe identity mismatch')
        util.need(Path(report.get('actual_user_dir', '')).resolve() == user.resolve(), 'Private user mismatch')
        checks = report.get('checks', [])
        util.need(len(checks) == len(LABELS) == report.get('check_count') and {c.get('label') for c in checks} == LABELS and all(c.get('passed') is True for c in checks), 'Missing/failed exact probe checks')
        value = report['identity']
        for key in ['source_sha256', 'rules_sha256', 'provider_sha256', 'optional_content', 'engine_binary_sha256', 'source_mode']:
            util.need(value.get(key) == manifest[key], 'Host identity mismatch: ' + key)
        util.need(value.get('ok') is True and value.get('save_eligible') is True and value.get('content_version') == 'source-v1:' + expected['source_sha256'], 'Ineligible identity')
        util.need(report.get('full_battle_resume_tested') is False and report.get('release_process_tested') is False, 'Wrong scope claim')
        util.need(all(util.file_sha(Path(p)) == s for p, s in frozen.items()), 'Probe source changed')
        receipt.update(complete=True, report_sha256=util.file_sha(out / 'report.json'), check_count=len(checks))
    except BaseException as error:
        receipt['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        # Never release the caller's lock. A started unconfirmed child is explicit in this receipt.
        util.save(out / 'process_receipt.json', receipt)
    if not receipt['complete']: raise RuntimeError('Identity probe failed: ' + str(out / 'process_receipt.json'))
    return receipt


def main():
    util = utilities()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--main-pack', type=Path)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, required=True, help='Exact post-import build_identity generate receipt')
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    project, exe = args.project.resolve(), args.godot.resolve()
    gen = generator(util)
    gen.private_staging(project)
    util.MAX_JSON = 16 * 1024 * 1024
    expected = util.read(args.receipt)
    gen.verify_generated(project, expected)
    util.need(util.file_sha(exe) == util.ENGINE_SHA, 'Unexpected actual editor')
    if not args.run:
        print(json.dumps({'preflight': True, 'godot_run': False, 'source_sha256': expected['identity']['source_sha256'], 'source_mode': args.main_pack is None}))
        return 0
    safety = util.load_helper(util.HELPER, util.HELPER_SHA, 'identity_outer_safety')
    guard = util.load_helper(util.GUARD, util.GUARD_SHA, 'identity_source_guard')
    safety.require_exclusive_godot()
    util.no_links(util.LOCK)
    util.need(not util.LOCK.exists(), 'Shared engine lock occupied')
    out = HERE / 'runs' / datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out.mkdir(parents=True, exist_ok=False)
    token = str(os.getpid()) + '|' + str(out)
    with util.LOCK.open('x', encoding='utf-8') as lock: lock.write(token)
    result = {'complete': False, 'lock_released': False, 'godot_run': False}
    source = players = None
    real_user = Path(os.environ['APPDATA']) / 'Godot/app_userdata' / guard.project_name(ROOT)
    try:
        source = guard.source_receipt(ROOT)
        players = util.tree(real_user)
        util.save(out / 'source_before.json', source)
        util.save(out / 'players_before.json', players)
        def final_guard():
            safety.require_exclusive_godot()
            util.need(util.LOCK.read_text(encoding='utf-8') == token, 'Shared lock ownership changed')
            util.need(guard.source_receipt(ROOT) == source and util.tree(real_user) == players, 'Production source/player changed')
            gen.verify_generated(project, expected)
        final_guard()
        result['godot_run'] = True
        result['probe'] = run_locked(project, args.main_pack, exe, out / 'probe', os.environ.copy(), expected['identity'], final_guard)
        result['complete'] = True
    except BaseException as error:
        result['error'] = type(error).__name__ + ': ' + str(error)
    finally:
        try:
            path = out / 'probe/process_receipt.json'
            util.need(not result['godot_run'] or path.exists(), 'Missing owned-process receipt; keep lock')
            if path.exists():
                receipt = util.read(path)
                util.need(not receipt['child_started'] or receipt['child_exit_confirmed'], 'Unconfirmed owned child; keep lock')
            final_guard()
            util.save(out / 'source_after.json', guard.source_receipt(ROOT))
            util.save(out / 'players_after.json', util.tree(real_user))
            util.LOCK.unlink()
            result.update(lock_released=True, source_unchanged=True, player_unchanged=True)
        except BaseException as error:
            result.update(complete=False, final_guard_error=type(error).__name__ + ': ' + str(error))
        util.save(out / 'receipt.json', result)
        print(json.dumps({'run': str(out), **result}))
    return 0 if result['complete'] and result['lock_released'] else 1


if __name__ == '__main__': sys.exit(main())
