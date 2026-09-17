extends Node
## Actual CampaignMission/Unit component behavior on a private synthetic host.
## This deliberately does not claim a deployed campaign or world save test.
const State := preload("res://scripts/run_campaign_mission_state.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
const UnitScript := preload("res://scripts/unit.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const CONTEXT := {"level_id": "level3", "content_version": "fixture:mission:v1", "mission_token": "mission:fixture:1", "presentation_token": "presentation:fixture:1"}
const BOUNDARY := {"deferred_drained": true, "presentation_captured": true}
var state := State.new()
var codec := Codec.new()
var checks: Array = []
var fixtures: Array = []

class FixtureMap extends RefCounted:
	func cell_to_world(cell: Vector2i) -> Vector2: return Vector2(cell * 32)
	func world_to_cell(point: Vector2) -> Vector2i: return Vector2i(point / 32.0)
	func sync_render_position(_node: Node2D) -> void: pass
	func _segment_open(_from: Vector2, _to: Vector2, _profile) -> bool: return true

class FixtureHUD extends Control:
	func campaign_objective_position() -> Vector2: return Vector2(84, 78)

class FixtureLevel extends RefCounted:
	var callbacks := 0
	var rewards := 0
	var finished: Array = []
	func on_mission_action(_owner, id: String, actor) -> void:
		callbacks += 1; rewards += 100; finished.append([id, actor.entity_id])

class FixtureBattle extends Node2D:
	enum Phase { FIGHT, END }
	var phase := Phase.FIGHT
	var hud := FixtureHUD.new()
	var fx_root := Node2D.new()
	var map := FixtureMap.new()
	var level := FixtureLevel.new()
	var mission
	var units: Array = []
	var selection: Array = []
	var _defs := {"lin_chong": {"name": "林冲"}}
	var messages: Array = []
	var camera_moves := 0
	func _init() -> void:
		add_child(hud); add_child(fx_root)
	func msg(text: String, _seconds := 0.0) -> void: messages.append(text)
	func center_camera_cell(_cell: Vector2i) -> void: camera_moves += 1
	func select_single(unit, _unused := false) -> void: selection = [unit]

func _ready() -> void:
	var profile := OS.get_environment("LSH_MISSION_STATE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("CAMPAIGN_MISSION_STATE_QA PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: push_error(label)

func gate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED; node.set_block_signals(true)
	for child: Node in node.get_children(true): gate(child)

func unbind_branch(node: Node) -> void:
	Localize.unbind(node)
	for child: Node in node.get_children(true): unbind_branch(child)

func fixture(started := false) -> Dictionary:
	var owner := FixtureBattle.new()
	var unit := UnitScript.new()
	unit.entity_id = 1; unit.key = "lin_chong"; unit.display_name = "林冲"
	unit.faction = UnitScript.FACTION_LIANG; unit.hp = 80.0; unit.position = Vector2(64, 64)
	owner.units = [unit]
	var mission := Mission.new(owner); owner.mission = mission
	if started:
		mission.configure_campaign("带林冲出林", [{"id": "rescue", "label": "解救林冲", "required_events": ["action:stage_a:rescue"]}, {"id": "quiet", "label": "未惊动守卫", "forbidden_events": ["alarm"]}], 2)
		mission.begin("stage_a", "救援", "救人后离开")
	mission.add_action("rescue", "解缚", Vector2i(2, 2), ["lin_chong"], 1.5, 48.0, 32.0, true)
	mission.add_actor_locator("rescue", "lin_chong")
	mission.add_map_locator("查看出口", Vector2i(9, 9))
	mission.add_action("talk", "后续交谈", Vector2i(2, 2), ["lin_chong"], 1.0, 48.0, 32.0, false)
	mission.add_action("blocked", "等待支援", Vector2i(8, 8), [], 2.0, 96.0, 48.0, true)
	mission.enable_scrolling()
	if started:
		mission.mark("earlier", "前一阶段已经完成")
		mission.mark("alarm", "守卫被惊动")
		mission.actions.blocked["blocked_reason"] = "等待同伴到场"
		mission.actions.rescue["settle_margin"] = 16.0
		mission.active_action_id = "rescue"; mission._actor = unit
		mission._progress = 0.75; mission._retry = 0.5
		mission.elapsed = 4.0; mission.total_game_seconds = 14.0
		mission._generation = 3; mission._stage_commands = 2; mission._stage_repaths = 1; mission._stage_interruptions = 1
		mission._stage_started_ms = 88000
		mission.stage_metrics.append({"stage": "earlier", "game_seconds": 10.0, "wall_seconds": 12.0, "accepted_task_commands": 1, "automatic_repaths": 0, "task_interruptions": 0, "end_reason": "transition"})
		mission.set_feedback("正在等待救援", 2.0)
	gate(owner); gate(unit)
	var result := {"owner": owner, "mission": mission, "unit": unit, "ids": {"1": unit}, "to_token": {}, "to_node": {}}
	for field: String in State.NODE_FIELDS:
		var node: Variant = mission.get(field)
		if node != null and not result.to_token.has(node): result.to_token[node] = "node:" + field
	var index := 0
	for node: Node in mission._buttons.get_children():
		result.to_token[node] = "button:" + str(index); index += 1
	index = 0
	for node: Variant in mission._markers:
		result.to_token[node] = "marker:" + str(index); index += 1
	for node: Variant in result.to_token: result.to_node[result.to_token[node]] = node
	fixtures.append(result)
	return result

func restore(target: Dictionary, record: Variant, now := 1000, presentation := true) -> Dictionary:
	return state.restore_into(target.mission, target.owner, record, CONTEXT, target.ids, 2, target.to_node, now, presentation)

func changed(record: Dictionary, section: String, field: String, value: Variant) -> Dictionary:
	var result := record.duplicate(true)
	var data: Dictionary = codec.decode(result.payload).value
	data[section][field] = value; result.payload = codec.encode(data).value
	return result

func changed_row(record: Dictionary, section: String, field: String, value: Variant) -> Dictionary:
	var result := record.duplicate(true)
	var data: Dictionary = codec.decode(result.payload).value
	data[section][0][field] = value; result.payload = codec.encode(data).value
	return result

func rejects(record: Variant, source: Dictionary) -> bool:
	return not state.validate(record, CONTEXT, source.ids, 2, source.to_node).ok

func exercise_progress(record: Dictionary, prefix: String) -> void:
	var target := fixture()
	var restored := restore(target, record)
	check(prefix + " actual Mission restored privately", restored.ok and not restored.get("complete_world", true))
	if not restored.ok: print(restored); return
	var mission: Variant = target.mission
	check(prefix + " actor is new stable Unit", mission._actor == target.unit and mission._actor.entity_id == 1)
	check(prefix + " half action progress retained", mission._progress == 0.75 and mission._retry == 0.5 and mission.active_action_id == "rescue")
	check(prefix + " stage and generation retained", mission.stage_id == "stage_a" and mission._generation == 3 and mission.elapsed == 4.0 and mission.total_game_seconds == 14.0)
	check(prefix + " no replay during restore", target.owner.messages.is_empty() and target.owner.level.callbacks == 0 and target.owner.level.rewards == 0 and restored.events_replayed == 0 and not restored.begin_called)
	check(prefix + " process ticks rebased through negative epoch", mission._stage_started_ms == -11000)
	check(prefix + " optional goals and report retained", mission.story_goals.quiet.state == "missed" and mission._story_miss_notified and mission.events.has("alarm") and mission.report.size() == 3)
	check(prefix + " UI factory callbacks stay on new Mission", mission.actions.rescue.button.pressed.is_connected(mission.focus_action.bind("rescue")))
	check(prefix + " order and locator buttons retained", mission.actions.keys() == ["rescue", "talk", "blocked"] and mission._buttons.get_child_count() == 4 and mission._markers.size() == 3)
	check(prefix + " scroll aliases and feedback retained", mission._scroll == mission._detail_scroll and mission._scroll_content == mission._details and mission._feedback_active and mission._feedback_left == 2.0)
	var recaptured := state.capture(mission, CONTEXT, target.ids, 2, target.to_token, 1000, BOUNDARY)
	check(prefix + " exact wire recapture before ticks", recaptured.ok and recaptured.record == record)
	check(prefix + " second install rejected", not restore(target, record).ok)
	mission.tick(0.5)
	check(prefix + " remaining time not shortened", mission._progress == 1.25 and target.owner.level.callbacks == 0)
	mission.tick(0.25)
	check(prefix + " completion executes original callback once", target.owner.level.callbacks == 1 and target.owner.level.rewards == 100 and target.owner.level.finished == [["rescue", 1]])
	check(prefix + " action tombstone and event committed", mission.actions.rescue.done and mission.has_event("action:stage_a:rescue") and mission.active_action_id == "" and mission._actor == null)
	check(prefix + " consumed order cannot start next colocated task", target.unit.mission_order_token == 0 and not target.unit.mission_order_active)
	mission.tick(0.5); mission.tick(0.5)
	check(prefix + " idle ticks do not repeat reward or follow-up", target.owner.level.callbacks == 1 and not mission.actions.talk.done and mission.active_action_id == "")
	var count: int = target.owner.messages.size()
	check(prefix + " duplicate event ignored", not mission.mark("action:stage_a:rescue", "duplicate") and target.owner.messages.size() == count)
	var final_result: Dictionary = mission.result_snapshot(true)
	check(prefix + " required event finalized once", final_result.story_done == 1 and final_result.story_total == 2 and final_result.done_ids == ["rescue"] and final_result.missed_ids == ["quiet"])
	check(prefix + " frozen settlement ignores contradictory later request", mission.result_snapshot(false) == final_result)

func full_suite() -> void:
	check("all production Mission declarations classified", state.audit_declarations().ok)
	var source := fixture(true)
	var captured := state.capture(source.mission, CONTEXT, source.ids, 2, source.to_token, 100000, BOUNDARY)
	check("production Mission capture", captured.ok)
	if not captured.ok: print(captured); return
	var record: Dictionary = JSON.parse_string(JSON.stringify(captured.record))
	check("capture leaves actor order and progress unchanged", source.mission._progress == 0.75 and source.unit.mission_order_token == 0 and source.owner.level.callbacks == 0)
	var file := FileAccess.open(OS.get_environment("LSH_MISSION_STATE_SNAPSHOT"), FileAccess.WRITE)
	if file == null: check("restart snapshot written", false); return
	file.store_string(JSON.stringify(record)); file.close()
	check("restart snapshot written", true)
	exercise_progress(record, "same process")
	for field: String in State.VALUE_FIELDS:
		var wrong: Variant = true if State.VALUE_FIELDS[field] == TYPE_STRING else "wrong"
		check("strict value type " + field, rejects(changed(record, "values", field, wrong), source))
	for field: String in ["elapsed", "total_game_seconds", "_progress", "_retry", "_feedback_left"]:
		check("negative timer " + field, rejects(changed(record, "values", field, -0.1), source))
	for field: String in ["story_contract_version", "_generation", "_stage_commands", "_stage_repaths", "_stage_interruptions", "stage_age_ms"]:
		check("negative counter " + field, rejects(changed(record, "values", field, -1), source))
	for field: String in CONTEXT:
		var other := CONTEXT.duplicate(); other[field] = "other"
		check("context mismatch " + field, not state.validate(record, other, source.ids, 2, source.to_node).ok)
	check("deferred boundary required", not state.capture(source.mission, CONTEXT, source.ids, 2, source.to_token, 100000, {"deferred_drained": false, "presentation_captured": true}).ok)
	check("presentation capture boundary required", not state.capture(source.mission, CONTEXT, source.ids, 2, source.to_token, 100000, {"deferred_drained": true, "presentation_captured": false}).ok)
	check("future stage clock rejected", not state.capture(source.mission, CONTEXT, source.ids, 2, source.to_token, 87000, BOUNDARY).ok)
	check("missing active Unit rejected", not state.validate(record, CONTEXT, {}, 2, source.to_node).ok)
	check("allocator boundary rejected", not state.validate(record, CONTEXT, source.ids, 1, source.to_node).ok)
	for field: String in State.NODE_FIELDS:
		if field in ["_scroll", "_scroll_content"]: continue
		check("missing external " + field, rejects(changed(record, "nodes", field, "missing"), source))
	for field: String in ["duration", "reach", "click_reach"]:
		check("action numeric type " + field, rejects(changed_row(record, "actions", field, "wrong"), source))
	check("zero action duration rejected", rejects(changed_row(record, "actions", "duration", 0.0), source))
	check("progress cannot already complete active action", rejects(changed(record, "values", "_progress", 1.5), source))
	check("active done action rejected", rejects(changed_row(record, "actions", "done", true), source))
	check("active blocked action rejected", rejects(changed_row(record, "actions", "blocked_reason", "closed"), source))
	check("unknown action field rejected", rejects(changed_row(record, "actions", "unreviewed", 1), source))
	check("string script path cannot replace marker", rejects(changed_row(record, "actions", "marker", "res://scripts/campaign_mission.gd"), source))
	check("float order counter rejected", rejects(changed(record, "values", "_generation", 3.0), source))
	check("invalid goal state rejected", rejects(changed_row(record, "story_goals", "state", "success"), source))
	check("duplicate required event rejected", rejects(changed_row(record, "story_goals", "required_events", ["x", "x"]), source))
	check("unknown goal field rejected", rejects(changed_row(record, "story_goals", "extra", true), source))
	check("mismatched goal identifier rejected", rejects(changed_row(record, "story_goals", "id", "quiet"), source))
	check("bad metric wall time rejected", rejects(changed_row(record, "stage_metrics", "wall_seconds", -1.0), source))
	check("unknown metrics end reason rejected", rejects(changed_row(record, "stage_metrics", "end_reason", "reload"), source))
	check("nonfrozen result cache rejected", rejects(changed(record, "result_cache", "core_cleared", true), source))
	var raw: Dictionary = codec.decode(record.payload).value
	for section: String in raw:
		var broken := record.duplicate(true); var data: Dictionary = raw.duplicate(true); data.erase(section); broken.payload = codec.encode(data).value
		check("missing section " + section, rejects(broken, source))
	var unknown := record.duplicate(true); unknown.payload = {"t": "object", "script": "res://arbitrary.gd"}
	check("object payload refused by codec", rejects(unknown, source))
	var target := fixture()
	check("presentation restoration promise required", not restore(target, record, 1000, false).ok)
	check("failed restore keeps new Mission pristine", target.mission.stage_id == "" and target.mission._generation == 0 and not target.mission.has_meta(State.INSTALLED))
	target.unit.set_block_signals(false)
	check("signal-enabled Unit rejected", not restore(target, record).ok)
	target.unit.set_block_signals(true)
	target.mission._status.set_block_signals(false)
	check("signal-enabled UI descendant rejected", not restore(target, record).ok)
	target.mission._status.set_block_signals(true)
	var button: Button = target.mission.actions.rescue.button
	button.pressed.disconnect(target.mission.focus_action.bind("rescue")); button.pressed.connect(source.mission.focus_action.bind("rescue"))
	check("old Mission callback rejected", not restore(target, record).ok)
	button.pressed.disconnect(source.mission.focus_action.bind("rescue")); button.pressed.connect(target.mission.focus_action.bind("rescue"))
	target.to_node["node:_title"] = source.mission._title
	check("old Mission UI rejected", not restore(target, record).ok)
	target.to_node["node:_title"] = target.mission._title
	add_child(target.owner)
	check("mounted Mission rejected even with disabled processing", not restore(target, record).ok)
	remove_child(target.owner)
	check("failed mounted restore does not replay events", target.mission.stage_id == "" and target.owner.level.callbacks == 0)
	var frozen := fixture(true)
	frozen.mission._stage_started_ms = Time.get_ticks_msec() - 12000
	var result: Dictionary = frozen.mission.result_snapshot(false)
	frozen.mission.finish_metrics(false)
	var frozen_capture := state.capture(frozen.mission, CONTEXT, frozen.ids, 2, frozen.to_token, Time.get_ticks_msec(), BOUNDARY)
	check("frozen defeat captures but cannot resume", frozen_capture.ok and not frozen_capture.get("resume_eligible", true))
	if frozen_capture.ok:
		var next := fixture(); var frozen_restore := restore(next, frozen_capture.record)
		check("frozen settlement restores without recomputation", frozen_restore.ok and not frozen_restore.get("resume_eligible", true) and next.mission.result_snapshot(true) == result)
		for field: String in ["story_done", "story_total", "contract_version"]:
			check("frozen result counter tamper " + field, rejects(changed(frozen_capture.record, "result_cache", field, 99), frozen))
		check("frozen result ids tamper", rejects(changed(frozen_capture.record, "result_cache", "pending_ids", []), frozen))

func run() -> void:
	var phase := OS.get_environment("LSH_MISSION_STATE_PHASE")
	if phase == "restart":
		var file := FileAccess.open(OS.get_environment("LSH_MISSION_STATE_SNAPSHOT"), FileAccess.READ)
		check("fresh process snapshot exists", file != null)
		if file != null:
			var record: Variant = JSON.parse_string(file.get_as_text()); file.close()
			check("fresh process JSON snapshot", typeof(record) == TYPE_DICTIONARY)
			if typeof(record) == TYPE_DICTIONARY: exercise_progress(record, "fresh process")
	else: full_suite()
	for fixture_data: Dictionary in fixtures:
		var mission: Variant = fixture_data.mission
		if Localize.language_changed.is_connected(mission._on_language_changed): Localize.language_changed.disconnect(mission._on_language_changed)
		unbind_branch(fixture_data.owner)
		fixture_data.owner.free(); fixture_data.unit.free()
	fixtures.clear()
	var passed: bool = checks.size() >= (20 if phase == "restart" else 90)
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"passed": passed, "component_only": true, "phase": phase, "checks": checks, "real_steam": false, "full_world": false}
	var report_path := OS.get_environment("LSH_MISSION_STATE_REPORT")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null: get_tree().quit(2); return
		file.store_string(JSON.stringify(report, "  ")); file.close()
	print("CAMPAIGN_MISSION_STATE_QA ", JSON.stringify(report))
	get_tree().quit(0 if passed else 1)
