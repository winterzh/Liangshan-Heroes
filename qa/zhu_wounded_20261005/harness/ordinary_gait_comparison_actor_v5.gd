extends Unit
## Detached diagnostic adapter: original Unit movement/draw; candidate idle/walk.
var use_candidate_family := false
var candidate_frames: Dictionary = {}
var sampled_frame: Texture2D
var sampled_candidate_family := false
var sampled_state := "idle"
var sampled_frame_index := 0

func load_gait_family(family: String) -> void:
	for state in ["idle","walk"]:
		for direction in ["se","sw","ne","nw"]:
			var frames: SpriteFrames = load("res://assets/anim/"+family+"_"+state+"_"+direction+".tres")
			assert(frames!=null and frames.get_frame_count(&"default")== (4 if state=="walk" else 1))
			var textures: Array = []
			for i in range(frames.get_frame_count(&"default")):
				textures.append(frames.get_frame_texture(&"default",i))
			candidate_frames[state+"_"+direction]=textures

func _anim_frame_for_state(fallback: Texture2D) -> Texture2D:
	sampled_state="walk" if _move_blend>0.3 else "idle"
	sampled_candidate_family=use_candidate_family and art_variant.is_empty() and not _dying and story_outcome.is_empty() and _flash<=0 and _lunge<=0
	if sampled_candidate_family:
		_frame_directional=true
		_real_frames=true
		var textures: Array = candidate_frames[sampled_state+"_"+animation_direction]
		var phase := fposmod(_anim_t,TAU)/TAU if sampled_state=="walk" else 0.0
		sampled_frame_index=int(phase*textures.size())%textures.size()
		sampled_frame=textures[sampled_frame_index]
	else:
		sampled_frame_index=-1
		sampled_frame=super._anim_frame_for_state(fallback)
	return sampled_frame
