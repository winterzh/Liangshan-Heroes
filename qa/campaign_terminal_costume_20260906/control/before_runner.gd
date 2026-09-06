extends "res://tools/campaign_terminal_costume_qa.gd"
func _run() -> void:
	var art=root.get_node("Art")
	art.set_script(load("res://qa/campaign_terminal_costume_20260906/control/art_db_73fb3a8.gd"))
	art._ready()
	await super._run()
