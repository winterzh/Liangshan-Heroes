"""UNEXECUTED strict actual candidate6 AB-prefix -> fresh C -> BOTH actual A.

The source batch FAILED when a foreign engine resumed during C. Its receipt,
profile and producer remain immutable. Only the successful raw B slot chain,
journal and handoffs are copied into a wholly fresh isolated profile. Source
JSON533/Owned76/A39/B351 are historical executed responsibilities; C342 and the
two single-safe As must execute anew. This is exploration, never full v25 QA.
"""
from __future__ import annotations
import argparse
import ast
import copy
import datetime as dt
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
import time
import uuid

sys.dont_write_bytecode = True
EXPLORER_SHA = "d2fd596b94b2de563a073c897aa30892212e3f0c1ada2db475aec34ecf22801b"
PREFIX_SHA = "b4cfa3b00f4fdd5e2e354c4e9a5079c46b4b70a8c74633fc92dcda51d4cbcab6"
SOURCE_RECEIPT_SHA = "6643502eb4d0c23909feb081e991839da753d02adb7c30bd27662a61495d353c"
DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
ADMIT = ("A_half_save", "B_continue_resave", "C_verify_resave")
RETREAT = "A_single_save"
VARIANTS = {"lu_first": "lu", "shi_first": "shi"}
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


class Blocked(RuntimeError):
    pass


