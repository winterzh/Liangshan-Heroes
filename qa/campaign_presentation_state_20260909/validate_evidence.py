"""Independently read one Presentation QA batch; never run Godot or write evidence.

An explicit batch is required. Current and frozen inputs must both match the
receipt. PID evidence comes from the runner's Popen records: the behavior JSON
does not independently contain a PID. Passing this audit proves consistency of
the retained component evidence, not full-world recovery or visual acceptance.
"""
import argparse
import ast
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import re
import struct

QA = Path(__file__).resolve().parent
ROOT = QA.parent.parent
SCENE = "campaign_presentation_state_qa.tscn"
PREFIX = "CAMPAIGN_PRESENTATION_STATE_QA "
CONTEXT = {"level_id": "level3", "content_version": "fixture:presentation:v1",
           "mission_token": "mission:presentation:1", "presentation_token": "presentation:real-ui:1"}
ARCHIVED = {
    "scripts/run_campaign_presentation_state.gd", "scripts/run_campaign_mission_state.gd",
    "scripts/run_local_lifecycle.gd", "tools/campaign_presentation_state_qa.gd",
    "tools/run_campaign_presentation_state_qa.py", "tools/run_steam_integration_qa.py",
    "scripts/continue_flow.gd", "assets/localization/continue_flow.json",
    "scripts/campaign_mission.gd", "scripts/localization.gd", "scripts/run_state_value_codec.gd",
    "scripts/unit.gd", "scripts/game_map.gd", "scripts/levels/level3_zhujiazhuang_rts.gd",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key: " + key)
        result[key] = value
    return result


def parse(text):
    def bad_constant(value):
        raise ValueError("Non-finite JSON constant: " + value)
    return json.loads(text, object_pairs_hook=unique_object, parse_constant=bad_constant)


def read(path):
    return parse(path.read_text(encoding="utf-8-sig"))


def relative_name(name):
    require(isinstance(name, str) and name and "\\" not in name and ":" not in name,
            "Invalid relative source path")
    path = PurePosixPath(name)
    require(not path.is_absolute() and ".." not in path.parts and str(path) == name,
            "Unsafe/noncanonical source path: " + name)
    return name


def checked_hash(path, expected, description):
    require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected),
            "Invalid SHA-256: " + description)
    require(path.is_file() and sha(path) == expected, description + ": " + str(path))


