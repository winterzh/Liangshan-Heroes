"""Freeze a private project and verify the real codex scene, serially.

No engine or filesystem changes without --run. All evidence/project/profile
outputs are outside --repo. --headless-only is a diagnostic, not visual acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import struct
import sys
import time
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
QA_DEST = "tools/codex_identity_qa.gd"
HELPERS = (
    "tools/run_character_art_qa.py",
    "tools/run_steam_integration_qa.py",
    "tools/run_campaign_level_state_qa.py",
)
CHARACTERS = ("song_jiang", "lin_chong", "sun_li", "hu_sanniang")
DIRECTIONS = ("se", "sw", "ne", "nw")
DIRECTION_NAMES = ("东南", "西南", "东北", "西北")
MANIFESTS = {key: f"assets/direction4/{key}_{'20260906' if key in CHARACTERS[:2] else '20260913'}.json" for key in CHARACTERS}
EXPECTED_PNGS = {
    "song_jiang_se": ("song_jiang", "se", "zh_CN"),
    "lin_chong_sw": ("lin_chong", "sw", "zh_CN"),
    "hu_sanniang_nw": ("hu_sanniang", "nw", "zh_CN"),
    **{f"sun_li_{direction}": ("sun_li", direction, "zh_CN") for direction in DIRECTIONS},
    "legacy_an_daoquan": ("an_daoquan", "sw", "zh_CN"),
    "legacy_arrow_tower": ("arrow_tower", "sw", "zh_CN"),
    **{f"locale_{locale}": ("hu_sanniang", "nw", locale) for locale in ("en", "ja", "zh_TW")},
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def load_art_helper(repo: Path):
    path = repo / HELPERS[0]
    spec = importlib.util.spec_from_file_location("codex_art_qa_helpers", path)
    require(spec is not None and spec.loader is not None, "Art QA helper unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def safe_source(root: Path, value: str) -> Path:
    require(isinstance(value, str), "Non-string source path")
    value = value.removeprefix("res://")
    parts = value.split("/")
    require(value and "\\" not in value and not Path(value).is_absolute() and all(p not in ("", ".", "..") for p in parts), "Invalid source path")
    path = root / value
    require(path.is_file() and path.resolve().is_relative_to(root.resolve()), "Source missing/outside project: " + value)
    return path


def collect_sources(repo, shared, art):
    runtime = shared.sources()
    production = set(runtime)
    for name in runtime:
        if (repo / (name + ".import")).is_file():
            production.add(art.relative_source(repo, name + ".import"))
    names = production | set(HELPERS)
    if (repo / "tools/.gdignore").is_file():
        names.add("tools/.gdignore")
    names.discard(QA_DEST)
    for name in names:
        art.relative_source(repo, name)
    for key, manifest in MANIFESTS.items():
        require(manifest in production, "Current runtime inventory misses manifest: " + key)
        parsed = json.loads((repo / manifest).read_text(encoding="utf-8-sig"))
        require(parsed.get("character") == key, "Manifest character mismatch: " + key)
        for source in parsed["sources"].values():
            source_name = source["path"].removeprefix("res://")
            require(source_name in production and source_name + ".import" in production, "Native source/import descriptor missing: " + source_name)
        for direction in DIRECTIONS:
            for state in ("idle", "walk", "attack"):
                name = f"assets/anim/{key}_{state}_{direction}.tres"
                require(name in production, "Authored resource missing: " + name)
    return runtime, sorted(production), sorted(names)


def verify_report(directory: Path, project: Path, repo: Path, profile: Path, visual: bool, step: dict):
    path = directory / "report.json"
    report = json.loads(path.read_text(encoding="utf-8"))
    require(report.get("schema") == "codex_identity_qa_v1" and report.get("complete") is True and report.get("passed") is True, "Codex report incomplete/failed")
    require(report.get("visual") is visual and type(report.get("pid")) is int and report["pid"] == step["pid"], "Report mode/process mismatch")
    checks = report.get("checks")
    require(isinstance(checks, list) and checks and type(report.get("count")) is int and report["count"] == len(checks), "Missing/mismatched check count")
    require(report.get("failures") == [] and all(isinstance(row, dict) and row.get("passed") is True and isinstance(row.get("label"), str) and row["label"] for row in checks), "Failed/empty check row")
    proof = report.get("private_profile", {})
    require(proof.get("passed") is True and Path(proof["profile"]).resolve() == profile.resolve() and Path(proof["project"]).resolve() == project.resolve() and Path(proof["source_root"]).resolve() == repo.resolve(), "Report private boundary mismatch")
    for key in ("APPDATA", "LOCALAPPDATA", "TEMP", "TMP"):
        require(Path(proof["environment"][key]).resolve() == (profile / key.lower()).resolve(), "Report environment mismatch")
    require(Path(proof["user_data_dir"]).resolve().is_relative_to((profile / "appdata").resolve()), "Report user path outside profile")
    before, after = report.get("identity_before"), report.get("identity_after")
    require(isinstance(before, dict) and before == after, "Report source identity changed")
    required_identity = {"res://scripts/codex.gd", "res://scripts/art_db.gd", "res://scenes/codex.tscn", "res://assets/localization/catalog.json"}
    required_identity.update("res://" + path for path in MANIFESTS.values())
    required_identity.update(f"res://assets/anim/{key}_{state}_{direction}.tres" for key in CHARACTERS for state in ("idle", "walk", "attack") for direction in DIRECTIONS)
    require(required_identity <= before.keys(), "Report omits expected source identities")
    for relative, digest in before.items():
        require(sha(safe_source(project, relative)) == digest, "Reported source differs from frozen project: " + relative)
    expected_routes = {(key, direction, state) for key in CHARACTERS for direction in DIRECTIONS for state in ("walk", "attack")}
    seen = set()
    layouts = report.get("layouts")
    require(isinstance(layouts, list) and layouts, "Missing actual draw layouts")
    for row in report.get("routes", []):
        token = (row.get("character"), row.get("direction"), row.get("state"))
        require(token in expected_routes and token not in seen, "Missing/duplicate/foreign codex route")
        seen.add(token)
        key, direction, state = token
        resource = f"res://assets/anim/{key}_{state}_{direction}.tres"
        require(row.get("resource") == resource and row.get("resource_sha256") == sha(safe_source(project, resource)), "Route resource does not match frozen TRES")
        manifest = json.loads((project / MANIFESTS[key]).read_text(encoding="utf-8-sig"))
        displayed = row.get("displayed")
        require(isinstance(displayed, list) and len(displayed) == len(manifest["states"][state]) and displayed, "Route frame count mismatch")
        source_paths = {"res://" + s["path"].removeprefix("res://") for s in manifest["sources"].values()}
        require(all(isinstance(frame, dict) and frame.get("authored") is True and frame.get("atlas") in source_paths for frame in displayed), "Route frame borrows foreign/legacy art")
        label = f"{key}/{state}/{direction}"
        observed = [item for item in layouts if item.get("label") == label]
        require(len(observed) == len(displayed) and {item.get("index") for item in observed} == set(range(len(displayed))), "Per-frame geometry evidence incomplete")
        for item in observed:
            require(item.get("frame") == displayed[item["index"]], "Geometry refers to a different displayed frame")
    require(seen == expected_routes, "Not all 32 codex routes observed")
    languages = report.get("languages", [])
    require(len(languages) == 4 and {r.get("locale") for r in languages} == {"zh_CN", "en", "ja", "zh_TW"}, "Four-language set incomplete")
    catalog = json.loads((project / "assets/localization/catalog.json").read_text(encoding="utf-8-sig"))
    for row in languages:
        if row["locale"] != "zh_CN":
            require(all(isinstance(catalog.get(name), dict) and isinstance(catalog[name].get(row["locale"]), str) and catalog[name][row["locale"]] for name in DIRECTION_NAMES), "Direction translations missing from frozen catalog")
        expected_labels = [name if row["locale"] == "zh_CN" else catalog.get(name, {}).get(row["locale"], name) for name in DIRECTION_NAMES]
        require(row.get("name") and row.get("bio") and row.get("directions") == expected_labels, "Language witness does not match frozen localization catalog")
    captures = report.get("screenshots", [])
    require(len(captures) == (12 if visual else 0), "Native screenshot count mismatch")
    seen_pngs = set()
    for row in captures:
        label = row.get("label")
        require(label in EXPECTED_PNGS and label not in seen_pngs, "Unexpected/duplicate screenshot")
        seen_pngs.add(label)
        png = Path(row["path"])
        require(png.is_absolute() and png.resolve() == (directory / (label + ".png")).resolve(), "Screenshot outside exact output location")
        require((row.get("character"), row.get("direction"), row.get("locale")) == EXPECTED_PNGS[label], "Screenshot UI identity mismatch")
        data = png.read_bytes()
        require(data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR" and len(data) >= 24, "Invalid PNG")
        dimensions = list(struct.unpack(">II", data[16:24]))
        require(dimensions == [1280, 720] == row.get("size") and sha(png) == row.get("sha256"), "Screenshot dimensions/SHA mismatch")
    require({p.name for p in directory.glob("*.png")} == {name + ".png" for name in seen_pngs}, "Unreported native screenshot")
    return {"mode": "visual" if visual else "headless", "checks": len(checks), "routes": len(seen), "locales": 4, "screenshots": len(captures), "report_sha256": sha(path), "pid": report["pid"], "passed": True}


def parser():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", required=True, type=Path)
    ap.add_argument("--work-root", required=True, type=Path)
    ap.add_argument("--qa-script", type=Path, default=HERE / "codex_identity_qa.gd")
    ap.add_argument("--godot")
    ap.add_argument("--headless-only", action="store_true")
    ap.add_argument("--cache-from", type=Path, help="Explicit prior private run; imported resources only, recorded non-fresh")
    ap.add_argument("--timeout", type=float, default=180.0)
    ap.add_argument("--import-timeout", type=float, default=1000.0)
    ap.add_argument("--window-position", default="20000,20000")
    ap.add_argument("--run", action="store_true")
    return ap


def main():
    args = parser().parse_args()
    repo = args.repo.resolve()
    loaded_helpers = {name: sha(repo / name) for name in HELPERS}
    art = load_art_helper(repo)
    shared, running_engine = art.load_helpers(repo)
    engine = shared.resolve_godot(args.godot)
    work_root = shared.resolve_profile_root(args.work_root)
    require(work_root is not None and not work_root.resolve().is_relative_to(repo), "--work-root must be absolute and outside checkout")
    require(0 < args.timeout <= 600 and 0 < args.import_timeout <= 3600, "Invalid bounded timeouts")
    require(re.fullmatch(r"-?\d{1,5},-?\d{1,5}", args.window_position), "Invalid window coordinates")
    qa_source = args.qa_script.resolve()
    require(qa_source.is_file() and not qa_source.is_symlink(), "QA candidate missing/linked")
    runtime, production, names = collect_sources(repo, shared, art)
    if not args.run:
        print(json.dumps({"preflight": True, "runtime_files": len(runtime), "production_with_imports": len(production), "frozen_source_files": len(names), "godot": str(engine), "lock_busy": shared.LOCK.exists(), "engine_busy": running_engine(), "work_root": str(work_root), "headless_only": args.headless_only, "fresh_import": args.cache_from is None, "qa_sha256": sha(qa_source)}, ensure_ascii=False))
        return 0
    require(not running_engine() and not shared.LOCK.exists(), "Shared Godot slot/lock occupied; no other process will be stopped")
    require(shared.LOCK.parent.is_dir(), "Existing shared lock directory missing")
    tag = time.strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:8]
    run = work_root / tag
    require(not run.exists(), "New run directory already exists")
    project, evidence = run / "project", run / "evidence"
    receipt = {"schema": "codex_identity_runner_v1", "complete": False, "visual_acceptance_complete": False, "run": str(run), "project": str(project), "source_root": str(repo), "fresh_import": args.cache_from is None, "headless_only": args.headless_only, "renderer": "gl_compatibility", "runtime_inventory": runtime, "production_inventory": production, "source_files": [], "steps": [], "results": [], "profiles": {}, "qa_sha256": sha(qa_source), "driver_sha256": sha(Path(__file__)), "helper_sha256": loaded_helpers, "godot_sha256": sha(engine), "scope": "Codex identity/direction/layout only. Headless does not provide visual acceptance. No battle/save/Steam/global suite."}
    locked = False
    failure = None
    qa_dest = project / QA_DEST
    try:
        with shared.LOCK.open("x", encoding="utf-8") as lock:
            lock.write(str(run))
        locked = True
        require(not running_engine(), "Engine appeared during lock acquisition")
        run.mkdir(parents=True, exist_ok=False)
        project.mkdir(exist_ok=False)
        evidence.mkdir(parents=True, exist_ok=False)
        for name in names:
            src, dest = repo / name, project / name
            data = src.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(data)
            require(sha(src) == digest == sha(dest), "Input changed during freeze: " + name)
            require(name not in loaded_helpers or digest == loaded_helpers[name], "Loaded helper changed before freeze")
            receipt["source_files"].append({"path": name, "sha256": digest, "bytes": len(data)})
        qa_dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(qa_source, qa_dest)
        require(sha(qa_dest) == receipt["qa_sha256"], "QA changed during freeze")
        harness = evidence / "harness"
        harness.mkdir()
        shutil.copyfile(qa_source, harness / "codex_identity_qa.gd")
        shutil.copyfile(Path(__file__), harness / "run_codex_identity_qa.py")
        for name in HELPERS:
            shutil.copyfile(project / name, harness / Path(name).name)
        def environment(label):
            profile = shared.create_private_profile(run / "contexts" / label, work_root / "profiles" / tag)
            env = art.private_environment(profile)
            for key in list(env):
                if key.startswith("CODEX_QA_"):
                    env.pop(key)
            receipt["profiles"][label] = str(profile)
            return profile, env
        _, import_env = environment("import")
        receipt["source_changes_before_import"] = art.source_changes(repo, receipt["source_files"])
        require(not receipt["source_changes_before_import"] and collect_sources(repo, shared, art) == (runtime, production, names), "Inputs changed before import")
        if args.cache_from is not None:
            prior = shared.resolve_profile_root(args.cache_from)
            require(prior is not None and not prior.resolve().is_relative_to(repo) and prior.resolve() != run.resolve(), "Invalid explicit cache source")
            prior_receipt_path = prior / "evidence/receipt.json"
            prior_receipt = json.loads(prior_receipt_path.read_text(encoding="utf-8"))
            require(any(s.get("case") == "import" and s.get("passed") is True and s.get("exit_code") == 0 for s in prior_receipt.get("steps", [])), "Prior cache has no successful actual import")
            require(Path(prior_receipt.get("source_root", "")).resolve() == repo and prior_receipt.get("godot_sha256") == receipt["godot_sha256"], "Prior cache engine/checkout mismatch")
            imported = shared.resolve_profile_root(prior / "project/.godot/imported")
            require(imported is not None and imported.is_dir(), "Prior imported directory missing")
            # Reject links anywhere inside the cache before copying, including files.
            for p in imported.rglob("*"):
                require(not p.is_symlink() and not (getattr(p.lstat(), "st_file_attributes", 0) & 0x400), "Linked cache entry refused")
            shutil.copytree(imported, project / ".godot/imported")
            receipt["import_cache"] = {"prior_run": str(prior), "prior_receipt_sha256": sha(prior_receipt_path), "scope": "Imported resources only; fresh project source, script class cache and all profiles."}
        art.process_step(engine, project, import_env, evidence, "import", ["--headless", "--editor", "--import", "--quit"], args.import_timeout, "gl_compatibility", running_engine, receipt["steps"])
        require(not art.source_changes(project, receipt["source_files"]), "Import changed frozen production descriptors/source")
        for mode in (["headless"] if args.headless_only else ["headless", "visual"]):
            profile, env = environment(mode)
            directory = evidence / mode
            directory.mkdir()
            env.update(CODEX_QA_SOURCE_ROOT=str(repo), CODEX_QA_OUT=str(directory), CODEX_QA_VISUAL="1" if mode == "visual" else "0")
            arguments = (["--headless"] if mode == "headless" else ["--position", args.window_position]) + ["--script", "res://" + QA_DEST]
            art.process_step(engine, project, env, evidence, mode, arguments, args.timeout, "gl_compatibility", running_engine, receipt["steps"])
            receipt["results"].append(verify_report(directory, project, repo, profile, mode == "visual", receipt["steps"][-1]))
        receipt["runtime_inventory_unchanged"] = collect_sources(repo, shared, art) == (runtime, production, names)
        receipt["qa_unchanged"] = sha(qa_source) == receipt["qa_sha256"] == sha(qa_dest)
        receipt["driver_unchanged"] = sha(Path(__file__)) == receipt["driver_sha256"]
        receipt["godot_unchanged"] = sha(engine) == receipt["godot_sha256"]
        require(all(receipt[k] for k in ("runtime_inventory_unchanged", "qa_unchanged", "driver_unchanged", "godot_unchanged")), "Input identity changed during codex QA")
        receipt["complete"] = True
    except BaseException as exc:
        failure = exc
        receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        if locked:
            receipt["source_changes"] = art.source_changes(repo, receipt["source_files"])
            receipt["private_source_changes"] = art.source_changes(project, receipt["source_files"])
            remaining = running_engine()
            receipt["engines_remaining"] = remaining
            if shared.LOCK.exists() and shared.LOCK.read_text(encoding="utf-8") == str(run) and not remaining:
                shared.LOCK.unlink()
            receipt["lock_released"] = not shared.LOCK.exists()
            receipt["complete"] = receipt["complete"] and receipt["lock_released"] and not receipt["source_changes"] and not receipt["private_source_changes"]
            receipt["visual_acceptance_complete"] = receipt["complete"] and not args.headless_only
        if evidence.exists():
            receipt["artifacts"] = [{"path": p.relative_to(evidence).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)} for p in sorted(evidence.rglob("*")) if p.is_file() and p.name != "receipt.json"]
            (evidence / "receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": receipt["complete"], "visual_acceptance_complete": receipt["visual_acceptance_complete"], "evidence": str(evidence), "checks": sum(r["checks"] for r in receipt["results"]), "failure": receipt.get("failure")}, ensure_ascii=False), flush=True)
    return 0 if failure is None and receipt["complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
