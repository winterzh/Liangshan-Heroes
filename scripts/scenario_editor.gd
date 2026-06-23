extends Control
## 场景编辑器（Phase B）：可视化造关。俯视网格上刷地形 / 放兵 / 设出兵口 / 镜头起点，
## 右栏调地图与波次、选胜负预设，存为 scenario JSON（user://scenarios/），可直接「试玩」。
## 编辑用俯视格（精确无 ISO 畸变）；试玩时引擎照常等距渲染。格式见 docs/SCENARIO_FORMAT.md。

const TERRAINS := ["GRASS", "WATER", "SHORE", "MARSH", "REEDS", "ROAD", "FOREST",
	"DRYHILL", "CLIFF", "TOWN", "PLAZA", "FIELD", "PLAIN", "DOCK", "HALL"]
const GATE_NAMES := ["E", "S", "W", "N", "E2", "S2"]
const THEMES := ["marsh", "plain", "hills", "town"]
# 装饰物贴图键（纯美观，用 Art.terrain_texture 渲染的景物子集）
const DECOR_KEYS := ["tower", "banner", "tent", "boat", "bridge", "rocks", "pine",
	"town_house", "scaffold", "treasure_cart", "gold_mine", "palisade"]
const DECOR_LABELS := {"tower": "箭塔", "banner": "旗", "tent": "营帐", "boat": "船", "bridge": "桥",
	"rocks": "石", "pine": "松", "town_house": "民房", "scaffold": "刑台", "treasure_cart": "宝车",
	"gold_mine": "金矿", "palisade": "栅栏"}

# 单位属性表（编辑器属性栏）：[字段, 中文标签, 类型]。enum 用 | 分隔选项，首项空=「无」。
const UNIT_SCHEMA := [
	["name", "名称", "str"], ["hp", "生命", "int"], ["atk", "攻击", "int"], ["cd", "攻击间隔", "float"],
	["range", "攻击距离", "int"], ["speed", "移速", "int"], ["radius", "体型", "int"], ["pop", "人口", "int"],
	["cost_gold", "造价·金", "int"], ["cost_wood", "造价·木", "int"], ["train_time", "训练耗时", "float"], ["min_age", "时代门槛", "int"],
	["hero", "英雄", "bool"], ["ranged", "远程", "bool"], ["cavalry", "骑兵", "bool"], ["worker", "工人", "bool"],
	["building", "建筑", "bool"], ["buildable", "可建造", "bool"], ["build_order", "建造序", "int"], ["build_time", "建造耗时", "float"],
	["melee_switch", "可拔刀", "bool"], ["drop_off", "卸货点", "bool"], ["is_main_base", "主基地", "bool"], ["is_altar", "祭坛", "bool"],
	["garrison_cap", "驻军容量", "int"], ["provides_pop", "提供人口", "int"], ["splash", "溅射半径", "float"], ["bonus_cav", "克骑倍率", "float"],
	["aura", "光环", "enum:|atk|speed"], ["aura_r", "光环半径", "int"], ["aura_p", "光环倍率", "float"],
	["trained_at", "训练于(建筑id)", "str"], ["proj_kind", "弹道", "enum:|arrow|fireball|boulder"],
	["ability", "主技能id", "str"], ["abilities", "技能组(逗号分隔)", "list"],
]
# 技能属性表
const ABILITY_SCHEMA := [
	["name", "名称", "str"], ["cd", "冷却", "float"], ["radius", "范围", "int"],
	["targeted", "指向(点地放)", "bool"], ["weak_global", "弱托管全屏", "bool"], ["passive", "被动", "bool"],
	["effect.kind", "效果类型", "enum:smite|rally|haste|fire_dot|self_buff|summon|debuff|drag|passive|sector_nuke|blink_shot|charge|orbit_axes|chrono|black_rain|ice_wall|slow_aura|drunk_buff|drunk_god|weapon_toggle|path"],
	["effect.dmg", "伤害", "int"], ["effect.heal", "治疗", "int"], ["effect.dur", "持续", "float"],
	["effect.slow", "减速(0-1)", "float"], ["effect.slow_dur", "减速时长", "float"], ["effect.stun", "眩晕", "float"],
	["effect.self_atk", "自身攻×", "float"], ["effect.self_dur", "自增时长", "float"], ["effect.lifesteal", "吸血", "float"],
	["effect.atk_mult", "队友攻×", "float"], ["effect.atk_add", "攻+", "int"], ["effect.hp_add", "血+", "int"],
	["effect.range_add", "射程+", "int"], ["effect.bonus_cav", "克骑×", "float"], ["effect.speed_mult", "移速×", "float"],
	["effect.dot_total", "持续伤害", "int"], ["effect.dot_dur", "持续伤害时长", "float"],
	["effect.range", "作用距离", "int"], ["effect.len", "长度", "int"], ["effect.width", "宽度", "int"],
	["effect.unit", "召唤单位id", "str"], ["effect.count", "召唤数", "int"],
]

var _cfg: Dictionary
var _map: GameMap                  # 地形工作模型（不入树，仅存格 + 供绘制读取）
var tool := "terrain"              # terrain / unit / gate / camera / erase
var cur_terrain := "WATER"
var brush := 1
var cur_unit := "liang_dao"
var cur_faction := "LIANG"
var cur_gate := "E"
var cur_decor := "tower"
var cur_decor_size := 64.0
var cur_rf_wave := 1               # 「放增援」目标波次（1 基）
var cur_rf_faction := "LIANG"

var _canvas: MapCanvas
var _toast: Label
var _toast_t := 0.0
var _name_edit: LineEdit
var _tool_panel: VBoxContainer     # 左栏随工具切换的子面板
var _waves_box: VBoxContainer
var _intro_box: VBoxContainer
var _place_keys: Array = []        # 可放置单位 key（按名）
var _combat_keys: Array = []       # 波次可用兵种 key
# 单位/技能编辑器状态（双击「用到的」单位 → 上下文编辑，只覆盖本场景）
var _eu_root: Control
var _eu_form: VBoxContainer
var _eu_key := ""


func _ready() -> void:
	_cfg = ScenarioStore.default_scenario()
	_refresh_unit_keys()
	_rebuild_map_model()
	_build()


## 重算可放置/可入波的单位 key（含本场景自定义/覆盖的单位）。单位编辑后调用以刷新各处下拉。
func _refresh_unit_keys() -> void:
	_place_keys.clear()
	_combat_keys.clear()
	var src := {}
	for k in Defs.UNITS:
		src[k] = Defs.UNITS[k]
	for k in _cfg.get("units", {}):
		src[k] = _cfg["units"][k]   # 自定义/覆盖优先
	for k in src:
		var d: Dictionary = src[k]
		if d.has("res_kind"):
			continue
		_place_keys.append(k)
		if not bool(d.get("building", false)) and (float(d.get("atk", 0)) > 0 or bool(d.get("ranged", false)) or bool(d.get("hero", false)) or bool(d.get("cavalry", false))):
			_combat_keys.append(k)
	_place_keys.sort()
	_combat_keys.sort()


