"""Reproducible static/fault checks. No real process, engine, or project writes.

Temporary filesystem fixtures live below this directory and are removed at exit.
The result is a NEW run in receipts.json, never a copy of earlier console output.
"""
import ast
import copy
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from unittest.mock import patch

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNNER = ROOT / "tools/run_reduced_effects_qa.py"
INPUTS = ["tools/run_reduced_effects_qa.py", "tools/reduced_effects_qa.gd",
          "tools/reduced_effects_ui_qa.gd", "tools/contracts/reduced_effects/manifest.json",
          "tools/contracts/reduced_effects/settings_legacy.gd.txt",
          "scripts/battle.gd", "scripts/unit.gd",
          "scratchpad/reduced_effects_v2/frozen/battle.gd.bin",
          "scratchpad/reduced_effects_v2/frozen/unit.gd.bin",
          "scratchpad/reduced_effects_v2/generated/driver.gd",
          "scratchpad/reduced_effects_ui/ui_driver.gd.in"]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def must(ok, message):
    if not ok:
        raise AssertionError(message)


def signatures():
    return {name: sha((ROOT / name).read_bytes()) for name in INPUTS}


def method(text, name, owner=None):
    begin = 0
    if owner:
        owner_match = re.search(r"(?m)^class " + re.escape(owner) + r"\b", text)
        must(owner_match is not None, "Missing class " + owner)
        begin = owner_match.end()
    indent = "\t" if owner else ""
    match = re.search(r"(?m)^" + indent + r"func " + re.escape(name) + r"\(", text[begin:])
    must(match is not None, "Missing method " + name)
    start = begin + match.start()
    next_match = re.search(r"(?m)^(?:" + indent + r"func |class |func )", text[begin + match.end():])
    end = begin + match.end() + next_match.start() if next_match else len(text)
    return text[start:end].strip()


def callback_code(text):
    # Only full-line comments/blank lines are ignored; code/string bytes remain.
    return "\n".join(line for line in text.splitlines() if line.strip() and not line.lstrip().startswith("#"))


