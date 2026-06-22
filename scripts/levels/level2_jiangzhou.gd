extends LevelBase
## 第2关·江州劫法场（浔阳江畔）。晁盖率花荣、李逵、戴宗、张顺、燕顺等好汉混入江州，
## 趁午时三刻行刑之前劫法场：杀穿十字街口法场官军，冲上刑台解救宋江、戴宗（二人随后入伙可控），
## 再护送全军且战且走，沿江边码头登上张顺接应的快船遁走。
## 限时营救：行刑倒计时悬在头顶；杀光两名刽子手可中断行刑、永久暂停倒计时。

const T := GameMap.T

# ---- 关键坐标（见规格 key_locations）----
const SCAFFOLD := Vector2i(30, 18)   # 法场刑台中心（十字街口北）
const PLAZA_C := Vector2i(30, 24)    # 法场夯土广场中心
const GATE_N := Vector2i(30, 4)      # 北衙门口（蔡九/官军增援）
const GATE_E := Vector2i(54, 24)     # 东街口（官军增援/堵口）
const SPAWN_W := Vector2i(8, 30)     # 好汉自西巷入场
const SPAWN_S := Vector2i(24, 40)    # 好汉自南巷入场
const DOCK_C := Vector2i(10, 50)     # 江边码头中心（登船点）
const YAMEN := Vector2i(30, 8)       # 衙门台阶（蔡九驻立）

const EXEC_TIME := 90.0              # 行刑倒计时（秒，受 time_scale 缩放）
const RESCUE_R := 62.0               # 刑台解救半径
const DOCK_R := 150.0                # 码头登船判定半径

# 我军初始入场阵容（奇兵突袭，开局直接 FIGHT；保留极短布阵）
const START_ARMY := [
	["chao_gai", Vector2i(8, 30)], ["li_kui", Vector2i(9, 31)],
	["hua_rong", Vector2i(7, 29)], ["yan_shun", Vector2i(8, 32)],
	["liang_dao", Vector2i(9, 29)], ["liang_dao", Vector2i(10, 30)],
	["liang_dao", Vector2i(10, 31)], ["liang_gong", Vector2i(7, 31)],
	["liang_gong", Vector2i(6, 30)],
	# 南巷一路
	["liang_dao", Vector2i(24, 40)], ["liang_dao", Vector2i(25, 40)],
	["liang_dao", Vector2i(23, 41)], ["liang_gong", Vector2i(24, 41)],
	["liang_gong", Vector2i(25, 41)],
]

var scaffold: Unit = null
var song_bound: Unit = null
var dai_bound: Unit = null
var cai: Unit = null

var exec_timer := EXEC_TIME
var rescued_song := false
var rescued_dai := false
var wave1_done := false       # 蔡九察觉·街市巡防第一波
var wave2_done := false       # 解救后·堵截封锁波
var wave3_done := false       # 抵达码头·追兵波
var at_dock_started := false
var smoke_phase := 0          # 冒烟自测推进阶段


