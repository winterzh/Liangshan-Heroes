extends LevelBase
## 孟州时期武松：无三不过望、酒店挑衅、拳脚制服、施恩收回酒店。
const T := GameMap.T
const START_E := Vector2i(6, 19)
const KUAIHUO := Vector2i(52, 19)
const SIGN := Vector2i(54, 18)
const BOSS_TRIGGER_X := 45
const DRINK_R := 58.0
const TAVERN_CELLS := [Vector2i(16, 15), Vector2i(25, 22), Vector2i(34, 14), Vector2i(43, 21)]
enum { ROAD, STEP_DRILL, SHOWDOWN, RETURN_SHOP }
const BRACE_SOURCE := 7291
var wu: Unit
var shi: Unit
var sign: Unit
var menshen: Unit
var taverns: Array = []
var drunk := 0
var st := ROAD
var boss_on := false
var smoke_t := 0.0
var fist_cd := 6.0
var fist_windup := 0.0
var fist_at := Vector2.ZERO
var dodged := false
var steady_left := 0.0
var fist_marker: Node2D
var drill_origin := Vector2.ZERO
var drill_marker: Node2D
var special_kind := "heavy"
var special_index := 0
var rush_from := Vector2.ZERO
var rush_end := Vector2.ZERO
var exposed_left := 0.0
var heavy_dodges := 0
var rush_dodges := 0
var story_step_primed := false

func id() -> String: return "level7"
func title() -> String: return "醉打蒋门神"
func subtitle() -> String: return "孟州快活林·玉环步，鸳鸯脚"
func campaign_core_goal() -> String: return "以拳脚制服蒋门神，让施恩活着收回酒店。"
func story_contract_version() -> int: return 1
func campaign_story_goals() -> Array:
	return [
		{"id": "three_bowls", "label": "依约无三不过望，沿路四处各饮三碗", "required_events": ["drink_0", "drink_1", "drink_2", "drink_3"], "forbidden_events": []},
		{"id": "drunken_provocation", "label": "到挂着“河阳风月”酒望的店前佯醉换酒，惊动酒保，引蒋门神赶来", "required_events": ["provoke"], "forbidden_events": ["kuaihuolin_early_showdown"]},
		{"id": "signature_fists", "label": "趁失势以玉环步接鸳鸯脚", "required_events": ["mengzhou_signature"], "forbidden_events": []},
		{"id": "spare_and_restore", "label": "留蒋门神性命，说清三项条件后交还酒店", "required_events": ["menshen_subdued", "terms", "restore_shop"], "forbidden_events": []},
	]
func map_w() -> int: return 60
func map_h() -> int: return 38
func map_theme() -> String: return "town"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(12, 19)
func deploy_hint() -> String:
	return "可依原著沿路吃酒、到店佯醉挑衅，也可直接去快活林挑战。任务栏只负责定位现场，所有移动、交互与战斗均由玩家下令。无论走哪条路，都须以拳脚留命制服蒋门神，并让施恩活着接管酒店；原著酒路、招式与退店条件另计演义印。"

