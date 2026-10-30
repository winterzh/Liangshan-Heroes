extends "base.gd"
## One actual chapter; dense formation, removed-overlay comparison and stopped
## simulation are explicit display fixtures, not ordinary keyboard/mouse play.
const Captions=preload("res://scripts/campaign_cart_captions.gd")
var out := ""
var screenshots: Array=[]
var layouts: Array=[]
var people: Array=[]
func _frames(n := 2) -> void:
	for i in range(n): await get_tree().process_frame

func _snapshot(name: String) -> Image:
	await _frames()
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	check(image != null and not image.is_empty() and image.save_png(path) == OK, "original viewport " + name)
	screenshots.append({"path": name + ".png", "sha256": FileAccess.get_sha256(path)})
	return image

func _start_once():
	var campaign = root.get_node("Campaign")
	campaign.current = 0
	for key in ["skirmish", "skirmish_ai", "arena", "scenario", "custom_defense", "scale_on", "ai_friendly"]: campaign.set(key, false)
	root.get_node("Settings").auto_micro_level = 0
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	# Production new-game API consumes the actual provider result resolved above.
	# This avoids a duplicate full source scan in Battle._ready; no provider,
	# gameplay, art, RNG or callback is stubbed and no identity is fabricated.
	var configured: Dictionary = b.configure_new_gameplay_rng(trusted, 5088120)
	check(configured.ok and b._gameplay_content_identity == trusted, "production new-game binding uses this process's actual provider identity")
	root.add_child(b); current_scene = b
	await get_tree().process_frame
	b.hud._intro_root.hide(); b._on_intro_done(); b._on_start_battle()
	check(b.phase == b.Phase.FIGHT, "actual new-game entry reaches fight")
	b.set_process(false); b.set_physics_process(false); b.fog = false
	b.camera.set_process(false); b.camera.set_physics_process(false); b.camera.position_smoothing_enabled = false
	for unit in b.units: unit.set_physics_process(false)
	b.level._ensure_bai(b, false).set_physics_process(false)
	b.level.st = b.level.CARRY; b.level.drug_done = true
	b.level._begin_cargo_choice(b); b.level._sync_controls(b); b.mission.tick(0)
	b.process_mode = Node.PROCESS_MODE_DISABLED
	return b

func _arrive(b, actor, prefix: String) -> String:
	b.select_single(actor, false)
	var id: String = b.level._selected_transport_action(b)
	check(id.begins_with(prefix), "original next action " + actor.key + prefix)
	if id.is_empty(): return ""
	actor.order_stop(); actor.position = b.map.cell_to_world(b.mission.actions[id].cell)
	if prefix == "force_load_":
		var index: int = actor.get_meta("pushing_empty_tribute", -1)
		b.level.jujube_carts[index].position = b.level._empty_cart_anchor(actor)
	check(b.mission.request_action(id), "original mission accepts " + id)
	b.mission.tick(1.0)
	check(b.mission.actions[id].done, "original callback completes " + id)
	return id



func _camera(b,center: Vector2,zoom: float,offset:=Vector2.ZERO) -> void:
	b.camera.zoom=Vector2.ONE*zoom
	b.camera.position=b.to_screen(center)+Vector2(0,-25)+offset
	b.camera.force_update_scroll()

func _formation(b,center: Vector2,zoom: float) -> void:
	for i in range(people.size()):
		var unit=people[i]
		unit.position=center+Vector2((i%3-1)*28,(int(i/3.0)-1)*28)
		unit.animation_direction="se";unit.face_left=false;unit._move_blend=0;unit._anim_t=0
		b.map.sync_render_position(unit);unit.z_index=clampi(1+int(b.map.project(unit.position).y),1,3400);unit.queue_redraw()
	_camera(b,center,zoom)

func _audit(b,overlay,label: String,wanted: Array,cart_count:=0) -> Array:
	await _frames(4);RenderingServer.force_draw(false)
	var rows: Array=overlay.last_layout.duplicate(true)
	var person_rows: Array=rows.filter(func(row):return row.kind=="person")
	var actual_ids: Array=person_rows.map(func(row):return row.entity_id);actual_ids.sort()
	var wanted_ids: Array=wanted.map(func(unit):return unit.entity_id);wanted_ids.sort()
	check(actual_ids==wanted_ids,label+": actual rendered identities include every wanted live person")
	check(rows.filter(func(row):return row.kind=="cart").size()==cart_count,label+": delivered-cart detail ownership remains separate")
	var obstacles: Array=overlay._obstacles(b);var occupied: Array=[]
	var area: Rect2=overlay.get_viewport_rect().grow(-8)
	for row: Dictionary in rows:
		var rect: Rect2=row.rect
		check(rect.size==Captions.CARD_SIZE and area.encloses(rect),label+": readable fixed screen card stays inside viewport "+str(row.entity_id))
		check(overlay._free(rect,obstacles) and overlay._free(rect,occupied),label+": no person/body/HUD/card overlap "+str(row.entity_id))
		occupied.append(rect.grow(Captions.GAP))
		check(not row.has("unit") and not row.text.is_empty(),label+": rendered record keeps identity/value data only")
	var layout_started: int=Time.get_ticks_usec()
	var repeated: Array=overlay.compute_layout()
	var component_us: int=Time.get_ticks_usec()-layout_started
	check(rows==repeated,label+": deterministic priority/entity order")
	check(overlay._styles.size()<=4,label+": border styles reused rather than allocated every frame")
	layouts.append({"label":label,"viewport":[root.size.x,root.size.y],"component_probe_us":component_us,"rows":rows})
	return rows

