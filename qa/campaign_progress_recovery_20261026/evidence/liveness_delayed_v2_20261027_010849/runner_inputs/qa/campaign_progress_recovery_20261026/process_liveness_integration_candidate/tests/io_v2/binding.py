"""Explicit 23-script/native-helper binding; imports legacy stage APIs without patching them."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
QA = HERE.parents[2]
OLD = QA / "store_protocol_candidate/tests/io"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


io = load_module("liveness_io_legacy_stages", OLD / "run_io.py")
delayed = load_module("liveness_io_legacy_delayed", OLD / "run_delayed_acquire.py")
prepare = load_module("liveness_io_prepare_binding", QA / "prepare_liveness.py")
helper, require = io.helper, io.require


def pin(path, pins, expected=None):
    path = io.plain_path(path)
    native = io.fs_path(path)
    helper.identity.no_links(native)
    digest = helper.sha(native)
    require(expected is None or digest == expected, "Pinned input changed: " + str(path))
    pins[str(path)] = digest
    return digest


def verify_pins(pins):
    # Receipts retain normal absolute paths; native I/O uses the already
    # validated extended-path implementation, including copied runner_inputs.
    helper.suite_verify_pins({str(io.fs_path(path)): digest for path, digest in pins.items()})


def pin_tree(folder, pins):
    for parent, directories, names in io.os.walk(io.fs_path(folder), followlinks=False, onerror=io.raise_walk_error):
        for name in directories + names:
            helper.identity.no_links(Path(parent) / name)
        for name in names:
            pin(Path(parent) / name, pins)


def source_points(project):
    # The statement itself is unchanged. Only its containing wrapper moved.
    points = io.source_points(project)
    points["recover_claim_crash"]["function"] = "_recover_unique"
    for row in [*points.values(), *delayed.points_for(project).values()]:
        source = project / row["source"].removeprefix("res://")
        lines = source.read_text(encoding="utf-8-sig").splitlines()
        functions = [re.match(r"^func (\w+)\(", line) for line in lines[:row["line"]]]
        functions = [match.group(1) for match in functions if match]
        require(functions and functions[-1] == row["function"], "Breakpoint containing function changed")
    return points


def preflight(base):
    base = base.resolve()
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026"), "Private campaign freeze required")
    helper.identity.no_links(base)
    # Rebuild the strict 20 + 4 overlay union (23 distinct paths), with the
    # unchanged preparation tool. This also binds native source/build/exe.
    expected, pins = prepare.preflight()
    manifest = helper.read(base / "candidate_manifest.json")
    preparation = helper.read(base / "preparation.json")
    require(manifest == expected and len(manifest["files"]) == 23, "Exact current 23-script manifest required")
    require(preparation.get("schema") == "campaign_liveness_preparation_v1" and preparation.get("complete") is True,
            "Completed liveness preparation required")
    require(preparation.get("candidate_manifest_sha256") == helper.sha(base / "candidate_manifest.json")
            and preparation.get("overlays") == manifest["files"]
            and preparation.get("native_assets") == manifest["native_assets"], "Preparation/manifest binding changed")
    project = helper.assert_runtime_current(base)
    require(project.resolve() == base / "project", "Frozen project must belong to this base run")
    generation = helper.read(base / "generation.json")
    helper.identity.verify_generated(project, generation)
    generated_rows = {row["path"]: row for row in generation["identity"]["files"]}
    for row in [*manifest["files"], *manifest["native_assets"]]:
        path = row["path"]
        require(path in generated_rows and generated_rows[path]["sha256"] == row["candidate_sha256"],
                "Generated identity omits or changes manifest member: " + path)
        pin(project / path, pins, row["candidate_sha256"])
        if "candidate_bytes" in row:
            require((project / path).stat().st_size == row["candidate_bytes"], "Candidate byte count mismatch")
    engine = helper.shared.resolve_godot(None)
    engine_sha = pin(engine, pins)
    imported = []
    for path in sorted(base.glob("import__*/receipt.json")):
        value = helper.read(path)
        steps = value.get("steps", [])
        if (value.get("complete") is True and value.get("phase") == "import"
                and value.get("project") == str(project) and value.get("engine_sha256") == engine_sha
                and value.get("lock_released") is True and len(steps) == 1
                and steps[0].get("exit_code") == 0 and steps[0].get("passed") is True and steps[0].get("errors") == []):
            pin(path.parent / "import.log", pins, steps[0]["log_sha256"])
            pin(path, pins)
            imported.append(str(path))
    require(imported, "A successful terminal import receipt for this project and engine is required")
    provenance = helper.read(HERE / "provenance.json")
    require(provenance.get("schema") == "liveness_io_adapter_sources_v1", "Unknown adapter provenance")
    for row in provenance["upstream_files"]:
        relative = Path(row["path"])
        require(not relative.is_absolute() and ".." not in relative.parts, "Repository-relative provenance required")
        pin(ROOT / relative, pins, row["sha256"])
    for row in provenance["adapted_workers"]:
        require(row["path"] in ("worker.gd", "delayed_worker.gd"), "Unknown adapted worker")
        pin(HERE / row["path"], pins, row["sha256"])
    for path in [*HERE.glob("*.py"), HERE / "README.md", HERE / "provenance.json", HERE / "worker_changes.diff",
                 Path(helper.__file__), Path(helper.common.__file__), Path(helper.identity.__file__), Path(helper.shared.__file__),
                 ROOT / "tools/godot_debug_wire.py", ROOT / "tools/run_workstation_baseline.py",
                 *(base / name for name in ("preparation.json", "root_source.json", "preimport_source.json", "generation.json", "candidate_manifest.json"))]:
        pin(path, pins)
    verify_pins(pins)
    return {"base": base, "project": project, "generation": generation, "manifest": manifest,
            "manifest_sha256": helper.sha(base / "candidate_manifest.json"), "pins": pins, "engine": engine,
            "points": source_points(project), "delayed_points": delayed.points_for(project), "imports": imported,
            "identity": {"content_version": "source-v1:" + generation["identity"]["source_sha256"],
                         "engine_sha256": engine_sha, "source_mode": True}}


def validate_liveness_rows(document, profile, pins):
    """Bind worker observations to the original atomic native report files."""
    rows = document.get("liveness_observations", [])
    for row in rows:
        wanted, target = row["expected_state"], row["target_pid"]
        result = row["result"]
        require(row["scope_closed"] is True and wanted in ("alive", "dead"), "Unclosed or invalid liveness observation")
        if wanted == "dead":
            require(result.get("ok") is True and result.get("code") == "PROCESS_CONFIRMED_DEAD", "Confirmed death required")
            observed = result["observation"]
        else:
            require(result.get("ok") is False and result.get("code") == "WRITER_ALIVE", "Confirmed live A required")
            observed = result["liveness_detail"]
        require(observed["state"] == wanted and observed["target_pid"] == target
                and observed.get("pending") is False and observed.get("helper_cleanup_confirmed") is True
                and observed["helper_sha256"] == prepare.HELPER_SHA, "Actual helper observation mismatch")
        folder = Path(observed["probe_directory"])
        require(folder.is_absolute(), "Absolute probe path required")
        folder = io.owned(folder, profile)
        raw_path = folder / "result.json"
        helper.identity.no_links(io.fs_path(raw_path))
        require(io.fs_path(raw_path).stat().st_size <= 4096 and not io.fs_path(folder / "pending.json").exists(), "Atomic bounded helper report required")
        native = helper.read(io.fs_path(raw_path))
        require(native == observed["evidence"] and native["target_pid"] == str(target)
                and native["provider_pid"] == str(observed["provider_pid"])
                and native["nonce"] == folder.name, "Raw helper report differs from observed PID/nonce/evidence")
        pin(raw_path, pins)
    return len(rows)
