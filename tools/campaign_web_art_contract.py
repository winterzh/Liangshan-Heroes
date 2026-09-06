"""Independently verify web PNGs, source provenance, alpha, feet and legacy bytes.

Read-only with respect to image files; writes only a dedicated web QA JSON.
This does not certify historical accuracy, real gait or in-game integration.
"""
from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, find_objects, label

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/campaign"
checks: list[dict] = []
BAI_PORTRAIT = "portraits/hn_bai_sheng.png"
BAI_BEFORE_SHA = "794d3a32eb8945c146ae0274dc8ce9258dc5f14368fcdedca302b103a1a63990"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name: str, passed: bool, details=None) -> None:
    checks.append({"name": name, "passed": bool(passed), "details": details})


def alpha_info(rgba: np.ndarray) -> dict:
    a = rgba[:, :, 3]
    yy, xx = np.where(a > 99)
    if not len(xx):
        return {"passed": False, "reason": "no visible subject"}
    box = [int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1)]
    empty = int(np.count_nonzero(a == 0))
    visible = int(len(xx))
    edge = bool(np.any(a[0, :] > 99) or np.any(a[-1, :] > 99) or np.any(a[:, 0] > 99) or np.any(a[:, -1] > 99))
    corners = [int(a[0, 0]), int(a[0, -1]), int(a[-1, 0]), int(a[-1, -1])]
    return {"passed": empty > a.size*0.05 and visible > 30 and not edge and max(corners) == 0,
            "alpha_zero": empty, "visible": visible, "bbox_end": box,
            "bottom": box[3]-1, "center_x": (box[0]+box[2])/2,
            "edge_cut": edge, "corner_alpha": corners}


def portrait_blocks(rgba: np.ndarray) -> list[dict]:
    """Report real alpha islands; never erase disconnected pixels automatically."""
    alpha = rgba[:, :, 3]
    labels, _ = label(alpha > 8, np.ones((3, 3), dtype=bool))
    sizes = np.bincount(labels.ravel())
    blocks = []
    for component_id, region in enumerate(find_objects(labels), 1):
        if region is not None:
            yy, xx = region
            blocks.append({"pixels": int(sizes[component_id]),
                           "bbox_end": [xx.start, yy.start, xx.stop, yy.stop],
                           "max_alpha": int(alpha[labels == component_id].max())})
    return sorted(blocks, key=lambda b: -b["pixels"])


