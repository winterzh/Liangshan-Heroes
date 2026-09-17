from pathlib import Path
import ast
import hashlib
import json
import sys
import run_native

HERE = Path(__file__).resolve().parent
ROOT = run_native.ROOT
assert not (HERE / "freeze.json").exists(), "Never rewrite frozen evidence"
sys.path.insert(0, str(ROOT / "scratchpad/stabilization_identity_20260907/parser_runtime"))
from gdtoolkit.parser import parser

rows = []
for name in run_native.FILES:
    parser.parse((ROOT / name).read_text(encoding="utf-8-sig"))
    rows.append({"file": name, "grammar": True})
ast.parse((HERE / "run_native.py").read_text(encoding="utf-8"))
exe = Path((ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip())
freeze = {"inputs": {name: run_native.sha(ROOT / name) for name in run_native.FILES}, "runner_sha256": run_native.sha(HERE / "run_native.py"), "godot_sha256": run_native.sha(exe)}
run_native.write(HERE / "preparation.json", {"checks": rows, "native_run": False})
run_native.write(HERE / "freeze.json", freeze)
print(json.dumps({"freeze_sha256": run_native.sha(HERE / "freeze.json"), "files": len(rows), "crash_cases": len(run_native.CRASHES)}))
