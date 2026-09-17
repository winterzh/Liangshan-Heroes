extends RefCounted
## Fixed Mission UI/marker factory. Records contain values and stable descriptors,
## never scripts, Callables, Resources, deployment instructions or reward actions.
const Mission := preload("res://scripts/campaign_mission.gd")
const State := preload("res://scripts/run_campaign_mission_state.gd")
const Codec := preload("res://scripts/run_state_value_codec.gd")
const SCHEMA := "campaign_presentation_v1"
const CONTROL := {"visible": TYPE_BOOL, "position": TYPE_VECTOR2, "size": TYPE_VECTOR2,
	"custom_minimum_size": TYPE_VECTOR2, "scale": TYPE_VECTOR2, "pivot_offset": TYPE_VECTOR2,
	"rotation": TYPE_FLOAT, "modulate": TYPE_COLOR, "self_modulate": TYPE_COLOR,
	"anchor_left": TYPE_FLOAT, "anchor_top": TYPE_FLOAT, "anchor_right": TYPE_FLOAT, "anchor_bottom": TYPE_FLOAT,
	"offset_left": TYPE_FLOAT, "offset_top": TYPE_FLOAT, "offset_right": TYPE_FLOAT, "offset_bottom": TYPE_FLOAT,
	"grow_horizontal": TYPE_INT, "grow_vertical": TYPE_INT,
	"z_index": TYPE_INT, "z_as_relative": TYPE_BOOL, "show_behind_parent": TYPE_BOOL,
	"mouse_filter": TYPE_INT, "mouse_force_pass_scroll_events": TYPE_BOOL,
	"focus_mode": TYPE_INT, "size_flags_horizontal": TYPE_INT, "size_flags_vertical": TYPE_INT,
	"size_flags_stretch_ratio": TYPE_FLOAT, "layout_direction": TYPE_INT,
	"clip_contents": TYPE_BOOL, "tooltip_text": TYPE_STRING}
const LABEL := {"text": TYPE_STRING, "autowrap_mode": TYPE_INT,
	"horizontal_alignment": TYPE_INT, "vertical_alignment": TYPE_INT}
const BUTTON := {"text": TYPE_STRING, "disabled": TYPE_BOOL, "toggle_mode": TYPE_BOOL,
	"button_pressed": TYPE_BOOL, "autowrap_mode": TYPE_INT, "alignment": TYPE_INT}
const SCROLL := {"horizontal_scroll_mode": TYPE_INT, "vertical_scroll_mode": TYPE_INT,
	"follow_focus": TYPE_BOOL, "scroll_deadzone": TYPE_INT}
const FLAGS := ["mode", "blocked", "process", "physics", "input", "shortcut", "unhandled", "unhandled_key", "priority", "physics_priority"]
const MARKER := {"label": TYPE_STRING, "number": TYPE_INT, "show_caption": TYPE_BOOL,
	"visible": TYPE_BOOL, "x": TYPE_VECTOR2, "y": TYPE_VECTOR2, "origin": TYPE_VECTOR2,
	"modulate": TYPE_COLOR, "self_modulate": TYPE_COLOR, "z_index": TYPE_INT,
	"z_as_relative": TYPE_BOOL, "show_behind_parent": TYPE_BOOL}
var _state: Variant = State.new()
var _codec: Variant = Codec.new()
var _owner: Variant = null
var mission: Variant = null
var token_to_external: Dictionary = {}
var level_buttons: Dictionary = {}
var activation_plan: Dictionary = {}
var _raw: Dictionary = {}
var _layout_done := false
var _active := false
var _used := false
var _mount_frame := -1
var _signal_issue := ""

class TemplateOwner extends RefCounted:
	var hud := Control.new()

func _bad(code: String, field := "") -> Dictionary:
	return {"ok": false, "code": code, "field": field, "complete_world": false}

func _fields(value: Variant, names: Array) -> bool:
	return _state._fields(value, names)

func _value(value: Variant, kind: int) -> bool:
	if typeof(value) != kind: return false
	if kind == TYPE_STRING: return value.length() <= 8192
	if kind == TYPE_FLOAT: return is_finite(value) and absf(value) <= 1.0e12
	if kind == TYPE_INT: return value >= -2147483648 and value <= 2147483647
	if kind == TYPE_VECTOR2: return value.is_finite() and value.abs().x <= 1.0e9 and value.abs().y <= 1.0e9
	if kind == TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	return true

func _props_valid(values: Variant, fields: Dictionary) -> bool:
	if not _fields(values, fields.keys()): return false
	for key: String in fields:
		if not _value(values[key], fields[key]): return false
	return true

