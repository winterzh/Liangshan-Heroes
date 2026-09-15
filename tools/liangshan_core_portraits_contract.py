from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART_DB = ROOT / "scripts/art_db.gd"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", type=Path, default=ROOT / "assets/characters/art_full_20260916/liangshan_core_portraits_manifest_20260916.json")
    ap.add_argument("--output", type=Path, default=ROOT / "qa/character_identity_20260916/liangshan_core_portraits_contract.json")
    args = ap.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, detail: object = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    source = ROOT / manifest["source"]["path"]
    prompt = ROOT / manifest["prompt"]["path"]
    check("source_present", source.is_file())
    check("source_sha256", source.is_file() and sha(source) == manifest["source"]["sha256"])
    if source.is_file():
        with Image.open(source) as image:
            check("source_size", image.size == (1254, 1254), list(image.size))
            check("source_mode", image.mode == manifest["source"]["mode"], image.mode)
    check("prompt_present", prompt.is_file())
    check("prompt_sha256", prompt.is_file() and sha(prompt) == manifest["prompt"]["sha256"])
    check("fixed_crop_documented", manifest.get("method") == "fixed 2x2 crop then 2x LANCZOS scale; source pixels retained")

    art_db = ART_DB.read_text(encoding="utf-8")
    for key, row in manifest["targets"].items():
        target = ROOT / row["path"]
        check(f"{key}_present", target.is_file())
        if target.is_file():
            with Image.open(target) as image:
                check(f"{key}_size", image.size == (1254, 1254), list(image.size))
                check(f"{key}_mode", image.mode == row["mode"], image.mode)
            check(f"{key}_sha256", sha(target) == row["sha256"], sha(target))
        expected = f'"{key}": "res://{row["path"]}"'
        check(f"{key}_standalone_route", expected in art_db)

    # The old atlas routes remain as fallback data; standalone routes must be distinct.
    paths = [row["path"] for row in manifest["targets"].values()]
    check("standalone_paths_unique", len(paths) == len(set(paths)), paths)
    report = {
        "schema": "liangshan_core_portraits_contract_v1",
        "passed": all(item["passed"] for item in checks),
        "checks": checks,
        "source_sha256": manifest["source"]["sha256"],
        "prompt_sha256": manifest["prompt"]["sha256"],
        "targets": len(manifest["targets"]),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"passed": report["passed"], "checks": len(checks)}, ensure_ascii=False))
    raise SystemExit(0 if report["passed"] else 1)


if __name__ == "__main__":
    main()
