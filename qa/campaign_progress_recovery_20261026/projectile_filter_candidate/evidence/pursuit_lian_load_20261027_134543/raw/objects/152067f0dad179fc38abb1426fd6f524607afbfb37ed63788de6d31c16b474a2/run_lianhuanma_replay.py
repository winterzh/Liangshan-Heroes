"""Replay unchanged Level4 victory/loss workers on the complete b22 source.

Default checks named sources only. --run requires its own successful cold import
and runs the selected four/three processes, never an old runtime qualification.
"""
from __future__ import annotations
import argparse, ast, importlib.util, json, subprocess, sys, time, traceback, uuid
from pathlib import Path
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
QA=HERE.parent
CONTRACT=HERE/'tests/lianhuanma_replay'
CONTENT='source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132'
spec=importlib.util.spec_from_file_location('lhm_b22_preparation',HERE/'integration_3365/prepare_projectile.py')
prep=importlib.util.module_from_spec(spec);spec.loader.exec_module(prep)
p,h,require=prep.p,prep.h,prep.require
ROUTES={
 'victory':{'directory':'lianhuanma','host':'run_lianhuanma_terminal.py','prefix':'LT_',
  'workers':('bootstrap.gd','base.gd','terminal.gd','policy.gd','driver.gd'),
  'modes':('save_training','resume_training','resume_victory','reject_terminal'),
  'provenance_schema':'lianhuanma_terminal_external_binding_sources_v1','report_schema':'campaign_lianhuanma_terminal_v2'},
 'loss':{'directory':'lianhuanma_loss','host':'run_lianhuanma_loss.py','prefix':'LL_',
  'workers':('bootstrap.gd','base.gd','terminal.gd','driver.gd'),
  'modes':('save_before_loss','resume_loss','reject_terminal'),
  'provenance_schema':'lianhuanma_loss_external_sources_v1','report_schema':'campaign_lianhuanma_loss_v1'}}
FALSE_FLAGS=('native_sdk_qualified','public_continue_qualified','human_acceptance','native_release_tested','full_campaign_qualified','full_61_qualified','published')

def source_pins():
 own=h.read(CONTRACT/'sources.json');require(own.get('schema')=='b22_lianhuanma_replay_sources_v1','Explicit replay contract required')
 require(own.get('source_identity')==CONTENT and own.get('candidate_scripts')==26 and own.get('native_assets')==1,'Fixed b22/26/one native only')
 current={Path(__file__).resolve(),CONTRACT/'README.md'}
 rows=own.get('files',[]);require(len(rows)==2 and {ROOT/r['path'] for r in rows}==current,'Exact replay host and README required')
 required=set()
 for label,route in ROUTES.items():
  directory=QA/'tests'/route['directory'];path=directory/'provenance.json';doc=h.read(path)
  expected={QA/route['host'],QA/'lianhuanma_candidate_binding.py',directory/'README.md',*(directory/n for n in route['workers'])}
  actual=doc.get('files',[])
  require(doc.get('schema')==route['provenance_schema'] and len(actual)==len(expected) and {ROOT/r['path'] for r in actual}==expected,'Exact original '+label+' provenance required')
  for row in actual:
   path_input=prep.inside(ROOT,row['path']);require(h.sha(path_input)==row['sha256'] and p.fs(path_input).stat().st_size==row['bytes'],'Original worker provenance changed')
  required.update(expected);required.add(path)
 required.update(Path(m.__file__).resolve() for m in (prep,p,h,h.common,h.shared,h.identity))
 required.add(ROOT/'tools/run_campaign_level_state_qa.py')
 dependencies=own.get('dependencies',[])
 require(len(dependencies)==len(required) and {ROOT/r['path'] for r in dependencies}==required,'All and only named current workers/helpers required; historical derived_from are not runtime dependencies')
 pins={}
 for row in [*rows,*dependencies]:
  path=prep.inside(ROOT,row['path']);require(path.suffix.lower() not in ('.exe','.dll','.pck'),'Named default must not hash binaries')
  p.pin(path,pins,row['sha256']);require(p.fs(path).stat().st_size==row['bytes'],'Named bytes changed')
  if path.suffix=='.py':ast.parse(p.fs(path).read_text(encoding='utf-8-sig'),filename=str(path))
 p.pin(CONTRACT/'sources.json',pins)
 return pins

