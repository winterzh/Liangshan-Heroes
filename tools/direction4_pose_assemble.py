"""Assemble reviewed directional Web ChatGPT poses into short runtime strips.

This tool never paints, mirrors, warps, or synthesizes a frame. It only places
already-normalized 256x256 PNG frames side by side. ``walk`` becomes
idle->step, while ``attack`` becomes idle->strike->idle. Provenance and byte
hashes are written to the shared direction manifest.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--keys", required=True, help="Comma-separated unit keys")
    parser.add_argument("--state", required=True, choices=("walk", "attack"))
    parser.add_argument("--pose-state", required=True)
    parser.add_argument("--pose-dir", default="assets/direction4/poses", type=Path)
    parser.add_argument("--manifest", default="assets/direction4/manifest.json", type=Path)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    keys = [value.strip() for value in args.keys.split(",") if value.strip()]
    if not keys:
        raise SystemExit("--keys is empty")
    pose_dir = args.pose_dir if args.pose_dir.is_absolute() else ROOT / args.pose_dir
    manifest_path = args.manifest if args.manifest.is_absolute() else ROOT / args.manifest
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    derived = manifest.setdefault("assembled_outputs", [])
    replacements = {(key, args.state, direction) for key in keys for direction in DIRECTIONS}
    if not args.overwrite and any(
        (str(item.get("unit", "")), str(item.get("state", "")), str(item.get("direction", ""))) in replacements
        for item in derived
    ):
        raise SystemExit("Refusing to replace assembled outputs without --overwrite")

    plans: list[tuple[Path, Image.Image, dict]] = []
    for key in keys:
        for direction in DIRECTIONS:
            idle_path = ROOT / f"assets/anim/{key}_idle_{direction}.png"
            pose_path = pose_dir / f"{key}_{args.pose_state}_{direction}.png"
            if not idle_path.is_file() or not pose_path.is_file():
                raise SystemExit(f"Missing input: {idle_path} or {pose_path}")
            idle = Image.open(idle_path).convert("RGBA")
            pose = Image.open(pose_path).convert("RGBA")
            if idle.size != (256, 256) or pose.size != (256, 256):
                raise SystemExit(f"Inputs must be 256x256: {key} {direction}")
            frames = [idle, pose] if args.state == "walk" else [idle, pose, idle]
            strip = Image.new("RGBA", (256 * len(frames), 256), (0, 0, 0, 0))
            for index, frame in enumerate(frames):
                strip.alpha_composite(frame, (index * 256, 0))
            output = ROOT / f"assets/anim/{key}_{args.state}_{direction}.png"
            if output.exists() and not args.overwrite:
                raise SystemExit(f"Refusing to replace {output} without --overwrite")
            record = {
                "unit": key,
                "state": args.state,
                "direction": direction,
                "output": output.relative_to(ROOT).as_posix(),
                "frame_count": len(frames),
                "assembly": "idle+pose" if args.state == "walk" else "idle+strike+idle",
                "inputs": [
                    {"file": idle_path.relative_to(ROOT).as_posix(), "sha256": sha256(idle_path)},
                    {"file": pose_path.relative_to(ROOT).as_posix(), "sha256": sha256(pose_path)},
                ],
                "processing": "Byte-faithful frame placement only; no mirror, repaint, warp, interpolation, or generated pixels.",
            }
            plans.append((output, strip, record))

    for output, strip, record in plans:
        output.parent.mkdir(parents=True, exist_ok=True)
        strip.save(output, optimize=True)
        record["sha256"] = sha256(output)
    derived[:] = [
        item for item in derived
        if (str(item.get("unit", "")), str(item.get("state", "")), str(item.get("direction", ""))) not in replacements
    ] + [record for _, _, record in plans]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": True, "outputs": len(plans), "state": args.state}, ensure_ascii=False))


if __name__ == "__main__":
    main()
