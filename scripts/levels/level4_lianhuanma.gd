extends LevelBase
## 原著56—57回：盗甲招徐宁，半月练兵，草林钩镰伏兵破连环马。
## 训练与实战分开重部署；韩滔被擒，呼延灼骑御赐马脱走青州。
const T := GameMap.T
const JIANGTAI_CELL := Vector2i(16,30)
const GATE_E := Vector2i(57,24)
const GATE_S := Vector2i(57,44)
const XU_IN := Vector2i(14,42)
const REED_W := Vector2i(24,30)
const REED_S := Vector2i(34,42)
const DRILL_BONUS := 6.0
const DRILL_CELL := Vector2i(24,40)
const DRILL_APPROACH := Vector2i(29,40)
const DRILL_LURE_ENTRY := Vector2i(27,40)
const DRILL_LURE_RETREAT := Vector2i(21,37)
const HOOK_TEAM_SIZE := 2
const HOOK_TEAM_RADIUS := 240.0
const LURE_RETREAT_RADIUS := 64.0
const LURE_CLEAR_RADIUS := 112.0
const WAVE_SIZE := 6
var stage := "training"
var jiangtai: Unit
var xu: Unit
var hu: Unit
var han: Unit
var dummy: Unit
var riders: Array = []
var broken_count := 0
var lhm_killed := 0
var lhm_total := 12
var smoke_t := 0.0
var battle_started := false
var hu_fleeing := false
var team_status_t := 0.0
var training_lure: Unit
var training_lure_entered := false
var training_lure_withdrew := false
var first_lane := ""
var rear_lane := ""
var wave_phase := ""
var front_lure: Unit
var rear_lure: Unit
var front_broken := 0
var rear_broken := 0
var front_defeated := 0
var rear_defeated := 0
var free_battle := false
var training_skipped := false
var xu_lost := false

func id() -> String: return "level4"
func title() -> String: return "大破连环马"
func subtitle() -> String: return "盗甲招师·晓夜练兵·草林破阵"
func campaign_core_goal() -> String: return "守住中军，击溃十二骑连环马并解除官军主阵。训练和钩镰伏击是可选演义目标。"
func story_contract_version() -> int: return 1
func campaign_story_goals() -> Array:
	return [
		{"id":"lhm_training","label":"徐宁授艺，诱骑撤步后协同下钩","required_events":["lhm_drill_complete"],"forbidden_events":["lhm_training_skipped"]},
		{"id":"lhm_hooks","label":"十二骑均先在草林中被钩破连环阵","required_events":["lhm_all_hook_broken"],"forbidden_events":["lhm_direct_break"]},
		{"id":"lhm_han","label":"生擒韩滔","required_events":["lhm_han_captured"],"forbidden_events":[]},
		{"id":"lhm_hu","label":"呼延灼骑踢雪乌骓败走青州","required_events":["lhm_hu_fled"],"forbidden_events":[]},
	]
func map_w() -> int: return 60
func map_h() -> int: return 60
func map_theme() -> String: return "plain"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(23,36)
func deploy_hint() -> String:
	return "可按原著完成徐宁授艺、两路诱骑与钩镰协同，也可跳过训练后正面或混合迎战。未破阵甲马有高额减伤，因此强攻代价更高；击溃十二骑并解除官军主阵即可通关，韩滔生擒、呼延灼退青州另计演义印。"
func intro_lines() -> Array:
	return [
		{"who":"旁白","key":"narrator","text":"呼延灼的连环甲马使梁山受挫。吴用遣时迁盗走徐宁的祖传雁翎砌就圈金甲，再由汤隆赚他上山，请他传授钩镰枪法。"},
		{"who":"徐宁","key":"xu_ning","text":"钩镰枪有钩有拨，步下还能专取马脚。你们先看我演练，学熟之后藏林伏草；钩倒甲马，再与同伴合力拿人。"},
		{"who":"军令","key":"narrator","text":"教场上先练诱骑与撤步：汤隆把演练骑引进打击道，退开后徐宁、搭档才下钩。出战分前后两队，第一伏用过，预备队须换到另一侧再诱一次。"}]

func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	defs["hook_training_dummy"] = {"name":"钩镰演练骑","hp":120,"atk":0,"speed":55,"cavalry":true,"radius":13,"defeat_outcome":"subdued","art_variant":"hook_training_dummy"}
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
	stage = "training"
	free_battle = false
	training_skipped = false
	xu_lost = false
	xu = b.spawn_at("xu_ning",Unit.FACTION_LIANG,Vector2i(16,40))
	var tang = b.spawn_at("tang_long",Unit.FACTION_LIANG,Vector2i(17,42))
	tang.stance = Unit.STANCE_PASSIVE
	for c in [Vector2i(19,42),Vector2i(20,42),Vector2i(21,42)]:
		var u = b.spawn_at("gou_lian",Unit.FACTION_LIANG,c)
		u.stance = Unit.STANCE_PASSIVE

