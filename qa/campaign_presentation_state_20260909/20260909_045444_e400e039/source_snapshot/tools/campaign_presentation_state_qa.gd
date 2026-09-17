extends Node
## Real Mission controls, MissionMarker, Localize and level3 evacuation callbacks.
## The Battle shell does not deploy a level or simulate an entire saved world.
const Presentation := preload("res://scripts/run_campaign_presentation_state.gd")
const MissionState := preload("res://scripts/run_campaign_mission_state.gd")
const Mission := preload("res://scripts/campaign_mission.gd")
const ZhuLevel := preload("res://scripts/levels/level3_zhujiazhuang_rts.gd")
const UnitScript := preload("res://scripts/unit.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const CONTEXT := {"level_id": "level3", "content_version": "fixture:presentation:v1", "mission_token": "mission:presentation:1", "presentation_token": "presentation:real-ui:1"}
const CAPTURE_MS := 100000
const RESTORE_MS := 1000
const STATUS_TEMPLATE := "%s正在前往%d号旗标；到场停留%s秒办理。"
const SOURCE_STATUS := "任务按钮只定位现场；请自行选人并右键目标标记。"
var state := MissionState.new()
var presentation := Presentation.new()
var codec := Codec.new()
var checks: Array = []
var fixtures: Array = []
var adapters: Array = []

class ConstantHeight extends RefCounted:
	func at(_point: Vector2) -> float: return 11.0

class FixtureHUD extends Control:
	func campaign_objective_position() -> Vector2: return Vector2(84, 78)

class FixtureBattle extends Node2D:
	enum Phase { FIGHT, END }
	var phase := Phase.FIGHT
	var hud := FixtureHUD.new()
	var fx_root := Node2D.new()
	var map := GameMap.new()
	var level: Variant = ZhuLevel.new()
	var mission: Variant = null
	var units: Array = []
	var selection: Array = []
	var _defs := {"shi_qian": {"name": "时迁"}, "shi_xiu": {"name": "石秀"}, "sun_li": {"name": "孙立"}, "song_jiang": {"name": "宋江"}}
	var messages: Array = []
	var camera_cells: Array = []
	var selections := 0
	func _init() -> void:
		add_child(hud); add_child(fx_root)
		map.height_field = ConstantHeight.new()
	func msg(text: String, _seconds := 0.0) -> void: messages.append(text)
	func center_camera_cell(cell: Vector2i) -> void: camera_cells.append(cell)
	func select_single(unit, _unused := false) -> void: selection = [unit]; selections += 1
	func select_members(members: Array, _unused := false) -> void: selection = members.duplicate(); selections += 1
	func find_unit(key: String) -> Variant:
		for unit: Variant in units:
			if unit.key == key: return unit
		return null

func _ready() -> void:
	var profile := OS.get_environment("LSH_PRESENTATION_STATE_PROFILE").replace("\\", "/").simplify_path()
	var safe := profile.is_absolute_path() and DirAccess.dir_exists_absolute(profile)
	for key: String in ["APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		var path := OS.get_environment(key).replace("\\", "/").simplify_path()
		safe = safe and path.to_lower() == (profile + "/" + key.to_lower()).to_lower()
	safe = safe and OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower().begins_with((profile + "/appdata/").to_lower())
	if not safe or OS.get_environment("STEAM_DISABLED") != "1" or OS.get_environment("CAMPAIGN_QA") != "1":
		print("CAMPAIGN_PRESENTATION_STATE_QA PRIVATE_PROFILE_REQUIRED"); get_tree().quit(2); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: print("PRESENTATION_CHECK_FAILED ", label)

func _unexpected_capture_signal() -> void:
	# A real connected handler whose behavior is outside the trusted factory.
	pass

func check_unknown_capture(source: Dictionary, label: String) -> void:
	var old_keys: Array = Localize._bindings.keys()
	var old_connections: int = Localize.language_changed.get_connections().size()
	var result: Dictionary = presentation.capture(source.mission, CONTEXT)
	check(label + " capture rejects unsupported behavior", not result.get("ok", false))
	check(label + " original binding keys unchanged", Localize._bindings.keys() == old_keys)
	check(label + " original language connections unchanged", Localize.language_changed.get_connections().size() == old_connections and Localize.language_changed.is_connected(source.mission._on_language_changed))

func exercise_unknown_capture(source: Dictionary) -> void:
	var status: Label = source.mission._status
	status.visibility_changed.connect(_unexpected_capture_signal)
	check_unknown_capture(source, "extra Label signal")
	status.visibility_changed.disconnect(_unexpected_capture_signal)
	check("Label signal removal restores normal capture", presentation.capture(source.mission, CONTEXT).get("ok", false))
	var marker: Node2D = source.mission.actions.zhu_rts_inside.marker
	marker.set_meta("qa_unregistered_behavior", "must never disappear silently")
	check_unknown_capture(source, "unknown marker metadata")
	marker.remove_meta("qa_unregistered_behavior")
	check("unknown metadata removal restores normal capture", presentation.capture(source.mission, CONTEXT).get("ok", false))
	var button: Button = source.mission.actions.zhu_rts_inside.button
	var had_color := button.has_theme_color_override("font_color")
	var previous_color := button.get_theme_color("font_color")
	button.add_theme_color_override("font_color", Color(0.1, 0.3, 0.8, 1.0))
	check_unknown_capture(source, "unsupported Button font color override")
	if had_color: button.add_theme_color_override("font_color", previous_color)
	else: button.remove_theme_color_override("font_color")
	check("font color restoration restores normal capture", presentation.capture(source.mission, CONTEXT).get("ok", false))
	var panel: PanelContainer = source.mission._panel
	var viewport_hook: Dictionary = {}
	for connection: Dictionary in panel.child_order_changed.get_connections():
		var callback: Callable = connection.callable
		if callback.get_object() == panel.get_viewport() and str(callback.get_method()) == "Viewport::canvas_parent_mark_dirty": viewport_hook = connection; break
	check("mounted source exposes the observed viewport canvas hook", not viewport_hook.is_empty())
	if not viewport_hook.is_empty():
		var original: Callable = viewport_hook.callable
		panel.child_order_changed.disconnect(original)
		panel.child_order_changed.connect(original, 0)
		check_unknown_capture(source, "viewport canvas hook with wrong flags")
		panel.child_order_changed.disconnect(original)
		var wrong_bound: Callable = original.bind(panel)
		panel.child_order_changed.connect(wrong_bound, int(viewport_hook.flags))
		check_unknown_capture(source, "viewport canvas hook with extra bound argument")
		panel.child_order_changed.disconnect(wrong_bound)
		panel.child_order_changed.connect(original, int(viewport_hook.flags))
		check("viewport canvas hook restoration restores normal capture", presentation.capture(source.mission, CONTEXT).get("ok", false))
	var internal_hints := 0
	for node: Node in source.mission._detail_scroll.get_children(true):
		if not node is TextureRect: continue
		internal_hints += 1
		var hint := node as TextureRect
		var old_texture := hint.texture
		hint.texture = GradientTexture2D.new()
		check_unknown_capture(source, "unregistered internal scroll hint texture " + str(internal_hints))
		hint.texture = old_texture
	check("native scroll factory has both internal hint controls", internal_hints == 2)
	check("internal hint restoration restores normal capture", presentation.capture(source.mission, CONTEXT).get("ok", false))

func gate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED; node.set_block_signals(true)
	for child: Node in node.get_children(true): gate(child)

func branch_gated(node: Node) -> bool:
	if node.process_mode != Node.PROCESS_MODE_DISABLED or not node.is_blocking_signals(): return false
	for child: Node in node.get_children(true):
		if not branch_gated(child): return false
	return true

func held_branch(node: Node, held: Array) -> void:
	held.append({"node": node, "mode": int(node.process_mode), "blocked": node.is_blocking_signals()})
	for child: Node in node.get_children(true): held_branch(child, held)

func unbind_branch(node: Node) -> void:
	for descriptor: Dictionary in Localize._bindings.values().duplicate():
		if descriptor.target.get_ref() == node: Localize.unbind(node, descriptor.property)
	for child: Node in node.get_children(true): unbind_branch(child)

func binding(node: Object, property := "text") -> Dictionary:
	for descriptor: Dictionary in Localize._bindings.values():
		if descriptor.target.get_ref() == node and String(descriptor.property) == property: return descriptor
	return {}

func make_owner() -> Dictionary:
	var owner := FixtureBattle.new()
	var ids := {}
	var keys := ["shi_qian", "shi_xiu", "sun_li", "song_jiang"]
	for index: int in keys.size():
		var unit := UnitScript.new()
		unit.entity_id = index + 1; unit.key = keys[index]; unit.display_name = owner._defs[keys[index]].name
		unit.faction = UnitScript.FACTION_LIANG; unit.hp = 80.0; unit.position = owner.map.cell_to_world(Vector2i(4 + index, 6))
		gate(unit); ids[str(unit.entity_id)] = unit; owner.units.append(unit)
	owner.level.prisoners.assign([ids["1"], ids["2"]])
	owner.level.sun = ids["3"]; owner.level.song = ids["4"]; owner.level.prisoners_freed = true
	gate(owner)
	var data := {"owner": owner, "ids": ids, "next_id": 5}
	fixtures.append(data)
	return data

func make_source() -> Dictionary:
	var data := make_owner()
	var owner: Variant = data.owner
	var mission := Mission.new(owner); owner.mission = mission
	# These methods set only the production Mission contract/presentation, never deploy.
	mission.configure_campaign(owner.level.campaign_core_goal(), owner.level.campaign_story_goals(), 2)
	mission.begin("zhu_rts", "第一打 · 扎营探路", "北取资源，南拔外营；兵营补兵、作坊造器械。先侦察，再决定主攻方向。")
	mission._stage_started_ms = CAPTURE_MS - 9000
	mission.enable_scrolling()
	mission.add_action("zhu_rts_inside", "接应内应，打开偏门", Vector2i(25, 18), ["sun_li"], 5.0, 64.0)
	mission.add_actor_locator("zhu_rts_inside", "sun_li")
	mission.add_map_locator("前营", ZhuLevel.CAMP)
	mission.add_action("zhu_rts_rescue", "救出被囚好汉", Vector2i(15, 35), ["song_jiang"], 3.0, 64.0)
	# Exercise the actual level method so an incompatible production callback fails.
	owner.level._add_evacuation_controls(owner)
	for index: int in [4, 5]:
		var rescue_button: Button = mission._buttons.get_child(index)
		check("real Zhu rescue control keeps touch size and font " + str(index), rescue_button.custom_minimum_size.y == 32 and rescue_button.has_theme_font_size_override("font_size") and rescue_button.get_theme_font_size("font_size") == 15)
	mission.add_action("caption_only", "守在原地", Vector2i(9, 10), [], 1.0, 96.0, 40.0, false)
	for index: int in 18:
		mission.add_map_locator("前营", Vector2i(30 + index, 20))
	mission.actions.zhu_rts_rescue.done = true
	mission.actions.zhu_rts_rescue.button.disabled = true
	mission.actions.zhu_rts_rescue.button.hide()
	mission.actions.zhu_rts_rescue.marker.hide()
	var first: Button = mission.actions.zhu_rts_inside.button
	first.custom_minimum_size = Vector2(204, 41)
	first.add_theme_font_size_override("font_size", 19)
	first.tooltip_text = "只定位地图；选人和移动仍由玩家指挥。"
	first.modulate = Color(0.85, 0.9, 0.95, 0.8)
	var marker: Node2D = mission.actions.zhu_rts_inside.marker
	marker.number = 17; marker.label = "孙立"; marker.show_caption = true
	marker.position += Vector2(2.0, -3.0); marker.rotation = 0.2; marker.scale = Vector2(1.1, 0.9)
	marker.z_index = 3451; marker.modulate = Color(0.7, 0.8, 0.9, 0.6)
	owner.map.sync_render_position(marker)
	Localize.bind_text(mission._objective, SOURCE_STATUS, &"tooltip_text", " [QA]")
	mission.set_feedback(Localize.format_text(STATUS_TEMPLATE, ["孙立", 17, "5"]), 1.75)
	# UI may be normal while the synthetic owner remains disabled. The captured
	# modes must not accidentally become the temporary gate installed by restore.
	add_child(owner)
	mission._panel.show(); mission._toggle.set_pressed_no_signal(true); mission._set_expanded(true)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	mission._detail_scroll.scroll_vertical = 170
	await get_tree().process_frame
	data["mission"] = mission
	return data

func view(mission: Variant) -> Dictionary:
	var hints: Array = []
	for node: Node in mission._detail_scroll.get_children(true):
		if node is TextureRect:
			hints.append({"texture_kind": presentation._texture_kind(node), "flip_h": node.flip_h,
				"flip_v": node.flip_v, "visible": node.visible, "modulate": node.modulate})
	var controls: Array = []
	for node: Node in mission._buttons.get_children():
		var button := node as Button
		controls.append({"text": button.text, "tooltip": button.tooltip_text, "disabled": button.disabled,
			"visible": button.visible, "minimum": button.custom_minimum_size, "autowrap": button.autowrap_mode,
			"font_size": button.get_theme_font_size("font_size"), "font_override": button.has_theme_font_size_override("font_size"),
			"modulate": button.modulate, "process_mode": int(button.process_mode), "blocked": button.is_blocking_signals()})
	var markers: Array = []
	for marker: Variant in mission._markers:
		markers.append({"number": marker.number, "label": marker.label, "caption": marker.show_caption,
			"visible": marker.visible, "transform": [marker.transform.x, marker.transform.y, marker.transform.origin], "z_index": marker.z_index,
			"modulate": marker.modulate, "render_height": float(marker.get_meta("render_height", 0.0))})
	return {"controls": controls, "markers": markers, "scroll_hints": hints, "panel_visible": mission._panel.visible,
		"panel_position": mission._panel.position, "panel_minimum": mission._panel.custom_minimum_size,
		"expanded": mission._expanded, "pressed": mission._toggle.button_pressed,
		"details_visible": mission._details.visible, "scroll_visible": mission._detail_scroll.visible,
		"scroll_x": mission._detail_scroll.scroll_horizontal, "scroll_y": mission._detail_scroll.scroll_vertical,
		"status": mission._status.text, "objective_tooltip": mission._objective.tooltip_text}

func print_native_hooks(mission: Variant) -> void:
	var registry: Dictionary = presentation._registry(mission)
	var rows: Dictionary = {}
	for node: Node in registry.external_to_token:
		for signal_info: Dictionary in node.get_signal_list():
			for connection: Dictionary in node.get_signal_connection_list(signal_info.name):
				var callback: Callable = connection.callable
				var target: Object = callback.get_object()
				if not target is Node or target.get_script() != null: continue
				var relation := "external"
				if target == node: relation = "self"
				elif target.get_parent() == node: relation = "direct_child"
				elif node.get_parent() == target: relation = "direct_parent"
				elif target.is_ancestor_of(node): relation = "ancestor"
				elif node.is_ancestor_of(target): relation = "descendant"
				var row := {"source_class": node.get_class(), "signal": str(signal_info.name), "target_class": target.get_class(),
					"method": str(callback.get_method()), "relation": relation, "flags": int(connection.flags),
					"bound_arguments": callback.get_bound_arguments(), "target_registered": registry.external_to_token.has(target)}
				rows[JSON.stringify(row)] = row
	print("PRESENTATION_NATIVE_HOOKS ", JSON.stringify(rows.values()))

func capture_source(source: Dictionary) -> Dictionary:
	var shown: Dictionary = presentation.capture(source.mission, CONTEXT)
	check("capture accepts actual ungated production controls", shown.get("ok", false))
	if not shown.get("ok", false): print(shown); return {}
	var captured := state.capture(source.mission, CONTEXT, source.ids, source.next_id, shown.external_to_token, CAPTURE_MS,
		{"deferred_drained": true, "presentation_captured": true})
	check("Mission component accepts real level3 presentation registry", captured.ok)
	if not captured.ok: print(captured); return {}
	check("source layout really has nonzero scroll", source.mission._detail_scroll.scroll_vertical == 170)
	check("capture preserves source bindings", binding(source.mission._status).has("args") and binding(source.mission._objective, "tooltip_text").get("suffix") == " [QA]")
	check("capture preserves real level and simulation state", source.owner.level.elapsed == 0.0 and source.owner.level.ai_trained == 0 and source.owner.selections == 0)
	var held: Array = []
	held_branch(source.mission._panel, held)
	for marker: Node in source.mission._markers: held_branch(marker, held)
	gate(source.mission._panel)
	for marker: Node in source.mission._markers: gate(marker)
	check("temporary barrier without original UI flags fails closed", not presentation.capture(source.mission, CONTEXT).get("ok", false))
	var barrier_capture: Dictionary = presentation.capture(source.mission, CONTEXT, held)
	check("barrier saved UI flags produce same presentation record", barrier_capture.get("ok", false) and barrier_capture.get("record") == shown.record)
	for row: Dictionary in held:
		row.node.process_mode = row.mode; row.node.set_block_signals(row.blocked)
	check("barrier capture leaves source button callbacks intact", not source.mission.actions.zhu_rts_inside.button.is_blocking_signals())
	var expected := codec.encode(view(source.mission))
	check("expected visual state encodes without object serialization", expected.ok)
	if not expected.ok: print(expected); return {}
	return {"presentation": shown.record, "mission": captured.record, "expected": expected.value}

func finish_mounted(adapter: Variant, owner: Node) -> Dictionary:
	get_tree().paused = true
	add_child(owner)
	var result: Dictionary = {"ok": false, "code": "NOT_CALLED"}
	for attempt: int in 12:
		await get_tree().process_frame
		result = adapter.finish_layout()
		if result.get("ok", false) or result.get("code") != "PRESENTATION_LAYOUT_PENDING": break
	return result

func verify_view(mission: Variant, expected: Dictionary, prefix: String, activated := false) -> void:
	var observed := view(mission)
	for field: String in ["panel_visible", "panel_position", "panel_minimum", "expanded", "pressed", "details_visible", "scroll_visible", "scroll_x", "scroll_y", "status", "objective_tooltip"]:
		check(prefix + " " + field, observed[field] == expected[field])
	check(prefix + " interleaved button count", observed.controls.size() == expected.controls.size())
	check(prefix + " actual marker count", observed.markers.size() == expected.markers.size())
	check(prefix + " native scroll hint textures and flip state", observed.scroll_hints == expected.scroll_hints)
	if observed.controls.size() == expected.controls.size():
		for index: int in observed.controls.size():
			var fields: Array = ["text", "tooltip", "disabled", "visible", "minimum", "autowrap", "font_size", "font_override", "modulate"]
			if activated: fields.append_array(["process_mode", "blocked"])
			var equal := true
			for field: String in fields: equal = equal and observed.controls[index][field] == expected.controls[index][field]
			check(prefix + " button visual and mode " + str(index), equal)
	if observed.markers.size() == expected.markers.size():
		for index: int in observed.markers.size():
			check(prefix + " marker geometry caption height " + str(index), observed.markers[index] == expected.markers[index])

func exercise_restore(bundle: Dictionary, prefix: String, source: Dictionary = {}) -> void:
	Localize.set_language("zh_CN", false)
	Localize._formatted_sources.clear()
	var target := make_owner()
	var factory := Presentation.new()
	var prepared: Dictionary = factory.prepare(target.owner, bundle.presentation, bundle.mission, CONTEXT, target.ids, target.next_id, RESTORE_MS)
	check(prefix + " detached trusted prepare", prepared.get("ok", false))
	if not prepared.get("ok", false): print(prepared); return
	var adapter: Variant = prepared.adapter; adapters.append(adapter)
	var mission: Variant = prepared.mission
	check(prefix + " fresh Mission assigned to new owner", target.owner.mission == mission and mission.battle == target.owner and mission != source.get("mission"))
	check(prefix + " detached UI and owner remain gated", not target.owner.is_inside_tree() and branch_gated(target.owner))
	check(prefix + " restore did not deploy or replay", target.owner.level.elapsed == 0.0 and target.owner.level.ai_trained == 0 and target.owner.messages.is_empty() and target.owner.selections == 0)
	check(prefix + " Mission contract state and timer restored", mission.stage_id == "zhu_rts" and mission.story_goals.size() == 3 and mission._stage_started_ms == -8000)
	check(prefix + " Localize format survives empty history", binding(mission._status).get("source") == STATUS_TEMPLATE and binding(mission._status).get("args") == ["孙立", 17, "5"])
	check(prefix + " source property suffix survives", binding(mission._objective, "tooltip_text").get("source") == SOURCE_STATUS and binding(mission._objective, "tooltip_text").get("suffix") == " [QA]")
	check(prefix + " actor renderer owns new Mission", binding(mission.actions.zhu_rts_inside.actor_button).get("render", Callable()).get_object() == mission)
	var before_ready: Dictionary = adapter.activate()
	check(prefix + " cannot activate before layout", not before_ready.get("ok", false))
	mission.actions.zhu_rts_inside.button.pressed.emit()
	check(prefix + " private blocked action callback cannot fire", target.owner.camera_cells.is_empty())
	var laid_out: Dictionary = await finish_mounted(adapter, target.owner)
	check(prefix + " mounted layout finishes", laid_out.get("ok", false))
	if not laid_out.get("ok", false): print(laid_out); adapter.dispose(); adapters.erase(adapter); return
	check(prefix + " mounted layout remains gated", branch_gated(target.owner))
	var expected: Dictionary = codec.decode(bundle.expected).value
	verify_view(mission, expected, prefix + " gated")
	var activated: Dictionary = adapter.activate()
	check(prefix + " activate only after layout", activated.get("ok", false))
	if not activated.get("ok", false): print(activated); adapter.dispose(); adapters.erase(adapter); return
	get_tree().paused = false
	verify_view(mission, expected, prefix + " active", true)
	check(prefix + " aliases point to new scroll widgets", mission._scroll == mission._detail_scroll and mission._scroll_content == mission._details)
	var map_button: Button = mission._buttons.get_child(2)
	# Exercise the restored descriptor before button clicks replace its status.
	for locale: String in ["en", "zh_TW", "ja", "zh_CN"]:
		Localize.set_language(locale, false)
		check(prefix + " restored format changes language " + locale, mission._status.text == Localize.format_text(STATUS_TEMPLATE, ["孙立", 17, "5"]))
		check(prefix + " restored source changes language " + locale, mission._objective.tooltip_text == Localize.text(SOURCE_STATUS) + " [QA]")
		check(prefix + " restored actor renderer changes language " + locale, mission.actions.zhu_rts_inside.actor_button.text == Localize.format_text("选中 · %s", Localize.text("孙立")))
		check(prefix + " restored map format changes language " + locale, map_button.text == Localize.format_text("查看 · %s", "前营"))
	check(prefix + " level buttons expose fixed real ids", prepared.level_buttons.has("zhu_select_shi_qian") and prepared.level_buttons.has("zhu_select_rescued"))
	if prepared.level_buttons.has("zhu_select_shi_qian") and prepared.level_buttons.has("zhu_select_rescued"):
		prepared.level_buttons.zhu_select_shi_qian.pressed.emit()
		check(prefix + " real level selects only new Shi Qian", target.owner.selection == [target.ids["1"]])
		prepared.level_buttons.zhu_select_rescued.pressed.emit()
		check(prefix + " real level selects new rescued members", target.owner.selection == [target.ids["1"], target.ids["2"]])
		target.ids["2"].is_captive = true
		prepared.level_buttons.zhu_select_rescued.pressed.emit()
		check(prefix + " rescue callback reads current captivity", target.owner.selection == [target.ids["1"]])
		target.ids["2"].is_captive = false
	mission.actions.zhu_rts_inside.button.pressed.emit()
	check(prefix + " action callback centers restored cell", target.owner.camera_cells.back() == Vector2i(25, 18))
	mission.actions.zhu_rts_inside.actor_button.pressed.emit()
	check(prefix + " actor locator selects new Sun Li", target.owner.selection == [target.ids["3"]])
	map_button.pressed.emit()
	check(prefix + " map locator retains closure cell", target.owner.camera_cells.back() == ZhuLevel.CAMP)
	check(prefix + " locator callbacks do not create player orders", target.ids["3"].mission_order_token == 0 and mission.active_action_id == "" and target.owner.level.elapsed == 0.0)
	if not source.is_empty(): check(prefix + " old world callbacks untouched", source.owner.camera_cells.is_empty() and source.owner.selections == 0)
	var status_key := "%d:text" % mission._status.get_instance_id()
	adapter.dispose(); adapters.erase(adapter)
	check(prefix + " dispose removes restored global bindings", not Localize._bindings.has(status_key))
	check(prefix + " dispose clears owner mission", not is_instance_valid(target.owner.mission))

func check_failed_prepare(bundle: Dictionary, source: Dictionary) -> void:
	# First distinguish a pure validation rejection from an actual partial factory
	# failure. The latter has valid types/tokens but an impossible structural path.
	var invalid_state: Dictionary = bundle.mission.duplicate(true)
	var state_payload: Dictionary = codec.decode(invalid_state.payload).value
	state_payload.values.stage_id = 23
	invalid_state.payload = codec.encode(state_payload).value
	var preflight_target := make_owner()
	var preflight_factory := Presentation.new()
	var preflight: Dictionary = preflight_factory.prepare(preflight_target.owner, bundle.presentation, invalid_state, CONTEXT, preflight_target.ids, preflight_target.next_id, RESTORE_MS)
	check("malformed Mission is rejected before allocation", not preflight.get("ok", false) and preflight_target.owner.mission == null and preflight_target.owner.hud.get_child_count() == 0)
	if preflight.get("ok", false): preflight.adapter.dispose()
	var malformed: Dictionary = bundle.presentation.duplicate(true)
	var payload: Dictionary = codec.decode(malformed.payload).value
	payload.controls[-1].path = [2048]
	malformed.payload = codec.encode(payload).value
	var target := make_owner()
	var old_keys: Array = Localize._bindings.keys()
	var old_connections: int = Localize.language_changed.get_connections().size()
	var failed_factory := Presentation.new()
	var rejected: Dictionary = failed_factory.prepare(target.owner, malformed, bundle.mission, CONTEXT, target.ids, target.next_id, RESTORE_MS)
	check("partial factory really reaches structural-path rejection", not rejected.get("ok", false) and rejected.get("code") == "PRESENTATION_GRAPH_PATH")
	if rejected.get("ok", false): rejected.adapter.dispose()
	check("failed prepare removes all provisional bindings", Localize._bindings.keys() == old_keys)
	check("failed prepare removes all provisional language callbacks", Localize.language_changed.get_connections().size() == old_connections)
	check("failed prepare leaves owner without Mission", target.owner.mission == null)
	check("failed prepare leaves no HUD or marker children", target.owner.hud.get_child_count() == 0 and target.owner.fx_root.get_child_count() == 0)
	check("failed prepare preserves old status binding", binding(source.mission._status).get("source") == STATUS_TEMPLATE)
	check("failed prepare preserves old Mission language callback", Localize.language_changed.is_connected(source.mission._on_language_changed))
	Localize.set_language("en", false)
	check("old world still localizes after failed restore", source.mission._status.text == Localize.format_text(STATUS_TEMPLATE, ["孙立", 17, "5"]))
	Localize.set_language("zh_CN", false)
	var mounted := make_owner(); add_child(mounted.owner)
	var mounted_factory := Presentation.new()
	var result: Dictionary = mounted_factory.prepare(mounted.owner, bundle.presentation, bundle.mission, CONTEXT, mounted.ids, mounted.next_id, RESTORE_MS)
	check("already mounted owner fails closed", not result.get("ok", false) and mounted.owner.mission == null)
	if result.get("ok", false): result.adapter.dispose()

func exercise_cross_locale(bundle: Dictionary) -> void:
	Localize.set_language("en", false)
	Localize._formatted_sources.clear()
	var target := make_owner()
	var factory := Presentation.new()
	var prepared: Dictionary = factory.prepare(target.owner, bundle.presentation, bundle.mission, CONTEXT, target.ids, target.next_id, RESTORE_MS)
	check("Chinese snapshot prepares under English locale", prepared.get("ok", false))
	if not prepared.get("ok", false): print(prepared); Localize.set_language("zh_CN", false); return
	var adapter: Variant = prepared.adapter; adapters.append(adapter)
	var mission: Variant = prepared.mission
	var result: Dictionary = await finish_mounted(adapter, target.owner)
	check("cross-language layout reaches a stable range", result.get("ok", false))
	if result.get("ok", false):
		check("cross-language panel uses English width", mission._panel.custom_minimum_size.x == 370.0)
		check("cross-language panel title uses saved source", mission._title.text == Localize.text("第一打 · 扎营探路"))
		check("cross-language status is restored from saved format", mission._status.text == Localize.format_text(STATUS_TEMPLATE, ["孙立", 17, "5"]))
		check("cross-language source suffix is intact", mission._objective.tooltip_text == Localize.text(SOURCE_STATUS) + " [QA]")
		check("cross-language actor render owns the new Mission", binding(mission.actions.zhu_rts_inside.actor_button).get("render", Callable()).get_object() == mission)
		check("cross-language scroll restored after English wrapping", mission._detail_scroll.scroll_vertical == 170)
		check("cross-language hidden completed button stays hidden", not mission.actions.zhu_rts_rescue.button.visible and mission.actions.zhu_rts_rescue.button.disabled)
		check("cross-language stage and event state do not advance", mission.stage_id == "zhu_rts" and mission.elapsed == 0.0 and target.owner.level.elapsed == 0.0 and target.owner.messages.is_empty())
		var activated: Dictionary = adapter.activate()
		check("cross-language layout can activate", activated.get("ok", false))
		if activated.get("ok", false) and prepared.level_buttons.has("zhu_select_shi_qian"):
			prepared.level_buttons.zhu_select_shi_qian.pressed.emit()
			check("cross-language real level callback selects new actor", target.owner.selection == [target.ids["1"]])
	adapter.dispose(); adapters.erase(adapter)
	get_tree().paused = false
	Localize.set_language("zh_CN", false)

func full_suite() -> void:
	Localize.set_language("zh_CN", false)
	var source: Dictionary = await make_source()
	print_native_hooks(source.mission)
	exercise_unknown_capture(source)
	var bundle := capture_source(source)
	if bundle.is_empty(): return
	var file := FileAccess.open(OS.get_environment("LSH_PRESENTATION_STATE_SNAPSHOT"), FileAccess.WRITE)
	check("restart bundle file created", file != null)
	if file == null: return
	file.store_string(JSON.stringify(bundle)); file.close()
	check("restart bundle contains only codec JSON", typeof(JSON.parse_string(JSON.stringify(bundle))) == TYPE_DICTIONARY)
	check_failed_prepare(bundle, source)
	await exercise_restore(bundle, "same process", source)
	await exercise_cross_locale(bundle)

func cleanup() -> void:
	get_tree().paused = false
	for adapter: Variant in adapters: adapter.dispose()
	adapters.clear()
	for data: Dictionary in fixtures:
		var owner: Variant = data.owner
		if not is_instance_valid(owner): continue
		var mission: Variant = owner.mission
		if is_instance_valid(mission) and Localize.language_changed.is_connected(mission._on_language_changed):
			Localize.language_changed.disconnect(mission._on_language_changed)
		unbind_branch(owner)
		var map_node: Node = owner.map
		owner.mission = null
		owner.free()
		for unit: Variant in data.ids.values():
			if is_instance_valid(unit): unit.free()
		if is_instance_valid(map_node): map_node.free()
	fixtures.clear()

func run() -> void:
	var phase := OS.get_environment("LSH_PRESENTATION_STATE_PHASE")
	if phase == "restart":
		var file := FileAccess.open(OS.get_environment("LSH_PRESENTATION_STATE_SNAPSHOT"), FileAccess.READ)
		check("fresh process bundle exists", file != null)
		if file != null:
			var bundle: Variant = JSON.parse_string(file.get_as_text()); file.close()
			check("fresh process bundle is JSON dictionary", typeof(bundle) == TYPE_DICTIONARY)
			if typeof(bundle) == TYPE_DICTIONARY: await exercise_restore(bundle, "fresh process")
	else: await full_suite()
	cleanup()
	var passed := checks.size() >= (60 if phase == "restart" else 80)
	for row: Dictionary in checks: passed = passed and row.passed
	var report := {"passed": passed, "component_only": true, "phase": phase, "checks": checks,
		"real_steam": false, "full_world": false, "real_mission_controls": true, "real_level3_callbacks": true}
	var path := OS.get_environment("LSH_PRESENTATION_STATE_REPORT")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: get_tree().quit(2); return
	file.store_string(JSON.stringify(report, "  ")); file.close()
	print("CAMPAIGN_PRESENTATION_STATE_QA ", JSON.stringify(report))
	get_tree().quit(0 if passed else 1)
