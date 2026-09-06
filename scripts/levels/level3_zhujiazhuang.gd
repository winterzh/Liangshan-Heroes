extends LevelBase
## 原著47—50回：探路脱围、阵前擒扈三娘、数日后孙立内应。
## 三次作战重新部署，只保留mission故事标志，不能带着伤兵连续冲庄。
const T := GameMap.T
const DEPLOY_CELL := Vector2i(58, 28)
const ENTRY_CELL := Vector2i(50, 28)
const FORK2_CELL := Vector2i(42, 22)
const HU_CELL := Vector2i(40, 14)
const FORK3_CELL := Vector2i(34, 30)
const GATE_CELL := Vector2i(22, 28)
const COURT_CELL := Vector2i(12, 28)
const AMBUSH_A := Vector2i(50, 33)
const AMBUSH_B := Vector2i(30, 36)
const PRISON_CELL := Vector2i(11, 33)
const SECOND_SONG_SAFE := Vector2i(56, 32)
const SECOND_LIN_INTERCEPT := Vector2i(40, 18)
const SECOND_HUA_COVER := Vector2i(44, 22)
const SECOND_HANDOFF := Vector2i(57, 27)
const INNER_GATE_SUPPORT := Vector2i(18, 28)
const OUTER_RALLY := Vector2i(25, 28)
const PRISON_RALLY_A := Vector2i(12, 28)
const PRISON_RALLY_B := Vector2i(15, 31)
const SAFE_NODES: Array[Vector2i] = [Vector2i(58,28),Vector2i(50,28),Vector2i(50,22),Vector2i(42,22),Vector2i(42,30),Vector2i(34,30),Vector2i(34,28),Vector2i(22,28),Vector2i(12,28)]
var stage := "scout"
var gate: Unit
var shi: Unit
var song: Unit
var lin: Unit
var hua: Unit
var hu: Unit
var sun: Unit
var gu: Unit
var prisoners: Array = []
var prisoner_groups: Array = []
var second_guards: Array = []
var second_spears: Array = []
var smoke_t := 0.0
var pursuit_sent := false
var assault_started := false
var free_scout = null
var free_second_fight := false
var free_third_assault := false

func id() -> String: return "level3"
func title() -> String: return "三打祝家庄"
func subtitle() -> String: return "探路脱围·阵前擒将·孙立内应"
func campaign_core_goal() -> String: return "三次交战后攻破祝家庄；宋江必须存活。认路、生擒、内应均为可选演义目标。"
func story_contract_version() -> int: return 1
func campaign_story_goals() -> Array:
	return [
		{"id":"zhu_poplar","label":"白杨认路，石秀探庄后带队脱围","required_events":["zhu_route_known","zhu_gate_scouted","zhu_first_withdrawal"],"forbidden_events":["zhu_free_scout"]},
		{"id":"zhu_capture","label":"三处分守，林冲生擒并押送扈三娘","required_events":["zhu_second_formation","zhu_hu_captured","zhu_hu_departed"],"forbidden_events":["zhu_second_freefight"]},
		{"id":"zhu_inside","label":"孙立入庄，邹渊、邹润开陷车，孙新换旗后里外合击","required_events":["zhu_sun_entered","zhu_prisoners_freed","zhu_gate_opened","zhu_assault_ordered"],"forbidden_events":["zhu_gate_breached"]},
		{"id":"zhu_seven","label":"七名被囚好汉全部生还","required_events":["zhu_seven_safe"],"forbidden_events":["zhu_prisoner_lost"]},
	]
func map_w() -> int: return 64
func map_h() -> int: return 56
func map_theme() -> String: return "village"
func map_base() -> int: return T.GRASS
func camera_start_cell() -> Vector2i: return Vector2i(52,28)
func deploy_hint() -> String:
	return "三次交战跨日重新部署。按原著可完成石秀认路、林冲擒将、孙立入庄、邹渊邹润救囚和孙新换旗；也可自行侦察、接战或强攻。偏离章法只失对应演义印；扈三娘始终按敌将俘虏处理。"
func intro_lines() -> Array:
	return [
		{"who":"旁白","key":"narrator","text":"时迁陷在祝家庄，宋江领兵来到独龙冈。扈家庄与祝家结亲，随时可能来援；李应却已被祝彪射伤，闭门不出。庄前盘陀路纵横，夜里难辨出路。"},
		{"who":"石秀","key":"shi_xiu","text":"钟离老人说了，遇着白杨便转弯，才是活路。我先去认清岔口，哥哥且接应着，莫教庄兵截断归路。"},
		{"who":"军令","key":"narrator","text":"先探清进退道路，保全出营的兄弟。庄门坚固，切莫贸然强攻；寻到内应，方可里外夹击。"}]
