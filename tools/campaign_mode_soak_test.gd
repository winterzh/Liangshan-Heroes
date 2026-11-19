extends SceneTree
## Real-renderer, long-running lifecycle fixture for campaign and free-play modes.
## It deliberately uses the normal Battle + HUD start path, never a synthetic scene.

const MENU_SCENE := "res://scenes/menu.tscn"
const BATTLE_SCENE := "res://scenes/main.tscn"
const SCENE_TIMEOUT_USEC := 120_000_000

const ROUTE := [
	{"mode": "campaign", "level_id": "level1"},
	{"mode": "arena", "level_id": "arena"},
	{"mode": "skirmish", "level_id": "skirmish"},
	{"mode": "skirmish_ai", "level_id": "skirmish_ai"},
	{"mode": "custom_defense", "level_id": "custom_defense"},
	{"mode": "campaign", "level_id": "level5"},
]
const DEFAULT_DURATION_SECONDS := 1800.0
const MIN_ACCEPTANCE_SECONDS := 1800.0
const DEFAULT_DWELL_SECONDS := 6.0
const MINUTE_USEC := 60_000_000
const MIB := 1024.0 * 1024.0
const FRAME_P95_LIMIT_MS := 16.7
const FRAME_P99_LIMIT_MS := 33.3
const REPORT_NAME := "campaign_mode_soak.json"

# A warm baseline is captured after the first complete six-scene route. By then
# every tested level script and its common art have entered ResourceLoader once.
# These tolerances gate retained growth after later scenes have been freed; live
# scene peaks are reported separately and are not compared to an empty scene.
const RECOVERY_TOLERANCE := {
	"working_set_bytes": 128.0 * MIB,
	"private_bytes": 128.0 * MIB,
	"godot_static_bytes": 64.0 * MIB,
	"object_count": 512.0,
	"resource_count": 128.0,
	"node_count": 32.0,
	"orphan_node_count": 2.0,
	"render_texture_bytes": 32.0 * MIB,
	"render_buffer_bytes": 64.0 * MIB,
	"render_video_bytes": 64.0 * MIB,
}

var _checks: Array = []
var _failures: Array[String] = []
var _minute_samples: Array = []
var _transitions: Array = []
var _cleanup_samples: Array = []
var _visit_counts := {}
var _route_visit_counts := {}
var _report := {}
var _output_dir := ""
var _duration_seconds := DEFAULT_DURATION_SECONDS
var _dwell_seconds := DEFAULT_DWELL_SECONDS
var _acceptance_eligible := false
var _started_at := ""
var _start_usec := 0
var _end_usec := 0
var _bucket_start_usec := 0
var _next_minute_usec := 0
var _last_frame_usec := 0
var _minute_frames: Array[float] = []
var _minute_draw_sum := 0.0
var _minute_draw_max := 0.0
var _minute_frame_count := 0
var _stage_timing_enabled := false
var _mount_trace_enabled := false
var _mount_trace := {}
var _mount_samples: Array[Dictionary] = []
var _stage_frame_samples := {}
var _active_stage_frames := {}
var _current_battle = null
var _current_mode := "idle"
var _current_level_id := ""
var _cycle := 0
var _baseline := {}
var _warm_baseline := {}
var _end_snapshot := {}
var _save_existed_before := false
var _save_before_bytes := PackedByteArray()
var _process_probe_failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, name: String, detail := "") -> void:
	_checks.append({"name": name, "passed": ok, "detail": detail})
	print("[soak-check] ", "PASS " if ok else "FAIL ", name, " ", detail)
	if not ok:
		_failures.append(name)


func _env_float(name: String, fallback: float) -> float:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty() or not raw.is_valid_float():
		return fallback
	return float(raw)


func _save_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes("user://campaign.cfg") \
		if FileAccess.file_exists("user://campaign.cfg") else PackedByteArray()


func _save_description(exists: bool, bytes: PackedByteArray) -> Dictionary:
	return {
		"exists": exists,
		"size_bytes": bytes.size(),
		"sha256": bytes.hex_encode().sha256_text() if exists else "absent",
	}


func _percentile(values: Array[float], q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * q)) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _resource_metrics() -> Dictionary:
	return {
		"godot_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"godot_static_peak_bytes": Performance.get_monitor(Performance.MEMORY_STATIC_MAX),
		"object_count": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resource_count": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphan_node_count": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"render_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"render_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"render_video_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"render_texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"render_buffer_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED),
	}


func _process_memory() -> Dictionary:
	var fallback := {
		"query_ok": false,
		"working_set_bytes": -1.0,
		"private_bytes": -1.0,
		"virtual_bytes": -1.0,
		"peak_working_set_bytes": -1.0,
		"source": "powershell Get-Process for this Godot PID",
	}
	if OS.get_name() != "Windows":
		_process_probe_failures += 1
		fallback["error"] = "Windows process counters are unavailable on " + OS.get_name()
		return fallback
	var output: Array = []
	var command := "$p=Get-Process -Id %d -ErrorAction Stop; [Console]::Out.Write(('{0},{1},{2},{3}' -f $p.WorkingSet64,$p.PrivateMemorySize64,$p.VirtualMemorySize64,$p.PeakWorkingSet64))" % OS.get_process_id()
	var code := OS.execute("powershell.exe", PackedStringArray([
		"-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command,
	]), output, true, false)
	var raw := String(output[0]).strip_edges() if not output.is_empty() else ""
	var values := raw.split(",", false)
	if code != 0 or values.size() != 4:
		_process_probe_failures += 1
		fallback["error"] = "exit=%d output=%s" % [code, raw]
		return fallback
	fallback["query_ok"] = true
	fallback["working_set_bytes"] = float(values[0])
	fallback["private_bytes"] = float(values[1])
	fallback["virtual_bytes"] = float(values[2])
	fallback["peak_working_set_bytes"] = float(values[3])
	return fallback


