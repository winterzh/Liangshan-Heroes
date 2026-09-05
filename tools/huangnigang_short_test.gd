extends "res://tools/zhujiazhuang_rts_test.gd"
## HNS_CASE=wine|force|boundaries|all. Live routes use actual player orders.
var cases: Array=[]
var visual:=false
var folder:="res://.godot/huangnigang_short"
var boundaries_done:=false

func until(predicate: Callable, seconds: float) -> bool:
	var t:=0.0
	while not predicate.call() and t<seconds:
		await _wait(0.1); t+=0.1
	return bool(predicate.call())

func action(b,u,key: String,seconds:=35.0) -> bool:
	if not alive(u) or not b.mission.actions.has(key): return false
	var event:="action:%s:%s"%[b.mission.stage_id,key]
	if key=="place_dates": event="place_dates" # The convoy can arrive during preparation.
	_action(b,u,key)
	var ok:=await until(func(): return b.mission.has_event(event) or b.phase==b.Phase.END,seconds)
	if not b.mission.has_event(event): print("[hns-action] timeout ",key," stage=",b.mission.stage_id," actor=",u.position," exposure=",b.level.exposure," controls=",b.mission.actions.keys())
	return ok and b.mission.has_event(event)

func shot(b,name: String,cell: Vector2i) -> void:
	if not visual: return
	b.camera.zoom=Vector2.ONE
	b.center_camera_cell(cell)
	await process_frame
	await RenderingServer.frame_post_draw
	if b.phase==b.Phase.FIGHT:
		check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"short chapter task panel avoids command cards")
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"saved "+name)

