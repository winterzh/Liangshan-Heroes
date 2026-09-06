"""DRAFT. Default prepares only under this directory. Explicit --run mutates temporarily.

No Godot/Git subprocess or production write occurs on the default preparation path.
The pinned candidate Unit is rebuilt from the original backup, never re-locked from
the live Unit while the parent's reference/candidate comparison is in progress.
"""
import argparse
import ast
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GENERATED = HERE / "generated"
FROZEN = HERE / "frozen"
UNIT = "scripts/unit.gd"
BATTLE = "scripts/battle.gd"
OWNED = (BATTLE, UNIT)
UNIT_RAW = "c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856"
UNIT_LF = "c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec"
BATTLE_RAW = "9fe157e49ef18f2ced0b10ee96f893a1f0ded4ce64e6d757e936d4ef4e9e1ee4"
OLD_UNIT_RAW = "f6f9bccd20a13e6d8d2a93647441b9e3b19d40f120c46426c17b85e7e66a6e36"
SAFETY = "scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py"
DEPENDENCIES = ("tools/polish_performance_probe.gd", "tools/zhujiazhuang_rts_test.gd",
                "tools/run_polish_performance.py", SAFETY, "project.godot")
LOCK = ROOT / ".godot/redraw_rejection_source.lock"
LEDGER_RESOURCE = "res://scratchpad/physics_step_diag/generated/ledger.gd"
ORIGINAL_NAME = "_physics_step_diag_original_physics_process"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def lf(raw):
    return raw.replace(b"\r\n", b"\n")


def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode())


def need(condition, message):
    if not condition:
        raise RuntimeError(message)


def span(raw, name):
    hit = re.search(rb"(?m)^func " + re.escape(name.encode()) + rb"\(", raw)
    need(hit is not None, "Missing complete method: " + name)
    following = re.search(rb"(?m)^func ", raw[hit.end():])
    need(following is not None, "Expected following method after " + name)
    return hit.start(), hit.end() + following.start()


def reconstruct_candidate():
    """Only literal AST extraction; do not execute the source-mutating helper."""
    original = (ROOT / "scratchpad/redraw_reject_validation/unit_before.bin").read_bytes()
    need(sha(original) == OLD_UNIT_RAW, "Original Unit backup mismatch")
    patch_source = (ROOT / "scratchpad/apply_redraw_candidate.py").read_text(encoding="utf-8-sig")
    tree = ast.parse(patch_source)
    assignments = [n for n in tree.body if isinstance(n, ast.Assign)
                   and any(isinstance(t, ast.Name) and t.id == "changes" for t in n.targets)]
    need(len(assignments) == 1, "Expected one literal redraw candidate changes dictionary")
    changes = ast.literal_eval(assignments[0].value)
    need(list(changes) == ["_queue_animated_redraw", "_queue_motion_redraw"], "Unexpected candidate scope")
    candidate = original
    for name in reversed(list(changes)):
        start, end = span(candidate, name)
        replacement = changes[name].encode()
        if b"\r\n" in candidate[start:end]:
            replacement = replacement.replace(b"\n", b"\r\n")
        candidate = candidate[:start] + replacement + candidate[end:]
    need(sha(candidate) == UNIT_RAW and sha(lf(candidate)) == UNIT_LF, "Reconstructed candidate mismatch")
    return candidate


def instrument(original, kind):
    need(kind in ("battle", "unit"), "Unknown callback kind")
    need(ORIGINAL_NAME.encode() not in original and b"_PhysicsStepDiag" not in original, "Already instrumented")
    start, end = span(original, "_physics_process")
    complete = original[start:end]
    need(lf(complete).startswith(b"func _physics_process(delta: float) -> void:\n"), "Callback signature drift")
    renamed = complete.replace(b"func _physics_process(", b"func " + ORIGINAL_NAME.encode() + b"(", 1)
    wrapper = '''const _PhysicsStepDiag = preload("%s")

func _physics_process(delta: float) -> void:
	var __diag_measure: bool = _PhysicsStepDiag.active and _PhysicsStepDiag.timing_enabled
	var __diag_tick := 0
	var __diag_started := 0
	if __diag_measure:
		__diag_tick = Engine.get_physics_frames()
		__diag_started = Time.get_ticks_usec()
	%s(delta)
	if __diag_measure:
		var __diag_ended := Time.get_ticks_usec()
		_PhysicsStepDiag.record_%s(__diag_tick, __diag_ended - __diag_started, __diag_ended)


''' % (LEDGER_RESOURCE, ORIGINAL_NAME, kind)
    prefix = wrapper.encode()
    if b"\r\n" in complete:
        prefix = prefix.replace(b"\n", b"\r\n")
    result = original[:start] + prefix + renamed + original[end:]
    # Source-level proof: original body is unchanged, and the wrapper has one call.
    need(prefix.count((ORIGINAL_NAME + "(delta)").encode()) == 1, "Original callback is not called once")
    recovered = result[:start] + result[start + len(prefix):]
    recovered = recovered.replace(b"func " + ORIGINAL_NAME.encode() + b"(", b"func _physics_process(", 1)
    need(recovered == original, "Inverse wrapper transform does not recover every original byte")
    return result, {"method_raw_sha256": sha(complete), "method_lf_sha256": sha(lf(complete)),
                    "full_body_preserved": True, "original_call_sites_in_wrapper": 1,
                    "early_returns_preserved_by_private_complete_method": True}