func _unit_counts() -> Dictionary:
	var counts := {
		"scene_units": 0,
		"alive_units": 0,
		"mobile_units": 0,
		"buildings": 0,
		"resources": 0,
		"liang": 0,
		"guan": 0,
		"visible": 0,
	}
	if _current_battle == null or not is_instance_valid(_current_battle):
		return counts
	for unit in _current_battle.units:
		if not is_instance_valid(unit):
			continue
		counts.scene_units += 1
		if unit.hp > 0.0:
			counts.alive_units += 1
		if unit.is_building:
			counts.buildings += 1
		elif unit.is_resource:
			counts.resources += 1
		else:
			counts.mobile_units += 1
		if unit.faction == 0:
			counts.liang += 1
		elif unit.faction == 1:
			counts.guan += 1
		if unit.visible and unit.is_visible_in_tree():
			counts.visible += 1
	return counts


func _snapshot(include_process_memory: bool) -> Dictionary:
	var snapshot := {
		"elapsed_seconds": maxf(0.0, float(Time.get_ticks_usec() - _start_usec) / 1_000_000.0) if _start_usec > 0 else 0.0,
		"mode": _current_mode,
		"level_id": _current_level_id,
		"cycle": _cycle,
		"scene_count": 1 if _current_battle != null and is_instance_valid(_current_battle) else 0,
		"root_child_count": root.get_child_count(),
		"phase": int(_current_battle.phase) if _current_battle != null and is_instance_valid(_current_battle) else -1,
		"units": _unit_counts(),
		"resources": _resource_metrics(),
	}
	if include_process_memory:
		snapshot["process_memory"] = _process_memory()
	return snapshot


func _tag_frame_stage(stage: String, mode := "", level_id := "") -> void:
	if not _stage_timing_enabled:
		return
	var key := "%s/%s/%s" % [stage, mode, level_id]
	if not _stage_frame_samples.has(key):
		_stage_frame_samples[key] = {
			"stage": stage, "mode": mode, "level_id": level_id,
			"frames": 0, "over_16_7_ms": 0, "over_33_3_ms": 0, "worst_ms": 0.0,
		}
	_active_stage_frames = _stage_frame_samples[key]


func _record_stage_frame(frame_ms: float) -> void:
	_active_stage_frames.frames += 1
	if frame_ms > FRAME_P95_LIMIT_MS:
		_active_stage_frames.over_16_7_ms += 1
	if frame_ms > FRAME_P99_LIMIT_MS:
		_active_stage_frames.over_33_3_ms += 1
	_active_stage_frames.worst_ms = maxf(_active_stage_frames.worst_ms, frame_ms)


func _check_stage_frame_coverage() -> void:
	var total := 0
	for sample: Dictionary in _minute_samples:
		total += int(sample.rendered_frames)
	var tagged := 0
	for stage: Dictionary in _stage_frame_samples.values():
		tagged += int(stage.frames)
	_check(tagged == total and total > 0, "each sampled render interval has exactly one diagnostic stage",
		"tagged=%d sampled=%d" % [tagged, total])


func _trace_node_added(node: Node) -> void:
	if _mount_trace.is_empty() or _mount_trace.scene_ready_us >= 0:
		return
	var elapsed := Time.get_ticks_usec() - int(_mount_trace.origin_us)
	if node.scene_file_path == BATTLE_SCENE and node.get_parent() == root:
		_mount_trace.battle_attached_us = elapsed
	elif _mount_trace.battle_attached_us >= 0:
		if _mount_trace.map_attached_us < 0 and node is GameMap:
			_mount_trace.map_attached_us = elapsed
		elif _mount_trace.hud_attached_us < 0 and node is HUD:
			_mount_trace.hud_attached_us = elapsed
		elif _mount_trace.first_unit_us < 0 and node is Unit:
			_mount_trace.first_unit_us = elapsed


func _trace_scene_changed() -> void:
	if not _mount_trace.is_empty() and _mount_trace.battle_attached_us >= 0:
		_mount_trace.scene_ready_us = Time.get_ticks_usec() - int(_mount_trace.origin_us)


func _trace_drawing() -> void:
	if _mount_trace.is_empty() or _mount_trace.first_battle_frame_us >= 0:
		return
	var elapsed := Time.get_ticks_usec() - int(_mount_trace.origin_us)
	if _mount_trace.first_overlay_us < 0:
		_mount_trace.first_overlay_us = elapsed
	if elapsed - int(_mount_trace.last_draw_us) > int(_mount_trace.gap_end_us) - int(_mount_trace.gap_start_us):
		_mount_trace.gap_start_us = _mount_trace.last_draw_us
		_mount_trace.gap_end_us = elapsed
	_mount_trace.last_draw_us = elapsed
	if _mount_trace.scene_ready_us >= 0:
		_mount_trace.first_battle_frame_us = elapsed


