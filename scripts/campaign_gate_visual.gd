extends RefCounted
## Terrain2 gate source: the stone wall feet, not the transparent square edges.
## Map both feet to the stockade endpoints; retain upright poles and roof.
const SOURCE_LEFT := Vector2(0.04, 0.64)
const SOURCE_RIGHT := Vector2(0.96, 0.925)

static func enabled(unit) -> bool:
	return unit.is_building and unit.has_meta("campaign_gate_wall_span")

static func source_transform(unit, texture_size: Vector2, vertical_axis := Vector2.DOWN) -> Transform2D:
	var span: Vector2 = unit.get_meta("campaign_gate_wall_span", Vector2.ZERO)
	var end: Vector2 = GameMap.ISO * span * 0.5
	var left := SOURCE_LEFT * texture_size
	var right := SOURCE_RIGHT * texture_size
	var height := GameMap.building_visual_px(GameMap.footprint_half_for(unit.radius))
	var y_axis := vertical_axis * height / texture_size.y
	var x_axis := (end * 2.0 - y_axis * (right.y - left.y)) / (right.x - left.x)
	return Transform2D(x_axis, y_axis, -end - x_axis * left.x - y_axis * left.y)
