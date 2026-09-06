class_name CampaignFlagOverlay
extends Node2D
## 旗文由 CampaignArt 的白名单决定；本层不接受任意字符串，避免把单位名、
## 地名或生成图中的错字直接当作旗号。它只绘制文字和可读底板，不改任何 PNG。

const CampaignArt := preload("res://scripts/campaign_art.gd")

var _static_marker := ""
var _visual_size := 64.0
var _foot := 0.8
var _static_level_id := ""
var _static_decor_key := ""
var _static_rect_override: Array = []
var _static_text_only := false


func configure_static_marker(marker: String, visual_size: float, foot := 0.8,
		level_id := "", decor_key := "", normalized_rect_override: Array = [],
		text_only := false) -> bool:
	if CampaignArt.static_flag_route(marker, level_id, decor_key).is_empty():
		# 复用节点时遇到未知 marker 必须清空旧旗，不能保留上一处的原著文字。
		_static_marker = ""
		_static_level_id = ""
		_static_decor_key = ""
		_static_rect_override.clear()
		_static_text_only = false
		queue_redraw()
		return false
	_static_marker = marker
	_visual_size = maxf(visual_size, 1.0)
	_foot = clampf(foot, 0.0, 1.0)
	_static_level_id = level_id
	_static_decor_key = decor_key
	_static_rect_override = normalized_rect_override.duplicate()
	_static_text_only = text_only
	queue_redraw()
	return true


func static_marker() -> String:
	return _static_marker


func overlay_id() -> String:
	return CampaignArt.static_flag_overlay_id(_static_marker)


func _draw() -> void:
	if _static_marker.is_empty():
		return
	draw_set_transform_matrix(GameMap.ISO_INV)
	draw_static_marker(self, _static_marker, _visual_size, _foot, 1.0,
		_static_level_id, _static_decor_key, _static_rect_override, _static_text_only)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 动态入口只由 Unit 的真实单位键、战役物件键和剧情 context 同时驱动。
## 不提供 marker + 任意 Rect2 的通用入口：那会让未来调用方把原著旗文挪到任何船上。
## exact_directional_source 来自 Art 实际加载结果，避免高俅旗在旧式镜像资源上出现镜像文字。
static func draw_dynamic_unit(canvas: CanvasItem, unit_key: String, object_key: String, context: String,
		state: String, direction: String, visual_size: float, exact_directional_source: bool,
		alpha := 1.0) -> bool:
	var route := CampaignArt.dynamic_flag_route(unit_key, object_key, context)
	if route.is_empty() or direction not in CampaignArt.DIRECTIONS:
		return false
	if bool(route.get("require_exact_directional_art", false)) and not exact_directional_source:
		return false
	var spec := CampaignArt.flag_text_spec(String(route.get("overlay_id", "")))
	if not _state_allowed(spec, state):
		return false
	match String(spec.get("layout", "single")):
		"paired_only":
			return _draw_vanguard_pair(canvas, spec, state, direction, visual_size, alpha)
		"single", "vertical":
			return _draw_dynamic_single(canvas, spec, direction, visual_size, alpha)
	return false


## 静态布景入口：只接受地点 marker，不把现有通用 banner 自动替换成任何旗号。
static func draw_static_marker(canvas: CanvasItem, marker: String, visual_size: float,
		foot := 0.8, alpha := 1.0, level_id := "", decor_key := "",
		normalized_rect_override: Array = [], text_only := false) -> bool:
	var route := CampaignArt.static_flag_route(marker, level_id, decor_key)
	if route.is_empty():
		return false
	var id := String(route.get("overlay_id", ""))
	var spec := CampaignArt.flag_text_spec(id)
	var normalized: Array = normalized_rect_override if normalized_rect_override.size()==4 else spec.get("static_rect", [])
	if normalized.size() != 4:
		return false
	var rect := _normalized_rect(normalized, visual_size, foot)
	return _draw_text_only_spec(canvas,spec,rect,alpha) if text_only else _draw_spec(canvas,spec,rect,alpha)


static func _state_allowed(spec: Dictionary, state: String) -> bool:
	var states: Array = spec.get("states", [])
	return states.is_empty() or state in states


static func _normalized_rect(values: Array, visual_size: float, foot: float) -> Rect2:
	var origin := Vector2(-visual_size * 0.5, -visual_size * foot)
	return Rect2(origin + Vector2(float(values[0]), float(values[1])) * visual_size,
		Vector2(float(values[2]), float(values[3])) * visual_size)


static func _draw_dynamic_single(canvas: CanvasItem, spec: Dictionary, direction: String,
		visual_size: float, alpha: float) -> bool:
	var rects: Dictionary = spec.get("dynamic_rects", {})
	var normalized: Array = rects.get(direction, [])
	if normalized.size() != 4:
		return false
	var flag_rect := _normalized_rect(normalized, visual_size, 0.82)
	return _draw_text_only_spec(canvas, spec, flag_rect, alpha) if bool(spec.get("text_only", false)) else _draw_spec(canvas, spec, flag_rect, alpha)


