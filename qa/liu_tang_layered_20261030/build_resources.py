"""Bind reviewed sidebar-web originals to Liu Tang's own cart registration.

No image pixels are generated, masked, mirrored or rewritten here. Default is
read-only; --write creates this new family's exact PNG copies and SpriteFrames.
"""
import argparse
import copy
import hashlib
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

FAMILY = "liu_tang_layered_20261030"
MANIFEST = ROOT / f"assets/direction4/level1_{FAMILY}.json"
RUNTIME = ROOT / "assets/characters" / FAMILY


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def intended():
    requests = json.loads((HERE / "requests.json").read_text(encoding="utf-8"))
    selected = json.loads((HERE / "selection.json").read_text(encoding="utf-8"))
    old = json.loads((ROOT / "assets/direction4/level1_liu_tang_pushcart_20261017.json").read_text(encoding="utf-8"))
    assert requests["owner"] == "liu_tang" and selected["owner"] == "liu_tang"
    assert set(selected["poses"]) == set(old["states"]["push_walk"] + ["push_idle"])
    sources = {"cart_only": copy.deepcopy(old["sources"]["cart_only"])}
    poses = copy.deepcopy(old["poses"])
    for state, binding in selected["poses"].items():
        assert binding["reviewed_actor_only"], "Review each generated actor before binding"
        source = ROOT / binding["path"]
        assert source.is_file() and sha(source) == binding["sha256"]
        with Image.open(source) as image:
            alpha = np.asarray(image)[:, :, 3]
            assert image.mode == "RGBA" and image.getextrema()[3][0] == 0
            # Preserve the existing per-frame hand/wheel registration. A changed
            # canvas needs an explicitly reviewed mapping, never guessed crops.
            expected = old["sources"][state]["native_size"]
            assert list(image.size) == expected, "Review a changed native canvas before integration"
        sources[state] = {"path": f"assets/characters/{FAMILY}/{state}.png",
                          "candidate_origin": binding["path"], "sha256": binding["sha256"],
                          "native_size": expected, "imported_size": expected}
        for direction in renderer.DIRECTIONS:
            pose = poses[f"{state}_{direction}"]
            pose["independent_cart"] = True
            x, y, w, h = pose["region"]
            ys, xs = np.nonzero(alpha[y:y+h, x:x+w] >= 64)
            assert len(xs) > 1000 and int(ys.min()) > 0 and int(ys.max()) < h-1
            pose["visible_top"] = (pose["margin"][1] + int(ys.min())) / (w + pose["margin"][2])
            pose["operations"] = "Untouched sidebar ChatGPT actor-only PNG; original Liu per-phase pose registration; fixed cart drawn separately."
            adjustment = binding.get("registration", {}).get(direction, [0, 0])
            assert len(adjustment) == 2
            pose["draw_offset_px"] = adjustment
    for direction in renderer.DIRECTIONS:
        pose = poses[f"cart_only_{direction}"]
        pose["independent_cart"] = False
        with Image.open(ROOT / sources["cart_only"]["path"]) as image:
            alpha = np.asarray(image)[:, :, 3]
        x, y, w, h = pose["region"]
        ys, _ = np.nonzero(alpha[y:y+h, x:x+w] >= 64)
        pose["visible_top"] = (pose["margin"][1] + int(ys.min())) / (w + pose["margin"][2])
    return {"schema": "native_direction4_spriteframes_v1", "character": FAMILY,
            "body_owner": "liu_tang", "sources": sources, "poses": poses,
            "states": old["states"], "resources": [
                f"assets/anim/{FAMILY}_{state}_{direction}.tres"
                for state in old["states"] for direction in renderer.DIRECTIONS],
            "wheel_offsets_per_body_size": old["wheel_offsets_per_body_size"],
            "canonical_cart_geometry": old.get("canonical_cart_geometry", {}),
            "source_workflow": "ChatGPT web in Codex sidebar; native PNG bytes preserved",
            "runtime_acceptance": "See qa/liu_tang_layered_20261030/README.md; source metadata is not a runtime pass",
            "canon": "Chapter16 seven Jiangzhou carts carry eleven loads. Existing Liu Tang merchant identity and game gait retained. Single-wheel construction, exact colours and hand/foot animation are game art interpretations."}


def outputs(manifest):
    result = renderer.render(manifest)
    for name, text in result.items():
        for key, pose in manifest["poses"].items():
            marker = f'[sub_resource type="AtlasTexture" id="{key}"]\n'
            if marker in text:
                metadata = (f'metadata/visible_top = {pose["visible_top"]:.9f}\n'
                            f'metadata/independent_cart = {str(pose["independent_cart"]).lower()}\n')
                text = text.replace(marker, marker + metadata)
        result[name] = text.encode()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    manifest = intended()
    if args.write:
        assert not MANIFEST.exists(), "Never overwrite an existing adopted family"
        if RUNTIME.exists():
            expected = {name for state in manifest["states"]["push_walk"] + ["push_idle"]
                        for name in [state + ".png", state + ".png.import"]}
            assert {p.name for p in RUNTIME.iterdir()} == expected, "Only resume exact incomplete PNG-copy preparation"
        else:
            RUNTIME.mkdir()
        for key, row in manifest["sources"].items():
            if key == "cart_only":
                continue
            path = ROOT / row["path"]
            if not path.exists(): shutil.copyfile(ROOT / row["candidate_origin"], path)
            assert sha(path) == row["sha256"]
            import_descriptor(path)
        for name, raw in outputs(manifest).items():
            path = ROOT / name
            assert not path.exists()
            path.write_bytes(raw)
        MANIFEST.write_bytes((json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode())
    assert json.loads(MANIFEST.read_text(encoding="utf-8")) == manifest
    for name, raw in outputs(manifest).items():
        assert (ROOT / name).read_bytes() == raw
    print(json.dumps({"owner": "liu_tang", "actor_pngs": 5, "spriteframes": 12,
                      "builder_changes_routing": False, "native_tested": False}))


if __name__ == "__main__":
    main()
