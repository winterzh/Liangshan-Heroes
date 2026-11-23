extends LevelBase
## 祝家庄 RTS 样板：同一张地图持续经营，外围兵源可以被切断。
## 不调用旧三日脚本的 clear_campaign_section，不改共享兵种数值。
const T := GameMap.T
const SquadOrders := preload("res://scripts/campaign_squad_orders.gd")
const CAMP := Vector2i(55, 28)
const CAMP_GOLD_CELLS := [Vector2i(51,18), Vector2i(57,18), Vector2i(60,24)]
const MAIN_GATE := Vector2i(20, 28)
const SIDE_GATE := Vector2i(20, 18)
const MAIN_TOWER := Vector2i(17, 30)
const GATE_DEFENDER_POSTS := [Vector2i(15, 26), Vector2i(15, 30), Vector2i(16, 28)]
const INSIDE_ACTION := "zhu_rts_inside"
const SEND_SUN_BUTTON := "zhu_send_sun_li"
const VIEW_SIDE_BUTTON := "zhu_view_side_gate"
const VIEW_DANGER_BUTTON := "zhu_view_evacuation_danger"
const EVACUATION_DANGER_NEAR := 3.0 * GameMap.CELL
const FEINT_RULE := "zhu_feint_rule"
const FEINT_HAPPENED := "zhu_feint_happened"
const FEINT_AT_SIDE := "zhu_feint_at_side"
const FEINT_SHIFTS := ["zhu_feint_guard_0", "zhu_feint_guard_1", "zhu_feint_guard_2"]
const FEINT_PRESSURE_SECONDS := 4.0
const FEINT_RETREAT_SECONDS := 5.0
const ESCORT_RULE := "zhu_ram_escort_rule"
const OUTPOST := Vector2i(36, 39)
const EXPANSION := Vector2i(36, 16)
const PRISON := Vector2i(11, 35)
const INNER_CONTACT := Vector2i(25, 18)
const EVACUATION_RADIUS := 190.0
const EVACUATION_RALLY := CAMP + Vector2i(-3,0)
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
var _evacuation_in_danger := false
var manor_fallen := false
var sent_sun := false
var main_breached := false
var ai_trained := 0
var ai_spent_gold := 0
var ai_spent_wood := 0
var raids_sent := 0
var raiders: Array[Unit] = []
var raid_state := "muster"
var raid_strength := 0
var raid_elapsed := 0.0
var raid_think := 0.0
var raid_home := Vector2.ZERO
var raid_announced := false
var raid_warned := false
var outpost_scouted := false
var expansion_spotted := false
var gate_defenders: Array[Unit] = []
var defense_state := "watch"
var defense_target := Vector2.ZERO
var defense_elapsed := 0.0
var defense_announced := false
var ram_escorts: Array = []

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
	return "先采金伐木、建民居扩军。北面资源可扩张，南营是来袭兵源；守军会迎敌回防，两个入口均有箭楼。可用投石车远拆箭楼、步兵护送撞车攻门，也可由孙立开偏门。设防城门与箭楼只承受25%的普通武器和技能伤害，撞车、投石车不受此限制。"
func intro_lines() -> Array:
	return [
		{"who":"旁白", "key":"narrator", "text":"时迁偷鸡被擒，陷在祝家庄。宋江领兵来到独龙冈，扎下前营，准备探路攻庄救人。本关将原著三次攻庄合为一场持续战斗。"},
		{"who":"宋江", "key":"song_jiang", "text":"先安营整军。北面有钱粮可取，南面庄客营不断来援；先夺哪处，由战局决定。"},
		{"who":"军令", "key":"narrator", "text":"两处庄门都有护庄箭楼，投石车可在箭楼射程外拆除，步兵保护器械。工人采集金木、兵营持续补兵；攻破大营后救时迁回营，保住宋江与前营。"},
	]

func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	# Siege defenses are chapter-local; shared HP, attacks and economic prices stay intact.
	for key in ["zhu_gate", "arrow_tower"]:
		defs[key]["fortification_damage_mult"] = 0.25
		defs[key]["fortification_faction"] = Unit.FACTION_GUAN
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
	if u == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return null
	# Guard the post by engaging nearby intruders and returning after a short chase.
	# Hold Position only attacks enemies already in melee reach and made these
	# defenders spectators while two heroes dismantled the whole manor.
	u.set_stance(Unit.STANCE_DEFEND)
	return u

func _resource(b, key: String, cell: Vector2i, faction: int, amount: float) -> Unit:
	var u: Unit = b.spawn_at(key, faction, cell)
	if u == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return null
	u.res_left = amount
	return u

