extends "res://tools/art_character_direction4_qa.gd"
## Real installed lighting capture/restore only. Map copy below is an explicit
## component fixture; it bypasses no public save gate and proves no world resume.
var Lights: Script
var Maps: Script
var B: Script
var M: Script
var S: Script
var L: Script
var Codec: Script
var trusted: Dictionary
const CONTEXT := {"mode": "campaign", "level_id": "level8", "waves": 0}

func _fixture(b):
	var owner = B.new()
	owner.process_mode = Node.PROCESS_MODE_DISABLED; owner.set_block_signals(true)
	var world := Node2D.new(); owner.add_child(world)
	owner.map = M.new(); world.add_child(owner.map)
	owner.level = L.new(); owner.fog = b.fog; owner._vision = b._vision.duplicate()
	var map = owner.map
	for key: String in ["w", "h", "theme", "base_fill", "environment_style", "natural_surface_enabled", "_navigation_revision"]:
		map.set(key, b.map.get(key))
	map.grid = b.map.grid.duplicate(); map._base_solid = b.map._base_solid.duplicate(); map._block_count = b.map._block_count.duplicate()
	map.decor = b.map.decor.duplicate(true)
	for key in b.map.get_meta_list(): map.set_meta(key, b.map.get_meta(key))
	var maps = Maps.new(trusted.content_version, CONTEXT)
	for key: String in Maps.NAV_NAMES:
		var state: Dictionary = maps._capture_nav(b.map.get(key), b.map.w, b.map.h, key)
		check(state.ok, "lighting fixture actual nav captured: " + key)
		if not state.ok: owner.free(); return null
		map.set(key, maps._new_nav(state.value))
	var captured: Dictionary = maps._capture_height(b.map.height_field)
	check(captured.ok, "lighting fixture actual height captured")
	if not captured.ok: owner.free(); return null
	if captured.value.kind != "none":
		var h = load("res://scripts/campaign_height.gd").new()
		h.width = captured.value.width; h.height = captured.value.height; h.style = captured.value.style
		h.samples = captured.value.samples.duplicate()
		var image := Image.create_from_data(h.width, h.height, false, Image.FORMAT_RF, captured.value.texture_rf_hex.hex_decode())
		h.texture = ImageTexture.create_from_image(image)
		map.height_field = h
	map.sample_scenery = S.new(); map.add_child(map.sample_scenery)
	map.sample_scenery.setup(map)
	return owner

