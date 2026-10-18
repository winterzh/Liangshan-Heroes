from pathlib import Path
import datetime,hashlib,importlib.util,json,shutil,sys,uuid
R=Path(r"D:/AI项目/水浒/开发工程");E=Path(__file__).parent;sys.path.insert(0,str(R/"tools"))
import run_character_art_qa as common
shared,running=common.load_helpers(R)
assert not (E/"package_phases_success.json").exists(),"completed immutable phase must not be rerun"
spec=importlib.util.spec_from_file_location("hg_identity_generator",R/"tools/contracts/run_content_identity_20260907/build_identity.py")
identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):
 with p.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()
def save(p,d):
 with p.open("x",encoding="utf-8") as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+"\n")
def load(p):return json.loads(p.read_text(encoding="utf-8"))
assert not running() and not shared.LOCK.exists(),"shared engine lane occupied"
export_path=Path(load(E/"export_identity_success.json")["receipt"]);export=load(export_path)
legacy_path=Path(load(E/"legacy_success.json")["receipt"]);legacy=load(legacy_path)
assert export["complete"] and export["lock_released"] and legacy["complete"] and legacy["lock_released"]
B=export_path.parent;P=Path(export["project"]);runtime=Path(export["exe"]["path"]).parent
identity.verify_generated(P,load(B/"generation.json"))
root_before=load(Path(export["preparation"]).parent/"root_before.json");assert identity.snapshot(R)==root_before
pins={Path(export["pck"]["path"]):export["pck"]["sha256"],Path(export["exe"]["path"]):export["exe"]["sha256"]}
for row in export["native_root_dlls"]:pins[runtime/row["path"]]=row["sha256"]
assert all(sha(path)==digest for path,digest in pins.items())
stamp=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")+"_"+uuid.uuid4().hex[:8]
O=E/"package_phases"/stamp;O.mkdir(parents=True,exist_ok=False);Q=O/"qa";Q.mkdir()
receipt={"complete":False,"scope":"exact new release package live route, world roundtrips, fresh carried continuation and genuine legacy refusal","export_receipt":str(export_path),"legacy_receipt":str(legacy_path),"steps":[],"reports":[],"production_applied":False,"full_goal_complete":False,"rendered_art_accepted":False,"native_steam_account_tested":False,"runner_sha256":sha(Path(__file__))};locked=False
try:
 with shared.LOCK.open("x",encoding="utf-8") as f:f.write(str(O))
 locked=True;assert not running()
 bindings={};qa_pins={}
 for name in ("bootstrap.gd","base.gd","identity.gd","live.gd","world.gd","cold_carried.gd","legacy_reject.gd"):
  shutil.copyfile(E/name,Q/name);qa_pins[name]=sha(Q/name)
  if name!="bootstrap.gd":bindings[name]=qa_pins[name]
 save(Q/"bindings.json",bindings)
 reports={}
 for key,timeout in [("live",360),("world",360),("cold_carried",240),("legacy_reject",180)]:
  phase=O/key;phase.mkdir();profile=shared.create_private_profile(phase,Path("D:/CodexQA/hgp_phase")/stamp)
  env=common.private_environment(profile)
  env.update(HG_WORKER=str(Q/(key+".gd")),HG_WORKER_ROOT=str(Q),HG_QA_BINDINGS=str(Q/"bindings.json"),HG_EXPECTED_IDENTITY=str(B/"expected_identity.json"),HG_EXPECTED_EXE_SHA=export["exe"]["sha256"],HG_REPORT=str(phase/"report.json"),HG_OUTPUT_ROOT=str(phase),HG_ROUTE_OUT=str(phase),HG_CARRIED_COPY=str(phase/"carried_fixture"))
  if key in ("cold_carried","legacy_reject"):
   if key=="cold_carried":
    producer=reports["world"];assert producer["full_world_save_restore_tested"] and len(producer["session_roundtrips"])==3
    fixture=O/"world/carried_fixture";rows=producer["carried_fixture_files"];namespace="hg_transport_world"
    env["HG_COLD_EXPECTED"]=str(O/"world/report.json")
   else:
    producer=load(Path(legacy["fixture_report"]));fixture=legacy_path.parent/"slot_copy";rows=producer["copied_fixture_files"];namespace="hg_legacy3"
    env["HG_LEGACY_EXPECTED"]=legacy["fixture_report"]
   assert len(rows)==2 and len(list(fixture.rglob("*.json")))==2
   target=profile/"appdata/Godot/app_userdata/水浒英雄传：八幕战役"/namespace
   copies=[]
   for row in rows:
    relative=Path(row["path"]);assert not relative.is_absolute() and ".." not in relative.parts
    source=fixture/relative;identity.no_links(source);assert source.resolve().is_relative_to(fixture.resolve()) and sha(source)==row["sha256"]
    destination=target/relative;identity.no_links(destination);assert destination.resolve().is_relative_to(profile.resolve()) and not destination.exists()
    destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination);assert sha(destination)==row["sha256"]
    copies.append({"path":str(destination),"sha256":sha(destination)})
   save(phase/"fixture_copies.json",copies)
  common.process_step(Path(export["exe"]["path"]),runtime,env,phase,key,["--main-pack",export["pck"]["path"],"--resolution","1280x720","--position","30000,30000","--script",str(Q/"bootstrap.gd")],timeout,"gl_compatibility",running,receipt["steps"])
  report=load(phase/"report.json");assert report["passed"] and not report["failures"] and len(report["checks"])>0
  assert report["trusted_identity"]["content_version"]=="source-v1:"+export["source_sha256"] and report["trusted_identity"]["source_mode"] is False
  reports[key]=report;receipt["reports"].append({"phase":key,"path":str(phase/"report.json"),"sha256":sha(phase/"report.json"),"checks":len(report["checks"]),"pid":report["pid"]})
  assert all(sha(path)==digest for path,digest in pins.items()) and all(sha(Q/name)==digest for name,digest in qa_pins.items())
 identity.verify_generated(P,load(B/"generation.json"));assert identity.snapshot(R)==root_before
 receipt.update(complete=True,root_unchanged=True,package_unchanged=True,qa_inputs=qa_pins,all_native_phases_complete=True,ordinary_player_continue_entry_tested=False)
except BaseException as error:receipt["error"]=repr(error)
finally:
 if locked and not running() and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8")==str(O):shared.LOCK.unlink()
 receipt["lock_released"]=not shared.LOCK.exists();save(O/"receipt.json",receipt)
save(E/("package_phases_success.json" if receipt["complete"] else "package_phases_failure_"+stamp+".json"),{"receipt":str(O/"receipt.json")})
print(json.dumps({k:receipt.get(k) for k in ["complete","error","lock_released"]},ensure_ascii=False));assert receipt["complete"]
