#!/usr/bin/env python3
"""Bounded contract for map-wide Web surface candidates.

This proves routing/sampling tokens and exact local provenance. It does not
approve visual quality, combat performance, Steam upload, or release status.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

from PIL import Image

import campaign_environment_art_static_contract as route_contract
from environment_validation_common import MAPPING, contained_path, report_target, write_report


SURFACES = (
    "surface_dry_earth",
    "surface_forest_earth",
    "surface_wet_bank",
    "surface_compacted_stone",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resolve_evidence_path(repo: Path, value: str, relocations: dict[str, str]) -> Path:
    """Explicit relocation preserves original evidence bytes and hashes."""
    return contained_path(repo, relocations.get(value, value))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--install-manifest",
        type=Path,
        default=Path("qa/environment_map_clamped_20260902/install_manifest.json"),
    )
    parser.add_argument(
        "--router-report",
        type=Path,
        help="optional previous report; must match freshly checked current route inputs",
    )
    parser.add_argument("--evidence-map", type=Path, help="JSON map from historical evidence paths to repo-relative restored paths")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(".godot/environment_validation/map_clamped_legacy.json"),
    )
    args = parser.parse_args()
    repo = args.repo.resolve()
    manifest_path = args.install_manifest if args.install_manifest.is_absolute() else repo / args.install_manifest
    router_report_path = (args.router_report if args.router_report.is_absolute() else repo / args.router_report) if args.router_report else None
    output_path = report_target(repo, args.output)
    generated_outputs = {output_path, (output_path.parent / "map_clamped_router.json").resolve()}
    if output_path.name == "map_clamped_router.json":
        raise ValueError("output must not use the reserved auxiliary router report name")
    if generated_outputs.intersection({p.resolve() for p in (manifest_path, router_report_path) if p is not None}):
        raise ValueError("output may not overwrite an input manifest or router report")

    missing = [str(path) for path in (manifest_path, router_report_path) if path is not None and not path.is_file()]
    if missing:
        failure = {"passed": False, "status": "blocked_missing_historical_evidence", "missing_inputs": missing,
                   "scope": "historical_map_clamped_contract", "checks_executed": 0}
        write_report(output_path, failure)
        print(json.dumps(failure, ensure_ascii=False))
        return 2

    evidence_map_path = (args.evidence_map if args.evidence_map.is_absolute() else repo / args.evidence_map) if args.evidence_map else None
    if evidence_map_path and evidence_map_path.resolve() in generated_outputs:
        raise ValueError("output may not overwrite the evidence relocation map")
    relocations = json.loads(evidence_map_path.read_text(encoding="utf-8")) if evidence_map_path else {}
    if not isinstance(relocations, dict) or any(not isinstance(k, str) or not isinstance(v, str) for k, v in relocations.items()):
        raise ValueError("evidence map must contain historical-path to repository-relative-path strings")

    checks: list[dict[str, Any]] = []

    def check(name: str, passed: bool, evidence: Any = None) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    install = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = {entry["batch_id"]: entry for entry in install["entries"]}
    check("exact_four_installed_surface_candidates", set(entries) == set(SURFACES), sorted(entries))
    check("field_remains_atlas_fallback", install.get("field_surface") == "fallback_atlas_no_web_png"
          and not (repo / "assets/campaign/environment/shared/surfaces/surface_field.png").exists())
    check("installer_did_not_write_steam_or_approve_release",
          install.get("steam_written") is False and install.get("release_approved") is False)

    for surface in SURFACES:
        entry = entries[surface]
        target = contained_path(repo, entry["target"])
        report_path = resolve_evidence_path(repo, entry["normalization_report"], relocations)
        candidate = resolve_evidence_path(repo, entry["candidate_png"], relocations)
        report = json.loads(report_path.read_text(encoding="utf-8"))
        normalization = report["normalization"]
        raw = resolve_evidence_path(repo, report["source"]["raw_png"], relocations)
        if generated_outputs.intersection({target, report_path, candidate, raw}):
            raise ValueError("output may not overwrite validated source, candidate or normalization evidence")
        source_rect = normalization["single_square_crop"]["source_rectangle"]
        raw_size = report["source"]["raw_size"]
        forbidden = normalization["forbidden_operations_performed"]
        with Image.open(target) as image:
            image.load()
            extrema = image.getchannel("A").getextrema() if image.mode == "RGBA" else None
            raster = {"mode": image.mode, "size": list(image.size), "alpha_extrema": extrema}
        check(f"{surface}_raw_sha_matches", raw.exists() and sha256(raw) == entry["raw_sha256"])
        check(f"{surface}_candidate_target_bytes_identical",
              candidate.exists() and target.exists() and sha256(candidate) == sha256(target)
              == entry["candidate_sha256"] == entry["target_sha256"])
        check(f"{surface}_opaque_2048_rgba", raster == {"mode": "RGBA", "size": [2048, 2048],
              "alpha_extrema": (255, 255)}, raster)
        check(f"{surface}_whole_source_no_crop", normalization["single_square_crop"]["performed"] is False
              and source_rect == [0, 0, raw_size[0], raw_size[1]])
        check(f"{surface}_only_whole_image_normalization",
              normalization["localized_pixel_operations"] == [] and not any(forbidden.values())
              and normalization["transparent_padding"] == [0, 0, 0, 0]
              and normalization["resize"]["scale_x"] == normalization["resize"]["scale_y"])
        check(f"{surface}_map_clamped_overrides_repeat_requirement_only",
              entry["source_repeat_gate_passed"] is False
              and entry["repeat_required_by_runtime"] is False
              and entry["runtime_sampling_mode"] == "map_clamped"
              and entry["crop_performed"] is False
              and entry["local_pixel_repair_performed"] is False)
        check(f"{surface}_web_prompt_provenance_bound",
              str(entry["conversation_url"]).startswith("https://chatgpt.com/c/")
              and report["source"]["prompt_sha256"] == entry["base_prompt_sha256"]
              and report["source"]["correction_prompt"]["sha256"]
              == entry["correction_prompt"]["sha256"])

    shader_path = repo / "scripts/liangshan_coast.gdshader"
    scenery_path = repo / "scripts/liangshan_scenery.gd"
    shader = shader_path.read_text(encoding="utf-8")
    scenery = scenery_path.read_text(encoding="utf-8")
    for uniform in ("forest", "dry", "wet", "hard", "field"):
        declaration = re.search(
            rf"uniform sampler2D surface_{uniform}_texture\s*:\s*([^;]+);", shader
        )
        check(f"shader_{uniform}_sampler_repeat_disabled", declaration is not None
              and "repeat_disable" in declaration.group(1)
              and "repeat_enable" not in declaration.group(1),
              declaration.group(0) if declaration else None)
        check(f"shader_{uniform}_has_no_direct_tile_uv_sample",
              re.search(rf"texture\(surface_{uniform}_texture\s*,\s*tile_uv\)", shader) is None)
    check("shader_clamps_map_uv_to_half_texel",
          "vec2 map_clamped_uv(vec2 map_uv, vec2 texture_size_px)" in shader
          and "vec2 half_texel = vec2(0.5) / max(texture_size_px, vec2(1.0));" in shader
          and "return clamp(map_uv, half_texel, vec2(1.0) - half_texel);" in shader)
    check("shader_map_uv_uses_world_size", "vec2 surface_map_uv =" in shader
          and "/ max(world_size, vec2(1.0));" in shader)
    check("shader_map_warp_is_centered_and_bounded_to_two_pixels",
          "vec2 map_detail_warp = (detail_noise - vec2(0.5)) * 4.0;" in shader)
    check("shader_legacy_atlas_keeps_repeat_tile_uv",
          "vec2 tile_uv = fract(" in shader and "/ 256.0);" in shader
          and "sample_primary(grass_region, tile_uv)" in shader
          and "sample_secondary(field_region, tile_uv)" in shader)
    check("shader_skips_only_exact_zero_weight_surface_reads",
          all(f"if ({weight} > 0.0)" in shader for weight in ("w.r", "w.g", "w.b", "w.a", "wf")))
    check("runtime_metadata_distinguishes_map_and_atlas_sampling",
          '"sampling_mode":"map_clamped" if enabled else "atlas_tile_uv"' in scenery
          and '"repeat_enabled":false if enabled else true' in scenery)

    # Re-execute the full current route contract. Historical 785/65 counters
    # are not evidence about today's source or resource completeness.
    router = route_contract.run(repo, repo / MAPPING, output_path.parent / "map_clamped_router.json")
    check("current_router_contract_pass", router["passed"] and all(c["passed"] for c in router["checks"]), router["counts"])
    if router_report_path:
        supplied = json.loads(router_report_path.read_text(encoding="utf-8"))
        check("supplied_router_report_matches_current_inputs",
              all(supplied.get(key) == router[key] for key in ("router_sha256", "consumer_file_sha256", "checks", "counts")))

    report_out = {
        "schema_version": 1,
        "kind": "environment_map_clamped_candidate_contract",
        "scope": "local_candidate_only_no_visual_approval_no_release_no_steam",
        "passed": all(item["passed"] for item in checks),
        "counts": {"checks": len(checks), "passed": sum(item["passed"] for item in checks),
                   "failed": sum(not item["passed"] for item in checks)},
        "checks": checks,
        "inputs": {
            "install_manifest": str(manifest_path),
            "install_manifest_sha256": sha256(manifest_path),
            "router_report": str(output_path.parent / "map_clamped_router.json"),
            "router_report_sha256": sha256(output_path.parent / "map_clamped_router.json"),
            "evidence_map": str(evidence_map_path) if evidence_map_path else None,
            "evidence_map_sha256": sha256(evidence_map_path) if evidence_map_path else None,
            "shader": str(shader_path),
            "shader_sha256": sha256(shader_path),
            "scenery": str(scenery_path),
            "scenery_sha256": sha256(scenery_path),
        },
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report_out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"contract_passed": report_out["passed"], **report_out["counts"],
                      "output": str(output_path)}, ensure_ascii=False))
    return 0 if report_out["passed"] else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({"passed": False, "status": "invalid_or_missing_historical_input", "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        raise SystemExit(2)
