"""Export a private Windows Steam feature candidate from a successful QA snapshot.

No upload or publication; this is not the commercial artwork/readiness gate.
The runtime allowlist includes the reviewed four-language catalog and font.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import time
import uuid
import zipfile
from run_steam_integration_qa import ROOT, LOCK, install_native, resolve_godot, resolve_profile_root, create_private_profile
from steam_candidate_verification import verify
from contracts.run_content_identity_20260907.build_identity import seed, generate, verify_generated, DERIVED
from contracts.run_content_identity_20260907.probe_runner import run_locked as probe_content_identity, utilities as identity_utilities

CORE = {"project.godot", "export_presets.cfg", "icon.png", "icon.png.import", "icon.ico"}
LOCALIZATION = {"assets/localization/catalog.json", "assets/fonts/NotoSansCJK-Regular.ttc",
                "assets/fonts/NotoSansCJK-Regular.ttc.import", "assets/fonts/OFL.txt"}
RUNTIME = ("assets/anim/", "assets/campaign/anim/", "assets/campaign/objects/",
           "assets/campaign/portraits/", "assets/campaign/environment/", "assets/vfx/", "assets/characters/")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def allowed(name):
    path = PurePosixPath(name)
    if name in CORE or name in LOCALIZATION: return True
    if name.startswith("content/"): return path.suffix == ".json"
    if name.startswith("scripts/"): return path.suffix in {".gd", ".gdshader", ".uid"}
    if name.startswith("scenes/"): return path.suffix == ".tscn"
    if path.parent == PurePosixPath("assets") or name.startswith("assets/ui/"):
        return "_raw" not in name and "/atlases/" not in name and name.endswith((".png", ".png.import"))
    return name.startswith(RUNTIME) and "_raw" not in name and name.endswith((".png", ".png.import", ".tres"))

def package_archive(run, windows):
    archive = run / "LiangshanHeroes_Steam_candidate.zip"
    if archive.exists(): raise RuntimeError("Refusing to overwrite a candidate archive")
    sources = [(p, p.relative_to(windows).as_posix()) for p in sorted(windows.rglob("*")) if p.is_file()]
    sources.append((ROOT / "vendor/godotsteam/license.md", "GODOTSTEAM_LICENSE.txt"))
    rows = [{"path":name,"bytes":path.stat().st_size,"sha256":sha(path)} for path,name in sources]
    with zipfile.ZipFile(archive,"w",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as output:
        for path,name in sources: output.write(path,name)
    with zipfile.ZipFile(archive) as check:
        assert set(check.namelist()) == {row["path"] for row in rows}
        for row in rows:
            digest = hashlib.sha256()
            with check.open(row["path"]) as file:
                for block in iter(lambda:file.read(1024*1024),b""): digest.update(block)
            assert digest.hexdigest() == row["sha256"]
    return {"passed":True,"path":archive.name,"bytes":archive.stat().st_size,"sha256":sha(archive),"members":rows}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qa-run", type=Path, required=True)
    parser.add_argument("--godot")
    parser.add_argument("--profile-root", type=Path, help="Absolute short parent for a new, exclusive private profile")
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    profile_root = resolve_profile_root(args.profile_root)
    qa = args.qa_run.resolve()
    qa.relative_to((ROOT / ".godot/steam_integration_qa").resolve())
    proof = json.loads((qa / "receipt.json").read_text())
    if not proof.get("complete"): raise RuntimeError("A successful QA run is required")
    records = [row for row in proof["source_files"] if allowed(row["path"]) and row["path"] != DERIVED]
    missing_localization = LOCALIZATION - {row["path"] for row in records}
    if missing_localization:
        raise RuntimeError("The successful QA snapshot must include localization inputs: " + ", ".join(sorted(missing_localization)))
    if not any(row["path"] == "scripts/run_content_identity.gd" for row in records):
        raise RuntimeError("The successful QA snapshot must include the reviewed identity provider")
    for row in records:
        if sha(ROOT / row["path"]) != row["sha256"]:
            raise RuntimeError("Source changed since QA: " + row["path"])
    if not args.run:
        print(json.dumps({"preflight":True, "source_files":len(records), "godot":str(resolve_godot(args.godot)), "profile_root":str(profile_root) if profile_root else None}))
        return
    running = subprocess.check_output(["powershell.exe", "-NoProfile", "-Command", "@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'Godot*' } | ForEach-Object { $_.Id }) | ConvertTo-Json -Compress"], text=True).strip()
    if running and json.loads(running): raise RuntimeError("Godot engine slot occupied")
    run = ROOT / ".godot/steam_candidates" / (time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8])
    run.mkdir(parents=True)
    with LOCK.open("x", encoding="utf-8") as lock: lock.write(str(run))
    receipt = {"complete":False, "kind":"windows_steam_feature_candidate", "qa_run":str(qa.relative_to(ROOT)),
               "qa_receipt_sha256":sha(qa / "receipt.json"), "source_head":proof["source_head"],
               "builder_sha256":sha(Path(__file__)), "probe_sha256":sha(ROOT / "tools/steam_package_probe.gd"),
               "source_files":records, "steps":[], "uploaded":False, "live_steam_tested":False}
    child = None
    try:
        project = run / "project"
        for row in records:
            dest = project / row["path"]
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / row["path"], dest)
            if sha(dest) != row["sha256"]: raise RuntimeError("Source changed during copy")
        shutil.copytree(qa / "project/.godot/imported", project / ".godot/imported")
        install_native(project)
        receipt["native_provenance"] = json.loads((ROOT / "vendor/godotsteam/provenance.json").read_text())
        env = os.environ.copy()
        for key in list(env):
            if key.endswith(("_TEST", "_QA", "_AUDIT")) or key in {"LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "SCREENSHOT_DIR"}:
                env.pop(key)
        template = Path(os.environ["APPDATA"]) / "Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe"
        profile = create_private_profile(run, profile_root)
        receipt["private_profile"] = str(profile)
        for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
            private = profile / key.lower()
            private.mkdir()
            env[key] = str(private)
        target = Path(env["APPDATA"]) / "Godot/export_templates/4.6.3.stable/windows_release_x86_64.exe"
        target.parent.mkdir(parents=True)
        shutil.copyfile(template, target)
        receipt["template_sha256"] = sha(target)
        engine = str(resolve_godot(args.godot))
        receipt["godot_sha256"] = sha(Path(engine))
        catalog_sha256 = sha(project / "assets/localization/catalog.json")
        receipt["localization_catalog_sha256"] = catalog_sha256
        env.update(STEAM_DISABLED="1", CONTENT_UPDATE_NO_AUTO="1", STEAM_PACKAGE_REPORT=str(run / "package_report.json"),
                   LSH_QA_CATALOG_SHA=catalog_sha256)
        windows = run / "windows"
        windows.mkdir()
        exe = windows / "LiangshanHeroes.exe"
        receipt["identity_seed"] = seed(project)
        identity_generation = None
        commands = [
            ("import", [engine,"--headless","--path",str(project),"--editor","--import"]),
            ("export", [engine,"--headless","--path",str(project),"--export-release","Windows Steam",str(exe)]),
        ]
        for name, command in commands:
            print("RUN " + name + " " + str(run), flush=True)
            started = time.time()
            with (run / (name + ".log")).open("wb") as log:
                child = subprocess.Popen(command, cwd=windows, env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
                try: code = child.wait(timeout=600)
                except BaseException:
                    child.kill(); child.wait(timeout=30); raise
            text = (run / (name + ".log")).read_text(encoding="utf-8", errors="replace")
            receipt["steps"].append({"name":name,"exit_code":code,"seconds":round(time.time()-started,2)})
            errors = [line for line in text.splitlines() if any(word in line for word in ["SCRIPT ERROR", "ERROR:", "Parse Error"])]
            if code or errors: raise RuntimeError(name + " failed: " + "\n".join(errors))
            if name == "import":
                identity_generation = generate(project)
                with (run / "content_identity_generation.json").open("x", encoding="utf-8") as output:
                    output.write(json.dumps(identity_generation, indent=2) + "\n")
                receipt["content_identity"] = identity_generation
            else:
                verify_generated(project, identity_generation)
        verification = verify(run, windows, Path(engine), env)
        receipt["steps"].extend(verification["steps"])
        receipt["verification"] = verification
        identity_util = identity_utilities()
        identity_source_guard = identity_util.load_helper(identity_util.GUARD, identity_util.GUARD_SHA, "identity_export_source_guard")
        real_user = Path(os.environ["APPDATA"]) / "Godot/app_userdata" / identity_source_guard.project_name(ROOT)
        identity_players_before = identity_util.tree(real_user)
        identity_sources_before = identity_source_guard.source_receipt(ROOT)
        identity_util.save(run / "identity_players_before.json", identity_players_before)
        identity_util.save(run / "identity_sources_before.json", identity_sources_before)
        def identity_guard():
            if LOCK.read_text(encoding="utf-8") != str(run): raise RuntimeError("Identity probe lost builder lock")
            if identity_util.tree(real_user) != identity_players_before: raise RuntimeError("Real player profile changed")
            if identity_source_guard.source_receipt(ROOT) != identity_sources_before: raise RuntimeError("Production source changed")
            for row in records:
                if sha(ROOT / row["path"]) != row["sha256"]: raise RuntimeError("Production source changed before identity probe")
            verify_generated(project, identity_generation)
        for probe_stage, probe_pack in [("source_identity_probe", None), ("content_identity_probe", exe)]:
            receipt["identity_probe_exit_unconfirmed"] = True
            try:
                receipt[probe_stage] = probe_content_identity(project, probe_pack, Path(engine), run / probe_stage, env, identity_generation["identity"], identity_guard)
            finally:
                process_path = run / probe_stage / "process_receipt.json"
                if process_path.is_file():
                    process = json.loads(process_path.read_text(encoding="utf-8"))
                    receipt["identity_probe_exit_unconfirmed"] = process["child_started"] and not process["child_exit_confirmed"]
        identity_guard()
        identity_util.save(run / "identity_players_after.json", identity_util.tree(real_user))
        identity_util.save(run / "identity_sources_after.json", identity_source_guard.source_receipt(ROOT))
        for expected in ["steam_api64.dll", "libgodotsteam.windows.template_release.x86_64.dll"]:
            found = list(windows.rglob(expected))
            if len(found) != 1 or sha(found[0]) != sha(ROOT / "vendor/godotsteam/win64" / expected):
                raise RuntimeError("Native export dependency missing or changed: " + expected)
        receipt["outputs"] = [{"path":p.relative_to(windows).as_posix(),"bytes":p.stat().st_size,"sha256":sha(p)} for p in sorted(windows.rglob("*")) if p.is_file()]
        for row in records:
            if sha(ROOT / row["path"]) != row["sha256"]: raise RuntimeError("Source changed during export")
            if not row["path"].endswith(".import") and sha(project / row["path"]) != row["sha256"]:
                raise RuntimeError("Exporter changed production source: " + row["path"])
        receipt["checks"] = verification["checks"]
        receipt["archive"] = package_archive(run, windows)
        receipt["complete"] = True
    finally:
        if child is not None and child.poll() is None: child.kill(); child.wait(timeout=30)
        (run / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
        if not receipt.get("identity_probe_exit_unconfirmed", False) and LOCK.read_text(encoding="utf-8") == str(run): LOCK.unlink()
        print(json.dumps({"complete":receipt["complete"],"run":str(run),"checks":receipt.get("checks",0)}), flush=True)

if __name__ == "__main__": main()
