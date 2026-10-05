"""Resume exact frozen imported inputs; no private source replacement."""
from pathlib import Path
import sys,json,shutil,time,uuid
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent.resolve()
sys.path.insert(0,str(repo/'tools'))
import run_character_art_qa as driver
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
prior=base/'20261005_090414_85f89378';project=prior/'project';p=prior/'evidence/receipt.json'
old=json.loads(p.read_text(encoding='utf-8'));engine=shared.resolve_godot(None)
assert old['source_root']==str(repo) and old['godot_sha256']==driver.sha(engine)
assert any(s['case']=='import' and s['passed'] for s in old['steps'])
assert not old['source_changes'] and not old['private_source_changes']
assert not driver.source_changes(repo,old['source_files']) and not driver.source_changes(project,old['source_files'])
qa=repo/driver.QA_DEST;dest=project/driver.QA_DEST
assert driver.sha(qa)==driver.sha(dest)==old['qa_sha256']
assert driver.sha(repo/'tools/run_character_art_qa.py')==old['driver_sha256']
if running_engine():raise RuntimeError('ENGINE_SLOT_OCCUPIED')
if shared.LOCK.exists():
 assert shared.LOCK.read_text(encoding='utf-8')==str(prior)
 assert old['failure'] and all(isinstance(s.get('exit_code'),int) for s in old['steps'])
 if running_engine():raise RuntimeError('ENGINE_SLOT_OCCUPIED')
 assert driver.release_owned_lock(shared.LOCK,prior,old,False)
 (base/'own_imported_lock_release.json').write_text(json.dumps({'released':True,'owner':str(prior),'receipt_sha256':driver.sha(p),'engine_busy_at_check':False,'owned_steps_exited':True,'foreign_lock_modified':False},indent=2)+'\n',encoding='utf-8')
if running_engine():raise RuntimeError('ENGINE_SLOT_OCCUPIED')
run=base/('continuation_'+time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);evidence=run/'evidence';evidence.mkdir(parents=True)
receipt={**{k:old[k] for k in ['source_root','source_files','qa_sha256','driver_sha256','godot_sha256','renderer','selected_cases']},'complete':False,'run':str(run),'project':str(project),'steps':[],'continued_from':{'receipt_sha256':driver.sha(p),'path':str(p),'unchanged_imported_project':str(project)},'continuation_driver_sha256':driver.sha(Path(__file__)),'fresh_import':False,'visual':True,'scope':'Same frozen imported production and QA bytes; fresh private profile. Original import linked by exact receipt SHA. Character art/local mechanism only; no package/publish/other process control.'}
locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
 locked=True
 harness=evidence/'harness';harness.mkdir()
 for source in [qa,Path(__file__),repo/'tools/run_character_art_qa.py']:shutil.copyfile(source,harness/source.name)
 profile=shared.create_private_profile(run,base/'profiles');env=driver.private_environment(profile);receipt['private_profile']=str(profile)
 receipt['private_environment']={k:env[k] for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']}
 directory=evidence/'han_tao';directory.mkdir();case=old['selected_cases'][0]
 driver.process_step(engine,project,env|{'ART_CHARACTER':'han_tao','ART_MANIFEST':'res://'+case['manifest'],'ART_QA_OUT':str(directory),'ART_VISUAL':'1'},evidence,'han_tao',['--position','20000,20000','--script','res://'+driver.QA_DEST],1000,'gl_compatibility',running_engine,receipt['steps'])
 receipt['character_results']=[driver.verify_character_report(case,directory,True)]
 for label,script,key in [('routing','skirmish_direction4_contract_test.gd','DIRECTION4_CONTRACT_OUT'),('inventory','character_direction4_inventory.gd','DIRECTION4_INVENTORY_OUT')]:
  for tick in range(40):
   if not running_engine():break
   print('WAIT natural engine idle before '+label,flush=True);time.sleep(15)
  folder=evidence/label;folder.mkdir()
  driver.process_step(engine,project,env|{key:str(folder)},evidence,label,['--headless','--script','res://tools/'+script],600,'gl_compatibility',running_engine,receipt['steps'])
  data=json.loads((folder/('report.json' if label=='routing' else 'inventory.json')).read_text(encoding='utf-8'));assert data.get('passed') is True if label=='routing' else isinstance(data.get('units'),list)
 receipt['qa_unchanged']=driver.sha(qa)==driver.sha(dest)==receipt['qa_sha256']
 receipt['driver_unchanged']=driver.sha(repo/'tools/run_character_art_qa.py')==receipt['driver_sha256']
 receipt['continuation_driver_unchanged']=driver.sha(Path(__file__))==receipt['continuation_driver_sha256']
 receipt['complete']=all(receipt[k] for k in ['qa_unchanged','driver_unchanged','continuation_driver_unchanged'])
except BaseException as exc:receipt['failure']={'type':type(exc).__name__,'message':str(exc)}
finally:
 receipt['source_changes']=driver.source_changes(repo,receipt['source_files']);receipt['private_source_changes']=driver.source_changes(project,receipt['source_files'])
 receipt['godot_unchanged']=driver.sha(engine)==receipt['godot_sha256'];receipt['engines_remaining']=running_engine()
 if locked:receipt['owned_lock_removed']=driver.release_owned_lock(shared.LOCK,run,receipt,receipt['engines_remaining'])
 receipt['lock_released']=not shared.LOCK.exists();receipt['complete']=receipt['complete'] and receipt['lock_released'] and not receipt['source_changes'] and not receipt['private_source_changes'] and receipt['godot_unchanged']
 receipt['artifacts']=[{'path':x.relative_to(evidence).as_posix(),'sha256':driver.sha(x),'bytes':x.stat().st_size} for x in sorted(evidence.rglob('*')) if x.is_file() and x.name!='receipt.json']
 (evidence/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 if receipt['complete']:(base/'final_run.json').write_text(json.dumps({'run':str(run),'project':str(project)}),encoding='utf-8')
 print(json.dumps({'complete':receipt['complete'],'run':str(run),'checks':sum(x['checks'] for x in receipt.get('character_results',[])),'failure':receipt.get('failure')},ensure_ascii=False),flush=True)
raise SystemExit(0 if receipt['complete'] else 1)