## 单位的「有效定义」：本场景覆盖 > 全局 Defs。名字查找同理。
func _udef(k: String) -> Dictionary:
	return _cfg.get("units", {}).get(k, Defs.UNITS.get(k, {}))

func _uname(k: String) -> String:
	return String(_udef(k).get("name", k))


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast != null:
			_toast.visible = false


## ---------- 地形工作模型 ----------

func _rebuild_map_model() -> void:
	var m: Dictionary = _cfg.get("map", {})
	_map = GameMap.new()
	_map.init_map(int(m.get("w", 48)), int(m.get("h", 48)), String(m.get("theme", "marsh")), _t(m.get("base", "GRASS")))
	# 把已有 terrain 指令光栅化进工作格（复用 scenario.gd 的解释器），这样旧关也能再编辑
	var sc = load("res://scripts/levels/scenario.gd").new()
	sc.data = _cfg
	sc.paint_map(_map)


func _t(v) -> int:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return int(GameMap.T.get(String(v), GameMap.T.GRASS))


## 把工作格压回 _cfg.terrain（base 之外的格逐个 set_cell；丢失原 ellipse/path 写法但地图等价）
func _flush_terrain() -> void:
	var base := _t(_cfg.get("map", {}).get("base", "GRASS"))
	var ops: Array = []
	for y in range(_map.h):
		for x in range(_map.w):
			var t := _map.t_at(x, y)
			if t != base:
				ops.append({"op": "set_cell", "c": [x, y], "t": _name_of(t)})
	_cfg["terrain"] = ops


func _name_of(t: int) -> String:
	for n in GameMap.T:
		if int(GameMap.T[n]) == t:
			return n
	return "GRASS"


