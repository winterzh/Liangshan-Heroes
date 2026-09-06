"""Verify and archive an unchanged exported candidate after the Fog transfer guard.

The original failed builder receipt remains immutable. Run the existing independent
identity probe first; this performs no Godot, Steam, player writes, or Git commands.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "tools"))
from build_steam_candidate import package_archive
from contracts.run_content_identity_20260907.build_identity import verify_generated


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--probe-run", type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    probe_run = args.probe_run.resolve()
    assert candidate.is_relative_to(ROOT / ".godot/steam_candidates")
    assert probe_run.is_relative_to(ROOT / ".godot/morning_identity_recovery_20260907/runs")
    output = candidate / "independent_recovery"
    assert not output.exists(), "Never overwrite a recovery receipt"
    original = read(candidate / "receipt.json")
    assert not original["complete"]
    native = read(ROOT / original["qa_run"] / "receipt.json")
    assert native["complete"] and native["checks"] == 176
    assert sha(ROOT / original["qa_run"] / "receipt.json") == original["qa_receipt_sha256"]
    assert original["verification"]["complete"] and original["verification"]["checks"] == 65
    assert all(step["exit_code"] == 0 for step in original["steps"])
    source_probe = read(candidate / "source_identity_probe/process_receipt.json")
    assert source_probe["complete"] and source_probe["child_exit_confirmed"]
    assert source_probe["exit_code"] == 0 and source_probe["check_count"] == 10
    rejected = read(candidate / "content_identity_probe/process_receipt.json")
    assert not rejected["child_started"] and rejected["error"] == "RuntimeError: Production source changed"
    recovery = read(probe_run / "receipt.json")
    assert all(recovery[key] for key in ["complete", "lock_released", "source_unchanged", "player_unchanged"])
    pack_probe = read(probe_run / "probe/process_receipt.json")
    assert pack_probe["complete"] and pack_probe["child_exit_confirmed"]
    assert pack_probe["exit_code"] == 0 and pack_probe["check_count"] == 10
    assert pack_probe["source_mode"] is False
    exe = candidate / "windows/LiangshanHeroes.exe"
    assert sha(exe) == pack_probe["pack_sha256"] == rejected["pack_sha256"]
    for record in original["source_files"]:
        assert sha(ROOT / record["path"]) == record["sha256"], record["path"]
        if not record["path"].endswith(".import"):
            assert sha(candidate / "project" / record["path"]) == record["sha256"], record["path"]
    verify_generated(candidate / "project", read(candidate / "content_identity_generation.json"))
    before = read(candidate / "identity_sources_before.json")
    after = read(probe_run / "source_after.json")
    prior_files, current_files = before["raw_file_sha256"], after["raw_file_sha256"]
    assert set(current_files) - set(prior_files) == {"scripts/run_fog_state.gd"}
    assert all(current_files.get(path) == digest for path, digest in prior_files.items())
    assert current_files["scripts/run_fog_state.gd"] == "caef97f9a10ca7dfaa39bd51a997c1bce8eb5575e7210a4a085ccfba57567d30"
    assert before["directories"] == after["directories"] and before["root_presence"] == after["root_presence"]
    assert read(candidate / "identity_players_before.json") == read(probe_run / "players_after.json")
    assert not (candidate / "project/scripts/run_fog_state.gd").exists()
    for name in ["steam_api64.dll", "libgodotsteam.windows.template_release.x86_64.dll"]:
        assert sha(candidate / "windows" / name) == sha(ROOT / "vendor/godotsteam/win64" / name)
    output.mkdir()
    archive = package_archive(output, candidate / "windows")
    receipt = {
        "complete": True,
        "kind": "independent_validation_of_unchanged_frozen_candidate",
        "original_builder_complete": False,
        "original_builder_receipt_sha256": sha(candidate / "receipt.json"),
        "original_source_head": original["source_head"],
        "candidate_run": candidate.relative_to(ROOT).as_posix(),
        "probe_run": probe_run.relative_to(ROOT).as_posix(),
        "native_checks": 176,
        "package_checks": 65,
        "source_identity_checks": 10,
        "pck_identity_checks": 10,
        "original_export_unchanged": True,
        "original_source_records_unchanged": True,
        "player_files_unchanged": True,
        "only_added_production_source": "scripts/run_fog_state.gd",
        "fog_in_candidate": False,
        "archive": archive,
        "uploaded": False,
        "live_steam_tested": False,
    }
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"complete": True, "output": str(output), "zip_sha256": archive["sha256"], "bytes": archive["bytes"]}))


if __name__ == "__main__":
    main()
