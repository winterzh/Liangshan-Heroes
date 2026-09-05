extends LevelBase
## 祝家庄 RTS 样板：同一张地图持续经营，外围兵源可以被切断。
## 不调用旧三日脚本的 clear_campaign_section，不改共享兵种数值。
const T := GameMap.T
const CAMP := Vector2i(55, 28)
const MAIN_GATE := Vector2i(20, 28)
const SIDE_GATE := Vector2i(20, 18)
const OUTPOST := Vector2i(36, 39)
const EXPANSION := Vector2i(36, 16)
const PRISON := Vector2i(11, 35)
const INNER_CONTACT := Vector2i(25, 18)
const PRISONERS := ["shi_qian", "shi_xiu", "qin_ming", "yang_lin", "huang_xin", "wang_ying", "deng_fei"]
const FIELD_ACTORS := ["song_jiang", "lin_chong", "hua_rong", "sun_li", "liang_dao", "liang_qiang", "liang_gong", "liang_ma"]
const TROOPS := [{"key":"zhu_keke", "cost":"liang_dao"}, {"key":"zhu_gong", "cost":"liang_gong"}, {"key":"zhu_qi", "cost":"liang_ma"}]
var hall: Unit
var song: Unit
var gate: Unit
var side_gate: Unit
var enemy_base: Unit
var outpost: Unit
var hu: Unit
var sun: Unit
var prisoners: Array[Unit] = []
var workers: Array[Unit] = []
var enemy_workers: Array[Unit] = []
var enemy_nodes: Array[Unit] = []
var reserve: Array[Unit] = []
var trained: Array[Unit] = []
var resource_guards: Array[Unit] = []
var elapsed := 0.0
var train_clock := 90.0
var raid_clock := 150.0
var strategic_clock := 0.0
var stage := "scout"
var expansion_secured := false
var supply_cut := false
var inside_open := false
var prisoners_freed := false
var manor_fallen := false
var sent_sun := false
var main_breached := false
var ai_trained := 0
var ai_spent_gold := 0
var ai_spent_wood := 0
var raids_sent := 0

func id() -> String: return "level3"
func title() -> String: return "三打祝家庄"
func subtitle() -> String: return "扎营整军·争夺外围·里应外合"
func economy_enabled() -> bool: return true
func start_gold() -> int: return 300
func start_wood() -> int: return 200
func base_pop_cap() -> int: return 20
func start_age() -> int: return 3
func hero_start_rank() -> int: return 0
func hero_cap() -> int: return 4
func fog_enabled() -> bool: return true
func map_w() -> int: return 64
func map_h() -> int: return 56
func map_theme() -> String: return "village"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return CAMP
func campaign_core_goal() -> String:
	return "摧毁祝家庄大营，救出时迁并送回前营。宋江、时迁与梁山前营必须存活。"
func story_contract_version() -> int: return 2
func campaign_story_goals() -> Array:
	return [
		{"id":"zhu_capture", "label":"生擒扈三娘，仍按敌将看押", "required_events":["zhu_hu_captured"]},
		{"id":"zhu_inside", "label":"孙立内应，打开偏门", "required_events":["zhu_gate_opened"], "forbidden_events":["zhu_side_breached"]},
		{"id":"zhu_seven", "label":"七名被囚好汉全部撤回前营", "required_events":["zhu_seven_safe"], "forbidden_events":["zhu_prisoner_lost"]},
	]
func deploy_hint() -> String:
	return "先采金伐木、建民居扩军。北面资源可扩张，南营是来袭兵源；守军会迎敌回防，两个入口均有箭楼。可用投石车远拆箭楼、步兵护送撞车攻门，也可由孙立开偏门。"
func intro_lines() -> Array:
	return [
		{"who":"旁白", "key":"narrator", "text":"时迁等好汉陷在祝家庄。宋江在独龙冈东侧扎下前营，准备探清盘陀路、拔除外围，再攻庄救人。"},
		{"who":"宋江", "key":"song_jiang", "text":"先安营整军。北面有钱粮可取，南面庄客营不断来援；先夺哪处，由战局决定。"},
		{"who":"军令", "key":"narrator", "text":"两处庄门都有护庄箭楼，投石车可在箭楼射程外拆除，步兵保护器械。工人采集金木、兵营持续补兵；攻破大营后救时迁回营，保住宋江与前营。"},
	]

