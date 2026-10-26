extends SceneTree

func _initialize() -> void:
	call_deferred("start_component")

func start_component() -> void:
	var worker: Script = load(OS.get_environment("PLI_WORKER"))
	if worker == null or not worker.can_instantiate():
		var file := FileAccess.open(OS.get_environment("PLI_REPORT"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"passed": false, "code": "WORKER_COMPILE", "pid": OS.get_process_id(), "nonce": OS.get_environment("PLI_NONCE")}))
			file.close()
		quit(2)
		return
	worker.new().run(self)
