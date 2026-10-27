extends RefCounted
## Explicit value codec only. No Node reflection, object serialization or references.
## The caller owns the field schema, entity references, raw JSON parser and disk IO.
const MAX_DEPTH := 32 # Root depth is zero.
const MAX_NODES := 32768 # One/tag, plus one/packed-f32 element.
const MAX_BYTES := 1048576 # Conservative compact-JSON UTF-8 upper bound.
const TAG_BYTES := 96
const I64_MAX_TEXT := "9223372036854775807"
const I64_MIN_MAGNITUDE := "9223372036854775808"

func _context() -> Dictionary:
	return {"nodes":0,"bytes":0,"parents":[],"code":"","path":""}

func _fail(ctx: Dictionary, code: String, path: String) -> Variant:
	if ctx.code == "":
		ctx.code = code
		ctx.path = path
	return null

func _charge(ctx: Dictionary, nodes: int, bytes: int, path: String) -> bool:
	if nodes > MAX_NODES - ctx.nodes:
		_fail(ctx, "NODE_LIMIT", path)
		return false
	if bytes > MAX_BYTES - ctx.bytes:
		_fail(ctx, "BYTE_LIMIT", path)
		return false
	ctx.nodes += nodes
	ctx.bytes += bytes
	return true

func _enter(value: Variant, ctx: Dictionary, path: String) -> bool:
	for parent in ctx.parents:
		if is_same(parent, value):
			_fail(ctx, "CYCLE", path)
			return false
	ctx.parents.append(value)
	return true

func _finish(ctx: Dictionary, value: Variant) -> Dictionary:
	if ctx.code != "": return {"ok":false,"code":ctx.code,"path":ctx.path}
	return {"ok":true,"code":"OK","value":value,"nodes":ctx.nodes,"json_bytes_upper_bound":ctx.bytes}

func encode(value: Variant) -> Dictionary:
	var ctx: Dictionary = _context()
	var encoded: Variant = _encode(value, ctx, 0, "$")
	return _finish(ctx, encoded)

func decode(tagged: Variant) -> Dictionary:
	var ctx: Dictionary = _context()
	var decoded: Variant = _decode(tagged, ctx, 0, "$")
	return _finish(ctx, decoded)

func encode_infinity(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_FLOAT or not is_inf(value): return {"ok":false,"code":"INFINITY_REQUIRED"}
	return {"ok":true,"code":"OK","value":{"t":"inf_sentinel","v":"+" if value > 0.0 else "-"}}

func decode_infinity(tagged: Variant) -> Dictionary:
	if typeof(tagged) != TYPE_DICTIONARY or not _fields(tagged, ["t","v"]):
		return {"ok":false,"code":"SENTINEL_SHAPE"}
	if typeof(tagged.t) != TYPE_STRING or typeof(tagged.v) != TYPE_STRING or tagged.t != "inf_sentinel" or tagged.v not in ["+","-"]:
		return {"ok":false,"code":"SENTINEL_SHAPE"}
	return {"ok":true,"code":"OK","value":INF if tagged.v == "+" else -INF}

func _fields(value: Dictionary, names: Array) -> bool:
	if value.size() != names.size(): return false
	for key in value:
		if typeof(key) != TYPE_STRING or key not in names: return false
	return true

func _hex64(value: float) -> String:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_double(0, value)
	return raw.hex_encode()

func _hex32(value: float) -> String:
	var raw := PackedByteArray()
	raw.resize(4)
	raw.encode_float(0, value)
	return raw.hex_encode()

func _hex_valid(value: Variant, length: int) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != length: return false
	for index in range(length):
		var c: int = value.unicode_at(index)
		if not (c >= 48 and c <= 57) and not (c >= 97 and c <= 102): return false
	return true

func _float64(value: Variant, ctx: Dictionary, path: String) -> float:
	if not _hex_valid(value, 16):
		_fail(ctx, "FLOAT_BITS", path)
		return 0.0
	var raw: PackedByteArray = value.hex_decode()
	var number: float = raw.decode_double(0)
	if not is_finite(number): _fail(ctx, "NON_FINITE", path)
	return number

func _float32(value: Variant, ctx: Dictionary, path: String) -> float:
	if not _hex_valid(value, 8):
		_fail(ctx, "FLOAT_BITS", path)
		return 0.0
	var raw: PackedByteArray = value.hex_decode()
	var number: float = raw.decode_float(0)
	if not is_finite(number): _fail(ctx, "NON_FINITE", path)
	return number

func _int64(value: Variant, ctx: Dictionary, path: String) -> int:
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 20:
		_fail(ctx, "INT64_TEXT", path)
		return 0
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) or (negative and digits == "0"):
		_fail(ctx, "INT64_TEXT", path)
		return 0
	for index in range(digits.length()):
		var c: int = digits.unicode_at(index)
		if c < 48 or c > 57:
			_fail(ctx, "INT64_TEXT", path)
			return 0
	var limit: String = I64_MIN_MAGNITUDE if negative else I64_MAX_TEXT
	if digits.length() > 19 or (digits.length() == 19 and digits > limit):
		_fail(ctx, "INT64_RANGE", path)
		return 0
	# Accumulate negatively so MIN_INT64 never needs a positive intermediate.
	# No to_float(), JSON numeric parse, abs(MIN), or overflowing positive literal.
	var number: int = 0
	for index in range(digits.length()): number = number * 10 - (digits.unicode_at(index) - 48)
	return number if negative else -number

