extends "res://tools/zhujiazhuang_rts_test.gd"
## Rendered current map and long-objective layout at both desktop sizes.
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var b=await _start("",4)
	var folder: String="res://.godot/gao_rts/layout"
	DirAccess.make_dir_recursive_absolute(folder)
	for u in b.units: u.set_physics_process(false); u.fog_visible=true; u.show()
	b.fog=false
	if b._fog_layer!=null: b._fog_layer.hide()
	for size in [Vector2i(1440,900),Vector2i(1280,720)]:
		root.size=size
		DisplayServer.window_set_size(size)
		b.camera.zoom=Vector2.ONE
		b.center_camera_cell(Vector2i(23,38))
		await _wait(0.7)
		await RenderingServer.frame_post_draw
		check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"objective panel stays above command cards at "+str(size))
		check(b.mission._scroll.size.y>=80 and b.mission._status.get_global_rect().end.y<b.hud._bottom_panel.get_global_rect().position.y,"scroll area and live status remain visible at "+str(size))
		check(root.get_texture().get_image().save_png(folder+"/camp_%d.png"%size.x)==OK,"saved actual camp and objective UI")
	# Maximum later task list, through the same mission registration API.
	for i in range(12): b.mission.add_action("layout_%d"%i,"后续任务滚动检查%d"%i,Vector2i(45,20+i),["liangshan_warship"],1)
	await _wait(0.5)
	check(b.mission._scroll.get_v_scroll_bar().max_value>b.mission._scroll.size.y,"long list actually scrolls instead of growing off-screen")
	check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"long later objective list still avoids command cards")
	b.mission._scroll.scroll_vertical=int(b.mission._scroll.get_v_scroll_bar().max_value)
	await _wait(0.3)
	await RenderingServer.frame_post_draw
	check(b.mission._buttons.get_child(-1).get_global_rect().end.y<=b.mission._scroll.get_global_rect().end.y+1,"last task remains reachable by scrolling")
	check(root.get_texture().get_image().save_png(folder+"/long_list_1280.png")==OK,"saved explicit long-list UI fixture")
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_size(root.size)
	b.mission._panel.hide()
	b.phase=b.Phase.DEPLOY
	for shot in [["shore",Vector2i(26,46),1.3],["corner",Vector2i(31,41),1.4],["enemy_sources",Vector2i(32,13),1.0]]:
		b.camera.zoom=Vector2.ONE*shot[2]
		b.center_camera_cell(shot[1])
		await _wait(0.5)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/"+shot[0]+".png")==OK,"saved "+shot[0])
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures},"\t"))
	print("[gao-visual] ",checks," checks, failures=",failures.size())
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
