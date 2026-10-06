extends "res://tools/level3_world_restore_qa.gd"
## Real actors, save barrier and session restore across five separate processes.
## Explicit contact/attacker positioning and frozen nonparticipants are fixtures.
## No prisoner teleport, injected damage, stage edits, accelerated clock or victory.
const ROLE_CASES := ["bound", "freed", "midroute", "camp", "verifycamp"]
const ROLE_HANDOFF := "user://rescued_seven_handoff_v4.json"
var role_case := ""
var role_nonce := ""
var before_restore := {}
var saved_state := {}
var command_count := 0

func _freeze(b, members: Array = []) -> void:
	for u in b.units:
		if is_instance_valid(u) and u not in members:
			u.passive=true;u.set_physics_process(false)

func _role_observation(b) -> Dictionary:
	var rows := []
	for u in b.level.prisoners:
		rows.append({"key":u.key,"entity_id":u.entity_id,"hp":u.hp,"max_hp":u.max_hp,
			"speed":u.base_speed,"attack":u.atk,"hero":u.is_hero,"noncombat":u.is_noncombat,
			"captive":u.is_captive,"variant":u.art_variant,"visual_variant":u.visual_art_variant(),
			"position":[u.position.x,u.position.y],"state":u._state,
			"path":Array(u._path).map(func(p):return [p.x,p.y]),"path_index":u._path_i,
			"direction":u.animation_direction,"slots":u.ability_slots.size()})
	return {"prisoners":rows,"freed":b.level.prisoners_freed,"inside_open":b.level.inside_open,
		"manor_fallen":b.level.manor_fallen,"safe_event":b.mission.has_event("zhu_seven_safe"),
		"finish_ready":b.level._finish_ready(),"phase":b.phase}

func _role_routes(b, freed: bool) -> void:
	var art = get_node("/root/Art")
	check("ROLE","original seven persistent entity IDs",b.level.prisoners.size()==7 and b.level.prisoners.all(func(u):return u.entity_id>0))
	for u in b.level.prisoners:
		var v: String = "zhu_wounded_"+u.key if freed else "bound_"+u.key
		check("ROLE","role-derived body after process restore "+u.key,u.visual_art_variant()==v and u.is_captive!=freed and u.is_noncombat)
		check("ROLE","living original actor with attack/slots disabled "+u.key,u.hp>0 and u.hp<=u.max_hp and u.atk==0 and u.ability_slots.is_empty())
		check("ROLE","original serialized role retained "+u.key,u.art_variant==("" if freed else v) and u.base_speed==(82.0 if freed else 0.0) and u.is_hero!=freed)
		for d in ["se","sw","ne","nw"]:
			var frames: Array = art.unit_anim_frames(u.key,"walk" if freed else "idle",d,v)
			check("ROLE","restored actor resolves authored direction "+u.key+" "+d,frames.size()==(4 if freed else 1) and art.unit_anim_uses_directional_source(u.key,"walk" if freed else "idle",d,v))
	if freed: check("ROLE","restored mission selection buttons",_has_level_button(b.mission,"zhu_select_shi_qian") and _has_level_button(b.mission,"zhu_select_rescued"))
	check("ROLE","rescue/return does not award victory before manor falls",not b.level.manor_fallen and not b.level._finish_ready() and not b.mission.has_event("zhu_seven_safe"))

func _normal_contact(b, actor, action_id: String) -> bool:
	var action: Dictionary = b.mission.actions[action_id]
	actor.position=b.map.cell_to_world(action.cell) # Explicit contact positioning, not prisoner movement.
	actor.passive=true;actor.auto_micro=false;actor.set_physics_process(true)
	b._grid_build();b.select_members([actor],false);b.minimap_order(b.map.cell_to_world(action.cell),false);command_count+=1
	for tick in range(160):
		if action.done:break
		await get_tree().create_timer(0.1).timeout
	actor.set_physics_process(false)
	return check("ACTION","normal timed callback "+action_id,action.done)

