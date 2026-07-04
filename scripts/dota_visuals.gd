class_name DotaVisuals
extends RefCounted
## 批量给 108 将 DOTA 技能补视觉语义。跳过驻守战玩家 6 将，避免改动他们的竞技场/驻守手感。
## 这里只给本场 _abilities 副本加 visual / bolt_art / orbit_art 字段，不直接改 Defs 常量。

const EXCLUDED_HEROES := {
	"song_jiang": true,
	"lin_chong": true,
	"hua_rong": true,
	"li_kui": true,
	"gongsun_sheng": true,
	"wu_song": true,
}

const PROJECTILE_BY_THEME := {
	"hammer": "hammer", "axe": "axe", "stone": "stone", "blade": "dagger",
	"arrow": "arrow", "spear": "spear", "fire": "fire_orb", "ice": "ice_shard",
	"poison": "poison_vial", "thunder": "thunder_orb", "shadow": "shadow_orb",
	"water": "water_drop", "holy": "rune", "beast": "claw", "chain": "chain",
	"command": "banner",
}

const IMPACT_BY_THEME := {
	"hammer": "heavy_slam", "axe": "blood_hit", "stone": "ground_crack", "blade": "blood_hit",
	"arrow": "dust_ring", "spear": "armor_crack", "fire": "fire_burst", "ice": "ice_burst",
	"poison": "poison_splash", "thunder": "thunder_hit", "shadow": "shadow_burst",
	"water": "water_splash", "holy": "holy_flash", "beast": "roar", "chain": "leaf_snare",
	"command": "roar",
}


static func apply(defs: Dictionary, abilities: Dictionary) -> Dictionary:
	var excluded_abilities := {}
	for hk in EXCLUDED_HEROES.keys():
		var hd: Dictionary = defs.get(hk, {})
		for aid in hd.get("abilities", []):
			excluded_abilities[String(aid)] = true
		if String(hd.get("ability", "")) != "":
			excluded_abilities[String(hd["ability"])] = true

	var hero_count := 0
	var ability_count := 0
	var visual_count := 0
	for key in defs.keys():
		var d: Dictionary = defs[key]
		if not bool(d.get("hero_trainable", false)) or EXCLUDED_HEROES.has(String(key)):
			continue
		hero_count += 1
		var base_theme := _hero_theme(String(key), d)
		for aid_v in d.get("abilities", []):
			var aid := String(aid_v)
			if excluded_abilities.has(aid) or not abilities.has(aid):
				continue
			var ad: Dictionary = abilities[aid]
			var eff: Dictionary = ad.get("effect", {})
			if eff.is_empty():
				continue
			ability_count += 1
			var kind := String(eff.get("active_kind", eff.get("kind", "")))
			var theme := _ability_theme(String(key), d, ad, eff, base_theme)
			var visual := _visual_for(kind, theme, ad, eff)
			if visual.is_empty():
				continue
			ad["visual"] = visual
			if kind == "bolt":
				eff["bolt_art"] = String(visual.get("projectile", ""))
			elif kind == "orbit_axes" and not eff.has("orbit_art"):
				eff["orbit_art"] = String(visual.get("projectile", "axe"))
			ad["effect"] = eff
			abilities[aid] = ad
			visual_count += 1
	return {"heroes": hero_count, "abilities": ability_count, "visuals": visual_count}


static func _visual_for(kind: String, theme: String, ad: Dictionary, eff: Dictionary) -> Dictionary:
	var projectile := String(PROJECTILE_BY_THEME.get(theme, "stone"))
	var impact := String(IMPACT_BY_THEME.get(theme, "dust_ring"))
	var delivery := "impact"
	match kind:
		"bolt":
			delivery = "projectile"
		"hook", "pull":
			delivery = "chain"
			theme = "chain"
			projectile = "chain"
			impact = "leaf_snare"
		"smite":
			if bool(ad.get("targeted", false)):
				if float(eff.get("silence", 0.0)) > 0.0 or float(eff.get("amp", 0.0)) > 0.0 or float(eff.get("hex", 0.0)) > 0.0:
					delivery = "rune"
				elif theme in ["fire", "stone", "thunder", "poison"]:
					delivery = "lob"
				else:
					delivery = "thrown"
			else:
				delivery = "roar" if (float(eff.get("taunt", 0.0)) > 0.0 or theme == "command") else "aura"
		"line_nuke", "chain_nuke", "global_nuke":
			delivery = "beam"
		"sector_nuke", "fissure", "echo", "knockback":
			delivery = "sweep"
		"charge", "blink", "blink_shot":
			delivery = "dash"
		"rally", "haste", "shield", "self_buff", "atkspeed", "debuff":
			delivery = "aura"
		"ward", "chrono", "fire_dot", "fire_line", "fire_trail", "black_rain", "ice_wall", "channel":
			delivery = "rune"
		"summon", "transform", "invis":
			delivery = "manifest"
		"heal_wave":
			delivery = "beam"
			theme = "holy"
			projectile = "rune"
			impact = "holy_flash"
		_:
			if kind == "passive":
				return {}
	return {
		"delivery": delivery,
		"theme": theme,
		"projectile": projectile,
		"impact": impact,
		"replace_default": true,
	}


