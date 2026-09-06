extends LevelBase
## Emergency army rescue: finite money and caches, real paid reinforcements,
## persistent streets and enemies, player-directed rescue and withdrawal.
const T := GameMap.T
const SCAFFOLD := Vector2i(30,18)
const WEST_CAMP := Vector2i(8,26)
const DOCK_CAMP := Vector2i(10,46)
const DOCK := Vector2i(10,50)
const BAILONG := Vector2i(14,43)
const CITY_POST := Vector2i(44,25)
const CACHE_CELLS := [Vector2i(13,23),Vector2i(28,41)]
const WEST_ROUTE := [Vector2i(22,28),Vector2i(18,34),Vector2i(14,40),BAILONG]
const SOUTH_ROUTE := [Vector2i(29,29),Vector2i(28,36),Vector2i(24,43),Vector2i(18,46),DOCK]
const NAMED := ["chao_gai","li_kui","hua_rong","yan_shun","zhang_shun","zhang_heng"]
const RESCUERS := ["chao_gai","li_kui","hua_rong","yan_shun","zhang_shun","zhang_heng","liang_dao","liang_qiang","liang_gong","liang_ma"]
const DEADLINE := 150.0
var camps: Array[Unit]=[]
var named_units: Dictionary={}
var caches: Array[Unit]=[]
var cache_taken := [false,false]
var executioners: Array[Unit]=[]
var city_guards: Array[Unit]=[]
var pursuit: Array[Unit]=[]
var blockers: Array[Unit]=[]
var towers: Array[Unit]=[]
var reinforcements: Array[Unit]=[]
var post: Unit
var scaffold: Unit
var temple: Unit
var song_bound: Unit
var dai_bound: Unit
var song_freed: Unit
var dai_freed: Unit
var alarm := false
var execution_halted := false
var exec_left := DEADLINE
var elapsed := 0.0
var strategy_t := 0.0
var train_left := 32.0
var enemy_produced := 0
var enemy_spent_gold := 0
var enemy_spent_wood := 0
var pursuit_left := -1.0
var pursuit_sent := false
var first_rescued := false
var meeting := false
var rally := false
var depart_button: Button
var victory := false

func id() -> String: return "level2"
func title() -> String: return "江州劫法场"
func subtitle() -> String: return "有限补给·分路劫救·护送登船"
func economy_enabled() -> bool: return true
func start_gold() -> int: return 190
func start_wood() -> int: return 120
func base_pop_cap() -> int: return 36
func hero_start_rank() -> int: return 0
func fog_enabled() -> bool: return true
func map_w() -> int: return 60
func map_h() -> int: return 58
func map_base() -> int: return T.TOWN
func map_theme() -> String: return "town"
func camera_start_cell() -> Vector2i: return Vector2i(16,29)
func story_contract_version() -> int: return 2
func campaign_core_goal() -> String: return "150秒内打倒两名刽子手，分别救出宋江、戴宗，护送二人活着登船，再下令开船。无需杀光官军。"
func campaign_story_goals() -> Array:
	return [
		{"id":"li_kui_first","label":"两路就位后，由李逵排头打断行刑","required_events":["jiangzhou_li_first"],"forbidden_events":["jiangzhou_other_first"]},
		{"id":"free_both","label":"在法场分别救下宋江、戴宗","required_events":["free_song","free_dai"]},
		{"id":"bailong_meeting","label":"护送二人到白龙庙，与水军相会","required_events":["bailong"]},
		{"id":"named_survive","label":"六名具名好汉全部活着撤回码头","required_events":["jiangzhou_named_survive"],"forbidden_events":["jiangzhou_named_lost"]},
	]
func deploy_hint() -> String:
	return "本关不采矿升代。西街、江边两处接应营共用有限金木，按原价补刀枪弓骑；两处补给棚各有100金60木，可派兵夺取。攻击令会发动劫场，先打倒两名刽子手解除150秒限时。救人后自行编队开路、护送和断后。"
