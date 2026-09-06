"""Prepare native profiling diagnostic only. --run starts one fixed/20s process.

No production rewrite, patch application, Git write, or normal FPS acceptance.
"""
import argparse
import ast
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = "4baafc11af55b0e46a57a48e54df181b8c1917a2"
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
SAFETY = "scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def need(ok, message):
    if not ok: raise RuntimeError(message)


def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def module(path):
    ns = {"__file__":str(path), "__name__":"native_sections_existing_helper"}
    exec(compile(path.read_text(encoding="utf-8-sig"), str(path), "exec"), ns)
    return ns


def verify(pins):
    need(subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip() == BASE, "Reference checkout HEAD changed; review before reuse")
    for path, item in pins["sources"].items():
        raw = (ROOT / path).read_bytes()
        need(sha(raw) == item["raw_sha256"], "Pinned source changed: " + path)
    for path, value in pins["drafts"].items():
        need(sha((HERE / path).read_bytes()) == value, "Frozen draft changed: " + path)


def analyze(m1, native):
    need(m1.get("integrity_passed") and m1.get("sample_complete") and m1.get("acceptance_eligible") is False,
         "Instrumented M1 must be complete/integral and remain ineligible")
    need(m1["requested_seconds"] == 20 and m1["scenario"] == "defense200" and m1["camera_mode"] == "fixed", "Unexpected inherited M1 fixture/window")
    need(native.get("native_valid") and native.get("acceptance_eligible") is False, "Invalid native sidecar")
    columns = native["columns"]
    rows = native["rows"]
    idx = {key:i for i,key in enumerate(columns)}
    need(len(rows) == native["row_count"] and len(rows) <= native["capacity"], "Native row count/capacity mismatch")
    need(all(len(row) == len(columns) for row in rows), "Truncated native row")
    need([row[idx["m1_tick"]] for row in rows] == list(range(1,len(rows)+1)), "Native ticks missing or duplicated")
    need(all(row[idx["native_prof_frames"]] == 1 and row[idx["label_presence_mask"]] == 511 for row in rows), "Native callbacks/labels missing")
    for previous, current in zip(rows, rows[1:]):
        need(current[idx["engine_physics_frame_at_start"]] == previous[idx["engine_physics_frame_at_start"]] + 1, "Engine physics steps not consecutive")
    for index, row in enumerate(rows):
        expected = row[idx["engine_physics_frame_at_start"]] + (0 if index == len(rows)-1 else 1)
        need(row[idx["engine_physics_frame_at_collection"]] == expected, "Native collection assigned to wrong boundary, including final step")
    start = m1["sample_start"]["tick"]
    end = m1["sample_end"]["tick"]
    need(end-start == m1["physics_ticks"] and end == len(rows), "M1/native final tick mismatch")
    selected = [row for row in rows if start < row[idx["m1_tick"]] <= end]
    need(len(selected) == m1["physics_ticks"] and selected, "Measurement ticks were not selected exactly once")
    labels = columns[9:]
    need(labels == ["grid","aura","stealth_ecast","automicro","summon_eco","separation","fog","zones","level_hud"], "Native labels drifted")
    totals = {}
    for key in ["unit_phys_body_us"] + labels:
        need(all(row[idx[key]] >= 0 for row in rows), "Negative native duration: " + key)
        values = [row[idx[key]] for row in selected]
        totals[key] = {"total_us":sum(values),"mean_us_per_physics_step":sum(values)/len(values),"max_us_per_physics_step":max(values)}
    need(native["prefs_before"] == native["prefs_at_dispose"], "Player save hash mismatch")
    return {"analysis_valid":True,"measurement_start_tick_exclusive":start,"measurement_end_tick_inclusive":end,
            "measurement_physics_steps":len(selected),"warmup_and_anchor_rows_excluded":start,
            "per_section":totals,"m1_contact_covered":m1["contact_covered"],
            "scope":"Native nested segments only. Never sum with full callback spans; no normal FPS comparison.",
            "acceptance_eligible":False,"performance_claim":False}


