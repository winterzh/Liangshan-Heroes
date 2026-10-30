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
	check(actual_ids==wanted_ids,label+": actual rendered identities include every wanted current visible person")
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

func _status_audit(b,overlay,label: String,all_people: Array,capacity:=false) -> Array:
	await _frames(4)
	var wanted: Array=all_people
	if capacity:
		wanted=all_people.filter(func(unit):return overlay.last_layout.any(func(row):return row.entity_id==unit.entity_id))
		check(overlay.last_layout.all(func(row):return all_people.any(func(unit):return row.entity_id==unit.entity_id)),label+": no fabricated status/person identity under capacity limit")
	var rows: Array=await _audit(b,overlay,label,wanted)
	for row in rows:
		var actor=all_people.filter(func(unit):return unit.entity_id==row.entity_id)[0]
		check(row.status==actor.story_label() and row.text==Localize.text(actor.display_name),label+": exact current original name and localized story status "+actor.key)
	var resolved: Array=all_people.filter(func(unit):return not unit.story_outcome.is_empty())
	var caches: Array=resolved.map(func(unit):return unit._frame_directional)
	for actor in resolved:
		check(Captions.person_owned(actor) and Captions.world_labels_owned(actor),label+": real resolved person is owned without original duplicate world name/status")
		check(overlay._story_body_rect(actor).has_area(),label+": original authored or fallback story body reserves a real area")
	overlay.compute_layout()
	check(caches==resolved.map(func(unit):return unit._frame_directional),label+": status geometry queries preserve Unit directional rendering cache")
	return rows

