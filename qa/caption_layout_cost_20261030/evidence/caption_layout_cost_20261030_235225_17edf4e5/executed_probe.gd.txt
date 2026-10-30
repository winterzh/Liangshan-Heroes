extends "base.gd"
## Actual current scene with exact prior-caption module as a diagnostic baseline.
## Entry, dense formation and stopped simulation are explicit fixtures.
const Captions=preload("res://scripts/campaign_cart_captions.gd")
var out := ""
var screenshots: Array=[]
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

func _ledger(b) -> Array:
	return [b.level.delivered,b.level.cargo.duplicate(),b.level.cargo_ready.duplicate(),b.level.empty_cargo.duplicate(),
		[b._run_clock._next_tick,b._run_clock._tick,b._run_clock._cache_frame,b._run_clock._fault],
		people.map(func(unit):return [unit.entity_id,unit.position,unit.hp,unit._order_serial])]

var samples: Array=[]
var pair_rects: Array=[]
func _median(values: Array) -> int:
	var ordered: Array=values.duplicate();ordered.sort()
	return int(ordered[int(ordered.size()/2.0)])

func _bench(b,overlay,baseline,label: String,expected_people: int,expected_carts:=0) -> Array:
	await _frames(4);RenderingServer.force_draw(false)
	var before: Array=_ledger(b)
	var outcomes: Array=people.map(func(unit):return unit.story_outcome)
	var resolved: Array=people.filter(func(unit):return not unit.story_outcome.is_empty())
	var directions: Array=resolved.map(func(unit):return unit._frame_directional)
	for _warmup in range(2):
		baseline.compute_layout();overlay.compute_layout()
	var old_us: Array=[];var new_us: Array=[];var current: Array=[]
	for index in range(9):
		var old_rows: Array;var new_rows: Array;var start: int
		# Alternate pair order to avoid always charging first-call work to one side.
		if index%2==0:
			start=Time.get_ticks_usec();old_rows=baseline.compute_layout();old_us.append(Time.get_ticks_usec()-start)
			start=Time.get_ticks_usec();new_rows=overlay.compute_layout();new_us.append(Time.get_ticks_usec()-start)
		else:
			start=Time.get_ticks_usec();new_rows=overlay.compute_layout();new_us.append(Time.get_ticks_usec()-start)
			start=Time.get_ticks_usec();old_rows=baseline.compute_layout();old_us.append(Time.get_ticks_usec()-start)
		check(new_rows==old_rows,label+": exact old/new identity order rectangles anchors status text health and priority pair "+str(index))
		current=new_rows
	check(not current.is_empty(),label+": actual view has rendered labels")
	if expected_people>=0:check(current.filter(func(row):return row.kind=="person").size()==expected_people,label+": exact original visible person count")
	check(current.filter(func(row):return row.kind=="cart").size()==expected_carts,label+": original cart detail count")
	var area: Rect2=overlay.get_viewport_rect().grow(-8);var obstacles: Array=baseline._obstacles(b);var occupied: Array=[]
	for row: Dictionary in current:
		check(area.encloses(row.rect) and baseline._free(row.rect,obstacles) and baseline._free(row.rect,occupied),label+": original collision predicate and viewport accept card "+str(row.entity_id))
		occupied.append(row.rect.grow(Captions.GAP))
	check(before==_ledger(b) and outcomes==people.map(func(unit):return unit.story_outcome),label+": paired display calls change no gameplay position orders health cargo clock or outcomes")
	check(directions==resolved.map(func(unit):return unit._frame_directional),label+": layout-local memo preserves real resolved directional caches")
	var old_median: int=_median(old_us);var new_median: int=_median(new_us)
	var improvement: float=1.0-float(new_median)/float(old_median)
	samples.append({"label":label,"old_us":old_us,"new_us":new_us,"old_median_us":old_median,"new_median_us":new_median,"median_reduction":improvement,"rows":current})
	if label=="dense_21_960_en":check(new_median<=old_median*.8,"dense 21-person paired median improves at least 20 percent; component only")
	return current

