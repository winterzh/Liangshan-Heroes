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

# 难度：普通开局钱粮、工人数、采集倍率与玩家一致；简单/困难补偿在选局页明示。
# train 仅为下单思考间隔，不代替真实建筑生产时间；age2/age3 仅为开始筹备升代的时点。
#   workers=起手农民；wcap=农民目标数；train=出兵间隔；first/pint=首攻/后续突击间隔；
#   push0/grow=每波规模与递增；cap=同时存活军队上限。
const DIFF := {
	"easy":   {"gather": 1.0, "sg": 150, "sw": 90,  "workers": 5, "wcap": 6, "train": 10.0, "first": 130.0, "pint": 60.0, "push0": 4, "grow": 2, "cap": 12, "age2": 75.0, "age3": 200.0, "name": "简单"},
	"normal": {"gather": 1.0, "sg": 280, "sw": 160, "workers": 5, "wcap": 7, "train": 6.5,  "first": 100.0, "pint": 46.0, "push0": 5, "grow": 2, "cap": 20, "age2": 60.0, "age3": 165.0, "name": "普通"},
	"hard":   {"gather": 1.9, "sg": 320, "sw": 200, "workers": 7, "wcap": 9, "train": 4.5,  "first": 72.0,  "pint": 36.0, "push0": 7, "grow": 3, "cap": 30, "age2": 45.0, "age3": 130.0, "name": "困难"},
}

# 普通兵的经济字段从对应玩家兵表复制；阵营造型、战斗属性和英雄名单仍不同。
const ECONOMY_MIRRORS := {"guan_dao": "liang_dao", "guan_gong": "liang_gong", "guan_qi": "liang_ma"}
const TROOPS := [
	{"key": "guan_dao", "wt": 5},
	{"key": "guan_gong", "wt": 3},
	{"key": "guan_qi", "wt": 2},
]
const AI_BASE_POP := 20       # 与玩家一致，民居完工才增加人口。

# 官军大将（轮番登场，各带四技能；由 _enemy_ability_pass 智能施放 Q/W/E/R）
const HERO_ROSTER := ["hu_yanzhuo", "luan_tingyu", "gao_qiu"]
const HERO_ECONOMY_DEFAULTS := {
	"luan_tingyu": {"cost_gold": 170, "cost_wood": 60, "pop": 3, "train_time": 40.0, "min_age": 1},
	"gao_qiu": {"cost_gold": 240, "cost_wood": 60, "pop": 3, "train_time": 44.0, "min_age": 1},
}
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
	{"key": "market",        "cell": Vector2i(4, -3)},                # 真集市完工后才可兑换资源。
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
var _rebuilding := false         # 当前工地是否为「被拆重建」：完工时不推进主序列
var _waves_sent := 0
var _muster := Vector2.ZERO
var _started := false
var _hero_diff := {}
var _hero_t := 0.0
var _hero_i := 0
var _ai_age := 1            # 只有真实研究队列完成后才能改变。
var _ai_tech_done := {}
var _ai_hp_mult := 1.0
var _ai_atk_mult := 1.0
var _ai_hero_hp_mult := 1.0
var _ai_hero_atk_mult := 1.0
var _ai_hero_progress := {}
var _siege_t := 0.0
var _built: Array = []      # 已建成过的建筑名单 [{key}]：被玩家拆掉 → 重建（原一次性序列「拆一次=永久没了」）
var _defend_t := 0.0        # 回防判定节流
# 胜利条件（占山为王 koth 已移除：守点兵与底层「呆住看门狗」互相拉扯、无法稳定控点）
var _victory := "conquest"
var _p_king: Unit = null
var _ai_king: Unit = null


static func difficulty_rules_text() -> String:
	var lines: Array[String] = []
	for key in ["easy", "normal", "hard"]:
		var d: Dictionary = DIFF[key]
		lines.append(Localize.format_text("%s：官军开局金%d、木%d、%d名工人；采集×%.1f。", [d.name, d.sg, d.sw, d.workers, d.gather]))
	return "\n".join(lines) + "\n" + Localize.format_text("玩家各难度均为金%d、木%d、%d名工人。双方升代、建造、训练都付费并等待；普通兵经济字段相同，阵容与战斗属性并非镜像。", [DIFF.normal.sg, DIFF.normal.sw, DIFF.normal.workers])