func deploy(b) -> void:
	hall = b.spawn_at("hall", Unit.FACTION_LIANG, CAMP)
	if hall == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	hall.display_name = "梁山前营"
	var _created_entity_1: Unit = b.spawn_at("barracks", Unit.FACTION_LIANG, Vector2i(55,37))
	if _created_entity_1 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	song = b.spawn_at("song_jiang", Unit.FACTION_LIANG, Vector2i(50,28))
	if song == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	var _created_entity_2: Unit = b.spawn_at("lin_chong", Unit.FACTION_LIANG, Vector2i(49,29))
	if _created_entity_2 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	for i in range(4):
		var _created_entity_3: Unit = b.spawn_at("liang_qiang" if i < 2 else "liang_gong", Unit.FACTION_LIANG, Vector2i(49+i,32))
		if _created_entity_3 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for i in range(6):
		var _created_entity_4: Unit = b.spawn_at("lou_luo", Unit.FACTION_LIANG, Vector2i(53+i,23))
		if _created_entity_4 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		workers.append(_created_entity_4)
	for c in CAMP_GOLD_CELLS:
		var _created_entity_5: Unit = _resource(b,"gold_mine",c,0,1400.0)
		if _created_entity_5 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for c in [Vector2i(59,33),Vector2i(60,36),Vector2i(60,40),Vector2i(51,42),Vector2i(55,43),Vector2i(59,44)]:
		var _created_entity_6: Unit = _resource(b,"tree",c,0,900.0)
		if _created_entity_6 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for c in [Vector2i(34,13),Vector2i(38,13)]:
		var _created_entity_7: Unit = _resource(b,"gold_mine",c,0,4000.0)
		if _created_entity_7 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for c in [Vector2i(31,15),Vector2i(32,12),Vector2i(40,15)]:
		var _created_entity_8: Unit = _resource(b,"tree",c,0,1200.0)
		if _created_entity_8 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for spec in [["zhu_keke",Vector2i(36,18)],["zhu_keke",Vector2i(38,18)],["zhu_gong",Vector2i(33,16)]]:
		var _created_entity_9: Unit = _guard(b,spec[0],spec[1])
		if _created_entity_9 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		resource_guards.append(_created_entity_9)
	gate = b.spawn_at("zhu_gate",1,MAIN_GATE)
	if gate == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	gate.display_name = "祝家庄正门"
	preload("res://scripts/campaign_gate_visual.gd").configure_zhujiazhuang(gate)
	side_gate = b.spawn_at("zhu_gate",1,SIDE_GATE)
	if side_gate == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	side_gate.display_name = "祝家庄偏门"
	side_gate.set_meta("campaign_no_auto_target", true)
	preload("res://scripts/campaign_gate_visual.gd").configure_zhujiazhuang(side_gate)
	# Existing shared towers cover both entrances. Catapults can outrange them;
	# melee defenders protect the towers, making an escorted siege force useful.
	# Offset along the inner wall so roofs do not overlap the gatehouse.
	for c in [MAIN_TOWER,Vector2i(17,20)]:
		var tower: Unit = b.spawn_at("arrow_tower",1,c)
		if tower == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		tower.display_name = "护庄箭楼"
	outpost = b.spawn_at("barracks",1,OUTPOST)
	if outpost == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	outpost.display_name = "庄客外营 · 拆除可断援"
	var _created_entity_10: Unit = _guard(b,"zhu_keke",Vector2i(39,39))
	if _created_entity_10 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	var _created_entity_11: Unit = _guard(b,"zhu_gong",Vector2i(35,36))
	if _created_entity_11 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	hu = _guard(b,"hu_sanniang",Vector2i(33,41))
	if hu == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	hu.defeat_outcome = "captured"
	enemy_base = b.spawn_at("hall",1,Vector2i(10,26))
	if enemy_base == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	enemy_base.display_name = "祝家庄大营 · 核心目标"
	for c in [Vector2i(15,26),Vector2i(15,30),Vector2i(15,19),Vector2i(8,34)]:
		var _created_entity_12: Unit = _guard(b,"zhu_keke",c)
		if _created_entity_12 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		if c in [Vector2i(15,26),Vector2i(15,30)]: gate_defenders.append(_created_entity_12)
	for c in [Vector2i(16,28),Vector2i(16,18),Vector2i(9,32)]:
		var _created_entity_13: Unit = _guard(b,"zhu_gong",c)
		if _created_entity_13 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		if c == Vector2i(16,28): gate_defenders.append(_created_entity_13)
	var _created_entity_14: Unit = _guard(b,"zhu_hu",Vector2i(12,29))
	if _created_entity_14 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	for c in [Vector2i(5,20),Vector2i(10,17)]:
		var _created_entity_15: Unit = _resource(b,"gold_mine",c,1,1600.0)
		if _created_entity_15 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		enemy_nodes.append(_created_entity_15)
	for c in [Vector2i(5,33),Vector2i(6,37),Vector2i(14,39)]:
		var _created_entity_16: Unit = _resource(b,"tree",c,1,1000.0)
		if _created_entity_16 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		enemy_nodes.append(_created_entity_16)
	for i in range(4):
		var _created_entity_17: Unit = b.spawn_at("lou_luo",1,Vector2i(7+i,21))
		if _created_entity_17 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		enemy_workers.append(_created_entity_17)
	for i in range(PRISONERS.size()):
		# Neutral captives do not reveal the manor or occupy the active-hero sidebar.
		var u: Unit = b.spawn_at(PRISONERS[i],2,PRISON+Vector2i(i%3,i/3))
		if u == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
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
	if OS.get_name() == "Windows":
		b.mission.events[FEINT_RULE] = true
		b.mission.events[ESCORT_RULE] = true
	b.mission.enable_scrolling()
	b.mission.add_action("zhu_rts_recon","探路：查看外围战场",Vector2i(42,22),FIELD_ACTORS,1.0,64.0)
	b.mission.add_action("zhu_rts_rescue",Localize.text("救出被囚好汉"),PRISON+Vector2i(4,0),FIELD_ACTORS,3.0,64.0)
	b.mission.add_map_locator("北面资源区", EXPANSION)
	b.mission.add_map_locator("庄客外营", OUTPOST)
	b.mission.add_level_button("zhu_find_camp_gold", "查看 · 前营金矿", "优先查看工人较少的可见前营金矿。")
	b.msg("北面可夺资源，南营可断援。派小队探路，观察外营集结；后方可同时采集、补兵。",8.0)

func _introduce_sun(b) -> void:
	if sent_sun:
		return
	sent_sun = true
	sun = b.spawn_at("sun_li",0,Vector2i(52,25))
	if sun == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	sun.order_hold_position()
	b.mission.add_action("zhu_rts_inside","接应内应，打开偏门",INNER_CONTACT,["sun_li","song_jiang","lin_chong","hua_rong"],5.0,96.0,96.0)
	b.mission.actions["zhu_rts_inside"]["quiet_complete"] = true
	b.mission.add_actor_locator("zhu_rts_inside","sun_li")
	if not _alive(side_gate):
		b.mission.block_action("zhu_rts_inside","偏门已被攻破，无需再接应；可直接入庄救人。")
	_update_inside_shortcut(b)
	b.msg("孙立已到前营！可接应内应开偏门，也可继续正攻。开门前先把接应部队调到附近，庄内守军仍需迎战。",9.0)

func on_mission_action(b, action_id: String, actor) -> void:
	match action_id:
		"zhu_rts_finish":
			if actor != song or not _finish_ready():
				b.mission.actions[action_id]["done"] = false
				b.mission.actions[action_id]["button"].disabled = false
				b.mission.actions[action_id]["marker"].show()
				b.mission.set_status("请先将时迁护送至前营附近，再由宋江收军。")
				return
			if prisoners.all(_at_forward_camp):
				b.mission.mark("zhu_seven_safe","七名被囚好汉全部撤回前营")
			b.mission.mark("zhu_victory","祝家庄大营已破，时迁安全回营")
			b.win("祝家庄已破，时迁归营！营地经营、战场争夺与攻庄救人完成。")
		"zhu_rts_recon":
			b.mission.mark("zhu_route_known","探明北面资源与南面兵源，两条道路均可进军")
			b.lit_cells[EXPANSION] = 30.0
			b.lit_cells[OUTPOST] = 30.0
			_introduce_sun(b)
			if not b._gameplay_rng_issue.is_empty(): return
		"zhu_rts_inside":
			if not _alive(sun) or not _alive(side_gate):
				return
			inside_open = true
			b.unregister_building_footprint(side_gate)
			side_gate.resolve_story("retreated")
			# One success toast only: clear in-flight toasts, then mark the gate-opened line.
			if b.hud != null and b.hud.has_method("_clear_info_toasts"):
				b.hud._clear_info_toasts()
			b.mission.mark("zhu_gate_opened","偏门已开！内应换旗成功，可沿偏门入庄救人；军队由玩家自行调入。")
			if defense_state == "feint" and _has_feint_guards(b.mission):
				b.mission.mark(FEINT_AT_SIDE, "孙立打开偏门时，正门佯攻仍在牵制守军。")
			_commit_gate_defense(b, SIDE_GATE)
		"zhu_rts_rescue":
			if prisoners_freed:
				return
			prisoners_freed = true
			for u in prisoners:
				if not _alive(u):
					continue
				u.faction = Unit.FACTION_LIANG
				u.is_captive = false
				u.is_hero = false # Wounded evacuees remain selectable, not seven extra combat heroes.
				u.base_speed = 82.0
				u.art_variant = ""
				u.queue_redraw()
			_add_evacuation_controls(b)
			b.mission.mark("zhu_prisoners_freed","七名好汉脱困；伤员不参加战斗")
			b.msg(Localize.text("用“选中 · 时迁”或“选中 · 获救队伍”，再轻点前营地面撤离。带兵保护伤员，攻破大营。" if b.hud.touch_ui \
				else "可点“选中 · 时迁”或“选中 · 获救队伍”，再右键送回前营；“查看 · 前营”只移镜头。大营仍须攻破，伤员需要战斗部队保护。"),8.0)


