extends LevelBase
## 鲁智深暗护林冲：尾随、拦棍、求情、照料、相送。没有陆谦到场和虚构追兵军团。
const T := GameMap.T
const GATE_E := Vector2i(49, 20)
const EXIT_W := Vector2i(3, 20)
const PINE := Vector2i(27, 20)
const WATCH := Vector2i(33, 20)
const AMBUSH := Vector2i(45, 16)
const EXEC_TIME := 42.0
const RESCUE_R := 86.0
const EXIT_R := 120.0
const REST := Vector2i(16, 20)
const SHADOW_TOO_CLOSE_R := 112.0
const SHADOW_TOO_FAR_R := 240.0
const SHADOW_CAUTION_TIME := 0.8
const SHADOW_EXPOSE_TIME := 2.4
enum { STALK, RESCUE, CARE, ESCAPE }
var lin_bound: Unit
var lin_freed: Unit
var lu: Unit
var escorts: Array = []
var st := STALK
var exec_timer := EXEC_TIME
var rescued := false
var alarm := false
var wave_t := 0.0
var wave_n := 0
var smoke_t := 0.0
var tracking_done := false
var treated := false
var shadow_route := ""
var shadow_attention := 0.0
var shadow_cautioned := false
var shadow_warning := false
var care_t := 0.0
var rest_reached := false
var escort_player_token := 0
var escort_player_target := Vector2.INF
var player_control_guard_fired := false
var help_t := 0.0
var victory := false
var escort_orders: Dictionary = {}

func id() -> String: return "level6"
func title() -> String: return "大闹野猪林"
func subtitle() -> String: return "花和尚暗护林冲·留解差性命"
func campaign_core_goal() -> String: return "救下林冲，由鲁智深护送他和幸存解差活着走出野猪林。"
func story_contract_version() -> int: return 2
func campaign_story_goals() -> Array:
	return [
		{"id": "hidden_intercept", "label": "暗中跟随，在水火棍落下前现身拦棍", "required_events": ["observe", "shadow_route_chosen", "intercept"], "forbidden_events": ["yezhulin_early_force"]},
		{"id": "spare_escorts", "label": "听林冲求情，留董超、薛霸性命", "required_events": ["untie", "warn_escorts"], "forbidden_events": ["yezhulin_escort_lost"]},
		{"id": "care_and_escort", "label": "林边歇脚后，由玩家编组四人一同出林", "required_events": ["tend_feet", "rest_stop", "yezhulin_four_left"], "forbidden_events": []},
	]
func map_w() -> int: return 52
func map_h() -> int: return 40
func map_theme() -> String: return "marsh"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(39, 20)
func deploy_hint() -> String:
	return "押送队会自行深入野猪林，剧情不等任务按钮。北侧松林路近但容易暴露，南侧芦丛路远却更隐蔽；也可提前现身强救。救人后可直接结队出林，也可歇脚取得演义印；选中任一人下令，鲁智深领队、解差照应林冲。"
func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	for key in ["lu_zhishen", "lin_chong", "dong_chao", "xue_ba"]:
		defs[key]["abilities"] = []
		defs[key]["ability"] = ""
	defs["lin_chong"]["ranged"] = false
	defs["lin_chong"]["speed"] = 60
	defs["lin_chong"]["atk"] = 0
	defs["lin_chong"]["hero"] = false
	defs["lin_chong"]["noncombat"] = true
	defs["lin_chong"]["aura"] = ""
	defs["lu_zhishen"]["art_variant"] = "lu_zhishen_rescue"
	defs["dong_chao"]["art_variant"] = "dong_chao_escort"
	defs["xue_ba"]["art_variant"] = "xue_ba_escort"

func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "林冲刺配沧州，双脚已被滚水烫伤。董超、薛霸受买嘱，要在僻静的野猪林下手。鲁智深一路尾随，未曾露面。"},
		{"who": "鲁智深", "key": "lu_zhishen", "text": "两个公人一路折磨林教头。洒家且从林边跟上，看他们到这僻静处又要做甚么。"},
		{"who": "行前提示", "key": "narrator", "text": "先沿北侧松林或南侧芦丛暗中跟上，在棍落之前救下林冲。救人后框选四人，自己决定先歇脚照伤还是直接出林。"},
	]

