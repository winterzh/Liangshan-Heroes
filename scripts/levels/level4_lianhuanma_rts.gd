extends LevelBase
## Persistent counter-cavalry campaign. All twelve linked riders are present at
## deployment; supply posts pay for ordinary escorts, never replace the twelve.
const T := GameMap.T
const CAMP := Vector2i(10,30)
const ENEMY_CAMP := Vector2i(54,30)
const NORTH_POST := Vector2i(44,12)
const SOUTH_POST := Vector2i(44,49)
const LANES := [Vector2i(29,21),Vector2i(30,41)]
const RIDER_POSTS := [Vector2i(52,20),Vector2i(52,42)]
const DRILL := Vector2i(16,45)
const DRILL_ENTRY := Vector2i(21,45)
const SOUTH_SIEGE_BUTTON := "lhm_flank_artillery"
const SOUTH_SIEGE_SELECT := "lhm_select_east_artillery"
const SOUTH_SIEGE_CELLS := [
	Vector2i(22,43), Vector2i(30,57), Vector2i(43,58), Vector2i(55,58),
	Vector2i(60,46), Vector2i(61,40),
]
const LINK_SOURCE := 4705
const HOOK_KEYS := ["gou_lian","xu_ning"]
const HOOK_TEAM_BUTTON := "lhm_select_hook_team"
const WAVE_TIMES := [150.0, 270.0]
const SUPPLY_DELAY := 45.0
const CAMP_FALL_WAVE_EVENTS := ["lhm_north_after_camp_fall", "lhm_south_after_camp_fall"]
const CAMP_FALL_CHARGE := [
	"官军大营已破 · 北路待命甲马正冲向中军！",
	"官军大营已破 · 南路待命甲马正冲向中军！",
]
const LANE_WARNING := [
	"北路甲马正在集结，约25秒后出发。",
	"南路甲马正在集结，约25秒后出发。",
]
const LANE_CHARGE := [
	"北路甲马开始冲锋！枪兵护弓，拒马减速；可出击截断辎重，也可先稳住两条路。",
	"南路甲马开始冲锋！枪兵护弓，拒马减速；可出击截断辎重，也可先稳住两条路。",
]
const LANE_SUPPLY_DELAYED := [
	"北路辎重营已毁：该处停止补军，未出发甲马推迟45秒；已出发部队仍在场",
	"南路辎重营已毁：该处停止补军，未出发甲马推迟45秒；已出发部队仍在场",
]
const LANE_SUPPLY_LOST := [
	"北路辎重营已毁：停止补军，已出击的甲马和在场部队继续作战。",
	"南路辎重营已毁：停止补军，已出击的甲马和在场部队继续作战。",
]
const LANE_SUPPLY_CLEARED := [
	"北路原骑已全歼，辎重营也已毁；本路不再补军。",
	"南路原骑已全歼，辎重营也已毁；本路不再补军。",
]
var hall: Unit
var song: Unit
var xu: Unit
var hu: Unit
var han: Unit
var enemy_base: Unit
var dummy: Unit
var riders: Array[Unit]=[]
var posts: Array[Unit]=[]
var workers: Array[Unit]=[]
var enemy_workers: Array[Unit]=[]
var enemy_nodes: Array[Unit]=[]
var escorts: Array[Unit]=[]
var waves := [{"time":WAVE_TIMES[0],"warned":false,"sent":false},{"time":WAVE_TIMES[1],"warned":false,"sent":false}]
var elapsed := 0.0
var strategy_t := 0.0
var escort_t := 55.0
var _hook_line_start := Vector2.INF
var _hook_line_end := Vector2.INF
var ai_trained := 0
var ai_spent_gold := 0
var ai_spent_wood := 0
var broken_count := 0
var lhm_killed := 0
var manor_fallen := false
var drill_entered := false
var drill_withdrew := false
var drill_coordinated := false
var drill_complete := false
var drill_lure: Unit
var drill_lure_origin := Vector2.ZERO
var phase_title := ""

const PREPARE_BRIEFING := {"title":"扎营 · 准备迎击北路","objective":"训练钩镰手，在北侧芦苇地迎骑。也可派兵先拆辎重营，断掉该路援军。徐宁的教场演练可选。"}
const SOUTH_BRIEFING := {"title":"迎骑 · 准备南路","objective":"北路甲马已击溃。整编钩镰手迎击南路，也可先拆南路辎重营，延迟该路冲锋。"}
const NORTH_AFTER_CUT := "北路辎重已断，尚未出发的骑队推迟45秒。趁这段时间补充钩镰手，在北侧芦苇地布阵。教场演练仍可选。"
const SOUTH_AFTER_CUT := "北路甲马已击溃，南路辎重也已断。南路原骑推迟45秒，趁此把钩镰手调到南侧迎击。"
const DEFEND_BRIEFING := {"title":"迎骑 · 守住中军","objective":"守住中军和宋江。把甲马引进芦苇地或沼泽，让两名钩镰手协同破阵。留兵拦住随骑而来的护军。"}
const COUNTER_BRIEFING := {"title":"反攻 · 攻破官军大营","objective":"十二骑已击溃。集结步军保护攻城器械，攻破大营即可取胜。想生擒韩滔，先击败他再拆大营。"}
const CAPTURED_COUNTER_BRIEFING := {"title":"反攻 · 韩滔已擒","objective":"韩滔已被生擒。护送攻城器械摧毁官军大营。正面难进时，可让步军牵制守军，投石车从侧翼攻营。"}
const FINISH_BRIEFING := {"title":"大营已破 · 击溃余骑","objective":"官军已停止补兵。点「查看 · 余骑」可定位离中军最近的甲马。击溃余骑，守住中军和宋江即可取胜。"}

func id() -> String: return "level4"
func title() -> String: return "大破连环马"
func subtitle() -> String: return "扎营练枪·断粮破骑·反攻主阵"
func economy_enabled() -> bool: return true
func start_gold() -> int: return 300
func start_wood() -> int: return 200
func base_pop_cap() -> int: return 24
func start_age() -> int: return 3
func hero_start_rank() -> int: return 0
func hero_cap() -> int: return 4
func fog_enabled() -> bool: return true
func map_w() -> int: return 64
func map_h() -> int: return 60
func map_theme() -> String: return "plain"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return CAMP
func campaign_core_goal() -> String:
	return "守住梁山中军，击溃十二骑连环马并摧毁官军大营。宋江与中军必须存活。"
