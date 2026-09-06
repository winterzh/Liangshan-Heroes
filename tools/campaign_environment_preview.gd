extends SceneTree
## 只读八关浏览：冻结战斗并隐藏开战按钮，不推进/保存Campaign。
var battle: Node
var loading := false
const CENTERS := [Vector2i(24,20),Vector2i(28,26),Vector2i(34,28),Vector2i(30,30),Vector2i(23,29),Vector2i(27,20),Vector2i(32,19),Vector2i(29,28)]

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var campaign := root.get_node("Campaign")
	for key in ["skirmish","skirmish_ai","arena","custom_defense","scenario","ai_friendly","scale_on"]: campaign.set(key,false)
	root.get_node("Settings").edge_scroll=false
	AudioServer.set_bus_mute(0,true)
	var controls := Controls.new()
	controls.choose = _load_level
	root.add_child(controls)
	var initial := int(OS.get_environment("CAMPAIGN_PREVIEW_LEVEL"))
	await _load_level(initial if initial in range(1,9) else 7)

func _load_level(number: int) -> void:
	if loading: return
	loading=true
	if is_instance_valid(battle):
		battle.queue_free()
		await process_frame
		await process_frame
	root.get_node("Campaign").current=number-1
	seed(5088120+number)
	battle=load("res://scenes/main.tscn").instantiate()
	root.add_child(battle)
	current_scene=battle
	await process_frame
	battle.hud._intro_root.hide()
	battle._on_intro_done()
	battle.set_process(false)
	battle.set_process_input(false)
	battle.set_process_unhandled_input(false)
	for unit in battle.units: unit.set_physics_process(false)
	battle._grid_build()
	battle.hud.start_btn.hide()
	battle.hud.set_top("环境浏览 · 数字1—8切关 · 方向键移动 · 滚轮缩放 · 不开战、不保存")
	battle.camera.position=battle.to_screen(battle.map.cell_to_world(CENTERS[number-1]))
	battle.camera.zoom=Vector2.ONE*0.85
	root.title="水浒环境 v8 · 第%d关 · 仅浏览"%number
	loading=false
	print("[campaign_preview] level=",number," combat disabled; no saves")

class Controls extends Node:
	var choose: Callable
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode>=KEY_1 and event.keycode<=KEY_8: choose.call(event.keycode-KEY_1+1)
