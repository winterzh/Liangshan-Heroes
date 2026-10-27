extends RefCounted
## Placement-only corrections for the reviewed 256px official top-four strips.
## Source: qa/skirmish_direction4_actions_20260905/staging/candidate_manifest.json.
## Preserve all source pixels; never reflect/rotate art.
## Live poses undo canvas-fit shifts. Death poses have different anatomical
## anchors, so align their visible silhouette centre/contact to the same ground.
## .gd is preloaded so export does not depend on QA/manifest JSON inclusion.
const RECIPES := {
	"idle": ["idle"], "walk": ["idle", "walk_step"],
	"attack": ["idle", "attack_strike", "idle"],
	"death": ["idle", "death_fall", "death_down", "death_down"],
}
const FIT_SHIFTS := {
	"guan_dao": {
		"walk_step": [Vector2.ZERO, Vector2.ZERO, Vector2(-5,0), Vector2.ZERO],
		"attack_strike": [Vector2.ZERO, Vector2(12,0), Vector2.ZERO, Vector2.ZERO],
		"death_fall": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
		"death_down": [Vector2(56,0), Vector2(9,0), Vector2(-9,0), Vector2(15,0)],
	},
	"guan_gong": {
		# SW revision keeps weak alpha pixels outside the visible figure intact.
		# Its fixed virtual ground pivot therefore needs a 25px canvas-fit undo.
		"idle": [Vector2.ZERO, Vector2(0,25), Vector2.ZERO, Vector2.ZERO],
		"walk_step": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
		"attack_strike": [Vector2(0,7), Vector2.ZERO, Vector2(-9,8), Vector2(0,19)],
		"death_fall": [Vector2(-42,0), Vector2(57,0), Vector2(-55,0), Vector2(50,0)],
		"death_down": [Vector2(38,-9), Vector2(5,0), Vector2(-3,0), Vector2(29,0)],
	},
	"guan_jingqi": {
		"walk_step": [Vector2.ZERO, Vector2(-14,0), Vector2.ZERO, Vector2.ZERO],
		"attack_strike": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
		"death_fall": [Vector2(1,0), Vector2.ZERO, Vector2.ZERO, Vector2(35,0)],
		"death_down": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
	},
	"guan_qi": {
		"walk_step": [Vector2.ZERO, Vector2.ZERO, Vector2(-16,0), Vector2.ZERO],
		"attack_strike": [Vector2(15,0), Vector2.ZERO, Vector2(-13,0), Vector2(5,0)],
		"death_fall": [Vector2(15,0), Vector2(-3,0), Vector2(-37,0), Vector2(11,0)],
		"death_down": [Vector2(25,0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO],
	},
}

## Pixel measurements of alpha > 15/255 in the committed 256px death frames.
## Centre x=128, lowest visible y=210. Translation only; no pixel modification.
## This prevents foot/hoof -> lowest-body anchor changes becoming a sideways jump.
const DEATH_DRAW_OFFSETS := {
	"guan_dao": {
		"death_fall": [Vector2(-34,-2), Vector2(39,-2), Vector2(-25,-2), Vector2(40,-3)],
		"death_down": [Vector2(0,-2), Vector2(40,-21), Vector2(-17,-2), Vector2(36,-2)],
	},
	"guan_gong": {
		"death_fall": [Vector2(-29,-3), Vector2(26,-3), Vector2(-24,-2), Vector2(34,-3)],
		"death_down": [Vector2(20,-41), Vector2(21,-14), Vector2(-25,-2), Vector2(26,-3)],
	},
	"guan_jingqi": {
		"death_fall": [Vector2(31,-2), Vector2(2,-1), Vector2(-27,-2), Vector2(44,-1)],
		"death_down": [Vector2(6,-27), Vector2(35,-24), Vector2(-13,-2), Vector2(-18,-1)],
	},
	"guan_qi": {
		"death_fall": [Vector2(27,-2), Vector2(-25,-1), Vector2(-27,-2), Vector2(32,-2)],
		"death_down": [Vector2(31,-37), Vector2(-5,-40), Vector2(-21,-2), Vector2(-5,-2)],
	},
}

static func annotate(frames: Array, key: String, state: String, direction: String) -> void:
	if not FIT_SHIFTS.has(key) or not RECIPES.has(state):
		return
	var di := ["se", "sw", "ne", "nw"].find(direction)
	var recipe: Array = RECIPES[state]
	if di < 0 or frames.size() != recipe.size():
		return
	for i in frames.size():
		var frame: Texture2D = frames[i]
		if frame == null or frame.get_height() != 256:
			continue
		var pose: String = recipe[i]
		var shift := Vector2.ZERO
		if FIT_SHIFTS[key].has(pose):
			shift = FIT_SHIFTS[key][pose][di]
		var offset := -shift
		if DEATH_DRAW_OFFSETS[key].has(pose):
			offset = DEATH_DRAW_OFFSETS[key][pose][di]
		frame.set_meta("draw_offset_px", offset)
		frame.set_meta("authored_direction4", true)
