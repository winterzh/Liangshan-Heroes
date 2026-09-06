"""Prepare v2 patch, source pins and QA only. Never apply or launch Godot/Git."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
UNIT_LF = "c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec"
UNIT_RAW = "c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856"
OLD_RAW = "f6f9bccd20a13e6d8d2a93647441b9e3b19d40f120c46426c17b85e7e66a6e36"
V1_PATCH = "a2eae1eab90a984c6d3cb31b0eb90788ebb7d35a8ade41a86df6a98838dfa202"
V1_QA = "cd4fb7a59e81840ffb86f772020392df34ce959a10e67fab98a7ca7bbe47688d"
BASE_LF = {"scripts/settings.gd":"93ffcc801149744cc9b0eed35b1bfd0769b5f25ac8f80cdbb7865997b5ef646c",
    "scripts/settings_panel.gd":"1a8f455515bbed7a287eeebb32aded1838356d667633fa728c81e2b0ea42cfca",
    "scripts/battle.gd":"784373eede18a82c24fc50a6e36a42b6c20516bf439cf200fe5be7d239db6e2c",
    "scripts/unit.gd":UNIT_LF}


def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.replace(b"\r\n", b"\n")
def save(path, value): path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2)+"\n").encode())
def need(ok, message):
    if not ok: raise RuntimeError(message)


def method_span(raw, name):
    hit = re.search(rb"(?m)^func " + name.encode() + rb"\(", raw)
    need(hit is not None, "Missing method " + name)
    nxt = re.search(rb"(?m)^func ", raw[hit.end():])
    need(nxt is not None, "Missing next method " + name)
    return hit.start(), hit.end()+nxt.start()


def candidate_unit():
    original = (ROOT/"scratchpad/redraw_reject_validation/unit_before.bin").read_bytes()
    need(sha(original)==OLD_RAW, "Frozen pre-redraw Unit mismatch")
    tree = ast.parse((ROOT/"scratchpad/apply_redraw_candidate.py").read_text(encoding="utf-8-sig"))
    assignments = [n for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="changes" for t in n.targets)]
    need(len(assignments)==1, "Expected literal redraw changes")
    changes = ast.literal_eval(assignments[0].value)
    need(list(changes)==["_queue_animated_redraw","_queue_motion_redraw"], "Unexpected redraw patch scope")
    result = original
    for name in reversed(list(changes)):
        start,end = method_span(result,name)
        fragment = changes[name].encode()
        if b"\r\n" in result[start:end]: fragment = fragment.replace(b"\n",b"\r\n")
        result = result[:start]+fragment+result[end:]
    need(sha(result)==UNIT_RAW and sha(lf(result))==UNIT_LF, "Rebuilt complete candidate Unit mismatch")
    return result


def apply_v1_memory(sources, patch, expected_counts=None):
    """Exact context replacement in memory; line offsets never restore the old Unit."""
    result = dict(sources)
    lines = patch.splitlines(keepends=True)
    name = None; index = 0; counts = {}
    while index < len(lines):
        line = lines[index]
        if line.startswith("+++ b/"): name = line[6:].strip()
        if line.startswith("@@ "):
            old=[]; new=[]; index+=1
            while index<len(lines) and not lines[index].startswith(("@@ ","diff --git ")):
                item=lines[index]
                if item.startswith(" "): old.append(item[1:]); new.append(item[1:])
                elif item.startswith("-"): old.append(item[1:])
                elif item.startswith("+"): new.append(item[1:])
                else: raise RuntimeError("Unexpected unified diff line")
                index+=1
            a,b="".join(old),"".join(new)
            need(result[name].count(a)==1,"Ambiguous/stale V1 context: "+str(name))
            result[name]=result[name].replace(a,b,1)
            counts[name]=counts.get(name,0)+1
            continue
        index+=1
    if expected_counts is None: expected_counts={"scripts/settings.gd":3,"scripts/settings_panel.gd":1,"scripts/battle.gd":4,"scripts/unit.gd":1}
    need(counts==expected_counts,"Unexpected change count")
    return result


def main():
    HERE.mkdir(exist_ok=True)
    (HERE/"frozen").mkdir(exist_ok=True)
    (HERE/"candidate").mkdir(exist_ok=True)
    (HERE/"generated").mkdir(exist_ok=True)
    originals={}
    for name in BASE_LF:
        frozen=HERE/"frozen"/(Path(name).stem+".gd.bin")
        if name=="scripts/unit.gd": raw=candidate_unit()
        elif frozen.exists(): raw=frozen.read_bytes()
        elif name=="scripts/battle.gd": raw=(ROOT/"scratchpad/physics_step_diag/frozen/battle_original.bin").read_bytes()
        else: raw=(ROOT/name).read_bytes()
        need(sha(lf(raw))==BASE_LF[name],"Base pin mismatch: "+name)
        if frozen.exists(): need(frozen.read_bytes()==raw,"Frozen file changed: "+name)
        else: frozen.write_bytes(raw)
        originals[name]=raw
    patch_path=ROOT/"scratchpad/reduced_effects_candidate.patch"
    qa_path=ROOT/"scratchpad/reduced_effects_qa.gd.in"
    need(sha(patch_path.read_bytes())==V1_PATCH and sha(qa_path.read_bytes())==V1_QA,"Original draft changed")
    base={name:lf(raw).decode("utf-8") for name,raw in originals.items()}
    candidate=apply_v1_memory(base,patch_path.read_text(encoding="utf-8-sig"))
    for name in ("scripts/battle.gd","scripts/unit.gd"):
        candidate[name]=candidate[name].replace('Settings.effects_quality','Settings.get("effects_quality")')
    candidate["scripts/battle.gd"]=candidate["scripts/battle.gd"].replace('var reduced_fx := Settings.get("effects_quality") == "reduced"', 'var reduced_fx: bool = Settings.get("effects_quality") == "reduced"')
    axes_marker='class LiBrawnAxesFx extends Node2D:'
    axes_start=candidate["scripts/battle.gd"].index(axes_marker)
    axes_end=candidate["scripts/battle.gd"].index('\nclass ',axes_start+len(axes_marker))
    axes_body=candidate["scripts/battle.gd"][axes_start:axes_end]
    unsafe_target='\t\t\tvar target: Unit = hit.get("target")'
    safe_target='\t\t\tvar target_value: Variant = hit.get("target")\n\t\t\tif not is_instance_valid(target_value):\n\t\t\t\tcontinue\n\t\t\tvar target: Unit = target_value'
    need(axes_body.count(unsafe_target)==2,"Axes lifetime guard seam drift")
    candidate["scripts/battle.gd"]=candidate["scripts/battle.gd"][:axes_start]+axes_body.replace(unsafe_target,safe_target)+candidate["scripts/battle.gd"][axes_end:]
    old_panel='\t_row(p, "特效细节", _seg([["标准", "standard"], ["精简", "reduced"]], Settings.effects_quality, func(v) -> void: Settings.effects_quality = String(v)))\n\t_row(p, "", _note("精简装饰粒子与拖尾，保留技能提示和命中反馈"))'
    new_panel='\t# Old packaged Settings instances may predate this field; keep standard and hide this row.\n\tvar effects_value: Variant = Settings.get("effects_quality")\n\tif effects_value is String and effects_value in ["standard", "reduced"]:\n\t\t_row(p, "特效细节", _seg([["标准", "standard"], ["精简", "reduced"]], effects_value, func(v) -> void: Settings.set("effects_quality", String(v))))\n\t\t_row(p, "", _note("精简装饰粒子与拖尾，保留技能提示和命中反馈"))'
    need(candidate["scripts/settings_panel.gd"].count(old_panel)==1,"Panel seam drift")
    candidate["scripts/settings_panel.gd"]=candidate["scripts/settings_panel.gd"].replace(old_panel,new_panel,1)
    panel_ready='\tprocess_mode = Node.PROCESS_MODE_ALWAYS   # 暂停态(Esc 菜单)下仍可操作\n'
    need(candidate["scripts/settings_panel.gd"].count(panel_ready)==1,"Panel modal seam drift")
    candidate["scripts/settings_panel.gd"]=candidate["scripts/settings_panel.gd"].replace(panel_ready,panel_ready+'\tz_index = 300  # Keep this modal above battle toasts, inventory and skill tips.\n',1)
    proofs={}
    for name in ("_queue_animated_redraw","_queue_motion_redraw"):
        a,z=method_span(originals["scripts/unit.gd"],name)
        changed=candidate["scripts/unit.gd"].encode(); b,y=method_span(changed,name)
        need(lf(originals["scripts/unit.gd"][a:z])==changed[b:y],"Redraw candidate was lost")
        proofs[name]=sha(changed[b:y])
    # Quality changes stay in four _draw bodies; the separate freed-target guard also changes resolve_hits.
    for name in ("scripts/battle.gd","scripts/unit.gd"):
        need("Settings.effects_quality" not in candidate[name],"Direct access to newly-added Autoload property")
    pins={"schema":2,"base_lf_sha256":BASE_LF,
        "base_raw_sha256":{name:sha(raw) for name,raw in originals.items()},
        "candidate_lf_sha256":{name:sha(text.encode()) for name,text in candidate.items()},
        "legacy_boot_profile":"same candidate files except original pre-field settings.gd; external runner verifies this before Godot",
        "redraw_methods_preserved_sha256":proofs,
        "v1_patch_raw_sha256":V1_PATCH,"v1_qa_raw_sha256":V1_QA,
        "safety_helper_raw_sha256":sha((ROOT/"scratchpad/redraw_reject_diag/run_redraw_reject_diagnostics.py").read_bytes()),
        "startup_dependency_raw_sha256":{name:sha((ROOT/name).read_bytes()) for name in (
            "project.godot","tools/run_polish_performance.py","scripts/android_updater.gd")}}
    patch='# DRAFT V2 ONLY. Not applied or parsed. Base Unit retains c8a692bf redraw candidate.\n'
    patch+=''.join('# '+line+'\n' for line in json.dumps(pins,ensure_ascii=False,indent=2).splitlines())
    for name in base:
        (HERE/"candidate"/(Path(name).stem+".gd.txt")).write_bytes(candidate[name].encode())
        patch+='diff --git a/'+name+' b/'+name+'\n'
        patch+=''.join(difflib.unified_diff(base[name].splitlines(keepends=True),candidate[name].splitlines(keepends=True),fromfile='a/'+name,tofile='b/'+name))
    (HERE/"candidate.patch").write_bytes(patch.encode())
    save(HERE/"pins.json",pins)
    qa=lf(qa_path.read_bytes()).decode()
    qa=qa.replace('## DRAFT ONLY: not parsed or run in Godot. Copy to .godot/reduced_effects_qa/driver.gd\n## only after the candidate patch is reviewed/applied and an exclusive Godot slot is held.', '## DRAFT ONLY: not parsed or run in Godot. Generated under this draft directory;\n## external launcher requires reviewed source application and an exclusive Godot slot.')
    qa=qa.replace('## to .godot. They do not write user://settings.cfg or call SettingsPanel.close.', '## to this draft run directory. They do not save through the booted Settings Autoload.\n## Its user:// path is separately isolated before process launch; panel.close is not used.')
    qa=qa.replace('const OUT := "res://.godot/reduced_effects_qa"','var OUT := ""')
    qa=qa.replace('const FIXTURE_SETTINGS := OUT + "/settings.cfg"','var FIXTURE_SETTINGS := ""')
    for symbol,values in (("BASE_LF_SHA256",BASE_LF),("CANDIDATE_LF_SHA256",pins["candidate_lf_sha256"])):
        qa=re.sub(r'const '+symbol+r' := \{.*?\n\}', 'const '+symbol+' := '+json.dumps(values,indent=2), qa, count=1, flags=re.S)
    qa=qa.replace('var quality_before := "standard"','var quality_before: Variant = null')
    qa=qa.replace('var matches := _text_lf("res://" + path).sha256_text() == CANDIDATE_LF_SHA256[path]', 'var expected: String = BASE_LF_SHA256[path] if stage == "legacy_autoload" and path == "scripts/settings.gd" else CANDIDATE_LF_SHA256[path]\n\t\tvar matches := _text_lf("res://" + path).sha256_text() == expected')
    qa=qa.replace('["all", "restart_write", "restart_read", "freed_target_boundary"]','["all", "restart_write", "restart_read", "freed_target_boundary", "legacy_autoload"]')
    seam='\tif not _source_lock():\n'
    out_setup='\tOUT = OS.get_environment("REDUCED_EFFECTS_QA_OUT")\n\tif OUT.is_empty() or not OUT.begins_with("res://scratchpad/reduced_effects_v2/runs/"):\n\t\tpush_error("Explicit bounded QA output required"); quit(2); return\n\tFIXTURE_SETTINGS = OUT + "/settings.cfg"\n\tvar user_path := ProjectSettings.globalize_path("user://").replace("\\\\", "/").simplify_path().trim_suffix("/")\n\tvar expected_user_root := OS.get_environment("REDUCED_EFFECTS_QA_USER_ROOT").replace("\\\\", "/").simplify_path().trim_suffix("/")\n\tif expected_user_root.is_empty() or not user_path.to_lower().begins_with(expected_user_root.to_lower() + "/"):\n\t\tpush_error("External isolated user-root receipt mismatch"); quit(2); return\n\treport["actual_user_dir"] = user_path\n'
    need(qa.count(seam)==1,"QA source gate seam drift")
    qa=qa.replace(seam,out_setup+seam,1)
    qa=qa.replace('quality_before = String(root.get_node("Settings").get("effects_quality"))','quality_before = root.get_node("Settings").get("effects_quality")')
    qa=qa.replace('\tif not _prepare_settings_fixture():','\tif stage == "legacy_autoload":\n\t\tawait _legacy_autoload_cases()\n\t\t_finish()\n\t\treturn\n\tif not _prepare_settings_fixture():',1)
    qa=qa.replace('\t\t_settings_cases()','\t\t_settings_missing_corrupt_cases()\n\t\t_settings_cases()',1)
    qa=qa.replace('\t\t_axes_edges()','\t\t_axes_edges()\n\t\tawait _in_tree_lifecycle_cases()',1)
    qa=qa.replace('\t\t\t\tawait _render_cases()','\t\t\t\tawait _render_cases()\n\t\t\t\tawait _critical_feedback_cases()',1)
    qa=qa.replace('\troot.get_node("Settings").effects_quality = quality_before','\tif quality_before is String:\n\t\troot.get_node("Settings").set("effects_quality", quality_before)',1)
    qa=qa.replace('res://.godot/reduced_effects_qa','res://scratchpad/reduced_effects_v2/runs')
    # The SceneTree script is parsed before Autoload registration. Resolve real
    # production scripts only in deferred _run; keep all fixture callbacks intact.
    qa_replacements = {
        'var b := Battle.new()': 'var b = battle_script.new()',
        'var u := Unit.new()': 'var u = unit_script.new()',
        'Defs.UNITS': 'defs_script.UNITS',
        'Defs.ABILITIES': 'defs_script.ABILITIES',
        'func _unit_fixture(b, label: String, at: Vector2, faction := 1) -> Unit:':
            'func _unit_fixture(b, label: String, at: Vector2, faction := 1):',
        'func _unit_state(u: Unit) -> Dictionary:': 'func _unit_state(u) -> Dictionary:',
        'var target: Unit': 'var target = null',
        'Battle.AmbientMotes.new()': 'motes_script.new()',
        'Battle.HitSpark.new()': 'hit_spark_script.new()',
        'Battle.GroundFireFx.new()': 'ground_fire_script.new()',
        'Battle.LiBrawnAxesFx.new()': 'axes_script.new()',
        'Unit.new()': 'unit_script.new()',
        'Unit.DUST_DUR': 'unit_script.DUST_DUR',
        'GameMap.ISO': 'map_script.ISO',
        'vp.own_world_2d = true': 'vp.world_2d = World2D.new()',
        'var hp_before := target.hp': 'var hp_before: float = target.hp',
        'check(fire is Battle.GroundFireFx, "real quiet ground fire creates visual with DOT")':
            'check(_is_script_instance(fire, ground_fire_script), "real quiet ground fire creates visual with DOT")\n\tif not _is_script_instance(fire, ground_fire_script):\n\t\tb.free(); return {}',
    }
    for old, new in qa_replacements.items():
        need(old in qa, "QA runtime-class seam drift: " + old)
        qa = qa.replace(old, new)
    qa, unit_bindings = re.subn(r'(var \w+) := (_unit_fixture\()', r'\1 = \2', qa)
    need(unit_bindings == 7, "QA untyped Unit fixture bindings drift")
    runtime_gate = '\troot.get_node("Sfx").enabled = false\n'
    need(qa.count(runtime_gate) == 1, "QA deferred runtime-load seam drift")
    qa = qa.replace(runtime_gate, runtime_gate + '\tif not _load_runtime_scripts():\n\t\tcheck(false, "runtime production class loading completed")\n\t\t_finish()\n\t\treturn\n', 1)
    equality = '\t\t\tcheck(standard == reduced, "fixed callbacks exact state/RNG/creation equivalence lite=" + str(lite))'
    need(qa.count(equality) == 1, "QA callback equivalence seam drift")
    qa = qa.replace(equality, '\t\t\tvar complete := _complete_callback_state(standard) and _complete_callback_state(reduced)\n\t\t\tcheck(complete, "both fixed callback runs reached a complete gameplay/RNG snapshot")\n\t\t\tif not complete:\n\t\t\t\t_finish()\n\t\t\t\treturn\n' + equality, 1)
    qa += '\n\n'+(HERE/"qa_extra.gd.in").read_text(encoding="utf-8")
    # Strip strings as well as comments: labels mention real Battle/Unit classes.
    executable = re.sub(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\#[^\n]*''', '', qa)
    need(re.search(r'\b(?:Battle|Unit|GameMap|Defs)\b', executable) is None,
         "QA retained an eager production-class reference")
    need("own_world_2d" not in qa and qa.count("world_2d = World2D.new()") == 3,
         "All three rendering fixtures require a real isolated World2D")
    need("var ref: WeakRef = weakref(fx)" in qa, "Keep the reviewed WeakRef binding")
    qa='## V2 GENERATED TEMPLATE. Read README; old draft is retained unchanged.\n'+qa
    (HERE/"qa.gd.in").write_bytes(qa.encode())
    (HERE/"generated/driver.gd").write_bytes(qa.encode())
    save(HERE/"preparation_receipt.json",{"production_mutated":False,"godot_run":False,"git_run":False,
        "gdscript_parsed_or_executed":False,"performance_claim":False,"pins":pins,
        "qa_sha256":sha(qa.encode()),"patch_sha256":sha(patch.encode()),
        "generator_sha256":sha(Path(__file__).read_bytes()),"extra_qa_sha256":sha((HERE/"qa_extra.gd.in").read_bytes())})
    print(json.dumps({"prepared":True,"production_mutated":False,"gdscript_validated":False,"candidate_sha256":pins["candidate_lf_sha256"]}))


if __name__=="__main__": main()
