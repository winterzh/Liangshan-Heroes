extends SceneTree
func _initialize() -> void:
    check.call_deferred()
func check() -> void:
    var paths: Variant = JSON.parse_string(OS.get_environment("LOAD_SCRIPT_PATHS"))
    if not paths is Array or paths.size() != 3:
        push_error("INVALID_UI_LOAD_ONLY_INVENTORY")
        quit(2)
        return
    for path: String in paths:
        var script: Script = load(path)
        if script == null or not script.can_instantiate():
            push_error("LOAD_ONLY_INVALID: " + path)
            quit(2)
            return
        print("LOAD_ONLY_PASS " + path)
    var active: Dictionary = {"request":{},"original_sha256":"","original_owner":"","transaction":"","stage":"building"}
    active.semantics_sha256 = "probe"
    active.stage = "staging"
    var keys: Array = []
    for key in active: keys.append({"text":String(key),"type":typeof(key)})
    var codec: Script = load("res://scripts/run_state_value_codec.gd")
    var result: Dictionary = codec.new().encode(active)
    print("CONFIG_ACTIVE_KEY_PROBE " + JSON.stringify({"keys":keys,"result":result}))
    if typeof(active.keys().back()) != TYPE_STRING_NAME or result.get("ok",true) or result.get("code") != "UNSUPPORTED_TYPE":
        push_error("CONFIG_ACTIVE_KEY_PROBE_UNEXPECTED")
        quit(3)
        return
    print("THREE_UI_SCRIPTS_LOADED_WITHOUT_INSTANTIATION")
    quit(0)
