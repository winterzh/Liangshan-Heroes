class_name HUD
extends CanvasLayer
## 战斗界面：顶部状态、战报消息、剧情对话、开战按钮、胜负结算。

signal start_battle
signal intro_done
signal restart
signal to_menu
signal resume_game
signal quit_game

const SPEAKER_COLORS := {
	"宋江": Color("ffd866"), "吴用": Color("8fd3ff"), "林冲": Color("c0a0ff"),
	"花荣": Color("a0e8c0"), "高俅": Color("ff8866"), "旁白": Color("cccccc"),
	"军令": Color("a9e34b"),
}

var top_label: Label
var msg_box: VBoxContainer
var start_btn: Button
var battle = null

# 顶部资源条（仅自由「遭遇战」模式显示）
var _res_bar: PanelContainer
var _res_gold: Label
var _res_wood: Label
var _res_pop: Label
var _res_idle: Button     # 闲置喽啰徽标：显示闲置数，点击轮流选中（经典RTS式）

# 底部指挥面板
var minimap: Minimap
var _port_tex: TextureRect
var _port_fallback: ColorRect
var _port_char: Label
var _port_frame: Panel       # 多选时点亮的金色边框：标出面板里这位就是「活动单位」
var _delete_btn: Button      # 拆除按钮（选中己方单位/建筑时出现；亦可按 Delete）
var _info_name: Label
var _info_hp: Label
var _info_stats: Label
var _skill_bar: GridContainer      # 命令卡：英雄技能/工人建造/生产训练（生产时多列分两排）
var _queue_bar: VBoxContainer      # 生产队列专栏（仅生产建筑显示，与训练按钮分开，清晰可撤）
var _sel_grid: GridContainer
var _sel_ref: Array = []
var _grid_keys: Array = []
var _skill_keys: Array = []
var _panel_accum := 0.0

# 悬浮技能说明（鼠标移到命令卡/技能图标上即时浮现一张说明卡）
var _tip_panel: PanelContainer
var _tip_title: Label
var _tip_body: Label
var _tip_foot: Label
var _tip_owner = null
var _tip_anchor := Rect2()

var _intro_root: ColorRect
var _intro_name: Label
var _intro_text: Label
var _intro_port_tex: TextureRect
var _intro_port_fallback: ColorRect
var _intro_port_char: Label
var _intro_lines: Array = []
var _intro_i := 0

var _end_root: ColorRect
var _end_title: Label
var _end_sub: Label
var _end_tally: Label     # 各路好汉战功（按英雄歼敌排行）
var _end_next: Button

var _pause_root: ColorRect

# AI友好模式·自动镜头按钮：左下角（全员托管后出现，点一下开/关自动镜头；开启时呼吸闪烁）
var _autocam_btn: Button
var _autocam_on := false
var _autocam_pulse := 0.0

# 触屏布局：屏上操作栏 + 编队 chips（手机/网页或收到首个触摸事件时启用）
var touch_ui := false
var _touch_built := false
var _touch_actions: HBoxContainer
var _act_amove: Button
var _act_stop: Button
var _act_stance: Button
var _act_delete: Button
var _act_cancel: Button
var _act_eject: Button
var _act_auto: Button       # 托管：当前英雄自动放招/加点/进攻（开→显示「取消托管」）
var _act_allauto: Button    # 托管军：全军托管/取消（label 随全员状态变）
var _touch_groups: HBoxContainer
var _group_chips: Array = []
var _hero_bar: GridContainer
var _hero_keys: Array = []
var _skill_rail: VBoxContainer   # 右缘常驻技能轨（每英雄一行，免选直放）
var _skill_rail_keys: Array = []
var _intro_btn: Button
var _menu_btn: Button      # 触屏屏上「菜单」键（右上角）：等同安卓返回键，呼出暂停菜单
var _eject_float: Button   # 桌面：选中有驻军建筑时浮在面板上方的「出击」键（命令卡挤不下时的可靠入口）


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时 UI（暂停菜单）仍可操作

	top_label = Label.new()
	top_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_label.offset_top = 8.0
	top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(top_label, 19)
	add_child(top_label)

	msg_box = VBoxContainer.new()
	msg_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	msg_box.offset_top = 46.0
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg_box)

	start_btn = Button.new()
	start_btn.text = "⚔  开 战"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	start_btn.offset_left = -100.0
	start_btn.offset_right = 100.0
	start_btn.offset_top = -226.0
	start_btn.offset_bottom = -170.0
	start_btn.visible = false
	start_btn.pressed.connect(_on_start_pressed)
	add_child(start_btn)

	# 桌面「出击」浮动键：选中有驻军建筑时浮在底部面板上方，命令卡挤不下也照样能点驻军冲出
	_eject_float = Button.new()
	_eject_float.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_eject_float.offset_left = -90.0
	_eject_float.offset_right = 90.0
	_eject_float.offset_top = -206.0
	_eject_float.offset_bottom = -166.0
	_eject_float.focus_mode = Control.FOCUS_NONE
	_eject_float.add_theme_font_size_override("font_size", 20)
	var ejs := StyleBoxFlat.new()
	ejs.bg_color = Color(0.10, 0.20, 0.30, 0.96)
	ejs.border_color = Color("6fb0e0")
	ejs.set_border_width_all(2)
	ejs.set_corner_radius_all(8)
	_eject_float.add_theme_stylebox_override("normal", ejs)
	_eject_float.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_eject_float.visible = false
	_eject_float.pressed.connect(func() -> void:
		if battle != null and battle.active_unit() != null:
			battle.ungarrison(battle.active_unit()))
	add_child(_eject_float)

	_build_resource_bar()
	_build_hero_bar()
	_build_bottom_panel()
	_build_intro()
	_build_end()
	_build_pause()
	_build_skill_tip()
	_build_autocam_badge()


func setup(p_battle) -> void:
	battle = p_battle
	minimap.battle = p_battle
	_res_bar.visible = battle != null and battle.economy
	if OS.has_feature("mobile") or OS.has_feature("web") or OS.get_environment("TOUCH_UI") == "1":
		set_touch_ui(true)   # 手机/网页（或 TOUCH_UI=1 桌面预览）：启用触屏布局；PC 上否则等首个触摸事件


## 启用/刷新触屏布局（由 battle 收到首个触摸事件、或移动端启动时调用）
func set_touch_ui(v: bool) -> void:
	touch_ui = v
	if v and not _touch_built:
		_build_touch_controls()
		_apply_touch_fonts()
	_refresh_touch_controls()


## 手机上字太小 → 把「进图就看到」的关键文字整体放大：顶部目标条、剧情对话、开战钮、
## 资源条、面板标题、战报、结算。桌面端从不调用 → 零影响。
func _apply_touch_fonts() -> void:
	if top_label != null:
		top_label.add_theme_font_size_override("font_size", 26)
	if _intro_name != null:
		_intro_name.add_theme_font_size_override("font_size", 30)
	if _intro_text != null:
		_intro_text.add_theme_font_size_override("font_size", 24)
		_intro_text.custom_minimum_size = Vector2(620, 96)
	if _intro_btn != null:
		_intro_btn.add_theme_font_size_override("font_size", 24)
	if _intro_port_char != null:
		_intro_port_char.add_theme_font_size_override("font_size", 64)
	if start_btn != null:
		start_btn.add_theme_font_size_override("font_size", 30)
		start_btn.offset_left = -132.0
		start_btn.offset_right = 132.0
		start_btn.offset_top = -242.0
		start_btn.offset_bottom = -168.0
	for l in [_res_gold, _res_wood, _res_pop]:
		if l != null:
			l.add_theme_font_size_override("font_size", 24)
	if _res_idle != null:
		_res_idle.add_theme_font_size_override("font_size", 23)
	if _info_name != null:
		_info_name.add_theme_font_size_override("font_size", 26)
	if _end_sub != null:
		_end_sub.add_theme_font_size_override("font_size", 26)
	if _end_tally != null:
		_end_tally.add_theme_font_size_override("font_size", 22)
	if _end_next != null:
		_end_next.add_theme_font_size_override("font_size", 26)


## 触屏操作栏（右下·拇指区：攻击移动/停/姿态/拆 + 待指向时的取消）+ 编队 chips（左下）
func _build_touch_controls() -> void:
	_touch_built = true
	_touch_actions = HBoxContainer.new()
	_touch_actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_touch_actions.offset_right = -12.0
	_touch_actions.offset_bottom = -166.0
	_touch_actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_touch_actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_touch_actions.add_theme_constant_override("separation", 10)
	_touch_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_actions.visible = false
	add_child(_touch_actions)
	_act_amove = _mk_action_btn("⚔攻击", Color("c84a3a"), func() -> void:
		if battle != null: battle.arm_amove())
	_act_stop = _mk_action_btn("■停", Color("4a5a72"), func() -> void:
		if battle != null: battle._order_stop())
	_act_stance = _mk_action_btn("⛨姿态", Color("4a6a4a"), func() -> void:
		if battle != null: battle._cycle_stance())
	_act_delete = _mk_action_btn("✕拆", Color("7a2a22"), func() -> void:
		if battle != null: battle.delete_selected(true))
	_act_cancel = _mk_action_btn("⨯取消", Color("6a5a2a"), func() -> void:
		if battle != null: battle.cancel_armed())
	_act_cancel.visible = false
	# 出击键：选中有驻军的建筑（聚义厅/箭楼）时出现，让驻军冲出（触屏入口，桌面在命令卡也有）
	_act_eject = _mk_action_btn("🚪出击", Color("4a6a8a"), func() -> void:
		if battle != null and battle.active_unit() != null: battle.ungarrison(battle.active_unit()))
	_act_eject.visible = false
	# 托管：当前英雄自动放招 + 自动加点 + 进攻索敌（移动端省手核心）
	_act_auto = _mk_action_btn("🪄托管", Color("8a5ad0"), func() -> void:
		toggle_auto_selected())
	_act_auto.visible = false

	_touch_groups = HBoxContainer.new()
	_touch_groups.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_touch_groups.offset_left = 12.0
	_touch_groups.offset_bottom = -166.0
	_touch_groups.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_touch_groups.add_theme_constant_override("separation", 10)
	_touch_groups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_groups.visible = false
	add_child(_touch_groups)
	for n in [1, 2, 3, 4]:
		var chip := TouchChip.new()
		chip.hud = self
		chip.num = n
		_touch_groups.add_child(chip)
		_group_chips.append(chip)
	# 「全军」一键：选中所有作战单位（轻操作式少微操）
	var allb := Button.new()
	allb.text = "全军"
	allb.custom_minimum_size = Vector2(72, 68)
	allb.focus_mode = Control.FOCUS_NONE
	allb.add_theme_font_size_override("font_size", 20)
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.14, 0.18, 0.10, 0.95)
	asb.border_color = Color("9fe06f")
	asb.set_border_width_all(2)
	asb.set_corner_radius_all(8)
	allb.add_theme_stylebox_override("normal", asb)
	allb.add_theme_color_override("font_color", Color(0.86, 1.0, 0.8))
	allb.pressed.connect(func() -> void:
		if battle != null: battle.select_all_army())
	_touch_groups.add_child(allb)
	# 托管全军：一键让全部在场英雄进入/退出托管
	_act_allauto = Button.new()
	_act_allauto.text = "🪄托管军"
	_act_allauto.custom_minimum_size = Vector2(72, 68)
	_act_allauto.focus_mode = Control.FOCUS_NONE
	_act_allauto.add_theme_font_size_override("font_size", 18)
	var aasb := StyleBoxFlat.new()
	aasb.bg_color = Color(0.16, 0.12, 0.22, 0.95)
	aasb.border_color = Color("b89af0")
	aasb.set_border_width_all(2)
	aasb.set_corner_radius_all(8)
	_act_allauto.add_theme_stylebox_override("normal", aasb)
	_act_allauto.add_theme_color_override("font_color", Color(0.9, 0.84, 1.0))
	_act_allauto.pressed.connect(_toggle_all_auto)
	_touch_groups.add_child(_act_allauto)

	# 屏上「☰ 菜单」键（右上角）：安卓返回键之外的入口，点开暂停菜单（继续/重开/返回/退出）
	_menu_btn = Button.new()
	_menu_btn.text = "☰ 菜单"
	_menu_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_menu_btn.offset_right = -12.0
	_menu_btn.offset_top = 10.0
	_menu_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_menu_btn.custom_minimum_size = Vector2(104, 52)
	_menu_btn.focus_mode = Control.FOCUS_NONE
	_menu_btn.add_theme_font_size_override("font_size", 22)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.12, 0.10, 0.07, 0.95)
	msb.border_color = Color(0.62, 0.5, 0.3)
	msb.set_border_width_all(2)
	msb.set_corner_radius_all(8)
	_menu_btn.add_theme_stylebox_override("normal", msb)
	var msb2 := msb.duplicate()
	msb2.bg_color = Color(0.22, 0.18, 0.12, 1.0)
	_menu_btn.add_theme_stylebox_override("pressed", msb2)
	_menu_btn.add_theme_color_override("font_color", Color(1, 0.94, 0.8))
	_menu_btn.pressed.connect(func() -> void:
		if battle != null: battle._open_pause())
	add_child(_menu_btn)

	_build_skill_rail()

	# 安全区（刘海/圆角）：把贴边控件按左右内缩量推开；桌面无内缩=无操作。屏幕尺寸变了重算一次。
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _apply_safe_area() -> void:
	if not _touch_built:
		return
	var sa := DisplayServer.get_display_safe_area()
	var ws := DisplayServer.window_get_size()
	var left := maxf(0.0, float(sa.position.x))
	var right := maxf(0.0, float(ws.x - (sa.position.x + sa.size.x)))
	if _touch_groups != null:
		_touch_groups.offset_left = 12.0 + left
	if _touch_actions != null:
		_touch_actions.offset_right = -12.0 - right
	if _menu_btn != null:
		_menu_btn.offset_right = -12.0 - right
	if _skill_rail != null:
		_skill_rail.offset_right = -10.0 - right
	if _res_bar != null:
		_res_bar.offset_left = 10.0 + left
	_layout_hero_bar()


