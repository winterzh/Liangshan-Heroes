extends "res://tools/zhujiazhuang_rts_test.gd"
## Input regression with enemy combat paused and actors placed near the drill.
## Movement, action arrival/hold, retreat and final attacks use actual commands.
func _reset_drill(b,l) -> void:
	_click(b,[l.xu],l.DRILL+Vector2i(-2,0))
	for i in range(100):
		await _wait(0.25)
		if alive(l.dummy): return
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b=await _start("",3)
	var l=b.level
	Engine.time_scale=4
	b.fog=false
	for u in b.units:
		u.fog_visible=true
		u.show()
		u.order_stop()
		u.set_stance(u.STANCE_PASSIVE)
		if u.faction==1: u.set_physics_process(false)
	l.xu.position=b.map.cell_to_world(Vector2i(13,45))
	var hook=b.units.filter(func(u): return u.faction==0 and u.key=="gou_lian")[0]
	var lure=b.units.filter(func(u): return u.faction==0 and u.key=="liang_qiang")[0]
	hook.position=b.map.cell_to_world(Vector2i(14,44))
	lure.position=b.map.cell_to_world(Vector2i(19,47))
	await _wait(0.5)
	await _reset_drill(b,l)
	check(alive(l.dummy),"Xu Ning ground move and one-second hold sets up practice rider")
	check(not l.drill_complete and not b.mission.actions.lhm_drill_reset.done,"practice can retry until completed")
	# Premature defeat must not award the optional story goal.
	l.dummy.take_damage(99999,hook,true,true)
	check(not l.drill_complete and not b.mission.has_event("lhm_drill_complete"),"premature practice defeat does not grant story goal")
	await _reset_drill(b,l)
	check(alive(l.dummy) and not l.drill_entered and not l.drill_withdrew,"new manual setup replaces defeated rider and resets practice state")
	_click(b,[lure],l.DRILL_ENTRY+Vector2i(0,2))
	for i in range(60):
		await _wait(0.25)
		if l.drill_entered: break
	check(l.drill_entered and l.drill_lure==lure,"non-hook infantry actually enters lure radius")
	await _wait(5)
	check(not l.drill_withdrew,"practice rider moving away cannot impersonate a player retreat")
	_click(b,[lure],Vector2i(11,46))
	for i in range(80):
		await _wait(0.25)
		if l.drill_withdrew: break
	check(l.drill_withdrew and lure.position.distance_to(l.drill_lure_origin)>80,"real retreat west behind hook line is recorded")
	print("[drill-retreat] lure=",lure.position," origin=",l.drill_lure_origin," dummy=",l.dummy.position," state=",lure._state," target=",lure._target," status=",b.mission._status.text)
	# Nearby idle partners must not be mistaken for a coordinated attack.
	hook.position=l.dummy.position+Vector2(-40,0)
	l.xu.position=l.dummy.position+Vector2(-35,-20)
	await _wait(0.5)
	check(not l.drill_coordinated,"idle Xu Ning and hook soldier do not complete coordinated attack")
	b.select_members([l.xu,hook],false)
	b._issue_order(b.to_screen(l.dummy.position),false)
	for i in range(80):
		await _wait(0.25)
		if l.drill_complete: break
	check(l.drill_coordinated and l.drill_complete and b.mission.has_event("lhm_drill_complete"),"two actual melee attackers complete the drill after lure and retreat")
	var action: Dictionary=b.mission.actions.lhm_drill_reset
	check(action.done and action.button.disabled and action.actor_button.disabled and not action.marker.visible,"completed optional drill closes its action cleanly")
	check(b.phase==b.Phase.FIGHT and alive(l.hall) and l.riders.size()==12,"practice completion preserves ongoing camp and real cavalry battle")
	# Explicit outcome fixture: the live drill event must combine correctly with
	# the remaining story contract at a real win callback, without replaying combat.
	for rider in l.riders: rider.set_meta("formation_broken",true)
	l.broken_count=12
	l._rider_tick(b)
	for rider in l.riders: rider.take_damage(99999,hook,true,true)
	l.han.take_damage(99999,hook,true,true)
	l.enemy_base.take_damage(99999,hook,true,true)
	await _wait(0.5)
	check(b.phase==b.Phase.END and b.mission.has_event("lhm_victory"),"headquarters and twelve-rider outcome fixture closes core objective")
	var result: Dictionary=b.mission.result_snapshot(true)
	check(result.story_done==4 and result.story_complete,"actual drill plus outcome fixtures satisfy all four story goals")
	check(l.hu.story_outcome=="retreated" and l.han.story_outcome=="captured","victory preserves nonlethal outcomes for both historical generals")
	await _dispose(b)
	# A dead instructor is recoverable through ordinary hall recruitment.
	b=await _start("",3)
	l=b.level
	for u in b.units:
		if u.faction==1: u.set_physics_process(false)
	var old_xu=l.xu
	old_xu.take_damage(99999,l.hu,true,true)
	check(b.phase==b.Phase.FIGHT and not alive(old_xu),"instructor death is not a mandatory campaign defeat")
	check(b.queue_train(l.hall,"xu_ning",false),"hall accepts paid instructor revival")
	for i in range(240):
		await _wait(0.5)
		var revived=b.find_unit("xu_ning")
		if alive(revived): break
	var new_xu=b.find_unit("xu_ning")
	check(alive(new_xu),"instructor returns after normal training timer")
	if alive(new_xu):
		new_xu.position=b.map.cell_to_world(Vector2i(13,45))
		_click(b,[new_xu],l.DRILL+Vector2i(-2,0))
		for i in range(100):
			await _wait(0.25)
			if alive(l.dummy): break
	check(alive(l.dummy) and l.xu==new_xu,"revived instructor can dispatch the same optional practice action")
	await _dispose(b)
	check(checks==18,"all expected drill assertions executed")
	Engine.time_scale=1
	var folder="res://qa/lianhuanma_rts_20260905"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/drill.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"isolated input/combat fixtures, not campaign balance"},"\t"))
	print("[lhm-drill] ",checks," checks, failures ",failures)
	quit(0 if failures.is_empty() else 1)
