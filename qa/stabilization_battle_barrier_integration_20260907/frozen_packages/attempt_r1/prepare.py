"""Build actual Battle clock/gate and root-v3 candidates; never run the engine."""
from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
DEST=HERE/'candidate/scripts'
HEAD='2e40c4afd5d3bce22a8204bed2c1f903fc046ff5'
def sha(raw): return hashlib.sha256(raw).hexdigest()
def put(name,text):
    path=DEST/name
    assert not (HERE/'freeze.json').exists(), 'Do not rewrite frozen candidates'
    assert path.resolve().is_relative_to(DEST.resolve())
    path.write_text(text,encoding='utf-8',newline='\n')
def replace_once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)
clock=ROOT/'scratchpad/stabilization_simulation_clock_20260907/attempt_actual_battle_v1/candidate/scripts/run_battle_clock.gd'
put('run_battle_clock.gd',clock.read_text(encoding='utf-8'))
battle=(ROOT/'scripts/battle.gd').read_text(encoding='utf-8')
battle=replace_once(battle,'var next_entity_id: int = 1', 'var next_entity_id: int = 1\nvar _run_clock: RefCounted\nvar _save_barrier: Node')
battle=replace_once(battle,'func _ready() -> void:\n\t_refresh_hot_patch_classes()', '''func _ready() -> void:
\t_run_clock = preload("res://scripts/run_battle_clock.gd").new()
\tvar initialized: Dictionary = _run_clock.initialize_new(Engine.get_physics_frames())
\tif not initialized.ok:
\t\t_gameplay_rng_stop(initialized.code)
\t\treturn
\t_save_barrier = preload("res://scripts/run_battle_barrier.gd").new()
\t_save_barrier.configure(self, _run_clock)
\tadd_child(_save_barrier)
\t_refresh_hot_patch_classes()''')
battle=replace_once(battle,'var fr := int(Engine.get_physics_frames())','var fr := _run_cache_frame()')
battle=replace_once(battle,'var bucket := int(Engine.get_physics_frames() / maxi(1, AI_TICK))','var bucket := int(_run_cache_frame() / maxi(1, AI_TICK))')
helpers='''func _run_cache_frame() -> int:
\tif _run_clock == null: return int(Engine.get_physics_frames())
\tvar frame: int = _run_clock.observe_cache_frame(Engine.get_physics_frames())
\tif frame < 0: _gameplay_rng_stop(_run_clock.fault())
\treturn frame

func _run_capture_input_closed() -> bool:
\treturn is_instance_valid(_save_barrier) and _save_barrier.input_closed()

func request_run_capture() -> Dictionary:
\tif not is_instance_valid(_save_barrier): return {"ok": false, "code": "RUN_BARRIER_UNAVAILABLE"}
\treturn _save_barrier.request_capture()

'''
battle=replace_once(battle,'\nfunc _ready() -> void:','\n'+helpers+'func _ready() -> void:')
for signature in ['func _unhandled_input(event: InputEvent) -> void:', 'func _goto_menu() -> void:', 'func _open_pause() -> void:', 'func _close_pause() -> void:', 'func _on_intro_done() -> void:', 'func _on_start_battle() -> void:']:
    battle=replace_once(battle,signature+'\n',signature+'\n\tif _run_capture_input_closed(): return\n')
