class_name CustomConfig
## 自定义据守战配置：单位/技能数值覆盖 + 敌方波次。存为 JSON 到 user://custom_defense/。
## 「默认配置」= 现行据守(Defs 现值 + skirmish.WAVES)，编辑器在此基础上改。

const SK = preload("res://scripts/levels/skirmish.gd")
const DIR := "user://custom_defense"

# 编辑器暴露可改的单位字段（皆数值）
const UNIT_FIELDS := ["hp", "atk", "defense", "range", "cd", "speed"]


## 是否算「战斗单位」（编辑器列出的对象）：能打的兵/英雄/工人/箭楼/投石车；排除纯资源点与纯经济建筑。
static func is_combat_unit(d: Dictionary) -> bool:
	if d.has("res_kind"):
		return false
	return float(d.get("atk", 0.0)) > 0.0 or bool(d.get("hero", false)) \
		or bool(d.get("worker", false)) or bool(d.get("ranged", false))


## 默认配置 = 现行据守战快照（单位现值 + 全技能 + skirmish 波次）。
static func default_config() -> Dictionary:
	var cfg := {
		"name": "默认据守", "units": {}, "abilities": {}, "waves": [],
		"start_gold": 250, "start_wood": 150, "pop_cap": 20, "hero_cap": 4,
	}
	for key in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[key]
		if not is_combat_unit(d):
			continue
		var u := {"name": String(d.get("name", key))}
		for f in UNIT_FIELDS:
			u[f] = float(d.get(f, 0.0))
		cfg["units"][key] = u
	for id in Defs.ABILITIES:
		var a: Dictionary = Defs.ABILITIES[id]
		var ab := {"name": String(a.get("name", id)), "cd": float(a.get("cd", 0.0)),
			"radius": float(a.get("radius", 0.0))}
		if a.has("effect"):
			ab["effect"] = (a["effect"] as Dictionary).duplicate(true)
		cfg["abilities"][id] = ab
	for w in SK.WAVES:
		var groups: Array = []
		for g in w["groups"]:
			# [兵种, 数量, 出兵口, 敌将技能等级(默认满级2)]
			groups.append([String(g[0]), int(g[1]), int(g[2]), 2])
		cfg["waves"].append({
			"t": float(w["t"]), "msg": String(w.get("msg", "")),
			"groups": groups, "cata": 1,
		})
	return cfg


## 把 config 的单位/技能覆盖合并进一场战斗的 _defs / _abilities（在任何 spawn 前调）。
static func apply_overrides(cfg: Dictionary, defs: Dictionary, abilities: Dictionary) -> void:
	var us: Dictionary = cfg.get("units", {})
	for key in us:
		if not defs.has(key):
			continue
		var ov: Dictionary = us[key]
		for f in UNIT_FIELDS:
			if ov.has(f):
				defs[key][f] = float(ov[f])
	var ab: Dictionary = cfg.get("abilities", {})
	for id in ab:
		if not abilities.has(id):
			continue
		var ov: Dictionary = ab[id]
		if ov.has("cd"):
			abilities[id]["cd"] = float(ov["cd"])
		if ov.has("radius"):
			abilities[id]["radius"] = float(ov["radius"])
		if ov.has("effect") and abilities[id].has("effect"):
			var eff: Dictionary = ov["effect"]
			for k in eff:
				abilities[id]["effect"][k] = eff[k]


## ---------- 存读 ----------

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)


static func _safe(name: String) -> String:
	var out := ""
	for ch in name:
		out += ch if "/\\:*?\"<>|".find(ch) < 0 else "_"
	return out.strip_edges() if out.strip_edges() != "" else "未命名"


static func save(cfg: Dictionary) -> String:
	_ensure_dir()
	var path := DIR + "/" + _safe(String(cfg.get("name", "未命名"))) + ".json"
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
