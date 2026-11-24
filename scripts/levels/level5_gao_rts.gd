extends LevelBase
## Three finite expeditions on one persistent camp, shore and water network.
## Shared land combat and paid ship production; story actions only add options.
const T := GameMap.T
const Naval := preload("res://scripts/naval_production.gd")
const Layout := preload("res://scripts/liangshan_layout.gd")
const HALL := Vector2i(18,30)
const YARD_SITE := Vector2i(27,46)
const LAND_POST := Vector2i(26,7)
const SEA_POST := Vector2i(55,34)
const LAND_FRONT := Vector2i(34,31)
const SEA_FRONT := Vector2i(39,44)
const CHAIN_FRONT := [Vector2i(40,43),Vector2i(44,43),Vector2i(40,45),Vector2i(44,45),Vector2i(42,44)]
const LANDING := Vector2i(20,49)
const LANDING_WATER := Vector2i(22,52)
const LIU_RETURN := Vector2i(20,52) # Separate from the prisoner handover marker.
const WIND := Vector2i(29,38)
# The inner approach must reach the incoming chain ships before they can
# hold the fireboat at cannon range from the west side of the channel.
const FIRE_POINTS := [Vector2i(42,29),Vector2i(40,40)]
# Match the chained warship's 180 range plus both 25-pixel hull radii.
# The same radius is used for readiness and actual fire damage.
const FIRE_ZONE_RADIUS := 230.0
const PRISONER_ESCORT_RADIUS := 180.0
const SHORE_ESCORT_SPACING := 104.0
const PRISONER_WAITING := "高俅正在等待岸军护卫。已下达的行军命令会保留。"
const PRISONER_HANDOVER := HALL + Vector2i(0,4)
const ESCORT_PROMPT := "高俅已上岸。点击「押送高俅回堂」调附近的一名空闲岸军同行，也可自行指挥。"
const FIRE_SAFE := Vector2i(32,50)
const FIRE_WITHDRAW_SLOTS := [Vector2i(-1, -1), Vector2i(0, 1)]
const WITHDRAW_ESCORT_SHIPS := "gao_withdraw_escort_ships"
const RETURN_LIU_TANG := "gao_return_liu_tang"
const WITHDRAW_ACTION := "gao_fire_withdraw"
const RETURN_ACTION := "gao_liu_return"
const WITHDRAW_PROMPT := "火船已点燃。点「撤出接应船」让两船驶向安全水域；附近有官船时，先压退追兵。"
const RETURN_PROMPT := "双船已撤离。可点「送刘唐返港」，让载他的原船回主码头。"
const SHIP_KEYS := ["ruan_xiaoqi_boat","ruan_xiaoer_boat","ruan_xiaowu_boat","zhang_shun_boat","liangshan_warship"]
const OPENING_OBJECTIVE := "首批约140秒出发，后两批约330与540秒。岸军防东山关、舰队守内港；可出击拆两处补给，也可经营补兵接战。"
var hall: Unit
var song: Unit
var flagship: Unit
var fireboat: Unit
var embarked_liu: Unit
var liu_carrier: Unit
var prisoner: Unit
var carrier: Unit
var workers: Array[Unit]=[]
var posts: Array[Unit]=[]
var water_groups: Array=[]
var land_groups: Array=[]
var support: Array[Unit]=[]
var waves := [{"time":140.0,"sent":false,"warned":false},{"time":330.0,"sent":false,"warned":false},{"time":540.0,"sent":false,"warned":false}]
var elapsed := 0.0
var strategy_t := 0.0
var production_t := [95.0,140.0]
var produced := [0,0]
var ai_spent_gold := 0
var ai_spent_wood := 0
var lure_started := false
var lure_cell := Vector2i(39,41)
var fire_prepared := false
var fire_lit := false
var fire_abandoned := false
var port_sealed := false
var flagship_disabled := false
var recovered := false
var landed := false
var capture_lost := false
var core_ready := false
var end_button: Button
var escort_warning := false

func id() -> String: return "level5"
func title() -> String: return "三败高太尉"
func subtitle() -> String: return "经营水寨·水陆断援·火攻擒将"
func economy_enabled() -> bool: return true
func start_gold() -> int: return 350
func start_wood() -> int: return 260
func base_pop_cap() -> int: return 44
func start_age() -> int: return 3
func hero_start_rank() -> int: return 0
func hero_cap() -> int: return 5
func fog_enabled() -> bool: return true
func map_w() -> int: return 60
func map_h() -> int: return 60
func map_base() -> int: return T.WATER
func camera_start_cell() -> Vector2i: return Vector2i(23,37)
func campaign_core_goal() -> String:
	return "守住忠义堂和宋江，击退三批水陆主力，打停高俅座船。可直接收兵通关；生擒并押回堂前是可选演义目标。"
func story_contract_version() -> int: return 3
func campaign_story_goals() -> Array:
	return [
		{"id":"gao_lure","label":"阮小七引活官船进入港汊伏区","required_events":["fleet_in_ambush"]},
		{"id":"gao_fire","label":"公孙胜祭风、刘唐登船举火，护两艘接应船撤离","required_events":["gongsun_wind","liu_tang_fire_leader","fireboat_prepared","fire_escort_safe"]},
		{"id":"gao_land","label":"击退岸军并拔除山前补给营","required_events":["gao_land_cleared","gao_land_post_destroyed"]},
		{"id":"gao_capture","label":"封港凿船、水上接俘、返航后实际押至忠义堂","required_events":["port_sealed","flagship_scuttled","gao_landed","gao_captured"],"forbidden_events":["gao_escaped"]},
	]
func deploy_hint() -> String:
	return "营寨和军队全程保留。工匠采金伐木，兵营练枪弓，南侧开阔岸地可建船坞。陆军走东山关外山路，船只走港水；拆北岸营断陆援，舰队拆东岸船坞断海援。三批主力已经在地图上，可侦察、截击，不必坐等。"
func intro_lines() -> Array:
	var lines := [
		{"who":"旁白","key":"narrator","text":"童贯败归，高俅调水陆军征讨梁山。三次进兵压缩在同一战场：水寨、港汊和山前道路始终保留，官军各部已在远处集结。"},
		{"who":"吴用","key":"wu_yong","text":"钱粮要分给岸军和水军。先造船坞留补船余地；北岸营与东岸船坞各有补充，拆掉便断一路。英雄留在岸上指挥，外港仍须战船争夺。"},
		{"who":"刘唐","key":"liu_tang","text":"也可走火攻：公孙先生祭风，我到主码头备火登船。把两艘阮氏接应船护在旁边，等连船进入火点再举火。"},
		{"who":"宋江","key":"song_jiang","text":"打停座船即可收兵。若要生擒，先封港，再让张顺凿船接俘，沿水道返航，岸军亲自押他到忠义堂。"},
	]
	if OS.get_name() == "Windows" and Campaign.has_jiangzhou_rescue_record(Campaign.level_record("level2")):
		lines.insert(1, {"who":"宋江", "key":"song_jiang", "text":"江州那回，大伙在白龙庙会齐，一个也没落下。今日仍照那回分工，护住每艘接应船。"})
	return lines
func apply_overrides(defs: Dictionary,abilities: Dictionary) -> void:
	load("res://scripts/levels/level5_liangshan.gd").new().apply_overrides(defs,abilities)
	Naval.configure(defs)
	defs.hall.produces=["lou_luo","song_jiang","wu_yong","gongsun_sheng","liu_tang","lin_chong"]
	for key in SHIP_KEYS: defs[key].pop=3
	defs.liu_tang_fireboat.pop=0 # The embarked hero is represented by this one authored boat.
	defs.liu_tang_fireboat.atk=0
	defs.liu_tang_fireboat.name="待装火具小船"
