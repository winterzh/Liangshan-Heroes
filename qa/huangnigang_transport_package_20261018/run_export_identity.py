from pathlib import Path
import datetime,hashlib,importlib.util,json,os,shutil,sys,uuid
R=Path(r"D:/AI项目/水浒/开发工程");E=Path(__file__).parent;sys.path.insert(0,str(R/"tools"))
import run_character_art_qa as common
shared,running=common.load_helpers(R)
assert not (E/"export_identity_success.json").exists(),"completed immutable phase must not be rerun"
spec=importlib.util.spec_from_file_location("hg_identity_generator",R/"tools/contracts/run_content_identity_20260907/build_identity.py")
identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):
 with p.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()
def save(p,d):
 with p.open("x",encoding="utf-8") as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+"\n")
# Existing mounted comparison must finish successfully before this second native job.
M=Path(r"D:/CodexEvidence/shuihu/gongsun_mounted_idle_mass_20261018")
assert (M/"latest.json").is_file(),"mounted native comparison has not completed"
mounted=json.loads((M/"latest.json").read_text(encoding="utf-8"))
assert json.loads(Path(mounted["receipt"]).read_text(encoding="utf-8"))["complete"]
assert not running() and not shared.LOCK.exists(),"shared engine lane occupied"
prep_path=Path(json.loads((E/"prepared_source_current.json").read_text(encoding="utf-8"))["receipt"])
prep=json.loads(prep_path.read_text(encoding="utf-8"));assert prep["prepared"]
P=Path(prep["project"]);identity.private_staging(P)
assert identity.snapshot(P)==json.loads((prep_path.parent/"prepared_before_import.json").read_text(encoding="utf-8")),"prepared source drift"
root_before=json.loads((prep_path.parent/"root_before.json").read_text(encoding="utf-8"));assert identity.snapshot(R)==root_before
stamp=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")+"_"+uuid.uuid4().hex[:8]
O=E/"export_identity"/stamp;O.mkdir(parents=True,exist_ok=False)
runtime=O/"runtime";runtime.mkdir();Q=O/"qa";Q.mkdir()
receipt={"complete":False,"scope":"new full PCK and real release EXE identity only; gameplay/save/cold/legacy gates pending","project":str(P),"preparation":str(prep_path),"steps":[],"production_applied":False,"native_steam_account_tested":False,"full_goal_complete":False,"runner_sha256":sha(Path(__file__))};locked=False
try:
 with shared.LOCK.open("x",encoding="utf-8") as f:f.write(str(O))
 locked=True;assert not running()
 profile=shared.create_private_profile(O,Path("D:/CodexQA/hgp_import"));env=common.private_environment(profile)
 engine=shared.resolve_godot(None);receipt["editor_engine_sha256"]=sha(engine)
 common.process_step(engine,P,env,O,"import",["--headless","--editor","--import","--quit"],900,"gl_compatibility",running,receipt["steps"])
 generation=identity.generate(P);save(O/"generation.json",generation)
 manifest={k:v for k,v in generation["identity"].items() if k not in ("files","directories")}
 save(O/"expected_identity.json",manifest);identity.verify_generated(P,generation)
 pck=runtime/"LiangshanHeroes.pck"
 common.process_step(engine,P,env,O,"full_export",["--headless","--editor","--export-pack","Windows Steam",str(pck)],900,"gl_compatibility",running,receipt["steps"])
 assert pck.is_file() and pck.stat().st_size>1000000
 template=Path(os.environ["APPDATA"])/"Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe"
 exe=runtime/"LiangshanHeroes.exe";shutil.copyfile(template,exe);assert sha(exe)==sha(template)
 receipt["native_runtime_provenance"]=shared.install_native(runtime)
 dlls=[]
 for name,manifest_vendor in shared.native_dependencies().items():
  for row in manifest_vendor["files"]:
   source=R/"vendor"/name/row["path"]
   if source.suffix.lower()!=".dll":continue
   target=runtime/source.name;shutil.copyfile(source,target);assert sha(target)==row["sha256"]
   dlls.append({"path":target.name,"bytes":target.stat().st_size,"sha256":sha(target)})
 bindings={}
 for name in ("bootstrap.gd","base.gd","identity.gd"):
  shutil.copyfile(E/name,Q/name);assert sha(Q/name)==sha(E/name)
  if name!="bootstrap.gd":bindings[name]=sha(Q/name)
 save(Q/"bindings.json",bindings)
 phase=O/"identity_phase";phase.mkdir()
 profile=shared.create_private_profile(phase,Path("D:/CodexQA/hgp_identity")/stamp)
 env=common.private_environment(profile)
 env.update(HG_WORKER=str(Q/"identity.gd"),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/"bindings.json"),HG_EXPECTED_IDENTITY=str(O/"expected_identity.json"),HG_EXPECTED_EXE_SHA=sha(exe),HG_REPORT=str(O/"identity_report.json"),HG_OUTPUT_ROOT=str(O))
 common.process_step(exe,runtime,env,O,"release_identity",["--main-pack",str(pck),"--resolution","1280x720","--position","30000,30000","--script",str(Q/"bootstrap.gd")],120,"gl_compatibility",running,receipt["steps"])
 report=json.loads((O/"identity_report.json").read_text(encoding="utf-8"));assert report["passed"] and not report["failures"]
 identity.verify_generated(P,generation);assert identity.snapshot(R)==root_before
 receipt.update(complete=True,root_unchanged=True,pck={"path":str(pck),"bytes":pck.stat().st_size,"sha256":sha(pck)},exe={"path":str(exe),"template":str(template),"sha256":sha(exe)},native_root_dlls=dlls,qa_inputs=[{"path":str(x),"sha256":sha(x)} for x in sorted(Q.iterdir())],identity_checks=len(report["checks"]),source_sha256=generation["identity"]["source_sha256"])
except BaseException as error:receipt["error"]=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8")==str(O):shared.LOCK.unlink()
 receipt["lock_released"]=not shared.LOCK.exists();save(O/"receipt.json",receipt)
save(E/("export_identity_success.json" if receipt["complete"] else "export_identity_failure_"+stamp+".json"),{"receipt":str(O/"receipt.json")})
print(json.dumps({k:receipt.get(k) for k in ["complete","identity_checks","error","lock_released"]},ensure_ascii=False));assert receipt["complete"]