## 第八十回的先锋头船只能走这里：两个固定旗面由同一条十四字白名单排版，
## 逗号仅作为两面旗的排版断行，绝不建立个人旗或可复用动态 marker。
static func _draw_vanguard_pair(canvas: CanvasItem, spec: Dictionary, state: String, direction: String,
		visual_size: float, alpha: float) -> bool:
	var rects: Dictionary = spec.get("dynamic_pair_rects", {})
	var state_rects: Dictionary = rects.get(state, {})
	var normalized_pair = state_rects.get(direction, [])
	if not normalized_pair is Array or normalized_pair.size() != 2:
		return false
	var lines := String(spec.get("text", "")).split("，", false)
	if lines.size() != 2 or lines[0].is_empty() or lines[1].is_empty():
		return false
	for index in range(2):
		var normalized = normalized_pair[index]
		if not normalized is Array or normalized.size() != 4:
			return false
		_draw_vanguard_text(canvas, String(lines[index]), _normalized_rect(normalized, visual_size, 0.82), alpha)
	return true


## 先锋头船的旗布来自网页端生成的真四向 PNG。本函数只把白名单中的文字写到
## 已审过的空白旗心，绝不在本地重画、遮盖或修补旗布。
static func _draw_vanguard_text(canvas: CanvasItem, text: String, flag_rect: Rect2, alpha: float) -> void:
	if flag_rect.size.x < 1.0 or flag_rect.size.y < 1.0:
		return
	var ink := Color("fae7bc")
	ink.a = alpha
	var font := ThemeDB.fallback_font
	if font != null:
		# 最窄的破损旗面仍要容纳七字；本地只降低字级，不绘制额外底板或边框。
		_draw_vertical(canvas, font, text, flag_rect, ink, alpha, 3, 0)


static func _draw_spec(canvas: CanvasItem, spec: Dictionary, flag_rect: Rect2, alpha: float) -> bool:
	var text := String(spec.get("text", ""))
	if text.is_empty() or flag_rect.size.x < 1.0 or flag_rect.size.y < 1.0 or alpha <= 0.0:
		return false
	var ground := Color(String(spec.get("ground_color", "1c2023")))
	ground.a = alpha
	var trim := Color(String(spec.get("trim_color", "c79845")))
	trim.a = alpha
	var ink := Color(String(spec.get("ink_color", "f2ddb0")))
	ink.a = alpha
	canvas.draw_rect(flag_rect, ground, true)
	canvas.draw_rect(flag_rect, trim, false, maxf(1.0, flag_rect.size.x * 0.055), true)
	var font := ThemeDB.fallback_font
	if font == null:
		return false
	if String(spec.get("layout", "single")) == "vertical":
		_draw_vertical(canvas, font, text, flag_rect, ink, alpha)
	else:
		_draw_centered(canvas, font, text, flag_rect, ink, alpha)
	return true


## Accepted blank flag bitmaps already contain cloth and trim. This path adds
## only the verified book text to its source-SHA-bound measured rectangle.
static func _draw_text_only_spec(canvas: CanvasItem, spec: Dictionary,
		flag_rect: Rect2, alpha: float) -> bool:
	var text := String(spec.get("text", ""))
	if text.is_empty() or flag_rect.size.x<1.0 or flag_rect.size.y<1.0 or alpha<=0.0:
		return false
	var font := ThemeDB.fallback_font
	if font==null: return false
	var ink := Color(String(spec.get("ink_color","f2ddb0")))
	ink.a=alpha
	if String(spec.get("layout","single"))=="vertical":
		_draw_vertical(canvas,font,text,flag_rect,ink,alpha)
	else:
		_draw_centered(canvas,font,text,flag_rect,ink,alpha)
	return true


static func _draw_centered(canvas: CanvasItem, font: Font, text: String, rect: Rect2,
		ink: Color, alpha: float) -> void:
	var font_size := maxi(8, int(minf(rect.size.x * 0.78, rect.size.y * 0.72)))
	var baseline := rect.position.y + (rect.size.y + float(font_size)) * 0.5 - 1.0
	var outline := Color(0.06, 0.05, 0.04, alpha * 0.92)
	canvas.draw_string_outline(font, Vector2(rect.position.x, baseline), text,
		HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), font_size, maxi(1, int(font_size * 0.11)), outline)
	canvas.draw_string(font, Vector2(rect.position.x, baseline), text,
		HORIZONTAL_ALIGNMENT_CENTER, int(rect.size.x), font_size, ink)


static func _draw_vertical(canvas: CanvasItem, font: Font, text: String, rect: Rect2,
		ink: Color, alpha: float, minimum_font_size := 7, forced_outline_width := -1) -> void:
	var glyphs: Array = []
	for glyph in text:
		glyphs.append(glyph)
	if glyphs.is_empty():
		return
	var font_size := maxi(minimum_font_size, int(minf(rect.size.x * 0.76, rect.size.y / (glyphs.size() * 1.10))))
	var line := float(font_size) * 1.02
	var start := rect.position.y + (rect.size.y - line * glyphs.size()) * 0.5 + font_size
	var outline := Color(0.06, 0.05, 0.04, alpha * 0.90)
	var outline_width := maxi(0, forced_outline_width if forced_outline_width >= 0 else int(font_size * 0.10))
	for index in glyphs.size():
		var at := Vector2(rect.position.x, start + line * index)
		canvas.draw_string_outline(font, at, String(glyphs[index]), HORIZONTAL_ALIGNMENT_CENTER,
			int(rect.size.x), font_size, outline_width, outline)
		canvas.draw_string(font, at, String(glyphs[index]), HORIZONTAL_ALIGNMENT_CENTER,
			int(rect.size.x), font_size, ink)
