extends SceneTree
## Real mission progression and rendered state checks; no pose, HP, position or victory fixtures.
## Art/Unit dependencies are loaded only after autoload startup. Run with a real renderer.
const KEYS := ["lu_junyi", "shi_xiu"]
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const VIEW_SIZE := Vector2i(1280,720)
var output_dir := ""
var checks: Array[Dictionary] = []
var receipts: Array[Dictionary] = []
var screenshots: Array[String] = []
var walking := {"lu_junyi":{}, "shi_xiu":{}}
var campaign_completed := false
var arena_completed := false
var restart_completed := false
var initial_states := {}
var mission_record := {}
var appearance_receipts: Array[Dictionary] = []
var first_unlock_draw := {}

func _initialize() -> void: _run.call_deferred()

func _check(passed: bool, label: String) -> void:
	checks.append({"check":label,"passed":passed})
	print("[daming-art-check] ","PASS " if passed else "FAIL ",label)

func _save_hash() -> String:
	var path := "user://campaign.cfg"
	return FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else "absent"

func _texture_info(texture) -> Dictionary:
	if texture == null: return {"missing":true}
	var source: String = texture.resource_path
	var region := ""
	if texture is AtlasTexture:
		source = texture.atlas.resource_path
		region = str(texture.region)
	var image: Image = texture.get_image()
	return {"source":source,"region":region,"size":str(texture.get_size()),
		"pixels":image.get_data().hex_encode().sha256_text() if image != null else "unavailable"}

func _snapshot(b,u,label: String) -> Dictionary:
	b._set_selection([u])
	b.hud.update_selection_panel([u])
	var art = root.get_node("Art")
	var rendered = u._anim_frame_for_state(art.unit_texture(u.key,u.art_variant))
	var frames: Array = art.unit_anim_frames(u.key,"walk",u.animation_direction,u.art_variant)
	var state := {"label":label,"key":u.key,"instance_id":u.get_instance_id(),"variant":u.art_variant,
		"hp":u.hp,"is_captive":u.is_captive,"story_outcome":u.story_outcome,"movement":u.movement_profile,
		"position":str(u.position),"cell":str(b.map.world_to_cell(u.position)),"move_blend":u._move_blend,
		"direction":u.animation_direction,"animation_phase":u._anim_t,"walk_frame_index":frames.find(rendered),
		"rendered_frame":_texture_info(rendered),"portrait":_texture_info(b.hud._port_tex.texture),
		"skills":u.ability_slots.map(func(slot): return slot.id),"base_speed":u.base_speed,
		"level_id":b.level.id(),"phase":int(b.phase),"game_seconds":b.mission.total_game_seconds if b.mission != null else 0.0}
	receipts.append(state)
	return state

func _on_story_appearance(u,b) -> void:
	# Production HeroChip subscribed at _ready, before this observer. Never refresh the HUD here.
	var expected := "res://assets/campaign/portraits/daming_rescued_%s.png"%u.key
	var selected: bool = b.active_unit() == u and b.hud._sel_ref.has(u)
	var state := {"key":u.key,"variant":u.art_variant,"hp":u.hp,"is_captive":u.is_captive,
		"selected":selected,"selected_portrait":_texture_info(b.hud._port_tex.texture),
		"game_seconds":b.mission.total_game_seconds,"source":"production appearance_changed signal; no HUD refresh by observer"}
	appearance_receipts.append(state)
	_check(u.art_variant == "daming_rescued_"+u.key and not u.is_captive and u.hp > 0.0,
		u.key+" real unlock emits appearance change after live free state is installed")
	if u.key == "lu_junyi":
		_check(selected and state.selected_portrait.get("source","") == expected,
			"selected Lu portrait updates inside real appearance signal before any capture refresh")
	if u.key == "shi_xiu":
		# The second prisoner changes in the same real unlock event. Observe its first rendered frame.
		RenderingServer.frame_post_draw.connect(_on_first_unlock_draw.bind(b),CONNECT_ONE_SHOT)