func on_start(b) -> void:
	b.mission.begin("lhm_training","演练·徐宁授艺","先让徐宁演示，再派钩镰手搭档就位。随后由汤隆引演练骑入道、撤出打击线，徐宁才可下钩。")
	b.mission.add_action("lhm_drill","徐宁：演示钩镰枪",Vector2i(20,40),["xu_ning"],3.0)
	# Keep the deliberate branch marker away from the authored drill lane so a
	# normal order to the wooden horse cannot claim "skip training" by proximity.
	b.mission.add_action("lhm_skip_training","直接整军出战（不计授艺印）",Vector2i(12,47),["xu_ning","tang_long","gou_lian"],0.6,48.0)

func on_mission_action(b, action_id: String, actor) -> void:
	match action_id:
		"lhm_skip_training":
			if stage != "training": return
			training_skipped = true
			b.mission.mark("lhm_training_skipped","梁山未完成教场协同，直接整军迎战连环马")
			_miss_story(b,"lhm_training","跳过徐宁授艺与诱骑撤步演练")
			stage = "transition"
			_deploy_battle.call_deferred(b)
		"lhm_drill":
			if stage != "training" or b.mission.has_event("lhm_drill_started"): return
			b.mission.mark("lhm_drill_started","徐宁演示钩镰枪配合")
			b.show_story_art("hook_spear_team",xu.position,128.0,3.0,"engaged")
			b.mission.add_action("lhm_partner","钩镰手：搭档就位",DRILL_CELL+Vector2i(0,1),["gou_lian"],2.0)
			b.mission.set_objective("另派一名钩镰手到木马旁配合徐宁。单人不能形成上下照应。")
		"lhm_partner":
			if stage != "training" or b.mission.has_event("lhm_drill_complete"): return
			if not _hooks_near(b,b.map.cell_to_world(DRILL_CELL)):
				_retry_action(b,action_id,"搭档不足：把徐宁和一名钩镰手移到木马旁，再检查就位。")
				return
			_clear_dummy(b)
			training_lure = null
			training_lure_entered = false
			training_lure_withdrew = false
			b.mission.mark("lhm_drill_pair_ready","徐宁与钩镰搭档就位，开始协同演练")
			dummy = b.spawn_at("hook_training_dummy",Unit.FACTION_GUAN,DRILL_APPROACH)
			dummy.passive = true
			dummy.stance = Unit.STANCE_PASSIVE
			dummy.order_hold_position()
			xu.bonus_vs_cav = DRILL_BONUS
			b.mission.add_action("lhm_training_lure","汤隆：引演练骑入道",DRILL_LURE_ENTRY,["tang_long"],1.2)
			_reopen_action(b,"lhm_training_lure")
			b.mission.set_objective("让汤隆走到演练骑前引它入道；他撤到打击线外后，徐宁与搭档才能下钩。")
		"lhm_training_lure":
			if stage != "training" or not is_instance_valid(dummy) or dummy.story_outcome != "" or not _hooks_near(b,b.map.cell_to_world(DRILL_CELL)):
				_retry_action(b,action_id,"演练骑或钩镰搭档未就绪，重新摆好两名枪手再诱骑。")
				return
			training_lure = actor
			training_lure_entered = true
			training_lure_withdrew = false
			b.mission.mark("lhm_training_lure_entered","汤隆进入演练骑前方，把它引向钩镰打击道")
			dummy.order_move(b.map.cell_to_world(DRILL_CELL))
			b.lit_cells[DRILL_LURE_RETREAT] = 12.0
			b.mission.set_objective("演练骑已经入道。请玩家命汤隆退到西北安全点，再命徐宁攻击；搭档须留在演练骑旁。")
		"lhm_to_battle":
			if stage != "training" or not b.mission.has_event("lhm_drill_complete"): return
			stage = "transition"
			_deploy_battle.call_deferred(b)
		"lhm_west_ambush":
			if stage == "battle" and wave_phase == "rear_redeploy":
				_redeploy_reserve(b,"west",action_id)
				return
			if stage != "prepare": return
			if not _hooks_near(b,b.map.cell_to_world(REED_W)):
				_retry_action(b,action_id,"西伏人手不足，或枪手正被晕眩、缴械。补齐两名可作战的钩镰手后，再点布西伏。")
				return
			b.mission.mark("lhm_west_ready","西侧草林伏兵就位")
			if first_lane == "": first_lane = "west"
			_try_ready(b)
		"lhm_south_ambush":
			if stage == "battle" and wave_phase == "rear_redeploy":
				_redeploy_reserve(b,"south",action_id)
				return
			if stage != "prepare": return
			if not _hooks_near(b,b.map.cell_to_world(REED_S)):
				_retry_action(b,action_id,"南伏人手不足，或枪手正被晕眩、缴械。补齐两名可作战的钩镰手后，再点布南伏。")
				return
			b.mission.mark("lhm_south_ready","南侧芦苇伏兵就位")
			if first_lane == "": first_lane = "south"
			_try_ready(b)
		"lhm_signal":
			if stage != "prepare" or not b.mission.has_event("lhm_west_ready") or not b.mission.has_event("lhm_south_ready"): return
			if not _hooks_near(b,b.map.cell_to_world(REED_W)) or not _hooks_near(b,b.map.cell_to_world(REED_S)):
				_retry_action(b,action_id,"伏兵离位，暂不能发令。西、南两处各补齐两名可作战的钩镰手，再发号诱敌。")
				return
			b.mission.mark("lhm_battle_started","宋江发令，官军连环马分前后两队压来")
			stage = "battle"
			battle_started = true
			free_battle = false
			if first_lane == "": first_lane = "west"
			rear_lane = _other_lane(first_lane)
			wave_phase = "front_lure"
			b.mission.begin("lhm_battle","前队·诱骑入伏","前队尚在道口。让诱敌好汉进入%s路线，再撤到草林侧后；伏兵不得提前暴露。"%_lane_name(first_lane))
			b.mission.add_action("lhm_front_lure","诱敌手：引前队入伏",_lane_entry(first_lane),["lin_chong","hua_rong","tang_long"],1.2)
			_spawn_battle_enemies(b,first_lane,rear_lane)
		"lhm_direct_battle":
			_start_free_battle(b)
		"lhm_front_lure":
			if stage != "battle" or wave_phase != "front_lure": return
			front_lure = actor
			wave_phase = "front_withdraw"
			b.mission.mark("lhm_front_lure_entered","诱敌手进入%s冲锋线，前队开始咬住目标"%_lane_name(first_lane))
			_activate_wave(b,1,first_lane,"luring")
			b.lit_cells[_lane_retreat(first_lane)] = 18.0
			b.mission.set_objective("诱敌手尚在打击道内。请玩家命他撤到%s侧后安全点，伏兵再现身。"%_lane_name(first_lane))
		"lhm_rear_lure":
			if stage != "battle" or wave_phase != "rear_lure" or rear_lane == "": return
			rear_lure = actor
			wave_phase = "rear_withdraw"
			b.mission.mark("lhm_rear_lure_entered","第二名诱敌手进入%s路线，引动后队"%_lane_name(rear_lane))
			_activate_wave(b,2,rear_lane,"luring")
			b.lit_cells[_lane_retreat(rear_lane)] = 18.0
			b.mission.set_objective("后队尚未冲入伏击带。请玩家命诱敌手退到%s侧后，再由预备队合钩。"%_lane_name(rear_lane))

