extends LevelBase
## 黄泥冈：伪装、酒计、搬担。押送者麻倒，不以歼灭护卫判胜。
const T := GameMap.T
const EnvironmentArt := preload("res://scripts/campaign_environment_art.gd")
const TOP := Vector2i(24, 20)
const GATE_E := Vector2i(46, 20)
const GATE_W := Vector2i(6, 20)
const SHADE := Vector2i(20, 17)
const DATES := Vector2i(22, 18)
const ANSWER := Vector2i(24, 17)
const INSPECT := Vector2i(26, 17)
const GOOD_WINE := Vector2i(22, 23)
const SALE_WINE := Vector2i(24, 23)
const DISTRACT := Vector2i(26, 24)
const SEVEN := ["chao_gai", "wu_yong", "gongsun_sheng", "liu_tang", "ruan_xiaoer", "ruan_xiaowu", "ruan_xiaoqi"]
const CARRIERS := ["liu_tang", "ruan_xiaowu", "ruan_xiaoqi"]
const CARGO_STAGE_CELLS := [Vector2i(23, 19), Vector2i(25, 22), Vector2i(27, 21)]
const CARGO_ROUTE_NAMES := ["北沿", "中道", "南沿"]
const CARGO_GROUP_POINT := Vector2i(22, 21)
const NO_FORCE_CARRIER := "__waiting_force_carrier__"
const JUJUBE_CART_CELLS := [Vector2i(17, 14), Vector2i(19, 13), Vector2i(22, 12), Vector2i(24, 13), Vector2i(24, 15), Vector2i(18, 18), Vector2i(16, 16)]
const JUJUBE_CART_SIZE := 72.0
enum { PREPARE, MARCH, INQUIRY, ARRIVAL, WINE, CARRY, WITHDRAW, FORCE }
var st := PREPARE
var cart: Unit
var yang: Unit
var convoy: Array = []
var bundles: Array = []
var actors: Array = []
var core_dead := 0
var drug_done := false
var rest_t := 0.0
var exposure := 0.0
var smoke_t := 0.0
var cargo := {}
var cargo_plan := ""
var cargo_assignments := {}
var cargo_ready := {}
var cargo_objective_cache := ""
var delivered := 0
var attention_left := 0.0
var attention_missed := false
var wine_step := ""
var clean_trial := false
var scoop_prepared := false
var sale_drugged := false
var suspicious_keys: Array[String] = []
var suspicion_seen := false
var cover_restored := false
var field_signs: Array = []
var jujube_carts: Array = []
var good_sign
var sale_sign
var suspicion_sign
var force_attempts := {}
var force_started := false

func id() -> String: return "level1"
func title() -> String: return "智取生辰纲"
func subtitle() -> String: return "黄泥冈·七星聚义，白胜卖酒"
func campaign_core_goal() -> String: return "夺得三担生辰纲，并让至少一名好汉活着带出黄泥冈。"
func story_contract_version() -> int: return 1
func campaign_story_goals() -> Array:
	return [
		{"id": "merchant_cover", "label": "七星扮贩枣客，经杨志盘问不露身份", "required_events": ["place_dates", "merchant_identity_confirmed"], "forbidden_events": ["huangnigang_force"]},
		{"id": "wine_scheme", "label": "白胜卖酒，依次试酒、引目、用瓢、夺瓢下药", "required_events": ["taste_wine", "distract_yang", "drug_scoop", "reclaim_scoop", "drugged"], "forbidden_events": ["huangnigang_force"]},
		{"id": "no_bloodshed", "label": "十五名押送者全部麻倒，无一伤亡", "required_events": ["drugged"], "forbidden_events": ["huangnigang_convoy_hurt"]},
		{"id": "all_safe", "label": "七星与白胜带走纲担，全身出冈", "required_events": ["huangnigang_all_safe"], "forbidden_events": ["huangnigang_actor_lost"]},
	]
func map_w() -> int: return 48
func map_h() -> int: return 40
func map_theme() -> String: return "hills"
func map_base() -> int: return T.DRYHILL
func camera_start_cell() -> Vector2i: return Vector2i(26, 20)
func deploy_hint() -> String:
	return "可依原著扮贩枣客、借酒下药，也可在身份败露后强夺。任务栏只负责定位现场，所有移动、交互与战斗均由玩家下令。疑心满、久拖或动武会使押队迎战；任一幸存七星或白胜都能接力搬担，三担出冈且有人生还即可通关。"

func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	if not defs.has("ruan_xiaoer"):
		defs["ruan_xiaoer"] = defs["ruan_brother"].duplicate(true)
		defs["ruan_xiaoer"]["name"] = "阮小二"
		defs["ruan_xiaoer"]["hero"] = true
	for key in SEVEN + ["bai_sheng"]:
		defs[key]["art_variant"] = "hn_" + key
	for key in SEVEN + ["bai_sheng", "yang_zhi"]:
		defs[key]["abilities"] = []
		defs[key]["ability"] = ""
		defs[key]["ranged"] = false
		defs[key]["aura"] = ""
	Art.set_runtime_alias({"ruan_xiaoer": "ruan_brother"})
	defs["treasure_cart"]["name"] = "生辰纲担"
	defs["treasure_cart"]["captive"] = true
	defs["treasure_cart"]["radius"] = 12

func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "杨志催着十一名军汉挑担上路，两个虞候、老都管相随。六月黄泥冈上炎热，晁保正等七人扮作贩枣客，把七辆小车歇在松阴里。"},
		{"who": "吴用", "key": "wu_yong", "text": "我们七人作贩枣客，白胜另挑酒来。先把一桶好酒吃给他们看，再借讨酒用瓢下药，休让杨志瞧破。"},
		{"who": "行前提示", "key": "narrator", "text": "七人各守商客身份，白胜另作卖酒人。按任务分头察路、答话、试酒、用瓢；不可向押送人动手。等他们饮酒麻倒，再搬走纲担。"},
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
	actors.clear()
	convoy.clear()
	bundles.clear()
	field_signs.clear()
	for cart_node in jujube_carts:
		if is_instance_valid(cart_node): cart_node.queue_free()
	jujube_carts.clear()
	yang = null
	for i in range(SEVEN.size()):
		var u: Unit = b.spawn_at(SEVEN[i], Unit.FACTION_LIANG, Vector2i(19 + i % 4, 15 + i / 4))
		u.passive = true
		u.stance = Unit.STANCE_PASSIVE
		u.set_meta("merchant_disguise", true)
		actors.append(u)
	for i in range(3):
		var bundle: Unit = b.spawn_at("treasure_cart", Unit.FACTION_GUAN, Vector2i(39 + i, 20))
		bundle.display_name = "生辰纲担·" + ["金银", "绸缎", "礼物"][i]
		bundle.art_variant = "tribute_load"
		bundle.set_meta("campaign_environment_route","tribute_load")
		bundle.set_meta("campaign_environment_state","default")
		# Guards defend these loads and Liangshan heroes seize them through the
		# mission interaction. Ordinary auto-acquire must not destroy the objective;
		# an explicit player attack or real area damage can still do so and fail it.
		bundle.set_meta("campaign_no_auto_target", true)
		# A shoulder-carried load is an interaction prop, not a hall-sized obstacle.
		# Keep this explicit even if the captive setup already skipped registration.
		b.unregister_building_footprint(bundle)
		bundles.append(bundle)
	cart = bundles[0]

