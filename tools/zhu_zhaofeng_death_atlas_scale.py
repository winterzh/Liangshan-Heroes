"""Create the production Zhu Zhaofeng death atlas from the retained web PNG.

The web image has a 1230x1278 transparent canvas. We preserve every source
pixel, center it on a transparent 1278x1278 canvas, then perform one deterministic
LANCZOS resize to the shared 2508x2508 production grid. No drawing, mirroring,
masking, recoloring, or source-pixel clearing is performed.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/art_full_20260915/zhu_zhaofeng_death_direction4_source.png"
OUTPUT = ROOT / "assets/characters/art_full_20260915/zhu_zhaofeng_death_direction4.png"
SOURCE_SHA256 = "66a790df3b3bf471117c733bf1ca35609f81274072cf5d94d1692d620ed8fd60"
NATIVE_SIZE = (1230, 1278)
CANVAS_SIZE = (1278, 1278)
TARGET_SIZE = (2508, 2508)


def main() -> int:
    actual = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if actual != SOURCE_SHA256:
        raise SystemExit(f"source SHA mismatch: {actual}")
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != NATIVE_SIZE:
        raise SystemExit(f"unexpected native size: {image.size}")
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    canvas.paste(image, ((CANVAS_SIZE[0] - image.width) // 2,
                         (CANVAS_SIZE[1] - image.height) // 2))
    output = canvas.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT, format="PNG", optimize=False)
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    print({"source": str(SOURCE), "output": str(OUTPUT), "source_sha256": actual,
           "output_sha256": digest, "native_size": image.size,
           "padded_canvas_size": canvas.size, "production_size": output.size,
           "alpha_extrema": output.getchannel("A").getextrema()})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