func paint_map(map: GameMap) -> void:
	# 田埂农田底子（村庄主题）
	map.fill_rect(0, 0, 64, 56, T.GRASS)
	map.fill_ellipse(Vector2(30, 28), 30, 22, T.FIELD, [T.GRASS])
	# 右侧梁山集结区：开阔草地
	map.fill_rect(52, 18, 12, 20, T.GRASS)
	# 中段盘陀路迷宫：大片树林墙（迷宫主体），随后由 ROAD 安全道与死巷切穿
	map.fill_rect(18, 10, 36, 38, T.FOREST, [T.GRASS, T.FIELD])
	# 庄内（更低 x）：农田 + 内院
	map.fill_rect(4, 16, 16, 26, T.FIELD, [T.FOREST, T.GRASS])
	map.fill_ellipse(Vector2(COURT_CELL.x, COURT_CELL.y), 6, 6, T.PLAZA, [T.FIELD, T.GRASS, T.FOREST])

	# —— 唯一安全 ROAD 路径（沿 SAFE_NODES 蜿蜒，遇白杨拐弯）——
	var pts: Array = []
	for c in SAFE_NODES:
		pts.append(Vector2(c.x, c.y))
	map.paint_path(pts, 0, T.ROAD)
	# 支线小道：岔口二 → 扈三娘遭遇点（可选）
	map.paint_path([Vector2(42, 22), Vector2(40, 18), Vector2(40, 14)], 0, T.ROAD)

	# —— 岔口死巷（ROAD），尽头 REEDS 藏伏兵 ——
	# 死巷A：入口岔口直行/下折，尽头 (50,33)
	map.paint_path([Vector2(50, 28), Vector2(50, 33)], 0, T.ROAD)
	# 死巷B：岔口三直行偏南，尽头 (30,36)
	map.paint_path([Vector2(34, 30), Vector2(32, 33), Vector2(30, 36)], 0, T.ROAD)
	# 再添两条迷惑性死巷增强盘陀感
	map.paint_path([Vector2(42, 22), Vector2(46, 18)], 0, T.ROAD)        # 岔口二误向东北
	map.paint_path([Vector2(34, 30), Vector2(28, 30), Vector2(26, 33)], 0, T.ROAD)  # 岔口三误直西偏南
	# 死巷尽头芦苇伏点
	map.fill_ellipse(Vector2(AMBUSH_A.x, AMBUSH_A.y), 2, 2, T.REEDS)
	map.fill_ellipse(Vector2(AMBUSH_B.x, AMBUSH_B.y), 2, 2, T.REEDS)
	map.fill_ellipse(Vector2(46, 18), 1, 1, T.REEDS)
	map.fill_ellipse(Vector2(26, 33), 1, 1, T.REEDS)
	# 扈三娘遭遇点四周小片树林（巡弋空地）
	map.fill_ellipse(Vector2(HU_CELL.x, HU_CELL.y), 3, 3, T.GRASS, [T.FOREST])

	# —— 庄墙壁垒（CLIFF 不可通行）+ 水渠（WATER）逼大军走盘陀路 ——
	# 庄墙：庄门所在竖墙（x≈20），留出庄门 1x3 缺口（y 27..29）
	for y in range(14, 43):
		if y < 27 or y > 29:
			map.set_cell_t(20, y, T.CLIFF)
			map.set_cell_t(19, y, T.CLIFF)
	# 水渠绕庄墙外侧（庄门外缺口处仍留 ROAD 通过）
	for y in range(14, 43):
		if y < 26 or y > 30:
			map.set_cell_t(21, y, T.WATER)
	# 上下边墙夹合迷宫
	map.fill_rect(18, 8, 36, 2, T.CLIFF)
	map.fill_rect(18, 46, 36, 2, T.CLIFF)


func decorate(map: GameMap) -> void:
	map.decor = [
		# 白杨为记（路标）——立于各拐点旁
		["forest", Vector2i(50, 26), 40.0], ["forest", Vector2i(43, 24), 40.0],
		["forest", Vector2i(40, 30), 40.0], ["forest", Vector2i(34, 26), 40.0],
		["forest", Vector2i(36, 14), 40.0],
		# 庄门与壁垒
		["hall", Vector2i(GATE_CELL.x, GATE_CELL.y), 74.0],
		["tower", Vector2i(20, 24), 60.0], ["tower", Vector2i(20, 32), 60.0],
		# 内院祠堂
		["hall", Vector2i(COURT_CELL.x, COURT_CELL.y - 1), 78.0],
		# 第四十八回庄门一对白旗。两处仅由 level3 marker 取原文，通用 banner 保持无字。
		["banner", Vector2i(10, 26), 144.0, "zhujiazhuang_gate_chao_standard"],
		["banner", Vector2i(14, 30), 144.0, "zhujiazhuang_gate_song_standard"],
		# 死巷标记物（迷惑）
		["rocks", Vector2i(50, 34), 44.0], ["rocks", Vector2i(30, 37), 44.0],
		["tent", Vector2i(58, 22), 60.0], ["tent", Vector2i(60, 30), 60.0],
	]


func deploy(b) -> void:
	stage = "scout"
	free_scout = null
	free_second_fight = false
	free_third_assault = false
	prisoners.clear()
	prisoner_groups.clear()
	second_guards.clear()
	second_spears.clear()
	pursuit_sent = false
	assault_started = false
	shi = b.spawn_at("shi_xiu", Unit.FACTION_LIANG, DEPLOY_CELL)
	song = b.spawn_at("song_jiang", Unit.FACTION_LIANG, DEPLOY_CELL + Vector2i(1,2))
	for c in [Vector2i(1,-1),Vector2i(2,1),Vector2i(1,3)]:
		b.spawn_at("liang_dao",Unit.FACTION_LIANG,DEPLOY_CELL+c)
	gate = b.spawn_at("zhu_gate",Unit.FACTION_GUAN,GATE_CELL)
	_configure_gate_environment(gate)
	gate.defeat_outcome = "subdued"
	gate.apply_shield(100000.0,99999.0)

func on_start(b) -> void:
	b.lit_cells.clear()
	b.mission.begin("zhu_scout","第一打·白杨认路","石秀到白杨岔口辨路；宋江与随军先在营地接应。")
	b.mission.add_action("zhu_white_poplar","石秀：辨认白杨",FORK2_CELL,["shi_xiu"],2.0)