static func economy_guide_text() -> String:
	return Localize.text("开局：让工人采金、伐木；观察资源入库后再安排生产。工人来回搬运，仓库能缩短路程。\n人口：训练队列也预占人口，民居完工后才增加上限。取消队列会退还资源。\n生产：聚义厅训练工人与英雄，兵营训练普通兵；同一建筑研究时不能训练。\n配兵：朴刀挡住近身敌人，长枪制骑，弓手在后排输出，骑兵追击远程兵；攻城器需要部队保护。\n练习：先完成一次采集、一座民居、一队士兵，再练习英雄施法。需要观察对手经营时，开启本页的训练情报。")


func is_training_match() -> bool:
	return bool(Campaign.get_meta("rts_training_intel", false))


func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	for key in ECONOMY_MIRRORS:
		var source: Dictionary = defs.get(ECONOMY_MIRRORS[key], {})
		for field in ["cost_gold", "cost_wood", "pop", "train_time", "min_age"]:
			defs[key][field] = source.get(field, 1 if field in ["pop", "min_age"] else 0)
	for key in HERO_ECONOMY_DEFAULTS:
		for field in HERO_ECONOMY_DEFAULTS[key]:
			if not defs[key].has(field): defs[key][field] = HERO_ECONOMY_DEFAULTS[key][field]
		defs[key]["hero_trainable"] = true
		defs[key]["trained_at"] = "hall"


func _producer_keys(bld: Unit) -> Array:
	match bld.key:
		"hall": return ["lou_luo"] + HERO_ROSTER
		"barracks": return ["guan_dao", "guan_gong", "guan_qi"]
		"siege_workshop": return ["siege_ram", "siege_cata"]
	return []


func _queued_count(b, key := "", heroes_only := false) -> int:
	var n := 0
	for u in b.units_of(_guan()):
		if not is_instance_valid(u) or u.hp <= 0.0 or not u.is_building: continue
		for queued_key in u._train_queue:
			if key != "" and queued_key != key: continue
			if heroes_only and not bool(b._defs.get(queued_key, {}).get("hero", false)): continue
			n += 1
	return n


func _queued_pop(b) -> int:
	var n := 0
	for u in b.units_of(_guan()):
		if not is_instance_valid(u) or u.hp <= 0.0 or not u.is_building: continue
		for key in u._train_queue: n += int(b._defs.get(key, {}).get("pop", 1))
	return n


func faction_train_block_reason(b, bld: Unit, key: String) -> String:
	if not is_instance_valid(bld) or bld.hp <= 0.0 or bld.faction != _guan(): return "invalid"
	if bld.is_constructing: return "constructing"
	if bld._research_key != "": return "researching"
	var d: Dictionary = b._defs.get(key, {})
	if d.is_empty() or key not in _producer_keys(bld): return "unsupported"
	if int(d.get("min_age", 1)) > _ai_age: return "age"
	if bool(d.get("hero", false)):
		if b.count_alive(_guan(), key) + _queued_count(b, key) > 0: return "hero_exists"
		var cap := int(HERO_DIFF[_resolve_diff()]["cap"])
		if _ai_hero_count(b) + _queued_count(b, "", true) >= cap: return "hero_cap"
	if _ai_pop(b) + _queued_pop(b) + int(d.get("pop", 1)) > _ai_pop_cap(b): return "population"
	if not b.faction_can_afford(_guan(), int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))): return "resources"
	if bld._train_queue.size() >= 8: return "queue_full"
	return ""


func faction_research_block_reason(b, bld: Unit, key: String) -> String:
	if not is_instance_valid(bld) or bld.hp <= 0.0 or bld.faction != _guan(): return "invalid"
	if bld.is_constructing: return "constructing"
	if bld._research_key != "": return "researching"
	var d: Dictionary = Defs.TECHS.get(key, {})
	if d.is_empty() or key not in bld.setup_def.get("researches", []): return "unsupported"
	if int(d.get("min_age", 1)) > _ai_age: return "age"
	if not bld._train_queue.is_empty(): return "production"
	if _ai_tech_done.has(key): return "done"
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.hp > 0.0 and u._research_key == key: return "in_progress"
	if not b.faction_can_afford(_guan(), int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))): return "resources"
	return ""