func _mk_action_btn(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96, 72)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.9))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.95)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, 1.0)
	b.add_theme_stylebox_override("pressed", sb2)
	b.add_theme_stylebox_override("hover", sb2)
	b.pressed.connect(cb)
	_touch_actions.add_child(b)
	return b


## 每帧/选区变化时刷新触屏控件显隐与文案
func _refresh_touch_controls() -> void:
	if not touch_ui or _touch_actions == null or battle == null:
		return
	var sel: Array = battle.selection
	var has_mover := false
	for u in sel:
		if is_instance_valid(u) and not u.is_building:
			has_mover = true
			break
	var au = battle.active_unit()
	# 建造选址态：屏上只留「取消」，其余作战键先收起，避免拖虚影时误触、也让取消更醒目
	var placing: bool = battle._build_armed != ""
	# 驻军建筑被选中时也亮出操作栏（让「出击」可点）
	var garrisoned_bld: bool = au != null and au.is_building and not au.passengers.is_empty()
	_touch_actions.visible = has_mover or battle.is_armed() or garrisoned_bld
	_touch_groups.visible = true
	if _act_amove != null:
		_act_amove.visible = not placing
	if _act_stop != null:
		_act_stop.visible = not placing
	_act_stance.visible = has_mover and au != null and not au.is_building and not placing
	if _act_stance.visible:
		match au.stance:
			Unit.STANCE_DEFEND: _act_stance.text = "⛨守备"
			Unit.STANCE_HOLD: _act_stance.text = "⛨据守"
			Unit.STANCE_PASSIVE: _act_stance.text = "⛨避战"
			_: _act_stance.text = "⛨进攻"
	_act_delete.visible = not sel.is_empty() and not placing
	_act_cancel.visible = battle.is_armed()
	if _act_cancel.visible:
		_act_cancel.text = "⨯取消建造" if placing else "⨯取消"
	if _act_eject != null:
		_act_eject.visible = garrisoned_bld and not placing
		if garrisoned_bld:
			_act_eject.text = "🚪出击 (%d)" % au.passengers.size()
	var micro_on: bool = int(Settings.auto_micro_level) > 0   # 「无托管」档隐藏托管按钮
	if _act_auto != null:
		_act_auto.visible = micro_on and au != null and au.is_hero and not au.is_building and not placing
		if _act_auto.visible:
			_act_auto.text = "🚫取消托管" if au.auto_micro else "🪄托管"
			_act_auto.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6) if au.auto_micro else Color(1, 0.96, 0.9))
	if _act_allauto != null:
		_act_allauto.visible = micro_on
		# 托管军：全员都在托管→显示「取消托管军」，否则「托管军」
		var hs: Array = battle.liang_heroes() if battle != null else []
		var all_on: bool = not hs.is_empty()
		for h in hs:
			if not h.auto_micro:
				all_on = false
				break
		_act_allauto.text = "🚫取消托管军" if all_on else "🪄托管军"


## 托管「当前选中的英雄」：选 1 个=单托管；框选/编队多个=整队托管。（PC 热键 T，移动端「托管」按钮）
func toggle_auto_selected() -> void:
	if battle == null:
		return
	var hs: Array = battle.selection.filter(func(u): return is_instance_valid(u) and u.is_hero and not u.is_building)
	if hs.is_empty():
		show_message("先选中英雄再托管（PC: T 托管 / Shift+T 全军）", 1.4)
		return
	# 有任一已托管 → 视为取消（全部关）；否则全部开。这样混合选区也能一键取消。
	var any_on := false
	for h in hs:
		if h.auto_micro:
			any_on = true
			break
	for h in hs:
		h.auto_micro = not any_on
		if h.auto_micro:
			h.set_stance(Unit.STANCE_AGGRO)
	show_message("%s %d 名英雄托管" % ["关闭" if any_on else "开启", hs.size()], 1.2)


## 托管全军：一键切换全部在场英雄的 auto_micro（已全开→全关，否则全开）。
func _toggle_all_auto() -> void:
	if battle == null:
		return
	var hs: Array = battle.liang_heroes()
	if hs.is_empty():
		return
	var all_on := true
	for h in hs:
		if not h.auto_micro:
			all_on = false
			break
	for h in hs:
		h.auto_micro = not all_on
		if h.auto_micro:
			h.set_stance(Unit.STANCE_AGGRO)
	show_message("%s全军托管（%d 名英雄）" % ["开启" if not all_on else "关闭", hs.size()], 1.2)


## 右缘常驻技能轨（仅触屏）：每个在场英雄一行，行内排该英雄的「可主动」技能按钮，
## 免选英雄即可直接点放——HeroSlotButton 持各自 hero 引用，cast_ability(hero,slot) 不读选中态。
func _build_skill_rail() -> void:
	_skill_rail = VBoxContainer.new()
	_skill_rail.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_skill_rail.offset_right = -10.0
	_skill_rail.offset_top = 70.0
	_skill_rail.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skill_rail.add_theme_constant_override("separation", 6)
	_skill_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skill_rail)


## 技能轨刷新：英雄集合或其主动槽数变化时重排（升级解锁新主动也会触发）。
func _refresh_skill_rail() -> void:
	if _skill_rail == null or battle == null:
		return
	var heroes: Array = battle.liang_heroes()
	var sig: Array = []
	for h in heroes:
		var act := 0
		for i in range(h.slot_count()):
			if (not bool(h.ability_slots[i]["passive"])) or h.slot_has_active(i):
				act += 1
		sig.append(h.get_instance_id())
		sig.append(act)
	if sig == _skill_rail_keys:
		return
	_skill_rail_keys = sig
	for c in _skill_rail.get_children():
		c.queue_free()
	for h in heroes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.alignment = BoxContainer.ALIGNMENT_END
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var av := TextureRect.new()
		av.custom_minimum_size = Vector2(56, 56)
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # 否则 TextureRect 会撑到原图尺寸（巨幅头像）
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av.texture = Art.avatar_texture(h.key)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(av)
		var any := false
		for i in range(h.slot_count()):
			if bool(h.ability_slots[i]["passive"]) and not h.slot_has_active(i):
				continue   # 纯被动不上轨
			var b := HeroSlotButton.new()
			b.hud = self
			b.hero = h
			b.slot = i
			b.compact = true
			row.add_child(b)
			any = true
		if any:
			_skill_rail.add_child(row)
		else:
			row.queue_free()


## 英雄快切栏（左缘竖排，轻操作式·桌面+触屏通用）：点头像=选中并居中该英雄；
## 驻军中的英雄标「驻」，点头像=出击。GridContainer 由 _layout_hero_bar 自适应缩放/分列，
## 顶部贴资源条下方、底部止于底部面板之上——不压住左下编队 chips。
func _build_hero_bar() -> void:
	_hero_bar = GridContainer.new()
	_hero_bar.columns = 1
	_hero_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hero_bar.offset_left = 8.0
	_hero_bar.offset_top = 52.0
	_hero_bar.add_theme_constant_override("h_separation", 8)
	_hero_bar.add_theme_constant_override("v_separation", 8)
	_hero_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_bar)


## 英雄快切栏：英雄集合变化时重排头像 chips
func _refresh_hero_bar() -> void:
	if _hero_bar == null or battle == null:
		return
	var heroes: Array = battle.liang_heroes()
	var keys: Array = []
	for h in heroes:
		keys.append(h.get_instance_id())
	if keys == _hero_keys:
		return
	_hero_keys = keys
	for c in _hero_bar.get_children():
		c.queue_free()
	for h in heroes:
		var chip := HeroChip.new()
		chip.hud = self
		chip.hero = h
		_hero_bar.add_child(chip)
	_layout_hero_bar()


## 英雄栏自适应：把整列头像塞进「资源条下方 ~ 左下编队 chips 上方」这条竖带里。
## 英雄越多 / 屏幕越矮 → 头像越小，必要时分 2~3 列；保证永不压住左下「1 2 3 4」。
func _layout_hero_bar() -> void:
	if _hero_bar == null:
		return
	var n := _hero_bar.get_child_count()
	if n == 0:
		return
	var sa := DisplayServer.get_display_safe_area()
	var ws := DisplayServer.window_get_size()
	var left := maxf(0.0, float(sa.position.x))
	var top := maxf(0.0, float(sa.position.y))
	var band_top := 52.0 + top                      # 让位给左上资源条
	var band_bottom := float(ws.y) - 250.0          # 让位给左下编队 chips（offset_bottom -166, 高 ~72）
	var band_h := maxf(120.0, band_bottom - band_top)
	var sep := 8.0
	var cols := 1
	var chip := 72.0
	for c in [1, 2, 3]:
		var rows: int = int(ceil(float(n) / float(c)))
		chip = (band_h - float(rows - 1) * sep) / float(rows)
		cols = c
		if chip >= 46.0:
			break
	chip = clampf(chip, 40.0, 72.0)
	_hero_bar.columns = cols
	_hero_bar.offset_left = 8.0 + left
	_hero_bar.offset_top = band_top
	for ch in _hero_bar.get_children():
		ch.custom_minimum_size = Vector2(chip, chip)