## Rescue controls only select the live evacuees or move the camera. They never
## issue orders, claim a mission action, or include ordinary troops and heroes.
func _rescued_members(only_shi_qian := false) -> Array:
	var candidates: Array = prisoners
	if only_shi_qian:
		candidates = [] if prisoners.is_empty() else [prisoners[0]]
	return candidates.filter(func(u): return _alive(u) and u.faction == Unit.FACTION_LIANG and not u.is_captive and not u.garrisoned)

func _add_evacuation_controls(b) -> void:
	b.mission.add_level_button("zhu_select_shi_qian", "选中 · 时迁", "选中并定位获救者，由你下令撤回前营。")
	b.mission.add_level_button("zhu_select_rescued", "选中 · 获救队伍", "选中并定位获救者，由你下令撤回前营。")
	b.mission.add_map_locator("前营", CAMP)

func _at_forward_camp(u) -> bool:
	return _alive(u) and u.position.distance_to(hall.position) < EVACUATION_RADIUS

func _rescued_outside_camp() -> Array:
	return _rescued_members().filter(func(u): return not _at_forward_camp(u))

func _update_camp_evacuation_control(b) -> void:
	var outside := _rescued_outside_camp()
	var button: Button = b.mission.find_level_button("zhu_select_outside_camp")
	if button == null:
		button = b.mission.add_level_button("zhu_select_outside_camp", "选中 · 尚未归营伤员",
			"只选中尚未抵达前营的可指挥伤员。请选择路线并下令归营。")
	button.disabled = outside.is_empty()
	if not manor_fallen or b.hud.touch_ui:
		return
	var return_button: Button = b.mission.find_level_button("zhu_return_wounded")
	if return_button == null and not outside.is_empty():
		return_button = b.mission.add_level_button("zhu_return_wounded", "送伤员回前营",
			"给尚未归营的伤员下达行军命令。请先派战斗部队清开撤路。")
		var danger_button: Button = b.mission.find_level_button(VIEW_DANGER_BUTTON)
		return_button.get_parent().move_child(return_button, 1 if danger_button != null else 0)
		b.mission.reveal_primary_level_button()
	if return_button != null:
		return_button.disabled = outside.is_empty()

func _evacuation_danger(b) -> Unit:
	if b.hud.touch_ui or not prisoners_freed or not _alive(hall):
		return null
	# Rescue order puts Shi Qian first. Only recent hits and enemies the player can see provide a warning.
	for wounded: Unit in _rescued_outside_camp():
		if wounded._hit_recent_t > 0.0:
			return wounded
		for enemy: Unit in b.units:
			if not _alive(enemy) or enemy.faction != Unit.FACTION_GUAN or enemy.atk <= 0.0 \
					or enemy.is_captive or enemy.garrisoned or enemy._invis_t > 0.0:
				continue
			var reach := maxf(EVACUATION_DANGER_NEAR, enemy.atk_range + enemy.radius + wounded.radius)
			if wounded.position.distance_squared_to(enemy.position) <= reach * reach and b.is_visible_world(enemy.position):
				return wounded
	return null


func _update_evacuation_danger_control(b, wounded: Unit) -> void:
	_evacuation_in_danger = wounded != null
	var button: Button = b.mission.find_level_button(VIEW_DANGER_BUTTON)
	if wounded == null:
		if button != null:
			button.get_parent().remove_child(button)
			button.queue_free()
		return
	if button != null:
		return
	button = b.mission.add_level_button(VIEW_DANGER_BUTTON, "查看 · 撤离险情",
		"把镜头移到遇险伤员。优先定位时迁。")
	button.get_parent().move_child(button, 0)


func _order_wounded_return(b) -> void:
	if not manor_fallen or not prisoners_freed or not _alive(hall) or b.hud.touch_ui or not b._gameplay_rng_issue.is_empty():
		return
	var outside := _rescued_outside_camp()
	if outside.is_empty():
		return
	var pending := outside.filter(func(u: Unit) -> bool:
		return u._state != Unit.ST_MOVE or u._home.distance_to(hall.position) >= EVACUATION_RADIUS \
			or u._path_i >= u._path.size())
	if pending.is_empty():
		b.mission.set_feedback("伤员正在归营途中。")
		return
	var origin: Vector2i = b.map.world_to_cell(pending[0].position)
	var rally_cell: Vector2i = b.map.nearest_open_from(EVACUATION_RALLY, origin)
	var rally: Vector2 = b.map.cell_to_world(rally_cell)
	if rally_cell.x < 0 or rally.distance_to(hall.position) >= EVACUATION_RADIUS:
		b.mission.set_feedback("前营附近没有落脚点。请清开道路后再下令归营。")
		return
	var targets: Array = b._formation_targets(pending, rally)
	var pace: float = b._group_speed_cap(pending)
	b._stamp_manual(pending)
	for i in range(pending.size()):
		var target: Vector2 = targets[i]
		if target.distance_to(hall.position) >= EVACUATION_RADIUS:
			target = rally
		pending[i].order_move(target, false, pace)
	b.select_members(outside, false)
	Sfx.play("order")
	b.mission.set_feedback(Localize.format_text("已派%d名伤员返回前营。", [pending.size()]))

func _inside_action_available(b, action: Dictionary) -> bool:
	return not action.is_empty() and not action.done and String(action.get("blocked_reason", "")).is_empty() \
		and _alive(side_gate) and b.mission._valid_action_actor(sun, action)


func _side_gate_is_open(b) -> bool:
	return inside_open or b.mission.has_event("zhu_side_breached")


func _sun_ordered_to_side_gate(b) -> bool:
	return (sun.mission_order_active or sun.mission_order_arrival_t > 0.0) \
		and b.mission._nearest_clicked_action(sun.mission_order_target) == INSIDE_ACTION


