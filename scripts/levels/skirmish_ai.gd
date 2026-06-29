extends LevelBase
## 遭遇战 · AI 对战（1v1 · 真经济）。与一名会经营的电脑官军正面对抗：
## 双方各有大本营、金矿、林木与农民。电脑用【真实的农民采集】钱粮、【真实的工地】修寨建塔、
## 按钱粮+人口+兵营约束点兵成军，攒够一波即倾巢突击；大将各带【四技能】智能施放，与玩家对等。
## 经济是真的、能被打断——骚扰它的农民、拆掉它的兵营，都会实打实削弱官军。
## 目标：守住聚义厅，攻破「官军大营」即胜；聚义厅被破则败。

const T := GameMap.T
const HALL := Vector2i(14, 48)        # 玩家·聚义厅
const AI_BASE := Vector2i(50, 14)     # 电脑·官军大营
const P_GOLD := Vector2i(25, 49)
const P_GOLD2 := Vector2i(27, 46)
const AI_GOLD := Vector2i(48, 10)     # 大营正北，避开建造格(都在大营南/西/东)，缩短运金路
const AI_GOLD2 := Vector2i(52, 10)

# 难度：gather=AI采集系数(经济手感：易<1 / 普=1 与玩家对等 / 难>1)；sg/sw=开局存量；
#   workers=起手农民；wcap=农民目标数；train=出兵间隔；first/pint=首攻/后续突击间隔；
#   push0/grow=每波规模与递增；cap=同时存活军队上限。
const DIFF := {
	"easy":   {"gather": 1.0, "sg": 150, "sw": 90,  "workers": 5, "wcap": 6, "train": 10.0, "first": 130.0, "pint": 60.0, "push0": 4, "grow": 2, "cap": 12, "age2": 75.0, "age3": 200.0, "name": "简单"},
	"normal": {"gather": 1.3, "sg": 220, "sw": 130, "workers": 6, "wcap": 7, "train": 6.5,  "first": 100.0, "pint": 46.0, "push0": 5, "grow": 2, "cap": 20, "age2": 60.0, "age3": 165.0, "name": "普通"},
	"hard":   {"gather": 1.9, "sg": 320, "sw": 200, "workers": 7, "wcap": 9, "train": 4.5,  "first": 72.0,  "pint": 36.0, "push0": 7, "grow": 3, "cap": 30, "age2": 45.0, "age3": 130.0, "name": "困难"},
}

# 可训练官军：花费(真实从 AI 私池扣) + 人口 + 抽签权重（defs 里这些兵无 cost 字段，AI 自带账本）
const TROOPS := [
	{"key": "guan_dao",  "g": 40, "w": 0,  "pop": 1, "wt": 5},
	{"key": "guan_gong", "g": 35, "w": 15, "pop": 1, "wt": 3},
	{"key": "guan_qi",   "g": 60, "w": 20, "pop": 2, "wt": 2},
]
const WORKER_G := 45
const WORKER_POP := 1
const AI_BASE_POP := 24       # AI 基础人口上限（盖民居再加）

# 官军大将（轮番登场，各带四技能；由 _enemy_ability_pass 智能施放 Q/W/E/R）
const HERO_ROSTER := ["hu_yanzhuo", "luan_tingyu", "gao_qiu"]
const HERO_COST := {"hu_yanzhuo": 210, "luan_tingyu": 170, "gao_qiu": 240}
const HERO_POP := 3
const HERO_DIFF := {
	"easy":   {"first": 110.0, "int": 96.0, "cap": 1},
	"normal": {"first": 80.0,  "int": 66.0, "cap": 2},
	"hard":   {"first": 56.0,  "int": 48.0, "cap": 3},
}