func on_start(b) -> void:
	st = PREPARE
	drug_done = false
	rest_t = 0.0
	exposure = 0.0
	delivered = 0
	attention_left = 0.0
	attention_missed = false
	wine_step = ""
	clean_trial = false
	scoop_prepared = false
	sale_drugged = false
	suspicion_seen = false
	cover_restored = false
	suspicious_keys.clear()
	cargo.clear()
	cargo_plan = ""
	cargo_assignments.clear()
	cargo_ready.clear()
	cargo_objective_cache = ""
	force_attempts.clear()
	force_started = false
	smoke_t = 0.0
	b.mission.begin("dates", "贩枣客歇松阴", "吴用察看冈顶，晁盖安置枣车。不要动武。")
	b.mission.add_action("scout_shade", "吴用·察看松阴", Vector2i(29, 17), ["wu_yong"], 1.2)
	b.mission.add_action("place_dates", "晁盖·安置枣车", DATES, ["chao_gai"], 1.5, 40.0)
	_add_sign(b, "贩枣客歇脚处", SHADE, Color(0.65, 0.82, 0.46), 146.0)
	suspicion_sign = _add_sign(b, "杨志疑心 0/100", INSPECT, Color(0.96, 0.72, 0.36))
	suspicion_sign.hide()

func on_mission_action(b, action_id: String, actor) -> void:
	if action_id.begins_with("return_"):
		if actor.position.distance_to(b.map.cell_to_world(_cover_cell(actor.key))) > 56.0:
			_retry_action(b, action_id, "先回自己的枣车旁，装作歇脚商客，莫让杨志继续盯上。")
			return
		actor.set_meta("merchant_disguise", true)
		cover_restored = true
		b.mission.mark("cover_restored_" + actor.key, actor.display_name + "退回枣车，收敛举动，重新作商客歇脚")
		b.mission.set_objective("已回到枣车旁。继续作商客歇脚，等疑心平复再接着酒计；切勿向押送人动武。")
		return
	if action_id.begins_with("force_take_"):
		var parts := action_id.split("_")
		var cargo_index := int(parts[2])
		_force_take_cargo(b, action_id, actor, cargo_index)
		return
	if action_id.begins_with("force_deliver_"):
		var parts := action_id.split("_")
		var cargo_index := int(parts[2])
		_force_deliver_cargo(b, action_id, actor, cargo_index)
		return
	match action_id:
		"scout_shade", "place_dates":
			if st != PREPARE: return
			if action_id == "place_dates": _place_jujube_carts(b)
			b.mission.mark(action_id, {"scout_shade": "吴用看定松阴与去路，退回商客歇脚处", "place_dates": "七星摆好枣车，装作歇脚商客"}[action_id])
			if b.mission.has_event("scout_shade") and b.mission.has_event("place_dates"):
				_start_convoy(b)
		"answer_yang":
			if st != INQUIRY: return
			if not b.mission.has_event("yang_inquired") or not _at(b, yang, INSPECT, 56.0):
				_retry_action(b, action_id, "杨志还没走到枣车前。等他近了，刘唐再当面说明来历。")
				return
			if not _identity_ready(b):
				_retry_action(b, action_id, "有人逼近押担队，露出破绽。先让此人退回枣车，等疑心降至40以下再应答。")
				return
			b.mission.mark("merchant_identity_confirmed", "刘唐答说七人从濠州贩枣去东京，邀看枣货；杨志查过小车，回去歇脚")
			st = ARRIVAL
			yang.order_move(b.map.cell_to_world(Vector2i(28, 21)))
			var bai: Unit = _ensure_bai(b, true)
			bai.set_meta("carrying_wine", true)
			b.mission.mark("bai_arrived", "杨志盘问过后，白胜唱着山歌，另挑两桶酒上冈")
			b.mission.begin("wine_arrival", "白胜挑酒上冈", "盘问已过，白胜才来卖酒。让他把两桶酒挑到冈边，七人仍作不相识的贩枣客。")
			b.mission.add_action("bring_wine", "白胜·挑酒到冈边", Vector2i(23, 24), ["bai_sheng"], 1.5, 40.0)
		"bring_wine":
			if st != ARRIVAL or not b.mission.has_event("merchant_identity_confirmed"): return
			actor.set_meta("carrying_wine", false)
			b.show_campaign_environment_art(id(),"wine_buckets","wine_buckets",
				b.map.cell_to_world(Vector2i(23, 23)),68.0,-1.0)
			b.show_campaign_environment_art(id(),"wine_bowls","wine_bowls",
				b.map.cell_to_world(GOOD_WINE)+Vector2(-15,0),38.0,-1.0)
			good_sign = _add_sign(b, "甲桶·好酒，尚未试饮", GOOD_WINE, Color(0.74, 0.85, 0.50))
			sale_sign = _add_sign(b, "乙桶·原酒，尚未用药", SALE_WINE, Color(0.92, 0.78, 0.49))
			_add_sign(b, "刘唐引注意处", DISTRACT, Color(0.95, 0.73, 0.43), 32.0)
			b.mission.mark("bring_wine", "白胜歇下两桶酒：先试甲桶好酒，乙桶仍未用药")
			st = WINE
			_begin_wine_trial(b, false)
		"taste_wine":
			if st != WINE or wine_step != "trial": return
			if not _identity_ready(b):
				_retry_action(b, action_id, "杨志仍在盯着露出破绽的人，先退回枣车藏住破绽，再试好酒。")
				return
			clean_trial = true
			wine_step = "attention"
			_set_sign(good_sign, "甲桶·试过的好酒，未下药")
			b.mission.mark(action_id, "刘唐领头，七人饮甲桶好酒；押送人看见贩枣客安然无事")
			b.mission.add_action("distract_yang", "刘唐·佯讨乙桶半瓢酒", DISTRACT, ["liu_tang"], 1.2, 40.0)
			b.mission.set_objective("甲桶好酒已饮过。让刘唐到押队看得见的地方，佯讨乙桶半瓢酒，借争酒引住目光；吴用、白胜在桶边接应。")
		"distract_yang":
			if st != WINE or wine_step != "attention" or not clean_trial: return
			if not _attention_valid(b) or not _identity_ready(b):
				_retry_action(b, action_id, "刘唐须到押队看得见的地方，其余人守住伪装，才好借争酒用瓢。")
				return
			attention_left = 22.0
			wine_step = "scoop"
			b.mission.mark("distract_yang", "刘唐佯讨乙桶半瓢酒喝了，白胜争执索还；押送人看在眼里，目光被引住")
			b.mission.add_action("drug_scoop", "吴用·拿药瓢舀乙桶", SALE_WINE, ["wu_yong"], 1.6, 40.0)
			b.mission.set_objective("刘唐留在争酒处。22秒内让吴用靠到乙桶用药瓢，白胜亲自夺瓢倾回；刘唐离开便会失去时机，须重新试酒。")
		"drug_scoop":
			if st != WINE or wine_step != "scoop" or not clean_trial: return
			if attention_left <= 0.0 or not _attention_valid(b) or not _identity_ready(b):
				_reset_wine_attempt(b, "刘唐没能引住押队目光，吴用难以下手；先收瓢退开，重新试酒。")
				return
			scoop_prepared = true
			wine_step = "reclaim"
			_set_sign(sale_sign, "吴用持瓢·等白胜夺回")
			b.mission.mark(action_id, "吴用暗把药藏在瓢中，到乙桶佯作舀酒；白胜正要赶来夺瓢")
			b.mission.add_action("reclaim_scoop", "白胜·夺瓢倾入乙桶", SALE_WINE, ["bai_sheng"], 1.2, 40.0)
		"reclaim_scoop":
			if st != WINE or wine_step != "reclaim" or not scoop_prepared: return
			if attention_left <= 0.0 or not _attention_valid(b) or not _at(b, b.find_unit("wu_yong"), SALE_WINE, 70.0) or not _identity_ready(b):
				_reset_wine_attempt(b, "吴用、白胜要在桶边交接，刘唐仍须引住押队目光；配合已断，先收起药瓢重试。")
				return
			sale_drugged = true
			wine_step = "sale"
			attention_left = 0.0
			_set_sign(sale_sign, "乙桶·已倾药酒，待押队购买")
			b.mission.mark("reclaim_scoop", "白胜夺瓢倾回乙桶；押队先见七人饮甲桶，又见刘唐喝过乙桶半瓢，放下戒心")
			b.mission.add_action("sell_wine", "白胜·把乙桶酒卖给押队", SALE_WINE, ["bai_sheng"], 2.0, 40.0)
		"sell_wine":
			if st != WINE or wine_step != "sale" or not sale_drugged or drug_done: return
			if not _identity_ready(b):
				_retry_action(b, action_id, "押送者正盯着露破绽的人，不肯买酒。让此人回枣车维持伪装后再卖。")
				return
			drug_done = true
			if is_instance_valid(suspicion_sign): suspicion_sign.hide()
			_set_sign(sale_sign, "乙桶·押送者饮药酒麻倒")
			for guard in convoy:
				if is_instance_valid(guard) and guard.hp > 0.0:
					guard.resolve_story("unconscious")
			b.mission.mark("drugged", "军汉、老都管和虞候买酒饮了，杨志也吃半瓢；十五人药性发作，软倒松阴")
			st = CARRY
			for sign_node in field_signs:
				if is_instance_valid(sign_node): sign_node.hide()
			_begin_cargo_choice(b)
		"cargo_group_plan":
			if not _cargo_plan_action_valid(b, action_id, actor, "chao_gai"): return
			cargo_plan = "grouped"
			for i in range(3):
				if not _assign_cargo(i, CARRIERS[i]): return
			b.mission.begin("carry_group", "三人先到担旁", "刘唐、阮小五、阮小七分别到三担旁站定，再一并挑运；三条短路互不挤占。")
			b.mission.mark("cargo_plan_grouped", "晁盖让三人分守北沿、中道、南沿，先在担旁站齐再动身")
			for i in range(3): _add_cargo_stage_action(b, i)
			_refresh_cargo_objective(b)
		"cargo_serial_plan":
			if not _cargo_plan_action_valid(b, action_id, actor, CARRIERS[0]): return
			cargo_plan = "serial"
			if not _assign_cargo(0, CARRIERS[0]): return
			cargo_ready[0] = true
			b.mission.begin("carry_serial", "逐担派送", "刘唐先挑第一担；送到西冈口后，再派下一人到担旁，路上不互相等候。")
			b.mission.mark("cargo_plan_serial", "刘唐先到第一担旁，众人决定逐担派送，送出一担再派下一人")
			b.mission.mark("cargo_ready_0", "刘唐已在第一担旁等候")
			_add_cargo_take_action(b, 0)
			_refresh_cargo_objective(b)
		"withdraw":
			if st != CARRY or delivered != 3:
				return
			st = WITHDRAW
			b.mission.begin("withdraw", "趁醒转前出冈", "三担已经送出。请玩家自行收拢七星与白胜，从西冈口撤离。")
			b.mission.set_status("撤离不会自动执行；可全选、分组或留下掩护，再由玩家下达移动命令。")
		"withdraw_now":
			if st != WITHDRAW or delivered < 3:
				return
			b.mission.mark("huangnigang_depart_early", "先到冈口的好汉带纲担撤走，其余人随后分路脱身")
			_story_miss(b, "all_safe", "没有等七星与白胜全部到达西冈口。")
		_:
			if action_id.begins_with("stage_"):
				var i := int(action_id.trim_prefix("stage_"))
				if not _cargo_stage_action_valid(b, action_id, actor, i): return
				cargo_ready[i] = true
				b.mission.mark("cargo_ready_%d" % i, "%s已在第%d担旁站定，走%s出冈" % [actor.display_name, i + 1, CARGO_ROUTE_NAMES[i]])
				if cargo_plan == "grouped":
					if cargo_ready.size() == 3:
						b.mission.mark("cargo_group_ready", "三名搬运人各守一担，北沿、中道、南沿都已安排妥当")
						for cargo_index in range(3): _add_cargo_take_action(b, cargo_index)
				elif cargo_plan == "serial":
					_add_cargo_take_action(b, i)
				_refresh_cargo_objective(b)
			elif action_id.begins_with("take_"):
				var i := int(action_id.trim_prefix("take_"))
				if not _cargo_take_action_valid(b, action_id, actor, i): return
				cargo[i] = actor
				_pick_up_bundle(b, bundles[i])
				actor.set_meta("carrying_tribute", i)
				actor.apply_slow(0.78, 999.0)
				b.mission.mark(action_id, "%s挑起第%d担，走%s送往西冈口" % [actor.display_name, i + 1, CARGO_ROUTE_NAMES[i]])
				b.mission.add_action("deliver_%d" % i, "%s·走%s送出第%d担" % [actor.display_name, CARGO_ROUTE_NAMES[i], i + 1], GATE_W + Vector2i(0, i - 1), [actor.key], 1.0)
				_refresh_cargo_objective(b)
			elif action_id.begins_with("deliver_"):
				var i := int(action_id.trim_prefix("deliver_"))
				if not _cargo_deliver_action_valid(b, action_id, actor, i): return
				actor.remove_meta("carrying_tribute")
				actor.apply_slow(1.0, 0.0)
				bundles[i].position = b.map.cell_to_world(GATE_W + Vector2i(0, i - 1))
				_put_down_bundle(b, bundles[i])
				delivered += 1
				b.mission.mark(action_id, "第%d担已由%s送出黄泥冈" % [i + 1, CARGO_ROUTE_NAMES[i]])
				if delivered == 3:
					b.mission.add_action("withdraw", "晁盖·招呼众人出冈", GATE_W, ["chao_gai"], 1.0)
				elif cargo_plan == "serial":
					var next_index := i + 1
					if next_index < 3 and _assign_cargo(next_index, CARRIERS[next_index]):
						_add_cargo_stage_action(b, next_index)
				_refresh_cargo_objective(b)