func _update_inside_shortcut(b) -> void:
	var opened := _side_gate_is_open(b)
	if b.hud.touch_ui or (not sent_sun and not opened):
		return
	var action: Dictionary = b.mission.actions.get(INSIDE_ACTION, {})
	var button: Button = b.mission.find_level_button(SEND_SUN_BUTTON)
	if opened or not _inside_action_available(b, action):
		if button != null:
			button.get_parent().remove_child(button)
			button.queue_free()
	elif button == null:
		button = b.mission.add_level_button(SEND_SUN_BUTTON, "派孙立去偏门",
			"派孙立前往偏门旗标接应。等他到场并完成接应后，军队才能从偏门进入。")
		button.get_parent().move_child(button, 0)
		b.mission.reveal_primary_level_button()
	if opened and b.mission.find_level_button(VIEW_SIDE_BUTTON) == null:
		var locator: Button = b.mission.add_level_button(VIEW_SIDE_BUTTON, "查看 · 偏门",
			"只定位地图；选人和移动仍由玩家指挥。")
		locator.get_parent().move_child(locator, 0)
		b.mission.reveal_primary_level_button()


func _order_sun_to_side_gate(b) -> void:
	if b.hud.touch_ui or not b._gameplay_rng_issue.is_empty():
		return
	var action: Dictionary = b.mission.actions.get(INSIDE_ACTION, {})
	if not _inside_action_available(b, action) or b.mission.active_action_id == INSIDE_ACTION:
		return
	if _sun_ordered_to_side_gate(b):
		return
	var target: Vector2 = b.map.cell_to_world(action.cell)
	var path: PackedVector2Array = b.map.find_path(sun.position, target, sun.faction, sun.movement_profile)
	if path.is_empty() or path[-1].distance_to(target) > float(action.reach) \
			or not b.map._segment_open(path[-1], target, sun.movement_profile):
		b.mission.set_feedback("暂时走不到旗标。请清开道路或手动改道。")
		return
	var group := [sun]
	var move: Dictionary = b.mission.prepare_manual_move(group, target)
	if move.is_empty() or move.actor != sun:
		return
	b._stamp_manual(group)
	sun.order_move(move.target)
	b._stamp_mission_move(group, target)
	Sfx.play("order")
	b.mission.set_feedback("孙立已前往偏门接应。")


func activate_mission_button(b, button_id: String) -> void:
	if b.phase != b.Phase.FIGHT: return
	if button_id == SEND_SUN_BUTTON:
		_order_sun_to_side_gate(b)
		return
	if button_id == VIEW_SIDE_BUTTON:
		if not b.hud.touch_ui and _side_gate_is_open(b):
			b.mission._activate_map_locator("祝家庄偏门", SIDE_GATE)
		return
	if button_id == VIEW_DANGER_BUTTON:
		var wounded := _evacuation_danger(b)
		if wounded != null:
			b.mission._activate_map_locator(wounded.display_name, b.map.world_to_cell(wounded.position))
		return
	if button_id == "zhu_return_wounded":
		_order_wounded_return(b)
		return
	if button_id == "zhu_find_camp_gold":
		_view_camp_gold(b)
		return
	if button_id == "zhu_select_outside_camp":
		if prisoners_freed and _alive(hall):
			var outside := _rescued_outside_camp()
			if not outside.is_empty():
				b.select_members(outside, false)
				b.mission.set_feedback(Localize.format_text("已选中尚未归营的伤员：%d 人。请下令归营。", outside.size()))
		return
	if button_id not in ["zhu_select_shi_qian", "zhu_select_rescued"]: return
	var only_shi_qian := button_id == "zhu_select_shi_qian"
	var members := _rescued_members(only_shi_qian)
	if members.is_empty():
		b.mission.set_status("时迁当前无法行动。" if only_shi_qian else "当前没有可选择的获救者。")
		return
	b.select_members(members, false)
	b.center_camera_cell(b.map.world_to_cell(members[0].position))
	if b.hud.touch_ui:
		b.mission.set_status("已选中时迁。轻点前营地面撤离。" if only_shi_qian else "已选中获救队伍。轻点前营地面撤离。")
	else:
		b.mission.set_status("已选中时迁；请右键下令撤回前营。" if only_shi_qian else "已选中获救队伍；请右键下令撤回前营。")


func _view_camp_gold(b) -> void:
	var assignments := {}
	for u in b.units:
		if _alive(u) and u.faction == Unit.FACTION_LIANG and u.is_worker \
				and u._state in [Unit.ST_GATHER, Unit.ST_RETURN] and is_instance_valid(u._gather_node):
			assignments[u._gather_node] = int(assignments.get(u._gather_node, 0)) + 1
	var best: Unit = null
	var fewest := 0
	for mine in b.units:
		if not _alive(mine) or mine.key != "gold_mine" or mine.res_left <= 0.0:
			continue
		if b.map.world_to_cell(mine.position) not in CAMP_GOLD_CELLS \
				or not b.is_visible_world(mine.position) or b._resource_blocked(mine):
			continue
		var count := int(assignments.get(mine, 0))
		if best == null or count < fewest or (count == fewest and mine.res_left > best.res_left):
			best = mine
			fewest = count
	if best == null:
		b.mission.set_feedback("前营暂无可见的可采金矿。可争夺北矿，或在集市卖木。", 5.0)
		return
	b.center_camera_cell(b.map.world_to_cell(best.position))
	var prompt := "此矿约剩%d金，%d名工人采运。选工人后轻点金矿采集。" if b.hud.touch_ui \
		else "此矿约剩%d金，%d名工人采运。选工人右键金矿可采集。"
	b.mission.set_feedback(Localize.format_text(prompt, [ceili(best.res_left), fewest]), 5.0)


func _enemy_economy(b, delta: float) -> void:
	if not _alive(enemy_base):
		return
	train_clock -= delta
	if train_clock > 0.0:
		return
	train_clock = 22.0
	trained = trained.filter(func(u): return _alive(u))
	if trained.size() >= 18:
		return
	var spec: Dictionary = TROOPS[ai_trained % TROOPS.size()]
	var cost: Dictionary = b._defs[spec.cost]
	var enemy_pop := 0
	for unit in b.units:
		if _alive(unit) and unit.faction == 1 and not unit.is_building:
			enemy_pop += int(unit.setup_def.get("pop",1))
	if enemy_pop + int(cost.get("pop",1)) > 36:
		return
	var g := int(cost.get("cost_gold",0))
	var w := int(cost.get("cost_wood",0))
	if not b.faction_spend(1,g,w):
		return
	var at := OUTPOST+Vector2i(3,0) if _alive(outpost) else Vector2i(14,23)
	var u: Unit = _guard(b,spec.key,at)
	if u == null:
		b.add_resources(g,w,1)
		return
	trained.append(u)
	if _alive(outpost):
		reserve.append(u)
	ai_trained += 1
	ai_spent_gold += g
	ai_spent_wood += w