def prepare(pins):
    verify(pins)
    generated = HERE / "generated"
    generated.mkdir(exist_ok=True)
    driver = generated / "driver.gd"
    driver.write_bytes((HERE / "driver.gd.in").read_bytes())
    save(HERE / "preparation_receipt.json", {"base":BASE,"driver_raw_sha256":sha(driver.read_bytes()),
         "pins":pins,"godot_run":False,"gdscript_parsed_or_executed":False,"production_mutated":False,"performance_claim":False})
    return driver


def run(args, driver, pins):
    safe = module(ROOT / SAFETY)
    helper = module(ROOT / "tools/run_polish_performance.py")
    exe = safe["resolve_godot"](args.godot)
    safe["require_exclusive_godot"]()
    need(not LOCK.exists(), "Shared Godot/source slot is already locked")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = HERE / "runs" / stamp
    output.mkdir(parents=True,exist_ok=False)
    need(HERE.resolve() in output.resolve().parents, "Output escaped bounded draft")
    source = helper["source_receipt"]()
    driver_hash = sha(driver.read_bytes())
    receipt = {"base":BASE,"complete":False,"production_mutated":False,"performance_claim":False,
               "driver_raw_sha256":driver_hash,"godot_raw_sha256":sha(Path(exe).read_bytes())}
    save(output / "source_before.json", source)
    with LOCK.open("x",encoding="utf-8") as stream: stream.write(str(output) + "\n")
    try:
        verify(pins)
        env, controls = helper["environment"]()
        for key in list(env):
            if key.startswith("NATIVE_SECTIONS_"): env.pop(key)
        env.update(NATIVE_SECTIONS_OUT=str(output / "native_profile.json"),POLISH_CASE="defense200",POLISH_CAMERA="fixed",POLISH_SECONDS="20",POLISH_OUT=str(output / "instrumented_m1_20s.json"))
        save(output / "configuration.json", {"controlled_environment":controls,"scenario":"defense200","camera":"fixed","seconds":20,"pins":pins,"acceptance_eligible":False,"scope":"Native instrumented diagnostic; inherited M1 report retained unchanged"})
        m1 = safe["run_godot"](exe, driver, output / "instrumented_m1_20s.json", env, 200, validity_key="integrity_passed")
        native = json.loads((output / "native_profile.json").read_text(encoding="utf-8-sig"))
        summary = analyze(m1, native)
        save(output / "native_analysis.json", summary)
        receipt["complete"] = True
    except BaseException as exc:
        receipt["exception"] = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        try:
            safe["require_exclusive_godot"]()
            verify(pins)
            after = helper["source_receipt"]()
            save(output / "source_after.json", after)
            need(after == source and sha(driver.read_bytes()) == driver_hash, "Source/resource/driver changed during diagnostic")
            need(LOCK.read_text(encoding="utf-8").strip() == str(output), "Shared lock ownership changed")
            LOCK.unlink(); receipt["lock_released"] = True
        except BaseException as exc:
            receipt["cleanup_error"] = type(exc).__name__ + ": " + str(exc)
            receipt["lock_released"] = False
        save(output / "receipt.json", receipt)
        print(json.dumps({"output":str(output),"complete":receipt["complete"],"lock_released":receipt["lock_released"],"performance_claim":False}))
    return 0 if receipt["complete"] and receipt["lock_released"] else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run",action="store_true")
    parser.add_argument("--godot")
    args = parser.parse_args()
    pins = json.loads((HERE / "pins.json").read_text(encoding="utf-8"))
    if LOCK.exists():
        owner = Path(LOCK.read_text(encoding="utf-8").strip())
        need(owner.parent != HERE / "runs", "Do not regenerate the native driver while this diagnostic owns the shared slot")
    driver = prepare(pins)
    print(json.dumps({"prepared":True,"godot_run":False,"production_mutated":False,"gdscript_parsed":False}))
    return run(args,driver,pins) if args.run else 0


if __name__ == "__main__":
    raise SystemExit(main())
