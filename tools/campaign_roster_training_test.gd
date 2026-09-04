extends SceneTree
## Headless regression for real recruitment and explicit production-limit fixtures.
## No global definition mutation or campaign progress writes.
const RECRUITS := ["lu_junyi","shi_xiu","wu_yong","liu_tang","ruan_brother","bai_sheng"]
var checks: Array[Dictionary] = []
var evidence := {}
var modes_done: Array[String] = []
var recruits_born: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _check(passed: bool,label: String) -> void:
	checks.append({"check":label,"passed":passed})
	print("[roster-check] ","PASS " if passed else "FAIL ",label)

func _save_hash() -> String:
	var file := "user://campaign.cfg"
	return FileAccess.get_file_as_bytes(file).hex_encode().sha256_text() if FileAccess.file_exists(file) else "absent"

func _start(mode: String):
	var c = root.get_node("Campaign")
	for key in ["skirmish","skirmish_ai","arena","scenario","custom_defense","scale_on","ai_friendly"]: c.set(key,false)
	c.set(mode,true)
	c.current = c.index_for_id("level8")
	seed(5088120)
	var b = load("res://scenes/main.tscn").instantiate()
	root.add_child(b)
	current_scene = b
	await process_frame
	b.hud._intro_root.hide()
	b._on_intro_done()
	b.hud._on_start_pressed()
	return b

func _dispose(b) -> void:
	b.queue_free()
	await process_frame
	await process_frame

func _menu_keys(b,bld) -> Array:
	var previous_cat: String = b._hall_cat
	var previous_page: int = b._hall_page
	var keys: Array = []
	b._hall_cat = ""
	b._hall_page = 0
	var first: Array = b.train_menu(bld)
	for entry in first:
		if entry.get("kind","") == "train" and not keys.has(entry.key): keys.append(entry.key)
	var categories: Array = first.filter(func(entry): return entry.get("kind","") == "hall_cat" and entry.get("cat","") != "")
	for category in categories:
		b._hall_cat = category.cat
		for page in range(32):
			b._hall_page = page
			var menu: Array = b.train_menu(bld)
			for entry in menu:
				if entry.get("kind","") == "train" and not keys.has(entry.key): keys.append(entry.key)
			if b._hall_page != page or not menu.any(func(entry): return entry.get("kind","") == "train_page"): break
	b._hall_cat = previous_cat
	b._hall_page = previous_page
	keys.sort()
	return keys

func _rejected(b,bld,key: String,reason: String,label: String) -> void:
	var gold_before: float = b.gold
	var wood_before: float = b.wood
	var queue_before: Array = bld._train_queue.duplicate() if is_instance_valid(bld) else []
	var actual: String = b._train_block_reason(bld,key)
	var accepted: bool = b.queue_train(bld,key,false)
	_check(actual == reason and not accepted,label+" rejects with "+reason)
	_check(b.gold == gold_before and b.wood == wood_before and (not is_instance_valid(bld) or bld._train_queue == queue_before),label+" does not spend or enqueue")