static func _hero_theme(key: String, d: Dictionary) -> String:
	var txt := "%s %s %s" % [key, String(d.get("name", "")), String(d.get("dota", ""))]
	if _has(txt, ["斧", "axe", "berserker"]): return "axe"
	if _has(txt, ["锤", "hammer", "sven", "tiny"]): return "hammer"
	if _has(txt, ["石", "山", "地", "earth", "shaker", "tusk"]): return "stone"
	if _has(txt, ["枪", "矛", "spear", "lancer", "mars"]): return "spear"
	if _has(txt, ["箭", "弓", "sniper", "drow", "clinkz", "wind"]): return "arrow"
	if _has(txt, ["刀", "剑", "blade", "jugger", "riki", "slark"]): return "blade"
	if _has(txt, ["火", "焰", "炮", "fire", "lina", "bat", "phoenix", "gyrocopter"]): return "fire"
	if _has(txt, ["雷", "电", "storm", "razor", "zeus"]): return "thunder"
	if _has(txt, ["冰", "寒", "霜", "水", "浪", "潮", "river", "morph", "kunkka", "lich", "winter"]): return "water"
	if _has(txt, ["毒", "瘴", "venom", "viper", "poison"]): return "poison"
	if _has(txt, ["魂", "黑", "暗", "影", "梦", "shadow", "bane", "spectre", "night"]): return "shadow"
	if _has(txt, ["医", "安道全", "heal", "omni", "oracle", "dazzle"]): return "holy"
	if _has(txt, ["虎", "龙", "狼", "兽", "lycan", "dragon", "beast", "ursa"]): return "beast"
	if _has(txt, ["索", "钩", "链", "网", "pudge", "shaman"]): return "chain"
	if _has(txt, ["宋", "军", "令", "banner", "commander"]): return "command"
	return ["stone", "blade", "fire", "water", "shadow", "thunder"][abs(hash(key)) % 6]


static func _ability_theme(key: String, d: Dictionary, ad: Dictionary, eff: Dictionary, fallback: String) -> String:
	var txt := "%s %s %s %s" % [key, String(d.get("name", "")), String(ad.get("name", "")), String(ad.get("desc", ""))]
	if _has(txt, ["锤", "重锤", "砸", "震"]): return "hammer"
	if _has(txt, ["斧"]): return "axe"
	if _has(txt, ["飞石", "石", "山", "地", "裂"]): return "stone"
	if _has(txt, ["枪", "矛", "刺", "突"]): return "spear"
	if _has(txt, ["箭", "弓", "射"]): return "arrow"
	if _has(txt, ["刀", "剑", "斩", "割"]): return "blade"
	if _has(txt, ["火", "焰", "炎", "炮", "爆"]): return "fire"
	if _has(txt, ["雷", "电", "霹雳"]): return "thunder"
	if _has(txt, ["冰", "寒", "霜"]): return "ice"
	if _has(txt, ["水", "浪", "潮", "江", "海"]): return "water"
	if _has(txt, ["毒", "瘴"]): return "poison"
	if _has(txt, ["魂", "幽", "黑", "暗", "影", "梦", "咒"]): return "shadow"
	if _has(txt, ["疗", "医", "救", "护", "盾", "金光"]): return "holy"
	if _has(txt, ["虎", "龙", "狼", "兽", "变身"]): return "beast"
	if _has(txt, ["钩", "索", "链", "网", "缚"]): return "chain"
	if _has(txt, ["令", "阵", "旗", "号令", "战吼", "暴喝"]): return "command"
	if String(eff.get("dispel", "")) != "" or String(eff.get("kind", "")) == "shield":
		return "holy"
	if float(eff.get("silence", 0.0)) > 0.0 or float(eff.get("amp", 0.0)) > 0.0:
		return "shadow"
	return fallback


static func _has(txt: String, needles: Array) -> bool:
	var low := txt.to_lower()
	for n in needles:
		if low.find(String(n).to_lower()) >= 0:
			return true
	return false
