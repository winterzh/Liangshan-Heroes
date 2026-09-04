extends Node2D
## Short, generated-asset event overlay. It carries no collision or damage.
var texture: Texture2D
var size := 110.0
var foot := 0.82
var life := 2.0
var duration := 2.0
func _process(delta: float) -> void:
	if duration < 0:
		set_process(false)
		return
	life-=delta
	if life<=0: queue_free(); return
	queue_redraw()
func _draw() -> void:
	if texture==null: return
	draw_set_transform_matrix(GameMap.ISO_INV)
	draw_texture_rect(texture,Rect2(-size*0.5,-size*foot,size,size),false,Color(1,1,1,1.0 if duration<0 else minf(1.0,life/0.35)))