func _case(b, label: String) -> void:
	var lights = Lights.new(trusted.content_version, CONTEXT)
	var captured: Dictionary = lights.capture(b.map.sample_scenery)
	check(captured.ok, label + " original installed lighting capture")
	if not captured.ok: print(captured); return
	var checked: Dictionary = lights.validate(captured.value)
	check(checked.ok, label + " original finite resource/energy contract")
	check(not Lights.new(trusted.content_version, {}).validate(captured.value).ok, label + " default context rejected")
	check(not Lights.new(trusted.content_version, {"mode":"campaign","level_id":"level8","waves":0.0}).validate(captured.value).ok, label + " floating waves rejected")
	var payload: Dictionary = Codec.new().decode(captured.value.payload).value
	for kind: String in ["duplicate_lamp", "market_energy", "foreign_gradient", "wrong_cuiyun"]:
		var bad: Dictionary = captured.value.duplicate(true)
		var value: Dictionary = payload.duplicate(true)
		match kind:
			"duplicate_lamp": value.ownership.lamps[1] = value.ownership.lamps[0]
			"market_energy": value.energies[0] = 1.15
			"foreign_gradient": value.gradient.texture["width"] = 256
			"wrong_cuiyun": value.ownership.cuiyun = value.ownership.lamps[0]
		bad.payload = Codec.new().encode(value).value
		check(not lights.validate(bad).ok, label + " malformed snapshot rejected: " + kind)
	var old_owner = b.map.sample_scenery._cuiyun_light
	b.map.sample_scenery._cuiyun_light = b.map.sample_scenery.get_child(payload.ownership.lamps[0] - 1, true)
	check(not lights.capture(b.map.sample_scenery).ok, label + " wrong live Cuiyun owner rejected")
	b.map.sample_scenery._cuiyun_light = old_owner
	var original_width: int = b.map.sample_scenery._lantern_texture.width
	b.map.sample_scenery._lantern_texture.width = 256
	check(not lights.capture(b.map.sample_scenery).ok, label + " changed generated resource rejected")
	b.map.sample_scenery._lantern_texture.width = original_width
	var owner = _fixture(b)
	if owner == null: return
	var fresh = owner.map.sample_scenery
	check(fresh._lantern_texture != b.map.sample_scenery._lantern_texture and fresh._lantern_texture.gradient != b.map.sample_scenery._lantern_texture.gradient,
		label + " new factory owns fresh generated resources")
	var before_apply: Dictionary = lights.capture(fresh)
	var bad_apply: Dictionary = captured.value.duplicate(true)
	var bad_payload: Dictionary = payload.duplicate(true)
	bad_payload.energies[0] = 0.9
	bad_apply.payload = Codec.new().encode(bad_payload).value
	check(not lights.apply_into(fresh, bad_apply).ok, label + " invalid apply rejected before energy mutation")
	var after_rejected: Dictionary = lights.capture(fresh)
	check(before_apply.ok and after_rejected.ok and before_apply.value == after_rejected.value,
		label + " rejected apply leaves complete lighting state unchanged")
	var applied: Dictionary = lights.apply_into(fresh, captured.value)
	check(applied.ok, label + " original factory lighting state applied")
	if not applied.ok: print(applied)
	var again: Dictionary = lights.capture(fresh)
	var equal: bool = again.ok and again.value == captured.value
	check(equal, label + " exact native lighting recapture")
	for key: String in Maps.NAV_NAMES:
		var maps = Maps.new(trusted.content_version, CONTEXT)
		var a: Dictionary = maps._capture_nav(b.map.get(key), b.map.w, b.map.h, key)
		var z: Dictionary = maps._capture_nav(owner.map.get(key), owner.map.w, owner.map.h, key)
		check(a.ok and z.ok and a.value == z.value, label + " component leaves actual nav unchanged: " + key)
	var source: Dictionary = lights.capture(b.map.sample_scenery)
	check(source.ok and source.value == captured.value, label + " original source lighting unchanged")
	art_runtime.append({"case": label, "exact_lighting_recapture": equal,
		"complete_scenery_qualified": false, "complete_world_qualified": false,
		"scope": "Actual original Level8 lighting state/resource sharing in a detached original-factory fixture. Explicit raw map-value/nav/height copy is not full map/scenery restoration. Phase calls and contact fixtures explicit; no independent process or natural ending."})
	owner.free()

func _run() -> void:
	if not _art_profile_guard(): quit(2); return
	Lights = load("res://scripts/run_daming_lighting_state.gd")
	Maps = load("res://scripts/run_map_state.gd"); B = load("res://scripts/battle.gd")
	M = load("res://scripts/game_map.gd"); S = load("res://scripts/campaign_scenery.gd")
	L = load("res://scripts/levels/level8_daming_rts.gd"); Codec = load("res://scripts/run_state_value_codec.gd")
	art_output = OS.get_environment("ART_QA_OUT"); art_character = "daming_lighting_v22"; art_visual = false
	trusted = _art_identity(); check(trusted.get("save_eligible", false), "installed input identity")
	if not trusted.get("save_eligible", false): _art_finish(); return
	var b = await _start("", 7)
	for frame in range(4): await physics_frame
	await process_frame; paused = true
	await _case(b, "level8 initial")
	# Explicit original task and safe-contact fixtures, never natural-play claims.
	b.level._open_prison(b, false)
	check(b.level.prison_open and not b.level.rescued, "original prison admission before rescue")
	await _case(b, "level8 prison admitted")
	b.level.chai.position = b.map.cell_to_world(Vector2i(19, 15))
	b.level.yue.position = b.level.chai.position + Vector2(25, 0)
	b.level.on_mission_action(b, "daming_fire", b.level.scout)
	check(b.level.signaled and b.level.signal_left == 90.0, "original fire signal callback")
	await _case(b, "level8 signal")
	b.level.process(b, 91.0)
	check(b.level.signaled and b.level.signal_left == 0.0 and b.level.reserve_returned, "original signal timer expiry callback")
	await _case(b, "level8 signal expired")
	paused = false; await _dispose(b); _art_finish()
