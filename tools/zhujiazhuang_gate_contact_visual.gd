extends "res://tools/zhujiazhuang_rts_visual.gd"
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	var c=root.get_node("Campaign")
	c.current=2
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(key,false)
	var b=load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b._on_start_battle()
	await create_timer(1).timeout
	b.fog=false
	b._fog_layer.hide()
	for u in b.units:
		u.fog_visible=true
		u.show()
	b.level._introduce_sun(b)
	var folder: String="res://qa/zhujiazhuang_gate_contact_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	for variant in ["before","after"]:
		for gate in [b.level.gate,b.level.side_gate]:
			if variant=="before": gate.remove_meta("campaign_gate_wall_span"); gate.set_meta("building_visual_mirror",true)
			else: gate.set_meta("campaign_gate_wall_span",Vector2(0,128)); gate.remove_meta("building_visual_mirror")
			gate.queue_redraw()
		for view in ["wide","close"]:
			b.camera.zoom=Vector2.ONE*(1.1 if view=="wide" else 2.0)
			b.center_camera_cell(Vector2i(20,23) if view=="wide" else b.level.MAIN_GATE)
			await create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/gate_"+variant+"_"+view+".png")
	# A labelled visual fixture places Sun Li near the marker, then uses the real
	# player order and five-second timer. No action callback or gate flag injection.
	var destination: Vector2=b.map.cell_to_world(b.level.INNER_CONTACT)
	b.level.sun.position=destination+Vector2(80,0)
	b.level.sun.fog_visible=true
	b.level.sun.show()
	b.select_single(b.level.sun,false)
	b.minimap_order(destination,false)
	b.camera.zoom=Vector2.ONE*1.35
	b.center_camera_cell(Vector2i(23,20))
	await create_timer(2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/contact_in_progress.png")
	await create_timer(5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/contact_gate_open.png")
	print("[gate-contact-visual] inside_open=",b.level.inside_open)
	b.queue_free()
	await process_frame
	quit()
