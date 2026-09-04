extends SceneTree
## Targeted failure / terminal-story contract checks. Damage inputs are test fixtures,
## distinct from campaign_later_playthrough.gd which plays normal movement and combat.
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, name: String) -> void:
	print("[later-contract] ",name," ","PASS" if ok else "FAIL")
	if not ok: failures.append(name)
func _start(id: String):
	seed(5088120)
	var campaign = root.get_node("Campaign")
	for i in range(campaign.LEVELS.size()):
		if campaign.LEVELS[i].id == id: campaign.current = i
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	Engine.time_scale = 4.0
	return b
func _dispose(b) -> void:
	b.queue_free()
	await process_frame
	await process_frame
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	var b = await _start("level3")
	check(not b.mission.request_action("zhu_open_gate"),"zhu_cannot_skip_scout_to_open_gate")
	b.level.song.take_damage(1000000.0)
	check(b.phase == b.Phase.END and not b.mission.has_event("zhu_victory"),"zhu_commander_death_fails")
	await _dispose(b)
	b = await _start("level3")
	check(b.level.stage == "scout" and b.mission.events.is_empty(),"zhu_restart_resets_story_events")
	b._smoke = true
	var frames := 0
	while b.level.stage != "send_hu" and b.phase != b.Phase.END and frames < 3000:
		await process_frame
		frames += 1
	b._smoke = false
	check(b.level.stage == "send_hu" and b.level.hu.story_outcome == "captured" and b.level.hu.faction == b.level.hu.FACTION_GUAN,"zhu_hu_captured_without_changing_sides")
	if b.level.stage == "send_hu":
		b.mission.request_action("zhu_escort_hu")
		check(not b.mission.request_action("zhu_escort_hu"),"zhu_duplicate_escort_request_rejected")
		b._smoke = true
		frames = 0
		while b.level.stage != "inside" and b.phase != b.Phase.END and frames < 1500:
			await process_frame
			frames += 1
		b._smoke = false
		check(b.level.stage == "inside" and b.find_unit("hu_sanniang") == null and b.mission.has_event("zhu_hu_departed"),"zhu_third_day_redeploys_without_hu")
		check(b.level.prisoners.size() == 7 and b.level.prisoners.all(func(u): return is_instance_valid(u) and u.hp > 0.0 and u.is_captive),"zhu_seven_live_captives_before_inside_rescue")
		if not b.level.prisoners.is_empty():
			b.level.prisoners[0].take_damage(1000000.0)
			check(b.phase != b.Phase.END and b.mission.has_event("zhu_prisoner_lost") and not b.mission.has_event("zhu_victory"),"zhu_prisoner_loss_misses_story_but_campaign_continues")
	await _dispose(b)
	b = await _start("level4")
	check(b.enemies_alive() == 0 and not b.mission.request_action("lhm_signal"),"lhm_no_battle_before_training")
	b._smoke = true
	frames = 0
	while b.level.stage != "battle" and b.phase != b.Phase.END and frames < 3000:
		await process_frame
		frames += 1
	b._smoke = false
	check(b.level.stage == "battle" and b.mission.has_event("lhm_drill_complete"),"lhm_training_actual_walk_and_attack")
	if b.level.stage == "battle":
		var han = b.level.han
		var hu = b.level.hu
		var kills_before: int = b.kills
		var bolt_target = b.find_unit("xu_ning")
		var target_hp: float = bolt_target.hp
		var target_stun: float = bolt_target._stun_t
		b._spawn_bolt(han, bolt_target, {}, {"dmg":90.0,"stun":3.0,"proj_speed":420.0}, 1.0, 1)
		han.take_damage(1000000.0)
		han.take_damage(1000000.0)
		hu.take_damage(1000000.0)
		hu.take_damage(1000000.0)
		check(han.story_outcome == "captured" and han.hp > 0,"han_atomic_captured_not_dead")
		check(hu.story_outcome == "retreated" and hu.hp > 0,"huyan_atomic_retreat_not_dead")
		check(b.kills == kills_before and not b.mission.has_event("lhm_victory"),"terminal_hits_no_kills_or_premature_victory")
		b._bolt_pass(50.0)
		check(is_equal_approx(bolt_target.hp,target_hp) and bolt_target._stun_t <= target_stun,"resolved_caster_inflight_bolt_has_no_damage_or_control")
	await _dispose(b)
	b = await _start("level4")
	b.level.xu.take_damage(1000000.0)
	frames = 0
	while b.level.stage not in ["prepare","battle"] and b.phase != b.Phase.END and frames < 300:
		await process_frame
		frames += 1
	check(b.phase != b.Phase.END and b.level.stage in ["prepare","battle"] and b.level.training_skipped and b.mission.has_event("lhm_training_skipped") and not b.mission.has_event("lhm_victory"),"lhm_training_instructor_loss_skips_story_but_campaign_continues")
	await _dispose(b)
	b = await _start("level8")
	check(b.find_unit("song_jiang") == null,"daming_song_jiang_not_in_battle")
	check(not b.mission.request_action("daming_lu_exit"),"daming_no_escape_before_rescue")
	b.level.lu.take_damage(1000000.0)
	check(b.phase == b.Phase.END and not b.mission.has_event("daming_victory"),"daming_bound_prisoner_death_fails")
	await _dispose(b)
	b = await _start("level8")
	check(b.level.stage == "approach" and b.mission.events.is_empty() and b.level.lu.is_captive and b.level.shi.is_captive,"daming_restart_restores_bound_prisoners_and_events")
	b._smoke = true
	frames = 0
	while not b.level.rescued and b.phase != b.Phase.END and frames < 6000:
		await process_frame
		frames += 1
	b._smoke = false
	check(b.level.rescued and b.level.gate_open,"daming_walkthrough_to_rescue")
	if b.level.rescued:
		check(not b.mission.request_action("daming_signal") and not b.mission.request_action("daming_unlock"),"daming_completed_fire_and_unlock_cannot_repeat")
		b.level.shi.take_damage(1000000.0)
		check(b.phase == b.Phase.END and not b.mission.has_event("daming_victory"),"daming_rescued_prisoner_death_still_fails")
		check(not b.mission.request_action("daming_lu_exit"),"daming_death_cannot_be_repaired_by_exit_action")
	await _dispose(b)
	print("[later-contract-result] ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	Engine.time_scale = 1.0
	quit(0 if failures.is_empty() else 1)
