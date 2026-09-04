"""Strictly validate and atomically ingest Web ChatGPT environment artwork.

The reviewed prompt contract lives outside the repository in
``../implementation_20260902/environment_prompt_drafts_v2``.  This command
does not open a browser, generate artwork, run Godot, or infer missing
production routes.

The default mode is a read-only dry run.  A commit is allowed only when every
adopted source passes objective and human-review gates and every runtime output
has an explicit target in the production mapping.  Opaque surfaces are copied
byte-for-byte.  Atlas cells are processed only as fixed 512px rectangles,
optionally uniformly scaled, and placed on transparent canvases.  There is no
component extraction, mirroring, repainting, direction synthesis, alpha mask,
foreign-pixel clearing, or baked-shadow repair path in this module.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import io
import json
import math
import os
import re
import shutil
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlsplit

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BATCH_MANIFEST = (
    ROOT.parent
    / "implementation_20260902"
    / "environment_prompt_drafts_v2"
    / "environment_batch_manifest.json"
)
DEFAULT_MAPPING_MANIFEST = ROOT / "tools/environment_production_mapping.template.json"
FROZEN_BATCH_MANIFEST_SHA256 = (
    "162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf"
)
FROZEN_STATIC_SELF_CHECK_SHA256 = (
    "f8e562d4aeebbd64519acf83ecfb54385742b3d7f89dd72684149a953386aa77"
)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SURFACE_CATEGORY = "opaque_tileable_surface"
ATLAS_CATEGORIES = {"transparent_object_atlas_4x4", "transparent_overlay_atlas_4x4"}
EXPECTED_CATEGORY_COUNTS = {
    SURFACE_CATEGORY: 5,
    "transparent_object_atlas_4x4": 3,
    "transparent_overlay_atlas_4x4": 1,
}

SURFACE_REVIEW_FLAGS = (
    "three_by_three_wrap_has_no_visible_seam_vignette_hotspot_or_directional_band",
    "no_forbidden_scene_content",
    "gameplay_zoom_100_and_150_readable",
    "prompt_specific_acceptance_confirmed",
)
ATLAS_REVIEW_FLAGS = (
    "cell_map_and_scale_confirmed",
    "whole_cell_rectangles_only_confirmed",
    "no_mirror_repaint_synthesis_mask_or_pixel_clear_needed",
    "no_forbidden_base_shadow_text_watermark_or_modern_content",
    "isometric_scale_silhouette_and_anchor_confirmed",
    "prompt_specific_acceptance_confirmed",
)


class IntakeError(RuntimeError):
    """A provenance, contract, mapping, or transaction error."""


@dataclass(frozen=True)
class EnvironmentContract:
    batch_manifest: Path
    batch_sha256: str
    static_self_check: Path
    static_self_check_sha256: str
    data: dict[str, Any]
    batches: tuple["Batch", ...]
    surface_size: tuple[int, int]
    edge_band_px: int
    edge_mean_max: float
    wrap_ratio_max: float
    atlas_size: tuple[int, int]
    atlas_grid: tuple[int, int]
    cell_size: tuple[int, int]
    outer_border_px: int
    vertical_bands: tuple[tuple[int, int], ...]
    horizontal_bands: tuple[tuple[int, int], ...]


@dataclass(frozen=True)
class Batch:
    order: int
    batch_id: str
    category: str
    prompt_path: Path
    prompt_sha256: str
    campaign_usage: tuple[str, ...]
    code_targets: tuple[str, ...]
    cell_map: tuple[tuple[str, ...], ...]
    declared_cell_routes: tuple["DeclaredCellRoute", ...]


@dataclass(frozen=True)
class DeclaredCellRoute:
    row: int
    column: int
    content: str
    output_id: str
    output_path: str
    level_scope: tuple[str, ...]
    route_scope: str
    reuse_policy: str
    resolver: str
    route_key: str
    state: str


@dataclass(frozen=True)
class SourceEntry:
    batch: Batch
    source_path: Path
    source_sha256: str
    conversation_url: str
    prompt_sha256: str
    decision: str
    reason: str
    human_review: dict[str, Any]
    declared_size: tuple[int, int]


@dataclass(frozen=True)
class CellRoute:
    row: int
    column: int
    label: str
    output_id: str | None
    level_scope: tuple[str, ...]
    route_scope: str
    reuse_policy: str
    resolver: str
    route_key: str
    state: str
    integration_ready: bool
    integration_evidence: tuple[str, ...]
    target_raw: str | None
    target: Path | None
    canvas_size: tuple[int, int]
    scaled_size: tuple[int, int]
    offset: tuple[int, int]


@dataclass(frozen=True)
class BatchRoute:
    batch_id: str
    mode: str
    target_raw: str | None
    target: Path | None
    cells: tuple[CellRoute, ...]
    output_id: str | None = None
    level_scope: tuple[str, ...] = ()
    route_scope: str = ""
    reuse_policy: str = ""
    resolver: str = ""
    route_key: str = ""
    integration_ready: bool = False
    integration_evidence: tuple[str, ...] = ()


@dataclass(frozen=True)
class Mapping:
    path: Path
    sha256: str
    data: dict[str, Any]
    archive_root: Path
    provenance_target: Path
    routes: dict[str, BatchRoute]
    runtime_router_contract: dict[str, Any]


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise IntakeError(f"{label} does not exist: {path}") from error
    except json.JSONDecodeError as error:
        raise IntakeError(f"{label} is invalid JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise IntakeError(f"{label} must contain one JSON object: {path}")
    return value


def expect_sha(value: Any, label: str) -> str:
    text = str(value).strip().lower()
    if SHA256_RE.fullmatch(text) is None:
        raise IntakeError(f"{label} must be a lowercase SHA-256 digest")
    return text


def expect_pair(value: Any, label: str, *, allow_zero: bool = False) -> tuple[int, int]:
    minimum = 0 if allow_zero else 1
    if (
        not isinstance(value, list)
        or len(value) != 2
        or any(not isinstance(item, int) or isinstance(item, bool) or item < minimum for item in value)
    ):
        qualifier = "nonnegative" if allow_zero else "positive"
        raise IntakeError(f"{label} must contain exactly two {qualifier} integers")
    return int(value[0]), int(value[1])


def expect_string_list(value: Any, label: str, *, nonempty: bool = True) -> tuple[str, ...]:
    if (
        not isinstance(value, list)
        or (nonempty and not value)
        or any(not isinstance(item, str) for item in value)
    ):
        raise IntakeError(f"{label} must be a{' nonempty' if nonempty else ''} string list")
    result = tuple(item.strip() for item in value)
    if any(not item for item in result):
        raise IntakeError(f"{label} may not contain blank entries")
    return result


def stable_conversation_url(value: Any, label: str) -> str:
    text = str(value).strip()
    parsed = urlsplit(text)
    parts = [part for part in parsed.path.split("/") if part]
    if (
        parsed.scheme != "https"
        or parsed.netloc.lower() != "chatgpt.com"
        or len(parts) != 2
        or parts[0] != "c"
        or re.fullmatch(r"[0-9A-Za-z-]{20,}", parts[1]) is None
        or parsed.query
        or parsed.fragment
        or parsed.username
        or parsed.password
        or parsed.port is not None
    ):
        raise IntakeError(
            f"{label} must be a stable https://chatgpt.com/c/... URL without query or fragment"
        )
    return text


def source_path_from(value: Any, manifest_path: Path, label: str) -> Path:
    raw = str(value).strip()
    if not raw:
        raise IntakeError(f"{label} is empty")
    path = Path(raw)
    return path.resolve() if path.is_absolute() else (manifest_path.parent / path).resolve()


def relative_to_workspace(path: Path, workspace_root: Path) -> str:
    try:
        return path.resolve().relative_to(workspace_root.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def parse_relative_target(
    value: Any,
    workspace_root: Path,
    label: str,
    *,
    required_prefix: str,
    suffix: str | None = None,
    allow_unmapped: bool = False,
    expect_directory: bool = False,
) -> tuple[str | None, Path | None]:
    if value is None or str(value).strip() == "":
        if allow_unmapped:
            return None, None
        raise IntakeError(f"{label} is not configured")
    raw = str(value).replace("\\", "/").strip()
    candidate = Path(raw)
    if candidate.is_absolute() or candidate.drive or ".." in candidate.parts:
        raise IntakeError(f"{label} must be a safe path relative to the workspace")
    if not raw.lower().startswith(required_prefix.lower().rstrip("/") + "/"):
        raise IntakeError(f"{label} must stay below {required_prefix}/")
    if suffix and candidate.suffix.lower() != suffix.lower():
        raise IntakeError(f"{label} must end in {suffix}")
    resolved = (workspace_root / candidate).resolve()
    try:
        resolved.relative_to(workspace_root.resolve())
    except ValueError as error:
        raise IntakeError(f"{label} resolves outside the workspace") from error
    if resolved.is_symlink():
        raise IntakeError(f"{label} may not target a symbolic link")
    if resolved.exists():
        if expect_directory and not resolved.is_dir():
            raise IntakeError(f"{label} must name a directory")
        if not expect_directory and resolved.is_dir():
            raise IntakeError(f"{label} names an existing directory")
    return candidate.as_posix(), resolved


def load_contract(path: Path) -> EnvironmentContract:
    path = path.resolve()
    data = load_json(path, "environment batch manifest")
    if data.get("schema_version") != 2:
        raise IntakeError("environment batch manifest schema_version must be 2")
    batch_sha256 = sha256_file(path)
    if batch_sha256 != FROZEN_BATCH_MANIFEST_SHA256:
        raise IntakeError(
            "environment batch manifest is not the frozen reviewed contract: "
            f"{batch_sha256} != {FROZEN_BATCH_MANIFEST_SHA256}"
        )
    raw_batches = data.get("send_order")
    if not isinstance(raw_batches, list) or len(raw_batches) != 9:
        raise IntakeError("environment batch manifest must define exactly nine send_order entries")
    static_self_check = path.parent / "static_self_check.json"
    if not static_self_check.is_file():
        raise IntakeError(f"environment prompt static self-check is missing: {static_self_check}")
    static_self_check_sha256 = sha256_file(static_self_check)
    if static_self_check_sha256 != FROZEN_STATIC_SELF_CHECK_SHA256:
        raise IntakeError(
            "environment prompt static self-check is not the frozen reviewed evidence: "
            f"{static_self_check_sha256} != {FROZEN_STATIC_SELF_CHECK_SHA256}"
        )
    static_data = load_json(static_self_check, "environment prompt static self-check")
    raw_static_checks = static_data.get("checks")
    if (
        static_data.get("passed") is not True
        or static_data.get("prompt_count") != 9
        or static_data.get("routed_atlas_count") != 4
        or static_data.get("routed_cell_count") != 64
        or static_data.get("manifest_sha256") != batch_sha256
        or static_data.get("failures") != []
        or not isinstance(raw_static_checks, list)
        or len(raw_static_checks) != 502
        or any(not isinstance(check, dict) or check.get("passed") is not True for check in raw_static_checks)
    ):
        raise IntakeError("environment prompt static self-check must be 502/502 PASS for this exact manifest")

    edge = data.get("edge_test_contract")
    grid = data.get("atlas_grid_contract")
    if not isinstance(edge, dict) or not isinstance(grid, dict):
        raise IntakeError("environment batch manifest is missing edge/grid contracts")
    surface_size = expect_pair(edge.get("surface_dimensions"), "edge_test_contract.surface_dimensions")
    if surface_size != (2048, 2048) or edge.get("opaque_alpha_required") is not True:
        raise IntakeError("surface contract must require exact 2048x2048 opaque RGBA sources")
    if edge.get("repeat_grid") != "3x3":
        raise IntakeError("surface repeat_grid must be 3x3")
    edge_band = int(edge.get("opposite_edge_band_px", -1))
    edge_mean_max = float(edge.get("opposite_edge_mean_rgb_delta_max_255", -1))
    ratio_max = float(edge.get("wrap_gradient_max_ratio_to_internal_p95", -1))
    if edge_band != 16 or edge_mean_max != 10.0 or ratio_max != 1.25:
        raise IntakeError("surface edge contract no longer matches the approved 16px/10/1.25 gate")

    atlas_size = expect_pair(grid.get("dimensions"), "atlas_grid_contract.dimensions")
    atlas_grid = expect_pair(grid.get("grid"), "atlas_grid_contract.grid")
    cell_size = expect_pair(grid.get("cell_px"), "atlas_grid_contract.cell_px")
    outer = int(grid.get("outer_transparent_border_px", -1))
    if atlas_size != (2048, 2048) or atlas_grid != (4, 4) or cell_size != (512, 512) or outer != 24:
        raise IntakeError("atlas contract must remain 2048 RGBA, 4x4, 512px cells and a 24px border")

    def parse_bands(value: Any, label: str) -> tuple[tuple[int, int], ...]:
        if not isinstance(value, list) or len(value) != 3:
            raise IntakeError(f"{label} must define three separator bands")
        result = tuple(expect_pair(item, f"{label}[{index}]", allow_zero=True) for index, item in enumerate(value))
        if any(end < start or end - start + 1 != 32 for start, end in result):
            raise IntakeError(f"{label} bands must each be exactly 32 pixels inclusive")
        return result

    vertical = parse_bands(grid.get("vertical_alpha_zero_bands_inclusive"), "vertical bands")
    horizontal = parse_bands(grid.get("horizontal_alpha_zero_bands_inclusive"), "horizontal bands")
    if vertical != ((496, 527), (1008, 1039), (1520, 1551)) or horizontal != vertical:
        raise IntakeError("atlas separator bands no longer match the approved 4x4 grid")

    required_allowed = {"whole-cell rectangular crop", "uniform scale", "transparent padding", "Godot import"}
    allowed = set(expect_string_list(data.get("local_processing_allowed"), "local_processing_allowed"))
    if not required_allowed.issubset(allowed):
        raise IntakeError("local_processing_allowed does not retain the approved four operations")
    forbidden_text = " ".join(expect_string_list(data.get("local_processing_forbidden"), "local_processing_forbidden")).lower()
    for term in ("mirroring", "repainting", "direction synthesis", "alpha masking", "foreign-pixel clearing"):
        if term not in forbidden_text:
            raise IntakeError(f"local_processing_forbidden no longer includes {term}")

    routing_contract = data.get("routing_contract")
    if not isinstance(routing_contract, dict):
        raise IntakeError("schema v2 batch manifest must contain routing_contract")
    if (
        routing_contract.get("resolver_namespace") != "CampaignEnvironmentArt"
        or routing_contract.get("requires_active_campaign_level_id") is not True
        or routing_contract.get("reject_out_of_scope_level") is not True
        or routing_contract.get("cross_level_asset_fallback_forbidden") is not True
    ):
        raise IntakeError("routing_contract must fail closed on campaign level and cross-level fallback")
    required_route_fields = {
        "output_id",
        "output_path",
        "level_scope",
        "route_scope",
        "reuse_policy",
        "route",
    }
    if set(routing_contract.get("cell_output_fields_required", [])) != required_route_fields:
        raise IntakeError("routing_contract.cell_output_fields_required changed from the reviewed six fields")

    batches: list[Batch] = []
    seen: set[str] = set()
    counts: dict[str, int] = {key: 0 for key in EXPECTED_CATEGORY_COUNTS}
    all_declared_output_ids: set[str] = set()
    all_declared_output_paths: set[str] = set()
    for expected_order, raw in enumerate(raw_batches, 1):
        if not isinstance(raw, dict):
            raise IntakeError(f"send_order[{expected_order - 1}] must be an object")
        order = raw.get("order")
        batch_id = str(raw.get("id", "")).strip()
        category = str(raw.get("category", "")).strip()
        if order != expected_order or not batch_id or batch_id in seen:
            raise IntakeError(f"invalid order or repeated id at send_order {expected_order}: {batch_id}")
        if category not in EXPECTED_CATEGORY_COUNTS:
            raise IntakeError(f"{batch_id}: unsupported category {category}")
        prompt_filename = str(raw.get("file", "")).strip()
        prompt_path = (path.parent / prompt_filename).resolve()
        try:
            prompt_path.relative_to(path.parent.resolve())
        except ValueError as error:
            raise IntakeError(f"{batch_id}: prompt file escapes its reviewed prompt directory") from error
        if not prompt_path.is_file():
            raise IntakeError(f"{batch_id}: reviewed prompt file is missing: {prompt_path}")
        prompt_sha = expect_sha(raw.get("prompt_sha256"), f"{batch_id}.prompt_sha256")
        actual_prompt_sha = sha256_file(prompt_path)
        if actual_prompt_sha != prompt_sha:
            raise IntakeError(
                f"{batch_id}: prompt SHA mismatch; declared {prompt_sha}, actual {actual_prompt_sha}"
            )
        campaign_usage = expect_string_list(raw.get("campaign_usage"), f"{batch_id}.campaign_usage")
        code_targets = expect_string_list(raw.get("code_targets"), f"{batch_id}.code_targets")
        cell_map: tuple[tuple[str, ...], ...] = ()
        declared_routes: tuple[DeclaredCellRoute, ...] = ()
        if category in ATLAS_CATEGORIES:
            raw_map = raw.get("cell_map")
            if not isinstance(raw_map, list) or len(raw_map) != 4:
                raise IntakeError(f"{batch_id}.cell_map must contain four rows")
            rows = tuple(expect_string_list(row, f"{batch_id}.cell_map[{index}]") for index, row in enumerate(raw_map))
            if any(len(row) != 4 for row in rows):
                raise IntakeError(f"{batch_id}.cell_map rows must each contain four labels")
            if len({label for row in rows for label in row}) != 16:
                raise IntakeError(f"{batch_id}.cell_map labels must be unique within the atlas")
            cell_map = rows
            raw_cell_routes = raw.get("cell_routes")
            if not isinstance(raw_cell_routes, list) or len(raw_cell_routes) != 16:
                raise IntakeError(f"{batch_id}.cell_routes must define all sixteen schema v2 outputs")
            parsed_routes: list[DeclaredCellRoute] = []
            route_cells: set[tuple[int, int]] = set()
            route_outputs: set[str] = set()
            route_paths: set[str] = set()
            for route_index, route_raw in enumerate(raw_cell_routes):
                if not isinstance(route_raw, dict):
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}] must be an object")
                row = route_raw.get("row")
                column = route_raw.get("col")
                if (
                    not isinstance(row, int)
                    or isinstance(row, bool)
                    or not isinstance(column, int)
                    or isinstance(column, bool)
                    or not (1 <= row <= 4 and 1 <= column <= 4)
                    or (row, column) in route_cells
                ):
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}] has invalid/repeated 1-based row/col")
                route_cells.add((row, column))
                content = str(route_raw.get("content", "")).strip()
                if content != cell_map[row - 1][column - 1]:
                    raise IntakeError(
                        f"{batch_id}.cell_routes[{route_index}].content does not match cell_map[{row},{column}]"
                    )
                output_id = str(route_raw.get("output_id", "")).strip()
                if re.fullmatch(r"[a-z][a-z0-9_]*(?:[.:/-][a-z0-9_]+)*", output_id) is None:
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}].output_id is invalid")
                if output_id.casefold() in route_outputs:
                    raise IntakeError(f"{batch_id}: repeated output_id {output_id}")
                route_outputs.add(output_id.casefold())
                if output_id.casefold() in all_declared_output_ids:
                    raise IntakeError(f"schema v2 repeats output_id across atlases: {output_id}")
                all_declared_output_ids.add(output_id.casefold())
                output_path = str(route_raw.get("output_path", "")).strip().replace("\\", "/")
                if (
                    not output_path.startswith("res://assets/campaign/environment/")
                    or not output_path.lower().endswith(".png")
                    or ".." in Path(output_path.removeprefix("res://")).parts
                ):
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}].output_path is unsafe")
                if output_path.casefold() in route_paths:
                    raise IntakeError(f"{batch_id}: repeated output_path {output_path}")
                route_paths.add(output_path.casefold())
                if output_path.casefold() in all_declared_output_paths:
                    raise IntakeError(f"schema v2 repeats output_path across atlases: {output_path}")
                all_declared_output_paths.add(output_path.casefold())
                level_scope = expect_string_list(
                    route_raw.get("level_scope"), f"{batch_id}.cell_routes[{route_index}].level_scope"
                )
                if len(set(level_scope)) != len(level_scope) or any(
                    re.fullmatch(r"level[1-8]", level) is None for level in level_scope
                ):
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}].level_scope is invalid")
                route_scope = str(route_raw.get("route_scope", "")).strip()
                reuse_policy = str(route_raw.get("reuse_policy", "")).strip()
                if route_scope != "campaign_level_only" or reuse_policy not in {
                    "level_scoped_only",
                    "shared_source_with_explicit_level_gate",
                }:
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}] has an unsafe route/reuse policy")
                route = route_raw.get("route")
                if not isinstance(route, dict):
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}].route must be an object")
                resolver = str(route.get("resolver", "")).strip()
                route_key = str(route.get("route_key", "")).strip()
                state = str(route_raw.get("state", "default")).strip()
                route_levels = tuple(route.get("level_scope", []))
                if (
                    resolver
                    not in {
                        "CampaignEnvironmentArt.object",
                        "CampaignEnvironmentArt.overlay",
                        "CampaignEnvironmentArt.static_flag",
                    }
                    or route.get("requires_level_id") is not True
                    or route.get("global_alias_forbidden") is not True
                    or route_levels != level_scope
                    or re.fullmatch(r"[a-z][a-z0-9_]*", route_key) is None
                    or re.fullmatch(r"[a-z][a-z0-9_]*", state) is None
                ):
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}].route is not fail-closed")
                if category == "transparent_overlay_atlas_4x4" and resolver != "CampaignEnvironmentArt.overlay":
                    raise IntakeError(f"{batch_id}.cell_routes[{route_index}] overlay atlas must use overlay resolver")
                parsed_routes.append(
                    DeclaredCellRoute(
                        row,
                        column,
                        content,
                        output_id,
                        output_path,
                        level_scope,
                        route_scope,
                        reuse_policy,
                        resolver,
                        route_key,
                        state,
                    )
                )
            parsed_routes.sort(key=lambda item: (item.row, item.column))
            declared_routes = tuple(parsed_routes)
        elif raw.get("cell_map") not in (None, []):
            raise IntakeError(f"{batch_id}: opaque surfaces may not define a cell_map")
        elif raw.get("cell_routes") not in (None, []):
            raise IntakeError(f"{batch_id}: opaque surfaces may not define cell_routes")
        batches.append(
            Batch(
                order=expected_order,
                batch_id=batch_id,
                category=category,
                prompt_path=prompt_path,
                prompt_sha256=prompt_sha,
                campaign_usage=campaign_usage,
                code_targets=code_targets,
                cell_map=cell_map,
                declared_cell_routes=declared_routes,
            )
        )
        seen.add(batch_id)
        counts[category] += 1
    if counts != EXPECTED_CATEGORY_COUNTS:
        raise IntakeError(f"unexpected environment category counts: {counts}")

    return EnvironmentContract(
        batch_manifest=path,
        batch_sha256=batch_sha256,
        static_self_check=static_self_check,
        static_self_check_sha256=static_self_check_sha256,
        data=data,
        batches=tuple(batches),
        surface_size=surface_size,
        edge_band_px=edge_band,
        edge_mean_max=edge_mean_max,
        wrap_ratio_max=ratio_max,
        atlas_size=atlas_size,
        atlas_grid=atlas_grid,
        cell_size=cell_size,
        outer_border_px=outer,
        vertical_bands=vertical,
        horizontal_bands=horizontal,
    )


def load_sources(path: Path, contract: EnvironmentContract) -> tuple[dict[str, Any], dict[str, SourceEntry]]:
    path = path.resolve()
    data = load_json(path, "environment source manifest")
    if data.get("schema_version") != 1 or data.get("kind") != "web_chatgpt_environment_sources":
        raise IntakeError("source manifest must use schema 1 and kind web_chatgpt_environment_sources")
    raw_entries = data.get("entries")
    if not isinstance(raw_entries, list) or not raw_entries:
        raise IntakeError("source manifest must contain at least one source entry")
    expected = {batch.batch_id: batch for batch in contract.batches}
    result: dict[str, SourceEntry] = {}
    hashes: set[str] = set()
    for index, raw in enumerate(raw_entries):
        if not isinstance(raw, dict):
            raise IntakeError(f"entries[{index}] must be an object")
        batch_id = str(raw.get("id", "")).strip()
        if batch_id not in expected or batch_id in result:
            raise IntakeError(f"entries[{index}] has unknown or repeated id: {batch_id}")
        batch = expected[batch_id]
        decision = str(raw.get("decision", "")).strip().lower()
        if decision not in ("adopt", "reject"):
            raise IntakeError(f"{batch_id}.decision must be adopt or reject")
        reason = str(raw.get("reason", "")).strip()
        if len(reason) < 4:
            raise IntakeError(f"{batch_id}.reason must record a concrete adoption or rejection reason")
        review = raw.get("human_review")
        if not isinstance(review, dict):
            raise IntakeError(f"{batch_id}.human_review must be an object")
        required_flags = SURFACE_REVIEW_FLAGS if batch.category == SURFACE_CATEGORY else ATLAS_REVIEW_FLAGS
        missing_flags = [flag for flag in required_flags if not isinstance(review.get(flag), bool)]
        if missing_flags:
            raise IntakeError(f"{batch_id}.human_review lacks explicit boolean flags: {missing_flags}")
        reviewed_at = str(review.get("reviewed_at", "")).strip()
        notes = str(review.get("notes", "")).strip()
        if not reviewed_at or len(notes) < 2:
            raise IntakeError(f"{batch_id}.human_review must record reviewed_at and notes")
        try:
            reviewed_time = datetime.fromisoformat(reviewed_at.replace("Z", "+00:00"))
        except ValueError as error:
            raise IntakeError(f"{batch_id}.human_review.reviewed_at must be ISO-8601") from error
        if reviewed_time.tzinfo is None or reviewed_time.utcoffset() is None:
            raise IntakeError(f"{batch_id}.human_review.reviewed_at must include a UTC offset")
        if decision == "adopt" and any(review[flag] is not True for flag in required_flags):
            raise IntakeError(f"{batch_id}: every human review flag must be true for an adopted source")
        source_sha = expect_sha(raw.get("source_sha256"), f"{batch_id}.source_sha256")
        if source_sha in hashes:
            raise IntakeError(f"{batch_id}: source SHA is repeated across environment batches")
        hashes.add(source_sha)
        prompt_sha = expect_sha(raw.get("prompt_sha256"), f"{batch_id}.prompt_sha256")
        if prompt_sha != batch.prompt_sha256:
            raise IntakeError(f"{batch_id}: source prompt SHA does not match the reviewed exact prompt")
        expected_size = contract.surface_size if batch.category == SURFACE_CATEGORY else contract.atlas_size
        declared_size = expect_pair(raw.get("size"), f"{batch_id}.size")
        if declared_size != expected_size:
            raise IntakeError(f"{batch_id}.size must be exactly {list(expected_size)}")
        result[batch_id] = SourceEntry(
            batch=batch,
            source_path=source_path_from(raw.get("source_png"), path, f"{batch_id}.source_png"),
            source_sha256=source_sha,
            conversation_url=stable_conversation_url(raw.get("conversation_url"), f"{batch_id}.conversation_url"),
            prompt_sha256=prompt_sha,
            decision=decision,
            reason=reason,
            human_review=review,
            declared_size=declared_size,
        )
    return data, result


def _gradient_histogram(rgb: np.ndarray, axis: int) -> tuple[np.ndarray, int]:
    # RGB integer absolute-difference sums are in [0, 765].  A histogram gives
    # an exact combined percentile without allocating one very large float array.
    delta = np.abs(np.diff(rgb.astype(np.int16), axis=axis)).sum(axis=2)
    histogram = np.bincount(delta.reshape(-1), minlength=766)
    return histogram, int(delta.size)


def _histogram_percentile(histogram: np.ndarray, count: int, percentile: float) -> float:
    if count <= 0:
        return 0.0
    rank = max(0, math.ceil(percentile * count) - 1)
    index = int(np.searchsorted(np.cumsum(histogram), rank + 1, side="left"))
    return index / 3.0


def inspect_surface(array: np.ndarray, contract: EnvironmentContract) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    alpha = array[:, :, 3]
    alpha_min = int(alpha.min())
    alpha_max = int(alpha.max())
    if alpha_min != 255 or alpha_max != 255:
        failures.append(f"surface alpha must be 255 everywhere; extrema are {alpha_min}..{alpha_max}")
    rgb = array[:, :, :3]
    band = contract.edge_band_px
    left_right_mean = float(
        np.abs(rgb[:, :band].astype(np.int16) - rgb[:, -band:].astype(np.int16)).mean()
    )
    top_bottom_mean = float(
        np.abs(rgb[:band].astype(np.int16) - rgb[-band:].astype(np.int16)).mean()
    )
    if left_right_mean > contract.edge_mean_max:
        failures.append(
            f"left/right 16px mean RGB delta {left_right_mean:.4f} exceeds {contract.edge_mean_max:g}"
        )
    if top_bottom_mean > contract.edge_mean_max:
        failures.append(
            f"top/bottom 16px mean RGB delta {top_bottom_mean:.4f} exceeds {contract.edge_mean_max:g}"
        )

    horizontal_hist, horizontal_count = _gradient_histogram(rgb, axis=1)
    vertical_hist, vertical_count = _gradient_histogram(rgb, axis=0)
    internal_hist = horizontal_hist + vertical_hist
    internal_p95 = _histogram_percentile(internal_hist, horizontal_count + vertical_count, 0.95)
    boundary_delta = np.concatenate(
        (
            np.abs(rgb[:, -1].astype(np.int16) - rgb[:, 0].astype(np.int16)).sum(axis=1),
            np.abs(rgb[-1].astype(np.int16) - rgb[0].astype(np.int16)).sum(axis=1),
        )
    )
    boundary_hist = np.bincount(boundary_delta.reshape(-1), minlength=766)
    boundary_p95 = _histogram_percentile(boundary_hist, int(boundary_delta.size), 0.95)
    if internal_p95 == 0.0:
        wrap_ratio = 0.0 if boundary_p95 == 0.0 else math.inf
    else:
        wrap_ratio = boundary_p95 / internal_p95
    if wrap_ratio > contract.wrap_ratio_max:
        ratio_text = "infinite" if math.isinf(wrap_ratio) else f"{wrap_ratio:.6f}"
        failures.append(
            f"wrap-boundary p95/internal p95 gradient ratio {ratio_text} exceeds {contract.wrap_ratio_max:g}"
        )
    report = {
        "alpha_extrema": [alpha_min, alpha_max],
        "virtual_repeat_grid": [3, 3],
        "virtual_repeat_dimensions": [contract.surface_size[0] * 3, contract.surface_size[1] * 3],
        "opposite_edge_band_px": band,
        "left_right_band_mean_rgb_delta_255": round(left_right_mean, 6),
        "top_bottom_band_mean_rgb_delta_255": round(top_bottom_mean, 6),
        "opposite_edge_mean_rgb_delta_max_255": contract.edge_mean_max,
        "internal_adjacent_pixel_gradient_p95_255": round(internal_p95, 6),
        "wrap_boundary_adjacent_pixel_gradient_p95_255": round(boundary_p95, 6),
        "wrap_gradient_ratio_to_internal_p95": None if math.isinf(wrap_ratio) else round(wrap_ratio, 6),
        "wrap_gradient_ratio_is_infinite": math.isinf(wrap_ratio),
        "wrap_gradient_max_ratio": contract.wrap_ratio_max,
        "metric_definition": "Per-adjacency RGB absolute-difference mean; combined horizontal/vertical p95.",
    }
    return report, failures


def _alpha_bbox(alpha: np.ndarray) -> list[int] | None:
    ys, xs = np.nonzero(alpha)
    if xs.size == 0:
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]


def inspect_atlas(array: np.ndarray, batch: Batch, contract: EnvironmentContract) -> tuple[dict[str, Any], list[str]]:
    failures: list[str] = []
    alpha = array[:, :, 3]
    alpha_min = int(alpha.min())
    alpha_max = int(alpha.max())
    if alpha_min != 0 or alpha_max == 0:
        failures.append(f"atlas must contain exact transparent and visible pixels; alpha extrema are {alpha_min}..{alpha_max}")
    border = contract.outer_border_px
    border_nonzero = {
        "top": int(np.count_nonzero(alpha[:border, :])),
        "bottom": int(np.count_nonzero(alpha[-border:, :])),
        "left": int(np.count_nonzero(alpha[:, :border])),
        "right": int(np.count_nonzero(alpha[:, -border:])),
    }
    for side, count in border_nonzero.items():
        if count:
            failures.append(f"outer {side} {border}px border contains {count} nonzero-alpha pixels")
    vertical_counts = []
    for start, end in contract.vertical_bands:
        count = int(np.count_nonzero(alpha[:, start : end + 1]))
        vertical_counts.append({"inclusive": [start, end], "nonzero_alpha_pixels": count})
        if count:
            failures.append(f"vertical separator {start}..{end} contains {count} nonzero-alpha pixels")
    horizontal_counts = []
    for start, end in contract.horizontal_bands:
        count = int(np.count_nonzero(alpha[start : end + 1, :]))
        horizontal_counts.append({"inclusive": [start, end], "nonzero_alpha_pixels": count})
        if count:
            failures.append(f"horizontal separator {start}..{end} contains {count} nonzero-alpha pixels")

    cell_reports: list[dict[str, Any]] = []
    cell_w, cell_h = contract.cell_size
    for row_index in range(4):
        for column_index in range(4):
            cell_alpha = alpha[
                row_index * cell_h : (row_index + 1) * cell_h,
                column_index * cell_w : (column_index + 1) * cell_w,
            ]
            visible = int(np.count_nonzero(cell_alpha))
            label = batch.cell_map[row_index][column_index]
            if visible == 0:
                failures.append(f"cell [{row_index + 1},{column_index + 1}] {label!r} is empty")
            cell_reports.append(
                {
                    "row": row_index + 1,
                    "column": column_index + 1,
                    "label": label,
                    "source_rectangle": [column_index * cell_w, row_index * cell_h, cell_w, cell_h],
                    "visible_alpha_pixels": visible,
                    "visible_alpha_bbox_within_cell": _alpha_bbox(cell_alpha),
                }
            )
    return (
        {
            "alpha_extrema": [alpha_min, alpha_max],
            "outer_border_px": border,
            "outer_border_nonzero_alpha_pixels": border_nonzero,
            "vertical_separator_bands": vertical_counts,
            "horizontal_separator_bands": horizontal_counts,
            "cells": cell_reports,
        },
        failures,
    )


def inspect_source(entry: SourceEntry, contract: EnvironmentContract) -> tuple[dict[str, Any], bytes]:
    path = entry.source_path
    if not path.is_file():
        raise IntakeError(f"{entry.batch.batch_id}: source PNG does not exist: {path}")
    payload = path.read_bytes()
    if len(payload) < 29 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise IntakeError(f"{entry.batch.batch_id}: source is not a normal PNG with IHDR")
    color_type = int(payload[25])
    if color_type != 6:
        raise IntakeError(
            f"{entry.batch.batch_id}: PNG color type must be 6 (native truecolor RGBA), got {color_type}"
        )
    actual_sha = sha256_bytes(payload)
    if actual_sha != entry.source_sha256:
        raise IntakeError(
            f"{entry.batch.batch_id}: source SHA mismatch; declared {entry.source_sha256}, actual {actual_sha}"
        )
    try:
        with Image.open(io.BytesIO(payload)) as image:
            image.load()
            if int(getattr(image, "n_frames", 1)) != 1 or bool(getattr(image, "is_animated", False)):
                raise IntakeError(f"{entry.batch.batch_id}: animated PNG sources are not accepted")
            mode = image.mode
            size = image.size
            if mode != "RGBA":
                raise IntakeError(f"{entry.batch.batch_id}: decoded PNG mode must be RGBA, got {mode}")
            array = np.asarray(image, dtype=np.uint8).copy()
    except OSError as error:
        raise IntakeError(f"{entry.batch.batch_id}: PNG cannot be decoded: {error}") from error
    expected_size = contract.surface_size if entry.batch.category == SURFACE_CATEGORY else contract.atlas_size
    if size != expected_size or size != entry.declared_size:
        raise IntakeError(
            f"{entry.batch.batch_id}: decoded size {size} differs from required and declared {expected_size}"
        )
    if entry.batch.category == SURFACE_CATEGORY:
        metrics, failures = inspect_surface(array, contract)
    else:
        metrics, failures = inspect_atlas(array, entry.batch, contract)
    report = {
        "id": entry.batch.batch_id,
        "order": entry.batch.order,
        "category": entry.batch.category,
        "source_png": str(path),
        "source_sha256": actual_sha,
        "size": list(size),
        "png_color_type": color_type,
        "decoded_mode": mode,
        "conversation_url": entry.conversation_url,
        "prompt_file": str(entry.batch.prompt_path),
        "prompt_sha256": entry.prompt_sha256,
        "decision": entry.decision,
        "reason": entry.reason,
        "human_review": entry.human_review,
        "objective_metrics": metrics,
        "objective_failures": failures,
        "objective_pass": not failures,
        "adoption_gate_pass": entry.decision == "reject" or not failures,
    }
    return report, payload


def load_mapping(path: Path, contract: EnvironmentContract, workspace_root: Path) -> Mapping:
    path = path.resolve()
    data = load_json(path, "environment production mapping")
    if data.get("schema_version") != 1 or data.get("kind") != "web_chatgpt_environment_production_mapping":
        raise IntakeError(
            "production mapping must use schema 1 and kind web_chatgpt_environment_production_mapping"
        )
    declared_batch_sha = expect_sha(data.get("batch_manifest_sha256"), "mapping.batch_manifest_sha256")
    if declared_batch_sha != contract.batch_sha256:
        raise IntakeError(
            f"production mapping was made for a different prompt contract: {declared_batch_sha} != {contract.batch_sha256}"
        )
    declared_static_sha = expect_sha(
        data.get("static_self_check_sha256"), "mapping.static_self_check_sha256"
    )
    if declared_static_sha != contract.static_self_check_sha256:
        raise IntakeError(
            "production mapping was made for a different prompt static self-check: "
            f"{declared_static_sha} != {contract.static_self_check_sha256}"
        )
    archive_raw, archive_root = parse_relative_target(
        data.get("archive_root"),
        workspace_root,
        "mapping.archive_root",
        required_prefix="qa",
        expect_directory=True,
    )
    provenance_raw, provenance_target = parse_relative_target(
        data.get("provenance_target"),
        workspace_root,
        "mapping.provenance_target",
        required_prefix="qa",
        suffix=".json",
    )
    assert archive_raw and archive_root and provenance_raw and provenance_target

    runtime_contract = data.get("runtime_router_contract")
    if not isinstance(runtime_contract, dict):
        raise IntakeError("mapping.runtime_router_contract must be an object")

    def evidence_file(
        field: str, sha_field: str, prefix: str, suffix: str
    ) -> tuple[str, Path, str]:
        raw, resolved = parse_relative_target(
            runtime_contract.get(field),
            workspace_root,
            f"mapping.runtime_router_contract.{field}",
            required_prefix=prefix,
            suffix=suffix,
        )
        assert raw and resolved
        if not resolved.is_file():
            raise IntakeError(f"runtime router evidence file is missing: {resolved}")
        expected_sha = expect_sha(
            runtime_contract.get(sha_field), f"mapping.runtime_router_contract.{sha_field}"
        )
        actual_sha = sha256_file(resolved)
        if actual_sha != expected_sha:
            raise IntakeError(
                f"runtime router evidence SHA mismatch for {raw}: {expected_sha} != {actual_sha}"
            )
        return raw, resolved, actual_sha

    router_raw, router_path, router_sha = evidence_file(
        "router_path", "router_sha256", "scripts", ".gd"
    )
    static_contract_raw, static_contract_path, static_contract_sha = evidence_file(
        "static_contract_path", "static_contract_sha256", "tools", ".py"
    )
    report_raw, report_path, report_sha = evidence_file(
        "report_path", "report_sha256", "qa", ".json"
    )
    expected_report_checks = runtime_contract.get("report_passed_checks")
    if (
        not isinstance(expected_report_checks, int)
        or isinstance(expected_report_checks, bool)
        or expected_report_checks < 1
    ):
        raise IntakeError("mapping.runtime_router_contract.report_passed_checks must be positive")
    runtime_report = load_json(report_path, "runtime router static-contract report")
    runtime_counts = runtime_report.get("counts")
    runtime_checks = runtime_report.get("checks")
    if (
        runtime_report.get("passed") is not True
        or runtime_report.get("scope") != "source_only_no_godot_no_bitmap_generation"
        or runtime_report.get("manifest_sha256") != contract.batch_sha256
        or runtime_report.get("router_sha256") != router_sha
        or not isinstance(runtime_counts, dict)
        or runtime_counts.get("manifest_cells") != 64
        or runtime_counts.get("object_route_keys") != 40
        or runtime_counts.get("object_state_paths") != 41
        or runtime_counts.get("overlay_route_keys") != 20
        or runtime_counts.get("static_flag_route_keys") != 3
        or runtime_counts.get("surface_paths") != 5
        or runtime_counts.get("consumer_ready_manifest_cells") != 64
        or runtime_counts.get("consumer_ready_surfaces") != 5
        or runtime_counts.get("consumer_ready_total") != 69
        or runtime_counts.get("missing_source_resources_expected_before_web_intake") != 69
        or runtime_counts.get("checks") != expected_report_checks
        or not isinstance(runtime_checks, list)
        or len(runtime_checks) != expected_report_checks
        or any(not isinstance(check, dict) or check.get("passed") is not True for check in runtime_checks)
    ):
        raise IntakeError(
            f"runtime router report must be {expected_report_checks}/{expected_report_checks} PASS "
            "with all 69 consumer routes for this exact manifest and router"
        )
    runtime_check_names = [check.get("name") for check in runtime_checks]
    if (
        any(not isinstance(name, str) or not name.strip() for name in runtime_check_names)
        or len(set(runtime_check_names)) != len(runtime_check_names)
    ):
        raise IntakeError(
            f"runtime router report must contain {expected_report_checks} uniquely named checks"
        )
    evidence_roots = (router_raw, static_contract_raw, report_raw)

    check_by_name = {
        str(check.get("name", "")): check
        for check in runtime_checks
        if isinstance(check, dict)
    }

    raw_consumer_hashes = runtime_report.get("consumer_file_sha256")
    if not isinstance(raw_consumer_hashes, dict) or len(raw_consumer_hashes) != 15:
        raise IntakeError("runtime router report must bind the exact fifteen consumer file SHAs")
    consumer_hashes: dict[str, str] = {}
    consumer_inputs_resolved: dict[Path, str] = {}
    seen_consumer_paths: set[str] = set()
    for raw_consumer_file, raw_consumer_sha in raw_consumer_hashes.items():
        if not isinstance(raw_consumer_file, str) or "\\" in raw_consumer_file:
            raise IntakeError("runtime consumer file paths must be canonical forward-slash strings")
        consumer_file, consumer_path = parse_relative_target(
            raw_consumer_file,
            workspace_root,
            f"runtime consumer {raw_consumer_file}",
            required_prefix="scripts",
        )
        assert consumer_file and consumer_path
        if consumer_path.suffix.lower() not in {".gd", ".gdshader"} or not consumer_path.is_file():
            raise IntakeError(f"runtime consumer file is missing or unsupported: {consumer_path}")
        consumer_key = consumer_file.casefold()
        if consumer_key in seen_consumer_paths:
            raise IntakeError(f"runtime consumer file is repeated by case: {consumer_file}")
        seen_consumer_paths.add(consumer_key)
        consumer_sha = expect_sha(raw_consumer_sha, f"runtime consumer SHA {consumer_file}")
        actual_consumer_sha = sha256_file(consumer_path)
        if actual_consumer_sha != consumer_sha:
            raise IntakeError(
                f"runtime consumer changed after its report: {consumer_file}: "
                f"{consumer_sha} != {actual_consumer_sha}"
            )
        consumer_hashes[consumer_file] = consumer_sha
        consumer_inputs_resolved[consumer_path] = consumer_sha

    def checked_evidence(value: Any, label: str) -> tuple[str, ...]:
        evidence = expect_string_list(value, label)
        for item in evidence:
            match = re.fullmatch(r"([^:]+):([1-9][0-9]*): (.+)", item)
            if match is None:
                raise IntakeError(f"{label} must use exact file:line: source evidence")
            evidence_file_raw, line_text = match.group(1), match.group(3)
            line_number = int(match.group(2))
            if evidence_file_raw not in consumer_hashes:
                raise IntakeError(f"{label} cites an unhashed consumer file: {evidence_file_raw}")
            evidence_path = (workspace_root / Path(evidence_file_raw)).resolve()
            source_lines = evidence_path.read_text(encoding="utf-8").splitlines()
            if line_number > len(source_lines) or source_lines[line_number - 1].strip() != line_text:
                raise IntakeError(f"{label} no longer matches {evidence_file_raw}:{line_number}")
        return evidence

    expected_atlas_consumers: dict[
        tuple[str, str, str, str, tuple[str, ...]], DeclaredCellRoute
    ] = {}
    for batch in contract.batches:
        for declared in batch.declared_cell_routes:
            identity = (
                declared.resolver,
                declared.route_key,
                declared.state,
                declared.output_path,
                declared.level_scope,
            )
            if identity in expected_atlas_consumers:
                raise IntakeError(f"frozen schema v2 repeats a full consumer identity: {identity}")
            expected_atlas_consumers[identity] = declared
    consumer_route_check = check_by_name.get("consumer_routes_exact")
    raw_atlas_consumers = None if consumer_route_check is None else consumer_route_check.get("detail")
    if not isinstance(raw_atlas_consumers, list) or len(raw_atlas_consumers) != 64:
        raise IntakeError("runtime consumer_routes_exact must enumerate all 64 atlas cells")
    atlas_consumers: dict[tuple[str, str, str, str, tuple[str, ...]], dict[str, Any]] = {}
    for index, item in enumerate(raw_atlas_consumers):
        if not isinstance(item, dict):
            raise IntakeError(f"consumer_routes_exact[{index}] must be an object")
        level_scope = expect_string_list(
            item.get("level_scope"), f"consumer_routes_exact[{index}].level_scope"
        )
        identity = (
            str(item.get("resolver", "")).strip(),
            str(item.get("route_key", "")).strip(),
            str(item.get("state", "")).strip(),
            str(item.get("output_path", "")).strip(),
            level_scope,
        )
        if identity not in expected_atlas_consumers or identity in atlas_consumers:
            raise IntakeError(f"consumer_routes_exact[{index}] is unknown or repeated: {identity}")
        consumer_file = str(item.get("consumer_file", "")).strip()
        if consumer_file not in consumer_hashes:
            raise IntakeError(f"consumer_routes_exact[{index}] cites an unhashed consumer file")
        consumer_sha = expect_sha(
            item.get("consumer_sha256"), f"consumer_routes_exact[{index}].consumer_sha256"
        )
        if consumer_sha != consumer_hashes[consumer_file]:
            raise IntakeError(f"consumer_routes_exact[{index}] consumer SHA differs from the file map")
        consumer_symbol = str(item.get("consumer_symbol", "")).strip()
        if not consumer_symbol:
            raise IntakeError(f"consumer_routes_exact[{index}] lacks consumer_symbol")
        consumer_evidence = checked_evidence(
            item.get("consumer_evidence"), f"consumer_routes_exact[{index}].consumer_evidence"
        )
        if not any(evidence.startswith(consumer_file + ":") for evidence in consumer_evidence):
            raise IntakeError(f"consumer_routes_exact[{index}] does not evidence its consumer_file")
        atlas_consumers[identity] = {
            "consumer_file": consumer_file,
            "consumer_sha256": consumer_sha,
            "consumer_symbol": consumer_symbol,
            "evidence": consumer_evidence,
        }
    if set(atlas_consumers) != set(expected_atlas_consumers):
        raise IntakeError("runtime consumer_routes_exact does not equal the frozen 64-cell contract")

    expected_surface_levels = {
        batch.batch_id: tuple(
            match.group(0)
            for usage in batch.campaign_usage
            for match in [re.match(r"level[1-8]", usage)]
            if match is not None
        )
        for batch in contract.batches
        if batch.category == SURFACE_CATEGORY
    }
    surface_consumer_check = check_by_name.get("surface_consumers_exact")
    raw_surface_consumers = (
        None if surface_consumer_check is None else surface_consumer_check.get("detail")
    )
    if not isinstance(raw_surface_consumers, list) or len(raw_surface_consumers) != 5:
        raise IntakeError("runtime surface_consumers_exact must enumerate all five surfaces")
    surface_consumers: dict[str, dict[str, Any]] = {}
    for index, item in enumerate(raw_surface_consumers):
        if not isinstance(item, dict):
            raise IntakeError(f"surface_consumers_exact[{index}] must be an object")
        surface_key = str(item.get("surface_key", "")).strip()
        level_scope = expect_string_list(
            item.get("level_scope"), f"surface_consumers_exact[{index}].level_scope"
        )
        output_path = str(item.get("output_path", "")).strip()
        if (
            surface_key not in expected_surface_levels
            or surface_key in surface_consumers
            or level_scope != expected_surface_levels[surface_key]
            or output_path
            != f"res://assets/campaign/environment/shared/surfaces/{surface_key}.png"
        ):
            raise IntakeError(f"surface_consumers_exact[{index}] is unknown, repeated, or out of scope")
        consumer_file = str(item.get("consumer_file", "")).strip()
        if consumer_file not in consumer_hashes:
            raise IntakeError(f"surface_consumers_exact[{index}] cites an unhashed consumer file")
        consumer_sha = expect_sha(
            item.get("consumer_sha256"), f"surface_consumers_exact[{index}].consumer_sha256"
        )
        if consumer_sha != consumer_hashes[consumer_file]:
            raise IntakeError(f"surface_consumers_exact[{index}] consumer SHA differs from the file map")
        consumer_symbol = str(item.get("consumer_symbol", "")).strip()
        if not consumer_symbol:
            raise IntakeError(f"surface_consumers_exact[{index}] lacks consumer_symbol")
        fallback_evidence = checked_evidence(
            item.get("fallback_evidence"), f"surface_consumers_exact[{index}].fallback_evidence"
        )
        if not any(evidence.startswith(consumer_file + ":") for evidence in fallback_evidence):
            raise IntakeError(f"surface_consumers_exact[{index}] does not evidence its consumer_file")
        surface_consumers[surface_key] = {
            "level_scope": level_scope,
            "output_path": output_path,
            "consumer_file": consumer_file,
            "consumer_sha256": consumer_sha,
            "consumer_symbol": consumer_symbol,
            "evidence": fallback_evidence,
        }
    if set(surface_consumers) != set(expected_surface_levels):
        raise IntakeError("runtime surface_consumers_exact does not equal the frozen five-surface contract")
    surface_target_check = check_by_name.get("five_surface_targets_exact")
    raw_surface_targets = None if surface_target_check is None else surface_target_check.get("detail")
    expected_surface_target_detail = {
        key: {"levels": list(record["level_scope"]), "path": record["output_path"]}
        for key, record in surface_consumers.items()
    }
    if raw_surface_targets != expected_surface_target_detail:
        raise IntakeError("five_surface_targets_exact disagrees with surface_consumers_exact")
    all_consumer_check = check_by_name.get("all_69_consumer_ready")
    if all_consumer_check is None or all_consumer_check.get("detail") != {
        "atlas_cells": 64,
        "surfaces": 5,
    }:
        raise IntakeError("runtime report does not prove all 69 consumers")
    surface_targets = {
        key: record["output_path"].removeprefix("res://")
        for key, record in surface_consumers.items()
    }

    def validate_integration_evidence(
        evidence: tuple[str, ...], consumer: dict[str, Any], label: str
    ) -> None:
        if not evidence:
            raise IntakeError(f"{label} is marked ready without integration evidence")
        for required in evidence_roots:
            if not any(item == required or item.startswith(required + "#") for item in evidence):
                raise IntakeError(f"{label} evidence must cite {required}")
        for required in consumer["evidence"]:
            if required not in evidence:
                raise IntakeError(f"{label} evidence must cite exact consumer line: {required}")

    def atlas_consumer(
        resolver: str,
        route_key: str,
        state: str,
        output_path: str,
        level_scope: tuple[str, ...],
        label: str,
    ) -> dict[str, Any]:
        identity = (resolver, route_key, state, output_path, level_scope)
        consumer = atlas_consumers.get(identity)
        if consumer is None:
            raise IntakeError(
                f"{label} may not be integration_ready: no exact resolver/key/state/path/scope consumer"
            )
        return consumer
    raw_routes = data.get("batches")
    if not isinstance(raw_routes, list) or len(raw_routes) != len(contract.batches):
        raise IntakeError("production mapping must contain exactly one route for every environment batch")
    expected = {batch.batch_id: batch for batch in contract.batches}
    routes: dict[str, BatchRoute] = {}
    used_targets: dict[str, str] = {}
    used_output_ids: dict[str, str] = {}

    def reserve_target(raw: str | None, label: str) -> None:
        if raw is None:
            return
        key = raw.casefold()
        if key in used_targets:
            raise IntakeError(f"production target collision: {raw} and {used_targets[key]}")
        used_targets[key] = label

    for index, raw in enumerate(raw_routes):
        if not isinstance(raw, dict):
            raise IntakeError(f"mapping.batches[{index}] must be an object")
        batch_id = str(raw.get("id", "")).strip()
        if batch_id not in expected or batch_id in routes:
            raise IntakeError(f"mapping.batches[{index}] has unknown or repeated id: {batch_id}")
        batch = expected[batch_id]
        if batch.category == SURFACE_CATEGORY:
            mode = str(raw.get("mode", ""))
            if mode != "copy_exact_source_png":
                raise IntakeError(f"{batch_id}: surface route mode must be copy_exact_source_png")
            target_raw, target = parse_relative_target(
                raw.get("target"),
                workspace_root,
                f"mapping.{batch_id}.target",
                required_prefix="assets",
                suffix=".png",
                allow_unmapped=True,
            )
            raw_output_id = raw.get("output_id")
            output_id = None if raw_output_id is None or str(raw_output_id).strip() == "" else str(raw_output_id).strip()
            if output_id is not None and re.fullmatch(r"[a-z][a-z0-9_]*(?:[.:/-][a-z0-9_]+)*", output_id) is None:
                raise IntakeError(f"{batch_id}.output_id must be a stable lowercase runtime identifier")
            if output_id is not None and output_id != batch_id:
                raise IntakeError(f"{batch_id}.output_id must equal its frozen surface id")
            raw_levels = raw.get("level_scope")
            level_scope = () if raw_levels in (None, []) else expect_string_list(
                raw_levels, f"{batch_id}.level_scope"
            )
            if len(set(level_scope)) != len(level_scope) or any(
                re.fullmatch(r"level[1-8]", level) is None for level in level_scope
            ):
                raise IntakeError(f"{batch_id}.level_scope is invalid")
            expected_levels = tuple(
                match.group(0)
                for usage in batch.campaign_usage
                for match in [re.match(r"level[1-8]", usage)]
                if match is not None
            )
            if level_scope and level_scope != expected_levels:
                raise IntakeError(
                    f"{batch_id}.level_scope differs from its reviewed campaign usage {list(expected_levels)}"
                )
            route_scope = str(raw.get("route_scope", "")).strip()
            if route_scope and route_scope != "shared_surface_class":
                raise IntakeError(f"{batch_id}.route_scope must be shared_surface_class")
            reuse_policy = str(raw.get("reuse_policy", "")).strip()
            if reuse_policy and reuse_policy != "shared_surface_with_declared_campaign_usage":
                raise IntakeError(f"{batch_id}.reuse_policy is unsafe")
            resolver = str(raw.get("resolver", "")).strip()
            route_key = str(raw.get("route_key", "")).strip()
            if resolver and resolver != "CampaignEnvironmentArt.surface":
                raise IntakeError(f"{batch_id}.resolver must be CampaignEnvironmentArt.surface")
            if route_key and re.fullmatch(r"[a-z][a-z0-9_]*", route_key) is None:
                raise IntakeError(f"{batch_id}.route_key is invalid")
            if route_key and route_key != batch_id:
                raise IntakeError(f"{batch_id}.route_key must equal its frozen surface id")
            expected_target_raw = surface_targets[batch_id]
            if target_raw is not None and target_raw.casefold() != expected_target_raw.casefold():
                raise IntakeError(
                    f"{batch_id}.target must equal runtime router target {expected_target_raw}"
                )
            integration_ready = raw.get("integration_ready")
            if not isinstance(integration_ready, bool):
                raise IntakeError(f"{batch_id}.integration_ready must be boolean")
            raw_evidence = raw.get("integration_evidence")
            integration_evidence = () if raw_evidence in (None, []) else expect_string_list(
                raw_evidence, f"{batch_id}.integration_evidence"
            )
            if integration_ready:
                validate_integration_evidence(
                    integration_evidence, surface_consumers[batch_id], batch_id
                )
            reserve_target(target_raw, batch_id)
            if output_id is not None:
                output_key = output_id.casefold()
                if output_key in used_output_ids:
                    raise IntakeError(f"output_id collision: {output_id} and {used_output_ids[output_key]}")
                used_output_ids[output_key] = batch_id
            routes[batch_id] = BatchRoute(
                batch_id,
                mode,
                target_raw,
                target,
                (),
                output_id,
                level_scope,
                route_scope,
                reuse_policy,
                resolver,
                route_key,
                integration_ready,
                integration_evidence,
            )
            continue

        mode = str(raw.get("mode", ""))
        if mode != "fixed_grid_cell_uniform_scale_transparent_pad":
            raise IntakeError(
                f"{batch_id}: atlas route mode must be fixed_grid_cell_uniform_scale_transparent_pad"
            )
        raw_cells = raw.get("cells")
        if not isinstance(raw_cells, list) or len(raw_cells) != 16:
            raise IntakeError(f"{batch_id}: atlas route must contain all sixteen cell mappings")
        cells: list[CellRoute] = []
        seen_cells: set[tuple[int, int]] = set()
        declared_by_cell = {(item.row, item.column): item for item in batch.declared_cell_routes}
        for cell_index, cell in enumerate(raw_cells):
            if not isinstance(cell, dict):
                raise IntakeError(f"{batch_id}.cells[{cell_index}] must be an object")
            row = cell.get("row")
            column = cell.get("column")
            if (
                not isinstance(row, int)
                or isinstance(row, bool)
                or not isinstance(column, int)
                or isinstance(column, bool)
                or not (1 <= row <= 4 and 1 <= column <= 4)
                or (row, column) in seen_cells
            ):
                raise IntakeError(f"{batch_id}.cells[{cell_index}] has invalid/repeated 1-based row and column")
            seen_cells.add((row, column))
            declared = declared_by_cell[(row, column)]
            expected_label = batch.cell_map[row - 1][column - 1]
            label = str(cell.get("label", "")).strip()
            if label != expected_label:
                raise IntakeError(
                    f"{batch_id}.cells[{cell_index}] label {label!r} does not match reviewed {expected_label!r}"
                )
            raw_output_id = cell.get("output_id")
            output_id = None if raw_output_id is None or str(raw_output_id).strip() == "" else str(raw_output_id).strip()
            if output_id is not None and output_id != declared.output_id:
                raise IntakeError(
                    f"{batch_id}.cells[{row},{column}].output_id differs from schema v2 route {declared.output_id}"
                )
            raw_level_scope = cell.get("level_scope")
            level_scope = () if raw_level_scope in (None, []) else expect_string_list(
                raw_level_scope, f"{batch_id}.cells[{row},{column}].level_scope"
            )
            if level_scope and level_scope != declared.level_scope:
                raise IntakeError(f"{batch_id}.cells[{row},{column}].level_scope differs from schema v2")
            route_scope = str(cell.get("route_scope", "")).strip()
            if route_scope and route_scope != declared.route_scope:
                raise IntakeError(f"{batch_id}.cells[{row},{column}].route_scope differs from schema v2")
            reuse_policy = str(cell.get("reuse_policy", "")).strip()
            if reuse_policy != declared.reuse_policy:
                raise IntakeError(
                    f"{batch_id}.cells[{row},{column}].reuse_policy differs from schema v2 {declared.reuse_policy}"
                )
            resolver = str(cell.get("resolver", "")).strip()
            route_key = str(cell.get("route_key", "")).strip()
            state = str(cell.get("state", "")).strip()
            if resolver and resolver != declared.resolver:
                raise IntakeError(f"{batch_id}.cells[{row},{column}].resolver differs from schema v2")
            if route_key and route_key != declared.route_key:
                raise IntakeError(f"{batch_id}.cells[{row},{column}].route_key differs from schema v2")
            if state != declared.state:
                raise IntakeError(
                    f"{batch_id}.cells[{row},{column}].state differs from schema v2 {declared.state}"
                )
            integration_ready = cell.get("integration_ready")
            if not isinstance(integration_ready, bool):
                raise IntakeError(f"{batch_id}.cells[{row},{column}].integration_ready must be boolean")
            raw_evidence = cell.get("integration_evidence")
            integration_evidence = () if raw_evidence in (None, []) else expect_string_list(
                raw_evidence, f"{batch_id}.cells[{row},{column}].integration_evidence"
            )
            if integration_ready:
                consumer = atlas_consumer(
                    resolver,
                    route_key,
                    state,
                    declared.output_path,
                    level_scope,
                    f"{batch_id}.cells[{row},{column}]",
                )
                validate_integration_evidence(
                    integration_evidence,
                    consumer,
                    f"{batch_id}.cells[{row},{column}]",
                )
            target_raw, target = parse_relative_target(
                cell.get("target"),
                workspace_root,
                f"mapping.{batch_id}.cells[{row},{column}].target",
                required_prefix="assets",
                suffix=".png",
                allow_unmapped=True,
            )
            expected_target_raw = declared.output_path.removeprefix("res://")
            if target_raw is not None and target_raw.casefold() != expected_target_raw.casefold():
                raise IntakeError(
                    f"{batch_id}.cells[{row},{column}].target must equal schema v2 {expected_target_raw}"
                )
            canvas_size = expect_pair(cell.get("canvas_size"), f"{batch_id}.cells[{row},{column}].canvas_size")
            scaled_size = expect_pair(cell.get("scaled_size"), f"{batch_id}.cells[{row},{column}].scaled_size")
            offset = expect_pair(cell.get("offset"), f"{batch_id}.cells[{row},{column}].offset", allow_zero=True)
            if scaled_size[0] != scaled_size[1]:
                raise IntakeError(f"{batch_id}.cells[{row},{column}]: scaled_size must preserve the square cell aspect")
            if offset[0] + scaled_size[0] > canvas_size[0] or offset[1] + scaled_size[1] > canvas_size[1]:
                raise IntakeError(f"{batch_id}.cells[{row},{column}]: scaled cell does not fit inside the canvas")
            if max(canvas_size + scaled_size) > 4096:
                raise IntakeError(f"{batch_id}.cells[{row},{column}]: mapping dimensions exceed 4096")
            reserve_target(target_raw, f"{batch_id}[{row},{column}]")
            if output_id is not None:
                output_key = output_id.casefold()
                if output_key in used_output_ids:
                    raise IntakeError(
                        f"output_id collision: {output_id} and {used_output_ids[output_key]}"
                    )
                used_output_ids[output_key] = f"{batch_id}[{row},{column}]"
            cells.append(
                CellRoute(
                    row,
                    column,
                    label,
                    output_id,
                    level_scope,
                    route_scope,
                    reuse_policy,
                    resolver,
                    route_key,
                    state,
                    integration_ready,
                    integration_evidence,
                    target_raw,
                    target,
                    canvas_size,
                    scaled_size,
                    offset,
                )
            )
        cells.sort(key=lambda item: (item.row, item.column))
        routes[batch_id] = BatchRoute(batch_id, mode, None, None, tuple(cells))
    if set(routes) != set(expected):
        raise IntakeError("production mapping does not cover the exact nine environment IDs")
    return Mapping(
        path=path,
        sha256=sha256_file(path),
        data=data,
        archive_root=archive_root,
        provenance_target=provenance_target,
        routes=routes,
        runtime_router_contract={
            "router_path": router_raw,
            "router_resolved": router_path,
            "router_sha256": router_sha,
            "static_contract_path": static_contract_raw,
            "static_contract_resolved": static_contract_path,
            "static_contract_sha256": static_contract_sha,
            "report_path": report_raw,
            "report_resolved": report_path,
            "report_sha256": report_sha,
            "report_passed_checks": expected_report_checks,
            "consumer_file_sha256": consumer_hashes,
            "consumer_inputs_resolved": consumer_inputs_resolved,
        },
    )


def encode_png(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=False, compress_level=6)
    return output.getvalue()


def render_atlas_cell(payload: bytes, contract: EnvironmentContract, route: CellRoute) -> bytes:
    # The source rectangle is fixed by row/column.  Deliberately do not inspect
    # alpha bounds, connected components, or foreign pixels here.
    with Image.open(io.BytesIO(payload)) as image:
        image.load()
        cell_w, cell_h = contract.cell_size
        left = (route.column - 1) * cell_w
        top = (route.row - 1) * cell_h
        cell = image.crop((left, top, left + cell_w, top + cell_h))
        if route.scaled_size != contract.cell_size:
            cell = cell.resize(route.scaled_size, resample=Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", route.canvas_size, (0, 0, 0, 0))
        canvas.paste(cell, route.offset)  # no mask argument: copy the complete RGBA rectangle
        return encode_png(canvas)


def collision_record(path: Path, workspace_root: Path) -> dict[str, Any]:
    exists = path.is_file()
    return {
        "path": relative_to_workspace(path, workspace_root),
        "exists": exists,
        "sha256": sha256_file(path) if exists else "",
        "size_bytes": path.stat().st_size if exists else 0,
    }


def build_plan(
    source_manifest_path: Path,
    batch_manifest_path: Path,
    mapping_manifest_path: Path,
    workspace_root: Path,
) -> dict[str, Any]:
    workspace_root = workspace_root.resolve()
    contract = load_contract(batch_manifest_path)
    source_data, sources = load_sources(source_manifest_path, contract)
    mapping = load_mapping(mapping_manifest_path, contract, workspace_root)
    reports: list[dict[str, Any]] = []
    source_payloads: dict[str, bytes] = {}
    output_payloads: dict[Path, bytes] = {}
    output_records: list[dict[str, Any]] = []
    mapping_gaps: list[dict[str, Any]] = []
    invalid_adoptions: list[str] = []

    for batch in contract.batches:
        entry = sources.get(batch.batch_id)
        if entry is None:
            continue
        report, payload = inspect_source(entry, contract)
        reports.append(report)
        source_payloads[batch.batch_id] = payload
        if entry.decision == "adopt" and not report["objective_pass"]:
            invalid_adoptions.append(batch.batch_id)
        if entry.decision != "adopt":
            continue
        route = mapping.routes[batch.batch_id]
        if batch.category == SURFACE_CATEGORY:
            missing_fields = []
            if route.output_id is None:
                missing_fields.append("output_id")
            if route.target is None:
                missing_fields.append("target")
            if not route.level_scope:
                missing_fields.append("level_scope")
            if not route.route_scope:
                missing_fields.append("route_scope")
            if not route.reuse_policy:
                missing_fields.append("reuse_policy")
            if not route.resolver:
                missing_fields.append("resolver")
            if not route.route_key:
                missing_fields.append("route_key")
            if not route.integration_ready:
                missing_fields.append("integration_ready")
            if not route.integration_evidence:
                missing_fields.append("integration_evidence")
            if missing_fields:
                mapping_gaps.append(
                    {
                        "id": batch.batch_id,
                        "logical_code_targets": list(batch.code_targets),
                        "missing": missing_fields,
                    }
                )
                continue
            assert route.target is not None and route.output_id is not None
            output_payloads[route.target] = payload
            output_records.append(
                {
                    "id": batch.batch_id,
                    "category": batch.category,
                    "target": route.target_raw,
                    "output_id": route.output_id,
                    "level_scope": list(route.level_scope),
                    "route_scope": route.route_scope,
                    "reuse_policy": route.reuse_policy,
                    "resolver": route.resolver,
                    "route_key": route.route_key,
                    "integration_evidence": list(route.integration_evidence),
                    "processing": "byte-for-byte source PNG copy",
                    "source_sha256": entry.source_sha256,
                    "output_sha256": entry.source_sha256,
                    "collision": collision_record(route.target, workspace_root),
                }
            )
            continue
        missing_cells = [
            cell
            for cell in route.cells
            if (
                cell.target is None
                or cell.output_id is None
                or not cell.level_scope
                or not cell.route_scope
                or not cell.resolver
                or not cell.route_key
                or not cell.integration_ready
                or not cell.integration_evidence
            )
        ]
        if missing_cells:
            for cell in missing_cells:
                missing_fields = []
                if cell.output_id is None:
                    missing_fields.append("output_id")
                if cell.target is None:
                    missing_fields.append("target")
                if not cell.level_scope:
                    missing_fields.append("level_scope")
                if not cell.route_scope:
                    missing_fields.append("route_scope")
                if not cell.resolver:
                    missing_fields.append("resolver")
                if not cell.route_key:
                    missing_fields.append("route_key")
                if not cell.integration_ready:
                    missing_fields.append("integration_ready")
                if not cell.integration_evidence:
                    missing_fields.append("integration_evidence")
                mapping_gaps.append(
                    {
                        "id": batch.batch_id,
                        "row": cell.row,
                        "column": cell.column,
                        "label": cell.label,
                        "schema_v2_output_path": next(
                            item.output_path
                            for item in batch.declared_cell_routes
                            if item.row == cell.row and item.column == cell.column
                        ),
                        "missing": missing_fields,
                        "reuse_policy": cell.reuse_policy,
                    }
                )
            continue
        for cell in route.cells:
            assert cell.target is not None and cell.target_raw is not None and cell.output_id is not None
            rendered = render_atlas_cell(payload, contract, cell)
            if cell.target in output_payloads and output_payloads[cell.target] != rendered:
                raise IntakeError(
                    f"{batch.batch_id}[{cell.row},{cell.column}] duplicate target produces different pixels"
                )
            output_payloads[cell.target] = rendered
            output_records.append(
                {
                    "id": batch.batch_id,
                    "category": batch.category,
                    "row": cell.row,
                    "column": cell.column,
                    "label": cell.label,
                    "output_id": cell.output_id,
                    "level_scope": list(cell.level_scope),
                    "route_scope": cell.route_scope,
                    "reuse_policy": cell.reuse_policy,
                    "resolver": cell.resolver,
                    "route_key": cell.route_key,
                    "state": cell.state,
                    "integration_evidence": list(cell.integration_evidence),
                    "source_rectangle": [
                        (cell.column - 1) * contract.cell_size[0],
                        (cell.row - 1) * contract.cell_size[1],
                        contract.cell_size[0],
                        contract.cell_size[1],
                    ],
                    "target": cell.target_raw,
                    "canvas_size": list(cell.canvas_size),
                    "scaled_size": list(cell.scaled_size),
                    "offset": list(cell.offset),
                    "processing": "fixed whole-cell rectangle; uniform scale; transparent padding; no mask",
                    "source_sha256": entry.source_sha256,
                    "output_sha256": sha256_bytes(rendered),
                    "collision": collision_record(cell.target, workspace_root),
                }
            )

    adopted = [entry for entry in sources.values() if entry.decision == "adopt"]
    rejected = [entry for entry in sources.values() if entry.decision == "reject"]
    unsubmitted = [batch.batch_id for batch in contract.batches if batch.batch_id not in sources]
    # A rejected-only review may still be committed to the immutable source
    # archive/provenance ledger.  Rejected PNGs never create runtime outputs.
    commit_ready = not invalid_adoptions and not mapping_gaps
    public = {
        "schema_version": 1,
        "kind": "web_chatgpt_environment_intake_plan",
        "dry_run": True,
        "committed": False,
        "workspace_root": str(workspace_root),
        "batch_manifest": str(contract.batch_manifest),
        "batch_manifest_sha256": contract.batch_sha256,
        "static_self_check": str(contract.static_self_check),
        "static_self_check_sha256": contract.static_self_check_sha256,
        "source_manifest": str(source_manifest_path.resolve()),
        "source_manifest_sha256": sha256_file(source_manifest_path.resolve()),
        "mapping_manifest": str(mapping.path),
        "mapping_manifest_sha256": mapping.sha256,
        "runtime_router_contract": {
            key: value
            for key, value in mapping.runtime_router_contract.items()
            if not key.endswith("_resolved")
        },
        "submitted_count": len(sources),
        "adopted_count": len(adopted),
        "rejected_count": len(rejected),
        "unsubmitted_batches": unsubmitted,
        "invalid_adoptions": invalid_adoptions,
        "mapping_gaps": mapping_gaps,
        "production_output_count": len(output_records),
        "production_outputs": output_records,
        "sources": reports,
        "commit_ready": commit_ready,
        "processing_boundary": {
            "surfaces": "byte-for-byte source copy only",
            "atlases": "fixed 512px whole-cell crop, optional uniform scale, transparent padding",
            "forbidden": [
                "components",
                "mirroring",
                "repainting",
                "direction synthesis",
                "alpha masking",
                "foreign-pixel clearing",
                "baked-shadow repair",
            ],
        },
    }
    canonical = {
        key: value
        for key, value in public.items()
        if key
        not in {
            "workspace_root",
            "batch_manifest",
            "static_self_check",
            "source_manifest",
            "mapping_manifest",
        }
    }
    public["deterministic_plan_sha256"] = sha256_bytes(
        json.dumps(canonical, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    )
    public["_contract"] = contract
    public["_mapping"] = mapping
    public["_sources"] = sources
    public["_source_data"] = source_data
    public["_source_payloads"] = source_payloads
    public["_output_payloads"] = output_payloads
    public["_input_hashes"] = {
        contract.batch_manifest: contract.batch_sha256,
        contract.static_self_check: contract.static_self_check_sha256,
        source_manifest_path.resolve(): public["source_manifest_sha256"],
        mapping.path: mapping.sha256,
        mapping.runtime_router_contract["router_resolved"]: mapping.runtime_router_contract[
            "router_sha256"
        ],
        mapping.runtime_router_contract[
            "static_contract_resolved"
        ]: mapping.runtime_router_contract["static_contract_sha256"],
        mapping.runtime_router_contract["report_resolved"]: mapping.runtime_router_contract[
            "report_sha256"
        ],
        **mapping.runtime_router_contract["consumer_inputs_resolved"],
        **{entry.source_path: entry.source_sha256 for entry in sources.values()},
        **{batch.prompt_path: batch.prompt_sha256 for batch in contract.batches},
    }
    return public


def public_plan(plan: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in plan.items() if not key.startswith("_")}


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        temporary.write_bytes(payload)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def acquire_lock(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as error:
        raise IntakeError(f"another environment intake commit may be active; lock exists: {path}") from error
    try:
        os.write(descriptor, f"pid={os.getpid()}\ntime={time.time()}\n".encode("ascii"))
    finally:
        os.close(descriptor)


def _checkpoint_targets(
    targets: Iterable[Path], checkpoint: Path, workspace_root: Path
) -> dict[Path, dict[str, Any]]:
    records: dict[Path, dict[str, Any]] = {}
    files_root = checkpoint / "files"
    for target in sorted(set(targets), key=lambda item: str(item).casefold()):
        if target.is_symlink():
            raise IntakeError(f"commit target became a symbolic link: {target}")
        exists = target.is_file()
        relative = relative_to_workspace(target, workspace_root)
        missing_parent_dirs: list[str] = []
        cursor = target.parent
        while cursor != workspace_root and not cursor.exists():
            missing_parent_dirs.append(relative_to_workspace(cursor, workspace_root))
            cursor = cursor.parent
        record = {
            "path": relative,
            "existed": exists,
            "sha256": sha256_file(target) if exists else "",
            "size_bytes": target.stat().st_size if exists else 0,
            "backup": "",
            "missing_parent_dirs": missing_parent_dirs,
        }
        if exists:
            backup = files_root / relative
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, backup)
            if sha256_file(backup) != record["sha256"]:
                raise IntakeError(f"checkpoint hash mismatch while copying {relative}")
            record["backup"] = relative_to_workspace(backup, workspace_root)
        records[target] = record
    checkpoint.mkdir(parents=True, exist_ok=True)
    (checkpoint / "checkpoint_manifest.json").write_text(
        json.dumps(
            {
                "schema_version": 1,
                "kind": "environment_art_precommit_sha_checkpoint",
                "created_epoch": time.time(),
                "targets": list(records.values()),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return records


def _verify_inputs(input_hashes: dict[Path, str]) -> None:
    for path, expected in input_hashes.items():
        if not path.is_file() or sha256_file(path) != expected:
            raise IntakeError(f"validated input changed before commit: {path}")


def _verify_targets_unchanged(records: dict[Path, dict[str, Any]]) -> None:
    for target, record in records.items():
        _verify_target_unchanged(target, record)


def _verify_target_unchanged(target: Path, record: dict[str, Any]) -> None:
    if record["existed"]:
        if not target.is_file() or sha256_file(target) != record["sha256"]:
            raise IntakeError(f"target changed after checkpoint: {target}")
    elif target.exists():
        raise IntakeError(f"new target collision appeared after checkpoint: {target}")


def _restore_checkpoint(records: dict[Path, dict[str, Any]], checkpoint: Path, workspace_root: Path) -> None:
    failures: list[str] = []
    new_directories: set[Path] = set()
    for target, record in records.items():
        new_directories.update(workspace_root / item for item in record.get("missing_parent_dirs", []))
        try:
            if record["existed"]:
                backup = checkpoint / "files" / relative_to_workspace(target, workspace_root)
                atomic_write(target, backup.read_bytes())
                if sha256_file(target) != record["sha256"]:
                    raise IntakeError("restored SHA differs from checkpoint")
            elif target.exists():
                if target.is_file() or target.is_symlink():
                    target.unlink()
                else:
                    raise IntakeError("new target is no longer a file")
        except Exception as error:  # report every rollback failure
            failures.append(f"{target}: {error}")
    for directory in sorted(new_directories, key=lambda item: len(item.parts), reverse=True):
        try:
            if directory.exists():
                directory.rmdir()
        except OSError as error:
            failures.append(f"{directory}: could not remove rollback-created directory: {error}")
    if failures:
        raise IntakeError("rollback was incomplete: " + "; ".join(failures))


def install_staged_file(staged: Path, target: Path) -> None:
    """Single injectable install boundary used by the rollback self-test."""
    target.parent.mkdir(parents=True, exist_ok=True)
    os.replace(staged, target)


def _existing_provenance(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"schema_version": 1, "kind": "web_chatgpt_environment_provenance", "records": []}
    data = load_json(path, "existing environment provenance")
    if data.get("schema_version") != 1 or data.get("kind") != "web_chatgpt_environment_provenance":
        raise IntakeError(f"existing provenance target has an incompatible schema: {path}")
    records = data.get("records")
    if not isinstance(records, list):
        raise IntakeError(f"existing provenance target records must be a list: {path}")
    seen: set[tuple[str, str]] = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise IntakeError(f"existing provenance record {index} is not an object: {path}")
        batch_id = record.get("id")
        source_sha = record.get("source_sha256")
        if not isinstance(batch_id, str) or not batch_id.strip() or not isinstance(source_sha, str):
            raise IntakeError(f"existing provenance record {index} lacks id/source_sha256: {path}")
        normalized_id = batch_id.strip()
        normalized_sha = expect_sha(source_sha, f"provenance.records[{index}].source_sha256")
        record["id"] = normalized_id
        record["source_sha256"] = normalized_sha
        key = (normalized_id, normalized_sha)
        if key in seen:
            raise IntakeError(f"existing provenance contains duplicate id/source SHA {key}: {path}")
        seen.add(key)
    return data


def _build_commit_writes(plan: dict[str, Any], workspace_root: Path) -> tuple[dict[Path, bytes], list[dict[str, Any]]]:
    contract: EnvironmentContract = plan["_contract"]
    mapping: Mapping = plan["_mapping"]
    sources: dict[str, SourceEntry] = plan["_sources"]
    source_payloads: dict[str, bytes] = plan["_source_payloads"]
    writes: dict[Path, bytes] = {}
    write_origins: dict[Path, str] = {}

    def add_write(path: Path, payload: bytes, origin: str) -> None:
        if path in writes:
            raise IntakeError(
                f"commit write collision at {relative_to_workspace(path, workspace_root)}: "
                f"{write_origins[path]} and {origin}"
            )
        writes[path] = payload
        write_origins[path] = origin

    for output_path, output_payload in plan["_output_payloads"].items():
        add_write(output_path, output_payload, "runtime PNG")
    output_by_id: dict[str, list[dict[str, Any]]] = {}
    for output in plan["production_outputs"]:
        output_by_id.setdefault(str(output["id"]), []).append(output)

    source_archive_records: list[dict[str, Any]] = []
    prompt_archive_by_id: dict[str, Path] = {}
    for batch_id, entry in sources.items():
        disposition = "accepted" if entry.decision == "adopt" else "rejected"
        source_archive = mapping.archive_root / "sources" / disposition / (
            f"{batch_id}_{entry.source_sha256[:16]}.png"
        )
        prompt_archive = mapping.archive_root / "prompts" / (
            f"{batch_id}_{entry.prompt_sha256[:16]}.txt"
        )
        add_write(source_archive, source_payloads[batch_id], f"{batch_id} source archive")
        add_write(prompt_archive, entry.batch.prompt_path.read_bytes(), f"{batch_id} prompt archive")
        prompt_archive_by_id[batch_id] = prompt_archive
        source_archive_records.append(
            {
                "id": batch_id,
                "source_archive": relative_to_workspace(source_archive, workspace_root),
                "source_sha256": entry.source_sha256,
                "prompt_archive": relative_to_workspace(prompt_archive, workspace_root),
                "prompt_sha256": entry.prompt_sha256,
            }
        )

    source_manifest_path = Path(plan["source_manifest"])
    manifest_archives = (
        (
            mapping.archive_root / "manifests" / f"batch_{plan['batch_manifest_sha256'][:16]}.json",
            contract.batch_manifest.read_bytes(),
            "batch manifest archive",
        ),
        (
            mapping.archive_root
            / "manifests"
            / f"static_self_check_{plan['static_self_check_sha256'][:16]}.json",
            contract.static_self_check.read_bytes(),
            "static self-check archive",
        ),
        (
            mapping.archive_root / "manifests" / f"mapping_{plan['mapping_manifest_sha256'][:16]}.json",
            mapping.path.read_bytes(),
            "production mapping archive",
        ),
        (
            mapping.archive_root / "manifests" / f"sources_{plan['source_manifest_sha256'][:16]}.json",
            source_manifest_path.read_bytes(),
            "source manifest archive",
        ),
    )
    for archive_path, archive_payload, archive_origin in manifest_archives:
        add_write(archive_path, archive_payload, archive_origin)

    provenance = _existing_provenance(mapping.provenance_target)
    existing_records = list(provenance["records"])
    existing_keys = {
        (str(record.get("id", "")), str(record.get("source_sha256", ""))): index
        for index, record in enumerate(existing_records)
        if isinstance(record, dict)
    }
    report_by_id = {str(record["id"]): record for record in plan["sources"]}
    commit_epoch = time.time()
    new_records: list[dict[str, Any]] = []
    for archive in source_archive_records:
        batch_id = str(archive["id"])
        entry = sources[batch_id]
        record = {
            "id": batch_id,
            "order": entry.batch.order,
            "category": entry.batch.category,
            "decision": entry.decision,
            "reason": entry.reason,
            "conversation_url": entry.conversation_url,
            "prompt_sha256": entry.prompt_sha256,
            "prompt_archive": archive["prompt_archive"],
            "source_sha256": entry.source_sha256,
            "source_archive": archive["source_archive"],
            "human_review": entry.human_review,
            "objective_metrics": report_by_id[batch_id]["objective_metrics"],
            "objective_pass": report_by_id[batch_id]["objective_pass"],
            "outputs": output_by_id.get(batch_id, []),
            "batch_manifest_sha256": plan["batch_manifest_sha256"],
            "static_self_check_sha256": plan["static_self_check_sha256"],
            "source_manifest_sha256": plan["source_manifest_sha256"],
            "mapping_manifest_sha256": plan["mapping_manifest_sha256"],
            "runtime_router_contract": plan["runtime_router_contract"],
            "recorded_epoch": commit_epoch,
            "local_processing": (
                "Opaque source copied byte-for-byte, or fixed whole 512px cell rectangle uniformly scaled "
                "and placed on transparent padding; no components, mirror, repaint, synthesis, alpha mask, "
                "foreign-pixel clear, or shadow repair."
            ),
        }
        key = (batch_id, entry.source_sha256)
        if key in existing_keys:
            existing_records[existing_keys[key]] = record
        else:
            existing_keys[key] = len(existing_records)
            existing_records.append(record)
        new_records.append(record)
    provenance["records"] = existing_records
    provenance["latest_commit_epoch"] = commit_epoch
    add_write(
        mapping.provenance_target,
        (json.dumps(provenance, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
        "provenance ledger",
    )
    return writes, new_records


def commit_plan(plan: dict[str, Any], workspace_root: Path) -> tuple[Path, dict[str, Any]]:
    workspace_root = workspace_root.resolve()
    if not plan.get("commit_ready"):
        raise IntakeError(
            "commit refused: an adopted source failed or at least one adopted output is unmapped"
        )
    _verify_inputs(plan["_input_hashes"])
    writes, provenance_records = _build_commit_writes(plan, workspace_root)
    input_paths = {path.resolve() for path in plan["_input_hashes"]}
    if any(target.resolve() in input_paths for target in writes):
        raise IntakeError("commit target collides with a validated input file")

    checkpoint_root = workspace_root / "qa/environment_art_intake/checkpoints"
    timestamp = time.strftime("%Y%m%d_%H%M%S", time.localtime()) + f"_{time.time_ns() % 1_000_000_000:09d}"
    checkpoint = checkpoint_root / timestamp
    records = _checkpoint_targets(writes, checkpoint, workspace_root)
    stage_root = Path(tempfile.mkdtemp(prefix="stage_", dir=checkpoint))
    staged: dict[Path, Path] = {}
    replacements_started = False
    try:
        # Checkpoint is complete before any output is staged, as required by the
        # environment-art intake contract.
        for index, (target, payload) in enumerate(sorted(writes.items(), key=lambda item: str(item[0]).casefold())):
            staged_path = stage_root / f"{index:04d}_{sha256_bytes(str(target).encode('utf-8'))[:16]}.bin"
            staged_path.write_bytes(payload)
            if sha256_file(staged_path) != sha256_bytes(payload):
                raise IntakeError(f"staged SHA mismatch: {target}")
            staged[target] = staged_path
        _verify_inputs(plan["_input_hashes"])
        _verify_targets_unchanged(records)
        for target in sorted(staged, key=lambda item: str(item).casefold()):
            _verify_target_unchanged(target, records[target])
            replacements_started = True
            install_staged_file(staged[target], target)
            expected = sha256_bytes(writes[target])
            if not target.is_file() or sha256_file(target) != expected:
                raise IntakeError(f"post-install SHA mismatch: {target}")
        for target, payload in writes.items():
            if not target.is_file() or sha256_file(target) != sha256_bytes(payload):
                raise IntakeError(f"final installed SHA mismatch: {target}")
    except Exception as error:
        if replacements_started:
            try:
                _restore_checkpoint(records, checkpoint, workspace_root)
            except Exception as rollback_error:
                raise IntakeError(f"commit failed ({error}); rollback also failed ({rollback_error})") from rollback_error
            raise IntakeError(f"commit failed and all targets were restored: {error}") from error
        raise
    finally:
        shutil.rmtree(stage_root, ignore_errors=True)

    result = {
        "schema_version": 1,
        "kind": "web_chatgpt_environment_intake_commit",
        "deterministic_plan_sha256": plan["deterministic_plan_sha256"],
        "batch_manifest_sha256": plan["batch_manifest_sha256"],
        "mapping_manifest_sha256": plan["mapping_manifest_sha256"],
        "checkpoint_manifest": relative_to_workspace(checkpoint / "checkpoint_manifest.json", workspace_root),
        "files_written": len(writes),
        "runtime_pngs_written": len(plan["production_outputs"]),
        "source_records_written": len(provenance_records),
        "targets": [
            {
                "path": relative_to_workspace(target, workspace_root),
                "sha256": sha256_file(target),
            }
            for target in sorted(writes, key=lambda item: str(item).casefold())
        ],
    }
    try:
        (checkpoint / "commit_result.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    except OSError as error:
        # Runtime/provenance files are already atomically installed and
        # verified here.  Do not misreport that durable commit as uncommitted
        # merely because this redundant checkpoint summary could not be saved.
        result["checkpoint_result_write_error"] = str(error)
    return checkpoint, result


def write_report(path: Path, report: dict[str, Any], workspace_root: Path) -> None:
    resolved = path.resolve()
    try:
        resolved.relative_to((workspace_root / "assets").resolve())
    except ValueError:
        pass
    else:
        raise IntakeError("--report may not be written inside production assets")
    atomic_write(resolved, (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def validate_report_path(path: Path | None, workspace_root: Path, inputs: Iterable[Path]) -> Path | None:
    if path is None:
        return None
    resolved = path.resolve()
    if resolved.suffix.lower() != ".json":
        raise IntakeError("--report must name a .json file")
    if resolved in {item.resolve() for item in inputs}:
        raise IntakeError("--report may not overwrite an input manifest")
    try:
        resolved.relative_to((workspace_root / "assets").resolve())
    except ValueError:
        return resolved
    raise IntakeError("--report may not be written inside production assets")


def validate_report_path_against_plan(path: Path | None, plan: dict[str, Any]) -> None:
    if path is None:
        return
    resolved = path.resolve()
    if resolved in {item.resolve() for item in plan["_input_hashes"]}:
        raise IntakeError("--report may not overwrite any validated source, prompt, route, or manifest input")
    mapping: Mapping = plan["_mapping"]
    if resolved == mapping.provenance_target.resolve():
        raise IntakeError("--report may not overwrite the provenance ledger")
    try:
        resolved.relative_to(mapping.archive_root.resolve())
    except ValueError:
        return
    raise IntakeError("--report may not be written inside the immutable source archive")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-manifest", required=True, type=Path)
    parser.add_argument("--batch-manifest", default=DEFAULT_BATCH_MANIFEST, type=Path)
    parser.add_argument("--mapping-manifest", default=DEFAULT_MAPPING_MANIFEST, type=Path)
    parser.add_argument("--workspace-root", default=ROOT, type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--report", type=Path, help="optional JSON report; never write it inside assets/")
    parser.add_argument("--commit", action="store_true", help="checkpoint, stage, and atomically install mapped outputs")
    args = parser.parse_args(argv)
    workspace_root = args.workspace_root.resolve()
    lock = workspace_root / "qa/environment_art_intake/.commit.lock"
    lock_acquired = False
    report_path: Path | None = None
    try:
        report_path = validate_report_path(
            args.report,
            workspace_root,
            (args.source_manifest, args.batch_manifest, args.mapping_manifest),
        )
        if args.commit:
            acquire_lock(lock)
            lock_acquired = True
        plan = build_plan(
            args.source_manifest.resolve(),
            args.batch_manifest.resolve(),
            args.mapping_manifest.resolve(),
            workspace_root,
        )
        try:
            validate_report_path_against_plan(report_path, plan)
        except IntakeError:
            # Do not write the failure payload onto the very evidence/input
            # path whose collision caused this refusal.
            report_path = None
            raise
        report = public_plan(plan)
        exit_code = 0
        if args.commit:
            checkpoint, commit_result = commit_plan(plan, workspace_root)
            report["dry_run"] = False
            report["committed"] = True
            report["checkpoint"] = relative_to_workspace(checkpoint, workspace_root)
            report["commit_result"] = commit_result
        elif report["invalid_adoptions"]:
            exit_code = 2
        if report_path:
            try:
                write_report(report_path, report, workspace_root)
            except OSError as error:
                report["report_write_error"] = str(error)
                print(json.dumps(report, ensure_ascii=False, indent=2))
                return 3
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return exit_code
    except (IntakeError, OSError, ValueError) as error:
        failure = {
            "schema_version": 1,
            "kind": "web_chatgpt_environment_intake_failure",
            "dry_run": not args.commit,
            "committed": False,
            "error": str(error),
        }
        if report_path:
            try:
                write_report(report_path, failure, workspace_root)
            except Exception:
                pass
        print(json.dumps(failure, ensure_ascii=False, indent=2), file=sys.stderr)
        return 2
    finally:
        if lock_acquired and lock.exists():
            lock.unlink()


if __name__ == "__main__":
    raise SystemExit(main())
