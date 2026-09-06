extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen real-map framing for walls, gates and corners at two scales.
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1440,900)
	DisplayServer.window_set_size(root.size)
	var tag: String=OS.get_environment("WALL_VISUAL_TAG")
	if tag=="": tag="after"
	var folder: String="res://.godot/wall_alignment/"+tag
	DirAccess.make_dir_recursive_absolute(folder)
	for scene in [["zhu","",2,Vector2i(20,23),1.1,Vector2i(20,28),1.7],
		["liangshan","",4,Vector2i(18,39),1.0,Vector2i(22,39),1.7],
		["defense","skirmish",4,Vector2i(24,37),0.8,Vector2i(31,41),1.5]]:
		var b=await _start(scene[1],scene[2])
		b.phase=b.Phase.DEPLOY
		for u in b.units: u.set_physics_process(false); u.fog_visible=true; u.show()
		b.fog=false
		if b._fog_layer!=null: b._fog_layer.hide()
		b.hud.hide()
		for view in [0,1]:
			b.camera.zoom=Vector2.ONE*scene[4+view*2]
			b.center_camera_cell(scene[3+view*2])
			await _wait(0.4)
			await RenderingServer.frame_post_draw
			var path: String=folder+"/"+scene[0]+("_wide.png" if view==0 else "_close.png")
			check(root.get_texture().get_image().save_png(path)==OK,"saved "+path)
		await _dispose(b)
	print("[wall-visual] ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() and checks==6 else 1)