func _apply_ai_tech(u: Unit) -> void:
	if not is_instance_valid(u) or u.is_building or u.hp <= 0.0: return
	var hp_ratio := _ai_hp_mult / float(u.get_meta("ai_economy_hp_mult", 1.0))
	var fraction := u.hp / maxf(1.0, u.max_hp)
	if u.is_hero:
		u._recompute_hero_stats()
	else:
		u.max_hp *= hp_ratio
	u.hp = u.max_hp * fraction
	u.set_meta("ai_economy_hp_mult", _ai_hp_mult)


func faction_hero_tech_hp(faction: int) -> float:
	return _ai_hero_hp_mult if faction == _guan() else 1.0


func faction_attack_tech_mult(u: Unit) -> float:
	if u.faction != _guan() or u.is_building or u.is_resource: return 1.0
	return _ai_hero_atk_mult if u.is_hero else _ai_atk_mult


func on_faction_research_done(b, bld: Unit, key: String) -> void:
	if bld.faction != _guan() or _ai_tech_done.has(key): return
	_ai_tech_done[key] = true
	var effect: Dictionary = Defs.TECHS.get(key, {}).get("effect", {})
	_ai_age = maxi(_ai_age, int(effect.get("advance_age", _ai_age)))
	_ai_hp_mult *= float(effect.get("hp_mult", 1.0))
	_ai_atk_mult *= float(effect.get("atk_mult", 1.0))
	if effect.has("advance_age"):
		_ai_hero_hp_mult *= float(effect.get("hp_mult", 1.0))
		_ai_hero_atk_mult *= float(effect.get("atk_mult", 1.0))
	b.faction_gather_mult[_guan()] = float(b.faction_gather_mult.get(_guan(), 1.0)) * float(effect.get("gather_mult", 1.0))
	for u in b.units_of(_guan()): _apply_ai_tech(u)


func on_faction_unit_trained(b, _bld: Unit, u: Unit) -> void:
	if u.is_hero and _ai_hero_progress.has(u.key):
		var pr: Dictionary = _ai_hero_progress[u.key]
		u.restore_progress(pr.level, pr.xp, pr.sp, pr.ranks)
		_ai_hero_progress.erase(u.key)
	_apply_ai_tech(u)
	if u.is_worker:
		var node = _pick_ai_node(b, u, _count_gold_miners(b) < 2)
		if node != null: u.order_gather(node)
	else:
		_garrison(u)
		_staged.append(u)


func on_unit_died(_b, u) -> void:
	if u.faction == _guan() and u.is_hero:
		_ai_hero_progress[u.key] = {"level": u.hero_level, "xp": u.hero_xp, "sp": u.skill_points,
			"ranks": u.ability_slots.map(func(s): return int(s.rank))}


func _producer(b, key: String) -> Unit:
	var best: Unit = null
	for u in b.units_of(_guan()):
		if not is_instance_valid(u) or u.hp <= 0.0 or not u.is_building or u.is_constructing or u._research_key != "": continue
		if key not in _producer_keys(u): continue
		if best == null or u._train_queue.size() < best._train_queue.size(): best = u
	return best


func _resolve_victory() -> String:
	var e := OS.get_environment("VICTORY")
	if e == "conquest" or e == "regicide":
		return e
	var v: String = String(Campaign.victory_mode) if Campaign.get("victory_mode") != null else "conquest"
	return v if (v == "conquest" or v == "regicide") else "conquest"   # 旧存档里的 koth 一律回落到征服


func id() -> String: return "skirmish_ai"
func title() -> String: return "AI 对战"
func subtitle() -> String: return "1v1 · 同规则经济 · 侦察与经营"
func map_w() -> int: return 64
func map_h() -> int: return 64
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(20, 46)