func _control_ranges(values: Dictionary, kind: String) -> bool:
	if values.size.x < 0.0 or values.size.y < 0.0 or values.custom_minimum_size.x < 0.0 or values.custom_minimum_size.y < 0.0 or values.mouse_filter not in [0, 1, 2] or values.focus_mode not in [0, 1, 2]: return false
	if values.z_index < -4096 or values.z_index > 4096 or values.size_flags_stretch_ratio <= 0.0 or values.layout_direction not in [0, 1, 2, 3, 4] or values.grow_horizontal not in [0, 1, 2] or values.grow_vertical not in [0, 1, 2]: return false
	if values.size_flags_horizontal < 0 or values.size_flags_horizontal > 15 or values.size_flags_vertical < 0 or values.size_flags_vertical > 15: return false
	if kind in ["Button", "Label"] and values.autowrap_mode not in [0, 1, 2, 3]: return false
	if kind == "Label" and (values.horizontal_alignment not in [0, 1, 2, 3] or values.vertical_alignment not in [0, 1, 2, 3]): return false
	if kind == "Button" and (values.alignment not in [0, 1, 2, 3] or (values.button_pressed and not values.toggle_mode)): return false
	if kind == "ScrollContainer" and (values.horizontal_scroll_mode not in [0, 1, 2, 3, 4] or values.vertical_scroll_mode not in [0, 1, 2, 3, 4] or values.scroll_deadzone < 0): return false
	return true

func _flag_record(node: Node, held: Dictionary) -> Dictionary:
	return {"mode": held.get("mode", node.process_mode), "blocked": held.get("blocked", node.is_blocking_signals()),
		"process": node.is_processing(), "physics": node.is_physics_processing(), "input": node.is_processing_input(),
		"shortcut": node.is_processing_shortcut_input(), "unhandled": node.is_processing_unhandled_input(),
		"unhandled_key": node.is_processing_unhandled_key_input(), "priority": node.process_priority,
		"physics_priority": node.process_physics_priority}

func _flags_valid(row: Variant) -> bool:
	if not _fields(row, FLAGS) or typeof(row.mode) != TYPE_INT or row.mode not in [0, 1, 2, 3, 4]: return false
	for key: String in FLAGS:
		if not _value(row[key], TYPE_INT if key in ["mode", "priority", "physics_priority"] else TYPE_BOOL): return false
	return true

func _control_fields(kind: String) -> Dictionary:
	if kind not in ["PanelContainer", "VBoxContainer", "ScrollContainer", "Label", "Button", "HScrollBar", "VScrollBar"]: return {}
	var fields: Dictionary = CONTROL.duplicate()
	if kind == "Label": fields.merge(LABEL)
	elif kind == "Button": fields.merge(BUTTON)
	elif kind == "ScrollContainer": fields.merge(SCROLL)
	return fields

func _resource_equal(left: Variant, right: Variant, depth := 0) -> bool:
	if typeof(left) != typeof(right): return false
	if left == right: return true
	if not left is Resource or not right is Resource or depth >= 8 or left.get_class() != right.get_class(): return false
	var fields: Dictionary = {}
	for row: Dictionary in left.get_property_list():
		if int(row.usage) & PROPERTY_USAGE_STORAGE: fields[str(row.name)] = true
	for row: Dictionary in right.get_property_list():
		if int(row.usage) & PROPERTY_USAGE_STORAGE: fields[str(row.name)] = true
	for field: String in fields:
		if not _resource_equal(left.get(field), right.get(field), depth + 1): return false
	return true

func _fixed_properties(source: Node, prototype: Node, captured: Dictionary, marker := false) -> Dictionary:
	var fields: Dictionary = {}
	for row: Dictionary in source.get_property_list() + prototype.get_property_list():
		if int(row.usage) & PROPERTY_USAGE_STORAGE: fields[str(row.name)] = true
	for field: String in fields:
		if field.begins_with("metadata/") or field in ["owner", "process_mode", "process_priority", "process_physics_priority"]: continue
		if captured.has(field) or field == "theme_override_font_sizes/font_size": continue
		if marker and field in ["transform", "position", "rotation", "rotation_degrees", "scale", "skew"]: continue
		if source is ScrollBar and field in ["min_value", "max_value", "page", "value"]: continue # Container-owned bounds; exact scroll is restored after layout.
		if field == "name":
			var name_text := str(source.name)
			if source.name == prototype.name or name_text == source.get_class() or (name_text.begins_with("@" + source.get_class() + "@") and name_text.trim_prefix("@" + source.get_class() + "@").is_valid_int()): continue
		if not _resource_equal(source.get(field), prototype.get(field)): return _bad("PRESENTATION_UNSUPPORTED_PROPERTY", source.get_class() + "/" + field)
	return {"ok": true}

