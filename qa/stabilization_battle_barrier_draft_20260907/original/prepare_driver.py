from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
BASE=ROOT/'scratchpad/stabilization_root_native_20260907/attempt_r2_content_keys'
assert not (HERE/'freeze.json').exists()
def sha(raw): return hashlib.sha256(raw).hexdigest()
def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)
original=(BASE/'root_smoke.gd').read_text(encoding='utf-8')
driver=original.replace('battle-root-v2-native','actual-classic-battle-barrier-candidate').replace('[battle-root-v2 native QA] ','[actual classic barrier QA] ')
declared=re.findall(r'^var\s+([A-Za-z_][A-Za-z_0-9]*)',(HERE/'candidate/scripts/battle.gd').read_text(encoding='utf-8'),re.M)
driver=re.sub(r'^const FROZEN_DECLARED_NAMES := .*$', 'const FROZEN_DECLARED_NAMES := '+json.dumps(declared),driver,flags=re.M)
driver=once(driver,'var completed_cases: Array = []','''var completed_cases: Array = []
var captured_clock: Dictionary = {}
var capture_rejections: Array = []

func _barrier_ready(record: Dictionary) -> void:
\tcaptured_clock = record.duplicate(true)

func _barrier_rejected(code: String) -> void:
\tcapture_rejections.append(code)

func _wait_barrier() -> bool:
\tfor frame in range(30):
\t\tif not captured_clock.is_empty() or not capture_rejections.is_empty(): break
\t\tawait process_frame
\treturn not captured_clock.is_empty() and capture_rejections.is_empty()
''')
driver=driver.replace('var all_names: Array = root_names + Factory.EXTERNAL_FIELDS','var all_names: Array = root_names + Factory.ROOT_SIMULATION_CLOCK + Factory.EXTERNAL_FIELDS')
driver=driver.replace('"170 declarations 105 root 65 external exact", Factory.ALL_DECLARATIONS.size() == 170 and root_names.size() == 105 and Factory.EXTERNAL_FIELDS.size() == 65 and unique.size() == 170', '"172 declarations 105 values plus clock 66 external exact", Factory.ALL_DECLARATIONS.size() == 172 and root_names.size() == 105 and Factory.ROOT_SIMULATION_CLOCK.size() == 1 and Factory.EXTERNAL_FIELDS.size() == 66 and unique.size() == 172')
driver=once(driver,'\tbattle.process_mode = Node.PROCESS_MODE_DISABLED\n','\tbattle.process_mode = Node.PROCESS_MODE_INHERIT\n')
anchor='\tawait process_frame\n\tawait process_frame\n\t_check("real standard Battle paused and started once"'
replacement='''\tawait process_frame
\tawait process_frame
\tpaused = false
\tfor tick in range(120):
\t\tawait physics_frame
\t\tif tick % 30 == 0:
\t\t\t_check("new cache phase matches actual Engine at tick " + str(tick), battle._run_cache_frame() == Engine.get_physics_frames())
\tawait process_frame
\tbattle._save_barrier.capture_ready.connect(_barrier_ready)
\tbattle._save_barrier.capture_rejected.connect(_barrier_rejected)
\t_check("actual FIGHT capture request accepted", battle.request_run_capture().ok)
\tif not _check("actual controller reaches stable capture", await _wait_barrier()):
\t\tawait _finish(true); return
\t_check("actual complete physics steps recorded", int(captured_clock.next_tick) >= 120)
\t_check("real input surfaces disabled", battle.hud.process_mode == Node.PROCESS_MODE_DISABLED and battle.camera.process_mode == Node.PROCESS_MODE_DISABLED and battle.hud.is_blocking_signals())
\tbattle.hud.resume_game.emit()
\tbattle.hud.restart.emit()
\tbattle.hud.to_menu.emit()
\tbattle.hud.quit_game.emit()
\tbattle._close_pause()
\tbattle._goto_menu()
\t_check("real HUD navigation signals and callbacks cannot escape capture", paused and current_scene == battle and battle._save_barrier.health().ok)
\tvar held_tick: String = captured_clock.next_tick
\tvar held_cache: String = captured_clock.cache_frame
\tvar held_wave: float = battle.level._wave_t
\tvar initial_engine_frame: int = Engine.get_physics_frames()
\tfor frame in range(5): await process_frame
\t_check("held world remains stable while Engine advances", Engine.get_physics_frames() > initial_engine_frame and battle.level._wave_t == held_wave and battle._run_clock.capture().record.next_tick == held_tick and battle._run_cache_frame() == int(held_cache))
\t_check("real standard Battle paused and started once"'''
driver=once(driver,anchor,replacement)
driver=driver.replace('battle.level._wave_t == 120.0', 'battle.level._wave_t < 120.0 and battle.level._wave_t > 110.0')
driver=once(driver,'_check("default Rect2 retained before real grid build", battle._unit_draw_rect == Rect2())','_check("actual physics grid retained nonempty viewport", battle._unit_draw_rect.size.x > 0.0 and battle._unit_draw_rect.size.y > 0.0)')
start=driver.index('\tvar old_frame: int = raw.clocks.physics')
end=driver.index('\tvar translated_origins: Array = []',start)
driver=driver[:start]+'''\texpected["_eco_lane_cache_bucket"] = raw.clock_values._eco_lane_cache_bucket
\texpected["_res_block_frame"] = raw.clock_values._res_block_frame
\t_check(label + " restored explicit clock preserves exact phase", target._run_clock.capture().record == raw.simulation)
'''+driver[end:]
driver=driver.replace('battle._res_block_frame = Engine.get_physics_frames()','battle._res_block_frame = battle._run_cache_frame()')
driver=driver.replace('battle._eco_lane_cache_bucket = Engine.get_physics_frames() / 16','battle._eco_lane_cache_bucket = battle._run_cache_frame() / 16')
driver=once(driver,'\tawait _finish()\n','''\t_check("actual capture releases back to running", battle._save_barrier.release_capture().ok and not paused)
\tfor tick in range(6): await physics_frame
\tawait process_frame
\t_check("original process cache includes elapsed held Engine frames", battle._run_cache_frame() == Engine.get_physics_frames())
\tbattle._open_pause()
\t_check("original user pause can still open", paused)
\tcaptured_clock.clear()
\t_check("capture from preexisting user pause accepted", battle.request_run_capture().ok)
\tif not _check("preexisting pause reaches stable capture", await _wait_barrier()):
\t\tawait _finish(true); return
\t_check("release preserves user pause", battle._save_barrier.release_capture().ok and paused)
\tawait _finish()
''')
old_scope='One true paused standard Battle capture; real codec JSON; 105 root fields bound into detached blocked Battle. Original viewport/visual consumer; shared identity maps to fresh real Unit shells. Map projection shared read-only, not restored. No whole graph, activation, cross-process or PCK claim.'
new_scope='Actual classic Battle runs at least 120 physics callbacks, captures through its controller, blocks HUD/camera input, drains paused deferred/free phase, and retains explicit cache phase plus 105 root values through JSON and detached bind. Source release/user-pause behavior checked. No whole world factory, cross-process gameplay, actual Projectile/LiBrawnAxes damage scenario, disk or player menu claim.'
driver=once(driver,old_scope,new_scope)
(HERE/'barrier_smoke.gd').write_text(driver,encoding='utf-8',newline='\n')
sys.path.insert(0,str(ROOT/'scratchpad/stabilization_identity_20260907/parser_runtime'))
from gdtoolkit.parser import parser
parser.parse(driver)
(HERE/'HANDOFF.md').write_text('''# Actual classic Battle barrier candidate

Four-file isolated overlay: Battle, run_battle_root_state v3, two new clock/gate
modules. No production changes. Uses accepted 2e40c4a modules as its base.

The complete-step serial and legacy cache phase are separate. New-game cache
queries remain equal to the current process Engine frame including INTRO, input
queries and ordinary user pause. Capture holds that phase; source release catches
up its existing anchor, while restored activation establishes a fresh anchor at
the saved phase. Existing AI/sep counters, passes, RNG and 60Hz remain unchanged.

The controller disables all current HUD nodes/signals and camera input, clears
only uncommitted gestures, gates Battle navigation/input callbacks, and pauses
after current physics callbacks. The next process boundary follows a paused
deferred/free drain; health rejects live processing, queued nodes, foreign thread
groups, physics priority edges, unsupported modes and faults. Full captures are
synchronous. Only official classic 30-wave FIGHT is supported here.

Driver barrier_smoke.gd -> tools/stabilization_battle_barrier/barrier_smoke.gd;
suite actual-classic-battle-barrier-candidate;
prefix [actual classic barrier QA] followed by a space.

Native validation remains pending. The driver runs the actual Battle and checks
root v3 JSON/detached binds and actual gate/release, but does not yet cover real
Projectile/LiBrawnAxes damage or campaign deferred tasks. Full world construction,
all effects, rendering state, disk transactions and player menu still need work.
Do not promote based on this preparation or the earlier scheduler fixture alone.
''',encoding='utf-8',newline='\n')
files=['prepare.py','prepare_driver.py','barrier_smoke.gd','HANDOFF.md','overlay_manifest.json','preparation.json']
files += [p.relative_to(HERE).as_posix() for p in sorted((HERE/'candidate').rglob('*.gd'))]
freeze={'status':'native_pending','source_head':'2e40c4afd5d3bce22a8204bed2c1f903fc046ff5','production_changed':False,'inputs':{name:sha((HERE/name).read_bytes()) for name in files}}
(HERE/'freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'freeze_sha256':sha((HERE/'freeze.json').read_bytes()),'files':len(files)}))
