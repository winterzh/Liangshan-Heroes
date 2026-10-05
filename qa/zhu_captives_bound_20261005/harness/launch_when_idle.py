"""Observe natural idle and retry only a refusal before any run allocation."""
from pathlib import Path
import sys,subprocess,time,json
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.dont_write_bytecode=True;sys.path.insert(0,str(repo/'tools'))
from run_campaign_level_state_qa import running_engine
import run_steam_integration_qa as shared
args=[sys.executable,'-X','utf8','-B',str(repo/'tools/run_zhu_captives_bound_qa.py'),'--repo',str(repo),'--manifest','zhu_captives_bound=assets/direction4/bound_yang_lin_20261005.json','--work-root',str(base),'--cache-from','E:/ChatGPT/qa-shi-qian-bound-20261005/20261005_114753_cd5cab75','--shared-checks','--run']
refusals=[]
while True:
    while running_engine():print('WAIT natural shared-engine idle; no process control',flush=True);time.sleep(15)
    assert not shared.LOCK.exists(),'Inspect shared lock owner before proceeding'
    old={p.name for p in base.glob('20261005_*')}
    log=base/('launch_'+str(len(list(base.glob('launch_*.log'))))+'.log')
    with log.open('wb') as f:r=subprocess.run(args,cwd=repo,stdout=f,stderr=subprocess.STDOUT)
    text=log.read_text(encoding='utf-8',errors='replace')
    if r.returncode and text.rstrip().endswith('RuntimeError: Godot/Liangshan engine slot is occupied'):
        assert not shared.LOCK.exists() and {p.name for p in base.glob('20261005_*')}==old
        refusals.append({'attempt':len(refusals),'case':'refused_before_run_allocation','log':str(log),'other_processes_controlled':False})
        print('REFUSED before run allocation; waiting naturally again',flush=True);continue
    (base/'launch_receipt.json').write_text(json.dumps({'returncode':r.returncode,'pre_run_refusals':refusals,'log':str(log)},indent=2)+'\n',encoding='utf-8')
    print(text[-3000:],flush=True);raise SystemExit(r.returncode)
