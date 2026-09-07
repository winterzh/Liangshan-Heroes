"""Run the pure receipt draft in a minimal private Godot project after slot release.

Default is read-only preflight. No SteamService, production scene, SDK or player
restore is used. The file fixture flushes then exits gracefully; it does not prove
atomic replacement, power-loss durability or the pre-invalidation callback window.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import time
import uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
INPUTS = [HERE / n for n in ('steam_run_receipt.gd', 'receipt_test.gd', 'process_test.gd')]
INPUTS += [ROOT / 'scripts' / n for n in ('steam_achievement_catalog.gd', 'steam_achievement_state.gd')]
ERROR = re.compile(r'SCRIPT ERROR|^ERROR:|^WARNING:|Parse Error|Compile Error|\bFAIL(?:ED)?\b(?![= ]0)|leaked|RID allocations', re.M)


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def no_links(path):
    for p in [path] + list(path.parents):
        if p.exists() or p.is_symlink():
            require(not p.is_symlink() and not getattr(p.lstat(), 'st_file_attributes', 0) & 0x400, f'Link refused: {p}')


def snapshot(path):
    no_links(path)
    if not path.exists():
        return {'exists': False, 'files': {}, 'directories': []}
    files, directories = {}, []
    for base, dirs, names in os.walk(path, followlinks=False):
        for name in dirs + names:
            no_links(Path(base) / name)
        directories.append(Path(base).relative_to(path).as_posix())
        for name in names:
            p = Path(base) / name
            files[p.relative_to(path).as_posix()] = sha(p)
    return {'exists': True, 'files': files, 'directories': sorted(directories)}


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def godot_pids():
    raw = subprocess.check_output(['powershell.exe', '-NoProfile', '-Command',
        "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
    data = json.loads(raw) if raw else []
    return data if isinstance(data, list) else [data]


def player_directory():
    text = (ROOT / 'project.godot').read_text(encoding='utf-8-sig')
    require('config/use_custom_user_dir' not in text and 'config/custom_user_dir_name' not in text,
            'Production custom profile mapping needs explicit review')
    names = re.findall(r'^config/name=("[^\n]+")\s*$', text, re.M)
    require(len(names) == 1, 'Production project name missing')
    name = json.loads(names[0])
    require(name not in ('', '.', '..') and not any(c in name for c in '<>:"/\\|?*'), 'Unsafe production user directory')
    return Path(os.environ['APPDATA']) / 'Godot/app_userdata' / name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--profile-root', type=Path, default=Path('D:/LHReceiptProfiles'))
    args = parser.parse_args()
    require(args.profile_root.is_absolute(), 'Private profile root must be absolute')
    no_links(args.profile_root)
    lock = ROOT / '.godot/redraw_rejection_source.lock'
    no_links(lock)
    exe = Path((ROOT / 'godot.local.txt').read_text(encoding='utf-8-sig').strip())
    require(exe.is_file(), 'Godot missing')
    no_links(exe)
    original = {}
    for source in INPUTS + [Path(__file__).resolve()]:
        no_links(source)
        original[str(source)] = sha(source)
    initial_pids = godot_pids()
    print(json.dumps({'scope': 'pure_receipt_candidate', 'lock_busy': lock.exists(), 'godot_pids': initial_pids,
                      'inputs': original}, ensure_ascii=False), flush=True)
    if not args.run:
        return 0
    require(not initial_pids, 'Godot slot busy')
    token = uuid.uuid4().hex
    run = HERE / 'runs' / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + token[:8])
    no_links(run)
    run.mkdir(parents=True, exist_ok=False)
    profile = args.profile_root / token
    project = run / 'project'
    report = {'scope': 'pure_receipt_candidate', 'inputs': original, 'production_integration': False,
              'processes': [], 'passed': False, 'runner_sha256': original[str(Path(__file__).resolve())],
              'godot_sha256': sha(exe), 'private_profile': str(profile),
              'boundary': 'Pure model and graceful fixture-process exits only; no atomic disk adapter or result-8 pre-persistence crash guarantee'}
    active = None
    lock_owned = False
    protected = {}
    copied = {}
    work_complete = False
    try:
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open('x', encoding='utf-8') as handle:
            lock_owned = True
            handle.write(token)
        # Protect the actual production profile AND the minimal test's default
        # non-private location, so a wrong APPDATA mapping cannot pass silently.
        for player in (player_directory(), Path(os.environ['APPDATA']) / 'LHReceiptContract'):
            protected[str(player)] = snapshot(player)
        project.mkdir()
        for source in INPUTS:
            raw = source.read_bytes()
            require(hashlib.sha256(raw).hexdigest() == original[str(source)], 'Input changed before freeze')
            relative = 'scripts/' + source.name if source.parent.name == 'scripts' else source.name
            dest = project / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(raw)
            copied[relative] = sha(dest)
            require(copied[relative] == original[str(source)], 'Frozen input differs from source receipt')
        (project / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="LHReceiptContract"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="LHReceiptContract"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding='utf-8')
        copied['project.godot'] = sha(project / 'project.godot')
        report['copied_inputs'] = copied.copy()
        no_links(profile)
        profile.mkdir(parents=True, exist_ok=False)
        env = os.environ.copy()
        for key in ('APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP'):
            dest = profile / key.lower()
            dest.mkdir()
            env[key] = str(dest)
        expected = profile / 'appdata/LHReceiptContract'
        env.update(STEAM_RECEIPT_EXPECTED_USER_DIR=expected.as_posix(), STEAM_DISABLED='1', CAMPAIGN_QA='1')
        report['expected_user_dir'] = str(expected)
        phases = [('import', ['--editor', '--import']), ('model', ['--script', 'res://receipt_test.gd'])]
        phases += [(p, ['--script', 'res://process_test.gd']) for p in
                   ('create', 'resume', 'intent_only', 'recover', 'invalidate_only', 'correct', 'recover_correction')]
        for name, tail in phases:
            require(not godot_pids(), 'Godot slot occupied before ' + name)
            require(all(sha(project / p) == digest for p, digest in copied.items()), 'Frozen inputs changed before ' + name)
            env['STEAM_RECEIPT_PHASE'] = name
            result = run / (name + '.json')
            env['STEAM_RECEIPT_TEST_OUTPUT'] = str(result)
            command = [str(exe), '--headless', '--path', str(project)] + tail
            started = time.monotonic()
            row = {'name': name, 'exit_code': None, 'child_exit_confirmed': False, 'log': name + '.log'}
            report['processes'].append(row)
            with (run / row['log']).open('wb') as log:
                active = subprocess.Popen(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT,
                                          creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                row['pid'] = active.pid
                code = active.wait(timeout=90)
                row.update(exit_code=code, child_exit_confirmed=active.poll() is not None,
                           seconds=time.monotonic()-started)
                active = None
            log_text = (run / row['log']).read_text(encoding='utf-8', errors='strict')
            row['log_errors'] = [line for line in log_text.splitlines() if ERROR.search(line)]
            require(code == 0 and not row['log_errors'], 'Phase failed: ' + name)
            if name != 'import':
                payload = json.loads(result.read_text(encoding='utf-8'))
                row.update(checks=len(payload['checks']), passed=payload['passed'])
                require(payload['passed'] is True and payload['failed'] == 0 and payload['checks'], 'Assertions failed: ' + name)
                require(all(item.get('passed') is True for item in payload['checks']), 'Contradictory assertions: ' + name)
                require(payload['pid'] == row['pid'], 'Result belongs to wrong process')
                require(Path(payload['user_data_dir']).resolve() == expected.resolve(), 'Observed private profile mismatch')
                if name != 'model':
                    require(payload['phase'] == name, 'Wrong fixture phase')
            require(not godot_pids(), 'Godot did not exit')
            require(all(snapshot(Path(p)) == before for p, before in protected.items()), 'Player profile changed')
            require(all(sha(project / p) == digest for p, digest in copied.items()), 'Frozen source changed')
            write(run / 'receipt.json', report)
        work_complete = True
    except BaseException as exc:
        report['error'] = type(exc).__name__ + ': ' + str(exc)
    finally:
        errors = []
        if active is not None:
            try:
                if active.poll() is None:
                    active.kill()
                active.wait(timeout=15)
                if report['processes']:
                    report['processes'][-1].update(exit_code=active.returncode, child_exit_confirmed=active.poll() is not None)
            except BaseException as exc:
                errors.append('Owned process exit not confirmed: ' + repr(exc))
        for name, operation in (
            ('source_unchanged', lambda: all(sha(Path(p)) == digest for p, digest in original.items())),
            ('frozen_inputs_unchanged', lambda: bool(copied) and all(sha(project / p) == digest for p, digest in copied.items())),
            ('player_profiles_unchanged', lambda: len(protected) == 2 and all(snapshot(Path(p)) == before for p, before in protected.items())),
        ):
            try:
                report[name] = operation()
            except BaseException as exc:
                report[name] = False
                errors.append(name + ': ' + repr(exc))
        try:
            report['godot_pids_after'] = godot_pids()
        except BaseException as exc:
            report['godot_pids_after'] = None
            errors.append('Process inventory unavailable: ' + repr(exc))
        report['child_exits_confirmed'] = all(row.get('child_exit_confirmed') is True for row in report['processes'])
        report['lock_released'] = False
        try:
            if lock_owned and lock.is_file() and lock.read_text(encoding='utf-8') == token and report['godot_pids_after'] == [] and report['child_exits_confirmed']:
                lock.unlink()
                report['lock_released'] = True
        except BaseException as exc:
            errors.append('Lock release failed: ' + repr(exc))
        report['finalization_errors'] = errors
        report['passed'] = work_complete and not errors and all(report.get(key) is True for key in
            ('source_unchanged', 'frozen_inputs_unchanged', 'player_profiles_unchanged', 'child_exits_confirmed', 'lock_released')) and report['godot_pids_after'] == []
        write(run / 'receipt.json', report)
        print(str(run / 'receipt.json'), flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())

