"""Freeze the explicit twenty-file Steam handoff candidate without production adoption."""
from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location(
    "campaign_handoff_prepare_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
FILES = {
    "battle.gd", "campaign.gd", "continue_flow.gd", "menu.gd", "run_world_session.gd", "steam_cloud.gd",
    "run_campaign_cfg_transaction.gd", "run_campaign_cfg_values.gd", "run_campaign_local_lifecycle.gd",
    "run_campaign_progress_coordinator.gd", "run_campaign_progress_gate.gd", "run_campaign_progress_intent.gd",
    "run_campaign_progress_projection.gd", "run_campaign_startup_scan.gd",
    "steam_run_receipt.gd", "steam_receipt_store.gd", "steam_run_ledger.gd",
    "steam_local_run_session.gd", "steam_service.gd", "run_campaign_legacy_data.gd",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, default=HERE / "handoff_candidate")
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    if not candidate.is_relative_to(HERE):
        raise RuntimeError("Candidate must remain inside this QA directory")
    helper.identity.no_links(candidate)
    manifest_path = candidate / "manifest.json"
    manifest = helper.read(manifest_path)
    rows = manifest["files"]
    if {r["path"] for r in rows} != {"scripts/" + name for name in FILES} or len(rows) != 20:
        raise RuntimeError("Exact twenty-file handoff candidate required")
    output = ROOT / ".godot/campaign_progress_recovery_20261026" / helper.stamp()
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    project.mkdir()
    receipt = {"schema": "campaign_handoff_overlay_preparation_v1", "complete": False, "project": str(project),
               "source_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
               "runner_sha256": helper.sha(__file__), "candidate_manifest_sha256": helper.sha(manifest_path),
               "production_modified": False, "candidate_qualified": False, "steps": []}
    pins = {str(manifest_path): helper.sha(manifest_path)}
    try:
        for row in rows:
            source = ROOT / row["path"]
            overlay = candidate / row["path"]
            helper.identity.no_links(source)
            helper.identity.no_links(overlay)
            base_hash = helper.sha(source) if source.exists() else None
            if base_hash != row["production_base_sha256"]:
                raise RuntimeError("Production base changed: " + row["path"])
            if helper.sha(overlay) != row["candidate_sha256"]:
                raise RuntimeError("Candidate changed: " + row["path"])
            pins[str(overlay)] = row["candidate_sha256"]
        print("PREPARE current production identity", flush=True)
        source = helper.identity.snapshot(ROOT)
        helper.save(output / "root_source.json", source)
        helper.copy_checked(manifest_path, output / "candidate_manifest.json", pins[str(manifest_path)])
        for name, present in source["directories"].items():
            if present and not name.startswith("@file/"):
                (project / name).mkdir(parents=True, exist_ok=True)
        last_notice = time.monotonic()
        for index, row in enumerate(source["files"], start=1):
            helper.copy_checked(ROOT / row["path"], project / row["path"], row["sha256"])
            if time.monotonic() - last_notice >= 25:
                print("COPY production %d/%d" % (index, len(source["files"])), flush=True)
                last_notice = time.monotonic()
        for row in rows:
            helper.copy_checked(candidate / row["path"], project / row["path"], row["candidate_sha256"])
        receipt["overlays"] = rows
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
        if helper.identity.snapshot(ROOT) != source:
            raise RuntimeError("Production changed during candidate preparation")
        helper.save(output / "preimport_source.json", helper.identity.snapshot(project))
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