func paint_map(map: GameMap) -> void:
	# 上下以崖壁松岭围合，中部留出一条林间官道走廊
	map.fill_rect(0, 0, 52, 7, T.CLIFF)
	map.fill_rect(0, 33, 52, 7, T.CLIFF)
	# 野猪林：成片密松（FOREST），夹道幽深
	map.fill_ellipse(Vector2(14, 12), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(20, 27), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(33, 12), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(36, 28), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(9, 25), 3, 2, T.FOREST)
	map.fill_ellipse(Vector2(44, 14), 3, 2, T.FOREST)
	# 林间官道：东林口 → 行刑松树 → 西林口
	map.paint_path([Vector2(49, 20), Vector2(40, 20), Vector2(33, 20), Vector2(27, 20), Vector2(18, 20), Vector2(8, 20), Vector2(1, 20)], 1, T.ROAD)
	# 行刑松树前的小空地
	map.fill_ellipse(Vector2(PINE.x, PINE.y), 4, 2, T.DRYHILL, [T.DRYHILL, T.GRASS])
	# 伏身芦苇荡（鲁智深藏身，离官道 3 格以上，藏得住）
	map.fill_ellipse(Vector2(24, 16), 3, 2, T.REEDS)
	map.fill_ellipse(Vector2(30, 25), 3, 2, T.REEDS)


func decorate(map: GameMap) -> void:
	map.decor = [
		["pine", Vector2i(27, 17), 64.0],      # 行刑大松树
		["rocks", Vector2i(10, 9), 48.0], ["rocks", Vector2i(42, 31), 48.0],
		["rocks", Vector2i(6, 30), 44.0], ["pine", Vector2i(15, 30), 52.0],
		["pine", Vector2i(38, 11), 52.0],
	]


func deploy(b) -> void:
	escorts.clear()
	lin_freed = b.spawn_at("lin_chong", Unit.FACTION_LIANG, Vector2i(43, 20))
	lin_freed.display_name = "林冲·披枷"
	lin_freed.art_variant = "lin_chong_prisoner"
	lin_freed.is_noncombat = true
	lin_freed.passive = true
	lin_freed.stance = Unit.STANCE_PASSIVE
	lin_freed.hp = lin_freed.max_hp * 0.65
	for i in range(2):
		var g: Unit = b.spawn_at(["dong_chao", "xue_ba"][i], Unit.FACTION_GUAN, Vector2i(43 + i, 19 + i * 2))
		g.passive = true
		g.stance = Unit.STANCE_PASSIVE
		g.defeat_outcome = "subdued"
		escorts.append(g)
	lu = b.spawn_at("lu_zhishen", Unit.FACTION_LIANG, AMBUSH)
	lu.passive = true
	lu.stance = Unit.STANCE_PASSIVE
	lin_bound = null

func on_start(b) -> void:
	st = STALK
	exec_timer = EXEC_TIME
	rescued = false
	tracking_done = false
	treated = false
	shadow_route = ""
	shadow_attention = 0.0
	shadow_cautioned = false
	shadow_warning = false
	care_t = 0.0
	rest_reached = false
	smoke_t = 0.0
	escort_player_token = 0
	escort_player_target = Vector2.INF
	player_control_guard_fired = false
	help_t = 0.0
	victory = false
	escort_orders.clear()
	lin_freed.order_move(b.map.cell_to_world(PINE))
	for i in range(escorts.size()):
		escorts[i].order_move(b.map.cell_to_world(PINE + Vector2i(i * 2 - 1, -1)))
	b.mission.begin("shadow", "沿林暗中跟随", "押送队正自行前往大松树。北侧松林更近但容易被看见，南侧芦丛更远但更隐蔽；第一次靠得过近只会警告，持续贴近才会缩短拦棍时间。")
	b.mission.enable_scrolling()
	_add_selection_button(b)
	b.mission.add_map_locator("北侧松林 · 近路", Vector2i(34,16))
	b.mission.add_map_locator("南侧芦丛 · 隐蔽", Vector2i(34,25))
	b.mission.set_status("点选鲁智深，再右键林边地面。查看只移镜头，押送队仍会继续前行。")

