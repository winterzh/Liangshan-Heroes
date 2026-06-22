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
var _lore_name: Label
var _lore_text: Label
var _detail_scroll: ScrollContainer


func _unhandled_input(e: InputEvent) -> void:
	# ESC：先关小作文浮层；没开则返回主菜单
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		if _lore_root != null and _lore_root.visible:
			_hide_lore()
		else:
			get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")
		get_viewport().set_input_as_handled()


func _ready() -> void:
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

	# 左：分组单位列表
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(232, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# 一百单八将（天罡地煞）排在最前，按座次；其余按类型分组。
	var stars: Array = []
	var by_type := {}
	for key in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[key]
		if not CustomConfig.is_combat_unit(d):
			continue
		if Bios.star_rank(key) < 9999:
			stars.append(key)
		else:
			var t := _utype(d)
			if not by_type.has(t):
				by_type[t] = []
			(by_type[t] as Array).append(key)
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


## 「详细」小传弹层（默认隐藏）
func _build_lore_overlay() -> void:
	_lore_root = ColorRect.new()
	_lore_root.color = Color(0, 0, 0, 0.74)
	_lore_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lore_root.visible = false
	_lore_root.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_hide_lore())
	add_child(_lore_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lore_root.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 480)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.07, 1.0)
	sb.border_color = Color("8a6a3a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	card.add_child(cv)
	_lore_name = Label.new()
	_lore_name.add_theme_font_size_override("font_size", 28)
	_lore_name.add_theme_color_override("font_color", Color("ffe9a8"))
	cv.add_child(_lore_name)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(716, 360)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(sc)
	_lore_text = Label.new()
	_lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_text.custom_minimum_size = Vector2(700, 0)
	_lore_text.add_theme_font_size_override("font_size", 20)
	_lore_text.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	_lore_text.add_theme_constant_override("line_spacing", 8)
	sc.add_child(_lore_text)
	var close := Button.new()
	close.text = "关闭"
	close.add_theme_font_size_override("font_size", 18)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_hide_lore)
	cv.add_child(close)


func _show_lore() -> void:
	if _cur == "" or _lore_root == null:
		return
	var d: Dictionary = Defs.UNITS.get(_cur, {})
	var sl: String = Bios.star_label(_cur)
	_lore_name.text = String(d.get("name", _cur)) + ("　〔%s〕" % sl if sl != "" else "")
	_lore_text.text = Bios.get_lore(_cur, _utype(d))
	_lore_root.visible = true


func _hide_lore() -> void:
	if _lore_root != null:
		_lore_root.visible = false


## 列表分组：一个标题 + 若干单位按钮
func _add_group(list: VBoxContainer, title: String, keys: Array) -> void:
	var hd := Label.new()
	hd.text = "【%s】%d" % [title, keys.size()]
	hd.add_theme_font_size_override("font_size", 15)
	hd.add_theme_color_override("font_color", Color("9fd0e8"))
	list.add_child(hd)
	for k in keys:
		var b := Button.new()
		var sl: String = Bios.star_label(k)
		b.text = "  " + String(Defs.UNITS[k].get("name", k)) + ("　" + sl.split(" · ")[1] if sl != "" else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = k
		b.pressed.connect(func() -> void: _select(key))
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
	var d: Dictionary = Defs.UNITS.get(key, {})
	var t := _utype(d)
	var sl: String = Bios.star_label(key)
	_name_lbl.text = String(d.get("name", key)) + ("　〔%s〕" % sl if sl != "" else "")
	_sub_lbl.text = "%s　血 %d　攻 %d　射程 %d" % [t, int(d.get("hp", 0)), int(d.get("atk", 0)), int(d.get("range", 0))]
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


func _utype(d: Dictionary) -> String:
	if bool(d.get("building", false)): return "建筑"
	if bool(d.get("hero", false)): return "英雄"
	if bool(d.get("worker", false)): return "工人"
	if bool(d.get("cavalry", false)): return "骑兵"
	if bool(d.get("ranged", false)): return "远程"
	return "步兵"


## 动画框：>1 帧时按 fps 循环播放，否则静态展示。
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