func paint_map(map: GameMap) -> void:
	load("res://scripts/levels/skirmish.gd").new().paint_map(map)
	map.set_meta("liangshan_hall_cell",HALL)
	# Northern land road skirts the east wall; never paints a hidden hole in it.
	Layout.paint(map)
	map.fill_rect(22,3,10,10,T.GRASS)
	map.paint_path([Vector2(LAND_POST),Vector2(30,14),Vector2(35,19),Vector2(35,31),Vector2(Layout.RTS_EAST_GATE)],1,T.ROAD)
	map.fill_rect(39,1,15,29,T.WATER)
	map.fill_rect(39,29,14,25,T.WATER)
	map.paint_path([Vector2(42,33),Vector2(37,37),Vector2(37,42),Vector2(40,44)],1,T.WATER)
	map.fill_rect(20,51,25,4,T.WATER)
	# Dedicated buildable shore beside, not on top of, the static main pier.
	map.paint_path([Vector2(18,45),Vector2(27,45)],1,T.ROAD)
	map.fill_rect(24,44,7,4,T.GRASS)
	map.fill_rect(23,48,10,7,T.WATER)
	map.fill_rect(54,31,5,8,T.GRASS)
	map.fill_rect(50,30,4,10,T.WATER)
	map.fill_rect(7,29,7,12,T.GRASS)
	map.fill_rect(33,26,5,8,T.GRASS)
	map.paint_path([Vector2(35,19),Vector2(LAND_FRONT),Vector2(Layout.RTS_EAST_GATE)],1,T.ROAD)
	map.fill_rect(HALL.x-1,HALL.y-1,3,3,T.HALL)
func decorate(map: GameMap) -> void:
	load("res://scripts/levels/skirmish.gd").new().decorate(map)
	map.decor=map.decor.filter(func(d): return d[0]!="boat")
func alive(u) -> bool: return is_instance_valid(u) and u.hp>0 and u.story_outcome==""
func _count(group: Array) -> int: return group.filter(func(u): return alive(u)).size()
func _guard(b,key: String,cell: Vector2i,faction := 1) -> Unit:
	var u: Unit=b.spawn_at(key,faction,cell)
	if u == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return null
	u.set_stance(Unit.STANCE_DEFEND)
	if u.movement_profile=="water":
		u.visual_scale=1.2
	return u
func _resource(b,key: String,cell: Vector2i,amount: float) -> void:
	var u: Unit=b.spawn_at(key,0,cell)
	if u == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	u.res_left=amount
func deploy(b) -> void:
	hall=b.spawn_at("hall",0,HALL)
	if hall == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	hall.display_name="忠义堂"
	for pair in [["campaign_environment_route","zhongyi_hall"],["campaign_environment_state","default"],["campaign_environment_text_surface_id","level5_hall_plaque"],["campaign_environment_runtime_text","忠义堂"],["campaign_environment_static_visual",true]]:
		hall.set_meta(pair[0],pair[1])
	var _created_entity_1: Unit = b.spawn_at("barracks",0,Vector2i(24,37))
	if _created_entity_1 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	song=b.spawn_at("song_jiang",0,Vector2i(20,34))
	if song == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	for record in [["wu_yong",Vector2i(22,34)],["gongsun_sheng",Vector2i(23,34)],["liu_tang",Vector2i(21,36)]]:
		var u: Unit=b.spawn_at(record[0],0,record[1])
		if u == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		u.set_stance(Unit.STANCE_DEFEND)
	for i in range(6):
		var _created_entity_2: Unit = b.spawn_at("lou_luo",0,Vector2i(10+i,31))
		if _created_entity_2 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		workers.append(_created_entity_2)
	for i in range(6):
		var _created_entity_3: Unit = _guard(b,"liang_qiang" if i<3 else "liang_gong",Vector2i(28+i%2,30+i/2),0)
		if _created_entity_3 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	for c in [Vector2i(9,35),Vector2i(12,35),Vector2i(11,39)]:
		_resource(b,"gold_mine",c,2600)
		if not b._gameplay_rng_issue.is_empty(): return
	for c in [Vector2i(8,28),Vector2i(10,26),Vector2i(13,25),Vector2i(8,40)]:
		_resource(b,"tree",c,1900)
		if not b._gameplay_rng_issue.is_empty(): return
	_resource(b,"gold_mine",Vector2i(29,4),4500)
	if not b._gameplay_rng_issue.is_empty(): return
	_resource(b,"tree",Vector2i(23,4),2500)
	if not b._gameplay_rng_issue.is_empty(): return
	for record in [["ruan_xiaoqi_boat",Vector2i(35,49)],["ruan_xiaoer_boat",Vector2i(38,47)],["ruan_xiaowu_boat",Vector2i(40,50)],["zhang_shun_boat",Vector2i(25,53)]]:
		var _created_entity_4: Unit = _guard(b,record[0],record[1],0)
		if _created_entity_4 == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
	fireboat=_guard(b,"liu_tang_fireboat",LANDING_WATER,0)
	if fireboat == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	fireboat.passive=true
	fireboat.set_stance(Unit.STANCE_PASSIVE)
	var _created_entity_5: Unit = b.spawn_at("barracks",1,LAND_POST)
	if _created_entity_5 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	var _created_entity_6: Unit = b.spawn_at("shipyard",1,SEA_POST)
	if _created_entity_6 == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	posts=[_created_entity_5,_created_entity_6]
	posts[0].display_name="山前补给营"
	posts[1].display_name="东岸官军船坞"
	for c in [Vector2i(23,10),Vector2i(30,9)]:
		var tower: Unit=b.spawn_at("arrow_tower",1,c)
		if tower == null:
			b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
			return
		tower.display_name="补给营护军箭楼"
	for wave in range(3):
		var water: Array=[]
		for i in range([3,5,6][wave]):
			var cell := Vector2i(43+i%2*3,23+i/2*3) if wave==0 else Vector2i(43+i%2*3,5+i/2*3) if wave==1 else Vector2i(50+i%2*2,15+i/2*3)
			var ship=_guard(b,"official_vanguard" if wave==2 and i==0 else "imperial_warship",cell)
			if ship == null:
				b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
				return
			ship.set_meta("gao_wave",wave)
			if wave==2 and i==0:
				ship.set_meta("campaign_flag_context","chapter80_vanguard_headship")
			water.append(ship)
		water_groups.append(water)
		var land: Array=[]
		for i in range([4,6,8][wave]):
			var key: String="guan_qi" if wave==2 and i<3 else "guan_gong" if i%3==2 else "guan_dao"
			var land_cell := Vector2i(34+i%2,24+i/2) if wave==0 else Vector2i(30+i%2,13+i/2) if wave==1 else Vector2i(23+i%3,3+i/3)
			var _created_entity_7: Unit = _guard(b,key,land_cell)
			if _created_entity_7 == null:
				b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
				return
			land.append(_created_entity_7)
		land_groups.append(land)
	flagship=_guard(b,"gao_flagship",Vector2i(51,5))
	if flagship == null:
		b._gameplay_rng_stop("ENTITY_REQUIRED_UNIT")
		return
	flagship.visual_scale=1.8
	flagship.defeat_outcome="subdued"
	flagship.set_meta("campaign_flag_context","chapter80_gao_flagship")
	Art.prefetch_gao_opening_art()