func _raids(b, delta: float) -> void:
	if raid_state == "muster": raid_clock = maxf(0.0, raid_clock - delta)
	else: raid_elapsed += delta
	raid_think -= delta
	if raid_think > 0.0: return
	raid_think = 0.5
	reserve.assign(SquadOrders.survivors(reserve))
	raiders.assign(SquadOrders.survivors(raiders))
	var home_alive := _alive(outpost) and _alive(enemy_base)
	var seeing_post: bool = _alive(outpost) and b.is_visible_world(outpost.position)
	if seeing_post: outpost_scouted = true
	_observe_expansion(b)
	if raid_state == "attack":
		if not raid_announced and _raiders_visible(b):
			raid_announced = true
			b.msg("发现庄客出击队！可拦截来敌，或留兵守营、另队进攻外营。",6.0)
		if raiders.is_empty():
			_reset_raid()
			return
		if SquadOrders.should_withdraw(raiders, raid_strength) or raid_elapsed >= 75.0:
			raid_state = "retreat"
			raid_elapsed = 0.0
			raid_home = b.map.cell_to_world(OUTPOST + Vector2i(3,0) if home_alive else Vector2i(25,28))
			SquadOrders.withdraw(raiders, raid_home)
			if _raiders_visible(b):
				b.msg("庄客正在退守！可以追击，也可趁空当补兵、争夺外围。",6.0)
		return
	if raid_state == "retreat":
		var next_home: Vector2 = b.map.cell_to_world(OUTPOST + Vector2i(3,0) if home_alive else Vector2i(25,28))
		if raid_home != next_home:
			raid_home = next_home
			SquadOrders.withdraw(raiders, raid_home)
		if raiders.is_empty() or SquadOrders.gathered(raiders, raid_home) or raid_elapsed >= 45.0:
			SquadOrders.guard(raiders)
			if home_alive:
				# Only troops that really returned rejoin the next raid. Stragglers
				# remain ordinary defenders; no off-map regroup or free healing.
				for u in raiders:
					if u.position.distance_to(raid_home) <= 150.0 and u not in reserve:
						reserve.append(u)
			_reset_raid()
		return
	if not home_alive: return
	if raid_clock <= 20.0 and reserve.size() >= 3 and seeing_post and not raid_warned:
		raid_warned = true
		b.msg("侦察：南营庄客正在集结，准备出击。可提前布防，也可攻击外营打乱集结。",7.0)
	if raid_clock > 0.0 or reserve.size() < 3: return
	# Never order reinforcements still fighting far from the assembly point.
	var rally: Vector2 = b.map.cell_to_world(OUTPOST + Vector2i(3,0))
	for u in reserve:
		if u.position.distance_to(rally) <= 180.0: raiders.append(u)
	if raiders.size() < 3:
		raiders.clear()
		return
	for u in raiders: reserve.erase(u)
	raid_strength = raiders.size()
	raid_state = "attack"
	raid_elapsed = 0.0
	raid_announced = false
	var target := EXPANSION if expansion_spotted and raids_sent % 2 == 1 else CAMP
	SquadOrders.advance(raiders, b.map.cell_to_world(target))
	raids_sent += 1

func _reset_raid() -> void:
	raiders.clear()
	raid_state = "muster"
	raid_strength = 0
	raid_elapsed = 0.0
	raid_clock = 60.0
	raid_announced = false
	raid_warned = false

func _raiders_visible(b) -> bool:
	return raiders.any(func(u): return _alive(u) and b.is_visible_world(u.position))

func _observe_expansion(b) -> void:
	if expansion_spotted: return
	var at: Vector2 = b.map.cell_to_world(EXPANSION)
	# Target knowledge comes from an actual enemy observer, not the player's
	# expansion_secured flag or the player's fog cache.
	for target in b.units:
		if not _alive(target) or target.faction != Unit.FACTION_LIANG or target.is_captive or target.garrisoned:
			continue
		if target.position.distance_to(at) > 180.0: continue
		for observer in resource_guards + reserve + raiders:
			if not _alive(observer): continue
			var sight := float(observer.setup_def.get("sight", 8)) * GameMap.CELL
			if observer.position.distance_to(target.position) <= sight and b.target_visible_to(observer, target):
				expansion_spotted = true
				return

func _commit_gate_defense(b, entrance: Vector2i) -> void:
	# Reassign existing guards once: opening the other entrance can then flank
	# this response. No extra spawn and no tracking of units behind player fog.
	if defense_state == "feint" and entrance == SIDE_GATE:
		return
	if defense_state not in ["watch", "feint", "returning"]: return
	if defense_state != "watch":
		_clear_feint_shifts(b.mission)
	gate_defenders.assign(SquadOrders.survivors(gate_defenders))
	if gate_defenders.is_empty():
		defense_state = "guard"
		return
	defense_state = "moving"
	defense_target = b.map.cell_to_world(entrance + Vector2i(-5,0))
	defense_elapsed = 0.0
	SquadOrders.advance(gate_defenders, defense_target)

func _gate_defense_tick(b, delta: float) -> void:
	if defense_state != "moving": return
	defense_elapsed += delta
	gate_defenders.assign(SquadOrders.survivors(gate_defenders))
	if not defense_announced and gate_defenders.any(func(u): return b.is_visible_world(u.position)):
		defense_announced = true
		b.msg("发现守军向入口增援！可迎击，也可另开一路，从侧翼入庄。",7.0)
	if gate_defenders.is_empty() or SquadOrders.gathered(gate_defenders, defense_target, 100.0) or defense_elapsed >= 45.0:
		SquadOrders.guard(gate_defenders)
		defense_state = "guard"

func _front_tower(b) -> Unit:
	var at: Vector2 = b.map.cell_to_world(MAIN_TOWER)
	for u in b.units:
		if _alive(u) and u.faction == Unit.FACTION_GUAN and u.key == "arrow_tower" and u.position.distance_to(at) < GameMap.CELL * 0.5:
			return u
	return null

func _front_is_pressured(b, tower: Unit) -> bool:
	if not _alive(tower) or not _alive(gate):
		return false
	var ahead: float = gate.position.x
	var count := 0
	for u in b.units:
		if not _alive(u) or u.faction != Unit.FACTION_LIANG or u.position.x <= ahead or u.is_building \
				or u.is_worker or u.is_noncombat or u.is_captive or u.garrisoned or u.is_summon or u.atk <= 0.0:
			continue
		if u.position.distance_to(tower.position) <= tower.atk_range + tower.radius + u.radius \
				and b.target_visible_to(tower, u):
			count += 1
			if count >= 2:
				return true
	return false