# 建造序列（相对大营的格偏移）：到点+负担得起+有空闲农民就开真实工地。民居提升 AI 人口上限。
const BUILD_PLAN := [
	{"key": "barracks",      "cell": Vector2i(3, 3)},                 # 先兵营：尽快能练兵
	{"key": "arrow_tower",   "cell": Vector2i(-3, 1)},                # 再修箭楼护营
	{"key": "house",         "cell": Vector2i(-4, 0)},
	{"key": "thunder_tower", "cell": Vector2i(-2, 4), "age": 2},      # 霹雳炮：群伤护营(聚义代)
	{"key": "house",         "cell": Vector2i(4, 1)},
	{"key": "altar_tower",   "cell": Vector2i(1, -2), "age": 2},      # 五雷法坛：优先打来犯英雄
	{"key": "caltrop_tower", "cell": Vector2i(-4, 3), "age": 2},      # 拒马：减速拖住攻势
	{"key": "arrow_tower",   "cell": Vector2i(2, -3), "age": 2},      # 多一座箭楼补火力
	{"key": "siege_workshop", "cell": Vector2i(5, 3), "age": 3},      # 替天行道代才建，造撞车攻坚
]

var hall: Unit
var ai_base: Unit
var _diff := {}
var _diff_key := "normal"

var _elapsed := 0.0
var _train_t := 0.0
var _worker_t := 0.0
var _push_t := 0.0
var _push_size := 6
var _staged: Array = []
var _build_i := 0
var _build_cool := 0.0
var _pending_site: Unit = null   # 当前在建工地：完工/失败前不推进建造序列(防玩家拆工地永久断兵)
var _pending_builder: Unit = null
var _waves_sent := 0
var _muster := Vector2.ZERO
var _started := false
var _hero_diff := {}
var _hero_t := 0.0
var _hero_i := 0
var _ai_age := 1            # 官军时代：到点按 DIFF.age2/age3 进阶（英雄需2代、攻城需3代）
var _siege_t := 0.0
# 胜利条件
const KOTH_CELL := Vector2i(32, 42)   # 占山为王·中央聚义点（两营之间的陆地）
const KOTH_R := 150.0
const KOTH_WIN := 75.0
var _victory := "conquest"
var _p_king: Unit = null
var _ai_king: Unit = null
var _koth_p := 0.0
var _koth_a := 0.0


func _resolve_victory() -> String:
	var e := OS.get_environment("VICTORY")
	if e == "conquest" or e == "regicide" or e == "koth":
		return e
	var v: String = String(Campaign.victory_mode) if Campaign.get("victory_mode") != null else "conquest"
	return v if (v == "conquest" or v == "regicide" or v == "koth") else "conquest"


func id() -> String: return "skirmish_ai"
func title() -> String: return "AI 对战"
func subtitle() -> String: return "1v1 · 真经济对抗 · 攻破官军大营"
func map_w() -> int: return 64
func map_h() -> int: return 64
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(20, 46)

func economy_enabled() -> bool: return true
func hero_start_rank() -> int: return 0   # 1v1：英雄仍走原来的经验升级学技能(不受 DOTA 改版影响)
func start_age() -> int: return 1          # 1v1 走完整三代进阶（草莽→聚义→替天行道）
func start_gold() -> int: return 280
func start_wood() -> int: return 160
func base_pop_cap() -> int: return 20
func fog_enabled() -> bool: return true


func _guan() -> int: return Unit.FACTION_GUAN


func deploy_hint() -> String:
	return "对面是会用农民采集、修工地建寨、按队列点兵来攻的电脑官军，大将各带四技能。采金伐木、修寨练兵，守住聚义厅并打穿「官军大营」即胜。骚扰它的农民、拆它的兵营能实打实削弱它。点「开战」开始。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "官军在对岸扎下大营，亦在屯粮募兵、修楼布防。这一回不是死守待援，而是两家正面较量——比谁攒得快、练得精、打得狠。"},
		{"who": "军令", "key": "narrator", "text": "【对战】难度：%s。守住聚义厅，集结兵马杀过去，踏平官军大营！" % String(DIFF.get(_resolve_diff(), {}).get("name", "普通"))},
	]


func paint_map(map: GameMap) -> void:
	# 右上电脑、左下玩家，中间一片水泊与树林分隔
	map.fill_ellipse(Vector2(34, 30), 8, 6, T.WATER)
	map.fill_ellipse(Vector2(30, 38), 4, 3, T.MARSH, [T.GRASS])
	map.scatter(T.MARSH, T.REEDS, 4)
	# 玩家方林木
	map.fill_ellipse(Vector2(22, 52), 4, 3, T.FOREST, [T.GRASS])
	map.fill_ellipse(Vector2(9, 42), 3, 3, T.FOREST, [T.GRASS])
	# 电脑方林木
	map.fill_ellipse(Vector2(52, 22), 4, 3, T.FOREST, [T.GRASS])
	# 两座大本营地基
	for c in [HALL, AI_BASE]:
		for y in range(c.y - 1, c.y + 2):
			for x in range(c.x - 1, c.x + 2):
				map.set_cell_t(x, y, T.HALL)


