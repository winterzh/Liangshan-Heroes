extends RefCounted
## Original v27b data-only Variant and per-value ConfigFile semantics.
static func supported(value: Variant, depth := 0, ancestors: Array = []) -> bool:
	# Refuse unsupported identities/cycles/depth BEFORE writing or probing the
	# writer, whose fallback can otherwise emit ERROR/null and look canonical.
	if depth > 128: return false
	var kind := typeof(value)
	if kind not in [TYPE_DICTIONARY, TYPE_ARRAY]:
		# Fixed 4.6.3 data-Variant leaves. Identity-bearing or future enum kinds
		# never gain write permission through a catch-all default.
		return kind in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
			TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I,
			TYPE_TRANSFORM2D, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION,
			TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION, TYPE_COLOR,
			TYPE_STRING_NAME, TYPE_NODE_PATH, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY,
			TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
			TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY,
			TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]
	for previous in ancestors:
		if is_same(value, previous): return false
	var nested: Array = ancestors.duplicate()
	nested.append(value)
	if kind == TYPE_ARRAY:
		if value.get_typed_builtin() == TYPE_OBJECT or value.get_typed_script() != null: return false
		for item in value:
			if not supported(item, depth + 1, nested): return false
	else:
		if value.get_typed_key_builtin() == TYPE_OBJECT or value.get_typed_value_builtin() == TYPE_OBJECT: return false
		if value.get_typed_key_script() != null or value.get_typed_value_script() != null: return false
		for key in value:
			if not supported(key, depth + 1, nested) or not supported(value[key], depth + 1, nested): return false
	return true


static func semantics(cfg: ConfigFile) -> Dictionary:
	var sections: Dictionary = {}
	for section in cfg.get_sections():
		var keys: Dictionary = {}
		for key in cfg.get_section_keys(section):
			var value: Variant = cfg.get_value(section, key)
			if not supported(value): return {"ok":false,"code":"CAMPAIGN_CFG_UNSUPPORTED_VALUE"}
			# Fixed safe probe names avoid whole-file encode_to_text differences in
			# escaping legal unknown section names. No JSON or full IEEE comparison.
			var probe := ConfigFile.new()
			probe.set_value("value", "value", value)
			keys[key] = {"variant_type":typeof(value),"canonical":probe.encode_to_text()}
		sections[section] = keys
	return {"ok":true,"sections":sections}