func apply_overrides(defs: Dictionary, abilities: Dictionary) -> void:
	defs["wu_song"]["abilities"] = ["mengzhou_punch", "mengzhou_step", "mengzhou_kick", "mengzhou_breath"]
	defs["wu_song"]["ability"] = "mengzhou_punch"
	defs["wu_song"]["atk"] = 26
	defs["wu_song"]["hp"] = 440
	defs["wu_song"]["range"] = 32
	defs["wu_song"]["ranged"] = false
	defs["shi_en"]["abilities"] = []
	defs["shi_en"]["ability"] = ""
	defs["shi_en"]["atk"] = 0
	defs["shi_en"]["noncombat"] = true
	defs["jiang_menshen"]["hp"] = 800
	defs["jiang_menshen"]["atk"] = 22
	defs["jiang_menshen"]["cd"] = 1.2
	defs["jiang_menshen"]["ability"] = ""
	defs["jiang_menshen"]["aura"] = ""
	defs["signboard"]["name"] = "快活林酒肉店"
	defs["signboard"]["captive"] = true
	defs["tavern"]["captive"] = true
	defs["signboard"]["mission_solid"] = true
	defs["tavern"]["mission_solid"] = true
	abilities["mengzhou_punch"] = {"name": "迎面直拳", "cd": 5.0, "targeted": false, "radius": 84.0, "color": Color("dfbe80"), "desc": "以拳击打近身对手，打断攻势。", "effect": {"kind": "smite", "dmg": 25.0, "stun": 0.5}}
	abilities["mengzhou_step"] = {"name": "玉环步", "cd": 8.0, "targeted": false, "radius": 0.0, "color": Color("dcc9a8"), "desc": "绕身换步，短时加速，避开蒋门神蓄拳落点。", "effect": {"kind": "haste", "speed_mult": 1.65, "dur": 2.0}}
	abilities["mengzhou_kick"] = {"name": "鸳鸯脚", "cd": 9.0, "targeted": false, "radius": 90.0, "color": Color("d99d62"), "desc": "接连踢击近身对手，短时使其失去重心。", "visual": {"face_nearest_foe": true, "face_nearest_foe_radius": 120.0}, "effect": {"kind": "smite", "dmg": 48.0, "stun": 1.2}}
	abilities["mengzhou_breath"] = {"name": "稳住酒势", "cd": 22.0, "targeted": false, "radius": 0.0, "color": Color("c9b47c"), "desc": "调整呼吸，恢复气血，5秒稳住步履；随后醉意仍在。", "effect": {"kind": "rally", "heal": 60.0, "atk_mult": 1.2, "dur": 5.0}}

func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "武松刺配孟州，受小管营施恩款待。施恩的快活林酒店被蒋忠倚仗张团练夺去；武松答应相助，裹头巾、穿布衫，从孟州东门步行而出。"},
		{"who": "武松", "key": "wu_song", "text": "小管营，路上遇着酒店，便请我吃三碗；不够三碗，我可不过酒望去！"},
		{"who": "施恩", "key": "shi_en", "text": "依哥哥便是。那蒋忠号称蒋门神，拳脚相扑都有本事，哥哥切莫轻敌。"},
		{"who": "行前提示", "key": "narrator", "text": "沿路吃酒，到店佯醉寻衅，再以拳脚打倒蒋门神。等他告饶后说清条件，留他性命，将酒店交还施恩。"},
	]

func paint_map(map: GameMap) -> void:
	# 上下林木夹道（快活"林"），中部一条贯通东西的孟州官道
	map.fill_rect(0, 0, 60, 6, T.FOREST)
	map.fill_rect(0, 32, 60, 6, T.FOREST)
	map.fill_ellipse(Vector2(20, 9), 4, 2, T.FOREST)
	map.fill_ellipse(Vector2(30, 28), 5, 2, T.FOREST)
	map.fill_ellipse(Vector2(40, 9), 4, 2, T.FOREST)
	# 孟州官道（东牢营 → 西快活林）
	map.paint_path([Vector2(START_E.x, START_E.y), Vector2(16, 19), Vector2(28, 19), Vector2(40, 19), Vector2(KUAIHUO.x, KUAIHUO.y)], 1, T.ROAD)
	# 快活林市口：一片镇集硬地
	map.fill_ellipse(Vector2(KUAIHUO.x, KUAIHUO.y), 7, 5, T.PLAZA)
	map.fill_ellipse(Vector2(SIGN.x, SIGN.y), 3, 2, T.PLAZA)
	# 各酒望前清出小块硬地
	for c in TAVERN_CELLS:
		map.fill_ellipse(Vector2(c.x, c.y), 2, 1, T.DRYHILL, [T.DRYHILL, T.GRASS, T.ROAD])


