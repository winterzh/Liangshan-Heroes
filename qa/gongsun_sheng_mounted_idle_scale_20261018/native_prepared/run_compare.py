from pathlib import Path
import sys,json,time,uuid,hashlib,shutil,datetime
R=Path(r"D:/AI项目/水浒/开发工程");E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
shared,running=common.load_helpers(R);assert not running() and not shared.LOCK.exists(),'shared lane occupied'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
old=json.loads((R/'qa/gongsun_sheng_mounted_sources_20261018/native_wide/receipt.json').read_text(encoding='utf-8'));oldp=Path(old['project']);assert all(sha(oldp/x['path'])==x['sha256'] for x in old['frozen'])
P=E/'native_resources'/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);P.mkdir(parents=True)
pins={x['path']:sha(R/x['path']) for x in json.loads((R/'qa/tribute_cart_wheel_unit_20261018/runtime_inventory.json').read_text(encoding='utf-8'))}
receipt={'complete':False,'project':str(P),'steps':[],'old_native_project':str(oldp),'engine_sha256':sha(shared.resolve_godot(None)),'runner_sha256':sha(Path(__file__)),'game_adopted':False,'new_pack_exported':False};locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(P))
 locked=True;assert not running()
 for src in (E/'prepared').rglob('*'):
  if src.is_file():
   dst=P/src.relative_to(E/'prepared');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
 profile=shared.create_private_profile(P,Path('D:/CodexQA/gsmi_profiles'));env=common.private_environment(profile);receipt['private_profile']=str(profile)
 engine=shared.resolve_godot(None)
 common.process_step(engine,P,env,P,'import',['--headless','--editor','--import','--quit'],120,'gl_compatibility',running,receipt['steps'])
 frozen=[{'path':p.relative_to(P).as_posix(),'sha256':sha(p)} for p in sorted(P.rglob('*')) if p.is_file() and '.godot' not in p.relative_to(P).parts and p.suffix!='.log']
 receipt['frozen']=frozen
 common.process_step(engine,P,env,P,'native',['--resolution','2304x720','--position','30000,30000','--script','res://preview.gd'],120,'gl_compatibility',running,receipt['steps'])
 report=json.loads((P/'report.json').read_text(encoding='utf-8'));assert report['art_resource_preview_complete'] and not report['failures'];receipt['checks']=len(report['checks']);receipt['screenshots']=report['screenshots']
 receipt['private_source_changes']=[x['path'] for x in frozen if sha(P/x['path'])!=x['sha256']]
 receipt['old_project_changes']=[x['path'] for x in old['frozen'] if sha(oldp/x['path'])!=x['sha256']]
 receipt['root_runtime80_changes']=[name for name,h in pins.items() if sha(R/name)!=h]
 assert not receipt['private_source_changes'] and not receipt['old_project_changes'] and not receipt['root_runtime80_changes'];receipt['complete']=True
except BaseException as error:receipt['error']=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(P):shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();save(P/'receipt.json',receipt)
save(E/'latest.json',{'receipt':str(P/'receipt.json')});print(json.dumps({k:receipt.get(k) for k in ['complete','checks','error','lock_released']},ensure_ascii=False));assert receipt['complete']
