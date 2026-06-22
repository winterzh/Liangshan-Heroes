extends "res://scripts/levels/skirmish.gd"
## 自定义据守战：继承据守关卡，按 Campaign.custom_config 覆盖经济/波次/单位与技能数值。
## 地图/部署/出兵口/敌将自动学技能(_arm_boss) 全部继承据守本体。

var _cfg: Dictionary = {}


func _init() -> void:
	if Campaign.custom_config is Dictionary:
		_cfg = Campaign.custom_config


func id() -> String: return "custom_defense"
func title() -> String: return String(_cfg.get("name", "自定义据守"))
func subtitle() -> String: return "自定义据守战"

func start_gold() -> int: return int(_cfg.get("start_gold", 250))
func start_wood() -> int: return int(_cfg.get("start_wood", 150))
func base_pop_cap() -> int: return int(_cfg.get("pop_cap", 20))
func hero_cap() -> int: return int(_cfg.get("hero_cap", 4))


func intro_lines() -> Array:
	return [{"who": "军令", "key": "narrator",
		"text": "【自定义据守】%s——守住聚义厅，击退所有来犯的官军！" % String(_cfg.get("name", ""))}]


## 波次：用 config 的，空则退回据守本体 WAVES。
func _waves() -> Array:
	var w: Variant = _cfg.get("waves", [])
	if w is Array and not (w as Array).is_empty():
		return w
	return WAVES


## 每波投石车数：config 每波带 "cata" 字段则用之，否则沿用本体 1/2 规则。
func _cata_for(i: int) -> int:
	var ws: Array = _waves()
	if i >= 0 and i < ws.size() and ws[i] is Dictionary and (ws[i] as Dictionary).has("cata"):
		return int(ws[i]["cata"])
	return super._cata_for(i)


## 兵组敌将技能等级：config 每组第 4 元 [key,count,gate,rank]；缺省满级 2。
func _group_rank(g) -> int:
	return int(g[3]) if (g is Array and g.size() > 3) else 2


## 部署前把单位/技能数值覆盖合并进本场 _defs/_abilities（借 battle 的每场深拷贝缝，全局生效）。
func _apply_overrides(b) -> void:
	if not _cfg.is_empty():
		CustomConfig.apply_overrides(_cfg, b._defs, b._abilities)
