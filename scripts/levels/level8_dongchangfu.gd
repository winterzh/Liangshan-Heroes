extends LevelBase
## 第8关·东昌府·飞石没羽箭（招安张清）。梁山打东昌府，守将「没羽箭」张清飞石打将，
## 一连打翻十数员梁山好汉，硬攻不得。宋江用浪里白条张顺的水军之计——把张清诱到水边，
## 一把掀下水去活捉上岸；宋公明亲解其缚，以义气相待，张清感佩来归，飞石神技自此归于梁山。
## 机制：张清飞石专打头领（命中=伤害+重眩落马）。硬拼会被逐个打懵——须把张清杀到力怯，
## 再把他逼到水边，张顺一掀活捉=招安入伙=胜。

const T := GameMap.T

const YAMEN := Vector2i(30, 11)         # 东昌府衙（北）
const LIANG_ENTRY := Vector2i(36, 48)   # 梁山军自东南入场
const WATER_EDGE := Vector2i(20, 31)    # 水边诱擒点（张清力怯后退至此）
const LAKE_C := Vector2i(10, 31)        # 西侧大湖中心

const STONE_CD := 2.1                   # 飞石间隔（秒，受 time_scale 缩放）
const STONE_DMG := 78.0
const STONE_RANGE := 360.0              # 飞石射程（逻辑像素）
const WEARY_FRAC := 0.40                # 张清力怯阈值（残血比例）
const CAPTURE_R := 130.0                # 水边活捉判定半径

var zq: Unit = null                     # 张清（先为敌将，后招安）
var song: Unit = null
var captured := false
var weary := false
var weary_t := 0.0                      # 力怯后计时（逼水边失败的兜底）
var move_retry := 0.0                   # 驱赶张清往水边的节流计时
var barrage_t := 0.0
var coda_t := -1.0
var hit_count := 0                      # 被飞石打懵的好汉人次（顶栏战报）
var smoke_t := 0.0


func id() -> String: return "level8"
func title() -> String: return "东昌府·飞石"
func subtitle() -> String: return "没羽箭张清·水擒招安"
func map_w() -> int: return 60
func map_h() -> int: return 52
func map_theme() -> String: return "town"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(30, 32)
func deploy_hint() -> String:
	return "守将没羽箭张清的飞石专打头领，一石一个、连打十数将——切莫一窝蜂硬冲送脸！先稳住阵脚、合力把张清杀到力怯（残血），他便往西边水泊退去。趁势把他逼到水边，让浪里白条张顺一把掀下水去活捉上岸——擒住张清、以义招安入伙=胜。"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "梁山兵马围打东昌府。城中守将『没羽箭』张清，生得一手飞石绝技——袖中石子百发百中，专打头脸。两军阵前，张清连珠飞石，一连打翻梁山十五员战将，众好汉一时无人近得了身。"},
		{"who": "张清", "key": "zhang_qing", "text": "量你这伙草寇，也敢来撼东昌府？看我袖中石子！一个一个，都与我落马来！"},
		{"who": "宋江", "key": "song_jiang", "text": "张清飞石如此了得，硬拼徒折好汉。——传我将令：诱他到水泊边上，教浪里白条张顺水中接应。这般英雄，正该收归山寨，断不可伤他性命！"},
		{"who": "军令", "key": "narrator", "text": "【水擒招安】张清飞石专打头领（中者受伤+落马重眩）。合力把张清杀到力怯，他便往西水边退；趁势把他逼到水泊边，张顺一掀活捉=招安入伙=胜。宋江阵亡或好汉尽墨=败。"},
	]


