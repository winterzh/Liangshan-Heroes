extends SceneTree
## CR_ contract: candidate autoloads exist before loading the external training worker.
## STEAM_DISABLED=1, CAMPAIGN_QA empty; CR_WORKERS and CR_WORKER_SHA256 bind this copy.
func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	var folder := OS.get_environment("CR_WORKERS").replace("\\", "/").simplify_path()
	var worker := folder.path_join("training.gd")
	if OS.get_environment("STEAM_DISABLED") != "1" or not OS.get_environment("CAMPAIGN_QA").is_empty() \
			or not folder.is_absolute_path() \
			or FileAccess.get_sha256(worker) != OS.get_environment("CR_WORKER_SHA256"):
		push_error("CAMPAIGN_TRAINING_WORKER_BINDING"); quit(2); return
	var script: Script = load(worker)
	if script == null or not script.can_instantiate():
		push_error("CAMPAIGN_TRAINING_WORKER_LOAD"); quit(2); return
	root.add_child(script.new())
