"""Static guard for AtlasTexture cell sampling in art/runtime factories.

This is a source-only regression check. It does not import Godot, edit PNGs,
run the game, export a build, or touch Steam state. The real renderer check is
the isolated art inventory run recorded with this batch.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def function_body(source: str, name: str) -> str:
    match = re.search(r"(?ms)^[ \t]*func " + re.escape(name) + r"\(.*?(?=^[ \t]*func |\Z)", source)
    if not match:
        raise AssertionError(f"missing function: {name}")
    return match.group(0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    checks: list[dict[str, object]] = []

    def check(name: str, ok: bool) -> None:
        checks.append({"name": name, "passed": bool(ok)})
        if not ok:
            raise AssertionError(name)

    art_db = (ROOT / "scripts" / "art_db.gd").read_text(encoding="utf-8")
    battle = (ROOT / "scripts" / "battle.gd").read_text(encoding="utf-8")
    factories = (
        ("portrait/terrain atlas", function_body(art_db, "_atlas")),
        ("campaign variant strip", function_body(art_db, "unit_anim_frames")),
        ("legacy strip", function_body(art_db, "unit_anim_frames")),
        ("directional strip slicer", function_body(art_db, "_slice_anim_strip")),
    )
    # The variant and legacy paths share unit_anim_frames, so assert the two
    # distinct creation sites rather than treating one broad function match as
    # sufficient.
    unit_body = factories[1][1]
    variant_site = unit_body[unit_body.find("var frame := AtlasTexture.new()") :]
    legacy_site = unit_body[unit_body.find("var at := AtlasTexture.new()") :]
    check("portrait/terrain AtlasTexture clips its cell", "at.filter_clip = true" in factories[0][1])
    check("campaign variant frames clip their cells", "frame.filter_clip = true" in variant_site)
    check("legacy strip frames clip their cells", "at.filter_clip = true" in legacy_site)
    check("directional strip frames clip their cells", "at.filter_clip = true" in factories[3][1])
    sliced_start = battle.find("var sliced := AtlasTexture.new()")
    sliced_site = battle[sliced_start : battle.find("frame_texture = sliced", sliced_start)]
    check("death-remains sheet clips its cell", sliced_start >= 0 and "sliced.filter_clip = true" in sliced_site)

    result = {
        "kind": "art_sampling_clip_source_selftest",
        "passed": True,
        "check_count": len(checks),
        "checks": checks,
        "production_written": False,
        "steam_modified_or_exported": False,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
