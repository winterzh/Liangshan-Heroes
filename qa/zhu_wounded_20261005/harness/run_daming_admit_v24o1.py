"""Run one fresh frozen three-process Daming admission Session batch.

No automatic retries. Any native failure, foreign-engine resumption, integrity
failure or deadline stops only this producer's child and preserves the batch.
The root task must review and prepare a new sibling attempt/profile to retry.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
CASES = ("A_half_save", "B_continue_resave", "C_verify_resave")
AUTHORIZED_DEADLINE = dt.datetime.fromisoformat("2026-10-07T22:00:00+00:00")
ENGINE_ERRORS = re.compile(r"(?m)^\s*(?:SCRIPT ERROR:|Parse Error:|ERROR:)")
SCOPE = "Real manual admission half-progress, full Session disk save/exit, independent complete install/continue/resave and independent generation-two complete install/native no-duplicate effects. No public campaign entry, fire/rescue/production/ships/natural result/reward/performance/device/release qualification."


class BatchFailure(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise BatchFailure(message)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def dump_new(path, value):
    with Path(path).open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def no_reparse(path):
    path = Path(path).absolute()
    for ancestor in [path, *path.parents]:
        if ancestor.exists() or ancestor.is_symlink():
            info = ancestor.lstat()
            require(not ancestor.is_symlink() and not getattr(info, "st_file_attributes", 0) & 0x400,
                    "link/reparse path refused: " + str(ancestor))
    return path


def relative_path(value):
    require(isinstance(value, str) and value and "\\" not in value and ":" not in value,
            "invalid receipt relative path")
    require(not Path(value).is_absolute() and all(p not in ("", ".", "..") for p in value.split("/")),
            "unsafe receipt relative path: " + value)
    return value


def cim_processes(process_id=None):
    # Fail closed on observation errors; never interpret an empty tool result as
    # a vanished process. The returned JSON has an explicit ok and array shape.
    selection = (f'$all=Get-CimInstance Win32_Process -Filter "ProcessId={int(process_id)}" -ErrorAction Stop; '
                 if process_id is not None else '$all=Get-CimInstance Win32_Process -ErrorAction Stop; ')
    query = ("$ErrorActionPreference='Stop'; " + selection +
             '$rows=@($all | Select-Object ProcessId,Name,ExecutablePath,CommandLine); '
             '@{ok=$true;rows=$rows}|ConvertTo-Json -Depth 4 -Compress')
    completed = subprocess.run(["powershell.exe", "-NoProfile", "-Command", query],
                               check=True, capture_output=True, text=True, encoding="utf-8",
                               errors="replace", timeout=20)
    payload = json.loads(completed.stdout.strip())
    require(payload.get("ok") is True and isinstance(payload.get("rows"), list),
            "CIM observation missing explicit success/array")
    return payload["rows"]


def engine_rows(owned_pid=None):
    rows = cim_processes()
    return [{"pid": int(row["ProcessId"]), "name": row.get("Name", "")}
            for row in rows
            if re.match(r"^(?:Godot|Liangshan|水浒)", row.get("Name", ""), re.I)
            and int(row["ProcessId"]) != owned_pid]


def installed_identity(project):
    """Mirror the fixed installed-input canonicalization; QA tools are outside it.

    The real native Provider must independently return this exact content digest
    in every process. This Python value never replaces runtime identity checks.
    """
    provider = project / "scripts/run_content_identity.gd"
    match = re.search(r'const INPUT_RULES_JSON := """(.*?)"""', provider.read_text(encoding="utf-8"), re.S)
    require(match is not None, "installed rules literal unavailable")
    rules_text = match.group(1)
    rules = json.loads(rules_text)
    files, directories, folded = {}, {}, {}

    def register(relative):
        relative_path(relative)
        require(relative.lower() not in folded or folded[relative.lower()] == relative,
                "installed input case alias")
        folded[relative.lower()] = relative
        no_reparse(project / relative)

    def file(relative):
        if relative == rules["derived"]:
            return
        register(relative)
        target = project / relative
        require(target.is_file(), "installed input not a file: " + relative)
        files[relative] = {"path": relative, "bytes": target.stat().st_size, "sha256": sha(target)}

    def walk(relative, depth=0):
        require(depth <= rules["max_depth"], "installed input depth limit")
        register(relative)
        directories[relative] = True
        for child in sorted((project / relative).iterdir(), key=lambda item: item.name):
            no_reparse(child)
            name = relative + "/" + child.name
            if child.is_dir():
                if child.name not in rules["skip_directories"]:
                    walk(name, depth + 1)
            else:
                file(name)

    for name in rules["root_files"]:
        target = project / name
        if target.is_file(): file(name)
        else:
            require(name not in rules["required_files"] and not target.exists(), "required root file absent")
            directories["@file/" + name] = False
    for name in rules["roots"]:
        target = project / name
        if target.is_dir(): walk(name)
        else:
            require(name not in rules["required_roots"] and not target.exists(), "required runtime root absent")
            directories[name] = False
    file("scripts/run_content_identity.gd")
    for name in rules["optional_content"]:
        if (project / name).is_file() and name not in files: file(name)
        require(not (project / name).is_dir(), "optional content has directory type")
    rules_sha = hashlib.sha256(rules_text.encode("utf-8")).hexdigest()
    canonical = rules["header"] + "\nrules\t" + rules_sha + "\n"
    for name in sorted(directories): canonical += f"D\t{name}\t{int(directories[name])}\n"
    for name in sorted(files):
        row = files[name]
        canonical += f"F\t{name}\t{row['bytes']}\t{row['sha256']}\n"
    for name in rules["optional_content"]: canonical += f"O\t{name}\t{int(name in files)}\n"
    total = sum(row["bytes"] for row in files.values())
    require(0 < len(files) <= rules["max_files"] and total <= rules["max_bytes"], "installed identity size budget")
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return {"content_version": "source-v1:" + digest, "rules_sha256": rules_sha,
            "file_count": len(files), "total_bytes": total,
            "files": [files[name] for name in sorted(files)], "directories": directories}


class Runner:
    def __init__(self, args, run):
        self.args, self.run = args, run
        self.root, self.project = args.source_root, run / "project"
        self.child = None
        self.locked = False
        self.lock = self.root / ".godot/redraw_rejection_source.lock"
        self.inputs = []
        self.installed = None
        self.shared = None
        self.native = None
        self.code_pins = {}
        self.reports = {}
        self.receipt = {"schema": "daming_admit_batch_v24o", "complete": False, "run": str(run),
                        "project": str(self.project), "source_root": str(self.root),
                        "scope": SCOPE, "private_runtime_patches": 0, "qa_harness_added": True,
                        "public_campaign_continue_qualified": False, "natural_victory_qualified": False,
                        "reward_once_qualified": False, "deadline_utc": args.deadline_utc.isoformat(),
                        "producer_sha256": sha(Path(__file__)), "steps": [], "reports": {}}

    def limit(self):
        if dt.datetime.now(dt.timezone.utc) >= self.args.deadline_utc:
            raise BatchFailure("authorized_six_am_wrap_deadline")

    def pause(self, seconds=5):
        self.limit()
        remaining = (self.args.deadline_utc - dt.datetime.now(dt.timezone.utc)).total_seconds()
        time.sleep(max(0.0, min(seconds, remaining)))
        self.limit()

    @contextlib.contextmanager
    def stage(self, label):
        step_dir = self.run / "steps" / f"{len(self.receipt['steps']):02d}_{label}"
        step_dir.mkdir(parents=True, exist_ok=False)
        step = {"case": label, "complete": False, "step_dir": str(step_dir),
                "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                "started_ns": time.monotonic_ns()}
        try:
            yield step
            step["complete"] = True
        except BaseException as exc:
            step["failure"] = {"type": type(exc).__name__, "message": str(exc)}
            raise
        finally:
            step["finished_ns"] = time.monotonic_ns()
            step["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
            self.receipt["steps"].append(step)
            dump_new(step_dir / "receipt.json", step)

    def copy_checked(self, source, dest, expected_sha=None):
        self.limit()
        no_reparse(source); no_reparse(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        with Path(source).open("rb") as reader, dest.open("xb") as writer:
            while True:
                self.limit()
                block = reader.read(1024 * 1024)
                if not block: break
                writer.write(block)
        if expected_sha is not None:
            require(sha(source) == sha(dest) == expected_sha, "copy changed: " + str(source))

    def input_integrity(self, private=False):
        self.limit()
        for row in self.inputs:
            self.limit()
            path = self.root / row["path"]
            require(path.is_file() and sha(path) == row["sha256"] and path.stat().st_size == row["bytes"],
                    "source input drift: " + row["path"])
            if private:
                path = self.project / row["path"]
                require(path.is_file() and sha(path) == row["sha256"] and path.stat().st_size == row["bytes"],
                        "private input drift: " + row["path"])
        require(sha(self.args.godot) == self.receipt["godot_sha256"], "Godot binary drift")
        for source, digest in self.code_pins.items(): require(sha(source) == digest, "proposal/helper drift: " + source)
        if private:
            for row in self.receipt["added_qa_files"]:
                require(sha(self.project / row["path"]) == row["sha256"], "private QA harness drift")
            require(self.shared.native_dependencies() == self.native, "source native manifest/file drift")
            for row in self.receipt["native_installed_files"]:
                require(sha(self.project / row["path"]) == row["sha256"] and (self.project / row["path"]).stat().st_size == row["bytes"], "private native binding/binary drift")
            actual = installed_identity(self.project)
            require(actual == self.installed, "entire installed runtime identity drift/addition")

    def preflight(self):
        with self.stage("preflight") as step:
            self.limit()
            baseline = read(self.args.source_receipt)
            require(baseline.get("complete") is True and baseline.get("private_runtime_patches") == 0,
                    "source receipt is not qualified zero-patch source")
            require(Path(baseline["source_root"]).resolve() == self.root, "source receipt repository mismatch")
            self.inputs = baseline["source_files"]
            grouped = {}
            for row in self.inputs: grouped.setdefault(row["path"], []).append(row)
            duplicates = {p: rows for p, rows in grouped.items() if len(rows) > 1}
            expected_duplicates = {
                "assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png",
                "assets/characters/lin_chong_traits_20261006/idle_spacing2_v4.png.import",
                "assets/characters/wu_song_traits_20261006/idle_spacing_v4.png",
                "assets/characters/wu_song_traits_20261006/idle_spacing_v4.png.import"}
            require(len(self.inputs) == 5039 and len(grouped) == 5035 and set(duplicates) == expected_duplicates
                    and all(len(rows) == 2 and rows[0] == rows[1] for rows in duplicates.values()),
                    "qualified raw manifest5039rows/5035distinct and four exact registered duplicate rows required")
            self.receipt["manifest_inventory"] = {"raw_rows": 5039, "distinct_paths": 5035,
                                                   "identical_duplicate_paths": sorted(duplicates)}
            for row in self.inputs:
                relative_path(row["path"])
                require(isinstance(row["bytes"], int) and row["bytes"] >= 0 and re.fullmatch(r"[0-9a-f]{64}", row["sha256"]), "input row invalid")
            cache = read(self.args.cache_receipt)
            require(cache.get("source_files") == self.inputs and Path(cache["source_root"]).resolve() == self.root,
                    "cache/source receipt frozen inputs differ")
            import_steps = [row for row in cache.get("steps", []) if row.get("case") == "import" and row.get("exit_code") == 0 and not row.get("stop_reason")]
            require(len(import_steps) == 1, "cache has no unique successful import evidence")
            cache_log = Path(cache["run"]) / "import.log"
            require(cache_log.is_file() and sha(cache_log) == import_steps[0]["log_sha256"] and not ENGINE_ERRORS.search(cache_log.read_text(encoding="utf-8", errors="replace")), "cached import log absent/changed/errored")
            engine_pin = read(self.root / "qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json")
            require(engine_pin.get("complete") is True and engine_pin.get("private_runtime_patches") == 0, "qualified engine/native anchor invalid")
            self.receipt.update(source_receipt=str(self.args.source_receipt), source_receipt_sha256=sha(self.args.source_receipt),
                                cache_receipt=str(self.args.cache_receipt), cache_receipt_sha256=sha(self.args.cache_receipt),
                                engine_anchor_sha256=sha(self.root / "qa/zhu_wounded_20261005/campaign_units_qualified_v19d.json"),
                                source_files=self.inputs, godot_sha256=engine_pin["godot_sha256"],
                                cache_project=cache["project"], cached_import_log_sha256=sha(cache_log))
            self.cache = cache
            helper = self.root / "tools/run_steam_integration_qa.py"
            require(sha(helper) == engine_pin["native_dependencies"]["steam_stats_reader"]["source_inputs"]["tools/run_steam_integration_qa.py"],
                    "native helper differs from qualified provenance anchor")
            self.code_pins[str(helper)] = sha(helper)
            proposal = Path(__file__).resolve().parent
            for name in ["run_daming_admit_v24o1.py", "daming_admit_cross_process_v24o.gd", "daming_admit_cross_process_v24o.tscn"]:
                self.code_pins[str(proposal / name)] = sha(proposal / name)
            self.receipt["helper_and_proposal_files"] = [{"path": p, "sha256": digest} for p, digest in self.code_pins.items()]
            self.input_integrity()
            spec = importlib.util.spec_from_file_location("daming_v24o_shared_native", helper)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            require(module.ROOT.resolve() == self.root, "native helper bound to a different source root")
            self.shared = module
            self.native = module.native_dependencies()
            require(self.native == cache["native_dependencies"] == engine_pin["native_dependencies"], "native manifests not identical to qualified/cache anchor")
            step.update(inputs=5039, cache_import_qualified=True, godot_sha256=self.receipt["godot_sha256"])

    def wait_prior(self):
        with self.stage("wait_fx_terminal") as step:
            while not self.args.prior_receipt.is_file():
                self.limit()
                require(self.args.prior_pid is not None, "FX receipt not terminal; --prior-pid required to verify live wait")
                rows = cim_processes(self.args.prior_pid)
                require(len(rows) == 1 and "run_fx_partition_v24n" in (rows[0].get("CommandLine") or ""), "specific prior FX process handle missing or identity changed without terminal receipt")
                step["last_live_prior_pid"] = int(rows[0]["ProcessId"])
                step["last_live_observation_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
                print("WAIT verified live FX producer", self.args.prior_pid, flush=True)
                self.pause()
            prior = read(self.args.prior_receipt)
            require(prior.get("complete") is True and prior.get("lock_released") is True and prior.get("private_runtime_patches") == 0 and prior.get("source_files") == self.inputs,
                    "FX terminal receipt failed or frozen inputs differ")
            require(prior.get("godot_sha256") == self.receipt["godot_sha256"] and prior.get("root_input_drift") == 0 and prior.get("private_input_drift") == 0,
                    "FX engine/source integrity qualification absent")
            for phase in ["component", "restart"]:
                report = prior.get("reports", {}).get(phase, {})
                require(report.get("passed") is True and report.get("checks") and all(row.get("passed") is True for row in report["checks"]), "FX native report not fully passed: " + phase)
                steps = [row for row in prior["steps"] if row.get("case") == phase and row.get("complete") is True]
                require(len(steps) == 1 and steps[0].get("exit_code") == 0 and not steps[0].get("stop_reason"), "FX phase no unique successful native exit")
                attempt = Path(steps[0]["attempt"])
                require(sha(attempt / "report.json") == steps[0]["report_sha256"] and read(attempt / "report.json") == report, "FX report bytes differ from terminal evidence")
                require(sha(attempt / "runtime.log") == steps[0]["log_sha256"] and not ENGINE_ERRORS.search((attempt / "runtime.log").read_text(encoding="utf-8", errors="replace")), "FX native log invalid")
            require(prior["reports"]["component"]["pid"] != prior["reports"]["restart"]["pid"], "FX restart not distinct process")
            if self.args.prior_pid is not None:
                rows = cim_processes(self.args.prior_pid)
                while rows:
                    require(len(rows) == 1 and "run_fx_partition_v24n" in (rows[0].get("CommandLine") or ""),
                            "prior PID was reused by a different process")
                    print("WAIT verified FX terminal producer process exit", self.args.prior_pid, flush=True)
                    self.pause()
                    rows = cim_processes(self.args.prior_pid)
            self.receipt.update(prior_receipt=str(self.args.prior_receipt), prior_receipt_sha256=sha(self.args.prior_receipt))
            step.update(prior_complete=True, prior_sha256=sha(self.args.prior_receipt))

    def wait_idle(self):
        while True:
            self.limit()
            rows = engine_rows()
            if not rows and not self.lock.exists(): return
            print("WAIT natural shared engine idle", rows, "lock_busy=", self.lock.exists(), flush=True)
            self.pause()

    def acquire(self):
        while True:
            self.wait_idle()
            try:
                self.lock.parent.mkdir(parents=True, exist_ok=True)
                with self.lock.open("x", encoding="utf-8") as stream: stream.write(str(self.run))
                self.locked = True
            except FileExistsError:
                self.pause(); continue
            if not engine_rows(): return
            self.release()

    def release(self):
        if self.locked and self.lock.exists() and self.lock.read_text(encoding="utf-8") == str(self.run):
            self.lock.unlink()
        self.locked = False

    def prepare(self):
        with self.stage("freeze_private_project") as step:
            self.limit(); self.input_integrity()
            self.project.mkdir(exist_ok=False)
            cache_project = no_reparse(Path(self.cache["project"]).resolve())
            require(not cache_project.is_relative_to(self.root) and cache_project.is_dir(), "private cache root invalid")
            for row in self.inputs:
                require(sha(cache_project / row["path"]) == row["sha256"], "cached source drift before reuse")
                self.copy_checked(self.root / row["path"], self.project / row["path"], row["sha256"])
            cache_dir = cache_project / ".godot"
            require(cache_dir.is_dir(), "successful imported cache no longer present")
            copied_cache = []
            for source in sorted(cache_dir.rglob("*")):
                self.limit(); no_reparse(source)
                relative = source.relative_to(cache_dir)
                if source.is_dir(): (self.project / ".godot" / relative).mkdir(parents=True, exist_ok=True)
                else:
                    digest = sha(source)
                    self.copy_checked(source, self.project / ".godot" / relative, digest)
                    copied_cache.append({"path": relative.as_posix(), "bytes": source.stat().st_size, "sha256": digest})
            dump_new(self.run / "copied_cache_manifest.json", copied_cache)
            self.receipt["copied_cache_manifest_sha256"] = sha(self.run / "copied_cache_manifest.json")
            self.receipt["cache_only_reused"] = True
            self.receipt["native_dependencies"] = self.shared.install_native(self.project)
            require(self.receipt["native_dependencies"] == self.native, "native installation returned different pins")
            native_rows = []
            for source in sorted((self.project / "addons").rglob("*")):
                no_reparse(source)
                if source.is_file(): native_rows.append({"path": source.relative_to(self.project).as_posix(), "bytes": source.stat().st_size, "sha256": sha(source)})
            self.receipt["native_installed_files"] = native_rows
            additions = []
            for name in ["daming_admit_cross_process_v24o.gd", "daming_admit_cross_process_v24o.tscn"]:
                source = Path(__file__).resolve().with_name(name)
                target = self.project / "tools" / name
                self.copy_checked(source, target, self.code_pins[str(source)])
                additions.append({"path": "tools/" + name, "bytes": target.stat().st_size, "sha256": sha(target), "kind": "explicit additional QA harness, outside installed runtime roots"})
            self.receipt["added_qa_files"] = additions
            self.installed = installed_identity(self.project)
            self.receipt["installed_identity"] = self.installed
            self.input_integrity(True)
            self.profile = self.run / "profile"
            self.profile.mkdir(exist_ok=False)
            for key in ["appdata", "localappdata", "temp", "tmp"]: (self.profile / key).mkdir()
            self.output = self.run / "native_evidence"
            self.output.mkdir(exist_ok=False)
            self.receipt["private_profile"] = str(self.profile)
            self.env = os.environ.copy()
            mode_keys = {"LEVEL", "SCENARIO", "CUSTOM_DEFENSE", "SKIRMISH", "SKIRMISH_AI", "ARENA", "AUTO_MICRO", "AUTOMICRO", "SCREENSHOT_DIR", "WORLD_SHADOW_ENABLED"}
            for key in list(self.env):
                if key.startswith(("LSH_", "ART_", "DAMING_ADMIT_")) or key.endswith(("_TEST", "_QA", "_QA_MANIFEST", "_AUDIT")) or key in mode_keys: self.env.pop(key)
            for key in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]: self.env[key] = str(self.profile / key.lower())
            self.env.update(STEAM_DISABLED="1", CAMPAIGN_QA="1", CONTENT_UPDATE_NO_AUTO="1",
                            DAMING_ADMIT_PROFILE=str(self.profile), DAMING_ADMIT_OUT=str(self.output),
                            DAMING_ADMIT_EXPECT_CONTENT=self.installed["content_version"],
                            DAMING_ADMIT_EXPECT_ENGINE=self.receipt["godot_sha256"])
            step.update(inputs=5039, cache_files=len(copied_cache), qa_additions=additions,
                        content_version=self.installed["content_version"])

    def stop_owned(self):
        if self.child is not None and self.child.poll() is None:
            self.child.terminate()
            try: self.child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                # Only the exact Popen-owned child, never names/PIDs discovered via CIM.
                self.child.kill(); self.child.wait(timeout=15)

    def native_phase(self, label, arguments, env, timeout_seconds, validator):
        with self.stage(label) as step:
            log = Path(step["step_dir"]) / "native.log"
            step.update(command=[str(self.args.godot), "--path", str(self.project), *arguments],
                        profile=str(self.profile), process_nonce=env.get("DAMING_ADMIT_NONCE", ""),
                        stop_reason=None, exit_code=None, process_terminal=False)
            try:
                self.input_integrity(True); self.acquire(); self.input_integrity(True)
                self.limit()
                require(not engine_rows(), "foreign engine entered before child launch")
                print("RUN", label, self.run, flush=True)
                with log.open("xb") as stream:
                    self.child = subprocess.Popen(step["command"], cwd=self.project, env=env,
                                                  stdout=stream, stderr=subprocess.STDOUT,
                                                  creationflags=subprocess.CREATE_NO_WINDOW)
                    step.update(pid=self.child.pid, native_started_ns=time.monotonic_ns(),
                                native_started_utc=dt.datetime.now(dt.timezone.utc).isoformat())
                    started, last_notice = time.monotonic(), time.monotonic()
                    while self.child.poll() is None:
                        self.limit()
                        rows = engine_rows(self.child.pid)
                        if rows:
                            step.update(stop_reason="foreign_engine_resumed", foreign_engine_pids=rows)
                            raise BatchFailure("foreign_engine_resumed; entire batch/profile preserved, no retry")
                        if ENGINE_ERRORS.search(log.read_text(encoding="utf-8", errors="replace")):
                            step["stop_reason"] = "engine_or_script_error"
                            raise BatchFailure("native engineering error")
                        if time.monotonic() - started > timeout_seconds:
                            step["stop_reason"] = "own_stage_timeout"
                            raise BatchFailure("native own stage timeout")
                        if time.monotonic() - last_notice >= 25:
                            print("RUNNING", label, round(time.monotonic() - started), "s", flush=True)
                            last_notice = time.monotonic()
                        self.pause(0.5)
                    step.update(native_finished_ns=time.monotonic_ns(), exit_code=self.child.returncode,
                                process_terminal=self.child.poll() is not None)
                text = log.read_text(encoding="utf-8", errors="replace")
                require(not ENGINE_ERRORS.search(text), "native error in final log")
                validator(step, text)
                self.input_integrity(True)
            except BaseException as exc:
                if step["stop_reason"] is None:
                    step["stop_reason"] = "authorized_six_am_wrap_deadline" if "authorized_six_am" in str(exc) else "producer_or_validation_exception"
                raise
            finally:
                self.stop_owned()
                if self.child is not None:
                    step.update(pid=self.child.pid, exit_code=self.child.returncode,
                                process_terminal=self.child.poll() is not None,
                                native_finished_ns=step.get("native_finished_ns", time.monotonic_ns()))
                if log.exists(): step.update(log=str(log), log_sha256=sha(log), log_bytes=log.stat().st_size)
                self.child = None
                self.release()

    def evidence_path(self, report, path):
        if path.startswith("user://"):
            result = Path(report["actual_user_data_dir"]) / path.removeprefix("user://")
        else: result = Path(path)
        result = no_reparse(result.resolve())
        require(result.is_relative_to(self.run), "native evidence escaped owned batch")
        return result

    def verify_slot(self, report, handoff, generation):
        userdata = no_reparse(Path(report["actual_user_data_dir"]).resolve())
        require(userdata.is_relative_to((self.profile / "appdata").resolve()), "reported native userdata not isolated")
        path = userdata / "daming_admit_v24o/continue/v1/5088120/1" / f"record_{generation:010d}.json"
        require(path.is_file() and sha(path) == handoff["file_sha256"], "actual committed slot SHA missing/mismatched")
        envelope = read(path)
        require(envelope["magic"] == "LH_CLASSIC_CONTINUE_SLOT" and envelope["app"] == "5088120" and envelope["owner"] == "1" and int(envelope["revision"]) == generation, "disk envelope identity/revision mismatch")
        raw_payload = envelope["payload"].encode("utf-8")
        require(len(raw_payload) == int(envelope["payload_bytes"]) and hashlib.sha256(raw_payload).hexdigest() == envelope["payload_sha256"], "disk envelope payload hash invalid")
        require(json.loads(envelope["payload"]) == handoff["packet"], "handoff complete packet does not equal disk envelope payload")
        expected_prev = "0" * 64 if generation == 1 else self.reports[CASES[0]]["slot_sha256"]
        require(envelope["previous_sha256"] == expected_prev, "disk generation chain previous SHA mismatched")
        retained = self.run / "retained_slots"
        retained.mkdir(exist_ok=True)
        target = retained / f"generation_{generation}.json"
        if not target.exists(): self.copy_checked(path, target, handoff["file_sha256"])
        else: require(sha(target) == handoff["file_sha256"], "retained slot evidence drift")
        return {"path": str(path), "sha256": sha(path), "bytes": path.stat().st_size,
                "retained_path": str(target), "generation": generation, "previous_sha256": envelope["previous_sha256"]}

    def validate_case(self, case, step, text):
        require(step["exit_code"] == 0 and step["process_terminal"] is True, "native case did not actually terminate successfully")
        path = self.output / case / "report.json"
        data = read(path)
        require(data.get("passed") is True and data.get("checks") and all(row.get("passed") is True for row in data["checks"]), "native case/report checks not fully passed")
        require(data["case"] == case and data["pid"] == step["pid"] and data["nonce"] == step["process_nonce"], "native PID/case/nonce mismatch")
        require(data["trusted"]["content_version"] == self.installed["content_version"] and data["trusted"]["engine_binary_sha256"] == self.receipt["godot_sha256"], "native actual content/engine differs from independently pinned inputs")
        require(data.get("teleports") == 0 and data.get("fixture_ticks") == 0 and data.get("progress_injections") == 0 and data.get("clock_acceleration") is False, "native fixture boundary violated")
        require(data.get("public_campaign_continue_qualified") is False and data.get("natural_victory_qualified") is False and data.get("reward_once_qualified") is False, "native scope overclaim")
        for row in data["evidence"]:
            target = self.evidence_path(data, row["path"])
            require(target.is_file() and sha(target) == row["sha256"], "native original evidence file changed/missing")
        labels = {row["label"] for row in data["checks"]}
        mandatory = {"producer pinned exact installed content and engine"}
        if case == CASES[0]:
            mandatory |= {"normal Battle launch already classifies actual Daming context", "native manual admission observed in partial-progress window", "HELD still contains actual incomplete admission", "complete Session save_held succeeds", "actual committed disk head matches receipt"}
            require(data["orders"] == 2, "A ordinary two-mover route not executed")
        else:
            mandatory |= {"correct preceding genuinely distinct process", "prior disk bytes and generation verified", "same frozen source and actual engine across processes", "actual Session prepare_restore succeeds", "actual Session commit_restore_async succeeds", "fresh full Core capture at real restored HELD", "complete whole-world envelope and field set exact", "whole-world schema/profile/context/content/engine envelope exact", "complete exact section keyset retained", "every non-payload mission wrapper field exact", "every non-payload root wrapper field exact", "full Root clock subfield schemas exact", "all complete non-root sections exact after independent install", "Mission complete wall age rebased within real prepare/capture intervals", "Root logical tick/cache phase and mount/HELD input clock contract exact", "all Root non-clock values/references/grids/economy exact", "every Session Campaign option installed exactly", "every Session setting installed exactly", "every installed profile flag exact after Session commit", "Session context and saved resume pause actually installed", "actual durable local lifecycle binding exact", "Steam-disabled Session active lease/context installed", "complete saved Visual root_node installed exactly at HELD"}
            require(data["orders"] == 0, "B/C driver issued gameplay orders")
        if case == CASES[1]: mandatory |= {"original natural native tick completes admission after resume", "admission event/report/control/marker effects occur exactly once", "Mission elapsed advances only by resumed fixed physics ticks", "complete Session save_held succeeds"}
        if case == CASES[2]: mandatory |= {"second generation independently read and no driver orders", "requested real uninterrupted ticks observed", "final running-world complete capture succeeds", "process C leaves generation-two disk slot intact"}
        require(mandatory <= labels, "required original case coverage absent: " + str(sorted(mandatory - labels)))
        require("DAMING_ADMIT_V24O_COMPLETE " + case in text, "native terminal marker missing")
        handoff_name = "handoff_A.json" if case == CASES[0] else "handoff_B.json"
        handoff_path = Path(data["actual_user_data_dir"]) / "daming_admit_v24o" / handoff_name
        handoff = read(handoff_path)
        generation = 1 if case == CASES[0] else 2
        require(int(handoff["generation"]) == generation, "unexpected saved generation")
        if case != CASES[2]: require(handoff["pid"] == step["pid"] and handoff["nonce"] == step["process_nonce"] and handoff["mode"] == case, "saved handoff not from actual current native process")
        if case != CASES[0]:
            preceding = CASES[0] if case == CASES[1] else CASES[1]
            prior = self.reports[preceding]
            require(data["previous_pid"] == prior["pid"] and data["previous_nonce"] == prior["nonce"], "native preceding-process chain broken")
            require(step["pid"] not in [report["pid"] for report in self.reports.values()] and step["process_nonce"] not in [report["nonce"] for report in self.reports.values()], "native process/nonce reused")
            earlier_step = [row for row in self.receipt["steps"] if row["case"] == preceding][0]
            require(earlier_step["process_terminal"] and earlier_step["native_finished_ns"] <= step["native_started_ns"], "native processes overlap or predecessor terminal unverified")
        slot = self.verify_slot(data, handoff, generation)
        step.update(report=str(path), report_sha256=sha(path), checks=len(data["checks"]),
                    slot_sha256=slot["sha256"], slot=slot, actual_content_version=data["trusted"]["content_version"])
        self.reports[case] = {"pid": step["pid"], "nonce": step["process_nonce"], "report": str(path),
                              "report_sha256": sha(path), "checks": len(data["checks"]), "slot_sha256": slot["sha256"], "generation": generation}
        self.receipt["reports"][case] = self.reports[case]

    def execute(self):
        self.preflight(); self.wait_prior()
        with self.stage("wait_natural_engine_idle") as step:
            self.wait_idle(); step["foreign_engines_at_idle"] = engine_rows()
        self.prepare()
        import_env = self.env.copy()
        import_env.update(DAMING_ADMIT_CASE=CASES[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
        def imported(step, text): require(step["exit_code"] == 0 and step["process_terminal"], "complete native import did not exit zero")
        self.native_phase("import", ["--headless", "--editor", "--import", "--quit"], import_env, 900, imported)
        guard_env = self.env.copy()
        guard_env.update(DAMING_ADMIT_PROFILE=str(self.profile / "mismatch"), DAMING_ADMIT_CASE=CASES[0], DAMING_ADMIT_NONCE=uuid.uuid4().hex)
        def guarded(step, text):
            require(step["exit_code"] == 2 and "PRIVATE_PROFILE_REQUIRED" in text and not (self.output / CASES[0]).exists(), "negative profile guard failed or wrote regular evidence")
            require(not list((self.profile / "appdata").rglob("handoff_A.json")), "negative guard wrote continuation handoff")
        self.native_phase("profile_guard", ["--headless", "res://tools/daming_admit_cross_process_v24o.tscn"], guard_env, 300, guarded)
        for case in CASES:
            env = self.env.copy()
            env.update(DAMING_ADMIT_CASE=case, DAMING_ADMIT_NONCE=uuid.uuid4().hex)
            self.native_phase(case, ["--rendering-method", "gl_compatibility", "--audio-driver", "Dummy", "--resolution", "1280x720", "--position", "30000,30000", "res://tools/daming_admit_cross_process_v24o.tscn"], env, 600,
                              lambda step, text, case=case: self.validate_case(case, step, text))
        with self.stage("final_source_native_and_slot_audit") as step:
            self.input_integrity(True)
            require(list(self.reports) == list(CASES), "A/B/C complete sequence missing")
            userdata = Path(read(self.output / CASES[2] / "report.json")["actual_user_data_dir"])
            profile_files = []
            for path in sorted((userdata / "daming_admit_v24o").rglob("*")):
                no_reparse(path)
                if path.is_file(): profile_files.append({"path": str(path), "bytes": path.stat().st_size, "sha256": sha(path)})
            dump_new(self.run / "isolated_slot_and_lifecycle_manifest.json", profile_files)
            step.update(independent_processes=3, isolated_profile_files=len(profile_files))
            self.receipt.update(complete=True, root_input_drift=0, private_input_drift=0,
                                source_native_drift=0, private_native_drift=0, independent_processes=3,
                                slot_and_lifecycle_manifest_sha256=sha(self.run / "isolated_slot_and_lifecycle_manifest.json"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["source-root", "source-receipt", "cache-receipt", "godot", "work-root", "prior-receipt"]:
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--deadline-utc", required=True)
    parser.add_argument("--prior-pid", type=int, help="Required only while the specified FX receipt is not terminal; exact live FX producer PID")
    args = parser.parse_args()
    args.deadline_utc = dt.datetime.fromisoformat(args.deadline_utc)
    require(args.deadline_utc.tzinfo is not None and args.deadline_utc <= AUTHORIZED_DEADLINE, "timezone-aware deadline may not extend the authorized 06:00 wrap")
    for field in ["source_root", "source_receipt", "cache_receipt", "godot", "work_root", "prior_receipt"]:
        value = getattr(args, field)
        require(value.is_absolute(), "explicit absolute path required: " + field)
        no_reparse(value)
        setattr(args, field, value.resolve())
    require(args.source_root.is_dir() and (args.source_root / "project.godot").is_file(), "source root not a Godot project")
    require(not args.work_root.is_relative_to(args.source_root) and args.work_root != args.source_root, "work root must be outside source checkout")
    args.work_root.mkdir(parents=True, exist_ok=True)
    run = args.work_root / ("daming_admit_v24o1_" + uuid.uuid4().hex[:8])
    run.mkdir(exist_ok=False)
    runner = Runner(args, run)
    code = 0
    try:
        runner.execute()
    except BaseException as exc:
        code = 1
        runner.receipt["complete"] = False
        runner.receipt["failure"] = {"type": type(exc).__name__, "message": str(exc)}
    finally:
        try: runner.stop_owned()
        except BaseException as exc:
            runner.receipt["complete"] = False
            runner.receipt["termination_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            code = 1
        try: runner.release()
        except BaseException as exc:
            runner.receipt["complete"] = False
            runner.receipt["lock_release_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            code = 1
        try:
            runner.receipt["lock_released"] = not runner.lock.exists() or runner.lock.read_text(encoding="utf-8") != str(run)
        except BaseException as exc:
            runner.receipt["lock_released"] = False
            runner.receipt["lock_audit_failure"] = {"type": type(exc).__name__, "message": str(exc)}
            code = 1
        runner.receipt["complete"] = runner.receipt["complete"] and runner.receipt["lock_released"]
        runner.receipt["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        dump_new(run / "receipt.json", runner.receipt)
        print(json.dumps({"run": str(run), "complete": runner.receipt["complete"], "failure": runner.receipt.get("failure")}, ensure_ascii=False), flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
