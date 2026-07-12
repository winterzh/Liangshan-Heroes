extends Control
## 主菜单：分模块入口（剧情模式 / 驻守战 / 1v1 / 更多）。
## headless 测试或设了 LEVEL/SKIRMISH 等环境变量时直接进入战斗。

const SPEAKERS := {}
var _update_label: Label
var _update_overlay: Control


func _ready() -> void:
	Engine.time_scale = 1.0   # 回到主菜单复位全局节奏（战斗内放慢到 0.6）
	Music.set_mood("calm")    # 主菜单/选关时放经营曲
	if OS.get_environment("SMOKE_TEST") == "1" or OS.get_environment("SCREENSHOT_DIR") != "" \
			or OS.get_environment("LEVEL") != "" or OS.get_environment("SKIRMISH") == "1" \
			or OS.get_environment("SKIRMISH_AI") == "1" or Campaign.scenario:
		_launch()
		return
	_build()


## 主菜单按安卓「返回键」=退出游戏（quit_on_go_back 已关，需自己处理；否则按返回毫无反应）
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _launch() -> void:
	# 延后切场景：直接在 _ready 内切换会撞上「父节点正忙于增删子节点」
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


# ======================================================================
# 主菜单：背景 + 标题 + 四个大模块入口
# ======================================================================
func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("1a2230")
	var bgsh := Shader.new()
	bgsh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.10, 0.13, 0.19), vec3(0.035, 0.045, 0.075), uv.y);   // 竖直渐变
	float g = distance(uv, vec2(0.5, 0.30));
	col += vec3(0.18, 0.13, 0.05) * smoothstep(0.75, 0.0, g) * 0.55;            // 暖色「灯笼」辉光
	float v = smoothstep(1.15, 0.40, distance(uv, vec2(0.5)) * 1.30);
	col *= mix(0.58, 1.0, v);                                                    // 暗角
	COLOR = vec4(col, 1.0);
}
"""
	var bgmat := ShaderMaterial.new()
	bgmat.shader = bgsh
	bg.material = bgmat
	add_child(bg)

	# 标题/副标题/模块列的竖向档位重排：原来 标题46+字号52 压到 副标题112，
	# 模块列居中后又顶进副标题区——「主菜单显示错位」。现在三段各留净空、互不侵入。
	var title := Label.new()
	title.text = "水浒英雄传"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("ffd866"))
	add_child(title)

	var sub := Label.new()
	sub.text = "替天行道 · 八方共域，异姓一家"
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 98.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color("a0b0c0"))
	add_child(sub)

	# 全屏切换（右上角，亦可 F11 / Alt+Enter）
	var fs := Button.new()
	fs.text = "⛶ 全屏"
	fs.tooltip_text = "切换全屏 / 窗口（F11 或 Alt+Enter）"
	fs.focus_mode = Control.FOCUS_NONE
	fs.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fs.offset_left = -116.0
	fs.offset_right = -16.0
	fs.offset_top = 14.0
	fs.offset_bottom = 46.0
	fs.add_theme_font_size_override("font_size", 16)
	fs.pressed.connect(func() -> void:
		Screen.toggle_fullscreen()
		fs.text = "⛶ 窗口" if Screen.is_fullscreen() else "⛶ 全屏")
	add_child(fs)

	# 大模块入口（竖排，居中在「副标题以下 ~ 版本号以上」的带内，绝不再顶进标题区）
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 128.0
	center.offset_bottom = -36.0
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	col.add_child(_mk_module("📜  剧情模式", "八幕战役 · 替天行道，从智取生辰纲到三败高太尉", Color("ffd866"), _show_story))
	col.add_child(_mk_module("🛡  驻守战", "波次防守 · 20 / 30 / 60 关，亦可加载自定义配置", Color("a9e34b"), _show_defense, true))
	col.add_child(_mk_module("⚔  1v1 对战", "对称经济 · 真实造兵造房，三种胜利条件、三档 AI", Color("8fd3ff"), _show_1v1))
	col.add_child(_mk_module("🏟  竞技场", "DOTA 改版试演场 · 自由点将放技能、一键刷敌（仅此模式启用新技能组）", Color("ff7a4a"), func() -> void:
		Campaign.arena = true
		Campaign.skirmish = false
		Campaign.skirmish_ai = false
		Campaign.custom_defense = false
		Campaign.scenario = false
		_launch()))
	col.add_child(_mk_module("📖  英雄图鉴", "108 将 · 立绘 / 技能 / 生平", Color("ff9a6a"), func() -> void: get_tree().change_scene_to_file.call_deferred("res://scenes/codex.tscn")))
	col.add_child(_mk_module("🛠  更多", "关卡编辑器 · 设置", Color("c0a0ff"), _show_more))

	# 版本号（右下角·低调灰）
	var ver := Label.new()
	ver.text = "v" + Campaign.VERSION
	if AndroidUpdater.enabled:
		ver.text = "v" + AndroidUpdater.display_version()
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -150.0
	ver.offset_top = -36.0
	ver.offset_right = -16.0
	ver.offset_bottom = -12.0
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color("6a7686"))
	add_child(ver)

	if AndroidUpdater.enabled:
		_update_label = Label.new()
		_update_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_update_label.offset_left = 16.0
		_update_label.offset_top = -36.0
		_update_label.offset_right = 620.0
		_update_label.offset_bottom = -12.0
		_update_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_update_label.add_theme_font_size_override("font_size", 15)
		add_child(_update_label)
		_setup_android_update_ui()


## 主菜单大模块：整块为一个带图标(emoji)的大按钮 + 下方小字副标题。
func _mk_module(title_text: String, subtitle: String, accent: Color, cb: Callable, recommended := false) -> Control:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)

	var btn := Button.new()
	btn.text = title_text + ("       ★ 推荐" if recommended else "")
	btn.custom_minimum_size = Vector2(580, 64)   # 6 模块要全塞进 900 高的窗口：82→64，配 col 间距 10
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", accent)
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("222d44")
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color("2d3c5a")
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = Color("3a4d72")
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.pressed.connect(cb)
	vb.add_child(btn)

	var s := Label.new()
	s.text = subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 14)
	s.add_theme_color_override("font_color", Color("8595a8"))
	vb.add_child(s)

	return vb


# ======================================================================
# 覆盖层工具：建一个半透明居中弹层，返回 [overlay, 内容VBox]
# ======================================================================

## 二级菜单弹层：Esc 一键返回（关闭自毁）
class MenuOverlay extends ColorRect:
	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			queue_free()


func _mk_overlay(title_text: String) -> Array:
	var overlay := MenuOverlay.new()
	overlay.color = Color(0.06, 0.05, 0.035, 0.97)   # 近不透明的暖深底，弹层文字清晰可读
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("ffe9a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	# 常驻左上角「返回」：内容再高也永远看得见（底部那颗返回可能被挤出屏外）；Esc 同效
	var backfix := Button.new()
	backfix.text = "←  返回 (Esc)"
	backfix.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	backfix.offset_left = 20.0
	backfix.offset_top = 16.0
	backfix.offset_right = 190.0
	backfix.offset_bottom = 58.0
	backfix.focus_mode = Control.FOCUS_NONE
	backfix.add_theme_font_size_override("font_size", 18)
	backfix.pressed.connect(overlay.queue_free)
	overlay.add_child(backfix)
	return [overlay, box]


func _add_back(box: VBoxContainer, overlay: ColorRect) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	box.add_child(sp)
	var back := Button.new()
	back.text = "←  返回"
	back.custom_minimum_size = Vector2(220, 44)
	back.add_theme_font_size_override("font_size", 19)
	back.pressed.connect(overlay.queue_free)
	box.add_child(back)


## 大号入口按钮（弹层内的选项）。
func _mk_big_btn(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", col)
	return b


# ======================================================================
# 模块一：剧情模式（八幕战役卡片）
# ======================================================================
func _show_story() -> void:
	var ov := _mk_overlay("剧情模式 · 八幕战役")
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]

	var grid := VBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 14)
	box.add_child(grid)

	var per_row := 4
	var n := Campaign.LEVELS.size()
	var i := 0
	while i < n:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		grid.add_child(row)
		for _k in range(per_row):
			if i >= n:
				break
			row.add_child(_make_card(i))
			i += 1

	_add_back(box, overlay)


# ======================================================================
# 模块二：驻守战（20 / 30 / 60 关 + 自定义）
# ======================================================================
func _show_defense() -> void:
	var ov := _mk_overlay("驻守战 · 据守梁山大寨")
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]

	var tip := Label.new()
	tip.text = "守住聚义厅，击退一波波官军围剿"
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color("9fb0c4"))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tip)

	# AI友好模式：全自动（全员英雄托管 + 可开自动镜头）。独立开关，与倍率无关。
	var afb := Button.new()
	afb.toggle_mode = true
	afb.button_pressed = Campaign.ai_friendly
	afb.custom_minimum_size = Vector2(420, 44)
	afb.add_theme_font_size_override("font_size", 17)
	afb.text = "🤖 AI友好模式（全自动）：%s" % ("开" if Campaign.ai_friendly else "关")
	afb.add_theme_color_override("font_color", Color("ffd866") if Campaign.ai_friendly else Color("9fb0c4"))
	box.add_child(afb)
	afb.toggled.connect(func(on: bool) -> void:
		Campaign.ai_friendly = on
		afb.text = "🤖 AI友好模式（全自动）：%s" % ("开" if on else "关")
		afb.add_theme_color_override("font_color", Color("ffd866") if on else Color("9fb0c4")))
	var aftip := Label.new()
	aftip.text = "（开启=全员英雄自动托管、可开自动镜头观战。和下面的倍率互不影响）"
	aftip.add_theme_font_size_override("font_size", 13)
	aftip.add_theme_color_override("font_color", Color("7c8a9c"))
	aftip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aftip.custom_minimum_size = Vector2(520, 0)
	aftip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(aftip)

	# 改变倍率：独立开关。开后出现 敌方倍率(1~5) + 英雄倍率(1~3)，英雄默认=敌方(封顶3)、可单独改。
	var scb := Button.new()
	scb.toggle_mode = true
	scb.button_pressed = Campaign.scale_on
	scb.custom_minimum_size = Vector2(420, 44)
	scb.add_theme_font_size_override("font_size", 17)
	scb.text = "⚖ 改变倍率：%s" % ("开" if Campaign.scale_on else "关")
	scb.add_theme_color_override("font_color", Color("ffd866") if Campaign.scale_on else Color("9fb0c4"))
	box.add_child(scb)
	var hsp := SpinBox.new()   # 英雄倍率框(先建引用，敌方回调里同步)
	# 敌方倍率行
	var erow := HBoxContainer.new()
	erow.alignment = BoxContainer.ALIGNMENT_CENTER
	erow.add_theme_constant_override("separation", 8)
	erow.visible = Campaign.scale_on
	box.add_child(erow)
	var elbl := Label.new()
	elbl.text = "敌方倍率 (1~5) ×"
	elbl.add_theme_font_size_override("font_size", 16)
	elbl.add_theme_color_override("font_color", Color("ff9a7a"))
	erow.add_child(elbl)
	var esp := SpinBox.new()
	esp.min_value = 1.0; esp.max_value = 5.0; esp.step = 0.5
	esp.value = Campaign.enemy_mult
	esp.custom_minimum_size = Vector2(112, 40)
	esp.update_on_text_changed = true
	esp.add_theme_font_size_override("font_size", 18)
	esp.value_changed.connect(func(v: float) -> void:
		Campaign.set_enemy_mult(v)
		if not Campaign.hero_mult_touched:
			hsp.set_value_no_signal(Campaign.hero_mult))   # 英雄默认跟随敌方
	erow.add_child(esp)
	# 英雄倍率行
	var hrow := HBoxContainer.new()
	hrow.alignment = BoxContainer.ALIGNMENT_CENTER
	hrow.add_theme_constant_override("separation", 8)
	hrow.visible = Campaign.scale_on
	box.add_child(hrow)
	var hlbl := Label.new()
	hlbl.text = "英雄倍率 (1~3) ×"
	hlbl.add_theme_font_size_override("font_size", 16)
	hlbl.add_theme_color_override("font_color", Color("a9e34b"))
	hrow.add_child(hlbl)
	hsp.min_value = 1.0; hsp.max_value = 3.0; hsp.step = 0.5
	hsp.value = Campaign.hero_mult
	hsp.custom_minimum_size = Vector2(112, 40)
	hsp.update_on_text_changed = true
	hsp.add_theme_font_size_override("font_size", 18)
	hsp.value_changed.connect(func(v: float) -> void:
		Campaign.set_hero_mult(v))   # 手动改英雄 → 脱钩、不再跟随敌方
	hrow.add_child(hsp)
	scb.toggled.connect(func(on: bool) -> void:
		Campaign.scale_on = on
		scb.text = "⚖ 改变倍率：%s" % ("开" if on else "关")
		scb.add_theme_color_override("font_color", Color("ffd866") if on else Color("9fb0c4"))
		erow.visible = on
		hrow.visible = on)
	var sctip := Label.new()
	sctip.text = "（敌方倍率 e：小兵数量×e、血×(1+(e-1)/3)、攻×(1+(e-1)/4)，大将只乘血/攻。英雄倍率 n：你方英雄范围/CD/伤害/血量按 n 放大。默认英雄=敌方，可单独改；e=1/n=1 即原版）"
	sctip.add_theme_font_size_override("font_size", 13)
	sctip.add_theme_color_override("font_color", Color("7c8a9c"))
	sctip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sctip.custom_minimum_size = Vector2(520, 0)
	sctip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sctip)

	# [波数, 英雄上限, 文案, 配色]
	var opts := [
		[20, 4, "⚡  20 关 · 速战", Color("ffe9a8")],
		[30, 4, "🛡  30 关 · 经典（推荐）", Color("a9e34b")],
		[60, 6, "🔥  60 关 · 史诗（可用 6 员英雄）", Color("ff9a6a")],
	]
	for o in opts:
		var waves: int = o[0]
		var hcap: int = o[1]
		var b := _mk_big_btn(String(o[2]), o[3])
		b.pressed.connect(func() -> void:
			Campaign.defense_waves = waves
			Campaign.defense_hero_cap = hcap
			Campaign.defense_random = false
			Campaign.skirmish = true
			Campaign.skirmish_ai = false
			Campaign.arena = false
			Campaign.custom_defense = false
			Campaign.scenario = false
			_launch())
		box.add_child(b)

	# 自定义随机波次：任意波数 + 每波固定间隔(秒)，每波随机敌军(数量随波次增长)、受敌方倍率影响
	var rndlbl := Label.new()
	rndlbl.text = "🎲 自定义随机波次（任意波数 · 随机敌军 · 数量随波次增长）"
	rndlbl.add_theme_font_size_override("font_size", 15)
	rndlbl.add_theme_color_override("font_color", Color("7ad7ff"))
	rndlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rndlbl)
	var rrow := HBoxContainer.new()
	rrow.alignment = BoxContainer.ALIGNMENT_CENTER
	rrow.add_theme_constant_override("separation", 10)
	box.add_child(rrow)
	var rwl := Label.new()
	rwl.text = "波次"
	rwl.add_theme_font_size_override("font_size", 16)
	rwl.add_theme_color_override("font_color", Color("c8d3e0"))
	rrow.add_child(rwl)
	var rwsp := SpinBox.new()
	rwsp.min_value = 1.0; rwsp.max_value = 999.0; rwsp.step = 1.0
	rwsp.value = Campaign.defense_rand_waves
	rwsp.custom_minimum_size = Vector2(110, 40)
	rwsp.update_on_text_changed = true
	rwsp.add_theme_font_size_override("font_size", 18)
	rrow.add_child(rwsp)
	var ril := Label.new()
	ril.text = "每波间隔(秒)"
	ril.add_theme_font_size_override("font_size", 16)
	ril.add_theme_color_override("font_color", Color("c8d3e0"))
	rrow.add_child(ril)
	var risp := SpinBox.new()
	risp.min_value = 1.0; risp.max_value = 600.0; risp.step = 1.0
	risp.value = Campaign.defense_interval
	risp.custom_minimum_size = Vector2(110, 40)
	risp.update_on_text_changed = true
	risp.add_theme_font_size_override("font_size", 18)
	rrow.add_child(risp)
	var rtip := Label.new()
	rtip.text = "（第 1 波固定 120 秒备战；之后每波间隔 = 你填的秒数，越小越急、建议 20~30。数量随波次增长、并受敌方倍率放大）"
	rtip.add_theme_font_size_override("font_size", 13)
	rtip.add_theme_color_override("font_color", Color("7c8a9c"))
	rtip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtip.custom_minimum_size = Vector2(520, 0)
	rtip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rtip)
	var rbtn := _mk_big_btn("🎲  随机波次 · 开战", Color("7ad7ff"))
	rbtn.pressed.connect(func() -> void:
		Campaign.defense_rand_waves = clampi(int(rwsp.value), 1, 999)
		Campaign.defense_interval = clampf(risp.value, 1.0, 600.0)
		Campaign.defense_waves = Campaign.defense_rand_waves
		Campaign.defense_hero_cap = 6
		Campaign.defense_random = true
		Campaign.skirmish = true
		Campaign.skirmish_ai = false
		Campaign.arena = false
		Campaign.custom_defense = false
		Campaign.scenario = false
		Campaign.save_prefs()
		_launch())
	box.add_child(rbtn)

	var cb := _mk_big_btn("📂  加载自定义配置", Color("c0a0ff"))
	cb.pressed.connect(func() -> void:
		overlay.queue_free()
		_show_custom_picker())
	box.add_child(cb)

	_add_back(box, overlay)


# ======================================================================
# 模块三：1v1 对战（难度 + 胜利条件）
# ======================================================================
func _show_1v1() -> void:
	var ov := _mk_overlay("1v1 对战 · 对称经济真实对抗")
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]

	# 胜利条件选择
	var vrow := HBoxContainer.new()
	vrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vrow.add_theme_constant_override("separation", 10)
	box.add_child(vrow)
	var vlbl := Label.new()
	vlbl.text = "胜利条件："
	vlbl.add_theme_font_size_override("font_size", 18)
	vlbl.add_theme_color_override("font_color", Color("c8b890"))
	vrow.add_child(vlbl)
	var vnames := {"conquest": "征服·破营", "regicide": "斩首·杀主帅"}
	var vstat := Label.new()
	vstat.add_theme_font_size_override("font_size", 18)
	vstat.add_theme_color_override("font_color", Color("a9e34b"))
	vstat.text = "▶ " + String(vnames.get(Campaign.victory_mode, "征服·破营"))
	for vc in [["征服", "conquest"], ["斩首", "regicide"]]:
		var vb := Button.new()
		vb.text = vc[0]
		vb.custom_minimum_size = Vector2(108, 42)
		vb.add_theme_font_size_override("font_size", 18)
		var vkey: String = vc[1]
		vb.pressed.connect(func() -> void:
			Campaign.victory_mode = vkey
			vstat.text = "▶ " + String(vnames.get(vkey, "")))
		vrow.add_child(vb)
	vrow.add_child(vstat)

	var dtip := Label.new()
	dtip.text = "选好胜利条件，再点难度开战"
	dtip.add_theme_font_size_override("font_size", 15)
	dtip.add_theme_color_override("font_color", Color("9fb0c4"))
	dtip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dtip)

	# 难度（即开战）
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", 16)
	box.add_child(drow)
	for diff in [["简单", "easy", Color("a9e34b")], ["普通", "normal", Color("ffe9a8")], ["困难", "hard", Color("ff8a6a")]]:
		var ab := Button.new()
		ab.text = diff[0]
		ab.custom_minimum_size = Vector2(130, 58)
		ab.add_theme_font_size_override("font_size", 22)
		ab.add_theme_color_override("font_color", diff[2])
		var key: String = diff[1]
		ab.pressed.connect(func() -> void:
			Campaign.skirmish_ai = true
			Campaign.arena = false
			Campaign.skirmish = false
			Campaign.custom_defense = false
			Campaign.scenario = false
			Campaign.ai_friendly = false   # AI友好模式仅限驻守战
			Campaign.ai_difficulty = key
			_launch())
		drow.add_child(ab)

	_add_back(box, overlay)


# ======================================================================
# 模块四：更多（编辑器 / 图鉴）
# ======================================================================
func _show_more() -> void:
	var ov := _mk_overlay("更多")
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]

	var sed := _mk_big_btn("🗺  场景编辑器（造关）", Color("9fe06f"))
	sed.pressed.connect(func() -> void:
		get_tree().change_scene_to_file.call_deferred("res://scenes/scenario_editor.tscn"))
	box.add_child(sed)

	var splay := _mk_big_btn("▶  玩自定义关卡", Color("87cefa"))
	splay.pressed.connect(func() -> void:
		overlay.queue_free()
		_show_scenario_picker())
	box.add_child(splay)

	var ed := _mk_big_btn("🛠  据守数值编辑器", Color("ffe9a8"))
	ed.pressed.connect(func() -> void:
		get_tree().change_scene_to_file.call_deferred("res://scenes/editor.tscn"))
	box.add_child(ed)

	var st := _mk_big_btn("⚙  设置", Color("a9e34b"))
	st.pressed.connect(func() -> void:
		overlay.queue_free()
		_show_settings())
	box.add_child(st)

	if AndroidUpdater.enabled:
		var update_btn := _mk_big_btn("↻  检查安卓更新", Color("8fd3ff"))
		update_btn.pressed.connect(func() -> void:
			overlay.queue_free()
			AndroidUpdater.check_now())
		box.add_child(update_btn)

	_add_back(box, overlay)


# ======================================================================
# 自定义关卡·选存档（场景编辑器做的关，存在 user://scenarios）
# ======================================================================
func _show_scenario_picker() -> void:
	var saved: Array = ScenarioStore.list_saved()
	var ov := _mk_overlay("玩自定义关卡" if not saved.is_empty() else "还没有自定义关卡——先去「更多 → 场景编辑器」做一个")
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]
	for name in saved:
		var nm: String = name
		var b := _mk_big_btn("▶  " + nm, Color("9fe06f"))
		b.pressed.connect(func() -> void:
			var d: Dictionary = ScenarioStore.load_by_name(nm)
			if not d.is_empty():
				Campaign.scenario_data = d
				Campaign.scenario = true
				Campaign.custom_defense = false
				Campaign.skirmish = false
				Campaign.skirmish_ai = false
				Campaign.arena = false
				Campaign.ai_friendly = false   # AI友好模式仅限驻守战
				_launch())
		box.add_child(b)
	_add_back(box, overlay)


# ======================================================================
# 自定义据守·选存档（由「驻守战 → 加载自定义配置」进入）
# ======================================================================
func _show_custom_picker() -> void:
	var saved: Array = CustomConfig.list_saved()
	var overlay := ColorRect.new()
	overlay.color = Color(0.06, 0.05, 0.035, 0.97)   # 近不透明的暖深底，弹层文字清晰可读
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := Label.new()
	title.text = "选择自定义据守配置" if not saved.is_empty() else "还没有保存的配置——先去「更多 → 关卡编辑器」做一个并保存"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffe9a8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for name in saved:
		var b := Button.new()
		b.text = "▶  " + String(name)
		b.custom_minimum_size = Vector2(340, 46)
		b.add_theme_font_size_override("font_size", 20)
		var nm: String = name
		b.pressed.connect(func() -> void:
			var cfg: Dictionary = CustomConfig.load_by_name(nm)
			if not cfg.is_empty():
				Campaign.custom_config = cfg
				Campaign.custom_defense = true
				Campaign.scenario = false
				Campaign.skirmish = false
				Campaign.skirmish_ai = false
				Campaign.arena = false
				_launch())
		box.add_child(b)
	_add_back(box, overlay)


# ======================================================================
# 剧情模式的关卡卡片
# ======================================================================
func _make_card(i: int) -> Control:
	var info: Dictionary = Campaign.LEVELS[i]
	var unlocked := Campaign.is_unlocked(i)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 250)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b3a4f") if unlocked else Color("222a36")
	sb.border_color = Color("ffd866") if unlocked else Color("3a4452")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var num := Label.new()
	num.text = "第 %d 幕" % (i + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 16)
	num.add_theme_color_override("font_color", Color("8fb0d0") if unlocked else Color("55606e"))
	vb.add_child(num)

	var nm := Label.new()
	nm.text = info["title"]
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.add_theme_font_size_override("font_size", 24)
	nm.add_theme_color_override("font_color", Color("ffe9a8") if unlocked else Color("6a7686"))
	vb.add_child(nm)

	var ds := Label.new()
	ds.text = info["sub"]
	ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.add_theme_font_size_override("font_size", 14)
	ds.add_theme_color_override("font_color", Color("9aa8b8") if unlocked else Color("55606e"))
	vb.add_child(ds)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var btn := Button.new()
	if not Campaign.implemented(i):
		btn.text = "敬请期待"
		btn.disabled = true
	elif not unlocked:
		btn.text = "🔒 未解锁"
		btn.disabled = true
	else:
		btn.text = "出 征"
		btn.pressed.connect(func() -> void:
			Campaign.current = i
			Campaign.skirmish = false       # 清掉自由模式残留（Campaign 是常驻 autoload，
			Campaign.skirmish_ai = false    # 上次点过「据守/AI」的旗标会留着 → 否则战役关也进据守）
			Campaign.custom_defense = false
			Campaign.scenario = false
			Campaign.ai_friendly = false   # AI友好模式仅限驻守战
			_launch())
	btn.add_theme_font_size_override("font_size", 18)
	vb.add_child(btn)

	return panel


# 设置面板：复用 SettingsPanel（与战斗内 Esc 菜单同一套 UI）
func _show_settings() -> void:
	add_child(preload("res://scripts/settings_panel.gd").new())


# ======================================================================
# Android 内容热更新界面（桌面平台不创建任何控件）
# ======================================================================
func _setup_android_update_ui() -> void:
	AndroidUpdater.status_changed.connect(_on_android_update_status)
	AndroidUpdater.update_available.connect(_on_android_update_available)
	AndroidUpdater.full_update_required.connect(_on_android_full_update)
	AndroidUpdater.update_ready.connect(_on_android_update_ready)
	_on_android_update_status(AndroidUpdater.state, AndroidUpdater.status_text, AndroidUpdater.progress)
	match AndroidUpdater.state:
		"available":
			var p: Dictionary = AndroidUpdater.available_manifest.get("patch", {})
			_on_android_update_available.call_deferred(
				String(AndroidUpdater.available_manifest.get("content_version", "")), int(p.get("size", 0)))
		"full_update":
			var f: Dictionary = AndroidUpdater.available_manifest.get("full_apk", {})
			_on_android_full_update.call_deferred(String(f.get("version_name", "")))
		"ready":
			_on_android_update_ready.call_deferred(
				String(AndroidUpdater.available_manifest.get("content_version", "")))


func _on_android_update_status(update_state: String, text: String, _progress: float) -> void:
	if _update_label == null or not is_instance_valid(_update_label):
		return
	_update_label.text = text
	var color := Color("8fa0b4")
	if update_state in ["available", "ready", "full_update"]:
		color = Color("ffd866")
	elif update_state == "error":
		color = Color("ff9a7a")
	elif update_state == "current":
		color = Color("7fa879")
	_update_label.add_theme_color_override("font_color", color)


func _on_android_update_available(version: String, size_bytes: int) -> void:
	if _update_overlay != null and is_instance_valid(_update_overlay):
		return
	var ov := _mk_overlay("发现安卓内容更新")
	var overlay: Control = ov[0]
	var box: VBoxContainer = ov[1]
	_update_overlay = overlay
	overlay.tree_exited.connect(func() -> void: _update_overlay = null)
	var info := Label.new()
	info.text = "内容版本 v%s\n差异包大小：%s\n\n只更新游戏脚本、关卡和素材，不需要重新安装 APK。" % [
		version, AndroidUpdater.format_bytes(size_bytes)]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 19)
	info.add_theme_color_override("font_color", Color("c8d3df"))
	box.add_child(info)
	var download := _mk_big_btn("下载更新", Color("a9e34b"))
	download.pressed.connect(func() -> void:
		overlay.queue_free()
		AndroidUpdater.begin_download())
	box.add_child(download)
	_add_back(box, overlay)


func _on_android_update_ready(version: String) -> void:
	if _update_overlay != null and is_instance_valid(_update_overlay):
		_update_overlay.queue_free()
	var ov := _mk_overlay("安卓更新已下载")
	var overlay: Control = ov[0]
	var box: VBoxContainer = ov[1]
	_update_overlay = overlay
	overlay.tree_exited.connect(func() -> void: _update_overlay = null)
	var info := Label.new()
	info.text = "内容版本 v%s 已通过签名和完整性校验。\n退出后重新打开游戏即可生效。" % version
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("c8e6b4"))
	box.add_child(info)
	var restart := _mk_big_btn("退出游戏，稍后重新打开", Color("ffd866"))
	restart.pressed.connect(AndroidUpdater.quit_for_restart)
	box.add_child(restart)
	_add_back(box, overlay)


func _on_android_full_update(version: String) -> void:
	if _update_overlay != null and is_instance_valid(_update_overlay):
		return
	var ov := _mk_overlay("需要更新完整 APK")
	var overlay: Control = ov[0]
	var box: VBoxContainer = ov[1]
	_update_overlay = overlay
	overlay.tree_exited.connect(func() -> void: _update_overlay = null)
	var info := Label.new()
	info.text = "新版 v%s 包含安卓程序层变更，无法使用差异包。\n请前往 GitHub 下载完整 APK 安装。" % version
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color("ffd0a0"))
	box.add_child(info)
	var open := _mk_big_btn("打开 GitHub 下载页", Color("8fd3ff"))
	open.pressed.connect(AndroidUpdater.open_full_apk)
	box.add_child(open)
	_add_back(box, overlay)
