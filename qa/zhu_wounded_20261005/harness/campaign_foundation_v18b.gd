extends "res://tools/art_character_direction4_qa.gd"
## Installed Level/presentation components from actual chapter launches.
## Detached Unit shells bind IDs only: this is deliberately not full world restore.
var Profiles: Script
var GaoFactory: Script
var DamingFactory: Script
var LevelState: Script
var Presentation: Script
var MissionState: Script
var UnitScript: Script
var BattleScript: Script
var UnitGraph: Script
var trusted: Dictionary

func _context(id: String) -> Dictionary:
	return {"level_id":id,"content_version":trusted.content_version,"mission_token":"mission:"+id+":core","presentation_token":"presentation:"+id+":core"}

func _id_registry(b) -> Dictionary:
	var ids := {}
	for u in b.units_root.get_children():
		if u.get_script()==UnitScript:ids[str(u.entity_id)]=u
	return ids

func _component(b, label: String) -> void:
	var id: String=b.level.id();var context:=_context(id);var ids:=_id_registry(b)
	var pc: Dictionary=Presentation.new().capture(b.mission,context)
	check(pc.get("ok",false),label+" original Mission presentation capture")
	if not pc.get("ok",false):print(pc);return
	var mc: Dictionary=MissionState.new().capture(b.mission,context,ids,b.next_entity_id,pc.external_to_token,Time.get_ticks_msec(),{"deferred_drained":true,"presentation_captured":true})
	check(mc.get("ok",false),label+" original Mission state capture")
	if not mc.get("ok",false):print(mc);return
	var external := {}
	if id=="level5" and is_instance_valid(b.level.end_button):external[b.level.end_button]="level5:end"
	var lc: Dictionary=LevelState.new().capture(b.level,id,trusted.content_version,ids,b.next_entity_id,external,{"mission_token":context.mission_token,"deferred_drained":true})
	check(lc.get("ok",false),label+" original Level capture all declared fields")
	if not lc.get("ok",false):print(lc);return
	var before_mission: Dictionary=b.mission.events.duplicate(true)
	var owner=BattleScript.new();owner.process_mode=Node.PROCESS_MODE_DISABLED;owner.set_block_signals(true)
	owner.hud=load("res://scripts/hud.gd").new();owner.hud.process_mode=Node.PROCESS_MODE_DISABLED;owner.hud.set_block_signals(true);owner.add_child(owner.hud)
	owner.fx_root=Node2D.new();owner.fx_root.process_mode=Node.PROCESS_MODE_DISABLED;owner.fx_root.set_block_signals(true);owner.add_child(owner.fx_root)
	owner.map=b.map # Read-only geometry borrowed for this isolated UI component.
	owner.level=Profiles.level_script(Profiles.GAO_ID if id=="level5" else Profiles.DAMING_ID).new()
	var shells: Dictionary={}
	for entity_id in ids:
		var u=UnitScript.new();u.entity_id=ids[entity_id].entity_id;u.key=ids[entity_id].key
		u.process_mode=Node.PROCESS_MODE_DISABLED;u.set_block_signals(true);shells[entity_id]=u
	var adapter=Presentation.new()
	var rebuilt: Dictionary=adapter.prepare(owner,pc.record,mc.record,context,shells,b.next_entity_id,Time.get_ticks_msec())
	check(rebuilt.get("ok",false),label+" fixed Mission UI recreated detached and gated")
	if not rebuilt.get("ok",false):print(rebuilt)
	else:
		check(not rebuilt.begin_called and rebuilt.events_replayed==0 and not rebuilt.complete_world,label+" reconstruction never begins chapter or replays events")
		check(owner.mission.events==before_mission and b.mission.events==before_mission,label+" original and rebuilt event ledgers unchanged")
		var tokens := {}
		if id=="level5" and rebuilt.level_buttons.has("gao_end"):tokens["level5:end"]=rebuilt.level_buttons.gao_end
		var factory=GaoFactory if id=="level5" else DamingFactory
		var restored: Dictionary=factory.restore_level(lc.record,trusted,shells,b.next_entity_id,context.mission_token,tokens) if id=="level5" else factory.restore_level(lc.record,trusted,shells,b.next_entity_id,context.mission_token)
		check(restored.get("ok",false),label+" installed factory restores every Level reference and value")
		if not restored.get("ok",false):print(restored)
		else:
			owner.level=restored.level
			check(not restored.deploy_or_start_called and not restored.complete_world,label+" factory has no deployment or full-world claim")
			var inverse: Dictionary={}
			for token in tokens:inverse[tokens[token]]=token
			var recaptured: Dictionary=LevelState.new().capture(owner.level,id,trusted.content_version,shells,b.next_entity_id,inverse,{"mission_token":context.mission_token,"deferred_drained":true})
			check(recaptured.get("ok",false) and recaptured.get("record",{})==lc.record,label+" restored Level recaptures byte-equivalent payload")
			check(owner.level.hall==shells[str(b.level.hall.entity_id)],label+" hall binds new registry rather than old actor")
			if not tokens.is_empty():
				var button: Button=owner.level.end_button;var connections:=button.get_signal_connection_list("pressed")
				check(button==tokens["level5:end"] and connections.size()==1,label+" restored end_button is exact Mission-owned replacement")
				check(connections.size()==1 and connections[0].callable.get_object()==owner.mission and connections[0].callable.get_method()=="_activate_level_button" and connections[0].callable.get_bound_arguments()==["gao_end"],label+" callback belongs to rebuilt Mission with fixed gao_end id")
				var refused: Dictionary=GaoFactory.restore_level(lc.record,trusted,shells,b.next_entity_id,context.mission_token,{})
				check(not refused.ok,label+" missing required external button rejected")
			var stale: Dictionary=trusted.duplicate(true);stale.content_version+="-stale"
			var refused: Dictionary=factory.restore_level(lc.record,stale,shells,b.next_entity_id,context.mission_token,tokens) if id=="level5" else factory.restore_level(lc.record,stale,shells,b.next_entity_id,context.mission_token)
			check(not refused.ok,label+" mismatched installed content rejected")
	adapter.dispose();owner.map=null;owner.free()
	for u in shells.values():u.free()
	art_runtime.append({"case":label,"chapter":id,"original_units":ids.size(),"scope":"Actual chapter Level and Mission capture; detached ID-only Unit shells and read-only original map used for UI/Level components. Does not prove Unit state/world restore, independent continue, natural ending or rewards."})

