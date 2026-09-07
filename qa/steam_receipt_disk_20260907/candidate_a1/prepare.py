"""Read-only grammar/contract checks, then create an immutable first freeze.

This is fixture generation, never production mutation. No Godot is launched.
After freeze exists, fixes require a new candidate directory.
"""
from pathlib import Path
import ast
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    assert not (HERE / "freeze.json").exists(), "Frozen candidate must not change"
    sys.path.insert(0, str(ROOT / "scratchpad/stabilization_identity_20260907/parser_runtime"))
    from gdtoolkit.parser import parser
    import run_matrix
    results = []
    for name in run_matrix.CANDIDATES:
        text = (HERE / name).read_text(encoding="utf-8")
        parser.parse(text)
        results.append({"file": name, "grammar": True, "sha256": sha(HERE / name)})
    for name in ("prepare.py", "run_matrix.py"):
        ast.parse((HERE / name).read_text(encoding="utf-8"))
        results.append({"file": name, "python_syntax": True, "sha256": sha(HERE / name)})
    host = (HERE / "receipt_host.gd").read_text(encoding="utf-8")
    critical = host.split("func transaction(", 1)[1].split("func publish(", 1)[0]
    assert not any(token in critical for token in ("await ", "emit_signal", ".emit(", "Callable", "sdk.", ".call("))
    assert critical.index("disk.acquire()") < critical.index("model.prepare_create")
    assert critical.index("disk.commit_locked") < critical.index("model.commit")
    assert host.index('transaction("dispatch", [token])') < host.index("model.take_sdk_targets") < host.index("sdk.set_stat")
    results.append({"fixed_non_yielding_host_boundary": True, "semantic_runtime_tested": False})
    frozen_names = run_matrix.CANDIDATES + ["run_matrix.py", "prepare.py", "README.md", "FAULT_MATRIX.md"]
    inputs = {name: sha(HERE / name) for name in frozen_names}
    exe = Path((ROOT / "godot.local.txt").read_text(encoding="utf-8-sig").strip())
    freeze = {"source_reference_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "head_policy": "Each run pins actual starting HEAD and requires it unchanged throughout; dependencies below must match exactly",
              "godot_sha256": sha(exe), "inputs": inputs,
              "dependencies": {name: sha(ROOT / name) for name in run_matrix.DEPENDENCIES.values()}}
    (HERE / "preparation.json").write_text(json.dumps({"checks": results, "native_run": False}, indent=2) + "\n", encoding="utf-8")
    (HERE / "freeze.json").write_text(json.dumps(freeze, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"freeze_sha256": sha(HERE / "freeze.json"), "checks": results, "crash_cases": len(run_matrix.CRASHES)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
