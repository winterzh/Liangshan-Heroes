extends "res://tools/huangnigang_short_test.gd"
var group_observations: Array=[]
func _group_fixture() -> void:
	var b=await _start("",0)
	b.set_process(false); b.set_physics_process(false);b.hud.set_process(false);b.camera.set_process(false)
	for u in b.units: u.set_physics_process(false)
	var l=b.level
	l.st=l.CARRY;l._begin_cargo_choice(b);l._sync_controls(b)
	var empty=b.find_unit(l.Transport.owner(0))
	var loaded=b.find_unit(l.Transport.owner(1))
	var free_actor=b.find_unit(l.Transport.owner(2))
	# Explicit transport-state fixture only; the separate live route performs all actions.
	l.empty_cargo[0]=empty;empty.set_meta("pushing_empty_tribute",0)
	l.cargo[1]=loaded;l.cargo_ready[1]=true;loaded.set_meta("carrying_tribute",1)
	l._add_load_action(b,0,empty);l._add_force_deliver(b,1,loaded)
	var buttons: Dictionary={}
	for child in b.mission._buttons.get_children():
		var descriptor: Dictionary=child.get_meta("campaign_presentation_v1",{})
		if descriptor.get("kind")=="level": buttons[descriptor.button_id]=child
	check(buttons.has("hg_empty_carts") and buttons.has("hg_loaded_carts"),"both groups have actual registered buttons")
	var serials: Array=l.actors.map(func(u):return u._order_serial)
	var positions: Array=l.actors.map(func(u):return u.position)
	buttons.hg_empty_carts.pressed.emit()
	check(b.selection==[empty] and l._selected_transport_action(b)=="force_load_0_0","empty-cart selection locates loading rather than another pickup")
	buttons.hg_loaded_carts.pressed.emit()
	check(b.selection==[loaded] and l._selected_transport_action(b)=="force_deliver_1_0","loaded-cart selection locates delivery")
	check(serials==l.actors.map(func(u):return u._order_serial) and positions==l.actors.map(func(u):return u.position) and l.delivered==0,"group buttons do not dispatch, move, load or deliver")
	loaded.hp=0
	buttons.hg_loaded_carts.pressed.emit()
	check(l._transport_group(b,true).is_empty() and b.selection==[loaded],"empty group leaves selection untouched and excludes a dead actor")
	loaded.hp=loaded.max_hp
	loaded.set_meta("carrying_tribute",3)
	check(l._transport_group(b,true).is_empty(),"mismatched actor metadata cannot enter the loaded group")
	loaded.set_meta("carrying_tribute",1)
	var point: Vector2i=b.map.world_to_cell(free_actor.position)
	for index in [5,6]: b.mission.actions["force_take_%d_0"%index].actors=[free_actor.key]
	b.mission.actions.force_take_5_0.cell=point
	b.mission.actions.force_take_6_0.cell=point+Vector2i(1,0)
	b.mission.actions.force_take_2_0.cell=point+Vector2i(10,0)
	b.select_single(free_actor,false)
	check(l._selected_transport_action(b)=="force_take_5_0","relay navigator chooses nearest eligible pickup, not dictionary order")
	b.mission.actions.force_take_5_0.blocked_reason="fixture blockage"
	check(l._selected_transport_action(b)=="force_take_6_0","blocked task is skipped")
	b.mission.actions.force_take_6_0.done=true
	check(l._selected_transport_action(b)=="force_take_2_0","completed task is skipped")
	var presentation=load("res://scripts/run_campaign_presentation_state.gd").new()
	check(["hg_empty_carts","hg_loaded_carts"].all(func(key):return presentation._descriptor_valid(buttons[key].get_meta("campaign_presentation_v1"),{"level_id":"level1"})),"both IDs use the existing fixed presentation callback contract")
	for language in ["zh_CN","zh_TW","en","ja"]:
		root.get_node("Localize").set_language(language,false)
		check(not l.unit_tactical_hint(b,empty).is_empty() and not l.unit_tactical_hint(b,loaded).is_empty(),language+" has empty/loaded state descriptions")
		group_observations.append({"language":language,"empty":l.unit_tactical_hint(b,empty),"loaded":l.unit_tactical_hint(b,loaded),"buttons":[buttons.hg_empty_carts.text,buttons.hg_loaded_carts.text]})
		if language in ["zh_CN","en"]:
			root.size=Vector2i(1280,720) if language=="zh_CN" else Vector2i(960,540)
			root.content_scale_size=root.size
			buttons.hg_loaded_carts.pressed.emit()
			b.hud.set_top(l.top_status(b))
			b.mission._set_expanded(true);b.hud.update_selection_panel(b.selection);b.hud._refresh_panel()
			for i in range(8):
				b.hud._refresh_hero_bar();b.hud._layout_desktop_hero();b.hud._layout_info_panel();b.mission.tick(0)
				b.mission._detail_scroll.scroll_vertical=int(buttons.hg_empty_carts.position.y+b.mission._buttons.position.y)
				await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(folder+"/"+language+".png")==OK,language+" actual group controls rendered")
	await _dispose(b)
func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1");AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll=false
	folder="res://.godot/campaign-transport-groups"
	DirAccess.make_dir_recursive_absolute(folder)
	await _group_fixture()
	root.get_node("Localize").set_language("zh_CN",false)
	Engine.time_scale=4
	await _live("wine")
	Engine.time_scale=1
	var passed: bool=failures.is_empty() and cases.size()==1 and cases[0].get("result",{}).get("core_cleared",false)
	FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"failures":failures,"fixture_observations":group_observations,"live_cases":cases,"scope":"explicit group/navigation fixtures and current seven-cart wine route; not full restore, human fun or device/performance acceptance"},"\t"))
	quit(0 if passed else 1)
