extends "res://tools/art_character_direction4_qa.gd"
## Actual installed Unit graph capture/bind/recapture; map and root are not restored.
var Profiles: Script
var UnitGraph: Script
var UnitState: Script
var Identity: Script
var Codec: Script
var UnitScript: Script
var Inventory: Script
var BattleScript: Script
var MapScript: Script
var GaoFactory: Script
var DamingFactory: Script
var trusted: Dictionary

func _graph(id: String):
	return UnitGraph.new(UnitState,Identity,Codec,UnitScript,Inventory,BattleScript,MapScript,{"mode":"campaign","level_id":id,"waves":0})

func _roundtrip(b,label: String) -> void:
	var id: String=b.level.id();var version: String=trusted.content_version;var mission_token: String="mission:"+id+":core"
	var graph=_graph(id);var objects := {};var original := {}
	for u in b.units_root.get_children():objects[u]=str(u.entity_id);original[str(u.entity_id)]=u
	var captured: Dictionary=graph.capture(b,objects,version,null,{"mission_token":mission_token,"deferred_drained":true})
	check(captured.get("ok",false),label+" actual Unit graph capture")
	if not captured.get("ok",false):print(captured);return
	var external := {}
	if id=="level5" and is_instance_valid(b.level.end_button):external["level5:end"]=true
	var checked: Dictionary=graph.validate(captured.value,version,captured.level_record,mission_token,external)
	check(checked.get("ok",false),label+" complete graph membership and references validate")
	if not checked.get("ok",false):print(checked);captured.identity.dispose();return
	var owner=BattleScript.new();owner.process_mode=Node.PROCESS_MODE_DISABLED;owner.set_block_signals(true)
	owner.map=MapScript.new();owner.map.process_mode=Node.PROCESS_MODE_DISABLED;owner.map.set_block_signals(true);owner.add_child(owner.map)
	owner.units_root=Node2D.new();owner.units_root.process_mode=Node.PROCESS_MODE_DISABLED;owner.units_root.set_block_signals(true);owner.add_child(owner.units_root)
	owner.next_entity_id=b.next_entity_id
	var prepared: Dictionary=graph.prepare(captured.value,version,owner,owner.map,captured.level_record,mission_token,external)
	check(prepared.get("ok",false),label+" original Unit state instantiated and bound into new registry")
	if not prepared.get("ok",false):print(prepared);captured.identity.dispose();owner.free();return
	check(not prepared.attached and not prepared.activated and not prepared.complete_battle_restore,label+" preparation remains detached inactive and partial")
	check(prepared.units_in_root_order.size()==original.size() and prepared.active_units.size()==b.units.size(),label+" root and active order sizes preserved")
	for entity_id in prepared.id_to_unit:
		var old=original[entity_id];var fresh=prepared.id_to_unit[entity_id]
		check(old!=fresh and old.entity_id==fresh.entity_id and old.key==fresh.key and old.hp==fresh.hp and old.position==fresh.position and old.art_variant==fresh.art_variant and old.story_outcome==fresh.story_outcome,label+" actual actor identity/health/position/story "+entity_id)
		if old.has_meta("daming_mine"):
			var mine=old.get_meta("daming_mine");var bound=fresh.get_meta("daming_mine")
			check(is_instance_valid(mine) and bound==prepared.id_to_unit[str(mine.entity_id)] and bound!=mine,label+" mine metadata binds NEW actual mineral "+entity_id)
	var buttons := {};var inverse := {}
	if not external.is_empty():
		var button=Button.new();button.process_mode=Node.PROCESS_MODE_DISABLED;button.set_block_signals(true)
		buttons["level5:end"]=button;inverse[button]="level5:end"
	var level: Dictionary=GaoFactory.restore_level(captured.level_record,trusted,prepared.id_to_unit,b.next_entity_id,mission_token,buttons) if id=="level5" else DamingFactory.restore_level(captured.level_record,trusted,prepared.id_to_unit,b.next_entity_id,mission_token)
	check(level.get("ok",false),label+" Level binds restored real Unit registry")
	if not level.get("ok",false):print(level)
	else:
		owner.level=level.level
		# Attach only under a disabled, detached owner. No Unit _ready/simulation occurs.
		for u in prepared.units_in_root_order:owner.units_root.add_child(u)
		owner.units.assign(prepared.active_units)
		prepared.identity.release_tombstones()
		# Explicit detached-node fixture: restore saved activation flags for recapture.
		# The disabled owner is never mounted, so this cannot run physics or _ready.
		for row in prepared.activation_plan:
			var u=row.unit;var a: Dictionary=row.activation
			u.process_priority=a.priority;u.process_physics_priority=a.physics_priority
			u.set_process(a.process);u.set_physics_process(a.physics);u.set_process_input(a.input)
			u.set_process_shortcut_input(a.shortcut);u.set_process_unhandled_input(a.unhandled_input);u.set_process_unhandled_key_input(a.unhandled_key)
			u.set_block_signals(a.signals_blocked);u.process_mode=a.mode
		var again: Dictionary=graph.capture(owner,prepared.object_to_id,version,prepared.identity,{"mission_token":mission_token,"deferred_drained":true}) if external.is_empty() else {"ok":false,"scope":"Full Mission button ownership requires outer presentation restore; not bypassed here."}
		if external.is_empty():
			check(again.get("ok",false),label+" bound Unit graph recaptured without simulation")
			if not again.get("ok",false):print(again)
			else:check(again.value==captured.value and again.level_record==captured.level_record,label+" exact complete Unit and Level payload preserved")
	# Malformed mine references are rejected before Unit allocation.
	if id=="level8":
		var worker=b.level.enemy_workers[0];var position: int=captured.value.root_order.find(str(worker.entity_id));var altered: Dictionary=captured.value.duplicate(true)
		var payload: Dictionary=Codec.new().decode(altered.records[position].payload).value
		payload.metadata.daming_mine.tag={"state":"entity","id":"999999999"};altered.records[position].payload=Codec.new().encode(payload).value
		check(not graph.validate(altered,version,captured.level_record,mission_token,external).ok,label+" unknown mineral id rejected before allocation")
		payload.metadata.daming_mine.tag={"state":"entity","id":str(b.level.hall.entity_id)};altered.records[position].payload=Codec.new().encode(payload).value
		check(not graph.validate(altered,version,captured.level_record,mission_token,external).ok,label+" hall impersonating mineral rejected by graph contract")
		altered=captured.value.duplicate(true);altered.active_order.erase(str(b.level.lu.entity_id))
		check(not graph.validate(altered,version,captured.level_record,mission_token,external).ok,label+" living captive missing active membership rejected")
	art_runtime.append({"case":label,"chapter":id,"units":original.size(),"source_payload":captured.value,"level_payload":captured.level_record,"scope":"Actual Unit graph capture and original state construction/remapping, including Daming mineral metadata. Disabled detached owner/map shell; no complete root/map/scenery/clock/FX/Mission restore, independent process or natural ending qualification."})
	prepared.identity.dispose();captured.identity.dispose()
	for u in prepared.units_in_root_order:
		if u.get_parent()==null:u.free()
	for button in buttons.values():button.free()
	owner.free()

