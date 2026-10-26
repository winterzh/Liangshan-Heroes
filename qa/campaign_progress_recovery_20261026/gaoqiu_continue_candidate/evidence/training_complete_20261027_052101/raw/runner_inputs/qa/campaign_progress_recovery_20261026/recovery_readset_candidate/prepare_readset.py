"""Default: read-only checks. --prepare creates a new d7 + SnapshotStore freeze.

The prior freeze and production stay unchanged. Import is a separate owned
engine step. prepared_state() requires that exact import before test execution.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location(
    "readset_prior_disk", HERE.parent / "continue_binding_candidate/tests/run_disk.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
p, h, require = prior.p, prior.h, prior.require
BASE_RUN = ".godot/campaign_progress_recovery_20261026/20261027_013339_8495b720"
BASE_IDENTITY = "source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac"
STORE = "scripts/run_snapshot_store.gd"
BASE_STORE = "7052bc687a26ef9edb155465e070bcedf1ae86a3e8f19b0553bb7757b8ad9b0c"


def preflight():
    state = prior.preflight(ROOT / BASE_RUN, "fixed")
    require(state["content_version"] == BASE_IDENTITY, "Exact imported d7 base required")
    pins = state["pins"]
    source_path = HERE / "source_manifest.json"
    overlay = h.read(source_path)
    require(overlay.get("schema") == "recovery_readset_overlay_v1"
            and overlay.get("base_run") == BASE_RUN
            and overlay.get("base_identity") == BASE_IDENTITY,
            "Readset overlay base changed")
    files = overlay["files"]
    require(len(files) == 1 and files[0]["path"] == STORE
            and files[0]["base_sha256"] == BASE_STORE,
            "Only the explicit SnapshotStore overlay is allowed")
    previous = state["manifest"]
    rows = {row["path"]: dict(row) for row in previous["files"]}
    row = files[0]
    require(rows[STORE]["candidate_sha256"] == BASE_STORE, "d7 Store changed")
    candidate = HERE / STORE
    p.pin(candidate, pins, row["candidate_sha256"])
    require(candidate.stat().st_size == row["candidate_bytes"], "Candidate size changed")
    rows[STORE].update(source_path=candidate.relative_to(ROOT).as_posix(),
                       candidate_sha256=row["candidate_sha256"],
                       candidate_bytes=row["candidate_bytes"])
    for support in overlay["support_files"]:
        path = (HERE / support["path"]).absolute()
        require(path.is_relative_to(HERE) and ".." not in Path(support["path"]).parts,
                "Overlay support must remain inside candidate")
        p.pin(path, pins, support["sha256"])
    sources = h.read(HERE / "sources.json")
    require(sources.get("schema") == "recovery_readset_candidate_sources_v1", "Sources schema changed")
    for source in sources["sources"]:
        path = (ROOT / source["path"]).absolute()
        require(path.is_relative_to(ROOT) and ".." not in Path(source["path"]).parts,
                "Source pin must remain inside checkout")
        p.pin(path, pins, source["sha256"])
    p.pin(HERE / "sources.json", pins)
    overlay_sha = p.pin(source_path, pins)
    p.pin(Path(__file__), pins)
    manifest = {"schema": "recovery_readset_integrated_manifest_v1",
                "previous_manifest_sha256": h.sha(state["run_base"] / "candidate_manifest.json"),
                "previous_identity": BASE_IDENTITY, "previous_run": BASE_RUN,
                "overlay_manifest_sha256": overlay_sha,
                "qualification_inherited": False, "production_integrated": False,
                "files": [rows[name] for name in sorted(rows)],
                "native_assets": previous["native_assets"]}
    p.verify_pins(pins)
    return {**state, "base": state["run_base"], "manifest": manifest, "overlay": overlay}


def prepare(state):
    output = ROOT / ".godot/campaign_progress_recovery_20261026" / h.stamp()
    project = output / "project"
    project.mkdir(parents=True, exist_ok=False)
    pins, manifest = state["pins"], state["manifest"]
    receipt = {"schema": "recovery_readset_preparation_v1", "complete": False,
               "project": str(project), "base_run": str(state["base"]),
               "base_identity": BASE_IDENTITY,
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": h.sha(__file__), "engine_started": False,
               "production_modified": False, "qualification_inherited": False}
    try:
        p.copy(state["base"] / "root_source.json", output / "root_source.json",
               pins[str(state["base"] / "root_source.json")])
        h.save(output / "candidate_manifest.json", manifest)
        receipt["candidate_manifest_sha256"] = h.sha(output / "candidate_manifest.json")
        source = state["generation"]["identity"]
        for name, present in source["directories"].items():
            if present and not name.startswith("@file/"):
                (project / name).mkdir(parents=True, exist_ok=True)
        notice = time.monotonic()
        for index, row in enumerate(source["files"], 1):
            p.copy(state["project"] / row["path"], project / row["path"], row["sha256"])
            if time.monotonic() - notice >= 25:
                print("COPY original d7 %d/%d" % (index, len(source["files"])), flush=True)
                notice = time.monotonic()
        for row in state["overlay"]["files"]:
            p.copy(HERE / row["path"], project / row["path"], row["candidate_sha256"])
        # Provenance EXEs remain at their pinned paths; never duplicate engines.
        for path, digest in pins.items():
            source_path = Path(path)
            if source_path.suffix.lower() == ".exe":
                continue
            require(source_path.is_relative_to(ROOT), "Unexpected non-project provenance input")
            p.copy(path, output / "preparation_inputs" / source_path.relative_to(ROOT), digest)
        receipt["overlays"] = manifest["files"]
        receipt["native_assets"] = manifest["native_assets"]
        receipt["native_dependencies"] = h.shared.install_native(project)
        receipt["identity_seed"] = h.identity.seed(project)
        cache = project / ".godot/imported"
        cache.mkdir(parents=True, exist_ok=False)
        count, size = 0, 0
        for source_cache in sorted((state["project"] / ".godot/imported").iterdir()):
            h.identity.no_links(source_cache)
            if source_cache.is_file():
                p.copy(source_cache, cache / source_cache.name)
                count += 1
                size += source_cache.stat().st_size
                if time.monotonic() - notice >= 25:
                    print("COPY original cache %d files" % count, flush=True)
                    notice = time.monotonic()
        receipt["cache_seed"] = {"files": count, "bytes": size, "qualification_reused": False}
        p.verify_pins(pins)
        h.assert_runtime_current(state["base"])
        h.identity.verify_generated(state["project"], state["generation"])
        frozen = h.identity.snapshot(project)
        expected = {row["path"]: dict(row) for row in source["files"]}
        for row in state["overlay"]["files"]:
            expected[row["path"]].update(sha256=row["candidate_sha256"], bytes=row["candidate_bytes"])
        require(frozen["files"] == [expected[row["path"]] for row in source["files"]]
                and frozen["directories"] == source["directories"],
                "Full source differs beyond the one Store overlay")
        actual = {row["path"]: row["sha256"] for row in frozen["files"]}
        for row in manifest["files"] + manifest["native_assets"]:
            require(actual.get(row["path"]) == row["candidate_sha256"], "Frozen manifest member differs")
        h.save(output / "preimport_source.json", frozen)
        receipt.update(complete=True, source_files=len(source["files"]), source_bytes=frozen["total_bytes"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        receipt["pinned_candidates"] = pins
        h.save(output / "preparation.json", receipt)
    print(json.dumps({"run": str(output), "complete": receipt["complete"], "error": receipt.get("error")}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


def prepared_state(base_run):
    """Read-only full-source and own-import binding for a new candidate run."""
    state = preflight()
    base_run = Path(base_run).resolve()
    require(base_run != state["base"]
            and base_run.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"),
            "New private freeze required")
    h.identity.no_links(base_run)
    manifest = h.read(base_run / "candidate_manifest.json")
    receipt = h.read(base_run / "preparation.json")
    require(manifest == state["manifest"] and receipt.get("complete") is True
            and receipt.get("schema") == "recovery_readset_preparation_v1"
            and receipt.get("base_run") == str(state["base"])
            and receipt.get("base_identity") == BASE_IDENTITY
            and receipt.get("candidate_manifest_sha256") == h.sha(base_run / "candidate_manifest.json")
            and receipt.get("overlays") == manifest["files"]
            and receipt.get("native_assets") == manifest["native_assets"],
            "Preparation and exact manifest binding required")
    pins = state["pins"]
    p.verify_pins(receipt["pinned_candidates"])
    pins.update(receipt["pinned_candidates"])
    project = h.assert_runtime_current(base_run)
    require(project == base_run / "project", "Frozen project path changed")
    generation = h.read(base_run / "generation.json")
    h.identity.verify_generated(project, generation)
    actual = {row["path"]: row["sha256"] for row in generation["identity"]["files"]}
    for row in manifest["files"] + manifest["native_assets"]:
        require(actual.get(row["path"]) == row["candidate_sha256"], "Generated member differs")
        p.pin(project / row["path"], pins, row["candidate_sha256"])
    imports = []
    for path in sorted(base_run.glob("import__*/receipt.json")):
        value = h.read(path)
        steps = value.get("steps", [])
        if (value.get("complete") is True and value.get("phase") == "import"
                and value.get("project") == str(project)
                and value.get("engine_sha256") == state["engine_sha256"]
                and value.get("lock_released") is True and len(steps) == 1
                and steps[0].get("exit_code") == 0 and steps[0].get("passed") is True
                and steps[0].get("errors") == []):
            p.pin(path.parent / "import.log", pins, steps[0]["log_sha256"])
            p.pin(path, pins)
            imports.append(str(path))
    require(imports, "Successful own import on the pinned engine required")
    for name in ("candidate_manifest.json", "preparation.json", "root_source.json", "preimport_source.json", "generation.json"):
        p.pin(base_run / name, pins)
    p.verify_pins(pins)
    return {**state, "run_base": base_run, "project": project, "generation": generation,
            "imports": imports, "content_version": "source-v1:" + generation["identity"]["source_sha256"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--check-run", type=Path, help="Read-only own-import and full-source check")
    args = parser.parse_args()
    if args.prepare and args.check_run:
        parser.error("Choose preparation or imported-run check")
    state = prepared_state(args.check_run) if args.check_run else preflight()
    if args.prepare:
        prepare(state)
    else:
        print(json.dumps({"preflight": True, "base_identity": BASE_IDENTITY,
                          "scripts": len(state["manifest"]["files"]), "engine_started": False,
                          "created_freeze": False, "checked_run": str(args.check_run) if args.check_run else None}, ensure_ascii=False))


if __name__ == "__main__":
    main()
