class_name WorldShadow
extends RefCounted
## Shared terrain-conforming shadow renderer for every Battle mode.
##
## Ordinary units and heroes are submitted by one persistent MultiMesh batch:
## one soft contact ellipse and one upper-left-light / down-right cast ellipse
## per visible unit. This replaces the old per-Unit CanvasItem draw work while
## preserving the same ground basis and elevation convention. Buildings and
## static scenery stay on their source-texture outline route: they are few,
## need their recognizable silhouettes, and must retain their authored detail.

const LIGHT_DIRECTION := "upper_left"
const CONTACT_OFFSET := Vector2(1.0, 3.0)
const CAST_OFFSET := Vector2(3.0, 3.0)
const CAST_SHEAR := Vector2(-0.62, -0.28)
const FULL_CONTACT_LAYERS := 4
const LITE_CONTACT_LAYERS := 1
const BATCH_NODE_NAME := &"WorldShadowBatch"
const INITIAL_BATCH_CAPACITY := 128

# QA-only A/B switch. It is evaluated when this script loads, so normal frame
# updates never perform an environment lookup. Production defaults to enabled.
static var _enabled := OS.get_environment("WORLD_SHADOW_ENABLED") != "0"


static func enabled() -> bool:
	return _enabled


static func scenery_batch_enabled() -> bool:
	# Static scenery normally keeps its outline silhouette, but emits the cached
	# contact/cast meshes instead of hundreds of individual CanvasItem commands.
	# This one-run switch is deliberately only evaluated when scenery redraws.
	return _enabled and OS.get_environment("CAMPAIGN_STATIC_SCENERY_SHADOW_MESH") != "0"


