extends Node
var root: Window
var checks: Array[Dictionary] = []
var output := ""

func _ready() -> void:
	root = get_tree().root
	output = OS.get_environment("STEAM_QA_OUTPUT")
	_run.call_deferred()

func check(name: String, condition: bool) -> void:
	checks.append({"name":name, "passed":condition})
	if not condition: print("FAIL " + name)

func _run() -> void:
	var campaign := root.get_node("Campaign")
	var service := root.get_node("SteamService")
	check("QA never initializes Steam", not service.available)
	var catalog := SteamAchievementCatalog.entries()
	check("exactly 30 achievements", catalog.size() == 30)
	var ids := {}
	for e in catalog:
		check("unique " + e.id, not ids.has(e.id))
		ids[e.id] = true
		check("localized " + e.id, not e.title_en.is_empty() and not e.description.is_empty())
	var state := SteamAchievementState.new()
	state.seed({"TOTAL_KILLS":999, "TOTAL_WINS":0, "AI_WINS":0, "DEFENSE_WINS":0}, {})
	state.add_kill()
	check("kill threshold", state.unlocked.get("ACH_KILLS_1000", false))
	check("kill exactly once", state.stats.TOTAL_KILLS == 1000)
	for i in range(1, 9):
		var ctx := {"mode":"campaign", "level_id":"level%d" % i}
		var r := {"story_complete":true, "story_done":3, "story_total":3}
		check("campaign settlement " + str(i), state.settle(i, ctx, true, r))
		check("duplicate settlement " + str(i), not state.settle(i, ctx, true, r))
	check("all clear", state.unlocked.get("ACH_ALL_CLEAR", false))
	check("all story", state.unlocked.get("ACH_ALL_STORY", false))
	check("eight wins", state.stats.TOTAL_WINS == 8)
	for waves in [30, 60]:
		state.settle(waves, {"mode":"defense", "waves":waves}, true, {})
		check("defense preset " + str(waves), state.unlocked.get("ACH_DEFENSE_%d" % waves, false))
	state.settle(101, {"mode":"ai"}, true, {})
	check("AI victory", state.unlocked.get("ACH_AI_WINS_1", false))
	var before: Dictionary = state.stats.duplicate(true)
	state.settle(102, {"mode":"custom"}, true, {})
	state.settle(103, {"mode":"campaign", "level_id":"level1"}, false, {})
	check("custom and defeat not victories", before == state.stats)
	for entry in catalog:
		if entry.stat == "": continue
		var probe := SteamAchievementState.new()
		probe.seed({entry.stat:int(entry.target) - 1}, {})
		probe.evaluate()
		check("below " + entry.id, not probe.unlocked.get(entry.id, false))
		probe.stats[entry.stat] += 1
		probe.evaluate()
		check("at " + entry.id, probe.unlocked.get(entry.id, false))
	var contract := {"level1":{"version":2, "ids":["a", "b"]}}
	var record := {"cleared":true, "story_complete":true, "contract_version":2, "story_total":2, "best_done":2, "best_goal_ids":["a", "b"]}
	check("verified migration", SteamAchievementCatalog.verified_legacy_ids({"level1":record}, contract).size() == 2)
	for field in ["cleared", "story_complete", "contract_version", "story_total", "best_done", "best_goal_ids"]:
		var broken := record.duplicate(true)
		broken.erase(field)
		check("migration missing " + field, SteamAchievementCatalog.verified_legacy_ids({"level1":broken}, contract).is_empty())
	var duplicate := record.duplicate(true)
	duplicate.best_goal_ids = ["a", "a"]
	check("duplicate legacy goals rejected", SteamAchievementCatalog.verified_legacy_ids({"level1":duplicate}, contract).is_empty())
	check("old clears never migrated", SteamAchievementCatalog.verified_legacy_ids({"level1":{"cleared":true}}, contract).is_empty())
	var validator := WorkshopContent.new()
	var scenario := ScenarioStore.default_scenario()
	scenario.deploy = [{"key":"song_jiang", "cell":[24,24], "faction":"LIANG", "ref":"leader"}]
	scenario.waves = [{"delay":2, "groups":[{"key":"guan_dao", "n":2}]}]
	scenario.win = [{"type":"survive_waves"}]
	scenario.lose = [{"type":"ref_dead", "ref":"leader"}]
	check("scenario editor format accepted: " + validator.error, validator.validate("scenario", scenario))
	var defense: Dictionary = WorkshopContent.encode_payload(CustomConfig.default_config())
	check("defense editor default accepted", validator.validate("custom_defense", defense))
	var local_defense := CustomConfig.default_config()
	local_defense.name = "QA editor round trip"
	check("default editor saves", not CustomConfig.save(local_defense).is_empty())
	var reopened := CustomConfig.load_by_name(local_defense.name)
	check("saved editor can publish", validator.validate("custom_defense", WorkshopContent.encode_payload(reopened)))
	check("legacy editor color string restored", WorkshopContent._restore_color("(0.1, 0.2, 0.3, 1.0)") is Color)
	check("invalid local color remains invalid", WorkshopContent._restore_color("(1, 2, nope, 4)") is String)
	var color_cfg := scenario.duplicate(true)
	color_cfg.abilities = {"song_rally":{"color":Color("aabbcc")}}
	color_cfg.title = "QA scenario round trip"
	check("scenario editor saves colors", not ScenarioStore.save(color_cfg).is_empty())
	check("scenario color type restored", ScenarioStore.load_by_name(color_cfg.title).abilities.song_rally.color is Color)
	if not validator.error.is_empty(): print("VALIDATOR " + validator.error)
	for variant in [{"script":"res://scripts/menu.gd"}, {"map":{"w":99999,"h":48}}, {"deploy":[{"key":"missing","cell":[0,0]}]}, {"terrain":[{"op":"paint_path","pts":[[0]]}]}, {"waves":[{"groups":[{"key":"guan_dao","n":-1}]}]}, {"win":[{"type":"hook","name":"arbitrary"}]}, {"sprite_alias":{"custom_1":"../../escape"}}, {"win":[{"type":"ref_dead","ref":"missing"}]}]:
		var bad := scenario.duplicate(true)
		bad.merge(variant, true)
		check("reject unsafe content " + str(variant.keys()), not validator.validate("scenario", bad))
	var clone := scenario.duplicate(true)
	clone.units = {"custom_1":Defs.UNITS.song_jiang.duplicate(true)}
	clone.sprite_alias = {"custom_1":"song_jiang"}
	clone.deploy[0].key = "custom_1"
	var json_clone: Variant = JSON.parse_string(JSON.stringify(clone))
	check("editor cloned unit accepted", validator.validate("scenario", json_clone))
	if not validator.error.is_empty(): print("CLONE " + validator.error)
	check("map example", validator.validate("scenario", WorkshopExamples.scenario()))
	check("defense example", validator.validate("custom_defense", WorkshopExamples.defense()))
	await _adapter_tests(service)
	# Actual campaign/node boundary: content-supplied level ids cannot create missions.
	campaign.current = 0
	campaign.scenario = false; campaign.custom_defense = false; campaign.skirmish = false; campaign.skirmish_ai = false; campaign.arena = false
	var level: RefCounted = campaign.make_level()
	check("official script classified", SteamRunPolicy.classify(campaign, level).mode == "campaign")
	campaign.scale_on = true
	check("built-in multipliers allowed", SteamRunPolicy.classify(campaign, level).mode == "campaign")
	campaign.scenario = true
	campaign.scenario_data = scenario.duplicate(true)
	campaign.scenario_data.id = "level1"
	var fake_level: RefCounted = campaign.make_level()
	check("spoofed id excluded", SteamRunPolicy.classify(campaign, fake_level).mode == "custom")
	var records_before: Dictionary = campaign.records.duplicate(true)
	var battle: Node = load("res://scripts/battle.gd").new()
	root.add_child(battle)
	await get_tree().process_frame
	check("custom actual Battle has no mission", battle.mission == null)
	battle._end(true, "QA custom win")
	check("custom actual victory preserves campaign records", campaign.records == records_before)
	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	campaign.scenario = false; campaign.scale_on = false
	if OS.get_environment("STEAM_QA_NATIVE") == "1":
		check("native extension loads in Godot 4.6.3", Engine.has_singleton("Steam"))
		if Engine.has_singleton("Steam"):
			var native := Engine.get_singleton("Steam")
			for method in ["steamInitEx", "run_callbacks", "steamShutdown", "getAchievement", "getStatInt", "setStatInt", "storeStats", "getSubscribedItems", "getItemInstallInfo", "createItem", "setItemTags", "submitItemUpdate", "getItemUpdateProgress"]:
				check("native method " + method, native.has_method(method))
			for s in ["item_created", "item_updated", "item_downloaded", "item_installed", "user_stats_stored"]:
				check("native signal " + s, native.has_signal(s))
	if OS.get_environment("STEAM_QA_VISUAL") == "1":
		var menu: Control = load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu)
		await get_tree().process_frame
		menu._show_more()
		await _capture("more.png")
		menu.get_child(menu.get_child_count()-1).queue_free()
		await get_tree().process_frame
		SteamPanels.show_achievements(menu)
		await _capture("achievements.png")
		menu.get_child(menu.get_child_count()-1).queue_free()
		await get_tree().process_frame
		SteamPanels.show_workshop(menu)
		await _capture("workshop.png")
		menu.queue_free()
		await get_tree().process_frame
		var editor: Control = load("res://scenes/scenario_editor.tscn").instantiate()
		root.add_child(editor)
		await get_tree().process_frame
		await _capture("scenario_editor.png")
		SteamPanels.show_publish(editor, "scenario", scenario)
		await _capture("publish.png")
		editor.queue_free()
		await get_tree().process_frame
		var defense_editor: Control = load("res://scenes/editor.tscn").instantiate()
		root.add_child(defense_editor)
		await get_tree().process_frame
		await _capture("defense_editor.png")
		defense_editor.queue_free()
		await get_tree().process_frame
	var passed := true
	for c in checks: passed = passed and c.passed
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks}, "\t"))
	file.close()
	print("STEAM_QA %s %d checks" % ["PASS" if passed else "FAIL", checks.size()])
	root.get_node("Sfx").shutdown()
	root.get_node("Music").shutdown()
	for i in range(3): await get_tree().process_frame
	get_tree().quit(0 if passed else 1)

