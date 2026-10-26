extends "base.gd"
## Independent process restore of a naturally reached in-transit seventh cart.
var delivery_rejections: Array = []

func reject_inconsistent_delivery_events(battle: Variant, store: Variant) -> void:
	# Mutate only deep in-memory copies of the actual second saved world. The
	# original slot, lifecycle, installed Mission and live cargo are read-only.
	var slot: Dictionary = store.read_slot()
	check(slot.get("ok", false), "delivery rejection source is the actual readable second save")
	if not slot.get("ok", false): return
	var before_inventory: Dictionary = store.inventory()
	check(before_inventory.get("ok", false), "delivery rejection snapshots all slot journal hashes")
	if not before_inventory.get("ok", false): return
	var slot_sha: String = slot.file_sha256
	var original_world_sha: String = JSON.stringify(slot.document.world).sha256_text()
	var live_events: Array = battle.mission.events.keys().duplicate()
	var live_factions: Array = battle.level.bundles.map(func(u): return u.faction)
	var live_delivered: int = battle.level.delivered
	var runtime: Dictionary = load("res://scripts/run_level1_world_factory.gd").prepare_runtime(trusted)
	check(runtime.get("ok", false), "real runtime prepares delivery consistency checks")
	if not runtime.get("ok", false): return
	var codec: Variant = load("res://scripts/run_state_value_codec.gd").new()
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	for case_name in ["missing_actual_seventh_delivery", "extra_undelivered_first_cart"]:
		var world: Dictionary = slot.document.world.duplicate(true)
		var decoded: Dictionary = codec.decode(world.sections.mission.payload)
		check(decoded.get("ok", false), case_name + ": actual saved Mission payload decodes")
		if not decoded.get("ok", false): continue
		var raw: Dictionary = decoded.value
		check(raw.events.has("force_delivered_6") and not raw.events.has("force_delivered_0"), case_name + ": baseline has exactly the actual seventh delivery")
		if not raw.events.has("force_delivered_6") or raw.events.has("force_delivered_0"): continue
		if case_name == "missing_actual_seventh_delivery": raw.events.erase("force_delivered_6")
		else: raw.events.append("force_delivered_0")
		var encoded: Dictionary = codec.encode(raw)
		check(encoded.get("ok", false), case_name + ": altered copy re-encodes through actual value Codec")
		if not encoded.get("ok", false): continue
		world.sections.mission.payload = encoded.value
		var core: Variant = load("res://scripts/run_battle_world_core.gd").new(trusted, runtime.runtime)
		var rejected: Dictionary = core.prepare(world)
		core.dispose()
		check(not rejected.get("ok", true) and rejected.get("code", "") == "LEVEL1_DELIVERY_FACTION" and rejected.get("section", "") == "units", case_name + ": actual Core rejects Mission-versus-cargo mismatch")
		check(current_scene == battle and battle.level.delivered == live_delivered and battle.mission.events.keys() == live_events and battle.level.bundles.map(func(u): return u.faction) == live_factions, case_name + ": installed live world is untouched")
		check(store.read_slot().get("file_sha256", "") == slot_sha and store.inventory() == before_inventory, case_name + ": complete original slot journal remains byte-identical")
		delivery_rejections.append({"case": case_name, "result": rejected, "original_slot_sha256": slot_sha, "mutated_only_in_memory": true})
	check(JSON.stringify(slot.document.world).sha256_text() == original_world_sha, "deep-copy negative cases retain original saved world object")
	get_tree().paused = was_paused

func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	var battle: Variant = await restore_checkpoint()
	if battle == null: report(); return
	var level: Variant = battle.level
	var actor: Variant = level.cargo[6]
	var start_position: Vector2 = actor.position
	root.get_node("Settings").game_speed = 1.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	_action(battle, actor, "force_deliver_6_0")
	check(await wait_until(func(): return level.delivered > 0 or battle.phase == battle.Phase.END, 100.0), "restored seventh cart finishes a real player delivery")
	check(actor.position.distance_to(start_position) > 30.0, "restored seventh cart physically traverses the world")
	check(level.delivered == 1 and level.cargo.size() == 6 and not level.cargo.has(6) and level._delivered_cart_indices(battle) == [6], "exactly seventh cart credits one load while six remain carried")
	check(level.st == level.CARRY and battle.units.has(level.bundles[6]) and level.bundles[6].visible, "partial delivery retains carry stage and original ground cart")
	check(range(7,11).all(func(i): return not battle.units.has(level.bundles[i]) and not level.bundles[i].visible), "secondary four loads remain packed")
	battle.select_single(actor, false)
	check(not battle.mission.request_action("force_deliver_6_0") and level.delivered == 1, "repeated completed seventh delivery cannot credit another load")
	var store: Variant = load("res://scripts/run_slot_store.gd").new("user://hg_transport_world/v1")
	check(store.read_slot().file_sha256 == source_checkpoint.saved_sha256, "live continuation alone does not rewrite frozen slot")
	if failures.is_empty():
		await checkpoint_save(battle, "cold_seventh_delivered_resaved")
		check(checkpoint.get("generation", 0) == int(source_checkpoint.generation) + 1 and checkpoint.get("saved_sha256", "") != source_checkpoint.saved_sha256, "second real save increments generation and writes changed state")
		check(checkpoint.get("delivered_loads", -1) == 1 and checkpoint.get("carried", {}).size() == 6, "second saved record contains actual post-restart seventh delivery")
		if failures.is_empty(): reject_inconsistent_delivery_events(battle, store)
		check(delivery_rejections.size() == 2, "both missing and extra delivery-event records checked")
	report({"scope": "Internal isolated save, independent process restoration, actual seventh-cart delivery and real second save",
		"producer_pid": producer_report.pid, "producer_checkpoint": source_checkpoint, "checkpoint": checkpoint, "delivery_event_rejections": delivery_rejections,
		"full_campaign_continue_accepted": false, "coordinates_or_mission_state_injected": false})
