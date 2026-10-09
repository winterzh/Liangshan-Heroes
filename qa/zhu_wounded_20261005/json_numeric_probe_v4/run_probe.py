from pathlib import Path
import sys,os,time,subprocess,json,hashlib
ROOT=Path('E:/ChatGPT/水浒');BASE=Path(__file__).parent
sys.dont_write_bytecode=True;sys.path.insert(0,str(ROOT/'tools'))
import run_steam_integration_qa as shared
from run_campaign_level_state_qa import running_engine
while running_engine() or shared.LOCK.exists():print('WAIT natural engine idle for numeric diagnostic',flush=True);time.sleep(15)
env=os.environ.copy();profile=BASE/'profile';profile.mkdir()
for key in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:
    p=profile/key.lower();p.mkdir();env[key]=str(p)
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1')
engine=shared.resolve_godot(None)
locked=False
try:
    with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(BASE))
    locked=True
    with (BASE/'probe.log').open('wb') as f:
        child=subprocess.Popen([str(engine),'--headless','--path',str(BASE),'--script','res://probe.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        child.wait(timeout=60)
    output=(BASE/'probe.log').read_text(encoding='utf-8',errors='replace');assert child.returncode==0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output,output
    print(output,flush=True)
    result=json.loads((BASE/'result.json').read_text(encoding='utf-8'));print(json.dumps(result),flush=True)
finally:
    if locked and shared.LOCK.is_file() and shared.LOCK.read_text(encoding='utf-8')==str(BASE):shared.LOCK.unlink()
