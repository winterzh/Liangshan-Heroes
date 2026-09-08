extends "res://tools/localization_qa.gd"
## Compare mechanics against the explicit pre-review snapshot; no player profile.

func _run() -> void:
	var baseline_path := OS.get_environment("LSH_QA_BASELINE_DEFS")
	check(not baseline_path.is_empty(), "explicit baseline definition snapshot supplied")
	if baseline_path.is_empty():
		_finish()
		return
	var baseline: GDScript = load(baseline_path)
	check(baseline.UNITS.keys() == Defs.UNITS.keys(), "unit identifiers and order preserved")
	check(baseline.ABILITIES.keys() == Defs.ABILITIES.keys(), "ability identifiers and order preserved")
	for key in Defs.UNITS:
		var before: Dictionary = baseline.UNITS[key].duplicate(true)
		var after: Dictionary = Defs.UNITS[key].duplicate(true)
		before.erase("name")
		after.erase("name")
		check(before == after, "unit mechanics preserved: " + key)
	for key in Defs.ABILITIES:
		var before: Dictionary = baseline.ABILITIES[key].duplicate(true)
		var after: Dictionary = Defs.ABILITIES[key].duplicate(true)
		for field in ["name", "desc"]:
			before.erase(field)
			after.erase(field)
		check(before == after, "ability mechanics preserved: " + key)
	check(LoreData.LORE.size() == 108 and LoreData.CHAPTERS.size() == 108, "108 biographies and source references")
	var ranks := []
	for key in Bios.STAR:
		ranks.append(Bios.star_rank(key))
		check(LoreData.LORE.has(key) and LoreData.CHAPTERS.has(key), "biography with chapters: " + key)
	ranks.sort()
	check(ranks == range(1, 109), "all 108 ranks occur once")
	_finish()