func intro_lines() -> Array:
	return [
		{"who":"旁白","key":"narrator","text":"宋江、戴宗被押赴江州法场，晁盖等分路混入街市。江边接应人手带着有限钱粮，这场急救没有从头造城采矿的工夫。"},
		{"who":"晁盖","key":"chao_gai","text":"两处接应营可补刀枪弓骑，钱粮共用。西巷短而狭，南巷宽但有马军；沿街还有两处存粮可取。先抢到人，再考虑断援、押送和后队。"},
		{"who":"李逵","key":"li_kui","text":"俺从西街挤近，燕顺走南巷接应。两边到位便可动手，不必空等！也可带兵直接打上刑台。"},
		{"who":"行前提示","key":"narrator","text":"两名刽子手倒下就停止行刑倒计时。宋江戴宗获救后不能作战，要分别带到江边登船；北面追兵提前20秒示警，东街巡防营可拆。白龙庙相会和全员撤回另记演义印。"},
	]
func apply_overrides(defs: Dictionary,_abilities: Dictionary) -> void:
	# Retain shared troops, skills, prices and training time. No worker/altar
	# is deployed; finite caches plus the finite enemy's normal bounty fund aid.
	defs.barracks.researches=[]
	defs.scaffold.captive=true
	defs.tavern.captive=true
	for key in ["song_jiang","dai_zong"]:
		defs[key].hero=false
		defs[key].hero_trainable=false
		defs[key].noncombat=true
		defs[key].pop=0
		defs[key].atk=0
		defs[key].abilities=[]
		defs[key].ability=""
		defs[key].aura=""
		defs[key].speed=50
func paint_map(map: GameMap) -> void:
	load("res://scripts/levels/level2_jiangzhou.gd").new().paint_map(map)
	for cell in [WEST_CAMP,DOCK_CAMP,CITY_POST]+CACHE_CELLS:
		map.fill_rect(cell.x-2,cell.y-2,5,5,T.TOWN)
	map.paint_path([Vector2(WEST_CAMP),Vector2(14,28),Vector2(22,25)],1,T.ROAD)
	map.paint_path([Vector2(30,27),Vector2(28,36),Vector2(24,43),Vector2(18,46),Vector2(DOCK)],1,T.ROAD)
func decorate(map: GameMap) -> void:
	load("res://scripts/levels/level2_jiangzhou.gd").new().decorate(map)
	for record in [[WEST_CAMP,"西街接应营"],[DOCK_CAMP,"江边接应营"],[CITY_POST,"巡防营"],[Vector2i(18,34),"西巷"],[Vector2i(27,36),"南巷"]]:
		map.decor.append(["story_sign",record[0]+Vector2i(2,2),56.0,record[1]])
func living(u) -> bool: return is_instance_valid(u) and u.hp>0
func active(u) -> bool: return living(u) and u.story_outcome==""
func _near(b,u,cell: Vector2i,radius: float) -> bool: return active(u) and u.position.distance_to(b.map.cell_to_world(cell))<radius
func _enemy_near(b,p: Vector2,radius: float) -> bool:
	return b.units.any(func(u): return active(u) and u.faction==1 and not u.is_building and u.position.distance_to(p)<radius)
func _guard(b,key: String,cell: Vector2i) -> Unit:
	var u: Unit=b.spawn_at(key,1,cell)
	u.set_stance(Unit.STANCE_DEFEND)
	u.passive=true # Await the uprising; no passive state remains after it.
	return u
func on_unit_trained(_b,u,building) -> void:
	# Recruits join the same quiet approach as the original rescuers. Rallying
	# them must not unexpectedly break the two-street plan by auto-acquiring.
	if not alarm and building in camps and u.faction==0:
		u.set_stance(Unit.STANCE_PASSIVE)
