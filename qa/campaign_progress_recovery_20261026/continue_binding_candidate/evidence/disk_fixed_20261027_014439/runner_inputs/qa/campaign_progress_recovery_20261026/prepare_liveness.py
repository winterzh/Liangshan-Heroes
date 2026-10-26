"""Prepare a separately pinned 23-script recovery candidate; default is read-only.

The fixed native helper is a private build artifact. Its source/build receipt and
actual executable hash are bound separately and included in the frozen identity.
No production file or earlier frozen project is changed.
"""
from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("liveness_prepare_base", HERE / "prepare_handoff.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
helper = base.helper
PREVIOUS = HERE / "store_protocol_candidate/integrated_candidate"
OVERLAY = HERE / "process_liveness_integration_candidate"
PREVIOUS_SHA = "8dfa8791b181319179fb27b284c4d5e9e34031d5c616a53616fe2a40da62400f"
HELPER_SHA = "012354b1cf0376712f97e19362d91b2ef7f51775c6797c862c513df1e2f1936c"
OVERLAY_FILES = {"scripts/" + name for name in (
    "run_snapshot_store.gd", "steam_receipt_store.gd", "process_liveness_oracle.gd",
    "run_process_liveness_manager.gd")}
NATIVE_TARGET = "addons/process_liveness/windows/ProcessLivenessProbe.exe"


def require(value, message):
    if not value:
        raise RuntimeError(message)


def pinned(path, expected, pins):
    helper.identity.no_links(path)
    require(path.is_file() and helper.sha(path) == expected, "Source/hash mismatch: " + str(path))
    pins[str(path)] = expected
    return path


def preflight():
    pins = {}
    previous_path = pinned(PREVIOUS / "manifest.json", PREVIOUS_SHA, pins)
    previous = helper.read(previous_path)
    overlay_path = OVERLAY / "source_manifest.json"
    helper.identity.no_links(overlay_path)
    overlay = helper.read(overlay_path)
    pinned(overlay_path, helper.sha(overlay_path), pins)
    require(overlay["previous_20file_manifest"]["sha256"] == PREVIOUS_SHA, "Wrong previous candidate")
    old_rows = previous["files"]
    require(len(old_rows) == 20 and {r["path"] for r in old_rows} == {"scripts/" + n for n in base.FILES},
            "Exact previous twenty-file set required")
    new_rows = overlay["files"]
    require(len(new_rows) == 4 and {r["path"] for r in new_rows} == OVERLAY_FILES, "Exact four-file overlay required")
    rows = {}
    for row in old_rows:
        name = row["path"]
        source = pinned(PREVIOUS / name, row["candidate_sha256"], pins)
        production = ROOT / name
        helper.identity.no_links(production)
        actual = helper.sha(production) if production.exists() else None
        require(actual == row["production_base_sha256"], "Production base changed: " + name)
        rows[name] = {"path": name, "source_path": source.relative_to(ROOT).as_posix(),
                      "production_base_sha256": actual, "candidate_sha256": row["candidate_sha256"],
                      "candidate_bytes": source.stat().st_size}
    for row in new_rows:
        name = row["path"]
        source = pinned(OVERLAY / name, row["candidate_sha256"], pins)
        require(source.stat().st_size == row["candidate_bytes"], "Overlay size changed: " + name)
        if row["base_path"] is not None:
            pinned(ROOT / row["base_path"], row["base_sha256"], pins)
        production = ROOT / name
        helper.identity.no_links(production)
        actual = helper.sha(production) if production.exists() else None
        if name == "scripts/run_snapshot_store.gd":
            require(actual == row["base_sha256"], "Snapshot production base changed")
        elif name not in rows:
            require(actual is None, "New overlay unexpectedly exists in production: " + name)
        rows[name] = {"path": name, "source_path": source.relative_to(ROOT).as_posix(),
                      "production_base_sha256": actual, "candidate_sha256": row["candidate_sha256"],
                      "candidate_bytes": source.stat().st_size}
    require(len(rows) == 23, "Exact combined twenty-three-script set required")
    native = overlay["helper"]
    require(native["target_path"] == NATIVE_TARGET and native["sha256"] == HELPER_SHA, "Native identity changed")
    require(not (ROOT / NATIVE_TARGET).exists(), "Native target already exists in production")
    for key, sha_key in (("source_path", "source_sha256"), ("build_receipt_path", "build_receipt_sha256"),
                         ("ignored_artifact_path", "sha256")):
        relative = Path(native[key])
        require(not relative.is_absolute() and ".." not in relative.parts, "Native source must be repository-relative")
        pinned(ROOT / relative, native[sha_key], pins)
    for path in (Path(__file__), Path(base.__file__), Path(helper.__file__), Path(helper.identity.__file__),
                 Path(helper.common.__file__), Path(helper.shared.__file__)):
        pinned(path, helper.sha(path), pins)
    manifest = {"schema": "campaign_liveness_integrated_manifest_v1", "previous_manifest_sha256": PREVIOUS_SHA,
                "overlay_manifest_sha256": pins[str(overlay_path)], "qualification_inherited": False,
                "production_integrated": False, "files": [rows[name] for name in sorted(rows)],
                "native_assets": [{"path": NATIVE_TARGET, "source_path": native["ignored_artifact_path"],
                                   "candidate_sha256": HELPER_SHA, "source_sha256": native["source_sha256"],
                                   "build_receipt_sha256": native["build_receipt_sha256"]}]}
    helper.suite_verify_pins(pins)
    return manifest, pins


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare", action="store_true", help="create a new private frozen project; never starts Godot")
    args = parser.parse_args()
    manifest, pins = preflight()
    if not args.prepare:
        print({"preflight": True, "scripts": len(manifest["files"]), "native_assets": len(manifest["native_assets"]),
               "overlay_manifest_sha256": manifest["overlay_manifest_sha256"], "engine_started": False})
        return
    output = ROOT / ".godot/campaign_progress_recovery_20261026" / helper.stamp()
    project = output / "project"
    project.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "campaign_liveness_preparation_v1", "complete": False, "project": str(project),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": helper.sha(__file__), "production_modified": False, "candidate_qualified": False,
               "engine_started": False, "steps": []}
    try:
        print("PREPARE current production identity", flush=True)
        source = helper.identity.snapshot(ROOT)
        helper.save(output / "root_source.json", source)
        helper.save(output / "candidate_manifest.json", manifest)
        receipt["candidate_manifest_sha256"] = helper.sha(output / "candidate_manifest.json")
        for path in (Path(__file__), PREVIOUS / "manifest.json", OVERLAY / "source_manifest.json"):
            helper.copy_checked(path, output / "preparation_inputs" / path.relative_to(ROOT), pins[str(path)])
        for name, present in source["directories"].items():
            if present and not name.startswith("@file/"):
                (project / name).mkdir(parents=True, exist_ok=True)
        last_notice = time.monotonic()
        for index, row in enumerate(source["files"], 1):
            helper.copy_checked(ROOT / row["path"], project / row["path"], row["sha256"])
            if time.monotonic() - last_notice >= 25:
                print("COPY production %d/%d" % (index, len(source["files"])), flush=True)
                last_notice = time.monotonic()
        for row in manifest["files"] + manifest["native_assets"]:
            helper.copy_checked(ROOT / row["source_path"], project / row["path"], row["candidate_sha256"])
        receipt["overlays"] = manifest["files"]
        receipt["native_assets"] = manifest["native_assets"]
        receipt["native_dependencies"] = helper.shared.install_native(project)
        receipt["identity_seed"] = helper.identity.seed(project)
        cache = project / ".godot/imported"
        cache.mkdir(parents=True)
        count, size = 0, 0
        for source_cache in sorted((ROOT / ".godot/imported").iterdir()):
            if source_cache.is_file():
                helper.copy_checked(source_cache, cache / source_cache.name)
                count += 1
                size += source_cache.stat().st_size
                if time.monotonic() - last_notice >= 25:
                    print("COPY import-cache %d files" % count, flush=True)
                    last_notice = time.monotonic()
        receipt["cache_seed"] = {"files": count, "bytes": size, "qualification_reused": False}
        helper.suite_verify_pins(pins)
        require(helper.identity.snapshot(ROOT) == source, "Production changed during preparation")
        frozen = helper.identity.snapshot(project)
        found = [r for r in frozen["files"] if r["path"] == NATIVE_TARGET]
        require(len(found) == 1 and found[0]["sha256"] == HELPER_SHA, "Native helper missing from full identity")
        helper.save(output / "preimport_source.json", frozen)
        receipt.update(complete=True, source_files=len(source["files"]), source_bytes=source["total_bytes"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        receipt["pinned_candidates"] = pins
        helper.save(output / "preparation.json", receipt)
    print({"run": str(output), "complete": receipt["complete"], "error": receipt.get("error")}, flush=True)
    if not receipt["complete"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