def godot_path(value):
    value = value or os.environ.get("GODOT_PATH")
    if not value:
        value = (ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip()
    path = Path(value)
    if path.stem.endswith("_console"):
        path = path.with_name(path.name.replace("_console.exe", ".exe"))
    return path.resolve()


def literal_assignment(source, name):
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise ValueError("Missing frozen runner constant: " + name)


def decode(tagged, depth=0, budget=None):
    """Read the explicit value-codec wire tags, without loading game scripts."""
    if budget is None:
        budget = [0]
    budget[0] += 1
    require(depth <= 32 and budget[0] <= 32768, "Fixture codec limit")
    require(isinstance(tagged, dict) and isinstance(tagged.get("t"), str), "Fixture codec tag")
    tag = tagged["t"]
    require(set(tagged) == ({"t"} if tag == "null" else {"t", "entries" if tag == "dictionary" else "v"}),
            "Fixture codec fields")
    if tag == "null":
        return None
    value = tagged.get("v")
    if tag in ("bool", "string"):
        require(type(value) is (bool if tag == "bool" else str), "Fixture scalar type")
        return value
    if tag == "int64":
        require(isinstance(value, str) and re.fullmatch(r"0|-?[1-9][0-9]*", value), "Fixture integer text")
        number = int(value)
        require(-(2 ** 63) <= number < 2 ** 63, "Fixture integer range")
        return number
    if tag in ("f64", "vector2", "vector2i", "color_f32", "packed_f32"):
        if tag == "vector2i":
            require(isinstance(value, list) and len(value) == 2, "Fixture integer vector")
            result = tuple(decode({"t": "int64", "v": v}, depth + 1, budget) for v in value)
            require(all(-(2 ** 31) <= v < 2 ** 31 for v in result), "Fixture integer vector range")
            return result
        width = 8 if tag in ("color_f32", "packed_f32") else 16
        if tag == "packed_f32":
            require(isinstance(value, str) and len(value) % width == 0, "Fixture packed float")
            values = [value[i:i + width] for i in range(0, len(value), width)]
            budget[0] += len(values)
        else:
            values = [value] if tag == "f64" else value
            require(isinstance(values, list) and len(values) == (4 if tag == "color_f32" else 1 if tag == "f64" else 2),
                    "Fixture float/vector shape")
        numbers = []
        for value in values:
            require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{%d}" % width, value), "Fixture float bits")
            number = struct.unpack("<f" if width == 8 else "<d", bytes.fromhex(value))[0]
            require(math.isfinite(number), "Fixture non-finite float")
            numbers.append(number)
        require(budget[0] <= 32768, "Fixture packed float limit")
        return numbers[0] if tag == "f64" else tuple(numbers)
    if tag == "array":
        require(isinstance(value, list), "Fixture array type")
        return [decode(v, depth + 1, budget) for v in value]
    if tag == "dictionary":
        require(isinstance(tagged["entries"], list), "Fixture dictionary type")
        result = {}
        for pair in tagged["entries"]:
            require(isinstance(pair, list) and len(pair) == 2, "Fixture dictionary entry")
            key = decode(pair[0], depth + 1, budget)
            require(isinstance(key, str) and key not in result, "Fixture dictionary key")
            result[key] = decode(pair[1], depth + 1, budget)
        return result
    raise ValueError("Unsupported fixture codec tag: " + tag)


def verify_fixture(path):
    bundle = read(path)
    require(set(bundle) == {"presentation", "mission", "expected"}, "Fixture bundle fields")
    decoded = {}
    for name, schema in [("presentation", "campaign_presentation_v1"), ("mission", "campaign_mission_component_v1")]:
        record = bundle[name]
        require(record["schema"] == schema and record["context"] == CONTEXT, "Fixture identity: " + name)
        decoded[name] = decode(record["payload"])
    presentation = decoded["presentation"]
    mission = decoded["mission"]
    expected = decode(bundle["expected"])
    require(presentation["locale"] == "zh_CN", "Fixture capture locale")
    require(presentation["scroll"] == mission["scroll"] == {"horizontal": 0, "vertical": 170}, "Fixture scroll pair")
    require(expected["scroll_x"] == 0 and expected["scroll_y"] == 170 and expected["expanded"] is True,
            "Fixture expanded visual state")
    controls = {row["token"]: row for row in presentation["controls"]}
    require(len(controls) == len(presentation["controls"]) and len(controls) >= 15, "Fixture control registry")
    buttons = presentation["buttons"]
    markers = presentation["markers"]
    require(len(buttons) == len(expected["controls"]) >= 6 and len(markers) == len(expected["markers"]) >= 2,
            "Fixture real control/marker graph")
    require(all(row["token"] in controls and controls[row["token"]]["kind"] == "Button" for row in buttons),
            "Fixture button token")
    descriptors = [row["descriptor"] for row in buttons]
    require({"action", "map", "actor", "level"} <= {d["kind"] for d in descriptors}, "Fixture button descriptors")
    require({"zhu_select_shi_qian", "zhu_select_rescued"} <= {d["button_id"] for d in descriptors if d["kind"] == "level"},
            "Fixture real Zhu controls")
    bindings = presentation["bindings"]
    require({"source", "format", "actor_render"} <= {b["descriptor"]["kind"] for b in bindings}, "Fixture localization kinds")
    require(any(b["descriptor"].get("suffix") == " [QA]" for b in bindings), "Fixture localization suffix")
    require(any(not c["visible"] and c["disabled"] for c in expected["controls"]), "Fixture hidden disabled button")
    require(any(m["number"] == 17 and math.isclose(m["render_height"], 11.0) for m in expected["markers"]),
            "Fixture nondefault marker state")
    require(len(expected["scroll_hints"]) == 2, "Fixture native scroll hints")
    return {"controls": len(controls), "buttons": len(buttons), "markers": len(markers), "bindings": len(bindings),
            "context": CONTEXT}


def verify_report(evidence, run, phase, log):
    path = evidence / (phase + "_report.json")
    report = read(path)
    require(report["passed"] is True and report["phase"] == phase, "Failed/wrong report: " + phase)
    for key, expected in [("component_only", True), ("real_steam", False), ("full_world", False),
                          ("real_mission_controls", True), ("real_level3_callbacks", True)]:
        require(report[key] is expected, "Report scope: " + phase + "/" + key)
    checks = report["checks"]
    require(isinstance(checks, list) and len(checks) >= (80 if phase == "component" else 60), "Truncated report: " + phase)
    require(all(isinstance(c, dict) and c.get("passed") is True and isinstance(c.get("label"), str) and c["label"] for c in checks),
            "Failed/malformed check: " + phase)
    labels = {c["label"] for c in checks}
    require(len(labels) == len(checks), "Duplicate check label: " + phase)
    logged = [parse(line[len(PREFIX):]) for line in log.splitlines() if line.startswith(PREFIX + "{")]
    require(len(logged) == 1 and logged[0] == report, "Log/report mismatch: " + phase)
    require(sha(path) == sha(run / path.name), "Run/archive report drift: " + phase)
    prefix = "same process" if phase == "component" else "fresh process"
    required = {prefix + " " + suffix for suffix in [
        "detached trusted prepare", "fresh Mission assigned to new owner", "detached UI and owner remain gated",
        "restore did not deploy or replay", "Localize format survives empty history", "actor renderer owns new Mission",
        "cannot activate before layout", "mounted layout finishes", "mounted layout remains gated",
        "activate only after layout", "real level selects only new Shi Qian", "real level selects new rescued members",
        "rescue callback reads current captivity", "action callback centers restored cell", "actor locator selects new Sun Li",
        "map locator retains closure cell", "dispose removes restored global bindings", "dispose clears owner mission"]}
    for locale in ["en", "zh_TW", "ja", "zh_CN"]:
        for kind in ["format", "source", "actor renderer", "map format"]:
            required.add(prefix + " restored " + kind + " changes language " + locale)
    for state in ["gated", "active"]:
        required.update(prefix + " " + state + " " + field for field in ["scroll_y", "panel_visible", "actual marker count", "native scroll hint textures and flip state"])
    if phase == "component":
        required.update([
            "capture accepts actual ungated production controls", "source layout really has nonzero scroll",
            "barrier saved UI flags produce same presentation record", "Label signal removal restores normal capture",
            "unknown metadata removal restores normal capture", "font color restoration restores normal capture",
            "partial factory really reaches structural-path rejection", "failed prepare removes all provisional bindings",
            "failed prepare removes all provisional language callbacks", "old world still localizes after failed restore",
            "Chinese snapshot prepares under English locale", "cross-language scroll restored after English wrapping",
            "cross-language real level callback selects new actor", "restart bundle file created",
            "restart bundle contains only codec JSON"])
        for kind in ["extra Label signal", "unknown marker metadata", "unsupported Button font color override"]:
            required.add(kind + " capture rejects unsupported behavior")
    else:
        required.update(["fresh process bundle exists", "fresh process bundle is JSON dictionary"])
    require(required <= labels, "Missing required behavior checks: " + phase + ": " + repr(sorted(required - labels)))
    return len(checks)


def validate(batch, engine):
    require(re.fullmatch(r"\d{8}_\d{6}_[0-9a-f]{8}", batch), "Invalid batch name")
    evidence = QA / batch
    receipt = read(evidence / "receipt.json")
    require(receipt.get("complete") is True, "Incomplete/failed batch: " + str(receipt.get("failure", "complete is not true")))
    require(not receipt.get("failure"), "Completed receipt still contains failure")
    for key, expected in [("component_only", True), ("real_steam", False), ("full_world", False),
                          ("fresh_import", True), ("real_mission_controls", True), ("real_level3_callbacks", True)]:
        require(receipt[key] is expected, "Receipt scope: " + key)
    require(re.fullmatch(r"[0-9a-f]{40}", receipt["source_head"]), "Invalid recorded source HEAD")
    checked_hash(godot_path(engine), receipt["godot_sha256"], "Godot binary drift")
    run = Path(receipt["run"])
    profile = Path(receipt["private_profile"])
    require(run.is_absolute() and run.name == batch and run.resolve() != evidence.resolve(), "Run identity")
    require(profile.is_absolute() and profile.name == batch and profile.resolve() != run.resolve(), "Private profile identity")
    require(profile.resolve().is_relative_to(run.parent.resolve()), "Profile outside dedicated work root")
    require(all((profile / d).is_dir() for d in ["appdata", "localappdata", "temp", "tmp"]), "Missing private profile directories")
    frozen = run / "project"
    sources = receipt["source_files"]
    require(isinstance(sources, list) and sources, "Missing source inventory")
    known = {}
    for row in sources:
        name = relative_name(row["path"])
        require(name not in known, "Duplicate source entry: " + name)
        known[name] = row["sha256"]
        checked_hash(ROOT / name, row["sha256"], "Current source drift")
        checked_hash(frozen / name, row["sha256"], "Frozen source drift")
    require(ARCHIVED <= known.keys(), "Missing required production/QA dependency")
    require(receipt["source_guard_checks"] == 2 * len(sources), "Source guard count")
    runner = (frozen / "tools/run_campaign_presentation_state_qa.py").read_text(encoding="utf-8-sig")
    require(set(literal_assignment(runner, "OWN")) <= known.keys(), "Frozen runner dependency omitted")
    scene = literal_assignment(runner, "SCENE")
    # Path.write_text uses platform newlines; read_text normalizes CRLF while
    # checked_hash below still verifies the exact retained bytes.
    require((frozen / SCENE).read_text(encoding="utf-8") == scene, "Generated scene disagrees with frozen runner")
    checked_hash(frozen / SCENE, receipt["generated_scene_sha256"], "Generated scene drift")
    archived = evidence / "source_snapshot"
    files = {p.relative_to(archived).as_posix(): p for p in archived.rglob("*") if p.is_file()}
    require(ARCHIVED | {SCENE} <= files.keys(), "Missing archived input snapshot")
    for name, path in files.items():
        require(name == SCENE or name in known, "Unlisted archived source: " + name)
        checked_hash(path, receipt["generated_scene_sha256"] if name == SCENE else known[name], "Archived source drift")
    steps = receipt["steps"]
    require([s["name"] for s in steps] == ["import", "profile_guard", "component", "restart"], "Missing/reordered execution phase")
    pids, logs = [], {}
    for step in steps:
        name = step["name"]
        path = evidence / (name + ".log")
        checked_hash(path, step["log_sha256"], "Log drift")
        log = path.read_text(encoding="utf-8-sig")
        require("Godot Engine v4.6.3.stable.official" in log, "Missing expected native engine banner: " + name)
        require(not re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|PRESENTATION_CHECK_FAILED )", log), "Native/check errors: " + name)
        require(step["errors"] == 0 and step["stop_reason"] is None, "Stopped/error phase: " + name)
        require(step["exit_code"] == step["expected_exit_code"] == (2 if name == "profile_guard" else 0), "Phase exit code: " + name)
        require(type(step["pid"]) is int and step["pid"] > 0, "Invalid runner PID")
        require(type(step["seconds"]) in (int, float) and math.isfinite(step["seconds"]) and step["seconds"] > 0, "Invalid duration")
        pids.append(step["pid"])
        logs[name] = log
    require(len(set(pids)) == 4, "Runner did not record four distinct processes")
    require(PREFIX + "PRIVATE_PROFILE_REQUIRED" in logs["profile_guard"], "Missing private-profile rejection")
    require(not any(line.startswith(PREFIX + "{") for line in logs["profile_guard"].splitlines()), "Guard unexpectedly ran behavior checks")
    require(not (run / "profile_guard_report.json").exists() and not (evidence / "profile_guard_report.json").exists(), "Guard wrote report")
    counts = {phase: verify_report(evidence, run, phase, logs[phase]) for phase in ["component", "restart"]}
    require(counts == receipt["phase_checks"] and sum(counts.values()) == receipt["checks"], "Receipt/report check totals")
    hooks = [parse(line.split(" ", 1)[1]) for line in logs["component"].splitlines() if line.startswith("PRESENTATION_NATIVE_HOOKS ")]
    require(len(hooks) == 1 and isinstance(hooks[0], list) and hooks[0], "Missing actual native hook diagnostic")
    snapshot = evidence / "presentation_snapshot.json"
    require(sha(snapshot) == sha(run / snapshot.name), "Fixture run/archive drift")
    fixture = verify_fixture(snapshot)
    artifacts = [{"path": p.relative_to(QA).as_posix(), "bytes": p.stat().st_size, "sha256": sha(p)}
                 for p in sorted(evidence.rglob("*")) if p.is_file()]
    return {"passed": True, "batch": batch, "scope": "independent retained evidence readback",
            "engine_rerun": False, "evidence_modified": False, "component_only": True, "full_world": False,
            "real_steam": False, "visual_acceptance": False, "source_head": receipt["source_head"],
            "source_files": len(sources), "current_and_frozen_hash_checks": 2 * len(sources),
            "archived_source_snapshot_checks": len(files), "behavior_checks": sum(counts.values()), "phase_checks": counts,
            "processes": pids, "pid_evidence": "runner Popen only; report and fixture do not independently carry PID",
            "fixture": fixture, "native_hook_rows": len(hooks[0]), "receipt_sha256": sha(evidence / "receipt.json"),
            "validator_sha256": sha(Path(__file__)), "artifacts": artifacts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch", help="Explicit existing batch name; no implicit latest/PASS batch")
    parser.add_argument("--godot", help="Binary to hash only; defaults to GODOT_PATH or godot.local.txt")
    args = parser.parse_args()
    try:
        result = validate(args.batch, args.godot)
    except (ValueError, OSError, KeyError, TypeError, IndexError, SyntaxError) as exc:
        print(json.dumps({"passed": False, "batch": args.batch, "error": str(exc),
                          "engine_rerun": False, "evidence_modified": False}, ensure_ascii=True))
        return 1
    print(json.dumps(result, indent=2, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