func on_mission_action(b, action_id: String, _actor) -> void:
	match action_id:
		"zhu_white_poplar":
			b.mission.mark("zhu_route_known","石秀辨清白杨记号与盘陀路")
			_light_route(b)
			b.mission.add_action("zhu_recon_gate","石秀：探看庄门",FORK3_CELL,["shi_xiu"],2.0)
		"zhu_recon_gate":
			b.mission.mark("zhu_gate_scouted","石秀探到庄前岔口，标出已走过的回营路线")
			_light_route(b)
			stage = "withdraw"
			b.mission.begin("zhu_withdraw","第一打·脱出盘陀路","庄军来追，护石秀返回营地；这次不攻庄门。")
			b.mission.add_action("zhu_return","石秀：回营报告",DEPLOY_CELL,["shi_xiu"],1.5)
			pursuit_sent = true
			b.spawn_group("zhu_keke",4,Unit.FACTION_GUAN,Vector2i(28,28),shi.position,1)
		"zhu_return":
			b.mission.mark("zhu_first_withdrawal","第一打探路脱围")
			stage = "transition"
			_second_day.call_deferred(b)
		"zhu_song_safe", "zhu_lin_intercept", "zhu_hua_cover":
			if stage != "second" or not _mission_action_done(b, action_id): return
			var role_actor: Unit = {"zhu_song_safe":song, "zhu_lin_intercept":lin, "zhu_hua_cover":hua}[action_id]
			if _actor != role_actor or not is_instance_valid(role_actor) or role_actor.hp <= 0.0: return
			var role_text: String = {"zhu_song_safe":"宋江退到东侧安全处，由亲军护住退路", "zhu_lin_intercept":"林冲抢到扈三娘来路前方，截住冲势", "zhu_hua_cover":"花荣在林冲后方张弓掩护，不入近身乱战"}[action_id]
			b.mission.mark(action_id, role_text)
			role_actor.order_hold_position()
			_try_begin_second_fight(b)
		"zhu_escort_hu":
			if stage != "send_hu" or _actor != lin or not _mission_action_done(b, action_id): return
			if not _escort_pair_at_handoff(b):
				_retry_action(b, action_id, "林冲与扈三娘须一同到营前，不能只让林冲独自回营。")
				return
			b.mission.mark("zhu_hu_at_handoff","林冲将扈三娘押到营前，当面交给留守军士")
			stage = "hu_handoff"
			b.mission.begin("zhu_hu_handoff","第二打·营前交接","林冲与扈三娘都已到营前。由林冲当面交接，再连夜送往梁山交宋太公看管。")
			b.mission.add_action("zhu_hu_handoff","林冲：确认营前交接",SECOND_HANDOFF,["lin_chong"],1.2,40.0)
		"zhu_hu_handoff":
			if stage != "hu_handoff" or _actor != lin or not _mission_action_done(b, action_id) or not _escort_pair_at_handoff(b): return
			b.mission.mark("zhu_hu_departed","扈三娘由军士连夜押送梁山，交宋太公看管")
			if is_instance_valid(hu): hu.hide()
			stage = "transition"
			_third_day.call_deferred(b)
		"zhu_enter_manor":
			if stage != "infiltrate" or _actor != sun or not _mission_action_done(b, action_id): return
			b.mission.mark("zhu_sun_entered","孙立把旗号改作“登州兵马提辖孙立”，借同门之谊获准入庄")
			# A guarded story entrance admits these two guests only. The outside army's gate stays blocked.
			for spec in [[sun,Vector2i(15,29)],[gu,Vector2i(15,31)]]:
				var guest: Unit = spec[0]
				if is_instance_valid(guest) and guest.hp > 0.0:
					guest.order_stop()
					guest.position = b.map.cell_to_world(b.map.nearest_open(spec[1],guest.movement_profile))
					b.map.sync_render_position(guest)
			stage = "inside"
			b.mission.begin("zhu_inside","第三打·内外分工","顾大嫂在堂前发出内应信号，邹渊、邹润守监门开陷车；孙立守吊桥接应孙新，宋江在庄外列阵。等七名好汉分两队退到内院，再发总攻。")
			b.mission.add_action("zhu_free_prisoners","顾大嫂：发出救囚信号",PRISON_CELL+Vector2i(2,0),["gu_dasao"],3.0)
			b.mission.add_action("zhu_inner_support","孙立：到庄门内侧接应",INNER_GATE_SUPPORT,["sun_li"],1.5,40.0)
			b.mission.add_action("zhu_outer_position","宋江：率外军在门外占位",OUTER_RALLY,["song_jiang"],1.5,40.0)
			_refresh_third_objective(b)
		"zhu_free_prisoners":
			if stage != "inside" or _actor != gu or not b.mission.has_event("zhu_sun_entered") or not _mission_action_done(b, action_id) or b.mission.has_event("zhu_prisoners_freed"): return
			prisoner_groups = [prisoners.slice(0,4), prisoners.slice(4,7)]
			for group_index in range(prisoner_groups.size()):
				var rally: Vector2i = PRISON_RALLY_A if group_index == 0 else PRISON_RALLY_B
				var group: Array = prisoner_groups[group_index]
				for member_index in range(group.size()):
					var u: Unit = group[member_index]
					if is_instance_valid(u) and u.hp > 0.0:
						_release_captive(u)
				b.lit_cells[rally] = 30.0
			b.mission.mark("zhu_prisoners_freed","顾大嫂在堂前发出内应信号；邹渊、邹润守监门开陷车，七名好汉已经恢复玩家控制")
			b.mission.set_status("请玩家把两队获救好汉分别撤到内院东西集结点；系统不会替他们行军。")
			_refresh_third_objective(b)
		"zhu_inner_support":
			if stage != "inside" or _actor != sun or not _mission_action_done(b, action_id): return
			b.mission.mark("zhu_inner_support_ready","孙立守住吊桥内侧，等孙新在门楼换旗")
			sun.order_hold_position()
			if not b.mission.actions.has("zhu_open_gate"):
				b.mission.add_action("zhu_open_gate","孙立：守桥接应孙新换旗",INNER_GATE_SUPPORT,["sun_li"],2.0,40.0)
			_refresh_third_objective(b)
		"zhu_outer_position":
			if stage != "inside" or _actor != song or not _mission_action_done(b, action_id): return
			b.mission.mark("zhu_outer_ready","宋江率外军在庄门外列定，暂不抢门")
			song.order_hold_position()
			_refresh_third_objective(b)
		"zhu_open_gate":
			if stage != "inside" or _actor != sun or not b.mission.has_event("zhu_inner_support_ready") or not _mission_action_done(b, action_id) or b.mission.has_event("zhu_gate_opened"): return
			b.mission.mark("zhu_gate_opened","孙新在门楼插起原带旗号，孙立守住吊桥接应；宋江尚未下总攻号令")
			if is_instance_valid(gate):
				b.unregister_building_footprint(gate)
				gate.resolve_story("retreated")
				gate.visible = false
			if not b.mission.actions.has("zhu_attack_signal"):
				b.mission.add_action("zhu_attack_signal","宋江：审势发总攻号令",OUTER_RALLY,["song_jiang"],1.2,40.0)
			_refresh_third_objective(b)
		"zhu_attack_signal":
			if stage != "inside" or _actor != song or not _mission_action_done(b, action_id) or b.mission.has_event("zhu_assault_ordered"): return
			if not _third_signal_ready(b):
				_restore_third_role_actions(b)
				_retry_action(b, action_id, "庄内外尚未合拢：两队囚犯都要退到内院，孙立守门内，宋江率军守门外，方可发令。")
				return
			b.mission.mark("zhu_assault_ordered","两队获救好汉已经退稳，宋江见内外俱备，下令里外夹攻")
			_begin_third_assault(b)

func _mission_action_done(b, action_id: String) -> bool:
	return b.mission.actions.has(action_id) and bool(b.mission.actions[action_id].done)

func _retry_action(b, action_id: String, reason: String) -> void:
	if b.mission.actions.has(action_id):
		var action: Dictionary = b.mission.actions[action_id]
		action.done = false
		action.button.disabled = false
		action.marker.show()
		b.mission._refresh_marker_captions()
	if reason != "":
		b.mission.set_objective(reason)
		b.msg(reason,4.0)

