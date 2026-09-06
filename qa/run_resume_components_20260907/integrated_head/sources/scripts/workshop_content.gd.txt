class_name WorkshopContent
extends RefCounted
## Data-only boundary used before BOTH publishing and playing downloaded content.
const FORMAT_VERSION := 1
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_PREVIEW_BYTES := 999999
const TERRAIN := ["WATER", "SHORE", "MARSH", "REEDS", "GRASS", "ROAD", "FOREST", "HALL", "DRYHILL", "CLIFF", "TOWN", "PLAZA", "FIELD", "PLAIN", "DOCK"]
const DECOR := ["tower", "banner", "tent", "boat", "bridge", "rocks", "pine", "town_house", "scaffold", "treasure_cart", "gold_mine", "palisade"]
const TOP_SCENARIO := ["id", "title", "subtitle", "map", "camera_start", "deploy_hint", "economy", "start_gold", "start_wood", "pop_cap", "hero_cap", "fog", "start_age", "intro", "terrain", "decor", "deploy", "gates", "target", "wave_faction", "wave_gap", "wave_mode", "waves", "start_msg", "wave_gap_msg", "win", "lose", "win_msg", "lose_msg", "top_status", "units", "abilities", "sprite_alias"]
const TOP_DEFENSE := ["name", "units", "abilities", "waves", "start_gold", "start_wood", "pop_cap", "hero_cap"]

static func encode_payload(value: Variant) -> Variant:
	if value is Color: return value.to_html()
	if value is Dictionary:
		var out := {}
		for key in value: out[key] = encode_payload(value[key])
		return out
	if value is Array:
		var out := []
		for v in value: out.append(encode_payload(v))
		return out
	return value

