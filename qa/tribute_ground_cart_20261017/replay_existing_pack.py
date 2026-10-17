"""Replay an unchanged exported PCK after C-drive report I/O exhaustion.
Reconstruct validation only from actual frozen sources and existing generated constant,
then require the packed constant to equal that validation in a separate native probe.
Never regenerate identity, re-export, edit source, or count the I/O-failed run as passed.
"""
import importlib.util,json,os,shutil,sys,time,traceback,uuid
from pathlib import Path
R=Path('D:/AI项目/水浒/开发工程');W=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as c
import run_tribute_ground_cart_20261017 as runner
sha=runner.file_sha
prior=Path('C:/CodexQA/tribute_cart/20261017_122350_b1c248bb');project=Path('C:/CodexQA/liu_cart/20261017_110740_a1de3a5e/source_owner/.godot/tribute_cart/20261017_120824_67def0b3/project')
owner=Path('C:/CodexQA/liu_cart/20261017_110740_a1de3a5e/source_owner');runtime=prior/'clean_runtime';pack=runtime/'LiangshanTributeGroundCart.pck'
work=W/'replay';work.mkdir(exist_ok=True);run=work/(time.strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8]);e=run/'evidence'
shared,running=c.load_helpers(R);engine=shared.resolve_godot(None)
assert not running() and not shared.LOCK.exists()
old_valid_path=Path('C:/CodexQA/tribute_cart/20261017_121837_c293d24e/evidence/receipt.json');old=json.loads(old_valid_path.read_text(encoding='utf-8'))
receipt={'complete':False,'run':str(run),'project':str(project),'source_owner':str(owner),'source_owner_is_checkout':False,
 'steps':[],'source_files':[],'steam_updated':False,'godot_sha256':sha(engine),
 'pack_sha256':sha(pack),'pack_bytes':pack.stat().st_size,'pack_path':str(pack),
 'identity_generator_sha256':old['identity_generator_sha256'],'reused_owner_reference':old['reused_owner_reference'],
 'resume_wrapper_sha256':sha(Path(__file__)),'prior_io_failed_run':str(prior),
 'scope':'Exact unchanged existing label-fixed PCK replay after C-drive PNG/report I/O exhaustion. No re-export or identity regeneration. Validate current ROOT/private sources and actual existing generated constant, then independently compare packed constant and run full visual script with new private D profile/evidence. Imported cache reused. Actual short-chapter ground carts/labels and Liu regression only; no full wine/campaign/performance/Steam acceptance.'}
locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(run))
 locked=True;assert not running();run.mkdir();e.mkdir()
 names=sorted(set(shared.sources())|{x['path'] for x in old['source_files']})
 for name in names:
  c.relative_source(R,name);assert (R/name).read_bytes()==(project/name).read_bytes()
  receipt['source_files'].append({'path':name,'sha256':sha(project/name)})
 helper=owner/'tools/contracts/run_content_identity_20260907/build_identity.py';assert sha(helper)==old['identity_generator_sha256']
 spec=importlib.util.spec_from_file_location('replay_real_identity',helper);identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity);identity.private_staging(project)
 owner_receipt_path=Path(old['reused_owner_reference']['receipt']);assert sha(owner_receipt_path)==old['reused_owner_reference']['receipt_sha256']
 owner_receipt=json.loads(owner_receipt_path.read_text(encoding='utf-8'));assert not c.source_changes(owner,owner_receipt['source_files'])
 actual=identity.snapshot(project);derived=project/identity.DERIVED
 assert derived.read_bytes()==identity.identity_constant(actual)
 receipt['generated_identity']={'identity':actual,'derived':{'path':identity.DERIVED,'bytes':derived.stat().st_size,'sha256':sha(derived)},'validation_only_existing_constant':True}
 identity.verify_generated(project,receipt['generated_identity'])
 expected=e/'expected_identity.json';expected.write_bytes((json.dumps({k:v for k,v in actual.items() if k not in ['files','directories']},ensure_ascii=False,indent=2)+'\n').encode())
 profile=shared.create_private_profile(run,work/'profiles');env=c.private_environment(profile);receipt['private_profile']=str(profile)
 receipt['native_dependencies']=shared.install_native(runtime)
 # The existing import/export/probe logs are preserved, not counted as new steps.
 source_inputs=json.loads((prior/'evidence/inputs.json').read_text(encoding='utf-8'))
 assert source_inputs['ground_manifest']==json.loads((R/'assets/direction4/level1_tribute_ground_cart_20261017.json').read_text(encoding='utf-8'))
 input_path=e/'inputs.json';shutil.copyfile(prior/'evidence/inputs.json',input_path);ref=e/'texture_references.json';shutil.copyfile(prior/'evidence/texture_references.json',ref)
 receipt['inputs_sha256']=sha(input_path);receipt['texture_reference_sha256']=sha(ref)
 c.process_step(engine,runtime,env|{'GROUND_EXPECTED_IDENTITY':str(expected)},e,'existing_pck_identity',['--headless','--main-pack',str(pack),'--script',str(W/'identity_probe.gd')],60,'gl_compatibility',running,receipt['steps'])
 c.process_step(engine,runtime,env|{'SHI_EN_ART_OUT':str(e/'visual'),'SHI_EN_PACK_INPUTS':str(input_path),'SHI_EN_TEXTURE_REFERENCE':str(ref)},e,'packed_ground_and_carry_visuals',['--main-pack',str(pack),'--position','30000,30000','--script',str(project/runner.SCRIPT)],360,'gl_compatibility',running,receipt['steps'])
 report=json.loads((e/'visual/report.json').read_text(encoding='utf-8'));assert report['passed'] and not report['failures']
 receipt.update(checks=len(report['checks']),screenshots=len(report['screenshots']),source_changes=c.source_changes(R,receipt['source_files']),private_source_changes=c.source_changes(project,receipt['source_files']),source_owner_changes=c.source_changes(owner,owner_receipt['source_files']))
 assert not receipt['source_changes'] and not receipt['private_source_changes'] and not receipt['source_owner_changes']
 identity.verify_generated(project,receipt['generated_identity']);assert sha(pack)==receipt['pack_sha256'];receipt['complete']=True
except Exception as error:receipt.update(error=repr(error),traceback=traceback.format_exc())
finally:
 if locked and shared.LOCK.exists() and shared.LOCK.read_text(encoding='utf-8')==str(run) and not running():shared.LOCK.unlink()
 receipt['lock_released']=locked and not shared.LOCK.exists();e.mkdir(parents=True,exist_ok=True)
 (e/'receipt.json').write_bytes((json.dumps(receipt,ensure_ascii=False,indent=2)+'\n').encode())
print(json.dumps({k:receipt.get(k) for k in ['complete','run','checks','screenshots','error']},ensure_ascii=False))
if not receipt['complete']:raise SystemExit(1)
