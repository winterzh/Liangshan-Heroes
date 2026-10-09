"""Finish only pending shared checks on the unchanged, already imported private project."""
from pathlib import Path
import sys,json,time,hashlib,shutil,uuid
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;run=base/'20261004_071806_170428c6'
sys.path.insert(0,str(repo/'tools'))
import run_character_art_qa as qa
shared,busy=qa.load_helpers(repo);engine=shared.resolve_godot(None)
evidence=run/'evidence';project=run/'project';original=evidence/'receipt.json'
r=json.loads(original.read_text(encoding='utf-8'))
assert r['failure']['message']=='Godot/Liangshan engine appeared before step routing'
assert [s['case'] for s in r['steps']]==['import','guan_sheng'] and all(s['passed'] for s in r['steps'])
assert r['source_root']==str(repo) and r['project']==str(project)
def identity():
 assert not qa.source_changes(repo,r['source_files']) and not qa.source_changes(project,r['source_files'])
 assert qa.sha(repo/qa.QA_DEST)==r['qa_sha256']==qa.sha(project/qa.QA_DEST)
 assert qa.sha(repo/'tools/run_character_art_qa.py')==r['driver_sha256']
 assert qa.sha(engine)==r['godot_sha256']
 assert set(shared.sources())<=set(x['path'] for x in r['source_files'])
 for case in r['selected_cases']:qa.verify_character_report(case,evidence/case['character'],r['visual'])
identity();runtime=shared.sources();deadline=time.monotonic()+1200
def wait_idle():
 idle=None
 while time.monotonic()<deadline:
  if busy():idle=None
  else:
   if idle is None:idle=time.monotonic()
   if time.monotonic()-idle>=10:return
  time.sleep(5)
 raise RuntimeError('Pending checks still waiting for engine; preserve current completed results')
print('Waiting to resume routing/inventory only; all character result and frozen-input hashes verified.',flush=True)
wait_idle();identity()
assert shared.LOCK.read_text(encoding='utf-8')==str(run)
assert not busy();shared.LOCK.unlink()
proof={'owner':str(run),'engine_idle_after_wait':True,'failed_receipt_sha256':qa.sha(original),'own_lock_released':True,'scope':'Only completed own runner residual lock; same private project and completed character evidence retained.'}
(run/'lock_recovery.json').write_text(json.dumps(proof,indent=2)+'\n',encoding='utf-8')
with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
continuation=run/('shared_continuation_'+uuid.uuid4().hex[:8]);continuation.mkdir()
profile=shared.create_private_profile(continuation,base/'profiles');env=qa.private_environment(profile)
shutil.copyfile(Path(__file__),evidence/'harness/resume_shared_checks.py')
r['continued_from']={'receipt_sha256':qa.sha(original),'failure':r.pop('failure'),'preserved_receipt':'receipt.json','scope':'Same immutable project/profile isolation; imported and character steps retained; only remaining shared steps executed.'}
r['shared_check_private_profile']=str(profile);r['continuation_sha256']=qa.sha(Path(__file__))
failure=None
try:
 for label,script,outkey in [('routing','skirmish_direction4_contract_test.gd','DIRECTION4_CONTRACT_OUT'),('inventory','character_direction4_inventory.gd','DIRECTION4_INVENTORY_OUT')]:
  directory=evidence/label;directory.mkdir(exist_ok=True)
  while True:
   wait_idle();identity()
   try:qa.process_step(engine,project,env|{outkey:str(directory)},evidence,label,['--headless','--script','res://tools/'+script],1000,r['renderer'],busy,r['steps']);break
   except RuntimeError as exc:
    if str(exc)!='Godot/Liangshan engine appeared before step '+label:raise
  parsed=json.loads((directory/('report.json' if label=='routing' else 'inventory.json')).read_text(encoding='utf-8'))
  assert parsed.get('passed') is True and not parsed.get('failures') if label=='routing' else isinstance(parsed.get('units'),list)
 identity();assert runtime==shared.sources()
 r.update(runtime_inventory_unchanged=True,qa_unchanged=True,driver_unchanged=True,godot_unchanged=True)
 wait_idle();assert not busy() and shared.LOCK.read_text(encoding='utf-8')==str(run)
 shared.LOCK.unlink();r['complete']=True
except BaseException as exc:
 failure=exc;r['failure']={'type':type(exc).__name__,'message':str(exc)}
finally:
 r['source_changes']=qa.source_changes(repo,r['source_files']);r['private_source_changes']=qa.source_changes(project,r['source_files'])
 r['engines_remaining']=busy()
 if shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not r['engines_remaining']:shared.LOCK.unlink()
 r['lock_released']=not shared.LOCK.exists();r['complete']=r['complete'] and r['lock_released'] and not r['source_changes'] and not r['private_source_changes']
 r['artifacts']=[{'path':p.relative_to(evidence).as_posix(),'sha256':qa.sha(p),'bytes':p.stat().st_size} for p in sorted(evidence.rglob('*')) if p.is_file() and p.name not in ('receipt.json','shared_continuation_receipt.json')]
 (evidence/'shared_continuation_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'complete':r['complete'],'steps':[(s['case'],s['passed']) for s in r['steps']],'failure':r.get('failure')}),flush=True)
sys.exit(0 if r['complete'] and failure is None else 1)
