"""Create the production-sized Lu Qian walk atlas from the retained web PNG.

This is a deterministic whole-image scale only: no mirroring, masking, repaint,
alpha clearing, or color correction. The raw downloaded PNG remains the source
record and the 2x output gives the 4x4 grid integer 627px cells matching idle.
"""
from __future__ import annotations
import hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/art_full_20260915/lu_qian_walk_direction4_source.png"
OUTPUT = ROOT / "assets/characters/art_full_20260915/lu_qian_walk_direction4.png"
SOURCE_SHA256 = "f677fcdbd8c9fcbe7fb26a0e1026d6ce56aef8f8dba86cec846dc19f27238649"
TARGET_SIZE = (2508, 2508)

def main() -> int:
    actual = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    if actual != SOURCE_SHA256:
        raise SystemExit(f"source SHA mismatch: {actual}")
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != (1254, 1254):
        raise SystemExit(f"unexpected native size: {image.size}")
    output = image.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT, format="PNG", optimize=False)
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    alpha = output.getchannel("A")
    print({"source": str(SOURCE), "output": str(OUTPUT), "source_sha256": actual,
           "output_sha256": digest, "native_size": image.size,
           "production_size": output.size, "alpha_extrema": alpha.getextrema()})
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