func paint_map(map: GameMap) -> void:
	# 西侧一片大水泊（活捉之处）+ 沿岸滩涂
	map.fill_ellipse(Vector2(LAKE_C.x, LAKE_C.y), 11, 13, T.WATER)
	map.fill_rect(0, 18, 6, 26, T.WATER, [T.GRASS])
	map.fill_ellipse(Vector2(19, 31), 5, 6, T.SHORE, [T.WATER])
	map.fill_ellipse(Vector2(LAKE_C.x, 18), 8, 3, T.SHORE, [T.WATER])
	# 东昌府城：北部一片城镇砖地 + 府衙广场
	map.fill_rect(18, 4, 26, 12, T.TOWN)
	map.fill_ellipse(Vector2(YAMEN.x, YAMEN.y), 7, 4, T.PLAZA)
	# 城南旷野（两军对阵的开阔地）
	map.fill_ellipse(Vector2(32, 32), 12, 9, T.FIELD)
	# 入城大道：东南入场 → 旷野 → 府衙
	map.paint_path([Vector2(LIANG_ENTRY.x, LIANG_ENTRY.y), Vector2(34, 40), Vector2(32, 30), Vector2(30, 20), Vector2(YAMEN.x, YAMEN.y)], 1, T.ROAD)
	# 水边小径（诱擒点）
	map.paint_path([Vector2(32, 32), Vector2(26, 31), Vector2(WATER_EDGE.x, WATER_EDGE.y)], 1, T.ROAD)


func decorate(map: GameMap) -> void:
	map.decor = [
		["town_house", Vector2i(22, 7), 58.0], ["town_house", Vector2i(38, 7), 58.0],
		["town_house", Vector2i(24, 14), 52.0], ["town_house", Vector2i(37, 14), 52.0],
		["dock", Vector2i(WATER_EDGE.x - 1, WATER_EDGE.y + 2), 56.0],
		["rocks", Vector2i(46, 36), 46.0], ["rocks", Vector2i(50, 24), 44.0],
	]


func deploy(b) -> void:
	var B: Battle = b
	# 梁山军：宋江率林冲、花荣、李逵、浪里白条张顺 + 步骑
	song = B.spawn_at("song_jiang", Unit.FACTION_LIANG, LIANG_ENTRY)
	B.spawn_at("lin_chong", Unit.FACTION_LIANG, LIANG_ENTRY + Vector2i(-1, 0))
	B.spawn_at("hua_rong", Unit.FACTION_LIANG, LIANG_ENTRY + Vector2i(1, 0))
	B.spawn_at("li_kui", Unit.FACTION_LIANG, LIANG_ENTRY + Vector2i(0, 1))
	B.spawn_at("zhang_shun", Unit.FACTION_LIANG, LIANG_ENTRY + Vector2i(-1, 1))
	for c in [Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1)]:
		B.spawn_at("liang_dao", Unit.FACTION_LIANG, LIANG_ENTRY + c)
	for c in [Vector2i(0, 2), Vector2i(1, 2), Vector2i(-1, 2)]:
		B.spawn_at("liang_gong", Unit.FACTION_LIANG, LIANG_ENTRY + c)
	for c in [Vector2i(3, 0), Vector2i(-3, 0)]:
		B.spawn_at("liang_ma", Unit.FACTION_LIANG, LIANG_ENTRY + c)
	# 东昌府：府衙 + 张清（守将）+ 龚旺、丁得孙 + 城防官军
	B.spawn_at("dongchang_yamen", Unit.FACTION_GUAN, YAMEN)
	zq = B.spawn_at("zhang_qing", Unit.FACTION_GUAN, Vector2i(30, 26))
	zq.ability = ""   # 飞石由关卡逻辑驱动远程打将（招安后再给玩家版以技能形态）
	B.spawn_at("gong_wang", Unit.FACTION_GUAN, Vector2i(27, 24))
	B.spawn_at("ding_desun", Unit.FACTION_GUAN, Vector2i(33, 24))
	for c in [Vector2i(24, 20), Vector2i(28, 20), Vector2i(32, 20), Vector2i(36, 20), Vector2i(26, 17), Vector2i(34, 17)]:
		B.spawn_at("guan_dao", Unit.FACTION_GUAN, c)
	for c in [Vector2i(25, 15), Vector2i(30, 14), Vector2i(35, 15), Vector2i(30, 17)]:
		B.spawn_at("guan_gong", Unit.FACTION_GUAN, c)
	for c in [Vector2i(22, 22), Vector2i(38, 22), Vector2i(30, 22)]:
		B.spawn_at("guan_qi", Unit.FACTION_GUAN, c)


