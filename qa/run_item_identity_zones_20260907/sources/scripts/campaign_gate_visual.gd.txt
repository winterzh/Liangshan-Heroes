extends RefCounted
## Terrain2 gate source: the stone wall feet, not the transparent square edges.
## Map both feet to the stockade endpoints; retain upright poles and roof.
const SOURCE_LEFT := Vector2(0.04, 0.64)
const SOURCE_RIGHT := Vector2(0.96, 0.925)

## This native facing has timber flanks matching the manor's palisade.
## Source coordinates refer to the two end-post stone feet in the untouched PNG.
const ZHU_NATIVE_VARIANT := "zhu_gate_native_20260906"
const ZHU_NATIVE_PATH := "res://assets/campaign/objects/zhu_gate_native_20260906_default.png"
const ZHU_NATIVE_LEFT := Vector2(1322.0/1536.0,647.0/1024.0)
const ZHU_NATIVE_RIGHT := Vector2(230.0/1536.0,935.0/1024.0)

static func configure_zhujiazhuang(unit) -> void:
	unit.set_meta("campaign_gate_wall_span",Vector2(0,128))
	# Keep the matching legacy texture/anchors together if an incomplete checkout
	# lacks the native asset; validation still reports that checkout as incomplete.
	if not ResourceLoader.exists(ZHU_NATIVE_PATH): return
	unit.art_variant=ZHU_NATIVE_VARIANT
	unit.set_meta("campaign_gate_source_left",ZHU_NATIVE_LEFT)
	unit.set_meta("campaign_gate_source_right",ZHU_NATIVE_RIGHT)
	unit.set_meta("campaign_gate_visual_height",180.0)
	unit.set_meta("campaign_gate_texture_tint",Color(0.60,0.70,0.83))

static func source_tint(unit, tint: Color) -> Color:
	# Texture-only calibration: health bars, labels and selection stay readable.
	return tint*unit.get_meta("campaign_gate_texture_tint",Color.WHITE)

static func enabled(unit) -> bool:
	return unit.is_building and unit.has_meta("campaign_gate_wall_span")

static func source_transform(unit, texture_size: Vector2, vertical_axis := Vector2.DOWN) -> Transform2D:
	var span: Vector2 = unit.get_meta("campaign_gate_wall_span", Vector2.ZERO)
	var end: Vector2 = GameMap.ISO * span * 0.5
	var left: Vector2 = unit.get_meta("campaign_gate_source_left",SOURCE_LEFT) * texture_size
	var right: Vector2 = unit.get_meta("campaign_gate_source_right",SOURCE_RIGHT) * texture_size
	var height: float = unit.get_meta("campaign_gate_visual_height",GameMap.building_visual_px(GameMap.footprint_half_for(unit.radius)))
	var y_axis := vertical_axis * height / texture_size.y
	var x_axis := (end * 2.0 - y_axis * (right.y - left.y)) / (right.x - left.x)
	return Transform2D(x_axis, y_axis, -end - x_axis * left.x - y_axis * left.y)

## The existing Daming source depicts an open arch. Draw its closed timber
## leaves in the same source coordinates so a blocked gate reads as closed.
## This is an explicit per-building state detail, never a bitmap replacement.
static func draw_closed_leaf(unit, texture_size: Vector2, tint: Color) -> void:
	if not bool(unit.get_meta("campaign_gate_closed_leaf",false)): return
	var scale := texture_size / 512.0
	var polygon := PackedVector2Array([Vector2(274,310),Vector2(278,293),Vector2(292,280),Vector2(309,273),Vector2(324,277),Vector2(336,287),Vector2(338,366),Vector2(274,391)])
	for i in range(polygon.size()): polygon[i]*=scale
	unit.draw_colored_polygon(polygon,Color("46392b")*tint)
	for plank in [[281,292,388],[289,284,385],[297,279,382],[306,275,379],[315,277,376],[324,282,372],[332,288,369]]:
		unit.draw_line(Vector2(plank[0],plank[1])*scale,Vector2(plank[0],plank[2])*scale,Color("30291f")*tint,1.2)
	for y in [323,360]:
		unit.draw_line(Vector2(278,y)*scale,Vector2(335,y-21)*scale,Color("292823")*tint,4)
		for x in [284,299,316,330]:
			unit.draw_circle(Vector2(x,y-(x-278)*21.0/57.0)*scale,1.5,Color("8b8065")*tint)