func story_contract_version() -> int: return 2
func campaign_story_goals() -> Array:
	return [
		{"id":"lhm_training","label":"教场诱骑撤步，徐宁与钩镰手协同下钩","required_events":["lhm_drill_complete"]},
		{"id":"lhm_hooks","label":"十二骑均先由钩镰枪破阵","required_events":["lhm_all_hook_broken"],"forbidden_events":["lhm_direct_break"]},
		{"id":"lhm_han","label":"生擒韩滔","required_events":["lhm_han_captured"]},
		{"id":"lhm_hu","label":"呼延灼败走青州","required_events":["lhm_hu_fled"]},
	]
func deploy_hint() -> String:
	return "兵营可练钩镰枪手，搭配弓手与拒马迎骑。甲马靠近同伴时有连环护阵；引到草林或减速后，由两名钩镰手近身配合破阵。北、南辎重营付钱补充护军，拆掉可断援并延缓尚未出发的骑队。"
func intro_lines() -> Array:
	return [
		{"who":"旁白","key":"narrator","text":"时迁盗甲、汤隆招师，徐宁已到梁山传授钩镰枪法。原著三千连环甲马在本关缩为十二骑，分屯两路，官军辎重营仍在补充护军。"},
		{"who":"徐宁","key":"xu_ning","text":"枪手须有同伴照应，逼近受阻的马队下钩。可先在南面教场练引骑撤步；也可直接练兵布阵，莫让弓手和工人独自迎马。"},
		{"who":"宋江","key":"song_jiang","text":"先经营中军。北、南草林可伏兵，外侧辎重营可断援；守住冲锋后再反攻，营地和已经打下的战果都留在这里。"},
	]
func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	defs.hall.produces=["lou_luo","song_jiang","xu_ning","lin_chong","hua_rong"]
	defs.barracks.produces=["liang_dao","liang_qiang","liang_gong","liang_ma","gou_lian"]
	# The shared hook soldier had no economic fields; combat stats stay shared.
	var recruitment := {"pop":2,"cost_gold":36,"cost_wood":24,"train_time":20.0,"trained_at":"barracks","min_age":1}
	for field in recruitment: defs.gou_lian[field]=recruitment[field]
	defs["hook_training_dummy"]={"name":"教场演练骑","hp":120,"atk":0,"speed":60,"cavalry":true,"radius":13,"defeat_outcome":"subdued","art_variant":"hook_training_dummy","pop":0}
func paint_map(map: GameMap) -> void:
	map.fill_rect(0,0,64,60,T.GRASS)
	map.fill_rect(24,10,34,42,T.PLAIN)
	for lane in LANES:
		map.fill_ellipse(Vector2(lane),8,7,T.MARSH)
		map.fill_ellipse(Vector2(lane),6,5,T.REEDS)
	map.paint_path([Vector2(CAMP),Vector2(20,28),Vector2(34,29),Vector2(ENEMY_CAMP)],2,T.ROAD)
	map.paint_path([Vector2(13,27),Vector2(25,17),Vector2(36,15),Vector2(NORTH_POST)],1,T.ROAD)
	map.paint_path([Vector2(14,35),Vector2(24,45),Vector2(36,48),Vector2(SOUTH_POST)],1,T.ROAD)
	map.fill_ellipse(Vector2(7,9),7,6,T.FOREST)
	map.fill_ellipse(Vector2(26,53),7,4,T.FOREST)
	map.fill_rect(3,21,16,17,T.GRASS)
	map.fill_rect(12,43,11,6,T.PLAIN)
func decorate(map: GameMap) -> void:
	map.decor=[["banner",CAMP+Vector2i(-2,0),80.0],["banner",ENEMY_CAMP+Vector2i(2,-1),80.0],["forest",Vector2i(25,9),42.0],["rocks",Vector2i(36,31),40.0]]
func alive(u) -> bool: return is_instance_valid(u) and u.hp>0 and u.story_outcome==""
func _guard(b,key: String,cell: Vector2i) -> Unit:
	var u: Unit=b.spawn_at(key,1,cell)
	if u == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return null
	u.set_stance(Unit.STANCE_DEFEND)
	return u
func _resource(b,key: String,cell: Vector2i,amount: float) -> Unit:
	var u: Unit=b.spawn_at(key,0,cell)
	if u == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return null
	u.res_left=amount
	return u
