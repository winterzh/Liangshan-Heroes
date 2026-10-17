import importlib.util,json,os,sys,time
from pathlib import Path
R=Path('D:/AI项目/水浒/开发工程');W=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as c
from run_chao_gai_pushcart_20261017 import sha,save
receipt_path=Path('D:/CodexEvidence/shuihu/chao_gai_pushcart_20261017/native/20261017_141148_3031f6d6/evidence/receipt.json')
accepted=json.loads(receipt_path.read_text(encoding='utf-8'));assert accepted['complete'] and accepted['lock_released']
shared,running=c.load_helpers(R);engine=shared.resolve_godot(None);assert not running() and not shared.LOCK.exists()
pack=Path(accepted['pack_path']);assert sha(pack)==accepted['pack_sha256'];project=Path(accepted['project'])
assert not c.source_changes(R,accepted['source_files']) and not c.source_changes(project,accepted['source_files'])
work=W/'natural_zoom';work.mkdir(exist_ok=True);run=work/time.strftime('%Y%m%d_%H%M%S');run.mkdir();e=run/'evidence';e.mkdir()
profile=shared.create_private_profile(run,work/'profiles');env=c.private_environment(profile)
result={'complete':False,'run':str(run),'qualified_receipt':str(receipt_path),'qualified_receipt_sha256':sha(receipt_path),'pack_sha256':sha(pack),'script_sha256':sha(W/'default_zoom.gd'),'runner_sha256':sha(Path(__file__)),'private_profile':str(profile),'steps':[]}
with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
try:
 c.process_step(engine,pack.parent,env|{'SHI_EN_ART_OUT':str(e/'visual')},e,'natural_zoom_views',['--main-pack',str(pack),'--position','30000,30000','--script',str(W/'default_zoom.gd')],180,'gl_compatibility',running,result['steps'])
 report=json.loads((e/'visual/report.json').read_text(encoding='utf-8'));assert report['passed'] and not report['failures']
 assert sha(pack)==accepted['pack_sha256'] and not c.source_changes(R,accepted['source_files']) and not c.source_changes(project,accepted['source_files'])
 result.update(complete=True,checks=len(report['checks']),screenshots=len(report['screenshots']))
except Exception as error:result['error']=repr(error)
finally:
 if not running() and shared.LOCK.read_text(encoding='utf-8')==str(run):shared.LOCK.unlink()
 result['lock_released']=not shared.LOCK.exists();save(e/'receipt.json',result)
print(json.dumps({k:result.get(k) for k in ['complete','run','checks','screenshots','error']},ensure_ascii=False))
if not result['complete']:raise SystemExit(1)
