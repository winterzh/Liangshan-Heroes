extends "res://tools/zhujiazhuang_rts_test.gd"
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1440,900)
	root.get_node("Settings").edge_scroll=false
	var b=await _start("",3)
	var l=b.level
	var folder: String="res://qa/lianhuanma_rts_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	b.camera.zoom=Vector2.ONE*1.1
	b.center_camera_cell(Vector2i(13,30))
	await _wait(1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/opening.png")
	b.fog=false
	b._fog_layer.hide()
	for u in b.units: u.fog_visible=true; u.show()
	b.hud.hide()
	b.mission._panel.hide()
	b.camera.zoom=Vector2.ONE*0.32
	b.center_camera_cell(Vector2i(32,30))
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/strategic_overview.png")
	b.hud.show()
	b.mission._panel.show()
	# Visual fixture: assemble an actual melee clash without changing unit stats.
	var center: Vector2=b.map.cell_to_world(l.LANES[0])
	var defenders: Array=b.units.filter(func(u): return u.faction==0 and u.key in ["gou_lian","liang_qiang","liang_gong","xu_ning"])
	for i in range(defenders.size()):
		var u=defenders[i]
		u.position=center+Vector2(-70,(i-3)*25)
		u.fog_visible=true
	for i in range(6):
		var rider=l.riders[i]
		rider.position=center+Vector2(100+i/3*30,(i%3-1)*35)
		rider.fog_visible=true
		rider.order_amove(center)
	b.select_members(defenders,false)
	b.minimap_order(center,true)
	b.camera.zoom=Vector2.ONE*1.8
	b.center_camera_cell(l.LANES[0])
	await _wait(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/hook_melee.png")
	print("[lhm-visual] hook_broken=",l.broken_count)
	await _dispose(b)
	quit()
