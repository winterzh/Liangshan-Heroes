extends SceneTree
func _initialize() -> void:
    check.call_deferred()
func check() -> void:
    var paths: Variant = JSON.parse_string(OS.get_environment("LOAD_SCRIPT_PATHS"))
    if not paths is Array or paths.size() != 14:
        push_error("INVALID_LOAD_ONLY_INVENTORY")
        quit(2)
        return
    for path: String in paths:
        var script: Script = load(path)
        if script == null or not script.can_instantiate():
            push_error("LOAD_ONLY_INVALID: " + path)
            quit(2)
            return
        print("LOAD_ONLY_PASS " + path)
    print("FOURTEEN_SCRIPTS_LOADED_WITHOUT_INSTANTIATION")
    quit(0)