func _report_mount_trace() -> void:
	var ordered := ["first_overlay_us", "battle_attached_us", "map_attached_us", "hud_attached_us",
		"first_unit_us", "scene_ready_us", "first_battle_frame_us"]
	var last := 0
	for stamp in ordered:
		var current := int(_mount_trace[stamp])
		if current < last or current <= 0:
			_check(false, "native mount trace has ordered milestones", JSON.stringify(_mount_trace))
			break
		last = current
	_mount_trace.erase("origin_us")
	_mount_trace.erase("last_draw_us")
	_mount_samples.append(_mount_trace)
	_mount_trace = {}


func _record_render_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		var frame_ms := float(now - _last_frame_usec) / 1000.0
		# A negative/zero interval would be a clock failure. Retain long transition
		# frames: scene construction and teardown are part of this lifecycle test.
		if frame_ms > 0.0:
			_minute_frames.append(frame_ms)
			_minute_frame_count += 1
			if _stage_timing_enabled:
				_record_stage_frame(frame_ms)
			var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			_minute_draw_sum += draw_calls
			_minute_draw_max = maxf(_minute_draw_max, draw_calls)
	_last_frame_usec = now
	if _start_usec > 0 and now >= _next_minute_usec:
		_finalize_minute(false)
		# Exclude the once-per-minute external process-counter probe itself from
		# the next rendered-frame interval.
		_last_frame_usec = Time.get_ticks_usec()


func _render_tick() -> void:
	await RenderingServer.frame_post_draw
	_record_render_frame()


func _finalize_minute(partial: bool) -> void:
	var now := Time.get_ticks_usec()
	var bucket_seconds := float(now - _bucket_start_usec) / 1_000_000.0
	if _minute_frame_count == 0 and bucket_seconds < 0.05:
		return
	var sample := _snapshot(true)
	sample["minute"] = _minute_samples.size() + 1
	sample["partial"] = partial
	sample["bucket_seconds"] = bucket_seconds
	sample["rendered_frames"] = _minute_frame_count
	sample["average_frame_ms"] = _mean(_minute_frames)
	sample["p95_frame_ms"] = _percentile(_minute_frames, 0.95)
	sample["p99_frame_ms"] = _percentile(_minute_frames, 0.99)
	sample["worst_frame_ms"] = _percentile(_minute_frames, 1.0)
	sample["average_draw_calls"] = _minute_draw_sum / float(maxi(1, _minute_frame_count))
	sample["peak_draw_calls"] = _minute_draw_max
	_minute_samples.append(sample)
	print("[soak-minute] ", JSON.stringify({
		"minute": sample.minute,
		"partial": partial,
		"mode": sample.mode,
		"p95_ms": sample.p95_frame_ms,
		"p99_ms": sample.p99_frame_ms,
		"working_set": sample.process_memory.working_set_bytes,
		"nodes": sample.resources.node_count,
		"textures": sample.resources.render_texture_bytes,
	}))
	_minute_frames = []
	_minute_draw_sum = 0.0
	_minute_draw_max = 0.0
	_minute_frame_count = 0
	_bucket_start_usec = now
	while _next_minute_usec <= now:
		_next_minute_usec += MINUTE_USEC


func _configure_mode(fixture: Dictionary) -> void:
	var campaign = root.get_node("Campaign")
	for key in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]:
		campaign.set(key, false)
	campaign.custom_config = {}
	campaign.scenario_data = {}
	campaign.ai_friendly = false
	campaign.scale_on = false
	campaign.ai_difficulty = "normal"
	campaign.victory_mode = "conquest"
	campaign.defense_waves = 30
	campaign.defense_hero_cap = 4
	campaign.defense_random = false
	var mode := String(fixture.mode)
	if mode == "campaign":
		campaign.current = campaign.index_for_id(String(fixture.level_id))
	else:
		campaign.set(mode, true)
	if mode == "custom_defense":
		campaign.custom_config = {"name": "稳定性据守"}


