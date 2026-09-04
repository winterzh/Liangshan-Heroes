"""Prepare the explicitly authorized Bai Sheng portrait atlas-ownership correction.

This script never edits or writes PNG pixels. It archives existing bytes and
records original-RGBA row runs for the normal Godot atlas slicer. --finalize
records the one rebuilt PNG only after every other runtime PNG is byte-identical.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, find_objects, label

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/campaign"
RECORD = ART / "web_bai_portrait_revision.json"
HISTORY = ART / "source/history/web_bai_portrait_fix_20260831"
PORTRAIT = "portraits/hn_bai_sheng.png"
OLD_SHA = "794d3a32eb8945c146ae0274dc8ce9258dc5f14368fcdedca302b103a1a63990"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def current_pngs() -> dict:
    return {str(p.relative_to(ART)).replace("\\", "/"): sha(p)
            for folder in ["anim", "objects", "portraits"]
            for p in sorted((ART / folder).glob("*.png"))}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--finalize", action="store_true")
    args = parser.parse_args()
    if args.finalize:
        record = json.loads(RECORD.read_text(encoding="utf-8"))
        frozen = json.loads((HISTORY / "runtime_png_sha256.json").read_text(encoding="utf-8"))
        current = current_pngs()
        changed = [p for p, old in frozen.items() if current.get(p) != old]
        if set(current) != set(frozen) or changed != [PORTRAIT]:
            raise SystemExit(f"Expected precisely one authorized PNG revision; got {changed}")
        record["after_sha256"] = current[PORTRAIT]
        record["status"] = "rebuilt_pending_independent_contract_and_visual_review"
        record["other_runtime_pngs_unchanged"] = len(frozen) - 1
        write_json(RECORD, record)
        print(json.dumps({"authorized_changed": changed, "other_pngs_unchanged": len(frozen)-1,
                          "after_sha256": current[PORTRAIT]}, ensure_ascii=False))
        return

    if RECORD.exists() or HISTORY.exists():
        raise SystemExit("Revision history already exists; refusing to overwrite the pre-fix evidence.")
    if sha(ART / PORTRAIT) != OLD_SHA:
        raise SystemExit("Portrait differs from the reviewed defective original.")
    manifest_path = ART / "web_art_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    spec = next(s for s in manifest["artifacts"] if s["id"] == "hn_bai_sheng_portrait")
    frame = spec["frames"][0]
    if frame["source"] != "web_merchants_b_idle_v1" or frame["region"] != [95, 915, 149, 152]:
        raise SystemExit("Unexpected portrait source/crop; review before changing anything.")
    source = manifest["sources"][frame["source"]]
    if sha(ART / source["file"]) != source["sha256"]:
        raise SystemExit("Source hash changed.")
    rgba = np.asarray(Image.open(ART / source["file"]).convert("RGBA"))
    labels, _ = label(rgba[:, :, 3] > 99)
    sizes = np.bincount(labels.ravel())
    bodies = {}
    for component_id, region in enumerate(find_objects(labels), 1):
        if region is not None and sizes[component_id] >= 1500:
            yy, xx = region
            bodies[component_id] = [xx.start, yy.start, xx.stop-xx.start, yy.stop-yy.start]
    targets = [i for i, box in bodies.items() if box == [97, 917, 145, 317]]
    if len(bodies) != 16 or len(targets) != 1:
        raise SystemExit("Reviewed body layout no longer matches; do not guess atlas ownership.")
    target = targets[0]
    major = np.where(np.isin(labels, list(bodies)), labels, 0)
    nearest = distance_transform_edt(major == 0, return_distances=False, return_indices=True)
    ownership = major[tuple(nearest)]
    x, y, w, h = frame["region"]
    own = ownership[y:y+h, x:x+w] == target
    alpha = rgba[y:y+h, x:x+w, 3]
    runs = []
    for row, mask in enumerate(own):
        transitions = np.diff(np.r_[False, mask, False].astype(np.int8))
        for start, end in zip(np.flatnonzero(transitions == 1), np.flatnonzero(transitions == -1)):
            runs.append([row, int(start), int(end-start)])
    yy, xx = np.where((alpha > 99) & own)
    expected_bounds = [int(xx.min()), int(yy.min()), int(xx.max()-xx.min()+1), int(yy.max()-yy.min()+1)]
    target_primary = labels[y:y+h, x:x+w] == target
    retained = int(np.count_nonzero((alpha > 99) & own))
    excluded = int(np.count_nonzero((alpha > 99) & ~own))
    if np.any(target_primary & ~own) or excluded <= 0:
        raise SystemExit("Ownership does not preserve Bai Sheng's complete primary pixels.")

    HISTORY.mkdir(parents=True, exist_ok=False)
    archive_paths = {}
    for relative in [PORTRAIT, "web_art_manifest.json", "web_art_slice_qa.json",
                     "web_art_contract_qa.json", "web_carry_prior_pngs.json"]:
        dest = HISTORY / Path(relative).name
        shutil.copyfile(ART / relative, dest)
        archive_paths[relative] = {"file": str(dest.relative_to(ART)).replace("\\", "/"), "sha256": sha(dest)}
    shutil.copyfile(Path(__file__).with_name("campaign_web_art_contract.py"), HISTORY / "campaign_web_art_contract_before.py")
    snapshot = current_pngs()
    write_json(HISTORY / "runtime_png_sha256.json", snapshot)
    record = {
        "revision_id": "web_bai_portrait_atlas_ownership_20260831",
        "status": "prepared_not_yet_rebuilt",
        "authorization": "Parent explicitly authorized only portraits/hn_bai_sheng.png after runtime review of an opaque foreign golden arc; no other image changes authorized.",
        "allowed_output": PORTRAIT,
        "before_sha256": OLD_SHA,
        "after_sha256": None,
        "history": archive_paths,
        "runtime_snapshot": {"file": str((HISTORY / "runtime_png_sha256.json").relative_to(ART)).replace("\\", "/"),
                             "sha256": sha(HISTORY / "runtime_png_sha256.json"), "count": len(snapshot)},
        "before_defect": {"alpha_threshold": 8, "pixels": 389, "max_alpha": 255, "bbox_end": [15, 10, 60, 21],
                          "attribution": "Foot pixels from the preceding Ruan Xiaoqi SE row leaked into the raw rectangular head crop."},
        "source": {"id": frame["source"], "file": source["file"], "sha256": source["sha256"],
                   "primary_component_id": target, "primary_bbox_xywh": bodies[target],
                   "portrait_region_unchanged": frame["region"], "portrait_scale_unchanged": spec["scale"]},
        "method": "Only original source RGBA attributed to Bai Sheng is copied by the normal Godot atlas slicer; same source face/hat/clothes, same crop and scale. No painting, erasing, recoloring or reconstructed hat.",
        "historical_carry_fact": "The archived 1419-check carry report proved all 351 pre-carry PNGs unchanged before this later explicit one-portrait correction. Its frozen baseline is not rewritten.",
    }
    write_json(RECORD, record)
    frame["expected_bounds"] = expected_bounds
    frame["isolation_runs"] = runs
    frame["isolation"] = {
        "method": "nearest large alpha>99 connected-component ownership inside the unchanged head-and-shoulder atlas crop",
        "component_id": target, "retained_visible_pixels": retained,
        "excluded_foreign_visible_pixels": excluded,
        "approval": record["authorization"],
        "revision_record": RECORD.name,
    }
    spec["portrait_scope"] += " Corrected only the authorized Ruan Xiaoqi shoe leak by source-component atlas attribution; full original Bai Sheng hat retained."
    write_json(manifest_path, manifest)
    print(json.dumps({"images_written": 0, "archive": str(HISTORY), "retained_original_pixels": retained,
                      "excluded_foreign_pixels": excluded, "expected_bounds": expected_bounds}, ensure_ascii=False))


if __name__ == "__main__":
    main()
