extends LevelBase
## 第4关·大破连环马。呼延灼率连环马（铁环连缀、成排冲锋）征剿梁山，正面平原硬拼必败。
## 三段式：①守阵——长枪堵口、英雄续命，借西/南芦苇沼泽卸力，顶过两波连锁冲锋；
## ②授艺——汤隆赚得金枪手徐宁，引钩镰枪手来援并“教授钩镰枪法”，全军钩镰枪手破甲强化
##   (bonus_vs_cav 3.5 → 6.0)；③破阵——把连环马诱入西/南芦苇陷地减速散阵，钩镰枪手专钩马腿
##   逐排清剿，最后围杀双鞭呼延灼（残血迫降）。
## 机制完全复用现有引擎：连环马=高hp/高速cavalry；克制=bonus_vs_cav（unit.gd:342-343）；
## 散阵=GameMap.speed_mult_at 对 GUAN 在 reeds/marsh 返回 0.5；授艺=遍历 units 抬高 bonus_vs_cav。

const T := GameMap.T

const JIANGTAI_CELL := Vector2i(16, 30)   # 中军帅旗（将台），守护核心，被毁=败
const GATE_E := Vector2i(57, 24)          # 东路连环马入口·甲（一、三波）
const GATE_S := Vector2i(57, 44)          # 东南连环马入口·乙（二波及呼延灼）
const XU_IN := Vector2i(14, 42)           # 徐宁援军入场点（西南芦苇）
const REED_W := Vector2i(24, 30)          # 西芦苇陷地（主诱杀场）
const REED_S := Vector2i(34, 42)          # 南翼沼泽陷地

# 梁山初始缓冲阵线（草地/芦苇交界 x28-34）
const START_ARMY := [
	["song_jiang", Vector2i(28, 30)], ["wu_yong", Vector2i(27, 32)],
	["lin_chong", Vector2i(33, 29)], ["hua_rong", Vector2i(28, 27)],
	["liang_qiang", Vector2i(33, 27)], ["liang_qiang", Vector2i(34, 29)],
	["liang_qiang", Vector2i(34, 31)], ["liang_qiang", Vector2i(33, 33)],
	["liang_qiang", Vector2i(32, 25)], ["liang_qiang", Vector2i(32, 35)],
	["liang_dao", Vector2i(31, 28)], ["liang_dao", Vector2i(31, 30)],
	["liang_dao", Vector2i(31, 32)], ["liang_dao", Vector2i(30, 34)],
	["liang_gong", Vector2i(29, 26)], ["liang_gong", Vector2i(29, 29)],
	["liang_gong", Vector2i(28, 33)], ["liang_gong", Vector2i(27, 36)],
]

# 援军授艺后钩镰枪手对连环马的破甲伤害倍率（DEF 基础 3.5 → 6.0）
const DRILL_BONUS := 6.0

enum { HOLD1, HOLD2, RESCUE, FINAL }

var jiangtai: Unit
var hu: Unit = null
var st := HOLD1
var wave_t := 0.0
var event_t := 0.0
var drilled := false             # 徐宁是否已授艺
var reinforced := false          # 援军是否已入场
var rescue_triggered := false    # 第二波结束/帅旗破60% → 触发援军剧情
var _wave_cleared_to_next := false  # HOLD2 子状态：是否已放出第二波
var final_spawned := false
var smoke_pushed := false
var smoke_attack_t := 0.0

# 已歼连环马计（总 24）
var lhm_total := 24
var lhm_killed := 0


func id() -> String: return "level4"
func title() -> String: return "大破连环马"
func subtitle() -> String: return "钩镰枪法·专砍马腿"
func map_w() -> int: return 60
func map_h() -> int: return 60
func map_theme() -> String: return "plain"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(31, 30)
func deploy_hint() -> String:
	return "切勿在平原硬拼连环马！长枪手堵正面、英雄技能续命，背靠西/南芦苇沼泽（骑兵入此减速一半、阵脚散乱）。顶过两波后徐宁会带钩镰枪手来援授艺。妥当后点「开战」。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "汝宁郡都统制、双鞭呼延灼，奉高太尉钧旨征讨梁山。麾下三千连环甲马，三十骑为一连，铁环锁定、人马披甲，冲锋时如铁壁推来，一线压平。梁山步军当其锋，一冲即溃，折损惨重……"},
		{"who": "宋江", "key": "song_jiang", "text": "这连环马端的厉害！弟兄们的朴刀砍在马甲上火星直冒，枪也戳不透。再这般硬拼，梁山泊危矣——军师，可有破敌良策？"},
		{"who": "吴用", "key": "wu_yong", "text": "硬撼不得，须以智取。其阵贵在‘连’与‘快’：连则不可分，快则不可挡。我等先据守拖住它两阵，再引它入西边芦苇泥淖——马陷烂泥，铁环自乱、其势顿散。只是要破马甲、断马腿，还须一件利器、一个能人。"},
		{"who": "汤隆", "key": "narrator", "text": "军师所言极是！小弟汤隆，祖传打铁手艺，识得一物名唤‘钩镰枪’，枪头带钩，专钩马腿——正破连环马！我那表兄金枪手徐宁，使的便是这钩镰枪法，天下无双。待我修书赚他上山，教演众军，管教呼延灼有来无回！"},
		{"who": "军令", "key": "narrator", "text": "【守阵阶段】先顶住连环马前两波冲锋（切勿在平原硬拼，退守芦苇陷地边缘、长枪堵口、技能续命）。徐宁与钩镰枪手抵达并‘授艺’后，把连环马诱入西侧芦苇沼泽减速散阵，以钩镰枪手专钩马腿、逐排剿杀，最后围杀呼延灼。"},
	]


