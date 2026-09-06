"""Prepare this directory only. No subprocess, Git, Godot or live source write."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = "4baafc11af55b0e46a57a48e54df181b8c1917a2"
LEDGER = 'const SeparationDiag = preload("res://scratchpad/separation_sections_diag/generated/ledger.gd")\n'
SAFETY = "scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py"


def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.replace(b"\r\n", b"\n")
def need(ok, text):
    if not ok: raise RuntimeError(text)
def save(path, value): path.write_bytes((json.dumps(value,ensure_ascii=False,indent=2)+"\n").encode())


def method(text, name):
    matches = list(re.finditer(r"(?m)^func " + re.escape(name) + r"\(",text))
    need(len(matches)==1,"Expected unique full method "+name)
    a=matches[0].start()
    nxt=re.search(r"(?m)^func ",text[matches[0].end():])
    z=matches[0].end()+nxt.start() if nxt else len(text)
    return text[a:z]


def edit(text, replacements):
    result=text
    for old,new in replacements:
        need(result.count(old)==1,"Nonunique/stale injection seam: "+old[:95])
        result=result.replace(old,new,1)
    restored=result
    for old,new in reversed(replacements):
        need(restored.count(new)==1,"Nonunique reverse seam")
        restored=restored.replace(new,old,1)
    need(restored==text,"Removing only injected seams must restore original complete bytes")
    return result


def main():
    for name in ("frozen","generated"): (HERE/name).mkdir(parents=True,exist_ok=True)
    native=json.loads((ROOT/"scratchpad/native_sections_diag/pins.json").read_text(encoding="utf-8"))
    source=json.loads((ROOT/"scratchpad/native_sections_diag/runs/20260906T093709848839Z/source_before.json").read_text(encoding="utf-8"))
    need(native["base"]==BASE and source["git_head"]==BASE,"Wrong frozen source receipt")
    expected={name:item["lf_sha256"] for name,item in native["sources"].items() if name!=SAFETY}
    for name in ("scripts/crowd_separation.gd","scripts/game_map.gd","scripts/android_updater.gd"):
        expected[name]=source["file_sha256"][name]
    origin={"scripts/battle.gd":"scratchpad/physics_step_diag/frozen/battle_original.bin",
            "scripts/unit.gd":"scratchpad/physics_step_diag/frozen/unit_original.bin",
            "scripts/settings.gd":"scratchpad/reduced_effects_v2/frozen/settings.gd.bin"}
    texts={}; frozen_files={}
    for name,value in expected.items():
        dest=HERE/"frozen"/name.replace("/","__")
        raw=dest.read_bytes() if dest.exists() else (ROOT/origin.get(name,name)).read_bytes()
        need(sha(lf(raw))==value,"Frozen 4baafc1 mismatch, never substitute current source: "+name)
        if not dest.exists(): dest.write_bytes(raw)
        texts[name]=lf(raw).decode("utf-8")
        frozen_files[name]={"path":dest.relative_to(HERE).as_posix(),"raw_sha256":sha(raw),"lf_sha256":value}
    safety_dest=HERE/"frozen/process_safety.py"
    safety=safety_dest.read_bytes() if safety_dest.exists() else (ROOT/SAFETY).read_bytes()
    need(sha(safety)==native["sources"][SAFETY]["raw_sha256"],"Enhanced safety helper mismatch")
    if not safety_dest.exists(): safety_dest.write_bytes(safety)

    crowd=texts["scripts/crowd_separation.gd"]
    signature='static func solve(units: Array, buckets: Dictionary, map: GameMap, cell_size: float) -> void:\n'
    need(crowd.count(signature)==1 and crowd.count("static func ")==1,"Exactly one original complete solve")
    need(not re.search(r"(?m)^\s+return\b",crowd),"New early return needs a separate lifetime review")
    crowd_changes=[('extends RefCounted\n','extends RefCounted\n'+LEDGER),
        (signature,signature+'\tvar __separation_t: int = SeparationDiag.begin_solve()\n'),
        ('\tvar profile_cells := {}\n','\t__separation_t = SeparationDiag.stage(0, __separation_t)\n\tvar profile_cells := {}\n'),
        ('\tfor ai: int in order:\n','\t__separation_t = SeparationDiag.stage(1, __separation_t)\n\tfor ai: int in order:\n'),
        ('\tfor i in range(count):\n\t\tif sources[i].position != positions[i]: sources[i].position=positions[i]\n',
         '\t__separation_t = SeparationDiag.stage(2, __separation_t)\n\tfor i in range(count):\n\t\tif sources[i].position != positions[i]: sources[i].position=positions[i]\n\tSeparationDiag.end_solve(__separation_t)\n')]
    instrumented_crowd=edit(crowd,crowd_changes)
    battle=texts["scripts/battle.gd"]
    dispatch=method(battle,"_separation_pass")
    call='\t\tpreload("res://scripts/crowd_separation.gd").solve(units, _mob_grid, map, GRID_CELL)\n'
    need(battle.count(call)==1,"Exactly one full original solve call in Battle")
    changed_dispatch=edit(dispatch,[(call,'\t\tSeparationDiag.dispatched(0, _mob_count, _mob_grid.size())\n'+call),
        ('\tvar stagger := _mob_count > 320\n','\tvar stagger := _mob_count > 320\n\tSeparationDiag.dispatched(2 if stagger else 1, _mob_count, _mob_grid.size())\n')])
    instrumented_battle=edit(battle,[('extends Node2D\n','extends Node2D\n'+LEDGER),(dispatch,changed_dispatch)])

    original_run=method(texts["tools/polish_performance_probe.gd"],"_run")
    hooks=[('\t_configure_settings()\n','\tSeparationDiag.prepare(separation_mode)\n\t_configure_settings()\n'),
        ('\troot.add_child(tick_driver)\n','\troot.add_child(tick_driver)\n\tphysics_frame.connect(_separation_physics_boundary)\n\tprocess_frame.connect(_separation_process_boundary)\n'),
        ('\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick\n',
         '\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick\n\tSeparationDiag.begin_measurement(started, start_tick)\n'),
        ('\t\traw.append(float(now-previous)/1000.0); previous = now\n','\t\traw.append(float(now-previous)/1000.0); previous = now\n\t\tSeparationDiag.presented(now, physics_tick)\n'),
        ('\tvar elapsed := float(Time.get_ticks_usec()-started)/1000000.0\n',
         '\tvar elapsed := float(Time.get_ticks_usec()-started)/1000000.0\n\tSeparationDiag.end_measurement(Time.get_ticks_usec(), physics_tick)\n')]
    anchored_run=edit(original_run,hooks)
    prefix=(HERE/"driver.gd.in").read_text(encoding="utf-8")
    need(prefix.count("# @@PINNED_M1_RUN_WITH_ANCHORS@@")==1,"One driver generation marker required")
    driver=prefix.replace("# @@PINNED_M1_RUN_WITH_ANCHORS@@",anchored_run)
    outputs={"battle_instrumented.gd.txt":instrumented_battle,"crowd_instrumented.gd.txt":instrumented_crowd,
             "driver.gd":driver,"ledger.gd":(HERE/"ledger.gd.in").read_text(encoding="utf-8")}
    for name,text in outputs.items(): (HERE/"generated"/name).write_bytes(text.encode())
    patch=""
    for path,changed in (("scripts/battle.gd",instrumented_battle),("scripts/crowd_separation.gd",instrumented_crowd)):
        patch+="".join(difflib.unified_diff(texts[path].splitlines(True),changed.splitlines(True),fromfile="a/"+path,tofile="b/"+path))
    (HERE/"instrumentation.patch").write_bytes(patch.encode())
    pins={"base":BASE,"frozen_sources":frozen_files,"source_lf_sha256":expected,"safety_raw_sha256":sha(safety),
        "generated_raw_sha256":{name:sha(text.encode()) for name,text in outputs.items()},
        "instrumentation_patch_sha256":sha(patch.encode()),"original_complete_solve_sha256":sha(crowd.encode()),
        "original_dispatch_sha256":sha(dispatch.encode()),"original_m1_run_sha256":sha(original_run.encode()),
        "template_raw_sha256":{name:sha((HERE/name).read_bytes()) for name in ("driver.gd.in","ledger.gd.in","prepare.py","launch.py","analyze.py","resume.py","resume_contract.json")},
        "proofs":{"reverse_injections_restore_all_originals":True,"complete_solve_unique":True,"battle_solve_call_unique":True,"no_original_early_returns":True,"original_public_tools_unchanged":True},
        "scope":"isolated git-archive copy only; live M2C must never be replaced"}
    save(HERE/"pins.json",pins)
    for path in HERE.glob("*.py"): ast.parse(path.read_text(encoding="utf-8"))
    save(HERE/"preparation_receipt.json",{"prepared":True,"base":BASE,"godot_run":False,"git_run":False,
         "gdscript_parsed_or_executed":False,"live_source_mutated":False,"optimization_written":False,
         "pins_sha256":sha((HERE/"pins.json").read_bytes()),"proofs":pins["proofs"]})
    print(json.dumps({"prepared":True,"godot_run":False,"git_run":False,"live_source_mutated":False,"optimization_written":False}))


if __name__ == "__main__": main()