func deploy(b) -> void:
	hall=b.spawn_at("hall",0,CAMP)
	if hall == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	hall.display_name="梁山中军"
	var _created_entity_1: Unit = b.spawn_at("barracks",0,Vector2i(8,36))
	if _created_entity_1 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	song=b.spawn_at("song_jiang",0,Vector2i(14,29))
	if song == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	xu=b.spawn_at("xu_ning",0,Vector2i(15,31))
	if xu == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	for i in range(6):
		var _created_entity_2: Unit = b.spawn_at("lou_luo",0,Vector2i(5+i,25))
		if _created_entity_2 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		workers.append(_created_entity_2)
	for i in range(6):
		var _created_entity_3: Unit = b.spawn_at(["gou_lian","gou_lian","liang_qiang","liang_qiang","liang_gong","liang_gong"][i],0,Vector2i(17+i%3,28+i/3))
		if _created_entity_3 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for cell in [Vector2i(5,20),Vector2i(10,20)]:
		var _created_entity_4: Unit = _resource(b,"gold_mine",cell,2400)
		if _created_entity_4 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for cell in [Vector2i(5,39),Vector2i(8,41),Vector2i(12,40),Vector2i(3,33)]:
		var _created_entity_5: Unit = _resource(b,"tree",cell,1500)
		if _created_entity_5 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for cell in [Vector2i(36,10),Vector2i(38,51)]:
		var _created_entity_6: Unit = _resource(b,"gold_mine",cell,4500)
		if _created_entity_6 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for cell in [Vector2i(33,10),Vector2i(35,52)]:
		var _created_entity_7: Unit = _resource(b,"tree",cell,1800)
		if _created_entity_7 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	enemy_base=b.spawn_at("hall",1,ENEMY_CAMP)
	if enemy_base == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	enemy_base.display_name="官军大营"
	for cell in [NORTH_POST,SOUTH_POST]:
		var post: Unit=b.spawn_at("barracks",1,cell)
		if post == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		post.display_name="北路辎重营" if cell==NORTH_POST else "南路辎重营"
		posts.append(post)
		for i in range(3):
			var _created_entity_8: Unit = _guard(b,"guan_dao" if i<2 else "guan_gong",cell+Vector2i(-3,i*2-2))
			if _created_entity_8 == null:
				b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
				return
	for lane in range(2):
		for i in range(6):
			var u: Unit=_guard(b,"lian_huan_ma",RIDER_POSTS[lane]+Vector2i(i/3,(i%3-1)*2))
			if u == null:
				b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
				return
			u.set_meta("wave_group",lane)
			u.set_meta("formation_broken",false)
			u.set_meta("wave_state","waiting")
			riders.append(u)
	hu=_guard(b,"hu_yanzhuo",Vector2i(51,29))
	if hu == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	hu.defeat_outcome="retreated"
	han=_guard(b,"han_tao",Vector2i(50,33))
	if han == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	han.defeat_outcome="captured"
	for cell in [Vector2i(49,26),Vector2i(49,35)]:
		var _created_entity_9: Unit = _guard(b,"guan_gong",cell)
		if _created_entity_9 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for cell in [Vector2i(58,24),Vector2i(58,37)]:
		var _created_entity_10: Unit = _resource(b,"gold_mine",cell,1800)
		if _created_entity_10 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		enemy_nodes.append(_created_entity_10)
	for i in range(2):
		var _created_entity_11: Unit = b.spawn_at("lou_luo",1,Vector2i(58,27+i*7))
		if _created_entity_11 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		enemy_workers.append(_created_entity_11)
func on_start(b) -> void:
	b.faction_res[1]={"gold":160.0,"wood":240.0}
	for i in range(workers.size()):
		var node=b.nearest_free_gold(workers[i].position,null,workers[i]) if i<3 else b.nearest_resource(workers[i].position,"wood")
		if node!=null: workers[i].order_gather(node)
	for i in range(enemy_workers.size()): enemy_workers[i].order_gather(enemy_nodes[i])
	phase_title = PREPARE_BRIEFING.title
	b.mission.begin("lhm_rts", phase_title, PREPARE_BRIEFING.objective)
	b.mission.add_action("lhm_drill_reset",Localize.text("摆好教场演练骑（可选）"),DRILL+Vector2i(-2,0),["xu_ning"],1,64)
	b.mission.add_actor_locator("lhm_drill_reset","xu_ning")
	b.mission.add_map_locator("北侧芦苇地", LANES[0])
	b.mission.add_map_locator("南侧芦苇地", LANES[1])
	b.mission.add_map_locator("北路辎重营", NORTH_POST)
	b.mission.add_map_locator("南路辎重营", SOUTH_POST)
	b.mission.add_map_locator("官军大营", ENEMY_CAMP)
	for cell in [LANES[0],LANES[1],NORTH_POST,SOUTH_POST]: b.lit_cells[cell]=20.0
	b.msg("首队甲马约150秒后沿北草林进军，后队约270秒走南路。兵营已能训练钩镰手；派军争辎重营可断护军并延迟该路骑队。",10)
func on_mission_action(b,action_id: String,_actor) -> void:
	if action_id!="lhm_drill_reset" or drill_complete:
		return
	var replacement: Unit=b.spawn_at("hook_training_dummy",1,DRILL_ENTRY)
	if replacement == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_REPLACEMENT")
		return
	xu=_actor # A normally re-recruited Xu Ning can still teach after a loss.
	if is_instance_valid(dummy):
		dummy.queue_free()
		b.units.erase(dummy)
	dummy=replacement
	# Reserve the practice target for deliberate commands while other troops fight.
	dummy.set_meta("campaign_no_auto_target", true)
	dummy.passive=true
	dummy.set_stance(Unit.STANCE_PASSIVE)
	drill_lure=null
	drill_entered=false
	drill_withdrew=false
	drill_coordinated=false
	var action: Dictionary=b.mission.actions.lhm_drill_reset
	action.done=false
	action.button.disabled=false
	action.actor_button.disabled=false
	action.marker.show()
	b.mission.set_status("教场：先让一名非钩镰单位靠近演练骑，再退到两名枪手身后；让徐宁与钩镰手近身击倒它。可随时重摆。")
func _drill_tick(b) -> void:
	if not alive(dummy) or drill_complete: return
	if not drill_entered:
		for u in b.units:
			if alive(u) and u.faction==0 and not u.is_building and not u.is_worker and u.key not in HOOK_KEYS and u.position.distance_to(dummy.position)<80:
				drill_lure=u
				drill_lure_origin=u.position
				drill_entered=true
				dummy.order_move(b.map.cell_to_world(DRILL))
				b.msg("演练骑已入道：诱敌手退到教场西侧、枪手身后，徐宁与一名钩镰手再上前合击。",5)
				break
	elif alive(drill_lure) and not drill_withdrew and drill_lure.position.x<float(DRILL.x-1)*32 \
			and drill_lure.position.distance_to(drill_lure_origin)>80 and drill_lure.position.distance_to(dummy.position)>128:
		drill_withdrew=true
		b.msg("诱敌手已经退开，可以协同下钩。",4)
	if drill_withdrew and not drill_coordinated:
		var attackers: Array=_hook_team(b,dummy).filter(func(u): return u._target==dummy and u.position.distance_to(dummy.position)<=u.atk_range+u.radius+dummy.radius+8)
		drill_coordinated=attackers.has(xu) and attackers.any(func(u): return u.key=="gou_lian")
func _hook_team(b,rider) -> Array:
	return b.units.filter(func(u): return alive(u) and u.faction==0 and u.key in HOOK_KEYS and not u.garrisoned and not u.is_captive and u._stun_t<=0 and u._disarm_t<=0 and u.position.distance_to(rider.position)<=96 and b.map._segment_open(u.position,rider.position,u.movement_profile))

