extends Unit

# Fixture-only resolver. Physics, orders, facing and body rendering are inherited.
# This deliberately does not establish production ArtDB/campaign routing.
var candidate_frames: Dictionary = {}
var sampled_state := "idle"
var sampled_index := 0

func load_candidate(character: String) -> void:
	for direction in ["se", "sw", "ne", "nw"]:
		for state in ["idle", "walk"]:
			var sf: SpriteFrames = load("res://assets/anim/" + character + "_" + state + "_" + direction + ".tres")
			assert(sf != null)
			candidate_frames[state + "_" + direction] = sf

func _anim_frame_for_state(_fallback: Texture2D) -> Texture2D:
	_real_frames = true
	_frame_directional = true
	sampled_state = "walk" if _move_blend > 0.3 else "idle"
	var sf: SpriteFrames = candidate_frames[sampled_state + "_" + animation_direction]
	var phase := fposmod(_anim_t, TAU) / TAU if sampled_state == "walk" else 0.0
	sampled_index = int(phase * sf.get_frame_count(&"default")) % sf.get_frame_count(&"default")
	return sf.get_frame_texture(&"default", sampled_index)