func _place_jujube_carts(b) -> void:
	# Placement reveals the seven carts once. They are scenery, never units or nav blockers.
	if not jujube_carts.is_empty(): return
	for i in range(JUJUBE_CART_CELLS.size()):
		var route_key := "jujube_cart_%02d" % (i+1)
		var texture := EnvironmentArt.object(id(),route_key)
		if texture==null: texture=Art.campaign_object_texture("jujube_cart")
		if texture==null: continue
		var cart_node := JujubeCart.new()
		cart_node.texture = texture
		cart_node.size = JUJUBE_CART_SIZE
		cart_node.life = -1.0
		cart_node.duration = -1.0
		cart_node.position = b.map.cell_to_world(JUJUBE_CART_CELLS[i])
		cart_node.z_as_relative = false
		cart_node.z_index = clampi(1 + int(b.map.project(cart_node.position).y), 1, 3400)
		cart_node.set_meta("campaign_object", "jujube_cart")
		cart_node.set_meta("campaign_environment_route",route_key)
		cart_node.set_meta("campaign_environment_state","default")
		cart_node.set_meta("campaign_environment_fallback_key","jujube_cart")
		cart_node.set_meta("mission_action", "place_dates")
		cart_node.set_meta("jujube_cart_index", i)
		b.fx_root.add_child(cart_node)
		b.map.sync_render_position(cart_node)
		jujube_carts.append(cart_node)
	# 独立枣筐扁担只在摆车事件后出现；缺少新图时复用原有剧情物件。
	b.show_campaign_environment_art(id(),"jujube_load","jujube_load",
		b.map.cell_to_world(DATES)+Vector2(-22,5),54.0,-1.0)

