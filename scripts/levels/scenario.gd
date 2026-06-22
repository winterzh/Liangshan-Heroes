extends LevelBase
## 数据驱动关卡（Phase A）。读一份 scenario 字典（schema 见 docs/SCENARIO_FORMAT.md），
## 把 LevelBase 的钩子全部从数据喂出来：地图 / 地形指令 / 装饰 / 布兵 / 波次 / 胜负条件。
## 覆盖 80% 常规需求；那 20% 定制机制（指路、专属胜负、特殊技能等）挂 data.script 的伴生 .gd——
## 伴生脚本可实现 deploy/on_start/process/on_wave/on_unit_died/on_ability/top_status/cond 任意子集。
##
## 数据来源：Campaign.scenario_data（编辑器试玩 / 分享码 / SCENARIO=<json> 环境变量）。

var data: Dictionary = {}

var _refs := {}            # ref 名 -> Unit（布兵/波次里标了 ref 的单位，供胜负条件引用）
var _wave_i := 0
var _wave_spawned := false
var _wave_t := 0.0
var _waves_done := false
var _all_spawned := false
var _wm := "clear"         # 波次推进：clear=清完上一波才出下一波（默认）；timed=按计时叠加出兵（像遭遇战）
var _elapsed := 0.0
var _ended := false
var _hook = null           # 可选伴生脚本实例（定制逻辑）

# 地形名 -> GameMap.T 枚举（显式表，比字符串索引枚举更稳、也是给编辑器的白名单）
const T_NAMES := {
	"WATER": GameMap.T.WATER, "SHORE": GameMap.T.SHORE, "MARSH": GameMap.T.MARSH,
	"REEDS": GameMap.T.REEDS, "GRASS": GameMap.T.GRASS, "ROAD": GameMap.T.ROAD,
	"FOREST": GameMap.T.FOREST, "HALL": GameMap.T.HALL, "DRYHILL": GameMap.T.DRYHILL,
	"CLIFF": GameMap.T.CLIFF, "TOWN": GameMap.T.TOWN, "PLAZA": GameMap.T.PLAZA,
	"FIELD": GameMap.T.FIELD, "PLAIN": GameMap.T.PLAIN, "DOCK": GameMap.T.DOCK,
}


# ---------- 名字/坐标转换工具 ----------

func _t(v) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return int(T_NAMES.get(String(v), GameMap.T.GRASS))


func _fac(v) -> int:
	return Unit.FACTION_GUAN if String(v).to_upper() == "GUAN" else Unit.FACTION_LIANG


func _cell(a) -> Vector2i:
	if a is Vector2i:
		return a
	if a is Array and a.size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))
	return Vector2i.ZERO


func _m(key: String, def = {}) -> Variant:
	return data.get("map", {}).get(key, def) if data.has("map") else def


# ---------- 基本信息 / 地图 ----------

func id() -> String: return String(data.get("id", "scenario"))
func title() -> String: return String(data.get("title", "自定义关卡"))
func subtitle() -> String: return String(data.get("subtitle", ""))

func map_w() -> int: return int(_m("w", 60))
func map_h() -> int: return int(_m("h", 60))
func map_theme() -> String: return String(_m("theme", "marsh"))
func map_base() -> int: return _t(_m("base", "GRASS"))

func camera_start_cell() -> Vector2i:
	return _cell(data.get("camera_start", [map_w() / 2, map_h() / 2]))

func deploy_hint() -> String:
	return String(data.get("deploy_hint", super.deploy_hint()))


# ---------- 经济 / 全局 ----------

func economy_enabled() -> bool: return bool(data.get("economy", false))
func start_gold() -> int: return int(data.get("start_gold", 0))
func start_wood() -> int: return int(data.get("start_wood", 0))
func base_pop_cap() -> int: return int(data.get("pop_cap", 0))
func hero_cap() -> int: return int(data.get("hero_cap", 0))
func fog_enabled() -> bool: return bool(data.get("fog", false))
func start_age() -> int: return int(data.get("start_age", 3))


# ---------- 剧情 ----------

func intro_lines() -> Array: return data.get("intro", [])


# ---------- 地形 / 装饰 ----------

func paint_map(map: GameMap) -> void:
	for op in data.get("terrain", []):
		_apply_terrain_op(map, op)

