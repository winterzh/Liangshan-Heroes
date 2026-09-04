extends SceneTree
## Mission walk-through: same request_action + actual movement/combat as players; no injected victory.
const CASES := {"level3":"zhu_victory","level4":"lhm_victory","level8":"daming_victory"}
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	var campaign = root.get_node("Campaign")
	var save_existed := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_before := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_existed else PackedByteArray()
	var requested := OS.get_environment("LATER_QA_LEVELS")
	var frame_limit := int(OS.get_environment("LATER_QA_MAX_FRAMES")) if OS.has_environment("LATER_QA_MAX_FRAMES") else 18000
	var ok := true
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	for key in CASES:
		if requested != "" and not key in requested.split(","): continue
		for i in range(campaign.LEVELS.size()):
			if campaign.LEVELS[i].id == key: campaign.current = i
		seed(5088120)
		var b = load("res://scenes/main.tscn").instantiate()
		root.add_child(b)
		current_scene = b
		await process_frame
		b.hud._intro_root.hide()
		b._on_intro_done()
		b._smoke = true
		b.hud._on_start_pressed()
		Engine.time_scale = 4.0
		var frames := 0
		while b.phase != b.Phase.END and frames < frame_limit:
			await process_frame
			frames += 1
			if frames%900 == 0:
				print("[later-progress] ",key," stage=",b.level.stage," action=",b.mission.active_action_id," events=",b.mission.events.keys())
		var story_result: Dictionary = b.mission.result_snapshot(true)
		var passed: bool = b.mission.has_event(CASES[key]) and b.phase == b.Phase.END and bool(story_result.get("story_complete", false))
		print("[later-result] ",JSON.stringify({"id":key,"passed":passed,"frames":frames,"stage":b.level.stage,"events":b.mission.events.keys(),"total_game_seconds":b.mission.total_game_seconds,"stage_metrics":b.mission.stage_metrics,"story_result":story_result}))
		if not passed:
			var snapshot := []
			for u in b.units:
				if is_instance_valid(u): snapshot.append({"key":u.key,"hp":u.hp,"cell":str(b.map.world_to_cell(u.position)),"outcome":u.story_outcome})
			print("[later-units] ",JSON.stringify(snapshot))
		ok = ok and passed
		b.queue_free()
		await process_frame
		await process_frame
	Engine.time_scale = 1.0
	var save_exists_now := FileAccess.file_exists(campaign.SAVE_PATH)
	var save_after := FileAccess.get_file_as_bytes(campaign.SAVE_PATH) if save_exists_now else PackedByteArray()
	var save_unchanged := save_existed == save_exists_now and save_before == save_after
	print("[later-save] ",JSON.stringify({"campaign_qa":OS.get_environment("CAMPAIGN_QA"),"unchanged":save_unchanged}))
	ok = ok and save_unchanged
	quit(0 if ok else 1)