func on_mission_action(b, action_id: String, actor) -> void:
	match action_id:
		"observe":
			b.mission.mark("observe", "董超、薛霸把林冲引往幽深林里，鲁智深仍未现身")
			b.mission.set_objective("可沿官道北侧松林或南侧芦丛跟上。保持距离：过近会让公人起疑，过远则看不清动向。")
			b.mission.add_action("shadow_pine", "鲁智深·走北侧松林", Vector2i(30, 16), ["lu_zhishen"], 1.0)
			b.mission.add_action("shadow_south", "鲁智深·走南侧芦丛", Vector2i(30, 25), ["lu_zhishen"], 1.0)
		"shadow_pine", "shadow_south":
			if tracking_done:
				return
			tracking_done = true
			shadow_route = "north_pines" if action_id == "shadow_pine" else "south_reeds"
			b.mission.mark(action_id, "从北侧松林跟到大树" if action_id == "shadow_pine" else "从南侧芦丛绕到大树")
			b.mission.mark("shadow_route_chosen", "鲁智深保持距离，听见公人要害林冲")
			b.mission.begin("shadow_wait", "尚未现身·候在树旁", "路已认清。隐在大树侧面，等解差押林冲到树下；此时不要攻击。")
		"intercept":
			if st != RESCUE or exec_timer <= 0.0:
				return
			exec_timer = EXEC_TIME
			rescued = true
			st = CARE
			actor.play_story_pose("intercept", "lu_zhishen_rescue", 2.0)
			actor._face_dir(lin_bound.position-actor.position,true)
			for guard in escorts:
				guard.order_stop()
				guard.apply_stun(2.0)
				guard.faction = Unit.FACTION_LIANG
				guard.passive = true
				guard.stance = Unit.STANCE_PASSIVE
				guard.is_noncombat = true
			b.mission.mark("intercept", "禅杖从松树后飞出，水火棍被拨开")
			b.mission.begin("mercy", "林冲求情", "林冲开口求情。鲁智深收住禅杖，接下来的解缚和照伤由现场演出自然继续。")
			b.mission.set_status("剧情演出中；不需要再点击任务按钮。")
			b.msg("林冲：师兄住手！这是高太尉叫陆虞候买嘱的。既救了我，且饶他两个性命。", 7.0)
			care_t = 0.0
		"untie":
			_finish_untie(b)
		"tend_feet":
			_finish_tending(b)
		"rest_stop":
			if st != ESCAPE or rest_reached: return
			if not _survivors_near(b.map.cell_to_world(REST),96):
				_retry_escort_action(b,"rest_stop","同伴尚未到齐；让队伍走近歇脚处后，再右键旗标。")
				return
			rest_reached = true
			b.mission.mark("rest_stop","玩家带相送队到林边歇脚，照料林冲脚伤。")
			lin_freed.heal(35.0)
			if _all_escorts_alive():
				b.mission.mark("warn_escorts","鲁智深当面喝令两个公人一路小心服侍林冲。")
			b.mission.set_title("整队完毕 · 结伴出林")
			b.mission.set_objective("已歇脚。选中相送队任一人，右键西侧出林旗标；整队抵达后通关。")
		"leave_forest":
			if st != ESCAPE: return
			b.mission.mark("leave_forest","玩家下令相送队一起出林。")
			b.mission.set_objective("等幸存同伴都走到林口。鲁智深和林冲必须生还；四人歇脚后出林另计演义目标。")

