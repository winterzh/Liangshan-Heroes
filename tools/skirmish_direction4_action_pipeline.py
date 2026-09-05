"""Safely stage and promote the four-unit skirmish direction-action batch.

The four reviewed source atlases are native RGBA PNGs arranged as four rows
(guan_dao, guan_gong, guan_jingqi, guan_qi) and four columns
(SE, SW, NE, NW).  This tool deliberately has a very small image-processing
surface: one alpha>0 rectangular crop per cell, one uniform LANCZOS scale per
unit across all 16 action poses/directions, and unmasked paste onto a transparent 256x256 canvas.  It never
mirrors, rotates, masks, clears, repaints, or invents source content.

Commands:
  dry-run  validate everything and print a plan; write nothing
  stage    atomically create a candidate-only staging directory and manifest
  commit   revalidate inputs/stage, then transactionally promote 48 strips
  recover  roll back an interrupted transaction from its journal

Real production commit is intentionally gated by a stage-bound approval
receipt, a fixed confirmation phrase, and collision baselines.  The script is
also importable by its self-test, which uses only a QA-contained fake target.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import io
import json
import os
import re
import shutil
import statistics
import struct
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
QA_ROOT = ROOT / "qa" / "skirmish_direction4_actions_20260905"
REAL_PRODUCTION_ROOT = ROOT / "assets" / "anim"
REAL_COMMIT_MANIFEST = ROOT / "assets" / "direction4" / "skirmish_top4_actions_direction4_manifest.json"
REAL_CLEANUP_VERIFICATION = QA_ROOT / "source" / "alpha_cleanup_verification.json"
UNITS = ("guan_dao", "guan_gong", "guan_jingqi", "guan_qi")
DIRECTIONS = ("se", "sw", "ne", "nw")
POSES = ("walk_step", "attack_strike", "death_fall", "death_down")
POSE_ANCHOR_KIND = {
    "walk_step": "foot_or_hoof",
    "attack_strike": "foot_or_hoof",
    "death_fall": "foot_or_hoof",
    "death_down": "lowest_contact",
}
ACTION_RECIPES = {
    "walk": ("idle", "walk_step"),
    "attack": ("idle", "attack_strike", "idle"),
    "death": ("idle", "death_fall", "death_down", "death_down"),
}
CONFIRM_COMMIT = "COMMIT_SKIRMISH_TOP4_ACTIONS"
CONFIRM_RECOVER = "RECOVER_SKIRMISH_TOP4_ACTIONS"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
REPARSE_ATTRIBUTE = 0x400
WALK_IDLE_HEIGHT_PREFERRED_MIN = 0.90
WALK_IDLE_HEIGHT_PREFERRED_MAX = 1.10
WALK_IDLE_HEIGHT_HARD_MIN = 0.85
WALK_IDLE_HEIGHT_HARD_MAX = 1.15


class PipelineError(RuntimeError):
    """A validation or transaction safety failure."""


@dataclass(frozen=True)
class RenderedFile:
    relative_path: str
    data: bytes
    width: int
    height: int
    sha256: str
    pixel_sha256: str


@dataclass
class BatchPlan:
    manifest: dict[str, Any]
    pose_files: dict[str, RenderedFile]
    strip_files: dict[str, RenderedFile]
    qa_files: dict[str, RenderedFile]
    target_snapshot: dict[str, dict[str, Any]]


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def pixel_sha256(image: Image.Image) -> str:
    return sha256_bytes(struct.pack(">II", image.width, image.height) + image.tobytes())


def png_bytes(image: Image.Image) -> bytes:
    payload = io.BytesIO()
    image.save(payload, format="PNG", optimize=True)
    return payload.getvalue()


def canonical_json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        with temporary.open("wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def resolve_path(value: str | Path) -> Path:
    path = Path(value)
    return path.resolve() if path.is_absolute() else (ROOT / path).resolve()


def relative_to_root(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def is_within(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def _is_reparse(path: Path) -> bool:
    try:
        stat = path.lstat()
    except FileNotFoundError:
        return False
    return path.is_symlink() or bool(getattr(stat, "st_file_attributes", 0) & REPARSE_ATTRIBUTE)


def reject_reparse_chain(path: Path, stop: Path) -> None:
    current = path.resolve(strict=False)
    stop_resolved = stop.resolve()
    if not is_within(current, stop_resolved) and current != stop_resolved:
        raise PipelineError(f"Path escapes safety root: {current} not under {stop_resolved}")
    while True:
        if current.exists() and _is_reparse(current):
            raise PipelineError(f"Symlink/junction/reparse point is not allowed: {current}")
        if current == stop_resolved:
            break
        current = current.parent


def require_sha(value: Any, label: str) -> str:
    text = str(value or "").lower()
    if SHA_RE.fullmatch(text) is None:
        raise PipelineError(f"{label} must be an explicit lowercase SHA-256")
    return text


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise PipelineError(f"Cannot read {label} {path}: {error}") from error
    if not isinstance(value, dict):
        raise PipelineError(f"{label} must contain one JSON object: {path}")
    return value


def load_config(path: Path) -> tuple[dict[str, Any], str]:
    resolved = path.resolve()
    config = load_json(resolved, "pipeline config")
    if config.get("schema_version") != 2 or config.get("kind") != "skirmish_direction4_action_batch":
        raise PipelineError("Unsupported pipeline config schema/kind; manual_source_rect workflow requires schema_version 2")
    if config.get("units") != list(UNITS) or config.get("directions") != list(DIRECTIONS):
        raise PipelineError(f"Config order must be units={list(UNITS)} and directions={list(DIRECTIONS)}")
    if not isinstance(config.get("batch_id"), str) or not config["batch_id"].strip():
        raise PipelineError("Config batch_id is required")
    scope = config.get("scope")
    if scope not in ("production", "test"):
        raise PipelineError("Config scope must be production or test")
    return config, sha256_file(resolved)


def validate_paths(config: dict[str, Any]) -> dict[str, Path]:
    raw = config.get("paths")
    if not isinstance(raw, dict):
        raise PipelineError("Config paths object is required")
    required = ("staging_dir", "production_root", "commit_manifest", "checkpoint_root", "approval_receipt")
    if any(not isinstance(raw.get(key), str) or not raw[key].strip() for key in required):
        raise PipelineError(f"Config paths must define {', '.join(required)}")
    paths = {key: resolve_path(raw[key]) for key in required}
    for key in ("staging_dir", "checkpoint_root", "approval_receipt"):
        if not is_within(paths[key], QA_ROOT):
            raise PipelineError(f"{key} must stay inside {QA_ROOT}")
        reject_reparse_chain(paths[key], ROOT)
    if config["scope"] == "production":
        if paths["production_root"] != REAL_PRODUCTION_ROOT.resolve():
            raise PipelineError(f"Production scope target must be exactly {REAL_PRODUCTION_ROOT}")
        if paths["commit_manifest"] != REAL_COMMIT_MANIFEST.resolve():
            raise PipelineError(f"Production scope commit_manifest must be exactly {REAL_COMMIT_MANIFEST}")
        reject_reparse_chain(paths["production_root"], ROOT)
        reject_reparse_chain(paths["commit_manifest"], ROOT)
    else:
        if not is_within(paths["production_root"], QA_ROOT) or paths["production_root"] == REAL_PRODUCTION_ROOT.resolve():
            raise PipelineError("Test scope production_root must be QA-contained and must not be assets/anim")
        if not is_within(paths["commit_manifest"], QA_ROOT):
            raise PipelineError("Test scope commit_manifest must stay inside the QA root")
        reject_reparse_chain(paths["production_root"], ROOT)
        reject_reparse_chain(paths["commit_manifest"], ROOT)
    if paths["staging_dir"] == paths["checkpoint_root"] or is_within(paths["staging_dir"], paths["checkpoint_root"]) or is_within(paths["checkpoint_root"], paths["staging_dir"]):
        raise PipelineError("Staging and checkpoint paths must not contain one another")
    if is_within(paths["production_root"], paths["staging_dir"]) or is_within(paths["staging_dir"], paths["production_root"]):
        raise PipelineError("Staging and production paths must be disjoint")
    return paths


def read_native_rgba_png(path: Path, label: str, expected_size: tuple[int, int] | None = None) -> Image.Image:
    try:
        header = path.read_bytes()[:33]
    except OSError as error:
        raise PipelineError(f"Cannot read {label} {path}: {error}") from error
    if len(header) < 33 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise PipelineError(f"{label} is not a valid PNG with IHDR: {path}")
    bit_depth, color_type = header[24], header[25]
    if bit_depth != 8 or color_type != 6:
        raise PipelineError(f"{label} must be native 8-bit PNG color type 6 RGBA; got depth={bit_depth}, type={color_type}: {path}")
    try:
        with Image.open(path) as opened:
            if opened.format != "PNG" or opened.mode != "RGBA":
                raise PipelineError(f"{label} must open directly as RGBA PNG: {path}")
            if getattr(opened, "is_animated", False) or getattr(opened, "n_frames", 1) != 1:
                raise PipelineError(f"{label} must be a single-frame PNG, not APNG: {path}")
            opened.load()
            image = opened.copy()
    except OSError as error:
        raise PipelineError(f"Cannot decode {label} {path}: {error}") from error
    if expected_size is not None and image.size != expected_size:
        raise PipelineError(f"{label} must be {expected_size[0]}x{expected_size[1]}, got {image.size}: {path}")
    return image


def require_file_hash(path: Path, expected: Any, label: str) -> str:
    expected_sha = require_sha(expected, f"{label} sha256")
    if not path.is_file():
        raise PipelineError(f"Missing {label}: {path}")
    actual = sha256_file(path)
    if actual != expected_sha:
        raise PipelineError(f"{label} hash mismatch: expected {expected_sha}, got {actual}: {path}")
    return actual


def validate_canvas(config: dict[str, Any]) -> dict[str, int]:
    canvas = config.get("canvas")
    if not isinstance(canvas, dict):
        raise PipelineError("Config canvas object is required")
    keys = (
        "size_px", "max_content_width_px", "max_content_height_px",
        "anchor_target_x_px", "anchor_target_y_px", "margin_px",
        "max_walk_attack_fit_shift_px",
    )
    values: dict[str, int] = {}
    for key in keys:
        value = canvas.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
            raise PipelineError(f"canvas.{key} must be a positive integer")
        values[key] = value
    size = values["size_px"]
    if size != 256:
        raise PipelineError("This batch requires 256x256 runtime frames")
    margin = values["margin_px"]
    available = size - margin * 2
    if values["max_content_width_px"] != available or values["max_content_height_px"] != available:
        raise PipelineError(f"Canvas content limits must equal the full padded area ({available}px)")
    if values["max_walk_attack_fit_shift_px"] > available:
        raise PipelineError("Canvas walk/attack fit-shift limit may not exceed the padded area")
    if not margin <= values["anchor_target_x_px"] < size - margin or not margin <= values["anchor_target_y_px"] < size - margin:
        raise PipelineError("Canvas anchor target must remain inside the padded canvas")
    return values


def validate_source_layout(config: dict[str, Any]) -> dict[str, int | str]:
    layout = config.get("source_layout")
    if not isinstance(layout, dict) or layout.get("mode") != "manual_source_rects_v2":
        raise PipelineError("source_layout.mode must be manual_source_rects_v2")
    values: dict[str, int] = {}
    for key in (
        "minimum_source_size_px",
        "rect_edge_transparent_clearance_px",
        "anchor_evidence_radius_px",
        "subject_group_join_gap_px",
        "minimum_subject_alpha_pixels",
    ):
        value = layout.get(key)
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            raise PipelineError(f"source_layout.{key} must be a non-negative integer")
        values[key] = value
    if values["rect_edge_transparent_clearance_px"] < 1:
        raise PipelineError("source_layout.rect_edge_transparent_clearance_px must be at least 1")
    if values["minimum_subject_alpha_pixels"] < 1:
        raise PipelineError("source_layout.minimum_subject_alpha_pixels must be at least 1")
    return {"mode": "manual_source_rects_v2", **values}


def load_anchors(config: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    path_value = config.get("anchors_file")
    hash_value = config.get("anchors_sha256")
    if not isinstance(path_value, str) or not path_value:
        raise PipelineError("Config anchors_file is required")
    path = resolve_path(path_value)
    actual_hash = require_file_hash(path, hash_value, "semantic anchors")
    data = load_json(path, "semantic anchors")
    if data.get("schema_version") not in (1, 2) or data.get("kind") != "skirmish_direction4_semantic_anchors":
        raise PipelineError("Unsupported semantic anchor schema/kind; entries must provide manual_source_rect")
    entries = data.get("entries")
    if not isinstance(entries, list):
        raise PipelineError("Semantic anchors entries must be an array")
    return entries, {"file": relative_to_root(path), "sha256": actual_hash, "schema_version": data["schema_version"]}


def normalize_manual_source_rect(raw: Any, key: tuple[str, str, str]) -> list[int]:
    if isinstance(raw, dict) and set(raw) == {"x0", "y0", "x1", "y1"}:
        rect = [raw["x0"], raw["y0"], raw["x1"], raw["y1"]]
    elif isinstance(raw, list) and len(raw) == 4:
        rect = list(raw)
    else:
        raise PipelineError(f"Semantic anchor {key} requires manual_source_rect as [x0,y0,x1,y1] or exact x0/y0/x1/y1 object")
    if (
        any(not isinstance(value, int) or isinstance(value, bool) or value < 0 for value in rect)
        or rect[0] >= rect[2]
        or rect[1] >= rect[3]
    ):
        raise PipelineError(f"Semantic anchor {key} requires manual_source_rect with positive half-open area")
    return rect


def validate_sources(
    config: dict[str, Any],
    anchors: list[dict[str, Any]],
    *,
    require_browser_confirmation: bool,
) -> list[dict[str, Any]]:
    raw_sources = config.get("sources")
    if not isinstance(raw_sources, list) or len(raw_sources) != 4:
        raise PipelineError("Config must define exactly four sources")
    by_pose: dict[str, dict[str, Any]] = {}
    source_paths: set[Path] = set()
    prompt_paths: set[Path] = set()
    raw_generated_paths: set[Path] = set()
    cleanup_input_paths: set[Path] = set()
    for item in raw_sources:
        if not isinstance(item, dict):
            raise PipelineError("Each source must be an object")
        pose = str(item.get("pose", ""))
        if pose not in POSES or pose in by_pose:
            raise PipelineError(f"Unknown or repeated source pose: {pose}")
        if item.get("rows") != list(UNITS) or item.get("columns") != list(DIRECTIONS):
            raise PipelineError(f"Source {pose} must use the frozen row/column order")
        source_path = resolve_path(str(item.get("file", "")))
        prompt_path = resolve_path(str(item.get("prompt_file", "")))
        if source_path in source_paths or prompt_path in prompt_paths:
            raise PipelineError("Each source atlas and prompt file must be unique")
        source_paths.add(source_path)
        prompt_paths.add(prompt_path)
        source_sha = require_file_hash(source_path, item.get("sha256"), f"{pose} source")
        prompt_sha = require_file_hash(prompt_path, item.get("prompt_sha256"), f"{pose} prompt")
        conversation = str(item.get("conversation", ""))
        if not conversation.startswith("https://chatgpt.com/c/") or "?" in conversation:
            raise PipelineError(f"Source {pose} requires a stable ChatGPT conversation URL without query parameters")
        cleanup = item.get("browser_cleanup")
        if not isinstance(cleanup, dict):
            raise PipelineError(f"Source {pose} requires browser_cleanup evidence")
        normalized_cleanup = dict(cleanup)
        normalized_raw_file: str | None = None
        normalized_raw_sha: str | None = None
        if config["scope"] == "production":
            if cleanup.get("method") != "browser_python_pillow_alpha_le_15_rgba_zero":
                raise PipelineError(f"Source {pose} cleanup method is not the reviewed browser-side method")
            raw_generated_path = resolve_path(str(item.get("raw_generated_file", "")))
            raw_generated_sha = require_file_hash(
                raw_generated_path,
                item.get("raw_generated_sha256"),
                f"{pose} original browser-generated raw source",
            )
            cleanup_input_path = resolve_path(str(cleanup.get("input_file", "")))
            cleanup_input_sha = require_file_hash(
                cleanup_input_path,
                cleanup.get("input_sha256"),
                f"{pose} browser-upload canonical cleanup input",
            )
            if raw_generated_path in raw_generated_paths or cleanup_input_path in cleanup_input_paths:
                raise PipelineError("Each raw browser generation and browser-upload canonical cleanup input must be unique")
            raw_generated_paths.add(raw_generated_path)
            cleanup_input_paths.add(cleanup_input_path)
            if raw_generated_path in (source_path, cleanup_input_path) or cleanup_input_path == source_path:
                raise PipelineError(f"Source {pose} raw, web-upload canonical input, and cleaned output must be three distinct files")
            if raw_generated_sha == cleanup_input_sha:
                raise PipelineError(f"Source {pose} must preserve the browser-upload re-encoding boundary; raw and web-upload canonical hashes are unexpectedly identical")
            if not is_within(raw_generated_path, QA_ROOT / "source"):
                raise PipelineError(f"Source {pose} raw browser generation must stay under the reviewed QA source directory")
            if cleanup_input_path.parent.name != "web_upload_canonical" or not is_within(cleanup_input_path, QA_ROOT / "source"):
                raise PipelineError(f"Source {pose} cleanup input must be retained in a web_upload_canonical directory under the reviewed QA source directory")
            if cleanup.get("input_role") != "web_upload_canonical":
                raise PipelineError(f"Source {pose} browser cleanup input_role must be web_upload_canonical")
            if cleanup.get("browser_upload_reencoded") is not True:
                raise PipelineError(f"Source {pose} must explicitly record browser_upload_reencoded=true")
            if cleanup.get("exactness_basis") != "web_upload_canonical":
                raise PipelineError(f"Source {pose} cleanup exactness_basis must be web_upload_canonical")
            if require_sha(cleanup.get("output_sha256"), f"{pose} browser cleanup output_sha256") != source_sha:
                raise PipelineError(f"Source {pose} cleanup output hash must equal the actual source hash")
            if not isinstance(cleanup.get("cleared_pixel_count"), int) or cleanup["cleared_pixel_count"] < 0:
                raise PipelineError(f"Source {pose} browser cleanup cleared_pixel_count is required")
            cleanup_prompt = resolve_path(str(cleanup.get("prompt_file", "")))
            cleanup_prompt_sha = require_file_hash(
                cleanup_prompt,
                cleanup.get("prompt_sha256"),
                f"{pose} browser cleanup prompt",
            )
            normalized_cleanup["prompt_file"] = relative_to_root(cleanup_prompt)
            normalized_cleanup["prompt_sha256"] = cleanup_prompt_sha
            verification_path = resolve_path(str(cleanup.get("verification_file", "")))
            if verification_path != REAL_CLEANUP_VERIFICATION.resolve():
                raise PipelineError(f"Source {pose} verification_file must be exactly {REAL_CLEANUP_VERIFICATION}")
            verification_sha = require_file_hash(
                verification_path,
                cleanup.get("verification_sha256"),
                f"{pose} browser cleanup verification",
            )
            verification = load_json(verification_path, "browser cleanup verification")
            if (
                verification.get("schema_version") != 1
                or verification.get("kind") != "browser_alpha_cleanup_verification"
                or verification.get("passed") is not True
                or verification.get("method") != cleanup["method"]
                or verification.get("conversation") != conversation
            ):
                raise PipelineError(f"Source {pose} browser cleanup verification header does not match the reviewed source chain")
            provenance_note = verification.get("provenance_note")
            if not isinstance(provenance_note, str) or "re-encoded" not in provenance_note or "web_upload_canonical" not in provenance_note:
                raise PipelineError(f"Source {pose} verification must explicitly distinguish the re-encoded web_upload_canonical input from the original raw generation")
            results = verification.get("results")
            if not isinstance(results, list) or len(results) != 4:
                raise PipelineError("Browser cleanup verification must contain exactly four pose results")
            result_map = {str(record.get("pose", "")): record for record in results if isinstance(record, dict)}
            if set(result_map) != set(POSES):
                raise PipelineError("Browser cleanup verification must cover the exact four frozen poses once each")
            verified = result_map[pose]
            verification_parent = verification_path.parent

            def verified_path(field: str) -> Path:
                value = verified.get(field)
                if not isinstance(value, str) or not value:
                    raise PipelineError(f"Source {pose} verification result requires {field}")
                candidate = Path(value)
                return candidate.resolve() if candidate.is_absolute() else (verification_parent / candidate).resolve()

            if verified_path("raw_generated_file") != raw_generated_path or require_sha(verified.get("raw_generated_sha256"), f"{pose} verified raw_generated_sha256") != raw_generated_sha:
                raise PipelineError(f"Source {pose} raw browser generation does not match its cleanup verification result")
            if verified_path("input_file") != cleanup_input_path or require_sha(verified.get("input_sha256"), f"{pose} verified input_sha256") != cleanup_input_sha:
                raise PipelineError(f"Source {pose} web-upload canonical input does not match its cleanup verification result")
            if verified_path("output_file") != source_path or require_sha(verified.get("output_sha256"), f"{pose} verified output_sha256") != source_sha:
                raise PipelineError(f"Source {pose} cleaned output does not match its cleanup verification result")
            if verified.get("changed_pixels") != cleanup["cleared_pixel_count"]:
                raise PipelineError(f"Source {pose} cleared_pixel_count does not match its cleanup verification result")
            if verified.get("alpha_gt_15_mismatch_pixels") != 0 or verified.get("alpha_le_15_output_nonzero_pixels") != 0:
                raise PipelineError(f"Source {pose} cleanup verification reports non-exact retained or cleared pixels")
            normalized_raw_file = relative_to_root(raw_generated_path)
            normalized_raw_sha = raw_generated_sha
            normalized_cleanup["input_file"] = relative_to_root(cleanup_input_path)
            normalized_cleanup["input_sha256"] = cleanup_input_sha
            normalized_cleanup["verification_file"] = relative_to_root(verification_path)
            normalized_cleanup["verification_sha256"] = verification_sha
        if require_browser_confirmation and cleanup.get("confirmed") is not True:
            raise PipelineError(f"Source {pose} browser-cleaned attachment is not confirmed")
        by_pose[pose] = {
            **item,
            "_path": source_path,
            "_prompt_path": prompt_path,
            "_sha": source_sha,
            "_prompt_sha": prompt_sha,
            "_raw_generated_file": normalized_raw_file,
            "_raw_generated_sha": normalized_raw_sha,
            "_browser_cleanup": normalized_cleanup,
        }
    if set(by_pose) != set(POSES):
        raise PipelineError(f"Sources must cover exactly {list(POSES)}")
    if require_browser_confirmation and config["scope"] == "production":
        approval = config.get("source_approval")
        if not isinstance(approval, dict) or approval.get("browser_cleaned_sources_confirmed") is not True:
            raise PipelineError("source_approval.browser_cleaned_sources_confirmed must be true before staging")

    expected = {(pose, unit, direction) for pose in POSES for unit in UNITS for direction in DIRECTIONS}
    seen: set[tuple[str, str, str]] = set()
    for index, entry in enumerate(anchors, 1):
        if not isinstance(entry, dict):
            raise PipelineError(f"Semantic anchor entry {index} must be an object")
        key = (str(entry.get("pose", "")), str(entry.get("unit", "")), str(entry.get("direction", "")))
        if key not in expected or key in seen:
            raise PipelineError(f"Unknown or repeated semantic anchor: {key}")
        seen.add(key)
        if entry.get("measurement_kind") != POSE_ANCHOR_KIND[key[0]]:
            raise PipelineError(f"Semantic anchor {key} must use {POSE_ANCHOR_KIND[key[0]]}")
        for coordinate in ("source_x_px", "source_y_px"):
            value = entry.get(coordinate)
            if not isinstance(value, int) or isinstance(value, bool) or value < 0:
                raise PipelineError(f"Semantic anchor {key} has invalid {coordinate}")
        entry["_manual_source_rect"] = normalize_manual_source_rect(entry.get("manual_source_rect"), key)
        if not isinstance(entry.get("review_note"), str) or not entry["review_note"].strip():
            raise PipelineError(f"Semantic anchor {key} requires a nonempty review_note")
    if seen != expected:
        missing = sorted(expected - seen)
        raise PipelineError(f"Semantic anchors must cover all 64 cells; missing={missing[:4]} count={len(missing)}")
    return [by_pose[pose] for pose in POSES]


def load_idles(config: dict[str, Any]) -> tuple[dict[tuple[str, str], Image.Image], list[dict[str, Any]]]:
    entries = config.get("idle_inputs")
    if not isinstance(entries, list) or len(entries) != 16:
        raise PipelineError("Config must freeze exactly 16 directional idle inputs")
    expected = {(unit, direction) for unit in UNITS for direction in DIRECTIONS}
    images: dict[tuple[str, str], Image.Image] = {}
    records: list[dict[str, Any]] = []
    for entry in entries:
        if not isinstance(entry, dict):
            raise PipelineError("Each idle input must be an object")
        key = (str(entry.get("unit", "")), str(entry.get("direction", "")))
        if key not in expected or key in images:
            raise PipelineError(f"Unknown or repeated idle input: {key}")
        path = resolve_path(str(entry.get("file", "")))
        actual_sha = require_file_hash(path, entry.get("sha256"), f"idle {key}")
        image = read_native_rgba_png(path, f"idle {key}", (256, 256))
        images[key] = image
        records.append({
            "unit": key[0], "direction": key[1], "file": relative_to_root(path),
            "sha256": actual_sha, "pixel_sha256": pixel_sha256(image),
        })
    if set(images) != expected:
        raise PipelineError("Idle inputs do not cover the exact 16 unit/direction cells")
    return images, records


def _rectangles_overlap(first: tuple[int, int, int, int], second: tuple[int, int, int, int]) -> bool:
    return max(first[0], second[0]) < min(first[2], second[2]) and max(first[1], second[1]) < min(first[3], second[3])


def _connected_components(image: Image.Image) -> list[dict[str, Any]]:
    """Return exact 8-connected alpha>0 components without altering pixels."""
    alpha = image.getchannel("A").tobytes()
    width, height = image.size
    visited = bytearray(width * height)
    components: list[dict[str, Any]] = []
    for start, value in enumerate(alpha):
        if value == 0 or visited[start]:
            continue
        visited[start] = 1
        stack = [start]
        count = 0
        min_x = width
        min_y = height
        max_x = -1
        max_y = -1
        while stack:
            index = stack.pop()
            y, x = divmod(index, width)
            count += 1
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
            for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                row_offset = neighbor_y * width
                for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                    neighbor = row_offset + neighbor_x
                    if not visited[neighbor] and alpha[neighbor] != 0:
                        visited[neighbor] = 1
                        stack.append(neighbor)
        components.append({"pixels": count, "bbox": (min_x, min_y, max_x + 1, max_y + 1)})
    return components


def _component_group_summary(components: list[dict[str, Any]], join_gap: int) -> list[dict[str, Any]]:
    parent = list(range(len(components)))

    def find(index: int) -> int:
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    def union(first: int, second: int) -> None:
        root_first, root_second = find(first), find(second)
        if root_first != root_second:
            parent[root_second] = root_first

    for first in range(len(components)):
        ax0, ay0, ax1, ay1 = components[first]["bbox"]
        for second in range(first + 1, len(components)):
            bx0, by0, bx1, by1 = components[second]["bbox"]
            gap_x = max(0, bx0 - ax1, ax0 - bx1)
            gap_y = max(0, by0 - ay1, ay0 - by1)
            if max(gap_x, gap_y) <= join_gap:
                union(first, second)
    grouped: dict[int, list[int]] = {}
    for index in range(len(components)):
        grouped.setdefault(find(index), []).append(index)
    summaries: list[dict[str, Any]] = []
    for indices in grouped.values():
        summaries.append({
            "component_count": len(indices),
            "alpha_pixels": sum(components[index]["pixels"] for index in indices),
            "bbox": [
                min(components[index]["bbox"][0] for index in indices),
                min(components[index]["bbox"][1] for index in indices),
                max(components[index]["bbox"][2] for index in indices),
                max(components[index]["bbox"][3] for index in indices),
            ],
        })
    return sorted(summaries, key=lambda item: item["alpha_pixels"], reverse=True)


def extract_manual_source_cells(
    image: Image.Image,
    layout: dict[str, int | str],
    pose: str,
    anchors: list[dict[str, Any]],
) -> dict[tuple[str, str], dict[str, Any]]:
    """Validate 16 reviewed source rectangles and retain every RGBA pixel in each alpha bbox."""
    width, height = image.size
    minimum = int(layout["minimum_source_size_px"])
    if width != height or width < minimum:
        raise PipelineError(f"Source {pose} must be square and >= {minimum}px; got {image.size}")
    pose_anchors = [entry for entry in anchors if entry["pose"] == pose]
    if len(pose_anchors) != 16:
        raise PipelineError(f"Source {pose} must have exactly 16 manual_source_rect entries")
    by_key = {(entry["unit"], entry["direction"]): entry for entry in pose_anchors}
    rectangles: dict[tuple[str, str], tuple[int, int, int, int]] = {}
    for key, entry in by_key.items():
        rect = tuple(entry["_manual_source_rect"])
        x0, y0, x1, y1 = rect
        if x1 > width or y1 > height:
            raise PipelineError(f"manual_source_rect {(pose, *key)} escapes source bounds {image.size}: {rect}")
        rectangles[key] = rect

    keys = list(rectangles)
    for first_index, first_key in enumerate(keys):
        for second_key in keys[first_index + 1:]:
            if _rectangles_overlap(rectangles[first_key], rectangles[second_key]):
                raise PipelineError(f"manual_source_rect overlap in {pose}: {first_key} and {second_key}")

    # Preserve the declared 4x4 semantic ordering even though cuts are manual.
    for unit in UNITS:
        centers = [(rectangles[(unit, direction)][0] + rectangles[(unit, direction)][2]) / 2.0 for direction in DIRECTIONS]
        if any(centers[index] >= centers[index + 1] for index in range(3)):
            raise PipelineError(f"manual_source_rect direction order is wrong for {pose}:{unit}; expected SE,SW,NE,NW left-to-right")
    for direction in DIRECTIONS:
        centers = [(rectangles[(unit, direction)][1] + rectangles[(unit, direction)][3]) / 2.0 for unit in UNITS]
        if any(centers[index] >= centers[index + 1] for index in range(3)):
            raise PipelineError(f"manual_source_rect unit order is wrong for {pose}:{direction}; expected frozen unit rows top-to-bottom")

    # A byte ownership map proves every visible source pixel belongs to exactly
    # one reviewed rectangle.  It is validation only and is never applied as an
    # image mask or used to modify/copy source pixels.
    ownership = bytearray(width * height)
    for rect in rectangles.values():
        x0, y0, x1, y1 = rect
        fill = b"\x01" * (x1 - x0)
        for y in range(y0, y1):
            start = y * width + x0
            ownership[start:start + (x1 - x0)] = fill
    alpha_bytes = image.getchannel("A").tobytes()
    uncovered = 0
    uncovered_samples: list[list[int]] = []
    for index, alpha in enumerate(alpha_bytes):
        if alpha > 0 and ownership[index] != 1:
            uncovered += 1
            if len(uncovered_samples) < 8:
                y, x = divmod(index, width)
                uncovered_samples.append([x, y])
    if uncovered:
        raise PipelineError(f"Source {pose} has {uncovered} alpha>0 pixels outside all manual_source_rect entries; samples={uncovered_samples}")

    clearance = int(layout["rect_edge_transparent_clearance_px"])
    join_gap = int(layout["subject_group_join_gap_px"])
    minimum_pixels = int(layout["minimum_subject_alpha_pixels"])
    result: dict[tuple[str, str], dict[str, Any]] = {}
    for key, rect in rectangles.items():
        x0, y0, x1, y1 = rect
        region = image.crop(rect)
        region_width, region_height = region.size
        if clearance * 2 >= region_width or clearance * 2 >= region_height:
            raise PipelineError(f"manual_source_rect {(pose, *key)} is too small for {clearance}px transparent clearance")
        edge_bands = {
            "top": (0, 0, region_width, clearance),
            "bottom": (0, region_height - clearance, region_width, region_height),
            "left": (0, 0, clearance, region_height),
            "right": (region_width - clearance, 0, region_width, region_height),
        }
        dirty_edges = [name for name, box in edge_bands.items() if region.crop(box).getchannel("A").getbbox() is not None]
        if dirty_edges:
            raise PipelineError(f"manual_source_rect {(pose, *key)} lacks {clearance}px alpha==0 edge clearance on {dirty_edges}")
        bounds = region.getchannel("A").getbbox()
        if bounds is None:
            raise PipelineError(f"manual_source_rect {(pose, *key)} contains no alpha>0 subject")
        absolute = (x0 + bounds[0], y0 + bounds[1], x0 + bounds[2], y0 + bounds[3])
        body = image.crop(absolute)
        measured_clearance = {
            "left": bounds[0],
            "top": bounds[1],
            "right": region_width - bounds[2],
            "bottom": region_height - bounds[3],
        }
        measured_clearance["minimum"] = min(measured_clearance.values())
        alpha_pixels = sum(1 for value in body.getchannel("A").tobytes() if value > 0)
        if alpha_pixels < minimum_pixels:
            raise PipelineError(f"manual_source_rect {(pose, *key)} has only {alpha_pixels} alpha pixels; minimum={minimum_pixels}")
        components = _connected_components(body)
        groups = _component_group_summary(components, join_gap)
        if len(groups) != 1:
            raise PipelineError(
                f"manual_source_rect {(pose, *key)} contains {len(groups)} separated subject groups "
                f"after joining component boxes within {join_gap}px: {groups[:4]}"
            )
        result[key] = {
            "manual_source_rect": rect,
            "alpha_bounds_in_manual_rect": bounds,
            "source_rect": absolute,
            "body": body,
            "source_pixel_sha256": pixel_sha256(body),
            "measured_alpha_zero_edge_clearance_px": measured_clearance,
            "owned_alpha_pixels": alpha_pixels,
            "connected_component_count": len(components),
            "subject_group_count": len(groups),
            "subject_group": groups[0],
        }
    return result


def render_pose_rows(
    sources: list[dict[str, Any]],
    anchors: list[dict[str, Any]],
    idles: dict[tuple[str, str], Image.Image],
    canvas: dict[str, int],
    layout: dict[str, int | str],
) -> tuple[dict[tuple[str, str, str], Image.Image], list[dict[str, Any]], list[dict[str, Any]]]:
    anchor_map = {(a["pose"], a["unit"], a["direction"]): a for a in anchors}
    rendered: dict[tuple[str, str, str], Image.Image] = {}
    pose_records: list[dict[str, Any]] = []
    source_records: list[dict[str, Any]] = []
    prepared_by_unit: dict[str, list[tuple[str, str, dict[str, Any], dict[str, Any], int, int, int]]] = {unit: [] for unit in UNITS}
    size = canvas["size_px"]
    target_x, target_y = canvas["anchor_target_x_px"], canvas["anchor_target_y_px"]
    margin = canvas["margin_px"]
    for source in sources:
        pose = source["pose"]
        atlas = read_native_rgba_png(source["_path"], f"{pose} source")
        cells = extract_manual_source_cells(atlas, layout, pose, anchors)
        source_records.append({
            "pose": pose,
            "file": relative_to_root(source["_path"]),
            "sha256": source["_sha"],
            "raw_generated_file": source["_raw_generated_file"],
            "raw_generated_sha256": source["_raw_generated_sha"],
            "width": atlas.width,
            "height": atlas.height,
            "png_contract": "single-frame native 8-bit PNG color type 6 RGBA",
            "prompt": {"file": relative_to_root(source["_prompt_path"]), "sha256": source["_prompt_sha"]},
            "conversation": source["conversation"],
            "browser_cleanup": source["_browser_cleanup"],
            "rows": list(UNITS),
            "columns": list(DIRECTIONS),
            "layout": "16 reviewed, non-overlapping absolute manual_source_rect entries; no global transparent-seam assumption",
            "visible_pixel_ownership": "Every source alpha>0 pixel belongs to exactly one manual_source_rect",
        })
        for unit in UNITS:
            for direction in DIRECTIONS:
                cell = cells[(unit, direction)]
                anchor = anchor_map[(pose, unit, direction)]
                x, y = anchor["source_x_px"], anchor["source_y_px"]
                cx0, cy0, cx1, cy1 = cell["manual_source_rect"]
                sx0, sy0, sx1, sy1 = cell["source_rect"]
                if not (cx0 <= x < cx1 and cy0 <= y < cy1):
                    raise PipelineError(f"Anchor {(pose, unit, direction)} lies outside its manual_source_rect")
                if not (sx0 <= x < sx1 and sy0 <= y < sy1):
                    raise PipelineError(f"Anchor {(pose, unit, direction)} lies outside the retained alpha>0 rectangle")
                radius = int(layout["anchor_evidence_radius_px"])
                evidence = atlas.crop((max(sx0, x - radius), max(sy0, y - radius), min(sx1, x + radius + 1), min(sy1, y + radius + 1)))
                max_alpha = max(evidence.getchannel("A").tobytes())
                if max_alpha == 0:
                    raise PipelineError(f"Anchor {(pose, unit, direction)} has no alpha>0 evidence within radius {radius}")
                offset_x, offset_y = x - sx0, y - sy0
                prepared_by_unit[unit].append((pose, direction, cell, anchor, offset_x, offset_y, max_alpha))

    # Derive one source-to-runtime world scale per unit from the median of the
    # four same-direction idle-height / walk-source-height ratios.  Only the
    # actual 248x248 padded canvas may reduce that reference scale; semantic
    # anchor placement is handled by the smallest per-frame translation.
    for unit in UNITS:
        walk_height_ratios: list[float] = []
        for direction in DIRECTIONS:
            idle_bounds = idles[(unit, direction)].getchannel("A").getbbox()
            if idle_bounds is None:
                raise PipelineError(f"Idle alpha bbox is empty: {(unit, direction)}")
            walk_cell = next(
                cell
                for pose, candidate_direction, cell, _anchor, _offset_x, _offset_y, _max_alpha in prepared_by_unit[unit]
                if pose == "walk_step" and candidate_direction == direction
            )
            idle_height = idle_bounds[3] - idle_bounds[1]
            walk_height_ratios.append(idle_height / walk_cell["body"].height)
        reference_scale = statistics.median(walk_height_ratios)
        fit_limits: list[float] = []
        for _pose, _direction, cell, _anchor, _offset_x, _offset_y, _max_alpha in prepared_by_unit[unit]:
            body: Image.Image = cell["body"]
            fit_limits.extend((
                canvas["max_content_width_px"] / body.width,
                canvas["max_content_height_px"] / body.height,
            ))
        all_pose_canvas_fit_scale_limit = min(fit_limits)
        scale = min(reference_scale, all_pose_canvas_fit_scale_limit)
        if not 0 < scale <= 100:
            raise PipelineError(f"Cannot derive one safe all-action uniform scale for {unit}")
        for pose, direction, cell, anchor, offset_x, offset_y, max_alpha in prepared_by_unit[unit]:
            body = cell["body"]
            resized_size = (max(1, round(body.width * scale)), max(1, round(body.height * scale)))
            resized = body.resize(resized_size, Image.Resampling.LANCZOS)
            scaled_anchor = (round(offset_x * scale), round(offset_y * scale))
            desired_paste_xy = (target_x - scaled_anchor[0], target_y - scaled_anchor[1])
            max_paste_x = size - margin - resized.width
            max_paste_y = size - margin - resized.height
            if max_paste_x < margin or max_paste_y < margin:
                raise PipelineError(f"Fit-limited pose still does not fit padded canvas: {(pose, unit, direction)}")
            paste_xy = (
                min(max(desired_paste_xy[0], margin), max_paste_x),
                min(max(desired_paste_xy[1], margin), max_paste_y),
            )
            fit_shift = (paste_xy[0] - desired_paste_xy[0], paste_xy[1] - desired_paste_xy[1])
            if pose in ("walk_step", "attack_strike") and max(abs(fit_shift[0]), abs(fit_shift[1])) > canvas["max_walk_attack_fit_shift_px"]:
                raise PipelineError(
                    f"Walk/attack semantic-anchor fit shift exceeds {canvas['max_walk_attack_fit_shift_px']}px: "
                    f"{(pose, unit, direction)} shift={fit_shift}"
                )
            output = Image.new("RGBA", (size, size), (0, 0, 0, 0))
            output.paste(resized, paste_xy)  # no mask: direct RGBA rectangle paste
            key = (pose, unit, direction)
            rendered[key] = output
            rel = f"poses/{pose}/{unit}_{pose}_{direction}.png"
            data = png_bytes(output)
            pose_records.append({
                "pose": pose,
                "unit": unit,
                "direction": direction,
                "staged_file": rel,
                "sha256": sha256_bytes(data),
                "pixel_sha256": pixel_sha256(output),
                "manual_source_rect": list(cell["manual_source_rect"]),
                "source_rect": list(cell["source_rect"]),
                "source_crop_pixel_sha256": cell["source_pixel_sha256"],
                "measured_alpha_zero_edge_clearance_px": cell["measured_alpha_zero_edge_clearance_px"],
                "owned_alpha_pixels": cell["owned_alpha_pixels"],
                "connected_component_count": cell["connected_component_count"],
                "subject_group_count": cell["subject_group_count"],
                "subject_group": cell["subject_group"],
                "reference_scale": reference_scale,
                "reference_scale_basis": "median of four same-direction existing-idle alpha-bbox heights divided by walk_step source alpha-bbox heights",
                "all_pose_canvas_fit_scale_limit": all_pose_canvas_fit_scale_limit,
                "fit_limited_scale": scale,
                "uniform_scale_for_unit_all_actions": scale,
                "resize_filter": "Pillow.Image.Resampling.LANCZOS",
                "resized_size": list(resized_size),
                "desired_paste_xy": list(desired_paste_xy),
                "paste_xy": list(paste_xy),
                "fit_shift_xy_px": list(fit_shift),
                "placed_anchor_xy_px": [paste_xy[0] + scaled_anchor[0], paste_xy[1] + scaled_anchor[1]],
                "semantic_anchor": {
                    "measurement_kind": anchor["measurement_kind"],
                    "source_xy_px": [anchor["source_x_px"], anchor["source_y_px"]],
                    "source_offset_in_crop_px": [offset_x, offset_y],
                    "source_evidence_max_alpha": max_alpha,
                    "review_note": anchor["review_note"],
                    "target_xy_px": [target_x, target_y],
                    "fit_shift_xy_px": list(fit_shift),
                    "placed_xy_px": [paste_xy[0] + scaled_anchor[0], paste_xy[1] + scaled_anchor[1]],
                },
                "processing": "manual rectangle ownership -> complete alpha>0 rectangular crop -> idle/walk median-height reference scale -> all-pose 248px fit limit -> semantic-anchor placement -> minimum canvas-fit shift -> unmasked RGBA paste",
            })
    return rendered, pose_records, source_records


def make_rendered_file(relative_path: str, image: Image.Image) -> RenderedFile:
    data = png_bytes(image)
    return RenderedFile(relative_path, data, image.width, image.height, sha256_bytes(data), pixel_sha256(image))


def alpha_bbox_stats(image: Image.Image) -> dict[str, Any]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        return {"bbox": None, "size": [0, 0]}
    return {"bbox": list(bounds), "size": [bounds[2] - bounds[0], bounds[3] - bounds[1]]}


def make_candidate_contact_sheet(
    idles: dict[tuple[str, str], Image.Image],
    poses: dict[tuple[str, str, str], Image.Image],
    pose_records: list[dict[str, Any]],
) -> Image.Image:
    """Create an opaque QA-only overview; never used as runtime art."""
    margin = 14
    label_width = 124
    cell_width = 208
    header_height = 34
    unit_header_height = 22
    action_height = 110
    width = margin * 2 + label_width + cell_width * 4
    height = margin * 2 + header_height + len(UNITS) * (unit_header_height + action_height * 3)
    sheet = Image.new("RGBA", (width, height), (24, 27, 32, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, margin), "QA ONLY | idle vs non-idle key poses | no production use", fill=(245, 219, 125, 255))
    for column, direction in enumerate(DIRECTIONS):
        x = margin + label_width + column * cell_width
        draw.text((x + 6, margin + 17), direction.upper(), fill=(210, 220, 235, 255))
    y = margin + header_height
    action_poses = {
        "walk": (("I", "idle"), ("W", "walk_step")),
        "attack": (("I", "idle"), ("A", "attack_strike")),
        "death": (("I", "idle"), ("F", "death_fall"), ("D", "death_down")),
    }
    thumb_size = 60
    pose_record_map = {(record["pose"], record["unit"], record["direction"]): record for record in pose_records}
    for unit in UNITS:
        draw.rectangle((margin, y, width - margin, y + unit_header_height - 2), fill=(43, 48, 57, 255))
        scale_record = pose_record_map[("walk_step", unit, "se")]
        draw.text(
            (margin + 4, y + 4),
            f"{unit} | reference={scale_record['reference_scale']:.3f} actual={scale_record['fit_limited_scale']:.3f} fit_limit={scale_record['all_pose_canvas_fit_scale_limit']:.3f}",
            fill=(255, 236, 170, 255),
        )
        y += unit_header_height
        for action, frame_specs in action_poses.items():
            draw.text((margin + 8, y + 34), action, fill=(220, 225, 232, 255))
            for column, direction in enumerate(DIRECTIONS):
                cell_x = margin + label_width + column * cell_width
                draw.rectangle((cell_x, y, cell_x + cell_width - 4, y + action_height - 4), outline=(91, 101, 117, 255), width=1)
                for frame_index, (short_label, pose) in enumerate(frame_specs):
                    frame = idles[(unit, direction)] if pose == "idle" else poses[(pose, unit, direction)]
                    thumb_x = cell_x + 5 + frame_index * 66
                    thumb_y = y + 4
                    for checker_y in range(0, thumb_size, 10):
                        for checker_x in range(0, thumb_size, 10):
                            color = (58, 63, 72, 255) if (checker_x // 10 + checker_y // 10) % 2 == 0 else (76, 82, 92, 255)
                            draw.rectangle((thumb_x + checker_x, thumb_y + checker_y, thumb_x + checker_x + 9, thumb_y + checker_y + 9), fill=color)
                    thumbnail = frame.resize((thumb_size, thumb_size), Image.Resampling.LANCZOS)
                    sheet.alpha_composite(thumbnail, (thumb_x, thumb_y))
                    bbox = alpha_bbox_stats(frame)["size"]
                    draw.text((thumb_x, thumb_y + thumb_size + 2), f"{short_label}{bbox[0]}x{bbox[1]}", fill=(196, 204, 216, 255))
                    if pose != "idle":
                        record = pose_record_map[(pose, unit, direction)]
                        shift = record["fit_shift_xy_px"]
                        draw.text((thumb_x, thumb_y + thumb_size + 13), f"shift={shift[0]},{shift[1]}", fill=(165, 180, 198, 255))
                        if pose == "walk_step":
                            idle_height = alpha_bbox_stats(idles[(unit, direction)])["size"][1]
                            height_ratio = bbox[1] / idle_height
                            draw.text((thumb_x, thumb_y + thumb_size + 24), f"Hratio={height_ratio:.2f}", fill=(155, 218, 166, 255))
            y += action_height
    return sheet


def build_plan(config_path: Path, *, require_browser_confirmation: bool) -> BatchPlan:
    config, config_sha = load_config(config_path)
    paths = validate_paths(config)
    canvas = validate_canvas(config)
    source_layout = validate_source_layout(config)
    anchors, anchor_record = load_anchors(config)
    sources = validate_sources(config, anchors, require_browser_confirmation=require_browser_confirmation)
    idles, idle_records = load_idles(config)
    poses, pose_records, source_records = render_pose_rows(sources, anchors, idles, canvas, source_layout)

    pose_files: dict[str, RenderedFile] = {}
    for record in pose_records:
        key = (record["pose"], record["unit"], record["direction"])
        rendered = make_rendered_file(record["staged_file"], poses[key])
        if rendered.sha256 != record["sha256"] or rendered.pixel_sha256 != record["pixel_sha256"]:
            raise PipelineError(f"Internal pose serialization drift: {key}")
        pose_files[rendered.relative_path] = rendered

    for pose in POSES:
        for unit in UNITS:
            for direction in DIRECTIONS:
                if poses[(pose, unit, direction)].tobytes() == idles[(unit, direction)].tobytes():
                    raise PipelineError(f"Pose must differ from same-direction idle: {(pose, unit, direction)}")
    for unit in UNITS:
        for direction in DIRECTIONS:
            if poses[("death_fall", unit, direction)].tobytes() == poses[("death_down", unit, direction)].tobytes():
                raise PipelineError(f"death_fall and death_down must differ: {(unit, direction)}")

    strip_files: dict[str, RenderedFile] = {}
    strip_records: list[dict[str, Any]] = []
    for unit in UNITS:
        for direction in DIRECTIONS:
            for action, recipe in ACTION_RECIPES.items():
                frames: list[Image.Image] = []
                frame_records: list[dict[str, Any]] = []
                for frame_name in recipe:
                    if frame_name == "idle":
                        frame = idles[(unit, direction)]
                        idle_record = next(item for item in idle_records if item["unit"] == unit and item["direction"] == direction)
                        frame_records.append({"kind": "idle", "file": idle_record["file"], "sha256": idle_record["sha256"], "pixel_sha256": idle_record["pixel_sha256"]})
                    else:
                        frame = poses[(frame_name, unit, direction)]
                        pose_record = next(item for item in pose_records if item["pose"] == frame_name and item["unit"] == unit and item["direction"] == direction)
                        frame_records.append({"kind": frame_name, "file": pose_record["staged_file"], "sha256": pose_record["sha256"], "pixel_sha256": pose_record["pixel_sha256"]})
                    frames.append(frame)
                strip = Image.new("RGBA", (256 * len(frames), 256), (0, 0, 0, 0))
                for index, frame in enumerate(frames):
                    strip.paste(frame, (index * 256, 0))  # no mask
                for index, frame in enumerate(frames):
                    if strip.crop((index * 256, 0, (index + 1) * 256, 256)).tobytes() != frame.tobytes():
                        raise PipelineError(f"Strip frame byte verification failed: {(unit, action, direction, index)}")
                relative = f"strips/{unit}_{action}_{direction}.png"
                rendered = make_rendered_file(relative, strip)
                strip_files[relative] = rendered
                target_rel = f"{unit}_{action}_{direction}.png"
                strip_records.append({
                    "unit": unit,
                    "direction": direction,
                    "state": action,
                    "recipe": list(recipe),
                    "frame_count": len(frames),
                    "size": [strip.width, strip.height],
                    "staged_file": relative,
                    "target_file": target_rel,
                    "sha256": rendered.sha256,
                    "pixel_sha256": rendered.pixel_sha256,
                    "frames": frame_records,
                    "frame_verification": "Every 256x256 strip slice is byte-identical in RGBA pixels to its listed input frame.",
                })

    if len(pose_files) != 64 or len(strip_files) != 48:
        raise PipelineError(f"Internal output count error: poses={len(pose_files)}, strips={len(strip_files)}")

    idle_walk_bbox_comparison: list[dict[str, Any]] = []
    for unit in UNITS:
        for direction in DIRECTIONS:
            idle_stats = alpha_bbox_stats(idles[(unit, direction)])
            walk_stats = alpha_bbox_stats(poses[("walk_step", unit, direction)])
            if idle_stats["size"][0] <= 0 or idle_stats["size"][1] <= 0:
                raise PipelineError(f"Idle alpha bbox is empty: {(unit, direction)}")
            walk_record = next(item for item in pose_records if item["pose"] == "walk_step" and item["unit"] == unit and item["direction"] == direction)
            height_ratio = walk_stats["size"][1] / idle_stats["size"][1]
            if not WALK_IDLE_HEIGHT_HARD_MIN <= height_ratio <= WALK_IDLE_HEIGHT_HARD_MAX:
                raise PipelineError(
                    f"Walk/idle height ratio outside hard visual continuity gate "
                    f"[{WALK_IDLE_HEIGHT_HARD_MIN}, {WALK_IDLE_HEIGHT_HARD_MAX}]: {(unit, direction)}={height_ratio}"
                )
            idle_walk_bbox_comparison.append({
                "unit": unit,
                "direction": direction,
                "idle": idle_stats,
                "walk_step": walk_stats,
                "walk_to_idle_width_ratio": walk_stats["size"][0] / idle_stats["size"][0],
                "walk_to_idle_height_ratio": height_ratio,
                "preferred_height_ratio_range": [WALK_IDLE_HEIGHT_PREFERRED_MIN, WALK_IDLE_HEIGHT_PREFERRED_MAX],
                "hard_height_ratio_range": [WALK_IDLE_HEIGHT_HARD_MIN, WALK_IDLE_HEIGHT_HARD_MAX],
                "preferred_height_ratio_passed": WALK_IDLE_HEIGHT_PREFERRED_MIN <= height_ratio <= WALK_IDLE_HEIGHT_PREFERRED_MAX,
                "hard_height_ratio_passed": True,
                "reference_scale": walk_record["reference_scale"],
                "all_pose_canvas_fit_scale_limit": walk_record["all_pose_canvas_fit_scale_limit"],
                "fit_limited_scale": walk_record["fit_limited_scale"],
                "uniform_scale_for_unit_all_actions": walk_record["uniform_scale_for_unit_all_actions"],
                "gate": "Hard 0.85-1.15 walk/idle height continuity gate; 0.90-1.10 is preferred and visual approval remains required.",
            })

    contact_sheet = make_candidate_contact_sheet(idles, poses, pose_records)
    contact_file = make_rendered_file("candidate_contact_sheet.png", contact_sheet)
    qa_files = {contact_file.relative_path: contact_file}

    collision_map_raw = config.get("collision_policy", {}).get("expected_existing_sha256", {})
    if not isinstance(collision_map_raw, dict):
        raise PipelineError("collision_policy.expected_existing_sha256 must be an object")
    collision_map = {str(key): require_sha(value, f"collision baseline {key}") for key, value in collision_map_raw.items()}
    expected_target_names = {record["target_file"] for record in strip_records}
    if not set(collision_map).issubset(expected_target_names):
        raise PipelineError("Collision baseline contains a path outside the exact 48 targets")
    target_snapshot: dict[str, dict[str, Any]] = {}
    for record in strip_records:
        target_name = record["target_file"]
        target = paths["production_root"] / target_name
        if target.exists() and (not target.is_file() or _is_reparse(target)):
            raise PipelineError(f"Production target is not a regular non-reparse file: {target}")
        if target.is_file():
            current = sha256_file(target)
            if current != record["sha256"]:
                expected_before = collision_map.get(target_name)
                if expected_before is None:
                    raise PipelineError(f"Collision at {target}; no expected-existing hash is approved")
                if current != expected_before:
                    raise PipelineError(f"Collision baseline drift at {target}: expected {expected_before}, got {current}")
            target_snapshot[target_name] = {"exists": True, "sha256": current, "already_identical": current == record["sha256"]}
        else:
            if target_name in collision_map:
                raise PipelineError(f"Collision baseline declares existing target but it is absent: {target}")
            target_snapshot[target_name] = {"exists": False, "sha256": None, "already_identical": False}

    manifest = {
        "schema_version": 2,
        "kind": "skirmish_direction4_action_candidate_manifest",
        "batch_id": config["batch_id"],
        "scope": config["scope"],
        "config": {"file": relative_to_root(config_path), "sha256": config_sha},
        "tool": {"file": relative_to_root(Path(__file__)), "sha256": sha256_file(Path(__file__)), "python": sys.version.split()[0], "pillow": Image.__version__},
        "semantic_anchors": {**anchor_record, "count": len(anchors), "fallback_used": False},
        "canvas": canvas,
        "source_layout": source_layout,
        "sources": source_records,
        "idle_inputs": idle_records,
        "idle_walk_alpha_bbox_comparison": idle_walk_bbox_comparison,
        "normalized_poses": pose_records,
        "strips": strip_records,
        "candidate_contact_sheet": {
            "file": contact_file.relative_path,
            "sha256": contact_file.sha256,
            "pixel_sha256": contact_file.pixel_sha256,
            "size": [contact_file.width, contact_file.height],
            "qa_only": True,
            "coverage": "4 units x 3 actions x 4 directions; each unit prints reference/actual/fit-limit scale, every non-idle key pose prints alpha-bbox size and fit shift, and walk also prints idle-height ratio.",
        },
        "target_snapshot": target_snapshot,
        "counts": {"source_atlases": 4, "semantic_anchors": 64, "normalized_poses": 64, "production_strips": 48, "candidate_contact_sheets": 1},
        "processing_contract": [
            "The source is never converted, mirrored, rotated, masked, threshold-cropped, cleared, repainted, or supplemented.",
            "Each source uses 16 explicit absolute manual_source_rect entries; rectangles do not overlap and every source alpha>0 pixel is owned exactly once.",
            "Each manual rectangle has configured alpha==0 edge clearance and exactly one proximity-joined subject group; disconnected weapons, riders, and horses remain allowed components.",
            "Each frame uses the complete alpha>0 bbox inside its manual rectangle and retains every RGBA pixel inside that bbox.",
            "Each unit reference scale is the median of four same-direction idle-height / walk-source-height ratios; only the full 248x248 padded-canvas fit across all 16 new poses may reduce it.",
            "Each unit shares that fit-limited world scale across all four poses and directions; semantic anchors target (128,210), then each frame receives only the minimum translation needed to fit the padded canvas.",
            "walk_step and attack_strike fit shifts are hard-limited by canvas.max_walk_attack_fit_shift_px; death poses may shift directionally to retain the complete source alpha bbox.",
            "walk=idle+walk_step; attack=idle+attack_strike+idle; death=idle+death_fall+death_down+death_down.",
            "candidate_contact_sheet.png is an opaque QA-only layout and is never a runtime or production-art input.",
        ],
        "steam_modified_or_exported": False,
        "production_written": False,
    }
    return BatchPlan(manifest, pose_files, strip_files, qa_files, target_snapshot)


def dry_run(config_path: Path) -> dict[str, Any]:
    plan = build_plan(config_path, require_browser_confirmation=False)
    return {
        "passed": True,
        "mode": "dry-run",
        "writes": 0,
        "batch_id": plan.manifest["batch_id"],
        "counts": plan.manifest["counts"],
        "source_hashes": {item["pose"]: item["sha256"] for item in plan.manifest["sources"]},
        "target_snapshot": plan.target_snapshot,
        "note": "All images were rendered and verified in memory; no directory, report, or temporary file was written.",
    }


def _expected_stage_files(plan: BatchPlan) -> set[str]:
    return set(plan.pose_files) | set(plan.strip_files) | set(plan.qa_files) | {"candidate_manifest.json"}


def validate_stage_tree(stage: Path, plan: BatchPlan) -> dict[str, Any]:
    if not stage.is_dir() or _is_reparse(stage):
        raise PipelineError(f"Stage directory is missing or unsafe: {stage}")
    actual = {path.relative_to(stage).as_posix() for path in stage.rglob("*") if path.is_file()}
    expected = _expected_stage_files(plan)
    if actual != expected:
        raise PipelineError(f"Stage file set mismatch: missing={sorted(expected - actual)}, extra={sorted(actual - expected)}")
    for relative, rendered in {**plan.pose_files, **plan.strip_files, **plan.qa_files}.items():
        path = stage / Path(relative)
        if _is_reparse(path) or sha256_file(path) != rendered.sha256:
            raise PipelineError(f"Staged output hash mismatch: {path}")
        image = read_native_rgba_png(path, f"staged output {relative}", (rendered.width, rendered.height))
        if pixel_sha256(image) != rendered.pixel_sha256:
            raise PipelineError(f"Staged output pixel hash mismatch: {path}")
    manifest_path = stage / "candidate_manifest.json"
    manifest = load_json(manifest_path, "candidate manifest")
    declared_self_hash = require_sha(manifest.get("stage_manifest_sha256"), "candidate manifest stage_manifest_sha256")
    without_self_hash = {key: value for key, value in manifest.items() if key != "stage_manifest_sha256"}
    if sha256_bytes(canonical_json_bytes(without_self_hash)) != declared_self_hash:
        raise PipelineError("Candidate manifest self-hash mismatch")
    # The production snapshot is deliberately frozen at stage time.  A later
    # idempotent re-commit may see the already-promoted bytes, so compare all
    # deterministic rendering/provenance fields here and validate destination
    # drift separately in commit_stage().
    ignored = ("staged_at", "stage_manifest_sha256", "target_snapshot")
    core = {key: value for key, value in manifest.items() if key not in ignored}
    fresh_core = {key: value for key, value in plan.manifest.items() if key != "target_snapshot"}
    if core != fresh_core:
        raise PipelineError("Candidate manifest does not match the freshly re-rendered plan")
    return manifest


def stage(config_path: Path) -> dict[str, Any]:
    config, _ = load_config(config_path)
    paths = validate_paths(config)
    plan = build_plan(config_path, require_browser_confirmation=True)
    destination = paths["staging_dir"]
    if destination.exists():
        raise PipelineError(f"Staging collision: {destination} already exists; archive/remove it explicitly before restaging")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.{uuid.uuid4().hex}.tmp")
    if temporary.exists():
        raise PipelineError(f"Unexpected staging temporary collision: {temporary}")
    try:
        for relative, rendered in {**plan.pose_files, **plan.strip_files, **plan.qa_files}.items():
            output = temporary / Path(relative)
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(rendered.data)
        staged_manifest = {**plan.manifest, "staged_at": utc_now()}
        # stage_manifest_sha256 intentionally hashes the manifest without its self-hash field
        staged_manifest["stage_manifest_sha256"] = sha256_bytes(canonical_json_bytes(staged_manifest))
        (temporary / "candidate_manifest.json").write_bytes(canonical_json_bytes(staged_manifest))
        # Validate the temporary tree manually before the one-directory rename.
        actual = {path.relative_to(temporary).as_posix() for path in temporary.rglob("*") if path.is_file()}
        if actual != _expected_stage_files(plan):
            raise PipelineError("Temporary stage file set is incomplete")
        for relative, rendered in {**plan.pose_files, **plan.strip_files, **plan.qa_files}.items():
            if sha256_file(temporary / Path(relative)) != rendered.sha256:
                raise PipelineError(f"Temporary staged output hash mismatch: {relative}")
        os.replace(temporary, destination)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    # Fresh render and full stage readback after atomic rename.
    validate_stage_tree(destination, plan)
    return {
        "passed": True,
        "mode": "stage",
        "batch_id": plan.manifest["batch_id"],
        "staging_dir": relative_to_root(destination),
        "candidate_manifest": relative_to_root(destination / "candidate_manifest.json"),
        "counts": plan.manifest["counts"],
        "production_written": False,
    }


def _validate_approval(config: dict[str, Any], paths: dict[str, Path], stage_manifest_path: Path) -> dict[str, Any]:
    receipt_path = paths["approval_receipt"]
    receipt = load_json(receipt_path, "commit approval receipt")
    if receipt.get("schema_version") != 1 or receipt.get("kind") != "skirmish_direction4_action_commit_approval":
        raise PipelineError("Unsupported commit approval receipt schema/kind")
    if receipt.get("batch_id") != config["batch_id"] or receipt.get("approved") is not True:
        raise PipelineError("Commit approval receipt does not approve this batch")
    if receipt.get("stage_manifest_sha256") != sha256_file(stage_manifest_path):
        raise PipelineError("Commit approval receipt is not bound to this exact staged manifest")
    for key in ("approved_by", "approved_at", "visual_review_note"):
        if not isinstance(receipt.get(key), str) or not receipt[key].strip():
            raise PipelineError(f"Commit approval receipt requires {key}")
    return receipt


def _snapshot_file(path: Path) -> dict[str, Any]:
    if path.exists():
        if not path.is_file() or _is_reparse(path):
            raise PipelineError(f"Transaction path is not a safe regular file: {path}")
        return {"exists": True, "sha256": sha256_file(path)}
    return {"exists": False, "sha256": None}


def _write_journal(path: Path, journal: dict[str, Any]) -> None:
    atomic_write(path, canonical_json_bytes(journal))


def _rollback_transaction(journal_path: Path, journal: dict[str, Any]) -> None:
    errors: list[str] = []
    preserved_external: list[str] = []
    applied = set(journal.get("applied", []))
    for entry in reversed(journal["entries"]):
        target = Path(entry["target"])
        temporary = Path(entry["temporary"])
        try:
            current = _snapshot_file(target)
            before = entry["before"]
            if current == before:
                pass
            elif current["exists"] and current["sha256"] == entry["after_sha256"]:
                if before["exists"]:
                    backup = Path(entry["backup"])
                    if not backup.is_file() or sha256_file(backup) != before["sha256"]:
                        raise PipelineError(f"Rollback backup missing or changed: {backup}")
                    restore_tmp = target.with_name(f".{target.name}.{journal['transaction_id']}.restore")
                    shutil.copy2(backup, restore_tmp)
                    os.replace(restore_tmp, target)
                else:
                    target.unlink()
            elif str(target) in applied:
                # Something modified an already-applied output after our replace.
                # Preserve it rather than destructively guessing which bytes win.
                raise PipelineError(f"Applied target now has an unknown external state; preserved: {target}")
            else:
                # This target was never recorded as applied and no longer matches
                # either baseline or our staged bytes.  Preserve the external
                # change while still rolling back every output we can identify.
                preserved_external.append(str(target))
            if temporary.exists():
                if not temporary.is_file() or _is_reparse(temporary):
                    raise PipelineError(f"Rollback refuses unsafe temporary: {temporary}")
                temporary.unlink()
        except Exception as error:  # retain every rollback error in the durable journal
            errors.append(f"{target}: {error}")
    journal["status"] = "ROLLBACK_FAILED" if errors else "ROLLED_BACK"
    journal["rolled_back_at"] = utc_now()
    journal["rollback_errors"] = errors
    journal["rollback_preserved_external"] = preserved_external
    _write_journal(journal_path, journal)
    if errors:
        raise PipelineError(f"Rollback incomplete; inspect {journal_path}: {errors}")


def pending_journals(checkpoint_root: Path) -> list[Path]:
    if not checkpoint_root.exists():
        return []
    result: list[Path] = []
    for path in checkpoint_root.glob("*/journal.json"):
        try:
            status = load_json(path, "transaction journal").get("status")
        except PipelineError:
            result.append(path)
            continue
        if status in ("PREPARING", "PREPARED", "COMMITTING", "ROLLBACK_FAILED"):
            result.append(path)
    return sorted(result)


def validate_journal_scope(
    journal_path: Path,
    journal: dict[str, Any],
    config: dict[str, Any],
    paths: dict[str, Path],
) -> None:
    if not is_within(journal_path, paths["checkpoint_root"]) or _is_reparse(journal_path):
        raise PipelineError(f"Transaction journal is outside the configured checkpoint root: {journal_path}")
    if journal.get("schema_version") != 1 or journal.get("kind") != "skirmish_direction4_action_commit_journal":
        raise PipelineError(f"Unsupported transaction journal schema/kind: {journal_path}")
    if journal.get("batch_id") != config["batch_id"]:
        raise PipelineError(f"Transaction journal belongs to another batch: {journal_path}")
    transaction_id = str(journal.get("transaction_id", ""))
    if not transaction_id or journal_path.parent.name != transaction_id:
        raise PipelineError(f"Transaction id/path mismatch: {journal_path}")
    expected_targets = {
        str((paths["production_root"] / f"{unit}_{action}_{direction}.png").resolve())
        for unit in UNITS for direction in DIRECTIONS for action in ACTION_RECIPES
    }
    expected_targets.add(str(paths["commit_manifest"].resolve()))
    entries = journal.get("entries")
    if not isinstance(entries, list) or len(entries) != len(expected_targets):
        raise PipelineError(f"Transaction journal must contain exactly {len(expected_targets)} entries")
    actual_targets: set[str] = set()
    backup_root = journal_path.parent / "backups"
    for entry in entries:
        if not isinstance(entry, dict):
            raise PipelineError("Transaction journal entry must be an object")
        target = Path(str(entry.get("target", "")))
        temporary = Path(str(entry.get("temporary", "")))
        backup = Path(str(entry.get("backup", "")))
        target_text = str(target.resolve(strict=False))
        if target_text not in expected_targets or target_text in actual_targets:
            raise PipelineError(f"Transaction journal has an unknown or repeated target: {target}")
        actual_targets.add(target_text)
        if temporary.parent.resolve(strict=False) != target.parent.resolve(strict=False) or temporary.name != f".{target.name}.{transaction_id}.tmp":
            raise PipelineError(f"Transaction temporary path is not the exact target sibling: {temporary}")
        if not is_within(backup, backup_root):
            raise PipelineError(f"Transaction backup escapes its checkpoint: {backup}")
        before = entry.get("before")
        if not isinstance(before, dict) or not isinstance(before.get("exists"), bool):
            raise PipelineError(f"Transaction before snapshot is invalid: {target}")
        if before["exists"]:
            require_sha(before.get("sha256"), f"journal before {target}")
        elif before.get("sha256") is not None:
            raise PipelineError(f"Absent journal target must have null before hash: {target}")
        require_sha(entry.get("after_sha256"), f"journal after {target}")
    if actual_targets != expected_targets:
        raise PipelineError("Transaction journal exact target set mismatch")
    applied = journal.get("applied", [])
    if not isinstance(applied, list) or not set(applied).issubset(actual_targets):
        raise PipelineError("Transaction journal applied list is invalid")


def recover_transactions(config_path: Path) -> dict[str, Any]:
    config, _ = load_config(config_path)
    paths = validate_paths(config)
    pending = pending_journals(paths["checkpoint_root"])
    recovered: list[str] = []
    for journal_path in pending:
        journal = load_json(journal_path, "transaction journal")
        validate_journal_scope(journal_path, journal, config, paths)
        _rollback_transaction(journal_path, journal)
        recovered.append(relative_to_root(journal_path))
    return {"passed": True, "mode": "recover", "recovered": recovered, "count": len(recovered)}


def commit_stage(
    config_path: Path,
    *,
    allow_replace_approved_targets: bool,
    _failure_after: int | None = None,
) -> dict[str, Any]:
    config, _ = load_config(config_path)
    paths = validate_paths(config)
    pending = pending_journals(paths["checkpoint_root"])
    if pending:
        raise PipelineError(f"Pending transaction must be recovered first: {pending[0]}")
    plan = build_plan(config_path, require_browser_confirmation=True)
    stage_manifest_path = paths["staging_dir"] / "candidate_manifest.json"
    staged_manifest = validate_stage_tree(paths["staging_dir"], plan)
    receipt = _validate_approval(config, paths, stage_manifest_path)

    # Recheck the exact production baseline captured during staging.
    strip_by_target = {record["target_file"]: record for record in plan.manifest["strips"]}
    replacements_needed = False
    commit_baseline: dict[str, dict[str, Any]] = {}
    for target_name, before in staged_manifest["target_snapshot"].items():
        current = _snapshot_file(paths["production_root"] / target_name)
        commit_baseline[target_name] = current
        staged_output_sha = strip_by_target[target_name]["sha256"]
        is_idempotent_output = current["exists"] and current["sha256"] == staged_output_sha
        if current != {"exists": before["exists"], "sha256": before["sha256"]} and not is_idempotent_output:
            raise PipelineError(f"Production target changed after staging: {target_name}")
        if before["exists"] and not before["already_identical"]:
            replacements_needed = True
    if replacements_needed and not allow_replace_approved_targets:
        raise PipelineError("Approved existing target replacements require --replace-approved-targets")

    paths["production_root"].mkdir(parents=True, exist_ok=True)
    paths["checkpoint_root"].mkdir(parents=True, exist_ok=True)
    transaction_id = f"{dt.datetime.now().strftime('%Y%m%dT%H%M%S')}_{uuid.uuid4().hex[:10]}"
    transaction_dir = paths["checkpoint_root"] / transaction_id
    backup_dir = transaction_dir / "backups"
    journal_path = transaction_dir / "journal.json"

    production_manifest = {
        "schema_version": 2,
        "kind": "skirmish_direction4_action_production_manifest",
        "batch_id": config["batch_id"],
        "committed_at": utc_now(),
        "transaction_id": transaction_id,
        "candidate_manifest": {"file": relative_to_root(stage_manifest_path), "sha256": sha256_file(stage_manifest_path)},
        "approval_receipt": {"file": relative_to_root(paths["approval_receipt"]), "sha256": sha256_file(paths["approval_receipt"]), "approved_by": receipt["approved_by"], "approved_at": receipt["approved_at"]},
        "semantic_anchors": plan.manifest["semantic_anchors"],
        "source_chain": plan.manifest["sources"],
        "outputs": [
            {"target": record["target_file"], "sha256": record["sha256"], "state": record["state"], "unit": record["unit"], "direction": record["direction"], "recipe": record["recipe"]}
            for record in plan.manifest["strips"]
        ],
        "processing_contract": plan.manifest["processing_contract"],
        "steam_modified_or_exported": False,
    }
    manifest_bytes = canonical_json_bytes(production_manifest)
    entries: list[dict[str, Any]] = []
    payload_files: dict[str, Path] = {}
    for target_name in sorted(strip_by_target):
        target = paths["production_root"] / target_name
        staged = paths["staging_dir"] / strip_by_target[target_name]["staged_file"]
        before = commit_baseline[target_name]
        backup = backup_dir / target_name
        temporary = target.with_name(f".{target.name}.{transaction_id}.tmp")
        if temporary.exists():
            raise PipelineError(f"Unexpected transaction temporary collision: {temporary}")
        payload_files[str(target)] = staged
        entries.append({
            "target": str(target), "temporary": str(temporary), "backup": str(backup),
            "before": before, "after_sha256": strip_by_target[target_name]["sha256"], "kind": "action_strip",
        })
    manifest_target = paths["commit_manifest"]
    manifest_before = _snapshot_file(manifest_target)
    manifest_backup = backup_dir / "__production_manifest__.json"
    manifest_tmp = manifest_target.with_name(f".{manifest_target.name}.{transaction_id}.tmp")
    if manifest_tmp.exists():
        raise PipelineError(f"Unexpected transaction temporary collision: {manifest_tmp}")
    entries.append({
        "target": str(manifest_target), "temporary": str(manifest_tmp), "backup": str(manifest_backup),
        "before": manifest_before, "after_sha256": sha256_bytes(manifest_bytes), "kind": "production_manifest",
    })
    journal = {
        "schema_version": 1,
        "kind": "skirmish_direction4_action_commit_journal",
        "batch_id": config["batch_id"],
        "transaction_id": transaction_id,
        "status": "PREPARING",
        "preparing_at": utc_now(),
        "entries": entries,
        "applied": [],
    }
    backup_dir.mkdir(parents=True, exist_ok=False)
    _write_journal(journal_path, journal)
    validate_journal_scope(journal_path, journal, config, paths)
    try:
        # Prepare every backup and same-directory temporary only after the
        # durable PREPARING journal exists.  A crash at any following point is
        # recoverable without guessing the intended exact target set.
        for entry in entries:
            target = Path(entry["target"])
            backup = Path(entry["backup"])
            temporary = Path(entry["temporary"])
            target.parent.mkdir(parents=True, exist_ok=True)
            if entry["before"]["exists"]:
                backup.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(target, backup)
                if sha256_file(backup) != entry["before"]["sha256"]:
                    raise PipelineError(f"Could not freeze transaction backup: {target}")
            if entry["kind"] == "action_strip":
                shutil.copy2(payload_files[str(target)], temporary)
            else:
                temporary.parent.mkdir(parents=True, exist_ok=True)
                temporary.write_bytes(manifest_bytes)
            if sha256_file(temporary) != entry["after_sha256"]:
                raise PipelineError(f"Prepared transaction copy hash mismatch: {target}")
        journal["status"] = "PREPARED"
        journal["prepared_at"] = utc_now()
        _write_journal(journal_path, journal)
        journal["status"] = "COMMITTING"
        _write_journal(journal_path, journal)
        for index, entry in enumerate(entries, 1):
            current = _snapshot_file(Path(entry["target"]))
            if current != entry["before"]:
                raise PipelineError(f"Target changed during transaction preparation: {entry['target']}")
            os.replace(entry["temporary"], entry["target"])
            if sha256_file(Path(entry["target"])) != entry["after_sha256"]:
                raise PipelineError(f"Post-replace hash mismatch: {entry['target']}")
            if _failure_after is not None and index == _failure_after:
                # Deliberately fail before the applied list is journaled.  The
                # rollback must identify our bytes by after_sha256 and recover
                # even across this narrow crash window.
                raise PipelineError(f"Injected self-test failure after replace {index}")
            journal["applied"].append(entry["target"])
            _write_journal(journal_path, journal)
        journal["status"] = "COMMITTED"
        journal["committed_at"] = utc_now()
        _write_journal(journal_path, journal)
    except Exception as error:
        try:
            _rollback_transaction(journal_path, journal)
        except Exception as rollback_error:
            raise PipelineError(f"Commit failed ({error}); rollback also failed ({rollback_error})") from rollback_error
        raise PipelineError(f"Commit failed and was rolled back: {error}") from error
    return {
        "passed": True,
        "mode": "commit",
        "batch_id": config["batch_id"],
        "outputs": 48,
        "production_manifest": relative_to_root(manifest_target),
        "transaction_journal": relative_to_root(journal_path),
        "transaction_status": "COMMITTED",
    }


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("dry-run", "stage"):
        child = subparsers.add_parser(command)
        child.add_argument("--config", required=True, type=Path)
    commit_parser = subparsers.add_parser("commit")
    commit_parser.add_argument("--config", required=True, type=Path)
    commit_parser.add_argument("--confirm", required=True)
    commit_parser.add_argument("--replace-approved-targets", action="store_true")
    recover_parser = subparsers.add_parser("recover")
    recover_parser.add_argument("--config", required=True, type=Path)
    recover_parser.add_argument("--confirm", required=True)
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if args.command == "dry-run":
            result = dry_run(args.config)
        elif args.command == "stage":
            result = stage(args.config)
        elif args.command == "commit":
            if args.confirm != CONFIRM_COMMIT:
                raise PipelineError(f"Commit confirmation phrase must be exactly {CONFIRM_COMMIT}")
            result = commit_stage(args.config, allow_replace_approved_targets=args.replace_approved_targets)
        else:
            if args.confirm != CONFIRM_RECOVER:
                raise PipelineError(f"Recovery confirmation phrase must be exactly {CONFIRM_RECOVER}")
            result = recover_transactions(args.config)
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
        return 0
    except PipelineError as error:
        print(json.dumps({"passed": False, "mode": args.command, "error": str(error)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