## 顶部资源条：金 | 木 | 人口（经典RTS式，左上角常驻）
func _build_resource_bar() -> void:
	_res_bar = PanelContainer.new()
	_res_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_res_bar.offset_left = 10.0
	_res_bar.offset_top = 8.0
	_res_bar.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.075, 0.05, 0.92)
	sb.border_color = Color(0.52, 0.40, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	_res_bar.add_theme_stylebox_override("panel", sb)
	add_child(_res_bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	_res_bar.add_child(hb)
	_res_gold = _res_label(hb, Color("ffd24a"))
	_res_wood = _res_label(hb, Color("b6883f"))
	_res_pop = _res_label(hb, Color("9fd0e8"))
	# 闲置喽啰徽标（可点）：有闲置工人时高亮，点击轮流跳选（. 键同效）
	_res_idle = Button.new()
	_res_idle.flat = true
	_res_idle.focus_mode = Control.FOCUS_NONE
	_res_idle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_res_idle.add_theme_font_size_override("font_size", 19)
	_res_idle.add_theme_color_override("font_color", Color("6fe06f"))
	_res_idle.add_theme_color_override("font_color_hover", Color("b6ffb6"))
	_res_idle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_res_idle.add_theme_constant_override("outline_size", 4)
	_res_idle.visible = false
	_res_idle.pressed.connect(func() -> void:
		if battle != null:
			battle._cycle_idle_worker())
	hb.add_child(_res_idle)


func _res_label(parent: Control, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


## 悬浮技能说明卡：一张漂浮在按钮上方的小面板，鼠标一移上去就即时显示（不等系统 tooltip 那 0.5 秒）。
func _build_skill_tip() -> void:
	_tip_panel = PanelContainer.new()
	_tip_panel.visible = false
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.z_index = 200
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.97)
	sb.border_color = Color("ffd866")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	_tip_panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.add_child(vb)
	_tip_title = Label.new()
	_tip_title.add_theme_font_size_override("font_size", 17)
	vb.add_child(_tip_title)
	_tip_body = Label.new()
	_tip_body.add_theme_font_size_override("font_size", 14)
	_tip_body.add_theme_color_override("font_color", Color(0.86, 0.88, 0.82))
	_tip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_body.custom_minimum_size = Vector2(236, 0)
	vb.add_child(_tip_body)
	_tip_foot = Label.new()
	_tip_foot.add_theme_font_size_override("font_size", 12)
	_tip_foot.add_theme_color_override("font_color", Color("a9e34b"))
	vb.add_child(_tip_foot)
	add_child(_tip_panel)


## 显示说明卡：owner=触发的按钮（用于 exit 时只关自己那张），anchor=按钮全局矩形（卡浮在其上方）。
func show_skill_tip(owner, anchor: Rect2, title: String, body: String, foot: String, col: Color) -> void:
	if _tip_panel == null:
		return
	_tip_owner = owner
	_tip_anchor = anchor
	_tip_title.text = title
	_tip_title.add_theme_color_override("font_color", col if col.a > 0.0 else Color("ffd866"))
	_tip_body.text = body
	_tip_foot.text = foot
	_tip_foot.visible = foot != ""
	_tip_panel.visible = true
	_tip_panel.reset_size()
	_position_tip()


func hide_skill_tip(owner) -> void:
	if _tip_panel == null:
		return
	if owner == null or _tip_owner == owner:
		_tip_panel.visible = false
		_tip_owner = null


func _position_tip() -> void:
	if _tip_panel == null or not _tip_panel.visible:
		return
	var sz := _tip_panel.size
	var vp := get_viewport().get_visible_rect().size
	var x := clampf(_tip_anchor.position.x + _tip_anchor.size.x * 0.5 - sz.x * 0.5, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	var y := _tip_anchor.position.y - sz.y - 8.0
	if y < 8.0:
		y = _tip_anchor.end.y + 8.0
	_tip_panel.position = Vector2(x, y)


func _process(delta: float) -> void:
	# 自动镜头按钮：已开启时轻微呼吸闪烁，提示镜头正自动接管；未开启则常亮（提示「点我」）
	if _autocam_btn != null and _autocam_btn.visible:
		if _autocam_on:
			_autocam_pulse += delta * 3.2
			_autocam_btn.modulate.a = 0.80 + 0.20 * sin(_autocam_pulse)
		elif _autocam_btn.modulate.a != 1.0:
			_autocam_btn.modulate.a = 1.0
	if _tip_panel != null and _tip_panel.visible:
		_position_tip()   # 面板尺寸在内容变更后一帧才定，逐帧重定位以贴准按钮上方
	if touch_ui:
		_refresh_touch_controls()
		_refresh_skill_rail()
	_refresh_hero_bar()   # 英雄快切栏：桌面与触屏都要刷新（含驻军英雄出击标记）
	if battle != null:
		_rebuild_command_card()   # 逐帧按签名比对：生产/研究队列一变(下单/完成)即刷新命令卡与队列栏，无需重选建筑
	# 桌面「出击」浮动键：选中有驻军的己方建筑时显示（命令卡可能挤不下，这个一定看得见）
	if _eject_float != null:
		var au = battle.active_unit() if battle != null else null
		var show_ej: bool = not touch_ui and au != null and au.is_building and not au.passengers.is_empty()
		_eject_float.visible = show_ej
		if show_ej:
			_eject_float.text = "🚪 出击 (%d)" % au.passengers.size()
	_panel_accum += delta
	if _panel_accum >= 0.25:
		_panel_accum = 0.0
		_layout_hero_bar()   # 兜底重排（窗口缩放时；桌面端 _apply_safe_area 不跑）
		if battle != null and battle.economy and _res_bar.visible:
			_res_gold.text = "金 %d" % battle.gold
			_res_wood.text = "木 %d" % battle.wood
			var up: int = battle.used_pop()
			_res_pop.text = "人口 %d / %d" % [up, battle.pop_cap]
			# 人口已满 → 标红提示（该造民居/聚义厅扩人口了）
			_res_pop.add_theme_color_override("font_color",
				Color("ff7a6a") if up >= battle.pop_cap and battle.pop_cap > 0 else Color("9fd0e8"))
			# 闲置喽啰徽标
			var idle := 0
			for u in battle.units:
				if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.is_idle_worker():
					idle += 1
			_res_idle.visible = idle > 0
			if idle > 0:
				_res_idle.text = "⚒ 闲置 %d" % idle
		if not _sel_ref.is_empty():
			_refresh_panel()


## 经典RTS式底部指挥面板：小地图 | 头像 | 属性 | 编队 | 操作提示
func _build_bottom_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -158.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.075, 0.05, 0.96)
	sb.border_color = Color(0.52, 0.40, 0.22)
	sb.border_width_top = 3
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	minimap = Minimap.new()
	hbox.add_child(minimap)

	var port_holder := Control.new()
	port_holder.custom_minimum_size = Vector2(118, 118)
	hbox.add_child(port_holder)
	_port_fallback = ColorRect.new()
	_port_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_port_fallback.color = Color(0.15, 0.15, 0.15)
	port_holder.add_child(_port_fallback)
	_port_char = Label.new()
	_port_char.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_port_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_port_char.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_port_char.add_theme_font_size_override("font_size", 48)
	_port_char.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_port_fallback.add_child(_port_char)
	_port_tex = TextureRect.new()
	_port_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_port_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_port_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port_holder.add_child(_port_tex)
	# 活动单位金框（多选时点亮）：和世界里那位的金环呼应
	_port_frame = Panel.new()
	_port_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_port_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0)
	fsb.set_border_width_all(3)
	fsb.border_color = Color(1.0, 0.84, 0.26, 0.98)
	fsb.set_corner_radius_all(2)
	_port_frame.add_theme_stylebox_override("panel", fsb)
	_port_frame.visible = false
	port_holder.add_child(_port_frame)
	# 拆除按钮：头像右上角小红「✕」。点击拆除选中的己方单位/建筑（防卡位）；快捷键 Delete。
	_delete_btn = Button.new()
	_delete_btn.text = "✕"
	_delete_btn.tooltip_text = "拆除选中单位/建筑（Delete）"
	_delete_btn.custom_minimum_size = Vector2(24, 24)
	_delete_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_delete_btn.offset_left = -24
	_delete_btn.offset_bottom = 24
	_delete_btn.add_theme_font_size_override("font_size", 14)
	_delete_btn.focus_mode = Control.FOCUS_NONE
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.6, 0.13, 0.11, 0.92)
	dsb.set_corner_radius_all(3)
	_delete_btn.add_theme_stylebox_override("normal", dsb)
	var dsb2 := dsb.duplicate()
	dsb2.bg_color = Color(0.82, 0.2, 0.16, 1.0)
	_delete_btn.add_theme_stylebox_override("hover", dsb2)
	_delete_btn.add_theme_color_override("font_color", Color(1, 0.92, 0.9))
	_delete_btn.visible = false
	_delete_btn.pressed.connect(func() -> void:
		if battle != null:
			battle.delete_selected(true))   # 点按钮是明确意图，直接拆（不走二次确认）
	port_holder.add_child(_delete_btn)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.custom_minimum_size = Vector2(248, 0)
	# 固定信息栏宽度上限：内部长文字（建筑提示/施工进度）自动折行，不再把命令卡与提示推出屏幕右缘
	info.clip_contents = true
	hbox.add_child(info)
	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 22)
	_info_name.add_theme_color_override("font_color", Color("ffd866"))
	_info_name.custom_minimum_size = Vector2(248, 0)
	info.add_child(_info_name)
	_info_hp = Label.new()
	_info_hp.add_theme_font_size_override("font_size", 15)
	_info_hp.custom_minimum_size = Vector2(248, 0)
	info.add_child(_info_hp)
	_info_stats = Label.new()
	_info_stats.add_theme_font_size_override("font_size", 13)
	_info_stats.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_info_stats.custom_minimum_size = Vector2(248, 0)
	_info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_info_stats)

	# 命令卡（英雄技能 / 工人建造 / 生产训练）。GridContainer：生产建筑设多列→训练按钮分两排，
	# 其余设大列数→单排。get_index 顺序不变，键盘 Q/W/E/R 经 train_menu/build_menu 索引派发，不受影响。
	_skill_bar = GridContainer.new()
	_skill_bar.columns = 99
	_skill_bar.add_theme_constant_override("h_separation", 6)
	_skill_bar.add_theme_constant_override("v_separation", 2)
	_skill_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_skill_bar)

	# 生产队列专栏：标题「队列 N」+ 一排小图标（队首=训练中带进度，点击撤单退资源）。仅生产建筑显示。
	_queue_bar = VBoxContainer.new()
	_queue_bar.add_theme_constant_override("separation", 2)
	_queue_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue_bar.visible = false
	hbox.add_child(_queue_bar)

	# 多选单位图标网格（经典RTS式）：每个图标含头像/精灵 + 血条，点击单选
	var grid_wrap := MarginContainer.new()
	# 收缩到图标本身宽度（不再抢占空白）——否则它吃掉所有富余空间，把右侧提示推出屏外
	grid_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(grid_wrap)
	_sel_grid = GridContainer.new()
	_sel_grid.columns = 12
	_sel_grid.add_theme_constant_override("h_separation", 3)
	_sel_grid.add_theme_constant_override("v_separation", 3)
	grid_wrap.add_child(_sel_grid)

	var help := Label.new()
	# 拆成 5 行短句（纵向有余、横向窄）：每行都 < 聚义厅时的最窄富余宽，保证整段完整可见不被裁。
	help.text = "左键 选取·框选·双击选同类\n右键 移动/攻击/采集/修理/续建/进驻\nA攻击移动 S待命 P巡逻 G切姿态 T托管(Shift+T全军)\nDelete拆除 Shift排队 QWER命令 Tab切单位\n.选闲置 Ctrl/Shift+数字编队 空格回基地 Esc菜单"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.55, 0.55, 0.5))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 占据剩余空白、右缘贴屏幕边（grid_wrap 已改 SHRINK，提示不会被推出屏）。
	# 不用 autowrap：容器里 autowrap Label 的最小高度按「最小宽度」算（一个汉字宽→堆成几十行）会撑高整栏。
	# 改为精简文案保证最宽一行 < 最窄富余宽（聚义厅时约 396px）。
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(help)


func update_selection_panel(sel: Array) -> void:
	# 己方选区为空但正在「查看」敌方单位 → 面板显示该敌信息（命令卡因 active_unit 为空而自动留空=不可操作）
	if sel.is_empty() and battle != null and battle._inspect_unit != null and is_instance_valid(battle._inspect_unit) and battle._inspect_unit.hp > 0.0:
		_sel_ref = [battle._inspect_unit]
	else:
		_sel_ref = sel
	_rebuild_grid()
	_rebuild_command_card()
	_refresh_panel()


