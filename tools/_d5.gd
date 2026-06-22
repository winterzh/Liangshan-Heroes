extends SceneTree
func _init() -> void:
	print("song_haste lvl: ", Defs.ability_levels("song_haste"))
	print("gong_dragon lvl: ", Defs.ability_levels("gong_dragon"))
	var u := Unit.new()
	u.ability_slots = [{"id": "song_haste", "rank": 1, "cd_t": 0.0, "passive": false}]
	var c1 := u._slot_cd(0)
	u.ability_slots[0]["rank"] = 2
	var c2 := u._slot_cd(0)
	u.ability_slots[0]["rank"] = 3
	var c3 := u._slot_cd(0)
	print("song_haste cd rank1/2/3 = %s / %s / %s" % [c1, c2, c3])
	u.free()
	quit()