func decorate(map: GameMap) -> void:
	map.decor = [
		["banner", Vector2i(16, 50), 52.0], ["banner", Vector2i(12, 46), 52.0],
		["banner", Vector2i(52, 16), 52.0], ["banner", Vector2i(48, 12), 52.0],
		["rocks", Vector2i(28, 46), 48.0], ["boat", Vector2i(33, 30), 56.0],
	]
	if _resolve_victory() == "koth":   # 占山为王：中央聚义点立大旗作标记
		map.decor.append(["banner", KOTH_CELL, 64.0])
		map.decor.append(["banner", KOTH_CELL + Vector2i(1, 0), 60.0])


func deploy(b) -> void:
	# 玩家方
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, HALL)
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, P_GOLD)
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, P_GOLD2)   # 双方各两座金矿(对等)：金是瓶颈，两座可同时下两人
	for c in [Vector2i(21, 51), Vector2i(23, 52), Vector2i(22, 53), Vector2i(24, 53), Vector2i(20, 52),
			Vector2i(9, 41), Vector2i(10, 43), Vector2i(8, 43), Vector2i(11, 41), Vector2i(9, 44)]:
		b.spawn_at("tree", Unit.FACTION_LIANG, c)
	for c in [Vector2i(17, 46), Vector2i(18, 47), Vector2i(17, 48), Vector2i(19, 47), Vector2i(18, 49)]:
		b.spawn_at("lou_luo", Unit.FACTION_LIANG, c)
	b.spawn_at("liang_dao", Unit.FACTION_LIANG, Vector2i(20, 46))
	b.spawn_at("liang_dao", Unit.FACTION_LIANG, Vector2i(21, 47))

	# 斩首模式：双方各立一名主帅（宋江 / 高俅），杀掉敌方主帅即胜、自家主帅亡即败
	_victory = _resolve_victory()
	if _victory == "regicide":
		_p_king = b.spawn_at("song_jiang", Unit.FACTION_LIANG, HALL + Vector2i(2, 2))
		_ai_king = b.spawn_at("gao_qiu", _guan(), AI_BASE + Vector2i(-2, 2))
		_seed_hero(_p_king)   # 玩家主帅也开局带技能(与高俅对等)，否则技能 rank0 + R 锁 6 级太弱
		_seed_hero(_ai_king)

	# 电脑方·官军大营(聚义厅形制·改名·作 AI 卸货点) + 金矿/林木(中立可争夺) + 起手农民 + 守军
	ai_base = b.spawn_at("hall", _guan(), AI_BASE)
	ai_base.display_name = "官军大营"
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, AI_GOLD)
	b.spawn_at("gold_mine", Unit.FACTION_LIANG, AI_GOLD2)
	for c in [Vector2i(51, 21), Vector2i(53, 22), Vector2i(52, 23), Vector2i(54, 19), Vector2i(50, 22),
			Vector2i(53, 24), Vector2i(55, 21), Vector2i(51, 24), Vector2i(54, 23), Vector2i(52, 20)]:
		b.spawn_at("tree", Unit.FACTION_LIANG, c)
	_muster = b.map.cell_to_world(b.map.nearest_open(AI_BASE + Vector2i(-2, 3)))
	var nworkers := int(DIFF[_resolve_diff()]["workers"])
	for i in range(nworkers):
		var wc: Vector2i = b.map.nearest_open(AI_BASE + Vector2i(randi_range(-2, 1), randi_range(2, 4)))
		b.spawn_unit("lou_luo", _guan(), b.map.cell_to_world(wc))
	for c in [Vector2i(48, 16), Vector2i(49, 17), Vector2i(50, 17)]:
		var g: Unit = b.spawn_at("guan_dao", _guan(), c)
		_garrison(g)


