extends RefCounted
## Per-battle mission state. Player UI locates tasks; request_action is reserved for QA drivers.
const STORY_PENDING := "pending"
const STORY_DONE := "done"
const STORY_MISSED := "missed"

var battle
var stage_id := ""
var stage_title := ""
var objective := ""
var core_goal := ""
var story_goals: Dictionary = {}
var story_contract_version := 1
var elapsed := 0.0
var events: Dictionary = {}
var report: Array[String] = []
var actions: Dictionary = {}
var active_action_id := ""
var _actor = null
var _progress := 0.0
var _retry := 0.0
var _generation := 0
const AUTO_DISPATCH_META := &"campaign_mission_auto_dispatch"
var _panel: PanelContainer
var _title: Label
var _core: Label
var _story: Label
var _objective: Label
var _buttons: VBoxContainer
var _status: Label
var _markers: Array = []
var stage_metrics: Array[Dictionary] = []
var total_game_seconds := 0.0
var _stage_started_ms := 0
var _stage_commands := 0
var _stage_repaths := 0
var _stage_interruptions := 0
var _metrics_closed := true
var _campaign_configured := false
var _story_miss_notified := false
var _result_frozen := false
var _result_cache: Dictionary = {}

func _init(owner) -> void:
	battle = owner
	_panel = PanelContainer.new()
	_panel.theme = UITheme.shared()
	_panel.name = "CampaignObjectives"
	_panel.position = Vector2(84, 78)
	_panel.custom_minimum_size = Vector2(286, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UITheme.PANEL, 0.95)
	style.border_color = UITheme.COPPER
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", UITheme.PAPER_DARK)
	box.add_child(_title)
	_core = Label.new()
	_core.custom_minimum_size.x = 262
	_core.add_theme_font_size_override("font_size", 14)
	_core.add_theme_color_override("font_color", UITheme.COMPLETE)
	_core.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_core.hide()
	box.add_child(_core)
	_story = Label.new()
	_story.custom_minimum_size.x = 262
	_story.add_theme_font_size_override("font_size", 13)
	_story.add_theme_color_override("font_color", UITheme.PAPER_MUTED)
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.hide()
	box.add_child(_story)
	_objective = Label.new()
	_objective.custom_minimum_size.x = 262
	_objective.add_theme_font_size_override("font_size", 15)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_objective)
	_buttons = VBoxContainer.new()
	box.add_child(_buttons)
	_status = Label.new()
	_status.custom_minimum_size.x = 262
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	battle.hud.add_child(_panel)
	_panel.hide()

func configure_campaign(core_text: String, goals: Array, contract_version := 1) -> void:
	# A battle owns one contract. Repeated start signals must not erase goals already
	# completed in an earlier act of the same battle.
	if _campaign_configured or _result_frozen:
		return
	_campaign_configured = true
	core_goal = core_text.strip_edges()
	story_contract_version = maxi(1, int(contract_version))
	story_goals.clear()
	for raw_goal in goals:
		if not raw_goal is Dictionary:
			continue
		var raw: Dictionary = raw_goal
		var goal_id := String(raw.get("id", "")).strip_edges()
		if goal_id == "" or story_goals.has(goal_id):
			continue
		var label := String(raw.get("label", goal_id)).strip_edges()
		story_goals[goal_id] = {
			"id": goal_id,
			"label": label if label != "" else goal_id,
			"required_events": _event_id_list(raw.get("required_events", [])),
			"forbidden_events": _event_id_list(raw.get("forbidden_events", [])),
			"state": STORY_PENDING,
			"note": "",
			"reason": "",
		}
	_evaluate_all_story_goals(false)
	_refresh_campaign_text()