def prepare():
    if LOCK.exists():
        owner = Path(LOCK.read_text(encoding="utf-8").strip())
        need(owner.parent != HERE / "runs", "This draft owns an active source lock; do not regenerate its artifacts")
    HERE.mkdir(exist_ok=True)
    GENERATED.mkdir(exist_ok=True)
    FROZEN.mkdir(exist_ok=True)
    originals = {UNIT: reconstruct_candidate(), BATTLE: (ROOT / BATTLE).read_bytes()}
    need(sha(originals[BATTLE]) == BATTLE_RAW, "Battle changed; do not refresh pins without review")
    pins_path = HERE / "pins.json"
    observed = {path: {"raw_sha256": sha((ROOT / path).read_bytes()),
                       "lf_sha256": sha(lf((ROOT / path).read_bytes()))} for path in DEPENDENCIES}
    pins = {"schema": 1, "unit_candidate_raw_sha256": UNIT_RAW, "unit_candidate_lf_sha256": UNIT_LF,
            "battle_raw_sha256": BATTLE_RAW, "dependencies": observed,
            "unit_source": "reconstructed from frozen original plus literal two-method redraw replacement; never live alternating Unit",
            "originals": {name: {"raw_sha256": sha(raw), "lf_sha256": sha(lf(raw))} for name, raw in originals.items()}}
    if pins_path.exists():
        need(json.loads(pins_path.read_text(encoding="utf-8")) == pins, "Dependency pins changed; explicit review required")
    else:
        save(pins_path, pins)
    methods = {}
    generated = {}
    for name in OWNED:
        kind = Path(name).stem
        frozen = FROZEN / (kind + "_original.bin")
        if frozen.exists():
            need(frozen.read_bytes() == originals[name], "Frozen original was changed: " + name)
        else:
            frozen.write_bytes(originals[name])
        changed, methods[name] = instrument(originals[name], kind)
        path = GENERATED / (kind + "_instrumented.gd.txt")
        path.write_bytes(changed)
        generated[name] = {"artifact": path.relative_to(HERE).as_posix(), "raw_sha256": sha(changed)}
    for name in ("ledger", "driver"):
        path = GENERATED / (name + ".gd")
        path.write_bytes((HERE / (name + ".gd.in")).read_bytes())
    artifact_hashes = {p.relative_to(HERE).as_posix(): sha(p.read_bytes()) for p in sorted(GENERATED.iterdir()) if p.is_file()}
    manifest = {"schema": 1, "production_mutated": False, "godot_run": False, "git_run": False,
                "gdscript_parsed_or_executed": False, "performance_claim": False,
                "methods": methods, "instrumented": generated, "artifacts": artifact_hashes,
                "source_pins": pins, "separate_callback_scopes": ["Battle._physics_process", "Unit._physics_process"],
                "nested_subitems": [], "prepared_runner_sha256": sha(Path(__file__).read_bytes())}
    save(HERE / "preparation_receipt.json", manifest)
    return originals, manifest


def load_safety():
    path = ROOT / SAFETY
    pins = json.loads((HERE / "pins.json").read_text(encoding="utf-8"))
    need(sha(path.read_bytes()) == pins["dependencies"][SAFETY]["raw_sha256"], "Enhanced safety helper changed; review before execution/recovery")
    namespace = {"__file__": str(path), "__name__": "physics_step_existing_safety"}
    exec(compile(path.read_text(encoding="utf-8-sig"), str(path), "exec"), namespace)
    return namespace