func on_start(b) -> void:
	# 玩家起手喽啰自动采办（3 金 2 木）
	var pworkers: Array = []
	for u in b.units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG:
			pworkers.append(u)
	for i in range(pworkers.size()):
		var kind := "gold" if i < 3 else "wood"
		var node = b.nearest_resource(pworkers[i].position, kind)
		if node != null:
			pworkers[i].order_gather(node)
	# 电脑经济初始化：真实私有钱粮池 + 难度采集系数
	_diff_key = _resolve_diff()
	_diff = DIFF[_diff_key]
	b.faction_res[_guan()] = {"gold": float(_diff["sg"]), "wood": float(_diff["sw"])}
	b.faction_gather_mult[_guan()] = float(_diff["gather"])
	_elapsed = 0.0
	_train_t = _diff["train"]
	_worker_t = 6.0
	_push_t = _diff["first"]
	_push_size = _diff["push0"]
	_build_i = 0
	_build_cool = 10.0
	_pending_site = null
	_pending_builder = null
	_staged.clear()
	_waves_sent = 0
	_hero_diff = HERO_DIFF[_diff_key]
	_hero_t = float(_hero_diff["first"])
	_hero_i = 0
	_ai_age = 1
	_siege_t = 30.0
	_victory = _resolve_victory()
	_koth_p = 0.0
	_koth_a = 0.0
	_assign_ai_workers(b)
	_started = true
	b.msg("官军（%s）已在对岸扎营——农民下矿伐木、修寨练兵，先发制人！" % String(_diff["name"]), 4.5)


func _seed_hero(h: Unit) -> void:
	if h == null or not is_instance_valid(h):
		return
	for s in range(h.slot_count()):
		h.ability_slots[s]["rank"] = 1 if bool(h.ability_slots[s]["passive"]) else 2
	if h.has_method("_recompute_hero_stats"):
		h._recompute_hero_stats()


# 胜利条件判定：返回 true=已分胜负(本帧结束)。基地被破在任何模式都是底线胜负。
func _check_victory(b, delta: float) -> bool:
	var hall_dead: bool = hall == null or not is_instance_valid(hall) or hall.hp <= 0.0
	var base_dead: bool = ai_base == null or not is_instance_valid(ai_base) or ai_base.hp <= 0.0
	if _victory == "regicide" and _started:
		if _p_king == null or not is_instance_valid(_p_king) or _p_king.hp <= 0.0:
			b.lose("主帅宋江阵亡——群龙无首，梁山败了……"); return true
		if _ai_king == null or not is_instance_valid(_ai_king) or _ai_king.hp <= 0.0:
			b.win("阵斩高太尉！官军群龙无首、土崩瓦解——梁山大胜！"); return true
	elif _victory == "koth" and _started:
		var cp: Vector2 = b.map.cell_to_world(KOTH_CELL)
		var p_in := 0
		var a_in := 0
		for u in b.units:
			if not is_instance_valid(u) or u.is_building or u.is_resource or u.hp <= 0.0 or u.garrisoned:
				continue
			if cp.distance_to(u.position) <= KOTH_R:
				if u.faction == Unit.FACTION_LIANG:
					p_in += 1
				elif u.faction == _guan():
					a_in += 1
		if p_in > 0 and a_in == 0:
			_koth_p += delta
		elif a_in > 0 and p_in == 0:
			_koth_a += delta
		if _koth_p >= KOTH_WIN:
			b.win("梁山独占聚义点，据山为王——这一场赢了！"); return true
		if _koth_a >= KOTH_WIN:
			b.lose("官军牢牢占住聚义点……这一场败了。"); return true
	# 征服 + 所有模式的底线：破营=胜、破厅=败
	if hall_dead:
		b.lose("聚义厅被官军攻破，杏黄旗倒下了……"); return true
	if base_dead:
		b.win("官军大营被踏平，高太尉仓皇北遁——这一场，梁山赢了！"); return true
	return false


func _resolve_diff() -> String:
	var e := OS.get_environment("AI_DIFF")
	if DIFF.has(e):
		return e
	var d: String = String(Campaign.ai_difficulty) if Campaign.get("ai_difficulty") != null else "normal"
	return d if DIFF.has(d) else "normal"