func _signals_valid(node: Node, source: Variant, prototype: Node, registry: Dictionary) -> bool:
	# Native container wiring is compared by signal, method and target ancestry.
	# Script callbacks are limited to the fixed Mission handlers and Localize's
	# one-shot cleanup hook; additional gameplay callbacks always fail closed.
	var native: Dictionary = {}
	for signal_info: Dictionary in prototype.get_signal_list():
		for row: Dictionary in prototype.get_signal_connection_list(signal_info.name):
			var callback: Callable = row.callable; var target: Object = callback.get_object()
			if target is Node and target.get_script() == null:
				native[str(signal_info.name) + ":" + str(callback.get_method()) + ":" + target.get_class()] = true
	for signal_info: Dictionary in node.get_signal_list():
		for row: Dictionary in node.get_signal_connection_list(signal_info.name):
			var callback: Callable = row.callable; var target: Object = callback.get_object()
			if not callback.is_valid(): return false
			var signal_name := str(signal_info.name)
			_signal_issue = "%s -> %s.%s flags=%s mission=%s localize=%s native=%s" % [signal_name, target.get_class() if target != null else "null", callback.get_method(), row.flags, target == source, target == Localize, native.keys()]
			if target == source:
				if signal_name == "pressed" and node.has_meta(Mission.PRESENTATION_META) and callback == _callback(node.get_meta(Mission.PRESENTATION_META), source): continue
				if node == source._toggle and signal_name == "toggled" and callback == Callable(source, "_set_expanded"): continue
				if node == source._panel and signal_name == "tree_exiting" and (int(row.flags) & CONNECT_ONE_SHOT) and str(callback.get_method()).contains("anonymous"): continue
				return false
			if target == Localize and signal_name == "tree_exiting" and (int(row.flags) & CONNECT_ONE_SHOT) and str(callback.get_method()).contains("anonymous"): continue
			# Observed Godot 4.6.3 mount hook: a parent Control's rectangle
			# updates its direct child's anchor-derived geometry. Detached
			# prototypes do not yet own this connection; exact graph ownership,
			# method, flags and zero bound args are mandatory.
			if signal_name == "item_rect_changed" and str(callback.get_method()) == "Control::_size_changed" and int(row.flags) == 0 and callback.get_bound_arguments().is_empty() and node is Control and target is Control and target.get_script() == null and target.get_parent() == node and registry.has(target): continue
			if target is Node and target.get_script() == null and registry.has(target) and target.is_ancestor_of(node) and native.has(signal_name + ":" + str(callback.get_method()) + ":" + target.get_class()): continue
			return false
	return true

func _audit_source(source: Variant, registry: Dictionary) -> Dictionary:
	var holder := TemplateOwner.new()
	var prototype: Variant = Mission.new(holder)
	for index: int in source._buttons.get_child_count(): prototype._buttons.add_child(Button.new())
	var template: Dictionary = _registry(prototype)
	var result: Dictionary = {"ok": true}
	for row: Dictionary in registry.rows:
		var node: Node = row.node; var token: String = registry.external_to_token[node]
		for key: StringName in node.get_meta_list():
			if key != Mission.PRESENTATION_META or not node is Button or node.get_parent() != source._buttons: result = _bad("PRESENTATION_UNKNOWN_METADATA", str(key)); break
		if not result.ok: break
		if not template.token_to_external.has(token): result = _bad("PRESENTATION_UNKNOWN_NODE", token); break
		var expected: Node = template.token_to_external[token]
		if node.get_class() != expected.get_class(): result = _bad("PRESENTATION_UNKNOWN_NODE_KIND", token); break
		result = _fixed_properties(node, expected, _control_fields(node.get_class()))
		if not result.ok: break
		if not _signals_valid(node, source, expected, registry.external_to_token): result = _bad("PRESENTATION_EXTRA_SIGNAL", token + " " + _signal_issue); break
	if result.ok:
		var marker_prototype: Node = Mission.MissionMarker.new()
		for marker: Node in source._markers:
			for key: StringName in marker.get_meta_list():
				if key not in [Mission.PRESENTATION_META, &"render_height"]: result = _bad("PRESENTATION_UNKNOWN_METADATA", str(key)); break
			if not result.ok: break
			result = _fixed_properties(marker, marker_prototype, MARKER, true)
			if not result.ok: break
			if not _signals_valid(marker, source, marker_prototype, registry.external_to_token): result = _bad("PRESENTATION_EXTRA_MARKER_SIGNAL"); break
		marker_prototype.free()
	if result.ok:
		for row: Dictionary in Localize.language_changed.get_connections():
			var callback: Callable = row.callable; var target: Object = callback.get_object()
			if target == source and callback != Callable(source, "_on_language_changed"):
				result = _bad("PRESENTATION_EXTRA_LANGUAGE_SIGNAL"); break
			if registry.external_to_token.has(target):
				if not target is Node or target.get_script() != Mission.MissionMarker or not str(callback.get_method()).contains("anonymous") or not callback.get_bound_arguments().is_empty():
					result = _bad("PRESENTATION_EXTRA_LANGUAGE_SIGNAL"); break
	# Detached prototypes never run gameplay, enter the scene tree, or own source
	# nodes. Their constructor's global language connection must still be retired.
	if Localize.language_changed.is_connected(prototype._on_language_changed): Localize.language_changed.disconnect(prototype._on_language_changed)
	holder.hud.free()
	return result

