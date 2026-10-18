from pathlib import Path
import datetime,hashlib,importlib.util,json,shutil,sys,uuid
R=Path(r"D:/AI项目/水浒/开发工程");E=Path(__file__).parent
sys.path.insert(0,str(R/"tools"))
import run_character_art_qa as common
shared,running=common.load_helpers(R)
spec=importlib.util.spec_from_file_location("hg_identity_generator",R/"tools/contracts/run_content_identity_20260907/build_identity.py")
identity=importlib.util.module_from_spec(spec);spec.loader.exec_module(identity)
def sha(p):
 with p.open("rb") as f:return hashlib.file_digest(f,"sha256").hexdigest()
def save(p,d):
 with p.open("x",encoding="utf-8") as f:f.write(json.dumps(d,ensure_ascii=False,indent=2)+"\n")
stamp=datetime.datetime.now().strftime("%Y%m%d_%H%M%S")+"_"+uuid.uuid4().hex[:8]
P=R/".godot/chao_gai_full_package"/stamp/"project"
identity.no_links(P);P.mkdir(parents=True,exist_ok=False)
O=E/"prepared_source"/stamp;O.mkdir(parents=True,exist_ok=False)
receipt={"prepared":False,"native_executed":False,"exported":False,"project":str(P),"output":str(O),"preparer_sha256":sha(Path(__file__)),"full_goal_complete":False}
try:
 root=identity.snapshot(R);save(O/"root_before.json",root)
 candidate=json.loads((E/"integration_candidate.json").read_text(encoding="utf-8"))
 assert candidate["applied"] is False and len(candidate["files"])==2
 # Freeze all actual normative inputs, including raw .gdignore art and existing descriptors.
 for name,present in root["directories"].items():
  if present and not name.startswith("@file/"):(P/name).mkdir(parents=True,exist_ok=True)
 for row in root["files"]:
  source=R/row["path"];target=P/row["path"]
  assert sha(source)==row["sha256"]
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
  assert sha(target)==row["sha256"]
 for row in candidate["files"]:
  name=row["path"];assert sha(R/name)==row["before_sha256"]
  source=E/"candidate"/name;assert sha(source)==row["candidate_sha256"]
  shutil.copyfile(source,P/name);assert sha(P/name)==row["candidate_sha256"]
 receipt["native_provenance"]=shared.install_native(P)
 receipt["seed"]=identity.seed(P)
 prepared=identity.snapshot(P);save(O/"prepared_before_import.json",prepared)
 assert identity.snapshot(R)==root,"Root inputs drifted during private preparation"
 receipt.update(prepared=True,root_unchanged=True,root_source_sha256=root["source_sha256"],preimport_source_sha256=prepared["source_sha256"],copied_root_files=len(root["files"]),copied_root_bytes=root["total_bytes"],candidate_files=candidate["files"])
except BaseException as error:receipt["error"]=repr(error)
finally:save(O/"preparation.json",receipt)
if receipt["prepared"]:
 # Single pointer is created only for the first successful prepared source.
 save(E/"prepared_source_current.json",{"receipt":str(O/"preparation.json")})
print(json.dumps({k:receipt.get(k) for k in ["prepared","project","output","copied_root_files","copied_root_bytes","error"]},ensure_ascii=False))
assert receipt["prepared"]