static func runtime_payload(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	for group in ["units", "abilities"]:
		if not result.get(group, {}) is Dictionary: continue
		var reference: Dictionary = Defs.UNITS if group == "units" else Defs.ABILITIES
		var examples := {}
		for entry in reference.values():
			for field in entry:
				if entry[field] is Color: examples[field] = true
		for key in result.get(group, {}):
			if not result[group][key] is Dictionary: continue
			for field in examples:
				if result[group][key].has(field): result[group][key][field] = _restore_color(result[group][key][field])
			if group == "abilities" and result[group][key].get("effect") is Dictionary:
				var colors := {}
				for entry in reference.values():
					for field in entry.get("effect", {}):
						if entry.effect[field] is Color: colors[field] = true
				for field in colors:
					if result[group][key].effect.has(field): result[group][key].effect[field] = _restore_color(result[group][key].effect[field])
	return result

static func _restore_color(value: Variant) -> Variant:
	if not value is String: return value
	if Color.html_is_valid(value): return Color(value)
	# Existing editor JSON stored Color as '(r, g, b, a)'. Parse only four numbers.
	if value.begins_with("(") and value.ends_with(")"):
		var parts: PackedStringArray = value.substr(1, value.length()-2).split(",")
		if parts.size() == 4:
			var values: Array[float] = []
			for part in parts:
				if not part.strip_edges().is_valid_float(): return value
				var n := float(part)
				if not is_finite(n) or n < 0 or n > 1: return value
				values.append(n)
			return Color(values[0], values[1], values[2], values[3])
	return value
var error := ""
var _budget := 0
var _width := 48
var _height := 48
var _units := {}
var _abilities := {}
var _refs := {}
var _gates := {}

static func read_package(folder: String) -> Dictionary:
	var dir := DirAccess.open(folder)
	if dir == null:
		return {"ok":false, "error":"作品尚未安装"}
	dir.include_hidden = true
	for name in dir.get_files():
		if name not in ["manifest.json", "content.json", "preview.jpg"] or dir.is_link(name):
			return {"ok":false, "error":"作品包含不支持的文件"}
	if not dir.get_directories().is_empty():
		return {"ok":false, "error":"作品包含不支持的子目录"}
	var manifest: Variant = _read_json(folder.path_join("manifest.json"), 4096)
	if not manifest is Dictionary or manifest.get("format_version") != FORMAT_VERSION or manifest.get("kind") not in ["scenario", "custom_defense"]:
		return {"ok":false, "error":"不支持的作品格式版本或类型"}
	var data: Variant = _read_json(folder.path_join("content.json"), MAX_JSON_BYTES)
	var validator := WorkshopContent.new()
	if not validator.validate(String(manifest.kind), data):
		return {"ok":false, "error":validator.error}
	return {"ok":true, "kind":manifest.kind, "data":data, "title":String(data.get("title", data.get("name", "工坊作品")))}

static func _read_json(path: String, limit: int) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > limit:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data

func validate(kind: String, data: Variant) -> bool:
	error = ""
	_budget = 0
	_refs = {}
	if kind not in ["scenario", "custom_defense"] or not data is Dictionary:
		return _fail("关卡必须是支持的 JSON 对象")
	if not _tree(data, 0) or JSON.stringify(data).to_utf8_buffer().size() > MAX_JSON_BYTES:
		return _fail("关卡数据过大、层级过深或包含不支持的值")
	if not _keys(data, TOP_SCENARIO if kind == "scenario" else TOP_DEFENSE):
		return false
	if not _text(data.get("title" if kind == "scenario" else "name", ""), 128) or String(data.get("title", data.get("name", ""))).strip_edges().is_empty():
		return _fail("请填写 1–128 字的作品名称")
	for key in ["subtitle", "deploy_hint", "start_msg", "wave_gap_msg", "win_msg", "lose_msg", "top_status"]:
		if data.has(key) and not _text(data[key], 2048): return _fail(key + " 必须是文字")
	for key in ["start_gold", "start_wood", "pop_cap", "hero_cap"]:
		var limit := 9999 if key.begins_with("start_") else (200 if key == "pop_cap" else 12)
		if data.has(key) and not _number(data[key], 0, limit, true): return _fail(key + " 超出范围")
	if not _overrides(data, kind): return false
	if kind == "custom_defense": return _defense(data)
	var map: Variant = data.get("map", {})
	if not map is Dictionary or not _keys(map, ["w", "h", "theme", "base"]): return _fail("地图格式无效")
	if not _number(map.get("w", 48), 24, 96, true) or not _number(map.get("h", 48), 24, 96, true): return _fail("地图宽高须为 24–96 格")
	_width = int(map.get("w", 48)); _height = int(map.get("h", 48))
	if map.get("theme", "marsh") not in ["marsh", "plain", "hills", "town"] or not _terrain(map.get("base", "GRASS")): return _fail("地图主题或地形无效")
	for key in ["camera_start", "target"]:
		if data.has(key) and not _cell(data[key]): return _fail(key + " 坐标无效")
	for key in ["economy", "fog"]:
		if data.has(key) and not data[key] is bool: return _fail(key + " 必须是布尔值")
	if not _number(data.get("start_age", 3), 1, 3, true): return _fail("时代无效")
	if data.get("wave_mode", "clear") not in ["clear", "timed"] or data.get("wave_faction", "GUAN") not in ["LIANG", "GUAN"] or not _number(data.get("wave_gap", 9), 0, 120): return _fail("波次设置无效")
	_gates = data.get("gates", {}) if data.get("gates", {}) is Dictionary else {}
	if not data.get("gates", {}) is Dictionary or _gates.size() > 32: return _fail("出兵口无效")
	for gate in _gates:
		if not _id(gate) or not _cell(_gates[gate]): return _fail("出兵口坐标无效")
	if not _deploy(data.get("deploy", [])): return false
	if not _scenario_waves(data.get("waves", [])): return false
	if not _conditions(data.get("win", [])) or not _conditions(data.get("lose", [])): return false
	if not _terrain_ops(data.get("terrain", [])): return false
	var decor: Variant = data.get("decor", [])
	if not decor is Array or decor.size() > 1024: return _fail("装饰数量过多")
	for e in decor:
		if not e is Array or e.size() != 3 or e[0] not in DECOR or not _cell(e[1]) or not _number(e[2], 16, 160): return _fail("装饰格式无效")
	var intro: Variant = data.get("intro", [])
	if not intro is Array or intro.size() > 100: return _fail("剧情数量过多")
	for line in intro:
		if not line is Dictionary or not _keys(line, ["who", "key", "text"]) or not _text(line.get("who", ""), 128) or not _text(line.get("text", ""), 2048): return _fail("剧情格式无效")
		if line.get("key", "narrator") != "narrator" and not Defs.UNITS.has(line.get("key")): return _fail("剧情头像必须使用游戏内角色")
	return true

func _overrides(data: Dictionary, kind: String) -> bool:
	var us: Variant = data.get("units", {})
	var ab: Variant = data.get("abilities", {})
	var aliases: Variant = data.get("sprite_alias", {})
	if not us is Dictionary or not ab is Dictionary or not aliases is Dictionary or us.size() > 512 or ab.size() > 1024: return _fail("单位或技能配置无效")
	_units = Defs.UNITS.duplicate()
	_abilities = Defs.ABILITIES.duplicate()
	for key in us:
		if not _id(key) or not us[key] is Dictionary: return _fail("单位标识无效")
		if not Defs.UNITS.has(key) and (kind != "scenario" or not aliases.has(key) or not Defs.UNITS.has(aliases[key])): return _fail("新单位必须直接借用游戏内单位美术")
		_units[key] = us[key]
	for key in ab:
		if not _id(key) or not ab[key] is Dictionary or (kind == "custom_defense" and not Defs.ABILITIES.has(key)): return _fail("技能标识无效")
		_abilities[key] = ab[key]
	for key in aliases:
		if not _units.has(key) or not Defs.UNITS.has(aliases[key]): return _fail("借图引用无效")
	var unit_fields := _field_examples(Defs.UNITS)
	unit_fields.defense = 0.0
	var ability_fields := _field_examples(Defs.ABILITIES)
	var effects := {}
	for a in Defs.ABILITIES.values():
		for k in a.get("effect", {}): effects[k] = a.effect[k]
	for key in us:
		if kind == "custom_defense" and not _keys(us[key], ["name", "hp", "atk", "defense", "range", "cd", "speed"]): return false
		var unit_examples := unit_fields.duplicate(true)
		unit_examples.merge(Defs.UNITS.get(key, Defs.UNITS.get(aliases.get(key, ""), {})), true)
		if not _typed_fields(us[key], unit_examples): return false
		for f in ["ability", "abilities", "trained_at", "produces"]:
			if not us[key].has(f): continue
			var refs: Array = us[key][f] if us[key][f] is Array else [us[key][f]]
			for ref in refs:
				if ref != "" and not (_abilities if f in ["ability", "abilities"] else _units).has(ref): return _fail("单位引用不存在：" + String(ref))
	for key in ab:
		var ability_examples := ability_fields.duplicate(true)
		ability_examples.merge(Defs.ABILITIES.get(key, {}), true)
		if not _typed_fields(ab[key], ability_examples): return false
		if ab[key].has("effect"):
			var effect_examples := effects.duplicate(true)
			for base in Defs.ABILITIES.values():
				if base.get("effect", {}).get("kind", "") == ab[key].effect.get("kind", ""):
					effect_examples.merge(base.get("effect", {}), true)
			effect_examples.merge(Defs.ABILITIES.get(key, {}).get("effect", {}), true)
			if not ab[key].effect is Dictionary or not _typed_fields(ab[key].effect, effect_examples): return false
			var eff: Dictionary = ab[key].effect
			var known_kinds := []
			for a in Defs.ABILITIES.values():
				if a.has("effect"): known_kinds.append(a.effect.get("kind", ""))
			if eff.has("kind") and eff.kind not in known_kinds: return _fail("不支持的技能效果")
			if eff.has("unit") and not _units.has(eff.unit): return _fail("召唤单位不存在")
	return true

func _typed_fields(values: Dictionary, examples: Dictionary) -> bool:
	for key in values:
		if not examples.has(key): return _fail("不支持的属性：" + String(key))
		var v: Variant = values[key]
		var sample: Variant = examples[key]
		if sample is Dictionary:
			if not v is Dictionary: return _fail(String(key) + " 必须是对象")
			if key != "effect" and not _typed_fields(v, sample): return false
		elif sample is Array:
			if not v is Array or v.size() > 128: return _fail(String(key) + " 列表无效")
			if key.ends_with("_ranks") or key in ["lo", "hi", "bonus", "copy_hp_mult", "copy_atk_mult", "copy_mult"]:
				if v.size() != 3: return _fail(String(key) + " 需要三个等级值")
			for item in v:
				if not sample.is_empty() and not _same_type(item, sample[0]): return _fail(String(key) + " 列表类型无效")
		elif not _same_type(v, sample): return _fail(String(key) + " 类型无效")
		if v is int or v is float:
			var maximum := 1000000.0
			if key in ["radius", "range", "speed", "aura_r"]: maximum = 1024
			if key in ["count", "max_stacks", "jumps", "garrison_cap"]: maximum = 40
			if not _number(v, 0, maximum): return _fail(String(key) + " 数值超出范围")
	return true

func _same_type(value: Variant, sample: Variant) -> bool:
	if sample is int or sample is float: return _number(value, -1000000, 1000000)
	if sample is Color: return value is Color or (value is String and Color.html_is_valid(value))
	return typeof(value) == typeof(sample)

func _field_examples(table: Dictionary) -> Dictionary:
	var result := {}
	for value in table.values():
		for key in value: result[key] = value[key]
	return result

func _deploy(entries: Variant) -> bool:
	if not entries is Array or entries.size() > 256: return _fail("布兵或增援过多")
	for e in entries:
		if not e is Dictionary or not _keys(e, ["key", "faction", "cell", "ref"]) or not _units.has(e.get("key")) or not _cell(e.get("cell")) or e.get("faction", "LIANG") not in ["LIANG", "GUAN"]: return _fail("布兵格式、单位或坐标无效")
		if not _register_ref(e): return false
	return true

func _register_ref(e: Dictionary) -> bool:
	var ref: Variant = e.get("ref", "")
	if ref == "": return true
	if not _id(ref) or _refs.has(ref): return _fail("重复或无效的单位引用")
	_refs[ref] = true
	return true

func _scenario_waves(waves: Variant) -> bool:
	if not waves is Array or waves.size() > 120: return _fail("波次最多 120 波")
	var total := 0
	for wave in waves:
		if not wave is Dictionary or not _keys(wave, ["delay", "msg", "groups", "reinforce"]) or not _number(wave.get("delay", 9), 0, 120) or not _text(wave.get("msg", ""), 2048): return _fail("波次格式无效")
		var groups: Variant = wave.get("groups", [])
		if not groups is Array or groups.size() > 32: return _fail("每波兵组过多")
		for g in groups:
			if not g is Dictionary or not _keys(g, ["key", "n", "gate", "ref"]) or not _units.has(g.get("key")) or not _number(g.get("n", 1), 1, 40, true): return _fail("兵组无效")
			var gate: Variant = g.get("gate")
			if gate != null and not ((gate is String and _gates.has(gate)) or _cell(gate)): return _fail("兵组出兵口不存在")
			if not _register_ref(g): return false
			total += int(g.get("n", 1))
		if wave.has("reinforce"):
			var rf: Variant = wave.reinforce
			if not rf is Dictionary or not _keys(rf, ["msg", "units"]) or not _text(rf.get("msg", ""), 2048) or not _deploy(rf.get("units", [])): return _fail("增援格式无效")
	return total <= 12000 or _fail("总出兵数量过多")

func _defense(data: Dictionary) -> bool:
	var waves: Variant = data.get("waves", [])
	if not waves is Array or waves.size() > 120: return _fail("波次最多 120 波")
	var total := 0
	for wave in waves:
		if not wave is Dictionary or not _keys(wave, ["t", "msg", "groups", "cata"]) or not _number(wave.get("t", 9), 0, 7200) or not _number(wave.get("cata", 1), 0, 10, true) or not _text(wave.get("msg", ""), 2048): return _fail("据守波次格式无效")
		var groups: Variant = wave.get("groups", [])
		if not groups is Array or groups.size() > 32: return _fail("每波兵组过多")
		for g in groups:
			if not g is Array or g.size() not in [3, 4] or not Defs.UNITS.has(g[0]) or not _number(g[1], 1, 200, true) or not _number(g[2], 0, 5, true): return _fail("据守兵组格式无效")
			if g.size() == 4 and not _number(g[3], 0, 2, true): return _fail("敌将等级无效")
			total += int(g[1])
	return total <= 12000 or _fail("总出兵数量过多")

func _conditions(conditions: Variant) -> bool:
	if not conditions is Array or conditions.size() > 32: return _fail("胜负条件数量过多")
	for c in conditions:
		if not c is Dictionary or not _keys(c, ["type", "msg", "ref", "t"]) or c.get("type") not in ["survive_waves", "kill_all", "no_army", "ref_dead", "ref_alive", "timer"] or not _text(c.get("msg", ""), 2048): return _fail("胜负条件无效或使用了脚本")
		if c.type in ["ref_dead", "ref_alive"] and not _refs.has(c.get("ref")): return _fail("胜负条件引用不存在")
		if c.type == "timer" and not _number(c.get("t", 60), 1, 7200): return _fail("计时条件无效")
	return true

func _terrain_ops(ops: Variant) -> bool:
	if not ops is Array or ops.size() > 10000: return _fail("地形指令过多")
	for op in ops:
		if not op is Dictionary or not _keys(op, ["op", "c", "rx", "ry", "t", "only", "x", "y", "w", "h", "pts", "brush", "of", "into", "density", "seed"]): return _fail("地形指令格式无效")
		if op.get("op") not in ["fill_ellipse", "fill_rect", "paint_path", "scatter", "set_cell"]: return _fail("地形指令不支持")
		for key in ["t", "of", "into"]:
			if op.has(key) and not _terrain(op[key]): return _fail("地形类型无效")
		if op.has("c") and not _cell(op.c): return _fail("地形坐标无效")
		for key in ["x", "y", "w", "h", "rx", "ry", "brush", "density"]:
			if op.has(key) and not _number(op[key], 0, 96): return _fail("地形范围无效")
		if op.has("seed") and not _number(op.seed, 0, 2147483647, true): return _fail("地形随机种子无效")
		var only: Variant = op.get("only", [])
		if not only is Array or only.size() > 15: return _fail("地形筛选无效")
		for t in only:
			if not _terrain(t): return _fail("地形筛选类型无效")
		var pts: Variant = op.get("pts", [])
		if not pts is Array or pts.size() > 256: return _fail("路径点过多")
		for p in pts:
			if not _cell(p): return _fail("路径坐标无效")
	return true

func _tree(value: Variant, depth: int) -> bool:
	_budget += 1
	if depth > 16 or _budget > 160000: return false
	if value is Dictionary:
		for k in value:
			if not k is String or k in ["script", "script_path", "resource_path"] or not _tree(value[k], depth + 1): return false
	elif value is Array:
		for v in value:
			if not _tree(v, depth + 1): return false
	elif value is float:
		return is_finite(value)
	elif value is String:
		return value.length() <= 4096 and not "://" in value and not "\\" in value
	elif value != null and not value is int and not value is bool:
		return false
	return true

func _keys(value: Dictionary, allowed: Array) -> bool:
	for key in value:
		if key not in allowed: return _fail("不支持的字段：" + String(key))
	return true

func _id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 64: return false
	for c in value:
		if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c not in ["_", "-"]: return false
	return true

func _cell(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], 0, _width - 1, true) and _number(value[1], 0, _height - 1, true)

func _terrain(value: Variant) -> bool:
	return value in TERRAIN if value is String else _number(value, 0, 14, true)

func _number(value: Variant, low: float, high: float, integer := false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or float(value) == floor(float(value)))

func _text(value: Variant, maximum: int) -> bool:
	return value is String and value.length() <= maximum

func _fail(message: String) -> bool:
	if error.is_empty(): error = message
	return false
