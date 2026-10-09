extends "res://tools/art_character_direction4_qa.gd"
## Actual held barrier, full core preparation/mount/activation and fresh capture.
## Initial-state integration only; no disk or independent-process continuation.
var trusted: Dictionary
var Core: Script
var Profiles: Script
var Codec: Script
var held := false
var rejected := ""
var held_physics := -1

func _held(_clock: Dictionary) -> void:
	held = true;held_physics=Engine.get_physics_frames()
func _rejected(code: String) -> void: rejected = code
func _capture_boundary(b, label: String) -> bool:
	held=false; rejected=""
	b._save_barrier.capture_ready.connect(_held, CONNECT_ONE_SHOT)
	b._save_barrier.capture_rejected.connect(_rejected, CONNECT_ONE_SHOT)
	var requested: Dictionary=b._save_barrier.request_capture()
	check(requested.ok,label+" actual barrier request")
	if not requested.ok: print(requested);return false
	for frame in range(180):
		await process_frame
		if held or not rejected.is_empty():break
	var ok: bool=held and rejected.is_empty() and b._save_barrier.health().ok
	check(ok,label+" real HELD barrier and stable clock")
	if not ok:print("BARRIER ",rejected)
	return ok

func _case(index: int, ending_fixture := false) -> void:
	var label: String="level"+str(index+1)+(" actual end button" if ending_fixture else " initial world")
	var factory: Script=load("res://scripts/run_level5_world_factory.gd" if index==4 else "res://scripts/run_level8_world_factory.gd")
	var pack: Dictionary=factory.prepare_runtime(trusted)
	check(pack.ok,label+" exact original private runtime")
	if not pack.ok:print(pack);return
	var context: Dictionary={"mode":"campaign","level_id":"level"+str(index+1),"waves":0}
	var b=await _start("",index)
	for frame in range(4):await physics_frame
	await process_frame
	if ending_fixture:
		if not await _end_fixture(b):paused=false;await _dispose(b);return
	var old_level=b.level
	var old_button=b.level.end_button if index==4 else null
	b._official_context=context.duplicate(true)
	b._save_barrier.configure(b,b._run_clock,context)
	if not await _capture_boundary(b,label):paused=false;await _dispose(b);return
	var old_core=Core.new(trusted,pack.runtime,{},null,context)
	var source_capture_before := Time.get_ticks_msec()
	var source_stage_started: int=b.mission._stage_started_ms
	var original: Dictionary=old_core.capture(b)
	var source_capture_after := Time.get_ticks_msec()
	_ui_diagnostic(b,label+" source")
	check(original.ok,label+" entire original world captured")
	if not original.ok:print("CAPTURE ",original);old_core.dispose();paused=false;await _dispose(b);return
	if ending_fixture:_end_negative(original.record,pack.runtime,context,label)
	var root_node: Dictionary=Codec.new().encode(old_core._visuals(b)._read_node(b))
	check(root_node.ok,label+" original root activation captured")
	var core=Core.new(trusted,pack.runtime,{},null,context)
	var prepare_before := Time.get_ticks_msec()
	var prepared: Dictionary=core.prepare(original.record)
	var prepare_after := Time.get_ticks_msec()
	check(prepared.ok,label+" new entire world prepared without callbacks")
	if not prepared.ok:print("PREPARE ",prepared);original.identity.dispose();old_core.dispose();core.dispose();paused=false;await _dispose(b);return
	check(not prepared.mounted and not prepared.activated and not prepared.battle.is_inside_tree(),label+" entire prepared world detached and inert")
	var saved_units: Array=original.record.sections.units.root_order
	check(prepared.battle.units_root.get_child_count()==saved_units.size(),label+" complete new root actor membership")
	original.identity.dispose();old_core.dispose()
	b.queue_free();await process_frame
	var mount_before := Time.get_ticks_msec()
	var mounted: Dictionary=core.mount_disabled(root)
	var mount_after := Time.get_ticks_msec()
	var mounted_input_stamps: Dictionary={}
	if mounted.ok:
		for field: String in ["_last_group_time","_press_ms","_last_tap_ms"]:mounted_input_stamps[field]=prepared.battle.get(field)
	check(mounted.ok,label+" new world mounted while paused")
	if not mounted.ok:print("MOUNT ",mounted);core.dispose();paused=false;return
	# Same trusted host context/lease installation as Session.stage_mount.
	prepared.battle._official_context=context.duplicate(true)
	prepared.battle._steam_run_id=0
	current_scene=prepared.battle
	var layout: Dictionary={"ok":false}
	for frame in range(120):
		layout=core.finish_presentation_layout()
		if layout.ok or layout.get("code","")!="PRESENTATION_LAYOUT_PENDING":break
		await process_frame
	check(layout.ok,label+" actual engine presentation layout finished")
	if not layout.ok:print(layout);core.dispose();paused=false;return
	var decoded_node: Dictionary=Codec.new().decode(root_node.value)
	check(decoded_node.ok,label+" root node follows actual Session decode contract")
	if not decoded_node.ok:print(decoded_node);core.dispose();paused=false;return
	_scene_mount_diagnostic(core,label)
	_static_flag_negative(core,label)
	_ui_diagnostic(prepared.battle,label+" restored")
	var activation_physics := Engine.get_physics_frames()
	var activated: Dictionary=core.activate_components(decoded_node.value)
	check(activated.ok and paused,label+" final components activate under pause")
	if not activated.ok:print("ACTIVATE ",activated);core.dispose();paused=false;return
	var fresh=activated.battle
	if not await _capture_boundary(fresh,label+" restored"):
		core.dispose();paused=false;return
	var fresh_capture_before := Time.get_ticks_msec()
	var fresh_capture_process := Engine.get_process_frames()
	var fresh_stage_started: int=fresh.mission._stage_started_ms
	var again: Dictionary=core.capture(fresh,prepared.identity)
	var fresh_capture_after := Time.get_ticks_msec()
	check(again.ok,label+" activated new world captured under real barrier")
	if not again.ok:print("RECAPTURE ",again)
	var compared: Array=[];var differing: Array=[];var timing: Dictionary={};var root_exact := false
	if again.ok:
		var source_mission: Dictionary=Codec.new().decode(original.record.sections.mission.payload).value
		var fresh_mission: Dictionary=Codec.new().decode(again.record.sections.mission.payload).value
		var saved_age: int=source_mission.values.stage_age_ms
		var fresh_age: int=fresh_mission.values.stage_age_ms
		var source_age_ok: bool=saved_age>=source_capture_before-source_stage_started and saved_age<=source_capture_after-source_stage_started
		var rebase_ok: bool=fresh_stage_started>=prepare_before-saved_age and fresh_stage_started<=prepare_after-saved_age
		var fresh_age_ok: bool=fresh_age>=fresh_capture_before-fresh_stage_started and fresh_age<=fresh_capture_after-fresh_stage_started
		check(source_age_ok and rebase_ok and fresh_age_ok,label+" complete Mission wall-age interval/rebase verified")
		timing={"source_capture_before":source_capture_before,"source_capture_after":source_capture_after,"source_stage_started":source_stage_started,"saved_stage_age":saved_age,"prepare_before":prepare_before,"prepare_after":prepare_after,"fresh_stage_started":fresh_stage_started,"fresh_capture_before":fresh_capture_before,"fresh_capture_after":fresh_capture_after,"fresh_stage_age":fresh_age,"mission_age_qualified":source_age_ok and rebase_ok and fresh_age_ok,"mount_before":mount_before,"mount_after":mount_after,"activation_physics":activation_physics,"held_physics":held_physics}
		# Only the measured wall-age is rebased. Every other Mission value,
		# actor/token/action/order/state remains exact and both native records stay.
		source_mission.values.erase("stage_age_ms");fresh_mission.values.erase("stage_age_ms")
		for section: String in original.record.sections:
			if section=="root":continue
			compared.append(section)
			var equal: bool=source_mission==fresh_mission if section=="mission" else original.record.sections[section]==again.record.sections[section]
			if not equal:differing.append(section)
		check(differing.is_empty(),label+" every non-root complete section with separately audited Mission clock")
		if not differing.is_empty():print("DIFFERING_SECTIONS ",differing)
		var old_root: Dictionary=Codec.new().decode(original.record.sections.root.payload).value
		var new_root: Dictionary=Codec.new().decode(again.record.sections.root.payload).value
		var clock_ok: bool=old_root.simulation.schema==new_root.simulation.schema and old_root.simulation.physics_hz==new_root.simulation.physics_hz and old_root.simulation.next_tick==new_root.simulation.next_tick
		clock_ok=clock_ok and int(new_root.simulation.cache_frame)==int(old_root.simulation.cache_frame)+held_physics-activation_physics
		clock_ok=clock_ok and int(new_root.clocks.physics)==int(new_root.simulation.cache_frame) and new_root.clocks.process==fresh_capture_process and new_root.clocks.msec>=fresh_capture_before and new_root.clocks.msec<=fresh_capture_after
		var input_ages: Dictionary={}
		for field: String in ["_last_group_time","_press_ms","_last_tap_ms"]:
			var age: int=old_root.clocks.msec-old_root.clock_values[field]
			var stamp: int=mounted_input_stamps[field]
			var bound: bool=stamp>=mount_before-age and stamp<=mount_after-age
			# Both real barriers intentionally clear transient pointer/double-tap stamps.
			bound=bound and old_root.clock_values[field]==0 and new_root.clock_values[field]==0
			input_ages[field]={"saved_age":age,"new_stamp":stamp,"bounded_at_mount":bound}
			clock_ok=clock_ok and bound
		for field: String in ["_res_block_frame","_eco_lane_cache_bucket"]:clock_ok=clock_ok and old_root.clock_values[field]==new_root.clock_values[field]
		check(clock_ok,label+" full Root simulation/cache/input clock contract verified")
		timing["root_clock_qualified"]=clock_ok;timing["input_ages"]=input_ages
		for field: String in ["simulation","clocks","clock_values"]:old_root.erase(field);new_root.erase(field)
		root_exact=old_root==new_root
		check(root_exact,label+" all non-clock Root values/references/grids/economy exact")
		if not root_exact:
			for field: String in old_root:
				if old_root[field]!=new_root.get(field):print("ROOT_FIELD_DIFF ",field)
	var f=FileAccess.open(art_output.path_join("level"+str(index+1)+"_world.json"),FileAccess.WRITE)
	check(f!=null,label+" complete before/after native evidence retained")
	if f!=null:f.store_string(JSON.stringify({"original":original.record,"restored":again.get("record",{}),"compared":compared,"differing":differing,"timing_audit":timing,"root_nonclock_exact":root_exact})+"\n");f.close()
	art_runtime.append({"case":label,"full_core_prepared":prepared.ok,"mounted":mounted.ok,"activated":activated.ok,"whole_capture":again.ok,"exact_nonroot_sections":again.ok and differing.is_empty(),"root_nonclock_exact":root_exact,"timing_audit":timing,"full_world_qualified":false,"independent_process_qualified":false,"scope":"Actual initial world HELD capture, detached preparation, paused mount/final activation. All non-clock whole sections exact and Mission/Root temporal fields bounded against actual source/prepare/mount/activation/capture timestamps. Complete unmodified before/after evidence retained. No independent process or natural ending."})
	if ending_fixture and again.ok:
		var button: Button=fresh.level.end_button
		check(fresh.level!=old_level and button!=old_button and fresh.mission.battle==fresh and button.get_parent()==fresh.mission._buttons,label+" final Level/control/Mission belong to new world")
		var links: Array=button.get_signal_connection_list("pressed")
		check(links.size()==1 and links[0].callable.get_object()==fresh.mission and links[0].callable.get_method()=="_activate_level_button",label+" actual pressed callback belongs only to new Mission")
		var released: Dictionary=fresh._save_barrier.release_capture()
		check(released.ok and paused,label+" native UI gate released without starting simulation")
		if released.ok:
			button.pressed.emit()
			check(fresh.phase==fresh.Phase.END and fresh.mission.has_event("gao_basic_victory"),label+" original restored button invokes final new Level finish")
			var event_count: int=fresh.mission.events.size()
			button.pressed.emit()
			check(fresh.phase==fresh.Phase.END and fresh.mission.events.size()==event_count,label+" second press does not replay completion event")
	core.dispose();paused=false;await process_frame

