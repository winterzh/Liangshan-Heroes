extends LevelBase
## 江州劫法场：分路混入、李逵先动手、解救二人、白龙庙相遇水军、活着登船。
const T := GameMap.T
const SCAFFOLD := Vector2i(30, 18)
const PLAZA_C := Vector2i(30, 24)
const GATE_N := Vector2i(30, 4)
const GATE_E := Vector2i(54, 24)
const SPAWN_W := Vector2i(8, 30)
const SPAWN_S := Vector2i(24, 40)
const DOCK_C := Vector2i(10, 50)
const BAILONG := Vector2i(14, 43)
const YAMEN := Vector2i(30, 8)
const EXEC_TIME := 120.0
const RESCUE_R := 62.0
const BAILONG_R := 150.0
const DOCK_R := 125.0
const RESCUERS := ["chao_gai", "li_kui", "hua_rong", "yan_shun"]
const START_ARMY := [
	["chao_gai", Vector2i(8, 30)], ["li_kui", Vector2i(9, 31)],
	["hua_rong", Vector2i(7, 29)], ["yan_shun", Vector2i(24, 40)],
	["liang_dao", Vector2i(9, 29)], ["liang_dao", Vector2i(10, 30)],
	["liang_dao", Vector2i(10, 31)], ["liang_gong", Vector2i(7, 31)],
	["liang_dao", Vector2i(25, 40)], ["liang_dao", Vector2i(23, 41)],
	["liang_gong", Vector2i(24, 41)], ["liang_gong", Vector2i(25, 41)],
]
enum { APPROACH, BREAK_EXEC, RESCUE, RETREAT, EMBARK }
var st := APPROACH
var scaffold: Unit
var song_bound: Unit
var dai_bound: Unit
var song_freed: Unit
var dai_freed: Unit
var chao: Unit
var cai: Unit
var rescuing_army: Array = []
var exec_timer := EXEC_TIME
var rescued_song := false
var rescued_dai := false
var wave1_done := false
var wave2_done := false
var wave3_done := false
var at_dock_started := false
var smoke_phase := 0
var smoke_t := 0.0
var escape_route := ""
var route_changed := false
var rear_guard: Unit
var rear_guard_recalled := false
var recall_action_added := false
var route_pressure: Array = []
var pursuit_timer := -1.0
var pursuit_wave_done := false

func id() -> String: return "level2"
func title() -> String: return "江州劫法场"
func subtitle() -> String: return "黑旋风劫法场·白龙庙会好汉"
func campaign_core_goal() -> String: return "救下宋江、戴宗，并让二人活着登船。"
func story_contract_version() -> int: return 1
func campaign_story_goals() -> Array:
	return [
		{"id": "li_kui_first", "label": "候到行刑时刻，由李逵排头扑向刽子手", "required_events": ["jiangzhou_li_first"], "forbidden_events": ["jiangzhou_other_first"]},
		{"id": "free_both", "label": "在法场分别救下宋江、戴宗", "required_events": ["free_song", "free_dai"], "forbidden_events": []},
		{"id": "bailong_meeting", "label": "护送二人到白龙庙，与张顺、张横相会", "required_events": ["bailong"], "forbidden_events": ["jiangzhou_direct_dock"]},
		{"id": "named_survive", "label": "本关具名好汉全身脱险", "required_events": ["jiangzhou_named_survive"], "forbidden_events": ["jiangzhou_named_lost"]},
	]
func map_w() -> int: return 60
func map_h() -> int: return 58
func map_theme() -> String: return "town"
func map_base() -> int: return T.TOWN
func camera_start_cell() -> Vector2i: return Vector2i(22, 29)
func deploy_hint() -> String:
	return "可依原著分路混入、候李逵排头动手，也可由任一好汉提前劫法场。任务栏只负责定位现场，所有移动、交互与战斗均由玩家下令。救下宋江、戴宗并让二人活着登船即可通关；白龙庙会水军与具名好汉全员脱险另计演义印。"