func decorate(map: GameMap) -> void:
	var d: Array = [
		["town_house", Vector2i(KUAIHUO.x - 3, KUAIHUO.y - 2), 60.0],
		["town_house", Vector2i(KUAIHUO.x + 2, KUAIHUO.y + 3), 56.0],
		["tent", Vector2i(START_E.x + 1, START_E.y + 1), 54.0],
	]
	for c in TAVERN_CELLS:
		d.append(["tent", c, 48.0])   # 酒望/酒旗草棚
	map.decor = d


func deploy(b) -> void:
	wu = b.spawn_at("wu_song", Unit.FACTION_LIANG, START_E)
	wu.art_variant = "wu_song_mengzhou"
	wu.passive = true
	wu.stance = Unit.STANCE_PASSIVE
	shi = b.spawn_at("shi_en", Unit.FACTION_LIANG, START_E + Vector2i(0, 1))
	shi.passive = true
	shi.stance = Unit.STANCE_PASSIVE
	taverns.clear()
	for index in range(TAVERN_CELLS.size()):
		var cell: Vector2i = TAVERN_CELLS[index]
		var tv: Unit = b.spawn_at("tavern", Unit.FACTION_LIANG, cell)
		tv.art_variant = "roadside_tavern"
		tv.set_meta("campaign_environment_route","roadside_tavern_%s" % ["a","b","c","d"][index])
		tv.set_meta("campaign_environment_state","default")
		taverns.append({"u": tv, "drunk": false})
	menshen = b.spawn_at("jiang_menshen", Unit.FACTION_GUAN, KUAIHUO)
	menshen.passive = true
	menshen.stance = Unit.STANCE_PASSIVE
	menshen.defeat_outcome = "subdued"
	menshen.art_variant = "jiang_menshen_fists"
	sign = b.spawn_at("signboard", Unit.FACTION_LIANG, SIGN)
	sign.art_variant = "heyang_tavern"
	sign.set_meta("campaign_environment_route","heyang_wine_sign")
	sign.set_meta("campaign_environment_state","default")
	sign.set_meta("campaign_environment_text_surface_id","level7_heyang_wine_sign")
	sign.set_meta("campaign_environment_runtime_text","河阳风月")

func on_start(b) -> void:
	st = ROAD
	drunk = 0
	boss_on = false
	fist_cd = 6.0
	fist_windup = 0.0
	dodged = false
	steady_left = 0.0
	special_kind = "heavy"
	special_index = 0
	exposed_left = 0.0
	heavy_dodges = 0
	rush_dodges = 0
	story_step_primed = false
	drill_origin = Vector2.ZERO
	if is_instance_valid(drill_marker):
		drill_marker.queue_free()
	drill_marker = null
	smoke_t = 0.0
	b.mission.begin("taverns", "无三不过望", "按沿路次序吃酒，每家三碗。酒后拳力增强，步速与出手会不稳；可用“稳住酒势”短时调整。")
	b.mission.add_action("drink_0", "武松·第一家吃三碗", TAVERN_CELLS[0] + Vector2i(0, 2), ["wu_song"], 1.6)
	b.mission.add_action("ask_shi", "可选·施恩说拳路", Vector2i(14, 18), ["shi_en"], 1.2)

