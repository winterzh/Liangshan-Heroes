from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
from PIL import Image

# Browser-generated source intake only: quadrants are cropped and scaled into
# existing 512x512 runtime slots. No masks, repainting, mirroring, or pixel clearing.
TARGETS = {
    "huangnigang_pine_old": {"quadrant": (0, 0), "visible_height": 330, "anchor": (89, 91)},
    "huangnigang_pine_double": {"quadrant": (1, 0), "visible_height": 335, "anchor": (86, 88)},
    "huangnigang_pine_young_lean": {"quadrant": (0, 1), "visible_height": 303, "anchor": (103, 104)},
}
ROOT = Path(__file__).resolve().parents[1]

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, required=True)
    args = ap.parse_args()
    source = args.source.resolve()
    im = Image.open(source).convert("RGBA")
    if im.size != (1254, 1254):
        raise SystemExit(f"expected 1254x1254 source, got {im.size}")
    quadrant = 627
    produced = []
    for name, spec in TARGETS.items():
        qx, qy = spec["quadrant"]
        tile = im.crop((qx * quadrant, qy * quadrant, (qx + 1) * quadrant, (qy + 1) * quadrant))
        bbox = tile.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"{name}: no visible pixels")
        # Fit the generated tree to the previous slot's measured visual height.
        scale = spec["visible_height"] / (bbox[3] - bbox[1])
        resized = tile.resize((round(tile.width * scale), round(tile.height * scale)), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        x, y = spec["anchor"]
        canvas.alpha_composite(resized, (x, y))
        target = ROOT / "assets/campaign/environment/level1" / f"{name}.png"
        canvas.save(target, format="PNG", optimize=False)
        out_bbox = canvas.getchannel("A").getbbox()
        produced.append({
            "key": name,
            "quadrant_xy": [qx, qy],
            "source_region": [qx * quadrant, qy * quadrant, quadrant, quadrant],
            "source_alpha_bbox": list(bbox),
            "runtime_path": str(target.relative_to(ROOT)).replace("\\", "/"),
            "runtime_size": list(canvas.size),
            "runtime_alpha_bbox": list(out_bbox) if out_bbox else None,
            "runtime_sha256": sha(target),
            "scale": scale,
            "anchor_xy": [x, y],
        })
    report = {
        "batch_id": "art_scene_20260916_huangnigang_pines",
        "provider": "web_chatgpt",
        "conversation": "https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c",
        "source_path": str(source),
        "source_sha256": sha(source),
        "source_size": list(im.size),
        "source_mode": im.mode,
        "source_alpha_range": list(im.getchannel("A").getextrema()),
        "method": "deterministic quadrant crop + LANCZOS scale into existing 512x512 slots",
        "targets": produced,
    }
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"source_sha256": report["source_sha256"], "targets": len(produced)}, ensure_ascii=False))

if __name__ == "__main__":
    main()