## One read-only predicate for both simulation and player feedback. Does not
## issue orders, refresh effects, reveal fog, or add state to a saved battle.
func hook_conditions(b, rider) -> Dictionary:
	if rider not in riders or not alive(rider): return {"valid": false}
	var terrain: int = b.map.t_world(rider.position)
	var impeded: bool = terrain in [T.REEDS,T.MARSH] or rider.temp_speed < 0.8
	var hooks: Array = _hook_team(b, rider)
	var attacking := hooks.any(func(h): return h._target == rider and h.position.distance_to(rider.position) <= h.atk_range + rider.radius + h.radius + 8)
	var broken := bool(rider.get_meta("formation_broken", false))
	return {"valid": true, "broken": broken, "impeded": impeded,
		"partners": hooks.size(), "attacking": attacking,
		"ready": not broken and impeded and hooks.size() >= 2 and attacking}

func _drill_hint(b) -> String:
	if not alive(xu):
		return Localize.text("教场缺徐宁。可在中军重新招募，再摆演练骑。")
	if not drill_entered:
		return Localize.text("教场第一步：派一名非钩镰战斗单位靠近演练骑。")
	if not drill_withdrew:
		if not alive(drill_lure):
			return Localize.text("诱敌手已倒下。让徐宁重摆演练骑，再派人引骑。")
		return Localize.format_text("引骑已成。让%s退到教场西侧，拉开距离。",drill_lure.display_name)
	var team := _hook_team(b,dummy)
	if xu not in team or not team.any(func(u): return u.key == "gou_lian"):
		return Localize.text("诱敌手已退。让徐宁和一名钩镰手都靠近演练骑。")
	if drill_coordinated:
		return Localize.text("合击已成立。保持两人近身，直到演练骑被制服。")
	return Localize.text("两名搭档已到。选中徐宁与钩镰手，轻点演练骑合击。" if b.hud.touch_ui \
		else "两名搭档已到。选中徐宁与钩镰手，右键演练骑合击。")

func _hook_line_actor(unit) -> bool:
	return alive(unit) and unit.faction == Unit.FACTION_LIANG and unit.key == "gou_lian" \
		and not unit.garrisoned and not unit.is_captive


func _line_hooks(b) -> Array:
	return b.selection.filter(_hook_line_actor)


func _available_hook_line_team(b) -> Array:
	if OS.get_name() != "Windows" or b.hud.touch_ui or lhm_killed >= 12:
		return []
	return b.units.filter(_hook_line_actor)


func _update_hook_team_button(b) -> void:
	var button: Button = b.mission.find_level_button(HOOK_TEAM_BUTTON)
	var available := _available_hook_line_team(b).size() >= 2
	if available and button == null:
		button = b.mission.add_level_button(HOOK_TEAM_BUTTON, "选中 · 钩镰队",
			"按 Alt 拖动右键，在地面划出钩镰阵线。")
		button.get_parent().move_child(button, 0)
		b.mission.reveal_primary_level_button()
	elif not available and button != null:
		button.get_parent().remove_child(button)
		button.queue_free()


func begin_hook_line(b, point: Vector2) -> bool:
	if OS.get_name() != "Windows" or _line_hooks(b).size() < 2:
		return false
	_hook_line_start = point
	_hook_line_end = point
	return true


func cancel_hook_line() -> void:
	_hook_line_start = Vector2.INF
	_hook_line_end = Vector2.INF


func continue_hook_line(b, event: InputEvent) -> bool:
	if _hook_line_start == Vector2.INF:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_hook_line()
		return true
	if event is InputEventMouseMotion:
		_hook_line_end = b.get_canvas_transform().affine_inverse() * event.position
		return true
	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or event.pressed:
		return false
	var mouse: Vector2 = event.position
	var world: Vector2 = b.get_canvas_transform().affine_inverse() * mouse
	var from: Vector2 = b.to_logic(_hook_line_start)
	cancel_hook_line()
	if mouse.y < b.get_viewport_rect().size.y - RTSCamera.PANEL_H:
		_order_hook_line(b, from, b.to_logic(world))
	return true


func draw_tactical_overlay(_b, overlay: Node2D) -> void:
	if _hook_line_start != Vector2.INF:
		overlay.draw_line(_hook_line_start, _hook_line_end, Color(0.98, 0.78, 0.32, 0.9), 3.0, true)


func _order_hook_line(b, from: Vector2, to: Vector2) -> void:
	var hooks := _line_hooks(b)
	if hooks.size() < 2 or from.distance_to(to) < 26.0:
		return
	var spacing := 26.0
	for hook: Unit in hooks:
		spacing = maxf(spacing, hook.radius * 2.0 + 4.0)
	var samples := clampi(ceili(from.distance_to(to) / 10.0), 2, 300)
	var valid: Array[Vector2] = []
	for index in range(samples + 1):
		var point := from.lerp(to, float(index) / samples)
		if b.map.is_open_world(point, "land") and (valid.is_empty() or point.distance_to(valid.back()) >= spacing):
			valid.append(point)
	var count := mini(valid.size(), hooks.size())
	if count < 2:
		b.msg("沿可通行地面拖长一点，至少为两名钩镰手留出位置。", 3.0)
		return
	var axis := (to - from).normalized()
	hooks.sort_custom(func(a, c):
		var pa: float = a.position.dot(axis)
		var pc: float = c.position.dot(axis)
		return a.entity_id < c.entity_id if is_equal_approx(pa, pc) else pa < pc)
	var assigned := hooks.slice(0, count)
	b._stamp_manual(assigned)
	for index in range(count):
		var soldier: Unit = assigned[index]
		soldier.set_stance(Unit.STANCE_DEFEND)
		var slot := roundi(float(index) * (valid.size() - 1) / (count - 1))
		soldier.order_move(valid[slot])
	b.msg(Localize.format_text("钩镰布阵 · %d/%d 人前往站位", [count, hooks.size()]), 3.0)

