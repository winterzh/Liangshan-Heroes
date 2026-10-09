"""Import and ordinary-menu startup only; no continuation or recovery qualification."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid

from run_workstation_baseline import engines, foreign_engines, sha
from run_steam_integration_qa import ROOT, LOCK

ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--base-bridge', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--run', action='store_true')
    args = parser.parse_args()
    candidate = args.candidate.resolve(strict=True)
    assert candidate.is_relative_to(ROOT / 'qa/campaign_progress_recovery_20261008')
    bridge = json.loads(args.base_bridge.read_text(encoding='utf-8'))
    baseline = json.loads(args.baseline.read_text(encoding='utf-8'))
    engine = args.godot.resolve(strict=True)
    assert bridge['schema'] == 'office_complete_candidate_source_bridge_v1' and bridge['complete']
    assert baseline['complete'] and baseline['engine_sha256'] == sha(engine)
    base = Path(bridge['candidate_root'])
    overlay = sorted(candidate.glob('*.gd'))
    assert len(overlay) == 14
    pins = [{'path':str(p), 'bytes':p.stat().st_size, 'sha256':sha(p)} for p in overlay]
    helpers = [{'path':str(p), 'sha256':sha(p)} for p in [Path(__file__),
        ROOT / 'tools/run_workstation_baseline.py', ROOT / 'tools/run_steam_integration_qa.py', args.base_bridge, args.baseline]]
    def verified():
        for row in pins + helpers:
            assert sha(Path(row['path'])) == row['sha256'], row['path']
        assert sha(engine) == baseline['engine_sha256']
    verified()
    if not args.run:
        print(json.dumps({'preflight':True,'candidate_files':len(pins),'source_pins_verified':True,
                          'native_started':False,'player_feature_qualified':False}))
        return
    work = Path('D:/CodexTemp/lsh-campaign-integration-20261008')
    for p in [work,*work.parents]:
        assert not p.exists() or not (p.is_symlink() or getattr(p.lstat(),'st_file_attributes',0) & 0x400)
    run = work / ('integration_parse_' + uuid.uuid4().hex[:8])
    run.mkdir(parents=True,exist_ok=False)
    project = run / 'project'; project.mkdir()
    receipt = {'schema':'campaign_integration_parse_v1','complete':False,'run':str(run),
               'engine_sha256':sha(engine),'base_bridge_sha256':sha(args.base_bridge),
               'candidate_source_pins':pins,'helper_pins':helpers,'installed_inputs':[], 'steps':[],
               'scope':'Actual isolated full-source import and ordinary headless menu startup only.',
               'continuation_qualified':False,'gen2_cfg_ack_recovery_qualified':False,
               'player_UI_qualified':False,'reward_qualified':False}
    def persist():
        (run / 'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    child = None; locked = False
    deadline = time.monotonic() + 3600
    def idle_and_lock():
        nonlocal locked
        idle = None; notice = 0.0
        while True:
            if time.monotonic() >= deadline: raise RuntimeError('Bounded parse batch deadline')
            if engines() or LOCK.exists(): idle = None
            elif idle is None: idle = time.monotonic()
            if time.monotonic()-notice >= 30:
                print('WAIT integration parse: continuous natural engine idle',flush=True);notice=time.monotonic()
            if idle is not None and time.monotonic()-idle >= 60:
                verified()
                try:
                    with LOCK.open('x',encoding='utf-8') as stream: stream.write(str(run))
                except FileExistsError:
                    idle=None;continue
                locked=True
                if engines():
                    release_lock();idle=None;continue
                return
            time.sleep(2)
    def release_lock():
        nonlocal locked
        if locked:
            if LOCK.read_text(encoding='utf-8') != str(run): raise RuntimeError('Shared lease ownership changed')
            LOCK.unlink();locked=False
    try:
        print('PREPARE '+str(run),flush=True)
        for row in bridge['candidate_identity']['files']:
            source=base/row['path']; data=source.read_bytes()
            assert len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256'],source
            target=project/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        frozen = run/'candidate_source';frozen.mkdir()
        for source in overlay:
            data=source.read_bytes();(frozen/source.name).write_bytes(data);(project/'scripts'/source.name).write_bytes(data)
        installed=[p for p in sorted(project.rglob('*')) if p.is_file()]
        receipt['installed_inputs']=[{'path':str(p.relative_to(project)),'bytes':p.stat().st_size,'sha256':sha(p)} for p in installed]
        persist()
        env=os.environ.copy()
        for key in list(env):
            if key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key.startswith('STEAM_') or key in {
                'LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO','SMOKE_TEST','SCREENSHOT_DIR','GODOT_USER_HOME'}:
                env.pop(key)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
            folder=run/'profile'/key.lower();folder.mkdir(parents=True);env[key]=str(folder)
        env['STEAM_DISABLED']='1'
        for name, args_native in [('import',['--headless','--editor','--import','--quit']),
                                  ('ordinary_menu_startup',['--headless','--quit-after','180'])]:
            idle_and_lock()
            for row in receipt['installed_inputs']:
                assert sha(project/row['path'])==row['sha256'],row['path']
            log=run/(name+'.log');command=[str(engine),'--path',str(project),*args_native]
            step={'case':name,'command':command,'process_terminal':False,'complete':False}
            receipt['steps'].append(step);persist()
            print('RUN '+name+' '+str(run),flush=True)
            with log.open('wb') as stream:
                child=subprocess.Popen(command,cwd=project,env=env,stdout=stream,stderr=subprocess.STDOUT,
                                       creationflags=subprocess.CREATE_NO_WINDOW)
                step['pid']=child.pid;persist()
                started=time.monotonic()
                while child.poll() is None:
                    if time.monotonic()-started>900: raise RuntimeError(name+' timeout')
                    foreign=foreign_engines(child.pid)
                    if foreign:
                        receipt['foreign_engine_pids']=foreign
                        raise RuntimeError('Shared engine entered during '+name)
                    time.sleep(2)
                step.update(exit_code=child.returncode,process_terminal=True,log_sha256=sha(log),
                            engine_errors=len(ERRORS.findall(log.read_text(encoding='utf-8',errors='replace'))))
                persist()
                if child.returncode != 0 or step['engine_errors']: raise RuntimeError(name+' failed')
                step['complete']=True;persist()
            release_lock();child=None
        verified()
        for row in receipt['installed_inputs']:
            assert sha(project/row['path'])==row['sha256'],row['path']
        receipt['complete']=True
    except BaseException as exc:
        receipt['failure']=repr(exc)
        raise
    finally:
        if child is not None and child.poll() is None:
            child.kill();child.wait(timeout=60)
            receipt['owned_process_stopped']=child.pid
        if child is not None and receipt['steps']:
            receipt['steps'][-1].update(process_terminal=child.poll() is not None,exit_code=child.returncode)
        release_lock();receipt['lock_released']=True;persist()
        print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure')}),flush=True)

if __name__=='__main__': main()