func deploy(b) -> void:
	for cell in [WEST_CAMP,DOCK_CAMP]:
		var camp: Unit=b.spawn_at("barracks",0,cell)
		camp.display_name="西街接应营" if cell==WEST_CAMP else "江边接应营"
		camps.append(camp)
	for cell in CACHE_CELLS:
		var cache: Unit=b.spawn_at("depot",2,cell)
		cache.display_name="补给棚 · 100金60木"
		caches.append(cache)
	scaffold=b.spawn_at("scaffold",0,SCAFFOLD)
	scaffold.art_variant="jiangzhou_scaffold"
	song_bound=b.spawn_at("song_jiang_bound",0,SCAFFOLD+Vector2i(-1,0))
	dai_bound=b.spawn_at("dai_zong_bound",0,SCAFFOLD+Vector2i(1,0))
	for off in [Vector2i(-1,2),Vector2i(1,2)]: executioners.append(_guard(b,"guan_zhanzi",SCAFFOLD+off))
	for off in [Vector2i(-3,1),Vector2i(3,1),Vector2i(-3,3),Vector2i(3,3),Vector2i(-2,4),Vector2i(2,4),Vector2i(0,5),Vector2i(-4,2)]: city_guards.append(_guard(b,"guan_laozi",SCAFFOLD+off))
	for record in [["chao_gai",Vector2i(8,30)],["li_kui",Vector2i(9,31)],["hua_rong",Vector2i(7,29)],["yan_shun",Vector2i(24,40)],["zhang_shun",Vector2i(8,49)],["zhang_heng",Vector2i(12,49)]]:
		var u: Unit=b.spawn_at(record[0],0,record[1])
		named_units[u.key]=u
		if u.key=="li_kui": u.art_variant="li_kui_jiangzhou"
		u.set_stance(Unit.STANCE_PASSIVE)
	for record in [["liang_dao",Vector2i(10,29)],["liang_dao",Vector2i(10,30)],["liang_gong",Vector2i(7,31)],["liang_qiang",Vector2i(25,40)],["liang_dao",Vector2i(23,41)],["liang_gong",Vector2i(24,41)]]:
		var u: Unit=b.spawn_at(record[0],0,record[1]); u.set_stance(Unit.STANCE_PASSIVE)
	for i in range(4): city_guards.append(_guard(b,"guan_dao" if i<2 else "guan_gong",Vector2i(18+i%2,24+i/2)))
	for i in range(5): blockers.append(_guard(b,"guan_qi" if i<2 else "guan_gong",Vector2i(28+i%2,35+i/2)))
	for i in range(4): blockers.append(_guard(b,"guan_dao" if i<3 else "guan_gong",Vector2i(23+i%2,44+i/2)))
	for i in range(6): pursuit.append(_guard(b,"guan_dao" if i<4 else "guan_gong",Vector2i(32+i%3,9+i/3)))
	city_guards.append(_guard(b,"cai_jiu",Vector2i(30,8)))
	for cell in [Vector2i(34,23),Vector2i(25,39)]:
		var tower: Unit=_guard(b,"arrow_tower",cell)
		tower.display_name="法场箭台" if cell.y==23 else "南巷箭台"
		tower.set_physics_process(false) # Building attack ticks do not use the mobile passive flag.
		towers.append(tower)
	post=b.spawn_at("barracks",1,CITY_POST)
	post.display_name="东街巡防营"
	temple=b.spawn_at("tavern",0,BAILONG+Vector2i(1,-1))
	temple.display_name="白龙庙"; temple.art_variant="bailong_temple"
func on_start(b) -> void:
	b.faction_res[1]={"gold":160.0,"wood":100.0}
	b.mission.begin("jiangzhou_rts","分路备兵 · 刑期将至","150秒内打倒两名刽子手。接应营补兵与好汉接近法场可同时进行；救人后继续使用现存部队，不重置战场。")
	b.mission.enable_scrolling()
	for cell in [WEST_CAMP,DOCK_CAMP,SCAFFOLD,CITY_POST]: b.lit_cells[cell]=9999
	b.mission.add_map_locator("西街接应营 · 刀枪弓骑",WEST_CAMP)
	b.mission.add_map_locator("江边接应营 · 共用金木",DOCK_CAMP)
	b.mission.add_map_locator("东街巡防营 · 拆除断援",CITY_POST)
	for i in range(2): b.mission.add_action("cache_%d"%i,"夺取补给 · 100金60木",CACHE_CELLS[i]+Vector2i(0,2),RESCUERS,2,64)
	b.mission.add_action("west_street","李逵 · 西街就位",Vector2i(22,25),["li_kui"],0.7,64)
	b.mission.add_action("south_lane","燕顺 · 南巷接应",Vector2i(27,29),["yan_shun"],0.7,64)
	b.msg("有限金木共用，接应营正常付费、计时补兵。附近补给棚只可领取一次；派人取粮的同时别耽误150秒行刑限时。",9)
