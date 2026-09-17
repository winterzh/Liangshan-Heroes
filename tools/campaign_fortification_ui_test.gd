extends "res://tools/zhujiazhuang_rts_test.gd"
## Geometry/text and real-renderer inspection; not an automated battle outcome.

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	root.get_node("Settings").edge_scroll=false
	var folder:="res://.godot/campaign_fortification_ui"
	DirAccess.make_dir_recursive_absolute(folder)
	var b=await _start()
	b.set_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	b.fog=false
	b._fog_layer.hide()
	var targets: Array=[b.level.gate]
	for u in b.units:
		if u.key=="arrow_tower" and u.faction==1:
			targets.append(u)
			break
	check(targets.size()==2,"gate and defended arrow tower both inspected")
	var texts: Array=[]
	for language in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(language,false)
		for target in targets:
			target.fog_visible=true
			target.show()
			b._set_inspect(target)
			b.hud.update_selection_panel([])
			b.hud._refresh_panel()
			b.camera.zoom=Vector2.ONE*1.25
			b.center_camera_cell(b.map.world_to_cell(target.position))
			b.camera.force_update_scroll()
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			var label: Label=b.hud._info_stats
			var rect: Rect2=label.get_global_rect()
			check(label.text.contains("25%"),language+" displays effective fortification value")
			check(label.get_minimum_size().x<=label.size.x+1 and label.get_minimum_size().y<=label.size.y+1,language+" fortification text fits label")
			check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(rect),language+" stats remain in viewport")
			check(root.get_texture().get_image().save_png(folder+"/"+language+"_"+target.key+".png")==OK,"capture "+language+" "+target.key)
			texts.append({"language":language,"key":target.key,"text":label.text,"width":rect.size.x,"height":rect.size.y})
	await _dispose(b)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"texts":texts},"\t"))
	quit(0 if failures.is_empty() else 1)
