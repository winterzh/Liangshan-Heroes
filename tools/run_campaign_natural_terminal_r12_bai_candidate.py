"""Scoped normal campaign terminal/restart acceptance; not the full successor suite."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid

from godot_debug_wire import DebugConnection, stack_frames
from run_workstation_baseline import engines, sha
from run_steam_integration_qa import ROOT, LOCK

IDENTITY_HELPER = ROOT / 'qa/zhu_wounded_20261005/harness/run_daming_admit_v24s.py'
IDENTITY_HELPER_SHA = '049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626'
assert sha(IDENTITY_HELPER)==IDENTITY_HELPER_SHA
_module = importlib.util.spec_from_file_location('natural_terminal_fixed_identity',IDENTITY_HELPER)
_identity = importlib.util.module_from_spec(_module)
_module.loader.exec_module(_identity)

ERRORS = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)')
PROBE = ROOT / 'tools/campaign_natural_terminal_probe.gd'
COORDINATOR = 'res://scripts/run_campaign_progress_coordinator.gd'
WINDOWS = {'after_gen2': 'var saved: Dictionary = _drive_cfg()',
           'after_cfg_before_ack': 'var acknowledged: Dictionary = _life.ack_progress(_ack)'}
OVERLAY = ROOT / 'qa/campaign_progress_recovery_20261008/integrated_v4_r12/scripts'
AUDIT = ROOT / 'qa/campaign_progress_recovery_20261008/SOURCE_AUDIT_V14.json'
SOURCE_REVIEW = ROOT / 'qa/campaign_progress_recovery_20261008/INTEGRATION_SOURCE_REVIEW_V5_R12.json'
GAMEPLAY_MANIFEST = ROOT / 'qa/campaign_progress_recovery_20261008/huangnigang_bai_arrival_candidate_v1/SOURCE.json'
GAMEPLAY_PARENT = ROOT / 'qa/campaign_progress_recovery_20261008/huangnigang_bai_arrival_candidate_v1/level1_huangnigang.gd'
BASE_BRIDGE = Path('D:/CodexTemp/lsh-office-candidate-preparation-20261008/complete_source_bridge_v1.json')
BASELINE = Path('D:/CodexTemp/lsh-office-20261008/20261008_090824_88273489/receipt.json')
ENGINE = Path('C:/Users/rsb/Desktop/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64.exe')


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def pin(path):
    return {'path':str(Path(path).resolve()), 'bytes':Path(path).stat().st_size, 'sha256':sha(path)}


def no_links(path):
    for item in [Path(path),*Path(path).parents]:
        if item.exists() or item.is_symlink():
            assert not item.is_symlink() and not getattr(item.lstat(),'st_file_attributes',0)&0x400, str(item)


def immutable_json(path, value):
    with Path(path).open('x',encoding='utf-8',newline='\n') as stream:
        stream.write(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
        stream.flush();os.fsync(stream.fileno())


def source_spec():
    audit,bridge,baseline,review = map(read,[AUDIT,BASE_BRIDGE,BASELINE,SOURCE_REVIEW])
    assert review['source_version']=='integrated_v4_r12' and review['approved_static_sources_only']
    assert review['source_audit_sha256']==sha(AUDIT) and baseline['complete'] and baseline['engine_sha256']==sha(ENGINE)
    assert bridge['complete'] and bridge['schema']=='office_complete_candidate_source_bridge_v1'
    base=Path(bridge['candidate_root']);no_links(base)
    for row in bridge['candidate_identity']['files']:
        p=base/row['path'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],str(p)
    candidate=[]
    for row in audit['candidate_files']:
        p=ROOT/row['path'];assert p.parent==OVERLAY and p.stat().st_size==row['bytes'] and sha(p)==row['sha256']
        candidate.append({**pin(p),'runtime_path':'scripts/'+p.name})
    assert len(candidate)==14
    gameplay=read(GAMEPLAY_MANIFEST)
    assert gameplay['runtime_path']=='scripts/levels/level1_huangnigang.gd'
    for key in ['production_source','candidate_source']:
        expected=gameplay[key];actual=ROOT/expected['path']
        assert actual.stat().st_size==expected['bytes'] and sha(actual)==expected['sha256']
    assert ROOT/gameplay['candidate_source']['path']==GAMEPLAY_PARENT
    candidate.append({**pin(GAMEPLAY_PARENT),'runtime_path':'scripts/levels/level1_huangnigang.gd'})
    for row in audit['production_sources']:
        p=ROOT/row['path'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256']
    dependencies=[]
    extra=['scripts/run_battle_world_core.gd','scripts/run_level8_unit_contract.gd']
    for row in audit['fixed_script_dependencies']:
        relative=row['runtime'].removeprefix('res://')
        target=OVERLAY/Path(relative).name if (OVERLAY/Path(relative).name).is_file() else base/relative
        actual=pin(target)
        if relative not in extra:assert actual['sha256']==row['source_pin']['sha256'],relative
        dependencies.append({'runtime':row['runtime'],'source':actual})
    lines=(OVERLAY/'run_campaign_progress_coordinator.gd').read_text(encoding='utf-8').splitlines()
    windows={}
    for name,text in WINDOWS.items():
        indexes=[i+1 for i,s in enumerate(lines) if s.strip()==text];assert len(indexes)==1
        windows[name]=indexes[0]
    gameplay_dependencies=[]
    for runtime in sorted(set(re.findall(r'"(res://scripts/[^"\n]+\.gd)"',GAMEPLAY_PARENT.read_text(encoding='utf-8')))):
        relative=runtime.removeprefix('res://');target=base/relative
        assert target.is_file()
        gameplay_dependencies.append({'runtime':runtime,'source':pin(target)})
    dependencies+=gameplay_dependencies
    helpers=[Path(__file__),PROBE,GAMEPLAY_MANIFEST,ROOT/'tools/godot_debug_wire.py',ROOT/'tools/run_workstation_baseline.py',ROOT/'tools/run_steam_integration_qa.py',IDENTITY_HELPER,BASE_BRIDGE,BASELINE,AUDIT,SOURCE_REVIEW,ENGINE]
    spec={'schema':'campaign_natural_terminal_source_spec_v1','helpers':[pin(p) for p in helpers],
          'candidate_files':candidate,'fixed_dependencies':dependencies,'semantic_extra_sources':[pin(base/p) for p in extra],
          'base_bridge_sha256':sha(BASE_BRIDGE),'base_identity':bridge['candidate_identity'],
          'debugger_windows':windows,'scoped_cases':['normal_and_restart','after_gen2_and_restart','after_cfg_before_ack_and_restart'],
          'Steam_disabled':True,'CAMPAIGN_QA_enabled':False,'full_roles_or19_qualified':False}
    digest=hashlib.sha256(json.dumps(spec,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
    return spec,digest,base,bridge


def journal(user):
    parent=user/'continue/v1/local_runs';assert parent.is_dir()
    tokens=[p for p in parent.iterdir() if p.is_dir() and re.fullmatch('[0-9a-f]{32}',p.name)]
    assert len(tokens)==1 and len(list(parent.iterdir()))==1
    directory=tokens[0]/'5088120/1';no_links(directory)
    rows=[];previous='0'*64
    for p in sorted(directory.glob('record_*.json')):
        envelope=read(p);payload=envelope['payload'];record=json.loads(payload)
        fields={'magic','version','app','owner','revision','previous_sha256','payload_bytes','payload_sha256','payload'}
        assert set(envelope)==fields and all(type(v) is str for v in envelope.values())
        assert envelope['magic']=='LH_LOCAL_CONTINUE_LIFECYCLE' and envelope['version']=='1' and envelope['app']=='5088120' and envelope['owner']=='1'
        assert re.fullmatch('[1-9][0-9]*',envelope['revision']) and int(envelope['revision'])<=2147483647
        revision=int(envelope['revision'])
        assert revision==len(rows)+1 and envelope['previous_sha256']==previous
        assert envelope['payload_bytes']==str(len(payload.encode())) and envelope['payload_sha256']==hashlib.sha256(payload.encode()).hexdigest()
        assert p.name=='record_%010d.json'%revision and type(record['generation']) is int and record['generation']==revision
        assert record['token']==tokens[0].name and record['schema']=='local_campaign_continue_lifecycle_v2'
        assert record['context']=={'mode':'campaign','level_id':'level1','waves':0}
        assert record['scope']['owner']=='' and record['scope']['engine_sha256']==sha(ENGINE)
        if rows:assert record['intent']['victory'] and record['intent']['result']['story_complete']
        previous=sha(p);rows.append({'path':str(p),'sha256':previous,'raw_envelope':envelope,'record':record})
    assert 1<=len(rows)<=3
    return {'token':tokens[0].name,'directory':str(directory),'records':rows}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true')
    parser.add_argument('--independent-review',type=Path)
    parser.add_argument('--write-spec',type=Path)
    args=parser.parse_args();spec,digest,base,bridge=source_spec()
    if args.write_spec is not None:
        no_links(args.write_spec);immutable_json(args.write_spec,{'source_spec_sha256':digest,'spec':spec})
    if not args.run:
        print(json.dumps({'preflight':True,'source_spec_sha256':digest,'source_files':len(spec['candidate_files']),'dependencies':len(spec['fixed_dependencies']),'native_started':False,'full_qualified':False}));return
    assert args.independent_review is not None
    review=read(args.independent_review)
    assert review['schema']=='campaign_natural_terminal_independent_review_v1' and review['independent'] and review['static_api_closure_passed']
    assert review['source_spec_sha256']==digest and review['approved_stages']==['natural_terminal_scoped']
    assert review['producer_sha256']==sha(Path(__file__)) and review['probe_sha256']==sha(PROBE)
    pins=spec['helpers']+spec['candidate_files']+spec['semantic_extra_sources']+[pin(args.independent_review)]
    work=Path('D:/CodexTemp/lsh-campaign-natural-terminal-20261008');no_links(work)
    run=work/('natural_terminal_'+uuid.uuid4().hex[:8]);run.mkdir(parents=True,exist_ok=False)
    project=run/'project';project.mkdir()
    receipt={'schema':'campaign_natural_terminal_batch_v1','complete':False,'run':str(run),'source_spec_sha256':digest,
             'source_spec':spec,'independent_review_sha256':sha(args.independent_review),'steps':[],
             'scope':'Fresh natural Huangnigang gen2/CFG/gen3 and two actual interruption/restart windows.',
             'full_roles_ABCD_qualified':False,'original19_faults_qualified':False,'pending_failure_UI_qualified':False,'Steam_rewards_qualified':False}
    child=None;locked=False;listener=None;connection=None;installed=[];post_identity=None
    deadline=time.monotonic()+10800
    def persist():
        (run/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    def integrity():
        for row in pins:
            p=Path(row['path']);assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],str(p)
        for row in installed:
            p=project/row['path'];assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'],str(p)
        if installed:
            current={p.relative_to(project).as_posix() for p in project.rglob('*') if p.is_file() and '.godot' not in p.parts}
            expected={row['path'] for row in installed}
            if post_identity is not None:
                assert current==expected and _identity.installed_identity(project)==post_identity,'Complete installed identity drift'
            else:
                assert expected<=current and all(name.endswith(('.import','.uid')) and (project/name.rsplit('.',1)[0]).is_file() for name in current-expected),'Cold import added non-derived files'
    def release():
        nonlocal locked
        if locked:
            assert LOCK.read_text(encoding='utf-8')==str(run);LOCK.unlink();locked=False
    def idle():
        nonlocal locked
        since=None;notice=0
        while True:
            if time.monotonic()>deadline:raise RuntimeError('Batch deadline')
            if engines() or LOCK.exists():since=None
            elif since is None:since=time.monotonic()
            if time.monotonic()-notice>30:print('WAIT natural terminal: idle60',flush=True);notice=time.monotonic()
            if since is not None and time.monotonic()-since>=60:
                integrity()
                try:
                    with LOCK.open('x',encoding='utf-8') as stream:stream.write(str(run))
                except FileExistsError:since=None;continue
                locked=True
                if engines():release();since=None;continue
                return
            time.sleep(2)
    def profile(name):
        p=run/name;p.mkdir(exist_ok=False)
        for key in ['appdata','localappdata','temp','tmp']:(p/key).mkdir()
        return p
    def phase(label,p,mode=None,stop=None,token='',recover=False):
        nonlocal child,listener,connection
        idle();out=run/('output_'+label);out.mkdir(exist_ok=False);log=out/'native.log'
        nonce=uuid.uuid4().hex;env=os.environ.copy()
        for key in ['CAMPAIGN_QA','LEVEL','SKIRMISH','SKIRMISH_AI','ARENA','SCENARIO','CUSTOM_DEFENSE','AI_FRIENDLY','AI_FRIENDLY_MULT','SCALE_ON','ENEMY_MULT','HERO_MULT','SMOKE_TEST','SCREENSHOT_DIR','AUTO_MICRO','AUTOMICRO','NEWHERO','ABILITY_VIS_AUDIT','GODOT_USER_HOME']:
            env.pop(key,None)
        for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:env[key]=str(p/key.lower())
        env.update(STEAM_DISABLED='1',CAMPAIGN_TERMINAL_OUTPUT=str(out),CAMPAIGN_TERMINAL_PROFILE=str(p),CAMPAIGN_TERMINAL_NONCE=nonce,CAMPAIGN_TERMINAL_MODE=mode or '',CAMPAIGN_TERMINAL_TOKEN=token,CAMPAIGN_TERMINAL_EXPECT_RECOVERY='1' if recover else '0')
        if mode is not None:
            env.update(CAMPAIGN_TERMINAL_IDENTITY_FILE=str(run/'post_cold_identity.json'),CAMPAIGN_TERMINAL_IDENTITY_SHA256=sha(run/'post_cold_identity.json'))
        command=[str(ENGINE),'--path',str(project),'--headless']
        if mode is None:command+=['--editor','--import','--quit']
        else:command+=['--script','res://tools/'+PROBE.name]
        if stop:
            listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen(1);listener.settimeout(.15)
            command+=['--remote-debug','tcp://127.0.0.1:'+str(listener.getsockname()[1])]
        step={'label':label,'command':command,'nonce':nonce,'mode':mode,'complete':False,'process_terminal':False,'profile':str(p),'stop_window':stop,'log':str(log),'output':str(out)}
        receipt['steps'].append(step);persist();print('RUN '+label+' '+str(run),flush=True)
        started=time.monotonic();notice=started;peer=None;stopped=False;armed=False;stop_entered=False
        with log.open('wb') as stream:
            while engines():
                release();idle()
            child=subprocess.Popen(command,env=env,stdout=stream,stderr=subprocess.STDOUT,cwd=project,creationflags=subprocess.CREATE_NO_WINDOW);step['pid']=child.pid;persist()
            while child.poll() is None:
                if engines()-{child.pid}:raise RuntimeError('Foreign engine resumed; whole batch aborted')
                if ERRORS.search(log.read_text(encoding='utf-8',errors='replace')):raise RuntimeError('Native engine error; whole batch aborted')
                if time.monotonic()>deadline or time.monotonic()-started>1800:raise RuntimeError('Bounded native phase deadline')
                if time.monotonic()-notice>=25:print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True);notice=time.monotonic()
                if listener is not None:
                    try:connection,_=listener.accept()
                    except socket.timeout:continue
                    listener.close();listener=None;connection.settimeout(.15);peer=DebugConnection(connection)
                if peer is not None:
                    try:message,_=peer.receive()
                    except socket.timeout:continue
                    except EOFError:
                        if child.poll() is None:raise RuntimeError('Debugger closed while owned child still live')
                        break
                    name,thread,data=message
                    if name=='set_pid':
                        assert data==[child.pid] and not armed
                        peer.command('breakpoint',thread,[COORDINATOR,spec['debugger_windows'][stop],True]);armed=True
                    elif name=='debug_enter':
                        assert armed and not stop_entered and len(data)==4 and data[:3]==[True,'Breakpoint',True] and data[3]==thread
                        stop_entered=True;peer.command('get_stack_dump',thread)
                    elif name=='stack_dump':
                        frames=stack_frames(data)
                        assert stop_entered and frames[0]=={'source':COORDINATOR,'line':spec['debugger_windows'][stop],'function':'retry'}
                        assert any(f['source']=='res://scripts/continue_flow.gd' and f['function']=='_commit_terminal' for f in frames)
                        ready=read(out/'ready_for_terminal.json')
                        assert ready['nonce']==nonce and ready['pid']==child.pid and ready['delivered']==3 and all(c['ok'] for c in ready['checks'])
                        user=Path(ready['actual_user_directory']);no_links(user);assert user.resolve().is_relative_to(p.resolve())
                        actual=journal(user);assert len(actual['records'])==2
                        head=actual['records'][-1]['record'];assert head['state']=='terminal' and head['progress_state']=='pending' and head['victory']
                        assert head['scope']['content_version']==ready['identity']['content_version']
                        cfg=user/'campaign.cfg'
                        if stop=='after_gen2':assert not cfg.exists()
                        else:assert cfg.is_file() and len(cfg.read_bytes())>0
                        step.update(debugger_stack=frames,actual_natural_preterminal=ready,actual_stopped_journal=actual,
                                    stopped_cfg_sha256=sha(cfg) if cfg.is_file() else '',actual_user_directory=str(user),
                                    intentional_owned_process_termination=True,breakpoint_confirmed_ns=time.monotonic_ns())
                        child.kill();stopped=True;break
                else:time.sleep(.2)
            child.wait(timeout=30)
        if connection is not None:connection.close();connection=None
        if listener is not None:listener.close();listener=None
        step.update(exit_code=child.returncode,process_terminal=True,log_sha256=sha(log),engine_errors=len(ERRORS.findall(log.read_text(encoding='utf-8',errors='replace'))))
        assert not step['engine_errors']
        if stop:assert stopped and step['intentional_owned_process_termination']
        else:
            assert child.returncode==0
            if mode is not None:
                report=read(out/'report.json');assert report['schema']=='campaign_natural_terminal_probe_v1' and report['pid']==child.pid and report['nonce']==nonce and report['mode']==mode and report['passed'] and not report['failures'] and all(c['ok'] for c in report['checks'])
                assert report['time_scale']==1 and report['physics_ticks']==60
                expected=read(run/'post_cold_identity.json')['runtime_fields']
                assert all(report['identity'].get(k)==v and type(report['identity'].get(k)) is type(v) for k,v in expected.items())
                user=Path(report['user_directory']);no_links(user);assert user.resolve().is_relative_to(p.resolve())
                actual=journal(user);assert len(actual['records'])==3
                head=actual['records'][-1]['record'];assert head['progress_state']=='applied' and head['progress_receipt']['persisted'] and not head['progress_receipt']['suppressed']
                step.update(report_sha256=sha(out/'report.json'),checks=len(report['checks']),actual_journal=actual,actual_user_directory=str(user),cfg_sha256=sha(user/'campaign.cfg'))
        step['complete']=True;child=None;persist();integrity();release()
        return step,out
    try:
        for row in bridge['candidate_identity']['files']:
            source=base/row['path'];target=project/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes());assert sha(target)==row['sha256']
        for row in spec['candidate_files']:
            source=Path(row['path']);target=project/row['runtime_path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(source.read_bytes());assert sha(target)==row['sha256']
        target=project/'tools'/PROBE.name;target.parent.mkdir(exist_ok=True);target.write_bytes(PROBE.read_bytes())
        installed=[{'path':p.relative_to(project).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(project.rglob('*')) if p.is_file() and '.godot' not in p.parts]
        before_identity=_identity.installed_identity(project)
        receipt['pre_import_installed_files']=installed;receipt['pre_import_runtime_identity']=before_identity;persist()
        phase('import',profile('import_profile'))
        # Cold import may create uid/import descriptors. Freeze their actual bytes
        # once before gameplay; no later runtime/resource/source edits are accepted.
        before={row['path']:row for row in installed}
        after=[{'path':p.relative_to(project).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(project.rglob('*')) if p.is_file() and '.godot' not in p.parts]
        assert all(row==before[row['path']] for row in after if row['path'] in before),'Cold import changed original input bytes'
        assert set(before)<={row['path'] for row in after}
        generated=[row for row in after if row['path'] not in before]
        assert all(row['path'].endswith(('.import','.uid')) and (project/row['path'].rsplit('.',1)[0]).is_file() for row in generated)
        installed=after;post_identity=_identity.installed_identity(project)
        fields={k:post_identity[k] for k in ['content_version','rules_sha256','file_count','total_bytes']}
        fields.update(engine_binary_sha256=sha(ENGINE),provider_sha256=sha(project/'scripts/run_content_identity.gd'))
        immutable_json(run/'post_cold_identity.json',{'schema':'campaign_natural_post_cold_identity_v1','source_spec_sha256':digest,'runtime_fields':fields,'complete_identity':post_identity})
        pins.append(pin(run/'post_cold_identity.json'))
        receipt.update(installed_files=installed,post_import_runtime_identity=post_identity,cold_import_generated_metadata=generated);persist()
        prior_pids=set();results=[]
        for group,stop in [('normal',None),('gen2','after_gen2'),('cfg_ack','after_cfg_before_ack')]:
            p=profile('profile_'+group)
            live,_=phase(group+'_fresh',p,'fresh',stop)
            actual=live['actual_stopped_journal'] if stop else live['actual_journal']
            recovered,_=phase(group+'_restart',p,'restart',token=actual['token'],recover=bool(stop))
            assert live['pid']!=recovered['pid'] and not {live['pid'],recovered['pid']}&prior_pids
            prior_pids|={live['pid'],recovered['pid']}
            after=recovered['actual_journal']
            assert [row['sha256'] for row in after['records'][:2]]==[row['sha256'] for row in actual['records'][:2]]
            assert after['records'][-1]['record']['intent']==actual['records'][-1]['record']['intent']
            if stop!='after_gen2':assert recovered['cfg_sha256']==(live['stopped_cfg_sha256'] if stop else live['cfg_sha256'])
            results.append({'group':group,'live_pid':live['pid'],'restart_pid':recovered['pid'],'token':actual['token'],'actual_restart_gen3':True})
        receipt.update(complete=True,scoped_groups=results,natural_Huangnigang_recovery_qualified=True)
    except Exception as error:
        receipt['failure']=repr(error)
        if child is not None:
            if child.poll() is None:child.kill()
            child.wait(timeout=30)
            step=receipt['steps'][-1];log=Path(step['log'])
            step.update(process_terminal=True,exit_code=child.returncode,log_sha256=sha(log),engine_errors=len(ERRORS.findall(log.read_text(encoding='utf-8',errors='replace'))))
    finally:
        if connection is not None:connection.close()
        if listener is not None:listener.close()
        try:release()
        except Exception as error:receipt['lock_release_failure']=repr(error);receipt['complete']=False
        receipt['lock_released']=not locked;persist()
    print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure'),'full_qualified':False}))
    raise SystemExit(0 if receipt['complete'] else 1)


if __name__=='__main__':main()
