extends Control
## 主菜单：分模块入口（剧情模式 / 驻守战 / 1v1 / 更多）。
## headless 测试或设了 LEVEL/SKIRMISH 等环境变量时直接进入战斗。

const SPEAKERS := {}


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

	var title := Label.new()
	title.text = "水浒英雄传"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 46.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("ffd866"))
	add_child(title)

	var sub := Label.new()
	sub.text = "替天行道 · 八方共域，异姓一家"
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 112.0
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

	# 四个大模块入口（竖排居中）
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 60.0
	add_child(center)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	col.add_child(_mk_module("📜  剧情模式", "八幕战役 · 替天行道，从智取生辰纲到三败高太尉", Color("ffd866"), _show_story))
	col.add_child(_mk_module("🛡  驻守战", "波次防守 · 20 / 30 / 60 关，亦可加载自定义配置", Color("a9e34b"), _show_defense, true))
	col.add_child(_mk_module("⚔  1v1 对战", "对称经济 · 真实造兵造房，三种胜利条件、三档 AI", Color("8fd3ff"), _show_1v1))
	col.add_child(_mk_module("📖  英雄图鉴", "108 将 · 立绘 / 技能 / 生平", Color("ff9a6a"), func() -> void: get_tree().change_scene_to_file.call_deferred("res://scenes/codex.tscn")))
	col.add_child(_mk_module("🛠  更多", "关卡编辑器 · 设置", Color("c0a0ff"), _show_more))


## 主菜单大模块：整块为一个带图标(emoji)的大按钮 + 下方小字副标题。
func _mk_module(title_text: String, subtitle: String, accent: Color, cb: Callable, recommended := false) -> Control:
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)

	var btn := Button.new()
	btn.text = title_text + ("       ★ 推荐" if recommended else "")
	btn.custom_minimum_size = Vector2(580, 82)
	btn.add_theme_font_size_override("font_size", 32)
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
func _mk_overlay(title_text: String) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
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
			Campaign.skirmish = true
			Campaign.skirmish_ai = false
			Campaign.custom_defense = false
			Campaign.scenario = false
			_launch())
		box.add_child(b)

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
	var vnames := {"conquest": "征服·破营", "regicide": "斩首·杀主帅", "koth": "占山为王·控点"}
	var vstat := Label.new()
	vstat.add_theme_font_size_override("font_size", 18)
	vstat.add_theme_color_override("font_color", Color("a9e34b"))
	vstat.text = "▶ " + String(vnames.get(Campaign.victory_mode, "征服·破营"))
	for vc in [["征服", "conquest"], ["斩首", "regicide"], ["占山为王", "koth"]]:
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
			Campaign.skirmish = false
			Campaign.custom_defense = false
			Campaign.scenario = false
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
				_launch())
		box.add_child(b)
	_add_back(box, overlay)


# ======================================================================
# 自定义据守·选存档（由「驻守战 → 加载自定义配置」进入）
# ======================================================================
func _show_custom_picker() -> void:
	var saved: Array = CustomConfig.list_saved()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
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
			_launch())
	btn.add_theme_font_size_override("font_size", 18)
	vb.add_child(btn)

	return panel


# 设置面板：复用 SettingsPanel（与战斗内 Esc 菜单同一套 UI）
func _show_settings() -> void:
	add_child(preload("res://scripts/settings_panel.gd").new())
