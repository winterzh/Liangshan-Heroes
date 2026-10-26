extends Node
## Synthetic component fixture only. No Battle instance, world mounting or gameplay.
const Codec := preload("res://scripts/run_state_value_codec.gd")
const Baseline := preload("res://scripts/run_visual_graph.gd")
const BattleScript := preload("res://scripts/battle.gd")
const UnitScript := preload("res://scripts/unit.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const ProjectileState := preload("res://scripts/run_projectile_state.gd")
var candidate: Script
var checks: Array = []
var failures: Array = []
var negatives: Array = []
var observations: Dictionary = {}
var roots: Array[Node] = []
var graphs: Array = []
var prior_paused := false
var pause_owned := false
var wire: Dictionary = {}
var source: Node2D
var projectile: Node2D
var blink: Node2D
var before_frame := 0
const VERSION := "synthetic-projectile-filter-component-v1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func check(ok: bool, label: String, detail: Variant = null) -> bool:
	var row: Dictionary = {"label":label,"passed":ok}
	if detail != null: row["detail"] = detail
	checks.append(row)
	if not ok: failures.append(label)
	print("PROJECTILE_FILTER ", "PASS " if ok else "FAIL ", label)
	return ok

func graph(script: Script) -> RefCounted:
	var value: RefCounted = script.new(Codec, BattleScript, UnitScript, null, {}, ProjectileState.new(Codec, ProjectileScript, UnitScript))
	graphs.append(value)
	return value

func holder(label: String) -> Node2D:
	var node := Node2D.new()
	node.name = label
	add_child(node)
	roots.append(node)
	return node

func negative(node: Node2D, field: String, value: Variant, label: String, kind: String) -> void:
	var original: Variant = node.get(field)
	node.set(field, value) # Deliberate mutation of this synthetic fixture, never a game world.
	var rejected: Dictionary = graph(candidate).capture(source, VERSION, {})
	node.set(field, original)
	var exact: bool = not rejected.get("ok", false) and rejected.get("code") == "TIMED_RENDER_OVERRIDE" and rejected.get("field") == kind
	check(exact, label, rejected)
	negatives.append({"label":label,"passed":exact,"field":field,"kind":kind,"code":rejected.get("code","")})
	var restored: Dictionary = graph(candidate).capture(source, VERSION, {})
	check(restored.get("ok", false) and restored.get("value") == wire, "fixture restored exactly after " + label)

func run() -> void:
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	if not check(OS.get_environment("STEAM_DISABLED") == "1" and OS.get_environment("CAMPAIGN_QA").is_empty() and OS.get_environment("LSH_CONTINUE_FLOW_QA").is_empty(), "component environment keeps SDK and private campaign gate disabled"):
		finish(); return
	for frame: int in range(240):
		if ContinueFlow.can_launch_new_run(): break
		await get_tree().process_frame
	if not check(ContinueFlow.can_launch_new_run(), "normal isolated autoload startup completed without a game world"):
		finish(); return
	while Engine.is_in_physics_frame(): await get_tree().process_frame
	var binding_path: String = OS.get_environment("PF_BINDINGS")
	if not check(not binding_path.is_empty() and FileAccess.get_sha256(binding_path) == OS.get_environment("PF_BINDINGS_SHA"), "native bindings exact bytes"):
		finish(); return
	var bindings: Variant = JSON.parse_string(FileAccess.get_file_as_string(binding_path))
	if not check(bindings is Dictionary and bindings.get("schema") == "projectile_filter_bindings_v1" and bindings.get("nonce") == OS.get_environment("PF_NONCE") and bindings.get("profile") == OS.get_environment("PF_PROFILE"), "native bindings match isolated process nonce and profile"):
		finish(); return
	if not check(not DirAccess.dir_exists_absolute("user://continue") and not DirAccess.dir_exists_absolute("user://steam_receipts") and not FileAccess.file_exists("user://campaign.cfg") and not DirAccess.dir_exists_absolute("user://campaign_cfg_candidates") and not DirAccess.dir_exists_absolute("user://campaign_cfg_transactions"), "fresh profile has no campaign slot or reward business files"):
		finish(); return
	var path: String = OS.get_environment("PF_CANDIDATE")
	if not check(not path.is_empty() and FileAccess.get_sha256(path) == OS.get_environment("PF_CANDIDATE_SHA"), "external candidate exact SHA before loading"):
		finish(); return
	candidate = load(path)
	if not check(candidate != null and candidate.can_instantiate(), "candidate graph compiles with installed autoload dependencies"):
		finish(); return
	prior_paused = get_tree().paused
	get_tree().paused = true
	pause_owned = true
	before_frame = Engine.get_physics_frames()
	var source_parent: Node2D = holder("SyntheticSource")
	source = Node2D.new()
	source.name = "FxRoot"
	source_parent.add_child(source)
	projectile = ProjectileScript.new()
	projectile.name = "Projectile"
	source.add_child(projectile) # Native creator _ready, no direct filter assignment.
	blink = BattleScript.BlinkShotFx.new()
	blink.name = "Blink"
	source.add_child(blink)
	check(projectile.is_node_ready() and projectile.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "native projectile creator derives MIP filter")
	check(blink.is_node_ready() and blink.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "other native timed creator retains PARENT filter")
	var rejected: Dictionary = graph(Baseline).capture(source, VERSION, {})
	observations["baseline_result"] = rejected
	check(not rejected.get("ok",false) and rejected.get("code") == "TIMED_RENDER_OVERRIDE" and rejected.get("field") == "projectile", "baseline reproduces exact native projectile filter rejection")
	var captured: Dictionary = graph(candidate).capture(source, VERSION, {})
	if not check(captured.get("ok",false) and captured.get("count") == 3, "candidate captures real ready mixed graph", captured if not captured.get("ok",false) else null):
		finish(); return
	wire = captured.value
	var prepared_graph: RefCounted = graph(candidate)
	var prepared: Dictionary = prepared_graph.prepare(wire, VERSION, {})
	if not check(prepared.get("ok",false) and prepared.get("created_count") == 3, "candidate validates and prepares exact detached graph", prepared if not prepared.get("ok",false) else null):
		finish(); return
	var restored: Node2D = prepared.root
	var restored_projectile: Node2D = prepared.nodes["2"]
	check(not restored.is_inside_tree() and not restored_projectile.is_node_ready() and restored_projectile.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "detached factory shell has not run _ready or received a fabricated filter")
	var destination: Node2D = holder("SyntheticRestored")
	destination.add_child(restored)
	check(get_tree().paused and restored_projectile.is_node_ready() and restored_projectile.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "paused native attach executes original _ready and preserves derived MIP filter")
	var activated: Dictionary = prepared_graph.activate()
	if not check(activated.get("ok",false), "original graph activation succeeds while paused", activated):
		finish(); return
	var recaptured: Dictionary = graph(candidate).capture(restored, VERSION, {})
	var codec := Codec.new()
	var first_bytes: Dictionary = codec.encode(wire)
	var next_bytes: Dictionary = codec.encode(recaptured.get("value"))
	observations["roundtrip_exact"] = recaptured.get("ok",false) and recaptured.get("value") == wire
	check(observations.roundtrip_exact and first_bytes.get("ok",false) and next_bytes.get("ok",false) and JSON.stringify(first_bytes.value) == JSON.stringify(next_bytes.value), "capture prepare attach activate recapture preserves exact typed wire")
	observations["restored_filter"] = restored_projectile.texture_filter
	observations["record_count"] = captured.count
	negative(projectile,"texture_filter",CanvasItem.TEXTURE_FILTER_PARENT_NODE,"projectile rejects PARENT","projectile")
	negative(projectile,"texture_filter",CanvasItem.TEXTURE_FILTER_NEAREST,"projectile rejects NEAREST","projectile")
	negative(projectile,"texture_filter",CanvasItem.TEXTURE_FILTER_LINEAR,"projectile rejects LINEAR","projectile")
	negative(projectile,"texture_filter",CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,"projectile rejects nearest MIP","projectile")
	negative(projectile,"material",CanvasItemMaterial.new(),"projectile rejects material","projectile")
	negative(projectile,"use_parent_material",true,"projectile rejects inherited material override","projectile")
	negative(projectile,"texture_repeat",CanvasItem.TEXTURE_REPEAT_ENABLED,"projectile rejects repeat override","projectile")
	negative(projectile,"light_mask",2,"projectile rejects light mask override","projectile")
	negative(projectile,"visibility_layer",2,"projectile rejects visibility layer override","projectile")
	negative(projectile,"clip_children",CanvasItem.CLIP_CHILDREN_ONLY,"projectile rejects clipping override","projectile")
	negative(blink,"texture_filter",CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"other timed kind still rejects MIP filter","blink_shot")
	negative(blink,"material",CanvasItemMaterial.new(),"other timed kind still rejects material","blink_shot")
	check(negatives.size() == 12 and negatives.all(func(row): return row.passed), "all twelve independent render negatives reject")
	check(Engine.get_physics_frames() == before_frame and get_tree().paused, "entire component transaction has no await physics or damage tick")
	check(not DirAccess.dir_exists_absolute("user://continue") and not DirAccess.dir_exists_absolute("user://steam_receipts") and not FileAccess.file_exists("user://campaign.cfg") and not DirAccess.dir_exists_absolute("user://campaign_cfg_candidates") and not DirAccess.dir_exists_absolute("user://campaign_cfg_transactions"), "component created no campaign slot or reward business files")
	finish()

func finish() -> void:
	for value: Variant in graphs: value.dispose()
	graphs.clear()
	for node: Node in roots:
		if is_instance_valid(node): node.free()
	roots.clear()
	if pause_owned: get_tree().paused = prior_paused
	var result: Dictionary = {"schema":"projectile_filter_component_v1", "passed":failures.is_empty(), "checks":checks, "failures":failures,
		"user_data_dir":ProjectSettings.globalize_path("user://"), "pid":OS.get_process_id(), "nonce":OS.get_environment("PF_NONCE"), "profile":OS.get_environment("PF_PROFILE"),
		"candidate_sha256":OS.get_environment("PF_CANDIDATE_SHA"), "bindings_sha256":OS.get_environment("PF_BINDINGS_SHA"),
		"synthetic_fixture":true, "gameplay_state_modified":false, "native_gameplay_qualified":false,
		"public_continue_qualified":false,"sdk_qualified":false,"negative_cases":negatives,"observations":observations}
	var file := FileAccess.open(OS.get_environment("PF_REPORT"),FileAccess.WRITE)
	if file == null: push_error("PROJECTILE_FILTER_REPORT_WRITE"); get_tree().quit(2); return
	file.store_string(JSON.stringify(result,"  "))
	file.flush()
	var error: int = file.get_error()
	file.close()
	if error != OK: push_error("PROJECTILE_FILTER_REPORT_FLUSH"); get_tree().quit(2); return
	get_tree().quit(0 if failures.is_empty() else 1)