func _miss_story(b, goal_id: String, reason: String) -> void:
	if b.mission.has_method("miss_story_goal"):
		b.mission.miss_story_goal(goal_id,reason)

func _complete_story(b, goal_id: String, note: String) -> void:
	if b.mission.has_method("complete_story_goal"):
		b.mission.complete_story_goal(goal_id,note)

func _living_liang(b) -> Array:
	return b.units_of(Unit.FACTION_LIANG).filter(func(u):
		return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == "" and not u.is_captive and not u.is_building)

func _free_scout_tick(b) -> void:
	if stage == "scout" and not b.mission.has_event("zhu_gate_scouted"):
		for actor in _living_liang(b):
			if actor.position.distance_to(b.map.cell_to_world(FORK3_CELL)) > 92.0 \
				and actor.position.distance_to(b.map.cell_to_world(GATE_CELL)) > 132.0:
				continue
			free_scout = actor
			actor.set_meta("zhu_free_scout",true)
			b.mission.mark("zhu_free_scout","%s自行探到庄前；未循白杨记号，仍可带队撤回。"%actor.display_name)
			_miss_story(b,"zhu_poplar","没有由石秀依白杨记号完成探路脱围")
			stage = "withdraw"
			b.mission.begin("zhu_withdraw_free","第一打·自行脱围","侦察已经取得。让任一幸存人马返回东侧营地；走错路只会遭伏，不会判整关失败。")
			pursuit_sent = true
			b.spawn_group("zhu_keke",4,Unit.FACTION_GUAN,Vector2i(28,28),actor.position,1)
			break
	elif stage == "withdraw" and free_scout != null:
		var returner = free_scout if is_instance_valid(free_scout) and free_scout.hp > 0.0 else null
		if returner == null:
			var survivors := _living_liang(b)
			if not survivors.is_empty(): returner = survivors[0]
		if returner != null and returner.position.distance_to(b.map.cell_to_world(DEPLOY_CELL)) <= 112.0:
			b.mission.mark("zhu_first_withdrawal","第一打侦察人马自行脱围回营")
			stage = "transition"
			_second_day.call_deferred(b)

func _start_second_free_fight(b) -> void:
	if stage != "second" or free_second_fight: return
	free_second_fight = true
	b.mission.mark("zhu_second_freefight","梁山自行接战，没有等三处分守同时站稳")
	_miss_story(b,"zhu_capture","未按宋江退守、林冲拦截、花荣掩护的阵势生擒")
	b.mission.begin("zhu_second_free","第二打·自行接战","扈家援军已经接战。任何好汉都可制服扈三娘；林冲按原阵势生擒并押送才计演义印。")
	for actor in [lin,hua]:
		if is_instance_valid(actor): actor.passive = false; actor.stance = Unit.STANCE_AGGRO
	if is_instance_valid(song): song.stance = Unit.STANCE_HOLD
	if is_instance_valid(hu):
		hu.passive = false; hu.stance = Unit.STANCE_AGGRO
		var target = lin if is_instance_valid(lin) and lin.hp > 0.0 else (song if is_instance_valid(song) else null)
		if target != null: hu.order_attack(target)
	for guard in second_guards:
		if is_instance_valid(guard): guard.passive = false; guard.stance = Unit.STANCE_AGGRO
	for spear in second_spears:
		if is_instance_valid(spear): spear.passive = false; spear.stance = Unit.STANCE_DEFEND

func _second_free_tick(b) -> void:
	if stage == "second" and not b.mission.has_event("zhu_second_formation") and not free_second_fight:
		for actor in _living_liang(b):
			if is_instance_valid(hu) and (hu.hp < hu.max_hp or actor.position.distance_to(hu.position) <= 88.0):
				_start_second_free_fight(b)
				break
	elif stage == "send_hu" and b.mission.active_action_id == "":
		for actor in _living_liang(b):
			if actor.position.distance_to(b.map.cell_to_world(SECOND_HANDOFF)) <= 64.0:
				b.mission.mark("zhu_hu_secured_free","扈三娘作为俘将交给营中军士，未完成林冲同行押送")
				_miss_story(b,"zhu_capture","未由林冲同行押送并当面交接")
				if is_instance_valid(hu): hu.hide()
				stage = "transition"
				_third_day.call_deferred(b)
				break

func _start_third_free_assault(b) -> void:
	if stage != "infiltrate" or free_third_assault: return
	free_third_assault = true
	assault_started = true
	stage = "assault"
	b.mission.mark("zhu_gate_breached","梁山改从庄门强攻，放弃孙立等人内应、孙新换旗的章法")
	_miss_story(b,"zhu_inside","没有完成孙立入庄、邹渊邹润救囚、孙新换旗后再发总攻")
	b.mission.begin("zhu_assault_free","第三打·强攻破庄","庄门可以正面攻破，囚车也可由到场好汉打开。击溃祝氏主力并控制内院即可取胜。")
	if is_instance_valid(gate): gate._shield = 0.0
	for key in ["zhu_long","zhu_hu","zhu_biao","luan_tingyu"]:
		var foe = b.find_unit(key)
		if foe != null:
			foe._shield = 0.0
			foe.passive = false
			foe.stance = Unit.STANCE_AGGRO
	for actor in _living_liang(b):
		actor.passive = false
		actor.stance = Unit.STANCE_DEFEND

func _third_free_tick(b) -> void:
	if stage == "infiltrate" and not free_third_assault:
		# A right-click on the enemy gate is a tactical choice, even if the attacker
		# cannot stand within the gate centre's 58px radius because the building
		# footprint and weapon reach stop it outside.  Only a player-stamped attack
		# target qualifies; scripted combat cannot silently discard the inside route.
		for actor in _living_liang(b):
			if (actor.manual_order_active or actor.manual_order_t > 0.0) and actor._target == gate:
				_start_third_free_assault(b)
				return
	if stage == "infiltrate" and not free_third_assault and b.mission.active_action_id != "zhu_enter_manor":
		for actor in _living_liang(b):
			if actor.position.distance_to(b.map.cell_to_world(GATE_CELL)) <= 58.0:
				_start_third_free_assault(b)
				break
	if stage != "assault" or not free_third_assault or b.mission.has_event("zhu_prisoners_freed"): return
	for actor in _living_liang(b):
		if actor.position.distance_to(b.map.cell_to_world(PRISON_CELL+Vector2i(2,0))) > 80.0: continue
		prisoner_groups = [prisoners.slice(0,4),prisoners.slice(4,7)]
		for captive in prisoners:
			if is_instance_valid(captive) and captive.hp > 0.0:
				_release_captive(captive)
				captive.order_hold_position()
		b.mission.mark("zhu_prisoners_freed","%s强开囚车，七名好汉获得自由"%actor.display_name)
		break

