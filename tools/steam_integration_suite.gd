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

func _native_method_args(native: Object, method_name: String) -> Array:
	for method in native.get_method_list():
		if method.name != method_name: continue
		var types := []
		for arg in method.args: types.append(int(arg.type))
		return types
	return []

func _native_signal_args(native: Object, signal_name: String) -> Array:
	for entry in native.get_signal_list():
		if entry.name != signal_name: continue
		var types := []
		for arg in entry.args: types.append(int(arg.type))
		return types
	return []

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
	_durable_publisher_tests()
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
			check("native getSubscribedItems(bool) signature", _native_method_args(native, "getSubscribedItems") == [TYPE_BOOL])
			check("native setItemTags(int, Array, bool) signature", _native_method_args(native, "setItemTags") == [TYPE_INT, TYPE_ARRAY, TYPE_BOOL])
			for s in ["item_created", "item_updated", "item_downloaded", "item_installed", "user_stats_stored"]:
				check("native signal " + s, native.has_signal(s))
				var adapter: RefCounted = load("res://tools/steam_fake_api.gd").new()
				# 4.22.1 metadata advertises two installation arguments; the real callback emits four.
				var expected: Array = [TYPE_INT, TYPE_INT] if s == "item_installed" else _native_signal_args(adapter, s)
				check("native signal argument types " + s, _native_signal_args(native, s) == expected)
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
	service._stats_reader = api # Fake read-only authority, never the live SDK.
	api.read_ok = false
	service._read_initial_state()
	check("failed initial read never seeds or writes", not service.stats_ready and service.state.stats.is_empty() and api.stat_writes == 0 and api.achievement_writes == 0 and api.stores == 0)
	api.read_ok = true
	service._read_initial_state()
	check("adapter ready after schema load", service.stats_ready)
	check("initial cache load uses no stat write probes", api.stat_writes == 0)
	service._active_run = 10
	service._context = {"mode":"ai"}
	service.settle(10, true, {})
	service.settle(10, true, {})
	check("adapter duplicate victory writes once", api.stats.TOTAL_WINS == 1 and api.stats.AI_WINS == 1)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	check("success notice cannot acknowledge or release request", service._dirty and service._store_busy)
	service._process(31.0) # A expires; its notification still has no write identity.
	service._retry_after = 0
	service._active_run = 11
	service.record_kill(11, 1)
	check("kills sent to Steam cache immediately", api.stats.TOTAL_KILLS == 1)
	api.store_ok = false
	service.flush()
	check("failed store retains dirty state", service._dirty and not service._store_busy)
	api.store_ok = true
	service._retry_after = 0
	service.flush()
	var stores_b: int = api.stores
	var revision_b: int = service._store_revision
	service.record_kill(11, 2)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	check("A late success cannot acknowledge B", service._dirty and service._store_busy and service._store_revision == revision_b)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	check("duplicate A success cannot release B", service._dirty and service._store_busy and api.stores == stores_b)
	service._retry_after = 0
	service.flush()
	check("busy request cannot be bypassed by duplicate notice", api.stores == stores_b)
	service._process(31.0)
	service._retry_after = 0
	service.flush()
	check("new progress remains eligible for bounded retry", service._dirty and service._store_busy and api.stores == stores_b + 1)
	var retained: Dictionary = service.state.stats.duplicate(true)
	var correction_writes: int = api.stat_writes
	service._on_stored(SteamAchievementCatalog.APP_ID, 8)
	api.stats.TOTAL_KILLS = 0 # Server correction, fixture only.
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	service._process(120.0)
	service._read_initial_state()
	service._sync_state()
	service.flush()
	check("correction retains local pending evidence", service.state.stats == retained and service._dirty)
	check("late success cannot reopen corrected process", not service.stats_ready and service._active_run == 0 and service._correction_required)
	check("corrected server cache is never overwritten", api.stats.TOTAL_KILLS == 0 and api.stat_writes == correction_writes)
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
	check("workshop tags use native Array signature", api.tag_calls.size() == 1 and api.tag_calls[0].tags == ["Map"] and not api.tag_calls[0].allow_admin_tags)
	api.item_updated.emit(2, false, 999001)
	check("failed update is retryable", not workshop.busy)
	workshop.publish("scenario", source, "QA retry", 2, preview)
	check("retry reuses created item", api.creates == 1 and api.submits == 2)
	api.item_updated.emit(1, true, 999001)
	check("agreement success opens mocked page", not workshop.busy and api.pages.size() == 1)
	var defense_source := WorkshopExamples.defense()
	workshop.publish("custom_defense", defense_source, "QA defense", 2, preview)
	api.item_created.emit(1, 999002, false)
	check("defense workshop uses Defense tag", api.tag_calls.size() == 3 and api.tag_calls[2].tags == ["Defense"] and not api.tag_calls[2].allow_admin_tags)
	api.item_updated.emit(1, false, 999002)
	api.subscribed = [999001]
	workshop.refresh()
	check("installed package validates", workshop.items.size() == 1 and workshop.items[0].ok)
	api.flags = 5 | 8
	workshop.refresh()
	check("updating package cannot play", not workshop.items[0].ok)
	api.flags = 5
	workshop._requested[999001] = true
	api.item_installed.emit(SteamAchievementCatalog.APP_ID + 1, 999001, 7, 8)
	check("foreign install leaves pending and listing unchanged", workshop._requested.has(999001) and not workshop.items[0].ok)
	api.item_installed.emit(SteamAchievementCatalog.APP_ID, 999001, 7, 8)
	check("four argument install refreshes playable package", workshop.items.size() == 1 and workshop.items[0].ok)
	check("installed item clears download request", not workshop._requested.has(999001))
	workshop.items.clear()
	workshop._installed(SteamAchievementCatalog.APP_ID, 999001)
	check("declared two argument install remains compatible", workshop.items.size() == 1 and workshop.items[0].ok)
	workshop.unsubscribe("999001")
	workshop.refresh()
	check("unsubscribe removes listing", workshop.items.is_empty())
	check("unsubscribe preserves local source", ScenarioStore.list_saved().has(source.title))
	var count_before: int = api.stats.TOTAL_KILLS
	api.owner = 222
	service._process(0.1)
	service.record_kill(11, 3)
	check("corrected process detects account switch without replay", not service.available and api.stats.TOTAL_KILLS == count_before)
	var normal: Node = load("res://scripts/steam_service.gd").new()
	root.add_child(normal)
	var normal_api: RefCounted = load("res://tools/steam_fake_api.gd").new()
	normal.native = normal_api
	normal.available = true
	normal.account = str(normal_api.owner)
	normal._stats_reader = normal_api
	normal._read_initial_state()
	normal._active_run = 12
	normal_api.owner = 222
	var normal_writes: int = normal_api.stat_writes
	normal.record_kill(12, 3)
	check("normal run account switch rejects old progress", not normal.available and normal_api.stats.TOTAL_KILLS == 0 and normal_api.stat_writes == normal_writes)
	normal.native = null
	normal.free()
	service.native = null
	service.available = false
	service.stats_ready = false
	service.status = "普通启动：Steam 成就不计入"
	workshop.items.clear()
	await get_tree().process_frame