## 情境命令卡（按当前活动单位 active_unit / Tab 子组）：英雄→技能槽；工人→建造；生产建筑→训练
func _rebuild_command_card() -> void:
	var au: Unit = battle.active_unit() if battle != null else null
	var eco: bool = battle != null and battle.economy
	var sig: Array
	if au != null and au.is_hero and au.slot_count() > 0:
		sig = ["hero", au.get_instance_id(), au.melee_mode]   # 切刀/弓 → 重建命令卡更新按钮态
	elif au != null and au.is_worker and eco:
		sig = ["build"]
	elif au != null and au.is_building and not au.is_constructing and (au.setup_def.has("produces") or au.setup_def.has("researches")) and eco:
		sig = ["train", au.get_instance_id(), au._train_queue.size()]   # 队列增减 → 重建以更新撤单图标
	elif au != null and au.is_building and not au.is_constructing and au.setup_def.has("trades") and eco:
		sig = ["trade", au.get_instance_id()]
	else:
		sig = []
	# 驻军建筑：签名加上当前驻军数 → 驻军变化时强制重建（出击按钮随之出现/更新）
	if au != null and au.is_building and not au.passengers.is_empty():
		sig = sig + ["eject", au.passengers.size()]
	if sig == _skill_keys:
		return
	_skill_keys = sig
	for c in _skill_bar.get_children():
		c.queue_free()
	for c in _queue_bar.get_children():
		c.queue_free()
	_queue_bar.visible = false
	_skill_bar.columns = 99   # 默认单排；生产建筑下面会改成多列分两排
	if au == null:
		return
	if au.is_hero and au.slot_count() > 0:
		var hotkeys := ["Q", "W", "E", "R"]
		for i in range(au.slot_count()):
			var b := HeroSlotButton.new()
			b.hud = self
			b.hero = au
			b.slot = i
			b.hotkey = hotkeys[i] if i < hotkeys.size() else ""
			_skill_bar.add_child(b)
	elif au.is_worker and eco:
		for spec in battle.build_menu():
			var cb := CmdButton.new()
			cb.hud = self
			cb.spec = spec
			_skill_bar.add_child(cb)
		# 维修键：让「修缮受损建筑」可被发现（不止右键）。点亮后再点己方建筑即派工人修。
		var rp := CmdButton.new()
		rp.hud = self
		rp.spec = {"kind": "repair", "label": "维修", "cost_g": 0, "cost_w": 0,
			"sub": "点亮后点选受损的己方建筑修缮"}
		_skill_bar.add_child(rp)
	elif au.is_building and not au.is_constructing and (au.setup_def.has("produces") or au.setup_def.has("researches")) and eco:
		# 生产建筑：训练/研究按钮更小、分两排（多列）；键盘 Q/W/E/R 仍按 train_menu 顺序派发。
		var prod: Array = []
		for spec in battle.train_menu(au):
			var cb := CmdButton.new(); cb.hud = self; cb.spec = spec; cb.compact = true
			prod.append(cb)
		for spec in battle.research_menu(au):
			var rb := CmdButton.new(); rb.hud = self; rb.spec = spec; rb.compact = true
			prod.append(rb)
		# 有驻军 → 出击键并入这张两排网格(同样紧凑)，免得单独成第三排溢出底栏
		if not au.passengers.is_empty():
			var eb := CmdButton.new(); eb.hud = self; eb.compact = true
			eb.spec = {"kind": "eject", "label": "出击 (%d)" % au.passengers.size(),
				"cost_g": 0, "cost_w": 0, "affordable": true, "sub": "驻军全部冲出", "bld": au}
			prod.append(eb)
		_skill_bar.columns = maxi(1, int(ceil(prod.size() / 2.0)))   # 分两排
		for b in prod:
			_skill_bar.add_child(b)
		# 生产队列专栏（与训练按钮分开，清楚显示在册项；队首=训练中带进度，点击撤单退资源）
		_rebuild_queue_bar(au)
	elif au.is_building and not au.is_constructing and au.setup_def.has("trades") and eco:
		for spec in battle.trade_menu(au):
			var tb := CmdButton.new()
			tb.hud = self
			tb.spec = spec
			_skill_bar.add_child(tb)
	# 英雄「驻扎」键：取代右键自动驻扎——点亮后左键点己方箭楼/聚义厅即进驻
	if au.is_hero:
		var gb := CmdButton.new()
		gb.hud = self
		gb.spec = {"kind": "garrison", "label": "驻扎", "cost_g": 0, "cost_w": 0,
			"affordable": true, "sub": "点亮后左键点选箭楼/聚义厅进驻"}
		_skill_bar.add_child(gb)
	# 出击按钮：有驻军的非生产建筑（如箭楼）显示在此（生产建筑的出击键已并入上面的两排网格）
	if au.is_building and not au.passengers.is_empty() \
			and not (au.setup_def.has("produces") or au.setup_def.has("researches")):
		var eb := CmdButton.new()
		eb.hud = self
		eb.spec = {"kind": "eject", "label": "出击 (%d)" % au.passengers.size(),
			"cost_g": 0, "cost_w": 0, "affordable": true, "sub": "驻军全部冲出", "bld": au}
		_skill_bar.add_child(eb)


## 生产队列专栏：标题「生产队列 N」+ 紧凑小图标网格（队首=训练中带剩余秒数，点击撤单退资源）。
## 空队列则隐藏。与训练按钮分开摆放，使在册项一目了然、便于逐项取消。
func _rebuild_queue_bar(bld) -> void:
	if not is_instance_valid(bld) or bld._train_queue.is_empty():
		_queue_bar.visible = false
		return
	_queue_bar.visible = true
	var title := Label.new()
	title.text = "生产队列  %d" % bld._train_queue.size()
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("ffd866"))
	_queue_bar.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 8   # 队列过长时自动换行，不再挤成一长条
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	_queue_bar.add_child(grid)
	for qi in range(bld._train_queue.size()):
		var qkey: String = bld._train_queue[qi]
		var qb := CmdButton.new()
		qb.hud = self
		qb.compact = true
		qb.spec = {"kind": "cancel_train", "key": qkey, "bld": bld, "index": qi,
			"label": String(battle._defs.get(qkey, {}).get("name", qkey)),
			"cost_g": 0, "cost_w": 0, "sub": "左键点击 = 取消该项生产（资源退还）"}
		grid.add_child(qb)


## 科技研究改变菜单后强制重建命令卡
func refresh_command() -> void:
	_skill_keys = []
	if not _sel_ref.is_empty():
		_rebuild_command_card()


func _on_skill_clicked(hero) -> void:
	if battle != null and is_instance_valid(hero):
		battle.cast_ability(hero)


## 选区成员变化时重建图标网格（成员不变只刷新血条由图标自身完成）
func _rebuild_grid() -> void:
	var alive: Array = _sel_ref.filter(func(u) -> bool: return is_instance_valid(u) and u.hp > 0.0)
	var keys: Array = alive.map(func(u) -> int: return u.get_instance_id())
	if keys == _grid_keys:
		return
	_grid_keys = keys
	for c in _sel_grid.get_children():
		c.queue_free()
	_sel_grid.columns = clampi(alive.size(), 1, 12)
	for u in alive:
		var icon := UnitIcon.new()
		icon.unit = u
		icon.hud = self
		_sel_grid.add_child(icon)


func _on_icon_clicked(u, additive: bool) -> void:
	if battle != null and is_instance_valid(u):
		battle.select_single(u, additive)


func _refresh_panel() -> void:
	var alive: Array = _sel_ref.filter(func(u) -> bool: return is_instance_valid(u) and u.hp > 0.0)
	# 拆除按钮：选区里有己方非资源单位/建筑时才显示（触屏隐藏小✕——操作栏已有大「拆」键）
	if _delete_btn != null:
		_delete_btn.visible = not touch_ui and alive.any(func(u) -> bool:
			return u.faction == Unit.FACTION_LIANG and not u.is_resource)
	if alive.is_empty():
		_info_name.text = ""
		_info_hp.text = ""
		_info_stats.text = ""
		_port_tex.visible = false
		_port_char.text = ""
		return
	var prim: Unit = battle.active_unit() if battle != null else null
	if prim == null or not is_instance_valid(prim):
		prim = alive[0]
		for u in alive:
			if u.is_hero:
				prim = u
				break
	var ptex: Texture2D = Art.avatar_texture(prim.key)
	if ptex != null:
		_port_tex.texture = ptex
		_port_tex.visible = true
	else:
		_port_tex.visible = false
		_port_char.text = prim.display_name.substr(0, 1)
	var multi := alive.size() > 1
	_port_frame.visible = multi          # 多选时点亮金框，标出面板这位即活动单位
	var title := prim.display_name
	if prim.is_hero and prim._hero_leveled:
		title += "  Lv%d" % prim.hero_level
	if multi:
		title = "▸ " + title + "  (当前 ｜ 共 %d ｜ Tab 切换)" % alive.size()
	_info_name.text = title
	_info_hp.text = "生命  %d / %d" % [int(prim.hp), int(prim.max_hp)]
	if prim.is_building:
		if prim.is_constructing:
			var pct: int = int(prim.build_progress / maxf(prim.build_time, 0.1) * 100.0)
			_info_hp.text = "施工  %d%%   （生命 %d / %d）" % [pct, int(prim.hp), int(prim.max_hp)]
			_info_stats.text = "右键工地续建 · 空选取消退资源"
		elif prim.setup_def.has("produces"):
			var q: int = prim._train_queue.size()
			if q > 0:
				_info_stats.text = "队列 %d · 剩 %d 秒 · 右键设集结点" % [q, int(ceil(prim._train_t))]
			else:
				_info_stats.text = "右键设集结点 · 资源上=自动采"
		elif prim.atk > 0.0:
			_info_stats.text = "箭楼 · 攻 %d  射程 %d  自动御敌" % [int(prim.atk), int(prim.atk_range)]
		else:
			_info_stats.text = "守住此处，便是守住梁山"
		if prim.garrison_cap > 0 and not prim.is_constructing:
			_info_stats.text += " · 驻军 %d/%d" % [prim.passengers.size(), prim.garrison_cap]
	elif prim.is_hero and prim._hero_leveled:
		# 攻显示「有效攻击」= atk×buff_atk（含科技/光环加成）；否则研究攻击科技后数字不变，看着像没生效
		# 防显示「有效防御」= defense − 削甲(_def_down)；每点防约减 5% 普攻伤害
		_info_stats.text = "攻 %d  防 %d  生命 %d  ｜ 经验 %d/%d  技能点 %d  ｜ %s" % [
			int(round(prim.atk * prim.buff_atk)), _eff_def(prim), int(prim.max_hp), int(prim.hero_xp), int(prim.xp_to_next()), prim.skill_points, _stance_tag(prim)]
	elif prim.is_worker:
		_info_stats.text = "攻 %d    防 %d    射程 %d    移速 %d" % [int(round(prim.atk * prim.buff_atk)), _eff_def(prim), int(prim.atk_range), int(prim.base_speed)]
	else:
		_info_stats.text = "攻 %d    防 %d    射程 %d    移速 %d    ｜ %s" % [
			int(round(prim.atk * prim.buff_atk)), _eff_def(prim), int(prim.atk_range), int(prim.base_speed), _stance_tag(prim)]


## 有效防御值（含双戒刀削甲 _def_down）；每点防约减 5% 普攻伤害。
func _eff_def(u) -> int:
	return int(round(maxf(0.0, u.defense - u._def_down)))


func _stance_tag(u) -> String:
	match u.stance:
		Unit.STANCE_DEFEND: return "姿态 守备(G)"
		Unit.STANCE_HOLD: return "姿态 据守(G)"
		Unit.STANCE_PASSIVE: return "姿态 避战(G)"
		_: return "姿态 进攻(G)"


func _style_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)


func _build_intro() -> void:
	_intro_root = ColorRect.new()
	_intro_root.color = Color(0, 0, 0, 0.55)
	_intro_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_root.visible = false
	add_child(_intro_root)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_root.add_child(cc)

	var panel := PanelContainer.new()
	cc.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	var port_holder := Control.new()
	port_holder.custom_minimum_size = Vector2(110, 110)
	hbox.add_child(port_holder)
	_intro_port_fallback = ColorRect.new()
	_intro_port_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	port_holder.add_child(_intro_port_fallback)
	_intro_port_char = Label.new()
	_intro_port_char.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_port_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_port_char.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_port_char.add_theme_font_size_override("font_size", 52)
	_intro_port_char.add_theme_color_override("font_color", Color(0, 0, 0, 0.75))
	_intro_port_fallback.add_child(_intro_port_char)
	_intro_port_tex = TextureRect.new()
	_intro_port_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_port_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intro_port_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port_holder.add_child(_intro_port_tex)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox)

	_intro_name = Label.new()
	_intro_name.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_intro_name)

	_intro_text = Label.new()
	_intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_text.custom_minimum_size = Vector2(560, 80)
	_intro_text.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_intro_text)

	var btn := Button.new()
	btn.text = "继续 ▸"
	btn.add_theme_font_size_override("font_size", 18)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.pressed.connect(_advance_intro)
	vbox.add_child(btn)
	_intro_btn = btn


