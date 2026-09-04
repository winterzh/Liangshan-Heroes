"""Build a fail-closed, physically allowlisted release-candidate source tree.

This command never runs Godot, exports a build, or touches Steam.  Its default
mode is a read-only audit.  ``--commit`` copies only reviewed runtime inputs to
an empty staging directory outside the repository, using a same-volume
temporary directory and an adjacent SHA-256 manifest.

The export preset's exclude filters remain defense in depth.  They are not the
physical allowlist implemented here.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tempfile
import uuid
from typing import Any, Callable, Iterable


ROOT = Path(__file__).resolve().parents[1]
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")

CORE_FILES = (
    "project.godot",
    "export_presets.cfg",
    "icon.png",
    "icon.png.import",
    "icon.ico",
)
FORMAL_SCENES = (
    "scenes/menu.tscn",
    "scenes/main.tscn",
    "scenes/editor.tscn",
    "scenes/scenario_editor.tscn",
    "scenes/codex.tscn",
)
PRODUCTION_ROOT_PNG_NAMES = frozenset(
    {
        "buildings.png",
        "buildings2.png",
        "buildings3.png",
        "fx_ability_impacts.png",
        "fx_ability_projectiles.png",
        "fx_items.png",
        "fx_kit2.png",
        "objects.png",
        "portrait_gongsun_sheng.png",
        "portraits_sheet.png",
        "portraits2.png",
        "portraits3.png",
        "portraits4.png",
        "portraits5.png",
        "portraits6.png",
        "portraits7.png",
        "portraits8.png",
        "portraits9.png",
        "portraits10.png",
        "portraits11.png",
        "portraits12.png",
        "portraits13.png",
        "portraits14.png",
        "portraits15.png",
        "portraits16.png",
        "portraits17.png",
        "portraits18.png",
        "terrain_sheet.png",
        "terrain2.png",
        "tower_altar.png",
        "tower_arrow.png",
        "tower_caltrop.png",
        "tower_thunder.png",
        "traps.png",
        "units_sheet.png",
        "units2.png",
        "units3.png",
        "wards.png",
    }
)
RUNTIME_ASSET_DIRS = (
    "assets/anim",
    "assets/campaign/anim",
    "assets/campaign/objects",
    "assets/campaign/portraits",
    "assets/campaign/environment",
    "assets/vfx",
)
DYNAMIC_RESOURCE_PREFIXES = tuple(f"res://{item}/" for item in RUNTIME_ASSET_DIRS)
OPTIONAL_RESOURCE_PREFIXES = ("res://content/",)
RESOURCE_EXTENSIONS = {
    ".png",
    ".gd",
    ".gdshader",
    ".tscn",
    ".tres",
    ".res",
    ".wav",
    ".ogg",
    ".mp3",
    ".json",
    ".cfg",
}
FORBIDDEN_COMPONENTS = {
    "implementation_20260902",
    "qa",
    "docs",
    "tools",
    "source",
    "sources",
    "web_prompts_20260831",
    "web_prompts_20260901",
    "web_prompts_20260902",
    "__pycache__",
    "tests",
    "test",
    "prompts",
    "manifests",
    "cache",
    "fixtures",
    "build",
    ".godot",
}
FORBIDDEN_FILE_TOKENS = {
    "test",
    "tests",
    "qa",
    "fixture",
    "prompt",
    "prompts",
    "manifest",
    "checkpoint",
    "report",
}
ENVIRONMENT_ROUTER = "scripts/campaign_environment_art.gd"
ENVIRONMENT_PROVENANCE = "qa/environment_art_intake/environment_web_provenance.json"
DIRECTION_REPORT = "qa/campaign_direction4_coverage_20260902/report.json"
MANUAL_GATE = "qa/release_candidate_gate.json"
EXPECTED_ENVIRONMENT_PNGS = 69
EXPECTED_DIRECTION_ROWS = 347


class StagingError(RuntimeError):
    """A safety, completeness, provenance, or transaction failure."""


@dataclass(frozen=True)
class FileRecord:
    path: str
    size_bytes: int
    sha256: str


@dataclass
class Plan:
    source_root: Path
    staging: Path
    gate_manifest: Path
    records: tuple[FileRecord, ...]
    source_tree_sha256: str
    errors: list[str]
    metrics: dict[str, Any]
    gate_bindings: dict[str, str]

    @property
    def commit_ready(self) -> bool:
        return not self.errors


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def safe_rel_path(value: str) -> str:
    """Return one canonical repository-relative POSIX path or fail closed."""
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        raise StagingError(f"unsafe relative path: {value!r}")
    if ":" in value or re.match(r"^[A-Za-z]:", value) or value.startswith(("/", "//")):
        raise StagingError(f"absolute path is forbidden in candidate metadata: {value!r}")
    pure = PurePosixPath(value)
    if pure.is_absolute() or any(part in ("", ".", "..") for part in pure.parts):
        raise StagingError(f"path traversal is forbidden: {value!r}")
    normalized = pure.as_posix()
    if normalized != value:
        raise StagingError(f"path is not canonical POSIX relative form: {value!r}")
    return normalized


def _inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def _assert_file_safe(root: Path, relative: str) -> Path:
    relative = safe_rel_path(relative)
    candidate = root.joinpath(*PurePosixPath(relative).parts)
    resolved_root = root.resolve()
    resolved = candidate.resolve(strict=False)
    if not _inside(resolved, resolved_root):
        raise StagingError(f"source path escapes the repository: {relative}")
    cursor = candidate
    while cursor != root:
        if cursor.is_symlink():
            raise StagingError(f"symbolic links and junction-like path redirects are forbidden: {relative}")
        cursor = cursor.parent
    if not candidate.is_file():
        raise StagingError(f"required candidate input is missing: {relative}")
    return candidate


def _file_tokens(relative: str) -> set[str]:
    stem = PurePosixPath(relative).name.lower()
    return {item for item in re.split(r"[^a-z0-9]+", stem) if item}


def assert_no_forbidden_selected(paths: Iterable[str]) -> list[str]:
    errors: list[str] = []
    for raw in paths:
        try:
            relative = safe_rel_path(raw)
        except StagingError as error:
            errors.append(str(error))
            continue
        pure = PurePosixPath(relative)
        lowered_parts = {part.lower() for part in pure.parts}
        prefixed_development = any(
            part.lower().startswith(("implementation", "web_prompt", "__pycache__"))
            for part in pure.parts
        )
        if lowered_parts & FORBIDDEN_COMPONENTS or prefixed_development:
            errors.append(f"development path entered the physical allowlist: {relative}")
        if "_raw" in pure.name.lower() or pure.suffix.lower() in {".pyc", ".pyo"}:
            errors.append(f"raw/cache file entered the physical allowlist: {relative}")
        if _file_tokens(relative) & FORBIDDEN_FILE_TOKENS:
            errors.append(f"test/evidence file entered the physical allowlist: {relative}")
        if pure.suffix.lower() in {".json", ".md", ".txt", ".py", ".ps1", ".log"}:
            errors.append(f"development document or manifest entered the physical allowlist: {relative}")
    return errors


def _walk_selected_files(root: Path, relative_dir: str, suffixes: tuple[str, ...]) -> tuple[list[str], list[str]]:
    selected: list[str] = []
    errors: list[str] = []
    directory = root / relative_dir
    if not directory.is_dir():
        return selected, [f"required runtime directory is missing: {relative_dir}"]
    for current, dirnames, filenames in os.walk(directory, followlinks=False):
        current_path = Path(current)
        for dirname in list(dirnames):
            child = current_path / dirname
            if child.is_symlink():
                rel = child.relative_to(root).as_posix()
                errors.append(f"symbolic directory is forbidden in an allowlisted tree: {rel}")
                dirnames.remove(dirname)
        for filename in filenames:
            child = current_path / filename
            rel = child.relative_to(root).as_posix()
            if child.is_symlink():
                errors.append(f"symbolic file is forbidden in an allowlisted tree: {rel}")
                continue
            if filename.endswith(suffixes):
                selected.append(rel)
    return selected, errors


def collect_allowlist(source_root: Path) -> tuple[list[str], list[str]]:
    root = source_root.resolve()
    selected: set[str] = set()
    errors: list[str] = []

    def require(relative: str) -> None:
        try:
            _assert_file_safe(root, relative)
            selected.add(safe_rel_path(relative))
        except StagingError as error:
            errors.append(str(error))

    for relative in CORE_FILES + FORMAL_SCENES:
        require(relative)

    script_files, script_errors = _walk_selected_files(
        root, "scripts", (".gd", ".gdshader", ".gd.uid", ".gdshader.uid")
    )
    selected.update(script_files)
    errors.extend(script_errors)
    if not any(path.endswith(".gdshader") for path in script_files):
        errors.append("no production shader was selected from scripts/")

    assets_root = root / "assets"
    if not assets_root.is_dir():
        errors.append("required runtime directory is missing: assets")
    else:
        discovered = {
            item.name
            for item in assets_root.glob("*.png")
            if item.is_file() and "_raw" not in item.name.lower()
        }
        unreviewed = sorted(discovered - PRODUCTION_ROOT_PNG_NAMES)
        missing_reviewed = sorted(PRODUCTION_ROOT_PNG_NAMES - discovered)
        if unreviewed:
            errors.append("unreviewed root production PNGs are outside the fixed allowlist: " + ", ".join(unreviewed))
        if missing_reviewed:
            errors.append("fixed root production PNGs are missing: " + ", ".join(missing_reviewed))
        for name in sorted(PRODUCTION_ROOT_PNG_NAMES):
            require(f"assets/{name}")
            require(f"assets/{name}.import")

    for relative_dir in RUNTIME_ASSET_DIRS:
        files, walk_errors = _walk_selected_files(root, relative_dir, (".png", ".png.import"))
        selected.update(files)
        errors.extend(walk_errors)
        pngs = {path for path in files if path.endswith(".png")}
        imports = {path.removesuffix(".import") for path in files if path.endswith(".png.import")}
        for missing_import in sorted(pngs - imports):
            errors.append(f"runtime PNG has no frozen Godot import sidecar: {missing_import}.import")
        for orphan in sorted(imports - pngs):
            errors.append(f"orphan PNG import sidecar has no source PNG: {orphan}.import")

    errors.extend(assert_no_forbidden_selected(selected))
    return sorted(selected), errors


QUOTED_RES_RE = re.compile(r"(?P<quote>[\"'])(?P<path>res://[^\"'\r\n]+)(?P=quote)")


def scan_runtime_references(source_root: Path, selected: set[str]) -> list[str]:
    """Catch concrete and formatted runtime loads that the allowlist missed."""
    errors: list[str] = []
    scan_paths = [
        path for path in selected
        if path == "project.godot"
        or path.endswith((".gd", ".gdshader", ".tscn"))
    ]
    for relative in sorted(scan_paths):
        source = source_root.joinpath(*PurePosixPath(relative).parts)
        try:
            text = source.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            errors.append(f"could not inspect runtime references in {relative}: {error}")
            continue
        for match in QUOTED_RES_RE.finditer(text):
            resource = match.group("path")
            if resource.startswith(OPTIONAL_RESOURCE_PREFIXES):
                continue
            if "%" in resource or "{" in resource or "<" in resource:
                if not resource.startswith(DYNAMIC_RESOURCE_PREFIXES):
                    line = text.count("\n", 0, match.start()) + 1
                    errors.append(f"uncovered dynamic resource pattern at {relative}:{line}: {resource}")
                continue
            suffix = PurePosixPath(resource).suffix.lower()
            if suffix not in RESOURCE_EXTENSIONS:
                continue
            try:
                candidate = safe_rel_path(resource.removeprefix("res://"))
            except StagingError as error:
                errors.append(f"unsafe runtime reference in {relative}: {error}")
                continue
            if candidate not in selected:
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"runtime reference is absent from the physical allowlist at {relative}:{line}: {candidate}")
    return errors


WINDOWS_ABSOLUTE_RE = re.compile(r"(?<![A-Za-z0-9_])[A-Za-z]:[\\/]")


def scan_forbidden_absolute_paths(source_root: Path, selected: set[str]) -> list[str]:
    errors: list[str] = []
    text_suffixes = (".gd", ".gdshader", ".tscn", ".godot", ".cfg", ".import", ".uid")
    for relative in sorted(path for path in selected if path.endswith(text_suffixes)):
        path = source_root.joinpath(*PurePosixPath(relative).parts)
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as error:
            errors.append(f"could not inspect candidate text file for absolute paths: {relative}: {error}")
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            if WINDOWS_ABSOLUTE_RE.search(line) or "file://" in line.lower():
                errors.append(f"local absolute path is forbidden in candidate input: {relative}:{line_number}")
    return errors


def build_records(source_root: Path, selected: Iterable[str]) -> tuple[tuple[FileRecord, ...], list[str]]:
    records: list[FileRecord] = []
    errors: list[str] = []
    for relative in sorted(set(selected)):
        try:
            path = _assert_file_safe(source_root, relative)
            records.append(FileRecord(relative, path.stat().st_size, sha256_file(path)))
        except (OSError, StagingError) as error:
            errors.append(str(error))
    return tuple(records), errors


def tree_sha256(records: Iterable[FileRecord]) -> str:
    digest = hashlib.sha256()
    for record in sorted(records, key=lambda item: item.path):
        digest.update(record.path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(record.sha256.encode("ascii"))
        digest.update(b"\0")
        digest.update(str(record.size_bytes).encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def verify_records(root: Path, records: Iterable[FileRecord]) -> list[str]:
    errors: list[str] = []
    for record in records:
        try:
            path = _assert_file_safe(root, record.path)
            if path.stat().st_size != record.size_bytes or sha256_file(path) != record.sha256:
                errors.append(f"source SHA changed after planning: {record.path}")
        except (OSError, StagingError) as error:
            errors.append(f"source changed after planning: {record.path}: {error}")
    return errors


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise StagingError(f"{label} is missing: {path}") from error
    except json.JSONDecodeError as error:
        raise StagingError(f"{label} is invalid JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise StagingError(f"{label} must contain one JSON object: {path}")
    return value


def expect_sha(value: Any, label: str) -> str:
    result = str(value).strip().lower()
    if SHA256_RE.fullmatch(result) is None:
        raise StagingError(f"{label} is not a lowercase SHA-256 digest")
    return result


def environment_paths(source_root: Path) -> tuple[set[str], list[str]]:
    errors: list[str] = []
    try:
        router = _assert_file_safe(source_root, ENVIRONMENT_ROUTER)
    except StagingError as error:
        return set(), [str(error)]
    text = router.read_text(encoding="utf-8")
    paths = {
        match.group(1).removeprefix("res://")
        for match in re.finditer(r'"(res://assets/campaign/environment/[^"\r\n]+\.png)"', text)
    }
    if len(paths) != EXPECTED_ENVIRONMENT_PNGS:
        errors.append(
            f"environment router registers {len(paths)}/{EXPECTED_ENVIRONMENT_PNGS} unique runtime PNGs"
        )
    for path in sorted(paths):
        try:
            safe_rel_path(path)
        except StagingError as error:
            errors.append(str(error))
    return paths, errors


def _all_bool_reviews_true(review: Any) -> bool:
    if not isinstance(review, dict):
        return False
    flags = [value for value in review.values() if isinstance(value, bool)]
    return len(flags) >= 4 and all(flags)


def validate_environment_gate(source_root: Path, selected: set[str]) -> tuple[list[str], dict[str, Any], str]:
    errors: list[str] = []
    expected, path_errors = environment_paths(source_root)
    errors.extend(path_errors)
    present = {path for path in expected if (source_root / path).is_file()}
    selected_expected = expected & selected
    metrics: dict[str, Any] = {
        "registered": len(expected),
        "present": len(present),
        "allowlisted": len(selected_expected),
        "provenance_matched": 0,
        "required": EXPECTED_ENVIRONMENT_PNGS,
    }
    if len(present) != EXPECTED_ENVIRONMENT_PNGS:
        errors.append(f"environment runtime PNG gate failed: {len(present)}/{EXPECTED_ENVIRONMENT_PNGS} present")
    if len(selected_expected) != EXPECTED_ENVIRONMENT_PNGS:
        errors.append(
            f"environment physical allowlist gate failed: {len(selected_expected)}/{EXPECTED_ENVIRONMENT_PNGS} selected"
        )

    try:
        ledger_path = _assert_file_safe(source_root, ENVIRONMENT_PROVENANCE)
    except StagingError:
        errors.append(f"environment provenance ledger is missing: {ENVIRONMENT_PROVENANCE}")
        return errors, metrics, ""
    ledger_sha = sha256_file(ledger_path)
    try:
        ledger = load_json(ledger_path, "environment provenance ledger")
        if ledger.get("schema_version") != 1 or ledger.get("kind") != "web_chatgpt_environment_provenance":
            raise StagingError("environment provenance ledger has an incompatible schema/kind")
        records = ledger.get("records")
        if not isinstance(records, list):
            raise StagingError("environment provenance ledger records must be an array")
    except StagingError as error:
        errors.append(str(error))
        return errors, metrics, ledger_sha

    matches: dict[str, set[tuple[str, str, str]]] = {path: set() for path in expected}
    for index, record in enumerate(records):
        if not isinstance(record, dict) or record.get("decision") != "adopt":
            continue
        if record.get("objective_pass") is not True or not _all_bool_reviews_true(record.get("human_review")):
            continue
        try:
            source_sha = expect_sha(record.get("source_sha256"), f"environment record {index} source_sha256")
            prompt_sha = expect_sha(record.get("prompt_sha256"), f"environment record {index} prompt_sha256")
            source_manifest_sha = expect_sha(
                record.get("source_manifest_sha256"), f"environment record {index} source_manifest_sha256"
            )
            conversation = str(record.get("conversation_url", ""))
            if not conversation.startswith("https://chatgpt.com/c/"):
                raise StagingError(f"environment record {index} lacks a stable ChatGPT conversation URL")
            source_archive = safe_rel_path(str(record.get("source_archive", "")))
            prompt_archive = safe_rel_path(str(record.get("prompt_archive", "")))
            if not source_archive.startswith("qa/environment_art_intake/archive/"):
                raise StagingError(f"environment record {index} source archive leaves the immutable archive")
            if not prompt_archive.startswith("qa/environment_art_intake/archive/"):
                raise StagingError(f"environment record {index} prompt archive leaves the immutable archive")
            source_file = _assert_file_safe(source_root, source_archive)
            prompt_file = _assert_file_safe(source_root, prompt_archive)
            if sha256_file(source_file) != source_sha or sha256_file(prompt_file) != prompt_sha:
                raise StagingError(f"environment record {index} source/prompt archive SHA drifted")
            source_manifest_archive = (
                source_root
                / "qa/environment_art_intake/archive/manifests"
                / f"sources_{source_manifest_sha[:16]}.json"
            )
            if not source_manifest_archive.is_file() or sha256_file(source_manifest_archive) != source_manifest_sha:
                raise StagingError(f"environment record {index} has no hash-matching archived source manifest")
            outputs = record.get("outputs")
            if not isinstance(outputs, list):
                raise StagingError(f"environment record {index} outputs must be an array")
            for output in outputs:
                if not isinstance(output, dict):
                    continue
                target = str(output.get("target", "")).removeprefix("res://")
                if target not in expected:
                    continue
                output_sha = expect_sha(output.get("output_sha256"), f"environment output {target}")
                if expect_sha(output.get("source_sha256"), f"environment output {target} source SHA") != source_sha:
                    raise StagingError(f"environment output {target} is bound to a different source SHA")
                runtime = source_root / target
                if runtime.is_file() and sha256_file(runtime) == output_sha:
                    matches[target].add((source_sha, output_sha, source_manifest_sha))
        except (OSError, StagingError) as error:
            errors.append(str(error))

    for target, identities in sorted(matches.items()):
        if len(identities) == 0:
            errors.append(f"environment PNG lacks matching source-manifest provenance: {target}")
        elif len(identities) > 1:
            errors.append(f"environment PNG provenance is ambiguous across accepted sources: {target}")
    metrics["provenance_matched"] = sum(len(items) == 1 for items in matches.values())
    return errors, metrics, ledger_sha


def validate_direction_gate(source_root: Path, selected: set[str]) -> tuple[list[str], dict[str, Any], str]:
    errors: list[str] = []
    report_path = source_root / DIRECTION_REPORT
    metrics: dict[str, Any] = {"accepted": 0, "required": EXPECTED_DIRECTION_ROWS, "expected_pngs": 0}
    try:
        report_path = _assert_file_safe(source_root, DIRECTION_REPORT)
    except StagingError:
        return [f"strict four-direction report is missing: {DIRECTION_REPORT}"], metrics, ""
    report_sha = sha256_file(report_path)
    try:
        report = load_json(report_path, "strict four-direction report")
        if report.get("schema_version") != 1 or report.get("audit_kind") != "static_read_only_campaign_direction4_exact_coverage":
            raise StagingError("strict four-direction report has an incompatible schema/kind")
        claimed = expect_sha(report.get("deterministic_payload_sha256"), "direction report deterministic payload SHA")
        canonical_payload = dict(report)
        canonical_payload.pop("deterministic_payload_sha256", None)
        actual = sha256_bytes(
            json.dumps(canonical_payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
        )
        if actual != claimed:
            raise StagingError("strict four-direction report deterministic payload SHA is invalid")
        input_hashes = report.get("input_sha256")
        if not isinstance(input_hashes, dict) or not input_hashes:
            raise StagingError("strict four-direction report has no frozen input SHA map")
        for relative, expected_sha in sorted(input_hashes.items()):
            rel = safe_rel_path(str(relative))
            expected = expect_sha(expected_sha, f"direction input {rel}")
            path = _assert_file_safe(source_root, rel)
            if sha256_file(path) != expected:
                errors.append(f"strict four-direction report is stale because input SHA drifted: {rel}")
        summary = report.get("summary")
        rows = report.get("unique_art_state_contract")
        if not isinstance(summary, dict) or not isinstance(rows, list):
            raise StagingError("strict four-direction report lacks summary/contract rows")
        accepted = int(summary.get("accepted_exact_unique_rows", -1))
        required = int(summary.get("unique_art_state_rows", -1))
        metrics["accepted"] = accepted
        metrics["required"] = required
        if required != EXPECTED_DIRECTION_ROWS or len(rows) != EXPECTED_DIRECTION_ROWS:
            errors.append(
                f"strict four-direction contract size changed: summary={required}, rows={len(rows)}, expected={EXPECTED_DIRECTION_ROWS}"
            )
        if accepted != EXPECTED_DIRECTION_ROWS:
            errors.append(f"strict four-direction coverage gate failed: {accepted}/{EXPECTED_DIRECTION_ROWS} accepted")
        if int(summary.get("existing_four_direction_rows_requiring_web_regeneration_for_provenance", -1)) != 0:
            errors.append("strict four-direction report still has noncompliant-provenance rows")
        if int(summary.get("missing_or_partial_exact_rows_requiring_web_generation", -1)) != 0:
            errors.append("strict four-direction report still has missing/partial rows")
        expected_paths: set[str] = set()
        absent_from_allowlist: list[str] = []
        missing_runtime_pngs: list[str] = []
        noncompliant_rows: list[int] = []
        malformed_path_rows: list[int] = []
        for index, row in enumerate(rows):
            if not isinstance(row, dict):
                errors.append(f"direction contract row {index} is not an object")
                continue
            if (
                row.get("accepted_exact_four_direction") is not True
                or row.get("coverage_status") != "exact_provenance_compliant"
                or row.get("provenance_compliant") is not True
            ):
                noncompliant_rows.append(index)
            paths = row.get("expected_paths")
            if not isinstance(paths, list) or len(paths) != 4:
                malformed_path_rows.append(index)
                continue
            for raw in paths:
                rel = safe_rel_path(str(raw))
                expected_paths.add(rel)
                if rel not in selected:
                    absent_from_allowlist.append(rel)
                elif not (source_root / rel).is_file():
                    missing_runtime_pngs.append(rel)
        if noncompliant_rows:
            errors.append(
                "strict four-direction rows are not exact/provenance-compliant: "
                f"{len(noncompliant_rows)}/{len(rows)}; first indices {noncompliant_rows[:12]}"
            )
        if malformed_path_rows:
            errors.append(
                "strict four-direction rows lack exactly four paths: "
                f"{len(malformed_path_rows)}/{len(rows)}; first indices {malformed_path_rows[:12]}"
            )
        if absent_from_allowlist:
            errors.append(
                "strict four-direction PNGs are absent from the physical allowlist: "
                f"{len(set(absent_from_allowlist))}; first paths {sorted(set(absent_from_allowlist))[:8]}"
            )
        if missing_runtime_pngs:
            errors.append(
                "strict four-direction runtime PNGs are missing: "
                f"{len(set(missing_runtime_pngs))}; first paths {sorted(set(missing_runtime_pngs))[:8]}"
            )
        metrics["expected_pngs"] = len(expected_paths)
    except (OSError, StagingError, TypeError, ValueError) as error:
        errors.append(str(error))
    return errors, metrics, report_sha


def validate_manual_gate(
    source_root: Path,
    gate_path: Path,
    source_tree_sha: str,
    direction_report_sha: str,
    environment_provenance_sha: str,
) -> tuple[list[str], str]:
    errors: list[str] = []
    if not gate_path.is_file():
        return [f"frozen-source/manual release gate is missing: {gate_path.relative_to(source_root).as_posix() if _inside(gate_path, source_root) else gate_path.name}"], ""
    gate_sha = ""
    try:
        gate_relative = gate_path.relative_to(source_root).as_posix()
        gate_path = _assert_file_safe(source_root, gate_relative)
        gate_sha = sha256_file(gate_path)
        gate = load_json(gate_path, "frozen-source/manual release gate")
        if gate.get("schema_version") != 1 or gate.get("kind") != "liangshan_release_candidate_gate":
            raise StagingError("frozen-source/manual release gate has an incompatible schema/kind")
        required_true = ("source_freeze_complete", "manual_review_complete", "approved_for_staging")
        for field in required_true:
            if gate.get(field) is not True:
                errors.append(f"release gate field is not true: {field}")
        if expect_sha(gate.get("allowlist_tree_sha256"), "release gate allowlist_tree_sha256") != source_tree_sha:
            errors.append("release gate was approved for a different physical-allowlist source tree")
        if expect_sha(gate.get("direction_report_sha256"), "release gate direction_report_sha256") != direction_report_sha:
            errors.append("release gate direction report SHA does not match the current strict report")
        if expect_sha(gate.get("environment_provenance_sha256"), "release gate environment_provenance_sha256") != environment_provenance_sha:
            errors.append("release gate environment provenance SHA does not match the current ledger")
        reviewer = str(gate.get("reviewer", "")).strip()
        reviewed_at = str(gate.get("reviewed_at", "")).strip()
        if not reviewer or not reviewed_at:
            errors.append("release gate must record reviewer and reviewed_at")
        evidence = gate.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            errors.append("release gate must bind at least one manually reviewed evidence file")
        else:
            for index, item in enumerate(evidence):
                if not isinstance(item, dict):
                    errors.append(f"release gate evidence {index} is not an object")
                    continue
                rel = safe_rel_path(str(item.get("path", "")))
                if not rel.startswith("qa/"):
                    errors.append(f"release gate evidence must remain under excluded qa/: {rel}")
                    continue
                expected = expect_sha(item.get("sha256"), f"release gate evidence {index} SHA")
                evidence_path = _assert_file_safe(source_root, rel)
                if sha256_file(evidence_path) != expected:
                    errors.append(f"release gate evidence SHA drifted: {rel}")
    except (OSError, StagingError) as error:
        errors.append(str(error))
    return errors, gate_sha


def validate_staging_target(source_root: Path, staging: Path) -> list[str]:
    errors: list[str] = []
    root = source_root.resolve()
    target = staging.resolve(strict=False)
    if _inside(target, root) or _inside(root, target):
        errors.append("staging directory must be physically outside the source repository")
    if any(part.casefold() == "steamworks" for part in target.parts):
        errors.append("staging directly inside a Steamworks tree is forbidden")
    if staging.is_symlink():
        errors.append("staging directory may not be a symbolic link")
    if staging.exists():
        if not staging.is_dir():
            errors.append("staging target exists and is not a directory")
        else:
            try:
                if any(staging.iterdir()):
                    errors.append("staging target must be empty")
            except OSError as error:
                errors.append(f"could not inspect staging target: {error}")
    parent = target.parent
    if not parent.exists() or not parent.is_dir():
        errors.append("staging parent directory must already exist")
    elif parent.is_symlink():
        errors.append("staging parent directory may not be a symbolic link")
    sidecar = target.with_name(target.name + ".manifest.json")
    if sidecar.exists():
        errors.append(f"candidate manifest sidecar already exists: {sidecar.name}")
    return errors


def validate_export_preset_patch(source_root: Path) -> list[str]:
    path = source_root / "export_presets.cfg"
    if not path.is_file():
        return ["export_presets.cfg is missing"]
    text = path.read_text(encoding="utf-8")
    errors: list[str] = []
    if text.count("implementation_20260902/*") < 2:
        errors.append("Windows/macOS exclude_filter lacks implementation_20260902/* defense-in-depth entries")
    if text.count("**/__pycache__/*") < 2:
        errors.append("Windows/macOS exclude_filter lacks **/__pycache__/* defense-in-depth entries")
    return errors


def build_plan(source_root: Path, staging: Path, gate_manifest: Path | None = None) -> Plan:
    root = source_root.resolve()
    target = staging.resolve(strict=False)
    errors = validate_staging_target(root, target)
    errors.extend(validate_export_preset_patch(root))
    selected_list, allowlist_errors = collect_allowlist(root)
    errors.extend(allowlist_errors)
    selected = set(selected_list)
    errors.extend(scan_runtime_references(root, selected))
    errors.extend(scan_forbidden_absolute_paths(root, selected))
    records, record_errors = build_records(root, selected)
    errors.extend(record_errors)
    source_tree = tree_sha256(records)

    environment_errors, environment_metrics, environment_sha = validate_environment_gate(root, selected)
    direction_errors, direction_metrics, direction_sha = validate_direction_gate(root, selected)
    errors.extend(environment_errors)
    errors.extend(direction_errors)

    gate = gate_manifest.resolve(strict=False) if gate_manifest is not None else root / MANUAL_GATE
    if not _inside(gate, root):
        errors.append("manual gate manifest must stay inside the source repository")
        gate_sha = ""
    else:
        manual_errors, gate_sha = validate_manual_gate(
            root, gate, source_tree, direction_sha, environment_sha
        )
        errors.extend(manual_errors)

    errors.extend(verify_records(root, records))
    metrics = {
        "selected_file_count": len(records),
        "selected_bytes": sum(record.size_bytes for record in records),
        "environment": environment_metrics,
        "direction4": direction_metrics,
        "selected_by_top_level": dict(Counter(record.path.split("/", 1)[0] for record in records)),
    }
    bindings = {
        "direction_report_sha256": direction_sha,
        "environment_provenance_sha256": environment_sha,
        "manual_gate_sha256": gate_sha,
    }
    return Plan(root, target, gate, records, source_tree, sorted(set(errors)), metrics, bindings)


def revalidate_plan_inputs(plan: Plan) -> list[str]:
    """Re-run every source and evidence gate around the atomic copy boundary."""
    errors = verify_records(plan.source_root, plan.records)
    errors.extend(validate_export_preset_patch(plan.source_root))
    selected = {record.path for record in plan.records}
    environment_errors, _environment_metrics, environment_sha = validate_environment_gate(
        plan.source_root, selected
    )
    direction_errors, _direction_metrics, direction_sha = validate_direction_gate(
        plan.source_root, selected
    )
    errors.extend(environment_errors)
    errors.extend(direction_errors)
    manual_errors, gate_sha = validate_manual_gate(
        plan.source_root,
        plan.gate_manifest,
        plan.source_tree_sha256,
        direction_sha,
        environment_sha,
    )
    errors.extend(manual_errors)
    observed = {
        "direction_report_sha256": direction_sha,
        "environment_provenance_sha256": environment_sha,
        "manual_gate_sha256": gate_sha,
    }
    if observed != plan.gate_bindings:
        errors.append("release evidence SHA bindings changed after planning")
    return sorted(set(errors))


def public_report(plan: Plan, *, include_files: bool = False) -> dict[str, Any]:
    report: dict[str, Any] = {
        "schema_version": 1,
        "kind": "release_candidate_physical_allowlist_dry_run",
        "dry_run": True,
        "committed": False,
        "commit_ready": plan.commit_ready,
        "source_tree_sha256": plan.source_tree_sha256,
        "metrics": plan.metrics,
        "gate_bindings": plan.gate_bindings,
        "errors": plan.errors,
        "boundary": {
            "runs_godot": False,
            "exports_build": False,
            "touches_steam": False,
            "candidate_target_outside_repository": not _inside(plan.staging, plan.source_root)
            and not _inside(plan.source_root, plan.staging),
            "manifest_is_adjacent_not_packaged": True,
            "export_exclude_filters_are_only_defense_in_depth": True,
        },
    }
    if include_files:
        report["files"] = [record.__dict__ for record in plan.records]
    return report


def _candidate_manifest(plan: Plan) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "kind": "release_candidate_physical_allowlist_manifest",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "platform": "windows",
        "source_tree_sha256": plan.source_tree_sha256,
        "file_count": len(plan.records),
        "total_bytes": sum(record.size_bytes for record in plan.records),
        "gate_bindings": plan.gate_bindings,
        "files": [record.__dict__ for record in plan.records],
        "excluded_by_construction": [
            "implementation",
            "qa",
            "docs",
            "tools",
            "source artwork",
            "prompts",
            "web-session manifests",
            "raw PNGs",
            "cache files",
            "tests",
        ],
    }


def _copy_to_temporary(plan: Plan, temporary: Path) -> None:
    for record in plan.records:
        source = _assert_file_safe(plan.source_root, record.path)
        target = temporary.joinpath(*PurePosixPath(record.path).parts)
        resolved = target.resolve(strict=False)
        if not _inside(resolved, temporary.resolve()):
            raise StagingError(f"candidate target escaped the temporary directory: {record.path}")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target, follow_symlinks=False)
        if target.stat().st_size != record.size_bytes or sha256_file(target) != record.sha256:
            raise StagingError(f"staged file hash mismatch: {record.path}")
    staged_files = sorted(
        path.relative_to(temporary).as_posix()
        for path in temporary.rglob("*")
        if path.is_file()
    )
    expected = [record.path for record in plan.records]
    if staged_files != expected:
        raise StagingError("temporary candidate contains files outside the physical allowlist")
    dynamic_errors = scan_runtime_references(temporary, set(expected))
    if dynamic_errors:
        raise StagingError("staged runtime reference check failed: " + "; ".join(dynamic_errors))


def _replace_path(source: Path, destination: Path) -> None:
    os.replace(source, destination)


def commit_staging(
    plan: Plan,
    *,
    after_install: Callable[[], None] | None = None,
    replace_path: Callable[[Path, Path], None] = _replace_path,
    revalidator: Callable[[Plan], list[str]] = revalidate_plan_inputs,
) -> dict[str, Any]:
    if not plan.commit_ready:
        raise StagingError("--commit refused because one or more fail-closed gates did not pass")
    target_errors = validate_staging_target(plan.source_root, plan.staging)
    if target_errors:
        raise StagingError("; ".join(target_errors))
    drift = revalidator(plan)
    if drift:
        raise StagingError("; ".join(drift))

    target = plan.staging
    parent = target.parent
    sidecar = target.with_name(target.name + ".manifest.json")
    lock = parent / f".{target.name}.staging.lock"
    try:
        descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as error:
        raise StagingError(f"another candidate staging transaction may be active: {lock.name}") from error
    try:
        os.write(descriptor, f"pid={os.getpid()}\n".encode("ascii"))
    finally:
        os.close(descriptor)
    temporary: Path | None = None
    sidecar_tmp = parent / f".{sidecar.name}.{uuid.uuid4().hex}.tmp"
    backup: Path | None = None
    target_installed = False
    sidecar_installed = False
    try:
        temporary = Path(tempfile.mkdtemp(prefix=f".{target.name}.tmp_", dir=parent))
        _copy_to_temporary(plan, temporary)
        drift = revalidator(plan)
        if drift:
            raise StagingError("; ".join(drift))
        manifest_payload = (
            json.dumps(_candidate_manifest(plan), ensure_ascii=False, indent=2) + "\n"
        ).encode("utf-8")
        sidecar_tmp.write_bytes(manifest_payload)
        if sha256_file(sidecar_tmp) != sha256_bytes(manifest_payload):
            raise StagingError("candidate manifest temporary SHA mismatch")

        if target.exists():
            backup = parent / f".{target.name}.empty_{uuid.uuid4().hex}.bak"
            replace_path(target, backup)
        replace_path(temporary, target)
        target_installed = True
        if after_install is not None:
            after_install()
        replace_path(sidecar_tmp, sidecar)
        sidecar_installed = True
        drift = revalidator(plan)
        if drift:
            raise StagingError("; ".join(drift))
        if backup is not None:
            backup.rmdir()
            backup = None
    except Exception as error:
        rollback_errors: list[str] = []
        try:
            if sidecar_installed and sidecar.exists():
                sidecar.unlink()
            if target_installed and target.exists():
                shutil.rmtree(target)
            if backup is not None and backup.exists():
                replace_path(backup, target)
                backup = None
        except Exception as rollback_error:
            rollback_errors.append(str(rollback_error))
        if temporary is not None:
            shutil.rmtree(temporary, ignore_errors=True)
        if sidecar_tmp.exists():
            sidecar_tmp.unlink()
        if backup is not None and backup.exists():
            rollback_errors.append(f"empty staging backup remains at {backup}")
        if rollback_errors:
            raise StagingError(
                f"candidate staging failed ({error}); rollback was incomplete: {'; '.join(rollback_errors)}"
            ) from error
        raise StagingError(f"candidate staging failed and was rolled back: {error}") from error
    finally:
        if temporary is not None and temporary.exists():
            shutil.rmtree(temporary, ignore_errors=True)
        if sidecar_tmp.exists():
            sidecar_tmp.unlink()
        if lock.exists():
            lock.unlink()

    return {
        "schema_version": 1,
        "kind": "release_candidate_physical_allowlist_commit",
        "committed": True,
        "staged_file_count": len(plan.records),
        "source_tree_sha256": plan.source_tree_sha256,
        "manifest_name": sidecar.name,
        "manifest_sha256": sha256_file(sidecar),
        "runs_godot": False,
        "exports_build": False,
        "touches_steam": False,
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", required=True, type=Path, help="empty or absent staging directory outside the repository")
    parser.add_argument("--source-root", type=Path, default=ROOT, help=argparse.SUPPRESS)
    parser.add_argument("--gate-manifest", type=Path, help="defaults to qa/release_candidate_gate.json")
    parser.add_argument("--show-files", action="store_true", help="include every allowlisted file/hash in dry-run JSON")
    parser.add_argument("--commit", action="store_true", help="atomically create the staging tree after every gate passes")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    source_root = args.source_root.resolve()
    gate = args.gate_manifest
    if gate is not None and not gate.is_absolute():
        gate = source_root / gate
    plan = build_plan(source_root, args.staging, gate)
    report = public_report(plan, include_files=args.show_files)
    if not args.commit:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    if not plan.commit_ready:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        print("commit refused: fail-closed release gates did not pass", file=sys.stderr)
        return 2
    try:
        result = commit_staging(plan)
    except StagingError as error:
        print(json.dumps({**report, "commit_error": str(error)}, ensure_ascii=False, indent=2))
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