func process(b, delta: float) -> void:
	if b._smoke:
		_smoke_drive(b, delta)
	if not is_instance_valid(lu) or lu.hp <= 0.0:
		b.lose("鲁智深倒下，林冲失了暗中护送的人。")
		return
	if st in [STALK,RESCUE] and _escort_fight_started():
		_begin_open_rescue(b,"鲁智深现身与解差交手，先制住他们再救林冲。")
		return
	help_t -= delta
	if help_t <= 0:
		help_t = 0.3
		_update_help(b)
	if st == STALK:
		var shadow_distance := _shadow_distance()
		if shadow_distance < SHADOW_TOO_CLOSE_R:
			shadow_attention += delta
			if shadow_attention >= SHADOW_CAUTION_TIME and not shadow_cautioned:
				shadow_cautioned = true
				b.mission.mark("shadow_caution", "公人似乎听见林边动静；鲁智深仍可及时退回隐蔽处")
				b.msg("太近了。先退回林边；继续贴近才会真正惊动公人。", 4.0)
			if shadow_attention >= SHADOW_EXPOSE_TIME and not shadow_warning:
				shadow_warning = true
				b.mission.mark("shadow_too_close", "鲁智深一度贴得太近，公人回头张望；拦棍可用的时间会缩短")
				b.msg("公人回头望了一眼，押送的脚步加快了。", 4.0)
		else:
			shadow_attention = maxf(0.0, shadow_attention - delta * 1.25)
		if not tracking_done and is_instance_valid(lin_freed) \
				and (lin_freed.position.distance_to(b.map.cell_to_world(WATCH)) < 72.0 \
				or lin_freed.position.distance_to(b.map.cell_to_world(PINE)) < 150.0):
			_resolve_shadow_checkpoint(b)
		if tracking_done and shadow_route == "lost_trail" and (_shadow_distance()<=SHADOW_TOO_FAR_R or lu.position.distance_to(b.map.cell_to_world(PINE))<260):
			tracking_done = false
			_resolve_shadow_checkpoint(b)
			b.mission.mark("shadow_recovered","鲁智深及时重新跟到树旁，仍能候机拦棍。")
		if is_instance_valid(lin_freed) and lin_freed.position.distance_to(b.map.cell_to_world(PINE)) < 60.0:
			if not tracking_done:
				_resolve_shadow_checkpoint(b)
			if shadow_route == "lost_trail":
				_story_miss(b,"hidden_intercept","未能一路暗随，但仍可在倒计时结束前赶来救人。")
			var old_pos: Vector2 = lin_freed.position
			var old_ratio: float = lin_freed.hp/lin_freed.max_hp
			var old_cool: float = lin_freed._combat_cool
			b.units.erase(lin_freed)
			lin_freed.queue_free()
			lin_freed = null
			lin_bound = b.spawn_unit("lin_chong_bound", Unit.FACTION_LIANG, old_pos)
			lin_bound.art_variant = "lin_chong_bound"
			lin_bound.hp = lin_bound.max_hp*old_ratio
			lin_bound._combat_cool = old_cool
			st = RESCUE
			exec_timer = 24.0 if shadow_warning or shadow_route=="lost_trail" else (34.0 if shadow_route == "north_pines" else EXEC_TIME)
			var route_hint := "北侧松林离大树更近，但留给你的反应时间较短。" if shadow_route == "north_pines" else "南侧芦丛更隐蔽，但要从更远处赶到大树。"
			if shadow_route=="lost_trail": route_hint="虽然没能一路暗随，仍有24秒赶到树旁补救。"
			b.mission.begin("intercept", "水火棍将落", ("持续贴得过近，公人已经加快动手！" if shadow_warning else "薛霸已经举棍！") + route_hint + "让鲁智深在倒计时结束前赶到松树旁拦棍。")
			b.mission.add_action("intercept", "鲁智深·禅杖拦棍", PINE + Vector2i(1, -1), ["lu_zhishen"], 0.8, 40.0, 48.0, false)
			_add_selection_button(b)
			b.mission.add_map_locator("大松树 · 赶来拦棍",PINE)
	elif st == RESCUE:
		exec_timer -= delta
		if exec_timer <= 0.0:
			b.mission.mark("yezhulin_missed_rescue","救援窗口结束，鲁智深未能拦住水火棍。")
			b.lose("水火棍落下，鲁智深晚了一步。重打时先选鲁智深，右键林边跟上；到树旁再右键拦棍旗标。")
	elif st == CARE:
		if _escorts_threatening():
			b.mission.set_status("解差尚在抵抗；制住他们后，解缚剧情会自然继续。")
			return
		var patient: Unit = lin_freed if is_instance_valid(lin_freed) else lin_bound
		if not is_instance_valid(patient) or lu.position.distance_to(patient.position)>100:
			b.mission.set_status("解差已制住。请让鲁智深走到林冲身旁，靠近后自然解缚照伤。")
			return
		care_t += delta
		if not is_instance_valid(lin_freed) and care_t >= 1.8:
			_finish_untie(b)
		elif is_instance_valid(lin_freed) and not treated and care_t >= 2.4:
			_finish_tending(b)
	elif st == ESCAPE:
		_enforce_post_rescue_escort_control(b)
		if not is_instance_valid(lin_freed) or lin_freed.hp <= 0.0:
			b.lose("林冲没有走出野猪林。")
			return
		if b.mission.has_event("leave_forest"):
			var exit_point: Vector2=b.map.cell_to_world(EXIT_W)
			var lin_out := lin_freed.position.distance_to(exit_point)<EXIT_R and lin_freed.story_outcome==""
			if lin_out:
				var four_out := _full_group_near(exit_point, EXIT_R)
				if not _survivors_near(exit_point, EXIT_R):
					b.mission.set_status("林冲不能单独结算；等鲁智深和幸存解差一起到达林口。")
					return
				if four_out and treated and rest_reached and b.mission.has_event("warn_escorts"):
					b.mission.mark("yezhulin_four_left", "董超、薛霸搀着林冲，跟随鲁智深踏上出林官道")
				victory = true
				b.mission.mark("yezhulin_victory", "林冲获救并活着离开野猪林")
				b.win("鲁智深救下林冲，依他求情饶过公人；董超、薛霸搀着林冲，四人一同出了野猪林。" if four_out else "鲁智深护着林冲，与幸存同伴一起离开野猪林；未能保全两名解差。")