class ShadowBatch extends Node2D:
	## One shared MultiMesh canvas submission for all non-building, non-resource
	## units. Each instance has a contact quad and an upper-left-light cast quad;
	## the parent is Battle.world, so the normal ISO transform applies once.
	const RADIUS_ENCODING_SCALE := 64.0
	var battle
	var paired_instances: MultiMeshInstance2D
	var paired_multimesh: MultiMesh
	var capacity := 0
	var active_count := 0
	var retained_dying_units: Array = []
	var retained_dying_visible := 0

	func setup(p_battle) -> void:
		battle = p_battle
		name = BATCH_NODE_NAME
		z_index = 0
		paired_instances = _make_instances()
		paired_multimesh = paired_instances.multimesh
		add_child(paired_instances)
		_resize(INITIAL_BATCH_CAPACITY)

	func _make_instances() -> MultiMeshInstance2D:
		# The two quads deliberately share an instance transform. UV.x 0..1 is
		# contact; 2..3 is cast. The shader restores the exact former local
		# contact/cast transforms after the shared logical origin + ground basis.
		var vertices := PackedVector2Array([
			Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
			Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5),
		])
		var uvs := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
			Vector2(2.0, 0.0), Vector2(3.0, 0.0), Vector2(3.0, 1.0), Vector2(2.0, 0.0), Vector2(3.0, 1.0), Vector2(2.0, 1.0),
		])
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		for index in colors.size():
			colors[index] = Color.WHITE
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
render_mode unshaded;
varying float shadow_shape;
void vertex() {
	shadow_shape = step(1.5, UV.x);
	UV.x = fract(UV.x);
	float radius = max(COLOR.r * 64.0, 0.0);
	vec2 local = VERTEX * (2.0 * radius);
	if (shadow_shape > 0.5) {
		local = vec2(
			1.62 * local.x - 0.20 * local.y + 3.0,
			-0.12 * local.x + 0.54 * local.y + 3.0
		);
		VERTEX = vec2(
			0.5 * local.x + local.y,
			-0.5 * local.x + local.y
		);
	} else {
		VERTEX = local + vec2(1.0, 3.0);
	}
}
void fragment() {
	vec2 point = UV * 2.0 - vec2(1.0);
	float radial_alpha = 1.0 - smoothstep(0.12, 1.0, dot(point, point));
	float opacity = COLOR.g;
	vec3 tint = shadow_shape > 0.5 ? vec3(0.025, 0.05, 0.035) : vec3(0.04, 0.08, 0.06);
	float layer_alpha = shadow_shape > 0.5 ? 0.154 : 0.065;
	COLOR = vec4(tint, layer_alpha * opacity * radial_alpha);
}
"""
		var material := ShaderMaterial.new()
		material.shader = shader
		mesh.surface_set_material(0, material)
		var multimesh := MultiMesh.new()
		multimesh.mesh = mesh
		multimesh.transform_format = MultiMesh.TRANSFORM_2D
		multimesh.use_colors = true
		var node := MultiMeshInstance2D.new()
		node.name = "ContactAndCast"
		node.multimesh = multimesh
		node.modulate = Color.WHITE
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		return node

	func _resize(required: int) -> void:
		if required <= capacity:
			return
		var next := maxi(INITIAL_BATCH_CAPACITY, capacity)
		while next < required:
			next *= 2
		capacity = next
		# Colors carry radius + opacity and must be enabled before instance_count.
		paired_multimesh.instance_count = capacity
		paired_multimesh.visible_instance_count = 0

	func _process(_delta: float) -> void:
		if battle == null or not is_instance_valid(battle) or not WorldShadow._enabled:
			active_count = 0
			retained_dying_visible = 0
			retained_dying_units.clear()
			if paired_multimesh != null:
				paired_multimesh.visible_instance_count = 0
			return
		_update_visible_units()

	func _update_visible_units() -> void:
		var candidates: Array = battle.get("units")
		if not retained_dying_units.is_empty():
			# Prune in place: ordinary frames allocate nothing, and even a mass-death
			# frame does not create a replacement Array in this render hot path.
			for retained_index in range(retained_dying_units.size() - 1, -1, -1):
				var retained = retained_dying_units[retained_index]
				if retained == null or not is_instance_valid(retained) \
						or retained.is_queued_for_deletion() \
						or retained.battle != battle or not WorldShadow._uses_batch(retained) \
						or retained.hp > 0.0 or not bool(retained._dying):
					retained_dying_units.remove_at(retained_index)
		# Capacity is persistent and grows in powers of two. Reserving the whole
		# unit list is safe even when it contains buildings, resources, or dead
		# entries, and avoids performing the expensive visibility/terrain test
		# twice for every moving unit each rendered frame.
		_resize(candidates.size() + retained_dying_units.size())
		var index := 0
		for unit in candidates:
			index = _write_unit_shadow(unit, index)
		var living_visible := index
		for unit in retained_dying_units:
			index = _write_unit_shadow(unit, index)
		retained_dying_visible = index - living_visible
		active_count = index
		paired_multimesh.visible_instance_count = active_count

	func _write_unit_shadow(unit, index: int) -> int:
		if not WorldShadow._batch_eligible(unit, battle):
			return index
		var opacity := WorldShadow._unit_opacity(unit, WorldShadow._death_fraction(unit))
		if opacity <= 0.001:
			return index
		var ground: Transform2D = WorldShadow._ground_basis(unit)
		var radius: float = unit.radius * 0.9
		# This is the same small walk-step contraction formerly applied in
		# Unit._draw(), now calculated once in the shared batch.
		var lift: float = maxf(0.0, -cos(unit._anim_t * 2.0)) * float(unit._move_blend)
		radius *= 1.0 - 0.12 * lift
		opacity *= 1.0 - 0.10 * lift
		var origin := WorldShadow._render_origin(unit)
		# Unit nodes receive `ground` as a local draw transform. The batch is
		# directly below Battle.world, so compose origin + slope exactly once.
		# The shader then reconstructs both former local transforms, including
		# the cast's ISO inverse, from one instance color and transform.
		paired_multimesh.set_instance_transform_2d(index, Transform2D(0.0, origin) * ground)
		paired_multimesh.set_instance_color(index, Color(radius / RADIUS_ENCODING_SCALE, opacity, 0.0, 1.0))
		return index + 1

	func retain_dying_unit(unit) -> void:
		if not WorldShadow._uses_batch(unit) or unit.battle != battle or unit in retained_dying_units:
			return
		retained_dying_units.append(unit)

	func clear_retained_dying_units() -> void:
		# Retained submissions are appended after live units. Shrink the visible
		# prefix immediately so a section transition cannot show one ghost frame.
		active_count = maxi(0, active_count - retained_dying_visible)
		if paired_multimesh != null:
			paired_multimesh.visible_instance_count = active_count
		retained_dying_units.clear()
		retained_dying_visible = 0

	func summary() -> Dictionary:
		return {
			"exists": true,
			"capacity": capacity,
			"contact_instances": active_count,
			"cast_instances": active_count,
			"retained_dying_units": retained_dying_units.size(),
			"retained_dying_visible": retained_dying_visible,
			"shapes_per_instance": 2,
			"draw_submissions": 1,
		}


static func ensure_batch(battle: Node) -> void:
	if not _enabled or battle == null or not is_instance_valid(battle):
		return
	var world: Node = battle.get("world")
	if world == null or not is_instance_valid(world):
		return
	if world.get_node_or_null(String(BATCH_NODE_NAME)) != null:
		return
	var batch := ShadowBatch.new()
	batch.setup(battle)
	# Units have z_index >= 1; a zero-index batch remains above the terrain but
	# below every body, regardless of node insertion order.
	world.add_child(batch)


static func retain_dying_shadow(battle: Node, unit) -> void:
	# Rendering-only retention: the victim remains absent from battle.units, so
	# targeting, navigation, selection and victory counting still forget it at
	# the lethal event.
	if not _enabled or battle == null or not is_instance_valid(battle) \
			or not _uses_batch(unit):
		return
	ensure_batch(battle)
	var world: Node = battle.get("world")
	if world == null or not is_instance_valid(world):
		return
	var batch := world.get_node_or_null(String(BATCH_NODE_NAME))
	if batch != null and batch.has_method("retain_dying_unit"):
		batch.retain_dying_unit(unit)


static func clear_dying_shadows(battle: Node) -> void:
	if battle == null or not is_instance_valid(battle):
		return
	var world: Node = battle.get("world")
	if world == null or not is_instance_valid(world):
		return
	var batch := world.get_node_or_null(String(BATCH_NODE_NAME))
	if batch != null and batch.has_method("clear_retained_dying_units"):
		batch.clear_retained_dying_units()


static func batch_summary(battle: Node) -> Dictionary:
	if battle == null or not is_instance_valid(battle):
		return {"exists": false, "contact_instances": 0, "cast_instances": 0,
			"retained_dying_units": 0, "retained_dying_visible": 0, "draw_submissions": 0}
	var world: Node = battle.get("world")
	if world == null or not is_instance_valid(world):
		return {"exists": false, "contact_instances": 0, "cast_instances": 0,
			"retained_dying_units": 0, "retained_dying_visible": 0, "draw_submissions": 0}
	var node := world.get_node_or_null(String(BATCH_NODE_NAME))
	if node != null and node.has_method("summary"):
		return node.summary()
	return {"exists": false, "contact_instances": 0, "cast_instances": 0,
		"retained_dying_units": 0, "retained_dying_visible": 0, "draw_submissions": 0}


static func route_summary(battle: Node) -> Dictionary:
	# Runtime-test evidence that each category has exactly one owner. This is kept
	# independent from the renderer counters: a local outline must never also be
	# inserted into the mobile batch.
	var result := {
		"mobile_units": 0,
		"mobile_visible": 0,
		"local_outline_units": 0,
		"local_outline_visible": 0,
		"unrouted_units": 0,
		"duplicate_routes": 0,
		"scenery_outline_anchors": 0,
		"scenery_static_batch_anchors": 0,
		"scenery_local_outline_anchors": 0,
		"scenery_duplicate_routes": 0,
		"scenery_static_draw_submissions": 0,
	}
	if battle == null or not is_instance_valid(battle):
		return result
	var units: Array = battle.get("units")
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			continue
		if _uses_batch(unit):
			result.mobile_units += 1
			if unit.visible and unit.is_visible_in_tree():
				result.mobile_visible += 1
		elif unit.is_building or unit.is_resource:
			result.local_outline_units += 1
			if unit.visible and unit.is_visible_in_tree():
				result.local_outline_visible += 1
		else:
			result.unrouted_units += 1
	var map = battle.get("map")
	if map != null and is_instance_valid(map):
		var scenery = map.get("sample_scenery")
		if scenery != null and is_instance_valid(scenery):
			var anchors = scenery.get("_ground_shadows")
			if anchors is Array:
				result.scenery_outline_anchors = anchors.size()
				var static_summary: Dictionary = scenery.shadow_batch_summary() if scenery.has_method("shadow_batch_summary") else {}
				if bool(static_summary.get("uses_mesh_batch", false)):
					result.scenery_static_batch_anchors = int(static_summary.get("anchors", anchors.size()))
					result.scenery_static_draw_submissions = int(static_summary.get("draw_submissions", 0))
				else:
					result.scenery_local_outline_anchors = anchors.size()
				result.scenery_duplicate_routes = 1 if result.scenery_static_batch_anchors > 0 and result.scenery_local_outline_anchors > 0 else 0
	return result


static func draw_unit(unit, death_f: float, fallback_texture: Texture2D = null, directional := false) -> void:
	if not _enabled:
		return
	if unit == null or not is_instance_valid(unit) or unit.story_assistance_hidden():
		return
	if _uses_batch(unit):
		ensure_batch(unit.battle)
		return
	var opacity := _unit_opacity(unit, death_f)
	if opacity <= 0.001:
		return
	var ground := _ground_basis(unit)
	var radius: float = unit.radius * (1.2 if unit.is_building else 0.9)
	# Buildings and resource props retain their richer source-texture outlines.
	unit.draw_set_transform_matrix(ground)
	draw_contact(unit, radius, 0.26 * opacity, FULL_CONTACT_LAYERS)
	unit.draw_set_transform_matrix(Transform2D.IDENTITY)
	var tex := _unit_texture(unit, fallback_texture)
	if tex != null and not unit.is_bound_person():
		var size: float = GameMap.building_visual_px(GameMap.footprint_half_for(unit.radius)) if unit.is_building else unit.radius * 3.7 * unit.visual_scale
		var foot := 0.78 if unit.is_building else 0.82
		var pair_origin: Vector2 = (unit.story_assist_partner.position - unit.position) * 0.5 if unit.story_assistance_active() else Vector2.ZERO
		draw_cast(unit, tex, Rect2(-size * 0.5, -size * foot, size, size), pair_origin, 0.25 * opacity,
			bool(unit.get_meta("building_visual_mirror",false)) if unit.is_building else unit.face_left and not directional, ground)
	unit.draw_set_transform_matrix(Transform2D.IDENTITY)


static func draw_scenery_shadow(canvas: Node2D, tex: Texture2D, anchor: Vector2, size: float, foot: float, alpha: float, ground := Transform2D.IDENTITY) -> void:
	if not _enabled:
		return
	# Static props are not Unit nodes, so their anchor is supplied by scenery. The
	# contact patch and silhouette each receive exactly one anchor and one slope
	# basis; no caller transform may be composed into the cast a second time.
	canvas.draw_set_transform_matrix(Transform2D(0.0, anchor) * ground)
	draw_contact(canvas, size * 0.19, 0.21)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_cast(canvas, tex, Rect2(-size * 0.5, -size * foot, size, size), anchor, alpha, false, ground)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func describe_unit(unit, death_f: float = 0.0) -> Dictionary:
	# Test-facing branch description. Godot does not expose individual canvas draw
	# commands reliably, so this stays aligned with the rendering route above.
	if unit == null or not is_instance_valid(unit):
		return {"visible": false, "contact_layers": 0, "silhouette": false, "light": LIGHT_DIRECTION, "cast_offset": [CAST_OFFSET.x, CAST_OFFSET.y], "ground_basis": [1.0, 0.0, 0.0, 1.0]}
	var ground := _ground_basis(unit)
	var batched := _uses_batch(unit)
	var visible: bool = _enabled and not unit.story_assistance_hidden() and _unit_opacity(unit, death_f) > 0.001
	return {
		"visible": visible,
		"enabled": _enabled,
		"contact_layers": LITE_CONTACT_LAYERS if batched else FULL_CONTACT_LAYERS,
		"silhouette": visible and not unit.is_bound_person(),
		"texture_silhouette": visible and not batched and not unit.is_bound_person(),
		"projection": "batched_ellipse" if batched else "texture",
		"light": LIGHT_DIRECTION,
		"cast_offset": [CAST_OFFSET.x, CAST_OFFSET.y],
		"ground_basis": [ground.x.x, ground.x.y, ground.y.x, ground.y.y],
	}


static func draw_contact(canvas: Node2D, radius: float, alpha: float, layers := FULL_CONTACT_LAYERS) -> void:
	for layer in range(maxi(1, int(layers))):
		var radius_at_layer := radius * (1.20 - float(layer) * 0.16)
		# Static/building contours are few. Disable Canvas antialiasing so the
		# fallback cannot multiply dense scenery draw work on Forward+.
		canvas.draw_circle(CONTACT_OFFSET, radius_at_layer, Color(0.04, 0.08, 0.06, alpha * 0.25), true, -1.0, false)


static func draw_cast(canvas: Node2D, tex: Texture2D, rect: Rect2, origin: Vector2, alpha: float, flip := false, ground := Transform2D.IDENTITY) -> void:
	# One global convention: upper-left light projects down-right. The inverse ISO
	# transform turns an upright source texture into a terrain-conforming outline.
	var cast := Transform2D(Vector2(-1.0 if flip else 1.0, 0.0), CAST_SHEAR, CAST_OFFSET)
	canvas.draw_set_transform_matrix(Transform2D(0.0, origin) * ground * GameMap.ISO_INV * cast)
	canvas.draw_texture_rect(tex, rect.grow(1.0), false, Color(0.03, 0.06, 0.04, alpha * 0.35))
	canvas.draw_texture_rect(tex, rect, false, Color(0.03, 0.06, 0.04, alpha * 0.65))


static func _batch_eligible(unit, battle) -> bool:
	if not _uses_batch(unit) or unit.battle != battle:
		return false
	if not unit.visible or not unit.is_visible_in_tree() or unit.story_assistance_hidden():
		return false
	if unit.hp <= 0.0 and not bool(unit._dying):
		return false
	return bool(battle.call("unit_visual_active", unit.position))


static func _uses_batch(unit) -> bool:
	return unit != null and is_instance_valid(unit) and not unit.is_building and not unit.is_resource


static func _death_fraction(unit) -> float:
	return clampf(float(unit._death_t) / float(unit.DEATH_DUR), 0.0, 1.0) if bool(unit._dying) else 0.0


static func _unit_opacity(unit, death_f: float) -> float:
	return (1.0 - death_f) * (0.35 if unit.is_constructing else 1.0)


static func _ground_basis(unit) -> Transform2D:
	if unit != null and unit.map != null:
		# Free-play maps have no height field. Avoid four zero-valued height
		# samples per visible unit per frame; the legacy ground_basis result there
		# is exactly identity, so this changes neither geometry nor pixels.
		if unit.map.height_field == null:
			return Transform2D.IDENTITY
		return unit.map.ground_basis(unit.position)
	return Transform2D.IDENTITY


static func _render_origin(unit) -> Vector2:
	var origin: Vector2 = unit.position
	# Same flat-map equivalence: height_at is exactly zero without a height field.
	if unit.map != null and unit.map.height_field != null:
		origin -= Vector2.ONE * unit.map.height_at(unit.position)
	return origin


static func _unit_texture(unit, fallback_texture: Texture2D) -> Texture2D:
	# The incoming fallback is already the current source texture selected by
	# Unit._draw(); do not reopen animation strips in the building hot path.
	if unit.story_assistance_active():
		return unit._anim_frame_for_state(fallback_texture)
	return fallback_texture
