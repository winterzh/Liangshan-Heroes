"""Read PNG geometry and write web atlas cutting instructions. Never writes image pixels.

Each retained atlas run copies original RGBA in Godot. The component ownership cut
only prevents another independent figure from leaking into a rectangular cell.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, find_objects, label

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets/campaign"
MANIFEST = ART / "web_art_manifest.json"
BASELINE = ART / "web_art_legacy_baseline.json"
DIRECTIONS = ["se", "sw", "ne", "nw"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not BASELINE.exists():
        protected = [ART / "slice_manifest.json", ART / "slice_qa.json"]
        for folder in ["anim", "portraits", "objects"]:
            protected.extend(sorted((ART / folder).glob("*.png")))
        write_json(BASELINE, {
            "description": "Legacy outputs and full slicer evidence before web assets; must remain byte-identical.",
            "inventory": {"strips": 188, "frames": 312, "objects": 22, "portraits": 20},
            "sha256": {str(p.relative_to(ART)).replace("\\", "/"): sha(p) for p in protected},
        })
    return {
        "schema_version": 1,
        "mode": "User-requested web ChatGPT generation; parent exclusively operates browser. Godot deterministic cutting only.",
        "legacy_baseline": BASELINE.name,
        "sources": {},
        "artifacts": [],
        "counting": "Single idle poses are not animation cycles. Add only built, reviewed and integrated artifacts to runtime inventory.",
    }


def source_record(args: argparse.Namespace, rgba: np.ndarray) -> dict:
    path = ART / "source" / args.source
    a = rgba[:, :, 3]
    ys, xs = np.where(a > 99)
    prompt = ART / args.prompt
    return {
        "file": "source/" + args.source,
        "sha256": sha(path),
        "status": "accepted",
        "generation_mode": "web ChatGPT",
        "conversation_url": args.conversation,
        "prompt_file": args.prompt,
        "prompt_sha256": sha(prompt),
        "review": args.review,
        "size": [int(rgba.shape[1]), int(rgba.shape[0])],
        "alpha_zero": int(np.count_nonzero(a == 0)),
        "alpha_gt99": int(np.count_nonzero(a > 99)),
        "alpha_bounds_xywh": [int(xs.min()), int(ys.min()), int(xs.max()-xs.min()+1), int(ys.max()-ys.min()+1)],
        "retained_rgba": "Original PNG RGBA kept. No recoloring, painted repair, direction mirroring or background replacement.",
    }


def upsert(manifest: dict, artifact: dict) -> None:
    manifest["artifacts"] = [s for s in manifest["artifacts"] if s["id"] != artifact["id"]]
    manifest["artifacts"].append(artifact)


def isolate_frame(rgba: np.ndarray, ownership: np.ndarray, component_id: int, box: list[int]) -> dict:
    x, y, w, h = box
    x0, y0 = max(0, x-3), max(0, y-3)
    x1, y1 = min(rgba.shape[1], x+w+3), min(rgba.shape[0], y+h+3)
    own = ownership[y0:y1, x0:x1] == component_id
    runs = []
    for row, mask in enumerate(own):
        transitions = np.diff(np.r_[False, mask, False].astype(np.int8))
        for start, end in zip(np.flatnonzero(transitions == 1), np.flatnonzero(transitions == -1)):
            runs.append([row, int(start), int(end-start)])
    a = rgba[y0:y1, x0:x1, 3]
    yy, xx = np.where((a > 99) & own)
    return {
        "region": [x0, y0, x1-x0, y1-y0],
        "expected_bounds": [int(xx.min()), int(yy.min()), int(xx.max()-xx.min()+1), int(yy.max()-yy.min()+1)],
        "isolation_runs": runs,
        "isolation": {
            "method": "nearest large alpha>99 connected-component ownership; retain original RGBA runs within body bbox+3",
            "component_id": component_id,
            "excluded_foreign_visible_pixels": int(np.count_nonzero((a > 99) & ~own)),
            "retained_visible_pixels": int(np.count_nonzero((a > 99) & own)),
            "approval": "Parent explicitly approved standard atlas component slicing; never reconstruct missing anatomy or remove a fake checkerboard.",
        },
    }


def prepare_atlas(args: argparse.Namespace, manifest: dict, rgba: np.ndarray, source_id: str) -> None:
    variants = args.variants.split(",")
    row_count = len(variants) * args.frames
    sheet_rows = args.sheet_rows or row_count
    selected_rows = [int(v) for v in args.row_indices.split(",")] if args.row_indices else list(range(row_count))
    if len(selected_rows) != row_count or any(row < 0 or row >= sheet_rows for row in selected_rows):
        raise SystemExit("Reviewed selected rows do not match variant/pose count.")
    labels, _ = label(rgba[:, :, 3] > 99)
    counts = np.bincount(labels.ravel())
    components = []
    for component_id, region in enumerate(find_objects(labels), 1):
        if region is not None and counts[component_id] >= args.minimum_pixels:
            yy, xx = region
            components.append({"id": component_id, "box": [xx.start, yy.start, xx.stop-xx.start, yy.stop-yy.start]})
    if len(components) != sheet_rows*4:
        raise SystemExit(f"Expected {sheet_rows*4} independent bodies; found {len(components)}. Must review source; do not guess or split anatomy.")
    major = np.where(np.isin(labels, [c["id"] for c in components]), labels, 0)
    nearest = distance_transform_edt(major == 0, return_distances=False, return_indices=True)
    ownership = major[tuple(nearest)]
    components.sort(key=lambda c: c["box"][1] + c["box"][3]*0.5)
    rows = [sorted(components[row*4:(row+1)*4], key=lambda c: c["box"][0]) for row in range(sheet_rows)]
    manifest["sources"][source_id]["layout"] = {
        "directions": DIRECTIONS, "rows": [[c["box"] for c in row] for row in rows],
        "variants": variants, "frames_per_direction": args.frames, "state": args.state,
        "row_order": "each variant gets consecutive pose rows; columns are SE/SW/NE/NW",
        "source_global_scale": args.scale,
        "selected_rows_zero_based": selected_rows,
        "unselected_rows_not_used": [row for row in range(sheet_rows) if row not in selected_rows],
    }
    for index, variant in enumerate(variants):
        for col, direction in enumerate(DIRECTIONS):
            frames = []
            for pose in range(args.frames):
                c = rows[selected_rows[index*args.frames + pose]][col]
                frame = isolate_frame(rgba, ownership, c["id"], c["box"])
                frame["source"] = source_id
                frame["scale"] = args.scale
                frames.append(frame)
            artifact_id = f"{variant}_{args.state}_{direction}"
            if args.append_frames:
                previous = next((s for s in manifest["artifacts"] if s["id"] == artifact_id), None)
                if previous is None:
                    raise SystemExit(f"Cannot append pose without reviewed first frame: {artifact_id}")
                # Idempotent append: a repeat replaces only frames from this source.
                frames = [f for f in previous["frames"] if f["source"] != source_id] + frames
            upsert(manifest, {
                "id": artifact_id, "kind": "animation", "variant": variant,
                "state": args.state, "direction": direction, "canvas_size": 256,
                "anchor": [0.5, 0.82], "scale": args.scale,
                "output": f"anim/{artifact_id}.png", "frames": frames,
                "motion_scope": "single fixed pose" if len(frames) == 1 else f"{len(frames)} drawn poses; complete gait only when explicitly verified in source review",
            })
        if args.state == "idle":
            c = rows[selected_rows[index*args.frames]][0]
            x, y, w, h = c["box"]
            portrait_region = [max(0, x-2), max(0, y-2), w+4, int(round(h*0.48))]
            upsert(manifest, {
                "id": variant + "_portrait", "kind": "portrait", "variant": variant,
                "canvas_size": 256, "anchor": [0.5, 0.5],
                "scale": 236.0 / max(portrait_region[2:]), "output": f"portraits/{variant}.png",
                "frames": [{"source": source_id, "region": portrait_region, "allow_source_crop": True}],
                "portrait_scope": "Exact same SE idle head and shoulders; intentional lower crop, no new face or recoloring.",
            })


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--prompt", required=True, help="Path relative to assets/campaign")
    parser.add_argument("--conversation", required=True)
    parser.add_argument("--review", required=True)
    parser.add_argument("--kind", choices=["object", "atlas"], required=True)
    parser.add_argument("--object-id", default="jujube_cart_default")
    parser.add_argument("--variants", default="")
    parser.add_argument("--state", default="idle")
    parser.add_argument("--frames", type=int, default=1)
    parser.add_argument("--scale", type=float, default=0.6)
    parser.add_argument("--minimum-pixels", type=int, default=1500)
    parser.add_argument("--sheet-rows", type=int, default=0)
    parser.add_argument("--row-indices", default="", help="Reviewed zero-based rows selected for poses; never choose them by hashes.")
    parser.add_argument("--append-frames", action="store_true", help="Append independently drawn reviewed poses to matching variant/state/direction.")
    args = parser.parse_args()
    if not args.conversation.startswith("https://chatgpt.com/c/") or "?" in args.conversation:
        raise SystemExit("Only stable ChatGPT conversation URLs are allowed; no signed asset URL.")
    manifest = load_manifest()
    path = ART / "source" / args.source
    rgba = np.asarray(Image.open(path).convert("RGBA"))
    source_id = Path(args.source).stem
    manifest["sources"][source_id] = source_record(args, rgba)
    if args.kind == "object":
        box = manifest["sources"][source_id]["alpha_bounds_xywh"]
        scale = min(450.0 / box[2], 395.0 / box[3])
        upsert(manifest, {
            "id": args.object_id, "kind": "object", "canvas_size": 512,
            "anchor": [0.5, 0.82], "scale": scale,
            "output": "objects/" + args.object_id + ".png",
            "frames": [{"source": source_id, "region": [0, 0, rgba.shape[1], rgba.shape[0]], "expected_bounds": box}],
        })
    else:
        prepare_atlas(args, manifest, rgba, source_id)
    write_json(MANIFEST, manifest)
    print(json.dumps({"source": source_id, "manifest_artifacts": len(manifest["artifacts"]), "images_written": 0}, ensure_ascii=False))


if __name__ == "__main__":
    main()
