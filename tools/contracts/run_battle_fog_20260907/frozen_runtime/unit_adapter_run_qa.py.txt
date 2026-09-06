"""One Unit value-adapter QA against root sources, with a new isolated profile.
Default checks frozen sources only; --run owns one actual headless Godot child.
"""
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

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
LOCK=ROOT/'.godot/redraw_rejection_source.lock'
GUARD=ROOT/'tools/run_reduced_effects_qa.py'
SCRIPT='scratchpad/run_unit_state_adapter/qa_driver.gd'
ERROR=re.compile(r'SCRIPT ERROR|^ERROR:|^WARNING:|\bFAIL\b|Unicode parsing error|Parse Error|Parser Error',re.M|re.I)

def need(ok,message):
    if not ok:raise RuntimeError(message)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def save(path,value):path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def verify_frozen(pins,pins_sha,contract,contract_sha):
    need(sha((HERE/'runner_contract.json').read_bytes())==contract_sha,'Runner contract changed')
    need(sha((HERE/'pins.json').read_bytes())==pins_sha==contract['adapter_pins_raw_sha256'],'Frozen adapter pins changed')
    need(sha(Path(__file__).read_bytes())==contract['runner_raw_sha256'],'Runner changed')
    for name,expected in pins['raw_sha256'].items():need(sha((HERE/name).read_bytes())==expected,'Frozen draft changed: '+name)
    need(sha((ROOT/'scripts/unit.gd').read_bytes())==pins['source_unit_raw_sha256'],'Actual Unit changed')
    need(sha((ROOT/'scratchpad/defense_resume_schema.md').read_bytes())==pins['schema_index_raw_sha256'],'Original field index changed')
    for name in ['scratchpad/run_state_value_codec/value_codec.gd','scripts/run_state_value_codec.gd']:
        need(sha((ROOT/name).read_bytes())==pins['value_codec_raw_sha256'],'Frozen/promoted codec changed: '+name)

def run_process(guard,exe,out,env,timeout):
    """Same exact-handle lifecycle as the public guard, with headless --script."""
    guard.require_exclusive_godot()
    command=[str(exe),'--headless','--path',str(ROOT),'--script','res://'+SCRIPT]
    process=None;failure=None;cleanup=None;confirmed=False;code=None
    log_path=out/'process.log';started=time.monotonic()
    with log_path.open('xb') as log:
        try:
            process=subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            guard.ACTIVE_PROCESS=process
            code=process.wait(timeout=timeout)
        except BaseException as error:
            failure=error
            if process is not None:
                try:
                    if process.poll() is None:process.kill()
                    code=process.wait(timeout=30)
                except BaseException as error2:cleanup=type(error2).__name__+': '+str(error2)
        finally:
            if process is not None:
                try:
                    code=process.poll();confirmed=code is not None
                    if confirmed:guard.ACTIVE_PROCESS=None
                except BaseException as error2:cleanup=type(error2).__name__+': '+str(error2)
    raw_log=log_path.read_bytes();decode_error=None;errors=[]
    try:
        text=raw_log.decode('utf-8')
        errors=[line for line in text.splitlines() if ERROR.search(line)]
    except UnicodeDecodeError as error:decode_error=str(error)
    result={'command':command,'child_pid':process.pid if process else None,'exit_code':code,
        'child_exit_confirmed':confirmed,'timed_out':isinstance(failure,subprocess.TimeoutExpired),
        'exception':None if failure is None else type(failure).__name__+': '+str(failure),
        'cleanup_error':cleanup,'log_decoding_error':decode_error,'matched_errors':errors,
        'log_raw_sha256':sha(raw_log),'wall_seconds':time.monotonic()-started,'scope':'single Unit value QA, not gameplay restore'}
    save(out/'process_receipt.json',result)
    if failure is not None:raise failure
    need(confirmed and cleanup is None,'Exact child exit unconfirmed; retain shared lock')
    guard.require_exclusive_godot()
    need(code==0 and decode_error is None and not errors,'Engine exit/Unicode/parser/diagnostics rejected')
    return result

