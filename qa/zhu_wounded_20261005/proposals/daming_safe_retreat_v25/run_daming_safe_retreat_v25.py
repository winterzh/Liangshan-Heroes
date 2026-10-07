"""UNEXECUTED v25 sibling. Reviews/missing negative implementation block before a batch.

Reuse the immutable r2 freeze/identity/engine ownership and original regression
implementation. No changes to that file, no production private runtime patches.
This file has only AST compilation, not a CLI/import/native qualification.
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
BASE_SHA = "1b486f16c955d5a54b7e7e15e570fc66e3573cc9f02581d6027e5a73be725fb4"
DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
CHANGED = {"scripts/run_snapshot_store.gd", "scripts/run_slot_store.gd",
           "scripts/run_level8_unit_contract.gd", "scripts/run_battle_world_core.gd"}
ADDED = {"scripts/run_scenery_json_boundary.gd", "scripts/run_scenery_json_boundary.gd.uid"}
RETREAT_CASES = ("A_single_save", "B_install_settle_resave", "C_install_finish", "D_read_terminal")
VARIANTS = {"lu_first": "lu", "shi_first": "shi"}
CATEGORIES = {"refs_queue", "actual_stop_fields", "other_actor_live_root_active",
              "selection_and_caster", "five_record_identity_primitive_guards"}
INHERITED_INSTALL_LABELS = {
    "correct preceding genuinely distinct process", "prior disk bytes and generation verified",
    "same frozen source and actual engine across processes", "actual Session prepare_restore succeeds",
    "actual Session paused stage_mount succeeds", "actual Session commit_restore_async succeeds",
    "fresh full Core capture at real restored HELD", "complete whole-world envelope and field set exact",
    "whole-world schema/profile/context/content/engine envelope exact", "complete exact section keyset retained",
    "every non-payload mission wrapper field exact", "every non-payload root wrapper field exact",
    "full Root clock subfield schemas exact", "all complete non-root sections exact after independent install",
    "Mission complete wall age rebased within real prepare/capture intervals",
    "Root logical tick/cache phase and mount/HELD input clock contract exact",
    "all Root non-clock values/references/grids/economy exact", "every Session Campaign option installed exactly",
    "every Session setting installed exactly", "every installed profile flag exact after Session commit",
    "Session context and saved resume pause actually installed", "actual durable local lifecycle binding exact",
    "Steam-disabled Session active lease/context installed", "complete saved Visual root_node installed exactly at HELD",
}


class PrerequisiteBlocked(RuntimeError):
    pass


def require(value, message):
    if not value:
        raise PrerequisiteBlocked(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def safe_absolute(path):
    p = Path(path)
    require(p.is_absolute(), "absolute path required: " + str(path))
    for q in [p, *p.parents]:
        if q.exists() or q.is_symlink():
            info = q.lstat()
            require(not q.is_symlink() and not getattr(info, "st_file_attributes", 0) & 0x400,
                    "link/reparse path refused: " + str(q))
    return p.resolve()


def verify_pin(row):
    require(isinstance(row, dict) and isinstance(row.get("path"), str)
            and type(row.get("bytes")) is int and row["bytes"] > 0
            and isinstance(row.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", row["sha256"]),
            "pin row shape invalid")
    p = safe_absolute(row["path"])
    require(p.is_file() and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"],
            "reviewed input drift: " + str(p))
    return p


def check_prerequisites(args):
    """Read only. Called before import base, mkdir run, source lock, wait, or Godot."""
    require(args.base_producer.is_file() and sha(args.base_producer) == BASE_SHA,
            "EXPLICIT_IMMUTABLE_R2_BASE_MISSING_OR_CHANGED")
    ast.parse(args.base_producer.read_text(encoding="utf-8-sig"))
    require(args.boundary_harness is not None and args.boundary_manifest is not None,
            "MANDATORY_JSON11_REGRESSION_NOT_SUPPLIED")
    require(args.runner_review.is_file(), "V25_RUNNER_REVIEW_MISSING")
    review = read(args.runner_review)
    require(review.get("schema") == "daming_safe_retreat_runner_cross_review_v25"
            and review.get("review_status") == "static_api_closure_no_identified_execution_blocker_native_pending",
            "V25_RUNNER_API_REVIEW_NOT_CLOSED")
    reviewed = {verify_pin(row) for row in review.get("candidate_pins", [])}
    require({args.retreat_runner, args.retreat_scene, args.retreat_route} <= reviewed,
            "V25_RUNNER_MODULE_OR_SCENE_NOT_REVIEW_PINNED")
    require(args.negative_matrix.is_file(), "V25_NEGATIVE_SUITE_NOT_IMPLEMENTED: implementation matrix missing")
    matrix = read(args.negative_matrix)
    require(matrix.get("schema") == "daming_retreat_negative_implementation_matrix_v25"
            and matrix.get("implemented") is True and matrix.get("api_review_complete") is True,
            "V25_NEGATIVE_SUITE_NOT_IMPLEMENTED: matrix or API review incomplete")
    harnesses = matrix.get("harnesses")
    require(isinstance(harnesses, list) and len(harnesses) == 2
            and len({h.get("id") for h in harnesses}) == 2,
            "V25_TWO_NEGATIVE_HARNESSES_NOT_IMPLEMENTED")
    require(set(matrix.get("covered_categories", [])) >= CATEGORIES,
            "V25_REQUIRED_FIVE_NEGATIVE_CATEGORIES_MISSING")
    require(set(matrix.get("required_routes", [])) >= {"source", "json"},
            "V25_SOURCE_JSON_NEGATIVE_ROUTES_MISSING")
    pins = [verify_pin(row) for row in matrix.get("pins", [])]
    for h in harnesses:
        require(isinstance(h, dict) and h.get("implemented") is True and h.get("api_review_complete") is True,
                "V25_NEGATIVE_HARNESS_NOT_IMPLEMENTED")
        require(isinstance(h.get("id"), str) and re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", h["id"]),
                "V25_NEGATIVE_HARNESS_ID_UNSAFE")
        require(h.get("consumer_schema") == "v25_producer_negative_descriptor_v1",
                "V25_NEGATIVE_REPORT_API_ADAPTER_NOT_REVIEWED")
        for key in ["gd", "scene", "static_review"]:
            require(safe_absolute(h[key]) in pins, "V25_NEGATIVE_HARNESS_FILE_NOT_PINNED: " + key)
        require(isinstance(h.get("report_schema"), str) and h["report_schema"]
                and isinstance(h.get("terminal_marker"), str) and h["terminal_marker"]
                and isinstance(h.get("env"), dict) and h["env"], "negative API descriptor incomplete")
        require(isinstance(h.get("required_checks"), list) and h["required_checks"]
                and isinstance(h.get("expected_flags"), dict) and h["expected_flags"],
                "negative independent mandatory checks/flags absent")
        rows = h.get("required_rows")
        require(isinstance(rows, list) and rows and all(
            isinstance(r, dict) and r.get("route") in {"source", "json"}
            and isinstance(r.get("id"), str) and r["id"] and isinstance(r.get("code"), str)
            and r["code"] and isinstance(r.get("path"), str) and r["path"] for r in rows),
            "negative exact row/code/path matrix absent")
        require(len({(r["id"], r["route"]) for r in rows}) == len(rows), "negative duplicate matrix row")
        require({r["route"] for r in rows} == {"source", "json"}, "negative harness lacks one required boundary route")
    return review, matrix


def load_base(path):
    spec = importlib.util.spec_from_file_location("immutable_daming_v24r2_for_v25", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Only approved producer metadata changes. No runtime/source file is patched.
    module.CANDIDATE_CHANGED_PATHS = CHANGED.copy()
    module.CANDIDATE_ADDED_PATHS = ADDED.copy()
    require(Path(module.__file__).resolve() == path, "explicit base module identity changed")
    require(module.CURRENT_CANDIDATE_INSTALLED_FILE_COUNT == 5102, "base runtime count changed")
    return module


def runner_class(base):
    class V25Runner(base.Runner):
        def __init__(self, args, run, reviewed, matrix):
            super().__init__(args, run)
            self.reviewed, self.matrix = reviewed, matrix
            self.retreat_reports, self.profile_groups, self.execution_pids, self.execution_nonces = {}, {}, set(), set()
            self.receipt.update(schema="daming_safe_retreat_batch_v25", complete=False,
                                producer_sha256=sha(Path(__file__)), base_producer_sha256=sha(args.base_producer),
                                natural_victory_qualified=False, local_terminal_once_qualified=False,
                                campaign_persistence_qualified=False, callback_invocation_count_qualified=False,
                                negative_matrix_sha256=sha(args.negative_matrix), runner_review_sha256=sha(args.runner_review),
                                scope="Original JSON/OwnedSlot/admit regressions plus both actual single-safe disk/terminal variants and reviewed source/JSON negative matrix; no public continue, Campaign persistence, Steam reward or release qualification.")

        def preflight(self):
            # Recheck gate after startup, before inherited donor/import source reads.
            check_prerequisites(self.args)
            super().preflight()
            for p in [Path(__file__).resolve(), self.args.base_producer, self.args.runner_review,
                      self.args.negative_matrix, self.args.retreat_runner, self.args.retreat_scene,
                      self.args.retreat_route, *[safe_absolute(row["path"]) for row in self.matrix["pins"]]]:
                self.code_pins[str(p)] = sha(p)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": digest} for p, digest in self.code_pins.items()]
            self.input_integrity()

        def select_candidate(self, baseline_grouped, cache_project):
            receipt = base.read(self.args.candidate_receipt)
            rows = receipt.get("files")
            base.require(isinstance(rows, list) and len(rows) == 6
                         and {r.get("path") for r in rows} == CHANGED | ADDED,
                         "combined actual ROOT candidate must contain exact four replacements and two additions")
            self.candidate_rows = {r["path"]: r for r in rows}
            for path, row in self.candidate_rows.items():
                base.relative_path(path)
                base.require(type(row.get("bytes")) is int and row["bytes"] > 0
                             and re.fullmatch(r"[0-9a-f]{64}", row.get("after_sha256", "")), "candidate row invalid")
                actual = base.no_reparse(self.root / path)
                base.require(actual.is_file() and actual.stat().st_size == row["bytes"]
                             and base.sha(actual) == row["after_sha256"], "actual ROOT candidate changed: " + path)
                if path in CHANGED:
                    base.require(path in baseline_grouped
                                 and row.get("before_sha256") == baseline_grouped[path][0]["sha256"]
                                 and row["before_sha256"] != row["after_sha256"]
                                 and base.sha(cache_project / path) == row["before_sha256"], "candidate not from original donor: " + path)
                else:
                    base.require(row.get("before_sha256") is None and path not in baseline_grouped
                                 and path not in {r["path"] for r in self.cache_installed["files"]}
                                 and not (cache_project / path).exists(), "candidate addition already in original donor")
            self.inputs = []
            for old in self.baseline_inputs:
                row = self.candidate_rows.get(old["path"])
                self.inputs.append({"path": old["path"], "bytes": row["bytes"], "sha256": row["after_sha256"]}
                                   if row else dict(old))
            for path in sorted(ADDED):
                row = self.candidate_rows[path]
                self.inputs.append({"path": path, "bytes": row["bytes"], "sha256": row["after_sha256"]})
            base.require(len(self.inputs) == 5041 and len({r["path"] for r in self.inputs}) == 5037,
                         "raw5041/distinct5037 candidate drift")
            self.code_pins[str(self.args.candidate_receipt)] = sha(self.args.candidate_receipt)
            self.receipt.update(source_files=self.inputs, qualified_baseline_source_files=self.baseline_inputs,
                                candidate_source_bridge={"receipt": str(self.args.candidate_receipt),
                                    "receipt_sha256": sha(self.args.candidate_receipt), "files": rows,
                                    "private_runtime_patches": 0, "candidate_runtime_qualified": False})
            self.receipt["manifest_inventory"].update(raw_rows=5041, distinct_paths=5037,
                                                    qualified_baseline_raw_rows=5039, qualified_baseline_distinct_paths=5035)

        def prepare(self):
            # Base __file__ remains the explicitly imported old proposal path.
            # Its old A/B/C tools, metadata and identity code need no copy/edit.
            super().prepare()
            self.profile_groups["original_admit"] = {"profile": self.profile, "output": self.output, "env": self.env.copy()}
            additions = self.receipt["added_qa_files"]
            paths = [self.args.retreat_runner, self.args.retreat_scene, self.args.retreat_route]
            paths += [safe_absolute(h[k]) for h in self.matrix["harnesses"] for k in ["gd", "scene"]]
            targets = set()
            for source in paths:
                relative = "tools/" + source.name
                base.require(relative not in targets and not (self.project / relative).exists(), "duplicate extra QA filename")
                targets.add(relative)
                self.copy_checked(source, self.project / relative, self.code_pins[str(source)])
                additions.append({"path": relative, "bytes": source.stat().st_size, "sha256": sha(source),
                                  "kind": "reviewed additional v25 QA outside runtime roots"})
            self.input_integrity(True)
            base.require(base.installed_identity(self.project) == self.installed
                         and self.installed["file_count"] == 5102, "QA additions changed complete runtime")

        def new_group(self, name):
            root = self.run / "profiles" / name
            out = self.run / "native_evidence_groups" / name
            root.mkdir(parents=True, exist_ok=False)
            out.mkdir(parents=True, exist_ok=False)
            for key in ["appdata", "localappdata", "temp", "tmp"]: (root / key).mkdir()
            env = self.profile_groups["original_admit"]["env"].copy()
            for key in list(env):
                if key.startswith(("DAMING_ADMIT_", "DAMING_RETREAT_", "V25_NEGATIVE_")): env.pop(key)
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]: env[key] = str(root / key.lower())
            env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1",
                       DAMING_RETREAT_QA="1", DAMING_RETREAT_PROFILE=str(root), DAMING_RETREAT_OUT=str(out),
                       DAMING_RETREAT_EXPECT_CONTENT=self.installed["content_version"],
                       DAMING_RETREAT_EXPECT_ENGINE=self.receipt["godot_sha256"])
            group = {"profile": root, "output": out, "env": env}
            self.profile_groups[name] = group
            return group

        def activate_group(self, group):
            self.profile, self.output, self.env = group["profile"], group["output"], group["env"].copy()

        def claim_process(self, step, report, previous=None):
            base.require(step.get("exit_code") == 0 and step.get("process_terminal") is True,
                         "actual native process not terminal zero")
            pid, nonce = step["pid"], step["process_nonce"]
            base.require(report.get("pid") == pid and report.get("nonce") == nonce
                         and pid not in self.execution_pids and nonce and nonce not in self.execution_nonces,
                         "PID/nonce not actual unique child")
            if previous:
                base.require(previous["finished_ns"] <= step["native_started_ns"]
                             and report.get("previous_pid") == previous["pid"]
                             and report.get("previous_nonce") == previous["nonce"], "predecessor process chain broken")
            self.execution_pids.add(pid); self.execution_nonces.add(nonce)
            trusted = report.get("trusted", {})
            base.require(trusted.get("content_version") == self.installed["content_version"]
                         and trusted.get("engine_binary_sha256") == self.receipt["godot_sha256"],
                         "actual runtime Provider identity changed")

        def verify_evidence(self, report):
            rows = report.get("evidence")
            base.require(isinstance(rows, list) and rows, "complete native evidence list absent")
            for row in rows:
                p = self.evidence_path(report, row["path"])
                base.require(p.is_file() and sha(p) == row["sha256"], "native evidence changed: " + str(p))

        def disk_envelope(self, path, magic, generation, previous):
            p = base.no_reparse(path)
            base.require(p.is_file(), "actual owned record missing")
            raw = p.read_bytes()
            env = json.loads(raw.decode("utf-8"))
            base.require(set(env) == {"magic", "version", "app", "owner", "revision", "previous_sha256", "payload_bytes", "payload_sha256", "payload"}
                         and all(type(v) is str for v in env.values()) and env["magic"] == magic
                         and env["version"] == "1" and env["app"] == "5088120" and env["owner"] == "1"
                         and env["revision"] == str(generation) and env["previous_sha256"] == previous,
                         "actual disk chain envelope identity mismatch")
            payload = env["payload"].encode("utf-8")
            base.require(env["payload_bytes"] == str(len(payload))
                         and env["payload_sha256"] == hashlib.sha256(payload).hexdigest(), "actual payload bytes/hash wrong")
            return {"path": str(p), "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                    "document": json.loads(env["payload"]), "previous_sha256": previous}

        def userdata(self, report):
            p = base.no_reparse(Path(report["actual_user_data_dir"]).resolve())
            base.require(p.is_relative_to((self.profile / "appdata").resolve()), "native userdata escaped group profile")
            return p

        def retreat_slot(self, variant, report, generation):
            user = self.userdata(report)
            prior = "0" * 64 if generation == 1 else self.retreat_reports[(variant, RETREAT_CASES[0])]["slot_sha256"]
            path = user / "daming_safe_retreat_v25/continue/v1/5088120/1" / (f"record_{generation:010d}.json")
            result = self.disk_envelope(path, "LH_CLASSIC_CONTINUE_SLOT", generation, prior)
            doc = result["document"]
            base.require(doc.get("context") == {"mode": "campaign", "level_id": "level8", "waves": 0}
                         and doc.get("generation") == generation and doc.get("binding", {}).get("kind") == "uncredited",
                         "retreat disk packet context/generation/binding wrong")
            target = self.run / "retained_slots" / variant / (f"generation_{generation}.json")
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists(): self.copy_checked(path, target, result["sha256"])
            else: base.require(sha(target) == result["sha256"], "retained retreat slot drift")
            result["retained_path"] = str(target)
            return result

        def terminal_files(self, variant, report, terminal_handoff):
            user = self.userdata(report)
            token = terminal_handoff["slot_binding"]["token"]
            base.require(isinstance(token, str) and re.fullmatch(r"[0-9a-f]{32}", token), "actual terminal token invalid")
            directory = user / "daming_safe_retreat_v25/continue/v1/local_runs" / token / "5088120/1"
            one = self.disk_envelope(directory / "record_0000000001.json", "LH_LOCAL_CONTINUE_LIFECYCLE", 1, "0" * 64)
            two = self.disk_envelope(directory / "record_0000000002.json", "LH_LOCAL_CONTINUE_LIFECYCLE", 2, one["sha256"])
            for generation, row in [(1, one), (2, two)]:
                doc = row["document"]
                base.require(set(doc) == {"schema", "generation", "token", "context", "state", "victory"}
                             and doc["schema"] == "local_continue_lifecycle_v1" and doc["generation"] == generation
                             and doc["token"] == token and doc["context"] == {"mode": "defense", "level_id": "", "waves": 30}
                             and doc["state"] == ("active" if generation == 1 else "terminal")
                             and doc["victory"] is (generation == 2), "terminal actual document identity/transition mismatch")
            base.require(terminal_handoff["terminal"]["document"] == two["document"]
                         and terminal_handoff["terminal"]["file_sha256"] == two["sha256"], "native terminal handoff differs from actual chain")
            campaign = terminal_handoff["campaign_file"]
            campaign_path = user / "campaign.cfg"
            if campaign.get("exists") is True:
                row = campaign["file"]
                base.require(row["relative_user_path"] == "campaign.cfg" and campaign_path.is_file()
                             and sha(campaign_path) == row["sha256"] and campaign_path.stat().st_size == row["bytes"],
                             "QA existing Campaign file drift")
            else: base.require(campaign == {"exists": False} and not campaign_path.exists(), "QA created unexpected Campaign persistence")
            return {"active": one, "terminal": two, "campaign_file": campaign}

        def validate_retreat_case(self, variant, case, step, text):
            path = self.output / case / "report.json"
            data = base.read(path)
            base.require(data.get("schema") == "daming_safe_retreat_cross_process_report_v25"
                         and data.get("case") == case and data.get("first_role") == VARIANTS[variant]
                         and data.get("passed") is True and isinstance(data.get("checks"), list) and data["checks"]
                         and all(row.get("passed") is True for row in data["checks"]), "v25 actual checks/schema/role incomplete")
            index = RETREAT_CASES.index(case)
            previous = self.retreat_reports.get((variant, RETREAT_CASES[index - 1])) if index else None
            self.claim_process(step, data, previous)
            self.verify_evidence(data)
            base.require("DAMING_RETREAT_V25_COMPLETE " + case in text, "retreat terminal marker missing")
            for key in ["public_campaign_continue_qualified", "campaign_persistence_qualified",
                        "steam_reward_once_qualified", "callback_invocation_count_qualified"]:
                base.require(data.get(key) is False, "retreat scope overclaim: " + key)
            base.require(data.get("teleports") == data.get("fixture_ticks") == data.get("progress_injections") == 0
                         and data.get("clock_acceleration") is False, "retreat synthetic route detected")
            labels = {r["label"] for r in data["checks"]}
            mandatory = {"producer pinned exact installed content and engine"}
            if case in RETREAT_CASES[:3]: mandatory.add("one safe actor remains coherent full FIGHT")
            if case == RETREAT_CASES[0]:
                mandatory |= {"fresh profile has no previous level8 result", "real safe report appears once and other report absent",
                              "single safe full state HELD", "complete Session save_held succeeds", "actual committed disk head matches receipt"}
                base.require(data.get("single_safe_disk_case_qualified") is True and data.get("natural_victory_qualified") is False,
                             "A natural save eligibility missing")
            elif case in RETREAT_CASES[1:3]: mandatory |= INHERITED_INSTALL_LABELS
            if case == RETREAT_CASES[1]:
                mandatory |= {"B independently installed generation1 and no driver commands", "B observed real ordinary clock ticks",
                              "B Mission elapsed follows real physics ticks", "safe actor report/action/control identity does not replay or revive",
                              "complete Session save_held succeeds"}
                base.require(data.get("orders") == 0 and data.get("single_safe_disk_case_qualified") is True,
                             "B issued commands or failed resave")
            if case == RETREAT_CASES[2]:
                mandatory |= {"C independent generation2 install and no driver commands", "actual durable local terminal completes before outcome claim",
                              "one observed natural durable terminal notification", "normal completion froze actual Mission result",
                              "same-run local campaign core result present in memory", "private Steam service performs zero credited settlement",
                              "actual terminal HUD displayed after completion", "safe and victory reports each exactly once",
                              "post-terminal normal frames add no result or callback signal", "actual terminal preserves last complete generation2 slot bytes"}
                base.require(data.get("natural_victory_qualified") is True and data.get("local_terminal_readback_qualified") is False,
                             "C actual natural terminal not qualified")
            if case == RETREAT_CASES[3]:
                mandatory |= {"new process verifies old slot remains exact generation2", "new process exact terminal receipt full readback",
                              "new process reloads prior Campaign baseline because QA suppressed write",
                              "actual Session refuses obsolete active slot after durable terminal",
                              "terminal rejected before any new Battle Unit or graph allocation"}
                base.require(data.get("orders") == 0 and data.get("local_terminal_readback_qualified") is True
                             and data.get("natural_victory_qualified") is False, "D terminal-only readback eligibility wrong")
            base.require(mandatory <= labels, "missing v25 strict coverage: " + str(sorted(mandatory - labels)))
            slot = self.retreat_slot(variant, data, 1 if index == 0 else 2)
            user = self.userdata(data)
            if index <= 1:
                hpath = user / "daming_safe_retreat_v25" / ("handoff_A.json" if index == 0 else "handoff_B.json")
                hand = base.read(hpath)
                base.require(hand["pid"] == step["pid"] and hand["nonce"] == step["process_nonce"]
                             and hand["mode"] == case and hand["first_role"] == VARIANTS[variant]
                             and hand["file_sha256"] == slot["sha256"] and hand["packet"] == slot["document"],
                             "actual retreat save handoff mismatch")
            else:
                hand = base.read(user / "daming_safe_retreat_v25/terminal_C.json")
                base.require(hand["slot_file_sha256"] == slot["sha256"] and hand["slot_generation"] == 2
                             and hand["slot_binding"] == slot["document"]["binding"]
                             and hand["campaign_persistence_qualified"] is False, "terminal saved slot/state scope changed")
                if index == 2: base.require(hand["pid"] == step["pid"] and hand["nonce"] == step["process_nonce"], "C terminal producer mismatch")
                else: base.require(hand["pid"] == previous["pid"] and hand["nonce"] == previous["nonce"], "D did not read C terminal")
                terminal = self.terminal_files(variant, data, hand)
                self.receipt.setdefault("terminal_records", {})[variant + "/" + case] = terminal
            if index in [0, 2]:
                commands = base.read(self.output / case / "route_commands.json")
                base.require(isinstance(commands, list) and commands and len(commands) == data["orders"]
                             and all(r.get("ids") and isinstance(r.get("attack_move"), bool) for r in commands),
                             "actual ordinary route command provenance missing")
            row = {"pid": step["pid"], "nonce": step["process_nonce"], "finished_ns": step["native_finished_ns"],
                   "report": str(path), "report_sha256": sha(path), "slot_sha256": slot["sha256"], "slot": slot,
                   "checks": len(data["checks"]), "first_role": VARIANTS[variant]}
            self.retreat_reports[(variant, case)] = row
            self.receipt.setdefault("retreat_reports", {})[variant + "/" + case] = row
            step.update(report=str(path), report_sha256=sha(path), checks=len(data["checks"]), group=variant)

        def negative_inputs(self, variant):
            a = self.retreat_reports[(variant, RETREAT_CASES[0])]
            folder = Path(a["report"]).parent
            files = {"report": Path(a["report"]), "slot": Path(a["slot"]["path"]),
                     "packet": folder / "saved_packet.json", "world": folder / "saved_world.json"}
            report = base.read(files["report"])
            files["handoff"] = Path(report["actual_user_data_dir"]) / "daming_safe_retreat_v25/handoff_A.json"
            for p in files.values(): base.require(p.is_file() and base.no_reparse(p).is_relative_to(self.run), "actual A fixture missing/escaped")
            return {k: {"path": str(p), "bytes": p.stat().st_size, "sha256": sha(p)} for k, p in files.items()}

        def run_negatives(self, variant):
            fixture = self.negative_inputs(variant)
            for h in self.matrix["harnesses"]:
                group = self.new_group("negative_" + variant + "_" + h["id"])
                self.activate_group(group)
                frozen = self.output / "actual_A_fixture_inputs.json"
                base.dump_new(frozen, {"schema": "v25_actual_single_safe_fixture_inputs", "variant": variant,
                    "first_role": VARIANTS[variant], "inputs": fixture,
                    "content_version": self.installed["content_version"], "engine_sha256": self.receipt["godot_sha256"]})
                self.code_pins[str(frozen)] = sha(frozen)
                output = self.output / "report.json"
                nonce = uuid.uuid4().hex
                values = {"profile": str(self.profile), "report": str(output), "fixtures": str(frozen),
                          "fixtures_sha256": sha(frozen), "nonce": nonce,
                          "content_version": self.installed["content_version"], "engine_sha256": self.receipt["godot_sha256"],
                          "first_role": VARIANTS[variant], "variant": variant}
                env = self.env.copy()
                # r2's monitor records this key; native descriptor also receives the same nonce.
                env["DAMING_ADMIT_NONCE"] = nonce
                for key, source in h["env"].items():
                    base.require(re.fullmatch(r"[A-Z][A-Z0-9_]+", key) and key not in {"PATH", "HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "TEMP", "TMP", "STEAM_DISABLED", "CAMPAIGN_QA"}
                                 and source in values, "negative env descriptor outside fixed API")
                    env[key] = values[source]

                def validate(step, log, descriptor=h, report_path=output):
                    data = base.read(report_path)
                    base.require(data.get("schema") == descriptor["report_schema"] and descriptor["terminal_marker"] in log,
                                 "negative actual report/schema/terminal marker missing")
                    self.claim_process(step, data)
                    base.require(data.get("passed") is True and isinstance(data.get("checks"), list) and data["checks"]
                                 and all(r.get("passed") is True for r in data["checks"]), "negative checks incomplete")
                    labels = {r["label"] for r in data["checks"]}
                    base.require(set(descriptor["required_checks"]) <= labels, "negative mandatory branch labels missing")
                    for key, value in descriptor["expected_flags"].items():
                        base.require(type(data.get(key)) is type(value) and data.get(key) == value, "negative scope/zeroallocation flag wrong: " + key)
                    rows = data.get("rows")
                    base.require(isinstance(rows, list) and rows and len(rows) == len(descriptor["required_rows"]), "negative complete source/JSON rows missing")
                    actual = {(r.get("id"), r.get("route")): r for r in rows}
                    base.require(len(actual) == len(rows), "negative duplicate row")
                    for required in descriptor["required_rows"]:
                        row = actual.get((required["id"], required["route"]), {})
                        base.require(row.get("passed") is True and row.get("path") == required["path"]
                                     and row.get("code") == required["code"] and row.get("input_unchanged") is True
                                     and row.get("zero_world_allocation") is True,
                                     "negative typed input/code/immutability/preallocation proof missing")
                    base.require(data.get("fixture_inputs") == fixture, "negative did not use exact actual A fixture SHA inputs")
                    for row in data.get("source_pins", []):
                        relative = base.relative_path(row["path"])
                        base.require(sha(self.project / relative) == row["sha256"], "negative actual validator source drift")
                    base.require({r["path"] for r in data.get("source_pins", [])} >= CHANGED | ADDED,
                                 "negative full six-path production source provenance missing")
                    self.verify_evidence(data)
                    step.update(report=str(report_path), report_sha256=sha(report_path), rows=len(rows), group=variant)
                    self.receipt.setdefault("negative_reports", {})[variant + "/" + descriptor["id"]] = {
                        "report": str(report_path), "sha256": sha(report_path), "rows": len(rows), "pid": step["pid"], "nonce": nonce}

                self.native_phase("negative_" + variant + "_" + h["id"],
                                  ["--headless", "res://tools/" + Path(h["scene"]).name], env, 900, validate)
                for row in fixture.values(): base.require(sha(row["path"]) == row["sha256"], "negative mutated positive actual A evidence")

        def execute(self):
            # Actual inherited original JSON11 / OwnedSlot / admission ABC, including
            # unmodified full-world/packet/clocks/native/pinned negative-profile guards.
            super().execute()
            self.receipt["complete"] = False
            for row in self.reports.values():
                base.require(row["pid"] not in self.execution_pids and row["nonce"] not in self.execution_nonces, "original process/nonce reused")
                self.execution_pids.add(row["pid"]); self.execution_nonces.add(row["nonce"])
            for variant in VARIANTS:
                group = self.new_group(variant)
                self.activate_group(group)
                guard_nonce = uuid.uuid4().hex
                guard_env = self.env.copy()
                guard_env.update(DAMING_RETREAT_PROFILE=str(self.profile / "mismatch"),
                                 DAMING_RETREAT_CASE=RETREAT_CASES[0], DAMING_RETREAT_FIRST_ROLE=VARIANTS[variant],
                                 DAMING_RETREAT_NONCE=guard_nonce, DAMING_ADMIT_NONCE=guard_nonce)
                def retreat_guarded(step, text):
                    base.require(step.get("exit_code") == 2 and step.get("process_terminal") is True
                                 and "DAMING_RETREAT PRIVATE_PROFILE_REQUIRED" in text
                                 and not (self.output / RETREAT_CASES[0]).exists()
                                 and not list((self.profile / "appdata").rglob("handoff_A.json")),
                                 "new v25 actual negative profile guard failed or wrote normal case evidence")
                self.native_phase(variant + "_profile_guard", ["--headless", "res://tools/" + self.args.retreat_scene.name],
                                  guard_env, 300, retreat_guarded)
                for case in RETREAT_CASES:
                    self.activate_group(group)
                    nonce = uuid.uuid4().hex
                    env = self.env.copy()
                    env.update(DAMING_RETREAT_CASE=case, DAMING_RETREAT_FIRST_ROLE=VARIANTS[variant],
                               DAMING_RETREAT_NONCE=nonce, DAMING_ADMIT_NONCE=nonce)
                    self.native_phase(variant + "_" + case,
                        ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy",
                         "--resolution", "1280x720", "--position", "30000,30000", "res://tools/" + self.args.retreat_scene.name],
                        env, 1200 if case == RETREAT_CASES[0] else 600,
                        lambda step, text, v=variant, c=case: self.validate_retreat_case(v, c, step, text))
                    if case == RETREAT_CASES[0]: self.run_negatives(variant)
            with self.stage("v25_final_full_source_profiles_and_native_audit") as step:
                self.input_integrity(True)
                base.require(set(self.retreat_reports) == {(v, c) for v in VARIANTS for c in RETREAT_CASES}, "eight actual cases incomplete")
                base.require(set(self.receipt.get("negative_reports", {})) == {
                    v + "/" + h["id"] for v in VARIANTS for h in self.matrix["harnesses"]}, "mandatory negative stages missing")
                manifest = []
                for name, group in self.profile_groups.items():
                    for p in sorted(group["profile"].rglob("*")):
                        base.no_reparse(p)
                        if p.is_file(): manifest.append({"group": name, "path": str(p), "bytes": p.stat().st_size, "sha256": sha(p)})
                base.dump_new(self.run / "all_isolated_profile_manifest.json", manifest)
                self.receipt.update(complete=True, natural_victory_qualified=True, local_terminal_once_qualified=True,
                                    main_gameplay_processes=11, actual_observed_case_processes=len(self.execution_pids),
                                    all_isolated_profile_manifest_sha256=sha(self.run / "all_isolated_profile_manifest.json"))
                step.update(profile_groups=len(self.profile_groups), profile_files=len(manifest))
    return V25Runner


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt", "cached-native-world", "candidate-receipt"]:
        p.add_argument("--" + key, type=Path, required=True)
    here = Path(__file__).resolve().parent
    defaults = {"base-producer": Path("E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24r2.py"),
                "runner-review": here / "RUNNER_REVIEW_V25.json", "negative-matrix": here / "NEGATIVE_IMPLEMENTATION_MATRIX_V25.json",
                "retreat-runner": here / "daming_safe_retreat_cross_process_v25.gd", "retreat-scene": here / "daming_safe_retreat_cross_process_v25.tscn",
                "retreat-route": here / "daming_safe_retreat_route_v25.gd"}
    for key, default in defaults.items(): p.add_argument("--" + key, type=Path, default=default)
    p.add_argument("--boundary-harness", type=Path, required=True)
    p.add_argument("--boundary-manifest", type=Path, required=True)
    p.add_argument("--prior-pid", type=int)
    p.add_argument("--deadline-utc", required=True)
    args = p.parse_args()
    try:
        args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
        require(args.deadline_utc.tzinfo is not None and args.deadline_utc <= DEADLINE
                and dt.datetime.now(dt.timezone.utc) < args.deadline_utc, "AUTHORIZED_DEADLINE_INVALID_OR_REACHED")
        for key, value in vars(args).items():
            if isinstance(value, Path): setattr(args, key, safe_absolute(value))
        reviewed, matrix = check_prerequisites(args)
        require(args.source_root.is_dir() and (args.source_root / "project.godot").is_file(), "source project missing")
        require(not args.work_root.is_relative_to(args.source_root), "work root inside production source")
    except (PrerequisiteBlocked, OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"status": "BLOCKED", "complete": False, "engine_batch_created": False,
                          "engine_started": False, "reason": str(exc)}, ensure_ascii=False), flush=True)
        return 2
    base = load_base(args.base_producer)
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("daming_safe_retreat_v25_" + uuid.uuid4().hex[:8])
    run.mkdir(exist_ok=False)
    runner = runner_class(base)(args, run, reviewed, matrix)
    code = 0
    try:
        runner.execute()
    except BaseException as exc:
        code = 1
        runner.receipt["complete"] = False
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
            code = 1; runner.receipt["lock_released"] = False
            runner.receipt["lock_audit_failure"] = str(exc)
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        base.dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"],
                          "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