func on_unit_died(b, u) -> void:
	if u == lin_bound or u == lin_freed:
		b.lose(u.display_name + "有失，护送失败。")
	elif u == lu:
		b.lose("鲁智深倒下，林冲尚未脱险。")
	elif u in escorts:
		b.mission.mark("yezhulin_escort_lost", u.display_name + "丧命；仍可救林冲出林，但不能完成留命章回")
		_story_miss(b, "spare_escorts", "两名解差未能全身。")
		_story_miss(b,"care_and_escort","已有解差阵亡，仍可护送林冲与幸存者出林。")
		if st in [STALK, RESCUE]:
			_begin_open_rescue(b, "解差已有伤亡，鲁智深立即救人")

func on_unit_resolved(b, u, _outcome: String) -> void:
	if u in escorts and st in [STALK, RESCUE]:
		_begin_open_rescue(b, "鲁智深提前制服解差，立即替林冲解缚")

func _escort_fight_started() -> bool:
	if not is_instance_valid(lu): return false
	if is_instance_valid(lu._target) and lu._target in escorts: return true
	for guard in escorts:
		if is_instance_valid(guard) and guard.hp < guard.max_hp - 0.5: return true
	return false

func _begin_open_rescue(b, reason: String) -> void:
	if st not in [STALK, RESCUE]: return
	b.mission.mark("yezhulin_early_force", reason)
	_story_miss(b, "hidden_intercept", "提前现身，未等水火棍落下再拦棍。")
	var bind_at: Vector2 = b.map.cell_to_world(PINE)
	if is_instance_valid(lin_bound):
		bind_at = lin_bound.position
	elif is_instance_valid(lin_freed):
		bind_at = lin_freed.position
		var hp_ratio: float = lin_freed.hp / lin_freed.max_hp
		b.units.erase(lin_freed)
		lin_freed.queue_free()
		lin_freed = null
		lin_bound = b.spawn_unit("lin_chong_bound", Unit.FACTION_LIANG, bind_at)
		lin_bound.art_variant = "lin_chong_bound"
		lin_bound.hp = lin_bound.max_hp * minf(hp_ratio, 0.65)
	for guard in escorts:
		if is_instance_valid(guard) and guard.hp > 0.0 and guard.story_outcome == "":
			guard.passive = false
			guard.stance = Unit.STANCE_AGGRO
			guard.order_attack(lu)
	st = CARE
	care_t = 0.0
	b.mission.begin("open_rescue", "提前现身·救下林冲", "暗中拦棍的章回已经错过。先制住两名解差；现场安全后，鲁智深会自然为林冲解缚。")
	b.mission.set_status("右键解差发动攻击；制住后，靠近林冲救人。")
	_add_selection_button(b)
	b.mission.add_map_locator("林冲 · 制敌后回到身旁",b.map.world_to_cell(bind_at))

func _resolve_shadow_checkpoint(b) -> void:
	if tracking_done or not is_instance_valid(lin_freed) or not is_instance_valid(lu):
		return
	b.mission.mark("observe", "押送队越走越深，两名公人开始张望四周")
	var distance := _shadow_distance()
	var waiting_ahead := lu.position.distance_to(b.map.cell_to_world(PINE)) < 260.0
	if distance <= 240.0 or waiting_ahead:
		shadow_route = "north_pines" if lu.position.y <= lin_freed.position.y else "south_reeds"
		b.mission.mark("shadow_pine" if shadow_route == "north_pines" else "shadow_south",
			"鲁智深借北侧松林遮身" if shadow_route == "north_pines" else "鲁智深沿南侧芦丛暗行")
		b.mission.mark("shadow_route_chosen", "鲁智深没有现身，仍在松树附近照应")
	else:
		shadow_route = "lost_trail"
		b.mission.mark("shadow_lost", "鲁智深与押送队拉开了距离，只能直接赶往大松树")
		b.msg("跟得太远了，仍来得及赶到松树旁。点查看找松树，再右键地面追上。",5)
	tracking_done = true
	b.mission.begin("shadow_wait", "松树将近", "解差押着林冲继续前行。剧情会在他们到达大松树时自然继续。")
	_add_selection_button(b)
	b.mission.add_map_locator("大松树 · 仍可追上",PINE)
	b.mission.set_status("保持隐蔽或自行赶往松树；看顶部距离提示。")

func _escorts_threatening() -> bool:
	for guard in escorts:
		if is_instance_valid(guard) and guard.hp > 0.0 and guard.story_outcome == "" and guard.faction == Unit.FACTION_GUAN:
			return true
	return false

func _all_escorts_alive() -> bool:
	for guard in escorts:
		if not is_instance_valid(guard) or guard.hp <= 0.0 or guard.story_outcome != "":
			return false
	return escorts.size() == 2

func _escort_group() -> Array:
	var group: Array = []
	for unit in [lu, lin_freed] + escorts:
		if is_instance_valid(unit) and unit.hp > 0.0 and unit.story_outcome == "":
			group.append(unit)
	return group