func process(b, delta: float) -> void:
	if _check_victory(b, delta):   # 按所选胜利条件判定（征服/斩首/占山为王）
		return
	if not _started:
		return
	_elapsed += delta
	_ai_advance_age()
	_ai_workers(b, delta)
	_ai_build(b, delta)
	_ai_train(b, delta)
	_ai_heroes(b, delta)
	_ai_siege(b, delta)
	_ai_command(b, delta)


# 时代进阶：到点升代（解锁英雄=2代、攻城=3代），与玩家研究升代对应
func _ai_advance_age() -> void:
	if _ai_age < 2 and _elapsed >= float(_diff.get("age2", 60.0)):
		_ai_age = 2
	elif _ai_age < 3 and _elapsed >= float(_diff.get("age3", 165.0)):
		_ai_age = 3


# ---------- 真经济：农民 ----------

# 开局把 AI 农民分两路：前 2 人下金矿(金是瓶颈)，其余伐木。
# 注意：开局没人在采，nearest_free_gold 对每个人都「空」，不能用它分流——必须按序号显式分。
func _assign_ai_workers(b) -> void:
	var workers := _guan_workers(b)
	for i in range(workers.size()):
		var node = _pick_ai_node(b, workers[i], i < 2)
		if node != null:
			workers[i].order_gather(node)


# 每帧：闲置农民复采(金矿不足 2 人就补金矿，否则伐木)；少于目标数、金粮充裕且有人口就补一个农民
func _ai_workers(b, delta: float) -> void:
	var workers := _guan_workers(b)
	for w in workers:
		if is_instance_valid(w) and w.is_idle_worker():
			var node = _pick_ai_node(b, w, _count_gold_miners(b) < 2)
			if node != null:
				w.order_gather(node)
	# 金矿采空兜底：双方金矿都挖完后，把堆积的木头按集市价折成金（防经济硬死锁）
	_ai_trade_fallback(b)
	_worker_t -= delta
	if _worker_t > 0.0:
		return
	_worker_t = 5.0
	if workers.size() >= _ai_wcap(b):   # 木紧时上限+3，多产的农民去伐木(金矿工受金矿数封顶)
		return
	if _ai_pop(b) + WORKER_POP > _ai_pop_cap(b):
		return
	# 留足买兵营/练兵的金子，别把钱全砸在农民上（金是瓶颈）；木紧时放低缓冲优先补伐木工；农民全没了必须重建
	var buf := 40.0 if _ai_wood_short(b) else 130.0
	if not workers.is_empty() and b.faction_gold(_guan()) < float(WORKER_G) + buf:
		return
	if not b.faction_spend(_guan(), WORKER_G, 0):
		return
	var wc: Vector2i = b.map.nearest_open(AI_BASE + Vector2i(randi_range(-2, 1), randi_range(2, 4)))
	var nw: Unit = b.spawn_unit("lou_luo", _guan(), b.map.cell_to_world(wc))
	var node = _pick_ai_node(b, nw, _count_gold_miners(b) < 2)
	if node != null:
		nw.order_gather(node)


# 金矿采空兜底：自家附近已无金矿、AI 缺金而囤木 → 折木成金（100木→70金，同集市价），防经济硬死锁
func _ai_trade_fallback(b) -> void:
	var g = b.nearest_resource(_muster, "gold")
	if g != null and _muster.distance_to(g.position) < 600.0:
		return   # 本阵附近还有金矿可采，不折
	if b.faction_gold(_guan()) >= 120.0 or b.faction_wood(_guan()) < 100.0:
		return
	if b.faction_spend(_guan(), 0, 100):
		b.add_resources(70, 0, _guan())


# 给一名农民挑资源点：want_gold 时优先没人占的金矿(没空金矿则伐木)；否则直接伐木(没木头才回退金矿)
func _pick_ai_node(b, w: Unit, want_gold: bool):
	var ref: Vector2 = ai_base.position if is_instance_valid(ai_base) else w.position   # 先采离大营最近的资源
	if want_gold:
		var gold = b.nearest_free_gold(ref, null, w)
		if gold != null:
			return gold
	var wood = b.nearest_resource(ref, "wood")
	if wood != null:
		return wood
	return b.nearest_resource(ref, "")


# 当前正下金矿的 AI 农民数（按其采集目标的资源类型计；含运送途中）
func _count_gold_miners(b) -> int:
	var n := 0
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.is_worker and u.hp > 0.0 \
				and is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold":
			n += 1
	return n