func _pick_up_bundle(b, bundle: Unit) -> void:
	# Carried art belongs to the carrier. Keep this exact node scene-owned for restart cleanup,
	# but remove it from world queries so visibility passes cannot resurrect the ground load.
	b.unregister_building_footprint(bundle)
	b.units.erase(bundle)
	bundle.set_meta("tribute_process_mode", bundle.process_mode)
	bundle.process_mode = Node.PROCESS_MODE_DISABLED
	bundle.hide()
	bundle.set_selected(false)
	bundle.set_inspected(false)
	var selection_changed: bool = b.selection.has(bundle) or b._inspect_unit == bundle
	b.selection.erase(bundle)
	if b._inspect_unit == bundle: b._inspect_unit = null
	if b._active == bundle: b._active = null
	for u in b.units:
		if is_instance_valid(u) and u._target == bundle: u.order_stop()
	if selection_changed: b._update_sel_label()
	# Task completion happens after this frame's normal grid build; evict stale buckets now.
	b._grid_build()

func _put_down_bundle(b, bundle: Unit) -> void:
	if not b.units.has(bundle): b.units.append(bundle)
	bundle.process_mode = int(bundle.get_meta("tribute_process_mode", Node.PROCESS_MODE_INHERIT))
	bundle.remove_meta("tribute_process_mode")
	bundle.show()
	b.map.sync_render_position(bundle)
	bundle.queue_redraw()
	b._grid_build()

func _ensure_bai(b, keep_passive: bool) -> Unit:
	var bai = b.find_unit("bai_sheng")
	if not is_instance_valid(bai):
		bai = b.spawn_at("bai_sheng", Unit.FACTION_LIANG, Vector2i(32, 25))
		actors.append(bai)
	bai.passive = keep_passive
	bai.stance = Unit.STANCE_PASSIVE if keep_passive else Unit.STANCE_AGGRO
	return bai

func _begin_force_route(b, reason: String, violent: bool) -> void:
	if force_started:
		if violent and not b.mission.has_event("huangnigang_convoy_hurt"):
			b.mission.mark("huangnigang_convoy_hurt", "押送队已经受袭，原著无伤酒计不可完成")
			_story_miss(b, "no_bloodshed", "押送者已经受伤或遭到强攻。")
		return
	if convoy.is_empty():
		_start_convoy(b)
	force_started = true
	st = FORCE
	b.mission.mark("huangnigang_force", reason)
	_story_miss(b, "merchant_cover", "身份已经败露，转为强夺生辰纲。")
	_story_miss(b, "wine_scheme", "未能依原著完成卖酒用药。")
	if violent:
		b.mission.mark("huangnigang_convoy_hurt", "七星向押送队动武，双方在冈上交战")
		_story_miss(b, "no_bloodshed", "押送者已经受伤或遭到强攻。")
	if is_instance_valid(suspicion_sign): suspicion_sign.hide()
	for sign_node in field_signs:
		if is_instance_valid(sign_node): sign_node.hide()
	var bai := _ensure_bai(b, false)
	bai.remove_meta("carrying_wine")
	for actor in actors:
		if is_instance_valid(actor) and actor.hp > 0.0:
			actor.passive = false
			actor.stance = Unit.STANCE_AGGRO
	for guard in convoy:
		if is_instance_valid(guard) and guard.hp > 0.0 and guard.story_outcome == "":
			guard.passive = false
			guard.stance = Unit.STANCE_AGGRO
			guard.order_amove(b.map.cell_to_world(SHADE))
	b.mission.begin("force_cargo", "身份败露·强夺纲担", "押送队已经拒酒并迎战。可由任一活着的七星或白胜到担旁挑走三担；搬运者倒下时纲担会原地落下，可换人接力。")
	for i in range(3):
		if _cargo_was_delivered(b, i):
			continue
		if cargo.has(i) and is_instance_valid(cargo[i]) and cargo[i].hp > 0.0:
			_add_force_deliver(b, i, cargo[i])
		else:
			_add_force_take(b, i)

func _cargo_was_delivered(b, index: int) -> bool:
	return b.mission.has_event("deliver_%d" % index) or b.mission.has_event("force_delivered_%d" % index)

func _add_force_take(b, index: int) -> void:
	if st != FORCE or index < 0 or index >= bundles.size() or _cargo_was_delivered(b, index): return
	if not is_instance_valid(bundles[index]) or not b.units.has(bundles[index]): return
	var attempt: int = int(force_attempts.get(index, 0))
	var action_id := "force_take_%d_%d" % [index, attempt]
	# The load remains Guan-faction cargo until it is carried out. Putting the
	# marker on its sprite turns a normal right click into order_attack and destroys
	# the objective, so the player claims it from the clear ground beside the load.
	var available := _available_force_carriers()
	# CampaignMission treats an empty actor list as "any Liang unit". Use a key
	# that no real unit owns while every survivor is already carrying another load.
	if available.is_empty(): available.append(NO_FORCE_CARRIER)
	b.mission.add_action(action_id, "任一好汉·接手第%d担" % (index + 1), _bundle_claim_cell(b, index), available, 1.0, 48.0)


