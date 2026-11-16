extends "res://tools/gao_rts_play.gd"
var escort_ids: Array=[]
var escort_deaths: Array=[]
var escort_phases: Array=[]
var flagship_origin := Vector2.ZERO
var escorted_distance := 0.0
var before_launch_count := -1
func _guard_died(u) -> void:
	escort_deaths.append(u.entity_id)
func _economy_gao(b) -> void:
	super._economy_gao(b)
	var l=b.level
	if escort_ids.is_empty():
		escort_ids=l._flagship_guards().map(func(u): return u.entity_id)
		flagship_origin=l.flagship.position
		for u in l._flagship_guards(): u.died.connect(_guard_died)
	var phase: String=l._flagship_guard_plan(b,-1).phase
	if phase not in escort_phases: escort_phases.append(phase)
	if not l.waves[2].sent: before_launch_count=l._count(l.water_groups[2])
	if l.waves[2].sent and not l._flagship_guards().is_empty():
		escorted_distance=maxf(escorted_distance,l.flagship.position.distance_to(flagship_origin))
func _attack(b,army: Array,target,cell: Vector2i) -> void:
	# A normal defensive player plan: hold the fleet at the harbor until the
	# final scheduled launch, then use the inherited counterattack orders.
	if not army.is_empty() and army[0].movement_profile=="water" and not b.level.waves[2].sent:
		_click(b,army,Vector2i(39,45),true)
		return
	super._attack(b,army,target,cell)
