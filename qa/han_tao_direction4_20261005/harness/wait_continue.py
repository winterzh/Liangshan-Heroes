from pathlib import Path
import subprocess,sys,time
sys.dont_write_bytecode=True
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.path.insert(0,str(repo/'tools'))
from run_campaign_level_state_qa import running_engine
for tick in range(40):
 if running_engine():
  print('WAIT native continuation naturally busy; no process controlled',flush=True);time.sleep(20);continue
 r=subprocess.run([sys.executable,'-X','utf8','-B',str(base/'continue_frozen.py')],cwd=repo,stderr=subprocess.PIPE,text=True,encoding='utf-8')
 if r.returncode==0:raise SystemExit(0)
 if 'ENGINE_SLOT_OCCUPIED' not in r.stderr:print(r.stderr,flush=True);raise SystemExit(r.returncode)
 print('SAFE_RETRY before owning native child',flush=True)
raise SystemExit('Still busy: retain inputs and naturally wait')