func paint_map(map: GameMap) -> void:
	# —— 底子：开阔平原决战场（plain）——
	map.fill_rect(0, 0, 60, 60, T.PLAIN)
	# 中部偏东一大片平坦草地/夯土场：连环马的“主场”，正面利于连锁冲锋
	map.fill_ellipse(Vector2(40, 30), 22, 18, T.GRASS)
	# 东面两条夯土大道（连环马成排压入的冲锋通道）
	map.paint_path([Vector2(59, 24), Vector2(50, 25), Vector2(42, 28), Vector2(34, 30)], 1, T.ROAD)
	map.paint_path([Vector2(59, 44), Vector2(50, 42), Vector2(42, 38), Vector2(35, 34)], 1, T.ROAD)

	# —— 西半部 + 南翼：大片芦苇(reeds)+沼泽(marsh)陷地（破阵场，GUAN/骑兵减速 50%）——
	# 西芦苇陷地（主诱杀场）
	map.fill_ellipse(Vector2(REED_W.x, REED_W.y), 13, 13, T.MARSH)
	map.fill_ellipse(Vector2(REED_W.x, REED_W.y), 10, 10, T.REEDS, [T.MARSH])
	# 南翼沼泽陷地（次诱杀场 / 伏击位）
	map.fill_ellipse(Vector2(REED_S.x, REED_S.y), 10, 7, T.MARSH)
	map.fill_ellipse(Vector2(REED_S.x, REED_S.y), 7, 5, T.REEDS, [T.MARSH])
	# 西南援军入场处的芦苇通道
	map.fill_ellipse(Vector2(XU_IN.x, XU_IN.y), 5, 4, T.REEDS, [T.MARSH, T.GRASS, T.PLAIN])
	# 芦苇荡里再散一些更密的芦苇做隐蔽伏点
	map.scatter(T.MARSH, T.REEDS, 5)

	# —— 缓冲阵线：草地与芦苇交界（x28-34），好汉初始列阵处 ——
	map.fill_ellipse(Vector2(31, 30), 5, 5, T.GRASS, [T.REEDS, T.MARSH])

	# —— 中军帅旗（将台）：复用建筑占地，坐落西侧草地，周围铺 HALL 实心地基 ——
	for y in range(JIANGTAI_CELL.y - 1, JIANGTAI_CELL.y + 2):
		for x in range(JIANGTAI_CELL.x - 1, JIANGTAI_CELL.x + 2):
			map.set_cell_t(x, y, T.GRASS)
	map.set_cell_t(JIANGTAI_CELL.x, JIANGTAI_CELL.y, T.HALL)


func decorate(map: GameMap) -> void:
	map.decor = [
		["banner", Vector2i(JIANGTAI_CELL.x, JIANGTAI_CELL.y - 1), 70.0],
		["banner", Vector2i(JIANGTAI_CELL.x - 2, JIANGTAI_CELL.y + 1), 52.0],
		["tower", Vector2i(18, 28), 70.0], ["tower", Vector2i(15, 33), 70.0],
		["rocks", Vector2i(REED_W.x, REED_W.y + 2), 48.0], ["rocks", Vector2i(26, 24), 44.0],
		["rocks", Vector2i(REED_S.x, REED_S.y), 46.0],
		["tent", Vector2i(57, 22), 66.0], ["tent", Vector2i(58, 25), 66.0],
		["tent", Vector2i(57, 43), 66.0], ["tent", Vector2i(58, 46), 66.0],
		["banner", Vector2i(54, 24), 50.0], ["banner", Vector2i(54, 44), 50.0],
	]


