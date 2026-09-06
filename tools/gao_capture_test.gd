extends "res://tools/zhujiazhuang_rts_test.gd"
## Frozen enemy/outcome fixture around real manual actions, sailing and escort.
## Not a live combat route; injected initial states are declared below.
func _until(b,predicate: Callable,seconds: float) -> bool:
	var t := 0.0
	while t<seconds and b.phase==b.Phase.FIGHT:
		if predicate.call(): return true
		await _wait(0.25)
		t+=0.25
	return predicate.call()
func _action_until(b,actor,key: String,predicate: Callable,seconds: float) -> bool:
	var t := 0.0
	while t<seconds and b.phase==b.Phase.FIGHT:
		if predicate.call(): return true
		_action(b,actor,key)
		await _wait(1)
		t+=1
	return predicate.call()
func _fixture():
	var b=await _start("",4)
	Engine.time_scale=4
	var l=b.level
	for wave in l.waves: wave.time=99999
	l.production_t=[99999.0,99999.0]
	for u in b.units:
		if u.faction==1 or u.is_worker: u.set_physics_process(false)
	for group in l.water_groups+l.land_groups:
		for u in group: u.take_damage(10000,null,false,true)
	l.flagship.position=b.map.cell_to_world(Vector2i(43,40))
	l.flagship.take_damage(10000,null,false,true)
	await _wait(0.4)
	return b
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var b=await _fixture()
	var l=b.level
	var two=b.find_unit("ruan_xiaoer_boat")
	var zhang=b.find_unit("zhang_shun_boat")
	var original_zhang_id: int=zhang.get_instance_id()
	var foe=b.spawn_at("imperial_warship",1,Vector2i(44,42))
	foe.set_physics_process(false)
	_action(b,two,"gao_seal")
	await _wait(12)
	check(not l.port_sealed and not b.mission.actions.gao_seal.done,"nearby live enemy prevents seal and leaves action retryable")
	foe.take_damage(10000,null,false,true)
	check(await _action_until(b,two,"gao_seal",func(): return l.port_sealed,20),"real manual order seals cleared port")
	var before: Vector2=zhang.position
	check(await _action_until(b,zhang,"gao_scuttle",func(): return l.recovered,40),"Zhang actually sails to disabled flagship and loads prisoner")
	check(zhang.position.distance_to(before)>200 and zhang.get_meta("carried_story_person","")=="高俅","same moving boat carries prisoner as cargo")
	check(l.prisoner==null and not l.landed,"water rescue creates no prisoner on distant shore")
	check(await _action_until(b,zhang,"gao_land",func(): return l.landed,40),"same cargo boat sails back and transfers at main dock")
	check(zhang.get_instance_id()==original_zhang_id and not zhang.has_meta("carried_story_person"),"landing clears exactly the original boat cargo")
	check(alive(l.prisoner) and b.map.is_open_world(l.prisoner.position,"land") and l.prisoner.position.distance_to(b.map.cell_to_world(l.LANDING))<40,"prisoner is created once at real land-side dock")
	check(not l.prisoner.is_hero and l.prisoner.is_noncombat and l.prisoner.atk==0 and l.prisoner.aura=="" and l.prisoner.ability_slots.is_empty(),"captured Gao cannot fight, cast or give army buffs")
	check(not b._defs.gao_qiu.has("pop"),"prisoner population override does not mutate shared chapter definition")
	check(b.phase==b.Phase.FIGHT and not b.mission.has_event("gao_captured"),"landing alone cannot complete escort objective or win")
	var initial: Vector2=l.prisoner.position
	_click(b,[l.prisoner],l.HALL+Vector2i(0,4))
	await _wait(2)
	check(l.prisoner.position.distance_to(initial)<30,"unescorted prisoner stops near dock instead of walking home alone")
	var escort=b.find_unit("wu_yong")
	_click(b,[escort],l.LANDING+Vector2i(0,-2))
	check(await _until(b,func(): return escort.position.distance_to(l.prisoner.position)<140,35),"player brings a real land escort to dock")
	_click(b,[escort,l.prisoner],l.HALL+Vector2i(0,4))
	check(await _until(b,func(): return b.mission.has_event("gao_captured"),45),"prisoner and guard actually walk to hall")
	check(b.phase==b.Phase.END and l.prisoner.position.distance_to(initial)>300,"only completed land escort triggers captured ending")
	await _dispose(b)
	# Independent death branch: capture failure still permits honest core clear.
	b=await _fixture()
	l=b.level
	zhang=b.find_unit("zhang_shun_boat")
	zhang.take_damage(10000,null,false,true)
	check(l.capture_lost and b.mission.has_event("gao_escaped") and not b.mission.has_event("gao_captured"),"lost required boat marks capture unavailable without granting story credit")
	l.end_button.pressed.emit()
	check(b.phase==b.Phase.END and b.mission.has_event("gao_basic_victory"),"lost capture route preserves basic victory")
	await _dispose(b)
	b=await _fixture()
	l=b.level
	l.song.take_damage(10000,null,false,true)
	l.end_button.pressed.emit()
	check(b.phase==b.Phase.END and not b.mission.has_event("gao_basic_victory"),"commander death cannot be overwritten by stale victory button")
	var folder: String="res://.godot/gao_rts"
	DirAccess.make_dir_recursive_absolute(folder)
	FileAccess.open(folder+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"controlled enemy/outcome fixtures, real manual boat and escort movement"},"\t"))
	print("[gao-capture] ",checks," checks, failures=",failures.size())
	await _dispose(b)
	quit(0 if failures.is_empty() else 1)