func _available_force_carriers() -> Array:
	var keys: Array = []
	for candidate in actors:
		if is_instance_valid(candidate) and candidate.hp > 0.0 and candidate.story_outcome == "" \
				and not candidate.has_meta("carrying_tribute"):
			keys.append(candidate.key)
	return keys


func _set_force_carrier_eligible(b, actor_key: String, eligible: bool) -> void:
	for pending_id in b.mission.actions:
		if not String(pending_id).begins_with("force_take_"):
			continue
		var pending: Dictionary = b.mission.actions[pending_id]
		if bool(pending.get("done", false)):
			continue
		var allowed: Array = Array(pending.get("actors", [])).duplicate()
		if eligible:
			allowed.erase(NO_FORCE_CARRIER)
			if not allowed.has(actor_key): allowed.append(actor_key)
		else:
			allowed.erase(actor_key)
			if allowed.is_empty(): allowed.append(NO_FORCE_CARRIER)
		b.mission.update_action_actors(String(pending_id), allowed)

func _add_force_deliver(b, index: int, actor) -> void:
	if st != FORCE or not is_instance_valid(actor) or actor.hp <= 0.0: return
	var attempt: int = int(force_attempts.get(index, 0))
	var action_id := "force_deliver_%d_%d" % [index, attempt]
	b.mission.add_action(action_id, "%s·送出第%d担" % [actor.display_name, index + 1], GATE_W + Vector2i(0, index - 1), [actor.key], 1.0)

func _force_take_cargo(b, action_id: String, actor, index: int) -> void:
	if st != FORCE or index < 0 or index >= bundles.size() or _cargo_was_delivered(b, index) or cargo.has(index): return
	if not is_instance_valid(actor) or actor.hp <= 0.0 or actor.story_outcome != "": return
	if actor.has_meta("carrying_tribute"):
		_set_force_carrier_eligible(b, actor.key, false)
		_retry_action(b, action_id, actor.display_name + "已经挑着一担，请另选一名好汉接手。")
		return
	if not is_instance_valid(bundles[index]) or not b.units.has(bundles[index]): return
	cargo[index] = actor
	_pick_up_bundle(b, bundles[index])
	actor.set_meta("carrying_tribute", index)
	_set_force_carrier_eligible(b, actor.key, false)
	actor.apply_slow(0.78, 999.0)
	b.mission.mark("force_taken_%d_%d" % [index, int(force_attempts.get(index, 0))], actor.display_name + "在混战中挑起第%d担" % (index + 1))
	_add_force_deliver(b, index, actor)

func _force_deliver_cargo(b, _action_id: String, actor, index: int) -> void:
	if st != FORCE or index < 0 or index >= bundles.size() or _cargo_was_delivered(b, index): return
	if not is_instance_valid(actor) or actor.hp <= 0.0 or not cargo.has(index) or cargo[index] != actor or actor.get_meta("carrying_tribute", -1) != index: return
	actor.remove_meta("carrying_tribute")
	_set_force_carrier_eligible(b, actor.key, true)
	actor.apply_slow(1.0, 0.0)
	bundles[index].position = b.map.cell_to_world(GATE_W + Vector2i(0, index - 1))
	bundles[index].faction = Unit.FACTION_LIANG
	_put_down_bundle(b, bundles[index])
	cargo.erase(index)
	delivered += 1
	b.mission.mark("force_delivered_%d" % index, "第%d担已由%s强夺出冈" % [index + 1, actor.display_name])
	if delivered >= 3:
		_begin_free_withdraw(b)

func _drop_carried_bundle(b, actor) -> void:
	var index := int(actor.get_meta("carrying_tribute", -1))
	if index < 0 or index >= bundles.size() or not cargo.has(index) or cargo[index] != actor: return
	var drop_cell: Vector2i = b.map.nearest_open(b.map.world_to_cell(actor.position), "land")
	bundles[index].position = b.map.cell_to_world(drop_cell)
	_put_down_bundle(b, bundles[index])
	cargo.erase(index)
	force_attempts[index] = int(force_attempts.get(index, 0)) + 1
	b.mission.mark("force_drop_%d_%d" % [index, int(force_attempts[index])], actor.display_name + "倒下，第%d担落在原地，可由他人接力" % (index + 1))
	if st == FORCE: _add_force_take(b, index)

func _begin_free_withdraw(b) -> void:
	if st == WITHDRAW: return
	st = WITHDRAW
	b.mission.begin("withdraw", "带纲担撤出黄泥冈", "三担已经送出，至少让一名幸存好汉到达西冈口即可脱身。")
	b.mission.set_status("请自行决定谁先带担撤退、谁负责断后；系统不会替全队出冈。")

func _begin_cargo_choice(b) -> void:
	cargo_plan = ""
	cargo_assignments.clear()
	cargo_ready.clear()
	cargo_objective_cache = ""
	b.mission.begin("carry_plan", "商定搬担办法", "三担只各走一次：可让三人先到担旁分守三路，也可逐担派人，送出一担再接下一担。")
	b.mission.add_action("cargo_group_plan", "晁盖·先分三路站位", CARGO_GROUP_POINT, ["chao_gai"], 0.8, 40.0)
	b.mission.add_action("cargo_serial_plan", "刘唐·先到第一担旁逐担派送", CARGO_STAGE_CELLS[0], [CARRIERS[0]], 0.8, 40.0)
	_refresh_cargo_objective(b)

func _cargo_plan_action_valid(b, action_id: String, actor, actor_key: String) -> bool:
	return st == CARRY and cargo_plan == "" and _mission_action_done(b, action_id) \
		and is_instance_valid(actor) and actor.hp > 0.0 and actor.story_outcome == "" and actor.key == actor_key

func _mission_action_done(b, action_id: String) -> bool:
	return b.mission.actions.has(action_id) and bool(b.mission.actions[action_id].done)

func _assign_cargo(index: int, actor_key: String) -> bool:
	if index < 0 or index >= CARRIERS.size() or CARRIERS[index] != actor_key:
		return false
	if cargo_assignments.has(index) or cargo_assignments.values().has(actor_key):
		return false
	cargo_assignments[index] = actor_key
	return true

func _cargo_stage_action_valid(b, action_id: String, actor, index: int) -> bool:
	return is_instance_valid(actor) and actor.hp > 0.0 and actor.story_outcome == "" \
		and st == CARRY and cargo_plan in ["grouped", "serial"] and index >= 0 and index < 3 \
		and cargo_assignments.has(index) and String(cargo_assignments[index]) == actor.key \
		and not cargo_ready.has(index) and _mission_action_done(b, action_id)

