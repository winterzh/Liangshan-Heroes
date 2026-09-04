"""Filesystem-isolated tests for environment_web_art_intake.py.

The test creates synthetic 2048px sources below a temporary workspace.  It
never writes repository production assets and never runs Godot or a browser.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/environment_web_art_intake.py"
BATCH_MANIFEST = (
    ROOT.parent
    / "implementation_20260902"
    / "environment_prompt_drafts_v2"
    / "environment_batch_manifest.json"
)
MAPPING_TEMPLATE = ROOT / "tools/environment_production_mapping.template.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def source_entry(batch: dict, png: Path, category: str) -> dict:
    if category == "opaque_tileable_surface":
        review = {
            "reviewed_at": "2026-09-02T04:00:00+08:00",
            "notes": "synthetic self-test source",
            "three_by_three_wrap_has_no_visible_seam_vignette_hotspot_or_directional_band": True,
            "no_forbidden_scene_content": True,
            "gameplay_zoom_100_and_150_readable": True,
            "prompt_specific_acceptance_confirmed": True,
        }
    else:
        review = {
            "reviewed_at": "2026-09-02T04:00:00+08:00",
            "notes": "synthetic self-test source",
            "cell_map_and_scale_confirmed": True,
            "whole_cell_rectangles_only_confirmed": True,
            "no_mirror_repaint_synthesis_mask_or_pixel_clear_needed": True,
            "no_forbidden_base_shadow_text_watermark_or_modern_content": True,
            "isometric_scale_silhouette_and_anchor_confirmed": True,
            "prompt_specific_acceptance_confirmed": True,
        }
    return {
        "id": batch["id"],
        "source_png": str(png),
        "source_sha256": sha256(png),
        "size": [2048, 2048],
        "conversation_url": "https://chatgpt.com/c/00000000-0000-0000-0000-000000000001",
        "prompt_sha256": batch["prompt_sha256"],
        "decision": "adopt",
        "reason": "synthetic acceptance fixture",
        "human_review": review,
    }


def load_module():
    spec = importlib.util.spec_from_file_location("environment_web_art_intake", TOOL)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load environment intake module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def run_cli(arguments: list[str], expected: int) -> dict:
    command = [sys.executable, "-X", "utf8", "-B", str(TOOL), *arguments]
    process = subprocess.run(command, text=True, encoding="utf-8", capture_output=True, check=False)
    if process.returncode != expected:
        raise AssertionError(
            f"expected exit {expected}, got {process.returncode}\nstdout={process.stdout}\nstderr={process.stderr}"
        )
    payload = process.stdout if expected == 0 else (process.stderr or process.stdout)
    return json.loads(payload)


def main() -> int:
    batch_data = json.loads(BATCH_MANIFEST.read_text(encoding="utf-8"))
    module = load_module()
    checks: list[str] = []
    with tempfile.TemporaryDirectory(prefix="environment_intake_selftest_") as temporary:
        workspace = Path(temporary)
        # The tool is deliberately pinned to the reviewed frozen contract.
        # Tests read that evidence in place while every generated PNG, route
        # fixture, checkpoint and target remains below this temporary workspace.
        fixture_batch_manifest = BATCH_MANIFEST
        fixture_static_check = BATCH_MANIFEST.parent / "static_self_check.json"
        batches = {item["id"]: item for item in batch_data["send_order"]}

        # Copy the frozen router, report, static contract and every SHA-bound
        # consumer into the isolated workspace.  Only the report's absolute
        # router path changes; all exact consumer lines and hashes stay real.
        router_target = workspace / "scripts/campaign_environment_art.gd"
        static_contract_target = workspace / "tools/campaign_environment_art_static_contract.py"
        router_report_target = workspace / "qa/environment_runtime_router_20260902/report.json"
        router_target.parent.mkdir(parents=True)
        static_contract_target.parent.mkdir(parents=True)
        router_report_target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "scripts/campaign_environment_art.gd", router_target)
        shutil.copyfile(ROOT / "tools/campaign_environment_art_static_contract.py", static_contract_target)
        router_report = json.loads(
            (ROOT / "qa/environment_runtime_router_20260902/report.json").read_text(encoding="utf-8")
        )
        router_report["manifest_sha256"] = sha256(fixture_batch_manifest)
        router_report["router_path"] = str(router_target)
        router_report["router_sha256"] = sha256(router_target)
        for relative in router_report["consumer_file_sha256"]:
            source = ROOT / relative
            target = workspace / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            # The production report remains frozen as pre-intake evidence.  The
            # isolated fixture binds that same audited route/check structure to
            # today's copied consumers, so later renderer-only changes do not
            # turn this intake behavior test into a stale-source test.
            router_report["consumer_file_sha256"][relative] = sha256(target)
        for contract_check in router_report["checks"]:
            if contract_check.get("name") not in {
                "consumer_routes_exact", "surface_consumers_exact"
            }:
                continue
            for route in contract_check.get("detail", []):
                consumer_file = route.get("consumer_file")
                if consumer_file in router_report["consumer_file_sha256"]:
                    route["consumer_sha256"] = router_report["consumer_file_sha256"][consumer_file]
        save_json(router_report_target, router_report)
        downloads = workspace / "downloads"
        downloads.mkdir(parents=True)

        surface_png = downloads / "surface.png"
        Image.new("RGBA", (2048, 2048), (121, 103, 72, 255)).save(surface_png)
        atlas_png = downloads / "atlas.png"
        atlas = Image.new("RGBA", (2048, 2048), (0, 0, 0, 0))
        draw = ImageDraw.Draw(atlas)
        for row in range(4):
            for column in range(4):
                left = column * 512 + 72
                top = row * 512 + 72
                draw.rounded_rectangle(
                    (left, top, left + 340, top + 340),
                    radius=28,
                    fill=(60 + row * 35, 70 + column * 30, 95 + (row + column) * 12, 255),
                )
        atlas.save(atlas_png)

        source_manifest = workspace / "sources.json"
        entries = [
            source_entry(batches["surface_dry_earth"], surface_png, "opaque_tileable_surface"),
            source_entry(
                batches["huangnigang_objects"], atlas_png, "transparent_object_atlas_4x4"
            ),
        ]
        save_json(
            source_manifest,
            {"schema_version": 1, "kind": "web_chatgpt_environment_sources", "entries": entries},
        )

        mapping = json.loads(MAPPING_TEMPLATE.read_text(encoding="utf-8"))
        mapping["batch_manifest_sha256"] = sha256(fixture_batch_manifest)
        mapping["static_self_check_sha256"] = sha256(fixture_static_check)
        mapping["runtime_router_contract"] = {
            "router_path": "scripts/campaign_environment_art.gd",
            "router_sha256": sha256(router_target),
            "static_contract_path": "tools/campaign_environment_art_static_contract.py",
            "static_contract_sha256": sha256(static_contract_target),
            "report_path": "qa/environment_runtime_router_20260902/report.json",
            "report_sha256": sha256(router_report_target),
            "report_passed_checks": router_report["counts"]["checks"],
        }
        mapping_path = workspace / "mapping.json"
        save_json(mapping_path, mapping)

        common = [
            "--workspace-root",
            str(workspace),
            "--source-manifest",
            str(source_manifest),
            "--batch-manifest",
            str(fixture_batch_manifest),
            "--mapping-manifest",
            str(mapping_path),
        ]
        dry = run_cli(common + ["--report", str(workspace / "qa/dry.json")], 0)
        assert dry["dry_run"] and dry["commit_ready"] and dry["production_output_count"] == 17
        assert not (workspace / "assets").exists(), "dry-run created production assets"
        signal_consumer = workspace / "scripts/levels/level8_dongchangfu.gd"
        signal_bytes = signal_consumer.read_bytes()
        signal_consumer.write_bytes(signal_bytes + b"\n")
        try:
            module.build_plan(source_manifest, fixture_batch_manifest, mapping_path, workspace)
        except module.IntakeError as error:
            assert "changed after its report" in str(error)
        else:
            raise AssertionError("consumer source drift was accepted")
        finally:
            signal_consumer.write_bytes(signal_bytes)
        checks.append("dry_run_no_production_write")

        committed = run_cli(common + ["--commit"], 0)
        assert committed["committed"] and committed["commit_result"]["runtime_pngs_written"] == 17
        surface_target = Path(
            next(item for item in mapping["batches"] if item["id"] == "surface_dry_earth")[
                "target"
            ]
        )
        assert (workspace / surface_target).read_bytes() == surface_png.read_bytes()
        first_huang_target = Path(
            next(
                item for item in mapping["batches"] if item["id"] == "huangnigang_objects"
            )["cells"][0]["target"]
        )
        with Image.open(workspace / first_huang_target) as output:
            assert output.mode == "RGBA" and output.size == (512, 512)
        checks.append("commit_surface_copy_and_fixed_cell_outputs")

        # A nonzero pixel in an exact separator is an objective adoption failure.
        bad_atlas_png = downloads / "atlas_bad_separator.png"
        bad = atlas.copy()
        bad.putpixel((496, 100), (255, 0, 0, 255))
        bad.save(bad_atlas_png)
        bad_entry = source_entry(
            batches["huangnigang_objects"], bad_atlas_png, "transparent_object_atlas_4x4"
        )
        bad_sources = workspace / "bad_sources.json"
        save_json(
            bad_sources,
            {"schema_version": 1, "kind": "web_chatgpt_environment_sources", "entries": [bad_entry]},
        )
        bad_report = run_cli(
            [
                "--workspace-root",
                str(workspace),
                "--source-manifest",
                str(bad_sources),
                "--batch-manifest",
                str(fixture_batch_manifest),
                "--mapping-manifest",
                str(mapping_path),
            ],
            2,
        )
        assert "huangnigang_objects" in bad_report["invalid_adoptions"]
        assert any("vertical separator" in item for item in bad_report["sources"][0]["objective_failures"])
        bad_entry["decision"] = "reject"
        bad_entry["reason"] = "synthetic separator defect rejected"
        save_json(
            bad_sources,
            {"schema_version": 1, "kind": "web_chatgpt_environment_sources", "entries": [bad_entry]},
        )
        rejected_report = run_cli(
            [
                "--workspace-root",
                str(workspace),
                "--source-manifest",
                str(bad_sources),
                "--batch-manifest",
                str(fixture_batch_manifest),
                "--mapping-manifest",
                str(mapping_path),
            ],
            0,
        )
        assert (
            rejected_report["commit_ready"]
            and rejected_report["production_output_count"] == 0
            and not rejected_report["sources"][0]["objective_pass"]
        )
        checks.append("separator_alpha_rejected")

        # Dry-run reports an unmapped adopted cell; commit refuses it.
        missing_signal_evidence = json.loads(mapping_path.read_text(encoding="utf-8"))
        signal_cell = next(
            cell
            for batch in missing_signal_evidence["batches"]
            for cell in batch.get("cells", [])
            if cell.get("output_id") == "level8_daming_cuiyun_tower_signal"
        )
        signal_cell["integration_evidence"] = [
            item
            for item in signal_cell["integration_evidence"]
            if not item.startswith("scripts/levels/level8_dongchangfu.gd:276:")
        ]
        missing_signal_path = workspace / "mapping_missing_signal_evidence.json"
        save_json(missing_signal_path, missing_signal_evidence)
        try:
            module.build_plan(
                source_manifest, fixture_batch_manifest, missing_signal_path, workspace
            )
        except module.IntakeError as error:
            assert "exact consumer line" in str(error)
        else:
            raise AssertionError("cuiyun signal was inferred from its shared route key")

        missing_mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
        huang_route = next(item for item in missing_mapping["batches"] if item["id"] == "huangnigang_objects")
        huang_route["cells"][0]["integration_ready"] = False
        huang_route["cells"][0]["integration_evidence"] = []
        missing_path = workspace / "mapping_missing.json"
        save_json(missing_path, missing_mapping)
        missing_common = common.copy()
        missing_common[missing_common.index(str(mapping_path))] = str(missing_path)
        missing_dry = run_cli(missing_common, 0)
        assert not missing_dry["commit_ready"] and missing_dry["mapping_gaps"]
        refused = run_cli(missing_common + ["--commit"], 2)
        assert "commit refused" in refused["error"]
        checks.append("unmapped_route_scope_commit_refused")

        # Dedicated duplicate targets are rejected before any staging.
        duplicate_mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
        duplicate_route = next(
            item for item in duplicate_mapping["batches"] if item["id"] == "huangnigang_objects"
        )
        duplicate_route["cells"][1]["target"] = duplicate_route["cells"][0]["target"]
        duplicate_path = workspace / "mapping_duplicate.json"
        save_json(duplicate_path, duplicate_mapping)
        try:
            module.build_plan(source_manifest, fixture_batch_manifest, duplicate_path, workspace)
        except module.IntakeError as error:
            assert "must equal schema v2" in str(error)
        else:
            raise AssertionError("dedicated duplicate target was accepted")
        checks.append("duplicate_target_rejected")

        # Inject one install failure after two replacements.  The transaction
        # must restore every pre-existing target byte-for-byte.
        rollback_plan = module.build_plan(source_manifest, fixture_batch_manifest, mapping_path, workspace)
        rollback_writes, _ = module._build_commit_writes(rollback_plan, workspace)
        new_target = sorted(rollback_writes, key=lambda item: str(item).casefold())[0]
        assert new_target.is_file()
        new_target.unlink()
        before = {path: sha256(path) for path in rollback_writes if path.is_file()}
        original_install = module.install_staged_file
        call_count = 0

        def fail_once(staged: Path, target: Path) -> None:
            nonlocal call_count
            call_count += 1
            if call_count == 3:
                raise OSError("synthetic install interruption")
            original_install(staged, target)

        module.install_staged_file = fail_once
        try:
            module.commit_plan(rollback_plan, workspace)
        except module.IntakeError as error:
            assert "restored" in str(error)
        else:
            raise AssertionError("synthetic install interruption did not fail the commit")
        finally:
            module.install_staged_file = original_install
        after = {path: sha256(path) for path in before}
        assert after == before
        assert not new_target.exists(), "rollback left a newly installed target behind"
        checks.append("partial_install_rollback_sha_exact")

    print(
        json.dumps(
            {
                "schema_version": 1,
                "kind": "environment_web_art_intake_selftest",
                "passed": True,
                "checks": checks,
                "godot_run": False,
                "browser_used": False,
                "repository_production_assets_written": False,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
