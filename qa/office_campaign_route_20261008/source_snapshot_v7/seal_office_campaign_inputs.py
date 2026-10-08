"""Seal the already verified full runtime bridge with exact QA/native-helper/fixture source pins."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa/zhu_wounded_20261005"
PROPOSAL = QA / "proposals/daming_safe_retreat_v25"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preparation", type=Path, required=True)
    parser.add_argument("--runtime-bridge", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--route-bundle", type=Path)
    args = parser.parse_args()
    preparation = json.loads(args.preparation.read_text(encoding="utf-8"))
    record = json.loads(args.runtime_bridge.read_text(encoding="utf-8"))
    assert record["schema"] == "office_complete_candidate_source_bridge_v1" and record["complete"]
    assert record["candidate_root"] == preparation["candidate_root"]
    assert not args.output.exists(), "New immutable input seal required"
    candidate = Path(record["candidate_root"])
    paths = {Path(__file__), ROOT / "tools/run_office_campaign_restore_qa.py", args.preparation, args.runtime_bridge,
             candidate / "tools/run_steam_integration_qa.py", candidate / "tools/owned_slot_retry_qa.gd",
             ROOT / "tools/run_steam_integration_qa.py", ROOT / "tools/owned_slot_retry_qa.gd",
             QA / "native_ownership_json_fixtures_v24q.json", QA / "harness/native_ownership_json_boundary_v24q1.gd",
             QA / "harness/daming_admit_cross_process_v24s.gd", QA / "harness/daming_admit_cross_process_v24s.tscn",
             Path(preparation["json_scene"]["current_path"])}
    paths.update(Path(row["current_path"]) for row in preparation["retained_full_review_source_bridge"])
    paths.update(Path(path) for path in preparation["json_fixture_paths"].values())
    for row in preparation["interfaces"].values():
        paths.add(Path(row["source"]))
        paths.update(Path(row[key]["current_path"]) for key in ["harness", "scene"])
    paths.update(PROPOSAL / name for name in ["run_daming_safe_retreat_v25s_r2b2_full.py",
                                             "daming_safe_retreat_cross_process_v25.gd",
                                             "daming_safe_retreat_cross_process_v25.tscn",
                                             "ADAPTER_BUNDLE_MATRIX_V25S_R2B2.json", "RUNNER_REVIEW_V25S1_FULL_FX.json"])
    if args.route_bundle is not None:
        bundle_path = args.route_bundle.resolve(strict=True)
        bundle = json.loads(bundle_path.read_text(encoding="utf-8"))
        assert bundle["schema"] == "office_defended_retreat_route_bundle_v26" and bundle["complete_source_preparation"]
        assert set(bundle["replacements"]) == {"retreat_runner", "retreat_scene", "retreat_route"}
        paths.add(bundle_path)
        for row in bundle["replacements"].values():
            path = Path(row["path"]).resolve(strict=True)
            assert path.is_relative_to(ROOT / "qa/office_campaign_route_20261008")
            assert path.stat().st_size == row["bytes"] and sha(path) == row["sha256"]
            paths.add(path)
        record["route_bundle_sha256"] = sha(bundle_path)
    assert (candidate / "tools/run_steam_integration_qa.py").read_bytes() == (ROOT / "tools/run_steam_integration_qa.py").read_bytes()
    assert (candidate / "tools/owned_slot_retry_qa.gd").read_bytes().replace(b"\r\n", b"\n") == (ROOT / "tools/owned_slot_retry_qa.gd").read_bytes().replace(b"\r\n", b"\n")
    record.update(schema="office_complete_candidate_inputs_v2", runtime_bridge_sha256=sha(args.runtime_bridge),
                  preparation_sha256=sha(args.preparation), qa_input_pins=[{"path": str(path), "bytes": path.stat().st_size,
                                                                          "sha256": sha(path)} for path in sorted(paths)],
                  scope="Complete raw runtime plus actual helper, original fixed QA and all eleven source fixtures. No runtime execution or static independent approval is supplied by this seal.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"complete": True, "runtime_files": record["candidate_identity"]["file_count"],
                      "qa_input_pins": len(paths), "output": str(args.output), "sha256": sha(args.output), "native_started": False}))


if __name__ == "__main__":
    main()
