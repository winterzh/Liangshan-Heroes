extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen current-map layout and maximum real objective list; not live combat.
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var b=await _start("",1)
	var l=b.level
	var folder := "res://.godot/jiangzhou_rts/layout"
	DirAccess.make_dir_recursive_absolute(folder)
	for u in b.units: u.set_physics_process(false)
	for size in [Vector2i(1440,900),Vector2i(1280,720)]:
		root.size=size; DisplayServer.window_set_size(size)
		b.camera.zoom=Vector2.ONE
		b.center_camera_cell(Vector2i(18,28))
		await _wait(0.5); await RenderingServer.frame_post_draw
		check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"objectives avoid command cards at "+str(size))
		check(b.mission._scroll.size.y>=80 and b.mission._status.get_global_rect().end.y<b.hud._bottom_panel.get_global_rect().position.y,"status and scroll area remain visible at "+str(size))
		check(root.get_texture().get_image().save_png(folder+"/start_%d.png"%size.x)==OK,"saved initial fog and objective UI")
	# Explicitly advance only this layout fixture to the real rescue action list.
	l._uprising(b,b.find_unit("chao_gai"))
	for u in l.executioners: u.take_damage(10000,null,false,true)
	l.process(b,0)
	l._free(b,true); l._free(b,false)
	for u in b.units: u.set_physics_process(false)
	await _wait(0.4)
	b.mission._scroll.scroll_vertical=int(b.mission._scroll.get_v_scroll_bar().max_value)
	await _wait(0.3); await RenderingServer.frame_post_draw
	check(b.mission._scroll.get_v_scroll_bar().max_value>b.mission._scroll.size.y,"real rescue list scrolls at 1280x720")
	check(b.mission._buttons.get_child(-1).get_global_rect().end.y<=b.mission._scroll.get_global_rect().end.y+1,"last real rescue task is reachable by scrolling")
	check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"rescue instructions avoid command cards")
	check(root.get_texture().get_image().save_png(folder+"/rescue_list_1280.png")==OK,"saved real later objective list fixture")
	root.size=Vector2i(1440,900); DisplayServer.window_set_size(root.size)
	b.fog=false
	if b._fog_layer!=null: b._fog_layer.hide()
	for u in b.units: u.fog_visible=true; u.show()
	b.hud.hide(); b.mission._panel.hide()
	for shot in [["scaffold",Vector2i(30,20),1.25],["west_cache",Vector2i(14,25),1.1],["south_route",Vector2i(27,38),1.0],["dock",Vector2i(13,45),1.1]]:
		b.camera.zoom=Vector2.ONE*shot[2]; b.center_camera_cell(shot[1])
		await _wait(0.4); await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder+"/"+shot[0]+".png")==OK,"saved "+shot[0])
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"frozen current map and explicitly advanced rescue-list layout"},"\t"))
	print("[jiangzhou-visual] ",checks," checks, failures=",failures.size())
	await _dispose(b)
	quit(0 if failures.is_empty() and checks==14 else 1)