# 木头吃紧（移植全托管思路）：库存 < 金的一半 或 绝对地板。塔/民居很费木，建造期常成瓶颈。
func _ai_wood_short(b) -> bool:
	return float(b.faction_wood(_guan())) < float(b.faction_gold(_guan())) * 0.5 or b.faction_wood(_guan()) < 120.0


# 农民目标：平时按难度 wcap；木紧时 +3——金矿工受金矿数封顶(2)，多产的农民自动去伐木补产。
func _ai_wcap(b) -> int:
	return int(_diff["wcap"]) + (3 if _ai_wood_short(b) else 0)


# ---------- 真经济：建造（真实工地，由农民施工） ----------

func _ai_build(b, delta: float) -> void:
	_build_cool -= delta
	# 盯住在建工地：完工才推进序列；被拆/工人途中阵亡→重试本档；在建但没人施工→再派工人。
	# （否则玩家拆掉兵营工地就能让 AI 永远练不出兵——本档永不重试。）
	if _pending_site != null:
		if not is_instance_valid(_pending_site) or _pending_site.hp <= 0.0:
			_pending_site = null            # 工地没了 → 不推进，下面重开本档
		elif not _pending_site.is_constructing:
			_pending_site = null            # 建好了 → 推进
			_build_i += 1
			_build_cool = 9.0
			return
		else:
			if not is_instance_valid(_pending_builder) or _pending_builder.hp <= 0.0:   # 施工的工人死了→补一个
				var w := _free_worker(b)
				if w != null:
					w.order_build(_pending_site)
					_pending_builder = w
			return
	if _build_cool > 0.0 or _build_i >= BUILD_PLAN.size():
		return
	var e: Dictionary = BUILD_PLAN[_build_i]
	if int(e.get("age", 1)) > _ai_age:   # 该建筑要更高时代 → 等升代（如攻城作坊需3代）
		return
	var key: String = e["key"]
	var cg := int(Defs.get_unit(key).get("cost_gold", 0))
	var cw := int(Defs.get_unit(key).get("cost_wood", 0))
	if not b.faction_can_afford(_guan(), cg, cw):
		return
	var builder := _free_worker(b)
	if builder == null:
		return
	if not b.faction_spend(_guan(), cg, cw):
		return
	var cell: Vector2i = b.map.nearest_open(AI_BASE + e["cell"])
	_pending_site = b.ai_start_construction(key, cell, _guan(), builder)   # 完工/失败前不推进 _build_i
	_pending_builder = builder
	_build_cool = 9.0
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] build %s @%s t=%.0f" % [key, cell, _elapsed])


# 拉一名农民去建造：优先伐木/闲置的(别抓金矿工，金是瓶颈)；实在没有才抓任意非施工工人
func _free_worker(b) -> Unit:
	var fallback: Unit = null
	for w in _guan_workers(b):
		if not is_instance_valid(w) or w._state == Unit.ST_BUILD:
			continue
		if is_instance_valid(w._gather_node) and w._gather_node.res_kind == "gold":
			fallback = w   # 金矿工留作兜底
			continue
		return w
	return fallback


# ---------- 真经济：练兵（钱粮+人口+兵营约束） ----------

func _ai_train(b, delta: float) -> void:
	_train_t -= delta
	if _train_t > 0.0:
		return
	_train_t = float(_diff["train"])
	if _ai_alive_army(b) >= int(_diff["cap"]):
		return
	if not _has_building(b, "barracks"):   # 没兵营就练不出兵——玩家拆了兵营即断兵源
		return
	var pick := _weighted_troop()
	if pick.is_empty():
		return
	if _ai_pop(b) + int(pick["pop"]) > _ai_pop_cap(b):
		return
	if not b.faction_spend(_guan(), int(pick["g"]), int(pick["w"])):
		return
	var src := _building_pos(b, "barracks", AI_BASE + Vector2i(2, 3))
	var cell: Vector2i = b.map.nearest_open(src + Vector2i(randi_range(-1, 1), randi_range(1, 3)))
	var u: Unit = b.spawn_unit(pick["key"], _guan(), b.map.cell_to_world(cell))
	_garrison(u)
	_staged.append(u)