func _scene_mount_diagnostic(core, label: String) -> void:
	var adapter=core._scenery_adapter
	if adapter==null:return
	var captured: Dictionary=adapter.capture(core._battle.map)
	var expected: Dictionary=adapter._campaign_record
	var rows: Array=[]
	if captured.ok and captured.value!=expected:
		for field: String in expected:
			if expected[field]==captured.value.get(field):continue
			print("MOUNT_SCENE_FIELD_DIFF ",label," ",field)
			if field=="nodes" and expected.nodes.size()==captured.value.nodes.size():
				for index in range(expected.nodes.size()):
					var before: Dictionary=Codec.new().decode(expected.nodes[index]).value
					var after: Dictionary=Codec.new().decode(captured.value.nodes[index]).value
					if before==after:continue
					rows.append({"node":index,"kind":before.kind,"expected":before,"mounted":after})
					print("MOUNT_SCENE_NODE_DIFF ",index," ",before.kind)
					for lane: String in before:
						if before[lane]!=after.get(lane):print("MOUNT_SCENE_VALUE ",lane," ",before[lane]," -> ",after.get(lane))
	var f=FileAccess.open(art_output.path_join(label.replace(" ","_")+"_mount_scenery.json"),FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify({"original":expected,"mounted":captured,"changed_nodes":rows})+"\n");f.close()