func on_start(b) -> void:
	var B: Battle = b
	captured = false
	weary = false
	barrage_t = 2.0
	coda_t = -1.0
	hit_count = 0
	B.msg("张清当阵立马，袖中石子蓄势待发——切莫一窝蜂硬冲！把他杀到力怯，再逼到水边！", 5.0)


func process(b, delta: float) -> void:
	var B: Battle = b
	if B._smoke:
		_smoke_drive(B, delta)

	# 招安成功后的尾声（让玩家看一眼张清归队），数秒后判胜
	if coda_t >= 0.0:
		coda_t -= delta
		if coda_t <= 0.0:
			B.win("宋公明亲解其缚，置酒相待。张清感梁山义气，纳头便拜，愿效犬马——没羽箭的飞石神技，自此归于梁山泊！东昌府下。")
		return

	if not is_instance_valid(song) or song.hp <= 0.0:
		B.lose("宋公明中乱军身陷重围，主帅有失，东昌府前功亏一篑……")
		return
	if B.count_alive(Unit.FACTION_LIANG) == 0:
		B.lose("梁山好汉被张清飞石一一打翻，阵脚大溃……")
		return

	if is_instance_valid(zq) and zq.faction == Unit.FACTION_GUAN and zq.hp > 0.0:
		_run_barrage(B, delta)
		# 力怯：杀到残血 → 往西水边退去，露出活捉之机
		if not weary and zq.hp <= zq.max_hp * WEARY_FRAC:
			weary = true
			weary_t = 0.0
			move_retry = 0.0
			B.msg("张清气力不加，拨马往西边水泊退去——快逼上去，教张顺把他掀下水！", 4.5)
		if weary:
			weary_t += delta
			# 持续把他往水边赶（节流下发，免得每帧重发打断寻路；被打会解除 passive，故反复设回）
			move_retry -= delta
			if move_retry <= 0.0:
				move_retry = 0.8
				zq.passive = true
				zq.order_move(B.map.cell_to_world(WATER_EDGE))
			# 活捉条件：逼到水边 / 力竭过久 / 残血将殁（兜底：绝不让他被打死而卡死流程）
			var at_water := zq.position.distance_to(B.map.cell_to_world(WATER_EDGE)) < CAPTURE_R or _near_water(B, zq.position)
			if at_water or weary_t > 14.0 or zq.hp <= zq.max_hp * 0.18:
				_capture(B)


func _run_barrage(b, delta: float) -> void:
	var B: Battle = b
	barrage_t -= delta
	if barrage_t > 0.0:
		return
	barrage_t = STONE_CD
	var tgt := _pick_barrage_target(B)
	if tgt == null:
		return
	# 飞石打将：飞射的石子（伤害随箭矢结算）+ 命中即落马重眩
	B.spawn_projectile(zq, tgt, STONE_DMG)
	tgt.apply_slow(0.07, 1.6)        # 落马·几近定身
	tgt.apply_temp_atk(0.4, 1.6)     # 被打懵·攻击大降
	B.spawn_impact(tgt.position + Vector2(0, -8), true)
	B.shake(3.0, tgt.position)
	hit_count += 1
	if hit_count <= 6 or hit_count % 3 == 0:
		B.msg("飞石！%s 被没羽箭一石打懵，跌撞落马！" % tgt.display_name, 1.6)