func _ledger(b) -> Array:
	return [b.level.delivered,b.level.cargo.duplicate(),b.level.cargo_ready.duplicate(),b.level.empty_cargo.duplicate(),
		[b._run_clock._next_tick,b._run_clock._tick,b._run_clock._cache_frame,b._run_clock._fault],
		people.map(func(unit):return [unit.entity_id,unit.position,unit.hp,unit._order_serial])]

func _run() -> void:
	out=OS.get_environment("HG_OUTPUT_ROOT");root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true)
	if not identity(true):report();return
	var b = await _start_once()
	var overlay=b.hud.get_node(Captions.NODE_NAME)
	people=b.units.filter(func(unit):return Captions.person_owned(unit))
	people.sort_custom(func(left,right):return left.entity_id<right.entity_id)
	var bai=b.find_unit("bai_sheng");var yang=b.find_unit("yang_zhi")
	check(people.size()>=9 and people.has(bai) and people.has(yang),"actual seven Stars, original non-hero Bai and hostile Yang have person labels")
	check(not bai.is_hero and Captions.person_owned(bai),"Bai gains name readability without changing his non-hero gameplay role")
	check(b.units.any(func(unit):return not Captions.person_owned(unit) and not unit.is_hero and unit.key!="bai_sheng"),"ordinary convoy units retain their original label path")
	b._set_selection([])
	var center: Vector2=b.map.cell_to_world(Vector2i(12,12))
	_formation(b,center,2.8)
	# Explicit old-world-label fallback on this same source; not old build execution.
	overlay.queue_free();await _frames(2)
	for unit in people:unit.queue_redraw()
	check(people.all(func(unit):return not Captions.person_owned(unit)),"missing overlay retains original world-label fallback")
	await _snapshot("world_fallback_fixture")
	Captions.ensure(b);overlay=b.hud.get_node(Captions.NODE_NAME)
	check(people.all(func(unit):return Captions.world_labels_owned(unit)),"ensure invalidates cached world labels before owning their new cards")
	var overlay_id: int=overlay.get_instance_id();Captions.ensure(b)
	check(overlay_id==b.hud.get_node(Captions.NODE_NAME).get_instance_id(),"same gameplay overlay is reused")
	await _audit(b,overlay,"overlay_activation",people);await _snapshot("overlay_activation")
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/catalog.json"))
	for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size=size;root.content_scale_size=size;await _frames(5)
		for locale: String in ["zh_CN","zh_TW","en","ja"]:
			Localize.set_language(locale,false);_formation(b,center,2.8)
			var label: String="dense_"+locale+"_"+str(size.x)
			var rows: Array=await _audit(b,overlay,label,people)
			for unit in people:
				var matching: Array=rows.filter(func(row):return row.entity_id==unit.entity_id)
				check(matching.size()==1 and matching[0].text==(unit.display_name if locale=="zh_CN" else catalog[unit.display_name][locale]),label+": exact authored locale name "+unit.key)
			await _snapshot(label)
	Localize.set_language("zh_CN",false)
	root.size=Vector2i(1600,900);root.content_scale_size=root.size;await _frames(5)
	_formation(b,center,1.0);await _audit(b,overlay,"wide_zoom_out",people);await _snapshot("wide_zoom_out")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;await _frames(5)
	_formation(b,center,1.0);await _audit(b,overlay,"normal_zoom_out",people);await _snapshot("normal_zoom_out")
	_formation(b,center,.65);await _audit(b,overlay,"far_zoom_out",people);await _snapshot("far_zoom_out")
	_formation(b,center,1.0)
	var wu=b.find_unit("wu_yong");var chao=b.find_unit("chao_gai")
	chao.take_damage(1.0,null,false,true);b.select_single(wu,false)
	var rows: Array=await _audit(b,overlay,"selected_and_hurt",people)
	check(rows[0].entity_id==wu.entity_id and rows[0].selected and b.hud._sel_ref==[wu],"selected hero has layout priority and original bottom panel")
	check(rows.filter(func(row):return row.entity_id==chao.entity_id)[0].priority==1,"real damage raises unselected person's layout priority")
	await _snapshot("selected_and_hurt")
	b._set_inspect(yang)
	rows=await _audit(b,overlay,"hostile_inspection",people)
	check(rows[0].entity_id==yang.entity_id and rows[0].inspected and b.hud._sel_ref==[yang],"original read-only hostile inspection keeps identity/panel and priority")
	var hp_image: Image=await _snapshot("hostile_inspection")
	var friendly_row: Dictionary=rows.filter(func(row):return row.entity_id==wu.entity_id)[0]
	var hostile_row: Dictionary=rows.filter(func(row):return row.entity_id==yang.entity_id)[0]
	var friendly_point:=Vector2i(friendly_row.rect.position+Vector2(20,26))
	var hostile_point:=Vector2i(hostile_row.rect.position+Vector2(20,26))
	var green: Color=hp_image.get_pixelv(friendly_point);var orange: Color=hp_image.get_pixelv(hostile_point)
	check(green.g>green.r+.1 and orange.r>orange.g+.1,"actual pixels preserve friendly green and hostile orange health bars")
	Settings.show_healthbars=false
	await _audit(b,overlay,"healthbars_disabled",people)
	var no_hp: Image=await _snapshot("healthbars_disabled")
	var without_green: Color=no_hp.get_pixelv(friendly_point)
	check(not without_green.g>without_green.r+.1,"existing healthbar setting removes actual floating health strip")
	Settings.show_healthbars=true
	var before:=_ledger(b);get_tree().paused=true
	var start_rows: Array=await _audit(b,overlay,"paused_before_camera",people)
	_camera(b,center,1.5,Vector2(30,-12))
	var moved_rows: Array=await _audit(b,overlay,"paused_camera",people)
	check(start_rows[0].anchor!=moved_rows[0].anchor and start_rows[0].rect.size==moved_rows[0].rect.size,"paused pan/zoom follows real anchor without resizing text/card")
	check(before==_ledger(b),"display/camera work changes no positions orders health cargo or gameplay clock")
	await _snapshot("paused_camera");get_tree().paused=false
	b._set_inspect(null)
	chao._flinch=Vector2.ZERO;chao._shi_en_hurt_t=0.0
	_arrive(b,chao,"force_take_");_arrive(b,chao,"force_load_")
	_formation(b,center,2.8)
	await _audit(b,overlay,"loaded_cart_clearance",people);await _snapshot("loaded_cart_clearance")
	_arrive(b,chao,"force_deliver_")
	var cart=b.level.bundles[0]
	var parked_center: Vector2=cart.position-Vector2(24,24)
	_formation(b,parked_center,2.8);b.select_single(cart,false)
	rows=await _audit(b,overlay,"people_and_cart",people,1)
	check(rows[0].entity_id==cart.entity_id and b.hud._sel_ref==[cart],"requested cart shares priority/layout without losing original information panel")
	await _snapshot("people_and_cart")
	b._set_selection([]);await _audit(b,overlay,"healthy_cart_quiet",people,0)
	check(Captions.owns(cart) and not Captions.wants_info(cart),"healthy unselected delivered cart remains quiet while people stay named")
	check(yang.resolve_story("unconscious"),"original story resolution API accepts explicit status fixture")
	var active: Array=people.filter(func(unit):return unit!=yang)
	check(not Captions.person_owned(yang) and not Captions.world_labels_owned(yang) and not yang.story_label().is_empty(),"resolved person retains original world name/status path")
	await _audit(b,overlay,"resolved_original_status",active);await _snapshot("resolved_original_status")
	var old_map=wu.map;wu.map=null
	check(not Captions.person_owned(wu),"unbound map cannot claim world labels")
	wu.map=old_map
	b.hud._pause_root.show();await _frames(4)
	check(overlay.last_layout.is_empty(),"full-screen pause menu owns label surface without overlapping fallback")
	b.hud._pause_root.hide();await _frames(4)
	_camera(b,parked_center,2.8,Vector2(8000,8000));await _frames(4)
	check(overlay.last_layout.is_empty(),"offscreen people do not leave stale floating labels")
	_camera(b,parked_center,2.8)
	var weak_overlay: WeakRef=weakref(overlay)
	await _dispose(b)
	check(not is_instance_valid(weak_overlay.get_ref()),"scene disposal releases shared overlay and style cache")
	report({"scope":"current short-chapter live person label layout and shared cart detail coexistence", "screenshots":screenshots,"layouts":layouts,
		"world_fallback_is_explicit_same_source_fixture":true,"dense_formation_and_stopped_simulation_are_fixtures":true,
		"original_selection_and_story_APIs_used":true,"full_playthrough":false,"full_regression_run":false,"performance_acceptance":false})
