extends Unit
## Diagnostic only. Uses real ordinary definitions and inherited Unit movement/draw.
## Only the candidate idle frame is substituted; walk/attack remain production Art.
var use_candidate_idle := false
var candidate_idle: Dictionary = {}
var sampled_frame: Texture2D
var sampled_candidate_idle := false
var sampled_state := "idle"

func load_idle_family(family: String) -> void:
	for direction in ["se","sw","ne","nw"]:
		var frames: SpriteFrames = load("res://assets/anim/"+family+"_idle_"+direction+".tres")
		assert(frames!=null and frames.get_frame_count(&"default")==1)
		candidate_idle[direction]=frames.get_frame_texture(&"default",0)

func _anim_frame_for_state(fallback: Texture2D) -> Texture2D:
	sampled_state="walk" if _move_blend>0.3 else "idle"
	sampled_candidate_idle=use_candidate_idle and sampled_state=="idle" and art_variant.is_empty() and not _dying and story_outcome.is_empty() and _flash<=0 and _lunge<=0
	if sampled_candidate_idle:
		_frame_directional=true;_real_frames=true
		sampled_frame=candidate_idle[animation_direction]
	else:
		sampled_frame=super._anim_frame_for_state(fallback)
	return sampled_frame
