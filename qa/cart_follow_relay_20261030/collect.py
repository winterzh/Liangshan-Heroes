"""Collect owned cart-follow / relay QA evidence; preserve full original viewports in the private run."""
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
    owners=["ruan_xiaoqi","gongsun_sheng","wu_yong"]
    for owner in owners:
        canvas=Image.new("RGB",(840,370),(35,40,45));draw=ImageDraw.Draw(canvas)
        for i,stem in enumerate(["receiver_old_cache_"+owner,"receiver_inherited_"+owner]):
            im=Image.open(output/(stem+".png")).convert("RGB").crop((430,170,850,510))
            canvas.paste(im,(i*420,27));draw.text((i*420+5,7),"OLD RECEIVER CACHE (fixture)" if i==0 else "ORIGINAL CART PHASE (actual callback)",fill="white")
        canvas.save(visual/("relay_"+owner+".jpg"),quality=94)
    names=["empty_cart_after_detour","empty_cart_after_real_walk","drop_chao_gai","drop_ruan_xiaoqi","drop_gongsun_sheng","final_original_cart"]
    canvas=Image.new("RGB",(1280,1170),(35,40,45));draw=ImageDraw.Draw(canvas)
    for i,stem in enumerate(names):
        im=Image.open(output/(stem+".png")).convert("RGB");im.thumbnail((640,360))
        x,y=i%2*640,i//2*390;canvas.paste(im,(x,y+25));draw.text((x+5,y+6),stem,fill="white")
    canvas.save(visual/"follow_drops_delivery.jpg",quality=94)
    for stem in ["receiver_old_cache_ruan_xiaoqi","receiver_inherited_ruan_xiaoqi"]:
        copy(output/(stem+".png"),visual/(stem+".png"))
    if args.visual_only:
        print(json.dumps({"viewports":len(rows),"final_source_postcheck_qualified":False})); return
    receipt = json.loads((output / "receipt.json").read_text())
    assert receipt["complete"] and receipt["source_unchanged"] and receipt["children_gone"] and receipt["lock_released"]
    target = evidence / output.name
    for name in ["report.json","receipt.json","cart_follow_relay.log"]:
        copy(output / name,target / name)
    for name in ["probe.gd","bootstrap.gd","base.gd"]:
        copy(output / "harness" / name,target / ("executed_"+name+".txt"))
    run = output.parent
    imports = sorted(run.glob("import__*/receipt.json"))
    assert len(imports) == 1
    copy(imports[0],evidence / "import.json")
    copy(run / "preparation.json",evidence / "preparation.json")
    for previous in sorted(run.glob("cart_follow_relay_*")):
        if previous == output or not (previous / "receipt.json").exists(): continue
        failed = json.loads((previous / "receipt.json").read_text())
        if failed.get("complete"): continue
        for name in ["receipt.json", "report.json", "cart_follow_relay.log"]:
            if (previous / name).is_file(): copy(previous / name, evidence / previous.name / name)
        for source in (previous / "harness").glob("*.gd"):
            copy(source, evidence / previous.name / ("executed_"+source.name+".txt"))
        if (previous / "report.json").exists():
            failed_report=json.loads((previous / "report.json").read_text())
            inventory=[]
            for row in failed_report.get("screenshots",[]):
                original=previous / row["path"]
                assert sha(original)==row["sha256"]
                inventory.append({**row,"original_path":original.relative_to(ROOT).as_posix(),"bytes":original.stat().st_size})
            (evidence / previous.name / "screenshot_inventory.json").write_bytes((json.dumps(inventory,indent=2)+"\n").encode())
    pins = [{"path":p.relative_to(ROOT).as_posix(),"sha256":sha(p),"bytes":p.stat().st_size} for p in [run / name for name in ["root_source.json","preimport_source.json","generation.json"]]]
    (evidence / "source_manifest_pins.json").write_bytes((json.dumps(pins,indent=2)+"\n").encode())
    print(json.dumps({"checks":len(report["checks"]),"viewports":len(rows),"complete":True}))

if __name__ == "__main__": main()