## ---------- UI 主体 ----------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("191510")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10; root.offset_top = 8; root.offset_right = -10; root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# 顶栏
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var ttl := Label.new()
	ttl.text = "场景编辑器"
	ttl.add_theme_font_size_override("font_size", 22)
	ttl.add_theme_color_override("font_color", Color("ffe9a8"))
	top.add_child(ttl)
	var nl := Label.new(); nl.text = "  关名："; top.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = String(_cfg.get("title", "我的关卡"))
	_name_edit.custom_minimum_size = Vector2(180, 32)
	_name_edit.text_changed.connect(func(t: String) -> void: _cfg["title"] = t)
	top.add_child(_name_edit)
	top.add_child(_btn("新建", func() -> void:
		_cfg = ScenarioStore.default_scenario(); _name_edit.text = _cfg["title"]; _rebuild_map_model(); _build()))
	top.add_child(_btn("读取", _show_load))
	top.add_child(_btn("保存", func() -> void:
		_flush_terrain()
		var p := ScenarioStore.save(_cfg)
		_show_toast("已保存：" + p if p != "" else "保存失败")))
	var mod := _btn("📋 已改单位", _show_modified_units)
	mod.add_theme_color_override("font_color", Color("87cefa"))
	mod.tooltip_text = "查看/编辑本关改过或自定义的单位"
	top.add_child(mod)
	var play := _btn("▶ 试玩", _playtest)
	play.add_theme_color_override("font_color", Color("9fe06f"))
	top.add_child(play)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	top.add_child(_btn("返回菜单", func() -> void:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")))

	# 三栏：左工具 / 中画布 / 右属性
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 6)
	root.add_child(cols)

	# 左：工具
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(190, 0)
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	_build_tools(left)

	# 中：画布
	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(center)
	_canvas = MapCanvas.new()
	_canvas.ed = self
	center.add_child(_canvas)

	# 右：属性 + 波次
	var rightscroll := ScrollContainer.new()
	rightscroll.custom_minimum_size = Vector2(348, 0)   # 加宽，避免「据守：守基地+撑过所有波」等文字被截断
	rightscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(rightscroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	rightscroll.add_child(right)
	_build_props(right)

	# Toast
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color("ffe9a8"))
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_bottom = -6; _toast.offset_top = -34
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	add_child(_toast)


func _build_tools(left: VBoxContainer) -> void:
	var hint := Label.new()
	hint.text = "工具"
	hint.add_theme_color_override("font_color", Color("ffd866"))
	left.add_child(hint)
	for t in [["选择/改单位", "select"], ["刷地形", "terrain"], ["放单位", "unit"], ["放装饰", "decor"], ["放增援", "reinforce"], ["出兵口", "gate"], ["镜头起点", "camera"], ["擦除", "erase"]]:
		var key: String = t[1]
		var b := _btn(t[0], func() -> void: tool = key; _refresh_tool_panel())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == "select":
			b.add_theme_color_override("font_color", Color("87cefa"))
		left.add_child(b)
	left.add_child(HSeparator.new())
	_tool_panel = VBoxContainer.new()
	_tool_panel.add_theme_constant_override("separation", 3)
	left.add_child(_tool_panel)
	_refresh_tool_panel()
	left.add_child(HSeparator.new())
	var tip := Label.new()
	tip.text = "左键画/放，右键拖动平移，滚轮缩放"
	tip.add_theme_font_size_override("font_size", 11)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", Color("9a8f7a"))
	left.add_child(tip)


func _refresh_tool_panel() -> void:
	if _tool_panel == null:
		return
	for c in _tool_panel.get_children():
		c.queue_free()
	match tool:
		"select":
			var l := Label.new(); l.text = "选择 / 改单位"; l.add_theme_color_override("font_color", Color("87cefa")); _tool_panel.add_child(l)
			var tip := Label.new()
			tip.text = "双击地图上已放置的单位\n→ 编辑它的属性 / 技能。\n右栏波次里点单位旁「✎」同理。\n只有改过的单位会被写入本关，\n其余单位保持默认。改动仅本图生效。"
			tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tip.add_theme_font_size_override("font_size", 12); tip.add_theme_color_override("font_color", Color("b8c4d4"))
			_tool_panel.add_child(tip)
		"terrain":
			var l := Label.new(); l.text = "地形"; l.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(l)
			var grid := GridContainer.new(); grid.columns = 2; _tool_panel.add_child(grid)
			for tn in TERRAINS:
				var sw := Button.new()
				sw.text = _terrain_label(tn)
				sw.custom_minimum_size = Vector2(82, 26)
				sw.add_theme_font_size_override("font_size", 12)
				var col := Color(GameMap.INFO[_t(tn)]["color"])
				sw.add_theme_color_override("font_color", Color.WHITE if col.get_luminance() < 0.5 else Color.BLACK)
				var sb := StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(4); sw.add_theme_stylebox_override("normal", sb)
				var t2: String = tn
				sw.pressed.connect(func() -> void: cur_terrain = t2; _show_toast("地形：" + _terrain_label(t2)))
				grid.add_child(sw)
			var bl := Label.new(); bl.text = "笔刷大小"; _tool_panel.add_child(bl)
			var bsl := HSlider.new(); bsl.min_value = 1; bsl.max_value = 4; bsl.step = 1; bsl.value = brush
			bsl.custom_minimum_size = Vector2(0, 20)
			bsl.value_changed.connect(func(v: float) -> void: brush = int(v))
			_tool_panel.add_child(bsl)
		"unit":
			var fl := Label.new(); fl.text = "阵营"; fl.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(fl)
			var fb := HBoxContainer.new(); _tool_panel.add_child(fb)
			for f in [["梁山", "LIANG"], ["官军", "GUAN"]]:
				var fk: String = f[1]
				var fbtn := _btn(f[0], func() -> void: cur_faction = fk; _show_toast("阵营：" + String(f[0])))
				fb.add_child(fbtn)
			var ul := Label.new(); ul.text = "单位（点选）"; ul.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(ul)
			var us := ScrollContainer.new(); us.custom_minimum_size = Vector2(0, 260); _tool_panel.add_child(us)
			var ub := VBoxContainer.new(); ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL; us.add_child(ub)
			for k in _place_keys:
				var nm := _uname(k)
				var kk: String = k
				var kb := _btn(nm, func() -> void: cur_unit = kk; _show_toast("单位：" + nm))
				kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ub.add_child(kb)
		"decor":
			var dl := Label.new(); dl.text = "装饰物（纯美观）"; dl.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(dl)
			var dgrid := GridContainer.new(); dgrid.columns = 2; _tool_panel.add_child(dgrid)
			for dk in DECOR_KEYS:
				var dkk: String = dk
				var dbtn := _btn(String(DECOR_LABELS.get(dk, dk)), func() -> void: cur_decor = dkk; _show_toast("装饰：" + String(DECOR_LABELS.get(dkk, dkk))))
				dbtn.custom_minimum_size = Vector2(82, 26)
				dgrid.add_child(dbtn)
			var dsl_l := Label.new(); dsl_l.text = "尺寸"; _tool_panel.add_child(dsl_l)
			var dsl := HSlider.new(); dsl.min_value = 32; dsl.max_value = 120; dsl.step = 4; dsl.value = cur_decor_size
			dsl.custom_minimum_size = Vector2(0, 20)
			dsl.value_changed.connect(func(v: float) -> void: cur_decor_size = v)
			_tool_panel.add_child(dsl)
		"reinforce":
			var rl := Label.new(); rl.text = "波次增援（影响战局）"; rl.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(rl)
			var nwaves: int = maxi(1, _cfg.get("waves", []).size())
			_tool_panel.add_child(_spin_row("放入第几波", clampi(cur_rf_wave, 1, nwaves), 1, nwaves, func(v: int) -> void: cur_rf_wave = v))
			var rfb := HBoxContainer.new(); _tool_panel.add_child(rfb)
			for f in [["梁山", "LIANG"], ["官军", "GUAN"]]:
				var fk: String = f[1]
				rfb.add_child(_btn(f[0], func() -> void: cur_rf_faction = fk; _show_toast("增援阵营：" + String(f[0]))))
			var rul := Label.new(); rul.text = "援军单位（点选）"; rul.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(rul)
			var rus := ScrollContainer.new(); rus.custom_minimum_size = Vector2(0, 220); _tool_panel.add_child(rus)
			var rub := VBoxContainer.new(); rub.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rus.add_child(rub)
			for k in _place_keys:
				var nm := _uname(k)
				var kk: String = k
				var kb := _btn(nm, func() -> void: cur_unit = kk; _show_toast("援军：" + nm))
				kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rub.add_child(kb)
			var rtip := Label.new(); rtip.text = "点地图把该单位放进第 N 波的增援；该波触发时刷出"
			rtip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rtip.add_theme_font_size_override("font_size", 11)
			_tool_panel.add_child(rtip)
		"gate":
			var gl := Label.new(); gl.text = "出兵口编号"; gl.add_theme_color_override("font_color", Color("ffd866")); _tool_panel.add_child(gl)
			for g in GATE_NAMES:
				var gk: String = g
				var gb := _btn("口 " + g, func() -> void: cur_gate = gk; _show_toast("放置出兵口：" + gk))
				gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_tool_panel.add_child(gb)
		"camera":
			var cl := Label.new(); cl.text = "点地图设置开局镜头中心"; cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _tool_panel.add_child(cl)
		"erase":
			var el := Label.new(); el.text = "点单位/出兵口将其删除"; el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _tool_panel.add_child(el)


## ---------- 右栏：地图 / 全局 / 波次 / 胜负 ----------

func _build_props(right: VBoxContainer) -> void:
	right.add_child(_head("地图"))
	var m: Dictionary = _cfg["map"]
	right.add_child(_spin_row("宽", int(m.get("w", 48)), 24, 96, func(v: int) -> void:
		_cfg["map"]["w"] = v; _rebuild_map_model()))
	right.add_child(_spin_row("高", int(m.get("h", 48)), 24, 96, func(v: int) -> void:
		_cfg["map"]["h"] = v; _rebuild_map_model()))
	right.add_child(_opt_row("主题", THEMES, String(m.get("theme", "marsh")), func(s: String) -> void: _cfg["map"]["theme"] = s))
	right.add_child(_opt_row("底色地形", TERRAINS, String(m.get("base", "GRASS")), func(s: String) -> void:
		_cfg["map"]["base"] = s; _rebuild_map_model()))

	right.add_child(_head("全局"))
	var eco := CheckBox.new(); eco.text = "开启经营（采集/建造/训练）"; eco.button_pressed = bool(_cfg.get("economy", false))
	eco.toggled.connect(func(v: bool) -> void: _cfg["economy"] = v)
	right.add_child(eco)
	right.add_child(_spin_row("起始金", int(_cfg.get("start_gold", 0)), 0, 9999, func(v: int) -> void: _cfg["start_gold"] = v))
	right.add_child(_spin_row("起始木", int(_cfg.get("start_wood", 0)), 0, 9999, func(v: int) -> void: _cfg["start_wood"] = v))
	right.add_child(_spin_row("人口上限", int(_cfg.get("pop_cap", 0)), 0, 200, func(v: int) -> void: _cfg["pop_cap"] = v))
	right.add_child(_spin_row("英雄上限", int(_cfg.get("hero_cap", 0)), 0, 12, func(v: int) -> void: _cfg["hero_cap"] = v))
	right.add_child(_spin_row("起始时代(1-3)", int(_cfg.get("start_age", 3)), 1, 3, func(v: int) -> void: _cfg["start_age"] = v))

	right.add_child(_head("胜负预设"))
	var presets := ["据守：守基地+撑过所有波", "歼灭：消灭全部敌人", "限时坚守60秒", "自定义(不改)"]
	right.add_child(_opt_row("规则", presets, presets[0], func(s: String) -> void: _apply_win_preset(s)))

	right.add_child(_head("开场剧情"))
	right.add_child(_btn("＋ 加一句", func() -> void:
		_cfg["intro"].append({"who": "旁白", "key": "narrator", "text": ""}); _rebuild_intro()))
	_intro_box = VBoxContainer.new()
	_intro_box.add_theme_constant_override("separation", 4)
	right.add_child(_intro_box)
	_rebuild_intro()

	right.add_child(_head("敌方波次"))
	right.add_child(_opt_row("出兵方式", ["clear", "timed"], String(_cfg.get("wave_mode", "clear")), func(s: String) -> void: _cfg["wave_mode"] = s))
	right.add_child(_spin_row("波间隔(默认秒)", int(_cfg.get("wave_gap", 9)), 0, 120, func(v: int) -> void: _cfg["wave_gap"] = float(v)))
	right.add_child(_btn("＋ 添加一波", func() -> void:
		_cfg["waves"].append({"delay": float(_cfg.get("wave_gap", 9.0)), "msg": "", "groups": []}); _rebuild_waves()))
	_waves_box = VBoxContainer.new()
	_waves_box.add_theme_constant_override("separation", 4)
	right.add_child(_waves_box)
	_rebuild_waves()


func _rebuild_intro() -> void:
	if _intro_box == null:
		return
	for c in _intro_box.get_children():
		c.queue_free()
	var lines: Array = _cfg.get("intro", [])
	for li in range(lines.size()):
		var line: Dictionary = lines[li]
		var lid := li
		var panel := PanelContainer.new()
		var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 2); panel.add_child(pv)
		var top := HBoxContainer.new(); pv.add_child(top)
		var who := LineEdit.new(); who.text = String(line.get("who", "")); who.placeholder_text = "说话人"
		who.custom_minimum_size = Vector2(70, 0)
		who.text_changed.connect(func(t: String) -> void: (_cfg["intro"][lid] as Dictionary)["who"] = t)
		top.add_child(who)
		var key := LineEdit.new(); key.text = String(line.get("key", "narrator")); key.placeholder_text = "头像键"
		key.custom_minimum_size = Vector2(90, 0); key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.text_changed.connect(func(t: String) -> void: (_cfg["intro"][lid] as Dictionary)["key"] = t)
		top.add_child(key)
		top.add_child(_btn("删", func() -> void: (_cfg["intro"] as Array).remove_at(lid); _rebuild_intro()))
		var txt := LineEdit.new(); txt.text = String(line.get("text", "")); txt.placeholder_text = "台词"
		txt.text_changed.connect(func(t: String) -> void: (_cfg["intro"][lid] as Dictionary)["text"] = t)
		pv.add_child(txt)
		_intro_box.add_child(panel)


