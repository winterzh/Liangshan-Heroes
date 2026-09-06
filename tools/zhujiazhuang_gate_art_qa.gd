extends "res://tools/zhujiazhuang_rts_test.gd"
## Geometry and scope checks plus optional real renderer captures. Not a playthrough.
var observations := {}
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	var visual=load("res://scripts/campaign_gate_visual.gd")
	var art=root.get_node("Art")
	var b=await _start("",2)
	b.phase=b.Phase.DEPLOY
	var expected="res://assets/campaign/objects/zhu_gate_native_20260906_default.png"
	for gate in [b.level.gate,b.level.side_gate]:
		var texture: Texture2D=art.unit_texture(gate.key,gate.art_variant)
		check(texture.resource_path==expected,gate.display_name+" loads its native texture")
		check(gate._building_shadow_texture(texture,null)==texture,"actual gate shadow selector retains the displayed native texture")
		check(texture.get_size()==Vector2(512,341),"bounded standard texture import")
		var tr: Transform2D=visual.source_transform(gate,texture.get_size())
		# Independently measured stone feet in the 1536x1024 original.
		var north=Vector2(1322.0/1536.0,647.0/1024.0)*texture.get_size()
		var south=Vector2(230.0/1536.0,935.0/1024.0)*texture.get_size()
		check((tr*north).distance_to(Vector2(64,-32))<0.01,"north foot on world wall endpoint")
		check((tr*south).distance_to(Vector2(-64,32))<0.01,"south foot on world wall endpoint")
		check(tr.determinant()>0 and tr.x.x>0,"native face is not mirrored")
		check(absf(tr.y.x)<0.0001 and tr.y.y>0,"posts and door jambs remain upright")
		check(absf(tr.x.y/tr.x.x)<0.12,"residual axis correction stays below 12 percent")
		var shadow: Transform2D=visual.source_transform(gate,texture.get_size(),Vector2(-0.35,0.24))
		check((shadow*north).distance_to(Vector2(64,-32))<0.01 and (shadow*south).distance_to(Vector2(-64,32))<0.01,"shadow shares both real stone feet")
		check(gate.self_modulate==Color.WHITE and visual.source_tint(gate,Color.WHITE)==Color(0.60,0.70,0.83),"only bitmap receives color calibration; labels keep their colors")
		check(not b.map.is_open_cell(b.map.world_to_cell(gate.position)),"closed gate still blocks its passage")
		observations[gate.display_name]={"texture":texture.resource_path,"axis_correction_ratio":absf(tr.x.y/tr.x.x)}
	check(art.campaign_object_texture("zhu_gate")==null and art.terrain_texture("zhu_gate").atlas.resource_path=="res://assets/terrain2.png","unscoped legacy gate keeps its original atlas")
	var folder: String=OS.get_environment("GATE_ART_OUT")
	if folder.is_empty(): folder="res://.godot/wall_gate_native/runtime"
	DirAccess.make_dir_recursive_absolute(folder)
	if OS.get_environment("GATE_ART_VISUAL")=="1":
		check(DisplayServer.get_name()!="headless","visual capture uses a real rendering device")
		root.size=Vector2i(1440,900)
		DisplayServer.window_set_size(root.size)
		for u in b.units: u.set_physics_process(false); u.fog_visible=true; u.show()
		b.fog=false
		b._fog_layer.hide()
		b.hud.hide()
		for view in [["main_close",b.level.MAIN_GATE,2.0],["side_close",b.level.SIDE_GATE,2.0],["both_wide",Vector2i(20,23),1.1]]:
			b.camera.zoom=Vector2.ONE*view[2]
			b.center_camera_cell(view[1])
			await _wait(0.35)
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/"+view[0]+".png")==OK,"saved "+view[0])
	await _dispose(b)
	b=await _start("",7)
	check(b.level.gate.art_variant!="zhu_gate_native_20260906","Daming retains its distinct gate art")
	var city_texture: Texture2D=art.unit_texture(b.level.gate.key,b.level.gate.art_variant)
	check(city_texture!=null and b.level.gate._building_shadow_texture(city_texture,null)==city_texture,"Daming shadow also uses its displayed variant")
	check(visual.source_tint(b.level.gate,Color(0.3,0.4,0.5,0.7))==Color(0.3,0.4,0.5,0.7),"Daming tint remains identical including opacity")
	await _dispose(b)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"observations":observations},"\t")+"\n")
	print("[gate-art] ",checks," checks, failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