func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	# Only chapter availability and captive state differ; shared combat/economy stats remain intact.
	defs["hall"]["produces"] = ["lou_luo", "song_jiang", "lin_chong", "hua_rong"]
	for troop in TROOPS:
		for field in ["cost_gold","cost_wood","pop"]:
			defs[troop.key][field] = defs[troop.cost].get(field,1 if field == "pop" else 0)
	for key in PRISONERS:
		defs[key]["hero_trainable"] = false
		defs[key]["pop"] = 0

func paint_map(map: GameMap) -> void:
	map.fill_rect(0, 0, 64, 56, T.GRASS)
	map.fill_rect(23, 7, 23, 42, T.FOREST)
	map.fill_rect(3, 10, 15, 36, T.FIELD)
	map.fill_rect(47, 13, 16, 33, T.GRASS)
	map.fill_ellipse(Vector2(EXPANSION), 8, 7, T.FIELD)
	map.fill_ellipse(Vector2(OUTPOST), 8, 7, T.PLAIN)
	map.paint_path([Vector2(CAMP), Vector2(44,28), Vector2(39,25), Vector2(30,28), Vector2(10,28)], 2, T.ROAD)
	map.paint_path([Vector2(49,25), Vector2(44,18), Vector2(EXPANSION), Vector2(25,18), Vector2(12,18)], 2, T.ROAD)
	map.paint_path([Vector2(49,32), Vector2(45,39), Vector2(OUTPOST), Vector2(29,35), Vector2(28,28)], 2, T.ROAD)
	# A continuous wall closes boundary bypasses. Each gate fills its entire 3x3 opening.
	for y in range(56):
		if y in [17,18,19,27,28,29]: continue
		for x in [19,20,21]: map.set_cell_t(x, y, T.CLIFF)
	map.set_meta("campaign_wall_segments", [[Vector2(20,0),Vector2(20,16)], [Vector2(20,20),Vector2(20,26)], [Vector2(20,30),Vector2(20,55)]])

func decorate(map: GameMap) -> void:
	map.decor = [["forest",Vector2i(42,23),40.0], ["forest",Vector2i(31,25),40.0],
		["banner",Vector2i(53,31),96.0], ["rocks",Vector2i(39,12),44.0]]