func _run() -> void:
	out=OS.get_environment("HG_OUTPUT_ROOT");root.size=Vector2i(1600,900);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true)
	if not identity(true):report();return
	var b=await _start_once();var overlay=b.hud.get_node(Captions.NODE_NAME)
	# Entry-time fixture: use the real finite-party spawner, rather than waiting
	# through the stopped chapter or fabricating replacement units.
	while b.level.convoy.size()<15:b.level._spawn_next_convoy_member(b)
	for actor in b.level.convoy:actor.set_physics_process(false)
	people=b.units.filter(func(unit):return Captions.person_owned(unit))
	var ordinary: Array=[b.level.convoy[1],b.level.convoy[12],b.level.convoy[14],b.level.convoy[2],b.level.convoy[3]]
	check(people.size()==9 and ordinary.size()>=5,"actual seven Stars/Bai/Yang and original ordinary convoy people available")
	if ordinary.size()<5:report();return
	var yang=b.find_unit("yang_zhi");var gong=b.find_unit("gongsun_sheng");var bai=b.find_unit("bai_sheng")
	for pair in [[yang,"unconscious"],[gong,"subdued"],[bai,"captured"],[ordinary[0],"unconscious"],[ordinary[1],"subdued"],[ordinary[2],"captured"]]:
		check(pair[0].resolve_story(pair[1]),"actual original story resolution "+pair[0].key+" "+pair[1])
	for actor in ordinary.slice(0,3):people.append(actor)
	people.sort_custom(func(left,right):return left.entity_id<right.entity_id)
	# Explicit photography fixtures: compact formation, stopped simulation and hidden
	# transient messages. Original bodies, HUD selection and gameplay state are real.
	b.hud.msg_box.hide();b._set_selection([])
	var center: Vector2=b.map.cell_to_world(Vector2i(12,12))
	_formation(b,center,1.6)
	var resolution_state: Array=people.map(func(unit):return [unit.entity_id,unit.story_outcome,unit.hp,unit.passive,unit.faction,unit._order_serial])
	var story_routes: Array=[]
	for actor in people:
		if actor.story_outcome.is_empty():continue
		var previous_directional: bool=actor._frame_directional
		var frames: Array=actor._story_animation_frames()
		story_routes.append({"entity_id":actor.entity_id,"key":actor.key,"outcome":actor.story_outcome,"authored_frame_count":frames.size(),"fallback_tilt_or_compression":frames.is_empty()})
		actor._frame_directional=previous_directional
	overlay.queue_free();await _frames(2)
	for actor in people:actor.queue_redraw()
	check(people.all(func(unit):return not Captions.person_owned(unit)),"missing overlay retains original world names/status fallback")
	await _snapshot("world_status_fallback_fixture")
	Captions.ensure(b);overlay=b.hud.get_node(Captions.NODE_NAME)
	await _status_audit(b,overlay,"status_overlay_activation",people)
	await _snapshot("status_overlay_activation")
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;await _frames(4)
	for locale: String in ["zh_CN","zh_TW","en","ja"]:
		Localize.set_language(locale,false);_formation(b,center,1.6)
		await _status_audit(b,overlay,"story_"+locale+"_1280",people)
		await _snapshot("story_"+locale+"_1280")
	Localize.set_language("en",false)
	root.size=Vector2i(960,540);root.content_scale_size=root.size;await _frames(4)
	_formation(b,center,1.5);b._set_inspect(ordinary[2])
	var rows: Array=await _status_audit(b,overlay,"ordinary_captive_inspected_960",people,true)
	check(not rows.is_empty() and rows[0].entity_id==ordinary[2].entity_id and rows[0].priority==0 and rows[0].inspected and b.hud._sel_ref==[ordinary[2]],"ordinary captive keeps real inspection panel and first readable slot in narrow English viewport")
	await _snapshot("ordinary_captive_inspected_960")
	b._set_inspect(null)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;await _frames(4)
	Localize.set_language("zh_CN",false);_formation(b,center,1.6)
	rows=await _status_audit(b,overlay,"status_and_health",people)
	var hp_image: Image=await _snapshot("status_and_health")
	for row in rows:
		if row.status.is_empty():continue
		var actor=people.filter(func(unit):return unit.entity_id==row.entity_id)[0]
		var color:=Color(0.85,.2,.15).lerp(Color(.3,.85,.3),row.health)
		if row.hostile:color=Color(.6,.1,.1).lerp(Color(.9,.55,.2),row.health)
		var health_pixels:=0
		for x in range(8,108):
			var c: Color=hp_image.get_pixelv(Vector2i(row.rect.position+Vector2(x,26)))
			if absf(c.r-color.r)<.03 and absf(c.g-color.g)<.03 and absf(c.b-color.b)<.03:health_pixels+=1
		check(health_pixels<3,"actual story card uses status text rather than an active health strip "+str(actor.entity_id))
	Settings.show_healthbars=false
	await _status_audit(b,overlay,"status_with_healthbars_disabled",people)
	await _snapshot("status_with_healthbars_disabled");Settings.show_healthbars=true
	check(resolution_state==people.map(func(unit):return [unit.entity_id,unit.story_outcome,unit.hp,unit.passive,unit.faction,unit._order_serial]),"all display/locale/inspection work leaves original resolutions health faction and commands unchanged")
	var before: Array=_ledger(b);get_tree().paused=true
	_camera(b,center,1.1,Vector2(25,-10))
	await _status_audit(b,overlay,"paused_story_camera",people)
	check(before==_ledger(b),"paused status labels follow camera without gameplay/order/health/cargo/clock mutation")
	await _snapshot("paused_story_camera");get_tree().paused=false
	for pair in [[ordinary[3],"retreated"],[ordinary[4],"embarked"]]:
		check(pair[0].resolve_story(pair[1]) and not pair[0].visible and not Captions.person_owned(pair[0]),"actual departed person has no floating label "+pair[1])
		pair[0].visible=true
		check(not Captions.person_owned(pair[0]),"departed outcome stays excluded even under explicit visibility guard fixture "+pair[1])
		pair[0].visible=false
	# Same original finite party under message-free narrow-window pressure.
	for actor in b.level.convoy:
		if actor.story_outcome.is_empty():check(actor.resolve_story("unconscious"),"remaining original convoy resolves for explicit capacity photograph")
	people=b.units.filter(func(unit):return Captions.person_owned(unit))
	people.sort_custom(func(left,right):return left.entity_id<right.entity_id)
	root.size=Vector2i(960,540);root.content_scale_size=root.size;await _frames(4)
	Localize.set_language("en",false);_formation(b,center,1.1);b._set_inspect(ordinary[2])
	rows=await _status_audit(b,overlay,"convoy_status_capacity_960",people,true)
	check(not rows.is_empty() and rows[0].entity_id==ordinary[2].entity_id and rows[0].priority==0,"actual whole-party capacity preserves inspected supervisor priority without requiring every card to fit")
	await _snapshot("convoy_status_capacity_960")
	var actual_party_caption_count: int=people.size()
	var old_map=yang.map;yang.map=null
	check(not Captions.person_owned(yang),"unbound resolved actor cannot suppress its original world label")
	yang.map=old_map
	b.hud._pause_root.show();await _frames(4)
	check(overlay.last_layout.is_empty(),"full-screen menu leaves no status/name cards")
	b.hud._pause_root.hide();_camera(b,center,1.6,Vector2(8000,8000));await _frames(4)
	check(overlay.last_layout.is_empty(),"offscreen resolved people leave no stale labels")
	var weak_overlay: WeakRef=weakref(overlay);await _dispose(b)
	check(not is_instance_valid(weak_overlay.get_ref()),"actual scene disposal releases person/status overlay")
	report({"scope":"short-chapter visible resolved people, name/status avoidance and ordinary convoy inspection", "screenshots":screenshots,"layouts":layouts,"actual_story_routes":story_routes,"whole_party_caption_candidates":actual_party_caption_count,"entry_and_whole_party_are_explicit_fixtures":true,"wine_positions_messages_and_stopped_simulation_are_fixtures":true,"story_outcomes_use_original_API":true,"world_fallback_is_same_source_fixture":true,"full_playthrough":false,"full_regression_run":false,"performance_acceptance":false})