func on_mission_action(b, action_id: String, actor) -> void:
	if action_id.begins_with("drink_"):
		var i := int(action_id.trim_prefix("drink_"))
		if st != ROAD or i != drunk or i >= taverns.size() or taverns[i]["drunk"]:
			return
		taverns[i]["drunk"] = true
		drunk += 1
		wu._base_atk += 5.0
		wu.atk += 5.0
		wu.heal(35.0)
		wu.start_drunk(maxf(0.64, 1.0 - 0.09 * drunk), 1.08, 999.0)
		wu._buff_glow = 0.8
		b.mission.mark(action_id, "第%d家酒望，武松吃足三碗" % (i + 1))
		if drunk == 2:
			_start_step_drill(b)
		elif drunk < TAVERN_CELLS.size():
			b.mission.add_action("drink_%d" % drunk, "武松·第%d家吃三碗" % (drunk + 1), TAVERN_CELLS[drunk] + Vector2i(0, 2), ["wu_song"], 1.6)
		else:
			b.mission.add_action("provoke", "武松·到店换酒挑衅", KUAIHUO + Vector2i(-2, 1), ["wu_song"], 1.4)
			b.mission.set_objective("酒已吃足。到挂着“河阳风月”酒望的店前佯醉换酒，激蒋门神来斗。")
		return
	match action_id:
		"ask_shi":
			b.mission.mark("ask_shi", "施恩提醒：蒋门神沉肩扎马后重拳落在原处，侧移即可让他落空")
			b.msg("施恩：他沉肩扎马便要砸原处；若俯身直冲，就横移让开来路。两招落空后再踢！", 7.0)
		"drill_left", "drill_right":
			if st != STEP_DRILL:
				return
			_complete_step_drill(b, action_id)
		"provoke":
			if st != ROAD or drunk != 4:
				return
			_open_showdown(b, true)
		"terms":
			if st != RETURN_SHOP or menshen.story_outcome != "subdued":
				return
			b.mission.mark("terms", "蒋忠应下三件事：退还酒店家当，请快活林众豪杰向施恩赔话，交割后离开孟州")
			b.mission.add_action("restore_shop", "施恩·收回酒店", SIGN + Vector2i(0, 2), ["shi_en"], 1.8)
		"restore_shop":
			if st != RETURN_SHOP or actor != shi:
				return
			if not b.mission.has_event("terms"):
				_story_miss(b, "spare_and_restore", "施恩直接接店，武松没有先说清原著三项条件。")
			sign.display_name = "施恩酒肉店·已收回"
			sign.set_meta("story_pose", "restored")
			b.mission.mark("restore_shop", "施恩收回酒店家当，蒋门神应诺搬离")
			b.win("武松拳脚制服蒋门神，逼他退店还物。施恩收回快活林生意，蒋门神告饶而去。")

func _open_showdown(b, original_provocation := false) -> void:
	if st == SHOWDOWN or st == RETURN_SHOP or not is_instance_valid(menshen) or menshen.story_outcome != "":
		return
	if not original_provocation:
		b.mission.mark("kuaihuolin_early_showdown", "武松没有走完酒路便直接挑战蒋门神")
		_story_miss(b, "drunken_provocation", "未按原著到店佯醉换酒。")
		if drunk < 4:
			_story_miss(b, "three_bowls", "没有走完无三不过望的四处酒路。")
	boss_on = true
	st = SHOWDOWN
	menshen.passive = false
	menshen.stance = Unit.STANCE_AGGRO
	menshen.order_attack(wu)
	wu.passive = false
	wu.stance = Unit.STANCE_AGGRO
	special_kind = "heavy"
	special_index = 0
	exposed_left = 0.0
	menshen.apply_damage_reduction(0.5, 999.0, BRACE_SOURCE)
	b.mission.set_status("蒋门神已经出店。武松和施恩均由玩家控制；可让施恩留在后方，避免卷入决斗。")
	if original_provocation:
		b.mission.mark("provoke", "武松佯醉换酒寻衅，酒保报信；蒋门神闻报赶来，与武松在大路相迎")
	b.mission.begin("duel", "玉环步·鸳鸯脚", "用拳脚制服蒋门神。沉肩重拳会砸向脚下圆场，俯身直冲则要横移让开来路；落空后他的架势才会松动。")
	b.msg("蒋门神迎面来斗！留意蓄拳落点，用玉环步换位，再接鸳鸯脚。", 5.0)

