"""Small deterministic artifact generator only. No engine, Git, copytree or live edits."""
import ast
import difflib
import hashlib
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
SEP = HERE.parent / 'separation_sections_diag'
BASE = '4baafc11af55b0e46a57a48e54df181b8c1917a2'
UNIT_RAW = 'c8310fd12a29858df8f7410dd06d2f1dc51f40f5eedc0e7a6a16599eb5e58856'
UNIT_LF = 'c8a692bff598b6ac9199d113ccc9ff39ea8943f127012b45fc67ff2cd6c4deec'
M1_SHA = '04a47115c8cd05670b465086653491466fdae99f6fadf9c41c40379aee0c1407'
PRIVATE = '_unit_body_sections_original'
RESOURCE = 'res://scratchpad/unit_body_sections_diag/generated/ledger.gd'
BOUNDARIES = [
    (b'\t_cd = maxf(0.0, _cd - delta)', 'status_timers'),
    (b'\t_eject_t -= delta', 'target_state_movement'),
    (b'\t_move_blend = move_toward(_move_blend, 1.0 if _stepped else 0.0, delta * 6.0)', 'tail_animation_hit_watchdog'),
]

def sha(raw): return hashlib.sha256(raw).hexdigest()
def lf(raw): return raw.replace(b'\r\n', b'\n')
def need(value, detail):
    if not value: raise RuntimeError(detail)
