extends SceneTree
func _initialize() -> void:
    call_deferred("probe")
func probe() -> void:
    var mode := OS.get_environment("META_MODE")
    var retained: RefCounted
    if mode == "engine_builtin": retained = RefCounted.new()
    else: retained = load("res://holder.gd").new()
    if mode == "root_script": root.set_meta("shutdown_fixture", retained)
    else: Engine.set_meta("shutdown_fixture", retained)
    print("METADATA_RETAINED ", mode)
    quit(0)