func on_start(b) -> void:
	b.faction_res[1]={"gold":560.0,"wood":400.0}
	for i in range(workers.size()):
		var node=b.nearest_free_gold(workers[i].position,null,workers[i]) if i<3 else b.nearest_resource(workers[i].position,"wood")
		if node!=null: workers[i].order_gather(node)
	b.mission.begin("gao_rts","经营水寨 · 分守水陆",OPENING_OBJECTIVE)
	b.mission.enable_scrolling()
	b.mission.add_map_locator("东山关防线",LAND_FRONT)
	b.mission.add_map_locator("内港接战线",SEA_FRONT)
	b.mission.add_map_locator("南岸建船坞",YARD_SITE)
	b.mission.add_map_locator("北岸补给营",LAND_POST)
	b.mission.add_map_locator("东岸官军船坞",SEA_POST)
	b.mission.add_action("gao_lure_main","阮小七：主港诱舰",Vector2i(42,31),["ruan_xiaoqi_boat"],1,64)
	b.mission.add_action("gao_lure_side","阮小七：侧汊诱舰",Vector2i(37,39),["ruan_xiaoqi_boat"],1,64)
	b.mission.add_action("gao_wind","公孙胜：祭风",WIND,["gongsun_sheng"],2,64)
	b.mission.add_actor_locator("gao_wind","gongsun_sheng")
	for cell in [YARD_SITE,LAND_POST,SEA_POST,LAND_FRONT,SEA_FRONT]: b.lit_cells[cell]=25.0
	b.msg("工匠已分采金木。南岸船坞100金100木，每艘战船90金65木、3人口；请留出下水口。先保住忠义堂与宋江。",10)
func _retry(b,key: String,text: String) -> void:
	var a: Dictionary=b.mission.actions[key]
	a.done=false
	if is_instance_valid(a.button): a.button.disabled=false
	a.marker.show()
	b.mission.set_status(text)
func _wave_has_force(index: int) -> bool:
	return water_groups[index].any(func(u): return alive(u)) or land_groups[index].any(func(u): return alive(u)) or (index==2 and alive(flagship))

func _send_wave(b,index: int) -> void:
	if waves[index].sent: return
	waves[index].sent=true
	if not _wave_has_force(index): return
	var guards := _flagship_guards() if index==2 else []
	for slot in range(water_groups[index].size()):
		var u: Unit=water_groups[index][slot]
		if not alive(u) or u in guards: continue
		var destination := lure_cell if index==0 and lure_started else SEA_FRONT
		if index==1 and slot<CHAIN_FRONT.size() and Naval.clear_water(b.map,CHAIN_FRONT[slot],u.radius):
			destination=CHAIN_FRONT[slot]
		u.set_stance(Unit.STANCE_AGGRO)
		u.order_amove(b.map.cell_to_world(destination))
	for u in land_groups[index]:
		if alive(u):
			u.order_amove(b.map.cell_to_world(LAND_FRONT))
			u.order_amove(hall.position,true)
	if index==2 and alive(flagship):
		flagship.order_amove(b.map.cell_to_world(Vector2i(44,40)))
		b.msg("高俅座船出发；留意护航战船的位置，可选择正面接战或侧翼攻击。",7)
	if not core_ready:
		b.mission.set_title(["第一败 · 水陆来犯","第二败 · 连船与岸军","第三败 · 海鳅船压港"][index])
		_update_wave_objective(b)
	b.msg(Localize.format_text("第%d批水陆主力出发。营地、资源和军队继续保留；两处补给源仍可主动拆除。", (index+1)),7)
## Two original rear ships screen the flagship. Their role and orders derive
## from existing groups/waves; no additional saved timer or replacement ship.
func _flagship_guards() -> Array:
	if water_groups.size()<3 or water_groups[2].size()!=6: return []
	return [water_groups[2][4],water_groups[2][5]].filter(func(u): return alive(u))
func _flagship_guard_plan(b,side: int) -> Dictionary:
	if not is_instance_valid(flagship) or flagship.hp<=0:
		return {"phase":"advance","goal":b.map.cell_to_world(SEA_FRONT)}
	var phase := "defend" if flagship_disabled else "escort" if waves[2].sent else "muster"
	var cell: Vector2i=b.map.world_to_cell(flagship.position)
	for offset in [Vector2i(side*2,2),Vector2i(side,2),Vector2i(0,2),Vector2i(side,1),Vector2i.ZERO]:
		var point: Vector2=b.map.cell_to_world(cell+offset)
		if Naval.clear_water(b.map,cell+offset,25) and b.map._segment_open(flagship.position,point,"water"):
			return {"phase":phase,"goal":point}
	return {"phase":phase,"goal":flagship.position}
func _flagship_guard_orders(b) -> void:
	var guards := _flagship_guards()
	for u in guards:
		if u.garrisoned or u.is_captive or u._taunt_t>0: continue
		var goal: Vector2=_flagship_guard_plan(b,-1 if water_groups[2][4]==u else 1).goal
		var sight: float=float(u.setup_def.get("sight",8))*GameMap.CELL
		if alive(u._target) and u._target.faction!=u.faction and u.position.distance_to(u._target.position)<=sight and b.target_visible_to(u,u._target): continue
		if u.position.distance_to(goal)<=80:
			if u._state!=Unit.ST_IDLE or u._target!=null: u.order_stop()
			u._amove_dest=Vector2.ZERO
			u._idle_push_t=0.0
			if u.stance!=Unit.STANCE_DEFEND: u.set_stance(Unit.STANCE_DEFEND)
		elif u._state!=Unit.ST_AMOVE or u._amove_dest.distance_to(goal)>96:
			u.order_amove(goal)
func _production(b,delta: float) -> void:
	if core_ready:
		return
	for lane in range(2):
		if not alive(posts[lane]) or produced[lane]>=[10,4][lane]:
			continue
		production_t[lane]-=delta
		if production_t[lane]>0:
			continue
		var naval := lane==1
		var key: String="imperial_warship" if naval else "guan_gong" if produced[0]%3==2 else "guan_dao"
		var price: Dictionary=b._defs.liangshan_warship if naval else b._defs.liang_gong if key=="guan_gong" else b._defs.liang_dao
		var cell: Vector2i=Naval.exit_cell(b,posts[lane],b._defs[key]) if naval else b.map.nearest_open(LAND_POST+Vector2i(0,3))
		if cell==Naval.INVALID or not b.faction_spend(1,int(price.cost_gold),int(price.cost_wood)):
			production_t[lane]=1.0
			continue
		var u: Unit=_guard(b,key,cell)
		if u == null:
			b.add_resources(int(price.cost_gold),int(price.cost_wood),1)
			return
		u.set_meta("gao_source",lane)
		u.order_amove(b.map.cell_to_world(SEA_FRONT if naval else LAND_FRONT))
		if not naval:
			u.order_amove(hall.position,true)
		support.append(u)
		produced[lane]+=1
		ai_spent_gold+=int(price.cost_gold)
		ai_spent_wood+=int(price.cost_wood)
		production_t[lane]=float(price.train_time)
func _near(b,u,cell: Vector2i,radius: float) -> bool:
	return alive(u) and u.position.distance_to(b.map.cell_to_world(cell))<=radius
func _enemy_near(b,p: Vector2,radius: float) -> bool:
	return b.units.any(func(u): return alive(u) and u.faction==1 and not u.is_resource and not u.is_building and u.position.distance_to(p)<radius)