func _alive(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

func _guard(b, key: String, cell: Vector2i) -> Unit:
	var u: Unit = b.spawn_at(key, Unit.FACTION_GUAN, cell)
	# Guard the post by engaging nearby intruders and returning after a short chase.
	# Hold Position only attacks enemies already in melee reach and made these
	# defenders spectators while two heroes dismantled the whole manor.
	u.set_stance(Unit.STANCE_DEFEND)
	return u

func _resource(b, key: String, cell: Vector2i, faction: int, amount: float) -> Unit:
	var u: Unit = b.spawn_at(key, faction, cell)
	u.res_left = amount
	return u

func deploy(b) -> void:
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, CAMP)
	hall.display_name = "梁山前营"
	b.spawn_at("barracks", Unit.FACTION_LIANG, Vector2i(55,37))
	song = b.spawn_at("song_jiang", Unit.FACTION_LIANG, Vector2i(50,28))
	b.spawn_at("lin_chong", Unit.FACTION_LIANG, Vector2i(49,29))
	for i in range(4): b.spawn_at("liang_qiang" if i < 2 else "liang_gong", Unit.FACTION_LIANG, Vector2i(49+i,32))
	for i in range(6): workers.append(b.spawn_at("lou_luo", Unit.FACTION_LIANG, Vector2i(53+i,23)))
	for c in [Vector2i(51,18),Vector2i(57,18),Vector2i(60,24)]: _resource(b,"gold_mine",c,0,1400.0)
	for c in [Vector2i(59,33),Vector2i(60,36),Vector2i(60,40),Vector2i(51,42),Vector2i(55,43),Vector2i(59,44)]: _resource(b,"tree",c,0,900.0)
	for c in [Vector2i(34,13),Vector2i(38,13)]: _resource(b,"gold_mine",c,0,4000.0)
	for c in [Vector2i(31,15),Vector2i(32,12),Vector2i(40,15)]: _resource(b,"tree",c,0,1200.0)
	for spec in [["zhu_keke",Vector2i(36,18)],["zhu_keke",Vector2i(38,18)],["zhu_gong",Vector2i(33,16)]]:
		resource_guards.append(_guard(b,spec[0],spec[1]))
	gate = b.spawn_at("zhu_gate",1,MAIN_GATE)
	gate.display_name = "祝家庄正门"
	gate.set_meta("campaign_gate_wall_span",Vector2(0,128))
	side_gate = b.spawn_at("zhu_gate",1,SIDE_GATE)
	side_gate.display_name = "祝家庄偏门"
	side_gate.set_meta("campaign_gate_wall_span",Vector2(0,128))
	# Existing shared towers cover both entrances. Catapults can outrange them;
	# melee defenders protect the towers, making an escorted siege force useful.
	# Offset along the inner wall so roofs do not overlap the gatehouse.
	for c in [Vector2i(17,30),Vector2i(17,20)]:
		var tower: Unit = b.spawn_at("arrow_tower",1,c)
		tower.display_name = "护庄箭楼"
	outpost = b.spawn_at("barracks",1,OUTPOST)
	outpost.display_name = "庄客外营 · 拆除可断援"
	_guard(b,"zhu_keke",Vector2i(39,39))
	_guard(b,"zhu_gong",Vector2i(35,36))
	hu = _guard(b,"hu_sanniang",Vector2i(33,41))
	hu.defeat_outcome = "captured"
	enemy_base = b.spawn_at("hall",1,Vector2i(10,26))
	enemy_base.display_name = "祝家庄大营 · 核心目标"
	for c in [Vector2i(15,26),Vector2i(15,30),Vector2i(15,19),Vector2i(8,34)]: _guard(b,"zhu_keke",c)
	for c in [Vector2i(16,28),Vector2i(16,18),Vector2i(9,32)]: _guard(b,"zhu_gong",c)
	_guard(b,"zhu_hu",Vector2i(12,29))
	for c in [Vector2i(5,20),Vector2i(10,17)]: enemy_nodes.append(_resource(b,"gold_mine",c,1,1600.0))
	for c in [Vector2i(5,33),Vector2i(6,37),Vector2i(14,39)]: enemy_nodes.append(_resource(b,"tree",c,1,1000.0))
	for i in range(4): enemy_workers.append(b.spawn_at("lou_luo",1,Vector2i(7+i,21)))
	for i in range(PRISONERS.size()):
		# Neutral captives do not reveal the manor or occupy the active-hero sidebar.
		var u: Unit = b.spawn_at(PRISONERS[i],2,PRISON+Vector2i(i%3,i/3))
		u.is_captive = true
		u.is_noncombat = true
		u.passive = true
		u.stance = Unit.STANCE_PASSIVE
		u.base_speed = 0.0
		u.atk = 0.0
		u.ability = ""
		u.ability_slots.clear()
		u.art_variant = "bound_"+u.key
		prisoners.append(u)

func on_start(b) -> void:
	b.faction_res[1] = {"gold":180.0,"wood":100.0}
	for i in range(workers.size()):
		var node = b.nearest_free_gold(workers[i].position,null,workers[i]) if i < 3 else b.nearest_resource(workers[i].position,"wood")
		if node != null: workers[i].order_gather(node)
	for i in range(enemy_workers.size()): enemy_workers[i].order_gather(enemy_nodes[i])
	b.mission.begin("zhu_rts", "第一打 · 扎营探路", "北取资源，南拔外营；兵营补兵、作坊造器械。先侦察，再决定主攻方向。")
	b.mission.add_action("zhu_rts_recon","探路：查看外围战场",Vector2i(42,22),FIELD_ACTORS,1.0,64.0)
	b.mission.add_action("zhu_rts_rescue","救出被囚好汉",PRISON+Vector2i(4,0),FIELD_ACTORS,3.0,64.0)
	b.lit_cells[OUTPOST] = 12.0
	b.lit_cells[EXPANSION] = 12.0
	b.msg("北面可夺资源，南面拆营可断援。首支庄客约150秒后出发，注意建民居补人口。",8.0)

func _introduce_sun(b) -> void:
	if sent_sun: return
	sent_sun = true
	sun = b.spawn_at("sun_li",0,Vector2i(52,25))
	sun.order_hold_position()
	b.mission.add_action("zhu_rts_inside","接应内应，打开偏门",INNER_CONTACT,["sun_li"],5.0,64.0)
	b.mission.add_actor_locator("zhu_rts_inside","sun_li")
	if not _alive(side_gate): b.mission.block_action("zhu_rts_inside","偏门已被攻破，无需再接应；可直接入庄救人。")
	b.msg("孙立已到前营。点“选中·孙立”，再右键3号旗标；到场停留5秒即可接应开偏门。",9.0)

