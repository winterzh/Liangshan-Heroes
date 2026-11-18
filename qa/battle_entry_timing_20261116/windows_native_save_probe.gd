extends Node
## External driver for an isolated copy of the Windows export, loaded by
## override.cfg. It calls the installed menu, pause and continue buttons.

const MENU := "res://scenes/menu.tscn"
const BATTLE := "res://scenes/main.tscn"

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	var flow := tree.root.get_node("ContinueFlow")
	var campaign := tree.root.get_node("Campaign")
	var chapter := OS.get_environment("LSH_FIXTURE_LEVEL")
	var stage := OS.get_environment("LSH_FIXTURE_STAGE")
	var expected_sha := OS.get_environment("LSH_FIXTURE_EXE_SHA")
	if not flow._private_qa_enabled() or DisplayServer.get_name() == "headless" \
			or campaign.index_for_id(chapter) < 0 or stage not in ["save", "restore"] \
			or expected_sha.length() != 64:
		_fail("expected rendered export, isolated profile, chapter and exact EXE identity")
		return
	AudioServer.set_bus_mute(0, true)
	var menu := load(MENU).instantiate() as Node
	tree.root.add_child(menu)
	tree.current_scene = menu
	var deadline := Time.get_ticks_msec() + 60000
	while not flow.can_launch():
		if flow.phase == flow.Phase.ERROR or Time.get_ticks_msec() >= deadline:
			_fail("startup: " + str(flow.last_result))
			return
		await tree.process_frame
	if stage == "restore":
		var continue_button := menu.find_child("ContinueBattle", true, false) as Button
		if not _usable(continue_button):
			_fail("continue button")
			return
		flow.operation_finished.connect(_restored.bind(chapter, expected_sha), CONNECT_ONE_SHOT)
		continue_button.pressed.emit()
		return
	var selector := menu.find_child("CampaignMenuEntry", true, false)
	var start := _find_button(selector, "开始战役") if selector != null else _find_button(menu, "剧情模式")
	if start == null:
		_fail("campaign selector")
		return
	start.pressed.emit()
	var title: String = campaign.LEVELS[campaign.index_for_id(chapter)].title
	var deploy: Button
	for label: Label in menu.find_children("*", "Label", true, false):
		if label.text == title:
			deploy = _find_button(label.get_parent().get_parent(), "出 征")
			break
	if deploy == null:
		_fail("chapter card: " + title)
		return
	deploy.pressed.emit()
	deadline = Time.get_ticks_msec() + 60000
	var next_draw := 0
	while (tree.current_scene == menu or tree.current_scene == null) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
		# An inactive Windows test desktop may skip presents. Exercise the
		# exported renderer without bringing its window to the user's desktop.
		if Time.get_ticks_msec() >= next_draw:
			RenderingServer.force_draw(false)
			next_draw = Time.get_ticks_msec() + 150
	var battle := tree.current_scene
	if not _battle_matches(battle, chapter, expected_sha):
		_fail("battle or native EXE identity mismatch")
		return
	for page in range(30):
		if not battle.hud._intro_root.visible:
			break
		battle.hud._intro_btn.pressed.emit()
		await tree.process_frame
	if battle.hud.start_btn.visible:
		battle.hud.start_btn.pressed.emit()
	for step in range(20):
		await tree.process_frame
	if battle.phase != battle.Phase.FIGHT:
		_fail("fight not started")
		return
	RenderingServer.force_draw(false)
	battle._open_pause()
	var saver := battle.hud.find_child("SaveAndExit", true, false) as Button
	if not _usable(saver):
		_fail("save and exit button")
		return
	flow.operation_finished.connect(_saved.bind(chapter, expected_sha), CONNECT_ONE_SHOT)
	saver.pressed.emit()


func _usable(button: Button) -> bool:
	return button != null and button.is_visible_in_tree() and not button.disabled


func _find_button(owner: Node, title: String) -> Button:
	for button: Button in owner.find_children("*", "Button", true, false):
		if _usable(button) and button.text.contains(title):
			return button
	return null


func _battle_matches(battle: Node, chapter: String, expected_sha: String) -> bool:
	return battle != null and battle.scene_file_path == BATTLE and battle.level.id() == chapter \
		and not battle._gameplay_content_identity.get("source_mode", true) \
		and battle._gameplay_content_identity.get("engine_binary_sha256", "") == expected_sha


func _saved(outcome: Dictionary, chapter: String, expected_sha: String) -> void:
	if not outcome.get("ok", false):
		_fail(str(outcome))
		return
	var slot: Dictionary = load("res://scripts/run_slot_store.gd").new().read_slot()
	if not slot.ok or slot.document.context.level_id != chapter or slot.document.world.engine_sha256 != expected_sha:
		_fail("slot readback did not match exported chapter")
		return
	print("NATIVE_STOCK_SLOT ", JSON.stringify({"chapter": chapter, "revision": slot.revision,
		"file_sha256": slot.file_sha256, "content_version": slot.document.world.content_version,
		"engine_sha256": slot.document.world.engine_sha256}))
	# The normal SaveAndExit path owns process shutdown.


func _restored(outcome: Dictionary, chapter: String, expected_sha: String) -> void:
	if not outcome.get("ok", false) or not _battle_matches(get_tree().current_scene, chapter, expected_sha):
		_fail("continue: " + str(outcome))
		return
	print("NATIVE_STOCK_CONTINUED ", JSON.stringify({"chapter": chapter, "revision": outcome.generation,
		"engine_sha256": expected_sha}))
	get_tree().root.get_node("AppLifecycle").request_quit("native_save_probe")


func _fail(detail: String) -> void:
	push_error("NATIVE_STOCK_FAILURE " + detail)
	get_tree().quit(2)