func deploy(b) -> void:
	var B: Battle = b
	# 中军帅旗（将台）：守护核心，被毁=败。用 FACTION_LIANG 建筑。
	jiangtai = B.spawn_at("jiangtai", Unit.FACTION_LIANG, JIANGTAI_CELL)
	jiangtai.display_name = "中军帅旗"
	# 梁山初始阵线
	for e in START_ARMY:
		B.spawn_at(e[0], Unit.FACTION_LIANG, e[1])


func on_start(b) -> void:
	var B: Battle = b
	st = HOLD1
	wave_t = 6.0
	event_t = 0.0
	drilled = false
	reinforced = false
	rescue_triggered = false
	final_spawned = false
	lhm_killed = 0
	hu = null
	B.msg("战鼓如雷——呼延灼连环马阵自东面平原压来！切勿在平原硬拼，长枪堵口、退守芦苇！", 6.0)


# —— 成排连锁冲锋：3-4 骑一排、相邻同向 attack-move，呈“连环”视觉 ——
func _spawn_lhm_rows(b, n: int, gate: Vector2i, rows := 3) -> Array:
	var B: Battle = b
	var out: Array = []
	var target_w: Vector2 = B.map.cell_to_world(JIANGTAI_CELL)
	var per := int(ceil(float(n) / float(rows)))
	var made := 0
	for r in range(rows):
		if made >= n:
			break
		# 一排沿垂直于冲锋方向横向铺开，整排同向 attack-move
		for k in range(per):
			if made >= n:
				break
			var off := Vector2i(r * 2, (k - per / 2) * 2)   # 排间隔 + 排内横向间隔
			var cell: Vector2i = B.map.nearest_open(gate + off)
			var u: Unit = B.spawn_unit("lian_huan_ma", Unit.FACTION_GUAN, B.map.cell_to_world(cell))
			u.order_amove(target_w + Vector2(randf_range(-40, 40), randf_range(-40, 40)))
			out.append(u)
			made += 1
	return out


func process(b, delta: float) -> void:
	var B: Battle = b

	# —— 帅旗 / 全军覆没：败北判定 ——
	if not is_instance_valid(jiangtai) or jiangtai.hp <= 0.0:
		B.lose("中军帅旗被连环马冲毁，将台倾覆——梁山军心溃散……")
		return
	if B.players_alive() == 0:
		B.lose("梁山可动兵马尽数折损，连环马踏平了营盘……")
		return

	match st:
		HOLD1:
			wave_t -= delta
			if wave_t <= 0.0:
				_spawn_wave1(B)
				st = HOLD2
				wave_t = 45.0   # 兜底：约 45 秒后或第一波清剿即上二波
		HOLD2:
			wave_t -= delta
			# 第一波清剿/退却 或 约 45 秒 → 第二波
			if not _wave_cleared_to_next and (_lhm_alive(B) == 0 or wave_t <= 0.0):
				_spawn_wave2(B)
				_wave_cleared_to_next = true
				event_t = 0.0
			# 二波结束 或 帅旗血量首跌破 60% → 援军剧情
			if _wave_cleared_to_next and not rescue_triggered:
				event_t += delta
				var hall_low := jiangtai.hp <= jiangtai.max_hp * 0.60
				if hall_low or _lhm_alive(B) == 0 or event_t > 40.0:
					_trigger_rescue(B)
		RESCUE:
			# 授艺事件后约 12 秒 → 末波
			event_t += delta
			if not final_spawned and event_t > 12.0:
				_spawn_final(B)
		FINAL:
			_check_victory(B)

	# —— 冒烟自测：把关卡推向胜利（不让主帅送死）——
	if B._smoke:
		_smoke_drive(B, delta)


# —— 第一波：8×连环马（东路成排）+ 2×官军弓手 ——
func _spawn_wave1(b) -> void:
	var B: Battle = b
	B.msg("【连环马·首阵】成排重甲铁骑自东路碾来！朴刀枪戳不透马甲——别在平原接战，引它们入芦苇！", 6.0)
	_spawn_lhm_rows(B, 8, GATE_E, 3)
	B.spawn_group("guan_gong", 2, Unit.FACTION_GUAN, GATE_E + Vector2i(-2, 2), B.map.cell_to_world(JIANGTAI_CELL))


