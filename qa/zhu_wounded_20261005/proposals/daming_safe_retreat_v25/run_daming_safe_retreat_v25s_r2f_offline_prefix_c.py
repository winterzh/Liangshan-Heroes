"""UNEXECUTED r2f: fresh offline prepare, consolidated adjacent final SHA audit.

No copy/guard is removed from immutable base.prepare. All three native-phase
pre/acquire/post input checks, native foreign-engine abort, real import, private
profile guards, original C342 and both ordinary A routes remain inherited or
byteexact. No links or failed profile/project/output are reused.
"""
from __future__ import annotations
import argparse
import ast
import datetime as dt
import hashlib
import importlib.util
import json
import re
from pathlib import Path
import sys
import uuid
sys.dont_write_bytecode = True
PREFIX_PRODUCER_SHA = "3d3715bb0c0a0b5be77bd840e46875a9856eab1164c65d8bbc44512274d37856"
EXPLORER_SHA = "d2fd596b94b2de563a073c897aa30892212e3f0c1ada2db475aec34ecf22801b"
DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
ADMIT = ("A_half_save", "B_continue_resave", "C_verify_resave")
RETREAT = "A_single_save"
VARIANTS = {"lu_first": "lu", "shi_first": "shi"}
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")


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
    p = Path(value); require(p.is_absolute(), "absolute input path required")
    for q in [p, *p.parents]:
        if q.exists() or q.is_symlink():
            require(not q.is_symlink() and not getattr(q.lstat(), "st_file_attributes", 0) & 0x400,
                    "reparse/link input refused")
    return p.resolve()


def pin(row):
    p = absolute(row["path"])
    require(type(row.get("bytes")) is int and row["bytes"] > 0 and p.is_file()
            and p.stat().st_size == row["bytes"] and sha(p) == row["sha256"], "exact source review pin drift")
    return p


def check_fast_review(args):
    require(sha(args.prefix_producer) == PREFIX_PRODUCER_SHA, "immutable 3d prefix producer required")
    ast.parse(args.prefix_producer.read_text(encoding="utf-8-sig"))
    review = read(args.fast_review)
    require(review.get("schema") == "daming_safe_retreat_offline_prepare_review_v25s_r2f"
            and review.get("static_api_closure_passed") is True
            and review.get("approved_stages") == ["offline_prepare_then_prefix_C_both_A"]
            and pin(review["producer_pin"]) == Path(__file__).resolve()
            and pin(review["prefix_parent_pin"]) == args.prefix_producer,
            "new offline preparation independent source review missing")


def import_pinned(path, digest, name):
    require(sha(path) == digest, "immutable imported source drift")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec); sys.modules[name] = module
    spec.loader.exec_module(module); return module


