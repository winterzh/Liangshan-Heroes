extends SceneTree
## Reach the real care event first. Post-capture position/damage mutations are explicit
## boundary fixtures, not playthrough evidence. A renderer also records the real pair.
var failures: Array[String]=[]
var results: Array[Dictionary]=[]
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	results.append({"name":label,"passed":ok})
	print("[assisted-check] ","PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _start():
	var c=root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(mode,false)
	c.current=c.index_for_id("level6")
	seed(5088120)
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b); current_scene=b
	await process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b.hud._on_start_pressed()
	b._smoke=true
	return b
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	root.get_node("Settings").auto_micro_level=0
	root.get_node("Settings").edge_scroll=false
	AudioServer.set_bus_mute(0,true)
	Engine.time_scale=4.0
	var b=await _start()
	var sim_time:=0.0
	while b.phase!=b.Phase.END and sim_time<120.0:
		await process_frame
		sim_time+=b.get_process_delta_time()
		if b.mission.has_event("tend_feet") and is_instance_valid(b.level.lin_freed) and b.level.lin_freed.story_assistance_active() and b.level.lin_freed._move_blend>0.3: break
	var lin=b.level.lin_freed
	var lu=b.level.lu
	var paired: bool=is_instance_valid(lin) and lin.story_assistance_active()
	check(b.mission.has_event("tend_feet") and paired,"real care and walking reached paired pose")
	b._smoke=false
	b.set_process(false); b.set_physics_process(false); b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	Engine.time_scale=1.0
	if not paired:
		print("[assisted-result] ",JSON.stringify({"passed":false,"failures":failures}))
		quit(1); return
	check(lu.story_assistance_hidden() and lin.hp>0.0 and lu.hp>0.0,"only the helper duplicate sprite is hidden, both actors remain alive")
	check(b._unit_at(b.to_screen(lin.position))==lin and b._unit_at(b.to_screen(lu.position))==lu,"both physical feet remain individually selectable by game hit testing")
	var art=root.get_node("Art")
	for direction in ["se","sw","ne","nw"]:
		check(art.campaign_variant_has_animation("lin_chong_escort","assisted",direction) and art.unit_anim_frames("lin_chong","assisted",direction,"lin_chong_escort").size()==4,"four real assisted frames "+direction)
	if DisplayServer.get_name()!="headless":
		b.camera.position=b.to_screen((lin.position+lu.position)*0.5)-Vector2(65,-45)
		b.camera.zoom=Vector2.ONE*1.8; b.camera.force_update_scroll()
		b._grid_build(); b.mission.tick(0.0)
		lin.queue_redraw(); lu.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/campaign_story_visual/level6_assisted_1280.png")
	# Explicit fixtures begin here. The real event screenshot above is unmodified.
	var saved: Vector2=lu.position
	lu.position=b.map.cell_to_world(b.map.nearest_open(b.map.world_to_cell(saved)+Vector2i(6,0),"land"))
	check(not lin.story_assistance_active() and not lu.story_assistance_hidden(),"walking apart restores both single sprites")
	lu.position=saved
	lu._lunge=0.5
	check(not lin.story_assistance_active() and not lu.story_assistance_hidden(),"helper starting an attack cannot remain hidden inside pair")
	lu._lunge=0.0
	lin.garrisoned=true
	check(not lin.story_assistance_active() and not lu.story_assistance_hidden(),"a removed patient does not hide the helper")
	lin.garrisoned=false
	lu.take_damage(100000.0,null,true,true)
	# Level-6 defeat is evaluated by the level process after the damage call;
	# allow that deferred mission state transition to run before asserting it.
	await process_frame
	await process_frame
	check(not lin.story_assistance_active() and not lu.story_assistance_hidden() \
		and b.level.st==b.level.ESCAPE and b.phase!=b.Phase.END,
		"helper death restores single patient; living Lin Chong may continue the escape stage")
	b.queue_free(); await process_frame; await process_frame
	b=await _start()
	check(b.level.lu.story_assist_owner==null and b.mission.stage_metrics.is_empty() and not b.mission.has_event("tend_feet"),"restart clears paired references and event/metrics history")
	b.queue_free(); await process_frame; await process_frame
	var report:={"passed":failures.is_empty(),"failures":failures,"checks":results,"real_event_game_seconds":sim_time,"human_playtest":false,"boundary_fixtures_after_capture":true}
	var file=FileAccess.open("res://qa/campaign_story_visual/assisted_contract.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("[assisted-result] ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
