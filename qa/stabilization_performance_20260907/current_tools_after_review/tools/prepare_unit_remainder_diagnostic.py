"""Prepare reversible diagnostic wrappers from a completed frozen M1 project.

Writes only a new private project below .godot/stabilization_performance. It does
not run Godot, mutate production files, reset gameplay state, or modify a prior run.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

sys.dont_write_bytecode = True
import run_stabilization_performance as guard
ROOT = Path(__file__).resolve().parents[1]
METHODS = {
    "scripts/unit.gd": ["_phys_body", "_do_chase", "_follow_path", "_acquire", "_begin_move",
                        "_begin_amove", "_try_attack_path_blocker", "_face_dir", "current_move_speed", "_attack"],
    "scripts/battle.gd": ["can_unit_step", "eject_from_buildings", "target_visible_to", "enemy_candidates_near"],
    "scripts/game_map.gd": ["_segment_open", "speed_mult_at"],
}


def need(ok, message):
    if not ok: raise RuntimeError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def transform(raw, path):
    text = raw.decode("utf-8-sig")
    original = text
    replacements = []
    scopes = []
    short = Path(path).stem
    for name in METHODS[path]:
        pattern = re.compile(r"^func " + re.escape(name) + r"\(([^\r\n]*)\)(?: -> ([^:\r\n]+))?:[^\r\n]*(?:\r?\n)", re.M)
        matches = list(pattern.finditer(text))
        need(len(matches) == 1, "Expected one original method: " + path + ":" + name)
        found = matches[0]
        declaration = found.group(0)
        arguments = [part.strip().split(":", 1)[0].split("=", 1)[0].strip() for part in found.group(1).split(",") if part.strip()]
        need(all(re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", arg) for arg in arguments), "Complex argument list requires explicit mapping")
        result_type = (found.group(2) or "").strip()
        need(result_type in ("void", "bool", "float", "Array"), "Unsupported synchronous result type: " + declaration)
        end = text.find("\nfunc ", found.end())
        body = text[found.end():end if end >= 0 else len(text)]
        need(not re.search(r"\bawait\b", body), "Async wrapper refused: " + name)
        scope = short + "." + name
        scopes.append(scope)
        renamed = declaration.replace("func " + name + "(", "func __unitdiag_original_" + name + "(", 1)
        call = "__unitdiag_original_" + name + "(" + ", ".join(arguments) + ")"
        wrapper = declaration + '\tvar __unitdiag_observer = Engine.get_meta("liangshan_unit_remainder_observer")\n'
        wrapper += '\tvar __unitdiag_token: int = __unitdiag_observer.enter("' + scope + '")\n'
        if result_type == "void":
            wrapper += "\t" + call + "\n\t__unitdiag_observer.leave(__unitdiag_token)\n\n"
        else:
            wrapper += "\tvar __unitdiag_result: " + result_type + " = " + call + "\n\t__unitdiag_observer.leave(__unitdiag_token)\n\treturn __unitdiag_result\n\n"
        replacement = wrapper + renamed
        text = text[:found.start()] + replacement + text[found.end():]
        replacements.append({"method": name, "old": declaration, "new": replacement})
    reverse = text
    for replacement in reversed(replacements):
        need(reverse.count(replacement["new"]) == 1, "Reverse transformation is ambiguous")
        reverse = reverse.replace(replacement["new"], replacement["old"], 1)
    need(reverse == original, "Original method bytes were not reversibly preserved")
    # The production sources have no UTF-8 BOM; reject instead of silently losing one.
    need(original.encode("utf-8") == raw, "Source encoding normalization requires review")
    return text.encode("utf-8"), replacements, scopes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-run", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    guard.no_links(args.baseline_run)
    guard.no_links(args.output)
    baseline = args.baseline_run.resolve()
    output = args.output.resolve()
    allowed = (ROOT / ".godot/stabilization_performance").resolve()
    need(allowed in baseline.parents and allowed in output.parents and not output.exists(), "Output must be a new private run")
    receipt_bytes = (baseline / "receipt.json").read_bytes()
    receipt = json.loads(receipt_bytes.decode("utf-8"))
    need(receipt.get("complete") and receipt.get("baseline_eligible") and receipt.get("player_unchanged") and receipt.get("lock_released"), "A completed valid baseline and all guards are required")
    production = {row["path"]: row for row in receipt["source_files"]}
    committed = {row["path"]: row["git_oid"] for row in guard.tree(receipt["source_head"])}
    need({name: row["git_oid"] for name, row in production.items()} == committed, "Baseline production manifest does not match the named Git tree")
    original_sources = {row["path"]: row["sha256"] for row in receipt["source_files"] + receipt["tools"]}
    original_sources[".polish_frozen_source.json"] = sha((baseline / "project/.polish_frozen_source.json").read_bytes())
    # Hash every copied source, including untouched dependencies. A three-file
    # match cannot establish the identity of a complete runtime project.
    for name, expected in original_sources.items():
        path = baseline / "project" / name
        guard.no_links(path)
        raw = path.read_bytes()
        need(sha(raw) == expected, "Baseline input drift: " + name)
        if name in committed:
            oid = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
            need(oid == committed[name], "Committed blob mismatch: " + name)
    prepared = {}
    all_scopes = []
    for path in METHODS:
        raw = (baseline / "project" / path).read_bytes()
        need(sha(raw) == production[path]["sha256"], "Baseline production source changed: " + path)
        changed, replacements, scopes = transform(raw, path)
        prepared[path] = {"before": raw, "after": changed, "replacements": replacements}
        all_scopes.extend(scopes)
    project_bytes = (baseline / "project/project.godot").read_bytes()
    project_text = project_bytes.decode("utf-8")
    autoload_marker = "[autoload]"
    need(project_text.count(autoload_marker) == 1 and "UnitRemainderObserver=" not in project_text, "Autoload mapping changed")
    project_after = project_text.replace(autoload_marker, autoload_marker + '\n\nUnitRemainderObserver="*res://tools/unit_remainder_observer.gd"', 1).encode("utf-8")
    probe_before = (baseline / "project/tools/polish_performance_probe.gd").read_bytes()
    probe_after = probe_before.decode("utf-8")
    substitutions = [
        ("var started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick", "var __unit_remainder_observer = root.get_node(\"UnitRemainderObserver\")\n\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick\n\t__unit_remainder_observer.begin_sample(started, start_tick)"),
        ("var now := Time.get_ticks_usec()\n", "var now := Time.get_ticks_usec()\n\t\t__unit_remainder_observer.present(now, physics_tick)\n"),
        ("var end_state := _state(b)", "__unit_remainder_observer.end_sample(previous, physics_tick)\n\tvar end_state := _state(b)"),
    ]
    # Keep exact original line ending so the derivative can be reversed byte for byte.
    for before, after in substitutions:
        if probe_after.count(before) != 1:
            before = before.replace("\n", "\r\n"); after = after.replace("\n", "\r\n")
        need(probe_after.count(before) == 1, "Probe sample marker changed")
        probe_after = probe_after.replace(before, after, 1)
    output.mkdir(parents=True)
    project = output / "project"
    project.mkdir()
    for name, expected in original_sources.items():
        raw = (baseline / "project" / name).read_bytes()
        need(sha(raw) == expected, "Baseline input changed while copying: " + name)
        dest = project / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
    cache = baseline / "project/.godot/imported"
    if cache.is_dir():
        for path in cache.rglob("*"): guard.no_links(path)
        shutil.copytree(cache, project / ".godot/imported")
    manifest = {"schema": 1, "baseline_run": str(baseline), "source_head": receipt["source_head"],
                "baseline_receipt_sha256": sha(receipt_bytes), "original_source_sha256": original_sources,
                "committed_blob_oids": committed,
                "scope": "Unit remaining synchronous hotspots; no fallback/fastpath/preload optimization", "changes": []}
    for path, item in prepared.items():
        (project / path).write_bytes(item["after"])
        manifest["changes"].append({"path": path, "before_sha256": sha(item["before"]), "after_sha256": sha(item["after"]), "reversible": True, "replacements": item["replacements"]})
    for path, before, after in [("project.godot", project_bytes, project_after), ("tools/polish_performance_probe.gd", probe_before, probe_after.encode("utf-8"))]:
        (project / path).write_bytes(after)
        manifest["changes"].append({"path": path, "before_sha256": sha(before), "after_sha256": sha(after)})
    observer = (ROOT / "tools/unit_remainder_observer.gd").read_bytes()
    (project / "tools/unit_remainder_observer.gd").write_bytes(observer)
    scope_bytes = json.dumps(all_scopes).encode("utf-8")
    (project / "tools/unit_remainder_scopes.json").write_bytes(scope_bytes)
    manifest["observer_sha256"] = sha(observer)
    manifest["scopes_sha256"] = sha(scope_bytes)
    manifest["scopes"] = all_scopes
    (output / "preparation.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"prepared": True, "path": str(output), "scope_count": len(all_scopes)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
