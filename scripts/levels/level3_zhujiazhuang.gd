extends LevelBase
## 第3关·三打祝家庄（独龙冈·盘陀路）。
## 核心机制【盘陀路】：迷宫外围全是 FOREST 树墙与 CLIFF 壁垒/WATER 水渠，
## 唯有一条 ROAD 安全小道（遇白杨树拐弯）通往庄门；其余岔口是 ROAD 死巷，
## 尽头藏 REEDS 隐蔽伏兵。石秀以技能 shi_xiu_path 沿安全路径逐段点亮（金色高亮），
## 引主力跟进；贸然踏入未点亮的死巷即激活伏兵围攻。
## 破庄门 + 灭祝家三杰(祝龙/祝虎/祝彪)与铁棒栾廷玉 = 胜；主力折损过半 = 败。
## 支线：岔口击败一丈青扈三娘触发「归顺」，她回血转入梁山阵营助战。

const T := GameMap.T

# —— 关键坐标（取自规格 key_locations）——
const DEPLOY_CELL := Vector2i(58, 28)    # 梁山集结区
const ENTRY_CELL := Vector2i(50, 28)     # 盘陀路入口·白杨岔口一
const FORK2_CELL := Vector2i(42, 22)     # 白杨岔口二
const HU_CELL := Vector2i(40, 14)        # 扈三娘遭遇点
const FORK3_CELL := Vector2i(34, 30)     # 白杨岔口三
const GATE_CELL := Vector2i(22, 28)      # 祝家庄门
const COURT_CELL := Vector2i(12, 28)     # 祝家内院
const AMBUSH_A := Vector2i(50, 33)       # 死巷伏兵A
const AMBUSH_B := Vector2i(30, 36)       # 死巷伏兵B

# —— 安全路径节点序列（石秀指路按此逐段点亮；含白杨拐点）——
const SAFE_NODES: Array[Vector2i] = [
	Vector2i(58, 28), Vector2i(51, 28),               # 入口直廊
	Vector2i(50, 28), Vector2i(50, 22),               # 岔口一：遇白杨向北拐
	Vector2i(43, 22), Vector2i(42, 22),               # 抵岔口二
	Vector2i(42, 23), Vector2i(42, 30),               # 岔口二：遇白杨向南折
	Vector2i(35, 30), Vector2i(34, 30),               # 抵岔口三
	Vector2i(34, 29), Vector2i(34, 28),               # 岔口三：遇白杨向西
	Vector2i(23, 28), Vector2i(22, 28),               # 直抵庄门
	Vector2i(12, 28),                                 # 入庄·内院
]

# 每次指路点亮 N 个节点（约 6-8 格）
const LIT_STEP := 4
const LIT_DUR := 14.0

# —— 状态 ——
var gate: Unit
var shi: Unit
var hu: Unit
var start_n := 0                # 开战时玩家作战单位基数
var lit_idx := 0                # 已点亮到的安全节点序号
var amb_a_fired := false
var amb_b_fired := false
var gate_guard_fired := false
var final_wave := false
var hu_engaged := false
var hu_turned := false
var zhao_dead := false
var amb_a: Array = []           # 死巷A 伏兵
var amb_b: Array = []           # 死巷B 伏兵
var hu_escort: Array = []       # 扈家庄客
var gate_guards: Array = []     # 壁垒守军

# 冒烟测试推进
var _sk_t := 0.0                # 指路节流
var _sk_seg := 0                # 已下令推进到的安全节点
var _sk_gate_hit := false
var _sk_final := false
var _sk_log := 0.0


