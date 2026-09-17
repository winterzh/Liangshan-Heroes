"""Deterministically intake a native 2x2 Liangshan portrait atlas.

The source is kept verbatim. Each quadrant is cropped at fixed coordinates and
upscaled with Pillow LANCZOS so standalone portraits retain the project's
1254x1254 codex texture size. No mirroring, repainting, masking, or background
removal is performed.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "characters" / "art_full_20260916"
SOURCE = OUT / "liangshan_core_portraits_source_20260916.png"
PROMPT = OUT / "liangshan_core_portraits_prompt_20260916.txt"
SIZE = 1254
HALF = SIZE // 2
TARGETS = {
    "chao_gai": (0, 0),
    "lu_zhishen": (HALF, 0),
    "wu_song": (0, HALF),
    "gongsun_sheng": (HALF, HALF),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    if not SOURCE.exists():
        raise SystemExit(f"missing source: {SOURCE}")
    if not PROMPT.exists():
        raise SystemExit(f"missing prompt: {PROMPT}")
    with Image.open(SOURCE) as source:
        source.load()
        if source.size != (SIZE, SIZE):
            raise SystemExit(f"source must be {SIZE}x{SIZE}, got {source.size}")
        source_mode = source.mode
        records: dict[str, dict[str, object]] = {}
        for key, (x, y) in TARGETS.items():
            box = (x, y, x + HALF, y + HALF)
            crop = source.crop(box)
            image = crop.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
            out = OUT / f"{key}_portrait_20260916.png"
            image.save(out, format="PNG", optimize=False)
            records[key] = {
                "path": str(out.relative_to(ROOT)).replace("\\", "/"),
                "crop": list(box),
                "size": list(image.size),
                "mode": image.mode,
                "sha256": sha256(out),
                "bytes": out.stat().st_size,
            }
    manifest = {
        "batch": "liangshan_core_portraits_20260916",
        "source": {
            "path": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
            "size": [SIZE, SIZE],
            "mode": source_mode,
            "sha256": sha256(SOURCE),
            "bytes": SOURCE.stat().st_size,
        },
        "prompt": {
            "path": str(PROMPT.relative_to(ROOT)).replace("\\", "/"),
            "sha256": sha256(PROMPT),
        },
        "method": "fixed 2x2 crop then 2x LANCZOS scale; source pixels retained",
        "targets": records,
    }
    manifest_path = OUT / "liangshan_core_portraits_manifest_20260916.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