func _clear_section(b) -> void:
	b.clear_campaign_section()
	xu = null
	dummy = null
	training_lure = null
	front_lure = null
	rear_lure = null

func _deploy_battle(b) -> void:
	_clear_section(b)
	stage = "prepare"
	free_battle = false
	team_status_t = 0.0
	riders.clear()
	broken_count = 0
	lhm_killed = 0
	battle_started = false
	hu_fleeing = false
	first_lane = ""
	rear_lane = ""
	wave_phase = ""
	front_broken = 0
	rear_broken = 0
	front_defeated = 0
	rear_defeated = 0
	jiangtai = b.spawn_at("jiangtai",Unit.FACTION_LIANG,JIANGTAI_CELL)
	for spec in [["song_jiang",Vector2i(19,30)],["wu_yong",Vector2i(19,32)],["lin_chong",Vector2i(29,30)],["hua_rong",Vector2i(28,34)],["tang_long",Vector2i(24,34)]]:
		var hero = b.spawn_at(spec[0],Unit.FACTION_LIANG,spec[1])
		hero.passive = true
		hero.order_hold_position()
	if not xu_lost:
		xu = b.spawn_at("xu_ning",Unit.FACTION_LIANG,Vector2i(26,31))
		xu.bonus_vs_cav = DRILL_BONUS if not training_skipped else 0.0
		xu.passive = true
		xu.order_hold_position()
	for i in range(12):
		var c := REED_W + Vector2i(-1+i%3,-2+i/3)
		if i >= 6: c = REED_S + Vector2i(-2+i%3,-2+(i-6)/3)
		var u = b.spawn_at("gou_lian",Unit.FACTION_LIANG,c)
		u.bonus_vs_cav = DRILL_BONUS if not training_skipped else 0.0
		u.set_meta("ambush_lane",REED_W if i<6 else REED_S)
		u.order_hold_position()
		u.passive = true
	b.mission.begin("lhm_prepare","枪法练成·列阵出战","军士晓夜习练，不到半月已学成枪法。西、南两处各布至少两名可作战的钩镰手，检查就位后，由宋江发令诱敌。")
	b.mission.add_action("lhm_west_ambush","钩镰手：布西伏",REED_W,["gou_lian","xu_ning"],3.0)
	b.mission.add_action("lhm_south_ambush","钩镰手：布南伏",REED_S,["gou_lian","xu_ning"],3.0)
	b.mission.add_action("lhm_direct_battle","正面迎战（可混合破阵）",Vector2i(40,34),[],0.6,64.0)
	b.msg("【枪法练成·整军下山】钩镰手已学会藏林伏草、钩蹄拽腿。先布两处伏兵，待甲马深入再一齐动手！",7.0)

