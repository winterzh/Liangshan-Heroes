"""Wait for natural idle, audit/release only this batch's exited-run lease, resume."""
from pathlib import Path
import sys,json,time,subprocess,hashlib
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.dont_write_bytecode=True;sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
prior=base/'20261005_104144_04942427'
receipt=prior/'evidence/receipt.json'
r=json.loads(receipt.read_text(encoding='utf-8'))
assert not r['complete'] and r['failure']['message']=='Godot/Liangshan engine appeared before step bound_qin_ming'
assert len(r['steps'])==1 and r['steps'][0]['case']=='import' and r['steps'][0]['passed']
while running_engine():
    print('WAIT naturally idle; no other process control',flush=True);time.sleep(15)
assert shared.LOCK.read_text(encoding='utf-8')==str(prior)
assert not running_engine()
old_sha=hashlib.sha256(receipt.read_bytes()).hexdigest()
shared.LOCK.unlink()
(base/'owned_lock_release.json').write_text(json.dumps({'complete':True,'owned_run':str(prior),'prior_receipt_sha256':old_sha,'own_import_completed':True,'prior_child_exited':True,'no_engine_at_release':True,'other_processes_controlled':False,'scope':'Release only exact own exited-run lease after shared engine naturally became idle; original failed receipt retained unchanged.'},indent=2)+'\n',encoding='utf-8')
args=[sys.executable,'-X','utf8','-B',str(repo/'tools/run_qin_ming_bound_qa.py'),'--repo',str(repo),'--manifest','bound_qin_ming=assets/direction4/bound_qin_ming_20261005.json','--work-root',str(base),'--cache-from',str(prior),'--shared-checks','--run']
raise SystemExit(subprocess.call(args,cwd=repo))
