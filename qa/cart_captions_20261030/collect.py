"""Collect owned caption-QA evidence; preserve full original viewports in the private run."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent

def sha(path):
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists(): shutil.copyfile(source, target)
    assert sha(source) == sha(target)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--visual-only", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / ".godot/huangnigang_production_20261020")
    report = json.loads((output / "report.json").read_text())
    assert report["passed"] and not report["failures"]
    rows = []
    for row in report["screenshots"]:
        path = output / row["path"]
        assert sha(path) == row["sha256"]
        rows.append({**row, "original_path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size})
    evidence, visual = HERE / "evidence", HERE / "visual"
    evidence.mkdir(exist_ok=True); visual.mkdir(exist_ok=True)
    (evidence / "screenshot_inventory.json").write_bytes((json.dumps(rows, indent=2)+"\n").encode())
    # Contact sheets are labelled review artifacts; source PNGs remain unchanged.
    groups = {"selection": ["quiet_zh_CN", "selected_zh_CN", "inspected_zh_CN", "damaged_zh_CN", "no_healthbar_zh_CN", "paused_pan_zoom_zh_CN"]}
    groups.update({"languages_"+size: ["multi_"+locale+"_"+size for locale in ["zh_CN","zh_TW","en","ja"]] for size in ["1280","1600"]})
    for name, files in groups.items():
        canvas = Image.new("RGB", (1280, ((len(files)+1)//2)*390), (35,40,45))
        draw = ImageDraw.Draw(canvas)
        for i, stem in enumerate(files):
            image = Image.open(output / (stem+".png")).convert("RGB")
            image.thumbnail((640,360))
            x,y = (i%2)*640,(i//2)*390
            canvas.paste(image,(x,y+25)); draw.text((x+5,y+6),stem,fill="white")
        canvas.save(visual / (name+".jpg"),quality=94)
    for stem in ["selected_zh_CN","multi_en_1280"]:
        copy(output / (stem+".png"),visual / (stem+".png"))
    if args.visual_only:
        print(json.dumps({"viewports":len(rows),"final_source_postcheck_qualified":False})); return
    receipt = json.loads((output / "receipt.json").read_text())
    assert receipt["complete"] and receipt["source_unchanged"] and receipt["children_gone"] and receipt["lock_released"]
    target = evidence / output.name
    for name in ["report.json","receipt.json","cart_captions.log"]:
        copy(output / name,target / name)
    for name in ["probe.gd","bootstrap.gd","base.gd"]:
        copy(output / "harness" / name,target / ("executed_"+name+".txt"))
    run = output.parent
    imports = sorted(run.glob("import__*/receipt.json"))
    assert len(imports) == 1
    copy(imports[0],evidence / "import.json")
    copy(run / "preparation.json",evidence / "preparation.json")
    for previous in sorted(run.glob("cart_captions_*")):
        if previous == output or not (previous / "receipt.json").exists(): continue
        failed = json.loads((previous / "receipt.json").read_text())
        if failed.get("complete"): continue
        for name in ["receipt.json", "report.json", "cart_captions.log"]:
            if (previous / name).is_file(): copy(previous / name, evidence / previous.name / name)
        for source in (previous / "harness").glob("*.gd"):
            copy(source, evidence / previous.name / ("executed_"+source.name+".txt"))
    pins = [{"path":p.relative_to(ROOT).as_posix(),"sha256":sha(p),"bytes":p.stat().st_size} for p in [run / name for name in ["root_source.json","preimport_source.json","generation.json"]]]
    (evidence / "source_manifest_pins.json").write_bytes((json.dumps(pins,indent=2)+"\n").encode())
    print(json.dumps({"checks":len(report["checks"]),"viewports":len(rows),"complete":True}))

if __name__ == "__main__": main()
