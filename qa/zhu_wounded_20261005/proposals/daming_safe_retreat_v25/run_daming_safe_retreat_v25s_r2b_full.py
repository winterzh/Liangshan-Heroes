"""UNEXECUTED full adapter sibling: b2 world, independent components, d1 live24.

This source reuses immutable r2a/parent/base guards. A scoped exploration receipt
is never a full pass; full startup requires its own producer/runner peer review.
Preparation performs AST review only, never imports or invokes these modules.
"""
from __future__ import annotations

import argparse
import ast
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import uuid

sys.dont_write_bytecode = True
BASE_SHA = "049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626"
PARENT_SHA = "5941315849982fb73d4851c2fcb95a2369d498760a83801427d315dd6a229af5"
EXPLORER_SHA = "d2fd596b94b2de563a073c897aa30892212e3f0c1ada2db475aec34ecf22801b"
DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
CASES = ("A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal")
VARIANTS = {"lu_first": "lu", "shi_first": "shi"}
TOOLS = {
    "world": ("daming_safe_retreat_negative_world_bundle_v25b2", "bc494c0bdabd1c52726f4f12465154529ed3cc9cee75042543d1872e11959b5d", "113eb68bde983102e92eb99b14d9537d968daa2516e8fc734808d03bdd30ccf0"),
    "component": ("daming_safe_retreat_component_bundle_v25", "ccb4abd78fe1277c2475f53ace9ff4c5c133e1e8ca4ebb59fa6ac30c65ab134a", "46adcee78872917b6518dc186ba1a055ff3bf00694835b723e51447282ba22fc"),
    "capture": ("daming_safe_retreat_capture_bundle_v25d1", "9933c71c514685da54ace5daf2e50ed645a998d34993c9709676dfb48d1e110b", "19d6c5c79a209cbee0e571a6992483ca31a56c0bde67681bf075b8a4543543f9"),
}


