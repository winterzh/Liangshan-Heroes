"""Read-only by default; --prepare creates a NEW e97a-based 23-script freeze.

Reuses the existing identity, native dependency and copy APIs. Never starts
Godot or modifies production/the original freeze. No previous test is inherited.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


original = load("continue_original_liveness_prepare", HERE.parent / "prepare_liveness.py")
sources = load("continue_overlay_sources", HERE / "check_sources.py")
h, require = original.helper, original.require


def fs(path):
    """Keep receipts readable while allowing long Windows evidence paths."""
    value = str(Path(path).absolute())
    if os.name == "nt" and not value.startswith("\\\\?\\"):
        value = "\\\\?\\UNC\\" + value[2:] if value.startswith("\\\\") else "\\\\?\\" + value
    return Path(value)


def pin(path, pins, expected=None):
    path = Path(path).absolute()
    h.identity.no_links(fs(path))
    digest = h.sha(fs(path))
    require(expected is None or digest == expected, "Pinned input changed: " + str(path))
    pins[str(path)] = digest
    return digest


def verify_pins(pins):
    h.suite_verify_pins({str(fs(path)): digest for path, digest in pins.items()})


def copy(source, target, expected=None):
    h.copy_checked(fs(source), fs(target), expected)


def preflight():
    overlay = sources.verify()
    previous, pins = original.preflight()
    base = ROOT / overlay["base_run"]
    require(base.resolve() == base and base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"),
            "Exact original private freeze required")
    for row in overlay["base_records"]:
        pin(ROOT / row["path"], pins, row["sha256"])
    previous_path = base / "candidate_manifest.json"
    require(h.read(previous_path) == previous, "Original 23-script manifest changed")
    preparation = h.read(base / "preparation.json")
    require(preparation.get("schema") == "campaign_liveness_preparation_v1" and preparation.get("complete") is True
            and preparation.get("candidate_manifest_sha256") == pins[str(previous_path)]
            and preparation.get("overlays") == previous["files"]
            and preparation.get("native_assets") == previous["native_assets"], "Original preparation binding changed")
    project = h.assert_runtime_current(base)
    require(project == base / "project", "Original project path changed")
    generation = h.read(base / "generation.json")
    h.identity.verify_generated(project, generation)
    require("source-v1:" + generation["identity"]["source_sha256"] == overlay["base_identity"], "Original identity changed")
    generated = {row["path"]: row for row in generation["identity"]["files"]}
    rows = {row["path"]: dict(row) for row in previous["files"]}
    for row in previous["files"] + previous["native_assets"]:
        require(generated[row["path"]]["sha256"] == row["candidate_sha256"], "Original member identity changed")
        pin(project / row["path"], pins, row["candidate_sha256"])
    for row in overlay["files"]:
        name = row["path"]
        require(name in rows and rows[name]["candidate_sha256"] == row["base_sha256"], "Overlay base is not the original 23-set")
        source = HERE / name
        pin(source, pins, row["candidate_sha256"])
        rows[name].update(source_path=source.relative_to(ROOT).as_posix(),
                          candidate_sha256=row["candidate_sha256"], candidate_bytes=row["candidate_bytes"])
    require(len(rows) == 23 and len(overlay["files"]) == 3, "Exact 23-script / three-overlay composition required")
    for row in overlay["support_files"]:
        pin(HERE / row["path"], pins, row["sha256"])
    for name in ("root_source.json", "preimport_source.json"):
        pin(base / name, pins)
    pin(ROOT / "tools/run_campaign_level_state_qa.py", pins)  # actual running_engine provider
    overlay_sha = pin(HERE / "source_manifest.json", pins)
    pin(Path(__file__), pins)
    manifest = {"schema": "continue_binding_integrated_manifest_v1",
                "previous_manifest_sha256": pins[str(previous_path)], "previous_identity": overlay["base_identity"],
                "previous_run": overlay["base_run"], "overlay_manifest_sha256": overlay_sha,
                "qualification_inherited": False, "production_integrated": False,
                "files": [rows[name] for name in sorted(rows)], "native_assets": previous["native_assets"]}
    verify_pins(pins)
    return {"manifest": manifest, "pins": pins, "base": base, "project": project,
            "generation": generation, "overlay": overlay}


def prepare(state):
    output = ROOT / ".godot/campaign_progress_recovery_20261026" / h.stamp()
    project = output / "project"
    project.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "continue_binding_preparation_v1", "complete": False,
               "project": str(project), "base_run": str(state["base"]),
               "base_identity": state["overlay"]["base_identity"],
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": h.sha(__file__), "engine_started": False, "production_modified": False,
               "qualification_inherited": False, "steps": []}
    pins, manifest = state["pins"], state["manifest"]
    try:
        copy(state["base"] / "root_source.json", output / "root_source.json", pins[str(state["base"] / "root_source.json")])
        h.save(output / "candidate_manifest.json", manifest)
        receipt["candidate_manifest_sha256"] = h.sha(output / "candidate_manifest.json")
        # Full bytes come ONLY from the original generated identity, not ROOT.
        source = state["generation"]["identity"]
        for name, present in source["directories"].items():
            if present and not name.startswith("@file/"):
                (project / name).mkdir(parents=True, exist_ok=True)
        notice = time.monotonic()
        for index, row in enumerate(source["files"], 1):
            copy(state["project"] / row["path"], project / row["path"], row["sha256"])
            if time.monotonic() - notice >= 25:
                print("COPY original e97a %d/%d" % (index, len(source["files"])), flush=True)
                notice = time.monotonic()
        for row in state["overlay"]["files"]:
            copy(HERE / row["path"], project / row["path"], row["candidate_sha256"])
        for path, digest in pins.items():
            copy(path, output / "preparation_inputs" / Path(path).relative_to(ROOT), digest)
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
                copy(source_cache, cache / source_cache.name)
                count += 1
                size += source_cache.stat().st_size
                if time.monotonic() - notice >= 25:
                    print("COPY original cache %d files" % count, flush=True)
                    notice = time.monotonic()
        receipt["cache_seed"] = {"files": count, "bytes": size, "qualification_reused": False}
        verify_pins(pins)
        h.assert_runtime_current(state["base"])
        h.identity.verify_generated(state["project"], state["generation"])
        frozen = h.identity.snapshot(project)
        expected_files = {row["path"]: dict(row) for row in source["files"]}
        for row in state["overlay"]["files"]:
            expected_files[row["path"]].update(sha256=row["candidate_sha256"], bytes=row["candidate_bytes"])
        require(frozen["files"] == [expected_files[row["path"]] for row in source["files"]]
                and frozen["directories"] == source["directories"], "Full original copy differs beyond the explicit three overlays")
        actual = {row["path"]: row["sha256"] for row in frozen["files"]}
        for row in manifest["files"] + manifest["native_assets"]:
            require(actual.get(row["path"]) == row["candidate_sha256"], "Frozen member differs or is missing")
        h.save(output / "preimport_source.json", frozen)
        receipt.update(complete=True, source_files=len(source["files"]), source_bytes=source["total_bytes"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        receipt["pinned_candidates"] = pins
        h.save(output / "preparation.json", receipt)
    print(json.dumps({"run": str(output), "complete": receipt["complete"], "error": receipt.get("error")}, ensure_ascii=False), flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true", help="create new freeze; never starts Godot")
    args = parser.parse_args()
    state = preflight()
    if args.prepare:
        prepare(state)
    else:
        print(json.dumps({"preflight": True, "scripts": len(state["manifest"]["files"]),
                          "native_assets": len(state["manifest"]["native_assets"]),
                          "base_identity": state["overlay"]["base_identity"],
                          "source_manifest_sha256": state["manifest"]["overlay_manifest_sha256"],
                          "engine_started": False, "created_freeze": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