func _build_end() -> void:
	_end_root = ColorRect.new()
	_end_root.color = Color(0.06, 0.05, 0.035, 0.93)   # 结算：近不透明暖深底
	_end_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_root.visible = false
	add_child(_end_root)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_root.add_child(cc)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(vbox)

	_end_title = Label.new()
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.add_theme_font_size_override("font_size", 52)
	vbox.add_child(_end_title)

	_end_sub = Label.new()
	_end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_sub.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_end_sub)

	# 各路好汉战功（按英雄歼敌排行）：金黄一行，居中可折行
	_end_tally = Label.new()
	_end_tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_tally.custom_minimum_size = Vector2(560, 0)
	_end_tally.add_theme_font_size_override("font_size", 18)
	_end_tally.add_theme_color_override("font_color", Color("ffd866"))
	vbox.add_child(_end_tally)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	_end_next = Button.new()
	_end_next.text = "下一关 ▸"
	_end_next.add_theme_font_size_override("font_size", 20)
	_end_next.pressed.connect(func() -> void: to_menu.emit())
	row.add_child(_end_next)

	var rbtn := Button.new()
	rbtn.text = "重打本关"
	rbtn.add_theme_font_size_override("font_size", 20)
	rbtn.pressed.connect(func() -> void: restart.emit())
	row.add_child(rbtn)

	var mbtn := Button.new()
	mbtn.text = "战役地图"
	mbtn.add_theme_font_size_override("font_size", 20)
	mbtn.pressed.connect(func() -> void: to_menu.emit())
	row.add_child(mbtn)


func show_intro(lines: Array) -> void:
	_intro_lines = lines
	_intro_i = 0
	_intro_root.visible = true
	_show_intro_line()


func _show_intro_line() -> void:
	var line: Dictionary = _intro_lines[_intro_i]
	var who: String = line.get("who", "旁白")
	var color: Color = SPEAKER_COLORS.get(who, Color.WHITE)
	_intro_name.text = "【%s】" % who
	_intro_name.add_theme_color_override("font_color", color)
	_intro_text.text = String(line.get("text", ""))
	var tex: Texture2D = Art.portrait_texture(String(line.get("key", "narrator")))
	if tex != null:
		_intro_port_tex.texture = tex
		_intro_port_tex.visible = true
		_intro_port_fallback.visible = false
	else:
		_intro_port_tex.visible = false
		_intro_port_fallback.visible = true
		_intro_port_fallback.color = color.darkened(0.2)
		_intro_port_char.text = who.substr(0, 1)


func _advance_intro() -> void:
	_intro_i += 1
	if _intro_i >= _intro_lines.size():
		_intro_root.visible = false
		intro_done.emit()
	else:
		_show_intro_line()


func show_deploy() -> void:
	start_btn.visible = true


func _on_start_pressed() -> void:
	start_btn.visible = false
	start_battle.emit()


func show_message(text: String, dur := 3.5) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(l, 28 if touch_ui else 20)
	msg_box.add_child(l)
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func set_top(text: String) -> void:
	top_label.text = text


## AI友好模式·自动镜头按钮：左下角（命令面板上方）。全员托管后出现，点一下开/关自动镜头。
func _build_autocam_badge() -> void:
	_autocam_btn = Button.new()
	_autocam_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_autocam_btn.offset_left = 12.0
	_autocam_btn.offset_right = 12.0 + 156.0
	_autocam_btn.offset_bottom = -(RTSCamera.PANEL_H + 12.0)   # 浮在底部指挥面板之上
	_autocam_btn.offset_top = _autocam_btn.offset_bottom - 40.0
	_autocam_btn.focus_mode = Control.FOCUS_NONE
	_autocam_btn.add_theme_font_size_override("font_size", 16)
	_autocam_btn.visible = false
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.12, 0.16, 0.92) if st == "normal" else Color(0.12, 0.20, 0.26, 0.96)
		sb.border_color = Color("5fd0e0")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		_autocam_btn.add_theme_stylebox_override(st, sb)
	_autocam_btn.add_theme_color_override("font_color", Color(0.74, 0.94, 1.0))
	_autocam_btn.add_theme_color_override("font_hover_color", Color(0.88, 0.98, 1.0))
	_autocam_btn.text = "🎥 自动镜头"
	_autocam_btn.pressed.connect(func() -> void:
		if battle != null and battle.has_method("toggle_autocam"):
			battle.toggle_autocam())
	add_child(_autocam_btn)


## 自动镜头按钮：show=全员托管才显示；on=当前是否已开启（开启时换文案+高亮，并在 _process 呼吸闪烁）。
func set_autocam_button(show: bool, on: bool) -> void:
	if _autocam_btn == null:
		return
	_autocam_on = on
	_autocam_btn.visible = show
	if not show:
		return
	_autocam_btn.text = "🎬 自动镜头·开" if on else "🎥 自动镜头"
	_autocam_btn.add_theme_color_override("font_color",
		Color(0.78, 1.0, 0.84) if on else Color(0.74, 0.94, 1.0))
	if not on:
		_autocam_btn.modulate.a = 1.0


func show_end(victory: bool, line: String, kills: int, has_next := false, hero_tally := "") -> void:
	_end_title.text = "旗开得胜！" if victory else "功败垂成……"
	_end_title.add_theme_color_override("font_color", Color("ffd866") if victory else Color("ff7766"))
	_end_sub.text = "%s\n此役歼灭敌军 %d 人。" % [line, kills]
	_end_tally.text = ("⚔ 各路好汉战功 ⚔\n" + hero_tally) if hero_tally != "" else ""
	_end_tally.visible = hero_tally != ""
	_end_next.visible = victory and has_next
	_end_root.visible = true


## 暂停菜单（Esc 呼出）：继续 / 重打 / 返回主菜单 / 退出
func _build_pause() -> void:
	_pause_root = ColorRect.new()
	_pause_root.color = Color(0.06, 0.05, 0.035, 0.95)   # 暂停菜单：近不透明暖深底，文字清晰
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.visible = false
	add_child(_pause_root)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(cc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(vb)

	var t := Label.new()
	t.text = "暂停"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color("ffd866"))
	vb.add_child(t)

	for spec in [["继续 (Esc)", resume_game], ["重新开始本局", restart], ["返回主菜单", to_menu], ["退出游戏", quit_game]]:
		var b := Button.new()
		b.text = String(spec[0])
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(240, 48)
		var sig: Signal = spec[1]
		b.pressed.connect(func() -> void: sig.emit())
		vb.add_child(b)

	# 设置（与主菜单同一套面板）：先收起暂停菜单，关闭设置后再弹回；HUD 为 ALWAYS，暂停态可操作
	var setb := Button.new()
	setb.text = "⚙ 设置"
	setb.add_theme_font_size_override("font_size", 22)
	setb.custom_minimum_size = Vector2(240, 48)
	setb.pressed.connect(func() -> void:
		hide_pause()
		var sp = preload("res://scripts/settings_panel.gd").new()
		sp.on_close = show_pause
		add_child(sp))
	vb.add_child(setb)

	# 全屏切换（亦可 F11 / Alt+Enter）
	var fsb := Button.new()
	fsb.add_theme_font_size_override("font_size", 20)
	fsb.custom_minimum_size = Vector2(240, 44)
	var scr := get_node_or_null("/root/Screen")
	fsb.text = ("⛶ 退出全屏 (F11)" if (scr != null and scr.is_fullscreen()) else "⛶ 全屏 (F11)")
	fsb.pressed.connect(func() -> void:
		if scr != null:
			scr.toggle_fullscreen()
			fsb.text = "⛶ 退出全屏 (F11)" if scr.is_fullscreen() else "⛶ 全屏 (F11)")
	vb.add_child(fsb)


func show_pause() -> void:
	_pause_root.visible = true


func hide_pause() -> void:
	_pause_root.visible = false


func _input(event: InputEvent) -> void:
	# 暂停态下 Esc 直接继续（HUD 始终处理，盖过被暂停的战斗输入）
	if _pause_root != null and _pause_root.visible \
			and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		resume_game.emit()
		get_viewport().set_input_as_handled()


## 小地图：地形底图（取贴图平均色）+ 敌我光点 + 视野框，点击/拖拽跳转视角
class Minimap extends Control:
	var battle = null
	var _bg: Texture2D
	var _accum := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(132, 132)

	func _process(delta: float) -> void:
		_accum += delta
		if _accum >= 0.1:
			_accum = 0.0
			queue_redraw()

	func _build_bg() -> void:
		var map: GameMap = battle.map
		var img := Image.create(map.w, map.h, false, Image.FORMAT_RGBA8)
		for y in range(map.h):
			for x in range(map.w):
				img.set_pixel(x, y, map._blend_color(map.t_at(x, y)))
		_bg = ImageTexture.create_from_image(img)

	func _ws() -> Vector2:
		return Vector2(battle.map.w * GameMap.CELL, battle.map.h * GameMap.CELL)

	func _draw() -> void:
		if battle == null:
			return
		if _bg == null:
			_build_bg()
		draw_texture_rect(_bg, Rect2(Vector2.ZERO, size), false)
		var ws := _ws()
		for u in battle.units:
			if not is_instance_valid(u) or u.hp <= 0.0 or u.garrisoned:
				continue   # 驻军单位藏在建筑里，小地图不另外画点
			if u.faction == Unit.FACTION_GUAN and battle.fog and not battle.is_visible_world(u.position):
				# 迷雾中：普通敌人不显示；但探明过的敌方建筑保留在小地图（记忆迷雾）
				if not (u.is_building and battle.is_explored_world(u.position)):
					continue
			var p: Vector2 = u.position / ws * size
			var col := Color("ffd866") if u.faction == Unit.FACTION_LIANG else Color("ff5544")
			if u.is_building:
				col = Color.WHITE
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), col)
		var cam: Camera2D = battle.camera
		var vp: Vector2 = get_viewport().get_visible_rect().size / cam.zoom.x
		var pts := PackedVector2Array()
		for corner in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5), Vector2(-0.5, -0.5)]:
			var sp: Vector2 = cam.position + corner * vp
			pts.append(battle.to_logic(sp) / ws * size)
		draw_polyline(pts, Color(1, 1, 1, 0.75), 1.0)
		# 遭袭告警：红框闪烁 + 红点
		if battle._alert_t > 0.0:
			var fl := 0.5 + 0.5 * sin(battle._alert_t * 18.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.2, 0.15, fl), false, 3.0)
			var ap: Vector2 = battle._alert_pos / ws * size
			draw_circle(ap, 3.0 + 2.0 * fl, Color(1.0, 0.25, 0.2, fl))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 1.5)

	func _gui_input(event: InputEvent) -> void:
		if battle == null:
			return
		var jump := false
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			jump = true
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			jump = true
		if jump:
			battle.camera.position = battle.to_screen(event.position / size * _ws())
			accept_event()