func _walk(node: Node, path: Array, rows: Array) -> void:
	rows.append({"node": node, "path": path.duplicate()})
	var index := 0
	for child: Node in node.get_children(true):
		var next: Array = path.duplicate(); next.append(index); index += 1
		_walk(child, next, rows)

func _registry(source: Variant) -> Dictionary:
	var rows: Array = []; _walk(source._panel, [], rows)
	var inverse: Dictionary = {}
	for row: Dictionary in rows:
		var parts: Array[String] = []
		for index: int in row.path: parts.append(str(index))
		inverse[row.node] = "ui:" + "/".join(parts)
	for field: String in State.NODE_FIELDS:
		if field in ["_scroll", "_scroll_content"]: continue
		inverse[source.get(field)] = "node:" + field
	var index := 0
	for node: Node in source._buttons.get_children(): inverse[node] = "button:" + str(index); index += 1
	index = 0
	for node: Node in source._markers: inverse[node] = "marker:" + str(index); index += 1
	var nodes: Dictionary = {}
	for node: Node in inverse: nodes[inverse[node]] = node
	return {"rows": rows, "external_to_token": inverse, "token_to_external": nodes}

func _descriptor_valid(value: Variant, context: Dictionary, marker := false) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not value.has("kind"): return false
	var kind: Variant = value.kind
	if kind == "marker": return marker and _fields(value, ["kind", "action_id"]) and _state._text(value.action_id, false)
	if marker: return false
	match kind:
		"action": return _fields(value, ["kind", "action_id"]) and _state._text(value.action_id, false)
		"map": return _fields(value, ["kind", "label", "cell"]) and _state._text(value.label) and typeof(value.cell) == TYPE_VECTOR2I
		"actor": return _fields(value, ["kind", "action_id", "actor_key"]) and _state._text(value.action_id, false) and _state._text(value.actor_key, false)
		"level": return _fields(value, ["kind", "button_id", "label", "tooltip"]) and value.button_id in Mission.LEVEL_BUTTON_IDS[context.level_id] and _state._text(value.label) and _state._text(value.tooltip)
	return false

func _callback(descriptor: Dictionary, target: Variant) -> Callable:
	match descriptor.kind:
		"action": return Callable(target, "focus_action").bind(descriptor.action_id)
		"map": return Callable(target, "_activate_map_locator").bind(descriptor.label, descriptor.cell)
		"actor": return Callable(target, "_activate_actor_locator").bind(descriptor.action_id, descriptor.actor_key)
		"level": return Callable(target, "_activate_level_button").bind(descriptor.button_id)
	return Callable()

func _binding_descriptor(binding: Dictionary, node: Node, source: Variant) -> Dictionary:
	if binding.has("render"):
		var descriptor: Variant = node.get_meta(Mission.PRESENTATION_META, {})
		if not _fields(descriptor, ["kind", "action_id", "actor_key"]) or descriptor.kind != "actor" or binding.property != &"text" or binding.render != Callable(source, "_actor_locator_text").bind(descriptor.actor_key): return _bad("UNTRUSTED_RENDER_BINDING")
		return {"ok": true, "value": {"kind": "actor_render", "actor_key": descriptor.actor_key}}
	var allowed: Array = ["target", "property", "source", "suffix", "args", "translate_arguments"]
	for key: Variant in binding:
		if key not in allowed: return _bad("UNKNOWN_LOCALIZATION_FIELD")
	if not binding.has("source"): return _bad("LOCALIZATION_SOURCE")
	var data := {"kind": "format" if binding.has("args") else "source", "source": binding.source, "suffix": binding.get("suffix", "")}
	if binding.has("args"):
		data["args"] = binding.args; data["translate_arguments"] = binding.get("translate_arguments", true)
	return {"ok": true, "value": data}

func _format_valid(source: String, args: Variant) -> bool:
	var values: Array = args if typeof(args) == TYPE_ARRAY else [args]
	for value: Variant in values:
		if typeof(value) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]: return false
	var index := 0; var count := 0
	while index < source.length():
		if source[index] != "%": index += 1; continue
		index += 1
		if index < source.length() and source[index] == "%": index += 1; continue
		while index < source.length() and source[index] in "-+ 0123456789.#": index += 1
		if index >= source.length() or source[index] not in "sdif" or count >= values.size(): return false
		if source[index] != "s" and typeof(values[count]) not in [TYPE_INT, TYPE_FLOAT]: return false
		count += 1; index += 1
	return count == values.size()

