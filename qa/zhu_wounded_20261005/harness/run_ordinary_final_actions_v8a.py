"""Frozen original-chapter skill/death QA, private Wu death lookup pilot only."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,sys,time,uuid
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
def read(p):return json.loads(p.read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_bytes((json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--from-receipt',type=Path,required=True);ap.add_argument('--work-root',type=Path,required=True)
 ap.add_argument('--case',choices=['skills','death','all'],default='all');ap.add_argument('--run',action='store_true');args=ap.parse_args()
 rp=args.from_receipt.resolve();prior=read(rp);old=Path(prior['project']);assert prior['complete'] and prior['lock_released'] and prior['covered_default_routes_verified'] and prior['private_runtime_patches']==0
 assert not prior['source_changes'] and not prior['private_source_changes'] and Path(prior['source_root']).resolve()==ROOT
 inputs=prior['source_files'];existing=prior['candidate_inputs']
 assert all(sha(ROOT/r['path'])==r['sha256']==sha(old/r['path']) for r in inputs+existing)
 engine=shared.resolve_godot(None);assert sha(engine)==prior['godot_sha256']
 manifest_path=ROOT/'assets/direction4/ordinary_wu_song_20261007_death_v8.json';m=read(manifest_path)
 assert not m['production_qualified'] and not m['runtime_death_qualified'] and len(m['resources'])==4
 paths=set(m['resources'])|{manifest_path.relative_to(ROOT).as_posix()}
 for source in m['sources'].values():
  assert source['import_dimensions_verified'] and sha(ROOT/source['path'])==source['sha256'];paths.update([source['path'],source['path']+'.import'])
 new_inputs=[{'path':p,'sha256':sha(ROOT/p)} for p in sorted(paths) if p not in {r['path'] for r in inputs+existing}]
 base=shared.resolve_profile_root(args.work_root.resolve());assert not base.is_relative_to(ROOT)
 boot=Path(read(base/'texture_bootstrap_wu_song_death_v8_run.json')['run']);assert read(boot/'receipt.json')['complete']
 if not args.run:print(json.dumps({'preflight':True,'source_inputs':len(inputs),'existing_inputs':len(existing),'new_inputs':len(new_inputs),'case':args.case}));return 0
 while running_engine() or shared.LOCK.exists():print('WAIT natural shared engine idle',flush=True);time.sleep(15)
 run=base/('ordinary_final_actions_v8a_'+uuid.uuid4().hex[:8]);project=run/'project';project.mkdir(parents=True)
 receipt={'complete':False,'run':str(run),'project':str(project),'source_root':str(ROOT),'source_files':inputs,'candidate_inputs':existing,'new_inputs':new_inputs,
  'prior_receipt':str(rp),'prior_receipt_sha256':sha(rp),'godot_sha256':sha(engine),'harnesses':[],'steps':[],'results':{},'production_qualified':False,
  'scope':'Original actors and production commands/skills/lethal enemy damage. Legal restored-level6/rank1 skill fixture, contact placement/nonparticipant freeze/fog-off/zoom and exact phase freezes. Death actors retain original level1 stats. Private ArtDB adds Wu death family only; no HP/damage/ability/Unit gameplay patch. Not natural leveling, full chapter, save, continuous playback, performance or platform qualification.'}
 locked=False;child=None
 try:
  with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
  locked=True
  for row in inputs+existing+new_inputs:
   dst=project/row['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/row['path'],dst)
  shutil.copytree(old/'.godot',project/'.godot');receipt['native_dependencies']=shared.install_native(project)
  for src in (boot/'project/.godot/imported').iterdir():
   if not src.is_file():continue
   dst=project/'.godot/imported'/src.name
   if dst.exists():assert sha(dst)==sha(src)
   else:shutil.copy2(src,dst)
  art=project/'scripts/art_db.gd';text=art.read_text(encoding='utf-8');needle='"attack": "character_traits_v7_wu_song_combat", "hurt": "character_traits_v7_wu_song_combat"'
  assert text.count(needle)==1;text=text.replace(needle,needle+', "death": "character_traits_v8_wu_song_death"');art.write_bytes(text.encode('utf-8'))
  receipt['private_patch']={'path':'scripts/art_db.gd','original_sha256':sha(ROOT/'scripts/art_db.gd'),'patched_sha256':sha(art),'scope':'Wu ordinary death family registration only; no gameplay edits'}
  for name in ['ordinary_skills_death_v8a.gd','run_ordinary_final_actions_v8a.py']:
   src=Path(__file__).with_name(name);shutil.copy2(src,project/name);frozen=run/'harness'/name;frozen.parent.mkdir(exist_ok=True);shutil.copy2(src,frozen)
   receipt['harnesses'].append({'path':src.relative_to(ROOT).as_posix(),'sha256':sha(src)})
  profile=shared.create_private_profile(run,base/'profiles');env=os.environ.copy()
  for key in list(env):
   if key.startswith('LSH_') or key.endswith(('_TEST','_QA','_QA_MANIFEST','_AUDIT')) or key in ['LEVEL','SCENARIO','CUSTOM_DEFENSE','SKIRMISH','SKIRMISH_AI','ARENA','AUTO_MICRO','AUTOMICRO']:env.pop(key)
  for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
   p=profile/key.lower();p.mkdir();env[key]=str(p)
  env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',ART_QA_PROFILE=str(profile),ART_VISUAL='1');receipt['private_profile']=str(profile)
  skill_cases=['skills_'+str(i) for i in range(8)]
  cases=skill_cases+['death'] if args.case=='all' else skill_cases if args.case=='skills' else ['death']
  stages=[('import',['--headless','--editor','--import','--quit'])]+[(case,['--audio-driver','Dummy','--resolution','1440x960','--position','30000,30000','--script','res://ordinary_skills_death_v8a.gd']) for case in cases]
  for label,extra in stages:
   while running_engine():print('WAIT natural shared engine idle before '+label,flush=True);time.sleep(15)
   out=run/label;out.mkdir();env.update(ART_QA_OUT=str(out),ORDINARY_FINAL_ACTION_CASE=label)
   log=run/(label+'.log');print('RUN '+label+' '+str(run),flush=True)
   with log.open('wb') as f:
    child=subprocess.Popen([str(engine),'--path',str(project),'--rendering-method','gl_compatibility']+extra,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    started=last=time.monotonic();reason=None
    while child.poll() is None:
     time.sleep(.5);output=log.read_text(encoding='utf-8',errors='replace')
     if re.search(r'(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)',output):reason='fatal_script_or_engine_error';break
     if time.monotonic()-started>1200:reason='own_case_timeout';break
     if time.monotonic()-last>=25:print('RUNNING '+label+' '+str(round(time.monotonic()-started))+'s',flush=True);last=time.monotonic()
    if reason and child.poll() is None:child.terminate();child.wait(timeout=15)
   receipt['steps'].append({'case':label,'pid':child.pid,'exit_code':child.returncode,'stop_reason':reason,'log_sha256':sha(log)})
   if label!='import' and (out/'report.json').is_file():receipt['results'][label]=read(out/'report.json')
   assert child.returncode==0 and not reason,log.read_text(encoding='utf-8',errors='replace')[-5500:]
   if label!='import':
    result=receipt['results'][label];assert result['passed'] and result['engine_time_scale']==1.0 and len(result['screenshots'])==(8 if label.startswith('skills_') else 32)
  assert all(sha(ROOT/r['path'])==r['sha256'] for r in inputs+existing+new_inputs)
  assert all(sha(project/r['path'])==r['sha256'] for r in inputs+existing+new_inputs if r['path']!='scripts/art_db.gd')
  assert sha(art)==receipt['private_patch']['patched_sha256']
  assert all(sha(ROOT/r['path'])==r['sha256']==sha(project/Path(r['path']).name) for r in receipt['harnesses'])
  for result in receipt['results'].values():
   assert all(sha(Path(s['path']))==s['sha256'] for s in result['screenshots'])
  receipt.update(complete=True,root_input_drift=0,private_input_drift_except_declared_patch=0,private_patch_verified=True)
 except BaseException as exc:receipt['failure']={'type':type(exc).__name__,'message':str(exc)};raise
 finally:
  if child is not None and child.poll() is None:child.terminate();child.wait(timeout=15)
  if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
  receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released'];dump(run/'receipt.json',receipt)
  if receipt['complete']:dump(base/('ordinary_final_actions_'+args.case+'_v8a_run.json'),{'run':str(run)})
  print(json.dumps({'complete':receipt['complete'],'run':str(run),'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
 return 0
if __name__=='__main__':raise SystemExit(main())
