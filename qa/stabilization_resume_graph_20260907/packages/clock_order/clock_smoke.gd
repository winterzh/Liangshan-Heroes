extends SceneTree
## Native schedule fixture, never a complete Battle or player save test.
var checks: Array = []
var failures: Array = []
var manifest: Dictionary = {}
var report_path := ""
var verified_manifest := false
var clock_script: Script
var barrier_script: Script
var fixture: Variant
var barrier: Variant
var clock: Variant
var traces: Array = []
var captures: Array = []
var rejections: Array = []
var completed_callbacks := 0
var deferred_count := 0
var idle_damage_calls := 0
var idle_deferred_count := 0
var idle_events: Array = []
var fixture_hp := 1000
var doomed: Variant
var gate_closed := false
var phase := "request_in_child"
var saved_max_fps := 0
var saved_time_scale := 1.0

class Actor extends Node:
	var host: Variant
	var label := ""
	func _physics_process(_delta: float) -> void:
		host._record(label)

class IdleDamageActor extends Node:
	var host: Variant
	func _process(_delta: float) -> void:
		host._record_idle()

func _initialize() -> void:
	call_deferred("_run")

func _check(label: String, value: bool) -> bool:
	checks.append({"label": label, "passed": value})
	if not value: failures.append(label)
	return value

func _guard(label: String) -> void:
	for path: String in manifest.source_sha256:
		_check(label + " " + path, FileAccess.get_sha256(path) == manifest.source_sha256[path])

func _finish(aborted := false) -> void:
	if is_instance_valid(fixture): fixture.free()
	Engine.max_fps = saved_max_fps
	Engine.time_scale = saved_time_scale
	paused = false
	if verified_manifest: _guard("source after")
	var result := {"suite": "simulation-clock-native-order-draft", "run_id": manifest.get("run_id", ""),
		"passed": failures.is_empty() and not aborted, "complete": not aborted, "checks": checks, "failures": failures,
		"check_count": checks.size(), "failed_count": failures.size(), "process_id": OS.get_process_id(),
		"actual_user_dir": OS.get_user_data_dir(), "source_sha256": manifest.get("source_sha256", {}),
		"traces": traces, "captures": captures, "rejections": rejections, "deferred_count": deferred_count,
		"idle_events": idle_events, "idle_damage_calls": idle_damage_calls, "idle_deferred_count": idle_deferred_count,
		"scope": "Pure exact-int clock plus actual 60Hz SceneTree fixture callbacks, child-issued save request, chained deferred work, queued free, real catch-up, pause and partial-step rejection. No production Battle clock wiring, full-world barrier, clocked LiBrawnAxes conversion, save slot, campaign or cross-process gameplay parity claim."}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			quit(1)
			return
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	print("[simulation-clock order draft QA] ", JSON.stringify(result))
	quit(0 if result.passed else 1)