func _retry(b,key: String,text: String) -> void:
	if not b.mission.actions.has(key): return
	var a: Dictionary=b.mission.actions[key]
	a.done=false
	if is_instance_valid(a.button): a.button.disabled=false
	if is_instance_valid(a.get("actor_button")): a.actor_button.disabled=false
	a.marker.show()
	b.mission._refresh_marker_captions()
	b.mission.set_status(text)
	b.msg(text,4)
func _uprising(b,actor) -> void:
	if alarm: return
	alarm=true
	var li_first: bool=actor==named_units.get("li_kui") and b.mission.has_event("west_street") and b.mission.has_event("south_lane") and _near(b,named_units.get("yan_shun"),Vector2i(27,29),160)
	b.mission.mark("jiangzhou_li_first" if li_first else "jiangzhou_other_first","李逵排头动手，两路好汉同时劫场。" if li_first else "救援队提前发动，先打倒刽子手；基础营救不受影响。")
	for u in b.units:
		if active(u) and u.faction in [0,1] and (not u.is_building or u.atk>0) and not u.is_noncombat:
			if u in pursuit: continue # Reserve remains in place until its warning expires, unless attacked.
			if u in towers: u.set_physics_process(true)
			u.passive=false
			u.set_stance(Unit.STANCE_DEFEND)
	b.mission.set_title("劫场 · 先打刽子手")
	b.mission.set_objective("两名刽子手倒下即可停刑，再分别解缚。东街巡防营32秒后开始付费补军，最多8人；拆营可断援。")
	for key in ["west_street","south_lane","first_axes"]: b.mission.block_action(key,"已经起事，直接攻击刽子手并救人。")
func _free(b,is_song: bool) -> void:
	var bound: Unit=song_bound if is_song else dai_bound
	if not active(bound): return
	var pos: Vector2=bound.position
	var remaining: float=bound.hp
	var combat_cool: float=bound._combat_cool
	b.units.erase(bound); bound.queue_free()
	var key: String="song_jiang" if is_song else "dai_zong"
	var rescued: Unit=b.spawn_unit(key,0,pos)
	rescued.art_variant=key+"_rescued"
	rescued.max_hp=200 if is_song else 150
	rescued.hp=minf(remaining,rescued.max_hp)
	rescued._combat_cool=combat_cool # Changing art/state must not reset the recovery delay.
	rescued.set_stance(Unit.STANCE_PASSIVE)
	if is_song: song_bound=null; song_freed=rescued
	else: dai_bound=null; dai_freed=rescued
	b.mission.mark("free_song" if is_song else "free_dai",rescued.display_name+"已解缚，不能作战；请派兵保护并亲自下令撤离。")
	b.mission.add_action("board_song" if is_song else "board_dai",rescued.display_name+" · 登船",DOCK if is_song else DOCK+Vector2i(2,0),[key],1.5,48,22)
	b.mission.add_actor_locator("board_song" if is_song else "board_dai",key)
	if not first_rescued:
		first_rescued=true; pursuit_left=20
		b.msg("北面六名追兵20秒后追向获救者。可留兵守法场、另队先开巷口；追兵是开局已有部队，可提前截住。",8)
	if living(song_freed) and living(dai_freed):
		b.mission.set_title("护送 · 开路与断后")
		b.mission.set_objective("二人已救下。西巷短而狭，南巷较宽有骑弓截兵；自由选路或改道。可先经白龙庙会水军，再分别下令登船。护卫留在岸边断后，让出登船旗标附近的通道。")
		b.mission.add_map_locator("西巷近路",Vector2i(18,34))
		b.mission.add_map_locator("南巷宽路",Vector2i(27,36))
		b.mission.add_map_locator("可选 · 宋戴与张顺张横到白龙庙",BAILONG)
		b.mission.add_action("rally_dock","好汉 · 码头收队",DOCK+Vector2i(0,-2),NAMED,0.7,64)