func _cargo_take_action_valid(b, action_id: String, actor, index: int) -> bool:
	return is_instance_valid(actor) and actor.hp > 0.0 and actor.story_outcome == "" \
		and st == CARRY and index >= 0 and index < 3 and cargo_ready.has(index) \
		and cargo_assignments.has(index) and String(cargo_assignments[index]) == actor.key \
		and not cargo.has(index) and _mission_action_done(b, action_id) \
		and is_instance_valid(bundles[index]) and b.units.has(bundles[index])

func _cargo_deliver_action_valid(b, action_id: String, actor, index: int) -> bool:
	return is_instance_valid(actor) and actor.hp > 0.0 and actor.story_outcome == "" \
		and st == CARRY and index >= 0 and index < 3 and cargo.has(index) and cargo[index] == actor \
		and cargo_assignments.has(index) and String(cargo_assignments[index]) == actor.key \
		and actor.get_meta("carrying_tribute", -1) == index and not b.mission.has_event(action_id) \
		and _mission_action_done(b, action_id) and is_instance_valid(bundles[index]) and not b.units.has(bundles[index])

func _add_cargo_stage_action(b, index: int) -> void:
	if index < 0 or index >= 3 or not cargo_assignments.has(index) or cargo_ready.has(index): return
	var action_id := "stage_%d" % index
	if b.mission.actions.has(action_id): return
	var actor_name: String = b._defs[CARRIERS[index]]["name"]
	var label := "%s·到第%d担旁走%s" % [actor_name, index + 1, CARGO_ROUTE_NAMES[index]]
	if cargo_plan == "serial": label = "%s·到第%d担旁接手" % [actor_name, index + 1]
	b.mission.add_action(action_id, label, CARGO_STAGE_CELLS[index], [CARRIERS[index]], 0.8, 40.0)

func _add_cargo_take_action(b, index: int) -> void:
	if index < 0 or index >= 3 or not cargo_assignments.has(index) or not cargo_ready.has(index) or cargo.has(index): return
	var action_id := "take_%d" % index
	if b.mission.actions.has(action_id): return
	b.mission.add_action(action_id, "%s·挑起第%d担" % [b._defs[CARRIERS[index]]["name"], index + 1], _bundle_claim_cell(b, index), [CARRIERS[index]], 1.2)


func _bundle_claim_cell(b, index: int) -> Vector2i:
	if index < 0 or index >= bundles.size() or not is_instance_valid(bundles[index]):
		return TOP + Vector2i(index, 2)
	var bundle_cell: Vector2i = b.map.world_to_cell(bundles[index].position)
	# Two logical cells are visually beside the load, yet their projected click is
	# outside the unit hit radius even at the far campaign zoom.
	return b.map.nearest_open(bundle_cell + Vector2i(0, 2), "land")

func _cargo_assignment_state(b, index: int) -> String:
	if b.mission.has_event("deliver_%d" % index): return "已送出"
	if cargo.has(index): return "挑运中"
	if cargo_ready.has(index): return "已到位"
	if cargo_assignments.has(index): return "去担旁"
	return "待派"

func _refresh_cargo_objective(b) -> void:
	if st != CARRY: return
	var plan_label := "待选办法"
	if cargo_plan == "grouped": plan_label = "集中编组"
	elif cargo_plan == "serial": plan_label = "逐担派送"
	var entries: Array[String] = []
	for i in range(3):
		entries.append("第%d担 %s·%s %s" % [i + 1, b._defs[CARRIERS[i]]["name"], CARGO_ROUTE_NAMES[i], _cargo_assignment_state(b, i)])
	var objective := "%s｜%s。三担各走一次；昏倒的押送者不可再攻击。" % [plan_label, "；".join(entries)]
	if objective == cargo_objective_cache: return
	cargo_objective_cache = objective
	b.mission.set_objective(objective)

func _start_convoy(b) -> void:
	st = MARCH
	b.mission.begin("convoy", "杨志催担上冈", "押队沿山道上冈。七人在枣车旁作歇脚商客，白胜尚未出场；杨志到后会先盘问来历。")
	yang = b.spawn_at("yang_zhi", Unit.FACTION_GUAN, GATE_E + Vector2i(0, -1))
	convoy.append(yang)
	for key in ["yu_hou", "yu_hou", "lao_duguan"]:
		convoy.append(b.spawn_at(key, Unit.FACTION_GUAN, GATE_E + Vector2i(0, 1)))
	for i in range(11):
		convoy.append(b.spawn_at("jun_han", Unit.FACTION_GUAN, GATE_E + Vector2i(-i % 3, i % 3 - 1)))
	for i in range(convoy.size()):
		var u: Unit = convoy[i]
		u.passive = true
		u.stance = Unit.STANCE_PASSIVE
		u.defeat_outcome = "subdued"
		u.order_move(b.map.cell_to_world(TOP + Vector2i(i % 4 - 1, i / 4 - 2)))
	b.msg("军汉挑着担子上冈。杨志不肯歇，老都管与军汉却只顾寻阴凉。", 5.0)

func _cover_cell(key: String) -> Vector2i:
	var i: int = maxi(0, SEVEN.find(key))
	return Vector2i(19 + i % 4, 16 + i / 4)

func _at(b, u, cell: Vector2i, distance: float) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "" and u.position.distance_to(b.map.cell_to_world(cell)) <= distance and b.map._segment_open(u.position, b.map.cell_to_world(cell), u.movement_profile)

func _find_suspicious(b) -> Array[String]:
	var found: Array[String] = []
	for u in actors:
		if not is_instance_valid(u) or u.hp <= 0.0: continue
		# A task is permission to walk to its role location, not permission to complete it remotely.
		if b.mission._actor == u and b.mission.active_action_id != "": continue
		if u.position.distance_to(b.map.cell_to_world(SHADE)) <= 146.0: continue
		if st in [INQUIRY, ARRIVAL] and u.key == "liu_tang" and _at(b, u, ANSWER, 64.0): continue
		if st in [ARRIVAL, WINE] and b.mission.has_event("bring_wine"):
			var cell: Vector2i = b.map.world_to_cell(u.position)
			if cell.x >= 20 and cell.x <= 25 and cell.y >= 22 and cell.y <= 26: continue
			if u.key == "liu_tang" and _at(b, u, DISTRACT, 64.0): continue
		if u.key == "bai_sheng" and st == ARRIVAL: continue
		var near_convoy: bool = is_instance_valid(yang) and u.position.distance_to(yang.position) < 176.0
		for bundle in bundles:
			if u.position.distance_to(bundle.position) < 110.0: near_convoy = true
		if near_convoy: found.append(u.key)
	return found

func _identity_ready(b) -> bool:
	if not _find_suspicious(b).is_empty() or exposure >= 40.0: return false
	for u in actors:
		if is_instance_valid(u) and not u.get_meta("merchant_disguise", true): return false
	return b.mission.has_event("place_dates")

