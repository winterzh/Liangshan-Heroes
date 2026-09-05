extends "res://tools/zhujiazhuang_rts_test.gd"
## KH_CASE=wine|direct|standing|all. Real routes never inject stats,
## positions, events or skill effects. Frozen boundary fixtures are separate.
var cases: Array=[]
var folder:="res://.godot/kuaihuolin_short"
var visual:=false
var cast_counts:={}
var charge_travel:=0.0
var min_hp:=INF
var execution_speed:=4.0

func _until(predicate: Callable,seconds: float) -> bool:
	var t:=0.0
	while not predicate.call() and t<seconds:
		await _wait(0.1); t+=0.1
	return bool(predicate.call())

func _move(b,u,p: Vector2) -> void:
	b.select_single(u,false); b.minimap_order(p,false); orders+=1

func _attack(b) -> void:
	b.select_single(b.level.wu,false)
	b._issue_order(b.to_screen(b.level.menshen.position),false)
	orders+=1

func _cast(b,slot: int) -> bool:
	var u=b.level.wu
	if not alive(u) or not u.slot_ready(slot) or u._cast_t>0: return false
	b.select_single(u,false); b._cast_ability_slot(slot)
	await _until(func(): return u._cast_t<=0,1.2)
	if not u.slot_ready(slot):
		cast_counts[slot]=int(cast_counts.get(slot,0))+1
		orders+=1
		return true
	return false

func _action_done(b,u,key: String,seconds:=55.0) -> bool:
	if not b.mission.actions.has(key): return false
	var event:="action:%s:%s"%[b.mission.stage_id,key]
	_action(b,u,key)
	var ok:=await _until(func(): return b.mission.has_event(event) or b.phase==b.Phase.END,seconds)
	if not b.mission.has_event(event): print("[kh-action-timeout] ",key," ",u.position," ",u._state," ",b.mission.active_action_id)
	return ok and b.mission.has_event(event)

func _shot(b,name: String) -> void:
	if not visual: return
	b.center_camera_cell(b.map.world_to_cell(b.level.wu.position))
	b.camera.zoom=Vector2.ONE*1.25
	await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"saved live "+name)

