"""Bind reviewed native web PNGs without editing pixels or borrowing bodies.

Default validates only; --write creates new owner families. Pose source keys
are retained, including Gongsun Sheng's SE-only passing-B-v2 selection.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools"))
import build_directional_spriteframes as renderer
from build_ruan_xiaoqi_pushcart_20261018 import import_descriptor

spec = importlib.util.spec_from_file_location("liu_resource_metadata", ROOT / "qa/liu_tang_layered_20261030/build_resources.py")
metadata = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metadata)
OWNERS = ["gongsun_sheng", "ruan_xiaoer", "ruan_xiaowu"]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def intended(owner, selection):
    family = owner + "_layered_20261030"
    old = json.loads((ROOT / f"assets/direction4/level1_{owner}_pushcart_20261017.json").read_text())
    expected = set(old["sources"]) - {"cart_only"}
    assert set(selection) == expected
    sources = {"cart_only": copy.deepcopy(old["sources"]["cart_only"])}
    poses = copy.deepcopy(old["poses"])
    for key in sorted(expected):
        binding = selection[key]
        assert binding["reviewed_actor_only"]
        image_path = ROOT / binding["path"]
        assert sha(image_path) == binding["sha256"]
        with Image.open(image_path) as image:
            assert image.mode == "RGBA" and list(image.size) == old["sources"][key]["native_size"]
            alpha = np.asarray(image)[:, :, 3]
            assert int(alpha.min()) == 0
        sources[key] = {"path": f"assets/characters/{family}/{key}.png",
                        "candidate_origin": binding["path"], "sha256": binding["sha256"],
                        "native_size": list(image.size), "imported_size": list(image.size)}
        for pose_key, pose in poses.items():
            if pose["source"] != key:
                continue
            pose["independent_cart"] = True
            x, y, w, h = pose["region"]
            ys, xs = np.nonzero(alpha[y:y+h, x:x+w] >= 64)
            assert len(xs) > 1000 and int(ys.min()) > 0 and int(ys.max()) < h-1, pose_key
            pose["visible_top"] = (pose["margin"][1] + int(ys.min())) / (w + pose["margin"][2])
            pose["draw_offset_px"] = binding.get("registration", {}).get(pose_key.rsplit("_", 1)[1], [0, 0])
            pose["operations"] = "Untouched sidebar ChatGPT actor-only PNG; original own per-phase pose registration; fixed cart drawn separately."
    for direction in renderer.DIRECTIONS:
        pose = poses["cart_only_" + direction]
        pose["independent_cart"] = False
        with Image.open(ROOT / sources["cart_only"]["path"]) as image:
            alpha = np.asarray(image)[:, :, 3]
        x, y, w, h = pose["region"]
        ys, _ = np.nonzero(alpha[y:y+h, x:x+w] >= 64)
        pose["visible_top"] = (pose["margin"][1] + int(ys.min())) / (w + pose["margin"][2])
    return {"schema": "native_direction4_spriteframes_v1", "character": family,
            "body_owner": owner, "sources": sources, "poses": poses, "states": old["states"],
            "resources": [f"assets/anim/{family}_{state}_{direction}.tres" for state in old["states"] for direction in renderer.DIRECTIONS],
            "wheel_offsets_per_body_size": old["wheel_offsets_per_body_size"],
            "canonical_cart_geometry": old.get("canonical_cart_geometry", {}),
            "source_workflow": "ChatGPT web in Codex sidebar; native PNG bytes preserved",
            "runtime_acceptance": "See qa/remaining_carriers_layered_20261030/README.md; metadata is not a runtime pass",
            "canon": "Chapter16 seven Jiangzhou carts carry eleven loads. Existing own merchant identity retained; exact colours, hand/foot animation and cart construction are game art interpretations."}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    selection = json.loads((HERE / "selection.json").read_text())
    counts = {}
    for owner in OWNERS:
        manifest = intended(owner, selection[owner])
        family = manifest["character"]
        manifest_path = ROOT / f"assets/direction4/level1_{family}.json"
        if args.write:
            assert not manifest_path.exists(), "Never overwrite an adopted family"
            runtime = ROOT / "assets/characters" / family
            assert not runtime.exists(), "Refuse unreviewed partial output"
            runtime.mkdir()
            for key, row in manifest["sources"].items():
                if key == "cart_only": continue
                dest = ROOT / row["path"]
                shutil.copyfile(ROOT / row["candidate_origin"], dest)
                assert sha(dest) == row["sha256"]
                import_descriptor(dest)
            output = metadata.outputs(manifest)
            for path, data in output.items():
                assert not (ROOT / path).exists()
                (ROOT / path).write_bytes(data)
            manifest_path.write_bytes((json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode())
        else:
            output = metadata.outputs(manifest)
        assert json.loads(manifest_path.read_text()) == manifest
        for path, data in output.items(): assert (ROOT / path).read_bytes() == data
        counts[owner] = {"native_actor_pngs": len(manifest["sources"])-1, "spriteframes": len(output)}
    print(json.dumps({"families": counts, "runtime_tested_by_builder": False}))

if __name__ == "__main__":
    main()