func unit_tactical_hint(b, unit) -> String:
	if not alive(unit): return ""
	if alive(dummy) and not drill_complete and (unit == dummy \
			or (unit == drill_lure and not drill_withdrew) or (unit.key in HOOK_KEYS and unit._target == dummy)):
		return _drill_hint(b) if b.is_visible_world(dummy.position) else Localize.text("暂无视野，无法判断破阵条件")
	if unit == han and lhm_killed >= 12 and b.is_visible_world(unit.position):
		return Localize.text("可选演义 · 集火击败韩滔即可生擒")
	if unit == enemy_base and b.is_visible_world(unit.position):
		for lane in range(waves.size()):
			if not waves[lane].sent and _lane_has_riders(lane):
				return Localize.text("若先攻破大营，待命甲马会立刻冲向中军。记得留兵守营。")
	var lane := posts.find(unit)
	if lane >= 0:
		if not b.is_visible_world(unit.position): return ""
		if not waves[lane].sent and _lane_has_riders(lane):
			return Localize.text("摧毁辎重营会停止本路补军，让尚未出击的甲马推迟45秒。")
		return Localize.text("摧毁辎重营会停止本路补军；已在场的部队仍会作战。")
	if unit in escorts:
		if not b.is_visible_world(unit.position): return Localize.text("暂无视野，无法判断破阵条件")
		var plan := _escort_plan(b,int(unit.get_meta("source_lane",-1)))
		return Localize.text({"muster":"护军候骑集结 · 可先袭辎重营断援","follow":"护军伴随甲马 · 可引开快骑、截住步军","retreat":"本路甲马已失 · 护军退守，可趁机整队"}.get(plan.get("phase",""),""))
	var rider = unit
	if unit.key in HOOK_KEYS and unit.faction == Unit.FACTION_LIANG:
		if unit._target in riders and alive(unit._target) and b.is_visible_world(unit._target.position):
			rider = unit._target
		else:
			if OS.get_name() == "Windows" and unit.key == "gou_lian" and not b.hud.touch_ui:
				return Localize.text("选两名以上钩镰手，按 Alt 拖动右键布阵。遇受阻甲马，右键集火破阵。")
			return Localize.text("钩镰配合：两人贴近受阻甲马\n轻点攻击；徐宁可充当搭档" if b.hud.touch_ui \
				else "钩镰配合：两人贴近受阻甲马\n右键攻击；徐宁可充当搭档")
	elif unit not in riders:
		return ""
	if not b.is_visible_world(rider.position):
		return Localize.text("暂无视野，无法判断破阵条件")
	var state := hook_conditions(b, rider)
	if not state.valid: return ""
	if state.broken:
		return Localize.text("连环阵已破 · 可集火击溃")
	# Show the actual link effect, including its remaining duration, rather
	# than inferring protection from an unseen neighboring rider.
	var link: Dictionary = rider._damage_reduction_sources.get(LINK_SOURCE, {})
	var protection := float(link.get("amount", 0.0)) if float(link.get("t", 0.0)) > 0.0 else 0.0
	var guard := Localize.format_text("连环护阵%d%%", roundi(protection * 100.0))
	var instruction := "下钩条件已齐"
	if not state.impeded:
		instruction = "先引入芦苇、沼泽，或使其显著减速"
	elif state.partners < 2:
		instruction = "调两名钩镰单位近身配合"
	elif not state.attacking:
		instruction = "搭档已到，轻点攻击此骑" if b.hud.touch_ui else "搭档已到，右键攻击此骑"
	return Localize.format_text("%s · 钩镰%d/2", [guard, mini(2, state.partners)]) + "\n" + Localize.text(instruction)

func _rider_tick(b) -> void:
	for u in riders:
		if not alive(u) or bool(u.get_meta("formation_broken",false)): continue
		var neighbors: int=riders.filter(func(other): return other!=u and alive(other) and not bool(other.get_meta("formation_broken",false)) and other.position.distance_to(u.position)<150).size()
		if neighbors>0: u.apply_damage_reduction(0.5,1.25,LINK_SOURCE)
		else: u._damage_reduction_sources.erase(LINK_SOURCE); u._refresh_damage_reduction()
		if hook_conditions(b, u).ready:
			u.set_meta("formation_broken",true)
			u.set_meta("wave_state","broken")
			u._damage_reduction_sources.erase(LINK_SOURCE)
			u._refresh_damage_reduction()
			u.apply_slow(0.45,4)
			broken_count+=1
			b.show_story_art("broken_cavalry",u.position,72,1.5)
			b.mission.mark("lhm_break_%d"%broken_count,Localize.format_text("钩镰协同破开第%d骑连环阵", broken_count))
	if broken_count==12: b.mission.mark("lhm_all_hook_broken","十二骑均被钩镰枪协同破阵")
func _send_wave(b, lane: int, camp_fell := false) -> void:
	waves[lane].sent=true
	for u in riders:
		if alive(u) and int(u.get_meta("wave_group"))==lane:
			u.set_meta("wave_state","charging")
			u.order_amove(b.map.cell_to_world(LANES[lane]))
			u.order_amove(hall.position,true)
	if camp_fell:
		b.mission.mark(CAMP_FALL_WAVE_EVENTS[lane], CAMP_FALL_CHARGE[lane])
	else:
		b.msg(LANE_CHARGE[lane],7)

func _lane_has_riders(lane: int) -> bool:
	return riders.any(func(u): return alive(u) and int(u.get_meta("wave_group",-1))==lane)

func activate_mission_button(b,button_id: String) -> void:
	if button_id == HOOK_TEAM_BUTTON:
		var team := _available_hook_line_team(b)
		if team.size() >= 2:
			b.select_members(team, false)
		return
	if button_id == SOUTH_SIEGE_SELECT:
		if _south_siege_available():
			_select_east_artillery(b)
		return
	if button_id == SOUTH_SIEGE_BUTTON:
		if _south_siege_available():
			_order_south_siege(b)
		return
	if button_id!="lhm_locate_remaining" or not manor_fallen or not alive(hall): return
	var closest: Unit
	var best_distance := INF
	for rider in riders:
		if not alive(rider): continue
		var distance: float = rider.position.distance_squared_to(hall.position)
		if distance < best_distance:
			closest = rider
			best_distance = distance
	if closest == null:
		b.mission.set_feedback("余骑已全部击溃。")
		return
	b.center_camera_cell(b.map.world_to_cell(closest.position))
	b.mission.set_feedback("已定位北路余骑。请选中部队下令追击。" if int(closest.get_meta("wave_group"))==0
		else "已定位南路余骑。请选中部队下令追击。")

