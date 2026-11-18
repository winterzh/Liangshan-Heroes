extends SceneTree
## Isolated cross-version continuation. Fixture creation is external to the game.

var flow: Node
var old_slot: Dictionary
var stage: String

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	flow = root.get_node("ContinueFlow")
	stage = OS.get_environment("LSH_FIXTURE_STAGE")
	var profile := OS.get_environment("APPDATA").replace("\\", "/")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless" \
			or not profile.contains("/legacy-windows-") or stage not in ["resave", "finish", "reject"]:
		_fail("an isolated rendered legacy test profile is required")
		return
	AudioServer.set_bus_mute(0, true)
	var deadline := Time.get_ticks_msec() + 60000
	while not flow.can_launch():
		if flow.phase == flow.Phase.ERROR or Time.get_ticks_msec() >= deadline:
			_fail("startup: " + str(flow.last_result))
			return
		await process_frame
	old_slot = _read_slot()
	if not old_slot.ok:
		_fail("input: " + str(old_slot))
		return
	var saved := old_slot.document as Dictionary
	var version: Script = load("res://scripts/run_campaign_save_version.gd")
	if saved.world.engine_sha256 != version.BUILD_26735223_EXE or saved.world.content_version != version.BUILD_26735223_CONTENT:
		_fail("fixture requires exact published identity fields")
		return
	var menu := load("res://scenes/menu.tscn").instantiate() as Node
	root.add_child(menu)
	current_scene = menu
	var entry := menu.find_child("ContinueBattle", true, false) as Button
	if entry == null:
		_fail("missing continue button")
		return
	flow.operation_finished.connect(_continued, CONNECT_ONE_SHOT)
	entry.pressed.emit()


func _read_slot() -> Dictionary:
	return load("res://scripts/run_slot_store.gd").new().read_slot()


func _continued(result: Dictionary) -> void:
	var slot := _read_slot()
	if not slot.ok or slot.file_sha256 != old_slot.file_sha256:
		_fail("reading changed the legacy slot")
		return
	if stage == "reject":
		if result.get("code") != "LOCAL_RUN_TERMINAL":
			_fail("settled slot: " + str(result))
			return
		print("LEGACY_TERMINAL_REJECTED ", slot.revision)
		flow.dismiss_error()
		root.get_node("AppLifecycle").request_quit("legacy_terminal_probe")
		return
	if not result.ok:
		_fail("continue: " + str(result))
		return
	var battle := current_scene
	if battle.level.id() != old_slot.document.context.level_id or battle._continue_receipt == null \
			or battle._continue_receipt.token != old_slot.document.binding.token \
			or battle._gameplay_content_identity.engine_binary_sha256 != old_slot.document.world.engine_sha256:
		_fail("restored battle identity")
		return
	print("LEGACY_CONTINUED ", slot.revision)
	_after_continue.call_deferred(battle)


func _after_continue(battle: Node) -> void:
	if stage == "finish":
		# Use a controlled outcome to exercise the original run journal,
		# independent of scoring the chapter's gameplay.
		flow.operation_finished.connect(_finished, CONNECT_ONE_SHOT)
		battle.lose("legacy save QA")
		return
	battle._close_pause()
	for step in range(12):
		await process_frame
	RenderingServer.force_draw(false)
	battle._open_pause()
	var saver := battle.hud.find_child("SaveAndExit", true, false) as Button
	if saver == null:
		_fail("missing save button")
		return
	flow.operation_finished.connect(_resaved, CONNECT_ONE_SHOT)
	saver.pressed.emit()
	if flow.phase == flow.Phase.CONFIRM:
		flow.confirm_save()


func _resaved(result: Dictionary) -> void:
	if not result.ok:
		_fail("resave: " + str(result))
		return
	var slot := _read_slot()
	if not slot.ok or slot.revision != old_slot.revision + 1 or slot.previous != old_slot.file_sha256 \
			or slot.document.binding != old_slot.document.binding \
			or slot.document.world.engine_sha256 != old_slot.document.world.engine_sha256:
		_fail("new generation did not preserve previous version and binding")
		return
	print("LEGACY_RESAVED ", slot.revision)


func _finished(result: Dictionary) -> void:
	if not result.get("terminal_completed", false) or not result.get("campaign_progress_committed", false):
		_fail("terminal: " + str(result))
		return
	var battle := current_scene
	var receipt: RefCounted = battle._continue_receipt
	var terminal: Dictionary = receipt.open_head()
	if not terminal.ok or terminal.revision != 3 or terminal.document.state != "terminal" \
			or terminal.document.token != old_slot.document.binding.token or terminal.document.scope.engine_sha256 != old_slot.document.world.engine_sha256:
		_fail("original terminal journal did not commit")
		return
	print("LEGACY_TERMINAL_COMMITTED")
	root.get_node("AppLifecycle").request_quit("legacy_terminal_probe")


func _fail(detail: String) -> void:
	push_error("LEGACY_PROBE_FAILURE " + detail)
	quit(2)