func _rebuild_waves() -> void:
	if _waves_box == null:
		return
	for c in _waves_box.get_children():
		c.queue_free()
	var waves: Array = _cfg.get("waves", [])
	for wi in range(waves.size()):
		var wave: Dictionary = waves[wi]
		var panel := PanelContainer.new()
		var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 2); panel.add_child(pv)
		var hdr := HBoxContainer.new(); pv.add_child(hdr)
		var hl := Label.new(); hl.text = "第 %d 波" % (wi + 1); hl.add_theme_color_override("font_color", Color("ffd866")); hdr.add_child(hl)
		var wid := wi
		hdr.add_child(_mini_spin("延时", float(wave.get("delay", 9.0)), 0, 120, func(v: int) -> void: (_cfg["waves"][wid] as Dictionary)["delay"] = float(v)))
		var delb := _btn("删波", func() -> void: (_cfg["waves"] as Array).remove_at(wid); _rebuild_waves())
		hdr.add_child(delb)
		for gi in range(wave.get("groups", []).size()):
			var grp: Dictionary = wave["groups"][gi]
			var gr := HBoxContainer.new(); pv.add_child(gr)
			var gid := gi
			gr.add_child(_key_opt(_combat_keys, String(grp.get("key", _combat_keys[0] if not _combat_keys.is_empty() else "")), func(k: String) -> void:
				((_cfg["waves"][wid] as Dictionary)["groups"][gid] as Dictionary)["key"] = k))
			# ✎ 点击时「实时」读当前下拉选中的兵种(而非建表时的旧值)，换了兵种再点也对
			var eb := _btn("✎", func() -> void: _edit_unit(String(((_cfg["waves"][wid] as Dictionary)["groups"][gid] as Dictionary).get("key", ""))))
			eb.tooltip_text = "编辑当前选中兵种的属性/技能（仅本关）"; gr.add_child(eb)
			gr.add_child(_mini_spin("×", int(grp.get("n", 4)), 1, 40, func(v: int) -> void:
				((_cfg["waves"][wid] as Dictionary)["groups"][gid] as Dictionary)["n"] = v))
			gr.add_child(_gate_opt(String(grp.get("gate", "E")), func(g: String) -> void:
				((_cfg["waves"][wid] as Dictionary)["groups"][gid] as Dictionary)["gate"] = g))
			var boss := CheckBox.new(); boss.text = "首领"; boss.button_pressed = String(grp.get("ref", "")) == "boss"
			boss.tooltip_text = "标记为首领/Boss：在「斩首」胜利模式下，此单位阵亡即获胜"
			boss.toggled.connect(func(v: bool) -> void:
				if v: ((_cfg["waves"][wid] as Dictionary)["groups"][gid] as Dictionary)["ref"] = "boss"
				else: ((_cfg["waves"][wid] as Dictionary)["groups"][gid] as Dictionary).erase("ref"))
			gr.add_child(boss)
			gr.add_child(_btn("x", func() -> void: ((_cfg["waves"][wid] as Dictionary)["groups"] as Array).remove_at(gid); _rebuild_waves()))
		pv.add_child(_btn("＋组", func() -> void:
			(_cfg["waves"][wid] as Dictionary)["groups"].append({"key": _combat_keys[0] if not _combat_keys.is_empty() else "guan_dao", "n": 4, "gate": "E"}); _rebuild_waves()))
		# 增援（用「放增援」工具往这一波放单位后在此显示/编辑提示语、清空）
		if wave.has("reinforce"):
			var rf: Dictionary = wave["reinforce"]
			var rfn: int = rf.get("units", []).size()
			var rrow := HBoxContainer.new(); pv.add_child(rrow)
			var rlbl := Label.new(); rlbl.text = "增援 %d 人" % rfn; rlbl.add_theme_color_override("font_color", Color("9fe06f")); rrow.add_child(rlbl)
			rrow.add_child(_btn("清空", func() -> void: (_cfg["waves"][wid] as Dictionary).erase("reinforce"); _rebuild_waves()))
			var rmsg := LineEdit.new(); rmsg.text = String(rf.get("msg", "")); rmsg.placeholder_text = "增援提示语（如：伏兵杀到！）"
			rmsg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rmsg.text_changed.connect(func(t: String) -> void: ((_cfg["waves"][wid] as Dictionary)["reinforce"] as Dictionary)["msg"] = t)
			pv.add_child(rmsg)
		_waves_box.add_child(panel)


func _apply_win_preset(s: String) -> void:
	if s.begins_with("据守"):
		_cfg["win"] = [{"type": "survive_waves", "msg": "守住了——敌军攻势尽数瓦解！"}]
		_cfg["lose"] = [{"type": "ref_dead", "ref": "hall", "msg": "基地陷落……"}, {"type": "no_army", "msg": "全军覆没……"}]
		_show_toast("据守规则：记得放一座基地建筑（会自动标为 hall）")
	elif s.begins_with("歼灭"):
		_cfg["win"] = [{"type": "kill_all", "msg": "全歼敌军！"}]
		_cfg["lose"] = [{"type": "no_army", "msg": "全军覆没……"}]
	elif s.begins_with("限时"):
		_cfg["win"] = [{"type": "timer", "t": 60.0, "msg": "坚守成功！"}]
		_cfg["lose"] = [{"type": "no_army", "msg": "全军覆没……"}]
	# 自定义：不动


