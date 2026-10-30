extends Node2D
## Screen-space names/status for short-chapter people and delivered tribute carts.
## The world Unit keeps its real position, hit target, health and selection.
const Ground = preload("res://scripts/campaign_tribute_cart_visual.gd")
const Wheel = preload("res://scripts/tribute_cart_wheel_visual.gd")
const NODE_NAME := "_TributeCartCaptions"
const CARD_SIZE := Vector2(116, 34)
const GAP := 6.0
var _battle: WeakRef
var last_layout: Array = [] # Rendered rectangles/IDs only, never saved Unit state.
var _styles: Dictionary = {} # Reuse the few border styles; no per-frame StyleBox allocation.

static func owns(unit) -> bool:
	if not Ground.layered(unit): return false
	var index: int = unit.battle.level.bundles.find(unit)
	return unit.battle.level._cargo_was_delivered(unit.battle, index)

static func wants_info(unit) -> bool:
	return owns(unit) and unit.hp > 0.0 and unit.is_visible_in_tree() \
		and (unit.selected or unit.inspected or unit.hp < unit.max_hp)

static func person_owned(unit) -> bool:
	var named: bool = unit.is_hero or (unit.key == "bai_sheng" and unit.art_variant == "hn_bai_sheng")
	var resolved: bool = unit.story_outcome in ["unconscious", "subdued", "captured"]
	if (not named and not resolved) or unit.is_building or unit.is_resource or unit.hp <= 0.0 or unit._dying \
		or unit.garrisoned or unit.movement_profile == "water" \
		or unit.story_outcome in ["retreated", "embarked"]: return false
	var b = unit.battle
	return is_instance_valid(b) and is_instance_valid(b.level) and is_instance_valid(b.hud) \
		and b.level.get_script().resource_path == "res://scripts/levels/level1_huangnigang_short.gd" \
		and is_instance_valid(unit.map) and unit.map == b.map and b.units.has(unit) and b.hud.has_node(NODE_NAME) \
		and (unit.is_hero or resolved or b.level.actors.has(unit))

static func world_labels_owned(unit) -> bool:
	return owns(unit) or person_owned(unit)

static func ensure(b) -> void:
	if not is_instance_valid(b.hud) or b.hud.has_node(NODE_NAME): return
	var overlay = load("res://scripts/campaign_cart_captions.gd").new()
	overlay.name = NODE_NAME
	overlay._battle = weakref(b)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	b.hud.add_child(overlay)
	# Unit draw commands may still contain deployment labels. Invalidate them
	# when the overlay starts owning names; no game state or orders are changed.
	for unit in b.units:
		if is_instance_valid(unit) and person_owned(unit): unit.queue_redraw()

func _process(_delta: float) -> void:
	if _battle == null or not is_instance_valid(_battle.get_ref()):
		queue_free()
		return
	queue_redraw() # Also follows camera/selection while the simulation is paused.

func _to_overlay(unit) -> Transform2D:
	var tr: Transform2D = unit.get_global_transform_with_canvas() * unit.map.ISO_INV
	var parent_view: Transform2D = unit.get_parent().get_global_transform_with_canvas()
	tr.origin -= (parent_view.x + parent_view.y) * float(unit.get_meta("render_height", 0.0))
	return get_global_transform_with_canvas().affine_inverse() * tr

func _control_rect(control) -> Rect2:
	var tr: Transform2D = get_global_transform_with_canvas().affine_inverse() * control.get_global_transform_with_canvas()
	return tr * Rect2(Vector2.ZERO, control.size)

func _story_body_rect(unit) -> Rect2:
	# Match the real story frame, its authored scale/offset and fallback tilt.
	# Frame lookup sets this render cache; restore it so a layout query is inert.
	var directional: bool = unit._frame_directional
	var frames: Array = unit._story_animation_frames()
	var frame: Texture2D
	var angle := 0.0
	var vertical := 1.0
	var offset := Vector2.ZERO
	if not frames.is_empty(): frame = frames[-1]
	else:
		frame = unit._rest_frame(Art.unit_texture(unit.key, unit.visual_art_variant(), unit.animation_direction))
		if unit.story_outcome == "unconscious": angle = 1.42; offset.y = unit.radius * 0.4
		else: vertical = 0.70; offset.y = unit.radius * 0.15
	var mirror := -1.0 if unit.face_left and not unit._frame_directional else 1.0
	unit._frame_directional = directional
	var size: float = unit.radius * 3.7 * unit.visual_scale * unit._frame_draw_scale(frame)
	var rect := Rect2(-size * 0.5, -size * 0.82, size, size)
	rect.position += unit._frame_draw_offset(frame, size)
	return (Transform2D(angle, Vector2(mirror, vertical), 0.0, offset) * rect).grow(2.0)

