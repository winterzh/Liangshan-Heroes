extends Node
## Private diagnostic. Ledger intervals overlap scope observations and are not
## a complete instrument cost. Never subtract them to infer production timing.
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
var measured_ledger_us := 0
var measured_hook_calls := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.set_meta("liangshan_unit_remainder_observer", self)
	var mode := OS.get_environment("UNIT_REMAINDER_MODE")
	if mode not in ["timed", "clockless"]: issues.append("explicit mode required")
	timed = mode == "timed"
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/unit_remainder_scopes.json"))
	if not loaded is Array:
		issues.append("scope definition invalid")
		return
	for value in loaded: scopes.append(String(value))

func _exit_tree() -> void:
	Engine.remove_meta("liangshan_unit_remainder_observer")

func begin_sample(usec: int, tick: int) -> void:
	if enabled or not stack.is_empty(): issues.append("sample start barrier")
	started_us = usec; started_tick = tick
	enabled = true

func enter(scope: String) -> int:
	if not enabled: return -1
	if stack.is_empty() and scope != "unit._phys_body": return -1
	var ledger_started := Time.get_ticks_usec() if timed else -1
	if stack.is_empty(): current_step = Engine.get_physics_frames()
	if not steps.has(current_step): steps[current_step] = {}
	if not steps[current_step].has(scope): steps[current_step][scope] = [0, 0 if timed else -1, 0 if timed else -1]
	next_token += 1
	measured_hook_calls += 1
	stack.append([next_token, scope, Time.get_ticks_usec() if timed else -1, 0])
	if timed: measured_ledger_us += Time.get_ticks_usec() - ledger_started
	return next_token

func leave(token: int) -> void:
	if token == -1: return
	var now := Time.get_ticks_usec() if timed else -1
	measured_hook_calls += 1
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
		measured_ledger_us += Time.get_ticks_usec() - now

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
	for step in steps: rows.append({"physics_id":step,"scopes":steps[step]})
	var report := {"schema":2,"timed":timed,"scope":"Unit body inline spans and nested methods only",
		"columns":["calls","inclusive_us","exclusive_us"],"scope_names":scopes,
		"start_usec":started_us,"end_usec":ended_us,"start_tick":started_tick,"end_tick":ended_tick,
		"steps":rows,"presents":presents,"issues":issues,"complete":issues.is_empty(),
		"actual_user_dir":OS.get_user_data_dir(),"observer_measured_ledger_us":measured_ledger_us if timed else null,
		"observer_hook_calls":measured_hook_calls,
		"observer_cost_note":"Inside enter/leave intervals only; incomplete observer cost, overlaps measured scopes. Never subtract it or timed/clockless differences to infer production cost."}
	var output := OS.get_environment("UNIT_REMAINDER_OUT")
	if output.is_empty():
		push_error("UNIT_REMAINDER_OUT required")
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write body diagnostic report")
		return
	file.store_string(JSON.stringify(report,"\t"))
	print("[unit body remainder] ","PASS" if issues.is_empty() else "FAIL", " ", rows.size(), " physics steps; ", issues)