## ---------- 放置/绘制回调（MapCanvas 调用）----------

func paint_cell(cell: Vector2i) -> void:
	if tool != "terrain":
		return
	var r := brush - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var n := cell + Vector2i(dx, dy)
			if n.x >= 0 and n.y >= 0 and n.x < _map.w and n.y < _map.h:
				_map.set_cell_t(n.x, n.y, _t(cur_terrain))


func click_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= _map.w or cell.y >= _map.h:
		return
	match tool:
		"terrain":
			paint_cell(cell)
		"unit":
			var entry := {"key": cur_unit, "faction": cur_faction, "cell": [cell.x, cell.y]}
			# 第一座基地建筑自动标 ref hall（据守胜负条件用）
			var d: Dictionary = Defs.UNITS.get(cur_unit, {})
			if bool(d.get("building", false)) and (d.has("produces") or d.get("key", "") == "hall" or cur_unit == "hall") and not _has_ref("hall"):
				entry["ref"] = "hall"
			_cfg["deploy"].append(entry)
		"decor":
			_cfg["decor"].append([cur_decor, [cell.x, cell.y], cur_decor_size])
		"reinforce":
			var waves: Array = _cfg.get("waves", [])
			if waves.is_empty():
				_show_toast("先在右栏「敌方波次」加一波，再放增援")
				return
			var wi := clampi(cur_rf_wave - 1, 0, waves.size() - 1)
			var wave: Dictionary = waves[wi]
			if not wave.has("reinforce"):
				wave["reinforce"] = {"msg": "", "units": []}
			(wave["reinforce"]["units"] as Array).append({"key": cur_unit, "faction": cur_rf_faction, "cell": [cell.x, cell.y]})
			_rebuild_waves()
		"gate":
			_cfg["gates"][cur_gate] = [cell.x, cell.y]
		"camera":
			_cfg["camera_start"] = [cell.x, cell.y]
		"erase":
			_erase_at(cell)


func _erase_at(cell: Vector2i) -> void:
	var dep: Array = _cfg.get("deploy", [])
	for i in range(dep.size() - 1, -1, -1):
		var c = dep[i].get("cell", [0, 0])
		if int(c[0]) == cell.x and int(c[1]) == cell.y:
			dep.remove_at(i)
			return
	# 增援单位
	for wave in _cfg.get("waves", []):
		if wave.has("reinforce"):
			var ru: Array = wave["reinforce"].get("units", [])
			for i in range(ru.size() - 1, -1, -1):
				var rc = ru[i].get("cell", [0, 0])
				if int(rc[0]) == cell.x and int(rc[1]) == cell.y:
					ru.remove_at(i)
					_rebuild_waves()
					return
	# 装饰物
	var dec: Array = _cfg.get("decor", [])
	for i in range(dec.size() - 1, -1, -1):
		var dc = dec[i][1]
		if int(dc[0]) == cell.x and int(dc[1]) == cell.y:
			dec.remove_at(i)
			return
	var gates: Dictionary = _cfg.get("gates", {})
	for g in gates.keys():
		var gc = gates[g]
		if int(gc[0]) == cell.x and int(gc[1]) == cell.y:
			gates.erase(g)
			return


func _has_ref(r: String) -> bool:
	for e in _cfg.get("deploy", []):
		if String(e.get("ref", "")) == r:
			return true
	return false


func _playtest() -> void:
	_flush_terrain()
	_cfg["title"] = _name_edit.text
	Campaign.scenario_data = _cfg.duplicate(true)
	Campaign.scenario = true
	Campaign.custom_defense = false
	Campaign.skirmish = false
	Campaign.skirmish_ai = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_load() -> void:
	var saved: Array = ScenarioStore.list_saved()
	var pw := _popup_window("读取关卡", 420, 480)
	var root: Control = pw["root"]
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(pw["body"] as Control).add_child(sc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(box)
	if saved.is_empty():
		var e := Label.new(); e.text = "还没有保存的关卡"; e.add_theme_color_override("font_color", Color("c8b89a")); box.add_child(e)
	for name in saved:
		var nm: String = name
		var b := _btn("▶ " + nm, _load_named.bind(nm, root))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 38); box.add_child(b)


func _load_named(nm: String, root: Control) -> void:
	var d := ScenarioStore.load_by_name(nm)
	if not d.is_empty():
		_cfg = d; _rebuild_map_model(); root.queue_free(); _build()


## ---------- 单位 / 技能编辑（双击「用到的」单位上下文编辑，仅本场景生效）----------

## 双击地图上某格 → 找到该格的布兵/增援单位 → 编辑它。
func _edit_unit_at(cell: Vector2i) -> void:
	for e in _cfg.get("deploy", []):
		var c = e.get("cell", [0, 0])
		if int(c[0]) == cell.x and int(c[1]) == cell.y:
			_edit_unit(String(e.get("key", "")))
			return
	for wave in _cfg.get("waves", []):
		if wave.has("reinforce"):
			for e in wave["reinforce"].get("units", []):
				var rc = e.get("cell", [0, 0])
				if int(rc[0]) == cell.x and int(rc[1]) == cell.y:
					_edit_unit(String(e.get("key", "")))
					return
	_show_toast("这一格没有单位——切到「放单位」先摆一个，或双击已放的单位")


## 列出本关「改过 / 自定义」的单位 + 技能（改单位属性进 units、改技能进 abilities，两者都列）。
func _show_modified_units() -> void:
	var units: Dictionary = _cfg.get("units", {})
	var abils: Dictionary = _cfg.get("abilities", {})
	var pw := _popup_window("本关已改 / 自定义（单位 %d · 技能 %d）" % [units.size(), abils.size()], 460, 520)
	var root: Control = pw["root"]
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(pw["body"] as Control).add_child(sc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 5)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(box)
	if units.is_empty() and abils.is_empty():
		var e := Label.new()
		e.text = "还没改过任何东西。\n切到「选择/改单位」双击地图上的单位，\n或在右栏波次里点兵种旁的「✎」。"
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; e.add_theme_color_override("font_color", Color("c8b89a"))
		box.add_child(e)
		return
	if not units.is_empty():
		box.add_child(_head("改过的单位"))
		var uk: Array = units.keys(); uk.sort()
		for k in uk:
			var kk := String(k)
			var b := _btn("✎ " + _uname(kk) + "  (" + kk + ")", _open_modified.bind(kk, root))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 34); box.add_child(b)
	if not abils.is_empty():
		box.add_child(_head("改过的技能（点→打开其所属单位）"))
		var ak: Array = abils.keys(); ak.sort()
		for a in ak:
			var aa := String(a)
			var owner := _ability_owner(aa)
			var lbl := "✦ " + _aname(aa) + "  (" + aa + ")" + ("  ←" + _uname(owner) if owner != "" else "")
			var ab := _btn(lbl, _open_modified.bind(owner if owner != "" else aa, root, owner == ""))
			ab.alignment = HORIZONTAL_ALIGNMENT_LEFT; ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ab.custom_minimum_size = Vector2(0, 34); box.add_child(ab)