def sources_without_git():
    """M1 source-fingerprint file scope, without invoking Git or logging environment."""
    paths = []
    for directory in ("scripts", "scenes", "assets", "shaders", "resources", "data", "addons", "content", "scenarios"):
        paths += [p for p in (ROOT / directory).rglob("*") if p.is_file()]
    paths += [ROOT / "project.godot", *(ROOT / name for name in DEPENDENCIES)]
    paths += [p for p in ROOT.glob("icon.*") if p.is_file()]
    # Godot may derive .gd.uid siblings. Only the four prepared source artifacts
    # participate; new generated UID sidecars are not a production source edit.
    paths += [GENERATED / name for name in ("ledger.gd", "driver.gd", "battle_instrumented.gd.txt", "unit_instrumented.gd.txt")]
    text_suffixes = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json", ".cfg", ".import", ".uid", ".svg", ".txt", ".csv", ".godot", ".py", ".md"}
    rows = {}
    for path in sorted(set(paths)):
        if not path.is_file(): continue
        raw = path.read_bytes()
        rows[path.relative_to(ROOT).as_posix()] = sha(lf(raw) if path.suffix.lower() in text_suffixes else raw)
    return {"file_sha256": rows, "combined_sha256": sha(json.dumps(rows, sort_keys=True).encode()), "git_used": False}


def atomic_replace(path, desired, expected, output, safe):
    safe["require_exclusive_godot"]()
    temporary = output / (path.stem + "_pending_replace.bin")
    temporary.write_bytes(desired)
    need(temporary.read_bytes() == desired, "Pending bytes failed verification")
    need(path.read_bytes() == expected, "Concurrent source change: " + str(path))
    os.replace(temporary, path)
    need(path.read_bytes() == desired, "Atomic replacement verification failed: " + str(path))


def restore_owned(originals, instrumented, output, safe, receipt):
    receipt["exclusive_before_restore"] = False
    receipt["restored"] = False
    try:
        safe["require_exclusive_godot"]()
        receipt["exclusive_before_restore"] = True
        for name in reversed(OWNED):
            path = ROOT / name
            current = path.read_bytes()
            original = originals[name]
            backup = output / (path.stem + "_original.bin")
            row = {"backup_verified_final": backup.is_file() and backup.read_bytes() == original}
            if current == instrumented[name]:
                # The pinned in-memory original remains authoritative even if the
                # on-disk backup is tampered with. Recovery has stricter checks.
                atomic_replace(path, original, instrumented[name], output, safe)
            elif current != original:
                (output / (path.stem + "_conflicting_current.bin")).write_bytes(current)
                row["source_conflict"] = True
            row["final_sha256"] = sha(path.read_bytes())
            row["restored"] = path.read_bytes() == original
            receipt.setdefault("restoration_files", {})[name] = row
        receipt["restored"] = all((ROOT / name).read_bytes() == originals[name] for name in OWNED)
    except BaseException as exc:
        receipt["restoration_error"] = type(exc).__name__ + ": " + str(exc)
    save(output / "restoration_receipt.json", receipt)
    if receipt["restored"]:
        need(LOCK.read_text(encoding="utf-8").strip() == str(output), "Shared lock owner changed; retain lock")
        LOCK.unlink()
    return receipt["restored"]


