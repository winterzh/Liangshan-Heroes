extends RefCounted
## Rebuild the shipped FIGHT HUD from restored battle objects and explicit UI state.
const B := preload("res://scripts/battle.gd")
const H := preload("res://scripts/hud.gd")
const U := preload("res://scripts/unit.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Messages := preload("res://scripts/run_hud_messages_state.gd")
const SCHEMA := "fight_hud_v1"
const BOOLS := ["touch_ui", "_inventory_popup_open", "_autocam_on", "_legacy_show_control_help"]
var _codec: Variant = Codec.new()
var _owner: Variant = null
var _raw: Dictionary = {}
var _ids: Dictionary = {}
var _expired: Variant = null
var _messages: Variant = Messages.new()
var _message_record: Dictionary = {}
var _finished := false
var _activated := false
var _frame := -1

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fields(v: Variant, names: Array) -> bool:
	return typeof(v) == TYPE_DICTIONARY and v.size() == names.size() and v.has_all(names)

func _phase(v: Variant, maximum: float) -> bool:
	return typeof(v) == TYPE_FLOAT and is_finite(v) and v >= 0.0 and v < maximum

func _tag(unit: Variant, ids: Dictionary) -> Dictionary:
	if typeof(unit) == TYPE_NIL: return {"kind": "none"}
	if not is_instance_valid(unit): return {"kind": "expired"}
	if not ids.has(unit): return {"kind": "unknown"}
	return {"kind": "unit", "id": ids[unit]}

func _tag_valid(tag: Variant, ids: Dictionary) -> bool:
	if _fields(tag, ["kind"]): return tag.kind in ["none", "expired"]
	return _fields(tag, ["kind", "id"]) and tag.kind == "unit" and typeof(tag.id) == TYPE_STRING and ids.has(tag.id)

func validate(raw: Variant, ids: Dictionary) -> Dictionary:
	if not _fields(raw, ["schema", "values", "selected", "top", "pause", "canvas", "activation", "minimap", "inventory_clocks", "hero_clocks", "autocam_visible", "autocam_alpha"]) or raw.schema != SCHEMA: return _bad("HUD_RECORD")
	if not _fields(raw.values, BOOLS + ["_panel_accum", "_autocam_pulse"]): return _bad("HUD_VALUES")
	for key: String in BOOLS:
		if typeof(raw.values[key]) != TYPE_BOOL: return _bad("HUD_BOOL")
	if not _phase(raw.values._panel_accum, 0.25) or not _phase(raw.values._autocam_pulse, 1.0e30): return _bad("HUD_CLOCK")
	if typeof(raw.selected) != TYPE_ARRAY or raw.selected.size() > 4096: return _bad("HUD_SELECTION")
	for tag: Variant in raw.selected:
		if not _tag_valid(tag, ids): return _bad("HUD_SELECTION_ID")
	if typeof(raw.top) != TYPE_STRING or raw.top.length() > 4096: return _bad("HUD_TOP")
	if not _fields(raw.pause, ["visible", "pending"]) or typeof(raw.pause.visible) != TYPE_BOOL or raw.pause.pending not in ["", "restart", "menu", "quit"] or (not raw.pause.visible and raw.pause.pending != ""): return _bad("HUD_PAUSE")
	if typeof(raw.autocam_visible) != TYPE_BOOL or typeof(raw.autocam_alpha) != TYPE_FLOAT or not is_finite(raw.autocam_alpha) or raw.autocam_alpha < 0.0 or raw.autocam_alpha > 1.0: return _bad("HUD_AUTOCAM")
	var c: Variant = raw.canvas
	if not _fields(c, ["layer", "visible", "x", "y", "origin", "follow", "follow_scale"]): return _bad("HUD_CANVAS")
	if typeof(c.layer) != TYPE_INT or c.layer < -2147483648 or c.layer > 2147483647 or typeof(c.visible) != TYPE_BOOL or typeof(c.follow) != TYPE_BOOL or not _phase(c.follow_scale, 1.0e6): return _bad("HUD_CANVAS_VALUE")
	for key: String in ["x", "y", "origin"]:
		if typeof(c[key]) != TYPE_VECTOR2 or not c[key].is_finite(): return _bad("HUD_CANVAS_VECTOR")
	if absf(c.x.cross(c.y)) < 0.000001: return _bad("HUD_CANVAS_TRANSFORM")
	var a: Variant = raw.activation
	if not _fields(a, ["mode", "blocked", "priority", "physics_priority", "process", "physics", "input", "shortcut", "unhandled", "unhandled_key"]): return _bad("HUD_ACTIVATION")
	for key: String in ["mode", "priority", "physics_priority"]:
		if typeof(a[key]) != TYPE_INT or a[key] < -2147483648 or a[key] > 2147483647: return _bad("HUD_ACTIVATION_INT")
	if a.mode not in [0, 1, 2, 3, 4]: return _bad("HUD_ACTIVATION_MODE")
	for key: String in ["blocked", "process", "physics", "input", "shortcut", "unhandled", "unhandled_key"]:
		if typeof(a[key]) != TYPE_BOOL: return _bad("HUD_ACTIVATION_BOOL")
	if not _fields(raw.minimap, ["clock", "pixels"]) or not _phase(raw.minimap.clock, 0.1): return _bad("HUD_MINIMAP")
	var pixels: Variant = raw.minimap.pixels
	if typeof(pixels) != TYPE_DICTIONARY: return _bad("HUD_MINIMAP_PIXELS")
	if not pixels.is_empty():
		if not _fields(pixels, ["width", "height", "hex"]) or typeof(pixels.width) != TYPE_INT or typeof(pixels.height) != TYPE_INT or pixels.width <= 0 or pixels.height <= 0 or pixels.width > 512 or pixels.height > 512 or typeof(pixels.hex) != TYPE_STRING or pixels.hex.length() != pixels.width * pixels.height * 8: return _bad("HUD_MINIMAP_SIZE")
		for character: String in pixels.hex:
			if character not in "0123456789abcdef": return _bad("HUD_MINIMAP_HEX")
	if typeof(raw.inventory_clocks) != TYPE_ARRAY or raw.inventory_clocks.size() != 12: return _bad("HUD_INVENTORY_CLOCKS")
	for value: Variant in raw.inventory_clocks:
		if not _phase(value, 0.1): return _bad("HUD_INVENTORY_CLOCK")
	if typeof(raw.hero_clocks) != TYPE_ARRAY or raw.hero_clocks.size() > 4096: return _bad("HUD_HERO_CLOCKS")
	var seen: Dictionary = {}
	for row: Variant in raw.hero_clocks:
		if not _fields(row, ["id", "clock"]) or typeof(row.id) != TYPE_STRING or not ids.has(row.id) or seen.has(row.id) or not _phase(row.clock, 0.1): return _bad("HUD_HERO_CLOCK")
		seen[row.id] = true
	return {"ok": true}

func capture(owner: Variant, object_to_id: Dictionary) -> Dictionary:
	if not is_instance_valid(owner) or owner.get_script() != B or owner._save_barrier == null or owner._save_barrier.state != owner._save_barrier.State.HELD or owner.phase != B.Phase.FIGHT: return _bad("HUD_HELD_FIGHT_REQUIRED")
	var hud: Variant = owner.hud
	if not is_instance_valid(hud) or hud.get_script() != H or hud.battle != owner or hud.get_parent() != owner or not hud.is_node_ready() or hud.custom_viewport != null or hud.has_meta("_run_hud_prepared"): return _bad("HUD_SOURCE")
	if hud._intro_root.visible or hud._end_root.visible or hud.start_btn.visible or hud._tip_panel.visible or hud._tip_owner != null or hud.get_viewport().gui_is_dragging(): return _bad("HUD_TRANSIENT_NOT_RELEASED")
	var held: Dictionary = {}
	for row: Dictionary in owner._save_barrier._saved_ui:
		if row.node == hud: held = row
	if held.is_empty() or hud.process_mode != Node.PROCESS_MODE_DISABLED or not hud.is_blocking_signals(): return _bad("HUD_INPUT_GATE")
	var a := {"mode": held.mode, "blocked": held.blocked, "priority": hud.process_priority, "physics_priority": hud.process_physics_priority, "process": hud.is_processing(), "physics": hud.is_physics_processing(), "input": hud.is_processing_input(), "shortcut": hud.is_processing_shortcut_input(), "unhandled": hud.is_processing_unhandled_input(), "unhandled_key": hud.is_processing_unhandled_key_input()}
	var values: Dictionary = {}
	for key: String in BOOLS + ["_panel_accum", "_autocam_pulse"]: values[key] = hud.get(key)
	var selected: Array = []
	for unit: Variant in hud._sel_ref: selected.append(_tag(unit, object_to_id))
	var pixels: Dictionary = {}
	if hud.minimap._bg != null:
		var img: Image = hud.minimap._bg.get_image()
		if img == null or img.is_empty() or img.get_format() != Image.FORMAT_RGBA8 or img.has_mipmaps(): return _bad("HUD_MINIMAP_IMAGE")
		pixels = {"width": img.get_width(), "height": img.get_height(), "hex": img.get_data().hex_encode()}
	var clocks: Array = []
	for grid: Node in [hud._inventory_grid, hud._inventory_popup_grid]:
		for node: Variant in grid.get_children():
			if not node is H.InventorySlotButton or node._held or node._drag_started or node._tip_shown: return _bad("HUD_INVENTORY_GESTURE")
			clocks.append(node._draw_acc)
	var heroes: Array = []
	for chip: Variant in hud._hero_bar.get_children():
		if not chip is H.HeroChip or not is_instance_valid(chip.hero) or not object_to_id.has(chip.hero): return _bad("HUD_HERO_ID")
		heroes.append({"id": object_to_id[chip.hero], "clock": chip._redraw_accum})
	var t: Transform2D = hud.transform
	var raw := {"schema": SCHEMA, "values": values, "selected": selected, "top": hud.top_label.text, "pause": {"visible": hud._pause_root.visible, "pending": hud._pause_pending_action}, "canvas": {"layer": hud.layer, "visible": hud.visible, "x": t.x, "y": t.y, "origin": t.origin, "follow": hud.follow_viewport_enabled, "follow_scale": hud.follow_viewport_scale}, "activation": a, "minimap": {"clock": hud.minimap._accum, "pixels": pixels}, "inventory_clocks": clocks, "hero_clocks": heroes, "autocam_visible": hud._autocam_btn.visible, "autocam_alpha": float(hud._autocam_btn.modulate.a)}
	var known: Dictionary = {}
	for id: String in object_to_id.values(): known[id] = true
	var checked: Dictionary = validate(raw, known)
	if not checked.ok: return checked
	return _codec.encode(raw)

func bind(owner: Variant, record: Variant, messages: Variant, ids: Dictionary, expired: Variant) -> Dictionary:
	if _owner != null or not is_instance_valid(owner) or owner.get_script() != B or owner.is_inside_tree() or owner.hud != null: return _bad("HUD_BIND_PHASE")
	var decoded: Dictionary = _codec.decode(record)
	if not decoded.ok: return decoded
	var checked: Dictionary = validate(decoded.value, ids)
	if not checked.ok: return checked
	checked = _messages.decode(messages)
	if not checked.ok: return checked
	var hud := H.new()
	hud.visible = false; hud.process_mode = Node.PROCESS_MODE_DISABLED; hud.set_block_signals(true)
	hud.set_meta("_run_hud_prepared", true)
	owner.hud = hud; owner.add_child(hud)
	_owner = owner; _raw = decoded.value; _ids = ids.duplicate(); _expired = expired; _message_record = messages.duplicate(true)
	return {"ok": true}

func finish() -> Dictionary:
	if _finished or not is_instance_valid(_owner) or not _owner.is_inside_tree() or not _owner.get_tree().paused or _owner.process_mode != Node.PROCESS_MODE_DISABLED or _owner._run_clock == null or not _owner._prepared_clock_entry_valid(): return _bad("HUD_FINISH_PHASE")
	var hud: Variant = _owner.hud
	if not hud.is_node_ready() or not hud.get_meta("_run_hud_prepared", false): return _bad("HUD_NOT_PREPARED")
	var old_active: Variant = _owner._active
	hud.setup(_owner)
	hud.set_touch_ui(_raw.values.touch_ui)
	hud._legacy_show_control_help = _raw.values._legacy_show_control_help
	var selected: Array = []
	for tag: Dictionary in _raw.selected:
		selected.append(_ids[tag.id] if tag.kind == "unit" else (_expired if tag.kind == "expired" else null))
	hud._sel_ref = selected
	hud._rebuild_grid(); hud._rebuild_command_card(); hud._refresh_panel(); hud._refresh_hero_bar()
	if hud.touch_ui: hud._refresh_skill_rail()
	hud.refresh_inventory()
	hud._inventory_popup_open = _raw.values._inventory_popup_open
	hud._layout_inventory(); hud._refresh_resource_values()
	hud.set_top(_raw.top)
	hud._panel_accum = _raw.values._panel_accum
	hud.set_autocam_button(_raw.autocam_visible, _raw.values._autocam_on)
	hud._autocam_pulse = _raw.values._autocam_pulse; hud._autocam_btn.modulate.a = _raw.autocam_alpha
	hud.minimap._accum = _raw.minimap.clock
	var pixels: Dictionary = _raw.minimap.pixels
	if not pixels.is_empty():
		if pixels.width != _owner.map.w or pixels.height != _owner.map.h: return _bad("HUD_MINIMAP_MAP_MISMATCH")
		hud.minimap._bg = ImageTexture.create_from_image(Image.create_from_data(pixels.width, pixels.height, false, Image.FORMAT_RGBA8, pixels.hex.hex_decode()))
	var index := 0
	for grid: Node in [hud._inventory_grid, hud._inventory_popup_grid]:
		for node: Variant in grid.get_children(): node._draw_acc = _raw.inventory_clocks[index]; index += 1
	for chip: Variant in hud._hero_bar.get_children():
		for saved: Dictionary in _raw.hero_clocks:
			if _ids[saved.id] == chip.hero: chip._redraw_accum = saved.clock
	if _raw.pause.visible:
		hud.show_pause()
		if not _raw.pause.pending.is_empty(): hud._request_pause_action(_raw.pause.pending)
	else: hud.hide_pause()
	var c: Dictionary = _raw.canvas
	hud.layer = c.layer; hud.transform = Transform2D(c.x, c.y, c.origin)
	hud.follow_viewport_enabled = c.follow; hud.follow_viewport_scale = c.follow_scale
	# active_unit() is a presentation dependency with a lazy canonicalization.
	# Keep the captured root field until the first real gameplay/UI consumer.
	_owner._active = old_active
	var restored: Dictionary = _messages.restore(hud, _message_record)
	if not restored.ok: return restored
	hud._gate_run_prepared_ui()
	var plan: Dictionary = hud.get_meta("_run_hud_activation")
	# Message rows were born disabled by their own adapter, so their default
	# flags must be supplied explicitly to the combined HUD activation plan.
	for row: Variant in _messages._rows:
		for node: Node in [row, row.get_node("Text")]: plan[node] = {"mode": Node.PROCESS_MODE_INHERIT, "blocked": false}
	hud.set_meta("_run_hud_activation", plan)
	_finished = true; _frame = Engine.get_process_frames()
	return {"ok": true, "input_enabled": false}

func activate() -> Dictionary:
	if _activated or not _finished or not is_instance_valid(_owner) or not _owner.is_inside_tree() or not _owner.get_tree().paused or not _owner._prepared_clock_entry_valid() or _frame != Engine.get_process_frames(): return _bad("HUD_ACTIVATION_PHASE")
	var hud: Variant = _owner.hud
	if hud.visible or hud.process_mode != Node.PROCESS_MODE_DISABLED or not hud.is_blocking_signals() or not hud.get_meta("_run_hud_prepared", false): return _bad("HUD_GATE_CHANGED")
	var plan: Dictionary = hud.get_meta("_run_hud_activation")
	var stack: Array = [hud]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if not plan.has(node) or node.process_mode != Node.PROCESS_MODE_DISABLED or not node.is_blocking_signals(): return _bad("HUD_GATE_CHANGED")
		stack.append_array(node.get_children(true))
	var messages: Dictionary = _messages.activate_rows()
	if not messages.ok: return messages
	_owner._connect_hud_signals()
	hud._open_run_prepared_ui()
	var a: Dictionary = _raw.activation
	hud.process_priority = a.priority; hud.process_physics_priority = a.physics_priority
	hud.set_process(a.process); hud.set_physics_process(a.physics); hud.set_process_input(a.input)
	hud.set_process_shortcut_input(a.shortcut); hud.set_process_unhandled_input(a.unhandled); hud.set_process_unhandled_key_input(a.unhandled_key)
	hud.process_mode = a.mode; hud.set_block_signals(a.blocked); hud.visible = _raw.canvas.visible
	if _raw.pause.visible:
		if not _raw.pause.pending.is_empty(): hud._pause_cancel_button.grab_focus()
		else: hud._pause_resume_button.grab_focus()
	_activated = true
	return {"ok": true, "gameplay_activated": false}
