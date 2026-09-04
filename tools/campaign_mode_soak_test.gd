extends SceneTree
## Real-renderer, long-running lifecycle fixture for campaign and free-play modes.
## It deliberately uses the normal Battle + HUD start path, never a synthetic scene.

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


func _record_render_frame() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_usec > 0:
		var frame_ms := float(now - _last_frame_usec) / 1000.0
		# A negative/zero interval would be a clock failure. Retain long transition
		# frames: scene construction and teardown are part of this lifecycle test.
		if frame_ms > 0.0:
			_minute_frames.append(frame_ms)
			_minute_frame_count += 1
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
	var mode := String(fixture.mode)
	if mode == "campaign":
		campaign.current = campaign.index_for_id(String(fixture.level_id))
	else:
		campaign.set(mode, true)
	if mode == "custom_defense":
		campaign.custom_config = {"name": "稳定性据守"}


func _activate_live_mode(battle, mode: String) -> String:
	# Exercise authored mode actions so a successful lifecycle cannot be an idle
	# main scene with no game work. Campaign levels keep their normal story start.
	match mode:
		"arena":
			battle.level.arena_spawn_troops(battle)
			return "authored arena troop button"
		"skirmish", "custom_defense":
			if battle.level.has_method("_spawn_wave"):
				battle.level._spawn_wave(battle, 0)
				battle.level._wave = 1
				battle.level._wave_t = 9999.0
				return "authored first defense wave"
		"skirmish_ai":
			var target = battle.level.hall
			var ordered := 0
			if target != null and is_instance_valid(target):
				for unit in battle.units:
					if is_instance_valid(unit) and unit.faction == 1 and not unit.is_building \
							and not unit.is_resource and unit.hp > 0.0:
						unit.order_amove(target.position)
						ordered += 1
			return "official opening force attack-move count=%d" % ordered
		"campaign":
			if String(battle.level.id()) == "level5" and battle.level.fleet.size() > 0:
				battle.level.on_mission_action(battle, "lure", battle.level.fleet[0])
				return "authored level5 main-harbour lure"
	return "normal authored on_start"


func _release_cursor_textures(battle) -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_CROSS)
	for property in ["_target_cursor", "_cur_attack", "_cur_gather_wood", "_cur_gather_gold", "_cur_repair", "_cur_select", "_cur_garrison"]:
		battle.set(property, null)


func _dispose_battle(battle, transition: Dictionary) -> void:
	var scene_ref: WeakRef = weakref(battle)
	var level_ref: WeakRef = weakref(battle.level)
	var mission_ref: WeakRef = weakref(battle.mission) if battle.mission != null else null
	var map_ref: WeakRef = weakref(battle.map)
	var hud_ref: WeakRef = weakref(battle.hud)
	var world_ref: WeakRef = weakref(battle.world)
	var camera_ref: WeakRef = weakref(battle.camera)
	var units_root_ref: WeakRef = weakref(battle.units_root)
	var unit_ref: WeakRef = weakref(battle.units[0]) if not battle.units.is_empty() else null
	paused = false
	current_scene = null
	_release_cursor_textures(battle)
	_current_battle = null
	_current_mode = "cleanup"
	battle.queue_free()
	battle = null
	await process_frame
	await _render_tick()
	await process_frame
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


func _run_fixture(fixture: Dictionary) -> void:
	_configure_mode(fixture)
	var mode := String(fixture.mode)
	_current_mode = "building:" + mode
	_current_level_id = String(fixture.level_id)
	var began := Time.get_ticks_usec()
	seed(5_088_120 + _transitions.size())
	var battle = load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	_current_battle = battle
	await process_frame
	await _render_tick()
	if battle.hud._intro_root != null:
		battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.hud._on_start_pressed()
	await process_frame
	await _render_tick()
	_current_mode = mode
	_current_level_id = String(battle.level.id())
	var expected_id := String(fixture.level_id)
	var nodes_ok := battle.map != null and battle.hud != null and battle.world != null \
		and battle.camera != null and battle.units_root != null
	var start_ok: bool = String(battle.level.id()) == expected_id and battle.phase == battle.Phase.FIGHT and nodes_ok
	var activation := _activate_live_mode(battle, mode)
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
	_visit_counts[mode] = int(_visit_counts.get(mode, 0)) + 1
	var live_started := Time.get_ticks_usec()
	var live_deadline := mini(_end_usec, live_started + int(_dwell_seconds * 1_000_000.0))
	while Time.get_ticks_usec() < live_deadline:
		await _render_tick()
	transition["live_seconds"] = float(Time.get_ticks_usec() - live_started) / 1_000_000.0
	transition["phase_at_end"] = int(battle.phase)
	transition["units_at_end"] = _unit_counts()
	await _dispose_battle(battle, transition)
	_transitions.append(transition)
	print("[soak-transition] ", JSON.stringify({
		"index": transition.index,
		"cycle": transition.cycle,
		"mode": transition.mode,
		"level": transition.level_id,
		"live_seconds": transition.live_seconds,
		"released": transition.release.passed,
	}))


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
	for metric in RECOVERY_TOLERANCE:
		var source: Array = _minute_samples if metric in ["working_set_bytes", "private_bytes"] else comparable_cleanup
		var values := _series_for(metric, source)
		var epsilon := 1.0 * MIB if metric.contains("bytes") else 1.0
		var trend := _trend(values, epsilon)
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
	_started_at = Time.get_datetime_string_from_system(false, true)
	_start_usec = Time.get_ticks_usec()
	_end_usec = _start_usec + int(_duration_seconds * 1_000_000.0)
	_bucket_start_usec = _start_usec
	_next_minute_usec = _start_usec + MINUTE_USEC
	_last_frame_usec = _start_usec
	_baseline = _snapshot(true)
	await _render_tick()
	while Time.get_ticks_usec() < _end_usec:
		_cycle += 1
		for fixture in ROUTE:
			if Time.get_ticks_usec() >= _end_usec:
				break
			await _run_fixture(fixture)
		if _cycle == 1 and _warm_baseline.is_empty():
			_current_mode = "warm_cleanup"
			_current_level_id = ""
			_warm_baseline = _snapshot(true)
			_last_frame_usec = Time.get_ticks_usec()
	# Allow deferred frees and renderer-side resource releases to settle before
	# the comparable end snapshot.
	_current_mode = "final_cleanup"
	_current_level_id = ""
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
	for mode in ["campaign", "arena", "skirmish", "skirmish_ai", "custom_defense"]:
		_check(int(_visit_counts.get(mode, 0)) > 0, mode + " was built and normally started", str(_visit_counts.get(mode, 0)))
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