func _south_siege_available() -> bool:
	return OS.has_feature("pc") and lhm_killed >= 12 and not manor_fallen and alive(enemy_base)


func _update_south_siege_button(b, available: bool) -> void:
	var button: Button = b.mission.find_level_button(SOUTH_SIEGE_BUTTON)
	if available and button == null:
		button = b.mission.add_level_button(SOUTH_SIEGE_BUTTON, "投石车绕南侧",
			"派选中的投石车从南侧绕到敌营东边，未选投石车时派空闲的。到位后自行下令攻营。")
		button.get_parent().move_child(button, 0)
		b.mission.reveal_primary_level_button()
	elif not available and button != null:
		button.get_parent().remove_child(button)
		button.queue_free()


func _update_east_artillery_button(b, arrived: bool) -> void:
	var button: Button = b.mission.find_level_button(SOUTH_SIEGE_SELECT)
	if arrived and button == null:
		button = b.mission.add_level_button(SOUTH_SIEGE_SELECT, "选中 · 东侧投石车",
			"选中已到敌营东侧的投石车并移动镜头。右键可见的官军大营下令攻击。")
		button.get_parent().move_child(button, 0)
		b.mission.reveal_primary_level_button()
	elif not arrived and button != null:
		button.get_parent().remove_child(button)
		button.queue_free()


func _at_east_staging_point(unit, staging: Vector2) -> bool:
	return _south_siege_actor(unit) and unit.position.distance_squared_to(staging) <= 32.0 * 32.0


func _select_east_artillery(b) -> void:
	var staging: Vector2 = b.map.cell_to_world(SOUTH_SIEGE_CELLS[-1])
	var arrived: Array = b.units.filter(_at_east_staging_point.bind(staging))
	if arrived.is_empty():
		return
	b.select_members(arrived, false)
	b.center_camera_cell(SOUTH_SIEGE_CELLS[-1])


func _south_siege_actor(unit) -> bool:
	return alive(unit) and unit.faction == 0 and unit.key == "siege_cata" and not unit.garrisoned and not unit.is_captive


func _south_siege_route(map: GameMap, unit: Unit) -> Array[Vector2]:
	# Spread nearby catapults within each shared navigation cell.
	var offset := Vector2.ONE * float(unit.entity_id % 3 - 1) * 9.0
	var route: Array[Vector2] = []
	for cell: Vector2i in SOUTH_SIEGE_CELLS:
		route.append(map.cell_to_world(cell) + offset)
	return route


func _south_siege_entry(cell: Vector2i) -> int:
	# A catapult already along the south or east edge can rejoin farther ahead.
	if cell.y >= 55:
		if cell.x >= 53: return 4
		if cell.x >= 40: return 3
		if cell.x >= 28: return 2
	if cell.x >= 58:
		return 5
	return 0


func _following_south_siege(unit: Unit, route: Array[Vector2], entry: int) -> bool:
	if unit._state != Unit.ST_MOVE: return false
	var current := route.size() - 1 - unit._queue.size()
	if current < 0 or not route[current].is_equal_approx(unit._home): return false
	# A direct move to the destination from the west is not the flank.
	if unit._queue.is_empty(): return entry == route.size() - 1
	for i in range(unit._queue.size()):
		var order: Dictionary = unit._queue[i]
		if order.get("kind") != "move" or order.get("pos") != route[current + i + 1]:
			return false
	return true


func _marching_south_siege(unit: Unit, map: GameMap) -> bool:
	if not _south_siege_actor(unit) or unit._state != Unit.ST_MOVE:
		return false
	var entry := _south_siege_entry(map.world_to_cell(unit.position))
	return _following_south_siege(unit, _south_siege_route(map, unit), entry)


func _south_siege_path_open(map: GameMap, unit: Unit, route: Array[Vector2], entry: int) -> bool:
	var from := unit.position
	for i in range(entry, route.size()):
		var path := map.find_path(from, route[i], unit.faction, unit.movement_profile)
		if path.is_empty() or not path[-1].is_equal_approx(route[i]): return false
		from = route[i]
	return true


func _order_south_siege(b) -> void:
	var actors: Array = b.selection.filter(_south_siege_actor)
	var selected := not actors.is_empty()
	if not selected:
		actors = b.units.filter(_south_siege_actor)
	var dispatched := 0
	var already := 0
	var blocked := 0
	for unit: Unit in actors:
		var route := _south_siege_route(b.map, unit)
		var entry := _south_siege_entry(b.map.world_to_cell(unit.position))
		if _following_south_siege(unit, route, entry) or unit.position.distance_to(route[-1]) <= 24.0:
			already += 1
			continue
		if not selected and (unit._state != Unit.ST_IDLE or unit._hold_order_active or unit._patrolling \
			or unit._target != null or not unit._queue.is_empty() or unit._action_queue_busy() \
			or unit.mission_order_active or unit.mission_order_arrival_t > 0.0):
			continue
		if not _south_siege_path_open(b.map, unit, route, entry):
			blocked += 1
			continue
		b._stamp_manual([unit])
		unit.order_move(route[entry])
		for i in range(entry + 1, route.size()):
			unit.order_move(route[i], true)
		dispatched += 1
	if blocked > 0:
		b.mission.set_feedback("部分投石车暂时无法绕行，请清开道路或手动改道。" if dispatched + already > 0
			else "投石车暂时无法绕行，请清开道路或手动改道。")
	elif dispatched > 0:
		b.mission.set_feedback("投石车已从南侧出发。到位后请下令攻营。")
	elif already > 0:
		b.mission.set_feedback("投石车已在绕行或抵达敌营东侧。")
	else:
		b.mission.set_feedback("请选中投石车，或等投石车空闲后再下令。")