def require(value, message):
    if not value:
        raise Blocked(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def absolute(value):
    path = Path(value)
    require(path.is_absolute(), "absolute input path required")
    for parent in [path, *path.parents]:
        if parent.exists() or parent.is_symlink():
            require(not parent.is_symlink() and not getattr(parent.lstat(), "st_file_attributes", 0) & 0x400,
                    "reparse/link input refused")
    return path.resolve()


def pin(row):
    require(isinstance(row, dict) and type(row.get("bytes")) is int and row["bytes"] >= 0
            and type(row.get("sha256")) is str and HEX64.fullmatch(row["sha256"]), "exact input pin shape")
    path = absolute(row["path"])
    require(path.is_file() and path.stat().st_size == row["bytes"] and sha(path) == row["sha256"],
            "original pinned file missing/changed: " + str(path))
    return path


def owned(root, value):
    path = absolute(value)
    require(path.is_relative_to(root), "original evidence escaped source run")
    return path


def slot_document(path, magic, generation, previous):
    envelope = read(path)
    require(set(envelope) == {"app", "magic", "owner", "payload", "payload_bytes", "payload_sha256",
                              "previous_sha256", "revision", "version"}
            and all(type(value) is str for value in envelope.values())
            and envelope["magic"] == magic and envelope["app"] == "5088120" and envelope["owner"] == "1"
            and envelope["version"] == "1" and envelope["revision"] == str(generation)
            and envelope["previous_sha256"] == previous, "original slot envelope identity/chain")
    raw = envelope["payload"].encode("utf-8")
    require(envelope["payload_bytes"] == str(len(raw))
            and envelope["payload_sha256"] == hashlib.sha256(raw).hexdigest(), "original payload length/hash")
    return json.loads(envelope["payload"])


def check_prefix(args):
    """Read-only pre-import gate; a failed source is never renamed complete."""
    require(sha(args.explorer_producer) == EXPLORER_SHA and sha(args.prefix_inputs) == PREFIX_SHA,
            "immutable explorer or fixed actual prefix manifest drift")
    ast.parse(args.explorer_producer.read_text(encoding="utf-8-sig"))
    manifest = read(args.prefix_inputs)
    require(manifest.get("schema") == "daming_admit_successful_AB_prefix_inputs_v25s_r2d"
            and manifest.get("source_batch_complete") is False and manifest.get("source_failure_preserved") is True
            and manifest.get("new_native_executed") is False, "explicit failed-prefix input scope missing")
    receipt_path = pin(manifest["source_receipt"])
    require(sha(receipt_path) == SOURCE_RECEIPT_SHA, "this successor requires the actual interrupted 07ad37bf receipt")
    source = read(receipt_path); root = absolute(source["run"])
    require(receipt_path == root / "receipt.json" and manifest["source_run"] == source["run"]
            and source.get("schema") == "daming_safe_retreat_adapter_batch_v25s_r2"
            and source.get("producer_sha256") == EXPLORER_SHA
            and source.get("execution_scope") == "a_fixture_exploration"
            and source.get("complete") is False and source.get("lock_released") is True
            and source.get("failure") == {"type": "BatchFailure", "message": "foreign_engine_resumed; entire batch/profile preserved, no retry"}
            and not source.get("finalization_failures") and not source.get("lock_audit_failure")
            and source.get("private_runtime_patches") == 0 and source.get("overall_v25_qualified") is False
            and not source.get("retreat_reports") and source.get("actual_A_fixture_exploration_complete") is False,
            "source is not the exact foreign-interrupted AB prefix; no generic failed-batch recovery")
    finished = dt.datetime.fromisoformat(source["finished_utc"])
    now = dt.datetime.now(dt.timezone.utc)
    require(finished.tzinfo is not None and finished <= now < args.deadline_utc
            and now - finished < dt.timedelta(hours=4), "same authorized immediate recovery window required")
    steps = source["steps"]
    expected_steps = ["preflight", "wait_fx_terminal", "wait_natural_engine_idle", "freeze_private_project",
                      "import", "profile_guard", "json_boundary", "owned_slot_retry", *ADMIT]
    require([step.get("case") for step in steps] == expected_steps
            and all(step.get("complete") is True for step in steps[:-1]), "source exact executed prefix sequence")
    interrupted = steps[-1]
    require(interrupted.get("complete") is False and interrupted.get("process_terminal") is True
            and interrupted.get("exit_code") == 1 and interrupted.get("stop_reason") == "foreign_engine_resumed"
            and interrupted.get("failure") == source["failure"], "source C interruption not terminal foreign-engine boundary")
    require(time.monotonic_ns() > interrupted["native_finished_ns"],
            "same monotonic process-clock domain no longer available; fresh rerun required")
    paths = [args.prefix_inputs, args.explorer_producer, receipt_path]
    indexed = {}
    for row in manifest["evidence_files"]:
        path = pin(row); require(path.is_relative_to(root) and str(path) not in indexed, "prefix evidence duplicate/escape")
        indexed[str(path)] = row; paths.append(path)
    require(str(receipt_path) in indexed, "source raw failure receipt not included in evidence pins")
    for step in steps[4:]:
        require(step.get("process_terminal") is True and step.get("native_started_ns") < step.get("native_finished_ns"),
                "original native terminal/timing missing")
        log = owned(root, step["log"])
        require(str(log) in indexed and sha(log) == step["log_sha256"], "original raw log pin missing")
        text = ANSI.sub("", log.read_text(encoding="utf-8", errors="replace"))
        require(not ERRORS.search(text), "original native engineering error, including ANSI-prefixed error")
        if step is not interrupted:
            require(step.get("exit_code") == (2 if step["case"] == "profile_guard" else 0)
                    and not step.get("stop_reason"), "only the final C can be interrupted")
            if step["case"] == "profile_guard": require("PRIVATE_PROFILE_REQUIRED" in text, "original private-profile refusal marker missing")
    require(set(source["reports"]) == set(ADMIT[:2]), "only original successful A/B may be imported")
    reports, pids, nonces = {}, set(), set()
    previous = None
    for case, count in zip(ADMIT[:2], [39, 351]):
        row = source["reports"][case]; report_path = owned(root, row["report"])
        require(str(report_path) in indexed and sha(report_path) == row["report_sha256"], "original report not pinned")
        report = read(report_path); step = next(s for s in steps if s["case"] == case)
        require(report.get("schema") == "daming_admit_cross_process_report_v24o"
                and report.get("case") == case and report.get("passed") is True
                and len(report.get("checks", [])) == row["checks"] == step["checks"] == count
                and all(c.get("passed") is True for c in report["checks"])
                and report.get("pid") == row["pid"] == step["pid"]
                and report.get("nonce") == row["nonce"] == step["process_nonce"]
                and row["pid"] not in pids and row["nonce"] not in nonces
                and report.get("teleports") == 0 and report.get("fixture_ticks") == 0
                and report.get("progress_injections") == 0 and report.get("clock_acceleration") is False,
                "original actual A/B report/check/PID/nonce/ordinary-route mismatch")
        trusted = report["trusted"]
        require(trusted.get("ok") is True and trusted.get("content_version") == source["installed_identity"]["content_version"]
                and trusted.get("file_count") == 5102 and trusted.get("engine_binary_sha256") == source["godot_sha256"],
                "actual source A/B entire identity/engine mismatch")
        for field in ["public_campaign_continue_qualified", "natural_victory_qualified", "reward_once_qualified"]:
            require(report.get(field) is False, "original A/B scope overclaim")
        user = owned(root / "profile" / "appdata", report["actual_user_data_dir"])
        for evidence in report["evidence"]:
            path = user / evidence["path"][7:] if evidence["path"].startswith("user://") else owned(root, evidence["path"])
            require(str(absolute(path)) in indexed and sha(path) == evidence["sha256"], "original full packet/world/clock evidence not pinned")
        text = ANSI.sub("", Path(step["log"]).read_text(encoding="utf-8", errors="replace"))
        require("DAMING_ADMIT_V24O_COMPLETE " + case in text, "actual validated original A/B terminal marker")
        if previous:
            require(report["previous_pid"] == previous["pid"] and report["previous_nonce"] == previous["nonce"]
                    and steps[-3]["native_finished_ns"] <= step["native_started_ns"], "actual distinct A->B predecessor chain")
        pids.add(row["pid"]); nonces.add(row["nonce"]); previous = row
        reports[case] = report
    for key, count in [("json_boundary_report", 533), ("owned_slot_retry_report", 76)]:
        row = source[key]; path = owned(root, row["path"])
        require(str(path) in indexed and sha(path) == row["sha256"], "actual candidate6 regression report not pinned")
        data = read(path)
        require(data.get("passed") is True and len(data.get("checks", [])) == row["checks"] == count
                and all(c.get("passed") is True for c in data["checks"]), "actual candidate6 full regression failed")
        if key == "json_boundary_report":
            require(data.get("schema") == "native_ownership_json_boundary_report_v24q"
                    and set(row["cases"]) == {"actual_v24p_pending", "classic_liangshan", "classic_none", "daming", "gao", "level1", "level2", "level3", "level4", "level6", "level7"}
                    and data.get("content_version") == source["installed_identity"]["content_version"]
                    and data.get("engine_sha256") == source["godot_sha256"] and data.get("pid") == row["pid"]
                    and data.get("nonce") == row["nonce"], "actual JSON11 full source/PID/nonce identity")
        else:
            require(data.get("production_slot_document") is False and data.get("real_steam") is False
                    and row.get("original_tool_unchanged") is True, "original OwnedSlot component scope changed")
    user = owned(root / "profile" / "appdata", reports[ADMIT[1]]["actual_user_data_dir"])
    suffix = Path(manifest["profile_application_suffix"])
    require(not suffix.is_absolute() and ".." not in suffix.parts
            and user == root / "profile" / "appdata" / suffix, "actual application profile suffix mismatch")
    profile_rows = manifest["profile_files"]; by_relative = {}
    for row in profile_rows:
        path = pin(row); relative = Path(row["relative"])
        require(not relative.is_absolute() and ".." not in relative.parts and row["relative"] not in by_relative
                and path == user / relative and path.is_relative_to(user / "daming_admit_v24o"), "unsafe prefix profile path")
        by_relative[row["relative"]] = row; paths.append(path)
    actual_profile = {p.relative_to(user).as_posix(): sha(p) for p in (user / "daming_admit_v24o").rglob("*") if absolute(p).is_file()}
    require(actual_profile == {k: v["sha256"] for k, v in by_relative.items()} and len(by_relative) == 5,
            "original prefix scope has pending/extra/missing/changed files; cannot recover unsafe transaction")
    packet_b = None
    for generation, case in enumerate(ADMIT[:2], 1):
        handoff_path = user / "daming_admit_v24o" / ("handoff_A.json" if generation == 1 else "handoff_B.json")
        handoff = read(handoff_path); row = source["reports"][case]
        slot = user / "daming_admit_v24o/continue/v1/5088120/1" / f"record_{generation:010d}.json"
        packet = slot_document(slot, "LH_CLASSIC_CONTINUE_SLOT", generation,
                               "0" * 64 if generation == 1 else source["reports"][ADMIT[0]]["slot_sha256"])
        folder = Path(row["report"]).parent
        require(sha(slot) == handoff.get("file_sha256") == row["slot_sha256"]
                and handoff.get("generation") == packet.get("generation") == generation
                and handoff.get("pid") == row["pid"] and handoff.get("nonce") == row["nonce"]
                and handoff.get("mode") == case and handoff.get("packet") == packet == read(folder / "saved_packet.json")
                and packet["world"] == read(folder / "saved_world.json")
                and handoff.get("content_version") == source["installed_identity"]["content_version"]
                and handoff.get("engine_sha256") == source["godot_sha256"], "exact raw successful save/packet/world/handoff identity")
        retained = owned(root, next(s for s in steps if s["case"] == case)["slot"]["retained_path"])
        require(str(retained) in indexed and sha(retained) == sha(slot), "retained original generation missing/changed")
        if generation == 2:
            require(handoff.get("ancestor_pids") == [source["reports"][ADMIT[0]]["pid"]]
                    and handoff.get("ancestor_nonces") == [source["reports"][ADMIT[0]]["nonce"]], "original handoff actual AB ancestor chain")
            packet_b = packet
    binding = packet_b["binding"]
    require(binding.get("kind") == "uncredited" and HEX64.fullmatch(binding.get("receipt_sha256", "")), "actual uncredited local binding required")
    journal = user / "daming_admit_v24o/continue/v1/local_runs" / binding["token"] / "5088120/1/record_0000000001.json"
    require(sha(journal) == binding["receipt_sha256"], "original active lifecycle journal SHA mismatch")
    require(slot_document(journal, "LH_LOCAL_CONTINUE_LIFECYCLE", 1, "0" * 64) == {
        "schema": "local_continue_lifecycle_v1", "generation": 1, "token": binding["token"],
        "context": {"mode": "defense", "level_id": "", "waves": 30}, "state": "active", "victory": False},
        "original LocalLifecycle default-defense30 schema required; do not fake campaign context")
    require(packet_b["context"] == {"mode": "campaign", "level_id": "level8", "waves": 0}, "actual campaign Slot context mismatch")
    candidate = read(args.candidate_receipt)
    require(source["candidate_source_bridge"]["files"] == candidate["files"] and len(candidate["files"]) == 6
            and source["candidate_source_bridge"]["receipt_sha256"] == sha(args.candidate_receipt)
            and source["godot_sha256"] == sha(args.godot)
            and len(source["source_files"]) == 5041 and len({r["path"] for r in source["source_files"]}) == 5037
            and source["installed_identity"]["file_count"] == len(source["installed_identity"]["files"]) == 5102,
            "current actual six candidate/source5041/full5102/engine differs from original prefix")
    for row in source["source_files"]:
        path = owned(args.source_root, args.source_root / row["path"])
        require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "current ROOT original full source inventory drift")
    for row in source["helper_and_proposal_files"]:
        path = absolute(row["path"]); require(sha(path) == row["sha256"], "original executed tool/proposal input drift")
        paths.append(path)
    require(len(source["added_qa_files"]) == 9 and len(source["native_installed_files"]) == 9,
            "original nine tool additions or nine actual native dependencies missing")
    project = absolute(source["project"])
    for row in [*source["added_qa_files"], *source["native_installed_files"]]:
        path = owned(project, project / row["path"])
        require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "original private tool/native file drift")
        paths.append(path)
    approval = read(args.recovery_review)
    require(approval.get("schema") == "daming_safe_retreat_prefix_c_review_v25s_r2d"
            and approval.get("static_api_closure_passed") is True
            and approval.get("approved_stages") == ["prefix_c_then_both_actual_A"]
            and pin(approval["producer_pin"]) == Path(__file__).resolve()
            and pin(approval["prefix_inputs_pin"]) == args.prefix_inputs,
            "new independent exact prefix recovery review missing")
    paths.append(args.recovery_review)
    return {"source": source, "manifest": manifest, "paths": sorted(set(paths)), "profile_rows": profile_rows,
            "pids": pids, "nonces": nonces, "reports": reports}


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def recovery_class(base, parent, explorer):
    Explorer = explorer.adapter_class(base, parent)

    class Recovery(Explorer):
        def __init__(self, args, run, reviewed, matrix, interfaces, extra, prefix):
            super().__init__(args, run, reviewed, matrix, interfaces, extra)
            self.prefix = prefix
            self.receipt.update(schema="daming_safe_retreat_prefix_c_exploration_batch_v25s_r2d",
                producer_sha256=sha(Path(__file__)), execution_scope="prefix_c_then_both_actual_A",
                source_prefix_receipt_sha256=SOURCE_RECEIPT_SHA, source_prefix_batch_complete=False,
                source_failure_preserved=True, source_prefix_inputs_sha256=PREFIX_SHA,
                historical_prefix_responsibilities=["JSON533", "OwnedSlot76", "A_half_save39", "B_continue_resave351"],
                newly_required_native_cases=[ADMIT[2], "lu_first/" + RETREAT, "shi_first/" + RETREAT],
                overall_v25_qualified=False, candidate_ABC_chain_completed=False,
                scope="Exact failed foreign-interrupted candidate6 batch AB prefix plus fresh C342 and both real A exploration. No full v25, natural terminal, Campaign persistence or release qualification.")

        def preflight(self):
            self.prefix = check_prefix(self.args)
            super().preflight()  # preserves immutable r2a review and select6/base/source/native guards
            source = self.prefix["source"]
            base.require(self.inputs == source["source_files"] and self.native == source["native_dependencies"],
                         "new fresh source/native dependencies do not equal actual prefix candidate")
            base.require(base.installed_identity(Path(source["project"])) == source["installed_identity"],
                         "old actual full installed5102 identity drift; prefix cannot be reused")
            for path in self.prefix["paths"] + [Path(__file__).resolve()]:
                self.code_pins[str(path)] = sha(path)
            self.receipt["helper_and_proposal_files"] = [{"path": path, "sha256": value} for path, value in self.code_pins.items()]
            self.input_integrity()

        def prepare(self):
            super().prepare()
            source = self.prefix["source"]
            base.require(self.installed == source["installed_identity"]
                         and self.receipt["native_installed_files"] == source["native_installed_files"],
                         "fresh frozen project full5102/native9 differs from actual AB prefix")
            base.require(self.receipt["added_qa_files"] == source["added_qa_files"],
                         "fresh actually installed QA9 differs from actual prefix tools")
            self.input_integrity(True)

        def native_phase(self, label, arguments, env, timeout_seconds, validator):
            def strict(step, text):
                clean = ANSI.sub("", text)
                base.require(not ERRORS.search(clean), "native engineering error including ANSI-prefixed error")
                if label == ADMIT[2]:
                    base.require(step["pid"] not in self.prefix["pids"] and step["process_nonce"] not in self.prefix["nonces"],
                                 "new C reused historical A/B actual PID/nonce")
                validator(step, clean)
            return super().native_phase(label, arguments, env, timeout_seconds, strict)

        def install_prefix(self):
            """Raw-byte copy only from pinned read-only inputs into fresh profile."""
            snapshot = self.run / "frozen_successful_AB_prefix"
            snapshot.mkdir(exist_ok=False)
            source = self.prefix["source"]
            copied = []
            user = self.profile / "appdata" / self.prefix["manifest"]["profile_application_suffix"]
            base.require(not (user / "daming_admit_v24o").exists(), "fresh recovery continuation subtree already has data")
            for row in self.prefix["profile_rows"]:
                original = pin(row)
                frozen = snapshot / "profile" / row["relative"]
                frozen.parent.mkdir(parents=True, exist_ok=True)
                self.copy_checked(original, frozen, row["sha256"])
                self.code_pins[str(frozen)] = row["sha256"]
                target = user / row["relative"]
                target.parent.mkdir(parents=True, exist_ok=True)
                base.require(not target.exists(), "recovery copy cannot overwrite fresh data")
                self.copy_checked(frozen, target, row["sha256"])
                copied.append({"source": str(original), "frozen": str(frozen), "target": str(target),
                               "bytes": row["bytes"], "sha256": row["sha256"], "relative": row["relative"]})
            base.dump_new(snapshot / "copy_manifest.json", copied)
            self.code_pins[str(snapshot / "copy_manifest.json")] = sha(snapshot / "copy_manifest.json")
            # Original successful steps remain explicit historical executions.
            # The unmodified C validator needs their actual PID/nonce/terminal
            # timestamps; no new native subprocess or receipt is fabricated.
            for case in ADMIT[:2]:
                original_step = next(s for s in source["steps"] if s["case"] == case)
                historical = copy.deepcopy(original_step)
                historical.update(evidence_origin="historical_successful_prefix", executed_in_this_batch=False,
                                  source_receipt_sha256=SOURCE_RECEIPT_SHA)
                self.receipt["steps"].append(historical)
                self.reports[case] = copy.deepcopy(source["reports"][case])
                self.receipt["reports"][case] = dict(self.reports[case], evidence_origin="historical_successful_prefix",
                                                      executed_in_this_batch=False, source_receipt_sha256=SOURCE_RECEIPT_SHA)
            self.receipt["json_boundary_report"] = dict(source["json_boundary_report"], evidence_origin="historical_successful_prefix",
                                                        executed_in_this_batch=False, source_receipt_sha256=SOURCE_RECEIPT_SHA)
            self.receipt["owned_slot_retry_report"] = dict(source["owned_slot_retry_report"], evidence_origin="historical_successful_prefix",
                                                           executed_in_this_batch=False, source_receipt_sha256=SOURCE_RECEIPT_SHA)
            self.receipt["prefix_copy_manifest_sha256"] = sha(snapshot / "copy_manifest.json")
            self.receipt["historical_actual_gameplay_processes"] = 2
            self.input_integrity(True)

        def execute(self):
            self.preflight(); self.wait_prior()
            with self.stage("wait_natural_engine_idle") as step:
                self.wait_idle(); step["foreign_engines_at_idle"] = base.engine_rows()
            self.prepare()
            import_env = self.env.copy()
            import_env.update(DAMING_ADMIT_CASE=ADMIT[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            def imported(step, text):
                base.require(step.get("exit_code") == 0 and step.get("process_terminal") is True,
                             "fresh complete native import must terminate zero")
                self.input_integrity(True)
            self.native_phase("import", ["--headless", "--editor", "--import", "--quit"], import_env, 900, imported)
            guard_env = self.env.copy()
            guard_env.update(DAMING_ADMIT_PROFILE=str(self.profile / "mismatch"), DAMING_ADMIT_CASE=ADMIT[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            def guarded(step, text):
                base.require(step.get("exit_code") == 2 and "PRIVATE_PROFILE_REQUIRED" in text
                             and not (self.output / ADMIT[0]).exists()
                             and not list((self.profile / "appdata").rglob("handoff_A.json")),
                             "fresh profile guard failed or wrote regular evidence")
            self.native_phase("profile_guard", ["--headless", "res://tools/daming_admit_cross_process_v24s.tscn"], guard_env, 300, guarded)
            self.install_prefix()
            env = self.env.copy(); env.update(DAMING_ADMIT_CASE=ADMIT[2], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            self.native_phase(ADMIT[2], ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                "--resolution", "1280x720", "--position", "30000,30000", "res://tools/daming_admit_cross_process_v24s.tscn"],
                env, 600, lambda step, text: self.validate_case(ADMIT[2], step, text))
            with self.stage("complete_historical_AB_plus_new_C_source_native_slot_audit") as step:
                self.input_integrity(True)
                base.require(list(self.reports) == list(ADMIT) and self.reports[ADMIT[2]]["checks"] == 342,
                             "actual full original C342/ABC-chain responsibility incomplete")
                user = Path(base.read(self.output / ADMIT[2] / "report.json")["actual_user_data_dir"])
                actual = {p.relative_to(user).as_posix(): sha(p) for p in (user / "daming_admit_v24o").rglob("*") if base.no_reparse(p).is_file()}
                base.require(actual == {r["relative"]: r["sha256"] for r in self.prefix["profile_rows"]},
                             "read-only C changed B slot/journal/handoff or created pending profile files")
                base.dump_new(self.run / "isolated_slot_and_lifecycle_manifest.json", [
                    {"path": str(user / r["relative"]), "bytes": r["bytes"], "sha256": r["sha256"]} for r in self.prefix["profile_rows"]])
                self.receipt.update(candidate_ABC_chain_completed=True, original_candidate_admit_regressions_qualified=True,
                    source_native_drift=0, private_native_drift=0, root_input_drift=0, private_input_drift=0,
                    original_AB_preserved_failed_batch=True, newly_executed_admit_case_count=1,
                    slot_and_lifecycle_manifest_sha256=sha(self.run / "isolated_slot_and_lifecycle_manifest.json"))
                step.update(historical_actual_AB_processes=2, newly_executed_C_processes=1, source_batch_complete=False)
            for row in self.reports.values():
                base.require(row["pid"] not in self.execution_pids and row["nonce"] not in self.execution_nonces,
                             "actual historical/new gameplay chain process reuse")
                self.execution_pids.add(row["pid"]); self.execution_nonces.add(row["nonce"])
            for variant, role in VARIANTS.items():
                group = self.new_group(variant); self.activate_group(group)
                nonce = uuid.uuid4().hex; guard = self.env.copy()
                guard.update(DAMING_RETREAT_PROFILE=str(self.profile / "mismatch"), DAMING_RETREAT_CASE=RETREAT,
                             DAMING_RETREAT_FIRST_ROLE=role, DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                def retreat_guarded(step, text):
                    base.require(step.get("exit_code") == 2 and step.get("process_terminal") is True
                        and "DAMING_RETREAT PRIVATE_PROFILE_REQUIRED" in text and not (self.output / RETREAT).exists()
                        and not list((self.profile / "appdata").rglob("handoff_A.json")), "fresh role private-profile guard failed")
                self.native_phase(variant + "_profile_guard", ["--headless", "res://tools/" + self.args.retreat_scene.name], guard, 300, retreat_guarded)
                self.activate_group(group)
                nonce = uuid.uuid4().hex; env = self.env.copy()
                env.update(DAMING_RETREAT_CASE=RETREAT, DAMING_RETREAT_FIRST_ROLE=role,
                           DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                self.native_phase(variant + "_" + RETREAT, ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                    "--resolution", "1280x720", "--position", "30000,30000", "res://tools/" + self.args.retreat_scene.name], env, 1200,
                    lambda step, text, variant=variant: self.validate_retreat_case(variant, RETREAT, step, text))
                self.freeze_actual_a(variant)
            with self.stage("prefix_C_both_actual_A_full_source_profiles_native_readback") as step:
                self.input_integrity(True)
                base.require(set(self.retreat_reports) == {(v, RETREAT) for v in VARIANTS}
                             and set(self.frozen_a) == set(VARIANTS), "both actual single-safe A responsibility missing")
                profiles = []
                for name, group in self.profile_groups.items():
                    for path in sorted(group["profile"].rglob("*")):
                        path = base.no_reparse(path)
                        if path.is_file(): profiles.append({"group": name, "path": str(path), "bytes": path.stat().st_size, "sha256": sha(path)})
                path = self.run / "actual_A_exploration_profile_manifest.json"; base.dump_new(path, profiles)
                for s in self.receipt["steps"]:
                    if s.get("log"):
                        text = ANSI.sub("", Path(s["log"]).read_text(encoding="utf-8", errors="replace"))
                        base.require(not ERRORS.search(text), "final ANSI-aware raw native log failed")
                # Re-read every original prefix input; no original profile write.
                check_prefix(self.args)
                self.receipt.update(complete=True, actual_A_fixture_exploration_complete=True,
                    actual_A_roles=["lu", "shi"], overall_v25_qualified=False, all_negatives_qualified=False,
                    natural_victory_qualified=False, local_terminal_once_qualified=False,
                    campaign_persistence_qualified=False, callback_invocation_count_qualified=False,
                    main_gameplay_process_responsibilities=5, main_gameplay_processes_launched_here=3,
                    historical_actual_gameplay_processes=2, actual_observed_case_processes=len(self.execution_pids),
                    exploration_profile_manifest_sha256=sha(path), root_input_drift=0, private_input_drift=0,
                    source_native_drift=0, private_native_drift=0,
                    implementation_boundary="Only historical candidate6 JSON/Owned/AB and new full C plus BOTH real single-safe A. No full negative matrix or B/C/D terminal gameplay executed by this producer.")
                step.update(profile_groups=len(self.profile_groups), profile_files=len(profiles), actual_A_cases=2)
    return Recovery


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt",
                 "cached-native-world", "candidate-receipt", "boundary-harness", "boundary-manifest",
                 "runner-review", "adapter-review", "recovery-review", "deadline-utc"]:
        parser.add_argument("--" + name, required=True, type=str if name == "deadline-utc" else Path)
    here = Path(__file__).resolve().parent
    defaults = {"base-producer": Path("E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py"),
        "parent-producer": here / "run_daming_safe_retreat_v25s.py", "explorer-producer": here / "run_daming_safe_retreat_v25s_r2a_explore.py",
        "prefix-inputs": here / "PREFIX_C_INPUTS_V25S_R2D_07AD37BF.json",
        "retreat-runner": here / "daming_safe_retreat_cross_process_v25s1.gd", "retreat-scene": here / "daming_safe_retreat_cross_process_v25s1.tscn",
        "retreat-route": here / "daming_safe_retreat_route_v25.gd", "capture-base": here / "daming_safe_retreat_cross_process_v25.gd",
        "negative-matrix": here / "ADAPTER_BUNDLE_MATRIX_V25S_R2A.json", "passed-admit-successor-proof": here / "PASSED_SUCCESSOR_PROOF_V25S_ACTUAL_2A817E70.json",
        "proof-repository-root": Path("E:/ChatGPT/水浒"), "world-interface": here / "NEGATIVE_WORLD_INTERFACE_V25B2.json",
        "capture-interface": here / "CAPTURE_NEGATIVE_INTERFACE_V25C.json", "component-interface": here / "COMPONENT_NEGATIVE_INTERFACE_V25.json",
        "negative-successor-review": here / "NEGATIVE_SUCCESSOR_REVIEW_V25.json", "component-review": here / "COMPONENT_NEGATIVE_PEER_REVIEW_V25_IMPLEMENTED_CANDIDATE.json"}
    for name, default in defaults.items(): parser.add_argument("--" + name, type=Path, default=default)
    parser.add_argument("--prior-pid", type=int)
    args = parser.parse_args(); args.stage = "a_fixture_exploration"; args.exploration_role = "both"
    try:
        args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
        require(args.deadline_utc.tzinfo is not None and dt.datetime.now(dt.timezone.utc) < args.deadline_utc <= DEADLINE,
                "AUTHORIZED_SIX_AM_DEADLINE_INVALID_OR_REACHED")
        for key, value in vars(args).items():
            if isinstance(value, Path): setattr(args, key, absolute(value))
        prefix = check_prefix(args)
        require(not args.work_root.is_relative_to(args.source_root), "new private work root must be outside ROOT")
        explorer = load_module(args.explorer_producer, "immutable_r2a_for_prefix_c")
        reviewed, matrix, interfaces, extra = explorer.check_prerequisites(args)
    except (Blocked, OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        print(json.dumps({"status": "BLOCKED", "complete": False, "engine_batch_created": False,
                          "engine_started": False, "reason": str(exc)}, ensure_ascii=False), flush=True)
        return 2
    # No original producer CLI, profile recovery or old batch writes.
    parent = explorer.load_module(args.parent_producer, "immutable_v25s_for_prefix_c")
    base = parent.load_base(args.base_producer)
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("daming_safe_retreat_v25s_r2d_prefix_c_" + uuid.uuid4().hex[:8]); run.mkdir(exist_ok=False)
    runner = recovery_class(base, parent, explorer)(args, run, reviewed, matrix, interfaces, extra, prefix)
    code = 0
    try:
        runner.execute()
    except BaseException as exc:
        code = 1; runner.receipt["complete"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        for action in [runner.stop_owned, runner.release]:
            try: action()
            except BaseException as exc:
                code = 1; runner.receipt["complete"] = False
                runner.receipt.setdefault("finalization_failures", []).append({"type": type(exc).__name__, "message": str(exc)})
        try:
            runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            code = 1; runner.receipt["lock_released"] = False; runner.receipt["lock_audit_failure"] = str(exc)
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        base.dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"], "execution_scope": "prefix_c_then_both_actual_A",
                          "overall_v25_qualified": False, "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
