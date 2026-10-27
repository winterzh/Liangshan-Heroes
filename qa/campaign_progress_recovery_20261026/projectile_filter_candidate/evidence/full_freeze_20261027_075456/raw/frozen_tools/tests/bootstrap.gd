extends SceneTree
func _initialize() -> void:
	start.call_deferred()
func start() -> void:
	while Engine.is_in_physics_frame(): await process_frame
	var path: String = OS.get_environment("PF_WORKER")
	if path.is_empty() or FileAccess.get_sha256(path) != OS.get_environment("PF_WORKER_SHA"):
		push_error("PROJECTILE_FILTER_WORKER_BINDING")
		quit(2)
		return
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		push_error("PROJECTILE_FILTER_WORKER_INVALID")
		quit(2)
		return
	root.add_child(script.new())