func _ui_diagnostic(b, label: String) -> void:
	var rows: Array=[]
	for key: String in ["_title","_core","_story","_objective","_status"]:
		var node=b.mission.get(key)
		rows.append({"field":key,"size":str(node.size),"minimum_size":str(node.get_minimum_size()),"combined_minimum_size":str(node.get_combined_minimum_size()),"parent_size":str(node.get_parent().size),"font_size":node.get_theme_font_size("font_size"),"visible_in_tree":node.is_visible_in_tree(),"text_length":node.text.length()})
	var f=FileAccess.open(art_output.path_join(label.replace(" ","_")+"_ui.json"),FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(rows)+"\n");f.close()

func _static_flag_negative(core, label: String) -> void:
	var adapter=core._scenery_adapter
	if adapter==null or not adapter._native_campaign():return
	var index: int=adapter._campaign_record.ownership.dock_parts[0]
	var node: Node2D=adapter._campaign_order[index]
	var old_color: Color=node.modulate
	var process_flags: Array=adapter._campaign_record.ownership.dock_parts.map(func(i):return adapter._campaign_order[i].is_processing())
	node.modulate=Color(0.2,0.3,0.4,1.0)
	var rejected_flags: Dictionary=adapter._restore_native_static_enter_flags()
	check(not rejected_flags.ok and adapter._campaign_record.ownership.dock_parts.map(func(i):return adapter._campaign_order[i].is_processing())==process_flags,label+" mutated static dock color rejects before any flag write")
	node.modulate=old_color
	var old_duration: float=float(node.get("duration"))
	node.set("duration",1.0)
	rejected_flags=adapter._restore_native_static_enter_flags()
	check(not rejected_flags.ok and adapter._campaign_record.ownership.dock_parts.map(func(i):return adapter._campaign_order[i].is_processing())==process_flags,label+" timed event cannot use static dock entry reconciliation")
	node.set("duration",old_duration)