def verify_bai_revision(manifest: dict) -> dict | None:
    path = ART / "web_bai_portrait_revision.json"
    if not path.exists():
        return None
    revision = json.loads(path.read_text(encoding="utf-8"))
    check("bai_revision_exact_authorized_output", revision.get("allowed_output") == BAI_PORTRAIT)
    check("bai_revision_exact_reviewed_before_hash", revision.get("before_sha256") == BAI_BEFORE_SHA)
    check("bai_revision_recorded_after_hash", bool(revision.get("after_sha256")) and sha(ART/BAI_PORTRAIT) == revision.get("after_sha256") and revision.get("after_sha256") != BAI_BEFORE_SHA)
    for original, archived in revision["history"].items():
        archived_path = ART / archived["file"]
        check("bai_history_preserved_" + original, archived_path.is_file() and sha(archived_path) == archived["sha256"])
    check("bai_history_original_portrait_hash", revision["history"][BAI_PORTRAIT]["sha256"] == BAI_BEFORE_SHA)
    historical_report = json.loads((ART/revision["history"]["web_art_contract_qa.json"]["file"]).read_text(encoding="utf-8"))
    carry_fact = next((c for c in historical_report["checks"] if c["name"] == "all_pre_carry_pngs_unchanged"), {})
    check("bai_history_carry_1419_fact_preserved", historical_report.get("passed") and len(historical_report["checks"]) == 1419 and carry_fact.get("passed") and carry_fact.get("details", {}).get("files") == 351)
    check("bai_historical_carry_baseline_not_rewritten", sha(ART/"web_carry_prior_pngs.json") == revision["history"]["web_carry_prior_pngs.json"]["sha256"])
    snapshot_info = revision["runtime_snapshot"]
    snapshot_path = ART/snapshot_info["file"]
    check("bai_pre_revision_359_snapshot_hash", sha(snapshot_path) == snapshot_info["sha256"] and snapshot_info["count"] == 359)
    frozen = json.loads(snapshot_path.read_text(encoding="utf-8"))
    current = {str(p.relative_to(ART)).replace("\\", "/"): sha(p) for folder in ["anim", "objects", "portraits"] for p in (ART/folder).glob("*.png")}
    changed = [p for p, old in frozen.items() if current.get(p) != old]
    check("bai_only_one_of_359_runtime_pngs_revised", set(current) == set(frozen) and changed == [BAI_PORTRAIT], {"changed": changed, "other_pngs_unchanged": len(frozen)-len(changed)})
    old_manifest = json.loads((ART/revision["history"]["web_art_manifest.json"]["file"]).read_text(encoding="utf-8"))
    current_other = {s["id"]: s for s in manifest["artifacts"] if s["output"] != BAI_PORTRAIT}
    previous_other = {s["id"]: s for s in old_manifest["artifacts"] if s["output"] != BAI_PORTRAIT}
    check("bai_only_portrait_atlas_spec_revised", current_other == previous_other and manifest["sources"] == old_manifest["sources"])
    old_spec = next(s for s in old_manifest["artifacts"] if s["output"] == BAI_PORTRAIT)
    new_spec = next(s for s in manifest["artifacts"] if s["output"] == BAI_PORTRAIT)
    check("bai_same_source_crop_scale_and_avatar", all(new_spec[k] == old_spec[k] for k in ["kind", "variant", "canvas_size", "anchor", "scale", "output"]) and all(new_spec["frames"][0][k] == old_spec["frames"][0][k] for k in ["source", "region", "allow_source_crop"]))
    return revision


