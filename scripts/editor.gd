extends Control
## 自定义据守·关卡编辑器（主程序内置）。改单位/技能数值 + 敌方波次，JSON 存读到 user://custom_defense。
## 程序化构建 UI；首次引入 LineEdit/OptionButton/ScrollContainer。中文走 ThemeDB.fallback_font。

var _cfg: Dictionary = {}
var _section := "units"          # units / abilities / waves
var _body: VBoxContainer         # 当前分页的滚动内容
var _name_edit: LineEdit
var _toast: Label
var _combat_keys: Array = []     # 波次兵种下拉用：全部战斗单位 key（按名）
var _unit_filter := ""           # 单位分页搜索过滤（按名）


func _ready() -> void:
	_cfg = CustomConfig.default_config()
	for k in _cfg["units"]:
		_combat_keys.append(k)
	_combat_keys.sort()
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b1712")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16; root.offset_top = 12; root.offset_right = -16; root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# —— 顶栏：标题 + 配置名 + 文件操作 ——
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var ttl := Label.new()
	ttl.text = "关卡编辑器 · 自定义据守"
	ttl.add_theme_font_size_override("font_size", 22)
	ttl.add_theme_color_override("font_color", Color("ffe9a8"))
	top.add_child(ttl)
	var nl := Label.new(); nl.text = "  配置名："; top.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = String(_cfg.get("name", "我的据守"))
	_name_edit.custom_minimum_size = Vector2(180, 34)
	_name_edit.text_changed.connect(func(t: String) -> void: _cfg["name"] = t)
	top.add_child(_name_edit)
	top.add_child(_btn("新建(默认)", func() -> void: _cfg = CustomConfig.default_config(); _name_edit.text = _cfg["name"]; _rebuild()))
	top.add_child(_btn("读取", _show_load))
	top.add_child(_btn("保存", func() -> void:
		var p := CustomConfig.save(_cfg)
		_show_toast("已保存：" + p if p != "" else "保存失败")))
	top.add_child(_btn("分享码", _show_share))
	top.add_child(_btn("导入码", _show_import))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	top.add_child(_btn("返回菜单", func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn")))

	# —— 分页切换 ——
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	root.add_child(tabs)
	for t in [["单位数值", "units"], ["技能数值", "abilities"], ["敌方波次", "waves"], ["全局/起始", "global"]]:
		var key: String = t[1]
		tabs.add_child(_btn(t[0], func() -> void: _section = key; _rebuild()))

	# —— 主体滚动区 ——
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)

	_toast = Label.new()
	_toast.add_theme_color_override("font_color", Color("9fe8b0"))
	root.add_child(_toast)

	_rebuild()


## 重建主体（切分页 / 结构变化时）
func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	match _section:
		"units": _build_units()
		"abilities": _build_abilities()
		"waves": _build_waves()
		"global": _build_global()


# ---------- 全局/起始分页 ----------
func _build_global() -> void:
	_body.add_child(_hdr("自定义据守 · 开局设置"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_lbl("起始金", 70)); row.add_child(_num(_cfg, "start_gold", 90))
	row.add_child(_lbl("起始木", 70)); row.add_child(_num(_cfg, "start_wood", 90))
	row.add_child(_lbl("人口上限", 84)); row.add_child(_num(_cfg, "pop_cap", 90))
	row.add_child(_lbl("英雄上限", 84)); row.add_child(_num(_cfg, "hero_cap", 70, 6.0))
	_body.add_child(row)
	_body.add_child(_hdr("说明：负数/超大值会自动收敛到合理范围；改完去「保存」存档，主菜单「自定义据守」加载开打。"))


# ---------- 单位分页 ----------
func _build_units() -> void:
	_body.add_child(_hdr("单位数值（敌我全单位，含战役登场，共 %d 个）：血 / 攻 / 防 / 射程 / 攻速(秒) / 移速" % _cfg["units"].size()))
	# 搜索框：按名过滤（持续打字不丢焦点——过滤态下重建后回焦）
	var search := LineEdit.new()
	search.placeholder_text = "🔍 搜索单位名（如 林冲 / 官军 / 祝家）…"
	search.text = _unit_filter
	search.custom_minimum_size = Vector2(320, 32)
	search.text_changed.connect(func(t: String) -> void:
		_unit_filter = t; _rebuild())
	_body.add_child(search)
	if _unit_filter != "":
		search.grab_focus.call_deferred()
		search.caret_column = _unit_filter.length()
	# 按类型分组（英雄/步兵/远程/骑兵/工人/建筑），战役登场的好汉与敌将都各归其位、一目了然
	var order := ["英雄", "步兵", "远程", "骑兵", "工人", "建筑"]
	var by_type := {}
	for k in _cfg["units"].keys():
		if _unit_filter != "" and not String(_cfg["units"][k].get("name", k)).contains(_unit_filter):
			continue
		var t := _unit_type(Defs.UNITS.get(k, {}))
		if not by_type.has(t):
			by_type[t] = []
		(by_type[t] as Array).append(k)
	for t in order:
		if not by_type.has(t):
			continue
		var ks: Array = by_type[t]
		ks.sort()
		_body.add_child(_hdr("【%s】 %d 个" % [t, ks.size()]))
		for k in ks:
			_body.add_child(_unit_row(k))


func _unit_row(k: String) -> HBoxContainer:
	var u: Dictionary = _cfg["units"][k]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var nm := Label.new()
	nm.text = String(u.get("name", k))
	nm.custom_minimum_size = Vector2(96, 30)
	row.add_child(nm)
	for f in CustomConfig.UNIT_FIELDS:
		row.add_child(_lbl(_field_label(f)))
		row.add_child(_num(u, f))
	return row


func _unit_type(d: Dictionary) -> String:
	if bool(d.get("building", false)): return "建筑"
	if bool(d.get("hero", false)): return "英雄"
	if bool(d.get("worker", false)): return "工人"
	if bool(d.get("cavalry", false)): return "骑兵"
	if bool(d.get("ranged", false)): return "远程"
	return "步兵"


# ---------- 技能分页 ----------
func _build_abilities() -> void:
	_body.add_child(_hdr("技能数值：冷却(秒) / 范围 / 效果参数（伤害·减速·眩晕…）"))
	var keys: Array = _cfg["abilities"].keys()
	keys.sort()
	for id in keys:
		var a: Dictionary = _cfg["abilities"][id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var nm := Label.new()
		nm.text = String(a.get("name", id))
		nm.custom_minimum_size = Vector2(96, 30)
		row.add_child(nm)
		row.add_child(_lbl("冷却")); row.add_child(_num(a, "cd"))
		row.add_child(_lbl("范围")); row.add_child(_num(a, "radius"))
		if a.has("effect"):
			var eff: Dictionary = a["effect"]
			for k in eff:
				if k == "kind":
					continue
				if not (eff[k] is float or eff[k] is int):
					continue
				row.add_child(_lbl(_field_label(k))); row.add_child(_num(eff, k))
		_body.add_child(row)


# ---------- 波次分页 ----------
func _build_waves() -> void:
	_body.add_child(_hdr("敌方波次：每波间隔(秒) / 投石车数 / 各组[兵种·数量·出兵口0东1北2南]"))
	var waves: Array = _cfg["waves"]
	for i in range(waves.size()):
		var w: Dictionary = waves[i]
		var panel := PanelContainer.new()
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 3)
		panel.add_child(pv)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		head.add_child(_lbl("第 %d 波" % (i + 1), 60))
		head.add_child(_lbl("间隔")); head.add_child(_num(w, "t"))
		head.add_child(_lbl("投石车")); head.add_child(_num(w, "cata", 56, 9))
		var idx := i
		head.add_child(_btn("+兵组", func() -> void: (w["groups"] as Array).append(["guan_dao", 5, 0, 2]); _rebuild()))
		head.add_child(_btn("删本波", func() -> void: (_cfg["waves"] as Array).remove_at(idx); _rebuild()))
		pv.add_child(head)
		# 本波提示语（出兵时飘在屏幕上）
		var msg_row := HBoxContainer.new()
		msg_row.add_theme_constant_override("separation", 6)
		msg_row.add_child(_lbl("　提示语", 60))
		var msg_le := LineEdit.new()
		msg_le.text = String(w.get("msg", ""))
		msg_le.custom_minimum_size = Vector2(380, 30)
		msg_le.text_changed.connect(func(t: String) -> void: w["msg"] = t)
		msg_row.add_child(msg_le)
		pv.add_child(msg_row)
		var groups: Array = w["groups"]
		for gi in range(groups.size()):
			pv.add_child(_group_row(groups, gi))
		_body.add_child(panel)
	_body.add_child(_btn("＋ 增加一波", func() -> void:
		(_cfg["waves"] as Array).append({"t": 30.0, "msg": "新一波官军杀到！", "groups": [["guan_dao", 6, 0, 2]], "cata": 1})
		_rebuild()))


func _group_row(groups: Array, gi: int) -> HBoxContainer:
	var g: Array = groups[gi]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_lbl("　兵种", 50))
	var opt := OptionButton.new()
	var sel := 0
	for ki in range(_combat_keys.size()):
		var k: String = _combat_keys[ki]
		opt.add_item(String(_cfg["units"][k].get("name", k)))
		opt.set_item_metadata(ki, k)
		if k == String(g[0]):
			sel = ki
	opt.select(sel)
	opt.item_selected.connect(func(idx: int) -> void: g[0] = opt.get_item_metadata(idx))
	row.add_child(opt)
	row.add_child(_lbl("数量"))
	row.add_child(_num_arr(g, 1, 56, 1, 200))
	row.add_child(_lbl("出兵口"))
	row.add_child(_num_arr(g, 2, 56, 0, 2))
	if g.size() < 4:
		g.append(2)
	row.add_child(_lbl("将技Lv"))
	row.add_child(_num_arr(g, 3, 46, 0, 2))   # 敌将技能等级 0~2（只对有技能的将领生效）
	row.add_child(_btn("删", func() -> void: groups.remove_at(gi); _rebuild()))
	return row


# ---------- 控件工厂 ----------
func _num(d: Dictionary, key: String, w := 64, hi := 99999.0) -> LineEdit:
	var le := LineEdit.new()
	le.custom_minimum_size = Vector2(w, 30)
	le.text = _fmt(d.get(key, 0))
	# 输入校验：收敛到 [0, hi]，并把规整后的值写回输入框（负数/乱填即时纠正）
	var commit := func(t: String) -> void:
		var v: float = clampf(t.to_float(), 0.0, hi)
		d[key] = v
		le.text = _fmt(v)
	le.text_submitted.connect(commit)
	le.focus_exited.connect(func() -> void: commit.call(le.text))
	return le


func _num_arr(arr: Array, idx: int, w := 56, lo := 0, hi := 9999) -> LineEdit:
	var le := LineEdit.new()
	le.custom_minimum_size = Vector2(w, 30)
	le.text = _fmt(arr[idx])
	var commit := func(t: String) -> void:
		var v: int = clampi(int(t.to_float()), lo, hi)
		arr[idx] = v
		le.text = str(v)
	le.text_submitted.connect(commit)
	le.focus_exited.connect(func() -> void: commit.call(le.text))
	return le


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b


func _lbl(text: String, w := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color("cfc4a8"))
	if w > 0:
		l.custom_minimum_size = Vector2(w, 0)
	return l


func _hdr(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color("ffd866"))
	return l


func _field_label(f: String) -> String:
	return {"hp": "血", "atk": "攻", "defense": "防", "range": "射程", "cd": "攻速", "speed": "移速",
		"dmg": "伤害", "slow": "减速", "slow_dur": "减速时长", "stun": "眩晕", "dur": "持续",
		"heal": "治疗", "atk_mult": "攻倍", "speed_mult": "速倍", "atk_add": "加攻",
		"hp_add": "加血", "regen": "回血", "lifesteal": "吸血", "len": "长度", "width": "宽度",
		"windup": "蓄力", "dist": "距离", "tick": "间隔", "bonus_cav": "克骑",
		"cav_bonus": "克骑", "radius": "范围"}.get(f, f)


func _fmt(v: Variant) -> String:
	var f := float(v)
	if f == floor(f):
		return str(int(f))
	return str(f)


func _show_toast(msg: String) -> void:
	_toast.text = msg


func _show_load() -> void:
	var saved: Array = CustomConfig.list_saved()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var t := Label.new()
	t.text = "读取配置" if not saved.is_empty() else "没有已保存的配置"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color("ffe9a8"))
	box.add_child(t)
	for name in saved:
		var nm: String = name
		var b := Button.new(); b.text = String(name); b.custom_minimum_size = Vector2(300, 40)
		b.pressed.connect(func() -> void:
			var cfg: Dictionary = CustomConfig.load_by_name(nm)
			if not cfg.is_empty():
				_cfg = cfg; _name_edit.text = String(_cfg.get("name", nm))
				_show_toast("已读取：" + nm)
			overlay.queue_free(); _rebuild())
		box.add_child(b)
	var back := Button.new(); back.text = "取消"; back.custom_minimum_size = Vector2(300, 36)
	back.pressed.connect(overlay.queue_free)
	box.add_child(back)


