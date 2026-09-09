extends "res://tools/zhujiazhuang_rts_feedback_test.gd"
## SIEGE_TEST=contracts|heroes|engineering. Contract fixtures only suspend their
## own spawned probes. Live routes use the existing real economy/combat drivers:
## no injected health/resources/damage/results, no frozen defenders or mission AI.
var fixture_serial := 0

func _fixture(b, key: String, faction: int):
	fixture_serial += 1
	var u = b.spawn_unit(key, faction, b.map.cell_to_world(Vector2i(57,49)))
	check(u != null, "fixture spawned: " + key)
	if u == null: return null
	u.set_physics_process(false)
	u.position = b.map.cell_to_world(Vector2i(57,49)) + Vector2(fixture_serial % 2 * 90, 0)
	return u

func _projectiles(b, shooter) -> Array:
	return b.fx_root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path == "res://scripts/projectile.gd" and not n.is_queued_for_deletion() and n.shooter == shooter)

func _land(projectiles: Array) -> void:
	for p in projectiles:
		p.set_physics_process(false)
		for tick in range(240):
			if p.is_queued_for_deletion(): break
			p._physics_process(1.0/60.0)
		check(p.is_queued_for_deletion(), "real projectile reached its target")

func _tower_shot(b, tower, target, expected: float, label: String) -> void:
	target.hp = target.max_hp
	tower._target = target
	tower._cd = 0.0
	var before: float = target.hp
	tower._tower_tick(0.0)
	var shots: Array = _projectiles(b, tower)
	check(shots.size() == 1 + tower.passengers.size(), label + " emits expected ordinary arrows")
	_land(shots)
	check(absf(before - target.hp - expected) < 0.02, label + " damage=" + str(before-target.hp))

func _armor_contracts(b) -> void:
	var tower = _fixture(b, "arrow_tower", 0)
	var target = _fixture(b, "siege_ram", 1)
	tower.position = target.position + Vector2(-90,0)
	tower.buff_atk = 1.0
	target.defense = 0.0
	_tower_shot(b,tower,target,51.0,"unarmored target")
	target.defense = 5.0
	_tower_shot(b,tower,target,40.8,"five armor ram")
	target._def_down = 3.0
	_tower_shot(b,tower,target,51.0/1.1,"armor reduction uses effective defense")
	target._def_down = 0.0
	var passenger = _fixture(b,"liang_gong",0)
	tower.passengers.append(passenger)
	_tower_shot(b,tower,target,(51.0+passenger.atk*0.85)/1.25,"tower and garrison arrows")
	tower.passengers.clear()
	target.apply_damage_reduction(0.5,5.0,99901)
	_tower_shot(b,tower,target,20.4,"physical armor and temporary reduction apply once")
	target.clear_damage_reduction()
	target.hp = target.max_hp
	var before: float = target.hp
	target.take_damage(100.0,tower,false,false,"test_skill")
	check(absf(before-target.hp-100.0)<0.01,"skills continue to bypass physical armor")
	passenger.position = target.position+Vector2(-90,0)
	passenger.crit_chance_bonus = -1.0
	passenger._pending_target = target
	target.hp = target.max_hp
	before = target.hp
	passenger._deal_hit()
	var arrows: Array = _projectiles(b,passenger)
	check(arrows.size()==1,"mobile ordinary attack creates one real arrow")
	_land(arrows)
	check(absf(before-target.hp-passenger.atk/1.25)<0.02,"mobile arrow keeps exactly one physical armor application")
	var cannon = _fixture(b,"thunder_tower",0)
	var primary = _fixture(b,"siege_ram",1)
	var secondary = _fixture(b,"siege_ram",1)
	primary.position=b.map.cell_to_world(Vector2i(32,50))
	secondary.position=primary.position+Vector2(0,32)
	cannon.position=primary.position+Vector2(-90,0)
	primary.defense=5.0
	secondary.defense=0.0
	b._grid_build()
	var secondary_before: float=secondary.hp
	_tower_shot(b,cannon,primary,66.0,"existing blast primary damage is unchanged")
	check(absf(secondary_before-secondary.hp-66.0)<0.02,"primary armor does not contaminate separate blast victim")