func _has_feint_guards(mission) -> bool:
	for index in range(mini(gate_defenders.size(), FEINT_SHIFTS.size())):
		if mission.has_event(FEINT_SHIFTS[index]) and _alive(gate_defenders[index]):
			return true
	return false


func _clear_feint_shifts(mission) -> void:
	for key: String in FEINT_SHIFTS:
		mission.events.erase(key)

func _feint_tick(b, seconds: float) -> void:
	if not b.mission.has_event(FEINT_RULE) or defense_state not in ["watch", "feint", "returning"] \
			or gate_defenders.size() > FEINT_SHIFTS.size():
		return
	if defense_state == "returning":
		var still_returning := false
		for index in range(gate_defenders.size()):
			var guard := gate_defenders[index]
			if not b.mission.has_event(FEINT_SHIFTS[index]) or not _alive(guard):
				continue
			if guard.position.distance_to(b.map.cell_to_world(GATE_DEFENDER_POSTS[index])) > 32.0:
				still_returning = true
			elif guard.stance == Unit.STANCE_PASSIVE:
				SquadOrders.guard([guard])
		if still_returning:
			return
		_clear_feint_shifts(b.mission)
		defense_state = "watch"
		# If the side gate opened during the diversion, the guards can now react to it.
		if inside_open or b.mission.has_event("zhu_side_breached"):
			_commit_gate_defense(b, SIDE_GATE)
		return
	var pressured := _front_is_pressured(b, _front_tower(b))
	if defense_state == "feint":
		defense_elapsed = 0.0 if pressured else defense_elapsed + seconds
		if defense_elapsed < FEINT_RETREAT_SECONDS:
			return
		defense_state = "returning"
		defense_elapsed = 0.0
		for index in range(gate_defenders.size()):
			var guard := gate_defenders[index]
			if b.mission.has_event(FEINT_SHIFTS[index]) and _alive(guard):
				guard.order_move(b.map.cell_to_world(GATE_DEFENDER_POSTS[index]))
				guard.set_stance(Unit.STANCE_PASSIVE)
		b.msg("正门压力已解除，守军返回原来的岗位。", 5.0)
		return
	var available := SquadOrders.survivors(gate_defenders)
	defense_elapsed = defense_elapsed + seconds if pressured and available.size() >= 2 else 0.0
	if defense_elapsed < FEINT_PRESSURE_SECONDS:
		return
	defense_state = "feint"
	defense_elapsed = 0.0
	defense_target = b.map.cell_to_world(MAIN_GATE + Vector2i(-2, 0))
	# The final living member keeps guarding the interior. Slots are stable
	# across death, retreat and save/load so orders always address originals.
	for member in available.slice(0, -1):
		var index := gate_defenders.find(member)
		b.mission.events[FEINT_SHIFTS[index]] = true
		var offset := Vector2(0.0, -25.0 if index == 0 else 25.0)
		SquadOrders.advance([member], defense_target + offset)
	if not b.mission.mark(FEINT_HAPPENED, "正门佯攻引开部分守军。保持压力，可让孙立从偏门接应。"):
		b.msg("正门佯攻引开部分守军。保持压力，可让孙立从偏门接应。", 5.0)

static func escort_footman(u: Unit) -> bool:
	return SquadOrders.alive(u) and u.faction == Unit.FACTION_LIANG and u.movement_profile == "land" \
		and not (u.is_worker or u.is_hero or u.is_building or u.is_cavalry or u.is_captive or u.garrisoned or u.is_summon) \
		and u.atk > 0.0 and not u.key.begins_with("siege_")


static func escort_ram(u: Unit) -> bool:
	return SquadOrders.alive(u) and u.faction == Unit.FACTION_LIANG and u.key == "siege_ram"


func try_ram_escort(b, screen_point: Vector2, movers: Array) -> bool:
	if not b.mission.has_event(ESCORT_RULE):
		return false
	var foot := movers.filter(escort_footman)
	if foot.is_empty():
		return false
	var ram: Unit = b._unit_at(screen_point)
	if not escort_ram(ram):
		return false
	b._stamp_manual(foot)
	for u: Unit in foot:
		u.order_stop()
		u.passive = false
		u._amove_dest = Vector2.ZERO
		u.set_stance(Unit.STANCE_DEFEND)
		ram_escorts.append([u, ram])
	_escort_tick(b)
	b.msg(Localize.format_text("%d 名步兵护卫撞车。给步兵下新命令可解除护卫。", foot.size()), 4.0)
	return true


func cancel_ram_escort(movers: Array) -> void:
	if not ram_escorts.is_empty():
		ram_escorts = ram_escorts.filter(func(pair): return not movers.has(pair[0]))


func _escort_tick(b) -> void:
	var slots := {}
	for index in range(ram_escorts.size() - 1, -1, -1):
		var pair: Array = ram_escorts[index]
		if not is_instance_valid(pair[0]) or not escort_footman(pair[0]) or not is_instance_valid(pair[1]) or not escort_ram(pair[1]):
			if is_instance_valid(pair[0]) and escort_footman(pair[0]):
				pair[0].order_stop()
			ram_escorts.remove_at(index)
	for pair: Array in ram_escorts:
		var foot: Unit = pair[0]
		var ram: Unit = pair[1]
		var slot: int = slots.get(ram, 0)
		slots[ram] = slot + 1
		var reach := ram.radius + foot.radius + 22.0 + float(slot / 8) * 32.0
		var dest := ram.position + Vector2.from_angle(float(slot % 8) * TAU / 8.0) * reach
		if not b.map.is_open_world(dest, foot.movement_profile):
			dest = b.map.cell_to_world(b.map.nearest_open_from(b.map.world_to_cell(dest), b.map.world_to_cell(foot.position), foot.movement_profile))
		if foot._state == Unit.ST_MOVE:
			if foot._home.distance_to(dest) > 48.0 and foot.position.distance_to(dest) > 42.0:
				foot._begin_move(dest)
		else:
			# Existing guard stance uses this anchor for short pursuit and return.
			foot._home = dest
			foot._has_home = true