def main() -> int:
    manifest = json.loads((ART / "web_art_manifest.json").read_text(encoding="utf-8"))
    report = json.loads((ART / "web_art_slice_qa.json").read_text(encoding="utf-8"))
    baseline = json.loads((ART / manifest["legacy_baseline"]).read_text(encoding="utf-8"))
    check("slice_passed", report.get("passed", False), report.get("failures", []))
    check("manifest_matches_build", sha(ART / "web_art_manifest.json") == report["manifest_sha256"])
    changed = [p for p, digest in baseline["sha256"].items() if not (ART/p).is_file() or sha(ART/p) != digest]
    check("legacy_assets_and_full_slice_evidence_unchanged", not changed, {"files": len(baseline["sha256"]), "changed": changed})
    bai_revision = verify_bai_revision(manifest)
    carry_baseline_path = ART / "web_carry_prior_pngs.json"
    if carry_baseline_path.exists():
        carry_baseline = json.loads(carry_baseline_path.read_text(encoding="utf-8"))
        changed_before_carry = [p for p, digest in carry_baseline["sha256"].items() if not (ART/p).is_file() or sha(ART/p) != digest]
        if bai_revision is None:
            check("all_pre_carry_pngs_unchanged", not changed_before_carry,
                  {"files": len(carry_baseline["sha256"]), "changed": changed_before_carry})
        else:
            check("pre_carry_exactly_one_later_authorized_portrait_revision", changed_before_carry == [BAI_PORTRAIT] and carry_baseline["sha256"].get(BAI_PORTRAIT) == BAI_BEFORE_SHA,
                  {"files": len(carry_baseline["sha256"]), "changed": changed_before_carry,
                   "other_pre_carry_pngs_unchanged": len(carry_baseline["sha256"])-len(changed_before_carry),
                   "history": "The archived carry report remains the original all-351-unchanged evidence; only this later specific portrait revision is authorized."})
    carry_specs = [s for s in manifest["artifacts"] if s.get("state", "").startswith("carry_")]
    if carry_specs:
        expected_carry = {f"hn_bai_sheng_{state}_{direction}" for state in ["carry_idle", "carry_walk"] for direction in ["se", "sw", "ne", "nw"]}
        check("carry_eight_exact_direction_strips", {s["id"] for s in carry_specs} == expected_carry)
        check("carry_twelve_frames_and_no_new_avatar", all(s["kind"] == "animation" and s["variant"] == "hn_bai_sheng" and len(s["frames"]) == (1 if s["state"] == "carry_idle" else 2) for s in carry_specs) and sum(len(s["frames"]) for s in carry_specs) == 12)
        if carry_baseline_path.exists():
            current_pngs = {str(p.relative_to(ART)).replace("\\", "/") for folder in ["anim", "objects", "portraits"] for p in (ART/folder).glob("*.png")}
            actual_added = current_pngs - set(carry_baseline["sha256"])
            check("carry_only_adds_eight_pngs_no_portrait_or_object", actual_added == {s["output"] for s in carry_specs}, sorted(actual_added))
    source_arrays = {}
    for key, source in manifest["sources"].items():
        path = ART / source["file"]
        check("source_hash_" + key, path.is_file() and sha(path) == source["sha256"])
        if source.get("status") != "accepted":
            continue
        check("source_conversation_url_" + key, source["conversation_url"].startswith("https://chatgpt.com/c/") and "?" not in source["conversation_url"])
        check("source_prompt_hash_" + key, sha(ART / source["prompt_file"]) == source["prompt_sha256"])
        with Image.open(path) as image:
            check("source_native_alpha_" + key, image.mode == "RGBA")
            rgba = np.asarray(image.convert("RGBA"))
        source_arrays[key] = rgba
        a = rgba[:, :, 3]
        check("source_has_real_transparency_" + key, np.count_nonzero(a == 0) > a.size*0.05 and np.count_nonzero(a > 99) > 30)
    counts = {"strips": 0, "frames": 0, "objects": 0, "portraits": 0}
    directions = defaultdict(dict)
    scales = defaultdict(set)
    pose_scales = defaultdict(set)
    frame_summary = {}
    portrait_alpha_components = {}
    for spec in manifest["artifacts"]:
        key = spec["id"]
        record = report["artifacts"].get(key)
        check("built_" + key, record is not None)
        if record is None:
            continue
        path = ART / spec["output"]
        check("output_hash_" + key, path.is_file() and sha(path) == record["sha256"])
        if not path.is_file():
            continue
        with Image.open(path) as image:
            size = int(spec["canvas_size"])
            check("rgba_and_dimensions_" + key, image.mode == "RGBA" and image.size == (size*len(spec["frames"]), size))
            rgba = np.asarray(image.convert("RGBA"))
        kind = spec["kind"]
        if kind == "portrait":
            blocks = portrait_blocks(rgba)
            portrait_alpha_components[key] = blocks
            # These 16 portraits were reviewed as single connected heads/shoulders.
            # A new substantial island needs review, not automatic deletion.
            check("portrait_no_unreviewed_secondary_entity_" + key,
                  all(b["pixels"] <= 32 and b["max_alpha"] <= 32 for b in blocks[1:]),
                  {"secondary_blocks": blocks[1:], "scope": "Reviewed batch-specific alpha guard; small low-alpha resampling fringes are retained."})
        counts[{"object": "objects", "portrait": "portraits", "animation": "strips"}[kind]] += 1
        if kind == "animation":
            counts["frames"] += len(spec["frames"])
            directions[(spec["variant"], spec["state"])][spec["direction"]] = record["sha256"]
        frame_stats = []
        for index, frame in enumerate(spec["frames"]):
            if kind == "animation":
                scales[(spec["variant"], spec["state"], frame["source"])].add(frame.get("scale", spec["scale"]))
                pose_scales[(spec["variant"], spec["state"], index, frame["source"])].add(frame.get("scale", spec["scale"]))
            info = alpha_info(rgba[:, index*size:(index+1)*size])
            check(f"real_alpha_and_no_clip_{key}_{index}", info["passed"], info)
            if kind != "portrait" and info["passed"]:
                check(f"foot_anchor_{key}_{index}", abs(info["bottom"] - round(size*spec["anchor"][1])) <= 3, info["bottom"])
                check(f"center_anchor_{key}_{index}", abs(info["center_x"] - size*spec["anchor"][0]) <= 3, info["center_x"])
            check(f"accepted_source_{key}_{index}", manifest["sources"][frame["source"]]["status"] == "accepted")
            if "isolation_runs" in frame:
                x, y, width, height = frame["region"]
                a = source_arrays[frame["source"]][y:y+height, x:x+width, 3]
                mask = np.zeros((height, width), dtype=bool)
                for yy, start, length in frame["isolation_runs"]:
                    mask[yy, start:start+length] = True
                kept = int(np.count_nonzero((a > 99) & mask))
                excluded = int(np.count_nonzero((a > 99) & ~mask))
                expected = frame["isolation"]
                check(f"atlas_ownership_cut_{key}_{index}", kept == expected["retained_visible_pixels"] and excluded == expected["excluded_foreign_visible_pixels"], {"kept_original_rgba": kept, "excluded_neighbour_visible": excluded})
                if key == "hn_bai_sheng_portrait" and bai_revision is not None:
                    full_a = source_arrays[frame["source"]][:, :, 3]
                    labels, _ = label(full_a > 99)
                    sizes = np.bincount(labels.ravel())
                    primary = bai_revision["source"]["primary_component_id"]
                    large = np.flatnonzero(sizes >= 1500)
                    large = large[large != 0]
                    major = np.where(np.isin(labels, large), labels, 0)
                    nearest = distance_transform_edt(major == 0, return_distances=False, return_indices=True)
                    expected_ownership = major[tuple(nearest)][y:y+height, x:x+width] == primary
                    target_pixels = labels[y:y+height, x:x+width] == primary
                    foreign_pixels = (major[y:y+height, x:x+width] != 0) & ~target_pixels
                    check("bai_exact_original_rgba_source_ownership", np.array_equal(mask, expected_ownership))
                    check("bai_complete_target_hat_face_and_shoulder_pixels", np.all(mask[target_pixels]) and int(np.count_nonzero(target_pixels)) == 12810, {"target_primary_pixels_retained": int(np.count_nonzero(target_pixels & mask))})
                    check("bai_foreign_shoe_pixels_excluded", not np.any(mask & foreign_pixels) and excluded == 132, {"excluded_source_alpha_gt99": excluded})
            frame_stats.append(info)
        frame_summary[key] = frame_stats
    for group, hashes in directions.items():
        key = "_".join(group)
        check("four_direction_files_" + key, set(hashes) == {"se", "sw", "ne", "nw"})
        check("four_distinct_direction_files_" + key, len(set(hashes.values())) == 4, "Different hashes are only a duplicate guard; real orientation is reviewed visually.")
    for group, values in scales.items():
        check("shared_source_direction_scale_" + "_".join(group), len(values) == 1, sorted(values))
    for group, values in pose_scales.items():
        check("shared_pose_scale_" + "_".join(map(str, group)), len(values) == 1, sorted(values))
    total_if_integrated = {key: baseline["inventory"][key] + value for key, value in counts.items()}
    passed = all(c["passed"] for c in checks)
    result = {"passed": passed, "checks": checks, "web_built_inventory": counts,
              "total_if_integrated": total_if_integrated, "frames": frame_summary,
              "portrait_alpha_components": portrait_alpha_components,
              "authorized_revision": bai_revision,
              "limitations": ["True gait and direction/identity/history need visual review, not hash differences.", "Runtime/HUD/crowd integration is tested separately by root and gameplay agents.", "Single-pose idle strips are not full animation cycles."]}
    (ART / "web_art_contract_qa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": len(checks), "passed": passed, "web_built_inventory": counts, "total_if_integrated": total_if_integrated}, ensure_ascii=False))
    for item in checks:
        if not item["passed"]:
            print(json.dumps(item, ensure_ascii=False))
    return 0 if passed else 3


if __name__ == "__main__":
    raise SystemExit(main())
