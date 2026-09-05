extends "res://tools/zhujiazhuang_rts_visual.gd"
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	root.size = Vector2i(1280,720)
	var c = root.get_node("Campaign")
	c.current = 2
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(key,false)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	await create_timer(2.0).timeout
	b.fog = false
	b._fog_layer.hide()
	for u in b.units:
		u.fog_visible = true
		u.show()
	b.camera.zoom = Vector2(1.8,1.8)
	b.mission.set_status("QA 寨门朝向检查：临时关闭迷雾，正常游玩保留迷雾。")
	var folder := "res://qa/zhujiazhuang_rts_feedback_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	for mirrored in [false,true]:
		for gate in [b.level.gate,b.level.side_gate]:
			gate.set_meta("building_visual_mirror",mirrored)
			gate.queue_redraw()
		for gate_name in ["main","side"]:
			b.center_camera_cell(b.level.MAIN_GATE if gate_name == "main" else b.level.SIDE_GATE)
			await create_timer(0.7).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			var picture = root.get_texture().get_image()
			var file: String = folder+"/"+gate_name+"_gate_"+("aligned" if mirrored else "original_axis")+".png"
			var error = picture.save_png(file)
			print("[gate-visual] ",file," ",picture.get_size()," error=",error)
	b.queue_free()
	await process_frame
	quit()
