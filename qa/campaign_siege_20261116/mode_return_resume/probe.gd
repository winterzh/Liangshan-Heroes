extends "res://qa/campaign_siege_20261116/menu_resume/probe.gd"
## Simulates returning from epic defense with the launch preferences retained.

func _save() -> void:
	var campaign = root.get_node("Campaign")
	campaign.defense_waves = 60
	campaign.defense_hero_cap = 6
	await super._save()

func _saved(result: Dictionary, state: Dictionary) -> void:
	if result.get("ok",false):
		var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
		check(slot.ok,"validated campaign slot is readable after saving with six-hero preference")
		if slot.ok:
			var options: Dictionary = load("res://scripts/run_state_value_codec.gd").new().decode(slot.document.options)
			check(options.ok and options.value.defense_hero_cap == 6,"campaign slot retains the six-hero defense preference")
	super._saved(result,state)

func _resume() -> void:
	check(root.get_node("Campaign").defense_hero_cap == 4,"independent process begins at the normal default preference")
	await super._resume()

func _restored(result: Dictionary, menu: WeakRef, previous: Dictionary) -> void:
	if result.get("ok",false):
		check(root.get_node("Campaign").defense_hero_cap == 6,"restoring the campaign retains the saved defense preference")
	super._restored(result,menu,previous)

func _finish() -> void:
	print("ZHU_MENU_RESULT ",JSON.stringify({"stage":stage,"pid":OS.get_process_id(),
		"checks":checks,"failures":failures,"facts":facts}))
	if failures.is_empty():
		if stage != "save":
			root.get_node("AppLifecycle").request_quit("zhu_mode_return_resume_fixture")
	else:
		root.get_node("Sfx").shutdown()
		root.get_node("Music").shutdown()
		quit.call_deferred(1)
