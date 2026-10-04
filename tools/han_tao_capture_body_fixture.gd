extends "res://scripts/unit.gd"
## Loaded dynamically after autoloads exist. Display-only, never a mission actor.
## Use the production body draw without labels in the explicit review matrix.
func _draw() -> void:
	_draw_sprite_animated(get_tree().root.get_node("Art").unit_texture(key), Color.WHITE, 0.0)
