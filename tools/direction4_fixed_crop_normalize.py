"""Normalize one reviewed Web ChatGPT direction atlas with fixed source rectangles.

This is a candidate-only pipeline.  Every frame is one explicit rectangular
crop from the untouched RGBA source.  The whole crop may receive transparent
padding and one uniform resize before it is pasted on a transparent canvas.
The tool never mirrors, masks, clears, repaints, fills, or synthesizes pixels.

Connected components are used only as a read-only completeness check: the
declared rectangle must contain its complete visible body and no other large
visible body.  Component labels are never used to edit an image.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import numpy as np
from PIL import Image
from scipy.ndimage import find_objects, label


ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
NAME_RE = re.compile(r"^[a-z0-9_]+$")
PROTECTED_ROOTS = (
    ROOT / "assets",
    Path.home() / "Documents" / "Steamworks",
)
SOURCE_RULE = "fixed_cell_rect_v1"
ROW_SOURCE_RULE = "fixed_direction_row_rect_v1"
SUPPORTED_SOURCE_RULES = (SOURCE_RULE, ROW_SOURCE_RULE)


class NormalizeError(RuntimeError):
    pass


@dataclass(frozen=True)
class VisibleComponent:
    component_id: int
    pixels: int
    bbox: tuple[int, int, int, int]
    center: tuple[float, float]


@dataclass(frozen=True)
class FrameSpec:
    unit: str
    state: str
    direction: str
    row: int
    column: int
    crop_rect: tuple[int, int, int, int]
    semantic_anchor_source: tuple[int, int]
    anchor_kind: str
    review_note: str


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rgba_sha256(image: Image.Image) -> str:
    header = f"RGBA:{image.width}x{image.height}:".encode("ascii")
    return sha256_bytes(header + image.tobytes())


def png_bytes(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def rel(path: Path) -> str:
    resolved = path.resolve()
    for base in (ROOT.parent.resolve(), ROOT.resolve()):
        try:
            return resolved.relative_to(base).as_posix()
        except ValueError:
            continue
    return str(resolved)


def load_json(path: Path, label_text: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise NormalizeError(f"{label_text} does not exist: {path}") from error
    except json.JSONDecodeError as error:
        raise NormalizeError(f"{label_text} is invalid JSON: {path}: {error}") from error
    if not isinstance(value, dict):
        raise NormalizeError(f"{label_text} must contain one JSON object")
    return value


def expect_sha(value: Any, label_text: str) -> str:
    digest = str(value).lower()
    if SHA256_RE.fullmatch(digest) is None:
        raise NormalizeError(f"{label_text} must be a lowercase SHA-256 digest")
    return digest


def stable_conversation_url(value: Any) -> str:
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
        raise NormalizeError(
            "conversation_url must be a stable https://chatgpt.com/c/... URL without query or fragment"
        )
    return text


def resolve_declared_path(value: Any, spec_path: Path) -> Path:
    raw = Path(str(value))
    if raw.is_absolute():
        return raw.resolve()
    candidates = (
        (ROOT.parent / raw).resolve(),
        (ROOT / raw).resolve(),
        (spec_path.parent / raw).resolve(),
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    return candidates[0]


def verify_prompt_record(
    record: Any,
    label_text: str,
    spec_path: Path,
    required: bool,
) -> dict[str, Any] | None:
    if record is None and not required:
        return None
    if not isinstance(record, dict):
        raise NormalizeError(f"{label_text} must be an object" + ("" if required else " or null"))
    path = resolve_declared_path(record.get("path", ""), spec_path)
    digest = expect_sha(record.get("sha256"), f"{label_text}.sha256")
    if not path.is_file():
        raise NormalizeError(f"{label_text} file does not exist: {path}")
    actual = sha256_file(path)
    if actual != digest:
        raise NormalizeError(f"{label_text} SHA mismatch: expected {digest}, actual {actual}")
    return {"file": rel(path), "sha256": actual}


def parse_int_tuple(value: Any, length: int, label_text: str) -> tuple[int, ...]:
    if (
        not isinstance(value, list)
        or len(value) != length
        or not all(isinstance(item, int) and not isinstance(item, bool) for item in value)
    ):
        raise NormalizeError(f"{label_text} must contain exactly {length} integers")
    return tuple(value)


def parse_frames(
    raw_frames: Any,
    source_size: tuple[int, int],
    expected_rows: int = 4,
    expected_columns: int = 4,
) -> list[FrameSpec]:
    expected_count = expected_rows * expected_columns
    if not isinstance(raw_frames, list) or len(raw_frames) != expected_count:
        raise NormalizeError(f"frames must contain exactly {expected_count} fixed frame records")
    frames: list[FrameSpec] = []
    slots: set[tuple[int, int]] = set()
    output_keys: set[tuple[str, str, str]] = set()
    width, height = source_size
    for index, raw in enumerate(raw_frames, 1):
        if not isinstance(raw, dict):
            raise NormalizeError(f"frame {index} must be an object")
        unit = str(raw.get("unit", ""))
        state = str(raw.get("state", ""))
        direction = str(raw.get("direction", "")).lower()
        if NAME_RE.fullmatch(unit) is None or NAME_RE.fullmatch(state) is None:
            raise NormalizeError(f"frame {index} unit/state must use lowercase ASCII keys")
        row = raw.get("row")
        column = raw.get("column")
        if (
            not isinstance(row, int)
            or isinstance(row, bool)
            or not isinstance(column, int)
            or isinstance(column, bool)
            or not 0 <= row < expected_rows
            or not 0 <= column < expected_columns
        ):
            raise NormalizeError(
                f"frame {index} row/column must lie inside the declared "
                f"{expected_rows}x{expected_columns} atlas"
            )
        if direction != DIRECTIONS[column]:
            raise NormalizeError(
                f"frame {index} direction {direction!r} does not match column {column} ({DIRECTIONS[column]})"
            )
        slot = (row, column)
        if slot in slots:
            raise NormalizeError(f"frame {index} repeats source slot {slot}")
        slots.add(slot)
        output_key = (unit, state, direction)
        if output_key in output_keys:
            raise NormalizeError(f"frame {index} repeats output identity {output_key}")
        output_keys.add(output_key)
        x, y, crop_width, crop_height = parse_int_tuple(
            raw.get("crop_rect"), 4, f"frame {index}.crop_rect"
        )
        if (
            x < 0
            or y < 0
            or crop_width <= 0
            or crop_height <= 0
            or x + crop_width > width
            or y + crop_height > height
        ):
            raise NormalizeError(f"frame {index} crop_rect is outside the source atlas")
        anchor_x, anchor_y = parse_int_tuple(
            raw.get("semantic_anchor_source"), 2, f"frame {index}.semantic_anchor_source"
        )
        if not (x <= anchor_x < x + crop_width and y <= anchor_y < y + crop_height):
            raise NormalizeError(f"frame {index} semantic anchor lies outside crop_rect")
        anchor_kind = str(raw.get("anchor_kind", ""))
        if anchor_kind not in ("foot_or_hoof", "lowest_contact"):
            raise NormalizeError(f"frame {index} anchor_kind is unsupported")
        review_note = str(raw.get("review_note", "")).strip()
        if len(review_note) < 12:
            raise NormalizeError(f"frame {index} requires a concrete fixed-crop review_note")
        frames.append(
            FrameSpec(
                unit,
                state,
                direction,
                row,
                column,
                (x, y, crop_width, crop_height),
                (anchor_x, anchor_y),
                anchor_kind,
                review_note,
            )
        )
    if slots != {
        (row, column)
        for row in range(expected_rows)
        for column in range(expected_columns)
    }:
        raise NormalizeError(
            f"frames must cover every {expected_rows}x{expected_columns} slot exactly once"
        )
    for row in range(expected_rows):
        row_frames = [frame for frame in frames if frame.row == row]
        if len({(frame.unit, frame.state) for frame in row_frames}) != 1:
            raise NormalizeError(f"row {row} must keep one unit/state identity across all directions")
    return sorted(frames, key=lambda item: (item.row, item.column))


def visible_components(
    alpha: np.ndarray,
    threshold: int,
    minimum_pixels: int,
    expected_rows: int = 4,
    expected_columns: int = 4,
) -> tuple[np.ndarray, list[list[VisibleComponent]]]:
    labels, _ = label(alpha > threshold)
    counts = np.bincount(labels.ravel())
    components: list[VisibleComponent] = []
    for component_id, region in enumerate(find_objects(labels), 1):
        if region is None or int(counts[component_id]) < minimum_pixels:
            continue
        yy, xx = region
        components.append(
            VisibleComponent(
                component_id,
                int(counts[component_id]),
                (xx.start, yy.start, xx.stop, yy.stop),
                ((xx.start + xx.stop) * 0.5, (yy.start + yy.stop) * 0.5),
            )
        )
    expected_count = expected_rows * expected_columns
    if len(components) != expected_count:
        raise NormalizeError(
            f"read-only completeness QA expected {expected_count} large visible bodies; found {len(components)}"
        )
    components.sort(key=lambda item: item.center[1])
    rows = [
        sorted(
            components[index * expected_columns:(index + 1) * expected_columns],
            key=lambda item: item.center[0],
        )
        for index in range(expected_rows)
    ]
    if any(
        max(item.center[1] for item in rows[row]) >= min(item.center[1] for item in rows[row + 1])
        for row in range(expected_rows - 1)
    ):
        raise NormalizeError(
            f"visible bodies cannot be ordered into {expected_rows} stable visual rows"
        )
    return labels, rows


def candidate_path_guard(path: Path, label_text: str) -> None:
    resolved = path.resolve()
    for protected in PROTECTED_ROOTS:
        protected_resolved = protected.resolve()
        try:
            resolved.relative_to(protected_resolved)
        except ValueError:
            continue
        raise NormalizeError(f"{label_text} must be a candidate path outside protected production root {protected_resolved}")
    lowered = str(resolved).lower()
    if "steamworks" in lowered or "liangshan_5088120" in lowered:
        raise NormalizeError(f"{label_text} may not target a Steam/Steamworks directory")


def edge_alpha_stats(alpha: np.ndarray, rect: tuple[int, int, int, int], threshold: int) -> dict[str, Any]:
    x, y, width, height = rect
    crop = alpha[y:y + height, x:x + width]
    edges = np.concatenate((crop[0], crop[-1], crop[:, 0], crop[:, -1]))
    return {
        "maximum_alpha": int(edges.max()) if edges.size else 0,
        "pixels_above_visible_threshold": int(np.count_nonzero(edges > threshold)),
        "transparent_guard": bool(np.count_nonzero(edges > threshold) == 0),
        "note": "A transparent edge guard is diagnostic only; complete-component containment is the no-clipping proof.",
    }


def load_contract(source: Path, spec_path: Path) -> tuple[dict[str, Any], Image.Image, list[FrameSpec], dict[str, Any]]:
    data = load_json(spec_path, "fixed-crop specification")
    source_rule = str(data.get("source_rule", ""))
    if (
        data.get("schema_version") != 1
        or data.get("kind") != "direction4_fixed_rect_normalization_spec"
        or source_rule not in SUPPORTED_SOURCE_RULES
    ):
        raise NormalizeError("fixed-crop specification uses an unsupported schema")
    source_record = data.get("source")
    if not isinstance(source_record, dict):
        raise NormalizeError("source provenance record is missing")
    expected_source_sha = expect_sha(source_record.get("sha256"), "source.sha256")
    actual_source_sha = sha256_file(source)
    if actual_source_sha != expected_source_sha:
        raise NormalizeError(
            f"raw source SHA mismatch: expected {expected_source_sha}, actual {actual_source_sha}"
        )
    conversation_url = stable_conversation_url(source_record.get("conversation_url"))
    base_prompt = verify_prompt_record(source_record.get("base_prompt"), "source.base_prompt", spec_path, True)
    correction_prompt = verify_prompt_record(
        source_record.get("correction_prompt"), "source.correction_prompt", spec_path, False
    )
    try:
        with Image.open(source) as opened:
            source_format = opened.format
            source_mode = opened.mode
            atlas = opened.copy()
    except OSError as error:
        raise NormalizeError(f"cannot read source PNG {source}: {error}") from error
    if source_format != "PNG" or source_mode != "RGBA":
        raise NormalizeError(
            f"source must be a true RGBA PNG before local processing; got format={source_format!r}, mode={source_mode!r}"
        )
    atlas_record = data.get("atlas")
    if not isinstance(atlas_record, dict):
        raise NormalizeError("atlas record is missing")
    declared_size = parse_int_tuple(atlas_record.get("size"), 2, "atlas.size")
    if declared_size != atlas.size:
        raise NormalizeError(f"atlas.size mismatch: declared {declared_size}, actual {atlas.size}")
    expected_rows = 4 if source_rule == SOURCE_RULE else 1
    if (
        atlas_record.get("rows") != expected_rows
        or atlas_record.get("columns") != 4
        or tuple(atlas_record.get("directions", [])) != DIRECTIONS
    ):
        raise NormalizeError(
            f"{source_rule} atlas must declare {expected_rows} rows, 4 columns "
            "and SE/SW/NE/NW direction order"
        )
    frames = parse_frames(data.get("frames"), atlas.size, expected_rows, 4)
    normalization = data.get("normalization")
    if not isinstance(normalization, dict):
        raise NormalizeError("normalization record is missing")
    integers: dict[str, int] = {}
    for name, minimum, maximum in (
        ("canvas_size", 32, 4096),
        ("target_width", 1, 4096),
        ("target_height", 1, 4096),
        ("anchor_target_y", 0, 4095),
        ("pre_scale_transparent_padding", 0, 128),
        ("visible_alpha_threshold", 0, 254),
        ("minimum_component_pixels", 1, atlas.width * atlas.height),
    ):
        value = normalization.get(name)
        if not isinstance(value, int) or isinstance(value, bool) or not minimum <= value <= maximum:
            raise NormalizeError(f"normalization.{name} is invalid")
        integers[name] = value
    if integers["target_width"] > integers["canvas_size"] or integers["target_height"] > integers["canvas_size"]:
        raise NormalizeError("target dimensions may not exceed the output canvas")
    if not 0 < integers["anchor_target_y"] < integers["canvas_size"]:
        raise NormalizeError("anchor_target_y must lie inside the output canvas")
    if normalization.get("scale_scope") != "row" or normalization.get("allow_upscale") is not False:
        raise NormalizeError("this reviewed pipeline requires row-uniform scale and allow_upscale=false")
    provenance = {
        "source_file": rel(source),
        "raw_sha256": actual_source_sha,
        "size": list(atlas.size),
        "mode": source_mode,
        "conversation_url": conversation_url,
        "base_prompt": base_prompt,
        "correction_prompt": correction_prompt,
    }
    return data, atlas, frames, {
        **integers,
        "provenance": provenance,
        "source_rule": source_rule,
        "rows": expected_rows,
        "columns": 4,
    }


def prepare_candidate(
    source: Path,
    spec_path: Path,
    output_dir: Path,
    manifest_path: Path,
) -> tuple[dict[str, Any], list[tuple[Path, bytes]]]:
    data, atlas, frames, contract = load_contract(source, spec_path)
    candidate_path_guard(output_dir, "output_dir")
    candidate_path_guard(manifest_path, "manifest")
    alpha = np.asarray(atlas)[:, :, 3]
    threshold = contract["visible_alpha_threshold"]
    labels, component_rows = visible_components(
        alpha,
        threshold,
        contract["minimum_component_pixels"],
        contract["rows"],
        contract["columns"],
    )
    major_ids = {item.component_id for row in component_rows for item in row}
    frame_qa: dict[tuple[int, int], dict[str, Any]] = {}
    for frame in frames:
        component = component_rows[frame.row][frame.column]
        x, y, width, height = frame.crop_rect
        x1, y1 = x + width, y + height
        bx0, by0, bx1, by1 = component.bbox
        if not (x <= bx0 and y <= by0 and x1 >= bx1 and y1 >= by1):
            raise NormalizeError(
                f"{frame.unit}:{frame.direction} crop truncates its complete visible component {component.bbox}"
            )
        crop_labels = labels[y:y1, x:x1]
        target_pixels = int(np.count_nonzero(crop_labels == component.component_id))
        if target_pixels != component.pixels:
            raise NormalizeError(f"{frame.unit}:{frame.direction} does not retain every target visible pixel")
        foreign_pixels = int(
            sum(np.count_nonzero(crop_labels == other_id) for other_id in major_ids - {component.component_id})
        )
        if foreign_pixels:
            raise NormalizeError(
                f"{frame.unit}:{frame.direction} crop contains {foreign_pixels} pixels from another large visible body"
            )
        anchor_x, anchor_y = frame.semantic_anchor_source
        anchor_window = alpha[
            max(0, anchor_y - 3):min(atlas.height, anchor_y + 4),
            max(0, anchor_x - 3):min(atlas.width, anchor_x + 4),
        ]
        if int(anchor_window.max()) <= threshold:
            raise NormalizeError(
                f"{frame.unit}:{frame.direction} semantic anchor has no visible foot/hoof contact within 3px"
            )
        frame_qa[(frame.row, frame.column)] = {
            "visible_component_id": component.component_id,
            "visible_component_bbox": list(component.bbox),
            "visible_component_pixels": component.pixels,
            "visible_component_pixels_retained": target_pixels,
            "foreign_large_visible_pixels": foreign_pixels,
            "visible_component_complete": True,
            "crop_edge": edge_alpha_stats(alpha, frame.crop_rect, threshold),
        }
    for index, first in enumerate(frames):
        ax, ay, aw, ah = first.crop_rect
        for second in frames[index + 1:]:
            bx, by, bw, bh = second.crop_rect
            left, top = max(ax, bx), max(ay, by)
            right, bottom = min(ax + aw, bx + bw), min(ay + ah, by + bh)
            if left < right and top < bottom:
                duplicated_visible = int(np.count_nonzero(alpha[top:bottom, left:right] > threshold))
                if duplicated_visible:
                    raise NormalizeError(
                        f"fixed crops {first.unit}:{first.direction} and {second.unit}:{second.direction} "
                        f"overlap {duplicated_visible} visible source pixels"
                    )
    canvas_size = contract["canvas_size"]
    anchor_target_y = contract["anchor_target_y"]
    prepad = contract["pre_scale_transparent_padding"]
    scales: dict[int, float] = {}
    for row in range(contract["rows"]):
        limits = [1.0]
        for frame in (item for item in frames if item.row == row):
            _, crop_y, crop_width, crop_height = frame.crop_rect
            padded_width = crop_width + prepad * 2
            padded_height = crop_height + prepad * 2
            anchor_offset_y = frame.semantic_anchor_source[1] - crop_y + prepad
            limits.extend(
                (
                    contract["target_width"] / padded_width,
                    contract["target_height"] / padded_height,
                    anchor_target_y / anchor_offset_y if anchor_offset_y else 1.0,
                    (canvas_size - anchor_target_y) / (padded_height - anchor_offset_y)
                    if padded_height > anchor_offset_y
                    else 1.0,
                )
            )
        scale = min(limits)
        if scale <= 0:
            raise NormalizeError(f"row {row} has no positive uniform scale")
        scales[row] = scale
    writes: list[tuple[Path, bytes]] = []
    outputs: list[dict[str, Any]] = []
    for frame in frames:
        x, y, crop_width, crop_height = frame.crop_rect
        crop = atlas.crop((x, y, x + crop_width, y + crop_height))
        padded = Image.new(
            "RGBA",
            (crop_width + prepad * 2, crop_height + prepad * 2),
            (0, 0, 0, 0),
        )
        padded.paste(crop, (prepad, prepad))
        scale = scales[frame.row]
        output_size = (
            max(1, round(padded.width * scale)),
            max(1, round(padded.height * scale)),
        )
        resized = padded.resize(output_size, Image.Resampling.LANCZOS)
        source_anchor_offset_y = frame.semantic_anchor_source[1] - y + prepad
        resized_anchor_offset_y = round(source_anchor_offset_y * scale)
        paste_x = round((canvas_size - output_size[0]) * 0.5)
        paste_y = anchor_target_y - resized_anchor_offset_y
        if (
            paste_x < 0
            or paste_y < 0
            or paste_x + output_size[0] > canvas_size
            or paste_y + output_size[1] > canvas_size
        ):
            raise NormalizeError(f"{frame.unit}:{frame.direction} does not fit the target canvas")
        canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        canvas.paste(resized, (paste_x, paste_y))
        payload = png_bytes(canvas)
        output = output_dir / f"{frame.unit}_{frame.state}_{frame.direction}.png"
        writes.append((output, payload))
        outputs.append(
            {
                "unit": frame.unit,
                "state": frame.state,
                "direction": frame.direction,
                "source_rule": contract["source_rule"],
                "source_slot": [frame.row, frame.column],
                "output": rel(output),
                "output_sha256": sha256_bytes(payload),
                "crop_rect": list(frame.crop_rect),
                "raw_crop_rgba_sha256": rgba_sha256(crop),
                "source_to_crop_operation": "one fixed rectangular crop; every RGBA pixel in the rectangle is retained",
                "pre_scale_transparent_padding": [prepad, prepad, prepad, prepad],
                "scale": scale,
                "scale_scope": "uniform_across_identity_row",
                "resampling": "Pillow LANCZOS on the complete padded crop",
                "output_size": list(output_size),
                "paste_xy": [paste_x, paste_y],
                "final_transparent_padding": [
                    paste_x,
                    paste_y,
                    canvas_size - paste_x - output_size[0],
                    canvas_size - paste_y - output_size[1],
                ],
                "semantic_anchor": {
                    "kind": frame.anchor_kind,
                    "source_xy_px": list(frame.semantic_anchor_source),
                    "source_crop_offset_y_px": source_anchor_offset_y,
                    "target_output_y_px": anchor_target_y,
                    "placed_output_y_px": paste_y + resized_anchor_offset_y,
                    "review_note": frame.review_note,
                },
                "read_only_component_qa": frame_qa[(frame.row, frame.column)],
                "forbidden_operations_used": [],
            }
        )
    manifest = {
        "schema_version": 1,
        "kind": "direction4_fixed_rect_candidate_manifest",
        "source_rule": contract["source_rule"],
        "candidate_only": True,
        "production_commit_allowed": False,
        "adoption_status": "pending_manual_visual_review",
        "production_assets_modified": False,
        "source": contract["provenance"],
        "spec_file": rel(spec_path),
        "spec_sha256": sha256_file(spec_path),
        "policy": {
            "allowed": [
                "fixed rectangular whole-unit crop",
                "transparent padding",
                "uniform whole-unit resize",
                "candidate import",
            ],
            "forbidden": [
                "mirroring",
                "connected-component ownership masking",
                "pixel clearing or alpha zeroing",
                "repainting",
                "local direction changes",
                "pixel synthesis",
            ],
            "component_analysis_is_read_only_qa": True,
            "visible_alpha_threshold": threshold,
            "minimum_component_pixels": contract["minimum_component_pixels"],
        },
        "normalization": {
            "canvas_size": canvas_size,
            "target_width": contract["target_width"],
            "target_height": contract["target_height"],
            "anchor_target_y": anchor_target_y,
            "pre_scale_transparent_padding": prepad,
            "scale_scope": "row",
            "allow_upscale": False,
        },
        "outputs": outputs,
    }
    return manifest, writes


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, path)
    except BaseException:
        try:
            Path(temporary_name).unlink(missing_ok=True)
        finally:
            raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Untouched RGBA Web ChatGPT PNG")
    parser.add_argument("--spec", required=True, type=Path, help="Reviewed fixed-rectangle JSON specification")
    parser.add_argument("--output-dir", required=True, type=Path, help="Candidate PNG directory outside production assets")
    parser.add_argument("--manifest", required=True, type=Path, help="Candidate manifest path outside production assets")
    parser.add_argument("--write-candidate", action="store_true", help="Write candidate PNGs and manifest")
    parser.add_argument("--overwrite-candidate", action="store_true", help="Replace an existing candidate, never production")
    args = parser.parse_args()
    source = args.source.resolve()
    spec_path = args.spec.resolve()
    output_dir = args.output_dir.resolve()
    manifest_path = args.manifest.resolve()
    if not source.is_file():
        raise SystemExit(f"Source does not exist: {source}")
    try:
        manifest, writes = prepare_candidate(source, spec_path, output_dir, manifest_path)
        collisions = [path for path, _ in writes if path.exists()]
        if manifest_path.exists():
            collisions.append(manifest_path)
        if args.write_candidate and collisions and not args.overwrite_candidate:
            raise NormalizeError(
                "candidate outputs already exist; use --overwrite-candidate after reviewing the paths: "
                + ", ".join(rel(path) for path in collisions[:3])
            )
        if args.write_candidate:
            for output, payload in writes:
                atomic_write(output, payload)
            manifest_payload = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            atomic_write(manifest_path, manifest_payload)
        summary = {
            "ok": True,
            "dry_run": not args.write_candidate,
            "candidate_only": True,
            "raw_sha256": manifest["source"]["raw_sha256"],
            "outputs": len(writes),
            "manifest": rel(manifest_path),
            "production_assets_modified": False,
            "operations": ["fixed rectangular crop", "uniform whole-unit resize", "transparent padding"],
        }
        if not args.write_candidate:
            summary["planned_outputs"] = manifest["outputs"]
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except NormalizeError as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    raise SystemExit(main())
