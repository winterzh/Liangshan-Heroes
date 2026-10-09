"""UNEXECUTED immutable r2a explorer: original regressions and actual A only.

Reuse the immutable v24s base and immutable v25s parent freeze/identity/packet/
clock/terminal validators. Exploration does not claim full qualification.
Full consumers do not exist in THIS immutable explorer. A separately reviewed
v25d/full adapter succeeds it; its source availability is not a scope waiver.
Only AST/source review is performed during preparation; Root approves startup.
"""
from __future__ import annotations

import argparse
import ast
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import uuid

sys.dont_write_bytecode = True
BASE_SHA = "049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626"
PARENT_SHA = "5941315849982fb73d4851c2fcb95a2369d498760a83801427d315dd6a229af5"
DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
CASES = ("A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal")
VARIANTS = {"lu_first": "lu", "shi_first": "shi"}
FULL_CONSUMERS_IMPLEMENTED_IN_THIS_EXPLORER = False
TOOL_PINS = {
    "world": ("daming_safe_retreat_negative_world_bundle_v25b2", "bc494c0bdabd1c52726f4f12465154529ed3cc9cee75042543d1872e11959b5d", "113eb68bde983102e92eb99b14d9537d968daa2516e8fc734808d03bdd30ccf0"),
    "capture": ("daming_safe_retreat_capture_bundle_v25c", "76f408d298db07cd12c9aa628465be60102628a60d4bad3d1a4f91c9bf43a3f7", "2128bcff8e4c87062034766d9a49a27469cc33a6ab67c2ef7a092f257b7d8d08"),
    "component": ("daming_safe_retreat_component_bundle_v25", "ccb4abd78fe1277c2475f53ace9ff4c5c133e1e8ca4ebb59fa6ac30c65ab134a", "46adcee78872917b6518dc186ba1a055ff3bf00694835b723e51447282ba22fc"),
}
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
ENGINE_ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")


class PrerequisiteBlocked(RuntimeError):
    pass


def require(value, text):
    if not value:
        raise PrerequisiteBlocked(text)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def absolute(path):
    p = Path(path)
    require(p.is_absolute(), "absolute input path required")
    for q in [p, *p.parents]:
        if q.exists() or q.is_symlink():
            st = q.lstat()
            require(not q.is_symlink() and not getattr(st, "st_file_attributes", 0) & 0x400,
                    "reparse/link input refused: " + str(q))
    return p.resolve()


