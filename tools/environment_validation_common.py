"""Portable locations and fail-closed report handling for environment QA."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LEGACY_DIRECTORY = Path("tools/contracts/environment/legacy")
LEGACY_BATCH = LEGACY_DIRECTORY / "environment_batch_manifest.json"
MAPPING = Path("tools/environment_production_mapping.template.json")
MAPPING_SHA256 = "af1204a50a865096be47917440a36c67d9290f295fd5ee1ac2f8e000b1d441f1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contained_path(repo: Path, relative: str) -> Path:
    """Reject absolute, drive, traversal and symlink escapes before reading."""
    if not isinstance(relative, str) or not relative or "\\" in relative or ":" in relative:
        raise ValueError(f"unsafe repository-relative path: {relative!r}")
    parts = PurePosixPath(relative)
    if parts.is_absolute() or ".." in parts.parts or "." == relative:
        raise ValueError(f"unsafe repository-relative path: {relative!r}")
    target = (repo / relative).resolve()
    target.relative_to(repo.resolve())
    return target


def report_target(repo: Path, path: Path) -> Path:
    """QA commands write disposable results, never production or historical QA."""
    target = path.resolve() if path.is_absolute() else (repo / path).resolve()
    relative = target.relative_to(repo.resolve())
    if len(relative.parts) < 2 or relative.parts[0] not in {".godot", "scratchpad"}:
        raise ValueError("report must stay below the selected repo's .godot/ or scratchpad/; copy reviewed evidence to qa/ separately")
    return target


def write_report(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def legacy_preflight(repo: Path = ROOT, batch: Path | None = None, *, require_router_report: bool = False) -> dict[str, Any]:
    """A missing historical input is a blocked test, never a skipped PASS."""
    manifest = batch or repo / LEGACY_BATCH
    requirements = [
        (manifest, "162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf"),
        (manifest.parent / "static_self_check.json", "f8e562d4aeebbd64519acf83ecfb54385742b3d7f89dd72684149a953386aa77"),
    ]
    if require_router_report:
        requirements.append((repo / "qa/environment_runtime_router_20260902/report.json",
                             "16dda6894bfc1bb54584ac90180de2227d6df6a34174192a6638fd8068405f43"))
    errors = []
    for path, expected in requirements:
        if not path.is_file():
            errors.append({"code": "missing_historical_input", "path": str(path), "expected_sha256": expected})
        elif sha256(path) != expected:
            errors.append({"code": "historical_sha256_mismatch", "path": str(path), "expected_sha256": expected, "actual_sha256": sha256(path)})
    if manifest.is_file() and sha256(manifest) == requirements[0][1]:
        for entry in json.loads(manifest.read_text(encoding="utf-8"))["send_order"]:
            path = contained_path(manifest.parent, entry["file"])
            if not path.is_file():
                errors.append({"code": "missing_reviewed_prompt", "path": str(path), "batch_id": entry["id"]})
            elif sha256(path) != entry["prompt_sha256"]:
                errors.append({"code": "prompt_sha256_mismatch", "path": str(path), "batch_id": entry["id"]})
    return {"passed": not errors, "status": "ready" if not errors else "blocked_missing_or_invalid_evidence", "errors": errors}
