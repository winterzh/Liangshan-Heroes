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
	bg.color = Color(0.06, 0.05, 0.035, 0.96)
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
	# 慢=原来的正常速度(1.0)；中=1.2×；快=1.5×。改完「返回」恢复对战即生效（_close_pause 重置 time_scale）。
	_row(p, "游戏速度", _seg([["慢", 1.0], ["中", 1.2], ["快", 1.5]], Settings.game_speed, func(v) -> void:
		Settings.game_speed = v
		if not get_tree().paused:
			Engine.time_scale = v))
	# 第四档「全托管」+ 自动镜头仅在驻守战「AI友好模式」下可用；未开则只给前三档（无/弱/强）。
	var micro_opts: Array = [["无", 0], ["弱", 1], ["强", 2]]
	var micro_cur: int = int(Settings.auto_micro_level)
	if Campaign.ai_friendly:
		micro_opts.append(["全托管", 3])
	elif micro_cur >= 3:
		micro_cur = 2   # 关掉AI友好模式后，原「全托管」档在面板上回落显示为「强托管」
	_row(p, "英雄托管", _seg(micro_opts, micro_cur, func(v) -> void: Settings.auto_micro_level = int(v)))
	if Campaign.ai_friendly:
		_row(p, "", _note("全托管：驻守战里彻底挂机——喽啰自动采集/建造/修复、自动练兵练将研究、英雄全自动、镜头自动"))
	else:
		_row(p, "", _note("「全托管」与自动镜头需先在驻守战开启「AI友好模式」才可用"))
	_row(p, "氛围特效", _check(Settings.atmosphere, func(on: bool) -> void: Settings.atmosphere = on))
	if OS.has_feature("mobile"):
		# 手机横屏方向：自动=重力感应双向横屏；手机不自动转就手动选正向/反向
		_row(p, "横屏方向", _seg([["自动", "auto"], ["正向", "normal"], ["反向", "flip"]], Screen.orient, func(v) -> void: Screen.set_orientation(String(v))))
		_row(p, "", _note("自动=重力感应双向横屏；若手机不自动旋转，可手动选正向/反向"))
	else:
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


## 灰色小字说明（占控件位，配合空 label 行做整行提示）
func _note(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("7c8a9c"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	return l


func _check(value: bool, cb: Callable) -> Control:
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(func(on: bool) -> void: cb.call(on))
	return c


## 数字输入框（SpinBox）：lo..hi、step 步进，可点箭头也可直接键入，实时回调。
func _num(value: float, lo: float, hi: float, step: float, cb: Callable) -> Control:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = value
	sb.custom_minimum_size = Vector2(130, 38)
	sb.add_theme_font_size_override("font_size", 18)
	sb.value_changed.connect(func(v: float) -> void: cb.call(v))
	return sb


## 分段单选按钮的醒目配色：选中=金底深字(粗边)，未选=暗底灰字。让「当前选中项」一眼可辨。
func _style_seg(b: Button) -> void:
	var norm := StyleBoxFlat.new()
	norm.bg_color = Color(0.15, 0.14, 0.11)
	norm.set_corner_radius_all(7)
	norm.set_border_width_all(1)
	norm.border_color = Color(0.34, 0.31, 0.24)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color("ffcf3f")          # 选中：醒目金黄
	sel.set_corner_radius_all(7)
	sel.set_border_width_all(2)
	sel.border_color = Color("fff3c8")
	b.add_theme_stylebox_override("normal", norm)
	b.add_theme_stylebox_override("hover", norm)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("hover_pressed", sel)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color("aa9f8c"))            # 未选：暗灰字
	b.add_theme_color_override("font_hover_color", Color("e6dcc4"))
	b.add_theme_color_override("font_pressed_color", Color("241a06"))    # 选中：深色压金底
	b.add_theme_color_override("font_hover_pressed_color", Color("241a06"))


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
		_style_seg(b)   # 选中=醒目金底深字，未选=暗底灰字，一眼区分
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