# ---------- 真经济：出将（四技能大将） ----------

func _ai_heroes(b, delta: float) -> void:
	if _hero_diff.is_empty() or _ai_age < 2:   # 英雄需「聚义」代
		return
	_hero_t -= delta
	if _hero_t > 0.0:
		return
	# 到点：满员/人口满 → 等下一轮；钱不够 → 保持到点态、下帧继续尝试(不暂停练兵，避免死锁)
	if _ai_hero_count(b) >= int(_hero_diff["cap"]) or _ai_pop(b) + HERO_POP > _ai_pop_cap(b):
		_hero_t = float(_hero_diff["int"])
		return
	var key: String = HERO_ROSTER[_hero_i % HERO_ROSTER.size()]
	var cost := int(HERO_COST.get(key, 300))
	if not b.faction_can_afford(_guan(), cost, 0):
		return
	b.faction_spend(_guan(), cost, 0)
	_hero_t = float(_hero_diff["int"])
	_hero_i += 1
	var cell: Vector2i = b.map.nearest_open(AI_BASE + Vector2i(randi_range(-3, 0), randi_range(2, 4)))
	var h: Unit = b.spawn_unit(key, _guan(), b.map.cell_to_world(cell))
	# 经济模式英雄技能默认 rank0 不会放招——给敌将自动学技能(主动 rank2、被动 rank1)，
	# 四技能由 Battle._enemy_ability_pass 智能施放；被动加成靠 _recompute 生效。
	for s in range(h.slot_count()):
		h.ability_slots[s]["rank"] = 1 if bool(h.ability_slots[s]["passive"]) else 2
	if h.has_method("_recompute_hero_stats"):
		h._recompute_hero_stats()
	_garrison(h)
	_staged.append(h)
	b.msg("⚔ 官军调来大将【%s】助阵！（四技能）" % h.display_name, 4.0)
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] hero %s @%s t=%.0f slots=%d" % [key, cell, _elapsed, h.slot_count()])


# 攻城：替天行道代 + 有攻城作坊 → 攒造撞车（上限2台）领队拆塔破营
func _ai_siege(b, delta: float) -> void:
	if _ai_age < 3 or not _has_building(b, "siege_workshop"):
		return
	_siege_t -= delta
	if _siege_t > 0.0:
		return
	_siege_t = 28.0
	var rams := 0
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.key == "siege_ram" and u.hp > 0.0:
			rams += 1
	if rams >= 2:   # 撞车只留 2 台领队，不占人口判定（数量已封顶）
		return
	if not b.faction_spend(_guan(), 110, 70):
		return
	var src := _building_pos(b, "siege_workshop", AI_BASE)
	var cell: Vector2i = b.map.nearest_open(src + Vector2i(randi_range(-1, 1), randi_range(1, 3)))
	var u: Unit = b.spawn_unit("siege_ram", _guan(), b.map.cell_to_world(cell))
	_garrison(u)
	_staged.append(u)
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] siege_ram @%s t=%.0f" % [cell, _elapsed])


# ---------- 指挥：成波突击 ----------

func _ai_command(b, delta: float) -> void:
	_push_t -= delta
	_staged = _staged.filter(func(u): return is_instance_valid(u) and u.hp > 0.0)
	if _waves_sent == 0:
		if _push_t <= 0.0 and _staged.size() >= 2:
			_launch_push(b)
		return
	var ready: bool = _staged.size() >= _push_size
	var timed: bool = _push_t <= 0.0 and _staged.size() >= 2
	if ready or timed:
		_launch_push(b)