func _run() -> void:
	saved_max_fps = Engine.max_fps
	saved_time_scale = Engine.time_scale
	var path := OS.get_environment("RUN_RESTORE_QA_MANIFEST")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if not path.is_empty() else null
	if typeof(data) != TYPE_DICTIONARY:
		_check("host manifest", false)
		_finish(true)
		return
	manifest = data
	for key: String in ["run_id", "private_user", "report"]:
		if typeof(manifest.get(key)) != TYPE_STRING or manifest[key].is_empty():
			_check("host field " + key, false)
			_finish(true)
			return
	if typeof(manifest.get("source_sha256")) != TYPE_DICTIONARY or manifest.source_sha256.is_empty():
		_check("host source manifest", false)
		_finish(true)
		return
	report_path = manifest.report
	if not report_path.is_absolute_path() or FileAccess.file_exists(report_path):
		_check("fresh absolute report", false)
		report_path = ""
		_finish(true)
		return
	verified_manifest = true
	_check("private user", OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower() == manifest.private_user.replace("\\", "/").simplify_path().to_lower())
	_guard("source before")
	_check("production physics frequency already 60Hz", Engine.physics_ticks_per_second == 60)
	if not failures.is_empty():
		_finish(true)
		return
	clock_script = load("res://scripts/run_simulation_clock.gd")
	barrier_script = load("res://scripts/run_step_barrier.gd")
	_pure()
	# Deliberately cap rendering only. Multiple true physics ticks must occur in
	# one actual process frame; no --fixed-fps or direct callback stepping.
	Engine.max_fps = 15
	Engine.time_scale = 1.0
	clock = clock_script.new()
	_check("native fixture clock begins with explicit phase 13", clock.initialize_new(13).ok)
	fixture = Actor.new()
	fixture.host = self
	fixture.label = "battle"
	for label: String in ["unit_a", "unit_b", "projectile"]:
		var actor := Actor.new()
		actor.host = self
		actor.label = label
		fixture.add_child(actor)
	var idle_actor := IdleDamageActor.new()
	idle_actor.host = self
	fixture.add_child(idle_actor)
	barrier = barrier_script.new()
	barrier.configure(fixture, clock, _health, func(): return gate_closed)
	barrier.capture_ready.connect(_captured)
	barrier.capture_rejected.connect(func(code): rejections.append(code))
	barrier.input_gate_changed.connect(func(closed): gate_closed = closed)
	fixture.add_child(barrier)
	root.add_child(fixture)
	for frame: int in range(90):
		await process_frame
		if not captures.is_empty(): break
	if not _check("child request reaches one real post-drain capture", captures.size() == 1):
		_finish(true)
		return
	_check("native callback order per complete tick", _ordered(traces))
	var batches: Dictionary = {}
	for row: Dictionary in traces:
		if row.label == "battle": batches[row.process_frame] = int(batches.get(row.process_frame, 0)) + 1
	var maximum := 0
	for count: int in batches.values(): maximum = maxi(maximum, count)
	_check("multiple actual catch-up physics ticks share a process frame", maximum >= 2)
	var captured_tick: int = clock.frame()
	for frame: int in range(3): await process_frame
	_check("held capture stays paused and clock does not advance", paused and clock.frame() == captured_tick)
	_check("release child request resumes prior unpaused state", barrier.release_capture().ok and not paused and not gate_closed)
	phase = "running"
	var resumed_from: int = completed_callbacks
	for frame: int in range(12):
		await process_frame
		if completed_callbacks >= resumed_from + 4: break
	_check("same native world resumes real physics", completed_callbacks >= resumed_from + 4)
	paused = true
	var before_pause: int = clock.frame()
	var engine_before: int = Engine.get_physics_frames()
	for frame: int in range(3): await process_frame
	_check("logical tick freezes while global engine counter advances", clock.frame() == before_pause and Engine.get_physics_frames() > engine_before)
	_check("save requested from existing pause is accepted", barrier.request_capture().ok)
	for frame: int in range(12):
		await process_frame
		if captures.size() >= 2: break
	_check("existing pause produces exact same clock phase", captures.size() == 2 and captures[1].record.next_tick == str(before_pause + 1))
	_check("release keeps the pre-existing user pause", barrier.release_capture().ok and paused)
	phase = "idle_request"
	paused = false
	for frame: int in range(20):
		await process_frame
		if captures.size() >= 3: break
	_check("request inside real idle damage callback drains before capture", captures.size() == 3 and idle_damage_calls > 0 and idle_damage_calls == idle_deferred_count)
	_check("idle-issued capture release resumes original state", barrier.release_capture().ok and not paused)
	phase = "fault_mid_step"
	paused = false
	for frame: int in range(12):
		await process_frame
		if not clock.fault().is_empty(): break
	_check("pause halfway through actual child callbacks faults the open tick", clock.fault() == "PAUSED_DURING_STEP" and paused)
	_check("partial tick can never become a save record", not clock.capture().ok and not barrier.request_capture().ok)
	_check("only the three healthy requests produced snapshots", captures.size() == 3 and rejections.is_empty())
	_finish()

func _pure() -> void:
	var original: Variant = clock_script.new()
	_check("empty clock cannot snapshot", not original.capture().ok)
	_check("new phase near 16-step boundary", original.initialize_new(14).ok)
	_check("first tick starts exactly at requested phase", original.begin_step().tick == 14)
	_check("partial first step cannot snapshot", not original.capture().ok)
	_check("complete first tick", original.end_step().ok)
	var wire: Dictionary = JSON.parse_string(JSON.stringify(original.capture().record))
	var restored: Variant = clock_script.new()
	_check("exact clock survives actual JSON", restored.restore(wire).ok and restored.capture().record == original.capture().record)
	var same := true
	for step: int in range(70):
		var a: Dictionary = original.begin_step()
		var b: Dictionary = restored.begin_step()
		same = same and a.tick == b.tick and int(a.tick / 16) == int(b.tick / 16) and a.tick % 16 == b.tick % 16
		same = same and original.end_step().ok and restored.end_step().ok
	_check("multiple resumed 16-step cache phases match exact next tick", same)
	for bad: Variant in ["0", "01", "-1", "1.0", "1e3", "9223372036854775808", 9007199254740992.0]:
		var record: Dictionary = wire.duplicate(true)
		record["next_tick"] = bad
		var rejected: Variant = clock_script.new()
		_check("invalid clock tick refuses " + str(bad), not rejected.restore(record).ok and not rejected._initialized)
	var huge: Variant = clock_script.new()
	_check("large tick above JSON safe integer restored exactly", huge.restore({"schema": "run_simulation_clock_v1", "physics_hz": 60, "next_tick": "9007199254740993"}).ok and huge.begin_step().tick == 9007199254740993)
	_check("large exact completed tick", huge.end_step().ok and huge.capture().record.next_tick == "9007199254740994")
	var exhausted: Variant = clock_script.new()
	_check("maximum next sentinel accepted as data", exhausted.restore({"schema": "run_simulation_clock_v1", "physics_hz": 60, "next_tick": "9223372036854775807"}).ok)
	_check("exhausted clock never wraps or issues a tick", not exhausted.begin_step().ok and exhausted.fault() == "CLOCK_EXHAUSTED")
	var wrong_hz: Variant = clock_script.new()
	_check("different physics frequency rejects", not wrong_hz.restore({"schema": "run_simulation_clock_v1", "physics_hz": 120, "next_tick": "1"}).ok)

