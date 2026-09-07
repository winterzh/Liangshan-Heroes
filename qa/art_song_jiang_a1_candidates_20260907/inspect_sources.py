"""Read-only PNG/source analysis; emits JSON and never modifies image pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect(path):
    with Image.open(path) as im:
        original_mode = im.mode
        im = im.convert("RGBA")
        a = im.getchannel("A")
        histogram = a.histogram()
        width, height = im.size
        edge = list(a.crop((0, 0, width, 1)).tobytes())
        edge += list(a.crop((0, height - 1, width, height)).tobytes())
        edge += list(a.crop((0, 0, 1, height)).tobytes())
        edge += list(a.crop((width - 1, 0, width, height)).tobytes())
        major = a.point(lambda value: 255 if value > 99 else 0)
        return {
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": sha(path), "bytes": path.stat().st_size,
            "original_mode": original_mode, "size": [width, height],
            "alpha_zero_fraction": histogram[0] / (width * height),
            "alpha_opaque_fraction": histogram[255] / (width * height),
            "alpha_extrema": list(a.getextrema()),
            "alpha_gt_99_fraction": sum(histogram[100:]) / (width * height),
            "alpha_gt_239_fraction": sum(histogram[240:]) / (width * height),
            "alpha_mode_nonzero": max(range(1, 256), key=lambda v: histogram[v]),
            "nonzero_bbox": a.getbbox(), "alpha_gt_99_bbox": major.getbbox(),
            "border_nonzero_count": sum(v > 0 for v in edge),
            "border_major_count": sum(v > 99 for v in edge),
            "corners_rgba": [im.getpixel(p) for p in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]],
            "no_pixel_changes_performed": True,
        }


def main():
    prior = json.loads((ROOT / "qa/stabilization_art_a1_brief_20260907/inputs.json").read_text(encoding="utf-8"))
    references = []
    for ref in prior["inputs"]:
        if "song_jiang" not in ref["relative_path"]:
            continue
        path = ROOT / ref["relative_path"]
        actual = sha(path)
        references.append({"path": ref["relative_path"], "expected_sha256": ref["sha256"], "actual_sha256": actual, "matches": actual == ref["sha256"]})
    sources = [inspect(p) for p in sorted((HERE / "source").glob("*.png"))]
    print(json.dumps({"scope": "PNG alpha, bounds and original reference hashes only; not gameplay or production approval", "references": references, "all_reference_hashes_match": all(r["matches"] for r in references), "sources": sources}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
