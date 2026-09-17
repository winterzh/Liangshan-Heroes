"""Read-only verification of the archived observer evidence; no engine/Steam."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    rows = manifest["files"]
    actual = {p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*") if p.is_file()}
    assert actual == set(rows) | {"manifest.json"}, "Archive inventory changed"
    for name, row in rows.items():
        data = (ROOT / name).read_bytes()
        assert len(data) == row["bytes"] and sha(data) == row["sha256"], name
        if row.get("transformation") == "exact_source_bytes":
            assert sha(data) == row["original_sha256"], "Source snapshot differs: " + name
    final = json.loads((ROOT / "validation_final/receipt.json").read_text(encoding="utf-8"))
    assert final["complete"] is True and final["lock_released"] is True
    assert final["vendor_replaced"] is False and final["live_steam_tested"] is False
    assert final["write_confirmation_tested"] is False
    for name, total in [("facade", 119), ("absent", 2), ("mock", 14)]:
        report = json.loads((ROOT / ("validation_final/" + name + "_report.json")).read_text(encoding="utf-8"))
        assert report == final["reports"][name] and report["passed"] is True
        assert len(report["checks"]) == total and all(row["passed"] is True for row in report["checks"])
        assert report["live_steam_tested"] is False and report["write_confirmation_tested"] is False
    for name, digest in final["sources"].items():
        data = (ROOT / ("sources/current/" + name + ".txt")).read_bytes()
        assert sha(data) == digest, "Final source mismatch: " + name
    failed = json.loads((ROOT / "validation_failed_0975ded7/receipt.json").read_text(encoding="utf-8"))
    assert failed["complete"] is False
    history = ROOT / "sources/history_0975ded7/scripts/steam_stats_observer.gd.txt"
    assert sha(history.read_bytes()) == failed["sources"]["scripts/steam_stats_observer.gd"]
    native = json.loads((ROOT / "native_final_f8fcccaf7d2d/receipt.json").read_text(encoding="utf-8"))
    assert native["complete"] is True
    assert native["reports"]["reader_test"]["checks"] == 61
    assert native["reports"]["observer_test"]["checks"] == 184
    build = json.loads((ROOT / "reader_build_58e3895e2199/receipt.json").read_text(encoding="utf-8"))
    assert build["complete"] is True and build["dll_sha256"] == final["reader_builder"]["dll_sha256"]
    assert rows["reader_build_58e3895e2199/receipt.json"]["original_sha256"] == final["reader_builder"]["receipt_sha256"]
    assert rows["native_final_f8fcccaf7d2d/receipt.json"]["original_sha256"] == final["native_tests"]["receipt_sha256"]
    assert all(row["exit_code"] == 0 for row in final["commands"])
    for row in final["commands"]:
        archived = "validation_final/" + row["name"] + ".log"
        assert rows[archived]["original_sha256"] == row["log_sha256"]
        text = (ROOT / archived).read_text(encoding="utf-8")
        assert not any(marker in text for marker in ["SCRIPT ERROR", "ERROR:", "warning C", "warning LNK"]), archived
    print(json.dumps({"passed": True, "archive_files": len(rows), "source_snapshots": len(final["sources"]) + 1, "facade": 119, "absent": 2, "mock": 14, "native_reader": 61, "native_observer": 184, "live_steam_tested": False, "write_confirmation_tested": False, "verification_only_no_tests_rerun": True}))


if __name__ == "__main__":
    main()
