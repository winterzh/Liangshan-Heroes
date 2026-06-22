extends LevelBase
## 第1关·智取生辰纲（黄泥冈）。七星聚义，潜伏松林芦苇，待运送队中暑歇脚、白胜下药昏倒，
## 趁虚一拥而上夺取生辰纲宝车。硬拼必败，智取方胜。

const T := GameMap.T
const TOP := Vector2i(24, 20)        # 黄泥冈顶·歇脚台
const GATE_E := Vector2i(46, 20)     # 运送队入口
const GATE_W := Vector2i(2, 20)      # 败逃出口

enum { MARCH, REST, ESCAPE }

var cart: Unit
var yang: Unit
var convoy: Array = []
var st := MARCH
var rest_t := 0.0
var drug_done := false
var assault_ordered := false
var core_dead := 0


func id() -> String: return "level1"
func title() -> String: return "智取生辰纲"
func subtitle() -> String: return "黄泥冈·七星聚义"
func map_w() -> int: return 48
func map_h() -> int: return 40
func map_theme() -> String: return "hills"
func map_base() -> int: return T.DRYHILL
func camera_start_cell() -> Vector2i: return Vector2i(26, 20)
func deploy_hint() -> String:
	return "把好汉藏进松林与芦苇（芦苇中隐身，敌人贴近才发觉）。耐心等运送队上冈歇脚、白胜下药昏倒，再一拥而上夺车——切勿过早惊动杨志！"


func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "六月酷暑，赤日炎炎。黄泥冈上松林蔽日。青面兽杨志押着十一名军汉、两个虞候、一个老都管，挑着十万贯生辰纲上冈来——这套不义之财，今日合该易主。"},
		{"who": "吴用", "key": "wu_yong", "text": "晁天王，杨志刀法了得，却架不住这毒日头。先把好汉藏进松林芦苇，按兵不动。待他们上冈口渴难当——白胜那担蒙汗药酒，便是破阵的锦囊。"},
		{"who": "晁盖", "key": "chao_gai", "text": "好计较！只是切记：未到时候，谁也不许露头。惊了杨志，七个人也未必讨得了好。"},
		{"who": "军令", "key": "narrator", "text": "【潜伏】把好汉拖进芦苇藏好。等运送队歇脚、白胜下药后，全军杀出夺取宝车。"},
	]


func paint_map(map: GameMap) -> void:
	# 上下岩坡围合，中部留出山道走廊
	map.fill_rect(0, 0, 48, 8, T.CLIFF)
	map.fill_rect(0, 32, 48, 8, T.CLIFF)
	# 松林伏点
	map.fill_ellipse(Vector2(22, 13), 3, 2, T.FOREST)
	map.fill_ellipse(Vector2(27, 27), 3, 2, T.FOREST)
	map.fill_ellipse(Vector2(13, 24), 2, 2, T.FOREST)
	map.fill_ellipse(Vector2(34, 26), 2, 2, T.FOREST)
	# 山道：东山脚 → 冈顶 → 西山口
	map.paint_path([Vector2(47, 20), Vector2(38, 20), Vector2(30, 20), Vector2(24, 20), Vector2(14, 20), Vector2(1, 20)], 1, T.ROAD)
	# 冈顶歇脚台（开阔黄土）
	map.fill_ellipse(Vector2(24, 20), 4, 2, T.DRYHILL, [T.DRYHILL])
	# 两片芦苇伏兵荡，离山道 3 格以上（藏得住、不被察觉），夹击冈顶
	map.fill_ellipse(Vector2(22, 15), 3, 2, T.REEDS)   # 北芦苇荡
	map.fill_ellipse(Vector2(27, 26), 3, 2, T.REEDS)   # 南芦苇荡
	map.fill_ellipse(Vector2(14, 16), 2, 1, T.REEDS)   # 西侧堵口伏点


func decorate(map: GameMap) -> void:
	map.decor = [
		["rocks", Vector2i(10, 10), 50.0], ["rocks", Vector2i(40, 30), 50.0],
		["rocks", Vector2i(6, 28), 46.0], ["rocks", Vector2i(42, 11), 46.0],
		["tent", Vector2i(44, 22), 60.0],
	]


func deploy(b) -> void:
	var B: Battle = b
	cart = B.spawn_at("treasure_cart", Unit.FACTION_GUAN, GATE_E)  # 随运送队，开战时移到队列
	# 七星好汉伏于芦苇荡，按兵不动（passive）：不主动索敌，待下令或被攻击才出手
	for spec in [["chao_gai", Vector2i(22, 15)], ["liu_tang", Vector2i(20, 15)], ["gongsun_sheng", Vector2i(24, 15)],
			["bai_sheng", Vector2i(21, 16)], ["ruan_brother", Vector2i(26, 26)],
			["ruan_brother", Vector2i(28, 26)], ["ruan_brother", Vector2i(27, 27)]]:
		var u := B.spawn_at(spec[0], Unit.FACTION_LIANG, spec[1])
		u.passive = true