func _apply_terrain_op(map: GameMap, op: Dictionary) -> void:
	var only: Array = []
	for tn in op.get("only", []):
		only.append(_t(tn))
	match String(op.get("op", "")):
		"fill_ellipse":
			var c := _cell(op.get("c", [0, 0]))
			map.fill_ellipse(Vector2(c.x, c.y), float(op.get("rx", 1)), float(op.get("ry", 1)), _t(op.get("t", "GRASS")), only)
		"fill_rect":
			map.fill_rect(int(op.get("x", 0)), int(op.get("y", 0)), int(op.get("w", 1)), int(op.get("h", 1)), _t(op.get("t", "GRASS")), only)
		"paint_path":
			var pts: Array = []
			for p in op.get("pts", []):
				pts.append(Vector2(int(p[0]), int(p[1])))
			map.paint_path(pts, int(op.get("brush", 1)), _t(op.get("t", "ROAD")))
		"scatter":
			map.scatter(_t(op.get("of", "GRASS")), _t(op.get("into", "FOREST")), int(op.get("density", 4)), int(op.get("seed", 0)))
		"set_cell":
			var sc := _cell(op.get("c", [0, 0]))
			map.set_cell_t(sc.x, sc.y, _t(op.get("t", "GRASS")))


func decorate(map: GameMap) -> void:
	var d: Array = []
	for e in data.get("decor", []):
		if e is Array and e.size() >= 3:
			d.append([String(e[0]), _cell(e[1]), float(e[2])])
	map.decor = d


# ---------- 布兵 / 流程 ----------

func deploy(b) -> void:
	_hook = _load_hook()
	for e in data.get("deploy", []):
		var u = b.spawn_at(String(e.get("key", "")), _fac(e.get("faction", "LIANG")), _cell(e.get("cell", [0, 0])))
		if u != null and String(e.get("ref", "")) != "":
			_refs[String(e["ref"])] = u
	if _hook != null and _hook.has_method("deploy"):
		_hook.deploy(b, self)


func on_start(b) -> void:
	_wave_i = 0
	_wave_spawned = false
	_all_spawned = false
	_elapsed = 0.0
	_ended = false
	_wm = String(data.get("wave_mode", "clear"))
	var waves: Array = data.get("waves", [])
	_waves_done = waves.is_empty()
	_wave_t = float(waves[0].get("delay", 5.0)) if not _waves_done else 0.0
	var sm := String(data.get("start_msg", ""))
	if sm != "":
		b.msg(sm, 4.0)
	if _hook != null and _hook.has_method("on_start"):
		_hook.on_start(b, self)


func process(b, delta: float) -> void:
	if _ended:
		return
	_elapsed += delta
	var waves: Array = data.get("waves", [])
	if not _waves_done:
		if _wm == "timed":
			# 定时叠加出兵：到点就放下一波，不等清场（密度大、像遭遇战围剿）
			_wave_t -= delta
			if _wave_t <= 0.0 and _wave_i < waves.size():
				_spawn_wave(b, _wave_i)
				_wave_i += 1
				if _wave_i < waves.size():
					_wave_t = float(waves[_wave_i].get("delay", data.get("wave_gap", 8.0)))
				else:
					_all_spawned = true
			if _all_spawned and b.enemies_alive() == 0:
				_waves_done = true
		else:
			# 清完上一波才出下一波（默认；每波是一场独立攻防）
			if not _wave_spawned:
				_wave_t -= delta
				if _wave_t <= 0.0:
					_spawn_wave(b, _wave_i)
			elif b.enemies_alive() == 0:
				if _wave_i >= waves.size() - 1:
					_waves_done = true
				else:
					_wave_i += 1
					_wave_spawned = false
					_wave_t = float(waves[_wave_i].get("delay", data.get("wave_gap", 8.0)))
					var gm := String(data.get("wave_gap_msg", ""))
					if gm != "":
						b.msg(gm, 3.5)
	if _hook != null and _hook.has_method("process"):
		_hook.process(b, delta, self)
	# 胜负判定（胜利优先：歼灭/守关都先于"全军覆没"结算）
	for c in _win_conds():
		if _cond_met(b, c):
			_ended = true
			b.win(String(c.get("msg", data.get("win_msg", "胜利！"))))
			return
	for c in _lose_conds():
		if _cond_met(b, c):
			_ended = true
			b.lose(String(c.get("msg", data.get("lose_msg", "战败……"))))
			return