def audit_production():
    paths = {name: ROOT / "scripts" / (name + ".gd") for name in ("battle", "unit")}
    originals = {name: ROOT / "scratchpad/reduced_effects_v2/frozen" / (name + ".gd.bin") for name in paths}
    must(sha(originals["battle"].read_bytes()) == "9fe157e49ef18f2ced0b10ee96f893a1f0ded4ce64e6d757e936d4ef4e9e1ee4", "Unexpected Battle preimage")
    must(sha(originals["unit"].read_bytes()) == "c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856", "Unexpected Unit preimage")
    base = {name: path.read_text(encoding="utf-8-sig") for name, path in originals.items()}
    current = {name: path.read_text(encoding="utf-8-sig") for name, path in paths.items()}
    recovered = current["battle"]
    changes = [
        ('\t\tif Settings.get("effects_quality") == "reduced":\n\t\t\treturn\n\t\tvar vpn := get_viewport()', '\t\tvar vpn := get_viewport()', 1),
        ('\t\tvar reduced_fx: bool = Settings.get("effects_quality") == "reduced"\n', '', 1),
        ('\t\t\tif reduced_fx and i % 2 == 1:\n\t\t\t\tcontinue\n', '', 1),
        ('\t\tif Settings.get("effects_quality") != "reduced":\n\t\t\tfor em in _embers:\n\t\t\t\tvar k := fposmod(elapsed * float(em["spd"]) * 0.02 + float(em["ph"]), 1.0)\n\t\t\t\tvar epos: Vector2 = em["p"] + Vector2(float(em["drift"]) * k, -float(em["spd"]) * k)\n\t\t\t\tdraw_circle(epos, 2.2 * (1.0 - k), Color(1.0, 0.7 + 0.2 * (1.0 - k), 0.2, 0.8 * env * (1.0 - k)))',
         '\t\tfor em in _embers:\n\t\t\tvar k := fposmod(elapsed * float(em["spd"]) * 0.02 + float(em["ph"]), 1.0)\n\t\t\tvar epos: Vector2 = em["p"] + Vector2(float(em["drift"]) * k, -float(em["spd"]) * k)\n\t\t\tdraw_circle(epos, 2.2 * (1.0 - k), Color(1.0, 0.7 + 0.2 * (1.0 - k), 0.2, 0.8 * env * (1.0 - k)))', 1),
        ('for j in range(0 if Settings.get("effects_quality") == "reduced" else 3):', 'for j in range(3):', 1),
        ('\t\t\tvar target_value: Variant = hit.get("target")\n\t\t\tif not is_instance_valid(target_value):\n\t\t\t\tcontinue\n\t\t\tvar target: Unit = target_value', '\t\t\tvar target: Unit = hit.get("target")', 2),
    ]
    for new, old, expected in changes:
        must(recovered.count(new) == expected, "Exact accepted Battle diff seam changed")
        recovered = recovered.replace(new, old)
    must(recovered == base["battle"], "Battle has changes beyond four draw reductions and the two validity guards")
    dust = '\tif Settings.get("effects_quality") != "reduced":\n\t\tfor d in _dust:\n\t\t\tvar da: float = d.t / DUST_DUR\n\t\t\tdraw_circle(Vector2(d.x, d.y), 2.5 + 5.0 * (1.0 - da), Color(0.62, 0.56, 0.45, da * 0.4))'
    old_dust = '\tfor d in _dust:\n\t\tvar da: float = d.t / DUST_DUR\n\t\tdraw_circle(Vector2(d.x, d.y), 2.5 + 5.0 * (1.0 - da), Color(0.62, 0.56, 0.45, da * 0.4))'
    must(current["unit"].count(dust) == 1 and current["unit"].replace(dust, old_dust) == base["unit"], "Unit has changes beyond dust drawing")
    unchanged = {}
    for file, names in {"battle": ["_physics_process", "_separation_pass", "spawn_li_brawn_axes", "_spawn_ground_fire_quiet", "_ground_dot_pass"],
                        "unit": ["_physics_process", "_phys_body", "take_damage", "absorb_physical_damage", "_spawn_dust", "_queue_animated_redraw", "_queue_motion_redraw"]}.items():
        for name in names:
            old, new = method(base[file], name), method(current[file], name)
            must(old == new, file + "." + name + " changed")
            unchanged[file + "." + name] = sha(new.encode())
    old_process = method(base["battle"], "_process", "LiBrawnAxesFx")
    new_process = method(current["battle"], "_process", "LiBrawnAxesFx")
    must(old_process == new_process, "Axe timing/resolve scheduling changed")
    unchanged["LiBrawnAxesFx._process"] = sha(new_process.encode())
    return {"exact_reverse_diff_recovers_both_preimages": True, "visual_categories": 5,
            "validity_guard_sites": 2, "unchanged_callback_lf_sha256": unchanged,
            "scope": "source identity/invariance, not a new engine execution"}


def audit_qa_migration():
    pairs = [
        ("scratchpad/reduced_effects_v2/generated/driver.gd", "tools/reduced_effects_qa.gd",
         ["_settings_cases", "_battle_fixture", "_unit_fixture", "_unit_state", "_sentinels", "_fixed_callbacks", "_axes_edges", "_freed_target_boundary", "_render_cases", "_visual_state", "_settings_missing_corrupt_cases", "_in_tree_lifecycle_cases", "_viewport_fixture", "_capture_frozen", "_pixel_equal", "_core_mask_agrees", "_disk_agrees", "_critical_feedback_cases", "_critical_fire_case", "_critical_axes_case"]),
        ("scratchpad/reduced_effects_ui/ui_driver.gd.in", "tools/reduced_effects_ui_qa.gd",
         ["_click", "_escape", "_quality", "_open_menu_settings", "_menu_flow", "_battle_state", "_battle_flow"]),
    ]
    same = {}
    for old_path, new_path, names in pairs:
        old, new = [(ROOT / name).read_text(encoding="utf-8-sig") for name in (old_path, new_path)]
        for name in names:
            a, b = [callback_code(method(text, name)) for text in (old, new)]
            must(a == b, "Migrated callback changed: " + name)
            same[new_path + "::" + name] = sha(b.encode())
    return {"callbacks": same, "full_line_comments_only_ignored": True,
            "not_claimed_identical": ["manifest/path/entry setup", "report metadata", "GUI layer observations"]}


