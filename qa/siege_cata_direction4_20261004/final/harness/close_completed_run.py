"""Authenticate passed terminal run and release only its own lock at natural idle."""
from pathlib import Path
import sys,time,json,shutil
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent;run=base/'20261004_121342_097df265'
sys.path.insert(0,str(repo/'tools'));import run_character_art_qa as qa
shared,busy=qa.load_helpers(repo);engine=shared.resolve_godot(None)
src=run/'evidence';original=src/'receipt.json';r=json.loads(original.read_text(encoding='utf-8'))
assert not r['complete'] and not r['lock_released'] and r.get('failure') is None and r['engines_remaining']
assert [(s['case'],s['passed']) for s in r['steps']]==[('import',True),('siege_cata',True),('routing',True),('inventory',True)]
def identity():
 assert not qa.source_changes(repo,r['source_files']) and not qa.source_changes(run/'project',r['source_files'])
 assert qa.sha(repo/qa.QA_DEST)==r['qa_sha256']==qa.sha(run/'project'/qa.QA_DEST)
 assert qa.sha(repo/'tools/run_character_art_qa.py')==r['driver_sha256'] and qa.sha(engine)==r['godot_sha256']
 assert set(shared.sources())<=set(x['path'] for x in r['source_files'])
 for row in r['artifacts']:assert qa.sha(src/row['path'])==row['sha256']
 for result in r['character_results']:assert qa.sha(src/result['character']/'report.json')==result['report_sha256']
identity();print('Passed four-step run identities verified; waiting only for natural-idle lock closure.',flush=True)
until=time.monotonic()+1200;idle=None
while time.monotonic()<until:
 foreign=shared.LOCK.exists() and shared.LOCK.read_text()!=str(run)
 if busy() or foreign:idle=None
 elif idle is None:idle=time.monotonic()
 elif time.monotonic()-idle>=10:break
 time.sleep(5)
else:raise RuntimeError('No natural idle window; unchanged successful test evidence retained.')
identity();assert not busy() and shared.LOCK.exists() and shared.LOCK.read_text()==str(run)
shared.LOCK.unlink()
r['closed_from']={'receipt_sha256':qa.sha(original),'preserved_receipt':'receipt.json','scope':'All four steps already passed on unchanged frozen inputs. Original receipt retained; terminal own lock released only after natural idle and verification of production/private sources, QA, driver, engine and evidence. No test result changed or reused from the failed five-slot run.'}
r.update(lock_released=True,engines_remaining=False,complete=True)
shutil.copyfile(Path(__file__),src/'harness/close_completed_run.py')
r['closure_sha256']=qa.sha(Path(__file__));r['artifacts']=[{'path':p.relative_to(src).as_posix(),'sha256':qa.sha(p),'bytes':p.stat().st_size} for p in sorted(src.rglob('*')) if p.is_file() and p.name not in ('receipt.json','closure_receipt.json')]
(src/'closure_receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(base/'final_run.json').write_text(json.dumps({'run_name':run.name,'receipt_name':'closure_receipt.json'},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'complete':True,'lock_released':True,'original_receipt_preserved':True,'native_checks':r['character_results'][0]['checks']}),flush=True)
