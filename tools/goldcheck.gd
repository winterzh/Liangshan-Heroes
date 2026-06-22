extends SceneTree
func _init() -> void:
	var GameMapC = load("res://scripts/game_map.gd")
	var lvl = load("res://scripts/levels/skirmish.gd").new()
	var map = GameMapC.new()
	get_root().add_child(map)
	map.init_map(lvl.map_w(), lvl.map_h(), lvl.map_theme(), lvl.map_base())
	lvl.paint_map(map)
	map.bake()
	var hall := Vector2i(16, 46)
	for cand in [Vector2i(10,44),Vector2i(8,43),Vector2i(7,43),Vector2i(6,42),Vector2i(8,42),Vector2i(9,42),Vector2i(7,45),Vector2i(6,45),Vector2i(5,44),Vector2i(8,44)]:
		var d: float = sqrt(float((hall.x-cand.x)*(hall.x-cand.x)+(hall.y-cand.y)*(hall.y-cand.y)))
		var delta: Vector2i = cand - hall
		var nopen: int = 0
		for dx in [-1,0,1]:
			for dy in [-1,0,1]:
				if map.is_open_cell(cand+Vector2i(dx,dy)): nopen += 1
		print("GC (%d,%d) self_open=%s nbr=%d/9 dist=%.1f screen=(%d,%d)" % [cand.x,cand.y,map.is_open_cell(cand),nopen,d,delta.x-delta.y,delta.x+delta.y])
	quit()
