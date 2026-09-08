"""Freeze a private project and run Steam feature QA without logging into Steam."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
RUNTIME_DIRS = {"scripts", "scenes", "assets", "content", "scenarios", "fonts", "shaders"}
ROOT_FILES = {"project.godot", "export_presets.cfg", "icon.ico", "icon.png", "icon.png.import"}
EXTENSION = '''[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.4"
[libraries]
windows.debug.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"
[dependencies]
windows.x86_64 = { "res://addons/godotsteam/win64/steam_api64.dll": "" }
'''
READER_EXTENSION = '''[configuration]
entry_symbol = "lsh_stats_reader_init"
compatibility_minimum = "4.4"
[libraries]
windows.x86_64 = "res://addons/steam_stats_reader/steam_stats_reader.dll"
'''
NATIVE_BINDINGS = ["res://addons/godotsteam/godotsteam.gdextension", "res://addons/steam_stats_reader/reader.gdextension"]

def sources():
    raw = subprocess.check_output(["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT)
    names = sorted(set(raw.decode("utf-8").split("\0")) - {""})
    return [p for p in names if p in ROOT_FILES or p.split("/")[0] in RUNTIME_DIRS]

def native_dependencies(include_reader=True):
    """Read and verify fixed dependency manifests without loading Steam."""
    manifests = {}
    for name in (["godotsteam", "steam_stats_reader"] if include_reader else ["godotsteam"]):
        vendor = ROOT / "vendor" / name
        manifest = json.loads((vendor / "provenance.json").read_text(encoding="utf-8"))
        seen = set()
        for item in manifest["files"]:
            relative = item["path"]
            if relative in seen or Path(relative).is_absolute() or "\\" in relative or any(p in ("", ".", "..") for p in relative.split("/")):
                raise RuntimeError("Invalid dependency path: " + relative)
            seen.add(relative)
            source = vendor / relative
            if hashlib.sha256(source.read_bytes()).hexdigest() != item["sha256"]:
                raise RuntimeError("Modified dependency: " + str(source))
            if "bytes" in item and source.stat().st_size != item["bytes"]:
                raise RuntimeError("Modified dependency size: " + str(source))
        if name == "steam_stats_reader" and seen != {"win64/steam_stats_reader.dll", "GODOT_CPP_LICENSE.md"}:
            raise RuntimeError("Unexpected reader dependency inventory")
        manifests[name] = manifest
    return manifests

def install_native(project, include_reader=True):
    manifests = native_dependencies(include_reader)
    for name, manifest in manifests.items():
        for item in manifest["files"]:
            source = ROOT / "vendor" / name / item["path"]
            relative = Path(item["path"]).name if name == "steam_stats_reader" else item["path"]
            dest = project / "addons" / name / relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, dest)
            if hashlib.sha256(dest.read_bytes()).hexdigest() != item["sha256"]:
                raise RuntimeError("Dependency changed during install: " + str(source))
    (project / "addons/godotsteam/godotsteam.gdextension").write_text(EXTENSION, encoding="utf-8")
    if include_reader:
        (project / "addons/steam_stats_reader/reader.gdextension").write_text(READER_EXTENSION, encoding="utf-8")
    # Register before first import: late native class discovery can crash Godot.
    cache = project / ".godot"
    cache.mkdir(exist_ok=True)
    (cache / "extension_list.cfg").write_text("\n".join(NATIVE_BINDINGS if include_reader else NATIVE_BINDINGS[:1]) + "\n", encoding="utf-8")
    return manifests

def resolve_godot(value):
    value = value or os.environ.get("GODOT_PATH", "") or (ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip()
    path = Path(value)
    if path.stem.endswith("_console"):
        path = path.with_name(path.name.replace("_console.exe", ".exe"))
    if not path.is_file(): raise RuntimeError("Non-console Godot executable unavailable")
    return path.resolve()

def resolve_profile_root(value):
    """An optional short parent; never follow links or reuse a prior profile."""
    if value is None: return None
    path = Path(value)
    if not path.is_absolute(): raise RuntimeError("--profile-root must be an absolute path")
    for item in [path] + list(path.parents):
        if item.exists() or item.is_symlink():
            attributes = item.lstat()
            if item.is_symlink() or getattr(attributes, "st_file_attributes", 0) & 0x400:
                raise RuntimeError("Profile link/reparse path refused: " + str(item))
            if not item.is_dir(): raise RuntimeError("Profile parent is not a directory: " + str(item))
    return path

def create_private_profile(run, profile_root):
    parent = resolve_profile_root(profile_root)
    profile = run / "profile" if parent is None else parent / run.name
    resolve_profile_root(profile)
    profile.mkdir(parents=True, exist_ok=False)
    resolve_profile_root(profile)
    return profile

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--visual", action="store_true")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--profile-root", type=Path, help="Absolute short parent for a new, exclusive private profile")
    parser.add_argument("--cache-from", type=Path, help="Prior private QA run; reuse imported textures only")
    args = parser.parse_args()
    profile_root = resolve_profile_root(args.profile_root)
    if not args.run:
        print(json.dumps({"preflight":True, "source_files":len(sources()), "godot":str(resolve_godot(args.godot)), "lock_busy":LOCK.exists(), "profile_root":str(profile_root) if profile_root else None}))
        return
    running = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
    if running and json.loads(running): raise RuntimeError("Godot is running; shared engine slot unavailable")
    run = ROOT / ".godot/steam_integration_qa" / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    run.mkdir(parents=True)
    with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
    receipt = {"complete":False, "native":args.native, "visual":args.visual, "source_head":subprocess.check_output(["git","rev-parse","HEAD"], cwd=ROOT, text=True).strip(), "steps":[], "source_files":[]}
    child = None
    try:
        project = run / "project"
        project.mkdir()
        runtime_paths = sources()
        for name in runtime_paths + ["tools/steam_integration_qa.gd", "tools/steam_integration_suite.gd", "tools/steam_catalog_export.gd", "tools/steam_fake_api.gd"]:
            source = ROOT / name
            data = source.read_bytes()
            dest = project / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            receipt["source_files"].append({"path":name, "sha256":hashlib.sha256(data).hexdigest()})
        if args.cache_from:
            prior = args.cache_from.resolve()
            prior.relative_to((ROOT / ".godot/steam_integration_qa").resolve())
            imported = prior / "project/.godot/imported"
            if not imported.is_dir(): raise RuntimeError("Imported texture cache unavailable")
            shutil.copytree(imported, project / ".godot/imported")
            receipt["imported_texture_cache"] = str(prior.relative_to(ROOT))
        if args.native: receipt["native_dependencies"] = install_native(project)
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key in ["LEVEL","SCENARIO","CUSTOM_DEFENSE","SKIRMISH","SKIRMISH_AI","ARENA","AUTO_MICRO","AUTOMICRO"]:
                env.pop(key)
        profile = create_private_profile(run, profile_root)
        receipt["private_profile"] = str(profile)
        for key in ["APPDATA","LOCALAPPDATA","TEMP","TMP"]:
            private = profile / key.lower()
            private.mkdir()
            env[key] = str(private)
        env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", STEAM_QA_OUTPUT=str(run), STEAM_CATALOG_OUTPUT=str(run / "backend"), STEAM_QA_VISUAL="1" if args.visual else "0", STEAM_QA_NATIVE="1" if args.native else "0")
        engine = str(resolve_godot(args.godot))
        for name, extra in [("import", ["--headless","--editor","--import"]), ("catalog", ["--headless","--script","res://tools/steam_catalog_export.gd"]), ("contracts", ([] if args.visual else ["--headless"]) + ["--script","res://tools/steam_integration_qa.gd"])]:
            log = run / (name + ".log")
            command = [engine,"--path",str(project)] + extra
            print("RUN " + name + " " + str(run), flush=True)
            started = time.time()
            with log.open("wb") as output:
                child = subprocess.Popen(command, cwd=project, env=env, stdout=output, stderr=subprocess.STDOUT, creationflags=getattr(subprocess,"CREATE_NO_WINDOW",0))
                try: code = child.wait(timeout=600)
                except BaseException:
                    child.kill(); child.wait(timeout=30); raise
            receipt["steps"].append({"name":name,"exit_code":code,"seconds":round(time.time()-started,2)})
            text = log.read_text(encoding="utf-8", errors="replace")
            if code or "SCRIPT ERROR" in text or "Parse Error" in text or "ERROR:" in text:
                lines = text.splitlines()
                keep = set()
                for i,line in enumerate(lines):
                    if "ERROR" in line or "FAIL" in line:
                        keep.update(range(max(0,i-1),min(len(lines),i+5)))
                print("\n".join(lines[i] for i in sorted(keep))[-12000:] or text[-2500:])
                raise RuntimeError(name + " failed")
        report = json.loads((run / "report.json").read_text(encoding="utf-8"))
        if not report["passed"]: raise RuntimeError("Behavioral checks failed")
        for row in receipt["source_files"]:
            if hashlib.sha256((ROOT / row["path"]).read_bytes()).hexdigest() != row["sha256"]:
                raise RuntimeError("Source changed during test: " + row["path"])
        if sources() != runtime_paths: raise RuntimeError("Runtime source inventory changed during test")
        if args.native and native_dependencies() != receipt["native_dependencies"]:
            raise RuntimeError("Native dependency manifest changed during test")
        receipt["complete"] = True
        receipt["checks"] = len(report["checks"])
    finally:
        if child is not None and child.poll() is None:
            child.kill(); child.wait(timeout=30)
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        if LOCK.read_text(encoding="utf-8") == str(run): LOCK.unlink()
        print(json.dumps({"complete":receipt["complete"], "run":str(run), "checks":receipt.get("checks",0)}), flush=True)

if __name__ == "__main__":
    main()
