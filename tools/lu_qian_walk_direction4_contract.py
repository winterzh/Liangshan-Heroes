"""Validate the accepted Lu Qian walk atlas, source transform, and exact SpriteFrames."""
from __future__ import annotations
import argparse, hashlib, io, json
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")
FRAMES = ("a", "b", "c", "d")

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check(items, name, passed, detail=None):
    row = {"name": name, "passed": bool(passed)}
    if detail is not None:
        row["detail"] = detail
    items.append(row)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    manifest_path = ROOT / "assets/direction4/lu_qian_walk_20260915.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    checks = []
    check(checks, "manifest schema", data.get("schema") == "native_direction4_spriteframes_v1")
    check(checks, "character identity", data.get("character") == "lu_qian")
    source = data["sources"]["lu_qian_walk_atlas"]
    source_path = ROOT / source["path"]
    raw_path = ROOT / source["raw_web_source"]
    check(checks, "production source exists", source_path.is_file(), str(source_path))
    check(checks, "raw web source exists", raw_path.is_file(), str(raw_path))
    if source_path.is_file() and raw_path.is_file():
        im = Image.open(source_path).convert("RGBA")
        raw = Image.open(raw_path).convert("RGBA")
        alpha = im.getchannel("A")
        check(checks, "production source SHA", sha(source_path) == source["sha256"], sha(source_path))
        check(checks, "raw source SHA", sha(raw_path) == source["raw_web_source_sha256"], sha(raw_path))
        check(checks, "production RGBA dimensions", im.mode == "RGBA" and list(im.size) == [2508, 2508], list(im.size))
        check(checks, "raw RGBA dimensions", raw.mode == "RGBA" and list(raw.size) == [1254, 1254], list(raw.size))
        check(checks, "genuine alpha range", alpha.getextrema() == (0, 255), list(alpha.getextrema()))
        zero_fraction = alpha.histogram()[0] / (im.width * im.height)
        check(checks, "transparent fraction locked", abs(zero_fraction - source["alpha_zero_fraction"]) < 1e-12, zero_fraction)
        expected = raw.resize((2508, 2508), Image.Resampling.LANCZOS)
        check(checks, "production is exact deterministic 2x scale", im.tobytes() == expected.tobytes())
        cell = 627
        for row, direction in enumerate(DIRECTIONS):
            frame_hashes = []
            for column, frame_name in enumerate(FRAMES):
                x, y = column * cell, row * cell
                crop = alpha.crop((x, y, x + cell, y + cell))
                check(checks, f"{direction} frame {frame_name} has visible body", crop.getbbox() is not None)
                frame_hashes.append(hashlib.sha256(crop.tobytes()).hexdigest())
                pose = data["poses"][f"walk_{frame_name}_{direction}"]
                check(checks, f"{direction} frame {frame_name} fixed region", pose["region"] == [x, y, cell, cell])
                check(checks, f"{direction} frame {frame_name} square virtual frame", pose["region"][2] + pose["margin"][2] == pose["region"][3] + pose["margin"][3])
            check(checks, f"{direction} walk frames are distinct", len(set(frame_hashes)) == 4, frame_hashes)
    check(checks, "stable conversation URL", source["conversation_url"] == "https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c")
    prompt = ROOT / source["prompt_file"]
    check(checks, "prompt SHA", prompt.is_file() and sha(prompt) == source["prompt_sha256"], str(prompt))
    for direction in DIRECTIONS:
        resource = ROOT / f"assets/anim/lu_qian_walk_{direction}.tres"
        text = resource.read_text(encoding="utf-8") if resource.is_file() else ""
        check(checks, f"{direction} resource exists", resource.is_file(), str(resource))
        check(checks, f"{direction} exact native reference", f'path="res://{source["path"]}"' in text)
        for column, frame_name in enumerate(FRAMES):
            x, y = column * 627, DIRECTIONS.index(direction) * 627
            check(checks, f"{direction} frame {frame_name} exact crop", f"region = Rect2({x}, {y}, 627, 627)" in text)
            check(checks, f"{direction} frame {frame_name} filter clip", "filter_clip = true" in text)
            check(checks, f"{direction} frame {frame_name} authored metadata", "metadata/authored_direction4 = true" in text)
        check(checks, f"{direction} no PNG shadow", not (ROOT / f"assets/anim/lu_qian_walk_{direction}.png").exists())
    report = {"passed": all(item["passed"] for item in checks), "checks": checks, "manifest": str(manifest_path), "scope": "Lu Qian walk-only native web atlas and deterministic production scale; idle is separate and attack/hurt/death remain open."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "checks": len(checks)}, ensure_ascii=False))
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
