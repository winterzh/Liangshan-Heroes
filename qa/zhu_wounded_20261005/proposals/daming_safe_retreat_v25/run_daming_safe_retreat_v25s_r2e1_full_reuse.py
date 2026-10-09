"""UNEXECUTED r2e1 full successor: exact closed r2a/r2d/r2f BOTH-A sources.

The exact corrected r2b2 consumers and original world/packet/clock/terminal
validators are inherited. Actual historical candidate6 ABC and both saved As
remain distinct historical responsibilities. Fresh native negative52 and both
BCD chains are mandatory; there is no skip or A-only full-pass path.
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
FULL_SHA = "e61b7e87a5c52792040fc9d6e84828c6fce2aec8f3496ec3bf883c78aab5fd79"
EXPLORER_SHA = "d2fd596b94b2de563a073c897aa30892212e3f0c1ada2db475aec34ecf22801b"
PREFIX_PRODUCER_SHA = "3d3715bb0c0a0b5be77bd840e46875a9856eab1164c65d8bbc44512274d37856"
OFFLINE_PRODUCER_SHA = "2f077e7903cd94c69826eee5f171e2f341163268b91676cf6104a70cc5ca8c61"
PREFIX_INPUT_SHA = "b4cfa3b00f4fdd5e2e354c4e9a5079c46b4b70a8c74633fc92dcda51d4cbcab6"
FAILED_PREFIX_SHA = "6643502eb4d0c23909feb081e991839da753d02adb7c30bd27662a61495d353c"
BASE_SHA = "049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626"
PARENT_SHA = "5941315849982fb73d4851c2fcb95a2369d498760a83801427d315dd6a229af5"
DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
CASES = ("A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal")
ADMIT = ("A_half_save", "B_continue_resave", "C_verify_resave")
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
    p = Path(value); require(p.is_absolute(), "absolute source path required")
    for q in [p, *p.parents]:
        if q.exists() or q.is_symlink():
            require(not q.is_symlink() and not getattr(q.lstat(), "st_file_attributes", 0) & 0x400, "reparse/link refused")
    return p.resolve()


def pin(row):
    require(isinstance(row, dict) and type(row.get("bytes")) is int and row["bytes"] >= 0
            and type(row.get("sha256")) is str and HEX64.fullmatch(row["sha256"]), "strict file pin shape")
    p = absolute(row["path"])
    require(p.is_file() and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"], "original evidence pin drift: " + str(p))
    return p


def in_roots(roots, value):
    p = absolute(value); require(any(p.is_relative_to(root) for root in roots), "original evidence escaped approved closed source roots")
    return p


def actual_slot(path, magic, generation, previous):
    envelope = read(path)
    require(set(envelope) == {"app", "magic", "owner", "payload", "payload_bytes", "payload_sha256", "previous_sha256", "revision", "version"}
            and all(type(v) is str for v in envelope.values()) and envelope["magic"] == magic
            and envelope["app"] == "5088120" and envelope["owner"] == "1" and envelope["version"] == "1"
            and envelope["revision"] == str(generation) and envelope["previous_sha256"] == previous, "original raw chain envelope identity")
    raw = envelope["payload"].encode("utf-8")
    require(envelope["payload_bytes"] == str(len(raw)) and envelope["payload_sha256"] == hashlib.sha256(raw).hexdigest(),
            "original raw payload bytes/hash")
    return json.loads(envelope["payload"])


def check_closed_source(args):
    """Exact raw closed source gate. Missing/incomplete/failure -> no batch."""
    require(HEX64.fullmatch(args.closed_source_proof_sha256 or "")
            and sha(args.closed_source_proof) == args.closed_source_proof_sha256,
            "actual closed-source proof must have explicit independently read-back SHA")
    proof = read(args.closed_source_proof)
    require(proof.get("schema") == "daming_safe_retreat_closed_A_source_proof_v25s_r2e"
            and proof.get("closed_source_observed_complete") is True and proof.get("both_actual_A_sources_verified") is True
            and proof.get("candidate6_ABC_chain_verified") is True and proof.get("native_source_profile_artifacts_verified") is True
            and proof.get("template_only") is False, "actual independent closed BOTH A source proof required")
    receipt_path = pin(proof["receipt_pin"]); source = read(receipt_path); root = absolute(source["run"])
    require(receipt_path == root / "receipt.json" and source.get("complete") is True and source.get("lock_released") is True
            and source.get("actual_A_fixture_exploration_complete") is True
            and source.get("original_candidate_admit_regressions_qualified") is True
            and source.get("actual_A_roles") == ["lu", "shi"] and source.get("overall_v25_qualified") is False
            and source.get("private_runtime_patches") == 0 and not source.get("failure")
            and not source.get("finalization_failures") and not source.get("lock_audit_failure")
            and all(source.get(k) == 0 for k in ["root_input_drift", "private_input_drift", "source_native_drift", "private_native_drift"]),
            "closed successful actual BOTH source required; no incomplete/failed/A-only reuse")
    roots = [root]; paths = [args.closed_source_proof, receipt_path]
    source_producer = pin(proof["producer_pin"])
    require(sha(source_producer) == source["producer_sha256"] == proof["producer_pin"]["sha256"], "closed actual producer identity mismatch")
    paths.append(source_producer)
    if source["producer_sha256"] == EXPLORER_SHA:
        require(source.get("schema") == "daming_safe_retreat_adapter_batch_v25s_r2"
                and source.get("execution_scope") == "a_fixture_exploration", "original r2a closed schema/scope mismatch")
    else:
        require(source["producer_sha256"] in {PREFIX_PRODUCER_SHA, OFFLINE_PRODUCER_SHA}
                and source.get("schema") == ("daming_safe_retreat_prefix_c_exploration_batch_v25s_r2d"
                    if source["producer_sha256"] == PREFIX_PRODUCER_SHA else "daming_safe_retreat_prefix_c_exploration_batch_v25s_r2f")
                and (source["producer_sha256"] != OFFLINE_PRODUCER_SHA
                     or (source.get("preparation_parent_sha256") == PREFIX_PRODUCER_SHA
                         and source.get("native_phase_guards_unchanged") is True
                         and source.get("original_real_C342_and_both_A_required") is True))
                and source.get("execution_scope") == "prefix_c_then_both_actual_A"
                and source.get("candidate_ABC_chain_completed") is True
                and source.get("source_prefix_batch_complete") is False and source.get("source_failure_preserved") is True
                and source.get("source_prefix_receipt_sha256") == FAILED_PREFIX_SHA
                and source.get("source_prefix_inputs_sha256") == PREFIX_INPUT_SHA
                and source.get("main_gameplay_processes_launched_here") == 3
                and source.get("historical_actual_gameplay_processes") == 2,
                "exact closed prefix-C successor chain required; failed predecessor stays failed")
        prefix_path = pin(proof["failed_prefix_inputs_pin"]); require(sha(prefix_path) == PREFIX_INPUT_SHA, "original failed prefix manifest drift")
        prefix = read(prefix_path); failed_receipt = pin(prefix["source_receipt"]); failed = read(failed_receipt)
        require(sha(failed_receipt) == FAILED_PREFIX_SHA and failed.get("complete") is False and failed.get("lock_released") is True,
                "original foreign-interrupted batch must remain failed")
        roots.append(absolute(failed["run"])); paths += [prefix_path, failed_receipt]
        # The closed source's original prefix tool/manifest/evidence inputs stay pinned.
        for row in [*prefix["evidence_files"], *prefix["profile_files"]]: paths.append(pin(row))
    finished = dt.datetime.fromisoformat(source["finished_utc"])
    require(finished.tzinfo is not None and finished <= dt.datetime.now(dt.timezone.utc) < args.deadline_utc,
            "closed source not terminal before this authorized deadline")
    identity = source["installed_identity"]
    require(identity["file_count"] == len(identity["files"]) == 5102 and len(source["source_files"]) == 5041
            and len({r["path"] for r in source["source_files"]}) == 5037
            and source["godot_sha256"] == sha(args.godot), "actual full5102/raw5041/distinct5037/engine source mismatch")
    candidate = read(args.candidate_receipt)
    require(source["candidate_source_bridge"]["files"] == candidate["files"] and len(candidate["files"]) == 6
            and source["candidate_source_bridge"]["receipt_sha256"] == sha(args.candidate_receipt), "actual six-candidate source bridge mismatch")
    for row in source["source_files"]:
        p = in_roots([args.source_root], args.source_root / row["path"])
        require(p.stat().st_size == row["bytes"] and sha(p) == row["sha256"], "current ROOT original complete source inventory drift")
    for row in source["helper_and_proposal_files"]:
        p = absolute(row["path"]); require(sha(p) == row["sha256"], "closed source executed tool/proposal input drift"); paths.append(p)
    source_project = absolute(source["project"])
    require(source_project.is_relative_to(root) and len(source["native_installed_files"]) == 9, "closed actual native9/project origin")
    for row in [*identity["files"], *source["native_installed_files"], *source["added_qa_files"]]:
        p = in_roots([source_project], source_project / row["path"])
        require(p.stat().st_size == row["bytes"] and sha(p) == row["sha256"], "actual closed project fullruntime/native/tool input drift")
    added = {r["path"]: r["sha256"] for r in source["added_qa_files"]}
    for p in [args.retreat_runner, args.retreat_scene, args.retreat_route]:
        require(added.get("tools/" + p.name) == sha(p), "original actual A runner/scene/route not current reviewed source")
    require(set(source.get("reports", {})) == set(ADMIT)
            and set(source.get("retreat_reports", {})) == {v + "/" + CASES[0] for v in VARIANTS}
            and set(source.get("actual_A_fixtures", {})) == set(VARIANTS), "complete genuine ABC and both A responsibility sets missing")
    steps = source["steps"]
    for step in steps:
        if step.get("log"):
            p = in_roots(roots, step["log"])
            require(sha(p) == step["log_sha256"] and step.get("process_terminal") is True and not step.get("stop_reason")
                    and step.get("exit_code") in [0, 2], "closed source native step not terminal/valid")
            text = ANSI.sub("", p.read_text(encoding="utf-8", errors="replace"))
            require(not ERRORS.search(text), "closed source ANSI-aware native error"); paths.append(p)
    pids, nonces, original_cases = set(), set(), {}
    def actual_case(key, row, expected_case, expected_count=None):
        report_path = in_roots(roots, row["report"])
        require(sha(report_path) == row["report_sha256"], "closed actual report SHA mismatch")
        data = read(report_path)
        require(data.get("case") == expected_case and data.get("passed") is True and data.get("checks")
                and all(c.get("passed") is True for c in data["checks"])
                and (expected_count is None or len(data["checks"]) == expected_count)
                and len(data["checks"]) == row["checks"] and data.get("pid") == row["pid"]
                and data.get("nonce") == row["nonce"] and row["pid"] not in pids and row["nonce"] not in nonces,
                "closed actual case/PID/nonce/count/check mismatch")
        trusted = data["trusted"]
        require(trusted.get("content_version") == identity["content_version"] and trusted.get("file_count") == 5102
                and trusted.get("engine_binary_sha256") == source["godot_sha256"]
                and data.get("teleports") == data.get("fixture_ticks") == data.get("progress_injections") == 0
                and data.get("clock_acceleration") is False, "closed actual case source/native or gameplay fixture boundary")
        matches = [s for s in steps if s.get("case") == key and s.get("pid") == row["pid"]]
        require(len(matches) == 1 and matches[0].get("complete") is True and matches[0].get("exit_code") == 0
                and matches[0].get("process_terminal") is True and matches[0].get("process_nonce") == row["nonce"]
                and matches[0]["native_started_ns"] < matches[0]["native_finished_ns"] <= time.monotonic_ns(),
                "closed actual native case process or same-host monotonic predecessor unavailable")
        step = matches[0]
        user = in_roots(roots, data["actual_user_data_dir"])
        for evidence in data["evidence"]:
            p = user / evidence["path"][7:] if evidence["path"].startswith("user://") else in_roots(roots, evidence["path"])
            p = in_roots(roots, p); require(sha(p) == evidence["sha256"], "closed complete native packet/world/clock evidence drift")
            paths.append(p)
        pids.add(row["pid"]); nonces.add(row["nonce"]); paths.append(report_path)
        return data, step
    previous = None
    for case, count in zip(ADMIT, [39, 351, 342]):
        data, step = actual_case(case, source["reports"][case], case, count)
        if previous:
            require(data["previous_pid"] == previous["row"]["pid"] and data["previous_nonce"] == previous["row"]["nonce"]
                    and previous["step"]["native_finished_ns"] <= step["native_started_ns"], "closed original candidate6 ABC predecessor chain")
        original_cases[case] = {"data": data, "step": step, "row": source["reports"][case]}
        previous = original_cases[case]
    for key, count in [("json_boundary_report", 533), ("owned_slot_retry_report", 76)]:
        row = source[key]; p = in_roots(roots, row["path"])
        require(sha(p) == row["sha256"], "actual candidate6 regression pin drift"); data = read(p)
        require(data.get("passed") is True and len(data.get("checks", [])) == row["checks"] == count
                and all(c.get("passed") is True for c in data["checks"]), "actual source regression full checks not passed")
        paths.append(p)
    frozen = {}
    for variant, role in VARIANTS.items():
        row = source["retreat_reports"][variant + "/" + CASES[0]]
        data, step = actual_case(variant + "_" + CASES[0], row, CASES[0])
        require(data.get("schema") == "daming_safe_retreat_cross_process_report_v25" and data.get("first_role") == role
                and data.get("single_safe_disk_case_qualified") is True and data.get("natural_victory_qualified") is False
                and data.get("campaign_persistence_qualified") is False, "closed actual role A not single-safe scoped")
        index_row = source["actual_A_fixtures"][variant]; index_path = in_roots([root], index_row["path"])
        require(sha(index_path) == index_row["sha256"], "actual A freeze index SHA mismatch"); index = read(index_path)
        require(index.get("schema") == "daming_actual_A_frozen_source_v25s_r2a"
                and index.get("first_role") == role and index.get("actual_A_pid") == row["pid"]
                and index.get("actual_A_nonce") == row["nonce"] and index.get("actual_A_finished_ns") == row["finished_ns"] == step["native_finished_ns"]
                and index.get("content_version") == identity["content_version"] and index.get("engine_sha256") == source["godot_sha256"],
                "actual immutable freeze index role/native/source provenance mismatch")
        inputs = index.get("inputs"); require(isinstance(inputs, dict) and set(inputs) == {"report", "handoff", "packet", "world", "slot"}, "actual full five A inputs required")
        for item in inputs.values():
            p = pin(item); require(p.is_relative_to(root / "frozen_actual_A" / variant), "actual frozen A input escaped scope"); paths.append(p)
        require(inputs["report"]["sha256"] == row["report_sha256"], "frozen report not same native actual A")
        handoff, packet, world = (read(inputs[k]["path"]) for k in ["handoff", "packet", "world"])
        slot = actual_slot(Path(inputs["slot"]["path"]), "LH_CLASSIC_CONTINUE_SLOT", 1, "0" * 64)
        require(handoff.get("mode") == CASES[0] and handoff.get("first_role") == role
                and handoff.get("pid") == row["pid"] and handoff.get("nonce") == row["nonce"]
                and handoff.get("packet") == packet == slot and packet.get("world") == world
                and handoff.get("file_sha256") == inputs["slot"]["sha256"] == row["slot_sha256"], "full raw actual A packet/world/handoff/slot mismatch")
        profile_rows = index.get("profile_files"); require(isinstance(profile_rows, list) and profile_rows, "actual full A slot-scope journal snapshot missing")
        actual_scope = root / "frozen_actual_A" / variant / "slot_scope"; expected = {}
        for item in profile_rows:
            rel = Path(item["relative"]); p = pin(item)
            require(not rel.is_absolute() and ".." not in rel.parts and item["relative"] not in expected
                    and p == actual_scope / rel, "actual frozen scope alias/escape")
            expected[item["relative"]] = item["sha256"]; paths.append(p)
        actual = {p.relative_to(actual_scope).as_posix(): sha(p) for p in actual_scope.rglob("*") if absolute(p).is_file()}
        require(actual == expected and not any("pending" in Path(k).name.lower() for k in expected), "unsafe/incomplete/extra actual A frozen scope")
        binding = packet["binding"]; token = binding.get("token", "")
        require(binding.get("kind") == "uncredited" and re.fullmatch(r"[0-9a-f]{32}", token), "actual A lifecycle token invalid")
        journal_rel = "local_runs/" + token + "/5088120/1/record_0000000001.json"
        require(expected.get(journal_rel) == binding["receipt_sha256"]
                and expected.get("5088120/1/record_0000000001.json") == inputs["slot"]["sha256"]
                and set(expected) == {journal_rel, "5088120/1/record_0000000001.json"},
                "actual original A complete gen1 slot/active journal scope mismatch")
        require(actual_slot(actual_scope / journal_rel, "LH_LOCAL_CONTINUE_LIFECYCLE", 1, "0" * 64) == {
            "schema": "local_continue_lifecycle_v1", "generation": 1, "token": token,
            "context": {"mode": "defense", "level_id": "", "waves": 30}, "state": "active", "victory": False},
            "original actual A journal default-defense30 binding not active")
        require(packet["context"] == {"mode": "campaign", "level_id": "level8", "waves": 0} and packet["generation"] == 1,
                "actual A campaign generation/context mismatch")
        suffix = Path(index["user_suffix_under_appdata"])
        require(not suffix.is_absolute() and ".." not in suffix.parts, "unsafe source application suffix")
        paths.append(index_path); frozen[variant] = {"index": index, "index_path": index_path, "row": row, "step": step}
    require(len(pids) == len(nonces) == 5, "actual three ABC plus both A process responsibilities missing")
    require(proof.get("actual_case_pids") == sorted(pids) and proof.get("actual_case_nonces") == sorted(nonces)
            and proof.get("installed_identity_sha256") == hashlib.sha256(json.dumps(identity, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest(),
            "independent observed process/full-identity source proof does not match actual artifacts")
    profile_manifest = root / "actual_A_exploration_profile_manifest.json"
    require(sha(profile_manifest) == source["exploration_profile_manifest_sha256"], "closed complete private profile manifest drift")
    for item in read(profile_manifest):
        p = pin(item); require(p.is_relative_to(root), "closed profile file escaped actual batch")
    paths.append(profile_manifest)
    return {"source": source, "receipt_path": receipt_path, "paths": sorted(set(paths)), "roots": roots,
            "frozen": frozen, "pids": pids, "nonces": nonces, "original_cases": original_cases}


def check_reuse_review(args):
    require(sha(args.full_producer) == FULL_SHA, "corrected full r2b2/e61 immutable source required")
    ast.parse(args.full_producer.read_text(encoding="utf-8-sig"))
    review = read(args.reuse_review)
    require(review.get("schema") == "daming_safe_retreat_full_reuse_review_v25s_r2e1"
            and review.get("static_api_closure_passed") is True and review.get("approved_stages") == ["full_reuse_closed_both_A"]
            and pin(review["producer_pin"]) == Path(__file__).resolve()
            and pin(review["full_parent_pin"]) == args.full_producer, "new independent full-reuse source review missing")


def import_pinned(path, digest, name):
    require(sha(path) == digest, "immutable imported producer drift")
    spec = importlib.util.spec_from_file_location(name, path); module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module; spec.loader.exec_module(module); return module


def runner_class(base, parent, explorer, full):
    Full = full.runner_class(base, parent, explorer)

    class Reuse(Full):
        def __init__(self, args, run, reviewed, matrix, interfaces, extra, closed):
            super().__init__(args, run, reviewed, matrix, interfaces, extra)
            self.closed = closed
            self.receipt.update(schema="daming_safe_retreat_full_reuse_batch_v25s_r2e1", producer_sha256=sha(Path(__file__)),
                full_parent_sha256=FULL_SHA, execution_scope="full_reuse_closed_both_A", overall_v25_qualified=False,
                source_exploration_receipt_sha256=sha(closed["receipt_path"]), source_exploration_producer_sha256=closed["source"]["producer_sha256"],
                historical_real_gameplay_responsibilities=5, newly_required_gameplay_processes=6,
                mandatory_negative_native_stages=52, historical_source_is_full_v25=False,
                source_failed_prefix_remains_failed=closed["source"].get("source_prefix_batch_complete") is False,
                responsibility_boundary="Actual historical candidate6 ABC plus both A and fresh six BCD + exact52 negative stages. No historical execution is claimed as newly launched.")

        def preflight(self):
            check_reuse_review(self.args); self.closed = check_closed_source(self.args)
            super().preflight()  # exact e61 nullable-presence/full packet/native/source guards
            source = self.closed["source"]
            base.require(self.inputs == source["source_files"] and self.native == source["native_dependencies"],
                         "fresh full candidate source/native dependencies differ from actual closed source")
            base.require(base.installed_identity(Path(source["project"])) == source["installed_identity"], "closed whole installed5102 identity drift")
            for p in [Path(__file__).resolve(), self.args.full_producer, self.args.reuse_review, *self.closed["paths"]]:
                self.code_pins[str(p)] = sha(p)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": s} for p, s in self.code_pins.items()]
            self.input_integrity()

        def prepare(self):
            super().prepare()
            base.require(self.installed == self.closed["source"]["installed_identity"]
                         and self.receipt["native_installed_files"] == self.closed["source"]["native_installed_files"],
                         "fresh full project complete runtime/native identity differs from closed actual A")
            self.input_integrity(True)

        def copy_closed_sources(self):
            """Frozen source copies only; never mount/recover/migrate original profile."""
            source = self.closed["source"]
            for case in ADMIT:
                row = copy.deepcopy(source["reports"][case])
                self.reports[case] = row
                self.receipt["reports"][case] = dict(row, evidence_origin="closed_actual_source", executed_in_this_batch=False,
                    source_receipt_sha256=sha(self.closed["receipt_path"]))
            for key in ["json_boundary_report", "owned_slot_retry_report"]:
                self.receipt[key] = dict(source[key], evidence_origin="closed_actual_source", executed_in_this_batch=False,
                                        source_receipt_sha256=sha(self.closed["receipt_path"]))
            self.execution_pids.update(self.closed["pids"]); self.execution_nonces.update(self.closed["nonces"])
            copied = []
            for variant, provenance in self.closed["frozen"].items():
                original = provenance["index"]; target = self.run / "frozen_actual_A" / variant
                target.mkdir(parents=True, exist_ok=False); index = copy.deepcopy(original)
                for name, row in index["inputs"].items():
                    p = pin(row); new = target / (name + ".json"); self.copy_checked(p, new, row["sha256"])
                    row["path"] = str(new); row["closed_source_frozen_path"] = str(p)
                    self.code_pins[str(new)] = row["sha256"]; copied.append({"source": str(p), "target": str(new), "sha256": row["sha256"]})
                for row in index["profile_files"]:
                    p = pin(row); new = target / "slot_scope" / row["relative"]
                    new.parent.mkdir(parents=True, exist_ok=True); self.copy_checked(p, new, row["sha256"])
                    row["path"] = str(new); row["closed_source_frozen_path"] = str(p)
                    self.code_pins[str(new)] = row["sha256"]; copied.append({"source": str(p), "target": str(new), "sha256": row["sha256"]})
                index["source_origin"] = {"receipt": str(self.closed["receipt_path"]), "receipt_sha256": sha(self.closed["receipt_path"]),
                    "original_index": str(provenance["index_path"]), "original_index_sha256": sha(provenance["index_path"]),
                    "A_executed_in_this_batch": False}
                path = target / "index.json"; base.dump_new(path, index); self.code_pins[str(path)] = sha(path)
                self.frozen_a[variant] = index
                self.receipt.setdefault("actual_A_fixtures", {})[variant] = {"path": str(path), "sha256": sha(path),
                    "actual_A_pid": index["actual_A_pid"], "actual_A_nonce": index["actual_A_nonce"],
                    "profile_files_count": len(index["profile_files"]), "evidence_origin": "closed_actual_source", "executed_in_this_batch": False}
            path = self.run / "closed_A_copy_manifest.json"; base.dump_new(path, copied)
            self.code_pins[str(path)] = sha(path); self.receipt["closed_A_copy_manifest_sha256"] = sha(path)
            self.input_integrity(True)

        def seed_role(self, variant, group):
            self.activate_group(group); fixture = self.frozen_a[variant]
            self.own_a_profile(group, fixture)  # exact original journal + gen1 + raw actual A handoff
            user = self.profile / "appdata" / fixture["user_suffix_under_appdata"]
            slot_path = user / "daming_safe_retreat_v25/continue/v1/5088120/1/record_0000000001.json"
            slot = self.disk_envelope(slot_path, "LH_CLASSIC_CONTINUE_SLOT", 1, "0" * 64)
            original = self.closed["frozen"][variant]["row"]
            base.require(slot["sha256"] == original["slot_sha256"] and slot["document"] == read(fixture["inputs"]["packet"]["path"]),
                         "fresh continuation seeded from different actual A")
            retained = self.run / "retained_slots" / variant / "generation_1.json"
            retained.parent.mkdir(parents=True, exist_ok=True); self.copy_checked(slot_path, retained, slot["sha256"])
            slot["retained_path"] = str(retained)
            row = copy.deepcopy(original); row["slot"] = slot; row["report"] = fixture["inputs"]["report"]["path"]
            row.update(evidence_origin="closed_actual_source", executed_in_this_batch=False,
                       original_actual_A_report=original["report"], source_receipt_sha256=sha(self.closed["receipt_path"]))
            self.retreat_reports[(variant, CASES[0])] = row
            self.receipt.setdefault("retreat_reports", {})[variant + "/" + CASES[0]] = row
            self.input_integrity(True)

        def native_phase(self, label, arguments, env, timeout_seconds, validator):
            def strict(step, text):
                clean = ANSI.sub("", text); base.require(not ERRORS.search(clean), "ANSI-prefixed native engineering error")
                validator(step, clean)
            return super().native_phase(label, arguments, env, timeout_seconds, strict)

        def execute(self):
            self.preflight(); self.wait_prior()
            with self.stage("wait_natural_engine_idle") as step:
                self.wait_idle(); step["foreign_engines_at_idle"] = base.engine_rows()
            self.prepare()
            env = self.env.copy(); env.update(DAMING_ADMIT_CASE=ADMIT[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            def imported(step, text):
                base.require(step.get("exit_code") == 0 and step.get("process_terminal") is True, "fresh full native import failed")
                self.input_integrity(True)
            self.native_phase("import", ["--headless", "--editor", "--import", "--quit"], env, 900, imported)
            env = self.env.copy(); env.update(DAMING_ADMIT_PROFILE=str(self.profile / "mismatch"), DAMING_ADMIT_CASE=ADMIT[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            def guarded(step, text):
                base.require(step.get("exit_code") == 2 and "PRIVATE_PROFILE_REQUIRED" in text and not (self.output / ADMIT[0]).exists()
                             and not list((self.profile / "appdata").rglob("handoff_A.json")), "fresh full private-profile guard failed")
            self.native_phase("profile_guard", ["--headless", "res://tools/daming_admit_cross_process_v24s.tscn"], env, 300, guarded)
            self.copy_closed_sources()
            for variant, role in VARIANTS.items():
                group = self.new_group(variant); self.activate_group(group)
                nonce = uuid.uuid4().hex; env = self.env.copy()
                env.update(DAMING_RETREAT_PROFILE=str(self.profile / "mismatch"), DAMING_RETREAT_CASE=CASES[0],
                           DAMING_RETREAT_FIRST_ROLE=role, DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                def role_guarded(step, text):
                    base.require(step.get("exit_code") == 2 and "DAMING_RETREAT PRIVATE_PROFILE_REQUIRED" in text
                                 and not (self.output / CASES[0]).exists()
                                 and not list((self.profile / "appdata").rglob("handoff_A.json")), "new full role guard failed before seed")
                self.native_phase(variant + "_profile_guard", ["--headless", "res://tools/" + self.args.retreat_scene.name], env, 300, role_guarded)
                self.seed_role(variant, group)
                self.run_negatives(variant)  # exact e61 three consumers, including all24 live cases
                for case in CASES[1:]:
                    self.activate_group(group); nonce = uuid.uuid4().hex; env = self.env.copy()
                    env.update(DAMING_RETREAT_CASE=case, DAMING_RETREAT_FIRST_ROLE=role,
                               DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                    self.native_phase(variant + "_" + case, ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                        "--resolution", "1280x720", "--position", "30000,30000", "res://tools/" + self.args.retreat_scene.name], env, 1200,
                        lambda step, text, variant=variant, case=case: self.validate_retreat_case(variant, case, step, text))
            with self.stage("full_reuse_exact52_eightcases_source_native_terminal_profile_audit") as step:
                self.input_integrity(True); check_closed_source(self.args)
                base.require(set(self.retreat_reports) == {(v, c) for v in VARIANTS for c in CASES}, "all8 actual natural case responsibilities mandatory")
                expected = {v + "/" + k for v in VARIANTS for k in ["world", "component"]}
                expected |= {v + "/capture/" + c for v in VARIANTS for c in self.interfaces["capture"]["required_cases"]}
                base.require(len(expected) == 52 and set(self.receipt.get("negative_reports", {})) == expected, "exact52 mandatory negative stages missing")
                new_cases = [s for s in self.receipt["steps"] if s.get("case") in {v + "_" + c for v in VARIANTS for c in CASES[1:]}]
                base.require(len(new_cases) == 6 and all(s.get("complete") is True and s.get("exit_code") == 0 for s in new_cases),
                             "all6 newly executed BCD processes required")
                for s in self.receipt["steps"]:
                    if s.get("log"):
                        p = base.no_reparse(Path(s["log"])); base.require(sha(p) == s["log_sha256"]
                            and not ERRORS.search(ANSI.sub("", p.read_text(encoding="utf-8", errors="replace"))), "final exact ANSI-aware native log gate")
                profiles = []
                for name, group in self.profile_groups.items():
                    for p in sorted(group["profile"].rglob("*")):
                        p = base.no_reparse(p)
                        if p.is_file(): profiles.append({"group": name, "path": str(p), "bytes": p.stat().st_size, "sha256": sha(p)})
                path = self.run / "all_isolated_full_profiles_manifest.json"; base.dump_new(path, profiles)
                self.receipt.update(complete=True, overall_v25_qualified=True, all_negatives_qualified=True,
                    natural_victory_qualified=True, local_terminal_once_qualified=True, campaign_persistence_qualified=False,
                    original_candidate_admit_regressions_qualified=True, actual_A_fixture_exploration_complete=True,
                    historical_real_gameplay_responsibilities=5, main_gameplay_process_responsibilities=11,
                    main_gameplay_processes_launched_here=6, actual_live_capture_native_cases=48,
                    actual_component_rows=724, actual_world_DTO_rows=528, actual_observed_case_processes=len(self.execution_pids),
                    all_isolated_profile_manifest_sha256=sha(path), root_input_drift=0, private_input_drift=0,
                    source_native_drift=0, private_native_drift=0,
                    scope="Exact actual candidate6 historical ABC+both A, new six BCD and all52 fixed negative stages. No public continue, Campaign durable progression under QA, Android, Steam credited rewards or release qualification.")
                step.update(profile_groups=len(self.profile_groups), profile_files=len(profiles), fixed_negative_stages=52,
                            historical_actual_cases=5, newly_executed_gameplay_cases=6, all_real_retreat_case_responsibilities=8)
    return Reuse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt", "cached-native-world",
                 "candidate-receipt", "boundary-harness", "boundary-manifest", "adapter-review", "runner-review", "reuse-review",
                 "closed-source-proof", "deadline-utc"]:
        parser.add_argument("--" + name, type=str if name == "deadline-utc" else Path, required=True)
    here = Path(__file__).resolve().parent
    defaults = {"full-producer": here / "run_daming_safe_retreat_v25s_r2b2_full.py", "explorer": here / "run_daming_safe_retreat_v25s_r2a_explore.py",
        "base-producer": Path("E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py"), "parent-producer": here / "run_daming_safe_retreat_v25s.py",
        "retreat-runner": here / "daming_safe_retreat_cross_process_v25s1.gd", "retreat-scene": here / "daming_safe_retreat_cross_process_v25s1.tscn",
        "retreat-route": here / "daming_safe_retreat_route_v25.gd", "capture-base": here / "daming_safe_retreat_cross_process_v25.gd",
        "capture-base-scene": here / "daming_safe_retreat_cross_process_v25.tscn", "negative-matrix": here / "ADAPTER_BUNDLE_MATRIX_V25S_R2B2.json",
        "passed-admit-successor-proof": here / "PASSED_SUCCESSOR_PROOF_V25S_ACTUAL_2A817E70.json", "proof-repository-root": Path("E:/ChatGPT/水浒"),
        "world-interface": here / "NEGATIVE_WORLD_INTERFACE_V25B2.json", "component-interface": here / "COMPONENT_NEGATIVE_INTERFACE_V25.json",
        "capture-interface": here / "CAPTURE_NEGATIVE_INTERFACE_V25D1.json", "negative-successor-review": here / "NEGATIVE_SUCCESSOR_REVIEW_V25.json",
        "component-review": here / "COMPONENT_NEGATIVE_PEER_REVIEW_V25_IMPLEMENTED_CANDIDATE.json", "capture-review": here / "CAPTURE_NEGATIVE_PEER_REVIEW_V25D1.json"}
    for name, value in defaults.items(): parser.add_argument("--" + name, type=Path, default=value)
    parser.add_argument("--closed-source-proof-sha256", required=True)
    parser.add_argument("--prior-pid", type=int); args = parser.parse_args(); args.stage = "full"
    try:
        args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
        require(args.deadline_utc.tzinfo is not None and dt.datetime.now(dt.timezone.utc) < args.deadline_utc <= DEADLINE,
                "authorized deadline invalid/reached; no implicit next-day extension")
        for key, value in vars(args).items():
            if isinstance(value, Path): setattr(args, key, absolute(value))
        check_reuse_review(args); closed = check_closed_source(args)
        require(not args.work_root.is_relative_to(args.source_root), "new full work root must be outside production ROOT")
        full = import_pinned(args.full_producer, FULL_SHA, "immutable_e61_full_for_reuse")
        reviewed, matrix, interfaces, extra = full.preflight(args)
        explorer = import_pinned(args.explorer, EXPLORER_SHA, "immutable_r2a_for_reuse")
        explorer.portable_successor(args)
        parent = import_pinned(args.parent_producer, PARENT_SHA, "immutable_v25s_for_reuse"); base = parent.load_base(args.base_producer)
        require(base.installed_identity(Path(closed["source"]["project"])) == closed["source"]["installed_identity"],
                "closed source full installed5102 identity mismatch before batch creation")
    except (Blocked, OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        print(json.dumps({"status": "BLOCKED", "complete": False, "overall_v25_qualified": False,
                          "engine_batch_created": False, "engine_started": False, "reason": str(exc)}, ensure_ascii=False), flush=True)
        return 2
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("v25_full_reuse_r2e1_" + uuid.uuid4().hex[:8]); run.mkdir(exist_ok=False)
    runner = runner_class(base, parent, explorer, full)(args, run, reviewed, matrix, interfaces, extra, closed)
    code = 0
    try: runner.execute()
    except BaseException as exc:
        code = 1; runner.receipt["complete"] = False; runner.receipt["overall_v25_qualified"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        for action in [runner.stop_owned, runner.release]:
            try: action()
            except BaseException as exc:
                code = 1; runner.receipt["complete"] = False; runner.receipt["overall_v25_qualified"] = False
                runner.receipt.setdefault("finalization_failures", []).append({"type": type(exc).__name__, "message": str(exc)})
        try: runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            code = 1; runner.receipt["lock_released"] = False; runner.receipt["lock_audit_failure"] = str(exc)
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["overall_v25_qualified"] = runner.receipt["overall_v25_qualified"] and runner.receipt["complete"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat(); base.dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"], "overall_v25_qualified": runner.receipt["overall_v25_qualified"],
                          "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