func _fire_targets(actor) -> Array:
	if not alive(actor): return []
	return water_groups[1].filter(func(u): return alive(u) and u.position.distance_to(actor.position)<=FIRE_ZONE_RADIUS)
func _fire_escorts(b,actor) -> Array:
	if not alive(actor): return []
	return [b.find_unit("ruan_xiaoer_boat"),b.find_unit("ruan_xiaowu_boat")].filter(func(u): return alive(u) and u.position.distance_to(actor.position)<=220)
func _visible_fire_target_count(b) -> int:
	return _fire_targets(fireboat).filter(func(u): return u._invis_t <= 0.0 and b.is_visible_world(u.position)).size()
func _fire_next_step(b, visible_targets: int, escorts: int) -> String:
	if visible_targets == 0 and not waves[1].sent:
		return "第二批连船尚未出发。可留火船在安全水域，等连船驶近再举火。"
	for action_id in ["gao_fire_0","gao_fire_1"]:
		var action: Dictionary = b.mission.actions.get(action_id,{})
		if action.is_empty() or action.done or not String(action.get("blocked_reason","")).is_empty(): continue
		var marker: Vector2 = b.map.cell_to_world(action.cell)
		if fireboat.position.distance_to(marker) > float(action.reach) or not b.map._segment_open(fireboat.position,marker,fireboat.movement_profile):
			continue
		if visible_targets == 0:
			return "等第二批连船进入火区。"
		if escorts < 2:
			return "等两艘接应船靠近火船。"
		if b.hud.touch_ui:
			return "可以举火。选中火船，轻点举火旗标。"
		return "可以举火。选中火船，右键举火旗标。"
	return "先护送火船到举火旗标附近。"
func _fire_hint(b) -> String:
	var visible_targets := _visible_fire_target_count(b)
	var escorts := _fire_escorts(b,fireboat).size()
	var count := Localize.format_text("火船附近可见连船%d；接应船到位%d/2。",[visible_targets,escorts])
	if not alive(fireboat):
		return count
	return count + "\n" + Localize.text(_fire_next_step(b, visible_targets, escorts))
func _escort_ships(b) -> Array:
	return [liu_carrier, b.find_unit("ruan_xiaowu_boat")]


func _withdraw_crew(b) -> Array:
	return _escort_ships(b).filter(func(ship): return _near(b, ship, FIRE_SAFE, 120))


# Both ships must enter the safe water before the first one starts the usual
# withdrawal action. The story's original enemy and arrival checks still run.
func can_start_manual_mission_action(b, action_id: String) -> bool:
	return action_id != WITHDRAW_ACTION or b.hud.touch_ui or _withdraw_crew(b).size() == 2


func _fire_route_ships(b, button_id: String) -> Array:
	if b.hud.touch_ui:
		return []
	var withdrew: bool = b.mission.has_event("fire_escort_safe")
	var missed: bool = b.mission.story_goals.get("gao_fire", {}).get("state", "") == "missed"
	var withdrawing := button_id == WITHDRAW_ESCORT_SHIPS
	if withdrawing and (not fire_lit or withdrew or missed or fire_abandoned):
		return []
	if not withdrawing and not withdrew and not missed:
		return []
	var action_id := WITHDRAW_ACTION if withdrawing else RETURN_ACTION
	var action: Dictionary = b.mission.actions.get(action_id, {})
	if action.is_empty() or action.done or not String(action.get("blocked_reason", "")).is_empty():
		return []
	var ships: Array = _escort_ships(b) if withdrawing else [_liu_return_ship()]
	return ships if ships.all(func(ship): return b.mission._valid_action_actor(ship, action)) else []


func _sync_fire_route_button(b, button_id: String, label: String, tooltip: String) -> void:
	var button: Button = b.mission.find_level_button(button_id)
	if _fire_route_ships(b, button_id).is_empty():
		if button != null:
			button.get_parent().remove_child(button)
			button.queue_free()
	elif button == null:
		button = b.mission.add_level_button(button_id, label, tooltip)
		button.get_parent().move_child(button, 0)
		b.mission.reveal_primary_level_button()


func _order_fire_route(b, button_id: String) -> void:
	if not b._gameplay_rng_issue.is_empty():
		return
	var withdrawing := button_id == WITHDRAW_ESCORT_SHIPS
	var action_id := WITHDRAW_ACTION if withdrawing else RETURN_ACTION
	var ships := _fire_route_ships(b, button_id)
	if ships.is_empty() or b.mission.active_action_id == action_id:
		return
	var action: Dictionary = b.mission.actions[action_id]
	var marker: Vector2 = b.map.cell_to_world(action.cell)
	var movers: Array = []
	var targets: Array[Vector2] = []
	for index in range(ships.size()):
		var ship: Unit = ships[index]
		if (ship.mission_order_active or ship.mission_order_arrival_t > 0.0) \
				and ship.mission_order_target == marker:
			continue
		# Keep a full tile between each hull and the marker, within action reach.
		var cell: Vector2i = action.cell
		if withdrawing:
			cell += FIRE_WITHDRAW_SLOTS[index]
		var target: Vector2 = b.map.cell_to_world(cell)
		var path: PackedVector2Array = b.map.find_path(ship.position, target, ship.faction, ship.movement_profile)
		if path.is_empty() or path[-1].distance_to(marker) > float(action.reach) \
				or not b.map._segment_open(path[-1], marker, ship.movement_profile):
			b.mission.set_feedback("暂时走不到旗标。请清开道路或手动改道。")
			return
		movers.append(ship)
		targets.append(target)
	if movers.is_empty() or not b.mission.can_tap_action(movers, marker):
		return
	b._stamp_manual(movers)
	for index in range(movers.size()):
		movers[index].order_move(targets[index])
	b._stamp_mission_move(movers, marker)
	b.mission.set_feedback("两艘接应船正驶往安全水域。" if withdrawing else "载刘唐的船已启程返港。")
	Sfx.play("order")
func _liu_return_ship() -> Unit:
	if not is_instance_valid(embarked_liu): return null
	var ship = liu_carrier if fire_lit else fireboat
	return ship if alive(ship) else null

func refresh_restored_liu_return(b) -> void:
	var ship := _liu_return_ship()
	var action: Dictionary = b.mission.actions.get(RETURN_ACTION, {})
	if ship != null and not action.is_empty() and not action.done and not action.has("blocked_reason") and action.actors != [ship.key]:
		# Older saves can list both boats. Preserve their action and progress;
		# only the ship carrying the restored passenger can take the next order.
		b.mission.update_action_actors(RETURN_ACTION, [ship.key])
	_update_wave_objective(b)

func _fire_aftermath(withdrew: bool, can_return: bool) -> String:
	if withdrew:
		return "双船已撤离，火攻演义保留。可让阮小二送刘唐返港下船。" if can_return else "双船已撤离，火攻演义保留。"
	return "火攻未成。普通战船可继续迎敌，载刘唐的船可返港下船。" if can_return else "火攻未成，继续用普通战船迎敌。"

func _liu_loss_text(b) -> String:
	if not fire_lit:
		return "搭载刘唐的船只损失，刘唐失散；可在忠义堂正常付费重新集结，火攻不再能补办。"
	if b.mission.has_event("fire_escort_safe"):
		return "刘唐随阮小二船失散。已完成的火攻演义保留，可在忠义堂付费重新集结刘唐。"
	return "阮小二船在撤离前沉没，刘唐失散。火攻演义未成，可在忠义堂付费重新集结刘唐。"
