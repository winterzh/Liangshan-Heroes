extends Control
## 可复用设置面板：主菜单与战斗内 Esc 菜单共用同一套 UI（用 preload 引用，无需 class_name）。
## add_child(SettingsPanel.new()) 即弹全屏覆盖层；返回/Esc 自销毁并保存。
## 若调用方需在关闭后做事（如重新显示暂停菜单），设 on_close 回调。

var on_close := Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停态(Esc 菜单)下仍可操作
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "⚙  设置"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ffe9a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var p := VBoxContainer.new()
	p.custom_minimum_size = Vector2(636, 0)
	p.add_theme_constant_override("separation", 6)
	scroll.add_child(p)

	_head(p, "🔊  音频")
	_row(p, "背景音乐", _slider(Settings.bgm, 0.0, 1.0, func(v: float) -> void: Settings.set_bgm(v)))
	_row(p, "音效", _slider(Settings.sfx, 0.0, 1.0, func(v: float) -> void: Settings.set_sfx(v)))
	_row(p, "全部静音", _check(Settings.muted, func(on: bool) -> void: Settings.set_muted(on)))

	_head(p, "⏱  游戏")
	_row(p, "游戏速度", _seg([["慢", 0.8], ["正常", 1.0], ["快", 1.5]], Settings.game_speed, func(v) -> void: Settings.game_speed = v))
	_row(p, "氛围特效", _check(Settings.atmosphere, func(on: bool) -> void: Settings.atmosphere = on))
	_row(p, "全屏", _check(Screen.is_fullscreen(), func(on: bool) -> void: Screen.set_fullscreen(on)))

	_head(p, "🎥  镜头")
	_row(p, "边缘滚屏", _check(Settings.edge_scroll, func(on: bool) -> void: Settings.edge_scroll = on))
	_row(p, "镜头速度", _slider(Settings.cam_speed, 0.3, 2.5, func(v: float) -> void: Settings.cam_speed = v))
	_row(p, "缩放灵敏度", _slider(Settings.zoom_sens, 0.3, 2.5, func(v: float) -> void: Settings.zoom_sens = v))

	_head(p, "💬  显示")
	_row(p, "伤害飘字", _check(Settings.show_damage, func(on: bool) -> void: Settings.show_damage = on))
	_row(p, "血条常显", _check(Settings.show_healthbars, func(on: bool) -> void: Settings.show_healthbars = on))
	_row(p, "技能冷却数字", _check(Settings.show_cooldown, func(on: bool) -> void: Settings.show_cooldown = on))

	_head(p, "🎯  默认对战（1v1）")
	_row(p, "难度", _seg([["简单", "easy"], ["普通", "normal"], ["困难", "hard"]], Campaign.ai_difficulty, func(v) -> void: Campaign.ai_difficulty = v))
	_row(p, "胜利条件", _seg([["征服", "conquest"], ["斩首", "regicide"], ["占山", "koth"]], Campaign.victory_mode, func(v) -> void: Campaign.victory_mode = v))

	_head(p, "⌨  键位一览")
	var keys := Label.new()
	keys.text = _keybind_text()
	keys.add_theme_font_size_override("font_size", 14)
	keys.add_theme_color_override("font_color", Color("b8c4d4"))
	p.add_child(keys)

	var back := Button.new()
	back.text = "←  返回（保存）"
	back.custom_minimum_size = Vector2(240, 46)
	back.add_theme_font_size_override("font_size", 19)
	back.pressed.connect(close)
	box.add_child(back)


func close() -> void:
	Settings.save()
	Campaign.save_prefs()
	if on_close.is_valid():
		on_close.call()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func _head(parent: VBoxContainer, title: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	parent.add_child(sp)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color("ffd866"))
	parent.add_child(l)


func _row(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(150, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color("c8d2de"))
	hb.add_child(l)
	hb.add_child(control)
	parent.add_child(hb)


## 数值滑条 + 实时数值标签。hi<=1 显示百分比；否则显示倍率（×）。
func _slider(value: float, lo: float, hi: float, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(240, 26)
	hb.add_child(sl)
	var vl := Label.new()
	vl.custom_minimum_size = Vector2(56, 0)
	vl.add_theme_font_size_override("font_size", 15)
	vl.add_theme_color_override("font_color", Color("ffe9a8"))
	vl.text = ("%d%%" % int(round(value * 100.0))) if hi <= 1.0 else ("%.1f×" % value)
	hb.add_child(vl)
	sl.value_changed.connect(func(v: float) -> void:
		vl.text = ("%d%%" % int(round(v * 100.0))) if hi <= 1.0 else ("%.1f×" % v)
		cb.call(v))
	return hb


func _check(value: bool, cb: Callable) -> Control:
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(func(on: bool) -> void: cb.call(on))
	return c


## 分段单选：[[显示文字, 值], ...]，高亮 current 对应项；点击互斥高亮并回调。
func _seg(options: Array, current: Variant, cb: Callable) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var btns: Array = []
	for opt in options:
		var b := Button.new()
		b.text = String(opt[0])
		b.toggle_mode = true
		b.button_pressed = (opt[1] == current)
		b.custom_minimum_size = Vector2(80, 38)
		b.add_theme_font_size_override("font_size", 17)
		btns.append(b)
		hb.add_child(b)
	for i in range(options.size()):
		var b: Button = btns[i]
		var val: Variant = options[i][1]
		b.pressed.connect(func() -> void:
			for bb in btns:
				(bb as Button).button_pressed = false
			b.button_pressed = true
			cb.call(val))
	return hb


func _keybind_text() -> String:
	var lines := [
		"编队：Ctrl/⌘+数字 设组　数字 选组　Shift+数字 并入",
		"A 攻击移动　S 停止　P 巡逻　G 切换站位",
		"Q / W / E / R 英雄技能　F1–F8 按头像选英雄",
		"空格 回起始视角　Tab 子编组　. / , 切闲置工人",
		"Delete 拆除　Esc 菜单 / 取消",
		"镜头：方向键平移　+ / − 或滚轮 缩放　中键拖拽",
	]
	return "\n".join(lines)