func id() -> String: return "level2"
func title() -> String: return "江州劫法场"
func subtitle() -> String: return "浔阳江畔·限时劫法场，黑旋风排头砍去"
func map_w() -> int: return 60
func map_h() -> int: return 58
func map_theme() -> String: return "town"
func map_base() -> int: return T.TOWN
func camera_start_cell() -> Vector2i: return Vector2i(28, 26)
func deploy_hint() -> String:
	return "奇兵突袭，刻不容缓！花荣远箭、李逵双斧第一时间扑向刑台前的两名刽子手——只要杀光刽子手便能中断行刑、暂停倒计时。让好汉贴近刑台即可救下宋江、戴宗，再护送全军退至西南江边码头登船遁走。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "江州城浔阳江畔，午时将近。法场刑台之上，宋江、戴宗反绑双手，背插招子；台下刀牢林立，蔡九知府升座监斩。十字街口人山人海，只待那一声炮响，便要开刀问斩……"},
		{"who": "晁盖", "key": "chao_gai", "text": "众兄弟听真！蔡九这厮要害我宋公明性命，今日便是拼了这条命，也要把人抢下刑台！花荣压住街口官军，戴宗、张顺接应水路——黑旋风何在？"},
		{"who": "李逵", "key": "li_kui", "text": "哥哥放心！俺铁牛第一个跳下去，抡起这双板斧排头砍将去，管教那鸟刽子手先吃俺一斧！"},
		{"who": "蔡九知府", "key": "narrator", "text": "午时三刻已到——开刀！哪里来的强人敢劫法场？刀牢手都与我团团围住，一个也走不脱！"},
		{"who": "军令", "key": "narrator", "text": "【限时营救】刑台上刽子手正行刑倒计时！杀穿法场官军，让好汉登上刑台即可解救宋江、戴宗（二人随后变为可控）。再护送全军撤至江边码头登船=胜利。倒计时归零宋江被斩、或好汉全灭=失败。"},
	]


func paint_map(map: GameMap) -> void:
	# 整城以城镇砖地为底（map_base=TOWN）。
	# 浔阳江：西南角一片大水域 + 沿江岸
	map.fill_ellipse(Vector2(6, 52), 16, 10, T.WATER)
	map.fill_rect(0, 48, 60, 10, T.WATER, [T.TOWN])  # 城南临江一带补水
	# 江岸滩涂
	map.fill_ellipse(Vector2(12, 47), 14, 4, T.SHORE, [T.WATER])
	map.fill_rect(0, 45, 30, 3, T.SHORE, [T.TOWN])
	# 法场夯土广场（开阔硬地，等同 road 速度）—— 十字街口核心
	map.fill_ellipse(Vector2(PLAZA_C.x, PLAZA_C.y), 9, 7, T.PLAZA)
	# 刑台四周清出广场地（刑台占 2x2，置 PLAZA 周边）
	map.fill_ellipse(Vector2(SCAFFOLD.x, SCAFFOLD.y), 5, 4, T.PLAZA)
	# 十字主街：南北大街（衙门→刑台→广场→码头方向）与东西街
	map.paint_path([Vector2(GATE_N.x, GATE_N.y), Vector2(30, 12), Vector2(30, 18), Vector2(30, 26), Vector2(30, 34), Vector2(26, 40)], 1, T.ROAD)
	map.paint_path([Vector2(GATE_E.x, GATE_E.y), Vector2(46, 24), Vector2(38, 24), Vector2(30, 24), Vector2(22, 26), Vector2(14, 30)], 1, T.ROAD)
	# 西巷、南巷（好汉入场）通向广场
	map.paint_path([Vector2(SPAWN_W.x, SPAWN_W.y), Vector2(14, 28), Vector2(20, 26), Vector2(26, 25)], 1, T.ROAD)
	map.paint_path([Vector2(SPAWN_S.x, SPAWN_S.y), Vector2(26, 36), Vector2(28, 30), Vector2(30, 26)], 1, T.ROAD)
	# 通往码头的撤退街巷（广场西南 → 江岸码头）
	map.paint_path([Vector2(22, 28), Vector2(18, 34), Vector2(14, 40), Vector2(DOCK_C.x, DOCK_C.y - 2)], 1, T.ROAD)
	# 码头栈道（伸入江面的木栈）
	map.fill_rect(DOCK_C.x - 3, DOCK_C.y - 1, 7, 3, T.DOCK, [T.SHORE, T.WATER])
	map.fill_rect(DOCK_C.x - 1, DOCK_C.y + 1, 3, 3, T.DOCK, [T.WATER])
	# 市井屋舍街区：用 HALL（不可通行）成排堆出街巷迷宫感
	_paint_block(map, 14, 14, 4, 3)
	_paint_block(map, 40, 14, 5, 3)
	_paint_block(map, 42, 30, 5, 4)
	_paint_block(map, 16, 18, 3, 3)
	_paint_block(map, 38, 38, 4, 3)
	_paint_block(map, 6, 36, 3, 3)
	# 衙门台阶区（蔡九驻立的硬地）
	map.fill_rect(YAMEN.x - 3, YAMEN.y - 1, 7, 3, T.PLAZA)


