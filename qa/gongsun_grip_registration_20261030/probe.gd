extends "base.gd"
## One original Gongsun actor, actual transport callbacks and real movement.
## Old NW appearance uses exact old AtlasTexture metadata as an explicit fixture,
## then restores every property before current production views are sampled.
const Wheel = preload("res://scripts/tribute_cart_wheel_visual.gd")
const Ground = preload("res://scripts/campaign_tribute_cart_visual.gd")
var out := ""
var screenshots: Array = []
var landmarks: Dictionary = {}
var samples: Array = []
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



func _centroid(key: String) -> Vector2:
	var points: Array = landmarks.poses[key].native_grips
	var result := Vector2.ZERO
	for p: Array in points: result += Vector2(p[0],p[1])
	return result / points.size()

func _point(actor, frame: AtlasTexture, native: Vector2) -> Vector2:
	var size: float = actor.radius * 3.7 * actor.visual_scale * actor._frame_draw_scale(frame)
	return Vector2(-size*.5,-size*.82) + actor._frame_draw_offset(frame,size) 		+ (native-frame.region.position+frame.margin.position)*size/float(frame.get_width())

func _properties(frame: AtlasTexture) -> Dictionary:
	return {"region":frame.region,"margin":frame.margin,"scale":frame.get_meta("draw_scale"),
		"top":frame.get_meta("visible_top"),"offset":frame.get_meta("draw_offset_px")}

func _apply(frame: AtlasTexture, values: Dictionary) -> void:
	frame.region=values.region; frame.margin=values.margin
	frame.set_meta("draw_scale",values.scale); frame.set_meta("visible_top",values.top); frame.set_meta("draw_offset_px",values.offset)

func _camera(b, actor) -> void:
	b.map.sync_render_position(actor)
	b.camera.position = b.to_screen(actor.position) + Vector2(0,-22)
	b.camera.force_update_scroll(); actor.queue_redraw()

func _baseline_nw(b, actor) -> void:
	actor.animation_direction="nw";actor.face_left=true
	_camera(b,actor)
	for state: String in ["push_idle","push_walk"]:
		var original: SpriteFrames = load(OS.get_environment("HG_BASELINE").path_join("gongsun_sheng_layered_20261030_"+state+"_nw.tres"))
		var actual: Array = Art.unit_anim_frames(actor.key,state,"nw",actor.art_variant)
		var saved: Array = []
		for i in range(actual.size()):
			var baseline_frame: AtlasTexture = original.get_frame_texture("default",i) as AtlasTexture
			check(actual[i].atlas.resource_path == baseline_frame.atlas.resource_path, "baseline fixture uses same exact native PNG " + state+str(i))
			saved.append(_properties(actual[i])); _apply(actual[i],_properties(baseline_frame))
		for i in range(actual.size()):
			actor._move_blend=0.0 if state=="push_idle" else 1.0
			actor._anim_t=(float(i)+.1)*TAU/4.0;actor.queue_redraw()
			await _snapshot("baseline_nw_"+state+"_"+str(i))
		for i in range(actual.size()):
			_apply(actual[i],saved[i])
			check(_properties(actual[i])==saved[i],"baseline fixture restores exact current frame properties "+state+str(i))

func _views(b, actor, manifest: Dictionary) -> void:
	actor.position=b.map.cell_to_world(Vector2i(12,12));actor.order_stop()
	actor._flinch=Vector2.ZERO;actor._lunge=0;actor._cast_t=0;actor._shi_en_hurt_t=0
	b.camera.zoom=Vector2.ONE*2.8
	await _baseline_nw(b,actor)
	for direction: String in ["se","sw","ne","nw"]:
		actor.animation_direction=direction;actor.face_left=direction in ["sw","nw"]
		_camera(b,actor)
		var walk: Array = Art.unit_anim_frames(actor.key,"push_walk",direction,actor.art_variant)
		var reference: AtlasTexture = walk[0] as AtlasTexture
		var target: Vector2 = _point(actor,reference,_centroid("push_contact_a_"+direction))
		var ref_ratio: float = reference.get_meta("draw_scale")/reference.get_width()
		var cart_contact: Vector2 = Wheel.ground_contact(actor,actor.radius*3.7*actor.visual_scale)
		var before: Array = [actor.position,actor._order_serial,actor._tribute_wheel_angle,b.level.delivered,b.level.cargo.duplicate()]
		for state: String in ["push_idle","push_walk"]:
			var frames: Array = Art.unit_anim_frames(actor.key,state,direction,actor.art_variant)
			check(frames.size()==(1 if state=="push_idle" else 4), "actual production frames "+state+direction)
			for i in range(frames.size()):
				actor._move_blend=0.0 if state=="push_idle" else 1.0
				actor._anim_t=(float(i)+.1)*TAU/4.0;actor.queue_redraw()
				var key: String = ("push_idle" if state=="push_idle" else ["push_contact_a","push_passing_a","push_contact_b","push_passing_b"][i])+"_"+direction
				var frame: AtlasTexture = actor._anim_frame_for_state(null) as AtlasTexture
				check(frame==frames[i] and actor._campaign_tribute_layered_frame(frame), "actual Unit chooses exact registered body "+key)
				check(frame.atlas.resource_path=="res://"+String(manifest.sources[landmarks.poses[key].source].path), "native source identity stays exact "+key)
				check(is_equal_approx(float(frame.get_meta("draw_scale"))/frame.get_width(),ref_ratio),"constant body scale within direction "+key)
				var grip: Vector2 = _point(actor,frame,_centroid(key))
				check(grip.distance_to(target)<.001,"rendered AtlasTexture registration keeps visible grip centroid stable "+key)
				check(Wheel.ground_contact(actor,actor.radius*3.7*actor.visual_scale)==cart_contact,"body phase never moves cart anchor "+key)
				samples.append({"pose":key,"grip":grip,"cart_contact":cart_contact,"source":frame.atlas.resource_path,"scale_ratio":ref_ratio})
				await _snapshot("current_"+key)
		check(before==[actor.position,actor._order_serial,actor._tribute_wheel_angle,b.level.delivered,b.level.cargo.duplicate()],"static gait sampling leaves gameplay and wheel phase unchanged "+direction)
	actor._flinch=Vector2(3,0);actor.queue_redraw()
	check(actor._campaign_tribute_push_state().is_empty() and not actor._campaign_tribute_layered_frame(actor._anim_frame_for_state(null)),"actual hurt still falls back beside parked cart")
	await _snapshot("hurt_nw");actor._flinch=Vector2.ZERO
	actor._lunge=.6;actor.queue_redraw()
	check(actor._campaign_tribute_push_state().is_empty(),"attack still interrupts registered push state")
	await _snapshot("attack_nw");actor._lunge=0