func _pick_barrage_target(b) -> Unit:
	var B: Battle = b
	var best: Unit = null
	var best_score := -1.0
	for u in B.units_of(Unit.FACTION_LIANG):
		if not is_instance_valid(u) or u.is_building or u.garrisoned or u.hp <= 0.0:
			continue
		var d := zq.position.distance_to(u.position)
		if d > STONE_RANGE:
			continue
		# 专打头领：英雄优先（高权重），其次就近
		var score := (1000.0 if u.is_hero else 0.0) + (STONE_RANGE - d)
		if score > best_score:
			best_score = score
			best = u
	return best


func _near_water(b, p: Vector2) -> bool:
	var B: Battle = b
	var c := B.map.world_to_cell(p)
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if B.map.t_at(c.x + dx, c.y + dy) == T.WATER:
				return true
	return false


func _capture(b) -> void:
	var B: Battle = b
	captured = true
	var sp: Vector2 = zq.position
	if is_instance_valid(zq):
		zq.queue_free()
		B.units.erase(zq)
	# 招安：在水边生成可控的张清（带飞石技能，归玩家所用）
	var ally := B.spawn_unit("zhang_qing", Unit.FACTION_LIANG, sp + Vector2(8, -4))
	ally._buff_glow = 1.0
	ally.queue_redraw()
	B.spawn_impact(sp, true)
	B.shake(5.0, sp)
	Sfx.play("cast", 0.0, 0.05, 120)
	# 守军见主将被擒，纷纷夺路（士气崩、战力大减）
	for u in B.units_of(Unit.FACTION_GUAN):
		if is_instance_valid(u) and not u.is_building:
			u.apply_temp_atk(0.5, 999.0)
			u.apply_slow(0.7, 999.0)
	B.msg("浪里白条水中一掀，没羽箭张清落入水泊，被生擒上岸！", 5.0)
	coda_t = 4.0


func on_unit_died(b, u) -> void:
	if u == song:
		b.lose("宋公明殁于东昌府前，主帅有失，大军溃散……")
	elif u == zq and not captured:
		# 兜底：万一张清被一击打殁（未及活捉），按「打翻擒下」处理，决不卡死流程
		_capture_at(b, u.position)


func _capture_at(b, pos: Vector2) -> void:
	var B: Battle = b
	if captured:
		return
	captured = true
	zq = null
	var ally := B.spawn_unit("zhang_qing", Unit.FACTION_LIANG, pos + Vector2(8, -4))
	ally._buff_glow = 1.0
	ally.queue_redraw()
	for u in B.units_of(Unit.FACTION_GUAN):
		if is_instance_valid(u) and not u.is_building:
			u.apply_temp_atk(0.5, 999.0)
			u.apply_slow(0.7, 999.0)
	B.msg("张清被打翻在地，梁山好汉一拥而上生擒活捉！宋公明亲解其缚，以礼相待——没羽箭来归！", 5.0)
	coda_t = 4.0


func top_status(b) -> String:
	var B: Battle = b
	if captured:
		return "东昌府·招安 | 张清入伙！没羽箭归于梁山 | 歼敌 %d" % B.kills
	if is_instance_valid(zq) and zq.hp > 0.0:
		var pct := int(100.0 * zq.hp / maxf(zq.max_hp, 1.0))
		var ph := "力怯·逼向水边活捉！" if weary else "硬拼必折将·杀到力怯"
		return "东昌府·飞石 | 张清 %d%%（%s）| 被飞石打懵 %d 人次 | 歼敌 %d" % [pct, ph, hit_count, B.kills]
	return "东昌府·飞石 | 歼敌 %d" % B.kills


# ---- 冒烟自测：合力围张清 → 杀到力怯逼水边 → 活捉招安 ----
func _smoke_drive(b, delta: float) -> void:
	var B: Battle = b
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 1.5
	if captured:
		return
	var focus: Vector2
	if is_instance_valid(zq) and zq.hp > 0.0:
		focus = zq.position
	else:
		focus = B.map.cell_to_world(YAMEN)
	for u in B.units_of(Unit.FACTION_LIANG):
		if is_instance_valid(u) and not u.is_building:
			u.order_amove(focus)
