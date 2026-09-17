"""Read-only dependency verification and syntax checks; writes only this scratch.

Does not start Godot, create a runtime copy, hash all resources, or use Git.
"""
from pathlib import Path
import ast
import hashlib
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
IDENTITY = ROOT / "scratchpad/stabilization_identity_20260907"
EFFECTS = ROOT / "scratchpad/stabilization_root_effects_20260907"
DEFENSE_SHA = "b7cbf96458669df3cf87cced4fa1c786e4f538e9d14aa276e27e30bc00331283"
IDENTITY_RECEIPT_SHA = "9b55e9ebe583eb1a83a559bc27d873adc71fc0dc5c3f8dce4974caeebf37f24f"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def describe(path):
    raw = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(raw), "bytes": len(raw)}


def dump(name, data):
    (HERE / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def main():
    receipt_file = IDENTITY / "source_receipt.json"
    assert sha(receipt_file.read_bytes()) == IDENTITY_RECEIPT_SHA
    receipt = json.loads(receipt_file.read_bytes())
    source = EFFECTS / "candidate/scripts/run_defense_level_state.gd"
    candidate = HERE / "candidate/scripts/run_defense_level_state.gd"
    assert sha(source.read_bytes()) == DEFENSE_SHA
    assert candidate.read_bytes() == source.read_bytes()
    overlays = []
    for row in receipt["files"]:
        path = IDENTITY / "candidate" / row["path"]
        assert sha(path.read_bytes()) == row["candidate_sha256"], row["path"]
        assert sha((ROOT / row["path"]).read_bytes()) == row["before_raw_sha256"], ("production drift", row["path"])
        overlays.append({"destination": row["path"], "input": describe(path), "production_before_sha256": row["before_raw_sha256"]})
    assert len(overlays) == 24
    assert sha((ROOT / "scripts/run_defense_level_state.gd").read_bytes()) == "5cb83ac01cddcdab0865434caa5e0de5ec8e5d1f28a746c657dc745e7ca4aa91"
    overlays.append({"destination": "scripts/run_defense_level_state.gd", "input": describe(candidate), "production_before_sha256": sha((ROOT / "scripts/run_defense_level_state.gd").read_bytes())})
    sys.path.insert(0, str(IDENTITY / "parser_runtime"))
    from gdtoolkit.parser import parser
    for path in [candidate, HERE / "bridge_smoke.gd"]:
        parser.parse(path.read_text(encoding="utf-8"), gather_metadata=True)
    ast.parse(Path(__file__).read_text(encoding="utf-8"))
    driver = (HERE / "bridge_smoke.gd").read_text(encoding="utf-8")
    assert "preload(" not in driver and "--headless" not in driver
    assert "defense.restore(bundle.level, VERSION, prepared.id_to_unit, gv.next_entity_id)" in driver
    assert "foe.entity_id = hall.get_instance_id()" in driver
    assert "target.next_entity_id = prepared.pending_battle_fields.next_entity_id" in driver
    assert driver.index("target.next_entity_id = prepared.pending_battle_fields.next_entity_id") < driver.index('target.spawn_unit("bridge_new"')
    frozen_inputs = [describe(p) for p in [receipt_file, IDENTITY / "freeze.json", source,
        HERE / "bridge_smoke.gd", HERE / "prepare.py", HERE / "HANDOFF.md"]]
    data = {"status": "syntax_verified_native_pending", "godot_run": False, "production_modified": False,
        "inputs": frozen_inputs, "overlays": overlays, "copied_defense_same_bytes": True,
        "driver_destination": "tools/stabilization_defense_identity_bridge/bridge_smoke.gd",
        "driver": describe(HERE / "bridge_smoke.gd"), "expected_suite": "defense-identity-bridge",
        "manifest_environment_variable": "RUN_RESTORE_QA_MANIFEST",
        "manifest_required": ["run_id", "private_user", "report", "source_sha256"],
        "host_guards_required": ["exclusive Godot lock", "private full project from pinned baseline plus 25 overlays",
            "actual private APPDATA/LOCALAPPDATA/TEMP/TMP", "real PID and strict logs", "all loaded input source hashes before/after",
            "production and actual player profile unchanged", "bounded timeout and owned-process cleanup", "final exit and lock ownership"],
        "parser": "gdtoolkit 4.5.0; syntax only", "engine_typecheck_passed": False,
        "boundary": "Historical position keys below validated next are allowed without current live membership; allocator is a high-water mark, not an allocation journal."}
    dump("source_receipt.json", data)
    dump("static_review.json", {"status": data["status"], "overlay_files": len(overlays), "parsed_gd_files": 2,
        "python_ast": True, "candidate_sha256": DEFENSE_SHA, "driver": data["driver"], "godot_run": False,
        "checks": ["24 identity candidate and production-before hashes", "one exact copied defense v2", "deferred game class load",
            "graph-validated next supplied to level restore", "deliberate cross-domain collision", "allocator installation before post-restore spawn"]})
    overlay = {"status": "frozen_native_pending", "source_full_copy_required": True, "production_changed": False,
        "identity_source_receipt_sha256": IDENTITY_RECEIPT_SHA,
        "files": [{"path": row["destination"], "candidate": row["input"]["path"],
            "candidate_sha256": row["input"]["sha256"], "before_exists": True,
            "before_raw_sha256": row["production_before_sha256"]} for row in overlays]}
    assert len(overlay["files"]) == len({x["path"] for x in overlay["files"]}) == 25
    dump("overlay_manifest.json", overlay)
    freeze = {"status": "frozen_for_first_native_attempt", "engine_run": False, "production_changed": False,
        "inputs": {name: sha((HERE / name).read_bytes()) for name in ["overlay_manifest.json", "bridge_smoke.gd",
            "HANDOFF.md", "prepare.py", "source_receipt.json", "static_review.json", "candidate/scripts/run_defense_level_state.gd"]}}
    dump("freeze.json", freeze)
    print(json.dumps({"status": data["status"], "overlays": len(overlays), "candidate_sha256": DEFENSE_SHA,
        "driver": data["driver"], "freeze_sha256": sha((HERE / "freeze.json").read_bytes())}, ensure_ascii=False))


if __name__ == "__main__":
    main()
