extends "res://tools/kuaihuolin_short_boundaries.gd"
## Frozen UI fixtures, not a live combat playthrough.
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1"); AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	DirAccess.make_dir_recursive_absolute("res://.godot/kuaihuolin_short/ui")
	for size in [Vector2i(1280,720),Vector2i(1440,900)]:
		root.size=size; DisplayServer.window_set_size(size)
		for stage in ["road","practice","duel","return"]:
			var b=await _fixture()
			var l=b.level
			if stage=="practice": l._start_step_drill(b)
			if stage in ["duel","return"]:
				l.wu.position=l.menshen.position+Vector2(-70,0)
				l._open_showdown(b,true)
				if stage=="duel": l._begin_special(b)
				else: l.menshen.resolve_story("subdued")
			l._sync_controls(b)
			b.select_single(l.wu,false)
			b.hud._process(0.1)
			b.hud.set_top(l.top_status(b)) # Battle's normal status tick is frozen here.
			b.mission.tick(0); await _wait(0.3); b.mission.tick(0); await process_frame
			var last=b.mission._buttons.get_child(-1)
			b.mission._scroll.ensure_control_visible(last); await _wait(0.1)
			check(b.mission._scroll.get_global_rect().encloses(last.get_global_rect()),"last control scrolls fully into view: %s %s"%[size,stage])
			check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"mission panel avoids command cards: %s %s"%[size,stage])
			var positions:=[l.wu.position,l.shi.position]
			var serials:=[l.wu._order_serial,l.shi._order_serial]
			last.pressed.emit()
			check([l.wu.position,l.shi.position]==positions and [l.wu._order_serial,l.shi._order_serial]==serials,"safe-place locator cannot move actors: %s %s"%[size,stage])
			var count: int=b.mission._buttons.get_child_count()
			l._sync_controls(b); l._sync_controls(b)
			check(b.mission._buttons.get_child_count()==count,"repeated sync does not duplicate controls: %s %s"%[size,stage])
			b.center_camera_cell(b.map.world_to_cell(l.wu.position)); b.camera.zoom=Vector2.ONE*1.2
			await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://.godot/kuaihuolin_short/ui/%s_%d.png"%[stage,size.x])==OK,"saved frozen %s %d"%[stage,size.x])
			await _dispose(b)
	print("[kh-ui] ",checks," checks; failures=",failures)
	quit(0 if failures.is_empty() and checks==40 else 1)