func _escort_formation_slots(target: Vector2) -> Array[Vector2]:
	# 原著关系：智深持禅杖在前；董超、薛霸分列两侧搀住林冲。
	return [target + Vector2(-52.0, 0.0), target,
		target + Vector2(18.0, -32.0), target + Vector2(18.0, 32.0)]

func _adopt_latest_player_escort_order(b) -> void:
	var newest_token := escort_player_token
	var target := Vector2.INF
	for unit in _escort_group():
		if bool(unit.get_meta(&"campaign_mission_auto_dispatch", false)):
			continue
		if unit.mission_order_token > newest_token and unit.mission_order_target != Vector2.INF:
			newest_token = unit.mission_order_token
			target = unit.mission_order_target
	if target == Vector2.INF:
		return
	escort_player_token = newest_token
	escort_player_target = target
	var group := _escort_group()
	if group.size() < 2: return
	var direction: Vector2 = (target-lin_freed.position).normalized()
	var side := Vector2(-direction.y,direction.x)
	var slots: Array[Vector2] = []
	for unit in group:
		if unit==lu: slots.append(target+direction*40)
		elif unit==lin_freed: slots.append(target)
		else: slots.append(target-direction*18+side*(-32 if unit==escorts[0] else 32))
	var speed_cap: float = b._group_speed_cap(group)
	for i in range(group.size()):
		var unit = group[i]
		unit.order_move(slots[i], false, speed_cap)
		unit.manual_order_t = 5.0
		unit.manual_order_active = true
		unit.stamp_mission_order_intent(target, newest_token)
		escort_orders[unit.get_instance_id()] = unit._order_serial
		unit.passive = true
		unit.stance = Unit.STANCE_PASSIVE
	var stop_hint := "点“■停”可让整队停下。" if b.hud.touch_ui else "按%s可让整队停下。" % Settings.key_label("stop")
	b.mission.set_status("已接收玩家路线：鲁智深领队，幸存解差照应林冲。" + stop_hint)

func _regulate_escort_spacing(b) -> void:
	var group := _escort_group()
	if group.size() != 4 or escort_player_target == Vector2.INF:
		return
	if not lin_freed.manual_order_active or lin_freed._state not in [Unit.ST_MOVE, Unit.ST_AMOVE]:
		return
	var travel := escort_player_target - lin_freed.position
	if travel.length_squared() < 16.0:
		return
	travel = travel.normalized()
	var side := Vector2(-travel.y, travel.x)
	var desired_long := [40.0, -18.0, -18.0]
	var desired_side := [0.0, -32.0, 32.0]
	var lag_max := 0.0
	var errors: Array[Vector2] = []
	for i in range(3):
		var offset: Vector2 = group[i + (0 if i == 0 else 1)].position - lin_freed.position
		var error := Vector2(offset.dot(travel) - desired_long[i], offset.dot(side) - desired_side[i])
		errors.append(error)
		lag_max = maxf(lag_max, maxf(-error.x, absf(error.y) - 18.0))
	var convoy_speed: float = b._group_speed_cap(group)
	# 伤员是队形节拍器：有人落后或绕树时先放慢林冲，避免领队和解差各跑各的。
	lin_freed._group_cap = convoy_speed * (0.38 if lag_max > 24.0 else (0.68 if lag_max > 10.0 else 1.0))
	for i in range(3):
		var unit = group[i + (0 if i == 0 else 1)]
		var error := errors[i]
		if error.x > 20.0:
			unit._group_cap = convoy_speed * 0.35
		elif error.x < -12.0 or absf(error.y) > 18.0:
			unit._group_cap = convoy_speed * 1.35
		else:
			unit._group_cap = convoy_speed

