extends "base.gd"
## Independent source/package process restores a genuinely moving original empty cart.
func _run() -> void:
	if not identity(OS.get_environment("HG_SOURCE_MODE") != "0"): report(); return
	var battle: Variant = await restore_checkpoint("empty")
	if battle == null: report(); return
	var level: Variant = battle.level
	var actor: Variant = level.empty_cargo[6]
	var original_position: Vector2 = actor.position
	var original_cart: Variant = level.jujube_carts[6]
	root.get_node("Settings").game_speed = 1.0
	Engine.time_scale = 1.0
	get_tree().paused = false
	_action(battle, actor, "force_load_6_0")
	check(await wait_until(func(): return level.cargo.has(6) or battle.phase == battle.Phase.END, 100.0), "cold seventh empty cart completes actual loading route")
	check(actor.position.distance_to(original_position)>20.0, "restored empty-carrier really traverses remaining path")
	check(level.cargo.size()==1 and level.cargo.get(6)==actor and level.empty_cargo.size()==6 and not level.empty_cargo.has(6), "only seventh cart changes from empty to loaded ownership")
	check(level.delivered==0 and level.st==level.CARRY and level.cargo_ready.get(6,false), "loading does not deliver or end chapter")
	check(level.jujube_carts[6]==original_cart and not level.jujube_carts[6].visible and not battle.units.has(level.bundles[6]), "original seventh cart and load are retained and stowed after real load")
	battle.select_single(actor,false)
	check(not battle.mission.request_action("force_load_6_0") and level.cargo.size()==1 and level.delivered==0,"completed load request cannot create or credit duplicate cargo")
	if failures.is_empty():
		await checkpoint_save(battle,"cold_empty_seventh_loaded_resaved")
		check(checkpoint.get("generation",0)==int(source_checkpoint.generation)+1,"restored empty transit can be saved again after real loading")
		check(checkpoint.get("empty_carried",{}).size()==6 and checkpoint.get("carried",{}).size()==1,"second save preserves mixed six-empty and one-loaded cart state")
	report({"scope":"Independent restore and actual resumed loading of original seventh empty cart, then real second save",
		"producer_pid":producer_report.pid,"producer_checkpoint":source_checkpoint,"checkpoint":checkpoint,
		"coordinates_or_mission_state_injected":false,"full_campaign_continue_accepted":false})