func unit_tactical_hint(b, u: Unit) -> String:
	if not _alive(u) or u.garrisoned or u._invis_t > 0.0:
		return ""
	if u.faction == Unit.FACTION_GUAN and not b.is_visible_world(u.position):
		return ""
	if escort_ram(u) and b.mission.has_event(ESCORT_RULE):
		var count := 0
		for pair: Array in ram_escorts:
			if is_instance_valid(pair[1]) and pair[1] == u:
				count += 1
		if count > 0:
			return Localize.format_text("撞车护卫 · %d 名步兵跟随", count)
		return Localize.text("选中步兵，右键这辆撞车即可指定护卫。")
	if u == outpost:
		return Localize.text("拆掉外营可断新援；已出击的庄客仍在场。")
	if u in resource_guards:
		return Localize.text("北矿守军。击退守军后派兵占住矿区，再调工人采金。")
	if u == gate:
		if b.mission.has_event(FEINT_RULE):
			if defense_state == "feint" and _has_feint_guards(b.mission):
				return Localize.text("正门佯攻生效 · 部分守军已被引向正门")
			if defense_state == "returning" and _has_feint_guards(b.mission):
				return Localize.text("佯攻已解除 · 守军正返回原岗位")
			if defense_state == "watch" and _alive(_front_tower(b)) and SquadOrders.survivors(gate_defenders).size() >= 2:
				return Localize.text("正门佯攻 · 两名战斗单位进入箭楼射程，持续4秒可牵制守军")
		return Localize.text("正攻可先用投石车拆箭楼，再让步兵护撞车攻门。")
	if u == side_gate:
		if _alive(sun):
			return Localize.text("孙立在阵。前往接应标记可开偏门，也可用器械强攻。")
		if sent_sun:
			return Localize.text("内应已失。可带器械攻破偏门。")
		return Localize.text("偏门可强攻，也可侦察外围寻找内应。")
	if u == sun and _alive(side_gate):
		return Localize.text("选中孙立，轻点接应旗标打开偏门。" if b.hud.touch_ui else "选中孙立，右键接应标记打开偏门。")
	return ""


func _refresh_stage(b) -> void:
	var side_open := _side_gate_is_open(b)
	stage = "siege" if main_breached or side_open or supply_cut or manor_fallen or prisoners_freed else "contest" if expansion_secured or sent_sun else "scout"
	var heading := "第一打 · 扎营探路"
	var objective := "北取资源，南拔外营；兵营补兵、作坊造器械。先侦察，再决定主攻方向。"
	if stage == "contest":
		heading = "第二打 · 争夺外围"
		objective = "夺北面资源扩军，或拔南面外营断援；也可整备器械直接攻庄。"
	elif stage == "siege":
		heading = "第三打 · 攻庄救人"
		objective = "攻破大营、救时迁回营。内应和正面器械都可破局；营地与战果保留。"
		if main_breached and side_open:
			objective = "正门和偏门都已通行。可分兵牵制守军、进牢院救人。还需攻破大营、护送时迁回前营。"
		elif side_open:
			objective = "偏门已可通行。可派护卫入庄救人，也可从正门牵制守军。还需攻破大营、护送时迁回前营。"
		elif main_breached and not supply_cut:
			objective = "正门已破。留兵守前营，护送器械破营，救时迁回营。缺金可查看前营金矿或在集市卖木，也可先断援。"
		elif supply_cut and not main_breached:
			objective = "南营已断援，庄内大营仍可补兵。可带器械攻正门，或接应孙立打开偏门。" if _alive(sun) else "孙立已阵亡，内应路线关闭；请用器械攻破庄门救人。"
	if not main_breached and not side_open and _alive(sun):
		var feint := defense_state == "feint" and _has_feint_guards(b.mission)
		if not b.hud.touch_ui and b.mission.active_action_id == INSIDE_ACTION:
			objective = "偏门接应中。保持正门压力，让接应者留在旗标旁。" if feint \
				else "偏门接应中。让接应者留在旗标旁，部队在门外掩护。"
		elif not b.hud.touch_ui and _sun_ordered_to_side_gate(b):
			objective = "孙立正赶往偏门。保持正门压力，派部队在偏门外掩护。" if feint \
				else "孙立正赶往偏门。部队可在门外掩护，开门后再入庄。"
		elif feint:
			objective = "部分守军已被引向正门。保持正门压力，让孙立到偏门接应；还需破营、救出时迁。"
	var danger: Unit
	if prisoners_freed:
		danger = _evacuation_danger(b)
		_update_evacuation_danger_control(b, danger)
	if _finish_ready():
		heading = "收军 · 时迁已归营"
		if b.mission.has_event("zhu_prisoner_lost"):
			objective = "本局有伤员阵亡，七人全返演义已失败。宋江可到前营收军，完成主目标。"
		elif b.mission.has_event("zhu_seven_safe"):
			objective = "七人全返演义已达成。让宋江到前营收军标记即可结算。"
		elif danger != null:
			objective = "宋江可立即收军。想取得七人全返演义，可先点「查看 · 撤离险情」，派兵掩护余下伤员。"
		else:
			objective = "宋江可立即收军。想取得七人全返演义，先选中尚未归营的伤员，把他们送回前营。" if b.hud.touch_ui \
				else "宋江可立即收军。想取得七人全返演义，可先点「送伤员回前营」。"
	elif manor_fallen and prisoners_freed:
		heading = "撤离 · 护送伤员"
		objective = "大营已破，敌军不再补兵。先清理撤路，再护送时迁回前营；其余好汉全部生还是可选演义目标。" if b.hud.touch_ui \
			else "先清开撤路，再点「送伤员回前营」。时迁归营即可收军，七人全返另记演义印。"
		if danger != null:
			objective = "时迁有危险。点「查看 · 撤离险情」并派兵掩护。时迁归营即可收军。" if danger == prisoners[0] \
				else "有伤员遇险。点「查看 · 撤离险情」并派兵掩护。时迁归营即可收军。"
	elif manor_fallen:
		heading = "营救 · 前往牢院"
		objective = "大营已破，敌军不再补兵。派战斗部队掩护，在牢院标记救人，再护送时迁回前营。"
	elif prisoners_freed:
		heading = "分兵 · 护送与攻营"
		objective = "伤员已获救，可先护送回营；另队仍须攻破祝家庄大营。宋江、时迁与前营必须存活。"
		if danger != null:
			objective = "有伤员遇险。点「查看 · 撤离险情」并派兵掩护，另队仍须攻破祝家庄大营。"
	if b.mission.stage_title != heading: b.mission.set_title(heading)
	if b.mission.objective != objective: b.mission.set_objective(objective)

