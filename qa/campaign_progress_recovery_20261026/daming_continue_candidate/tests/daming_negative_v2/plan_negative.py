"""Read-only source/52-stage planning and closed-A admission request drafting.

No engine launcher, profile creation, payload copying, source freeze or complete
identity audit is implemented. Default checks only named small source files.
The future native host MUST call integration_941.prepared_state before execution.
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
WORKERS = ("bootstrap.gd", "fixture_reader.gd", "admission_worker.gd", "case_catalog.gd")


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prep = load("daming_negative_prepare", CANDIDATE / "integration_941/prepare_daming.py")
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


def admit_closed_a(receipt_path, role):
    """Read completed producer evidence only; never reread its advancing profile."""
    require(role in ("lu", "shi"), "explicit first role")
    receipt_path = Path(receipt_path).absolute()
    flow_run = receipt_path.parent
    require(receipt_path.name == "receipt.json" and flow_run.parent == ROOT / ".godot/daming_flow_20261027",
            "original actual Flow run receipt required")
    receipt_pin = pin(receipt_path)
    receipt = document(receipt_path)
    require(receipt.get("schema") == "daming_flow_eight_process_v1" and all(receipt.get(key) is True for key in
        ("complete", "eight_stages_passed", "source_flow_chain_passed", "final_identity_passed",
         "child_process_terminal", "lock_ownership_confirmed", "engine_lane_idle", "lock_released"))
        and receipt.get("cleanup_errors") == [] and "error" not in receipt, "completed actual eight-process producer")
    require(receipt.get("candidate_script_count") == 25 and receipt.get("native_asset_count") == 1
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
        "binding": binding, "context": dict(fixture.CONTEXT), "scope": "admission_only_not_52_execution",
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
                          "negative_execution_implemented": False}, ensure_ascii=False))
    else:
        require(args.role is None and args.request_output is None, "actual receipt required for request drafting")
        print(json.dumps({"planned_processes": len(stages), "world": 2, "component": 2, "capture": 48,
            "fixed_world_specs_per_role": 132, "fixed_component_specs_per_role": 181,
            "capture_cases_per_role": 24, "source_tables_preserved": True,
            "implemented_scope": "admission_and_case_catalog_only", "native_compiled": False,
            "negative_execution_implemented": False, "engine_started": False, "full_source_verified": False,
            "profile_created": False, "cold_import_qualified": False, "full_61_qualified": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