func _binding_valid(binding: Variant) -> bool:
	if typeof(binding) != TYPE_DICTIONARY or not binding.has("kind"): return false
	if binding.kind == "actor_render": return _fields(binding, ["kind", "actor_key"]) and _state._text(binding.actor_key, false)
	var fields: Array = ["kind", "source", "suffix"]
	if binding.kind == "format": fields.append_array(["args", "translate_arguments"])
	elif binding.kind != "source": return false
	if not _fields(binding, fields) or not _state._text(binding.source) or not _state._text(binding.suffix): return false
	if binding.kind == "format":
		return typeof(binding.translate_arguments) == TYPE_BOOL and _format_valid(binding.source, binding.args) and _format_valid(Localize.text(binding.source), binding.args)
	return true

func capture(source: Variant, context: Dictionary, held_ui: Array = []) -> Dictionary:
	if not _state._context(context) or not is_instance_valid(source) or source.get_script() != Mission: return _bad("PRESENTATION_SOURCE")
	var registry: Dictionary = _registry(source)
	var audited: Dictionary = _audit_source(source, registry)
	if not audited.ok: return audited
	var held: Dictionary = {}
	for row: Variant in held_ui:
		if not _fields(row, ["node", "mode", "blocked"]) or not is_instance_valid(row.node) or held.has(row.node): return _bad("PRESENTATION_HELD_FLAGS")
		held[row.node] = row
	var raw := {"locale": Localize.locale, "controls": [], "buttons": [], "markers": [], "bindings": [],
		"scroll": {"horizontal": source._detail_scroll.scroll_horizontal, "vertical": source._detail_scroll.scroll_vertical}}
	for row: Dictionary in registry.rows:
		if not row.node is Control or row.node.is_queued_for_deletion() or row.node.get_script() != null: return _bad("PRESENTATION_CONTROL")
		var node: Control = row.node
		var kind: String = node.get_class(); var fields: Dictionary = _control_fields(kind)
		if fields.is_empty(): return _bad("PRESENTATION_CONTROL_KIND", kind)
		if node.process_mode == Node.PROCESS_MODE_DISABLED and node.is_blocking_signals() and not held.has(node): return _bad("PRESENTATION_FLAGS_REQUIRED")
		var values: Dictionary = {}
		for field: String in fields: values[field] = node.get(field)
		var font: Variant = node.get_theme_font_size("font_size") if node.has_theme_font_size_override("font_size") else null
		raw.controls.append({"token": registry.external_to_token[node], "path": row.path, "kind": kind, "values": values,
			"font_size": font, "flags": _flag_record(node, held.get(node, {}))})
	for node: Node in source._buttons.get_children():
		var descriptor: Variant = node.get_meta(Mission.PRESENTATION_META, {})
		if not _descriptor_valid(descriptor, context) or node.get_signal_connection_list("pressed").size() != 1 or not node.pressed.is_connected(_callback(descriptor, source)): return _bad("UNREGISTERED_MISSION_BUTTON")
		raw.buttons.append({"token": registry.external_to_token[node], "descriptor": descriptor.duplicate(true)})
	for marker: Variant in source._markers:
		if not is_instance_valid(marker) or marker.is_queued_for_deletion() or marker.get_script() != Mission.MissionMarker: return _bad("PRESENTATION_MARKER")
		var descriptor: Variant = marker.get_meta(Mission.PRESENTATION_META, {})
		if not _descriptor_valid(descriptor, context, true): return _bad("UNREGISTERED_MISSION_MARKER")
		var values: Dictionary = {}
		for field: String in MARKER:
			values[field] = marker.transform.x if field == "x" else (marker.transform.y if field == "y" else (marker.transform.origin if field == "origin" else marker.get(field)))
		raw.markers.append({"token": registry.external_to_token[marker], "descriptor": descriptor.duplicate(true), "values": values,
			"render_height": marker.get_meta("render_height", null), "flags": _flag_record(marker, held.get(marker, {}))})
	for binding: Dictionary in Localize._bindings.values():
		var target: Variant = binding.target.get_ref()
		if target == null or not registry.external_to_token.has(target): continue
		if binding.property not in [&"text", &"tooltip_text"]: return _bad("UNSUPPORTED_LOCALIZATION_PROPERTY")
		var descriptor: Dictionary = _binding_descriptor(binding, target, source)
		if not descriptor.ok: return descriptor
		raw.bindings.append({"token": registry.external_to_token[target], "property": str(binding.property), "descriptor": descriptor.value})
	var packed: Dictionary = _codec.encode(raw)
	if not packed.ok: return packed
	var record := {"schema": SCHEMA, "context": context.duplicate(true), "payload": packed.value}
	var checked: Dictionary = validate(record, context)
	if not checked.ok: return checked
	return {"ok": true, "record": record, "external_to_token": registry.external_to_token, "token_to_external": registry.token_to_external, "complete_world": false}