func process(b, delta: float) -> void:
	elapsed += delta
	_enemy_economy(b,delta)
	if not b._gameplay_rng_issue.is_empty(): return
	_raids(b,delta)
	_gate_defense_tick(b,delta)
	strategic_clock -= delta
	if strategic_clock > 0.0:
		return
	strategic_clock = 0.5
	_feint_tick(b, 0.5)
	_update_inside_shortcut(b)
	if not ram_escorts.is_empty():
		_escort_tick(b)
	preload("res://scripts/zhujiazhuang_recovery_hint.gd").refresh(b)
	if not expansion_secured and resource_guards.all(func(u): return not _alive(u)):
		for u in b.units:
			if _alive(u) and u.faction == 0 and not u.is_building and not u.is_captive and u.position.distance_to(b.map.cell_to_world(EXPANSION)) < 220.0:
				expansion_secured = true
				b.mission.mark("zhu_resource_secured","北面守军已清，可带工人采集并建设仓库；采集仍需玩家下令")
				b.msg("北面资源区已夺下：新增两处金矿，记得安排工人和防卫。",6.0)
				_introduce_sun(b)
				if not b._gameplay_rng_issue.is_empty(): return
				break
	if prisoners_freed and _alive(hall):
		_update_camp_evacuation_control(b)
	if prisoners_freed and manor_fallen and _alive(hall):
		if prisoners.size() == PRISONERS.size() and prisoners.all(_at_forward_camp):
			b.mission.mark("zhu_seven_safe","七名被囚好汉全部撤回前营")
		if _finish_ready():
			if not b.mission.actions.has("zhu_rts_finish"):
				b.mission.add_action("zhu_rts_finish",Localize.text("宋江：收军结算（可先救齐七人）"),CAMP+Vector2i(-4,0),["song_jiang"],1.0,96.0)
				b.msg("时迁已到前营。可由宋江在收军标记完成主目标。",7.0)
	_refresh_stage(b)

func on_unit_resolved(b, u, outcome: String) -> void:
	if u == hu and outcome == "captured":
		b.mission.mark("zhu_hu_captured","扈三娘被生擒，仍作为敌将看押，不转为我军")

func on_unit_died(b, u) -> void:
	for index in range(ram_escorts.size() - 1, -1, -1):
		var pair: Array = ram_escorts[index]
		if is_instance_valid(pair[1]) and pair[1] == u:
			if is_instance_valid(pair[0]) and escort_footman(pair[0]):
				pair[0].order_stop()
			ram_escorts.remove_at(index)
		elif is_instance_valid(pair[0]) and pair[0] == u:
			ram_escorts.remove_at(index)
	if u == hall:
		b.lose("前营被攻破，本次攻庄失败。\n留兵回防；选工人右键受损建筑可修理。\n出征前先处理来袭敌军，避免营地失守。")
		return
	if u == song:
		b.lose("宋江阵亡，本次攻庄失败。\n先让普通兵侦察、掩护，再让英雄支援；避免孤军接敌。")
		return
	if not prisoners.is_empty() and u == prisoners[0]:
		if prisoners_freed:
			b.lose("时迁遇难，本次护送失败。\n先确认撤退路线安全，再让战斗部队护送伤员回前营。\n获救者不会反击，也不会自行撤离。")
		else:
			b.lose("时迁遇难，本次营救失败。\n先清理囚徒附近威胁，再由战斗部队掩护救援。\n时迁无法战斗，需要保护。")
		return
	if u == outpost:
		supply_cut = true
		b.mission.mark("zhu_supply_cut","庄客外营已毁：停止从此处训练与出击，已出发敌军仍在场")
		b.msg("南营已拔除，不再派出新的来袭队。已出发的敌军仍在，庄内大营仍可补兵。",7.0)
		_introduce_sun(b)
		if not b._gameplay_rng_issue.is_empty(): return
	elif u == gate:
		main_breached = true
		b.mission.mark("zhu_gate_breached","正门已被攻破，军队可直接入庄")
		_commit_gate_defense(b, MAIN_GATE)
	elif u == side_gate:
		b.mission.mark("zhu_side_breached","偏门被强攻攻破")
		b.mission.block_action("zhu_rts_inside","偏门已被攻破，无需再接应；可直接入庄救人。")
		_commit_gate_defense(b, SIDE_GATE)
	elif u == sun:
		b.mission.block_action("zhu_rts_inside","孙立已阵亡，内应路线关闭；请用器械攻破庄门救人。")
	elif u == enemy_base:
		manor_fallen = true
		b.mission.mark("zhu_manor_fallen","祝家庄大营已毁，敌军停止补兵；护送时迁回前营即可收军")
		b.msg("祝家庄大营已破！无需清空所有敌兵，救时迁回前营后即可结算。",7.0)
	elif u in prisoners:
		b.mission.mark("zhu_prisoner_lost","部分获救好汉未能生还")

func campaign_debrief(mission) -> Array[Dictionary]:
	var side_result := "偏门未开"
	if inside_open:
		side_result = "孙立已打开偏门"
	elif mission.has_event("zhu_side_breached"):
		side_result = "偏门由强攻打开"
	var rows: Array[Dictionary] = [
		{"source": "北矿 · %s", "args": ["已夺下" if expansion_secured else "未夺下"]},
		{"source": "南营 · %s · 共派出 %d 队", "args": ["已断援" if supply_cut else "外营未拆", raids_sent]},
		{"source": "入口 · %s · %s", "args": ["正门已攻破" if main_breached else "正门未破", side_result]},
	]
	if mission.has_event(FEINT_AT_SIDE):
		rows.append({"source": "重玩建议 · 本局佯攻接应成功。下次可集中兵力，护送撞车直攻正门。"})
	elif not supply_cut and raids_sent > 0:
		rows.append({"source": "重玩建议 · 南营派出%d队。下次可先断援，再集中兵力攻门。", "args": [raids_sent]})
	elif mission.has_event(FEINT_RULE) and not inside_open:
		rows.append({"source": "重玩建议 · 可试用正门佯攻牵制守军，同时派孙立接应偏门。"})
	return rows

func _finish_ready() -> bool:
	return manor_fallen and prisoners_freed and _alive(hall) and not prisoners.is_empty() and _at_forward_camp(prisoners[0])

func top_status(b) -> String:
	if _evacuation_in_danger and not b.mission._expanded:
		return Localize.text("祝家庄 · 伤员遇险 · 查看任务目标")
	if manor_fallen and prisoners_freed and _alive(hall):
		var arrived := prisoners.filter(_at_forward_camp).size()
		var lost := PRISONERS.size() - prisoners.filter(_alive).size()
		return Localize.format_text("祝家庄 · 伤员归营 %d/%d · 阵亡 %d", [arrived, PRISONERS.size(), lost])
	var supply := "南营情报需侦察"
	if manor_fallen:
		supply = "大营停止补兵"
	elif raid_state == "attack" and _raiders_visible(b):
		supply = "南营已断援 · 残部仍在出击" if supply_cut else "庄客正在出击"
	elif raid_state == "retreat" and _raiders_visible(b):
		supply = "南营已断援 · 残部正在退守" if supply_cut else "庄客正在退守"
	elif supply_cut:
		supply = "南营已断援 · 庄内仍可补兵"
	elif _alive(outpost) and b.is_visible_world(outpost.position):
		supply = "南营正在集结" if reserve.size() >= 3 else "南营正在补兵"
	elif outpost_scouted:
		supply = "南营暂无新情报"
	return Localize.format_text("祝家庄 · %s · %s · %s", ["攻庄救人" if stage == "siege" else "经营与侦察", "北矿可采" if expansion_secured else "北矿待争", supply])