# —— 第二波：8×连环马（东南为主）+ 韩滔 + 2×官军弓手 ——
func _spawn_wave2(b) -> void:
	var B: Battle = b
	B.msg("【连环马·二阵】百胜将韩滔领冲，自东南夹击！阵线告急——撑住，徐宁就快到了！", 6.0)
	_spawn_lhm_rows(B, 6, GATE_S, 2)
	_spawn_lhm_rows(B, 2, GATE_E, 1)
	var ht: Unit = B.spawn_unit("han_tao", Unit.FACTION_GUAN, B.map.cell_to_world(B.map.nearest_open(GATE_S + Vector2i(-1, 0))))
	ht.order_amove(B.map.cell_to_world(JIANGTAI_CELL))
	B.spawn_group("guan_gong", 2, Unit.FACTION_GUAN, GATE_S + Vector2i(-2, -2), B.map.cell_to_world(JIANGTAI_CELL))


# —— 援军 + 授艺 ——
func _trigger_rescue(b) -> void:
	var B: Battle = b
	rescue_triggered = true
	reinforced = true
	st = RESCUE
	event_t = 0.0
	B.msg("西南芦苇喊声大震——汤隆赚得金枪手徐宁上山，引钩镰枪手杀到！", 6.0)
	# 援军入场：徐宁 + 汤隆 + 8×钩镰枪手（西南芦苇方向）
	var spots := [
		["xu_ning", Vector2i(14, 42)], ["tang_long", Vector2i(13, 43)],
		["gou_lian", Vector2i(15, 41)], ["gou_lian", Vector2i(15, 43)],
		["gou_lian", Vector2i(16, 40)], ["gou_lian", Vector2i(16, 42)],
		["gou_lian", Vector2i(14, 40)], ["gou_lian", Vector2i(17, 41)],
		["gou_lian", Vector2i(17, 43)], ["gou_lian", Vector2i(13, 41)],
	]
	for s in spots:
		B.spawn_at(s[0], Unit.FACTION_LIANG, s[1])
	# 当场“教授钩镰枪法”：全军钩镰枪手破甲强化（bonus_vs_cav → 6.0）
	_apply_drill(B)


# 授艺：把所有在场（及标记后续）钩镰枪手对连环马伤害抬高
func _apply_drill(b) -> void:
	var B: Battle = b
	drilled = true
	var n := 0
	for u in B.units_of(Unit.FACTION_LIANG, "gou_lian"):
		u.bonus_vs_cav = DRILL_BONUS
		n += 1
	# 徐宁亲授，自身对连环马也更狠
	var xu := B.find_unit("xu_ning")
	if xu != null:
		xu.bonus_vs_cav = maxf(xu.bonus_vs_cav, 4.0)
	B.msg("徐宁授艺！钩镰枪法·专钩马腿——将连环马引入西侧芦苇陷地减速散阵，逐排钩杀！", 6.5)


# —— 末波：呼延灼 + 8×连环马 + 彭玘 + 2×官军弓手 ——
func _spawn_final(b) -> void:
	var B: Battle = b
	final_spawned = true
	st = FINAL
	B.msg("【末波】双鞭呼延灼亲率残余连环马与彭玘压上！诱它们入芦苇散阵，钩镰枪逐排放倒，围杀呼延灼！", 7.0)
	var spawned := _spawn_lhm_rows(B, 8, GATE_S, 3)
	hu = B.spawn_unit("hu_yanzhuo", Unit.FACTION_GUAN, B.map.cell_to_world(B.map.nearest_open(GATE_S + Vector2i(0, -1))))
	hu.order_amove(B.map.cell_to_world(JIANGTAI_CELL))
	var pq: Unit = B.spawn_unit("peng_qi", Unit.FACTION_GUAN, B.map.cell_to_world(B.map.nearest_open(GATE_E + Vector2i(0, 1))))
	pq.order_amove(B.map.cell_to_world(JIANGTAI_CELL))
	B.spawn_group("guan_gong", 2, Unit.FACTION_GUAN, GATE_S + Vector2i(-2, 2), B.map.cell_to_world(JIANGTAI_CELL))


func _lhm_alive(b) -> int:
	var B: Battle = b
	return B.count_alive(Unit.FACTION_GUAN, "lian_huan_ma")


# —— 胜利结算：连环马全灭 且 呼延灼死亡或残血迫降（≤15%）——
func _check_victory(b) -> void:
	var B: Battle = b
	if not final_spawned:
		return
	var lhm := _lhm_alive(B)
	var hu_dead := not is_instance_valid(hu) or hu.hp <= 0.0
	var hu_yield := is_instance_valid(hu) and hu.hp > 0.0 and hu.hp <= hu.max_hp * 0.15
	if lhm == 0 and (hu_dead or hu_yield):
		if hu_yield:
			B.win("连环马连锁尽断、铁骑散作一地；呼延灼力穷，跪鞭请降——大破连环马！")
		else:
			B.win("连环马尽数钩翻，双鞭呼延灼亦死于乱军之中——大破连环马！")


