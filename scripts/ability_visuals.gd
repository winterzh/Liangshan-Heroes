class_name AbilityVisuals
extends RefCounted
## 批量给 108 将的技能补齐视觉语义。跳过驻守战玩家 6 将，避免改动他们的竞技场/驻守手感。
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


# Earlier matches take priority. Hero keywords use lowercase Latin or Chinese.
const HERO_THEME_KEYWORDS := {
	"axe": ["斧", "axe", "berserker"],
	"hammer": ["锤", "hammer"],
	"stone": ["石", "山", "地", "earth"],
	"spear": ["枪", "矛", "spear", "lancer"],
	"arrow": ["箭", "弓", "arrow", "wind"],
	"blade": ["刀", "剑", "blade"],
	"fire": ["火", "焰", "炮", "fire"],
	"thunder": ["雷", "电", "storm", "thunder"],
	"water": ["冰", "寒", "霜", "水", "浪", "潮", "river", "winter"],
	"poison": ["毒", "瘴", "venom", "poison"],
	"shadow": ["魂", "黑", "暗", "影", "梦", "shadow", "night"],
	"holy": ["医", "安道全", "heal", "holy"],
	"beast": ["虎", "龙", "狼", "兽", "dragon", "beast"],
	"chain": ["索", "钩", "链", "网", "chain"],
	"command": ["宋", "军", "令", "banner", "commander"],
}

const ABILITY_THEME_KEYWORDS := {
	"hammer": ["锤", "重锤", "砸", "震"],
	"axe": ["斧"],
	"stone": ["飞石", "石", "山", "地", "裂"],
	"spear": ["枪", "矛", "刺", "突"],
	"arrow": ["箭", "弓", "射"],
	"blade": ["刀", "剑", "斩", "割"],
	"fire": ["火", "焰", "炎", "炮", "爆"],
	"thunder": ["雷", "电", "霹雳"],
	"ice": ["冰", "寒", "霜"],
	"water": ["水", "浪", "潮", "江", "海"],
	"poison": ["毒", "瘴"],
	"shadow": ["魂", "幽", "黑", "暗", "影", "梦", "咒"],
	"holy": ["疗", "医", "救", "护", "盾", "金光"],
	"beast": ["虎", "龙", "狼", "兽", "变身"],
	"chain": ["钩", "索", "链", "网", "缚"],
	"command": ["令", "阵", "旗", "号令", "战吼", "暴喝"],
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
		var hero_label := "%s %s" % [String(key), String(d.get("name", ""))]
		var base_theme := _hero_theme(String(key), hero_label)
		var art_abilities: Array = d.get("abilities", []).duplicate()
		if String(key) == "liu_tang" and not art_abilities.has("liu_cleave"):
			art_abilities.append("liu_cleave")
		for aid_v in art_abilities:
			var aid := String(aid_v)
			if excluded_abilities.has(aid) or not abilities.has(aid):
				continue
			var ad: Dictionary = abilities[aid]
			var eff: Dictionary = ad.get("effect", {})
			if eff.is_empty():
				continue
			ability_count += 1
			var kind := String(eff.get("active_kind", eff.get("kind", "")))
			# 施恩/阮小七/刘唐的枪棒刀法只配贴身尘迹，不转换成飞弹、符文或法术光环。
			if aid in ["shi_en_q", "shi_en_w", "shi_en_r", "ruan_xiaoqi_q", "ruan_xiaoqi_w", "ruan_xiaoqi_r", "liu_tang_q", "liu_tang_w", "liu_tang_r", "liu_cleave", "ruan_xiaowu_q", "ruan_xiaowu_w"]:
				ad["visual"] = {"delivery": "staff", "theme": "staff", "replace_default": true, "face_nearest_foe": true}
				abilities[aid] = ad
				visual_count += 1
				continue
			var theme := _ability_theme(hero_label, ad, eff, base_theme)
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


static func _hero_theme(key: String, label: String) -> String:
	var text := label.to_lower()
	for theme: String in HERO_THEME_KEYWORDS:
		if _has_keyword(text, HERO_THEME_KEYWORDS[theme]):
			return theme
	return ["stone", "blade", "fire", "water", "shadow", "thunder"][abs(hash(key)) % 6]


static func _ability_theme(hero_label: String, ad: Dictionary, eff: Dictionary, fallback: String) -> String:
	var text := "%s %s %s" % [hero_label, String(ad.get("name", "")), String(ad.get("desc", ""))]
	for theme: String in ABILITY_THEME_KEYWORDS:
		if _has_keyword(text, ABILITY_THEME_KEYWORDS[theme]):
			return theme
	if String(eff.get("dispel", "")) != "" or String(eff.get("kind", "")) == "shield":
		return "holy"
	if float(eff.get("silence", 0.0)) > 0.0 or float(eff.get("amp", 0.0)) > 0.0:
		return "shadow"
	return fallback


static func _has_keyword(text: String, keywords: Array) -> bool:
	for keyword: String in keywords:
		if text.contains(keyword):
			return true
	return false
