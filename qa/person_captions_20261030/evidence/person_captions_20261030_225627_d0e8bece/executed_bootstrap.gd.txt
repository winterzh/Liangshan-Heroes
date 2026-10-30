extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var worker := OS.get_environment("HG_WORKER")
	if OS.get_environment("STEAM_DISABLED") != "1" or FileAccess.get_sha256(worker) != OS.get_environment("HG_WORKER_SHA"):
		push_error("PERSON_CAPTIONS_PRIVATE_WORKER_MISMATCH")
		quit(2)
		return
	var script: Script = load(worker)
	if script == null or not script.can_instantiate():
		quit(2)
		return
	root.add_child(script.new())