func unit_tactical_hint(b,u) -> String:
	if not is_instance_valid(u): return ""
	if u.faction==1 and _flagship_guards().has(u):
		return Localize.text("座船护航 · 随座船集结与推进\n座船停航后仍守卫附近水面。")
	if u.faction==1 and water_groups.size()>1 and u in water_groups[1]:
		return Localize.text("第二批连船 · 前港列阵\n等多艘进入火区，再让刘唐举火。")
	if u.faction!=0: return ""
	if u == prisoner and alive(prisoner) and not capture_lost:
		return Localize.text(PRISONER_WAITING if prisoner_waiting_for_escort(b, prisoner)
			else "已有岸军护卫。可下令将高俅押回忠义堂前。")
	if u.key not in ["liu_tang","liu_tang_fireboat","ruan_xiaoer_boat","ruan_xiaowu_boat"]: return ""
	if b.mission.has_event("gao_liu_returned") and u.key=="liu_tang":
		return Localize.text("刘唐已返港，可继续指挥岸军。")
	if b.mission.has_event("liu_tang_lost"):
		return Localize.text("刘唐已重新集结，可继续指挥岸军。" if alive(b.find_unit("liu_tang")) else _liu_loss_text(b))
	var withdrew: bool = b.mission.has_event("fire_escort_safe")
	if withdrew or fire_abandoned or b.mission.story_goals.get("gao_fire",{}).get("state","")=="missed":
		return Localize.text(_fire_aftermath(withdrew, u == _liu_return_ship()))
	if fire_lit:
		var prompt := "接应船已到安全区%d/2；压退附近官船。\n两船到齐后，轻点撤出险水旗标。" if b.hud.touch_ui \
			else "接应船已到安全区%d/2；压退附近官船。\n两船到齐后，右键撤出险水标记。"
		return Localize.format_text(prompt,_withdraw_crew(b).size())
	if fire_prepared:
		return _fire_hint(b)
	if not b.mission.has_event("gongsun_wind"):
		return Localize.text("公孙胜先到祭风标记；刘唐随后备火。\n先造普通战船掩护两艘接应船。")
	return Localize.format_text("刘唐到码头备火需60木，当前%d木。\n待装火具小船须留在主码头。",[int(b.wood)])
func _fire_unavailable(b,reason: String) -> void:
	if b.mission.has_event("fire_escort_safe"): return
	if not b.mission.miss_story_goal("gao_fire",reason): return
	for action in ["gao_wind","gao_prepare","gao_fire_0","gao_fire_1","gao_fire_withdraw"]:
		b.mission.block_action(action,reason)
func _liu_landing_cell(b) -> Vector2i:
	# Local dock transfer only. A blocked shore must be cleared, never search the
	# whole map and teleport the original hero to a distant free cell.
	if not is_instance_valid(embarked_liu): return Naval.INVALID
	for r in range(3):
		for y in range(-r,r+1):
			for x in range(-r,r+1):
				if maxi(absi(x),absi(y))!=r: continue
				var cell := LANDING+Vector2i(x,y)
				var point: Vector2=b.map.cell_to_world(cell)
				if not b.map.is_open_cell(cell,"land"): continue
				if b.units.any(func(u): return alive(u) and not u.garrisoned and u.position.distance_to(point)<u.radius+embarked_liu.radius+4): continue
				return cell
	return Naval.INVALID
func _disembark_liu(b,actor) -> void:
	if not is_instance_valid(embarked_liu) or embarked_liu.story_outcome!="embarked": return
	if actor!=_liu_return_ship() or not _near(b,actor,LIU_RETURN,64) or _enemy_near(b,b.map.cell_to_world(LANDING),180):
		_retry(b,"gao_liu_return","请把搭载刘唐的原船驶到返港标记，先清开码头附近官军。")
		return
	var cell := _liu_landing_cell(b)
	if cell==Naval.INVALID:
		_retry(b,"gao_liu_return","码头岸上没有安全空位，请移开部队或清理阻挡后再下船。")
		return
	var hero=embarked_liu
	embarked_liu=null
	liu_carrier=null
	hero.story_outcome=""
	hero.position=b.map.cell_to_world(cell)
	hero.order_stop()
	hero.passive=false
	hero.set_stance(Unit.STANCE_DEFEND)
	hero.show()
	hero.queue_redraw()
	actor.remove_meta("carried_story_person")
	if not fire_lit:
		actor.remove_meta("story_commander")
		actor.resolve_story("retreated")
	if not b.mission.has_event("fire_escort_safe"):
		fire_abandoned=true
		_fire_unavailable(b,"刘唐已返港放弃本次火攻；火具耗材不退，可继续指挥岸军、造普通战船。")
	b.mission.mark("gao_liu_returned","刘唐已由原船返港下船，保留生命、成长和装备，可重新指挥岸军。")
	b.hud.update_selection_panel(b.selection)