func _suspicion_tick(b, delta: float) -> void:
	suspicious_keys = _find_suspicious(b)
	if suspicious_keys.is_empty():
		# A return command stops further escalation, but doubt cannot drain remotely before re-entering the merchant area.
		var returning_outside: bool = b.mission.active_action_id.begins_with("return_") and is_instance_valid(b.mission._actor) and b.mission._actor.position.distance_to(b.map.cell_to_world(SHADE)) > 146.0
		if not returning_outside: exposure = maxf(0.0, exposure - 24.0 * delta)
		if suspicion_seen and cover_restored and exposure <= 0.0 and _identity_ready(b):
			b.mission.mark("suspicion_recovered", "露破绽的人已回枣车重新歇脚，杨志的疑心平复；酒计可以继续")
	else:
		exposure = minf(100.0, exposure + 22.0 * delta)
		var names: Array[String] = []
		for key in suspicious_keys:
			var u = b.find_unit(key)
			u.set_meta("merchant_disguise", false)
			names.append(u.display_name)
			var action_id := "return_" + key
			if not b.mission.actions.has(action_id):
				b.mission.add_action(action_id, u.display_name + "·退回枣车收敛举动", _cover_cell(key), [key], 0.8, 40.0)
			elif b.mission.actions[action_id].done:
				_retry_action(b, action_id, "")
		if not suspicion_seen:
			suspicion_seen = true
			b.mission.mark("suspicion_raised", "有人离开枣车，逼近押担队，杨志起疑；让露出破绽的人回车旁歇脚")
		b.mission.set_objective("%s逼近押队，疑心%d/100；让此人退回枣车藏住破绽。疑心到100或向押送人动武，酒计便告败。" % ["、".join(names), ceili(exposure)])
	if is_instance_valid(suspicion_sign):
		suspicion_sign.show()
		suspicion_sign.position = yang.position
		b.map.sync_render_position(suspicion_sign)
		var names: Array[String] = []
		for key in suspicious_keys: names.append(b._defs[key]["name"])
		_set_sign(suspicion_sign, "杨志疑心 %d/100%s" % [ceili(exposure), "·" + "、".join(names) if not names.is_empty() else ""])
	if exposure >= 100.0:
		b.mission.mark("exposed", "贩枣客反复逼近押担队，杨志识破身份，拒饮催担")
		_begin_force_route(b, "疑心已到100，杨志识破贩枣身份；七星决定强夺纲担", false)

func _attention_valid(b) -> bool:
	var liu = b.find_unit("liu_tang")
	return _at(b, liu, DISTRACT, 56.0) and is_instance_valid(yang) and liu.position.distance_to(yang.position) < 200.0 and b.map._segment_open(liu.position, yang.position, "land")

func _begin_wine_trial(b, retry: bool) -> void:
	wine_step = "trial"
	clean_trial = false
	scoop_prepared = false
	attention_left = 0.0
	_set_sign(good_sign, "甲桶·好酒，可先试饮")
	_set_sign(sale_sign, "乙桶·等候用瓢")
	b.mission.begin("wine_retry" if retry else "wine_trial", "重新试酒" if retry else "先试一桶好酒", "先让刘唐领头饮甲桶好酒，再佯讨乙桶半瓢，引住押队目光。吴用拿药瓢到乙桶舀酒，白胜夺瓢倾回。")
	b.mission.add_action("taste_wine", "刘唐·再试甲桶好酒" if retry else "刘唐·领头饮甲桶好酒", GOOD_WINE, ["liu_tang"], 1.4, 40.0)
	# A failed wine handoff must not delete an unresolved disguise recovery task.
	for u in actors:
		if is_instance_valid(u) and not u.get_meta("merchant_disguise", true):
			b.mission.add_action("return_" + u.key, u.display_name + "·退回枣车收敛举动", _cover_cell(u.key), [u.key], 0.8, 40.0)

func _reset_wine_attempt(b, reason: String) -> void:
	if sale_drugged or drug_done: return
	attention_missed = true
	b.mission.mark("missed_attention", "借瓢配合已断，先收瓢退开；重新试酒，另寻时机")
	_begin_wine_trial(b, true)
	b.msg(reason + " 杨志催担在即，歇脚余时不会增加。", 5.0)

func _retry_action(b, action_id: String, reason: String) -> void:
	if b.mission.actions.has(action_id):
		var action: Dictionary = b.mission.actions[action_id]
		action.done = false
		action.button.disabled = false
		action.marker.show()
		b.mission._refresh_marker_captions()
	if reason != "":
		b.mission.set_objective(reason)
		b.msg(reason, 4.0)

func _add_sign(b, label: String, cell: Vector2i, tint: Color, radius := 20.0):
	var sign_node := FieldSign.new()
	sign_node.label = label
	sign_node.tint = tint
	sign_node.radius = radius
	sign_node.position = b.map.cell_to_world(cell)
	sign_node.z_index = 3440
	b.fx_root.add_child(sign_node)
	b.map.sync_render_position(sign_node)
	field_signs.append(sign_node)
	return sign_node

func _set_sign(sign_node, label: String) -> void:
	if is_instance_valid(sign_node):
		sign_node.label = label
		sign_node.queue_redraw()

