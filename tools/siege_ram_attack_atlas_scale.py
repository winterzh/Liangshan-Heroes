"""Create siege_ram attack production atlas from retained native web PNG."""
from __future__ import annotations
import hashlib
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/characters/art_full_20260916/siege_ram_attack_direction4_source.png"
OUTPUT = ROOT / "assets/characters/art_full_20260916/siege_ram_attack_direction4.png"
NATIVE_SIZE = (1254, 1254)
TARGET_SIZE = (2508, 2508)


def main() -> int:
    source_sha = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    image = Image.open(SOURCE).convert("RGBA")
    if image.size != NATIVE_SIZE:
        raise SystemExit(f"unexpected native size: {image.size}")
    output = image.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT, format="PNG", optimize=False)
    print({
        "source": str(SOURCE),
        "output": str(OUTPUT),
        "source_sha256": source_sha,
        "output_sha256": hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        "native_size": image.size,
        "production_size": output.size,
        "alpha_extrema": output.getchannel("A").getextrema(),
    })
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
