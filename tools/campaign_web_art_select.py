"""Prepare a reviewed mixed-source atlas plan without writing any image pixels.

Use for independently generated stride/passing views or a replacement view.
The JSON plan explicitly names every complete connected body; merged/cropped
figures are rejected, never repaired by this tool. Rendering remains in Godot.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from types import SimpleNamespace

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, find_objects, label

from campaign_web_art_prepare import ART, MANIFEST, isolate_frame, load_manifest, source_record, upsert, write_json


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    manifest = load_manifest()
    source_data = {}
    for key, source in plan["sources"].items():
        rgba = np.asarray(Image.open(ART / "source" / source["file"]).convert("RGBA"))
        record_args = SimpleNamespace(source=source["file"], prompt=source["prompt_file"], conversation=source["conversation_url"], review=source["review"])
        if not record_args.conversation.startswith("https://chatgpt.com/c/") or "?" in record_args.conversation:
            raise SystemExit("Only stable ChatGPT conversation links may enter provenance.")
        manifest["sources"][key] = source_record(record_args, rgba)
        labels, _ = label(rgba[:, :, 3] > 99)
        counts = np.bincount(labels.ravel())
        components = {}
        for component_id, region in enumerate(find_objects(labels), 1):
            if region is not None and counts[component_id] >= 1500:
                yy, xx = region
                components[(xx.start, yy.start, xx.stop-xx.start, yy.stop-yy.start)] = component_id
        major = np.where(np.isin(labels, list(components.values())), labels, 0)
        nearest = distance_transform_edt(major == 0, return_distances=False, return_indices=True)
        source_data[key] = (rgba, major[tuple(nearest)], components)
        manifest["sources"][key]["selection_plan"] = str(args.plan.name)
    for spec in plan["artifacts"]:
        frames = []
        for selection in spec["frames"]:
            key = selection["source"]
            rgba, ownership, components = source_data[key]
            box = tuple(selection["body_box"])
            if box not in components:
                raise SystemExit(f"Reviewed complete body missing or merged: {key} {box}; regenerate instead of splitting anatomy.")
            x, y, width, height = box
            if min(x, y, rgba.shape[1]-x-width, rgba.shape[0]-y-height) < 1:
                raise SystemExit(f"Reviewed body touches outer source edge: {key} {box}; cannot repair by padding.")
            frame = isolate_frame(rgba, ownership, components[box], list(box))
            frame["source"] = key
            frame["scale"] = selection["scale"]
            frame["pose_review"] = selection["pose_review"]
            frames.append(frame)
        variant, state, direction = spec["variant"], spec["state"], spec["direction"]
        artifact_id = f"{variant}_{state}_{direction}"
        upsert(manifest, {
            "id": artifact_id, "kind": "animation", "variant": variant, "state": state,
            "direction": direction, "canvas_size": 256, "anchor": [0.5, 0.82],
            "scale": 1.0, "frames": frames, "output": f"anim/{artifact_id}.png",
            "motion_scope": spec["motion_scope"],
            "selection_plan": str(args.plan.name),
        })
    write_json(MANIFEST, manifest)
    print(json.dumps({"selected_outputs": len(plan["artifacts"]), "manifest_artifacts": len(manifest["artifacts"]), "images_written": 0}))


if __name__ == "__main__":
    main()
