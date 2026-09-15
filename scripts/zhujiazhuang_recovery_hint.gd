extends PanelContainer
## Derived chapter UI: no orders, resource changes, RNG calls or saved level state.

const NODE_NAME := "ZhujiazhuangRecoveryHint"
const SOLDIERS := ["liang_dao", "liang_qiang", "liang_gong", "liang_ma"]
const MESSAGES := {
	"ready": "普通士兵已损失，可在兵营补员。查看兵营后，选中建筑招募。",
	"training": "补员正在训练，出营后可重新集结。",
	"blocked": "补员已完成训练，但兵营出口受阻。请移开出口附近的单位。",
	"resources": "暂无普通士兵，补员资源不足。可安排工人采集金木。",
	"population": "暂无普通士兵，补员人口不足。可建民居增加人口上限。",
	"researching": "暂无普通士兵，兵营正在研究。研究完成后可补员。",
	"constructing": "暂无普通士兵，兵营尚未完工。可安排工人继续建造。",
	"no_barracks": "暂无普通士兵和可用兵营。可选工人重建兵营。",
	"no_workers": "暂无工人，恢复采集或建设前需补充喽啰。可查看前营的招募选项。",
}

var message: Label
var barracks_button: Button
var camp_button: Button
var state_key := "hidden"
var _battle

static func refresh(b) -> void:
	var hint = b.hud.get_node_or_null(NODE_NAME)
	if hint == null:
		hint = load("res://scripts/zhujiazhuang_recovery_hint.gd").new()
		hint.name = NODE_NAME
		hint._battle = b
		b.hud.add_child(hint)
	hint.update_state()

static func _alive(u) -> bool:
	return is_instance_valid(u) and u.hp > 0.0 and u.story_outcome == ""

static func _soldier(u) -> bool:
	return _alive(u) and u.faction == Unit.FACTION_LIANG and u.key in SOLDIERS \
		and not u.is_hero and not u.is_worker and not u.is_building \
		and not u.is_captive and not u.is_noncombat and not u.is_summon

func _ready() -> void:
	theme = UITheme.shared()
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UITheme.PANEL, 0.96)
	style.border_color = UITheme.COPPER
	style.set_border_width_all(1)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(box)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 15)
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	barracks_button = _make_button(row, "查看 · 兵营", _view_barracks)
	Localize.bind_text(barracks_button, "只移动镜头；选中兵营后可在指挥栏招募。", &"tooltip_text")
	camp_button = _make_button(row, "查看 · 前营", _view_camp)
	Localize.bind_text(camp_button, "只移动镜头，保留当前选择和命令。", &"tooltip_text")
	hide()

func _make_button(row: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 32
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(button)
	Localize.bind_text(button, text)
	button.pressed.connect(callback)
	return button

func _applicable() -> bool:
	return is_instance_valid(_battle) and _battle.phase == _battle.Phase.FIGHT \
		and _battle.level != null and _battle.level.id() == "level3" \
		and not _battle.level._finish_ready()

func _process(_delta: float) -> void:
	# Level processing stops at END, so the derived panel must hide itself too.
	if not _applicable():
		state_key = "hidden"
		hide()
	if visible:
		custom_minimum_size.x = 430.0 if Localize.locale == "en" else 380.0
		reset_size()
		var top_bottom: float = _battle.hud.top_label.get_global_rect().end.y
		position = Vector2(get_viewport_rect().size.x - size.x - 12.0, maxf(62.0, top_bottom + 12.0))

func _barracks() -> Array:
	var found: Array = []
	for u in _battle.units:
		if _alive(u) and u.faction == Unit.FACTION_LIANG and u.key == "barracks":
			found.append(u)
	return found

func _choice() -> Dictionary:
	var buildings := _barracks()
	if buildings.is_empty(): return {"state": "no_barracks", "unit": null}
	# Prefer a real pending reinforcement, then a building able to train now.
	for building in buildings:
		if building.is_constructing: continue
		if building._train_queue.any(func(key): return key in SOLDIERS):
			var status := "blocked" if building.production_blocked else "training"
			return {"state": status, "unit": building}
	for building in buildings:
		for key in SOLDIERS:
			if _battle._train_block_reason(building, key) == "":
				return {"state": "ready", "unit": building}
	var chosen = buildings[0]
	for building in buildings:
		if not building.is_constructing:
			chosen = building
			break
	var reason := "resources"
	if chosen.is_constructing:
		reason = "constructing"
	elif chosen._research_key != "":
		reason = "researching"
	else:
		for key in SOLDIERS:
			if _battle._train_block_reason(chosen, key) == "population":
				reason = "population"
				break
	return {"state": reason, "unit": chosen}

func update_state() -> void:
	if not _applicable() or _battle.units.any(_soldier):
		state_key = "hidden"
		hide()
		return
	var choice := _choice()
	var next := String(choice.state)
	if next in ["resources", "constructing", "no_barracks"] and not _battle.units.any(func(u): return _alive(u) and u.faction == Unit.FACTION_LIANG and u.is_worker and not u.is_captive):
		next = "no_workers"
	if next != state_key:
		Localize.bind_text(message, MESSAGES[next])
	state_key = next
	barracks_button.disabled = choice.unit == null
	camp_button.disabled = not _alive(_battle.level.hall)
	show()

func _view_barracks() -> void:
	if not _applicable(): return
	# Resolve again at click time: the original barracks may have been destroyed.
	var target = _choice().unit
	if _alive(target):
		_battle.center_camera_cell(_battle.map.world_to_cell(target.position))
	update_state()

func _view_camp() -> void:
	if not _applicable(): return
	if _alive(_battle.level.hall):
		_battle.center_camera_cell(_battle.map.world_to_cell(_battle.level.hall.position))
	update_state()