func on_mission_action(b, action_id: String, actor) -> void:
	match action_id:
		"zhu_rts_finish":
			if actor != song or not _finish_ready():
				b.mission.actions[action_id]["done"] = false
				b.mission.actions[action_id]["button"].disabled = false
				b.mission.actions[action_id]["marker"].show()
				b.mission.set_status("请先将时迁护送至前营附近，再由宋江收军。")
				return
			if prisoners.all(func(u): return _alive(u) and u.position.distance_to(hall.position) < 190.0):
				b.mission.mark("zhu_seven_safe","七名被囚好汉全部撤回前营")
			b.mission.mark("zhu_victory","祝家庄大营已破，时迁安全回营")
			b.win("祝家庄已破，时迁归营！营地经营、战场争夺与攻庄救人完成。")
		"zhu_rts_recon":
			b.mission.mark("zhu_route_known","探明北面资源与南面兵源，两条道路均可进军")
			b.lit_cells[EXPANSION] = 30.0
			b.lit_cells[OUTPOST] = 30.0
			_introduce_sun(b)
		"zhu_rts_inside":
			if actor != sun or not _alive(sun) or not _alive(side_gate): return
			inside_open = true
			b.unregister_building_footprint(side_gate)
			side_gate.resolve_story("retreated")
			b.mission.mark("zhu_gate_opened","孙立接应孙新换旗，偏门已开；军队由玩家自行调入")
			b.msg("偏门已开！可沿北路入庄；前营、外军与工人继续由你指挥。",6.0)
		"zhu_rts_rescue":
			if prisoners_freed: return
			prisoners_freed = true
			for u in prisoners:
				if not _alive(u): continue
				u.faction = Unit.FACTION_LIANG
				u.is_captive = false
				u.is_hero = false # Wounded evacuees remain selectable, not seven extra combat heroes.
				u.base_speed = 82.0
				u.art_variant = ""
				u.queue_redraw()
			b.mission.mark("zhu_prisoners_freed","七名好汉脱困，由玩家护送回前营；伤员不参加战斗")
			b.msg("选中时迁等获救者，右键送回前营。大营仍须攻破；完成时可直接结算或继续护送其余好汉。",8.0)

func _enemy_economy(b, delta: float) -> void:
	if not _alive(enemy_base): return
	train_clock -= delta
	if train_clock > 0.0: return
	train_clock = 22.0
	trained = trained.filter(func(u): return _alive(u))
	if trained.size() >= 18: return
	var spec: Dictionary = TROOPS[ai_trained % TROOPS.size()]
	var cost: Dictionary = b._defs[spec.cost]
	var enemy_pop := 0
	for unit in b.units:
		if _alive(unit) and unit.faction == 1 and not unit.is_building:
			enemy_pop += int(unit.setup_def.get("pop",1))
	if enemy_pop + int(cost.get("pop",1)) > 36: return
	var g := int(cost.get("cost_gold",0))
	var w := int(cost.get("cost_wood",0))
	if not b.faction_spend(1,g,w): return
	var at := OUTPOST+Vector2i(3,0) if _alive(outpost) else Vector2i(14,23)
	var u: Unit = _guard(b,spec.key,at)
	trained.append(u)
	if _alive(outpost): reserve.append(u)
	ai_trained += 1
	ai_spent_gold += g
	ai_spent_wood += w

func _raids(b, delta: float) -> void:
	if not _alive(outpost) or not _alive(enemy_base): return
	raid_clock -= delta
	if raid_clock > 0.0: return
	reserve = reserve.filter(func(u): return _alive(u))
	if reserve.size() < 3:
		raid_clock = 10.0
		return
	var target := CAMP if raids_sent % 2 == 0 or not expansion_secured else EXPANSION
	for u in reserve: u.order_amove(b.map.cell_to_world(target))
	reserve.clear()
	raids_sent += 1
	raid_clock = 90.0
	b.lit_cells[OUTPOST] = 15.0
	b.msg("庄客从南面外营出击！目标：%s。拔掉外营可阻止下一次出击。" % ("梁山前营" if target == CAMP else "北面资源区"),6.0)

