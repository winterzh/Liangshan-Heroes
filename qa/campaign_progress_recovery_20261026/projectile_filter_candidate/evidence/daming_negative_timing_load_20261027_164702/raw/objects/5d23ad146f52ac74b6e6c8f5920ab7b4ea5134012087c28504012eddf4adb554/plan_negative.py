"""Named-source planning and strict completed b22 Flow/closed-A admission.

Default does not launch an engine, copy profiles or audit a whole project.
The separate run_negative.py host requires full new-freeze/own-cold admission.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import uuid

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parents[1]
ROOT = CANDIDATE.parents[2]
WORKERS = ("bootstrap.gd", "fixture_reader.gd", "case_catalog.gd", "worker_support.gd",
           "world_worker.gd", "component_worker.gd", "capture_base.gd", "capture_worker.gd")


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prep = load("daming_negative_prepare", CANDIDATE.parent / "projectile_filter_candidate/integration_3365/prepare_projectile.py")
p, h = prep.p, prep.h
fixture = load("daming_negative_closed_a", HERE.parent / "daming_flow/fixture_freeze.py")
require = fixture.require


def raw(path):
    h.identity.no_links(p.fs(path))
    return p.fs(path).read_bytes()


def document(path):
    return fixture.strict_json(raw(path))


def pin(path):
    path = Path(path).absolute()
    value = raw(path)
    return {"path": str(path), "bytes": len(value), "sha256": hashlib.sha256(value).hexdigest()}


def block(text, name):
    start = text.index("func " + name + "(")
    stop = text.find("\nfunc ", start + 1)
    return text[start:stop + 1 if stop != -1 else len(text)]


def rebuild_catalog(plan):
    texts = {}
    for row in plan["historical_sources"]:
        path = ROOT / row["path"]
        require(path.is_relative_to(ROOT / "qa"), "historical source within QA")
        value = raw(path)
        require(len(value) == row["bytes"] and fixture.digest(value) == row["sha256"], "historical table source pin")
        texts[row["kind"]] = value.decode("utf-8")
    world = [next(x + "\n" for x in texts["world"].splitlines() if x.startswith("const " + name + " "))
             for name in ("RECORD_TEXT", "CONTEXT_TEXT", "CASTERS")]
    world += [block(texts["world"], name) for name in ("_add", "_build_specs")]
    component = [block(texts["component"], name) for name in ("_add", "_build_specs")]
    capture = texts["capture"][texts["capture"].index("const CAPTURE_CASES := {"):
                               texts["capture"].index("const IDENTITY_FIELDS :=")]
    for row, fragments in zip(plan["historical_sources"], (world, component, [capture])):
        require([fixture.digest(value.encode("utf-8")) for value in fragments] == row["retained_blocks_sha256"],
                "exact historical declaration/function bytes")
    require(json.loads(capture[capture.index("{"):].strip()) == plan["capture"]["cases"], "exact 24 capture map")

    def nested(name, parts):
        return ("class " + name + ":\n\textends RefCounted\n\tvar specs: Array = []\n"
                + "".join("".join("\t" + line if line.strip() else line for line in value.splitlines(keepends=True))
                          for value in parts) + "\n")
    value = ("extends RefCounted\n"
        "## Generated from exact historical table declarations, not historical fixture admission.\n"
        "## No negative execution is implemented here; source audit reconstructs these bytes.\n"
        + capture + "\n" + nested("WorldCases", world) + nested("ComponentCases", component)
        + "static func world_specs() -> Array:\n\tvar table := WorldCases.new()\n\ttable._build_specs()\n\treturn table.specs\n\n"
        + "static func component_specs() -> Array:\n\tvar table := ComponentCases.new()\n\ttable._build_specs()\n\treturn table.specs\n")
    require(value.encode("utf-8") == raw(HERE / "case_catalog.gd")
            and fixture.digest(value.encode("utf-8")) == plan["catalog_sha256"], "catalog is exact declared extraction")


def verify_migration():
    audit = document(HERE / "migration_audit.json")
    require(audit.get("schema") == "daming_negative_migration_function_audit_v2", "Migration audit schema")
    for row in audit["changes"]:
        old = raw(ROOT / row["original"]["path"]).decode("utf-8")
        new = raw(ROOT / row["candidate"]["path"]).decode("utf-8")
        require(pin(ROOT / row["candidate"]["path"])["sha256"] == row["candidate"]["sha256"], "Migrated worker pin")
        for retained in row["retained_functions"]:
            left = (block(old, retained["method"]).rstrip() + "\n").encode("utf-8")
            right = (block(new, retained["method"]).rstrip() + "\n").encode("utf-8")
            require(left == right and fixture.digest(left) == retained["sha256"], "Exact original assertion function " + retained["method"])
    row = audit["capture_worker"]
    old = raw(ROOT / row["original"]["path"]).decode("utf-8")
    new = raw(ROOT / row["candidate"]["path"]).decode("utf-8")
    require(pin(ROOT / row["candidate"]["path"])["sha256"] == row["candidate"]["sha256"]
            and pin(ROOT / row["new_capture_base"]["path"])["sha256"] == row["new_capture_base"]["sha256"], "Capture closure exact pins")
    for retained in row["retained_functions"]:
        left = (block(old, retained["method"]).rstrip() + "\n").encode("utf-8")
        right = (block(new, retained["method"]).rstrip() + "\n").encode("utf-8")
        require(left == right and fixture.digest(left) == retained["sha256"], "Exact original live mutation/undo " + retained["method"])


def static_plan():
    sources = document(HERE / "sources.json")
    require(sources.get("schema") == "daming_negative_external_sources_v2", "new external source manifest")
    for row in sources["files"] + sources["dependencies"]:
        source = ROOT / row["path"]
        require(source.is_relative_to(ROOT) and ".." not in Path(row["path"]).parts, "source path bound")
        observed = pin(source)
        require(observed["bytes"] == row["bytes"] and observed["sha256"] == row["sha256"], "named source bytes unchanged")
    plan = document(HERE / "case_plan.json")
    rebuild_catalog(plan)
    verify_migration()
    require(plan["world"]["specs_per_role"] == 132 and plan["component"]["specs_per_role"] == 181
            and len(plan["capture"]["cases"]) == 24, "fixed historical case cardinalities")
    stages = []
    for role in ("lu", "shi"):
        stages.extend([{"first_role": role, "family": "world", "rows": 264},
                       {"first_role": role, "family": "component", "rows": 362}])
        stages += [{"first_role": role, "family": "capture", "case": name, "expected_code": code,
                    "renderer": "gl_compatibility", "new_profile_and_process_required": True}
                   for name, code in plan["capture"]["cases"].items()]
    require(len(stages) == 52, "exact 52 planned process stages")
    return stages


def validate_flow_source(receipt_path):
    """Small named receipts/pins only; full installed source admission is separate."""
    receipt_path = Path(receipt_path).absolute()
    run = receipt_path.parent
    require(receipt_path.name == "receipt.json" and run.parent == ROOT / ".godot/daming_projectile_flow_20261027",
            "Only a new projectile-source producer is admissible")
    receipt = document(receipt_path)
    required = ("complete", "eight_stages_passed", "source_flow_chain_passed", "initial_identity_passed",
                "final_identity_passed", "child_process_terminal", "lock_ownership_confirmed", "engine_lane_idle",
                "lock_released", "cold_import_qualified")
    require(receipt.get("schema") == "daming_flow_eight_process_v1" and all(receipt.get(k) is True for k in required)
            and receipt.get("cleanup_errors") == [] and "error" not in receipt,
            "Actual same-source complete eight Flow processes are required before profile/engine creation")
    require(receipt.get("candidate_script_count") == 26 and receipt.get("native_asset_count") == 1,
            "26 scripts plus original native helper required")
    base = Path(receipt["base_run"])
    require(base.is_absolute() and base.parent == ROOT / ".godot/campaign_progress_recovery_20261026"
            and receipt["project"] == str(base / "project"), "Exact new frozen project path")
    pins = receipt.get("pinned_files", {})
    require(type(pins) is dict and pins, "Producer pins required")
    evidence_pins = {str(receipt_path): pin(receipt_path)["sha256"]}
    source_map = []
    # Prefer the producer's immutable runner_inputs over subsequently edited sources.
    # Native executables are hash-only here; prepared_state verifies them before launch.
    for name, digest in pins.items():
        original = Path(name)
        require(original.is_absolute() and fixture.hex_text(digest, 64), "Strict absolute producer pin")
        if original.suffix.lower() == ".exe":
            source_map.append({"source": name, "sha256": digest, "kind": "native_hash_only_full_admission_required"})
            continue
        require(original.is_relative_to(ROOT), "Producer named source outside project")
        copied = run / "runner_inputs" / original.relative_to(ROOT)
        actual = original if original.is_relative_to(run) else copied
        require(p.fs(actual).is_file(), "Missing actual frozen producer source: " + str(actual))
        observed = pin(actual)
        require(observed["sha256"] == digest, "Frozen producer source changed: " + str(actual))
        evidence_pins[str(actual)] = digest
        source_map.append({"source": name, "frozen": str(actual), "sha256": digest, "bytes": observed["bytes"]})
    imports = receipt.get("import_receipts", [])
    require(type(imports) is list and len(imports) == 1, "One own cold-import receipt required")
    cold_path = Path(imports[0])
    require(cold_path.parent.parent == base and cold_path.parent.name.startswith("import_cold__")
            and cold_path.name == "receipt.json", "Own first cold-import path")
    cold_pin = pin(cold_path)
    require(pins.get(str(cold_path)) == cold_pin["sha256"], "Producer pins its own cold receipt")
    cold = document(cold_path)
    require(cold.get("schema") == "projectile_3365_cold_import_v1" and cold.get("phase") == "import"
            and cold.get("project") == receipt["project"] and cold.get("run_base") == str(base)
            and cold.get("engine_sha256") == receipt["engine_sha256"]
            and all(cold.get(k) is True for k in ("complete", "cold_import_qualified", "lock_released",
                "lock_owner_verified", "engine_lane_idle", "child_terminal", "initial_identity_passed",
                "final_identity_passed", "final_pins_passed", "engine_pin_passed",
                "production_identity_passed", "generated_identity_passed"))
            and not cold.get("error") and not cold.get("cleanup_errors") and not cold.get("postcheck_errors"),
            "Own first cold native import and full terminal checks")
    require(len(cold.get("steps", [])) == 1 and cold["steps"][0].get("passed") is True
            and type(cold["steps"][0].get("pid")) is int and cold["steps"][0]["pid"] > 0
            and cold["steps"][0].get("exit_code") == 0 and cold["steps"][0].get("errors") == []
            and cold["steps"][0].get("stopped_for") is None, "Actual terminal import child")
    evidence_pins[str(cold_path)] = cold_pin["sha256"]
    manifest_path = base / "candidate_manifest.json"
    require(pin(manifest_path)["sha256"] == receipt["candidate_manifest_sha256"] == pins.get(str(manifest_path)),
            "Producer exact candidate manifest")
    manifest = document(manifest_path)
    require(manifest.get("schema") == "projectile_3365_integrated_manifest_v1"
            and len(manifest.get("files", [])) == 26 and len(manifest.get("native_assets", [])) == 1,
            "Strict current manifest shape")
    evidence_pins[str(manifest_path)] = receipt["candidate_manifest_sha256"]
    modes = ("save_single", "resume_settle_save", "resume_finish", "reject_terminal")
    steps, reports = receipt.get("steps", []), receipt.get("reports", [])
    require(len(steps) == len(reports) == len(receipt.get("attempted_modes", [])) == 8, "Exact eight native stages")
    seen_pids, seen_nonces = set(), set()
    worker_manifest = str(CANDIDATE / "tests/daming_flow/sources.json")
    for index, (role, mode) in enumerate((r, m) for r in ("lu", "shi") for m in modes):
        step, summary = steps[index], reports[index]
        path, log = run / role / mode / "report.json", run / role / mode / (mode + ".log")
        report = document(path)
        role_row = receipt.get("roles", {}).get(role, {})
        require(role_row.get("complete") is True and len(role_row.get("process_ids", [])) == 4
                and len(role_row.get("process_nonces", [])) == 4, "Complete native role chain")
        require(summary.get("first_role") == role and summary.get("mode") == mode and summary.get("path") == str(path)
                and summary.get("passed") is True and summary.get("failures") == []
                and pin(path)["sha256"] == summary.get("sha256") == pins.get(str(path))
                and pin(log)["sha256"] == step.get("log_sha256") == pins.get(str(log)), "Actual report/log pin and order")
        pid, nonce = report.get("pid"), report.get("process_nonce")
        require(type(pid) is int and pid > 0 and pid not in seen_pids and pid == step.get("pid")
                and pid == role_row["process_ids"][modes.index(mode)] and fixture.hex_text(nonce,32)
                and nonce not in seen_nonces and nonce == step.get("process_nonce")
                and nonce == role_row["process_nonces"][modes.index(mode)]
                and type(step.get("exit_code")) is int and step["exit_code"] == 0
                and step.get("passed") is True and step.get("errors") == [] and step.get("stopped_for") is None
                and step.get("first_role") == role and step.get("mode") == mode, "Distinct actual terminal child chain")
        seen_pids.add(pid); seen_nonces.add(nonce)
        require(report.get("schema") == "campaign_daming_flow_v1" and report.get("passed") is True
                and report.get("stage_completed") is True and report.get("failures") == [] and report.get("checks")
                and all(row.get("passed") is True for row in report["checks"])
                and report.get("mode") == mode and report.get("first_role") == role
                and report.get("batch_nonce") == receipt["batch_nonce"] and report.get("role_nonce") == role_row["role_nonce"]
                and report.get("profile") == role_row["profile"] and report.get("slot_root") == "user://continue/v1"
                and report.get("candidate_manifest_sha256") == receipt["candidate_manifest_sha256"]
                and report.get("sources_sha256") == pins.get(worker_manifest)
                and report.get("identity", {}).get("content_version") == receipt["content_version"]
                and report.get("identity", {}).get("engine_sha256") == receipt["engine_sha256"]
                and report.get("identity", {}).get("source_mode") is True
                and report.get("simulation_time_scale") == 1 and report.get("physics_hz") == 60
                and report.get("no_gameplay_state_injection") is True,
                "Actual current Flow source/clock/identity report")
        if mode in modes[:2]:
            require(report.get("save_exit_observed") is True and report.get("exit_reason") == "continue_saved",
                    "Both saves must exit through production AppLifecycle")
        if mode == "resume_finish":
            result = report.get("terminal_checkpoint", {}).get("full_result", {})
            require(report.get("observations", {}).get("natural_terminal") is True
                    and result.get("core_cleared") is True and result.get("contract_version") == 2
                    and result.get("story_total") == 3, "Natural current Level8 terminal required")
        if mode == "reject_terminal":
            refusal = report.get("observations", {}).get("terminal_refusal", {})
            require(refusal.get("ok") is False and refusal.get("code") == "LOCAL_RUN_TERMINAL",
                    "Independent native Flow terminal refusal required")
        evidence_pins[str(path)], evidence_pins[str(log)] = pins[str(path)], pins[str(log)]
    return {"receipt": receipt, "cold_import_receipt": cold_pin,
            "source_map": source_map, "evidence_pins": evidence_pins}


def admit_closed_a(receipt_path, role):
    """Read completed producer evidence only; never reread its advancing profile."""
    require(role in ("lu", "shi"), "explicit first role")
    receipt_path = Path(receipt_path).absolute()
    flow_run = receipt_path.parent
    require(receipt_path.name == "receipt.json" and flow_run.parent == ROOT / ".godot/daming_projectile_flow_20261027",
            "original actual Flow run receipt required")
    producer = validate_flow_source(receipt_path)
    receipt_pin = pin(receipt_path)
    receipt = producer["receipt"]
    require(receipt.get("schema") == "daming_flow_eight_process_v1" and all(receipt.get(key) is True for key in
        ("complete", "eight_stages_passed", "source_flow_chain_passed", "final_identity_passed",
         "child_process_terminal", "lock_ownership_confirmed", "engine_lane_idle", "lock_released"))
        and receipt.get("cleanup_errors") == [] and "error" not in receipt, "completed actual eight-process producer")
    require(receipt.get("candidate_script_count") == 26 and receipt.get("cold_import_qualified") is True and receipt.get("native_asset_count") == 1
            and receipt.get("project") == str(Path(receipt["base_run"]) / "project"), "producer candidate shape")
    steps, reports, pins = receipt["steps"], receipt["reports"], receipt["pinned_files"]
    require(len(steps) == len(reports) == 8 and len({step["pid"] for step in steps}) == 8,
            "eight distinct recorded terminal processes")
    for step in steps:
        require(type(step.get("pid")) is int and step["pid"] > 0 and type(step.get("exit_code")) is int
                and step["exit_code"] == 0 and step.get("passed") is True
                and step.get("errors") == [] and step.get("stopped_for") is None, "producer process terminal success")
    role_row = receipt["roles"][role]
    require(role_row.get("complete") is True and len(role_row["process_ids"]) == 4, "role process chain complete")
    reference = role_row["closed_a_fixture"]
    fixture.verify_frozen(p=p, output=flow_run, reference=reference, pins=pins)
    descriptor = document(reference["path"])
    require(descriptor.get("evidence_kind") == "actual_host_validated_closed_a"
            and descriptor.get("original_profile_unchanged") is True
            and descriptor.get("world_or_codec_reconstructed") is False, "actual closure, no synthetic fixture")
    expected = descriptor["expected"]
    require(expected["batch_nonce"] == receipt["batch_nonce"] and expected["role_nonce"] == role_row["role_nonce"]
            and expected["content_version"] == receipt["content_version"]
            and expected["engine_sha256"] == receipt["engine_sha256"]
            and expected["candidate_manifest_sha256"] == receipt["candidate_manifest_sha256"], "producer/descriptor identity binding")
    a_report = descriptor["a_report"]
    require(Path(a_report["path"]) == flow_run / role / "save_single/report.json"
            and pin(a_report["path"])["sha256"] == a_report["sha256"] == pins[a_report["path"]], "actual pinned A report")
    a = document(a_report["path"])
    require(a.get("schema") == "campaign_daming_flow_v1" and a.get("mode") == "save_single"
            and a.get("first_role") == role and a.get("passed") is True and a.get("stage_completed") is True
            and a.get("failures") == [] and a.get("checks") and all(row.get("passed") is True for row in a["checks"])
            and a.get("save_exit_observed") is True and a.get("exit_reason") == "continue_saved", "actual successful A schema")
    actual_steps = [step for step in steps if step.get("first_role") == role and step.get("mode") == "save_single"]
    require(len(actual_steps) == 1 and actual_steps[0] == descriptor["actual_process_step"]
            and a["pid"] == descriptor["actual_pid"] == actual_steps[0]["pid"], "actual A step/PID equality")
    for key in ("batch_nonce", "role_nonce", "process_nonce"):
        require(fixture.hex_text(expected[key], 32) and a.get(key) == expected[key], "exact A " + key)
    require(a["identity"]["content_version"] == expected["content_version"]
            and a["identity"]["engine_sha256"] == expected["engine_sha256"]
            and a["identity"]["source_mode"] is True and a["sources_sha256"] == expected["sources_sha256"], "actual A runtime identity")
    log = descriptor["a_log"]
    require(Path(log["path"]) == flow_run / role / "save_single/save_single.log"
            and pin(log["path"])["sha256"] == log["sha256"] == pins[log["path"]]
            and log["sha256"] == actual_steps[0]["log_sha256"], "actual A clean terminal log pin")
    cp, binding = a["checkpoint"], descriptor["binding"]
    require(cp["generation"] == 1 and type(cp["generation"]) is not bool and cp["binding"] == binding
            and cp["file_sha256"] == reference["slot_sha256"] and cp["lifecycle"]["file_sha256"] == reference["lifecycle_sha256"]
            and cp["lifecycle"]["document"]["schema"] == "local_campaign_continue_lifecycle_v3", "actual A genesis binding")
    terminal_path = flow_run / role / "resume_finish/report.json"
    terminal_pin = pin(terminal_path)
    require(terminal_pin["sha256"] == pins[str(terminal_path)], "actual C terminal report pin")
    terminal = document(terminal_path)
    terminal_lc = terminal.get("terminal_checkpoint", {}).get("lifecycle", {}).get("document", {})
    require(terminal.get("schema") == "campaign_daming_flow_v1" and terminal.get("mode") == "resume_finish"
            and terminal.get("first_role") == role and terminal.get("passed") is True
            and terminal.get("batch_nonce") == expected["batch_nonce"]
            and terminal_lc.get("schema") == "local_campaign_continue_lifecycle_v3"
            and terminal_lc.get("token") == binding["token"] and terminal_lc.get("generation") == 3
            and terminal_lc.get("intent", {}).get("schema") == "campaign_progress_intent_v2"
            and terminal_lc.get("progress_receipt", {}).get("schema") == "campaign_progress_ack_v2",
            "same-token producer C documents current LC3/Intent2/ACK2; no legacy fallback")
    require(pin(receipt_path) == receipt_pin, "producer receipt unchanged during admission")
    frozen_scope = Path(descriptor["frozen_scope"])
    return {"schema": "daming_negative_admission_request_v2", "first_role": role,
        "flow_receipt": receipt_pin, "closed_a_descriptor": pin(reference["path"]), "a_report": a_report, "a_log": log,
        "producer_terminal_report": terminal_pin,
        "slot": pin(frozen_scope / descriptor["slot_relative_path"]),
        "lifecycle": pin(frozen_scope / descriptor["lifecycle_relative_path"]),
        "content_version": expected["content_version"], "engine_sha256": expected["engine_sha256"],
        "candidate_manifest_sha256": expected["candidate_manifest_sha256"], "base_run": receipt["base_run"],
        "producer_pid": a["pid"], "producer_batch_nonce": expected["batch_nonce"],
        "producer_role_nonce": expected["role_nonce"], "producer_process_nonce": expected["process_nonce"],
        "consumer_batch_nonce": uuid.uuid4().hex, "consumer_process_nonce": uuid.uuid4().hex,
        "binding": binding, "context": dict(fixture.CONTEXT), "scope": "negative_matrix_52",
        "project": receipt["project"], "cold_import_qualified": True,
        "cold_import_receipt": producer["cold_import_receipt"],
        "producer_source_map": producer["source_map"],
        "producer_evidence_pins": producer["evidence_pins"],
        "full_current_source_audit_required_before_native_launch": True,
        "worker_bindings": {name: pin(HERE / name)["sha256"] for name in WORKERS}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flow-receipt", type=Path, help="Original completed actual eight-process receipt")
    parser.add_argument("--role", choices=("lu", "shi"))
    parser.add_argument("--request-output", type=Path, help="Write a new admission request only; no profiles or engine")
    args = parser.parse_args()
    stages = static_plan()
    if args.flow_receipt:
        require(args.role is not None, "role required for actual fixture admission")
        request = admit_closed_a(args.flow_receipt, args.role)
        if args.request_output:
            h.identity.no_links(p.fs(args.request_output))
            require(p.fs(args.request_output.parent).is_dir(), "request parent must already exist")
            h.save(p.fs(args.request_output), request)
        print(json.dumps({"admission_request": request, "engine_started": False,
                          "negative_execution_implemented": True}, ensure_ascii=False))
    else:
        require(args.role is None and args.request_output is None, "actual receipt required for request drafting")
        print(json.dumps({"planned_processes": len(stages), "world": 2, "component": 2, "capture": 48,
            "fixed_world_specs_per_role": 132, "fixed_component_specs_per_role": 181,
            "capture_cases_per_role": 24, "source_tables_preserved": True,
            "implemented_scope": "52_stage_external_tools_unexecuted", "native_compiled": False,
            "negative_execution_implemented": True, "engine_started": False, "full_source_verified": False,
            "profile_created": False, "cold_import_qualified": False, "full_61_qualified": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
