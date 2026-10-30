"""Collect owned grip-registration QA evidence; preserve full original viewports in the private run."""
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
    states=["push_idle","push_contact_a","push_passing_a","push_contact_b","push_passing_b"]
    for direction in ["se","sw","ne","nw"]:
        canvas=Image.new("RGB",(1750,310),(35,40,45)); draw=ImageDraw.Draw(canvas)
        for i,state in enumerate(states):
            stem="current_"+state+"_"+direction
            im=Image.open(output/(stem+".png")).convert("RGB").crop((430,170,850,510))
            im.thumbnail((350,282));canvas.paste(im,(i*350,25));draw.text((i*350+5,6),stem,fill="white")
        canvas.save(visual/("current_"+direction+".jpg"),quality=94)
    canvas=Image.new("RGB",(1750,620),(35,40,45));draw=ImageDraw.Draw(canvas)
    for row in range(2):
        for i,state in enumerate(states):
            stem=("baseline_nw_push_idle_0" if i==0 else "baseline_nw_push_walk_"+str(i-1)) if row==0 else "current_"+state+"_nw"
            im=Image.open(output/(stem+".png")).convert("RGB").crop((430,170,850,510))
            im.thumbnail((350,282));canvas.paste(im,(i*350,row*310+25));draw.text((i*350+5,row*310+6),stem,fill="white")
    canvas.save(visual/"nw_before_after.jpg",quality=94)
    canvas=Image.new("RGB",(1280,780),(35,40,45));draw=ImageDraw.Draw(canvas)
    for i,stem in enumerate(["hurt_nw","attack_nw","after_real_movement","after_delivery"]):
        im=Image.open(output/(stem+".png")).convert("RGB");im.thumbnail((640,360))
        x,y=i%2*640,i//2*390;canvas.paste(im,(x,y+25));draw.text((x+5,y+6),stem,fill="white")
    canvas.save(visual/"interruptions_motion_delivery.jpg",quality=94)
    for stem in ["baseline_nw_push_walk_2","current_push_contact_b_nw"]:
        copy(output/(stem+".png"),visual/(stem+".png"))
    pair=Image.new("RGB",(840,370),(35,40,45));draw=ImageDraw.Draw(pair)
    for i,stem in enumerate(["baseline_nw_push_walk_2","current_push_contact_b_nw"]):
        im=Image.open(output/(stem+".png")).convert("RGB").crop((430,170,850,510))
        pair.paste(im,(i*420,27));draw.text((i*420+7,7),"BEFORE: old registration" if i==0 else "AFTER: stable grip registration",fill="white")
    pair.save(visual/"contact_b_before_after.jpg",quality=94)
    if args.visual_only:
        print(json.dumps({"viewports":len(rows),"final_source_postcheck_qualified":False})); return
    receipt = json.loads((output / "receipt.json").read_text())
    assert receipt["complete"] and receipt["source_unchanged"] and receipt["children_gone"] and receipt["lock_released"]
    harness_rows=[]
    for item in receipt["qa_inputs"]:
        source=ROOT / item["path"]
        name=source.name[:-4] if source.name.endswith(".tres.txt") else source.name
        executed=output / "harness" / ("baseline" if source.parent.name=="baseline" else "") / name
        assert sha(source)==sha(executed)==item["sha256"]
        harness_rows.append({"original":source.relative_to(ROOT).as_posix(),"executed_copy":executed.relative_to(ROOT).as_posix(),"sha256":sha(executed)})
    assert sha(HERE / "run.py")==receipt["runner_sha256"]
    (evidence / "harness_postcheck.json").write_bytes((json.dumps({"complete":True,"all_current_original_and_executed_harness_copies_match":True,"runner_unchanged":True,"files":harness_rows},indent=2)+"\n").encode())
    target = evidence / output.name
    for name in ["report.json","receipt.json","grip_registration.log"]:
        copy(output / name,target / name)
    for name in ["probe.gd","bootstrap.gd","base.gd"]:
        copy(output / "harness" / name,target / ("executed_"+name+".txt"))
    run = output.parent
    imports = sorted(run.glob("import__*/receipt.json"))
    assert len(imports) == 1
    copy(imports[0],evidence / "import.json")
    copy(run / "preparation.json",evidence / "preparation.json")
    for previous in sorted(run.glob("grip_registration_*")):
        if previous == output or not (previous / "receipt.json").exists(): continue
        failed = json.loads((previous / "receipt.json").read_text())
        if failed.get("complete"): continue
        for name in ["receipt.json", "report.json", "grip_registration.log"]:
            if (previous / name).is_file(): copy(previous / name, evidence / previous.name / name)
        for source in (previous / "harness").glob("*.gd"):
            copy(source, evidence / previous.name / ("executed_"+source.name+".txt"))
    pins = [{"path":p.relative_to(ROOT).as_posix(),"sha256":sha(p),"bytes":p.stat().st_size} for p in [run / name for name in ["root_source.json","preimport_source.json","generation.json"]]]
    (evidence / "source_manifest_pins.json").write_bytes((json.dumps(pins,indent=2)+"\n").encode())
    print(json.dumps({"checks":len(report["checks"]),"viewports":len(rows),"complete":True}))

if __name__ == "__main__": main()