## 成排市井屋舍（不可通行的 HALL 块，构成街巷），但留出已铺的 ROAD/PLAZA
func _paint_block(map: GameMap, x0: int, y0: int, bw: int, bh: int) -> void:
	for y in range(y0, y0 + bh):
		for x in range(x0, x0 + bw):
			var t := map.t_at(x, y)
			if t == T.TOWN or t == T.PLAZA:
				map.set_cell_t(x, y, T.HALL)


func decorate(map: GameMap) -> void:
	map.decor = [
		["hall", Vector2i(SCAFFOLD.x, SCAFFOLD.y), 78.0],          # 刑台
		["tower", Vector2i(YAMEN.x, YAMEN.y), 72.0],               # 衙门
		["banner", Vector2i(31, 22), 50.0], ["banner", Vector2i(29, 22), 50.0],
		["hall", Vector2i(15, 15), 64.0], ["hall", Vector2i(42, 15), 64.0],
		["hall", Vector2i(44, 31), 64.0], ["hall", Vector2i(39, 39), 64.0],
		["boat", Vector2i(DOCK_C.x, DOCK_C.y + 2), 72.0],          # 接应快船
		["bridge", Vector2i(DOCK_C.x, DOCK_C.y), 70.0],            # 码头栈道
		["rocks", Vector2i(4, 44), 48.0], ["rocks", Vector2i(20, 46), 46.0],
		["tent", Vector2i(28, 6), 56.0], ["tent", Vector2i(32, 6), 56.0],
	]


func deploy(b) -> void:
	var B: Battle = b
	# 法场建筑与被绑缚者（FACTION_LIANG 建筑：玩家不会去打自己人，钉在刑台不可动）
	scaffold = B.spawn_at("scaffold", Unit.FACTION_LIANG, SCAFFOLD)
	song_bound = B.spawn_at("song_jiang_bound", Unit.FACTION_LIANG, SCAFFOLD + Vector2i(-1, 0))
	dai_bound = B.spawn_at("dai_zong_bound", Unit.FACTION_LIANG, SCAFFOLD + Vector2i(1, 0))

	# 法场初始守军（已在场，非 spawn 波次）
	# 2 名刽子手贴刑台前
	var zt1 := B.spawn_at("guan_zhanzi", Unit.FACTION_GUAN, SCAFFOLD + Vector2i(-1, 2))
	zt1.passive = true
	var zt2 := B.spawn_at("guan_zhanzi", Unit.FACTION_GUAN, SCAFFOLD + Vector2i(1, 2))
	zt2.passive = true
	# 10 名江州牢子环刑台列阵（充作肉墙）
	var ring := [Vector2i(-3, 1), Vector2i(3, 1), Vector2i(-3, 3), Vector2i(3, 3),
		Vector2i(-2, 4), Vector2i(2, 4), Vector2i(0, 5), Vector2i(-4, 2),
		Vector2i(4, 2), Vector2i(0, 4)]
	for off in ring:
		var lz := B.spawn_at("guan_laozi", Unit.FACTION_GUAN, SCAFFOLD + off)
		lz.passive = true
	# 蔡九知府立于衙门台阶督战（不主动冲锋）
	cai = B.spawn_at("cai_jiu", Unit.FACTION_GUAN, YAMEN)
	cai.passive = true

	# 好汉自西巷、南巷入场（奇兵，开局可操作）
	for e in START_ARMY:
		B.spawn_at(e[0], Unit.FACTION_LIANG, e[1])