func _event_id_list(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is String or value is StringName:
		var one := String(value).strip_edges()
		if one != "": out.append(one)
	elif value is Array or value is PackedStringArray:
		for item in value:
			var event_id := String(item).strip_edges()
			if event_id != "" and not out.has(event_id): out.append(event_id)
	return out

func complete_story_goal(goal_id: String, note := "") -> bool:
	if _result_frozen or not story_goals.has(goal_id):
		return false
	var goal: Dictionary = story_goals[goal_id]
	if String(goal.state) != STORY_PENDING:
		return false
	goal.state = STORY_DONE
	goal.note = note
	if note != "": report.append("演义完成 · %s：%s" % [goal.label, note])
	_refresh_campaign_text()
	return true

func miss_story_goal(goal_id: String, reason: String) -> bool:
	if _result_frozen or not story_goals.has(goal_id):
		return false
	var goal: Dictionary = story_goals[goal_id]
	if String(goal.state) == STORY_MISSED:
		return false
	goal.state = STORY_MISSED
	goal.reason = reason
	report.append("演义未成 · %s%s" % [goal.label, "：" + reason if reason != "" else ""])
	if not _story_miss_notified:
		_story_miss_notified = true
		battle.msg("演义条件未达成：%s。本关仍可继续。" % (reason if reason != "" else String(goal.label)), 5.0)
	_refresh_campaign_text()
	return true

func result_snapshot(victory: bool) -> Dictionary:
	if _result_frozen:
		return _result_cache.duplicate(true)
	# Required events are only a candidate during play. Freeze them as DONE here
	# so a later forbidden event cannot leave a false full seal behind.
	_evaluate_all_story_goals(victory)
	if victory:
		# A required original-story beat that remained pending was not completed in
		# this run. Resolve it silently at settlement; runtime deviation already has
		# its own single notification path.
		for goal_id in story_goals:
			var pending: Dictionary = story_goals[goal_id]
			if String(pending.state) == STORY_PENDING:
				pending.state = STORY_MISSED
				pending.reason = "本局未完成"
	var done_ids: Array[String] = []
	var missed_ids: Array[String] = []
	var pending_ids: Array[String] = []
	var rows: Array[Dictionary] = []
	for goal_id in story_goals:
		var goal: Dictionary = story_goals[goal_id]
		var state := String(goal.state)
		if state == STORY_DONE: done_ids.append(goal_id)
		elif state == STORY_MISSED: missed_ids.append(goal_id)
		else: pending_ids.append(goal_id)
		rows.append({"id":goal_id,"label":String(goal.label),"state":state,
			"note":String(goal.note),"reason":String(goal.reason)})
	var total := story_goals.size()
	_result_cache = {
		"core_cleared": victory,
		"core_goal": core_goal,
		"story_complete": victory and total > 0 and done_ids.size() == total,
		"story_done": done_ids.size(),
		"story_total": total,
		"done_ids": done_ids,
		"missed_ids": missed_ids,
		"pending_ids": pending_ids,
		"goals": rows,
		"contract_version": story_contract_version,
	}
	_result_frozen = true
	_refresh_campaign_text()
	return _result_cache.duplicate(true)

func result_report(result: Dictionary) -> String:
	var total := int(result.get("story_total", 0))
	var lines: Array[String] = ["基础通关：%s" % ("完成" if bool(result.get("core_cleared", false)) else "未完成")]
	if total > 0:
		lines.append("演义复现：%d/%d%s" % [int(result.get("story_done", 0)), total,
			" · 获得演义印" if bool(result.get("story_complete", false)) else ""])
	return "\n".join(lines)

func _evaluate_story_event(event_id: String) -> void:
	if _result_frozen:
		return
	for goal_id in story_goals:
		var goal: Dictionary = story_goals[goal_id]
		if goal.forbidden_events.has(event_id):
			# Forbidden event ids are stable implementation keys. They must never leak
			# into player-facing toasts or the battle report.
			miss_story_goal(goal_id, "本局已偏离“%s”的原著条件" % String(goal.label))
	_refresh_campaign_text()

func _evaluate_all_story_goals(finalize_required := false) -> void:
	if _result_frozen:
		return
	for goal_id in story_goals:
		var goal: Dictionary = story_goals[goal_id]
		var forbidden: Array = goal.forbidden_events
		var violated := false
		for event_id in forbidden:
			if events.has(event_id):
				miss_story_goal(goal_id, "本局已偏离“%s”的原著条件" % String(goal.label))
				violated = true
				break
		if violated or String(goal.state) != STORY_PENDING:
			continue
		var required: Array = goal.required_events
		if finalize_required and not required.is_empty() \
				and required.all(func(required_id): return events.has(required_id)):
			complete_story_goal(goal_id)

func _refresh_campaign_text() -> void:
	if _core == null or _story == null:
		return
	_core.visible = core_goal != ""
	_core.text = "核心目标 · " + core_goal if core_goal != "" else ""
	_story.visible = not story_goals.is_empty()
	if story_goals.is_empty():
		_story.text = ""
		return
	var done := 0
	var rows: Array[String] = []
	for goal_id in story_goals:
		var goal: Dictionary = story_goals[goal_id]
		var state := String(goal.state)
		if state == STORY_DONE: done += 1
		var icon := "✓" if state == STORY_DONE else ("×" if state == STORY_MISSED else "○")
		var progress := ""
		var required: Array = goal.required_events
		if state == STORY_PENDING and not required.is_empty():
			var matched := 0
			for event_id in required:
				if events.has(event_id): matched += 1
			progress = " %d/%d" % [matched, required.size()]
			if matched == required.size(): icon = "◐"
		rows.append("%s %s%s" % [icon, String(goal.label), progress])
	_story.text = "演义目标（可选） %d/%d\n%s" % [done, story_goals.size(), "\n".join(rows)]

func begin(new_id: String, title: String, text: String) -> void:
	if active_action_id!="": _stage_interruptions+=1
	_clear_auto_dispatch(_actor)
	_close_stage_metrics("transition")
	_generation += 1
	stage_id = new_id
	stage_title = title
	elapsed = 0.0
	_stage_started_ms = Time.get_ticks_msec()
	_stage_commands = 0
	_stage_repaths = 0
	_stage_interruptions = 0
	_metrics_closed = false
	actions.clear()
	active_action_id = ""
	_actor = null
	_progress = 0.0
	for child in _buttons.get_children():
		child.queue_free()
	for marker in _markers:
		if is_instance_valid(marker): marker.queue_free()
	_markers.clear()
	_title.text = title
	set_objective(text)
	_status.text = "任务按钮只定位现场；请自行选人并右键目标标记。"

## Change the heading while ongoing economy, actions and their progress continue.
func set_title(text: String) -> void:
	stage_title = text
	_title.text = text

func set_objective(text: String) -> void:
	objective = text
	_objective.text = text

func set_status(text: String) -> void:
	_status.text = text

func add_action(action_id: String, label: String, cell: Vector2i, actors: Array, duration := 1.0, reach := 96.0, click_reach := 48.0, show_button := true) -> void:
	if actions.has(action_id):
		return
	var button = null
	if show_button:
		button = Button.new()
		button.text = "查看 · %s" % label
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size", 15)
		button.tooltip_text = "定位现场；移动、攻击和交互均由玩家下令。建议人物：%s" % _actor_labels(actors)
		button.pressed.connect(focus_action.bind(action_id))
		_buttons.add_child(button)
	var marker := MissionMarker.new()
	marker.position = battle.map.cell_to_world(cell)
	marker.label = label
	marker.number = actions.size()+1
	marker.show_caption = not show_button
	marker.z_index = 3450
	battle.fx_root.add_child(marker)
	_markers.append(marker)
	battle.map.sync_render_position(marker)
	# click_reach 只判断玩家是否明确点中标记；reach 是人物办理距离。二者
	# 必须分开，拥挤场景放宽人物距离时不能顺便吞掉附近普通移动命令。
	actions[action_id] = {"label": label, "cell": cell, "actors": actors, "duration": maxf(0.1, duration),
		"reach":clampf(reach,24.0,160.0), "click_reach":clampf(click_reach,24.0,64.0), "button": button,
		"show_button": show_button, "done": false}
	actions[action_id]["marker"] = marker
	if not show_button:
		_status.text = "没有自动寻路按钮；选中人物后右键场景标记即可行动。"

func update_action_actors(action_id: String, actor_keys: Array) -> void:
	if not actions.has(action_id):
		return
	var action: Dictionary = actions[action_id]
	action["actors"] = actor_keys
	var button = action.get("button")
	if is_instance_valid(button):
		button.tooltip_text = "定位现场；移动、攻击和交互均由玩家下令。建议人物：%s" % _actor_labels(actor_keys)
	_refresh_marker_captions()

func focus_action(action_id: String) -> bool:
	if battle.phase != battle.Phase.FIGHT or not actions.has(action_id):
		return false
	var action: Dictionary = actions[action_id]
	if action.done:
		return false
	battle.center_camera_cell(action.cell)
	_status.text = "已定位：%s。请自行选人并右键场景标记。" % action.label
	return true

func _refresh_marker_captions() -> void:
	for action_id in actions:
		var marker = actions[action_id].marker
		# The numbered HUD button already contains the full instruction. Repeating it
		# over the destination obscures the person/boat when an actor arrives there.
		marker.show_caption = not bool(actions[action_id].get("show_button", true))
		marker.queue_redraw()

func request_action(action_id: String) -> bool:
	if battle.phase != battle.Phase.FIGHT or not actions.has(action_id):
		return false
	var action: Dictionary = actions[action_id]
	if action.done or active_action_id == action_id:
		return false
	var destination: Vector2 = battle.map.cell_to_world(action.cell)
	var candidate = null
	var best := INF
	for u in battle.units:
		if not _valid_action_actor(u, action):
			continue
		var score: float = u.position.distance_squared_to(destination)
		if battle.selection.has(u):
			score -= 100000000.0
		if score < best:
			candidate = u
			best = score
	if candidate == null:
		_status.text = "所需人物不在场，或仍被绑缚。"
		return false
	_start_action(action_id, candidate, true)
	return true

func _start_action(action_id: String, candidate, dispatch: bool) -> void:
	var action: Dictionary = actions[action_id]
	_stage_commands += 1
	if active_action_id != "":
		_stage_interruptions += 1
		_clear_auto_dispatch(_actor)
	_actor = candidate
	active_action_id = action_id
	_progress = 0.0
	_retry = 0.0
	if dispatch:
		var destination: Vector2 = battle.map.cell_to_world(action.cell)
		_actor.set_meta(AUTO_DISPATCH_META, true)
		_actor.clear_mission_order_intent()
		_actor.order_move(destination)
		_actor.manual_order_t = 60.0
		_status.text = "%s：前往%s" % [_actor.display_name, action.label]
	else:
		# Claim exactly one compatible action for this player command. Otherwise a
		# newly-added colocated follow-up could consume the same old move order.
		_actor.manual_order_t = 0.0
		_actor.manual_order_active = false
		_actor.clear_mission_order_intent()
		_status.text = "%s：已手动到达，开始%s" % [_actor.display_name, action.label]
	_refresh_marker_captions()

func _valid_action_actor(u, action: Dictionary) -> bool:
	if not is_instance_valid(u) or u.hp <= 0 or u.faction != Unit.FACTION_LIANG or u.is_captive or u.garrisoned or u.story_outcome != "":
		return false
	return action.actors.is_empty() or action.actors.has(u.key)

func _clear_auto_dispatch(candidate) -> void:
	if not is_instance_valid(candidate):
		return
	candidate.clear_mission_order_intent()
	if bool(candidate.get_meta(AUTO_DISPATCH_META, false)):
		candidate.remove_meta(AUTO_DISPATCH_META)
		# The task button uses this timer only to protect its route from battle AI.
		# Clearing it prevents a newly-created action at the same marker from being
		# mistaken for a fresh player order after the first action completes.
		candidate.manual_order_t = 0.0
		candidate.manual_order_active = false

func on_player_order(candidate) -> void:
	if active_action_id == "" or candidate != _actor:
		return
	_stage_interruptions += 1
	_clear_auto_dispatch(candidate)
	active_action_id = ""
	_actor = null
	_progress = 0.0
	_retry = 0.0
	_status.text = "玩家已改令，现场动作取消。"
	_refresh_marker_captions()

func _consume_mission_order_token(token: int) -> void:
	if token <= 0:
		return
	for unit in battle.units:
		if is_instance_valid(unit) and unit.mission_order_token == token:
			unit.clear_mission_order_intent()

func _try_manual_action() -> bool:
	if battle.phase != battle.Phase.FIGHT or active_action_id != "":
		return false
	var selected_action_id := ""
	var selected_candidate = null
	var best_click_distance := INF
	var best_actor_distance := INF
	for action_id in actions:
		var action: Dictionary = actions[action_id]
		if action.done:
			continue
		var destination: Vector2 = battle.map.cell_to_world(action.cell)
		for u in battle.units:
			# 只接受一次明确的移动右键，并核对玩家点击的原始目标就是本任务区。
			# 通用手动保护戳、途经任务区、攻击、S/H/P 与脚本位移都不能认领动作。
			if not _valid_action_actor(u, action) \
					or (not u.mission_order_active and u.mission_order_arrival_t <= 0.0) \
					or u.mission_order_token <= 0 \
					or u.mission_order_target == Vector2.INF \
					or bool(u.get_meta(AUTO_DISPATCH_META, false)):
				continue
			var click_distance: float = u.mission_order_target.distance_to(destination)
			if click_distance > float(action.click_reach):
				continue
			var distance: float = u.position.distance_to(destination)
			if distance > float(action.reach) or not battle.map._segment_open(u.position, destination, u.movement_profile):
				continue
			if click_distance < best_click_distance - 0.01 \
					or (is_equal_approx(click_distance, best_click_distance) and distance < best_actor_distance):
				selected_action_id = String(action_id)
				selected_candidate = u
				best_click_distance = click_distance
				best_actor_distance = distance
	if selected_candidate != null:
		# 一次群选移动共享同一 token；任何一项认领后整组凭证同时消费，
		# 不允许同一右键在相邻标记间连续办理多项任务。
		_consume_mission_order_token(int(selected_candidate.mission_order_token))
		_start_action(selected_action_id, selected_candidate, false)
		return true
	return false

func _actor_labels(actor_keys: Array) -> String:
	if actor_keys.is_empty():
		return "任一可行动好汉"
	var names: Array[String] = []
	for key_value in actor_keys:
		var key := String(key_value)
		if key.begins_with("__") and not battle._defs.has(key):
			continue
		var label := key
		if battle._defs.has(key):
			label = String(battle._defs[key].get("name", key))
		names.append(label)
	if names.is_empty():
		return "暂时无人可接手"
	return "、".join(names)

func tick(delta: float) -> void:
	_panel.visible = battle.phase == battle.Phase.FIGHT and stage_id != ""
	if not _panel.visible:
		return
	_panel.position = battle.hud.campaign_objective_position()
	_panel.reset_size()
	elapsed += delta
	total_game_seconds += delta
	if active_action_id == "":
		_try_manual_action()
		if active_action_id == "":
			return
	if not is_instance_valid(_actor) or _actor.hp <= 0 or _actor.story_outcome != "" or _actor.is_captive or _actor.garrisoned:
		_stage_interruptions += 1
		_clear_auto_dispatch(_actor)
		active_action_id = ""
		_actor = null
		_progress = 0.0
		_retry = 0.0
		_status.text = "办理中断：人物已无法行动。"
		return
	var action: Dictionary = actions[active_action_id]
	var destination: Vector2 = battle.map.cell_to_world(action.cell)
	_retry += delta
	if _actor.position.distance_to(destination) > float(action.reach) or not battle.map._segment_open(_actor.position, destination, _actor.movement_profile):
		_progress = 0.0
		if _retry > 3.0:
			if bool(_actor.get_meta(AUTO_DISPATCH_META, false)):
				# request_action() 只保留给自动回归夹具；玩家界面不会进入该分支。
				_stage_repaths += 1
				_actor.order_move(destination)
				_retry = 0.0
			else:
				var interrupted_actor = _actor
				active_action_id = ""
				_actor = null
				_progress = 0.0
				_retry = 0.0
				_status.text = "%s离开办理范围；请重新下令到目标标记。" % interrupted_actor.display_name
		return
	_actor.order_stop()
	_progress += delta
	_status.text = "%s：%s %d%%" % [_actor.display_name, action.label, mini(100, int(100.0 * _progress / action.duration))]
	if _progress < action.duration:
		return
	# Commit before callback: another hit/click or a phase switch cannot resolve it twice.
	var finished := active_action_id
	var actor = _actor
	_clear_auto_dispatch(actor)
	action.done = true
	if is_instance_valid(action.button):
		action.button.disabled = true
	action.marker.hide()
	active_action_id = ""
	_actor = null
	_refresh_marker_captions()
	mark("action:%s:%s" % [stage_id, finished], String(action.label))
	battle.level.on_mission_action(battle, finished, actor)

func mark(event_id: String, text: String) -> bool:
	if events.has(event_id):
		return false
	events[event_id] = true
	report.append(text)
	battle.msg(text)
	_evaluate_story_event(event_id)
	return true

func has_event(event_id: String) -> bool:
	return events.has(event_id)

func finish_metrics(victory: bool) -> void:
	if _metrics_closed or stage_id == "": return
	# A terminal result cancels a pending task just like a phase transition.
	if active_action_id != "": _stage_interruptions += 1
	_close_stage_metrics("victory" if victory else "defeat")

func _close_stage_metrics(reason: String) -> void:
	if _metrics_closed or stage_id == "": return
	_metrics_closed = true
	# In-memory only. QA may export this; ordinary play never adds a save or telemetry upload.
	stage_metrics.append({"stage":stage_id,"game_seconds":elapsed,
		"wall_seconds":float(Time.get_ticks_msec()-_stage_started_ms)/1000.0,
		"accepted_task_commands":_stage_commands,"automatic_repaths":_stage_repaths,
		"task_interruptions":_stage_interruptions,"end_reason":reason})

class MissionMarker extends Node2D:
	var label := ""
	var number := 1
	var show_caption := true
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 25, 0, TAU, 28, Color(0.98,0.79,0.34,0.86), 2.0)
		draw_set_transform_matrix(GameMap.ISO_INV)
		draw_line(Vector2(0,-8),Vector2(0,-30),Color(0.98,0.79,0.34),2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-30),Vector2(16,-26),Vector2(0,-22)]),Color(0.98,0.79,0.34))
		draw_string(ThemeDB.fallback_font,Vector2(1,-15),str(number),HORIZONTAL_ALIGNMENT_CENTER,18,12,Color(1.0,0.90,0.66))
		if show_caption:
			draw_string(ThemeDB.fallback_font,Vector2(-50,-40),label,HORIZONTAL_ALIGNMENT_CENTER,100,12,Color(1.0,0.90,0.66))