func on_ability(b, caster, ability_id: String, _lp: Vector2) -> bool:
	if caster != wu:
		return false
	if ability_id == "mengzhou_step":
		story_step_primed = true
		b.mission.mark("mengzhou_step_used", "武松踏玉环步绕身换位")
		return false
	if ability_id == "mengzhou_kick":
		var opening_seen: bool = b.mission.has_event("dodge_heavy") or b.mission.has_event("dodge_rush")
		if story_step_primed and opening_seen and is_instance_valid(menshen) and wu.position.distance_to(menshen.position) <= 100.0:
			b.mission.mark("mengzhou_signature", "蒋门神失势时，武松以玉环步接鸳鸯脚将他踢倒")
			story_step_primed = false
		return false
	if ability_id != "mengzhou_breath":
		return false
	steady_left = 5.0
	wu.start_drunk(1.0, 1.0, 5.0)
	wu.heal(60.0)
	return true

func process(b, delta: float) -> void:
	if steady_left > 0.0:
		steady_left = maxf(0.0, steady_left - delta)
		if steady_left <= 0.0 and is_instance_valid(wu) and wu.hp > 0.0:
			wu.start_drunk(maxf(0.64, 1.0 - 0.09 * drunk), 1.08, 999.0)
	if b._smoke:
		_smoke_drive(b, delta)
	if not is_instance_valid(wu) or wu.hp <= 0.0 or not is_instance_valid(shi) or shi.hp <= 0.0:
		b.lose("武松或施恩倒下，夺回酒店失败。")
		return
	if st == STEP_DRILL:
		if b.mission.active_action_id == "" and wu.position.distance_to(drill_origin) > 94.0:
			_complete_step_drill(b, "manual_step")
	if st in [ROAD, STEP_DRILL]:
		if menshen.hp < menshen.max_hp - 0.5 or menshen.story_outcome != "":
			if menshen.story_outcome == "subdued":
				_set_menshen_subdued(b)
			else:
				_open_showdown(b, false)
		elif is_instance_valid(wu._target) and wu._target == menshen:
			_open_showdown(b, false)
		elif drunk < 4 and is_instance_valid(wu) and is_instance_valid(menshen) and wu.position.distance_to(menshen.position) < 250.0:
			_open_showdown(b, false)
	elif st == SHOWDOWN and is_instance_valid(menshen) and menshen.story_outcome == "":
		if exposed_left > 0.0:
			exposed_left = maxf(0.0, exposed_left - delta)
			if exposed_left <= 0.0:
				menshen.apply_damage_reduction(0.5, 999.0, BRACE_SOURCE)
		if fist_windup > 0.0:
			fist_windup -= delta
			if fist_windup <= 0.0:
				if is_instance_valid(fist_marker):
					fist_marker.queue_free()
				var hit := wu.position.distance_to(fist_at) <= 78.0 if special_kind == "heavy" else _distance_to_segment(wu.position, rush_from, rush_end) <= 46.0
				if hit:
					wu.take_damage(32.0 if special_kind == "heavy" else 42.0, menshen)
					wu.apply_stun(0.55)
					b.msg("重拳砸中！离开脚下圆场。" if special_kind == "heavy" else "直冲撞中！下次横移让开红色来路。", 3.0)
				else:
					dodged = true
					exposed_left = 2.8 if special_kind == "rush" else 2.2
					menshen._damage_reduction_sources.erase(BRACE_SOURCE)
					menshen._refresh_damage_reduction()
					menshen.apply_stun(exposed_left)
					if special_kind == "heavy":
						heavy_dodges += 1
						b.mission.mark("dodge_heavy", "绕步离开重拳落点，蒋门神失势露出破绽")
					else:
						rush_dodges += 1
						b.mission.mark("dodge_rush", "横移让开直冲来路，蒋门神收势不及")
					b.msg("蒋门神招式落空，架势松了——趁现在接鸳鸯脚！", 3.0)
				menshen.set_meta("story_pose", "")
		else:
			fist_cd -= delta
			if fist_cd <= 0.0 and menshen.position.distance_to(wu.position) < 145.0:
				fist_cd = 6.2
				special_index += 1
				special_kind = "heavy" if special_index % 2 == 1 else "rush"
				fist_at = wu.position
				rush_from = menshen.position
				rush_end = rush_from + rush_from.direction_to(wu.position) * 190.0
				fist_windup = 1.6 if special_kind == "heavy" else 1.25
				menshen.apply_stun(fist_windup + 0.1)
				menshen.set_meta("story_pose", "windup" if special_kind == "heavy" else "rush_windup")
				fist_marker = FistWarning.new() if special_kind == "heavy" else RushWarning.new()
				fist_marker.set_meta("tell_kind", special_kind)
				fist_marker.position = fist_at if special_kind == "heavy" else rush_from
				if special_kind == "rush":
					fist_marker.rotation = rush_from.direction_to(rush_end).angle()
				fist_marker.z_index = 3449
				b.fx_root.add_child(fist_marker)
				b.map.sync_render_position(fist_marker)
				b.msg("蒋门神沉肩蓄拳！离开脚下圆场。" if special_kind == "heavy" else "蒋门神俯身直冲！横移让开红色来路。", 2.0)