def save(path, value):
    path.write_bytes((json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode('utf-8'))

def span(raw, name):
    found = list(re.finditer(rb'(?m)^func '+name.encode()+rb'\(', raw))
    need(len(found) == 1, 'Expected unique method '+name)
    start = found[0].start()
    following = re.search(rb'(?m)^func ', raw[found[0].end():])
    end = found[0].end()+following.start() if following else len(raw)
    return start, end

def transform(original):
    need(sha(original) in [UNIT_RAW,UNIT_LF] and sha(lf(original)) == UNIT_LF, 'Only exact pinned raw/LF Unit accepted')
    need(b'_UnitBodySectionsDiag' not in original and PRIVATE.encode() not in original, 'Already instrumented')
    start, end = span(original, '_phys_body')
    complete = original[start:end]
    newline = b'\r\n' if complete.split(b'\n',1)[0].endswith(b'\r') else b'\n'
    modified = complete.replace(b'func _phys_body(', ('func '+PRIVATE+'(').encode(), 1)
    insertions = []
    for index,(anchor,label) in enumerate(BOUNDARIES,1):
        matches = list(re.finditer(rb'(?m)^'+re.escape(anchor)+rb'\r?$',modified))
        need(len(matches) == 1,'Boundary anchor drift: '+label)
        addition = ('\t_UnitBodySectionsDiag.section(%d) # UNIT_BODY_SECTIONS_MARK\n'%index).encode().replace(b'\n',newline)
        position = matches[0].start()
        modified = modified[:position]+addition+modified[position:]
        source_pos = complete.index(anchor)
        insertions.append({'index':index,'label':label,'anchor':anchor.decode(),
                           'original_line':original[:start+source_pos].count(b'\n')+1,
                           'inserted_utf8':addition.decode()})
    wrapper = '''const _UnitBodySectionsDiag = preload("%s")

func _phys_body(delta: float) -> void:
	var __uds_collect: bool = _UnitBodySectionsDiag.active
	var __uds_started: int = 0
	var __uds_token: int = -1
	if __uds_collect:
		if _UnitBodySectionsDiag.timed: __uds_started = Time.get_ticks_usec()
		__uds_token = _UnitBodySectionsDiag.begin_body(__uds_started)
	%s(delta)
	if __uds_collect:
		var __uds_ended: int = Time.get_ticks_usec() if _UnitBodySectionsDiag.timed else 0
		_UnitBodySectionsDiag.end_body(__uds_token, __uds_started, __uds_ended)


'''%(RESOURCE,PRIVATE)
    prefix = wrapper.encode().replace(b'\n',newline)
    changed = original[:start]+prefix+modified+original[end:]
    # This inverse checks ALL bytes, including untouched methods and mixed EOLs.
    restored = changed.replace(prefix,b'',1)
    for entry in insertions:
        marker = entry['inserted_utf8'].encode()
        need(restored.count(marker)==1,'Unique exact boundary marker')
        restored = restored.replace(marker,b'',1)
    restored = restored.replace(('func '+PRIVATE+'(').encode(),b'func _phys_body(',1)
    need(restored == original,'Inverse failed to recover every original byte')
    need(prefix.count((PRIVATE+'(delta)').encode()) == 1,'Complete original called once')
    # Exclude lambda returns: only return statements beginning an indented line.
    outer_returns = list(re.finditer(rb'(?m)^\t+return(?:\s|$)',complete))
    positions = [complete.index(anchor) for anchor,_ in BOUNDARIES]
    returns_per_section = [0,0,0,0]
    for ret in outer_returns: returns_per_section[sum(ret.start() > p for p in positions)] += 1
    need(returns_per_section == [5,0,3,0],'Pinned early-return route changed')
    before_callback = original[slice(*span(original,'_physics_process'))]
    after_callback = changed[slice(*span(changed,'_physics_process'))]
    need(before_callback==after_callback,'Outer native callback was modified')
    return changed, {'source_raw_sha256':sha(original),'source_lf_sha256':sha(lf(original)),
        'result_raw_sha256':sha(changed),'original_method_raw_sha256':sha(complete),
        'original_method_lf_sha256':sha(lf(complete)),'original_method_lines':[original[:start].count(b'\n')+1,original[:end].count(b'\n')],
        'insertions':insertions,'outer_returns_by_section':returns_per_section,
        'inverse_restores_every_original_byte':True,'one_original_call_in_wrapper':True,
        'original_outer_physics_process_unchanged':True}, restored

def driver_from_m1(m1):
    need(sha(m1)==M1_SHA,'Frozen exact M1 source drift')
    original = m1[slice(*span(m1,'_run'))].decode()
    hooks = [
        ('\t_configure_settings()\n','\tUnitBodyDiag.prepare(unit_sections_mode)\n'),
        ('\troot.add_child(tick_driver)\n','\tphysics_frame.connect(_unit_sections_physics_boundary)\n\tprocess_frame.connect(_unit_sections_process_boundary)\n'),
        ('\tvar started := Time.get_ticks_usec(); var previous := started; var start_tick := physics_tick\n','\tUnitBodyDiag.begin_measurement(started, start_tick)\n'),
        ('\t\traw.append(float(now-previous)/1000.0); previous = now\n','\t\tUnitBodyDiag.presented(now, physics_tick)\n'),
        ('\tvar elapsed := float(Time.get_ticks_usec()-started)/1000000.0\n','\tUnitBodyDiag.end_measurement(Time.get_ticks_usec(), physics_tick)\n'),
    ]
    changed = original
    for index,(anchor,addition) in enumerate(hooks):
        need(changed.count(anchor)==1,'M1 anchor drift')
        changed = changed.replace(anchor, addition+anchor if index==0 else anchor+addition,1)
    restored = changed
    for _,addition in hooks:
        need(restored.count(addition)==1,'Unique M1 observer insertion')
        restored = restored.replace(addition,'',1)
    need(restored==original,'Original M1 run changed beyond observer hooks')
    template = (HERE/'driver.gd.in').read_text(encoding='utf-8')
    need(template.count('# @@PINNED_M1_RUN_WITH_ANCHORS@@')==1,'One driver placeholder')
    return template.replace('# @@PINNED_M1_RUN_WITH_ANCHORS@@',changed).encode(),{
        'original_run_sha256':sha(original.encode()),'observer_hooks':len(hooks),
        'inverse_restores_exact_m1_run':True,'setup_warmup_loop_sample_anchors_unchanged':True}

def main():
    # Read only these small existing frozen files, never the private project tree.
    sources = json.loads((SEP/'pins.json').read_text(encoding='utf-8'))
    need(sources['base']==BASE,'Separation frozen base drift')
    unit = (SEP/sources['frozen_sources']['scripts/unit.gd']['path']).read_bytes()
    m1 = (SEP/sources['frozen_sources']['tools/polish_performance_probe.gd']['path']).read_bytes()
    need(sha(unit)==UNIT_RAW,'Frozen Unit raw differs from reviewed source')
    generated = HERE/'generated'; generated.mkdir(exist_ok=True)
    raw_output, raw_proof, restored = transform(unit)
    lf_output, lf_proof, _ = transform(lf(unit))
    driver, driver_proof = driver_from_m1(m1)
    outputs = {'unit_instrumented.raw.gd.txt':raw_output,'unit_instrumented.lf.gd.txt':lf_output,
               'driver.gd':driver,'ledger.gd':(HERE/'ledger.gd.in').read_bytes(),
               'original_phys_body.gd.txt':unit[slice(*span(unit,'_phys_body'))]}
    for name,data in outputs.items(): (generated/name).write_bytes(data)
    patch = ''.join(difflib.unified_diff(lf(unit).decode().splitlines(True),lf_output.decode().splitlines(True),
                                       fromfile='a/scripts/unit.gd',tofile='b/scripts/unit.gd')).encode()
    (HERE/'instrumentation.patch').write_bytes(patch)
    pins = {'base':BASE,'source_origin':'read-only existing separation_sections_diag/frozen files; never live Unit',
        'unit_raw_variant':raw_proof,'unit_lf_variant':lf_proof,'m1_driver':driver_proof,
        'generated_sha256':{name:sha(data) for name,data in outputs.items()},'patch_sha256':sha(patch),
        'source_contract':{path:{'raw_sha256':row['raw_sha256'],'lf_sha256':row['lf_sha256'],'frozen_path':str(SEP/row['path'])}
                           for path,row in sources['frozen_sources'].items()},
        'container_mutation_plan':['Restore prior separation-instrumented scripts/battle.gd and scripts/crowd_separation.gd to frozen 4baafc1, if that private container is selected',
            'Replace only exact pinned raw/LF scripts/unit.gd with corresponding instrumented artifact',
            'Add scratchpad/unit_body_sections_diag/generated/driver.gd and ledger.gd',
            'Do not modify prior reports/receipts/source manifests, live source, settings, campaign, Art, Sfx, public probes or engine configuration'],
        'source_restored_sha256':sha(restored),'godot_run':False,'git_run':False,'live_source_mutated':False}
    save(HERE/'pins.json',pins)
    for p in HERE.glob('*.py'): ast.parse(p.read_text(encoding='utf-8'))
    save(HERE/'preparation_receipt.json',{'prepared':True,'godot_run':False,'git_run':False,
        'gdscript_parsed_or_executed':False,'mirror_created':False,'production_mutated':False,
        'optimization_written':False,'generated_bytes':sum(map(len,outputs.values())),
        'pins_sha256':sha((HERE/'pins.json').read_bytes()),'raw_inverse_exact':True,'lf_inverse_exact':True,'m1_inverse_exact':True})
    print(json.dumps({'prepared':True,'generated_bytes':sum(map(len,outputs.values())),'godot_run':False,'mirror_created':False}))

if __name__=='__main__': main()
