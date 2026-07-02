extends SceneTree
## 同构检测：遍历 Defs.UNITS 中 hero_trainable 英雄，按 4 技能 effect.kind 排序拼签名分组，
## 输出 size>1 的组（=同构 kit）。期望 0 组。
## 用法：/Applications/Godot.app/Contents/MacOS/Godot --headless -s res://tools/iso_check.gd

func _init() -> void:
	var groups := {}    # signature -> [hero names]
	for key in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[key]
		if not bool(d.get("hero_trainable", false)):
			continue
		var abils: Array = d.get("abilities", [])
		var kinds: Array = []
		for aid in abils:
			var ad: Dictionary = Defs.ABILITIES.get(String(aid), {})
			var eff: Dictionary = ad.get("effect", {})
			var k := String(eff.get("kind", "?"))
			kinds.append(k)
		kinds.sort()
		var sig := "|".join(kinds)
		if not groups.has(sig):
			groups[sig] = []
		groups[sig].append(String(d.get("name", key)) + "(" + key + ")")

	var dup := 0
	for sig in groups:
		var g: Array = groups[sig]
		if g.size() > 1:
			dup += 1
			print("[iso] DUP sig=[%s] : %s" % [sig, ", ".join(g)])
	print("[iso] hero_trainable=%d  distinct_sigs=%d  DUP_GROUPS=%d" % [_count_trainable(), groups.size(), dup])
	quit()

func _count_trainable() -> int:
	var n := 0
	for key in Defs.UNITS:
		if bool(Defs.UNITS[key].get("hero_trainable", false)):
			n += 1
	return n
