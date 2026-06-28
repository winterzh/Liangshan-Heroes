extends Control
## 英雄图鉴：左侧按类型列出所有单位（含战役登场），右侧大图展示
## 头像 / 移动动画 / 攻击动画，下方一段生平。从主菜单「📖 英雄图鉴」进入。

const TYPE_ORDER := ["英雄", "步兵", "远程", "骑兵", "工人", "建筑"]

var _cur := ""
var _name_lbl: Label
var _sub_lbl: Label
var _abil_title: Label
var _abil_lbl: Label
var _bio_lbl: Label
var _port: AnimBox
var _walk: AnimBox
var _atk: AnimBox
var _lore_root: ColorRect
var _lore_panel: Panel
var _lore_name: Label
var _lore_text: Label
var _lore_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _list_scroll: ScrollContainer

# 触屏：手指拖动滚动列表（原生 ScrollContainer 在密集小按钮上不跟手，这里显式接管）
var _touch := false
var _active_scroll: ScrollContainer = null
var _drag_amt := 0.0
var _dragging_list := false


## 触屏：手指拖动滚动左列表/右详情。在 _input 里接管（早于子按钮消费），
## 拖动超过阈值即标记 _dragging_list，使本次松手不触发选中（区分点选 vs 滚动）。
func _input(e: InputEvent) -> void:
	if not _touch:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_drag_amt = 0.0
			_dragging_list = false
			var p: Vector2 = e.position
			if _lore_root != null and _lore_root.visible:
				# 详情面板打开时为模态：手指在面板上→滚正文；在暗区→不滚背后（松手由 gui_input 收起）
				_active_scroll = _lore_scroll if (_lore_panel != null and _lore_panel.get_global_rect().has_point(p)) else null
			elif _list_scroll != null and _list_scroll.get_global_rect().has_point(p):
				_active_scroll = _list_scroll
			elif _detail_scroll != null and _detail_scroll.get_global_rect().has_point(p):
				_active_scroll = _detail_scroll
			else:
				_active_scroll = null
		# 松手不复位 _dragging_list：留给紧随的按钮 release 判定，下次按下再清
	elif e is InputEventScreenDrag and _active_scroll != null:
		_drag_amt += absf(e.relative.y)
		if _drag_amt > 10.0:
			_dragging_list = true
		_active_scroll.scroll_vertical -= int(e.relative.y)


func _unhandled_input(e: InputEvent) -> void:
	# ESC：先关小作文浮层；没开则返回主菜单
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if _lore_root != null and _lore_root.visible:
			_hide_lore()
		else:
			get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		get_viewport().set_input_as_handled()