func _activate_live_mode(battle, mode: String) -> Dictionary:
	# Use current authored actions and player orders. The defense fixture expires
	# only the first wave timer; the ordinary level.process owns wave progression.
	match mode:
		"arena":
			var before: int = battle.enemies_alive()
			battle.level.arena_spawn_troops(battle)
			var spawned: int = battle.enemies_alive() - before
			return {"passed": spawned == 50, "action": "authored arena troop button", "spawned": spawned}
		"skirmish", "custom_defense":
			var ready: bool = battle.level._started and battle.level._wave == 0
			if ready: battle.level._wave_t = 0.0
			return {"passed": ready, "action": "expire first defense timer; normal process spawns wave"}
		"skirmish_ai":
			var target = battle.level.hall
			var ordered := 0
			if target != null and is_instance_valid(target):
				for unit in battle.units:
					if is_instance_valid(unit) and unit.faction == 1 and not unit.is_building \
							and not unit.is_resource and not unit.is_worker and unit.hp > 0.0:
						unit.order_amove(target.position)
						ordered += 1
			return {"passed": ordered > 0, "action": "official opening soldiers attack-move; workers keep gathering", "ordered": ordered}
		"campaign":
			if String(battle.level.id()) == "level5":
				var actor = battle.find_unit("ruan_xiaoqi_boat")
				var action_id := "gao_lure_side"
				var ready: bool = is_instance_valid(actor) and actor.hp > 0.0 \
					and battle.mission != null and battle.mission.actions.has(action_id)
				if not ready:
					return {"passed": false, "action": "current level5 side-harbour player task", "reason": "actor or task missing"}
				var destination: Vector2 = battle.map.cell_to_world(battle.mission.actions[action_id].cell)
				battle._set_selection([actor])
				battle._issue_order(battle.to_screen(destination))
				return {"passed": actor.mission_order_active and actor.mission_order_target.distance_to(destination) < 1.0,
					"action": "select Ruan Xiaoqi and right-click gao_lure_side marker", "actor": actor.key, "task": action_id}
			if String(battle.level.id()) == "level1":
				return {"passed": battle.level.st == battle.level.MARCH and not battle.level.convoy.is_empty(),
					"action": "normal authored Huangnigang convoy march"}
	return {"passed": false, "action": "unsupported fixture"}


func _activity_snapshot(battle) -> Dictionary:
	# Store values and instance IDs, not Node references that would mask release.
	var units := {}
	for unit in battle.units:
		if is_instance_valid(unit) and unit.hp > 0.0 and not unit.is_building and not unit.is_resource:
			units[unit.get_instance_id()] = {"position": unit.position, "hp": unit.hp}
	return {"units": units, "physics_frame": Engine.get_physics_frames()}


func _activity_evidence(battle, initial: Dictionary) -> Dictionary:
	var moved := 0
	var damaged := 0
	var dead_or_removed: int = initial.units.size()
	var max_distance := 0.0
	for unit in battle.units:
		if not is_instance_valid(unit) or not initial.units.has(unit.get_instance_id()): continue
		dead_or_removed -= 1
		var before: Dictionary = initial.units[unit.get_instance_id()]
		var distance: float = unit.position.distance_to(before.position)
		max_distance = maxf(max_distance, distance)
		if distance > 1.0: moved += 1
		if unit.hp < float(before.hp): damaged += 1
	var physics_steps: int = Engine.get_physics_frames() - int(initial.physics_frame)
	var evidence := {"physics_steps": physics_steps, "moved_units": moved, "damaged_units": damaged,
		"removed_units": dead_or_removed, "max_distance": max_distance,
		"passed": physics_steps > 0 and (moved > 0 or damaged > 0 or dead_or_removed > 0)}
	if String(battle.level.id()) in ["skirmish", "custom_defense"]:
		evidence["wave"] = battle.level._wave
		evidence["enemies_alive"] = battle.enemies_alive()
		evidence.passed = evidence.passed and battle.level._wave >= 1 and battle.enemies_alive() > 0
	elif String(battle.level.id()) == "level5":
		var actor = battle.find_unit("ruan_xiaoqi_boat")
		var actor_distance := 0.0
		if is_instance_valid(actor) and initial.units.has(actor.get_instance_id()):
			actor_distance = actor.position.distance_to(initial.units[actor.get_instance_id()].position)
		evidence["task_actor_distance"] = actor_distance
		evidence["lure_started"] = battle.level.lure_started
		evidence["task_done"] = bool(battle.mission.actions.gao_lure_side.done)
		evidence["first_wave_sent"] = bool(battle.level.waves[0].sent)
		# The regular six-second dwell may end while the boat is still en route;
		# report completion separately instead of claiming the lure was completed.
		evidence.passed = evidence.passed and actor_distance > 1.0
	return evidence


func _await_scene(path: String) -> bool:
	var deadline := Time.get_ticks_usec() + SCENE_TIMEOUT_USEC
	while Time.get_ticks_usec() < deadline:
		await _render_tick()
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path and current_scene.is_node_ready():
			return true
	return false


func _dispose_battle(battle, transition: Dictionary) -> bool:
	var scene_ref: WeakRef = weakref(battle)
	var level_ref: WeakRef = weakref(battle.level)
	var mission_ref: WeakRef = weakref(battle.mission) if battle.mission != null else null
	var map_ref: WeakRef = weakref(battle.map)
	var hud_ref: WeakRef = weakref(battle.hud)
	var world_ref: WeakRef = weakref(battle.world)
	var camera_ref: WeakRef = weakref(battle.camera)
	var units_root_ref: WeakRef = weakref(battle.units_root)
	var unit_ref: WeakRef = weakref(battle.units[0]) if not battle.units.is_empty() else null
	_current_battle = null
	_current_mode = "cleanup"
	_tag_frame_stage("return", transition.mode, transition.level_id)
	battle.hud.to_menu.emit()
	battle = null
	var menu_ready := await _await_scene(MENU_SCENE)
	_check(menu_ready and not paused and Engine.time_scale == 1.0, "return reaches the original unpaused menu")
	if not menu_ready:
		return false
	await _render_tick()
	var released := scene_ref.get_ref() == null and level_ref.get_ref() == null \
		and (mission_ref == null or mission_ref.get_ref() == null) and map_ref.get_ref() == null \
		and hud_ref.get_ref() == null and world_ref.get_ref() == null \
		and camera_ref.get_ref() == null and units_root_ref.get_ref() == null \
		and (unit_ref == null or unit_ref.get_ref() == null)
	transition["release"] = {
		"passed": released,
		"scene": scene_ref.get_ref() == null,
		"level": level_ref.get_ref() == null,
		"mission": mission_ref == null or mission_ref.get_ref() == null,
		"map": map_ref.get_ref() == null,
		"hud": hud_ref.get_ref() == null,
		"world": world_ref.get_ref() == null,
		"camera": camera_ref.get_ref() == null,
		"units_root": units_root_ref.get_ref() == null,
		"sample_unit": unit_ref == null or unit_ref.get_ref() == null,
	}
	var cleanup := _snapshot(false)
	transition["post_cleanup"] = cleanup
	_cleanup_samples.append(cleanup)
	_check(released, "%s transition %d releases scene and key nodes" % [transition.mode, _transitions.size() + 1], JSON.stringify(transition.release))
	return true