func _on_first_unlock_draw(b) -> void:
	first_unlock_draw = {"game_seconds":b.mission.total_game_seconds,"physics_frame":Engine.get_physics_frames(),
		"rendered_frame":Engine.get_frames_drawn(),"hero_chip_draws":_drawn_hero_portraits(b,"unlock_first_post_draw"),
		"selected_portrait":_texture_info(b.hud._port_tex.texture),"event_completed":b.mission.has_event("daming_prisoners_freed")}

func _drawn_hero_portraits(b,label: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in KEYS:
		var actor = b.find_unit(key)
		var chip = null
		for child in b.hud._hero_bar.get_children():
			if child.get("hero") == actor and not child.is_queued_for_deletion():
				chip = child
				break
		var expected: String = "res://assets/campaign/portraits/%s.png"%actor.art_variant if actor != null else ""
		var state := {"key":key,"missing":chip == null,"variant":chip.get("_last_drawn_art_variant") if chip != null else "",
			"portrait_path":chip.get("_last_drawn_portrait_path") if chip != null else "",
			"expected":expected,"game_seconds":b.mission.total_game_seconds}
		result.append(state)
		_check(chip != null and actor != null and state.variant == actor.art_variant and state.portrait_path == expected,
			label+" "+key+" hero chip actually drew current portrait without timer compensation")
	var selected = b.active_unit()
	var selected_expected := "res://assets/campaign/portraits/%s.png"%selected.art_variant if selected != null else ""
	_check(selected != null and _texture_info(b.hud._port_tex.texture).get("source","") == selected_expected,
		label+" selected portrait agrees with current hero-chip appearance")
	return result

func _resource_checks() -> void:
	var art = root.get_node("Art")
	for key in KEYS:
		for status in ["bound","rescued"]:
			var variant: String = "daming_"+status+"_"+key
			for direction in DIRECTIONS:
				var idle: Array = art.unit_anim_frames(key,"idle",direction,variant)
				var expected := "res://assets/campaign/anim/%s_idle_%s.png"%[variant,direction]
				_check(art.campaign_variant_has_direction(variant,direction) and idle.size() == 1 and _texture_info(idle[0]).get("source","") == expected,
					variant+" "+direction+" has its own bound/free idle")
				if status == "rescued":
					var frames: Array = art.unit_anim_frames(key,"walk",direction,variant)
					var cached: Array = art.unit_anim_frames(key,"walk",direction,variant)
					var has_two: bool = art.campaign_variant_has_animation(variant,"walk",direction) and frames.size() == 2
					_check(has_two,variant+" "+direction+" has exactly two real walk frames")
					if has_two:
						var first: Dictionary = _texture_info(frames[0])
						var second: Dictionary = _texture_info(frames[1])
						_check(first.source == "res://assets/campaign/anim/%s_walk_%s.png"%[variant,direction] and first.source == second.source and first.pixels != second.pixels and frames == cached,
							variant+" "+direction+" walk frames are distinct and reused from Art cache")
			var portrait = art.avatar_texture(key,variant)
			_check(_texture_info(portrait).get("source","") == "res://assets/campaign/portraits/%s.png"%variant,
				variant+" has matching HUD portrait resource")

func _start(arena := false):
	var c = root.get_node("Campaign")
	for mode in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(mode,false)
	c.arena = arena
	c.current = c.index_for_id("level8")
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	b._smoke = false
	return b

func _dispose(b,label: String) -> void:
	var scene_ref = weakref(b)
	var map_ref = weakref(b.map)
	var refs: Array = []
	for key in KEYS:
		var u = b.find_unit(key)
		if u != null: refs.append(weakref(u))
	b.queue_free()
	await process_frame
	await process_frame
	_check(scene_ref.get_ref() == null and map_ref.get_ref() == null and refs.all(func(item): return item.get_ref() == null),label+" scene, map and both actors actually freed")

func _capture(b,u,label: String,focus: Vector2) -> void:
	var prior_mode: int = b.process_mode
	var prior_scale := Engine.time_scale
	b.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.time_scale = 1.0
	b.camera.position = b.to_screen(focus)+Vector2(-60,60)
	b.camera.zoom = Vector2.ONE*1.8
	b.camera.force_update_scroll()
	b._grid_build()
	var receipt: Dictionary = _snapshot(b,u,label)
	var position_before: Vector2 = u.position
	var phase_before: float = u._anim_t
	var events_before: Dictionary = b.mission.events.duplicate(true) if b.mission != null else {}
	b.hud.set_top(b.level.top_status(b))
	if b.mission != null:
		# Refresh layout only; tick(0) can stop an arriving actor and change a walk capture.
		b.mission._panel.visible = b.phase == b.Phase.FIGHT and b.mission.stage_id != ""
		b.mission._panel.position = b.hud.campaign_objective_position()
		b.mission._panel.reset_size()
	u.queue_redraw()
	await process_frame
	await process_frame
	if b.mission != null:
		b.mission._panel.position = b.hud.campaign_objective_position()
		b.mission._panel.reset_size()
	await RenderingServer.frame_post_draw
	if label.begins_with("bound_") or label.begins_with("freed_") or label == "campaign_restart_bound":
		# No HeroChip.queue_redraw or 100ms wait: the production signal must invalidate the canvas.
		receipt["hero_chip_draws"] = _drawn_hero_portraits(b,label)
	var file_name := label+"_1280.png"
	var screenshot: Image = root.get_texture().get_image()
	var saved: bool = screenshot.get_size() == VIEW_SIZE and screenshot.save_png(output_dir.path_join(file_name)) == OK
	_check(saved,label+" native 1280x720 real-scene PNG")
	if saved: screenshots.append(file_name)
	_check(u.position == position_before and u._anim_t == phase_before and u.hp == receipt.hp and int(b.phase) == receipt.phase
		and (b.mission == null or (b.mission.events == events_before and b.mission.total_game_seconds == receipt.game_seconds)),
		label+" capture leaves movement, animation phase, HP and mission unchanged")
	receipt["captured_with_simulation_paused"] = true
	receipt["camera_zoom"] = 1.8
	Engine.time_scale = prior_scale
	b.process_mode = prior_mode

func _story_run() -> void:
	var b = await _start()
	for key in KEYS:
		var u = b.find_unit(key)
		initial_states[key] = _snapshot(b,u,"initial_"+key)
		_check(u.is_captive and u.hp > 0 and u.art_variant == "daming_bound_"+key and u.base_speed == 0.0,
			key+" starts alive, bound and unable to walk")
		_check(initial_states[key].portrait.source == "res://assets/campaign/portraits/daming_bound_%s.png"%key,
			key+" initial selection portrait matches bound art")
		await _capture(b,u,"bound_"+key,(b.level.lu.position+b.level.shi.position)*0.5)
	_check(not b.level.prison_door_open and not b.level.rescued and not b.mission.has_event("daming_prisoners_freed"),"initial prison door and rescue event are untouched")
	# An ordinary selection before the event lets the production signal update the lower portrait.
	b._set_selection([b.level.lu])
	_check(b.active_unit() == b.level.lu and _texture_info(b.hud._port_tex.texture).get("source","") == "res://assets/campaign/portraits/daming_bound_lu_junyi.png",
		"Lu is normally selected with his bound portrait before actual unlocking")
	for key in KEYS:
		b.find_unit(key).appearance_changed.connect(_on_story_appearance.bind(b))
	var freed_seen := false
	var freed_positions := {}
	var deadline := Time.get_ticks_msec()+120000
	b._smoke = true
	Engine.time_scale = 4.0
	while b.phase != b.Phase.END and Time.get_ticks_msec() < deadline:
		await process_frame
		if b.mission.has_event("daming_prisoners_freed") and not freed_seen:
			freed_seen = true
			# This is intentionally before _snapshot/_capture, which refresh the selection panel.
			_check(b.active_unit() == b.level.lu and _texture_info(b.hud._port_tex.texture).get("source","") == "res://assets/campaign/portraits/daming_rescued_lu_junyi.png",
				"completed unlock already shows free Lu in selected portrait before test refresh")
			_check(b.mission.has_event("daming_fire_lit") and b.mission.has_event("daming_gate_opened") and b.level.prison_door_open and b.level.gate_open,"actual fire signal and gate actions preceded unlocking")
			_check(b.map.is_open_world(b.map.cell_to_world(b.level.PRISON_DOOR),"land"),"real prison doorway is traversable after admission and rescue")
			for key in KEYS:
				var u = b.find_unit(key)
				freed_positions[key] = u.position
				var state: Dictionary = _snapshot(b,u,"freed_"+key)
				_check(u.get_instance_id() == initial_states[key].instance_id and not u.is_captive and u.hp > 0 and u.art_variant == "daming_rescued_"+key and u.story_outcome == "",key+" same living actor changes to free art through unlock event")
				_check(state.portrait.source == "res://assets/campaign/portraits/daming_rescued_%s.png"%key,key+" selection portrait changes with rescue variant")
				await _capture(b,u,"freed_"+key,(b.level.lu.position+b.level.shi.position)*0.5)
		if freed_seen:
			for key in KEYS:
				var u = b.find_unit(key)
				if u == null or u.hp <= 0 or u.story_outcome != "" or u._move_blend <= 0.3: continue
				if u.position.distance_to(freed_positions[key]) < 32.0: continue
				if b.map.world_to_cell(u.position).y < 23: continue # Observe on the street, clear of the prison wall.
				var frames: Array = root.get_node("Art").unit_anim_frames(key,"walk",u.animation_direction,u.art_variant)
				var actual = u._anim_frame_for_state(root.get_node("Art").unit_texture(key,u.art_variant))
				var index := frames.find(actual)
				if frames.size() != 2 or index < 0 or walking[key].has(str(index)): continue
				walking[key][str(index)] = {"position":str(u.position),"direction":u.animation_direction,"game_seconds":b.mission.total_game_seconds,"hp":u.hp,"source":_texture_info(actual)}
				_check(not u.is_captive and u.art_variant == "daming_rescued_"+key and b.map.is_open_world(u.position,"land"),key+" really walks on land using frame "+str(index))
				await _capture(b,u,"walking_%s_frame%d"%[key,index],u.position)
	Engine.time_scale = 1.0
	b._smoke = false
	campaign_completed = b.phase == b.Phase.END and b.mission.has_event("daming_victory")
	_check(freed_seen and campaign_completed,"authored mission driver completes real rescue and victory without outcome injection")
	_check(appearance_receipts.size() == 2 and appearance_receipts.map(func(item): return item.key) == KEYS and not first_unlock_draw.is_empty()
		and bool(first_unlock_draw.get("event_completed",false)),"both real appearance signals and their first post-draw observation actually completed")
	for key in KEYS:
		var u = b.find_unit(key)
		_check(walking[key].size() == 2,key+" both walk frames were observed during real mission movement")
		_check(u != null and u.hp > 0 and not u.is_captive and u.story_outcome == "retreated",key+" exits alive with no remaining captivity")
		if u != null: _snapshot(b,u,"extracted_"+key)
	mission_record = {"events":b.mission.events.keys(),"total_game_seconds":b.mission.total_game_seconds,"stage_metrics":b.mission.stage_metrics.duplicate(true),"final_stage":b.level.stage,"phase":int(b.phase)}
	if campaign_completed: await _capture(b,b.level.shi,"both_rescued_victory",b.map.cell_to_world(b.level.EXIT_CELL))
	await _dispose(b,"campaign after rescue")

func _mode_run() -> void:
	var definitions = load("res://scripts/defs.gd")
	var b = await _start(true)
	_check(b.level.id() == "arena" and b.mission == null,"mode switch builds actual arena without campaign mission")
	for key in KEYS:
		_check(b.queue_train(b.level.hall,key,false),"arena accepts normal recruitment for "+key)
		var u = b.find_unit(key)
		for frame in range(180):
			if u != null: break
			await process_frame
			u = b.find_unit(key)
		_check(u != null,"arena recruitment creates "+key)
		if u == null: continue
		var state: Dictionary = _snapshot(b,u,"arena_"+key)
		_check(u.art_variant == "" and not u.is_captive and not u.is_noncombat and u.story_outcome == "" and u.base_speed == definitions.UNITS[key].speed,key+" arena restores original appearance, movement and combat state")
		_check(state.skills == definitions.UNITS[key].abilities and state.skills.size() == 4,key+" arena restores all four original skills")
		_check(not String(state.portrait.get("source","")).begins_with("res://assets/campaign/") and state.portrait.get("pixels","") != initial_states[key].portrait.get("pixels",""),key+" arena portrait does not reuse campaign prisoner portrait")
		var frames: Array = root.get_node("Art").unit_anim_frames(key,"walk","se",u.art_variant)
		_check(not frames.is_empty() and not String(_texture_info(frames[0]).get("source","")).begins_with("res://assets/campaign/"),key+" arena walk does not reuse warmed prisoner cache")
		var start: Vector2 = u.position
		# The east route crosses the arena's parked workers. Use the clear southern yard.
		var offset := Vector2i(0,4) if key == "lu_junyi" else Vector2i(4,4)
		var destination: Vector2i = b.map.nearest_open(b.map.world_to_cell(start)+offset,"land")
		u.order_move(b.map.cell_to_world(destination))
		for frame in range(240):
			await process_frame
			if u.position.distance_to(start) > 35.0: break
		_check(u.movement_profile == "land" and u.position.distance_to(start) > 20.0 and b.map.is_open_world(u.position,"land"),key+" arena executes a real land move")
		await _capture(b,u,"arena_"+key,u.position)
	arena_completed = b.find_unit("lu_junyi") != null and b.find_unit("shi_xiu") != null
	await _dispose(b,"arena")
	b = await _start()
	for key in KEYS:
		var u = b.find_unit(key)
		var state: Dictionary = _snapshot(b,u,"restart_"+key)
		_check(u.is_captive and u.hp > 0 and u.base_speed == 0 and u.story_outcome == "" and u.art_variant == initial_states[key].variant,key+" returning campaign restores live bound state")
		_check(state.portrait == initial_states[key].portrait and state.rendered_frame == initial_states[key].rendered_frame,key+" returning campaign restores initial portrait and idle cache")
	_check(not b.level.rescued and not b.level.gate_open and not b.level.prison_door_open and not b.mission.has_event("daming_prisoners_freed"),"returning campaign resets gates, rescue and story flags")
	await _capture(b,b.level.lu,"campaign_restart_bound",(b.level.lu.position+b.level.shi.position)*0.5)
	restart_completed = true
	await _dispose(b,"returning campaign")

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	OS.set_environment("SMOKE_TEST","")
	if DisplayServer.get_name() == "headless":
		push_error("Prisoner visual QA requires a real graphical renderer.")
		quit(2)
		return
	output_dir = OS.get_environment("DAMING_PRISONER_VISUAL_OUT")
	if output_dir.is_empty(): output_dir = ProjectSettings.globalize_path("res://qa/web_chatgpt_art_20260831/daming_prisoner_visual")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		quit(2)
		return
	root.size = VIEW_SIZE
	root.content_scale_size = VIEW_SIZE
	root.title = "Liangshan Daming prisoner story QA · 1280×720"
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	root.get_node("Settings").game_speed = 1.0
	AudioServer.set_bus_mute(0,true)
	var saved_before := _save_hash()
	_resource_checks()
	if checks.all(func(item): return item.passed):
		await _story_run()
		if campaign_completed: await _mode_run()
	_check(campaign_completed and arena_completed and restart_completed and screenshots.size() == 12,"all real-story, arena and restart captures actually completed")
	_check(_save_hash() == saved_before,"CAMPAIGN_QA keeps campaign.cfg existence and bytes unchanged")
	var passed: bool = checks.all(func(item): return item.passed)
	var report := {"passed":passed,"checks":checks,"receipts":receipts,"walking":walking,"screenshots":screenshots,"mission":mission_record,
		"appearance_signals":appearance_receipts,"first_unlock_draw":first_unlock_draw,
		"renderer":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"save_hash_before":saved_before,"save_hash_after":_save_hash(),
		"scope":"Real authored task requests, movement and combat; still captures pause existing simulation only. No injected pose, HP, actor position, outcome or victory. Two source walk poses, not a full four-frame cycle. Not a performance sample or human playtest."}
	var file := FileAccess.open(output_dir.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("[daming-art-summary] ",JSON.stringify({"passed":passed,"checks":checks.size(),"screenshots":screenshots.size(),"campaign_completed":campaign_completed,"arena_completed":arena_completed,"restart_completed":restart_completed}))
	quit(0 if passed else 1)