battle=replace_once(battle,'elif what == NOTIFICATION_WM_GO_BACK_REQUEST:\n','elif what == NOTIFICATION_WM_GO_BACK_REQUEST:\n\t\tif _run_capture_input_closed(): return\n')
put('battle.gd',battle)
root=(ROOT/'scripts/run_battle_root_state.gd').read_text(encoding='utf-8')
root=replace_once(root,'const SCHEMA := "defense_battle_root_v2"','const SCHEMA := "defense_battle_root_v3"\nconst Clock = preload("res://scripts/run_battle_clock.gd")\nconst Barrier = preload("res://scripts/run_battle_barrier.gd")\nconst ROOT_SIMULATION_CLOCK := ["_run_clock"]')
root=replace_once(root,'const PAYLOAD_FIELDS := ["values",','const PAYLOAD_FIELDS := ["simulation", "values",')
root=replace_once(root,'const ALL_DECLARATIONS := [','const ALL_DECLARATIONS := ["_run_clock", "_save_barrier", ')
root=replace_once(root,'const EXTERNAL_FIELDS := [','const EXTERNAL_FIELDS := ["_save_barrier", ')
declared=re.findall(r'^var\s+([A-Za-z_][A-Za-z_0-9]*)',battle,re.M)
old_declared=re.findall(r'^var\s+([A-Za-z_][A-Za-z_0-9]*)',(ROOT/'scripts/battle.gd').read_text(encoding='utf-8'),re.M)
assert len(declared)==172 and set(declared)==set(old_declared)|{'_run_clock','_save_barrier'}
root=re.sub(r'^const ALL_DECLARATIONS := .*$', 'const ALL_DECLARATIONS := '+json.dumps(declared),root,flags=re.M)
root=replace_once(root,'\tif _bound.has(battle): return _bad("ALREADY_BOUND")','\tif _bound.has(battle): return _bad("ALREADY_BOUND")\n\tif battle._run_clock != null: return _bad("FRESH_CLOCK_DESTINATION_REQUIRED")')
anchor='\tvar registered: Dictionary = _registry(object_to_id)\n'
root=replace_once(root,anchor,'''\tif battle._run_clock == null or battle._run_clock.get_script() != Clock: return _bad("ACTUAL_CLOCK_REQUIRED")
\tif not is_instance_valid(battle._save_barrier) or battle._save_barrier.get_script() != Barrier: return _bad("ACTUAL_BARRIER_REQUIRED")
\tvar stable: Dictionary = battle._save_barrier.health()
\tif not stable.ok: return _bad(stable.code)
\tvar simulation: Dictionary = battle._run_clock.capture()
\tif not simulation.ok: return _bad(simulation.code)
'''+anchor)
root=replace_once(root,'\tvar clocks: Dictionary = {"physics": Engine.get_physics_frames(), "process": Engine.get_process_frames(), "msec": Time.get_ticks_msec()}', '\tvar source_engine_frame: int = Engine.get_physics_frames()\n\tvar clocks: Dictionary = {"physics": int(simulation.record.cache_frame), "process": Engine.get_process_frames(), "msec": Time.get_ticks_msec()}')
root=replace_once(root,'\tvar raw: Dictionary = {"values": values,','\tvar raw: Dictionary = {"simulation": simulation.record, "values": values,')
root=replace_once(root,'if Engine.get_physics_frames() != clocks.physics or Engine.get_process_frames() != clocks.process:', 'if Engine.get_physics_frames() != source_engine_frame or Engine.get_process_frames() != clocks.process:')
root=replace_once(root,'\tvar clocks: Dictionary = _clocks(raw.clocks, raw.clock_values)\n\tif not clocks.ok: return clocks\n', '''\tvar clocks: Dictionary = _clocks(raw.clocks, raw.clock_values)
\tif not clocks.ok: return clocks
\tvar simulation: Dictionary = Clock.new().validate(raw.simulation)
\tif not simulation.ok: return _bad(simulation.code)
\tif simulation.cache_frame != raw.clocks.get("physics"): return _bad("CACHE_CLOCK_DOMAIN")
''')
start=root.index('\tif frame % 16 != int(raw.clocks.physics) % 16:')
end=root.index('\tvar pending: Dictionary = raw.values.duplicate(true)',start)
root=root[:start]+'''\tvar restored_clock: RefCounted = Clock.new()
\tvar restored: Dictionary = restored_clock.restore(raw.simulation, frame)
\tif not restored.ok: return _bad(restored.code)
'''+root[end:]
start=root.index('\tvar old_frame: int = raw.clocks.physics',root.index('func bind('))
end=root.index('\tfor name in ROOT_INPUT_CLOCK:',start)
root=root[:start]+'''\t# Cache stamps stay in the saved logical cache phase; loading never shifts
\t# buckets to the new Engine modulo and does not discard existing rows.
\tpending["_eco_lane_cache_bucket"] = raw.clock_values._eco_lane_cache_bucket
\tpending["_res_block_frame"] = raw.clock_values._res_block_frame
\tpending["_run_clock"] = restored_clock
'''+root[end:]
put('run_battle_root_state.gd',root)
sys.path.insert(0,str(ROOT/'scratchpad/stabilization_identity_20260907/parser_runtime'))
from gdtoolkit.parser import parser
parsed=[]
for p in sorted(DEST.glob('*.gd')):
    text=p.read_text(encoding='utf-8')
    if p.name=='battle.gd':
        # Existing two equality/not expressions use native Godot grammar; keep
        # source bytes and only parenthesize the parser's in-memory projection.
        text=text.replace('== not hud.touch_ui','== (not hud.touch_ui)')
    parser.parse(text)
    parsed.append(p.name)
files=[]
for p in sorted(DEST.glob('*.gd')):
    name='scripts/'+p.name; before=ROOT/name
    files.append({'path':name,'before_exists':before.exists(),'before_raw_sha256':sha(before.read_bytes()) if before.exists() else None,'candidate':p.relative_to(ROOT).as_posix(),'candidate_sha256':sha(p.read_bytes())})
(HERE/'.gdignore').write_bytes(b'\n')
(HERE/'overlay_manifest.json').write_text(json.dumps({'source_head':HEAD,'files':files},ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
(HERE/'preparation.json').write_text(json.dumps({'status':'candidate_only_unfrozen','source_head':HEAD,'parsed':parsed,'production_changed':False,'native_tested':False,'root_schema':'v3','root_fields':106,'external_fields':66,'declarations':172},indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'parsed':parsed,'production_changed':False,'native_tested':False}))
