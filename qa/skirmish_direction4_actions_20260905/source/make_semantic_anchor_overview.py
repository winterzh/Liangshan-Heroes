#!/usr/bin/env python3
"""QA-only coordinate and semantic-anchor overlays for the four 4x4 atlases.

This helper never modifies production art.  It composites the cleaned RGBA
sources over a checkerboard, adds absolute source-coordinate ticks, and (when
semantic_anchors.json exists) draws the reviewed contact points.
"""

from __future__ import annotations

import json
from pathlib import Path
from collections import deque

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
POSE_FILES = {
    "walk_step": "official_top4_walk_step_4x4_alpha15.png",
    "attack_strike": "official_top4_attack_strike_4x4_alpha15.png",
    "death_fall": "official_top4_death_fall_4x4_alpha15.png",
    "death_down": "official_top4_death_down_4x4_alpha15.png",
}
UNITS = ("guan_dao", "guan_gong", "guan_jingqi", "guan_qi")
DIRECTIONS = ("se", "sw", "ne", "nw")


def checker(size: tuple[int, int], block: int = 16) -> Image.Image:
    out = Image.new("RGBA", size, (42, 42, 42, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            shade = 64 if ((x // block) + (y // block)) % 2 == 0 else 48
            draw.rectangle((x, y, min(x + block - 1, size[0] - 1), min(y + block - 1, size[1] - 1)), fill=(shade, shade, shade, 255))
    return out


def load_anchor_map() -> dict[tuple[str, str, str], dict]:
    path = HERE / "semantic_anchors.json"
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return {(entry["pose"], entry["unit"], entry["direction"]): entry for entry in data["entries"]}


def connected_figure_bounds(source: Image.Image) -> list[list[tuple[int, int, int, int]]]:
    """Return the 16 main 8-connected alpha components in visual row/column order."""
    alpha = source.getchannel("A")
    width, height = source.size
    pixels = alpha.load()
    seen = bytearray(width * height)
    found: list[tuple[int, int, int, int, int, float, float]] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if seen[index] or pixels[x, y] == 0:
                continue
            queue = deque([(x, y)])
            seen[index] = 1
            count = 0
            min_x = max_x = x
            min_y = max_y = y
            sum_x = sum_y = 0
            while queue:
                cx, cy = queue.pop()
                count += 1
                sum_x += cx
                sum_y += cy
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for dy in (-1, 0, 1):
                    ny = cy + dy
                    if not 0 <= ny < height:
                        continue
                    for dx in (-1, 0, 1):
                        nx = cx + dx
                        if (dx == 0 and dy == 0) or not 0 <= nx < width:
                            continue
                        ni = ny * width + nx
                        if seen[ni] or pixels[nx, ny] == 0:
                            continue
                        seen[ni] = 1
                        queue.append((nx, ny))
            if count > 10_000:
                found.append((count, min_x, min_y, max_x + 1, max_y + 1, sum_x / count, sum_y / count))
    if len(found) != 16:
        raise RuntimeError(f"Expected 16 main figure components, got {len(found)}")
    found.sort(key=lambda item: item[6])
    rows: list[list[tuple[int, int, int, int]]] = []
    for row in range(4):
        group = sorted(found[row * 4:(row + 1) * 4], key=lambda item: item[5])
        rows.append([(item[1], item[2], item[3], item[4]) for item in group])
    return rows


def make_contact_zooms(pose: str, source: Image.Image, bounds: list[list[tuple[int, int, int, int]]]) -> None:
    out_dir = HERE / "anchor_review"
    out_dir.mkdir(exist_ok=True)
    font = ImageFont.load_default()
    for row, unit in enumerate(UNITS):
        panels: list[Image.Image] = []
        for col, direction in enumerate(DIRECTIONS):
            left, top, right, bottom = bounds[row][col]
            pad = 12
            # The lower 130 source pixels retain the actual foot/hoof/down-contact
            # area while still showing enough anatomy to identify it manually.
            crop_left = max(0, left - pad)
            crop_right = min(source.width, right + pad)
            crop_bottom = min(source.height, bottom + pad)
            crop_top = max(0, crop_bottom - 154)
            crop = source.crop((crop_left, crop_top, crop_right, crop_bottom))
            base = checker(crop.size, block=8)
            base.alpha_composite(crop)
            draw = ImageDraw.Draw(base)
            for x in range(((crop_left + 9) // 10) * 10, crop_right, 10):
                lx = x - crop_left
                draw.line((lx, 0, lx, crop.height - 1), fill=(20, 130, 180, 90), width=1)
                if x % 20 == 0:
                    draw.text((lx + 1, 2), str(x), font=font, fill=(255, 255, 0, 255), stroke_width=2, stroke_fill=(0, 0, 0, 255))
            for y in range(((crop_top + 4) // 5) * 5, crop_bottom, 5):
                ly = y - crop_top
                draw.line((0, ly, crop.width - 1, ly), fill=(20, 130, 180, 75), width=1)
                if y % 10 == 0:
                    draw.text((2, ly + 1), str(y), font=font, fill=(255, 255, 0, 255), stroke_width=2, stroke_fill=(0, 0, 0, 255))
            draw.rectangle((0, crop.height - 18, min(crop.width - 1, 190), crop.height - 1), fill=(0, 0, 0, 210))
            draw.text((3, crop.height - 16), f"{pose} {unit}/{direction}", font=font, fill=(255, 255, 255, 255))
            panels.append(base.resize((base.width * 2, base.height * 2), Image.Resampling.NEAREST))
        gap = 8
        montage = Image.new("RGBA", (sum(p.width for p in panels) + gap * 3, max(p.height for p in panels)), (20, 20, 20, 255))
        x = 0
        for panel in panels:
            montage.alpha_composite(panel, (x, 0))
            x += panel.width + gap
        montage.save(out_dir / f"qa_{pose}_{row + 1}_{unit}_contact_zoom.png")


def main() -> None:
    anchors = load_anchor_map()
    font = ImageFont.load_default()
    for pose, filename in POSE_FILES.items():
        source = Image.open(HERE / filename).convert("RGBA")
        base = checker(source.size)
        base.alpha_composite(source)
        draw = ImageDraw.Draw(base)
        width, height = source.size
        for i in range(1, 4):
            x = round(width * i / 4)
            y = round(height * i / 4)
            draw.line((x, 0, x, height - 1), fill=(0, 210, 255, 230), width=2)
            draw.line((0, y, width - 1, y), fill=(0, 210, 255, 230), width=2)
        for x in range(0, width, 25):
            major = x % 100 == 0
            draw.line((x, 0, x, 13 if major else 7), fill=(255, 220, 0, 255), width=2 if major else 1)
            if major:
                draw.text((x + 2, 2), str(x), font=font, fill=(255, 255, 0, 255), stroke_width=2, stroke_fill=(0, 0, 0, 255))
        for y in range(0, height, 25):
            major = y % 100 == 0
            draw.line((0, y, 13 if major else 7, y), fill=(255, 220, 0, 255), width=2 if major else 1)
            if major:
                draw.text((2, y + 2), str(y), font=font, fill=(255, 255, 0, 255), stroke_width=2, stroke_fill=(0, 0, 0, 255))
        for row, unit in enumerate(UNITS):
            for col, direction in enumerate(DIRECTIONS):
                x0 = round(width * col / 4)
                y0 = round(height * row / 4)
                label = f"{row + 1},{col + 1} {unit}/{direction}"
                draw.rectangle((x0 + 5, y0 + 18, x0 + 190, y0 + 37), fill=(0, 0, 0, 190))
                draw.text((x0 + 8, y0 + 21), label, font=font, fill=(255, 255, 255, 255))
                entry = anchors.get((pose, unit, direction))
                if not entry or entry.get("source_x_px", -1) < 0:
                    continue
                x = int(entry["source_x_px"])
                y = int(entry["source_y_px"])
                draw.ellipse((x - 8, y - 8, x + 8, y + 8), outline=(255, 0, 255, 255), width=3)
                draw.line((x - 14, y, x + 14, y), fill=(255, 0, 255, 255), width=2)
                draw.line((x, y - 14, x, y + 14), fill=(255, 0, 255, 255), width=2)
                draw.rectangle((x + 9, y - 18, x + 82, y - 2), fill=(0, 0, 0, 210))
                draw.text((x + 12, y - 17), f"{x},{y}", font=font, fill=(255, 255, 0, 255))
        suffix = "reviewed" if anchors else "coordinate_reference"
        output = HERE / f"qa_{pose}_{suffix}.png"
        base.save(output)
        print(output)
        make_contact_zooms(pose, source, connected_figure_bounds(source))


if __name__ == "__main__":
    main()
