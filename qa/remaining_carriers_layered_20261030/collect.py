"""Collect exact owned-run evidence and create review-only contact sheets.

Screenshots/native production originals are not rewritten. JPEGs are labelled
review crops only; they do not replace the full original viewport images.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OWNERS = ["gongsun_sheng", "ruan_xiaoer", "ruan_xiaowu"]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        shutil.copyfile(source, destination)
    assert sha(source) == sha(destination)

def initial_partial():
    output = ROOT / ".godot/huangnigang_production_20261020/20261030_182452_fe3de354/transport_visuals_20261030_183312_08dfba7d"
    receipt = json.loads((output / "receipt.json").read_text())
    assert not receipt["complete"] and receipt["steps"][0]["stopped_for"] == "timeout" and not receipt["steps"][0]["errors"]
    lines = (output / "transport_visuals.log").read_text().splitlines()
    assert not any(line.startswith("HG FAIL ") for line in lines)
    assert "HG PASS gongsun_sheng_after_delivery: saved original screenshot" in lines
    files = sorted(output.glob("*.png"))
    assert len(files) == 37 and all(p.name.startswith("gongsun_sheng_") for p in files)
    evidence = HERE / "evidence" / output.name
    for name in ["receipt.json", "transport_visuals.log"]:
        copy(output / name, evidence / name)
    for name in ["probe.gd", "bootstrap.gd", "base.gd"]:
        copy(output / "harness" / name, evidence / ("executed_"+name+".txt"))
    rows = []
    for path in files:
        if path.name.endswith("_after_delivery.png"):
            copy(path, HERE / "screenshots" / path.name)
        rows.append({"path": path.name, "sha256": sha(path), "bytes": path.stat().st_size,
                     "original_path": path.relative_to(ROOT).as_posix()})
    summary = {"derived_from_original_log": True, "initial_run_complete": False,
               "positive_logged_checks": sum(line.startswith("HG PASS ") for line in lines),
               "failures_logged": 0, "screenshots": rows,
               "last_complete_actor": "gongsun_sheng", "log_sha256": sha(output / "transport_visuals.log"),
               "trusted_identity_report_written": False, "full_run_passed": False,
               "note": "Original 360s process timed out after Gongsun visual/delivery checks. Remaining actors are rerun separately; this derived inventory does not turn the first process into a pass."}
    (evidence / "partial_inventory.json").write_text(json.dumps(summary, indent=2)+"\n")
    return summary

def sheet(names, path, columns, crop=(350, 100, 930, 580)):
    tile_w, tile_h = 350, 310
    canvas = Image.new("RGB", (columns*tile_w, ((len(names)+columns-1)//columns)*tile_h), (35, 40, 45))
    draw = ImageDraw.Draw(canvas)
    inventory = {r["path"]: r for r in json.loads((HERE / "evidence/screenshot_inventory.json").read_text())}
    for i, name in enumerate(names):
        row = inventory[name+".png"]
        original = ROOT / row["original_path"]
        assert sha(original) == row["sha256"]
        im = Image.open(original).convert("RGB").crop(crop)
        im.thumbnail((tile_w, tile_h-25))
        x, y = (i % columns)*tile_w, (i // columns)*tile_h
        canvas.paste(im, (x, y+25)); draw.text((x+4, y+5), name, fill="white")
    path.parent.mkdir(exist_ok=True)
    canvas.save(path, quality=93)

def make_sheets(owners):
    visual = HERE / "visual"
    for owner in owners:
        for direction in ["se", "sw", "ne", "nw"]:
            names = [owner+"_idle_"+direction] + [owner+"_walk_"+direction+"_"+str(i) for i in range(4)]
            sheet(names, visual / (owner+"_gait_"+direction+".jpg"), 5)
        sheet([owner+"_"+d+"_"+phase for d in ["se", "sw", "ne", "nw"] for phase in ["a", "b"]], visual / (owner+"_wheels.jpg"), 4)
        sheet([owner+"_"+state+"_"+d for d in ["se", "sw", "ne", "nw"] for state in ["hurt", "attack"]], visual / (owner+"_interruptions.jpg"), 4)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--partial-only", action="store_true")
    args = parser.parse_args()
    partial = initial_partial()
    if args.partial_only:
        (HERE / "evidence/screenshot_inventory.json").write_text(json.dumps(partial["screenshots"], indent=2)+"\n")
        make_sheets(["gongsun_sheng"])
        print(json.dumps({"initial_run_complete": False, "positive_logged_checks": partial["positive_logged_checks"], "screenshots": 37}))
        return
    assert args.output is not None
    output = args.output.resolve()
    assert output.is_relative_to(ROOT / ".godot/huangnigang_production_20261020")
    report = json.loads((output / "report.json").read_text())
    receipt = json.loads((output / "receipt.json").read_text())
    assert report["passed"] and not report["failures"] and receipt["complete"]
    evidence = HERE / "evidence" / output.name
    for name in ["report.json", "receipt.json", "transport_visuals.log"]:
        copy(output / name, evidence / name)
    for name in ["probe.gd", "bootstrap.gd", "base.gd"]:
        copy(output / "harness" / name, evidence / ("executed_" + name + ".txt"))
    all_images = list(partial["screenshots"])
    for row in report["screenshots"]:
        assert sha(output / row["path"]) == row["sha256"]
        if row["path"].endswith("_after_delivery.png"):
            copy(output / row["path"], HERE / "screenshots" / row["path"])
        all_images.append({**row, "bytes": (output / row["path"]).stat().st_size,
                           "original_path": (output / row["path"]).relative_to(ROOT).as_posix()})
    (HERE / "evidence/screenshot_inventory.json").write_text(json.dumps(all_images, indent=2)+"\n")
    prepared = output.parent
    import_runs = sorted(prepared.glob("import__*/receipt.json"))
    assert len(import_runs) == 1
    copy(import_runs[0], HERE / "evidence/import.json")
    copy(prepared / "preparation.json", HERE / "evidence/preparation.json")
    failed = ROOT / ".godot/huangnigang_production_20261020/20261030_181948_af999b52/preparation.json"
    copy(failed, HERE / "evidence/initial_preparation_failed.json")
    pins = [{"path": str(p.relative_to(ROOT)), "sha256": sha(p), "bytes": p.stat().st_size}
            for p in [prepared / name for name in ["root_source.json", "preimport_source.json", "generation.json"]]]
    (HERE / "evidence/source_manifest_pins.json").write_text(json.dumps(pins, indent=2) + "\n")
    make_sheets(OWNERS)
    print(json.dumps({"checks": len(report["checks"]), "screenshots": len(report["screenshots"]), "evidence": str(evidence)}))

if __name__ == "__main__":
    main()
