from pathlib import Path
import sys,subprocess,time,json
base=Path(__file__).parent;repo=Path('E:/ChatGPT/水浒')
sys.dont_write_bytecode=True;sys.path.insert(0,str(repo/'tools'))
from run_campaign_level_state_qa import running_engine
attempts=[]
while True:
 while running_engine():print('WAIT natural idle for own redundant import cleanup',flush=True);time.sleep(15)
 r=subprocess.run([sys.executable,'-X','utf8','-B',str(base/'cleanup_own_imports.py')],capture_output=True,text=True,encoding='utf-8')
 attempts.append({'returncode':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
 if r.returncode and running_engine() and not (repo/'qa/current_campaign_art_20261005/cleanup.json').exists():
  print('Cleanup pre-delete guard refused; wait naturally again',flush=True);continue
 (base/'cleanup_launch_receipt.json').write_text(json.dumps({'attempts':attempts},indent=2)+'\n',encoding='utf-8')
 print(r.stdout+r.stderr,flush=True);raise SystemExit(r.returncode)
