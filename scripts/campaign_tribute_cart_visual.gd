extends RefCounted
## Chapter16 ground cargo after actual seizure; no additional save fields.
const Wheel = preload("res://scripts/tribute_cart_wheel_visual.gd")
const BASE_BODY_SIZE := 48.1
static func enabled(unit) -> bool:
	if unit.key != "treasure_cart": return false
	var b = unit.battle
	if b == null or b.level == null or not b.units.has(unit): return false
	var script_path: String = b.level.get_script().resource_path
	if script_path == "res://scripts/levels/level1_huangnigang_short.gd":
		# The current short chapter replaces the base route during deploy.
		if unit.art_variant != "tribute_load_alpha_20260906" \
			or String(unit.setup_def.get("campaign_object", "")) != "tribute_load_alpha_20260906" \
			or unit.has_meta("campaign_environment_route"): return false
	elif script_path == "res://scripts/levels/level1_huangnigang.gd":
		if unit.art_variant != "tribute_load" \
			or String(unit.get_meta("campaign_environment_route", "")) != "tribute_load": return false
	else: return false
	if b.level.id() != "level1": return false
	var index: int = b.level.bundles.find(unit)
	if index < 0: return false
	# Drinking alone does not load a cart. The exact original cargo must have
	# been claimed before its later world appearance changes from load to cart.
	return b.mission.has_event("take_%d" % index) \
		or b.mission.has_event("force_taken_%d_0" % index) \
		or b.mission.has_event("deliver_%d" % index) \
		or b.mission.has_event("force_delivered_%d" % index) \
		or int(b.level.force_attempts.get(index, 0)) > 0

static func visual_size(texture: Texture2D, scale_factor := 1.0) -> float:
	# Match the adopted Liu cart's scale (13 radius * 3.7 body size), while
	# its own world anchor sits under the wheel rather than behind the handles.
	return BASE_BODY_SIZE * scale_factor * float(texture.get_meta("draw_scale", 1.0))

static func layered(unit) -> bool:
	return enabled(unit) and unit.animation_direction in Wheel.GROUND_POSES \
		and unit.battle.level.get_script().resource_path == "res://scripts/levels/level1_huangnigang_short.gd"

static func draw(unit, tint: Color) -> void:
	Wheel.draw_ground_cart(unit, BASE_BODY_SIZE * unit.visual_scale, tint)

static func receive_wheel_phase(cart, actor) -> bool:
	# The same cart keeps its visual wheel angle when loaded or relayed. The
	# receiver's previous vehicle must not supply this vehicle's spoke phase.
	if not is_instance_valid(cart) or not Wheel.enabled(actor) or cart.map != actor.map \
		or cart.battle != actor.battle or cart.key != "treasure_cart": return false
	var b = actor.battle
	if b == null or b.level == null or b.level.get_script().resource_path != "res://scripts/levels/level1_huangnigang_short.gd": return false
	var index: Variant = actor.get_meta("carrying_tribute", -1)
	if not preload("res://scripts/huangnigang_transport.gd").is_cart(index) or index >= b.level.bundles.size() \
		or b.level.bundles[index] != cart or b.level.cargo.get(index) != actor \
		or b.level._cargo_was_delivered(b, index): return false
	if cart.art_variant != "tribute_load_alpha_20260906" \
		or String(cart.setup_def.get("campaign_object", "")) != "tribute_load_alpha_20260906" \
		or cart.has_meta("campaign_environment_route") or not is_finite(cart._tribute_wheel_angle): return false
	actor._tribute_wheel_angle = fposmod(cart._tribute_wheel_angle, TAU)
	return true

static func place_from_carrier(cart, actor) -> bool:
	# A dying carrier also releases the same vehicle. Registration ownership
	# is separate from the live-body drawing gate; no terminal body is rendered.
	if not is_instance_valid(cart) or not Wheel.owns_registration(actor) \
		or not actor.has_meta("carrying_tribute") or cart.map != actor.map \
		or cart.battle != actor.battle or cart.key != "treasure_cart": return false
	var b = actor.battle
	if b == null or b.level == null or b.level.get_script().resource_path != "res://scripts/levels/level1_huangnigang_short.gd": return false
	var raw_index: Variant = actor.get_meta("carrying_tribute", -1)
	if typeof(raw_index) != TYPE_INT: return false
	var index: int = raw_index
	if index < 0 or index >= b.level.bundles.size() or b.level.bundles[index] != cart \
		or b.level.cargo.get(index) != actor: return false
	var body_size: float = actor.radius * 3.7 * actor.visual_scale
	if not is_finite(body_size) or body_size <= 0.0: return false
	var contact: Vector2 = actor.map.project(actor.position) + Wheel.ground_contact(actor, body_size)
	var position: Vector2 = actor.map.unproject(contact)
	var cell: Vector2i = actor.map.world_to_cell(position)
	# Keep an edge-of-path death drop reachable. On open ground the exact
	# projected wheel contact is retained, including non-flat terrain.
	var open_cell: Vector2i = actor.map.nearest_open(cell, "land")
	if open_cell == Vector2i(-1, -1): return false
	if not actor.map.is_open_world(position, "land"):
		position = actor.map.cell_to_world(open_cell)
	cart.position = position
	cart.z_index = clampi(1 + int(actor.map.project(position).y), 1, 3400)
	cart.animation_direction = actor.animation_direction
	cart.face_left = actor.face_left
	cart.visual_scale = body_size / BASE_BODY_SIZE
	cart._tribute_wheel_angle = actor._tribute_wheel_angle
	return true
