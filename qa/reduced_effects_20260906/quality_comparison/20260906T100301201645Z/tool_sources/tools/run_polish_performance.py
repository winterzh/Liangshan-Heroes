"""Serial, fresh-process Godot performance samples with source and run receipts.

Use --allow-short only to validate the harness; such samples cannot form a baseline.
No third-party Python dependencies. Godot comes from --godot, GODOT_PATH or
the ignored project-local godot.local.txt. Artifacts stay in .godot by default.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CASES = ("economy", "defense200", "zhu_contact", "gao_contact")
ERROR = re.compile(r"SCRIPT ERROR|^ERROR:|\bFAIL\b", re.M)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def write_json(path, data):
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))


def source_receipt():
    paths = []
    for directory in ("scripts", "scenes", "assets", "shaders", "resources", "data", "addons", "content", "scenarios"):
        paths.extend(p for p in (ROOT / directory).rglob("*") if p.is_file())
    paths += [ROOT / "project.godot", ROOT / "tools/polish_performance_probe.gd",
              ROOT / "tools/zhujiazhuang_rts_test.gd", Path(__file__).resolve()]
    paths += [p for p in ROOT.glob("icon.*") if p.is_file()]
    text_suffixes = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json", ".cfg",
                     ".import", ".uid", ".svg", ".txt", ".csv", ".godot", ".py", ".md"}
    rows = {}
    for path in sorted(set(paths)):
        raw = path.read_bytes()
        if path.suffix.lower() in text_suffixes:
            raw = raw.replace(b"\r\n", b"\n")
        rows[path.relative_to(ROOT).as_posix()] = sha(raw)
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    return {"git_head": head, "file_sha256": rows,
            "hash_policy": "text suffixes normalized CRLF to LF; binary resources hashed byte-for-byte",
            "combined_sha256": sha(json.dumps(rows, sort_keys=True).encode())}


def environment():
    env = os.environ.copy()
    # Derive literal production switches from the same source receipt, including
    # rendering, profiler, screenshot and content-update switches. Never log the
    # inherited environment or the removed values (which could contain secrets).
    exact = set()
    for path in (ROOT / "scripts").rglob("*.gd"):
        exact.update(re.findall(r'OS\.(?:get_environment|has_environment)\(\s*["\']([A-Z0-9_]+)["\']',
                                path.read_text(encoding="utf-8-sig")))
    prefixes = ("PERF_", "POLISH_", "DEF_", "AI_FRIENDLY", "RTS_TEST_", "YF_")
    for key in list(env):
        if key in exact or key.startswith(prefixes):
            env.pop(key)
    env["CAMPAIGN_QA"] = "1"
    return env, {key: env.get(key, "<unset>") for key in sorted(exact)}


def summarize(rows, args):
    groups = []
    for camera in args.camera:
        for case in args.cases:
            samples = [r for r in rows if r["scenario"] == case and r["camera_mode"] == camera]
            valid = [r for r in samples if r.get("integrity_passed") and r.get("sample_complete")
                     and r.get("exit_code") == 0 and not r.get("script_errors")
                     and r.get("source_unchanged") and r.get("quality_metadata_valid")
                     and r.get("effects_quality") == args.effects_quality]
            group = {"scenario": case, "camera_mode": camera, "samples": len(samples),
                     "effects_quality": args.effects_quality,
                     "valid_samples": len(valid), "required_samples": args.repeats,
                     "baseline_eligible": len(valid) >= 3 and len(valid) == args.repeats
                     and all(r.get("acceptance_eligible") for r in valid)}
            if valid:
                for key in ("fps", "p95_ms", "p99_ms", "simulated_seconds"):
                    group[key + "_samples"] = [r[key] for r in valid]
                    group[key + "_median"] = statistics.median(r[key] for r in valid)
                group["initial_deployment_matches"] = len({r["initial_deployment_sha256"] for r in valid}) == 1
                group["input_plan_matches"] = len({r["input_log_sha256"] for r in valid}) == 1
                group["baseline_eligible"] = (group["baseline_eligible"]
                                                and group["initial_deployment_matches"]
                                                and group["input_plan_matches"])
                group["end_counts"] = [r["sample_end"]["count"] for r in valid]
                group["end_phases"] = [r["sample_end"]["phase"] for r in valid]
            groups.append(group)
    return {"schema": 2, "label": args.label, "effects_quality": args.effects_quality, "groups": groups,
            "baseline_eligible": bool(groups) and all(g["baseline_eligible"] for g in groups),
            "note": "Same deployment and tick-input specification, statistical comparison. "
                    "Combat may diverge due to existing render-frame damage and audio global RNG. "
                    "No performance gate is waived and short preflights are never a baseline."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot")
    parser.add_argument("--cases", nargs="+", choices=CASES, default=list(CASES))
    parser.add_argument("--camera", nargs="+", choices=("fixed", "auto"), default=["fixed"])
    parser.add_argument("--effects-quality", choices=("standard", "reduced"), default="standard")
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--seconds", type=float, default=60.0)
    parser.add_argument("--allow-short", action="store_true")
    parser.add_argument("--label", default="baseline")
    parser.add_argument("--output", type=Path, default=Path(".godot/polish_performance"))
    args = parser.parse_args()
    if args.repeats < 1 or args.seconds < 1 or (args.seconds < 60 and not args.allow_short):
        parser.error("Use >=60 seconds for baselines; --allow-short is preflight-only.")
    if len(set(args.cases)) != len(args.cases) or len(set(args.camera)) != len(args.camera):
        parser.error("Duplicate cases or camera modes would hide missing repetitions.")
    if "auto" in args.camera and args.cases != ["defense200"]:
        parser.error("Auto-camera comparison uses --cases defense200; other fixtures have no fully managed heroes.")
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.label):
        parser.error("Label must contain only letters, digits, underscore, dot or hyphen.")
    exe = args.godot or os.environ.get("GODOT_PATH")
    if not exe and (ROOT / "godot.local.txt").is_file():
        exe = (ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip()
    if not exe or not Path(exe).is_file():
        parser.error("Provide --godot, GODOT_PATH or the ignored godot.local.txt.")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    base = args.output if args.output.is_absolute() else ROOT / args.output
    output = base / (args.label + "_" + stamp)
    output.mkdir(parents=True, exist_ok=False)
    source = source_receipt()
    controlled_env, environment_receipt = environment()
    write_json(output / "sources.json", source)
    write_json(output / "configuration.json", {"cases": args.cases, "camera": args.camera,
               "effects_quality": args.effects_quality,
               "repeats": args.repeats, "seconds": args.seconds, "allow_short": args.allow_short,
               "seed": 5088120, "warmup_ticks": 300, "label": args.label,
               "platform": platform.platform(), "processor": platform.processor(),
               "godot_executable_sha256": sha(Path(exe).read_bytes()),
               "controlled_production_environment": environment_receipt,
               "audio_policy": "production audio logic remains active; master muted"})
    print("OUTPUT " + str(output), flush=True)
    rows = []
    for repetition in range(1, args.repeats + 1):
        for camera in args.camera:
            for case in args.cases:
                if source_receipt()["combined_sha256"] != source["combined_sha256"]:
                    raise RuntimeError("Source changed during baseline; preserve results and start a new run.")
                name = f"{case}_{camera}_{repetition}"
                report_path = output / (name + ".json")
                log_path = output / (name + ".log")
                env = controlled_env.copy()
                env.update(POLISH_CASE=case, POLISH_CAMERA=camera, POLISH_SECONDS=str(args.seconds),
                           POLISH_OUT=str(report_path), POLISH_EFFECTS_QUALITY=args.effects_quality)
                command = [str(exe), "--path", str(ROOT), "--script", "res://tools/polish_performance_probe.gd"]
                start = time.monotonic()
                timed_out = False
                with log_path.open("wb") as log:
                    try:
                        result = subprocess.run(command, env=env, cwd=ROOT, stdout=log,
                                                stderr=subprocess.STDOUT, timeout=args.seconds + 180)
                        exit_code = result.returncode
                    except subprocess.TimeoutExpired:
                        timed_out = True
                        exit_code = -1
                console = log_path.read_text(encoding="utf-8", errors="replace")
                source_after = source_receipt()
                source_unchanged = source_after["combined_sha256"] == source["combined_sha256"]
                if not source_unchanged:
                    write_json(output / (name + "_changed_sources.json"), source_after)
                errors = [line for line in console.splitlines() if ERROR.search(line)]
                row = json.loads(report_path.read_text(encoding="utf-8")) if report_path.is_file() else {}
                quality_metadata_valid = (row.get("schema") == 2
                    and row.get("effects_quality_verified") is True
                    and row.get("effects_quality_violations") == 0
                    and all(row.get(key) == args.effects_quality for key in
                        ("effects_quality", "effects_quality_requested", "effects_quality_initial", "effects_quality_start", "effects_quality_end"))
                    and row.get("configured_settings", {}).get("effects_quality") == args.effects_quality)
                row.update(scenario=case, camera_mode=camera, repetition=repetition,
                           quality_metadata_valid=quality_metadata_valid,
                           exit_code=exit_code, process_seconds=time.monotonic()-start,
                           script_errors=errors, timed_out=timed_out, log=log_path.name,
                           source_unchanged=source_unchanged,
                           report=report_path.name)
                for key, output_key in (("initial_units", "initial_deployment_sha256"), ("inputs", "input_log_sha256")):
                    row[output_key] = sha(json.dumps(row.get(key), sort_keys=True).encode())
                compact = {key: row.get(key) for key in ("scenario", "camera_mode", "repetition", "exit_code",
                           "process_seconds", "script_errors", "timed_out", "log", "report",
                           "integrity_passed", "sample_complete", "acceptance_eligible", "fps", "p95_ms",
                           "source_unchanged",
                           "effects_quality", "effects_quality_verified", "effects_quality_violations", "quality_metadata_valid",
                           "p99_ms", "simulated_seconds", "sample_end", "initial_deployment_sha256",
                           "input_log_sha256")}
                rows.append(compact)
                write_json(output / "runs.json", rows)
                write_json(output / "summary.json", summarize(rows, args))
                print(json.dumps(compact, ensure_ascii=False), flush=True)
                if exit_code or errors or not row.get("integrity_passed") or not source_unchanged or not quality_metadata_valid:
                    raise RuntimeError("Invalid sample; inspect preserved log " + str(log_path))
    summary = summarize(rows, args)
    write_json(output / "summary.json", summary)
    print("SUMMARY " + json.dumps(summary, ensure_ascii=False), flush=True)
    return 0 if args.allow_short or summary["baseline_eligible"] else 1


if __name__ == "__main__":
    sys.exit(main())