func on_unit_resolved(b, u, outcome: String) -> void:
	if u != menshen or outcome != "subdued":
		return
	if st != SHOWDOWN:
		b.mission.mark("kuaihuolin_early_showdown", "武松直接制服蒋门神，没有走完原著酒路")
		_story_miss(b, "drunken_provocation", "未按原著到店佯醉换酒。")
		if drunk < 4:
			_story_miss(b, "three_bowls", "没有走完无三不过望的四处酒路。")
	_set_menshen_subdued(b)

func _set_menshen_subdued(b) -> void:
	if st == RETURN_SHOP:
		return
	st = RETURN_SHOP
	fist_windup = 0.0
	if is_instance_valid(fist_marker):
		fist_marker.queue_free()
	wu.order_stop()
	# The right-click attack that opened this free route has now been resolved.
	# Do not let its still-live manual stamp claim the nearby optional terms marker;
	# speaking the three original conditions requires a new player order.
	wu.manual_order_t = 0.0
	wu.manual_order_active = false
	wu.clear_mission_order_intent()
	wu.stance = Unit.STANCE_PASSIVE
	b.mission.mark("menshen_subdued", "蒋门神倒地告饶，武松收住拳头，叫他听清退店条件")
	b.mission.begin("return_shop", "夺回快活林酒店", "可直接让施恩接管酒店；若先由武松说清退店还物、赔话、离开孟州三件事，可完成原著章回。")
	b.mission.add_action("terms", "武松·说清退店条件", b.map.world_to_cell(menshen.position) + Vector2i(-1, 0), ["wu_song"], 1.5)
	b.mission.add_action("restore_shop", "施恩·接管酒店", SIGN + Vector2i(0, 2), ["shi_en"], 1.8)

func on_unit_died(b, u) -> void:
	if u == wu or u == shi:
		b.lose(u.display_name + "倒下，夺店失败。")
	elif u == menshen:
		b.lose("蒋门神丧命，已无从逼他退店赔话。夺店失败。")

func top_status(_b) -> String:
	if st == ROAD:
		return "无三不过望 | 已吃酒 %d/4家 | 武松徒手" % drunk
	if st == STEP_DRILL:
		return "施恩试步 | 离开脚下圆场，练一次横移"
	if st == RETURN_SHOP:
		return "蒋门神倒地告饶 | 谈定退店条件，请施恩接管"
	var tell := "寻找破绽"
	if fist_windup > 0.0:
		tell = "重拳将落！" if special_kind == "heavy" else "直冲将发！"
	elif exposed_left > 0.0:
		tell = "架势已松·趁势反击"
	return "快活林拳脚对决 | 圆场离开·直线横移 | " + tell

