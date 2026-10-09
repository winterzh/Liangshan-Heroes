from pathlib import Path
import sys,subprocess,time
repo=Path('E:/ChatGPT/水浒');base=Path(__file__).parent
sys.path.insert(0,str(repo/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
started=time.monotonic()
while time.monotonic()-started<600:
    announced=False
    while running_engine() or shared.LOCK.exists():
        if not announced:print('WAIT_SHARED_ENGINE: keep waiting naturally.',flush=True);announced=True
        if time.monotonic()-started>=600:sys.exit(3)
        time.sleep(2)
    r=subprocess.run([sys.executable,'-X','utf8','-B',str(base/'continue_frozen.py')],cwd=repo,stderr=subprocess.PIPE,text=True,encoding='utf-8')
    if r.returncode==0:sys.exit(0)
    if 'ENGINE_SLOT_OCCUPIED' not in r.stderr:
        print(r.stderr,flush=True);sys.exit(r.returncode)
    print('SAFE_RETRY: continuation did not acquire the engine slot.',flush=True)
    time.sleep(2)
sys.exit(3)
