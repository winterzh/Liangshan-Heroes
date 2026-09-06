from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/campaign/source/web_death_remains_v1.png"
OUTPUT = ROOT / "assets/campaign/objects/death_remains_default.png"
REPORT = ROOT / "qa/death_remains_20260901/art_prepare.json"

EXPECTED_SOURCE_SHA256 = "5ce342aedc2cdb0e2cbcdc60368ded7eeaa0aebee4ed355970bc9222076247a0"
EXPECTED_SOURCE_SIZE = (1774, 887)
PADDED_SIZE = (1776, 888)
OUTPUT_SIZE = (1024, 512)
CELL_SIZE = 256


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_bbox_over(image: Image.Image, threshold: int) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    mask = alpha.point(lambda value: 255 if value > threshold else 0)
    return mask.getbbox()


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing source: {SOURCE}")
    source_hash = sha256(SOURCE)
    if source_hash != EXPECTED_SOURCE_SHA256:
        raise SystemExit(f"source sha mismatch: {source_hash}")

    source = Image.open(SOURCE)
    source.load()
    if source.format != "PNG" or source.mode != "RGBA" or source.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(
            f"unexpected source: format={source.format} mode={source.mode} size={source.size}"
        )
    if source.getchannel("A").getextrema() != (0, 255):
        raise SystemExit("source is not a mixed transparent RGBA image")

    # The web image is 1774x887, exactly a 2:1 layout except for rounding.
    # One transparent pixel on the left and two/one pixels of total padding make
    # all eight cells exactly square without cropping any generated pixel.
    padded = Image.new("RGBA", PADDED_SIZE, (0, 0, 0, 0))
    padded.alpha_composite(source, (1, 0))

    # Resize in premultiplied-alpha space to avoid dark RGB fringes around the
    # transparent objects, then return to ordinary straight-alpha RGBA PNG.
    atlas = padded.convert("RGBa").resize(OUTPUT_SIZE, Image.Resampling.LANCZOS).convert("RGBA")

    cells: list[dict[str, object]] = []
    for index in range(8):
        x = (index % 4) * CELL_SIZE
        y = (index // 4) * CELL_SIZE
        cell = atlas.crop((x, y, x + CELL_SIZE, y + CELL_SIZE))
        bbox8 = alpha_bbox_over(cell, 8)
        bbox99 = alpha_bbox_over(cell, 99)
        if bbox8 is None or bbox99 is None:
            raise SystemExit(f"empty remains cell: {index}")
        if bbox8[0] < 3 or bbox8[1] < 3 or bbox8[2] > CELL_SIZE - 3 or bbox8[3] > CELL_SIZE - 3:
            raise SystemExit(f"cell content touches gutter: {index} {bbox8}")
        cells.append({"index": index, "bbox_alpha_gt_8": bbox8, "bbox_alpha_gt_99": bbox99})

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT, format="PNG", optimize=True)

    alpha = atlas.getchannel("A")
    if alpha.getextrema() != (0, 255):
        raise SystemExit("output lost transparent or visible pixels")
    transparent_pixels = sum(1 for value in alpha.get_flattened_data() if value == 0)
    if transparent_pixels < int(OUTPUT_SIZE[0] * OUTPUT_SIZE[1] * 0.55):
        raise SystemExit("output transparent area is unexpectedly small")

    report = {
        "schema_version": 1,
        "source": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": source_hash,
        "source_size": list(source.size),
        "source_mode": source.mode,
        "source_alpha_extrema": list(source.getchannel("A").getextrema()),
        "conversation": "https://chatgpt.com/c/6a968371-24a0-83ea-8e33-d5fe2a8b56b2",
        "prompt": "assets/campaign/web_prompts_20260901/01_death_remains.txt",
        "processing": "transparent padding plus premultiplied-alpha Lanczos resize; no redrawing or content repair",
        "output": str(OUTPUT.relative_to(ROOT)).replace("\\", "/"),
        "output_sha256": sha256(OUTPUT),
        "output_size": list(atlas.size),
        "cell_size": CELL_SIZE,
        "transparent_pixels": transparent_pixels,
        "cells": cells,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