func _clear_route(b) -> bool:
	var fighter = b.find_unit("lin_chong")
	if not check("MOVE","original Lin Chong available",is_instance_valid(fighter) and fighter.hp>0):return false
	var defenders: Array = b.units.filter(func(u):return is_instance_valid(u) and u.hp>0 and u.faction==1 and not u.is_building and not u.is_resource and not u.is_worker and u.position.x<b.map.cell_to_world(Vector2i(19,0)).x)
	for guard in b.level.resource_guards:
		if is_instance_valid(guard) and guard.hp>0 and guard not in defenders:defenders.append(guard)
	for enemy in defenders:
		fighter.position=enemy.position+Vector2(24,0) # Same documented melee contact fixture as original art QA.
		fighter.auto_micro=false;fighter.set_physics_process(true)
		b._grid_build();b.select_members([fighter],false);b.minimap_order(enemy.position,false);command_count+=1
		for tick in range(480):
			if not is_instance_valid(enemy) or enemy.hp<=0:break
			await get_tree().create_timer(0.25).timeout
		if not check("MOVE","normal attacks clear original defender",not is_instance_valid(enemy) or enemy.hp<=0):return false
		fighter.order_stop();fighter.set_physics_process(false)
	return true

func _normal_waypoint(b, cell: Vector2i) -> bool:
	var members: Array = b.level.prisoners.duplicate()
	var target: Vector2 = b.map.cell_to_world(cell)
	if not check("MOVE","ground waypoint does not target enemy",b._enemy_at(b.to_screen(target))==null):return false
	for u in members:u.set_physics_process(true)
	b.select_members(members,false);b.minimap_order(target,false);command_count+=1
	for tick in range(480):
		if members.all(func(u):return u.hp>0 and u.position.distance_to(target)<105 and (cell!=Vector2i(52,29) or u.position.distance_to(b.level.hall.position)<190)):return true
		_freeze(b,members)
		await get_tree().create_timer(0.25).timeout
	return check("MOVE","seven real actors reach "+str(cell),false)

func _save_role(b) -> bool:
	if not check("SAVE","real battle has classified Zhu context",b._official_context==Profiles.ZHU_CONTEXT):return false
	# Installed component opt-in, matching the existing Level3 restore harness.
	# This does not enable or bypass the public ContinueFlow player entry.
	b._save_barrier.configure(b,b._run_clock,Profiles.ZHU_CONTEXT)
	b._save_barrier.capture_ready.connect(_on_held)
	b._save_barrier.capture_rejected.connect(_on_rejected)
	var saved: Dictionary = await _pause_save(b)
	if not check("SAVE","original save barrier and session succeed",saved.get("ok",false)):
		print("ROLE_SAVE_FAILURE ",saved);return false
	saved_state=_role_observation(b)
	var slot: Dictionary = Store.new(slot_root).read_slot()
	if not check("SAVE","disk slot remains readable after capture",slot.get("ok",false)):return false
	var handoff := {"case":role_case,"nonce":role_nonce,"pid":OS.get_process_id(),"slot_sha256":slot.get("file_sha256",""),"state":saved_state}
	var f := FileAccess.open(ROLE_HANDOFF,FileAccess.WRITE)
	if not check("SAVE","persistent handoff writable",f!=null):return false
	f.store_string(JSON.stringify(handoff));f.close()
	return true

func _pause_save(battle: Node) -> Dictionary:
	held=false;rejected="";get_tree().paused=true
	var requested: Dictionary = battle._save_barrier.request_capture()
	if not requested.get("ok",false):return requested
	for tick in range(180):
		await get_tree().process_frame
		if held or not rejected.is_empty():break
	if not (held and rejected.is_empty() and battle._save_barrier.state==battle._save_barrier.State.HELD and battle._save_barrier.health().ok):
		return {"ok":false,"code":"BARRIER_HELD","rejection":rejected,"held":held,"health":battle._save_barrier.health()}
	return Session.new(trusted,runtime,slot_root).save_held(battle)