func _launch_push(b) -> void:
	var pool := _staged.filter(func(u): return is_instance_valid(u) and u.hp > 0.0)
	if pool.is_empty():
		_push_t = float(_diff["pint"])
		return
	var n: int = mini(pool.size(), _push_size)
	var army := pool.slice(0, n)
	# 占山为王：大队去中央聚义点并「守」住它(以点为家，leash 150 把人留在圈内清场)；否则强攻姿态直扑聚义厅
	var koth: bool = _victory == "koth"
	var target: Vector2 = b.map.cell_to_world(KOTH_CELL) if koth else (hall.position if is_instance_valid(hall) else b.map.cell_to_world(HALL))
	for u in army:
		if koth:
			u.stance = Unit.STANCE_DEFEND   # 守点：清掉圈内玩家单位但不远追，保持占领
			u._home = target
			u._has_home = true
			u.order_amove(target + Vector2(randf_range(-60, 60), randf_range(-60, 60)))
		else:
			u.stance = Unit.STANCE_AGGRO
			u._has_home = false
			u.order_amove(target + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	_staged = pool.slice(n)
	_push_t = float(_diff["pint"])
	_push_size = mini(_push_size + int(_diff["grow"]), 44)
	_waves_sent += 1
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] push #%d size=%d reserve=%d next=%.0f" % [_waves_sent, army.size(), _staged.size(), _diff["pint"]])
	b.msg("⚔ 官军第 %d 波压向梁山大寨——共 %d 骑！" % [_waves_sent, army.size()], 4.0)


func _garrison(u: Unit) -> void:
	u.stance = Unit.STANCE_DEFEND
	u._home = _muster
	u._has_home = true


# ---------- 查询助手 ----------

func _guan_workers(b) -> Array:
	var out: Array = []
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.is_worker and u.hp > 0.0:
			out.append(u)
	return out


func _ai_alive_army(b) -> int:
	# 只数作战单位（含大将），不含农民/建筑——否则农民会挤占军队上限
	var n := 0
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and not u.is_building and not u.is_worker and u.hp > 0.0:
			n += 1
	return n


func _ai_hero_count(b) -> int:
	var n := 0
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.is_hero and u.hp > 0.0 and not u.is_building:
			n += 1
	return n


func _ai_pop(b) -> int:
	var n := 0
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and not u.is_building and u.hp > 0.0:
			n += int(u.setup_def.get("pop", 1))
	return n


func _ai_pop_cap(b) -> int:
	var cap := AI_BASE_POP
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.is_building and u.hp > 0.0 and not u.is_constructing:
			cap += int(u.setup_def.get("provides_pop", 0))
	return cap


func _has_building(b, key: String) -> bool:
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.key == key and u.hp > 0.0 and not u.is_constructing:
			return true
	return false


func _building_pos(b, key: String, fallback: Vector2i) -> Vector2i:
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.key == key and u.hp > 0.0:
			return b.map.world_to_cell(u.position)
	return fallback


func _weighted_troop() -> Dictionary:
	var total := 0
	for t in TROOPS:
		total += int(t["wt"])
	var r := randi_range(1, total)
	for t in TROOPS:
		r -= int(t["wt"])
		if r <= 0:
			return t
	return TROOPS[0]


func top_status(b) -> String:
	var nxt := ""
	if _started and is_instance_valid(ai_base):
		nxt = " ｜ 下次突击 %d 秒" % int(ceil(maxf(_push_t, 0.0)))
	# 胜利目标条
	var obj := ""
	if _victory == "regicide":
		var pk := int(_p_king.hp) if (_p_king != null and is_instance_valid(_p_king)) else 0
		var ak := int(_ai_king.hp) if (_ai_king != null and is_instance_valid(_ai_king)) else 0
		obj = "【斩首】宋江血%d / 高俅血%d ｜ " % [pk, ak]
	elif _victory == "koth":
		obj = "【占山为王】控点 你%d / 官军%d（满%d秒胜） ｜ " % [int(_koth_p), int(_koth_a), int(KOTH_WIN)]
	return obj + "AI对战(%s·%d代) 官军 %d兵·农%d·待发%d%s ｜ 大营 %d%% ｜ AI 金%d 木%d 口%d/%d ｜ 你 金%d 木%d 口%d/%d ｜ 聚义厅 %d%%" % [
		String(_diff.get("name", "")), _ai_age, _ai_alive_army(b), _guan_workers(b).size(), _staged.size(), nxt,
		int(ai_base.hp / ai_base.max_hp * 100.0) if (ai_base != null and is_instance_valid(ai_base)) else 0,
		int(b.faction_gold(_guan())), int(b.faction_wood(_guan())), _ai_pop(b), _ai_pop_cap(b),
		b.gold, b.wood, b.used_pop(), b.pop_cap,
		int(hall.hp / hall.max_hp * 100.0) if (hall != null and is_instance_valid(hall)) else 0]
