extends Node2D
## Visual state follows the actual navigation cell; no independent cosmetic open flag.
var map: GameMap
var caption := "偏门"
var object_key := ""
var _open := false

func _process(_delta: float) -> void:
	var opened := map.is_open_world(position,"land")
	if opened!=_open:
		_open=opened
		queue_redraw()

func _draw() -> void:
	draw_set_transform_matrix(GameMap.ISO_INV)
	if object_key!="":
		var texture := Art.campaign_object_texture(object_key,"open" if _open else "default")
		if texture!=null:
			draw_texture_rect(texture,Rect2(-48,-96*0.82,96,96),false)
			draw_string(ThemeDB.fallback_font,Vector2(-14,-78),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("dfc990"))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			return
	var left := Vector2(-16,-8)
	var right := Vector2(16,8)
	var height := Vector2(0,64)
	for base in [left,right]:
		draw_rect(Rect2(base-height-Vector2(3,0),Vector2(6,67)),Color("89816b"))
	draw_line(left-height,right-height,Color("aba28a"),7.0,true)
	if _open:
		for base in [left,right]:
			var inward := Vector2(18,-9)
			draw_colored_polygon(PackedVector2Array([base,base+inward,base+inward-height,base-height]),Color("503d29"))
	else:
		draw_colored_polygon(PackedVector2Array([left,right,right-height,left-height]),Color("58432d"))
		for i in range(1,6):
			var p := left.lerp(right,float(i)/6.0)
			draw_line(p,p-height,Color("392f22"),1.1,true)
		draw_line(left-height*0.42,right-height*0.42,Color("957446"),3.0,true)
	draw_string(ThemeDB.fallback_font,Vector2(-14,-72),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("dfc990"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func body_overlaps(foot: Vector2) -> bool:
	return Rect2(-22,-78,46,90).intersects(Rect2(foot+Vector2(-12,-38),Vector2(24,40)))
