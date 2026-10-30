"""Collect owned person-label QA evidence; preserve full original viewports in the private run."""
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
    parser.add_argument("--primary", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / ".godot/huangnigang_production_20261020")
    report = json.loads((output / "report.json").read_text())
    assert report["passed"] and not report["failures"]
    primary = args.primary.resolve()
    assert primary.parent == output.parent and primary != output
    primary_report = json.loads((primary / "report.json").read_text())
    expected_failures = ["dense_en_960: actual rendered identities include every wanted live person", "dense_en_960: exact authored locale name bai_sheng"]
    assert primary_report["failures"] == expected_failures
    assert report["supersedes_only_primary_assertions"] == expected_failures
    rows = []
    for source, source_report in [(primary, primary_report), (output, report)]:
      for row in source_report["screenshots"]:
        path = source / row["path"]
        assert sha(path) == row["sha256"]
        rows.append({**row, "original_path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size})
    evidence, visual = HERE / "evidence", HERE / "visual"
    evidence.mkdir(exist_ok=True); visual.mkdir(exist_ok=True)
    (evidence / "screenshot_inventory.json").write_bytes((json.dumps(rows, indent=2)+"\n").encode())
    # Contact sheets are labelled review artifacts; source PNGs remain unchanged.
    groups={"dense_1280":["dense_"+locale+"_1280" for locale in ["zh_CN","zh_TW","en","ja"]],
            "dense_960":["dense_"+locale+"_960" for locale in ["zh_CN","zh_TW","en","ja"]],
            "zoom_and_controls":["wide_zoom_out","normal_zoom_out","far_zoom_out","selected_and_hurt","hostile_inspection","healthbars_disabled","paused_camera"],
            "cart_and_status":["loaded_cart_clearance","people_and_cart","resolved_original_status"],
            "capacity_supplement":["saturated_english_960","selected_bai_960","english_960_messages_hidden"]}
    for name,files in groups.items():
        canvas=Image.new("RGB",(1280,((len(files)+1)//2)*390),(35,40,45));draw=ImageDraw.Draw(canvas)
        for i,stem in enumerate(files):
            im=Image.open((output if name=="capacity_supplement" else primary)/(stem+".png")).convert("RGB");im.thumbnail((640,360))
            x,y=i%2*640,i//2*390;canvas.paste(im,(x,y+25));draw.text((x+5,y+6),stem,fill="white")
        canvas.save(visual/(name+".jpg"),quality=94)
    pair=Image.new("RGB",(1280,390),(35,40,45));draw=ImageDraw.Draw(pair)
    for i,stem in enumerate(["world_fallback_fixture","overlay_activation"]):
        im=Image.open(primary/(stem+".png")).convert("RGB");im.thumbnail((640,360))
        pair.paste(im,(i*640,25));draw.text((i*640+5,6),"WORLD LABEL FALLBACK (same-source fixture)" if i==0 else "PERSON/CART SHARED SCREEN LABELS",fill="white")
    pair.save(visual/"before_after.jpg",quality=94)
    for stem in ["dense_en_960","people_and_cart"]:
        copy(primary/(stem+".png"),visual/(stem+".png"))
    if args.visual_only:
        print(json.dumps({"viewports":len(rows),"final_source_postcheck_qualified":False})); return
    receipt = json.loads((output / "receipt.json").read_text())
    assert receipt["complete"] and receipt["source_unchanged"] and receipt["children_gone"] and receipt["lock_released"]
    harness_rows=[]
    for item in receipt["qa_inputs"]:
        source=ROOT / item["path"];executed=output / "harness" / source.name
        assert sha(source)==sha(executed)==item["sha256"]
        harness_rows.append({"original":source.relative_to(ROOT).as_posix(),"executed_copy":executed.relative_to(ROOT).as_posix(),"sha256":sha(executed)})
    assert sha(HERE / "run.py")==receipt["runner_sha256"]
    old_receipt=json.loads((primary / "receipt.json").read_text())
    assert old_receipt["lock_released"] and old_receipt["steps"][0]["exit_code"]==1 and not old_receipt["steps"][0]["errors"]
    assert sha(evidence / "primary_executed_runner.py.txt")==old_receipt["runner_sha256"]
    for item in old_receipt["qa_inputs"]:
        original=ROOT / item["path"]; executed=primary / "harness" / original.name
        assert sha(original)==sha(executed)==item["sha256"]
    (evidence / "harness_postcheck.json").write_bytes((json.dumps({"complete":True,"original_and_executed_harness_inputs_match":True,"runner_unchanged":True,"files":harness_rows},indent=2)+"\n").encode())
    target = evidence / output.name
    for name in ["report.json","receipt.json","person_captions.log"]:
        copy(output / name,target / name)
    for name in ["probe.gd","capacity_probe.gd","bootstrap.gd","base.gd"]:
        copy(output / "harness" / name,target / ("executed_"+name+".txt"))
    run = output.parent
    imports = sorted(run.glob("import__*/receipt.json"))
    assert len(imports) == 1
    copy(imports[0],evidence / "import.json")
    copy(run / "preparation.json",evidence / "preparation.json")
    for previous in sorted(run.glob("person_captions_*")):
        if previous == output or not (previous / "receipt.json").exists(): continue
        failed = json.loads((previous / "receipt.json").read_text())
        if failed.get("complete"): continue
        for name in ["receipt.json", "report.json", "person_captions.log"]:
            if (previous / name).is_file(): copy(previous / name, evidence / previous.name / name)
        for source in (previous / "harness").glob("*.gd"):
            copy(source, evidence / previous.name / ("executed_"+source.name+".txt"))
    pins = [{"path":p.relative_to(ROOT).as_posix(),"sha256":sha(p),"bytes":p.stat().st_size} for p in [run / name for name in ["root_source.json","preimport_source.json","generation.json"]]]
    (evidence / "source_manifest_pins.json").write_bytes((json.dumps(pins,indent=2)+"\n").encode())
    print(json.dumps({"primary_checks":len(primary_report["checks"]),"primary_passed_checks":len(primary_report["checks"])-2,"supplement_checks":len(report["checks"]),"viewports":len(rows),"complete":True}))

if __name__ == "__main__": main()
