"""Deterministically crop Lu Qian's matching portrait from the accepted native atlas.

Only a fixed rectangle and transparent-preserving PNG encode are used.  The
source atlas remains untouched; this helper never redraws, masks, mirrors, or
recolors pixels.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/art_full_20260915/lu_qian_direction4.png"
OUTPUT = ROOT / "assets/characters/art_full_20260915/lu_qian.png"
SOURCE_SHA256 = "3f73f999960652ef35b4d3b42b39d43a937989663d8a235a1e989b705f26d8c0"
REGION = (140, 10, 500, 370)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    source = args.source if args.source.is_absolute() else ROOT / args.source
    output = args.output if args.output.is_absolute() else ROOT / args.output
    payload = source.read_bytes()
    if hashlib.sha256(payload).hexdigest() != SOURCE_SHA256:
        raise SystemExit("accepted Lu Qian source SHA mismatch")
    image = Image.open(source).convert("RGBA")
    if image.size != (1254, 1254):
        raise SystemExit(f"unexpected native source size: {image.size}")
    crop = image.crop(REGION)
    if crop.size != (360, 360) or crop.getchannel("A").getbbox() is None:
        raise SystemExit("fixed portrait crop is empty or not square")
    output.parent.mkdir(parents=True, exist_ok=True)
    crop.save(output, format="PNG", optimize=False, compress_level=9)
    print({"source": str(source), "output": str(output), "region": REGION,
           "source_sha256": SOURCE_SHA256,
           "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest()})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