func _live(name: String) -> void:
	var b=await _start("",0)
	var l=b.level
	var start_orders:=orders
	var combat: Dictionary={}
	check(l.st==l.MARCH and l.convoy.size()==15 and not b._smoke and not b.economy,"convoy actually approaches while player prepares")
	var chao=b.find_unit("chao_gai")
	var before: Vector2=chao.position
	var serial: int=chao._order_serial
	var select_button=b.mission._buttons.get_children().filter(func(n): return n is Button and n.text=="选中 · 晁盖")
	if not select_button.is_empty(): select_button[0].pressed.emit()
	check(select_button.size()==1 and b.selection==[chao] and before==chao.position and serial==chao._order_serial,"selection shortcut selects without issuing movement")
	await shot(b,name+"_start",l.TOP)
	if name=="wine":
		check(await action(b,chao,"place_dates"),"Chao places the actual seven carts during approach")
		check(await until(func(): return l.st==l.INQUIRY,30),"convoy arrives at real inquiry")
		check(await action(b,b.find_unit("liu_tang"),"answer_yang"),"Liu answers Yang at the actual inquiry point")
		check(await action(b,b.find_unit("bai_sheng"),"bring_wine"),"Bai carries wine to the actual sale area")
		if l.st!=l.WINE:
			cases.append({"route":name,"failed_stage":l.st}); await _dispose(b); return
		_click(b,[b.find_unit("wu_yong")],l.WU_STATION)
		_click(b,[b.find_unit("bai_sheng")],l.BAI_STATION)
		check(await action(b,b.find_unit("liu_tang"),"taste_wine"),"first wine trial uses real Liu movement")
		check(await until(func(): return l._team_ready(b),20),"Wu and Bai can preposition without false suspicion")
		await shot(b,"wine_ready",l.SALE_WINE)
		check(await action(b,b.find_unit("liu_tang"),"distract_yang"),"Liu initiates the actual cooperative distraction")
		check(await until(func(): return l.drug_done or l.force_started,8) and l.drug_done,"three real participants complete one wine handoff")
		check(b.kills==0 and l.convoy.all(func(u): return u.hp>0 and u.story_outcome=="unconscious"),"all fifteen convoy members survive unconscious")
	else:
		check(await until(func(): return l.st==l.INQUIRY,30),"force player waits for the convoy to reach the hill")
		b.center_camera_cell(l.TOP)
		b.select_members(l.actors.filter(func(u): return alive(u)),false)
		b._issue_order(b.to_screen(l.yang.position),false); orders+=1
		check(await until(func(): return l.force_started,35),"actual player attack starts the force route")
		if not l.force_started:
			cases.append({"route":name,"failed_stage":l.st}); await _dispose(b); return
		var t:=0.0
		while b.phase==b.Phase.FIGHT and l.convoy.any(func(u): return alive(u)) and t<100:
			var guards: Array=l.convoy.filter(func(u): return alive(u))
			var fighters: Array=l.actors.filter(func(u): return alive(u))
			if not guards.is_empty() and not fighters.is_empty():
				b.select_members(fighters,false)
				b._issue_order(b.to_screen(guards[0].position),false); orders+=1
			await _wait(2); t+=2
		check(l.convoy.all(func(u): return u.hp>0 and u.story_outcome=="subdued") and b.phase==b.Phase.FIGHT,"real force combat subdues the convoy without killing Yang")
		print("[hns-combat] phase=",b.phase," actors=",l.actors.map(func(u): return [u.key,u.hp,b.map.world_to_cell(u.position)] if is_instance_valid(u) else ["fallen"])," guards=",l.convoy.map(func(u): return [u.key,u.hp,u.story_outcome]))
		combat={"actors":l.actors.map(func(u): return {"key":u.key,"hp":u.hp,"max_hp":u.max_hp} if is_instance_valid(u) else {"fallen":true}),"guards":l.convoy.map(func(u): return {"key":u.key,"hp":u.hp,"outcome":u.story_outcome})}
		await shot(b,"force_battle",l.TOP)
	if b.phase==b.Phase.END:
		cases.append({"route":name,"failed_phase":true}); await _dispose(b); return
	check(not b.mission.actions.has("cargo_group_plan") and not b.mission.actions.has("stage_0"),"cargo needs no planning or staging chores")
	var carriers: Array=l.actors.filter(func(u): return alive(u)).slice(0,3)
	if carriers.size()!=3:
		check(false,"three carriers survive live route"); await _dispose(b); return
	for i in range(3): _action(b,carriers[i],"force_take_%d_0"%i)
	check(await until(func(): return l.cargo.size()==3 or b.phase==b.Phase.END,35) and l.cargo.size()==3,"three different player-assigned companions pick up the original loads")
	if l.cargo.size()!=3:
		print("[hns-cargo] ",l.cargo," actions=",b.mission.actions.keys()); await _dispose(b); return
	var idle_positions: Array=carriers.map(func(u): return u.position)
	await _wait(1)
	check(range(3).all(func(i): return carriers[i].position.distance_to(idle_positions[i])<3),"carriers wait for a separate exit order")
	await shot(b,name+"_cargo",l.TOP)
	for i in range(3): _action(b,carriers[i],"force_deliver_%d_0"%i)
	await _wait(0.5)
	check(carriers.all(func(u): return u._state==u.ST_MOVE),"all three loaded carriers walk concurrently on player orders")
	var reserves: Array=l.actors.filter(func(u): return alive(u) and not u.has_meta("carrying_tribute"))
	if not reserves.is_empty(): _click(b,reserves,l.GATE_W+Vector2i(-1,0))
	check(await until(func(): return l.victory or b.phase==b.Phase.END,55) and l.victory,"actual cargo and all companions reach the west exit")
	print("[hns-exit] ",name," ",l.actors.map(func(u): return [u.key,u.hp,b.map.world_to_cell(u.position),u._state] if is_instance_valid(u) else ["fallen"])," phase=",b.phase," stage=",l.st)
	var result: Dictionary=b.mission.result_snapshot(l.victory)
	check(l.delivered==3 and l.bundles.all(func(u): return b.units.has(u) and u.visible),"same three loads are visible and delivered once")
	if name=="wine": check(result.story_complete,"wine route earns all four optional story goals")
	else: check(not result.story_complete and b.mission.has_event("huangnigang_all_safe")==l.actors.all(func(u): return alive(u)),"force route credits actual survivors without inventing wine or all-safe goals")
	await shot(b,name+"_result",l.GATE_W)
	cases.append({"route":name,"orders":orders-start_orders,"seconds":b.mission.total_game_seconds,"result":result,"events":b.mission.events.keys(),"alive":l.actors.filter(func(u): return alive(u)).size(),"combat":combat})
	await _dispose(b)

func _wine_fixture():
	var b=await _start("",0)
	b.set_process(false); b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	var l=b.level
	l._place_jujube_carts(b)
	b.mission.mark("place_dates","explicit boundary fixture")
	b.mission.mark("merchant_identity_confirmed","explicit boundary fixture")
	var bai=l._ensure_bai(b,true)
	bai.set_physics_process(false)
	l.st=l.WINE; l.clean_trial=true
	b.mission.mark("bring_wine","explicit boundary fixture")
	l._begin_team_setup(b,false)
	b.find_unit("liu_tang").position=b.map.cell_to_world(l.DISTRACT)
	b.find_unit("wu_yong").position=b.map.cell_to_world(l.WU_STATION)
	bai.position=b.map.cell_to_world(l.BAI_STATION)
	l.yang.position=b.map.cell_to_world(Vector2i(28,21))
	return b