func process(b, delta: float) -> void:
	if b._smoke:
		_smoke_drive(b, delta)
	if not drug_done:
		for guard in convoy:
			if is_instance_valid(guard) and (guard.hp < guard.max_hp - 0.5 or guard.story_outcome != ""):
				_begin_force_route(b, "押送人受袭，商客身份败露；酒计转为强夺", true)
				break
		for actor in actors:
			if is_instance_valid(actor) and is_instance_valid(actor._target) and (actor._target in convoy or actor._target in bundles):
				_begin_force_route(b, "七星主动向押送队动武，酒计转为强夺", true)
				break
	if st in [INQUIRY, ARRIVAL, WINE]:
		_suspicion_tick(b, delta)
		if b.phase == b.Phase.END: return
	if st in [ARRIVAL, WINE]:
		rest_t += delta
		if rest_t > 100.0:
			_begin_force_route(b, "歇脚太久，杨志拒绝再等；七星只得强夺纲担", false)
	match st:
		MARCH:
			for i in range(bundles.size()):
				bundles[i].position = bundles[i].position.move_toward(b.map.cell_to_world(TOP + Vector2i(i, 0)), 62.0 * delta)
			if is_instance_valid(yang) and yang.position.distance_to(b.map.cell_to_world(TOP)) < 110.0:
				st = INQUIRY
				for guard in convoy:
					guard.order_stop()
				for i in range(bundles.size()):
					bundles[i].position = b.map.cell_to_world(TOP + Vector2i(i, 0))
				yang.order_move(b.map.cell_to_world(INSPECT))
				b.mission.begin("inquiry", "杨志察看贩枣客", "杨志先来查枣货，白胜还未到。刘唐当面说明来历，其余好汉留在枣车周围；冒进逼近押队会积累疑心。")
				b.mission.add_action("answer_yang", "刘唐·当面应答杨志", ANSWER, ["liu_tang"], 1.5, 40.0)
		INQUIRY:
			if _at(b, yang, INSPECT, 56.0):
				yang.order_stop()
				b.mission.mark("yang_inquired", "杨志走到枣车前，盘问七名商客何来何往")
		WINE:
			if wine_step in ["scoop", "reclaim"] and not sale_drugged:
				if not _attention_valid(b):
					_reset_wine_attempt(b, "刘唐离开押队前的位置，众人目光不再被引住。")
					return
				attention_left = maxf(0.0, attention_left - delta)
				if attention_left <= 0.0:
					_reset_wine_attempt(b, "22秒已过，争酒没能引住押队目光；须重新试酒。")
		WITHDRAW:
			var any_out := false
			var all_alive := true
			var all_out := true
			for u in actors:
				if not is_instance_valid(u) or u.hp <= 0.0:
					all_alive = false
					all_out = false
				else:
					var at_exit: bool = u.position.distance_to(b.map.cell_to_world(GATE_W)) <= 150.0
					any_out = any_out or at_exit
					all_out = all_out and at_exit
			if any_out and delivered >= 3:
				if not force_started and all_alive and not all_out and not b.mission.has_event("huangnigang_depart_early"):
					if not b.mission.actions.has("withdraw_now"):
						b.mission.add_action("withdraw_now", "可选·先行撤走（放弃全员出冈印）", GATE_W, [], 0.6)
					b.mission.set_objective("已有好汉到达西冈口。可等七星与白胜全部赶到；也可选择先行撤走，立即完成夺纲核心目标。")
					return
				if not force_started and all_alive and all_out and actors.size() == 8:
					b.mission.mark("huangnigang_all_safe", "七星与白胜均活着踏上撤出黄泥冈的道路，三担财物搬运完毕")
				else:
					_story_miss(b, "all_safe", "仍有好汉未能全身出冈。")
				b.mission.mark("escaped", "至少一名好汉带着三担财物撤出黄泥冈")
				b.win("身份虽已败露，幸存好汉仍夺下三担生辰纲，活着撤出黄泥冈。" if force_started else "七星施计，白胜卖酒。押送人麻倒松阴，生辰纲由好汉挑出冈去；杨志醒时，担子早已不见。")

func on_unit_died(b, u) -> void:
	if u in actors:
		_drop_carried_bundle(b, u)
		b.mission.mark("huangnigang_actor_lost", u.display_name + "折在黄泥冈，其余好汉仍可接力夺担")
		_story_miss(b, "all_safe", "七星或白胜已有伤亡。")
		_begin_force_route(b, "好汉已有伤亡，余众改以强夺接力完成核心目标", true)
		if actors.filter(func(actor): return is_instance_valid(actor) and actor.hp > 0.0).is_empty():
			b.lose("七星与白胜已经全部倒下，无人能够带走纲担。")
	elif u in bundles:
		b.lose("纲担被毁，三担生辰纲已不可能全部带出冈。")
	elif u in convoy:
		b.mission.mark("huangnigang_convoy_hurt", "押送者已有伤亡，原著无伤酒计不可完成")
		_story_miss(b, "no_bloodshed", "押送者已有伤亡。")
		_begin_force_route(b, "押送者已有伤亡，七星继续强夺纲担", true)

func on_unit_resolved(b, u, outcome: String) -> void:
	if u in convoy and not drug_done and outcome != "unconscious":
		_begin_force_route(b, "押送者被制服，酒计已经败露；七星继续强夺纲担", true)

func top_status(_b) -> String:
	var phase_name: String = ["摆枣察路", "押队上冈", "杨志盘问", "白胜挑酒", "配合酒计", "挑担出冈", "招呼撤离", "身份败露·强夺"][st]
	var detail := ""
	if st in [INQUIRY, ARRIVAL, WINE]: detail = " | 疑心%d/100" % ceili(exposure)
	if st in [ARRIVAL, WINE]: detail += " · 歇脚剩%d秒" % ceili(maxf(0.0, 100.0 - rest_t))
	if wine_step in ["scoop", "reclaim"] and not sale_drugged: detail += " · 引注意%d秒" % ceili(attention_left)
	if st == CARRY and cargo_plan != "": detail += " · %s" % ("集中编组" if cargo_plan == "grouped" else "逐担派送")
	return "智取生辰纲 | %s%s | 送担%d/3" % [phase_name, detail, delivered]

func _story_miss(b, goal_id: String, reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id, reason)

func _smoke_drive(b, delta: float) -> void:
	if b.mission.active_action_id != "":
		return
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 0.8
	# SMOKE 只负责自动回归。正式游戏从任务按钮到撤离都不会替玩家下令。
	if st == WITHDRAW:
		var exit_world: Vector2 = b.map.cell_to_world(GATE_W + Vector2i(-2, 0))
		for i in range(actors.size()):
			var actor: Unit = actors[i]
			if is_instance_valid(actor) and actor.hp > 0.0 and actor.story_outcome == "":
				actor.order_move(exit_world + Vector2((i % 4) * 18.0, (i / 4) * 18.0))
	for action_id in b.mission.actions:
		if action_id.begins_with("return_") and b.mission.request_action(action_id): return
	for action_id in ["scout_shade", "place_dates", "answer_yang", "bring_wine", "taste_wine", "distract_yang", "drug_scoop", "reclaim_scoop", "sell_wine", "cargo_serial_plan", "stage_0", "take_0", "deliver_0", "stage_1", "take_1", "deliver_1", "stage_2", "take_2", "deliver_2", "withdraw"]:
		if b.mission.request_action(action_id):
			return

class JujubeCart extends Node2D:
	static var contact_texture: GradientTexture2D
	var texture: Texture2D
	var size := 72.0
	var life := -1.0
	var duration := -1.0
	var contact_shadow_enabled := true
	func _ready() -> void:
		if contact_texture != null: return
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(0.035, 0.025, 0.015, 0.22), Color(0.035, 0.025, 0.015, 0.12), Color(0.035, 0.025, 0.015, 0.0)])
		contact_texture = GradientTexture2D.new()
		contact_texture.gradient = gradient
		contact_texture.width = 64
		contact_texture.height = 24
		contact_texture.fill = GradientTexture2D.FILL_RADIAL
		contact_texture.fill_from = Vector2(0.5, 0.5)
		contact_texture.fill_to = Vector2(1.0, 0.5)
	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		if contact_shadow_enabled and contact_texture != null:
			draw_texture_rect(contact_texture, Rect2(-size * 0.30, -size * 0.04, size * 0.60, size * 0.20), false)
		if texture != null:
			draw_texture_rect(texture, Rect2(-size * 0.5, -size * 0.82, size, size), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)

class FieldSign extends Node2D:
	var label := ""
	var tint := Color.WHITE
	var radius := 20.0
	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(tint, 0.55), 1.4)
		draw_set_transform_matrix(GameMap.ISO_INV)
		draw_string(ThemeDB.fallback_font, Vector2(-104, -36), label, HORIZONTAL_ALIGNMENT_CENTER, 208, 12, tint)