func _case(index: int) -> void:
	var b=await _start("",index)
	for frame in range(4):await physics_frame
	await process_frame;paused=true
	var id: String=b.level.id();check(id==("level5" if index==4 else "level8"),"original installed chapter launch "+str(index))
	await _component(b,id+" initial")
	if index==4:
		b.level.activate_mission_button(b,"gao_end")
		check(b.phase==BattleScript.Phase.FIGHT,"early Gao end handler enforces original threats")
		b.level.activate_mission_button(b,"unknown")
		check(b.phase==BattleScript.Phase.FIGHT,"unknown Gao button id ignored")
		# Explicit stage fixture: original enemies take real lethal/resolution damage.
		# No fake actors, direct counter assignment or natural-victory claim.
		for group in b.level.water_groups+b.level.land_groups:
			for u in group:
				if alive(u):u.take_damage(100000.0,null,false,true)
		if alive(b.level.flagship):b.level.flagship.take_damage(100000.0,null,false,true)
		b.level.process(b,0.5)
		check(b.level._core_threats_clear() and is_instance_valid(b.level.end_button),"original resolved enemies create Gao authored end control")
		await process_frame;await process_frame
		await _component(b,"level5 end_button")
		if is_instance_valid(b.level.end_button):
			b.level.end_button.pressed.emit()
			check(b.phase==BattleScript.Phase.END and b.mission.has_event("gao_basic_victory"),"original fixed Mission callback reaches authored basic ending")
	paused=false;await _dispose(b)

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	Profiles=load("res://scripts/run_official_restore_profile.gd")
	GaoFactory=load("res://scripts/run_level5_world_factory.gd")
	DamingFactory=load("res://scripts/run_level8_world_factory.gd")
	LevelState=load("res://scripts/run_campaign_level_state.gd")
	Presentation=load("res://scripts/run_campaign_presentation_state.gd")
	MissionState=load("res://scripts/run_campaign_mission_state.gd")
	UnitScript=load("res://scripts/unit.gd")
	BattleScript=load("res://scripts/battle.gd")
	UnitGraph=load("res://scripts/run_unit_graph.gd")
	art_output=OS.get_environment("ART_QA_OUT");art_character="campaign_foundation_v18b";art_visual=false
	trusted=_art_identity();check(trusted.get("save_eligible",false),"installed runtime identity eligible")
	if not trusted.get("save_eligible",false):_art_finish();return
	var campaign=root.get_node("Campaign");var flags_before={}
	for field in ["current","skirmish","skirmish_ai","arena","custom_defense","scenario"]:flags_before[field]=campaign.get(field)
	var definitions: Dictionary=load("res://scripts/defs.gd").UNITS.duplicate(true)
	for factory in [GaoFactory,DamingFactory]:
		var runtime: Dictionary=factory.prepare_runtime(trusted)
		check(runtime.get("ok",false) and not runtime.get("deploy_or_start_called",true),"installed inert chapter runtime "+str(factory))
		if not runtime.get("ok",false):print(runtime)
		check(load("res://scripts/defs.gd").UNITS==definitions,"runtime preparation leaves global definitions unchanged")
	for field in flags_before:check(campaign.get(field)==flags_before[field],"selection/factory leaves Campaign flag "+field)
	for id in [Profiles.CLASSIC_ID,Profiles.HG_ID,Profiles.JIANG_ID,Profiles.ZHU_ID,Profiles.LIAN_ID,Profiles.GAO_ID,Profiles.YEZHU_ID,Profiles.KUAI_ID,Profiles.DAMING_ID]:
		var script: Script=Profiles.level_script(id);check(script!=null and script.can_instantiate(),"fixed installed profile script "+id)
		var flags: Dictionary=Profiles.install_flags(id);check(flags.ok,"installed profile flags "+id)
	var unsupported=[{"mode":"campaign","level_id":"level9","waves":0},{"mode":"campaign","level_id":"level5","waves":30},{"mode":"scenario","level_id":"level8","waves":0}]
	for context in unsupported:check(not Profiles.select_context(context,trusted).ok,"unsupported context still rejected "+str(context))
	var untrusted: Dictionary=trusted.duplicate(true);untrusted.save_eligible=false
	check(not GaoFactory.prepare_runtime(untrusted).ok and not DamingFactory.prepare_runtime(untrusted).ok,"untrusted installation refuses both factories")
	for index in [4,7]:await _case(index)
	_art_finish()