func _refresh_stage(b) -> void:
	var next := "siege" if inside_open or main_breached or supply_cut else "contest" if expansion_secured or sent_sun else "scout"
	if next == stage: return
	stage = next
	b.mission.set_title("第三打 · 攻庄救人" if stage == "siege" else "第二打 · 争夺外围")
	b.mission.set_objective("攻破大营、救时迁回营。内应和正面器械都可破局；营地与战果保留。" if stage == "siege" else "夺北面资源扩军，或拔南面外营断援；也可整备器械直接攻庄。")

func process(b, delta: float) -> void:
	elapsed += delta
	_enemy_economy(b,delta)
	_raids(b,delta)
	strategic_clock -= delta
	if strategic_clock > 0.0: return
	strategic_clock = 0.5
	if not expansion_secured and resource_guards.all(func(u): return not _alive(u)):
		for u in b.units:
			if _alive(u) and u.faction == 0 and not u.is_building and not u.is_captive and u.position.distance_to(b.map.cell_to_world(EXPANSION)) < 220.0:
				expansion_secured = true
				b.mission.mark("zhu_resource_secured","北面守军已清，可带工人采集并建设仓库；采集仍需玩家下令")
				b.msg("北面资源区已夺下：新增两处金矿，记得安排工人和防卫。",6.0)
				_introduce_sun(b)
				break
	_refresh_stage(b)
	if prisoners_freed and manor_fallen:
		var safe := 0
		for u in prisoners:
			if _alive(u) and u.position.distance_to(hall.position) < 190.0: safe += 1
		if safe == 7: b.mission.mark("zhu_seven_safe","七名被囚好汉全部撤回前营")
		if _alive(prisoners[0]) and prisoners[0].position.distance_to(hall.position) < 190.0:
			if not b.mission.actions.has("zhu_rts_finish"):
				b.mission.add_action("zhu_rts_finish","宋江：收军结算（可先救齐七人）",CAMP+Vector2i(-4,0),["song_jiang"],1.0,96.0)
				b.msg("核心目标已完成。宋江到前营标记收军即可获胜；也可继续接回其余好汉。",7.0)

func on_unit_resolved(b, u, outcome: String) -> void:
	if u == hu and outcome == "captured":
		b.mission.mark("zhu_hu_captured","扈三娘被生擒，仍作为敌将看押，不转为我军")

func on_unit_died(b, u) -> void:
	if u == hall or u == song or (not prisoners.is_empty() and u == prisoners[0]):
		b.lose("%s失守，本次攻庄失败。可重新部署，调整扩张与防守安排。" % u.display_name)
		return
	if u == outpost:
		supply_cut = true
		b.mission.mark("zhu_supply_cut","庄客外营已毁：停止从此处训练与出击，已出发敌军仍在场")
		b.msg("外营已拔除，后续来袭停止！可集中整军攻庄。",7.0)
		_introduce_sun(b)
	elif u == gate:
		main_breached = true
		b.mission.mark("zhu_gate_breached","正门已被攻破，军队可直接入庄")
	elif u == side_gate:
		b.mission.mark("zhu_side_breached","偏门被强攻攻破")
		b.mission.block_action("zhu_rts_inside","偏门已被攻破，无需再接应；可直接入庄救人。")
	elif u == sun:
		b.mission.block_action("zhu_rts_inside","孙立已阵亡，内应路线关闭；请用器械攻破庄门救人。")
	elif u == enemy_base:
		manor_fallen = true
		b.mission.mark("zhu_manor_fallen","祝家庄大营已毁，敌军停止补兵；护送时迁回前营即可收军")
		b.msg("祝家庄大营已破！无需清空所有敌兵，救时迁回前营后即可结算。",7.0)
	elif u in prisoners:
		b.mission.mark("zhu_prisoner_lost","部分获救好汉未能生还")

func _finish_ready() -> bool:
	return manor_fallen and prisoners_freed and _alive(hall) and not prisoners.is_empty() and _alive(prisoners[0]) and prisoners[0].position.distance_to(hall.position) < 190.0

func top_status(_b) -> String:
	var supply := "外营已断援" if supply_cut else "外营出击约 %d 秒" % maxi(0,ceili(raid_clock))
	return "祝家庄 · %s · %s · %s" % ["攻庄救人" if stage == "siege" else "经营与侦察", "北矿可采" if expansion_secured else "北矿待争", supply]
