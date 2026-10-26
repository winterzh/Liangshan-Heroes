"""Narrow native ownership-lifetime reproducer. Expected Engine/script crash is diagnostic, never acceptance."""
from pathlib import Path
import argparse
import json
import subprocess
from run_component import ROOT, h

HOLDER = "extends RefCounted\nvar retained_value := 1\n"
WORKER = '''extends SceneTree
func _initialize() -> void:
    call_deferred("probe")
func probe() -> void:
    var mode := OS.get_environment("META_MODE")
    var retained: RefCounted
    if mode == "engine_builtin": retained = RefCounted.new()
    else: retained = load("res://holder.gd").new()
    if mode == "root_script": root.set_meta("shutdown_fixture", retained)
    else: Engine.set_meta("shutdown_fixture", retained)
    print("METADATA_RETAINED ", mode)
    quit(0)
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if not args.execute:
        print(json.dumps({"preflight": True, "engine_started": False})); return
    output = ROOT / ".godot/process_liveness_metadata_20261027" / h.stamp()
    output.mkdir(parents=True, exist_ok=False)
    receipt = {"schema": "process_liveness_metadata_shutdown_reproducer_v1", "complete": False,
               "cases": [], "component_qualified": False, "production_integrated": False}
    locked = False
    process = None
    try:
        assert not h.shared.LOCK.exists() and not h.running()
        with h.shared.LOCK.open("x", encoding="utf-8") as stream: stream.write(str(output))
        locked = True
        engine = h.shared.resolve_godot(None)
        pins = {str(engine): h.sha(engine), str(Path(__file__)): h.sha(Path(__file__))}
        for mode in ["engine_builtin", "engine_script", "root_script"]:
            project = output / mode; project.mkdir()
            (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Metadata Lifetime Reproducer"\n', encoding="utf-8")
            (project / "holder.gd").write_text(HOLDER, encoding="utf-8")
            (project / "worker.gd").write_text(WORKER, encoding="utf-8")
            for path in project.iterdir(): pins[str(path)] = h.sha(path)
            profile = output / (mode + "_profile"); profile.mkdir()
            env = h.common.private_environment(profile); env["META_MODE"] = mode
            with (output / (mode + ".log")).open("xb") as log:
                command = [str(engine), "--headless", "--path", str(project), "--script", str(project / "worker.gd")]
                process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
                process.wait(timeout=20)
            text = (output / (mode + ".log")).read_text("utf-8", errors="replace")
            receipt["cases"].append({"mode": mode, "pid": process.pid, "exit": process.returncode,
                "retained_marker": "METADATA_RETAINED " + mode in text,
                "script_errors": any(x in text for x in ["SCRIPT ERROR:", "Parse Error:", "Compile Error:"]), "command": command})
        receipt["pins"] = pins
        receipt["pins_unchanged"] = all(h.sha(Path(path)) == digest for path, digest in pins.items())
        cases = {row["mode"]: row for row in receipt["cases"]}
        receipt["engine_script_shutdown_av_reproduced"] = cases["engine_script"]["exit"] == 3221225477
        receipt["controls_exit_zero"] = cases["engine_builtin"]["exit"] == 0 and cases["root_script"]["exit"] == 0
        receipt["complete"] = receipt["pins_unchanged"] and receipt["engine_script_shutdown_av_reproduced"] and receipt["controls_exit_zero"] and all(row["retained_marker"] and not row["script_errors"] for row in receipt["cases"])
    except BaseException as error:
        receipt["error"] = repr(error)
    finally:
        if process is not None and process.poll() is None: process.kill(); process.wait(timeout=10)
        receipt["owned_child_terminal"] = process is None or process.poll() is not None
        if locked and h.shared.LOCK.exists() and h.shared.LOCK.read_text("utf-8") == str(output) and not h.running(): h.shared.LOCK.unlink()
        receipt["lock_released"] = locked and not h.shared.LOCK.exists()
        receipt["complete"] = receipt["complete"] and receipt["owned_child_terminal"] and receipt["lock_released"]
        h.save(output / "receipt.json", receipt)
    print(json.dumps({"output":str(output), **receipt}, ensure_ascii=False))
    if not receipt["complete"]: raise SystemExit(1)

if __name__ == "__main__": main()
