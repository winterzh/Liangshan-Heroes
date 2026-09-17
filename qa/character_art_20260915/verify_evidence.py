"""Read-only evidence verification, except the derived validation summary."""
from pathlib import Path
import hashlib
import json

QA = Path(__file__).resolve().parent
ROOT = QA.parents[1]
NATIVE = QA / "native/20260915_155056_7d7baaac"

def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    receipt = read(NATIVE / "receipt.json")
    assert receipt["complete"] is True
    assert all(step["passed"] for step in receipt["steps"])
    assert not receipt["source_changes"] and not receipt["private_source_changes"]
    assert receipt["lock_released"] and not receipt["engines_remaining"]
    for item in receipt["source_files"]:
        assert sha(ROOT / item["path"]) == item["sha256"], item["path"]
    for item in receipt["artifacts"]:
        assert sha(NATIVE / item["path"]) == item["sha256"], item["path"]
    assert sha(ROOT / "tools/art_character_direction4_qa.gd") == receipt["qa_sha256"]
    assert sha(ROOT / "tools/run_character_art_qa.py") == receipt["driver_sha256"]
    lineage = read(ROOT / "tools/contracts/guan_zhanzi_direction4_20260915/portrait_lineage.json")
    for item in lineage:
        assert sha(ROOT / item["repository_path"]) == item["sha256"]
        for path, expected in item["reference_hashes"].items():
            assert sha(ROOT / path) == expected, path
    routing = read(NATIVE / "routing/report.json")
    assert len(routing["checks"]) == 8 and all(c["passed"] for c in routing["checks"])
    result = {
        "passed": True,
        "receipt_sha256": sha(NATIVE / "receipt.json"),
        "frozen_source_files": len(receipt["source_files"]),
        "artifact_hashes": len(receipt["artifacts"]),
        "character_checks": receipt["character_results"][0]["checks"],
        "screenshots": receipt["character_results"][0]["screenshots"],
        "routing_checks": len(routing["checks"]),
        "portrait_lineage_entries": len(lineage),
        "inventory_totals": read(NATIVE / "inventory/inventory.json")["totals"],
        "scope": "Hash readback and assertions only; visual and gameplay limits are recorded separately in README.md."
    }
    (QA / "validation_summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    main()
