"""Source and synthetic ledger checks. No Godot/Git/subprocess/production changes."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import tempfile
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
checks=[]


def check(ok,label):
    checks.append({"label":label,"passed":bool(ok)})
    if not ok: raise AssertionError(label)
def module(path):
    namespace={"__file__":str(path),"__name__":"separation_static_check"}
    exec(compile(path.read_text(encoding="utf-8"),str(path),"exec"),namespace)
    return namespace


def fixture():
    steps=[]
    for tick in range(1,304):
        pid=tick if tick<=300 else (1000 if tick<=302 else 1001)
        stamp=tick*1000
        steps.append([tick,tick+100,pid,stamp,stamp+10,tick+100,stamp+30,1,0,206,30,1,15,10,20,30,40])
    data={"valid":True,"errors":0,"overflow":False,"timed":True,"mode":"timed","step_count":303,
        "step_columns":["m1_tick","physics_id","process_id","physics_signal_us","observer_us","collection_physics_id","collected_us","dispatch_count","route","mobs","buckets","solve_calls","stage_mask","snapshot_us","profile_cells_us","pairs_us","publish_us"],
        "presentation_columns":["start_us","end_us","process_id","physics_id","m1_tick","step_begin_index","step_end_index"],
        "m1_start":{"us":300500,"m1_tick":300,"step_count":300},"m1_end":{"us":304100,"m1_tick":303,"step_count":303},
        "steps":steps,"presentation_count":2,"presentations":[[300500,302800,1000,402,302,300,302],[302800,304000,1001,403,303,302,303]],
        "processes":[[302500,1000,402],[303500,1001,403]]}
    m1={"integrity_passed":True,"sample_complete":True,"acceptance_eligible":False,"requested_seconds":10,
        "scenario":"defense200","camera_mode":"fixed","sample_start":{"tick":300},"sample_end":{"tick":303},
        "physics_ticks":3,"frames":2,"raw_frame_ms":[2.3,1.2]}
    return m1,data


def main():
    for path in HERE.glob("*.py"):
        ast.parse(path.read_text(encoding="utf-8"));check(True,"Python AST "+path.name)
    pins=json.loads((HERE/"pins.json").read_text(encoding="utf-8"))
    launcher=module(HERE/"launch.py");launcher["verify_draft"](pins)
    check(True,"frozen generated/template hashes match")
    with tempfile.TemporaryDirectory(prefix="manifest_check_",dir=HERE) as temp:
        folder=Path(temp)
        (folder/"visible.txt").write_bytes(b"known")
        (folder/".hidden.txt").write_bytes(b"hidden")
        for label,target in (("missing root",folder/"missing"),("file root",folder/"visible.txt")):
            try: launcher["manifest"](target)
            except RuntimeError: check(True,"reject manifest "+label)
            else: check(False,"reject manifest "+label)
        with patch.object(launcher["os"],"scandir",side_effect=PermissionError("injected scan failure")):
            try: launcher["manifest"](folder)
            except PermissionError: check(True,"reject manifest directory scan failure")
            else: check(False,"reject manifest directory scan failure")
        (folder/".godot").mkdir();(folder/".godot/cache.bin").write_bytes(b"cache")
        check(set(launcher["manifest"](folder))=={"visible.txt",".hidden.txt"},"manifest includes hidden sources and prunes engine cache")
        check(".godot/cache.bin" in launcher["manifest"](folder,exclude_godot=False),"explicit full cache snapshot does not prune nested cache path")
    for name,item in pins["frozen_sources"].items():
        raw=(HERE/item["path"]).read_bytes()
        check(hashlib.sha256(raw).hexdigest()==item["raw_sha256"],"raw frozen blob "+name)
    driver=(HERE/"generated/driver.gd").read_text(encoding="utf-8")
    crowd=(HERE/"generated/crowd_instrumented.gd.txt").read_text(encoding="utf-8")
    battle=(HERE/"generated/battle_instrumented.gd.txt").read_text(encoding="utf-8")
    ledger=(HERE/"generated/ledger.gd").read_text(encoding="utf-8")
    check(driver.count("func _run() -> void:")==1 and driver.count("super._on_tick()")==1,"one complete M1 run and one parent observer call")
    check(crowd.count("SeparationDiag.begin_solve()")==1 and crowd.count("SeparationDiag.end_solve(__separation_t)")==1,"one solve entry and exit")
    check(all(crowd.count("SeparationDiag.stage(%d, __separation_t)"%i)==1 for i in range(3)),"three interior boundaries produce exactly four spans")
    check(battle.count('preload("res://scripts/crowd_separation.gd").solve(units, _mob_grid, map, GRID_CELL)')==1,"original solve call not duplicated")
    check(battle.count("SeparationDiag.dispatched(")==2,"buffered and direct dispatch have one exclusive counter each")
    check("steps[offset+3] = step_signal_us" in ledger and "step_signal_us = physics_boundary_us" in ledger,"previous step retains its own physics signal clock")
    check("SeparationDiag.presented(now, physics_tick)" in driver and "SeparationDiag.begin_measurement(started, start_tick)" in driver,"presentation/start use unchanged M1 timestamp variables")
    check(all(token not in ledger for token in ("randf(","randi(","seed(","randomize(","Node.new(")),"ledger adds no RNG or scene nodes")
    check(pins["proofs"]["reverse_injections_restore_all_originals"],"preparer proved insertion-only restoration of original source")
    analyze=module(HERE/"analyze.py")["analyze"]
    m1,data=fixture()
    summary=analyze(m1,data)
    check(summary["all_measurement"]["physics_steps"]==3 and summary["all_measurement"]["stage_total_us"]["profile_cells_us"]==60,"same-clock synthetic 2+1 catch-up grouping and stage totals")
    clockless=copy.deepcopy(data);clockless["timed"]=False;clockless["mode"]="clockless"
    for row in clockless["steps"]: row[13:]=[0,0,0,0]
    check(analyze(m1,clockless)["all_measurement"]["mean_us_per_buffered_solve"]["profile_cells_us"] is None,"clockless does not present zero clocks as measured cost")
    mutations=[("missing last step",lambda m,d:d["steps"].pop()),
        ("duplicated tick",lambda m,d:d["steps"][301].__setitem__(0,301)),
        ("missing stage",lambda m,d:d["steps"][301].__setitem__(12,7)),
        ("wrong shared clock origin",lambda m,d:d["steps"][301].__setitem__(3,42)),
        ("wrong process frame",lambda m,d:d["steps"][301].__setitem__(2,999)),
        ("overlapping presentation range",lambda m,d:d["presentations"][1].__setitem__(5,301)),
        ("raw M1 interval mismatch",lambda m,d:m["raw_frame_ms"].__setitem__(0,9.9)),
        ("dispatch double-count",lambda m,d:d["steps"][301].__setitem__(7,2)),
        ("clockless with timings",lambda m,d:d.__setitem__("timed",False))]
    for label,mutate in mutations:
        bad_m,bad_d=copy.deepcopy(m1),copy.deepcopy(data);mutate(bad_m,bad_d)
        try: analyze(bad_m,bad_d)
        except RuntimeError: check(True,"reject "+label)
        else: check(False,"reject "+label)
    output={"passed":True,"checks":len(checks),"results":checks,"godot_run":False,"gdscript_parsed_or_executed":False,
        "git_run":False,"live_source_mutated":False,"synthetic_only":True,"import_process_lifecycle_not_executed":True}
    (HERE/"static_receipt.json").write_bytes((json.dumps(output,indent=2)+"\n").encode())
    print(json.dumps({key:value for key,value in output.items() if key!="results"}))


if __name__=="__main__": main()