func on_start(b) -> void:
	var B: Battle = b
	exec_timer = EXEC_TIME
	rescued_song = false
	rescued_dai = false
	wave1_done = false
	wave2_done = false
	wave3_done = false
	at_dock_started = false
	smoke_phase = 0
	# 张顺自江中浮出码头接应（一开始便在码头水边接应）
	var zs := B.spawn_at("zhang_shun", Unit.FACTION_LIANG, DOCK_C + Vector2i(-2, 1))
	zs.passive = true
	B.msg("午时将近——杀上刑台救下宋公明、戴院长！先取那两名刽子手中断行刑！", 6.0)


func process(b, delta: float) -> void:
	var B: Battle = b

	# ---- 1) 行刑倒计时：仅在未救出宋江、且仍有刽子手在场时递减 ----
	var zhanzi := B.count_alive(Unit.FACTION_GUAN, "guan_zhanzi")
	if not rescued_song:
		if zhanzi > 0:
			exec_timer = maxf(0.0, exec_timer - delta)
			if exec_timer <= 0.0:
				B.lose("午时三刻已过，刽子手手起刀落——宋公明人头落地，劫法场功亏一篑……")
				return
		# zhanzi==0：行刑被打断，倒计时冻结（不递减）——为玩家争取解围窗口

	# ---- 2) 蔡九察觉（t≈12s 或与刑台守军交战）：街市巡防第一波 ----
	if not wave1_done and (EXEC_TIME - exec_timer >= 12.0 or _engaged_at_scaffold(B)):
		wave1_done = true
		_spawn_wave1(B)

	# ---- 3) 刑台解救：任一存活好汉（非建筑）贴近刑台 → 救人 ----
	if not rescued_song or not rescued_dai:
		_check_rescue(B)

	# ---- 4) 抵达码头：登船撤退阶段·追兵波 ----
	if rescued_song and not wave3_done and _any_at_dock(B):
		wave3_done = true
		at_dock_started = true
		_spawn_wave3(B)
		B.msg("先头好汉已抵江边码头！张顺接住缆绳——掩护宋江、戴宗与全员登船！", 5.0)

	# ---- 5) 胜利检测：救出二人后，全部存活好汉（含宋江戴宗）都进码头区 ----
	if rescued_song and rescued_dai and _all_at_dock(B):
		B.win("好汉尽数登船，快船顺浔阳江而下——江州劫法场，救下宋公明、戴院长，满载而归！")
		return

	# ---- 6) 失败：主帅晁盖阵亡 / 全部可控好汉阵亡 ----
	if not B.hero_alive("chao_gai"):
		B.lose("托塔天王晁盖殁于江州市曹，群龙无首，劫法场溃败……")
		return
	if B.players_alive() == 0:
		B.lose("好汉尽数折于江州十字街口，浔阳江畔血染长街……")
		return

	# ---- 7) 冒烟自测：自动把关卡推向胜利路径（不让主帅送死）----
	if B._smoke:
		_smoke_drive(B)


## 好汉是否已与刑台守军交战（任一刽子手/牢子有目标，或好汉逼近刑台）
func _engaged_at_scaffold(b) -> bool:
	var B: Battle = b
	for u in B.units_of(Unit.FACTION_GUAN):
		if (u.key == "guan_zhanzi" or u.key == "guan_laozi") and u.has_target():
			return true
	var sc_w: Vector2 = B.map.cell_to_world(SCAFFOLD)
	for u in B.units_of(Unit.FACTION_LIANG):
		if not u.is_building and u.position.distance_to(sc_w) < 140.0:
			return true
	return false