func _publisher_fixture(api: RefCounted) -> Node:
	var service: Node = load("res://scripts/steam_service.gd").new()
	root.add_child(service)
	service.set_process(false)
	service.native = api
	service.available = true
	service.stats_ready = true
	service.account = str(api.owner)
	service._stats_reader = api
	var snapshot: Dictionary = api.current_snapshot()
	service.state.seed(snapshot.stats, snapshot.unlocked)
	service._sent_stats = snapshot.stats.duplicate()
	service._sent_achievements = snapshot.unlocked.duplicate()
	return service

func _durable_publisher_tests() -> void:
	var api: RefCounted = load("res://tools/steam_fake_api.gd").new()
	api.owner = 55555
	api.stats.TOTAL_KILLS = 40
	var service := _publisher_fixture(api)
	check("durable publisher adopts before gameplay", service._adopt_publisher().ok and service._publisher_enabled)
	var run_id: int = service._begin_persistent_run({"mode":"defense", "level_id":"", "waves":30})
	check("durable publisher allocates official run", run_id > 0)
	service.record_kill(run_id, 3)
	check("kills wait for durable checkpoint", api.stats.TOTAL_KILLS == 40)
	check("durable checkpoint succeeds", service._checkpoint_persistent_run().ok)
	check("checkpoint publishes absolute total", api.stats.TOTAL_KILLS == 43 and api.stores == 1)
	var binding: Dictionary = service._persistent_binding(run_id, service._context, 3)
	check("save binds to durable run", binding.ok)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	check("durable success never acknowledges receipt", service._dirty and service._store_busy)
	service._process(31.0)
	service._process(61.0)
	check("durable publisher retries after timeout", api.stores >= 2 and api.stats.TOTAL_KILLS == 43)
	service.native = null; service.available = false; service.free()
	# Restart with the same independent disk ledger and older world highwater.
	api.stats.TOTAL_KILLS = 45
	service = _publisher_fixture(api)
	check("restart adopts ledger and remote floor", service._adopt_publisher().ok and service.state.stats.TOTAL_KILLS == 45)
	var prepared: Dictionary = service._prepare_persistent_resume(binding.binding, {"mode":"defense", "level_id":"", "waves":30}, 3)
	check("restart accepts saved run identity", prepared.ok)
	if prepared.ok:
		service._install_persistent_resume(prepared)
		run_id = service._active_run
		service.record_kill(run_id, 3)
		service._checkpoint_persistent_run()
		check("replayed kills do not increment after restart", api.stats.TOTAL_KILLS == 45)
		service.record_kill(run_id, 4)
		service._checkpoint_persistent_run()
		check("new kill increments preserved remote floor", api.stats.TOTAL_KILLS == 46)
		service.settle(run_id, true, {})
		service._checkpoint_persistent_run()
		service.settle(run_id, true, {})
		service._checkpoint_persistent_run()
		check("durable duplicate terminal counts once", api.stats.TOTAL_WINS == 1 and api.stats.DEFENSE_WINS == 1)
		check("terminal run cannot resume old slot", not service._prepare_persistent_resume(binding.binding, {"mode":"defense", "level_id":"", "waves":30}, 3).ok)
	service.native = null; service.available = false; service.free()
	service = _publisher_fixture(api)
	check("settled publisher reopens in new process", service._adopt_publisher().ok and service._active_run == 0)
	var old_slot: Dictionary = service._prepare_persistent_resume(binding.binding, {"mode":"defense", "level_id":"", "waves":30}, 3)
	check("settled Steam run refused after restart", old_slot.get("code") == "RUN_TERMINAL")
	var writes: int = api.stat_writes
	service._on_stored(SteamAchievementCatalog.APP_ID, 8)
	service._on_stored(SteamAchievementCatalog.APP_ID, 1)
	service._process(120.0)
	check("durable correction stops further SDK writes", service._correction_required and not service.stats_ready and api.stat_writes == writes)
	service.native = null; service.available = false; service.free()
	service = _publisher_fixture(api)
	api.read_ok = false
	check("correction with failed read cannot publish", not service._adopt_publisher().ok and not service._publisher_enabled and api.stat_writes == writes)
	api.read_ok = true
	api.stats.TOTAL_KILLS = 2
	api.stats.TOTAL_WINS = 0
	api.stats.DEFENSE_WINS = 0
	api.achievements.clear()
	check("restart accepts corrected server values", service._adopt_publisher().ok and service._publisher_enabled and service.state.stats.TOTAL_KILLS == 2 and service.state.stats.TOTAL_WINS == 0)
	check("correction keeps old run terminal", not service._prepare_persistent_resume(binding.binding, {"mode":"defense", "level_id":"", "waves":30}, 3).ok)
	var fresh_run: int = service._begin_persistent_run({"mode":"defense", "level_id":"", "waves":30})
	service.record_kill(fresh_run, 1)
	service._checkpoint_persistent_run()
	check("new run counts after correction", fresh_run > 0 and api.stats.TOTAL_KILLS == 3)
	service.native = null; service.available = false; service.free()