func id() -> String: return "level3"
func title() -> String: return "三打祝家庄"
func subtitle() -> String: return "独龙冈·盘陀路·里应外合"
func map_w() -> int: return 64
func map_h() -> int: return 56
func map_theme() -> String: return "village"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(52, 28)
func deploy_hint() -> String:
	return "盘陀路凶险：选中石秀按技能『指路·遇白杨转弯』点亮前方一段安全小道（金色高亮），引主力跟着走。切勿擅闯未点亮的岔口死巷——白杨树后尽是庄客冷箭！主力折损过半即败。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "独龙冈下，三村连环：祝家庄壁垒森严，扈家庄、李家庄为犄角。庄前一片盘陀路——白杨树为记的迷魂小道，纵横如蛛网，走错一步便陷绝地。宋公明前两打折兵损将，至今未能近庄门一步。"},
		{"who": "石秀", "key": "shi_xiu", "text": "哥哥放心！小弟扮作行脚客，已在庄里盘桓数日，钟离老人说破了关窍——『遇白杨便转弯』，但凡看见白杨树就拐，方是活路；岔道尽是死巷与暗箭。待我在前引路，大军跟定我走的道便万无一失。"},
		{"who": "吴用", "key": "wu_yong", "text": "石秀兄弟探得明白，这盘陀路便不足惧。我已遣孙立等诈降入庄为内应，只待庄门一破，里应外合。三郎，你专一在前指路，大队莫要贪功乱闯岔口——那白杨树后，藏的全是祝家庄客的冷箭。"},
		{"who": "宋江", "key": "song_jiang", "text": "好！传我将令：石秀引路在先，长枪手护两翼防祝家马军，弓手随后压阵。先破了庄门，再擒祝氏父子，与晁天王、众兄弟报仇雪恨！"},
		{"who": "军令", "key": "narrator", "text": "【盘陀路】只有石秀指出的高亮小道安全，岔口踏入死路会惊动伏兵。选中石秀按技能『指路·遇白杨转弯』点亮前方一段安全路径，引主力跟进→破庄门→击败祝家三杰与栾廷玉。主力折损过半即败。"},
	]


# —— 地图：迷宫在外、庄堡在内 ——
func paint_map(map: GameMap) -> void:
	# 田埂农田底子（村庄主题）
	map.fill_rect(0, 0, 64, 56, T.GRASS)
	map.fill_ellipse(Vector2(30, 28), 30, 22, T.FIELD, [T.GRASS])
	# 右侧梁山集结区：开阔草地
	map.fill_rect(52, 18, 12, 20, T.GRASS)
	# 中段盘陀路迷宫：大片树林墙（迷宫主体），随后由 ROAD 安全道与死巷切穿
	map.fill_rect(18, 10, 36, 38, T.FOREST, [T.GRASS, T.FIELD])
	# 庄内（更低 x）：农田 + 内院
	map.fill_rect(4, 16, 16, 26, T.FIELD, [T.FOREST, T.GRASS])
	map.fill_ellipse(Vector2(COURT_CELL.x, COURT_CELL.y), 6, 6, T.PLAZA, [T.FIELD, T.GRASS, T.FOREST])

	# —— 唯一安全 ROAD 路径（沿 SAFE_NODES 蜿蜒，遇白杨拐弯）——
	var pts: Array = []
	for c in SAFE_NODES:
		pts.append(Vector2(c.x, c.y))
	map.paint_path(pts, 0, T.ROAD)
	# 支线小道：岔口二 → 扈三娘遭遇点（可选）
	map.paint_path([Vector2(42, 22), Vector2(40, 18), Vector2(40, 14)], 0, T.ROAD)

	# —— 岔口死巷（ROAD），尽头 REEDS 藏伏兵 ——
	# 死巷A：入口岔口直行/下折，尽头 (50,33)
	map.paint_path([Vector2(50, 28), Vector2(50, 33)], 0, T.ROAD)
	# 死巷B：岔口三直行偏南，尽头 (30,36)
	map.paint_path([Vector2(34, 30), Vector2(32, 33), Vector2(30, 36)], 0, T.ROAD)
	# 再添两条迷惑性死巷增强盘陀感
	map.paint_path([Vector2(42, 22), Vector2(46, 18)], 0, T.ROAD)        # 岔口二误向东北
	map.paint_path([Vector2(34, 30), Vector2(28, 30), Vector2(26, 33)], 0, T.ROAD)  # 岔口三误直西偏南
	# 死巷尽头芦苇伏点
	map.fill_ellipse(Vector2(AMBUSH_A.x, AMBUSH_A.y), 2, 2, T.REEDS)
	map.fill_ellipse(Vector2(AMBUSH_B.x, AMBUSH_B.y), 2, 2, T.REEDS)
	map.fill_ellipse(Vector2(46, 18), 1, 1, T.REEDS)
	map.fill_ellipse(Vector2(26, 33), 1, 1, T.REEDS)
	# 扈三娘遭遇点四周小片树林（巡弋空地）
	map.fill_ellipse(Vector2(HU_CELL.x, HU_CELL.y), 3, 3, T.GRASS, [T.FOREST])

	# —— 庄墙壁垒（CLIFF 不可通行）+ 水渠（WATER）逼大军走盘陀路 ——
	# 庄墙：庄门所在竖墙（x≈20），留出庄门 1x3 缺口（y 27..29）
	for y in range(14, 43):
		if y < 27 or y > 29:
			map.set_cell_t(20, y, T.CLIFF)
			map.set_cell_t(19, y, T.CLIFF)
	# 水渠绕庄墙外侧（庄门外缺口处仍留 ROAD 通过）
	for y in range(14, 43):
		if y < 26 or y > 30:
			map.set_cell_t(21, y, T.WATER)
	# 上下边墙夹合迷宫
	map.fill_rect(18, 8, 36, 2, T.CLIFF)
	map.fill_rect(18, 46, 36, 2, T.CLIFF)


