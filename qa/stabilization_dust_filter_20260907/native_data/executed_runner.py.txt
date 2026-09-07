"""Run only the exact dust-block pure-data driver in a fresh minimal project.

No production scripts execute. Original/candidate Unit text is retained as data
and source-hashed. A normal full-game A/B is a separate later test.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import run_stabilization_performance as guard


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze-sha256', required=True)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    frozen_bytes = (HERE / 'freeze.json').read_bytes()
    guard.need(guard.sha(frozen_bytes) == args.freeze_sha256, 'Wrong approved freeze')
    frozen = json.loads(frozen_bytes.decode('utf-8'))
    guard.need('run_data.py' in frozen['inputs'], 'Native launcher is not a frozen input')
    for name, digest in frozen['inputs'].items():
        guard.no_links(HERE / name)
        guard.need(guard.sha((HERE / name).read_bytes()) == digest, 'Frozen input changed: ' + name)
    metadata = json.loads((HERE / 'source_receipt.json').read_text(encoding='utf-8'))
    original = ROOT / '.godot/stabilization_performance/20260907T053341Z_cd6e93a0/project/scripts/unit.gd'
    guard.need(guard.sha(original.read_bytes()) == metadata['before_sha256'], 'Original baseline bytes changed')
    exe = Path((ROOT / 'godot.local.txt').read_text(encoding='utf-8-sig').strip())
    guard.no_links(exe)
    info = {'preflight': True, 'source_head': metadata['source_head'], 'freeze_sha256': args.freeze_sha256,
            'mode': 'exact dust blocks in a minimal pure-data project', 'godot_pids': guard.godot_processes(),
            'godot_sha256':guard.sha(exe.read_bytes())}
    print(json.dumps(info), flush=True)
    if not args.run: return 0
    guard.need(not info['godot_pids'], 'Godot slot is occupied')
    run_id = 'dust_data_' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + uuid.uuid4().hex[:8]
    run = ROOT / '.godot/stabilization_performance' / run_id
    guard.no_links(run); run.mkdir(parents=True, exist_ok=False)
    protected = {name:guard.sha((ROOT/name).read_bytes()) for name in ('project.godot','scripts/unit.gd')}
    lock = ROOT / '.godot/redraw_rejection_source.lock'
    guard.no_links(lock)
    owner = json.dumps({'owner':'dust_data','run_id':run_id,'pid':os.getpid()})
    receipt = dict(info, run_id=run_id, complete=False, runner_sha256=frozen['inputs']['run_data.py'],
                   errors=[], final_issues=[])
    lock_owned = False
    active = None
    player = None
    player_before = None
    project = run / 'project'
    expected = None
    try:
        with lock.open('x', encoding='utf-8') as stream:
            lock_owned = True
            stream.write(owner)
        config = (ROOT / 'project.godot').read_text(encoding='utf-8-sig')
        guard.need('config/use_custom_user_dir' not in config and 'config/custom_user_dir_name' not in config, 'Custom player mapping not reviewed')
        names = re.findall(r'^config/name=("[^\n]+")\s*$', config, re.M)
        guard.need(len(names) == 1, 'Ambiguous real player project name')
        name = json.loads(names[0])
        guard.need(not any(x in name for x in '<>:"/\\|?*'), 'Unsafe profile project name')
        player = Path(os.environ['APPDATA']) / 'Godot/app_userdata' / name
        player_before = guard.snapshot(player)
        receipt['player_before_digest'] = guard.sha(json.dumps(player_before,sort_keys=True).encode())
        profile = Path('D:/LHPerfProfiles') / run_id
        guard.no_links(profile); profile.mkdir(parents=True, exist_ok=False)
        env = os.environ.copy()
        for key in ('APPDATA','LOCALAPPDATA','TEMP','TMP'):
            path = profile / key.lower(); path.mkdir(); env[key] = str(path)
        env.update(CAMPAIGN_QA='1', STEAM_DISABLED='1')
        actual_user = profile / 'appdata/Godot/app_userdata' / name
        project.mkdir()
        (project / 'project.godot').write_bytes(('[application]\nconfig/name=' + json.dumps(name,ensure_ascii=False) + '\n').encode('utf-8'))
        (project / 'reference_unit.gd.txt').write_bytes(original.read_bytes())
        (project / 'candidate_unit.gd.txt').write_bytes((HERE/'candidate/scripts/unit.gd').read_bytes())
        (project / 'data_smoke.gd').write_bytes((HERE/'data_smoke.gd').read_bytes())
        expected = {p.name:guard.sha(p.read_bytes()) for p in project.iterdir() if p.is_file()}
        manifest = {'run_id':run_id,'private_user':str(actual_user),'report':str(run/'report.json'),'source_sha256':expected}
        guard.save(run/'manifest.json',manifest)
        env['RUN_RESTORE_QA_MANIFEST'] = str(run/'manifest.json')
        (run/'freeze.json').write_bytes(frozen_bytes)
        (run/'executed_runner.py.txt').write_bytes(Path(__file__).read_bytes())
        (run/'executed_guard.py.txt').write_bytes(Path(guard.__file__).read_bytes())
        command = [str(exe),'--headless','--path',str(project),'--script','res://data_smoke.gd']
        started = time.monotonic()
        with (run/'native.log').open('xb') as stream:
            active = subprocess.Popen(command,cwd=project,env=env,stdout=stream,stderr=subprocess.STDOUT,
                                      creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            receipt['pid'] = active.pid
            try: code = active.wait(timeout=45)
            except subprocess.TimeoutExpired: active.kill(); active.wait(timeout=30); code = -1
            active = None
        receipt.update(exit_code=code,seconds=time.monotonic()-started,child_exit_confirmed=True)
        text = (run/'native.log').read_text(encoding='utf-8',errors='strict')
        receipt['errors'] = [line for line in text.splitlines() if guard.ERROR.search(line)]
        guard.need(code == 0 and not receipt['errors'], 'Native pure-data driver failed')
        report = json.loads((run/'report.json').read_text(encoding='utf-8'))
        prefix = '[dust-filter data QA] '
        printed = [json.loads(line[len(prefix):]) for line in text.splitlines() if line.startswith(prefix)]
        guard.need(printed == [report], 'Stdout/report mismatch')
        guard.need(report['run_id'] == run_id and report['process_id'] == receipt['pid'] and report['suite'] == 'dust-filter-data-candidate', 'Report identity mismatch')
        guard.need(Path(report['actual_user_dir']).resolve() == actual_user.resolve(), 'Actual private user mismatch')
        guard.need(report['source_sha256'] == expected and report['complete'] and report['passed'] and not report['failures'] and report['failed_count'] == 0, 'Native contract failed')
        guard.need(report['check_count'] == len(report['checks']) and all(x['passed'] is True for x in report['checks']), 'Check inventory invalid')
        receipt.update(complete=True,check_count=report['check_count'],source_sha256=expected,
                       report_sha256=guard.sha((run/'report.json').read_bytes()),actual_unit_timestep_tested=False,normal_ab_tested=False)
    except BaseException as exc:
        receipt['error'] = type(exc).__name__ + ': ' + str(exc)
    finally:
        if active is not None:
            try: active.kill(); active.wait(timeout=30)
            except BaseException as exc: receipt['final_issues'].append(str(exc))
        for label, check in (
            ('production_unchanged',lambda: all(guard.sha((ROOT/name).read_bytes()) == digest for name,digest in protected.items())),
            ('player_unchanged',lambda: player_before is not None and guard.snapshot(player) == player_before),
            ('private_sources_unchanged',lambda: expected is not None and all(guard.sha((project/name).read_bytes()) == digest for name,digest in expected.items())
                and {path.name for path in project.iterdir() if path.is_file()} - set(expected) <= {'data_smoke.gd.uid'}),
            ('candidate_unchanged',lambda: guard.sha((HERE/'freeze.json').read_bytes()) == args.freeze_sha256 and
                all(guard.sha((HERE/name).read_bytes()) == digest for name,digest in frozen['inputs'].items())),
        ):
            try: receipt[label] = check()
            except BaseException as exc: receipt[label] = False; receipt['final_issues'].append(label+': '+str(exc))
        try:
            receipt['godot_pids_after'] = guard.godot_processes()
            guard.need(not receipt['godot_pids_after'] and lock_owned and lock.read_text(encoding='utf-8') == owner, 'Exit/lock ownership mismatch')
            lock.unlink(); receipt['lock_released'] = True
        except BaseException as exc:
            receipt['lock_released'] = False; receipt['final_issues'].append(str(exc))
        receipt['complete'] = receipt['complete'] and not receipt['final_issues'] and all(receipt.get(key) is True for key in
            ('production_unchanged','player_unchanged','private_sources_unchanged','candidate_unchanged','lock_released'))
        guard.save(run/'receipt.json',receipt)
        print('RECEIPT '+str(run/'receipt.json'),flush=True)
    return 0 if receipt['complete'] else 1


if __name__ == '__main__': raise SystemExit(main())
