from pathlib import Path
import datetime,hashlib,json,shutil,sys,uuid
R=Path(r"D:/AI项目/水浒/开发工程");E=Path(__file__).parent;sys.path.insert(0,str(R/"tools"))
import run_character_art_qa as common
import run_ruan_xiaoqi_layered_20261018 as previous
shared,running=common.load_helpers(R)
assert not (E/"legacy_success.json").exists(),"completed immutable phase must not be rerun"
def sha(p):
 with p.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()
def save(p,d):
 with p.open("x",encoding="utf-8") as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+"\n")
M=Path(r"D:/CodexEvidence/shuihu/gongsun_mounted_idle_mass_20261018")
assert (M/"latest.json").is_file(),"mounted native comparison has not completed"
_mounted_path=Path(json.loads((M/"latest.json").read_text(encoding="utf-8"))["receipt"])
assert _mounted_path.resolve().is_relative_to((M/"native_resources").resolve()) and json.loads(_mounted_path.read_text(encoding="utf-8"))["complete"],"finish the actual mounted comparison first"
assert not running() and not shared.LOCK.exists(),"shared engine lane occupied"
old_path=R/"qa/tribute_cart_wheel_unit_20261018/actual_native/receipt.json"
old=json.loads(old_path.read_text(encoding="utf-8"));P=Path(old["project"])
assert old["complete"] and old["lock_released"]
assert P==Path(r"C:/CodexQA/liu_cart/20261017_110740_a1de3a5e/source_owner/.godot/tribute_cart/20261017_120824_67def0b3/project")
identity=previous.load_identity(R/previous.HELPER);identity.verify_generated(P,old["generated_identity"])
assert not common.source_changes(P,old["source_files"])
stamp=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")+"_"+uuid.uuid4().hex[:8]
O=E/"legacy_fixture"/stamp;O.mkdir(parents=True);Q=O/"qa";Q.mkdir()
receipt={"complete":False,"scope":"genuine old three-target initial-world save only","old_source_receipt":str(old_path),"project":str(P),"steps":[],"source_changed":False,"runner_sha256":sha(Path(__file__))};locked=False
try:
 with shared.LOCK.open("x",encoding="utf-8") as f:f.write(str(O))
 locked=True;assert not running()
 bindings={}
 for name in ("bootstrap.gd","base.gd","legacy.gd"):
  shutil.copyfile(E/name,Q/name)
  if name!="bootstrap.gd":bindings[name]=sha(Q/name)
 save(Q/"bindings.json",bindings)
 profile=shared.create_private_profile(O,Path("D:/CodexQA/hgp_legacy"));env=common.private_environment(profile)
 env.update(HG_WORKER=str(Q/"legacy.gd"),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/"bindings.json"),HG_REPORT=str(O/"legacy_report.json"),HG_OUTPUT_ROOT=str(O),HG_LEGACY_COPY=str(O/"slot_copy"))
 common.process_step(shared.resolve_godot(None),P,env,O,"legacy_real_save",["--headless","--script",str(Q/"bootstrap.gd")],240,"gl_compatibility",running,receipt["steps"])
 report=json.loads((O/"legacy_report.json").read_text(encoding="utf-8"));assert report["passed"] and report["profile"]=="campaign_level1_v1" and len(report["load_ids"])==3
 copied=report["copied_fixture_files"];assert len(copied)==2
 assert all(sha(O/"slot_copy"/x["path"])==x["sha256"] for x in copied)
 identity.verify_generated(P,old["generated_identity"]);assert not common.source_changes(P,old["source_files"])
 receipt.update(complete=True,old_source_unchanged=True,fixture_report=str(O/"legacy_report.json"),fixture_files=copied,private_profile=str(profile))
except BaseException as error:receipt["error"]=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8")==str(O):shared.LOCK.unlink()
 receipt["lock_released"]=not shared.LOCK.exists();save(O/"receipt.json",receipt)
save(E/("legacy_success.json" if receipt["complete"] else "legacy_failure_"+stamp+".json"),{"receipt":str(O/"receipt.json")})
print(json.dumps({k:receipt.get(k) for k in ["complete","error","old_source_unchanged","lock_released"]},ensure_ascii=False));assert receipt["complete"]