## 选区单位图标：精灵/头像 + 实时血条；左键单选，Shift 加减
class UnitIcon extends Control:
	var unit: Unit = null
	var hud = null

	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		tooltip_text = ""

	func _process(_delta: float) -> void:
		if is_instance_valid(unit):
			tooltip_text = unit.display_name
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(unit) or unit.hp <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.04))
		# 统一取图链（脸→走图→建筑→物件→地形+别名）：建筑/资源/特殊单位都能拿到图，消灭黄圈
		var tex: Texture2D = Art.avatar_texture(unit.key)
		if tex != null:
			draw_texture_rect(tex, Rect2(3, 1, size.x - 6, size.y - 9), false)
		else:
			# 极少数仍无图者：画名字首字（而非黄圈），至少能认出是谁
			var f := ThemeDB.fallback_font
			var col := Color("e6b84c") if unit.faction == Unit.FACTION_LIANG else Color("e08c7c")
			draw_string(f, Vector2(0, size.y * 0.5 + 6.0), unit.display_name.substr(0, 1),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, col)
		# 血条
		var frac := clampf(unit.hp / unit.max_hp, 0.0, 1.0)
		draw_rect(Rect2(3, size.y - 6, size.x - 6, 4), Color(0, 0, 0, 0.75))
		var hc := Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.3), frac)
		draw_rect(Rect2(3, size.y - 6, (size.x - 6) * frac, 4), hc)
		# 边框：编队里「活动单位」（Tab/命令面板指向的那个）画醒目金粗框 + 淡金底，一眼看出当前是谁
		var multi: bool = hud != null and hud._sel_ref.size() > 1
		var active: bool = multi and hud.battle != null and hud.battle.active_unit() == unit
		if active:
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(1.0, 0.95, 0.6, 0.22))
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.84, 0.26), false, 3.0)
		else:
			var bc := Color("ffd866") if unit.is_hero else Color(0.45, 0.38, 0.26)
			draw_rect(Rect2(Vector2.ZERO, size), bc, false, 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if hud != null:
				hud._on_icon_clicked(unit, event.shift_pressed)
			accept_event()


## 技能按钮：名称 + 说明 + 冷却倒计时遮罩；点击施放
class SkillButton extends Control:
	var hero: Unit = null
	var hud = null
	var adef := {}
	var hotkey := ""

	func _init() -> void:
		custom_minimum_size = Vector2(150, 100)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(_delta: float) -> void:
		if is_instance_valid(hero):
			tooltip_text = "%s（%s）" % [adef.get("name", ""), hotkey]
			queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(hero):
			return
		var f := ThemeDB.fallback_font
		var col: Color = adef.get("color", Color.WHITE)
		var rdy := hero.ability_ready()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.10, 0.07))
		draw_rect(Rect2(0, 0, 5, size.y), col)
		draw_string(f, Vector2(13, 23), adef.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 18, Color("ffd866"))
		# 右上角热键键帽
		if hotkey != "":
			draw_rect(Rect2(size.x - 25, 6, 18, 18), Color(0.05, 0.04, 0.03, 0.9))
			draw_rect(Rect2(size.x - 25, 6, 18, 18), Color(0.5, 0.45, 0.3), false, 1.0)
			draw_string(f, Vector2(size.x - 21, 20), hotkey, HORIZONTAL_ALIGNMENT_LEFT, 16, 14, Color("ffe9a8"))
		draw_multiline_string(f, Vector2(13, 44), adef.get("desc", ""), HORIZONTAL_ALIGNMENT_LEFT, size.x - 18, 12, -1, Color(0.82, 0.82, 0.78))
		# 冷却遮罩 + 倒计时秒数（自下而上填充）
		if not rdy:
			var frac := hero.ability_cd_frac()
			draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(0, size.y * (1.0 - frac), size.x, size.y * frac), Color(0.2, 0.3, 0.5, 0.4))
			if Settings.show_cooldown:
				var secs := int(ceil(frac * hero.ability_cd))
				draw_string(f, Vector2(0, size.y * 0.5 + 12.0), str(secs), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(1, 1, 1, 0.92))
		var bc := col if rdy else Color(0.32, 0.32, 0.32)
		draw_rect(Rect2(Vector2.ZERO, size), bc, false, 2.0 if rdy else 1.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if hud != null and is_instance_valid(hero):
				hud._on_skill_clicked(hero)
			accept_event()


## 命令卡通用按钮（建造菜单用）：标题 + 花费 + 可负担态；点击施放 spec.action
class CmdButton extends Control:
	var hud = null
	var spec := {}
	var compact := false   # 生产训练/队列用：更小的图标，便于分两排紧凑排列
	var _press_ms := 0
	var _held := false
	var _tip_shown := false

	func _init() -> void:
		# 经典RTS式紧凑命令图标：方形图标 + 单位/建筑名 + 花费。详细说明走「悬浮说明卡」，省横向空间。
		custom_minimum_size = Vector2(76, 88)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_hover_in)
		mouse_exited.connect(_on_hover_out)

	func _process(_delta: float) -> void:
		queue_redraw()
		var _t: bool = hud != null and hud.touch_ui
		if compact:
			custom_minimum_size = Vector2(74, 68) if _t else Vector2(62, 68)   # 生产按钮更小·矮一点，两排能完整放进底栏
		else:
			custom_minimum_size = Vector2(88, 104) if _t else Vector2(76, 88)   # 触屏放大易点
		# 触屏：长按 ≥400ms 弹说明（替代失效的鼠标 hover）
		if _held and hud != null and hud.touch_ui and not _tip_shown and Time.get_ticks_msec() - _press_ms >= 400:
			_tip_shown = true
			_on_hover_in()

	func _on_hover_in() -> void:
		if hud == null:
			return
		var cg := int(spec.get("cost_g", 0))
		var cw := int(spec.get("cost_w", 0))
		var kind := String(spec.get("kind", "build"))
		var sub := String(spec.get("sub", ""))
		if sub == "":
			match kind:
				"train": sub = "左键训练（Shift 排队）"
				"build": sub = "左键选址放置"
				"research": sub = "左键研究科技"
				"trade": sub = "左键交易"
				"eject": sub = "驻军全部冲出"
		var foot := ""
		if cg > 0 or cw > 0:
			foot = "花费　金 %d　木 %d" % [cg, cw]
		hud.show_skill_tip(self, get_global_rect(), String(spec.get("label", "")), sub, foot, Color("ffd866"))

	func _on_hover_out() -> void:
		if hud != null:
			hud.hide_skill_tip(self)

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var b = hud.battle if hud != null else null
		var cg := int(spec.get("cost_g", 0))
		var cw := int(spec.get("cost_w", 0))
		var aff: bool = b != null and b.can_afford(cg, cw)
		var kind := String(spec.get("kind", "build"))
		var key := String(spec.get("key", ""))
		var accent := Color(0.55, 0.42, 0.22)
		var glyph := "建"
		var tex: Texture2D = null
		if kind == "train":
			accent = Color(0.45, 0.55, 0.32); glyph = "练"; tex = Art.avatar_texture(key)   # 有头像优先用头像(干净)，无则退回走图
		elif kind == "build":
			tex = Art.building_texture(key)
		elif kind == "research":
			accent = Color(0.45, 0.4, 0.62); glyph = "研"
		elif kind == "trade":
			accent = Color(0.6, 0.5, 0.2); glyph = "易"
		elif kind == "eject":
			accent = Color(0.6, 0.3, 0.25); glyph = "出"
		elif kind == "repair":
			accent = Color(0.3, 0.55, 0.62); glyph = "修"
		elif kind == "weapon":
			accent = Color(0.42, 0.5, 0.62); glyph = "刀" if bool(spec.get("melee", false)) else "弓"
		elif kind == "garrison":
			accent = Color(0.42, 0.45, 0.72); glyph = "驻"
		elif kind == "cancel_train":
			accent = Color(0.66, 0.28, 0.24); glyph = "×"; tex = Art.avatar_texture(key)   # 队列图标同样优先用头像
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.09, 0.06))
		# 方形图标：有贴图用贴图（不可负担则压暗），否则画类别字形底。触屏整体放大（图标盒 + 字形随盒缩放）。
		var big: bool = hud != null and hud.touch_ui
		var ir: Rect2
		if compact:
			var isz := minf(size.x - 8.0, size.y - 26.0)   # 预留底部两行小字
			ir = Rect2((size.x - isz) * 0.5, 4.0, isz, isz)
		else:
			ir = Rect2(14, 6, 60, 60) if big else Rect2(12, 5, 52, 52)
		var gsc := ir.size.x / 52.0
		draw_rect(ir, Color(0.06, 0.05, 0.04))
		if tex != null:
			draw_texture_rect(tex, ir, false, Color(1, 1, 1) if aff else Color(0.5, 0.46, 0.42))
		else:
			draw_rect(ir, accent.darkened(0.35))
			draw_string(f, Vector2(ir.position.x, ir.position.y + ir.size.y * 0.71), glyph, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, int(30 * gsc),
				Color(0.96, 0.9, 0.78) if aff else Color(0.6, 0.55, 0.5))
		# 名称（y 随按钮高度，desktop 88→69、touch 104→85）
		draw_string(f, Vector2(3, size.y - 19), String(spec.get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, (11 if compact else (15 if big else 13)),
			Color("ffd866") if aff else Color(0.62, 0.52, 0.4))
		# 底行：花费；生产/研究中则显示进度
		var info := ""
		if cg > 0:
			info += "金%d " % cg
		if cw > 0:
			info += "木%d" % cw
		if kind == "eject":
			info = "驻军全出"
		elif kind == "repair":
			info = "修受损建筑"
		elif kind == "weapon":
			info = "+10%吸血" if bool(spec.get("melee", false)) else "可拔刀"
		elif kind == "garrison":
			info = "点亮后点建筑进驻"
		elif kind == "train":
			var bld = spec.get("bld", null)
			if is_instance_valid(bld) and not bld._train_queue.is_empty():
				info = "队列%d 剩%ds" % [bld._train_queue.size(), int(ceil(bld._train_t))]
		elif kind == "research":
			var rb = spec.get("bld", null)
			if is_instance_valid(rb) and rb._research_key != "":
				info = "研究 剩%ds" % int(ceil(rb._research_t))
		elif kind == "cancel_train":
			var cb = spec.get("bld", null)
			if int(spec.get("index", -1)) == 0 and is_instance_valid(cb):
				info = "训练中 剩%ds·点撤" % int(ceil(cb._train_t))
			else:
				info = "排队·点撤单"
		# 撤单图标：右上角红 × 角标，提示「点我取消」
		if kind == "cancel_train":
			var bdg := Rect2(ir.position.x + ir.size.x - 17, ir.position.y, 17, 17)
			draw_rect(bdg, Color(0.72, 0.14, 0.11, 0.92))
			draw_string(f, Vector2(bdg.position.x + 3, bdg.position.y + 14), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
		draw_string(f, Vector2(3, size.y - 4), info, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, (9 if compact else (13 if big else 11)),
			Color("ffd24a") if aff else Color(0.85, 0.35, 0.3))
		# 快捷键键帽（Q/W/E/R，与 _command_hotkey 槽位一致）；「出击」/撤单/队列 非槽位命令，不画键帽。触屏隐藏（手机无键盘）
		var slot := get_index()
		if slot < 4 and kind != "eject" and kind != "weapon" and kind != "repair" and kind != "garrison" and kind != "cancel_train" and not (hud != null and hud.touch_ui):
			var keyc: String = ["Q", "W", "E", "R"][slot]
			var kr := Rect2(size.x - 17, 3, 15, 15)
			draw_rect(kr, Color(0, 0, 0, 0.6))
			draw_rect(kr, Color(0.75, 0.62, 0.34), false, 1.0)
			draw_string(f, Vector2(size.x - 14, 15), keyc, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe9a8"))
		draw_rect(Rect2(Vector2.ZERO, size), accent if aff else Color(0.4, 0.32, 0.24), false, 1.5)

	func _execute() -> void:
		if hud == null or hud.battle == null:
			return
		var kind := String(spec.get("kind", "build"))
		if kind == "train":
			hud.battle.queue_train(spec.get("bld", null), String(spec.get("key", "")))
		elif kind == "research":
			hud.battle.queue_research(spec.get("bld", null), String(spec.get("key", "")))
			hud.refresh_command()
		elif kind == "trade":
			hud.battle.do_trade(String(spec.get("give", "wood")))
		elif kind == "eject":
			hud.battle.ungarrison(spec.get("bld", null))
		elif kind == "repair":
			hud.battle.arm_repair()
		elif kind == "garrison":
			hud.battle.arm_garrison()
		elif kind == "weapon":
			hud.battle.toggle_hero_melee(spec.get("hero", null))
		elif kind == "cancel_train":
			hud.battle.cancel_train(spec.get("bld", null), int(spec.get("index", -1)))
		else:
			hud.battle.arm_build(String(spec.get("key", "")))

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if hud == null or not hud.touch_ui:
			if event.pressed:           # 桌面：按下即执行（hover 出说明）
				_execute()
			accept_event()
			return
		# 触屏：短按执行，长按只出说明（_process 里弹）
		if event.pressed:
			_held = true
			_press_ms = Time.get_ticks_msec()
		else:
			_held = false
			if _tip_shown:
				_tip_shown = false
				_on_hover_out()
			else:
				_execute()
		accept_event()


## 英雄技能槽按钮：名称 + 等级点 + 冷却 + 学习(+)；点击施放/学习
class HeroSlotButton extends Control:
	var hud = null
	var hero: Unit = null
	var slot := 0
	var hotkey := ""
	var compact := false      # 右侧技能轨用紧凑尺寸
	var _press_ms := 0
	var _held := false
	var _tip_shown := false
	var _press_pos := Vector2.ZERO
	var _aiming := false       # 触屏：按下技能即进入「瞄准」(指向技)，拖动准星跟手指、松手在落点放招

	# 技能 id → 矢量图标种类。花荣神射四式各有专属图标；其余英雄按招式归类，整张命令卡都图标化。
	const ICON_TOKENS := {
		"hua_shot": "bow", "hua_rain": "rain", "hua_pin": "pin", "hua_eye": "eye", "hua_blade": "saber",
		"song_rally": "banner", "song_meteor": "fire", "song_fire": "fire", "song_lead": "star",
		"lin_sweep": "blade", "lin_charge": "spear", "lin_storm": "blade", "lin_drill": "star",
		"li_berserk": "axe", "li_whirl": "axe", "li_rage": "axe", "li_brawn": "star",
		"wu_fire": "fire", "gongsun_thunder": "thunder", "bai_drug": "drug", "zhang_drag": "wave",
	}

	func _init() -> void:
		# 紧凑技能图标：色块徽记 + 技能名；等级/冷却/被动叠在图标上，详细说明走「悬浮说明卡」
		custom_minimum_size = Vector2(76, 88)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_hover_in)
		mouse_exited.connect(_on_hover_out)

	func _process(_delta: float) -> void:
		if is_instance_valid(hero) and slot < hero.slot_count():
			queue_redraw()
		custom_minimum_size = (Vector2(78, 94) if compact else Vector2(88, 104)) if (hud != null and hud.touch_ui) else Vector2(76, 88)   # 触屏放大易点；右侧技能轨也放大易点
		# 触屏：长按 ≥400ms 弹技能说明（替代失效的鼠标 hover；松手不施放）。瞄准中不弹说明。
		if _held and not _aiming and hud != null and hud.touch_ui and not _tip_shown and Time.get_ticks_msec() - _press_ms >= 400:
			_tip_shown = true
			_on_hover_in()

	func _on_hover_in() -> void:
		if hud == null or hud.battle == null or not is_instance_valid(hero) or slot >= hero.slot_count():
			return
		var s: Dictionary = hero.ability_slots[slot]
		var ad: Dictionary = hud.battle.ability_def(String(s["id"]))
		var passive := bool(s["passive"])
		var has_active: bool = hero.slot_has_active(slot)
		var rank := int(s["rank"])
		var cd := int(round(hero.slot_cd(slot)))
		var foot := ""
		if passive and not has_active:
			foot = "常驻被动 · 无需施放"
		elif passive and has_active:
			foot = "常驻被动 + 主动 · 冷却 %d 秒 · 等级 %d/3 · 热键 %s" % [cd, rank, hotkey]
		elif rank <= 0:
			foot = "未学习 · 点图标右下「＋」学习（消耗技能点）"
		else:
			foot = "冷却 %d 秒 · 等级 %d/3 · 热键 %s" % [cd, rank, hotkey]
		# 说明 + 各级数值速览（1/2/3 级）——悬浮即见技能详情
		var body := Defs.ability_desc(String(s["id"]), rank)
		var detail := Defs.ability_levels(String(s["id"]))
		if detail != "":
			body += "\n〔1/2/3级〕" + detail
		hud.show_skill_tip(self, get_global_rect(), String(ad.get("name", "")),
			body, foot, ad.get("color", Color.WHITE))

	func _on_hover_out() -> void:
		if hud != null:
			hud.hide_skill_tip(self)

	func _draw() -> void:
		if hud == null or hud.battle == null or not is_instance_valid(hero) or slot >= hero.slot_count():
			return
		var f := ThemeDB.fallback_font
		var s: Dictionary = hero.ability_slots[slot]
		var ad: Dictionary = hud.battle.ability_def(String(s["id"]))
		var col: Color = ad.get("color", Color.WHITE)
		var passive: bool = bool(s["passive"])
		var rank: int = int(s["rank"])
		var learned := rank > 0
		var nm := String(ad.get("name", ""))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.09, 0.06))
		# 方形徽记：技能色块底 + 矢量图标（无图标的技能回退名称首字）
		var big: bool = hud != null and hud.touch_ui
		var ir: Rect2
		if compact:
			ir = Rect2(10, 6, 58, 58)       # 右侧技能轨：图标 58²，居中且不溢出 78×94 边框
		elif big:
			ir = Rect2(14, 6, 60, 60)
		else:
			ir = Rect2(12, 5, 52, 52)
		var ds := ir.size.x / 52.0
		draw_rect(ir, col.darkened(0.15) if learned else col.darkened(0.55))
		var token := String(ICON_TOKENS.get(String(s["id"]), ""))
		if token != "":
			_draw_ability_icon(token, ir, col, learned)
		else:
			draw_string(f, Vector2(ir.position.x, ir.position.y + ir.size.y * 0.71), nm.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, int(30 * ds),
				Color(1, 1, 1, 0.94) if learned else Color(0.85, 0.85, 0.85, 0.6))
		# 被动角标
		if passive:
			draw_string(f, Vector2(ir.position.x, ir.position.y + 13.0 * ds), "被动", HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, int(11 * ds), Color(0.78, 0.92, 0.78))
		# 等级圆点（满 3 级）叠在图标底部
		for i in range(3):
			var px := ir.position.x + 8.0 * ds + float(i) * 13.0 * ds
			draw_rect(Rect2(px, ir.end.y - 9.0 * ds, 9.0 * ds, 6.0 * ds), col.lightened(0.25) if i < rank else Color(0, 0, 0, 0.45))
			draw_rect(Rect2(px, ir.end.y - 9.0 * ds, 9.0 * ds, 6.0 * ds), Color(0.5, 0.45, 0.3, 0.8), false, 1.0)
		# 混合被动（宋江 R）既常驻又可主动放 → 当作可施放技能走冷却显示
		var castable: bool = (not passive) or hero.slot_has_active(slot)
		# 冷却遮罩 / 未学暗罩（叠在图标上）
		if castable and learned and not hero.slot_ready(slot):
			var frac := hero.slot_cd_frac(slot)
			draw_rect(ir, Color(0, 0, 0, 0.55))
			if Settings.show_cooldown:
				var secs := int(ceil(frac * hero.slot_cd(slot)))
				draw_string(f, Vector2(ir.position.x, ir.position.y + ir.size.y * 0.65), str(secs), HORIZONTAL_ALIGNMENT_CENTER, ir.size.x, int(24 * ds), Color(1, 1, 1, 0.95))
		elif rank == 0 and not passive:
			draw_rect(ir, Color(0, 0, 0, 0.36))
		# 名称（y 随按钮高度）
		var nm_fs: int = 14 if compact else (15 if big else 13)
		draw_string(f, Vector2(3, size.y - 19), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, nm_fs, Color("ffd866") if learned else Color(0.6, 0.55, 0.45))
		# 底行状态：未冷却时显示该技能（当前等级）的冷却秒数——让玩家随时看到「CD 多少」
		var st := ""
		if castable and learned and not hero.slot_ready(slot):
			st = "冷却 %ds" % int(ceil(hero.slot_cd_frac(slot) * hero.slot_cd(slot)))
		elif castable and learned:
			st = "CD %ds " % int(round(hero.slot_cd(slot))) + hotkey   # 就绪：直接标出冷却时长
		elif passive:
			st = "常驻"
		elif hero.can_learn(slot):
			st = "可学 +"
		draw_string(f, Vector2(3, size.y - 4), st, HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, (12 if compact else 13) if big else 11, Color(0.82, 0.86, 0.72))
		var _touch: bool = big
		# 热键键帽（触屏隐藏，手机无键盘）
		if hotkey != "" and not passive and not _touch:
			var kr := Rect2(size.x - 17, 3, 15, 15)
			draw_rect(kr, Color(0, 0, 0, 0.6))
			draw_rect(kr, Color(0.75, 0.62, 0.34), false, 1.0)
			draw_string(f, Vector2(size.x - 14, 15), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffe9a8"))
		# 学习按钮 +（图标右下角）；触屏放大到易点
		if hero.can_learn(slot):
			var pc := Vector2(ir.end.x - 9.0, ir.end.y - 9.0)
			var pr := (11.0 if compact else 18.0) if _touch else 9.0
			draw_circle(pc, pr, Color(0.18, 0.6, 0.24))
			draw_circle(pc, pr, Color(0.85, 0.95, 0.85), false, 1.5)
			var pf := (18 if compact else 28) if _touch else 18
			draw_string(f, Vector2(pc.x - 11, pc.y + pf * 0.34), "+", HORIZONTAL_ALIGNMENT_CENTER, 24, pf, Color(0.95, 1, 0.95))
		draw_rect(Rect2(Vector2.ZERO, size), col if learned else Color(0.35, 0.3, 0.22), false, 1.5)

	## 在徽记方块内画矢量技能图标。token 见 ICON_TOKENS；ink=亮描线，ac=技能色描线（未学则压暗）。
	func _draw_ability_icon(token: String, ir: Rect2, col: Color, lit: bool) -> void:
		var cx := ir.position.x + ir.size.x * 0.5
		var cy := ir.position.y + ir.size.y * 0.45
		var sc := ir.size.x / 52.0
		# 整张矢量图标绕中心按盒子缩放（连线宽一起）；sc=1 即恒等变换，桌面渲染零变化。
		if sc != 1.0:
			draw_set_transform(Vector2(cx, cy) * (1.0 - sc), 0.0, Vector2(sc, sc))
		var a := 0.96 if lit else 0.5
		var ink := Color(1, 0.98, 0.9, a)
		var ac := Color(col.r, col.g, col.b, a)
		match token:
			"bow":   # 百步穿杨：弓 + 搭箭右射
				draw_arc(Vector2(cx - 11, cy), 15.0, -1.15, 1.15, 18, ac, 3.0)
				draw_line(Vector2(cx - 11 + 15.0 * cos(-1.15), cy + 15.0 * sin(-1.15)), Vector2(cx - 11 + 15.0 * cos(1.15), cy + 15.0 * sin(1.15)), ink, 1.2)
				draw_line(Vector2(cx - 11, cy), Vector2(cx + 13, cy), ink, 2.2)
				draw_colored_polygon(PackedVector2Array([Vector2(cx + 18, cy), Vector2(cx + 11, cy - 4.5), Vector2(cx + 11, cy + 4.5)]), ink)
				draw_line(Vector2(cx - 11, cy), Vector2(cx - 16, cy - 4), ac, 1.6)
				draw_line(Vector2(cx - 11, cy), Vector2(cx - 16, cy + 4), ac, 1.6)
			"rain":  # 箭雨：三支斜向下落的箭
				for i in range(3):
					var ox := (float(i) - 1.0) * 11.0 + 2.0
					var tp := Vector2(cx + ox - 5, cy - 15)
					var bp := Vector2(cx + ox + 4, cy + 14)
					draw_line(tp, bp, ink, 2.0)
					var d := (bp - tp).normalized()
					var pp := d.orthogonal()
					draw_colored_polygon(PackedVector2Array([bp + d * 4.0, bp - d * 3.0 + pp * 3.5, bp - d * 3.0 - pp * 3.5]), ink)
					draw_line(tp, tp - d * 4.0 + pp * 3.0, ac, 1.4)
					draw_line(tp, tp - d * 4.0 - pp * 3.0, ac, 1.4)
			"pin":   # 定身神箭：大箭穿环
				draw_arc(Vector2(cx + 4, cy), 11.0, 0.0, TAU, 22, ac, 2.4)
				draw_line(Vector2(cx - 17, cy - 6), Vector2(cx + 15, cy + 6), ink, 2.6)
				var dd := (Vector2(cx + 15, cy + 6) - Vector2(cx - 17, cy - 6)).normalized()
				var op := dd.orthogonal()
				draw_colored_polygon(PackedVector2Array([Vector2(cx + 15, cy + 6) + dd * 5.0, Vector2(cx + 15, cy + 6) - dd * 3.5 + op * 4.0, Vector2(cx + 15, cy + 6) - dd * 3.5 - op * 4.0]), ink)
			"eye":   # 小李广（神射被动）：靶心
				draw_arc(Vector2(cx, cy), 14.0, 0.0, TAU, 26, ac, 2.0)
				draw_arc(Vector2(cx, cy), 8.0, 0.0, TAU, 20, ink, 1.6)
				draw_circle(Vector2(cx, cy), 3.0, ac)
			"fire":  # 火攻：火苗
				draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 16), Vector2(cx + 10, cy + 2), Vector2(cx + 5, cy + 13), Vector2(cx - 5, cy + 13), Vector2(cx - 10, cy + 2)]), ac)
				draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 6), Vector2(cx + 5, cy + 4), Vector2(cx, cy + 12), Vector2(cx - 5, cy + 4)]), ink)
			"banner":  # 替天行道：旗
				draw_line(Vector2(cx - 9, cy - 16), Vector2(cx - 9, cy + 16), ink, 2.0)
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 9, cy - 15), Vector2(cx + 14, cy - 10), Vector2(cx - 9, cy - 1)]), ac)
			"wing":  # 神行：三道速度气流
				for i in range(3):
					var yy := cy - 9.0 + float(i) * 9.0
					draw_arc(Vector2(cx + 4, yy), 12.0 - float(i) * 1.5, deg_to_rad(150), deg_to_rad(265), 14, ac if i == 1 else ink, 2.0)
			"blade":  # 横扫：刀光弧 + 火花
				draw_arc(Vector2(cx - 4, cy + 4), 17.0, deg_to_rad(-75), deg_to_rad(25), 18, ink, 3.0)
				draw_line(Vector2(cx + 9, cy - 12), Vector2(cx + 15, cy - 16), ac, 1.6)
				draw_line(Vector2(cx + 11, cy - 8), Vector2(cx + 17, cy - 10), ac, 1.4)
			"spear":  # 冲锋：枪
				draw_line(Vector2(cx - 15, cy + 14), Vector2(cx + 11, cy - 12), ink, 2.4)
				draw_colored_polygon(PackedVector2Array([Vector2(cx + 16, cy - 16), Vector2(cx + 7, cy - 13), Vector2(cx + 12, cy - 7)]), ink)
			"axe":   # 黑旋风：板斧
				draw_line(Vector2(cx - 10, cy + 15), Vector2(cx + 6, cy - 12), ink, 2.2)
				draw_arc(Vector2(cx + 4, cy - 8), 12.0, deg_to_rad(-60), deg_to_rad(80), 16, ac, 6.0)
			"thunder":  # 五雷：闪电
				draw_colored_polygon(PackedVector2Array([Vector2(cx + 2, cy - 16), Vector2(cx - 8, cy + 2), Vector2(cx - 1, cy + 2), Vector2(cx - 6, cy + 16), Vector2(cx + 9, cy - 4), Vector2(cx + 2, cy - 4)]), ac)
			"drug":  # 蒙汗药：酒葫芦
				draw_circle(Vector2(cx, cy + 5), 11.0, ac)
				draw_circle(Vector2(cx, cy - 8), 5.0, ac)
				draw_line(Vector2(cx - 3, cy - 13), Vector2(cx + 3, cy - 13), ink, 2.0)
			"wave":  # 浪里拖人：水波
				for i in range(3):
					draw_arc(Vector2(cx, cy - 8.0 + float(i) * 9.0), 14.0, deg_to_rad(20), deg_to_rad(160), 16, ac if i == 1 else ink, 2.0)
			"saber":  # 拔刀·换刀（大招）：单刀 + 双向小箭暗示切换
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 12, cy + 14), Vector2(cx + 14, cy - 12), Vector2(cx + 17, cy - 9), Vector2(cx - 9, cy + 16)]), ink)
				draw_line(Vector2(cx - 16, cy + 10), Vector2(cx - 7, cy + 18), ac, 2.6)   # 护手
				draw_line(Vector2(cx - 12, cy + 14), Vector2(cx - 17, cy + 19), ac, 3.4)  # 刀柄
				draw_line(Vector2(cx - 4, cy - 9), Vector2(cx - 12, cy - 9), ac, 1.6)     # 切换小箭
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, cy - 9), Vector2(cx - 10, cy - 12), Vector2(cx - 10, cy - 6)]), ac)
			"star":  # 被动：四芒星
				draw_colored_polygon(PackedVector2Array([Vector2(cx, cy - 15), Vector2(cx + 4, cy - 4), Vector2(cx + 15, cy), Vector2(cx + 4, cy + 4), Vector2(cx, cy + 15), Vector2(cx - 4, cy + 4), Vector2(cx - 15, cy), Vector2(cx - 4, cy - 4)]), ink)
				draw_circle(Vector2(cx, cy), 3.0, ac)
		if sc != 1.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _execute(pos: Vector2) -> void:
		if hud == null or hud.battle == null or not is_instance_valid(hero) or slot >= hero.slot_count():
			return
		# 学习「+」热区：精确匹配 _draw 里画的圆（圆心 ir.end-9，半径 9，留 1px 容差）。
		# 用同一 ir 推导，避免热区无右/下界——否则点图标右下空白会误把「升级技能」当成施放，白扣技能点。
		var ir := Rect2(14, 6, 60, 60) if (hud != null and hud.touch_ui) else Rect2(12, 5, 52, 52)
		var plus_r: float = 22.0 if (hud != null and hud.touch_ui) else 10.0   # 触屏放大「+」热区，好点
		var on_plus: bool = pos.distance_to(Vector2(ir.end.x - 9.0, ir.end.y - 9.0)) <= plus_r
		if hero.can_learn(slot) and (on_plus or int(hero.ability_slots[slot]["rank"]) == 0):
			hud.battle.learn_slot(hero, slot)
		elif (not bool(hero.ability_slots[slot]["passive"]) or hero.slot_has_active(slot)) and int(hero.ability_slots[slot]["rank"]) > 0:
			hud.battle.cast_ability(hero, slot)

	## 该槽此刻是否「指向技能、可直接瞄准施放」（用于触屏：按下技能即拖动瞄准、松手放招）。
	## 学习「+」热区 / 非指向技 / 未学 / 冷却中 → 返回 false，走普通 _execute(学习 / 即放 / 提示)。
	func _can_aim_cast() -> bool:
		if hud == null or hud.battle == null or not is_instance_valid(hero) or slot >= hero.slot_count():
			return false
		var s: Dictionary = hero.ability_slots[slot]
		if int(s["rank"]) <= 0:
			return false
		if bool(s["passive"]) and not hero.slot_has_active(slot):
			return false
		var ir := Rect2(14, 6, 60, 60) if (hud != null and hud.touch_ui) else Rect2(12, 5, 52, 52)
		if hero.can_learn(slot) and _press_pos.distance_to(Vector2(ir.end.x - 9.0, ir.end.y - 9.0)) <= 22.0:
			return false   # 按在「+」上 → 是学习，不是施放
		var ad: Dictionary = hud.battle.ability_def(String(s["id"]))
		if not bool(ad.get("targeted", false)):
			return false   # 非指向技：松手即放(走 _execute)，无需瞄准
		return hero.slot_ready(slot)

	func _gui_input(event: InputEvent) -> void:
		if hud == null or not hud.touch_ui:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_execute(event.position)   # 桌面：按下即执行（指向技会进入 armed，再点地图）
				accept_event()
			return
		# 触屏：①按下技能→若是指向技立刻 arm 并瞄准 ②拖动→准星跟手指 ③松手→拖出去就在落点放、原地点则保持 armed 等点地图
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_held = true
				_press_ms = Time.get_ticks_msec()
				_press_pos = event.position
				_aiming = false
				if _can_aim_cast():
					hud.battle.cast_ability(hero, slot)   # arm 指向技
					if hud.battle._ability_armed != "":
						_aiming = true
						if hud.battle.overlay != null:
							hud.battle.overlay.queue_redraw()
			else:
				_held = false
				if _tip_shown:
					_tip_shown = false
					_on_hover_out()
				elif _aiming:
					# 拖出按钮(到战斗画面)再松手 → 在手指落点放招；原地点(没拖)→保持 armed，玩家接着点地图放
					if _press_pos.distance_to(event.position) > 24.0 and hud.battle._ability_armed != "":
						hud.battle._cast_armed_at(hud.battle.get_global_mouse_position())
					_aiming = false
				else:
					_execute(_press_pos)
			accept_event()
		elif event is InputEventMouseMotion and _held and _aiming:
			if hud.battle != null and hud.battle.overlay != null:
				hud.battle.overlay.queue_redraw()   # 准星跟手指(指示器用 get_global_mouse_position 实时定位)
			accept_event()