def pin(row):
    require(isinstance(row, dict) and type(row.get("bytes")) is int and row["bytes"] > 0
            and isinstance(row.get("sha256"), str) and HEX64.fullmatch(row["sha256"]), "pin shape invalid")
    p = absolute(row["path"])
    require(p.is_file() and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"], "pinned input drift: " + str(p))
    return p


def repo_pin(root, row):
    rel = Path(row["repository_relative_path"])
    require(not rel.is_absolute() and ".." not in rel.parts, "portable evidence path escaped repository")
    p = absolute(root / rel)
    require(p.is_relative_to(root), "portable evidence outside proof repository")
    return pin({"path": str(p), "bytes": row["bytes"], "sha256": row["sha256"]})


def method_sha(path):
    text = Path(path).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    match = re.search(r"(?ms)^func _hold\(.*?(?=^func |\Z)", text)
    require(match is not None, "actual qualified hold missing")
    return hashlib.sha256((match.group(0).rstrip() + "\n").encode()).hexdigest()


def portable_successor(args):
    proof = read(args.passed_admit_successor_proof)
    require(proof.get("schema") == "daming_admit_passed_successor_proof_v2_portable"
            and proof.get("complete") is True and proof.get("full_admit_ABC_native_qualified") is True
            and proof.get("template_only") is False, "actual closed s qualification proof required")
    root = absolute(args.proof_repository_root)
    paths = [args.passed_admit_successor_proof]
    summary_path = repo_pin(root, proof["qualified_summary_pin"])
    receipt_path = repo_pin(root, proof["receipt_pin"])
    harness = repo_pin(root, proof["harness_pin"])
    producer = repo_pin(root, proof["producer_pin"])
    paths += [summary_path, receipt_path, harness, producer]
    summary, batch = read(summary_path), read(receipt_path)
    require(summary.get("schema") == "daming_admission_native_continuation_qualified_v24s"
            and summary.get("complete") is True and summary.get("runtime_candidate_qualified") is True,
            "committed original s qualification summary absent")
    bridge = proof["source_archive_bridge"]
    require(isinstance(bridge, list) and len(bridge) == len(summary["files"]) and bridge,
            "actual archived source bridge count mismatch")
    norm = lambda s: s.replace("\\", "/").casefold()
    expected = {norm(r["original"]): r for r in summary["files"]}
    mapped = {}
    for row in bridge:
        key = norm(row["original_recorded_path"])
        require(key in expected and key not in mapped, "portable original evidence alias/missing row")
        old = expected[key]
        require(row["repository_relative_path"] == old["path"] and row["sha256"] == old["sha256"]
                and row["bytes"] == old["bytes"], "portable bridge altered raw original source identity")
        mapped[key] = repo_pin(root, row)
        paths.append(mapped[key])
    def resolved(original, digest):
        require(norm(original) in mapped, "original evidence not captured by exact archive bridge")
        path = mapped[norm(original)]
        require(sha(path) == digest, "archived original evidence SHA changed")
        return path
    require(batch.get("complete") is True and batch.get("lock_released") is True
            and batch.get("producer_sha256") == BASE_SHA and sha(producer) == BASE_SHA
            and batch.get("installed_identity", {}).get("file_count") == 5102
            and len(batch.get("source_files", [])) == 5041 and batch.get("private_runtime_patches") == 0
            and all(batch.get(k) == 0 for k in ["root_input_drift", "private_input_drift", "source_native_drift", "private_native_drift"])
            and batch.get("godot_sha256") == sha(args.godot), "original closed s source/runtime/engine audit invalid")
    cases = ("A_half_save", "B_continue_resave", "C_verify_resave")
    require(set(batch.get("reports", {})) == set(cases), "original ABC process set incomplete")
    pids, nonces, previous = set(), set(), None
    for case in cases:
        row = batch["reports"][case]
        report = read(resolved(row["report"], row["report_sha256"]))
        require(report.get("case") == case and report.get("passed") is True and report.get("checks")
                and all(c.get("passed") is True for c in report["checks"])
                and report.get("pid") == row["pid"] and report.get("nonce") == row["nonce"]
                and row["pid"] not in pids and row["nonce"] not in nonces, "actual archived native ABC report/PID/checks invalid")
        steps = [s for s in batch["steps"] if s.get("case") == case and s.get("pid") == row["pid"]]
        require(len(steps) == 1, "original unique native step absent")
        step = steps[0]
        log = resolved(step["log"], step["log_sha256"])
        require(step.get("exit_code") == 0 and step.get("process_terminal") is True and not step.get("stop_reason")
                and not ENGINE_ERRORS.search(log.read_text(encoding="utf-8", errors="replace")), "original native ABC log/terminal failed")
        if previous:
            require(previous["native_finished_ns"] <= step["native_started_ns"], "original ABC processes overlapped")
        pids.add(row["pid"]); nonces.add(row["nonce"]); previous = step
    qualified_sha = sha(harness)
    require(any(r.get("path") == "tools/daming_admit_cross_process_v24s.gd" and r.get("sha256") == qualified_sha
                for r in batch.get("added_qa_files", []))
            and any(Path(r["path"]).name == harness.name and r.get("sha256") == qualified_sha
                    for r in batch.get("helper_and_proposal_files", [])), "original actual frozen s harness pin absent")
    require(sha(args.base_producer.with_name(harness.name)) == qualified_sha
            and method_sha(harness) == proof["qualified_hold_method_lf_sha256"] == method_sha(args.retreat_runner),
            "actual future base or retreat still has old hold method")
    return proof, paths


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def check_prerequisites(args):
    """No import base/parent, mkdir batch, wait or engine before this read-only gate."""
    require(sha(args.base_producer) == BASE_SHA and sha(args.parent_producer) == PARENT_SHA, "immutable base/parent producer drift")
    ast.parse(args.base_producer.read_text(encoding="utf-8-sig"))
    ast.parse(args.parent_producer.read_text(encoding="utf-8-sig"))
    proof, proof_paths = portable_successor(args)
    review = read(args.runner_review)
    require(review.get("schema") == "daming_safe_retreat_runner_cross_review_v25"
            and review.get("review_status") == "static_api_closure_no_identified_execution_blocker_native_pending",
            "actual new v25s runner/route independent review missing")
    reviewed = {pin(r) for r in review["candidate_pins"]}
    require({args.retreat_runner, args.retreat_scene, args.retreat_route} <= reviewed,
            "new corrected runner/scene/route not covered by exact review pins")
    approval = read(args.adapter_review)
    require(approval.get("schema") == "daming_safe_retreat_adapter_review_v25s_r2"
            and approval.get("static_api_closure_passed") is True
            and pin(approval["producer_pin"]) == Path(__file__).resolve()
            and args.stage in approval.get("approved_stages", []), "Root independent adapter review/stage approval missing")
    interfaces = {}
    harnesses = []
    for kind in ["world", "capture", "component"]:
        path = getattr(args, kind + "_interface")
        data = read(path); schema, gd_sha, scene_sha = TOOL_PINS[kind]
        require(data.get("schema") == schema and data["harness"]["sha256"] == gd_sha
                and data["scene"]["sha256"] == scene_sha, "new exact " + kind + " tool API drift")
        gd, scene = pin(data["harness"]), pin(data["scene"])
        require('type="Script" path="res://tools/' + gd.name + '"' in scene.read_text(encoding="utf-8-sig"),
                "actual reviewed scene does not bind its GD")
        interfaces[kind] = data
        harnesses.append({"id": kind, "gd": str(gd), "scene": str(scene)})
    rows = interfaces["world"]["route_expectations"]
    require(len(rows) == 264 and len({(r["case"], r["route"]) for r in rows}) == 264
            and sum(r["core_prepare_called"] is False for r in rows) == 18, "b2 exact canonical/Core matrix drift")
    require(len(interfaces["capture"]["required_cases"]) == 19
            and len(interfaces["component"]["required_route_rows"]) == 362, "component/live exact matrix drift")
    if args.stage != "a_fixture_exploration":
        # Flags or a review JSON cannot substitute source that has not been built.
        require(FULL_CONSUMERS_IMPLEMENTED_IN_THIS_EXPLORER, "FULL_V25_BLOCKED_R2A_EXPLORER_HAS_NO_REVIEWED_FULL_CONSUMERS")
        successor = read(args.negative_successor_review)
        require(successor.get("static_closure_passed_for_targeted_successor_changes") is True, "b2/c independent source closure absent")
        component = read(args.component_review)
        require(component.get("schema") == "daming_safe_retreat_component_peer_review_v25"
                and component.get("static_api_closure_passed") is True
                and pin(component["harness_pin"]) == pin(interfaces["component"]["harness"]),
                "independent component API peer closure missing")
    matrix = {"harnesses": [] if args.stage == "a_fixture_exploration" else harnesses, "pins": []}
    paths = [args.parent_producer, args.base_producer, args.runner_review, args.adapter_review,
             args.retreat_runner, args.retreat_scene, args.retreat_route, args.world_interface,
             args.capture_interface, args.component_interface, args.capture_base, *proof_paths]
    if args.stage != "a_fixture_exploration":
        paths += [args.negative_successor_review, args.component_review]
    for data in interfaces.values():
        paths += [pin(data["harness"]), pin(data["scene"])]
    require(sha(args.capture_base) == "6a70e00e6a7786bdf8791b84e3fdfdbe85159bf5398ec8ab385f2e34a3242940", "explicit capture inherited base drift")
    return review, matrix, interfaces, sorted(set(paths))


def adapter_class(base, parent):
    ParentRunner = parent.runner_class(base)

    class Adapter(ParentRunner):
        def __init__(self, args, run, reviewed, matrix, interfaces, extra_pins):
            super().__init__(args, run, reviewed, matrix)
            self.interfaces, self.extra_pins = interfaces, extra_pins
            self.frozen_a = {}
            self.receipt.update(schema="daming_safe_retreat_adapter_batch_v25s_r2",
                                producer_sha256=sha(Path(__file__)),
                                parent_producer_sha256=PARENT_SHA, execution_scope=args.stage,
                                overall_v25_qualified=False, actual_A_fixture_exploration_complete=False,
                                unconsumed_live_cast_cases_in_this_explorer=5, all_negatives_qualified=False,
                                full_matrix_consumer_implemented=False,
                                scope="Explicit scoped actual-A exploration or complete suite; a scoped completion cannot qualify the whole feature.")

        def preflight(self):
            check_prerequisites(self.args)
            # Preserve original rigor but replace the superseded parent gate for
            # its unfinished two-tool API. select_candidate6 is inherited intact.
            base.Runner.preflight(self)
            missing = parent.producer_required_native_labels() - parent.source_proven_native_labels(self.args.retreat_runner, self.args.retreat_route)
            base.require(not missing, "new runner mandatory exact native labels missing: " + str(sorted(missing)))
            for p in [Path(__file__).resolve(), self.args.negative_matrix, *self.extra_pins]:
                self.code_pins[str(p)] = sha(p)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": digest} for p, digest in self.code_pins.items()]
            self.receipt["source_proven_mandatory_native_labels"] = sorted(parent.producer_required_native_labels())
            self.receipt["targeted_negative_interfaces"] = {k: v["schema"] for k, v in self.interfaces.items()}
            self.receipt["tool_dependency_closure"] = parent.reviewed_tool_dependency_closure(self.args, self.matrix)
            self.input_integrity()

        def prepare(self):
            super().prepare()  # complete actual freeze/guards; never private patch
            if self.args.stage != "a_fixture_exploration":
                target = self.project / "tools" / self.args.capture_base.name
                base.require(not target.exists(), "capture inherited base filename collision")
                self.copy_checked(self.args.capture_base, target, self.code_pins[str(self.args.capture_base)])
                self.receipt["added_qa_files"].append({"path": "tools/" + target.name,
                    "bytes": target.stat().st_size, "sha256": sha(target), "kind": "explicit immutable capture inheritance source outside runtime"})
                base.require(base.installed_identity(self.project) == self.installed and self.installed["file_count"] == 5102,
                             "QA inheritance source changed full runtime identity")
                self.input_integrity(True)

        def new_group(self, name):
            group = super().new_group(name)
            for key in list(group["env"]):
                if key.startswith(("DAMING_CAPTURE_", "DAMING_COMPONENT_", "DAMING_NEGATIVE_")):
                    group["env"].pop(key)
            return group

        def freeze_actual_a(self, variant):
            """After actual A process terminal0, before any B save; exact raw bytes."""
            a = self.retreat_reports[(variant, CASES[0])]
            files = self.negative_inputs(variant)
            report = base.read(files["report"]["path"])
            user = self.userdata(report)
            slot_scope = base.no_reparse(user / "daming_safe_retreat_v25/continue/v1")
            target = self.run / "frozen_actual_A" / variant
            target.mkdir(parents=True, exist_ok=False)
            frozen = {}
            for name, row in files.items():
                source = base.no_reparse(Path(row["path"]))
                base.require(source.is_relative_to(self.run) and sha(source) == row["sha256"], "actual A input changed/escaped")
                copy = target / (name + ".json")
                self.copy_checked(source, copy, row["sha256"])
                frozen[name] = {"path": str(copy), "sha256": row["sha256"], "bytes": copy.stat().st_size,
                                "original_actual_A_path": str(source)}
                self.code_pins[str(copy)] = row["sha256"]
            profile_files = []
            for source in sorted(slot_scope.rglob("*")):
                source = base.no_reparse(source)
                if not source.is_file():
                    continue
                relative = source.relative_to(slot_scope).as_posix()
                digest = sha(source)
                copy = target / "slot_scope" / relative
                copy.parent.mkdir(parents=True, exist_ok=True)
                self.copy_checked(source, copy, digest)
                profile_files.append({"path": str(copy), "sha256": digest, "bytes": copy.stat().st_size,
                                      "relative": relative, "original_actual_A_path": str(source)})
                self.code_pins[str(copy)] = digest
            base.require(profile_files and any(r["relative"].startswith("local_runs/") for r in profile_files),
                         "actual A original local journal absent")
            token = a["slot"]["document"]["binding"]["token"]
            journal = slot_scope / "local_runs" / token / "5088120/1/record_0000000001.json"
            active = self.disk_envelope(journal, "LH_LOCAL_CONTINUE_LIFECYCLE", 1, "0" * 64)
            base.require(active["sha256"] == a["slot"]["document"]["binding"]["receipt_sha256"]
                         and active["document"]["token"] == token and active["document"]["state"] == "active"
                         and active["document"]["victory"] is False
                         and active["document"]["context"] == {"mode": "defense", "level_id": "", "waves": 30},
                         "actual original local default-context journal binding failed")
            record = {"schema": "daming_actual_A_frozen_source_v25s_r2", "first_role": VARIANTS[variant],
                      "inputs": frozen, "profile_files": profile_files,
                      "actual_A_pid": a["pid"], "actual_A_nonce": a["nonce"], "actual_A_finished_ns": a["finished_ns"],
                      "user_suffix_under_appdata": user.relative_to(self.profile / "appdata").as_posix(),
                      "content_version": self.installed["content_version"], "engine_sha256": self.receipt["godot_sha256"],
                      "scope": "Original actual A full packet/world/slot/handoff/report and closed entire slot+local journal only; no whole player/cache/profile copying."}
            path = target / "index.json"
            base.dump_new(path, record)
            self.code_pins[str(path)] = sha(path)
            self.frozen_a[variant] = record
            self.receipt.setdefault("actual_A_fixtures", {})[variant] = {"path": str(path), "sha256": sha(path),
                "actual_A_pid": a["pid"], "actual_A_nonce": a["nonce"], "profile_files": len(profile_files)}
            self.input_integrity(True)
            return record

        def own_a_profile(self, group, fixture):
            user = group["profile"] / "appdata" / fixture["user_suffix_under_appdata"]
            scope = user / "daming_safe_retreat_v25/continue/v1"
            for row in fixture["profile_files"]:
                destination = scope / base.relative_path(row["relative"])
                destination.parent.mkdir(parents=True, exist_ok=True)
                base.require(not destination.exists(), "new owned A profile alias")
                self.copy_checked(Path(row["path"]), destination, row["sha256"])
            handoff = user / "daming_safe_retreat_v25/handoff_A.json"
            handoff.parent.mkdir(parents=True, exist_ok=True)
            self.copy_checked(Path(fixture["inputs"]["handoff"]["path"]), handoff,
                              fixture["inputs"]["handoff"]["sha256"])
            return scope, handoff

        def actual_manifest(self, interface, fixture, path, full_profile):
            names = {"report": "a_report", "handoff": "a_handoff", "packet": "a_packet", "world": "a_world", "slot": "a_slot"}
            doc = {"schema": interface["manifest_schema"], "first_role": fixture["first_role"],
                   "content_version": self.installed["content_version"], "engine_sha256": self.receipt["godot_sha256"]}
            for old, field in names.items():
                doc[field] = fixture["inputs"][old]
            if full_profile:
                doc["profile_files"] = fixture["profile_files"]
            if interface["schema"] == TOOL_PINS["component"][0]:
                doc["source_pins"] = {p: sha(self.project / base.relative_path(p.removeprefix("res://")))
                                      for p in interface["required_source_paths"]}
            base.dump_new(path, doc)
            self.code_pins[str(path)] = sha(path)
            return doc

        def claim_negative(self, step, report, fixture, nonce, marker, log):
            base.require(step.get("exit_code") == 0 and step.get("process_terminal") is True
                         and not ENGINE_ERRORS.search(log) and marker in log, "negative actual native terminal/log/marker failed")
            pid = step["pid"]
            base.require(type(pid) is int and report.get("pid") == pid and report.get("nonce") == nonce
                         and pid not in self.execution_pids and nonce not in self.execution_nonces
                         and fixture["actual_A_finished_ns"] <= step["native_started_ns"],
                         "negative actual A/native process chain reused/overlapped")
            self.execution_pids.add(pid); self.execution_nonces.add(nonce)
            base.require(report.get("first_role") == fixture["first_role"]
                         and report.get("content_version") == self.installed["content_version"]
                         and report.get("engine_sha256") == self.receipt["godot_sha256"]
                         and self.userdata(report).is_relative_to(self.profile / "appdata"),
                         "negative actual role/Provider/engine/profile mismatch")
            base.require(report.get("passed") is True and report.get("checks")
                         and all(c.get("passed") is True for c in report["checks"]), "negative actual checks failed/incomplete")

        def verify_manifest_sources(self, data, manifest, manifest_path):
            labels = {(r.get("label"), r.get("sha256")) for r in data.get("provenance", [])}
            for field in ["a_report", "a_handoff", "a_packet", "a_world", "a_slot"]:
                base.require((field, manifest[field]["sha256"]) in labels
                             and sha(manifest[field]["path"]) == manifest[field]["sha256"],
                             "negative actual original A input provenance/drift")
            base.require(sha(manifest_path) == self.code_pins[str(manifest_path)], "actual negative manifest drift")

        def verify_sources(self, data, kind):
            interface = self.interfaces[kind]
            base.require(data.get("harness_sha256") == interface["harness"]["sha256"], "actual negative harness pin differs")
            rows = data.get("source_files") if kind == "world" else data.get("source_pins")
            if kind == "capture":
                # capture inherited content identity is complete; explicit
                # schema's source pin is the immutable base plus all A sources.
                base.require(data.get("base_harness_sha256") == sha(self.args.capture_base), "actual capture inherited base differs")
                return
            if isinstance(rows, dict):
                rows = [{"path": p, "sha256": digest} for p, digest in rows.items()]
            expected_paths = interface["required_source_paths"] if kind == "component" else [
                "res://scripts/" + name for name in ["run_battle_world_core.gd", "run_level8_unit_contract.gd", "run_slot_store.gd", "run_snapshot_store.gd", "run_unit_graph.gd", "run_unit_state.gd", "run_graph_identity.gd", "run_battle_root_state.gd", "run_campaign_level_state.gd", "run_campaign_mission_state.gd", "run_campaign_presentation_state.gd", "run_cast_flow_state.gd", "run_item_cast_flow_state.gd", "run_state_value_codec.gd"]]
            base.require(isinstance(rows, list) and len(rows) == len(expected_paths)
                         and {r["path"] for r in rows} == set(expected_paths), "actual complete module source pin set missing")
            for row in rows:
                base.require(row["path"].startswith("res://")
                             and sha(self.project / base.relative_path(row["path"].removeprefix("res://"))) == row["sha256"],
                             "actual module source drift")

        def verify_owned_scope(self, scope, handoff, fixture):
            actual = {}
            for path in scope.rglob("*"):
                path = base.no_reparse(path)
                if path.is_file():
                    actual[path.relative_to(scope).as_posix()] = sha(path)
            base.require(actual == {r["relative"]: r["sha256"] for r in fixture["profile_files"]}
                         and sha(handoff) == fixture["inputs"]["handoff"]["sha256"],
                         "owned actual A original slot/journal/handoff changed")

        def run_world_dto_negatives(self, variant):
            interface = self.interfaces["world"]; fixture = self.frozen_a[variant]
            group = self.new_group("world_" + variant); self.activate_group(group)
            manifest_path = self.output / "actual_A_manifest.json"
            manifest = self.actual_manifest(interface, fixture, manifest_path, False)
            report_path = self.output / "report.json"; nonce = uuid.uuid4().hex
            env = self.env.copy()
            env.update(DAMING_NEGATIVE_PROFILE=str(self.profile), DAMING_NEGATIVE_REPORT=str(report_path),
                       DAMING_NEGATIVE_MANIFEST=str(manifest_path), DAMING_NEGATIVE_MANIFEST_SHA256=sha(manifest_path),
                       DAMING_NEGATIVE_NONCE=nonce, DAMING_NEGATIVE_EXPECT_CONTENT=self.installed["content_version"],
                       DAMING_NEGATIVE_EXPECT_ENGINE=self.receipt["godot_sha256"], DAMING_ADMIT_NONCE=nonce)
            def validate(step, log):
                data = base.read(report_path)
                self.claim_negative(step, data, fixture, nonce, "DAMING_SAFE_NEGATIVE_WORLD_V25_COMPLETE ", log)
                base.require(data.get("schema") == interface["report_schema"]
                             and all(data.get(k) is True for k in ["pure_matrix_passed", "fixture_ready", "matrix_complete"])
                             and data.get("whole_world_dto_negative_only") is True, "world DTO scope/matrix missing")
                for k in ["overall_v25_qualified", "live_object_capture_negative_implemented", "live_object_capture_negative_qualified", "separate_component_harness_implemented", "future_producer_integration_qualified"]:
                    base.require(data.get(k) is False, "DTO claimed another scope")
                base.require(all(type(data.get(k)) is int and data[k] == 0 for k in ["disk_slot_writes", "direct_gameplay_calls", "cached_grids_cleared"]), "DTO side effects claimed")
                expected = {(r["case"], r["route"]): r for r in interface["route_expectations"]}
                rows = data.get("executed_rows")
                base.require(isinstance(rows, list) and len(rows) == 264, "world exact264 rows absent")
                actual = {(r.get("case"), r.get("route")): r for r in rows}
                base.require(len(actual) == 264 and set(actual) == set(expected), "world duplicated/missing fixed routes")
                for key, row in actual.items():
                    for field, value in expected[key].items():
                        base.require(type(row.get(field)) is type(value) and row.get(field) == value, "world actual route layer/nullable observation mismatch: " + field)
                    base.require(row.get("passed") is True and row.get("actual_code") == expected[key]["expected_code"]
                                 and row.get("source_input_type_ieee_exact") is True and row.get("cached_grids_preserved") is True
                                 and HEX64.fullmatch(row.get("mutated_packet_sha256", ""))
                                 and HEX64.fullmatch(row.get("typed_document_sha256", "")), "world actual immutable source/code proof missing")
                positives = data.get("positives")
                base.require(isinstance(positives, list) and len(positives) == 2 and {r["route"] for r in positives} == {"source", "json"}
                             and all(all(r.get(k) is True for k in ["actual_A_unmodified", "prepared", "detached_inert", "input_exact"]) for r in positives),
                             "world actual A full original positive prepare not proven")
                self.verify_manifest_sources(data, manifest, manifest_path); self.verify_sources(data, "world")
                self.record_negative(variant + "/world", step, report_path, 264)
            self.native_phase("world_negative_" + variant, ["--headless", interface["scene_resource"]], env, 900, validate)

        def record_negative(self, key, step, path, rows):
            self.receipt.setdefault("negative_reports", {})[key] = {
                "path": str(path), "sha256": sha(path), "pid": step["pid"],
                "nonce": step["process_nonce"], "rows": rows, "overall_v25_qualified": False}
            step.update(report=str(path), report_sha256=sha(path), rows=rows)

        def execute(self):
            # Original JSON11/OwnedSlot/admit ABC and all source/native/packet
            # guards remain actual calls on this new complete six-file candidate.
            base.Runner.execute(self)
            self.receipt["complete"] = False
            self.receipt["original_candidate_admit_regressions_qualified"] = True
            for row in self.reports.values():
                base.require(row["pid"] not in self.execution_pids and row["nonce"] not in self.execution_nonces,
                             "original native PID/nonce reused")
                self.execution_pids.add(row["pid"]); self.execution_nonces.add(row["nonce"])
            base.require(self.args.stage == "a_fixture_exploration",
                         "r2a exploration source cannot execute full consumers; use a separately reviewed full successor")
            variants = list(VARIANTS) if self.args.exploration_role == "both" else [self.args.exploration_role]
            for variant in variants:
                group = self.new_group(variant); self.activate_group(group)
                nonce = uuid.uuid4().hex
                guard = self.env.copy()
                guard.update(DAMING_RETREAT_PROFILE=str(self.profile / "mismatch"), DAMING_RETREAT_CASE=CASES[0],
                             DAMING_RETREAT_FIRST_ROLE=VARIANTS[variant], DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                def guarded(step, log):
                    base.require(step.get("exit_code") == 2 and step.get("process_terminal") is True
                                 and "DAMING_RETREAT PRIVATE_PROFILE_REQUIRED" in log
                                 and not (self.output / CASES[0]).exists()
                                 and not list((self.profile / "appdata").rglob("handoff_A.json")),
                                 "actual A private-profile negative guard wrote case evidence")
                self.native_phase(variant + "_profile_guard", ["--headless", "res://tools/" + self.args.retreat_scene.name],
                                  guard, 300, guarded)
                self.activate_group(group)
                nonce = uuid.uuid4().hex
                env = self.env.copy()
                env.update(DAMING_RETREAT_CASE=CASES[0], DAMING_RETREAT_FIRST_ROLE=VARIANTS[variant],
                           DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                self.native_phase(variant + "_" + CASES[0],
                    ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                     "--resolution", "1280x720", "--position", "30000,30000", "res://tools/" + self.args.retreat_scene.name],
                    env, 1200, lambda step, log, v=variant: self.validate_retreat_case(v, CASES[0], step, log))
                self.freeze_actual_a(variant)
            with self.stage("actual_A_exploration_full_source_profiles_native_readback") as step:
                self.input_integrity(True)
                base.require(set(self.retreat_reports) == {(v, CASES[0]) for v in variants}
                             and set(self.frozen_a) == set(variants), "exploration actual exact A set incomplete")
                profiles = []
                for name, group in self.profile_groups.items():
                    for path in sorted(group["profile"].rglob("*")):
                        path = base.no_reparse(path)
                        if path.is_file():
                            profiles.append({"group": name, "path": str(path), "bytes": path.stat().st_size, "sha256": sha(path)})
                path = self.run / "actual_A_exploration_profile_manifest.json"
                base.dump_new(path, profiles)
                self.receipt.update(complete=True, actual_A_fixture_exploration_complete=True,
                    original_candidate_admit_regressions_qualified=True,
                    overall_v25_qualified=False, all_negatives_qualified=False,
                    natural_victory_qualified=False, local_terminal_once_qualified=False,
                    campaign_persistence_qualified=False, callback_invocation_count_qualified=False,
                    main_gameplay_processes=3 + len(variants), actual_A_roles=[VARIANTS[v] for v in variants],
                    actual_observed_case_processes=len(self.execution_pids),
                    exploration_profile_manifest_sha256=sha(path),
                    implementation_boundary="This scoped immutable r2a source executes original regressions plus genuine A only. It does not dispatch component/world/capture or B/C/D; their separate interfaces remain pinned source context, with no executed coverage claim.")
                step.update(profile_groups=len(self.profile_groups), profile_files=len(profiles), actual_A_cases=len(variants))
    return Adapter


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root",
                 "prior-receipt", "cached-native-world", "candidate-receipt", "boundary-harness", "boundary-manifest",
                 "runner-review", "adapter-review", "deadline-utc"]:
        parser.add_argument("--" + name, required=True, type=str if name == "deadline-utc" else Path)
    here = Path(__file__).resolve().parent
    defaults = {"base-producer": Path("E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py"),
                "parent-producer": here / "run_daming_safe_retreat_v25s.py",
                "retreat-runner": here / "daming_safe_retreat_cross_process_v25s.gd",
                "retreat-scene": here / "daming_safe_retreat_cross_process_v25s.tscn",
                "retreat-route": here / "daming_safe_retreat_route_v25.gd",
                "capture-base": here / "daming_safe_retreat_cross_process_v25.gd",
                "negative-matrix": here / "ADAPTER_BUNDLE_MATRIX_V25S_R2A.json",
                "passed-admit-successor-proof": here / "PASSED_SUCCESSOR_PROOF_V25S_ACTUAL_2A817E70.json",
                "proof-repository-root": Path("E:/ChatGPT/水浒"),
                "world-interface": here / "NEGATIVE_WORLD_INTERFACE_V25B2.json",
                "capture-interface": here / "CAPTURE_NEGATIVE_INTERFACE_V25C.json",
                "component-interface": here / "COMPONENT_NEGATIVE_INTERFACE_V25.json",
                "negative-successor-review": here / "NEGATIVE_SUCCESSOR_REVIEW_V25.json",
                "component-review": here / "COMPONENT_NEGATIVE_PEER_REVIEW_V25_IMPLEMENTED_CANDIDATE.json"}
    for name, default in defaults.items():
        parser.add_argument("--" + name, type=Path, default=default)
    parser.add_argument("--stage", choices=["a_fixture_exploration", "full"], default="a_fixture_exploration")
    parser.add_argument("--exploration-role", choices=["lu_first", "shi_first", "both"], default="lu_first")
    parser.add_argument("--prior-pid", type=int)
    args = parser.parse_args()
    try:
        args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
        require(args.deadline_utc.tzinfo is not None and args.deadline_utc <= DEADLINE
                and dt.datetime.now(dt.timezone.utc) < args.deadline_utc, "AUTHORIZED_SIX_AM_DEADLINE_INVALID_OR_REACHED")
        for key, value in vars(args).items():
            if isinstance(value, Path):
                setattr(args, key, absolute(value))
        reviewed, matrix, interfaces, extra = check_prerequisites(args)
        require(args.source_root.is_dir() and (args.source_root / "project.godot").is_file()
                and not args.work_root.is_relative_to(args.source_root), "source/work root scope invalid")
        require(args.negative_matrix.is_file(), "new scoped source bundle matrix missing")
    except (PrerequisiteBlocked, OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "BLOCKED", "complete": False, "engine_batch_created": False,
                          "engine_started": False, "reason": str(exc)}, ensure_ascii=False), flush=True)
        return 2
    # Only after every actual preflight guard and Root stage review is concrete.
    parent = load_module(args.parent_producer, "immutable_v25s_parent_for_r2a")
    base = parent.load_base(args.base_producer)
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("daming_safe_retreat_v25s_r2a_" + uuid.uuid4().hex[:8])
    run.mkdir(exist_ok=False)
    runner = adapter_class(base, parent)(args, run, reviewed, matrix, interfaces, extra)
    code = 0
    try:
        runner.execute()
    except BaseException as exc:
        code = 1
        runner.receipt["complete"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        for action in [runner.stop_owned, runner.release]:
            try:
                action()
            except BaseException as exc:
                code = 1
                runner.receipt["complete"] = False
                runner.receipt.setdefault("finalization_failures", []).append({"type": type(exc).__name__, "message": str(exc)})
        try:
            runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            code = 1
            runner.receipt["lock_released"] = False
            runner.receipt["lock_audit_failure"] = str(exc)
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        base.dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"],
                          "execution_scope": args.stage, "overall_v25_qualified": False,
                          "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