func economy_enabled() -> bool: return true
func hero_start_rank() -> int: return 0   # 1v1：英雄仍走原来的经验升级学技能
func start_age() -> int: return 1          # 1v1 走完整三代进阶（草莽→聚义→替天行道）
func start_gold() -> int: return int(DIFF.normal.sg)
func start_wood() -> int: return int(DIFF.normal.sw)
func base_pop_cap() -> int: return AI_BASE_POP
func fog_enabled() -> bool: return true


func _guan() -> int: return Unit.FACTION_GUAN


func deploy_hint() -> String:
	var goal := Localize.text("守住聚义厅和宋江，击败高俅或摧毁官军大营即胜。") if _resolve_victory() == "regicide" else Localize.text("守住聚义厅，摧毁官军大营即胜。")
	return goal + Localize.text("双方采集资源；建造、训练与升代都付费并等待。骚扰工人、拆毁生产建筑能打断经营；敌军情报需要侦察。点「开战」开始。")


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "官军在对岸扎下大营，亦在屯粮募兵、修楼布防。这一回不是死守待援，而是两家正面较量——比谁攒得快、练得精、打得狠。"},
		{"who": "军令", "key": "narrator", "text": Localize.format_text("【对战】难度：%s。", String(DIFF.get(_resolve_diff(), {}).get("name", "普通"))) + deploy_hint()},
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


func deploy(b) -> void:
	# 玩家方
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, HALL)
	if hall == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	if b.spawn_at("gold_mine", Unit.FACTION_LIANG, P_GOLD) == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	if b.spawn_at("gold_mine", Unit.FACTION_LIANG, P_GOLD2) == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	for c in [Vector2i(21, 51), Vector2i(23, 52), Vector2i(22, 53), Vector2i(24, 53), Vector2i(20, 52),
			Vector2i(9, 41), Vector2i(10, 43), Vector2i(8, 43), Vector2i(11, 41), Vector2i(9, 44)]:
		if b.spawn_at("tree", Unit.FACTION_LIANG, c) == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
	for c in [Vector2i(17, 46), Vector2i(18, 47), Vector2i(17, 48), Vector2i(19, 47), Vector2i(18, 49)]:
		if b.spawn_at("lou_luo", Unit.FACTION_LIANG, c) == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
	if b.spawn_at("liang_dao", Unit.FACTION_LIANG, Vector2i(20, 46)) == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	if b.spawn_at("liang_dao", Unit.FACTION_LIANG, Vector2i(21, 47)) == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return

	# 斩首模式：双方各立一名主帅（宋江 / 高俅），杀掉敌方主帅即胜、自家主帅亡即败
	_victory = _resolve_victory()
	if _victory == "regicide":
		_p_king = b.spawn_at("song_jiang", Unit.FACTION_LIANG, HALL + Vector2i(2, 2))
		if _p_king == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
		_ai_king = b.spawn_at("gao_qiu", _guan(), AI_BASE + Vector2i(-2, 2))
		if _ai_king == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
		_seed_hero(_p_king)   # 玩家主帅也开局带技能(与高俅对等)，否则技能 rank0 + R 锁 6 级太弱
		_seed_hero(_ai_king)

	# 电脑方·官军大营(聚义厅形制·改名·作 AI 卸货点) + 金矿/林木(中立可争夺) + 起手农民 + 守军
	ai_base = b.spawn_at("hall", _guan(), AI_BASE)
	if ai_base == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	ai_base.display_name = "官军大营"
	if b.spawn_at("gold_mine", Unit.FACTION_LIANG, AI_GOLD) == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	if b.spawn_at("gold_mine", Unit.FACTION_LIANG, AI_GOLD2) == null:
		b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
		return
	for c in [Vector2i(51, 21), Vector2i(53, 22), Vector2i(52, 23), Vector2i(54, 19), Vector2i(50, 22),
			Vector2i(53, 24), Vector2i(55, 21), Vector2i(51, 24), Vector2i(54, 23), Vector2i(52, 20)]:
		if b.spawn_at("tree", Unit.FACTION_LIANG, c) == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
	_muster = b.map.cell_to_world(b.map.nearest_open(AI_BASE + Vector2i(-2, 3)))
	var nworkers := int(DIFF[_resolve_diff()]["workers"])
	for i in range(nworkers):
		var wc: Vector2i = b.map.nearest_open(AI_BASE + Vector2i(randi_range(-2, 1), randi_range(2, 4)))
		if b.spawn_unit("lou_luo", _guan(), b.map.cell_to_world(wc)) == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
	for c in [Vector2i(48, 16), Vector2i(49, 17)]:
		var g: Unit = b.spawn_at("guan_dao", _guan(), c)
		if g == null:
			b._gameplay_rng_stop("ENTITY_AI_DEPLOY")
			return
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
	_ai_tech_done.clear()
	_ai_hp_mult = 1.0
	_ai_atk_mult = 1.0
	_ai_hero_hp_mult = 1.0
	_ai_hero_atk_mult = 1.0
	_ai_hero_progress.clear()
	_siege_t = 30.0
	_built.clear()
	_defend_t = 8.0
	_victory = _resolve_victory()
	_assign_ai_workers(b)
	_started = true
	b.msg(Localize.format_text("官军（%s）已在对岸扎营——农民下矿伐木、修寨练兵，先发制人！", String(_diff["name"])), 4.5)


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
	if not b._gameplay_rng_issue.is_empty(): return
	if _check_victory(b, delta):   # 按所选胜利条件判定（征服/斩首/占山为王）
		return
	if not _started:
		return
	_elapsed += delta
	_ai_advance_age(b)
	_ai_workers(b, delta)
	if not b._gameplay_rng_issue.is_empty(): return
	_ai_build(b, delta)
	if not b._gameplay_rng_issue.is_empty(): return
	_ai_train(b, delta)
	if not b._gameplay_rng_issue.is_empty(): return
	_ai_heroes(b, delta)
	if not b._gameplay_rng_issue.is_empty(): return
	_ai_siege(b, delta)
	if not b._gameplay_rng_issue.is_empty(): return
	_ai_defend(b, delta)
	_ai_command(b, delta)