func on_mission_action(b,key: String,actor) -> void:
	if fire_abandoned and key in ["gao_wind","gao_prepare","gao_fire_0","gao_fire_1","gao_fire_withdraw"]: return
	match key:
		"gao_liu_return":
			_disembark_liu(b,actor)
		"gao_lure_main","gao_lure_side":
			if lure_started or _count(water_groups[0])==0:
				return
			lure_started=true
			lure_cell=Vector2i(39,43) if key=="gao_lure_main" else Vector2i(37,42)
			_send_wave(b,0)
			for u in water_groups[0]:
				if alive(u):
					u.order_amove(b.map.cell_to_world(lure_cell))
			b.msg("官船追入港汊。请把阮小七撤到主力后面，岸弓与战船合击；活官船确实入伏区才计演义印。",7)
		"gao_wind":
			b.mission.mark("gongsun_wind","公孙胜祭风，刘唐可在主码头装火具登船。")
			b.mission.add_action("gao_prepare","刘唐：码头备火登船",LANDING,["liu_tang"],2,48)
			b.mission.add_actor_locator("gao_prepare","liu_tang")
		"gao_prepare":
			if fire_prepared:
				return
			if not _near(b,fireboat,LANDING_WATER,80) or b.wood<60:
				_retry(b,key,"待装火具小船需在主码头水面，另需60木备火。可先造普通战船继续作战。")
				return
			b.add_resources(0,-60)
			fire_prepared=true
			embarked_liu=actor
			actor.resolve_story("embarked")
			fireboat.display_name="刘唐·举火小船"
			fireboat.set_meta("story_commander","liu_tang")
			b.mission.mark("liu_tang_fire_leader","刘唐带引火物实际登上主码头小船。")
			b.mission.mark("fireboat_prepared","小船备好火具，消耗60木；护它接近第二批连船再举火。")
			for i in range(FIRE_POINTS.size()):
				var action_id := "gao_fire_%d" % i
				b.mission.add_action(action_id,"刘唐：外港举火" if i==0 else "刘唐：内港举火",FIRE_POINTS[i],["liu_tang_fireboat"],1.5,48)
				# Initial arrival still uses 48. Only an already started action
				# tolerates a small nudge from the two required escort ships.
				b.mission.actions[action_id].settle_margin = 12.0
			b.mission.add_action("gao_liu_return","刘唐：原船返港下船",LIU_RETURN,["liu_tang_fireboat"],1.5,48)
			b.msg("火攻可自选放弃：把搭载刘唐的原船开回返港标记下船，已耗60木不退。若已完成两船安全撤离，下船保留该演义成果。",7)
		"gao_fire_0","gao_fire_1":
			if fire_lit or actor!=fireboat:
				return
			var near: Array=_fire_targets(actor)
			var two=b.find_unit("ruan_xiaoer_boat")
			if near.is_empty():
				var message := "连船还没进入火区。让接应船护住火船，等连船靠近再举火。"
				if not waves[1].sent:
					message = "第二批连船尚未出发。可留火船在安全水域，等连船驶近再举火。"
				_retry(b,key,message)
				return
			if _fire_escorts(b,actor).size()!=2:
				_retry(b,key,"连船已靠近。等阮小二、阮小五两艘接应船都到火船旁，再举火。")
				return
			fire_lit=true
			liu_carrier=two
			two.set_meta("carried_story_person","刘唐")
			b.mission.update_action_actors("gao_liu_return",["ruan_xiaoer_boat"])
			b._spawn_ground_fire(actor.position,FIRE_ZONE_RADIUS,650,8,actor,1,"gao_fireboat")
			for u in near:
				u.apply_slow(0.35,8)
			actor.set_meta("ship_state","disabled")
			actor.resolve_story("retreated")
			b.mission.mark("gao_fire_lit","火船燃起，刘唐转入阮小二接应船。火区持续8秒，只有区内官船实际受伤。")
			b.mission.add_action("gao_fire_withdraw","阮氏接应船：撤出险水",FIRE_SAFE,["ruan_xiaoer_boat","ruan_xiaowu_boat"],1,64)
		"gao_fire_withdraw":
			if _withdraw_crew(b).size()!=2 or _enemy_near(b,b.map.cell_to_world(FIRE_SAFE),230):
				_retry(b,key,"两艘接应船都需回到南侧安全水域，并先压退230距离内的官船。")
				return
			b.mission.mark("fire_escort_safe","两艘阮氏接应船和刘唐撤出险水，水寨与其余舰队保留。")
		"gao_seal":
			if capture_lost or port_sealed or not flagship_disabled:
				return
			if _enemy_near(b,flagship.position,260):
				_retry(b,key,"座船已停航，但周围仍有官船；先清开封港和小艇靠船的水面。")
				return
			port_sealed=true
			b.mission.mark("port_sealed","阮氏水军控制座船外侧港口，张顺可安全靠船。")
			b.mission.add_action("gao_scuttle",Localize.text("张顺：凿船接俘"),b.map.world_to_cell(flagship.position)+Vector2i(-3,0),["zhang_shun_boat"],3,64)
		"gao_scuttle":
			if capture_lost or recovered or not port_sealed:
				return
			if actor.position.distance_to(flagship.position)>160 or _enemy_near(b,actor.position,200):
				_retry(b,key,"张顺须贴近停航座船，先清开靠船处的官军。")
				return
			recovered=true
			carrier=actor
			actor.set_meta("carried_story_person","高俅")
			actor.display_name="张顺·押送高俅"
			flagship.set_meta("ship_state","disabled")
			flagship.queue_redraw()
			b.mission.mark("flagship_scuttled","张顺凿破座船并接起高俅；俘虏现在随小艇实际返航。")
			b.mission.add_action("gao_land","押送艇：主码头交接",LANDING_WATER,["zhang_shun_boat"],1,40)
		"gao_land":
			if capture_lost or landed or not recovered or actor!=carrier:
				return
			if not _near(b,actor,LANDING_WATER,64) or _enemy_near(b,b.map.cell_to_world(LANDING),160):
				_retry(b,key,"押送艇需抵主码头水面，岸上交接地须安全。")
				return
			var replacement: Unit=b.spawn_at("gao_qiu",0,LANDING)
			if replacement == null:
				b._gameplay_rng_stop("ENTITY_REQUIRED_REPLACEMENT")
				return
			prisoner=replacement
			landed=true
			actor.remove_meta("carried_story_person")
			actor.display_name="张顺·凿船小艇"
			prisoner.display_name="高俅·待押堂"
			prisoner.art_variant="gao_qiu_captured"
			prisoner.is_hero=false
			prisoner.is_cavalry=false
			prisoner.is_noncombat=true
			prisoner.base_speed=42
			prisoner.atk=0
			prisoner.hp=180
			prisoner.max_hp=180
			prisoner.ability=""
			prisoner.ability_slots.clear()
			prisoner.aura=""
			prisoner.setup_def=prisoner.setup_def.duplicate(true)
			prisoner.setup_def["pop"]=0
			prisoner.set_stance(Unit.STANCE_PASSIVE)
			var briefing := "高俅已实际上岸。选中他和岸军一起返回忠义堂；落单会停下等待护卫。" if b.hud.touch_ui else ESCORT_PROMPT
			b.mission.mark("gao_landed",briefing)
			b.mission.add_map_locator(Localize.text("押俘终点 · 忠义堂前"),PRISONER_HANDOVER)
			_sync_prisoner_escort_button(b)
func _capture_failed(b,reason: String) -> void:
	if capture_lost: return
	capture_lost=true
	b.mission.mark("gao_escaped",reason+Localize.text("；仍可打停座船、击退三批主力取得基础通关。"))
	for key in ["gao_seal","gao_scuttle","gao_land"]: b.mission.block_action(key,reason)
	_sync_prisoner_escort_button(b)
	if core_ready: _update_withdrawal_briefing(b)

func _is_shore_guard(guard: Unit) -> bool:
	return alive(guard) and guard.faction == Unit.FACTION_LIANG and guard.story_outcome == "" \
		and not guard.is_building and not guard.is_worker and not guard.is_noncombat \
		and not guard.garrisoned and not guard.is_captive and guard.movement_profile == "land"

# The movement controller and task briefing use the same live shore guards.
func prisoner_waiting_for_escort(b, unit: Unit) -> bool:
	if unit != prisoner or not landed or capture_lost:
		return false
	return not b.units_near(unit.position, PRISONER_ESCORT_RADIUS).any(func(guard):
		return _is_shore_guard(guard) and guard.position.distance_to(unit.position) < PRISONER_ESCORT_RADIUS)

func wait_for_shore_escort(b, mover: Unit) -> bool:
	if mover == prisoner:
		return prisoner_waiting_for_escort(b, mover)
	# Bind the two ordinary move orders, including across a save. A new player
	# order on either unit ends this assignment without changing its route.
	var link: Variant = mover.get_meta(Unit.SHORE_ESCORT_ORDER, [])
	if not alive(prisoner) or capture_lost or not _is_shore_guard(mover) \
			or not link is Array or link != [prisoner.entity_id, prisoner._order_serial, mover._order_serial]:
		mover.remove_meta(Unit.SHORE_ESCORT_ORDER)
		return false
	if prisoner._state != Unit.ST_MOVE or mover._path_i >= mover._path.size():
		return false
	var gap: Vector2 = mover.position - prisoner.position
	var step: Vector2 = mover._path[mover._path_i] - mover.position
	return gap.length_squared() >= SHORE_ESCORT_SPACING * SHORE_ESCORT_SPACING and gap.dot(step) > 0.0

func _sync_prisoner_escort_button(b) -> void:
	var button: Button = b.mission.find_level_button("gao_escort")
	if not landed or capture_lost or not alive(prisoner) or b.mission.has_event("gao_captured"):
		if button != null: button.queue_free()
	elif button == null and not b.hud.touch_ui:
		button = b.mission.add_level_button("gao_escort", "押送高俅回堂", "派附近一名空闲岸军与高俅按编队速度走向忠义堂。")
		button.get_parent().move_child(button, 0)
		b.mission.set_guidance(ESCORT_PROMPT)
		b.mission.reveal_primary_level_button()