class PrerequisiteBlocked(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise PrerequisiteBlocked(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def absolute(value):
    p = Path(value)
    require(p.is_absolute(), "absolute path required")
    for q in [p, *p.parents]:
        if q.exists() or q.is_symlink():
            require(not q.is_symlink() and not getattr(q.lstat(), "st_file_attributes", 0) & 0x400,
                    "reparse/link source refused")
    return p.resolve()


def pin(row):
    p = absolute(row["path"])
    require(type(row.get("bytes")) is int and row["bytes"] > 0
            and p.is_file() and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"], "source pin drift")
    return p


def import_pinned(path, digest, name):
    require(sha(path) == digest, "imported immutable producer drift")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def preflight(args):
    for path, digest in [(args.explorer, EXPLORER_SHA), (args.parent_producer, PARENT_SHA), (args.base_producer, BASE_SHA)]:
        require(sha(path) == digest, "exact immutable producer source missing")
        ast.parse(path.read_text(encoding="utf-8-sig"))
    approval = read(args.adapter_review)
    require(approval.get("schema") == "daming_safe_retreat_adapter_review_v25s_r2b"
            and approval.get("static_api_closure_passed") is True and approval.get("approved_stages") == ["full"]
            and pin(approval["producer_pin"]) == Path(__file__).resolve(), "full independent producer review missing")
    runner = read(args.runner_review)
    require(runner.get("schema") == "daming_safe_retreat_runner_cross_review_v25"
            and runner.get("review_status") == "static_api_closure_no_identified_execution_blocker_native_pending"
            and "full" in runner.get("approved_stages", []), "new runner full-scope source closure absent")
    reviewed = {pin(r) for r in runner["candidate_pins"]}
    require({args.retreat_runner, args.retreat_scene, args.retreat_route} <= reviewed, "full runner/scene/route not pin reviewed")
    interfaces, extra, harnesses = {}, [args.explorer, args.parent_producer, args.base_producer,
        args.adapter_review, args.runner_review, args.retreat_runner, args.retreat_scene,
        args.retreat_route, args.negative_matrix, args.capture_base, args.capture_base_scene], []
    for kind in ["world", "component", "capture"]:
        source = getattr(args, kind + "_interface")
        data = read(source); schema, gd_sha, scene_sha = TOOLS[kind]
        require(data.get("schema") == schema and data["harness"]["sha256"] == gd_sha and data["scene"]["sha256"] == scene_sha,
                "full latest tool bundle mismatch")
        gd, scene = pin(data["harness"]), pin(data["scene"])
        require('type="Script" path="res://tools/' + gd.name + '"' in scene.read_text(encoding="utf-8-sig"), "fixed scene/GD binding changed")
        interfaces[kind] = data; extra += [source, gd, scene]
        harnesses.append({"id": kind, "gd": str(gd), "scene": str(scene)})
    require(len(interfaces["world"]["route_expectations"]) == 264
            and len(interfaces["component"]["required_route_rows"]) == 362
            and len(interfaces["capture"]["required_cases"]) == 24
            and {k for k in interfaces["capture"]["required_cases"] if k.startswith("safe_caster_")} ==
                {"safe_caster__walk_casts", "safe_caster__pending_casts", "safe_caster__channels", "safe_caster__walk_item_casts", "safe_caster__pending_item_casts"},
            "full exact source matrices or five actual live casts absent")
    for path, schema, kind in [(args.component_review, "daming_safe_retreat_component_peer_review_v25", "component"),
                               (args.capture_review, "daming_safe_retreat_capture_peer_review_v25d1", "capture")]:
        review = read(path)
        require(review.get("schema") == schema and review.get("static_api_closure_passed") is True
                and pin(review["harness_pin"]) == pin(interfaces[kind]["harness"])
                and pin(review["scene_pin"]) == pin(interfaces[kind]["scene"])
                and pin(review["interface_pin"]) == getattr(args, kind + "_interface"), "new actual component/live peer closure missing")
        extra.append(path)
    successor = read(args.negative_successor_review)
    require(successor.get("static_closure_passed_for_targeted_successor_changes") is True
            and successor["source_pins"]["world"]["sha256"] == TOOLS["world"][1], "world b2 source review absent")
    extra.append(args.negative_successor_review)
    require(sha(args.capture_base) == "6a70e00e6a7786bdf8791b84e3fdfdbe85159bf5398ec8ab385f2e34a3242940", "capture immutable inherited base changed")
    require(sha(args.capture_base_scene) == "5df31a7071b2625bda2fce59b72398257807babbd42f50d022ae37615e39247a", "capture inheritance scene drift")
    # Imported explorer's portable-proof function is used only after this gate.
    return runner, {"harnesses": harnesses, "pins": []}, interfaces, sorted(set(extra))


def runner_class(base, parent, explorer):
    Scoped = explorer.adapter_class(base, parent)

    class Full(Scoped):
        def __init__(self, args, run, reviewed, matrix, interfaces, extra_pins):
            super().__init__(args, run, reviewed, matrix, interfaces, extra_pins)
            self.receipt.update(schema="daming_safe_retreat_full_adapter_batch_v25s_r2b",
                                producer_sha256=sha(Path(__file__)), explorer_source_sha256=EXPLORER_SHA,
                                execution_scope="full", full_matrix_consumer_implemented=True,
                                actual_live_cases_per_role=24, all_negatives_qualified=False,
                                overall_v25_qualified=False, actual_A_fixture_exploration_complete=False)
            self.receipt.pop("unconsumed_live_cast_cases_in_this_explorer", None)

        def preflight(self):
            preflight(self.args)
            proof, proof_paths = explorer.portable_successor(self.args)
            base.Runner.preflight(self)
            missing = parent.producer_required_native_labels() - parent.source_proven_native_labels(self.args.retreat_runner, self.args.retreat_route)
            base.require(not missing, "full corrected runner mandatory native labels missing")
            for path in [Path(__file__).resolve(), *self.extra_pins, *proof_paths]:
                self.code_pins[str(path)] = sha(path)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": s} for p, s in self.code_pins.items()]
            # Include capture's explicit inherited old base in reference closure.
            closure_matrix = {"harnesses": self.matrix["harnesses"] + [{"id": "capture-base-reference-only",
                "gd": str(self.args.capture_base), "scene": str(self.args.capture_base_scene)}]}
            self.receipt["tool_dependency_closure"] = parent.reviewed_tool_dependency_closure(self.args, closure_matrix)
            self.receipt["source_proven_mandatory_native_labels"] = sorted(parent.producer_required_native_labels())
            self.receipt["actual_passed_successor_proof_sha256"] = sha(self.args.passed_admit_successor_proof)
            self.input_integrity()

        def prepare(self):
            super().prepare()
            target = self.project / "tools" / self.args.capture_base_scene.name
            base.require(not target.exists(), "capture inheritance scene collision")
            self.copy_checked(self.args.capture_base_scene, target, self.code_pins[str(self.args.capture_base_scene)])
            self.receipt["added_qa_files"].append({"path": "tools/" + target.name, "bytes": target.stat().st_size,
                "sha256": sha(target), "kind": "actual frozen scene source in explicit capture inheritance closure"})
            base.require(base.installed_identity(self.project) == self.installed and self.installed["file_count"] == 5102,
                         "full QA-only scene changed complete runtime identity")
            self.input_integrity(True)

        def claim_negative(self, step, report, fixture, nonce, marker, log):
            clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
            base.require(not re.search(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)", clean), "ANSI-stripped negative native error")
            return super().claim_negative(step, report, fixture, nonce, marker, clean)

        def run_component_negatives(self, variant):
            interface = self.interfaces["component"]; fixture = self.frozen_a[variant]
            group = self.new_group("component_" + variant); self.activate_group(group)
            scope, handoff = self.own_a_profile(group, fixture)
            manifest_path = self.output / "actual_A_manifest.json"
            manifest = self.actual_manifest(interface, fixture, manifest_path, True)
            out = self.output / "component"; nonce = uuid.uuid4().hex
            report_path = out / "report.json"; env = self.env.copy()
            env.update(DAMING_COMPONENT_PROFILE=str(self.profile), DAMING_COMPONENT_OUT=str(out),
                       DAMING_COMPONENT_MANIFEST=str(manifest_path), DAMING_COMPONENT_MANIFEST_SHA256=sha(manifest_path),
                       DAMING_COMPONENT_NONCE=nonce, DAMING_COMPONENT_EXPECT_CONTENT=self.installed["content_version"],
                       DAMING_COMPONENT_EXPECT_ENGINE=self.receipt["godot_sha256"], DAMING_ADMIT_NONCE=nonce)
            def validate(step, log):
                data = base.read(report_path)
                self.claim_negative(step, data, fixture, nonce, "DAMING_SAFE_COMPONENT_V25_COMPLETE ", log)
                base.require(data.get("schema") == interface["report_schema"]
                             and all(data.get(k) is True for k in ["pure_matrix_passed", "fixture_ready", "component_matrix_complete"])
                             and data.get("independent_component_calls_implemented") is True
                             and data.get("whole_world_DTO_prepare_substitution") is False, "independent actual component scope incomplete")
                for key in ["overall_v25_qualified", "future_producer_integration_qualified", "native_zero_ERROR_log_verified", "actual_two_unretreated_whole_fixture_qualified"]:
                    base.require(data.get(key) is False, "component falsely qualified wider scope")
                for key in ["actual_Core_prepare_calls", "actual_Core_capture_calls", "disk_slot_writes", "local_journal_writes", "gameplay_ticks_injected", "cached_grids_cleared"]:
                    base.require(type(data.get(key)) is int and data[key] == 0, "component source-only side effect violated")
                expected = {(r["id"], r["route"]): r for r in interface["required_route_rows"]}
                rows = data.get("executed_rows")
                base.require(isinstance(rows, list) and len(rows) == 362, "component exact362 target calls absent")
                actual = {(r.get("id"), r.get("route")): r for r in rows}
                base.require(len(actual) == len(rows) and set(actual) == set(expected), "component duplicated/missing fixed rows")
                fields = ["id", "route", "module", "actual_call", "expected_code", "expected_guard_layer",
                          "core_constructor_called", "core_prepare_called", "core_capture_called",
                          "core_zero_before", "core_zero_after", "direct_pair_branch_called"]
                for key, row in actual.items():
                    for field in fields:
                        value = expected[key][field]
                        base.require(type(row.get(field)) is type(value) and row.get(field) == value, "component actual API/nullable Core row mismatch")
                    base.require(all(row.get(k) is True for k in ["passed", "actual_component_call_executed", "input_type_ieee_unchanged", "original_A_type_ieee_unchanged", "native_node_count_unchanged"])
                                 and row.get("actual_code") == expected[key]["expected_code"]
                                 and row.get("input_type_ieee_sha256_before") == row.get("input_type_ieee_sha256_after")
                                 and re.fullmatch(r"[0-9a-f]{64}", row.get("input_type_ieee_sha256_before", "")),
                                 "component actual unchanged typed input/refusal missing")
                    base.require(row.get("native_node_count_before") == row.get("native_node_count_after"), "component actual native Node allocation changed")
                positives = data.get("positives")
                base.require(isinstance(positives, list) and len(positives) == 8
                             and {(r.get("id"), r.get("route")) for r in positives} == {(r["id"], r["route"]) for r in interface["required_positives"]}
                             and all(r.get("passed") is True for r in positives), "component actual original positives missing or fabricated")
                self.verify_manifest_sources(data, manifest, manifest_path); self.verify_sources(data, "component")
                self.verify_evidence(data); self.verify_owned_scope(scope, handoff, fixture)
                self.record_negative(variant + "/component", step, report_path, 362)
            self.native_phase("component_negative_" + variant, ["--headless", interface["scene_resource"]], env, 1200, validate)

        def run_live_negatives(self, variant):
            interface = self.interfaces["capture"]; fixture = self.frozen_a[variant]
            for index, (case, expected_code) in enumerate(interface["required_cases"].items()):
                group = self.new_group("live_" + variant + "_" + str(index).zfill(2)); self.activate_group(group)
                scope, handoff = self.own_a_profile(group, fixture)
                manifest_path = self.output / "actual_A_manifest.json"
                manifest = self.actual_manifest(interface, fixture, manifest_path, True)
                out = self.output / "capture"; report_path = out / "report.json"; nonce = uuid.uuid4().hex
                env = self.env.copy()
                env.update(DAMING_CAPTURE_PROFILE=str(self.profile), DAMING_CAPTURE_OUT=str(out),
                           DAMING_CAPTURE_CASE=case, DAMING_CAPTURE_MANIFEST=str(manifest_path),
                           DAMING_CAPTURE_MANIFEST_SHA256=sha(manifest_path), DAMING_CAPTURE_NONCE=nonce,
                           DAMING_CAPTURE_EXPECT_CONTENT=self.installed["content_version"],
                           DAMING_CAPTURE_EXPECT_ENGINE=self.receipt["godot_sha256"], DAMING_ADMIT_NONCE=nonce)
                def validate(step, log, case=case, expected_code=expected_code):
                    data = base.read(report_path)
                    self.claim_negative(step, data, fixture, nonce, "DAMING_SAFE_CAPTURE_V25_COMPLETE " + case, log)
                    base.require(data.get("schema") == interface["report_schema"] and data.get("case") == case
                                 and all(data.get(k) is True for k in ["row_completed", "actual_Core_capture_called", "actual_live_object_capture", "successful_handoff_owned_world_tracked"])
                                 and data.get("harness_revision") == "v25d1" and data.get("planned_cases") == 24
                                 and data.get("live_cast_cases_implemented") == 5, "actual d1 full24 live capture row absent")
                    for key in ["whole_live_capture_matrix_qualified", "overall_v25_qualified", "separate_component_harness_implemented", "native_log_zero_ERROR_verified"]:
                        base.require(data.get(key) is False, "single live row claimed aggregate/wider scope")
                    for key in ["disk_slot_writes", "gameplay_ticks_injected", "grid_clears", "runtime_patches"]:
                        base.require(type(data.get(key)) is int and data[key] == 0, "live row mutation scope violated")
                    row = data.get("executed_live_row")
                    base.require(isinstance(row, dict) and set(interface["required_row_fields"]) <= set(row)
                                 and row.get("case") == case and row.get("first_role") == fixture["first_role"]
                                 and row.get("expected_code") == row.get("actual_code") == expected_code
                                 and row.get("DTO_substitution") is False, "actual live row precise source/code missing")
                    for key in ["passed", "actual_Core_capture_called", "single_live_field_applied",
                                "temporary_field_unchanged_by_capture", "original_field_type_ieee_restored",
                                "retained_identity_same_live_unchanged", "source_held_no_ticks_no_nodes_added"]:
                        base.require(row.get(key) is True, "live full source/identity/no-tick restoration missing")
                    if case.startswith("safe_caster_"):
                        array = case.removeprefix("safe_caster_")
                        base.require(row.get("cast_component_capture_called") is True and row.get("cast_component_capture_accepted") is True
                                     and row.get("expected_guard_layer") == row.get("actual_guard_layer") == "level8_safe_pair"
                                     and row.get("actual_section") == row.get("actual_pair_array") == row.get("expected_pair_array") == array
                                     and row.get("direct_safe_cast_pair_coverage") is True
                                     and re.fullmatch(r"[1-9][0-9]*", row.get("actual_caster_object_id", "")),
                                     "actual live array component acceptance and pair section proof missing")
                    self.validate_retreat_hold_lifecycle(data, CASES[2])
                    self.verify_manifest_sources(data, manifest, manifest_path); self.verify_sources(data, "capture")
                    self.verify_evidence(data); self.verify_owned_scope(scope, handoff, fixture)
                    self.record_negative(variant + "/capture/" + case, step, report_path, 1)
                self.native_phase("live_capture_" + variant + "_" + case, ["--headless", interface["scene_resource"]], env, 600, validate)

        def run_negatives(self, variant):
            self.run_world_dto_negatives(variant)
            self.run_component_negatives(variant)
            self.run_live_negatives(variant)

        def execute(self):
            base.Runner.execute(self)
            self.receipt["complete"] = False
            for row in self.reports.values():
                base.require(row["pid"] not in self.execution_pids and row["nonce"] not in self.execution_nonces, "original PID/nonce reused")
                self.execution_pids.add(row["pid"]); self.execution_nonces.add(row["nonce"])
            for variant in VARIANTS:
                group = self.new_group(variant); self.activate_group(group)
                nonce = uuid.uuid4().hex; env = self.env.copy()
                env.update(DAMING_RETREAT_PROFILE=str(self.profile / "mismatch"), DAMING_RETREAT_CASE=CASES[0],
                           DAMING_RETREAT_FIRST_ROLE=VARIANTS[variant], DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                def guarded(step, log):
                    base.require(step.get("exit_code") == 2 and step.get("process_terminal") is True
                                 and "DAMING_RETREAT PRIVATE_PROFILE_REQUIRED" in log
                                 and not (self.output / CASES[0]).exists()
                                 and not list((self.profile / "appdata").rglob("handoff_A.json")), "full actual profile guard failed")
                self.native_phase(variant + "_profile_guard", ["--headless", "res://tools/" + self.args.retreat_scene.name], env, 300, guarded)
                for case in CASES:
                    self.activate_group(group); nonce = uuid.uuid4().hex; env = self.env.copy()
                    env.update(DAMING_RETREAT_CASE=case, DAMING_RETREAT_FIRST_ROLE=VARIANTS[variant],
                               DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                    self.native_phase(variant + "_" + case,
                        ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                         "--resolution", "1280x720", "--position", "30000,30000", "res://tools/" + self.args.retreat_scene.name],
                        env, 1200 if case == CASES[0] else 600,
                        lambda step, log, v=variant, c=case: self.validate_retreat_case(v, c, step, log))
                    if case == CASES[0]:
                        self.freeze_actual_a(variant)
                        self.run_negatives(variant)
            with self.stage("full_exact_matrices_source_native_terminal_profile_audit") as step:
                self.input_integrity(True)
                for row in self.receipt["steps"]:
                    if row.get("log"):
                        path = base.no_reparse(Path(row["log"]))
                        clean = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", path.read_text(encoding="utf-8", errors="replace"))
                        base.require(not re.search(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)", clean), "full ANSI-stripped original/route native error")
                base.require(set(self.retreat_reports) == {(v, c) for v in VARIANTS for c in CASES}, "eight natural cases missing")
                wanted = {v + "/" + k for v in VARIANTS for k in ["world", "component"]}
                wanted |= {v + "/capture/" + c for v in VARIANTS for c in self.interfaces["capture"]["required_cases"]}
                base.require(set(self.receipt.get("negative_reports", {})) == wanted and len(wanted) == 52, "full exact source stage set incomplete")
                profiles = []
                for name, group in self.profile_groups.items():
                    for path in sorted(group["profile"].rglob("*")):
                        path = base.no_reparse(path)
                        if path.is_file():
                            profiles.append({"group": name, "path": str(path), "bytes": path.stat().st_size, "sha256": sha(path)})
                path = self.run / "all_isolated_full_profiles_manifest.json"
                base.dump_new(path, profiles)
                self.receipt.update(complete=True, overall_v25_qualified=True, all_negatives_qualified=True,
                    natural_victory_qualified=True, local_terminal_once_qualified=True,
                    campaign_persistence_qualified=False, main_gameplay_processes=11,
                    actual_live_capture_native_cases=48, actual_component_rows=724, actual_world_DTO_rows=528,
                    actual_observed_case_processes=len(self.execution_pids),
                    all_isolated_profile_manifest_sha256=sha(path),
                    scope="Exact implemented v25 fixed matrices plus both natural save/continue/local-terminal variants. This does not qualify public continue entry, Campaign durable progression outside CAMPAIGN_QA, Android, Steam credited rewards or release.")
                step.update(profile_groups=len(self.profile_groups), profile_files=len(profiles), fixed_negative_stages=52)
    return Full


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt",
                 "cached-native-world", "candidate-receipt", "boundary-harness", "boundary-manifest",
                 "adapter-review", "runner-review", "deadline-utc"]:
        parser.add_argument("--" + name, type=str if name == "deadline-utc" else Path, required=True)
    here = Path(__file__).resolve().parent
    defaults = {"explorer": here / "run_daming_safe_retreat_v25s_r2a_explore.py",
                "base-producer": Path("E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py"),
                "parent-producer": here / "run_daming_safe_retreat_v25s.py",
                "retreat-runner": here / "daming_safe_retreat_cross_process_v25s1.gd",
                "retreat-scene": here / "daming_safe_retreat_cross_process_v25s1.tscn",
                "retreat-route": here / "daming_safe_retreat_route_v25.gd",
                "capture-base": here / "daming_safe_retreat_cross_process_v25.gd",
                "capture-base-scene": here / "daming_safe_retreat_cross_process_v25.tscn",
                "negative-matrix": here / "ADAPTER_BUNDLE_MATRIX_V25S_R2B.json",
                "passed-admit-successor-proof": here / "PASSED_SUCCESSOR_PROOF_V25S_ACTUAL_2A817E70.json",
                "proof-repository-root": Path("E:/ChatGPT/水浒"),
                "world-interface": here / "NEGATIVE_WORLD_INTERFACE_V25B2.json",
                "component-interface": here / "COMPONENT_NEGATIVE_INTERFACE_V25.json",
                "capture-interface": here / "CAPTURE_NEGATIVE_INTERFACE_V25D1.json",
                "negative-successor-review": here / "NEGATIVE_SUCCESSOR_REVIEW_V25.json",
                "component-review": here / "COMPONENT_NEGATIVE_PEER_REVIEW_V25_IMPLEMENTED_CANDIDATE.json",
                "capture-review": here / "CAPTURE_NEGATIVE_PEER_REVIEW_V25D1.json"}
    for name, value in defaults.items():
        parser.add_argument("--" + name, type=Path, default=value)
    parser.add_argument("--prior-pid", type=int)
    args = parser.parse_args()
    args.stage = "full"
    try:
        args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
        require(args.deadline_utc.tzinfo is not None and args.deadline_utc <= DEADLINE
                and dt.datetime.now(dt.timezone.utc) < args.deadline_utc, "authorized six-am deadline invalid/reached")
        for key, value in vars(args).items():
            if isinstance(value, Path):
                setattr(args, key, absolute(value))
        reviewed, matrix, interfaces, extra = preflight(args)
        require(args.source_root.is_dir() and (args.source_root / "project.godot").is_file()
                and not args.work_root.is_relative_to(args.source_root), "full source/work root invalid")
        # Proof remains read-only and no base/import batch exists at this point.
        proof = read(args.passed_admit_successor_proof)
        require(proof.get("schema") == "daming_admit_passed_successor_proof_v2_portable"
                and proof.get("complete") is True and proof.get("full_admit_ABC_native_qualified") is True,
                "actual closed successor proof missing")
    except (PrerequisiteBlocked, OSError, KeyError, TypeError, ValueError) as exc:
        print(json.dumps({"status": "BLOCKED", "complete": False, "engine_batch_created": False,
                          "engine_started": False, "reason": str(exc)}, ensure_ascii=False), flush=True)
        return 2
    # Pin-defined modules are imported only after concrete full-scope review.
    explorer = import_pinned(args.explorer, EXPLORER_SHA, "immutable_r2a_for_full")
    explorer.portable_successor(args)  # full actual bytes/process/log proof before mkdir/import base
    parent = import_pinned(args.parent_producer, PARENT_SHA, "immutable_v25s_parent_for_full")
    base = parent.load_base(args.base_producer)
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("v25_full_" + uuid.uuid4().hex[:8])
    run.mkdir(exist_ok=False)
    runner = runner_class(base, parent, explorer)(args, run, reviewed, matrix, interfaces, extra)
    code = 0
    try:
        runner.execute()
    except BaseException as exc:
        code = 1
        runner.receipt["complete"] = False
        runner.receipt["overall_v25_qualified"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        for action in [runner.stop_owned, runner.release]:
            try:
                action()
            except BaseException as exc:
                code = 1; runner.receipt["complete"] = False
                runner.receipt["overall_v25_qualified"] = False
                runner.receipt.setdefault("finalization_failures", []).append({"type": type(exc).__name__, "message": str(exc)})
        try:
            runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            code = 1; runner.receipt["lock_released"] = False
            runner.receipt["lock_audit_failure"] = str(exc)
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["overall_v25_qualified"] = runner.receipt["overall_v25_qualified"] and runner.receipt["complete"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        base.dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"],
                          "overall_v25_qualified": runner.receipt["overall_v25_qualified"],
                          "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
