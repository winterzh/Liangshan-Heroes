"""Synthetic/static checks only. Never starts or queries Godot."""
import ast
import copy
import hashlib
import json
from pathlib import Path
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
RUNNER = HERE.parent / "run_settings_qa.py"
ns = {"__file__": str(RUNNER), "__name__": "steam_settings_static_review"}
raw = RUNNER.read_bytes()
exec(compile(raw, str(RUNNER), "exec"), ns)
checks = []


def check(label, ok):
    if not ok:
        raise AssertionError(label)
    checks.append({"label": label, "passed": True})


def rejected(label, callback):
    try:
        callback()
    except RuntimeError:
        check(label, True)
    else:
        raise AssertionError("Not rejected: " + label)


root = ns["ROOT"]
build_path = root / ".godot/steam_update_20260907/build_receipt.json"
build = ns["read_json"](build_path)
args = SimpleNamespace(godot=build["godot"], exe=build["executable"], build_receipt=None,
                       source_commit=ns["DEFAULT_COMMIT"], run=False, out=None, timeout=180)
tools = ns["load_tools"]()
check("pinned helper imports are read-only", set(tools) == {"child", "safe", "environment"})
calls = []


def tripwire(*unused, **kw):
    calls.append(True)
    raise AssertionError("Runtime primitive reached in static preflight")


for key in ("run_child", "run", "load_contract", "full_preflight", "planned_source", "profile_environment"):
    tools["child"][key] = tripwire
for key in ("require_exclusive_godot", "resolve_godot"):
    tools["safe"][key] = tripwire
tools["environment"]["environment"] = tripwire
real_sha = ns["file_sha"]


def bounded_sha(path):
    check("no package/engine/resource hash: " + Path(path).name,
          Path(path).suffix.lower() not in (".exe", ".png", ".tres"))
    return real_sha(path)


ns["file_sha"] = bounded_sha
plan = ns["preflight"](args, tools)
check("actual current package readonly preflight ready", plan["inputs_ready"] is True)
check("default preflight starts/queries no process", calls == [] and plan["godot_run"] is False)
future = copy.copy(args)
future.exe = str(HERE / "not_generated/windows/LiangshanHeroes.exe")
check("missing future package is honest pending preflight", ns["preflight"](future, tools)["inputs_ready"] is False)
console = copy.copy(args)
console.godot = str(HERE / "Godot_console.exe")
rejected("console wrapper rejected", lambda: ns["preflight"](console, tools))
wrong_commit = copy.copy(args)
wrong_commit.source_commit = "0" * 40
rejected("old build/source commit rejected", lambda: ns["preflight"](wrong_commit, tools))
ns["file_sha"] = real_sha

user = HERE / "synthetic_profile/appdata/Godot/app_userdata/qa"
report = {"schema": 1, "mode": "write", "complete": True, "passed": True, "failures": [],
          "checks": [{"label": "synthetic check", "passed": True}], "check_count": 1,
          "pid": 123, "actual_user_dir": str(user), "executable_sha256": build["sha256"],
          "source_commit": ns["DEFAULT_COMMIT"], "qa_script_path": str(ns["QA"]),
          "qa_script_raw_sha256": ns["QA_SHA"], "resolution": [1280, 720],
          "rendering_driver": "vulkan", "rendering_method": "forward_plus"}


def validate(value):
    return ns["validate_report"](value, "write", {"child_pid": 123}, user, build["sha256"], ns["DEFAULT_COMMIT"], ns["QA_SHA"])


check("synthetic all-pass report accepted", validate(report) == 1)
mutants = {"schema": 2, "mode": "read", "complete": False, "passed": False, "failures": ["bad"],
           "checks": [], "check_count": 2, "pid": 124, "actual_user_dir": str(HERE),
           "executable_sha256": "0" * 64, "source_commit": "0" * 40,
           "qa_script_path": str(HERE / "another.gd"), "qa_script_raw_sha256": "0" * 64,
           "resolution": [1440, 900], "rendering_driver": "dummy", "rendering_method": "gl_compatibility"}
for key, value in mutants.items():
    mutant = copy.deepcopy(report)
    mutant[key] = value
    rejected("reject report " + key, lambda m=mutant: validate(m))
failed = copy.deepcopy(report)
failed["checks"][0]["passed"] = False
rejected("reject failed nested check", lambda: validate(failed))
boolean_pid = copy.deepcopy(report)
boolean_pid["pid"] = True
rejected("reject boolean PID", lambda: validate(boolean_pid))

tree = ast.parse(raw)
run_node = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "run")
segment = ast.get_source_segment(raw.decode("utf8"), run_node)
check("ordered write/read loop", 'for mode in ("write", "read"):' in segment)
check("exact main-pack plus absolute external script", '"--main-pack", str(pack)' in segment and '"--script", str(QA)' in segment)
check("no source-project path or import command", '"--path"' not in segment and '"--editor"' not in segment and '"--import"' not in segment)
check("shared profile outside modes", segment.index('profile = output / "private_profile"') < segment.index('for mode in ("write", "read")'))
check("all profile variables redirected", all(x in segment for x in ('APPDATA=', 'LOCALAPPDATA=', 'TEMP=', 'TMP=')))
check("each attempted child receipt checked before lock unlink", segment.index('process.get("child_exit_confirmed") is True') < segment.index('LOCK.unlink()'))
check("player and source guards precede release", segment.index('guard()\n            pack_after') < segment.index('LOCK.unlink()'))
check("actual package/engine final hash verified", 'pack_after == pack_before and engine_after == engine_before' in segment)
check("private settings cross-process bytes checked", 'first["settings_file_after"] == second["settings_file_before"]' in segment)
check("old helper PID wording retained as provenance", 'borrowed_helper_pid_evidence' in segment and 'qa_pid_match_verified' in segment)
check("no engine query or subprocess start used in this review", calls == [])

receipt = {"schema": 1, "kind": "static_and_synthetic_only_not_engine_test", "passed": True,
           "check_count": len(checks), "checks": checks, "godot_run": False, "engine_or_package_hashed": False,
           "production_mutated": False, "private_project_mutated": False,
           "runner_raw_sha256": hashlib.sha256(raw).hexdigest(), "qa_raw_sha256": real_sha(ns["QA"]),
           "static_checks_raw_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), "preflight": plan}
(HERE / "receipt.json").write_bytes((json.dumps(receipt, ensure_ascii=False, indent=2) + "\n").encode("utf8"))
print(json.dumps({"passed": True, "check_count": len(checks), "runner_raw_sha256": receipt["runner_raw_sha256"],
                  "godot_run": False}, ensure_ascii=True))
