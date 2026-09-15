from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


# This is a fixed atlas intake for the four level-5 waterline reed groups.
# The source is a single 2x2 web-generated RGBA atlas.  We only crop fixed
# regions and scale them into the existing 512x512 runtime slots.  The tiny
# RGB sanitation keeps near-transparent browser matte colours from producing
# bright fringes; alpha and every pixel with alpha > 3 remain unchanged.
TARGETS = {
    "reeds_short": {
        "source_region": (0, 260, 627, 627),
        "visible_height": 222,
        "anchor": (115, 144),
    },
    "reeds_tall": {
        "source_region": (627, 0, 1254, 627),
        "visible_height": 301,
        "anchor": (129, 104),
    },
    "reeds_bent": {
        "source_region": (0, 650, 627, 1254),
        "visible_height": 231,
        "anchor": (85, 139),
    },
    "reeds_seeded": {
        "source_region": (627, 650, 1254, 1254),
        "visible_height": 299,
        "anchor": (121, 104),
    },
}

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets/campaign/environment/level5"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    box = image.getchannel("A").getbbox()
    return box


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()

    source = args.source.resolve()
    image = Image.open(source).convert("RGBA")
    if image.size != (1254, 1254):
        raise SystemExit(f"expected 1254x1254 source, got {image.size}")

    # Preserve the source bytes in the repo and only alter RGB for pixels that
    # are visually transparent.  No alpha is cleared and no opaque artwork is
    # repainted, mirrored, masked, or supplemented.
    pixels = image.load()
    sanitized = 0
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if 0 < a <= 3 and (r or g or b):
                pixels[x, y] = (0, 0, 0, a)
                sanitized += 1

    rows: list[dict[str, object]] = []
    for key, spec in TARGETS.items():
        tile = image.crop(spec["source_region"])
        source_box = alpha_bbox(tile)
        if source_box is None:
            raise SystemExit(f"{key}: no alpha pixels in source region")
        target_h = int(spec["visible_height"])
        scale = target_h / (source_box[3] - source_box[1])
        resized = tile.resize(
            (round(tile.width * scale), round(tile.height * scale)),
            Image.Resampling.LANCZOS,
        )
        anchor_x, anchor_y = spec["anchor"]
        paste = (
            anchor_x - round(source_box[0] * scale),
            anchor_y - round(source_box[1] * scale),
        )
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        canvas.alpha_composite(resized, paste)
        target = OUT_DIR / f"{key}.png"
        canvas.save(target, format="PNG", optimize=False)
        runtime_box = alpha_bbox(canvas)
        rows.append(
            {
                "key": key,
                "source_region_xywh": [
                    spec["source_region"][0],
                    spec["source_region"][1],
                    spec["source_region"][2] - spec["source_region"][0],
                    spec["source_region"][3] - spec["source_region"][1],
                ],
                "source_alpha_bbox": list(source_box),
                "runtime_path": str(target.relative_to(ROOT)).replace("\\", "/"),
                "runtime_size": [512, 512],
                "runtime_alpha_bbox": list(runtime_box) if runtime_box else None,
                "runtime_sha256": sha(target),
                "scale": scale,
                "anchor_xy": [anchor_x, anchor_y],
            }
        )

    data = {
        "batch_id": "art_scene_20260916_liangshan_reeds",
        "provider": "web_chatgpt",
        "conversation": "https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c",
        "source_path": str(source),
        "source_sha256": sha(source),
        "prompt_path": "assets/campaign/environment/art_scene_20260916/liangshan_reeds_prompt.txt",
        "prompt_sha256": sha(ROOT / "assets/campaign/environment/art_scene_20260916/liangshan_reeds_prompt.txt"),
        "source_size": [1254, 1254],
        "source_mode": "RGBA",
        "source_alpha_range": list(image.getchannel("A").getextrema()),
        "method": "fixed source-region crop + deterministic LANCZOS scale; RGB=(0,0,0) only for 0<alpha<=3",
        "alpha_preserved": True,
        "sanitized_low_alpha_rgb_pixels": sanitized,
        "targets": rows,
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"source_sha256": data["source_sha256"], "targets": len(rows), "sanitized": sanitized}, ensure_ascii=False))


if __name__ == "__main__":
    main()
