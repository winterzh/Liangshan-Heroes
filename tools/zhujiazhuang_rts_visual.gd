extends SceneTree
## Actual opening UI plus a labelled fog-disabled map-layout inspection.
const OUT := "res://qa/zhujiazhuang_rts_20260905"
func _initialize() -> void: _run.call_deferred()
func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	var error = picture.save_png(OUT+"/"+name+".png")
	print("[rts-visual] ",name," ",picture.get_size()," error=",error)
func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false # Hidden-window cursor must not pan the capture away.
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
	Engine.time_scale = 1.0
	b.center_camera_cell(b.level.CAMP)
	b.select_single(b.level.hall,false)
	await create_timer(2.0).timeout
	b.center_camera_cell(b.level.CAMP)
	DirAccess.make_dir_recursive_absolute(OUT)
	await _capture("opening_1280x720")
	# Explicit layout inspection only: no claim that undiscovered enemies are visible in gameplay.
	b.fog = false
	b._fog_layer.hide()
	for u in b.units: u.show()
	b.camera.zoom = Vector2(0.55,0.55)
	b.center_camera_cell(Vector2i(31,28))
	b.mission.set_status("QA 地图检查：此图暂时关闭迷雾；正常游玩保持战争迷雾。")
	await _capture("layout_inspection_fog_disabled_1280x720")
	b.queue_free()
	await process_frame
	quit()
