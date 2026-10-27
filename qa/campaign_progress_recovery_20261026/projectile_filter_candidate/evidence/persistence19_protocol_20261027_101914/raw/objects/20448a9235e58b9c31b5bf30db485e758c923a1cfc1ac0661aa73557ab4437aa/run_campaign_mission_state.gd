extends RefCounted
## Explicit Mission component. A trusted caller owns the detached Battle, UI
## factory, localization bindings and visual graph. No begin(), gameplay tick,
## event replay, dynamic script loading, scene mount or activation occurs here.
const Mission := preload("res://scripts/campaign_mission.gd")
const UnitScript := preload("res://scripts/unit.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const SCHEMA := "campaign_mission_component_v1"
const LEVELS := ["level1", "level2", "level3", "level4", "level5", "level6", "level7", "level8"]
const LIMIT := 4096
const MAX_AGE_MS := 9007199254740991
const INSTALLED := &"_run_campaign_mission_restored"
const VALUE_FIELDS := {
	"stage_id": TYPE_STRING, "stage_title": TYPE_STRING, "objective": TYPE_STRING,
	"core_goal": TYPE_STRING, "story_contract_version": TYPE_INT,
	"elapsed": TYPE_FLOAT, "active_action_id": TYPE_STRING, "_progress": TYPE_FLOAT,
	"_retry": TYPE_FLOAT, "_generation": TYPE_INT, "_expanded": TYPE_BOOL,
	"_feedback_text": TYPE_STRING, "_feedback_active": TYPE_BOOL, "_feedback_left": TYPE_FLOAT,
	"total_game_seconds": TYPE_FLOAT, "_stage_commands": TYPE_INT,
	"_stage_repaths": TYPE_INT, "_stage_interruptions": TYPE_INT, "_metrics_closed": TYPE_BOOL,
	"_campaign_configured": TYPE_BOOL, "_story_miss_notified": TYPE_BOOL, "_result_frozen": TYPE_BOOL}
const NODE_FIELDS := ["_panel", "_toggle", "_details", "_detail_scroll", "_title", "_core",
	"_story", "_objective", "_buttons", "_status", "_scroll", "_scroll_content"]
const OTHER_FIELDS := ["battle", "story_goals", "events", "report", "actions", "_actor",
	"_markers", "stage_metrics", "_stage_started_ms", "_result_cache"]
const ACTION_FIELDS := ["label", "cell", "actors", "duration", "reach", "click_reach", "button", "show_button", "done", "marker"]
const OPTIONAL_ACTION_FIELDS := ["actor_button", "blocked_reason", "settle_margin", "quiet_complete"]
var _codec := Codec.new()

func _bad(code: String, field := "") -> Dictionary:
	return {"ok": false, "code": code, "field": field, "complete_world": false}

func _fields(value: Variant, names: Array) -> bool:
	if typeof(value) != TYPE_DICTIONARY or value.size() != names.size(): return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return true

func _text(value: Variant, empty := true, maximum := 4096) -> bool:
	return typeof(value) == TYPE_STRING and value.length() <= maximum and (empty or not value.is_empty())

func _token(value: Variant) -> bool:
	return _text(value, false, 256)

func _integer(value: Variant, minimum := 0, maximum := MAX_AGE_MS) -> bool:
	return typeof(value) == TYPE_INT and value >= minimum and value <= maximum

func _number(value: Variant, minimum := 0.0) -> bool:
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value >= minimum

func _id(value: Variant) -> bool:
	if not _text(value, false, 19) or value[0] == "0": return false
	for c: String in value:
		if c < "0" or c > "9": return false
	return value.length() < 19 or value <= "9223372036854775806"

func _context(context: Variant) -> bool:
	return _fields(context, ["level_id", "content_version", "mission_token", "presentation_token"]) and context.level_id in LEVELS and _token(context.content_version) and _token(context.mission_token) and _token(context.presentation_token)

func _strings(value: Variant, unique := false, empty_items := false) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() > LIMIT: return false
	var seen := {}
	for item: Variant in value:
		if not _text(item, empty_items) or (unique and seen.has(item)): return false
		seen[item] = true
	return true

func audit_declarations() -> Dictionary:
	var expected: Array = VALUE_FIELDS.keys() + NODE_FIELDS + OTHER_FIELDS
	var found := {}
	var mission_script: Script = Mission
	for property: Dictionary in mission_script.get_script_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: found[String(property.name)] = true
	for field: String in found:
		if field not in expected: return _bad("UNCLASSIFIED_DECLARATION", field)
	for field: String in expected:
		if not found.has(field): return _bad("MISSING_DECLARATION", field)
	return {"ok": true, "fields": expected.size()}

func _private(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and not node.is_queued_for_deletion() and not node.is_inside_tree() and node.process_mode == Node.PROCESS_MODE_DISABLED and node.is_blocking_signals()

func _private_branch(node: Node) -> bool:
	if not _private(node): return false
	for child: Node in node.get_children(true):
		if not _private_branch(child): return false
	return true

func _registry(ids: Dictionary, next_id: int, prepared := false) -> Dictionary:
	if ids.size() > LIMIT or next_id < 1: return _bad("UNIT_REGISTRY_LIMIT")
	var inverse := {}
	for id: Variant in ids:
		var unit: Variant = ids[id]
		if not _id(id) or String(id).to_int() >= next_id or not is_instance_valid(unit) or unit.get_script() != UnitScript or unit.is_queued_for_deletion() or str(unit.entity_id) != id or inverse.has(unit): return _bad("UNIT_REGISTRY")
		if prepared and not _private(unit): return _bad("PRIVATE_UNIT_REQUIRED")
		inverse[unit] = id
	return {"ok": true, "inverse": inverse}

func _node_kind(field: String, node: Variant) -> bool:
	if field in ["_scroll", "_scroll_content"] and node == null: return true
	if not is_instance_valid(node) or not node is Node or node.is_queued_for_deletion(): return false
	match field:
		"_panel": return node is PanelContainer
		"_toggle", "button", "actor_button", "button_order": return node is Button
		"_details", "_buttons", "_scroll_content": return node is VBoxContainer
		"_detail_scroll", "_scroll": return node is ScrollContainer
		"marker", "marker_order": return node.get_script() == Mission.MissionMarker
	return node is Label

func _encode_node(node: Variant, field: String, inverse: Dictionary, nullable := false) -> Dictionary:
	if node == null and nullable: return {"ok": true, "value": null}
	if not _node_kind(field, node) or not inverse.has(node) or not _token(inverse[node]): return _bad("EXTERNAL_BINDING", field)
	return {"ok": true, "value": inverse[node]}

func _decode_node(token: Variant, field: String, nodes: Dictionary, nullable := false) -> Dictionary:
	if token == null and nullable: return {"ok": true, "value": null}
	if not _token(token) or not nodes.has(token): return _bad("EXTERNAL_BINDING", field)
	return {"ok": true, "value": nodes[token]}

func capture(mission: Variant, context: Dictionary, id_to_unit: Dictionary, next_entity_id: int,
		external_to_token: Dictionary, capture_ticks_msec: int, boundary: Dictionary) -> Dictionary:
	if not _context(context): return _bad("TRUSTED_CONTEXT")
	if not is_instance_valid(mission) or mission.get_script() != Mission: return _bad("OFFICIAL_MISSION_REQUIRED")
	if not _fields(boundary, ["deferred_drained", "presentation_captured"]) or boundary.deferred_drained != true or boundary.presentation_captured != true: return _bad("EXTERNAL_BOUNDARY_REQUIRED")
	if not _integer(capture_ticks_msec): return _bad("CAPTURE_CLOCK")
	var audit := audit_declarations()
	if not audit.ok: return audit
	var registry := _registry(id_to_unit, next_entity_id)
	if not registry.ok: return registry
	var known_external := {}
	for node: Variant in external_to_token:
		var token: Variant = external_to_token[node]
		if not _token(token) or known_external.has(token) or not is_instance_valid(node) or not node is Node or node.is_queued_for_deletion(): return _bad("EXTERNAL_REGISTRY")
		known_external[token] = node
	var data := {"values": {}, "story_goals": [], "events": [], "report": mission.report.duplicate(),
		"actions": [], "stage_metrics": mission.stage_metrics.duplicate(true), "result_cache": mission._result_cache.duplicate(true),
		"actor": null, "nodes": {}, "button_order": [], "marker_order": [], "scroll": {"horizontal": 0, "vertical": 0}}
	for field: String in VALUE_FIELDS: data.values[field] = mission.get(field)
	var started: Variant = mission._stage_started_ms
	if typeof(started) != TYPE_INT or started > capture_ticks_msec or started < capture_ticks_msec - MAX_AGE_MS: return _bad("STAGE_CLOCK")
	data.values["stage_age_ms"] = capture_ticks_msec - started
	for goal_id: Variant in mission.story_goals:
		var raw: Variant = mission.story_goals[goal_id]
		if not _text(goal_id, false) or typeof(raw) != TYPE_DICTIONARY or raw.get("id") != goal_id: return _bad("STORY_GOAL_ID")
		data.story_goals.append(raw.duplicate(true))
	for event_id: Variant in mission.events:
		if not _text(event_id, false) or typeof(mission.events[event_id]) != TYPE_BOOL or not mission.events[event_id]: return _bad("EVENT")
		data.events.append(event_id)
	if mission._actor != null:
		if not is_instance_valid(mission._actor) or not registry.inverse.has(mission._actor): return _bad("ACTIVE_ACTOR_UNBOUND")
		data.actor = registry.inverse[mission._actor]
	for field: String in NODE_FIELDS:
		var encoded := _encode_node(mission.get(field), field, external_to_token, field in ["_scroll", "_scroll_content"])
		if not encoded.ok: return encoded
		data.nodes[field] = encoded.value
	data.scroll.horizontal = mission._detail_scroll.scroll_horizontal
	data.scroll.vertical = mission._detail_scroll.scroll_vertical
	for node: Node in mission._buttons.get_children():
		var encoded := _encode_node(node, "button_order", external_to_token)
		if not encoded.ok: return encoded
		data.button_order.append(encoded.value)
	for node: Variant in mission._markers:
		var encoded := _encode_node(node, "marker_order", external_to_token)
		if not encoded.ok: return encoded
		data.marker_order.append(encoded.value)
	for action_id: Variant in mission.actions:
		var raw: Variant = mission.actions[action_id]
		if not _text(action_id, false) or typeof(raw) != TYPE_DICTIONARY or not raw.has_all(ACTION_FIELDS): return _bad("ACTION_FIELDS")
		for key: Variant in raw:
			if key not in ACTION_FIELDS and key not in OPTIONAL_ACTION_FIELDS: return _bad("UNKNOWN_ACTION_FIELD", str(key))
		var row: Dictionary = {"id": action_id}
		for field: String in raw:
			if field in ["button", "actor_button", "marker"]:
				var encoded := _encode_node(raw[field], field, external_to_token, field == "button")
				if not encoded.ok: return encoded
				row[field] = encoded.value
			else: row[field] = raw[field]
		data.actions.append(row)
	var packed := _codec.encode(data)
	if not packed.ok: return packed
	var record := {"schema": SCHEMA, "context": context.duplicate(true), "payload": packed.value}
	var checked := validate(record, context, id_to_unit, next_entity_id, known_external)
	if not checked.ok: return checked
	return {"ok": true, "record": record, "complete_world": false, "resume_eligible": checked.resume_eligible}

func _goals(rows: Variant, events: Array, frozen: bool) -> Dictionary:
	if typeof(rows) != TYPE_ARRAY or rows.size() > LIMIT: return _bad("STORY_GOALS")
	var result := {}
	for row: Variant in rows:
		if not _fields(row, ["id", "label", "required_events", "forbidden_events", "state", "note", "reason"]): return _bad("STORY_GOAL_FIELDS")
		if not _text(row.id, false) or result.has(row.id) or not _text(row.label, false) or not _strings(row.required_events, true) or not _strings(row.forbidden_events, true) or row.state not in ["pending", "done", "missed"] or not _text(row.note) or not _text(row.reason): return _bad("STORY_GOAL_VALUE")
		if not frozen and row.state != "missed":
			for event_id: String in row.forbidden_events:
				if events.has(event_id): return _bad("STORY_FORBIDDEN_EVENT", row.id)
		result[row.id] = row
	return {"ok": true, "value": result}

func _metrics(rows: Variant) -> bool:
	if typeof(rows) != TYPE_ARRAY or rows.size() > LIMIT: return false
	for row: Variant in rows:
		if not _fields(row, ["stage", "game_seconds", "wall_seconds", "accepted_task_commands", "automatic_repaths", "task_interruptions", "end_reason"]): return false
		if not _text(row.stage, false) or not _number(row.game_seconds) or not _number(row.wall_seconds) or not _integer(row.accepted_task_commands) or not _integer(row.automatic_repaths) or not _integer(row.task_interruptions) or row.end_reason not in ["transition", "victory", "defeat"]: return false
	return true

func _result(cache: Variant, values: Dictionary, goals: Dictionary) -> bool:
	if not values._result_frozen: return typeof(cache) == TYPE_DICTIONARY and cache.is_empty()
	if not _fields(cache, ["core_cleared", "core_goal", "story_complete", "story_done", "story_total", "done_ids", "missed_ids", "pending_ids", "goals", "contract_version"]): return false
	if typeof(cache.core_cleared) != TYPE_BOOL or typeof(cache.story_complete) != TYPE_BOOL or not _integer(cache.story_done) or not _integer(cache.story_total) or not _integer(cache.contract_version, 1): return false
	var done: Array = []; var missed: Array = []; var pending: Array = []; var rows: Array = []
	for id: String in goals:
		var goal: Dictionary = goals[id]
		if goal.state == "done": done.append(id)
		elif goal.state == "missed": missed.append(id)
		else: pending.append(id)
		rows.append({"id": id, "label": goal.label, "state": goal.state, "note": goal.note, "reason": goal.reason})
	return cache.core_goal == values.core_goal and cache.contract_version == values.story_contract_version and cache.story_total == goals.size() and cache.story_done == done.size() and cache.done_ids == done and cache.missed_ids == missed and cache.pending_ids == pending and cache.goals == rows and cache.story_complete == (cache.core_cleared and not goals.is_empty() and done.size() == goals.size()) and (not cache.core_cleared or pending.is_empty())

func validate(record: Variant, context: Dictionary, known_unit_ids: Dictionary, next_entity_id: int, external_tokens: Dictionary) -> Dictionary:
	if not _context(context): return _bad("TRUSTED_CONTEXT")
	var audit := audit_declarations()
	if not audit.ok: return audit
	if not _fields(record, ["schema", "context", "payload"]) or record.schema != SCHEMA or record.context != context: return _bad("RECORD_IDENTITY")
	if next_entity_id < 1 or known_unit_ids.size() > LIMIT or external_tokens.size() > LIMIT: return _bad("REGISTRY_LIMIT")
	for id: Variant in known_unit_ids:
		if not _id(id) or String(id).to_int() >= next_entity_id: return _bad("UNIT_REGISTRY")
	var decoded := _codec.decode(record.payload)
	if not decoded.ok: return decoded
	var data: Variant = decoded.value
	if not _fields(data, ["values", "story_goals", "events", "report", "actions", "stage_metrics", "result_cache", "actor", "nodes", "button_order", "marker_order", "scroll"]): return _bad("PAYLOAD_FIELDS")
	if not _fields(data.values, VALUE_FIELDS.keys() + ["stage_age_ms"]): return _bad("VALUE_FIELDS")
	var values: Dictionary = data.values
	for field: String in VALUE_FIELDS:
		var value: Variant = values[field]
		if typeof(value) != VALUE_FIELDS[field]: return _bad("VALUE_TYPE", field)
		if typeof(value) == TYPE_STRING and not _text(value): return _bad("TEXT_LIMIT", field)
		if typeof(value) == TYPE_FLOAT and not _number(value): return _bad("TIMER_VALUE", field)
		if typeof(value) == TYPE_INT and not _integer(value, 1 if field == "story_contract_version" else 0): return _bad("COUNTER_VALUE", field)
	if not _integer(values.stage_age_ms) or values.elapsed > values.total_game_seconds: return _bad("CLOCK_VALUE")
	if not _strings(data.events, true) or not _strings(data.report, false, true): return _bad("EVENTS_OR_REPORT")
	var goals := _goals(data.story_goals, data.events, values._result_frozen)
	if not goals.ok: return goals
	if not values._campaign_configured and (not goals.value.is_empty() or values.core_goal != ""): return _bad("CAMPAIGN_CONTRACT")
	if not _metrics(data.stage_metrics) or not _result(data.result_cache, values, goals.value): return _bad("METRICS_OR_RESULT")
	if data.actor != null and (not _id(data.actor) or not known_unit_ids.has(data.actor)): return _bad("ACTIVE_ACTOR_UNBOUND")
	if not _fields(data.nodes, NODE_FIELDS) or not _fields(data.scroll, ["horizontal", "vertical"]) or not _integer(data.scroll.horizontal, 0, 2147483647) or not _integer(data.scroll.vertical, 0, 2147483647): return _bad("PRESENTATION_FIELDS")
	for field: String in NODE_FIELDS:
		var resolved := _decode_node(data.nodes[field], field, external_tokens, field in ["_scroll", "_scroll_content"])
		if not resolved.ok: return resolved
	if (data.nodes._scroll == null) != (data.nodes._scroll_content == null): return _bad("SCROLL_ALIAS")
	if data.nodes._scroll != null and (data.nodes._scroll != data.nodes._detail_scroll or data.nodes._scroll_content != data.nodes._details): return _bad("SCROLL_ALIAS")
	if not _strings(data.button_order, true) or not _strings(data.marker_order, true): return _bad("EXTERNAL_ORDER")
	for token: String in data.button_order + data.marker_order:
		if not _token(token) or not external_tokens.has(token): return _bad("EXTERNAL_BINDING")
	if typeof(data.actions) != TYPE_ARRAY or data.actions.size() > LIMIT: return _bad("ACTIONS")
	var actions := {}; var markers: Array = []; var buttons := {}
	for row: Variant in data.actions:
		if typeof(row) != TYPE_DICTIONARY or not row.has_all(ACTION_FIELDS + ["id"]): return _bad("ACTION_FIELDS")
		for field: Variant in row:
			if field not in ACTION_FIELDS + OPTIONAL_ACTION_FIELDS + ["id"]: return _bad("UNKNOWN_ACTION_FIELD", str(field))
		if not _text(row.id, false) or actions.has(row.id) or not _text(row.label) or typeof(row.cell) != TYPE_VECTOR2I or not _strings(row.actors) or not _number(row.duration, 0.1) or not _number(row.reach, 24.0) or row.reach > 160.0 or not _number(row.click_reach, 24.0) or row.click_reach > 64.0 or typeof(row.show_button) != TYPE_BOOL or typeof(row.done) != TYPE_BOOL: return _bad("ACTION_VALUE")
		if row.has("blocked_reason") and not _text(row.blocked_reason): return _bad("BLOCKED_REASON")
		if row.has("settle_margin") and (not _number(row.settle_margin) or row.settle_margin > 16.0): return _bad("SETTLE_MARGIN")
		if (row.button != null) != row.show_button: return _bad("ACTION_BUTTON")
		for field: String in ["button", "marker", "actor_button"]:
			if not row.has(field): continue
			var resolved := _decode_node(row[field], field, external_tokens, field == "button")
			if not resolved.ok: return resolved
			if row[field] != null:
				if field == "marker":
					if markers.has(row[field]): return _bad("ACTION_MARKER_ALIAS")
					markers.append(row[field])
				else:
					if buttons.has(row[field]) or not data.button_order.has(row[field]): return _bad("ACTION_BUTTON_ALIAS")
					buttons[row[field]] = true
		actions[row.id] = row
	if markers != data.marker_order: return _bad("MARKER_ORDER")
	if values.active_action_id != "":
		if not actions.has(values.active_action_id) or data.actor == null: return _bad("ACTIVE_ACTION")
		var action: Dictionary = actions[values.active_action_id]
		if action.done or not String(action.get("blocked_reason", "")).is_empty() or values._progress >= action.duration: return _bad("ACTIVE_ACTION_PROGRESS")
	elif data.actor != null: return _bad("IDLE_ACTOR")
	if values.stage_id == "" and (not actions.is_empty() or not values._metrics_closed): return _bad("UNSTARTED_STAGE")
	var terminal: bool = values._result_frozen
	if values._metrics_closed and not data.stage_metrics.is_empty(): terminal = terminal or data.stage_metrics[-1].end_reason in ["victory", "defeat"]
	return {"ok": true, "value": data, "goals": goals.value, "actions": actions, "resume_eligible": not terminal, "complete_world": false}

func _button_connections(button: Button, mission: Variant, action_id := "") -> bool:
	var connections := button.get_signal_connection_list("pressed")
	if connections.size() != 1: return false
	var callback: Callable = connections[0].callable
	if not callback.is_valid() or callback.get_object() != mission: return false
	return action_id == "" or (callback.get_method() == &"focus_action" and callback.get_bound_arguments() == [action_id])

func restore_into(mission: Variant, owner: Node, record: Variant, context: Dictionary,
		id_to_unit: Dictionary, next_entity_id: int, token_to_external: Dictionary,
		restore_ticks_msec: int, presentation_restored: bool) -> Dictionary:
	if not is_instance_valid(mission) or mission.get_script() != Mission or mission.battle != owner or mission.has_meta(INSTALLED): return _bad("PRIVATE_MISSION_REQUIRED")
	if not _private(owner) or owner.get_parent() != null or not presentation_restored or not _integer(restore_ticks_msec): return _bad("PRIVATE_PRESENTATION_REQUIRED")
	# The trusted fixed UI factory may have added actions/locators, but must never
	# have started gameplay or configured/replayed the chapter contract.
	if mission.stage_id != "" or mission._generation != 0 or mission.elapsed != 0.0 or mission.total_game_seconds != 0.0 or not mission.events.is_empty() or not mission.story_goals.is_empty() or not mission.stage_metrics.is_empty() or mission._result_frozen or mission._campaign_configured: return _bad("FRESH_MISSION_REQUIRED")
	var registry := _registry(id_to_unit, next_entity_id, true)
	if not registry.ok: return registry
	var seen := {}
	for token: Variant in token_to_external:
		var node: Variant = token_to_external[token]
		if not _token(token) or not _private(node) or seen.has(node): return _bad("PRIVATE_EXTERNAL_REQUIRED")
		seen[node] = true
	var checked := validate(record, context, id_to_unit, next_entity_id, token_to_external)
	if not checked.ok: return checked
	var data: Dictionary = checked.value
	for field: String in NODE_FIELDS:
		var node: Variant = null if data.nodes[field] == null else token_to_external[data.nodes[field]]
		if not _node_kind(field, node): return _bad("EXTERNAL_TYPE", field)
		if field not in ["_scroll", "_scroll_content"] and mission.get(field) != node: return _bad("FOREIGN_MISSION_UI", field)
		if field != "_panel" and node != null and not mission._panel.is_ancestor_of(node): return _bad("PANEL_DESCENDANT", field)
	if not _private_branch(mission._panel) or mission._panel.get_parent() != owner.get("hud"): return _bad("PANEL_OWNERSHIP")
	var toggle_callback := Callable(mission, "_set_expanded")
	if mission._toggle.get_signal_connection_list("toggled").size() != 1 or not mission._toggle.toggled.is_connected(toggle_callback): return _bad("TOGGLE_BINDING")
	if not Localize.language_changed.is_connected(mission._on_language_changed): return _bad("LANGUAGE_BINDING")
	# Saved presentation tokens include the localization descriptor. The external
	# factory restores its text/format data; callable renderers must target this
	# new Mission, never a previous-world closure. No descriptor is evaluated here.
	for binding: Dictionary in Localize._bindings.values():
		var target: Variant = binding.target.get_ref()
		if target == null or not seen.has(target): continue
		if binding.has("render"):
			var renderer: Variant = binding.render
			if typeof(renderer) != TYPE_CALLABLE or not renderer.is_valid() or renderer.get_object() != mission: return _bad("LANGUAGE_RENDERER_OWNER")
	var button_nodes: Array = []
	for token: String in data.button_order:
		var button: Variant = token_to_external[token]
		if not _node_kind("button_order", button) or not _button_connections(button, mission): return _bad("BUTTON_CALLBACK")
		button_nodes.append(button)
	if mission._buttons.get_children() != button_nodes: return _bad("BUTTON_ORDER")
	var marker_nodes: Array = []
	for token: String in data.marker_order:
		var marker: Variant = token_to_external[token]
		if not _node_kind("marker_order", marker) or marker.get_parent() != owner.get("fx_root"): return _bad("MARKER_OWNERSHIP")
		marker_nodes.append(marker)
	if mission.actions.keys() != checked.actions.keys() or mission._markers != marker_nodes: return _bad("FACTORY_ACTIONS")
	var restored_actions := {}
	for id: String in checked.actions:
		var saved: Dictionary = checked.actions[id]
		if mission.actions[id].has("actor_button") != saved.has("actor_button"): return _bad("FACTORY_ACTOR_LOCATOR", id)
		var row: Dictionary = saved.duplicate(true); row.erase("id")
		for field: String in ["button", "marker", "actor_button"]:
			if row.has(field):
				row[field] = null if row[field] == null else token_to_external[row[field]]
				if mission.actions[id].get(field) != row[field]: return _bad("FACTORY_ACTION_BINDING", id + "/" + field)
		if row.button != null and not _button_connections(row.button, mission, id): return _bad("ACTION_CALLBACK", id)
		restored_actions[id] = row
	# All failure checks precede assignment. Only the private Mission is changed;
	# no UI setters that emit callbacks or consume player orders are invoked.
	for field: String in VALUE_FIELDS: mission.set(field, data.values[field])
	mission._stage_started_ms = restore_ticks_msec - int(data.values.stage_age_ms)
	mission.story_goals = checked.goals.duplicate(true)
	mission.events = {}
	for event_id: String in data.events: mission.events[event_id] = true
	mission.report.assign(data.report)
	mission.stage_metrics.assign(data.stage_metrics)
	mission._result_cache = data.result_cache.duplicate(true)
	mission.actions = restored_actions
	mission._actor = null if data.actor == null else id_to_unit[data.actor]
	mission._markers = marker_nodes
	mission._scroll = null if data.nodes._scroll == null else token_to_external[data.nodes._scroll]
	mission._scroll_content = null if data.nodes._scroll_content == null else token_to_external[data.nodes._scroll_content]
	mission.set_meta(INSTALLED, true)
	return {"ok": true, "mission": mission, "complete_world": false, "resume_eligible": checked.resume_eligible,
		"presentation_after_layout": {"expanded": data.values._expanded, "scroll_horizontal": data.scroll.horizontal, "scroll_vertical": data.scroll.vertical},
		"requires_external_same_frame_install": true, "events_replayed": 0, "begin_called": false}