func _end_fixture(b) -> bool:
	# Explicit component ending-state fixture. Native callbacks and ordinary
	# damage create a real Mission-owned control; this is NOT a natural victory.
	for index in range(3):b.level._send_wave(b,index)
	b.level.flagship.resolve_story("subdued")
	for groups: Array in [b.level.water_groups,b.level.land_groups]:
		for group: Array in groups:
			for unit in group:
				if is_instance_valid(unit) and unit!=b.level.flagship and unit.hp>0.0:unit.take_damage(100000.0,null,true)
	b.level.process(b,5.0)
	await process_frame
	var ok: bool=b.phase==b.Phase.FIGHT and b.level._core_threats_clear() and b.level.core_ready and is_instance_valid(b.level.end_button) and b.level.end_button.get_parent()==b.mission._buttons
	check(ok,"Gao explicit native callbacks/death fixture creates actual Mission-owned end button")
	return ok

func _end_negative(record: Dictionary, runtime: Dictionary, context: Dictionary, label: String) -> void:
	var raw: Dictionary=Codec.new().decode(record.sections.presentation.payload).value
	var found := false
	for row: Dictionary in raw.buttons:
		if row.descriptor.kind=="level" and row.descriptor.button_id=="gao_end":
			row.descriptor.button_id="foreign_end";found=true
	check(found,label+" native source includes real fixed end descriptor")
	if not found:return
	var bad: Dictionary=record.duplicate(true);bad.sections.presentation.payload=Codec.new().encode(raw).value
	var rejected_core=Core.new(trusted,runtime,{},null,context)
	var rejected_plan: Dictionary=rejected_core.prepare(bad)
	check(not rejected_plan.ok and rejected_core._battle==null and rejected_core._unit_plan.is_empty(),label+" foreign end descriptor rejected and transaction disposed before Units")
	rejected_core.dispose()
	raw=Codec.new().decode(record.sections.presentation.payload).value
	for index in range(raw.buttons.size()-1,-1,-1):
		if raw.buttons[index].descriptor.kind=="level" and raw.buttons[index].descriptor.button_id=="gao_end":raw.buttons.remove_at(index)
	bad=record.duplicate(true);bad.sections.presentation.payload=Codec.new().encode(raw).value
	rejected_core=Core.new(trusted,runtime,{},null,context);rejected_plan=rejected_core.prepare(bad)
	check(not rejected_plan.ok and rejected_core._battle==null and rejected_core._unit_plan.is_empty(),label+" missing Mission-owned end descriptor rejects before Units")
	rejected_core.dispose()

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	Core=load("res://scripts/run_battle_world_core.gd");Profiles=load("res://scripts/run_official_restore_profile.gd");Codec=load("res://scripts/run_state_value_codec.gd")
	art_output=OS.get_environment("ART_QA_OUT");art_character="campaign_core_v24g";art_visual=false
	trusted=_art_identity()
	if not trusted.get("save_eligible",false):_art_finish();return
	await _case(4)
	await _case(7)
	await _case(4,true)
	_art_finish()