func _role_at(b, actor, cell: Vector2i, radius := 52.0) -> bool:
	return is_instance_valid(actor) and actor.hp > 0.0 and actor.story_outcome == "" \
		and actor.position.distance_to(b.map.cell_to_world(cell)) <= radius \
		and b.map._segment_open(actor.position,b.map.cell_to_world(cell),actor.movement_profile)

func _try_begin_second_fight(b) -> void:
	if stage != "second": return
	for event_id in ["zhu_song_safe","zhu_lin_intercept","zhu_hua_cover"]:
		if not b.mission.has_event(event_id): return
	var missing: Array[String] = []
	if not _role_at(b,song,SECOND_SONG_SAFE): missing.append("zhu_song_safe")
	if not _role_at(b,lin,SECOND_LIN_INTERCEPT): missing.append("zhu_lin_intercept")
	if not _role_at(b,hua,SECOND_HUA_COVER): missing.append("zhu_hua_cover")
	if not missing.is_empty():
		for action_id in missing: _retry_action(b,action_id,"")
		b.mission.set_objective("阵形尚未站稳。宋江退到东侧，林冲截在扈三娘来路，花荣留在后方掩护；离位者可重新办理。")
		return
	b.mission.mark("zhu_second_formation","宋江退路、林冲拦截与花荣弓箭掩护三处同时就位")
	b.mission.begin("zhu_second_fight","第二打·拦截擒将","阵形已成：宋江守在安全处；林冲正面截住扈三娘，花荣留在后方以弓箭掩护；枪兵分头挡住两名庄客。")
	song.passive = true
	song.stance = Unit.STANCE_HOLD
	song.order_hold_position()
	lin.passive = false
	lin.stance = Unit.STANCE_AGGRO
	hua.passive = false
	hua.stance = Unit.STANCE_HOLD
	hua.order_hold_position()
	hu.passive = false
	hu.stance = Unit.STANCE_AGGRO
	hu.order_attack(lin)
	for i in range(second_guards.size()):
		if not is_instance_valid(second_guards[i]): continue
		var guard: Unit = second_guards[i]
		guard.passive = false
		guard.stance = Unit.STANCE_AGGRO
		if not second_spears.is_empty(): guard.order_attack(second_spears[i % second_spears.size()])
	for i in range(second_spears.size()):
		if not is_instance_valid(second_spears[i]): continue
		var spear: Unit = second_spears[i]
		spear.passive = false
		spear.stance = Unit.STANCE_DEFEND
	b.mission.set_status("扈家援军开始进攻。林冲、花荣和枪兵已交还玩家控制，请自行迎击并保护宋江。")

func _second_capture_ready(b) -> bool:
	return b.mission.has_event("zhu_second_formation") and _role_at(b,song,SECOND_SONG_SAFE,88.0) \
		and is_instance_valid(lin) and lin.hp > 0.0 and lin.story_outcome == "" \
		and is_instance_valid(hua) and hua.hp > 0.0 and hua.story_outcome == "" \
		and lin.position.distance_to(hu.position) <= 112.0 \
		and hua.position.distance_to(b.map.cell_to_world(SECOND_HUA_COVER)) <= 104.0

func _escort_hu_tick(b) -> void:
	if stage != "send_hu": return
	if not is_instance_valid(lin) or not is_instance_valid(hu) or hu.story_outcome != "captured": return
	var trail := hu.position - lin.position
	if trail.length_squared() < 1.0: trail = Vector2(-1,0)
	var candidate := lin.position + trail.normalized() * 34.0
	if not b.map.is_open_world(candidate,"land"): candidate = lin.position
	hu.position = candidate
	hu.show()
	b.map.sync_render_position(hu)
	hu.queue_redraw()

func _escort_pair_at_handoff(b) -> bool:
	var handoff: Vector2 = b.map.cell_to_world(SECOND_HANDOFF)
	return is_instance_valid(lin) and lin.hp > 0.0 and lin.story_outcome == "" \
		and is_instance_valid(hu) and hu.hp > 0.0 and hu.story_outcome == "captured" and hu.visible \
		and lin.position.distance_to(handoff) <= 56.0 and hu.position.distance_to(handoff) <= 80.0 \
		and lin.position.distance_to(hu.position) <= 72.0

func _group_at_rally(b, group: Array, rally: Vector2i) -> bool:
	if group.is_empty(): return false
	var center: Vector2 = b.map.cell_to_world(rally)
	for u in group:
		if not is_instance_valid(u) or u.hp <= 0.0 or u.story_outcome != "" or u.is_captive or u.position.distance_to(center) > 94.0:
			return false
	return true

func _prisoner_groups_tick(b) -> void:
	if stage != "inside" or not b.mission.has_event("zhu_prisoners_freed") or prisoner_groups.size() != 2: return
	for group_index in range(2):
		var event_id := "zhu_prison_group_%s_safe" % ("a" if group_index == 0 else "b")
		var rally: Vector2i = PRISON_RALLY_A if group_index == 0 else PRISON_RALLY_B
		var group: Array = prisoner_groups[group_index]
		if not b.mission.has_event(event_id) and _group_at_rally(b,group,rally):
			for u in group: u.order_hold_position()
			b.mission.mark(event_id,"获救好汉第%d队已经退到内院" % (group_index+1))
			_refresh_third_objective(b)

func _third_signal_ready(b) -> bool:
	return b.mission.has_event("zhu_gate_opened") and b.mission.has_event("zhu_inner_support_ready") \
		and b.mission.has_event("zhu_outer_ready") and b.mission.has_event("zhu_prison_group_a_safe") \
		and b.mission.has_event("zhu_prison_group_b_safe") and _role_at(b,sun,INNER_GATE_SUPPORT,80.0) \
		and _role_at(b,song,OUTER_RALLY,72.0) and prisoner_groups.size() == 2 \
		and _group_at_rally(b,prisoner_groups[0],PRISON_RALLY_A) and _group_at_rally(b,prisoner_groups[1],PRISON_RALLY_B)