func _story_rect_cached(unit, rects: Dictionary) -> Rect2:
	var key: int = unit.get_instance_id()
	if not rects.has(key): rects[key] = _story_body_rect(unit)
	return rects[key]

func _label_bar(unit, story_rects: Variant = null) -> float:
	if unit.is_building: return float(unit.get_meta("campaign_environment_label_y", -unit.radius * 1.9))
	var bar: float = unit._campaign_tribute_label_y(-unit.radius * 3.3 * unit.visual_scale)
	if unit.story_outcome in ["unconscious", "subdued", "captured"]:
		var rect: Rect2 = _story_body_rect(unit) if story_rects == null else _story_rect_cached(unit, story_rects)
		return minf(bar, rect.position.y - 8.0)
	# Accepted native frames can extend above the ordinary standing silhouette.
	# Reuse their measured top/offset instead of covering a raised weapon.
	var frame: Texture2D = unit._anim_frame_for_state(null)
	if frame != null and frame.has_meta("visible_top"):
		var size: float = unit.radius * 3.7 * unit.visual_scale * unit._frame_draw_scale(frame)
		bar = minf(bar, size * (float(frame.get_meta("visible_top")) - 0.82) + unit._frame_draw_offset(frame, size).y - 8.0)
	return bar

func _obstacles(b, story_rects: Variant = null) -> Array:
	if story_rects == null: story_rects = {} # New local memo for standalone callers.
	var result: Array = []
	for actor in b.units:
		if not is_instance_valid(actor) or not is_instance_valid(actor.map) or actor._dying or not actor.is_visible_in_tree(): continue
		var body: float = actor.radius * 3.7 * actor.visual_scale
		var bar: float = _label_bar(actor, story_rects)
		var owns_name: bool = person_owned(actor)
		var width: float = body + 6.0 if owns_name else maxf(body, minf(100, ThemeDB.fallback_font.get_string_size(Localize.text(actor.display_name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)) + 6.0
		var top: float = bar if owns_name else (bar - 22.0 if actor.is_hero or actor.is_building else bar - 2.0)
		result.append((_to_overlay(actor) * Rect2(-width * 0.5, top, width, -top + 32)).grow(GAP))
		if actor.story_outcome in ["unconscious", "subdued", "captured"]:
			result.append((_to_overlay(actor) * _story_rect_cached(actor, story_rects)).grow(GAP))
		if Wheel.enabled(actor):
			# Loaded carts are painted inside their carrier's command list, not
			# in b.units. Reserve their real body/rim rectangles as well.
			var pose: Dictionary = Wheel._pose(actor)
			var row: Dictionary = Wheel.FIT[actor.animation_direction]
			var scale_native: float = body / float(pose.virtual_canvas_reference)
			var region: Array = row.body_region
			var rect := Rect2(Wheel._point(pose, Vector2(region[0], region[1]), scale_native), Vector2(region[2], region[3]) * scale_native)
			result.append((_to_overlay(actor) * rect).grow(GAP))
			region = row.region
			var sr: float = row.rim_uniform_scale
			var translation := Vector2(row.rim_translation_original_native[0], row.rim_translation_original_native[1])
			rect = Rect2(Wheel._point(pose, translation + sr * Vector2(region[0], region[1]), scale_native), Vector2(region[2], region[3]) * sr * scale_native)
			result.append((_to_overlay(actor) * rect).grow(GAP))
	for cart in b.level.bundles:
		if not is_instance_valid(cart) or not Ground.layered(cart) or not cart.is_visible_in_tree(): continue
		var texture: Texture2D = Art.campaign_tribute_cart_texture(cart.animation_direction)
		if texture == null: continue
		var size: float = Ground.visual_size(texture, cart.visual_scale)
		var top: float = size * (float(texture.get_meta("visible_top", 0.0)) - 0.82)
		result.append((_to_overlay(cart) * Rect2(-size * 0.5, top, size, -top + 8)).grow(GAP))
	for field: String in ["top_label", "_fps_label", "_res_bar", "_bottom_panel", "_hero_bar", "msg_box", "_info_panel", "_info_toggle", "_control_help_panel", "_inventory_popup", "_tip_panel", "_intro_root", "_end_root", "_pause_root"]:
		var control = b.hud.get(field)
		if is_instance_valid(control) and control is Control and control.is_visible_in_tree() and control.size.x > 1 and control.size.y > 1:
			result.append(_control_rect(control).grow(GAP))
	for control in [b.mission._panel, b.mission._toggle]:
		if is_instance_valid(control) and control.is_visible_in_tree(): result.append(_control_rect(control).grow(GAP))
	return result

func _fit(origin: Vector2, area: Rect2) -> Vector2:
	return Vector2(clampf(origin.x, area.position.x, area.end.x - CARD_SIZE.x),
		clampf(origin.y, area.position.y, area.end.y - CARD_SIZE.y))

func _free(rect: Rect2, obstacles: Array) -> bool:
	var padded := rect.grow(GAP)
	for obstacle: Rect2 in obstacles:
		if padded.intersects(obstacle): return false
	return true

func _nearest_slot(desired: Vector2, points: Array[Vector2], obstacles: Array) -> Rect2:
	var best := Rect2()
	var distance := INF
	for point: Vector2 in points:
		var score: float = point.distance_squared_to(desired)
		if score < distance:
			var rect := Rect2(point, CARD_SIZE)
			if _free(rect, obstacles): best = rect; distance = score
	return best

func _place(desired: Vector2, area: Rect2, obstacles: Array) -> Rect2:
	var initial := Rect2(_fit(desired, area), CARD_SIZE)
	if _free(initial, obstacles): return initial
	var candidates: Array[Vector2] = []
	var seen: Dictionary = {initial.position: true} # This candidate is already blocked.
	for obstacle: Rect2 in obstacles:
		for point: Vector2 in [Vector2(desired.x, obstacle.position.y - CARD_SIZE.y - GAP * 2),
			Vector2(desired.x, obstacle.end.y + GAP * 2), Vector2(obstacle.position.x - CARD_SIZE.x - GAP * 2, desired.y),
			Vector2(obstacle.end.x + GAP * 2, desired.y)]:
			var fitted := _fit(point, area)
			if not seen.has(fitted):
				seen[fitted] = true
				candidates.append(fitted) # Preserve first occurrence and equal-distance ties.
	var best := _nearest_slot(desired, candidates, obstacles)
	if best.has_area(): return best
	# Build the finite grid only when obstacle-edge candidates cannot fit.
	candidates.clear()
	for y in range(int(area.position.y), int(area.end.y - CARD_SIZE.y) + int(CARD_SIZE.y + GAP), int(CARD_SIZE.y + GAP)):
		for x in range(int(area.position.x), int(area.end.x - CARD_SIZE.x) + int(CARD_SIZE.x + GAP), int(CARD_SIZE.x + GAP)):
			var fitted := _fit(Vector2(x, y), area)
			if not seen.has(fitted):
				seen[fitted] = true
				candidates.append(fitted)
	return _nearest_slot(desired, candidates, obstacles)

func _entry(unit, kind: String, anchor: Vector2, desired: Vector2) -> Dictionary:
	var priority := 2
	if kind == "person" and not unit.is_hero and unit.key != "bai_sheng": priority = 3
	if unit.story_outcome.is_empty() and unit.hp < unit.max_hp: priority = 1
	if unit.selected or unit.inspected: priority = 0
	return {"unit": unit, "kind": kind, "anchor": anchor, "desired": desired,
		"entity_id": unit.entity_id, "priority": priority}

func compute_layout() -> Array:
	var b = _battle.get_ref() if _battle != null else null
	if not is_instance_valid(b) or not is_instance_valid(b.level) or b.level.get_script().resource_path != "res://scripts/levels/level1_huangnigang_short.gd": return []
	var area: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect().grow(-8)
	if area.size.x < CARD_SIZE.x or area.size.y < CARD_SIZE.y: return []
	var entries: Array = []
	# Rectangles are shared only within this calculation, never across frames.
	# Pose/camera/state changes therefore require no invalidation policy.
	var story_rects: Dictionary = {}
	for hero in b.units:
		if not is_instance_valid(hero) or not person_owned(hero) or not hero.is_visible_in_tree(): continue
		var tr := _to_overlay(hero)
		var bar: float = _label_bar(hero, story_rects)
		var anchor: Vector2 = tr * Vector2(0, bar)
		if not area.grow(24).has_point(anchor): continue
		entries.append(_entry(hero, "person", anchor, anchor - Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y + GAP * 2)))
	for cart in b.level.bundles:
		if not is_instance_valid(cart) or not wants_info(cart): continue
		var tr := _to_overlay(cart)
		if not area.grow(24).has_point(tr.origin): continue
		var texture: Texture2D = Art.campaign_tribute_cart_texture(cart.animation_direction)
		var size: float = Ground.visual_size(texture, cart.visual_scale)
		var bar: float = size * (float(texture.get_meta("visible_top", 0.0)) - 0.82) - 8.0
		entries.append(_entry(cart, "cart", tr.origin, tr * Vector2(0, bar) - Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)))
	if entries.is_empty(): return []
	entries.sort_custom(func(left, right):
		return int(left.priority) < int(right.priority) if left.priority != right.priority else int(left.entity_id) < int(right.entity_id))
	var obstacles := _obstacles(b, story_rects)
	for obstacle: Rect2 in obstacles:
		if obstacle.encloses(area): return [] # A full-screen menu owns the whole surface.
	var result: Array = []
	for entry: Dictionary in entries:
		var rect := _place(entry.desired, area, obstacles)
		if not rect.has_area(): continue # Original portraits / selection panel remain available.
		var unit = entry.unit
		obstacles.append(rect.grow(GAP))
		result.append({"entity_id": unit.entity_id, "kind": entry.kind, "rect": rect, "anchor": entry.anchor,
			"status": unit.story_label() if entry.kind == "person" else "",
			"text": Localize.text(unit.display_name), "health": clampf(unit.hp / unit.max_hp, 0, 1),
			"friendly": unit.faction == unit.FACTION_LIANG, "hostile": unit.faction == unit.FACTION_GUAN, "priority": entry.priority,
			"selected": unit.selected, "inspected": unit.inspected})
	return result

