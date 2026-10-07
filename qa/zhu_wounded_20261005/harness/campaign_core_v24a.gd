extends "res://tools/art_character_direction4_qa.gd"
## Actual held barrier, full core preparation/mount/activation and fresh capture.
## Initial-state integration only; no disk or independent-process continuation.
var trusted: Dictionary
var Core: Script
var Profiles: Script
var Codec: Script
var held := false
var rejected := ""

func _held(_clock: Dictionary) -> void: held = true
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

func _case(index: int) -> void:
	var label: String="level"+str(index+1)+" initial world"
	var factory: Script=load("res://scripts/run_level5_world_factory.gd" if index==4 else "res://scripts/run_level8_world_factory.gd")
	var pack: Dictionary=factory.prepare_runtime(trusted)
	check(pack.ok,label+" exact original private runtime")
	if not pack.ok:print(pack);return
	var context: Dictionary={"mode":"campaign","level_id":"level"+str(index+1),"waves":0}
	var b=await _start("",index)
	for frame in range(4):await physics_frame
	await process_frame
	b._official_context=context.duplicate(true)
	b._save_barrier.configure(b,b._run_clock,context)
	if not await _capture_boundary(b,label):paused=false;await _dispose(b);return
	var old_core=Core.new(trusted,pack.runtime,{},null,context)
	var original: Dictionary=old_core.capture(b)
	check(original.ok,label+" entire original world captured")
	if not original.ok:print("CAPTURE ",original);old_core.dispose();paused=false;await _dispose(b);return
	var root_node: Dictionary=Codec.new().encode(old_core._visuals(b)._read_node(b))
	check(root_node.ok,label+" original root activation captured")
	var core=Core.new(trusted,pack.runtime,{},null,context)
	var prepared: Dictionary=core.prepare(original.record)
	check(prepared.ok,label+" new entire world prepared without callbacks")
	if not prepared.ok:print("PREPARE ",prepared);original.identity.dispose();old_core.dispose();core.dispose();paused=false;await _dispose(b);return
	check(not prepared.mounted and not prepared.activated and not prepared.battle.is_inside_tree(),label+" entire prepared world detached and inert")
	var saved_units: Array=original.record.sections.units.root_order
	check(prepared.battle.units_root.get_child_count()==saved_units.size(),label+" complete new root actor membership")
	original.identity.dispose();old_core.dispose()
	b.queue_free();await process_frame
	var mounted: Dictionary=core.mount_disabled(root)
	check(mounted.ok,label+" new world mounted while paused")
	if not mounted.ok:print("MOUNT ",mounted);core.dispose();paused=false;return
	current_scene=prepared.battle
	var layout: Dictionary={"ok":false}
	for frame in range(120):
		layout=core.finish_presentation_layout()
		if layout.ok or layout.get("code","")!="PRESENTATION_LAYOUT_PENDING":break
		await process_frame
	check(layout.ok,label+" actual engine presentation layout finished")
	if not layout.ok:print(layout);core.dispose();paused=false;return
	var activated: Dictionary=core.activate_components(root_node.value)
	check(activated.ok and paused,label+" final components activate under pause")
	if not activated.ok:print("ACTIVATE ",activated);core.dispose();paused=false;return
	var fresh=activated.battle
	if not await _capture_boundary(fresh,label+" restored"):
		core.dispose();paused=false;return
	var again: Dictionary=core.capture(fresh,prepared.identity)
	check(again.ok,label+" activated new world captured under real barrier")
	if not again.ok:print("RECAPTURE ",again)
	var compared: Array=[];var differing: Array=[]
	if again.ok:
		# Root stores rebased engine clocks; record those separately. No clock
		# fields are dropped from either complete native evidence document.
		for section: String in original.record.sections:
			if section=="root":continue
			compared.append(section)
			if original.record.sections[section]!=again.record.sections[section]:differing.append(section)
		check(differing.is_empty(),label+" every non-root whole-world section exact")
		if not differing.is_empty():print("DIFFERING_SECTIONS ",differing)
	var f=FileAccess.open(art_output.path_join("level"+str(index+1)+"_world.json"),FileAccess.WRITE)
	check(f!=null,label+" complete before/after native evidence retained")
	if f!=null:f.store_string(JSON.stringify({"original":original.record,"restored":again.get("record",{}),"compared":compared,"differing":differing})+"\n");f.close()
	art_runtime.append({"case":label,"full_core_prepared":prepared.ok,"mounted":mounted.ok,"activated":activated.ok,"whole_capture":again.ok,"exact_nonroot_sections":again.ok and differing.is_empty(),"full_world_qualified":false,"independent_process_qualified":false,"scope":"Actual initial world HELD capture, detached preparation, paused mount/final activation. All non-root sections compared; complete root clock rebasing evidence retained but not yet qualified. No independent process or natural ending."})
	core.dispose();paused=false;await process_frame

func _run() -> void:
	if not _art_profile_guard():quit(2);return
	Core=load("res://scripts/run_battle_world_core.gd");Profiles=load("res://scripts/run_official_restore_profile.gd");Codec=load("res://scripts/run_state_value_codec.gd")
	art_output=OS.get_environment("ART_QA_OUT");art_character="campaign_core_v24a";art_visual=false
	trusted=_art_identity()
	if not trusted.get("save_eligible",false):_art_finish();return
	await _case(4)
	await _case(7)
	_art_finish()
