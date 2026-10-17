import json,os,sys
from pathlib import Path
R=Path('D:/AI项目/水浒/开发工程');W=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as c
d=json.loads(Path('C:/CodexQA/tribute_cart/20261017_121214_c1fa5726/evidence/receipt.json').read_text(encoding='utf-8'));shared,running=c.load_helpers(R);engine=shared.resolve_godot(None)
assert not running() and not shared.LOCK.exists()
env=os.environ.copy()
for k in ['APPDATA','LOCALAPPDATA','TEMP','TMP']:env[k]=str(Path(d['private_profile'])/k.lower())
env.update(STEAM_DISABLED='1',CAMPAIGN_QA='1',LSH_LANGUAGE='zh_CN')
with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(W/'probe'))
steps=[]
try:c.process_step(engine,Path(d['run'])/'clean_runtime',env,W,'probe',['--headless','--main-pack',str(Path(d['run'])/'clean_runtime/LiangshanTributeGroundCart.pck'),'--script',str(W/'probe.gd')],60,'gl_compatibility',running,steps)
finally:
 if not running() and shared.LOCK.read_text(encoding='utf-8')==str(W/'probe'):shared.LOCK.unlink()
print((W/'probe.log').read_text(encoding='utf-8'))