func _run() -> void:
	out=OS.get_environment("HG_OUTPUT_ROOT");root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true)
	if not identity(true):report();return
	var b=await _start_once();var overlay=b.hud.get_node(Captions.NODE_NAME)
	var baseline_script: Script=load(get_script().resource_path.get_base_dir().path_join("baseline_caption.gd"))
	var baseline=baseline_script.new();baseline.name="_CaptionCostBaseline"
	baseline._battle=weakref(b);baseline.process_mode=Node.PROCESS_MODE_DISABLED;baseline.hide();b.hud.add_child(baseline)
	check(FileAccess.get_sha256(baseline_script.resource_path)==OS.get_environment("CAPTION_BASELINE_SHA"),"actually loaded old caption module matches pinned Git source")
	b.hud.msg_box.hide();b._set_selection([])
	people=b.units.filter(func(unit):return Captions.person_owned(unit));people.sort_custom(func(left,right):return left.entity_id<right.entity_id)
	var center: Vector2=b.map.cell_to_world(Vector2i(12,12))
	_formation(b,center,2.8)
	await _bench(b,overlay,baseline,"live_9_1280_zh_CN",9);await _snapshot("live_9_1280_zh_CN")
	var chao=b.find_unit("chao_gai")
	_arrive(b,chao,"force_take_");_arrive(b,chao,"force_load_");_arrive(b,chao,"force_deliver_")
	var cart=b.level.bundles[0];Localize.set_language("en",false)
	_formation(b,cart.position-Vector2(24,24),2.0);b.select_single(cart,false)
	var rows: Array=await _bench(b,overlay,baseline,"delivered_cart_1280_en",9,1)
	check(rows[0].entity_id==cart.entity_id and rows[0].selected,"real selected original cart retains first slot")
	await _snapshot("delivered_cart_1280_en");b._set_selection([])
	while b.level.convoy.size()<15:b.level._spawn_next_convoy_member(b)
	for actor in b.level.convoy:actor.set_physics_process(false)
	var ordinary: Array=[b.level.convoy[1],b.level.convoy[12],b.level.convoy[14],b.level.convoy[2],b.level.convoy[3]]
	for pair in [[b.find_unit("yang_zhi"),"unconscious"],[b.find_unit("gongsun_sheng"),"subdued"],[b.find_unit("bai_sheng"),"captured"],[ordinary[0],"unconscious"],[ordinary[1],"subdued"],[ordinary[2],"captured"]]:
		check(pair[0].resolve_story(pair[1]),"original status fixture "+pair[0].key+" "+pair[1])
	people=b.units.filter(func(unit):return Captions.person_owned(unit));people.sort_custom(func(left,right):return left.entity_id<right.entity_id)
	Localize.set_language("ja",false);_formation(b,center,1.6)
	await _bench(b,overlay,baseline,"resolved_12_1280_ja",12);await _snapshot("resolved_12_1280_ja")
	for pair in [[ordinary[3],"retreated"],[ordinary[4],"embarked"]]:check(pair[0].resolve_story(pair[1]),"original departure fixture "+pair[1])
	for actor in b.level.convoy:
		if actor.story_outcome.is_empty():check(actor.resolve_story("unconscious"),"original remaining convoy status fixture")
	people=b.units.filter(func(unit):return Captions.person_owned(unit));people.sort_custom(func(left,right):return left.entity_id<right.entity_id)
	check(people.size()==21,"same original finite party yields 21 caption candidates")
	root.size=Vector2i(960,540);root.content_scale_size=root.size;await _frames(4)
	Localize.set_language("en",false);_formation(b,center,1.1);b._set_inspect(ordinary[2]);b.hud.msg_box.hide()
	rows=await _bench(b,overlay,baseline,"dense_21_960_en",-1)
	check(rows[0].entity_id==ordinary[2].entity_id and rows[0].inspected,"same original supervisor inspection retains first slot")
	for row in rows:
		var rect: Rect2=row.rect.grow(2)
		pair_rects.append([int(floor(rect.position.x)),int(floor(rect.position.y)),int(ceil(rect.end.x)),int(ceil(rect.end.y))])
	await _snapshot("dense_21_960_en")
	# Diagnostic image from exact old caption code on this SAME current scene.
	# This is an algorithm A/B, not an old whole-game/build execution.
	overlay.hide();baseline.show();baseline.queue_redraw();await _snapshot("dense_21_960_en_baseline")
	baseline.hide();overlay.show();overlay.queue_redraw()
	var before: Array=_ledger(b);get_tree().paused=true
	Localize.set_language("ja",false);_camera(b,center,1.5,Vector2(30,-12))
	await _bench(b,overlay,baseline,"paused_21_960_ja",-1)
	check(before==_ledger(b),"actual paused pan/locale retains all gameplay/clock state")
	await _snapshot("paused_21_960_ja");get_tree().paused=false
	b.hud._pause_root.show();await _frames(4)
	check(overlay.compute_layout().is_empty() and baseline.compute_layout().is_empty(),"full-screen menu keeps exact empty layout")
	b.hud._pause_root.hide();_camera(b,center,1.6,Vector2(8000,8000));await _frames(4)
	check(overlay.compute_layout().is_empty() and baseline.compute_layout().is_empty(),"offscreen view keeps exact empty layout")
	var weak_current: WeakRef=weakref(overlay);var weak_old: WeakRef=weakref(baseline)
	await _dispose(b)
	check(not is_instance_valid(weak_current.get_ref()) and not is_instance_valid(weak_old.get_ref()),"actual scene disposal releases both diagnostic/production overlays")
	report({"scope":"five actual-scene paired caption algorithms, exact layout equality and component cost", "screenshots":screenshots,"paired_samples":samples,"paired_card_pixel_regions":pair_rects,"baseline_module_sha256":FileAccess.get_sha256(baseline_script.resource_path),"ordinary_entry_arrival_positions_and_outcomes_are_fixtures":true,"same_scene_prior_caption_module_only":true,"old_whole_build_executed":false,"full_playthrough":false,"full_regression_run":false,"normal_game_performance_accepted":false})
