extends "res://qa/campaign_siege_20261116/mode_return_resume/probe.gd"

func _run() -> void:
	stage = OS.get_environment("ZHU_MENU_STAGE")
	flow = root.get_node("ContinueFlow")
	flow.set_script(load("res://qa/campaign_siege_20261116/player_continue/platform_entry.gd"))
	check(not flow._private_qa_enabled(),"campaign-private entry is disabled")
	AudioServer.set_bus_mute(0,true)
	root.get_node("Settings").edge_scroll = false
	match stage:
		"save":
			_check_menu_policy()
			await _save()
		"resume":
			# The slot must choose its own chapter when browsing another one.
			root.get_node("Campaign").current = 7
			await _resume()
		_:
			check(false,"known stage")
			_finish()

func _check_menu_policy() -> void:
	var campaign = root.get_node("Campaign")
	var profiles: Script = load("res://scripts/run_official_restore_profile.gd")
	var battle_mode := {"mode":"campaign","level_id":"level3","waves":0}
	check(profiles.is_player_campaign_context(battle_mode),"Zhu Manor is explicitly admitted")
	for index in range(campaign.LEVELS.size()):
		campaign.current = index
		var id: String = campaign.LEVELS[index].id
		var expected := {"mode":"campaign","level_id":id,"waves":0}
		check(flow._player_launch_context() == expected,"normal campaign choice has expected scope " + campaign.LEVELS[index].id)
	campaign.skirmish = true
	check(flow._player_launch_context() == {"mode":"defense","level_id":"","waves":30},"classic 30-wave defense stays supported")
	campaign.defense_waves = 60
	campaign.defense_hero_cap = 6
	check(flow._player_launch_context().is_empty(),"epic 60-wave defense remains outside the slot scope")
	campaign.skirmish = false
	campaign.arena = true
	check(flow._player_launch_context().is_empty(),"arena remains outside the slot scope")
	campaign.arena = false
