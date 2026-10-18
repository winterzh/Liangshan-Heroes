from pathlib import Path
import datetime,hashlib,importlib.util,json,os,shutil,subprocess,sys,time,uuid
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
import run_ruan_xiaoqi_layered_20261018 as previous_runner
shared,running=common.load_helpers(R);assert not running() and not shared.LOCK.exists(),'shared Godot lane occupied'
old_path=R/'qa/tribute_cart_wheel_unit_20261018/actual_native/receipt.json'
old=json.loads(old_path.read_text());assert old['complete'] and old['lock_released']
project=Path(old['project']);assert project==Path('C:/CodexQA/liu_cart/20261017_110740_a1de3a5e/source_owner/.godot/tribute_cart/20261017_120824_67def0b3/project')
identity=previous_runner.load_identity(R/previous_runner.HELPER);identity.verify_generated(project,old['generated_identity'])
spec=json.loads((E/'integration_candidate.json').read_text());assert not spec['applied']
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];P=E/'actual_native'/stamp;P.mkdir(parents=True)
def sha(p):return hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
frozen={row['path']:row['sha256'] for row in old['source_files']}
assert not common.source_changes(project,old['source_files'])
pins={row['path']:sha(R/row['path']) for row in json.loads((R/'qa/tribute_cart_wheel_unit_20261018/runtime_inventory.json').read_text())}
pins['scripts/huangnigang_transport.gd']=sha(R/'scripts/huangnigang_transport.gd')
receipt={'complete':False,'phase':'fresh_process_consumer_identity_recheck','previous_complete_receipt':str(old_path),'project':str(project),'candidate_files':spec['files'],'actual_level_tested':False,'new_pack_exported':False,'steps':[],'engine_sha256':sha(shared.resolve_godot(None)),'runner_sha256':sha(Path(__file__))}
before={};extra=[];owned_marker=str(P);locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(owned_marker)
 locked=True
 assert not running()
 receipt['prior_archive']=previous_runner.archive_previous(project,old,identity,P,'cb290a564e894cb589395ac46a406dc9dea5bd5b')
 for row in spec['files']:
  name=row['path'];src=E/'candidate'/name;assert sha(src)==row['candidate_sha256']
  dst=project/name;assert dst.resolve().is_relative_to(project.resolve())
  before[name]=dst.read_bytes() if dst.exists() else None
  if before[name] is not None:assert name in frozen and sha(dst)==frozen[name]
  else:extra.append(name+'.uid')
  dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
 profile=shared.create_private_profile(P,E/'parse_profiles');env=common.private_environment(profile);receipt['private_profile']=str(profile)
 engine=shared.resolve_godot(None)
 common.process_step(engine,project,env,P,'import_candidate',['--headless','--editor','--import','--quit'],180,'gl_compatibility',running,receipt['steps'])
 producer_receipt_path=Path("D:/CodexEvidence/shuihu/huangnigang_transport_display_20261018/actual_native/20261018_141408_33571bdb/receipt.json");producer=json.loads(producer_receipt_path.read_text(encoding='utf-8'));producer_report=producer_receipt_path.parent/'actual_report.json'
 writer=json.loads(producer_report.read_text(encoding='utf-8'));assert writer['passed'] and len(writer['checks'])==258
 source_profile=Path(producer['private_profile']);assert source_profile.resolve().is_relative_to(Path("D:/CodexEvidence/shuihu/huangnigang_transport_display_20261018/parse_profiles").resolve())
 receipt['producer_receipt']=str(producer_receipt_path);receipt['producer_report_sha256']=sha(producer_report);receipt['producer_checks_not_rerun']=258
 for key in ['appdata','localappdata','temp','tmp']:
  source=source_profile/key;assert source.is_dir() and not source.is_symlink();shutil.copytree(source,profile/key,dirs_exist_ok=True)
 expected=P/'producer_report.json';shutil.copyfile(producer_report,expected)
 consumer=P/'cold_transport.gd';shutil.copyfile(E/'cold_transport.gd',consumer);receipt['cold_wrapper_sha256']=sha(consumer)
 writer_step=next(x for x in producer['steps'] if x['case']=='actual_callbacks')
 common.process_step(engine,project,env|{'HG_COLD_OUT':str(P/'cold_report.json'),'HG_COLD_EXPECTED':str(expected),'HG_PRODUCER_PID':str(writer_step['pid']),'HG_PRIVATE_PROFILE':str(profile)},P,'cold_restore',['--headless','--script',str(consumer)],240,'gl_compatibility',running,receipt['steps'])
 cold=json.loads((P/'cold_report.json').read_text());assert cold['passed'] and not cold['failures'];receipt['cold_checks']=len(cold['checks']);receipt['cold_restart_tested']=True
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
