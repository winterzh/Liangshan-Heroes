extends "res://tools/zhujiazhuang_rts_test.gd"
## Isolated input/geometry regression, not a balance or combat playthrough.
var evidence := {}
func freeze_foes(b) -> void:
	for u in b.units:
		if u.faction==1: u.passive=true; u.order_stop(); u.set_physics_process(false)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b=await _start()
	Engine.time_scale=4
	freeze_foes(b)
	var l=b.level
	l._introduce_sun(b)
	var action=b.mission.actions.zhu_rts_inside
	var original_position: Vector2=l.sun.position
	action.actor_button.pressed.emit()
	check(b.selection==[l.sun],"actor locator selects Sun Li")
	check(l.sun.position==original_position and not l.sun.mission_order_active,"locator does not move or dispatch the hero")
	_click(b,[l.song,b.find_unit("lin_chong")],l.INNER_CONTACT)
	check(b.mission._status.text.contains("需要孙立"),"wrong heroes receive actor requirement immediately")
	check(not l.sun.mission_order_active,"wrong hero click never recruits unselected Sun Li")
	# Original failure: Sun Li's last formation slot stopped about 88px away.
	var army: Array=[]
	for i in range(32): army.append(b.spawn_at("liang_qiang",0,Vector2i(38+i%6,16+i/6)))
	army.append(l.sun)
	b.select_members(army,false)
	var destination: Vector2=b.map.cell_to_world(l.INNER_CONTACT)
	b._issue_order(b.to_screen(destination)+Vector2(0,-22),false) # visible flag, not exact ground center
	for i in range(100):
		await _wait(0.5)
		if b.mission.active_action_id=="zhu_rts_inside": break
	check(b.mission.active_action_id=="zhu_rts_inside","33-unit group right-click on visible flag starts contact")
	evidence["group_actor_distance"]=l.sun.position.distance_to(destination)
	check(l.sun.position.distance_to(destination)<=64,"selected actor reaches task radius despite formation")
	await _wait(1)
	check(not l.inside_open,"contact must hold for full five seconds")
	b._stamp_manual([l.sun])
	l.sun.order_hold_position()
	await _wait(5.5)
	check(not l.inside_open and b.mission.active_action_id=="","new hold command cancels contact without auto-resuming")
	_click(b,[l.sun],l.INNER_CONTACT,true)
	await _wait(1)
	check(b.mission.active_action_id=="","attack-move cannot claim a mission action")
	_click(b,[l.sun],l.INNER_CONTACT)
	for i in range(50):
		await _wait(0.5)
		if l.inside_open: break
	check(l.inside_open and b.mission.has_event("zhu_gate_opened"),"fresh player move completes contact and story event")
	check(action.done and not action.marker.visible and action.actor_button.disabled,"completed action hides marker and disables locator")
	check(alive(l.gate),"inside contact leaves main gate intact")
	check(not b.map.find_path(b.map.cell_to_world(Vector2i(25,18)),b.map.cell_to_world(Vector2i(16,18))).is_empty(),"opened side gate is actually traversable")
	var visual=load("res://scripts/campaign_gate_visual.gd")
	var tex=root.get_node("Art").unit_texture(l.gate.key,l.gate.art_variant)
	var tr: Transform2D=visual.source_transform(l.gate,tex.get_size())
	var endpoint: Vector2=b.map.project(Vector2(0,64))
	check((tr*(l.gate.get_meta("campaign_gate_source_left",visual.SOURCE_LEFT)*tex.get_size())).distance_to(-endpoint)<0.01,"gate source left foot matches north stockade end")
	check((tr*(l.gate.get_meta("campaign_gate_source_right",visual.SOURCE_RIGHT)*tex.get_size())).distance_to(endpoint)<0.01,"gate source right foot matches south stockade end")
	check(absf(tr.y.x)<0.001 and tr.y.y>0,"gate roof and poles remain upright")
	var shadow: Transform2D=visual.source_transform(l.gate,tex.get_size(),Vector2(-0.35,0.24))
	check((shadow*(l.gate.get_meta("campaign_gate_source_left",visual.SOURCE_LEFT)*tex.get_size())).distance_to(-endpoint)<0.01 and (shadow*(l.gate.get_meta("campaign_gate_source_right",visual.SOURCE_RIGHT)*tex.get_size())).distance_to(endpoint)<0.01,"shadow retains both wall contact anchors")
	await _dispose(b)
	b=await _start()
	Engine.time_scale=4
	freeze_foes(b)
	l=b.level
	l._introduce_sun(b)
	l.side_gate.hp=0
	l.on_unit_died(b,l.side_gate)
	check(not b.mission.actions.zhu_rts_inside.done and not b.mission.actions.zhu_rts_inside.marker.visible,"destroyed gate closes obsolete action without false success")
	b.mission.focus_action("zhu_rts_inside")
	check(b.mission._status.text.contains("偏门已被攻破"),"destroyed gate explains alternate route")
	check(not b.mission.request_action("zhu_rts_inside"),"blocked action cannot be dispatched by regression API")
	await _dispose(b)
	b=await _start()
	Engine.time_scale=4
	freeze_foes(b)
	l=b.level
	l._introduce_sun(b)
	l.sun.hp=0
	l.on_unit_died(b,l.sun)
	check(b.mission.actions.zhu_rts_inside.actor_button.disabled,"dead Sun disables locator")
	check(b.mission._status.text.contains("孙立已阵亡") and b.phase==b.Phase.FIGHT,"dead Sun explains siege alternative and campaign continues")
	await _dispose(b)
	var folder: String="res://qa/zhujiazhuang_gate_contact_20260905"
	if not OS.get_environment("RTS_TEST_OUT").is_empty(): folder=OS.get_environment("RTS_TEST_OUT")
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"evidence":evidence,"fixture":"enemy simulation paused for input tests; not combat balance evidence"},"\t"))
	print("[gate-contact] ",checks," checks, failures ",failures)
	quit(0 if failures.is_empty() else 1)
