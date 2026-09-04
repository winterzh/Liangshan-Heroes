"""Normalize one Web ChatGPT surface into a review-only 2048 RGBA candidate.

This tool is intentionally separate from ``environment_web_art_intake.py``.
It never writes production assets and never changes the frozen prompt, mapping,
or intake evidence.  Its only pixel operations are:

* append an all-255 alpha channel to an RGB source; and
* optionally select one contiguous square source rectangle; and
* uniformly resize that whole rectangle to the frozen 2048x2048 surface size.

No mirror, mask, inpainting, edge stitch, blend, seam repair, local filtering,
pixel clearing, or partial redraw is implemented.  The output remains a
candidate until the canonical intake and human review gates accept it.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
from typing import Any

import numpy as np
from PIL import Image

import environment_web_art_intake as intake


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BATCH_MANIFEST = intake.DEFAULT_BATCH_MANIFEST
PREVIEW_TILE_SIZE = 512


class NormalizeError(RuntimeError):
    """A source, provenance, or candidate-output safety error."""


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def decoded_pixel_sha256(image: Image.Image) -> str:
    return sha256_bytes(image.tobytes())


def png_color_type(payload: bytes, label: str) -> int:
    if len(payload) < 29 or payload[:8] != b"\x89PNG\r\n\x1a\n" or payload[12:16] != b"IHDR":
        raise NormalizeError(f"{label} is not a normal PNG with IHDR")
    return int(payload[25])


def _relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def _looks_like_steamworks(path: Path) -> bool:
    return any(part.casefold() == "steamworks" for part in path.resolve().parts)


def validate_write_path(path: Path, workspace_root: Path, label: str) -> Path:
    resolved = path.resolve()
    assets = (workspace_root.resolve() / "assets").resolve()
    if _relative_to(resolved, assets):
        raise NormalizeError(f"{label} may not be written inside production assets: {resolved}")
    if _looks_like_steamworks(resolved):
        raise NormalizeError(f"{label} may not be written inside a Steamworks directory: {resolved}")
    if resolved.exists() and resolved.is_dir():
        raise NormalizeError(f"{label} names a directory: {resolved}")
    return resolved


def atomic_write(path: Path, payload: bytes, *, identical_ok: bool = False) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if not path.is_file():
            raise NormalizeError(f"candidate output is not a file: {path}")
        if identical_ok and path.read_bytes() == payload:
            return "reused_identical"
        raise NormalizeError(f"candidate output already exists with different or unreviewed bytes: {path}")
    handle, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise
    return "written"


def atomic_replace_report(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(handle, "wb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_name, path)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def encode_png(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=False, compress_level=9)
    return buffer.getvalue()


def normalized_from_rect(
    rgba: Image.Image, rect: tuple[int, int, int, int], target_size: tuple[int, int]
) -> Image.Image:
    x, y, width, height = rect
    if width != height:
        raise NormalizeError(f"normalization crop must be square, got {rect}")
    if rect == (0, 0, rgba.width, rgba.height):
        selected = rgba.copy()
    else:
        selected = rgba.crop((x, y, x + width, y + height))
    if selected.size == target_size:
        return selected
    return selected.resize(target_size, resample=Image.Resampling.LANCZOS)


def edge_band_metrics(array: np.ndarray, contract: intake.EnvironmentContract) -> dict[str, float]:
    rgb = array[:, :, :3]
    band = contract.edge_band_px
    return {
        "left_right_band_mean_rgb_delta_255": float(
            np.abs(rgb[:, :band].astype(np.int16) - rgb[:, -band:].astype(np.int16)).mean()
        ),
        "top_bottom_band_mean_rgb_delta_255": float(
            np.abs(rgb[:band].astype(np.int16) - rgb[-band:].astype(np.int16)).mean()
        ),
    }


def objective_score(metrics: dict[str, Any], contract: intake.EnvironmentContract) -> float:
    ratio = metrics.get("wrap_gradient_ratio_to_internal_p95")
    ratio_value = float("inf") if ratio is None else float(ratio)
    return max(
        float(metrics["left_right_band_mean_rgb_delta_255"]) / contract.edge_mean_max,
        float(metrics["top_bottom_band_mean_rgb_delta_255"]) / contract.edge_mean_max,
        ratio_value / contract.wrap_ratio_max,
    )


def search_square_crop(
    rgba: Image.Image,
    contract: intake.EnvironmentContract,
    minimum_size: int,
) -> tuple[tuple[int, int, int, int] | None, dict[str, Any]]:
    """Search deterministic contiguous square crops; never synthesize an edge.

    A raw-resolution proxy ranks a fixed 16px-size/8px-offset grid.  Canonical
    2048 metrics are then evaluated for the global best candidates and the two
    best candidates at every searched size.  The report states that this is a
    deterministic grid search rather than claiming an every-pixel proof.
    """

    width, height = rgba.size
    if width != height:
        raise NormalizeError("square crop search requires a square source")
    if minimum_size < 1 or minimum_size > width:
        raise NormalizeError(f"crop minimum size must be within 1..{width}, got {minimum_size}")
    if minimum_size == width:
        return None, {
            "enabled": True,
            "minimum_size": minimum_size,
            "proxy_candidate_count": 0,
            "exact_candidate_count": 0,
            "selected_crop": None,
            "passed": False,
            "note": "minimum crop size equals source size; no smaller crop exists",
        }

    raw_rgb = np.asarray(rgba, dtype=np.uint8)[:, :, :3]
    horizontal_hist, horizontal_count = intake._gradient_histogram(raw_rgb, axis=1)
    vertical_hist, vertical_count = intake._gradient_histogram(raw_rgb, axis=0)
    proxy_internal_p95 = intake._histogram_percentile(
        horizontal_hist + vertical_hist, horizontal_count + vertical_count, 0.95
    )
    size_values = set(range(width, minimum_size - 1, -16))
    size_values.update({minimum_size, 896, 960, 1024, 1088, 1152, 1216})
    sizes = sorted((size for size in size_values if minimum_size <= size < width), reverse=True)
    proxy_records: list[dict[str, Any]] = []
    best_per_size: dict[int, list[dict[str, Any]]] = {}
    target_width = contract.surface_size[0]
    for size in sizes:
        maximum_offset = width - size
        offsets = list(range(0, maximum_offset + 1, 8))
        if maximum_offset not in offsets:
            offsets.append(maximum_offset)
        raw_band = max(1, round(contract.edge_band_px * size / target_width))
        records_for_size: list[dict[str, Any]] = []
        for y in offsets:
            for x in offsets:
                candidate = raw_rgb[y : y + size, x : x + size]
                left_right = float(
                    np.abs(
                        candidate[:, :raw_band].astype(np.int16)
                        - candidate[:, -raw_band:].astype(np.int16)
                    ).mean()
                )
                top_bottom = float(
                    np.abs(
                        candidate[:raw_band].astype(np.int16)
                        - candidate[-raw_band:].astype(np.int16)
                    ).mean()
                )
                boundary_delta = np.concatenate(
                    (
                        np.abs(
                            candidate[:, -1].astype(np.int16)
                            - candidate[:, 0].astype(np.int16)
                        ).sum(axis=1),
                        np.abs(
                            candidate[-1].astype(np.int16)
                            - candidate[0].astype(np.int16)
                        ).sum(axis=1),
                    )
                )
                boundary_hist = np.bincount(boundary_delta.reshape(-1), minlength=766)
                boundary_p95 = intake._histogram_percentile(
                    boundary_hist, int(boundary_delta.size), 0.95
                )
                if proxy_internal_p95 == 0.0:
                    ratio = 0.0 if boundary_p95 == 0.0 else float("inf")
                else:
                    ratio = boundary_p95 / proxy_internal_p95
                proxy_score = max(
                    left_right / contract.edge_mean_max,
                    top_bottom / contract.edge_mean_max,
                    ratio / contract.wrap_ratio_max,
                )
                record = {
                    "rect": [x, y, size, size],
                    "proxy_score": proxy_score,
                    "proxy_left_right_band_mean_rgb_delta_255": left_right,
                    "proxy_top_bottom_band_mean_rgb_delta_255": top_bottom,
                    "proxy_wrap_ratio": ratio,
                    "proxy_edge_band_px": raw_band,
                }
                proxy_records.append(record)
                records_for_size.append(record)
        records_for_size.sort(
            key=lambda item: (
                item["proxy_score"],
                abs(item["rect"][0] - maximum_offset / 2),
                abs(item["rect"][1] - maximum_offset / 2),
                item["rect"][1],
                item["rect"][0],
            )
        )
        best_per_size[size] = records_for_size[:2]

    proxy_records.sort(
        key=lambda item: (
            item["proxy_score"],
            -item["rect"][2],
            item["rect"][1],
            item["rect"][0],
        )
    )
    selected_for_exact: dict[tuple[int, int, int, int], dict[str, Any]] = {}
    for record in proxy_records[:24]:
        selected_for_exact[tuple(record["rect"])] = record
    for records in best_per_size.values():
        for record in records:
            selected_for_exact[tuple(record["rect"])] = record

    exact_records: list[dict[str, Any]] = []
    passing: list[dict[str, Any]] = []
    for rect, proxy in selected_for_exact.items():
        normalized = normalized_from_rect(rgba, rect, contract.surface_size)
        normalized_array = np.asarray(normalized, dtype=np.uint8).copy()
        edge = edge_band_metrics(normalized_array, contract)
        exact: dict[str, Any] = {
            "rect": list(rect),
            "proxy_score": proxy["proxy_score"],
            "left_right_band_mean_rgb_delta_255": round(
                edge["left_right_band_mean_rgb_delta_255"], 6
            ),
            "top_bottom_band_mean_rgb_delta_255": round(
                edge["top_bottom_band_mean_rgb_delta_255"], 6
            ),
        }
        if (
            edge["left_right_band_mean_rgb_delta_255"] <= contract.edge_mean_max
            and edge["top_bottom_band_mean_rgb_delta_255"] <= contract.edge_mean_max
        ):
            metrics, failures = intake.inspect_surface(normalized_array, contract)
            exact["canonical_metrics"] = metrics
            exact["canonical_failures"] = failures
            exact["canonical_pass"] = not failures
            exact["canonical_score"] = objective_score(metrics, contract)
            if not failures:
                passing.append(exact)
        else:
            exact["canonical_pass"] = False
            exact["canonical_score"] = max(
                edge["left_right_band_mean_rgb_delta_255"] / contract.edge_mean_max,
                edge["top_bottom_band_mean_rgb_delta_255"] / contract.edge_mean_max,
            )
        exact_records.append(exact)

    passing.sort(
        key=lambda item: (
            -item["rect"][2],
            item["canonical_score"],
            item["rect"][1],
            item["rect"][0],
        )
    )
    selected = passing[0] if passing else None
    failed_records = [record for record in exact_records if record not in passing]
    failed_records.sort(
        key=lambda item: (
            item["canonical_score"],
            -item["rect"][2],
            item["rect"][1],
            item["rect"][0],
        )
    )
    best_failed = failed_records[0] if failed_records else None
    if best_failed is not None and "canonical_metrics" not in best_failed:
        rect = tuple(int(value) for value in best_failed["rect"])
        normalized = normalized_from_rect(rgba, rect, contract.surface_size)
        metrics, failures = intake.inspect_surface(
            np.asarray(normalized, dtype=np.uint8).copy(), contract
        )
        best_failed["canonical_metrics"] = metrics
        best_failed["canonical_failures"] = failures
        best_failed["canonical_score"] = objective_score(metrics, contract)

    search_report = {
        "enabled": True,
        "minimum_size": minimum_size,
        "source_size": [width, height],
        "grid": {
            "size_step_px": 16,
            "offset_step_px": 8,
            "additional_common_sizes": [896, 960, 1024, 1088, 1152, 1216],
            "claim": "deterministic grid search, not an every-pixel exhaustive proof",
        },
        "proxy_internal_adjacent_pixel_gradient_p95_255": proxy_internal_p95,
        "proxy_candidate_count": len(proxy_records),
        "exact_candidate_count": len(exact_records),
        "selected_crop": selected,
        "best_failed_crop": best_failed,
        "passed": selected is not None,
        "allowed_operation": "one contiguous axis-aligned square crop from the raw source",
        "forbidden_operations_used": [],
    }
    selected_rect = (
        tuple(int(value) for value in selected["rect"]) if selected is not None else None
    )
    return selected_rect, search_report


def normalize_surface(
    raw_png: Path,
    batch_id: str,
    conversation_url: str,
    prompt_sha256: str,
    candidate_dir: Path,
    workspace_root: Path,
    batch_manifest: Path,
    allow_square_crop_search: bool,
    crop_min_size: int,
    correction_prompt_file: Path | None,
) -> tuple[dict[str, Any], dict[Path, bytes]]:
    workspace_root = workspace_root.resolve()
    raw_png = raw_png.resolve()
    candidate_dir = candidate_dir.resolve()
    if not raw_png.is_file():
        raise NormalizeError(f"raw PNG does not exist: {raw_png}")
    validate_write_path(candidate_dir / "candidate.guard", workspace_root, "candidate directory")

    contract = intake.load_contract(batch_manifest)
    batches = {batch.batch_id: batch for batch in contract.batches}
    batch = batches.get(batch_id)
    if batch is None:
        raise NormalizeError(f"unknown frozen environment batch: {batch_id}")
    if batch.category != intake.SURFACE_CATEGORY:
        raise NormalizeError(
            f"{batch_id} is {batch.category}; this tool only normalizes opaque tileable surfaces"
        )
    stable_url = intake.stable_conversation_url(conversation_url, "conversation_url")
    declared_prompt_sha = intake.expect_sha(prompt_sha256, "prompt_sha256")
    if declared_prompt_sha != batch.prompt_sha256:
        raise NormalizeError(
            f"prompt SHA does not match the frozen prompt for {batch_id}: "
            f"{declared_prompt_sha} != {batch.prompt_sha256}"
        )
    correction_prompt: dict[str, Any] | None = None
    if correction_prompt_file is not None:
        correction_path = correction_prompt_file.resolve()
        if not correction_path.is_file():
            raise NormalizeError(f"correction prompt does not exist: {correction_path}")
        correction_payload = correction_path.read_bytes()
        try:
            correction_text = correction_payload.decode("utf-8")
        except UnicodeDecodeError as error:
            raise NormalizeError("correction prompt must be UTF-8 text") from error
        if len(correction_text.strip()) < 4:
            raise NormalizeError("correction prompt must contain concrete UTF-8 text")
        correction_prompt = {
            "file": str(correction_path),
            "sha256": sha256_bytes(correction_payload),
            "utf8_bytes": len(correction_payload),
        }

    raw_payload = raw_png.read_bytes()
    raw_file_sha = sha256_bytes(raw_payload)
    raw_type = png_color_type(raw_payload, "raw source")
    try:
        with Image.open(io.BytesIO(raw_payload)) as opened:
            opened.load()
            if int(getattr(opened, "n_frames", 1)) != 1 or bool(
                getattr(opened, "is_animated", False)
            ):
                raise NormalizeError("animated PNG sources are not accepted")
            raw_mode = opened.mode
            raw_size = tuple(int(value) for value in opened.size)
            if raw_mode not in ("RGB", "RGBA"):
                raise NormalizeError(f"raw decoded mode must be RGB or RGBA, got {raw_mode}")
            if raw_size[0] != raw_size[1]:
                raise NormalizeError(
                    f"raw surface must be square for a whole-image uniform resize, got {raw_size}"
                )
            if raw_mode == "RGBA":
                source_alpha = np.asarray(opened.getchannel("A"), dtype=np.uint8)
                alpha_min = int(source_alpha.min())
                alpha_max = int(source_alpha.max())
                if alpha_min != 255 or alpha_max != 255:
                    raise NormalizeError(
                        "raw RGBA surface must already be fully opaque; transparent-pixel repair is forbidden"
                    )
                rgba = opened.copy()
                alpha_operation = "preserve_existing_all_255_alpha"
            else:
                rgba = Image.new("RGBA", raw_size, (0, 0, 0, 255))
                rgba.paste(opened, (0, 0))
                alpha_operation = "append_constant_alpha_255_to_whole_image"
            raw_pixel_sha = decoded_pixel_sha256(opened)
    except OSError as error:
        raise NormalizeError(f"raw PNG cannot be decoded: {error}") from error

    target_size = contract.surface_size
    whole_rect = (0, 0, raw_size[0], raw_size[1])
    whole_normalized = normalized_from_rect(rgba, whole_rect, target_size)
    whole_metrics, whole_failures = intake.inspect_surface(
        np.asarray(whole_normalized, dtype=np.uint8).copy(), contract
    )
    crop_search: dict[str, Any] = {
        "enabled": allow_square_crop_search,
        "minimum_size": crop_min_size,
        "selected_crop": None,
        "passed": False,
        "note": "not run because the whole image passed or crop search was not requested",
    }
    selected_rect = whole_rect
    if whole_failures and allow_square_crop_search:
        selected_crop, crop_search = search_square_crop(rgba, contract, crop_min_size)
        if selected_crop is not None:
            selected_rect = selected_crop
    normalized = normalized_from_rect(rgba, selected_rect, target_size)
    if selected_rect == whole_rect:
        crop_operation = "no_crop_use_complete_source_rectangle"
    else:
        crop_operation = "single_contiguous_axis_aligned_square_crop"
    if selected_rect[2:] == target_size:
        resize_operation = "no_resize_selected_rectangle_already_2048x2048"
    else:
        resize_operation = "uniform_whole_selected_rectangle_lanczos_resize"
    normalized_array = np.asarray(normalized, dtype=np.uint8).copy()
    metrics, objective_failures = intake.inspect_surface(normalized_array, contract)
    candidate_payload = encode_png(normalized)
    candidate_type = png_color_type(candidate_payload, "normalized candidate")
    if candidate_type != 6:
        raise NormalizeError(f"normalized candidate must encode as PNG color type 6, got {candidate_type}")

    candidate_path = validate_write_path(
        candidate_dir / f"{batch_id}.normalized_2048_rgba.png",
        workspace_root,
        "normalized candidate",
    )
    preview_path = validate_write_path(
        candidate_dir / f"{batch_id}.repeat_3x3_preview_1536.png",
        workspace_root,
        "3x3 preview",
    )
    preview_tile = normalized.resize(
        (PREVIEW_TILE_SIZE, PREVIEW_TILE_SIZE), resample=Image.Resampling.LANCZOS
    )
    preview = Image.new(
        "RGBA", (PREVIEW_TILE_SIZE * 3, PREVIEW_TILE_SIZE * 3), (0, 0, 0, 255)
    )
    for row in range(3):
        for column in range(3):
            preview.paste(preview_tile, (column * PREVIEW_TILE_SIZE, row * PREVIEW_TILE_SIZE))
    preview_payload = encode_png(preview)

    normalized_sha = sha256_bytes(candidate_payload)
    preview_sha = sha256_bytes(preview_payload)
    source_scale = target_size[0] / selected_rect[2]
    report: dict[str, Any] = {
        "schema_version": 1,
        "kind": "web_chatgpt_environment_surface_normalization_candidate",
        "scope": "candidate_only_no_production_write_no_steam_write",
        "batch_id": batch_id,
        "frozen_batch_manifest": str(contract.batch_manifest),
        "frozen_batch_manifest_sha256": contract.batch_sha256,
        "source": {
            "raw_png": str(raw_png),
            "raw_sha256": raw_file_sha,
            "raw_decoded_pixel_sha256": raw_pixel_sha,
            "raw_size": list(raw_size),
            "raw_decoded_mode": raw_mode,
            "raw_png_color_type": raw_type,
            "conversation_url": stable_url,
            "prompt_file": str(batch.prompt_path),
            "prompt_sha256": declared_prompt_sha,
            "correction_prompt": correction_prompt,
        },
        "normalization": {
            "candidate_png": str(candidate_path),
            "normalized_sha256": normalized_sha,
            "normalized_decoded_pixel_sha256": sha256_bytes(normalized.tobytes()),
            "normalized_size": list(normalized.size),
            "normalized_mode": normalized.mode,
            "normalized_png_color_type": candidate_type,
            "whole_image_operations": [alpha_operation, crop_operation, resize_operation],
            "single_square_crop": {
                "source_rectangle": list(selected_rect),
                "performed": selected_rect != whole_rect,
                "source_pixels_outside_rectangle_are_only_excluded_not_modified": True,
            },
            "resize": {
                "source_rectangle": list(selected_rect),
                "destination_rectangle": [0, 0, target_size[0], target_size[1]],
                "scale_x": source_scale,
                "scale_y": source_scale,
                "resampler": "Pillow.Image.Resampling.LANCZOS",
            },
            "transparent_padding": [0, 0, 0, 0],
            "localized_pixel_operations": [],
            "forbidden_operations_performed": {
                "multiple_or_nonrectangular_crop": False,
                "mirror": False,
                "rotate": False,
                "component_extraction": False,
                "mask_or_pixel_clear": False,
                "wrap_or_edge_stitch": False,
                "blend_or_feather": False,
                "seam_repair_or_seamless_synthesis": False,
                "inpainting_or_partial_redraw": False,
                "local_filter_or_color_edit": False,
            },
        },
        "whole_source_objective_gate_before_optional_crop": {
            "metrics": whole_metrics,
            "failures": whole_failures,
            "passed": not whole_failures,
        },
        "square_crop_search": crop_search,
        "repeat_preview": {
            "preview_png": str(preview_path),
            "preview_sha256": preview_sha,
            "preview_size": list(preview.size),
            "layout": [3, 3],
            "preview_tile_size": [PREVIEW_TILE_SIZE, PREVIEW_TILE_SIZE],
            "note": "visual-review aid only; objective metrics use the full 2048 candidate",
        },
        "objective_edge_and_wrap_gate": {
            "metrics": metrics,
            "failures": objective_failures,
            "passed": not objective_failures,
        },
        "candidate_disposition": (
            "eligible_for_separate_human_review"
            if not objective_failures
            else "reject_for_production_objective_edge_or_wrap_failure"
        ),
        "production_assets_written": False,
        "steam_written": False,
        "raw_source_unchanged": None,
    }
    return report, {candidate_path: candidate_payload, preview_path: preview_payload}


def public_error(error: Exception) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "kind": "web_chatgpt_environment_surface_normalization_candidate",
        "passed": False,
        "error": str(error),
        "production_assets_written": False,
        "steam_written": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-png", type=Path, required=True)
    parser.add_argument("--batch-id", required=True)
    parser.add_argument("--conversation-url", required=True)
    parser.add_argument("--prompt-sha256", required=True)
    parser.add_argument("--candidate-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--workspace-root", type=Path, default=ROOT)
    parser.add_argument("--batch-manifest", type=Path, default=DEFAULT_BATCH_MANIFEST)
    parser.add_argument(
        "--correction-prompt-file",
        type=Path,
        help="optional exact UTF-8 follow-up prompt used for this regenerated source",
    )
    parser.add_argument(
        "--allow-square-crop-search",
        action="store_true",
        help="after a whole-image failure, search one contiguous square crop without repair",
    )
    parser.add_argument(
        "--crop-min-size",
        type=int,
        default=896,
        help="minimum raw square crop side in pixels (default: 896)",
    )
    args = parser.parse_args(argv)

    report_path: Path | None = None
    try:
        report_path = validate_write_path(args.report, args.workspace_root, "report")
        if report_path.suffix.lower() != ".json":
            raise NormalizeError("--report must end in .json")
        raw_before = sha256_file(args.raw_png.resolve()) if args.raw_png.is_file() else None
        report, writes = normalize_surface(
            args.raw_png,
            args.batch_id.strip(),
            args.conversation_url,
            args.prompt_sha256,
            args.candidate_dir,
            args.workspace_root,
            args.batch_manifest,
            args.allow_square_crop_search,
            args.crop_min_size,
            args.correction_prompt_file,
        )
        if report_path in writes or report_path == args.raw_png.resolve():
            raise NormalizeError("report path may not overwrite the raw source or a candidate PNG")
        raw_prewrite = sha256_file(args.raw_png.resolve())
        if raw_before != raw_prewrite or raw_prewrite != report["source"]["raw_sha256"]:
            raise NormalizeError("raw source changed while the candidate was being computed")
        correction_record = report["source"].get("correction_prompt")
        if correction_record is not None:
            correction_path = Path(correction_record["file"])
            if sha256_file(correction_path) != correction_record["sha256"]:
                raise NormalizeError("correction prompt changed while the candidate was being computed")
        write_status: dict[str, str] = {}
        for path, payload in writes.items():
            write_status[str(path)] = atomic_write(path, payload, identical_ok=True)
        raw_after = sha256_file(args.raw_png.resolve())
        report["raw_source_unchanged"] = raw_before == raw_after == report["source"]["raw_sha256"]
        if not report["raw_source_unchanged"]:
            for path, status in write_status.items():
                if status == "written":
                    try:
                        Path(path).unlink()
                    except FileNotFoundError:
                        pass
            raise NormalizeError("raw source changed during normalization")
        report["candidate_write_status"] = write_status
        report_payload = (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        atomic_replace_report(report_path, report_payload)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0 if report["objective_edge_and_wrap_gate"]["passed"] else 2
    except (NormalizeError, intake.IntakeError, OSError, ValueError) as error:
        failure = public_error(error)
        if report_path is not None:
            try:
                atomic_replace_report(
                    report_path,
                    (json.dumps(failure, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
                )
            except OSError:
                pass
        print(json.dumps(failure, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
