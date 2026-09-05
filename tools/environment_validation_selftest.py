"""Isolated failure-injection tests; never modify repository production assets."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from environment_validation_common import ROOT, contained_path, report_target, write_report


def main() -> int:
    checks = []
    temporary_root = ROOT / ".godot/environment_validation"
    temporary_root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="isolated_", dir=temporary_root) as directory:
        fixture = Path(directory).resolve()
        fixture.relative_to(temporary_root.resolve())
        shutil.copytree(ROOT / "scripts", fixture / "scripts")
        shutil.copytree(ROOT / "assets/campaign/environment", fixture / "assets/campaign/environment")
        (fixture / "tools").mkdir()
        for source in (ROOT / "tools").glob("*.py"):
            shutil.copyfile(source, fixture / "tools" / source.name)
        for relative in ("tools/environment_production_mapping.template.json", "tools/contracts/environment/inventory_20260906.json"):
            target = fixture / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        field_sources = Path("tools/contracts/environment/field_20260906")
        shutil.copytree(ROOT / field_sources, fixture / field_sources)

        def cli(tool: str, expected: int, *args: str) -> dict:
            # Deliberately run from a directory other than the fixture root.
            process = subprocess.run([sys.executable, "-X", "utf8", "-B", str(fixture / "tools" / tool), *args],
                                     cwd=fixture.parent, capture_output=True, text=True, encoding="utf-8")
            if process.returncode != expected:
                details = ""
                try:
                    emitted = json.loads(process.stdout)
                    failure_report = json.loads(Path(emitted["output"]).read_text(encoding="utf-8"))
                    details = str([c for c in failure_report["checks"] if not c["passed"]])
                    write_report(ROOT / ".godot/environment_validation/last_failed_fixture.json", failure_report)
                except (ValueError, KeyError, OSError):
                    pass
                raise AssertionError(f"{tool}: expected exit {expected}, got {process.returncode}: {process.stdout} {process.stderr} {details}")
            if "Traceback" in process.stderr:
                raise AssertionError(process.stderr)
            return json.loads(process.stdout or process.stderr)

        def audit(expected: int) -> dict:
            cli("environment_art_audit.py", expected)
            return json.loads((fixture / ".godot/environment_validation/audit.json").read_text(encoding="utf-8"))

        def changed_file(relative: str, payload: bytes, expected: int, code: str):
            path = fixture / relative
            original = path.read_bytes()
            try:
                path.write_bytes(payload)
                report = audit(expected)
                assert any(e["code"] == code for e in report["errors"]), report
            finally:
                path.write_bytes(original)

        route = cli("campaign_environment_art_static_contract.py", 0)
        assert route["basis_kind"] == "retained_production_mapping" and route["consumer_ready_total"] == 69
        checks.append("copied_checkout_without_git_or_office_directory_runs_from_other_cwd")
        report = audit(1)
        assert report["routes_passed"] and report["production_integrity_passed"] and report["counts"]["verified_production_hashes"] == 37
        assert not report["passed"] and not report["provenance_complete"] and report["counts"]["missing_production"] == 32
        assert len(report["production"]) == 69 and len(report["gaps"]) == 249
        checks.append("route_pass_and_37_hashes_do_not_hide_32_missing_outputs_or_source_gaps")
        from environment_art_audit import reviewed_entries
        historical = json.loads((fixture / "tools/contracts/environment/inventory_20260906.json").read_text(encoding="utf-8"))
        current = reviewed_entries(fixture, historical)
        assert [e for e in current if e["output_id"] != "surface_field"] == [e for e in historical["entries"] if e["output_id"] != "surface_field"]
        field_result = next(e for e in report["production"] if e["output_id"] == "surface_field")
        assert field_result["production_status"] == "matches_reviewed_addition" and field_result["source_status"] == "matches_reviewed_source_records"
        checks.append("one_reviewed_addition_preserves_all_other_68_historical_entries")
        reviewed = fixture / field_sources / "review.json"
        reviewed_bytes = reviewed.read_bytes()
        try:
            reviewed.write_bytes(reviewed_bytes + b"\n")
            assert "field review SHA256 mismatch" in cli("environment_art_audit.py", 2)["error"]
            checks.append("field_review_digest_is_independently_pinned")
            reviewed.unlink()
            assert cli("environment_art_audit.py", 2)["passed"] is False
            checks.append("missing_field_review_cannot_implicitly_approve_production")
        finally:
            reviewed.write_bytes(reviewed_bytes)
        for filename in ("original.png", "prompt.txt", "intake.json"):
            relative = (field_sources / filename).as_posix()
            original = (fixture / relative).read_bytes()
            changed_file(relative, original + b"drift", 2, "source_sha256_mismatch")
            checks.append("field_" + filename + "_byte_drift_rejected")
            try:
                (fixture / relative).unlink()
                missing = audit(1)
                assert any(g["code"] == "missing_source_file" and g["path"] == relative for g in missing["gaps"])
                assert next(e for e in missing["production"] if e["output_id"] == "surface_field")["source_status"] == "incomplete"
                checks.append("field_" + filename + "_missing_source_not_marked_complete")
            finally:
                (fixture / relative).write_bytes(original)
        mapped = fixture / "tools/environment_production_mapping.template.json"
        original_mapping = mapped.read_bytes()
        try:
            mapped.unlink()
            assert cli("campaign_environment_art_static_contract.py", 2)["status"] == "invalid_or_missing_input"
            checks.append("missing_mapping_is_structured_failure")
            mapped.write_bytes(b"{broken-json")
            assert cli("campaign_environment_art_static_contract.py", 2)["passed"] is False
            checks.append("malformed_mapping_is_structured_failure")
            mapped.write_bytes(original_mapping + b"\n")
            assert "SHA-bound" in cli("campaign_environment_art_static_contract.py", 2)["error"]
            checks.append("mapping_digest_cannot_be_silently_rebaselined")
        finally:
            mapped.write_bytes(original_mapping)
        inventory = fixture / "tools/contracts/environment/inventory_20260906.json"
        before = inventory.read_bytes()
        try:
            inventory.write_bytes(before + b"\n")
            assert "inventory SHA256 mismatch" in cli("environment_art_audit.py", 2)["error"]
            checks.append("production_inventory_digest_is_independently_pinned")
        finally:
            inventory.write_bytes(before)
        router = fixture / "scripts/campaign_environment_art.gd"
        before = router.read_bytes()
        assert b'"level8"' in before
        changed_file("scripts/campaign_environment_art.gd", before.replace(b'"level8"', b'"level2"', 1), 2, "route_contract_failed")
        checks.append("wrong_level_scope_fails_against_retained_mapping")
        changed_file("scripts/campaign_environment_art.gd", before.replace(b"cuiyun_tower_default.png", b"wrong.png", 1), 2, "route_contract_failed")
        checks.append("wrong_runtime_output_path_is_rejected")
        changed_file("scripts/campaign_environment_art.gd", before.replace(b'"signal":', b'"wrong_state":', 1), 2, "route_contract_failed")
        checks.append("wrong_runtime_state_is_rejected")
        image_path = "assets/campaign/environment/level5/zhongyi_hall.png"
        original_png = (fixture / image_path).read_bytes()
        changed_file(image_path, original_png + b"changed", 2, "production_sha256_mismatch")
        checks.append("production_png_byte_drift_is_rejected")
        try:
            (fixture / image_path).unlink()
            assert any(e["code"] == "tracked_production_deleted" for e in audit(2)["errors"])
            checks.append("deletion_of_previously_tracked_png_is_an_error")
        finally:
            (fixture / image_path).write_bytes(original_png)
        extra = fixture / "assets/campaign/environment/unmapped.png"
        try:
            extra.write_bytes(original_png)
            assert any(e["code"] == "unmapped_production_png" for e in audit(2)["errors"])
            checks.append("unmapped_production_png_is_rejected")
        finally:
            extra.unlink()
        new_target = fixture / "assets/campaign/environment/shared/overlays/shallow_cart_ruts.png"
        new_target.parent.mkdir(parents=True, exist_ok=True)
        try:
            new_target.write_bytes(original_png)
            assert any(e["code"] == "unreviewed_production_png" for e in audit(2)["errors"])
            checks.append("new_output_requires_independent_reviewed_baseline")
        finally:
            new_target.unlink()
        for unsafe in ("../outside.png", "C:/office/file.png", "/absolute.png", "assets\\escape.png"):
            try:
                contained_path(fixture, unsafe)
            except ValueError:
                pass
            else:
                raise AssertionError(f"unsafe path accepted: {unsafe}")
        checks.append("traversal_absolute_drive_and_backslash_paths_rejected")
        refusal = cli("campaign_environment_art_static_contract.py", 2, "--report", image_path)
        assert "report must stay" in refusal["error"] and (fixture / image_path).read_bytes() == original_png
        checks.append("report_cannot_overwrite_production_assets")
        history = fixture / "qa/historical.json"
        history.parent.mkdir()
        history.write_text("historical-evidence", encoding="utf-8")
        cli("environment_art_audit.py", 2, "--report", "qa/historical.json")
        assert history.read_text(encoding="utf-8") == "historical-evidence"
        checks.append("report_cannot_overwrite_historical_qa")
        cli("campaign_environment_art_static_contract.py", 2, "--manifest", "missing_manifest.json")
        checks.append("explicit_missing_frozen_manifest_fails_closed")
        basis_copy = fixture / ".godot/copied_basis.json"
        basis_copy.write_bytes(original_mapping)
        cli("campaign_environment_art_static_contract.py", 2, "--manifest", str(basis_copy), "--report", str(basis_copy))
        assert basis_copy.read_bytes() == original_mapping
        checks.append("report_cannot_overwrite_an_explicit_route_basis")
        legacy = fixture / "tools/contracts/environment/legacy/environment_batch_manifest.json"
        legacy.parent.mkdir()
        try:
            legacy.write_text('{"schema_version": 2}', encoding="utf-8")
            assert any(e["code"] == "historical_sha256_mismatch" for e in audit(2)["errors"])
            checks.append("substitute_historical_manifest_is_not_accepted_as_original")
        finally:
            legacy.unlink()
        for script in ("environment_web_art_intake_selftest.py", "environment_surface_candidate_normalize_selftest.py"):
            result = cli(script, 2)
            assert result["passed"] is False and result["tests_executed"] == 0 and result["errors"]
            checks.append(script.removesuffix(".py") + "_reports_blocked_not_passed")
        result = cli("environment_map_clamped_contract.py", 2)
        assert not result["passed"] and result["checks_executed"] == 0
        checks.append("map_clamped_legacy_reports_each_missing_input")
        # Explicitly fabricated metadata tests validator behavior only. These
        # temporary fixtures cannot be promoted to the production inventory.
        install = {"fixture_only": True, "steam_written": False, "release_approved": False,
                   "field_surface": "fallback_atlas_no_web_png", "entries": []}
        relocation = {}
        evidence = fixture / "scratchpad/map_fixture"
        evidence.mkdir(parents=True)
        for surface in ("surface_dry_earth", "surface_forest_earth", "surface_wet_bank", "surface_compacted_stone"):
            png_path = "assets/campaign/environment/shared/surfaces/" + surface + ".png"
            from environment_validation_common import sha256
            digest = sha256(fixture / png_path)
            historical_raw = "C:/office/" + surface + "_raw.png"
            historical_report = "C:/office/" + surface + "_normalization.json"
            report_relative = "scratchpad/map_fixture/" + surface + ".json"
            relocation[historical_raw] = png_path
            relocation[historical_report] = report_relative
            write_report(fixture / report_relative, {
                "fixture_only": True,
                "source": {"raw_png": historical_raw, "raw_size": [2048, 2048], "prompt_sha256": "a" * 64,
                           "correction_prompt": {"sha256": "b" * 64}},
                "normalization": {"single_square_crop": {"performed": False, "source_rectangle": [0, 0, 2048, 2048]},
                                  "forbidden_operations_performed": {"repaint": False}, "localized_pixel_operations": [],
                                  "transparent_padding": [0, 0, 0, 0], "resize": {"scale_x": 1.0, "scale_y": 1.0}}})
            install["entries"].append({"batch_id": surface, "target": png_path, "candidate_png": png_path,
                "normalization_report": historical_report, "raw_sha256": digest, "candidate_sha256": digest, "target_sha256": digest,
                "source_repeat_gate_passed": False, "repeat_required_by_runtime": False, "runtime_sampling_mode": "map_clamped",
                "crop_performed": False, "local_pixel_repair_performed": False, "base_prompt_sha256": "a" * 64,
                "correction_prompt": {"sha256": "b" * 64}, "conversation_url": "https://chatgpt.com/c/00000000-0000-0000-0000-000000000001"})
        install_path = evidence / "install.json"
        relocation_path = evidence / "relocations.json"
        write_report(install_path, install)
        write_report(relocation_path, relocation)
        map_args = ("--install-manifest", str(install_path))
        original_install = install_path.read_bytes()
        assert "overwrite" in cli("environment_map_clamped_contract.py", 2, *map_args, "--output", str(install_path))["error"]
        assert install_path.read_bytes() == original_install
        checks.append("map_report_cannot_overwrite_install_evidence")
        assert "unsafe" in cli("environment_map_clamped_contract.py", 2, *map_args)["error"]
        checks.append("historical_absolute_source_paths_require_explicit_relocation")
        map_args += ("--evidence-map", str(relocation_path))
        field_path = fixture / "assets/campaign/environment/shared/surfaces/surface_field.png"
        field_bytes = field_path.read_bytes()
        assert not cli("environment_map_clamped_contract.py", 1, *map_args)["contract_passed"]
        checks.append("new_field_is_not_a_pass_of_the_historical_four_surface_install")
        # The next positive fixture represents the old four-surface snapshot only.
        # Remove this new addition in the disposable fixture, never in production.
        field_path.unlink()
        assert cli("environment_map_clamped_contract.py", 0, *map_args)["contract_passed"]
        checks.append("explicit_relative_relocation_preserves_evidence_and_reruns_current_routes")
        install["entries"][0]["raw_sha256"] = "0" * 64
        write_report(install_path, install)
        assert not cli("environment_map_clamped_contract.py", 1, *map_args)["contract_passed"]
        checks.append("relocation_does_not_bypass_original_source_hash_check")
        install["entries"][0]["raw_sha256"] = install["entries"][0]["target_sha256"]
        write_report(install_path, install)
        stale = evidence / "stale_router.json"
        write_report(stale, {"passed": True, "counts": {"checks": 785}})
        assert not cli("environment_map_clamped_contract.py", 1, *map_args, "--router-report", str(stale))["contract_passed"]
        checks.append("stale_green_report_cannot_substitute_for_current_route_evidence")
        relocation[historical_raw] = "../outside.png"
        write_report(relocation_path, relocation)
        assert "unsafe" in cli("environment_map_clamped_contract.py", 2, *map_args)["error"]
        checks.append("explicit_relocation_still_rejects_directory_escape")
        field_path.write_bytes(field_bytes)
        result = cli("environment_web_art_intake.py", 2, "--source-manifest", str(fixture / "missing_sources.json"))
        assert result["committed"] is False and "tools" in result["error"] and "implementation_20260902" not in result["error"]
        checks.append("intake_default_uses_repo_local_legacy_location_and_refuses_missing_evidence")
        assert audit(1)["counts"] == report["counts"]
        checks.append("all_failure_injections_restore_original_fixture_state")
    result = {"passed": True, "scope": "validator_behavior_and_portability_not_art_acceptance", "checks": len(checks), "results": checks}
    write_report(report_target(ROOT, Path(".godot/environment_validation/selftest.json")), result)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