func decorate(map: GameMap) -> void:
	map.decor = [
		# 白杨为记（路标）——立于各拐点旁
		["forest", Vector2i(50, 26), 40.0], ["forest", Vector2i(43, 24), 40.0],
		["forest", Vector2i(40, 30), 40.0], ["forest", Vector2i(34, 26), 40.0],
		["forest", Vector2i(36, 14), 40.0],
		# 庄门与壁垒
		["hall", Vector2i(GATE_CELL.x, GATE_CELL.y), 74.0],
		["tower", Vector2i(20, 24), 60.0], ["tower", Vector2i(20, 32), 60.0],
		# 内院祠堂
		["hall", Vector2i(COURT_CELL.x, COURT_CELL.y - 1), 78.0],
		["banner", Vector2i(10, 26), 50.0], ["banner", Vector2i(14, 30), 50.0],
		# 死巷标记物（迷惑）
		["rocks", Vector2i(50, 34), 44.0], ["rocks", Vector2i(30, 37), 44.0],
		["tent", Vector2i(58, 22), 60.0], ["tent", Vector2i(60, 30), 60.0],
	]


# —— 部署：玩家主力 + 预置隐蔽伏兵 + 庄门 + 庄内据守 ——
func deploy(b) -> void:
	var B: Battle = b
	# 玩家主力（石秀立于队首）
	shi = B.spawn_at("shi_xiu", Unit.FACTION_LIANG, DEPLOY_CELL + Vector2i(-1, 0))
	B.spawn_at("lin_chong", Unit.FACTION_LIANG, DEPLOY_CELL + Vector2i(0, -2))
	B.spawn_at("hua_rong", Unit.FACTION_LIANG, DEPLOY_CELL + Vector2i(1, 2))
	var qi_cells := [Vector2i(0, -3), Vector2i(1, -3), Vector2i(2, -2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 2)]
	for c in qi_cells:
		B.spawn_at("liang_qiang", Unit.FACTION_LIANG, DEPLOY_CELL + c)
	var dao_cells := [Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, -1), Vector2i(2, 0), Vector2i(2, 1)]
	for c in dao_cells:
		B.spawn_at("liang_dao", Unit.FACTION_LIANG, DEPLOY_CELL + c)
	var gong_cells := [Vector2i(3, -2), Vector2i(3, -1), Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 0)]
	for c in gong_cells:
		B.spawn_at("liang_gong", Unit.FACTION_LIANG, DEPLOY_CELL + c)

	# 庄门（目标建筑①）——横亘壁垒缺口
	gate = B.spawn_at("zhu_gate", Unit.FACTION_GUAN, GATE_CELL)

	# —— 死巷伏兵A：reeds 中庄客×3（隐蔽待发）——
	for c in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 1)]:
		var u := B.spawn_at("zhu_keke", Unit.FACTION_GUAN, AMBUSH_A + c)
		u.passive = true
		amb_a.append(u)
	# —— 死巷伏兵B：庄客×2 + 弓手×3（隐蔽待发）——
	for c in [Vector2i(0, 0), Vector2i(1, -1)]:
		var u := B.spawn_at("zhu_keke", Unit.FACTION_GUAN, AMBUSH_B + c)
		u.passive = true
		amb_b.append(u)
	for c in [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var u := B.spawn_at("zhu_gong", Unit.FACTION_GUAN, AMBUSH_B + c)
		u.passive = true
		amb_b.append(u)

	# —— 壁垒守军：庄门两侧庄客×2 + 弓手×2（隐蔽待发，破门前不动）——
	for c in [Vector2i(-1, -3), Vector2i(-1, 3)]:
		var u := B.spawn_at("zhu_keke", Unit.FACTION_GUAN, GATE_CELL + c)
		u.passive = true
		gate_guards.append(u)
	for c in [Vector2i(-2, -2), Vector2i(-2, 2)]:
		var u := B.spawn_at("zhu_gong", Unit.FACTION_GUAN, GATE_CELL + c)
		u.passive = true
		gate_guards.append(u)

	# —— 扈三娘遭遇点：一丈青 + 扈家庄客×2（巡弋待触发）——
	hu = B.spawn_at("hu_sanniang", Unit.FACTION_GUAN, HU_CELL)
	hu.passive = true
	for c in [Vector2i(-1, 1), Vector2i(1, 1)]:
		var u := B.spawn_at("zhu_keke", Unit.FACTION_GUAN, HU_CELL + c)
		u.passive = true
		hu_escort.append(u)

	# —— 庄内据守（破门后冲出；先按兵不动）——
	_deploy_inner(B)


func _deploy_inner(b) -> void:
	var B: Battle = b
	# 祝家三杰 + 栾廷玉 + 祝朝奉 据守内院
	for spec in [["luan_tingyu", Vector2i(17, 28)], ["zhu_long", Vector2i(14, 25)],
			["zhu_hu", Vector2i(14, 31)], ["zhu_biao", Vector2i(10, 28)],
			["zhu_zhaofeng", Vector2i(11, 28)]]:
		var u := B.spawn_at(spec[0], Unit.FACTION_GUAN, spec[1])
		u.passive = true
	# 祝家马军×4
	for c in [Vector2i(16, 24), Vector2i(16, 32), Vector2i(13, 23), Vector2i(13, 33)]:
		var u := B.spawn_at("zhu_qi", Unit.FACTION_GUAN, c)
		u.passive = true
	# 庄内守卫庄客×3
	for c in [Vector2i(15, 27), Vector2i(15, 29), Vector2i(12, 26)]:
		var u := B.spawn_at("zhu_keke", Unit.FACTION_GUAN, c)
		u.passive = true


func on_start(b) -> void:
	var B: Battle = b
	start_n = B.players_alive()      # 21（石秀/林冲/花荣/6长枪/6朴刀/6弓手）
	lit_idx = 0
	# 开战即时：点亮第一段安全小道，立路标提示
	_light_from_shi(B, true)
	B.msg("石秀立于队首，盘陀路入口的白杨岔口亮起金光——选中石秀施放『指路』，引主力沿高亮小道穿过！切勿擅闯岔口死巷。", 6.5)


# —— 关卡自定义技能：石秀指路（沿安全路径逐段点亮）——
func on_ability(b, caster, ability_id: String, _lp: Vector2) -> bool:
	if ability_id != "shi_xiu_path":
		return false
	var B: Battle = b
	_light_from_shi(B, false)
	return true


## 以石秀当前位置匹配安全路径序号，点亮其后 N 个节点；同段重复刷新而不前进。
func _light_from_shi(b, first: bool) -> void:
	var B: Battle = b
	var here := 0
	if not first and is_instance_valid(shi) and shi.hp > 0.0:
		here = _nearest_node_index(B, shi.position)
	# 起点取石秀所处节点（或开战的 0），点亮其后 LIT_STEP 段
	var start_i: int = maxi(here, 0)
	var end_i: int = mini(start_i + LIT_STEP, SAFE_NODES.size() - 1)
	lit_idx = maxi(lit_idx, end_i)
	# 把这段路径上的 road 格逐格点亮（含节点间插值），LIT_DUR 秒高亮
	for i in range(start_i, end_i):
		_light_segment(B, SAFE_NODES[i], SAFE_NODES[i + 1])
	if first:
		B.msg("【指路·遇白杨转弯】前方一段安全小道已点亮（金色）——引主力跟着走。", 4.0)
	else:
		B.msg("【指路·遇白杨转弯】石秀又探明前路，安全小道延伸！", 3.0)


func _light_segment(b, a: Vector2i, c: Vector2i) -> void:
	var B: Battle = b
	var steps: int = maxi(absi(c.x - a.x), absi(c.y - a.y))
	for s in range(steps + 1):
		var t := float(s) / float(maxi(steps, 1))
		var cx := int(round(lerpf(a.x, c.x, t)))
		var cy := int(round(lerpf(a.y, c.y, t)))
		B.lit_cells[Vector2i(cx, cy)] = LIT_DUR
		# 点亮区内我方单位获得短时移速指引（+10%）
		var wp: Vector2 = B.map.cell_to_world(Vector2i(cx, cy))
		for u in B.units_of(Unit.FACTION_LIANG):
			if not u.is_building and u.position.distance_to(wp) < 40.0:
				u.apply_slow(1.1, 4.0)


func _nearest_node_index(b, wpos: Vector2) -> int:
	var B: Battle = b
	var best := 0
	var best_d := INF
	for i in range(SAFE_NODES.size()):
		var d: float = B.map.cell_to_world(SAFE_NODES[i]).distance_to(wpos)
		if d < best_d:
			best_d = d
			best = i
	return best


func process(b, delta: float) -> void:
	var B: Battle = b

	# —— 扈三娘归顺：在其阵亡前拦截（take_damage 一旦把 hp 打到 0 会立刻 died，故提前切阵营）——
	if is_instance_valid(hu) and not hu_turned and hu.faction == Unit.FACTION_GUAN:
		if hu_engaged and hu.hp <= 70.0:
			_hu_defect(B)

	# —— 死巷伏兵触发：任一我方单位踏入未点亮的死巷区即激活 ——
	if not amb_a_fired and _player_near(B, AMBUSH_A, 70.0):
		_fire_ambush(B, amb_a, AMBUSH_A, "盘陀路岔口直行，白杨树后窜出祝家庄客——『中了埋伏！』")
		amb_a_fired = true
	if not amb_b_fired and _player_near(B, AMBUSH_B, 70.0):
		_fire_ambush(B, amb_b, AMBUSH_B, "走错盘陀路！死巷尽头乱箭齐发，祝家弓手伏兵杀出！")
		amb_b_fired = true

	# —— 扈三娘遭遇：主力进入遭遇点 ——
	if not hu_engaged and _player_near(B, HU_CELL, 110.0):
		_engage_hu(B)

	# —— 抵达庄门前：壁垒守军被惊动 ——
	if not gate_guard_fired and _player_near(B, GATE_CELL + Vector2i(2, 0), 130.0):
		_wake_gate_guards(B)

	# —— 破门：庄内三杰与马军杀出（总决战）——
	if not final_wave and is_instance_valid(gate) and gate.hp <= 0.0:
		_break_gate(B)

	# —— 冒烟测试：自动指路 + 逐段推进 → 破门 → 灭三杰，走向胜利 ——
	if B._smoke:
		_smoke_drive(B, delta)

	# —— 胜负判定 ——
	if is_instance_valid(gate) and gate.hp <= 0.0 \
			and not B.hero_alive("zhu_long") and not B.hero_alive("zhu_hu") \
			and not B.hero_alive("zhu_biao") and not B.hero_alive("luan_tingyu"):
		B.win("庄门破，三杰诛，栾廷玉授首——三打祝家庄，里应外合，独龙冈盘陀路终告破！")
		return
	# 主力折损过半（不含归顺后的扈三娘，避免她拉高基数）
	if _core_alive(B) < int(start_n / 2.0):
		B.lose("盘陀路上人马折损过半，伏兵四起，宋公明只得收兵——三打祝家庄，又是一场恶战……")


# —— 死巷伏兵激活：取消隐蔽，向闯入者 attack-move ——
func _fire_ambush(b, mob: Array, gate_cell: Vector2i, line: String) -> void:
	var B: Battle = b
	var tgt: Vector2 = B.map.cell_to_world(gate_cell)
	var intruder := _nearest_player(B, tgt)
	if intruder != null:
		tgt = intruder.position
	for u in mob:
		if is_instance_valid(u) and u.hp > 0.0:
			u.passive = false
			u.order_amove(tgt)
	B.msg(line, 4.5)


func _engage_hu(b) -> void:
	var B: Battle = b
	hu_engaged = true
	var tgt: Vector2 = B.map.cell_to_world(FORK2_CELL)
	var intruder := _nearest_player(B, B.map.cell_to_world(HU_CELL))
	if intruder != null:
		tgt = intruder.position
	for u in [hu] + hu_escort:
		if is_instance_valid(u) and u.hp > 0.0:
			u.passive = false
			u.order_amove(tgt)
	B.msg("一丈青扈三娘率扈家庄客拦路杀来！『梁山草寇，敢近独龙冈？』——击败她或可收得一员猛将。", 5.0)


func _hu_defect(b) -> void:
	var B: Battle = b
	hu_turned = true
	hu.hp = hu.max_hp                 # 回满血（归顺不死）
	hu.faction = Unit.FACTION_LIANG   # 切换为梁山阵营
	hu.passive = false
	hu._target = null                 # 清空仇恨
	hu.heal(1.0)                       # 触发金色辉光刷新
	hu.queue_redraw()
	B.msg("林冲马到擒来，一丈青力穷归降！扈三娘回马反戈——『愿随头领杀入祝家庄！』双刀马军入伙助战。", 5.5)


func _wake_gate_guards(b) -> void:
	var B: Battle = b
	gate_guard_fired = true
	var tgt: Vector2 = B.map.cell_to_world(GATE_CELL + Vector2i(3, 0))
	for u in gate_guards:
		if is_instance_valid(u) and u.hp > 0.0:
			u.passive = false
			u.order_amove(tgt)
	B.msg("壁垒守军惊动！庄门两侧弓手居高放箭，庄客列阵阻门——速破庄门，用花荣弓手压制箭楼！", 5.0)


func _break_gate(b) -> void:
	var B: Battle = b
	final_wave = true
	var rally: Vector2 = B.map.cell_to_world(GATE_CELL + Vector2i(2, 0))
	# 破门首波：栾廷玉率三杰与 4 马军杀出反扑（庄客留作后续，避免一拥而上团灭、给玩家节奏）
	var charge := ["luan_tingyu", "zhu_long", "zhu_hu", "zhu_biao", "zhu_qi"]
	for u in B.units_of(Unit.FACTION_GUAN):
		if u.passive and not u.is_building and u.key in charge:
			u.passive = false
			u.order_amove(rally + Vector2(randf_range(-50, 50), randf_range(-50, 50)))
	# 里应外合：孙立等诈降内应在庄中举火策应，梁山军心大振（回血+短时攻击增益），
	# 复刻「第三打里应外合方破庄」——也给最终决战足够余地。
	for u in B.units_of(Unit.FACTION_LIANG):
		if not u.is_building:
			u.heal(45.0)
			u.apply_temp_atk(1.35, 16.0)
	B.msg("庄门轰然倒塌！庄内火起——孙立等内应反戈策应，里应外合！梁山众兄弟士气大振，杀入庄中。栾廷玉率三杰与马军反扑，总决战！", 6.5)


# —— 工具 ——
func _player_near(b, cell: Vector2i, r: float) -> bool:
	var B: Battle = b
	var wp: Vector2 = B.map.cell_to_world(cell)
	for u in B.units_of(Unit.FACTION_LIANG):
		if not u.is_building and u.position.distance_to(wp) <= r:
			return true
	return false


func _nearest_player(b, wpos: Vector2) -> Unit:
	var B: Battle = b
	var best: Unit = null
	var best_d := INF
	for u in B.units_of(Unit.FACTION_LIANG):
		if u.is_building:
			continue
		var d: float = u.position.distance_to(wpos)
		if d < best_d:
			best_d = d
			best = u
	return best


## 初始作战单位（玩家本队，不含归顺后的扈三娘 — 她 key 为 hu_sanniang，单列排除）
func _core_alive(b) -> int:
	var B: Battle = b
	var n := 0
	for u in B.units_of(Unit.FACTION_LIANG):
		if u.is_building or u.key == "hu_sanniang":
			continue
		n += 1
	return n


# —— 冒烟测试：把关卡推向胜利（拟真：石秀指路→主力沿安全路压向庄门→集火破门→灭三杰）——
func _smoke_drive(b, delta: float) -> void:
	var B: Battle = b
	_sk_log -= delta
	if _sk_log <= 0.0:
		_sk_log = 4.0
		print("[smoke3] core=%d gate=%d guan=%d seg=%d brk=%s hu=%s" % [
			_core_alive(B), (int(gate.hp) if is_instance_valid(gate) else -1),
			B.count_alive(Unit.FACTION_GUAN), _sk_seg, final_wave, hu_turned])
	_sk_t -= delta
	if _sk_t > 0.0:
		return
	_sk_t = 0.8

	# 石秀持续指路（推进高亮 + 给路径上我方移速指引）
	if is_instance_valid(shi) and shi.hp > 0.0 and shi.ability_ready():
		B.cast_ability(shi)

	var players: Array = B.units_of(Unit.FACTION_LIANG)

	# 已破门：远程(花荣+弓手)点名优先英雄速杀，近战散开扑入敌群清扫（不抱团，避开栾廷玉横扫 AoE 团灭），
	# 林冲点名骑将(2x)，技能频放。四目标英雄皆死即胜。
	if is_instance_valid(gate) and gate.hp <= 0.0:
		_sk_final = true
		var focus := _smoke_focus(B)
		var mass: Vector2 = _enemy_center(B)
		var lin := B.find_unit("lin_chong")
		for u in players:
			if u.is_building:
				continue
			if u.is_ranged and focus != null and is_instance_valid(focus):
				u.order_attack(focus, false, true)    # 剧情点名：持续追击硬目标
			elif u == lin and focus != null and is_instance_valid(focus):
				u.order_attack(focus, false, true)    # 林冲咬住目标英雄
			else:
				u.order_amove(mass + Vector2(randf_range(-55, 55), randf_range(-55, 55)))  # 步兵散开清扫
		# 林冲横扫(非指向,自身周围)频放
		if lin != null and lin.ability_ready():
			B.cast_ability(lin)
		# 花荣百步穿杨(指向)直接点名硬目标——170 穿透伤害，加速点掉三杰栾廷玉
		var hr := B.find_unit("hua_rong")
		if hr != null and hr.ability_ready() and focus != null and is_instance_valid(focus):
			B._do_ability(hr, 0, focus.position)
		return

	# 未破门：若已有单位逼近庄门，全军集火破门（庄门 1600 hp，需持续猛攻）
	if _sk_gate_hit or _player_near(B, GATE_CELL + Vector2i(2, 0), 170.0):
		_sk_gate_hit = true
		if is_instance_valid(gate) and gate.hp > 0.0:
			for u in players:
				if not u.is_building:
						u.order_attack(gate, false, true)
			# 破门阶段也放技能清壁垒守军、加速破门
			for hk in ["hua_rong", "lin_chong"]:
				var h := B.find_unit(hk)
				if h != null and h.ability_ready():
					B.cast_ability(h)
		return

	# 进军：沿安全 ROAD 节点逐段推进（贴着石秀点亮的路走，避开死巷 reeds 伏兵），
	# 队首抵达当前目标节点就推进到下一节点，最终汇于庄门前。
	var van: Vector2 = _vanguard_pos(B, players)
	_sk_seg = _nearest_node_index(B, van)
	var next_i: int = mini(_sk_seg + 2, SAFE_NODES.size() - 2)   # 看向前方两节点，保持队形跟进
	var dest: Vector2 = B.map.cell_to_world(SAFE_NODES[next_i])
	for u in players:
		if u.is_building:
			continue
		u.order_amove(dest + Vector2(randf_range(-26, 26), randf_range(-26, 26)))


## 队首（最靠近庄门的我方单位）位置——用于显示推进进度
func _vanguard_pos(b, players: Array) -> Vector2:
	var B: Battle = b
	var gate_w: Vector2 = B.map.cell_to_world(GATE_CELL)
	var best := DEPLOY_CELL
	var best_pos: Vector2 = B.map.cell_to_world(DEPLOY_CELL)
	var best_d := INF
	for u in players:
		if u.is_building:
			continue
		var d: float = u.position.distance_to(gate_w)
		if d < best_d:
			best_d = d
			best_pos = u.position
	return best_pos


func _enemy_center(b) -> Vector2:
	var B: Battle = b
	var sum := Vector2.ZERO
	var n := 0
	for u in B.units_of(Unit.FACTION_GUAN):
		if u.is_building:
			continue
		sum += u.position
		n += 1
	if n == 0:
		return B.map.cell_to_world(COURT_CELL)
	return sum / float(n)


func _smoke_focus(b) -> Unit:
	var B: Battle = b
	# 优先序：先点掉攻击光环(祝虎)与远程精英(祝彪)削弱敌方持续输出，
	# 再清骑将祝龙，最后啃硬肉盾栾廷玉——四目标皆为胜利必杀对象。
	for k in ["zhu_hu", "zhu_biao", "zhu_long", "luan_tingyu"]:
		var u := B.find_unit(k)
		if u != null:
			return u
	# 四目标皆灭：扫荡残敌（最近优先，加速结束战斗）
	var best: Unit = null
	var best_d := INF
	var ref: Vector2 = B.map.cell_to_world(GATE_CELL)
	for u in B.units_of(Unit.FACTION_GUAN):
		if u.is_building:
			continue
		var d: float = u.position.distance_to(ref)
		if d < best_d:
			best_d = d
			best = u
	return best


func on_unit_died(b, u) -> void:
	var B: Battle = b
	if u.faction == Unit.FACTION_GUAN:
		if u.key == "zhu_zhaofeng" and not zhao_dead:
			zhao_dead = true
			B.msg("祝家庄主祝朝奉殁于内院，庄客士气崩溃，四散奔逃！", 4.5)
		elif u.key == "luan_tingyu":
			B.msg("铁棒教师栾廷玉力战身亡——祝家庄再无中流砥柱！", 4.0)
		elif u.key in ["zhu_long", "zhu_hu", "zhu_biao"]:
			B.msg("%s 授首！祝家三杰又折一员。" % u.display_name, 3.5)
	else:
		if u.key == "shi_xiu":
			B.msg("石秀阵亡！盘陀路再无人指引——大军务必谨守已点亮的高亮小道！", 5.0)
		elif u.is_hero and u.key != "hu_sanniang":
			B.msg("%s 阵亡了！" % u.display_name, 4.0)


func top_status(b) -> String:
	var B: Battle = b
	var heroes := 0
	for k in ["zhu_long", "zhu_hu", "zhu_biao", "luan_tingyu"]:
		if B.hero_alive(k):
			heroes += 1
	var gate_pct := 0
	if is_instance_valid(gate):
		gate_pct = int(gate.hp / gate.max_hp * 100.0)
	var phase_txt := "盘陀路·指路突进" if not final_wave else "破门·总决战"
	var hu_txt := " | 一丈青已归顺" if hu_turned else ""
	return "三打祝家庄 | %s | 庄门 %d%% | 三杰栾廷玉残 %d/4 | 主力 %d/%d%s | 歼敌 %d" % [
		phase_txt, gate_pct, heroes, _core_alive(B), start_n, hu_txt, B.kills]