func _enforce_post_rescue_escort_control(b) -> void:
	if b._smoke:
		return
	# A player's stop/hold keeps manual protection but has no moving-task token.
	# Natural arrivals clear protection; mission consumption alone does not stop a path.
	if escort_player_target!=Vector2.INF and _escort_group().any(func(u): return u.manual_order_active and u._state==Unit.ST_IDLE and u.mission_order_token==0):
		if b.mission._actor in _escort_group(): b.mission.on_player_order(b.mission._actor)
		for unit in _escort_group():
			unit.order_stop()
			unit.manual_order_active=false
		escort_player_target=Vector2.INF
		escort_orders.clear()
		b.mission.set_status("相送队已按你的命令停下；右键新目的地继续同行。")
		return
	_adopt_latest_player_escort_order(b)
	var blocked: Array[String] = []
	for unit in _escort_group():
		var moving: bool = unit._state in [Unit.ST_MOVE, Unit.ST_AMOVE] or not unit._path.is_empty()
		if not moving:
			continue
		var same_player_order: bool = escort_player_target!=Vector2.INF \
			and int(escort_orders.get(unit.get_instance_id(),-1))==unit._order_serial \
			and not bool(unit.get_meta(&"campaign_mission_auto_dispatch", false))
		if same_player_order:
			continue
		if b.mission.active_action_id != "" and b.mission._actor == unit:
			b.mission.on_player_order(unit)
		if bool(unit.get_meta(&"campaign_mission_auto_dispatch", false)):
			unit.remove_meta(&"campaign_mission_auto_dispatch")
		unit.order_stop()
		blocked.append(unit.display_name)
	if blocked.is_empty():
		_regulate_escort_spacing(b)
		return
	if not player_control_guard_fired:
		player_control_guard_fired = true
		b.mission.mark("post_rescue_auto_move_blocked", "%s收到非玩家移动命令，已在原地拦停" % "、".join(blocked))
	b.mission.set_status("已拦下非玩家移动；相送队只跟随你的右键路线。")

func _full_group_near(point: Vector2, radius: float) -> bool:
	# 单位碰撞分离会把终点推开不到一个像素；给编组判定留 2px 数值容差。
	var allowed := radius + 2.0
	if not is_instance_valid(lin_freed) or lin_freed.hp <= 0.0 or lin_freed.position.distance_to(point) > allowed:
		return false
	if not is_instance_valid(lu) or lu.hp <= 0.0 or lu.position.distance_to(point) > allowed:
		return false
	for guard in escorts:
		if not is_instance_valid(guard) or guard.hp <= 0.0 or guard.story_outcome != "" or guard.position.distance_to(point) > allowed:
			return false
	return escorts.size() == 2

func _finish_untie(b) -> void:
	if st != CARE or is_instance_valid(lin_freed) or not is_instance_valid(lin_bound):
		return
	var hp_ratio: float = lin_bound.hp / lin_bound.max_hp
	var patient_pos: Vector2 = lin_bound.position
	var patient_cool: float = lin_bound._combat_cool
	b.units.erase(lin_bound)
	lin_bound.queue_free()
	lin_bound = null
	lin_freed = b.spawn_unit("lin_chong", Unit.FACTION_LIANG, patient_pos)
	lin_freed._combat_cool = patient_cool
	lin_freed.art_variant = "lin_chong_escort"
	lin_freed.display_name = "林冲"
	lin_freed.hp = lin_freed.max_hp * minf(hp_ratio, 0.65)
	lin_freed.passive = true
	lin_freed.stance = Unit.STANCE_PASSIVE
	lin_freed.apply_slow(0.7, 999.0)
	b.mission.mark("untie", "鲁智深收住禅杖，取戒刀割断绑绳，扶起林冲")
	b.mission.begin("care", "林冲已经脱缚", "鲁智深俯身查看林冲被烫伤的双脚。")
	b.mission.set_status("剧情演出中；不需要重复下达解缚和照伤命令。")
	care_t = 0.0

func _finish_tending(b) -> void:
	if st != CARE or treated or not is_instance_valid(lin_freed):
		return
	treated = true
	lin_freed.heal(lin_freed.max_hp * 0.2)
	lin_freed.apply_slow(0.88, 999.0)
	# 旧双人图把鲁智深画成持续搀扶者，属于与原著不符的压缩。本段改回
	# 四个真实单位：智深只在割绳后扶起，行路由董超、薛霸夹扶林冲。
	lin_freed.set_meta("story_pose", "")
	lin_freed.story_assist_partner = null
	if is_instance_valid(lu):
		lu.story_assist_owner = null
	b.mission.mark("tend_feet", "鲁智深扶起林冲，喝令董超、薛霸上前搀扶；四人等玩家决定路线")
	for guard in escorts:
		if is_instance_valid(guard) and guard.hp > 0.0 and guard.story_outcome in ["", "subdued"]:
			# 提前接战路线中，活着被制服的解差仍要依林冲求情继续搀扶上路。
			guard.story_outcome = ""
			guard.order_stop()
			guard.faction = Unit.FACTION_LIANG
			guard.passive = true
			guard.stance = Unit.STANCE_PASSIVE
			guard.is_noncombat = true
			guard.queue_redraw()
	lin_freed.order_stop()
	if is_instance_valid(lu):
		lu.order_stop()
	b.mission.begin("escort", "救人成功 · 选择归路", "可直接结队出林，也可到林边歇脚照伤完成演义目标。选中任意一人右键旗标，幸存队伍沿你的路线同行；没有新命令便停留原地。")
	b.mission.add_action("rest_stop", "可选 · 林边歇脚整队", REST, ["lin_chong"], 1.2, 48.0, 48.0)
	b.mission.add_action("leave_forest", "结队出林", EXIT_W, ["lin_chong"], 0.8, 48.0, 48.0)
	# Arriving companions can nudge the stopped patient a few pixels while he
	# is treating/resting. Keep the tight arrival range without losing the order.
	for action_id in ["rest_stop","leave_forest"]:
		b.mission.actions[action_id].settle_margin=16.0
	b.mission.set_status("查看只移镜头；先选人，再右键旗标。出林需林冲、鲁智深和所有幸存同伴到齐。")
	_add_selection_button(b,true)
	st = ESCAPE
	rest_reached = false