func _ready() -> void:
	_touch = OS.has_feature("mobile") or OS.has_feature("web") or OS.get_environment("TOUCH_UI") == "1"
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 顶栏
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18; top.offset_top = 12; top.offset_right = -18
	add_child(top)
	var title := Label.new()
	title.text = "📖  英雄图鉴 · 水浒英雄传"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("ffd866"))
	top.add_child(title)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	var back := Button.new()
	back.text = "返回主菜单"
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn"))
	top.add_child(back)

	# 主体：左列表 + 右详情
	var body := HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 18; body.offset_top = 58; body.offset_right = -18; body.offset_bottom = -16
	body.add_theme_constant_override("separation", 16)
	add_child(body)

	# 左：分组单位列表（触屏加宽，便于手指点选）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340 if _touch else 232, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list_scroll = scroll
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5 if _touch else 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# 一百单八将（天罡地煞）排在最前，按座次；其余按类型分组。
	var stars: Array = []
	var by_type := {}
	for key in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[key]
		if bool(d.get("building", false)):
			# 建筑统一进「建筑」组：收可建造的 + 主基地(聚义厅)，跳过资源点/装饰/内容包占位
			if not (bool(d.get("buildable", false)) or key == "hall"):
				continue
		elif not CustomConfig.is_combat_unit(d):
			continue
		if Bios.star_rank(key) < 9999:
			stars.append(key)
		else:
			var t := _utype(d)
			if not by_type.has(t):
				by_type[t] = []
			(by_type[t] as Array).append(key)
	# 图鉴专条：STAR 名册里尚无战斗单位条目的一百单八将（新补的天罡/地煞）也列入「天罡地煞」。
	for sk in Bios.STAR:
		if not Defs.UNITS.has(sk):
			stars.append(sk)
	var first := ""
	stars.sort_custom(func(a, b): return Bios.star_rank(a) < Bios.star_rank(b))
	if not stars.is_empty():
		first = stars[0]
		_add_group(list, "天罡地煞 · 梁山一百单八将", stars)
	for t in TYPE_ORDER:
		if not by_type.has(t):
			continue
		var ks: Array = by_type[t]
		ks.sort_custom(func(a, b): return String(Defs.UNITS[a].get("name", a)) < String(Defs.UNITS[b].get("name", b)))
		if first == "":
			first = ks[0]
		_add_group(list, t, ks)

	# 右：详情（放进竖向滚动容器——4 技能英雄的技能详情很长，否则会把「生平」挤出屏幕外看不到）
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(detail_scroll)
	_detail_scroll = detail_scroll
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(detail)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 34)
	_name_lbl.add_theme_color_override("font_color", Color("ffe9a8"))
	detail.add_child(_name_lbl)
	_sub_lbl = Label.new()
	_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_lbl.custom_minimum_size = Vector2(660, 0)
	_sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_lbl.add_theme_font_size_override("font_size", 17)
	_sub_lbl.add_theme_color_override("font_color", Color("c8b890"))
	detail.add_child(_sub_lbl)

	# 三大图：头像 / 移动 / 攻击
	var imgs := HBoxContainer.new()
	imgs.add_theme_constant_override("separation", 18)
	detail.add_child(imgs)
	_port = _img_col(imgs, "头像")
	_walk = _img_col(imgs, "移动动画")
	_atk = _img_col(imgs, "攻击动画")

	# 技能数值（仅有技能组的英雄显示）
	_abil_title = Label.new()
	_abil_title.add_theme_font_size_override("font_size", 20)
	_abil_title.add_theme_color_override("font_color", Color("ffd866"))
	detail.add_child(_abil_title)
	_abil_lbl = Label.new()
	_abil_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_abil_lbl.custom_minimum_size = Vector2(660, 0)
	_abil_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_abil_lbl.add_theme_font_size_override("font_size", 16)
	_abil_lbl.add_theme_color_override("font_color", Color(0.84, 0.9, 0.78))
	detail.add_child(_abil_lbl)

	var bio_head := HBoxContainer.new()
	bio_head.add_theme_constant_override("separation", 14)
	detail.add_child(bio_head)
	var bd_title := Label.new()
	bd_title.text = "生平"
	bd_title.add_theme_font_size_override("font_size", 20)
	bd_title.add_theme_color_override("font_color", Color("ffd866"))
	bio_head.add_child(bd_title)
	var more := Button.new()
	more.text = "详细 ▸"
	more.add_theme_font_size_override("font_size", 16)
	more.focus_mode = Control.FOCUS_NONE
	more.pressed.connect(_show_lore)
	bio_head.add_child(more)
	_bio_lbl = Label.new()
	_bio_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_lbl.custom_minimum_size = Vector2(640, 0)
	_bio_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bio_lbl.add_theme_font_size_override("font_size", 19)
	_bio_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	detail.add_child(_bio_lbl)

	_build_lore_overlay()

	if first != "":
		_select(first)


