extends Node
## Diagnostic only. Measures nested synchronous methods entered from Unit._phys_body.
## Wrapper/ledger costs remain in observations. Clockless is not a zero-cost control.
var timed := true
var enabled := false
var scopes: Array[String] = []
var stack: Array = []
var steps := {}
var presents: Array = []
var issues: Array[String] = []
var started_us := 0
var ended_us := 0
var started_tick := 0
var ended_tick := 0
var next_token := 0
var current_step := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mode := OS.get_environment("UNIT_REMAINDER_MODE")
	if mode not in ["timed", "clockless"]: issues.append("explicit timed/clockless mode required")
	timed = mode == "timed"
	var file := FileAccess.open("res://tools/unit_remainder_scopes.json", FileAccess.READ)
	if file == null:
		issues.append("scope definition missing")
		return
	var loaded: Variant = JSON.parse_string(file.get_as_text())
	if not loaded is Array:
		issues.append("scope definition invalid")
		return
	for value in loaded: scopes.append(String(value))

func begin_sample(usec: int, tick: int) -> void:
	if enabled or not stack.is_empty(): issues.append("sample start barrier")
	started_us = usec; started_tick = tick
	enabled = true

func enter(scope: String) -> int:
	if not enabled: return -1
	if stack.is_empty():
		if scope != "unit._phys_body": return -1
		current_step = Engine.get_physics_frames()
	if not steps.has(current_step): steps[current_step] = {}
	if not steps[current_step].has(scope): steps[current_step][scope] = [0, 0 if timed else -1, 0 if timed else -1]
	next_token += 1
	stack.append([next_token, scope, Time.get_ticks_usec() if timed else -1, 0])
	return next_token

func leave(token: int) -> void:
	if token == -1: return
	var now := Time.get_ticks_usec() if timed else -1
	if stack.is_empty() or stack[-1][0] != token:
		issues.append("nested token mismatch")
		return
	var frame: Array = stack.pop_back()
	var row: Array = steps[current_step][frame[1]]
	row[0] += 1
	if timed:
		var elapsed: int = now - int(frame[2])
		var own: int = elapsed - int(frame[3])
		if own < 0: issues.append("negative exclusive time")
		row[1] += elapsed; row[2] += own
		if not stack.is_empty(): stack[-1][3] += elapsed

func present(usec: int, tick: int) -> void:
	if enabled:
		if not stack.is_empty(): issues.append("scope still active at presentation")
		presents.append([usec, tick, Engine.get_physics_frames()])

func end_sample(usec: int, tick: int) -> void:
	ended_us = usec; ended_tick = tick
	enabled = false
	if not stack.is_empty(): issues.append("scope active at sample end")
	if presents.is_empty() or started_us >= ended_us: issues.append("sample clock bounds")
	var rows := []
	for step in steps:
		rows.append({"physics_id":step,"scopes":steps[step]})
	var output := OS.get_environment("UNIT_REMAINDER_OUT")
	if output.is_empty():
		push_error("UNIT_REMAINDER_OUT required")
		return
	var report := {"schema":1,"timed":timed,"scope":"only synchronous calls nested under actual Unit._phys_body",
		"columns":["calls","inclusive_us","exclusive_us"],"scope_names":scopes,
		"start_usec":started_us,"end_usec":ended_us,"start_tick":started_tick,"end_tick":ended_tick,
		"steps":rows,"presents":presents,"issues":issues,"complete":issues.is_empty(),
		"actual_user_dir":OS.get_user_data_dir(),"warning":"Includes observer overhead; timed and clockless are independent combat runs, never subtract their timing or report their FPS as product performance."}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write diagnostic report")
		return
	file.store_string(JSON.stringify(report,"\t"))
	print("[unit remainder] ","PASS" if issues.is_empty() else "FAIL", " ", rows.size(), " physics steps; ", issues)