func _try_ready(b) -> void:
	if b.mission.has_event("lhm_west_ready") and b.mission.has_event("lhm_south_ready"):
		if _hooks_near(b,b.map.cell_to_world(REED_W)) and _hooks_near(b,b.map.cell_to_world(REED_S)):
			b.mission.add_action("lhm_signal","宋江：发令诱敌",JIANGTAI_CELL+Vector2i(3,0),["song_jiang"],2.0)

func _retry_action(b, action_id: String, reason: String) -> void:
	# The site inspection completed, but its tactical requirement failed. Re-enable only this action.
	if b.mission.actions.has(action_id):
		var action: Dictionary = b.mission.actions[action_id]
		action.done = false
		action.button.disabled = false
		action.marker.show()
	b.mission.set_objective(reason)
	b.msg(reason,4.0)

func _miss_story(b, goal_id: String, reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id,reason)

func _complete_story(b, goal_id: String, note: String) -> void:
	if b.mission.has_method("complete_story_goal"):
		b.mission.complete_story_goal(goal_id,note)

func _effective(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

func _spawn_battle_enemies(b, front_lane_name: String, rear_lane_name: String) -> void:
	_spawn_riders(b,_lane_gate(front_lane_name),_lane_cell(front_lane_name),WAVE_SIZE,1)
	_spawn_riders(b,_lane_gate(rear_lane_name),_lane_cell(rear_lane_name),WAVE_SIZE,2)
	han = b.spawn_at("han_tao",Unit.FACTION_GUAN,_lane_gate(rear_lane_name)+Vector2i(-2,0))
	han.defeat_outcome = "captured"
	han.order_hold_position()
	han.passive = true
	hu = b.spawn_at("hu_yanzhuo",Unit.FACTION_GUAN,_lane_gate(front_lane_name)+Vector2i(-2,-2))
	hu.defeat_outcome = "retreated"
	hu.order_hold_position()
	hu.passive = true

func _start_free_battle(b) -> void:
	if stage != "prepare" or battle_started: return
	free_battle = true
	battle_started = true
	stage = "battle"
	first_lane = "west"
	rear_lane = "south"
	wave_phase = "free_charge"
	b.mission.mark("lhm_free_battle","梁山自行迎击，两路甲马同时压来；可正面强攻，也可引入草林破阵")
	b.mission.begin("lhm_free_battle","自由迎战·正伏皆可","击溃十二骑即可解除官军主阵。未钩破的甲马减伤很高，但正面强攻不会判负。")
	_spawn_battle_enemies(b,first_lane,rear_lane)
	_activate_wave(b,1,first_lane)
	_activate_wave(b,2,rear_lane)
	if is_instance_valid(hu):
		hu.passive = false
		hu.stance = Unit.STANCE_AGGRO
		hu.order_amove(b.map.cell_to_world(JIANGTAI_CELL+Vector2i(5,0)))

func _free_battle_trigger_tick(b) -> void:
	if stage != "prepare" or battle_started or b.mission.active_action_id != "": return
	for actor in b.units_of(Unit.FACTION_LIANG):
		if not is_instance_valid(actor) or actor.hp <= 0.0 or actor.story_outcome != "" or actor.is_building: continue
		if b.map.world_to_cell(actor.position).x >= 40:
			_start_free_battle(b)
			return

func _reopen_action(b, action_id: String) -> void:
	if not b.mission.actions.has(action_id): return
	var action: Dictionary = b.mission.actions[action_id]
	action.done = false
	if is_instance_valid(action.button): action.button.disabled = false
	if is_instance_valid(action.marker): action.marker.show()

func _clear_dummy(b) -> void:
	if is_instance_valid(dummy):
		b.selection.erase(dummy)
		b.units.erase(dummy)
		dummy.queue_free()
	dummy = null

func _lane_cell(lane: String) -> Vector2i:
	return REED_W if lane == "west" else REED_S

func _lane_gate(lane: String) -> Vector2i:
	return GATE_E if lane == "west" else GATE_S

func _lane_entry(lane: String) -> Vector2i:
	return REED_W + Vector2i(10,-1) if lane == "west" else REED_S + Vector2i(8,0)

func _lane_retreat(lane: String) -> Vector2i:
	return REED_W + Vector2i(-5,-6) if lane == "west" else REED_S + Vector2i(-6,-6)

func _other_lane(lane: String) -> String:
	return "south" if lane == "west" else "west"

func _lane_name(lane: String) -> String:
	return "西伏" if lane == "west" else "南伏"

func _training_lure_is_clear(b) -> bool:
	if not is_instance_valid(training_lure) or training_lure.hp <= 0.0 or training_lure.story_outcome != "": return false
	var retreat: Vector2 = b.map.cell_to_world(DRILL_LURE_RETREAT)
	var strike: Vector2 = b.map.cell_to_world(DRILL_CELL)
	return training_lure.position.distance_to(retreat) <= LURE_RETREAT_RADIUS \
		and training_lure.position.distance_to(strike) >= LURE_CLEAR_RADIUS \
		and b.map._segment_open(training_lure.position,retreat,training_lure.movement_profile)

func _lure_is_clear(b, actor, lane: String) -> bool:
	if not is_instance_valid(actor) or actor.hp <= 0.0 or actor.story_outcome != "": return false
	var retreat: Vector2 = b.map.cell_to_world(_lane_retreat(lane))
	var strike: Vector2 = b.map.cell_to_world(_lane_cell(lane))
	return actor.position.distance_to(retreat) <= LURE_RETREAT_RADIUS \
		and actor.position.distance_to(strike) >= LURE_CLEAR_RADIUS \
		and b.map._segment_open(actor.position,retreat,actor.movement_profile)

func _spawn_riders(b, from_cell: Vector2i, target_cell: Vector2i, count: int, wave_group: int) -> void:
	for i in range(count):
		var u = b.spawn_at("lian_huan_ma",Unit.FACTION_GUAN,from_cell+Vector2i(-i/3,(i%3-1)*2))
		u.set_meta("formation_broken",false)
		u.set_meta("ambush_target",target_cell)
		u.set_meta("wave_group",wave_group)
		u.set_meta("wave_state","waiting")
		u.apply_damage_reduction(0.88,9999.0,4704)
		u.stance = Unit.STANCE_PASSIVE
		u.passive = true
		u.order_hold_position()
		riders.append(u)

func _activate_wave(b, wave_group: int, lane: String, state := "charging") -> void:
	for u in riders:
		if not is_instance_valid(u) or u.hp <= 0.0 or int(u.get_meta("wave_group",0)) != wave_group: continue
		u.set_meta("wave_state",state)
		u.stance = Unit.STANCE_AGGRO
		u.passive = false
		u.order_amove(b.map.cell_to_world(_lane_cell(lane)))
	if wave_group == 2 and state == "charging" and is_instance_valid(han) and han.story_outcome == "":
		han.stance = Unit.STANCE_AGGRO
		han.passive = false
		han.order_amove(b.map.cell_to_world(_lane_cell(lane)))

func _wave_may_break(wave_group: int) -> bool:
	if wave_phase == "free_charge": return true
	if wave_group == 1:
		return wave_phase == "front_charge" and is_instance_valid(front_lure)
	return wave_phase == "rear_charge" and rear_lure != null

func _begin_rear_redeploy(b) -> void:
	if b.mission.has_event("lhm_front_wave_broken"): return
	if front_broken < WAVE_SIZE:
		b.mission.mark("lhm_direct_break","前队有人未入钩镰伏击便被正面击溃")
		_miss_story(b,"lhm_hooks","并非十二骑都先由钩镰枪破阵")
	b.mission.mark("lhm_front_wave_broken",
		"前队已经击溃，后队在另一条路上暂缓不进" if front_broken < WAVE_SIZE else "前队六骑已在%s破阵击溃，后队在另一条路上暂缓不进"%_lane_name(first_lane))
	rear_lane = _other_lane(first_lane)
	wave_phase = "rear_redeploy"
	b.mission.begin("lhm_redeploy","后队·调预备伏兵","第一伏已经暴露。把保存下来的钩镰预备队调到%s，至少两人可战，再检查新的伏击位。"%_lane_name(rear_lane))
	b.mission.add_action("lhm_west_ambush","钩镰手：改布西伏",REED_W,["gou_lian","xu_ning"],2.0)
	b.mission.add_action("lhm_south_ambush","钩镰手：改布南伏",REED_S,["gou_lian","xu_ning"],2.0)

func _redeploy_reserve(b, lane: String, action_id: String) -> void:
	if lane != rear_lane:
		_retry_action(b,action_id,"前队已经用过%s，后队不会再走这条明伏。把预备队改调到%s。"%[_lane_name(first_lane),_lane_name(rear_lane)])
		return
	var lane_pos: Vector2 = b.map.cell_to_world(_lane_cell(lane))
	if not _hooks_near(b,lane_pos):
		_retry_action(b,action_id,"%s不足两名可战钩镰手。若原预备队减员，就从另一队调人补位后再检查。"%_lane_name(lane))
		return
	for u in b.units_of(Unit.FACTION_LIANG):
		if u.key in ["gou_lian","xu_ning"] and u.story_outcome == "" and u.position.distance_to(lane_pos) <= HOOK_TEAM_RADIUS:
			u.set_meta("ambush_lane",_lane_cell(lane))
	b.mission.mark("lhm_reserve_redeployed","预备钩镰手转到%s，后队改道压来"%_lane_name(lane))
	wave_phase = "rear_lure"
	b.mission.begin("lhm_rear_lure","后队·换路再诱","后队见第一伏暴露，转走%s。另派诱敌手进入路线，随后撤出打击道。"%_lane_name(lane))
	b.mission.add_action("lhm_rear_lure","诱敌手：引后队入新伏",_lane_entry(lane),["lin_chong","hua_rong","tang_long"],1.2)

func process(b, delta: float) -> void:
	if stage == "transition": return
	_free_battle_trigger_tick(b)
	if stage in ["prepare","battle"]:
		if not is_instance_valid(jiangtai) or jiangtai.hp <= 0.0:
			b.lose("中军被冲毁，诱敌伏击失败。")
			return
	if stage == "training" and (not is_instance_valid(xu) or xu.hp <= 0.0):
		xu_lost = true
		training_skipped = true
		b.mission.mark("lhm_training_skipped","徐宁未能完成授艺，余部直接出战")
		_miss_story(b,"lhm_training","徐宁未能完成钩镰授艺")
		stage = "transition"
		_deploy_battle.call_deferred(b)
		return
	if stage == "training" and training_lure_entered and not training_lure_withdrew and _training_lure_is_clear(b):
		training_lure_withdrew = true
		b.mission.mark("lhm_training_lure_withdrew","汤隆已经撤出木马打击道，演练骑正冲向钩镰搭档")
		b.mission.set_objective("诱敌手已经退开。等演练骑进入木马旁，再由徐宁与钩镰搭档合力下钩。")
	team_status_t -= delta
	if stage in ["prepare","battle"] and team_status_t <= 0.0:
		team_status_t = 1.0
		var west := _hook_count(b,b.map.cell_to_world(REED_W))
		var south := _hook_count(b,b.map.cell_to_world(REED_S))
		if stage == "prepare":
			b.mission.set_objective("西伏可战枪手%d/2，南伏%d/2。每骑近旁须有两人协同；缺人、晕眩或缴械时，调同伴补位。"%[west,south])
			_try_ready(b)
		elif wave_phase == "front_charge":
			b.mission.set_objective("前队已入%s：破阵%d/6，击溃%d/6。诱敌手须留在侧后，枪手两人一组下钩。"%[_lane_name(first_lane),front_broken,front_defeated])
		elif wave_phase == "rear_redeploy":
			b.mission.set_objective("第一伏已经暴露。%s现有可战枪手%d/2；保存或补调两人，再检查新伏击位。"%[_lane_name(rear_lane),_hook_count(b,b.map.cell_to_world(_lane_cell(rear_lane)))])
		elif wave_phase == "rear_charge":
			b.mission.set_objective("后队已改走%s：破阵%d/6，击溃%d/6。仍须两名可战枪手协同。"%[_lane_name(rear_lane),rear_broken,rear_defeated])
	if stage == "battle":
		if wave_phase == "front_withdraw" and _lure_is_clear(b,front_lure,first_lane):
			b.mission.mark("lhm_front_lure_withdrew","诱敌手撤出%s打击道，前队六骑冲入草林"%_lane_name(first_lane))
			wave_phase = "front_charge"
			_activate_wave(b,1,first_lane)
		if wave_phase == "rear_withdraw" and _lure_is_clear(b,rear_lure,rear_lane):
			b.mission.mark("lhm_rear_lure_withdrew","第二名诱敌手撤出%s打击道，后队改道冲入新伏"%_lane_name(rear_lane))
			wave_phase = "rear_charge"
			_activate_wave(b,2,rear_lane)
		for u in riders:
			if not is_instance_valid(u) or u.hp <= 0.0 or bool(u.get_meta("formation_broken",false)): continue
			var wave_group := int(u.get_meta("wave_group",0))
			if not _wave_may_break(wave_group): continue
			var cell: Vector2i = u.get_meta("ambush_target",REED_W)
			if u.position.distance_to(b.map.cell_to_world(cell)) <= 210.0 and _hooks_near(b,u.position):
				u.set_meta("formation_broken",true)
				u.set_meta("wave_state","broken")
				u._damage_reduction_sources.erase(4704)
				u._refresh_damage_reduction()
				u.apply_slow(0.45,18.0)
				broken_count += 1
				if wave_group == 1: front_broken += 1
				else: rear_broken += 1
				if broken_count in [1,7]:
					b.show_story_art("hook_spear_team",u.position-Vector2(22,0),110.0,2.0,"engaged")
					b.show_story_art("broken_cavalry",u.position+Vector2(25,0),100.0,2.0)
				b.mission.mark("lhm_break_%d"%broken_count,"草林伏兵钩倒第%d骑甲马"%broken_count)
		if wave_phase == "front_charge" and front_defeated == WAVE_SIZE:
			_begin_rear_redeploy(b)
		if lhm_killed >= lhm_total and broken_count < lhm_total and not b.mission.has_event("lhm_direct_break"):
			b.mission.mark("lhm_direct_break","有甲马未先钩破连环阵便被正面击溃")
			_miss_story(b,"lhm_hooks","并非十二骑都先在草林中由钩镰枪破阵")
		if lhm_killed >= lhm_total and broken_count == lhm_total and not b.mission.has_event("lhm_all_hook_broken"):
			b.mission.mark("lhm_all_hook_broken","十二骑均先由钩镰枪破开连环甲马")
			_complete_story(b,"lhm_hooks","十二骑均先钩破再击溃")
		if lhm_killed >= lhm_total and not hu_fleeing:
			hu_fleeing = true
			if is_instance_valid(hu) and hu.story_outcome == "":
				hu.resolve_story("retreated")
			if is_instance_valid(hu) and hu.story_outcome == "retreated":
				b.mission.mark("lhm_hu_fled","呼延灼乘御赐踢雪乌骓逃往青州")
				_complete_story(b,"lhm_hu","呼延灼败走青州")
			else:
				_miss_story(b,"lhm_hu","呼延灼没有按原著败走青州")
		if hu_fleeing and not _effective(han):
			if lhm_killed < lhm_total: return
			var han_captured: bool = b.mission.has_event("lhm_han_captured")
			var hu_fled: bool = b.mission.has_event("lhm_hu_fled")
			b.mission.mark("lhm_victory","十二骑连环马与官军主阵均已解除")
			if broken_count == lhm_total and han_captured and hu_fled:
				b.win("荒草芦苇中，钩镰伏兵破了连环甲马，韩滔被擒；呼延灼骑踢雪乌骓败走青州。")
			else:
				b.win("梁山以正面强攻与局部钩镰合战击溃十二骑，官军主阵已经解除。韩滔与呼延灼的具体结局及钩马章法，按本局演义印另行结算。")
			return
	if b._smoke: _smoke_drive(b,delta)

func _hooks_near(b, pos: Vector2) -> bool:
	return _hook_count(b,pos) >= HOOK_TEAM_SIZE

func _hook_count(b, pos: Vector2) -> int:
	var count := 0
	for u in b.units_of(Unit.FACTION_LIANG):
		if u.key not in ["gou_lian","xu_ning"] or u.story_outcome != "" or u.is_captive or u.garrisoned or u.is_noncombat:
			continue
		if u._stun_t > 0.0 or u._disarm_t > 0.0: continue
		if u.position.distance_to(pos) <= HOOK_TEAM_RADIUS and b.map._segment_open(u.position,pos,u.movement_profile):
			count += 1
	return count

func on_unit_died(b, u) -> void:
	if u.key == "lian_huan_ma" and stage == "battle":
		var wave_group := int(u.get_meta("wave_group",0))
		u.set_meta("wave_state","defeated")
		lhm_killed += 1
		if wave_group == 1: front_defeated += 1
		elif wave_group == 2: rear_defeated += 1
		if not bool(u.get_meta("formation_broken",false)):
			b.mission.mark("lhm_direct_break","甲马尚未被钩破连环便遭正面击溃")
			_miss_story(b,"lhm_hooks","有甲马未先进入钩镰打击道")
	elif u.key == "song_jiang":
		b.lose("宋江阵亡，中军失去统领。")
	elif u == xu:
		xu_lost = true
		if not b.mission.has_event("lhm_drill_complete"):
			_miss_story(b,"lhm_training","徐宁未能完成钩镰授艺")
		else:
			b.mission.mark("lhm_xu_lost_after_training","徐宁已经授艺完成，后续减员不抹去教场成果")
	elif u == han:
		_miss_story(b,"lhm_han","韩滔没有以活俘结局退出战斗")
	elif u == hu:
		_miss_story(b,"lhm_hu","呼延灼没有骑御赐马败走青州")

func on_unit_resolved(b, u, outcome: String) -> void:
	if u == dummy and stage == "training":
		var in_lane: bool = u.position.distance_to(b.map.cell_to_world(DRILL_CELL)) <= 210.0
		if not training_lure_withdrew or not in_lane or not _hooks_near(b,u.position):
			training_lure = null
			training_lure_entered = false
			training_lure_withdrew = false
			_retry_action(b,"lhm_partner","演练骑倒得太早，或枪手搭档已经离位。重新摆出演练骑，再完成“引入打击道、诱敌手撤开、两人下钩”。")
			return
		b.mission.mark("lhm_drill_complete","诱敌手撤开后，徐宁与搭档合力钩倒演练骑，教场演练已成")
		b.mission.add_action("lhm_to_battle","徐宁：整军赴战",Vector2i(18,40),["xu_ning"],2.0)
		b.mission.set_objective("此次演练已成。命徐宁回教场集合，继续教习军士，待枪法练熟再下山出战。")
		return
	if u == han and outcome == "captured":
		b.mission.mark("lhm_han_captured","韩滔在乱军中被生擒")
		_complete_story(b,"lhm_han","韩滔被生擒")
	elif u == hu and outcome == "retreated":
		b.mission.mark("lhm_hu_withdrew","呼延灼脱出战阵，往青州奔走")

func top_status(_b) -> String:
	var detail := "前队%d/6 · 后队%d/6"%[front_broken,rear_broken] if stage == "battle" else "破连环 %d/%d"%[broken_count,lhm_total]
	return "大破连环马 | %s | %s · 击溃 %d/%d"%[{"training":"钩镰演练","transition":"枪法练成","prepare":"布置伏兵","battle":"诱骑破阵"}.get(stage,stage),detail,lhm_killed,lhm_total]

func _smoke_drive(b, delta: float) -> void:
	smoke_t -= delta
	if smoke_t > 0.0: return
	smoke_t = 1.5
	if b.mission.active_action_id != "": return
	if stage == "training":
		if not b.mission.has_event("lhm_drill_started"): b.mission.request_action("lhm_drill")
		elif b.mission.has_event("lhm_drill_complete"): b.mission.request_action("lhm_to_battle")
		elif not is_instance_valid(dummy) or dummy.story_outcome != "": b.mission.request_action("lhm_partner")
		elif not training_lure_entered: b.mission.request_action("lhm_training_lure")
		elif not training_lure_withdrew and is_instance_valid(training_lure): training_lure.order_move(b.map.cell_to_world(DRILL_LURE_RETREAT))
		elif training_lure_withdrew: xu.order_attack(dummy)
	elif stage == "prepare":
		if not b.mission.has_event("lhm_west_ready"): b.mission.request_action("lhm_west_ambush")
		elif not b.mission.has_event("lhm_south_ready"): b.mission.request_action("lhm_south_ambush")
		else: b.mission.request_action("lhm_signal")
	elif stage == "battle":
		match wave_phase:
			"front_lure": b.mission.request_action("lhm_front_lure")
			"front_withdraw":
				if is_instance_valid(front_lure): front_lure.order_move(b.map.cell_to_world(_lane_retreat(first_lane)))
			"front_charge": _smoke_fight_wave(b,1,first_lane)
			"rear_redeploy": _smoke_redeploy_reserve(b)
			"rear_lure": b.mission.request_action("lhm_rear_lure")
			"rear_withdraw":
				if is_instance_valid(rear_lure): rear_lure.order_move(b.map.cell_to_world(_lane_retreat(rear_lane)))
			"rear_charge":
				if rear_defeated < WAVE_SIZE: _smoke_fight_wave(b,2,rear_lane)
				else: _smoke_capture_han(b)

func _smoke_fight_wave(b, wave_group: int, lane: String) -> void:
	var live_wave: Array = []
	for rider in riders:
		if is_instance_valid(rider) and rider.hp > 0.0 and rider.story_outcome == "" and int(rider.get_meta("wave_group",0)) == wave_group:
			live_wave.append(rider)
	if live_wave.is_empty(): return
	var all_broken: bool = live_wave.all(func(r): return bool(r.get_meta("formation_broken",false)))
	var lane_cell := _lane_cell(lane)
	var lane_pos: Vector2 = b.map.cell_to_world(lane_cell)
	for u in b.units_of(Unit.FACTION_LIANG):
		if u.is_building or u.key in ["song_jiang","wu_yong"] or u.story_outcome != "" or u.is_captive: continue
		if u.key == "gou_lian" and Vector2i(u.get_meta("ambush_lane",Vector2i(-99,-99))) != lane_cell: continue
		if not all_broken:
			if u == front_lure or u == rear_lure: continue
			if u.key not in ["gou_lian","xu_ning"]: continue
			if u.position.distance_to(lane_pos) > 70.0: u.order_move(lane_pos)
			else: u.order_hold_position()
			continue
		var target: Unit = null
		var dist := INF
		for rider in live_wave:
			var d: float = u.position.distance_to(rider.position)
			if d < dist:
				dist = d
				target = rider
		if target != null: u.order_attack(target,false,true)

func _smoke_redeploy_reserve(b) -> void:
	var lane_pos: Vector2 = b.map.cell_to_world(_lane_cell(rear_lane))
	if _hooks_near(b,lane_pos):
		b.mission.request_action("lhm_west_ambush" if rear_lane == "west" else "lhm_south_ambush")
		return
	var needed := HOOK_TEAM_SIZE - _hook_count(b,lane_pos)
	for u in b.units_of(Unit.FACTION_LIANG):
		if needed <= 0: break
		if u.key not in ["gou_lian","xu_ning"] or u.story_outcome != "" or u.is_captive or u._stun_t > 0.0 or u._disarm_t > 0.0: continue
		if u.position.distance_to(lane_pos) <= HOOK_TEAM_RADIUS: continue
		u.order_move(lane_pos+Vector2(float(needed*28),0.0))
		needed -= 1

func _smoke_capture_han(b) -> void:
	if not is_instance_valid(han) or han.story_outcome != "": return
	for u in b.units_of(Unit.FACTION_LIANG):
		if not u.is_building and u.key not in ["song_jiang","wu_yong"] and u.story_outcome == "" and not u.is_captive:
			u.order_attack(han,false,true)