func _support_tick(b,delta: float) -> void:
	if not alive(enemy_base):
		return
	escort_t-=delta
	if escort_t>0:
		return
	escort_t=28
	escorts=escorts.filter(func(u): return alive(u))
	if escorts.size()>=12:
		return
	for lane in range(2):
		if escorts.size()>=12:
			break
		if not alive(posts[lane]):
			continue
		var key: String="guan_gong" if ai_trained%3==2 else "guan_dao"
		var cost: Dictionary=b._defs.liang_gong if key=="guan_gong" else b._defs.liang_dao
		if not b.faction_spend(1,int(cost.cost_gold),int(cost.cost_wood)):
			continue
		var u: Unit=_guard(b,key,(NORTH_POST if lane==0 else SOUTH_POST)+Vector2i(-3,0))
		if u == null:
			b.add_resources(int(cost.cost_gold),int(cost.cost_wood),1)
			return
		u.set_meta("source_lane",lane)
		escorts.append(u)
		ai_trained+=1
		ai_spent_gold+=int(cost.cost_gold)
		ai_spent_wood+=int(cost.cost_wood)
## Derived from already saved wave state, original rider identities and each
## escort's source_lane. Only ordinary Unit orders persist; no hidden AI timer.
func _escort_plan(b,lane: int) -> Dictionary:
	if lane not in [0,1]: return {}
	var cavalry: Array=riders.filter(func(u): return alive(u) and int(u.get_meta("wave_group",-1))==lane)
	if cavalry.is_empty():
		var home: Vector2i=ENEMY_CAMP+Vector2i(-4,-4 if lane==0 else 4)
		if not alive(enemy_base): home=(NORTH_POST if lane==0 else SOUTH_POST) if alive(posts[lane]) else LANES[lane]
		return {"phase":"retreat","goal":b.map.cell_to_world(home)}
	if not waves[lane].sent:
		return {"phase":"muster","goal":b.map.cell_to_world(RIDER_POSTS[lane]+Vector2i(2,3 if lane==0 else -3))}
	var center := Vector2.ZERO
	for rider in cavalry: center+=rider.position
	# Infantry approaches behind its own cavalry, without reading enemy positions.
	return {"phase":"follow","goal":center/float(cavalry.size())+Vector2(96,0)}

func _escort_orders(b) -> void:
	for lane in range(2):
		var plan := _escort_plan(b,lane)
		var goal: Vector2=plan.goal
		for u in escorts:
			if not alive(u) or int(u.get_meta("source_lane",-1))!=lane or u.garrisoned or u.is_captive: continue
			if u._taunt_t>0: continue # Forced targeting belongs to Unit, even during retreat.
			var retreat: bool=plan.phase=="retreat"
			# Nearby visible fighting takes precedence over following a moving center.
			# Retreat deliberately disengages, using movement rather than teleporting.
			var sight: float=float(u.setup_def.get("sight",8))*GameMap.CELL
			if (not retreat or u.position.distance_to(goal)<=160) and alive(u._target) and u._target.faction!=u.faction \
					and u.position.distance_to(u._target.position)<=sight and b.target_visible_to(u,u._target): continue
			if u.position.distance_to(goal)<=80:
				if u._state!=Unit.ST_IDLE or u._target!=null: u.order_stop()
				u._amove_dest=Vector2.ZERO # Retire the old attack-move watchdog at the guard point.
				u._idle_push_t=0.0
				if u.stance!=Unit.STANCE_DEFEND: u.set_stance(Unit.STANCE_DEFEND)
				continue
			if retreat:
				if u._state!=Unit.ST_MOVE or u._home.distance_to(goal)>96: u.order_move(goal)
			elif u._state!=Unit.ST_AMOVE or u._amove_dest.distance_to(goal)>96:
				u.order_amove(goal)

func process(b,delta: float) -> void:
	if not alive(hall) or not alive(song):
		return
	elapsed+=delta
	_support_tick(b,delta)
	if not b._gameplay_rng_issue.is_empty(): return
	strategy_t-=delta
	if strategy_t>0:
		return
	strategy_t=0.25
	_drill_tick(b)
	_rider_tick(b)
	for lane in range(2):
		if waves[lane].sent or not _lane_has_riders(lane):
			continue
		if manor_fallen:
			# Only the surviving riders that have not already charged react to
			# the fall of headquarters. Their original route and units remain.
			_send_wave(b, lane, true)
			continue
		if elapsed>=float(waves[lane].time)-25 and not waves[lane].warned:
			waves[lane].warned=true
			b.lit_cells[RIDER_POSTS[lane]]=30.0
			b.msg(LANE_WARNING[lane],6)
		if elapsed>=float(waves[lane].time):
			_send_wave(b,lane)
	_escort_orders(b)
	_update_briefing(b)
	if manor_fallen:
		for u in riders:
			if alive(u):
				b.lit_cells[b.map.world_to_cell(u.position)]=2.0
	if manor_fallen and lhm_killed>=12:
		if alive(hu):
			hu.resolve_story("retreated")
		b.mission.mark("lhm_victory","十二骑连环马与官军大营均已解除，中军守住")
		b.win("官军大营已破，十二骑连环马尽数击溃；梁山中军守住。呼延灼败走青州。")
func _update_briefing(b) -> void:
	var briefing: Dictionary = PREPARE_BRIEFING
	if manor_fallen:
		briefing = FINISH_BRIEFING
	elif lhm_killed >= 12:
		briefing = CAPTURED_COUNTER_BRIEFING if b.mission.has_event("lhm_han_captured") else COUNTER_BRIEFING
	elif not waves[1].sent and not _lane_has_riders(0):
		briefing = SOUTH_BRIEFING
	elif waves[0].sent or waves[1].sent:
		briefing = DEFEND_BRIEFING
	var objective: String = briefing.objective
	_update_hook_team_button(b)
	var south_siege_available := _south_siege_available()
	_update_south_siege_button(b, south_siege_available)
	var staging: Vector2 = b.map.cell_to_world(SOUTH_SIEGE_CELLS[-1])
	var arrived: bool = south_siege_available and b.units.any(_at_east_staging_point.bind(staging))
	_update_east_artillery_button(b, arrived)
	if arrived:
		objective = "投石车已到敌营东侧。选中东侧投石车，右键可见的官军大营攻城。" if briefing == CAPTURED_COUNTER_BRIEFING \
			else "投石车已到敌营东侧。想生擒韩滔，先击败他，再选中投石车攻营。"
	elif south_siege_available and b.units.any(_marching_south_siege.bind(b.map)):
		objective = "投石车正在绕南侧。用步军牵制守军，投石车到东侧后再下令攻营。" if briefing == CAPTURED_COUNTER_BRIEFING \
			else "投石车正在绕南侧。想生擒韩滔，先击败他，再下令攻营。"
	elif south_siege_available:
		objective = "韩滔已被生擒。可让投石车绕南侧，步军在正面牵制。投石车到位后，请下令攻营。" if briefing == CAPTURED_COUNTER_BRIEFING \
			else "十二骑已击溃。可让投石车绕南侧，到位后下令攻营。想生擒韩滔，先击败他再拆大营。"
	elif briefing == FINISH_BRIEFING and CAMP_FALL_WAVE_EVENTS.any(b.mission.has_event):
		objective = "待命甲马因大营被毁已向中军出击。守住中军和宋江，击溃余骑。点「查看 · 余骑」可定位最近的一骑。"
	elif briefing == PREPARE_BRIEFING and b.mission.has_event("lhm_supply_0"):
		objective = NORTH_AFTER_CUT
	elif briefing == SOUTH_BRIEFING and b.mission.has_event("lhm_supply_1"):
		objective = SOUTH_AFTER_CUT
	if phase_title != briefing.title:
		phase_title = briefing.title
		b.mission.set_title(phase_title)
	if b.mission.objective != objective:
		b.mission.set_objective(objective)