func on_mission_action(b,key: String,actor) -> void:
	if key.begins_with("cache_"):
		var index: int=int(key.trim_prefix("cache_"))
		if index<0 or index>=2 or cache_taken[index]: return
		if not active(caches[index]) or _enemy_near(b,caches[index].position,170):
			_retry(b,key,"先清开补给棚170距离内的官军，再派人领取。")
			return
		cache_taken[index]=true
		caches[index].display_name="补给棚 · 已领取"
		b.add_resources(100,60)
		b.mission.mark(key,"夺得一处补给，100金60木已入账，可在任一接应营补军。")
		return
	match key:
		"west_street","south_lane":
			if alarm: return
			b.mission.mark(key,"李逵西街就位。" if key=="west_street" else "燕顺南巷接应就位。")
			if b.mission.has_event("west_street") and b.mission.has_event("south_lane"):
				b.mission.add_action("first_axes","李逵 · 排头动手",SCAFFOLD+Vector2i(-2,3),["li_kui"],0.6,64)
		"first_axes": _uprising(b,actor)
		"free_song":
			if execution_halted and song_freed==null: _free(b,true)
		"free_dai":
			if execution_halted and dai_freed==null: _free(b,false)
		"board_song","board_dai":
			var expected: Unit=song_freed if key=="board_song" else dai_freed
			if actor!=expected or not active(actor): return
			if _enemy_near(b,actor.position,150):
				_retry(b,key,"登船处仍有近身官军，请护卫清开150距离内的追兵。")
				return
			actor.resolve_story("embarked")
			b.mission.mark(key,actor.display_name+"已活着登船。")
		"rally_dock":
			rally=true
			b.mission.mark("rally_dock","码头已收队。玩家带回的具名好汉会在安全登船点上船，其余人仍需亲自指挥撤回。")
func _produce(b,delta: float) -> void:
	if not alarm or not active(post) or enemy_produced>=8: return
	train_left-=delta
	if train_left>0: return
	var key: String="guan_gong" if enemy_produced%3==2 else "guan_dao"
	var price: Dictionary=b._defs.liang_gong if key=="guan_gong" else b._defs.liang_dao
	if not b.faction_spend(1,int(price.cost_gold),int(price.cost_wood)):
		train_left=1; return
	var u: Unit=_guard(b,key,CITY_POST+Vector2i(-2,2))
	u.passive=false
	u.order_amove(_pursuit_target(b))
	reinforcements.append(u)
	enemy_produced+=1
	enemy_spent_gold+=int(price.cost_gold); enemy_spent_wood+=int(price.cost_wood)
	train_left=float(price.train_time)
func _pursuit_target(b) -> Vector2:
	for u in [song_freed,dai_freed]:
		if active(u): return u.position
	return b.map.cell_to_world(SCAFFOLD+Vector2i(0,5))
func _can_continue_rescue(b) -> bool:
	if living(song_freed) and living(dai_freed): return true
	if b.units.any(func(u): return active(u) and u.faction==0 and u.key in RESCUERS): return true
	for camp in camps:
		if not active(camp): continue
		if not camp._train_queue.is_empty(): return true
		for key in b._trainable_keys(camp):
			var d: Dictionary=b._defs[key]
			if b.can_afford(int(d.get("cost_gold",0)),int(d.get("cost_wood",0))) and b.used_pop()+int(d.get("pop",0))<=b.pop_cap: return true
	return false
func _finish(b) -> void:
	if victory or b.phase!=b.Phase.FIGHT: return
	if not living(song_freed) or not living(dai_freed) or song_freed.story_outcome!="embarked" or dai_freed.story_outcome!="embarked": return
	victory=true
	if NAMED.all(func(key):
		var u=named_units.get(key)
		return living(u) and u.story_outcome=="embarked"):
		b.mission.mark("jiangzhou_named_survive","六名具名好汉均已由玩家带回码头，活着脱险。")
	b.mission.mark("all_embarked","宋江、戴宗均已活着登船，救援队开船离开江州。")
	b.win("宋江、戴宗活着登船，众好汉护着二人离开江州，往梁山而去。")