def run(args, originals, manifest):
    safe = load_safety()
    exe = safe["resolve_godot"](args.godot)
    safe["require_exclusive_godot"]()
    need(not LOCK.exists(), "Shared source lock exists; do not interfere with another run")
    for name in OWNED:
        need((ROOT / name).read_bytes() == originals[name], "Live source is not the pinned candidate/original: " + name)
    output = HERE / "runs" / datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output.mkdir(parents=True, exist_ok=False)
    instrumented = {name: (HERE / manifest["instrumented"][name]["artifact"]).read_bytes() for name in OWNED}
    for name in OWNED:
        need(sha(instrumented[name]) == manifest["instrumented"][name]["raw_sha256"], "Prepared bytes changed")
    helpers = safe["baseline_helpers"]()
    env, env_receipt = helpers["environment"]()
    for key in list(env):
        if key.startswith("PHYSICS_STEP_"): env.pop(key)
    receipt = {"performance_claim": False, "restored": False, "applied": [], "samples": [],
               "original_sha256": {k: sha(v) for k, v in originals.items()},
               "instrumented_sha256": {k: sha(v) for k, v in instrumented.items()}}
    save(output / "configuration.json", {"seconds": args.seconds, "cameras": args.cameras, "modes": args.modes,
         "repeats": args.repeats, "godot_sha256": sha(Path(exe).read_bytes()), "controlled_environment": env_receipt,
         "preparation": manifest, "status": "diagnostic only; no FPS acceptance", "source_lock": str(LOCK)})
    # Same lock as the enhanced redraw harness: excludes the parent's comparison.
    with LOCK.open("x", encoding="utf-8") as stream:
        stream.write(str(output) + "\n")
    try:
        for name in OWNED:
            backup = output / (Path(name).stem + "_original.bin")
            backup.write_bytes(originals[name])
            need(backup.read_bytes() == originals[name], "Complete backup verification failed")
            (output / (Path(name).stem + "_instrumented.bin")).write_bytes(instrumented[name])
        save(output / "running_receipt.json", receipt)
        save(output / "original_sources.json", sources_without_git())
        for name in OWNED:
            atomic_replace(ROOT / name, instrumented[name], originals[name], output, safe)
            receipt["applied"].append(name)
            save(output / "running_receipt.json", receipt)
        source = sources_without_git()
        save(output / "instrumented_sources.json", source)
        for repetition in range(1, args.repeats + 1):
            order = args.modes if repetition % 2 else list(reversed(args.modes))
            for camera in args.cameras:
                for mode in order:
                    need(sources_without_git()["combined_sha256"] == source["combined_sha256"], "Source/resource changed before diagnostic")
                    report_path = output / ("%s_%s_%d.json" % (mode, camera, repetition))
                    sample_env = env.copy()
                    sample_env.update(PHYSICS_STEP_SECONDS=str(args.seconds), PHYSICS_STEP_CAMERA=camera,
                                      PHYSICS_STEP_MODE=mode, PHYSICS_STEP_OUT=str(report_path))
                    report = safe["run_godot"](exe, GENERATED / "driver.gd", report_path, sample_env, args.seconds + 180)
                    after = sources_without_git()
                    if after["combined_sha256"] != source["combined_sha256"]:
                        save(output / (report_path.stem + "_changed_sources.json"), after)
                        raise RuntimeError("Source/resource changed during diagnostic")
                    receipt["samples"].append({"report": report_path.name, "mode": mode, "camera": camera,
                        "repetition": repetition, "diagnostic_valid": report["diagnostic_valid"],
                        "physics_steps": len(report["step_rows"]), "presentations": len(report["frame_rows"]),
                        "initial_deployment_sha256": sha(json.dumps(report["initial_units"], sort_keys=True).encode())})
                    save(output / "running_receipt.json", receipt)
    except BaseException as exc:
        receipt["exception"] = type(exc).__name__ + ": " + str(exc)
        raise
    finally:
        restore_owned(originals, instrumented, output, safe, receipt)
        print("RESTORATION " + json.dumps({"restored": receipt["restored"], "output": str(output), "performance_claim": False}), flush=True)
    return 0 if receipt["restored"] else 2


def recover(directory):
    """Explicit recovery only; never clear a lock or overwrite unknown current bytes."""
    output = directory.resolve()
    need(HERE.resolve() in output.parents and output.parent.name == "runs", "Recovery must name this draft's own run directory")
    safe = load_safety()
    safe["require_exclusive_godot"]()
    need(LOCK.is_file() and LOCK.read_text(encoding="utf-8").strip() == str(output), "Shared lock does not belong to requested run")
    original_expected = {UNIT: UNIT_RAW, BATTLE: BATTLE_RAW}
    originals = {}
    instrumented = {}
    for name in OWNED:
        original = (output / (Path(name).stem + "_original.bin")).read_bytes()
        need(sha(original) == original_expected[name], "Recovery backup SHA mismatch: " + name)
        transformed, _ = instrument(original, Path(name).stem)
        saved_instrumented = (output / (Path(name).stem + "_instrumented.bin")).read_bytes()
        need(saved_instrumented == transformed, "Recovery instrumented backup mismatch: " + name)
        need((ROOT / name).read_bytes() in (original, transformed), "Unknown current source; preserve conflict and stop: " + name)
        originals[name] = original
        instrumented[name] = transformed
    receipt = {"recovery": True, "performance_claim": False}
    return 0 if restore_owned(originals, instrumented, output, safe, receipt) else 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--run", action="store_true", help="Explicitly apply the prepared wrappers, run diagnostics, then restore.")
    actions.add_argument("--recover", type=Path, metavar="RUN_DIRECTORY")
    parser.add_argument("--godot")
    parser.add_argument("--seconds", type=int, choices=(10, 20, 60), default=10)
    parser.add_argument("--cameras", nargs="+", choices=("fixed", "auto"), default=["fixed"])
    parser.add_argument("--modes", nargs="+", choices=("timed", "clockless_control"), default=["timed", "clockless_control"])
    parser.add_argument("--repeats", type=int, default=1)
    args = parser.parse_args()
    need(args.repeats >= 1 and len(set(args.cameras)) == len(args.cameras) and len(set(args.modes)) == len(args.modes), "Invalid repeated specification")
    if args.recover:
        return recover(args.recover)
    originals, manifest = prepare()
    print("PREPARED " + str(HERE) + "; no production edit, Godot, Git, or normal FPS conclusion", flush=True)
    if not args.run:
        return 0
    return run(args, originals, manifest)


if __name__ == "__main__":
    sys.exit(main())