func _encode(value: Variant, ctx: Dictionary, depth: int, path: String) -> Variant:
	if depth > MAX_DEPTH: return _fail(ctx, "DEPTH_LIMIT", path)
	if not _charge(ctx, 1, TAG_BYTES, path): return null
	var container: bool = typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY]
	if container and not _enter(value, ctx, path): return null
	var result: Variant = _encode_body(value, ctx, depth, path)
	if container: ctx.parents.pop_back()
	return result

func _encode_body(value: Variant, ctx: Dictionary, depth: int, path: String) -> Variant:
	match typeof(value):
		TYPE_NIL: return {"t":"null"}
		TYPE_BOOL: return {"t":"bool","v":value}
		TYPE_STRING:
			# Six bytes/codepoint safely covers UTF-8 and JSON string escaping.
			if not _charge(ctx, 0, value.length() * 6, path): return null
			return {"t":"string","v":value}
		TYPE_INT: return {"t":"int64","v":str(value)}
		TYPE_FLOAT:
			if not is_finite(value): return _fail(ctx, "NON_FINITE", path)
			return {"t":"f64","v":_hex64(value)}
		TYPE_VECTOR2:
			if not value.is_finite(): return _fail(ctx, "NON_FINITE", path)
			return {"t":"vector2","v":[_hex64(value.x),_hex64(value.y)]}
		TYPE_VECTOR2I: return {"t":"vector2i","v":[str(value.x),str(value.y)]}
		TYPE_COLOR:
			for component in [value.r,value.g,value.b,value.a]:
				if not is_finite(component): return _fail(ctx, "NON_FINITE", path)
			return {"t":"color_f32","v":[_hex32(value.r),_hex32(value.g),_hex32(value.b),_hex32(value.a)]}
		TYPE_PACKED_FLOAT32_ARRAY:
			if not _charge(ctx, value.size(), value.size() * 8, path): return null
			var raw := PackedByteArray()
			raw.resize(value.size() * 4)
			for index in range(value.size()):
				if not is_finite(value[index]): return _fail(ctx, "NON_FINITE", path + "/" + str(index))
				raw.encode_float(index * 4, value[index])
			return {"t":"packed_f32","v":raw.hex_encode()}
		TYPE_ARRAY:
			if value.size() > MAX_NODES - ctx.nodes: return _fail(ctx, "NODE_LIMIT", path)
			var elements: Array = []
			for index in range(value.size()):
				var item: Variant = _encode(value[index], ctx, depth + 1, path + "/" + str(index))
				if ctx.code != "": return null
				elements.append(item)
			return {"t":"array","v":elements}
		TYPE_DICTIONARY:
			if value.size() * 2 > MAX_NODES - ctx.nodes: return _fail(ctx, "NODE_LIMIT", path)
			var entries: Array = []
			var index := 0
			for key in value:
				var encoded_key: Variant = _encode(key, ctx, depth + 1, path + "/key" + str(index))
				if ctx.code != "": return null
				var encoded_value: Variant = _encode(value[key], ctx, depth + 1, path + "/value" + str(index))
				if ctx.code != "": return null
				entries.append([encoded_key,encoded_value])
				index += 1
			return {"t":"dictionary","entries":entries}
		_: return _fail(ctx, "UNSUPPORTED_TYPE", path)

func _decode(tagged: Variant, ctx: Dictionary, depth: int, path: String) -> Variant:
	if depth > MAX_DEPTH: return _fail(ctx, "DEPTH_LIMIT", path)
	if not _charge(ctx, 1, TAG_BYTES, path): return null
	if typeof(tagged) != TYPE_DICTIONARY: return _fail(ctx, "TAG_SHAPE", path)
	if not _enter(tagged, ctx, path): return null
	var value: Variant = _decode_body(tagged, ctx, depth, path)
	ctx.parents.pop_back()
	return value