func _fortification_contracts(b) -> void:
	var gate = _fixture(b,"zhu_gate",1)
	var weapon = _fixture(b,"liang_dao",0)
	var ram = _fixture(b,"siege_ram",0)
	var catapult = _fixture(b,"siege_cata",0)
	for spec in [
		[weapon,false,"",25.0,"ordinary weapon"],
		[weapon,false,"test_skill",25.0,"generic skill"],
		[weapon,true,"test_piercing",25.0,"piercing skill"],
		[null,false,"",25.0,"unattributed ordinary damage"],
		[null,true,"test_dot",25.0,"named DOT with expired source"],
		[ram,false,"",100.0,"ram ordinary hit"],
		[catapult,false,"test_skill",25.0,"generic skill cannot borrow siege exemption"]]:
		gate.hp=gate.max_hp
		var before: float=gate.hp
		gate.take_damage(100.0,spec[0],false,spec[1],spec[2])
		check(absf(before-gate.hp-float(spec[3]))<0.01,String(spec[4])+" observes fortification")
	gate.hp=gate.max_hp
	gate.apply_shield(100.0,5.0)
	gate.take_damage(100.0,weapon)
	check(absf(gate._shield-75.0)<0.01 and gate.hp==gate.max_hp,"fortification applies before shield absorption")
	gate._shield=0.0
	var projectile = load("res://scripts/projectile.gd").new()
	b.fx_root.add_child(projectile)
	projectile.position=gate.position+Vector2(100,0)
	projectile.setup(catapult,gate,100.0)
	projectile.set_physics_process(false)
	var factory = load("res://scripts/run_projectile_state.gd").new(load("res://scripts/run_state_value_codec.gd"),load("res://scripts/projectile.gd"),load("res://scripts/unit.gd"))
	var values: Dictionary=factory._read_values(projectile)
	check(values.size()==12 and factory.REFERENCE_FIELDS.size()==2 and values.kind=="boulder","existing fourteen-field projectile state carries siege provenance")
	var restored = load("res://scripts/projectile.gd").new()
	b.fx_root.add_child(restored)
	factory._assign_values(restored,values)
	restored.target=gate
	restored.shooter=null # Saved reference can be expired when its engine died.
	restored.position=gate.position+Vector2(100,0)
	projectile.queue_free()
	gate.hp=gate.max_hp
	var before: float=gate.hp
	_land([restored])
	check(absf(before-gate.hp-100.0)<0.01,"restored stone keeps siege damage after its shooter expires")
	gate.hp=gate.max_hp
	gate.take_damage(gate.hp+1.0,null,false,true)
	check(gate.hp<=0.0,"explicit source-free internal removal remains effective")

func _scope_contracts(b) -> void:
	for key in ["zhu_gate","arrow_tower"]:
		var actual: Dictionary=b._defs[key].duplicate(true)
		check(actual.get("fortification_damage_mult",1.0)==0.25 and actual.get("fortification_faction",-1)==1,b.level.id()+" has explicit enemy fortification: "+key)
		actual.erase("fortification_damage_mult")
		actual.erase("fortification_faction")
		check(actual==load("res://scripts/defs.gd").UNITS[key],b.level.id()+" preserves shared combat numbers: "+key)
		var enemy = _fixture(b,key,1)
		var friendly = _fixture(b,key,0)
		check(enemy.fortification_regular_damage_mult()==0.25 and friendly.fortification_regular_damage_mult()==1.0,b.level.id()+" fortification is enemy-only: "+key)
	var barracks = _fixture(b,"barracks",1)
	check(barracks.fortification_regular_damage_mult()==1.0,"ordinary enemy production buildings gain no fortification")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	AudioServer.set_bus_mute(0,true)
	var requested: String=OS.get_environment("SIEGE_TEST")
	if requested.is_empty(): requested="contracts"
	out_dir="res://.godot/campaign_siege_balance"
	if not OS.get_environment("SIEGE_TEST_OUT").is_empty(): out_dir=OS.get_environment("SIEGE_TEST_OUT")
	var b = await _start()
	Engine.time_scale=4.0
	if requested=="contracts":
		_armor_contracts(b)
		_fortification_contracts(b)
		_scope_contracts(b)
		await _dispose(b)
		b=await _start("",7)
		_scope_contracts(b)
		await _dispose(b)
		b=await _start("skirmish")
		check(b._defs.zhu_gate==load("res://scripts/defs.gd").UNITS.zhu_gate and b._defs.arrow_tower==load("res://scripts/defs.gd").UNITS.arrow_tower,"fortification definitions do not leak into defense mode")
		await _dispose(b)
	elif requested=="engineering":
		route="direct"
		await _play(b)
		await _dispose(b)
	elif requested=="heroes":
		await _dispose(b) # The inherited real hero probe creates its own campaign.
		route="hero_front"
		await _hero_probe()
	else:
		check(false,"unknown SIEGE_TEST route")
		await _dispose(b)
	Engine.time_scale=1.0
	DirAccess.make_dir_recursive_absolute(out_dir)
	var result: Dictionary={"route":requested,"passed":failures.is_empty(),"checks":checks,"failures":failures,"metrics":play_metrics,"scope":"isolated numerical and real-projectile fixtures" if requested=="contracts" else "live campaign orders and economy; no frozen enemies, forced damage or forced result; not human fun acceptance"}
	FileAccess.open(out_dir+"/"+requested+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("[campaign-siege-balance] ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
