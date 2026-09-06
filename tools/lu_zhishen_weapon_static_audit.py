#!/usr/bin/env python3
"""Static source audit for Lu Zhishen's iron-staff routing.

This intentionally reads only production source and writes QA evidence.  It
does not inspect or mutate bitmap art, web downloads, or Steam content.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "qa" / "lu_zhishen_iron_staff_20260902" / "static_report.json"
FILES = {
    "unit": ROOT / "scripts" / "unit.gd",
    "battle": ROOT / "scripts" / "battle.gd",
    "defs": ROOT / "scripts" / "defs.gd",
    "sfx": ROOT / "scripts" / "sfx.gd",
    "campaign": ROOT / "scripts" / "campaign.gd",
    "level6": ROOT / "scripts" / "levels" / "level6_yezhulin.gd",
    "bios": ROOT / "scripts" / "bios.gd",
    "lore": ROOT / "scripts" / "lore_data.gd",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gd_function(source: str, name: str) -> str:
    match = re.search(rf"^func {re.escape(name)}\([^\n]*\).*?(?=^func |\Z)", source, re.M | re.S)
    return match.group(0) if match else ""


def main() -> int:
    text = {name: path.read_text(encoding="utf-8-sig") for name, path in FILES.items()}
    checks: list[dict[str, object]] = []

    def check(name: str, passed: bool, details: object = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "details": details})
        print(f"[lu-iron-staff-static] {'PASS' if passed else 'FAIL'} {name}" +
              ("" if details is None else f" :: {json.dumps(details, ensure_ascii=False)}"))

    lu_def = re.search(r'"lu_zhishen"\s*:\s*\{.*?\},', text["defs"], re.S)
    check("unit definition found", lu_def is not None)
    lu_def_text = lu_def.group(0) if lu_def else ""
    check("unit definition has exact iron_staff profile",
          '"weapon_profile": "iron_staff"' in lu_def_text)
    check("unit definition does not declare forbidden profile",
          not re.search(r'"weapon_profile"\s*:\s*"(?:axe|spear|hammer|club|wood_staff|crescent_spade)"', lu_def_text))

    check("weapon enum declares IRON_STAFF", re.search(r'enum WK \{[^}]*\bIRON_STAFF\b', text["unit"]) is not None)
    check("Lu key and profile resolve IRON_STAFF",
          'weapon_profile == "iron_staff" or key == "lu_zhishen"' in text["unit"]
          and '_weapon = WK.IRON_STAFF' in text["unit"])
    check("Lu no longer shares axe branch",
          'key == "li_kui" or key == "lu_zhishen"' not in text["unit"]
          and 'key == "lu_zhishen" or key == "li_kui"' not in text["unit"])
    route_functions = ("_attack", "_weapon_kind", "_swing_offset", "_swing_rot", "_draw_swing_fx")
    route_presence = {name: "WK.IRON_STAFF" in gd_function(text["unit"], name)
                      for name in route_functions}
    check("iron staff has dedicated timing, mapping, motion, rotation and draw routes",
          all(route_presence.values()), route_presence)
    check("iron staff routes atk_staff sound", 'WK.IRON_STAFF: return "atk_staff"' in text["unit"])

    check("Lu sweep does not route slash or spear",
          '"lu_sweep": "iron_staff"' in text["battle"]
          and '"lu_sweep": "slash"' not in text["battle"]
          and '"lu_sweep": "spear"' not in text["battle"])
    check("dedicated IronStaffSweepFx exists and is dispatched",
          'class IronStaffSweepFx extends TimedFx:' in text["battle"]
          and 'var fx := IronStaffSweepFx.new()' in text["battle"])
    iron_fx = re.search(r'class IronStaffSweepFx extends TimedFx:(.*?)(?=\nclass |\Z)', text["battle"], re.S)
    iron_fx_text = iron_fx.group(1) if iron_fx else ""
    check("iron-staff effect avoids spearhead, blade and hammer drawing helpers",
          iron_fx is not None
          and "SpearSweepFx" not in iron_fx_text
          and "SlashArcFx" not in iron_fx_text
          and "draw_colored_polygon(PackedVector2Array([tip" not in iron_fx_text)

    staff_sfx_line = next((line for line in text["sfx"].splitlines() if '_bank["atk_staff"]' in line), "")
    check("staff sound is identified as metal, not wood",
          "浑铁禅杖" in staff_sfx_line and "金铁" in staff_sfx_line
          and "木响" not in staff_sfx_line and "木棍" not in staff_sfx_line)

    copy_blob = "\n".join((text["campaign"], text["level6"], text["bios"], text["lore"]))
    check("campaign and narrative copy retain staff terminology",
          all(term in copy_blob for term in ("花和尚禅杖", "禅杖拦棍", "水磨禅杖")))
    check("Lu sweep copy names the iron staff", "抡浑铁禅杖横扫" in text["defs"])

    failures = [str(row["name"]) for row in checks if not row["passed"]]
    report = {
        "passed": not failures,
        "check_count": len(checks),
        "failure_count": len(failures),
        "failures": failures,
        "source_hashes": {str(path.relative_to(ROOT)).replace("\\", "/"): sha256(path)
                          for path in FILES.values()},
        "checks": checks,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[lu-iron-staff-static] RESULT {json.dumps({'passed': not failures, 'checks': len(checks), 'failures': failures}, ensure_ascii=False)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
