extends "res://tools/zhujiazhuang_rts_test.gd"
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,900)
	root.get_node("Settings").edge_scroll=false
	var b=await _start("",7)
	var folder="res://qa/daming_rts_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	b.camera.zoom=Vector2.ONE
	b.center_camera_cell(b.level.CAMP)
	await _wait(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/camp.png")
	b.fog=false
	b._fog_layer.hide()
	for u in b.units: u.fog_visible=true; u.show()
	b.hud.hide()
	b.camera.zoom=Vector2.ONE*1.7
	b.center_camera_cell(b.level.SOUTH_GATE)
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/city_gate.png")
	b.camera.zoom=Vector2.ONE*0.31
	b.center_camera_cell(Vector2i(30,33))
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/overview.png")
	await _dispose(b)
	print("[daming-visual] 3 frames saved")
	quit()
