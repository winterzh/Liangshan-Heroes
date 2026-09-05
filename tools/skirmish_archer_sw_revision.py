"""Scoped, reproducible SW archer replacement. No drawing, mirroring or alpha edits."""
from __future__ import annotations
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "qa/skirmish_direction4_fix_20260905"
SOURCE = QA / "source/archer_sw_idle_step_raw.png"
MANIFEST = ROOT / "assets/direction4/skirmish_archer_sw_revision_20260905.json"
TARGETS = tuple(f"guan_gong_{s}_sw.png" for s in ("idle", "walk", "attack", "death"))
STAGE = QA / "archer_stage"
BACKUP = QA / "archer_before"
BASE_HASHES = {
    "guan_gong_idle_sw.png": "e846831dbc685245565653fd3331ba8bd3ce0784317da512c0ba7426dd8f4959",
}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf8")

def build() -> dict:
    source = Image.open(SOURCE)
    assert source.mode == "RGBA" and source.size == (1774, 887)
    # Complete alpha bounding rectangles, including weak alpha; never erase pixels.
    crops = [source.crop((0, 0, 887, 887)), source.crop((887, 0, 1774, 887))]
    bboxes = [im.getchannel("A").getbbox() for im in crops]
    scale = min(198 / 653, *(248 / max(b[2]-b[0], b[3]-b[1]) for b in bboxes))
    # Visually reviewed ground pivots: torso axis projected to lowest planted boot.
    # These are virtual ground points, not claims of an opaque pixel at that point.
    pivots = [(510, 799), (463, 810)]
    normalized = []
    placements = {}
    STAGE.mkdir(parents=True, exist_ok=True)
    for pose, cell, bb, pivot in zip(("idle", "walk_step"), crops, bboxes, pivots):
        body = cell.crop(bb)
        resized = body.resize((round(body.width*scale), round(body.height*scale)), Image.Resampling.LANCZOS)
        desired = (128-round((pivot[0]-bb[0])*scale), 210-round((pivot[1]-bb[1])*scale))
        xy = (max(4, min(desired[0], 252-resized.width)), max(4, min(desired[1], 252-resized.height)))
        image = Image.new("RGBA", (256,256), (0,0,0,0))
        image.paste(resized, xy) # unmasked paste preserves resized RGBA exactly
        image.save(STAGE / f"{pose}.png")
        normalized.append(image)
        placements[pose] = {"crop_in_half": list(bb), "half_x": 0 if pose == "idle" else 887,
            "virtual_ground_pivot_in_half": list(pivot), "scale": scale, "paste_xy": list(xy),
            "fit_shift_xy_px": [xy[0]-desired[0], xy[1]-desired[1]],
            "alpha_bbox": list(image.getchannel("A").getbbox())}
    old_dir = BACKUP if BACKUP.exists() else ROOT / "assets/anim"
    inputs = {}
    for name in TARGETS:
        path = old_dir / name
        inputs[name] = sha(path)
        if name in BASE_HASHES: assert inputs[name] == BASE_HASHES[name]
    original = json.loads((ROOT / "assets/direction4/skirmish_top4_actions_direction4_manifest.json").read_text(encoding="utf8"))
    for row in original["outputs"]:
        if row["target"] in inputs: assert inputs[row["target"]] == row["sha256"]
    idle, step = normalized
    originals = {s: Image.open(old_dir / f"guan_gong_{s}_sw.png") for s in ("attack", "death")}
    recipes = {
        "idle": [idle], "walk": [idle, step],
        "attack": [idle, originals["attack"].crop((256,0,512,256)), idle],
        "death": [idle] + [originals["death"].crop((i*256,0,(i+1)*256,256)) for i in range(1,4)],
    }
    outputs = []
    for state, frames in recipes.items():
        strip = Image.new("RGBA", (256*len(frames),256), (0,0,0,0))
        for i, frame in enumerate(frames): strip.paste(frame,(i*256,0))
        name = f"guan_gong_{state}_sw.png"
        strip.save(STAGE / name)
        outputs.append({"target": name, "state": state, "unit": "guan_gong", "direction": "sw",
            "before_sha256": inputs[name], "sha256": sha(STAGE / name), "frame_count": len(frames)})
    record = {"schema_version": 1, "kind": "skirmish_archer_sw_visual_revision", "status": "staged",
        "conversation": "https://chatgpt.com/c/6a9aa67d-22a0-83e9-aeb6-0237a7882356",
        "source": {"file": SOURCE.relative_to(ROOT).as_posix(), "sha256": sha(SOURCE)},
        "prompt": {"file": "qa/skirmish_direction4_fix_20260905/source/01_archer_sw_prompt.txt",
                   "sha256": sha(QA / "source/01_archer_sw_prompt.txt")},
        "base_action_manifest_sha256": sha(ROOT / "assets/direction4/skirmish_top4_actions_direction4_manifest.json"),
        "processing": "two equal source halves; complete alpha bounding crop; shared scale; virtual ground pivot; unmasked RGBA placement; exact strip assembly; no reflection, alpha clearing, repaint or color correction",
        "placements": placements, "outputs": outputs,
        "visual_review": "Assistant reviewed left-facing nose/chest/boots in both poses; not user visual approval",
        "retained_frames": "attack strike and death fall/down remain byte-identical RGBA to original strips"}
    save_json(STAGE / "revision.json", record)
    return record

def commit() -> None:
    record = build()
    assert not MANIFEST.exists(), "Revision already exists; use verify instead of overwriting history"
    baseline = {p.name: sha(p) for p in (ROOT / "assets/anim").glob("*.png")}
    for out in record["outputs"]:
        assert baseline[out["target"]] == out["before_sha256"], "Target changed since baseline"
    BACKUP.mkdir(parents=True, exist_ok=False)
    save_json(QA / "archer_anim_baseline.json", baseline)
    for name in TARGETS: shutil.copy2(ROOT / "assets/anim" / name, BACKUP / name)
    try:
        for name in TARGETS: shutil.copy2(STAGE / name, ROOT / "assets/anim" / name)
        record["status"] = "committed"
        save_json(MANIFEST, record)
        verify()
    except Exception:
        for name in TARGETS: shutil.copy2(BACKUP / name, ROOT / "assets/anim" / name)
        raise

def verify() -> dict:
    record = json.loads(MANIFEST.read_text(encoding="utf8"))
    rebuilt = build()
    assert record["source"] == rebuilt["source"]
    assert record["prompt"] == rebuilt["prompt"]
    assert record["placements"] == rebuilt["placements"]
    assert record["outputs"] == rebuilt["outputs"]
    assert record["status"] == "committed"
    for row in record["outputs"]: assert sha(ROOT / "assets/anim" / row["target"]) == row["sha256"]
    baseline = json.loads((QA / "archer_anim_baseline.json").read_text(encoding="utf8"))
    current = {p.name: sha(p) for p in (ROOT / "assets/anim").glob("*.png")}
    changed = {k for k in baseline if baseline[k] != current[k]}
    assert set(current) == set(baseline) and changed == set(TARGETS)
    result = {"passed": True, "changed": sorted(changed), "unchanged": len(current)-4,
              "source_pixels_modified": False, "retained_attack_death_frames_rebuilt_exactly": True}
    save_json(QA / "archer_revision_verify.json", result)
    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("stage", "commit", "verify"))
    args = parser.parse_args()
    if args.mode == "stage": print(json.dumps(build(), ensure_ascii=False, indent=2))
    elif args.mode == "commit": commit(); print(json.dumps(verify(), ensure_ascii=False))
    else: print(json.dumps(verify(), ensure_ascii=False))