# 到点只产生研究意愿。付费、建筑空闲、研究时间、被拆中断均走真实建筑流程。
func _desired_age_tech() -> String:
	if _ai_age < 2 and _elapsed >= float(_diff.get("age2", 60.0)): return "tech_age2"
	if _ai_age == 2 and _elapsed >= float(_diff.get("age3", 165.0)): return "tech_age3"
	return ""


func _ai_advance_age(b) -> void:
	var key := _desired_age_tech()
	if key == "" or not is_instance_valid(ai_base): return
	b.queue_research(ai_base, key, false)


# 筹备升代时只花超出预算的资源，避免每个下单周期都把研究的钱花光。
# 农民不足三人或重建唯一兵营可用基本救济预算；没有免费钱粮。
func _can_budget(b, gold: int, wood: int, essential := false) -> bool:
	if not b.faction_can_afford(_guan(), gold, wood): return false
	if essential: return true
	var key := _desired_age_tech()
	if key == "" or (is_instance_valid(ai_base) and ai_base._research_key == key): return true
	var tech: Dictionary = Defs.TECHS.get(key, {})
	return b.faction_can_afford(_guan(), gold + int(tech.get("cost_gold", 0)), wood + int(tech.get("cost_wood", 0)))


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
		if not is_instance_valid(w):
			continue
		# 农民避险：被打了就撒腿跑回大营（不再站在矿口挨刀）。到家转闲置后由下面的复采逻辑再派活，
		# 骚扰者若一直蹲点，农民会跑-回-跑地拉扯，至少不白送；AI 的「死了再补」不再是唯一应对。
		if w.recently_hit() and is_instance_valid(ai_base) \
				and w.position.distance_to(ai_base.position) > 140.0 and w._state != Unit.ST_MOVE:
			w.order_move(b.map.cell_to_world(b.map.nearest_open(AI_BASE + Vector2i(randi_range(-1, 1), randi_range(2, 3)))))
			continue
		if w.is_idle_worker():
			var node = _pick_ai_node(b, w, _count_gold_miners(b) < 2)
			if node != null:
				w.order_gather(node)
	# 金矿采空兜底：双方金矿都挖完后，把堆积的木头按集市价折成金（防经济硬死锁）
	_ai_trade_fallback(b)
	_worker_t -= delta
	if _worker_t > 0.0:
		return
	_worker_t = 5.0
	if workers.size() + _queued_count(b, "lou_luo") >= _ai_wcap(b):
		return
	# 留足买兵营/练兵的金子，别把钱全砸在农民上（金是瓶颈）；木紧时放低缓冲优先补伐木工；农民全没了必须重建
	var buf := 40.0 if _ai_wood_short(b) else 130.0
	var definition: Dictionary = b._defs.get("lou_luo", {})
	var cg := int(definition.get("cost_gold", 0))
	var cw := int(definition.get("cost_wood", 0))
	if not workers.is_empty() and b.faction_gold(_guan()) < float(cg) + buf:
		return
	if not _can_budget(b, cg, cw, workers.size() < 3): return
	var producer := _producer(b, "lou_luo")
	if producer != null: b.queue_train(producer, "lou_luo", false)