func validate(record: Variant, context: Dictionary) -> Dictionary:
	if not _state._context(context) or not _fields(record, ["schema", "context", "payload"]) or record.schema != SCHEMA or record.context != context: return _bad("PRESENTATION_IDENTITY")
	var decoded: Dictionary = _codec.decode(record.payload)
	if not decoded.ok: return decoded
	var raw: Variant = decoded.value
	if not _fields(raw, ["locale", "controls", "buttons", "markers", "bindings", "scroll"]) or raw.locale not in Localize.LOCALES: return _bad("PRESENTATION_RECORD")
	for field: String in ["controls", "buttons", "markers", "bindings"]:
		if typeof(raw[field]) != TYPE_ARRAY or raw[field].size() > 2048: return _bad("PRESENTATION_LIMIT")
	if raw.controls.is_empty() or not _fields(raw.scroll, ["horizontal", "vertical"]) or not _state._integer(raw.scroll.horizontal, 0, 2147483647) or not _state._integer(raw.scroll.vertical, 0, 2147483647): return _bad("PRESENTATION_SCROLL")
	var tokens: Dictionary = {}; var paths: Dictionary = {}; var controls: Dictionary = {}
	for row: Variant in raw.controls:
		if not _fields(row, ["token", "path", "kind", "values", "font_size", "flags"]) or not _state._token(row.token) or tokens.has(row.token) or typeof(row.path) != TYPE_ARRAY or row.path.size() > 16 or typeof(row.kind) != TYPE_STRING: return _bad("PRESENTATION_CONTROL_RECORD")
		for index: Variant in row.path:
			if not _state._integer(index, 0, 2048): return _bad("PRESENTATION_NODE_PATH")
		var path: String = JSON.stringify(row.path)
		if paths.has(path): return _bad("PRESENTATION_DUPLICATE_PATH")
		paths[path] = true
		var fields: Dictionary = _control_fields(row.kind)
		if fields.is_empty() or not _props_valid(row.values, fields) or not _flags_valid(row.flags): return _bad("PRESENTATION_CONTROL_VALUE")
		if row.font_size != null and not _state._integer(row.font_size, 1, 512): return _bad("PRESENTATION_FONT")
		if not _control_ranges(row.values, row.kind): return _bad("PRESENTATION_CONTROL_RANGE")
		tokens[row.token] = true; controls[row.token] = row
	var button_tokens: Dictionary = {}; var level_ids: Dictionary = {}; var descriptors: Dictionary = {}
	for row: Variant in raw.buttons:
		if not _fields(row, ["token", "descriptor"]) or typeof(row.token) != TYPE_STRING or not controls.has(row.token) or controls[row.token].kind != "Button" or button_tokens.has(row.token) or not _descriptor_valid(row.descriptor, context): return _bad("PRESENTATION_BUTTON_RECORD")
		if row.descriptor.kind == "level":
			if level_ids.has(row.descriptor.button_id): return _bad("PRESENTATION_LEVEL_BUTTON_DUPLICATE")
			level_ids[row.descriptor.button_id] = true
		button_tokens[row.token] = true; descriptors[row.token] = row.descriptor
	for row: Variant in raw.markers:
		if not _fields(row, ["token", "descriptor", "values", "render_height", "flags"]) or not _state._token(row.token) or tokens.has(row.token) or not _descriptor_valid(row.descriptor, context, true) or not _props_valid(row.values, MARKER) or not _flags_valid(row.flags): return _bad("PRESENTATION_MARKER_RECORD")
		if row.values.number < 1 or row.values.z_index < -4096 or row.values.z_index > 4096 or absf(row.values.x.cross(row.values.y)) < 0.000001 or (row.render_height != null and not _value(row.render_height, TYPE_FLOAT)): return _bad("PRESENTATION_MARKER_VALUE")
		tokens[row.token] = true
	var bindings: Dictionary = {}
	for row: Variant in raw.bindings:
		if not _fields(row, ["token", "property", "descriptor"]) or typeof(row.token) != TYPE_STRING or not controls.has(row.token) or row.property not in ["text", "tooltip_text"] or (row.property == "text" and controls[row.token].kind not in ["Button", "Label"]) or not _binding_valid(row.descriptor): return _bad("PRESENTATION_BINDING")
		var key: String = row.token + ":" + row.property
		if bindings.has(key): return _bad("PRESENTATION_DUPLICATE_BINDING")
		bindings[key] = true
		if row.descriptor.kind == "actor_render" and (row.property != "text" or not descriptors.has(row.token) or descriptors[row.token].kind != "actor" or descriptors[row.token].actor_key != row.descriptor.actor_key): return _bad("PRESENTATION_RENDERER")
	return {"ok": true, "value": raw, "tokens": tokens, "complete_world": false}

func _gate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED; node.set_block_signals(true)
	for child: Node in node.get_children(true): _gate(child)

func _all_gated() -> bool:
	for node: Node in token_to_external.values():
		if not is_instance_valid(node) or node.is_queued_for_deletion() or node.process_mode != Node.PROCESS_MODE_DISABLED or not node.is_blocking_signals(): return false
	return true

