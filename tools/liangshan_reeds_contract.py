from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ROUTER = ROOT / "scripts/campaign_environment_art.gd"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, detail: object = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    source = ROOT / "assets/campaign/environment/art_scene_20260916/liangshan_reeds_source_20260916.png"
    prompt = ROOT / manifest["prompt_path"]
    check("source_present", source.is_file())
    check("source_sha256", source.is_file() and sha(source) == manifest["source_sha256"])
    if source.is_file():
        image = Image.open(source).convert("RGBA")
        check("source_size", image.size == (1254, 1254), list(image.size))
        check("source_alpha_range", image.getchannel("A").getextrema() == (0, 255), list(image.getchannel("A").getextrema()))
    check("prompt_present", prompt.is_file())
    check("prompt_sha256", prompt.is_file() and sha(prompt) == manifest["prompt_sha256"])
    check("alpha_preserved", manifest.get("alpha_preserved") is True)
    check("deterministic_sanitation_documented", "RGB=(0,0,0) only for 0<alpha<=3" in manifest.get("method", ""))

    router = ROUTER.read_text(encoding="utf-8")
    for row in manifest["targets"]:
        key = row["key"]
        target = ROOT / row["runtime_path"]
        present = target.is_file()
        check(f"{key}_present", present)
        if present:
            image = Image.open(target).convert("RGBA")
            check(f"{key}_rgba_512", image.size == (512, 512), list(image.size))
            check(f"{key}_alpha_range", image.getchannel("A").getextrema() == (0, 255), list(image.getchannel("A").getextrema()))
            bbox = image.getchannel("A").getbbox()
            actual_bbox = list(bbox) if bbox else None
            check(f"{key}_bbox", actual_bbox == row["runtime_alpha_bbox"], actual_bbox)
            check(f"{key}_sha256", sha(target) == row["runtime_sha256"], sha(target))
        pattern = re.compile(
            rf'"{re.escape(key)}"\s*:\s*\{{"level_id":"level5",\s*"source_sha256":"{re.escape(row["runtime_sha256"])}",\s*"visible_bbox_xywh":\s*{re.escape(json.dumps(row["runtime_alpha_bbox"], separators=(",", ":")))}\}}'
        )
        check(f"{key}_router_hash_bbox", bool(pattern.search(router)))

    report = {
        "schema": "liangshan_reeds_scene_contract_v1",
        "passed": all(item["passed"] for item in checks),
        "checks": checks,
        "source_sha256": manifest["source_sha256"],
        "prompt_sha256": manifest["prompt_sha256"],
        "targets": len(manifest["targets"]),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "checks": len(checks)}, ensure_ascii=False))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
