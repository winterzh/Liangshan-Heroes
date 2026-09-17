"""Deterministically crop Zhu Zhaofeng's matching portrait from his native atlas."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/art_full_20260915/zhu_zhaofeng_direction4.png"
OUTPUT = ROOT / "assets/characters/art_full_20260915/zhu_zhaofeng.png"
SOURCE_SHA256 = "046be9f9632628a8d35edad6171e8f24914483adc40e9874e64d7fec5ff178b1"
REGION = (120, 0, 520, 400)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    source = args.source if args.source.is_absolute() else ROOT / args.source
    output = args.output if args.output.is_absolute() else ROOT / args.output
    payload = source.read_bytes()
    if hashlib.sha256(payload).hexdigest() != SOURCE_SHA256:
        raise SystemExit("accepted Zhu Zhaofeng source SHA mismatch")
    image = Image.open(source).convert("RGBA")
    if image.size != (1254, 1254):
        raise SystemExit(f"unexpected native source size: {image.size}")
    crop = image.crop(REGION)
    if crop.size != (400, 400) or crop.getchannel("A").getbbox() is None:
        raise SystemExit("fixed portrait crop is empty or not square")
    output.parent.mkdir(parents=True, exist_ok=True)
    crop.save(output, format="PNG", optimize=False, compress_level=9)
    print({"source": str(source), "output": str(output), "region": REGION,
           "source_sha256": SOURCE_SHA256,
           "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest()})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