func _run_fixture(fixture: Dictionary) -> bool:
	_configure_mode(fixture)
	var mode := String(fixture.mode)
	_current_mode = "building:" + mode
	_current_level_id = String(fixture.level_id)
	_tag_frame_stage("mount", mode, _current_level_id)
	var began := Time.get_ticks_usec()
	if _mount_trace_enabled:
		_mount_trace = {"level_id": _current_level_id, "mode": mode, "origin_us": began,
			"first_overlay_us": -1, "battle_attached_us": -1, "map_attached_us": -1,
			"hud_attached_us": -1, "first_unit_us": -1, "scene_ready_us": -1,
			"first_battle_frame_us": -1, "last_draw_us": 0, "gap_start_us": 0, "gap_end_us": 0}
	seed(5_088_120 + _transitions.size())
	current_scene.call("_launch", _current_level_id if mode == "campaign" else "")
	var battle_ready := await _await_scene(BATTLE_SCENE)
	_check(battle_ready, "%s enters the battle scene through the menu" % mode)
	if not battle_ready:
		return false
	var battle = current_scene
	var battle_initialized: bool = battle.hud != null and battle.level != null and battle.gameplay_rng_fault().is_empty()
	_check(battle_initialized, "%s has an initialized HUD, level and gameplay RNG" % mode)
	if not battle_initialized:
		return false
	_current_battle = battle
	_tag_frame_stage("start", mode, _current_level_id)
	if battle.hud._intro_root != null:
		battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	await process_frame
	await _render_tick()
	_current_mode = mode
	_current_level_id = String(battle.level.id())
	if _mount_trace_enabled:
		_report_mount_trace()
	_tag_frame_stage("play", mode, _current_level_id)
	var expected_id := String(fixture.level_id)
	var nodes_ok := battle.map != null and battle.hud != null and battle.world != null \
		and battle.camera != null and battle.units_root != null
	var start_ok: bool = String(battle.level.id()) == expected_id and battle.phase == battle.Phase.FIGHT and nodes_ok
	var activation := _activate_live_mode(battle, mode)
	var activity_start := _activity_snapshot(battle)
	var transition := {
		"index": _transitions.size() + 1,
		"cycle": _cycle,
		"mode": mode,
		"level_id": String(battle.level.id()),
		"expected_level_id": expected_id,
		"normal_start_passed": start_ok,
		"activation": activation,
		"build_and_start_ms": float(Time.get_ticks_usec() - began) / 1000.0,
		"units_at_start": _unit_counts(),
	}
	_check(start_ok, "%s constructs expected level and enters normal FIGHT" % mode, JSON.stringify({
		"actual": battle.level.id(), "expected": expected_id, "phase": int(battle.phase), "nodes": nodes_ok,
	}))
	_check(bool(activation.passed), "%s/%s accepts a current authored activity" % [mode, expected_id], JSON.stringify(activation))
	_visit_counts[mode] = int(_visit_counts.get(mode, 0)) + 1
	var route_key := mode + ":" + expected_id
	_route_visit_counts[route_key] = int(_route_visit_counts.get(route_key, 0)) + 1
	var live_started := Time.get_ticks_usec()
	# Complete the dwell of every started fixture, even at the overall deadline.
	# A truncated last scene cannot provide a meaningful activity/release sample.
	var live_deadline := live_started + int(_dwell_seconds * 1_000_000.0)
	while Time.get_ticks_usec() < live_deadline:
		await _render_tick()
	transition["live_seconds"] = float(Time.get_ticks_usec() - live_started) / 1_000_000.0
	transition["phase_at_end"] = int(battle.phase)
	transition["units_at_end"] = _unit_counts()
	transition["activity"] = _activity_evidence(battle, activity_start)
	_check(bool(transition.activity.passed), "%s/%s executes live simulation activity" % [mode, expected_id], JSON.stringify(transition.activity))
	if not await _dispose_battle(battle, transition):
		return false
	_transitions.append(transition)
	print("[soak-transition] ", JSON.stringify({
		"index": transition.index,
		"cycle": transition.cycle,
		"mode": transition.mode,
		"level": transition.level_id,
		"live_seconds": transition.live_seconds,
		"released": transition.release.passed,
	}))
	return true