def preflight(base):
 state=prep.prepared_state(base)
 require(state['validation_level']=='full_new_freeze_and_own_import' and state['content_version']==CONTENT and state['cold_import_qualified'] is True
  and state['run_base']==Path(base).resolve() and state['project']==state['run_base']/'project','Complete b22 with its own successful first cold import required')
 manifest=h.read(state['run_base']/'candidate_manifest.json')
 require(len(manifest['files'])==26 and len(manifest['native_assets'])==1,'Exact combined script/native list required')
 prep.merge_pins(state['pins'],source_pins());p.verify_pins(state['pins']);return state

def execute(args):
 output=ROOT/'.godot/lianhuanma_b22_replay_20261027'/h.stamp();h.identity.no_links(output);p.fs(output).mkdir(parents=True,exist_ok=False)
 labels=['victory','loss'] if args.route=='both' else [args.route]
 receipt={'schema':'b22_lianhuanma_replay_v1','complete':False,'steps':[],'reports':[],'attempted_modes':[],'routes':{},'post_errors':[],
  'selected_routes':labels,'source_identity_expected':CONTENT,'runner_sha256':h.sha(__file__),'source_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  'source_victory_chain_passed':False,'source_loss_chain_passed':False,'both_routes_qualified':False,**{k:False for k in FALSE_FLAGS}}
 state=None;pins={};locked=False;owner=str(output);pids=set();nonces=set();route_nonces=set()
 try:
  start=time.monotonic()
  while not locked:
   if not p.fs(h.shared.LOCK).exists() and not h.running():
    try:
     with p.fs(h.shared.LOCK).open('x',encoding='utf-8') as stream:stream.write(owner)
     locked=True;break
    except FileExistsError:pass
   require(time.monotonic()-start<args.wait_lane,'Shared native lane occupied; no child started');time.sleep(1)
  require(not h.running(),'Engine appeared before admission')
  state=preflight(args.base_run);pins=state['pins'];project,engine=state['project'],state['engine']
  manifest_sha=pins[str(state['run_base']/'candidate_manifest.json')]
  receipt.update(base_run=str(state['run_base']),project=str(project),source_identity=state['content_version'],engine_sha256=state['engine_sha256'],
   candidate_manifest_sha256=manifest_sha,cold_import_qualified=True,initial_identity_passed=True,import_receipts=state['imports'])
  for name,digest in list(pins.items()):
   source=Path(name)
   if source.suffix.lower()=='.exe':continue
   require(source.is_relative_to(ROOT),'External provenance rejected')
   target=output/'runner_inputs'/source.relative_to(ROOT);p.copy(source,target,digest);p.pin(target,pins,digest)
  for label in labels:
   route=ROUTES[label];original=QA/'tests'/route['directory'];workers=output/'workers'/label;p.fs(workers).mkdir(parents=True)
   for name in route['workers']:p.copy(original/name,workers/name,pins[str(original/name)]);p.pin(workers/name,pins,pins[str(original/name)])
   binding=workers/'bindings.json';h.save(p.fs(binding),{n:pins[str(workers/n)] for n in route['workers']});p.pin(binding,pins)
   nonce=uuid.uuid4().hex;require(nonce not in route_nonces,'Independent route batch nonce required');route_nonces.add(nonce);profile=Path(ROOT.anchor)/'CodexQA/lianreplay'/output.name/label
   h.identity.no_links(profile);p.fs(profile).mkdir(parents=True,exist_ok=False)
   row={'complete':False,'profile':str(profile),'batch_nonce':nonce,'process_ids':[],'modes':list(route['modes'])};receipt['routes'][label]=row
   prefix=route['prefix'];env=h.common.private_environment(profile)
   for key in list(env):
    if key.startswith(('LT_','LL_','GT_','GVT_','GLS_','DF_','DN_','UST_','UCR_','USR_','UTR_','URF_','P19_','LSH_CONTINUE_FLOW_','CR_','HG_','CH_','LHMR_','RS_')):env.pop(key)
   env.update(STEAM_DISABLED='1',CAMPAIGN_QA='',LSH_CONTINUE_FLOW_QA='1',LSH_CONTINUE_FLOW_PROFILE=str(profile),LSH_LANGUAGE='zh_CN')
   env.update({prefix+'PROFILE':str(profile),prefix+'PROJECT':str(project),prefix+'WORKERS':str(workers),prefix+'BINDINGS':str(binding),
    prefix+'BINDINGS_SHA256':pins[str(binding)],prefix+'NONCE':nonce,prefix+'CANDIDATE_SHA256':manifest_sha,
    prefix+'PROVENANCE_SHA256':pins[str(original/'provenance.json')]})
   previous=None
   for mode in route['modes']:
    p.verify_pins(pins);stage=output/label/mode;p.fs(stage).mkdir(parents=True);report_path=stage/'report.json'
    process_nonce=uuid.uuid4().hex;require(process_nonce not in nonces,'Process nonce must be unique')
    child_env=dict(env);child_env.update({prefix+'MODE':mode,prefix+'REPORT':str(report_path),prefix+'PROCESS_NONCE':process_nonce})
    if previous:child_env.update({prefix+'PREVIOUS':str(previous),prefix+'PREVIOUS_SHA256':pins[str(previous)]})
    receipt['attempted_modes'].append({'route':label,'mode':mode,'process_nonce':process_nonce});report=None;before=len(receipt['steps'])
    try:
     h.common.process_step(engine,project,child_env,p.fs(stage),mode,['--resolution','1280x720','--position','30000,30000','--script',str(workers/'bootstrap.gd')],args.timeout,'gl_compatibility',h.running,receipt['steps'])
    finally:
     log=stage/(mode+'.log')
     if p.fs(log).is_file():p.pin(log,pins)
     if p.fs(report_path).is_file():
      p.pin(report_path,pins);report=h.read(p.fs(report_path));receipt['reports'].append({'route':label,'mode':mode,'path':str(report_path),'sha256':pins[str(report_path)],'checks':len(report.get('checks',[])),'passed':report.get('passed',False)})
     if len(receipt['steps'])==before+1:receipt['steps'][-1].update(route=label,mode=mode,process_nonce=process_nonce)
    require(report is not None and report.get('schema')==route['report_schema'] and report.get('passed') is True and report.get('stage_completed') is True
     and report.get('failures')==[] and report.get('checks') and all(c.get('passed') is True for c in report['checks']),'Native route failed or incomplete: '+label+'/'+mode)
    require(report.get('mode')==mode and report.get('profile')==str(profile) and report.get('batch_nonce')==nonce and report.get('process_nonce')==process_nonce
     and report.get('slot_root')=='user://continue/v1' and report.get('candidate_manifest_sha256')==manifest_sha
     and report.get('identity',{}).get('content_version')==CONTENT and report['identity'].get('engine_sha256')==state['engine_sha256'] and report['identity'].get('source_mode') is True
     and report.get('simulation_time_scale')==1 and report.get('no_gameplay_state_injection') is True,'Actual private scope/source/clock identity required')
    require(report.get('full_story_required') is (label=='victory'),'Original full-story victory boundary required')
    if label=='loss':require(report.get('natural_loss_required') is True and report.get('provenance_sha256')==pins[str(original/'provenance.json')],'Natural loss and original driver provenance required')
    require(all(report.get(k) is False for k in ('public_continue_qualified','native_sdk_qualified','native_release_tested','human_acceptance')),'Source replay cannot grant wider qualification')
    if mode in ('save_training','resume_training','save_before_loss'):require(report.get('save_exit_observed') is True and report.get('exit_reason')=='continue_saved','Production SaveAndExit must own save stages')
    if mode=='reject_terminal':
     refusal=report.get('observations',{}).get('terminal_refusal',{});require(refusal.get('ok') is False and refusal.get('code')=='LOCAL_RUN_TERMINAL','Original terminal token must be rejected')
    require(len(receipt['steps'])==before+1,'Exactly one owned terminal process required');step=receipt['steps'][-1];pid=report.get('pid')
    require(type(pid) is int and pid>0 and pid==step.get('pid') and pid not in pids and step.get('exit_code')==0 and step.get('passed') is True
     and step.get('errors')==[] and step.get('log_sha256')==pins[str(log)],'Actual unique PID/exit/log required')
    pids.add(pid);nonces.add(process_nonce);row['process_ids'].append(pid);previous=report_path
   row['complete']=len(row['process_ids'])==len(route['modes'])
 except BaseException as error:receipt.update(error=repr(error),traceback=traceback.format_exc())
 finally:
  def post(name,fn):
   try:fn()
   except BaseException as error:receipt['post_errors'].append({'phase':name,'error':repr(error)})
  def final_identity():
   require(state is not None,'Full admission did not complete');h.assert_runtime_current(state['run_base']);h.identity.verify_generated(state['project'],state['generation']);p.verify_pins(pins)
   require(h.sha(state['engine'])==state['engine_sha256'],'Engine bytes changed');receipt['final_identity_passed']=True
  post('final source identity',final_identity)
  receipt['child_process_terminal']=len(receipt['steps'])==len(receipt['attempted_modes']) and all(type(s.get('pid')) is int and s['pid']>0 and type(s.get('exit_code')) is int for s in receipt['steps'])
  def release():
   receipt['engine_lane_idle']=not h.running();receipt['lock_ownership_confirmed']=bool(locked and p.fs(h.shared.LOCK).is_file() and p.fs(h.shared.LOCK).read_text(encoding='utf-8')==owner)
   if receipt['engine_lane_idle'] and receipt['lock_ownership_confirmed'] and receipt['child_process_terminal']:p.fs(h.shared.LOCK).unlink();receipt['lock_released']=not p.fs(h.shared.LOCK).exists()
  post('owned terminal lane release',release)
  receipt['complete']=bool(receipt.get('final_identity_passed') and receipt['child_process_terminal'] and receipt.get('lock_released') and len(receipt['routes'])==len(labels)
   and all(r['complete'] for r in receipt['routes'].values()) and not receipt['post_errors'] and 'error' not in receipt)
  terminal_ok=bool(receipt.get('final_identity_passed') and receipt['child_process_terminal'] and receipt.get('lock_released') and not receipt['post_errors'])
  receipt['source_victory_chain_passed']=bool(terminal_ok and receipt['routes'].get('victory',{}).get('complete'));receipt['source_loss_chain_passed']=bool(terminal_ok and receipt['routes'].get('loss',{}).get('complete'))
  receipt['both_routes_qualified']=bool(receipt['complete'] and labels==['victory','loss']);receipt['actual_process_count']=len(receipt['steps']);receipt['actual_checks']=sum(r['checks'] for r in receipt['reports']);receipt['pinned_files']=pins
  h.save(p.fs(output/'receipt.json'),receipt)
 print(json.dumps({'output':str(output),'complete':receipt['complete'],'actual_process_count':len(receipt['steps']),'error':receipt.get('error')},ensure_ascii=False),flush=True)
 if not receipt['complete']:raise SystemExit(1)

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--base-run',type=Path);parser.add_argument('--run',action='store_true');parser.add_argument('--route',choices=('victory','loss','both'),default='both');parser.add_argument('--timeout',type=int,default=1500);parser.add_argument('--wait-lane',type=int,default=0);args=parser.parse_args()
 if args.timeout<1200 or args.wait_lane<0:parser.error('Invalid bounded deadline')
 if args.run and args.base_run is None:parser.error('--run requires --base-run')
 pins=source_pins()
 if args.run:execute(args);return
 require(args.base_run is None,'Full admission runs only with --run; default is named sources only')
 print(json.dumps({'validation_level':'named_sources_only','named_pins':len(pins),'routes':{k:list(v['modes']) for k,v in ROUTES.items()},'worker_scripts':9,'engine_started':False,'lane_acquired':False,'profile_created':False,'full_source_verified':False,'runtime_qualified':False},ensure_ascii=False))
if __name__=='__main__':main()
