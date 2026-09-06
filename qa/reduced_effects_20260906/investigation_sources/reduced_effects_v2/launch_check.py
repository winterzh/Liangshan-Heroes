"""DRAFT external launch checks. Default writes a plan only; --run is explicit.

Never applies a patch or changes production files. Candidate source (or the explicit
legacy Settings boot profile) must already be present and passes hashes BEFORE Godot.
Windows-only runs isolate APPDATA/LOCALAPPDATA in the private run directory.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SAFETY = ROOT / "scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py"
LOCK = ROOT / ".godot/redraw_rejection_source.lock"


def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.replace(b"\r\n", b"\n")
def save(path,value): path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+"\n").encode())
def need(ok,message):
    if not ok: raise RuntimeError(message)


def expected_hashes(pins, profile):
    expected=dict(pins["candidate_lf_sha256"])
    if profile=="legacy": expected["scripts/settings.gd"]=pins["base_lf_sha256"]["scripts/settings.gd"]
    return expected


def check_live_source(pins, preparation, profile):
    observed={name:sha(lf((ROOT/name).read_bytes())) for name in expected_hashes(pins,profile)}
    expected=expected_hashes(pins,profile)
    need(observed==expected,"Source profile mismatch before Godot; this runner never applies/replaces source")
    need(sha((HERE/"generated/driver.gd").read_bytes())==preparation["qa_sha256"],"Generated QA source changed")
    need(sha(SAFETY.read_bytes())==pins["safety_helper_raw_sha256"],"Enhanced process safety helper changed")
    for name,expected_raw in pins["startup_dependency_raw_sha256"].items():
        need(sha((ROOT/name).read_bytes())==expected_raw,"Startup dependency changed before Godot: "+name)
    project=(ROOT/"project.godot").read_text(encoding="utf-8-sig")
    need(not re.search(r'(?m)^config/(use_custom_user_dir|custom_user_dir_name)\s*=',project),"Custom user-directory policy needs separate review")
    need('Settings="*res://scripts/settings.gd"' in project,"Settings Autoload mapping changed")
    need('AndroidUpdater="*res://scripts/android_updater.gd"' in project,"Autoload bootstrap mapping changed")
    return observed


def source_manifest():
    rows={}
    paths=[ROOT/"project.godot",ROOT/"tools/run_polish_performance.py",SAFETY,HERE/"generated/driver.gd"]
    for folder in ("scripts","scenes","assets","shaders","resources","data","addons","content","scenarios"):
        paths.extend(p for p in (ROOT/folder).rglob("*") if p.is_file())
    text_suffix={".gd",".tscn",".tres",".gdshader",".gdshaderinc",".json",".cfg",".import",".uid",".svg",".txt",".csv",".godot",".py",".md"}
    for path in sorted(set(paths)):
        raw=path.read_bytes()
        rows[path.relative_to(ROOT).as_posix()]=sha(lf(raw) if path.suffix.lower() in text_suffix else raw)
    return {"files":rows,"combined_sha256":sha(json.dumps(rows,sort_keys=True).encode()),"git_used":False}


def private_preferences(roaming):
    rows={}
    for name in ("settings.cfg","campaign.cfg"):
        for path in roaming.rglob(name):
            need(roaming.resolve() in path.resolve().parents,"Private preference path escaped run directory")
            rows[path.relative_to(roaming).as_posix()]={"bytes":path.stat().st_size,"sha256":sha(path.read_bytes())}
    return rows


def launch(args,pins,preparation):
    need(os.name=="nt","Prepared boot isolation is pinned to Windows")
    check_live_source(pins,preparation,args.profile)
    namespace={"__file__":str(SAFETY),"__name__":"reduced_effects_v2_process_guard"}
    exec(compile(SAFETY.read_text(encoding="utf-8-sig"),str(SAFETY),"exec"),namespace)
    namespace["require_exclusive_godot"]()
    need(not LOCK.exists(),"Shared source lock is occupied")
    exe=namespace["resolve_godot"](args.godot)
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output=HERE/"runs"/stamp
    output.mkdir(parents=True,exist_ok=False)
    roaming=output/"private_roaming"; local=output/"private_local"
    roaming.mkdir();local.mkdir()
    need(HERE.resolve() in roaming.resolve().parents and HERE.resolve() in local.resolve().parents,"Isolation path must stay in draft")
    helpers=namespace["baseline_helpers"]()
    env,env_receipt=helpers["environment"]()
    for key in list(env):
        if key.startswith("REDUCED_EFFECTS_"): env.pop(key)
    # Child-only env; do not mutate os.environ or use a nonexistent Godot CLI flag.
    env.update(APPDATA=str(roaming),LOCALAPPDATA=str(local),QA_ONLY="1",CAMPAIGN_QA="1",
        REDUCED_EFFECTS_QA_USER_ROOT=str(roaming),REDUCED_EFFECTS_QA_OUT="res://"+output.relative_to(ROOT).as_posix(),
        REDUCED_EFFECTS_QA_RENDER="1" if args.render else "0")
    source=source_manifest()
    before=private_preferences(roaming)
    receipt={"source_mutated_by_runner":False,"performance_claim":False,"profile":args.profile,"stages":[],
             "private_user_root":str(roaming),"private_preferences_before":before,"lock_released":False}
    save(output/"configuration.json",{"profile":args.profile,"stages":args.stages,"render":args.render,
        "godot_sha256":sha(Path(exe).read_bytes()),"controlled_production_environment":env_receipt,
        "source_profile":expected_hashes(pins,args.profile),"qa_sha256":preparation["qa_sha256"],
        "child_only_private_APPDATA":str(roaming),"child_only_private_LOCALAPPDATA":str(local),
        "known_user_data_rule_source":"https://raw.githubusercontent.com/godotengine/godot/4.6/platform/windows/os_windows.cpp",
        "historical_apk_pck_boot_equivalence_claimed":False})
    save(output/"sources_before.json",source)
    with LOCK.open("x",encoding="utf-8") as file: file.write(str(output)+"\n")
    success=False
    try:
        for stage in args.stages:
            check_live_source(pins,preparation,args.profile)
            need(source_manifest()["combined_sha256"]==source["combined_sha256"],"Production/resources changed before startup")
            env["REDUCED_EFFECTS_QA_STAGE"]=stage
            path=output/("report_"+stage+".json")
            report=namespace["run_godot"](exe,HERE/"generated/driver.gd",path,env,args.timeout,
                headless=False,validity_key="automated_checks_passed")
            actual=Path(report["actual_user_dir"]).resolve()
            need(roaming.resolve() in actual.parents,"Runtime user:// did not stay in the private APPDATA")
            check_live_source(pins,preparation,args.profile)
            need(source_manifest()["combined_sha256"]==source["combined_sha256"],"Production/resources changed during startup/test")
            need(private_preferences(roaming)==before,"Unexpected writes to isolated Autoload preferences")
            receipt["stages"].append({"stage":stage,"checks":report["checks"],"report":path.name,
                "automated_checks_passed":report["automated_checks_passed"],"actual_user_dir":str(actual)})
            save(output/"running_receipt.json",receipt)
        success=True
    except BaseException as exc:
        receipt["exception"]=type(exc).__name__+": "+str(exc)
        raise
    finally:
        # run_godot retains the exact owned Popen handle if exit is unconfirmed.
        # No source restoration is attempted: this guard never mutated source.
        try:
            namespace["require_exclusive_godot"]()
            check_live_source(pins,preparation,args.profile)
            after=source_manifest()
            save(output/"sources_after.json",after)
            receipt["private_preferences_after"]=private_preferences(roaming)
            unchanged=after["combined_sha256"]==source["combined_sha256"] and receipt["private_preferences_after"]==before
            receipt["sources_and_preferences_unchanged"]=unchanged
            if unchanged:
                need(LOCK.read_text(encoding="utf-8").strip()==str(output),"Lock ownership changed")
                LOCK.unlink();receipt["lock_released"]=True
        except BaseException as exc:
            receipt["final_guard_error"]=type(exc).__name__+": "+str(exc)
        save(output/"exit_receipt.json",receipt)
        print(json.dumps({"output":str(output),"lock_released":receipt["lock_released"],"performance_claim":False}),flush=True)
    return 0 if success and receipt["lock_released"] else 2


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--profile",choices=("candidate","legacy"),default="candidate")
    parser.add_argument("--stages",nargs="+",choices=("all","restart_write","restart_read","freed_target_boundary","legacy_autoload"),default=["all"])
    parser.add_argument("--render",action="store_true")
    parser.add_argument("--timeout",type=int,default=240)
    args=parser.parse_args()
    need(args.timeout>=30 and len(set(args.stages))==len(args.stages),"Invalid bounded stage specification")
    if args.profile=="legacy": need(args.stages==["legacy_autoload"],"Legacy profile runs only legacy_autoload stage")
    else: need("legacy_autoload" not in args.stages,"Legacy stage needs the explicit legacy profile")
    if "restart_read" in args.stages:
        need("restart_write" in args.stages and args.stages.index("restart_write")<args.stages.index("restart_read"),"Restart writer/reader must be separate processes in the same new run")
    pins=json.loads((HERE/"pins.json").read_text(encoding="utf-8"))
    preparation=json.loads((HERE/"preparation_receipt.json").read_text(encoding="utf-8"))
    if not args.run:
        save(HERE/"launch_plan.json",{"godot_run":False,"production_mutated":False,"profile":args.profile,"stages":args.stages,
            "render_requested":args.render,"source_must_match_before_boot":expected_hashes(pins,args.profile),
            "patch_application":"owned by root task; this runner never mutates source",
            "private_user_data":"child APPDATA and LOCALAPPDATA under new runs directory; startup asserts actual user:// containment",
            "source_first_policy":"hash four production sources and generated QA before Godot class/autoload parsing",
            "performance_claim":False})
        print("Prepared launch checks only; no Godot, Git or production changes")
        return 0
    return launch(args,pins,preparation)


if __name__=="__main__": sys.exit(main())