func on_start(b) -> void:
	var B: Battle = b
	st = MARCH
	rest_t = 0.0
	drug_done = false
	# 运送队自东山脚登场，沿山道压向冈顶
	var top_w: Vector2 = B.map.cell_to_world(TOP)
	yang = B.spawn_at("yang_zhi", Unit.FACTION_GUAN, GATE_E + Vector2i(0, -1))
	yang.order_amove(top_w)
	convoy = [yang]
	for cell in [Vector2i(47, 19), Vector2i(47, 21)]:
		var yh := B.spawn_at("yu_hou", Unit.FACTION_GUAN, cell)
		yh.order_amove(top_w)
		convoy.append(yh)
	for i in range(11):
		var jh := B.spawn_at("jun_han", Unit.FACTION_GUAN, GATE_E + Vector2i(2 + i % 3, -1 + i % 3))
		jh.order_amove(top_w + Vector2(randf_range(-50, 50), randf_range(-40, 40)))
		convoy.append(jh)
	var ldg := B.spawn_at("lao_duguan", Unit.FACTION_GUAN, GATE_E + Vector2i(1, 1))
	ldg.order_amove(top_w)
	convoy.append(ldg)
	# 宝车随队（移到冈顶东侧，开战后“推上冈”）
	cart.position = B.map.cell_to_world(Vector2i(40, 20))
	B.msg("青面兽杨志押着生辰纲上冈来了——按兵不动！", 5.0)


func process(b, delta: float) -> void:
	var B: Battle = b
	match st:
		MARCH:
			# 宝车随杨志缓缓推上冈
			if is_instance_valid(yang) and yang.hp > 0.0:
				cart.position = cart.position.move_toward(B.map.cell_to_world(TOP) + Vector2(40, 0), 36.0 * delta)
				if yang.position.distance_to(B.map.cell_to_world(TOP)) < 80.0:
					_enter_rest(B)
		REST:
			rest_t += delta
			if not drug_done and rest_t > 12.0:
				_apply_drug(B)
			# 冒烟测试：下药后由猛士发起总攻、晁盖原地放增益（避免主帅送死），验证胜利路径
			if B._smoke and drug_done and not assault_ordered:
				assault_ordered = true
				for u in B.units_of(Unit.FACTION_LIANG):
					if u.key != "bai_sheng":
						u.order_amove(cart.position)
				var cg := B.find_unit("chao_gai")
				if cg != null:
					B.cast_ability(cg)
				var lt := B.find_unit("liu_tang")
				if lt != null:
					B.cast_ability(lt)
			if _guards_alive(B) == 0:
				B.win("夺得生辰纲！十万贯不义之财，今日归了梁山泊。")
				return
			if rest_t > 46.0:
				st = ESCAPE
				B.msg("杨志缓过劲来，护着宝车便往西山口夺路而走——拦住他！", 5.0)
				if is_instance_valid(yang):
					yang.order_move(B.map.cell_to_world(GATE_W))
		ESCAPE:
			cart.position = cart.position.move_toward(B.map.cell_to_world(GATE_W), 34.0 * delta)
			if _guards_alive(B) == 0:
				B.win("截下宝车，夺得生辰纲！")
				return
			if cart.position.distance_to(B.map.cell_to_world(GATE_W)) < 50.0:
				B.lose("杨志护着生辰纲逃出冈外，七星空忙一场……")


func _enter_rest(b) -> void:
	var B: Battle = b
	st = REST
	rest_t = 0.0
	# 中暑歇脚：押运兵疲乏（移速↓攻击↓）
	for u in convoy:
		if is_instance_valid(u) and u.hp > 0.0:
			u.apply_slow(0.6, 999.0)
			u.apply_temp_atk(0.7, 999.0)
	B.msg("日头毒辣，官军人困马乏，在冈顶歇下脚来。白胜的酒担凑了上去……机会来了！", 5.0)


func _apply_drug(b) -> void:
	var B: Battle = b
	drug_done = true
	for u in convoy:
		if not is_instance_valid(u) or u.hp <= 0.0:
			continue
		if u.key == "yang_zhi":
			u.apply_slow(0.5, 18.0)
			u.apply_temp_atk(0.6, 18.0)
		else:
			u.apply_slow(0.25, 18.0)
			u.apply_temp_atk(0.4, 18.0)
	B.msg("一个个软作一堆，口角流涎，登时麻翻在地！七星好汉——杀出来夺纲！", 5.0)


func _guards_alive(b) -> int:
	var B: Battle = b
	return B.count_alive(Unit.FACTION_GUAN, "yang_zhi") \
		+ B.count_alive(Unit.FACTION_GUAN, "yu_hou") \
		+ B.count_alive(Unit.FACTION_GUAN, "jun_han")


func on_unit_died(b, u) -> void:
	if u.faction != Unit.FACTION_LIANG:
		return
	if u.key == "chao_gai":
		b.lose("晁天王晁盖殁于黄泥冈，七星折首，大事去矣……")
	elif u.key in ["gongsun_sheng", "liu_tang"]:
		core_dead += 1
		if core_dead >= 2:
			b.lose("七星头领折损过半，伏击之势已溃……")


func top_status(b) -> String:
	var g := _guards_alive(b)
	var phase_txt := "运送队上冈中…" if st == MARCH else ("智取窗口！速夺宝车" if st == REST else "杨志西逃·拦截！")
	return "智取生辰纲 | %s | 残余护卫 %d | 歼敌 %d" % [phase_txt, g, b.kills]
