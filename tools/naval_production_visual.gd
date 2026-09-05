extends "res://tools/zhujiazhuang_rts_test.gd"
## Controlled construction/launch view on the real existing Liangshan shore.
## Opt-in is confined to this fixture; it is not a playable Gao RTS chapter.
var folder := "res://.godot/naval_visual"
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK,"saved "+name)
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_size(root.size)
	var b=await _start("",4)
	Engine.time_scale=4
	for u in b.units: u.set_physics_process(false)
	b.level=load("res://scripts/level_base.gd").new()
	b.mission.begin("naval_visual","船坞验证场 · 非战役流程","工匠岸边建造 → 付费造船 → 清开泊位后下水。此图只验证新增船坞，不代表高俅RTS已接入。")
	load("res://scripts/naval_production.gd").configure(b._defs)
	b.economy=true
	b.gold=500
	b.wood=500
	b.pop_cap=80
	b.fog=false
	if b._fog_layer!=null: b._fog_layer.hide()
	var cell := Vector2i(16,49)
	check(b.building_terrain_valid("shipyard",cell),"actual Liangshan dock supports shore construction")
	if not b.building_terrain_valid("shipyard",cell): await _dispose(b); quit(1); return
	var worker=b.spawn_at("lou_luo",0,Vector2i(16,46))
	b.select_single(worker,false)
	b.arm_build("shipyard")
	b._try_place_building(b.to_screen(b.map.cell_to_world(cell)))
	var yard=b.find_unit("shipyard")
	check(alive(yard),"worker places yard on real shore")
	if not alive(yard): await _dispose(b); quit(1); return
	b.camera.zoom=Vector2.ONE*1.15
	b.center_camera_cell(Vector2i(18,47))
	DirAccess.make_dir_recursive_absolute(folder)
	b.select_single(yard,false)
	await _wait(8)
	await shot("construction")
	await _wait(28)
	check(not yard.is_constructing,"actual shore worker completes construction")
	var berth: Vector2i=yard.get_meta("production_berth")
	b.map.block_footprint(berth,2,true)
	check(b.queue_train(yard,"liangshan_warship",false),"actual shore accepts paid queue")
	await _wait(29)
	check(yard.production_blocked,"actual shore completed boat waits at obstructed berth")
	await shot("waiting")
	b.map.block_footprint(berth,2,false)
	_click(b,[yard],Vector2i(23,53))
	await _wait(2)
	check(yard._train_queue.is_empty() and not yard.production_blocked,"actual shore resumes launch")
	await shot("launched")
	await _dispose(b)
	print("[naval-visual] ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() and checks==9 else 1)