## 找到拥有该技能的单位 key（用于从「改过的技能」跳回所属单位编辑）。
func _ability_owner(aid: String) -> String:
	var src := {}
	for k in Defs.UNITS: src[k] = Defs.UNITS[k]
	for k in _cfg.get("units", {}): src[k] = _cfg["units"][k]
	for k in src:
		var d: Dictionary = src[k]
		if String(d.get("ability", "")) == aid or (d.get("abilities", []) as Array).has(aid):
			return String(k)
	return ""


func _open_modified(target: String, root: Control, is_ability := false) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	if is_ability:
		_ae_open(target)   # 找不到所属单位的孤立技能：直接开技能窗
	else:
		_edit_unit(target)


## 打开某单位的属性/技能编辑浮窗（只有改了才会写进本场景，其余单位保持默认）。
func _edit_unit(key: String) -> void:
	if key == "":
		return
	_eu_key = key
	var pw := _popup_window("编辑单位：%s (%s)" % [_uname(key), key], 560, 640)
	_eu_root = pw["root"]
	var top := HBoxContainer.new(); (pw["body"] as Control).add_child(top)
	var hint := Label.new(); hint.text = "改动仅对本关生效"; hint.add_theme_color_override("font_color", Color("9fe06f"))
	hint.add_theme_font_size_override("font_size", 12); hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(hint)
	top.add_child(_btn("复制为新单位", _eu_clone))
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(pw["body"] as Control).add_child(sc)
	_eu_form = VBoxContainer.new(); _eu_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(_eu_form)
	_eu_rebuild_form()


## 重建编辑浮窗的属性表 + 技能入口（技能编辑窗关闭后刷新用）。
func _eu_rebuild_form() -> void:
	if _eu_form == null or not is_instance_valid(_eu_form):
		return
	for c in _eu_form.get_children():
		c.queue_free()
	var key := _eu_key
	if key == "":
		return
	for spec in UNIT_SCHEMA:
		_eu_form.add_child(_prop_row(_udef(key), func(fk, v) -> void: _unit_set(key, fk, v), spec))
	_eu_form.add_child(_head("技能（点「编辑」改全部参数）"))
	var d := _udef(key)
	var ab: Array = d.get("abilities", [])
	if ab.is_empty() and String(d.get("ability", "")) != "":
		ab = [d["ability"]]
	if ab.is_empty():
		var none := Label.new(); none.text = "（该单位无技能）"; none.add_theme_color_override("font_color", Color("9aa3ad")); _eu_form.add_child(none)
	for aid in ab:
		var aid2 := String(aid)
		var hr := HBoxContainer.new()
		var al := Label.new(); al.text = "  " + _aname(aid2) + "  (" + aid2 + ")"; al.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hr.add_child(al)
		hr.add_child(_btn("编辑", func() -> void: _ae_open(aid2)))
		_eu_form.add_child(hr)


## 写入单位字段（写时才固化为本场景 override；不重建表，免丢输入焦点）。
func _unit_set(key: String, fk: String, v) -> void:
	_spec_set(_edit_unit_dict(key), fk, v)


## 把当前单位复制成一个新单位（借用其美术），并切到新单位继续编辑；新单位可在「放单位」里选用。
func _eu_clone() -> void:
	var src := _eu_key
	var base: Dictionary = _udef(src).duplicate(true)
	if base.is_empty():
		base = {"name": "新单位", "hp": 100, "atk": 10, "cd": 1.0, "range": 26, "speed": 72, "radius": 11}
	var i := 1
	while _cfg.get("units", {}).has("custom_%d" % i) or Defs.UNITS.has("custom_%d" % i):
		i += 1
	var nk := "custom_%d" % i
	base["name"] = String(base.get("name", "新单位")) + "·改"
	if not _cfg.has("units"):
		_cfg["units"] = {}
	_cfg["units"][nk] = base
	if src != "":
		if not _cfg.has("sprite_alias"):
			_cfg["sprite_alias"] = {}
		_cfg["sprite_alias"][nk] = src
	_refresh_unit_keys()
	if _eu_root != null and is_instance_valid(_eu_root):
		_eu_root.queue_free()
	_build()                # 刷新「放单位」下拉，带上新单位
	_edit_unit(nk)
	_show_toast("已复制为 %s（借用 %s 美术），可在「放单位」里摆放" % [nk, _uname(src)])


func _ae_open(aid: String) -> void:
	# 叠在单位编辑窗之上的小弹窗（背景半透明，仍能看见底下的单位属性）
	var pw := _popup_window("技能编辑：%s (%s)" % [_aname(aid), aid], 560, 560, _eu_root)
	pw["xbtn"].pressed.connect(_eu_rebuild_form)   # 关闭后刷新单位窗里的技能入口
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(pw["body"] as Control).add_child(sc)
	var form := VBoxContainer.new(); form.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(form)
	for spec in ABILITY_SCHEMA:
		form.add_child(_prop_row(_adef(aid), func(fk, val) -> void: _spec_set(_edit_ability_dict(aid), fk, val), spec))


## 有效技能定义（本场景覆盖 > 全局）
func _adef(aid: String) -> Dictionary:
	return _cfg.get("abilities", {}).get(aid, Defs.ABILITIES.get(aid, {}))

func _aname(aid: String) -> String:
	return String(_adef(aid).get("name", aid))

func _edit_unit_dict(key: String) -> Dictionary:
	if not _cfg.has("units"):
		_cfg["units"] = {}
	if not _cfg["units"].has(key):
		var base: Dictionary = Defs.UNITS.get(key, {})
		_cfg["units"][key] = base.duplicate(true) if not base.is_empty() else {"name": key, "hp": 100, "atk": 10, "cd": 1.0, "range": 26, "speed": 72, "radius": 11}
	return _cfg["units"][key]

func _edit_ability_dict(aid: String) -> Dictionary:
	if not _cfg.has("abilities"):
		_cfg["abilities"] = {}
	if not _cfg["abilities"].has(aid):
		var base: Dictionary = Defs.ABILITIES.get(aid, {})
		_cfg["abilities"][aid] = base.duplicate(true) if not base.is_empty() else {"name": aid, "cd": 8.0, "radius": 100.0, "targeted": false, "effect": {"kind": "smite", "dmg": 20.0}}
	return _cfg["abilities"][aid]


