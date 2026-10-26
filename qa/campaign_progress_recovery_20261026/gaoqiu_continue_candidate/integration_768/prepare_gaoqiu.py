"""Default: lightweight metadata/source-pin check, NOT full-source qualification.

--full-preflight verifies the entire imported 768 source and its provenance.
--prepare additionally creates a NEW full freeze with only the Gao Session
overlay. --check-run requires that new freeze's own successful import. None of
these commands starts Godot; import and natural gameplay are separate steps.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
QA = HERE.parents[1]
spec = importlib.util.spec_from_file_location(
    "gaoqiu_768_prior", QA / "recovery_readset_candidate/prepare_readset.py")
prior = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prior)
p, h, require = prior.p, prior.h, prior.require
BASE_RUN = ".godot/campaign_progress_recovery_20261026/20261027_034810_ed1bdef8"
BASE_IDENTITY = "source-v1:768b6e5937321126b4c927fce6b5565459610aa13ccb556f695837a814eb74c2"
BASE_MANIFEST = "11c1d813daab8fd9eeaa0e8ed7569deb33da3af243b429c9cffc69c6de74a5e6"
SESSION = "scripts/run_world_session.gd"
BASE_SESSION = "fbea69f28d74b9d4372a93cdcc933ead129f3bbbc8b1c89c51fdca43965e5427"
GAO_SESSION = "420b59364d26382d5c9b2e96b4671ce5e507bc9cd18c4e07a4b2a06a185f563e"
GAO_SOURCE = "qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/scripts/run_world_session.gd"


def inside(root, relative):
    value = Path(relative)
    require(not value.is_absolute() and ".." not in value.parts, "Relative source path required")
    path = (root / value).absolute()
    require(path.is_relative_to(root), "Source path escaped its root")
    h.identity.no_links(p.fs(path))
    return path


def merge_pins(target, additions):
    for path, digest in additions.items():
        require(path not in target or target[path] == digest, "Conflicting source pin: " + path)
        target[path] = digest


def lightweight():
    """Only named metadata and small source files; never snapshot a project."""
    pins = {}
    overlay_path = HERE / "source_manifest.json"
    overlay = h.read(overlay_path)
    require(overlay.get("schema") == "gaoqiu_768_overlay_v1"
            and overlay.get("base_run") == BASE_RUN
            and overlay.get("base_identity") == BASE_IDENTITY
            and overlay.get("base_manifest_sha256") == BASE_MANIFEST,
            "Exact 768 overlay origin required")
    files = overlay.get("files", [])
    require(len(files) == 1 and files[0].get("path") == SESSION
            and files[0].get("source_path") == GAO_SOURCE
            and files[0].get("base_sha256") == BASE_SESSION
            and files[0].get("candidate_sha256") == GAO_SESSION,
            "Only the existing fixed Gao Session overlay is allowed")
    sources_path = HERE / "sources.json"
    sources = h.read(sources_path)
    require(sources.get("schema") == "gaoqiu_768_sources_v1" and sources.get("sources"),
            "Source list required")
    for row in sources["sources"]:
        p.pin(inside(ROOT, row["path"]), pins, row["sha256"])
    for row in overlay["support_files"]:
        p.pin(inside(HERE, row["path"]), pins, row["sha256"])
    base = ROOT / BASE_RUN
    previous_path = base / "candidate_manifest.json"
    p.pin(previous_path, pins, BASE_MANIFEST)
    previous = h.read(previous_path)
    require(previous.get("schema") == "recovery_readset_integrated_manifest_v1"
            and len(previous["files"]) == 23 and len(previous["native_assets"]) == 1,
            "Exact previous 23 scripts and native helper required")
    generation = h.read(base / "generation.json")
    require("source-v1:" + generation["identity"]["source_sha256"] == BASE_IDENTITY,
            "Named base identity metadata changed")
    rows = {row["path"]: deepcopy(row) for row in previous["files"]}
    require(len(rows) == 23 and rows[SESSION]["candidate_sha256"] == BASE_SESSION,
            "Previous Session must be the original d7/768 bytes")
    candidate = inside(ROOT, GAO_SOURCE)
    p.pin(candidate, pins, GAO_SESSION)
    require(p.fs(candidate).stat().st_size == files[0]["candidate_bytes"], "Gao Session size changed")
    rows[SESSION].update(source_path=GAO_SOURCE, candidate_sha256=GAO_SESSION,
                         candidate_bytes=files[0]["candidate_bytes"])
    p.pin(sources_path, pins)
    overlay_sha = p.pin(overlay_path, pins)
    p.pin(Path(__file__), pins)
    manifest = {"schema": "gaoqiu_768_integrated_manifest_v1",
                "previous_manifest_sha256": BASE_MANIFEST,
                "previous_identity": BASE_IDENTITY, "previous_run": BASE_RUN,
                "overlay_manifest_sha256": overlay_sha,
                "qualification_inherited": False, "production_integrated": False,
                "files": [rows[name] for name in sorted(rows)],
                "native_assets": deepcopy(previous["native_assets"])}
    p.verify_pins(pins)
    return {"pins": pins, "base": base, "manifest": manifest, "previous_manifest": previous,
            "overlay": overlay, "validation_level": "metadata_and_named_sources_only",
            "full_source_verified": False}


def preflight():
    """Full admission: original imported 768 plus the exact one-file overlay."""
    light = lightweight()
    state = prior.prepared_state(ROOT / BASE_RUN)
    require(state["run_base"] == light["base"] and state["content_version"] == BASE_IDENTITY
            and state["manifest"] == light["previous_manifest"],
            "Full imported 768 provenance differs from lightweight metadata")
    merge_pins(state["pins"], light["pins"])
    p.verify_pins(state["pins"])
    return {**state, "base": state["run_base"], "manifest": light["manifest"],
            "overlay": light["overlay"], "validation_level": "full_imported_base",
            "full_source_verified": True}


def expected_files(state):
    source = state["generation"]["identity"]["files"]
    rows = {row["path"]: dict(row) for row in source}
    require(rows[SESSION]["sha256"] == BASE_SESSION, "Full base Session changed")
    row = state["overlay"]["files"][0]
    rows[SESSION].update(sha256=row["candidate_sha256"], bytes=row["candidate_bytes"])
    return [rows[row["path"]] for row in source]


def check_composition(identity, state):
    require(identity["files"] == expected_files(state)
            and identity["directories"] == state["generation"]["identity"]["directories"],
            "Full source differs beyond the single Gao Session overlay")
    actual = {row["path"]: row["sha256"] for row in identity["files"]}
    for row in state["manifest"]["files"] + state["manifest"]["native_assets"]:
        require(actual.get(row["path"]) == row["candidate_sha256"], "Composed manifest member differs")


def prepare(state):
    require(state.get("full_source_verified") is True, "Lightweight result cannot prepare a freeze")
    output = ROOT / ".godot/campaign_progress_recovery_20261026" / h.stamp()
    project = output / "project"
    project.mkdir(parents=True, exist_ok=False)
    pins, manifest = state["pins"], state["manifest"]
    receipt = {"schema": "gaoqiu_768_preparation_v1", "complete": False,
               "project": str(project), "base_run": str(state["base"]), "base_identity": BASE_IDENTITY,
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
                p.fs(project / name).mkdir(parents=True, exist_ok=True)
        notice = time.monotonic()
        for index, row in enumerate(source["files"], 1):
            p.copy(state["project"] / row["path"], project / row["path"], row["sha256"])
            if time.monotonic() - notice >= 25:
                print("COPY original 768 %d/%d" % (index, len(source["files"])), flush=True)
                notice = time.monotonic()
        for row in state["overlay"]["files"]:
            p.copy(inside(ROOT, row["source_path"]), project / row["path"], row["candidate_sha256"])
        # Actual native helper is already in the full source above. Its build,
        # source and receipt remain pinned; engines/EXEs are not evidence copies.
        for path, digest in pins.items():
            source_path = Path(path)
            if source_path.suffix.lower() == ".exe":
                continue
            require(source_path.is_relative_to(ROOT), "Unexpected provenance path")
            p.copy(source_path, output / "preparation_inputs" / source_path.relative_to(ROOT), digest)
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
        check_composition(frozen, state)
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
    """Future drivers must use this full binding, never lightweight()."""
    state = preflight()
    base_run = Path(base_run).resolve()
    require(base_run != state["base"]
            and base_run.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"),
            "A new private Gao freeze is required")
    h.identity.no_links(base_run)
    manifest = h.read(base_run / "candidate_manifest.json")
    receipt = h.read(base_run / "preparation.json")
    require(manifest == state["manifest"] and receipt.get("complete") is True
            and receipt.get("schema") == "gaoqiu_768_preparation_v1"
            and receipt.get("base_run") == str(state["base"])
            and receipt.get("base_identity") == BASE_IDENTITY
            and receipt.get("candidate_manifest_sha256") == h.sha(base_run / "candidate_manifest.json")
            and receipt.get("overlays") == manifest["files"]
            and receipt.get("native_assets") == manifest["native_assets"],
            "Exact completed Gao preparation and manifest required")
    pins = state["pins"]
    p.verify_pins(receipt["pinned_candidates"])
    merge_pins(pins, receipt["pinned_candidates"])
    require(all(receipt["pinned_candidates"].get(path) == digest for path, digest in state["pins"].items()),
            "Preparation must retain the complete current provenance set")
    project = h.assert_runtime_current(base_run)
    require(project == base_run / "project", "Prepared project path changed")
    generation = h.read(base_run / "generation.json")
    h.identity.verify_generated(project, generation)
    check_composition(generation["identity"], state)
    require(h.read(base_run / "preimport_source.json") == generation["identity"],
            "Generated source must equal the complete preimport source")
    require(h.sha(base_run / "root_source.json") == pins[str(state["base"] / "root_source.json")],
            "Original production identity record changed")
    for row in manifest["files"] + manifest["native_assets"]:
        p.pin(project / row["path"], pins, row["candidate_sha256"])
    imports = []
    for path in sorted(base_run.glob("import__*/receipt.json")):
        value = h.read(path)
        steps = value.get("steps", [])
        if not (value.get("complete") is True and value.get("phase") == "import"
                and value.get("project") == str(project)
                and value.get("engine_sha256") == state["engine_sha256"]
                and value.get("lock_released") is True and len(steps) == 1):
            continue
        step = steps[0]
        command = step.get("command", [])
        if not (step.get("passed") is True and type(step.get("pid")) is int and step["pid"] > 0
                and type(step.get("exit_code")) is int and step["exit_code"] == 0
                and step.get("errors") == [] and step.get("stopped_for") is None
                and command and Path(command[0]) == state["engine"]
                and "--path" in command and command.index("--path") + 1 < len(command)
                and Path(command[command.index("--path") + 1]) == project
                and all(flag in command for flag in ("--editor", "--import", "--quit"))):
            continue
        p.pin(path.parent / "import.log", pins, step["log_sha256"])
        p.pin(path, pins)
        imports.append(str(path))
    require(imports, "Successful own import/PID/exit/log on the pinned engine required")
    for name in ("candidate_manifest.json", "preparation.json", "root_source.json", "preimport_source.json",
                 "generation.json", "expected_identity.json"):
        p.pin(base_run / name, pins)
    p.verify_pins(pins)
    return {**state, "run_base": base_run, "project": project, "generation": generation,
            "imports": imports, "content_version": "source-v1:" + generation["identity"]["source_sha256"],
            "validation_level": "full_new_freeze_and_own_import"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--full-preflight", action="store_true", help="Expensive complete imported-base verification; no copy")
    modes.add_argument("--prepare", action="store_true", help="Full verification, then NEW freeze only; no engine")
    modes.add_argument("--check-run", type=Path, help="Full new-freeze/own-import verification for future execution")
    args = parser.parse_args()
    if args.check_run:
        state = prepared_state(args.check_run)
    elif args.prepare or args.full_preflight:
        state = preflight()
    else:
        state = lightweight()
    if args.prepare:
        prepare(state)
    else:
        print(json.dumps({"validation_level": state["validation_level"],
                          "full_source_verified": state["full_source_verified"],
                          "base_identity": BASE_IDENTITY, "scripts": len(state["manifest"]["files"]),
                          "native_assets": len(state["manifest"]["native_assets"]), "pins": len(state["pins"]),
                          "engine_started": False, "created_freeze": False,
                          "checked_run": str(args.check_run) if args.check_run else None}, ensure_ascii=False))


if __name__ == "__main__":
    main()