func _start_fixture_distraction(b) -> void:
	_action(b,b.find_unit("liu_tang"),"distract_yang")
	b.mission.tick(1.0)

func _boundaries() -> void:
	var b=await _start("",0)
	var ArtDB=root.get_node("Art")
	var replacement=ArtDB.campaign_object_texture(b.level.TRIBUTE_ART)
	check(replacement!=null and b.level.bundles.all(func(u): return not u.has_meta("campaign_environment_route") and u.setup_def.campaign_object==b.level.TRIBUTE_ART and ArtDB.unit_texture(u.key,u.art_variant)==replacement),"ground and selected load use the versioned transparent prop")
	check(b.level.actors.all(func(u): return u._campaign_carried_texture("tribute_load")==replacement),"all seven carriers use the same native-alpha prop")
	b.set_process(false); b.set_physics_process(false)
	for u in b.units: u.set_physics_process(false)
	var l=b.level
	b.find_unit("chao_gai").position=b.map.cell_to_world(l.DATES)
	l.yang.position=b.map.cell_to_world(l.TOP)
	for i in range(3): l.bundles[i].position=b.map.cell_to_world(l.TOP+Vector2i(i,0))
	_action(b,b.find_unit("chao_gai"),"place_dates"); b.mission.tick(0.4)
	var generation: int=b.mission._generation
	l.process(b,0)
	b.mission.tick(0.7)
	check(l.st==l.INQUIRY and b.mission._generation==generation and b.mission.has_event("place_dates") and l.jujube_carts.size()==7,"convoy arrival preserves an in-progress player preparation order")
	await _dispose(b)
	b=await _wine_fixture(); l=b.level
	var liu=b.find_unit("liu_tang")
	var wu=b.find_unit("wu_yong")
	var bai=b.find_unit("bai_sheng")
	check(bai._campaign_carried_texture("tribute_load")==replacement,"late-arriving Bai uses the same new carried prop")
	_start_fixture_distraction(b)
	check(l.wine_step=="cooperate","real distraction command starts the frozen cooperation fixture")
	wu.position=b.map.cell_to_world(l.GATE_E)
	l.process(b,2)
	check(not l.drug_done and l.team_t==0 and l.attention_left<22,"missing partner prevents wine completion and time still runs")
	b.select_single(liu,false); b._order_stop()
	l.process(b,0)
	check(l.wine_step=="attention" and l.clean_trial and not l.drug_done,"actual stop cancels distraction without making the player repeat good wine")
	_start_fixture_distraction(b)
	var before_clock: float=l.rest_t
	l.process(b,23)
	check(l.wine_step=="attention" and l.clean_trial and l.rest_t>=before_clock+23,"expired cooperation window does not refill the total rest clock")
	wu.position=b.map.cell_to_world(l.WU_STATION)
	_start_fixture_distraction(b)
	l.process(b,1)
	wu.position=b.map.cell_to_world(l.GATE_E)
	l.process(b,0.1)
	check(l.team_t==0 and not l.drug_done,"partner departure resets incomplete handoff progress")
	wu.position=b.map.cell_to_world(l.WU_STATION)
	l.process(b,3.1)
	check(l.drug_done and l.convoy.size()==15 and l.convoy.all(func(u): return u.hp>0 and u.story_outcome=="unconscious"),"retry with all three present completes the same nonlethal convoy")
	# Exact original cargo nodes, actual mission input, deliberate death injection.
	var first=l.bundles[0]
	var carrier=b.find_unit("chao_gai")
	carrier.position=b.map.cell_to_world(l._bundle_claim_cell(b,0))
	_action(b,carrier,"force_take_0_0"); b.mission.tick(0.7)
	check(l.cargo.get(0)==carrier and not b.units.has(first) and not first.visible,"picked load leaves world queries while keeping its original scene node")
	check(not b.mission.actions.force_take_1_0.actors.has(carrier.key),"loaded carrier cannot be assigned a second load")
	l._force_take_cargo(b,"force_take_0_0",carrier,0)
	check(l.cargo.size()==1 and l.delivered==0,"duplicate pickup callback cannot duplicate cargo")
	var drop_at: Vector2=carrier.position
	carrier.take_damage(10000,null,false,true)
	check(b.units.has(first) and first.visible and first.position.distance_to(drop_at)<33 and not l.force_started,"real carrier death drops the same load without erasing the completed wine route")
	liu.position=b.map.cell_to_world(l._bundle_claim_cell(b,0))
	_action(b,liu,"force_take_0_1"); b.mission.tick(0.7)
	check(l.cargo.get(0)==liu and l.bundles[0]==first,"another survivor can take over the dropped original load")
	liu.position=b.map.cell_to_world(l.GATE_W+Vector2i(0,-1))
	_action(b,liu,"force_deliver_0_1"); b.mission.tick(0.7)
	l._force_deliver_cargo(b,"force_deliver_0_1",liu,0)
	check(l.delivered==1 and b.units.has(first) and first.visible and not liu.has_meta("carrying_tribute"),"delivery resolves once and restores the original ground load")
	for i in [1,2]:
		var u=wu if i==1 else bai
		u.position=b.map.cell_to_world(l._bundle_claim_cell(b,i))
		_action(b,u,"force_take_%d_0"%i); b.mission.tick(0.7)
		u.position=b.map.cell_to_world(l.GATE_W+Vector2i(0,i-1))
		_action(b,u,"force_deliver_%d_0"%i); b.mission.tick(0.7)
	l._withdraw_tick(b)
	check(l.delivered==3 and l.st==l.WITHDRAW and not l.victory,"cargo arrival does not silently abandon distant living companions")
	_action(b,bai,"withdraw_now"); b.mission.tick(0.7)
	l._withdraw_tick(b)
	check(l.victory and not b.mission.has_event("huangnigang_all_safe"),"actual early-departure command clears the core without inventing all-safe credit")
	await _dispose(b)
	b=await _wine_fixture(); l=b.level
	var chao=b.find_unit("chao_gai")
	chao.position=l.bundles[0].position+Vector2(20,0)
	check(l._find_suspicious(b).has("chao_gai") and not l._find_suspicious(b).has("wu_yong"),"wine station corridors do not authorize unrelated people approaching cargo")
	l._suspicion_tick(b,5)
	check(l.force_started and l.st==l.FORCE and not l.drug_done,"full suspicion produces the live force fallback")
	await _dispose(b)
	b=await _wine_fixture(); l=b.level
	l.rest_t=99
	l.process(b,2)
	check(l.force_started and not l.drug_done,"total wine timeout still forces a consequential fallback")
	await _dispose(b)
	b=await _start("",0); l=b.level
	var old_id: int=b.get_instance_id()
	l.bundles[0].take_damage(10000,null,false,true)
	check(b.phase==b.Phase.END and not l.victory,"destroyed objective produces an explicit loss")
	var retry=b.hud.find_children("*","Button",true,false).filter(func(n): return n.text=="重打本关")
	if retry.size()==1: retry[0].pressed.emit()
	await until(func(): return is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id,10)
	b=current_scene
	check(retry.size()==1 and is_instance_valid(b) and b.get_instance_id()!=old_id and b.level.id()=="level1" and b.level.bundles.size()==3 and b.level.delivered==0,"actual restart reloads three fresh loads and chapter state")
	await _dispose(b)
	b=await _start("skirmish",4)
	check(not b._defs.chao_gai.has("campaign_tribute_object") and not b._defs.treasure_cart.has("campaign_object"),"short chapter art overrides do not leak into defense definitions")
	await _dispose(b)
	boundaries_done=true

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	Engine.time_scale=4
	var selected:=OS.get_environment("HNS_CASE")
	if selected=="": selected="all"
	visual=OS.get_environment("HNS_VISUAL")=="1" and DisplayServer.get_name()!="headless"
	folder+="/"+selected+("_rendered" if visual else "")
	if visual:
		root.size=Vector2i(1280,720) if OS.get_environment("HNS_SIZE")=="1280" else Vector2i(1440,900)
		DisplayServer.window_set_size(root.size)
		if root.size.x==1280: folder+="_1280"
	DirAccess.make_dir_recursive_absolute(folder)
	for name in ["wine","force"]:
		if selected in ["all",name]: await _live(name)
	if selected in ["all","boundaries"]: await _boundaries()
	var expected:=2 if selected=="all" else (0 if selected=="boundaries" else 1)
	var boundary_ok:=boundaries_done if selected in ["all","boundaries"] else true
	var passed:=selected in ["all","wine","force","boundaries"] and failures.is_empty() and boundary_ok and cases.size()==expected and cases.all(func(row): return row.has("result") and row.result.core_cleared)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":passed,"failures":failures,"cases":cases,"boundaries_done":boundaries_done},"\t"))
	print("[hns-result] ",checks," checks, failures=",failures)
	quit(0 if passed else 1)