## 通用属性行：read_d 仅供显示当前值；on_set(字段, 值) 负责写入(写时才固化 override)。
func _prop_row(read_d: Dictionary, on_set: Callable, spec: Array) -> HBoxContainer:
	var key: String = spec[0]
	var label: String = spec[1]
	var typ: String = spec[2]
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(124, 0); l.add_theme_font_size_override("font_size", 13)
	h.add_child(l)
	var cur = _spec_get(read_d, key)
	if typ == "bool":
		var cb := CheckBox.new(); cb.button_pressed = (cur == true)   # cur 可能为 null：勿用 bool(null)(会报错)
		cb.toggled.connect(func(v: bool) -> void: on_set.call(key, v))
		h.add_child(cb)
	elif typ == "int" or typ == "float":
		var s := SpinBox.new(); s.min_value = 0; s.max_value = 99999; s.step = (1.0 if typ == "int" else 0.05)
		s.allow_greater = true; s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.update_on_text_changed = true   # 边打字边生效，不必失焦才提交（确保改动写入 override）
		s.value = float(cur) if (cur is float or cur is int) else 0.0
		s.value_changed.connect(func(v: float) -> void: on_set.call(key, (int(v) if typ == "int" else v)))
		h.add_child(s)
	elif typ == "str":
		var le := LineEdit.new(); le.text = String(cur) if cur != null else ""; le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(t: String) -> void: on_set.call(key, t))
		h.add_child(le)
	elif typ == "list":
		var le2 := LineEdit.new(); le2.text = (",".join(cur) if cur is Array else ""); le2.placeholder_text = "技能id,逗号分隔"
		le2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le2.text_changed.connect(func(t: String) -> void: on_set.call(key, _split_csv(t)))
		h.add_child(le2)
	elif typ.begins_with("enum:"):
		var opts := typ.substr(5).split("|")
		var curs := String(cur) if cur != null else ""   # cur 可能为 null：勿用 String(null)
		var o := OptionButton.new(); o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(opts.size()):
			o.add_item(opts[i] if opts[i] != "" else "(无)", i)
			if curs == opts[i]:
				o.select(i)
		o.item_selected.connect(func(idx: int) -> void: on_set.call(key, String(opts[idx])))
		h.add_child(o)
	return h


func _spec_get(d: Dictionary, key: String):
	if key.begins_with("effect."):
		return d.get("effect", {}).get(key.substr(7), null)
	return d.get(key, null)

func _spec_set(d: Dictionary, key: String, val) -> void:
	if key.begins_with("effect."):
		if not d.has("effect"):
			d["effect"] = {}
		d["effect"][key.substr(7)] = val
	else:
		d[key] = val

func _split_csv(t: String) -> Array:
	var out: Array = []
	for p in t.split(","):
		var q := p.strip_edges()
		if q != "":
			out.append(q)
	return out


## ---------- 小部件工具 ----------

## 浮动弹窗（替代全屏覆盖）：半透明背景(仍能看见编辑器) + 居中可拖动面板 + 标题栏✕。
## 返回 {root, body, xbtn}。✕ 默认销毁整窗；调用方可再 connect xbtn 做收尾(刷新等)。
func _popup_window(title_text: String, w: float, h: float, host: Node = null) -> Dictionary:
	var parent: Node = host if host != null else self
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # 模态：吞掉点击，但背景半透明仍可见编辑器
	parent.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.42)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var vp := get_viewport_rect().size
	w = minf(w, vp.x - 24.0); h = minf(h, vp.y - 24.0)
	var win := Panel.new()
	win.size = Vector2(w, h)
	win.position = ((vp - Vector2(w, h)) * 0.5).floor()
	root.add_child(win)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12; vb.offset_top = 8; vb.offset_right = -12; vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 8)
	win.add_child(vb)
	# 标题栏（按住可拖动整窗）
	var bar := DragBar.new()
	bar.target = win
	bar.bounds = vp
	bar.custom_minimum_size = Vector2(0, 30)
	vb.add_child(bar)
	var bh := HBoxContainer.new()
	bh.set_anchors_preset(Control.PRESET_FULL_RECT)
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bh)
	var tl := Label.new(); tl.text = "▦  " + title_text
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_theme_font_size_override("font_size", 17); tl.add_theme_color_override("font_color", Color("ffe9a8"))
	bh.add_child(tl)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; bh.add_child(sp)
	var xb := _btn("✕", func() -> void: root.queue_free())
	xb.add_theme_font_size_override("font_size", 18); xb.custom_minimum_size = Vector2(34, 26)
	bh.add_child(xb)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	return {"root": root, "win": win, "body": body, "xbtn": xb}


func _head(t: String) -> Label:
	var l := Label.new(); l.text = "— " + t + " —"
	l.add_theme_font_size_override("font_size", 15); l.add_theme_color_override("font_color", Color("ffd866"))
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14); b.pressed.connect(cb)
	return b


func _spin_row(label: String, val: int, lo: int, hi: int, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(110, 0); h.add_child(l)
	var s := SpinBox.new(); s.min_value = lo; s.max_value = hi; s.value = val; s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void: cb.call(int(v)))
	h.add_child(s)
	return h


