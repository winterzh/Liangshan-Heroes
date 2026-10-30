"""Collect owned source-QA receipts and review-only before/after sheets."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OWNERS = ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi"]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists(): shutil.copyfile(source, target)
    assert sha(source) == sha(target)

def collect_visuals(output, report):
    rows = []
    for row in report["screenshots"]:
        path = output / row["path"]
        assert sha(path) == row["sha256"]
        rows.append({**row, "original_path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size})
    evidence = HERE / "evidence"
    evidence.mkdir(exist_ok=True)
    (evidence / "screenshot_inventory.json").write_bytes((json.dumps(rows, indent=2)+"\n").encode())
    visual = HERE / "visual"
    visual.mkdir(exist_ok=True)
    pairs = [("handoff_"+d, ["handoff_"+d+"_before", "handoff_"+d+"_after"]) for d in ["se", "sw", "ne", "nw"]]
    pairs += [("delivery_"+owner, [owner+"_loaded", owner+"_released"]) for owner in OWNERS]
    for name, files in pairs:
        canvas = Image.new("RGB", (1000, 420), (35, 40, 45))
        draw = ImageDraw.Draw(canvas)
        for i, stem in enumerate(files):
            source = output / (stem+".png")
            im = Image.open(source).convert("RGB").crop((340, 90, 940, 560))
            im.thumbnail((500, 390))
            canvas.paste(im, (i*500, 28))
            label = stem + (" (Wu relay)" if stem.startswith("ruan_xiaoqi_") else "")
            draw.text((i*500+5, 7), label, fill="white")
        canvas.save(visual / (name+".jpg"), quality=93)
    for name in ["gongsun_sheng_released.png", "ruan_xiaoqi_released.png"]:
        copy(output / name, visual / name)
    return rows

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--visual-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / ".godot/huangnigang_production_20261020")
    report = json.loads((output / "report.json").read_text())
    assert report["passed"] and not report["failures"]
    images = collect_visuals(output, report)
    if args.visual_only:
        print(json.dumps({"visuals": len(images), "final_source_postcheck_qualified": False}))
        return
    receipt = json.loads((output / "receipt.json").read_text())
    assert receipt["complete"] and receipt["source_unchanged"] and receipt["children_gone"] and receipt["lock_released"]
    evidence = HERE / "evidence" / output.name
    for name in ["report.json", "receipt.json", "transport_visuals.log"]:
        copy(output / name, evidence / name)
    for name in ["probe.gd", "bootstrap.gd", "base.gd"]:
        copy(output / "harness" / name, evidence / ("executed_"+name+".txt"))
    for path in output.glob("checkpoint_*.json"):
        copy(path, evidence / path.name)
    run = output.parent
    imports = sorted(run.glob("import__*/receipt.json"))
    assert len(imports) == 1
    copy(imports[0], HERE / "evidence/import.json")
    copy(run / "preparation.json", HERE / "evidence/preparation.json")
    copy(ROOT / ".godot/huangnigang_production_20261020/20261030_192354_99af965c/preparation.json", HERE / "evidence/initial_preparation_failed.json")
    pins = [{"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path), "bytes": path.stat().st_size}
            for path in [run / name for name in ["root_source.json", "preimport_source.json", "generation.json"]]]
    (HERE / "evidence/source_manifest_pins.json").write_bytes((json.dumps(pins, indent=2)+"\n").encode())
    print(json.dumps({"checks": len(report["checks"]), "viewports": len(images), "complete": True}))

if __name__ == "__main__":
    main()
