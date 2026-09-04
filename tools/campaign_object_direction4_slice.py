"""Cut a reviewed Web ChatGPT 4x4 campaign-object atlas into directional PNGs.

The atlas has exactly four rows and four columns.  Rows are supplied as
``key:state`` values, while the columns always mean SE, SW, NE, NW.  This
tool intentionally does only three pixel operations: crop each source cell,
uniformly scale the complete cell content, and pad it on a transparent canvas.
It never mirrors, paints, fills, composites, or replaces pixels.

It is intended for reviewed transparent-background Web ChatGPT artwork with
one object in each direction slot.  ``components`` identifies the 16 complete
major alpha components, sorts them into four visual rows and four columns, and
rejects a crop that would contain another visible component.  ``grid`` first
proves full transparent seams between columns and within every source column
between rows, then retains every original RGBA pixel in each whole cell.  It
never masks, repaints, mirrors, or borrows pixels from adjacent artwork.
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
from scipy.ndimage import find_objects, label


ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")
ROW_SPEC = re.compile(r"^(?P<key>[a-z0-9_]+):(?P<state>[a-z0-9_]+)$")


@dataclass(frozen=True)
class Row:
    key: str
    state: str


@dataclass(frozen=True)
class Cell:
    row: int
    column: int
    source_region: tuple[int, int, int, int]
    alpha_bounds: tuple[int, int, int, int]
    component_ids: tuple[int, ...]
    detached_component_ids: tuple[int, ...]
    component_pixels: int
    body: Image.Image
    layout: str = "components"
    source_cell: tuple[int, int, int, int] | None = None
    selected_seams: dict[str, Any] | None = None


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def project_path(path: Path) -> str:
    """Return a stable project-relative path where possible."""
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return str(path.resolve())


def resolve_path(path: Path) -> Path:
    return path if path.is_absolute() else ROOT / path


def parse_rows(value: str) -> list[Row]:
    rows: list[Row] = []
    for raw in value.split(","):
        match = ROW_SPEC.fullmatch(raw.strip())
        if match is None:
            raise SystemExit(
                "--rows must contain exactly four comma-separated key:state values "
                "using lowercase letters, digits, and underscores"
            )
        rows.append(Row(match["key"], match["state"]))
    if len(rows) != 4:
        raise SystemExit("--rows must name exactly four source rows")
    if len({(row.key, row.state) for row in rows}) != 4:
        raise SystemExit("--rows may not repeat a key:state output")
    return rows


def rect_distance(left: tuple[int, int, int, int], right: tuple[int, int, int, int]) -> float:
    """Shortest pixel-space gap between two source rectangles."""
    left_x, left_y, left_width, left_height = left
    right_x, right_y, right_width, right_height = right
    horizontal = max(left_x - (right_x + right_width), right_x - (left_x + left_width), 0)
    vertical = max(left_y - (right_y + right_height), right_y - (left_y + left_height), 0)
    return float((horizontal * horizontal + vertical * vertical) ** 0.5)


def union_rect(regions: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    x0 = min(region[0] for region in regions)
    y0 = min(region[1] for region in regions)
    x1 = max(region[0] + region[2] for region in regions)
    y1 = max(region[1] + region[3] for region in regions)
    return x0, y0, x1 - x0, y1 - y0


def reviewed_bodies(
    atlas: Image.Image,
    threshold: int,
    minimum_pixels: int,
    minimum_detached_pixels: int,
    maximum_detached_gap: float,
    detached_distance_margin: float,
) -> list[list[Cell]]:
    """Return four rows of safe crops, including unambiguous detached flags."""
    rgba = np.asarray(atlas)
    labels, _ = label(rgba[:, :, 3] > threshold)
    counts = np.bincount(labels.ravel())
    components: list[dict[str, Any]] = []
    for component_id, region in enumerate(find_objects(labels), 1):
        if region is None:
            continue
        yy, xx = region
        components.append(
            {
                "id": component_id,
                "pixels": int(counts[component_id]),
                "region": (xx.start, yy.start, xx.stop - xx.start, yy.stop - yy.start),
                "center": ((xx.start + xx.stop) * 0.5, (yy.start + yy.stop) * 0.5),
            }
        )
    base_candidates = [component for component in components if component["pixels"] >= minimum_pixels]
    if len(base_candidates) < 16:
        raise SystemExit(
            "Expected at least 16 reviewed ship bodies of at least %d alpha pixels; found %d. "
            "Regenerate/review the atlas with a complete 4x4 arrangement."
            % (minimum_pixels, len(base_candidates))
        )
    # A detached flag can itself be sizable.  Take the sixteen largest bodies
    # as slot anchors and attach only components whose ownership is geometrically
    # unambiguous.  If that assumption proves false, later overlap checks fail.
    base_components = sorted(base_candidates, key=lambda item: (-item["pixels"], item["id"]))[:16]
    base_components.sort(key=lambda item: item["center"][1])
    rows: list[list[dict[str, Any]]] = [base_components[index * 4:(index + 1) * 4] for index in range(4)]
    for row in rows:
        row.sort(key=lambda item: item["center"][0])
    if any(max(item["center"][1] for item in rows[index]) >= min(item["center"][1] for item in rows[index + 1]) for index in range(3)):
        raise SystemExit("Unable to separate the 16 bodies into four visual rows")

    flat_bases = [component for row in rows for component in row]
    base_ids = {component["id"] for component in flat_bases}
    groups: list[list[dict[str, Any]]] = [[component] for component in flat_bases]
    for component in components:
        if component["id"] in base_ids or component["pixels"] < minimum_detached_pixels:
            continue
        distances = sorted(
            (rect_distance(component["region"], base["region"]), base_index)
            for base_index, base in enumerate(flat_bases)
        )
        nearest_distance, nearest_index = distances[0]
        next_distance = distances[1][0]
        if nearest_distance > maximum_detached_gap or next_distance - nearest_distance < detached_distance_margin:
            raise SystemExit(
                "Detached alpha component %d (%d pixels) cannot be assigned safely to one ship "
                "(nearest gap %.1f, second %.1f). Regenerate/review with connected flags or clearer spacing."
                % (component["id"], component["pixels"], nearest_distance, next_distance)
        )
        groups[nearest_index].append(component)

    group_regions = [union_rect([component["region"] for component in group]) for group in groups]

    for group_index, region in enumerate(group_regions):
        own_ids = {component["id"] for component in groups[group_index]}
        x, y, width, height = region
        label_crop = labels[y:y + height, x:x + width]
        foreign_ids = [
            int(component_id)
            for component_id in np.unique(label_crop)
            if component_id > 0
            and component_id not in own_ids
            and counts[component_id] >= minimum_detached_pixels
        ]
        foreign_pixels = int(np.count_nonzero(np.isin(label_crop, foreign_ids)))
        if foreign_ids:
            raise SystemExit(
                "Output crop for ship body %d contains %d alpha pixels from unrelated component(s) %s. "
                "Regenerate/review the source rather than mixing adjacent art."
                % (groups[group_index][0]["id"], foreign_pixels, ", ".join(str(item) for item in foreign_ids))
            )

    result: list[list[Cell]] = []
    for row_index, row in enumerate(rows):
        output_row: list[Cell] = []
        for column, component in enumerate(row):
            group_index = row_index * 4 + column
            group = groups[group_index]
            x, y, width, height = group_regions[group_index]
            output_row.append(
                Cell(
                    row=row_index,
                    column=column,
                    source_region=(x, y, width, height),
                    alpha_bounds=(0, 0, width, height),
                    component_ids=tuple(item["id"] for item in group),
                    detached_component_ids=tuple(item["id"] for item in group if item["id"] != component["id"]),
                    component_pixels=sum(item["pixels"] for item in group),
                    body=atlas.crop((x, y, x + width, y + height)),
                )
            )
        result.append(output_row)
    return result


def _transparent_runs(max_alpha: np.ndarray, threshold: int) -> list[tuple[int, int]]:
    """Return half-open runs whose entire source row/column is transparent."""
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
    """Select three transparent seams near logical quarter-grid boundaries.

    A seam must be transparent for the full extent of the slice passed here.
    For vertical seams that slice is the whole atlas.  For horizontal seams it
    is one already-isolated source column, so rows can be packed at slightly
    different heights in different columns without ever sharing pixels.
    """
    length = len(max_alpha)
    cell_span = length / 4.0
    radius = cell_span * search_fraction
    runs = _transparent_runs(max_alpha, threshold)
    qualifying = [(start, end) for start, end in runs if end - start >= minimum_gap]
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
                {
                    "start": start,
                    "end": end,
                    "gap": end - start,
                    "center": (start + end) * 0.5,
                }
                for start, end in runs
                if abs((start + end) * 0.5 - nominal) <= radius
            ]
            raise SystemExit(
                "No safe %s seam near 4x4 boundary %d (nominal %.1f): need a full %s band "
                "of at least %d pixels at alpha <= %d; nearby runs=%s"
                % (axis, boundary, nominal, axis, minimum_gap, threshold, nearby)
            )
        start, end = min(
            candidates,
            key=lambda run: (abs((run[0] + run[1]) * 0.5 - nominal), -(run[1] - run[0])),
        )
        seam = {
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
        if seam["gap"] < minimum_gap or seam["max_alpha"] > threshold:
            raise SystemExit("Selected seam did not meet its own safety criterion: %s" % seam)
        seams.append(seam)
    if any(seams[index]["center"] >= seams[index + 1]["center"] for index in range(2)):
        raise SystemExit("Selected grid seams are not strictly ordered")
    return seams


def grid_bodies(
    atlas: Image.Image,
    seam_alpha_threshold: int,
    minimum_seam_gap: int,
    seam_search_fraction: float,
) -> list[list[Cell]]:
    """Return 16 whole source cells split only at audited transparent seams.

    The selected vertical seams cross the full atlas.  Each resulting column
    then receives its own full-width horizontal seams.  That deliberately
    rejects stacked art that really overlaps, while allowing a valid atlas
    whose rows are vertically staggered from one column to the next.
    """
    rgba = np.asarray(atlas)
    alpha = rgba[:, :, 3]
    x_seams = _select_grid_seams(
        np.max(alpha, axis=0),
        "vertical column",
        seam_alpha_threshold,
        minimum_seam_gap,
        seam_search_fraction,
    )
    x_cuts = [0] + [round(float(seam["center"])) for seam in x_seams] + [atlas.width]
    if any(x_cuts[index] >= x_cuts[index + 1] for index in range(4)):
        raise SystemExit("Selected vertical seams do not form four nonempty source columns")

    cells: list[list[Cell | None]] = [[None for _ in range(4)] for _ in range(4)]
    for column in range(4):
        x0, x1 = x_cuts[column], x_cuts[column + 1]
        y_seams = _select_grid_seams(
            np.max(alpha[:, x0:x1], axis=1),
            "horizontal row in source column %d" % (column + 1),
            seam_alpha_threshold,
            minimum_seam_gap,
            seam_search_fraction,
        )
        y_cuts = [0] + [round(float(seam["center"])) for seam in y_seams] + [atlas.height]
        if any(y_cuts[index] >= y_cuts[index + 1] for index in range(4)):
            raise SystemExit("Selected horizontal seams do not form four nonempty source rows in column %d" % (column + 1))
        seam_record = {"vertical": x_seams, "horizontal": y_seams, "source_column": column}
        for row in range(4):
            y0, y1 = y_cuts[row], y_cuts[row + 1]
            source_cell = (x0, y0, x1 - x0, y1 - y0)
            cell_rgba = rgba[y0:y1, x0:x1].copy()
            cell_image = Image.fromarray(cell_rgba, "RGBA")
            bounds = cell_image.getchannel("A").getbbox()
            if bounds is None:
                raise SystemExit("Transparent whole grid cell %d,%d has no source art" % (row, column))
            left, top, right, bottom = bounds
            cells[row][column] = Cell(
                row=row,
                column=column,
                source_region=(x0 + left, y0 + top, right - left, bottom - top),
                alpha_bounds=(left, top, right, bottom),
                component_ids=(),
                detached_component_ids=(),
                component_pixels=int(np.count_nonzero(cell_rgba[:, :, 3] > 0)),
                body=cell_image.crop(bounds),
                layout="grid",
                source_cell=source_cell,
                selected_seams=seam_record,
            )
    if any(cell is None for row in cells for cell in row):
        raise SystemExit("Grid extraction did not produce all 16 source cells")
    return [[cell for cell in row if cell is not None] for row in cells]


def png_bytes(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def render_body(
    body: Image.Image,
    scale: float,
    canvas_size: int,
    anchor_y: int,
) -> tuple[Image.Image, tuple[int, int], tuple[int, int]]:
    size = (
        max(1, round(body.width * scale)),
        max(1, round(body.height * scale)),
    )
    resized = body.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    paste_x = round((canvas_size - resized.width) * 0.5)
    paste_y = anchor_y - resized.height
    if paste_x < 0 or paste_y < 0 or paste_x + resized.width > canvas_size or paste_y + resized.height > canvas_size:
        raise SystemExit("Reviewed body does not fit the target canvas")
    canvas.alpha_composite(resized, (paste_x, paste_y))
    return canvas, size, (paste_x, paste_y)


def manifest_template() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "pipeline": "campaign-object-direction4",
        "sources": {},
        "outputs": [],
    }


def load_manifest(path: Path) -> dict[str, Any]:
    if not path.exists():
        return manifest_template()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"Manifest is not valid JSON: {path}: {error}") from error
    if not isinstance(data, dict):
        raise SystemExit(f"Manifest root must be an object: {path}")
    data.setdefault("schema_version", 1)
    data.setdefault("pipeline", "campaign-object-direction4")
    data.setdefault("sources", {})
    data.setdefault("outputs", [])
    if not isinstance(data["sources"], dict) or not isinstance(data["outputs"], list):
        raise SystemExit(f"Manifest has invalid sources/outputs fields: {path}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Reviewed transparent 4x4 PNG atlas")
    parser.add_argument(
        "--rows",
        required=True,
        help="Four comma-separated key:state values in top-to-bottom row order",
    )
    parser.add_argument("--prompt", required=True, type=Path, help="Saved Web ChatGPT prompt text")
    parser.add_argument("--conversation", required=True, help="Stable https://chatgpt.com/c/... URL")
    parser.add_argument("--review", required=True, help="Human review note for this source atlas")
    parser.add_argument(
        "--output-dir",
        default="assets/campaign/objects",
        type=Path,
        help="Directory for <key>_<state>_<direction>.png outputs",
    )
    parser.add_argument(
        "--manifest",
        default="assets/direction4/campaign_object_manifest.json",
        type=Path,
        help="Provenance manifest to create/update",
    )
    parser.add_argument("--canvas-size", default=512, type=int)
    parser.add_argument("--target-width", default=440, type=int)
    parser.add_argument("--target-height", default=430, type=int)
    parser.add_argument("--foot-anchor", default=0.82, type=float)
    parser.add_argument(
        "--layout",
        choices=("components", "grid"),
        default="components",
        help="components isolates 16 bodies; grid requires audited transparent seams before retaining whole cells",
    )
    parser.add_argument("--alpha-threshold", default=4, type=int, help="Alpha at or below this value is ignored")
    parser.add_argument(
        "--minimum-component-pixels",
        default=1000,
        type=int,
        help="Minimum alpha-pixel count for one reviewed directional body",
    )
    parser.add_argument(
        "--minimum-detached-component-pixels",
        default=40,
        type=int,
        help="Detached component size that must be assigned safely rather than ignored",
    )
    parser.add_argument(
        "--maximum-detached-gap",
        default=96.0,
        type=float,
        help="Largest source-pixel gap for a detached flag/rope to join its ship",
    )
    parser.add_argument(
        "--detached-distance-margin",
        default=24.0,
        type=float,
        help="Required source-pixel lead over the second-nearest ship body",
    )
    parser.add_argument(
        "--seam-alpha-threshold",
        default=6,
        type=int,
        help="Largest alpha treated as transparent while proving a grid seam",
    )
    parser.add_argument(
        "--minimum-seam-gap",
        default=8,
        type=int,
        help="Minimum continuous full-width/full-height transparent seam in source pixels",
    )
    parser.add_argument(
        "--seam-search-fraction",
        default=0.22,
        type=float,
        help="Search radius around each nominal quarter boundary, as a fraction of one logical cell",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Permit replacing an existing directional PNG or manifest entry",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and report planned output without modifying PNGs or provenance",
    )
    args = parser.parse_args()

    if args.canvas_size <= 0 or args.target_width <= 0 or args.target_height <= 0:
        raise SystemExit("Canvas and target dimensions must be positive")
    if not 0.0 < args.foot_anchor < 1.0:
        raise SystemExit("--foot-anchor must be between 0 and 1")
    if not 0 <= args.alpha_threshold <= 255:
        raise SystemExit("--alpha-threshold must be between 0 and 255")
    if args.minimum_component_pixels <= 0:
        raise SystemExit("--minimum-component-pixels must be positive")
    if args.minimum_detached_component_pixels <= 0:
        raise SystemExit("--minimum-detached-component-pixels must be positive")
    if args.maximum_detached_gap < 0.0 or args.detached_distance_margin < 0.0:
        raise SystemExit("Detached-component distances may not be negative")
    if not 0 <= args.seam_alpha_threshold <= 255 or args.minimum_seam_gap <= 0:
        raise SystemExit("Grid seam alpha threshold and gap are invalid")
    if not 0.0 < args.seam_search_fraction < 0.25:
        raise SystemExit("--seam-search-fraction must be greater than 0 and less than 0.25")
    if not args.conversation.startswith("https://chatgpt.com/c/") or "?" in args.conversation:
        raise SystemExit("Use a stable ChatGPT conversation URL without signed query parameters")

    source = resolve_path(args.source)
    prompt = resolve_path(args.prompt)
    output_dir = resolve_path(args.output_dir)
    manifest_path = resolve_path(args.manifest)
    rows = parse_rows(args.rows)
    if not source.is_file():
        raise SystemExit(f"Source atlas does not exist: {source}")
    if not prompt.is_file():
        raise SystemExit(f"Prompt file does not exist: {prompt}")

    try:
        atlas = Image.open(source).convert("RGBA")
    except OSError as error:
        raise SystemExit(f"Cannot read source atlas {source}: {error}") from error
    if atlas.width < 4 or atlas.height < 4:
        raise SystemExit("Source atlas is too small for a 4x4 layout")

    cells = (
        grid_bodies(
            atlas,
            args.seam_alpha_threshold,
            args.minimum_seam_gap,
            args.seam_search_fraction,
        )
        if args.layout == "grid"
        else reviewed_bodies(
            atlas,
            args.alpha_threshold,
            args.minimum_component_pixels,
            args.minimum_detached_component_pixels,
            args.maximum_detached_gap,
            args.detached_distance_margin,
        )
    )
    anchor_y = round(args.canvas_size * args.foot_anchor)
    # A bottom/foot anchor at 82% leaves at most anchor_y pixels above it.  The
    # requested 430px design envelope is therefore safely capped at 420px on a
    # 512px canvas, rather than clipping the mast above the transparent frame.
    effective_target_height = min(args.target_height, anchor_y)
    plans: list[tuple[Path, bytes, dict[str, Any]]] = []
    for row_index, row in enumerate(rows):
        row_scale = min(
            args.target_width / cell.body.width
            for cell in cells[row_index]
        )
        row_scale = min(
            row_scale,
            min(effective_target_height / cell.body.height for cell in cells[row_index]),
        )
        for column, direction in enumerate(DIRECTIONS):
            cell = cells[row_index][column]
            frame, output_size, paste_xy = render_body(cell.body, row_scale, args.canvas_size, anchor_y)
            output = output_dir / f"{row.key}_{row.state}_{direction}.png"
            payload = png_bytes(frame)
            entry: dict[str, Any] = {
                "key": row.key,
                "state": row.state,
                "direction": direction,
                "output": project_path(output),
                "sha256": sha256_bytes(payload),
                "source_component": {
                    "ids": list(cell.component_ids),
                    "detached_ids": list(cell.detached_component_ids),
                    "alpha_pixels": cell.component_pixels,
                    "row": row_index,
                    "column": column,
                    "region": list(cell.source_region),
                },
                "source_alpha_bounds": list(cell.alpha_bounds),
                "row_scale": row_scale,
                "output_size": list(output_size),
                "paste_xy": list(paste_xy),
                "canvas_size": [args.canvas_size, args.canvas_size],
                "anchor": [0.5, args.foot_anchor],
                "layout": cell.layout,
                "retained_pixels": (
                    "Whole source cell divided only by audited transparent seams, then crop, uniform scale and transparent padding; no masking, mirroring, repainting, filling, or pixel invention."
                    if cell.layout == "grid"
                    else "Crop, uniform scale and transparent padding only; no mirroring, repainting, filling, or pixel invention."
                ),
            }
            if cell.source_cell is not None:
                entry["source_cell"] = list(cell.source_cell)
            if cell.selected_seams is not None:
                entry["selected_seams"] = cell.selected_seams
            plans.append(
                (
                    output,
                    payload,
                    entry,
                )
            )

    collisions = [path for path, _, _ in plans if path.exists()]
    if collisions and not args.overwrite and not args.dry_run:
        examples = ", ".join(str(path) for path in collisions[:3])
        raise SystemExit(f"Refusing to replace existing output(s) without --overwrite: {examples}")

    manifest = load_manifest(manifest_path)
    source_id = source.stem
    manifest["sources"][source_id] = {
        "file": project_path(source),
        "sha256": sha256_file(source),
        "size": [atlas.width, atlas.height],
        "generation": "Web ChatGPT",
        "conversation_url": args.conversation,
        "prompt_file": project_path(prompt),
        "prompt_sha256": sha256_file(prompt),
        "review": args.review,
        "layout": {"rows": [{"key": row.key, "state": row.state} for row in rows], "directions": list(DIRECTIONS)},
        "minimum_detached_component_pixels": args.minimum_detached_component_pixels,
        "extraction_layout": args.layout,
        "grid_seam_policy": (
            {
                "alpha_threshold": args.seam_alpha_threshold,
                "minimum_gap": args.minimum_seam_gap,
                "search_fraction": args.seam_search_fraction,
                "geometry": "Three full-height vertical seams, then three full-width horizontal seams within each isolated source column.",
            }
            if args.layout == "grid"
            else None
        ),
        "retained_pixels": (
            "Whole source cells divided only by audited transparent seams, then crop, uniform scale and transparent padding; no masking, mirroring, repainting, filling, or pixel invention."
            if args.layout == "grid"
            else "Crop, uniform scale and transparent padding only; no mirroring, repainting, filling, or pixel invention."
        ),
    }
    replacement_keys = {(entry[2]["key"], entry[2]["state"], entry[2]["direction"]) for entry in plans}
    existing_keys = {
        (str(entry.get("key", "")), str(entry.get("state", "")), str(entry.get("direction", "")))
        for entry in manifest["outputs"]
        if isinstance(entry, dict)
    }
    manifest_collisions = replacement_keys & existing_keys
    if manifest_collisions and not args.overwrite and not args.dry_run:
        shown = ", ".join("%s:%s:%s" % item for item in sorted(manifest_collisions))
        raise SystemExit(f"Refusing to replace existing manifest output(s) without --overwrite: {shown}")
    manifest["outputs"] = [
        entry
        for entry in manifest["outputs"]
        if not isinstance(entry, dict)
        or (str(entry.get("key", "")), str(entry.get("state", "")), str(entry.get("direction", "")))
        not in replacement_keys
    ] + [entry for _, _, entry in plans]

    if args.dry_run:
        grid_seams: dict[str, Any] | None = None
        if args.layout == "grid":
            grid_seams = {
                "vertical": cells[0][0].selected_seams["vertical"] if cells[0][0].selected_seams else [],
                "horizontal_by_source_column": [
                    cells[0][column].selected_seams["horizontal"]
                    if cells[0][column].selected_seams
                    else []
                    for column in range(4)
                ],
            }
        print(
            json.dumps(
                {
                    "dry_run": True,
                    "source": source_id,
                    "source_sha256": manifest["sources"][source_id]["sha256"],
                    "layout": args.layout,
                    "outputs": len(plans),
                    "planned_output_paths": [entry["output"] for _, _, entry in plans],
                    "grid_seams": grid_seams,
                    "manifest": project_path(manifest_path),
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    for output, payload, _ in plans:
        temporary = output.with_name(f".{output.name}.tmp")
        temporary.write_bytes(payload)
        temporary.replace(output)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "source": source_id,
                "outputs": len(plans),
                "output_dir": project_path(output_dir),
                "manifest": project_path(manifest_path),
                "canvas_size": args.canvas_size,
                "anchor": [0.5, args.foot_anchor],
                "target_box_limit": [args.target_width, effective_target_height],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