func _arena() -> void:
	var b = await _start("arena")
	var hall = b.level.hall
	var definitions_before: Dictionary = b._defs.duplicate(true)
	var hall_definition: Dictionary = hall.setup_def.duplicate(true)
	var menu: Array = _menu_keys(b,hall)
	evidence["arena_menu_before"] = menu
	_check(RECRUITS.all(func(key): return key in menu),"arena category pages contain the six expanded recruitment cases")
	_check(not bool(b._defs.chao_gai.get("hero_trainable",false)) and not menu.has("chao_gai"),"unmarked Chao Gai remains outside the normal recruit roster")
	_rejected(b,hall,"chao_gai","unsupported","unmarked Chao Gai")
	# A second hall and barracks are explicit building fixtures for multi-producer routing.
	var second = b.spawn_at("hall",hall.faction,Vector2i(23,18))
	var barracks = b.spawn_at("barracks",hall.faction,Vector2i(29,24))
	var barracks_keys: Array = _menu_keys(b,barracks)
	var original_troops: Array = barracks.setup_def.produces.duplicate()
	original_troops.sort()
	_check(barracks_keys == original_troops and not b.train_menu(barracks).any(func(entry): return entry.get("kind","") == "hall_cat"),"arena barracks retains its original troop menu without hall categories")
	_rejected(b,barracks,"lu_junyi","unsupported","arena barracks hero request")
	b._set_selection([hall,second,barracks])
	var producers: Array = b._selected_producers_for(hall,"lu_junyi")
	_check(producers.size() == 2 and producers.has(hall) and producers.has(second) and not producers.has(barracks),"expanded hero routes to both selected halls, never barracks")
	_check(b._selected_producers_for(barracks,"lu_junyi").is_empty(),"selected barracks cannot become an expanded hero producer")
	# Current-match marker changes must affect all three readers without mutating Defs.UNITS.
	b._defs.lu_junyi.hero_trainable = false
	_check(not _menu_keys(b,hall).has("lu_junyi") and b._train_block_reason(hall,"lu_junyi") == "unsupported" and b._selected_producers_for(hall,"lu_junyi").is_empty(),"menu, validation and producer routing all read current-match hero marker")
	b._defs.lu_junyi.hero_trainable = definitions_before.lu_junyi.hero_trainable
	_rejected(b,null,"lu_junyi","invalid","missing building")
	hall.is_constructing = true
	_rejected(b,hall,"lu_junyi","constructing","unfinished hall")
	hall.is_constructing = false
	hall._research_key = "tech_gather"
	_rejected(b,hall,"lu_junyi","researching","researching hall")
	hall._research_key = ""
	var age_before: int = b.current_age
	b.current_age = 1
	_rejected(b,barracks,"liang_ma","age","second-age cavalry at first age")
	_check(not _menu_keys(b,barracks).has("liang_ma"),"age-locked cavalry also stays out of menu")
	b.current_age = age_before
	var gold_before: float = b.gold
	var wood_before: float = b.wood
	b.gold = 0
	b.wood = 0
	_rejected(b,hall,"lu_junyi","resources","expanded hero with no resources")
	b.gold = gold_before
	b.wood = wood_before
	var pop_before: int = b.pop_cap
	b.pop_cap = b.used_pop()+2
	_rejected(b,hall,"lu_junyi","population","expanded hero exceeding population")
	b.pop_cap = pop_before
	var all_queued := true
	for index in range(8): all_queued = b.queue_train(hall,"lou_luo",false) and all_queued
	_check(all_queued and hall._train_queue.size() == 8,"normal worker requests fill exactly eight queue entries")
	_rejected(b,hall,"lu_junyi","queue_full","expanded hero at full queue")
	for index in range(8): b.cancel_train(hall,0)
	_check(b.gold == gold_before and b.wood == wood_before,"normal cancellations refund queued fixture workers")
	_check(b.queue_train(hall,"lu_junyi",false),"first normal Lu Junyi order is accepted")
	_rejected(b,second,"lu_junyi","hero_exists","duplicate hero in another hall queue")
	_check(not _menu_keys(b,second).has("lu_junyi"),"queued hero is hidden in the other hall menu")
	b.cancel_train(hall,0)
	# Actual production for six expanded cases: no instant spawn fixture.
	for key in RECRUITS:
		if not b._defs.has(key):
			_check(false,"recruit definition exists for "+key)
			continue
		var target = second if key == "lu_junyi" else hall
		var before_gold: float = b.gold
		var before_wood: float = b.wood
		var accepted := false
		if key == "lu_junyi":
			_check(b.queue_train(hall,"lou_luo",false),"multi-producer routing has a real longer queue in first hall")
			before_gold = b.gold
			before_wood = b.wood
			b.queue_train_multi(hall,key)
			accepted = second._train_queue.has(key) and not hall._train_queue.has(key)
		else: accepted = b.queue_train(target,key,false)
		_check(accepted,"normal recruitment enqueues "+key)
		_check(b.gold == before_gold-int(b._defs[key].cost_gold) and b.wood == before_wood-int(b._defs[key].cost_wood),"normal recruitment charges unchanged costs for "+key)
		var unit = b.find_unit(key)
		for frame in range(180):
			if unit != null: break
			await process_frame
			unit = b.find_unit(key)
		_check(unit != null and unit.hp > 0 and unit.key == key and unit.art_variant == "","normal training queue actually produces "+key)
		if unit != null: recruits_born.append(key)
	_rejected(b,hall,"lu_junyi","hero_exists","duplicate hero after birth")
	_check(b._defs == definitions_before and hall.setup_def == hall_definition,"production did not mutate current definitions or building produces arrays")
	modes_done.append("arena")
	await _dispose(b)

