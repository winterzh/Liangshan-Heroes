"""Default plan only. --run archives 4baafc1 into a private copy, imports, runs 2x10s.

Live production/public tools are never replaced. All mutations stay in this draft's
new run directory. No automatic longer run, optimization or source restoration.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import time

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
LOCK=ROOT/".godot/redraw_rejection_source.lock"
BASE="4baafc11af55b0e46a57a48e54df181b8c1917a2"
ALLOW={"project.godot","default_bus_layout.tres","scripts","scenes","assets","shaders","resources","data","addons","content","scenarios","tools"}


def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.replace(b"\r\n",b"\n")
def need(ok,message):
    if not ok: raise RuntimeError(message)
def save(path,data): path.write_bytes((json.dumps(data,ensure_ascii=False,indent=2)+"\n").encode())
def module(path):
    namespace={"__file__":str(path),"__name__":"separation_private_helper"}
    exec(compile(path.read_text(encoding="utf-8-sig"),str(path),"exec"),namespace)
    return namespace


def verify_draft(pins):
    need(pins["base"]==BASE,"Wrong frozen Git base")
    for name,value in pins["generated_raw_sha256"].items(): need(sha((HERE/"generated"/name).read_bytes())==value,"Generated file drift: "+name)
    for name,value in pins["template_raw_sha256"].items(): need(sha((HERE/name).read_bytes())==value,"Template drift: "+name)
    need(sha((HERE/"frozen/process_safety.py").read_bytes())==pins["safety_raw_sha256"],"Process guard drift")


def manifest(directory,exclude_godot=True):
    directory=Path(directory)
    need(directory.is_dir(),"Manifest root is missing or not a directory: "+str(directory))
    need(not directory.is_symlink() and not getattr(directory.lstat(),'st_file_attributes',0)&0x400,'Manifest root is a reparse path')
    def scan_failed(error): raise error
    result={}
    for parent,dirs,names in os.walk(directory,followlinks=False,onerror=scan_failed):
        for name in dirs+names:
            entry=Path(parent)/name
            need(not entry.is_symlink() and not getattr(entry.lstat(),'st_file_attributes',0)&0x400,'Unexpected private source reparse path')
        if exclude_godot: dirs[:]=[name for name in dirs if name!='.godot']
        for name in names:
            path=Path(parent)/name
            result[path.relative_to(directory).as_posix()]=sha(path.read_bytes())
    return result


def generated_uid(raw):
    try: value=raw.decode('ascii').strip()
    except UnicodeError: return False
    if not re.fullmatch(r'uid://[a-y0-8]+',value): return False
    digits='abcdefghijklmnopqrstuvwxyz0123456789'[:25]+'012345678'
    number=0
    for char in value[6:]: number=number*34+digits.index(char)
    if number<0 or number>0x7fffffffffffffff: return False
    encoded=''
    while number:
        encoded=digits[number%34]+encoded;number//=34
    return value[6:]==(encoded or 'a') and raw in [(value+'\n').encode(),(value+'\r\n').encode()]


def live_pins(pins):
    # Hash current M2C bytes for preservation, never use them as old runtime input.
    return {name:sha((ROOT/name).read_bytes()) for name in pins["source_lf_sha256"]}


def archive_base(project,archive,pins):
    need(project.resolve().is_relative_to(HERE.resolve()),"Private extraction escaped draft")
    need(subprocess.check_output(["git","cat-file","-t",BASE],cwd=ROOT,text=True).strip()=="commit","Frozen Git object unavailable")
    names=subprocess.check_output(["git","ls-tree","--name-only",BASE],cwd=ROOT,text=True).splitlines()
    chosen=[name for name in names if name in ALLOW]
    need({"project.godot","scripts","scenes","assets","tools"}.issubset(chosen),"Required frozen project paths absent")
    with archive.open("xb") as stream:
        subprocess.run(["git","archive","--format=tar",BASE,"--"]+chosen,cwd=ROOT,stdout=stream,check=True,timeout=300)
    project.mkdir()
    with tarfile.open(archive,"r:") as source:
        for item in source.getmembers():
            path=Path(item.name)
            target=(project/path).resolve()
            need(not path.is_absolute() and not path.drive and project.resolve() in target.parents,"Unsafe archive path")
            need(item.isdir() or item.isfile(),"Archive links/special files are not allowed")
        source.extractall(project)
    for name,value in pins["source_lf_sha256"].items(): need(sha(lf((project/name).read_bytes()))==value,"Git archive differs from reviewed frozen source: "+name)
    config=(project/"project.godot").read_text(encoding="utf-8")
    need(not re.search(r'(?m)^config/(use_custom_user_dir|custom_user_dir_name)\s*=',config),"Custom user directory needs review")


def import_project(safe,exe,project,env,output,timeout=300):
    """Bounded headless asset preparation; exact child handle shares the existing guard."""
    safe["require_exclusive_godot"]()
    process=None; confirmed=False; error=None
    command=[exe,"--headless","--editor","--import","--path",str(project)]
    started=time.monotonic()
    path=output/"import.log"
    try:
        with path.open("wb") as log:
            process=subprocess.Popen(command,cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
            safe["ACTIVE_GODOT_PROCESS"]=process
            try: process.wait(timeout=timeout)
            except BaseException:
                if process.poll() is None: process.kill()
                process.wait(timeout=15)
                raise
    except BaseException as exc:
        error=type(exc).__name__+": "+str(exc)
        raise
    finally:
        if process is not None:
            confirmed=process.poll() is not None
            if confirmed: safe["ACTIVE_GODOT_PROCESS"]=None
        save(output/"import_process.json",{"child_pid":process.pid if process else None,"child_exit_confirmed":confirmed,"timeout_seconds":timeout,
            "command":command,"wall_seconds":time.monotonic()-started,
            "exit_code":process.returncode if confirmed else None,"exception":error,"scope":"asset import only, not a performance sample"})
    need(confirmed and process.returncode==0,"Private import process failed")
    text=path.read_text(encoding="utf-8",errors="replace")
    need(not safe["ERROR"].search(text),"Private import reported warnings/errors; inspect import.log")
    safe["require_exclusive_godot"]()


def private_environment(helper,folder):
    env,controls=helper["environment"]()
    for key in list(env):
        if key.startswith("SEPARATION_SECTIONS_"): env.pop(key)
    roaming=folder/"private_roaming";local=folder/"private_local"
    roaming.mkdir();local.mkdir()
    env.update(APPDATA=str(roaming),LOCALAPPDATA=str(local),CAMPAIGN_QA="1",SEPARATION_SECTIONS_USER_ROOT=str(roaming))
    return env,controls


def measure_pair(safe,exe,project,output,pins,before,isolated_before,receipt,validate_extra=None):
    """Same bounded runtime for a fresh archive or a verified resumed import."""
    helper=module(project/"tools/run_polish_performance.py")
    analyzer=module(HERE/"analyze.py")
    generated=project/"scratchpad/separation_sections_diag/generated"
    for mode in ("timed","clockless"):
        verify_draft(pins);need(live_pins(pins)==before,"Current M2C source changed during private diagnostic")
        need(manifest(project)==isolated_before,"Private source changed before measurement")
        if validate_extra is not None: validate_extra("before_"+mode)
        folder=output/mode;folder.mkdir()
        env,controls=private_environment(helper,folder)
        env.update(SEPARATION_SECTIONS_OUT=str(folder/"separation.json"),SEPARATION_SECTIONS_MODE=mode)
        save(folder/"configuration.json",{"mode":mode,"seconds":10,"camera":"fixed","base":BASE,"controlled_environment":controls,
            "godot_sha256":sha(Path(exe).read_bytes()),"private_project":str(project),"private_user_root":env["SEPARATION_SECTIONS_USER_ROOT"],"performance_claim":False})
        m1=safe["run_godot"](exe,generated/"driver.gd",folder/"m1_10s.json",env,180,validity_key="integrity_passed")
        data=json.loads((folder/"separation.json").read_text(encoding="utf-8-sig"))
        analysis=analyzer["analyze"](m1,data)
        save(folder/"analysis.json",analysis)
        need(manifest(project)==isolated_before,"Private source changed during measurement")
        if validate_extra is not None: validate_extra("after_"+mode)
        receipt["stages"].append({"mode":mode,"analysis_valid":analysis["analysis_valid"]})


def run(args,pins):
    need(os.name=="nt","Private APPDATA policy is Windows-only")
    verify_draft(pins)
    safe=module(HERE/"frozen/process_safety.py")
    # Resolve ignored local engine path on the real checkout before redirecting helper ROOT.
    safe["ROOT"]=ROOT
    exe=safe["resolve_godot"](args.godot)
    safe["require_exclusive_godot"]();need(not LOCK.exists(),"Shared Godot/source slot occupied")
    output=HERE/"runs"/datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output.mkdir(parents=True,exist_ok=False)
    project=output/"project"
    before=live_pins(pins)
    receipt={"base":BASE,"live_before":before,"live_source_mutated_by_runner":False,"complete":False,"lock_released":False,"stages":[]}
    with LOCK.open("x",encoding="utf-8") as stream: stream.write(str(output)+"\n")
    try:
        archive_base(project,output/"base.tar",pins)
        # Only this private copy receives instrumentation; archive retains original bytes.
        (project/"scripts/battle.gd").write_bytes((HERE/"generated/battle_instrumented.gd.txt").read_bytes())
        (project/"scripts/crowd_separation.gd").write_bytes((HERE/"generated/crowd_instrumented.gd.txt").read_bytes())
        generated=project/"scratchpad/separation_sections_diag/generated"
        generated.mkdir(parents=True)
        for name in ("driver.gd","ledger.gd"): shutil.copyfile(HERE/"generated"/name,generated/name)
        safe["ROOT"]=project
        helper=module(project/"tools/run_polish_performance.py")
        isolated_before=manifest(project)
        allowed_uid_sources={name+'.uid':name for name in isolated_before if name.endswith('.gd') and name+'.uid' not in isolated_before}
        save(output/'allowed_import_uid_sources.json',allowed_uid_sources)
        save(output/'runner_sources.json',{name:sha((HERE/name).read_bytes()) for name in ('launch.py','analyze.py')})
        setup=output/"setup";setup.mkdir()
        import_env,_=private_environment(helper,setup)
        import_project(safe,exe,project,import_env,setup)
        imported=manifest(project)
        need(all(imported.get(name)==value for name,value in isolated_before.items()),"Import changed frozen source/metadata; review before measuring")
        created=set(imported)-set(isolated_before)
        need(created<=set(allowed_uid_sources),"Import created unexpected source-side files")
        for name in created: need(generated_uid((project/name).read_bytes()),'Invalid generated Godot UID: '+name)
        save(output/'generated_uid_receipt.json',{name:{'script':allowed_uid_sources[name],'script_sha256':isolated_before[allowed_uid_sources[name]],'uid_sha256':imported[name]} for name in sorted(created)})
        save(output/"private_source_before_import.json",isolated_before)
        isolated_before=imported
        save(output/"private_source_after_import.json",isolated_before)
        measure_pair(safe,exe,project,output,pins,before,isolated_before,receipt)
        receipt["complete"]=True
    except BaseException as exc:
        receipt["exception"]=type(exc).__name__+": "+str(exc)
        raise
    finally:
        try:
            safe["require_exclusive_godot"]()
            receipt["live_after"]=live_pins(pins)
            need(receipt["live_after"]==before,"Live source drift: retain lock; never auto-restore")
            need(LOCK.read_text(encoding="utf-8").strip()==str(output),"Shared lock ownership changed")
            LOCK.unlink();receipt["lock_released"]=True
        except BaseException as exc: receipt["cleanup_error"]=type(exc).__name__+": "+str(exc)
        save(output/"receipt.json",receipt)
        print(json.dumps({"output":str(output),"complete":receipt["complete"],"lock_released":receipt["lock_released"]}))
    return 0 if receipt["complete"] and receipt["lock_released"] else 2


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",action="store_true");parser.add_argument("--godot")
    args=parser.parse_args()
    pins=json.loads((HERE/"pins.json").read_text(encoding="utf-8"))
    verify_draft(pins)
    if not args.run:
        save(HERE/"launch_plan.json",{"base":BASE,"git_run":False,"godot_run":False,"live_source_mutated":False,
            "future_setup":"Git archive into a new private run project, validate paths and frozen source, instrument only that copy, bounded headless import",
            "future_measurements":[{"mode":"timed","seconds":10,"camera":"fixed"},{"mode":"clockless","seconds":10,"camera":"fixed"}],
            "after_pair":"stop for root review; no longer run or optimization","private_user_data":"child-only APPDATA/LOCALAPPDATA","performance_claim":False})
        print("Plan only: no Git, Godot or live source changes")
        return 0
    return run(args,pins)


if __name__=="__main__": sys.exit(main())
