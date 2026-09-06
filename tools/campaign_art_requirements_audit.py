"""Static, repeatable campaign-art requirements and material snapshot audit.

The tool deliberately does not load Godot, import assets, create PNGs, or edit
project material.  It only reads the eight campaign scripts, Defs and manifests,
then writes explicitly requested JSON files outside the project (or verifies a
previous JSON snapshot in --check-snapshot mode).  It is not a visual QA or a
playthrough test.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT = Path(__file__).resolve().parents[1]
DIRECTIONS = ("se", "sw", "ne", "nw")
ACTION_STATES = ("idle", "walk", "attack", "hurt", "down")
LEVELS = (
    ("level6", "野猪林", "scripts/levels/level6_yezhulin.gd"),
    ("level1", "智取生辰纲", "scripts/levels/level1_huangnigang.gd"),
    ("level7", "醉打蒋门神", "scripts/levels/level7_kuaihuolin.gd"),
    ("level2", "江州劫法场", "scripts/levels/level2_jiangzhou.gd"),
    ("level3", "三打祝家庄", "scripts/levels/level3_zhujiazhuang.gd"),
    ("level4", "大破连环马", "scripts/levels/level4_lianhuanma.gd"),
    ("level8", "智取大名府", "scripts/levels/level8_dongchangfu.gd"),
    ("level5", "三败高太尉", "scripts/levels/level5_liangshan.gd"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha(value: Any) -> str:
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(read_text(path))


def rel(project: Path, path: Path) -> str:
    return path.relative_to(project).as_posix()


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def balanced(text: str, start: int, opener: str = "{", closer: str = "}") -> tuple[str, int]:
    """Return the balanced part starting at *start*, while respecting strings."""
    if start < 0 or start >= len(text) or text[start] != opener:
        raise ValueError(f"expected {opener!r} at {start}")
    depth = 0
    quoted = False
    escaped = False
    for index in range(start, len(text)):
        char = text[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
            continue
        if char == '"':
            quoted = True
        elif char == opener:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return text[start:index + 1], index + 1
    raise ValueError(f"unclosed {opener!r} beginning at {start}")


def parse_unit_table(text: str) -> dict[str, dict[str, Any]]:
    """Parse the top-level Defs.UNITS literals without executing GDScript."""
    anchor = text.find("const UNITS")
    if anchor < 0:
        raise ValueError("const UNITS not found")
    opening = text.find("{", anchor)
    body, _ = balanced(text, opening)
    result: dict[str, dict[str, Any]] = {}
    cursor = 1
    key_re = re.compile(r'\s*"([^"]+)"\s*:\s*')
    while cursor < len(body) - 1:
        match = key_re.match(body, cursor)
        if not match:
            cursor += 1
            continue
        key = match.group(1)
        value_start = match.end()
        if value_start >= len(body) or body[value_start] != "{":
            cursor = value_start
            continue
        value, cursor = balanced(body, value_start)
        data: dict[str, Any] = {}
        for name, raw in re.findall(r'"([A-Za-z_]+)"\s*:\s*([^,}\n]+)', value):
            raw = raw.strip()
            if raw in ("true", "false"):
                data[name] = raw == "true"
            elif raw.startswith('"') and raw.endswith('"'):
                data[name] = raw[1:-1]
            else:
                try:
                    data[name] = float(raw) if "." in raw else int(raw)
                except ValueError:
                    data[name] = raw
        result[key] = data
    return result


def parse_local_defs(text: str) -> dict[str, dict[str, Any]]:
    """Capture literal level-local entries such as hook_training_dummy."""
    result: dict[str, dict[str, Any]] = {}
    for match in re.finditer(r'defs\s*\[\s*"([^"]+)"\s*\]\s*=\s*\{', text):
        key = match.group(1)
        value, _ = balanced(text, match.end() - 1)
        data: dict[str, Any] = {}
        for name, raw in re.findall(r'"([A-Za-z_]+)"\s*:\s*([^,}\n]+)', value):
            raw = raw.strip()
            if raw in ("true", "false"):
                data[name] = raw == "true"
            elif raw.startswith('"') and raw.endswith('"'):
                data[name] = raw[1:-1]
            else:
                try:
                    data[name] = float(raw) if "." in raw else int(raw)
                except ValueError:
                    data[name] = raw
        result[key] = data
    return result


def parse_level_vessel_records(text: str) -> dict[str, dict[str, Any]]:
    """Recognize the level-5 literal vessel table populated at runtime.

    Those keys are deliberately derived from ``guan_gong`` inside the level
    rather than duplicated in Defs.UNITS.  This records the declared movement
    contract without pretending that they are global Defs entries.
    """
    result: dict[str, dict[str, Any]] = {}
    marker = "for record in [[\"ruan_xiaoqi_boat\""
    start = text.find(marker)
    if start < 0:
        return result
    end = text.find("]]:", start)
    if end < 0:
        return result
    table = text[start:end]
    for key in re.findall(r'\[\s*"([a-z0-9_]+)"\s*,\s*"[^"]+"\s*,\s*\d', table):
        result[key] = {"name": key, "movement_profile": "water", "runtime_local_definition": True}
    return result


def parse_campaign_art(text: str) -> tuple[set[str], set[str]]:
    variants: set[str] = set()
    aliases: set[str] = set()
    variants_match = re.search(r"const ANIMATED_VARIANTS\s*:=\s*\[", text)
    if variants_match:
        value, _ = balanced(text, variants_match.end() - 1, "[", "]")
        variants.update(re.findall(r'"([^"]+)"', value))
    aliases_match = re.search(r"const OBJECT_ALIASES\s*:=\s*\{", text)
    if aliases_match:
        value, _ = balanced(text, aliases_match.end() - 1)
        aliases.update(re.findall(r'"([^"]+)"\s*:', value))
    return variants, aliases


def classify(key: str, definition: dict[str, Any]) -> str:
    movement = str(definition.get("movement_profile", ""))
    if movement == "water" or key.endswith(("_boat", "_warship", "_flagship")) or key in {
        "official_vanguard", "official_warship", "gao_flagship", "liangshan_boat"
    }:
        return "vessel"
    if definition.get("building"):
        return "object"
    if definition.get("captive"):
        return "captive"
    if definition.get("noncombat"):
        return "noncombat"
    return "combatant"


def required_states(key: str, definition: dict[str, Any], object_states: set[str]) -> tuple[list[str], str]:
    kind = classify(key, definition)
    if kind == "vessel":
        ordered = [state for state in ("default", "damaged", "flooding", "disabled") if state in object_states]
        return (ordered or ["default"], "object-state")
    if kind == "object":
        return (sorted(object_states) or ["default"], "object-state")
    if kind in {"captive", "noncombat"}:
        states = ["idle"]
        if float(definition.get("speed", 0) or 0) > 0:
            states.append("walk")
        return (states, "story-or-civilian")
    return (list(ACTION_STATES), "mobile-combat")


def parse_spawns(text: str, source: str) -> tuple[dict[str, list[dict[str, Any]]], list[dict[str, Any]]]:
    literal: dict[str, list[dict[str, Any]]] = defaultdict(list)
    dynamic: list[dict[str, Any]] = []
    call_re = re.compile(r"\bspawn_(at|group|unit)\s*\(")
    for call in call_re.finditer(text):
        start = call.end()
        rest = text[start:start + 260]
        literal_match = re.match(r'\s*"([^"]+)"', rest)
        array_match = re.match(r'\s*\[\s*((?:"[^"]+"\s*,?\s*)+)\]\s*\[', rest)
        location = {"file": source, "line": line_of(text, call.start()), "call": call.group(1)}
        if literal_match:
            literal[literal_match.group(1)].append(location)
        elif array_match:
            for key in re.findall(r'"([^"]+)"', array_match.group(1)):
                literal[key].append({**location, "expression": "inline literal array"})
        else:
            preview = rest.split("\n", 1)[0].strip()[:120]
            dynamic.append({**location, "first_argument": preview})
    return literal, dynamic


def parse_story(text: str, source: str, variants: set[str], aliases: set[str]) -> dict[str, Any]:
    seen_variants: dict[str, list[int]] = defaultdict(list)
    seen_aliases: dict[str, list[int]] = defaultdict(list)
    for key in variants:
        for found in re.finditer(rf'(?<![A-Za-z0-9_])"{re.escape(key)}"', text):
            seen_variants[key].append(line_of(text, found.start()))
    for key in aliases:
        for found in re.finditer(rf'(?<![A-Za-z0-9_])"{re.escape(key)}"', text):
            seen_aliases[key].append(line_of(text, found.start()))
    outcomes = [(m.group(1), line_of(text, m.start())) for m in re.finditer(r'defeat_outcome\s*=\s*"([^"]+)"', text)]
    poses = [(m.group(1), line_of(text, m.start())) for m in re.finditer(r'play_story_pose\s*\(\s*"([^"]+)"', text)]
    poses += [(m.group(1), line_of(text, m.start())) for m in re.finditer(r'story_pose"\s*,\s*"([^"]+)"', text)]
    object_states = [(m.group(1), m.group(2), line_of(text, m.start())) for m in re.finditer(
        r'set_story_object_state\s*\(\s*"([^"]+)"\s*,\s*"([^"]+)"', text)]
    return {
        "variants": [{"variant": key, "file": source, "lines": lines} for key, lines in sorted(seen_variants.items())],
        "object_aliases": [{"object": key, "file": source, "lines": lines} for key, lines in sorted(seen_aliases.items())],
        "defeat_outcomes": [{"outcome": value, "file": source, "line": line} for value, line in outcomes],
        "story_poses": [{"pose": value, "file": source, "line": line} for value, line in poses],
        "object_state_events": [{"object": key, "state": state, "file": source, "line": line} for key, state, line in object_states],
    }


def directions_from_filename(path: Path) -> tuple[str, str, str] | None:
    name = path.stem
    for state in ("carry_walk", "carry_idle", "intercept", "assisted", "restored", "windup", "rush_windup", *ACTION_STATES):
        for direction in DIRECTIONS:
            suffix = f"_{state}_{direction}"
            if name.endswith(suffix):
                return (name[: -len(suffix)], state, direction)
    for direction in DIRECTIONS:
        suffix = f"_{direction}"
        if name.endswith(suffix):
            return (name[: -len(suffix)], "default", direction)
    return None


def asset_inventory(project: Path) -> dict[str, Any]:
    campaign = project / "assets/campaign"
    dir4 = project / "assets/direction4"
    buckets = {
        "campaign_anim": campaign / "anim",
        "campaign_objects": campaign / "objects",
        "campaign_portraits": campaign / "portraits",
        "generic_anim": project / "assets/anim",
    }
    files = {name: sorted(folder.glob("*.png")) for name, folder in buckets.items()}
    state_map: dict[str, set[str]] = defaultdict(set)
    for name in ("campaign_anim", "generic_anim"):
        for path in files[name]:
            parsed = directions_from_filename(path)
            if parsed:
                key, state, direction = parsed
                state_map[f"{key}|{state}"].add(direction)
    object_state_map: dict[str, set[str]] = defaultdict(set)
    for path in files["campaign_objects"]:
        parsed = directions_from_filename(path)
        if parsed:
            key, state, direction = parsed
            object_state_map[f"{key}|{state}"].add(direction)
        else:
            object_state_map[f"{path.stem}|default"].add("static")

    direction_manifest = load_json(dir4 / "manifest.json")
    object_manifest = load_json(dir4 / "campaign_object_manifest.json")
    web_manifest = load_json(campaign / "web_art_manifest.json")
    manifests = {
        "direction4": (direction_manifest, project, "outputs"),
        "campaign_objects": (object_manifest, project, "outputs"),
        "web": (web_manifest, campaign, "artifacts"),
    }
    manifest_results: dict[str, Any] = {}
    for name, (manifest, base, output_key) in manifests.items():
        missing: list[str] = []
        hash_mismatch: list[str] = []
        outputs = manifest.get(output_key, [])
        for row in outputs:
            output = row.get("output") if isinstance(row, dict) else None
            if not output:
                continue
            target = base / output
            if not target.is_file():
                missing.append(output)
            elif row.get("sha256") and sha256(target).lower() != str(row["sha256"]).lower():
                hash_mismatch.append(output)
        source_bad: list[str] = []
        for source in manifest.get("sources", {}).values():
            if not isinstance(source, dict) or not source.get("file"):
                continue
            target = base / source["file"]
            expected = source.get("sha256")
            if not target.is_file() or (expected and sha256(target).lower() != str(expected).lower()):
                source_bad.append(source["file"])
        manifest_results[name] = {
            "declared_outputs": len(outputs),
            "missing_output_files": missing,
            "output_hash_mismatch": hash_mismatch,
            "source_hash_failures": source_bad,
        }
    web_artifacts = web_manifest.get("artifacts", [])
    return {
        "physical_png_counts": {name: len(items) for name, items in files.items()},
        "recognized_directional_animation_states": {key: sorted(value) for key, value in sorted(state_map.items())},
        "recognized_directional_object_states": {key: sorted(value) for key, value in sorted(object_state_map.items())},
        "manifest_results": manifest_results,
        "manifest_counts": {
            "direction4_outputs": len(direction_manifest.get("outputs", [])),
            "direction4_sources": len(direction_manifest.get("sources", {})),
            "campaign_object_outputs": len(object_manifest.get("outputs", [])),
            "campaign_object_sources": len(object_manifest.get("sources", {})),
            "web_artifacts": len(web_artifacts),
            "web_artifacts_by_kind": dict(sorted(Counter(str(row.get("kind", "unknown")) for row in web_artifacts).items())),
            "web_artifacts_by_state": dict(sorted(Counter(str(row.get("state", "unknown")) for row in web_artifacts).items())),
        },
    }


def snapshot_files(project: Path) -> list[Path]:
    allowed_suffixes = {".gd", ".tscn", ".tres", ".png", ".json", ".txt", ".md", ".cfg", ".import"}
    roots = [project / "scripts", project / "scenes", project / "assets", project / "docs"]
    included = [project / "project.godot", project / "export_presets.cfg", project / "tools/campaign_art_requirements_audit.py"]
    excluded_parts = {".godot", "qa", "build", "export", "exports", "history", ".git", "staging"}
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in allowed_suffixes:
                continue
            parts = set(path.relative_to(project).parts)
            if parts & excluded_parts:
                continue
            included.append(path)
    return sorted(set(included), key=lambda item: rel(project, item))


def write_snapshot(project: Path, out: Path, label: str) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    unstable: list[str] = []
    for path in snapshot_files(project):
        before = path.stat()
        digest = sha256(path)
        after = path.stat()
        row = {
            "path": rel(project, path),
            "bytes": before.st_size,
            "mtime_ns": before.st_mtime_ns,
            "sha256": digest,
        }
        rows.append(row)
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            unstable.append(row["path"])
    payload = {
        "schema_version": 1,
        "label": label,
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Source and current material file-list hash snapshot; no file copies. Excludes cache, export, build, QA outputs and historical backup trees.",
        "excluded_path_parts": [".godot", "qa", "build", "export", "exports", "history", ".git", "staging"],
        "files": rows,
        "file_count": len(rows),
        "content_index_sha256": canonical_sha(rows),
        "unstable_paths_during_hash": unstable,
        "status": "stable_observation" if not unstable else "concurrent_mutation_detected",
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def check_snapshot(project: Path, path: Path) -> dict[str, Any]:
    snapshot = load_json(path)
    expected = {row["path"]: row["sha256"] for row in snapshot.get("files", [])}
    actual_paths = {rel(project, candidate): candidate for candidate in snapshot_files(project)}
    missing = sorted(set(expected) - set(actual_paths))
    added = sorted(set(actual_paths) - set(expected))
    changed = sorted(key for key in set(expected) & set(actual_paths) if sha256(actual_paths[key]) != expected[key])
    return {
        "snapshot": str(path),
        "expected_file_count": len(expected),
        "current_file_count": len(actual_paths),
        "missing": missing,
        "added": added,
        "changed": changed,
        "passed": not missing and not added and not changed,
    }


def requirements(project: Path) -> dict[str, Any]:
    defs = parse_unit_table(read_text(project / "scripts/defs.gd"))
    variants, aliases = parse_campaign_art(read_text(project / "scripts/campaign_art.gd"))
    inventory = asset_inventory(project)
    object_events_by_level: dict[str, dict[str, set[str]]] = {}
    level_rows: list[dict[str, Any]] = []
    undefined_literals: list[dict[str, Any]] = []
    for level_id, title, source in LEVELS:
        text = read_text(project / source)
        level_defs = {**defs, **parse_local_defs(text), **parse_level_vessel_records(text)}
        literal_spawns, dynamic_spawns = parse_spawns(text, source)
        story = parse_story(text, source, variants, aliases)
        object_events: dict[str, set[str]] = defaultdict(set)
        for row in story["object_state_events"]:
            object_events[row["object"]].add(row["state"])
        object_events_by_level[level_id] = object_events
        units: list[dict[str, Any]] = []
        for key in sorted(literal_spawns):
            definition = level_defs.get(key)
            if definition is None:
                undefined_literals.append({"level": level_id, "key": key, "sites": literal_spawns[key]})
                definition = {}
            observed_states = object_events.get(key, set())
            states, category = required_states(key, definition, observed_states)
            asset_key = key
            direction_coverage = {state: inventory["recognized_directional_animation_states"].get(f"{asset_key}|{state}", []) for state in states}
            if category == "object-state":
                direction_coverage = {state: inventory["recognized_directional_object_states"].get(f"{asset_key}|{state}", []) for state in states}
            missing_directional = [state for state, dirs in direction_coverage.items() if category != "object-state" and set(dirs) != set(DIRECTIONS)]
            units.append({
                "key": key,
                "name": definition.get("name", "<unregistered>"),
                "category": category,
                "definition_flags": {name: definition.get(name) for name in ("building", "noncombat", "captive", "hero", "cavalry", "ranged", "movement_profile") if name in definition},
                "required_states": states,
                "directional_state_coverage": direction_coverage,
                "missing_exact_four_direction_actions": missing_directional,
                "spawn_sites": literal_spawns[key],
            })
        level_rows.append({
            "id": level_id,
            "title": title,
            "script": source,
            "unit_requirements": units,
            "dynamic_spawn_sites_requiring_manual_review": dynamic_spawns,
            "story_requirements": story,
        })

    setup = read_text(project.parent / "SOURCE_SETUP.md") if (project.parent / "SOURCE_SETUP.md").is_file() else ""
    worklog = read_text(project.parent / "WORKLOG.md") if (project.parent / "WORKLOG.md").is_file() else ""
    count = inventory["manifest_counts"]
    physical = inventory["physical_png_counts"]
    doc_drift = [
        {
            "topic": "四向通用 manifest",
            "current": f"assets/direction4/manifest.json outputs={count['direction4_outputs']}",
            "historical_text": "SOURCE_SETUP.md / WORKLOG.md retain the earlier 80-output statement.",
            "evidence": {"source_setup_mentions_80": "80" in setup, "worklog_mentions_80": "80" in worklog},
            "interpretation": "Current 96 is 16 higher. The older figure is a historical batch count and must not be silently overwritten as if it described the present directory.",
        },
        {
            "topic": "网页战役美术清单与物理目录",
            "current": {"web_artifacts": count["web_artifacts"], "physical": physical},
            "historical_text": "web_art_manifest tracks the accepted web batch only; it is not a total inventory of every campaign or generic asset.",
            "interpretation": "Different scopes, therefore do not treat this as a manifest corruption solely because the physical directory has more files.",
        },
        {
            "topic": "旧 motion contract 库存",
            "current": {"physical_campaign_anim": physical["campaign_anim"], "physical_campaign_objects": physical["campaign_objects"], "physical_campaign_portraits": physical["campaign_portraits"]},
            "historical_text": "motion_contract_qa.json documents the previous 188 strips / 312 frames / 22 objects / 20 variants checkpoint.",
            "interpretation": "It is preserved historical evidence, not a current-total manifest. Future reports must say which scope/count they use.",
        },
        {
            "topic": "战役物件四向 manifest",
            "current": {"declared_outputs": count["campaign_object_outputs"], "physical_campaign_objects": physical["campaign_objects"]},
            "historical_text": "campaign_object_manifest is a declared four-direction object batch, not necessarily every pre-existing campaign object.",
            "interpretation": "The difference needs an explicit scope label, not automatic deletion or re-counting of legacy objects.",
        },
    ]
    checks = [
        {"name": "story_order_has_eight_registered_levels", "passed": len(LEVELS) == 8},
        {"name": "all_level_scripts_exist", "passed": all((project / source).is_file() for _, _, source in LEVELS)},
        {"name": "literal_spawn_keys_resolve_to_defs_or_level_local_defs", "passed": not undefined_literals, "details": undefined_literals},
        {"name": "direction4_manifest_outputs_exist_and_match_hashes", "passed": not inventory["manifest_results"]["direction4"]["missing_output_files"] and not inventory["manifest_results"]["direction4"]["output_hash_mismatch"], "details": inventory["manifest_results"]["direction4"]},
        {"name": "campaign_object_manifest_outputs_exist_and_match_hashes", "passed": not inventory["manifest_results"]["campaign_objects"]["missing_output_files"] and not inventory["manifest_results"]["campaign_objects"]["output_hash_mismatch"], "details": inventory["manifest_results"]["campaign_objects"]},
        {"name": "web_manifest_declared_outputs_exist_and_sources_match_hashes", "passed": not inventory["manifest_results"]["web"]["missing_output_files"] and not inventory["manifest_results"]["web"]["source_hash_failures"], "details": inventory["manifest_results"]["web"]},
    ]
    return {
        "schema_version": 1,
        "scope": "Static source/art requirement inventory for the eight campaign levels. It does not execute Godot, certify animation quality, certify visual composition, or replace human playtesting.",
        "story_order": [level_id for level_id, _, _ in LEVELS],
        "levels": level_rows,
        "inventory": inventory,
        "documentation_count_reconciliation": doc_drift,
        "contract_checks": checks,
        "contract_passed": all(row["passed"] for row in checks),
        "limitations": [
            "Dynamic spawn expressions are enumerated for manual review; only literal and inline-array keys are mechanically resolved.",
            "Exact PNG state coverage is a production-backlog signal. A missing exact action can still have runtime fallback and is not a gameplay failure assertion.",
            "No pixel, texture import, renderer, Steam directory, export, upload, performance run, screenshot review or human playtest is performed by this tool.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=PROJECT)
    parser.add_argument("--out", type=Path, help="Write static requirement report JSON here.")
    parser.add_argument("--snapshot", type=Path, help="Write source/material SHA-256 snapshot JSON here.")
    parser.add_argument("--label", default="manual_snapshot")
    parser.add_argument("--check-snapshot", type=Path, help="Read-only compare current tracked inputs to an existing snapshot.")
    args = parser.parse_args()
    project = args.project_root.resolve()
    if args.check_snapshot:
        result = check_snapshot(project, args.check_snapshot)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["passed"] else 1
    if not args.out:
        parser.error("--out is required unless --check-snapshot is used")
    report = requirements(project)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    snapshot = write_snapshot(project, args.snapshot, args.label) if args.snapshot else None
    summary = {
        "contract_passed": report["contract_passed"],
        "checks": len(report["contract_checks"]),
        "levels": len(report["levels"]),
        "snapshot_status": snapshot["status"] if snapshot else "not_requested",
        "snapshot_files": snapshot["file_count"] if snapshot else 0,
        "report": str(args.out),
        "snapshot": str(args.snapshot) if args.snapshot else None,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if report["contract_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
