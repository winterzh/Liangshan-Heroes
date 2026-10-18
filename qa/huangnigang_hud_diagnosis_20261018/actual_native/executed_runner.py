from pathlib import Path
import datetime,hashlib,importlib.util,json,os,shutil,subprocess,sys,time,uuid
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
import run_ruan_xiaoqi_layered_20261018 as previous_runner
shared,running=common.load_helpers(R)
M=Path(r'D:/CodexEvidence/shuihu/gongsun_mounted_idle_mass_20261018')
assert (M/"latest.json").is_file(),"mounted native comparison has not completed"
_mounted_path=Path(json.loads((M/"latest.json").read_text(encoding="utf-8"))["receipt"])
assert _mounted_path.resolve().is_relative_to((M/"native_resources").resolve()) and json.loads(_mounted_path.read_text(encoding="utf-8"))["complete"],"finish the actual mounted comparison first"
assert not running() and not shared.LOCK.exists(),'shared Godot lane occupied'
old_path=R/'qa/tribute_cart_wheel_unit_20261018/actual_native/receipt.json'
old=json.loads(old_path.read_text());assert old['complete'] and old['lock_released']
project=Path(old['project']);assert project==Path('C:/CodexQA/liu_cart/20261017_110740_a1de3a5e/source_owner/.godot/tribute_cart/20261017_120824_67def0b3/project')
identity=previous_runner.load_identity(R/previous_runner.HELPER);identity.verify_generated(project,old['generated_identity'])
A=Path(r'D:/CodexEvidence/shuihu/huangnigang_transport_arrival_path_20261018')
spec=json.loads((A/'integration_candidate.json').read_text());assert not spec['applied']
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];P=E/'actual_native'/stamp;P.mkdir(parents=True)
def sha(p):return hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
frozen={row['path']:row['sha256'] for row in old['source_files']}
assert not common.source_changes(project,old['source_files'])
pins={row['path']:sha(R/row['path']) for row in json.loads((R/'qa/tribute_cart_wheel_unit_20261018/runtime_inventory.json').read_text())}
pins['scripts/huangnigang_transport.gd']=sha(R/'scripts/huangnigang_transport.gd')
receipt={'complete':False,'phase':'live_hud_bottom_offset_diagnosis','previous_complete_receipt':str(old_path),'project':str(project),'candidate_files':spec['files'],'actual_level_tested':False,'new_pack_exported':False,'steps':[],'engine_sha256':sha(shared.resolve_godot(None)),'runner_sha256':sha(Path(__file__))}
before={};extra=[];owned_marker=str(P);locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(owned_marker)
 locked=True
 assert not running()
 receipt['prior_archive']=previous_runner.archive_previous(project,old,identity,P,'cb290a564e894cb589395ac46a406dc9dea5bd5b')
 for row in spec['files']:
  name=row['path'];src=A/'candidate'/name;assert sha(src)==row['candidate_sha256']
  dst=project/name;assert dst.resolve().is_relative_to(project.resolve())
  before[name]=dst.read_bytes() if dst.exists() else None
  if before[name] is not None:assert name in frozen and sha(dst)==frozen[name]
  else:extra.append(name+'.uid')
  dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
 profile=shared.create_private_profile(P,Path('D:/CodexQA/hgh_profiles'));env=common.private_environment(profile);receipt['private_profile']=str(profile)
 engine=shared.resolve_godot(None)
 common.process_step(engine,project,env,P,'import_candidate',['--headless','--editor','--import','--quit'],180,'gl_compatibility',running,receipt['steps'])
 wrapper=P/'actual_transport.gd';shutil.copyfile(E/'actual_transport.gd',wrapper);receipt['wrapper_sha256']=sha(wrapper)
 common.process_step(engine,project,env|{'HNS_CASE':'wine','HNS_VISUAL':'1','HNS_SIZE':'1280','HG_ROUTE_OUT':str(P/'route')},P,'actual_callbacks',['--resolution','1280x720','--position','30000,30000','--script',str(wrapper)],600,'gl_compatibility',running,receipt['steps'])
 report=json.loads((P/'route/report.json').read_text());assert report['passed'] and not report['failures']
 receipt['hud_diagnostics']=[{'path':str(x),'sha256':sha(x)} for x in sorted((P/'route').glob('loaded_*.json'))];assert len(receipt['hud_diagnostics'])==2
 receipt['native_checks']=report['checks'];receipt['actual_level_tested']=True;receipt['component_graph_capture_tested']=False;receipt['full_save_restore_tested']=False;receipt['full_wine_sequence_tested']=True;receipt['actual_player_order_movement_tested']=True
 assert all(sha(project/x['path'])==x['candidate_sha256'] for x in spec['files'])
 receipt['complete']=True
except BaseException as error:
 receipt['error']=repr(error)
finally:
 # Restore only the exact overlaid files, not a historical whole project/cache.
 for name,data in before.items():
  dst=project/name;assert dst.resolve().is_relative_to(project.resolve())
  if data is None:
   if dst.exists():dst.unlink()
  else:dst.write_bytes(data)
 for name in extra:
  dst=project/name;assert dst.resolve().is_relative_to(project.resolve())
  if dst.exists():dst.unlink()
 try:
  identity.verify_generated(project,old['generated_identity'])
  receipt['private_old_frozen_changes']=common.source_changes(project,old['source_files'])
  receipt['root_pin_changes']=[name for name,h in pins.items() if sha(R/name)!=h]
  assert not receipt['private_old_frozen_changes'] and not receipt['root_pin_changes']
  receipt['old_source_restored_exact']=True
 except BaseException as error:
  receipt.update(complete=False,restore_error=repr(error))
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==owned_marker:shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();save(P/'receipt.json',receipt)
save(E/'actual_native_latest.json',{'receipt':str(P/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','error','restore_error','old_source_restored_exact','lock_released']},ensure_ascii=False))
assert receipt['complete']