def validate_report(out,manifest,manifest_sha,process,private_user):
    report=read(out/'report.json')
    need(report.get('schema')==1 and report.get('run_id')==manifest['run_id'],'Wrong report identity')
    need(report.get('process_id')==process['child_pid'] and report.get('manifest_sha256')==manifest_sha,'Report PID/manifest mismatch')
    need(Path(report['actual_user_dir']).resolve()==private_user.resolve(),'Actual user:// escaped private profile')
    need(report.get('source_sha256')==manifest['source_sha256'],'Runtime sources differ')
    checks=report.get('checks',[])
    need(isinstance(checks,list) and len(checks)>=45 and report.get('passed') is True and report.get('failures')==[], 'Missing/failed checks')
    need(all(isinstance(row,dict) and row.get('passed') is True for row in checks),'Check rows contradict passed')
    labels=[row['label'] for row in checks]
    for label in [
        'different/missing Unit declarations refused before explicit access',
        'actual production Unit instance without setup or ticking',
        'all 241 declaration values plus two inherited values validated',
        'non-default live-state values capture',
        'capture neither consumes RNG nor emits Unit signals',
        'missing timer never silently defaults',
        'freed references are deferred explicitly, never flattened into null values',
        'Object in effective definition rejected without serializing it',
        'freed subject rejected']:
        need(labels.count(label)==1,'Incomplete real QA sequence: '+label)
    coverage=report.get('coverage',{})
    need(coverage.get('declared_fields')==272 and coverage.get('captured_declared_values')==241 and coverage.get('inherited_values')==['position','modulate'],'Coverage changed')
    catalog=read(HERE/'field_catalog.json')['fields']
    expected_deferred={row['field'] for row in catalog if row['handling'] not in ['captured_value','visual_cache_omitted']}
    expected_visual={row['field'] for row in catalog if row['handling']=='visual_cache_omitted'}
    need(len(coverage.get('deferred_fields',[]))==26 and set(coverage['deferred_fields'])==expected_deferred,'Deferred fields lost/duplicated')
    need(len(coverage.get('omitted_visual_fields',[]))==5 and set(coverage['omitted_visual_fields'])==expected_visual,'Visual boundary changed')
    for key in ['restore_ready','references_encoded','metadata_capture_implemented','business_definition_validated']:
        need(coverage.get(key) is False,'Incomplete scope falsely marked complete: '+key)
    need(report.get('restore_ready') is False and report.get('battle_resume_tested') is False,'Value QA cannot claim full restore')
    return report

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true');parser.add_argument('--godot')
    parser.add_argument('--timeout',type=int,default=120);args=parser.parse_args()
    need(30<=args.timeout<=240,'Timeout must be 30..240 seconds')
    pins=read(HERE/'pins.json');pins_sha=sha((HERE/'pins.json').read_bytes());contract=read(HERE/'runner_contract.json');contract_sha=sha((HERE/'runner_contract.json').read_bytes())
    need(contract.get('schema')==1,'Unknown runner contract')
    verify_frozen(pins,pins_sha,contract,contract_sha)
    if not args.run:
        print(json.dumps({'preflight':True,'frozen_sources_match':True,'godot_run':False,'no_project_copy':True}));return 0
    guard_raw=GUARD.read_bytes()
    guard=types.ModuleType('unit_adapter_public_guard');guard.__file__=str(GUARD)
    exec(compile(guard_raw.decode('utf-8-sig'),str(GUARD),'exec'),guard.__dict__)
    exe=Path(guard.resolve_godot(args.godot))
    need(not re.search(r'[._-]console\.exe$',exe.name,re.I),'Actual non-console executable required')
    guard.no_link(exe);guard.require_exclusive_godot();need(not LOCK.exists(),'Shared Godot slot occupied')
    name=guard.project_name(ROOT)
    original_appdata=Path(os.environ['APPDATA'])
    real_user=original_appdata/'Godot/app_userdata'/name
    protected=guard.signatures(real_user)
    for boundary in [ROOT,ROOT/'.godot',HERE.parent,HERE,HERE/'runs']:
        if boundary.exists():guard.no_link(boundary)
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    out=HERE/'runs'/stamp;out.mkdir(parents=True,exist_ok=False)
    guard.no_link(HERE);guard.no_link(out)
    token=str(os.getpid())+'|'+str(out)
    result={'schema':1,'complete':False,'lock_released':False,'godot_run':False,'no_project_copy':True,
        'source_mutations':False,'protected_player_before':protected,'adapter_pins':pins,'runner_contract':contract,'runner_contract_raw_sha256':contract_sha,
        'engine_sha256':sha(exe.read_bytes()),'restore_ready':False}
    with LOCK.open('x',encoding='utf-8') as file:file.write(token)
    source=None
    try:
        guard.require_exclusive_godot();verify_frozen(pins,pins_sha,contract,contract_sha)
        source=guard.source_receipt(ROOT)
        need(source['raw_file_sha256']['tools/run_reduced_effects_qa.py']==sha(guard_raw),'Public guard changed while loading')
        save(out/'sources.json',source)
        profile=out/'private_profile';user=profile/'appdata/Godot/app_userdata'/name
        user.mkdir(parents=True,exist_ok=False)
        (profile/'localappdata').mkdir();(profile/'temp').mkdir()
        env,controls=guard.environment(source,out,profile,user)
        for key in list(env):
            if key.startswith(('UNIT_ADAPTER_','ANIM_LOAD_','FIRST_USE_','VALUE_CODEC_','STORE_QA_','REDRAW_','SEPARATION_','REDUCED_EFFECTS_')):env.pop(key)
        env.update(APPDATA=str(profile/'appdata'),LOCALAPPDATA=str(profile/'localappdata'),TEMP=str(profile/'temp'),TMP=str(profile/'temp'))
        manifest={'schema':1,'run_id':stamp,'private_user':str(user),'report':str(out/'report.json'),'source_sha256':{
            'scripts/unit.gd':pins['source_unit_raw_sha256'],
            'scripts/run_state_value_codec.gd':pins['value_codec_raw_sha256'],
            'scratchpad/run_state_value_codec/value_codec.gd':pins['value_codec_raw_sha256'],
            'scratchpad/run_unit_state_adapter/unit_values.gd':pins['raw_sha256']['unit_values.gd'],
            SCRIPT:pins['raw_sha256']['qa_driver.gd'],
            'project.godot':source['raw_file_sha256']['project.godot']}}
        manifest_path=out/'manifest.json';save(manifest_path,manifest);manifest_sha=sha(manifest_path.read_bytes())
        env['UNIT_ADAPTER_QA_MANIFEST']=str(manifest_path)
        save(out/'configuration.json',{'private_project_source':str(ROOT),'private_profile':str(profile),
            'private_user':str(user),'temp':str(profile/'temp'),'controlled_production_switches':controls,
            'manifest_sha256':manifest_sha,'read_only_source_root':True})
        need(guard.signatures(real_user)==protected,'Player preferences changed before launch')
        result['godot_run']=True
        process=run_process(guard,exe,out,env,args.timeout)
        need(sha(manifest_path.read_bytes())==manifest_sha,'Manifest drifted')
        report=validate_report(out,manifest,manifest_sha,process,user)
        verify_frozen(pins,pins_sha,contract,contract_sha)
        need(guard.source_receipt(ROOT)==source,'Root source path set or bytes changed')
        need(guard.signatures(real_user)==protected,'Real player preferences changed')
        source_checks=sum(row['label'].startswith(('runtime source ','source unchanged ')) for row in report['checks'])
        result.update(complete=True,process_id=process['child_pid'],exit_code=process['exit_code'],checks=len(report['checks']),
            source_checks=source_checks,other_checks=len(report['checks'])-source_checks,
            source_combined_sha256=source['combined_sha256'],source_files=len(source['raw_file_sha256']),
            report_raw_sha256=sha((out/'report.json').read_bytes()),manifest_raw_sha256=manifest_sha)
    except BaseException as error:
        result['error']=type(error).__name__+': '+str(error)
        raise
    finally:
        try:
            guard.require_exclusive_godot();verify_frozen(pins,pins_sha,contract,contract_sha)
            need(source is not None and guard.source_receipt(ROOT)==source,'Source verification failed; retain lock')
            need(guard.signatures(real_user)==protected,'Protected profile drifted; retain lock')
            need(LOCK.read_text(encoding='utf-8')==token,'Shared lock ownership changed')
            result['source_unchanged']=True;result['protected_player_after']=guard.signatures(real_user)
            LOCK.unlink();result['lock_released']=True
        except BaseException as error:result.update(complete=False,final_guard_error=type(error).__name__+': '+str(error))
        save(out/'receipt.json',result)
        print(json.dumps({'run':str(out),'complete':result['complete'],'lock_released':result['lock_released']}))
    return 0 if result['complete'] and result['lock_released'] else 2

if __name__=='__main__':sys.exit(main())