## 触屏英雄快切 chip（左缘竖排）：点头像 = 选中并居中该英雄（轻操作式随时跳到英雄放招走位）。
class HeroChip extends Control:
	var hud = null
	var hero: Unit = null

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(_d: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if hud != null and hud.battle != null and is_instance_valid(hero):
				if hero.garrisoned:
					hud.battle.sortie_unit(hero)   # 驻军英雄 → 点头像出击
				else:
					hud.battle.focus_unit(hero)    # 在场英雄 → 选中并居中
			accept_event()

	func _draw() -> void:
		if not is_instance_valid(hero):
			return
		var f := ThemeDB.fallback_font
		var garr: bool = hero.garrisoned
		var sel: bool = hud != null and hud.battle != null and hud.battle.selection.has(hero)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.08, 0.05, 0.95))
		var border := Color("ffd866") if sel else Color(0.5, 0.42, 0.26)
		if garr:
			border = Color("7f9bff")   # 驻军中：靛蓝描边，与「驻军光标」同色系
		elif hero.auto_micro:
			border = Color(0.42, 0.85, 0.48)   # 托管中：绿描边
		draw_rect(Rect2(Vector2.ZERO, size), border, false, 4.0 if (sel or garr or hero.auto_micro) else 3.0)
		var ir := Rect2(3, 3, size.x - 6, size.y - 15)
		var tex: Texture2D = Art.avatar_texture(hero.key)   # 脸→走图→…回退，公孙胜无专属头像时也有图（不画空白首字）
		if tex != null:
			draw_texture_rect(tex, ir, false, Color(0.55, 0.6, 0.85) if garr else Color.WHITE)
		else:
			draw_string(f, Vector2(0, size.y * 0.52), hero.display_name.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("ffe9a8"))
		# 驻军徽标：左上「驻」+ 底部「点击出击」提示，让玩家知道这头像现在是出击键
		if garr:
			draw_rect(ir, Color(0.10, 0.13, 0.28, 0.42))
			draw_string(f, Vector2(5, 22), "驻", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("cfe0ff"))
			draw_string(f, Vector2(0, size.y - 16), "▶出击", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color("cfe0ff"))
		# 托管徽标：绿底「托管」横幅压在头像顶部，一眼可辨哪些英雄在托管
		if hero.auto_micro:
			draw_rect(Rect2(3, 3, size.x - 6, 17), Color(0.10, 0.34, 0.15, 0.92))
			draw_string(f, Vector2(3, 16), "托管", HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, 13, Color(0.80, 1.0, 0.84))
		var frac := clampf(hero.hp / hero.max_hp, 0.0, 1.0)
		draw_rect(Rect2(3, size.y - 10, size.x - 6, 7), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(3, size.y - 10, (size.x - 6) * frac, 7), Color(0.3, 0.85, 0.3).lerp(Color(0.85, 0.2, 0.15), 1.0 - frac))