func _case(index: int) -> void:
	var b=await _start("",index)
	for frame in range(4):await physics_frame
	await process_frame;paused=true
	await _roundtrip(b,b.level.id()+" initial")
	if index==4:
		var liu=b.find_unit("liu_tang")
		# Explicit contact fixture; original paid prepare action/resolution handles state.
		liu.position=b.map.cell_to_world(Vector2i(20,49));b.level.fireboat.position=b.map.cell_to_world(Vector2i(22,52))
		var wood: int=b.wood;b.level.on_mission_action(b,"gao_wind",b.find_unit("gongsun_sheng"));b.level.on_mission_action(b,"gao_prepare",liu)
		check(b.level.fire_prepared and b.level.embarked_liu==liu and liu.story_outcome=="embarked" and b.wood==wood-60,"actual paid Liu embark action and reservation")
		await process_frame;await _roundtrip(b,"level5 Liu embarked")
		b.level._send_wave(b,0)
		check(b.level.waves[0].sent,"original water/land wave orders dispatched")
		await _roundtrip(b,"level5 wave sent")
	else:
		b.level.scout._break_invis();b.level._spy_tick(b,0.25)
		check(not b.level.scout.get_meta("daming_covered"),"actual disguise break recorded")
		await _roundtrip(b,"level8 exposed scout")
		# Original gate/prison and rescue methods, explicit safe contact fixture.
		b.level._open_gate(b,true);b.level._open_prison(b,true)
		for u in b.units:
			if alive(u) and u.faction==1 and not u.is_building:u.position=b.map.cell_to_world(Vector2i(44,8))
		b.level.chai.position=b.map.cell_to_world(Vector2i(19,15));b.level.yue.position=b.level.chai.position+Vector2(25,0)
		b.level.on_mission_action(b,"daming_rescue",b.level.chai)
		check(b.level.rescued and not b.level.lu.is_captive and b.level.lu.base_speed==68.0,"original prisoner rescue callback")
		await process_frame;await _roundtrip(b,"level8 gate open rescued")
	paused=false;await _dispose(b)

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	Profiles=load("res://scripts/run_official_restore_profile.gd");UnitGraph=load("res://scripts/run_unit_graph.gd");UnitState=load("res://scripts/run_unit_state.gd")
	Identity=load("res://scripts/run_graph_identity.gd");Codec=load("res://scripts/run_state_value_codec.gd");UnitScript=load("res://scripts/unit.gd")
	Inventory=load("res://scripts/hero_inventory.gd");BattleScript=load("res://scripts/battle.gd");MapScript=load("res://scripts/game_map.gd")
	GaoFactory=load("res://scripts/run_level5_world_factory.gd");DamingFactory=load("res://scripts/run_level8_world_factory.gd")
	art_output=OS.get_environment("ART_QA_OUT");art_character="campaign_units_v19";art_visual=false
	trusted=_art_identity();check(trusted.get("save_eligible",false),"installed input identity")
	if not trusted.get("save_eligible",false):_art_finish();return
	for index in [4,7]:await _case(index)
	_art_finish()
