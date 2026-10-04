"""Execute all still-pending checks on the unchanged pre-import frozen project."""
from pathlib import Path
import sys,json,time,shutil,uuid
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;run=base/'20261004_113357_c4e8e5e1'
sys.path.insert(0,str(repo/'tools'))
import run_character_art_qa as qa
shared,busy=qa.load_helpers(repo);engine=shared.resolve_godot(None)
evidence=run/'evidence';project=run/'project';original=evidence/'receipt.json'
r=json.loads(original.read_text(encoding='utf-8'))
assert not r['steps'] and r['failure']['message']=='Godot/Liangshan engine appeared before step import'
assert r['source_root']==str(repo) and r['project']==str(project) and r['visual']
def identity():
 assert not qa.source_changes(repo,r['source_files']) and not qa.source_changes(project,r['source_files'])
 assert qa.sha(repo/qa.QA_DEST)==r['qa_sha256']==qa.sha(project/qa.QA_DEST)
 assert qa.sha(repo/'tools/run_character_art_qa.py')==r['driver_sha256']
 assert qa.sha(engine)==r['godot_sha256']
 assert set(shared.sources())<=set(row['path'] for row in r['source_files'])
 for case in r['selected_cases']:assert qa.sha(project/case['manifest'])==case['manifest_sha256']
identity();runtime=shared.sources()
def wait_idle():
 until=time.monotonic()+1200;idle=None
 while time.monotonic()<until:
  foreign_lock=shared.LOCK.exists() and shared.LOCK.read_text()!=str(run)
  if busy() or foreign_lock:idle=None
  elif idle is None:idle=time.monotonic()
  elif time.monotonic()-idle>=10:return
  time.sleep(5)
 raise RuntimeError('Waiting for natural idle; frozen project and receipts retained.')
print('All frozen production/private/QA/driver/engine identities verified. Waiting to execute import and full QA, no prior failed character result reused.',flush=True)
wait_idle();identity()
if shared.LOCK.exists():
 assert shared.LOCK.read_text()==str(run) and not busy()
 shared.LOCK.unlink()
 (run/'continuation_lock_recovery.json').write_text(json.dumps({'owner':str(run),'original_receipt_sha256':qa.sha(original),'engine_idle':True,'all_frozen_identities_verified':True,'own_lock_released':True},indent=2)+'\n',encoding='utf-8')
with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
holder=run/('full_continuation_'+uuid.uuid4().hex[:8]);holder.mkdir()
profile=shared.create_private_profile(holder,base/'profiles');env=qa.private_environment(profile)
shutil.copyfile(Path(__file__),evidence/'harness/resume_frozen_run.py')
r['continued_from']={'receipt_sha256':qa.sha(original),'failure':r.pop('failure'),'preserved_receipt':'receipt.json','scope':'Same unchanged pre-import frozen project; all four pending steps execute. No previous failed character result retained.'}
r['continuation_private_profile']=str(profile);r['continuation_sha256']=qa.sha(Path(__file__));r['character_results']=[];r['complete']=False
def step(label,args,case_env):
 while True:
  wait_idle();identity()
  try:qa.process_step(engine,project,case_env,evidence,label,args,1000,r['renderer'],busy,r['steps']);return
  except RuntimeError as exc:
   if str(exc)!='Godot/Liangshan engine appeared before step '+label:raise
failure=None
try:
 step('import',['--headless','--editor','--import','--quit'],env)
 identity()
 for case in r['selected_cases']:
  directory=evidence/case['character'];directory.mkdir()
  case_env=env|{'ART_CHARACTER':case['character'],'ART_MANIFEST':'res://'+case['manifest'],'ART_QA_OUT':str(directory),'ART_VISUAL':'1'}
  step(case['character'],['--position','20000,20000','--script','res://'+qa.QA_DEST],case_env)
  r['character_results'].append(qa.verify_character_report(case,directory,True))
 for label,script,out_key in [('routing','skirmish_direction4_contract_test.gd','DIRECTION4_CONTRACT_OUT'),('inventory','character_direction4_inventory.gd','DIRECTION4_INVENTORY_OUT')]:
  directory=evidence/label;directory.mkdir()
  step(label,['--headless','--script','res://tools/'+script],env|{out_key:str(directory)})
  parsed=json.loads((directory/('report.json' if label=='routing' else 'inventory.json')).read_text(encoding='utf-8'))
  assert parsed.get('passed') is True and not parsed.get('failures') if label=='routing' else isinstance(parsed.get('units'),list)
 identity();assert shared.sources()==runtime
 r.update(runtime_inventory_unchanged=True,qa_unchanged=True,driver_unchanged=True,godot_unchanged=True)
 wait_idle();identity();assert not busy() and shared.LOCK.read_text()==str(run)
 shared.LOCK.unlink();r['complete']=True
except BaseException as exc:
 failure=exc;r['failure']={'type':type(exc).__name__,'message':str(exc)}
finally:
 r['source_changes']=qa.source_changes(repo,r['source_files']);r['private_source_changes']=qa.source_changes(project,r['source_files']);r['engines_remaining']=busy()
 if shared.LOCK.exists() and shared.LOCK.read_text()==str(run) and not r['engines_remaining']:shared.LOCK.unlink()
 r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
 r['artifacts']=[{'path':p.relative_to(evidence).as_posix(),'sha256':qa.sha(p),'bytes':p.stat().st_size} for p in sorted(evidence.rglob('*')) if p.is_file() and p.name not in ('receipt.json','full_continuation_receipt.json')]
 (evidence/'full_continuation_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'complete':r['complete'],'steps':[(s['case'],s['passed']) for s in r['steps']],'failure':r.get('failure')}),flush=True)
sys.exit(0 if r['complete'] and failure is None else 1)
