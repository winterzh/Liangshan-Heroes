#!/usr/bin/env python3
"""Static provenance and allowlist audit for the Mengzhou Wu Song batch."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from PIL import Image

import wu_song_mengzhou_direction4_production_install as installer


REPO = installer.REPO


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup-manifest", type=Path, required=True)
    parser.add_argument("--report", type=Path, default=REPO / "qa" / "wu_song_mengzhou_direction4_production_20260902" / "static_audit.json")
    args = parser.parse_args()
    checks: list[dict[str, Any]] = []
    failures: list[str] = []

    def check(name: str, passed: bool, detail: Any = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})
        if not passed:
            failures.append(name)

    candidate, verification, frames = installer.load_verified()
    production = json.loads(installer.PRODUCTION_MANIFEST.read_text(encoding="utf-8"))
    backup = json.loads(args.backup_manifest.read_text(encoding="utf-8"))
    check("candidate manifest hash remains frozen", sha256(installer.CANDIDATE_MANIFEST) == installer.CANDIDATE_MANIFEST_SHA256)
    check("web exact-alpha verification remains frozen and PASS", sha256(installer.WEB_VERIFICATION) == installer.WEB_VERIFICATION_SHA256 and verification.get("all_pass") is True)
    check("exact 20-frame candidate matrix", len(frames) == 20)
    outputs = production.get("outputs", [])
    by_key = {(str(item.get("state")), str(item.get("direction"))): item for item in outputs}
    check("production manifest has unique 20-frame matrix", len(outputs) == 20 and len(by_key) == 20, sorted(by_key))
    for frame in frames:
        key = (frame["state"], frame["direction"])
        target: Path = frame["target"]
        record = by_key.get(key, {})
        expected = frame["candidate_sha256"]
        current = sha256(target) if target.is_file() else ""
        check(f"byte-identical candidate copy {key[0]}/{key[1]}", current == expected == record.get("sha256"), {"candidate": expected, "production": current})
        if target.is_file():
            with Image.open(target) as image:
                image.load()
                alpha = image.getchannel("A")
                edges = [alpha.crop((0, 0, 256, 1)), alpha.crop((0, 255, 256, 256)), alpha.crop((0, 1, 1, 255)), alpha.crop((255, 1, 256, 255))]
                check(f"RGBA 256 transparent-border contract {key[0]}/{key[1]}", image.mode == "RGBA" and image.size == (256, 256) and max(edge.getextrema()[1] for edge in edges) == 0)

    portrait = REPO / "assets" / "campaign" / "portraits" / "wu_song_mengzhou.png"
    idle_se = REPO / "assets" / "campaign" / "anim" / "wu_song_mengzhou_idle_se.png"
    check("campaign portrait is byte-identical idle_se", portrait.is_file() and idle_se.is_file() and sha256(portrait) == sha256(idle_se))
    check("source, hurt, and alpha webpage sessions are recorded", set(production.get("source_generation_conversations", [])) == {installer.SOURCE_CONVERSATION, installer.HURT_CONVERSATION} and production.get("exact_alpha_cleanup_conversation") == installer.ALPHA_CONVERSATION)
    check("archive and candidate hashes are recorded", production.get("web_input_archive_sha256") == installer.INPUT_ARCHIVE_SHA256 and production.get("web_download_archive_sha256") == installer.DOWNLOAD_ARCHIVE_SHA256 and production.get("candidate_manifest_sha256") == installer.CANDIDATE_MANIFEST_SHA256)
    check("all five prompt/source chains retained", len(production.get("sources", [])) == 5 and all(item.get("prompt_sha256") and item.get("raw_sha256") and item.get("cleaned_sha256") for item in production.get("sources", [])))
    evidence = production.get("original_evidence", {})
    check("original attire and kick evidence retained", "万字头巾" in evidence.get("attire", "") and "赤手空拳" in evidence.get("attire", "") and "第二脚高踢" in evidence.get("signature_action", "") and evidence.get("chapter_28", "").startswith("https://zh.wikisource.org/"))
    check("no forbidden local pixel operation recorded", production.get("forbidden_operations_used") == [] and "byte-identical production copy" in production.get("allowed_operations", []))
    check("backup completed before write", backup.get("complete_before_production_write") is True)
    backup_targets = {str(item.get("path")): item for item in backup.get("targets", [])}
    expected_relatives = {frame["target"].relative_to(installer.WORKSPACE).as_posix() for frame in frames}
    expected_relatives.add(portrait.relative_to(installer.WORKSPACE).as_posix())
    check("all 21 bitmap targets have prewrite backup records", expected_relatives.issubset(backup_targets), sorted(expected_relatives - set(backup_targets)))
    changed_bitmap_targets = []
    for relative in expected_relatives:
        item = backup_targets[relative]
        current = installer.WORKSPACE / relative
        before = str(item.get("sha256") or "")
        after = sha256(current) if current.is_file() else ""
        if before != after:
            changed_bitmap_targets.append(relative)
    check("all intended bitmap targets changed from prior batch", len(changed_bitmap_targets) == 21, changed_bitmap_targets)
    direction_deaths = list((REPO / "assets" / "campaign" / "anim").glob("wu_song_mengzhou_death_*.png"))
    check("no campaign death alias was created", not direction_deaths, [str(path) for path in direction_deaths])
    imports = [Path(str(frame["target"]) + ".import") for frame in frames] + [Path(str(portrait) + ".import")]
    check("Godot import metadata exists for all adopted PNGs", all(path.is_file() for path in imports), [str(path) for path in imports if not path.is_file()])
    battle_text = (REPO / "scripts" / "battle.gd").read_text(encoding="utf-8")
    level_text = (REPO / "scripts" / "levels" / "level7_kuaihuolin.gd").read_text(encoding="utf-8")
    check("signature kick declares bounded nearest-foe facing", '"face_nearest_foe": true' in level_text and '"face_nearest_foe_radius": 120.0' in level_text)
    check("cast path locks declared nearest foe without changing effect center", 'var facing_point := lp' in battle_text and 'facing_point = facing_foe.position' in battle_text and 'var center: Vector2 = lp if ad["targeted"] else caster.position' in battle_text)
    steam_before = backup.get("steam_before", {})
    steam_after = installer.steam_snapshot()
    check("Steam directory is byte-for-byte unchanged", steam_before == steam_after, {"before": steam_before, "after": steam_after})
    report = {
        "schema_version": 1, "kind": "wu_song_mengzhou_direction4_production_static_audit",
        "passed": not failures, "checks": len(checks), "failures": failures,
        "coverage": {"required_frames": 20, "byte_identical_frames": sum(1 for frame in frames if frame["target"].is_file() and sha256(frame["target"]) == frame["candidate_sha256"])},
        "scope": "Static provenance, original-attire evidence, allowlist, import, direction-lock declaration, terminal-state and Steam no-touch evidence. Runtime and visual results are separate.",
        "checks_detail": checks,
    }
    args.report.resolve().parent.mkdir(parents=True, exist_ok=True)
    args.report.resolve().write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WU_SONG_MENGZHOU_DIRECTION4_STATIC {'PASS' if report['passed'] else 'FAIL'} {report['checks']} checks")
    for failure in failures:
        print("FAIL", failure)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