## 「详细」生平：从右侧推出约半屏的古朴卷轴面板（点左侧暗区 / ✕ / ESC 收起）。
## 修复点：每次打开滚动回顶（不再「共享」上一位的位置）；面板自占半屏、拖动不再误触关闭。
func _build_lore_overlay() -> void:
	_lore_root = ColorRect.new()
	_lore_root.color = Color(0, 0, 0, 0.5)
	_lore_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lore_root.mouse_filter = Control.MOUSE_FILTER_STOP   # 模态：自己接点击、挡住背后图鉴
	_lore_root.visible = false
	# 收起只认「暗区上的明确点击/轻点」：左键单击 或 触屏轻点。
	# 关键：滚轮(WHEEL_*)也是 InputEventMouseButton——正文滚到底时滚轮事件会冒泡到此，
	# 必须按 button_index 过滤掉，否则「滚到底就直接关了」。滚动绝不触发收起。
	_lore_root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_hide_lore()
		elif e is InputEventScreenTouch and e.pressed:
			_hide_lore())
	add_child(_lore_root)

	# 古朴宋体（系统字，零打包）：宋体/明体/思源宋体/Noto Serif CJK，找不到退回衬线
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Songti SC", "STSong", "SimSun", "Source Han Serif SC", "Noto Serif CJK SC", "Noto Serif CJK", "Noto Serif", "Serif", "serif"])

	# 右侧推出的卷轴面板（Panel=自由定位，便于滑入动画）
	_lore_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.91, 0.85, 0.71)          # 米黄宣纸
	sb.border_color = Color(0.42, 0.30, 0.16)       # 深褐装订边
	sb.border_width_left = 5
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	_lore_panel.add_theme_stylebox_override("panel", sb)
	_lore_root.add_child(_lore_panel)

	var cv := VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.offset_left = 38; cv.offset_top = 26; cv.offset_right = -30; cv.offset_bottom = -26
	cv.add_theme_constant_override("separation", 14)
	_lore_panel.add_child(cv)

	# 标题行：名号（朱砂印色）+ ✕
	var head := HBoxContainer.new()
	cv.add_child(head)
	_lore_name = Label.new()
	_lore_name.add_theme_font_override("font", serif)
	_lore_name.add_theme_font_size_override("font_size", 33)
	_lore_name.add_theme_color_override("font_color", Color(0.46, 0.13, 0.10))   # 朱砂
	_lore_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_lore_name)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 26)
	close.add_theme_color_override("font_color", Color(0.35, 0.24, 0.14))
	close.add_theme_color_override("font_hover_color", Color(0.6, 0.18, 0.12))
	close.pressed.connect(_hide_lore)
	head.add_child(close)

	# 朱栏分隔线
	var rule := ColorRect.new()
	rule.color = Color(0.42, 0.30, 0.16, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	cv.add_child(rule)

	# 正文滚动区（横向滚动关→正文按面板宽自动换行）
	_lore_scroll = ScrollContainer.new()
	_lore_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lore_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lore_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(_lore_scroll)
	_lore_text = Label.new()
	_lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lore_text.add_theme_font_override("font", serif)
	_lore_text.add_theme_font_size_override("font_size", 22)
	_lore_text.add_theme_color_override("font_color", Color(0.15, 0.10, 0.05))   # 墨色
	_lore_text.add_theme_constant_override("line_spacing", 13)
	_lore_scroll.add_child(_lore_text)


func _show_lore() -> void:
	if _cur == "" or _lore_root == null:
		return
	var d: Dictionary = Defs.UNITS.get(_cur, {})
	var sl: String = Bios.star_label(_cur)
	_lore_name.text = _disp_name(_cur) + ("　〔%s〕" % sl if sl != "" else "")
	_lore_text.text = Bios.get_lore(_cur, _utype(d))
	var vp: Vector2 = get_viewport_rect().size
	var pw: float = clampf(vp.x * 0.54, 360.0, 760.0)   # 约半屏多一点，限个上下界
	_lore_panel.size = Vector2(pw, vp.y)
	_lore_panel.position = Vector2(vp.x, 0.0)            # 起始：屏幕右外
	_lore_root.visible = true
	_lore_scroll.scroll_vertical = 0                     # 每次打开回到开头（修共享滚动）
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lore_panel, "position:x", vp.x - pw, 0.22)   # 从右推出


func _hide_lore() -> void:
	if _lore_root == null or not _lore_root.visible:
		return
	var vp: Vector2 = get_viewport_rect().size
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_lore_panel, "position:x", vp.x, 0.16)        # 滑回右外
	tw.tween_callback(func() -> void: _lore_root.visible = false)


## 列表分组：一个标题 + 若干单位按钮
func _add_group(list: VBoxContainer, title: String, keys: Array) -> void:
	var hd := Label.new()
	hd.text = "【%s】%d" % [title, keys.size()]
	hd.add_theme_font_size_override("font_size", 18 if _touch else 15)
	hd.add_theme_color_override("font_color", Color("9fd0e8"))
	list.add_child(hd)
	for k in keys:
		var b := Button.new()
		var sl: String = Bios.star_label(k)
		b.text = "  " + _disp_name(k) + ("　" + sl.split(" · ")[1] if sl != "" else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22 if _touch else 17)
		if _touch:
			b.custom_minimum_size = Vector2(0, 54)   # 触屏：加高便于手指点选
		b.focus_mode = Control.FOCUS_NONE
		var key: String = k
		b.pressed.connect(func() -> void:
			if _dragging_list:   # 拖动滚动中误触 → 不选中
				return
			_select(key))
		list.add_child(b)


