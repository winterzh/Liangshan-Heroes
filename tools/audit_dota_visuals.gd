extends SceneTree

const EXCLUDE := {
	"song_jiang": true,
	"lin_chong": true,
	"hua_rong": true,
	"li_kui": true,
	"gongsun_sheng": true,
	"wu_song": true,
}

func _init() -> void:
	var defs := Defs.UNITS.duplicate(true)
	var abilities := Defs.ABILITIES.duplicate(true)
	var applied := DotaVisuals.apply(defs, abilities)
	var heroes: Array = []
	var targets: Array = []
	var kinds := {}
	var visual_count := 0
	var target_abilities := 0
	var excluded_visuals := 0
	for key in Defs.UNITS.keys():
		var d: Dictionary = defs[key]
		if not bool(d.get("hero_trainable", false)):
			continue
		heroes.append(key)
		if EXCLUDE.has(key):
			for aid_ex in d.get("abilities", []):
				if abilities.get(String(aid_ex), {}).has("visual"):
					excluded_visuals += 1
			continue
		targets.append(key)
		for aid in d.get("abilities", []):
			target_abilities += 1
			var ad: Dictionary = abilities.get(String(aid), {})
			var eff: Dictionary = ad.get("effect", {})
			var kind := String(eff.get("active_kind", eff.get("kind", "")))
			kinds[kind] = int(kinds.get(kind, 0)) + 1
			if ad.has("visual"):
				visual_count += 1
	heroes.sort()
	targets.sort()
	var ks: Array = kinds.keys()
	ks.sort()
	print("[dota_visual_audit] heroes=%d excluded=%d targets=%d abilities=%d visuals=%d excluded_visuals=%d applied=%s" % [
		heroes.size(), EXCLUDE.size(), targets.size(), target_abilities, visual_count, excluded_visuals, str(applied)])
	for k in ks:
		print("  %-14s %d" % [String(k), int(kinds[k])])
	quit()