func _capture(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check("capture " + name, root.get_texture().get_image().save_png(output.path_join(name)) == OK)

func _adapter_tests(service: Node) -> void:
	var api: RefCounted = load("res://tools/steam_fake_api.gd").new()
	service.native = api
	service.available = true
	service.account = str(api.owner)
	service._read_initial_state()
	check("adapter ready after schema load", service.stats_ready)
	service._active_run = 10
	service._context = {"mode":"ai"}
	service.settle(10, true, {})
	service.settle(10, true, {})
	check("adapter duplicate victory writes once", api.stats.TOTAL_WINS == 1 and api.stats.AI_WINS == 1)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	service._retry_after = 0
	service._active_run = 11
	service.record_kill(11)
	check("kills sent to Steam cache immediately", api.stats.TOTAL_KILLS == 1)
	api.store_ok = false
	service.flush()
	check("failed store retains dirty state", service._dirty and not service._store_busy)
	api.store_ok = true
	service._retry_after = 0
	service.flush()
	service.record_kill(11)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	check("in-flight newer progress remains dirty", service._dirty)
	service._retry_after = 0
	service.flush()
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	check("acknowledged progress becomes clean", not service._dirty)
	var workshop := root.get_node("WorkshopService")
	workshop._connect_native()
	var preview := Image.create(32,32,false,Image.FORMAT_RGB8)
	preview.fill(Color("a08050"))
	var source := WorkshopExamples.scenario()
	workshop.publish("scenario", source, "QA only", 2, preview)
	check("upload creates once", workshop.busy and api.creates == 1)
	workshop.publish("scenario", source, "QA duplicate", 2, preview)
	check("duplicate submit blocked", api.creates == 1)
	api.item_created.emit(1, 999001, false)
	check("created id persisted before submit", int(workshop._pending.id) == 999001 and api.submits == 1)
	api.item_updated.emit(2, false, 999001)
	check("failed update is retryable", not workshop.busy)
	workshop.publish("scenario", source, "QA retry", 2, preview)
	check("retry reuses created item", api.creates == 1 and api.submits == 2)
	api.item_updated.emit(1, true, 999001)
	check("agreement success opens mocked page", not workshop.busy and api.pages.size() == 1)
	api.subscribed = [999001]
	workshop.refresh()
	check("installed package validates", workshop.items.size() == 1 and workshop.items[0].ok)
	api.flags = 5 | 8
	workshop.refresh()
	check("updating package cannot play", not workshop.items[0].ok)
	api.flags = 5
	workshop.unsubscribe("999001")
	workshop.refresh()
	check("unsubscribe removes listing", workshop.items.is_empty())
	check("unsubscribe preserves local source", ScenarioStore.list_saved().has(source.title))
	var count_before: int = api.stats.TOTAL_KILLS
	api.owner = 222
	service.record_kill(11)
	check("account switch cannot write old progress to new user", not service.available and api.stats.TOTAL_KILLS == count_before)
	service.native = null
	service.available = false
	service.stats_ready = false
	service.status = "普通启动：Steam 成就不计入"
	workshop.items.clear()
	await get_tree().process_frame
