"""Resume an already imported, unchanged private character run after engine guard pause."""
from pathlib import Path
import os,sys,json,shutil,time
repo=Path("E:/ChatGPT/水浒");sys.path.insert(0,str(repo/"tools"))
import run_character_art_qa as qa
shared,running_engine=qa.load_helpers(repo)
run=Path("E:/ChatGPT/qa-hua-rong-20261004/20261004_013857_81e76fba")
prior=run/"evidence/receipt.json";project=run/"project"
receipt=json.loads(prior.read_text(encoding="utf-8"))
assert any(s["case"]=="import" and s["passed"] for s in receipt["steps"])
assert not receipt.get("character_results")
assert shared.LOCK.read_text(encoding="utf-8")==str(run)

engine=shared.resolve_godot(None)
assert qa.sha(engine)==receipt["godot_sha256"]
assert not qa.source_changes(repo,receipt["source_files"])
assert not qa.source_changes(project,receipt["source_files"])
runtime_inventory=shared.sources()
assert set(runtime_inventory)<=set(r["path"] for r in receipt["source_files"])
assert qa.sha(repo/qa.QA_DEST)==receipt["qa_sha256"]==qa.sha(project/qa.QA_DEST)
assert qa.sha(repo/"tools/run_character_art_qa.py")==receipt["driver_sha256"]
evidence=run/("evidence_resume_"+time.strftime("%H%M%S"));evidence.mkdir()
receipt.pop("failure",None);receipt.pop("artifacts",None)
receipt["continued_from"]={"receipt":str(prior),"sha256":qa.sha(prior),"reason":"Shared unrelated Godot appeared after successful import; resumed only after engine slot became idle."}
receipt["resume_runner_sha256"]=qa.sha(Path(__file__))
receipt["complete"]=False
receipt["engine_guard_pauses"]=[]
resume_deadline=time.monotonic()+3600
def wait_slot(label):
 idle_since=None;last=0;recorded=False
 while True:
  now=time.monotonic()
  if running_engine():
   idle_since=None
   if not recorded:
    receipt["engine_guard_pauses"].append({"step":label,"reason":"Other Godot occupied before launch or close"})
    recorded=True
  elif idle_since is None:idle_since=now
  elif now-idle_since>=30:return
  if now>resume_deadline:raise RuntimeError("Bounded shared-engine wait exceeded; no other process changed")
  if now-last>45:print("WAIT before "+label,flush=True);last=now
  time.sleep(5)
def guarded_step(*args):
 while True:
  wait_slot(args[4])
  assert shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8")==str(run)
  try:return qa.process_step(*args)
  except RuntimeError as exc:
   if str(exc).startswith("Godot/Liangshan engine appeared before step"):
    receipt["engine_guard_pauses"].append({"step":args[4],"reason":str(exc)})
    continue
   raise
profile=Path(receipt["private_profile"])
env=os.environ.copy()
prefixes=("LSH_","RTS_","KH_","HNS_","HNA_","DAMING_","MENGZHOU_","SIEGE_","ART_","LC_","SJ_","SL_","DIRECTION4_","ZHU_","DEF_","STEAM_QA_","CAMPAIGN_QA_","PLAYTEST_")
exact={"LEVEL","SCENARIO","CUSTOM_DEFENSE","SKIRMISH","SKIRMISH_AI","ARENA","AUTO_MICRO","AUTOMICRO","AI_FRIENDLY","AI_DIFF","VICTORY","SCALE_ON","ENEMY_MULT","HERO_MULT","SCALE_LOCKED"}
for k in list(env):
 if k.endswith(("_TEST","_QA","_QA_MANIFEST","_AUDIT")) or k.startswith(prefixes) or k in exact:env.pop(k)
env.update(receipt["private_environment"])
env.update(STEAM_DISABLED="1",CAMPAIGN_QA="1",LSH_LANGUAGE="zh_CN",ART_QA_PROFILE=str(profile))
(evidence/"harness").mkdir()
shutil.copyfile(run/"evidence/import.log",evidence/"import.log")
for p in (repo/qa.QA_DEST,repo/"tools/run_character_art_qa.py",Path(__file__)):
 shutil.copyfile(p,evidence/"harness"/p.name)
try:
 receipt["character_results"]=[]
 for case in receipt["selected_cases"]:
  directory=evidence/case["character"];directory.mkdir()
  guarded_step(engine,project,env|{"ART_CHARACTER":case["character"],"ART_MANIFEST":"res://"+case["manifest"],"ART_QA_OUT":str(directory),"ART_VISUAL":"1"},evidence,case["character"],["--position","20000,20000","--script","res://"+qa.QA_DEST],1000,"gl_compatibility",running_engine,receipt["steps"])
  receipt["character_results"].append(qa.verify_character_report(case,directory,True))
 for label,script,outkey in (("routing","skirmish_direction4_contract_test.gd","DIRECTION4_CONTRACT_OUT"),("inventory","character_direction4_inventory.gd","DIRECTION4_INVENTORY_OUT")):
  directory=evidence/label;directory.mkdir()
  guarded_step(engine,project,env|{outkey:str(directory)},evidence,label,["--headless","--script","res://tools/"+script],1000,"gl_compatibility",running_engine,receipt["steps"])
  report=json.loads((directory/("report.json" if label=="routing" else "inventory.json")).read_text(encoding="utf-8"))
  assert report.get("passed") is True and not report.get("failures") if label=="routing" else isinstance(report.get("units"),list)
 wait_slot("close_and_release")
 receipt["complete"]=True
except BaseException as e:
 receipt["failure"]={"type":type(e).__name__,"message":str(e)}
finally:
 receipt["source_changes"]=qa.source_changes(repo,receipt["source_files"])
 receipt["private_source_changes"]=qa.source_changes(project,receipt["source_files"])
 receipt["runtime_inventory_unchanged"]=shared.sources()==runtime_inventory
 receipt["qa_unchanged"]=qa.sha(repo/qa.QA_DEST)==receipt["qa_sha256"]==qa.sha(project/qa.QA_DEST)
 receipt["driver_unchanged"]=qa.sha(repo/"tools/run_character_art_qa.py")==receipt["driver_sha256"]
 receipt["godot_unchanged"]=qa.sha(engine)==receipt["godot_sha256"]
 receipt["resume_runner_unchanged"]=qa.sha(Path(__file__))==receipt["resume_runner_sha256"]
 receipt["engines_remaining"]=running_engine()
 if not receipt["engines_remaining"] and shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8")==str(run):shared.LOCK.unlink()
 receipt["lock_released"]=not shared.LOCK.exists()
 receipt["complete"]=receipt["complete"] and not receipt["source_changes"] and not receipt["private_source_changes"] and all(receipt[k] for k in ("runtime_inventory_unchanged","qa_unchanged","driver_unchanged","godot_unchanged","resume_runner_unchanged","lock_released"))
 receipt["artifacts"]=[{"path":p.relative_to(evidence).as_posix(),"sha256":qa.sha(p),"bytes":p.stat().st_size} for p in sorted(evidence.rglob("*")) if p.is_file() and p.name!="receipt.json"]
 (evidence/"receipt.json").write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(json.dumps({"complete":receipt["complete"],"evidence":str(evidence),"checks":sum(r["checks"] for r in receipt.get("character_results",[])),"failure":receipt.get("failure")},ensure_ascii=False),flush=True)
sys.exit(0 if receipt["complete"] else 1)
