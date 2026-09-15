"""Freeze installed art inputs and run one or two character QA cases serially.

Preparation/preflight is read-only unless --run is explicitly supplied. All run
files live under --work-root, outside the checkout. Reuses the repository's
source enumerator, shared Godot lock, executable resolver and private-profile
helpers. Never packages, publishes, modifies Git, edits bitmaps or controls other applications.

Example:
  py -3 -X utf8 -B run_character_art_qa.py --repo <checkout> \
    --work-root <external-qa-root> \
    --manifest sun_li=assets/direction4/<final-sun-manifest>.json \
    --manifest hu_sanniang=assets/direction4/<final-hu-manifest>.json --run
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
CHARACTERS = ("sun_li", "hu_sanniang", "guan_zhanzi")
QA_DEST = "tools/art_character_direction4_qa.gd"
HERE = Path(__file__).resolve().parent
ERROR_LINES = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:).*$")
TOOLS = (
    "tools/zhujiazhuang_rts_test.gd",
    "tools/skirmish_direction4_contract_test.gd",
    "tools/character_direction4_inventory.gd",
    "tools/run_steam_integration_qa.py",
    "tools/run_campaign_level_state_qa.py",
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_helpers(repo: Path):
    tool_root = repo / "tools"
    sys.path.insert(0, str(tool_root))
    # Import the actual repository helpers, not unrelated modules on PYTHONPATH.
    for name in ("run_steam_integration_qa", "run_campaign_level_state_qa"):
        module_path = tool_root / (name + ".py")
        spec = importlib.util.spec_from_file_location(name, module_path)
        if spec is None or spec.loader is None:
            raise RuntimeError("Cannot load helper: " + str(module_path))
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
    shared = sys.modules["run_steam_integration_qa"]
    level = sys.modules["run_campaign_level_state_qa"]
    if shared.ROOT.resolve() != repo or level.ROOT.resolve() != repo:
        raise RuntimeError("Repository helper resolved a different checkout")
    return shared, level.running_engine


def relative_source(repo: Path, raw: str) -> str:
    raw = raw.removeprefix("res://")
    value = Path(raw)
    path = value.resolve() if value.is_absolute() else (repo / value).resolve()
    if not path.is_relative_to(repo) or not path.is_file():
        raise ValueError("Source must be an existing file inside checkout: " + raw)
    if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != repo):
        raise ValueError("Source links are not accepted: " + raw)
    relative = path.relative_to(repo).as_posix()
    if relative.startswith((".git/", ".godot/")):
        raise ValueError("Cache/Git path is not a production source: " + raw)
    return relative


def parse_cases(repo: Path, entries: list[str]):
    cases = []
    seen = set()
    for entry in entries:
        if "=" not in entry:
            raise ValueError("--manifest must be character=path")
        character, raw = entry.split("=", 1)
        if character not in CHARACTERS or character in seen:
            raise ValueError("Unsupported or duplicated character: " + character)
        seen.add(character)
        relative = relative_source(repo, raw)
        if not relative.startswith("assets/direction4/") or not relative.endswith(".json"):
            raise ValueError("Character manifest must reside in assets/direction4")
        manifest = json.loads((repo / relative).read_text(encoding="utf-8-sig"))
        if manifest.get("character") != character:
            raise ValueError("Character/manifest identity mismatch")
        if not all(isinstance(manifest.get(k), dict) for k in ("states", "poses", "sources")):
            raise ValueError("Incomplete SpriteFrames manifest")
        expected = {
            f"assets/anim/{character}_{state}_{direction}.tres"
            for state in ("idle", "walk", "attack", "hurt", "death")
            for direction in ("se", "sw", "ne", "nw")
        }
        declared = {relative_source(repo, p) for p in manifest.get("resources", [])}
        if declared != expected:
            raise ValueError("Manifest must declare the selected character's exact 20 five-state TRES")
        dependencies = {relative} | declared
        for item in manifest["sources"].values():
            native = relative_source(repo, item["path"])
            if not native.startswith("assets/characters/") or not native.endswith(".png"):
                raise ValueError("Native character PNG must be in assets/characters")
            if sha(repo / native) != item.get("sha256"):
                raise ValueError("Native source differs from manifest: " + native)
            dependencies.add(native)
            # Import descriptors are production identity inputs even when a new
            # descriptor is ignored until the root explicitly stages it.
            dependencies.add(relative_source(repo, native + ".import"))
        for name in declared:
            if (repo / name).with_suffix(".png").exists() and character != "guan_zhanzi":
                raise ValueError("An exact PNG would shadow authored TRES: " + name)
        cases.append({"character": character, "manifest": relative,
                      "manifest_sha256": sha(repo / relative),
                      "dependencies": sorted(dependencies)})
    if not cases:
        raise ValueError("At least one character manifest is required")
    return cases


def private_environment(profile: Path) -> dict[str, str]:
    env = os.environ.copy()
    prefixes = ("LSH_", "RTS_", "KH_", "HNS_", "HNA_", "DAMING_", "MENGZHOU_",
                "SIEGE_", "ART_", "LC_", "SJ_", "SL_", "DIRECTION4_", "ZHU_",
                "DEF_", "STEAM_QA_", "CAMPAIGN_QA_", "PLAYTEST_")
    exact = {"LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI",
             "ARENA", "AUTO_MICRO", "AUTOMICRO", "AI_FRIENDLY", "AI_DIFF",
             "VICTORY", "SCALE_ON", "ENEMY_MULT", "HERO_MULT", "SCALE_LOCKED"}
    for key in list(env):
        if key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key.startswith(prefixes) or key in exact:
            env.pop(key)
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        target = profile / key.lower()
        target.mkdir(exist_ok=False)
        env[key] = str(target)
    env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", LSH_LANGUAGE="zh_CN",
               ART_QA_PROFILE=str(profile))
    return env


def source_changes(base: Path, rows: list[dict]) -> list[str]:
    changed = []
    for row in rows:
        path = base / row["path"]
        if not path.is_file() or sha(path) != row["sha256"]:
            changed.append(row["path"])
    return changed


def process_step(engine: Path, project: Path, env: dict, evidence: Path,
                 label: str, args: list[str], timeout: float, renderer: str,
                 running_engine, steps: list[dict]):
    # Unrelated applications are neither queried nor controlled here.
    if running_engine():
        raise RuntimeError("Godot/Liangshan engine appeared before step " + label)
    log_path = evidence / (label + ".log")
    command = [str(engine), "--path", str(project), "--rendering-method", renderer] + args
    print("RUN " + label, flush=True)
    started = time.monotonic()
    child = None
    stop_reason = None
    row = {"case": label, "command": command, "passed": False, "errors": []}
    try:
        with log_path.open("wb") as log:
            child = subprocess.Popen(command, cwd=project, env=env, stdout=log,
                                     stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            row["pid"] = child.pid
            last_update = started
            while child.poll() is None:
                time.sleep(0.5)
                current = log_path.read_text(encoding="utf-8", errors="replace")
                found = ERROR_LINES.findall(current)
                if found:
                    stop_reason = "script_or_engine_error"
                    break
                if time.monotonic() - started > timeout:
                    stop_reason = "timeout"
                    break
                if time.monotonic() - last_update >= 25:
                    print("RUNNING " + label + " " + str(round(time.monotonic() - started)) + "s", flush=True)
                    last_update = time.monotonic()
            if stop_reason and child.poll() is None:
                # Only terminate the exact private child created in this call;
                # never enumerate and stop unrelated game processes.
                child.terminate()
                try:
                    child.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=15)
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=15)
        output = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        errors = ERROR_LINES.findall(output)
        row.update(exit_code=child.returncode if child is not None else None,
                   seconds=round(time.monotonic() - started, 3),
                   stopped_for=stop_reason, errors=errors[:30],
                   log_sha256=sha(log_path) if log_path.exists() else None)
        row["passed"] = row["exit_code"] == 0 and not errors and stop_reason is None
        steps.append(row)
        print("DONE " + label + " " + str(row["passed"]), flush=True)
    if not row["passed"]:
        raise RuntimeError("Private character QA step failed: " + label)


def verify_character_report(case: dict, directory: Path, visual: bool):
    report_path = directory / "report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("passed") is not True or report.get("failures") or int(report.get("checks", 0)) <= 0:
        raise RuntimeError("Character behavioral report did not pass")
    if report.get("character") != case["character"] or report.get("manifest") != "res://" + case["manifest"]:
        raise RuntimeError("Report character/manifest differs from selected case")
    resources = report.get("resources", [])
    pairs = {(r.get("state"), r.get("direction")) for r in resources}
    if pairs != {(s, d) for s in ("idle", "walk", "attack", "hurt", "death") for d in ("se", "sw", "ne", "nw")}:
        raise RuntimeError("Report omitted an authored state or direction")
    moves = {r.get("direction") for r in report.get("runtime", []) if r.get("case") == "melee" and r.get("damage", 0) > 0}
    if moves != {"se", "sw", "ne", "nw"}:
        raise RuntimeError("Report omitted actual melee damage in a direction")
    before, after = report.get("identity_before", {}), report.get("identity_after", {})
    if before.get("ok") is not True or after.get("ok") is not True or before.get("source_sha256") != after.get("source_sha256") or before.get("file_count") != after.get("file_count"):
        raise RuntimeError("Runtime installed identity failed or changed")
    if report.get("engine_time_scale") != 1.0:
        raise RuntimeError("Character QA did not preserve normal simulation speed")
    if report.get("private_profile", {}).get("passed") is not True:
        raise RuntimeError("Native character private-profile guard did not pass")
    names = set()
    for image in report.get("screenshots", []):
        path = Path(image["path"]).resolve()
        if not path.is_relative_to(directory.resolve()) or not path.is_file() or sha(path) != image["sha256"]:
            raise RuntimeError("Screenshot path or SHA mismatch")
        names.add(image["name"])
    if visual:
        expected = {f"{kind}_{d}" for kind in ("walk", "melee", "hurt", "fall", "terminal") for d in ("se", "sw", "ne", "nw")}
        if case["character"] == "sun_li":
            expected |= {"sun_real_riders", "sun_actual_contact"}
        elif case["character"] == "hu_sanniang":
            expected |= {"hu_captured_" + d for d in ("se", "sw", "ne", "nw")}
        else:
            expected |= {"codex_" + d for d in ("se", "sw", "ne", "nw")}
        if not expected <= names or not any(n.startswith("unit_pose_matrix_") for n in names):
            raise RuntimeError("Required actual character renders are missing")
    return {"character": case["character"], "checks": report["checks"],
            "report_sha256": sha(report_path), "screenshots": len(names),
            "identity": before}


def parser():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, required=True)
    ap.add_argument("--manifest", action="append", required=True,
                    help="Repeat character=path; supports only sun_li and hu_sanniang")
    ap.add_argument("--qa-script", type=Path, default=HERE / "art_character_direction4_qa.gd")
    ap.add_argument("--work-root", type=Path, required=True,
                    help="Absolute directory outside checkout for exclusive QA runs/profiles")
    ap.add_argument("--godot")
    ap.add_argument("--rendering-method", choices=("gl_compatibility", "forward_plus", "mobile"), default="gl_compatibility")
    ap.add_argument("--headless", action="store_true", help="Resource/behavior only; no render acceptance")
    ap.add_argument("--window-position", default="20000,20000",
                    help="Render window position; default keeps automatic screenshots away from the desktop")
    ap.add_argument("--cache-from", type=Path,
                    help="Prior private run; reuse imported resources with a recorded non-fresh import")
    ap.add_argument("--shared-checks", action="store_true", help="After selected characters, run routing and current inventory once")
    ap.add_argument("--timeout", type=float, default=1000.0)
    ap.add_argument("--run", action="store_true")
    return ap


def main():
    args = parser().parse_args()
    repo = args.repo.resolve()
    shared, running_engine = load_helpers(repo)
    engine = shared.resolve_godot(args.godot)
    work_root = shared.resolve_profile_root(args.work_root)
    if work_root is None or work_root.resolve().is_relative_to(repo):
        raise ValueError("--work-root must be outside the checkout")
    if args.timeout <= 0 or args.timeout > 3600:
        raise ValueError("--timeout must be positive and at most one hour")
    if not re.fullmatch(r"-?\d{1,5},-?\d{1,5}", args.window_position):
        raise ValueError("--window-position must be X,Y integer coordinates")
    qa_source = args.qa_script.resolve()
    if not qa_source.is_file():
        raise ValueError("Candidate QA script is missing")
    cases = parse_cases(repo, args.manifest)
    runtime_inventory = shared.sources()
    required = set(runtime_inventory) | set(TOOLS)
    # New texture descriptors can be Git-ignored until final staging. Freeze
    # each existing descriptor beside a production input even when only one
    # of the two characters is selected for this run.
    for name in runtime_inventory:
        descriptor = name + ".import"
        if (repo / descriptor).is_file():
            required.add(relative_source(repo, descriptor))
    for case in cases:
        required.update(case["dependencies"])
    if (repo / "tools/.gdignore").is_file():
        required.add("tools/.gdignore")
    # The root owns the external QA candidate. Do not accidentally freeze a
    # different repository file under the same destination name.
    required.discard(QA_DEST)
    names = sorted(required)
    for name in names:
        relative_source(repo, name)
    if not args.run:
        print(json.dumps({"preflight": True, "characters": [c["character"] for c in cases],
                          "source_files": len(names), "lock_busy": shared.LOCK.exists(),
                          "engine_busy": running_engine(), "godot": str(engine),
                          "work_root": str(work_root), "visual": not args.headless,
                          "shared_checks": args.shared_checks, "qa_sha256": sha(qa_source)}, ensure_ascii=False))
        return 0
    if running_engine():
        raise RuntimeError("Godot/Liangshan engine slot is occupied")
    if shared.LOCK.exists():
        raise RuntimeError("Shared QA lock is occupied; do not remove another task's lock")
    if not shared.LOCK.parent.is_dir():
        raise RuntimeError("Existing shared lock directory is missing; root must initialize its QA workspace")
    tag = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / tag
    project, evidence = run / "project", run / "evidence"
    receipt = {"complete": False, "run": str(run), "project": str(project),
               "source_root": str(repo), "selected_cases": cases, "steps": [],
               "fresh_import": args.cache_from is None, "visual": not args.headless,
               "renderer": args.rendering_method, "source_files": [],
               "qa_sha256": sha(qa_source), "driver_sha256": sha(Path(__file__)),
               "godot_sha256": sha(engine), "scope": "Character art integration only; no save/restore, Steam, balance, long-run or other application operations."}
    locked = False
    failure = None
    try:
        with shared.LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        if running_engine():
            raise RuntimeError("Engine started before lock acquisition completed")
        project.mkdir(parents=True, exist_ok=False)
        evidence.mkdir(parents=True, exist_ok=False)
        for name in names:
            src, dest = repo / name, project / name
            data = src.read_bytes()
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            digest = hashlib.sha256(data).hexdigest()
            if sha(src) != digest or sha(dest) != digest:
                raise RuntimeError("Source changed during freeze: " + name)
            receipt["source_files"].append({"path": name, "sha256": digest, "bytes": len(data)})
        qa_dest = project / QA_DEST
        qa_dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(qa_source, qa_dest)
        if sha(qa_dest) != receipt["qa_sha256"]:
            raise RuntimeError("QA candidate changed during freeze")
        harness = evidence / "harness"
        harness.mkdir()
        shutil.copyfile(qa_source, harness / qa_source.name)
        shutil.copyfile(Path(__file__), harness / Path(__file__).name)
        profile = shared.create_private_profile(run, work_root / "profiles")
        env = private_environment(profile)
        receipt["private_profile"] = str(profile)
        receipt["private_environment"] = {k: env[k] for k in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP")}
        receipt["source_changes_before_import"] = source_changes(repo, receipt["source_files"])
        if receipt["source_changes_before_import"] or shared.sources() != runtime_inventory:
            raise RuntimeError("Production inputs changed before import")
        if any(sha(project / case["manifest"]) != case["manifest_sha256"] for case in cases):
            raise RuntimeError("Selected manifest changed between dependency parsing and freeze")
        if args.cache_from is not None:
            prior = shared.resolve_profile_root(args.cache_from.resolve())
            if prior is None or prior.is_relative_to(repo) or prior == run:
                raise ValueError("Cache source must be a prior private run outside checkout")
            prior_receipt = json.loads((prior / "evidence/receipt.json").read_text(encoding="utf-8"))
            if not any(step.get("case") == "import" and step.get("passed") is True
                       for step in prior_receipt.get("steps", [])):
                raise ValueError("Cache source has no successful import step")
            if prior_receipt.get("source_root") != str(repo) or prior_receipt.get("godot_sha256") != receipt["godot_sha256"]:
                raise ValueError("Cache source checkout or engine differs")
            imported = prior / "project/.godot/imported"
            if not imported.is_dir():
                raise ValueError("Prior imported resource directory is missing")
            shutil.copytree(imported, project / ".godot/imported")
            receipt["import_cache"] = {
                "prior_run": str(prior),
                "prior_receipt_sha256": sha(prior / "evidence/receipt.json"),
                "scope": "Imported resources only; source files, script-class cache and player profile are fresh."
            }
        process_step(engine, project, env, evidence, "import",
                     ["--headless", "--editor", "--import", "--quit"], args.timeout,
                     args.rendering_method, running_engine, receipt["steps"])
        if source_changes(project, receipt["source_files"]):
            raise RuntimeError("Fresh import changed frozen production bytes; inspect private import descriptors before retrying")
        receipt["character_results"] = []
        for case in cases:
            directory = evidence / case["character"]
            directory.mkdir()
            case_env = env | {"ART_CHARACTER": case["character"],
                              "ART_MANIFEST": "res://" + case["manifest"],
                              "ART_QA_OUT": str(directory), "ART_VISUAL": "0" if args.headless else "1"}
            process_step(engine, project, case_env, evidence, case["character"],
                         (["--headless"] if args.headless else ["--position", args.window_position]) + ["--script", "res://" + QA_DEST],
                         args.timeout, args.rendering_method, running_engine, receipt["steps"])
            receipt["character_results"].append(verify_character_report(case, directory, not args.headless))
        if args.shared_checks:
            for label, script, out_key in (
                ("routing", "skirmish_direction4_contract_test.gd", "DIRECTION4_CONTRACT_OUT"),
                ("inventory", "character_direction4_inventory.gd", "DIRECTION4_INVENTORY_OUT"),
            ):
                directory = evidence / label
                directory.mkdir()
                process_step(engine, project, env | {out_key: str(directory)}, evidence, label,
                             ["--headless", "--script", "res://tools/" + script],
                             args.timeout, args.rendering_method, running_engine, receipt["steps"])
                expected = directory / ("report.json" if label == "routing" else "inventory.json")
                parsed = json.loads(expected.read_text(encoding="utf-8"))
                if label == "routing" and (parsed.get("passed") is not True or parsed.get("failures")):
                    raise RuntimeError("Shared art routing report did not pass")
                if label == "inventory" and not isinstance(parsed.get("units"), list):
                    raise RuntimeError("Current character inventory is missing")
        receipt["source_changes"] = source_changes(repo, receipt["source_files"])
        receipt["private_source_changes"] = source_changes(project, receipt["source_files"])
        receipt["runtime_inventory_unchanged"] = shared.sources() == runtime_inventory
        receipt["qa_unchanged"] = sha(qa_source) == receipt["qa_sha256"] == sha(qa_dest)
        receipt["driver_unchanged"] = sha(Path(__file__)) == receipt["driver_sha256"]
        receipt["godot_unchanged"] = sha(engine) == receipt["godot_sha256"]
        if receipt["source_changes"] or receipt["private_source_changes"] or not all(receipt[k] for k in ("runtime_inventory_unchanged", "qa_unchanged", "driver_unchanged", "godot_unchanged")):
            raise RuntimeError("Input identities changed during character QA")
        receipt["complete"] = True
    except BaseException as exc:
        failure = exc
        receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        if locked:
            # Preserve the source identity comparison even on a failed step.
            receipt["source_changes"] = source_changes(repo, receipt["source_files"])
            receipt["private_source_changes"] = source_changes(project, receipt["source_files"])
            engine_busy = running_engine()
            receipt["engines_remaining"] = engine_busy
            if shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == str(run) and not engine_busy:
                shared.LOCK.unlink()
            receipt["lock_released"] = not shared.LOCK.exists()
            receipt["complete"] = receipt["complete"] and receipt["lock_released"] and not receipt["source_changes"] and not receipt["private_source_changes"]
        if evidence.exists():
            receipt["artifacts"] = [{"path": p.relative_to(evidence).as_posix(), "sha256": sha(p), "bytes": p.stat().st_size}
                                    for p in sorted(evidence.rglob("*")) if p.is_file() and p.name != "receipt.json"]
            (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "evidence": str(evidence),
                          "checks": sum(r["checks"] for r in receipt.get("character_results", [])),
                          "failure": receipt.get("failure")}, ensure_ascii=False), flush=True)
    if failure is not None:
        return 1
    return 0 if receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