func _restore_third_role_actions(b) -> void:
	if not _role_at(b,sun,INNER_GATE_SUPPORT,80.0): _retry_action(b,"zhu_inner_support","")
	if not _role_at(b,song,OUTER_RALLY,72.0): _retry_action(b,"zhu_outer_position","")

func _refresh_third_objective(b) -> void:
	if stage != "inside": return
	var statuses := [
		"顾大嫂策应救囚%s" % ("已办" if b.mission.has_event("zhu_prisoners_freed") else "未办"),
		"孙立吊桥内侧%s" % ("就位" if b.mission.has_event("zhu_inner_support_ready") else "未就位"),
		"宋江门外%s" % ("就位" if b.mission.has_event("zhu_outer_ready") else "未就位"),
		"第一队%s" % ("到内院" if b.mission.has_event("zhu_prison_group_a_safe") else "撤离中"),
		"第二队%s" % ("到内院" if b.mission.has_event("zhu_prison_group_b_safe") else "撤离中"),
		"庄门%s" % ("已开" if b.mission.has_event("zhu_gate_opened") else "仍闭")]
	b.mission.set_objective("；".join(statuses)+"。开门不等于总攻，内外俱备后由宋江发令。")

func _begin_third_assault(b) -> void:
	stage = "assault"
	assault_started = true
	b.mission.begin("zhu_assault","第三打·里应外合","两队获救好汉留在内院，孙立等内应从门内接应，宋江所部由门外攻入；保护七名好汉，合击祝氏主力。")
	song.passive = false
	song.stance = Unit.STANCE_DEFEND
	for group in prisoner_groups:
		for captive in group:
			if is_instance_valid(captive): captive.order_hold_position()
	for u in b.units_of(Unit.FACTION_GUAN):
		if not u.is_building:
			u.passive = false
			u.stance = Unit.STANCE_AGGRO
			u.order_amove(b.map.cell_to_world(Vector2i(26,28)))
	for key in ["zhu_long","zhu_hu","zhu_biao","luan_tingyu"]:
		var foe = b.find_unit(key)
		if foe != null: foe._shield = 0.0
	b.mission.set_status("庄军已经向门楼反扑。外军、内应和获救好汉均由玩家指挥；可分兵守牢、抢门或合击敌将。")

func _clear_section(b) -> void:
	b.clear_campaign_section()
	prisoners.clear()
	prisoner_groups.clear()
	second_guards.clear()
	second_spears.clear()
	shi = null
	song = null
	lin = null
	hua = null
	hu = null
	sun = null
	gu = null
	gate = null
	assault_started = false
func _second_day(b) -> void:
	_clear_section(b)
	stage = "second"
	free_second_fight = false
	song = b.spawn_at("song_jiang",Unit.FACTION_LIANG,DEPLOY_CELL)
	lin = b.spawn_at("lin_chong",Unit.FACTION_LIANG,Vector2i(42,21))
	hua = b.spawn_at("hua_rong",Unit.FACTION_LIANG,Vector2i(43,22))
	for c in [Vector2i(41,21),Vector2i(42,23),Vector2i(44,22),Vector2i(43,24)]:
		var spear: Unit = b.spawn_at("liang_qiang",Unit.FACTION_LIANG,c)
		spear.order_stop()
		spear.passive = true
		spear.stance = Unit.STANCE_PASSIVE
		second_spears.append(spear)
	hu = b.spawn_at("hu_sanniang",Unit.FACTION_GUAN,HU_CELL)
	hu.defeat_outcome = "captured"
	hu.passive = true
	hu.stance = Unit.STANCE_PASSIVE
	hu.order_hold_position()
	for c in [Vector2i(39,15),Vector2i(41,15)]:
		var guard: Unit = b.spawn_at("zhu_keke",Unit.FACTION_GUAN,c)
		guard.passive = true
		guard.stance = Unit.STANCE_PASSIVE
		guard.order_hold_position()
		second_guards.append(guard)
	for actor in [song,lin,hua]:
		actor.passive = true
		actor.stance = Unit.STANCE_PASSIVE
	gate = b.spawn_at("zhu_gate",Unit.FACTION_GUAN,GATE_CELL)
	_configure_gate_environment(gate)
	gate.defeat_outcome = "subdued"
	gate.apply_shield(100000.0,99999.0)
	b.mission.begin("zhu_second","第二打·分守三处","先让宋江退守东侧安全处，林冲到扈三娘来路正面拦截，花荣留在后方弓箭掩护。三处同时站稳后再交战。")
	b.mission.add_action("zhu_song_safe","宋江：退到东侧安全处",SECOND_SONG_SAFE,["song_jiang"],1.2,40.0)
	b.mission.add_action("zhu_lin_intercept","林冲：抢占正面拦截位",SECOND_LIN_INTERCEPT,["lin_chong"],1.2,40.0)
	b.mission.add_action("zhu_hua_cover","花荣：留后张弓掩护",SECOND_HUA_COVER,["hua_rong"],1.2,40.0)
	b.msg("【再战祝家庄】扈三娘引庄客来援。林冲上前迎住，众军保护宋江！",6.0)