def runner_class(base, parent, explorer, prefix):
    Recovery = prefix.recovery_class(base, parent, explorer)

    class OfflineFresh(Recovery):
        def __init__(self, args, run, reviewed, matrix, interfaces, extra, inputs):
            super().__init__(args, run, reviewed, matrix, interfaces, extra, inputs)
            self.receipt.update(schema="daming_safe_retreat_prefix_c_exploration_batch_v25s_r2f",
                producer_sha256=sha(Path(__file__)), preparation_parent_sha256=PREFIX_PRODUCER_SHA,
                preparation_scope="All original base copies/guards retained; pure fresh prepare before first idle wait; one full adjacent final QA/root/private/native/tool audit instead of duplicate identical walks.",
                native_phase_guards_unchanged=True, original_real_C342_and_both_A_required=True)

        def preflight(self):
            check_fast_review(self.args)
            super().preflight()  # exact 3d prefix proof plus original r2a/base/select6 guards
            for path in [Path(__file__).resolve(), self.args.prefix_producer, self.args.fast_review]:
                self.code_pins[str(path)] = sha(path)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": value} for p, value in self.code_pins.items()]
            # base.prepare begins with the original complete input_integrity walk,
            # including these pins, before any copying. No native launch occurs here.

        def prepare(self):
            # Preserve every byte of the actual base freeze implementation, including
            # Root hashes, donor hashes, copied-cache source/dest hashes, all native
            # binaries, exact88 metadata bridge and full5014->5102 identities.
            base.Runner.prepare(self)
            with self.stage("reviewed_offline_QA_and_all_input_final_audit") as step:
                self.profile_groups["original_admit"] = {"profile": self.profile, "output": self.output, "env": self.env.copy()}
                additions = self.receipt["added_qa_files"]
                paths = [self.args.retreat_runner, self.args.retreat_scene, self.args.retreat_route]
                base.require(self.args.stage == "a_fixture_exploration" and not self.matrix["harnesses"],
                             "offline explorer cannot silently omit full tools")
                targets = set()
                for source in paths:
                    relative = "tools/" + source.name
                    base.require(relative not in targets and not (self.project / relative).exists(), "duplicate extra QA filename")
                    targets.add(relative)
                    self.copy_checked(source, self.project / relative, self.code_pins[str(source)])
                    additions.append({"path": relative, "bytes": source.stat().st_size, "sha256": sha(source),
                                      "kind": "reviewed additional v25 QA outside runtime roots"})
                # This is the one actual endpoint audit. Its unchanged implementation
                # independently hashes all ROOT5041/5037 and private inputs, all QA9,
                # full actual native9 + source native manifests, engine/tool/profile
                # proof inputs and all88 metadata, then recomputes actual installed5102
                # canonical identity and directory/rule equality. Nothing is cached.
                self.input_integrity(True)
                source = self.prefix["source"]
                base.require(self.installed == source["installed_identity"] and self.installed["file_count"] == 5102
                             and self.receipt["native_installed_files"] == source["native_installed_files"]
                             and additions == source["added_qa_files"],
                             "full independently-read private identity/native9/QA9 differs from actual prefix")
                step.update(root_raw_rows=5041, root_distinct_files=5037, actual_private_runtime_files=5102,
                            actual_native_files=9, actual_QA_additions=9, actual_complete_endpoint_audits=1,
                            cached_validation_used=False, failed_profile_reused=False, prepare_only_no_engine=True)

        def execute(self):
            self.preflight(); self.wait_prior()
            # Only pure fresh file preparation occurs while another engine may be busy.
            # Every native launch still uses the unchanged continuous-idle/acquire guard.
            self.prepare()
            with self.stage("wait_natural_engine_idle") as step:
                self.wait_idle(); step["foreign_engines_at_idle"] = base.engine_rows()
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
                prefix.check_prefix(self.args)
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

    return OfflineFresh


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt",
                 "cached-native-world", "candidate-receipt", "boundary-harness", "boundary-manifest",
                 "runner-review", "adapter-review", "recovery-review", "fast-review", "deadline-utc"]:
        parser.add_argument("--" + name, required=True, type=str if name == "deadline-utc" else Path)
    here = Path(__file__).resolve().parent
    defaults = {"prefix-producer": here / "run_daming_safe_retreat_v25s_r2d_prefix_c.py",
        "base-producer": Path("E:/ChatGPT/daming_admit_v24o_proposal/run_daming_admit_v24s.py"),
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
                "authorized deadline invalid/reached")
        for key, value in vars(args).items():
            if isinstance(value, Path): setattr(args, key, absolute(value))
        check_fast_review(args)
        require(not args.work_root.is_relative_to(args.source_root), "fresh independent work root must be outside ROOT")
        prefix = import_pinned(args.prefix_producer, PREFIX_PRODUCER_SHA, "immutable_3d_for_offline_fresh")
        inputs = prefix.check_prefix(args)
        explorer = import_pinned(args.explorer_producer, EXPLORER_SHA, "immutable_d2_for_offline_fresh")
        reviewed, matrix, interfaces, extra = explorer.check_prerequisites(args)
    except (Blocked, OSError, ValueError, KeyError, TypeError, RuntimeError) as exc:
        print(json.dumps({"status": "BLOCKED", "complete": False, "engine_batch_created": False,
                          "engine_started": False, "reason": str(exc)}, ensure_ascii=False), flush=True)
        return 2
    parent = explorer.load_module(args.parent_producer, "immutable_v25s_for_offline_fresh")
    base = parent.load_base(args.base_producer)
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("daming_safe_retreat_v25s_r2f_offline_prefix_c_" + uuid.uuid4().hex[:8]); run.mkdir(exist_ok=False)
    runner = runner_class(base, parent, explorer, prefix)(args, run, reviewed, matrix, interfaces, extra, inputs)
    code = 0
    try: runner.execute()
    except BaseException as exc:
        code = 1; runner.receipt["complete"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        for action in [runner.stop_owned, runner.release]:
            try: action()
            except BaseException as exc:
                code = 1; runner.receipt["complete"] = False
                runner.receipt.setdefault("finalization_failures", []).append({"type": type(exc).__name__, "message": str(exc)})
        try: runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            code = 1; runner.receipt["lock_released"] = False; runner.receipt["lock_audit_failure"] = str(exc)
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat(); base.dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"], "execution_scope": "prefix_c_then_both_actual_A",
                          "overall_v25_qualified": False, "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