func process(b,delta: float) -> void:
	elapsed+=delta
	_produce(b,delta)
	if first_rescued and not pursuit_sent: pursuit_left-=delta
	if not execution_halted:
		exec_left=maxf(0,exec_left-delta)
		if executioners.all(func(u): return not active(u)):
			execution_halted=true
			b.mission.mark("execution_halted","两名刽子手均被打倒，行刑已中断。")
			b.mission.set_title("救人 · 分别解缚")
			for rec in [["free_song",-1,"宋江"],["free_dai",1,"戴宗"]]:
				b.mission.add_action(rec[0],"好汉 · 救下"+rec[2],SCAFFOLD+Vector2i(rec[1],1),RESCUERS,1.3,130,22)
		elif exec_left<=0:
			b.lose("行刑限时已到，两名刽子手未被全部打倒。下次可让补兵与进场同时进行，先集火刽子手再救人。"); return
	strategy_t-=delta
	if strategy_t>0: return
	strategy_t=0.25
	if not _can_continue_rescue(b):
		b.lose("救援队已覆没，接应营也无法再补兵，无人能解救囚徒。下次请保留后队或补兵钱粮。"); return
	if not alarm:
		for u in b.units:
			if active(u) and u.faction==0 and not u.is_building and is_instance_valid(u._target) and u._target.faction==1:
				_uprising(b,u); break
	if first_rescued and not pursuit_sent:
		if pursuit_left<=0:
			pursuit_sent=true
			for u in pursuit:
				if active(u): u.passive=false; u.order_amove(_pursuit_target(b))
			b.mission.mark("jiangzhou_rear_pursuit","北面原有追兵开始行动，护住获救者，安排后队断后。")
	if not meeting and _near(b,song_freed,BAILONG,130) and _near(b,dai_freed,BAILONG,130) and _near(b,named_units.get("zhang_shun"),BAILONG,130) and _near(b,named_units.get("zhang_heng"),BAILONG,130):
		meeting=true
		b.mission.mark("bailong","宋江、戴宗实际抵达白龙庙，与沿江寻来的张顺、张横会合；继续带到码头登船。")
	if rally:
		for key in NAMED:
			var u=named_units.get(key)
			if _near(b,u,DOCK,120) and not _enemy_near(b,u.position,150): u.resolve_story("embarked")
	if living(song_freed) and living(dai_freed) and song_freed.story_outcome=="embarked" and dai_freed.story_outcome=="embarked" and not is_instance_valid(depart_button):
		b.mission.set_title("二人已脱险 · 开船或收队")
		b.mission.set_objective("核心营救已达成。可立即开船；要全员脱险印，先让好汉办理码头收队，再亲自带六人撤回安全登船点。")
		depart_button=Button.new(); depart_button.text="开船通关 · 宋江戴宗已登船"
		depart_button.pressed.connect(func(): _finish(b))
		b.mission._buttons.add_child(depart_button)
func on_unit_died(b,u) -> void:
	if u==song_bound or u==song_freed or u==dai_bound or u==dai_freed:
		b.lose(u.display_name+"遇害，营救失败。请用军队清开退路并保护获救者。"); return
	if not alarm and u.faction==1 and living(u._killer) and u._killer.faction==0: _uprising(b,u._killer)
	if u==post: b.mission.mark("jiangzhou_post_destroyed","巡防营已拆，停止该处后续补军；已出场官军仍在。")
	if u==named_units.get(u.key):
		b.mission.mark("jiangzhou_named_lost",u.display_name+"阵亡，仍可完成二人的核心营救。")
		b.mission.miss_story_goal("named_survive","已有具名好汉阵亡。")
		if u.key in ["zhang_shun","zhang_heng"] and not meeting:
			b.mission.miss_story_goal("bailong_meeting","接应好汉已阵亡，可直接护送宋江戴宗到码头完成核心营救。")
func top_status(_b) -> String:
	return "江州劫法场 · "+("行刑剩余%d秒"%ceili(exec_left) if not execution_halted else "行刑已中断")+" · 补给%d/2 · 巡防补军%d/8"%[cache_taken.count(true),enemy_produced]