func _style(border: Color) -> StyleBoxFlat:
	var key := border.to_rgba32()
	if not _styles.has(key): _styles[key] = UITheme.panel_style(Color(0.09, 0.07, 0.05, 0.92), border, 1, 4)
	return _styles[key]

func _draw() -> void:
	last_layout = compute_layout()
	for item: Dictionary in last_layout:
		var rect: Rect2 = item.rect
		var anchor: Vector2 = item.anchor
		var nearest := Vector2(clampf(anchor.x, rect.position.x, rect.end.x), clampf(anchor.y, rect.position.y, rect.end.y))
		var normal_border: Color = UITheme.COPPER if item.kind == "person" and item.friendly else UITheme.WARNING
		var border := UITheme.COPPER_LIGHT if item.selected else (Color("ff8866") if item.inspected else normal_border)
		draw_line(anchor, nearest, Color(border, 0.65), 1.0)
		draw_style_box(_style(border), rect)
		var name_color: Color = (Color("ffd866") if item.friendly else Color("ff8866")) if item.kind == "person" else UITheme.PAPER
		UITheme.draw_compact_label(self, ThemeDB.fallback_font, rect.position + Vector2(6, 16), item.text, CARD_SIZE.x - 12, 13, name_color)
		if not item.status.is_empty():
			UITheme.draw_compact_label(self, ThemeDB.fallback_font, rect.position + Vector2(6, 29), item.status, CARD_SIZE.x - 12, 11, Color(0.96, 0.83, 0.53))
		elif Settings.show_healthbars:
			var bar := Rect2(rect.position + Vector2(8, 24), Vector2(CARD_SIZE.x - 16, 5))
			draw_rect(bar, UITheme.INK)
			var health_color := Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.3), item.health)
			if item.kind == "person" and item.hostile: health_color = Color(0.6, 0.1, 0.1).lerp(Color(0.9, 0.55, 0.2), item.health)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(item.health), bar.size.y)), health_color)
