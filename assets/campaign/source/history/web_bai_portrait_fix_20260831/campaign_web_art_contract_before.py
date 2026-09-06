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

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/campaign"
checks: list[dict] = []


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


def main() -> int:
    manifest = json.loads((ART / "web_art_manifest.json").read_text(encoding="utf-8"))
    report = json.loads((ART / "web_art_slice_qa.json").read_text(encoding="utf-8"))
    baseline = json.loads((ART / manifest["legacy_baseline"]).read_text(encoding="utf-8"))
    check("slice_passed", report.get("passed", False), report.get("failures", []))
    check("manifest_matches_build", sha(ART / "web_art_manifest.json") == report["manifest_sha256"])
    changed = [p for p, digest in baseline["sha256"].items() if not (ART/p).is_file() or sha(ART/p) != digest]
    check("legacy_assets_and_full_slice_evidence_unchanged", not changed, {"files": len(baseline["sha256"]), "changed": changed})
    carry_baseline_path = ART / "web_carry_prior_pngs.json"
    if carry_baseline_path.exists():
        carry_baseline = json.loads(carry_baseline_path.read_text(encoding="utf-8"))
        changed_before_carry = [p for p, digest in carry_baseline["sha256"].items() if not (ART/p).is_file() or sha(ART/p) != digest]
        check("all_pre_carry_pngs_unchanged", not changed_before_carry,
              {"files": len(carry_baseline["sha256"]), "changed": changed_before_carry})
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
              "limitations": ["True gait and direction/identity/history need visual review, not hash differences.", "Runtime/HUD/crowd integration is tested separately by root and gameplay agents.", "Single-pose idle strips are not full animation cycles."]}
    (ART / "web_art_contract_qa.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"checks": len(checks), "passed": passed, "web_built_inventory": counts, "total_if_integrated": total_if_integrated}, ensure_ascii=False))
    for item in checks:
        if not item["passed"]:
            print(json.dumps(item, ensure_ascii=False))
    return 0 if passed else 3


if __name__ == "__main__":
    raise SystemExit(main())
