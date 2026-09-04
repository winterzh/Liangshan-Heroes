extends SceneTree
## ID-keyed real renderer captures, including a four-direction action sample at 1280x720.
const VIEWS := {"level1":Vector2i(23,20),"level2":Vector2i(28,23),"level3":Vector2i(31,28),"level4":Vector2i(20,40),
	"level5":Vector2i(32,42),"level6":Vector2i(39,20),"level7":Vector2i(12,19),"level8":Vector2i(36,25)}
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	var out := OS.get_environment("CAMPAIGN_REWORK_CAPTURE")
	if out=="": quit(2); return
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,720); root.content_scale_size=root.size
	var campaign=root.get_node("Campaign")
	root.get_node("Settings").edge_scroll=false
	root.get_node("Settings").game_speed=1.0
	AudioServer.set_bus_mute(0,true)
	var wanted:=OS.get_environment("CAPTURE_IDS")
	if wanted=="":
		var menu=load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu); current_scene=menu
		await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("menu_1280.png"))
		menu._show_story()
		await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("story_order_1280.png"))
		menu.queue_free(); await process_frame; await process_frame
	for id in VIEWS:
		if wanted!="" and id not in wanted.split(","): continue
		campaign.current=campaign.index_for_id(id)
		var b=load("res://scenes/main.tscn").instantiate()
		root.add_child(b); current_scene=b
		await process_frame
		b.hud._intro_root.hide(); b._on_intro_done(); b.hud._on_start_pressed()
		b.set_process(false); b.set_physics_process(false); b.camera.set_process(false)
		for u in b.units: u.set_physics_process(false)
		b.mission.tick(0)
		b.hud.set_top(b.level.top_status(b))
		b._grid_build()
		b.camera.position=b.to_screen(b.map.cell_to_world(VIEWS[id])); b.camera.zoom=Vector2.ONE*0.9
		b.camera.force_update_scroll()
		await create_timer(0.25).timeout
		b.mission.tick(0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		print("[visual-layout] ",id," panel=",b.mission._panel.get_global_rect()," rail=",b.hud._hero_bar.get_global_rect())
		root.get_texture().get_image().save_png(out.path_join(id+"_1280.png"))
		if id=="level5":
			b.camera.position=b.to_screen(b.map.cell_to_world(Vector2i(17,37)))-Vector2(80,0)
			b.camera.zoom=Vector2.ONE
			b.camera.force_update_scroll()
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("liangshan_hall_gate_dock_1280.png"))
		if id=="level7":
			b.mission._panel.hide()
			var origin=b.map.cell_to_world(Vector2i(29,19))
			b.camera.position=b.to_screen(origin)
			for i in range(4):
				var wu=b.spawn_unit("wu_song",0,origin+Vector2(i*62-90,-i*42+70))
				wu.art_variant="wu_song_mengzhou"; wu.animation_direction=["se","sw","ne","nw"][i]
				wu.set_physics_process(false); wu._lunge=0.55; wu._swing_kind=wu._weapon_kind(); wu.display_name=["东南·拳","西南·拳","东北·拳","西北·拳"][i]
				wu.visual_scale=1.7; wu.queue_redraw()
			b._grid_build(); b.camera.zoom=Vector2.ONE*1.65; b.camera.force_update_scroll()
			await create_timer(0.25).timeout; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join("wu_song_four_directions_1280.png"))
		print("[visual] ",id," 1280x720 saved")
		b.queue_free(); await process_frame; await process_frame
	quit()
