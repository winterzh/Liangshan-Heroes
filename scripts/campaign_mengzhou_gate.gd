extends Node2D
## Mengzhou's east gate faces the X-axis road. Reuse the untouched city-gate
## bitmap in its native facing; only its ground feet receive an axis correction.
const TEXTURE_PATH := "res://assets/campaign/objects/daming_south_gate_default.png"
const SOURCE_LEFT := Vector2(0.22,0.822)
const SOURCE_RIGHT := Vector2(0.943,0.635)
const WORLD_WALL_SPAN := Vector2(0,-128)
const VISUAL_HEIGHT := 256.0
var tex: Texture2D = preload(TEXTURE_PATH)

func _ready() -> void:
	var shadow := GroundShadow.new()
	shadow.name = "AlignedGroundShadow"
	shadow.gate = self
	shadow.z_as_relative = false
	shadow.z_index = 0
	add_child(shadow)

func source_transform(vertical_axis := Vector2.DOWN) -> Transform2D:
	var texture_size := tex.get_size()
	var left := SOURCE_LEFT*texture_size
	var right := SOURCE_RIGHT*texture_size
	var end := GameMap.ISO*WORLD_WALL_SPAN*0.5
	var y_axis := vertical_axis*VISUAL_HEIGHT/texture_size.y
	var x_axis := (end*2.0-y_axis*(right.y-left.y))/(right.x-left.x)
	return Transform2D(x_axis,y_axis,-end-x_axis*left.x-y_axis*left.y)

func _draw() -> void:
	draw_set_transform_matrix(GameMap.ISO_INV*source_transform())
	draw_texture_rect(tex,Rect2(Vector2.ZERO,tex.get_size()),false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_ground_shadow(canvas: Node2D) -> void:
	if not WorldShadow.enabled(): return
	# Both ends stay at the real wall feet when the roof collapses onto ground.
	# A separate ground layer keeps the long cast behind people on the road.
	canvas.draw_set_transform_matrix(GameMap.ISO_INV*source_transform(WorldShadow.CAST_SHEAR))
	canvas.draw_texture_rect(tex,Rect2(Vector2.ZERO,tex.get_size()),false,Color(0.03,0.06,0.04,0.22))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func body_overlaps(foot: Vector2) -> bool:
	var gate_transform := source_transform()
	var bounds := Rect2(gate_transform*Vector2.ZERO,Vector2.ZERO)
	for corner in [Vector2(tex.get_width(),0),tex.get_size(),Vector2(0,tex.get_height())]:
		bounds=bounds.expand(gate_transform*corner)
	return bounds.intersects(Rect2(foot+Vector2(-12,-38),Vector2(24,40)))

class GroundShadow extends Node2D:
	var gate
	func _draw() -> void:
		gate.draw_ground_shadow(self)
