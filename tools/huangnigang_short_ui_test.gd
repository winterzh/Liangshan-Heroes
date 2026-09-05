extends "res://tools/huangnigang_short_test.gd"
## Frozen UI fixtures: verify the controls below the initial small-window fold.
func _run() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	for size in [Vector2i(1280,720),Vector2i(1440,900)]:
		root.size=size
		DisplayServer.window_set_size(size)
		for stage in ["wine","cargo"]:
			var b=await _wine_fixture()
			if stage=="cargo":
				b.level.st=b.level.CARRY
				b.level._begin_cargo_choice(b)
			b.level._sync_controls(b)
			# Battle's physics tick normally lays out the mission. Tick it explicitly
			# while this fixture freezes both battle and unit simulation.
			b.mission.tick(0)
			await _wait(0.3)
			b.mission.tick(0)
			await process_frame
			var last=b.mission._buttons.get_child(-1)
			b.mission._scroll.ensure_control_visible(last)
			await _wait(0.1)
			var visible: Rect2=b.mission._scroll.get_global_rect()
			print("[hns-ui-rect] ",visible," last=",last.get_global_rect()," scroll=",b.mission._scroll.scroll_vertical," content=",b.mission._scroll_content.size)
			check(visible.encloses(last.get_global_rect()),"last locator can scroll fully into view: %s %s"%[size,stage])
			check(b.mission._panel.get_global_rect().end.y<=b.hud._bottom_panel.get_global_rect().position.y-6,"scrolled panel stays above command cards: %s %s"%[size,stage])
			var positions: Array=b.level.actors.map(func(u): return u.position)
			var serials: Array=b.level.actors.map(func(u): return u._order_serial)
			last.pressed.emit()
			check(b.level.actors.map(func(u): return u.position)==positions and b.level.actors.map(func(u): return u._order_serial)==serials,"exit locator never orders companions to walk: %s %s"%[size,stage])
			await _dispose(b)
	print("[hns-ui] ",checks," checks, failures=",failures)
	quit(0 if failures.is_empty() and checks==12 else 1)