## 触屏编队 chip：点=调出该队，长按(≥450ms)=把当前选中设为该队。点亮=该队有兵。
class TouchChip extends Control:
	var hud = null
	var num := 1
	var _down := false
	var _press_ms := 0

	func _init() -> void:
		custom_minimum_size = Vector2(68, 68)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(_d: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if event.pressed:
			_down = true
			_press_ms = Time.get_ticks_msec()
		elif _down:
			_down = false
			if hud != null and hud.battle != null:
				var held := Time.get_ticks_msec() - _press_ms
				if held >= 450:
					hud.battle._assign_group(num)    # 长按 = 把当前选中设为该队
				else:
					hud.battle._recall_group(num)    # 点 = 调出该队
		accept_event()

	func _draw() -> void:
		var n := 0
		if hud != null and hud.battle != null:
			n = hud.battle.group_size(num)
		var lit := n > 0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.14, 0.08, 0.95) if lit else Color(0.10, 0.09, 0.07, 0.72))
		draw_rect(Rect2(Vector2.ZERO, size), Color("ffd866") if lit else Color(0.4, 0.36, 0.28), false, 2.0)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, size.y * 0.58), str(num), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32,
			Color("ffe9a8") if lit else Color(0.55, 0.5, 0.4))
		if lit:
			draw_string(f, Vector2(0, size.y - 6), "%d兵" % n, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.8, 0.85, 0.7))