func _series_for(metric: String, source: Array) -> Array[float]:
	var values: Array[float] = []
	for snapshot in source:
		if metric in ["working_set_bytes", "private_bytes"]:
			var process: Dictionary = snapshot.get("process_memory", {})
			if bool(process.get("query_ok", false)):
				values.append(float(process.get(metric, -1.0)))
		else:
			var resources: Dictionary = snapshot.get("resources", {})
			if resources.has(metric):
				values.append(float(resources[metric]))
	return values


func _trend(values: Array[float], epsilon: float) -> Dictionary:
	var increases := 0
	var decreases := 0
	var flat := 0
	for i in range(1, values.size()):
		var delta := values[i] - values[i - 1]
		if delta > epsilon:
			increases += 1
		elif delta < -epsilon:
			decreases += 1
		else:
			flat += 1
	var steps := maxi(0, values.size() - 1)
	var net: float = values.back() - values.front() if values.size() >= 2 else 0.0
	var near_monotonic := steps >= 5 and decreases <= maxi(1, int(floor(float(steps) * 0.1))) \
		and increases >= int(ceil(float(steps) * 0.7))
	return {
		"samples": values.size(),
		"first": values.front() if not values.is_empty() else 0.0,
		"last": values.back() if not values.is_empty() else 0.0,
		"net": net,
		"increases": increases,
		"decreases": decreases,
		"flat": flat,
		"near_monotonic": near_monotonic,
	}


func _metric_value(snapshot: Dictionary, metric: String) -> float:
	if metric in ["working_set_bytes", "private_bytes"]:
		return float(snapshot.get("process_memory", {}).get(metric, -1.0))
	return float(snapshot.get("resources", {}).get(metric, -1.0))


func _analyse_stability() -> Dictionary:
	var analysis := {}
	var comparable_cleanup := _cleanup_samples.slice(ROUTE.size()) \
		if _cleanup_samples.size() > ROUTE.size() else _cleanup_samples
	# Retained growth starts at the same warmed state used for recovery. A
	# minute sampled before the first route finishes can still inform the peak.
	var warm_elapsed := float(_warm_baseline.elapsed_seconds)
	var warmed_process_samples := [_warm_baseline]
	warmed_process_samples.append_array(_minute_samples.filter(
		func(sample): return float(sample.elapsed_seconds) > warm_elapsed))
	for metric in RECOVERY_TOLERANCE:
		var process_metric: bool = metric in ["working_set_bytes", "private_bytes"]
		var source: Array = warmed_process_samples if process_metric else comparable_cleanup
		var epsilon := 1.0 * MIB if metric.contains("bytes") else 1.0
		var trend := _trend(_series_for(metric, source), epsilon)
		var values := _series_for(metric, _minute_samples if process_metric else comparable_cleanup)
		var warm := _metric_value(_warm_baseline, metric)
		var ending := _metric_value(_end_snapshot, metric)
		var peak := maxf(warm, ending)
		for value in values:
			peak = maxf(peak, value)
		if metric == "working_set_bytes":
			for sample in _minute_samples:
				var process: Dictionary = sample.get("process_memory", {})
				if bool(process.get("query_ok", false)):
					peak = maxf(peak, float(process.get("peak_working_set_bytes", peak)))
		var tolerance := float(RECOVERY_TOLERANCE[metric])
		var recovery_ok := warm >= 0.0 and ending >= 0.0 and ending <= warm + tolerance
		var monotonic_leak := bool(trend.near_monotonic) and float(trend.net) > tolerance
		analysis[metric] = {
			"warm_baseline": warm,
			"peak": peak,
			"end": ending,
			"end_delta_from_warm": ending - warm,
			"recovered_from_peak": peak - ending,
			"tolerance": tolerance,
			"recovery_passed": recovery_ok,
			"monotonic_growth_detected": monotonic_leak,
			"trend": trend,
		}
		_check(recovery_ok, metric + " returns within warm-baseline tolerance", JSON.stringify(analysis[metric]))
		_check(not monotonic_leak, metric + " has no sustained monotonic growth above tolerance", JSON.stringify(trend))
	return analysis


func _performance_summary() -> Dictionary:
	var complete: Array = _minute_samples.filter(func(sample): return not bool(sample.partial) and float(sample.bucket_seconds) >= 55.0)
	var max_p95 := 0.0
	var max_p99 := 0.0
	var max_worst := 0.0
	var max_draw := 0.0
	for sample in complete:
		max_p95 = maxf(max_p95, float(sample.p95_frame_ms))
		max_p99 = maxf(max_p99, float(sample.p99_frame_ms))
		max_worst = maxf(max_worst, float(sample.worst_frame_ms))
		max_draw = maxf(max_draw, float(sample.peak_draw_calls))
	return {
		"complete_minute_buckets": complete.size(),
		"max_minute_p95_ms": max_p95,
		"max_minute_p99_ms": max_p99,
		"worst_frame_ms": max_worst,
		"peak_draw_calls": max_draw,
		"p95_limit_ms": FRAME_P95_LIMIT_MS,
		"p99_limit_ms": FRAME_P99_LIMIT_MS,
	}


