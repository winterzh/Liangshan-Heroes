class_name ScenarioStore
## 自定义关卡（scenario）存读：JSON 存到 user://scenarios/，供场景编辑器与「自定义关卡」入口共用。
## 格式见 docs/SCENARIO_FORMAT.md，由 scripts/levels/scenario.gd 解释执行。

const DIR := "user://scenarios"


static func default_scenario() -> Dictionary:
	return {
		"id": "my_scenario",
		"title": "我的关卡",
		"subtitle": "",
		"map": {"w": 48, "h": 48, "theme": "marsh", "base": "GRASS"},
		"camera_start": [24, 24],
		"start_age": 3,
		"hero_cap": 0,
		"economy": false,
		"start_gold": 0,
		"start_wood": 0,
		"pop_cap": 0,
		"terrain": [],
		"decor": [],
		"intro": [],
		"deploy": [],
		"gates": {},
		"wave_faction": "GUAN",
		"wave_gap": 9.0,
		"start_msg": "",
		"wave_gap_msg": "",
		"waves": [],
		"win": [],
		"lose": [],
	}


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


static func _safe(name: String) -> String:
	var out := ""
	for ch in name:
		out += ch if "/\\:*?\"<>|".find(ch) < 0 else "_"
	out = out.strip_edges()
	return out if out != "" else "未命名关卡"


static func save(cfg: Dictionary) -> String:
	_ensure_dir()
	var path := DIR + "/" + _safe(String(cfg.get("title", "未命名关卡"))) + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(cfg, "\t"))
	f.close()
	return path


static func list_saved() -> Array:
	_ensure_dir()
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir != null:
		for fn in dir.get_files():
			if fn.ends_with(".json"):
				out.append(fn.get_basename())
	out.sort()
	return out


static func load_by_name(name: String) -> Dictionary:
	var path := DIR + "/" + _safe(name) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	return data if data is Dictionary else {}
