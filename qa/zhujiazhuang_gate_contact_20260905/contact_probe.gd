extends "res://tools/zhujiazhuang_rts_test.gd"
func _run() -> void:
	var b = await _start()
	Engine.time_scale=4
	b.level._introduce_sun(b)
	for u in b.units:
		if u.faction == 1: u.passive=true; u.order_stop(); u.set_process(false)
	var army: Array=[]
	for i in range(32): army.append(b.spawn_at("liang_qiang",0,Vector2i(38+i%6,16+i/6)))
	army.append(b.level.sun)
	_click(b,army,b.level.INNER_CONTACT)
	for i in range(12):
		await _wait(5)
		var u=b.level.sun
		print("CONTACT_PROBE ",JSON.stringify({"time":i*5,"position":str(u.position),"distance":u.position.distance_to(b.map.cell_to_world(b.level.INNER_CONTACT)),"intent":u.mission_order_active,"arrival":u.mission_order_arrival_t,"token":u.mission_order_token,"active":b.mission.active_action_id,"opened":b.level.inside_open}))
	await _dispose(b)
	quit()