func _reset_campaign_flags() -> void:
	var campaign = root.get_node("Campaign")
	for key in ["arena", "skirmish", "skirmish_ai", "custom_defense", "scenario"]:
		campaign.set(key, false)
	campaign.custom_config = {}
	campaign.scenario_data = {}
	campaign.ai_friendly = false
	campaign.scale_on = false


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var file := FileAccess.open(_output_dir.path_join(REPORT_NAME), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write soak report: " + _output_dir.path_join(REPORT_NAME))
		return
	file.store_string(JSON.stringify(_report, "  ") + "\n")
	file.close()


func _early_exit(reason: String, code: int) -> void:
	_report = {
		"passed": false,
		"runtime_checks_passed": false,
		"acceptance_eligible": false,
		"failures": _failures,
		"checks": _checks,
		"reason": reason,
		"transition_count": _transitions.size(),
		"renderer": {
			"display": DisplayServer.get_name(),
			"driver": RenderingServer.get_current_rendering_driver_name(),
			"api": RenderingServer.get_video_adapter_api_version(),
			"method": RenderingServer.get_current_rendering_method(),
		},
		"scope": "No human playtest or balance conclusion. Exit warnings are appended by run_campaign_mode_soak.ps1 after this process exits.",
	}
	_write_report()
	quit(code)


func _run() -> void:
	OS.set_environment("CAMPAIGN_QA", "1")
	OS.set_environment("SMOKE_TEST", "")
	_output_dir = OS.get_environment("CAMPAIGN_SOAK_OUT")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://qa/campaign_mode_soak")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	_duration_seconds = maxf(1.0, _env_float("CAMPAIGN_SOAK_SECONDS", DEFAULT_DURATION_SECONDS))
	_dwell_seconds = clampf(_env_float("CAMPAIGN_SOAK_DWELL_SECONDS", DEFAULT_DWELL_SECONDS), 2.0, 30.0)
	_acceptance_eligible = _duration_seconds >= MIN_ACCEPTANCE_SECONDS
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	root.get_node("Settings").game_speed = 1.0
	AudioServer.set_bus_mute(0, true)
	await RenderingServer.frame_post_draw
	var driver: String = RenderingServer.get_current_rendering_driver_name()
	var api: String = RenderingServer.get_video_adapter_api_version()
	var method: String = RenderingServer.get_current_rendering_method()
	var renderer_ok: bool = DisplayServer.get_name() != "headless" and driver == "vulkan" \
		and method == "forward_plus" and root.size == Vector2i(1280, 720)
	_check(DisplayServer.get_name() != "headless", "soak refuses a headless display", DisplayServer.get_name())
	_check(driver == "vulkan" and method == "forward_plus", "soak uses Vulkan forward_plus", driver + " " + api + " / " + method)
	_check(root.size == Vector2i(1280, 720), "viewport is exactly 1280x720", str(root.size))
	if not renderer_ok:
		_early_exit("A real 1280x720 Vulkan forward_plus renderer is required.", 2)
		return

	_save_existed_before = FileAccess.file_exists("user://campaign.cfg")
	_save_before_bytes = _save_bytes()
	_reset_campaign_flags()
	if change_scene_to_file(MENU_SCENE) != OK:
		_early_exit("Could not open the game menu.", 2)
		return
	await scene_changed
	if not is_instance_valid(current_scene) or current_scene.scene_file_path != MENU_SCENE:
		_early_exit("The game did not reach the main menu.", 2)
		return
	_mount_trace_enabled = OS.get_environment("CAMPAIGN_SOAK_MOUNT_TRACE") == "1"
	if _mount_trace_enabled:
		node_added.connect(_trace_node_added)
		scene_changed.connect(_trace_scene_changed)
		RenderingServer.frame_post_draw.connect(_trace_drawing)
	_started_at = Time.get_datetime_string_from_system(false, true)
	_start_usec = Time.get_ticks_usec()
	_end_usec = _start_usec + int(_duration_seconds * 1_000_000.0)
	_bucket_start_usec = _start_usec
	_next_minute_usec = _start_usec + MINUTE_USEC
	_last_frame_usec = _start_usec
	_stage_timing_enabled = OS.get_environment("CAMPAIGN_SOAK_STAGE_TIMING") == "1"
	_tag_frame_stage("menu")
	_baseline = _snapshot(true)
	await _render_tick()
	while Time.get_ticks_usec() < _end_usec:
		_cycle += 1
		for fixture in ROUTE:
			if Time.get_ticks_usec() >= _end_usec:
				break
			if not await _run_fixture(fixture):
				_early_exit("Mode transition failed: %s/%s." % [fixture.mode, fixture.level_id], 2)
				return
		if _cycle == 1 and _warm_baseline.is_empty():
			_current_mode = "warm_cleanup"
			_current_level_id = ""
			_tag_frame_stage("warm_cleanup")
			_warm_baseline = _snapshot(true)
			_last_frame_usec = Time.get_ticks_usec()
	# Allow deferred frees and renderer-side resource releases to settle before
	# the comparable end snapshot.
	_current_mode = "final_cleanup"
	_current_level_id = ""
	_tag_frame_stage("final_cleanup")
	for i in range(8):
		await _render_tick()
	if not _minute_frames.is_empty():
		_finalize_minute(true)
	_end_snapshot = _snapshot(true)
	_last_frame_usec = Time.get_ticks_usec()
	if _warm_baseline.is_empty():
		_warm_baseline = _baseline
	_reset_campaign_flags()
	# Keep the mode reset in memory only.  Calling save_prefs() here would create
	# or rewrite the user's campaign.cfg and would invalidate this no-write QA.
	var save_exists_after := FileAccess.file_exists("user://campaign.cfg")
	var save_after_bytes := _save_bytes()
	var save_unchanged := _save_existed_before == save_exists_after and _save_before_bytes == save_after_bytes
	_check(save_unchanged, "campaign.cfg existence and bytes remain unchanged", JSON.stringify({
		"before": _save_description(_save_existed_before, _save_before_bytes),
		"after": _save_description(save_exists_after, save_after_bytes),
	}))
	_check(_process_probe_failures == 0, "all once-per-minute Windows process-memory probes succeeded", str(_process_probe_failures))
	_check(not _transitions.is_empty() and _transitions.all(func(item): return bool(item.release.passed)), "every constructed scene passed key-node release checks", "transitions=%d" % _transitions.size())
	for fixture in ROUTE:
		var route_key := String(fixture.mode) + ":" + String(fixture.level_id)
		_check(int(_route_visit_counts.get(route_key, 0)) > 0, route_key + " was built and normally started", str(_route_visit_counts.get(route_key, 0)))
	if _stage_timing_enabled:
		_check_stage_frame_coverage()
	var performance := _performance_summary()
	var actual_seconds := float(Time.get_ticks_usec() - _start_usec) / 1_000_000.0
	if _acceptance_eligible:
		_check(actual_seconds >= MIN_ACCEPTANCE_SECONDS, "wall-clock soak reaches 30 minutes", "%.3f" % actual_seconds)
		_check(int(performance.complete_minute_buckets) >= 30, "thirty complete minute buckets were recorded", str(performance.complete_minute_buckets))
		_check(float(performance.max_minute_p95_ms) <= FRAME_P95_LIMIT_MS, "all minute P95 values meet 16.7ms", str(performance.max_minute_p95_ms))
		_check(float(performance.max_minute_p99_ms) <= FRAME_P99_LIMIT_MS, "all minute P99 values meet 33.3ms", str(performance.max_minute_p99_ms))
	var stability := _analyse_stability()
	var runtime_checks_passed := _failures.is_empty()
	var acceptance_passed := runtime_checks_passed and _acceptance_eligible \
		and actual_seconds >= MIN_ACCEPTANCE_SECONDS and int(performance.complete_minute_buckets) >= 30
	_report = {
		"passed": acceptance_passed,
		"runtime_checks_passed": runtime_checks_passed,
		"acceptance_eligible": _acceptance_eligible,
		"requested_seconds": _duration_seconds,
		"actual_seconds": actual_seconds,
		"dwell_seconds": _dwell_seconds,
		"started_at": _started_at,
		"completed_at": Time.get_datetime_string_from_system(false, true),
		"viewport": [root.size.x, root.size.y],
		"renderer": {
			"display": DisplayServer.get_name(),
			"adapter": RenderingServer.get_video_adapter_name(),
			"vendor": RenderingServer.get_video_adapter_vendor(),
			"driver": driver,
			"api": api,
			"method": method,
			"vsync": DisplayServer.window_get_vsync_mode(),
			"godot": Engine.get_version_info(),
		},
		"route": ROUTE,
		"cycles_started": _cycle,
		"visits": _visit_counts,
		"route_visits": _route_visit_counts,
		"transition_count": _transitions.size(),
		"transitions": _transitions,
		"minute_samples": _minute_samples,
		"performance": performance,
		"baseline": _baseline,
		"warm_baseline": _warm_baseline,
		"end_snapshot": _end_snapshot,
		"stability": stability,
		"campaign_save": {
			"unchanged": save_unchanged,
			"before": _save_description(_save_existed_before, _save_before_bytes),
			"after": _save_description(save_exists_after, save_after_bytes),
		},
		"checks": _checks,
		"failures": _failures,
		"exit_warning_status": "pending wrapper post-process",
		"scope": "Real renderer lifecycle, frame, resource and release evidence. No human playtest, pacing or balance conclusion.",
	}
	if _stage_timing_enabled:
		_report["frame_stages"] = _stage_frame_samples.values()
	if _mount_trace_enabled:
		_report["mount_traces"] = _mount_samples
	_write_report()
	print("CAMPAIGN_MODE_SOAK_RESULT ", JSON.stringify({
		"passed": acceptance_passed,
		"runtime_checks_passed": runtime_checks_passed,
		"acceptance_eligible": _acceptance_eligible,
		"actual_seconds": actual_seconds,
		"transitions": _transitions.size(),
		"failures": _failures,
		"report": _output_dir.path_join(REPORT_NAME),
	}))
	# A short explicitly requested harness-debug run may exit zero while the JSON
	# remains acceptance_eligible=false and passed=false. The wrapper preserves
	# that distinction. A full run exits non-zero for any runtime failure.
	quit(0 if runtime_checks_passed else 1)
