#!/usr/bin/env python3
"""Static provenance and allowlist audit for the Lu Zhishen production batch."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from PIL import Image

import lu_zhishen_direction4_production_install as installer


REPO = installer.REPO
WORKSPACE = installer.WORKSPACE
OLD_SOURCE = REPO / "assets" / "campaign" / "source" / "lu_zhishen_rescue.png"
OLD_SOURCE_SHA256 = "53cd6b9e7c725d7c86cc8f1dfc65f7fef155f078db872567a4c495376122f332"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup-manifest", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=REPO / "qa" / "lu_zhishen_direction4_production_20260902" / "static_audit.json")
    args = parser.parse_args()
    checks: list[dict[str, Any]] = []
    failures: list[str] = []

    def check(name: str, passed: bool, detail: Any = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})
        if not passed:
            failures.append(name)

    candidate, frames = installer.load_frames()
    check("candidate manifest hash remains frozen", sha256(installer.CANDIDATE_MANIFEST) == installer.CANDIDATE_MANIFEST_SHA256)
    check("exact 20-frame candidate matrix", len(frames) == 20)
    production = json.loads(installer.PRODUCTION_MANIFEST.read_text(encoding="utf-8"))
    outputs = production.get("outputs", [])
    check("production manifest has exact 20-frame matrix", len(outputs) == 20, len(outputs))
    by_key = {(str(item.get("state")), str(item.get("direction"))): item for item in outputs}
    check("production output keys are unique", len(by_key) == 20, sorted(by_key))
    for frame in frames:
        key = (frame["state"], frame["direction"])
        target: Path = frame["target"]
        record = by_key.get(key, {})
        expected = frame["candidate_sha256"]
        current = sha256(target) if target.is_file() else ""
        check(f"byte-identical candidate copy {key[0]}/{key[1]}",
              current == expected == record.get("sha256"),
              {"candidate": expected, "production": current, "manifest": record.get("sha256")})
        if target.is_file():
            with Image.open(target) as image:
                image.load()
                check(f"RGBA 256 contract {key[0]}/{key[1]}", image.mode == "RGBA" and image.size == (256, 256))

    portrait = REPO / "assets" / "campaign" / "portraits" / "lu_zhishen_rescue.png"
    idle_se = REPO / "assets" / "campaign" / "anim" / "lu_zhishen_rescue_idle_se.png"
    check("campaign portrait is a byte-identical corrected idle source",
          portrait.is_file() and idle_se.is_file() and sha256(portrait) == sha256(idle_se),
          sha256(portrait) if portrait.is_file() else "missing")
    check("historical wrong source is preserved only as provenance",
          OLD_SOURCE.is_file() and sha256(OLD_SOURCE) == OLD_SOURCE_SHA256,
          sha256(OLD_SOURCE) if OLD_SOURCE.is_file() else "missing")

    check("generation and exact-alpha sessions recorded separately",
          production.get("source_generation_conversation") == installer.SOURCE_GENERATION_CONVERSATION
          and production.get("exact_alpha_cleanup_conversation") == installer.EXACT_ALPHA_CONVERSATION)
    check("web archives and candidate manifest hashes recorded",
          production.get("web_input_archive_sha256") == installer.INPUT_ARCHIVE_SHA256
          and production.get("web_download_archive_sha256") == installer.DOWNLOAD_ARCHIVE_SHA256
          and production.get("candidate_manifest_sha256") == installer.CANDIDATE_MANIFEST_SHA256)
    check("all five source prompt chains retained",
          len(production.get("sources", [])) == 5
          and all(item.get("base_prompt_sha256") and item.get("raw_sha256") and item.get("cleaned_sha256") for item in production.get("sources", [])))
    check("production intake records no forbidden pixel operation",
          production.get("forbidden_operations_used") == []
          and "byte-identical production copy" in production.get("allowed_operations", []))

    backup = json.loads(args.backup_manifest.read_text(encoding="utf-8"))
    check("backup completed before production write", backup.get("complete_before_production_write") is True)
    before_anim: dict[str, str] = backup.get("campaign_anim_png_before", {})
    current_anim = {
        path.relative_to(REPO / "assets" / "campaign" / "anim").as_posix(): sha256(path)
        for path in sorted((REPO / "assets" / "campaign" / "anim").glob("*.png"))
    }
    changed_anim = sorted(name for name in set(before_anim) | set(current_anim) if before_anim.get(name) != current_anim.get(name))
    expected_anim = sorted(frame["target"].name for frame in frames)
    check("campaign animation PNG changes are exactly the 20 allowlisted targets",
          changed_anim == expected_anim,
          {"actual": changed_anim, "expected": expected_anim})
    old_intercepts = [f"lu_zhishen_rescue_intercept_{direction}.png" for direction in installer.DIRECTIONS]
    check("legacy intercept PNG bytes remain untouched",
          all(before_anim.get(name) == current_anim.get(name) and before_anim.get(name) for name in old_intercepts),
          {name: current_anim.get(name) for name in old_intercepts})
    before_portraits: dict[str, str] = backup.get("campaign_portrait_png_before", {})
    current_portraits = {
        path.relative_to(REPO / "assets" / "campaign" / "portraits").as_posix(): sha256(path)
        for path in sorted((REPO / "assets" / "campaign" / "portraits").glob("*.png"))
    }
    changed_portraits = sorted(name for name in set(before_portraits) | set(current_portraits) if before_portraits.get(name) != current_portraits.get(name))
    check("campaign portrait PNG change is exactly Lu Zhishen rescue",
          changed_portraits == ["lu_zhishen_rescue.png"], changed_portraits)

    direction_deaths = list((REPO / "assets" / "campaign" / "anim").glob("lu_zhishen_rescue_death_*.png"))
    check("no campaign death alias was created", not direction_deaths, [str(path) for path in direction_deaths])
    imports = [
        Path(str(frame["target"]) + ".import") for frame in frames
    ] + [Path(str(portrait) + ".import")]
    check("Godot import metadata exists for all adopted PNGs", all(path.is_file() for path in imports), [str(path) for path in imports if not path.is_file()])

    campaign_text = (REPO / "scripts" / "campaign_art.gd").read_text(encoding="utf-8")
    unit_text = (REPO / "scripts" / "unit.gd").read_text(encoding="utf-8")
    check("runtime has explicit Lu intercept-to-attack route",
          "lu_zhishen_rescue" in campaign_text and "intercept" in campaign_text and "attack" in campaign_text)
    check("Unit still requests independent down and death states",
          'Art.unit_anim_frames(_anim_key(), "down", animation_direction, art_variant)' in unit_text
          and 'Art.unit_anim_frames(_anim_key(), "death", animation_direction, art_variant)' in unit_text)

    steam_before = backup.get("steam_before", {})
    steam_after = installer.steam_snapshot()
    check("Steam directory is byte-for-byte unchanged", steam_before == steam_after,
          {"before": steam_before, "after": steam_after})
    report = {
        "schema_version": 1,
        "kind": "lu_zhishen_direction4_production_static_audit",
        "passed": not failures,
        "checks": len(checks),
        "failures": failures,
        "coverage": {"required_frames": 20, "byte_identical_frames": sum(1 for frame in frames if frame["target"].is_file() and sha256(frame["target"]) == frame["candidate_sha256"])},
        "scope": "Static provenance, allowlist, import, terminal-state and Steam no-touch evidence. Runtime and visual results are separate.",
        "checks_detail": checks,
    }
    args.report.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.report.resolve().write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"LU_ZHISHEN_DIRECTION4_STATIC {'PASS' if report['passed'] else 'FAIL'} {report['checks']} checks")
    for failure in failures:
        print("FAIL", failure)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
