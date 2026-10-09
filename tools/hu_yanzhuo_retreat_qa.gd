extends "res://tools/art_character_direction4_qa.gd"
## Original chapter actors, ordinary full-HP normal attacks, explicit contact,
## frozen nonparticipants and Battle coordinator to exclude enemy auto-spells.
## No HP/damage/time edits, injected combat actors or direct story resolution.

func _normal_retreat() -> void:
	var b = await _start("", 3)
	_freeze_nonparticipants(b)
	b.set_physics_process(false)
	b.fog = false
	if is_instance_valid(b._fog_layer): b._fog_layer.hide()
	var hu = b.level.hu
	var xu = b.level.xu
	var art = root.get_node("Art")
	hu.fog_visible = true; hu.show()
	xu.fog_visible = true; xu.show()
	check(b.phase == b.Phase.FIGHT and b.level.get_script().resource_path == "res://scripts/levels/level4_lianhuanma_rts.gd", "actual fighting linked-cavalry chapter")
	check(hu.key == "hu_yanzhuo" and hu.hp == hu.max_hp and hu.hp == 780.0 and hu.faction == 1 and hu.defeat_outcome == "retreated" and hu.story_outcome.is_empty(), "original full-HP 780 enemy Hu has retreat outcome")
	check(xu.key == "xu_ning" and b.level.riders.size() == 12 and b.level.han.defeat_outcome == "captured", "original Xu and chapter roster retained")
	var id: int = hu.get_instance_id()
	var stats := [hu.max_hp,hu.atk,hu.atk_cd,hu.atk_range,hu.base_speed,hu.radius]
	var portrait: String = _texture_pose(hu.ui_portrait_texture())
	if hu.can_learn(0): hu.learn(0)
	check(hu.slot_ready(0), "ordinary level-one Q learning fixture ready before retreat")
	for direction in ART_DIRS:
		hu.animation_direction = direction; hu.face_left = direction in ["sw","nw"]
		var frames: Array = art.unit_anim_frames("hu_yanzhuo","idle",direction)
		check(not frames.is_empty() and _texture_pose(hu._anim_frame_for_state(art.unit_texture("hu_yanzhuo"))) == _texture_pose(frames[0]) and hu._frame_directional, "original Hu exact idle without mirror: " + direction)
		hu.queue_redraw()
		await _art_screenshot(b,"hu_opening_"+direction,hu)
	var cell := _clear_art_patch(b)
	check(cell.x >= 0,"clear patch for explicit original-actor contact fixture")
	if cell.x < 0:
		await _dispose(b); return
	var signals := {"deaths":0,"retreats":0}
	hu.died.connect(func(_u): signals.deaths += 1)
	hu.story_resolved.connect(func(_u,outcome):
		if outcome == "retreated": signals.retreats += 1)
	hu.position = b.map.cell_to_world(cell)
	xu.position = hu.position + Vector2(34,0)
	b._grid_build()
	var counters := {"kills":b.kills,"hero_kills":b.hero_kills.duplicate(true),"gold":b.gold,"wood":b.wood,"next_item_uid":b.next_item_uid,"xp":xu.hero_xp,"level":xu.hero_level,"entity_count":b.units.size()}
	var before: float = hu.hp
	xu.passive = false; xu.auto_micro = false; xu.set_physics_process(true)
	xu.order_attack(hu,false,true)
	var previous: float = hu.hp
	var ticks := 0
	var first_hit := false
	for tick in range(1500):
		await _wait(0.1)
		if hu.hp < previous:
			ticks += 1
			if not first_hit and hu.story_outcome.is_empty():
				first_hit = true
				xu.set_physics_process(false)
				check(hu.hp > 0 and hu.visible and hu.story_outcome.is_empty(), "normal first hit remains living combat actor")
				await _art_screenshot(b,"hu_normal_hit",hu)
				xu.set_physics_process(true)
		previous = hu.hp
		if hu.story_outcome == "retreated": break
	xu.order_stop(); xu.passive = true; xu.set_physics_process(false)
	check(first_hit and ticks > 1 and hu.hp == 1.0 and hu.story_outcome == "retreated" and not hu._dying, "normal repeated Xu attacks retreat full-HP Hu alive at HP1")
	check(hu.get_instance_id() == id and hu.faction == 1 and b.units.has(hu) and not hu.visible, "same enemy actor retained hidden without corpse or conversion")
	check(signals == {"deaths":0,"retreats":1} and b.mission.has_event("lhm_hu_fled"), "normal registered chapter callback once without death signal")
	check(stats == [hu.max_hp,hu.atk,hu.atk_cd,hu.atk_range,hu.base_speed,hu.radius] and portrait == _texture_pose(hu.ui_portrait_texture()), "combat stats and portrait identity unchanged")
	check(b.kills == counters.kills and b.hero_kills == counters.hero_kills and b.gold == counters.gold and b.wood == counters.wood and b.next_item_uid == counters.next_item_uid and b.units.size() == counters.entity_count, "retreat does not award kill/bounty/loot or remove actor")
	check(xu.hero_xp == counters.xp and xu.hero_level == counters.level, "retreat does not grant kill XP to original attacker")
	check(xu._target == null and xu._pending_target == null and not b.selection.has(hu), "callback clears attack references and selection")
	await _art_screenshot(b,"hu_retreated",hu)
	var held: Vector2 = hu.position
	var hp: float = hu.hp
	hu.take_damage(999.0,xu) # Only post-resolution rejection fixture.
	check(hu.hp == hp and not hu.resolve_story("captured") and not hu.resolve_story("retreated") and signals == {"deaths":0,"retreats":1}, "further damage/resolution cannot alter outcome or repeat callback")
	for slot in range(4): check(not hu.slot_ready(slot),"retreated Hu skill blocked: "+str(slot))
	hu.set_physics_process(true)
	hu.order_move(held+Vector2(80,0)); hu.order_attack(xu,false,true)
	xu.order_attack(hu,false,true)
	await _wait(hu.DEATH_DUR+0.5)
	check(is_instance_valid(hu) and not hu.visible and hu.hp == hp and not hu._dying and hu.position == held and hu._target == null and hu._pending_target == null, "hidden living retreat persists inert beyond corpse duration")
	check(signals == {"deaths":0,"retreats":1} and not b.mission.has_event("lhm_victory"), "no duplicate retreat or whole-chapter victory claimed")
	await _art_screenshot(b,"hu_retreat_persistent",hu)
	art_runtime.append({"case":"hu_original_normal_retreat","actor_injected":false,"actor_retained":hu.get_instance_id()==id,"hp_modified":false,"stats_modified":false,"hp_before":before,"hp_after":hu.hp,"damage_ticks":ticks,"hidden":not hu.visible,"signals":signals,"mission_event":b.mission.has_event("lhm_hu_fled"),"normal_attack":true,"contact_position_fixture":true,"battle_coordinator_paused":true,"nonparticipants_frozen":true,"ordinary_q_learning_fixture":true,"kill_rewards_unchanged":b.kills==counters.kills and b.gold==counters.gold and xu.hero_xp==counters.xp,"time_scale":Engine.time_scale})
	await _dispose(b)

func _run() -> void:
	if not _art_profile_guard(): quit(2); return
	AudioServer.set_bus_mute(0,true); Engine.time_scale = 1.0
	art_character = "hu_yanzhuo"
	art_manifest_path = OS.get_environment("ART_MANIFEST")
	art_output = OS.get_environment("ART_QA_OUT")
	art_visual = OS.get_environment("ART_VISUAL") == "1"
	check(art_output.is_absolute_path(),"explicit external QA output")
	DirAccess.make_dir_recursive_absolute(art_output)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(art_manifest_path))
	check(parsed is Dictionary,"current Hu production manifest loaded")
	if not parsed is Dictionary: _art_finish(); return
	art_manifest = parsed
	if art_visual:
		root.unfocusable = true; root.size = Vector2i(1440,960); root.content_scale_size = root.size
		DisplayServer.window_set_size(root.size)
	await process_frame
	art_identity_before = _art_identity()
	if failures.is_empty(): await _normal_retreat()
	art_identity_after = _art_identity()
	check(art_identity_before.get("source_sha256") == art_identity_after.get("source_sha256"),"installed identity unchanged across retreat QA")
	_art_finish()