func _order_prisoner_escort(b) -> void:
	if not landed or capture_lost or not alive(prisoner) or b.mission.has_event("gao_captured") or not b._gameplay_rng_issue.is_empty():
		return
	var destination: Vector2 = b.map.cell_to_world(PRISONER_HANDOVER)
	if prisoner._state == Unit.ST_MOVE and prisoner._home.distance_to(destination) < 100.0 \
			and not prisoner_waiting_for_escort(b, prisoner):
		b.mission.set_feedback("高俅正在押送途中。")
		return
	var guard: Unit
	var closest := PRISONER_ESCORT_RADIUS
	for candidate: Unit in b.units_near(prisoner.position, PRISONER_ESCORT_RADIUS):
		if not _is_shore_guard(candidate) or candidate._state != Unit.ST_IDLE or candidate._target != null \
				or not candidate._queue.is_empty() or candidate.stance == Unit.STANCE_HOLD or candidate._patrolling \
				or candidate._action_queue_busy() or candidate.waiting_manual_mission_arrival():
			continue
		var distance := candidate.position.distance_to(prisoner.position)
		if distance < closest:
			guard = candidate
			closest = distance
	if guard == null:
		b.center_camera_cell(b.map.world_to_cell(prisoner.position))
		b.mission.set_feedback("附近没有空闲岸军。让一名岸军到高俅身边待命，再点押送。", 4.0)
		return
	var group := [guard, prisoner]
	var targets: Array = b._formation_targets(group, destination)
	var pace: float = b._group_speed_cap(group)
	b._stamp_manual(group)
	guard.order_move(targets[0], false, pace)
	prisoner.order_move(targets[1], false, pace)
	var link := [prisoner.entity_id, prisoner._order_serial, guard._order_serial]
	guard.set_meta(Unit.SHORE_ESCORT_ORDER, link)
	prisoner.set_meta(Unit.SHORE_ESCORT_ORDER, link)
	b.select_members(group, false)
	Sfx.play("order")
	b.mission.set_feedback("岸军已出发，正押送高俅回堂。")

func _capture_completed(b) -> bool:
	return not capture_lost and alive(prisoner) and b.mission.has_event("gao_captured") and not b.mission.has_event("gao_escaped")

func _update_withdrawal_briefing(b) -> void:
	var title := "主力已退 · 收兵或押俘"
	var objective := "基础目标已达成，可直接收兵通关；也可继续清开座船周围、封港凿船并押俘回堂。"
	if capture_lost:
		title = "主力已退 · 收兵通关"
		objective = "基础目标已达成，生擒路线已失去条件。可直接点击收兵通关，无需寻找替代专船或清扫全图。"
	elif _capture_completed(b):
		objective = "高俅已押抵忠义堂。点击「收兵通关」即可结算。"
	elif landed:
		if prisoner_waiting_for_escort(b, prisoner):
			objective = "高俅正在等待岸军。让护卫靠近后可继续押堂，也可直接收兵通关。"
		else:
			objective = "高俅已上岸。选中他和岸军，一同押到忠义堂前；也可直接收兵通关。" if b.hud.touch_ui \
				else "可点「押送高俅回堂」，也可直接收兵通关。"
	elif recovered:
		objective = "高俅已在张顺的小艇上。先护送小艇回主码头交接，再由岸军押堂；也可直接收兵通关。"
	elif port_sealed:
		objective = "港口已封。让张顺靠近停航座船，轻点「凿船接俘」旗标；也可直接收兵通关。" if b.hud.touch_ui \
			else "港口已封。让张顺靠近停航座船，右键「凿船接俘」；也可直接收兵通关。"
	if b.mission.stage_title != title: b.mission.set_title(title)
	if b.mission.objective != objective: b.mission.set_objective(objective)

func _core_threats_clear() -> bool:
	return flagship_disabled and water_groups.all(func(group): return _count(group)==0) and land_groups.all(func(group): return _count(group)==0)
func _finish(b) -> void:
	if b.phase!=b.Phase.FIGHT or not _core_threats_clear() or not alive(hall) or not alive(song): return
	var captured := _capture_completed(b)
	if not captured:
		if b.mission.has_event("gao_captured"):
			_capture_failed(b,"押俘所需小艇或俘虏损失")
		b.mission.mark("gao_basic_victory","三批主力败退，高俅座船被打停，梁山收兵。")
	b.win("高俅三次进兵失利，水寨与钱粮守住。高俅已由水军生擒、岸军押至忠义堂，宋江仍以礼相待，盼借此求得招安。" if captured else "高俅三次进兵失利，水寨与钱粮守住。本局以击退座船收束；生擒押堂可在重玩时挑战。")
func _wave_objective(b) -> String:
	if waves[2].sent:
		return "座船已停。击退余下的水陆主力即可收兵。" if flagship_disabled else "第三批有座船压港。步军守关，舰队看清护船位置后合击座船。"
	var withdrew: bool = b.mission.has_event("fire_escort_safe")
	var fire_available: bool = not fire_abandoned and not withdrew \
		and b.mission.story_goals.get("gao_fire",{}).get("state","")!="missed"
	if not fire_available and _liu_return_ship() != null:
		if withdrew and not b.hud.touch_ui:
			return RETURN_PROMPT
		return _fire_aftermath(withdrew, true)
	if fire_available:
		if fire_lit:
			return "火船已点燃。让两艘接应船一同撤到安全水域，再下达撤出指令。" if b.hud.touch_ui else WITHDRAW_PROMPT
		if fire_prepared and alive(fireboat):
			return _fire_next_step(b, _visible_fire_target_count(b), _fire_escorts(b,fireboat).size())
	if waves[1].sent:
		if fire_available and _count(water_groups[1])>0:
			return "第二批连船已动。可护送刘唐举火，也可派普通舰队接战，岸军继续守关。"
		return "岸军守住东山关，普通战船接应内港。继续击退水陆主力。"
	if waves[0].sent:
		var can_lure: bool=_count(water_groups[0])>0 and not b.mission.has_event("fleet_in_ambush")
		return "守住东山关和内港。阮小七可把首批活官船引入港汊，再由舰队合击。" if can_lure else "补齐岸军和舰队，守东山关与内港。可拆两处补给源来减少后续援军。"
	return OPENING_OBJECTIVE

func _wave_warning(b, index: int) -> String:
	match index:
		0:
			return "第一批约25秒后出发。岸军守东山关，留战船和岸弓互相支援。"
		1:
			var fire_goal: Dictionary = b.mission.story_goals.get("gao_fire", {})
			if not fire_lit and not fire_abandoned and fire_goal.get("state", "") != "missed" and _count(water_groups[1]) > 0:
				return "第二批约25秒后出发。可备火并集结两艘接应船，或用普通战船迎敌。"
			return "第二批约25秒后出发。让普通战船接应内港，岸军继续守东山关。"
		_:
			if flagship_disabled:
				return "第三批约25秒后出发。座船已停，守住水陆通路，准备击退余部。"
			return "第三批约25秒后出发。步军留守东山关，舰队看清座船与护船的位置再接战。"


