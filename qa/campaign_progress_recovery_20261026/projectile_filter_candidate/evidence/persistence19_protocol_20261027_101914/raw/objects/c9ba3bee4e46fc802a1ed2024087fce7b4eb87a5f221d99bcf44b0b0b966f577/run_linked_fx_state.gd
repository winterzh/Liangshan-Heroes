extends RefCounted
## Fixed remaining Battle Fx scripts, scalar state and reference/texture fields.
const Scalar := preload("res://scripts/run_procedural_fx_state.gd")
const TYPES := {
	"hua_snipe_aim": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "life": TYPE_FLOAT, "col": TYPE_COLOR},
	"hua_snipe_mark": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "life": TYPE_FLOAT},
	"hua_lock_mark": {"col": TYPE_COLOR, "pulse": TYPE_FLOAT},
	"lin_guard": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "life": TYPE_FLOAT, "col": TYPE_COLOR},
	"lin_spear_stack": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "stacks": TYPE_INT, "proc": TYPE_BOOL},
	"lin_duel": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "life": TYPE_FLOAT, "col": TYPE_COLOR},
	"ability_projectile": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "end_w": TYPE_VECTOR2, "col": TYPE_COLOR, "lob": TYPE_BOOL, "_E": TYPE_VECTOR2, "_ang": TYPE_FLOAT},
	"ability_impact": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "rad": TYPE_FLOAT, "col": TYPE_COLOR, "mode": TYPE_STRING},
	"orbit_axes": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "rad": TYPE_FLOAT, "col": TYPE_COLOR, "life": TYPE_FLOAT, "_spin": TYPE_FLOAT},
	"black_rain": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "rad": TYPE_FLOAT, "col": TYPE_COLOR, "life": TYPE_FLOAT, "lite": TYPE_BOOL, "_drops": TYPE_ARRAY},
	"firefly": {"dur": TYPE_FLOAT, "t": TYPE_FLOAT, "life": TYPE_FLOAT, "col": TYPE_COLOR, "_motes": TYPE_ARRAY},
	"fading_mark": {"t": TYPE_FLOAT}}
const REFERENCES := {"hua_snipe_aim": ["caster", "target"], "hua_snipe_mark": ["target"], "hua_lock_mark": ["source", "target"], "lin_guard": ["target"], "lin_spear_stack": ["target"], "lin_duel": ["source", "target"], "ability_projectile": [], "ability_impact": [], "orbit_axes": ["target"], "black_rain": ["follow"], "firefly": ["follow"], "fading_mark": []}
const TEXTURES := {"hua_snipe_aim": [], "hua_snipe_mark": [], "hua_lock_mark": [], "lin_guard": [], "lin_spear_stack": [], "lin_duel": [], "ability_projectile": ["tex", "impact_tex"], "ability_impact": ["tex"], "orbit_axes": ["tex"], "black_rain": [], "firefly": [], "fading_mark": []}
var scripts: Dictionary
var _scalar: Variant

func _init(battle: Script) -> void:
	_scalar = Scalar.new(battle)
	scripts = {"hua_snipe_aim": battle.HuaSnipeAimFx, "hua_snipe_mark": battle.HuaSnipeMarkFx, "hua_lock_mark": battle.HuaLockMarkFx, "lin_guard": battle.LinGuardFx, "lin_spear_stack": battle.LinSpearStackFx, "lin_duel": battle.LinDuelFx, "ability_projectile": battle.AbilityProjectileFx, "ability_impact": battle.AbilityImpactFx, "orbit_axes": battle.OrbitAxesFx, "black_rain": battle.BlackRainFx, "firefly": battle.FireflyFx, "fading_mark": battle.FadingMark}

func kind(node: Node2D) -> String:
	for key: String in scripts:
		if node.get_script() == scripts[key]: return key
	return ""

func validate(values: Variant, kind: String) -> Dictionary:
	if not TYPES.has(kind) or typeof(values) != TYPE_DICTIONARY or values.size() != TYPES[kind].size() + TEXTURES[kind].size() or not values.has_all(TYPES[kind].keys() + TEXTURES[kind]): return _scalar._bad("LINKED_FIELDS", kind)
	for key: String in TYPES[kind]:
		if not _scalar._typed(values[key], TYPES[kind][key]): return _scalar._bad("LINKED_TYPE", kind + "." + key)
	if values.has("t") and (values.t <= 0.0 or values.t > values.get("dur", 1.2)): return _scalar._bad("LINKED_LIFETIME", kind)
	if values.has("dur") and values.dur <= 0.0: return _scalar._bad("LINKED_LIFETIME", kind)
	for key: String in ["rad", "life", "pulse"]:
		if values.has(key) and (values[key] < 0.0 or values[key] > 1000000.0): return _scalar._bad("LINKED_RANGE", key)
	if values.has("life") and values.life <= 0.0: return _scalar._bad("LINKED_LIFE", kind)
	if values.has("mode") and values.mode.length() > 128: return _scalar._bad("LINKED_MODE", kind)
	if kind == "lin_spear_stack" and (values.stacks < 0 or values.stacks > 4096): return _scalar._bad("LINKED_STACKS")
	if kind == "black_rain":
		var count: int = int(values.rad / (8.0 if values.lite else 5.0)) + (8 if values.lite else 14)
		if not _scalar._rows(values._drops, count, {"p": TYPE_VECTOR2, "ph": TYPE_FLOAT, "spd": TYPE_FLOAT, "h": TYPE_FLOAT}): return _scalar._bad("LINKED_RAIN_CACHE")
		for drop: Dictionary in values._drops:
			if drop.spd <= 0.0 or drop.h <= 0.0: return _scalar._bad("LINKED_RAIN_RANGE")
	if kind == "firefly":
		if not _scalar._rows(values._motes, 10, {"a": TYPE_FLOAT, "r": TYPE_FLOAT, "sp": TYPE_FLOAT, "ph": TYPE_FLOAT}): return _scalar._bad("LINKED_FIREFLY_CACHE")
		for mote: Dictionary in values._motes:
			if mote.r <= 0.0 or mote.sp <= 0.0: return _scalar._bad("LINKED_FIREFLY_RANGE")
	return {"ok": true}