# —— 冒烟自测：拟真地把关卡推向胜利路径 ——
func _smoke_drive(b, delta: float) -> void:
	var B: Battle = b
	smoke_attack_t -= delta
	# 守阵两段：让长枪/朴刀/英雄迎击连环马（主帅吴用留后放技能，不送死）
	if (st == HOLD1 or st == HOLD2 or st == RESCUE) and smoke_attack_t <= 0.0:
		smoke_attack_t = 2.5
		var targ := _nearest_enemy_world(B, B.map.cell_to_world(JIANGTAI_CELL))
		for u in B.units_of(Unit.FACTION_LIANG):
			if u.is_building:
				continue
			# 主帅宋江、军师吴用、花荣远程留在帅旗附近放光环/输出，不前压
			if u.key in ["song_jiang", "wu_yong", "hua_rong"]:
				continue
			u.order_amove(targ)
		# 英雄放技能续命/清场
		_smoke_cast(B, "lin_chong")
		_smoke_cast(B, "song_jiang")
		_smoke_cast(B, "wu_yong")
	# 末波：钩镰枪手 + 徐宁专钩连环马、围杀呼延灼
	if st == FINAL and smoke_attack_t <= 0.0:
		smoke_attack_t = 2.0
		# 先清连环马，再扑呼延灼
		var foe: Vector2
		if _lhm_alive(B) > 0:
			foe = _nearest_enemy_world(B, B.map.cell_to_world(REED_W), "lian_huan_ma")
		elif is_instance_valid(hu) and hu.hp > 0.0:
			foe = hu.position
		else:
			foe = _nearest_enemy_world(B, B.map.cell_to_world(JIANGTAI_CELL))
		for u in B.units_of(Unit.FACTION_LIANG):
			if u.is_building or u.key in ["song_jiang", "wu_yong"]:
				continue
			u.order_amove(foe)
		_smoke_cast(B, "xu_ning")
		_smoke_cast(B, "lin_chong")
		_smoke_cast(B, "hua_rong")
		_smoke_cast(B, "song_jiang")
		_smoke_cast(B, "wu_yong")


func _smoke_cast(b, key: String) -> void:
	var B: Battle = b
	var u := B.find_unit(key)
	if u != null and u.ability != "" and u.ability_ready():
		# 仅瞬发技能直接放（指向技 _do_ability 用 caster.position 兜底也安全）
		B.cast_ability(u)


func _nearest_enemy_world(b, fallback: Vector2, key := "") -> Vector2:
	var B: Battle = b
	var best: Unit = null
	var best_d := INF
	for u in B.units_of(Unit.FACTION_GUAN, key):
		if u.is_building:
			continue
		var d: float = u.position.distance_to(fallback)
		if d < best_d:
			best_d = d
			best = u
	return best.position if best != null else fallback


func on_unit_died(b, u) -> void:
	var B: Battle = b
	if u.faction == Unit.FACTION_GUAN:
		if u.key == "lian_huan_ma":
			lhm_killed += 1
			if lhm_killed == lhm_total:
				B.msg("连环马 24 骑尽数钩翻、铁环连锁俱断——只剩呼延灼孤身困阵！", 5.0)
			# 末波阶段每次有连环马倒下都复核胜利
			_check_victory(B)
		elif u == hu or u.key == "hu_yanzhuo":
			_check_victory(B)
	elif u.faction == Unit.FACTION_LIANG and u.is_hero:
		B.msg("%s 中伤倒下了！" % u.display_name, 4.0)


func top_status(b) -> String:
	var B: Battle = b
	var phase_txt := ""
	match st:
		HOLD1: phase_txt = "守阵·首波将至"
		HOLD2: phase_txt = "守阵·顶住连环马冲锋"
		RESCUE: phase_txt = "徐宁授艺！诱敌入芦苇"
		FINAL: phase_txt = "破阵·钩杀连环马·围杀呼延灼"
	var hu_txt := ""
	if final_spawned and is_instance_valid(hu) and hu.hp > 0.0:
		hu_txt = " | 呼延灼 %d%%" % int(hu.hp / hu.max_hp * 100.0)
	var drill_txt := "（钩镰已授艺）" if drilled else ""
	return "大破连环马 | %s%s | 连环马 %d/%d 已歼%s | 帅旗 %d%%" % [
		phase_txt, drill_txt, lhm_killed, lhm_total, hu_txt,
		int(jiangtai.hp / jiangtai.max_hp * 100.0) if is_instance_valid(jiangtai) else 0]