## 一列：标题 + 动画框
func _img_col(parent: HBoxContainer, cap: String) -> AnimBox:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)
	var box := AnimBox.new()
	col.add_child(box)
	var lb := Label.new()
	lb.text = cap
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.custom_minimum_size = Vector2(232, 0)
	lb.add_theme_font_size_override("font_size", 16)
	lb.add_theme_color_override("font_color", Color("c8b890"))
	col.add_child(lb)
	return box


func _select(key: String) -> void:
	_cur = key
	if _detail_scroll != null:
		_detail_scroll.scroll_vertical = 0   # 切换武将→右侧详情回到顶部（修「共享滚动」）
	var d: Dictionary = Defs.UNITS.get(key, {})
	var t := _utype(d)
	var sl: String = Bios.star_label(key)
	_name_lbl.text = _disp_name(key) + ("　〔%s〕" % sl if sl != "" else "")
	if d.is_empty():
		_sub_lbl.text = "梁山一百单八将 · 图鉴专条"   # 无战斗单位条目者：不显血攻射程
	else:
		_sub_lbl.text = _stat_block(d, t)
	_bio_lbl.text = Bios.get_bio(key, t)
	# 技能（1/2/3 级数值）：有技能组的英雄；战役单将退回单技能
	var abil: Array = d.get("abilities", [])
	if abil.is_empty() and String(d.get("ability", "")) != "":
		abil = [d["ability"]]
	if abil.is_empty():
		_abil_title.text = ""
		_abil_lbl.text = ""
	else:
		_abil_title.text = "技能（数值＝1级 / 2级 / 3级）"
		var slots := ["Q", "W", "E", "R"]
		var txt := ""
		for i in abil.size():
			var aid: String = abil[i]
			var a: Dictionary = Defs.ABILITIES.get(aid, {})
			if a.is_empty():
				continue
			var head: String = (slots[i] if i < slots.size() else "·") + " " + String(a.get("name", aid))
			var eff_d: Dictionary = a.get("effect", {})
			var is_passive := bool(a.get("passive", false))
			var has_active: bool = eff_d.has("active_kind")
			if is_passive and not has_active:
				head += "（被动）"
			else:
				var cr: Array = a.get("cd_ranks", [])
				if cr.size() == 3:
					head += "　cd%s/%s/%ss" % [str(cr[0]), str(cr[1]), str(cr[2])]
				else:
					head += "　cd%ss" % str(a.get("cd", 0.0))
				if is_passive and has_active:
					head += "（被动+主动）"
			# 技能详情：说明文字 + 各级数值速览
			var desc_txt := Defs.ability_desc(aid, 1).replace("\n", "\n    ")
			txt += head + "\n    " + desc_txt + "\n    " + Defs.ability_levels(aid) + "\n\n"
		_abil_lbl.text = txt.strip_edges()
	# 塔：图鉴展示「旋转」——头像=中心格底座；移动/攻击框=循环塔自带的 8 向帧（已脚底对齐→塔身不跳、只武器转）
	if bool(d.get("building", false)) and bool(d.get("ranged", false)) and Art.tower_sheet(key) != null:
		_port.set_frames([Art.tower_dir_texture(key, Vector2i(1, 1))])
		var ring := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
			Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1), Vector2i(0, 0)]   # 顺时针一圈
		# tower_sheet 已非空 → tower_dir_texture 各格必非空，无需逐格判空
		var tf: Array = []
		for rc in ring:
			tf.append(Art.tower_dir_texture(key, rc))
		_walk.set_frames(tf)
		_atk.set_frames(tf)
		return
	# 头像：肖像 → 头像图标 → 立绘
	var ptex: Texture2D = Art.portrait_texture(key)
	if ptex == null:
		ptex = Art.avatar_texture(key)
	if ptex == null:
		ptex = Art.unit_texture(key)
	_port.set_frames([ptex] if ptex != null else [])
	# 移动 / 攻击：逐帧带；无则退回立绘静帧
	var wf: Array = Art.unit_anim_frames(key, "walk")
	if wf.is_empty() and Art.unit_texture(key) != null:
		wf = [Art.unit_texture(key)]
	_walk.set_frames(wf)
	var af: Array = Art.unit_anim_frames(key, "attack")
	if af.is_empty():
		af = wf
	_atk.set_frames(af)


## 显示名：有战斗单位条目用其 name；图鉴专条（仅 STAR 名册）用一百单八将姓名；都没有退回 key。
func _disp_name(key: String) -> String:
	if Defs.UNITS.has(key):
		return String(Defs.UNITS[key].get("name", key))
	var sn := Bios.star_name(key)
	return sn if sn != "" else key


