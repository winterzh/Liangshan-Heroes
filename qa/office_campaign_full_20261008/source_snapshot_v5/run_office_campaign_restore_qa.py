"""Fresh office full campaign QA; retain original validators, use current source/native/engine identity."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import time
import types
import uuid

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa/zhu_wounded_20261005"
PROPOSAL = QA / "proposals/daming_safe_retreat_v25"
PINNED_MODULES = {
    "base": (QA / "harness/run_daming_admit_v24s.py", "049dcdc74fab7936d4812f71a9806cee46569163ece4c524043ac7cfdedd8626"),
    "parent": (PROPOSAL / "run_daming_safe_retreat_v25s.py", "5941315849982fb73d4851c2fcb95a2369d498760a83801427d315dd6a229af5"),
    "explorer": (PROPOSAL / "run_daming_safe_retreat_v25s_r2a_explore.py", "d2fd596b94b2de563a073c897aa30892212e3f0c1ada2db475aec34ecf22801b"),
    "full": (PROPOSAL / "run_daming_safe_retreat_v25s_r2b2_full.py", "e61b7e87a5c52792040fc9d6e84828c6fce2aec8f3496ec3bf883c78aab5fd79"),
}


def require(value, message):
    if not value:
        raise RuntimeError(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def fixed_pin(pins, path, expected):
    key = str(path)
    require(key not in pins or pins[key] == expected, "Attempted replacement of fixed input pin: " + key)
    require(sha(path) == expected, "Fixed input pin drift: " + key)
    pins[key] = expected


def load_module(path, name, digest=None):
    if digest is not None:
        require(sha(path) == digest, "Immutable module source drift: " + str(path))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preparation", type=Path, required=True)
    parser.add_argument("--source-bridge", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--work-root", type=Path, default=Path("D:/CodexTemp/lsh-office-restore-20261008"))
    parser.add_argument("--deadline-utc")
    parser.add_argument("--independent-review", type=Path)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    preparation = read(args.preparation)
    require(preparation.get("schema") == "office_campaign_candidate_preparation_v1" and preparation.get("complete") is True,
            "Complete office candidate preparation required")
    source_root = Path(preparation["candidate_root"]).resolve(strict=True)
    require(source_root != ROOT and not source_root.is_relative_to(ROOT), "Private source root required")
    for row in preparation["files"]:
        require(sha(source_root / row["path"]) == row["after_sha256"], "Prepared six-path candidate drift")
    for row in preparation["retained_full_review_source_bridge"]:
        path = Path(row["current_path"])
        require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "Retained review bridge drift")
    for path, digest in PINNED_MODULES.values():
        require(sha(path) == digest, "Immutable full validator source drift")
    source_bridge = read(args.source_bridge)
    require(source_bridge.get("schema") == "office_complete_candidate_inputs_v2"
            and source_bridge.get("complete") is True
            and source_bridge.get("candidate_root") == str(source_root)
            and source_bridge.get("only_semantic_changes") == ["scripts/run_battle_world_core.gd", "scripts/run_level8_unit_contract.gd"],
            "Complete fresh runtime and QA source bridge required")
    identity_module = load_module(PINNED_MODULES["base"][0], "office_preflight_identity", PINNED_MODULES["base"][1])
    require(identity_module.installed_identity(source_root) == source_bridge["candidate_identity"],
            "Candidate complete source identity differs from reviewed bridge")
    require(identity_module.installed_identity(ROOT) == source_bridge["production_identity"],
            "Production baseline changed after fresh source bridge")
    for row in source_bridge["qa_input_pins"]:
        path = Path(row["path"])
        require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "Complete QA/helper/fixture pin changed")
    for name in ["tools/run_steam_integration_qa.py", "tools/owned_slot_retry_qa.gd"]:
        committed = subprocess.check_output(["git", "show", "HEAD:" + name], cwd=source_root)
        require(committed.replace(b"\r\n", b"\n") == (source_root / name).read_bytes().replace(b"\r\n", b"\n"),
                "Original committed helper/OwnedSlot source changed")
    args.godot = args.godot.resolve(strict=True)
    if not args.run:
        print(json.dumps({"preflight": True, "candidate_source_verified": True,
                          "historical_validators_byte_exact": True, "JSON_checks": 533, "OwnedSlot_checks": 76,
                          "admission_checks": [39, 351, 342], "world_rows_per_role": 264,
                          "component_rows_per_role": 362, "live_cases_per_role": 24, "negative_stages": 52,
                          "both_roles_ABCD_required": True, "baseline_required": True,
                          "fresh_runner_independent_review_required": True, "native_started": False}))
        return
    require(args.baseline is not None and args.independent_review is not None and args.deadline_utc,
            "Actual baseline, fresh independent source review and new bounded batch deadline required")
    baseline = read(args.baseline)
    require(baseline.get("complete") is True and baseline.get("schema") == "workstation_baseline_v1"
            and baseline.get("engine_sha256") == sha(args.godot) and baseline.get("source_drift") == [],
            "This machine's actual completed import/startup baseline required")
    version = baseline.get("startup_report", {}).get("engine", {})
    require([version.get(key) for key in ["major", "minor", "patch"]] == [4, 6, 3]
            and version.get("status") == "stable", "Actual baseline must use stable Godot 4.6.3")
    review = read(args.independent_review)
    require(review.get("schema") == "office_campaign_restore_independent_review_v1"
            and review.get("independent") is True and review.get("static_api_closure_passed") is True
            and review.get("approved_stages") == ["full"] and review.get("producer_sha256") == sha(Path(__file__))
            and review.get("preparation_sha256") == sha(args.preparation)
            and review.get("source_bridge_sha256") == sha(args.source_bridge), "Fresh full office producer review missing or mismatched")
    for row in baseline["source_files"]:
        path = ROOT / row["path"]
        require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "Actual baseline source input changed")
    deadline = dt.datetime.fromisoformat(args.deadline_utc)
    require(deadline.tzinfo is not None and dt.datetime.now(dt.timezone.utc) < deadline,
            "Future timezone-aware batch deadline required")
    modules = {name: load_module(path, "office_immutable_" + name, digest)
               for name, (path, digest) in PINNED_MODULES.items()}
    base, parent, explorer, full = [modules[name] for name in ["base", "parent", "explorer", "full"]]
    shared_path = source_root / "tools/run_steam_integration_qa.py"
    require(shared_path.read_bytes() == (ROOT / "tools/run_steam_integration_qa.py").read_bytes(), "Current native helper drift")
    shared = load_module(shared_path, "office_source_native_helper")
    require(shared.ROOT == source_root, "Native helper bound to wrong checkout")
    original_shared = load_module(ROOT / "tools/run_steam_integration_qa.py", "office_original_native_helper")
    original_native = original_shared.native_dependencies()
    for name, manifest in original_native.items():
        for row in manifest["files"]:
            source = ROOT / "vendor" / name / row["path"]
            target = source_root / "vendor" / name / row["path"]
            require(sha(source) == row["sha256"], "Original native source changed before provisioning")
            if target.exists():
                require(sha(target) == row["sha256"], "Refusing modified candidate native dependency")
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read_bytes())
            require(sha(target) == row["sha256"], "Native provisioning readback failed")
        source = ROOT / "vendor" / name / "provenance.json"
        target = source_root / "vendor" / name / "provenance.json"
        if target.exists():
            require(target.read_bytes() == source.read_bytes(), "Existing native provenance drift")
        else:
            target.write_bytes(source.read_bytes())
    native = shared.native_dependencies()
    require(native == baseline["native_dependencies"], "Fresh native dependency manifests differ from local baseline")
    # Native artifacts stay local and are never inferred from a successful Godot import.
    portable = types.SimpleNamespace(**vars(base))
    sources = list(preparation["retained_full_review_source_bridge"])
    extra_pins = {str(path): digest for path, digest in PINNED_MODULES.values()}
    for row in sources:
        fixed_pin(extra_pins, row["current_path"], row["sha256"])
    for row in source_bridge["qa_input_pins"]:
        fixed_pin(extra_pins, row["path"], row["sha256"])
    for path in [Path(__file__), args.preparation, args.source_bridge, args.baseline, args.independent_review, shared_path]:
        if str(path) in extra_pins:
            require(sha(path) == extra_pins[str(path)], "Reviewed producer/helper drift before startup")
        else:
            extra_pins[str(path)] = sha(path)
    interfaces, harnesses = {}, []
    for kind, row in preparation["interfaces"].items():
        source = Path(row["source"])
        require(sha(source) == row["sha256"], "Fixed matrix interface drift")
        interface = read(source)
        for field in ["harness", "scene"]:
            current = row[field]
            require(sha(current["current_path"]) == current["sha256"], "Fixed consumer source drift")
            interface[field] = {"path": current["current_path"], "sha256": current["sha256"], "bytes": current["bytes"]}
            fixed_pin(extra_pins, current["current_path"], current["sha256"])
        interfaces[kind] = interface
        require(str(source) in extra_pins and sha(source) == extra_pins[str(source)], "Unpinned or changed matrix interface")
        harnesses.append({"id": kind, "gd": interface["harness"]["path"], "scene": interface["scene"]["path"]})
    matrix = {"harnesses": harnesses, "pins": []}
    runner_args = types.SimpleNamespace(
        source_root=source_root, work_root=args.work_root.resolve(), godot=args.godot, deadline_utc=deadline,
        base_producer=PINNED_MODULES["base"][0], stage="full", exploration_role="both",
        retreat_runner=PROPOSAL / "daming_safe_retreat_cross_process_v25s1.gd",
        retreat_scene=PROPOSAL / "daming_safe_retreat_cross_process_v25s1.tscn",
        retreat_route=PROPOSAL / "daming_safe_retreat_route_v25.gd",
        runner_review=PROPOSAL / "RUNNER_REVIEW_V25S1_FULL_FX.json",
        negative_matrix=PROPOSAL / "ADAPTER_BUNDLE_MATRIX_V25S_R2B2.json",
        capture_base=PROPOSAL / "daming_safe_retreat_cross_process_v25.gd",
        capture_base_scene=PROPOSAL / "daming_safe_retreat_cross_process_v25.tscn",
    )

    class OfficeBase(base.Runner):
        def __init__(self, arguments, run):
            super().__init__(arguments, run)
            self.receipt.update(schema="office_campaign_restore_full_v1", producer_sha256=sha(Path(__file__)),
                                historical_deadline_reused=False, historical_physical_cache_reused=False,
                                fresh_machine_baseline_sha256=sha(args.baseline), preparation_sha256=sha(args.preparation),
                                office_independent_review_sha256=sha(args.independent_review))

        def limit(self):
            if dt.datetime.now(dt.timezone.utc) >= self.args.deadline_utc:
                raise base.BatchFailure("office_batch_deadline_reached")

        def preflight(self):
            self.limit()
            self.shared, self.native = shared, native
            self.root_identity = base.installed_identity(self.root)
            require(self.root_identity == source_bridge["candidate_identity"], "Fresh complete source pin changed before freeze")
            names = sorted(set(shared.sources()) | {row["path"] for row in self.root_identity["files"]})
            self.inputs = [{"path": name, "bytes": (self.root / name).stat().st_size, "sha256": sha(self.root / name)}
                           for name in names]
            self.code_pins.update(extra_pins)
            owned_tool = self.root / "tools/owned_slot_retry_qa.gd"
            require(str(owned_tool) in self.code_pins and sha(owned_tool) == self.code_pins[str(owned_tool)], "Fixed OwnedSlot tool drift")
            self.receipt.update(source_files=self.inputs, source_head=preparation["source_head"],
                                fresh_source_installed_identity=self.root_identity, godot_sha256=sha(self.args.godot),
                                native_dependencies=self.native, private_runtime_patches=0,
                                complete_source_bridge_sha256=sha(args.source_bridge))
            gd = QA / "harness/native_ownership_json_boundary_v24q1.gd"
            scene = Path(preparation["json_scene"]["current_path"])
            manifest = read(QA / "native_ownership_json_fixtures_v24q.json")
            for key in ["original_payload", "normalized_payload"]:
                manifest[key]["path"] = preparation["json_fixture_paths"][key]
            for row in manifest["maps"]:
                row["path"] = preparation["json_fixture_paths"][row["case"]]
            for path in [gd, scene, *(Path(row["path"]) for row in [manifest["original_payload"], manifest["normalized_payload"], *manifest["maps"]])]:
                require(str(path) in self.code_pins and sha(path) == self.code_pins[str(path)], "Fixed JSON harness/scene/fixture drift")
            require(sha(scene) == preparation["json_scene"]["sha256"], "Fresh explicit JSON scene binding changed")
            self.boundary = {"gd": gd, "scene": scene, "manifest": manifest}
            self.input_integrity()

        def wait_prior(self):
            # All original component contracts are rerun on this machine; no historical FX receipt or clock is adopted.
            self.receipt["historical_FX_qualification_used_as_current"] = False

        def input_integrity(self, private=False):
            self.limit()
            for row in self.inputs:
                path = self.root / row["path"]
                require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "Current source input drift")
                if private:
                    target = self.project / row["path"]
                    require(target.stat().st_size == row["bytes"] and sha(target) == row["sha256"], "Frozen source input drift")
            require(base.installed_identity(self.root) == self.root_identity, "Candidate source runtime inventory changed")
            for path, digest in self.code_pins.items():
                require(sha(path) == digest, "Pinned producer/tool/fixture changed")
            require(sha(self.args.godot) == self.receipt["godot_sha256"], "Engine drift")
            require(self.shared.native_dependencies() == self.native, "Native source dependencies changed")
            if private:
                for row in self.receipt["added_qa_files"] + self.receipt["native_installed_files"]:
                    path = self.project / row["path"]
                    require(path.stat().st_size == row["bytes"] and sha(path) == row["sha256"], "Installed native/QA file drift")
                require(base.installed_identity(self.project) == self.installed, "Complete frozen runtime identity changed")

        def prepare(self):
            self.input_integrity()
            self.project.mkdir(exist_ok=False)
            for row in self.inputs:
                self.copy_checked(self.root / row["path"], self.project / row["path"], row["sha256"])
            require(self.shared.install_native(self.project) == self.native, "Native installation pin mismatch")
            native_rows = [{"path": path.relative_to(self.project).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path)}
                           for path in sorted((self.project / "addons").rglob("*")) if path.is_file()]
            self.receipt["native_installed_files"] = native_rows
            additions = []
            extra = [QA / "harness/daming_admit_cross_process_v24s.gd", QA / "harness/daming_admit_cross_process_v24s.tscn",
                     runner_args.retreat_runner, runner_args.retreat_scene, runner_args.retreat_route,
                     runner_args.capture_base, runner_args.capture_base_scene]
            extra += [Path(harness[key]) for harness in harnesses for key in ["gd", "scene"]]
            known_sources = {source.name: source for source in extra}
            copied = set()
            while extra:
                source = extra.pop()
                if source in copied:
                    continue
                copied.add(source)
                require(str(source) in self.code_pins and sha(source) == self.code_pins[str(source)], "Retained fixed QA source drift before copy")
                target = self.project / "tools" / source.name
                require(not target.exists(), "QA filename collision")
                self.copy_checked(source, target, self.code_pins[str(source)])
                additions.append({"path": "tools/" + source.name, "bytes": target.stat().st_size,
                                  "sha256": self.code_pins[str(source)], "kind": "byte-exact retained full consumer"})
                references = re.findall(r'res://tools/([^"\s]+\.(?:gd|tscn))', source.read_text(encoding="utf-8-sig"))
                for name in references:
                    if name == source.name or any(item.name == name for item in copied):
                        continue
                    path = known_sources.get(name, PROPOSAL / name)
                    require(path.is_file() and str(path) in self.code_pins,
                            "Unresolved or unpinned retained QA dependency: " + name)
                    extra.append(path)
            self.prepare_regression_inputs(additions)
            self.receipt["added_qa_files"] = additions
            self.installed = base.installed_identity(self.project)
            self.receipt["pre_import_installed_identity"] = self.installed
            self.profile, self.output = self.run / "profile", self.run / "native_evidence"
            self.profile.mkdir(); self.output.mkdir()
            self.env = os.environ.copy()
            for key in list(self.env):
                if key.startswith(("LSH_", "ART_", "DAMING_", "V25_")) or key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key in {
                    "LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR", "WORLD_SHADOW_ENABLED"}:
                    self.env.pop(key)
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
                path = self.profile / key.lower(); path.mkdir(); self.env[key] = str(path)
            self.env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1",
                            DAMING_ADMIT_PROFILE=str(self.profile), DAMING_ADMIT_OUT=str(self.output),
                            DAMING_ADMIT_EXPECT_CONTENT=self.installed["content_version"],
                            DAMING_ADMIT_EXPECT_ENGINE=self.receipt["godot_sha256"])
            self.receipt["private_profile"] = str(self.profile)
            self.profile_groups["original_admit"] = {"profile": self.profile, "output": self.output, "env": self.env.copy()}
            self.input_integrity(True)

        def native_phase(self, label, arguments, env, timeout_seconds, validator):
            if label == "import":
                original_validator = validator

                def imported(step, text):
                    original_validator(step, text)
                    actual = base.installed_identity(self.project)
                    before = {row["path"]: row for row in self.installed["files"]}
                    after = {row["path"]: row for row in actual["files"]}
                    require(all(after.get(name) == row for name, row in before.items()), "First cold import changed frozen source/native bytes")
                    generated = [row for name, row in after.items() if name not in before]
                    require(all(row["path"].endswith((".import", ".uid"))
                                and (self.project / row["path"].rsplit(".", 1)[0]).is_file() for row in generated),
                            "Cold import added non-derived runtime input")
                    self.installed = actual
                    self.receipt["fresh_cold_import_metadata"] = generated
                    self.receipt["installed_identity"] = actual
                    self.env["DAMING_ADMIT_EXPECT_CONTENT"] = actual["content_version"]
                    self.profile_groups["original_admit"]["env"] = self.env.copy()
                    self.receipt["runtime_identity_sealed_after_cold_import"] = True
                validator = imported
            # Before any child starts, a resumed foreign engine is another natural
            # wait, not a native failure/retry. Once launched, retain the exact old
            # terminal/error/foreign-engine failure policy and all source guards.
            with self.stage(label) as step:
                log = Path(step["step_dir"]) / "native.log"
                step.update(command=[str(self.args.godot), "--path", str(self.project), *arguments],
                            profile=str(self.profile), process_nonce=env.get("DAMING_ADMIT_NONCE", ""),
                            stop_reason=None, exit_code=None, process_terminal=False, prelaunch_waits=[])
                try:
                    while True:
                        self.input_integrity(True); self.acquire(); self.input_integrity(True)
                        self.limit()
                        foreign = base.engine_rows()
                        if not foreign:
                            break
                        step["prelaunch_waits"].append({"foreign_engines": foreign, "observed_ns": time.monotonic_ns(),
                                                       "own_child_started": False})
                        self.release()
                        print("WAIT foreign engine entered before launch; no own native child or retry", foreign, flush=True)
                    print("RUN", label, self.run, flush=True)
                    with log.open("xb") as stream:
                        self.child = subprocess.Popen(step["command"], cwd=self.project, env=env,
                                                      stdout=stream, stderr=subprocess.STDOUT,
                                                      creationflags=subprocess.CREATE_NO_WINDOW)
                        step.update(pid=self.child.pid, native_started_ns=time.monotonic_ns(),
                                    native_started_utc=dt.datetime.now(dt.timezone.utc).isoformat())
                        started = last_notice = time.monotonic()
                        while self.child.poll() is None:
                            self.limit()
                            foreign = base.engine_rows(self.child.pid)
                            if foreign:
                                step.update(stop_reason="foreign_engine_resumed", foreign_engine_pids=foreign)
                                raise base.BatchFailure("foreign_engine_resumed; entire batch/profile preserved, no retry")
                            if base.ENGINE_ERRORS.search(log.read_text(encoding="utf-8", errors="replace")):
                                step["stop_reason"] = "engine_or_script_error"
                                raise base.BatchFailure("native engineering error")
                            if time.monotonic() - started > timeout_seconds:
                                step["stop_reason"] = "own_stage_timeout"
                                raise base.BatchFailure("native own stage timeout")
                            if time.monotonic() - last_notice >= 25:
                                print("RUNNING", label, round(time.monotonic() - started), "s", flush=True)
                                last_notice = time.monotonic()
                            self.pause(0.5)
                        step.update(native_finished_ns=time.monotonic_ns(), exit_code=self.child.returncode,
                                    process_terminal=self.child.poll() is not None)
                    text = log.read_text(encoding="utf-8", errors="replace")
                    require(not base.ENGINE_ERRORS.search(text), "native error in final log")
                    validator(step, text)
                    self.input_integrity(True)
                except BaseException:
                    if step["stop_reason"] is None:
                        step["stop_reason"] = "producer_or_validation_exception"
                    raise
                finally:
                    self.stop_owned()
                    if self.child is not None:
                        step.update(pid=self.child.pid, exit_code=self.child.returncode,
                                    process_terminal=self.child.poll() is not None,
                                    native_finished_ns=step.get("native_finished_ns", time.monotonic_ns()))
                    if log.exists():
                        step.update(log=str(log), log_sha256=sha(log), log_bytes=log.stat().st_size)
                    self.child = None
                    self.release()

    portable.Runner = OfficeBase
    ExistingFull = full.runner_class(portable, parent, explorer)

    class OfficeFull(ExistingFull):
        def preflight(self):
            OfficeBase.preflight(self)
            missing = parent.producer_required_native_labels() - parent.source_proven_native_labels(self.args.retreat_runner, self.args.retreat_route)
            require(not missing, "Original complete mandatory native coverage missing")
            self.receipt["source_proven_mandatory_native_labels"] = sorted(parent.producer_required_native_labels())

        def prepare(self):
            OfficeBase.prepare(self)

    run = args.work_root.absolute() / ("office_full_" + uuid.uuid4().hex[:8])
    base.no_reparse(run)
    require(not run.is_relative_to(source_root) and not run.is_relative_to(ROOT), "Independent work root required")
    run.mkdir(parents=True, exist_ok=False)
    runner = OfficeFull(runner_args, run, read(runner_args.runner_review), matrix, interfaces, list(map(Path, extra_pins)))
    runner.receipt.update(schema="office_campaign_restore_full_v1", producer_sha256=sha(Path(__file__)),
                          execution_scope="fresh_full", fresh_machine_baseline_sha256=sha(args.baseline),
                          inherited_full_consumer_sha256=PINNED_MODULES["full"][1], full_scope_not_reduced=True)
    try:
        runner.execute()
    except BaseException as error:
        runner.receipt["failure"] = repr(error)
        raise
    finally:
        runner.stop_owned(); runner.release()
        runner.receipt["lock_released"] = not runner.locked
        (run / "receipt.json").write_text(json.dumps(runner.receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"complete": runner.receipt["complete"], "run": str(run), "failure": runner.receipt.get("failure")}))


if __name__ == "__main__":
    main()