func _update_wave_objective(b) -> void:
	_sync_fire_route_button(b, WITHDRAW_ESCORT_SHIPS, "撤出接应船", "派阮小二和阮小五驶向安全水域。两船到齐并压退附近官船后才算撤离。")
	_sync_fire_route_button(b, RETURN_LIU_TANG, "送刘唐返港", "派载刘唐的原船返回主码头。靠岸并清开登陆点后，刘唐才能下船。")
	if core_ready: return
	var objective := _wave_objective(b)
	if b.mission.objective!=objective: b.mission.set_objective(objective)

func process(b,delta: float) -> void:
	if not alive(hall) or not alive(song):
		return
	elapsed+=delta
	_production(b,delta)
	if not b._gameplay_rng_issue.is_empty(): return
	strategy_t-=delta
	if strategy_t>0:
		return
	strategy_t=0.25
	for i in range(3):
		if waves[i].sent:
			continue
		if elapsed>=waves[i].time-25 and not waves[i].warned:
			waves[i].warned=true
			if _wave_has_force(i):
				b.msg(_wave_warning(b, i),6)
		if elapsed>=waves[i].time:
			_send_wave(b,i)
	_flagship_guard_orders(b)
	if lure_started and not b.mission.has_event("fleet_in_ambush") and water_groups[0].any(func(u): return _near(b,u,lure_cell,170)):
		b.mission.mark("fleet_in_ambush","阮小七引得活官船深入港汊，主力可以合击。")
	if _count(water_groups[0])==0 and not b.mission.has_event("fleet_in_ambush"):
		b.mission.miss_story_goal("gao_lure","官船在入伏区前已被击退；基础通关不受影响。")
		for key in ["gao_lure_main","gao_lure_side"]:
			b.mission.block_action(key,"第一批官船已击退，继续经营和进攻即可。")
	if _count(water_groups[1])==0 and not fire_lit:
		_fire_unavailable(b,"第二批连船已击退，可继续用现存舰队进攻；已登船的刘唐可由原船返港下船。")
	_update_wave_objective(b)
	if land_groups.all(func(group): return _count(group)==0):
		b.mission.mark("gao_land_cleared","三批岸上主力均已击退。")
	if flagship_disabled and not capture_lost and not b.mission.actions.has("gao_seal"):
		b.mission.add_action("gao_seal",Localize.text("阮氏水军：封港"),b.map.world_to_cell(flagship.position)+Vector2i(0,3),["ruan_xiaoer_boat","ruan_xiaowu_boat"],2,64)
	if landed and not capture_lost and alive(prisoner):
		if prisoner_waiting_for_escort(b, prisoner):
			if not escort_warning:
				b.msg(PRISONER_WAITING,5)
			escort_warning=true
		else:
			escort_warning=false
			if _near(b,prisoner,PRISONER_HANDOVER,100) and not _enemy_near(b,prisoner.position,180):
				b.mission.mark("gao_captured","俘虏与护卫已实际抵忠义堂前。")
				_sync_prisoner_escort_button(b)
				if _core_threats_clear():
					_finish(b)
					return
		_sync_prisoner_escort_button(b)
	if _core_threats_clear() and not core_ready:
		core_ready=true
		end_button=b.mission.add_level_button("gao_end","收兵通关 · 已击退高俅")
	if core_ready:
		_update_withdrawal_briefing(b)
func activate_mission_button(b, button_id: String) -> void:
	if button_id == "gao_end": _finish(b)
	elif button_id == "gao_escort": _order_prisoner_escort(b)
	elif button_id == WITHDRAW_ESCORT_SHIPS or button_id == RETURN_LIU_TANG:
		_order_fire_route(b, button_id)
func on_unit_resolved(b,u,outcome: String) -> void:
	if u==flagship and outcome=="subdued":
		flagship_disabled=true
		u.set_meta("ship_state","damaged")
		b.mission.mark("flagship_disabled","高俅座船在实际交战中失去战力。压退剩余水陆主力即可收兵，或另做封港押俘。")
func on_unit_died(b,u) -> void:
	if u==hall or u==song: b.lose(Localize.text(u.display_name)+Localize.text("失守。岸军要守东山关，舰队护住码头；可重开并调整水陆投入。")); return
	# The hidden embarked hero reserves population/uniqueness while aboard.
	# A real loss of his carrier must release that reservation as well.
	var lost_liu: bool=is_instance_valid(embarked_liu) and ((u==fireboat and not fire_lit) or u==liu_carrier)
	if lost_liu:
		b.units.erase(embarked_liu)
		embarked_liu.queue_free()
		embarked_liu=null
		if u==liu_carrier:
			liu_carrier=null
			u.remove_meta("carried_story_person")
		var reason := _liu_loss_text(b)
		b.mission.mark("liu_tang_lost",reason)
		b.mission.block_action("gao_liu_return","载船已损失，刘唐失散；可在忠义堂付费重新集结。")
		_fire_unavailable(b,reason)
	if u==posts[0]: b.mission.mark("gao_land_post_destroyed","山前补给营被拆，停止该处所有陆军补充，北侧资源可争取。")
	if u==posts[1]: b.mission.mark("gao_sea_post_destroyed","东岸官军船坞被拆，停止该处所有战船补充。")
	if u==flagship: flagship_disabled=true; _capture_failed(b,"座船已沉，未能生擒高俅")
	if u==prisoner or (not landed and (u==carrier or u.key=="zhang_shun_boat")):
		_capture_failed(b,"押俘所需小艇或俘虏损失")
	if u.key in ["ruan_xiaoer_boat","ruan_xiaowu_boat"]:
		if not port_sealed and not alive(b.find_unit("ruan_xiaoer_boat")) and not alive(b.find_unit("ruan_xiaowu_boat")):
			_capture_failed(b,"两艘封港专船均已损失")
		if not lost_liu and not b.mission.has_event("fire_escort_safe"):
			_fire_unavailable(b,"接应船损失，可继续用普通舰队作战；刘唐若仍在原船上，可返港下船。")
	if not lost_liu and u==fireboat and not fire_lit: _fire_unavailable(b,"火船损失，可建船坞补普通战船继续进攻。")
func campaign_debrief(mission) -> Array[Dictionary]:
	var fire_result := "未备火船"
	if mission.has_event("fire_escort_safe"):
		fire_result = "举火并完成接应撤离"
	elif fire_abandoned:
		fire_result = "已放弃火攻"
	elif fire_lit:
		fire_result = "已举火，接应撤离未完成"
	elif fire_prepared:
		fire_result = "已备火船，尚未举火"
	var capture_result := "未接俘"
	if _capture_completed(mission.battle):
		capture_result = "已押抵忠义堂"
	elif capture_lost:
		capture_result = "押俘路线未成"
	elif landed:
		capture_result = "已上岸，尚未押堂"
	elif recovered:
		capture_result = "已接俘，尚未上岸"
	return [
		{"source": "火攻 · %s", "args": [fire_result]},
		{"source": "座船 · %s", "args": ["已失去战力" if flagship_disabled else "尚未打停"]},
		{"source": "押俘 · %s", "args": [capture_result]},
	]

func top_status(_b) -> String:
	if not core_ready:
		for index in range(waves.size()):
			if not waves[index].sent and _wave_has_force(index):
				var remaining := maxi(0,ceili(float(waves[index].time)-elapsed))
				return Localize.format_text("三败高太尉 · 第%d批约%d秒 · 官军补充 陆%d/10 船%d/4",[index+1,remaining,produced[0],produced[1]])
	return Localize.format_text("三败高太尉 · 官军补充 陆%d/10 船%d/4",[produced[0],produced[1]])
