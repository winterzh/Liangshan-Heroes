"""Validate the accepted web Zhu Zhaofeng idle atlas and exact SpriteFrames resources."""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")

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
    manifest_path = ROOT / "assets/direction4/zhu_zhaofeng_20260915.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    checks = []
    check(checks, "manifest schema", data.get("schema") == "native_direction4_spriteframes_v1")
    check(checks, "character identity", data.get("character") == "zhu_zhaofeng")
    source = data["sources"]["zhu_zhaofeng_atlas"]
    source_path = ROOT / source["path"]
    check(checks, "native source exists", source_path.is_file(), str(source_path))
    if source_path.is_file():
        im = Image.open(source_path).convert("RGBA")
        alpha = im.getchannel("A")
        check(checks, "native source SHA", sha(source_path) == source["sha256"], sha(source_path))
        check(checks, "native RGBA dimensions", im.mode == "RGBA" and list(im.size) == [1254, 1254], list(im.size))
        check(checks, "genuine alpha range", alpha.getextrema() == (0, 255), list(alpha.getextrema()))
        zero_fraction = alpha.histogram()[0] / (im.width * im.height)
        check(checks, "transparent fraction locked", abs(zero_fraction - source["alpha_zero_fraction"]) < 1e-12, zero_fraction)
        cell = 627
        for index, direction in enumerate(DIRECTIONS):
            x = (index % 2) * cell
            y = (index // 2) * cell
            crop = alpha.crop((x, y, x + cell, y + cell))
            check(checks, f"{direction} has visible body", crop.getbbox() is not None)
            pose = data["poses"][f"idle_{direction}"]
            check(checks, f"{direction} fixed region", pose["region"] == [x, y, cell, cell])
            check(checks, f"{direction} square virtual frame", pose["region"][2] + pose["margin"][2] == pose["region"][3] + pose["margin"][3])
        portrait_path = ROOT / "assets/characters/art_full_20260915/zhu_zhaofeng.png"
        check(checks, "matching portrait exists", portrait_path.is_file(), str(portrait_path))
        if portrait_path.is_file():
            portrait = Image.open(portrait_path).convert("RGBA")
            expected_portrait = im.crop((120, 0, 520, 400))
            check(checks, "portrait fixed crop size", portrait.size == (400, 400))
            check(checks, "portrait pixels equal fixed crop", portrait.tobytes() == expected_portrait.tobytes())
            check(checks, "portrait has genuine alpha", portrait.getchannel("A").getextrema() == (0, 255))
    check(checks, "stable conversation URL", source["conversation_url"] == "https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c")
    prompt = ROOT / source["prompt_file"]
    check(checks, "prompt SHA", prompt.is_file() and sha(prompt) == source["prompt_sha256"], str(prompt))
    for direction in DIRECTIONS:
        resource = ROOT / f"assets/anim/zhu_zhaofeng_idle_{direction}.tres"
        text = resource.read_text(encoding="utf-8") if resource.is_file() else ""
        pose = data["poses"][f"idle_{direction}"]
        check(checks, f"{direction} resource exists", resource.is_file(), str(resource))
        check(checks, f"{direction} exact native reference", f'path="res://{source["path"]}"' in text)
        x, y, w, h = pose["region"]
        check(checks, f"{direction} exact crop", f"region = Rect2({x}, {y}, {w}, {h})" in text)
        mx, my, mw, mh = pose["margin"]
        check(checks, f"{direction} exact padding", f"margin = Rect2({mx}, {my}, {mw}, {mh})" in text)
        check(checks, f"{direction} filter clip", "filter_clip = true" in text)
        check(checks, f"{direction} authored metadata", "metadata/authored_direction4 = true" in text)
        check(checks, f"{direction} no PNG shadow", not (ROOT / f"assets/anim/zhu_zhaofeng_idle_{direction}.png").exists())
    report = {"passed": all(item["passed"] for item in checks), "checks": checks, "manifest": str(manifest_path), "scope": "Zhu Zhaofeng idle-only native web atlas provenance and exact fixed-cell SpriteFrames; action states remain open."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "checks": len(checks)}, ensure_ascii=False))
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
