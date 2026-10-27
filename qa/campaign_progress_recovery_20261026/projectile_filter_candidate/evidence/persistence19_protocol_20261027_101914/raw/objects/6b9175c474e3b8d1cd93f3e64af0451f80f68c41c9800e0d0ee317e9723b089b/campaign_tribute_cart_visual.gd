extends RefCounted
## Chapter16 ground cargo after actual seizure, with no persistent Unit state.
static func enabled(unit) -> bool:
	if unit.key != "treasure_cart": return false
	var b = unit.battle
	if b == null or b.level == null or not b.units.has(unit): return false
	var script_path: String = b.level.get_script().resource_path
	if script_path == "res://scripts/levels/level1_huangnigang_short.gd":
		# The current short chapter replaces the base route during deploy.
		if unit.art_variant != "tribute_load_alpha_20260906" \
			or String(unit.setup_def.get("campaign_object", "")) != "tribute_load_alpha_20260906" \
			or unit.has_meta("campaign_environment_route"): return false
	elif script_path == "res://scripts/levels/level1_huangnigang.gd":
		if unit.art_variant != "tribute_load" \
			or String(unit.get_meta("campaign_environment_route", "")) != "tribute_load": return false
	else: return false
	if b.level.id() != "level1": return false
	var index: int = b.level.bundles.find(unit)
	if index < 0: return false
	# Drinking alone does not load a cart. The exact original cargo must have
	# been claimed before its later world appearance changes from load to cart.
	return b.mission.has_event("take_%d" % index) \
		or b.mission.has_event("force_taken_%d_0" % index) \
		or b.mission.has_event("deliver_%d" % index) \
		or b.mission.has_event("force_delivered_%d" % index) \
		or int(b.level.force_attempts.get(index, 0)) > 0

static func visual_size(texture: Texture2D) -> float:
	# Match the adopted Liu cart's scale (13 radius * 3.7 body size), while
	# its own world anchor sits under the wheel rather than behind the handles.
	return 48.1 * float(texture.get_meta("draw_scale", 1.0))
