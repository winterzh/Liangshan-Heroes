"""Freeze current sources and run the existing 30-minute Vulkan lifecycle soak.

The player profile is read-only; the existing soak report retains its own FPS,
memory and duration gates. A completed run is not automatically a passed run.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

from run_steam_integration_qa import ROOT, LOCK, sources, resolve_godot, resolve_profile_root
from run_classic30_continue_acceptance import tree_snapshot, engine_pids


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--work-root', type=Path, default=Path('D:/LHReleaseSoak'))
    args = parser.parse_args()
    parent = resolve_profile_root(args.work_root)
    engine = resolve_godot(None)
    if not args.run:
        print(json.dumps({'preflight': True, 'engine_busy': engine_pids(), 'lock_busy': LOCK.exists(), 'seconds': 1800}))
        return 0
    if engine_pids() or LOCK.exists():
        raise RuntimeError('Exclusive engine slot unavailable')
    run_id = time.strftime('%Y%m%d_%H%M%S') + '_' + uuid.uuid4().hex[:8]
    run = parent / run_id
    run.mkdir(parents=True, exist_ok=False)
    project = run / 'project'
    evidence = ROOT / 'qa/continue_release_20260924/soak' / run_id
    evidence.mkdir(parents=True, exist_ok=False)
    owner = json.dumps({'runner': 'private_release_soak', 'pid': os.getpid(), 'run': run_id})
    with LOCK.open('x', encoding='utf-8') as stream:
        stream.write(owner)
    receipt = {'run_id': run_id, 'complete': False, 'passed': False, 'source_files': [], 'steps': [],
               'engine_sha256': digest(engine), 'private_project': str(project), 'seconds_required': 1800}
    console_engine = engine.with_name(engine.stem + '_console.exe')
    if console_engine.is_file():
        receipt['console_launcher_sha256'] = digest(console_engine)
    child = None
    protected = before = None
    try:
        project.mkdir()
        paths = sorted(set(sources()) | {'tools/campaign_mode_soak_test.gd', 'tools/run_campaign_mode_soak.ps1',
                                        'tools/resolve_godot.ps1', 'tools/run_private_release_soak.py'})
        for name in paths:
            source = ROOT / name
            destination = project / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            receipt['source_files'].append({'path': name, 'sha256': digest(source)})
        name = json.loads(re.search(r'^config/name=("[^\n]+")\s*$', (project/'project.godot').read_text(encoding='utf-8'), re.M)[1])
        protected = Path(os.environ['APPDATA']) / 'Godot/app_userdata' / name
        before = tree_snapshot(protected)
        env = os.environ.copy()
        hooks = set()
        for script in (project/'scripts').rglob('*.gd'):
            hooks.update(re.findall(r'OS\.(?:get_environment|has_environment)\("([A-Z0-9_]+)"\)', script.read_text(encoding='utf-8-sig')))
        for key in list(env):
            if key in hooks or key.startswith('LSH_') or key.endswith(('_TEST', '_QA', '_AUDIT')):
                env.pop(key)
        for key in ['APPDATA', 'LOCALAPPDATA', 'TEMP', 'TMP']:
            folder = run/'profile'/key.lower()
            folder.mkdir(parents=True)
            env[key] = str(folder)
        env.update(STEAM_DISABLED='1', CAMPAIGN_QA='1')
        # Cache is only an import seed; Godot still checks all frozen resources.
        if (ROOT/'.godot/imported').is_dir():
            shutil.copytree(ROOT/'.godot/imported', project/'.godot/imported')
        commands = [
            ('import', [str(engine), '--path', str(project), '--headless', '--editor', '--import'], 600),
            ('soak', ['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(project/'tools/run_campaign_mode_soak.ps1'),
                      '-GodotPath', str(engine), '-ProjectPath', str(project), '-OutputDirectory', str(evidence), '-DurationSeconds', '1800'], 2400),
        ]
        for label, command, limit in commands:
            if engine_pids():
                raise RuntimeError('Another engine started before ' + label)
            print('RUN ' + label + ' ' + str(evidence), flush=True)
            started = time.monotonic()
            with (evidence/(label+'_runner.log')).open('wb') as log:
                child = subprocess.Popen(command, cwd=project, env=env, stdout=log, stderr=subprocess.STDOUT,
                                         creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                code = child.wait(timeout=limit)
            child = None
            receipt['steps'].append({'case': label, 'exit_code': code, 'seconds': time.monotonic()-started})
            import_errors = label == 'import' and re.search(r'(?m)^ERROR:|SCRIPT ERROR|Parse Error', (evidence/(label+'_runner.log')).read_text(encoding='utf-8', errors='replace'))
            if label == 'import' and (code or import_errors):
                raise RuntimeError('Import failed')
            if engine_pids():
                raise RuntimeError('Engine still running after ' + label)
        report = json.loads((evidence/'campaign_mode_soak.json').read_text(encoding='utf-8-sig'))
        receipt['complete'] = True
        receipt['passed'] = report.get('passed') is True and all(row['exit_code'] == 0 for row in receipt['steps'])
    except Exception as exc:
        receipt['failure'] = str(exc)
    finally:
        if child is not None and child.poll() is None:
            # Terminate this owned process tree only (PowerShell owns Godot).
            subprocess.run(['taskkill', '/PID', str(child.pid), '/T', '/F'], capture_output=True)
            child.wait(timeout=30)
        try:
            receipt['source_unchanged'] = all(digest(ROOT/row['path']) == row['sha256'] and digest(project/row['path']) == row['sha256'] for row in receipt['source_files'])
            receipt['player_unchanged'] = before is not None and tree_snapshot(protected) == before
            receipt['engine_pids_after'] = engine_pids()
        except Exception as exc:
            receipt.update(source_unchanged=False, player_unchanged=False, engine_pids_after=[], guard_failure=str(exc))
        receipt['passed'] = receipt['passed'] and receipt['source_unchanged'] and receipt['player_unchanged'] and not receipt['engine_pids_after']
        receipt['lock_released'] = False
        if LOCK.exists() and LOCK.read_text(encoding='utf-8') == owner and not receipt['engine_pids_after']:
            LOCK.unlink()
            receipt['lock_released'] = True
        (evidence/'receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(json.dumps({key: receipt.get(key) for key in ['run_id','complete','passed','failure','source_unchanged','player_unchanged']}, ensure_ascii=False), flush=True)
    return 0 if receipt['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