func _spawn_wave(b, i: int) -> void:
	_wave_spawned = true
	var wave: Dictionary = data.get("waves", [])[i]
	var msg := String(wave.get("msg", ""))
	if msg != "":
		b.msg("【第 %d 波】%s" % [i + 1, msg], 5.0)
	var target := _wave_target(b)
	var wf := _fac(data.get("wave_faction", "GUAN"))
	var gates: Dictionary = data.get("gates", {})
	for g in wave.get("groups", []):
		var gate_cell := _resolve_gate(g.get("gate", null), gates)
		var spawned: Array = b.spawn_group(String(g.get("key", "")), int(g.get("n", 1)), wf, gate_cell, target)
		if String(g.get("ref", "")) != "" and spawned.size() > 0:
			_refs[String(g["ref"])] = spawned[0]
	var rf = wave.get("reinforce", null)
	if rf != null:
		var rmsg := String(rf.get("msg", ""))
		if rmsg != "":
			b.msg(rmsg, 5.0)
		for e in rf.get("units", []):
			var ru = b.spawn_at(String(e.get("key", "")), _fac(e.get("faction", "LIANG")), _cell(e.get("cell", [0, 0])))
			if ru != null and String(e.get("ref", "")) != "":
				_refs[String(e["ref"])] = ru
	if _hook != null and _hook.has_method("on_wave"):
		_hook.on_wave(b, i, self)


func _wave_target(b) -> Vector2:
	if data.has("target"):
		return b.map.cell_to_world(_cell(data["target"]))
	if _refs.has("hall") and is_instance_valid(_refs["hall"]):
		return _refs["hall"].position
	return b.map.cell_to_world(camera_start_cell())


func _resolve_gate(g, gates: Dictionary) -> Vector2i:
	if g == null:
		return camera_start_cell()
	if typeof(g) == TYPE_STRING:
		return _cell(gates[g]) if gates.has(g) else camera_start_cell()
	if g is Array:
		return _cell(g)
	return camera_start_cell()


func on_unit_died(b, u) -> void:
	if _hook != null and _hook.has_method("on_unit_died"):
		_hook.on_unit_died(b, u, self)


func on_ability(b, caster, ability_id: String, lp: Vector2) -> bool:
	if _hook != null and _hook.has_method("on_ability"):
		return bool(_hook.on_ability(b, caster, ability_id, lp, self))
	return false


func top_status(b) -> String:
	if _hook != null and _hook.has_method("top_status"):
		var s := String(_hook.top_status(b, self))
		if s != "":
			return s
	var waves: Array = data.get("waves", [])
	if not waves.is_empty():
		var nxt := ""
		var pending := (_wave_i < waves.size()) if _wm == "timed" else (not _wave_spawned)
		if pending and not _waves_done:
			nxt = " | 下一波 %d 秒" % int(ceil(maxf(0.0, _wave_t)))
		return "第 %d/%d 波%s | 歼敌 %d" % [mini(_wave_i + 1, waves.size()), waves.size(), nxt, b.kills]
	return String(data.get("top_status", ""))


# ---------- 胜负条件 ----------

func _win_conds() -> Array:
	if data.has("win"):
		return data["win"]
	if not data.get("waves", []).is_empty():
		return [{"type": "survive_waves", "msg": "守住了——敌军攻势尽数瓦解！"}]
	return [{"type": "kill_all", "msg": "全歼敌军！"}]


func _lose_conds() -> Array:
	if data.has("lose"):
		return data["lose"]
	return [{"type": "no_army", "msg": "全军覆没……"}]


func _cond_met(b, c: Dictionary) -> bool:
	match String(c.get("type", "")):
		"survive_waves":
			return _waves_done and b.enemies_alive() == 0
		"kill_all":
			return b.enemies_alive() == 0
		"no_army":
			return b.players_alive() == 0
		"ref_dead":
			# 仅当该 ref 曾被登记（已出场）后死亡才算——避免后续波次的 boss 未出场就误判
			var r := String(c.get("ref", ""))
			return _refs.has(r) and (not is_instance_valid(_refs[r]) or _refs[r].hp <= 0.0)
		"ref_alive":
			var ra := String(c.get("ref", ""))
			return _refs.has(ra) and is_instance_valid(_refs[ra]) and _refs[ra].hp > 0.0
		"timer":
			return _elapsed >= float(c.get("t", 60.0))
		"hook":
			return _hook != null and _hook.has_method("cond") and bool(_hook.cond(b, String(c.get("name", "")), self))
	return false


# ---------- 伴生脚本 ----------

func _load_hook():
	var sp := String(data.get("script", ""))
	if sp != "" and ResourceLoader.exists(sp):
		return load(sp).new()
	return null