func run() -> void:
	get_window().unfocusable=true
	role_case=OS.get_environment("RESCUED_ROLE_CASE");role_nonce=OS.get_environment("RESCUED_ROLE_NONCE")
	if not check("INIT","known role case and process nonce",role_case in ROLE_CASES and role_nonce.length()==32):finish();return
	check("INIT","normal engine time scale",Engine.time_scale==1.0)
	trusted=Provider.new().resolve_runtime_identity()
	if not check("INIT","trusted current installation",trusted.get("ok",false) and trusted.get("save_eligible",false)):finish();return
	var pack: Dictionary = Factory.prepare_runtime(trusted)
	if not check("INIT","original world restore runtime prepared",pack.get("ok",false)):finish();return
	runtime=pack.runtime
	var b: Node
	if role_case=="bound":
		b=await _launch_level3_battle()
	else:
		var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROLE_HANDOFF))
		var index: int = ROLE_CASES.find(role_case)
		if not check("RESTORE","handoff belongs to preceding finished process",old.get("case","")==ROLE_CASES[index-1] and old.get("nonce","")!=role_nonce):finish();return
		var slot: Dictionary = Store.new(slot_root).read_slot()
		if not check("RESTORE","same disk slot after process exit",slot.get("ok",false) and slot.get("file_sha256","")==old.slot_sha256):finish();return
		var result: Dictionary = await _restore_from_menu()
		if not check("RESTORE","new process commits original world",result.get("ok",false)):
			print("ROLE_RESTORE_FAILURE ",result);finish();return
		b=result.battle
		before_restore=_role_observation(b)
		check("RESTORE","seven IDs/stats/positions/commands/phase unchanged",JSON.stringify(before_restore)==JSON.stringify(old.state))
	if not check("INIT","real Zhu RTS battle",is_instance_valid(b) and b.level.get_script()==Zhu):finish();return
	_freeze(b)
	_role_routes(b,b.level.prisoners_freed)
	get_tree().paused=false
	if role_case=="freed":
		var prior_health := {}
		for u in b.level.prisoners:prior_health[u.key]=[u.hp,u.max_hp]
		if not await _normal_contact(b,b.level.song,"zhu_rts_recon"):finish();return
		if not await _normal_contact(b,b.level.sun,"zhu_rts_inside"):finish();return
		if not await _normal_contact(b,b.level.song,"zhu_rts_rescue"):finish();return
		for u in b.level.prisoners:check("ROLE","real callbacks preserve own original health "+u.key,[u.hp,u.max_hp]==prior_health[u.key])
		_role_routes(b,true)
	elif role_case=="midroute":
		if not await _clear_route(b):finish();return
		if not await _normal_waypoint(b,Vector2i(16,23)):finish();return
		if not await _normal_waypoint(b,Vector2i(25,18)):finish();return
	elif role_case=="camp":
		if not await _normal_waypoint(b,Vector2i(43,18)):finish();return
		if not await _normal_waypoint(b,Vector2i(52,29)):finish();return
		check("MOVE","all original seven back near real camp",b.level.prisoners.all(func(u):return u.position.distance_to(b.level.hall.position)<190))
	elif role_case=="verifycamp":
		check("MOVE","new process retains seven at camp",b.level.prisoners.all(func(u):return u.position.distance_to(b.level.hall.position)<190))
		get_tree().paused=true;saved_state=_role_observation(b)
		b.queue_free();await get_tree().process_frame;finish();return
	check("SAVE","no early safe-return reward",not b.level._finish_ready() and not b.mission.has_event("zhu_seven_safe"))
	await _save_role(b)
	b.queue_free();await get_tree().process_frame
	finish()

func finish() -> void:
	var passed: bool = not checks.is_empty() and checks.all(func(c):return c.passed)
	var report := {"passed":passed,"checks":checks,"case":role_case,"pid":OS.get_process_id(),"process_nonce":role_nonce,
		"engine_time_scale":Engine.time_scale,"restored_state":before_restore,"saved_state":saved_state,"commands":command_count,
		"explicit_installed_campaign_capture_profile":true,"public_player_entry_qualified":false,
		"scope":"Original Zhu seven-actor save barrier and session restore across process exits with explicit installed campaign capture-profile opt-in, contact/attacker-position fixtures and frozen nonparticipants. No prisoner teleport/damage injection/stage changes; no manor defeat, full victory/reward-once, public player entry/normal UI button, terminal, performance or platform qualification."}
	if not report_path.is_empty():
		var f := FileAccess.open(report_path,FileAccess.WRITE)
		if f!=null:f.store_string(JSON.stringify(report,"\t"));f.close()
	print("RESCUED_ROLE_PROCESS_COMPLETE ",role_case," ",checks.size()," ",passed)
	get_node("/root/Sfx").shutdown();get_node("/root/Music").shutdown()
	get_tree().quit(0 if passed else 1)