# 经济兜底（双向·防硬死锁）：
# ① 木荒兜底：缺木而囤金 → 折金成木(100金→70木)，防「有金无木、建造与补伐木工两停」的死锁；
# ② 金矿采空兜底：自家附近已无金矿、缺金而囤木 → 折木成金(100木→70金，同集市价)。
func _ai_trade_fallback(b) -> void:
	if not _has_building(b, "market"): return
	if _ai_wood_short(b) and b.faction_gold(_guan()) >= 220.0:
		if b.faction_spend(_guan(), 100, 0):
			b.add_resources(0, 70, _guan())
		return
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
			if _rebuilding:
				_rebuilding = false         # 重建完工：名单里本就有记录，不追加、不动主序列
			else:
				_built.append({"key": String(_pending_site.key)})   # 记入「已建成」名单：日后被拆即重建
				_build_i += 1
			_pending_site = null            # 建好了 → 推进
			_build_cool = 9.0
			return
		else:
			if not is_instance_valid(_pending_builder) or _pending_builder.hp <= 0.0:   # 施工的工人死了→补一个
				var w := _free_worker(b)
				if w != null:
					w.order_build(_pending_site)
					_pending_builder = w
			return
	if _build_cool > 0.0:
		return
	if _ai_rebuild_missing(b):   # 已建成建筑被毁 → 先补建（兵营被拆不再等于永久断兵）
		return
	if not b._gameplay_rng_issue.is_empty(): return
	if _build_i >= BUILD_PLAN.size():
		return
	var e: Dictionary = BUILD_PLAN[_build_i]
	if int(e.get("age", 1)) > _ai_age:   # 该建筑要更高时代 → 等升代（如攻城作坊需3代）
		return
	var key: String = e["key"]
	var definition: Dictionary = b._defs.get(key, {})
	if int(definition.get("min_age", 1)) > _ai_age: return
	var cg := int(definition.get("cost_gold", 0))
	var cw := int(definition.get("cost_wood", 0))
	if not _can_budget(b, cg, cw, key == "barracks" and not _has_building(b, "barracks")):
		return
	var builder := _free_worker(b)
	if builder == null:
		return
	if not b.faction_spend(_guan(), cg, cw):
		return
	var cell: Vector2i = b.map.nearest_open(AI_BASE + e["cell"])
	_pending_site = b.ai_start_construction(key, cell, _guan(), builder)   # 完工/失败前不推进 _build_i
	if _pending_site == null:
		b.add_resources(cg, cw, _guan())
		return
	_pending_builder = builder
	_rebuilding = false   # 主序列工地：完工时正常推进 _build_i（防上一座重建工地半途被拆留下脏标志）
	_build_cool = 9.0
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] build %s @%s t=%.0f" % [key, cell, _elapsed])