func _mini_spin(label: String, val: float, lo: int, hi: int, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	if label != "":
		var l := Label.new(); l.text = label; h.add_child(l)
	var s := SpinBox.new(); s.min_value = lo; s.max_value = hi; s.value = val; s.custom_minimum_size = Vector2(56, 0)
	s.value_changed.connect(func(v: float) -> void: cb.call(int(v)))
	h.add_child(s)
	return h


func _opt_row(label: String, items: Array, cur: String, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(110, 0); h.add_child(l)
	var o := OptionButton.new(); o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(items.size()):
		o.add_item(String(items[i]), i)
		if String(items[i]) == cur:
			o.select(i)
	o.item_selected.connect(func(idx: int) -> void: cb.call(String(items[idx])))
	h.add_child(o)
	return h


func _key_opt(keys: Array, cur: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new(); o.custom_minimum_size = Vector2(96, 0)
	for i in range(keys.size()):
		o.add_item(_uname(String(keys[i])), i)
		if String(keys[i]) == cur:
			o.select(i)
	o.item_selected.connect(func(idx: int) -> void: cb.call(String(keys[idx])))
	return o


func _gate_opt(cur: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new(); o.custom_minimum_size = Vector2(60, 0)
	for i in range(GATE_NAMES.size()):
		o.add_item("口" + GATE_NAMES[i], i)
		if GATE_NAMES[i] == cur:
			o.select(i)
	o.item_selected.connect(func(idx: int) -> void: cb.call(GATE_NAMES[idx]))
	return o


func _terrain_label(tn: String) -> String:
	var zh := {"GRASS": "草地", "WATER": "水", "SHORE": "浅滩", "MARSH": "沼泽", "REEDS": "芦苇",
		"ROAD": "道路", "FOREST": "树林", "DRYHILL": "旱丘", "CLIFF": "崖", "TOWN": "城镇",
		"PLAZA": "广场", "FIELD": "田", "PLAIN": "平原", "DOCK": "栈桥", "HALL": "地基"}
	return String(zh.get(tn, tn))


func _show_toast(t: String) -> void:
	if _toast == null:
		return
	_toast.text = t; _toast.visible = true; _toast_t = 2.2


# ======================================================================
# 弹窗标题栏：按住拖动整个浮动窗
# ======================================================================
class DragBar extends Panel:
	var target: Control          # 被拖动的窗口面板
	var bounds := Vector2.ZERO    # 视口尺寸：把窗口夹在屏内
	var _drag := false
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
		elif e is InputEventMouseMotion and _drag and target != null:
			var mm: InputEventMouseMotion = e
			var p: Vector2 = target.position + mm.relative
			if bounds != Vector2.ZERO:
				p.x = clampf(p.x, -target.size.x + 80.0, bounds.x - 80.0)
				p.y = clampf(p.y, 0.0, bounds.y - 40.0)
			target.position = p


# ======================================================================
# 俯视网格画布
# ======================================================================
class MapCanvas extends Control:
	var ed = null
	var cz := 14.0                 # 每格像素
	var pan := Vector2(20, 20)
	var hover := Vector2i(-1, -1)
	var _painting := false
	var _panning := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _process(_d: float) -> void:
		queue_redraw()

	func _cell_at(p: Vector2) -> Vector2i:
		return Vector2i(int(floor((p.x - pan.x) / cz)), int(floor((p.y - pan.y) / cz)))

	func _gui_input(e: InputEvent) -> void:
		if ed == null or ed._map == null:
			return
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
				_zoom(1.15, e.position)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
				_zoom(1.0 / 1.15, e.position)
			elif e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
				_panning = e.pressed
			elif e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					if ed.tool == "select":
						if e.double_click:
							ed._edit_unit_at(_cell_at(e.position))   # 双击已放置单位 → 编辑其属性/技能
					else:
						_painting = true
						ed.click_cell(_cell_at(e.position))
				else:
					_painting = false
		elif e is InputEventMouseMotion:
			hover = _cell_at(e.position)
			if _panning:
				pan += e.relative
			elif _painting and ed.tool == "terrain":
				ed.paint_cell(hover)

	func _zoom(f: float, at: Vector2) -> void:
		var before := (at - pan) / cz
		cz = clampf(cz * f, 5.0, 40.0)
		pan = at - before * cz

	func _draw() -> void:
		if ed == null or ed._map == null:
			return
		var m: GameMap = ed._map
		# 地形格
		for y in range(m.h):
			for x in range(m.w):
				var info: Dictionary = GameMap.INFO[m.t_at(x, y)]
				var col := Color(info["color"])
				draw_rect(Rect2(pan + Vector2(x, y) * cz, Vector2(cz, cz)), col)
		# 网格线（疏）
		if cz >= 9.0:
			var gc := Color(0, 0, 0, 0.12)
			for x in range(m.w + 1):
				draw_line(pan + Vector2(x * cz, 0), pan + Vector2(x * cz, m.h * cz), gc, 1.0)
			for y in range(m.h + 1):
				draw_line(pan + Vector2(0, y * cz), pan + Vector2(m.w * cz, y * cz), gc, 1.0)
		var f := ThemeDB.fallback_font
		# 装饰物（棕色◇ + 首字）
		for d in ed._cfg.get("decor", []):
			if not (d is Array and d.size() >= 2):
				continue
			var dp := pan + Vector2(int(d[1][0]) + 0.5, int(d[1][1]) + 0.5) * cz
			var ds := cz * 0.4
			draw_colored_polygon(PackedVector2Array([dp + Vector2(0, -ds), dp + Vector2(ds, 0), dp + Vector2(0, ds), dp + Vector2(-ds, 0)]), Color(0.7, 0.55, 0.3, 0.9))
			if cz >= 11.0:
				var dlab := String(ed.DECOR_LABELS.get(String(d[0]), String(d[0])).substr(0, 1))
				draw_string(f, dp + Vector2(-cz * 0.28, cz * 0.26), dlab, HORIZONTAL_ALIGNMENT_LEFT, -1, int(cz * 0.6), Color(0.1, 0.07, 0.04))
		# 增援单位（菱形描边 + 波号）
		for wi in range(ed._cfg.get("waves", []).size()):
			var wave: Dictionary = ed._cfg["waves"][wi]
			if not wave.has("reinforce"):
				continue
			for e in wave["reinforce"].get("units", []):
				var rc = e.get("cell", [0, 0])
				var rp := pan + Vector2(int(rc[0]) + 0.5, int(rc[1]) + 0.5) * cz
				var rs := cz * 0.44
				var lia := String(e.get("faction", "LIANG")) == "LIANG"
				var rcol := Color(0.4, 0.95, 0.5) if lia else Color(1.0, 0.45, 0.4)
				var diamond := PackedVector2Array([rp + Vector2(0, -rs), rp + Vector2(rs, 0), rp + Vector2(0, rs), rp + Vector2(-rs, 0)])
				draw_polyline(diamond + PackedVector2Array([diamond[0]]), rcol, 2.0)
				if cz >= 11.0:
					draw_string(f, rp + Vector2(-cz * 0.2, cz * 0.26), str(wi + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cz * 0.6), rcol)
		# 出兵口
		for g in ed._cfg.get("gates", {}).keys():
			var gc2 = ed._cfg["gates"][g]
			var gp := pan + Vector2(int(gc2[0]) + 0.5, int(gc2[1]) + 0.5) * cz
			draw_rect(Rect2(gp - Vector2(cz, cz) * 0.5, Vector2(cz, cz)), Color(1, 0.5, 0.1, 0.85))
			draw_string(f, gp + Vector2(-cz * 0.3, cz * 0.3), String(g), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cz * 0.8), Color.WHITE)
		# 布兵
		for e in ed._cfg.get("deploy", []):
			var c = e.get("cell", [0, 0])
			var cp := pan + Vector2(int(c[0]) + 0.5, int(c[1]) + 0.5) * cz
			var lia := String(e.get("faction", "LIANG")) == "LIANG"
			var col := Color(0.35, 0.95, 0.45) if lia else Color(1.0, 0.4, 0.35)
			draw_circle(cp, cz * 0.42, col)
			draw_circle(cp, cz * 0.42, Color(0, 0, 0, 0.6), false, 1.5)
			if String(e.get("ref", "")) == "hall":
				draw_arc(cp, cz * 0.6, 0, TAU, 16, Color(1, 0.9, 0.3), 2.0)
			var nm: String = ed._uname(String(e.get("key", "")))
			if cz >= 11.0:
				draw_string(f, cp + Vector2(-cz * 0.35, cz * 0.28), nm.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(cz * 0.7), Color(0.06, 0.05, 0.04))
		# 镜头起点
		var cs = ed._cfg.get("camera_start", [m.w / 2, m.h / 2])
		var csp := pan + Vector2(int(cs[0]) + 0.5, int(cs[1]) + 0.5) * cz
		draw_line(csp - Vector2(cz, 0), csp + Vector2(cz, 0), Color(0.4, 0.8, 1.0), 2.0)
		draw_line(csp - Vector2(0, cz), csp + Vector2(0, cz), Color(0.4, 0.8, 1.0), 2.0)
		# 悬停高亮
		if hover.x >= 0 and hover.y >= 0 and hover.x < m.w and hover.y < m.h:
			draw_rect(Rect2(pan + Vector2(hover.x, hover.y) * cz, Vector2(cz, cz)), Color(1, 1, 1, 0.5), false, 2.0)
