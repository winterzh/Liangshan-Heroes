"""Small text/source-pin checks only. Never imports or starts Godot."""
import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
HEAD = "06c2c69601bc6fb6e1172ab5d195a3ef5c143a3a"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--freeze", action="store_true", help="Create initial pins; refuses replacement")
    args = parser.parse_args()
    driver = (BASE / "driver.gd").read_text(encoding="utf-8")
    helper = (BASE / "candidate_helper.gd").read_text(encoding="utf-8")
    probe = (ROOT / "tools/polish_performance_probe.gd").read_text(encoding="utf-8")
    checks = []

    def need(value, label):
        checks.append({"label": label, "passed": bool(value)})
        if not value:
            raise RuntimeError(label)

    ast.parse(Path(__file__).read_text(encoding="utf-8"))
    need(subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip() == HEAD,
         "current agreed Git HEAD")
    need(driver.startswith('extends "res://tools/polish_performance_probe.gd"'), "inherits current M1")
    need(re.findall(r"^func (\w+)\(", driver, re.M) == ["_animation_source_hashes", "_initialize", "_new_battle", "_write_animation_report", "_dispose"],
         "no original run/tick/fixture/warmup replacement")
    need(driver.count("await super._new_battle()") == 1, "original fixture runs exactly once")
    need("preload(" not in driver and driver.index('animation_candidate = load(') < driver.index("await super._new_battle()"),
         "same helper compiles after Autoload readiness and before fixture in both modes")
    need(driver.index("await super._new_battle()") < driver.index("await animation_candidate.run("), "preparation follows complete disabled fixture")
    need(probe.index("var b = await _new_battle()") < probe.index("var tick_driver := TickDriver.new()") < probe.index("while physics_tick < WARMUP_TICKS"),
         "inherited tick driver and 300-step warmup start later")
    need("const WARMUP_TICKS := 300" in probe and "seed(5088120)" in probe, "original warmup/seed present")
    for name, value in [("POLISH_CASE", "defense200"), ("POLISH_CAMERA", "fixed"), ("POLISH_SECONDS", "10"), ("POLISH_EFFECTS_QUALITY", "standard")]:
        need('OS.set_environment("%s","%s")' % (name, value) in driver, "fixed entry " + name)
    executable = "\n".join(line.split("#", 1)[0] for line in (driver + "\n" + helper).splitlines())
    need(re.search(r"\b(seed|randomize|randi|randf|randf_range|randi_range|spawn_unit|order_amove|queue_free|set_instance_id)\s*\(", executable) is None,
         "no added RNG/spawn/order/deletion/identity override calls")
    need(".new(" not in executable and "add_child(" not in executable, "no helper instance or fixture Node allocation")
    need(executable.count("art.unit_anim_frames(") == 1 and "await RenderingServer.frame_post_draw" in executable,
         "one original Art API call site and presented-frame yield")
    need('if mode == "current_units":' in helper and 'mode=="none"' in helper, "same-source none/current_units modes")
    need('const STATES := ["attack","walk"]' in helper and 'const MAX_REQUESTS := 96' in helper,
         "finite common-action plan")
    need("node is Unit and node.can_process()" in helper and '"existing_unit_ids_before"' in helper and '"observed_state_equal"' in helper,
         "explicit frozen descendant and state/identity observations")
    need("private_root.to_lower().begins_with(boundary.to_lower()+\"/\")" in driver and 'output.get_file() != "preparation.json"' in driver,
         "driver requires experiment-private profile and separate sidecar name")
    need('"source_sha256_before"' in driver and '"source_sha256_after_measurement"' in driver,
         "runtime source observations before and after sample")
    need('"future_object_ids_may_differ":true' in helper and '"acceptance_eligible"] = false' in driver,
         "future identity uncertainty and preflight-only qualification explicit")
    paths = re.findall(r'"res://([^"\n]+)"', driver[driver.index("const SOURCE_PATHS"):driver.index("var animation_load_mode")])
    rows = {}
    for relative in paths:
        raw = (ROOT / relative).read_bytes()
        lf = raw.replace(b"\r\n", b"\n")
        rows[relative] = {"bytes": len(raw), "raw_sha256": digest(raw), "lf_sha256": digest(lf)}
        if not relative.startswith("scratchpad/"):
            old = subprocess.check_output(["git", "show", HEAD + ":" + relative], cwd=ROOT)
            need(lf == old.replace(b"\r\n", b"\n"), "source matches frozen HEAD: " + relative)
    for leaf in ["static_checks.py", "README.md", ".gdignore"]:
        raw = (BASE / leaf).read_bytes()
        rows[(BASE / leaf).relative_to(ROOT).as_posix()] = {"bytes": len(raw), "raw_sha256": digest(raw), "lf_sha256": digest(raw.replace(b"\r\n", b"\n"))}
    pins = {"schema": 1, "git_head": HEAD, "files": rows,
            "scope": "Critical source and candidate pins only, not the full asset/source manifest; parent runner must record the full production receipt.",
            "engine_executed": False, "status": "frozen_for_first_2x10s_entry"}
    target = BASE / "pins.json"
    if args.freeze:
        need(not target.exists(), "initial pin file absent")
        target.write_bytes((json.dumps(pins, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    else:
        need(json.loads(target.read_text(encoding="utf-8")) == pins, "all frozen bytes unchanged")
    report = {"status": "PASS", "checks": checks, "check_count": len(checks), "pins_sha256": digest(target.read_bytes()),
              "engine_executed": False, "limit": "Text/AST/source checks do not establish GDScript compile or runtime correctness."}
    (BASE / "static_check_receipt.json").write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print(json.dumps({"status": "PASS", "checks": len(checks), "pins_sha256": report["pins_sha256"]}))


if __name__ == "__main__":
    main()