func _restricted_mode(mode: String) -> void:
	var b = await _start(mode)
	var hall = b.find_unit("hall")
	var allowed: Array = hall.setup_def.produces.duplicate()
	var menu: Array = _menu_keys(b,hall)
	var expected: Array = []
	for key in allowed:
		if int(b._defs[key].get("min_age",1)) <= b.current_age: expected.append(key)
	expected.sort()
	_check(not b.level.uses_full_roster() and menu == expected,mode+" retains the original hall menu")
	_check(b._trainable_keys(hall) == allowed,mode+" retains the exact produces roster")
	b._set_selection([hall])
	_check(b._selected_producers_for(hall,"lu_junyi").is_empty(),mode+" cannot route an expanded hero to selected hall")
	_rejected(b,hall,"lu_junyi","unsupported",mode+" expanded hero")
	_check(b._train_block_reason(hall,"song_jiang") == "",mode+" original hero remains eligible")
	if mode == "custom_defense":
		_check(int(b.level.hero_cap()) == 1 and b.queue_train(hall,"song_jiang",false),"custom defense respects its configured one-hero queue")
		_rejected(b,hall,"lin_chong","hero_cap","custom defense second hero")
	evidence[mode+"_menu"] = menu
	modes_done.append(mode)
	await _dispose(b)

func _run() -> void:
	OS.set_environment("CAMPAIGN_QA","1")
	OS.set_environment("SMOKE_TEST","")
	root.get_node("Settings").edge_scroll = false
	root.get_node("Settings").auto_micro_level = 0
	AudioServer.set_bus_mute(0,true)
	Engine.time_scale = 4.0
	var c = root.get_node("Campaign")
	var config_before: Dictionary = c.custom_config.duplicate(true)
	var defs = load("res://scripts/defs.gd")
	var global_before: Dictionary = defs.UNITS.duplicate(true)
	var save_before := _save_hash()
	await _arena()
	for mode in ["skirmish","skirmish_ai","custom_defense"]:
		if mode == "custom_defense": c.custom_config = {"hero_cap":1}
		await _restricted_mode(mode)
	c.custom_config = config_before
	_check(defs.UNITS == global_before,"global Defs.UNITS is unchanged across all four modes")
	_check(_save_hash() == save_before,"CAMPAIGN_QA keeps campaign.cfg unchanged")
	_check(modes_done.size() == 4 and recruits_born.size() == RECRUITS.size(),"all four mode cases and six genuine births executed")
	Engine.time_scale = 1.0
	var passed: bool = checks.all(func(item): return item.passed)
	var output := OS.get_environment("ROSTER_QA_OUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://qa/web_chatgpt_art_20260831/roster_training")
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"evidence":evidence,"modes":modes_done,"recruits_born":recruits_born,
		"save_hash_before":save_before,"save_hash_after":_save_hash(),"scope":"Real queue births and explicit limit/building fixtures. No rendering, human acceptance or permanent data changes."},"\t"))
	file.close()
	print("[roster-summary] ",JSON.stringify({"passed":passed,"checks":checks.size(),"modes":modes_done,"born":recruits_born}))
	quit(0 if passed else 1)