## 详细数值条：血量/攻击/攻击间隔/射程/移速/造价/人口/建造·训练/特性——建筑与英雄/单位通用。
## 本作无独立「护甲」数值（减伤靠护甲科技），故以血量代表耐久；攻击间隔=出手冷却(cd)。
func _stat_block(d: Dictionary, t: String) -> String:
	var p: Array = []
	if int(d.get("hp", 0)) > 0:
		p.append("血量 %d" % int(d.get("hp", 0)))
	var atk := int(d.get("atk", 0))
	if atk > 0:
		p.append("攻击 %d" % atk)
		var cd := float(d.get("cd", 0.0))
		if cd > 0.0:
			p.append("攻击间隔 %.2fs" % cd)
		var rng := int(d.get("range", 0))
		if rng > 0:
			p.append("射程 %d" % rng)
	var spd := int(d.get("speed", 0))
	if spd > 0:
		p.append("移速 %d" % spd)
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if cg > 0 or cw > 0:
		p.append("造价 金%d/木%d" % [cg, cw])
	if int(d.get("pop", 0)) > 0:
		p.append("占人口 %d" % int(d.get("pop", 0)))
	if int(d.get("provides_pop", 0)) > 0:
		p.append("供给人口 +%d" % int(d.get("provides_pop", 0)))
	if int(d.get("build_time", 0)) > 0:
		p.append("建造 %ds" % int(d.get("build_time", 0)))
	if int(d.get("train_time", 0)) > 0:
		p.append("训练 %ds" % int(d.get("train_time", 0)))
	if int(d.get("garrison_cap", 0)) > 0:
		p.append("可驻军 %d" % int(d.get("garrison_cap", 0)))
	if float(d.get("splash", 0.0)) > 0.0:
		p.append("溅射半径 %d" % int(d.get("splash", 0.0)))
	if float(d.get("bonus_cav", 1.0)) > 1.0:
		p.append("克骑兵 ×%.1f" % float(d.get("bonus_cav", 1.0)))
	if float(d.get("bonus_hero", 1.0)) > 1.0:
		p.append("克英雄 ×%.1f" % float(d.get("bonus_hero", 1.0)))
	if float(d.get("slow_mult", 1.0)) < 1.0:
		p.append("减速 %d%%·%.1fs" % [int(round((1.0 - float(d.get("slow_mult", 1.0))) * 100.0)), float(d.get("slow_dur", 0.0))])
	if String(d.get("aura", "")) != "":
		var an: String = {"atk": "攻击", "speed": "移速", "def": "防御"}.get(String(d.get("aura", "")), String(d.get("aura", "")))
		p.append("光环·%s ×%.2f(半径%d)" % [an, float(d.get("aura_p", 1.0)), int(d.get("aura_r", 0))])
	return t + "　|　" + "　".join(p)


func _utype(d: Dictionary) -> String:
	if bool(d.get("building", false)): return "建筑"
	if bool(d.get("hero", false)): return "英雄"
	if bool(d.get("worker", false)): return "工人"
	if bool(d.get("cavalry", false)): return "骑兵"
	if bool(d.get("ranged", false)): return "远程"
	return "步兵"


## 动画框：>1 帧时按 fps 循环播放（塔=循环 8 向帧即转向动画），否则静态展示。
class AnimBox extends Control:
	var frames: Array = []
	var fps := 6.0
	var _t := 0.0
	var _i := 0

	func _init() -> void:
		custom_minimum_size = Vector2(232, 232)

	func set_frames(fr: Array) -> void:
		frames = fr; _i = 0; _t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		if frames.size() > 1:
			_t += delta * fps
			if _t >= 1.0:
				_t -= 1.0
				_i = (_i + 1) % frames.size()
				queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.10, 0.07))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.37, 0.24), false, 2.0)
		if frames.is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(0, size.y * 0.52), "—", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(0.5, 0.45, 0.4))
			return
		var tex: Texture2D = frames[_i % frames.size()]
		if tex == null:
			return
		var ts := tex.get_size()
		if ts.x <= 0.0 or ts.y <= 0.0:
			return
		var sc: float = minf((size.x - 16.0) / ts.x, (size.y - 16.0) / ts.y)
		var dsz := ts * sc
		draw_texture_rect(tex, Rect2((size - dsz) * 0.5, dsz), false)