# 已建成过却不在场的建筑 → 补建一座（挑回原计划里同类建筑的格位，nearest_open 自动避让）。
# 返回 true=已开工地（本轮建造额度用掉）。
func _ai_rebuild_missing(b) -> bool:
	if _built.is_empty():
		return false
	var want := {}
	for rec in _built:
		var k := String(rec["key"])
		want[k] = int(want.get(k, 0)) + 1
	var have := {}
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.is_building and not u.is_resource and u.hp > 0.0:
			have[u.key] = int(have.get(u.key, 0)) + 1
	for k in want:
		if int(have.get(k, 0)) >= int(want[k]):
			continue
		var cg := int(b._defs.get(k, {}).get("cost_gold", 0))
		var cw := int(b._defs.get(k, {}).get("cost_wood", 0))
		if not _can_budget(b, cg, cw, k == "barracks" and not _has_building(b, "barracks")):
			continue
		var builder := _free_worker(b)
		if builder == null:
			return false
		var cell: Vector2i = AI_BASE + Vector2i(3, 3)
		for e in BUILD_PLAN:
			if String(e["key"]) == String(k):
				cell = AI_BASE + e["cell"]
				break
		if not b.faction_spend(_guan(), cg, cw):
			return false
		# 记录保留在 _built 里：重建工地若中途被拆，下一轮仍会判定「缺这座」再补（完工分支不重复追加）
		_pending_site = b.ai_start_construction(String(k), b.map.nearest_open(cell), _guan(), builder)
		if _pending_site == null:
			b.add_resources(cg, cw, _guan())
			return false
		_pending_builder = builder
		_rebuilding = true
		_build_cool = 9.0
		if OS.get_environment("SMOKE_TEST") == "1":
			print("[ai] rebuild %s t=%.0f" % [k, _elapsed])
		return true
	return false


# 回防救家：基地圈(400px)里出现成建制的玩家部队(≥3 作战单位) → 把在外的军队按距离就近召回，
# 召回量 = 威胁×2+2（不整军回撤，防「3 人偷家钓走 30 人大部队」的钓鱼战术）。
func _ai_defend(b, delta: float) -> void:
	_defend_t -= delta
	if _defend_t > 0.0:
		return
	_defend_t = 3.0
	if ai_base == null or not is_instance_valid(ai_base):
		return
	var threat := 0
	for u in b.units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building \
				and not u.is_worker and not u.is_resource and u.hp > 0.0 and not u.garrisoned \
				and u.position.distance_to(ai_base.position) < 400.0:
			threat += 1
	if threat < 3:
		return
	var afield: Array = []
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and not u.is_building and not u.is_worker and u.hp > 0.0 \
				and u.position.distance_to(ai_base.position) > 500.0:
			afield.append(u)
	if afield.is_empty():
		return
	afield.sort_custom(func(a, c): return a.position.distance_to(ai_base.position) < c.position.distance_to(ai_base.position))
	var n: int = mini(afield.size(), threat * 2 + 2)
	for i in range(n):
		var u: Unit = afield[i]
		u.stance = Unit.STANCE_AGGRO
		u._has_home = false
		u.order_amove(ai_base.position + Vector2(randf_range(-70, 70), randf_range(-70, 70)))
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] defend! threat=%d recalled=%d t=%.0f" % [threat, n, _elapsed])


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
	if _ai_alive_army(b) + _queued_count(b) - _queued_count(b, "lou_luo") >= int(_diff["cap"]):
		return
	if not _has_building(b, "barracks"):   # 没兵营就练不出兵——玩家拆了兵营即断兵源
		return
	var pick := _weighted_troop()
	if pick.is_empty():
		return
	var key := String(pick["key"])
	var d: Dictionary = b._defs.get(key, {})
	if not _can_budget(b, int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))): return
	var producer := _producer(b, key)
	if producer != null: b.queue_train(producer, key, false)


# ---------- 真经济：出将（四技能大将） ----------

func _ai_heroes(b, delta: float) -> void:
	if _hero_diff.is_empty():
		return
	_hero_t -= delta
	if _hero_t > 0.0:
		return
	# 到点：满员/人口满 → 等下一轮；钱不够 → 保持到点态、下帧继续尝试(不暂停练兵，避免死锁)
	if _ai_hero_count(b) + _queued_count(b, "", true) >= int(_hero_diff["cap"]):
		_hero_t = float(_hero_diff["int"])
		return
	for offset in range(HERO_ROSTER.size()):
		var index := (_hero_i + offset) % HERO_ROSTER.size()
		var key: String = HERO_ROSTER[index]
		if b.count_alive(_guan(), key) + _queued_count(b, key) > 0: continue
		var d: Dictionary = b._defs.get(key, {})
		if not _can_budget(b, int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))): continue
		var producer := _producer(b, key)
		if producer != null and b.queue_train(producer, key, false):
			_hero_t = float(_hero_diff["int"])
			_hero_i = (index + 1) % HERO_ROSTER.size()
			return


