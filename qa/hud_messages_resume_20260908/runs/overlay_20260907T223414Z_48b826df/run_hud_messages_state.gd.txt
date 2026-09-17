extends RefCounted
## Message history and the shipped HUD's finite linear toast animation only.
## Full HUD construction, root binding and input activation belong to the caller.
const B := preload("res://scripts/battle.gd")
const H := preload("res://scripts/hud.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const SCHEMA := "hud_messages_v1"
const ROW_FIELDS := ["text", "count", "fade_in", "hold", "elapsed", "alpha"]
var _codec: Variant = Codec.new()
var _hud: Variant = null
var _rows: Array = []
var _activated := false

func _bad(code: String) -> Dictionary:
	return {"ok": false, "code": code}

func _fields(value: Variant, names: Array) -> bool:
	return typeof(value) == TYPE_DICTIONARY and value.size() == names.size() and value.has_all(names)

func _message(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty() and value.length() <= 4096

func _count(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0

func validate(raw: Variant) -> Dictionary:
	if not _fields(raw, ["schema", "log", "unread", "expanded", "scroll", "scroll_pending", "toasts"]) or raw.schema != SCHEMA: return _bad("HUD_MESSAGES_RECORD")
	if typeof(raw.log) != TYPE_ARRAY or raw.log.size() > H.INFO_LOG_CAP or typeof(raw.toasts) != TYPE_ARRAY or raw.toasts.size() > 3: return _bad("HUD_MESSAGES_LIMIT")
	if typeof(raw.unread) != TYPE_INT or raw.unread < 0 or raw.unread > H.INFO_LOG_CAP or typeof(raw.expanded) != TYPE_BOOL or typeof(raw.scroll_pending) != TYPE_BOOL: return _bad("HUD_MESSAGES_FLAGS")
	if typeof(raw.scroll) != TYPE_VECTOR2I or raw.scroll.x < 0 or raw.scroll.y < 0: return _bad("HUD_MESSAGES_SCROLL")
	if raw.expanded and (raw.unread != 0 or not raw.toasts.is_empty()): return _bad("HUD_MESSAGES_EXPANDED")
	for entry: Variant in raw.log:
		if not _fields(entry, ["text", "count"]) or not _message(entry.text) or not _count(entry.count): return _bad("HUD_MESSAGE_LOG_ENTRY")
	var unique: Dictionary = {}
	for row: Variant in raw.toasts:
		if not _fields(row, ROW_FIELDS) or not _message(row.text) or not _count(row.count) or typeof(row.fade_in) != TYPE_BOOL: return _bad("HUD_TOAST_ENTRY")
		if unique.has(row.text): return _bad("HUD_TOAST_DUPLICATE")
		unique[row.text] = true
		for key: String in ["hold", "elapsed", "alpha"]:
			if typeof(row[key]) != TYPE_FLOAT or not is_finite(row[key]): return _bad("HUD_TOAST_NUMBER")
		if row.hold not in ([1.60, 2.60] if row.fade_in else [1.75, 2.75]): return _bad("HUD_TOAST_DURATION")
		var fade: float = 0.15 if row.fade_in else 0.0
		var end: float = fade + row.hold + 0.25
		if row.elapsed < 0.0 or row.elapsed >= end or row.alpha < 0.0 or row.alpha > 1.0: return _bad("HUD_TOAST_PHASE")
		var alpha: float = 1.0
		if row.fade_in and row.elapsed < fade: alpha = row.elapsed / fade
		elif row.elapsed > fade + row.hold: alpha = (end - row.elapsed) / 0.25
		if absf(alpha - row.alpha) > 0.00001: return _bad("HUD_TOAST_ANIMATION_CHANGED")
	return {"ok": true}

func decode(record: Variant) -> Dictionary:
	var decoded: Dictionary = _codec.decode(record)
	if not decoded.ok: return decoded
	var checked: Dictionary = validate(decoded.value)
	return decoded if checked.ok else checked

func capture(owner: Variant) -> Dictionary:
	if not is_instance_valid(owner) or owner.get_script() != B or owner._save_barrier == null or owner._save_barrier.state != owner._save_barrier.State.HELD: return _bad("HUD_MESSAGES_HELD_REQUIRED")
	var hud: Variant = owner.hud
	if not is_instance_valid(hud) or hud.get_script() != H or hud.battle != owner or hud.get_parent() != owner or not hud.is_node_ready() or hud.process_mode != Node.PROCESS_MODE_DISABLED or not hud.is_blocking_signals(): return _bad("HUD_MESSAGES_SOURCE")
	# The original barrier must own every currently visible message row.
	var gated: Dictionary = {}
	for item: Dictionary in owner._save_barrier._saved_ui: gated[item.node] = true
	var rows: Array = []
	for row: Node in hud.msg_box.get_children():
		if not row is PanelContainer or row.get_script() != null or row.is_queued_for_deletion() or not gated.has(row) or row.process_mode != Node.PROCESS_MODE_DISABLED or not row.is_blocking_signals() or row.get_child_count() != 1: return _bad("HUD_TOAST_NODE")
		var label: Variant = row.get_node_or_null("Text")
		if not label is Label or label.get_script() != null: return _bad("HUD_TOAST_LABEL")
		var keys: Array = row.get_meta_list()
		if keys.size() != 5: return _bad("HUD_TOAST_METADATA")
		for key: String in ["info_text", "info_count", "toast_tween", "toast_fade_in", "toast_hold"]:
			if not row.has_meta(key): return _bad("HUD_TOAST_METADATA")
		var tween: Variant = row.get_meta("toast_tween")
		if not tween is Tween or not tween.is_valid() or not tween.is_running() or tween.get_loops_left() != 1: return _bad("HUD_TOAST_TWEEN")
		var text: Variant = row.get_meta("info_text")
		var count: Variant = row.get_meta("info_count")
		if not _message(text) or not _count(count) or label.text != ("%s  ×%d" % [text, count] if count > 1 else text): return _bad("HUD_TOAST_TEXT")
		rows.append({"text": text, "count": count, "fade_in": row.get_meta("toast_fade_in"), "hold": row.get_meta("toast_hold"), "elapsed": tween.get_total_elapsed_time(), "alpha": float(row.modulate.a)})
	var scroll: Vector2i = hud._info_scroll_restore if hud._info_scroll_restore.x >= 0 else Vector2i(hud._info_scroll.scroll_horizontal, hud._info_scroll.scroll_vertical)
	var raw := {"schema": SCHEMA, "log": hud._message_log.duplicate(true), "unread": hud._info_unread, "expanded": hud._info_expanded, "scroll": scroll, "scroll_pending": hud._info_scroll_pending, "toasts": rows}
	var checked: Dictionary = validate(raw)
	if not checked.ok: return checked
	return _codec.encode(raw)

func restore(hud: Variant, record: Variant) -> Dictionary:
	# Build the complete normal widget tree first, while the installation is
	# paused. This adapter never enables HUD input or attaches another Battle.
	if _hud != null or not is_instance_valid(hud) or hud.get_script() != H or not hud.is_node_ready() or not hud.is_inside_tree() or not hud.get_tree().paused or hud.process_mode != Node.PROCESS_MODE_DISABLED or not hud.is_blocking_signals(): return _bad("HUD_MESSAGES_RESTORE_PHASE")
	if not hud._message_log.is_empty() or hud.msg_box.get_child_count() != 0: return _bad("HUD_MESSAGES_FRESH_TARGET_REQUIRED")
	var decoded: Dictionary = decode(record)
	if not decoded.ok: return decoded
	var raw: Dictionary = decoded.value
	# No messages are re-emitted: duplicate counts and unread values are stored
	# state, and opening a restored log must not mark it read a second time.
	hud._message_log = raw.log.duplicate(true)
	hud._info_unread = raw.unread
	hud._info_expanded = raw.expanded
	hud._info_panel.visible = raw.expanded
	hud._info_scroll_pending = raw.scroll_pending
	hud._info_scroll_restore = raw.scroll
	hud._refresh_info_log(); hud._update_info_toggle()
	hud._layout_info_panel()
	for saved: Dictionary in raw.toasts:
		var row: Variant = hud._make_info_toast(saved.text, saved.count)
		row.process_mode = Node.PROCESS_MODE_DISABLED; row.set_block_signals(true)
		var label: Variant = row.get_node("Text")
		label.process_mode = Node.PROCESS_MODE_DISABLED; label.set_block_signals(true)
		hud._arm_info_toast(row, saved.fade_in, saved.hold)
		# Recreate the trusted finite Tween and seek its native timeline. The
		# record cannot supply a Callable, resource, easing function or duration.
		var tween: Tween = row.get_meta("toast_tween")
		tween.custom_step(saved.elapsed)
		row.modulate.a = saved.alpha
		_rows.append(row)
	hud.msg_box.visible = not raw.expanded and not raw.toasts.is_empty()
	hud._info_scroll.scroll_horizontal = raw.scroll.x
	hud._info_scroll.scroll_vertical = raw.scroll.y
	_hud = hud
	return {"ok": true, "hud_input_enabled": false, "complete_hud": false}

func activate_rows() -> Dictionary:
	if _activated or not is_instance_valid(_hud) or not _hud.is_inside_tree() or not _hud.get_tree().paused or _hud.process_mode != Node.PROCESS_MODE_DISABLED or not _hud.is_blocking_signals(): return _bad("HUD_MESSAGES_ACTIVATION_PHASE")
	if _hud.msg_box.get_children() != _rows: return _bad("HUD_MESSAGES_ROWS_CHANGED")
	for row: Variant in _rows:
		if not is_instance_valid(row) or row.is_queued_for_deletion() or row.process_mode != Node.PROCESS_MODE_DISABLED or not row.is_blocking_signals(): return _bad("HUD_MESSAGES_ROWS_CHANGED")
		var label: Variant = row.get_node_or_null("Text")
		if row.get_child_count() != 1 or not label is Label or label.is_queued_for_deletion() or label.process_mode != Node.PROCESS_MODE_DISABLED or not label.is_blocking_signals(): return _bad("HUD_MESSAGES_ROWS_CHANGED")
	for row: Variant in _rows:
		for node: Node in [row, row.get_node("Text")]:
			node.process_mode = Node.PROCESS_MODE_INHERIT; node.set_block_signals(false)
	_activated = true
	return {"ok": true, "hud_input_enabled": false}
