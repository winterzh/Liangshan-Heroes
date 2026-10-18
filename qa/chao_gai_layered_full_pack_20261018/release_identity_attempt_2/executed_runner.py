from pathlib import Path
import datetime,hashlib,importlib.util,json,shutil,sys,uuid
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
from release_step import run_release_step
shared,running=common.load_helpers(R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
 with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
assert not (E/'export_identity_success.json').exists()
assert not running() and not shared.LOCK.exists(),'shared Godot lane occupied'
binding=json.loads((E/'retained_export_binding.json').read_text());prior_path=Path(binding['failed_release_receipt']);assert sha(prior_path)==binding['failed_release_receipt_sha256'];prior=json.loads(prior_path.read_text());assert prior['lock_released']
assert all(any(s['case']==case and s['passed'] for s in prior['steps']) for case in ['import','full_export'])
pck=Path(binding['pack_observed_after_failed_launch']['path']);exe=Path(binding['exe']['path']);runtime=exe.parent
assert sha(pck)==binding['pack_observed_after_failed_launch']['sha256'] and sha(exe)==binding['exe']['sha256']==prior['template_sha256']
project=Path(prior['project']);prep_path=Path(prior['preparation']);root_before=json.loads((prep_path.parent/'root_before.json').read_text());generation_path=prior_path.parent/'generation.json';assert sha(generation_path)==binding['generated_identity_sha256'];generation=json.loads(generation_path.read_text())
spec=importlib.util.spec_from_file_location('chao_release_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];O=E/'release_identity_v2'/stamp;Q=O/'qa';Q.mkdir(parents=True)
receipt={'complete':False,'scope':'Corrected actual release launch of the unchanged newly exported full PCK; original --path failure preserved. No source identity regeneration, binary changes, Steam account or gameplay acceptance.','project':str(project),'preparation':str(prep_path),'original_export_receipt':str(prior_path),'original_export_receipt_sha256':sha(prior_path),'steps':[],'runner_sha256':sha(Path(__file__)),'release_helper_sha256':sha(E/'release_step.py'),'production_applied':False,'full_goal_complete':False};locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
 locked=True;assert not running()
 identity.verify_generated(project,generation);assert identity.snapshot(R)==root_before
 for n in ['bootstrap.gd','base.gd','identity.gd']:shutil.copyfile(E/n,Q/n)
 save(Q/'bindings.json',{n:sha(Q/n) for n in ['base.gd','identity.gd']})
 for n in ['generation.json','expected_identity.json']:shutil.copyfile(prior_path.parent/n,O/n);assert sha(O/n)==sha(prior_path.parent/n)
 profile=shared.create_private_profile(O,Path('D:/CodexQA/cg_release2_profiles'));env=common.private_environment(profile);receipt['private_profile']=str(profile)
 env.update(HG_WORKER=str(Q/'identity.gd'),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/'bindings.json'),HG_EXPECTED_IDENTITY=str(O/'expected_identity.json'),HG_EXPECTED_EXE_SHA=sha(exe),HG_REPORT=str(O/'identity_report.json'),HG_OUTPUT_ROOT=str(O))
 run_release_step(exe,runtime,env,O,'release_identity',['--resolution','1280x720','--position','30000,30000','--script',str(Q/'bootstrap.gd')],120,common,running,receipt['steps'])
 report=json.loads((O/'identity_report.json').read_text());assert report['passed'] and not report['failures']
 identity.verify_generated(project,generation);assert identity.snapshot(R)==root_before;assert sha(pck)==binding['pack_observed_after_failed_launch']['sha256'] and sha(exe)==prior['template_sha256']
 receipt.update(complete=True,root_unchanged=True,pck=binding['pack_observed_after_failed_launch'],exe={'path':str(exe),'sha256':sha(exe)},identity_checks=len(report['checks']),source_sha256=generation['identity']['source_sha256'],qa_inputs=[{'path':str(p),'sha256':sha(p)} for p in sorted(Q.iterdir())])
except BaseException as error:receipt['error']=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/('export_identity_success.json' if receipt['complete'] else 'release_identity_failure_'+stamp+'.json'),{'receipt':str(O/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','identity_checks','error','lock_released']},ensure_ascii=False));assert receipt['complete']
