"""Read-only binding for the explicit 23-script/native-helper Level4 candidate.

The original twenty-script hosts keep their adjacent-source validation branch.
This module neither prepares a project nor starts an engine, and imports no I/O
runner that may be frozen by another test.
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent
LIVENESS_SCHEMA = "campaign_liveness_integrated_manifest_v1"
LEGACY_SCHEMAS = {
    "campaign_steam_handoff_candidate_manifest_v1",
    "campaign_steam_store_protocol_integrated_manifest_v1",
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def repository_path(relative, helper):
    require(isinstance(relative, str) and helper.identity.relative_ok(relative),
            "Strict repository-relative candidate path required")
    path = ROOT / relative
    helper.identity.no_links(path)
    require(path.resolve().is_relative_to(ROOT), "Candidate source escaped the repository")
    return path


def bind_liveness(base, manifest_path, helper):
    """Bind an archived QA manifest to its exact prepared/imported full project."""
    helper.identity.no_links(base)
    helper.identity.no_links(manifest_path)
    require(base.is_relative_to(ROOT / ".godot/campaign_progress_recovery_20261026")
            and manifest_path.is_relative_to(QA), "Private freeze and QA manifest required")
    preparation_script = QA / "prepare_liveness.py"
    spec = importlib.util.spec_from_file_location("lianhuanma_liveness_preparation", preparation_script)
    prepare = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(prepare)
    expected, pins = prepare.preflight()
    manifest = helper.read(manifest_path)
    require(manifest.get("schema") == LIVENESS_SCHEMA and manifest == expected,
            "Requested manifest must equal the current strict 23-script/native candidate")
    require(len(manifest["files"]) == 23 and len(manifest["native_assets"]) == 1,
            "Exactly 23 candidate scripts and one native helper required")

    def pin(path, digest=None):
        helper.identity.no_links(path)
        actual = helper.sha(path)
        require(digest is None or actual == digest, "Candidate binding changed: " + str(path))
        pins[str(path)] = actual
        return actual

    manifest_sha = pin(manifest_path)
    pin(base / "candidate_manifest.json", manifest_sha)
    preparation = helper.read(base / "preparation.json")
    require(preparation.get("schema") == "campaign_liveness_preparation_v1"
            and preparation.get("complete") is True
            and preparation.get("candidate_manifest_sha256") == manifest_sha
            and preparation.get("overlays") == manifest["files"]
            and preparation.get("native_assets") == manifest["native_assets"],
            "Completed preparation must bind every script and native asset")
    project = helper.assert_runtime_current(base)
    require(project.resolve() == base / "project", "Prepared project path differs from selected freeze")
    generation = helper.read(base / "generation.json")
    helper.identity.verify_generated(project, generation)
    expected_identity = helper.read(base / "expected_identity.json")
    require(expected_identity == {key: value for key, value in generation["identity"].items()
                                  if key not in ("files", "directories")},
            "Expected identity differs from generated full identity")
    generated = {row["path"]: row for row in generation["identity"]["files"]}
    for row in manifest["files"] + manifest["native_assets"]:
        source = repository_path(row["source_path"], helper)
        require(helper.identity.relative_ok(row["path"]), "Invalid frozen member path")
        target = project / row["path"]
        require(row["path"] in generated and generated[row["path"]]["sha256"] == row["candidate_sha256"],
                "Full generated identity omits or changes candidate member: " + row["path"])
        pin(source, row["candidate_sha256"])
        pin(target, row["candidate_sha256"])
        if "candidate_bytes" in row:
            require(source.stat().st_size == target.stat().st_size == row["candidate_bytes"],
                    "Candidate byte count changed: " + row["path"])
    engine = helper.shared.resolve_godot(None)
    engine_sha = pin(engine)
    imported = []
    for receipt_path in sorted(base.glob("import__*/receipt.json")):
        imported_receipt = helper.read(receipt_path)
        steps = imported_receipt.get("steps", [])
        if (imported_receipt.get("complete") is True and imported_receipt.get("phase") == "import"
                and imported_receipt.get("project") == str(project)
                and imported_receipt.get("engine_sha256") == engine_sha
                and imported_receipt.get("lock_released") is True and len(steps) == 1
                and steps[0].get("exit_code") == 0 and steps[0].get("passed") is True
                and steps[0].get("errors") == [] and steps[0].get("stopped_for") is None):
            pin(receipt_path.parent / "import.log", steps[0]["log_sha256"])
            pin(receipt_path)
            imported.append(str(receipt_path))
    require(imported, "Successful terminal import for this full project and actual engine required")
    for path in (Path(__file__), preparation_script, manifest_path,
                 *(base / name for name in ("preparation.json", "root_source.json", "preimport_source.json",
                                            "generation.json", "expected_identity.json", "candidate_manifest.json"))):
        pin(path)
    helper.suite_verify_pins(pins)
    return {"project": project, "generation": generation, "engine": engine, "engine_sha256": engine_sha,
            "pins": pins, "candidate_manifest_sha256": manifest_sha, "candidate_schema": LIVENESS_SCHEMA,
            "candidate_script_count": 23, "native_asset_count": 1, "import_receipts": imported}