func _third_day(b) -> void:
	_clear_section(b)
	stage = "infiltrate"
	free_third_assault = false
	song = b.spawn_at("song_jiang",Unit.FACTION_LIANG,Vector2i(27,28))
	for spec in [["lin_chong",Vector2i(28,27)],["hua_rong",Vector2i(29,29)],["mu_hong",Vector2i(29,27)]]:
		b.spawn_at(spec[0],Unit.FACTION_LIANG,spec[1])
	for i in range(8):
		b.spawn_at("liang_qiang" if i%2==0 else "liang_gong",Unit.FACTION_LIANG,Vector2i(26+i%4,30+i/4))
	sun = b.spawn_at("sun_li",Unit.FACTION_LIANG,Vector2i(26,26))
	gu = b.spawn_at("gu_dasao",Unit.FACTION_LIANG,Vector2i(26,27))
	sun.stance = Unit.STANCE_PASSIVE
	gu.stance = Unit.STANCE_PASSIVE
	for spec in [["shi_xiu",Vector2i(11,33)],["shi_qian",Vector2i(12,34)],["qin_ming",Vector2i(10,33)],["yang_lin",Vector2i(12,33)],["huang_xin",Vector2i(13,34)],["wang_ying",Vector2i(12,35)],["deng_fei",Vector2i(14,34)]]:
		var u = b.spawn_at(spec[0],Unit.FACTION_LIANG,spec[1])
		_bind_captive(u)
		prisoners.append(u)
	prisoner_groups.clear()
	gate = b.spawn_at("zhu_gate",Unit.FACTION_GUAN,GATE_CELL)
	_configure_gate_environment(gate)
	gate.defeat_outcome = "subdued"
	gate.apply_shield(100000.0,99999.0)
	for spec in [["zhu_long",Vector2i(36,24)],["zhu_hu",Vector2i(36,32)],["zhu_biao",Vector2i(40,28)],["luan_tingyu",Vector2i(42,31)]]:
		var u = b.spawn_at(spec[0],Unit.FACTION_GUAN,spec[1])
		u.passive = true
		u.stance = Unit.STANCE_PASSIVE
		u.apply_shield(100000.0,99999.0)
	for c in [Vector2i(10,31),Vector2i(13,34),Vector2i(18,26),Vector2i(18,30)]:
		var u = b.spawn_at("zhu_keke",Unit.FACTION_GUAN,c)
		u.order_hold_position()
	b.mission.begin("zhu_infiltrate","数日后·孙立投庄","孙立到庄门报明来意，借与栾廷玉同师学艺的交情入庄。外军暂守庄外，等邹渊、邹润救囚，孙新换旗。")
	# Keep the admission spot precise.  With the old default 96px reach, Sun Li
	# already stood inside its trigger radius; a player's explicit attack order on
	# the nearby manor gate could therefore be consumed as "report identity" before
	# the unit took a step.  A real move to the marker still works, while an attack
	# order now remains distinguishable as the free-assault choice.
	b.mission.add_action("zhu_enter_manor","孙立：报明身份入庄",Vector2i(24,28),["sun_li"],3.0,40.0)
	b.msg("【数日后·孙立来投】孙立把旗号改作“登州兵马提辖孙立”，假称调任途经此地，来访同门栾廷玉。庄外人马隐住旗号，等候接应。",7.0)


func _configure_gate_environment(target: Unit) -> void:
	if target==null: return
	target.set_meta("campaign_environment_route","zhujiazhuang_main_gate")
	target.set_meta("campaign_environment_state","default")

func _bind_captive(u: Unit) -> void:
	u.is_captive = true
	u.is_noncombat = true
	u.passive = true
	u.stance = Unit.STANCE_PASSIVE
	u.set_meta("free_speed",u.base_speed)
	u.set_meta("free_atk",u.atk)
	u.base_speed = 0.0
	u.atk = 0.0
	u.ability = ""
	u.ability_slots.clear()
	u.art_variant = "bound_"+u.key

func _release_captive(u: Unit) -> void:
	u.is_captive = false
	u.is_noncombat = false
	u.passive = true
	u.stance = Unit.STANCE_PASSIVE
	u.base_speed = float(u.get_meta("free_speed",75.0))
	u.atk = float(u.get_meta("free_atk",20.0))
	u.art_variant = ""
	u.queue_redraw()

func on_unit_resolved(b, u, outcome: String) -> void:
	if u == hu and outcome == "captured" and stage == "second":
		if not _second_capture_ready(b):
			b.mission.mark("zhu_hu_captured","扈三娘在乱军中被生擒，仍作为敌将看押")
			_miss_story(b,"zhu_capture","扈三娘虽被擒，但没有完成林冲三处分守的阵前生擒")
			for guard in second_guards:
				if is_instance_valid(guard) and guard.story_outcome == "": guard.resolve_story("retreated")
			if is_instance_valid(hu): hu.hide()
			stage = "transition"
			_third_day.call_deferred(b)
			return
		b.mission.mark("zhu_hu_captured","林冲军前擒住扈三娘")
		for guard in second_guards:
			if is_instance_valid(guard) and guard.story_outcome == "": guard.resolve_story("retreated")
		for ally in second_spears + [lin,hua,song]:
			if is_instance_valid(ally): ally.order_stop()
		hu.show()
		stage = "send_hu"
		b.mission.begin("zhu_send_hu","第二打·押送回营","扈三娘仍是被擒敌将，不归我方作战。让林冲亲自押她走到营前，再当面交给留守军士。")
		b.mission.add_action("zhu_escort_hu","林冲：押扈三娘到营前",SECOND_HANDOFF,["lin_chong"],2.0,40.0)
	elif u == gate and outcome in ["subdued","retreated"] and stage == "assault" and free_third_assault:
		b.unregister_building_footprint(gate)
		gate.visible = false
		b.mission.mark("zhu_gate_breached","庄门被正面攻破，外军涌入庄内")
		_miss_story(b,"zhu_inside","庄门由强攻攻破，没有完成孙立内应、孙新换旗")

func on_unit_died(b, u) -> void:
	if u == song:
		b.lose("宋江阵亡，三次攻庄失去统领。")
	elif u in prisoners:
		b.mission.mark("zhu_prisoner_lost","被囚好汉有人未能生还")
		_miss_story(b,"zhu_seven","七名被囚好汉没有全部生还")
	elif u == shi:
		_miss_story(b,"zhu_poplar","石秀未能完成白杨认路")
		if stage == "withdraw" and free_scout == null:
			# The route information is no longer canonical, but any survivor may still
			# carry the reconnaissance back and preserve the three-day campaign flow.
			free_scout = u
	elif u == lin or u == hua:
		_miss_story(b,"zhu_capture","阵前生擒所需好汉未能完成任务")
	elif u == sun or u == gu:
		_miss_story(b,"zhu_inside","内应人物未能完成入庄救囚")

