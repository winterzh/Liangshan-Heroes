from pathlib import Path
import datetime,hashlib,importlib.util,json,os,shutil,sys,uuid
R=Path('D:/AI项目/水浒/开发工程');E=Path(__file__).parent;sys.path.insert(0,str(R/'tools'))
import run_character_art_qa as common
from release_step import run_release_step
shared,running=common.load_helpers(R)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
 with p.open('x',encoding='utf-8') as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
assert not (E/'pck_acceptance_success.json').exists(),'Completed immutable acceptance must not be rerun'
assert not running() and not shared.LOCK.exists(),'shared engine lane occupied'
b=json.loads((E/'retained_export_binding.json').read_text());prior_path=Path(b['failed_release_receipt']);assert sha(prior_path)==b['failed_release_receipt_sha256'];prior=json.loads(prior_path.read_text());assert prior['lock_released'] and any(x['case']=='full_export' and x['passed'] for x in prior['steps'])
pck=Path(b['pack_observed_after_failed_launch']['path']);exe=Path(b['exe']['path']);runtime=exe.parent;project=Path(prior['project']);prep_path=Path(prior['preparation']);root_before=json.loads((prep_path.parent/'root_before.json').read_text());generation=json.loads((prior_path.parent/'generation.json').read_text())
spec=importlib.util.spec_from_file_location('chao_pck_identity',R/'tools/contracts/run_content_identity_20260907/build_identity.py');identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')+'_'+uuid.uuid4().hex[:8];O=E/'pck_acceptance'/stamp;Q=O/'qa';Q.mkdir(parents=True)
receipt={'complete':False,'project':str(project),'preparation':str(prep_path),'original_export_receipt':str(prior_path),'original_export_receipt_sha256':sha(prior_path),'steps':[],'runner_sha256':sha(Path(__file__)),'release_helper_sha256':sha(E/'release_step.py'),'scope':'New full PCK compiled-identity/resources/live-Chao acceptance using configured editor executable as loader, plus distinct normal official configured release EXE chapter-start smoke. Release-template external-script identity/gameplay admission remains unverified; no whole wine/save/Steam/all-art acceptance.','production_applied':False,'full_goal_complete':False};locked=False
try:
 with shared.LOCK.open('x',encoding='utf-8') as f:f.write(str(O))
 locked=True;assert not running()
 assert sha(pck)==b['pack_observed_after_failed_launch']['sha256'] and sha(exe)==b['exe']['sha256']==prior['template_sha256']
 identity.verify_generated(project,generation);assert identity.snapshot(R)==root_before
 for n in ['base.gd','bootstrap.gd','identity.gd','live.gd','runtime_inputs.json']:shutil.copyfile(E/'pck_workers'/n,Q/n)
 save(Q/'bindings.json',{n:sha(Q/n) for n in ['base.gd','identity.gd','live.gd']})
 for n in ['generation.json','expected_identity.json']:shutil.copyfile(prior_path.parent/n,O/n);assert sha(O/n)==sha(prior_path.parent/n)
 engine=shared.resolve_godot(None);receipt['pck_loader']={'path':str(engine),'sha256':sha(engine),'kind':'editor_executable_loading_only_exported_compiled_PCK'}
 phase=O/'identity_profile';phase.mkdir();profile=shared.create_private_profile(phase,Path('D:/CodexQA/cgpck_identity'));env=common.private_environment(profile)
 env.update(HG_WORKER=str(Q/'identity.gd'),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/'bindings.json'),HG_EXPECTED_IDENTITY=str(O/'expected_identity.json'),HG_EXPECTED_EXE_SHA=sha(engine),HG_REPORT=str(O/'identity_report.json'),HG_OUTPUT_ROOT=str(O))
 common.process_step(engine,runtime,env,O,'compiled_full_pck_identity',['--headless','--main-pack',str(pck),'--script',str(Q/'bootstrap.gd')],120,'gl_compatibility',running,receipt['steps'])
 report=json.loads((O/'identity_report.json').read_text());assert report['passed'] and not report['failures'];receipt['pck_identity_checks']=len(report['checks'])
 phase=O/'visual_profile';phase.mkdir();profile=shared.create_private_profile(phase,Path('D:/CodexQA/cgpck_visual'));env=common.private_environment(profile)
 env.update(HG_WORKER=str(Q/'live.gd'),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/'bindings.json'),HG_EXPECTED_IDENTITY=str(O/'expected_identity.json'),HG_EXPECTED_EXE_SHA=sha(engine),CHAO_ART_OUT=str(O/'visual'),CHAO_ART_INPUTS=str(Q/'runtime_inputs.json'))
 common.process_step(engine,runtime,env,O,'compiled_full_pck_live_art',['--main-pack',str(pck),'--resolution','1280x720','--position','30000,30000','--script',str(Q/'bootstrap.gd')],360,'gl_compatibility',running,receipt['steps'])
 report=json.loads((O/'visual/report.json').read_text());assert report['passed'] and not report['failures'];receipt.update(pck_art_checks=report['checks'],pck_art_screenshots=len(report['screenshots']))
 phase=O/'release_smoke';phase.mkdir();profile=shared.create_private_profile(phase,Path('D:/CodexQA/cgrelease_smoke'));env=common.private_environment(profile);shots=phase/'screenshots';shots.mkdir()
 env.update(LEVEL='1',SCREENSHOT_DIR=str(shots))
 run_release_step(exe,runtime,env,phase,'normal_release_chapter_start',['--resolution','1280x720','--position','30000,30000','--fixed-fps','60','--quit-after','480'],180,common,running,receipt['steps'])
 assert (shots/'shot_00.png').is_file();receipt['normal_release_smoke']={'passed':True,'scope':'Existing LEVEL/SCREENSHOT_DIR hook starts actual chapter and saves first normal scene capture; no script override, compiled identity probe, cargo movement or Steam account acceptance.','exe_sha256':sha(exe),'screenshots':[{'path':str(x),'sha256':sha(x)} for x in sorted(shots.glob('*.png'))]}
 identity.verify_generated(project,generation);assert identity.snapshot(R)==root_before;assert sha(pck)==b['pack_observed_after_failed_launch']['sha256'] and sha(exe)==b['exe']['sha256']
 receipt.update(complete=True,root_unchanged=True,private_export_inputs_unchanged=True,pck=b['pack_observed_after_failed_launch'],release_exe=b['exe'],qa_inputs=[{'path':str(x),'sha256':sha(x)} for x in sorted(Q.iterdir())],full_gait_accepted=False,release_exe_external_driver_accepted=False)
except BaseException as error:receipt['error']=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text()==str(O):shared.LOCK.unlink()
 receipt['lock_released']=not shared.LOCK.exists();save(O/'receipt.json',receipt)
save(E/('pck_acceptance_success.json' if receipt['complete'] else 'pck_acceptance_failure_'+stamp+'.json'),{'receipt':str(O/'receipt.json')})
print(json.dumps({k:receipt.get(k) for k in ['complete','pck_identity_checks','pck_art_checks','pck_art_screenshots','normal_release_smoke','error','lock_released']},ensure_ascii=False));assert receipt['complete']