func _smoke_drive(b, delta: float) -> void:
	if b.mission.active_action_id != "":
		return
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 0.5
	for action_id in ["ask_shi", "drink_0", "drink_1", "drill_left", "drink_2", "drink_3", "provoke", "terms", "restore_shop"]:
		if b.mission.request_action(action_id):
			return
	if st != SHOWDOWN or menshen.story_outcome != "":
		return
	if fist_windup > 0.1:
		wu.order_move(wu.position + Vector2(0, 120))
		if wu.slot_ready(1):
			b._do_ability(wu, 1, wu.position)
	else:
		if not wu.has_target():
			wu.order_attack(menshen)
		if wu.position.distance_to(menshen.position) < 90.0:
			for slot in [0, 2, 3]:
				if wu.slot_ready(slot):
					b._do_ability(wu, slot, wu.position)

class FistWarning extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 78.0, Color(0.86, 0.19, 0.07, 0.16))
		draw_arc(Vector2.ZERO, 78.0, 0.0, TAU, 48, Color(1.0, 0.39, 0.16, 0.9), 2.5)
		draw_line(Vector2(-14, 0), Vector2(14, 0), Color(1.0, 0.56, 0.28), 2.0)
		draw_line(Vector2(0, -14), Vector2(0, 14), Color(1.0, 0.56, 0.28), 2.0)

class RushWarning extends Node2D:
	func _draw() -> void:
		var shape := PackedVector2Array([Vector2(0, -46), Vector2(190, -46), Vector2(190, 46), Vector2(0, 46)])
		draw_colored_polygon(shape, Color(0.86, 0.19, 0.07, 0.15))
		draw_polyline(PackedVector2Array([Vector2(0, -46), Vector2(190, -46), Vector2(190, 46), Vector2(0, 46)]), Color(1.0, 0.35, 0.13, 0.9), 2.5)
		draw_line(Vector2(18, 0), Vector2(174, 0), Color(1.0, 0.56, 0.28), 2.0)

func _start_step_drill(b) -> void:
	st = STEP_DRILL
	drill_origin = wu.position
	drill_marker = FistWarning.new()
	drill_marker.position = drill_origin
	drill_marker.z_index = 3449
	b.fx_root.add_child(drill_marker)
	b.map.sync_render_position(drill_marker)
	b.mission.begin("road_step_drill", "酒意上来·试一次横移", "施恩在路中指出蒋门神重拳的落点。可自己移出红圈，也可选左右任一练步任务；此次只练步，不受伤。")
	b.mission.add_action("drill_left", "武松·向官道上侧移", Vector2i(25, 19), ["wu_song"], 0.3)
	b.mission.add_action("drill_right", "武松·向官道下侧移", Vector2i(25, 25), ["wu_song"], 0.3)

func _complete_step_drill(b, source: String) -> void:
	if st != STEP_DRILL:
		return
	st = ROAD
	if is_instance_valid(drill_marker):
		drill_marker.queue_free()
	drill_marker = null
	b.mission.mark("road_step_practiced", "武松趁着酒意试走玉环步，横移离开重拳落点（%s）" % source)
	b.mission.begin("taverns_resume", "继行无三不过望", "已练过一次侧移，继续沿官道吃酒。真交手时，圆形落点要离开，直线冲撞要横移。")
	b.mission.add_action("drink_2", "武松·第三家吃三碗", TAVERN_CELLS[2] + Vector2i(0, 2), ["wu_song"], 1.6)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var line := finish - start
	if line.length_squared() <= 0.001:
		return point.distance_to(start)
	var t := clampf((point - start).dot(line) / line.length_squared(), 0.0, 1.0)
	return point.distance_to(start + line * t)

func _story_miss(b, goal_id: String, reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id, reason)