# 攻城：替天行道代 + 有攻城作坊 → 攒造撞车（上限2台）领队拆塔破营
func _ai_siege(b, delta: float) -> void:
	if _ai_age < 3 or not _has_building(b, "siege_workshop"):
		return
	_siege_t -= delta
	if _siege_t > 0.0:
		return
	_siege_t = 28.0
	var rams := _queued_count(b, "siege_ram")
	for u in b.units_of(_guan()):
		if is_instance_valid(u) and u.key == "siege_ram" and u.hp > 0.0:
			rams += 1
	if rams >= 2:
		return
	var d: Dictionary = b._defs.get("siege_ram", {})
	if not _can_budget(b, int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))): return
	var producer := _producer(b, "siege_ram")
	if producer != null: b.queue_train(producer, "siege_ram", false)


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
	var target: Vector2 = hall.position if is_instance_valid(hall) else b.map.cell_to_world(HALL)
	for u in army:
		u.stance = Unit.STANCE_AGGRO
		u._has_home = false
		u.order_amove(target + Vector2(randf_range(-80, 80), randf_range(-80, 80)))
	_staged = pool.slice(n)
	_push_t = float(_diff["pint"])
	_push_size = mini(_push_size + int(_diff["grow"]), 44)
	_waves_sent += 1
	if OS.get_environment("SMOKE_TEST") == "1":
		print("[ai] push #%d size=%d reserve=%d next=%.0f" % [_waves_sent, army.size(), _staged.size(), _diff["pint"]])
	if is_training_match():
		b.msg(Localize.format_text("【训练情报】官军第 %d 次突击，共 %d 兵。", [_waves_sent, army.size()]), 4.0)


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
	if not is_training_match():
		var goal := Localize.text("摧毁官军大营；守住聚义厅")
		if _victory == "regicide": goal = Localize.text("击败高俅或破营；保护宋江与聚义厅")
		# 玩家钱粮/预占人口由 HUD 的统一资源条常驻，军令条不再重复挤占手机视野。
		return Localize.format_text("%s · %s", [String(_diff.get("name", DIFF[_resolve_diff()].name)), goal])
	var nxt := ""
	if _started and is_instance_valid(ai_base):
		nxt = Localize.format_text(" ｜ 下次突击 %d 秒", int(ceil(maxf(_push_t, 0.0))))
	# 胜利目标条
	var obj := ""
	if _victory == "regicide":
		var pk := int(_p_king.hp) if (_p_king != null and is_instance_valid(_p_king)) else 0
		var ak := int(_ai_king.hp) if (_ai_king != null and is_instance_valid(_ai_king)) else 0
		obj = Localize.format_text("【斩首】宋江血%d / 高俅血%d ｜ ", [pk, ak])
	return Localize.text("【训练情报】") + obj + Localize.format_text("AI对战(%s·%d代) 官军 %d兵·农%d·待发%d%s ｜ 大营 %d%% ｜ AI 金%d 木%d 口%d/%d ｜ 你 金%d 木%d 口%d/%d ｜ 聚义厅 %d%%", [
		String(_diff.get("name", "")), _ai_age, _ai_alive_army(b), _guan_workers(b).size(), _staged.size(), nxt,
		int(ai_base.hp / ai_base.max_hp * 100.0) if (ai_base != null and is_instance_valid(ai_base)) else 0,
		int(b.faction_gold(_guan())), int(b.faction_wood(_guan())), _ai_pop(b), _ai_pop_cap(b),
		b.gold, b.wood, b.used_pop(), b.pop_cap,
		int(hall.hp / hall.max_hp * 100.0) if (hall != null and is_instance_valid(hall)) else 0])
