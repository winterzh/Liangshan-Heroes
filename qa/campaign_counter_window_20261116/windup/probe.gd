extends "res://tools/zhujiazhuang_rts_test.gd"
## Render the actual tells, then check the same chapter attack callbacks.

func _open_stretch(b) -> Vector2i:
	for x in range(38,50):
		for y in range(16,24):
			var cell:=Vector2i(x,y)
			var point: Vector2=b.map.cell_to_world(cell)
			if b.map._segment_open(point,point+Vector2(198,0),"land") and b.map.is_open_world(point+Vector2(15,58),"land"):
				return cell
	return Vector2i(-1,-1)

func _shot(b, file_name: String) -> bool:
	b.hud.set_top(b.level.top_status(b))
	b.center_camera_cell(b.map.world_to_cell(b.level.menshen.position))
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().save_png(OS.get_environment("KH_WINDUP_CAPTURE").path_join(file_name))==OK

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	var b=await _start("",6)
	b.set_process(false)
	b.set_physics_process(false)
	b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	var l=b.level
	l._open_showdown(b,false)
	var localize=root.get_node("Localize")
	var cell:=_open_stretch(b)
	check(cell.x>=0,"find an actual clear charge path beside the arena")
	if cell.x<0:
		await _dispose(b)
		quit(1)
		return
	var origin: Vector2=b.map.cell_to_world(cell)
	l.menshen.position=origin
	l.wu.position=origin+Vector2(95,0)
	l.shi.position=origin+Vector2(0,-220)
	b.map.sync_render_position(l.menshen)
	b.map.sync_render_position(l.wu)
	l.special_index=0
	l._begin_special(b)
	var texts: Dictionary={}
	var heavy := {"zh_CN":"重拳","zh_TW":"重拳","en":"Heavy punch","ja":"強打"}
	for locale in heavy:
		localize.set_language(locale,false)
		texts[locale]=l.top_status(b)
		check(heavy[locale] in texts[locale] and "1.6" in texts[locale],"heavy countdown resolves in "+locale)
	localize.set_language("zh_CN",false)
	check(await _shot(b,"heavy_zh_1280.png"),"render the heavy countdown and actual circular tell")
	l.wu.position=origin+Vector2(0,-108)
	l._duel_tick(b,1.6)
	check(l.exposed_left==2.2 and l.heavy_dodges==1,"a real heavy whiff preserves its counter window and dodge credit")
	l._duel_tick(b,2.2)
	await process_frame
	b.hud._clear_info_toasts()

	l.wu.position=origin+Vector2(95,0)
	b.map.sync_render_position(l.wu)
	l._begin_special(b)
	var radius: float=l.RUSH_WIDTH*0.5+maxf(l.wu.radius,l.shi.radius)
	var outline: PackedVector2Array=l.fist_marker._rush_outline(radius)
	var min_x:=INF
	var max_x:=-INF
	var max_y:=-INF
	for point in outline:
		min_x=minf(min_x,point.x)
		max_x=maxf(max_x,point.x)
		max_y=maxf(max_y,point.y)
	var travel: float=l.fist_marker.extent
	check(is_equal_approx(min_x,-radius) and is_equal_approx(max_x,travel+radius)
		and is_equal_approx(max_y,radius),"the drawn outline includes the body radius and both charge end caps")
	var registry: Dictionary=load("res://scripts/run_level7_visual_state.gd").tokens(l,b.fx_root)
	check(registry.ok,"the existing visual snapshot protocol recognizes the revised tell: "+str(registry.get("code","OK")))
	localize.set_language("en",false)
	root.size=Vector2i(960,540)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	check("Charge in" in l.top_status(b) and "marked area" in l.top_status(b)
		and await _shot(b,"rush_en_960.png"),"render the readable English charge tell at 960 pixels")

	l._duel_tick(b,1.25)
	var dir: Vector2=l.menshen._charge_dir
	var step := 1.0/60.0
	var side_distance: float=l.RUSH_WIDTH*0.5+l.wu.radius-1.0
	l.wu.position=l.menshen.position+dir*560.0*step+dir.orthogonal()*side_distance
	var before_hp: float=l.wu.hp
	l.menshen._do_charge_step(step)
	check(l.charge_running and l.menshen._charge_hit.has(l.wu) and l.wu.hp<before_hp
		and side_distance>l.RUSH_WIDTH*0.5,
		"the real charge hits outside the old strip but within the new warning")
	l.menshen._charge_dash=0
	l._duel_tick(b,0.0)
	localize.set_language("zh_CN",false)

	var old_dodges: int=l.rush_dodges
	l.special_index=1
	l.menshen.position=origin+Vector2(15,0)
	l.wu.position=origin+Vector2(15.5,0)
	b.map.block_footprint(cell+Vector2i(1,0),0,true)
	l._begin_special(b)
	var blocked_status: String=l.top_status(b)
	check(l.rush_end==l.rush_from and "冲撞受阻" in blocked_status,"fully blocked travel gets its own windup notice")
	l._duel_tick(b,1.25)
	check(not l.charge_running and l.menshen._charge_dash==0.0 and l.exposed_left==2.8
		and l.rush_dodges==old_dodges and not b.mission.has_event("dodge_rush"),
		"blocked charge opens a real counter without a phantom dash or a dodge award")
	print("KH_WINDUP_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,
		"failures":failures,"heavy_localizations":texts,"blocked_status":blocked_status,
		"old_half_width":l.RUSH_WIDTH*0.5,"warning_radius":radius,"hit_from_center":side_distance,
		"scope":"rendered real chapter fixtures for warning countdown, draw geometry and actual charge steps"}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
