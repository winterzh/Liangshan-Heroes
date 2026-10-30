extends Node2D
## Screen-space captions for delivered short-chapter tribute carts only.
## The world Unit keeps its real position, hit target, health and selection.
const Ground = preload("res://scripts/campaign_tribute_cart_visual.gd")
const NODE_NAME := "_TributeCartCaptions"
const CARD_SIZE := Vector2(116, 34)
const GAP := 6.0
var _battle: WeakRef
var last_layout: Array = [] # Rendered rectangles/IDs only, never saved Unit state.

static func owns(unit) -> bool:
	if not Ground.layered(unit): return false
	var index: int = unit.battle.level.bundles.find(unit)
	return unit.battle.level._cargo_was_delivered(unit.battle, index)

static func wants_info(unit) -> bool:
	return owns(unit) and unit.hp > 0.0 and unit.is_visible_in_tree() \
		and (unit.selected or unit.inspected or unit.hp < unit.max_hp)

static func ensure(b) -> void:
	if not is_instance_valid(b.hud) or b.hud.has_node(NODE_NAME): return
	var overlay = load("res://scripts/campaign_cart_captions.gd").new()
	overlay.name = NODE_NAME
	overlay._battle = weakref(b)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	b.hud.add_child(overlay)

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

func _obstacles(b) -> Array:
	var result: Array = []
	for actor in b.units:
		if not is_instance_valid(actor) or not actor.is_hero or actor._dying or not actor.is_visible_in_tree(): continue
		var body: float = actor.radius * 3.7 * actor.visual_scale
		var bar: float = actor._campaign_tribute_label_y(-actor.radius * 3.3 * actor.visual_scale)
		var width: float = maxf(body, minf(100, ThemeDB.fallback_font.get_string_size(Localize.text(actor.display_name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)) + 6.0
		result.append((_to_overlay(actor) * Rect2(-width * 0.5, bar - 22, width, -bar + 32)).grow(GAP))
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
	for obstacle: Rect2 in obstacles:
		if rect.grow(GAP).intersects(obstacle): return false
	return true

func _place(desired: Vector2, area: Rect2, obstacles: Array) -> Rect2:
	var initial := Rect2(_fit(desired, area), CARD_SIZE)
	if _free(initial, obstacles): return initial
	var candidates: Array[Vector2] = []
	for obstacle: Rect2 in obstacles:
		for point: Vector2 in [Vector2(desired.x, obstacle.position.y - CARD_SIZE.y - GAP * 2),
			Vector2(desired.x, obstacle.end.y + GAP * 2), Vector2(obstacle.position.x - CARD_SIZE.x - GAP * 2, desired.y),
			Vector2(obstacle.end.x + GAP * 2, desired.y)]: candidates.append(_fit(point, area))
	# Finite fallback grid, including the right/bottom edges, for multi-selection.
	for y in range(int(area.position.y), int(area.end.y - CARD_SIZE.y) + int(CARD_SIZE.y + GAP), int(CARD_SIZE.y + GAP)):
		for x in range(int(area.position.x), int(area.end.x - CARD_SIZE.x) + int(CARD_SIZE.x + GAP), int(CARD_SIZE.x + GAP)):
			candidates.append(_fit(Vector2(x, y), area))
	var best := Rect2()
	var distance := INF
	for point: Vector2 in candidates:
		var rect := Rect2(point, CARD_SIZE)
		var score: float = point.distance_squared_to(desired)
		if score < distance and _free(rect, obstacles): best = rect; distance = score
	return best # No overlapping fallback: the unchanged information panel remains available.

func compute_layout() -> Array:
	var b = _battle.get_ref() if _battle != null else null
	if not is_instance_valid(b) or not is_instance_valid(b.level) or b.level.get_script().resource_path != "res://scripts/levels/level1_huangnigang_short.gd": return []
	var area: Rect2 = get_global_transform_with_canvas().affine_inverse() * get_viewport_rect().grow(-8)
	if area.size.x < CARD_SIZE.x or area.size.y < CARD_SIZE.y: return []
	# Most frames have no requested cart details. Avoid rebuilding obstacles then.
	var carts: Array = b.level.bundles.filter(func(cart): return is_instance_valid(cart) and wants_info(cart))
	if carts.is_empty(): return []
	var obstacles := _obstacles(b)
	var result: Array = []
	for cart in carts: # Stable original cargo order, independent of selection order.
		var tr := _to_overlay(cart)
		if not area.grow(24).has_point(tr.origin): continue
		var texture: Texture2D = Art.campaign_tribute_cart_texture(cart.animation_direction)
		var size: float = Ground.visual_size(texture, cart.visual_scale)
		var bar: float = size * (float(texture.get_meta("visible_top", 0.0)) - 0.82) - 8.0
		var desired: Vector2 = tr * Vector2(0, bar) - Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
		var rect := _place(desired, area, obstacles)
		if not rect.has_area(): continue
		obstacles.append(rect.grow(GAP))
		result.append({"entity_id": cart.entity_id, "rect": rect, "anchor": tr.origin,
			"text": Localize.text(cart.display_name), "health": clampf(cart.hp / cart.max_hp, 0, 1),
			"selected": cart.selected, "inspected": cart.inspected})
	return result

func _draw() -> void:
	last_layout = compute_layout()
	for item: Dictionary in last_layout:
		var rect: Rect2 = item.rect
		var anchor: Vector2 = item.anchor
		var nearest := Vector2(clampf(anchor.x, rect.position.x, rect.end.x), clampf(anchor.y, rect.position.y, rect.end.y))
		var border := UITheme.COPPER_LIGHT if item.selected else (Color("ff8866") if item.inspected else UITheme.WARNING)
		draw_line(anchor, nearest, Color(border, 0.65), 1.0)
		draw_style_box(UITheme.panel_style(Color(0.09, 0.07, 0.05, 0.92), border, 1, 4), rect)
		UITheme.draw_compact_label(self, ThemeDB.fallback_font, rect.position + Vector2(6, 16), item.text, CARD_SIZE.x - 12, 13, UITheme.PAPER)
		if Settings.show_healthbars:
			var bar := Rect2(rect.position + Vector2(8, 24), Vector2(CARD_SIZE.x - 16, 5))
			draw_rect(bar, UITheme.INK)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(item.health), bar.size.y)), Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.3), item.health))