func _record(label: String) -> void:
	traces.append({"label": label, "tick": clock.frame(), "engine_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "open": clock.in_step()})
	if label == "battle":
		completed_callbacks += 1
		# Mirrors mission work inside the parent Battle callback, before Units.
		traces.append({"label": "mission", "tick": clock.frame(), "engine_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "open": clock.in_step()})
	if label == "unit_a" and phase == "request_in_child" and completed_callbacks == 12:
		_check("request from child is accepted without immediately pausing siblings", barrier.request_capture().ok and not paused)
		_check("parent callback completion cannot authorize a partial capture", not clock.capture().ok)
		doomed = Node.new()
		fixture.add_child(doomed)
		doomed.queue_free()
		call_deferred("_deferred_first")
	if label == "unit_a" and phase == "fault_mid_step": paused = true

func _deferred_first() -> void:
	deferred_count += 1
	call_deferred("_deferred_second")

func _deferred_second() -> void:
	deferred_count += 1

func _record_idle() -> void:
	idle_damage_calls += 1
	fixture_hp -= 1
	idle_events.append({"damage_serial": idle_damage_calls, "tick": clock.frame(), "engine_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "physics_open": clock.in_step()})
	call_deferred("_deferred_idle")
	if phase == "idle_request":
		phase = "idle_request_issued"
		_check("idle damage can request without aborting current callback", barrier.request_capture().ok and not paused and not clock.in_step())

func _deferred_idle() -> void:
	idle_deferred_count += 1

func _health() -> Dictionary:
	if deferred_count != 2: return {"ok": false, "code": "DEFERRED_GAMEPLAY_PENDING"}
	if idle_damage_calls == 0 or idle_damage_calls != idle_deferred_count: return {"ok": false, "code": "IDLE_DAMAGE_DEFERRED_PENDING"}
	if fixture_hp != 1000 - idle_damage_calls: return {"ok": false, "code": "IDLE_DAMAGE_VALUE"}
	for row: Dictionary in idle_events:
		if row.physics_open: return {"ok": false, "code": "IDLE_INTERLEAVES_OPEN_PHYSICS_STEP"}
	if is_instance_valid(doomed): return {"ok": false, "code": "QUEUED_NODE_NOT_FREED"}
	if not _ordered(traces): return {"ok": false, "code": "INCOMPLETE_CALLBACK_TRACE"}
	return {"ok": true}

func _ordered(rows: Array) -> bool:
	if rows.is_empty() or rows.size() % 5 != 0: return false
	var order := ["battle", "mission", "unit_a", "unit_b", "projectile"]
	for index: int in range(rows.size()):
		if rows[index].label != order[index % 5] or not rows[index].open: return false
		if rows[index].tick != rows[index - index % 5].tick: return false
	return true

func _captured(record: Dictionary) -> void:
	_check("capture occurs paused outside every native physics callback", paused and not Engine.is_in_physics_frame() and not clock.in_step())
	_check("capture follows nested deferred work and actual deletion", deferred_count == 2 and not is_instance_valid(doomed))
	_check("capture includes prior idle damage and its deferred work", idle_damage_calls > 0 and idle_damage_calls == idle_deferred_count)
	captures.append({"record": record, "trace_rows": traces.size(), "engine_frame": Engine.get_physics_frames(), "process_frame": Engine.get_process_frames(), "idle_damage_serial": idle_damage_calls, "fixture_hp": fixture_hp})
