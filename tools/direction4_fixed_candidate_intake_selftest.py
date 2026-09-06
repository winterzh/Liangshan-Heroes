"""Regression tests for the candidate-only fixed_cell_rect_v1 intake path."""
from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/direction4_first_sample_intake.py"
PROVENANCE = (
    ROOT.parent
    / "implementation_20260902/web_sample_sources_20260902/fixed_cell_rect_candidates.json"
)


def load_module():
    spec = importlib.util.spec_from_file_location("direction4_fixed_candidate_intake_under_test", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load intake module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


M = load_module()
CHECKS: list[dict[str, object]] = []
NEGATIVE_CHECKS = 0


def check(condition: bool, label: str) -> None:
    CHECKS.append({"label": label, "passed": bool(condition)})
    if not condition:
        raise AssertionError(label)


def expect_failure(label: str, needle: str, action) -> None:
    global NEGATIVE_CHECKS
    NEGATIVE_CHECKS += 1
    try:
        action()
    except M.IntakeError as error:
        check(needle in str(error), label + " -> " + str(error))
    else:
        raise AssertionError(label + " did not fail")


def absolute_test_manifest(data: dict[str, object], destination: Path) -> Path:
    ledger = PROVENANCE.parent
    for raw in [*data["entries"], *data["row_replacements"], *data["blocked_attempts"]]:
        entry = raw
        entry["source_png"] = str((ledger / entry["source_png"]).resolve())
        for field in ("base_prompt", "correction_prompt", "crop_spec", "candidate_manifest"):
            record = entry.get(field)
            if not isinstance(record, dict):
                continue
            path = M.candidate_record_path(record["path"], PROVENANCE, field)
            record["path"] = str(path)
    destination.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return destination


class FastFixedNormalizer:
    """Skip expensive image transforms after provenance gates in negative cases."""

    def __init__(self, real):
        self.real = real
        self.NormalizeError = real.NormalizeError
        self.rgba_sha256 = real.rgba_sha256
        self.visible_components = real.visible_components

    def candidate_path_guard(self, path, label):
        self.real.candidate_path_guard(path, label)

    @staticmethod
    def prepare_candidate(source, spec, output_dir, manifest_path):
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        writes = []
        for output in manifest["outputs"]:
            path = M.candidate_record_path(output["output"], manifest_path, "output")
            writes.append((path, path.read_bytes()))
        return manifest, writes


def main() -> int:
    real_snapshot = M.production_candidate_snapshot
    production_before = M.production_candidate_snapshot()
    report = M.validate_fixed_candidate_manifest(PROVENANCE, M.DEFAULT_BATCH_MANIFEST)
    atlases = report["atlases"]
    frames = [frame for atlas in atlases for frame in atlas["frames"]]
    row_replacements = report["row_replacements"]
    replacement_frames = [frame for replacement in row_replacements for frame in replacement["frames"]]
    check(report["provenance_validation_passed"] is True, "formal provenance validation passes")
    check(report["normalization_reproducible"] is True, "all candidate bytes reproduce deterministically")
    check(report["candidate_only"] is True, "formal path remains candidate only")
    check(report["adoption_approved"] is False, "formal path never auto-adopts")
    check(report["production_commit_eligible"] is False, "formal path has no production commit eligibility")
    check(report["production_assets_modified"] is False, "formal validation does not modify production")
    check(report["supported_source_rules"] == list(M.SUPPORTED_SOURCE_RULES), "both source rules remain explicit")
    check(
        report["campaign_variant_scope_gate"] == M.FIXED_CAMPAIGN_VARIANT_SCOPE_GATE,
        "Mengzhou Wu Song and Wild Boar Forest Lin Chong stay excluded from generic hero adoption",
    )
    check(
        report["runtime_mapping_gate"] == M.FIXED_RUNTIME_MAPPING_GATE
        and report["runtime_mapping_gate"]["production_blocking"] is True,
        "generic hurt selection and down/death naming remain explicit production blockers",
    )
    check([atlas["atlas_id"] for atlas in atlases] == list(M.FIXED_CANDIDATE_ATLAS_IDS), "exact reviewed atlas set")
    expected_frame_count = len(M.FIXED_CANDIDATE_ATLAS_IDS) * 16
    check(len(frames) == expected_frame_count, "every candidate atlas exposes exactly 16 frame proofs")
    check(all(frame["complete_visible_body_retained"] for frame in frames), "all complete bodies retained")
    check(all(frame["foreign_large_visible_pixels"] == 0 for frame in frames), "no crop contains another large body")
    check(all(atlas["adoption_approved"] is False for atlas in atlases), "no atlas is auto-adopted")
    check(
        sum(atlas["fringe_threshold_frames"] for atlas in atlases) == expected_frame_count,
        "colored fringe flags all current frames",
    )
    check(all(frame["fringe"]["automatic_pixel_clearing_performed"] is False for frame in frames), "fringe pixels are never cleared")
    check(all(frame["fringe"]["automatic_adoption_granted"] is False for frame in frames), "fringe statistics never grant adoption")
    check(all(frame["fringe"]["canvas_border_max_alpha"] == 0 for frame in frames), "all final canvas borders stay transparent")
    check(all(atlas["manual_visual_review_required"] for atlas in atlases), "all current atlases stay at manual review")
    check(
        [item["replacement_id"] for item in row_replacements] == list(M.FIXED_ROW_REPLACEMENT_IDS)
        and len(replacement_frames) == 4,
        "one reviewed four-direction Wu Song attack row overrides the base atlas row",
    )
    check(
        [(frame["unit"], frame["state"], frame["direction"]) for frame in replacement_frames]
        == [("wu_song", "attack", direction) for direction in M.DIRECTIONS],
        "Wu Song row replacement has the exact generic attack identity and four direction order",
    )
    check(
        all(frame["complete_visible_body_retained"] and frame["foreign_large_visible_pixels"] == 0 for frame in replacement_frames),
        "Wu Song replacement keeps every full figure and both blades isolated",
    )
    check(
        row_replacements[0]["campaign_scope"]["excluded_variants"] == ["wu_song_mengzhou"]
        and row_replacements[0]["production_commit_eligible"] is False,
        "Wu Song replacement remains generic-only and excluded from Mengzhou",
    )
    check(
        atlases[2]["reference_idle_sha256"] == atlases[0]["raw_sha256"]
        and atlases[3]["reference_idle_sha256"] == atlases[1]["raw_sha256"],
        "walk candidates bind their exact idle raw source",
    )
    check(
        len(report["blocked_attempts"]) == len(M.FIXED_BLOCKED_ATTEMPT_IDS),
        "all reviewed semantic rejections and fixed-rectangle blockers remain recorded",
    )
    check(
        report["blocked_attempts"][1]["geometry_evidence"]["first_cell"][
            "second_cell_visible_pixels_inside_required_rect"
        ]
        == 304,
        "hero attack cross-cell blocker reproduces its foreign-pixel evidence",
    )
    check(
        report["blocked_attempts"][1]["geometry_evidence"]["workaround_forbidden"] is True,
        "blocked hero attack cannot use masking or pixel clearing",
    )
    check(
        report["blocked_attempts"][2]["content_review"][
            "wu_song_double_sheathed_jiedao_visible_all_directions"
        ]
        is True,
        "blocked hero hurt source retains the reviewed Wu Song paired-sheath finding",
    )
    check(
        report["blocked_attempts"][3]["content_review"][
            "lian_huan_ma_armor_and_rider_equipment_confirmed"
        ]
        is True,
        "blocked troop hurt source retains the reviewed linked-horse equipment finding",
    )

    original_data = json.loads(PROVENANCE.read_text(encoding="utf-8"))
    real_fixed = M.load_fixed_normalizer()
    with tempfile.TemporaryDirectory(prefix="direction4_fixed_intake_negative_") as temporary:
        temp = Path(temporary)
        M.production_candidate_snapshot = lambda: "0" * 64
        M.load_fixed_normalizer = lambda: FastFixedNormalizer(real_fixed)

        def mutated(name: str, mutate):
            data = copy.deepcopy(original_data)
            mutate(data)
            return absolute_test_manifest(data, temp / f"{name}.json")

        expect_failure(
            "reject wrong source rule",
            "source rule",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("source_rule", lambda d: d["entries"][0].__setitem__("source_rule", "transparent_grid_v1")),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject raw SHA drift",
            "raw source",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("raw_sha", lambda d: d["entries"][0].__setitem__("raw_sha256", "0" * 64)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject base prompt SHA drift",
            "base_prompt SHA mismatch",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("base_prompt", lambda d: d["entries"][0]["base_prompt"].__setitem__("sha256", "0" * 64)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject correction prompt SHA drift",
            "correction_prompt SHA mismatch",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("correction_prompt", lambda d: d["entries"][0]["correction_prompt"].__setitem__("sha256", "0" * 64)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject crop specification SHA drift",
            "crop_spec SHA mismatch",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("crop_spec", lambda d: d["entries"][0]["crop_spec"].__setitem__("sha256", "0" * 64)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject candidate manifest SHA drift",
            "candidate_manifest SHA mismatch",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("candidate_manifest", lambda d: d["entries"][0]["candidate_manifest"].__setitem__("sha256", "0" * 64)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject wrong idle binding",
            "does not bind",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("idle_binding", lambda d: d["entries"][2].__setitem__("reference_idle_sha256", "0" * 64)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject automatic fringe clearing policy",
            "fringe policy",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("fringe_policy", lambda d: d["fringe_policy"].__setitem__("automatic_pixel_clearing", True)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject dropped campaign variant scope gate",
            "campaign-variant scope",
            lambda: M.validate_fixed_candidate_manifest(
                mutated(
                    "variant_scope",
                    lambda d: d["campaign_variant_scope_gate"].__setitem__(
                        "whole_hero_atlas_production_adoption_allowed", True
                    ),
                ),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject dropped runtime mapping gate",
            "runtime-mapping production blockers",
            lambda: M.validate_fixed_candidate_manifest(
                mutated(
                    "runtime_mapping",
                    lambda d: d["runtime_mapping_gate"].__setitem__("production_blocking", False),
                ),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject Mengzhou scope on generic Wu Song row replacement",
            "target row, campaign scope",
            lambda: M.validate_fixed_candidate_manifest(
                mutated(
                    "row_replacement_scope",
                    lambda d: d["row_replacements"][0]["campaign_scope"].__setitem__(
                        "excluded_variants", []
                    ),
                ),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject pre-approved candidate",
            "source rule, status",
            lambda: M.validate_fixed_candidate_manifest(
                mutated("approved", lambda d: d["entries"][0].__setitem__("adoption_approved", True)),
                M.DEFAULT_BATCH_MANIFEST,
            ),
        )
        expect_failure(
            "reject Steam report destination",
            "Steam/Steamworks",
            lambda: M.validate_report_path(
                Path(r"C:\temporary\Steamworks\Liangshan_5088120\candidate_report.json"), ()
            ),
        )

    M.production_candidate_snapshot = real_snapshot
    production_after = M.production_candidate_snapshot()
    check(production_after == production_before, "production direction-art tree unchanged")
    result = {
        "schema_version": 1,
        "kind": "direction4_fixed_candidate_intake_selftest",
        "passed": all(item["passed"] for item in CHECKS),
        "checks": len(CHECKS),
        "negative_checks": NEGATIVE_CHECKS,
        "candidate_atlases": len(atlases),
        "candidate_frames": len(frames),
        "row_replacement_frames": len(replacement_frames),
        "fringe_threshold_frames": sum(atlas["fringe_threshold_frames"] for atlas in atlases),
        "row_replacement_fringe_threshold_frames": sum(
            replacement["fringe_threshold_frames"] for replacement in row_replacements
        ),
        "production_assets_modified": production_after != production_before,
        "production_tree_sha256_before": production_before,
        "production_tree_sha256_after": production_after,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
