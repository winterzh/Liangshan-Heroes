extends SceneTree

func _initialize() -> void:
	_boot.call_deferred()

func _boot() -> void:
	var suite: Node = load("res://tools/steam_integration_suite.gd").new()
	root.add_child(suite)