func _fixture() -> void:
	var b=await _start("",4)
	b.set_process(false);b.set_physics_process(false);b.camera.set_process(false)
	for unit in b.units: unit.set_physics_process(false)
	var l=b.level
	var chain: Array=l.water_groups[1]
	var chain_positions: Array=chain.map(func(u): return u.position)
	l._send_wave(b,1)
	var berths := {}
	for ship in chain: berths[b.map.world_to_cell(ship._amove_dest)]=true
	check(berths.size()==5 and l.CHAIN_FRONT.all(func(cell): return berths.has(cell))
		and chain.all(func(u): return u._state==u.ST_AMOVE)
		and chain_positions==chain.map(func(u): return u.position),"second wave uses five distinct navigable attack-move berths without moving the ships directly")
	var guards: Array=l._flagship_guards()
	var ids: Array=l.water_groups[2].map(func(u): return u.entity_id)
	check(guards==[l.water_groups[2][4],l.water_groups[2][5]] and ids.size()==6,"only two original rear ships become guards; third fleet still has six identities")
	check(l._flagship_guard_plan(b,-1).phase=="muster" and l.Naval.clear_water(b.map,b.map.world_to_cell(l._flagship_guard_plan(b,-1).goal),25),"muster uses local navigable water beside the original flagship")
	var before: Array=[guards[0].position,guards[1].position,guards[0].hp,guards[1].hp,b.faction_res[1].duplicate()]
	l._flagship_guard_orders(b)
	check(guards.all(func(u): return u._state==u.ST_AMOVE) and before==[guards[0].position,guards[1].position,guards[0].hp,guards[1].hp,b.faction_res[1]],"muster uses ordinary orders without moving, healing or paying for replacement units")
	var serials: Array=guards.map(func(u): return u._order_serial)
	l._flagship_guard_orders(b)
	check(serials==guards.map(func(u): return u._order_serial),"unchanged formation does not reset active orders")
	var u=guards[0]
	u.position=l._flagship_guard_plan(b,-1).goal
	l._flagship_guard_orders(b)
	check(u._state==u.ST_IDLE and u.stance==u.STANCE_DEFEND and u._amove_dest==Vector2.ZERO and u._idle_push_t==0,"arrived guard stays near the flagship without stale attack-move push")
	var opponent=b.find_unit("ruan_xiaoqi_boat")
	opponent.position=u.position+Vector2(40,0)
	u.order_attack(opponent)
	var serial: int=u._order_serial
	l._flagship_guard_orders(b)
	check(u._target==opponent and u._order_serial==serial,"visible local engagement takes precedence over formation orders")
	opponent._invis_t=5
	l._flagship_guard_orders(b)
	check(u._target==null,"invisible opponent is not pursued by formation logic")
	opponent._invis_t=0;u.order_attack(opponent);u._taunt_t=2;u._taunt_src=opponent;serial=u._order_serial
	l._flagship_guard_orders(b)
	check(u._order_serial==serial and u._target==opponent,"forced taunt remains under Unit control")
	u._taunt_t=0;u._taunt_src=null;u.order_stop()
	serials=guards.map(func(ship): return ship._order_serial)
	l._send_wave(b,2)
	check(serials==guards.map(func(ship): return ship._order_serial) and l._flagship_guard_plan(b,-1).phase=="escort" and l.flagship._state==l.flagship.ST_AMOVE,"scheduled launch sends flagship while preserving its dedicated guards")
	var old_goal: Vector2=l._flagship_guard_plan(b,-1).goal
	l.flagship.position+=Vector2(0,640)
	l._flagship_guard_orders(b)
	check(u._amove_dest==l._flagship_guard_plan(b,-1).goal and old_goal.distance_to(u._amove_dest)>500,"escort destination follows actual flagship position")
	l.flagship_disabled=true;l.flagship.story_outcome="subdued";l.flagship.hp=1
	check(l._flagship_guard_plan(b,-1).phase=="defend" and l._flagship_guards().size()==2,"disabled flagship retains its original defending ships")
	l.flagship.hp=0
	check(l._flagship_guard_plan(b,-1).phase=="advance" and l._flagship_guard_plan(b,-1).goal==b.map.cell_to_world(l.SEA_FRONT),"sunk flagship sends surviving guards to known front without hiding or disappearing")
	check(ids==l.water_groups[2].map(func(ship): return ship.entity_id) and l.produced==[0,0],"role changes neither replace fleet identities nor add production")
	root.get_node("Localize").set_language("en",false)
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	b.fog=false;u.fog_visible=true;u.show();b._set_inspect(u)
	b.hud.update_selection_panel(b.selection);b.hud._refresh_panel()
	b.center_camera_cell(b.map.world_to_cell(u.position))
	await process_frame
	await RenderingServer.frame_post_draw
	var label: Label=b.hud._info_stats
	check("Flagship escort" in label.text and b.hud._info_box.get_global_rect().encloses(label.get_global_rect()) and label.get_minimum_size().y<=label.size.y+1,"English escort role fits actual narrow inspector")
	root.get_texture().get_image().save_png(out_dir+"/en_guard_960.png")
	await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	out_dir="res://.godot/gao-flagship-escort"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if OS.get_environment("FLAGSHIP_LIVE_ONLY")!="1": await _fixture()
	var fixture_checks := checks
	if OS.get_environment("FLAGSHIP_FIXTURE_ONLY")!="1":
		root.get_node("Localize").set_language("zh_CN",false)
		build_cells=[Vector2i(24,26),Vector2i(26,40),Vector2i(14,42),Vector2i(10,43),Vector2i(21,40),Vector2i(26,23),Vector2i(9,31),Vector2i(15,24)]
		route="assault"
		var b=await _start("",4)
		Engine.time_scale=4
		print("[gao-escort] time_scale=",Engine.time_scale)
		await _play_gao(b)
		check(before_launch_count==6,"defensive route leaves original third fleet intact until its scheduled launch")
		check("muster" in escort_phases and "escort" in escort_phases and escorted_distance>320,"actual guard route includes muster and a moving flagship after launch")
		check(escort_ids.size()==2 and escort_deaths.size()==2 and escort_ids.all(func(id): return escort_deaths.count(id)==1),"both original guards die once through real combat")
		play_metrics.merge({"guard_ids":escort_ids,"guard_deaths":escort_deaths,"guard_phases":escort_phases,"escorted_distance":escorted_distance,"third_before_launch":before_launch_count})
		await _dispose(b)
	Engine.time_scale=1
	var report={"passed":failures.is_empty(),"checks":checks,"fixture_checks":fixture_checks,"failures":failures,"metrics":play_metrics,"scope":"explicit guard fixtures and/or defensive actual economy/combat route; not full restore or human/performance acceptance"}
	FileAccess.open(out_dir+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[gao-escort] ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