func _survivors_near(point: Vector2,radius: float) -> bool:
	if not is_instance_valid(lu) or lu.hp<=0 or not is_instance_valid(lin_freed) or lin_freed.hp<=0: return false
	return _escort_group().all(func(u): return u.position.distance_to(point)<=radius+2)

func _retry_escort_action(b,key: String,text: String) -> void:
	var action: Dictionary=b.mission.actions[key]
	action.done=false
	if is_instance_valid(action.button): action.button.disabled=false
	action.marker.show()
	b.mission.set_status(text)

func _add_selection_button(b,group := false) -> void:
	var button := Button.new()
	button.text = "选中 · 相送队伍" if group else "选中 · 鲁智深"
	button.pressed.connect(func():
		var members: Array = _escort_group() if group else [lu]
		members = members.filter(func(u): return is_instance_valid(u) and u.hp>0 and u.story_outcome=="")
		if members.is_empty(): return
		b.select_members(members,false)
		b.center_camera_cell(b.map.world_to_cell(members[0].position)))
	b.mission._buttons.add_child(button)

func _update_help(b) -> void:
	if b.mission.active_action_id!="": return
	if st==STALK:
		if lu not in b.selection:
			b.mission.set_guidance("先点选鲁智深，再右键林边地面跟随。顶部提示距离；查看按钮只移镜头。")
		elif shadow_route=="lost_trail":
			b.mission.set_guidance("已跟丢，仍可补救：查看大松树，再右键旁边地面赶去。")
		else:
			b.mission.set_guidance("右键林边地面跟随；贴近会惹人起疑，保持距离。右键解差则提前动手强救。")
	elif st==RESCUE:
		b.mission.set_guidance("选中鲁智深，右键松树旁金色拦棍旗标，站稳0.8秒即可救人。")

func _story_miss(b, goal_id: String, reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id, reason)

func _shadow_distance() -> float:
	var distance := INF
	for target in escorts + [lin_freed]:
		if is_instance_valid(target) and target.hp > 0.0:
			distance = minf(distance, lu.position.distance_to(target.position))
	return distance

func top_status(b) -> String:
	if st == RESCUE:
		return "野猪林 | 拦棍倒计时 %d 秒" % ceili(maxf(0.0, exec_timer))
	if st == STALK:
		var distance := _shadow_distance()
		var distance_text := "过近·立即退回林边" if distance < SHADOW_TOO_CLOSE_R else ("过远·向官道边跟上" if distance > SHADOW_TOO_FAR_R else "未露面·距离合适")
		return "野猪林 | 暗中跟随 | " + distance_text
	return "野猪林 | " + ["暗中跟随", "拦棍救人", "求情解缚·照料脚伤", "相送沧州道"][st]

func _smoke_drive(b, delta: float) -> void:
	if st == STALK and is_instance_valid(lu) and is_instance_valid(lin_freed) \
			and lu.position.distance_to(lin_freed.position) > 180.0 and lu._path_i >= lu._path.size():
		lu.order_move(lin_freed.position + Vector2(0, -128))
	if st == ESCAPE and is_instance_valid(lin_freed):
		var target_cell := REST if not b.mission.has_event("rest_stop") else EXIT_W
		var target: Vector2 = b.map.cell_to_world(target_cell)
		for i in range(escorts.size()):
			if is_instance_valid(escorts[i]) and escorts[i].hp > 0.0 and escorts[i].story_outcome == "" and escorts[i]._path_i >= escorts[i]._path.size():
				escorts[i].order_move(target + Vector2(0, -30.0 if i == 0 else 30.0))
		if is_instance_valid(lu) and lu.hp > 0.0 and lu._path_i >= lu._path.size():
			lu.order_move(target + Vector2(-30, -12))
	if b.mission.active_action_id != "":
		return
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 0.9
	for action_id in ["intercept", "rest_stop", "leave_forest"]:
		if b.mission.request_action(action_id):
			return
