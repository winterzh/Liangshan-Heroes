#!/usr/bin/env python3
"""Strict static audit for the 40-frame Li Kui / hook-sickle batch."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from PIL import Image

import direction4_minimal_production_install as installer


REPO = installer.REPO
DIRECTIONS = installer.DIRECTIONS


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install-report", type=Path, default=REPO / "qa/direction4_minimal_production_20260902/install_report.json")
    parser.add_argument("--report", type=Path, default=REPO / "qa/direction4_minimal_production_20260902/static_audit.json")
    args = parser.parse_args()

    checks: list[dict[str, Any]] = []
    failures: list[str] = []

    def check(name: str, passed: bool, detail: Any = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})
        if not passed:
            failures.append(name)

    frames, source_records = installer.load_batch()
    check("exact requested frame cardinality", len(frames) == 40, len(frames))
    check("exact source atlas cardinality", len(source_records) == 10, len(source_records))
    manifest = json.loads(installer.PRODUCTION_MANIFEST.read_text(encoding="utf-8"))
    selected = [
        output for output in manifest.get("outputs", [])
        if output.get("unit") in ("li_kui", "gou_lian")
        and output.get("state") in ("idle", "walk", "attack", "hurt", "down")
    ]
    check("production manifest has exactly 40 scoped outputs", len(selected) == 40, len(selected))
    by_path = {str(output.get("output")): output for output in selected}
    check("production scoped output paths are unique", len(by_path) == len(selected), len(by_path))

    manifest_sources = manifest.get("sources", {})
    for source_id, expected in source_records.items():
        source = manifest_sources.get(source_id, {})
        check(f"source tracked {source_id}", bool(source), source_id)
        check(f"source raw hash {source_id}", source.get("sha256") == expected.get("sha256"), source.get("sha256"))
        check(f"source URL {source_id}", source.get("conversation_url") == expected.get("conversation_url"), source.get("conversation_url"))
        check(f"source fixed rect rule {source_id}", source.get("source_rule") == "fixed_cell_rect_v1", source.get("source_rule"))
        check(f"source direction declaration {source_id}", tuple(source.get("layout", {}).get("directions", [])) == DIRECTIONS, source.get("layout"))
        check(f"source forbids pixel deletion {source_id}", "no masking" in str(source.get("retained_pixels", "")).lower(), source.get("retained_pixels"))

    for frame in frames:
        target: Path = frame["target"]
        label = f"{frame['unit']}/{frame['state']}/{frame['direction']}"
        check(f"target exists {label}", target.is_file(), frame["target_rel"])
        if not target.is_file():
            continue
        candidate_hash = sha256(frame["candidate"])
        target_hash = sha256(target)
        check(f"target is byte-identical reviewed candidate {label}", target_hash == candidate_hash, {"target": target_hash, "candidate": candidate_hash})
        output = by_path.get(frame["target_rel"], {})
        check(f"manifest output exists {label}", bool(output), frame["target_rel"])
        check(f"manifest hash matches {label}", output.get("sha256") == target_hash, output.get("sha256"))
        check(f"manifest source matches {label}", output.get("source") == frame["source_id"], output.get("source"))
        check(f"fixed rect recorded {label}", output.get("crop_rect") == frame["record"].get("crop_rect"), output.get("crop_rect"))
        check(f"row-uniform scale recorded {label}", output.get("scale_scope") == "uniform_across_identity_row", output.get("scale_scope"))
        check(f"transparent padding recorded {label}", output.get("final_transparent_padding") == frame["record"].get("final_transparent_padding"), output.get("final_transparent_padding"))
        check(f"no excluded source pixels {label}", output.get("excluded_foreign_pixels") == 0, output.get("excluded_foreign_pixels"))
        check(f"no forbidden operations {label}", output.get("forbidden_operations_used") == [], output.get("forbidden_operations_used"))
        isolation = str(output.get("isolation", "")).lower()
        check(f"whole rectangular RGBA retained {label}", "every in-rectangle rgba pixel is retained" in isolation, isolation)
        with Image.open(target) as image:
            image.load()
            check(f"RGBA 256 canvas {label}", image.mode == "RGBA" and image.size == (256, 256), {"mode": image.mode, "size": image.size})
            alpha = image.getchannel("A")
            edge_max = max(
                alpha.crop(box).getextrema()[1]
                for box in ((0, 0, 256, 1), (0, 255, 256, 256), (0, 1, 1, 255), (255, 1, 256, 255))
            )
            check(f"transparent border {label}", edge_max == 0, edge_max)

    death_paths = [
        REPO / f"assets/anim/{unit}_death_{direction}.png"
        for unit in ("li_kui", "gou_lian") for direction in DIRECTIONS
    ]
    check("no production death aliases", not any(path.exists() for path in death_paths), [str(path) for path in death_paths if path.exists()])
    death_manifest = [
        output for output in manifest.get("outputs", [])
        if output.get("unit") in ("li_kui", "gou_lian") and output.get("state") == "death"
    ]
    check("no manifest death aliases", not death_manifest, death_manifest)
    down_outputs = [output for output in selected if output.get("state") == "down"]
    check("eight exact down outputs", len(down_outputs) == 8, len(down_outputs))
    check(
        "down source-label conversion documented",
        len(down_outputs) == 8
        and all(output.get("candidate_state") == "death" and "no death alias" in str(output.get("state_mapping_note", "")).lower() for output in down_outputs),
        [output.get("state_mapping_note") for output in down_outputs],
    )

    install_report_path = args.install_report.resolve()
    check("install report exists", install_report_path.is_file(), str(install_report_path))
    if install_report_path.is_file():
        install_report = json.loads(install_report_path.read_text(encoding="utf-8"))
        backup = install_report.get("backup", {})
        backup_dir = Path(str(backup.get("directory", ""))).resolve()
        backup_manifest = Path(str(backup.get("manifest", ""))).resolve()
        check("batch was applied", install_report.get("applied") is True, install_report.get("applied"))
        check("backup completed before write", backup.get("completed_before_write") is True, backup)
        check("backup outside repository", installer.canonical(REPO) not in backup_dir.parents and backup_dir != installer.canonical(REPO), str(backup_dir))
        check("backup manifest exists", backup_manifest.is_file(), str(backup_manifest))
        if backup_manifest.is_file():
            check("backup manifest hash", sha256(backup_manifest) == backup.get("manifest_sha256"), {"actual": sha256(backup_manifest), "expected": backup.get("manifest_sha256")})
            backup_data = json.loads(backup_manifest.read_text(encoding="utf-8"))
            check("backup recorded all targets", backup_data.get("target_count") == 40 and len(backup_data.get("targets", [])) == 40, backup_data.get("target_count"))
            existing = [item for item in backup_data.get("targets", []) if item.get("existed")]
            check("backup preserved four prior hook-sickle idle files", len(existing) == 4 and all("gou_lian_idle_" in item.get("path", "") for item in existing), existing)
            before_anim = backup_data.get("assets_anim_png_snapshot", {})
            current_anim = installer.directory_hashes(installer.ANIM_DIR)
            anim_diff = sorted(path for path in set(before_anim) | set(current_anim) if before_anim.get(path) != current_anim.get(path))
            expected_diff = sorted(frame["target_rel"] for frame in frames)
            check("assets/anim differs from prewrite snapshot only at the 40 scoped targets", anim_diff == expected_diff, {"actual_count":len(anim_diff), "unexpected":sorted(set(anim_diff) - set(expected_diff))})

    fringe_path = REPO / "qa/direction4_minimal_production_20260902/fringe_record.json"
    check("fringe record exists", fringe_path.is_file(), str(fringe_path))
    if fringe_path.is_file():
        fringe = json.loads(fringe_path.read_text(encoding="utf-8"))
        fringe_frames = fringe.get("frames", [])
        target_hashes = {sha256(frame["target"]) for frame in frames if frame["target"].is_file()}
        check("fringe record covers all 40 production bytes", len(fringe_frames) == 40 and {item.get("output_sha256") for item in fringe_frames} == target_hashes, len(fringe_frames))
        check("fringe threshold results are retained", fringe.get("threshold_exceeded_frames") == 40, fringe.get("threshold_exceeded_frames"))
        check("fringe QA did not clear pixels", fringe.get("automatic_pixel_clearing_performed") is False and all(item.get("fringe", {}).get("automatic_pixel_clearing_performed") is False for item in fringe_frames), None)
        check("fringe QA did not auto-adopt", fringe.get("automatic_adoption_granted") is False and all(item.get("fringe", {}).get("automatic_adoption_granted") is False for item in fringe_frames), None)

    unit_text = (REPO / "scripts/unit.gd").read_text(encoding="utf-8")
    hurt_call = 'Art.unit_anim_frames(ak, "hurt", animation_direction, art_variant)'
    check("generic hurt exact directional request is present", hurt_call in unit_text, hurt_call)
    check("story outcomes request independent down state", 'Art.unit_anim_frames(_anim_key(), "down", animation_direction, art_variant)' in unit_text, "scripts/unit.gd")
    check("ordinary deaths remain independent death state", 'Art.unit_anim_frames(_anim_key(), "death", animation_direction, art_variant)' in unit_text, "scripts/unit.gd")

    report = {
        "schema_version": 1,
        "kind": "direction4_minimal_production_static_audit",
        "passed": not failures,
        "checks": len(checks),
        "failures": failures,
        "scope": "Only li_kui and gou_lian, five exact runtime states, four directions. Static provenance and file coverage; runtime and visual evidence are separate.",
        "coverage": {"required": 40, "present_and_exact": sum(1 for frame in frames if frame["target"].is_file() and sha256(frame["target"]) == sha256(frame["candidate"]))},
        "checks_detail": checks,
    }
    args.report.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.report.resolve().write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"DIRECTION4_MINIMAL_STATIC {'PASS' if report['passed'] else 'FAIL'} {report['checks']} checks; coverage {report['coverage']['present_and_exact']}/40")
    if failures:
        for failure in failures:
            print("FAIL", failure)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