def main():
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    before = signatures()
    raw = RUNNER.read_bytes()
    ast.parse(raw)
    ns = {"__name__": "public_runner_static_fixture", "__file__": str(RUNNER)}
    exec(compile(raw.decode("utf-8-sig"), str(RUNNER), "exec"), ns)
    rows = []
    def case(label, category, operation, rejection=None):
        row = {"name": label, "category": category, "expected": "reject" if rejection else "accept"}
        try:
            details = operation()
            row["passed"] = rejection is None
            if details is not None:
                row["details"] = details
            if rejection:
                row["failure"] = "Operation unexpectedly accepted"
        except BaseException as exc:
            row["passed"] = rejection is not None and isinstance(exc, rejection)
            row["observed_exception"] = type(exc).__name__ + ": " + str(exc)
        rows.append(row)
    fixture_root = None
    with tempfile.TemporaryDirectory(prefix="fixtures_", dir=HERE) as tmp:
        fixture_root = Path(tmp).resolve()
        must(fixture_root.parent == HERE.resolve(), "Temporary fixture root escaped requested directory")
        index = 0
        def fixture():
            nonlocal index
            index += 1
            root = fixture_root / str(index)
            root.mkdir()
            for name in ns["REQUIRED"]:
                (root / name).mkdir(parents=True, exist_ok=True)
            for name in ns["FIXED"]:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(("fixture:" + name).encode())
            (root / "scripts/existing.gd").write_bytes(b"extends Node\n")
            (root / "scripts/existing.gd.uid").write_bytes(b"uid://e\n")
            (root / "scripts/.hidden.json").write_bytes(b"{}")
            return root
        def drift(kind):
            root = fixture()
            first = ns["source_receipt"](root)
            if kind == "addition": (root / "scripts/new.gd").write_bytes(b"extends Node\n")
            elif kind == "deletion": (root / "scripts/.hidden.json").unlink()
            elif kind == "bytes": (root / "scripts/existing.gd").write_bytes(b"extends Node2D\n")
            elif kind == "uid": (root / "scripts/existing.gd.uid").write_bytes(b"uid://f\n")
            second = ns["source_receipt"](root)
            ns["need"](first == second, "Source snapshot differs after " + kind)
        for kind in ("addition", "deletion", "bytes", "uid"):
            case("source drift: " + kind, "source_receipts", lambda kind=kind: drift(kind), RuntimeError)
        def missing_fixed():
            root = fixture(); (root / ns["GUI"]).unlink(); return ns["source_receipt"](root)
        case("required public script missing", "source_receipts", missing_fixed, RuntimeError)
        def missing_directory():
            root = fixture(); (root / "assets").rmdir(); return ns["source_receipt"](root)
        case("required production directory missing", "source_receipts", missing_directory, RuntimeError)
        def hidden_and_public_uid():
            root = fixture(); uid = ns["GUI"] + ".uid"; (root / uid).write_bytes(b"uid://g\n")
            record = ns["source_receipt"](root)
            must("scripts/.hidden.json" in record["raw_file_sha256"] and uid in record["raw_file_sha256"], "Hidden/paired UID omitted")
            return {"hidden_file_included":True, "existing_public_uid_included":True}
        case("hidden file and existing public UID included", "source_receipts", hidden_and_public_uid)
        def scan_failure():
            root = fixture()
            def failing_walk(*args, **kwargs):
                kwargs["onerror"](PermissionError("synthetic unreadable fixture directory"))
                return []
            with patch.object(ns["os"], "walk", failing_walk):
                return ns["source_receipt"](root)
        case("directory scan failure is not ignored", "source_receipts", scan_failure, PermissionError)
        def scan_race():
            root = fixture(); original = ns["enumerate_sources"]; calls = [0]
            def changing(path):
                result = original(path); calls[0] += 1
                if calls[0] == 1: (root / "scripts/arrived.json").write_bytes(b"{}")
                return result
            ns["enumerate_sources"] = changing
            try: return ns["source_receipt"](root)
            finally: ns["enumerate_sources"] = original
        case("new path during receipt hashing is rejected", "source_receipts", scan_race, RuntimeError)

        def uid_case(kind):
            root = fixture(); legacy = ns["CONTRACT"] + "/legacy_settings.gd"
            (root / legacy).write_bytes(b"extends Node\n")
            first = ns["source_receipt"](root)
            missing = {name + ".uid":name for name in first["raw_file_sha256"] if name.endswith(".gd") and name + ".uid" not in first["raw_file_sha256"]}
            must(len(missing) == 3, "Expected exactly the two public scripts and legacy fixture")
            for i, uid in enumerate(missing): (root / uid).write_bytes(("uid://" + chr(98 + i) + "\n").encode())
            if kind == "extra":
                (root / ns["CONTRACT"] / "alien.gd").write_bytes(b"extends Node\n")
                (root / ns["CONTRACT"] / "alien.gd.uid").write_bytes(b"uid://h\n")
            elif kind == "old_uid": (root / "scripts/existing.gd.uid").write_bytes(b"uid://h\n")
            elif kind == "overflow": (root / next(iter(missing))).write_bytes(b"uid://yyyyyyyyyyyyy\n")
            elif kind == "script": (root / ns["GUI"]).write_bytes(b"changed source\n")
            result, generated = ns["accept_import_metadata"](root, first, missing)
            must(len(generated) == 3, "Missing actual UID receipt")
            return {"new_uid_paths":list(generated), "generated_metadata":generated,
                    "original_source_sha256":first["combined_sha256"], "imported_source_sha256":result["combined_sha256"]}
        case("exact three missing-script UID additions", "uid_allowance", lambda: uid_case("valid"))
        for kind in ("extra", "old_uid", "overflow", "script"):
            case("UID/source change: " + kind, "uid_allowance", lambda kind=kind: uid_case(kind), RuntimeError)

        valid = {"schema":1, "stage":"write", "run_id":"fixture_run", "checks":[{"passed":True}],
                 "failures":[], "gui_valid":True, "source_manifest_sha256":"fixture_manifest"}
        def report_case(changes, missing=False):
            file = fixture_root / ("report_" + str(len(rows)) + ".json")
            if not missing: file.write_text(json.dumps(dict(valid, **changes)), encoding="utf-8")
            return ns["read_report"](file, "write", "fixture_run", "gui_valid", "fixture_manifest")
        case("complete matching report", "report_validation", lambda: report_case({}))
        for label, changes in [("wrong stage",{"stage":"read"}), ("wrong run",{"run_id":"old"}),
                               ("empty checks",{"checks":[]}), ("false check row",{"checks":[{"passed":False}]}),
                               ("truthy string validity",{"gui_valid":"true"}), ("source mismatch",{"source_manifest_sha256":"other"})]:
            case(label, "report_validation", lambda changes=changes: report_case(changes), RuntimeError)
        case("missing process report", "report_validation", lambda: report_case({}, missing=True), RuntimeError)

        class FakeChild:
            pid = 424242
            def __init__(self, mode): self.mode=mode; self.exited=False; self.killed=0; self.waits=[]
            def wait(self, timeout):
                self.waits.append(timeout)
                if self.mode in ("timeout", "unconfirmed") and len(self.waits) == 1:
                    raise subprocess.TimeoutExpired("in-memory child", timeout)
                if self.mode == "interrupt" and len(self.waits) == 1: raise KeyboardInterrupt()
                if self.mode == "unconfirmed": raise RuntimeError("in-memory stop failure")
                self.exited=True; return -9 if self.killed else 0
            def kill(self): self.killed += 1
            def poll(self): return (-9 if self.killed else 0) if self.exited else None
        def process_case(mode):
            child = FakeChild(mode); log = fixture_root / ("process_" + mode + ".log")
            original_guard = ns["require_exclusive_godot"]
            ns["require_exclusive_godot"] = lambda: None  # No OS scan/process is executed.
            ns["ACTIVE_PROCESS"] = None
            failure = None
            def factory(*args, **kwargs):
                if mode == "script_error": kwargs["stdout"].write(b"SCRIPT ERROR: injected fixture failure\n")
                return child
            try:
                with patch.object(subprocess, "Popen", factory):
                    try: ns["run_process"]("NEVER_EXECUTED", fixture_root, log, {}, 40, "tools/fake.gd")
                    except BaseException as exc: failure = type(exc).__name__
                observed = json.loads(log.with_name(log.stem + "_process.json").read_text(encoding="utf-8"))
                must((failure is None) == (mode == "normal"), "Incorrect process acceptance")
                must(observed["child_exit_confirmed"] == (mode != "unconfirmed"), "False exit confirmation")
                must((ns["ACTIVE_PROCESS"] is child) == (mode == "unconfirmed"), "Unconfirmed handle lost")
                if mode in ("timeout", "interrupt", "unconfirmed"):
                    must(child.killed == 1 and child.waits == [40,30], "Child not killed/waited exactly as required")
                return {"injected_outcome":mode, "runner_exception":failure,
                        "wait_timeouts":child.waits, "kill_calls":child.killed,
                        "child_exit_confirmed":observed["child_exit_confirmed"],
                        "unconfirmed_handle_preserved":ns["ACTIVE_PROCESS"] is child,
                        "matched_messages":observed["matched_messages"]}
            finally:
                ns["require_exclusive_godot"] = original_guard
                ns["ACTIVE_PROCESS"] = None
        for mode in ("normal", "timeout", "interrupt", "unconfirmed", "script_error"):
            case("owned process lifecycle: " + mode, "mock_process_lifecycle", lambda mode=mode: process_case(mode))
        must(fixture_root.resolve().parent == HERE.resolve(), "Refuse cleanup outside requested directory")
    case("production whole-file diff and callback invariance", "readonly_source_review", audit_production)
    case("public behavior and GUI callback migration", "readonly_source_review", audit_qa_migration)
    after = signatures()
    case("all reviewed project inputs remained exact bytes", "readonly_source_review",
         lambda: must(before == after, "A reviewed project file changed during checks"))
    counts = {category: sum(row["category"] == category for row in rows) for category in sorted({row["category"] for row in rows})}
    report = {"schema":1, "started_utc":start, "completed_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "command":"python scratchpad/reduced_effects_public_static/check.py", "python":sys.version,
              "check_script_raw_sha256":sha(Path(__file__).read_bytes()), "input_raw_sha256_before":before,
              "input_raw_sha256_after":after, "cases":rows, "case_count":len(rows), "category_counts":counts,
              "passed":all(row["passed"] for row in rows), "failed_cases":[row["name"] for row in rows if not row["passed"]],
              "temporary_fixture_root_removed":not fixture_root.exists(), "real_subprocesses_started":0,
              "godot_run":False, "production_or_public_tools_mutated":False,
              "scope":"Real runner logic against temporary filesystem data and mocked process outcomes. Case count is not gameplay features; engine behavior is covered by separate public runs."}
    (HERE / "receipts.json").write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode())
    print(json.dumps({"passed":report["passed"], "cases":len(rows), "failed":report["failed_cases"],
                      "categories":counts, "receipt":str(HERE / "receipts.json"), "godot_run":False}, ensure_ascii=False))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
