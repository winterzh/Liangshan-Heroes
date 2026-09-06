"""Failure-injection tests on synthetic files beneath this directory only.

Does not invoke Godot, Git, process enumeration, or the real production paths.
Fixtures/receipts remain available for inspection instead of recursive cleanup.
"""
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent


def main():
    path = HERE / "prepare_and_run.py"
    module = {"__file__": str(path), "__name__": "physics_step_synthetic_recovery"}
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module)
    originals = {"scripts/battle.gd": b"ORIGINAL BATTLE\r\n", "scripts/unit.gd": b"ORIGINAL UNIT\n"}
    instrumented = {"scripts/battle.gd": b"INSTRUMENTED BATTLE\r\n", "scripts/unit.gd": b"INSTRUMENTED UNIT\n"}
    checks = []
    def check(value, label):
        if not value: raise RuntimeError(label)
        checks.append(label)
    for case in ("partial_apply", "damaged_disk_backup", "foreign_unit", "unconfirmed_child", "interrupted_second_restore"):
        root = (HERE / "selftest_fixtures" / case / "root").resolve()
        output = root.parent / "run"
        check(HERE.resolve() in root.parents, case + " fixture target stays inside draft")
        (root / "scripts").mkdir(parents=True, exist_ok=True)
        (root / ".godot").mkdir(exist_ok=True)
        output.mkdir(exist_ok=True)
        lock = root / ".godot/redraw_rejection_source.lock"
        lock.write_text(str(output) + "\n", encoding="utf-8")
        module["ROOT"] = root
        module["LOCK"] = lock
        for name in module["OWNED"]:
            (root / name).write_bytes(instrumented[name])
            (output / (Path(name).stem + "_original.bin")).write_bytes(originals[name])
        if case == "partial_apply": (root / "scripts/unit.gd").write_bytes(originals["scripts/unit.gd"])
        if case == "damaged_disk_backup": (output / "unit_original.bin").write_bytes(b"CORRUPT DISK BACKUP")
        if case == "foreign_unit": (root / "scripts/unit.gd").write_bytes(b"FOREIGN EDIT")
        calls = [0]
        def exclusive():
            calls[0] += 1
            if case == "unconfirmed_child" or case == "interrupted_second_restore" and calls[0] >= 3:
                raise RuntimeError("SYNTHETIC unconfirmed Godot child or interrupted guard")
        receipt = {"synthetic_only": True, "production_mutated": False, "performance_claim": False}
        restored = module["restore_owned"](originals, instrumented, output, {"require_exclusive_godot": exclusive}, receipt)
        battle = (root / "scripts/battle.gd").read_bytes()
        unit = (root / "scripts/unit.gd").read_bytes()
        if case in ("partial_apply", "damaged_disk_backup"):
            check(restored and not lock.exists(), case + " complete known originals permit lock removal")
            check(battle == originals["scripts/battle.gd"] and unit == originals["scripts/unit.gd"], case + " restores exact original bytes")
            if case == "damaged_disk_backup":
                check(not receipt["restoration_files"]["scripts/unit.gd"]["backup_verified_final"], "damaged disk backup is reported while pinned memory bytes restore")
        elif case == "foreign_unit":
            check(not restored and lock.exists() and unit == b"FOREIGN EDIT", "foreign edit is preserved and lock retained")
            check(battle == originals["scripts/battle.gd"] and (output / "unit_conflicting_current.bin").read_bytes() == b"FOREIGN EDIT", "known owned source restores while conflict copy remains")
        elif case == "unconfirmed_child":
            check(not restored and lock.exists(), "unconfirmed child prevents restoration and keeps lock")
            check(battle == instrumented["scripts/battle.gd"] and unit == instrumented["scripts/unit.gd"], "no source replacement before confirmed child exit")
        else:
            check(not restored and lock.exists(), "interrupted second restore keeps lock")
            check(unit == originals["scripts/unit.gd"] and battle == instrumented["scripts/battle.gd"], "partial restoration is explicit without overwriting remaining source")
    result = {"checks": len(checks), "passed": checks, "synthetic_only": True, "godot_run": False,
              "git_run": False, "production_mutated": False, "os_process_lifecycle_exercised": False,
              "scope": "real atomic file replacement on bounded synthetic fixtures; injected exclusive guard failures"}
    (HERE / "recovery_checks_receipt.json").write_bytes((json.dumps(result, indent=2) + "\n").encode())
    print(json.dumps({"checks": len(checks), "synthetic_only": True, "production_mutated": False}))


if __name__ == "__main__":
    main()