func _live(name: String) -> void:
	var b=await _start("",6)
	var l=b.level
	orders=0; cast_counts={}; charge_travel=0; min_hp=l.wu.hp
	check(l.story_contract_version()==2 and not b._smoke and not b.economy,name+" starts current player-controlled short chapter")
	check(l.wu.max_hp==440 and l.menshen.max_hp==800 and l.shi.is_noncombat,name+" retains authored duel stats and vulnerable noncombat companion")
	check(b.mission.actions.has("drink_3") and b.mission.actions.has("provoke") and b.mission.actions.has("practice_step"),"all preparation choices are available at the start")
	var start: Vector2=l.shi.position
	_move(b,l.shi,b.map.cell_to_world(Vector2i(44,25)))
	if name=="wine":
		for i in range(4):
			check(await _action_done(b,l.wu,"drink_%d"%i),"player walks to tavern and drinks "+str(i))
			if i==1:
				check(l.st==l.ROAD and not b.mission.has_event("road_step_practiced"),"second drink does not force practice")
				check(await _action_done(b,l.wu,"practice_step"),"player explicitly chooses practice on the road")
				await _cast(b,1)
				_move(b,l.wu,l.drill_origin+Vector2(0,-130))
				check(await _until(func(): return b.mission.has_event("road_step_practiced"),8),"practice completes only after actual movement out of the circle")
				check(l.wu.hp==l.wu.max_hp,"optional practice deals no damage")
		await _shot(b,"wine_road")
		check(await _action_done(b,l.wu,"provoke"),"four-tavern route explicitly provokes Menshen")
	else:
		# Attack the actual actor through the player hit test; no phase callback.
		_move(b,l.wu,b.map.cell_to_world(Vector2i(48,19)))
		check(await _until(func(): return l.wu.position.distance_to(l.menshen.position)<155,40),name+" walks to the shop")
		check(l.st==l.ROAD,"proximity alone does not steal the player's preparation choice")
		_attack(b)
		check(await _until(func(): return l.st==l.SHOWDOWN,8),name+" actual attack opens the duel")
	check(l.shi.position.distance_to(start)>800 and l.shi.hp==l.shi.max_hp,"Shi En actually walks to the safe waiting area")
	check(l.drunk==(4 if name=="wine" else 0),name+" keeps chosen drink count")
	var t:=0.0
	var seen_special:=-1
	var attack_wait:=0.0
	var previous: Vector2=l.menshen.position
	var screenshots:={}
	while l.st==l.SHOWDOWN and b.phase!=b.Phase.END and t<240:
		if l.charge_running: charge_travel+=previous.distance_to(l.menshen.position)
		previous=l.menshen.position
		min_hp=minf(min_hp,l.wu.hp)
		if name!="standing" and l.fist_windup>0 and seen_special!=l.special_index:
			seen_special=l.special_index
			if not screenshots.has(l.special_kind):
				screenshots[l.special_kind]=true
				await _shot(b,name+"_"+l.special_kind+"_tell")
			await _cast(b,1)
			# The rush direction was locked at its tell, before Wu's cast finishes.
			# Read that line, and use the other side when a real obstacle blocks it.
			var direction: Vector2=l.rush_from.direction_to(l.rush_end) if l.special_kind=="rush" else l.menshen.position.direction_to(l.wu.position)
			var origin: Vector2=l.wu.position if l.special_kind=="rush" else l.menshen.position
			var offset: Vector2=direction.orthogonal()*(110 if l.special_kind=="rush" else 86)
			var destination: Vector2=origin+offset
			if not b.map._segment_open(l.wu.position,destination,"land"): destination=origin-offset
			_move(b,l.wu,destination)
		elif l.fist_windup<=0 and not l.charge_running:
			if l.exposed_left>0 and name!="standing":
				if l.wu.position.distance_to(l.menshen.position)<=88:
					await _cast(b,2)
					if not screenshots.has("counter") and b.mission.has_event("mengzhou_signature"):
						screenshots.counter=true; await _shot(b,name+"_counter")
				elif l.wu._state!=l.wu.ST_MOVE:
					_move(b,l.wu,l.menshen.position+l.menshen.position.direction_to(l.wu.position)*64)
			else:
				if l.wu.hp<l.wu.max_hp-60: await _cast(b,3)
				if l.wu.position.distance_to(l.menshen.position)<80:
					await _cast(b,0)
					if name=="standing": await _cast(b,2)
				if attack_wait<=0:
					_attack(b); attack_wait=0.7
		await _wait(0.1); t+=0.1; attack_wait-=0.1
	var standing_loss: bool=name=="standing" and l.wu.hp<=0 and b.phase==b.Phase.END and not l.victory
	check((l.st==l.RETURN_SHOP and l.menshen.story_outcome=="subdued") or standing_loss,name+" reaches a real combat outcome (standing control may lose)")
	if name!="standing":
		check(l.heavy_dodges>0 and l.rush_dodges>0,name+" actually avoids both distinct specials")
		check(charge_travel>100,name+" boss visibly travels through an actual charge")
		check(l.counter_hits>0 and b.mission.has_event("mengzhou_signature"),name+" actual moving W and current-window E earns signature")
	else:
		check(not b.mission.has_event("mengzhou_signature"),"standing attacks cannot counterfeit footwork credit")
	if l.st==l.RETURN_SHOP:
		await _shot(b,name+"_subdued")
		check(await _action_done(b,l.wu,"terms"),name+" player chooses and speaks the three terms")
		check(await _action_done(b,l.shi,"restore_shop"),name+" Shi En actually returns and takes over the shop")
	elif standing_loss:
		check(not b.mission.has_event("terms"),"defeated standing control cannot speak terms")
		check(not b.mission.has_event("restore_shop"),"defeated standing control cannot restore the shop")
	check(b.phase==b.Phase.END and (l.victory or standing_loss),name+" explicitly ends without a timeout or fabricated result")
	var result: Dictionary=b.mission.result_snapshot(l.victory)
	if name=="wine": check(result.story_complete,"wine route earns all four optional story goals")
	else: check(not result.story_complete,"direct route does not invent optional wine/provocation credit")
	var row:={"route":name,"game_seconds":b.mission.total_game_seconds,"orders":orders,"casts":cast_counts,"drinks":l.drunk,"min_hp":min_hp,"final_hp":l.wu.hp,"heavy_dodges":l.heavy_dodges,"rush_dodges":l.rush_dodges,"charge_travel":charge_travel,"counter_hits":l.counter_hits,"victory":l.victory,"events":b.mission.events.keys(),"result":result}
	cases.append(row); print("[kh-live] ",JSON.stringify(row))
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var selected:=OS.get_environment("KH_CASE")
	if selected=="": selected="all"
	visual=OS.get_environment("KH_VISUAL")=="1" and DisplayServer.get_name()!="headless"
	folder+="/"+selected+("_rendered" if visual else "")
	DirAccess.make_dir_recursive_absolute(folder)
	if visual:
		root.size=Vector2i(1440,900); DisplayServer.window_set_size(root.size)
	if not OS.get_environment("KH_SPEED").is_empty(): execution_speed=clampf(float(OS.get_environment("KH_SPEED")),1,4)
	Engine.time_scale=execution_speed
	for name in ["wine","direct","standing"]:
		if selected in ["all",name]: await _live(name)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"time_scale":execution_speed,"cases":cases,"scope":"Real commands and actual combat; not human pacing, fun or performance acceptance."},"\t"))
	print("[kuaihuolin-short] ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() and checks>0 else 1)
