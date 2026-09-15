"""Run one external recovery probe against a completed Steam candidate's embedded PCK.

Reuses the reviewed editor/DLL probe host, shared lock, process safety and fresh
private-profile helpers. --run is mandatory for execution; no export or upload.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
CHARACTERS = {"song_jiang", "lin_chong", "sun_li", "hu_sanniang"}
HELPERS = ("tools/run_character_art_qa.py", "tools/run_steam_integration_qa.py", "tools/run_campaign_level_state_qa.py")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def need(ok, message):
    if not ok:
        raise RuntimeError(message)


def verify_report(path, step, pack, digest, profile):
    report = json.loads(path.read_text(encoding="utf-8"))
    need(report.get("schema") == "recovery_pck_probe_v1" and report.get("complete") is True and report.get("passed") is True and report.get("failures") == [], "Pack report failed/incomplete")
    need(type(report.get("pid")) is int and report["pid"] == step["pid"] and Path(report["pack"]).resolve() == pack.resolve() and report.get("pack_sha256") == digest, "Report not bound to this process/package")
    proof = report.get("private_profile", {})
    need(proof.get("passed") is True and Path(proof["profile"]).resolve() == profile.resolve(), "Private profile witness mismatch")
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        need(Path(proof["environment"][key]).resolve() == (profile / key.lower()).resolve(), "Private environment mismatch")
    need(Path(proof["user_data_dir"]).resolve().is_relative_to((profile / "appdata").resolve()), "User data escaped private profile")
    checks = report.get("checks", [])
    need(checks and all(row.get("passed") is True and row.get("label") for row in checks), "Missing/failed check rows")
    languages = report.get("languages", [])
    need(len(languages) == 4 and {row.get("locale") for row in languages} == {"zh_CN", "zh_TW", "en", "ja"}, "Four language witnesses required")
    need(all(row.get("text") and row.get("barracks") and row.get("camp") for row in languages), "Empty localized UI")
    need(len(checks) >= 25, "Recovery pack checks incomplete")
    return {"checks": len(checks), "languages": 4, "report_sha256": sha(path), "pid": report["pid"]}



def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--candidate-run", type=Path, required=True)
    parser.add_argument("--work-root", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    repo = args.repo.resolve()
    spec = importlib.util.spec_from_file_location("art_pack_safety", repo / HELPERS[0])
    art = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(art)
    shared, running_engine = art.load_helpers(repo)
    candidate = shared.resolve_profile_root(args.candidate_run)
    work_root = shared.resolve_profile_root(args.work_root)
    need(candidate is not None and work_root is not None and not work_root.resolve().is_relative_to(repo), "Explicit candidate and external work root required")
    need(0 < args.timeout <= 600, "Invalid probe timeout")
    candidate_receipt = candidate / "receipt.json"
    original = json.loads(candidate_receipt.read_text(encoding="utf-8"))
    verification_path = candidate / "verification_report.json"
    verification = json.loads(verification_path.read_text(encoding="utf-8"))
    need(original.get("complete") is True and original.get("kind") == "windows_steam_feature_candidate" and verification.get("complete") is True, "Finished verified Steam candidate required")
    pack = candidate / "windows/LiangshanHeroes.exe"
    engine = candidate / "probe_host/Godot.exe"
    expected_pack = [row for row in original.get("outputs", []) if row.get("path") == "LiangshanHeroes.exe"]
    need(len(expected_pack) == 1 and pack.is_file() and sha(pack) == expected_pack[0]["sha256"] and pack.stat().st_size == expected_pack[0]["bytes"], "Candidate embedded PCK/EXE identity differs")
    need(engine.is_file() and sha(engine) == verification.get("editor_sha256"), "Reviewed editor probe host changed")
    guards = {str(candidate_receipt): sha(candidate_receipt), str(verification_path): sha(verification_path), str(pack): sha(pack), str(engine): sha(engine)}
    for manifest in shared.native_dependencies().values():
        for row in manifest["files"]:
            if not row["path"].endswith(".dll"):
                continue
            host = candidate / "probe_host" / Path(row["path"]).name
            need(host.is_file() and sha(host) == row["sha256"], "Native dependency in probe host changed")
            guards[str(host)] = row["sha256"]
    probe = HERE / "recovery_pack_probe.gd"
    for path in [probe, Path(__file__), *(repo / name for name in HELPERS)]:
        guards[str(path)] = sha(path)
    if not args.run:
        print(json.dumps({"preflight": True, "candidate": str(candidate), "pack_sha256": guards[str(pack)], "lock_busy": shared.LOCK.exists(), "engine_busy": running_engine(), "work_root": str(work_root)}, ensure_ascii=False))
        return 0
    need(not shared.LOCK.exists() and not running_engine(), "Shared Godot slot occupied; no unrelated engine will be stopped")
    need(shared.LOCK.parent.is_dir(), "Shared QA lock directory missing")
    tag = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / tag
    receipt = {"schema": "recovery_pack_probe_runner_v1", "complete": False, "candidate_run": str(candidate), "pack": str(pack), "pack_sha256": guards[str(pack)], "guards_before": guards, "steps": [], "scope": "Editor-host exported-PCK recovery state/binding check only; not release EXE gameplay, live Steam, upload or publication."}
    locked = False
    try:
        need(not run.exists(), "New probe run already exists")
        with shared.LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        need(not running_engine(), "Engine appeared while acquiring lock")
        run.mkdir(parents=True, exist_ok=False)
        harness = run / "harness"
        harness.mkdir()
        for path in [probe, Path(__file__), *(repo / name for name in HELPERS)]:
            shutil.copyfile(path, harness / path.name)
        profile = shared.create_private_profile(run, work_root / "profiles")
        env = art.private_environment(profile)
        for key in list(env):
            if key.startswith("PCK_ART_"): env.pop(key)
        env.update(PCK_ART_PACK=str(pack), PCK_ART_PACK_SHA=guards[str(pack)], PCK_ART_REPORT=str(run / "report.json"))
        need(all(sha(path) == digest for path, digest in guards.items()), "Probe/package inputs changed before launch")
        receipt["private_profile"] = str(profile)
        arguments = ["--headless", "--main-pack", str(pack), "--script", str(harness / probe.name)]
        art.process_step(engine, pack.parent, env, run, "recovery_pck", arguments, args.timeout, "gl_compatibility", running_engine, receipt["steps"])
        receipt["result"] = verify_report(run / "report.json", receipt["steps"][-1], pack, guards[str(pack)], profile)
        receipt["complete"] = True
    except BaseException as exc:
        receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        if locked:
            receipt["guards_changed"] = [path for path, digest in guards.items() if not Path(path).is_file() or sha(path) != digest]
            busy = running_engine()
            receipt["engines_remaining"] = busy
            if shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == str(run) and not busy:
                shared.LOCK.unlink()
            receipt["lock_released"] = not shared.LOCK.exists()
            receipt["complete"] = receipt["complete"] and receipt["lock_released"] and not receipt["guards_changed"]
        if run.exists():
            receipt["artifacts"] = [{"path": p.relative_to(run).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)} for p in sorted(run.rglob("*")) if p.is_file() and p.name != "receipt.json" and not p.is_relative_to(run / "profile")]
            (run / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "run": str(run), "result": receipt.get("result"), "failure": receipt.get("failure")}, ensure_ascii=False), flush=True)
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