## 检测好汉贴近刑台 → 解救宋江/戴宗（原地替换为可控英雄入伙）
func _check_rescue(b) -> void:
	var B: Battle = b
	var sc_w: Vector2 = B.map.cell_to_world(SCAFFOLD)
	var near := false
	for u in B.units_of(Unit.FACTION_LIANG):
		if u.is_building:
			continue
		if u.position.distance_to(sc_w) <= RESCUE_R + 40.0:
			near = true
			break
	if not near:
		return
	if not rescued_song:
		rescued_song = true
		var sp: Vector2 = song_bound.position if is_instance_valid(song_bound) else B.map.cell_to_world(SCAFFOLD + Vector2i(-1, 0))
		if is_instance_valid(song_bound):
			song_bound.queue_free()
			B.units.erase(song_bound)
		var sj := B.spawn_unit("song_jiang", Unit.FACTION_LIANG, sp)
		sj.passive = false
		B.msg("【解救】好汉砍翻牢子，一把扯断绳索——宋江挣脱绑缚，入伙可控！", 5.0)
	if not rescued_dai:
		rescued_dai = true
		var dp: Vector2 = dai_bound.position if is_instance_valid(dai_bound) else B.map.cell_to_world(SCAFFOLD + Vector2i(1, 0))
		if is_instance_valid(dai_bound):
			dai_bound.queue_free()
			B.units.erase(dai_bound)
		var dz := B.spawn_unit("dai_zong", Unit.FACTION_LIANG, dp)
		dz.passive = false
		B.msg("【解救】戴院长神行太保得脱！蔡九大恨：『走了反贼，提头来见！』——速退码头！", 5.0)
		# 解救成功瞬间：第二波堵截官军封锁通往码头的街巷
		if not wave2_done:
			wave2_done = true
			_spawn_wave2(B)


## 任一好汉抵达码头区域
func _any_at_dock(b) -> bool:
	var B: Battle = b
	var dk_w: Vector2 = B.map.cell_to_world(DOCK_C)
	for u in B.units_of(Unit.FACTION_LIANG):
		if not u.is_building and u.position.distance_to(dk_w) <= DOCK_R:
			return true
	return false


## 全部存活好汉（含宋江戴宗，非建筑）都进入码头区
func _all_at_dock(b) -> bool:
	var B: Battle = b
	var dk_w: Vector2 = B.map.cell_to_world(DOCK_C)
	var any := false
	for u in B.units_of(Unit.FACTION_LIANG):
		if u.is_building:
			continue
		any = true
		if u.position.distance_to(dk_w) > DOCK_R:
			return false
	return any


func _spawn_wave1(b) -> void:
	var B: Battle = b
	B.msg("【援军】蔡九察觉劫法场，急调街市巡防——官军自北衙门、东街口两路杀来！", 5.0)
	var sc_w: Vector2 = B.map.cell_to_world(PLAZA_C)
	B.spawn_group("guan_dao", 4, Unit.FACTION_GUAN, GATE_N, sc_w)
	B.spawn_group("guan_gong", 3, Unit.FACTION_GUAN, GATE_N, sc_w)
	B.spawn_group("guan_dao", 4, Unit.FACTION_GUAN, GATE_E, sc_w)
	B.spawn_group("guan_qi", 2, Unit.FACTION_GUAN, GATE_E, sc_w)


func _spawn_wave2(b) -> void:
	var B: Battle = b
	# 堵截官军自东街口涌出封锁通往码头的街巷，刀盾兵与马军列阵堵口
	var block_w: Vector2 = B.map.cell_to_world(Vector2i(20, 32))
	B.spawn_group("guan_qi", 2, Unit.FACTION_GUAN, GATE_E, block_w)
	B.spawn_group("guan_dao", 4, Unit.FACTION_GUAN, GATE_E, block_w)
	B.spawn_group("guan_gong", 3, Unit.FACTION_GUAN, GATE_N, B.map.cell_to_world(PLAZA_C))