func apply_overrides(defs: Dictionary, _abilities: Dictionary) -> void:
	defs["scaffold"]["captive"] = true
	defs["tavern"]["captive"] = true
	# 两位囚犯脱困时没有武器，不以魔幻技能替代撤离任务。
	for key in ["song_jiang", "dai_zong", "yan_shun", "zhang_shun", "zhang_heng"]:
		defs[key]["abilities"] = []
		defs[key]["ability"] = ""
		if key in ["song_jiang", "dai_zong"]:
			defs[key]["atk"] = 0
		defs[key]["aura"] = ""

func intro_lines() -> Array:
	return [
		{"who": "旁白", "key": "narrator", "text": "宋江题诗获罪，戴宗因假书败露，一同押赴江州法场。晁盖等扮作客商、脚夫，分路混入街市；李逵也独自赶来，要救宋江。"},
		{"who": "晁盖", "key": "chao_gai", "text": "先救二人脱了刀下，再杀开一条路。各自分开行走，莫先露了形迹。"},
		{"who": "李逵", "key": "li_kui", "text": "法刀要落了，俺先救哥哥！"},
		{"who": "行前提示", "key": "narrator", "text": "先分路靠近，李逵动手后众人救人。离开法场仍须保护宋江、戴宗；到白龙庙江边遇上驾船来的张顺等人，护送二人登船脱险。"},
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
	scaffold = b.spawn_at("scaffold", Unit.FACTION_LIANG, SCAFFOLD)
	scaffold.art_variant = "jiangzhou_scaffold"
	song_bound = b.spawn_at("song_jiang_bound", Unit.FACTION_LIANG, SCAFFOLD + Vector2i(-1, 0))
	dai_bound = b.spawn_at("dai_zong_bound", Unit.FACTION_LIANG, SCAFFOLD + Vector2i(1, 0))
	song_bound.art_variant = "song_jiang_bound"
	dai_bound.art_variant = "dai_zong_bound"
	for off in [Vector2i(-1, 2), Vector2i(1, 2)]:
		var guard: Unit = b.spawn_at("guan_zhanzi", Unit.FACTION_GUAN, SCAFFOLD + off)
		guard.passive = true
	for off in [Vector2i(-3, 1), Vector2i(3, 1), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(-2, 4), Vector2i(2, 4), Vector2i(0, 5), Vector2i(-4, 2)]:
		var guard: Unit = b.spawn_at("guan_laozi", Unit.FACTION_GUAN, SCAFFOLD + off)
		guard.passive = true
	cai = b.spawn_at("cai_jiu", Unit.FACTION_GUAN, YAMEN)
	cai.passive = true
	rescuing_army.clear()
	for spec in START_ARMY:
		var u: Unit = b.spawn_at(spec[0], Unit.FACTION_LIANG, spec[1])
		# 第四十、四十一回的法场/白龙庙李逵是赤膊双板斧造型；
		# 只在本关挂专用 variant，其他模式继续使用通用有上衣李逵。
		if u.key == "li_kui":
			u.art_variant = "li_kui_jiangzhou"
		u.passive = true
		u.stance = Unit.STANCE_PASSIVE
		rescuing_army.append(u)
		if u.key == "chao_gai":
			chao = u
	var temple: Unit = b.spawn_at("tavern", Unit.FACTION_LIANG, BAILONG + Vector2i(1, -1))
	temple.display_name = "白龙庙"
	temple.art_variant = "bailong_temple"
	song_freed = null
	dai_freed = null

func on_start(b) -> void:
	st = APPROACH
	exec_timer = EXEC_TIME
	rescued_song = false
	rescued_dai = false
	wave1_done = false
	wave2_done = false
	wave3_done = false
	at_dock_started = false
	smoke_t = 0.0
	escape_route = ""
	route_changed = false
	rear_guard = null
	rear_guard_recalled = false
	recall_action_added = false
	route_pressure.clear()
	pursuit_timer = -1.0
	pursuit_wave_done = false
	b.mission.begin("infiltrate", "混入十字街口", "李逵走西街，燕顺走南巷。兵器暂不出手；行刑时刻正在逼近。")
	b.mission.add_action("west_street", "李逵·混入西街", Vector2i(22, 25), ["li_kui"], 0.7)
	b.mission.add_action("south_lane", "燕顺·进入南巷", Vector2i(27, 29), ["yan_shun"], 0.7)

func on_mission_action(b, action_id: String, actor) -> void:
	match action_id:
		"west_street", "south_lane":
			b.mission.mark(action_id, "李逵从西街挤近法场" if action_id == "west_street" else "南巷好汉准备接应救出的囚犯")
			if b.mission.has_event("west_street") and b.mission.has_event("south_lane"):
				b.mission.add_action("first_axes", "李逵·排头动手", SCAFFOLD + Vector2i(-2, 3), ["li_kui"], 0.6)
		"first_axes":
			if st != APPROACH:
				return
			b.mission.mark("first_axes", "李逵先扑向刽子手，众好汉随即起事")
			_start_uprising(b, actor, true)
		"free_song":
			if st != RESCUE or rescued_song or not is_instance_valid(song_bound):
				return
			var at: Vector2 = song_bound.position
			b.units.erase(song_bound)
			song_bound.queue_free()
			song_bound = null
			song_freed = b.spawn_unit("song_jiang", Unit.FACTION_LIANG, at)
			song_freed.art_variant = "song_jiang_rescued"
			song_freed.passive = true
			song_freed.stance = Unit.STANCE_PASSIVE
			rescued_song = true
			b.mission.mark("free_song", "宋江脱了绑绳，尚未脱险；留人护送，尽快离开法场")
			_after_rescue(b)
		"free_dai":
			if st != RESCUE or rescued_dai or not is_instance_valid(dai_bound):
				return
			var at: Vector2 = dai_bound.position
			b.units.erase(dai_bound)
			dai_bound.queue_free()
			dai_bound = null
			dai_freed = b.spawn_unit("dai_zong", Unit.FACTION_LIANG, at)
			dai_freed.art_variant = "dai_zong_rescued"
			dai_freed.passive = true
			dai_freed.stance = Unit.STANCE_PASSIVE
			rescued_dai = true
			b.mission.mark("free_dai", "戴宗脱了绑绳；他与宋江都还未脱险，须一同护送到江边")
			_after_rescue(b)
		"route_west", "route_south":
			if st != RETREAT or escape_route != "":
				return
			escape_route = action_id
			b.mission.mark(action_id, "选择西巷近路，提防截兵" if action_id == "route_west" else "选择南巷宽路，绕开西巷堵截")
			_order_escape_route(b)
			b.mission.begin("bailong", "护着二人寻江而走", "西巷近而狭，南巷远而宽；两处截兵都已露头。若选错，可在中途岔口改道一次，再护送二人到白龙庙。")
			b.mission.add_action("bailong", "晁盖·到白龙庙江边", BAILONG, ["chao_gai"], 1.0)
			b.mission.add_action("change_route", "可选·岔口改走%s" % ("南巷" if escape_route == "route_west" else "西巷"), Vector2i(22, 28), ["chao_gai"], 0.8)
		"change_route":
			if st != RETREAT or escape_route == "" or route_changed:
				return
			escape_route = "route_south" if escape_route == "route_west" else "route_west"
			route_changed = true
			b.mission.mark("jiangzhou_route_changed", "晁盖看清截兵去向，改走%s；改道机会已用" % ("南巷宽路" if escape_route == "route_south" else "西巷近路"))
			_order_escape_route(b)
		"bailong":
			if st != RETREAT:
				return
			if not _rescued_pair_at_bailong(b):
				_retry_action(b, action_id, "宋江、戴宗还未一同到达白龙庙。先护住二人到庙江边，再与水军会合。")
				return
			_begin_river_escape(b, true)
		"rearguard_li", "rearguard_yan":
			if st != EMBARK or is_instance_valid(rear_guard):
				return
			rear_guard = actor
			rear_guard_recalled = false
			rear_guard.stance = Unit.STANCE_AGGRO
			b.mission.mark("jiangzhou_rearguard_set", rear_guard.display_name + "已由玩家部署在白龙庙前，掩护二人登船")
			b.mission.begin("embark", "江边相会·二人登船", "宋江、戴宗分别登船即可脱险；断后者由玩家自行安排，不再是胜利门锁。")
			_add_embark_actions(b)
		"board_song":
			if st == EMBARK and actor == song_freed and _living(song_freed):
				song_freed.resolve_story("embarked")
				b.mission.mark("board_song", "宋江已经登船，船上自有好汉照应")
		"board_dai":
			if st == EMBARK and actor == dai_freed and _living(dai_freed):
				dai_freed.resolve_story("embarked")
				b.mission.mark("board_dai", "戴宗已经登船，船上自有好汉照应")
		"rally_dock":
			if st != EMBARK:
				return
			b.mission.mark("rally_dock", "晁盖已经抵达码头并发出收队信号；其余人仍须由玩家亲自撤到江边" + ("，%s仍在庙前断后" % rear_guard.display_name if is_instance_valid(rear_guard) else ""))
		"recall_rearguard":
			if st != EMBARK or not is_instance_valid(rear_guard) or not _living(rear_guard):
				return
			rear_guard_recalled = true
			rear_guard.stance = Unit.STANCE_PASSIVE
			b.mission.mark("jiangzhou_rearguard_recalled", rear_guard.display_name + "已由玩家从断后位撤到码头")
		"leave_now":
			if st != EMBARK or not _living(song_freed) or not _living(dai_freed) \
					or song_freed.story_outcome != "embarked" or dai_freed.story_outcome != "embarked":
				return
			b.mission.mark("jiangzhou_depart_early", "宋江、戴宗先行开船，其余好汉各自突围")
			_story_miss(b, "named_survive", "没有等具名好汉全部登船。")

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

func _rescued_pair_at_bailong(b) -> bool:
	var temple_world: Vector2 = b.map.cell_to_world(BAILONG)
	for rescued in [song_freed, dai_freed]:
		if not _living(rescued) or rescued.story_outcome != "" or rescued.position.distance_to(temple_world) >= BAILONG_R:
			return false
	return true

func _after_rescue(b) -> void:
	if not rescued_song or not rescued_dai:
		return
	st = RETREAT
	pursuit_timer = 22.0
	pursuit_wave_done = false
	b.mission.begin("escape_choice", "选一条撤退巷道", "西巷近但窄，截兵正向路口赶来；南巷路长却开阔。选定后保护二人到白龙庙。")
	b.mission.add_action("route_west", "晁盖·走西巷近路", Vector2i(21, 29), ["chao_gai"], 0.8)
	b.mission.add_action("route_south", "燕顺·走南巷宽路", Vector2i(28, 33), ["yan_shun"], 0.8)
	_spawn_wave2(b)

func _start_uprising(b, actor, li_first: bool) -> void:
	if st != APPROACH:
		return
	st = BREAK_EXEC
	if li_first:
		b.mission.mark("jiangzhou_li_first", "李逵候到行刑时刻，排头扑向刽子手")
	else:
		b.mission.mark("jiangzhou_other_first", actor.display_name + "提前发动，众好汉随即劫法场")
		_story_miss(b, "li_kui_first", "没有候到李逵排头动手。")
	b.mission.begin("halt_execution", "打断行刑", "击倒两名刽子手，拦住行刑；随即上刑台，分别替二人解绳。")
	for u in rescuing_army:
		if _living(u):
			u.passive = false
			u.stance = Unit.STANCE_AGGRO
	b.mission.set_status("法场已经起事。请自行编队、集火刽子手并安排掩护；系统不会替你冲锋。")
	_spawn_wave1(b)

func _uprising_actor():
	for u in rescuing_army:
		if _living(u) and is_instance_valid(u._target) and u._target.faction == Unit.FACTION_GUAN:
			return u
	return null

func _begin_river_escape(b, at_bailong: bool) -> void:
	if st != RETREAT:
		return
	st = EMBARK
	if at_bailong:
		b.mission.mark("bailong", "到白龙庙江边，恰遇张顺、张横等驾船赶来救人；江上有了脱身去路")
	else:
		b.mission.mark("jiangzhou_direct_dock", "救援队自行赶到码头，与沿江搜索的水军会合")
		_story_miss(b, "bailong_meeting", "没有先到白龙庙会合水军。")
	for key in ["zhang_shun", "zhang_heng"]:
		var sailor: Unit = b.spawn_at(key, Unit.FACTION_LIANG, DOCK_C + Vector2i(-2, -2))
		rescuing_army.append(sailor)
	b.mission.begin("river_escape", "护送宋江、戴宗登船", "两位获救者活着登船即可完成营救。可自行留人断后；原著路线可在白龙庙前安排李逵或燕顺守口。")
	var li: Unit = b.find_unit("li_kui")
	var yan: Unit = b.find_unit("yan_shun")
	if _living(li): b.mission.add_action("rearguard_li", "可选·李逵守庙前路口", BAILONG + Vector2i(2, 0), ["li_kui"], 0.8)
	if _living(yan): b.mission.add_action("rearguard_yan", "可选·燕顺守庙前路口", BAILONG + Vector2i(2, 1), ["yan_shun"], 0.8)
	_add_embark_actions(b)
	_spawn_wave3(b)

func _add_embark_actions(b) -> void:
	var leader: Unit = b.find_unit("chao_gai")
	if _living(leader):
		b.mission.add_action("rally_dock", "可选·晁盖到码头发收队信号", DOCK_C + Vector2i(0, -1), ["chao_gai"], 1.0)
	b.mission.add_action("board_song", "宋江·登船脱险", DOCK_C, ["song_jiang"], 1.8)
	b.mission.add_action("board_dai", "戴宗·登船脱险", DOCK_C + Vector2i(1, 0), ["dai_zong"], 1.8)

func _rescued_pair_near(b, cell: Vector2i, radius: float) -> bool:
	var target: Vector2 = b.map.cell_to_world(cell)
	for rescued in [song_freed, dai_freed]:
		if not _living(rescued) or rescued.story_outcome != "" or rescued.position.distance_to(target) >= radius:
			return false
	return true

func _living_rescuers() -> int:
	var count := 0
	for u in rescuing_army:
		if _living(u) and u.story_outcome == "": count += 1
	return count

func _route_points() -> Array:
	return [Vector2i(18, 34), Vector2i(14, 40), BAILONG] if escape_route == "route_west" else [Vector2i(28, 36), Vector2i(24, 41), Vector2i(18, 45), BAILONG]

func _order_escape_route(b) -> void:
	var points: Array = _route_points()
	for point in points:
		b.lit_cells[point] = 18.0
	var route_name := "西巷近路" if escape_route == "route_west" else "南巷宽路"
	b.mission.set_status("已标出%s。请自行编组护送宋江、戴宗；系统不会替队伍行军。" % route_name)

func _spawn_pursuit_wave(b) -> void:
	if pursuit_wave_done or st != RETREAT:
		return
	pursuit_wave_done = true
	var target: Vector2 = b.map.cell_to_world(BAILONG)
	if _living(song_freed) and _living(dai_freed):
		target = (song_freed.position + dai_freed.position) * 0.5
	var pursuers: Array = b.spawn_group("guan_dao", 3, Unit.FACTION_GUAN, PLAZA_C, target)
	for pursuer in pursuers:
		pursuer.set_meta("jiangzhou_pressure", "rear_pursuit")
	b.mission.mark("jiangzhou_rear_pursuit", "衙役从法场追来；护送队若停在街中，会被前后夹击")
	b.mission.set_status("追兵已经出城。继续由玩家控制前队开路、后队断后。")

func process(b, delta: float) -> void:
	# 这是必须的实体检查：曾经救出不代表当前仍存活。
	if rescued_song and not _living(song_freed):
		b.lose("宋江脱困后遇害，营救失败。")
		return
	if rescued_dai and not _living(dai_freed):
		b.lose("戴宗在获救后遇害，营救失败。")
		return
	var pair_can_self_evacuate := rescued_song and rescued_dai and _living(song_freed) and _living(dai_freed)
	if _living_rescuers() == 0 and not pair_can_self_evacuate:
		b.lose("救援者已经全部倒下，宋江、戴宗无人护送登船。")
		return
	if b._smoke:
		_smoke_drive(b, delta)
	var zhanzi: int = b.count_alive(Unit.FACTION_GUAN, "guan_zhanzi")
	if st == APPROACH:
		var uprising_actor: Unit = _uprising_actor()
		if is_instance_valid(uprising_actor):
			_start_uprising(b, uprising_actor, uprising_actor.key == "li_kui" and b.mission.has_event("west_street") and b.mission.has_event("south_lane"))
	if st in [APPROACH, BREAK_EXEC] and zhanzi > 0:
		exec_timer = maxf(0.0, exec_timer - delta)
		if exec_timer <= 0.0:
			b.lose("行刑时刻已过，未能打断刽子手。")
			return
	if st == BREAK_EXEC and zhanzi == 0:
		st = RESCUE
		b.mission.mark("execution_halted", "两名刽子手被打倒，行刑中断")
		b.mission.begin("free_captives", "刑台解缚", "分别替宋江、戴宗解绳，留人掩护，尽快离开法场。")
		# 标记留在两名囚犯各自的刑台前沿，保持原著主线派遣路径；人物办理距离
		# 放宽以容纳刑台碰撞与人群，但点击命中仅24px，点两标记中间不会误救。
		b.mission.add_action("free_song", "好汉·救下宋江", SCAFFOLD + Vector2i(-1, 1), RESCUERS, 1.3, 160.0, 24.0)
		b.mission.add_action("free_dai", "好汉·救下戴宗", SCAFFOLD + Vector2i(1, 1), RESCUERS, 1.3, 160.0, 24.0)
	if st == RETREAT:
		if not pursuit_wave_done and pursuit_timer >= 0.0:
			pursuit_timer -= delta
			if pursuit_timer <= 0.0:
				_spawn_pursuit_wave(b)
		if _rescued_pair_at_bailong(b):
			_begin_river_escape(b, true)
		elif _rescued_pair_near(b, DOCK_C, DOCK_R):
			_begin_river_escape(b, false)
	if st == EMBARK:
		if not recall_action_added and is_instance_valid(rear_guard) and _living(rear_guard) and b.mission.has_event("board_song") and b.mission.has_event("board_dai") and b.mission.has_event("rally_dock"):
			recall_action_added = true
			b.mission.add_action("recall_rearguard", "%s·撤到码头" % rear_guard.display_name, DOCK_C, [rear_guard.key], 0.7, 54.0)
		if b.mission.has_event("rally_dock"):
			for u in rescuing_army:
				if _living(u) and u.story_outcome == "" and u.position.distance_to(b.map.cell_to_world(DOCK_C)) < DOCK_R:
					if u == rear_guard and not rear_guard_recalled:
						rear_guard_recalled = true
						b.mission.mark("jiangzhou_rearguard_recalled", rear_guard.display_name + "已由玩家从断后位撤到码头")
					u.resolve_story("embarked")
		if _living(song_freed) and _living(dai_freed) and song_freed.story_outcome == "embarked" and dai_freed.story_outcome == "embarked":
			var named_safe := true
			for key in ["chao_gai", "li_kui", "hua_rong", "yan_shun", "zhang_shun", "zhang_heng"]:
				var named: Unit = b.find_unit(key)
				if not _living(named) or named.story_outcome != "embarked": named_safe = false
			if named_safe:
				b.mission.mark("jiangzhou_named_survive", "本关具名好汉均活着脱险")
			elif b.mission.has_event("rally_dock") and not b.mission.has_event("jiangzhou_named_lost") and not b.mission.has_event("jiangzhou_depart_early"):
				if not b.mission.actions.has("leave_now"):
					b.mission.add_action("leave_now", "可选·二人先行开船（放弃全员脱险印）", DOCK_C + Vector2i(2, 0), [], 0.6)
				b.mission.set_objective("宋江、戴宗已经登船。可等具名好汉全部撤到码头；也可选择先行开船，立即完成核心营救。")
				return
			else:
				_story_miss(b, "named_survive", "已有具名好汉未能脱险。")
			b.mission.mark("all_embarked", "宋江、戴宗均已活着登船")
			b.win("宋江、戴宗活着登船，江州营救的核心目标已经完成。")

func _living(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0

func _all_at_dock(_b) -> bool:
	if not _living(song_freed) or not _living(dai_freed) or not _living(chao):
		return false
	if song_freed.story_outcome != "embarked" or dai_freed.story_outcome != "embarked":
		return false
	# 断后者是明确任务对象，不能按“幸存单位”规则跳过死亡；必须活着登船。
	if not _living(rear_guard) or rear_guard.story_outcome != "embarked":
		return false
	for u in rescuing_army:
		if _living(u) and u.story_outcome != "embarked":
			return false
	return chao.story_outcome == "embarked"

func _any_at_dock(b) -> bool:
	for u in rescuing_army:
		if _living(u) and u.position.distance_to(b.map.cell_to_world(DOCK_C)) < DOCK_R:
			return true
	return false

func _all_at_dock_quiet(b) -> bool:
	return _all_at_dock(b)

func _spawn_wave1(b) -> void:
	if wave1_done:
		return
	wave1_done = true
	b.spawn_group("guan_dao", 3, Unit.FACTION_GUAN, GATE_N, b.map.cell_to_world(PLAZA_C))
	b.spawn_group("guan_gong", 2, Unit.FACTION_GUAN, GATE_E, b.map.cell_to_world(PLAZA_C))

func _spawn_wave2(b) -> void:
	if wave2_done:
		return
	wave2_done = true
	# 总数仍是既有六人：三人守西巷窄口，三人压向南巷宽口。
	# 玩家在选路前能看到两边压力，选错仍有一次改道机会。
	var west_group: Array = b.spawn_group("guan_dao", 3, Unit.FACTION_GUAN, GATE_E, b.map.cell_to_world(Vector2i(18, 34)))
	var south_group: Array = b.spawn_group("guan_gong", 3, Unit.FACTION_GUAN, GATE_N, b.map.cell_to_world(Vector2i(27, 36)))
	for u in west_group:
		u.set_meta("jiangzhou_pressure", "west_narrow")
		route_pressure.append(u)
	for u in south_group:
		u.set_meta("jiangzhou_pressure", "south_open")
		route_pressure.append(u)

func _spawn_wave3(b) -> void:
	if wave3_done:
		return
	wave3_done = true
	at_dock_started = true
	b.spawn_group("guan_dao", 3, Unit.FACTION_GUAN, GATE_E, b.map.cell_to_world(BAILONG))

func on_unit_died(b, u) -> void:
	# 能力瞬杀刽子手时，攻击目标可能已被清掉；仍必须真正切入劫法场，不能留在潜入阶段软锁。
	if st == APPROACH and u.key == "guan_zhanzi":
		var attacker: Unit = u._killer
		if not _living(attacker) or not (attacker in rescuing_army):
			attacker = null
			for candidate in rescuing_army:
				if _living(candidate):
					attacker = candidate
					break
		if _living(attacker):
			_start_uprising(b, attacker, attacker.key == "li_kui" and b.mission.has_event("west_street") and b.mission.has_event("south_lane"))
	if u == song_bound or u == song_freed:
		b.lose("宋江遇害，营救失败。")
	elif u == dai_bound or u == dai_freed:
		b.lose("戴宗遇害，营救失败。")
	elif u in rescuing_army and u.key in ["chao_gai", "li_kui", "hua_rong", "yan_shun", "zhang_shun", "zhang_heng"]:
		b.mission.mark("jiangzhou_named_lost", u.display_name + "未能脱险；营救仍可继续")
		_story_miss(b, "named_survive", "具名好汉已有伤亡。")

func on_unit_resolved(b, u, outcome: String) -> void:
	if outcome == "embarked":
		b.mission.mark("embarked_%d" % u.get_instance_id(), u.display_name + "活着登船")

func top_status(_b) -> String:
	var stage_text: String = ["分路混入", "中断行刑", "分别解救二人", "护送至白龙庙", "掩护登船"][st]
	if st in [APPROACH, BREAK_EXEC]:
		stage_text += " | 行刑剩余%d秒" % ceili(exec_timer)
	if st == EMBARK:
		stage_text += " | 宋江%s·戴宗%s" % ["已登船" if _living(song_freed) and song_freed.story_outcome == "embarked" else "未脱险", "已登船" if _living(dai_freed) and dai_freed.story_outcome == "embarked" else "未脱险"]
		if is_instance_valid(rear_guard):
			stage_text += " | %s%s" % [rear_guard.display_name, "正撤回" if rear_guard_recalled else "断后"]
	return "江州劫法场 | " + stage_text

func _smoke_drive(b, delta: float) -> void:
	if b.mission.active_action_id != "":
		return
	smoke_t -= delta
	if smoke_t > 0.0:
		return
	smoke_t = 0.8
	# SMOKE 只负责自动回归：补齐正式玩法已移除的友军行军命令。
	# 这些命令不会在玩家游玩时执行。
	if st == RETREAT and escape_route != "":
		var temple_world: Vector2 = b.map.cell_to_world(BAILONG)
		for i in range([song_freed, dai_freed].size()):
			var rescued: Unit = [song_freed, dai_freed][i]
			if _living(rescued):
				rescued.order_move(temple_world + Vector2(i * 24.0, 0.0))
		for i in range(rescuing_army.size()):
			var escort: Unit = rescuing_army[i]
			if _living(escort) and escort.story_outcome == "":
				escort.order_move(temple_world + Vector2((i % 4) * 20.0, 30.0 + (i / 4) * 20.0))
	elif st == EMBARK:
		var dock_world: Vector2 = b.map.cell_to_world(DOCK_C)
		for i in range([song_freed, dai_freed].size()):
			var rescued: Unit = [song_freed, dai_freed][i]
			if _living(rescued) and rescued.story_outcome == "":
				rescued.order_move(dock_world + Vector2(i * 22.0, 0.0))
		for i in range(rescuing_army.size()):
			var escort: Unit = rescuing_army[i]
			if _living(escort) and escort.story_outcome == "" and escort != rear_guard:
				escort.order_move(dock_world + Vector2((i % 4) * 20.0, 28.0 + (i / 4) * 20.0))
	var chosen_route := "route_south" if OS.get_environment("JIANGZHOU_SMOKE_ROUTE") == "south" else "route_west"
	for action_id in ["west_street", "south_lane", "first_axes", "free_song", "free_dai", chosen_route, "bailong", "rearguard_li", "rally_dock", "board_song", "board_dai", "recall_rearguard"]:
		if b.mission.request_action(action_id):
			return
	if st == BREAK_EXEC:
		var target: Unit = b.find_unit("guan_zhanzi")
		for u in rescuing_army:
			if _living(u) and u.key != "chao_gai" and target != null:
				if not u.has_target():
					u.order_attack(target)
				if u.is_hero and u.slot_ready(0):
					b._do_ability(u, 0, target.position)

func _story_miss(b, goal_id: String, reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id, reason)
