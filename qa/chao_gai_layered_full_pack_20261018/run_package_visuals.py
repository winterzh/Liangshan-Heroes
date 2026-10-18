from pathlib import Path
import datetime,hashlib,importlib.util,json,shutil,sys,uuid
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
from release_step import run_release_step
shared,running=common.load_helpers(R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
 with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
assert not (E/'visual_success.json').exists(),'Do not rerun a completed immutable phase'
assert not running() and not shared.LOCK.exists(),'shared Godot lane occupied'
p=Path(json.loads((E/'export_identity_success.json').read_text())['receipt']);parent=json.loads(p.read_text());assert parent['complete'] and parent['lock_released']
project=Path(parent['project']);runtime=Path(parent['pck']['path']).parent;exe=Path(parent['exe']['path']);pck=Path(parent['pck']['path']);assert sha(exe)==parent['exe']['sha256'] and sha(pck)==parent['pck']['sha256']
prep_path=Path(parent['preparation']);root_before=json.loads((prep_path.parent/'root_before.json').read_text());generation=json.loads((p.parent/'generation.json').read_text())
spec=importlib.util.spec_from_file_location('chao_pack_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
assert identity.snapshot(R)==root_before;identity.verify_generated(project,generation)
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];O=E/'package_visuals'/stamp;Q=O/'qa';Q.mkdir(parents=True)
receipt={'complete':False,'scope':'Real release EXE + newly exported full PCK; live Chao art and retained Ruan7 owner/wheel guards. Explicit cargo-stage and controlled placement; no full wine/save/SDK/Steam or all-art acceptance.','steps':[],'project':str(project),'export_receipt':str(p),'export_receipt_sha256':sha(p),'pck':parent['pck'],'exe':parent['exe'],'runner_sha256':sha(Path(__file__)),'production_applied':False,'full_goal_complete':False};locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
 locked=True;assert not running()
 for n in ['base.gd','bootstrap.gd','live.gd','runtime_inputs.json']:shutil.copyfile(E/n,Q/n);assert sha(Q/n)==sha(E/n)
 bindings={n:sha(Q/n) for n in ['base.gd','live.gd']};save(Q/'bindings.json',bindings)
 profile=shared.create_private_profile(O,Path('D:/CodexQA/cgfull_visuals'));env=common.private_environment(profile);receipt['private_profile']=str(profile)
 env.update(HG_WORKER=str(Q/'live.gd'),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/'bindings.json'),HG_EXPECTED_IDENTITY=str(p.parent/'expected_identity.json'),HG_EXPECTED_EXE_SHA=sha(exe),CHAO_ART_OUT=str(O/'visual'),CHAO_ART_INPUTS=str(Q/'runtime_inputs.json'))
 run_release_step(exe,runtime,env,O,'packed_chao_visuals',['--resolution','1280x720','--position','30000,30000','--script',str(Q/'bootstrap.gd')],360,common,running,receipt['steps'])
 report=json.loads((O/'visual/report.json').read_text());assert report['passed'] and not report['failures']
 identity.verify_generated(project,generation);assert identity.snapshot(R)==root_before;assert sha(exe)==parent['exe']['sha256'] and sha(pck)==parent['pck']['sha256']
 receipt.update(complete=True,native_checks=report['checks'],screenshots=len(report['screenshots']),root_unchanged=True,private_export_inputs_unchanged=True,compiled_identity_verified=True,qa_inputs=[{'path':str(x),'sha256':sha(x)} for x in sorted(Q.iterdir())],full_gait_accepted=False)
except BaseException as error:receipt['error']=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/('visual_success.json' if receipt['complete'] else 'visual_failure_'+stamp+'.json'),{'receipt':str(O/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','native_checks','screenshots','error','lock_released']},ensure_ascii=False));assert receipt['complete']