func _decode_body(tagged: Dictionary, ctx: Dictionary, depth: int, path: String) -> Variant:
	if tagged.size() < 1 or tagged.size() > 2 or not tagged.has("t") or typeof(tagged.t) != TYPE_STRING:
		return _fail(ctx, "TAG_SHAPE", path)
	var tag: String = tagged.t
	if tag not in ["null","bool","string","int64","f64","vector2","vector2i","color_f32","packed_f32","array","dictionary"]:
		return _fail(ctx, "UNKNOWN_TAG", path)
	var names: Array = ["t"] if tag == "null" else (["t","entries"] if tag == "dictionary" else ["t","v"])
	if not _fields(tagged, names): return _fail(ctx, "TAG_FIELDS", path)
	if tag == "null": return null
	var data: Variant = tagged.entries if tag == "dictionary" else tagged.v
	match tag:
		"bool":
			if typeof(data) != TYPE_BOOL: return _fail(ctx, "VALUE_TYPE", path)
			return data
		"string":
			if typeof(data) != TYPE_STRING: return _fail(ctx, "VALUE_TYPE", path)
			if not _charge(ctx, 0, data.length() * 6, path): return null
			return data
		"int64": return _int64(data, ctx, path)
		"f64": return _float64(data, ctx, path)
		"vector2", "vector2i", "color_f32":
			var count: int = 4 if tag == "color_f32" else 2
			if typeof(data) != TYPE_ARRAY or data.size() != count: return _fail(ctx, "VALUE_TYPE", path)
			if tag == "vector2i":
				var x: int = _int64(data[0], ctx, path + "/x")
				var y: int = _int64(data[1], ctx, path + "/y")
				if ctx.code != "": return null
				if x < -2147483648 or x > 2147483647 or y < -2147483648 or y > 2147483647: return _fail(ctx, "VECTOR2I_RANGE", path)
				return Vector2i(x,y)
			var components: Array = []
			for index in range(count):
				var number: float = _float32(data[index], ctx, path) if tag == "color_f32" else _float64(data[index], ctx, path)
				if ctx.code != "": return null
				components.append(number)
			if tag == "color_f32": return Color(components[0],components[1],components[2],components[3])
			var vector := Vector2(components[0],components[1])
			if not vector.is_finite() or _hex64(vector.x) != data[0] or _hex64(vector.y) != data[1]:
				return _fail(ctx, "VECTOR2_PRECISION", path)
			return vector
		"packed_f32":
			if typeof(data) != TYPE_STRING or data.length() % 8 != 0: return _fail(ctx, "FLOAT_BITS", path)
			@warning_ignore("integer_division")
			var count: int = data.length() / 8
			if not _charge(ctx, count, data.length(), path): return null
			if not _hex_valid(data, data.length()): return _fail(ctx, "FLOAT_BITS", path)
			var raw: PackedByteArray = data.hex_decode() if count > 0 else PackedByteArray()
			var packed := PackedFloat32Array()
			packed.resize(count)
			for index in range(count):
				var number: float = raw.decode_float(index * 4)
				if not is_finite(number): return _fail(ctx, "NON_FINITE", path + "/" + str(index))
				packed[index] = number
			return packed
		"array":
			if typeof(data) != TYPE_ARRAY: return _fail(ctx, "VALUE_TYPE", path)
			if data.size() > MAX_NODES - ctx.nodes: return _fail(ctx, "NODE_LIMIT", path)
			var result: Array = []
			for index in range(data.size()):
				var item: Variant = _decode(data[index], ctx, depth + 1, path + "/" + str(index))
				if ctx.code != "": return null
				result.append(item)
			return result
		"dictionary":
			if typeof(data) != TYPE_ARRAY: return _fail(ctx, "VALUE_TYPE", path)
			if data.size() * 2 > MAX_NODES - ctx.nodes: return _fail(ctx, "NODE_LIMIT", path)
			var result: Dictionary = {}
			for index in range(data.size()):
				var entry: Variant = data[index]
				if typeof(entry) != TYPE_ARRAY or entry.size() != 2: return _fail(ctx, "ENTRY_SHAPE", path)
				var key: Variant = _decode(entry[0], ctx, depth + 1, path + "/key" + str(index))
				if ctx.code != "": return null
				if result.has(key): return _fail(ctx, "DUPLICATE_KEY", path + "/key" + str(index))
				var value: Variant = _decode(entry[1], ctx, depth + 1, path + "/value" + str(index))
				if ctx.code != "": return null
				result[key] = value
			return result
	return _fail(ctx, "UNKNOWN_TAG", path)