## 通用居中弹层（半透底 + 竖排盒），返回 [overlay, box] 供填内容。
func _overlay() -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	return [overlay, box]


## 分享码：把当前配置编码成 base64 文本，全选复制发给好友。
func _show_share() -> void:
	var ov := _overlay()
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]
	var t := Label.new()
	t.text = "分享码 —— 点「复制」发给好友，对方「导入码」粘贴即可载入此据守设计"
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color("ffe9a8"))
	box.add_child(t)
	var code := Marshalls.utf8_to_base64(JSON.stringify(_cfg))
	var te := TextEdit.new()
	te.text = code
	te.editable = false
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(620, 320)
	box.add_child(te)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); box.add_child(row)
	var cp := Button.new(); cp.text = "复制到剪贴板"; cp.custom_minimum_size = Vector2(200, 38)
	cp.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(code); _show_toast("分享码已复制（%d 字）" % code.length()))
	row.add_child(cp)
	var cl := Button.new(); cl.text = "关闭"; cl.custom_minimum_size = Vector2(160, 38)
	cl.pressed.connect(overlay.queue_free)
	row.add_child(cl)


## 导入码：粘贴分享码 → 解码校验 → 载入配置。
func _show_import() -> void:
	var ov := _overlay()
	var overlay: ColorRect = ov[0]
	var box: VBoxContainer = ov[1]
	var t := Label.new()
	t.text = "导入码 —— 把好友给的分享码粘贴到下框，点「导入」"
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color("ffe9a8"))
	box.add_child(t)
	var te := TextEdit.new()
	te.placeholder_text = "在此粘贴分享码…"
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size = Vector2(620, 300)
	box.add_child(te)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); box.add_child(row)
	var imp := Button.new(); imp.text = "导入"; imp.custom_minimum_size = Vector2(200, 38)
	imp.pressed.connect(func() -> void:
		var raw := te.text.strip_edges()
		var js := Marshalls.base64_to_utf8(raw) if raw != "" else ""
		var parsed: Variant = JSON.parse_string(js) if js != "" else null
		if parsed is Dictionary and (parsed as Dictionary).has("units") and (parsed as Dictionary).has("waves"):
			_cfg = parsed
			_name_edit.text = String(_cfg.get("name", "导入的据守"))
			_show_toast("已导入：" + String(_cfg.get("name", "")))
			overlay.queue_free(); _rebuild()
		else:
			_show_toast("分享码无效，请检查是否完整复制"))
	row.add_child(imp)
	var cl := Button.new(); cl.text = "取消"; cl.custom_minimum_size = Vector2(160, 38)
	cl.pressed.connect(overlay.queue_free)
	row.add_child(cl)
