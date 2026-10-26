"""Freeze and run only the four-file integration component; default is read-only preflight."""
from pathlib import Path
import argparse
import ctypes
import importlib.util
import json
import os
import subprocess
import sys
import time
import traceback
import uuid

HERE = Path(__file__).resolve().parent
CANDIDATE = HERE.parent
ROOT = CANDIDATE.parents[2]
COMPONENT = ROOT / "qa/campaign_progress_recovery_20261026/process_liveness_candidate"

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

h = module("integration_component_helpers", ROOT / "qa/huangnigang_production_20261020/run_batch.py")
native = module("integration_component_native", COMPONENT / "tests/run_godot_component.py")

def require(value, message):
    if not value:
        raise RuntimeError(message)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    require(os.name == "nt", "Windows-only actual native component run")
    source_manifest = CANDIDATE / "source_manifest.json"
    overlay = h.read(source_manifest)
    helper = ROOT / overlay["helper"]["ignored_artifact_path"]
    require(h.sha(helper) == overlay["helper"]["sha256"], "fixed helper bytes changed")
    files = {}
    for row in overlay["files"]:
        source = CANDIDATE / row["path"]
        require(h.sha(source) == row["candidate_sha256"], "overlay source changed: " + str(source))
        files[row["path"]] = source
    require(len(files) == 4, "exact four-file overlay required")
    previous = ROOT / overlay["previous_20file_manifest"]["path"]
    require(h.sha(previous) == overlay["previous_20file_manifest"]["sha256"], "previous manifest changed")
    prior = h.read(previous)
    receipt_source = previous.parent / "scripts/steam_run_receipt.gd"
    receipt_row = next(row for row in prior["files"] if row["path"] == "scripts/steam_run_receipt.gd")
    require(h.sha(receipt_source) == receipt_row["candidate_sha256"], "actual receipt dependency changed")
    files.update({"scripts/steam_run_receipt.gd": receipt_source,
                  "scripts/steam_achievement_catalog.gd": ROOT / "scripts/steam_achievement_catalog.gd",
                  "scripts/steam_achievement_state.gd": ROOT / "scripts/steam_achievement_state.gd",
                  "bootstrap.gd": HERE / "bootstrap.gd", "component.gd": HERE / "component.gd",
                  "report_model.gd": COMPONENT / "tests/report_model.gd",
                  "addons/process_liveness/windows/ProcessLivenessProbe.exe": helper})
    pins = {str(source): h.sha(source) for source in files.values()}
    for source in [source_manifest, previous, Path(__file__), Path(native.__file__),
                   COMPONENT / "native/ProcessLivenessProbe.cs", ROOT / overlay["helper"]["build_receipt_path"]]:
        pins[str(source)] = h.sha(source)
    for helper_module in [h, h.shared, h.common, h.identity]:
        source = Path(helper_module.__file__)
        pins[str(source)] = h.sha(source)
    if not args.execute:
        print(json.dumps({"preflight": True, "engine_started": False, "files": len(files), "pins": pins}, ensure_ascii=False)); return
    output = ROOT / ".godot/process_liveness_integration_20261026" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "process_liveness_integration_host_v1", "complete": False, "output": str(output),
               "component_only": True, "gameplay_qualified": False, "store_dead_writer_recovery_qualified": False,
               "timeout_termination_qualified": False, "production_integrated": False, "sdk_qualified": False}
    children = []
    engine_child = None
    locked = False
    targets = []
    nonce = uuid.uuid4().hex
    try:
        require(not h.shared.LOCK.exists() and not h.running(), "Shared engine occupied; never queue")
        with h.shared.LOCK.open("x", encoding="utf-8") as stream:
            stream.write(str(output))
        locked = True
        engine = h.shared.resolve_godot(None)
        pins[str(engine)] = h.sha(engine)
        project = output / "project"
        project.mkdir()
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Liveness Integration Component"\n[physics]\ncommon/physics_ticks_per_second=60\n', encoding="utf-8")
        for target, source in files.items():
            destination = project / target
            h.copy_checked(source, destination, pins[str(source)])
            pins[str(destination)] = pins[str(source)]
        pins[str(project / "project.godot")] = h.sha(project / "project.godot")
        inputs = output / "inputs"; inputs.mkdir()
        for index, (name, digest) in enumerate(list(pins.items())):
            source = Path(name)
            if source == engine or source.suffix.lower() == ".exe" or source.is_relative_to(project):
                continue
            h.copy_checked(source, inputs / (str(index).zfill(2) + "_" + source.name), digest)
        h.copy_checked(source_manifest, output / "source_manifest.original.json", h.sha(source_manifest))
        profile = Path(ROOT.anchor) / "CodexQA/procliveint" / nonce[:12]
        profile.mkdir(parents=True, exist_ok=False)
        private_environment = h.common.private_environment(profile)
        # Register the actual dependency's class_name through the normal Godot editor scan.
        # A raw --script run in a never-imported project does not establish that global cache.
        import_command = [str(engine), "--headless", "--editor", "--path", str(project), "--quit"]
        with (output / "import.log").open("xb") as log:
            engine_child = subprocess.Popen(import_command, env=private_environment,
                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            children.append(engine_child)
            receipt["import_pid"] = engine_child.pid
            engine_child.wait(timeout=60)
        receipt["import_exit"] = engine_child.returncode
        import_log = (output / "import.log").read_text("utf-8", errors="replace")
        require(engine_child.returncode == 0 and not any(word in import_log for word in ["SCRIPT ERROR:", "Parse Error:", "Compile Error:", "ERROR:"]), "Editor import failed")
        class_cache = project / ".godot/global_script_class_cache.cfg"
        require(class_cache.is_file(), "Imported actual global class cache missing")
        pins[str(class_cache)] = h.sha(class_cache)
        actual_private = profile / "oracle_private"; actual_private.mkdir()
        target_root = profile / "junction_target"; target_root.mkdir()
        junction_helper_real = target_root / "ProcessLivenessProbe.exe"
        h.copy_checked(helper, junction_helper_real, h.sha(helper))
        pins[str(junction_helper_real)] = h.sha(helper)
        junction = profile / "junction_parent"
        powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        require(powershell.is_file(), "Fixed junction fixture provider missing")
        env_link = dict(os.environ, PLI_LINK=str(junction), PLI_TARGET=str(target_root))
        with (output / "junction.log").open("xb") as log:
            link_process = subprocess.Popen([str(powershell), "-NoProfile", "-NonInteractive", "-Command",
                "$ErrorActionPreference='Stop'; New-Item -ItemType Junction -Path $env:PLI_LINK -Target $env:PLI_TARGET | Out-Null"],
                env=env_link, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            children.append(link_process); link_process.wait(timeout=15)
        require(link_process.returncode == 0, "Actual junction fixture creation failed")
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.GetFileAttributesW.argtypes = [ctypes.c_wchar_p]; kernel.GetFileAttributesW.restype = ctypes.c_uint32
        attributes = kernel.GetFileAttributesW(str(junction))
        require(attributes != 0xffffffff and attributes & 0x400, "Fixture is not a native Windows reparse point")
        receipt["junction_fixture"] = {"path": str(junction), "target": str(target_root), "attributes": attributes,
                                       "provider_pid": link_process.pid, "provider_exit": link_process.returncode}
        def child(code):
            process = subprocess.Popen([sys.executable, "-c", code], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
            children.append(process)
            return process
        live = child("import time; time.sleep(90)")
        held = child("import sys; sys.exit(259)"); held.wait(timeout=10)
        require(held.returncode == 259, "Retained process must actually exit 259")
        gone = child("pass"); gone.wait(timeout=10); gone._handle.Close()
        # Kernel process-object disposal may lag the final Popen handle close. Establish
        # actual ERROR_INVALID_PARAMETER before labeling this distinct fixture "absent".
        released_observations = []
        released_deadline = time.monotonic() + 3
        while True:
            observed = native.native_state(gone.pid)
            released_observations.append(observed)
            if observed.get("error") == 87 and observed["state"] == "dead": break
            require(time.monotonic() < released_deadline, "Released PID did not become absent within bounded fixture setup")
            time.sleep(0.025)
        receipt["released_pid_observations"] = released_observations
        for label, pid, expected, code in [("external sibling alive", live.pid, "alive", "HANDLE_NONSIGNALED"),
                ("retained exit259", held.pid, "dead", "HANDLE_SIGNALED"), ("released PID", gone.pid, "dead", "PID_ABSENT_87"),
                ("permission denied", 4, "unknown", "OPEN_FAILED")]:
            observed = native.native_state(pid)
            require(observed["state"] == expected, "Host fixture state wrong: " + str((label, observed)))
            if code == "PID_ABSENT_87": require(observed.get("error") == 87 and observed["creation_filetime"] == "", "Absent PID fixture no longer absent")
            targets.append(dict(observed, label=label, pid=pid, expected=expected, code=code))
        fixtures = {"nonce": nonce, "targets": targets, "helper_sha256": overlay["helper"]["sha256"],
                    "junction": str(junction), "junction_helper": str(junction / "ProcessLivenessProbe.exe"), "real_private": str(actual_private)}
        h.save(output / "fixtures.json", fixtures)
        pins[str(output / "fixtures.json")] = h.sha(output / "fixtures.json")
        env = dict(private_environment)
        env.update(PLI_WORKER=str(project / "component.gd"), PLI_FIXTURES=str(output / "fixtures.json"), PLI_NONCE=nonce,
                   PLI_REPORT=str(output / "report.json"))
        command = [str(engine), "--headless", "--path", str(project), "--script", str(project / "bootstrap.gd")]
        h.save(output / "manifest.json", {"schema": "process_liveness_integration_freeze_v1", "nonce": nonce, "pins": pins,
                  "original_overlay_manifest_sha256": h.sha(source_manifest), "helper_is_original_pinned_binary": True,
                  "project": str(project), "profile": str(profile), "command": command})
        with (output / "native.log").open("xb") as stream:
            engine_child = subprocess.Popen(command, env=env, stdout=stream, stderr=subprocess.STDOUT,
                                            creationflags=subprocess.CREATE_NO_WINDOW)
            receipt.update(pid=engine_child.pid, nonce=nonce, command=command, profile=str(profile), project=str(project))
            engine_child.wait(timeout=60)
        receipt["exit_code"] = engine_child.returncode
        log = (output / "native.log").read_text("utf-8", errors="replace")
        require(not any(word in log for word in ["SCRIPT ERROR:", "Parse Error:", "Compile Error:", "ERROR:"]), "Native log contains errors")
        require(engine_child.returncode == 0, "Native component failed")
        report = h.read(output / "report.json")
        require(report["passed"] and report["pid"] == engine_child.pid and report["nonce"] == nonce, "Actual Popen/report identity failed")
        require(all(row["passed"] for row in report["checks"]), "Component checks failed")
        require(len(report["model"]["checks"]) == 22 and all(row["passed"] for row in report["model"]["checks"]), "V2 strict model failed")
        receipt["host_after"] = [native.native_state(row["pid"]) for row in targets]
        require(all(row["state"] == after["state"] and row["creation_filetime"] == after["creation_filetime"] for row, after in zip(targets, receipt["host_after"])), "Target identity changed during run")
        require(live.poll() is None, "Queried external sibling was terminated")
        provider_results = output / "provider_results"; provider_results.mkdir()
        for result in report["queries"]:
            observation = result.get("observation", result.get("liveness_detail", {}))
            raw_path = Path(observation["probe_directory"]) / "result.json"
            require(raw_path.is_relative_to(profile), "Provider report escaped private profile")
            raw = h.read(raw_path)
            require(raw["provider_pid"] == str(observation["provider_pid"]) and raw["target_pid"] == str(observation["target_pid"]), "Provider identity mismatch")
            h.copy_checked(raw_path, provider_results / (raw["nonce"] + ".json"), h.sha(raw_path))
        receipt.update(complete=True, model_checks=22, component_checks=len(report["checks"]), native_queries=len(report["queries"]),
                       report_sha256=h.sha(output / "report.json"))
    except BaseException as error:
        receipt["error"] = repr(error)
        receipt["traceback"] = traceback.format_exc()
    finally:
        for process in [engine_child] + children:
            if process is not None and process.poll() is None:
                process.kill(); process.wait(timeout=10)
        receipt["owned_children_terminal"] = all(p is None or p.poll() is not None for p in [engine_child] + children)
        receipt["pins"] = pins
        receipt["pins_unchanged"] = all(Path(path).is_file() and h.sha(Path(path)) == digest for path, digest in pins.items())
        if locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text("utf-8") == str(output) and not h.running():
            h.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not h.shared.LOCK.exists()
        receipt["complete"] = bool(receipt["complete"] and receipt["pins_unchanged"] and receipt["owned_children_terminal"] and receipt["lock_released"])
        h.save(output / "receipt.json", receipt)
    print(json.dumps(receipt, ensure_ascii=False))
    if not receipt["complete"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
