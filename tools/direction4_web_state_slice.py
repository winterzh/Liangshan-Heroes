"""Slice one reviewed Web ChatGPT 4x4 atlas into directional unit states.

The source atlas is four rows by four columns.  Pass one ``key:state`` mapping
per row; the columns always mean SE, SW, NE, NW.  The only supported layout
first proves that three full-height and three full-width low-alpha seams
(default alpha <= 6) divide the source into a 4x4 grid, then retains every
original RGBA pixel inside each cell, including disconnected weapons and
ropes.  It only crops, uniformly scales, and transparently pads reviewed source
pixels.  It never mirrors, masks, clears, repaints, fills, removes a background,
or invents pixels.  Atlases without full grid seams must use the reviewed fixed
rectangle candidate tool instead of connected-component ownership.

Normal output names are ``assets/anim/<key>_<state>_<direction>.png``.  The
shared ``assets/direction4/manifest.json`` records the source and each row
mapping so a state sheet can be traced back to its Web ChatGPT prompt.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")
ROW_SPEC = re.compile(r"^(?P<key>[a-z0-9_]+):(?P<state>[a-z0-9_]+)$")


@dataclass(frozen=True)
class RowMapping:
    key: str
    state: str


@dataclass
class ReviewedBody:
    source_region: tuple[int, int, int, int]
    source_alpha_bounds: tuple[int, int, int, int]
    body: Image.Image
    layout: str
    source_cell: tuple[int, int, int, int] | None = None
    selected_seams: dict[str, list[dict[str, Any]]] | None = None


@dataclass(frozen=True)
class SemanticAnchor:
    unit: str
    direction: str
    measurement_kind: str
    source_y_px: int


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def resolve_path(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def relative_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def parse_rows(value: str) -> list[RowMapping]:
    rows: list[RowMapping] = []
    for raw in value.split(","):
        match = ROW_SPEC.fullmatch(raw.strip())
        if match is None:
            raise SystemExit(
                "--rows must contain lowercase key:state values separated by commas"
            )
        rows.append(RowMapping(match["key"], match["state"]))
    if len(rows) != 4:
        raise SystemExit("--rows must name exactly four source rows")
    if len({(row.key, row.state) for row in rows}) != 4:
        raise SystemExit("--rows may not repeat a key:state output")
    return rows


def load_semantic_anchors(
    path: Path | None,
    rows: list[RowMapping],
) -> tuple[dict[tuple[str, str], SemanticAnchor], float, int]:
    if path is None:
        return {}, 0.82, 3
    resolved = resolve_path(path)
    try:
        data = json.loads(resolved.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read semantic anchor measurements {resolved}: {error}") from error
    raw_entries = data.get("entries") if isinstance(data, dict) else None
    if (
        not isinstance(data, dict)
        or data.get("schema_version") != 1
        or data.get("kind") != "direction4_manual_semantic_anchor_measurements"
        or not isinstance(raw_entries, list)
    ):
        raise SystemExit("Semantic anchor measurements use an unsupported schema")
    target_fraction = data.get("target_fraction")
    tolerance_px = data.get("tolerance_px")
    if target_fraction != 0.82 or tolerance_px != 3:
        raise SystemExit("Semantic anchor measurements must use the reviewed 82 percent plus-or-minus 3px contract")
    expected = {(row.key, direction) for row in rows for direction in DIRECTIONS}
    result: dict[tuple[str, str], SemanticAnchor] = {}
    for index, raw in enumerate(raw_entries, 1):
        if not isinstance(raw, dict):
            raise SystemExit(f"Semantic anchor entry {index} must be an object")
        unit = str(raw.get("art_identity", ""))
        direction = str(raw.get("direction", "")).lower()
        key = (unit, direction)
        source_y = raw.get("source_y_px")
        kind = str(raw.get("measurement_kind", ""))
        if key not in expected or key in result:
            raise SystemExit(f"Unknown or repeated semantic anchor {unit}:{direction}")
        if kind not in ("foot_or_hoof", "lowest_contact"):
            raise SystemExit(f"Invalid semantic anchor kind for {unit}:{direction}")
        if not isinstance(source_y, int) or isinstance(source_y, bool) or source_y < 0:
            raise SystemExit(f"Invalid source_y_px for semantic anchor {unit}:{direction}")
        result[key] = SemanticAnchor(unit, direction, kind, source_y)
    if set(result) != expected:
        raise SystemExit("Semantic anchor measurements must cover all 16 identity/direction cells")
    return result, float(target_fraction), int(tolerance_px)


def _transparent_runs(max_alpha: np.ndarray, threshold: int) -> list[tuple[int, int]]:
    """Return contiguous axis positions whose full row/column is transparent."""
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for index, value in enumerate(max_alpha):
        if int(value) <= threshold and start is None:
            start = index
        elif int(value) > threshold and start is not None:
            runs.append((start, index))
            start = None
    if start is not None:
        runs.append((start, len(max_alpha)))
    return runs


def _select_grid_seams(
    max_alpha: np.ndarray,
    axis: str,
    threshold: int,
    minimum_gap: int,
    search_fraction: float,
) -> list[dict[str, Any]]:
    """Select three globally transparent seams near quarter-grid boundaries."""
    length = len(max_alpha)
    cell_span = length / 4.0
    radius = cell_span * search_fraction
    qualifying = [
        (start, end)
        for start, end in _transparent_runs(max_alpha, threshold)
        if end - start >= minimum_gap
    ]
    seams: list[dict[str, Any]] = []
    for boundary in range(1, 4):
        nominal = cell_span * boundary
        candidates = [
            (start, end)
            for start, end in qualifying
            if abs((start + end) * 0.5 - nominal) <= radius
        ]
        if not candidates:
            nearby = [
                {"start": start, "end": end, "gap": end - start, "center": (start + end) * 0.5}
                for start, end in _transparent_runs(max_alpha, threshold)
                if abs((start + end) * 0.5 - nominal) <= radius
            ]
            raise SystemExit(
                "No safe %s seam near 4x4 boundary %d (nominal %.1f): need a full %s band "
                "of at least %d pixels at alpha <= %d; nearby runs=%s"
                % (axis, boundary, nominal, axis, minimum_gap, threshold, nearby)
            )
        start, end = min(candidates, key=lambda run: (abs((run[0] + run[1]) * 0.5 - nominal), -(run[1] - run[0])))
        selected = {
            "axis": axis,
            "boundary": boundary,
            "nominal": nominal,
            "start": start,
            "end": end,
            "gap": end - start,
            "center": (start + end) * 0.5,
            "max_alpha": int(np.max(max_alpha[start:end])),
            "criterion": "Every full %s in the selected continuous band has alpha <= %d" % (axis, threshold),
        }
        if selected["gap"] < minimum_gap or selected["max_alpha"] > threshold:
            raise SystemExit("Selected seam did not meet its own safety criterion: %s" % selected)
        seams.append(selected)
    if any(seams[index]["center"] >= seams[index + 1]["center"] for index in range(2)):
        raise SystemExit("Selected grid seams are not strictly ordered")
    return seams


def grid_bodies(
    atlas: Image.Image,
    seam_alpha_threshold: int,
    minimum_seam_gap: int,
    seam_search_fraction: float,
) -> list[list[ReviewedBody]]:
    """Crop safe 4x4 grid cells without alpha masking any pixel in the crop.

    Image generators can leave nearly invisible alpha dust across an otherwise
    transparent cell.  It must not determine scale or anchor placement.  A
    thresholded alpha channel therefore chooses one rectangular crop, while
    the crop itself is copied byte-for-byte.  This is still crop/scale/pad;
    It never clears selected pixels inside the crop.
    """
    rgba = np.asarray(atlas)
    x_seams = _select_grid_seams(
        np.max(rgba[:, :, 3], axis=0),
        "column",
        seam_alpha_threshold,
        minimum_seam_gap,
        seam_search_fraction,
    )
    y_seams = _select_grid_seams(
        np.max(rgba[:, :, 3], axis=1),
        "row",
        seam_alpha_threshold,
        minimum_seam_gap,
        seam_search_fraction,
    )
    x_cuts = [0] + [round(float(seam["center"])) for seam in x_seams] + [atlas.width]
    y_cuts = [0] + [round(float(seam["center"])) for seam in y_seams] + [atlas.height]
    if any(x_cuts[index] >= x_cuts[index + 1] for index in range(4)) or any(
        y_cuts[index] >= y_cuts[index + 1] for index in range(4)
    ):
        raise SystemExit("Selected transparent seams do not form four nonempty grid cells")

    seam_record = {"vertical": x_seams, "horizontal": y_seams}
    result: list[list[ReviewedBody]] = []
    for row in range(4):
        output_row: list[ReviewedBody] = []
        for column in range(4):
            x0, x1 = x_cuts[column], x_cuts[column + 1]
            y0, y1 = y_cuts[row], y_cuts[row + 1]
            cell = Image.fromarray(rgba[y0:y1, x0:x1].copy(), "RGBA")
            meaningful_alpha = cell.getchannel("A").point(
                lambda value: 255 if value > seam_alpha_threshold else 0
            )
            bounds = meaningful_alpha.getbbox()
            if bounds is None:
                raise SystemExit("Transparent grid cell %d,%d has no source art" % (row, column))
            left, top, right, bottom = bounds
            output_row.append(
                ReviewedBody(
                    source_region=(x0 + left, y0 + top, right - left, bottom - top),
                    source_alpha_bounds=(left, top, right, bottom),
                    body=cell.crop(bounds),
                    layout="grid",
                    source_cell=(x0, y0, x1 - x0, y1 - y0),
                    selected_seams=seam_record,
                )
            )
        result.append(output_row)
    return result


def render_frame(
    body: Image.Image,
    scale: float,
    canvas_size: int,
    reference_y: int,
    semantic_anchor_offset_y: int | None = None,
) -> tuple[Image.Image, tuple[int, int], tuple[int, int], int]:
    size = (
        max(1, round(body.width * scale)),
        max(1, round(body.height * scale)),
    )
    resized = body.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    resized_anchor_offset_y = (
        resized.height
        if semantic_anchor_offset_y is None
        else round(semantic_anchor_offset_y * scale)
    )
    paste_xy = (
        round((canvas_size - resized.width) * 0.5),
        reference_y - resized_anchor_offset_y,
    )
    if (
        paste_xy[0] < 0
        or paste_xy[1] < 0
        or paste_xy[0] + resized.width > canvas_size
        or paste_xy[1] + resized.height > canvas_size
    ):
        raise SystemExit("A reviewed figure does not fit the transparent target canvas")
    canvas.alpha_composite(resized, paste_xy)
    return canvas, size, paste_xy, paste_xy[1] + resized_anchor_offset_y


def png_bytes(image: Image.Image) -> bytes:
    payload = io.BytesIO()
    image.save(payload, format="PNG", optimize=True)
    return payload.getvalue()


def load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema_version": 1, "sources": {}, "outputs": []}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"Manifest is not valid JSON: {path}: {error}") from error
    if not isinstance(data, dict) or not isinstance(data.get("sources", {}), dict) or not isinstance(data.get("outputs", []), list):
        raise SystemExit(f"Manifest has an incompatible structure: {path}")
    data.setdefault("schema_version", 1)
    data.setdefault("sources", {})
    data.setdefault("outputs", [])
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Reviewed transparent 4x4 Web ChatGPT PNG")
    parser.add_argument("--rows", required=True, help="Four key:state values in top-to-bottom row order")
    parser.add_argument("--prompt", required=True, type=Path, help="Saved Web ChatGPT prompt text")
    parser.add_argument("--conversation", required=True, help="Stable https://chatgpt.com/c/... URL")
    parser.add_argument("--review", required=True, help="Human review note for this exact source atlas")
    parser.add_argument(
        "--semantic-anchor-measurements",
        type=Path,
        help="Reviewed 16-cell source-pixel foot/hoof or down-contact coordinates",
    )
    parser.add_argument("--manifest", default="assets/direction4/manifest.json", type=Path)
    parser.add_argument("--output-dir", default="assets/anim", type=Path)
    parser.add_argument("--canvas-size", default=256, type=int)
    parser.add_argument("--target-width", default=226, type=int)
    parser.add_argument("--target-height", default=198, type=int)
    parser.add_argument(
        "--alpha-bottom-reference",
        "--foot-anchor",
        dest="alpha_bottom_reference",
        default=0.82,
        type=float,
        help=(
            "Destination Y for the cropped source alpha-bounds bottom. This is only a placement "
            "reference and is never evidence of a semantic foot, hoof, or down-contact anchor."
        ),
    )
    parser.add_argument(
        "--layout",
        choices=("grid",),
        default="grid",
        help="Only audited transparent-seam grid cropping is supported",
    )
    parser.add_argument(
        "--seam-alpha-threshold",
        default=6,
        type=int,
        help="Largest alpha treated as transparent while proving a full grid seam",
    )
    parser.add_argument(
        "--minimum-seam-gap",
        default=8,
        type=int,
        help="Minimum continuous full-row/full-column transparent seam width in source pixels",
    )
    parser.add_argument(
        "--seam-search-fraction",
        default=0.22,
        type=float,
        help="Search radius around each nominal quarter boundary, as a fraction of one cell",
    )
    parser.add_argument("--overwrite", action="store_true", help="Permit replacing matching PNGs and manifest entries")
    parser.add_argument("--dry-run", action="store_true", help="Validate and report planned writes without modifying files")
    args = parser.parse_args()

    if args.canvas_size <= 0 or args.target_width <= 0 or args.target_height <= 0:
        raise SystemExit("Canvas and target dimensions must be positive")
    if not 0.0 < args.alpha_bottom_reference < 1.0:
        raise SystemExit("--alpha-bottom-reference must be between 0 and 1")
    if not 0 <= args.seam_alpha_threshold <= 255 or args.minimum_seam_gap <= 0:
        raise SystemExit("Seam alpha threshold and minimum gap are invalid")
    if not 0.0 < args.seam_search_fraction < 0.25:
        raise SystemExit("--seam-search-fraction must be greater than 0 and less than 0.25")
    if not args.conversation.startswith("https://chatgpt.com/c/") or "?" in args.conversation:
        raise SystemExit("Use a stable ChatGPT conversation URL without signed query parameters")

    source = resolve_path(args.source)
    prompt = resolve_path(args.prompt)
    manifest_path = resolve_path(args.manifest)
    output_dir = resolve_path(args.output_dir)
    rows = parse_rows(args.rows)
    semantic_anchors, semantic_target_fraction, semantic_tolerance_px = load_semantic_anchors(
        args.semantic_anchor_measurements, rows
    )
    if not source.is_file():
        raise SystemExit(f"Source atlas does not exist: {source}")
    if not prompt.is_file():
        raise SystemExit(f"Prompt file does not exist: {prompt}")
    try:
        atlas = Image.open(source).convert("RGBA")
    except OSError as error:
        raise SystemExit(f"Cannot read source atlas {source}: {error}") from error

    cells = grid_bodies(
        atlas,
        args.seam_alpha_threshold,
        args.minimum_seam_gap,
        args.seam_search_fraction,
    )
    alpha_bottom_reference_y = round(args.canvas_size * args.alpha_bottom_reference)
    semantic_target_y = round(args.canvas_size * semantic_target_fraction)
    plans: list[tuple[Path, bytes, dict[str, Any]]] = []
    for row_index, row in enumerate(rows):
        scale_limits: list[float] = []
        anchor_offsets: dict[str, int] = {}
        for column, direction in enumerate(DIRECTIONS):
            cell = cells[row_index][column]
            limits = [args.target_width / cell.body.width, args.target_height / cell.body.height]
            semantic_anchor = semantic_anchors.get((row.key, direction))
            if semantic_anchor is not None:
                source_offset_y = semantic_anchor.source_y_px - cell.source_region[1]
                if source_offset_y < 0 or source_offset_y >= cell.body.height:
                    raise SystemExit(
                        f"Manual semantic anchor {row.key}:{direction} lies outside the retained source alpha crop"
                    )
                anchor_offsets[direction] = source_offset_y
                above = source_offset_y
                below = cell.body.height - source_offset_y
                if above > 0:
                    limits.append(semantic_target_y / above)
                if below > 0:
                    limits.append((args.canvas_size - semantic_target_y) / below)
            scale_limits.extend(limits)
        row_scale = min(scale_limits)
        for column, direction in enumerate(DIRECTIONS):
            cell = cells[row_index][column]
            semantic_anchor = semantic_anchors.get((row.key, direction))
            semantic_offset_y = anchor_offsets.get(direction)
            placement_y = semantic_target_y if semantic_anchor is not None else alpha_bottom_reference_y
            frame, output_size, paste_xy, placed_reference_y = render_frame(
                cell.body,
                row_scale,
                args.canvas_size,
                placement_y,
                semantic_offset_y,
            )
            output = output_dir / f"{row.key}_{row.state}_{direction}.png"
            entry: dict[str, Any] = {
                "unit": row.key,
                "state": row.state,
                "direction": direction,
                "output": relative_path(output),
                "layout": cell.layout,
                "source_region": list(cell.source_region),
                "source_alpha_bounds": list(cell.source_alpha_bounds),
                "excluded_foreign_pixels": 0,
                "isolation": "Audited transparent-seam grid cell; one rectangular alpha-content crop is copied whole, including detached props, with no in-crop pixel masking.",
                "row_scale": row_scale,
                "output_size": list(output_size),
                "paste_xy": list(paste_xy),
                "canvas_size": [args.canvas_size, args.canvas_size],
            }
            alpha_bottom_output_y = paste_xy[1] + output_size[1]
            if semantic_anchor is not None:
                entry["placement_reference"] = {
                    "kind": "manual_source_pixel_semantic_anchor",
                    "measurement_kind": semantic_anchor.measurement_kind,
                    "source_y_px": semantic_anchor.source_y_px,
                    "source_offset_y_px": semantic_offset_y,
                    "target_fraction": semantic_target_fraction,
                    "target_output_y_px": semantic_target_y,
                    "placed_output_y_px": placed_reference_y,
                    "tolerance_px": semantic_tolerance_px,
                    "semantic_anchor_evidence": True,
                }
                entry["alpha_bbox_bottom_reference"] = {
                    "kind": "source_alpha_bbox_bottom_only",
                    "output_y_px": alpha_bottom_output_y,
                    "semantic_anchor_evidence": False,
                    "note": "Recorded only to prove it was not substituted for the manual semantic anchor.",
                }
            else:
                entry["placement_reference"] = {
                    "kind": "source_alpha_bbox_bottom_only",
                    "normalized_y": args.alpha_bottom_reference,
                    "pixel_y": alpha_bottom_reference_y,
                    "semantic_anchor_evidence": False,
                    "note": "Not a foot, hoof, or down-contact measurement.",
                }
            if cell.source_cell is not None:
                entry["source_cell"] = list(cell.source_cell)
            if cell.selected_seams is not None:
                entry["selected_seams"] = cell.selected_seams
            plans.append((output, png_bytes(frame), entry))

    manifest = load_manifest(manifest_path)
    output_keys = {(entry[2]["unit"], entry[2]["state"], entry[2]["direction"]) for entry in plans}
    existing_keys = {
        (str(entry.get("unit", "")), str(entry.get("state", "")), str(entry.get("direction", "")))
        for entry in manifest["outputs"]
    }
    collisions = [output for output, _, _ in plans if output.exists()]
    replacement_keys = output_keys & existing_keys
    source_id = source.stem
    if source_id in manifest["sources"]:
        replacement_keys.add(("source", source_id, ""))
    if not args.dry_run and (collisions or replacement_keys) and not args.overwrite:
        examples = [relative_path(path) for path in collisions[:2]]
        examples.extend(":".join(key) for key in sorted(replacement_keys)[:2])
        raise SystemExit("Refusing to replace existing output/provenance without --overwrite: " + ", ".join(examples))

    source_record = {
        "file": relative_path(source),
        "sha256": sha256_file(source),
        "size": [atlas.width, atlas.height],
        "generation": "Web ChatGPT",
        "conversation_url": args.conversation,
        "prompt_file": relative_path(prompt),
        "prompt_sha256": sha256_file(prompt),
        "review": args.review,
        "retained_pixels": "Audited transparent-seam grid crop, uniform per-row scale and transparent padding only; every RGBA pixel inside the reported rectangular crop is retained with no masking, mirroring, repainting, background processing or pixel invention.",
        "layout": "grid",
        "grid_seam_policy": {
            "alpha_threshold": args.seam_alpha_threshold,
            "minimum_gap": args.minimum_seam_gap,
            "search_fraction": args.seam_search_fraction,
        },
        "directions": list(DIRECTIONS),
        "row_mapping": [{"unit": row.key, "state": row.state} for row in rows],
        "semantic_anchor_measurements": (
            {
                "sha256": sha256_file(resolve_path(args.semantic_anchor_measurements)),
                "cells": len(semantic_anchors),
                "target_fraction": semantic_target_fraction,
                "tolerance_px": semantic_tolerance_px,
                "alpha_bbox_bottom_is_semantic_evidence": False,
            }
            if args.semantic_anchor_measurements is not None
            else None
        ),
    }
    for _, payload, entry in plans:
        entry["sha256"] = sha256_bytes(payload)
        entry["source"] = source_id

    if args.dry_run:
        print(
            json.dumps(
                {
                    "dry_run": True,
                    "source": source_id,
                    "source_sha256": source_record["sha256"],
                    "row_mapping": source_record["row_mapping"],
                    "outputs": [entry for _, _, entry in plans],
                    "manifest": relative_path(manifest_path),
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    for output, payload, _ in plans:
        output.write_bytes(payload)
    manifest["sources"][source_id] = source_record
    manifest["outputs"] = [
        entry
        for entry in manifest["outputs"]
        if (str(entry.get("unit", "")), str(entry.get("state", "")), str(entry.get("direction", ""))) not in output_keys
    ] + [entry for _, _, entry in plans]
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "dry_run": False,
                "source": source_id,
                "outputs": len(plans),
                "manifest_outputs": len(manifest["outputs"]),
                "manifest": relative_path(manifest_path),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