func _remove_bindings(nodes: Dictionary) -> void:
	for key: Variant in Localize._bindings.keys():
		var row: Dictionary = Localize._bindings[key]
		var target: Variant = row.target.get_ref()
		if target != null and nodes.has(target): Localize.unbind(target, row.property)

func _abort(code: String, field := "") -> Dictionary:
	dispose()
	return _bad(code, field)

func prepare(owner: Node, presentation_record: Variant, mission_record: Variant, context: Dictionary,
		id_to_unit: Dictionary, next_entity_id: int, restore_ticks_msec: int) -> Dictionary:
	if _used or not _state._private(owner) or owner.get_parent() != null or owner.get("mission") != null: return _bad("PRESENTATION_PREPARE_PHASE")
	for field: String in ["hud", "fx_root", "map", "level"]:
		if not is_instance_valid(owner.get(field)): return _bad("PRESENTATION_OWNER_DEPENDENCY", field)
	if owner.get("hud").is_inside_tree() or owner.get("fx_root").is_inside_tree() or owner.get("level").id() != context.get("level_id"): return _bad("PRESENTATION_OWNER_IDENTITY")
	var checked: Dictionary = validate(presentation_record, context)
	if not checked.ok: return checked
	var state_data: Dictionary = _state.validate(mission_record, context, id_to_unit, next_entity_id, checked.tokens)
	if not state_data.ok: return state_data
	if state_data.value.scroll != checked.value.scroll: return _bad("PRESENTATION_SCROLL_PAIR")
	_used = true; _owner = owner; _raw = checked.value
	mission = Mission.new(owner)
	# Fixed shipped UI constructors only. In particular no Level method is invoked
	# here, no begin/configure/tick, and no request_action/finish/reward is called.
	for id: String in state_data.actions:
		var action: Dictionary = state_data.actions[id]
		mission.add_action(id, action.label, action.cell, action.actors, action.duration, action.reach, action.click_reach, action.show_button)
	var created: Dictionary = {}
	for row: Dictionary in _raw.buttons:
		var descriptor: Dictionary = row.descriptor; var button: Variant = null
		match descriptor.kind:
			"action":
				if not mission.actions.has(descriptor.action_id): return _abort("PRESENTATION_ACTION_BINDING")
				button = mission.actions[descriptor.action_id].button
			"map": button = mission.add_map_locator(descriptor.label, descriptor.cell)
			"actor":
				if not mission.actions.has(descriptor.action_id): return _abort("PRESENTATION_ACTOR_BINDING")
				mission.add_actor_locator(descriptor.action_id, descriptor.actor_key)
				button = mission.actions[descriptor.action_id].actor_button
			"level":
				if not owner.get("level").has_method("activate_mission_button"): return _abort("PRESENTATION_LEVEL_ADAPTER_REQUIRED")
				button = mission.add_level_button(descriptor.button_id, descriptor.label, descriptor.tooltip)
				level_buttons[descriptor.button_id] = button
		if not is_instance_valid(button) or created.has(button): return _abort("PRESENTATION_BUTTON_FACTORY")
		created[button] = true
		mission._buttons.move_child(button, created.size() - 1)
	if mission._buttons.get_child_count() != created.size(): return _abort("PRESENTATION_BUTTON_COUNT")
	var registry: Dictionary = _registry(mission); token_to_external = registry.token_to_external
	if registry.rows.size() != _raw.controls.size() or token_to_external.size() != checked.tokens.size(): return _abort("PRESENTATION_GRAPH_SIZE")
	for token: String in checked.tokens:
		if not token_to_external.has(token): return _abort("PRESENTATION_GRAPH_TOKEN", token)
	var paths: Dictionary = {}
	for row: Dictionary in registry.rows: paths[registry.external_to_token[row.node]] = row.path
	for row: Dictionary in _raw.controls:
		var node: Control = token_to_external[row.token]
		if node.get_class() != row.kind or paths[row.token] != row.path: return _abort("PRESENTATION_GRAPH_PATH", row.token)
		for field: String in row.values:
			if field == "button_pressed": (node as Button).set_pressed_no_signal(row.values[field])
			else: node.set(field, row.values[field])
		if row.font_size == null: node.remove_theme_font_size_override("font_size")
		else: node.add_theme_font_size_override("font_size", row.font_size)
		activation_plan[node] = row.flags.duplicate()
	for row: Dictionary in _raw.markers:
		var marker: Variant = token_to_external[row.token]
		if marker.get_meta(Mission.PRESENTATION_META) != row.descriptor: return _abort("PRESENTATION_MARKER_BINDING")
		for field: String in row.values:
			if field not in ["x", "y", "origin"]: marker.set(field, row.values[field])
		marker.transform = Transform2D(row.values.x, row.values.y, row.values.origin)
		if row.render_height == null:
			if marker.has_meta("render_height"): marker.remove_meta("render_height")
		else: marker.set_meta("render_height", row.render_height)
		owner.get("map").sync_render_position(marker)
		if absf(float(marker.get_meta("render_height", 0.0)) - float(row.render_height if row.render_height != null else 0.0)) > 0.00001: return _abort("PRESENTATION_MAP_HEIGHT_MISMATCH")
		activation_plan[marker] = row.flags.duplicate()
	_remove_bindings(registry.external_to_token)
	for row: Dictionary in _raw.bindings:
		var node: Node = token_to_external[row.token]; var descriptor: Dictionary = row.descriptor
		if descriptor.kind == "actor_render": Localize.bind_render(node, Callable(mission, "_actor_locator_text").bind(descriptor.actor_key), StringName(row.property))
		else:
			var binding: Dictionary = descriptor.duplicate(true); binding.erase("kind")
			Localize._bind(node, StringName(row.property), binding)
	_gate(mission._panel)
	for marker: Node in mission._markers: _gate(marker)
	var restored: Dictionary = _state.restore_into(mission, owner, mission_record, context, id_to_unit, next_entity_id, token_to_external, restore_ticks_msec, true)
	if not restored.ok: return _abort(restored.code, restored.get("field", ""))
	owner.set("mission", mission)
	return {"ok": true, "adapter": self, "mission": mission, "token_to_external": token_to_external,
		"level_buttons": level_buttons, "activation_plan": activation_plan, "resume_eligible": restored.resume_eligible,
		"complete_world": false, "begin_called": false, "events_replayed": 0}