func _spawn_wave3(b) -> void:
	var B: Battle = b
	# 登船阶段：残余官军自北衙门倾巢追击
	var dk_w: Vector2 = B.map.cell_to_world(DOCK_C)
	B.spawn_group("guan_dao", 3, Unit.FACTION_GUAN, GATE_N, dk_w)
	B.spawn_group("guan_gong", 2, Unit.FACTION_GUAN, GATE_N, dk_w)


## 冒烟自测：headless 下自动驱动关卡到「胜利」。分阶段推进，主帅压阵不送死。
func _smoke_drive(b) -> void:
	var B: Battle = b
	var sc_w: Vector2 = B.map.cell_to_world(SCAFFOLD)
	var dk_w: Vector2 = B.map.cell_to_world(DOCK_C)
	var rear_w: Vector2 = B.map.cell_to_world(Vector2i(14, 30))  # 主帅西巷压阵点（远离街口火线）
	match smoke_phase:
		0:
			# 阶段0：突击队（除主帅）攻向刑台杀守军/刽子手；李逵放排头砍去；主帅退守西巷
			smoke_phase = 1
			for u in B.units_of(Unit.FACTION_LIANG):
				if u.is_building:
					continue
				if u.key == "chao_gai":
					u.order_move(rear_w)  # 主帅纯移动压阵，不主动卷入近战
				else:
					u.order_amove(sc_w)
			var lk := B.find_unit("li_kui")
			if lk != null and lk.ability_ready():
				B.cast_ability(lk)
		1:
			# 阶段1：主帅持续守在西巷安全点；救出二人后转入撤退
			var cg := B.find_unit("chao_gai")
			if cg != null and not cg.has_target() and cg.position.distance_to(rear_w) > 60.0:
				cg.order_move(rear_w)
			if rescued_song and rescued_dai:
				smoke_phase = 2
				var dz := B.find_unit("dai_zong")
				if dz != null and dz.ability_ready():
					B.cast_ability(dz)  # 神行甲马全军加速撤退
		2:
			# 阶段2：全军（含被救者）撤向码头并持续催进，直至全员登船
			for u in B.units_of(Unit.FACTION_LIANG):
				if u.is_building:
					continue
				if u.position.distance_to(dk_w) > DOCK_R - 30.0:
					# 主帅用纯移动逃离，其余且战且走
					if u.key == "chao_gai":
						u.order_move(dk_w)
					elif not u.has_target():
						u.order_amove(dk_w)


func on_unit_died(b, u) -> void:
	var B: Battle = b
	if u.faction == Unit.FACTION_LIANG and u.is_hero and not u.is_building:
		if u.key == "chao_gai":
			return  # 主帅阵亡由 process 统一判负
		B.msg("%s 中刀倒下了！" % u.display_name, 3.5)
	elif u.faction == Unit.FACTION_GUAN and u.key == "guan_zhanzi":
		if B.count_alive(Unit.FACTION_GUAN, "guan_zhanzi") == 0 and not rescued_song:
			B.msg("【行刑中断】两名刽子手已被排头砍翻，鬼头刀落地——行刑停下，倒计时暂停！", 5.0)


func top_status(b) -> String:
	var B: Battle = b
	var phase_txt := ""
	if not rescued_song:
		var zhanzi := B.count_alive(Unit.FACTION_GUAN, "guan_zhanzi")
		if zhanzi == 0:
			phase_txt = "行刑已中断·倒计时暂停！速救宋江"
		else:
			phase_txt = "行刑倒计时 %d 秒 | 刽子手 %d" % [int(ceil(exec_timer)), zhanzi]
	elif not _all_at_dock_quiet(B):
		phase_txt = "已救出%s%s · 护送登船！" % [
			"宋江" if rescued_song else "", "、戴宗" if rescued_dai else ""]
	else:
		phase_txt = "登船遁走"
	return "江州劫法场 | %s | 歼敌 %d" % [phase_txt, B.kills]


## 顶栏用的安静版码头检测（不触发任何副作用）
func _all_at_dock_quiet(b) -> bool:
	return _all_at_dock(b)