func on_unit_died(b,u) -> void:
	if u==hall or u==song:
		b.lose(Localize.format_text("%s失守。可重开本局，先补枪兵、拒马与人口，再安排两路防守。", u.display_name))
	elif u in riders:
		lhm_killed+=1
		if not bool(u.get_meta("formation_broken",false)): b.mission.mark("lhm_direct_break","部分甲马由正面兵力击溃，未先协同钩破阵")
	elif u==enemy_base:
		manor_fallen=true
		b.mission.mark("lhm_manor_fallen","官军大营已毁，护军停止补充；残余甲马位置已标明")
		if riders.any(alive):
			b.mission.add_level_button("lhm_locate_remaining","查看 · 余骑","移镜头到离中军最近的剩余甲马。")
	elif u==xu and not drill_complete:
		b.msg("徐宁阵亡，教场暂缺教头；可在中军重新招募后继续演练，现有钩镰兵仍可作战。",7)
	elif u in posts:
		var lane: int=posts.find(u)
		var notice: String = LANE_SUPPLY_CLEARED[lane]
		if _lane_has_riders(lane):
			if waves[lane].sent:
				notice = LANE_SUPPLY_LOST[lane]
			else:
				waves[lane].time += SUPPLY_DELAY
				waves[lane].warned = false
				notice = LANE_SUPPLY_DELAYED[lane]
		b.mission.mark("lhm_supply_%d" % lane, notice)
func on_unit_resolved(b,u,outcome: String) -> void:
	if u==han and outcome=="captured": b.mission.mark("lhm_han_captured","韩滔被生擒，仍按敌将看押")
	elif u==hu and outcome=="retreated": b.mission.mark("lhm_hu_fled","呼延灼骑踢雪乌骓败走青州")
	elif u==dummy:
		if drill_entered and drill_withdrew and drill_coordinated and _hook_team(b,u).size()>=2 and alive(xu) and xu.position.distance_to(u.position)<=96:
			drill_complete=true
			b.mission.mark("lhm_drill_complete","徐宁与钩镰手在诱骑撤步后共同下钩，教场演练完成")
			var action: Dictionary=b.mission.actions.lhm_drill_reset
			action.done=true
			action.button.disabled=true
			action.actor_button.disabled=true
			action.marker.hide()
		else: b.msg("演练骑倒得过早或搭档不齐；可重新摆骑，再试诱入、退开、两人下钩。",6)
func _remaining_by_lane() -> Array[int]:
	var remaining: Array[int] = [0, 0]
	for rider in riders:
		if not alive(rider): continue
		var lane := int(rider.get_meta("wave_group", -1))
		if lane >= 0 and lane < remaining.size():
			remaining[lane] += 1
	return remaining

func campaign_debrief(mission) -> Array[Dictionary]:
	var remaining := _remaining_by_lane()
	var rows: Array[Dictionary] = []
	for lane in range(waves.size()):
		var args: Array = ["北路" if lane == 0 else "南路", remaining[lane], "已出击" if waves[lane].sent else "未出击"]
		var source := "%s · 余 %d 骑 · %s · 辎重营仍在"
		var supply_cut: bool = mission.has_event("lhm_supply_%d" % lane)
		if mission.has_event(CAMP_FALL_WAVE_EVENTS[lane]):
			source = "%s · 余 %d 骑 · 大营被毁后出击 · 辎重营已毁" if supply_cut \
				else "%s · 余 %d 骑 · 大营被毁后出击 · 辎重营仍在"
			args.resize(2)
		elif supply_cut:
			var delay := roundi(float(waves[lane].time) - WAVE_TIMES[lane])
			if not waves[lane].sent and remaining[lane] == 0:
				source = "%s · 原骑未出击即被歼灭 · 辎重营已毁"
				args.resize(1)
			elif delay > 0:
				source = "%s · 余 %d 骑 · %s · 断援使冲锋推迟 %d 秒"
				args.append(delay)
			else:
				source = "%s · 余 %d 骑 · %s · 出击后断援"
		rows.append({"source": source, "args": args})
	rows.append({"source": "协同钩破 %d/12 · %s", "args": [broken_count,
		"韩滔已被生擒" if mission.has_event("lhm_han_captured") else "未擒获韩滔"]})
	return rows

func top_status(_b) -> String:
	var remaining := _remaining_by_lane()
	var wave_text: Array[String] = []
	for lane in range(2):
		var direction := Localize.text("北" if lane == 0 else "南")
		var status := Localize.format_text("余%d骑", remaining[lane]) if manor_fallen or waves[lane].sent or remaining[lane]==0 \
			else Localize.format_text("%d秒", maxi(0, ceili(float(waves[lane].time) - elapsed)))
		wave_text.append(direction + " " + status)
	return Localize.format_text("%s\n击溃%d · 钩破%d · 辎重%d/2", [" / ".join(wave_text), lhm_killed, broken_count, posts.filter(func(u): return alive(u)).size()])
