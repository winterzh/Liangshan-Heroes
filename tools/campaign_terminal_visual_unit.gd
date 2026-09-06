extends "res://scripts/unit.gd"
## Records the texture returned by the real draw fallback; does not replace it.
var terminal_rest_source := ""
var terminal_rest_calls := 0

func _rest_frame(fallback: Texture2D) -> Texture2D:
	var frame := super._rest_frame(fallback)
	if _dying:
		terminal_rest_calls += 1
		terminal_rest_source = frame.atlas.resource_path if frame is AtlasTexture else frame.resource_path
	return frame