func _move(b, actor) -> void:
	b.process_mode=Node.PROCESS_MODE_INHERIT
	actor.position=b.map.cell_to_world(b.map.nearest_open(Vector2i(12,12),"land"))
	actor.order_stop(); actor.animation_direction="se"
	var origin: Vector2=actor.position;var angle: float=actor._tribute_wheel_angle
	actor.set_physics_process(true)
	actor.order_move(b.map.cell_to_world(b.map.nearest_open(Vector2i(16,12),"land")))
	var walk: Array=Art.unit_anim_frames(actor.key,"push_walk","se",actor.art_variant)
	var seen: Array=[]
	for i in range(120):
		await get_tree().physics_frame
		var index: int=walk.find(actor._anim_frame_for_state(null))
		if index>=0 and not seen.has(index):seen.append(index)
	check(seen.size()==4,"real original Unit movement visits every registered phase")
	actor.set_physics_process(false);actor.order_stop();b.process_mode=Node.PROCESS_MODE_DISABLED
	check(actor.position.distance_to(origin)>1 and actor._tribute_wheel_angle!=angle,"real movement advances feet and independent wheel without injected motion")
	_camera(b,actor)
	await _snapshot("after_real_movement")

func _run() -> void:
	out=OS.get_environment("HG_OUTPUT_ROOT")
	landmarks=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HG_LANDMARKS")))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	AudioServer.set_bus_mute(0,true)
	if not identity(true):report();return
	var b = await _start_once()
	var actor = b.find_unit("gongsun_sheng")
	var stats: Array=[actor.max_hp,actor.atk,actor.atk_cd,actor.base_speed,actor.setup_def.abilities]
	var portrait: Texture2D=actor.ui_portrait_texture()
	check(not Wheel.enabled(actor),"unloaded original Gongsun uses ordinary merchant body")
	_arrive(b,actor,"force_take_");_arrive(b,actor,"force_load_")
	check(actor.get_meta("carrying_tribute",-1)==2 and Wheel.enabled(actor),"original callbacks load Gongsun's exact third cart")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/direction4/level1_gongsun_sheng_layered_20261030.json"))
	for row: Dictionary in manifest.sources.values():
		check(FileAccess.get_sha256("res://"+String(row.path))==row.sha256,"original PNG unchanged "+String(row.path))
	await _views(b,actor,manifest)
	await _move(b,actor)
	_arrive(b,actor,"force_deliver_")
	check(not actor.has_meta("carrying_tribute") and not Wheel.enabled(actor) and b.level.delivered==2,"original delivery counts two loads and restores ordinary route")
	actor._move_blend=0;actor._anim_t=0;actor._flinch=Vector2.ZERO;actor._lunge=0;actor.queue_redraw()
	check(actor.ui_portrait_texture()==portrait and stats==[actor.max_hp,actor.atk,actor.atk_cd,actor.base_speed,actor.setup_def.abilities],"portrait combat values and abilities unchanged")
	check(not actor._campaign_tribute_layered_frame(actor._anim_frame_for_state(null)),"unloaded ordinary pose never uses registered push body")
	_camera(b,actor);await _snapshot("after_delivery")
	await _dispose(b)
	report({"scope":"Gongsun 20 body poses, eight registered SpriteFrames only", "screenshots":screenshots,"samples":samples,
		"baseline_nw_metadata_is_explicit_visual_fixture":true,"native_pixels_changed":false,"full_regression_run":false,
		"wine_and_arrival_positions_and_stopped_simulation_are_fixtures":true,"full_natural_gait_or_grip_occlusion_accepted":false})
