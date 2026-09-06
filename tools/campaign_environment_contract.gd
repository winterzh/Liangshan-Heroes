extends "res://tools/campaign_environment_capture.gd"
## 完整项目上下文中的兼容回归，不采图、不写游戏存档。
func _run() -> void:
	var out := OS.get_environment("CAMPAIGN_CAPTURE_DIR")
	var campaign := root.get_node("Campaign")
	for key in ["skirmish","skirmish_ai","arena","custom_defense","scenario","ai_friendly","scale_on"]: campaign.set(key,false)
	var results := []
	# 自由玩法不能误套战役坐标、材质或楼房替换表。
	for mode in ["skirmish","skirmish_ai","arena","custom_defense"]:
		if mode=="custom_defense": campaign.custom_config={"name":"contract"}
		campaign.set(mode,true)
		seed(5088120)
		var b = load("res://scenes/main.tscn").instantiate()
		root.add_child(b)
		await process_frame
		b.set_process(false)
		for u in b.units: u.set_physics_process(false)
		results.append({"name":mode,"passed":b.map.sample_scenery==null and root.get_node("Art").environment_buildings.is_empty(),"level":b.level.id()})
		b.queue_free()
		await process_frame
		await process_frame
		campaign.set(mode,false)
		if mode=="custom_defense": campaign.custom_config={}
	var passed := results.all(func(r):return r.passed)
	_save(out.path_join("compatibility.json"),{"passed":passed,"results":results})
	print("[campaign_contract] ",JSON.stringify(results))
	quit(0 if passed else 6)