func finish_layout() -> Dictionary:
	if _active or _layout_done or not is_instance_valid(_owner) or not _owner.is_inside_tree() or not _owner.get_tree().paused or not _all_gated(): return _bad("PRESENTATION_LAYOUT_PHASE")
	if _mount_frame < 0:
		_mount_frame = Engine.get_process_frames()
		if _raw.locale != Localize.locale: mission._on_language_changed(Localize.locale)
		else: mission._layout_details()
		for node: Node in token_to_external.values():
			if node is Container: node.queue_sort()
		return _bad("PRESENTATION_LAYOUT_PENDING")
	if Engine.get_process_frames() <= _mount_frame: return _bad("PRESENTATION_LAYOUT_PENDING")
	var scroll: ScrollContainer = mission._detail_scroll
	var horizontal: HScrollBar = scroll.get_h_scroll_bar(); var vertical: VScrollBar = scroll.get_v_scroll_bar()
	if float(_raw.scroll.horizontal) > maxf(horizontal.min_value, horizontal.max_value - horizontal.page) or float(_raw.scroll.vertical) > maxf(vertical.min_value, vertical.max_value - vertical.page): return _bad("PRESENTATION_LAYOUT_PENDING")
	scroll.scroll_horizontal = _raw.scroll.horizontal; scroll.scroll_vertical = _raw.scroll.vertical
	if scroll.scroll_horizontal != _raw.scroll.horizontal or scroll.scroll_vertical != _raw.scroll.vertical: return _bad("PRESENTATION_LAYOUT_PENDING")
	for marker: Node in mission._markers: _owner.get("map").sync_render_position(marker)
	_layout_done = true
	return {"ok": true, "input_enabled": false, "complete_world": false}

func activate() -> Dictionary:
	if _active or not _layout_done or not is_instance_valid(_owner) or not _owner.is_inside_tree() or not _owner.get_tree().paused or not _all_gated(): return _bad("PRESENTATION_ACTIVATION_PHASE")
	for node: Node in activation_plan:
		var flags: Dictionary = activation_plan[node]
		node.process_priority = flags.priority; node.process_physics_priority = flags.physics_priority
		node.set_process(flags.process); node.set_physics_process(flags.physics); node.set_process_input(flags.input)
		node.set_process_shortcut_input(flags.shortcut); node.set_process_unhandled_input(flags.unhandled); node.set_process_unhandled_key_input(flags.unhandled_key)
		node.process_mode = flags.mode; node.set_block_signals(flags.blocked)
	_active = true
	return {"ok": true, "complete_world": false, "gameplay_activated": false}

func dispose() -> void:
	if is_instance_valid(mission):
		if Localize.language_changed.is_connected(mission._on_language_changed): Localize.language_changed.disconnect(mission._on_language_changed)
		var nodes: Dictionary = {}
		if is_instance_valid(mission._panel):
			var rows: Array = []; _walk(mission._panel, [], rows)
			for row: Dictionary in rows: nodes[row.node] = true
		_remove_bindings(nodes)
		for marker: Variant in mission._markers:
			if is_instance_valid(marker): marker.free()
		if is_instance_valid(mission._panel): mission._panel.free()
		if is_instance_valid(_owner) and _owner.get("mission") == mission: _owner.set("mission", null)
	mission = null; _owner = null; token_to_external.clear(); level_buttons.clear(); activation_plan.clear()