func process(b, delta: float) -> void:
	if stage == "transition": return
	_free_scout_tick(b)
	_second_free_tick(b)
	_third_free_tick(b)
	if stage == "send_hu": _escort_hu_tick(b)
	if stage == "inside": _prisoner_groups_tick(b)
	if stage == "assault" and assault_started:
		var remaining := 0
		for key in ["zhu_long","zhu_hu","zhu_biao","luan_tingyu"]:
			if b.hero_alive(key): remaining += 1
		var gate_down := not is_instance_valid(gate) or gate.story_outcome != "" or not gate.visible
		if remaining == 0 and gate_down:
			b.mission.mark("zhu_victory","内外夹攻，祝家庄失守，囚犯获救")
			var seven_safe := prisoners.size() == 7 and prisoners.all(func(captive): return is_instance_valid(captive) and captive.hp > 0.0 and not captive.is_captive)
			if seven_safe:
				b.mission.mark("zhu_seven_safe","七名被囚好汉全部获救生还")
				_complete_story(b,"zhu_seven","七名被囚好汉全部获救生还")
			var authored: bool = b.mission.has_event("zhu_assault_ordered") and b.mission.has_event("zhu_gate_opened")
			if authored:
				b.win("庄内换旗，庄外合击，祝家庄终于告破。获救者随军回山，扈三娘仍以俘将身份看押。")
			else:
				b.win("梁山人马攻破庄门，击溃祝氏主力，占领祝家庄。原著内应章法未必完成，以本局战报为准。")
			return
	if b.players_alive() == 0: b.lose("出战人马尽失，此番攻庄失败。")
	if b._smoke: _smoke_drive(b,delta)

func on_ability(b, _caster, aid: String, _lp: Vector2) -> bool:
	if aid != "shi_xiu_path": return false
	if not b.mission.has_event("zhu_route_known"):
		b.msg("还未辨明白杨记号。先完成认路，才能标出已探明的路线。",3.0)
		return true
	_light_route(b)
	return true

func _light_route(b) -> void:
	# Never reveal unvisited turns or the interior path, even through Shi Xiu's route skill.
	var known_segments := 5 if b.mission.has_event("zhu_gate_scouted") else (3 if b.mission.has_event("zhu_route_known") else 0)
	for i in range(known_segments):
		var a := SAFE_NODES[i]
		var c := SAFE_NODES[i+1]
		var n := maxi(absi(c.x-a.x),absi(c.y-a.y))
		for j in range(n+1):
			var p := Vector2(a).lerp(Vector2(c),float(j)/maxf(n,1))
			b.lit_cells[Vector2i(roundi(p.x),roundi(p.y))] = 999.0

func top_status(_b) -> String:
	return "三打祝家庄 | %s | 保全领军好汉" % {"scout":"辨认白杨","withdraw":"脱围回营","second":"分位擒将","send_hu":"同行押送","hu_handoff":"营前交接","transition":"数日后","infiltrate":"报明身份入庄","inside":"内外分工","assault":"里应外合"}.get(stage,stage)

func _smoke_drive(b, delta: float) -> void:
	smoke_t -= delta
	if smoke_t > 0.0: return
	smoke_t = 1.5
	# SMOKE 只负责自动回归。正式玩法中的两队获救者必须由玩家分别编队撤离。
	if stage == "inside" and b.mission.has_event("zhu_prisoners_freed") and prisoner_groups.size() == 2:
		for group_index in range(2):
			var event_id := "zhu_prison_group_%s_safe" % ("a" if group_index == 0 else "b")
			if b.mission.has_event(event_id): continue
			var rally: Vector2i = PRISON_RALLY_A if group_index == 0 else PRISON_RALLY_B
			var rally_world: Vector2 = b.map.cell_to_world(rally)
			var group: Array = prisoner_groups[group_index]
			for member_index in range(group.size()):
				var member: Unit = group[member_index]
				if is_instance_valid(member) and member.hp > 0.0 and member.story_outcome == "":
					member.order_move(rally_world + Vector2((member_index % 2) * 20.0, (member_index / 2) * 20.0))
	if stage in ["scout","withdraw","send_hu","hu_handoff","infiltrate","inside"]:
		_smoke_action(b)
	elif stage == "second":
		if not b.mission.has_event("zhu_second_formation"):
			_smoke_action(b)
		elif is_instance_valid(hu) and hu.story_outcome == "":
			song.order_move(b.map.cell_to_world(SECOND_SONG_SAFE))
			lin.order_attack(hu)
			hua.order_hold_position()
			for i in range(second_spears.size()):
				var spear: Unit = second_spears[i]
				if not is_instance_valid(spear): continue
				var guard: Unit = null
				if not second_guards.is_empty() and is_instance_valid(second_guards[i % second_guards.size()]):
					guard = second_guards[i % second_guards.size()]
				if is_instance_valid(guard) and guard.story_outcome == "": spear.order_attack(guard)
	elif stage == "assault":
		for u in b.units_of(Unit.FACTION_LIANG):
			if u == song or u.is_captive or u in prisoners: continue
			var target: Unit = null
			var distance := INF
			for foe in b.units_of(Unit.FACTION_GUAN):
				if foe.is_building or foe.story_outcome != "": continue
				var d: float = u.position.distance_to(foe.position)
				if d < distance:
					target = foe
					distance = d
			if not is_instance_valid(target): continue
			u.order_attack(target)
			for slot in range(u.slot_count()):
				if not u.slot_ready(slot): continue
				var aid: String = u.ability_slots[slot]["id"]
				var ad: Dictionary = b._abilities.get(aid,{})
				if bool(ad.get("passive",false)): continue
				# SMOKE 是自动回归驾驶，不得走会盖“玩家改令”戳的公开输入入口。
				# 直接调用 AI 施法守卫；单体友军技以自身为目标，敌军技才指向当前敌人。
				var cast_target: Unit = null
				var cast_pos: Vector2 = u.position
				if bool(ad.get("targeted", false)):
					if String(ad.get("target", "point")) == "unit":
						cast_target = u if String(ad.get("unit_team", "enemy")) == "ally" else target
						cast_pos = cast_target.position if is_instance_valid(cast_target) else target.position
					else:
						cast_pos = target.position
				b._ai_cast_slot(u, slot, cast_pos, cast_target)
				break

func _smoke_action(b) -> void:
	if b.mission.active_action_id != "": return
	var action_id := ""
	match stage:
		"scout": action_id = "zhu_recon_gate" if b.mission.has_event("zhu_route_known") else "zhu_white_poplar"
		"withdraw": action_id = "zhu_return"
		"send_hu": action_id = "zhu_escort_hu"
		"hu_handoff": action_id = "zhu_hu_handoff"
		"infiltrate": action_id = "zhu_enter_manor"
		"second":
			for candidate in ["zhu_song_safe","zhu_lin_intercept","zhu_hua_cover"]:
				if b.mission.request_action(candidate): return
		"inside":
			for candidate in ["zhu_free_prisoners","zhu_inner_support","zhu_outer_position","zhu_open_gate","zhu_attack_signal"]:
				if b.mission.request_action(candidate): return
	if action_id != "": b.mission.request_action(action_id)
