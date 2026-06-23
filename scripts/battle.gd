class_name Battle
extends Node2D
## 通用战斗运行器：加载一个 LevelBase 关卡，提供地图/单位/相机/HUD 与全部通用系统
## （框选指挥、攻击移动、英雄技能、编队、光环、芦苇隐蔽、分离避让、动画）。
## 关卡专属内容（地图布局、部署、波次、机制、胜负）由 level 钩子驱动。

enum Phase { INTRO, DEPLOY, FIGHT, END }

var level: LevelBase
var _defs := {}
var _abilities := {}

var world: Node2D
var map: GameMap
var hud: HUD
var camera: RTSCamera
var units_root: Node2D
var fx_root: Node2D
var overlay: Node2D

# AI友好模式（驻守战）：开则敌方小兵×3(在 skirmish 出兵处生效) + 全员托管后自动镜头巡战场
var ai_friendly := false
var _autocam_enabled := false          # 玩家是否点了「自动镜头」按钮开启（全托管后左下角出现该按钮）
var _autocam_active := false           # 当前是否正由自动镜头接管
var _autocam_dwell := 0.0              # 当前机位已停留秒数（≥AUTOCAM_DWELL 才重选）
var _autocam_target_pos := Vector2.ZERO   # 目标镜头中心(屏幕/iso 空间)
var _autocam_target_zoom := 1.1        # 目标缩放
var _autocam_focus := Vector2.INF      # 当前聚焦战团中心(逻辑坐标)，用于跨帧判定战团是否还在
var _autocam_review_idx := 0           # 检阅模式：当前轮到第几名英雄
var _autocam_review_unit: Unit = null  # 检阅模式：正在跟拍的英雄（非空=检阅中，每帧跟随其走位）
const AUTOCAM_DWELL := 2.4             # 每个机位至少停留秒数（>2s，避免切太勤眼花）
const AUTOCAM_HOT_R := 224.0           # 战团聚合半径(px) ≈ 7 格
const AUTOCAM_REVIEW_ZOOM := 1.5       # 检阅我方英雄时的近景缩放（比战斗略近，看清人物）

# 全托管经济 AI（auto_micro_level>=3）：喽啰自动采集/建造/修复 + 自动练兵练将研究 + 自动开战
# 策略（用户定）：优先出齐英雄(AoE 打 3× 群)，再升级基地/造兵/科技/箭楼。
var _eco_t := 0.0
var _eco_deploy_t := 0.0
var _eco_started := false              # 是否已自动开战
const ECO_MAX_SITES := 2              # 同时在建的工地数（并行施工，盖得快、补得上被拆的）
const ECO_BOOT_WORKERS := 4           # 出英雄阶段的最低农民数（起手已有5个，通常一个都不补→不抢聚义厅队列，英雄连着出）
const ECO_PRE_HERO_POP := 30          # 出英雄前先铺到的人口上限（容 6 英雄=18 口 + 几个农民即可，别多盖民居拖时间）
const ECO_WCAP := 6                    # 出齐英雄后的农民目标数（少养农民，人口/钱留给军队）
const ECO_GOLD_MINERS := 4            # 金矿工目标（贴仓库·采矿效率 max），其余伐木
const ECO_ARMY_CAP := 40              # 兵营常备军上限（不含英雄/农民）
# 经济建筑(仓库/民居/集市)堆在金矿后方(安全角，远离东侧出兵口)护住人口；兵营/箭楼在聚义厅前沿御敌。
const ECO_MAINT := [["depot", 1, "gold"], ["barracks", 2, "hall"], ["market", 1, "gold"], ["house", 8, "gold"], ["arrow_tower", 7, "hall"]]
const ECO_HERO_ORDER := ["song_jiang", "hua_rong", "lin_chong", "gongsun_sheng", "li_kui", "wu_song"]

var units: Array = []
var selection: Array = []
var phase := Phase.INTRO
var kills := 0
var hero_kills := {}          # 按英雄统计歼敌：instance_id -> {name, key, n}（战后结算展示）
var hero_progress := {}        # 英雄战死存档：key -> {level,xp,sp,ranks}（聚义厅重练后恢复，不从1级重来）
var lit_cells := {}          # 关卡高亮格（如盘陀路指路）：Vector2i -> 剩余秒

# 经济（自由「遭遇战」模式；战役关卡 economy=false，下列全部不参与）
var economy := false
var gold := 0
var wood := 0
var pop_cap := 0
var current_age := 1    # 玩家时代：1草莽 / 2聚义 / 3替天行道（聚义厅研究升代；门槛 min_age 过滤菜单）
var faction_res := {}   # 非玩家阵营的私有钱粮池 {faction: {gold, wood}}（1v1 里 AI 官军用，与玩家互不串账）
var faction_gather_mult := {}   # 非玩家阵营的采集系数 {faction: float}（难度手感：易<1、普=1 对等、难>1）
# 科技升级（已研究项 + 全局加成）
var _tech_done := {}
var tech_atk := 1.0
var tech_hp := 1.0
var tech_gather := 1.0

# 战争迷雾
var fog := false
var _vision: PackedByteArray       # 每格 0=未探索 1=已探索(阴影) 2=明亮(正看 + 离开后驻留)
var _vis_t: PackedFloat32Array     # 每格「明亮」驻留剩余秒数：离开视野后仍亮 SIGHT_LINGER 秒再退阴影
var _sight_now: PackedByteArray    # 本次 pass 是否真正在某单位视野内（复用，免每帧重分配）
var _vision_img: Image
var _fog_tex: ImageTexture
var _fog_layer: Node2D
var _fog_t := 0.0
const SIGHT_LINGER := 30.0          # 视野延时：单位离开后，已照亮区域保持明亮 30 秒再变回阴影

var _dragging := false
var _drag_from := Vector2.ZERO
var _click_fx_pos := Vector2.ZERO
var _click_fx_t := 0.0
var _click_fx_attack := false
var _amove_armed := false
var _repair_armed := false     # 武装维修：点己方受损建筑即派工人修缮
var _garrison_armed := false   # 武装驻扎：英雄「驻扎」键点亮后，左键点己方建筑即进驻
var _ability_armed := ""
var _ability_caster: Unit = null
var _ground_dots: Array = []   # 活动的地面烈焰 DOT：{pos,r,foe,caster,t,tick_t,tick,per}
var _chrono_zones: Array = []  # 时空封印立场：{pos,r,foe,t}——每帧把域内敌军续晕（林冲 R）
var _orbit_zones: Array = []   # 双斧回旋扫伤区：{caster,foe,r,t,tick,tick_t,dmg,slow,slow_dur}（李逵 Q）
var _ice_walls: Array = []     # 冰墙阻挡：{cells:[Vector2i],t}——到期解锁格子（公孙胜 W）
var _pending_casts: Array = []  # 施法抬手·待结算队列：{caster,slot,lp}——抬手归零后才真正放招
const CAST_WINDUP := 0.34       # 施法抬手时长（秒）：先抬手蓄势，再结算技能
# 技能音效：先按技能 id 取签名音（标志性技能各有其声），否则按 effect.kind 取类型音，再退 "cast"
const ABILITY_SFX_ID := {
	"hua_rain": "sk_rain", "lin_chrono": "sk_chrono", "hua_blink": "sk_blink",
	"li_charge": "sk_charge", "li_fury": "sk_fury", "li_axes": "sk_axes",
	"lin_thrust": "sk_thrust", "lin_sweep": "sk_sweep",
	"song_rally": "sk_rally", "song_fire": "sk_fire", "song_haste": "sk_haste",
}
const ABILITY_SFX_KIND := {
	"rally": "sk_rally", "haste": "sk_haste", "smite": "sk_smite",
	"debuff": "sk_debuff", "drag": "sk_drag", "fire_dot": "sk_fire",
	"line_nuke": "sk_thrust", "blink_shot": "sk_blink", "orbit_axes": "sk_axes",
	"charge": "sk_charge", "chrono": "sk_chrono", "self_buff": "sk_fury",
	"path": "sk_blink", "weapon_toggle": "sk_swap", "sector_nuke": "sk_sweep",
}
var _ability_slot := 0
var _build_armed := ""        # 待放置的建筑 key（遭遇战建造）
var _active: Unit = null      # 当前子组「活动单位」（Tab 切换；命令卡/QWER 针对它）
var _inspect_unit: Unit = null  # 「查看中」的敌方单位（只读：显示信息+高亮，但不进 selection、不可下令）
var _demolish_armed_t := 0.0  # 拆除已成型建筑的二次确认计时
var _alert_t := 0.0           # 遭袭告警计时（小地图闪烁）
var _alert_pos := Vector2.ZERO
var _idle_i := 0              # 闲置喽啰轮询索引
var _groups := {}
var _last_group_key := -1
var _last_group_time := 0
var _smoke := false
var _smoke_t := 0.0
var _touch_mode := false   # 触摸屏模式（一旦收到触摸事件即开启触摸交互：轻点选取、长按下令）
var _press_ms := 0         # 左键/单指按下的时刻
var _box_mode := false     # 触屏：长按原地后进入「框选」态（再拖动拖出选择框）
var _panning := false      # 触屏：单指拖动地图中
var _drag_cur := Vector2.ZERO   # 触屏：当前手指位置
var _last_tap_ms := 0      # 触屏双击检测
var _last_tap_pos := Vector2.ZERO
var _target_cursor: ImageTexture   # 攻击/施法指向时的「圈中带点」鼠标
var _cur_attack: ImageTexture
var _cur_gather_wood: ImageTexture
var _cur_gather_gold: ImageTexture
var _cur_repair: ImageTexture
var _cur_select: ImageTexture
var _cur_garrison: ImageTexture   # 驻军：靛蓝环+拱门，提示「点这进驻」
var _hover_kind := "normal"


func _ready() -> void:
	level = _resolve_level()
	_defs = Defs.UNITS.duplicate(true)
	_abilities = Defs.ABILITIES.duplicate(true)
	Defs.apply_content_pack(_defs, _abilities)   # 内容包覆盖（res://content/*.json，无则不变）
	Art.set_runtime_alias({})                    # 清掉上局的运行时借图别名
	if level.has_method("apply_overrides"):
		level.apply_overrides(_defs, _abilities)   # 关卡级覆盖（场景编辑器：仅本场景的单位/技能改动）

	economy = level.economy_enabled()
	if economy:
		gold = level.start_gold()
		wood = level.start_wood()
		pop_cap = level.base_pop_cap()
		current_age = level.start_age() if level.has_method("start_age") else 3
	fog = level.fog_enabled()

	world = Node2D.new()
	world.transform = GameMap.ISO
	add_child(world)

	map = GameMap.new()
	world.add_child(map)
	map.init_map(level.map_w(), level.map_h(), level.map_theme(), level.map_base())
	level.paint_map(map)
	map.bake()
	level.decorate(map)
	_build_dapple()   # 地面斑驳光影（云隙阳光）：打破大片纯绿的平板感，叠在地形之上、单位之下

	units_root = Node2D.new()
	units_root.y_sort_enabled = true
	world.add_child(units_root)

	fx_root = Node2D.new()
	world.add_child(fx_root)

	if fog:
		_init_fog()

	overlay = Overlay.new()
	overlay.b = self
	add_child(overlay)

	camera = RTSCamera.new()
	# 相机限制 = 地图等距投影包围盒 + 四周余量，可滚到地图边缘「之外」一截，
	# 边角单位不至于卡在屏幕边；底部再多留一个面板高度，好把地图下沿拉到面板上方。
	var mw := float(map.w * GameMap.CELL)
	var mh := float(map.h * GameMap.CELL)
	var margin := 540.0
	camera.limit_left = int(-mh - margin)
	camera.limit_top = int(-margin)
	camera.limit_right = int(mw + margin)
	camera.limit_bottom = int((mw + mh) * 0.5 + margin + RTSCamera.PANEL_H)
	add_child(camera)
	ai_friendly = Campaign.ai_friendly   # AI友好模式：敌方小兵×3 + 全员托管自动镜头
	_autocam_target_zoom = camera.zoom.x

	_build_atmosphere()   # 后期处理层：暗角 + 暖色调 + 对比/饱和（在世界之上、HUD 之下）
	add_child(AmbientMotes.new())   # 空气中缓缓飘动的暖色微尘（阳光浮尘），叠在调色之上

	hud = HUD.new()
	hud.start_battle.connect(_on_start_battle)
	hud.intro_done.connect(_on_intro_done)
	hud.restart.connect(func() -> void: get_tree().paused = false; get_tree().reload_current_scene())
	hud.to_menu.connect(func() -> void: get_tree().paused = false; _goto_menu())
	hud.resume_game.connect(_close_pause)
	hud.quit_game.connect(func() -> void: get_tree().paused = false; get_tree().quit())
	add_child(hud)
	hud.setup(self)
	_install_target_cursor()

	level.deploy(self)

	camera.position = to_screen(map.cell_to_world(level.camera_start_cell()))
	hud.set_top("%s · %s" % [level.title(), level.subtitle()])

	if OS.get_environment("SMOKE_TEST") == "1":
		_smoke = true
		Engine.time_scale = 6.0
		phase = Phase.DEPLOY
		_group_selftest()
		_ability_selftest()
		_on_start_battle()
		_economy_selftest()
		_hover_selftest()
		if OS.get_environment("NEWHERO") == "1":
			_newhero_selftest()
		if OS.get_environment("ARMOR_TEST") == "1":
			_armor_selftest()
		if OS.get_environment("AUTOMICRO") == "1":
			_automicro_selftest()
		if OS.get_environment("AUTOCAM") == "1":
			_autocam_selftest()
	else:
		Engine.time_scale = Settings.game_speed   # 实时节奏（设置可调慢/正常/快）：技能冷却/建造/训练/波次按倍率走时
		hud.show_intro(level.intro_lines())
	if OS.get_environment("SCREENSHOT_DIR") != "":
		_screenshot_loop(OS.get_environment("SCREENSHOT_DIR"))
	if OS.get_environment("BUILD_TEST") == "1":
		await _build_test()


func _build_test() -> void:
	Engine.time_scale = 1.0
	await get_tree().process_frame
	gold += 1000
	wood += 1000
	var c := level.camera_start_cell()
	var wkr := spawn_unit("lou_luo", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(c + Vector2i(-4, 0))))
	_set_selection([wkr])
	var half := building_footprint_half("house")
	var hcell := map.nearest_open(c + Vector2i(4, 0))
	for r in range(4, 10):
		var cand := c + Vector2i(r, 0)
		if map.area_buildable(cand, half) and not _building_overlap(cand, half):
			hcell = cand
			break
	arm_build("house")
	_try_place_building(to_screen(map.cell_to_world(hcell)))
	for t in range(22):
		await get_tree().create_timer(1.0).timeout
		var site: Unit = null
		for u in units:
			if is_instance_valid(u) and u.key == "house":
				site = u
				break
		if site == null:
			print("[build] t=%d house gone" % t)
			break
		print("[build] t=%d prog=%.1f/%.1f hp=%d con=%s d=%.0f st=%d" % [t, site.build_progress,
			site.build_time, int(site.hp), site.is_constructing, wkr.position.distance_to(site.position), wkr._state])
		if not site.is_constructing:
			print("[build] COMPLETE t=%d" % t)
			break
	# 再造一座箭楼并完成，然后持续观察 18 秒：建筑/箭楼造完后会不会自己消失
	var w2 := spawn_unit("lou_luo", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(c + Vector2i(-3, 3))))
	_set_selection([w2])
	var th := building_footprint_half("arrow_tower")
	var tcell := map.nearest_open(c + Vector2i(2, 5))
	for r in range(2, 9):
		var cand := c + Vector2i(r, 5)
		if map.area_buildable(cand, th) and not _building_overlap(cand, th):
			tcell = cand
			break
	arm_build("arrow_tower")
	_try_place_building(to_screen(map.cell_to_world(tcell)))
	for t in range(40):
		await get_tree().create_timer(1.0).timeout
		var house_n := units.filter(func(u: Unit) -> bool: return is_instance_valid(u) and u.key == "house").size()
		var tower: Unit = null
		for u in units:
			if is_instance_valid(u) and u.key == "arrow_tower":
				tower = u
				break
		var twr := "gone" if tower == null else ("con" if tower.is_constructing else "DONE hp=%d" % int(tower.hp))
		print("[persist] t=%d house_in_units=%d tower=%s" % [t, house_n, twr])
		if tower != null and not tower.is_constructing and t > 25:
			break
	get_tree().quit()


func _resolve_level() -> LevelBase:
	if Engine.has_singleton("Campaign") or get_node_or_null("/root/Campaign") != null:
		var camp = get_node_or_null("/root/Campaign")
		if camp != null:
			return camp.make_level()
	# 回退：默认第5关
	return load("res://scripts/levels/level5_liangshan.gd").new()


func _goto_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


## 安卓系统「返回键」：开/关暂停菜单——而非默认「直接退出 app」(被当成闪退)。
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud != null and hud._pause_root != null and hud._pause_root.visible:
			_close_pause()
		else:
			_open_pause()


func _open_pause() -> void:
	if phase == Phase.END or phase == Phase.INTRO:
		return
	get_tree().paused = true
	hud.show_pause()


func _close_pause() -> void:
	get_tree().paused = false
	if phase != Phase.END:
		Engine.time_scale = Settings.game_speed   # 恢复对战时套用最新游戏速度（设置改了即生效）
	hud.hide_pause()


## ---------- 关卡可用的辅助 API ----------

func to_screen(p: Vector2) -> Vector2:
	return GameMap.ISO * p


func to_logic(p: Vector2) -> Vector2:
	return GameMap.ISO_INV * p


func spawn_unit(key: String, faction: int, world_pos: Vector2) -> Unit:
	var u := Unit.new()
	units_root.add_child(u)
	u.setup(key, _defs[key], faction, self, map)
	if u.ability != "" and _abilities.has(u.ability):
		u.ability_cd = _abilities[u.ability]["cd"]
	if economy and tech_hp != 1.0 and faction == Unit.FACTION_LIANG and not u.is_building and not u.is_hero:
		u.max_hp *= tech_hp
		u.hp = u.max_hp
	u.position = world_pos
	u.died.connect(_on_unit_died)
	units.append(u)
	return u


func spawn_at(key: String, faction: int, cell: Vector2i) -> Unit:
	return spawn_unit(key, faction, map.cell_to_world(map.nearest_open(cell)))


## 成批生成敌军并向目标 attack-move（波次用）。返回生成的单位数组。
func spawn_group(key: String, n: int, faction: int, gate: Vector2i, target_w: Vector2, spread := 2) -> Array:
	var out: Array = []
	for i in range(n):
		var cell := map.nearest_open(gate + Vector2i(randi_range(-spread, spread), randi_range(-spread, spread)))
		var u := spawn_unit(key, faction, map.cell_to_world(cell))
		u.order_amove(target_w + Vector2(randf_range(-70, 70), randf_range(-70, 70)))
		out.append(u)
	return out


func units_of(faction: int, key := "") -> Array:
	return units.filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0 and u.faction == faction and (key == "" or u.key == key))


func count_alive(faction: int, key := "") -> int:
	return units_of(faction, key).size()


func find_unit(key: String) -> Unit:
	for u in units:
		if is_instance_valid(u) and u.key == key and u.hp > 0.0:
			return u
	return null


func hero_alive(key: String) -> bool:
	return find_unit(key) != null


func players_alive() -> int:
	return units.filter(func(u) -> bool:
		return is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building and u.hp > 0.0).size()


func enemies_alive() -> int:
	return units.filter(func(u) -> bool:
		return is_instance_valid(u) and u.faction == Unit.FACTION_GUAN and not u.is_building and u.hp > 0.0).size()


func msg(text: String, dur := 3.5) -> void:
	hud.show_message(text, dur)


func set_top(text: String) -> void:
	hud.set_top(text)


func center_camera_cell(cell: Vector2i) -> void:
	camera.position = to_screen(map.cell_to_world(cell))


func win(line: String) -> void:
	_end(true, line)


func lose(line: String) -> void:
	_end(false, line)


func spawn_projectile(from: Unit, target: Unit, dmg: float, crit := false, splash := 0.0) -> void:
	var p := Projectile.new()
	fx_root.add_child(p)
	p.position = from.position + Vector2(0, -4)
	p.splash = splash
	p.setup(from, target, dmg, crit)


## 近战命中火花（heavy=斧/重击更大）
func spawn_impact(lp: Vector2, heavy := false) -> void:
	var fx := HitSpark.new()
	fx.position = lp + Vector2(0, -6)
	fx.heavy = heavy
	fx_root.add_child(fx)


## 屏震（相机偏移抖动）。只在画面可见区域附近才震，免得远处交战晃屏。
func shake(amount: float, at := Vector2.INF) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if at != Vector2.INF:
		# camera.position 是视图中心（iso 屏幕空间）；偏移超出半屏的 ~0.7 倍则不震
		var off := to_screen(at) - camera.position
		var rect := get_viewport().get_visible_rect()
		if off.length() > rect.size.length() * 0.7 / camera.zoom.x:
			return
	camera.add_shake(amount)


## 飘字伤害（fx 层）。crit=暴击放大变色；on_player=落在己方单位上（偏红警示）。
func spawn_damage(lp: Vector2, amount: float, crit := false, on_player := false) -> void:
	if amount < 1.0 or not Settings.show_damage:
		return
	var fl := FloatLabel.new()
	fl.position = lp + Vector2(0, -float(radius_hint()))
	fl.amount = int(round(amount))
	fl.crit = crit
	fl.on_player = on_player
	fx_root.add_child(fl)


func radius_hint() -> int:
	return 26


func ability_def(id: String) -> Dictionary:
	return _abilities.get(id, {})


## 遭袭告警（被多处调用，内部节流）：小地图闪烁 + 音效 + 提示
func alert(pos: Vector2) -> void:
	_alert_pos = pos
	if _alert_t <= 0.0:
		msg("⚠ 寨子遭到攻击！", 2.0)
	_alert_t = 2.0
	Sfx.play("alert", 0.0, 0.0, 6000)


## 英雄升级金光
func spawn_levelup(lp: Vector2) -> void:
	_spawn_ability_fx(lp, 52.0, Color("ffe066"))
	Sfx.play("levelup", 0.0, 0.02, 300)


## ---------- 经济（遭遇战）----------

func can_afford(g: int, w: int) -> bool:
	return gold >= g and wood >= w


func spend(g: int, w: int) -> bool:
	if not can_afford(g, w):
		return false
	gold -= g
	wood -= w
	return true


func add_resources(g: int, w: int, faction := Unit.FACTION_LIANG) -> void:
	# 玩家(梁山)用主资源池 gold/wood；其它阵营(如 AI 官军)各自记在 faction_res 私池里，
	# 让 1v1 双方经济互不串账（工人卸货按自己阵营进自己的库）。默认阵营=玩家，保持原有调用不变。
	if faction == Unit.FACTION_LIANG:
		gold += g
		wood += w
		return
	if not faction_res.has(faction):
		faction_res[faction] = {"gold": 0.0, "wood": 0.0}
	faction_res[faction]["gold"] = maxf(0.0, float(faction_res[faction]["gold"]) + float(g))
	faction_res[faction]["wood"] = maxf(0.0, float(faction_res[faction]["wood"]) + float(w))


## 某阵营当前金/木（玩家=主池；其它=私池）。供 AI/HUD 读取。
func faction_gold(faction: int) -> float:
	if faction == Unit.FACTION_LIANG:
		return float(gold)
	return float(faction_res.get(faction, {}).get("gold", 0.0))


func faction_wood(faction: int) -> float:
	if faction == Unit.FACTION_LIANG:
		return float(wood)
	return float(faction_res.get(faction, {}).get("wood", 0.0))


func faction_can_afford(faction: int, g: int, w: int) -> bool:
	return faction_gold(faction) >= float(g) and faction_wood(faction) >= float(w)


## 从某阵营私池扣费（玩家走 spend）。成功返回 true。
func faction_spend(faction: int, g: int, w: int) -> bool:
	if not faction_can_afford(faction, g, w):
		return false
	if faction == Unit.FACTION_LIANG:
		gold -= g
		wood -= w
		return true
	faction_res[faction]["gold"] = float(faction_res[faction]["gold"]) - float(g)
	faction_res[faction]["wood"] = float(faction_res[faction]["wood"]) - float(w)
	return true


## 已占人口：玩家方非建筑单位的 pop 之和（默认每个 1）
func used_pop() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building and u.hp > 0.0:
			n += int(u.setup_def.get("pop", 1))
	return n


## 最近的资源点（kind 限定金/木；空=不限）
func nearest_resource(p: Vector2, kind := "") -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if is_instance_valid(u) and u.is_resource and u.res_left > 0.0 and (kind == "" or u.res_kind == kind):
			var d: float = p.distance_to(u.position)
			if d < bd:
				bd = d
				best = u
	return best


## 最近的「空闲」金矿（矿口没有别的农民在采），用于独占模式下自动分流。无空闲则返回 null（原地等）。
func nearest_free_gold(p: Vector2, exclude: Unit, w: Unit) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if not is_instance_valid(u) or not u.is_resource or u.res_kind != "gold" or u.res_left <= 0.0:
			continue
		if u == exclude or u.gold_busy(w):
			continue
		var d: float = p.distance_to(u.position)
		if d < bd:
			bd = d
			best = u
	return best


## 最近的卸货点（指定阵营、带 drop_off 标记的建筑：聚义厅/仓库；默认玩家）
func nearest_dropoff(p: Vector2, faction := Unit.FACTION_LIANG) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if is_instance_valid(u) and u.is_building and u.hp > 0.0 and u.faction == faction \
				and not u.is_constructing and u.setup_def.get("drop_off", false):
			var d: float = p.distance_to(u.position)
			if d < bd:
				bd = d
				best = u
	return best


## 资源点采空：移出并释放
func deplete_resource(node: Unit) -> void:
	units.erase(node)
	selection.erase(node)
	if is_instance_valid(node):
		node.queue_free()


## ---------- 建造 ----------

## 命令卡·建造菜单：从 defs 派生「可建造建筑」（带 buildable 标记的都自动上菜单，
## 顺序按 build_order）——这样内容包加新建筑无需改引擎。时代未到的不显示。
func build_menu() -> Array:
	var keys: Array = []
	for key in _defs:
		if bool(_defs[key].get("buildable", false)):
			keys.append(key)
	keys.sort_custom(func(a: String, b: String) -> bool:
		var oa := int(_defs[a].get("build_order", 99))
		var ob := int(_defs[b].get("build_order", 99))
		return oa < ob if oa != ob else a < b)
	var out: Array = []
	for key in keys:
		var d: Dictionary = _defs.get(key, {})
		if int(d.get("min_age", 1)) > current_age:
			continue   # 时代未到 → 不显示（攻城作坊需替天行道代）
		var cg := int(d.get("cost_gold", 0))
		var cw := int(d.get("cost_wood", 0))
		out.append({"key": key, "label": String(d.get("name", key)),
			"cost_g": cg, "cost_w": cw, "affordable": can_afford(cg, cw)})
	return out


## 主基地建筑（带 is_main_base 标记，回退到 key=="hall"）：引擎里"退守基地""默认卸货点"等用。
## 让引擎不写死 水浒 的"聚义厅"键——内容包把自己的主基地标 is_main_base 即可。
func main_base(p_faction := Unit.FACTION_LIANG) -> Unit:
	for u in units:
		if is_instance_valid(u) and u.is_building and u.hp > 0.0 and u.faction == p_faction \
				and (bool(u.setup_def.get("is_main_base", false)) or u.key == "hall"):
			return u
	return null


## 集市贸易菜单：木↔金互换（固定汇率含价差，反经济卡死：矿采空也能换金练兵）
const TRADE_AMT := 100
const TRADE_GET := 70

func trade_menu(_bld: Unit) -> Array:
	return [
		{"kind": "trade", "give": "wood", "label": "卖木换金", "cost_g": 0, "cost_w": TRADE_AMT,
			"affordable": wood >= TRADE_AMT, "sub": "%d 木 → %d 金" % [TRADE_AMT, TRADE_GET]},
		{"kind": "trade", "give": "gold", "label": "卖金换木", "cost_g": TRADE_AMT, "cost_w": 0,
			"affordable": gold >= TRADE_AMT, "sub": "%d 金 → %d 木" % [TRADE_AMT, TRADE_GET]},
	]


func do_trade(give: String) -> void:
	if give == "wood":
		if wood < TRADE_AMT:
			Sfx.play("cant"); return
		wood -= TRADE_AMT
		add_resources(TRADE_GET, 0)
	else:
		if gold < TRADE_AMT:
			Sfx.play("cant"); return
		gold -= TRADE_AMT
		add_resources(0, TRADE_GET)
	Sfx.play("complete", -4.0, 0.04, 120)


func building_footprint_half(key: String) -> int:
	return GameMap.footprint_half_for(float(_defs.get(key, {}).get("radius", 24)))


## 建筑「可点半径」：跟视觉贴图同宽（GameMap.building_visual_px 的一半），否则视觉放大后点不到边缘——
## 选取/驻军/修理全用它，让整个看得见的建筑都能点中。
func _bld_click_r(u: Unit) -> float:
	var vis := GameMap.building_visual_px(GameMap.footprint_half_for(u.radius))
	return maxf(u.radius + 16.0, vis * 0.5)


## 该格放置的建筑是否会压到（或紧贴到）别的建筑：用占地 AABB 各向外扩 1 格判定，
## 确保两座建筑之间至少留一格缝、贴图屋檐不相叠（防止把箭塔造进聚义厅那种重叠）。
## 关卡预置建筑（如聚义厅）spawn 时未登记 fcell/占地，故这里一律由 position+radius 现算占地，
## 不依赖 area_buildable 的寻路 solid 判定——后者对预置建筑并不封格。
func _building_overlap(cell: Vector2i, half: int) -> bool:
	for u in units:
		if not (is_instance_valid(u) and u.is_building and not u.is_resource and u.hp > 0.0):
			continue
		var bc: Vector2i = u.get_meta("fcell", map.world_to_cell(u.position))
		var bh: int = int(u.get_meta("fhalf", GameMap.footprint_half_for(u.radius)))
		if cell.x - half - 1 <= bc.x + bh and cell.x + half + 1 >= bc.x - bh \
				and cell.y - half - 1 <= bc.y + bh and cell.y + half + 1 >= bc.y - bh:
			return true
	return false


func arm_build(key: String) -> void:
	if not _defs.get(key, {}).get("buildable", false):
		return
	_disarm_ability()
	_disarm_amove()
	_build_armed = key
	# 触屏：先把虚影摆到视图中心，玩家再拖动定位、松手落地（见 _unhandled_input 触屏分支）。
	if hud != null and hud.touch_ui:
		_drag_cur = camera.get_screen_center_position() if is_instance_valid(camera) else get_global_mouse_position()
		msg("拖动选址 → 松手建造（点「取消」放弃）", 2.0)
	Sfx.play("click")
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _cancel_build() -> void:
	_build_armed = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _try_place_building(p: Vector2) -> void:
	var key := _build_armed
	var d: Dictionary = _defs.get(key, {})
	var cell := map.world_to_cell(to_logic(p))
	var half := building_footprint_half(key)
	if not map.area_buildable(cell, half):
		msg("此处无法建造（地形不平或已被占用）", 1.5)
		return
	if _building_overlap(cell, half):
		msg("太靠近其它建筑了，不能压在上面", 1.5)
		Sfx.play("cant")
		return
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if not can_afford(cg, cw):
		msg("资源不足：需 金%d 木%d" % [cg, cw], 1.5)
		Sfx.play("cant")
		return
	spend(cg, cw)
	Sfx.play("build")
	_start_construction(key, cell, half)
	if not Input.is_key_pressed(KEY_SHIFT):   # 按住 Shift 连续放置
		_cancel_build()


func _start_construction(key: String, cell: Vector2i, half: int) -> void:
	var site := spawn_unit(key, Unit.FACTION_LIANG, map.cell_to_world(cell))
	site.is_constructing = true
	site.build_progress = 0.0
	site.hp = site.max_hp * 0.1
	site.set_meta("fcell", cell)
	site.set_meta("fhalf", half)
	map.block_footprint(cell, half, true)
	var builders := selection.filter(func(u) -> bool:
		return is_instance_valid(u) and u.is_worker and u.hp > 0.0)
	# 按住 Shift 连续放置时，建造令排队（工人逐座建过去），而不是只建最后一座
	var queued := Input.is_key_pressed(KEY_SHIFT)
	for wkr in builders:
		wkr.order_build(site, queued)
	msg("开始建造 %s" % String(_defs[key].get("name", key)), 1.5)


## AI 真实建造：在 cell 起一座 faction 阵营的工地（10% 血、占地封路），派 builder 工人去建。
## 与玩家 _start_construction 同机制（工人 advance_build → 完工 on_building_complete），只是阵营/工人由调用方指定。
func ai_start_construction(key: String, cell: Vector2i, faction: int, builder: Unit) -> Unit:
	var half := building_footprint_half(key)
	var site := spawn_unit(key, faction, map.cell_to_world(cell))
	site.is_constructing = true
	site.build_progress = 0.0
	site.hp = site.max_hp * 0.1
	site.set_meta("fcell", cell)
	site.set_meta("fhalf", half)
	map.block_footprint(cell, half, true)
	if is_instance_valid(builder):
		builder.order_build(site)
	return site


func on_building_complete(b: Unit) -> void:
	var pp := int(b.setup_def.get("provides_pop", 0))
	if pp > 0 and b.faction == Unit.FACTION_LIANG:   # 人口上限只随玩家建筑增长；AI 人口由其关卡自行记账
		pop_cap += pp
	if b.faction == Unit.FACTION_LIANG:
		msg("%s 建造完成！" % b.display_name, 2.0)
		Sfx.play("complete", 0.0, 0.04, 200)


## ---------- 生产（建筑训练队列）----------

## 命令卡·生产菜单：该建筑可训练的单位
func train_menu(bld: Unit) -> Array:
	var out: Array = []
	for key in bld.setup_def.get("produces", []):
		if int(_defs.get(key, {}).get("min_age", 1)) > current_age:
			continue   # 时代未到 → 不出（英雄/马军需聚义代、攻城需替天行道代）
		var d: Dictionary = _defs.get(key, {})
		# 可培养英雄：已在阵中(现役或在产队列)就不再显示按钮——唯有战死后(hero_progress)才显示「复活」
		if bool(d.get("hero_trainable", false)):
			if count_alive(Unit.FACTION_LIANG, key) > 0 or _eco_in_queue(key):
				continue
		var cg := int(d.get("cost_gold", 0))
		var cw := int(d.get("cost_wood", 0))
		# 祭坛复活：战死的可培养英雄在聚义厅以「训练原价」复活，保留等级/技能
		var lbl := String(d.get("name", key))
		var is_revive := false
		if hero_progress.has(key):
			is_revive = true
			lbl = "复活·%s Lv%d" % [lbl, int(hero_progress[key].get("level", 1))]
		out.append({"kind": "train", "key": key, "label": lbl,
			"cost_g": cg, "cost_w": cw, "affordable": can_afford(cg, cw), "bld": bld, "revive": is_revive})
	return out


## 队列中尚未生成的单位人口之和
func _queued_pop() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_building:
			for k in u._train_queue:
				n += int(_defs.get(k, {}).get("pop", 1))
	return n


func queue_train(bld: Unit, key: String) -> void:
	if bld == null or not is_instance_valid(bld) or bld.is_constructing:
		return
	var d: Dictionary = _defs.get(key, {})
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	var pp := int(d.get("pop", 1))
	if bool(d.get("hero_trainable", false)):   # 英雄每种限一员
		var have := count_alive(Unit.FACTION_LIANG, key)
		for u in units:
			if is_instance_valid(u) and u.is_building:
				have += u._train_queue.count(key)
		if have >= 1:
			msg("%s 已在阵中" % String(d.get("name", key)), 1.5)
			return
		# 驻守战·英雄总数上限（关卡可配，0=不限）：现役英雄 + 在产英雄 ≤ hero_cap
		var hcap := int(level.hero_cap()) if (level != null and level.has_method("hero_cap")) else 0
		if hcap > 0:
			var htotal := liang_heroes().size()
			for u in units:
				if is_instance_valid(u) and u.is_building:
					for qk in u._train_queue:
						if bool(_defs.get(qk, {}).get("hero_trainable", false)):
							htotal += 1
			if htotal >= hcap:
				msg("聚义厅英雄已满（上限 %d 员，可在编辑器调整）" % hcap, 1.8)
				return
	if used_pop() + _queued_pop() + pp > pop_cap:
		msg("人口已满（造民居可加人口）", 1.5)
		return
	if not can_afford(cg, cw):
		msg("资源不足：需 金%d 木%d" % [cg, cw], 1.5)
		Sfx.play("cant")
		return
	if bld._train_queue.size() >= 8:
		msg("生产队列已满", 1.2)
		return
	spend(cg, cw)
	Sfx.play("click")
	bld._train_queue.append(key)
	if bld._train_queue.size() == 1:
		bld._train_t = float(d.get("train_time", 12.0))


## 取消生产队列里第 index 个（经典RTS式：点队列图标即撤单），全额退还资源；撤的是队首则重置计时。
func cancel_train(bld: Unit, index: int) -> void:
	if bld == null or not is_instance_valid(bld) or index < 0 or index >= bld._train_queue.size():
		return
	var key: String = bld._train_queue[index]
	var d: Dictionary = _defs.get(key, {})
	add_resources(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0)))   # 退还花费
	bld._train_queue.remove_at(index)
	if index == 0 and not bld._train_queue.is_empty():   # 撤的是正在训练的 → 计时重置到新队首
		bld._train_t = float(_defs.get(bld._train_queue[0], {}).get("train_time", 12.0))
	Sfx.play("order")
	msg("已取消生产 %s（资源已退还）" % String(d.get("name", key)), 1.2)
	if hud != null:
		hud.refresh_command()


## 命令卡·科技菜单：该建筑可研究、且尚未完成/进行中的科技
func research_menu(bld: Unit) -> Array:
	var out: Array = []
	for key in bld.setup_def.get("researches", []):
		if _tech_done.has(key) or bld._research_key == key:
			continue
		if int(Defs.TECHS.get(key, {}).get("min_age", 1)) > current_age:
			continue   # 升「替天行道」需先到聚义代
		var d: Dictionary = Defs.TECHS.get(key, {})
		var cg := int(d.get("cost_gold", 0))
		var cw := int(d.get("cost_wood", 0))
		out.append({"kind": "research", "key": key, "label": String(d.get("name", key)),
			"cost_g": cg, "cost_w": cw, "affordable": can_afford(cg, cw), "bld": bld,
			"sub": String(d.get("desc", ""))})
	return out


func queue_research(bld: Unit, key: String) -> void:
	if bld == null or not is_instance_valid(bld) or bld.is_constructing or bld._research_key != "":
		return
	if _tech_done.has(key):
		return
	var d: Dictionary = Defs.TECHS.get(key, {})
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if not can_afford(cg, cw):
		msg("资源不足：需 金%d 木%d" % [cg, cw], 1.5)
		Sfx.play("cant")
		return
	spend(cg, cw)
	Sfx.play("click")
	bld._research_key = key
	bld._research_t = float(d.get("time", 25.0))


func on_research_done(bld: Unit, key: String) -> void:
	if _tech_done.has(key):
		return
	_tech_done[key] = true
	var eff: Dictionary = Defs.TECHS.get(key, {}).get("effect", {})
	if eff.has("advance_age"):   # 时代进阶：解锁后期单位/建筑/科技
		current_age = maxi(current_age, int(eff["advance_age"]))
		if hud != null:
			hud.show_message("【时代】晋升至「%s」！" % ["", "草莽", "聚义", "替天行道"][clampi(current_age, 1, 3)], 3.0)
	tech_atk *= float(eff.get("atk_mult", 1.0))
	tech_gather *= float(eff.get("gather_mult", 1.0))
	var hp_m := float(eff.get("hp_mult", 1.0))
	if hp_m != 1.0:
		tech_hp *= hp_m
		for u in units:   # 现役梁山兵立即受益
			if not (is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building and u.hp > 0.0):
				continue
			if u.is_hero:
				u._recompute_hero_stats()   # 英雄把 tech_hp 折进重算→持久（否则下次重算被清）
			else:
				var frac: float = u.hp / u.max_hp
				u.max_hp *= hp_m
				u.hp = u.max_hp * frac
	msg("【科技】%s 研究完成！" % String(Defs.TECHS.get(key, {}).get("name", key)), 2.5)
	Sfx.play("complete", 0.0, 0.04, 200)
	if hud != null:
		hud.refresh_command()


func on_unit_trained(bld: Unit, key: String) -> void:
	var half := building_footprint_half(bld.key)
	var c := map.world_to_cell(bld.position) + Vector2i(half + 1, half + 1)
	var u := spawn_unit(key, Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(c)))
	# 战死英雄重练 → 恢复原等级/技能（不从 1 级重来）
	if u.is_hero and u._hero_leveled and hero_progress.has(key):
		var pr: Dictionary = hero_progress[key]
		u.restore_progress(int(pr["level"]), float(pr["xp"]), int(pr["sp"]), pr["ranks"])
		hero_progress.erase(key)
		msg("%s 重整旗鼓归来——仍是 %d 级好汉！" % [u.display_name, u.hero_level], 3.5)
	if u.is_worker:
		# 工人优先复用 typed 集结点：去采指定资源；采空则就近补同类；都没有就近采任意资源
		var node: Unit = null
		if bld.rally_node != null and is_instance_valid(bld.rally_node) and bld.rally_node.res_left > 0.0:
			node = bld.rally_node
		elif bld.rally_kind != "":
			node = nearest_resource(bld.rally, bld.rally_kind)
		elif bld.has_rally:
			var rn := nearest_resource(bld.rally, "")
			if rn != null and rn.position.distance_to(bld.rally) < 70.0:
				node = rn
		if node != null:
			u.order_gather(node)
			return
		if bld.has_rally:
			u.order_move(bld.rally)
			return
		# 无集结点：自动去采当前较缺的那种资源（经典RTS式新村民不闲置）
		var want := "gold" if gold <= wood else "wood"
		var auto := nearest_resource(u.position, want)
		if auto == null:
			auto = nearest_resource(u.position, "")
		if auto != null:
			u.order_gather(auto)
	elif bld.has_rally:
		u.order_move(bld.rally)
	elif ai_friendly and int(Settings.auto_micro_level) >= 3 and not u.is_hero:
		u.order_amove(_eco_frontline())   # 全托管：新练的兵自动 A 移到防御前线（边走边打）


## ---------- 主循环 ----------

func _on_intro_done() -> void:
	phase = Phase.DEPLOY
	hud.show_deploy()
	hud.set_top("准备阶段 — 查看战场，点击「开战」开始（开战前不能操作单位）")
	if level.deploy_hint() != "":
		hud.show_message(level.deploy_hint(), 6.0)


func _on_start_battle() -> void:
	phase = Phase.FIGHT
	level.on_start(self)


func _on_unit_died(u: Unit) -> void:
	# 战死英雄存档：可培养英雄阵亡时记下等级/经验/技能点/已学技能，重练后恢复（issue：复活变1级）
	if u.is_hero and u._hero_leveled:
		hero_progress[u.key] = {
			"level": u.hero_level, "xp": u.hero_xp, "sp": u.skill_points,
			"ranks": u.ability_slots.map(func(s: Dictionary) -> int: return int(s["rank"]))}
	units.erase(u)
	selection.erase(u)
	if _ability_caster == u:   # 施法者阵亡：解除指向态，避免光标/预览悬空
		_disarm_ability()
	if u.is_building:
		if u.has_meta("fcell"):   # 拆除后放开占地（瓦砾可通行）
			map.block_footprint(u.get_meta("fcell"), u.get_meta("fhalf"), false)
		if not u.is_constructing and u.faction == Unit.FACTION_LIANG:   # 只扣玩家人口上限
			var pp := int(u.setup_def.get("provides_pop", 0))
			if pp > 0:
				pop_cap = maxi(0, pop_cap - pp)
	_update_sel_label()
	var mark := FadingMark.new()
	mark.position = u.position
	fx_root.add_child(mark)
	if u.faction == Unit.FACTION_GUAN and not u.is_building:
		kills += 1
		# 按英雄统计歼敌：把这一杀记到「最后一击」的梁山英雄名下。
		# 用英雄 key 作键（而非 instance_id）→ 英雄阵亡后在聚义厅复活(新实例)仍并入同一条战功，不另起一行。
		var k: Unit = u._killer
		if k != null and is_instance_valid(k) and k.is_hero and k.faction == Unit.FACTION_LIANG:
			var rec: Dictionary = hero_kills.get(k.key, {"name": k.display_name, "key": k.key, "n": 0})
			rec["n"] = int(rec["n"]) + 1
			hero_kills[k.key] = rec
		if economy:   # 自由模式：击杀经验
			var xp: float = float(u.setup_def.get("xp", 0.0))
			if xp <= 0.0:
				xp = u.max_hp * 0.4 + 20.0
			# 最后一击的英雄无论距离多远都得经验：超视距/远程技能补刀也算
			var xk_id := 0
			if k != null and is_instance_valid(k) and k.is_hero and k.faction == Unit.FACTION_LIANG and k.hp > 0.0:
				k.gain_xp(xp)
				xk_id = k.get_instance_id()
			# 附近其他玩家英雄共享经验（不重复给最后一击者）
			for h in units:
				if is_instance_valid(h) and h.is_hero and h.faction == Unit.FACTION_LIANG and h.hp > 0.0 \
						and h.get_instance_id() != xk_id \
						and h.position.distance_to(u.position) < 300.0:
					h.gain_xp(xp)
	if phase == Phase.FIGHT:
		level.on_unit_died(self, u)


func _physics_process(delta: float) -> void:
	if phase == Phase.INTRO:
		return
	_aura_pass()
	_stealth_pass()
	_enemy_ability_pass()
	_auto_micro_pass()
	_summon_hunt_pass()
	if ai_friendly and int(Settings.auto_micro_level) >= 3:
		_auto_economy_pass(delta)   # 全托管(仅AI友好模式)：喽啰自动经营 + 自动开战（DEPLOY/FIGHT 均跑）
	_separation_pass(delta)
	_decay_lit(delta)
	if fog:
		_fog_pass(delta)

	if phase != Phase.FIGHT:
		return

	_ground_dot_pass(delta)
	_zone_pass(delta)
	_ice_wall_pass(delta)
	_tick_pending_casts()
	level.process(self, delta)
	if phase == Phase.FIGHT:
		hud.set_top(level.top_status(self))

	if _smoke:
		_smoke_t -= delta
		if _smoke_t <= 0.0:
			_smoke_t = 15.0
			print("[smoke] %s enemies=%d players=%d kills=%d" % [level.id(), enemies_alive(), players_alive(), kills])
			if economy:
				var blds := units.filter(func(u: Unit) -> bool:
					return is_instance_valid(u) and u.is_building and not u.is_resource and u.key != "hall")
				var con := blds.filter(func(u: Unit) -> bool: return u.is_constructing).size()
				print("[smoke] %s gold=%d wood=%d pop=%d/%d builds=%d con=%d techG=%.2f" % [
					level.id(), gold, wood, used_pop(), pop_cap, blds.size(), con, tech_gather])
				# #6 验证：没有敌人以资源点为目标，且林木满血（敌人不再砍树）
				var foe_on_res := units.filter(func(u: Unit) -> bool:
					return is_instance_valid(u) and u.faction == Unit.FACTION_GUAN and u.hp > 0.0 \
						and u._target != null and is_instance_valid(u._target) and u._target.is_resource).size()
				var min_tree := 1.0
				for u in units:
					if is_instance_valid(u) and u.is_resource and u.res_kind == "wood":
						min_tree = minf(min_tree, u.hp / u.max_hp)
				print("[smoke] skirmish foe_on_resource=%d min_tree_hp=%.2f" % [foe_on_res, min_tree])


func _process(_delta: float) -> void:
	# 触屏：单指按住原地 ≥350ms → 长按。按在己方可驻军建筑上且选了可动单位 → 驻扎；
	# 否则进入「框选」态（之后拖动拖出选择框，不再拖地图）。建造选址态(_build_armed)不参与长按。
	if _dragging and _touch_mode and not _box_mode and not _panning and _build_armed == "" and _ability_armed == "" \
			and Time.get_ticks_msec() - _press_ms >= 350 and _drag_from.distance_to(_drag_cur) < 16.0:
		if _garrisonable_at(_drag_from) != null and not _selected_movers().is_empty():
			_dragging = false
			_order_garrison_at(_drag_from)   # 长按建筑 = 驻扎（短按仍是切换选择）
		else:
			_box_mode = true
			overlay.queue_redraw()
			Sfx.play("click")
	# 触屏·指向技能瞄准：手指拖到屏幕边缘 → 地图朝该方向自动滚屏（够得着屏外目标；准星仍跟手指、松手即放）
	if _touch_mode and _dragging and _ability_armed != "" and camera != null and not get_tree().paused:
		var vs: Vector2 = get_viewport().get_visible_rect().size
		var sm: Vector2 = get_viewport().get_mouse_position()
		var bottom: float = vs.y - RTSCamera.PANEL_H   # 底部命令栏之上才算「下边缘」
		var m := 70.0
		var dir := Vector2.ZERO
		if sm.x < m: dir.x = -1.0
		elif sm.x > vs.x - m: dir.x = 1.0
		if sm.y < m: dir.y = -1.0
		elif sm.y > bottom - m: dir.y = 1.0
		if dir != Vector2.ZERO:
			camera.position += dir * (640.0 * _delta * Settings.cam_speed) / camera.zoom.x
			_drag_cur = get_global_mouse_position()   # 滚屏后准星落在新露出的区域
			overlay.queue_redraw()
	if _click_fx_t > 0.0:
		_click_fx_t = maxf(0.0, _click_fx_t - _delta)
	if _alert_t > 0.0:
		_alert_t = maxf(0.0, _alert_t - _delta)
	if _demolish_armed_t > 0.0:
		_demolish_armed_t = maxf(0.0, _demolish_armed_t - _delta)
	_update_hover_cursor()
	# BGM 情绪：交战阶段且场上有敌→战斗曲，否则→经营曲（交叉淡变在 Music 内处理）
	if phase == Phase.FIGHT:
		var want := "battle" if enemies_alive() > 0 else "calm"
		if Music.mood() != want:
			Music.set_mood(want)
	if ai_friendly:   # 自动镜头仅在 AI友好模式下生效（含其下的全托管档）
		_autocam_tick(_delta)


## ───────────────── AI友好模式·自动镜头：全员托管后自动巡视战况最激烈处 ─────────────────
## 触发：交战阶段、场上有敌、全部我方英雄均已托管，且玩家未在手动操控镜头。
## 行为：每 ≥AUTOCAM_DWELL 秒重选「最激烈战团」，平滑移镜+缩放对准；同一战团则持续跟随，不乱跳。
func _autocam_tick(delta: float) -> void:
	# 全员托管 → 左下角出现「自动镜头」按钮；玩家点开后才接管（无敌时检阅我方英雄、有战事时盯最激烈处）
	var full := ai_friendly and int(Settings.auto_micro_level) >= 3   # 全托管(仅AI友好模式)：镜头自动接管，无需按钮
	var managed := phase == Phase.FIGHT and not get_tree().paused and _all_heroes_managed()
	if full and managed:
		_autocam_enabled = true          # 全托管：彻底不用操作，镜头直接自动
	elif not managed:
		_autocam_enabled = false         # 失去全托管（取消某英雄托管等）→ 收回自动镜头意图
	if hud != null:
		hud.set_autocam_button(managed and not full, _autocam_enabled)   # 全托管不显示按钮（无需手动）
	var want := managed and _autocam_enabled
	if want != _autocam_active:
		_autocam_active = want
		_autocam_dwell = 999.0           # 刚接管：立即选点
		_autocam_focus = Vector2.INF     # 清掉上次的聚焦（未选到目标前不移镜）
		_autocam_review_unit = null
		_autocam_target_pos = camera.position   # 安全兜底：先对齐当前视角，避免漂向 (0,0)
		camera.auto_driving = want
		if not want:
			return
	if not _autocam_active:
		return
	# 玩家显式操控镜头（方向键/滚轮/拖拽/手势）→ 暂时让位，期间不抢镜
	if camera.user_controlling():
		_autocam_dwell = 999.0           # 让位结束后立即重新选点
		return
	_autocam_dwell += delta
	if _autocam_dwell >= AUTOCAM_DWELL:
		_autocam_repick()
	# 检阅模式：持续跟拍被检阅的英雄（它会走动），镜头平滑跟随
	if _autocam_review_unit != null and is_instance_valid(_autocam_review_unit) and _autocam_review_unit.hp > 0.0:
		_autocam_target_pos = to_screen(_autocam_review_unit.position)
		_autocam_focus = _autocam_review_unit.position
	# 还没选到任何目标（_autocam_focus 仍为 INF）→ 保持原地，绝不漂向地图原点(尖角)
	if _autocam_focus == Vector2.INF:
		return
	# 平滑插值到目标机位（时间无关阻尼，掉帧也不突跳）
	var t := 1.0 - pow(0.0025, delta)
	camera.position = camera.position.lerp(_autocam_target_pos, t)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * _autocam_target_zoom, t)


## 左下角「自动镜头」按钮的点击回调：开/关自动镜头（仅全托管时按钮可见）。
func toggle_autocam() -> void:
	_autocam_enabled = not _autocam_enabled
	if hud != null:
		hud.show_message("自动镜头：%s" % ("开" if _autocam_enabled else "关"), 1.2)


## 是否「全部我方英雄都在托管」（且至少有一名存活英雄）。
func _all_heroes_managed() -> bool:
	if int(Settings.auto_micro_level) <= 0:
		return false
	var any := false
	for u in units:
		if is_instance_valid(u) and u.is_hero and u.faction == Unit.FACTION_LIANG \
				and u.hp > 0.0 and not u.is_building:
			any = true
			if not u.auto_micro:
				return false
	return any


## 重新选机位：找最激烈战团；当前战团仍在且别处没「明显更激烈又离得远」时，继续跟随当前战团。
func _autocam_repick() -> void:
	var pts := _combat_points()
	if pts.is_empty():
		_autocam_review()   # 没有交战 → 转去逐个检阅我方英雄
		return
	_autocam_review_unit = null   # 进入战斗模式，停止检阅
	var chosen := _cluster_at(pts, _densest_point(pts))
	var ch_center: Vector2 = chosen["center"]
	var ch_heat := float(chosen["heat"])
	if _autocam_focus != Vector2.INF:
		var cur := _cluster_at(pts, _autocam_focus)
		var cur_heat := float(cur["heat"])
		# 当前战团还在、且别处没「(1.3×)更激烈又>9格远」→ 继续跟当前战团（防镜头来回跳）
		if cur_heat > 0.0 and not (ch_center.distance_to(_autocam_focus) > 288.0 and ch_heat >= cur_heat * 1.3):
			chosen = cur
			ch_center = cur["center"]
	_autocam_focus = ch_center
	_autocam_target_pos = to_screen(ch_center)
	_autocam_target_zoom = float(chosen["zoom"])
	_autocam_dwell = 0.0


## 检阅模式：无战事时，镜头近景逐个巡视我方英雄（每名停留 ≥AUTOCAM_DWELL 秒，循环）。
func _autocam_review() -> void:
	var heroes: Array = []
	for u in units:
		if is_instance_valid(u) and u.is_hero and u.faction == Unit.FACTION_LIANG \
				and u.hp > 0.0 and not u.is_building:
			heroes.append(u)
	if heroes.is_empty():
		_autocam_review_unit = null   # 没英雄可看 → 保持原地
		return
	_autocam_review_idx = (_autocam_review_idx + 1) % heroes.size()
	var h: Unit = heroes[_autocam_review_idx]
	_autocam_review_unit = h
	_autocam_focus = h.position
	_autocam_target_pos = to_screen(h.position)
	_autocam_target_zoom = AUTOCAM_REVIEW_ZOOM
	_autocam_dwell = 0.0


## 交战点：每个「附近有我方战斗单位」的官军单位记一个带权点（敌将权重更高，更值得看）。
func _combat_points() -> Array:
	var lians: Array = []
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and not u.is_building and not u.is_resource:
			lians.append(u)
	var pts: Array = []
	if lians.is_empty():
		return pts
	var near2 := (6.0 * GameMap.CELL) * (6.0 * GameMap.CELL)   # 6 格内算「交战」
	for e in units:
		if not (is_instance_valid(e) and e.faction == Unit.FACTION_GUAN and e.hp > 0.0 and not e.is_building):
			continue
		var w := 0.0
		for l in lians:
			if e.position.distance_squared_to(l.position) <= near2:
				w += 3.0 if l.is_hero else 1.0
		if w > 0.0:
			pts.append([e.position, w * (2.0 if e.is_hero else 1.0)])
	return pts


## 局部热度最高的交战点（聚合半径内权重和最大者）作为战团种子。
func _densest_point(pts: Array) -> Vector2:
	var r2 := AUTOCAM_HOT_R * AUTOCAM_HOT_R
	var best := -1.0
	var seed: Vector2 = pts[0][0]
	for i in range(pts.size()):
		var pi: Vector2 = pts[i][0]
		var heat := 0.0
		for j in range(pts.size()):
			if pi.distance_squared_to(pts[j][0]) <= r2:
				heat += float(pts[j][1])
		if heat > best:
			best = heat
			seed = pi
	return seed


## 以 seed 为中心聚合半径内交战点 → {center 加权中心, heat 权重和, zoom 按散布定缩放}。
func _cluster_at(pts: Array, seed: Vector2) -> Dictionary:
	var r2 := AUTOCAM_HOT_R * AUTOCAM_HOT_R
	var center := Vector2.ZERO
	var wsum := 0.0
	for j in range(pts.size()):
		var pj: Vector2 = pts[j][0]
		if seed.distance_squared_to(pj) <= r2:
			center += pj * float(pts[j][1])
			wsum += float(pts[j][1])
	if wsum <= 0.0:
		return {"center": seed, "heat": 0.0, "zoom": _autocam_target_zoom}
	center /= wsum
	# 实际散布半径（中心周围所有交战点）→ 定缩放：让战团约占视口 0.6
	var maxd := 0.0
	for j in range(pts.size()):
		var pj2: Vector2 = pts[j][0]
		if seed.distance_squared_to(pj2) <= r2:
			maxd = maxf(maxd, center.distance_to(pj2))
	var vp := get_viewport().get_visible_rect().size
	var span := maxf(maxd * 2.0 * 1.12, 3.0 * GameMap.CELL)   # iso 投影约同尺度，留底
	var zoom := clampf(vp.y * 0.6 / span, 0.85, 1.7)
	return {"center": center, "heat": wsum, "zoom": zoom}


## ───────────────── 全托管·经济 AI（喽啰自动经营，auto_micro_level>=3）─────────────────
## 每 ~0.5s 一拍：喽啰采集/建造/修复 → 推进建造计划 → 练农民/兵/将 → 研究科技；DEPLOY 阶段自动开战。
func _auto_economy_pass(delta: float) -> void:
	if not economy or level == null:
		return
	if phase == Phase.DEPLOY:
		_eco_deploy_t += delta
		if not _eco_started and _eco_deploy_t >= 5.0:
			_eco_started = true
			_on_start_battle()   # 全托管：自动开战（经济在战斗阶段持续铺，首波 120s 后才来）
	elif phase != Phase.FIGHT:
		return
	_eco_t -= delta
	if _eco_t > 0.0:
		return
	_eco_t = 0.5
	_eco_workers()
	_eco_build()
	_eco_train()
	_eco_research()
	_eco_trade()


## 喽啰：闲置→补在建工地/采集（金矿工不足补金、否则伐木）；另抽工修受损建筑。
func _eco_workers() -> void:
	var workers: Array = []
	for u in units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0:
			workers.append(u)
	if workers.is_empty():
		return
	var gold_miners := _eco_count_miners("gold")
	for w in workers:
		if not w.is_idle_worker():
			continue
		var site := _eco_pending_site()
		if site != null:
			w.order_build(site)
			continue
		var want_gold := gold_miners < ECO_GOLD_MINERS
		var node: Unit = nearest_free_gold(w.position, null, w) if want_gold else null
		if node == null:
			node = nearest_resource(w.position, "wood")
		if node == null:
			node = nearest_resource(w.position, "")
		if node != null:
			w.order_gather(node)
			if node.res_kind == "gold":
				gold_miners += 1
	_eco_repair()


## 自动修复：受损(<65%)、非施工、附近无敌的己方建筑 → 抽一名非金矿工去修（已有人修则不重复）。
func _eco_repair() -> void:
	var dmg: Unit = null
	for u in units:
		if is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG and not u.is_constructing \
				and u.hp > 0.0 and u.hp < u.max_hp * 0.65 and not _foe_within(u.position, 220.0, Unit.FACTION_LIANG):
			dmg = u
			break
	if dmg == null:
		return
	for u in units:   # 已有人在修这座 → 不再派
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG \
				and u._state == Unit.ST_REPAIR and u.position.distance_to(dmg.position) < 130.0:
			return
	var w := _eco_free_worker()
	if w != null:
		w.order_repair(dmg)


## 建造（并行·纯状态驱动）：先给所有在建工地补工人；在建数 < ECO_MAX_SITES 且按需+负担得起+有空闲工 → 再开一座。
func _eco_build() -> void:
	var active := 0
	for u in units:
		if is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG and u.is_constructing and u.hp > 0.0:
			active += 1
			if _eco_builders_on(u) == 0:   # 工地没人施工(工人阵亡/被打断)→ 补一个
				var bw := _eco_free_worker()
				if bw != null:
					bw.order_build(u)
	if active >= ECO_MAX_SITES:
		return
	var e: Dictionary = _eco_next_build()
	if e.is_empty():
		return
	var key: String = e["key"]
	var d: Dictionary = _defs.get(key, {})
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if not can_afford(cg, cw):
		return
	var cell := _eco_find_cell(_eco_anchor(String(e.get("near", "hall"))), key)
	if cell.x < 0:
		return
	var builder := _eco_free_worker()
	if builder == null:
		return
	if not spend(cg, cw):
		return
	ai_start_construction(key, cell, Unit.FACTION_LIANG, builder)


## 练兵（英雄优先）：出英雄阶段只保最低农民、全力按序出英雄；英雄齐了再补农民到 wcap + 兵营练常备军。
func _eco_train() -> void:
	var hall := main_base(Unit.FACTION_LIANG)
	if hall == null or hall.is_constructing:
		return
	if _eco_hero_count() < _eco_hero_target():
		# 出英雄阶段：保最低农民(采金供英雄)，金宽裕才补；其余一律攒钱按序出英雄
		if _eco_count_workers() < ECO_BOOT_WORKERS and gold > 240 and _eco_can_train("lou_luo", hall):
			queue_train(hall, "lou_luo")
			return
		for hk in ECO_HERO_ORDER:
			if count_alive(Unit.FACTION_LIANG, hk) > 0 or _eco_in_queue(hk) or hero_progress.has(hk):
				continue
			if _eco_can_train(hk, hall):
				queue_train(hall, hk)
			return   # 严格按顺序：该出的英雄出不起就攒钱等它，不越位练后面的/兵
		return   # 英雄还没排满(可能在等人口/钱)→ 本拍不练兵
	# 英雄齐了：补农民 → 兵营常备军
	if _eco_count_workers() < ECO_WCAP and _eco_can_train("lou_luo", hall):
		queue_train(hall, "lou_luo")
		return
	if _eco_army_count() + _eco_queued_army() < ECO_ARMY_CAP:
		var bar := _eco_idle_barracks()   # 选队列最短的兵营，多兵营并行出兵
		if bar != null:
			var sk := _eco_pick_soldier()
			if sk != "" and _eco_can_train(sk, bar):
				queue_train(bar, sk)


## 研究（英雄之后）：出齐英雄前不研究(钱全留给英雄)；之后先精耕(经济)，再升 hp/atk 科技。
func _eco_research() -> void:
	if _eco_hero_count() < _eco_hero_target():
		return
	var hall := main_base(Unit.FACTION_LIANG)
	if hall != null and not hall.is_constructing and hall._research_key == "" \
			and not _tech_done.has("tech_gather") and _eco_afford_tech("tech_gather"):
		queue_research(hall, "tech_gather")
		return
	if hall != null and not hall.is_constructing and hall._research_key == "":
		for t in ["tech_age2", "tech_age3"]:   # 聚义·壮大(+10%血) / 替天行道(+10%攻)
			if not _tech_done.has(t) and int(Defs.TECHS.get(t, {}).get("min_age", 1)) <= current_age and _eco_afford_tech(t):
				queue_research(hall, t)
				return
	var bar := _eco_first_building("barracks")
	if bar != null and not bar.is_constructing and bar._research_key == "":
		for t2 in ["tech_armor", "tech_weapon"]:   # 甲胄·坚铠(+25%血) / 锻造·利刃(+20%攻)
			if not _tech_done.has(t2) and _eco_afford_tech(t2):
				queue_research(bar, t2)
				return


## 集市贸易：缺金又囤木时，把多余木头换成金（金是后期练兵瓶颈，木头常溢出）。有集市才换。
func _eco_trade() -> void:
	if gold >= 300 or wood < 500:
		return
	if _eco_first_building("market") != null:
		do_trade("wood")   # 100 木 → 70 金


# ---------- 全托管经济·助手 ----------

## 下一座要建的（纯状态驱动·英雄优先）：
##   ①仓库(采金命脉，最先且被拆即重建) → ②出英雄前只铺够 6 英雄人口的民居，其余省钱给英雄
##   → ③出齐英雄后按 ECO_MAINT 补兵营/民居/箭楼(被拆即重建)。
func _eco_next_build() -> Dictionary:
	if _eco_count_building("depot") < 1:
		return {"key": "depot", "near": "gold"}
	if _eco_hero_count() < _eco_hero_target():
		if pop_cap < ECO_PRE_HERO_POP:
			return {"key": "house", "near": "gold"}   # 给 6 英雄铺人口(堆金矿后方安全角)
		return {}                                       # 出英雄前别的都不修，把金留给英雄
	for m in ECO_MAINT:
		if _eco_count_building(String(m[0])) < int(m[1]):
			return {"key": String(m[0]), "near": String(m[2])}
	return {}


func _eco_count_building(key: String) -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.key == key and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 and not u.is_constructing:
			n += 1
	return n


func _eco_anchor(near: String) -> Vector2i:
	var hall := main_base(Unit.FACTION_LIANG)
	var hp: Vector2 = hall.position if hall != null else map.cell_to_world(level.camera_start_cell())
	if near == "gold":
		var g := nearest_resource(hp, "gold")
		if g != null:
			return map.world_to_cell(g.position)
	return map.world_to_cell(hp)


## 锚点四周环形搜一个能放下该建筑(footprint 全空)的格；找不到返回 (-1,-1)。
func _eco_find_cell(anchor: Vector2i, key: String) -> Vector2i:
	var half := building_footprint_half(key)
	for r in range(half + 2, 17):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue   # 只看当前环
				var c := anchor + Vector2i(dx, dy)
				if map.area_buildable(c, half):
					return c
	return Vector2i(-1, -1)


## 拉一名可建造的工人：优先伐木/闲置(别抽金矿工，金是瓶颈)，实在没有才抽金矿工。
func _eco_free_worker() -> Unit:
	var fallback: Unit = null
	for u in units:
		if not (is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0):
			continue
		if u._state == Unit.ST_BUILD or u._state == Unit.ST_REPAIR:
			continue
		if is_instance_valid(u._gather_node) and u._gather_node.res_kind == "gold":
			fallback = u
			continue
		return u
	return fallback


func _eco_pending_site() -> Unit:
	for u in units:
		if is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG \
				and u.is_constructing and u.hp > 0.0 and _eco_builders_on(u) == 0:
			return u
	return null


func _eco_builders_on(site: Unit) -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and u._state == Unit.ST_BUILD and u.position.distance_to(site.position) < 130.0:
			n += 1
	return n


func _eco_count_workers() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0:
			n += 1
	return n


func _eco_count_miners(kind: String) -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and is_instance_valid(u._gather_node) and u._gather_node.res_kind == kind:
			n += 1
	return n


func _eco_hero_count() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_hero and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 and not u.is_building:
			n += 1
	return n


## 升科技的英雄目标数：min(6, 英雄上限)；上限 0(不限)则按 6。
func _eco_hero_target() -> int:
	var hcap := int(level.hero_cap()) if (level != null and level.has_method("hero_cap")) else 0
	return mini(6, hcap) if hcap > 0 else 6


func _eco_army_count() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building \
				and not u.is_worker and not u.is_hero and not u.is_summon and u.hp > 0.0:
			n += 1
	return n


func _eco_in_queue(key: String) -> bool:
	for u in units:
		if is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG and key in u._train_queue:
			return true
	return false


func _eco_first_building(key: String) -> Unit:
	for u in units:
		if is_instance_valid(u) and u.key == key and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 and not u.is_constructing:
			return u
	return null


## 全托管·防御前线：新练的兵集结处。优先取我方前沿建筑(兵营/箭楼)形心并略向敌方推进；
## 没有前沿建筑则朝最近的来犯之敌推进；都没有就站在聚义厅前沿。
func _eco_frontline() -> Vector2:
	var base := main_base(Unit.FACTION_LIANG)
	var hp: Vector2 = base.position if (base != null and is_instance_valid(base)) else Vector2.ZERO
	var sum := Vector2.ZERO
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_building \
				and not u.is_constructing and (u.key == "barracks" or u.key == "arrow_tower"):
			sum += u.position
			n += 1
	if n > 0:
		var c: Vector2 = sum / float(n)
		var dir: Vector2 = c - hp
		return (c + dir.normalized() * 72.0) if dir.length() > 1.0 else c
	var foe := _nearest_foe_pos(hp, Unit.FACTION_LIANG)
	if foe != Vector2.INF:
		return hp.lerp(foe, 0.45)
	return hp


## 队列最短的兵营（多兵营并行出兵，别全挤在一座）。
func _eco_idle_barracks() -> Unit:
	var best: Unit = null
	var bq := 999
	for u in units:
		if is_instance_valid(u) and u.key == "barracks" and u.faction == Unit.FACTION_LIANG \
				and u.hp > 0.0 and not u.is_constructing and u._train_queue.size() < bq:
			bq = u._train_queue.size()
			best = u
	return best


## 各兵营队列里已排的常备兵总数（避免排超过军队上限）。
func _eco_queued_army() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.key == "barracks" and u.faction == Unit.FACTION_LIANG:
			n += u._train_queue.size()
	return n


## 兵营出兵：弓手/长枪/刀手/马军里挑一个能负担的（偏好弓+枪，远程+克骑兵）。
func _eco_pick_soldier() -> String:
	for sk in ["liang_gong", "liang_qiang", "liang_dao", "liang_ma"]:
		var d: Dictionary = _defs.get(sk, {})
		if d.is_empty() or int(d.get("min_age", 1)) > current_age:
			continue
		if can_afford(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))):
			return sk
	return "liang_dao"


## 训练前置检查（钱/人口/队列/时代），避免直接 queue_train 触发资源不足提示刷屏。
func _eco_can_train(key: String, bld: Unit) -> bool:
	if bld == null or not is_instance_valid(bld):
		return false
	var d: Dictionary = _defs.get(key, {})
	if int(d.get("min_age", 1)) > current_age:
		return false
	if not can_afford(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))):
		return false
	if used_pop() + _queued_pop() + int(d.get("pop", 1)) > pop_cap:
		return false
	if bld._train_queue.size() >= 8:
		return false
	return true


func _eco_afford_tech(key: String) -> bool:
	var d: Dictionary = Defs.TECHS.get(key, {})
	return can_afford(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0)))


## 地面斑驳光影：生成一张柔和径向贴图，在地图范围内确定性地撒若干「亮斑/暗斑」（云隙光）。
func _build_dapple() -> void:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var dx := (float(x) - 31.5) / 31.5
			var dy := (float(y) - 31.5) / 31.5
			var dd := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - dd, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)   # smoothstep 柔化边缘
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var dl := DappleLayer.new()
	dl.tex = ImageTexture.create_from_image(img)
	dl.ws = Vector2(map.w * GameMap.CELL, map.h * GameMap.CELL)
	world.add_child(dl)


## ---------- 后期处理（氛围）----------

## 全屏后处理：暗角 + 暖色分离调（高光偏暖、阴影偏冷）+ 轻对比/饱和提升。
## 用一张满屏 ColorRect + canvas_item 着色器采样屏幕纹理实现。世界之上、HUD 之下。
func _build_atmosphere() -> void:
	if not Settings.atmosphere:
		return   # 设置里关掉了氛围后期
	# 移动端（Android）跳过屏幕读取式后期处理：部分手机 GPU 对 hint_screen_texture 支持不稳，
	# 宁可不要这层暖色滤镜，也别冒黑屏风险（手机上画面照常，只是少一层调色）。
	if OS.has_feature("mobile"):
		return
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette : hint_range(0.0, 1.0) = 0.34;
uniform float warmth : hint_range(0.0, 0.3) = 0.07;
uniform float contrast : hint_range(0.8, 1.4) = 1.07;
uniform float saturation : hint_range(0.5, 1.6) = 1.14;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;
	col = (col - 0.5) * contrast + 0.5;                       // 对比
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);                      // 饱和
	col.r += warmth * l;                                      // 高光偏暖
	col.b += warmth * (1.0 - l) * 0.55;                       // 阴影偏冷
	// 水面波光：在偏蓝像素上叠加随时间流动的微光（无需逐格扫描）
	float waterness = clamp((col.b - max(col.r, col.g)) * 3.2, 0.0, 1.0);
	float sh = (sin(uv.x * 60.0 + uv.y * 38.0 + TIME * 1.4) * 0.5 + 0.5)
		* (sin(uv.x * 28.0 - uv.y * 66.0 - TIME * 1.05) * 0.5 + 0.5);
	col += waterness * sh * 0.10 * vec3(0.72, 0.86, 1.0);
	vec2 d = uv - vec2(0.5);
	float vig = smoothstep(0.92, 0.30, length(d) * 1.28);     // 暗角
	col *= mix(1.0 - vignette, 1.0, vig);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var rect := ColorRect.new()
	rect.name = "Atmosphere"
	rect.material = mat
	rect.color = Color(1, 1, 1, 1)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## ---------- 战争迷雾 ----------

func _init_fog() -> void:
	var n := map.w * map.h
	_vision = PackedByteArray()
	_vision.resize(n)               # 默认 0=未探索
	_vis_t = PackedFloat32Array()
	_vis_t.resize(n)                # 默认 0=无驻留
	_sight_now = PackedByteArray()
	_sight_now.resize(n)
	_vision_img = Image.create(map.w, map.h, false, Image.FORMAT_RGBA8)
	_vision_img.fill(Color(0, 0, 0, 1.0))
	_fog_tex = ImageTexture.create_from_image(_vision_img)
	_fog_layer = FogLayer.new()
	_fog_layer.tex = _fog_tex
	_fog_layer.ws = Vector2(map.w * GameMap.CELL, map.h * GameMap.CELL)
	world.add_child(_fog_layer)   # 在 units/fx 之后 → 盖住迷雾中的敌人


# 「明亮」：当前正看或离开后 30 秒驻留内（_vision==2）。决定敌方普通单位是否显示。
func is_visible_world(p: Vector2) -> bool:
	if not fog:
		return true
	var c := map.world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= map.w or c.y >= map.h:
		return false
	return _vision[c.y * map.w + c.x] == 2


# 「已探索」：曾照亮过（_vision != 0）。决定敌方建筑是否留在阴影里（记忆迷雾）。
func is_explored_world(p: Vector2) -> bool:
	if not fog:
		return true
	var c := map.world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= map.w or c.y >= map.h:
		return false
	return _vision[c.y * map.w + c.x] != 0


func _fog_pass(delta: float) -> void:
	_fog_t -= delta
	if _fog_t > 0.0:
		return
	var step := 0.18 - _fog_t                   # 距上次 pass 的实际秒数（用于驻留倒计时）
	_fog_t = 0.18
	var n := _vision.size()
	# 1) 计算本次真正在视野内的格（_sight_now）
	for i in range(n):
		_sight_now[i] = 0
	for u in units:
		# 资源点不提供视野；驻军单位藏在建筑里也不另外提供视野（视野由建筑本身给）
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 or u.is_resource or u.garrisoned:
			continue
		var r := int(u.setup_def.get("sight", 10 if u.is_building else 8))
		_mark_sight_now(map.world_to_cell(u.position), r)
	# 2) 更新可见度 + 驻留：视野内→满驻留并标记明亮；视野外→倒计时，到 0 才退为阴影
	for i in range(n):
		if _sight_now[i] == 1:
			_vision[i] = 2
			_vis_t[i] = SIGHT_LINGER
		elif _vision[i] == 2:
			_vis_t[i] -= step
			if _vis_t[i] <= 0.0:
				_vis_t[i] = 0.0
				_vision[i] = 1                  # 驻留耗尽 → 退为已探索（阴影）
	# 3) 刷新迷雾纹理：2=明亮(透明) 1=阴影(半黑) 0=未探索(全黑)
	for y in range(map.h):
		for x in range(map.w):
			var v: int = _vision[y * map.w + x]
			var a := 0.0 if v == 2 else (0.5 if v == 1 else 1.0)
			_vision_img.set_pixel(x, y, Color(0, 0, 0, a))
	_fog_tex.update(_vision_img)
	# 4) 迷雾中的敌人：普通单位仅「明亮」时显示；建筑一旦探明便留在阴影里（记忆迷雾）。
	#    fog 层绘制在 units 之后、已探索格罩 0.5 黑 → 保留的建筑自然呈半暗阴影轮廓，
	#    玩家始终知道开过图处官军大营/箭楼/兵营的位置。
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_GUAN:
			if u.is_building:
				u.visible = is_explored_world(u.position)
			else:
				u.visible = is_visible_world(u.position)


## 临时照亮一片区域（技能落点等）：把范围内格设为「明亮」并给驻留时长，_fog_pass 会自然延时再退阴影。
## 仅 fog 模式生效；不在任何单位视野内时，dur 秒后自动淡回阴影。
func _reveal_fog_at(center: Vector2, radius_px: float, dur := 6.0) -> void:
	if not fog or _vision.is_empty():
		return
	var c := map.world_to_cell(center)
	var r := maxi(1, int(ceil(radius_px / float(GameMap.CELL))))
	var r2 := r * r
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r2:
				continue
			var x := c.x + dx
			var y := c.y + dy
			if x >= 0 and y >= 0 and x < map.w and y < map.h:
				var idx := y * map.w + x
				_vision[idx] = 2
				_vis_t[idx] = maxf(_vis_t[idx], dur)


func _mark_sight_now(c: Vector2i, r: int) -> void:
	var r2 := r * r
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r2:
				continue
			var x := c.x + dx
			var y := c.y + dy
			if x >= 0 and y >= 0 and x < map.w and y < map.h:
				_sight_now[y * map.w + x] = 1


func _decay_lit(delta: float) -> void:
	if lit_cells.is_empty():
		return
	var dead: Array = []
	for c in lit_cells:
		lit_cells[c] -= delta
		if lit_cells[c] <= 0.0:
			dead.append(c)
	for c in dead:
		lit_cells.erase(c)
	overlay.queue_redraw()


func _end(victory: bool, line: String) -> void:
	if phase == Phase.END:
		return
	phase = Phase.END
	_disarm_amove()
	_disarm_ability()
	var camp = get_node_or_null("/root/Campaign")
	if camp != null and victory:
		camp.on_level_won()
	hud.show_end(victory, line, kills, camp != null and victory and camp.has_next(), _hero_kill_tally())
	if _smoke:
		print("[end] victory=%s kills=%d | %s" % [victory, kills, line])
		print("[end] hero_kills: %s" % _hero_kill_tally())


## 战后按英雄歼敌排行（多→少），用于结算面板「各路好汉战功」
func _hero_kill_tally() -> String:
	var arr: Array = hero_kills.values()
	arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) > int(b["n"]))
	var parts: Array = []
	for r in arr:
		if int(r["n"]) > 0:
			parts.append("%s 斩 %d" % [r["name"], int(r["n"])])
	return "    ".join(parts)


## ---------- 全局逐帧效果 ----------

func _aura_pass() -> void:
	for u in units:
		u.buff_atk = 1.0
		u.buff_speed = 1.0
		u.aura_slow = 1.0
		u.slow_aura_r = 0.0
	for h in units:
		if h.hp <= 0.0 or h.garrisoned:
			continue
		# 友方增益光环（攻/速）
		if h.aura != "":
			for v in units:
				if v == h or v.faction != h.faction or v.is_building or v.hp <= 0.0 or v.garrisoned:
					continue
				if h.position.distance_to(v.position) <= h.aura_radius:
					match h.aura:
						"atk":
							v.buff_atk = maxf(v.buff_atk, h.aura_power)
						"speed":
							v.buff_speed = maxf(v.buff_speed, h.aura_power)
		# 减速光环（公孙胜 E·被动）：data-driven，按已学等级减附近敌军移速
		if h.is_hero:
			var sa := _slow_aura_of(h)
			if not sa.is_empty():
				var sfoe := Unit.FACTION_GUAN if h.faction == Unit.FACTION_LIANG else Unit.FACTION_LIANG
				var sr: float = sa[1]
				h.slow_aura_r = sr
				for v in units:
					if v.faction == sfoe and not v.is_building and not v.is_resource and v.hp > 0.0 and not v.garrisoned \
							and h.position.distance_to(v.position) <= sr:
						v.aura_slow = minf(v.aura_slow, 1.0 - float(sa[0]))
	if tech_atk != 1.0:
		for u in units:
			if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building:
				u.buff_atk *= tech_atk


func _slow_aura_of(h: Unit) -> Array:
	for s in h.ability_slots:
		if int(s["rank"]) <= 0:
			continue
		var eff: Dictionary = _abilities.get(s["id"], {}).get("effect", {})
		if String(eff.get("kind", "")) == "slow_aura":
			var pct := float(eff.get("slow", 0.10)) * float(int(s["rank"]))
			var rad := float(_abilities.get(s["id"], {}).get("radius", 160.0))
			return [pct, rad]
	return []


func _stealth_pass() -> void:
	for u in units:
		if u.is_building or u.hp <= 0.0:
			continue
		u.hidden_in_reeds = u.faction == Unit.FACTION_LIANG and not u.has_target() \
			and map.t_world(u.position) == GameMap.T.REEDS
		if not u._dying:
			u.modulate.a = 0.55 if u.hidden_in_reeds else 1.0


## 敌方英雄自动施放技能。遍历全部技能槽(Q/W/E/R)：交战中就按招式智能起手——
## 指向型技能瞄准最近的梁山兵，范围攻击需附近有敌，自/友增益(鼓舞/死战)交战即放。
## 每帧每将最多起手一招（靠施法抬手 windup 自然错开 QWER，不会一帧全倒出来）。
func _enemy_ability_pass() -> void:
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_GUAN or u.hp <= 0.0 or u.is_building:
			continue
		if u.slot_count() <= 0 or u._cast_t > 0.0:   # 没技能槽 / 正在抬手 → 跳过
			continue
		if not u.has_target():   # 未交战不放招
			continue
		for i in range(u.slot_count()):
			if not u.slot_ready(i):
				continue
			var ad: Dictionary = _abilities.get(String(u.ability_slots[i]["id"]), {})
			if ad.is_empty():
				continue
			var r: float = float(ad.get("radius", 100.0))
			var lp: Vector2 = u.position
			if bool(ad.get("targeted", false)):
				var fp := _nearest_foe_pos(u.position, u.faction)
				if fp == Vector2.INF or u.position.distance_to(fp) > maxf(r, u.aggro_range):
					continue   # 没有可瞄的敌人、或目标太远 → 这招先不放
				lp = fp
			else:
				var kind := String(ad.get("effect", {}).get("kind", ""))
				var buff := kind in ["rally", "haste", "self_buff", "rally_heroes", "drunk_buff", "drunk_god"]
				if not buff and not _foe_within(u.position, r, u.faction):
					continue   # 范围攻击但附近没敌 → 不放
			_begin_cast(u, i, lp)
			break


## 在 pos 半径 r 内是否有 my_fac 的敌方作战单位（供敌将范围技能起手判定）。
func _foe_within(pos: Vector2, r: float, my_fac: int) -> bool:
	for v in units:
		if is_instance_valid(v) and v.faction != my_fac and not v.is_building and not v.is_resource \
				and not v.garrisoned and v.hp > 0.0 and pos.distance_to(v.position) <= r:
			return true
	return false


## 英雄托管(auto_micro)：自动加点 + 分英雄战术大脑（走位/退守/索敌/放招）。PC/移动端通用。
## 按 u.key 分派到 _brain_*（林冲盯骑兵、花荣后排风筝、武松召虎开大…），无专属脑者走 _auto_micro_generic。
## 只对开了 auto_micro 的英雄生效；没人托管时整 pass 只是一次廉价过滤。每将每 ~0.27s 一个动作。
const AI_TICK := 16   # 托管决策节流：每英雄约每 16 物理帧(~0.27s)决策一次，错帧分散

func _auto_micro_pass() -> void:
	if hud == null:
		return
	var lvl := int(Settings.auto_micro_level)
	if lvl <= 0:
		# 无托管：把任何仍处托管态的英雄一律关掉（切到「无」即全军取消托管）
		for u in units:
			if is_instance_valid(u) and u.is_hero and u.auto_micro:
				u.auto_micro = false
		return
	if lvl >= 3 and ai_friendly:   # 全托管(仅AI友好模式)：所有英雄自动进入托管，无需手动点「托管军」
		for u in units:
			if is_instance_valid(u) and u.is_hero and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 and not u.auto_micro:
				u.auto_micro = true
	var frame := Engine.get_physics_frames()
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or not u.is_hero \
				or not u.auto_micro or u.hp <= 0.0 or u.is_building:
			continue
		if u.skill_points > 0:   # 自动加点（受 can_learn 等级门槛约束）
			_auto_learn(u)
		if u.slot_count() <= 0 or u._cast_t > 0.0:
			continue
		# 节流：每帧都决策会让英雄不停改朝向(左右摇头)、徒增寻路抖动；改成每 ~0.27s 一次，按 id 错帧
		if (frame + u.get_instance_id()) % AI_TICK != 0:
			continue
		if lvl == 1:
			_auto_micro_weak(u)   # 弱托管：守住附近一块（~15×15 格），不追远、不管别处
		else:
			_auto_micro_hero(u)


## 弱托管：英雄各守一方。守备姿态（守阵短追、打完归位），只对「防区」内的敌人放招——
## 不越区追击、不管别处战事。增益/召唤照常；指向技能命中点钳制在防区内。
## 防区按角色缩放（各司其职）：近战 ≈15×15 格；远程更宽 ≈20×20 格（+5 格，能提前点射来犯）；
## 且不低于英雄自身够得着的范围（攻击距离+缓冲），免得忽视射程内的敌人。
const WEAK_LEASH := 240.0        # 近战防区半径（px）：240/32 ≈ 7.5 格 → ~15×15 格
const WEAK_LEASH_RANGED := 320.0 # 远程防区半径（px）：320/32 = 10 格 → ~20×20 格（比近战 +5 格直径）
const WEAK_GLOBAL := 760.0       # 超远支援技能(weak_global)在弱托管下的施放半径(≈24格≈全屏)

func _weak_leash(u: Unit) -> float:
	var r: float = WEAK_LEASH_RANGED if u.is_ranged else WEAK_LEASH
	return maxf(r, u.atk_range + 48.0)

const WEAK_HYST := 320.0   # 磁滞：被敌击中后防区/搜索范围 +10 格（≈320px），脱战 3 秒后收回
func _auto_micro_weak(u: Unit) -> void:
	if u.stance != Unit.STANCE_DEFEND:
		u.set_stance(Unit.STANCE_DEFEND)   # 守阵短追、自动归位
	# 磁滞回线：主动引敌范围小；一旦被打，防区 +10 格（去追打你的那个，不再呆站挨射）
	var hit := u.recently_hit()
	var leash := _weak_leash(u) + (WEAK_HYST if hit else 0.0)
	var fp := _nearest_foe_pos(u.position, u.faction)
	var dfp: float = u.position.distance_to(fp) if fp != Vector2.INF else 1.0e20
	for i in range(u.slot_count()):
		if not u.slot_ready(i):
			continue
		var ad: Dictionary = _abilities.get(String(u.ability_slots[i]["id"]), {})
		if ad.is_empty():
			continue
		# 召唤类（武松驱虎 / 公孙画龙）：与防区/托管档位无关——CD 一好、场上有敌、还有名额就放，
		# 召唤物自己扑出去打（_summon_hunt_pass）。「拉到战场上」靠召唤物自行索敌，不占英雄走位。
		var eff: Dictionary = ad.get("effect", {})
		if String(eff.get("kind", "")) == "summon":
			if fp != Vector2.INF:   # 召唤不设上限：CD 一好、场上有敌就召（虎/龙自行扑战场）
				_begin_cast(u, i, u.position)
				return
			continue
		# 超远支援技能（weak_global，如花荣箭雨/定身、宋江/吴用火攻）弱托管下仍全屏支援，无视防区
		var reach: float = WEAK_GLOBAL if bool(ad.get("weak_global", false)) else leash
		# 防区内没有敌人 → 一律不放（含增益/大招）：边上没人不要轻易开大
		if dfp > reach:
			continue
		var lp: Vector2 = fp if bool(ad.get("targeted", false)) else u.position
		_begin_cast(u, i, lp)
		return
	# 被打之后主动出击：奔向防区内最近的敌人砍/射，别原地呆站（与「开大后赶紧去砍人」同源）
	if hit and dfp <= leash and u._state == Unit.ST_IDLE:
		u.order_amove(fp)


## 召唤物自动出击：召出来的猛虎/金龙(is_summon)无需手操——空闲就攻击移动扑向最近敌、持续索敌
## （等价「框住按 A 出去」）。与托管档位无关，始终生效；不打断正在进行的攻击/移动。
func _summon_hunt_pass() -> void:
	var frame := Engine.get_physics_frames()
	for u in units:
		if not is_instance_valid(u) or not u.is_summon or u.hp <= 0.0 or u._state != Unit.ST_IDLE:
			continue
		if (frame + u.get_instance_id()) % AI_TICK != 0:
			continue
		var fp := _nearest_foe_pos(u.position, u.faction)
		if fp != Vector2.INF:
			u.order_amove(fp)


## 托管自动加点：受 can_learn 全部门槛约束（普通[1,3,5]/大招[6,8,10]/技能点/满级3），先大招后 Q/W/E。
func _auto_learn(h: Unit) -> void:
	var order := _learn_order(h)
	var guard := 0
	while h.skill_points > 0 and guard < 16:
		guard += 1
		var pick := -1
		for s in order:
			if h.can_learn(s):
				pick = s
				break
		if pick < 0:
			break
		h.learn(pick)


## 托管加点优先级（受 can_learn 等级门槛约束，学不了就顺到下一个）。
## 默认：先抢大招，再 Q/W/E。宋江特例：优先把火攻(song_fire, E 槽)点满，再大招、再 Q/W。
func _learn_order(h: Unit) -> Array:
	var last := h.slot_count() - 1
	match String(h.key):
		"song_jiang": return [2, last, 0, 1]   # 火攻(song_fire, E=2) 优先
		"hua_rong": return [1, last, 0, 2]      # 箭雨(hua_rain, W=1) 优先
		"lin_chong": return [2, last, 0, 1]     # 猎骑被动(lin_predator, E=2) 优先
	var o := [last]                             # 其它英雄照旧：先抢大招，再 Q/W/E
	for i in range(maxi(0, last)):
		o.append(i)
	return o


## ───────────────── 分英雄战术大脑（托管 AI）：每帧每将只发一个动作 ─────────────────
## 按 key 分派；无专属脑→通用放招。所有动作走 _begin_cast / order_*，靠抬手 windup 自然错开 QWER。
## 单位战斗力粗估：有效输出(atk×buff_atk/cd) × 当前血量。用于「能否轻松战胜」的双方对比，
## 比单纯数人头更准——同样 2 个，普通小兵可秒、精锐/骑兵则未必。
func _combat_power(u: Unit) -> float:
	if u == null or not is_instance_valid(u) or u.hp <= 0.0:
		return 0.0
	var dps: float = u.atk * maxf(u.buff_atk, 0.1) / maxf(u.atk_cd, 0.3)
	return dps * u.hp


## 勇敢反打：血量 > 1/5，且「自己的战斗力 ≥ 周围全部追兵之和 × BRAVE_MARGIN」才回身反打——
## 不再只看血量/人数(2 个精锐或骑兵照样该退就退)。作各英雄脑「残血退守」分支的闸门，
## 满足时不撤退、落回正常索敌反打（远程英雄=回身放风筝）。
const BRAVE_MARGIN := 2.0   # 需把追兵总战斗力压制到 2 倍以上才算「轻松战胜」
func _brave_retaliate(u: Unit) -> bool:
	if u.hp / maxf(u.max_hp, 1.0) <= 0.20:
		return false
	var r: float = maxf(220.0, u.aggro_range)
	var foe_pow := 0.0
	var n := 0
	for v in units:
		if not (is_instance_valid(v) and v.faction != u.faction and not v.is_building \
				and not v.is_resource and not v.garrisoned and not v.is_captive and v.hp > 0.0):
			continue
		if u.position.distance_to(v.position) > r:
			continue
		foe_pow += _combat_power(v)
		n += 1
	if n == 0:
		return false
	return _combat_power(u) >= foe_pow * BRAVE_MARGIN


func _auto_micro_hero(u: Unit) -> void:
	match String(u.key):
		"lin_chong": _brain_lin(u)
		"li_kui": _brain_li(u)
		"wu_song": _brain_wu(u)
		"hua_rong": _brain_hua(u)
		"gongsun_sheng": _brain_gong(u)
		"song_jiang": _brain_song(u)
		_: _auto_micro_generic(u)


## 通用托管放招（原 _auto_micro_pass 内联逻辑）。唯一改动：buff 白名单加入 "summon"，
## 让 radius=0 的召唤技（虎/龙）不再被「附近需有敌」误挡（原来 _foe_within(r=0) 恒 false → 放不出）。
func _auto_micro_generic(u: Unit) -> void:
	for i in range(u.slot_count()):
		if not u.slot_ready(i):
			continue
		var ad: Dictionary = _abilities.get(String(u.ability_slots[i]["id"]), {})
		if ad.is_empty():
			continue
		var r: float = float(ad.get("radius", 100.0))
		var lp: Vector2 = u.position
		if bool(ad.get("targeted", false)):
			var fp := _nearest_foe_pos(u.position, u.faction)
			if fp == Vector2.INF or u.position.distance_to(fp) > maxf(r, u.aggro_range):
				continue
			lp = fp
		else:
			var kind := String(ad.get("effect", {}).get("kind", ""))
			var buff := kind in ["rally", "haste", "self_buff", "rally_heroes", "drunk_buff", "drunk_god", "summon"]
			if not buff and not _foe_within(u.position, r, u.faction):
				continue
		_begin_cast(u, i, lp)
		break
	# 没在放招时，主动集火高价值目标（敌将/投石/远程/残血），别干站等引擎索敌
	if u._cast_t <= 0.0:
		var gt := _focus_target(u, maxf(280.0, u.aggro_range))
		if gt != null and u._target != gt:
			u.order_attack(gt)


## 林冲·反骑突击：专盯骑兵（猎骑被动吸血续航），Q 突刺 / W 横扫收割身边小兵，R 时空封印定一片。
## 残血且身边无骑可吸、大招也没好 → 回撤。
func _brain_lin(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var hp_frac := u.hp / u.max_hp
	var cav := _nearest_foe_unit(u.position, u.faction, true, false, false, u)
	var near_cav: bool = cav != null and u.position.distance_to(cav.position) <= u.atk_range + u.radius + 20.0
	var e_rank := int(u.ability_slots[2]["rank"])   # 猎骑被动等级 → 是否能靠咬骑兵回血
	# 退守：残血、身边没有可吸血的骑兵、且大招不可用（被一两个小兵追时血>1/5 则勇敢反打，不退）
	if hp_frac < 0.25 and not (near_cav and e_rank > 0) and not u.slot_ready(3) and not _brave_retaliate(u):
		if u.stance != Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_PASSIVE)
		_ai_move(u, _retreat_point(u,200.0))
		return
	elif u.stance == Unit.STANCE_PASSIVE and hp_frac > 0.35:
		u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position   # 牵引锚点跟随本体，免得恢复进攻后被旧撤退点拽回、永远咬不住骑兵
	# R 时空封印：敌群够密 / 命中敌英雄 / ≥2 骑兵 才放（cd40 稀缺，别空转）
	if u.slot_ready(3):
		var c := _densest_foe_pos(u.faction, 200.0)
		if c != Vector2.INF:
			var rr_arr := [130.0, 165.0, 200.0]
			var rr: float = rr_arr[clampi(int(u.ability_slots[3]["rank"]), 1, 3) - 1]
			if _foe_count_within(c, rr, u.faction) >= 3 or _any_enemy_hero_within(c, rr, u.faction) \
					or _foe_count_within(c, rr, u.faction, true) >= 2:
				if _ai_cast_slot(u, 3, c):
					return
	# Q 破阵突刺：朝最近敌方向（70°前锥，CD 仅 8s，主清+爆发）
	var fp := _nearest_foe_pos(u.position, u.faction)
	if fp != Vector2.INF and u.position.distance_to(fp) <= maxf(260.0, u.aggro_range):
		if _ai_cast_slot(u, 0, fp):
			return
	# W 横扫：已贴进敌群（自我中心 r100，粘住骑兵）
	if _foe_within(u.position, 100.0, u.faction):
		if _ai_cast_slot(u, 1, u.position):
			return
	# 索敌：优先锁骑兵；锁定后不再改判，避免在多骑间反复横跳
	if cav != null:
		if u._target == null or not is_instance_valid(u._target) or not u._target.is_cavalry:
			u.order_attack(cav)
	else:
		var sq := _nearest_foe_unit(u.position, u.faction, false, true, false, u)   # 退而求次：切脆皮远程
		if sq != null and u._target == null:
			u.order_attack(sq)
	# 兜底：仍无目标（没骑兵/脆皮、且引擎够不着） → 攻击移动压上最近敌
	if not u.has_target():
		_ai_push_into_range(u, _nearest_foe_pos(u.position, u.faction), 90.0)


## 李逵·黑旋风：W 冲锋切入 → Q 双斧绕身 → R 嗜血暴走（被围/残血就开，靠 150% 吸血反打）。
## 残血且大招没好 → 回撤。
func _brain_li(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var frac := u.hp / u.max_hp
	if frac < 0.30 and not u.slot_ready(3) and not _brave_retaliate(u):
		if u.stance != Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_PASSIVE)
		_ai_move(u, _retreat_point(u,220.0))
		return
	elif u.stance == Unit.STANCE_PASSIVE and frac > 0.4:
		u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position   # 牵引锚点跟随本体，免得恢复进攻后被旧撤退点拽回
	var fp := _nearest_foe_pos(u.position, u.faction)
	var d: float = u.position.distance_to(fp) if fp != Vector2.INF else 1.0e20
	# W 莽撞冲锋：中距离一跃切入（贴脸则别浪费 1s 蓄力）
	if fp != Vector2.INF and d > 90.0 and d <= 210.0:
		if _ai_cast_slot(u, 1, fp):
			return
	# Q 双斧回旋：身边有敌即开（紧跟冲锋落点最佳）
	if _foe_within(u.position, 120.0, u.faction):
		if _ai_cast_slot(u, 0, u.position):
			return
	# R 嗜血暴走（有大就开）：在近战中且被围≥2 或 残血
	if u.slot_ready(3) and _foe_within(u.position, 150.0, u.faction):
		if _foe_count_within(u.position, 150.0, u.faction) >= 2 or frac < 0.45:
			if _ai_cast_slot(u, 3, u.position):
				return
	# P3 兜底：集火高价值目标（敌将/投石/远程/残血先杀），够不着才攻击移动切入贴脸
	_engage_focus(u, fp)


## 武松·行者：召虎(CD一好就放) → 被围开 R 醉神（物免转血保命+反打）→ E 横扫。残血没大招才避战回撤。
func _brain_wu(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var frac := u.hp / u.max_hp
	var fp := _nearest_foe_pos(u.position, u.faction)
	var melee_near := _foe_count_within(u.position, 160.0, u.faction, false, true)
	# P1 残血：有大开大（醉神 20s 物免+结束转血=保命兼反打），否则更低再避战回撤
	if frac <= 0.35:
		if u.slot_ready(3):
			if _ai_cast_slot(u, 3, u.position):
				if fp != Vector2.INF:
					_ai_move(u, fp, true)
				return
		elif frac <= 0.30 and not _brave_retaliate(u):
			if u.stance != Unit.STANCE_PASSIVE:
				u.set_stance(Unit.STANCE_PASSIVE)
			_ai_move(u, _retreat_point(u,220.0))
			return
	elif u.stance == Unit.STANCE_PASSIVE and frac > 0.45:
		u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position
	# P2 推进：离敌尚远→攻击移动压上贴脸（不限 aggro，靠 amove 收紧索敌；近处交给放招）
	_ai_push_into_range(u, fp, 90.0)
	# P3 放招
	# R 醉神大闹快活林（进攻开大）：①贴身交战(≤180)或被围就开；②看对面人多(防区内≥3)且自己血不满 →
	# 先开大再扎进人堆（20s 物免，扎进去最安全）。20s物免+每击加攻是武松核心强势期，别苛求条件否则放不出。
	if u.slot_ready(3):
		var crowd := _foe_count_within(u.position, 240.0, u.faction, false, false)
		# 被围(身边≥2近战)就开；或「对面人多(防区内≥3)且血不满」→ 先开再扎进人堆。单个杂兵不浪费大招。
		if melee_near >= 2 or (frac < 0.92 and crowd >= 3):
			if _ai_cast_slot(u, 3, u.position):
				return   # 开完大招：下一拍 P2 推进会自动扎进最近人堆（此处别下移动令，免得打断施法）
	# Q 驱使猛虎（CD 一好、地图上有敌就召；老虎不设上限，召出来的虎自行扑向战场）
	if fp != Vector2.INF:
		if _ai_cast_slot(u, 0, u.position):
			return
	# E 双戒刀横扫（削甲+致盲）
	if _foe_within(u.position, 110.0, u.faction):
		if _ai_cast_slot(u, 2, u.position):
			return
	# W 三碗不过岗（血健康时增益攻速移速）
	if frac > 0.40 and _foe_within(u.position, 110.0, u.faction):
		if _ai_cast_slot(u, 1, u.position):
			return
	# 兜底集火：扑向高价值目标（敌将/投石/远程/残血），而非干站等引擎索敌
	_engage_focus(u, fp)


## 花荣·射手：后排风筝。默认挂弓远射；被贴脸→定身神箭压速+拉开；残血→凌空闪朝『远离』方向逃。
## 关键：凌空闪会把 180 血的花荣传送到落点，绝不朝最近敌盲放（否则等于送脸）。
func _brain_hua(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var hp_frac := u.hp / u.max_hp
	var nf := _nearest_foe_pos(u.position, u.faction)
	if nf == Vector2.INF:
		if u.melee_mode and u.slot_ready(3):
			_ai_cast_slot(u, 3, u.position)   # 无敌：收刀挂弓恢复射程
		if u.stance == Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_AGGRO)
			u._home = u.position
		return
	var dnf := u.position.distance_to(nf)
	var melee_threat := _foe_within(u.position, 130.0, u.faction)
	# 安全了（血回稳且已拉开距离）→ 退出避战，恢复后排平 A
	if u.stance == Unit.STANCE_PASSIVE and hp_frac > 0.5 and dnf > 200.0:
		u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position
	# P1 撤退/保命（被一两个小兵贴身追时，血>1/5 则不逃，回身放风筝反打——见 _brave_retaliate）
	if hp_frac < 0.35 and dnf < 150.0 and not _brave_retaliate(u):
		if u.melee_mode and u.slot_ready(3):
			if _ai_cast_slot(u, 3, u.position):   # 先切回弓
				return
		if u.slot_ready(0):
			var away := u.position + (u.position - nf).normalized() * 330.0
			if _ai_cast_slot(u, 0, away):         # 凌空闪·朝远离方向逃
				return
		if u.stance != Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_PASSIVE)   # 避战，免得跑到撤退点又自动索敌回冲
		_ai_move(u, _retreat_point(u,260.0))
		return
	# P2 反贴脸：被近战/骑兵逼近 → 定身神箭压到 20% 速 + 拉开
	if melee_threat:
		if not u.melee_mode and u.slot_ready(2):
			if _ai_cast_slot(u, 2, nf):
				return
		_ai_move(u, u.position + (u.position -nf).normalized() * 120.0)
		return
	# P3 箭雨(W·超视距主力)：有 CD 就放——任何同屏敌(≤520)都砸最密/最近，不受弓射程限制
	if u.slot_ready(1):
		var cc := _densest_foe_pos(u.faction, 100.0)
		if cc == Vector2.INF or u.position.distance_to(cc) > 520.0:
			cc = nf
		if cc != Vector2.INF and u.position.distance_to(cc) <= 520.0:
			if _ai_cast_slot(u, 1, cc):
				return
	# 定身神箭(E)：有冲脸近战/骑兵在 200 内逼近 → 钉控
	if u.slot_ready(2) and _foe_count_within(u.position, 200.0, u.faction, false, true) >= 1:
		if _ai_cast_slot(u, 2, nf):
			return
	# P4 默认挂弓后排平 A：若不慎处于近战形态则收刀回弓；射程内点最近脆皮
	if u.melee_mode and u.slot_ready(3):
		if _ai_cast_slot(u, 3, u.position):
			return
	var sq := _nearest_foe_unit(u.position, u.faction, false, true)   # 优先点最近远程脆皮
	if sq != null and u._target == null and u.position.distance_to(sq.position) <= u.atk_range + 40.0:
		u.order_attack(sq)
		return
	# P5 兜底：敌超出弓射程(站桩真空) → 攻击移动压进 ~210 射程，amove 沿途索敌、不主动贴脸
	_ai_push_into_range(u, nf, u.atk_range - 20.0)


## 公孙胜·法师：脆皮后排。被贴脸/残血→冰墙横在身前隔挡或撤；交战召金龙；敌成堆放黑雨。
func _brain_gong(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var hp_frac := u.hp / u.max_hp
	var threat := _nearest_foe_unit(u.position, u.faction, false, false, true)   # 最近的近战/骑兵威胁
	var nf := _nearest_foe_pos(u.position, u.faction)
	var d_near: float = u.position.distance_to(nf) if nf != Vector2.INF else 1.0e20
	var melee_110: bool = threat != null and u.position.distance_to(threat.position) <= 110.0
	# P1 退守/隔挡：残血或被贴脸 → 避战拉开 / 冰墙隔挡（被一两个小兵追且血>1/5 则不退，回身放招反打）
	if (hp_frac <= 0.45 or melee_110) and not _brave_retaliate(u):
		if u.stance != Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_PASSIVE)
		if u.slot_ready(1) and threat != null:
			var awy := (u.position - threat.position).normalized()
			if _ai_cast_slot(u, 1, u.position - awy * 120.0):   # 冰墙横在身前阻路
				return
		_ai_move(u, _retreat_point(u,160.0))
		return
	elif u.stance == Unit.STANCE_PASSIVE:
		u.set_stance(Unit.STANCE_AGGRO)   # 脱离威胁、血也够 → 恢复远程索敌
		u._home = u.position
	# P2 R 画龙点睛：交战中召龙（radius=0，brain 直接 _begin_cast 不受附近判定限制）
	if u.slot_ready(3) and nf != Vector2.INF and d_near <= 720.0:
		if _ai_cast_slot(u, 3, u.position):
			return
	# P3 Q 黑雨：敌成堆且血健康（黑雨随身，身体需靠近敌群）
	if u.slot_ready(0) and hp_frac > 0.5 and _foe_count_within(u.position, 180.0, u.faction) >= 2:
		if _ai_cast_slot(u, 0, u.position):
			return
	# P4 W 冰墙进攻：拦截冲脸骑兵
	if u.slot_ready(1) and threat != null and threat.is_cavalry \
			and u.position.distance_to(threat.position) <= 220.0:
		var awy2 := (u.position - threat.position).normalized()
		if _ai_cast_slot(u, 1, u.position - awy2 * 120.0):
			return
	# P5 站位：太近则后撤一点；够不着(站桩真空)且无近战威胁且血健康 → 攻击移动压进 ~180 射程
	if d_near < 160.0 and threat != null:
		_ai_move(u, u.position + (u.position -threat.position).normalized() * 70.0)
	elif d_near > u.atk_range and hp_frac > 0.5:
		_ai_push_into_range(u, nf, u.atk_range - 20.0)


## 宋江·指挥：站队伍质心放光环/群体增益。Q 群回血+狂攻 / R 群英急救（与 Q 互斥，R 会顶掉 Q）/
## E 火攻砸敌群 / W 全队加速追击。残血贴脸→先自救再撤。
func _brain_song(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var hpf := u.hp / u.max_hp
	var melee_near := _foe_within(u.position, 60.0, u.faction)
	# P1 退守（残血且贴脸）：先自救 Q / R 再撤（被一两个小兵追且血>1/5 则不撤，靠 P2/P3 边奶边打）
	if hpf < 0.45 and melee_near and not _brave_retaliate(u):
		if u.slot_ready(0):
			if _ai_cast_slot(u, 0, u.position):
				return
		if u.slot_ready(3) and u.slot_has_active(3):
			if _ai_cast_slot(u, 3, u.position):
				return
		if u.stance != Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_PASSIVE)
		_ai_move(u, _retreat_point(u,120.0))
		return
	elif hpf >= 0.6 and u.stance == Unit.STANCE_PASSIVE:
		u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position
	# P2 R 号令众将（群英急救）：≥2 英雄、有人残血，且此刻 Q 不更急需（R 会顶掉 Q 进 CD）
	if u.slot_ready(3) and u.slot_has_active(3):
		if _count_ally_heroes(u.faction) >= 2 and _ally_hero_hurt(u.faction, 0.6) \
				and not _ally_hurt_within(u.position, 200.0, u.faction, 0.6, true):
			if _ai_cast_slot(u, 3, u.position):
				return
	# P3 Q 替天行道（群体回血+狂攻 60%）
	if u.slot_ready(0):
		var allies := _ally_combat_count_within(u.position, 200.0, u.faction)
		if (allies >= 3 and _foe_within(u.position, 220.0, u.faction)) \
				or _ally_hurt_within(u.position, 200.0, u.faction, 0.6):
			if _ai_cast_slot(u, 0, u.position):
				return
	# P4 E 火攻连营（超视距·有 CD 就放：优先砸最密敌群，太远则砸最近敌，≤520）
	if u.slot_ready(2):
		var fp := _densest_foe_pos(u.faction, 100.0)
		if fp == Vector2.INF or u.position.distance_to(fp) > 520.0:
			fp = _nearest_foe_pos(u.position, u.faction)
		if fp != Vector2.INF and u.position.distance_to(fp) <= 520.0:
			if _ai_cast_slot(u, 2, fp):
				return
	# P5 W 神行号令（全队加速，团战追击/扑后排时）
	if u.slot_ready(1) and _ally_combat_count_within(u.position, 190.0, u.faction) >= 2 \
			and _foe_within(u.position, 240.0, u.faction):
		if _ai_cast_slot(u, 1, u.position):
			return
	# P6 站位：太靠前→退到 buff 圈后沿；掉队→归队；都不满足且敌中距(360,520]→压进火攻射程
	var c := _ally_combat_centroid(u.faction)
	var front := _nearest_foe_pos(u.position, u.faction)
	if front != Vector2.INF and u.position.distance_to(front) < 90.0:
		_ai_move(u, u.position + (u.position -front).normalized() * 70.0)
	elif c != Vector2.INF and u.position.distance_to(c) > 120.0:
		_ai_move(u, c)
	elif front != Vector2.INF and u.position.distance_to(front) <= 520.0:
		_ai_push_into_range(u, front, 340.0)


## 采金循环中的农民（去采 / 运回）→ 进入「相位」彼此穿过，不在矿口/运线上互相卡位。
func _gold_phasing(u: Unit) -> bool:
	return u.is_worker and u._carry_kind == "gold" \
		and (u._state == Unit.ST_GATHER or u._state == Unit.ST_RETURN)


func _separation_pass(_delta: float) -> void:
	var n := units.size()
	for i in range(n):
		var a: Unit = units[i]
		if a.is_building or a.hp <= 0.0 or a.garrisoned:
			continue
		for j in range(i + 1, n):
			var b: Unit = units[j]
			if b.is_building or b.hp <= 0.0 or b.garrisoned:
				continue
			# 采金农民「相位」：两个都在采/运金矿循环时彼此不卡位，免得挤在矿口互相推开采不到
			# （采木头不需要——林木分散，不会扎堆；只对金矿放行）
			if _gold_phasing(a) and _gold_phasing(b):
				continue
			var diff := a.position - b.position
			var d := diff.length()
			var min_d := a.radius + b.radius + 2.0
			if d < min_d and d > 0.01:
				# 非对称分离：行进中的单位多让位、静止单位少挪动 → 站桩的不被推得乱抖
				var a_mv := a._state == Unit.ST_MOVE or a._state == Unit.ST_AMOVE or a._state == Unit.ST_CHASE
				var b_mv := b._state == Unit.ST_MOVE or b._state == Unit.ST_AMOVE or b._state == Unit.ST_CHASE
				var aw := 0.5
				var bw := 0.5
				if a_mv and not b_mv:
					aw = 0.85; bw = 0.15
				elif b_mv and not a_mv:
					aw = 0.15; bw = 0.85
				var dirn := diff / d
				var overlap := min_d - d
				var ap := a.position + dirn * overlap * aw
				var bp := b.position - dirn * overlap * bw
				if map.is_open_world(ap):
					a.position = ap
				if map.is_open_world(bp):
					b.position = bp


## ---------- 选取与指挥 ----------

func _unhandled_input(event: InputEvent) -> void:
	# 开战(FIGHT)之前一律不接收对单位的操作：旁白/布阵/结算阶段不能选取或指挥单位。
	# （镜头平移缩放在 RTSCamera 里另行处理，「开战」按钮是 HUD 控件，二者不受影响。）
	if phase != Phase.FIGHT:
		return
	if event is InputEventScreenTouch:
		if not _touch_mode:
			_touch_mode = true   # 进入触摸交互模式 → 通知 HUD 切到触屏布局（屏上操作栏/编队条/长按出说明）
			if hud != null:
				hud.set_touch_ui(true)
		if event.pressed and event.index >= 1:
			_dragging = false   # 第二指按下 → 双指手势（缩放/平移），取消单指框选/平移，交给相机
			_box_mode = false
			_panning = false
	# 触屏单指拖动：未进入框选 → 「拖地图」（相机平移）；长按后进入框选 → 拖出选择框。
	# 用 get_global_mouse_position()（随触摸模拟跟手）与既有框选同坐标系；平移用屏幕增量 relative/zoom。
	if event is InputEventScreenDrag and event.index == 0 and _touch_mode and _dragging:
		_drag_cur = get_global_mouse_position()
		if _build_armed != "":
			overlay.queue_redraw()   # 建造选址：单指拖动只移动虚影，不拖地图
		elif _ability_armed != "":
			overlay.queue_redraw()   # 技能瞄准：单指拖动只移动准星，不拖地图（松手才放招）
		elif _box_mode:
			overlay.queue_redraw()
		elif _panning or _drag_from.distance_to(_drag_cur) > 12.0:
			_panning = true
			camera.position -= event.relative / camera.zoom.x
		return
	if event is InputEventMouseButton:
		var p := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _build_armed != "":
					if _touch_mode:
						# 触屏：按下开始「拖动选址」，松手才落地（见下方 release 分支）；其间虚影跟手。
						_dragging = true
						_drag_from = p
						_drag_cur = p
						_box_mode = false
						_panning = false
						_press_ms = Time.get_ticks_msec()
						overlay.queue_redraw()
					else:
						_try_place_building(p)
					return
				if _ability_armed != "":
					if _touch_mode:
						# 触屏：按下开始「拖动瞄准」，松手才放招——可先按下技能再拖到合适落点(见 release 分支)
						_dragging = true
						_drag_from = p
						_drag_cur = p
						_box_mode = false
						_panning = false
						_press_ms = Time.get_ticks_msec()
						overlay.queue_redraw()
					else:
						_cast_armed_at(p)
					return
				if _amove_armed:
					_order_amove_at(p, event.shift_pressed)
					_disarm_amove()
					return
				if _repair_armed:
					_order_repair_at(p, event.shift_pressed)
					_disarm_repair()
					return
				if _garrison_armed:
					_order_garrison_at(p, event.shift_pressed)
					_disarm_garrison()
					return
				if event.double_click and not _touch_mode:
					var du := _unit_at(p)
					if du != null:
						# 双击（桌面）：选中屏幕内所有同类己方单位（经典RTS式）；建筑/敌方则只选它
						if du.faction == Unit.FACTION_LIANG and not du.is_building:
							_select_all_type(du, event.shift_pressed)
						else:
							_set_selection([du])
						return
				_dragging = true
				_drag_from = p
				_drag_cur = p
				_box_mode = false
				_panning = false
				_press_ms = Time.get_ticks_msec()
			elif _dragging:
				_dragging = false
				overlay.queue_redraw()
				if _build_armed != "" and _touch_mode:
					# 触屏：松手 → 在虚影处落地（无效则保留 armed，可重选址或点「取消」）
					_try_place_building(_drag_cur)
				elif _ability_armed != "" and _touch_mode:
					# 触屏：松手 → 在准星(手指当前处)放招（按下后可拖动调整落点/贴边滚屏，松手才结算）
					_cast_armed_at(p)
				elif _touch_mode:
					if _box_mode:
						if _drag_from.distance_to(p) >= 8.0:
							_box_select(_rect_from(_drag_from, p), event.shift_pressed)
						_box_mode = false           # 长按框选完成
					elif _panning:
						_panning = false            # 拖地图结束
					else:
						_touch_tap_or_double(p, event.shift_pressed)   # 轻点：双击选同类 / 否则点选即下令
				elif _drag_from.distance_to(p) < 8.0:
					_click_select(p, event.shift_pressed)
				else:
					_box_select(_rect_from(_drag_from, p), event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _build_armed != "":
				_cancel_build()
				return
			if _ability_armed != "":
				_disarm_ability()
				return
			if _amove_armed:
				_disarm_amove()
				return
			if _repair_armed:
				_disarm_repair()
				return
			if _garrison_armed:
				_disarm_garrison()
				return
			_issue_order(p, event.shift_pressed)
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		var num := -1
		if kc >= KEY_0 and kc <= KEY_9:
			num = kc - KEY_0
		elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
			num = kc - KEY_KP_0
		if num >= 0:
			if event.ctrl_pressed or event.meta_pressed:
				_assign_group(num)
			elif event.shift_pressed:
				_add_to_group(num)
			else:
				_recall_group(num)
		elif kc == KEY_SPACE:
			center_camera_cell(level.camera_start_cell())
		elif kc == KEY_A:
			arm_amove()
		elif kc == KEY_S:
			_order_stop()
		elif kc == KEY_P:
			_order_patrol_at(get_global_mouse_position())
		elif kc == KEY_G:
			_cycle_stance()
		elif kc == KEY_T:
			if hud != null and int(Settings.auto_micro_level) > 0:   # 「无托管」档关闭 T 热键
				if event.shift_pressed:
					hud._toggle_all_auto()        # Shift+T：全军托管
				else:
					hud.toggle_auto_selected()    # T：托管选中英雄（单个 / 编队）
		elif kc == KEY_DELETE or kc == KEY_BACKSPACE:
			delete_selected(event.shift_pressed)   # 拆除选中己方单位/建筑（Mac 上 Delete 即 Backspace；Shift 跳过确认）
		elif kc == KEY_Q:
			_command_hotkey(0)
		elif kc == KEY_W:
			_command_hotkey(1)
		elif kc == KEY_E:
			_command_hotkey(2)
		elif kc == KEY_R:
			_command_hotkey(3)
		elif kc >= KEY_F1 and kc <= KEY_F8:
			_select_hero_by_index(kc - KEY_F1)   # F1..F8 按头像栏顺序选英雄
		elif kc == KEY_TAB:
			_cycle_subgroup()
		elif kc == KEY_PERIOD or kc == KEY_COMMA:
			_cycle_idle_worker()
		elif kc == KEY_ESCAPE:
			if is_armed():
				cancel_armed()
			else:
				_open_pause()


## 「圈中带点」指向光标：注册到 CURSOR_CROSS 形状上。攻击移动(A)与指向施法
## 已经把光标切到 CURSOR_CROSS，于是这两种指令自动显示此光标，松手即恢复箭头。
func _install_target_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sz := 30
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(sz * 0.5, sz * 0.5)
	for y in range(sz):
		for x in range(sz):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d >= 10.5 and d <= 12.5:
				img.set_pixel(x, y, Color(1, 1, 1, 0.95))        # 外圈（白）
			elif (d >= 9.0 and d < 10.5) or (d > 12.5 and d <= 14.0):
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05, 0.7)) # 外圈描边
			elif d <= 2.2:
				img.set_pixel(x, y, Color(1, 1, 1, 0.95))        # 中心点
			elif d <= 3.4:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05, 0.7)) # 中心点描边
	_target_cursor = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(_target_cursor, Input.CURSOR_CROSS, c)
	# 情境悬停光标：每种动作=不同颜色+不同图标，一眼区分。
	# 选取用「中性白」而非绿——把绿色让给「林木采集」，避免悬停树/空地都是绿环分不清。
	_cur_attack = _ring_cursor(Color(1.0, 0.28, 0.22), "dot")
	_cur_gather_wood = _ring_cursor(Color(0.38, 0.86, 0.30), "tree")   # 林木：绿环+松树
	_cur_gather_gold = _ring_cursor(Color(1.0, 0.82, 0.18), "coin")   # 金矿：金环+金锭
	_cur_repair = _ring_cursor(Color(0.4, 0.85, 1.0), "plus")          # 修理：天蓝环+加号
	_cur_garrison = _ring_cursor(Color(0.62, 0.64, 1.0), "door")      # 驻军：靛蓝环+拱门
	_cur_select = _ring_cursor(Color(0.94, 0.94, 0.80), "")           # 选取：中性米白环


const CURSOR_SZ := 38   # 光标边长（热点取一半，见 _update_hover_cursor）

## 构造一枚环形光标（更大更粗 + 中心图标 dot/tree/coin/plus/box）
func _ring_cursor(col: Color, glyph: String) -> ImageTexture:
	var sz := CURSOR_SZ
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cc := Vector2(sz * 0.5, sz * 0.5)
	var edge := Color(0.04, 0.04, 0.04, 0.9)
	for y in range(sz):
		for x in range(sz):
			var pt := Vector2(x + 0.5, y + 0.5)
			var d := pt.distance_to(cc)
			var rx := pt.x - cc.x
			var ry := pt.y - cc.y
			if d >= 12.5 and d <= 16.0:
				img.set_pixel(x, y, col)               # 粗环
			elif (d >= 10.5 and d < 12.5) or (d > 16.0 and d <= 17.5):
				img.set_pixel(x, y, edge)              # 环描边
			else:
				match glyph:
					"dot":
						if d <= 3.4: img.set_pixel(x, y, col)
						elif d <= 4.6: img.set_pixel(x, y, edge)
					"tree":   # 松树：上窄下宽的三角树冠 + 树干
						if ry >= -6.0 and ry <= 3.0 and absf(rx) <= (ry + 6.5) * 0.52:
							img.set_pixel(x, y, col)
						elif ry > 3.0 and ry <= 6.0 and absf(rx) <= 1.6:
							img.set_pixel(x, y, col)
					"coin":   # 金锭：菱形元宝
						if absf(rx) + absf(ry) <= 4.6: img.set_pixel(x, y, col)
						elif absf(rx) + absf(ry) <= 6.0: img.set_pixel(x, y, edge)
					"box":
						if absf(rx) <= 2.8 and absf(ry) <= 2.8: img.set_pixel(x, y, col)
					"door":   # 拱门：两根门柱 + 半圆拱顶 + 门槛 → 一眼是「进驻」
						var ax := absf(rx)
						var on_pillar := ax >= 3.2 and ax <= 4.8 and ry >= -2.0 and ry <= 5.5
						var on_arch := ry < -2.0 and absf(Vector2(rx, ry + 2.0).length() - 4.0) <= 0.95
						var on_sill := ry >= 5.5 and ry <= 6.6 and ax <= 4.8
						if on_pillar or on_arch or on_sill:
							img.set_pixel(x, y, col)
					"plus":
						if (absf(rx) <= 1.7 and absf(ry) <= 5.0) or (absf(ry) <= 1.7 and absf(rx) <= 5.0):
							img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 每帧按鼠标下内容切换悬停光标（采集/攻击/修理/选取/普通）
func _update_hover_cursor() -> void:
	if DisplayServer.get_name() == "headless" or get_tree().paused:
		return
	if _ability_armed != "" or _amove_armed or _repair_armed or _garrison_armed or _build_armed != "":
		return   # 指向态自管光标
	var kind := _hover_kind_at(get_global_mouse_position())
	if kind == _hover_kind:
		return
	_hover_kind = kind
	var hot := Vector2(CURSOR_SZ * 0.5, CURSOR_SZ * 0.5)
	match kind:
		"attack": Input.set_custom_mouse_cursor(_cur_attack, Input.CURSOR_ARROW, hot)
		"gather_wood": Input.set_custom_mouse_cursor(_cur_gather_wood, Input.CURSOR_ARROW, hot)
		"gather_gold": Input.set_custom_mouse_cursor(_cur_gather_gold, Input.CURSOR_ARROW, hot)
		"build": Input.set_custom_mouse_cursor(_cur_repair, Input.CURSOR_ARROW, hot)
		"repair": Input.set_custom_mouse_cursor(_cur_repair, Input.CURSOR_ARROW, hot)
		"garrison": Input.set_custom_mouse_cursor(_cur_garrison, Input.CURSOR_ARROW, hot)
		"select": Input.set_custom_mouse_cursor(_cur_select, Input.CURSOR_ARROW, hot)
		_: Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


## 鼠标位置 p 下应显示的悬停光标种类（攻击/采集/续建/修理/驻军/选取/普通）。
## 抽成纯函数便于自检（HOVERTEST）。优先级：攻击>采集>续建>修理>驻军>选取。
func _hover_kind_at(p: Vector2) -> String:
	# 面板区判定必须用「屏幕像素」坐标：p 是世界坐标（随相机平移/缩放），
	# 而面板高度 PANEL_H 是屏幕像素——混用会让镜头一往下移就误判成「在面板上」→ 光标永远不变。
	var vs := get_viewport().get_visible_rect().size
	if get_viewport().get_mouse_position().y > vs.y - RTSCamera.PANEL_H:
		return "normal"
	# 驻军优先（与 _issue_order 一致）：悬停自家有空位的箭楼/聚义厅且选了可动单位 →「进驻」光标，
	# 即使旁边有敌人也优先——这样据守战里围攻聚义厅时也能看清并右键进驻。
	if _garrisonable_at(p) != null and not _selected_movers().is_empty():
		return "garrison"
	if _enemy_at(p) != null:
		return "attack"
	var rnode := _resource_at(p)
	if rnode != null:
		return "gather_gold" if rnode.res_kind == "gold" else "gather_wood"
	if _constructing_building_at(p) != null and _selection_has_worker():
		return "build"   # 在建工地 + 选工人 → 「续建」光标
	if _damaged_building_at(p) != null and _selection_has_worker():
		return "repair"
	if _unit_at(p) != null or _player_building_at(p) != null:
		return "select"
	return "normal"


func _selection_has_worker() -> bool:
	for u in selection:
		if is_instance_valid(u) and u.is_worker:
			return true
	return false


func _player_building_at(p: Vector2) -> Unit:
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_building and not u.is_resource and u.hp > 0.0:
			if to_screen(u.position).distance_to(p) <= u.radius + 8.0:
				return u
	return null


func _disarm_amove() -> void:
	_amove_armed = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 武装攻击移动（A 键与触屏「攻击」按钮共用）：随后点地即攻击移动。
func arm_amove() -> void:
	if selection.is_empty():
		return
	_disarm_ability()
	_cancel_build()
	_amove_armed = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _disarm_repair() -> void:
	_repair_armed = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 武装维修（农民命令卡「维修」键）：随后点己方受损建筑 → 工人前去修缮。
func arm_repair() -> void:
	if not _selection_has_worker():
		msg("先选中农民/工人，再点维修", 1.3)
		return
	_disarm_ability()
	_cancel_build()
	_disarm_amove()
	_repair_armed = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	msg("维修：点选要修缮的己方建筑", 1.5)


func _disarm_garrison() -> void:
	_garrison_armed = false
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_hover_kind = ""   # 让 _update_hover_cursor 下一帧重新按悬停内容上光标


## 武装驻扎（英雄命令卡「驻扎」键）：点亮后左键点己方箭楼/聚义厅 → 选中单位进驻。
## 英雄不再走右键自动驻扎，避免据守战里右键聚义厅误判成攻击近敌（见 _issue_order）。
func arm_garrison() -> void:
	if _selected_movers().is_empty():
		return
	_disarm_ability()
	_cancel_build()
	_disarm_amove()
	_disarm_repair()
	_garrison_armed = true
	Input.set_custom_mouse_cursor(_cur_garrison, Input.CURSOR_ARROW, Vector2(CURSOR_SZ * 0.5, CURSOR_SZ * 0.5))
	msg("驻扎：左键点选要进驻的己方建筑（箭楼/聚义厅）", 1.6)


## 武装驻扎落点：点己方有空位的箭楼/聚义厅 → 选中可动单位进驻（含英雄）。
func _order_garrison_at(p: Vector2, queued := false) -> void:
	var bld := _garrisonable_at(p)
	if bld == null:
		msg("那不是可进驻的建筑（需箭楼/聚义厅且有空位）", 1.4)
		return
	var movers := _selected_movers()
	if movers.is_empty():
		return
	var space: int = bld.garrison_cap - bld.passengers.size()
	var sent := 0
	var glp := to_logic(p)
	for u in movers:
		if sent < space:
			u.order_garrison(bld, queued)
			sent += 1
		else:
			u.order_move(glp, queued)   # 满了的就移动过去待有空位再点
	if sent > 0:
		Sfx.play("order")
		msg("驻入 %s（%d 人）" % [bld.display_name, sent], 1.2)


## 取消一切「待指向」状态（触屏取消键 / Esc / 右键共用）
func cancel_armed() -> void:
	_disarm_amove()
	_disarm_repair()
	_disarm_ability()
	_disarm_garrison()
	_cancel_build()


## 某编队当前存活成员数（触屏编队 chip 用来判断是否点亮）
func group_size(n: int) -> int:
	if not _groups.has(n):
		return 0
	return (_groups[n] as Array).filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0).size()


## 是否处于待指向态（触屏「取消」键据此显隐）
func is_armed() -> bool:
	return _amove_armed or _repair_armed or _garrison_armed or _ability_armed != "" or _build_armed != ""


## 选中并把镜头移到某单位（触屏英雄快切栏：点英雄头像直达）
func focus_unit(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	_set_selection([u])
	_center_on([u])


## F1..F8：按英雄头像栏顺序（liang_heroes 同序）选中第 idx 个英雄。
## 与点头像一致：驻军中的英雄改为「出击」，在场英雄则选中并居中。
func _select_hero_by_index(idx: int) -> void:
	var hs := liang_heroes()
	if idx < 0 or idx >= hs.size():
		return
	var h: Unit = hs[idx]
	if not is_instance_valid(h):
		return
	if h.garrisoned:
		sortie_unit(h)
	else:
		focus_unit(h)


## 全选己方军队（非工人、非建筑、未驻军的作战单位）——触屏「全军」一键
func select_all_army() -> void:
	var arr: Array = []
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and not u.is_building and not u.is_worker and not u.garrisoned:
			arr.append(u)
	if not arr.is_empty():
		_set_selection(arr)


## 当前存活的己方英雄（英雄快切栏用），按 key 稳定排序。
## 含已驻军的英雄——快切栏会标「驻」并允许点击出击（不剔除，否则进驻后英雄从栏里消失就没法点出击了）。
func liang_heroes() -> Array:
	var hs: Array = []
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and u.is_hero and not u.is_building:
			hs.append(u)
	hs.sort_custom(func(a: Unit, b: Unit) -> bool: return a.key < b.key)
	return hs


func _rect_from(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _click_select(p: Vector2, additive: bool) -> void:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 or u.is_building:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= u.radius + 10.0 and d < best_d:
			best = u
			best_d = d
	if best == null:   # 无单位时尝试选中己方建筑（聚义厅/兵营 → 训练·设集结点）
		for u in units:
			if u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 or not u.is_building or u.is_resource:
				continue
			var d: float = to_screen(u.position).distance_to(p)
			if d <= _bld_click_r(u) and d < best_d:
				best = u
				best_d = d
	if best == null and not additive:
		# 没点到己方 → 试着「查看」敌方单位（只读：高亮+看信息，但不可下令）
		var foe := _enemy_at(p)
		if foe != null:
			_set_inspect(foe)
		# 点到空地（无己方单位/建筑、无敌人）：保留当前选区，不再清空
		# （用户要求：已选中单位时，单击空地不取消选择）
		return
	var new_sel: Array = []
	if additive:
		new_sel = selection.duplicate()
	if best != null and not new_sel.has(best):
		new_sel.append(best)
	_set_selection(new_sel)


## 触屏·点选即下令（轻操作式）：点到己方单位/建筑 = 选取；点空地/敌人/资源且有选中 = 上下文指令。
func _tap_command(p: Vector2, additive: bool) -> void:
	if _friendly_at(p) != null:
		_click_select(p, additive)        # 命中己方单位/建筑 → 选取（含建筑回退、Shift 追加）
	elif not selection.is_empty():
		_issue_order(p, false)            # 点别处且有选中 → 移动/攻击/采集/进驻
	else:
		_click_select(p, additive)        # 没选中也点空地 → 清空选区


## 屏幕点下处是否有「可选的己方单位或建筑」（用于区分 tap 是选取还是下令）
func _friendly_at(p: Vector2) -> Unit:
	var u := _unit_at(p)
	if u != null:
		return u
	for b in units:
		if is_instance_valid(b) and b.faction == Unit.FACTION_LIANG and b.hp > 0.0 \
				and b.is_building and not b.is_resource \
				and to_screen(b.position).distance_to(p) <= _bld_click_r(b):
			return b
	return null


## 触屏轻点：320ms 内在同位置再点一次 = 双击选同屏同类；否则点选即下令。
func _touch_tap_or_double(p: Vector2, additive: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 360 and _last_tap_pos.distance_to(p) < 56.0:   # 高分屏手指抖动大，放宽容差
		_last_tap_ms = 0
		var du := _unit_at(p)
		if du != null and du.faction == Unit.FACTION_LIANG and not du.is_building:
			_select_all_type(du, additive)        # 双击单位 → 选同屏同类
			return
	_last_tap_ms = now
	_last_tap_pos = p
	_tap_command(p, additive)


func _box_select(rect: Rect2, additive: bool) -> void:
	var new_sel: Array = []
	if additive:
		new_sel = selection.duplicate()
	for u in units:
		if u.faction != Unit.FACTION_LIANG or u.is_building or u.garrisoned:
			continue
		if rect.has_point(to_screen(u.position)) and not new_sel.has(u):
			new_sel.append(u)
	_set_selection(new_sel)


## ---------- 英雄技能 ----------

## 当前活动单位（Tab 子组）；命令卡与 QWER 都针对它
func active_unit() -> Unit:
	if _active != null and is_instance_valid(_active) and _active.hp > 0.0 and selection.has(_active):
		return _active
	_active = _default_active()
	return _active


func _default_active() -> Unit:
	for u in selection:                       # 英雄优先
		if is_instance_valid(u) and u.hp > 0.0 and u.is_hero:
			return u
	for u in selection:
		if is_instance_valid(u) and u.hp > 0.0:
			return u
	return null


## Tab：在选区不同「类型」子组间循环切换活动单位
func _cycle_subgroup() -> void:
	if selection.size() <= 1:
		return
	var order: Array = []
	var seen := {}
	for u in selection:
		if not is_instance_valid(u) or u.hp <= 0.0:
			continue
		if not seen.has(u.key):
			seen[u.key] = true
			order.append(u)
	if order.size() <= 1:
		return
	var cur := active_unit()
	var ci := 0
	for i in range(order.size()):
		if order[i].key == cur.key:
			ci = i
			break
	_active = order[(ci + 1) % order.size()]
	_disarm_ability()
	_update_sel_label()


func cast_ability(caster: Unit, slot := 0) -> void:
	if caster == null or not is_instance_valid(caster) or not caster.slot_ready(slot):
		return
	var aid: String = caster.ability_slots[slot]["id"]
	var ad: Dictionary = _abilities[aid]
	if ad["targeted"]:
		_disarm_amove()
		_cancel_build()
		_ability_caster = caster
		_ability_armed = aid
		_ability_slot = slot
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		hud.show_message("%s · %s：左键选择目标位置" % [caster.display_name, ad["name"]], 2.5)
	else:
		_begin_cast(caster, slot, caster.position)


## QWER：对「活动英雄」的第 slot 个技能（学习/施放/提示）
## QWER 命令热键：按活动单位上下文分派（英雄技能 / 工人建造 / 建筑训练）
func _command_hotkey(slot: int) -> void:
	var au := active_unit()
	if au == null:
		return
	if au.is_hero and au.slot_count() > 0:
		_cast_ability_slot(slot)
	elif economy and au.is_worker:
		var menu := build_menu()
		if slot < menu.size():
			arm_build(String(menu[slot]["key"]))
	elif economy and au.is_building and not au.is_constructing and au.setup_def.has("produces"):
		var tm := train_menu(au)
		if slot < tm.size():
			queue_train(au, String(tm[slot]["key"]))
	elif economy and au.is_building and not au.is_constructing and au.setup_def.has("trades"):
		var trm := trade_menu(au)
		if slot < trm.size():
			do_trade(String(trm[slot]["give"]))


## 循环选中闲置喽啰（经典RTS式）
func _cycle_idle_worker() -> void:
	var idle := units.filter(func(u: Unit) -> bool:
		return is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_idle_worker())
	if idle.is_empty():
		hud.show_message("没有闲置的喽啰", 1.2)
		return
	_idle_i = _idle_i % idle.size()
	var w: Unit = idle[_idle_i]
	_idle_i += 1
	_set_selection([w])
	center_camera_cell(map.world_to_cell(w.position))


## 双击选同屏同类（经典RTS式）
func _select_all_type(proto: Unit, additive: bool) -> void:
	if proto == null or proto.faction != Unit.FACTION_LIANG or proto.is_building:
		return
	# 「屏幕内」要在 ISO 世界空间判定：to_screen(u.position) 是世界坐标，而 get_visible_rect()
	# 是屏幕像素——空间不符会几乎一个都框不中（之前双击选同类失效的根因）。这里用相机中心+缩放
	# 算出当前可见的世界矩形，再向外放宽 64px 让贴边单位也算「在屏内」。
	var vsize: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var vrect := Rect2(camera.position - vsize * 0.5, vsize).grow(64.0)
	var sel: Array = selection.duplicate() if additive else []
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 and not u.is_building and not u.garrisoned \
				and u.key == proto.key and vrect.has_point(to_screen(u.position)) and not sel.has(u):
			sel.append(u)
	_set_selection(sel)


func _cast_ability_slot(slot: int) -> void:
	var h := active_unit()
	if h == null or not h.is_hero or slot >= h.slot_count():
		return
	var s: Dictionary = h.ability_slots[slot]
	if bool(s["passive"]) and not h.slot_has_active(slot):   # 纯被动不可施放；混合被动（宋江R）可主动放
		return
	if int(s["rank"]) <= 0:
		hud.show_message("%s 尚未学习该技能（升级后点 + 学习）" % h.display_name, 1.5)
		return
	if h.slot_ready(slot):
		cast_ability(h, slot)
	else:
		hud.show_message("%s 的技能冷却中…" % h.display_name, 1.2)


## 学习/升级活动英雄的第 slot 个技能（花一点技能点）
func learn_slot(h: Unit, slot: int) -> void:
	if h == null or not is_instance_valid(h):
		return
	if not h.can_learn(slot):
		return
	h.learn(slot)
	hud.update_selection_panel(selection)


func _cast_armed_at(p: Vector2) -> void:
	var caster := _ability_caster
	var ab := _ability_armed
	var slot := _ability_slot
	_disarm_ability()
	if caster != null and is_instance_valid(caster) and slot < caster.slot_count() \
			and caster.ability_slots[slot]["id"] == ab and caster.slot_ready(slot):
		_begin_cast(caster, slot, to_logic(p))


func _disarm_ability() -> void:
	_ability_armed = ""
	_ability_caster = null
	_ability_slot = 0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 花荣·切刀/挂弓：在弓与刀之间切换（命令卡按钮触发）。
func toggle_hero_melee(hero) -> void:
	if hero == null or not is_instance_valid(hero) or not hero.can_melee_switch:
		return
	hero.toggle_melee()
	Sfx.play("click")
	hud.show_message("%s · %s" % [hero.display_name, "拔刀近战（+10%% 吸血）" if hero.melee_mode else "挂弓远射"], 1.8)
	hud.refresh_command()   # 刷新命令卡，更新「持刀/持弓」按钮态


## 施法抬手：技能不再瞬发——先让英雄抬手蓄势 CAST_WINDUP 秒（带蓄能辉光），归零后才结算。
## 目标点 lp 在点击瞬间已锁定，抬手只是表演；抬手期间技能仍占「就绪」，靠 _cast_t>0 防连发。
func _begin_cast(caster: Unit, slot: int, lp: Vector2) -> void:
	if caster == null or not is_instance_valid(caster):
		return
	if caster._cast_t > 0.0:                # 已在抬手中：忽略重复触发
		return
	var aid: String = caster.ability_slots[slot]["id"]
	var ad: Dictionary = _abilities.get(aid, {})
	var col: Color = ad.get("color", Color(0.82, 0.86, 1.0))
	if bool(ad.get("targeted", false)):
		caster._face_dir(lp - caster.position)   # 转身面向施法点：方向型技能抬手更自然
	caster.begin_cast_windup(CAST_WINDUP, col)
	_pending_casts.append({"caster": caster, "slot": slot, "lp": lp})
	Sfx.play("cast", -0.6, 0.05, 90)        # 抬手蓄能轻响（结算时各分支另有命中声）


## 抬手结算：每帧检查待结算队列，施法者抬手归零即真正放招（死亡/失效则丢弃）。
func _tick_pending_casts() -> void:
	if _pending_casts.is_empty():
		return
	var keep: Array = []
	for pc in _pending_casts:
		var c: Unit = pc["caster"]
		if c == null or not is_instance_valid(c) or c.hp <= 0.0:
			continue                        # 抬手途中阵亡：取消
		if c._cast_t > 0.0:
			keep.append(pc)                 # 仍在抬手
		else:
			_do_ability(c, int(pc["slot"]), pc["lp"])
	_pending_casts = keep


## 技能音效名：签名 id 优先，否则按 effect.kind，再退 "cast"。
func _ability_sfx(aid: String, kind: String) -> String:
	if ABILITY_SFX_ID.has(aid):
		return ABILITY_SFX_ID[aid]
	return ABILITY_SFX_KIND.get(kind, "cast")


## 数据化技能结算：按 effect.kind 统一处理；伤害/治疗随技能等级缩放。
func _do_ability(caster: Unit, slot: int, lp: Vector2) -> void:
	if not is_instance_valid(caster) or not caster.slot_ready(slot):
		return
	var aid: String = caster.ability_slots[slot]["id"]
	var ad: Dictionary = _abilities[aid]
	if level.on_ability(self, caster, aid, lp):
		caster.slot_start_cd(slot)
		return
	var rank := int(caster.ability_slots[slot]["rank"])
	var sc := 0.6 + 0.4 * float(rank)     # rank1=1.0 rank2=1.4 rank3=1.8
	var eff: Dictionary = ad.get("effect", {})
	Sfx.play(_ability_sfx(aid, String(eff.get("kind", ""))), 0.0, 0.05, 60)   # 技能专属音（按 id/种类区分）
	# 花荣大招·换刀：切换弓/刀，非伤害技，单独处理。
	if String(eff.get("kind", "")) == "weapon_toggle":
		caster.toggle_melee()
		_spawn_ability_fx(caster.position, 46.0, ad["color"])
		hud.show_message("%s · %s" % [caster.display_name, "拔刀近战（+10%% 吸血）" if caster.melee_mode else "挂弓远射"], 1.8)
		caster.slot_start_cd(slot)
		hud.refresh_command()
		return
	var r: float = ad["radius"]
	var center: Vector2 = lp if ad["targeted"] else caster.position
	# 指向型技能打到阴影区 → 短暂照亮落点（花荣箭雨/宋江放火等：「看清自己往哪儿打」）
	if bool(ad.get("targeted", false)):
		_reveal_fog_at(center, r + 40.0, 6.0)
	var ally := caster.faction
	var foe := Unit.FACTION_GUAN if ally == Unit.FACTION_LIANG else Unit.FACTION_LIANG
	var snap := units.duplicate()
	# 施放分派种类：混合被动（声明 active_kind，如宋江 R）按其主动种类走；其余按 effect.kind
	var cast_kind := String(eff["active_kind"]) if eff.has("active_kind") else String(eff.get("kind", ""))
	match cast_kind:
		"rally_heroes":   # 宋江 R·号令众将：所有友方英雄回血(=Q回血量)，并让宋江 Q 同时转入冷却
			var qheal := 0.0
			var qslot := -1
			for qi in caster.slot_count():
				var qeff: Dictionary = _abilities.get(String(caster.ability_slots[qi]["id"]), {}).get("effect", {})
				if String(qeff.get("kind", "")) == "rally":
					qslot = qi
					var qrank := maxi(1, int(caster.ability_slots[qi]["rank"]))
					qheal = float(qeff.get("heal", 0.0)) * (0.6 + 0.4 * float(qrank))   # = Q 当前等级的回血量
					break
			for u in snap:
				if is_instance_valid(u) and u.faction == ally and u.is_hero and u.hp > 0.0 and not u.garrisoned:
					u.heal(qheal)
					spawn_impact(u.position + Vector2(0, -10), false)   # 群英金光
			if qslot >= 0:
				caster.slot_start_cd(qslot)   # Q 同步进入冷却
		"rally":
			for u in snap:
				if is_instance_valid(u) and u.faction == ally and not u.is_building and not u.garrisoned and u.hp > 0.0 \
						and caster.position.distance_to(u.position) <= r:
					u.heal(float(eff["heal"]) * sc)
					u.apply_temp_atk(eff["atk_mult"], eff["dur"])
					spawn_impact(u.position + Vector2(0, -10), false)   # 鼓舞金光
		"haste":
			for u in snap:
				if is_instance_valid(u) and u.faction == ally and not u.is_building and not u.garrisoned and u.hp > 0.0 \
						and caster.position.distance_to(u.position) <= r:
					u.apply_slow(eff["speed_mult"], eff["dur"])
		"smite":
			for u in snap:
				if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
						and center.distance_to(u.position) <= r:
					var dmg: float = float(eff["dmg"]) * sc
					if eff.get("cav_bonus", 0.0) > 0.0 and u.is_cavalry:
						dmg *= eff["cav_bonus"]
					if eff.get("slow", 0.0) > 0.0:
						u.apply_slow(eff["slow"], eff["slow_dur"])
					if eff.get("stun", 0.0) > 0.0:
						u.apply_stun(eff["stun"])   # 踩地板·震晕：暂停移动与攻击
					if eff.has("def_down"):
						u.apply_def_down(float(_pick(eff["def_down"], rank)), float(eff.get("def_down_dur", 8.0)))   # 双戒刀·削甲
					if eff.has("blind"):
						u.apply_blind(float(eff["blind"]))   # 双戒刀·致盲：周围敌军攻击必失
					u.take_damage(dmg, caster)
					spawn_impact(u.position, true)   # 命中火花
			if eff.get("self_atk", 0.0) > 0.0:
				caster.apply_temp_atk(eff["self_atk"], eff["self_dur"])
			if eff.get("self_lifesteal", 0.0) > 0.0:
				caster.apply_lifesteal(eff["self_lifesteal"], eff["self_lifesteal_dur"])
		"debuff":
			for u in snap:
				if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
						and center.distance_to(u.position) <= r:
					u.apply_slow(eff["slow"], eff["dur"])
					u.apply_temp_atk(eff["atk_mult"], eff["dur"])
		"drag":
			for u in snap:
				if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
						and center.distance_to(u.position) <= r:
					var wdir := _nearest_water_dir(u.position)
					if wdir != Vector2.ZERO:
						var np: Vector2 = u.position + wdir * 36.0
						if map.is_open_world(np):
							u.position = np
					u.take_damage(float(eff["dmg"]) * sc, caster)
		"line_nuke":   # 林冲 Q·破阵突刺：从施法者朝指向贯穿一条矩形带
			var ldir := center - caster.position
			if ldir.length() < 1.0:
				ldir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
			ldir = ldir.normalized()
			var llen := float(eff.get("len", r))
			var lhw := float(eff.get("width", 48.0)) * 0.5
			for u in snap:
				if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
						and _in_capsule(caster.position, ldir, llen, lhw + u.radius, u.position):
					if eff.get("slow", 0.0) > 0.0:
						u.apply_slow(eff["slow"], eff["slow_dur"])
					u.take_damage(float(eff["dmg"]) * sc, caster)
					spawn_impact(u.position, true)
		"blink_shot":   # 花荣 Q·凌空闪：沿箭路伤害 + 闪现到落点
			var bdir := center - caster.position
			if bdir.length() < 1.0:
				bdir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
			bdir = bdir.normalized()
			var blen := minf(float(eff.get("len", r)), maxf(60.0, caster.position.distance_to(center)))
			var bhw := float(eff.get("width", 42.0)) * 0.5
			for u in snap:
				if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
						and _in_capsule(caster.position, bdir, blen, bhw + u.radius, u.position):
					u.take_damage(float(eff["dmg"]) * sc, caster)
					spawn_impact(u.position, true)
			var bstart := caster.position
			var bend := caster.position + bdir * blen
			var bcell := map.nearest_open(map.world_to_cell(bend))
			caster.position = map.cell_to_world(bcell)
			var bfx := BlinkShotFx.new()           # 穿云箭流光 + 起落双闪
			bfx.start_w = bstart
			bfx.end_w = caster.position
			bfx.col = ad["color"]
			fx_root.add_child(bfx)
			shake(2.5, caster.position)
			center = caster.position   # 后续华丽演出落在新位置
		"charge":   # 李逵 W·莽撞冲锋：蓄力后朝指向猛冲（结算在 unit._do_charge_step）
			var cdir := center - caster.position
			caster._begin_charge(cdir, float(eff["dmg"]) * sc, float(eff.get("windup", 1.0)),
				float(eff.get("dist", 200.0)), float(eff.get("width", 54.0)),
				float(eff.get("slow", 0.0)), float(eff.get("slow_dur", 1.0)))
		"sector_nuke":   # 花荣 W·箭雨扇击：朝指向的前方扇形区域
			var sdir := center - caster.position
			if sdir.length() < 1.0:
				sdir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
			sdir = sdir.normalized()
			var srange := float(eff.get("range", r))
			var shalf := deg_to_rad(float(eff.get("arc", 60.0)) * 0.5)
			for u in snap:
				if not (is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource):
					continue
				var rel: Vector2 = u.position - caster.position
				var dd := rel.length()
				if dd > srange + float(u.radius):
					continue
				if dd > 1.0 and absf(rel.angle_to(sdir)) > shalf:
					continue
				if eff.get("slow", 0.0) > 0.0:
					u.apply_slow(eff["slow"], eff["slow_dur"])
				u.take_damage(float(eff["dmg"]) * sc, caster)
				spawn_impact(u.position, true)
			center = caster.position + sdir * clampf(caster.position.distance_to(center), 50.0, srange * 0.95)   # 演出贯穿到扇区前沿(与真实伤害范围一致)
		"orbit_axes":   # 李逵 Q·双斧回旋：绕身持续扫伤的区域，跟随施法者
			_orbit_zones.append({"caster": caster, "foe": foe, "r": r, "t": float(eff.get("dur", 3.0)),
				"tick": float(eff.get("tick", 0.5)), "tick_t": float(eff.get("tick", 0.5)),
				"dmg": float(eff["dmg"]) * sc, "slow": float(eff.get("slow", 0.0)), "slow_dur": float(eff.get("slow_dur", 1.0))})
			var oax := OrbitAxesFx.new()
			oax.target = caster
			oax.rad = r
			oax.col = ad["color"]
			oax.life = float(eff.get("dur", 3.0))
			fx_root.add_child(oax)
		"chrono":   # 林冲 R·时空封印：域内敌军定身（每帧续晕）持续 dur；封印范围随等级 radius_ranks 扩大
			var cr := r
			if eff.has("radius_ranks"):
				cr = float(_pick(eff["radius_ranks"], rank))
			_chrono_zones.append({"pos": center, "r": cr, "foe": foe, "t": float(eff.get("dur", 10.0))})
			var cz := ChronoFx.new()
			cz.position = center
			cz.rad = cr
			cz.col = ad["color"]
			cz.life = float(eff.get("dur", 10.0))
			fx_root.add_child(cz)
			shake(4.0, center)
		"self_buff":   # 李逵 R·嗜血暴走：自身平攻 +N、吸血拉满
			caster.apply_temp_atk_add(float(eff.get("atk_add", 0.0)) * sc, float(eff.get("dur", 5.0)))
			caster.apply_lifesteal(float(eff.get("lifesteal", 1.0)), float(eff.get("dur", 5.0)))
		"summon":   # 召唤物：武松·驱使猛虎 / 公孙胜·画龙点睛
			_do_summon(caster, eff, rank)
		"black_rain":   # 公孙胜 Q·黑雨：以己为心随身移动的 DOT；每秒伤害/时长随等级
			var br_dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 6.0))
			var br_dps := float(_pick(eff["dps_ranks"], rank)) if eff.has("dps_ranks") else (float(eff["dmg"]) * sc / maxf(br_dur, 0.1))
			var br_follow: Unit = caster if bool(eff.get("follow", false)) else null
			var br_center: Vector2 = caster.position if br_follow != null else center
			_spawn_black_rain(br_center, r, br_dps * br_dur, br_dur, caster, foe, br_follow)
		"ice_wall":   # 公孙胜 W·冰墙：少量伤害 + 阻隔敌军移动
			_do_ice_wall(caster, eff, sc, center, foe, ad["color"])
		"drunk_buff":   # 武松 W·三碗不过岗：移动/攻速随机波动
			caster.start_drunk(float(_pick(eff.get("lo", [0.9]), rank)), float(_pick(eff.get("hi", [1.3]), rank)), float(eff.get("dur", 30.0)))
		"drunk_god":   # 武松 R·醉神大闹快活林：物免 + 每击加攻 + 结束转血
			caster.start_drunk_god(float(_pick(eff.get("bonus", [10.0]), rank)), float(eff.get("dur", 20.0)))
	if String(eff.get("kind", "")) == "fire_dot":
		var fd_dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 5.0))
		var fd_total := (float(eff["dps"]) * fd_dur) if eff.has("dps") else (float(eff["dmg"]) * sc)
		_spawn_ground_fire(center, r, fd_total, fd_dur, caster, foe)
	if eff.has("dot_total"):   # 普通技附带地面持续伤害（如箭雨钉地续伤），不挂火焰演出，沿用本招演出
		_add_ground_dot(center, r, float(eff["dot_total"]) * sc, float(eff.get("dot_dur", 3.0)), caster, foe)
	if String(eff.get("kind", "")) != "sector_nuke":   # 扇形突刺(林冲戳茅)不画整圈大光环——与前方扇形伤害不符，只留长枪贯穿演出
		_spawn_ability_fx(center, r, ad["color"])
	_spawn_hero_skill_fx(aid, caster, center, ad)   # 英雄专属华丽演出（花荣箭雨/神箭…）
	hud.show_message("【%s】" % ad["name"], 1.8)
	caster.slot_start_cd(slot)
	# 技能音已在函数开头按 id/种类播放，这里不再重复


## 点 p 是否落在「从 origin 沿 dir 长 len、半宽 hw」的胶囊带内（线形/冲锋判定共用）。
func _in_capsule(origin: Vector2, dir: Vector2, length: float, hw: float, p: Vector2) -> bool:
	var rel := p - origin
	var along := rel.dot(dir)
	if along < -hw or along > length + hw:
		return false
	var perp := absf(rel.dot(Vector2(-dir.y, dir.x)))
	return perp <= hw


## 时空封印 + 双斧回旋：每帧推进。封印域内敌军反复续晕（定身）；回旋区按节拍扫伤减速。
func _zone_pass(delta: float) -> void:
	# 时空封印：域内敌军每帧续 0.2s 晕 → 持续定身（不可动/不攻击）。施法者/友军不受影响。
	if not _chrono_zones.is_empty():
		for z in _chrono_zones:
			z["t"] = float(z["t"]) - delta
			var zp: Vector2 = z["pos"]
			var zr: float = z["r"]
			var zfoe: int = int(z["foe"])
			for u in units:
				if is_instance_valid(u) and u.faction == zfoe and u.hp > 0.0 and not u.is_building \
						and not u.is_resource and not u.garrisoned and zp.distance_to(u.position) <= zr:
					u.apply_stun(maxf(0.22, delta * 2.0))
		_chrono_zones = _chrono_zones.filter(func(z): return float(z["t"]) > 0.0)
	# 双斧回旋：跟随施法者，按节拍对周围敌军扫伤减速。
	if not _orbit_zones.is_empty():
		for z in _orbit_zones:
			z["t"] = float(z["t"]) - delta
			z["tick_t"] = float(z["tick_t"]) - delta
			var src = z["caster"]   # 同 _ground_dot_pass：不加类型注解，避免对已释放施法者赋值时直接报错
			if not is_instance_valid(src) or src.hp <= 0.0:
				z["t"] = 0.0
				continue
			if float(z["tick_t"]) <= 1e-4:
				z["tick_t"] = float(z["tick_t"]) + float(z["tick"])
				var zr2: float = z["r"]
				var zfoe2: int = int(z["foe"])
				for u in units:
					if is_instance_valid(u) and u.faction == zfoe2 and u.hp > 0.0 and not u.is_resource \
							and not u.garrisoned and src.position.distance_to(u.position) <= zr2:
						if float(z["slow"]) > 0.0:
							u.apply_slow(float(z["slow"]), float(z["slow_dur"]))
						u.take_damage(float(z["dmg"]), src)
						spawn_impact(u.position, false)
		_orbit_zones = _orbit_zones.filter(func(z): return float(z["t"]) > 0.0)


func _nearest_water_dir(p: Vector2) -> Vector2:
	var c := map.world_to_cell(p)
	for radius in range(1, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				if map.t_at(c.x + dx, c.y + dy) == GameMap.T.WATER:
					return Vector2(dx, dy).normalized()
	return Vector2.ZERO


func _spawn_ability_fx(lp: Vector2, r: float, col: Color) -> void:
	var fx := AbilityFx.new()
	fx.position = lp
	fx.rad = r
	fx.col = col
	fx_root.add_child(fx)
	# 大招炸响 → 屏震（按范围给强度，仅可见区域附近）
	shake(clampf(r / 14.0, 2.0, 6.0), lp)


## 地面烈焰 DOT：在 center 铺一片燃烧区，dur 秒内按固定节拍分多次跳伤敌人（累计 total），
## 配 GroundFireFx 持续火焰演出。伤害结算在 _ground_dot_pass（施法者可中途阵亡，火照烧）。
func _pick(arr, rank: int):
	if arr is Array and (arr as Array).size() > 0:
		return arr[clampi(rank - 1, 0, (arr as Array).size() - 1)]
	return arr


func _nearest_foe_pos(from: Vector2, my_fac: int) -> Vector2:
	var best := Vector2.INF
	var bd := 1.0e20
	for u in units:
		if is_instance_valid(u) and u.faction != my_fac and not u.is_building and not u.is_resource and not u.garrisoned and not u.is_captive and u.hp > 0.0:
			var d := from.distance_to(u.position)
			if d < bd:
				bd = d
				best = u.position
	return best


## ───────────────── 托管 AI 通用工具（faction 过滤，绝不命中己方召唤物）─────────────────

## 最近的敌方『单位』（非位置），可按类别过滤：only_cav=只骑兵 / only_ranged=只远程 / only_melee=非远程(含骑兵)。
func _nearest_foe_unit(from: Vector2, my_fac: int, only_cav := false, only_ranged := false, only_melee := false, chaser: Unit = null) -> Unit:
	var best: Unit = null
	var bd := 1.0e20
	for v in units:
		if not is_instance_valid(v) or v.faction == my_fac or v.is_building or v.is_resource \
				or v.garrisoned or v.is_captive or v.hp <= 0.0:
			continue
		if chaser != null and chaser.chase_blocked(v):
			continue   # 追击放弃冷却中：本单位暂不重锁该目标（取次近的）
		if only_cav and not v.is_cavalry:
			continue
		if only_ranged and not v.is_ranged:
			continue
		if only_melee and v.is_ranged:
			continue
		var d := from.distance_to(v.position)
		if d < bd:
			bd = d
			best = v
	return best


## 集火目标（托管智商↑）：reach 内挑「最该先杀」的敌——敌将＞投石＞远程脆皮，残血可秒优先，越近越好。
## 带去抖加权：当前目标仍有效就略加分，避免每拍换目标抖动。近战脑兜底索敌用。
func _focus_target(u: Unit, reach: float) -> Unit:
	var best: Unit = null
	var best_s := -1.0e20
	for v in units:
		if not (is_instance_valid(v) and v.faction != u.faction and not v.is_building \
				and not v.is_resource and not v.garrisoned and not v.is_captive and v.hp > 0.0):
			continue
		if u.chase_blocked(v):
			continue   # 刚追不上放弃的目标：冷却期内不再集火（免得立刻又锁回去一路追）
		var d := u.position.distance_to(v.position)
		if d > reach:
			continue
		var s := -d                                       # 近优先（基准）
		if v.is_hero:
			s += 320.0                                    # 敌将最该集火
		elif String(v.key).begins_with("siege"):
			s += 240.0                                    # 投石车（破基地/箭楼）次之
		elif v.is_ranged:
			s += 150.0                                    # 远程脆皮
		s += (1.0 - v.hp / maxf(v.max_hp, 1.0)) * 170.0   # 残血可秒：先收掉，少一个输出源
		if v == u._target:
			s += 90.0                                     # 粘滞防抖：略偏向保持现目标
		if s > best_s:
			best_s = s
			best = v
	return best


## 近战脑统一的「集火索敌」兜底：reach 内有高价值/残血目标就 order_attack(去抖)，没有则攻击移动压上最近敌。
func _engage_focus(u: Unit, fp: Vector2) -> void:
	var tgt := _focus_target(u, maxf(300.0, u.aggro_range))
	if tgt != null:
		if u._target != tgt:
			u.order_attack(tgt)
		return
	_ai_push_into_range(u, fp, 90.0)


## 半径内敌方单位计数（want_cav=只数骑兵 / want_melee=只数非远程，含骑兵）。
func _foe_count_within(pos: Vector2, r: float, my_fac: int, want_cav := false, want_melee := false) -> int:
	var c := 0
	for v in units:
		if not is_instance_valid(v) or v.faction == my_fac or v.is_building or v.is_resource \
				or v.garrisoned or v.is_captive or v.hp <= 0.0:
			continue
		if want_cav and not v.is_cavalry:
			continue
		if want_melee and v.is_ranged:
			continue
		if pos.distance_to(v.position) <= r:
			c += 1
	return c


## 半径内是否有敌方英雄（林冲 R / 武松 R 开大判定）。
func _any_enemy_hero_within(pos: Vector2, r: float, my_fac: int) -> bool:
	for v in units:
		if is_instance_valid(v) and v.faction != my_fac and v.is_hero and v.hp > 0.0 \
				and not v.is_building and pos.distance_to(v.position) <= r:
			return true
	return false


## 存活的己方召唤物计数（武松只在场上<2 只虎时再召）。tiger_summon 带 cavalry:true，故按 faction 过滤绝不误数。
func _count_my_summons(owner_fac: int, kind: String) -> int:
	var c := 0
	for v in units:
		if is_instance_valid(v) and v.faction == owner_fac and v.is_summon and v.summon_kind == kind and v.hp > 0.0:
			c += 1
	return c


## 敌方最密集处的落点（AoE/大招落点：宋江火攻/花荣箭雨/林冲 R）。无敌返回 INF；仅 1 敌返回其位置。
func _densest_foe_pos(my_fac: int, sample_r: float) -> Vector2:
	var foes: Array = []
	for v in units:
		if is_instance_valid(v) and v.faction != my_fac and not v.is_building and not v.is_resource \
				and not v.garrisoned and not v.is_captive and v.hp > 0.0:
			foes.append(v)
	if foes.is_empty():
		return Vector2.INF
	if foes.size() == 1:
		return foes[0].position
	var best: Vector2 = foes[0].position
	var bestn := -1
	for a in foes:
		var n := 0
		for b in foes:
			if a.position.distance_to(b.position) <= sample_r:
				n += 1
		if n > bestn:
			bestn = n
			best = a.position
	return best


## 可走的撤退点：朝远离最近敌的方向退 kite_dist；无敌则退向聚义厅；落点不可走则吸附到最近开阔格。
func _retreat_point(u: Unit, kite_dist: float) -> Vector2:
	var fp := _nearest_foe_pos(u.position, u.faction)
	var p: Vector2
	if fp == Vector2.INF:
		var base := main_base(u.faction)
		p = base.position if base != null else u.position
	else:
		p = u.position + (u.position - fp).normalized() * kite_dist
	if not map.is_open_world(p):
		p = map.cell_to_world(map.nearest_open(map.world_to_cell(p)))
	return p


## 抬手守卫的单次放招：就绪且未抬手且落点有效→放并返回 true（调用方据此 return）。非指向传 lp=自身位置。
func _ai_cast_slot(u: Unit, slot: int, lp: Vector2) -> bool:
	if u._cast_t > 0.0 or not u.slot_ready(slot) or lp == Vector2.INF:
		return false
	_begin_cast(u, slot, lp)
	return true


## 托管·压上进射程：敌超出自身索敌半径(站桩真空)时，攻击移动逼近到 want_dist 处再交战。
## 仅 ST_IDLE 时发(去抖)，避战/无敌不动。返回 true=已下令（调用方据此 return）。各脑最低优先级兜底。
func _ai_push_into_range(u: Unit, foe_pos: Vector2, want_dist: float) -> bool:
	if foe_pos == Vector2.INF or u.stance == Unit.STANCE_PASSIVE or u._state != Unit.ST_IDLE:
		return false
	var d := u.position.distance_to(foe_pos)
	if d <= want_dist:
		return false
	_ai_move(u, u.position + (foe_pos - u.position).normalized() * (d - want_dist), true)
	return true


## 托管移动·去抖：目标点与上次几乎相同且已在对应移动态 → 不重发（免得每次决策都 find_path 重算、朝向来回抖）。
func _ai_move(u: Unit, dest: Vector2, amove := false) -> void:
	if dest == Vector2.INF:
		return
	var moving := u._state == (Unit.ST_AMOVE if amove else Unit.ST_MOVE)
	if moving and u._ai_dest.distance_to(dest) <= 30.0:
		return
	u._ai_dest = dest
	if amove:
		u.order_amove(dest)
	else:
		u.order_move(dest)


## ── 宋江指挥用·己方态势小工具 ──
func _count_ally_heroes(fac: int) -> int:
	var c := 0
	for v in units:
		if is_instance_valid(v) and v.faction == fac and v.is_hero and v.hp > 0.0 and not v.is_building:
			c += 1
	return c


func _ally_hero_hurt(fac: int, thr: float) -> bool:
	for v in units:
		if is_instance_valid(v) and v.faction == fac and v.is_hero and v.hp > 0.0 and not v.is_building \
				and v.hp / v.max_hp < thr:
			return true
	return false


## 半径内是否有受伤的己方作战单位（troops_only=只看非英雄小兵——用于 R/Q 互斥判定）。
func _ally_hurt_within(pos: Vector2, r: float, fac: int, thr: float, troops_only := false) -> bool:
	for v in units:
		if not is_instance_valid(v) or v.faction != fac or v.is_building or v.is_resource \
				or v.garrisoned or v.hp <= 0.0:
			continue
		if troops_only and v.is_hero:
			continue
		if v.hp / v.max_hp < thr and pos.distance_to(v.position) <= r:
			return true
	return false


func _ally_combat_count_within(pos: Vector2, r: float, fac: int) -> int:
	var c := 0
	for v in units:
		if not is_instance_valid(v) or v.faction != fac or v.is_building or v.is_resource \
				or v.garrisoned or v.is_worker or v.hp <= 0.0:
			continue
		if pos.distance_to(v.position) <= r:
			c += 1
	return c


func _ally_combat_centroid(fac: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for v in units:
		if not is_instance_valid(v) or v.faction != fac or v.is_building or v.is_resource \
				or v.garrisoned or v.is_worker or v.hp <= 0.0:
			continue
		sum += v.position
		n += 1
	if n == 0:
		return Vector2.INF
	return sum / float(n)


## 召唤物（虎/龙）：在施法者周围生成 count 个单位，按 copy_caster 或等级数组定血/攻；dur>0 则限时。
func _do_summon(caster: Unit, eff: Dictionary, rank: int) -> void:
	var skey := String(eff.get("unit", ""))
	if skey == "" or not _defs.has(skey):
		return
	var n := maxi(1, int(eff.get("count", 1)))
	var dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 0.0))
	var cmult := float(_pick(eff["copy_mult"], rank)) if eff.has("copy_mult") else 1.0   # copy_caster 时按等级取本体血/攻的百分比
	var skind := String(eff.get("summon_kind", ""))
	for i in n:
		var ang := TAU * (float(i) / float(n)) + 0.6
		var off := Vector2(cos(ang), sin(ang)) * (34.0 + 8.0 * float(n))
		var pos := map.cell_to_world(map.nearest_open(map.world_to_cell(caster.position + off)))
		var su := spawn_unit(skey, caster.faction, pos)
		su.is_summon = true
		su.summon_kind = skind
		if bool(eff.get("copy_caster", false)):
			su.max_hp = caster.max_hp * cmult
			su.hp = su.max_hp
			su.atk = caster.atk * cmult
			su._base_hp = su.max_hp
			su._base_atk = su.atk
		else:
			if eff.has("hp"):
				su.max_hp = float(_pick(eff["hp"], rank))
				su.hp = su.max_hp
			if eff.has("atk"):
				su.atk = float(_pick(eff["atk"], rank))
		if dur > 0.0:
			su._summon_ttl = dur
		su.set_stance(Unit.STANCE_AGGRO)   # 召唤物默认进攻姿态：自己索敌（配合 _summon_hunt_pass 持续出击）
		var tp := _nearest_foe_pos(pos, caster.faction)
		if tp != Vector2.INF and pos.distance_to(tp) < 1200.0:
			su.order_amove(tp)
		var pf := AbilityFx.new()
		pf.position = pos
		pf.rad = su.radius * 2.4
		pf.col = Color("ffd24a") if skind == "dragon" else Color("e8a23c")
		fx_root.add_child(pf)


## 召唤物到期消散：消散小特效 + 走既有死亡清理。
func despawn_summon(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	var pf := AbilityFx.new()
	pf.position = u.position
	pf.rad = u.radius * 2.0
	pf.col = Color("ffd24a") if u.summon_kind == "dragon" else Color("cfe3ff")
	fx_root.add_child(pf)
	u.take_damage(u.hp + 1.0, null)


## 黑雨 DOT（公孙胜 Q）：机制同地火，黑紫演出。
func _spawn_black_rain(center: Vector2, r: float, total: float, dur: float, caster: Unit, foe: int, follow: Unit = null) -> void:
	_add_ground_dot(center, r, total, dur, caster, foe, follow)
	var fx := BlackRainFx.new()
	fx.position = center
	fx.rad = r
	fx.life = dur
	fx.follow = follow   # 跟随施法者移动（以己为心的黑雨）
	fx_root.add_child(fx)
	shake(2.0, center)


## 冰墙（公孙胜 W）：沿垂直于施法方向布一道墙，少量伤害+减速，并把墙线格子临时锁死阻挡寻路。
func _do_ice_wall(caster: Unit, eff: Dictionary, sc: float, center: Vector2, foe: int, col: Color) -> void:
	var wdir := center - caster.position
	if wdir.length() < 1.0:
		wdir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	wdir = wdir.normalized()
	var perp := Vector2(-wdir.y, wdir.x)
	var reach := clampf(caster.position.distance_to(center), 40.0, float(eff.get("range", 170.0)))
	var wc := caster.position + wdir * reach
	var half_len := float(eff.get("len", 130.0)) * 0.5
	var dmg := float(eff.get("dmg", 18.0)) * sc
	for u in units:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
				and _in_capsule(wc - perp * half_len, perp, half_len * 2.0, 24.0 + u.radius, u.position):
			u.take_damage(dmg, caster)
			u.apply_slow(0.45, 1.4)
			spawn_impact(u.position, false)
	var cells: Array = []
	var step := float(GameMap.CELL) * 0.85
	var nseg := maxi(2, int(half_len * 2.0 / step))
	for i in range(-nseg / 2, nseg / 2 + 1):
		var wp := wc + perp * (float(i) * step)
		var cell := map.world_to_cell(wp)
		if map.is_open_cell(cell) and not _cell_has_unit(wp):
			map.astar.set_point_solid(cell, true)
			cells.append(cell)
	if not cells.is_empty():
		_ice_walls.append({"cells": cells, "t": float(eff.get("dur", 5.0))})
	var ifx := IceWallFx.new()
	ifx.position = wc
	ifx.dir = perp
	ifx.half_len = half_len
	ifx.life = float(eff.get("dur", 5.0))
	ifx.col = col
	fx_root.add_child(ifx)
	shake(2.5, wc)


func _cell_has_unit(wp: Vector2) -> bool:
	for u in units:
		if is_instance_valid(u) and not u.is_building and u.hp > 0.0 and wp.distance_to(u.position) < float(GameMap.CELL) * 0.6:
			return true
	return false


## 冰墙到期：解锁此前锁死的格子。
func _ice_wall_pass(delta: float) -> void:
	if _ice_walls.is_empty():
		return
	for w in _ice_walls:
		w["t"] = float(w["t"]) - delta
		if float(w["t"]) <= 0.0:
			for c in w["cells"]:
				map.astar.set_point_solid(c, false)
	_ice_walls = _ice_walls.filter(func(w): return float(w["t"]) > 0.0)


## 仅登记地面 DOT 伤害区（无演出）：供 fire/黑雨/箭雨续伤等共用。
func _add_ground_dot(center: Vector2, r: float, total: float, dur: float, caster: Unit, foe: int, follow: Unit = null) -> void:
	var tick := 0.5
	var ticks := maxi(1, int(round(dur / tick)))
	_ground_dots.append({
		"pos": center, "r": r, "foe": foe, "caster": caster, "follow": follow,
		"t": dur, "tick_t": tick, "tick": tick, "per": total / float(ticks)})


func _spawn_ground_fire(center: Vector2, r: float, total: float, dur: float, caster: Unit, foe: int) -> void:
	_add_ground_dot(center, r, total, dur, caster, foe)
	var fx := GroundFireFx.new()
	fx.position = center
	fx.rad = r
	fx.life = dur
	fx_root.add_child(fx)
	var ignite := FlameburstFx.new()   # 点燃瞬间一记火爆，叠在持续地火之上，起手更有冲击力
	ignite.position = center
	ignite.rad = r
	ignite.col = fx.col
	fx_root.add_child(ignite)
	shake(clampf(r / 18.0, 2.0, 4.0), center)


## 地面烈焰逐帧推进：到节拍跳伤区内敌人；区到期移除。
func _ground_dot_pass(delta: float) -> void:
	if _ground_dots.is_empty():
		return
	for d in _ground_dots:
		d["t"] = float(d["t"]) - delta
		d["tick_t"] = float(d["tick_t"]) - delta
		# 跟随型黑雨：区中心每帧跟到施法者脚下（以己为心随身移动）
		var fol = d.get("follow")
		if fol != null and is_instance_valid(fol) and fol.hp > 0.0:
			d["pos"] = fol.position
		# 容差 1e-4：t 与 tick_t 同步递减，在 DOT 到期那一帧 tick_t 常落在极小正 epsilon
		# （如 144Hz 下 +7.8e-15），用 <=0 会漏掉最后一跳 → 只结算 9/10 跳（117 而非 130）。
		if d["tick_t"] <= 1e-4:
			d["tick_t"] = float(d["tick_t"]) + float(d["tick"])
			var src = d["caster"]   # 不加 :Unit 类型注解——施法者已被释放时，对「类型变量」赋已释放实例会直接报错（在 is_instance_valid 之前）
			if not is_instance_valid(src):
				src = null
			var fpos: Vector2 = d["pos"]
			var fr: float = d["r"]
			var foe2: int = int(d["foe"])
			var per: float = float(d["per"])
			for u in units:
				if is_instance_valid(u) and u.faction == foe2 and u.hp > 0.0 and not u.garrisoned \
						and not u.is_resource and fpos.distance_to(u.position) <= fr:
					u.take_damage(per, src)
	_ground_dots = _ground_dots.filter(func(d): return float(d["t"]) > 0.0)


# 技能 id → 招式特效主题。每个英雄技能都按招式归类放一段专属演出（火攻有火、落雷有电、
# 鼓舞金光、神行疾风、横扫刀光、拖人水花、蒙药毒雾、神箭破空、飞石…）。未列者退回通用冲击波。
const ABILITY_FX := {
	"gongsun_thunder": "thunder",
	"song_rally": "rally", "chao_rally": "rally",
	"song_haste": "haste", "dai_dash": "haste",
	"lin_sweep": "spear", "lin_charge": "charge", "lin_storm": "stomp",
	"liu_cleave": "slash", "li_berserk": "stomp", "li_whirl": "whirl", "li_rage": "blood",
	"luan_smash": "slash", "hu_whips": "slash", "xu_drill": "slash",
	"lu_sweep": "slash", "wu_kick": "slash", "jiang_smash": "stomp", "shi_spear": "spear",
	"zhang_drag": "water", "bai_drug": "poison",
	"hua_rain": "arrow_rain", "hua_shot": "arrow_shot", "hua_pin": "arrow_big",
	"zhang_stone": "stone",
	# DOTA 改版：lin_thrust 长枪波 / li_charge 莽冲(复用 charge) / li_fury 暴走(复用 blood)。
	# lin_chrono(封印)、hua_blink(凌空闪)、li_axes(回旋)的演出在 _do_ability 内直接生成，不走这里。
	"lin_thrust": "thrust", "li_charge": "charge", "li_fury": "blood",
	# 新英雄：公孙胜 / 武松。黑雨·冰墙·召唤的主演出在 _do_ability 内直接生成，这里只补自身爆发类招式光。
	"wu_wine": "haste", "wu_blades": "whirl", "wu_drunkgod": "rally",
}


## 英雄专属技能演出：在通用冲击波之上叠一层「招式」动画。按 ABILITY_FX 主题分派。
func _spawn_hero_skill_fx(aid: String, caster: Unit, center: Vector2, ad: Dictionary) -> void:
	var col: Color = ad.get("color", Color.WHITE)
	var rad: float = float(ad.get("radius", 90.0))
	if rad <= 1.0:
		rad = 90.0
	match String(ABILITY_FX.get(aid, "")):
		"arrow_rain":   # 箭雨：一根根箭从天而降覆盖 AoE
			var fx := ArrowRainFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"arrow_big":   # 花荣 E·定身神箭：一根加粗破空大箭自花荣远程射向目标，命中留插地大箭 + 蓝色定身环
			var bfx := ArrowShotFx.new()
			bfx.position = caster.position + Vector2(0, -10)
			bfx.end_w = center
			bfx.big = true
			bfx.pin = true
			bfx.col = col
			fx_root.add_child(bfx)
			shake(3.0, center)
		"arrow_shot":   # 百步穿杨：一根大箭破空穿透射出
			var fx := ArrowShotFx.new()
			fx.position = caster.position + Vector2(0, -10)
			fx.end_w = center
			fx.col = col
			fx_root.add_child(fx)
			shake(2.5, center)
		"pin":   # 定身神箭：重箭钉入 + 地面尖桩定身笼 + 蓝色束缚环（与破空飞箭判然不同）
			var fx := PinFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
			shake(2.0, center)
		"spear":   # 丈八蛇矛横扫：一杆长矛蜿蜒扫过（蛇形残影），异于通用横扫
			var fx := SpearSweepFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
			shake(2.5, center)
		"thrust":   # 丈八·破阵突刺：一杆巨枪朝指向猛刺贯穿（直线长矛波）
			var fx := ThrustFx.new()
			fx.position = caster.position
			fx.end_w = center
			fx.col = col
			fx_root.add_child(fx)
			shake(3.0, caster.position)
		"stomp":   # 撼地踏（震晕控制）：地裂放射 + 尘环猛扩 + 碎石腾起
			var fx := StompFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
			shake(6.0, center)
		"whirl":   # 黑旋风：多刃绕身高速旋扫
			var fx := WhirlFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"blood":   # 嗜血狂斩：交叉血痕 + 血珠迸溅
			var fx := BloodFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"charge":   # 豹影冲锋：朝面向猛扑的残影冲线 + 前缘新月
			var fx := ChargeFx.new()
			fx.position = caster.position
			fx.rad = rad
			fx.col = col
			fx.dir = -1.0 if caster.face_left else 1.0
			fx_root.add_child(fx)
			shake(3.0, caster.position)
		"thunder":   # 落雷：一道天雷劈下 + 电火花
			var fx := LightningFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
			shake(4.0, center)
		"rally":   # 鼓舞：金光腾起 + 愈合十字
			var fx := RallyFx.new()
			fx.position = caster.position
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"haste":   # 神行：疾风纹向外扩散
			var fx := HasteFx.new()
			fx.position = caster.position
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"slash":   # 横扫：一道大刀光弧扫过 + 激波
			var fx := SlashArcFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"water":   # 拖人：水柱炸开 + 涟漪
			var fx := WaterSplashFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"poison":   # 蒙汗药：翻涌的毒雾
			var fx := PoisonCloudFx.new()
			fx.position = center
			fx.rad = rad
			fx.col = col
			fx_root.add_child(fx)
		"stone":   # 飞石：一记石子破空打去
			var fx := StoneFx.new()
			fx.position = caster.position + Vector2(0, -10)
			fx.end_w = center
			fx.col = col
			fx_root.add_child(fx)
			shake(2.0, center)


## ---------- 编队 ----------
# 一个单位可同属多个编队（Ctrl 重设该队 / Shift 并入该队，都不动其它队）——
# 例如全选 Ctrl1、再选一小队 Ctrl2，这一小队 1、2 两队都能调出。
# 角标并排显示其所属的全部队号（升序，见 _refresh_group_badges）。

func _assign_group(n: int) -> void:
	var members := selection.filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0 and not u.is_building)
	if members.is_empty():
		_groups.erase(n)
		_refresh_group_badges()
		return
	_groups[n] = members.duplicate()
	_refresh_group_badges()
	hud.show_message("编队 [%d]：%d 个单位" % [n, members.size()], 1.4)


func _add_to_group(n: int) -> void:
	var members := selection.filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0 and not u.is_building)
	if members.is_empty():
		return
	# 并入 n 队（保留 n 队原有成员 + 新增选中；不动其它队 → 可同属多队）
	var combined: Array = []
	for u in _groups.get(n, []):
		if is_instance_valid(u) and u.hp > 0.0 and not combined.has(u):
			combined.append(u)
	for u in members:
		if not combined.has(u):
			combined.append(u)
	_groups[n] = combined
	_refresh_group_badges()
	hud.show_message("编队 [%d] +%d：共 %d 个单位" % [n, members.size(), combined.size()], 1.4)


func _refresh_group_badges() -> void:
	for u in units:
		if is_instance_valid(u):
			u.group_nums = []
	var keys := _groups.keys()
	keys.sort()                                          # 升序遍历 → group_nums 天然升序
	for n in keys:
		for u in _groups[n]:
			if is_instance_valid(u) and not u.group_nums.has(n):
				u.group_nums.append(n)
	for u in units:
		if is_instance_valid(u):
			u.queue_redraw()


func _recall_group(n: int) -> void:
	if not _groups.has(n):
		return
	var members: Array = _groups[n].filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0)
	if members.is_empty():
		_groups.erase(n)
		return
	_groups[n] = members
	_set_selection(members)
	_active = _default_active()              # 每次按编队键都回到「第一个」（英雄优先），覆盖 Tab 切过的活动单位
	_update_sel_label()
	var now := Time.get_ticks_msec()
	if _last_group_key == n and now - _last_group_time < 350:
		_center_on(members)
	_last_group_key = n
	_last_group_time = now


func _center_on(members: Array) -> void:
	var c := Vector2.ZERO
	for u in members:
		c += u.position
	camera.position = to_screen(c / float(members.size()))


func select_single(u: Unit, additive: bool) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var new_sel: Array
	if additive:
		new_sel = selection.duplicate()
		if new_sel.has(u):
			new_sel.erase(u)
		else:
			new_sel.append(u)
	else:
		new_sel = [u]
	_set_selection(new_sel)


## 查看敌方单位（只读）：清掉己方选区与命令卡，高亮该敌、面板显示其信息，但不可对其下令。
func _set_inspect(u: Unit) -> void:
	for s in selection:
		if is_instance_valid(s):
			s.set_selected(false)
	selection = []
	_active = null
	if _inspect_unit != null and is_instance_valid(_inspect_unit):
		_inspect_unit.set_inspected(false)
	_inspect_unit = u
	if u != null and is_instance_valid(u):
		u.set_inspected(true)
		Sfx.play("select")
	_update_sel_label()


func _set_selection(arr: Array) -> void:
	if _inspect_unit != null and is_instance_valid(_inspect_unit):
		_inspect_unit.set_inspected(false)   # 选己方 → 退出敌方查看态
	_inspect_unit = null
	for u in selection:
		if is_instance_valid(u):
			u.set_selected(false)
	# 中央过滤：驻军单位（藏在建筑里）一律不可选——覆盖框选/双击/编队召回等一切选取路径
	var valid: Array = arr.filter(func(u) -> bool: return is_instance_valid(u) and u.hp > 0.0 and not u.garrisoned)
	# 英雄排在普通单位前面：影响命令面板显示顺序、Tab 子组顺序、以及「编队第一个」
	var heroes: Array = valid.filter(func(u) -> bool: return u.is_hero)
	var others: Array = valid.filter(func(u) -> bool: return not u.is_hero)
	selection = heroes + others
	for u in selection:
		u.set_selected(true)
	if _active == null or not selection.has(_active):
		_active = _default_active()
	if not selection.is_empty():
		Sfx.play("select")
	_update_sel_label()


func _update_sel_label() -> void:
	_refresh_active_highlight()
	hud.update_selection_panel(selection)


## 标记「活动单位」高亮：仅当编队多于一个单位时才标（单个时本就是它，无需区分）
func _refresh_active_highlight() -> void:
	var act := active_unit()
	var multi := selection.size() > 1
	for u in selection:
		if is_instance_valid(u):
			u.set_active(multi and u == act)


func _issue_order(p: Vector2, queued := false) -> void:
	# 右键点击「建造中」的己方建筑 → 取消建造、退还资源（经典RTS式）。
	# 仅当没有可移动单位被选中时才取消——否则这一下右键是给部队下移动令，
	# 不能因为点到了工地附近就把在建建筑拆了（这正是「建筑莫名消失」的元凶）。
	var con := _constructing_building_at(p)
	if con != null:
		var movers_c := _selected_movers()
		var builders := movers_c.filter(func(u: Unit) -> bool: return u.is_worker)
		if not builders.is_empty():
			# 工人续建：右键在建工地 → 派工人接着建。地基永不消失、任何工人都能续建（经典RTS式）。
			for w in builders:
				w.order_build(con, queued)
			_click_fx_pos = p
			_click_fx_t = 0.5
			Sfx.play("order")
			msg("工人前去续建 %s" % con.display_name, 1.2)
			return
		if movers_c.is_empty():
			# 没选可移动单位 → 右键在建工地视作「取消建造」（退还资源）
			cancel_construction(con)
			return
		# 选的是非工人单位 → 当作普通移动令（下方处理），既不续建也不取消
	# 生产建筑：右键设集结点（rally）。设在资源上 → 记住该资源点(typed gather-point)，
	# 新练的工人会自动去采该类资源，采空后就近补位（经典RTS式 TC 集结到金矿）。
	var rally_res := _resource_at(p)
	var rallied := false
	for u in selection:
		if is_instance_valid(u) and u.is_building and not u.is_constructing and u.setup_def.has("produces"):
			u.rally = to_logic(p)
			u.has_rally = true
			u.rally_node = rally_res
			u.rally_kind = rally_res.res_kind if rally_res != null else ""
			rallied = true
	if rallied:
		_click_fx_pos = p
		_click_fx_t = 0.5
		_click_fx_attack = false
	var movers := _selected_movers()
	if movers.is_empty():
		return
	_click_fx_pos = p
	_click_fx_t = 0.5
	Sfx.play("order")
	var node := _resource_at(p)
	var rep := _damaged_building_at(p)
	# 驻军优先：右键自家有空位的箭楼/聚义厅 → 单位进驻——即使旁边正围着敌人也先进驻，
	# 否则据守战里聚义厅被围攻时，右键它永远被判成「攻击近旁的敌人」，英雄/兵根本进不去。
	var garr := _garrisonable_at(p)
	if garr != null:
		# 英雄不再右键自动驻扎（改用命令卡「驻扎」键 → 左键点建筑）；只对非英雄单位右键进驻。
		var g_movers: Array = movers.filter(func(u: Unit) -> bool: return not u.is_hero)
		if not g_movers.is_empty():
			var space: int = garr.garrison_cap - garr.passengers.size()
			var sent := 0
			var glp := to_logic(p)
			for u in g_movers:
				if sent < space:
					u.order_garrison(garr, queued)
					sent += 1
				else:
					u.order_move(glp, queued)   # 装不下的就移动到建筑旁（待有空位再手动进驻）
			for u in movers:
				if u.is_hero:
					u.order_move(glp, queued)   # 混选里的英雄：右键建筑时只移动过去，不进驻
			if sent > 0:
				msg("驻入 %s（%d 人）" % [garr.display_name, sent], 1.2)
				return
	var enemy := _enemy_at(p)
	_click_fx_attack = enemy != null
	if enemy != null:
		for u in movers:
			u.order_attack(enemy, queued)
		return
	var lp := to_logic(p)
	var targets := _formation_targets(movers, lp)
	var repaired := false
	for i in range(movers.size()):
		var u: Unit = movers[i]
		if node != null and u.is_worker:
			u.order_gather(node, queued)        # 工人采集
		elif rep != null and u.is_worker:
			u.order_repair(rep, queued)         # 工人修理受损建筑
			repaired = true
		else:
			u.order_move(targets[i], queued)
	if repaired:
		msg("工人前去修缮 %s" % rep.display_name, 1.3)
	_apply_group_cap(movers)   # 下令后再设限速（_begin_move 会先清零），避免被覆盖


## 武装维修落点：点己方建筑 → 选区里的工人前去修缮（受损才修；完好则提示）。
func _order_repair_at(p: Vector2, queued := false) -> void:
	var workers: Array = selection.filter(func(u: Unit) -> bool:
		return is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0)
	if workers.is_empty():
		msg("没有可派遣的工人", 1.2)
		return
	var rep := _damaged_building_at(p)
	if rep == null:
		# 也许点到的是完好的己方建筑 → 明确告知无需修缮，而不是静默无反应
		var whole := _friendly_building_at(p)
		if whole != null:
			msg("%s 完好无损，无需修缮" % whole.display_name, 1.3)
		else:
			msg("请点选要修缮的己方建筑", 1.3)
		return
	for u in workers:
		u.order_repair(rep, queued)
	_click_fx_pos = p
	_click_fx_t = 0.5
	_click_fx_attack = false
	Sfx.play("order")
	msg("工人前去修缮 %s" % rep.display_name, 1.3)


## 屏幕点下处是否为己方非资源建筑（完好或受损都算；用于维修反馈区分）
func _friendly_building_at(p: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or not u.is_building \
				or u.is_resource or u.is_constructing or u.hp <= 0.0:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= _bld_click_r(u) and d < bd:
			bd = d
			best = u
	return best


func _order_amove_at(p: Vector2, queued := false) -> void:
	var movers := _selected_movers()
	if movers.is_empty():
		return
	_click_fx_pos = p
	_click_fx_t = 0.5
	_click_fx_attack = true
	var lp := to_logic(p)
	var targets := _formation_targets(movers, lp)
	for i in range(movers.size()):
		movers[i].order_amove(targets[i], queued)
	_apply_group_cap(movers)


## S：停止/原地待命——清空选中单位的指令、就地驻守
func _order_stop() -> void:
	var movers := _selected_movers()
	if movers.is_empty():
		return
	for u in movers:
		u.order_stop()
	Sfx.play("order")
	msg("原地待命", 1.2)


## P：巡逻——选中的战斗单位在「当前位置 ↔ 鼠标点」间往返，沿途攻击移动迎敌
func _order_patrol_at(p: Vector2) -> void:
	var movers := _selected_movers().filter(func(u): return not u.is_worker)
	if movers.is_empty():
		return
	_click_fx_pos = p
	_click_fx_t = 0.5
	_click_fx_attack = true
	Sfx.play("order")
	var lp := to_logic(p)
	var targets := _formation_targets(movers, lp)
	for i in range(movers.size()):
		movers[i].order_patrol(targets[i])
	_apply_group_cap(movers)
	msg("巡逻", 1.2)


## G：循环切换选中战斗单位的作战姿态（进攻 → 守备 → 据守）
func _cycle_stance() -> void:
	var movers := _selected_movers().filter(func(u): return not u.is_worker)
	if movers.is_empty():
		return
	# 以「活动单位」当前姿态为基准循环，整组统一
	var base: int = active_unit().stance if active_unit() != null else movers[0].stance
	var nxt := (base + 1) % 4
	for u in movers:
		u.set_stance(nxt)
	var names := ["进攻（追击索敌）", "守备（守阵地·短追）", "据守（原地·只打近敌）", "避战（不索敌·不还手）"]
	Sfx.play("click")
	msg("姿态：" + names[nxt], 1.6)
	_refresh_active_highlight()


## 屏幕点下的资源点（金矿/林木）。命中区匹配「直立精灵」的实际绘制范围
## （见 unit._draw_resource_node：尺寸 s=radius*3.4，纵向 [-0.84s,+0.16s]，居原点上方），
## 否则只点到脚下那一小圈、点不到矿/树的图（树尤甚），鼠标也不会切到采集光标。
func _resource_at(p: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if not (is_instance_valid(u) and u.is_resource and u.res_left > 0.0):
			continue
		var o := to_screen(u.position)
		var s: float = u.radius * 3.4
		var dx: float = absf(p.x - o.x)
		var dy: float = p.y - o.y                      # 屏幕向下为正；精灵主要在原点上方（dy<0）
		if dx <= s * 0.44 + 4.0 and dy >= -s * 0.82 and dy <= s * 0.16 + 4.0:
			var d: float = Vector2(dx, dy + s * 0.34).length()   # 离精灵视觉中心的距离
			if d < bd:
				bd = d
				best = u
	return best


func _selected_movers() -> Array:
	return selection.filter(func(u) -> bool: return is_instance_valid(u) and u.hp > 0.0 and not u.is_building and not u.garrisoned)


## 真·阵型：朝行军方向旋转的方阵 + 角色分排（近战在前、远程居中、工人靠后）。
## 返回与 movers 同序的目标点数组（逻辑坐标）。让一队人成阵推进，而非乱挤一团。
func _formation_targets(movers: Array, dest: Vector2, spacing := 30.0) -> Array:
	var n := movers.size()
	var res: Array = []
	res.resize(n)
	if n == 0:
		return res
	if n == 1:
		res[0] = dest
		return res
	# 行军方向：队伍质心 → 目标点
	var c := Vector2.ZERO
	for u in movers:
		c += u.position
	c /= float(n)
	var fwd := dest - c
	fwd = fwd.normalized() if fwd.length() > 1.0 else Vector2.RIGHT
	var right := Vector2(-fwd.y, fwd.x)
	var cols := int(ceil(sqrt(float(n))))
	var rows := int(ceil(float(n) / float(cols)))
	# 按角色排序分配槽位：近战(0)→远程(1)→工人(2)，前排先填
	var order: Array = []
	for i in range(n):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _form_rank(movers[a]) < _form_rank(movers[b]))
	for slot in range(n):
		var mi: int = order[slot]
		var col := slot % cols
		var row := slot / cols
		var cx := (float(col) - float(cols - 1) * 0.5) * spacing
		var cy := (float(row) - float(rows - 1) * 0.5) * spacing
		res[mi] = dest + right * cx + fwd * (-cy)   # row 0 = 最前排（朝目标）
	return res


func _form_rank(u: Unit) -> int:
	if u.is_worker:
		return 2
	if u.is_ranged:
		return 1
	return 0


## 成队行军：把每个成员的速度上限设为队伍最慢者，使队形整体推进、不散开（单个单位不限速）。
func _apply_group_cap(movers: Array) -> void:
	if movers.size() <= 1:
		if movers.size() == 1:
			movers[0]._group_cap = 0.0
		return
	var slow := INF
	for u in movers:
		slow = minf(slow, u.base_speed)
	for u in movers:
		u._group_cap = slow


func _enemy_at(p: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.faction != Unit.FACTION_GUAN or u.hp <= 0.0 or u.garrisoned:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= u.radius + 12.0 and d < best_d:
			best = u
			best_d = d
	return best


func _unit_at(p: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 or u.is_building or u.garrisoned:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= u.radius + 10.0 and d < best_d:
			best = u
			best_d = d
	return best


## 屏幕点下「己方受损建筑」（修理目标）
func _damaged_building_at(p: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or not u.is_building \
				or u.is_resource or u.is_constructing or u.hp <= 0.0 or u.hp >= u.max_hp:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= _bld_click_r(u) and d < bd:
			bd = d
			best = u
	return best


## 屏幕点下「己方建造中建筑」（取消目标）
func _constructing_building_at(p: Vector2) -> Unit:
	var best: Unit = null
	var bd := INF
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or not u.is_constructing or u.hp <= 0.0:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= u.radius + 10.0 and d < bd:
			bd = d
			best = u
	return best


## 取消建造：退还全额资源、解除占地封路、停下建造工人、移除工地
func cancel_construction(bld: Unit) -> void:
	if bld == null or not is_instance_valid(bld) or not bld.is_constructing:
		return
	var d: Dictionary = _defs.get(bld.key, {})
	add_resources(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0)))
	var fcell: Vector2i = bld.get_meta("fcell", map.world_to_cell(bld.position))
	var fhalf: int = int(bld.get_meta("fhalf", 1))
	map.block_footprint(fcell, fhalf, false)
	bld.is_constructing = false
	for u in units:                          # 停下正在建造它的工人
		if is_instance_valid(u) and u._build_site == bld:
			u._build_site = null
	if selection.has(bld):
		var ns := selection.duplicate()
		ns.erase(bld)
		_set_selection(ns)
	units.erase(bld)
	bld.queue_free()
	msg("已取消建造 %s（资源已退还）" % String(d.get("name", bld.key)), 1.5)
	Sfx.play("cant")


## 驻军变化（进/出/弹出）：刷新命令卡与面板，让驻军数/出击按钮即时更新
func on_garrison_changed(_bld: Unit) -> void:
	# 进驻的单位从选区里移除（已藏进建筑，不该再显示在编队栏）
	if not selection.is_empty():
		var keep: Array = selection.filter(func(u: Unit) -> bool:
			return is_instance_valid(u) and not u.garrisoned)
		if keep.size() != selection.size():
			_set_selection(keep)
			return
	if hud != null:
		hud.refresh_command()
		_update_sel_label()


## 单个英雄出击：从所驻建筑弹出并选中居中（英雄快切栏点驻军英雄=出击）
func sortie_unit(u: Unit) -> void:
	if u == null or not is_instance_valid(u) or not u.garrisoned:
		return
	var bld := u.garrison_holder
	u.leave_garrison()
	Sfx.play("order")
	msg("%s 出击！" % u.display_name, 1.2)
	if bld != null and is_instance_valid(bld):
		on_garrison_changed(bld)
	focus_unit(u)


## 出击：把建筑里的驻军全部弹出
func ungarrison(bld: Unit) -> void:
	if bld == null or not is_instance_valid(bld):
		return
	for pg in bld.passengers.duplicate():
		if is_instance_valid(pg):
			pg.leave_garrison()
	bld.passengers.clear()
	Sfx.play("order")
	msg("驻军出击！", 1.2)
	on_garrison_changed(bld)


## 屏幕点下「可驻军的己方建筑」（有空位才返回）
func _garrisonable_at(p: Vector2) -> Unit:
	for u in units:
		if not (is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_building \
				and u.garrison_cap > 0 and not u.is_constructing and u.hp > 0.0):
			continue
		if u.passengers.size() >= u.garrison_cap:
			continue
		if to_screen(u.position).distance_to(p) <= _bld_click_r(u):
			return u
	return null


## 拆除（经典RTS式 Delete）：删除选中的己方单位/建筑。建筑/地基立即释放占地以防卡位；不退资源。
## 在建工地按「取消建造」退资源走 cancel_construction；已成型建筑/单位则直接销毁。
func delete_selected(skip_confirm := false) -> void:
	if selection.is_empty():
		return
	var doomed: Array = selection.filter(func(u: Unit) -> bool:
		return is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_resource and u.hp > 0.0)
	if doomed.is_empty():
		return
	# 拆「已成型建筑」需二次确认，防误删基地（纯单位/在建工地立即拆）。Shift 跳过确认。
	var solid_blds: int = doomed.filter(func(u: Unit) -> bool:
		return u.is_building and not u.is_constructing).size()
	if solid_blds > 0 and not skip_confirm and _demolish_armed_t <= 0.0:
		_demolish_armed_t = 2.5
		msg("再按 Delete 确认拆除 %d 座建筑（Shift+Delete 直接拆）" % solid_blds, 2.5)
		Sfx.play("click")
		return
	_demolish_armed_t = 0.0
	var n := 0
	for u in doomed:
		if u.is_constructing:
			cancel_construction(u)   # 在建工地：退资源 + 释放占地
		else:
			_demolish(u)
		n += 1
	_set_selection([])
	Sfx.play("cant")
	msg("已拆除 %d 个目标" % n, 1.2)


## 销毁单个已成型目标：释放占地、清理工人引用、扣回人口、留血渍、移除节点
func _demolish(u: Unit) -> void:
	if not is_instance_valid(u):
		return
	if u.is_building:
		# 拆除带驻军的建筑前，把驻军全部弹出（否则它们会卡在已删建筑里：隐身、无敌、永久失联）
		if not u.passengers.is_empty():
			for pg in u.passengers.duplicate():
				if is_instance_valid(pg):
					pg.leave_garrison()
			u.passengers.clear()
		if u.has_meta("fcell"):
			map.block_footprint(u.get_meta("fcell"), u.get_meta("fhalf"), false)
		var pp := int(u.setup_def.get("provides_pop", 0))
		if pp > 0:
			pop_cap = maxi(0, pop_cap - pp)
		for w in units:
			if is_instance_valid(w) and w._build_site == u:
				w._build_site = null
	var mark := FadingMark.new()
	mark.position = u.position
	fx_root.add_child(mark)
	units.erase(u)
	u.queue_free()


## ---------- 自检 / 截图（headless） ----------

func _ability_selftest() -> void:
	var heroes := units.filter(func(u) -> bool:
		return is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.ability != "")
	if heroes.size() < 1:
		print("[ability] no player ability heroes (ok)")
		return
	_set_selection(heroes.slice(0, mini(2, heroes.size())))
	var au := active_unit()
	var order_ok: bool = au != null and au.is_hero
	_set_selection([])
	var caster: Unit = heroes[0]
	# 仅测瞬发技能，避免进入指向状态
	if not _abilities[caster.ability]["targeted"]:
		cast_ability(caster, 0)
	# 施法抬手后技能不再瞬发：进入待结算队列，物理帧推进抬手归零才上冷却（这里同步无帧→查队列）
	var cd_started: bool = caster.ability_cd_frac() > 0.0 or not _pending_casts.is_empty() or _abilities[caster.ability]["targeted"]
	print("[ability] %s cd/slot ok=%s order_ok=%s" % [caster.key, cd_started, order_ok])


## headless 自检：选一个工人造一座兵营，验证建造链路
func _economy_selftest() -> void:
	if not economy:
		return
	var wkr: Unit = null
	for u in units:
		if is_instance_valid(u) and u.is_worker:
			wkr = u
			break
	if wkr == null:
		return
	var half := building_footprint_half("barracks")
	var base := map.world_to_cell(wkr.position)
	var cell := base
	for r in range(2, 9):
		var cand := base + Vector2i(r, -1)
		if map.area_buildable(cand, half) and not _building_overlap(cand, half):
			cell = cand
			break
	gold += 1000
	wood += 1000
	_set_selection([wkr])
	arm_build("barracks")
	_try_place_building(to_screen(map.cell_to_world(cell)))
	_set_selection([])
	# 生产链路：聚义厅训练 3 个喽啰
	var hall := find_unit("hall")
	if hall != null:
		for i in range(3):
			queue_train(hall, "lou_luo")
	var con := units.filter(func(u: Unit) -> bool: return is_instance_valid(u) and u.is_constructing).size()
	print("[econ] selftest: barracks constructing=%d, hall queue=%d" % [con, hall._train_queue.size() if hall else -1])
	# 英雄系统：直接生成宋江，给经验升级、学技能、施放
	var hero := spawn_unit("song_jiang", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-3, 0))))
	hero.hp = hero.max_hp * 0.5            # 先打成半血，验证升级不回满
	var _lhp0 := hero.hp
	var _lmax0 := hero.max_hp
	hero.gain_xp(500.0)
	print("[levelup] lv→%d hp %.0f→%.0f max %.0f→%.0f full=%s grew=%.0f healed=%.0f" % [
		hero.hero_level, _lhp0, hero.hp, _lmax0, hero.max_hp,
		hero.hp >= hero.max_hp - 0.5, hero.max_hp - _lmax0, hero.hp - _lhp0])
	hero.learn(0)
	_set_selection([hero])
	cast_ability(hero, 0)
	print("[econ] hero song_jiang slots=%d lvl=%d sp=%d rank0=%d cd0=%.1f" % [
		hero.slot_count(), hero.hero_level, hero.skill_points,
		int(hero.ability_slots[0]["rank"]), float(hero.ability_slots[0]["cd_t"])])
	_set_selection([])
	# 科技 + 马军
	if hall != null:
		queue_research(hall, "tech_gather")
	var cav := spawn_unit("liang_ma", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-2, 2))))
	print("[econ] cav liang_ma hp=%d cavalry=%s | researching=%s" % [int(cav.max_hp), cav.is_cavalry, hall._research_key if hall else ""])
	# 资源点命中区自检：精灵居原点上方，命中区须覆盖整图，否则点不到树/矿、采集光标不出
	for rk in ["wood", "gold"]:
		var rn: Unit = null
		for u in units:
			if is_instance_valid(u) and u.is_resource and u.res_kind == rk and u.res_left > 0.0:
				rn = u
				break
		if rn == null:
			continue
		var o := to_screen(rn.position)
		var s: float = rn.radius * 3.4
		print("[hit] %s(r=%d) base=%s center=%s canopy=%s" % [rk, int(rn.radius),
			_resource_at(o) == rn,
			_resource_at(o + Vector2(0, -s * 0.34)) == rn,
			_resource_at(o + Vector2(0, -s * 0.6)) == rn])
	# 取消建造自检：找一个建造中工地，记录资源→取消→应全额退还且工地移除
	# （截图模式下跳过，让工地保留以便拍到进度条）
	var site: Unit = null
	for u in units:
		if is_instance_valid(u) and u.is_constructing and u.faction == Unit.FACTION_LIANG:
			site = u
			break
	if site != null and OS.get_environment("SCREENSHOT_DIR") == "":
		var sp := to_screen(site.position)
		# 门控：选着工人右键工地 → 不该拆（是移动令）；空选右键 → 才拆（防「建筑莫名消失」）
		_set_selection([wkr])
		_issue_order(sp)
		var survived_with_movers := units.has(site)
		var g0: int = gold
		var w0: int = wood
		var sk: String = site.key
		_set_selection([])
		_issue_order(sp)
		print("[cancel] survived_with_movers=%s empty_sel_cancels=%s refund g+%d w+%d" % [
			survived_with_movers, not units.has(site), gold - g0, wood - w0])
	# 移动覆盖自动攻击自检：单位执行移动令时挨打，不该回头（状态仍为移动、无目标）
	var mu := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-4, 1))))
	mu.order_move(map.cell_to_world(map.nearest_open(base + Vector2i(6, 1))))
	var foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, mu.position + Vector2(20, 0))
	mu.take_damage(5.0, foe)
	print("[moveoverride] state=%d (move=1) target_null=%s" % [mu._state, mu._target == null])
	# 指令自检：停止/姿态/巡逻
	var cu := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-3, 3))))
	cu.order_move(map.cell_to_world(map.nearest_open(base + Vector2i(6, 3))))
	cu.order_stop()
	var stop_ok := cu._state == Unit.ST_IDLE and cu._target == null
	cu.set_stance(Unit.STANCE_HOLD)
	# 据守：远处放一个敌人，应「不索敌、不挪窝」（aggro_range 内但不在攻击范围）
	var far_foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, cu.position + Vector2(120, 0))
	cu._acquire()
	var hold_ignores_far := cu._target == null
	cu.set_stance(Unit.STANCE_AGGRO)
	cu._acquire()
	var aggro_sees_far := cu._target == far_foe
	cu.order_patrol(map.cell_to_world(map.nearest_open(base + Vector2i(6, 3))))
	print("[command] stop_ok=%s hold_ignores_far=%s aggro_sees_far=%s patrol_on=%s state=%d" % [
		stop_ok, hold_ignores_far, aggro_sees_far, cu._patrolling, cu._state])
	# 箭楼自检：活塔会射箭；被摧毁(废墟)后不再射箭（防「打掉塔还被不明箭矢打」）
	var twr := spawn_unit("arrow_tower", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(base + Vector2i(-6, 5))))
	twr.is_constructing = false
	twr.hp = twr.max_hp
	var tgt := spawn_unit("liang_dao", Unit.FACTION_LIANG, twr.position + Vector2(30, 0))
	twr._cd = 0.0
	var pj0 := fx_root.get_child_count()
	twr._physics_process(0.1)                  # 活塔：应射出一箭
	var alive_shot := fx_root.get_child_count() > pj0
	twr.hp = 0.0                               # 摧毁 → 废墟
	twr._cd = 0.0
	var pj1 := fx_root.get_child_count()
	twr._physics_process(0.1)                  # 废墟：不应再射箭
	var dead_silent := fx_root.get_child_count() == pj1
	print("[tower] alive_shoots=%s dead_silent=%s" % [alive_shot, dead_silent])
	twr.queue_free()
	tgt.queue_free()
	units.erase(twr)
	units.erase(tgt)
	# 续建自检：地基持久存在 + 任意工人右键工地可续建（修「工人离开就停建」）
	add_resources(300, 300)
	var rcell := map.nearest_open(base + Vector2i(4, -4))
	_start_construction("house", rcell, building_footprint_half("house"))
	var fnd: Unit = null
	for u in units:
		if is_instance_valid(u) and u.is_constructing and u.key == "house":
			fnd = u
	var newwkr := spawn_unit("lou_luo", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(2, -4))))
	_set_selection([newwkr])
	_issue_order(to_screen(fnd.position) if fnd != null else Vector2.ZERO)
	var resume_ok := fnd != null and newwkr._build_site == fnd
	print("[resume] foundation_persists=%s any_worker_resumes=%s" % [fnd != null, resume_ok])
	# 拆除自检：选中己方建筑+单位 → delete_selected 移除两者并释放占地（防卡位）
	var dcell := map.nearest_open(base + Vector2i(-2, -5))
	var dbld := spawn_unit("depot", Unit.FACTION_LIANG, map.cell_to_world(dcell))
	dbld.is_constructing = false
	dbld.hp = dbld.max_hp
	var dhalf := building_footprint_half("depot")
	dbld.set_meta("fcell", dcell)
	dbld.set_meta("fhalf", dhalf)
	map.block_footprint(dcell, dhalf, true)
	var blocked_before := not map.area_buildable(dcell, dhalf)
	var dunit := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-4, -5))))
	_set_selection([dbld, dunit])
	# 先验证确认门控：默认调用应「武装确认」而不删；带 skip 才真正拆
	delete_selected()
	var confirm_guard := units.has(dbld)
	delete_selected(true)
	var bld_gone := not units.has(dbld)
	var unit_gone := not units.has(dunit)
	var footprint_freed := map.area_buildable(dcell, dhalf)
	print("[delete] confirm_guard=%s bld_gone=%s unit_gone=%s footprint_blocked_before=%s footprint_freed_after=%s" % [
		confirm_guard, bld_gone, unit_gone, blocked_before, footprint_freed])
	if fnd != null:
		cancel_construction(fnd)
	newwkr.queue_free(); units.erase(newwkr)
	# 自动复工自检：采集中的工人被拉去建造，建完应自动回采（不傻站工地）
	var gnode := nearest_resource(map.cell_to_world(base), "")
	if gnode != null:
		var rw := spawn_unit("lou_luo", Unit.FACTION_LIANG, gnode.position + Vector2(40, 0))
		rw.order_gather(gnode)
		var was_gathering := rw._gather_node == gnode
		var bs := spawn_unit("house", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(5, -2))))
		bs.is_constructing = true
		bs.set_meta("fhalf", 1)
		rw.order_build(bs)
		var building_now := rw._state == Unit.ST_BUILD
		bs.is_constructing = false           # 模拟「建完」
		rw._do_build(0.1)                    # 触发收尾 → 应自动回采
		var resumed := rw._state == Unit.ST_GATHER
		print("[autowork] was_gathering=%s building=%s resumed_gather=%s" % [was_gathering, building_now, resumed])
		# typed 集结点自检：生产建筑集结到资源 → 新工人自动去采该资源
		var hb := find_unit("hall")
		if hb != null:
			hb.has_rally = true
			hb.rally = gnode.position
			hb.rally_node = gnode
			hb.rally_kind = gnode.res_kind
			on_unit_trained(hb, "lou_luo")
			var nw: Unit = units[units.size() - 1]
			var typed_rally := nw.is_worker and (nw._gather_node == gnode or nw._state == Unit.ST_GATHER)
			print("[rally] typed_autogather=%s kind=%s" % [typed_rally, hb.rally_kind])
			nw.queue_free(); units.erase(nw)
			hb.has_rally = false; hb.rally_node = null; hb.rally_kind = ""
		rw.queue_free(); units.erase(rw)
		bs.queue_free(); units.erase(bs)
	# 阵型自检：一队混编单位 → 目标点互不重叠 + 近战排在远程之前（更靠目标）
	var fm: Array = []
	var melee_u := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(0, 6))))
	var ranged_u := spawn_unit("liang_gong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(1, 6))))
	fm = [melee_u, ranged_u,
		spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(2, 6)))),
		spawn_unit("liang_gong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(3, 6))))]
	var fdest := map.cell_to_world(map.nearest_open(base + Vector2i(0, -8)))
	var ftargets := _formation_targets(fm, fdest)
	var distinct := {}
	for t in ftargets:
		distinct[Vector2i(t)] = true
	var all_distinct := distinct.size() == ftargets.size()
	# 近战槽更靠目标（行军方向上更前）
	var mt: Vector2 = ftargets[0]
	var rt: Vector2 = ftargets[1]
	var melee_closer := mt.distance_to(fdest) <= rt.distance_to(fdest)
	print("[formation] n=%d distinct=%s melee_front=%s" % [fm.size(), all_distinct, melee_closer])
	# 成队限速自检：受令后速度上限取最慢成员
	_apply_group_cap(fm)
	var slowest := INF
	for u in fm:
		slowest = minf(slowest, u.base_speed)
	var cap_ok := true
	for u in fm:
		if absf(u._group_cap - slowest) > 0.01:
			cap_ok = false
	# 限速解除自检（修状态泄漏）：单独下移动令应清零 _group_cap，不再被永久拖慢
	var fu: Unit = fm[0]
	fu.order_move(map.cell_to_world(map.nearest_open(base + Vector2i(3, -7))))
	var cap_cleared: bool = fu._group_cap == 0.0
	# 避战姿态自检：不索敌、挨打不还手
	var pv := melee_u
	pv.set_stance(Unit.STANCE_PASSIVE)
	pv._target = null
	var pfoe := spawn_unit("guan_dao", Unit.FACTION_GUAN, pv.position + Vector2(30, 0))
	pv._acquire()
	var passive_no_acquire := pv._target == null
	pv.take_damage(3.0, pfoe)
	var passive_no_retaliate := pv._target == null
	pfoe.queue_free(); units.erase(pfoe)
	print("[feel] group_cap_slowest=%s group_cap_cleared=%s passive_no_acquire=%s passive_no_retaliate=%s" % [
		cap_ok, cap_cleared, passive_no_acquire, passive_no_retaliate])
	# 集市贸易自检：木→金、金→木 各按汇率结算
	var g0 := gold
	var w0 := wood
	wood = 300
	gold = 300
	var gb := gold
	do_trade("wood")                                    # 100 木 → 70 金
	var trade_wood_ok := gold == gb + TRADE_GET and wood == 300 - TRADE_AMT
	var wb := wood
	var gb2 := gold
	do_trade("gold")                                    # 100 金 → 70 木
	var trade_gold_ok := wood == wb + TRADE_GET and gold == gb2 - TRADE_AMT
	print("[trade] wood_to_gold=%s gold_to_wood=%s rate=%d/%d" % [trade_wood_ok, trade_gold_ok, TRADE_AMT, TRADE_GET])
	gold = g0
	wood = w0
	for u in fm:
		u.queue_free(); units.erase(u)
	# 驻军自检：进驻/隐身、敌不索敌、驻军增援射击、出击、建筑摧毁弹出
	var gtow := spawn_unit("arrow_tower", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-7, -2))))
	gtow.is_constructing = false
	gtow.hp = gtow.max_hp
	gtow.set_meta("fhalf", 1)
	var garch := spawn_unit("liang_gong", Unit.FACTION_LIANG, gtow.position + Vector2(20, 0))
	garch.order_garrison(gtow)
	garch._do_garrison(0.1)                              # 在触及半径内 → 进驻
	var entered := garch.garrisoned and gtow.passengers.has(garch) and not garch.visible
	# 驻军免疫伤害（飞行箭/范围技能也打不到）
	var hp_pre := garch.hp
	garch.take_damage(50.0, null)
	var invuln := garch.hp == hp_pre
	var genemy := spawn_unit("guan_dao", Unit.FACTION_GUAN, gtow.position + Vector2(40, 0))
	genemy._acquire()
	var hidden_from_enemy := genemy._target != garch    # 驻军单位不被索敌
	gtow._target = genemy
	gtow._cd = 0.0
	var pjb := fx_root.get_child_count()
	gtow._tower_tick(0.1)
	var fire_arrows := fx_root.get_child_count() - pjb  # 塔自身 + 远程驻军各一箭 ≥ 2
	ungarrison(gtow)
	var ejected := not garch.garrisoned and gtow.passengers.is_empty() and garch.visible
	# 建筑摧毁弹出驻军（不陪葬）
	garch.order_garrison(gtow)
	garch._do_garrison(0.1)
	var re_entered := garch.garrisoned
	gtow.take_damage(gtow.max_hp + 10.0, genemy)        # 摧毁塔
	var death_ejected := not garch.garrisoned and garch.visible
	# 拆除带驻军建筑：驻军应被弹出，不卡在已删建筑里
	var gtow2 := spawn_unit("arrow_tower", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-9, 5))))
	gtow2.is_constructing = false
	gtow2.hp = gtow2.max_hp
	gtow2.set_meta("fhalf", 1)
	gtow2.set_meta("fcell", map.world_to_cell(gtow2.position))
	var garch2 := spawn_unit("liang_gong", Unit.FACTION_LIANG, gtow2.position + Vector2(18, 0))
	garch2.order_garrison(gtow2)
	garch2._do_garrison(0.1)
	_demolish(gtow2)
	var demolish_ejected := not garch2.garrisoned and garch2.visible and gtow2.passengers.is_empty()
	print("[garrison] entered=%s hidden=%s invuln=%s fire_arrows=%d ejected=%s death_ejected=%s demolish_ejected=%s" % [
		entered, hidden_from_enemy, invuln, fire_arrows, ejected, death_ejected, demolish_ejected])
	garch2.queue_free(); units.erase(garch2)
	genemy.queue_free(); units.erase(genemy)
	garch.queue_free(); units.erase(garch)
	gtow.queue_free(); units.erase(gtow)
	# 迷雾自检（仅 fog 开启的模式）：视野延时驻留 + 建筑记忆
	if fog:
		var fc := map.world_to_cell(mu.position)
		var idx := fc.y * map.w + fc.x
		# 强制照亮该格，再模拟「单位已离开」连跑若干 pass：
		_sight_now.fill(0)
		_vision[idx] = 2
		_vis_t[idx] = SIGHT_LINGER
		# 跑 ~10 秒（无单位照亮）：仍应明亮（驻留未耗尽）
		for _i in range(60):
			_force_fog_decay(0.18)
		var lingers_10s := _vision[idx] == 2
		# 再跑 ~25 秒：累计 >30 秒，应退为阴影（已探索）
		for _i in range(140):
			_force_fog_decay(0.18)
		var faded_after_30s := _vision[idx] == 1
		# 建筑记忆：该格已探明（vision==1）→ 建筑应保留可见、普通敌人应隐去（纯判定，不生成单位）
		var p := map.cell_to_world(fc)
		var bld_remembered := is_explored_world(p)     # 建筑：探明即保留
		var foe_hidden := not is_visible_world(p)       # 普通敌人：非明亮即隐去
		print("[fog] sight_unit=%d sight_bld=%d linger_10s=%s faded_30s=%s bld_remembered=%s foe_hidden=%s" % [
			8, 10, lingers_10s, faded_after_30s, bld_remembered, foe_hidden])


## 悬停光标 / 驻军出击 / 英雄栏含驻军英雄 自检（HOVERTEST=1，在 SMOKE 末尾跑一次）
func _hover_selftest() -> void:
	if OS.get_environment("HOVERTEST") != "1":
		return
	var vs := get_viewport().get_visible_rect().size
	# 林木 / 金矿：验 _resource_at 命中且 res_kind 正确（资源点在固定地图位）
	var t_tree: Unit = null
	var t_gold: Unit = null
	for u in units:
		if is_instance_valid(u) and u.is_resource and u.res_left > 0.0:
			if u.res_kind == "gold": t_gold = u
			else: t_tree = u
	var ht_tree_ok: bool = t_tree != null and _resource_at(to_screen(t_tree.position)) == t_tree
	var ht_gold_ok: bool = t_gold != null and _resource_at(to_screen(t_gold.position)) == t_gold
	# 箭楼 + 弓手放在「面板上方」的受控屏幕点 → 直接验 _hover_kind_at 的返回种类
	var ht_lp := to_logic(Vector2(vs.x * 0.40, vs.y * 0.30))
	var t_tow := spawn_unit("arrow_tower", Unit.FACTION_LIANG, ht_lp)
	t_tow.is_constructing = false
	t_tow.position = ht_lp
	var t_arch := spawn_unit("liang_gong", Unit.FACTION_LIANG, ht_lp + Vector2(18, 0))
	_set_selection([t_arch])
	var ht_garr_cursor: bool = _hover_kind_at(to_screen(t_tow.position)) == "garrison"
	_set_selection([])
	var ht_empty_select: bool = _hover_kind_at(to_screen(t_tow.position)) == "select"
	t_arch.order_garrison(t_tow)
	for _gi in range(10):
		t_arch._do_garrison(0.2)
	var ht_garr_in: bool = t_arch.garrisoned and t_tow.passengers.has(t_arch)
	# 英雄栏含驻军英雄（驻军后仍在 liang_heroes 里，才能点头像出击）
	var t_hero := spawn_unit("song_jiang", Unit.FACTION_LIANG, ht_lp + Vector2(18, 6))
	t_hero.order_garrison(t_tow)
	for _gi2 in range(10):
		t_hero._do_garrison(0.2)
	var ht_hero_in_bar: bool = t_hero.garrisoned and liang_heroes().has(t_hero)
	sortie_unit(t_hero)
	var ht_sortie_out: bool = not t_hero.garrisoned and selection.has(t_hero)
	print("[hover] tree=%s gold=%s garr_cursor=%s empty_select=%s garr_in=%s hero_in_bar=%s sortie_out=%s" % [
		ht_tree_ok, ht_gold_ok, ht_garr_cursor, ht_empty_select, ht_garr_in, ht_hero_in_bar, ht_sortie_out])
	# 聚义厅（大占地）驻军：英雄从远处走来能否真正进驻 hall
	var t_hall: Unit = null
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_building \
				and u.garrison_cap > 0 and u.hp > 0.0 and u.setup_def.has("produces"):
			t_hall = u; break
	if t_hall != null:
		# (1) 英雄右键聚义厅：现在应「不」自动驻扎（英雄改用「驻扎」键）。
		var t_h2 := spawn_unit("song_jiang", Unit.FACTION_LIANG, t_hall.position + Vector2(40, 0))
		_set_selection([t_h2])
		_issue_order(to_screen(t_hall.position))
		var rc_no_garrison := t_h2._state != Unit.ST_GARRISON and t_h2._garrison_dest != t_hall
		# (2) 「驻扎」键全链路：arm_garrison → 左键聚义厅 → 英雄进驻。
		arm_garrison()
		var armed_ok := _garrison_armed
		_order_garrison_at(to_screen(t_hall.position))
		_disarm_garrison()
		for _hi in range(40):
			t_h2._do_garrison(0.1)
		var armed_entered := t_h2.garrisoned and t_hall.passengers.has(t_h2)
		print("[hallgar] hall=%s rc_no_garrison=%s armed=%s armed_entered=%s cap=%d/%d" % [
			t_hall.key, rc_no_garrison, armed_ok, armed_entered,
			t_hall.passengers.size(), t_hall.garrison_cap])
		if is_instance_valid(t_h2):
			if t_h2.garrisoned: t_h2.leave_garrison()
			t_h2.queue_free(); units.erase(t_h2)
	_set_selection([])
	for tu in [t_hero, t_arch, t_tow]:
		if is_instance_valid(tu):
			tu.queue_free(); units.erase(tu)


func _force_fog_decay(step: float) -> void:
	for i in range(_vision.size()):
		if _sight_now[i] == 1:
			_vision[i] = 2
			_vis_t[i] = SIGHT_LINGER
		elif _vision[i] == 2:
			_vis_t[i] -= step
			if _vis_t[i] <= 0.0:
				_vis_t[i] = 0.0
				_vision[i] = 1


func _group_selftest() -> void:
	var army := units.filter(func(u) -> bool:
		return u.faction == Unit.FACTION_LIANG and not u.is_building)
	if army.size() < 6:
		print("[group] too few units (%d), skip" % army.size())
		return
	_set_selection(army.slice(0, 5))
	_assign_group(1)
	_set_selection(army.slice(5, mini(11, army.size())))
	_assign_group(2)
	_set_selection([])
	_recall_group(1)
	var ok := selection.size() == 5 and _groups.has(1)
	print("[group] recalled=%d ok=%s badge=%s" % [selection.size(), ok, army[0].group_nums.has(1)])
	# 同属多队：把 army[0]（已在 1 队）并入 2 队 → 角标应同时显示 [1,2]（请求：多队号）
	_set_selection([army[0]])
	_add_to_group(2)
	print("[group] multi=%s nums=%s" % [army[0].group_nums == [1, 2], str(army[0].group_nums)])
	_groups[2] = _groups[2].filter(func(u): return u != army[0])   # 还原 2 队
	_refresh_group_badges()
	# 英雄置前 + 编队键复位活动单位（请求 1/3）
	var ahero: Unit = null
	var anon: Unit = null
	for u in army:
		if u.is_hero and ahero == null:
			ahero = u
		elif not u.is_hero and anon == null:
			anon = u
	if ahero != null and anon != null:
		_set_selection([anon, ahero])           # 输入里英雄在后，期望被排到最前
		var hf: bool = selection[0] == ahero
		_assign_group(3)
		_active = anon                          # 模拟 Tab 切到非英雄
		_recall_group(3)                        # 再按编队键 → 应复位到第一个（英雄）
		print("[group] hero_first=%s recall_reset=%s" % [hf, active_unit() == ahero])
		_groups.erase(3)
	_set_selection([])


## 美术总检：雾关闭→生成五英雄与一排敌军贴脸互殴→触发施法抬手→连拍多帧（验证攻击逐帧+抬手）。
func _artshot(dir: String, center: Vector2i) -> void:
	fog = false
	phase = Phase.FIGHT
	Engine.time_scale = 1.0
	if hud != null and hud._intro_root != null:
		hud._intro_root.visible = false          # 收掉开场旁白框，免得挡住画面
	var base := map.nearest_open(center)
	var heroes := ["song_jiang", "lin_chong", "hua_rong", "li_kui", "wu_yong"]
	var hus: Array = []
	for i in range(heroes.size()):
		var hp := map.cell_to_world(map.nearest_open(base + Vector2i(-2, i - 2)))
		var h := spawn_unit(heroes[i], Unit.FACTION_LIANG, hp)
		if h != null:
			h.set_stance(Unit.STANCE_AGGRO)
			h.max_hp = 99999.0; h.hp = 99999.0   # 加血保活：让演示全程不死
			hus.append(h)
	var foes := ["guan_dao", "guan_gong", "guan_qi", "lou_luo", "liang_qiang"]
	var fus: Array = []
	for i in range(foes.size()):
		var fp := map.cell_to_world(map.nearest_open(base + Vector2i(3, i - 2)))
		var f := spawn_unit(foes[i], Unit.FACTION_GUAN, fp)
		if f != null:
			f.set_stance(Unit.STANCE_AGGRO)
			f.max_hp = 99999.0; f.hp = 99999.0
			fus.append(f)
	camera.zoom = Vector2(3.1, 3.1)
	camera.position = to_screen(map.cell_to_world(base))
	# 互指目标，强制开打（贴脸→立即进入挥击，拍到攻击逐帧）
	for i in range(hus.size()):
		if i < fus.size():
			hus[i]._target = fus[i]
			fus[i]._target = hus[i]
	var shot := 0
	for round in range(16):
		# 间隔直接触发抬手施法（_begin_cast 含 windup），朝对面敌人方向
		var cast_h: Unit = null
		if round == 4 and hus.size() > 0: cast_h = hus[0]          # 宋江
		elif round == 8 and hus.size() > 2: cast_h = hus[2]        # 花荣（远程抬手）
		elif round == 12 and hus.size() > 3: cast_h = hus[3]       # 李逵
		if cast_h != null and is_instance_valid(cast_h) and cast_h.slot_count() > 0:
			var tp: Vector2 = cast_h.position + Vector2(60, 0)
			if not fus.is_empty() and is_instance_valid(fus[0]):
				tp = fus[0].position
			_begin_cast(cast_h, 0, tp)
		# 相机跟随：取存活英雄的质心，保证打斗始终在画面里
		var cen := Vector2.ZERO
		var nlive := 0
		for h in hus:
			if is_instance_valid(h) and h.hp > 0.0:
				cen += h.position; nlive += 1
		if nlive > 0:
			camera.position = to_screen(cen / float(nlive))
		if hud != null and hud._intro_root != null:
			hud._intro_root.visible = false
		await get_tree().create_timer(0.22).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/artshot_%02d.png" % [dir, shot])
		print("[shot] artshot %02d saved" % shot)
		shot += 1
	return


func _screenshot_loop(dir: String) -> void:
	var center := level.camera_start_cell()
	if OS.get_environment("CMDCARD_TEST") == "1":
		await _cmdcard_test(dir)
		return
	if OS.get_environment("HUARONG_TEST") == "1":
		await _huarong_test(dir)
		return
	if OS.get_environment("ARTSHOT") == "1":
		await _artshot(dir, center)
		return
	if OS.get_environment("ANIM_TEST") == "1":
		Engine.time_scale = 1.0
		camera.zoom = Vector2(2.8, 2.8)
		camera.position = to_screen(map.cell_to_world(center))
		var waited := 0.0
		while _front_combat() == 0 and waited < 60.0:
			await get_tree().create_timer(0.3).timeout
			waited += 0.3
		Engine.time_scale = 0.4
		for i in range(5):
			var foe := _nearest_combat_pair()
			if foe != Vector2.ZERO:
				camera.position = foe
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/anim_%02d.png" % [dir, i])
			print("[shot] anim %02d saved" % i)
		return
	for i in range(4):
		await get_tree().create_timer([4.0, 26.0, 45.0, 24.0][i]).timeout
		var sel := units.filter(func(u) -> bool:
			return is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building and u.hp > 0.0)
		_set_selection(sel.slice(0, 10))
		camera.zoom = Vector2([1.1, 2.2, 1.1, 2.0][i], [1.1, 2.2, 1.1, 2.0][i])
		var foe := _nearest_combat_pair()
		camera.position = foe if foe != Vector2.ZERO else to_screen(map.cell_to_world(center))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [dir, i])
		print("[shot] %02d saved" % i)


## 花荣技能特效自检：生成花荣 + 一簇官军靶子，逐式施放并在动画过程中连拍，确认神箭/箭雨演出。
func _huarong_test(dir: String) -> void:
	Engine.time_scale = 1.0
	if _fog_layer != null:
		_fog_layer.visible = false        # 关迷雾，免得盖住特效
	if hud != null and hud._intro_root != null:
		hud._intro_root.visible = false   # 收起开场旁白
	var c := map.cell_to_world(level.camera_start_cell())
	var hr := spawn_unit("hua_rong", Unit.FACTION_LIANG, c)
	var tgt := c + Vector2(150, 40)
	for i in range(7):
		spawn_unit("guan_dao", Unit.FACTION_GUAN, tgt + Vector2(randf_range(-45, 45), randf_range(-30, 30)))
	# 学满三个主动技
	for s in range(hr.slot_count()):
		if not bool(hr.ability_slots[s]["passive"]):
			hr.ability_slots[s]["rank"] = 2
			hr.ability_slots[s]["cd_t"] = 0.0
	camera.zoom = Vector2(1.7, 1.7)
	camera.position = to_screen((c + tgt) * 0.5)
	await get_tree().process_frame
	var skills := [["hua_shot", 0], ["hua_rain", 1], ["hua_pin", 2]]
	for sk in skills:
		var aid: String = sk[0]
		var slot: int = sk[1]
		hr.position = c
		camera.zoom = Vector2(2.4, 2.4)
		camera.position = to_screen((c + tgt) * 0.5)
		hr.ability_slots[slot]["cd_t"] = 0.0
		_do_ability(hr, slot, tgt)
		# 动画过程中连拍三帧（飞行 / 命中 / 余韵）
		for fi in range(3):
			await get_tree().create_timer([0.07, 0.16, 0.34][fi]).timeout
			camera.position = to_screen((c + tgt) * 0.5)   # 抵消屏震漂移，保持取景
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/hr_%s_%d.png" % [dir, aid, fi])
		print("[huarong] %s cast + captured" % aid)
		# 复活靶子，保证下一式有目标
		for i in range(4):
			spawn_unit("guan_dao", Unit.FACTION_GUAN, tgt + Vector2(randf_range(-45, 45), randf_range(-30, 30)))
		await get_tree().create_timer(0.2).timeout
	# 大招·换刀自检：施放 hua_blade(slot 3) → 近战(射程缩/吸血+10%/弓关)，再放 → 还原
	var blade_slot := 3
	var r_bow := hr.atk_range
	var ls_bow := hr.lifesteal_frac()
	hr.ability_slots[blade_slot]["cd_t"] = 0.0
	_do_ability(hr, blade_slot, hr.position)
	var ok_melee: bool = hr.melee_mode and not hr.is_ranged and hr.atk_range < r_bow and abs(hr.lifesteal_frac() - ls_bow - 0.10) < 0.001 and hr._weapon_kind() == Unit.WK.SWORD
	hr.ability_slots[blade_slot]["cd_t"] = 0.0
	_do_ability(hr, blade_slot, hr.position)
	var ok_bow: bool = (not hr.melee_mode) and hr.is_ranged and abs(hr.atk_range - r_bow) < 0.01 and abs(hr.lifesteal_frac() - ls_bow) < 0.001
	print("[huarong] blade_ult melee=%s restore=%s %s" % [ok_melee, ok_bow, "PASS" if (ok_melee and ok_bow) else "FAIL"])
	# 近战立绘验证：进入近战后截图看花荣是否持刀（应切到 hua_rong_melee 帧）
	var open := c + Vector2(-260, -120)
	hr.position = open
	hr.ability_slots[blade_slot]["cd_t"] = 0.0
	if not hr.melee_mode:
		_do_ability(hr, blade_slot, open)   # 进入近战
	camera.zoom = Vector2(4.2, 4.2)
	hr.order_move(open + Vector2(140, 60))   # 走起来，播放走刀帧
	for fi in range(2):
		await get_tree().create_timer(0.55).timeout
		camera.position = to_screen(hr.position)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hr_melee_sprite_%d.png" % [dir, fi])
	print("[huarong] melee_sprite anim_key=%s (期望 hua_rong_melee)" % hr._anim_key())
	print("[huarong] DONE")


## 命令卡布局自检：选中聚义厅/工人/英雄，逐图标断言其全局矩形不越出屏幕（防右侧命令被裁切），并截图。
func _cmdcard_test(dir: String) -> void:
	Engine.time_scale = 1.0
	gold = 9999
	wood = 9999
	pop_cap = 200
	await get_tree().process_frame
	# 找己方聚义厅、工人；英雄直接生成一名
	var hall: Unit = null
	var worker: Unit = null
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG:
			continue
		if hall == null and u.is_building and u.setup_def.has("produces") and u.setup_def.has("garrison_cap"):
			hall = u
		elif worker == null and u.is_worker:
			worker = u
	var hero: Unit = null
	if hall != null:
		hero = spawn_unit("hua_rong", Unit.FACTION_LIANG, hall.position + Vector2(80, 0))
	await get_tree().process_frame
	var total_bad := 0
	# 1) 聚义厅满命令（5 生产 + 1 科技 + 出击）：临时塞一名驻军以显示「出击」按钮，触发最多按钮数
	if hall != null and worker != null:
		worker.garrisoned = true
		worker.garrison_holder = hall
		worker.visible = false
		if not hall.passengers.has(worker):
			hall.passengers.append(worker)
		total_bad += await _cmdcard_capture(dir, "hall", [hall])
		# 还原驻军假态
		hall.passengers.erase(worker)
		worker.garrisoned = false
		worker.garrison_holder = null
		worker.visible = true
	if worker != null:
		total_bad += await _cmdcard_capture(dir, "worker", [worker])
	if hero != null:
		# 学满技能槽以渲染冷却/等级态
		for _i in range(8):
			for sidx in range(hero.slot_count()):
				if hero.can_learn(sidx):
					learn_slot(hero, sidx)
		total_bad += await _cmdcard_capture(dir, "hero", [hero])
	print("[cmdcard] TOTAL overflow=%d %s" % [total_bad, "PASS" if total_bad == 0 else "FAIL"])


## 选中并截图 + 断言命令卡每个按钮都在屏幕内。返回越界按钮数。
func _cmdcard_capture(dir: String, label: String, sel: Array) -> int:
	_set_selection(sel)   # → _update_sel_label → hud.update_selection_panel → 重建命令卡
	# 让容器重新排版（GridContainer/HBox 排序需要跨帧）
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp := get_viewport().get_visible_rect().size
	var bad := 0
	var n := hud._skill_bar.get_child_count()
	for c in hud._skill_bar.get_children():
		var gr: Rect2 = c.get_global_rect()
		if gr.position.x < -0.5 or gr.end.x > vp.x + 0.5 or gr.position.y < -0.5 or gr.end.y > vp.y + 0.5:
			bad += 1
			print("[cmdcard]   OVERFLOW %s: idx=%d rect=%s vp=%s" % [label, c.get_index(), gr, vp])
	print("[cmdcard] %s: buttons=%d overflow=%d %s" % [label, n, bad, "PASS" if bad == 0 else "FAIL"])
	get_viewport().get_texture().get_image().save_png("%s/cmd_%s.png" % [dir, label])
	# 诊断：打印底栏每个子节点的全局矩形，定位提示文字越界
	var hbox := hud._skill_bar.get_parent()
	for c in hbox.get_children():
		var r: Rect2 = (c as Control).get_global_rect()
		print("[cmdcard]   layout %s: %s x=[%.0f,%.0f] w=%.0f" % [label, c.get_class(), r.position.x, r.end.x, r.size.x])
	return bad


func _nearest_combat_pair() -> Vector2:
	for u in units:
		if u.faction == Unit.FACTION_GUAN and u.hp > 0.0 and u.has_target():
			return to_screen(u.position)
	return Vector2.ZERO


func _front_combat() -> int:
	var n := 0
	for u in units:
		if u.faction == Unit.FACTION_GUAN and u.hp > 0.0 and u.has_target():
			n += 1
	return n


## ---------- 顶层覆盖绘制 ----------

class Overlay extends Node2D:
	var b = null

	func _process(_delta: float) -> void:
		if b != null:
			queue_redraw()

	func _draw() -> void:
		if b == null:
			return
		# 选中生产建筑的集结点旗帜
		for u in b.selection:
			if is_instance_valid(u) and u.is_building and u.has_rally and u.setup_def.has("produces"):
				var rp: Vector2 = b.to_screen(u.rally)
				draw_line(rp, rp + Vector2(0, -24), Color(0.25, 0.95, 0.45, 0.9), 2.0)
				draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -24), rp + Vector2(15, -19), rp + Vector2(0, -14)]),
					Color(0.25, 0.95, 0.45, 0.85))
		# 关卡高亮格（盘陀路指路等）
		for c in b.lit_cells:
			var pts := PackedVector2Array([
				b.to_screen(Vector2(c.x * GameMap.CELL, c.y * GameMap.CELL)),
				b.to_screen(Vector2((c.x + 1) * GameMap.CELL, c.y * GameMap.CELL)),
				b.to_screen(Vector2((c.x + 1) * GameMap.CELL, (c.y + 1) * GameMap.CELL)),
				b.to_screen(Vector2(c.x * GameMap.CELL, (c.y + 1) * GameMap.CELL)),
			])
			draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, 0.18))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.85, 0.3, 0.7), 1.5)
		# 框选预览：桌面拖拽时一直显示；触屏只在「长按框选」态显示（普通单指拖动=拖地图，不画框）
		if b._dragging and (not b._touch_mode or b._box_mode):
			var cur: Vector2 = b._drag_cur if b._touch_mode else get_global_mouse_position()
			var r: Rect2 = b._rect_from(b._drag_from, cur)
			draw_rect(r, Color(0.4, 1.0, 0.5, 0.08), true)
			draw_rect(r, Color(0.4, 1.0, 0.5, 0.9), false, 1.5)
		if b._click_fx_t > 0.0:
			var t: float = b._click_fx_t / 0.5
			var c := Color(1.0, 0.35, 0.25, t) if b._click_fx_attack else Color(0.4, 1.0, 0.5, t)
			var gr := 1.0 - t
			# 下令落点 ping（放大+双环+中心点，触屏更醒目；红=攻击 绿=移动/采集）
			draw_arc(b._click_fx_pos, 8.0 + 20.0 * gr, 0.0, TAU, 22, c, 3.0)
			draw_arc(b._click_fx_pos, 4.0 + 9.0 * gr, 0.0, TAU, 18, Color(c.r, c.g, c.b, t * 0.7), 2.0)
			draw_circle(b._click_fx_pos, 3.0 * t, Color(c.r, c.g, c.b, t))
		# 指向施法预览：按下技能即在地面显示「作用范围指示器」（跟随鼠标，等距投影）。
		# 形状随技能：闪现/突刺/冲锋=直线箭头(封顶最大射程)；箭雨=前方扇形；其余点目标=圆圈。
		if b._ability_armed != "":
			_draw_cast_indicator(b.ability_def(b._ability_armed))
		# 建造放置预览：占地框（绿=可建 / 红=不可）
		if b._build_armed != "":
			var bhalf: int = b.building_footprint_half(b._build_armed)
			# 触屏：虚影跟手指（_drag_cur 在拖动中实时更新，未拖时为视图中心）；桌面跟鼠标。
			var bref: Vector2 = b._drag_cur if b._touch_mode else get_global_mouse_position()
			var bcell: Vector2i = b.map.world_to_cell(b.to_logic(bref))
			var bdef: Dictionary = b._defs.get(b._build_armed, {})
			var bok: bool = b.map.area_buildable(bcell, bhalf) and not b._building_overlap(bcell, bhalf) \
				and b.can_afford(int(bdef.get("cost_gold", 0)), int(bdef.get("cost_wood", 0)))
			var cc := float(GameMap.CELL)
			var x0 := float(bcell.x - bhalf) * cc
			var x1 := float(bcell.x + bhalf + 1) * cc
			var y0 := float(bcell.y - bhalf) * cc
			var y1 := float(bcell.y + bhalf + 1) * cc
			var quad := PackedVector2Array([b.to_screen(Vector2(x0, y0)), b.to_screen(Vector2(x1, y0)), b.to_screen(Vector2(x1, y1)), b.to_screen(Vector2(x0, y1))])
			var bcol := Color(0.4, 1.0, 0.5) if bok else Color(1.0, 0.35, 0.3)
			draw_colored_polygon(quad, Color(bcol.r, bcol.g, bcol.b, 0.22))
			# 半透「建筑虚影」：直接在选址处画出这座建筑的样子（经典RTS式放置预览）
			var btex: Texture2D = Art.building_texture(b._build_armed)
			if btex != null:
				var ctr: Vector2 = b.to_screen(Vector2((float(bcell.x) + 0.5) * cc, (float(bcell.y) + 0.5) * cc))
				var gs := GameMap.building_visual_px(bhalf)
				draw_texture_rect(btex, Rect2(ctr - Vector2(gs * 0.5, gs * 0.78), Vector2(gs, gs)), false,
					Color(bcol.r, bcol.g, bcol.b, 0.5))
			draw_polyline(quad + PackedVector2Array([quad[0]]), bcol, 2.0)

	## 技能释放指示器：按技能命中几何画地面预览（直线箭头 / 前方扇形 / 圆圈），跟随鼠标。
	func _draw_cast_indicator(ad: Dictionary) -> void:
		var col: Color = ad.get("color", Color(1, 1, 1))
		var eff: Dictionary = ad.get("effect", {})
		var kind := String(eff.get("kind", ""))
		var mp := get_global_mouse_position()
		var lp: Vector2 = b.to_logic(mp)
		var caster = b._ability_caster
		var fill := Color(col.r, col.g, col.b, 0.14)
		var edge := Color(col.r, col.g, col.b, 0.85)
		# 方向型（直线/扇形）：须有施法者作为起点
		if caster != null and is_instance_valid(caster) and kind in ["line_nuke", "blink_shot", "charge", "sector_nuke"]:
			var origin: Vector2 = caster.position
			var dirv := lp - origin
			if dirv.length() < 1.0:
				dirv = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
			var dn := dirv.normalized()
			if kind == "sector_nuke":
				# 前方扇形：从施法者张开 arc°、半径 range
				var srange := float(eff.get("range", ad.get("radius", 120.0)))
				var shalf := deg_to_rad(float(eff.get("arc", 60.0)) * 0.5)
				var a0 := dn.angle()
				var fan := PackedVector2Array([b.to_screen(origin)])
				var seg := 22
				for i in range(seg + 1):
					var aa := a0 - shalf + (2.0 * shalf) * float(i) / float(seg)
					fan.append(b.to_screen(origin + Vector2(cos(aa), sin(aa)) * srange))
				draw_colored_polygon(fan, fill)
				draw_polyline(fan + PackedVector2Array([fan[0]]), edge, 2.0)
			else:
				# 直线走廊 + 箭头：长度封顶在最大射程（闪现=闪烁距离），宽=命中带宽
				var reach := float(eff.get("len", eff.get("dist", ad.get("radius", 120.0))))
				var hw := float(eff.get("width", 48.0)) * 0.5
				var travel := reach
				if kind == "blink_shot":
					travel = clampf(dirv.length(), 60.0, reach)   # 闪现落点随光标，但不超过闪烁距离
				var endp := origin + dn * travel
				var perp := Vector2(-dn.y, dn.x)
				# 满射程走廊（淡）：标出最大可达
				var maxend := origin + dn * reach
				var corr_max := PackedVector2Array([b.to_screen(origin + perp * hw), b.to_screen(maxend + perp * hw),
					b.to_screen(maxend - perp * hw), b.to_screen(origin - perp * hw)])
				draw_colored_polygon(corr_max, Color(col.r, col.g, col.b, 0.07))
				# 实际走廊
				var corr := PackedVector2Array([b.to_screen(origin + perp * hw), b.to_screen(endp + perp * hw),
					b.to_screen(endp - perp * hw), b.to_screen(origin - perp * hw)])
				draw_colored_polygon(corr, fill)
				draw_polyline(corr + PackedVector2Array([corr[0]]), edge, 2.0)
				# 中线 + 箭头
				draw_line(b.to_screen(origin), b.to_screen(endp), edge, 2.0)
				var tip: Vector2 = b.to_screen(endp)
				var bk: Vector2 = b.to_screen(endp - dn * 22.0)
				var sidep: Vector2 = b.to_screen(endp - dn * 22.0 + perp * 14.0) - bk
				draw_colored_polygon(PackedVector2Array([tip, bk + sidep, bk - sidep]), edge)
				if kind == "blink_shot":   # 落点标记
					draw_arc(tip, 9.0, 0.0, TAU, 18, Color(1, 1, 1, 0.9), 2.0)
			return
		# 冰墙：施法距离有限(range)——指示器把墙夹到最大射程处画出真实落点(不跟光标无限远)，
		# 并画一圈"最大可达"虚环；与 _do_ice_wall 的 clamp 完全一致，所见即所得。
		if caster != null and is_instance_valid(caster) and kind == "ice_wall":
			var origin: Vector2 = caster.position
			var rng := float(eff.get("range", 175.0))
			var dirv := lp - origin
			if dirv.length() < 1.0:
				dirv = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
			var dn := dirv.normalized()
			var reach := clampf(dirv.length(), 40.0, rng)   # 夹到最大射程
			var wc := origin + dn * reach
			var perp := Vector2(-dn.y, dn.x)
			var hl := float(eff.get("len", 150.0)) * 0.5
			var hw := 16.0
			# 最大可达范围环（等距椭圆，淡）：标出"最远能放到哪"
			var mring := PackedVector2Array()
			for i in range(40):
				var a := i * TAU / 40.0
				mring.append(b.to_screen(origin + Vector2(cos(a), sin(a)) * rng))
			draw_polyline(mring + PackedVector2Array([mring[0]]), Color(col.r, col.g, col.b, 0.22), 1.5)
			# 施法者 → 墙心 连线 + 真实墙体（夹紧后的落点）
			draw_line(b.to_screen(origin), b.to_screen(wc), edge, 1.5)
			var e1 := wc - perp * hl
			var e2 := wc + perp * hl
			var wall := PackedVector2Array([b.to_screen(e1 - dn * hw), b.to_screen(e2 - dn * hw),
				b.to_screen(e2 + dn * hw), b.to_screen(e1 + dn * hw)])
			draw_colored_polygon(wall, fill)
			draw_polyline(wall + PackedVector2Array([wall[0]]), edge, 2.0)
			return
		# 点目标（圆圈 AoE）：在光标处画作用范围环
		var rr: float = ad.get("radius", 90.0)
		var ring := PackedVector2Array()
		for i in range(48):
			var a := i * TAU / 48.0
			ring.append(b.to_screen(lp + Vector2(cos(a), sin(a)) * rr))
		draw_colored_polygon(ring, fill)
		draw_polyline(ring + PackedVector2Array([ring[0]]), edge, 2.0)
		draw_arc(mp, 4.0, 0.0, TAU, 16, Color(col.r, col.g, col.b, 0.95), 2.0)


# 限时演出基类：所有技能特效共用「t 倒计时→queue_free，每帧 queue_redraw」。
# 子类只需在 _ready 里设好 dur/t（默认各 1.0）并实现 _draw（必要时预生成粒子）。
class TimedFx extends Node2D:
	var dur := 1.0
	var t := 1.0

	func _process(delta: float) -> void:
		t -= delta
		if t <= 0.0:
			queue_free()
		queue_redraw()


class AbilityFx extends TimedFx:
	var rad := 90.0
	var col := Color.WHITE
	var _seed := 0

	func _ready() -> void:
		dur = 0.7
		t = 0.7
		_seed = (int(position.x) * 13 + int(position.y) * 7) % 360

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)            # 1→0
		var grow := 1.0 - f                            # 0→1 扩张
		var rr := rad * (0.5 + 0.6 * grow)
		# 冲击波（外扩环 + 内填充）
		draw_circle(Vector2.ZERO, rr, Color(col.r, col.g, col.b, f * f * 0.28))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(col.r, col.g, col.b, f * 0.95), 3.5 * f + 1.0)
		draw_arc(Vector2.ZERO, rr * 0.62, 0.0, TAU, 40, Color(col.r, col.g, col.b, f * 0.6), 2.0)
		# 起手瞬间的中心闪光
		if grow < 0.45:
			var fl := 1.0 - grow / 0.45
			draw_circle(Vector2.ZERO, rad * 0.28 * (0.4 + fl), Color(1, 1, 1, fl * 0.55))
		# 放射火花线
		var lc := Color(col.r, col.g, col.b, f * 0.85)
		for i in range(12):
			var a := deg_to_rad(_seed + i * 30.0)
			var dir := Vector2(cos(a), sin(a) * 0.6)   # 略压扁贴合等距
			draw_line(dir * rr * 0.55, dir * rr * (0.95 + 0.1 * sin(grow * 6.0)), lc, 2.0)


## 花荣·箭雨：一根根箭矢从天（屏幕上方）错峰落入 AoE 椭圆，落地小爆 + 插地余箭。
class ArrowRainFx extends TimedFx:
	const FALL := 0.24            # 单根下坠时长
	const DROP := 240.0           # 起始高度（屏幕像素）
	const N := 18
	var rad := 100.0
	var col := Color("a0e8c0")
	var _arrows: Array = []       # 每根：{p:Vector2(屏幕落点偏移), delay:float}

	func _ready() -> void:
		dur = 1.2
		t = 1.2
		for i in range(N):
			var a := randf() * TAU
			var dist := sqrt(randf()) * rad
			var lo := Vector2(cos(a), sin(a)) * dist          # 逻辑空间圆内随机点
			_arrows.append({"p": GameMap.ISO.basis_xform(lo), "delay": float(i) * (0.55 / float(N)) + randf() * 0.045})

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)   # 屏幕对齐：箭竖直坠落
		var elapsed := dur - t
		# 地面落点范围（淡椭圆）
		var gf := clampf(t / dur, 0.0, 1.0)
		var ring := PackedVector2Array()
		for i in range(28):
			var aa := float(i) / 28.0 * TAU
			ring.append(GameMap.ISO.basis_xform(Vector2(cos(aa), sin(aa)) * rad))
		draw_colored_polygon(ring, Color(col.r, col.g, col.b, 0.09 * gf))
		for ar in _arrows:
			var lt: float = elapsed - float(ar["delay"])
			if lt < 0.0:
				continue
			var lp: Vector2 = ar["p"]
			if lt < FALL:
				var prog := lt / FALL
				var tip := Vector2(lp.x, lp.y - DROP * (1.0 - prog))
				draw_line(tip + Vector2(0, -17), tip, Color(0.92, 0.88, 0.7, 0.92), 2.0)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 3), tip + Vector2(-2.6, -3), tip + Vector2(2.6, -3)]), Color(0.96, 0.93, 0.77))
				draw_line(tip + Vector2(0, -17), tip + Vector2(-2.6, -20), col, 1.3)
				draw_line(tip + Vector2(0, -17), tip + Vector2(2.6, -20), col, 1.3)
			else:
				var bt := clampf((lt - FALL) / 0.2, 0.0, 1.0)
				var bf := 1.0 - bt
				draw_circle(lp, 7.0 * (0.4 + bt), Color(col.r, col.g, col.b, 0.5 * bf))
				draw_line(lp, lp + Vector2(0, -9), Color(0.85, 0.8, 0.62, 0.65 * bf), 1.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 花荣·神箭：一根大箭自施法者破空射向目标，带拖影 + 命中爆裂；
## 定身箭(pin)更粗重，命中后留插地大箭 + 蓝色定身脉冲环。
class ArrowShotFx extends TimedFx:
	var end_w := Vector2.ZERO     # 目标逻辑坐标
	var col := Color("a0e8c0")
	var pin := false
	var big := false             # 花荣·箭雨改：加粗破空大箭
	var travel := 0.0
	var _E := Vector2.ZERO        # 目标相对起点的屏幕偏移
	var _ang := 0.0

	func _ready() -> void:
		travel = 0.24 if (pin or big) else 0.18
		dur = travel + (0.6 if (pin or big) else 0.34)
		t = dur
		_E = GameMap.ISO.basis_xform(end_w - position)
		_ang = _E.angle()

	func _draw() -> void:
		var elapsed := dur - t
		var tp := clampf(elapsed / travel, 0.0, 1.0)
		var dist := _E.length()
		var w := 5.0 if (pin or big) else 3.6        # 大箭：粗箭杆
		if tp < 1.0:
			# 飞行段：旋转到飞行方向，箭沿 +X 前进
			draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_ang, Vector2.ZERO))
			var x := dist * tp
			var trail := 90.0 if (pin or big) else 70.0   # 长拖尾（动感）
			# 发光拖尾：一条渐隐的粗光带
			for k in range(9):
				var f0 := float(k) / 9.0
				var tx0 := x - trail * f0
				var tx1 := x - trail * (f0 + 1.0 / 9.0)
				if tx1 < 0.0:
					tx1 = 0.0
				draw_line(Vector2(tx0, 0), Vector2(tx1, 0), Color(col.r, col.g, col.b, (0.5 - 0.5 * f0) * 0.8), w * (1.6 - 1.1 * f0))
				if tx1 <= 0.0:
					break
			# 起手枪口闪光（前 40% 行程在尾端留亮斑）
			if tp < 0.4:
				draw_circle(Vector2.ZERO, 9.0 * (1.0 - tp / 0.4), Color(1, 0.98, 0.8, 0.7 * (1.0 - tp / 0.4)))
			# 箭杆 + 亮芯
			draw_line(Vector2(x - 26, 0), Vector2(x, 0), Color(0.6, 0.5, 0.3, 0.9), w + 2.0)   # 暗描边
			draw_line(Vector2(x - 26, 0), Vector2(x, 0), Color(1, 0.98, 0.85, 1.0), w)
			# 大箭头
			var hl := 16.0 if (pin or big) else 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + hl, 0), Vector2(x - 1, -hl * 0.55), Vector2(x - 1, hl * 0.55)]), Color(1, 0.99, 0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(x + hl + 4, 0), Vector2(x + hl * 0.4, -hl * 0.28), Vector2(x + hl * 0.4, hl * 0.28)]), Color(col.r, col.g, col.b, 0.9))
			# 尾羽
			draw_line(Vector2(x - 26, 0), Vector2(x - 34, -6), col, w * 0.7)
			draw_line(Vector2(x - 26, 0), Vector2(x - 34, 6), col, w * 0.7)
		else:
			# 命中段：屏幕对齐，于目标处爆裂
			draw_set_transform_matrix(GameMap.ISO_INV)
			var bt := clampf((elapsed - travel) / maxf(dur - travel, 0.01), 0.0, 1.0)
			var bf := 1.0 - bt
			draw_circle(_E, (16.0 if (pin or big) else 12.0) * (0.5 + bt), Color(col.r, col.g, col.b, 0.55 * bf))
			draw_arc(_E, (20.0 if (pin or big) else 14.0) * (0.6 + bt), 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.9 * bf), 2.0)
			if pin:
				draw_line(_E + Vector2(0, -22), _E, Color(0.9, 0.85, 0.66, 0.9 * bf), 3.0)
				draw_colored_polygon(PackedVector2Array([_E + Vector2(0, 2), _E + Vector2(-3.5, -5), _E + Vector2(3.5, -5)]), Color(1, 0.98, 0.85, bf))
				draw_arc(_E, 30.0 * bt, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.7 * bf), 2.0)
				draw_arc(_E, 18.0 * bt, 0.0, TAU, 20, Color(0.6, 0.85, 1.0, 0.5 * bf), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 火攻：地面腾起一片火舌 + 上飘火星。火舌错峰窜起又回落，外橙内黄。
class FlameburstFx extends TimedFx:
	var rad := 95.0
	var col := Color("ff7a2a")
	var _flames: Array = []
	var _embers: Array = []

	func _ready() -> void:
		dur = 0.85
		t = 0.85
		var n := 9 + int(rad / 14.0)
		for i in range(n):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_flames.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"delay": randf() * 0.28, "h": randf_range(24.0, 42.0), "w": randf_range(8.0, 15.0), "ph": randf() * TAU})
		for i in range(12):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_embers.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"delay": randf() * 0.4, "spd": randf_range(45.0, 90.0), "drift": randf_range(-12.0, 12.0)})

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var elapsed := dur - t
		for fl in _flames:
			var lt: float = elapsed - float(fl["delay"])
			if lt < 0.0:
				continue
			var k := clampf(lt / 0.5, 0.0, 1.0)
			if k >= 1.0:
				continue
			var base: Vector2 = fl["p"]
			var flick := sin(float(fl["ph"]) + elapsed * 22.0) * 2.5
			var hgt: float = float(fl["h"]) * (0.4 + 0.6 * sin(k * PI))   # 窜起又回落
			var wid: float = float(fl["w"]) * (1.0 - k * 0.65)
			var top := base + Vector2(flick, -hgt)
			var a := 0.92 * (1.0 - k)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid, 0), base + Vector2(wid, 0), top]), Color(col.r, col.g * 0.75, 0.1, a))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid * 0.5, -3), base + Vector2(wid * 0.5, -3), top + Vector2(0, 4)]), Color(1.0, 0.9, 0.38, a))
		for em in _embers:
			var lt: float = elapsed - float(em["delay"])
			if lt < 0.0:
				continue
			var k := clampf(lt / 0.6, 0.0, 1.0)
			if k >= 1.0:
				continue
			var pos: Vector2 = em["p"] + Vector2(float(em["drift"]) * k, -float(em["spd"]) * k)
			draw_circle(pos, 2.3 * (1.0 - k), Color(1.0, 0.72 + 0.2 * (1.0 - k), 0.2, 0.85 * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 落雷：一道折线天雷自屏上方劈下，前半程电光大亮，落点白闪 + 地面冲击环 + 分叉电火。
class LightningFx extends TimedFx:
	const DROP := 235.0
	var rad := 95.0
	var col := Color("8fd3ff")
	var _segs := PackedVector2Array()
	var _branches: Array = []

	func _ready() -> void:
		dur = 0.55
		t = 0.55
		var steps := 7
		_segs.append(Vector2(0.0, -DROP))
		for i in range(1, steps + 1):
			var y := -DROP * (1.0 - float(i) / float(steps))
			var x := 0.0 if i == steps else randf_range(-16.0, 16.0)
			_segs.append(Vector2(x, y))
		for i in range(3):
			var idx := randi_range(2, steps - 1)
			var o: Vector2 = _segs[idx]
			_branches.append([o, o + Vector2(randf_range(-32.0, 32.0), randf_range(-8.0, 22.0))])

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		# 地面冲击环（逻辑空间→椭圆）
		draw_arc(Vector2.ZERO, rad * (0.3 + 0.7 * grow), 0.0, TAU, 32, Color(col.r, col.g, col.b, f * 0.7), 2.5)
		draw_set_transform_matrix(GameMap.ISO_INV)
		draw_circle(Vector2.ZERO, 16.0 * (0.5 + grow), Color(0.82, 0.92, 1.0, f * 0.5))
		if t > dur * 0.4:
			var a := clampf((t - dur * 0.4) / (dur * 0.6), 0.0, 1.0)
			draw_polyline(_segs, Color(col.r, col.g, col.b, a), 7.0)   # 光晕
			draw_polyline(_segs, Color(1, 1, 1, a), 3.0)               # 亮芯
			for br in _branches:
				draw_line(br[0], br[1], Color(0.9, 0.96, 1.0, a * 0.8), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 鼓舞：金光腾起的微粒（夹愈合十字）自地面升起 + 地面金环。
class RallyFx extends TimedFx:
	var rad := 180.0
	var col := Color("ffd24a")
	var _motes: Array = []

	func _ready() -> void:
		dur = 0.95
		t = 0.95
		for i in range(18):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_motes.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"delay": randf() * 0.4, "spd": randf_range(45.0, 80.0), "cross": randf() < 0.35})

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		draw_arc(Vector2.ZERO, rad * (0.4 + 0.6 * grow), 0.0, TAU, 40, Color(col.r, col.g, col.b, f * 0.5), 2.5)
		draw_set_transform_matrix(GameMap.ISO_INV)
		var elapsed := dur - t
		for m in _motes:
			var lt: float = elapsed - float(m["delay"])
			if lt < 0.0:
				continue
			var k := clampf(lt / 0.6, 0.0, 1.0)
			if k >= 1.0:
				continue
			var pos: Vector2 = m["p"] + Vector2(0, -float(m["spd"]) * k)
			var a := 0.9 * (1.0 - k)
			if bool(m["cross"]):
				draw_line(pos + Vector2(-4, 0), pos + Vector2(4, 0), Color(1, 0.95, 0.6, a), 2.0)
				draw_line(pos + Vector2(0, -4), pos + Vector2(0, 4), Color(1, 0.95, 0.6, a), 2.0)
			else:
				draw_circle(pos, 2.6 * (1.0 - k * 0.5), Color(1.0, 0.86, 0.4, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 神行/疾风：三道风纹环自中心向外扩散 + 中心放射速度线。
class HasteFx extends TimedFx:
	var rad := 180.0
	var col := Color("9ce0a0")

	func _ready() -> void:
		dur = 0.6
		t = 0.6

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		for i in range(3):
			var rr := rad * (0.2 + 0.8 * grow) - float(i) * rad * 0.14
			if rr <= 0.0:
				continue
			var a := f * 0.7 * (1.0 - float(i) * 0.25)
			draw_arc(Vector2.ZERO, rr, deg_to_rad(200), deg_to_rad(340), 18, Color(col.r, col.g, col.b, a), 3.0)
			draw_arc(Vector2.ZERO, rr, deg_to_rad(20), deg_to_rad(160), 18, Color(col.r, col.g, col.b, a * 0.7), 2.0)
		draw_set_transform_matrix(GameMap.ISO_INV)
		for i in range(6):
			var ang := deg_to_rad(float(i) * 60.0 + grow * 40.0)
			var dir := Vector2(cos(ang), sin(ang) * 0.6)
			var r0 := rad * 0.3 * grow
			draw_line(dir * r0, dir * (r0 + 22.0), Color(col.r, col.g, col.b, f * 0.6), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 横扫：两道交叉大刀光弧划过 AoE，亮白前缘 + 中心激波环。
class SlashArcFx extends TimedFx:
	var rad := 110.0
	var col := Color("c0a0ff")
	var _a0 := 0.0

	func _ready() -> void:
		dur = 0.42
		t = 0.42
		_a0 = randf() * TAU

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var sweep := 1.0 - f
		var R := rad * 0.92
		var span := deg_to_rad(150.0)
		for s in range(2):
			var base := _a0 + float(s) * PI * 0.9
			var steps := 14
			var pts := PackedVector2Array()
			for i in range(steps + 1):
				var aa := base + span * sweep * float(i) / float(steps)
				var rr := R * (0.6 + 0.4 * float(i) / float(steps))
				pts.append(Vector2(cos(aa) * rr, sin(aa) * rr * 0.6))
			if pts.size() >= 2:
				draw_polyline(pts, Color(col.r, col.g, col.b, f * 0.85), 4.0)
			var lead := base + span * sweep
			draw_circle(Vector2(cos(lead) * R, sin(lead) * R * 0.6), 4.0 * f, Color(1, 1, 1, f * 0.9))
		draw_arc(Vector2.ZERO, R * sweep, 0.0, TAU, 28, Color(col.r, col.g, col.b, f * 0.5), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 浪里拖人：地面同心涟漪 + 中心水柱炸起 + 四溅水滴。
class WaterSplashFx extends TimedFx:
	var rad := 90.0
	var col := Color("5fbfe0")
	var _drops: Array = []

	func _ready() -> void:
		dur = 0.8
		t = 0.8
		for i in range(12):
			_drops.append({"ang": randf() * TAU, "spd": randf_range(60.0, 120.0), "delay": randf() * 0.1})

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		for i in range(3):
			var rr := rad * (0.2 + 0.9 * grow) - float(i) * rad * 0.22
			if rr > 0.0:
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 36, Color(col.r, col.g, col.b, f * 0.6 * (1.0 - float(i) * 0.25)), 2.5)
		draw_set_transform_matrix(GameMap.ISO_INV)
		var col_h := 34.0 * sin(clampf(grow * 2.2, 0.0, PI))
		draw_line(Vector2(0, 4), Vector2(0, -col_h), Color(0.8, 0.95, 1.0, f * 0.8), 5.0)
		draw_circle(Vector2(0, -col_h), 5.0 * f, Color(0.9, 0.98, 1.0, f * 0.85))
		var elapsed := dur - t
		for d in _drops:
			var lt: float = elapsed - float(d["delay"])
			if lt < 0.0:
				continue
			var k := lt / 0.6
			if k >= 1.0:
				continue
			var dir := Vector2(cos(float(d["ang"])), sin(float(d["ang"])) * 0.6)
			var horiz := dir * float(d["spd"]) * k
			var vert := -float(d["spd"]) * 1.1 * k + float(d["spd"]) * 1.6 * k * k
			draw_circle(horiz + Vector2(0, vert), 2.4 * (1.0 - k * 0.5), Color(0.85, 0.96, 1.0, 0.85 * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 蒙汗药：翻涌的绿毒雾团（贴地椭圆，脉动）+ 上升毒泡。
class PoisonCloudFx extends TimedFx:
	var rad := 110.0
	var col := Color("b8e060")
	var _blobs: Array = []
	var _bubbles: Array = []

	func _ready() -> void:
		dur = 1.2
		t = 1.2
		for i in range(9):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad * 0.8
			_blobs.append({"p": Vector2(cos(a), sin(a)) * d, "r": randf_range(18.0, 30.0), "ph": randf() * TAU})
		for i in range(10):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_bubbles.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d), "delay": randf() * 0.6, "spd": randf_range(20.0, 40.0)})

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var env := sin((1.0 - f) * PI)   # 0→1→0 淡入淡出
		var elapsed := dur - t
		for bl in _blobs:
			var pulse := 1.0 + 0.18 * sin(float(bl["ph"]) + elapsed * 4.0)
			draw_circle(bl["p"], float(bl["r"]) * pulse, Color(col.r, col.g, col.b * 0.5, 0.2 * env))
		draw_set_transform_matrix(GameMap.ISO_INV)
		for bu in _bubbles:
			var lt: float = elapsed - float(bu["delay"])
			if lt < 0.0:
				continue
			var k := clampf(lt / 0.9, 0.0, 1.0)
			if k >= 1.0:
				continue
			var pos: Vector2 = bu["p"] + Vector2(0, -float(bu["spd"]) * k)
			draw_circle(pos, 2.6 * (1.0 - k * 0.4), Color(col.r, col.g, col.b * 0.4, 0.6 * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 飞石：一记石子破空飞向目标，带短拖影，命中处腾起尘爆。
class StoneFx extends TimedFx:
	var end_w := Vector2.ZERO
	var col := Color("cfd6dd")
	var travel := 0.0
	var _E := Vector2.ZERO
	var _ang := 0.0

	func _ready() -> void:
		travel = 0.16
		dur = travel + 0.28
		t = dur
		_E = GameMap.ISO.basis_xform(end_w - position)
		_ang = _E.angle()

	func _draw() -> void:
		var elapsed := dur - t
		var tp := clampf(elapsed / travel, 0.0, 1.0)
		var dist := _E.length()
		if tp < 1.0:
			draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_ang, Vector2.ZERO))
			var x := dist * tp
			for k in range(5):
				var f0 := float(k) / 5.0
				draw_circle(Vector2(x - 16.0 * f0, 0), 4.0 * (1.0 - f0 * 0.6), Color(col.r, col.g, col.b, 0.5 - 0.4 * f0))
			draw_circle(Vector2(x, 0), 4.5, Color(0.52, 0.52, 0.58))
			draw_circle(Vector2(x - 1, -1), 2.0, Color(0.78, 0.78, 0.82))
		else:
			draw_set_transform_matrix(GameMap.ISO_INV)
			var bt := clampf((elapsed - travel) / maxf(dur - travel, 0.01), 0.0, 1.0)
			var bf := 1.0 - bt
			draw_circle(_E, 10.0 * (0.5 + bt), Color(0.7, 0.68, 0.6, 0.5 * bf))
			for i in range(6):
				var a := deg_to_rad(float(i) * 60.0)
				var dd := Vector2(cos(a), sin(a) * 0.6)
				draw_line(_E + dd * 4.0, _E + dd * (14.0 * (0.4 + bt)), Color(0.75, 0.72, 0.62, 0.7 * bf), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 战争迷雾层（world 子节点，套等距投影）：把 w×h 迷雾贴图铺满地图
class FogLayer extends Node2D:
	var tex: Texture2D
	var ws := Vector2.ZERO

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, ws), false)


## 空气浮尘：屏幕空间内缓缓飘动的暖色微粒（阳光里的尘埃），给静态画面添一层「活气」。
## 极淡、缓慢，不喧宾夺主；HUD 在更高层会盖住面板区。
class AmbientMotes extends Node2D:
	const N := 30

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var vpn := get_viewport()
		if vpn == null:
			return   # 场景拆卸时 viewport 可能为 null，跳过本帧绘制，避免崩溃
		var vp := vpn.get_visible_rect().size
		var t := Time.get_ticks_msec() / 1000.0
		for i in range(N):
			var bx := float((i * 131 + 7) % 1000) / 1000.0 * vp.x
			var by := float((i * 197 + 31) % 1000) / 1000.0 * vp.y
			var spd := 7.0 + float(i % 5) * 2.5
			var x := fposmod(bx + sin(t * 0.25 + float(i)) * 16.0 + t * spd * 0.35, vp.x + 40.0) - 20.0
			var y := fposmod(by - t * spd * 0.6, vp.y + 40.0) - 20.0
			var tw := 0.5 + 0.5 * sin(t * 0.8 + float(i) * 1.3)
			var a := 0.035 + 0.05 * tw
			var r := 1.1 + 0.7 * float(i % 3)
			draw_circle(Vector2(x, y), r, Color(1.0, 0.93, 0.72, a))


## 地面斑驳光影层：在地图范围内确定性撒布柔和亮/暗斑，模拟云隙阳光，打破纯色地面。
class DappleLayer extends Node2D:
	var tex: Texture2D
	var ws := Vector2.ZERO

	func _draw() -> void:
		if tex == null:
			return
		var n := 40
		for i in range(n):
			var hx := float((i * 73 + 17) % 997) / 997.0
			var hy := float((i * 131 + 53) % 991) / 991.0
			var pos := Vector2(hx * ws.x, hy * ws.y)
			var r := 110.0 + float((i * 97) % 90) * 2.4
			var light := (i % 2 == 0)
			var col := Color(1.0, 0.95, 0.80, 0.085) if light else Color(0.10, 0.12, 0.17, 0.085)
			draw_texture_rect(tex, Rect2(pos - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, col)


class FadingMark extends Node2D:
	var t := 1.2

	func _process(delta: float) -> void:
		t -= delta
		if t <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 9.0, Color(0.35, 0.1, 0.08, clampf(t, 0.0, 1.0) * 0.7))


## 近战命中火花：几道迸射的短线 + 一闪白点（直立空间，抵消等距斜切）
class HitSpark extends Node2D:
	var t := 0.18
	var dur := 0.18
	var heavy := false
	var _seed := 0

	func _ready() -> void:
		_seed = get_index() * 37 + int(position.x) + int(position.y)

	func _process(delta: float) -> void:
		t -= delta
		if t <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		draw_set_transform_matrix(GameMap.ISO_INV)
		var n := 6 if heavy else 4
		var reach := (16.0 if heavy else 11.0) * (1.3 - 0.3 * f)
		var col := Color(1.0, 0.95, 0.7, f * 0.9)
		for i in range(n):
			var ang := float(_seed % 17) * 0.3 + i * TAU / n
			var d := Vector2(cos(ang), sin(ang) * 0.7)
			draw_line(d * reach * 0.4, d * reach, col, 2.0 if heavy else 1.5)
		draw_circle(Vector2.ZERO, (5.0 if heavy else 3.0) * f, Color(1, 1, 1, f * 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 飘字伤害数字：上飘 + 淡出。暴击金色放大并带「!」，落己方时偏红。
class FloatLabel extends Node2D:
	var amount := 0
	var crit := false
	var on_player := false
	var t := 0.0
	const DUR := 0.72
	const CDUR := 0.95

	func _process(delta: float) -> void:
		t += delta
		if t >= (CDUR if crit else DUR):
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var dur := CDUR if crit else DUR
		var f := clampf(t / dur, 0.0, 1.0)
		var font := ThemeDB.fallback_font
		var sz := 26 if crit else 17
		# 暴击有个「弹出」放大：前 1/4 段从 1.25x 收到 1.0x
		var pop := 1.0 + 0.28 * clampf(1.0 - f * 4.0, 0.0, 1.0) if crit else 1.0
		var size := int(round(sz * pop))
		# 上飘：减速曲线（开头快，后段缓）
		var rise := -34.0 * (1.0 - pow(1.0 - f, 2.0))
		var alpha := 1.0 if f < 0.6 else (1.0 - (f - 0.6) / 0.4)
		var col: Color
		if crit:
			col = Color(1.0, 0.86, 0.2, alpha)
		elif on_player:
			col = Color(1.0, 0.55, 0.45, alpha)
		else:
			col = Color(1.0, 0.97, 0.86, alpha)
		var txt := str(amount)
		if crit:
			txt += "!"
		draw_set_transform_matrix(GameMap.ISO_INV)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
		var pos := Vector2(-w * 0.5, rise)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, alpha * 0.85))
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 地面烈焰（DOT 区域演出）：半径内持续腾起火舌 + 飞火星，整段 life 秒里反复窜起，
## 首尾各 0.5 秒淡入淡出。只负责画；伤害在 Battle._ground_dot_pass 结算。
class GroundFireFx extends TimedFx:
	var rad := 95.0
	var col := Color("ff7a2a")
	var life := 5.0
	var _flames: Array = []
	var _embers: Array = []

	func _ready() -> void:
		dur = life
		t = life
		var n := 10 + int(rad / 10.0)
		for i in range(n):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_flames.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"h": randf_range(20.0, 40.0), "w": randf_range(7.0, 14.0),
				"ph": randf() * TAU, "rate": randf_range(1.4, 2.4)})
		for i in range(int(rad / 8.0) + 6):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_embers.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"ph": randf() * TAU, "spd": randf_range(34.0, 70.0), "drift": randf_range(-10.0, 10.0)})

	func _draw() -> void:
		var elapsed := dur - t
		var env := clampf(elapsed / 0.5, 0.0, 1.0) * clampf(t / 0.5, 0.0, 1.0)
		draw_circle(Vector2.ZERO, rad * 0.92, Color(0.12, 0.04, 0.03, 0.16 * env))   # 焦地暗斑（贴地椭圆）
		draw_set_transform_matrix(GameMap.ISO_INV)
		for fl in _flames:
			var base: Vector2 = fl["p"]
			var cyc := sin(float(fl["ph"]) + elapsed * float(fl["rate"]) * PI)
			var k := 0.5 + 0.5 * cyc
			var flick := sin(float(fl["ph"]) * 1.7 + elapsed * 20.0) * 2.2
			var hgt: float = float(fl["h"]) * (0.35 + 0.65 * k) * env
			var wid: float = float(fl["w"]) * (0.7 + 0.3 * k)
			var top := base + Vector2(flick, -hgt)
			var a := 0.9 * env * (0.5 + 0.5 * k)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid, 0), base + Vector2(wid, 0), top]), Color(col.r, col.g * 0.7, 0.08, a))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid * 0.5, -2), base + Vector2(wid * 0.5, -2), top + Vector2(0, 4)]), Color(1.0, 0.88, 0.36, a))
		for em in _embers:
			var k := fposmod(elapsed * float(em["spd"]) * 0.02 + float(em["ph"]), 1.0)
			var epos: Vector2 = em["p"] + Vector2(float(em["drift"]) * k, -float(em["spd"]) * k)
			draw_circle(epos, 2.2 * (1.0 - k), Color(1.0, 0.7 + 0.2 * (1.0 - k), 0.2, 0.8 * env * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 撼地踏（震晕控制技演出）：落点地裂放射 + 尘环猛烈外扩 + 腾起的碎石。短促有力。
class StompFx extends TimedFx:
	var rad := 100.0
	var col := Color("ffd24a")
	var _cracks: Array = []
	var _debris: Array = []

	func _ready() -> void:
		dur = 0.6
		t = 0.6
		for i in range(7):
			_cracks.append({"a": randf() * TAU, "len": randf_range(0.55, 1.0), "w": randf_range(2.0, 3.5)})
		for i in range(12):
			var a := randf() * TAU
			_debris.append({"dir": Vector2(cos(a), sin(a) * 0.6), "spd": randf_range(60.0, 130.0)})

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		# 尘环 + 内冲击环（贴地椭圆）
		draw_arc(Vector2.ZERO, rad * (0.15 + 0.95 * grow), 0.0, TAU, 40, Color(0.78, 0.7, 0.55, f * 0.6), 5.0 * f + 1.5)
		draw_arc(Vector2.ZERO, rad * (0.05 + 0.6 * grow), 0.0, TAU, 36, Color(col.r, col.g, col.b, f * 0.7), 3.0)
		for cr in _cracks:   # 地裂：自中心放射的裂纹
			var a := float(cr["a"])
			var d := Vector2(cos(a), sin(a))
			var L := rad * float(cr["len"]) * clampf(grow * 1.6, 0.0, 1.0)
			draw_line(d * 6.0, d * L, Color(0.10, 0.07, 0.05, f * 0.85), float(cr["w"]))
		draw_set_transform_matrix(GameMap.ISO_INV)
		if grow < 0.4:
			var fl := 1.0 - grow / 0.4
			draw_circle(Vector2(0, -4), rad * 0.22 * (0.4 + fl), Color(1, 0.96, 0.8, fl * 0.6))
		var elapsed := dur - t
		for db in _debris:
			var k := clampf(elapsed / 0.5, 0.0, 1.0)
			if k < 1.0:
				var ddir: Vector2 = db["dir"]
				var horiz := ddir * float(db["spd"]) * k
				var vert := -float(db["spd"]) * 1.4 * k + float(db["spd"]) * 2.0 * k * k
				draw_circle(horiz + Vector2(0, vert), 2.4 * (1.0 - k), Color(0.5, 0.42, 0.32, 0.85 * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 黑旋风：三片刀光绕中心高速旋转（旋身狂砍），各拖一段渐隐光弧 + 前刃白点。
class WhirlFx extends TimedFx:
	var rad := 110.0
	var col := Color("ff5544")
	var _spin := 0.0

	func _ready() -> void:
		dur = 0.5
		t = 0.5
		_spin = randf() * TAU

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		var spin := _spin + grow * TAU * 1.7
		var R := rad * 0.9 * (0.55 + 0.45 * grow)
		for s in range(3):
			var base := spin + float(s) * TAU / 3.0
			var pts := PackedVector2Array()
			for i in range(10):
				var aa := base - 0.95 * float(i) / 9.0
				var rr := R * (1.0 - 0.04 * float(i))
				pts.append(Vector2(cos(aa) * rr, sin(aa) * rr * 0.6))
			draw_polyline(pts, Color(col.r, col.g, col.b, f * 0.85), 3.5)
			var lead := Vector2(cos(base) * R, sin(base) * R * 0.6)
			draw_circle(lead, 4.0 * f, Color(1, 1, 1, f * 0.9))
		# 外甩的刀风碎屑（更多动感）
		for i in range(6):
			var wa := spin * 1.3 + float(i) * TAU / 6.0
			var d := Vector2(cos(wa), sin(wa) * 0.6)
			draw_line(d * R * 0.7, d * R * (1.08 + 0.16 * sin(grow * 6.0 + float(i))), Color(col.r, col.g, col.b, f * 0.5), 1.6)
		draw_arc(Vector2.ZERO, R * 0.5, 0.0, TAU, 24, Color(col.r, col.g, col.b, f * 0.4), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 嗜血狂斩：两道交叉血色刀痕（X 形，带亮缘）+ 外飞的血珠（落地暗红）。
class BloodFx extends TimedFx:
	var rad := 95.0
	var col := Color("ff3322")
	var _drops: Array = []
	var _a0 := 0.0

	func _ready() -> void:
		dur = 0.45
		t = 0.45
		_a0 = randf() * TAU
		for i in range(14):
			var a := randf() * TAU
			_drops.append({"dir": Vector2(cos(a), sin(a) * 0.6), "spd": randf_range(70.0, 150.0), "r": randf_range(1.6, 3.2)})

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var sweep := 1.0 - f
		# 起手血光爆闪（更多视觉冲击）
		if sweep < 0.4:
			var fl := 1.0 - sweep / 0.4
			draw_circle(Vector2.ZERO, rad * 0.34 * (0.5 + fl), Color(1.0, 0.32, 0.28, fl * 0.42))
		for s in range(2):
			var base := _a0 + float(s) * PI * 0.5
			var pts := PackedVector2Array()
			for i in range(9):
				var aa := base - 0.7 + 1.4 * float(i) / 8.0
				var rr := rad * 0.85 * (0.3 + 0.7 * float(i) / 8.0) * (0.5 + 0.5 * sweep)
				pts.append(Vector2(cos(aa) * rr, sin(aa) * rr * 0.6))
			draw_polyline(pts, Color(0.7, 0.05, 0.04, f * 0.9), 4.5)
			draw_polyline(pts, Color(1.0, 0.5, 0.4, f * 0.8), 1.6)
		var elapsed := dur - t
		for d in _drops:
			var k := clampf(elapsed / 0.4, 0.0, 1.0)
			if k < 1.0:
				var ddir: Vector2 = d["dir"]
				var horiz := ddir * float(d["spd"]) * k
				var vert := -float(d["spd"]) * 0.7 * k + float(d["spd"]) * 1.3 * k * k
				draw_circle(horiz + Vector2(0, vert), float(d["r"]) * (1.0 - k * 0.5), Color(0.78, 0.06, 0.05, 0.9 * (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 豹影冲锋：朝面向（dir）猛扑——一串递隐的残影冲线 + 前缘人字光刃 + 地面冲尘。
class ChargeFx extends TimedFx:
	var rad := 92.0
	var col := Color("c0a0ff")
	var dir := 1.0   # 面向：+1 右 / -1 左

	func _ready() -> void:
		dur = 0.4
		t = 0.4

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var prog := 1.0 - f
		var lead := dir * rad * 1.15 * prog
		for k in range(6):
			var off := lead - dir * float(k) * 11.0
			var a := (0.72 - 0.1 * float(k)) * f
			if a > 0.0:
				draw_line(Vector2(off - dir * 16.0, -6.0 + float(k)), Vector2(off, -6.0 + float(k)), Color(col.r, col.g, col.b, a), 3.4 - 0.4 * float(k))
		var tip := Vector2(lead, -6.0)
		draw_line(tip, tip - Vector2(dir * 13.0, 11.0), Color(1, 1, 1, f * 0.9), 3.0)
		draw_line(tip, tip - Vector2(dir * 13.0, -11.0), Color(1, 1, 1, f * 0.9), 3.0)
		draw_circle(tip, 4.0 * f, Color(1, 1, 1, f * 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, rad * (0.3 + 0.6 * prog), 0.0, TAU, 28, Color(0.72, 0.66, 0.82, f * 0.32), 2.0)


## 花荣·定身神箭：一支重箭自上钉入目标，地面迸出六根尖桩组成「定身桩笼」+ 蓝色束缚脉冲环。
## 与「百步穿杨」的破空飞箭判然不同——这是把人「钉/定」在原地的控制演出。
class PinFx extends TimedFx:
	var rad := 55.0
	var col := Color("8fd3ff")
	var _stakes: Array = []

	func _ready() -> void:
		dur = 0.7
		t = 0.7
		for i in range(6):
			_stakes.append(TAU * float(i) / 6.0 + 0.25)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		var rr := rad * (0.5 + 0.5 * minf(grow * 2.0, 1.0))
		# 钉入的重箭：从上方猛插下、落定
		var drop := 56.0 * maxf(0.0, 1.0 - grow * 3.2)
		var tip := Vector2(0, 3 - drop)
		draw_line(Vector2(0, -28 - drop), tip, Color(0.6, 0.48, 0.3, f), 5.0)
		draw_line(Vector2(0, -28 - drop), tip, Color(1, 0.98, 0.85, f), 2.4)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 3), tip + Vector2(-4, -5), tip + Vector2(4, -5)]), Color(1, 0.99, 0.9, f))
		# 地面定身桩笼：六根尖桩自地里立起
		var up := minf(grow * 2.4, 1.0) * 15.0
		for a in _stakes:
			var base := Vector2(cos(a) * rr, sin(a) * rr * 0.6)
			draw_line(base, base + Vector2(0, -up), Color(0.72, 0.78, 0.5, f * 0.95), 3.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(0, -up - 5), base + Vector2(-2.6, -up + 1), base + Vector2(2.6, -up + 1)]), Color(0.86, 0.9, 0.6, f))
		# 蓝色束缚脉冲环（定身标志）
		for i in range(2):
			var pr := rr * (0.55 + 0.7 * grow) - float(i) * rr * 0.3
			if pr > 0.0:
				draw_arc(Vector2.ZERO, pr, 0.0, TAU, 28, Color(0.55, 0.82, 1.0, f * 0.75 * (1.0 - float(i) * 0.3)), 2.5)
		# 命中闪
		if grow < 0.4:
			var fl := 1.0 - grow / 0.4
			draw_circle(tip, 9.0 * (0.4 + fl), Color(0.8, 0.95, 1.0, fl * 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 林冲·丈八蛇矛横扫：一杆长矛绕身扫过 ~155°，矛身画出蜿蜒蛇形残影 + 矛尖银光 + 扫尾激波。
## 比通用「横扫」(双弧交叉) 更长、更具蛇矛甩劲——给林冲专属手感。
class SpearSweepFx extends TimedFx:
	var rad := 100.0
	var col := Color("c0a0ff")
	var _a0 := 0.0
	var _dir := 1.0

	func _ready() -> void:
		dur = 0.46
		t = 0.46
		_a0 = randf() * TAU
		_dir = -1.0 if randf() < 0.5 else 1.0

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var sweep := 1.0 - f
		var span := deg_to_rad(155.0)
		var cur := _a0 + _dir * span * sweep      # 当前矛尖角度
		var L := rad * 1.05                          # 矛长
		# 残影扇面（扫过的余光）
		var fan := PackedVector2Array([Vector2.ZERO])
		for i in range(13):
			var ang2 := _a0 + _dir * span * sweep * float(i) / 12.0
			fan.append(Vector2(cos(ang2) * L * 0.96, sin(ang2) * L * 0.96 * 0.6))
		draw_colored_polygon(fan, Color(col.r, col.g, col.b, f * 0.12))
		# 蛇形矛身：从握把到矛尖叠一条正弦扰动 → 蜿蜒
		var body := PackedVector2Array()
		for i in range(17):
			var u := float(i) / 16.0                  # 0 握把 → 1 矛尖
			var wob := sin(u * 5.5 + sweep * 7.0) * 6.0 * u
			var ang := cur + _dir * wob / maxf(L, 1.0)
			body.append(Vector2(cos(ang) * L * u, sin(ang) * L * u * 0.6))
		draw_polyline(body, Color(col.r * 0.6, col.g * 0.55, col.b * 0.7, f * 0.8), 5.5)
		draw_polyline(body, Color(col.r, col.g, col.b, f * 0.95), 2.4)
		# 矛尖银光 + 枪头
		var tip := Vector2(cos(cur) * L, sin(cur) * L * 0.6)
		draw_circle(tip, 5.0 * f, Color(1, 1, 1, f))
		var back := Vector2(cos(cur + _dir * 0.12) * (L - 16.0), sin(cur + _dir * 0.12) * (L - 16.0) * 0.6)
		draw_colored_polygon(PackedVector2Array([tip, back + Vector2(-3, -4), back + Vector2(3, 4)]), Color(0.95, 0.96, 1.0, f))
		# 扫尾激波环
		draw_arc(Vector2.ZERO, L * 0.55 * sweep, 0.0, TAU, 24, Color(col.r, col.g, col.b, f * 0.4), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 林冲 Q·破阵突刺：一杆巨枪从握点朝指向猛刺出去——枪身快速前探、枪尖银光爆裂，
## 沿途留一道紫色冲击带。直线长矛波，区别于绕身横扫。
class ThrustFx extends TimedFx:
	var end_w := Vector2.ZERO
	var col := Color("c0a0ff")
	var _E := Vector2.ZERO
	var _ang := 0.0

	func _ready() -> void:
		dur = 0.40
		t = dur
		_E = GameMap.ISO.basis_xform(end_w - position)
		_ang = _E.angle()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		var reach := _E.length()
		var x := reach * clampf(grow / 0.55, 0.0, 1.0)   # 前 55% 时间内刺到底
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_ang, Vector2.ZERO))
		# 冲击带（贯穿矩形余光）
		var hw := 16.0 * f + 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, -hw), Vector2(x, -hw * 0.5), Vector2(x, hw * 0.5), Vector2(0, hw)]),
			Color(col.r, col.g, col.b, f * 0.22))
		# 枪杆：暗描边 + 亮芯
		draw_line(Vector2(0, 0), Vector2(x, 0), Color(0.32, 0.26, 0.4, f * 0.9), 9.0)
		draw_line(Vector2(0, 0), Vector2(x, 0), Color(col.r, col.g, col.b, f), 4.5)
		draw_line(Vector2(maxf(0.0, x - 60.0), 0), Vector2(x, 0), Color(1, 1, 1, f * 0.9), 2.0)
		# 枪头（长菱形）+ 枪尖银爆
		var hl := 26.0
		draw_colored_polygon(PackedVector2Array([Vector2(x + hl, 0), Vector2(x - 4, -10), Vector2(x - 4, 10)]), Color(0.96, 0.97, 1.0, f))
		draw_circle(Vector2(x, 0), 7.0 * (0.5 + f), Color(1, 1, 1, f))
		# 枪尖放射激波
		if grow > 0.45:
			var bf := (grow - 0.45) / 0.55
			draw_arc(Vector2(reach, 0), 24.0 * bf, 0.0, TAU, 20, Color(col.r, col.g, col.b, (1.0 - bf) * 0.8), 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 花荣 Q·凌空闪：一道穿云箭流光从起点疾射到落点，两端各一记轻闪——强调「闪现」位移。
class BlinkShotFx extends TimedFx:
	var start_w := Vector2.ZERO
	var end_w := Vector2.ZERO
	var col := Color("a0e8c0")
	var _S := Vector2.ZERO
	var _E := Vector2.ZERO

	func _ready() -> void:
		dur = 0.42
		t = dur
		_S = GameMap.ISO.basis_xform(start_w - position)   # position == end_w（节点放在落点）
		_E = GameMap.ISO.basis_xform(end_w - position)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		# 箭流光：从起点向落点推进的亮带
		var head := _S.lerp(_E, clampf(grow / 0.6, 0.0, 1.0))
		draw_line(_S, head, Color(col.r, col.g, col.b, f * 0.5), 6.0)
		draw_line(_S, head, Color(1, 1, 1, f * 0.85), 2.2)
		# 起点残影闪（消失）
		var sf := f
		draw_arc(_S, 16.0 * (0.4 + grow), 0.0, TAU, 20, Color(col.r, col.g, col.b, sf * 0.7), 2.0)
		# 落点闪现绽放
		var ef := clampf(grow / 0.5, 0.0, 1.0)
		draw_circle(_E, 10.0 * ef, Color(1, 1, 1, f * 0.6))
		draw_arc(_E, 26.0 * ef, 0.0, TAU, 24, Color(col.r, col.g, col.b, f * 0.9), 2.5)
		for i in range(8):
			var a := deg_to_rad(i * 45.0)
			var d := Vector2(cos(a), sin(a) * 0.6)
			draw_line(_E + d * 8.0, _E + d * (10.0 + 18.0 * ef), Color(col.r, col.g, col.b, f * 0.7), 1.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 李逵 Q·双斧回旋：两柄板斧绕施法者高速旋飞，持续整个技能时长，并随李逵移动。
class OrbitAxesFx extends TimedFx:
	var target: Unit = null
	var rad := 120.0
	var col := Color("ff7744")
	var life := 3.0
	var _spin := 0.0

	func _ready() -> void:
		dur = life
		t = life

	func _process(delta: float) -> void:
		if is_instance_valid(target):
			position = target.position
		else:
			t = minf(t, 0.15)
		_spin += delta * 9.0
		super._process(delta)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var env := clampf((dur - t) / 0.2, 0.0, 1.0) * clampf(t / 0.25, 0.0, 1.0)
		var orbit := rad * 0.66
		for k in range(2):
			var a := _spin + float(k) * PI
			var c := Vector2(cos(a), sin(a)) * orbit
			# 旋飞拖影
			for j in range(5):
				var aj := a - float(j) * 0.16
				var cj := Vector2(cos(aj), sin(aj)) * orbit
				draw_circle(cj, 4.0, Color(col.r, col.g, col.b, env * 0.16 * (1.0 - float(j) / 5.0)))
			# 斧柄
			var hub := c * 0.34
			draw_line(hub, c, Color(0.5, 0.36, 0.22, env * 0.9), 3.0)
			# 斧刃（扇形钢面）
			var tang := Vector2(-sin(a), cos(a))
			var blade := PackedVector2Array([c + tang * 11.0, c + Vector2(cos(a), sin(a)) * 13.0 + tang * 4.0,
				c + Vector2(cos(a), sin(a)) * 13.0 - tang * 4.0, c - tang * 11.0])
			draw_colored_polygon(blade, Color(0.85, 0.87, 0.92, env))
			draw_polyline(blade, Color(1, 1, 1, env * 0.8), 1.2)
		# 地面旋风环
		draw_arc(Vector2.ZERO, orbit, 0.0, TAU, 28, Color(col.r, col.g, col.b, env * 0.35), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 林冲 R·时空封印：一座半透紫色时停穹顶罩住范围，缓转的刻度环 + 内部凝滞涟漪，持续 dur 秒。
class ChronoFx extends TimedFx:
	var rad := 150.0
	var col := Color("a070ff")
	var life := 10.0
	var _spin := 0.0

	func _ready() -> void:
		dur = life
		t = life

	func _process(delta: float) -> void:
		_spin += delta * 0.5
		super._process(delta)

	func _draw() -> void:
		var env := clampf((dur - t) / 0.4, 0.0, 1.0) * clampf(t / 0.6, 0.0, 1.0)
		# 畸变修正：全程留在 default 空间绘制——该空间已带等距投影，draw_circle/arc/line → 自动压扁成
		# 贴地椭圆/径向，与实际生效的地面圆域精确吻合。大范围下不再像以前用 ISO_INV 那样画成「悬浮正圆」。
		draw_circle(Vector2.ZERO, rad, Color(col.r, col.g, col.b, env * 0.14))            # 地面域填充
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, env * 0.85), 3.0)  # 外缘主环
		for i in range(3):
			var rr := rad * (0.72 - float(i) * 0.22)
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(col.r, col.g, col.b, env * 0.4), 1.6)
		for i in range(12):   # 缓转时钟刻度（沿地面径向，自动随等距压扁）
			var a := _spin + deg_to_rad(i * 30.0)
			var d := Vector2(cos(a), sin(a))
			draw_line(d * rad * 0.82, d * rad * 0.96, Color(0.85, 0.8, 1.0, env * 0.7), 2.0)
		draw_circle(Vector2.ZERO, rad * 0.16, Color(0.9, 0.85, 1.0, env * 0.32 * (0.6 + 0.4 * sin(_spin * 6.0))))


## 黑雨 DOT 演出（公孙胜 Q）：暗紫雨幕倾下 + 地面黑斑。机制伤害走 _ground_dots。
class BlackRainFx extends TimedFx:
	var rad := 100.0
	var col := Color("6a4fb0")
	var life := 10.0
	var follow: Unit = null   # 非空 → 每帧跟到施法者脚下（以己为心的黑雨）
	var _drops: Array = []

	func _ready() -> void:
		dur = life
		t = life
		for i in range(int(rad / 5.0) + 14):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_drops.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"ph": randf() * TAU, "spd": randf_range(120.0, 200.0), "h": randf_range(26.0, 46.0)})

	func _process(delta: float) -> void:
		if follow != null and is_instance_valid(follow) and follow.hp > 0.0:
			position = follow.position
		super._process(delta)

	func _draw() -> void:
		var elapsed := dur - t
		var env := clampf(elapsed / 0.4, 0.0, 1.0) * clampf(t / 0.6, 0.0, 1.0)
		draw_circle(Vector2.ZERO, rad * 0.95, Color(0.06, 0.03, 0.10, 0.20 * env))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(col.r, col.g, col.b, env * 0.5), 2.0)
		draw_set_transform_matrix(GameMap.ISO_INV)
		for dp in _drops:
			var k := fposmod(elapsed * float(dp["spd"]) * 0.02 + float(dp["ph"]), 1.0)
			var base: Vector2 = dp["p"]
			var top := base + Vector2(0, -float(dp["h"]) * (1.0 - k) - 6.0)
			var a := env * 0.75 * (0.4 + 0.6 * (1.0 - k))
			draw_line(top, top + Vector2(0, 7.0), Color(col.r, col.g * 0.7, col.b, a), 1.8)
			if k > 0.85:
				draw_circle(base, 2.4 * (k - 0.85) / 0.15, Color(0.5, 0.4, 0.7, env * 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 冰墙演出（公孙胜 W）：沿墙方向竖起一排半透明冰晶柱。
class IceWallFx extends TimedFx:
	var dir := Vector2.RIGHT
	var half_len := 65.0
	var col := Color("9fd8ff")
	var life := 5.0
	var _shards: Array = []

	func _ready() -> void:
		dur = life
		t = life
		var n := maxi(3, int(half_len * 2.0 / 22.0))
		for i in range(n + 1):
			var f := float(i) / float(n) * 2.0 - 1.0
			_shards.append({"off": dir * (f * half_len), "h": randf_range(20.0, 34.0),
				"w": randf_range(9.0, 14.0)})

	func _draw() -> void:
		var env := clampf((dur - t) / 0.25, 0.0, 1.0) * clampf(t / 0.5, 0.0, 1.0)
		draw_set_transform_matrix(GameMap.ISO_INV)
		for sh in _shards:
			var base: Vector2 = GameMap.ISO.basis_xform(sh["off"])
			var hgt: float = float(sh["h"]) * env
			var wid: float = float(sh["w"])
			var top := base + Vector2(0, -hgt)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid, 0), base + Vector2(wid, 0),
				base + Vector2(wid * 0.5, -hgt * 0.5), top, base + Vector2(-wid * 0.5, -hgt * 0.5)]),
				Color(col.r, col.g, col.b, 0.42 * env))
			draw_line(base, top, Color(0.95, 0.99, 1.0, 0.8 * env), 1.6)
			draw_line(base + Vector2(-wid, 0), base + Vector2(wid, 0), Color(0.8, 0.92, 1.0, 0.6 * env), 1.4)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 护甲/相克自检（ARMOR_TEST=1）：相克系数 ±10%、分类正确、全战斗单位护甲非 0、护甲已落到单位。
func _armor_selftest() -> void:
	var o := Vector2.ZERO
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.key == "hall":
			o = u.position
			break
	if o == Vector2.ZERO and not units.is_empty():
		o = units[0].position
	var qiang := spawn_unit("liang_qiang", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(o + Vector2(40, 0)))))
	var qi := spawn_unit("guan_qi", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(map.world_to_cell(o + Vector2(-40, 0)))))
	var gong := spawn_unit("liang_gong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(o + Vector2(0, 40)))))
	var dao := spawn_unit("guan_dao", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(map.world_to_cell(o + Vector2(0, -40)))))
	var cls_ok := qiang._counter_class() == "spear" and qi._counter_class() == "cav" and gong._counter_class() == "archer" and dao._counter_class() == "inf"
	# 相克环：枪>骑>远>步>枪（克 +10%、被克 −10%、无关 1.0）
	var counter_ok := absf(qiang._counter_mult(qi) - 1.1) < 0.001 and absf(qi._counter_mult(qiang) - 0.9) < 0.001 \
			and absf(qi._counter_mult(gong) - 1.1) < 0.001 and absf(gong._counter_mult(dao) - 1.1) < 0.001 \
			and absf(dao._counter_mult(qiang) - 1.1) < 0.001 and absf(qiang._counter_mult(gong) - 1.0) < 0.001
	# 全战斗单位护甲非 0
	var armor_nonzero := true
	var missing := ""
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if bool(d.get("building", false)) or bool(d.get("is_resource", false)) or bool(d.get("noncombat", false)) \
				or bool(d.get("captive", false)) or bool(d.get("objective", false)) or float(d.get("atk", 0)) <= 0.0:
			continue
		if Defs.armor_for(k, d) <= 0.0:
			armor_nonzero = false
			missing += k + " "
	var applied := dao.defense > 0.0 and absf(dao.defense - Defs.armor_for("guan_dao", Defs.UNITS["guan_dao"])) < 0.001
	var all_ok := cls_ok and counter_ok and armor_nonzero and applied
	print("[armor] cls=%s counter=%s nonzero=%s applied=%s ALL=%s | dao护甲=%.0f 缺:[%s]" % [cls_ok, counter_ok, armor_nonzero, applied, all_ok, dao.defense, missing])
	for u in [qiang, qi, gong, dao]:
		if is_instance_valid(u):
			u.take_damage(u.hp + 1.0, null)


## 新英雄自检（NEWHERO=1）：公孙胜/武松全技能 + 召唤/物免/削甲/减速/英雄上限。
func _newhero_selftest() -> void:
	var origin := Vector2.ZERO
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.key == "hall":
			origin = u.position
			break
	if origin == Vector2.ZERO and not units.is_empty():
		origin = units[0].position
	var gong := spawn_unit("gongsun_sheng", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(60, 0)))))
	var wus := spawn_unit("wu_song", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(-60, 0)))))
	var foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(0, 64)))))
	foe.defense = 8.0
	foe.max_hp = 9999.0
	foe.hp = 9999.0
	for h in [gong, wus]:
		for i in h.ability_slots.size():
			h.ability_slots[i]["rank"] = 2
			h.ability_slots[i]["cd_t"] = 0.0
		h._recompute_hero_stats()

	# 公孙胜 Q 黑雨 → _ground_dots 增长，且跟随施法者(follow==gong)，rank2 每秒22 → 每跳11
	var d0 := _ground_dots.size()
	_do_ability(gong, 0, foe.position)
	var blackrain_ok := _ground_dots.size() > d0
	var br_follow_ok: bool = not _ground_dots.is_empty() and _ground_dots[-1].get("follow") == gong and absf(float(_ground_dots[-1]["per"]) - 11.0) < 0.6

	# 公孙胜 W 冰墙 → _ice_walls 增长且锁了格子
	gong.ability_slots[1]["cd_t"] = 0.0
	var w0 := _ice_walls.size()
	_do_ability(gong, 1, foe.position)
	var icewall_ok := _ice_walls.size() > w0 and not _ice_walls.is_empty() and not (_ice_walls[-1]["cells"] as Array).is_empty()

	# 公孙胜 E 减速光环（被动）→ _aura_pass 后敌人 aura_slow<1（rank2=-20%）
	_aura_pass()
	var slow_ok := foe.aura_slow < 0.99

	# 公孙胜 R 画龙点睛 → 金龙血/攻同主、限时
	gong.ability_slots[3]["cd_t"] = 0.0
	_do_ability(gong, 3, gong.position)
	var dragon: Unit = null
	for u in units:
		if is_instance_valid(u) and u.key == "dragon_summon" and u.hp > 0.0:
			dragon = u
			break
	# rank2 copy_mult=1.5 → 血/攻=本体150%；且金龙为远程吐火带溅射50；限时10s
	var dragon_ok := dragon != null and absf(dragon.max_hp - gong.max_hp * 1.5) < 1.5 and absf(dragon.atk - gong.atk * 1.5) < 0.6 and dragon._summon_ttl > 0.0 and dragon.is_ranged and absf(float(dragon.setup_def.get("splash", 0.0)) - 50.0) < 0.1

	# 武松 Q 驱使猛虎 → 两只 tiger_summon，rank2 → hp150/atk15
	var nt0 := count_alive(Unit.FACTION_LIANG, "tiger_summon")
	_do_ability(wus, 0, wus.position)
	var tigers := count_alive(Unit.FACTION_LIANG, "tiger_summon") - nt0
	var tiger_stat_ok := false
	for u in units:
		if is_instance_valid(u) and u.key == "tiger_summon" and u.hp > 0.0:
			tiger_stat_ok = absf(u.max_hp - 150.0) < 1.0 and absf(u.atk - 15.0) < 0.5
			break
	var tigers_ok := tigers == 2 and tiger_stat_ok

	# 武松 W 三碗不过岗 → _drunk_t>0
	wus.ability_slots[1]["cd_t"] = 0.0
	_do_ability(wus, 1, wus.position)
	var drunk_ok := wus._drunk_t > 0.0

	# 武松 E 双戒刀 → 敌人 _def_down=4（rank2）+ 致盲 3s（攻击必失）
	wus.ability_slots[2]["cd_t"] = 0.0
	wus.position = foe.position + Vector2(20, 0)
	_do_ability(wus, 2, wus.position)
	var defdown_ok := foe._def_down >= 3.9
	var blind_ok := foe._blind_t > 0.0
	# 致盲落空：被致盲的 foe 普攻 gong，gong 不掉血
	gong.hp = gong.max_hp
	var gh := gong.hp
	foe._pending_target = gong
	foe._pending_done = false
	foe._deal_hit()
	var miss_ok := absf(gong.hp - gh) < 0.01

	# 武松 R 醉神 → 物免 + 普攻被挡累计 + 结束转血
	wus.ability_slots[3]["cd_t"] = 0.0
	_do_ability(wus, 3, wus.position)
	var immune_ok := wus._phys_immune_t > 0.0
	wus.hp = wus.max_hp * 0.5
	var hp_before := wus.hp
	foe._blind_t = 0.0   # 清掉前面 E 致盲（否则 foe 必失，挡不到伤害无法验证物免吸收）
	foe._pending_target = wus
	foe._pending_done = false
	foe._deal_hit()
	var absorbed_ok := wus.hp >= hp_before - 0.01 and wus._absorbed_phys > 0.0
	var hp_pre_heal := wus.hp
	wus._phys_immune_t = 0.0001
	wus._physics_process(0.01)
	var heal_ok := wus.hp > hp_pre_heal - 0.01

	# 宋江 R 替天行道·仁义（混合被动+主动）→ 群英雄回血(=Q回血量) + 宋江 Q 进入冷却
	var song := spawn_unit("song_jiang", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(0, -64)))))
	for i in song.ability_slots.size():
		song.ability_slots[i]["rank"] = 2
		song.ability_slots[i]["cd_t"] = 0.0
	song._recompute_hero_stats()
	var song_hybrid_ok := song.slot_has_active(3) and song.slot_ready(3)
	gong.hp = gong.max_hp * 0.4
	var gh0 := gong.hp
	_do_ability(song, 3, song.position)
	var song_rally_ok := gong.hp > gh0 + 1.0 and float(song.ability_slots[0]["cd_t"]) > 0.0
	# 宋江 E 火攻 → 每秒20·rank2持续8s → 每跳 10
	song.ability_slots[2]["cd_t"] = 0.0
	var sf0 := _ground_dots.size()
	_do_ability(song, 2, foe.position)
	var song_fire_ok := _ground_dots.size() > sf0 and absf(float(_ground_dots[-1]["per"]) - 10.0) < 0.6

	var cap_ok := level.hero_cap() == 4
	var all_ok := blackrain_ok and br_follow_ok and icewall_ok and slow_ok and dragon_ok and tigers_ok and drunk_ok and defdown_ok and blind_ok and miss_ok and immune_ok and absorbed_ok and heal_ok and song_hybrid_ok and song_rally_ok and song_fire_ok and cap_ok
	print("[newhero] blackrain=%s brfollow=%s icewall=%s slowaura=%s dragon=%s tigers=%s drunk=%s defdown=%s blind=%s miss=%s immune=%s absorbed=%s heal=%s songhybrid=%s songrally=%s songfire=%s cap=%s ALL=%s" % [blackrain_ok, br_follow_ok, icewall_ok, slow_ok, dragon_ok, tigers_ok, drunk_ok, defdown_ok, blind_ok, miss_ok, immune_ok, absorbed_ok, heal_ok, song_hybrid_ok, song_rally_ok, song_fire_ok, cap_ok, all_ok])

	# 清理：移除召唤物与测试单位，避免污染后续
	for u in units.duplicate():
		if is_instance_valid(u) and (u.key == "dragon_summon" or u.key == "tiger_summon" or u == foe or u == gong or u == wus or u == song):
			u.take_damage(u.hp + 1.0, null)


## 待结算队列里某将是否排了某槽（托管自检用）。
func _pending_has(who: Unit, slot: int) -> bool:
	for pc in _pending_casts:
		if pc["caster"] == who and int(pc["slot"]) == slot:
			return true
	return false


func _pending_lp(who: Unit, slot: int) -> Vector2:
	for pc in _pending_casts:
		if pc["caster"] == who and int(pc["slot"]) == slot:
			return pc["lp"]
	return Vector2.INF


## 自动镜头自检（AUTOCAM=1）：构造强/弱两处战团，确定性断言「最激烈处被选中、缩放合法、全员托管门控、会切走」。
func _autocam_selftest() -> void:
	var saved_af := ai_friendly
	ai_friendly = true
	phase = Phase.FIGHT
	var origin := Vector2(800, 1500)
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.key == "hall":
			origin = u.position
			break
	# 清场：移除已布官军 + 先前自检遗留的我方英雄（否则未托管的遗留英雄会污染「全员托管」判定）
	for v in units.duplicate():
		if not (is_instance_valid(v) and not v.is_building):
			continue
		if v.faction == Unit.FACTION_GUAN or (v.faction == Unit.FACTION_LIANG and v.is_hero):
			v.take_damage(v.hp + 1.0, null)
	var spawned: Array = []
	# 弱战团 A：1 我方英雄 + 2 步兵
	var A := origin + Vector2(0, 320)
	var ha := spawn_unit("lin_chong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(A))))
	ha.auto_micro = true
	spawned.append(ha)
	for k in range(2):
		spawned.append(spawn_unit("guan_dao", Unit.FACTION_GUAN, A + Vector2(24 + k * 18, 0)))
	# 强战团 B：1 我方英雄 + 6 步兵 + 1 敌将（权重远高于 A）
	var B := origin + Vector2(760, 0)
	var hb := spawn_unit("hua_rong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(B))))
	hb.auto_micro = true
	spawned.append(hb)
	for k in range(6):
		spawned.append(spawn_unit("guan_dao", Unit.FACTION_GUAN, B + Vector2(20 + (k % 3) * 22, (k / 3) * 22)))
	spawned.append(spawn_unit("hu_yanzhuo", Unit.FACTION_GUAN, B + Vector2(0, 30)))

	var managed_on := _all_heroes_managed()
	var pts := _combat_points()
	var pts_ok := pts.size() >= 6
	# 无焦点 → 应选中强战团 B
	_autocam_focus = Vector2.INF
	_autocam_repick()
	var pick_B := _autocam_focus != Vector2.INF and _autocam_focus.distance_to(B) < 160.0
	var zoom_ok := _autocam_target_zoom >= 0.85 and _autocam_target_zoom <= 1.7
	# 取消一名英雄托管 → 不再算「全员托管」（门控）
	hb.auto_micro = false
	var gate_ok := not _all_heroes_managed()
	hb.auto_micro = true
	# 焦点在弱战团 A，但 B 明显更激烈又远 → 应切到 B（不黏死在 A）
	_autocam_focus = A
	_autocam_repick()
	var switch_ok := _autocam_focus.distance_to(B) < 160.0
	# 检阅模式：清掉所有官军 → 无交战 → 应转去近景检阅我方英雄
	for s2 in spawned:
		if is_instance_valid(s2) and s2.faction == Unit.FACTION_GUAN:
			s2.take_damage(s2.hp + 1.0, null)
	_autocam_review_unit = null
	_autocam_repick()
	var review_ok := _autocam_review_unit != null and is_instance_valid(_autocam_review_unit) \
		and _autocam_review_unit.is_hero and _autocam_review_unit.faction == Unit.FACTION_LIANG \
		and absf(_autocam_target_zoom - AUTOCAM_REVIEW_ZOOM) < 0.01
	# 按钮流程：全托管下「点按钮」→ 接管；再点 → 释放（不点不接管）
	_autocam_enabled = false
	_autocam_active = false
	_autocam_tick(0.016)
	var btn_idle_ok := not _autocam_active        # 没点按钮 → 不接管
	toggle_autocam()
	_autocam_tick(0.016)
	var btn_on_ok := _autocam_enabled and _autocam_active
	toggle_autocam()
	_autocam_tick(0.016)
	var btn_off_ok := (not _autocam_enabled) and (not _autocam_active)
	var btn_ok := btn_idle_ok and btn_on_ok and btn_off_ok
	var all_ok := managed_on and pts_ok and pick_B and zoom_ok and gate_ok and switch_ok and review_ok and btn_ok
	print("[autocam] managed=%s pts=%d(%s) pickB=%s zoom_ok=%s gate=%s switch=%s review=%s btn=%s ALL=%s" % [
		managed_on, pts.size(), pts_ok, pick_B, zoom_ok, gate_ok, switch_ok, review_ok, btn_ok, all_ok])
	for s in spawned:   # 清理测试单位 + 复位
		if is_instance_valid(s):
			s.take_damage(s.hp + 1.0, null)
	_autocam_focus = Vector2.INF
	_autocam_review_unit = null
	ai_friendly = saved_af


## 托管 AI 自检（AUTOMICRO=1）：直接调 _brain_* / 工具函数做确定性断言——
## 不跑帧、不依赖 hud.touch_ui；每个子场景前清 _pending_casts 并复位 _cast_t，相互隔离。
func _automicro_selftest() -> void:
	var origin := Vector2.ZERO
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.key == "hall":
			origin = u.position
			break
	if origin == Vector2.ZERO and not units.is_empty():
		origin = units[0].position
	var park := origin + Vector2(0, 6000.0)   # 不参与当前场景的单位先挪到远处
	# 清场：移除据守战已布的官军（否则它们污染本测试以 origin 为中心的空间查询）
	for v in units.duplicate():
		if is_instance_valid(v) and v.faction == Unit.FACTION_GUAN and not v.is_building:
			v.take_damage(v.hp + 1.0, null)

	# 6 个梁山英雄（全 rank2、cd 清零）
	var lin := spawn_unit("lin_chong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(0, -40)))))
	var li := spawn_unit("li_kui", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(-40, 0)))))
	var wu := spawn_unit("wu_song", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(40, 0)))))
	var hua := spawn_unit("hua_rong", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(0, 40)))))
	var song := spawn_unit("song_jiang", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(-40, -40)))))
	var gong := spawn_unit("gongsun_sheng", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(40, -40)))))
	var heroes := [lin, li, wu, hua, song, gong]
	for h in heroes:
		for i in h.ability_slots.size():
			h.ability_slots[i]["rank"] = 2
			h.ability_slots[i]["cd_t"] = 0.0
		h._recompute_hero_stats()
		h.hp = h.max_hp

	# 3 个官军：骑兵 / 步兵 / 敌将（皆设超厚血，避免测试中阵亡）
	var ecav := spawn_unit("guan_qi", Unit.FACTION_GUAN, park)
	var emel := spawn_unit("guan_dao", Unit.FACTION_GUAN, park)
	var ehero := spawn_unit("hu_yanzhuo", Unit.FACTION_GUAN, park)
	var foes := [ecav, emel, ehero]
	for f in foes:
		f.max_hp = 99999.0
		f.hp = 99999.0
		f.set_stance(Unit.STANCE_PASSIVE)

	# ───── S0 工具函数 ─────
	var P := origin + Vector2(0, 300.0)
	ecav.position = P
	emel.position = P + Vector2(20, 0)
	ehero.position = P + Vector2(0, 20)
	var cav_unit := _nearest_foe_unit(P, Unit.FACTION_LIANG, true)
	var h_count := _foe_count_within(P, 60.0, Unit.FACTION_LIANG)
	var h_hero := _any_enemy_hero_within(P, 60.0, Unit.FACTION_LIANG)
	var h_summon0 := _count_my_summons(Unit.FACTION_LIANG, "tiger")
	lin.position = P + Vector2(0, -100)
	var rp := _retreat_point(lin, 200.0)
	var helpers_ok: bool = cav_unit == ecav and cav_unit.is_cavalry and h_count >= 3 and h_hero \
			and h_summon0 == 0 and map.is_open_world(rp) and (rp - P).length() > (lin.position - P).length()

	# ───── S1 武松召虎（tactic ④ + summon radius=0 放招）─────
	for f in foes:
		f.position = park
	wu.position = origin
	wu.hp = wu.max_hp
	wu._cast_t = 0.0
	emel.position = wu.position + Vector2(150, 0)   # 单个近战在 250 内、110 外
	_pending_casts.clear()
	_brain_wu(wu)
	var tiger_gate_ok := _pending_has(wu, 0)   # Q 驱使猛虎已入队（gate 修复后才放得出）

	# ───── S1a' 弱托管也要召虎：唯一的敌人放在防区外，弱托管仍应召虎（summon 无视防区/档位）─────
	wu._cast_t = 0.0
	wu.ability_slots[0]["cd_t"] = 0.0
	for f in foes:
		f.position = park
	emel.position = wu.position + Vector2(900, 0)   # 远在弱托管防区外
	_pending_casts.clear()
	_auto_micro_weak(wu)
	var weak_tiger_ok := _pending_has(wu, 0)

	# ───── S1b 武松『有大就开』(tactic ③)：被围≥2(无敌将)→开 R；单敌→不开 ─────
	wu._cast_t = 0.0
	for i in [0, 1, 2]:
		wu.ability_slots[i]["cd_t"] = 99.0   # 压住召虎/E/W，单测 R
	ecav.position = wu.position + Vector2(-40, 0)   # 2 个近战(骑兵+步兵，皆非英雄)在 160 内
	emel.position = wu.position + Vector2(40, 0)
	_pending_casts.clear()
	_brain_wu(wu)
	var wu_ult_on := _pending_has(wu, 3)
	wu._cast_t = 0.0
	ecav.position = park                             # 只剩 1 敌
	_pending_casts.clear()
	_brain_wu(wu)
	var wu_ult_ok := wu_ult_on and not _pending_has(wu, 3)
	for i in [0, 1, 2]:
		wu.ability_slots[i]["cd_t"] = 0.0

	# ───── S2 林冲专盯骑兵（tactic ①）─────
	lin.position = origin
	lin.hp = lin.max_hp
	lin._cast_t = 0.0
	lin._target = null
	lin.set_stance(Unit.STANCE_AGGRO)
	for i in [0, 1, 3]:
		lin.ability_slots[i]["cd_t"] = 99.0   # 压住放招，逼到索敌分支
	ecav.position = lin.position + Vector2(120, 0)   # 骑兵较远
	emel.position = lin.position + Vector2(80, 0)    # 非骑兵更近
	ehero.position = park
	_pending_casts.clear()
	_brain_lin(lin)
	var lin_focus_ok: bool = lin._target == ecav and lin._target.is_cavalry   # 越过更近的步兵，锁骑兵
	for i in [0, 1, 3]:
		lin.ability_slots[i]["cd_t"] = 0.0

	# ───── S3 花荣残血凌空闪朝『远离』方向（绝不传送进敌脸）─────
	for f in foes:
		f.position = park
	hua.position = origin
	hua.melee_mode = false
	hua.hp = hua.max_hp * 0.3
	hua._cast_t = 0.0
	emel.position = hua.position + Vector2(100, 0)   # 贴脸威胁 <150
	_pending_casts.clear()
	_brain_hua(hua)
	var blink_lp := _pending_lp(hua, 0)
	var hua_blink_ok: bool = blink_lp != Vector2.INF \
			and (blink_lp - emel.position).length() > (hua.position - emel.position).length()
	hua.hp = hua.max_hp

	# ───── S4 残血退撤（tactic ②）：李逵残血且大招没好 → 避战+回撤 ─────
	for f in foes:
		f.position = park
	li.position = origin
	li.hp = li.max_hp * 0.2
	li._cast_t = 0.0
	li.set_stance(Unit.STANCE_AGGRO)
	li.ability_slots[3]["cd_t"] = 99.0   # 大招不可用
	emel.position = li.position + Vector2(60, 0)
	_pending_casts.clear()
	_brain_li(li)
	var retreat_ok: bool = li.stance == Unit.STANCE_PASSIVE and li._state == Unit.ST_MOVE

	# ───── S5 李逵『有大就开』（tactic ③）：被围≥2 且大招好 → 开 R；单敌 → 不开 ─────
	li.hp = li.max_hp
	li.set_stance(Unit.STANCE_AGGRO)
	li._cast_t = 0.0
	li.ability_slots[3]["cd_t"] = 0.0
	li.ability_slots[0]["cd_t"] = 99.0   # 压住 Q/W，单测 R
	li.ability_slots[1]["cd_t"] = 99.0
	ecav.position = li.position + Vector2(-40, 0)
	emel.position = li.position + Vector2(40, 0)   # 两敌都在 150 内
	_pending_casts.clear()
	_brain_li(li)
	var ult_on_ok := _pending_has(li, 3)
	li._cast_t = 0.0
	ecav.position = park                            # 只剩 1 敌
	_pending_casts.clear()
	_brain_li(li)
	var ult_off_ok := not _pending_has(li, 3)
	var ult_ok := ult_on_ok and ult_off_ok
	li.ability_slots[0]["cd_t"] = 0.0
	li.ability_slots[1]["cd_t"] = 0.0

	# ───── S6 宋江 R/Q 互斥：有小兵残血→放 Q 不放 R；只英雄残血→放 R ─────
	for h in heroes:
		h.hp = h.max_hp
		h._cast_t = 0.0
	for f in foes:
		f.position = park
	song.position = origin
	song.set_stance(Unit.STANCE_AGGRO)
	lin.position = origin + Vector2(30, 0)
	lin.hp = lin.max_hp * 0.5            # 残血英雄（<0.6）
	var troop := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(50, 0)))))
	troop.hp = troop.max_hp * 0.3       # 残血小兵（troops_only 命中 → 顶住 R）
	_pending_casts.clear()
	_brain_song(song)
	var mutex_a_ok: bool = _pending_has(song, 0) and not _pending_has(song, 3)
	song._cast_t = 0.0
	troop.hp = troop.max_hp             # 小兵满血 → 只剩英雄残血
	_pending_casts.clear()
	_brain_song(song)
	var mutex_b_ok := _pending_has(song, 3)
	var song_mutex_ok := mutex_a_ok and mutex_b_ok

	# ───── S7 托管加点优先级：宋江火攻(E=2) / 花荣箭雨(W=1) / 林冲猎骑被动(E=2) 各自先点 ─────
	var learn_prio_ok := true
	for trip in [[song, 2], [hua, 1], [lin, 2]]:
		var hh: Unit = trip[0]
		var want: int = int(trip[1])
		for i in hh.ability_slots.size():
			hh.ability_slots[i]["rank"] = 0
		hh._hero_leveled = true
		hh.hero_level = 1
		hh.skill_points = 1
		_auto_learn(hh)
		for i in hh.ability_slots.size():
			if int(hh.ability_slots[i]["rank"]) != (1 if i == want else 0):
				learn_prio_ok = false

	# ───── S8 超视距技能有 CD 就放：宋江火攻(E)/花荣箭雨(W) 对单个远敌(250px)也放 ─────
	for h in heroes:
		h.hp = h.max_hp
		h._cast_t = 0.0
		h.set_stance(Unit.STANCE_AGGRO)
		for i in h.ability_slots.size():
			h.ability_slots[i]["rank"] = 2
			h.ability_slots[i]["cd_t"] = 0.0
		h._recompute_hero_stats()
	for f in foes:
		f.position = park
	for h in [lin, li, wu, hua, gong]:
		h.position = park            # 挪远其它英雄，免得宋江因友军/英雄触发 R/Q
	song.position = origin
	emel.position = song.position + Vector2(250, 0)
	_pending_casts.clear()
	_brain_song(song)
	var song_fire_cast := _pending_has(song, 2)
	hua.position = origin
	hua._cast_t = 0.0
	emel.position = hua.position + Vector2(250, 0)
	_pending_casts.clear()
	_brain_hua(hua)
	var hua_rain_cast := _pending_has(hua, 1)
	var lr_cast_ok := song_fire_cast and hua_rain_cast

	# ───── S9 远程英雄对超出 aggro(280) 的远敌(400px)也参战：箭雨超视距放；W进CD则攻击移动压上 ─────
	hua.position = origin
	hua._state = Unit.ST_IDLE
	hua._cast_t = 0.0
	for i in hua.ability_slots.size():
		hua.ability_slots[i]["cd_t"] = 0.0
	emel.position = hua.position + Vector2(400, 0)   # 超出 aggro 280、超出旧 330 上限
	_pending_casts.clear()
	_brain_hua(hua)
	var hua_far_w := _pending_has(hua, 1)             # 箭雨超视距砸 400 远敌
	hua.ability_slots[1]["cd_t"] = 99.0              # W 进 CD → 应攻击移动压上(state→AMOVE)
	hua._cast_t = 0.0
	hua._state = Unit.ST_IDLE
	hua._ai_dest = Vector2.INF
	_pending_casts.clear()
	_brain_hua(hua)
	var engage_ok := hua_far_w and hua._state == Unit.ST_AMOVE

	# ───── S8 集火优先：近处小兵 vs 略远敌将 → _focus_target 应挑敌将（敌将集火权重压过距离）─────
	for f in foes:
		f.position = park
	li.position = origin
	li._target = null
	emel.position = li.position + Vector2(60, 0)    # 近处杂兵(步兵)
	ehero.position = li.position + Vector2(210, 0)   # 略远敌将(呼延灼)
	var focus_pick := _focus_target(li, 320.0)
	var focus_ok := focus_pick == ehero             # 该集火敌将而非最近杂兵

	var all_ok := helpers_ok and tiger_gate_ok and weak_tiger_ok and wu_ult_ok and lin_focus_ok and hua_blink_ok and retreat_ok and ult_ok and song_mutex_ok and learn_prio_ok and lr_cast_ok and engage_ok and focus_ok
	print("[automicro] helpers=%s tigergate=%s weaktiger=%s wuult=%s linfocus=%s huablink=%s retreat=%s liult=%s songmutex=%s learnprio=%s lrcast(song=%s hua=%s)=%s engage(farW=%s)=%s focus=%s ALL=%s" % [
		helpers_ok, tiger_gate_ok, weak_tiger_ok, wu_ult_ok, lin_focus_ok, hua_blink_ok, retreat_ok, ult_ok, song_mutex_ok, learn_prio_ok, song_fire_cast, hua_rain_cast, lr_cast_ok, hua_far_w, engage_ok, focus_ok, all_ok])

	# 清理：移除本测试 spawn 的英雄/敌兵/召唤物，避免污染后续 skirmish
	for u in units.duplicate():
		if is_instance_valid(u) and (u in heroes or u in foes or u == troop or u.key == "tiger_summon" or u.key == "dragon_summon"):
			u.take_damage(u.hp + 1.0, null)
