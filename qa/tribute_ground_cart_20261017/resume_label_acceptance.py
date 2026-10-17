"""Repair the exact short-chapter binding after a rejected package; keep failed PCK and replaced source bytes.
The new PCK is built after an exact current-source freeze and new identity.
The existing import cache is reused explicitly, never reported as a new cold import.
"""
import hashlib,importlib.util,json,os,shutil,sys,time,traceback,uuid
from pathlib import Path
R=Path('D:/AI项目/水浒/开发工程');W=Path(__file__).parent
sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
import run_tribute_ground_cart_20261017 as runner
sha=runner.file_sha
old_path=Path('C:/CodexQA/tribute_cart/20261017_121837_c293d24e/evidence/receipt.json')
old=json.loads(old_path.read_text(encoding='utf-8'));assert not old['complete'] and old['lock_released']
assert [(x['case'],x['passed']) for x in old['steps']]==[('reimport_existing_cache',True),('parse_scene_probe',True),('source_texture_reference',True),('export_pack',True),('packed_ground_and_carry_visuals',False)]
project=Path(old['project']);owner=Path(old['source_owner']);shared,running=common.load_helpers(R);engine=shared.resolve_godot(None)
assert not running() and not shared.LOCK.exists()
work=Path('C:/CodexQA/tribute_cart');run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);e=run/'evidence';runtime=run/'clean_runtime'
receipt={'complete':False,'run':str(run),'project':str(project),'source_owner':str(owner),'source_owner_is_checkout':False,'source_files':[],'steps':[],
 'scope':'Fresh full PCK after label placement and QA absent-meta repair; actual ground route retained. Reuses explicitly verified pre-pack candidate source container and imported cache; not a fresh cold import. New source freeze, identity and isolated profile. Exact mission claimed ground carts and retained Liu tests; no full wine/campaign/performance/Steam qualification.',
 'steam_updated':False,'godot_sha256':sha(engine),'resume_previous_receipt':str(old_path),'resume_previous_receipt_sha256':sha(old_path),'resume_wrapper_sha256':sha(Path(__file__)),
 'identity_generator_sha256':old['identity_generator_sha256'],'reused_owner_reference':old['reused_owner_reference']}
locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as lock:lock.write(str(run))
 locked=True;assert not running();run.mkdir();e.mkdir();runtime.mkdir()
 assert not common.source_changes(project,old['source_files'])
 identity_path=owner/'tools/contracts/run_content_identity_20260907/build_identity.py'
 spec=importlib.util.spec_from_file_location('ground_resume_identity',identity_path);identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
 identity.no_links(project);identity.private_staging(project)
 assert sha(identity_path)==old['identity_generator_sha256']
 owner_receipt_path=Path(old['reused_owner_reference']['receipt']);assert sha(owner_receipt_path)==old['reused_owner_reference']['receipt_sha256']
 owner_receipt=json.loads(owner_receipt_path.read_text(encoding='utf-8'));assert not common.source_changes(owner,owner_receipt['source_files'])
 names=sorted(set(shared.sources())|{row['path'] for row in old['source_files']})
 changes=[]
 for name in names:
  common.relative_source(R,name);target=project/name;raw=(R/name).read_bytes()
  if not target.exists() or target.read_bytes()!=raw:
   if target.exists():
    archive=e/'replaced_sources'/name;archive.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(target,archive)
    prior=sha(target)
   else:prior=None
   changes.append({'path':name,'old_sha256':prior,'new_sha256':hashlib.sha256(raw).hexdigest()})
   target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  receipt['source_files'].append({'path':name,'sha256':sha(target)})
 assert [x['path'] for x in changes]==['assets/anim/tribute_ground_cart_20261017_idle_ne.tres', 'assets/anim/tribute_ground_cart_20261017_idle_nw.tres', 'assets/anim/tribute_ground_cart_20261017_idle_se.tres', 'assets/anim/tribute_ground_cart_20261017_idle_sw.tres', 'assets/direction4/level1_tribute_ground_cart_20261017.json', 'tools/build_tribute_ground_cart_20261017.py', 'tools/tribute_ground_cart_20261017.gd']
 receipt['repaired_sources']=changes
 derived=project/identity.DERIVED;assert sha(derived)==old['generated_identity']['derived']['sha256'];derived.unlink()
 receipt['identity_seed']=identity.seed(project)
 receipt['native_dependencies']=shared.install_native(project)
 profile=shared.create_private_profile(run,work/'profiles');env=common.private_environment(profile);receipt['private_profile']=str(profile)
 template=Path(os.environ['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe';target=Path(env['APPDATA'])/'Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe'
 target.parent.mkdir(parents=True);shutil.copyfile(template,target);receipt['template_sha256']=sha(template)
 input_path=e/'inputs.json';inputs=json.loads((old_path.parent/'inputs.json').read_text(encoding='utf-8'));inputs['ground_manifest']=json.loads((R/'assets/direction4/level1_tribute_ground_cart_20261017.json').read_text(encoding='utf-8'));input_path.write_bytes((json.dumps(inputs,ensure_ascii=False,indent=2)+'\n').encode());receipt['inputs_sha256']=sha(input_path)
 common.process_step(engine,project,env,e,'reimport_existing_cache',['--headless','--editor','--import','--quit'],300,'gl_compatibility',running,receipt['steps'])
 common.process_step(engine,project,env,e,'parse_scene_probe',['--headless','--check-only','--script','res://'+runner.SCRIPT],60,'gl_compatibility',running,receipt['steps'])
 ref=e/'texture_references.json';common.process_step(engine,project,env|{'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE_OUT':str(ref)},e,'source_texture_reference',['--headless','--script','res://'+runner.REFERENCE],90,'gl_compatibility',running,receipt['steps'])
 assert set(json.loads(ref.read_text(encoding='utf-8')))==set(json.loads(input_path.read_text(encoding='utf-8'))['textures']);receipt['texture_reference_sha256']=sha(ref)
 receipt['generated_identity']=identity.generate(project)
 assert not common.source_changes(project,receipt['source_files'])
 pack=runtime/'LiangshanTributeGroundCart.pck'
 common.process_step(engine,project,env,e,'export_pack',['--headless','--editor','--export-pack','Windows Steam',str(pack)],300,'gl_compatibility',running,receipt['steps'])
 identity.verify_generated(project,receipt['generated_identity']);receipt.update(pack_sha256=sha(pack),pack_bytes=pack.stat().st_size)
 assert shared.install_native(runtime)==receipt['native_dependencies']
 for path in sorted((R/'vendor').glob('*/provenance.json')):
  for row in json.loads(path.read_text(encoding='utf-8'))['files']:
   if row['path'].endswith('.dll'):
    src=path.parent/row['path'];assert sha(src)==row['sha256'];dest=runtime/src.name
    if not dest.exists():shutil.copyfile(src,dest)
    assert sha(dest)==row['sha256']
 cmd=['--main-pack',str(pack),'--position','30000,30000','--script',str(project/runner.SCRIPT)]
 common.process_step(engine,runtime,env|{'SHI_EN_ART_OUT':str(e/'visual'),'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE':str(ref)},e,'packed_ground_and_carry_visuals',cmd,360,'gl_compatibility',running,receipt['steps'])
 report=json.loads((e/'visual/report.json').read_text(encoding='utf-8'));assert report['passed'] and not report['failures']
 receipt.update(checks=len(report['checks']),screenshots=len(report['screenshots']),source_changes=common.source_changes(R,receipt['source_files']),private_source_changes=common.source_changes(project,receipt['source_files']),source_owner_changes=common.source_changes(owner,owner_receipt['source_files']))
 assert not receipt['source_changes'] and not receipt['private_source_changes'] and not receipt['source_owner_changes']
 identity.verify_generated(project,receipt['generated_identity']);assert sha(pack)==receipt['pack_sha256'];receipt['complete']=True
except Exception as error:receipt.update(error=repr(error),traceback=traceback.format_exc())
finally:
 if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not running():shared.LOCK.unlink()
 receipt['lock_released']=locked and not shared.LOCK.exists();e.mkdir(parents=True,exist_ok=True)
 (e/'receipt.json').write_bytes((json.dumps(receipt,ensure_ascii=False,indent=2)+'\n').encode())
print(json.dumps({k:receipt.get(k) for k in ['complete','run','checks','screenshots','error']},ensure_ascii=False))
if not receipt['complete']:raise SystemExit(1)
