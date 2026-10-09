"""Audit own failed contract lease and wait naturally before final rerun."""
from pathlib import Path
import sys,json,time,subprocess,hashlib
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.dont_write_bytecode=True;sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
prior=base/'20261005_104553_5aa1a251';receipt=prior/'evidence/receipt.json'
r=json.loads(receipt.read_text(encoding='utf-8'))
assert not r['complete'] and r['failure']['message']=='Private character QA step failed: campaign_contract'
assert [x['case'] for x in r['steps']]==['import','bound_qin_ming','terminal_contract','campaign_contract']
assert all(x['passed'] for x in r['steps'][:-1]) and not r['steps'][-1]['passed']
while running_engine():print('WAIT naturally idle after contract correction',flush=True);time.sleep(15)
assert not running_engine()
owned_removed=False
if shared.LOCK.exists():
    assert shared.LOCK.read_text()==str(prior);shared.LOCK.unlink();owned_removed=True
(base/'contract_lock_release.json').write_text(json.dumps({'complete':True,'owned_run':str(prior),'prior_receipt_sha256':hashlib.sha256(receipt.read_bytes()).hexdigest(),'no_engine_at_release':True,'own_children_exited':True,'owned_lock_removed':owned_removed,'other_processes_controlled':False},indent=2)+'\n',encoding='utf-8')
args=[sys.executable,'-X','utf8','-B',str(repo/'tools/run_qin_ming_bound_qa.py'),'--repo',str(repo),'--manifest','bound_qin_ming=assets/direction4/bound_qin_ming_20261005.json','--work-root',str(base),'--cache-from',str(prior),'--shared-checks','--run']
raise SystemExit(subprocess.call(args,cwd=repo))
