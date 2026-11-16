extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen real-level regression. Production handlers and settlement stay active.

func _tick(b) -> void:
	b.level.strategy_t = 0.0
	b.level.process(b, 0.25)

func _setup(keep_enemy: bool):
	var b = await _start("",4)
	b.set_process(false)
	b.set_physics_process(false)
	for u in b.units:
		u.set_physics_process(false)
	var l = b.level
	for wave in l.waves:
		wave.sent = true
		wave.warned = true
	l.production_t = [99999.0,99999.0]
	var sentinel = l.land_groups[2][0] if keep_enemy else null
	for u in b.units.duplicate():
		if alive(u) and u.faction == 1 and u != sentinel and u != l.flagship:
			u.resolve_story("retreated")
	l.flagship.resolve_story("subdued")
	if keep_enemy:
		sentinel.position = b.map.cell_to_world(Vector2i(6,5))
	_tick(b)
	check(l.flagship_disabled and l.core_ready != keep_enemy,"base settlement correctly waits for the remaining unit")
	return [b,sentinel]

func _land(b, verify_briefings: bool) -> void:
	var l = b.level
	var sealing = b.find_unit("ruan_xiaoer_boat")
	var carrier = b.find_unit("zhang_shun_boat")
	l.on_mission_action(b, "gao_seal", sealing)
	_tick(b)
	check(l.port_sealed and (not verify_briefings or b.mission.objective.begins_with("港口已封")),"sealing enables boarding and updates the withdrawal guidance")
	carrier.position = l.flagship.position
	l.on_mission_action(b, "gao_scuttle", carrier)
	_tick(b)
	check(l.recovered and (not verify_briefings or b.mission.objective.begins_with("高俅已在张顺")),"boarding changes guidance to the actual carrier and main pier")
	carrier.position = b.map.cell_to_world(l.LANDING_WATER)
	l.on_mission_action(b, "gao_land", carrier)
	_tick(b)
	check(l.landed and alive(l.prisoner) and (not verify_briefings or b.mission.objective.begins_with("高俅已上岸")),"landing changes guidance to land escort")
	if verify_briefings:
		var localize = root.get_node("Localize")
		for language in ["zh_TW","en","ja"]:
			localize.set_language(language,false)
			var expected: String = localize.text(b.mission.objective)
			check(expected != b.mission.objective and expected == b.mission._objective.text,"landed guidance appears in " + language)
		localize.set_language("zh_CN",false)

func _arrive(b) -> void:
	var l = b.level
	if not alive(l.prisoner): return
	l.prisoner.position = b.map.cell_to_world(l.HALL+Vector2i(0,4))
	l.song.position = l.prisoner.position+Vector2(35,0)
	_tick(b)
	check(b.mission.has_event("gao_captured"),"living prisoner arrives with escort and records the historical event")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var result = await _setup(false)
	var b = result[0]
	check(b.mission.stage_title == "主力已退 · 收兵或押俘","base victory exposes both available endings")
	_land(b,true)
	_arrive(b)
	var victory: Dictionary = b.mission.result_snapshot(true)
	check(b.phase == b.Phase.END and "gao_capture" in victory.done_ids and "已由水军生擒" in b.hud._end_sub.text
		and not b.mission.has_event("gao_basic_victory"),"successful escort grants the capture ending and story goal")
	await _dispose(b)
	result = await _setup(true)
	b = result[0]
	var sentinel = result[1]
	_land(b,false)
	_arrive(b)
	check(b.phase == b.Phase.FIGHT and not b.level.core_ready,"escort arrival alone does not end while original opposition survives")
	if alive(b.level.prisoner):
		b.level.prisoner.take_damage(10000,null,false,true)
	check(b.mission.has_event("gao_captured") and b.mission.has_event("gao_escaped") and b.level.capture_lost,
		"actual prisoner death preserves arrival history and records capture failure")
	if alive(sentinel): sentinel.resolve_story("retreated")
	_tick(b)
	check(b.level.core_ready and b.mission.stage_title == "主力已退 · 收兵通关"
		and b.mission.objective.contains("生擒路线已失去条件"),"after remaining enemies leave, the task shows the available basic ending")
	b.level.activate_mission_button(b,"gao_end")
	var basic: Dictionary = b.mission.result_snapshot(true)
	check(b.phase == b.Phase.END and basic.core_cleared and b.mission.has_event("gao_basic_victory"),
		"official withdraw button settles a base victory after capture loss")
	check("gao_capture" in basic.missed_ids and "本局以击退座船收束" in b.hud._end_sub.text
		and "已由水军生擒" not in b.hud._end_sub.text,"settlement narrative and failed capture seal agree after loss")
	print("GAO_CAPTURE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"frozen real level, production action/loss/settlement handlers"}))
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
