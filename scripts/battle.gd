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
var _eco_last_wood := -1
var _eco_wood_stall := 0.0
var _eco_trap_cd := 0.0   # 全托管布陷阱节流
var _eco_trap_lane := 0   # 布陷阱轮换的来路序号（三门轮流照顾）
var _eco_lane_cache_bucket := -1   # 动态分路态势按 AI_TICK 缓存；6 将同拍共用，避免兵海里重复全表扫描
var _eco_lane_cache := {}
var _last_hb := 1.0       # 上次英雄倍率(变了就重算在场英雄血量)
const ECO_MAX_SITES := 2              # 同时在建的工地数（并行施工，盖得快、补得上被拆的）
const ECO_POP_HEADROOM := 10          # 人口余量(上限+在建民居 − 已用 − 在产)低于此值才补民居——按需建，不无脑堆满
const ECO_POP_MAX := 90               # 人口上限硬顶（容 40 常备军+6 英雄+农民有余）；到顶不再铺民居
const ECO_WCAP := 8                    # 平时农民目标（5采金 + 3伐木，给塔/民居稳定供木，少卡木荒）
const ECO_WCAP_WOOD := 12             # 木紧时农民上限：英雄之后主动多产喽啰，多出的全去伐木
const ECO_GOLD_MINERS := 5            # 金矿工目标（贴仓库·采矿效率 max，多留点金以备不时之需），其余伐木；木紧时-1
# 木头目标：库存 ≈ 金的一半（建房/塔期极费木，民居/仓库/集市是纯木 0 金）。低于此比例或绝对地板 = 吃紧。
const ECO_WOOD_RATIO := 0.6
const ECO_WOOD_FLOOR := 140
const ECO_MIN_WOODCUTTERS := 3
const ECO_ARMY_CAP := 40              # 兵营常备军上限（不含英雄/农民）
# 经济建筑(仓库/民居/集市)堆在金矿后方(安全角，远离东侧出兵口)护住人口；兵营在聚义厅、各塔往前沿外推御敌。
## 全托管常备建筑配额（出齐英雄后按序补，被拆即重建）。民居不在此列——改按人口需求动态补(见 _eco_house_needed)。塔走多塔种混搭、往前沿外推，构筑前置防线。
const ECO_MAINT := [["depot", 1, "gold"], ["barracks", 2, "hall"], ["market", 1, "gold"],
	["arrow_tower", 4, "front"], ["caltrop_tower", 2, "front"], ["thunder_tower", 3, "front"], ["altar_tower", 2, "front"]]
const ECO_FRONT_CELLS := 18.0    # 塔前推格数（聚义厅→敌向）：构筑前置防线，越大越靠前线（18×32 ≈ 576px）
const ECO_FRONT_CAP_FRAC := 0.55 # 塔前推距离上限 = hall→最近敌 ×此值：小图/敌近时别把半成品塔锚到敌脸上被秒
const ECO_TRAP_CAP := 6   # 全托管同时在场陷阱上限
const ECO_REVIVE_GOLD := 160   # 估算每个英雄复活所需金；复活留底线 = max(2,战死数)×此值
const ECO_HERO_ORDER := ["song_jiang", "hua_rong", "lin_chong", "gongsun_sheng", "li_kui", "wu_song"]
const ECO_HERO_TRAIN_MULT := 0.5   # 全托管(AI友好)专用·英雄训练提速：6 将同排一个聚义厅逐个练，原速要 ~3 分钟才凑齐，左侧英雄栏空太久。仅托管生效，手动/战役/1v1 训练时间不变。

var units: Array = []
var _grid: Dictionary = {}            # 空间网格(每物理帧重建)：Vector2i 格 → Array[Unit]，加速分离/光环/索敌的邻近查询
var _mob_grid: Dictionary = {}        # 仅存机动单位；分离按桶对遍历，避免每名单位重复查询 9 个邻桶
var _body_grid_liang: Dictionary = {} # 身体阻挡只查敌方机动单位；分阵营建桶，避免后排单位反复扫描大批友军
var _body_grid_guan: Dictionary = {}
var _focus_counts: Dictionary = {}    # 目标 instance_id → 有多少机动单位正锁定它(每物理帧随网格重建)；索敌打分的「过度集火」惩罚用
var _res_block_cache: Dictionary = {} # 资源点 instance_id → 是否被建筑压住(按物理帧缓存；排矿农民每帧都问，别每次全表扫建筑)
var _res_block_frame := -1
var _lite_fx := false                 # 机动单位过多(>90)：启用视觉预算，保留技能主体但限制逐目标反馈洪峰
var _mob_count := 0
var _sep_phase := 0
var _impact_fx_frame := 0
var _damage_fx_frame := 0
var _ground_fire_visuals := 0
var _unit_draw_rect := Rect2()
const LITE_IMPACT_BUDGET := 16
const LITE_DAMAGE_BUDGET := 12
const LITE_GROUND_FIRE_CAP := 8
var _no_opt := false                  # 压测对照(NO_OPT=1)：关掉 1.1.1 索敌限流，量优化前后差
var _stealth_acc := 0.0               # 潜行 pass 限流累加（不必每帧跑）
var _ecast_acc := 0.0                 # 敌将放招 pass 限流累加（不必每帧跑）
var _prof_on := false                 # 性能压测(PERF_BENCH)：逐帧给各系统计时；正常游玩为 false
var _prof := {}                       # 标签 → 累计微秒
var _prof_frames := 0
var _prof_print_acc := 0.0
var _unit_proc_us := 0                # 单位 _physics_process 累计耗时(由 unit.gd 回填)
const GRID_CELL := 64.0               # 空间网格边长(px)
var selection: Array = []
var phase := Phase.INTRO
var kills := 0
var hero_kills := {}          # 按英雄统计歼敌：instance_id -> {name, key, n}（战后结算展示）
var track_hero_combat_stats := false   # 仅驻守/自定义据守启用；其他模式的受击路径只多一次布尔判断
var hero_combat_stats := {}    # 英雄 key -> {name, damage, taken, kills}，英雄战死重练仍沿用
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
# 英雄专用科技倍率：只累计「聚义厅·时代科技」(tech_age2/age3)，不含兵营的利刃/坚铠——
# 兵营升级只强化常备军，英雄的攻防只受基地(聚义厅)升级影响(各 +10% 左右)。
var hero_tech_atk := 1.0
var hero_tech_hp := 1.0
var tech_gather := 1.0

# 战争迷雾
var fog := false
var _vision: PackedByteArray       # 每格 0=未探索 1=已探索(阴影) 2=明亮(当前确有视野)
var _sight_now: PackedByteArray    # 本次 pass 是否真正在某单位视野内（复用，免每帧重分配）
var _reveal_t: PackedFloat32Array  # 技能临时侦察剩余秒数；属于真实视野，不与地面驻留混用
var _vision_img: Image
var _fog_tex: ImageTexture
var _fog_layer: Node2D
var _fog_t := 0.0
const FOG_STEP := 0.18              # 迷雾逻辑/纹理刷新拍；明暗和敌军显隐在同一拍切换

var _dragging := false
var _drag_from := Vector2.ZERO
var _click_fx_pos := Vector2.ZERO
var _click_fx_t := 0.0
var _click_fx_attack := false
var _amove_armed := false
var _patrol_armed := false
var _repair_armed := false     # 武装维修：点己方受损建筑即派工人修缮
var _garrison_armed := false   # 武装驻扎：英雄「驻扎」键点亮后，左键点己方建筑即进驻
var _ability_armed := ""
var _ability_caster: Unit = null
var _ground_dots: Array = []   # 活动的地面烈焰 DOT：{pos,r,foe,caster,t,tick_t,tick,per}
var _hua_snipe_dots: Array = [] # 花荣 R 敌将单体百分比流血：{target,caster,t,tick_t,tick,pct}
var _chrono_zones: Array = []  # 时空封印立场：{pos,r,foe,t}——每帧把域内敌军续晕（林冲 R）
var _orbit_zones: Array = []   # 双斧回旋扫伤区：{caster,foe,r,t,tick,tick_t,dmg,slow,slow_dur}（李逵 Q）
var _meteor_zones: Array = []  # 天降陨石滚动区：{pos,dir,remain,hw,foe,caster,impact,dps,dot_dur,hit,trail}（宋江 W）
var _ice_walls: Array = []     # 冰墙阻挡：{cells:[Vector2i],t}——到期解锁格子（公孙胜 W）
var _wards: Array = []          # 立桩/旗阵：治疗、攻击、毒桩及忠义旗（减伤+忠回血/义攻速）
var _ward_serial := 0           # 忠义旗光环来源编号：让重叠旗按来源独立到期并正确降档
var _fire_trails: Array = []    # 火径：{caster,t,drop_t,drop,dps,dot_dur,r,foe}——随身移动沿途铺地火（魏定国 E）
var _bolts: Array = []          # 技能弹道：{mode:bolt/hook_out/hook_drag, pos,tgt/dir,eff,sc,rank,caster,fx}——追踪弹/钩镰
var _walk_casts: Array = []     # 走近施法队列：{c,slot,tgt/point,serial,t,age}——超射程时自动接近原目标再放
var _channels: Array = []       # 引导施法：{caster,center,eff,sc,rank,r,tick,tick_t}——逐 tick 结算，施法者被打断即止
var _pending_casts: Array = []  # 施法抬手·待结算队列：{caster,slot,lp}——抬手归零后才真正放招
const CAST_WINDUP := 0.34       # 施法抬手时长（秒）：先抬手蓄势，再结算技能
# 技能音效：先按技能 id 取签名音（标志性技能各有其声），否则按 effect.kind 取类型音，再退 "cast"
const ABILITY_SFX_ID := {
	"hua_rain": "sk_rain", "lin_chrono": "sk_chrono", "hua_blink": "sk_blink",
	"li_charge": "sk_charge", "li_fury": "sk_fury", "li_axes": "sk_axes",
	"lin_thrust": "sk_thrust", "lin_sweep": "sk_sweep",
	"song_rally": "sk_rally", "song_fire": "sk_fire", "song_banner": "sk_rally",
}
# （旧 ABILITY_SFX_KIND 共享类型音已废：非 6 将技能全部走 Sfx.play_ability 按 id 播种的专属音）
var _ability_slot := 0
var _build_armed := ""        # 待放置的建筑 key（遭遇战建造）
var _trap_armed := ""         # 待布置的陷阱 key（喽啰 E 子菜单·一次性机关）
var _worker_cat := ""         # 喽啰命令卡当前分类页：""=根 / "build"建筑 / "tower"塔 / "trap"陷阱
var _hall_page := 0           # 聚义厅「点将」菜单当前页（108 将太多 → 按星次分页）
var _hall_cat := ""           # 竞技场点将二级菜单当前分类：""=分类根页 / tiangang / disha_a / disha_b
var _traps: Array = []        # 已布置的陷阱：{key,pos,trigger_r,arm_t,effect,owner,fx}
var _active: Unit = null      # 当前子组「活动单位」（Tab 切换；命令卡/QWER 针对它）
var _inspect_unit: Unit = null  # 「查看中」的敌方单位（只读：显示信息+高亮，但不进 selection、不可下令）
var _demolish_armed_t := 0.0  # 拆除已成型建筑的二次确认计时
var _alert_t := 0.0           # 遭袭告警计时（小地图闪烁）
var _alert_pos := Vector2.ZERO
var _idle_i := 0              # 闲置喽啰轮询索引
var _groups := {}
var _last_group_key := -1
var _last_group_time := 0
var _camera_locs := {}     # Ctrl/⌘+F1-F4 记录；Shift+F1-F4 跳转
var _smoke := false
var _smoke_t := 0.0
var _touch_mode := false   # 触摸屏模式（一旦收到触摸事件即开启触摸交互：轻点选取、长按下令）
# 桌面端(Win/Mac exe)纯键鼠：默认不接触屏事件，避免触屏笔记本(如荣耀 MagicBook)误入触屏布局、
# 且杜绝杂散触摸打断鼠标框选/施法。仅移动端/网页/TOUCH_UI=1 预览才允许触屏交互。
var _allow_touch := OS.has_feature("mobile") or OS.has_feature("web") or OS.get_environment("TOUCH_UI") == "1"
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
	_refresh_hot_patch_classes()
	level = _resolve_level()
	track_hero_combat_stats = Campaign.skirmish or Campaign.custom_defense
	_defs = Defs.UNITS.duplicate(true)
	_abilities = Defs.ABILITIES.duplicate(true)
	Defs.apply_content_pack(_defs, _abilities)   # 内容包覆盖（res://content/*.json，无则不变）
	Art.set_runtime_alias({})                    # 清掉上局的运行时借图别名
	if level.has_method("apply_overrides"):
		level.apply_overrides(_defs, _abilities)   # 关卡级覆盖（场景编辑器：仅本场景的单位/技能改动）
	var dv := DotaVisuals.apply(_defs, _abilities)  # 108将 DOTA 批量视觉语义；跳过驻守战玩家 6 将
	if OS.get_environment("DOTA_VIS_AUDIT") == "1":
		print("[dota_visuals] heroes=%d abilities=%d visuals=%d" % [int(dv.get("heroes", 0)), int(dv.get("abilities", 0)), int(dv.get("visuals", 0))])

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
	# 不用 y_sort：它按「逻辑 y」排，而本作等距投影的屏幕深度是 (x+y)——单位站在建筑东南侧(屏幕上明明在前)
	# 会因 y 更小被建筑盖住。改为每帧按 z_index=(x+y) 排（_grid_build 顺路更新，星际/红警同款深度序）。
	units_root.y_sort_enabled = false
	world.add_child(units_root)

	fx_root = Node2D.new()
	fx_root.z_index = 3500   # 特效永远压在全体单位(z≤3400)之上，维持原「fx_root 在 units_root 之后」的层序
	world.add_child(fx_root)

	if fog:
		_init_fog()

	overlay = Overlay.new()
	overlay.b = self
	overlay.z_index = 3800   # 选框/指示器永远最上（HUD 之下）；单位深度 z≤3400
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
	# 按模式给「英雄托管」默认档：AI友好模式→全托管(彻底挂机)；其余模式→无托管(手动)。
	# 测试钩子 AUTO_MICRO 优先（设了就不覆盖），方便指定档位跑 smoke。
	if OS.get_environment("AUTO_MICRO") == "":
		Settings.auto_micro_level = 3 if ai_friendly else 0
	_autocam_target_zoom = camera.zoom.x

	_build_atmosphere()   # 后期处理层：暗角 + 暖色调 + 对比/饱和（在世界之上、HUD 之下）
	var _motes := AmbientMotes.new()   # 空气中缓缓飘动的暖色微尘（阳光浮尘），叠在调色之上
	_motes.z_index = 3750
	add_child(_motes)

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
		if OS.get_environment("ECO_RESEARCH_TEST") == "1":
			_eco_research_selftest()
		_hover_selftest()
		if OS.get_environment("COMBAT_STATS_TEST") == "1":
			_combat_stats_selftest()
		if OS.get_environment("HUA_REWORK_TEST") == "1":
			_hua_rework_selftest()
		if OS.get_environment("NEWHERO") == "1":
			_newhero_selftest()
		if OS.get_environment("ARMOR_TEST") == "1":
			_armor_selftest()
		if OS.get_environment("AUTOMICRO") == "1":
			_automicro_selftest()
		if OS.get_environment("AMOVE_SIDE_TEST") == "1":
			_amove_side_selftest()
		if OS.get_environment("SHIFTBUILD_TEST") == "1":
			_shiftbuild_selftest()
		if OS.get_environment("TOWERTRAP_TEST") == "1":
			_towertrap_selftest()
		if OS.get_environment("FINAL_CLEANUP_TEST") == "1":
			_final_cleanup_selftest()
		if OS.get_environment("DOTACAST") == "1":
			_dota_cast_selftest()
		if OS.get_environment("REWORK_TEST") == "1":
			_rework_selftest()
		if OS.get_environment("KIT2_TEST") == "1":
			_kit2_selftest()
		if OS.get_environment("TECH_TEST") == "1":
			_tech_selftest()
		if OS.get_environment("AUTOCAM") == "1":
			_autocam_selftest()
	else:
		Engine.time_scale = Settings.game_speed   # 实时节奏（设置可调慢/正常/快）：技能冷却/建造/训练/波次按倍率走时
		hud.show_intro(level.intro_lines())
	var info_ui_dir := OS.get_environment("INFO_UI_TEST_DIR")
	if info_ui_dir == "" and OS.get_environment("INFO_UI_TEST") == "1":
		info_ui_dir = OS.get_environment("SCREENSHOT_DIR")
	if info_ui_dir != "":
		await _info_ui_selftest(info_ui_dir)
		get_tree().quit()
		return
	if OS.get_environment("SCREENSHOT_DIR") != "":
		await _screenshot_loop(OS.get_environment("SCREENSHOT_DIR"))   # 保持协程引用，确保连拍能跨帧继续执行
	if OS.get_environment("BUILD_TEST") == "1":
		await _build_test()
	if OS.get_environment("PERF_BENCH") != "":
		_perf_bench_setup(int(OS.get_environment("PERF_BENCH")))
	if OS.get_environment("PROF") == "1":
		_prof_on = true   # 在真实关卡(配合 SMOKE_TEST 跑实际波次)上开 profiler，量真实瓶颈与敌军峰值
	if OS.get_environment("NO_OPT") == "1":
		_no_opt = true


## Godot 会在 AndroidUpdater 装入 PCK 前预载 class_name 脚本；内容补丁若升级 Unit，
## Battle 虽来自新 PCK，Unit 全局类却仍可能指向 APK 旧缓存。进入战斗、生成任何单位前用
## CACHE_MODE_IGNORE 强制 GDScript 从补丁重新读盘并原位 reload 缓存对象，既保留全局类型
## 身份，也让累计补丁里的新方法生效。CACHE_MODE_REPLACE 对 GDScript 仍会返回旧缓存，不能用。
func _refresh_hot_patch_classes() -> void:
	if not AndroidUpdater.enabled:
		return
	# 这里必须读取当前 Autoload 实例实际挂载的旧脚本常量；直接写
	# AndroidUpdater.BASE_CONTENT_VERSION 会在补丁 Battle 编译时折叠成新版常量，无法识别旧 APK。
	var updater_script: Script = AndroidUpdater.get_script()
	var packaged_content := String(updater_script.get_script_constant_map().get(
		"BASE_CONTENT_VERSION", AndroidUpdater.active_content_version))
	var active_content := String(AndroidUpdater.active_content_version)
	if active_content == packaged_content \
			or String(AndroidUpdater.get_meta("unit_cache_content_version", "")) == active_content:
		return
	var refreshed := ResourceLoader.load("res://scripts/unit.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	var probe := Unit.new()
	var reduction_api := probe.has_method("apply_damage_reduction") and probe.has_method("clear_damage_reduction")
	var charge_api := probe.has_method("slot_max_charges") and probe.has_method("slot_recharge_left")
	var aura_speed_api := probe.has_method("apply_aura_atkspeed") and probe.has_method("clear_aura_atkspeed")
	probe.free()
	if refreshed != null and reduction_api and charge_api and aura_speed_api:
		AndroidUpdater.set_meta("unit_cache_content_version", active_content)
	else:
		push_error("安卓内容补丁未能刷新 Unit 脚本缓存（content=%s）" % active_content)
	if OS.get_environment("ANDROID_UPDATE_TEST") == "1":
		print("[android_update] unit_cache_refresh=%s reduction_api=%s charge_api=%s aura_speed_api=%s" % [
			refreshed != null, reduction_api, charge_api, aura_speed_api])


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
	if track_hero_combat_stats and u.is_hero and faction == Unit.FACTION_LIANG:
		_ensure_hero_combat_stat(u.key, u.display_name)
	if u.ability != "" and _abilities.has(u.ability):
		u.ability_cd = _abilities[u.ability]["cd"]
	if economy and tech_hp != 1.0 and faction == Unit.FACTION_LIANG and not u.is_building and not u.is_hero:
		u.max_hp *= tech_hp
		u.hp = u.max_hp
	u.position = world_pos
	# 迷雾中新刷出的官军按「此刻真实视野」初始化，不能借用上一拍缓存先闪现一帧。
	if fog and faction == Unit.FACTION_GUAN:
		var seen_now := _has_live_sight_at(world_pos)
		u.fog_visible = (seen_now or is_explored_world(world_pos)) if u.is_building else seen_now
		u.visible = u.fog_visible
	u.died.connect(_on_unit_died)
	units.append(u)
	return u


func spawn_at(key: String, faction: int, cell: Vector2i) -> Unit:
	var d: Dictionary = _defs.get(key, {})
	var is_bld := bool(d.get("building", false)) and not d.has("res_kind")
	var blocks := is_bld and not bool(d.get("captive", false))
	# 建筑必须落在关卡声明的准确格位；机动单位/资源仍避开实心地形。
	var at := cell if is_bld else map.nearest_open(cell)
	var u := spawn_unit(key, faction, map.cell_to_world(at))
	if blocks:
		u.set_meta("fcell", at)
		u.set_meta("fhalf", building_footprint_half(key))
		register_building_footprint(u)
	return u


func register_building_footprint(bld: Unit) -> void:
	if bld == null or not is_instance_valid(bld) or not bld.is_building or bld.is_resource \
			or bld.is_captive or bool(bld.get_meta("footprint_blocked", false)):
		return
	var c: Vector2i = bld.get_meta("fcell", map.world_to_cell(bld.position))
	var half: int = int(bld.get_meta("fhalf", building_footprint_half(bld.key)))
	bld.set_meta("fcell", c)
	bld.set_meta("fhalf", half)
	map.block_footprint(c, half, true)
	bld.set_meta("footprint_blocked", true)


func unregister_building_footprint(bld: Unit) -> void:
	if bld == null or not is_instance_valid(bld) or not bool(bld.get_meta("footprint_blocked", false)):
		return
	map.block_footprint(bld.get_meta("fcell"), int(bld.get_meta("fhalf", 1)), false)
	bld.set_meta("footprint_blocked", false)


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
	var n := 0   # 朴素循环：不再每次 filter 新建数组+lambda（关卡条件/音乐每帧多次调用）
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building and u.hp > 0.0:
			n += 1
	return n


func enemies_alive() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_GUAN and not u.is_building and u.hp > 0.0:
			n += 1
	return n


func msg(text: String, dur := 3.5) -> void:
	hud.show_message(text, dur)


func set_top(text: String) -> void:
	hud.set_top(text)


func center_camera_cell(cell: Vector2i) -> void:
	camera.position = to_screen(map.cell_to_world(cell))


func _jump_alert_or_home() -> void:
	if _alert_t > 0.0:
		camera.position = to_screen(_alert_pos)
	else:
		center_camera_cell(level.camera_start_cell())


func _save_camera_loc(n: int) -> void:
	_camera_locs[n] = camera.position
	msg("已记录镜头位置 F%d" % n, 1.1)
	Sfx.play("click")


func _jump_camera_loc(n: int) -> void:
	if not _camera_locs.has(n):
		msg("F%d 尚未记录镜头位置" % n, 1.1)
		return
	camera.position = _camera_locs[n]
	Sfx.play("select")


func minimap_order(logic_pos: Vector2, amove: bool, queued := false) -> void:
	var p := to_screen(logic_pos)
	if amove:
		_order_amove_at(p, queued)
		_disarm_amove()
	else:
		_issue_order(p, queued)


func win(line: String) -> void:
	_end(true, line)


func lose(line: String) -> void:
	_end(false, line)


func spawn_projectile(from: Unit, target: Unit, dmg: float, crit := false, splash := 0.0, slow_mult := 1.0, slow_dur := 0.0) -> void:
	var p := Projectile.new()
	fx_root.add_child(p)
	p.position = from.position + Vector2(0, -4)
	p.splash = splash
	p.on_slow_mult = slow_mult
	p.on_slow_dur = slow_dur
	p.setup(from, target, dmg, crit)


## 李逵 E·蛮力：一次触发只建一个效果节点，内部为范围内每名敌军各维护一把追踪飞斧。
## 返回节点供自检直接推进；没有合法目标时返回 null。
func spawn_li_brawn_axes(caster: Unit, effect_radius: float, art := "axe"):
	if not is_instance_valid(caster) or caster.hp <= 0.0:
		return null
	var foe := Unit.FACTION_GUAN if caster.faction == Unit.FACTION_LIANG else Unit.FACTION_LIANG
	var hits: Array = []
	for u in units_near(caster.position, effect_radius + 32.0):
		if not (is_instance_valid(u) and u.faction == foe and u.hp > 0.0):
			continue
		if u.is_building or u.is_resource or u.garrisoned or u.is_captive:
			continue
		if caster.position.distance_to(u.position) > effect_radius:
			continue
		var hit_dmg := caster.secondary_basic_damage_against(u)
		if hit_dmg > 0.0:
			hits.append({"target": u, "dmg": hit_dmg})
	if hits.is_empty():
		return null
	var fx := LiBrawnAxesFx.new()
	fx.position = caster.position + Vector2(0, -8)
	fx.caster = caster
	fx.game = self
	fx.hits = hits
	fx.tex = Art.item_texture(art)
	if fx.tex == null:
		fx.tex = Art.dota_projectile_texture(art)
	fx_root.add_child(fx)
	Sfx.play("sk_axes", -8.0, 0.1, 55)
	return fx


## 近战命中火花（heavy=斧/重击更大）
func spawn_impact(lp: Vector2, heavy := false) -> void:
	if _lite_fx:
		var limit := LITE_IMPACT_BUDGET + (4 if heavy else 0)
		if _impact_fx_frame >= limit:
			return
		_impact_fx_frame += 1
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
	if _lite_fx:
		# 己方受创/暴击保留额外额度；普通 AoE 不再为数百个目标同时各建一个逐帧 Node2D。
		var limit := LITE_DAMAGE_BUDGET + (6 if crit or on_player else 0)
		if _damage_fx_frame >= limit:
			return
		_damage_fx_frame += 1
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


## 竞技场沙盒（资源近乎无限）→ 命令卡上隐藏金/木花费（信息噪声）。1v1/驻守/战役仍照常显示。
func train_cost_hidden() -> bool:
	return level != null and level.has_method("uses_dota_roster") and level.uses_dota_roster()


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
		if is_instance_valid(u) and u.is_resource and u.res_left > 0.0 and (kind == "" or u.res_kind == kind) \
				and not _resource_blocked(u):
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
		if not is_instance_valid(u) or not u.is_resource or u.res_kind != "gold" or u.res_left <= 0.0 \
				or _resource_blocked(u):
			continue
		if u == exclude or u.gold_busy(w):
			continue
		var d: float = p.distance_to(u.position)
		if d < bd:
			bd = d
			best = u
	return best


## 硬占位（星际/红警式）：实心格（建筑占地/实心地形）永不站人。判定直接问寻路网格——
## 与走路吃同一份真源，绝不会「格子明明能走却被弹开」。此前按 radius 猜占地会比真实封闭区
## 大一圈，把合法走廊上的工人反复弹出、与寻路拔河钉死（竞技场喽啰采矿卡住的元凶）。
## 只兜「传送类」落点：出生挤压、钩拽/闪现落点、AI 直点建筑中心。单位侧 10Hz 限流，O(1)。
func eject_from_buildings(u: Unit) -> void:
	var c := map.world_to_cell(u.position)
	if map.is_open_cell(c):
		return
	u.position = map.cell_to_world(map.nearest_open(c))


func _resource_blocked(node: Unit) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	var fr := int(Engine.get_physics_frames())
	if _res_block_frame != fr:
		_res_block_frame = fr
		_res_block_cache.clear()
	var nid := node.get_instance_id()
	if _res_block_cache.has(nid):
		return bool(_res_block_cache[nid])
	var blocked := _resource_blocked_calc(node)
	_res_block_cache[nid] = blocked
	return blocked


func _resource_blocked_calc(node: Unit) -> bool:
	var rc := map.world_to_cell(node.position)
	if not map.is_open_cell(rc):
		return true
	for u in units:
		if not (is_instance_valid(u) and u.is_building and not u.is_resource and u.hp > 0.0):
			continue
		var bc: Vector2i = u.get_meta("fcell", map.world_to_cell(u.position))
		var bh: int = int(u.get_meta("fhalf", GameMap.footprint_half_for(u.radius)))
		if rc.x >= bc.x - bh and rc.x <= bc.x + bh and rc.y >= bc.y - bh and rc.y <= bc.y + bh:
			return true
	return false


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


## 命令卡·建造菜单（分类）：cat="build"普通建筑 / "tower"防御塔。未标 build_cat 的默认归"build"。
func build_menu_cat(cat: String) -> Array:
	var out: Array = []
	for spec in build_menu():
		var d: Dictionary = _defs.get(String(spec["key"]), {})
		if String(d.get("build_cat", "build")) == cat:
			out.append(spec)
	return out


## 命令卡·陷阱菜单（喽啰 E）：从 Defs.TRAPS 派生，附当前是否买得起。
func trap_menu() -> Array:
	var out: Array = []
	for key in Defs.TRAPS:
		var d: Dictionary = Defs.TRAPS[key]
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


## 点击命中容差：镜头拉远后 ISO 世界里的固定像素在屏幕上按 zoom 等比缩小 → 容差按 zoom 反向放大
## （上限 4 倍），保证屏幕手感恒定——拉远后点小兵不再是像素级操作。拉近(zoom≥1)不额外缩小。
func _click_tol(base: float) -> float:
	if camera == null:
		return base
	return base / clampf(camera.zoom.x, 0.25, 1.0)


## 建筑「可点半径」：跟视觉贴图同宽（GameMap.building_visual_px 的一半），否则视觉放大后点不到边缘——
## 选取/驻军/修理全用它，让整个看得见的建筑都能点中。
func _bld_click_r(u: Unit) -> float:
	var vis := GameMap.building_visual_px(GameMap.footprint_half_for(u.radius))
	return maxf(u.radius + _click_tol(16.0), vis * 0.5)


## 该格放置的建筑是否会压到（或紧贴到）别的建筑：用占地 AABB 各向外扩 1 格判定，
## 确保两座建筑之间至少留一格缝、贴图屋檐不相叠（防止把箭塔造进聚义厅那种重叠）。
## 关卡预置与动态建筑都会登记 fcell/占地；这里仍保留 position+radius 兜底，兼容脚本直接 spawn_unit 的临时建筑。
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


func _resource_overlap(cell: Vector2i, half: int) -> bool:
	for u in units:
		if not (is_instance_valid(u) and u.is_resource and u.res_left > 0.0):
			continue
		var rc := map.world_to_cell(u.position)
		if rc.x >= cell.x - half and rc.x <= cell.x + half and rc.y >= cell.y - half and rc.y <= cell.y + half:
			return true
	return false


func arm_build(key: String) -> void:
	if not _defs.get(key, {}).get("buildable", false):
		return
	_disarm_ability()
	_disarm_amove()
	_disarm_patrol()
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
	if _resource_overlap(cell, half):
		msg("不能把建筑压在资源点上", 1.5)
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
	site._pending_build = true   # 先「虚影」：不挡路、不可被攻击；工人走到起第一锤才转实体、封路（见 advance_build）
	site.build_progress = 0.0
	site.hp = site.max_hp * 0.1
	site.set_meta("fcell", cell)
	site.set_meta("fhalf", half)
	var builders := selection.filter(func(u) -> bool:
		return is_instance_valid(u) and u.is_worker and u.hp > 0.0)
	_order_builders_to_site(builders, site, Input.is_key_pressed(KEY_SHIFT))
	msg("开始建造 %s" % String(_defs[key].get("name", key)), 1.5)


## Shift 连放语义：首座「立刻开工」（非排队，打断采集——采集是无限循环任务，排在它后面的建造令
## 永远轮不到，工地全成幽灵虚影；此时再手动催某座会先建那座、完了才轮旧单——正是用户反馈的
## 「顺序与 Shift 顺序不符 + 卡住」）。工人已在建造/队列里已有建造令时才排队跟进，保持逐座顺序。
func _order_builders_to_site(builders: Array, site: Unit, shift: bool) -> void:
	for wkr in builders:
		var busy_building: bool = wkr._state == Unit.ST_BUILD
		if not busy_building:
			for o in wkr._queue:
				if String(o.get("kind", "")) == "build":
					busy_building = true
					break
		wkr.order_build(site, shift and busy_building)


## AI 真实建造：在 cell 起一座 faction 阵营的工地（10% 血、占地封路），派 builder 工人去建。
## 与玩家 _start_construction 同机制（工人 advance_build → 完工 on_building_complete），只是阵营/工人由调用方指定。
func ai_start_construction(key: String, cell: Vector2i, faction: int, builder: Unit) -> Unit:
	var half := building_footprint_half(key)
	var site := spawn_unit(key, faction, map.cell_to_world(cell))
	site.is_constructing = true
	site._pending_build = true   # 同玩家：先虚影、工人到场起建才封路（见 advance_build）
	site.build_progress = 0.0
	site.hp = site.max_hp * 0.1
	site.set_meta("fcell", cell)
	site.set_meta("fhalf", half)
	if is_instance_valid(builder):
		builder.order_build(site)
	return site


# ---------- 喽啰命令卡·分类页（建筑 / 塔 / 陷阱 / 维修） ----------

## 进入某分类子页（建筑/塔/陷阱）：先撤一切待指向态，刷新命令卡。
func _open_worker_cat(cat: String) -> void:
	cancel_armed()
	_worker_cat = cat
	Sfx.play("click")
	if hud != null:
		hud.refresh_command()


## 退回命令卡根页（返回键 / 右键 / Esc）。
func _worker_back() -> void:
	if _worker_cat == "":
		return
	_worker_cat = ""
	if hud != null:
		hud.refresh_command()


## 喽啰 QWER：按当前分类页分派——根页开分类/维修；建筑/塔页放建筑；陷阱页布陷阱。
func _worker_hotkey(slot: int) -> void:
	match _worker_cat:
		"build", "tower":
			var menu := build_menu_cat(_worker_cat)
			if slot < menu.size():
				arm_build(String(menu[slot]["key"]))
			else:
				_worker_back()   # 返回键位
		"trap":
			var tm := trap_menu()
			if slot < tm.size():
				arm_trap(String(tm[slot]["key"]))
			else:
				_worker_back()
		_:
			match slot:
				0: _open_worker_cat("build")
				1: _open_worker_cat("tower")
				2: _open_worker_cat("trap")
				3: arm_repair()


# ---------- 陷阱（一次性地面机关） ----------

## 武装布置陷阱（喽啰 E 子菜单）：随后点地放置。触屏先把虚影摆到视图中心，拖动定位、松手落地。
func arm_trap(key: String) -> void:
	if not Defs.TRAPS.has(key):
		return
	_disarm_ability()
	_disarm_amove()
	_disarm_patrol()
	_cancel_build()
	_trap_armed = key
	if hud != null and hud.touch_ui:
		_drag_cur = camera.get_screen_center_position() if is_instance_valid(camera) else get_global_mouse_position()
		msg("拖动选址 → 松手布置（点「取消」放弃）", 2.0)
	Sfx.play("click")
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func _cancel_trap() -> void:
	_trap_armed = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 落点放置陷阱：校验地面可放 + 花费 → 登记一枚陷阱（短暂布防后生效）。
func _try_place_trap(p: Vector2) -> void:
	var key := _trap_armed
	var d: Dictionary = Defs.TRAPS.get(key, {})
	if d.is_empty():
		return
	var cell := map.world_to_cell(to_logic(p))
	if not map.area_buildable(cell, 0):
		msg("此处无法布置（地形不平或已被占用）", 1.5)
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
	_place_trap(key, map.cell_to_world(cell), Unit.FACTION_LIANG)
	if not Input.is_key_pressed(KEY_SHIFT):
		_cancel_trap()


## 登记一枚陷阱（玩家或全托管 AI 共用）：lp=逻辑落点，owner=布置方阵营（伤其敌）。
func _place_trap(key: String, lp: Vector2, owner: int) -> void:
	var d: Dictionary = Defs.TRAPS.get(key, {})
	if d.is_empty():
		return
	var fx := TrapMarkerFx.new()
	fx.position = lp
	fx.key = key
	fx.col = d.get("color", Color("ffaa44"))
	fx.rad = float(d.get("trigger_r", 65.0)) * 0.4
	fx_root.add_child(fx)
	_traps.append({
		"key": key, "pos": lp, "trigger_r": float(d.get("trigger_r", 65.0)),
		"arm_t": float(d.get("arm_t", 1.0)), "effect": d.get("effect", {}),
		"owner": owner, "fx": fx})


## 陷阱逐帧：布防计时 → 警戒圈内出现敌人即触发一次后销毁。
func _trap_pass(delta: float) -> void:
	if _traps.is_empty():
		return
	var triggered: Array = []
	for tr in _traps:
		if float(tr["arm_t"]) > 0.0:
			tr["arm_t"] = float(tr["arm_t"]) - delta
			if float(tr["arm_t"]) <= 0.0 and is_instance_valid(tr["fx"]):
				tr["fx"].armed = true   # 布防完成
			continue
		var owner: int = int(tr["owner"])
		var pos: Vector2 = tr["pos"]
		var rr: float = float(tr["trigger_r"])
		var victim: Unit = null
		for u in units:
			if not is_instance_valid(u) or u.faction == owner or u.hp <= 0.0 \
					or u.is_resource or u.is_building or u.garrisoned or u.is_captive:
				continue
			if pos.distance_to(u.position) <= rr:
				victim = u
				break
		if victim != null:
			_trigger_trap(tr, victim)
			triggered.append(tr)
	for tr in triggered:
		if is_instance_valid(tr["fx"]):
			tr["fx"].queue_free()
		_traps.erase(tr)


## 触发一枚陷阱：按 effect.kind 结算（aoe 范围伤 / stun 范围晕 / fire 地面长燃）。
func _trigger_trap(tr: Dictionary, victim: Unit) -> void:
	var owner: int = int(tr["owner"])
	var pos: Vector2 = tr["pos"]
	var eff: Dictionary = tr["effect"]
	var kind := String(eff.get("kind", "aoe"))
	var r := float(eff.get("radius", 90.0))
	match kind:
		"fire":
			_spawn_ground_fire(pos, r, float(eff.get("total", 150.0)), float(eff.get("dur", 6.0)), null, victim.faction)
		"stun":
			var sdmg := float(eff.get("dmg", 0.0))
			var sdur := float(eff.get("dur", 2.0))
			for u in units:
				if is_instance_valid(u) and u.faction != owner and u.hp > 0.0 and not u.is_resource \
						and not u.is_building and not u.garrisoned and pos.distance_to(u.position) <= r:
					u.apply_stun(sdur)
					if sdmg > 0.0:
						u.take_damage(sdmg, null)
			spawn_impact(pos, true)
			shake(4.0, pos)
		_:   # aoe
			var dmg := float(eff.get("dmg", 120.0))
			for u in units:
				if is_instance_valid(u) and u.faction != owner and u.hp > 0.0 and not u.is_resource \
						and not u.is_building and not u.garrisoned and pos.distance_to(u.position) <= r:
					u.take_damage(dmg, null)
			spawn_impact(pos, true)
			shake(5.0, pos)
	Sfx.play("sk_smite")


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
	var workers: Array = []
	var heroes: Array = []
	for key in bld.setup_def.get("produces", []):
		if int(_defs.get(key, {}).get("min_age", 1)) > current_age:
			continue   # 时代未到 → 不出
		var d: Dictionary = _defs.get(key, {})
		var cg := int(d.get("cost_gold", 0))
		var cw := int(d.get("cost_wood", 0))
		if bool(d.get("hero_trainable", false)):
			# 已在阵中(现役/在产)不显示；战死(hero_progress)显示「复活」
			if count_alive(Unit.FACTION_LIANG, key) > 0 or _eco_in_queue(key):
				continue
			var lbl := String(d.get("name", key))
			var is_revive := false
			if hero_progress.has(key):
				is_revive = true
				lbl = "复活·%s Lv%d" % [lbl, int(hero_progress[key].get("level", 1))]
			heroes.append({"kind": "train", "key": key, "label": lbl,
				"cost_g": cg, "cost_w": cw, "affordable": can_afford(cg, cw), "bld": bld, "revive": is_revive,
				"_star": int((Bios.STAR.get(key, [999]) as Array)[0])})
		else:
			workers.append({"kind": "train", "key": key, "label": String(d.get("name", key)),
				"cost_g": cg, "cost_w": cw, "affordable": can_afford(cg, cw), "bld": bld, "revive": false})
	# 竞技场沙盒：把全部 108 将(DOTA 改版 kit)动态列入点将菜单；并加「刷敌」键。
	# 1v1/驻守战 level.uses_dota_roster()==false → 不进此分支 → 仍只有原 6 个可训练英雄(原样不变)。
	if level != null and level.has_method("uses_dota_roster") and level.uses_dota_roster():
		var seen := {}
		for h in heroes:
			seen[String(h["key"])] = true
		for key in Defs.UNITS:
			var d2: Dictionary = Defs.UNITS[key]
			if not bool(d2.get("hero_trainable", false)) or seen.has(key):
				continue
			if count_alive(Unit.FACTION_LIANG, key) > 0 or _eco_in_queue(key):
				continue
			var c2g := int(d2.get("cost_gold", 0))
			var c2w := int(d2.get("cost_wood", 0))
			heroes.append({"kind": "train", "key": key, "label": String(d2.get("name", key)),
				"cost_g": c2g, "cost_w": c2w, "affordable": can_afford(c2g, c2w), "bld": bld, "revive": false,
				"_star": int((Bios.STAR.get(key, [999]) as Array)[0])})
	heroes.sort_custom(func(a, b): return int(a["_star"]) < int(b["_star"]))   # 天罡在前、地煞在后
	var out: Array = workers.duplicate()
	var PAGE := 6
	if heroes.size() <= PAGE + 1:
		out.append_array(heroes)
		return out
	# 竞技场 108 将太多 → 分类二级菜单（天罡/地煞上/地煞下）：根页选类、类内再分页（复用编辑器 7ac8ab5 思路）
	if level != null and level.has_method("uses_dota_roster") and level.uses_dota_roster():
		return _hall_cat_menu(bld, out, heroes)
	# 非竞技场（保留原扁平分页，虽当前 heroes≤6 走不到这里）
	var pages := int(ceil(float(heroes.size()) / float(PAGE)))
	_hall_page = clampi(_hall_page, 0, pages - 1)
	var start := _hall_page * PAGE
	out.append_array(heroes.slice(start, mini(start + PAGE, heroes.size())))
	out.append({"kind": "train_page", "dir": -1, "label": "◀上页",
		"cost_g": 0, "cost_w": 0, "affordable": true, "bld": bld})
	out.append({"kind": "train_page", "dir": 1, "label": "%d/%d页▶" % [_hall_page + 1, pages],
		"cost_g": 0, "cost_w": 0, "affordable": true, "bld": bld})
	return out


const HALL_CATS := [
	{"key": "tiangang", "label": "天罡星", "lo": 1, "hi": 36, "glyph": "罡"},
	{"key": "disha_a", "label": "地煞·上", "lo": 37, "hi": 72, "glyph": "煞"},
	{"key": "disha_b", "label": "地煞·下", "lo": 73, "hi": 108, "glyph": "煞"},
]


## 竞技场点将二级菜单：分类根页（三类入口，标各类可点将数）/ 分类页（该类英雄，类内 6/页分页 + 返回）。
func _hall_cat_menu(bld: Unit, out: Array, heroes: Array) -> Array:
	if _hall_cat == "":
		for c in HALL_CATS:
			var n := 0
			for h in heroes:
				if int(h["_star"]) >= int(c["lo"]) and int(h["_star"]) <= int(c["hi"]):
					n += 1
			out.append({"kind": "hall_cat", "cat": String(c["key"]), "glyph": String(c["glyph"]),
				"label": "%s（%d）" % [String(c["label"]), n], "info": "▸ 展开",
				"cost_g": 0, "cost_w": 0, "affordable": true, "bld": bld})
		return out
	var lo := 1
	var hi := 108
	for c in HALL_CATS:
		if String(c["key"]) == _hall_cat:
			lo = int(c["lo"]); hi = int(c["hi"])
	var sub: Array = []
	for h in heroes:
		if int(h["_star"]) >= lo and int(h["_star"]) <= hi:
			sub.append(h)
	out.append({"kind": "hall_cat", "cat": "", "glyph": "返", "label": "◂ 返回分类", "info": "◂ 返回",
		"cost_g": 0, "cost_w": 0, "affordable": true, "bld": bld})
	var PAGE := 6
	if sub.size() <= PAGE:
		out.append_array(sub)
		return out
	var pages := int(ceil(float(sub.size()) / float(PAGE)))
	_hall_page = clampi(_hall_page, 0, pages - 1)
	var start := _hall_page * PAGE
	out.append_array(sub.slice(start, mini(start + PAGE, sub.size())))
	out.append({"kind": "train_page", "dir": -1, "label": "◀上页",
		"cost_g": 0, "cost_w": 0, "affordable": true, "bld": bld})
	out.append({"kind": "train_page", "dir": 1, "label": "%d/%d页▶" % [_hall_page + 1, pages],
		"cost_g": 0, "cost_w": 0, "affordable": true, "bld": bld})
	return out


## 竞技场点将：进入某分类（cat=""回到分类根页），归零页码并刷新命令卡。
func hall_set_cat(cat: String) -> void:
	_hall_cat = cat
	_hall_page = 0
	Sfx.play("click")
	if hud != null:
		hud.refresh_command()


## 竞技场「出兵 / 随机」：交给关卡(arena.gd)刷 50 兵 + 1 名随机敌将试招（主界面两枚按钮触发）。
func arena_spawn_troops() -> void:
	if level != null and level.has_method("arena_spawn_troops"):
		level.arena_spawn_troops(self)


func arena_spawn_random() -> void:
	if level != null and level.has_method("arena_spawn_random"):
		level.arena_spawn_random(self)


## 聚义厅「点将」翻页（108 将太多 → 分页浏览；越界由 train_menu 钳制）。
func hall_page_turn(dir: int) -> void:
	_hall_page += dir
	Sfx.play("click")
	if hud != null:
		hud.refresh_command()


## 队列中尚未生成的单位人口之和
func _queued_pop() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG:
			for k in u._train_queue:
				n += int(_defs.get(k, {}).get("pop", 1))
	return n


## 训练/研究共用建筑的唯一训练校验入口。返回空串=可下单；非空为稳定原因码。
## 玩家与托管都走这一套，避免自动预检和实际下单条件漂移。
func _train_block_reason(bld: Unit, key: String) -> String:
	if bld == null or not is_instance_valid(bld):
		return "invalid"
	if bld.is_constructing:
		return "constructing"
	if bld._research_key != "":
		return "researching"
	var d: Dictionary = _defs.get(key, {})
	if d.is_empty() or key not in bld.setup_def.get("produces", []):
		return "unsupported"
	if int(d.get("min_age", 1)) > current_age:
		return "age"
	if bool(d.get("hero_trainable", false)):   # 英雄每种限一员
		var have := count_alive(Unit.FACTION_LIANG, key)
		for u in units:
			if is_instance_valid(u) and u.is_building:
				have += u._train_queue.count(key)
		if have >= 1:
			return "hero_exists"
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
				return "hero_cap"
	if used_pop() + _queued_pop() + int(d.get("pop", 1)) > pop_cap:
		return "population"
	if not can_afford(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))):
		return "resources"
	if bld._train_queue.size() >= 8:
		return "queue_full"
	return ""


func _show_train_block(reason: String, key: String) -> void:
	var d: Dictionary = _defs.get(key, {})
	match reason:
		"researching": msg("该建筑正在研究科技，暂时不能训练", 1.4)
		"hero_exists": msg("%s 已在阵中" % String(d.get("name", key)), 1.5)
		"hero_cap":
			var hcap := int(level.hero_cap()) if (level != null and level.has_method("hero_cap")) else 0
			msg("聚义厅英雄已满（上限 %d 员，可在编辑器调整）" % hcap, 1.8)
		"population": msg("人口已满（造民居可加人口）", 1.5)
		"resources": msg("资源不足：需 金%d 木%d" % [int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))], 1.5)
		"queue_full": msg("生产队列已满", 1.2)
		"age": msg("当前时代尚不能训练该单位", 1.4)
		"unsupported": msg("该建筑不能训练此单位", 1.4)
		_: return
	Sfx.play("cant")


## feedback=false 供全托管使用：预期的等待不弹玩家提示、不播放失败/点击音效。
func queue_train(bld: Unit, key: String, feedback := true) -> bool:
	var reason := _train_block_reason(bld, key)
	if reason != "":
		if feedback:
			_show_train_block(reason, key)
		return false
	var d: Dictionary = _defs.get(key, {})
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if not spend(cg, cw):
		return false
	if feedback:
		Sfx.play("click")
	bld._train_queue.append(key)
	if bld._train_queue.size() == 1:
		bld._train_t = train_time_for(key)
	return true


## 训练耗时（按模式）：竞技场沙盒即时成军；全托管(AI友好)下英雄训练提速，避免逐个练 3 分钟、
## 左侧英雄栏长期空着（仅托管生效，手动/战役/1v1 不受影响，balance 不动）。其余一律原 train_time。
func train_time_for(key: String) -> float:
	if level != null and level.has_method("arena_instant_train") and level.arena_instant_train():
		return 0.6
	var base := float(_defs.get(key, {}).get("train_time", 12.0))
	if _full_auto() and bool(_defs.get(key, {}).get("hero", false)):
		return maxf(6.0, base * ECO_HERO_TRAIN_MULT)
	return base


## 多生产建筑同选：从同类建筑里挑最短队列下单，形成 SC2 式宏操作；单建筑退回原逻辑。
func queue_train_multi(bld: Unit, key: String) -> void:
	var pool := _selected_producers_for(bld, key)
	if pool.size() <= 1:
		queue_train(bld, key)
		return
	pool.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a._train_queue.size() == b._train_queue.size():
			return a.get_instance_id() < b.get_instance_id()
		return a._train_queue.size() < b._train_queue.size())
	queue_train(pool[0], key)


func _selected_producers_for(bld: Unit, key: String) -> Array:
	if bld == null or not is_instance_valid(bld):
		return []
	var out: Array = []
	for u in selection:
		if not (is_instance_valid(u) and u.is_building and not u.is_constructing and u._research_key == "" \
				and u.faction == bld.faction and u.key == bld.key):
			continue
		if key in u.setup_def.get("produces", []):
			out.append(u)
	return out


## 取消生产队列里第 index 个（经典RTS式：点队列图标即撤单），全额退还资源；撤的是队首则重置计时。
func cancel_train(bld: Unit, index: int) -> void:
	if bld == null or not is_instance_valid(bld) or index < 0 or index >= bld._train_queue.size():
		return
	var key: String = bld._train_queue[index]
	var d: Dictionary = _defs.get(key, {})
	add_resources(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0)))   # 退还花费
	bld._train_queue.remove_at(index)
	if index == 0 and not bld._train_queue.is_empty():   # 撤的是正在训练的 → 计时重置到新队首
		bld._train_t = train_time_for(bld._train_queue[0])
	Sfx.play("order")
	msg("已取消生产 %s（资源已退还）" % String(d.get("name", key)), 1.2)
	if hud != null:
		hud.refresh_command()


## 命令卡·科技菜单：该建筑可研究、且尚未完成/进行中的科技
func research_menu(bld: Unit) -> Array:
	var out: Array = []
	if level != null and level.has_method("arena_spawn_troops"):
		return out   # 竞技场沙盒：移除聚义厅的升级/科技(时代进阶/锻造/甲胄/精耕)选项
	for key in bld.setup_def.get("researches", []):
		if _tech_done.has(key) or _tech_in_progress(key):
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


## 同一科技是全局状态：任意建筑研究中，都不能在另一座建筑重复扣费研究。
func _tech_in_progress(key: String) -> bool:
	for u in units:
		if is_instance_valid(u) and u.is_building and u.hp > 0.0 and u._research_key == key:
			return true
	return false


func _research_block_reason(bld: Unit, key: String) -> String:
	if bld == null or not is_instance_valid(bld):
		return "invalid"
	if bld.is_constructing:
		return "constructing"
	if bld._research_key != "":
		return "researching"
	var d: Dictionary = Defs.TECHS.get(key, {})
	if d.is_empty() or key not in bld.setup_def.get("researches", []):
		return "unsupported"
	if int(d.get("min_age", 1)) > current_age:
		return "age"
	if not bld._train_queue.is_empty():
		return "production"
	if _tech_done.has(key):
		return "done"
	if _tech_in_progress(key):
		return "in_progress"
	if not can_afford(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))):
		return "resources"
	return ""


func _show_research_block(reason: String, key: String) -> void:
	var d: Dictionary = Defs.TECHS.get(key, {})
	match reason:
		"production": msg("请先完成或取消生产队列，再开始研究", 1.5)
		"researching": msg("该建筑已有科技正在研究", 1.4)
		"in_progress": msg("该科技已在另一座建筑研究中", 1.4)
		"resources": msg("资源不足：需 金%d 木%d" % [int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))], 1.5)
		"age": msg("当前时代尚不能研究该科技", 1.4)
		"unsupported": msg("该建筑不能研究此科技", 1.4)
		_: return
	Sfx.play("cant")


func queue_research(bld: Unit, key: String, feedback := true) -> bool:
	var reason := _research_block_reason(bld, key)
	if reason != "":
		if feedback:
			_show_research_block(reason, key)
		return false
	var d: Dictionary = Defs.TECHS.get(key, {})
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if not spend(cg, cw):
		return false
	if feedback:
		Sfx.play("click")
	bld._research_key = key
	bld._research_t = float(d.get("time", 25.0))
	if hud != null:
		hud.refresh_command()
	return true


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
	if eff.has("advance_age"):   # 仅聚义厅·时代科技加成英雄：英雄攻/血各按该科技倍率(+10% 左右)
		hero_tech_atk *= float(eff.get("atk_mult", 1.0))
		hero_tech_hp *= hp_m
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
		unregister_building_footprint(u)   # 摧毁后放开占地（地面恢复可通行）
		if not u.is_constructing and u.faction == Unit.FACTION_LIANG:   # 只扣玩家人口上限
			var pp := int(u.setup_def.get("provides_pop", 0))
			if pp > 0:
				pop_cap = maxi(0, pop_cap - pp)
		# 非资源建筑：坍塌演出 + 释放节点——不留黑废墟，尘埃散尽地面如初（星际/红警式）
		if not u.is_resource:
			var cfx := BuildingCollapseFx.new()
			cfx.position = u.position
			cfx.tex = Art.building_texture(u.key)
			if cfx.tex == null:
				cfx.tex = Art.terrain_texture(u.key)
			cfx.s = GameMap.building_visual_px(GameMap.footprint_half_for(u.radius))
			fx_root.add_child(cfx)
			Sfx.play("atk_catapult", -2.0, 0.10, 150)   # 坍塌闷响
			u.queue_free()
	_update_sel_label()
	var mark := FadingMark.new()
	mark.position = u.position
	fx_root.add_child(mark)
	if u.faction == Unit.FACTION_GUAN and not u.is_building:
		kills += 1
		# 按英雄统计歼敌：把这一杀记到「最后一击」的梁山英雄名下。
		# 用英雄 key 作键（而非 instance_id）→ 英雄阵亡后在聚义厅复活(新实例)仍并入同一条战功，不另起一行。
		var k: Unit = u._killer
		if track_hero_combat_stats:
			var stat_key := _hero_stat_attacker_key(k)
			if stat_key != "":
				var stat_name := k.display_name if k != null and is_instance_valid(k) and k.is_hero \
						else String(_defs.get(stat_key, {}).get("name", stat_key))
				var combat_rec := _ensure_hero_combat_stat(stat_key, stat_name)
				combat_rec["kills"] = int(combat_rec["kills"]) + 1
				hero_combat_stats[stat_key] = combat_rec
		if k != null and is_instance_valid(k) and k.is_hero and k.faction == Unit.FACTION_LIANG:
			var rec: Dictionary = hero_kills.get(k.key, {"name": k.display_name, "key": k.key, "n": 0})
			rec["n"] = int(rec["n"]) + 1
			hero_kills[k.key] = rec
		if economy:   # 自由模式：击杀经验 + 击杀赏金
			# 赏金：官军阵亡给一小笔金（血量 5%，敌将×2）。守住本身产生收益——
			# 单金矿 6000 采干后金收入不再断崖（塔/陷阱/英雄杀敌一律计入，不看最后一击是谁）。
			var bounty := maxi(1, int(round(u.max_hp * 0.05 * (2.0 if u.is_hero else 1.0))))
			if _song_jiang_alive():
				bounty = maxi(bounty + 1, int(round(bounty * 1.25)))   # 及时雨·仗义疏财：宋江在场赏金 +25%
			add_resources(bounty, 0)
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
	elif economy and u.faction == Unit.FACTION_LIANG and not u.is_building and not u.is_resource:
		# 对称赏金/经验：1v1 里 AI 官军杀梁山单位 → 金入其私池、经验给其英雄（与玩家同公式）。
		# 仅限有私池的对局（1v1）；驻守战官军无经济不受影响。配合敌将 1 级出场+自动加点 → 双方英雄成长对等。
		if faction_res.has(Unit.FACTION_GUAN):
			add_resources(maxi(1, int(round(u.max_hp * 0.05 * (2.0 if u.is_hero else 1.0)))), 0, Unit.FACTION_GUAN)
			var xpg: float = float(u.setup_def.get("xp", 0.0))
			if xpg <= 0.0:
				xpg = u.max_hp * 0.4 + 20.0
			var kg: Unit = u._killer
			var xkg_id := 0
			if kg != null and is_instance_valid(kg) and kg.is_hero and kg.faction == Unit.FACTION_GUAN and kg.hp > 0.0:
				kg.gain_xp(xpg)
				xkg_id = kg.get_instance_id()
			for h in units:
				if is_instance_valid(h) and h.is_hero and h.faction == Unit.FACTION_GUAN and h.hp > 0.0 \
						and h.get_instance_id() != xkg_id \
						and h.position.distance_to(u.position) < 300.0:
					h.gain_xp(xpg)
	if phase == Phase.FIGHT:
		level.on_unit_died(self, u)


## 及时雨·仗义疏财：宋江在场（存活、未驻军隐身也算在场）→ 全军击杀赏金 +25%。
## 大哥仗义疏财，兄弟们跟着沾光——给「练出宋江并保住他」一个经济意义上的优待。
func _song_jiang_alive() -> bool:
	for v in units:
		if is_instance_valid(v) and v.key == "song_jiang" and v.faction == Unit.FACTION_LIANG and v.hp > 0.0:
			return true
	return false


## ---------- 性能压测 / profiler（PERF_BENCH=N：造 N/side 混战，逐帧累计各系统微秒）----------
func _pf(label: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	_prof[label] = int(_prof.get(label, 0)) + (now - t0)
	return now


func _prof_tick(delta: float) -> void:
	_prof_print_acc += delta
	if _prof_print_acc >= 1.0:
		_prof_print_acc = 0.0
		_prof_dump()


func _prof_dump() -> void:
	var f := float(maxi(1, _prof_frames))
	var ne := 0   # 敌(官军)机动数
	var na := 0   # 我方机动数
	for u in units:
		if is_instance_valid(u) and not u.is_building and not u.is_resource and u.hp > 0.0:
			if u.faction == Unit.FACTION_GUAN:
				ne += 1
			elif u.faction == Unit.FACTION_LIANG:
				na += 1
	var keys := _prof.keys()
	keys.sort()
	var parts := PackedStringArray()
	var work := float(_unit_proc_us) / f
	for k in keys:
		work += float(_prof[k]) / f
		parts.append("%s=%.0f" % [k, float(_prof[k]) / f])
	parts.append("units=%.0f" % (float(_unit_proc_us) / f))
	print("[prof] fps=%.1f n=%d(e%d a%d) work=%.0fus/f(%.1fms) | %s" % [
		Engine.get_frames_per_second(), ne + na, ne, na, work, work / 1000.0, " ".join(parts)])
	_prof.clear()
	_prof_frames = 0
	_unit_proc_us = 0


## 防御压测：n 个官军压向基地侧 vs 我方 6 英雄(开技能·自动放招) → 打开 profiler。贴近 60关5x 实战峰值。
func _perf_bench_setup(n: int) -> void:
	Engine.time_scale = 1.0
	ai_friendly = true
	Settings.auto_micro_level = 3   # 6 英雄自动放招(光环/AoE)，贴近全托管实战
	phase = Phase.DEPLOY
	_on_start_battle()
	for u in units.duplicate():
		if is_instance_valid(u) and not u.is_building and not u.is_resource:
			units.erase(u); u.queue_free()
	var c := map.cell_to_world(level.camera_start_cell())
	var heroes := ["song_jiang", "hua_rong", "lin_chong", "gongsun_sheng", "li_kui", "wu_song"]
	for hi in heroes.size():
		var h := spawn_unit(heroes[hi], Unit.FACTION_LIANG, c + Vector2(-140, -100 + hi * 30))
		for s in h.ability_slots:
			s["rank"] = 2; s["cd_t"] = 0.0
		h._recompute_hero_stats()
		h.auto_micro = true
	var ek := ["guan_dao", "guan_dao", "guan_gong"]
	for i in range(n):
		var off := Vector2(float(i % 16) * 20.0, float(i / 16) * 20.0)
		var e := spawn_unit(ek[i % 3], Unit.FACTION_GUAN, c + Vector2(340, -160) + off)
		e.order_amove(c + Vector2(-140, 0))
	_prof_on = true
	print("[prof] bench(def): %d 敌 vs 6 英雄" % n)


func _physics_process(delta: float) -> void:
	if phase == Phase.INTRO:
		return
	var _t := Time.get_ticks_usec() if _prof_on else 0
	if _prof_on: _prof_frames += 1
	_grid_build()
	if _prof_on: _t = _pf("grid", _t)
	_hero_boost_refresh()
	_aura_pass()
	if _prof_on: _t = _pf("aura", _t)
	# 潜行/敌将放招这些「决策」不必每帧跑：限流到 ~7~10Hz，兵海后期省下大把 O(N) 扫描
	_stealth_acc += delta
	if _stealth_acc >= 0.15:
		_stealth_acc = 0.0
		_stealth_pass()
	_ecast_acc += delta
	if _ecast_acc >= 0.1:
		_ecast_acc = 0.0
		_enemy_ability_pass()
	if _prof_on: _t = _pf("stealth_ecast", _t)
	_auto_micro_pass()
	if _prof_on: _t = _pf("automicro", _t)
	_summon_hunt_pass()
	if ai_friendly and int(Settings.auto_micro_level) >= 3:
		_auto_economy_pass(delta)   # 全托管(仅AI友好模式)：喽啰自动经营 + 自动开战（DEPLOY/FIGHT 均跑）
	if _prof_on: _t = _pf("summon_eco", _t)
	_separation_pass(delta)   # 每帧全速跑：分离是软约束，隔帧跑会在密集堆里抖动(画面/手感优先)
	if _prof_on: _t = _pf("separation", _t)
	_decay_lit(delta)
	if fog:
		_fog_pass(delta)
	if _prof_on: _t = _pf("fog", _t)

	if phase != Phase.FIGHT:
		if _prof_on: _prof_tick(delta)
		return

	_ground_dot_pass(delta)
	_hua_snipe_dot_pass(delta)
	_zone_pass(delta)
	_trap_pass(delta)
	_ice_wall_pass(delta)
	_ward_pass(delta)
	_trail_pass(delta)
	_bolt_pass(delta)
	_walk_cast_pass(delta)
	_channel_pass(delta)
	_tick_pending_casts()
	if _prof_on: _t = _pf("zones", _t)
	level.process(self, delta)
	if phase == Phase.FIGHT:
		hud.set_top(level.top_status(self))
	if _prof_on:
		_t = _pf("level_hud", _t)
		_prof_tick(delta)

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


## 全托管 = AI友好模式 + 英雄托管档「全托管(3)」。统一闸门，避免散落的内联判断不一致。
func _full_auto() -> bool:
	return ai_friendly and int(Settings.auto_micro_level) >= 3


## 全托管驻守战末波扫尾（由关卡在“残敌长期不减”后低频调用）。
## 侦察只照亮残敌周围；空闲托管部队前去清剿；只有确认断路或持续卡死的敌人才重置回原进攻路线。
## 返回统计供专项自检使用。
func final_wave_cleanup() -> Dictionary:
	var result := {"enemies": 0, "revealed": 0, "relocated": 0, "hunters": 0}
	if not _full_auto():
		return result
	var hall := main_base(Unit.FACTION_LIANG)
	if hall == null or not is_instance_valid(hall):
		return result
	var residuals: Array = []
	for e in units:
		if is_instance_valid(e) and e.faction == Unit.FACTION_GUAN and e.hp > 0.0 \
				and not e.is_building and not e.is_resource and not e.garrisoned and not e.is_captive:
			residuals.append(e)
	result["enemies"] = residuals.size()
	if residuals.is_empty():
		return result
	var lanes := _eco_lanes()
	for e: Unit in residuals:
		# 地面和敌军共用同一份临时视野，避免出现“亮地上凭空冒兵”。下一次迷雾刷新会同时生效。
		_reveal_fog_at(e.position, maxf(96.0, e.radius + 64.0), 3.5)
		result["revealed"] = int(result["revealed"]) + 1
		var last_pos: Vector2 = e.get_meta("final_cleanup_pos", e.position)
		var stalled := int(e.get_meta("final_cleanup_stall", 0))
		if e.position.distance_to(last_pos) < 10.0 and not e.has_target():
			stalled += 1
		else:
			stalled = 0
		e.set_meta("final_cleanup_pos", e.position)
		e.set_meta("final_cleanup_stall", stalled)
		var far_from_hall := e.position.distance_to(hall.position) > 70.0
		# 正常行军单位不重复跑 A*；只检查已经待机、路径为空，或连续三拍（约 6 秒）没有移动的残敌。
		var needs_route_check := not e.has_target() and (e._state == Unit.ST_IDLE \
				or (e._state == Unit.ST_AMOVE and e._path.is_empty()) or stalled >= 3)
		var no_route := false
		if far_from_hall and needs_route_check:
			no_route = map.find_path(e.position, hall.position, e.faction).is_empty()
		if far_from_hall and needs_route_check and (no_route or stalled >= 3) and not lanes.is_empty():
			# 按残敌当前最近的进攻路线回填；instance_id 给少量散开，避免全部叠在同一格。
			var li := _eco_nearest_lane(e.position, lanes)
			var eid := e.get_instance_id()
			var spread := Vector2i((eid % 5) - 2, (floori(float(eid) / 5.0) % 5) - 2)
			var rc := map.nearest_open(map.world_to_cell(lanes[li]) + spread)
			e.position = map.cell_to_world(rc)
			e._target = null
			e._path = PackedVector2Array()
			e.set_meta("final_cleanup_pos", e.position)
			e.set_meta("final_cleanup_stall", 0)
			e.order_amove(hall.position)
			_reveal_fog_at(e.position, maxf(96.0, e.radius + 64.0), 3.5)
			result["relocated"] = int(result["relocated"]) + 1
		elif needs_route_check:
			# 可达但因拥挤/旧命令停住：低频补一条进攻令，单位自身有限重寻负责兜底。
			e.order_amove(hall.position)
	# 不足十人的残存守军原本会一直留在集结点；扫尾期让所有空闲托管战斗单位就近搜索残敌。
	for s in units:
		if not (is_instance_valid(s) and s.faction == Unit.FACTION_LIANG and s.hp > 0.0 \
				and not s.is_worker and not s.is_building and not s.is_summon and not s.garrisoned):
			continue
		if s.manual_order_active or s.manual_order_t > 0.0 or s.has_target() or s._state == Unit.ST_CHASE:
			continue
		if s.is_hero and not s.auto_micro:
			continue
		var nearest: Unit = residuals[0]
		var best_d: float = s.position.distance_squared_to(nearest.position)
		for ri in range(1, residuals.size()):
			var d: float = s.position.distance_squared_to(residuals[ri].position)
			if d < best_d:
				best_d = d
				nearest = residuals[ri]
		# 已经朝该片残敌 A 移就不重复下令，避免每两秒清空路径。
		if s._state != Unit.ST_AMOVE or s._amove_dest.distance_to(nearest.position) > 100.0:
			s.order_amove(nearest.position)
			result["hunters"] = int(result["hunters"]) + 1
	return result


## ───────────────── 全托管·经济 AI（喽啰自动经营，auto_micro_level>=3）─────────────────
## 每 ~0.5s 一拍：喽啰采集/建造/修复 → 推进建造计划 → 练农民/兵/将 → 研究科技 → 把成军拉去前线。
## 仅在「开战(FIGHT)」后才动——全托管也要玩家点一次「开战」(不再自动开战)。
func _auto_economy_pass(delta: float) -> void:
	if not economy or level == null or phase != Phase.FIGHT:
		return
	_eco_t -= delta
	if _eco_t > 0.0:
		return
	_eco_t = 0.5
	# 先规划研究，再让建造/训练消费资源。研究目标建筑会停止续排，最高优先科技保留一份预算。
	var research_plans := _eco_research_plans()
	var tech_reserve := _eco_research_reserve(research_plans)
	_eco_update_wood_stall()
	_eco_workers()
	_eco_build(tech_reserve)
	_eco_train(research_plans, tech_reserve)
	_eco_research(research_plans)
	# 研究可能已在本拍启动并扣费；重新计算剩余计划，避免继续为已启动项目重复留预算。
	var remaining_plans := _eco_research_plans()
	var remaining_reserve := _eco_research_reserve(remaining_plans)
	_eco_trade(remaining_reserve)
	_eco_traps(remaining_reserve)
	_eco_muster_and_charge()


## 全托管：把所有「非喽啰非英雄」的成军(闲置、未交战、离前线尚远)攻击移动到防御前线集结，参战。
## 已在交战/已在前线附近/身边有敌(自行索敌中) → 不打扰，免得反复改令抖动。
## 全托管·成军集结后整队出击：兵营集结点设到「基地外面一点」的集结点 → 新兵直接走出去、不在寨门口堆住；
## 闲散的成军回集结；攒够 ECO_CHARGE_SIZE 个就整队 A 移冲向最密敌群。彻底解决兵/虎卡在基地周围。
const ECO_CHARGE_SIZE := 10
func _eco_muster_and_charge() -> void:
	var muster := _eco_muster_point()
	# 兵营集结点 → 集结点（新兵 on_unit_trained 走 has_rally 分支，直接奔集结点，不堆寨门）
	for u in units:
		if is_instance_valid(u) and u.key == "barracks" and u.faction == Unit.FACTION_LIANG \
				and not u.is_constructing and u.hp > 0.0:
			if not u.has_rally or u.rally.distance_to(muster) > 80.0:
				u.has_rally = true
				u.rally = muster
				u.rally_kind = ""
				u.rally_node = null
	# 收集闲散成军：交战中/身边有敌的不动；离集结远的回集结；到了集结的列入待命队
	var mustered: Array = []
	for u in units:
		if not (is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and not u.is_worker and not u.is_hero and not u.is_building and not u.is_summon and not u.garrisoned):
			continue
		if u.has_target() or u._state == Unit.ST_CHASE:
			continue
		if _foe_within(u.position, u.aggro_range, u.faction):
			continue   # 身边有敌 → 自行索敌，不硬拉
		if u.position.distance_to(muster) > 150.0:
			if u._state != Unit.ST_AMOVE and u._state != Unit.ST_MOVE:
				u.order_move(muster)   # 散在外面的回集结点（不 A 移，免得半路被零散勾走）
		else:
			mustered.append(u)
	# 攒够一队 → 整队冲向最密敌群（没敌人就压到前线待命）
	if mustered.size() >= ECO_CHARGE_SIZE:
		var tgt := _densest_foe_pos(Unit.FACTION_LIANG, 120.0)
		if tgt == Vector2.INF:
			tgt = _nearest_foe_pos(muster, Unit.FACTION_LIANG)
		if tgt == Vector2.INF:
			tgt = _eco_frontline()
		for s in mustered:
			s.order_amove(tgt)


## 集结点：前沿建筑外再朝敌方推一点（够 10 兵就从这儿冲出去）。
func _eco_muster_point() -> Vector2:
	var f := _eco_frontline()
	var foe := _nearest_foe_pos(f, Unit.FACTION_LIANG)
	if foe != Vector2.INF:
		return f + (foe - f).normalized() * minf(f.distance_to(foe) * 0.5, 160.0)
	return f


## 喽啰：闲置→补在建工地/采集（金矿工不足补金、否则伐木）；另抽工修受损建筑。
## 木头吃紧：库存低于「金的一半」(ECO_WOOD_RATIO) 或绝对地板。塔/民居/仓库/集市很费木(多为纯木)，木常成瓶颈。
func _eco_wood_short() -> bool:
	return float(wood) < float(gold) * ECO_WOOD_RATIO or wood < ECO_WOOD_FLOOR


## 金矿工目标：平时 5(其余伐木)；木紧时降到 4，把多产的农民全推去伐木（四到五个金矿工）。
func _eco_gold_target() -> int:
	return (ECO_GOLD_MINERS - 1) if _eco_wood_short() else ECO_GOLD_MINERS


## 农民上限：平时 6；木紧时拉到 10——英雄之后、军队之前主动补喽啰专去伐木（修「木荒却不产农民」）。
func _eco_wcap_dyn() -> int:
	return ECO_WCAP_WOOD if _eco_wood_short() else ECO_WCAP


## 采集参照点：主基地(聚义厅)位置——按「离基地最近」挑资源点，避免工人跑远。
func _eco_base_pos() -> Vector2:
	var hall := main_base(Unit.FACTION_LIANG)
	return hall.position if hall != null else map.cell_to_world(level.camera_start_cell())


func _eco_update_wood_stall() -> void:
	if _eco_last_wood < 0:
		_eco_last_wood = wood
		return
	if _eco_wood_short() and wood <= _eco_last_wood:
		_eco_wood_stall += 0.5
	else:
		_eco_wood_stall = 0.0
	_eco_last_wood = wood


func _eco_worker_kind(w: Unit) -> String:
	if w == null or not is_instance_valid(w):
		return ""
	if w._carry_kind != "" and (w._state == Unit.ST_RETURN or w._carry_amt > 0.0):
		return w._carry_kind
	if is_instance_valid(w._gather_node) and (w._state == Unit.ST_GATHER or w._state == Unit.ST_RETURN):
		return String(w._gather_node.res_kind)
	return ""


func _eco_effective_miners(kind: String) -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0 \
				and (u._state == Unit.ST_GATHER or u._state == Unit.ST_RETURN) \
				and _eco_worker_kind(u) == kind:
			n += 1
	return n


func _eco_wood_target() -> int:
	var workers := _eco_count_workers()
	if workers <= 0:
		return 0
	var keep_gold := 1 if workers > 1 else 0
	var baseline := maxi(ECO_MIN_WOODCUTTERS, _eco_wcap_dyn() - _eco_gold_target())
	return clampi(baseline, 1, maxi(1, workers - keep_gold))


func _eco_reassign_wood(workers: Array) -> void:
	if not _eco_wood_short():
		return
	var target := _eco_wood_target()
	if target <= 0:
		return
	var have := _eco_effective_miners("wood")
	var force_refresh := _eco_wood_stall >= 3.0
	if have >= target and not force_refresh:
		return
	var node := nearest_resource(_eco_base_pos(), "wood")
	if node == null:
		return
	var keep_gold := _eco_effective_miners("gold")
	var candidates: Array = []
	for w in workers:
		if not (is_instance_valid(w) and w.hp > 0.0 and not w.garrisoned):
			continue
		if w._state == Unit.ST_BUILD or w._state == Unit.ST_REPAIR:
			continue
		var k := _eco_worker_kind(w)
		if k == "wood" and not force_refresh:
			continue
		if k == "gold" and keep_gold <= 1:
			continue
		var pri := 2
		if w.is_idle_worker():
			pri = 0
		elif k == "wood":
			pri = 1
		elif k == "":
			pri = 1
		elif k == "gold":
			pri = 4
		candidates.append({"w": w, "p": pri, "d": w.position.distance_to(node.position), "k": k})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["p"]) == int(b["p"]):
			return float(a["d"]) < float(b["d"])
		return int(a["p"]) < int(b["p"]))
	var orders := 0
	var max_orders := target if force_refresh else maxi(0, target - have)
	for c in candidates:
		if orders >= max_orders:
			break
		var w: Unit = c["w"]
		if String(c["k"]) == "gold":
			if keep_gold <= 1:
				continue   # 收集候选时用的是初始金矿工数，这里按实时余量再拦一次——至少留 1 个金矿工
			keep_gold -= 1
		w.order_gather(node)
		orders += 1


## 反向再平衡：木不紧却金矿工不足目标、且伐木工有富余 → 每轮调一名伐木工回采金。
## 修「早期木荒把 5/6 工人一次性锁死在伐木，此后木溢到上千、金却始终 1 个矿工饿死，
## 全托管三分多钟才凑出 4 将——玩家看到左侧英雄栏长期空着」。与 _eco_reassign_wood 互斥(一个只在木紧时推、一个只在木足时拉)。
func _eco_rebalance_to_gold(workers: Array) -> void:
	if _eco_wood_short():
		return
	if _eco_count_miners("gold") >= _eco_gold_target():
		return
	# 木已明显富余(>金+300)只留 1 个维持伐木，否则守 ECO_MIN_WOODCUTTERS 保底——绝不把人锁死在伐木让金饿死
	var wood_floor := 1 if wood > gold + 300 else ECO_MIN_WOODCUTTERS
	if _eco_effective_miners("wood") <= wood_floor:
		return
	var ref := _eco_base_pos()
	var best: Unit = null
	var bd := INF
	for w in workers:
		if not (is_instance_valid(w) and w.hp > 0.0 and not w.garrisoned):
			continue
		if w._state == Unit.ST_BUILD or w._state == Unit.ST_REPAIR:
			continue
		if _eco_worker_kind(w) != "wood":
			continue
		var d: float = w.position.distance_to(ref)
		if d < bd:
			bd = d
			best = w
	if best == null:
		return
	var node: Unit = nearest_free_gold(ref, null, best)
	if node != null:
		best.order_gather(node)   # 每 0.5s 调 1 名，渐进收敛不抖


func _eco_workers() -> void:
	var workers: Array = []
	for u in units:
		if is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0:
			workers.append(u)
	if workers.is_empty():
		return
	_eco_reassign_wood(workers)
	_eco_rebalance_to_gold(workers)
	var gold_miners := _eco_count_miners("gold")
	for w in workers:
		if not w.is_idle_worker():
			continue
		var site := _eco_pending_site()
		if site != null and not _eco_wood_short():
			w.order_build(site)
			continue
		var want_gold := gold_miners < _eco_gold_target()   # 木紧时金矿工目标-1，腾人去伐木
		var ref := _eco_base_pos()   # 以基地为参照：先采离基地最近的资源，别让工人跑去远处那棵树
		var node: Unit = nearest_free_gold(ref, null, w) if want_gold else null
		if node == null:
			node = nearest_resource(ref, "wood")
		if node == null:
			node = nearest_resource(ref, "")
		if node != null:
			w.order_gather(node)
			if node.res_kind == "gold":
				gold_miners += 1
	_eco_repair()


## 自动修复：受损(<65%)、非施工、附近无敌的己方建筑 → 抽一名非金矿工去修（已有人修则不重复）。
func _eco_repair() -> void:
	if _eco_wood_short() and _eco_effective_miners("wood") < _eco_wood_target():
		return
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
	var w := _eco_free_worker(_eco_wood_short())
	if w != null:
		w.order_repair(dmg)


## 建造（并行·纯状态驱动）：先给所有在建工地补工人；在建数 < ECO_MAX_SITES 且按需+负担得起+有空闲工 → 再开一座。
func _eco_build(tech_reserve := {}) -> void:
	var active := 0
	for u in units:
		if is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG and u.is_constructing and u.hp > 0.0:
			active += 1
			if _eco_builders_on(u) == 0:   # 工地没人施工(工人阵亡/被打断)→ 补一个
				var bw := _eco_free_worker(_eco_wood_short())
				if bw != null:
					bw.order_build(u)
	if active >= ECO_MAX_SITES:
		return
	var e: Dictionary = _eco_next_build()
	if e.is_empty():
		return
	var key: String = e["key"]
	if _eco_wood_short() and _eco_effective_miners("wood") < _eco_wood_target() \
			and key != "depot" and key != "house":
		return
	var d: Dictionary = _defs.get(key, {})
	var cg := int(d.get("cost_gold", 0))
	var cw := int(d.get("cost_wood", 0))
	if not can_afford(cg, cw):
		return
	# 仓库/卡人口民居/第一座兵营是经济继续运转的硬前置，可突破科技预留；其余常备建筑先给科技让预算。
	var essential := key == "depot" or key == "house" or (key == "barracks" and _eco_count_building("barracks") < 1)
	if not essential and not _eco_can_spend_after_tech(cg, cw, tech_reserve):
		return
	if cg > 0 and gold - cg < _eco_revive_reserve():
		return   # 费金建筑要给复活留底线（纯木建筑 cg==0 不受限，照常盖）
	var cell := _eco_find_cell(_eco_anchor(String(e.get("near", "hall"))), key)
	if cell.x < 0:
		return
	# 前沿建筑(兵营/各塔·near=hall/front)选址处有敌 → 这拍先别起：否则工人和半成品都会被火线上的敌人打掉。
	# 塔(front)耐打、本就该顶在前面 → 只避开「贴脸」的敌(120px)，否则一开打就永远建不起来各种塔。
	var nr := String(e.get("near", "hall"))
	var guard_r := 120.0 if nr == "front" else 240.0
	if (nr == "hall" or nr == "front") and _foe_within(map.cell_to_world(cell), guard_r, Unit.FACTION_LIANG):
		return
	var builder := _eco_free_worker(_eco_wood_short())
	if builder == null:
		return
	if not spend(cg, cw):
		return
	ai_start_construction(key, cell, Unit.FACTION_LIANG, builder)


## 练兵（英雄至上·高于一切）：只要还没出齐 或 有英雄战死，聚义厅就【只许排英雄】——
## 立刻停掉队列里的所有非英雄(喽啰)退资源，然后 有钱就复活 > 有钱就按序把没出的英雄全塞进队列。
## 期间不补农民、不造兵。英雄全员在阵且无人阵亡时，才补农民到 wcap + 兵营练常备军。
func _eco_train(research_plans := [], tech_reserve := {}) -> void:
	var hall := main_base(Unit.FACTION_LIANG)
	if hall == null or hall.is_constructing:
		return
	var reserved := _eco_reserved_buildings(research_plans)
	var hero_pending := _eco_hero_count() < _eco_hero_target()   # 没出齐 或 有人战死(现役<目标)
	if hero_pending:
		_eco_clear_hall_nonhero(hall)   # 聚义厅有非英雄队列(喽啰)→ 全停掉，腾出来出英雄/复活
		# 木荒急救(高于英雄逻辑)：木紧且喽啰不足上限 → 即便在攒/复活英雄，也补一个喽啰去伐木。
		# 喽啰仅 20 金且不碰复活底线；否则「伐木工全死 + 英雄战死攒金复活」会锁死经济、永不产喽啰(用户反馈)。
		var wood_emergency := _eco_wood_short() and _eco_effective_miners("wood") < ECO_MIN_WOODCUTTERS
		var worker_cost := int(_defs.get("lou_luo", {}).get("cost_gold", 20))
		if _eco_wood_short() and _eco_count_workers() < _eco_wcap_dyn() and not _eco_in_queue("lou_luo") \
				and _eco_can_train("lou_luo", hall) \
				and (wood_emergency or gold - worker_cost >= _eco_revive_reserve()):
			queue_train(hall, "lou_luo", false)
		# 有钱就复活：战死英雄(有存档、不在场、未在队列) → 按 ORDER 能复几个复几个
		var revived := false
		for hk in ECO_HERO_ORDER:
			if hero_progress.has(hk) and count_alive(Unit.FACTION_LIANG, hk) == 0 and not _eco_in_queue(hk):
				if not _eco_can_train(hk, hall):
					break
				if queue_train(hall, hk, false):   # 原价复活，保留等级/技能
					revived = true
		if revived:
			return
		# 有钱就出：按 ORDER 把还没出的英雄一口气全塞进队列(直到钱/人口/队列上限)；绝不越位、不补农民/造兵
		for hk in ECO_HERO_ORDER:
			if count_alive(Unit.FACTION_LIANG, hk) > 0 or _eco_in_queue(hk) or hero_progress.has(hk):
				continue
			if not _eco_can_train(hk, hall):
				break
			queue_train(hall, hk, false)
		return
	# 英雄齐全且无人阵亡：补农民 → 兵营常备军
	if not reserved.has(hall.get_instance_id()) and _eco_count_workers() < _eco_wcap_dyn() \
			and _eco_can_train("lou_luo", hall, tech_reserve):
		queue_train(hall, "lou_luo", false)
		return
	if _eco_army_count() + _eco_queued_army() < ECO_ARMY_CAP:
		var bar := _eco_idle_barracks(reserved)   # 选队列最短的非研究兵营，多兵营并行出兵
		if bar != null:
			var sk := _eco_pick_soldier()
			# 练常备军也要给复活留底线（费金）；纯靠木的兵很少，金不足就先攒着复活金
			if sk != "" and _eco_can_train(sk, bar, tech_reserve) and gold - int(_defs.get(sk, {}).get("cost_gold", 0)) >= _eco_revive_reserve():
				queue_train(bar, sk, false)


## 聚义厅队列里所有「非英雄」项(喽啰)立刻停掉并退还资源——全托管下英雄/复活高于一切，聚义厅专供英雄。
## 静默处理(不弹提示/音效)：训练中的队首(index 0)也照停，停后重置队首计时。
func _eco_clear_hall_nonhero(hall: Unit) -> void:
	var keep_wood := _eco_wood_short()   # 木荒急救：保留喽啰(伐木工)，别把救命工也一并退了
	var changed := false
	var i := 0
	while i < hall._train_queue.size():
		var k: String = hall._train_queue[i]
		if bool(_defs.get(k, {}).get("hero_trainable", false)) or (keep_wood and k == "lou_luo"):
			i += 1
			continue
		var d: Dictionary = _defs.get(k, {})
		add_resources(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0)))   # 退还花费
		hall._train_queue.remove_at(i)
		if i == 0 and not hall._train_queue.is_empty():
			hall._train_t = train_time_for(hall._train_queue[0])
		changed = true
	if changed and hud != null:
		hud.refresh_command()


## 研究（英雄之后）：规划和提交分离。规划阶段保留建筑/预算，提交阶段只在队列已空时静默下单。
## 聚义厅与兵营是两条独立通道；一边排队不会再阻塞另一边的科技。
func _eco_research_plans() -> Array:
	var out: Array = []
	if _eco_hero_count() < _eco_hero_target():
		return out
	var hall := main_base(Unit.FACTION_LIANG)
	if hall != null and not hall.is_constructing and hall._research_key == "":
		var hall_key := _eco_next_tech(["tech_gather", "tech_age2", "tech_age3"])
		if hall_key != "":
			out.append(_eco_research_plan(hall, hall_key))
	# 兵营科技保持串行，但从所有兵营中挑队列最短的一座；不再写死 units 里的第一座。
	if not _eco_research_channel_busy(["tech_armor", "tech_weapon"]):
		var bar := _eco_research_barracks()
		var bar_key := _eco_next_tech(["tech_armor", "tech_weapon"])
		if bar != null and bar_key != "":
			out.append(_eco_research_plan(bar, bar_key))
	return out


func _eco_next_tech(order: Array) -> String:
	for key_v in order:
		var key := String(key_v)
		if _tech_done.has(key) or _tech_in_progress(key):
			continue
		if int(Defs.TECHS.get(key, {}).get("min_age", 1)) > current_age:
			continue
		return key
	return ""


func _eco_research_channel_busy(keys: Array) -> bool:
	for u in units:
		if not (is_instance_valid(u) and u.is_building and u.faction == Unit.FACTION_LIANG and u.hp > 0.0):
			continue
		if u._research_key in keys:
			return true
	return false


func _eco_research_barracks() -> Unit:
	var best: Unit = null
	for u in units:
		if not (is_instance_valid(u) and u.key == "barracks" and u.faction == Unit.FACTION_LIANG \
				and u.hp > 0.0 and not u.is_constructing and u._research_key == ""):
			continue
		if best == null or u._train_queue.size() < best._train_queue.size() \
				or (u._train_queue.size() == best._train_queue.size() and u.get_instance_id() < best.get_instance_id()):
			best = u
	return best


func _eco_research_plan(bld: Unit, key: String) -> Dictionary:
	var d: Dictionary = Defs.TECHS.get(key, {})
	return {"bld": bld, "key": key, "cost_g": int(d.get("cost_gold", 0)), "cost_w": int(d.get("cost_wood", 0))}


## 一次只为最高优先级、尚未启动的科技留预算；启动扣费后下一拍自然轮到另一通道，避免过度冻结经济。
func _eco_research_reserve(plans: Array) -> Dictionary:
	if plans.is_empty():
		return {"gold": 0, "wood": 0}
	return {"gold": int(plans[0].get("cost_g", 0)), "wood": int(plans[0].get("cost_w", 0))}


func _eco_reserved_buildings(plans: Array) -> Dictionary:
	var out := {}
	for p in plans:
		var bld = p.get("bld", null)
		if is_instance_valid(bld):
			out[bld.get_instance_id()] = true
	return out


func _eco_can_spend_after_tech(cg: int, cw: int, reserve: Dictionary) -> bool:
	return can_afford(cg, cw) and gold - cg >= int(reserve.get("gold", 0)) \
		and wood - cw >= int(reserve.get("wood", 0))


func _eco_research(plans := []) -> void:
	var held := {"gold": 0, "wood": 0}
	for p in plans:
		var bld = p.get("bld", null)
		var key := String(p.get("key", ""))
		if not is_instance_valid(bld):
			continue
		var cg := int(p.get("cost_g", 0))
		var cw := int(p.get("cost_w", 0))
		if not bld._train_queue.is_empty() or not _eco_can_spend_after_tech(cg, cw, held):
			# 正常等待队列/资源：保住这项更高优先科技的预算，但仍允许另一通道用真正多出来的资源启动。
			held["gold"] = maxi(int(held["gold"]), cg)
			held["wood"] = maxi(int(held["wood"]), cw)
			continue
		# 每拍至多启动一项；下一拍已启动通道会退出计划，另一通道即可接着启动，既能并行又不越过预算优先级。
		if queue_research(bld, key, false):
			return
		held["gold"] = maxi(int(held["gold"]), cg)
		held["wood"] = maxi(int(held["wood"]), cw)


## 集市贸易（双向·防经济死锁）：有集市才换。
## ① 木荒急救(优先)：木紧(库存<金六成或低于地板)且金有富余(留足复活底线) → 卖金换木；
##    修「有钱却无木 → 建造与补伐木工两停」的硬死锁（全托管常被塔/民居等纯木建筑把木抽干）。
## ② 缺金囤木：金不足又木溢出 → 卖木换金（金是后期练兵瓶颈，木常溢出）。
func _eco_trade(tech_reserve := {}) -> void:
	if _eco_first_building("market") == null:
		return
	var wood_emergency := _eco_wood_short() and (_eco_effective_miners("wood") < ECO_MIN_WOODCUTTERS or _eco_wood_stall >= 3.0)
	var gold_reserved := int(tech_reserve.get("gold", 0))
	var wood_reserved := int(tech_reserve.get("wood", 0))
	if _eco_wood_short() and (gold >= TRADE_AMT + maxi(_eco_revive_reserve(), gold_reserved) \
			or (wood_emergency and gold >= TRADE_AMT + 20)):
		do_trade("gold")   # 100 金 → 70 木：木荒兜底；常规不动复活底线，紧急木荒(伐木断档/木量停滞)例外——先解锁经济再攒复活金
		return
	if gold < 300 and wood >= 500 and wood - TRADE_AMT >= wood_reserved:
		do_trade("wood")   # 100 木 → 70 金


## 复活留金底线 = max(2, 当前战死可复活英雄数) × ECO_REVIVE_GOLD。
## 所有非复活的花金行为(造塔/练常备军/布陷阱)都不得把金压到此线以下；复活本身(_eco_train 英雄分支)无视它。
func _eco_revive_reserve() -> int:
	var dead := 0
	for hk in ECO_HERO_ORDER:
		if hero_progress.has(hk) and count_alive(Unit.FACTION_LIANG, hk) == 0 and not _eco_in_queue(hk):
			dead += 1
	return maxi(2, dead) * ECO_REVIVE_GOLD


## 全托管布陷阱：出齐英雄后、钱有富余时，沿前线再往敌方推一点散布一次性机关（轮换三种），上限 ECO_TRAP_CAP。
func _eco_traps(tech_reserve := {}) -> void:
	_eco_trap_cd -= 0.5   # 本拍 ~0.5s 调一次
	if _eco_trap_cd > 0.0:
		return
	_eco_trap_cd = 5.0
	if _traps.size() >= ECO_TRAP_CAP:
		return
	if _eco_hero_count() < _eco_hero_target():
		return   # 英雄至上：没出齐不布陷阱
	if gold < _eco_revive_reserve() + 80:
		return   # 留钱给英雄复活(底线)+一点富余才布陷阱
	var pick := ""
	for k in Defs.TRAPS:
		var d: Dictionary = Defs.TRAPS[k]
		if can_afford(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0))):
			pick = k
			break
	if pick == "":
		return
	# 落点：优先布在敌人固定来路上（三门→基地的走廊，轮流照顾三路）——驻守战敌人只走这几条道，
	# 撒在走廊里必踩；没有门数据（非驻守）才退回旧的「集结点外推+随机散布」。
	var spot: Vector2
	var lanes := _eco_lanes()
	if not lanes.is_empty():
		var gates: Array = level.threat_gates()
		var li := _eco_trap_lane % lanes.size()
		_eco_trap_lane += 1
		var anchor: Vector2 = lanes[li]
		var gw: Vector2 = map.cell_to_world(gates[li])
		var fwd := (gw - anchor)
		fwd = fwd.normalized() if fwd.length() > 1.0 else Vector2(1, 0)
		spot = anchor + fwd * randf_range(40.0, 170.0) + Vector2(randf_range(-55.0, 55.0), randf_range(-55.0, 55.0))
	else:
		var muster := _eco_muster_point()
		var fl := _eco_frontline()
		var fwd2 := muster - fl
		fwd2 = fwd2.normalized() if fwd2.length() > 1.0 else Vector2(1, 0)
		spot = muster + fwd2 * randf_range(40.0, 150.0) + Vector2(randf_range(-90.0, 90.0), randf_range(-90.0, 90.0))
	# spot 全程是逻辑空间（unit.position/cell_to_world 同系）——原先这里多套了一层 to_logic(ISO逆变换)，
	# 把落点扭到斜 45° 的错位处，陷阱经常落在莫名其妙的地方/直接放不下。
	var cell := map.world_to_cell(spot)
	if not map.area_buildable(cell, 0):
		return
	var wp := map.cell_to_world(cell)
	for tr in _traps:   # 别和已有陷阱挤一起
		if wp.distance_to(tr["pos"]) < 80.0:
			return
	var dd: Dictionary = Defs.TRAPS[pick]
	var cg := int(dd.get("cost_gold", 0))
	var cw := int(dd.get("cost_wood", 0))
	if not _eco_can_spend_after_tech(cg, cw, tech_reserve) or not spend(cg, cw):
		return
	_place_trap(pick, wp, Unit.FACTION_LIANG)


# ---------- 全托管经济·助手 ----------

## 下一座要建的（纯状态驱动·英雄优先）：
##   ①仓库(采金命脉，最先且被拆即重建) → ②出英雄前只铺够 6 英雄人口的民居，其余省钱给英雄
##   → ③出齐英雄后按 ECO_MAINT 补兵营/民居/箭楼(被拆即重建)。
func _eco_next_build() -> Dictionary:
	if _eco_count_building("depot") < 1:
		return {"key": "depot", "near": "gold"}
	# 出 2 个英雄后：在树边补一座仓库(木头落点)，缩短伐木往返、拉高木产；木紧时尤为关键。
	if _eco_hero_count() >= 2 and not _eco_has_depot_near_wood():
		return {"key": "depot", "near": "wood"}
	# 民居：仅在人口快不够时按需补(含在产英雄/兵的人口)，不再无脑堆——出英雄前后同此一处判定。
	if _eco_house_needed():
		return {"key": "house", "near": "back"}
	# 英雄未出齐时：金吃紧→把金留给英雄/复活(别的不修)；金有富余→照样修塔/兵营/集市(走 ECO_MAINT)。
	# 硬等「6 英雄同时在场」常因前线伤亡永远凑不齐，会让上千金睡大觉、各种塔永远建不起来——故富余即放行。
	if _eco_hero_count() < _eco_hero_target() and gold < _eco_revive_reserve() + 200:
		return {}
	for m in ECO_MAINT:
		if _eco_count_building(String(m[0])) < int(m[1]):
			return {"key": String(m[0]), "near": String(m[2])}
	return {}


## 该补民居了吗？——按需建：把(已用人口+在产队列人口) 与 (当前上限+在建民居将提供的人口) 比，
## 余量低于 ECO_POP_HEADROOM 才盖；并设硬顶 ECO_POP_MAX 防止无限堆。人口只在「快不够」时才扩。
func _eco_house_needed() -> bool:
	if pop_cap >= ECO_POP_MAX:
		return false
	var projected_cap := pop_cap + _eco_constructing_pop()   # 现上限 + 在建民居完工后会加的人口
	var demand := used_pop() + _queued_pop()                 # 现役 + 兵营队列里待产的人口
	return demand + ECO_POP_HEADROOM > projected_cap


## 在建中(尚未完工)的供人口建筑将来会提供的人口之和——避免施工期间重复下单把民居堆爆。
func _eco_constructing_pop() -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_building \
				and u.is_constructing and u.hp > 0.0:
			n += int(u.setup_def.get("provides_pop", 0))
	return n


## 树边是否已有仓库(木头落点)：最近林木 320px 内有完好仓库即算有。无林木则视为不需要。
func _eco_has_depot_near_wood() -> bool:
	var hall := main_base(Unit.FACTION_LIANG)
	var hp: Vector2 = hall.position if hall != null else map.cell_to_world(level.camera_start_cell())
	var tree := nearest_resource(hp, "wood")
	if tree == null:
		return true
	for u in units:
		if is_instance_valid(u) and u.key == "depot" and u.faction == Unit.FACTION_LIANG \
				and u.hp > 0.0 and not u.is_constructing and u.position.distance_to(tree.position) < 320.0:
			return true
	return false


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
	if near == "wood":
		var w := nearest_resource(hp, "wood")
		if w != null:
			return map.world_to_cell(w.position)
	if near == "back":
		# 基地「后方」（远离前线一侧）外推 7 格——民居堆这儿，别挤在基地/集结走廊/采矿角，免得卡住单位
		var fl := _eco_frontline()
		var away := hp - fl
		away = away.normalized() if away.length() > 1.0 else Vector2(-1, 1)
		return map.world_to_cell(hp + away * (7.0 * float(GameMap.CELL)))
	if near == "front":
		# 塔往前沿外推：从聚义厅朝「敌军来向」推出 ECO_FRONT_CELLS 格，在基地前面结成前置防线。
		# 距离上限 = hall→最近敌 ×ECO_FRONT_CAP_FRAC：小图/敌近时别把塔锚到敌脸上、半成品被秒。
		var dir := _eco_forward_dir()
		var dist := ECO_FRONT_CELLS * float(GameMap.CELL)
		var nf := _nearest_foe_pos(hp, Unit.FACTION_LIANG)
		if nf != Vector2.INF:
			dist = minf(dist, hp.distance_to(nf) * ECO_FRONT_CAP_FRAC)
		return map.world_to_cell(hp + dir * dist)
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
				if map.area_buildable(c, half) and not _resource_overlap(c, half):
					return c
	return Vector2i(-1, -1)


## 拉一名可建造的工人：常规优先非金矿工；木荒时保护正在伐木/送木的工人，避免越缺木越把木工拉走。
func _eco_free_worker(protect_wood := false) -> Unit:
	var fallback_gold: Unit = null
	for u in units:
		if not (is_instance_valid(u) and u.is_worker and u.faction == Unit.FACTION_LIANG and u.hp > 0.0):
			continue
		if u._state == Unit.ST_BUILD or u._state == Unit.ST_REPAIR:
			continue
		var k := _eco_worker_kind(u)
		if protect_wood and k == "wood":
			continue   # 木荒保护：绝不抽伐木/送木工（宁可这轮没人可派）
		if k == "gold":
			fallback_gold = u
			continue
		return u
	return fallback_gold


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
	var hp: Vector2 = base.position if (base != null and is_instance_valid(base)) else map.cell_to_world(level.camera_start_cell())
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
		return (c + dir.normalized() * 110.0) if dir.length() > 1.0 else c   # 站到前沿建筑「外面一点」
	var foe := _nearest_foe_pos(hp, Unit.FACTION_LIANG)
	if foe != Vector2.INF:
		return hp.lerp(foe, 0.45)
	return hp


## 「前方」单位向量（聚义厅→敌军来向）：优先朝最近敌，无敌则朝战线方向，再无则默认东南。
## 塔的前推方向用它——保证塔阵正对敌军来路，而非朝着随机环放的兵营。O(n)，只在建造拍/无塔时调用。
func _eco_forward_dir() -> Vector2:
	var base := main_base(Unit.FACTION_LIANG)
	var hp: Vector2 = base.position if (base != null and is_instance_valid(base)) else map.cell_to_world(level.camera_start_cell())
	var nf := _nearest_foe_pos(hp, Unit.FACTION_LIANG)
	if nf != Vector2.INF:
		var d := nf - hp
		if d.length() > 1.0:
			return d.normalized()
	var fl := _eco_frontline()
	var fwd := fl - hp
	return fwd.normalized() if fwd.length() > 1.0 else Vector2(1, -1)


## 英雄 hold-line（依塔而战的锚点）：我方已建成前置塔群的质心，朝外(远离聚义厅)再推 1.5 格——
## 英雄站在塔阵稍前一点替塔扛线、依塔御敌。尚无塔时回退到塔的规划锚点(front anchor)。
## 只在「身边无敌该回防待命」时调用(见 _auto_micro_hero)，故 O(n) 扫描落在低战斗负载的拍，不进热路径。
## 分路防守：驻守战敌人固定从右侧三门来（level.threat_gates）。技能有施法距离后英雄不能再全挤
## 在「各塔平均位置」——另一路出兵时技能够不着还要慢慢走过去。这里给每条来路算一个前置锚点
## （基地→门约 1/3 处），托管英雄按稳定顺序轮流领路；自己那路暂时没敌人就去支援最热的一路。
func _eco_lanes() -> Array:
	var gates: Array = level.threat_gates()
	if gates.is_empty():
		return []
	var base := main_base(Unit.FACTION_LIANG)
	if base == null or not is_instance_valid(base):
		return []
	var out: Array = []
	for g in gates:
		var gw: Vector2 = map.cell_to_world(g)
		var p: Vector2 = base.position + (gw - base.position) * 0.35
		out.append(map.cell_to_world(map.nearest_open(map.world_to_cell(p))))
	return out


## 返回离 pos 最近的路线编号。路线锚点从基地向三个敌门展开，可同时用于敌军/守军/英雄归路。
func _eco_nearest_lane(pos: Vector2, lanes: Array) -> int:
	if lanes.is_empty():
		return -1
	var best := 0
	var bd := INF
	for i in range(lanes.size()):
		var d: float = pos.distance_squared_to(lanes[i])
		if d < bd:
			bd = d
			best = i
	return best


## 各路当前敌军数量（该路锚点是三路里离它最近的一路）。
func _eco_lane_threat(lanes: Array) -> Array:
	var th: Array = []
	th.resize(lanes.size())
	th.fill(0)
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_GUAN or u.is_building \
				or u.is_resource or u.garrisoned or u.hp <= 0.0:
			continue
		var bi := _eco_nearest_lane(u.position, lanes)
		if bi >= 0:
			th[bi] += 1
	return th


## 各路加权压力：普通兵=1、骑兵=1.25、攻城/战象=2.5、敌将=3。
## 数量仍是主因素，但少量高威胁单位不会被误判成“这路没事”。
func _eco_lane_pressure(lanes: Array) -> Array:
	var pressure: Array = []
	pressure.resize(lanes.size())
	pressure.fill(0.0)
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_GUAN or u.is_building \
				or u.is_resource or u.garrisoned or u.is_captive or u.hp <= 0.0:
			continue
		var w := 1.0
		if u.is_hero:
			w = 3.0
		elif String(u.key).begins_with("siege") or u.key == "war_elephant":
			w = 2.5
		elif u.is_cavalry:
			w = 1.25
		var li := _eco_nearest_lane(u.position, lanes)
		if li >= 0:
			pressure[li] = float(pressure[li]) + w
	return pressure


## 路线上已存在、不会参与本轮英雄调度的守备力量。工人不算；普通兵=1、塔=2.5、手操英雄=3。
## 全托管英雄不在这里重复计数，稍后由分配器按每人 3 点防守量逐个填入。
func _eco_lane_cover(lanes: Array) -> Array:
	var cover: Array = []
	cover.resize(lanes.size())
	cover.fill(0.0)
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 \
				or u.is_resource or u.is_worker or u.garrisoned:
			continue
		var w := 1.0
		if u.is_building:
			if u.is_constructing or u.atk <= 0.0:
				continue
			w = 2.5
		elif u.is_hero:
			if u.auto_micro and not u.manual_order_active and u.manual_order_t <= 0.0:
				continue
			w = 3.0
		var li := _eco_nearest_lane(u.position, lanes)
		if li >= 0:
			cover[li] = float(cover[li]) + w
	return cover


func _eco_lane_heroes() -> Array:
	var heroes: Array = []
	for h in units:
		if is_instance_valid(h) and h.faction == Unit.FACTION_LIANG and h.is_hero and h.hp > 0.0 \
				and h.auto_micro and not h.manual_order_active and h.manual_order_t <= 0.0:
			heroes.append(h)
	heroes.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	return heroes


const ECO_LANE_HERO_COVER := 3.0


## 纯分配器：无敌时均匀站三路；有敌时每次把下一名英雄投向
## pressure / (现有守军 + 已派英雄) 最大的一路。多路同时来敌会自然分兵，守军已足的路不再堆人。
func _eco_lane_allocate(pressure: Array, cover: Array, hero_count: int) -> Array:
	var out: Array = []
	out.resize(maxi(0, hero_count))
	out.fill(-1)
	var lane_n := pressure.size()
	if lane_n <= 0 or hero_count <= 0:
		return out
	var total := 0.0
	for p in pressure:
		total += maxf(0.0, float(p))
	if total <= 0.0:
		for hi in range(hero_count):
			out[hi] = hi % lane_n
		return out
	var assigned: Array = []
	assigned.resize(lane_n)
	assigned.fill(0)
	var hi := 0
	# 先给“有敌且现有守军压不住”的每一路至少一名英雄。敌军再多，也不能把另一条漏兵路线完全放空。
	var uncovered: Array = []
	for li in range(lane_n):
		var fixed_cover := float(cover[li]) if li < cover.size() else 0.0
		if float(pressure[li]) > maxf(0.0, fixed_cover):
			uncovered.append(li)
	while hi < hero_count and not uncovered.is_empty():
		var pick := int(uncovered[0])
		var pick_score := -INF
		for li in uncovered:
			var fixed_cover := float(cover[int(li)]) if int(li) < cover.size() else 0.0
			var score := float(pressure[int(li)]) / maxf(1.0, fixed_cover)
			if score > pick_score:
				pick_score = score
				pick = int(li)
		out[hi] = pick
		assigned[pick] = 1
		uncovered.erase(pick)
		hi += 1
	# 剩余英雄继续投向压力/防守量最高的一路。
	for slot_i in range(hi, hero_count):
		var best := -1
		var best_score := -INF
		for li in range(lane_n):
			var p := maxf(0.0, float(pressure[li]))
			if p <= 0.0:
				continue
			var fixed_cover := float(cover[li]) if li < cover.size() else 0.0
			var defence := maxf(1.0, fixed_cover + float(assigned[li]) * ECO_LANE_HERO_COVER)
			var score := p / defence
			if score > best_score:
				best_score = score
				best = li
		if best < 0:
			best = slot_i % lane_n
		out[slot_i] = best
		assigned[best] = int(assigned[best]) + 1
	return out


## 把分配器给出的各路“名额”映射到具体英雄：优先保留已经在该路的人，只调走超额者，减少横跳换线。
func _eco_lane_assignments(lanes: Array, heroes: Array, pressure: Array, cover: Array) -> Dictionary:
	var slots := _eco_lane_allocate(pressure, cover, heroes.size())
	var need: Array = []
	need.resize(lanes.size())
	need.fill(0)
	for li in slots:
		if int(li) >= 0:
			need[int(li)] = int(need[int(li)]) + 1
	var result := {}
	var open: Array = heroes.duplicate()
	# 先保留本来就在该路的英雄（离该路锚点近者优先）。
	for li in range(lanes.size()):
		var stay: Array = []
		for h in open:
			if _eco_nearest_lane(h.position, lanes) == li:
				stay.append(h)
		stay.sort_custom(func(a, b): return a.position.distance_squared_to(lanes[li]) < b.position.distance_squared_to(lanes[li]))
		for si in range(mini(int(need[li]), stay.size())):
			var h: Unit = stay[si]
			result[h.get_instance_id()] = li
			open.erase(h)
			need[li] = int(need[li]) - 1
	# 剩余英雄按到尚缺路线的距离补位，跨路人数保持最少。
	for h in open:
		var best := -1
		var bd := INF
		for li in range(lanes.size()):
			if int(need[li]) <= 0:
				continue
			var d: float = h.position.distance_squared_to(lanes[li])
			if d < bd:
				bd = d
				best = li
		if best < 0:
			best = _eco_nearest_lane(h.position, lanes)
		result[h.get_instance_id()] = best
		if best >= 0:
			need[best] = maxi(0, int(need[best]) - 1)
	return result


## 同一个 AI 决策周期只扫描一次全场敌军/守军，所有英雄共享同一份路线计划。
## 最多延迟 AI_TICK 帧（约 0.27 秒）响应新波次，和英雄本身的决策节流一致。
func _eco_lane_runtime_state() -> Dictionary:
	var bucket := int(Engine.get_physics_frames() / maxi(1, AI_TICK))
	if _eco_lane_cache_bucket == bucket and not _eco_lane_cache.is_empty():
		return _eco_lane_cache
	var lanes := _eco_lanes()
	var pressure: Array = _eco_lane_pressure(lanes) if not lanes.is_empty() else []
	var heroes := _eco_lane_heroes()
	var assignments := _eco_lane_assignments(lanes, heroes, pressure, _eco_lane_cover(lanes)) \
			if not lanes.is_empty() else {}
	_eco_lane_cache_bucket = bucket
	_eco_lane_cache = {"lanes": lanes, "pressure": pressure, "heroes": heroes, "assignments": assignments}
	return _eco_lane_cache


func _eco_hold_line() -> Vector2:
	var base := main_base(Unit.FACTION_LIANG)
	var hp: Vector2 = base.position if (base != null and is_instance_valid(base)) else map.cell_to_world(level.camera_start_cell())
	var sum := Vector2.ZERO
	var n := 0
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.is_building \
				and not u.is_constructing and u.hp > 0.0 \
				and (u.key == "arrow_tower" or u.key == "caltrop_tower" \
					or u.key == "thunder_tower" or u.key == "altar_tower"):
			sum += u.position
			n += 1
	if n > 0:
		var c: Vector2 = sum / float(n)
		var out := c - hp
		out = out.normalized() if out.length() > 1.0 else Vector2(1, -1)
		return c + out * (1.5 * float(GameMap.CELL))
	return map.cell_to_world(_eco_anchor("front"))


## 队列最短的可训练兵营（多兵营并行出兵，研究中/研究保留的建筑不参与）。
func _eco_idle_barracks(reserved := {}) -> Unit:
	var best: Unit = null
	var bq := 999
	for u in units:
		if is_instance_valid(u) and u.key == "barracks" and u.faction == Unit.FACTION_LIANG \
				and u.hp > 0.0 and not u.is_constructing and u._research_key == "" \
				and not reserved.has(u.get_instance_id()) and u._train_queue.size() < bq:
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


## 自动训练前置检查：复用正式下单校验，再叠加科技预算；不会再漏掉「建筑正在研究」。
func _eco_can_train(key: String, bld: Unit, tech_reserve := {}) -> bool:
	if _train_block_reason(bld, key) != "":
		return false
	var d: Dictionary = _defs.get(key, {})
	return _eco_can_spend_after_tech(int(d.get("cost_gold", 0)), int(d.get("cost_wood", 0)), tech_reserve)


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
	rect.z_index = 3700   # 氛围调色在单位/特效/迷雾之上（单位现走 z_index 深度序，z≤3400）
	add_child(rect)


## ---------- 战争迷雾 ----------

func _init_fog() -> void:
	var n := map.w * map.h
	_vision = PackedByteArray()
	_vision.resize(n)               # 默认 0=未探索
	_sight_now = PackedByteArray()
	_sight_now.resize(n)
	_reveal_t = PackedFloat32Array()
	_reveal_t.resize(n)
	_vision_img = Image.create(map.w, map.h, false, Image.FORMAT_RGBA8)
	_vision_img.fill(Color(0, 0, 0, 1.0))
	_fog_tex = ImageTexture.create_from_image(_vision_img)
	_fog_layer = FogLayer.new()
	_fog_layer.z_index = 3600   # 迷雾盖住单位(z≤3400)与特效(3500)，维持原层序
	_fog_layer.tex = _fog_tex
	_fog_layer.ws = Vector2(map.w * GameMap.CELL, map.h * GameMap.CELL)
	world.add_child(_fog_layer)   # 在 units/fx 之后 → 盖住迷雾中的敌人


# 「当前可见」：只认单位真实视野或技能临时侦察。决定敌军显示、点击和锁定。
func is_visible_world(p: Vector2) -> bool:
	if not fog:
		return true
	var c := map.world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= map.w or c.y >= map.h:
		return false
	var i := c.y * map.w + c.x
	return _sight_now[i] == 1 or _reveal_t[i] > 0.0


# 出生帧专用的即时视野判定：不读取最多落后 FOG_STEP 的 _sight_now，直接按当前友军格位计算。
# 只在生成官军时调用，避免把全单位扫描放进逐帧索敌热路径。
func _has_live_sight_at(p: Vector2) -> bool:
	if not fog:
		return true
	var c := map.world_to_cell(p)
	if c.x < 0 or c.y < 0 or c.x >= map.w or c.y >= map.h:
		return false
	var idx := c.y * map.w + c.x
	if not _reveal_t.is_empty() and _reveal_t[idx] > 0.0:
		return true
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 \
				or u.is_resource or u.garrisoned:
			continue
		var uc := map.world_to_cell(u.position)
		var dc := c - uc
		var r := int(u.setup_def.get("sight", 10 if u.is_building else 8))
		if dc.x * dc.x + dc.y * dc.y <= r * r:
			return true
	return false


# 地面明亮与实时可见严格同义；失去视野后立即转为已探索阴影。
func is_lit_world(p: Vector2) -> bool:
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


func target_visible_to(observer: Unit, target: Unit) -> bool:
	if target == null or not is_instance_valid(target) or target._invis_t > 0.0:
		return false
	# 战争迷雾是玩家情报规则；官军 AI 不读取玩家的视野缓存。
	if fog and observer != null and observer.faction == Unit.FACTION_LIANG and target.faction == Unit.FACTION_GUAN:
		if is_visible_world(target.position):
			return true
		# 视野纹理约 0.18 秒刷新一次；逻辑索敌用观察者距离即时补判，避免敌人贴脸后还短暂无敌。
		var sight := float(observer.setup_def.get("sight", 10 if observer.is_building else 8)) * GameMap.CELL
		return observer.position.distance_to(target.position) <= sight
	return true


func _fog_pass(delta: float) -> void:
	_fog_t -= delta
	if _fog_t > 0.0:
		return
	var step := FOG_STEP - _fog_t               # 距上次 pass 的实际秒数（用于临时侦察倒计时）
	_fog_t = FOG_STEP
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
	# 2) 统一实时视野与地面明暗：明亮格必定能看见普通敌军；失去视野的已探索格本拍即转阴影。
	#    禁止保留“地面仍亮、敌军却隐藏”的伪视野，否则敌人再次被发现时会像在亮地上凭空冒出。
	for i in range(n):
		if _reveal_t[i] > 0.0:
			_reveal_t[i] = maxf(0.0, _reveal_t[i] - step)
		if _sight_now[i] == 1 or _reveal_t[i] > 0.0:
			_vision[i] = 2
		elif _vision[i] != 0:
			_vision[i] = 1                    # 曾探索但当前无视野 → 阴影
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
				u.fog_visible = is_explored_world(u.position)
			else:
				u.fog_visible = is_visible_world(u.position)
			var reveal_now: bool = u.fog_visible and not u.garrisoned and unit_visual_active(u.position)
			if reveal_now and not u.visible:
				u.queue_redraw()   # 屏外/迷雾期间状态可能已结束，重新入画时丢弃旧绘制命令。
			u.visible = reveal_now


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
				_reveal_t[idx] = maxf(_reveal_t[idx], dur)


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
	_disarm_patrol()
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


## 驻守战英雄实时统计。伤害在 Unit.take_damage 减伤/护盾结算后按实际值增量回填，
## 没有逐帧遍历；召唤物/幻象通过 stat_owner_key 归到召唤英雄。
func _ensure_hero_combat_stat(hero_key: String, hero_name: String) -> Dictionary:
	var rec: Dictionary = hero_combat_stats.get(hero_key, {
		"name": hero_name, "damage": 0.0, "taken": 0.0, "kills": 0})
	if String(rec.get("name", "")) == "":
		rec["name"] = hero_name
	hero_combat_stats[hero_key] = rec
	return rec


func _hero_stat_attacker_key(attacker: Unit) -> String:
	if attacker == null or not is_instance_valid(attacker) or attacker.faction != Unit.FACTION_LIANG:
		return ""
	if attacker.is_hero:
		return attacker.key
	return attacker.stat_owner_key


func record_hero_combat_damage(victim: Unit, attacker: Unit, amount: float) -> void:
	if not track_hero_combat_stats or amount <= 0.0:
		return
	var attacker_key := _hero_stat_attacker_key(attacker)
	if attacker_key != "" and victim != null and is_instance_valid(victim) \
			and victim.faction == Unit.FACTION_GUAN:
		var attacker_name := attacker.display_name if attacker.is_hero \
				else String(_defs.get(attacker_key, {}).get("name", attacker_key))
		var dealt := _ensure_hero_combat_stat(attacker_key, attacker_name)
		dealt["damage"] = float(dealt["damage"]) + amount
		hero_combat_stats[attacker_key] = dealt
	if victim != null and is_instance_valid(victim) and victim.is_hero \
			and victim.faction == Unit.FACTION_LIANG:
		var received := _ensure_hero_combat_stat(victim.key, victim.display_name)
		received["taken"] = float(received["taken"]) + amount
		hero_combat_stats[victim.key] = received


## 仅增加己方英雄承伤，不增加敌方/己方输出：用于记录李逵 Q 减免、W 物免真正拦下的伤害。
func record_hero_combat_mitigation(victim: Unit, amount: float) -> void:
	if not track_hero_combat_stats or amount <= 0.0 or victim == null or not is_instance_valid(victim):
		return
	if not victim.is_hero or victim.faction != Unit.FACTION_LIANG:
		return
	var received := _ensure_hero_combat_stat(victim.key, victim.display_name)
	received["taken"] = float(received["taken"]) + amount
	hero_combat_stats[victim.key] = received


func hero_combat_stat(hero_key: String) -> Dictionary:
	return hero_combat_stats.get(hero_key, {"damage": 0.0, "taken": 0.0, "kills": 0})


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
		# 友方增益光环（攻/速）——只扫网格邻近格，不再全表扫描
		if h.aura != "":
			for v in units_near(h.position, h.aura_radius):
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
				for v in units_near(h.position, sr):
					if v.faction == sfoe and not v.is_building and not v.is_resource and v.hp > 0.0 and not v.garrisoned \
							and h.position.distance_to(v.position) <= sr:
						v.aura_slow = minf(v.aura_slow, 1.0 - float(sa[0]))
			# 常驻移速光环（宋江 R·仁义之名·被动）：按 R 等级给附近友军加移速 5/10/15%
			var spa := _speed_aura_of(h)
			if not spa.is_empty():
				var spr: float = spa[1]
				for v in units_near(h.position, spr):
					if v.faction == h.faction and not v.is_building and v.hp > 0.0 and not v.garrisoned \
							and h.position.distance_to(v.position) <= spr:
						v.buff_speed = maxf(v.buff_speed, float(spa[0]))
	if tech_atk != 1.0 or hero_tech_atk != 1.0:
		for u in units:
			if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and not u.is_building:
				u.buff_atk *= (hero_tech_atk if u.is_hero else tech_atk)   # 英雄只吃基地科技；喽啰/常备军吃兵营+基地


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


## 已学的「常驻移速光环」(声明 speed_aura_ranks 的被动，如宋江 R)：返回 [速度乘子, 半径]，无则空。
func _speed_aura_of(h: Unit) -> Array:
	for s in h.ability_slots:
		if int(s["rank"]) <= 0:
			continue
		var eff: Dictionary = _abilities.get(s["id"], {}).get("effect", {})
		if eff.has("speed_aura_ranks"):
			var mult := float(_pick(eff["speed_aura_ranks"], int(s["rank"])))
			var rad := float(_abilities.get(s["id"], {}).get("radius", 170.0))
			return [mult, rad]
	return []


func _stealth_pass() -> void:
	for u in units:
		if u.is_building or u.hp <= 0.0:
			continue
		u.hidden_in_reeds = u.faction == Unit.FACTION_LIANG and not u.has_target() \
			and map.t_world(u.position) == GameMap.T.REEDS
		if not u._dying:
			if u._invis_t > 0.0:
				u.modulate.a = 0.35   # 主动隐身：己方半透可见
			elif u.hidden_in_reeds:
				u.modulate.a = 0.55
			else:
				u.modulate.a = 1.0


## 敌方英雄自动施放技能。遍历全部技能槽(Q/W/E/R)：交战中就按招式智能起手——
## 指向型技能瞄准最近的梁山兵，范围攻击需附近有敌，自/友增益(鼓舞/死战)交战即放。
## 每帧每将最多起手一招（靠施法抬手 windup 自然错开 QWER，不会一帧全倒出来）。
func _enemy_ability_pass() -> void:
	for u in units:
		if not is_instance_valid(u) or u.faction != Unit.FACTION_GUAN or u.hp <= 0.0 or u.is_building:
			continue
		if u.is_hero and u.skill_points > 0:
			_auto_learn(u)   # 1v1 敌将 1 级出场吃经验升级 → 自动加点（与玩家托管同一套加点序）
		if u.slot_count() <= 0 or u._cast_t > 0.0:   # 没技能槽 / 正在抬手 → 跳过
			continue
		var engaged: bool = u.has_target()
		for i in range(u.slot_count()):
			if not u.slot_ready(i):
				continue
			var ad: Dictionary = _abilities.get(String(u.ability_slots[i]["id"]), {})
			if ad.is_empty():
				continue
			var r: float = float(ad.get("radius", 100.0))
			var lp: Vector2 = u.position
			var eff: Dictionary = ad.get("effect", {})
			if String(eff.get("kind", "")) == "ward" and String(eff.get("ward_mode", "")) == "banner":
				# 敌方宋江同样把旗插在自己的受压阵线，而不是按通用指向技塞到梁山单位脚下。
				lp = _best_banner_pos(u.faction, float(eff.get("ward_radius", r)), 190.0)
				if lp == Vector2.INF or u.position.distance_to(lp) > 560.0:
					continue
				_begin_cast(u, i, lp)
				break
			if bool(ad.get("targeted", false)):
				# 远程指向技能：敌人一进施法距离就先手放，不必等交战——修「敌将被风筝在射程外全程哑火」。
				# 无施法距离上限的（全图豁免类）仍要求已交战，免得敌将一出生就隔半张图开大。
				var fp := _nearest_foe_pos(u.position, u.faction)
				if fp == Vector2.INF:
					continue
				var d: float = u.position.distance_to(fp)
				var rng := ability_cast_range(u, ad)
				if rng == INF:
					if not engaged or d > maxf(r, u.aggro_range):
						continue
				elif d > rng:
					continue
				lp = fp
			else:
				if not engaged:
					continue   # 自身/范围类仍要求已交战（贴身才有意义）
				var kind := String(ad.get("effect", {}).get("kind", ""))
				var buff := kind in ["rally", "haste", "self_buff", "rally_heroes", "drunk_buff", "drunk_god"]
				if not buff and not _foe_within(u.position, r, u.faction):
					continue   # 范围攻击但附近没敌 → 不放
			_begin_cast(u, i, lp)
			break


## 在 pos 半径 r 内是否有 my_fac 的敌方作战单位（供敌将范围技能起手判定）。
func _foe_within(pos: Vector2, r: float, my_fac: int) -> bool:
	for v in units_near(pos, r):
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
		if u.manual_order_active or u.manual_order_t > 0.0:
			continue   # 玩家刚亲自下过令：保护期内托管不插手（执行完会提前解除）
		if String(u.key) == "hua_rong" and u.hua_lock_active() and target_visible_to(u, u._hua_lock_target):
			continue   # E 的五次跨距锁定普攻正在执行：托管不能用走位/换目标把它中途覆盖
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
	# 弱托管也走花荣新单体逻辑：危险时先向外 Q；E/R 只点高价值目标，R 优先于 E。
	if String(u.key) == "hua_rong" and fp != Vector2.INF:
		if u.slot_ready(0) and u.hp / maxf(u.max_hp, 1.0) < 0.45 and dfp <= 160.0:
			var away_dir := u.position - fp
			if away_dir.length() < 1.0:
				away_dir = Vector2(-1.0 if u.face_left else 1.0, 0.0)
			_begin_cast(u, 0, u.position + away_dir.normalized() * 330.0)
			return
		for hs in [3, 2]:
			if not u.slot_ready(hs):
				continue
			var had: Dictionary = _abilities.get(String(u.ability_slots[hs]["id"]), {})
			var hreach := INF if hs == 2 else minf(WEAK_GLOBAL, ability_cast_range(u, had))
			var high := _hua_high_value_target(u, hreach)
			if high != null:
				_begin_cast(u, hs, high.position, high)
				return
	for i in range(u.slot_count()):
		if not u.slot_ready(i):
			continue
		var ad: Dictionary = _abilities.get(String(u.ability_slots[i]["id"]), {})
		if ad.is_empty():
			continue
		# 召唤类（武松驱虎 / 公孙画龙）：与防区/托管档位无关——CD 一好、场上有敌、还有名额就放，
		# 召唤物自己扑出去打（_summon_hunt_pass）。「拉到战场上」靠召唤物自行索敌，不占英雄走位。
		var eff: Dictionary = ad.get("effect", {})
		if String(u.key) == "hua_rong" and i in [0, 2, 3]:
			continue   # Q/E/R 已由上方专属决策处理；不能退回“对最近杂兵施放”
		if String(eff.get("kind", "")) == "summon":
			if fp != Vector2.INF:   # 召唤不设上限：CD 一好、场上有敌就召（虎/龙自行扑战场）
				_begin_cast(u, i, u.position)
				return
			continue
		# 忠义旗是点地友军支援技：弱托管也必须插在己方交战阵线，不能沿用“指向技瞄最近敌”的落点。
		if String(eff.get("kind", "")) == "ward" and String(eff.get("ward_mode", "")) == "banner":
			var bp := _best_banner_pos(u.faction, float(eff.get("ward_radius", ad.get("radius", 130.0))), 190.0)
			if bp != Vector2.INF and u.position.distance_to(bp) <= WEAK_GLOBAL:
				_begin_cast(u, i, bp)
				return
			continue
		# 超远支援技能（weak_global，如花荣箭雨/定身、宋江/吴用火攻）弱托管下仍全屏支援，无视防区
		var reach: float = WEAK_GLOBAL if bool(ad.get("weak_global", false)) else leash
		reach = minf(reach, ability_cast_range(u, ad))   # 不越施法距离硬放（放出去也会被钳短落空）
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
		elif _full_auto() and u.faction == Unit.FACTION_LIANG:
			# 没敌人时别窝在基地口堆着（卡住兵/虎）→ 去前线集结点待命
			var fl := _eco_frontline()
			if u.position.distance_to(fl) > 160.0:
				u.order_amove(fl)


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
## 默认：先抢大招，再 Q/W/E。宋江特例：先学忠义双旗(W) → 火攻(E) → 大招 → Q。
func _learn_order(h: Unit) -> Array:
	var last := h.slot_count() - 1
	match String(h.key):
		"song_jiang": return [1, 2, last, 0]   # 忠义双旗(song_banner, W=1) 优先 → 火攻(E=2) → 大招 → Q
		"hua_rong": return [1, last, 2, 0]      # W 先稳清线；能学 R 就抢，随后单体 E，Q 最后
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


## 全托管·非守家英雄是否「该出手」：身边有敌(260)就打；否则只在敌人已推进到防线内(离聚义厅≤HERO_FRONT_LEASH)
## 才迎上去——避免战场空了还独自冲到敌方出生点被 ×3 群殴。
const HERO_FRONT_LEASH := 820.0   # 英雄迎敌半径(以聚义厅为心，≈26 格)：敌人进了这圈才主动压上(依塔而战·前压)
func _hero_engage_ok(u: Unit) -> bool:
	if _foe_within(u.position, maxf(u.aggro_range, 260.0), u.faction):
		return true
	var base := main_base(u.faction)
	if base == null:
		return true
	var nf := _nearest_foe_pos(u.position, u.faction)
	if nf == Vector2.INF:
		return false
	return base.position.distance_to(nf) <= HERO_FRONT_LEASH


const ECO_LANE_TRANSFER_DANGER := 130.0   # 跨路调兵时若已被贴脸，先解决眼前威胁再走，避免转身白挨打


## 全托管英雄分路调度。返回 true 表示本拍已接管（调路/去锚点/原地待命），不再进入个人战术脑。
## 仅 _full_auto() 调用：弱托管和手动档完全不走这里；玩家手动命令也已在上层过滤。
func _eco_rebalance_hero(u: Unit) -> bool:
	var state := _eco_lane_runtime_state()
	var lanes: Array = state.get("lanes", [])
	if lanes.is_empty():
		# 非三路关卡沿用原来的统一塔线，不改变其它模式的托管行为。
		if not _hero_engage_ok(u):
			var hold := _eco_hold_line()
			if u.position.distance_to(hold) > 140.0:
				_ai_move(u, hold)
			return true
		return false
	var pressure: Array = state.get("pressure", [])
	var assignments: Dictionary = state.get("assignments", {})
	var li := int(assignments.get(u.get_instance_id(), _eco_nearest_lane(u.position, lanes)))
	if li < 0:
		return false
	var anchor: Vector2 = lanes[li]
	var total := 0.0
	for p in pressure:
		total += float(p)
	# 无敌时三路均匀前出待命；不是把公孙胜单独钉回聚义厅。
	if total <= 0.0:
		if not _hero_engage_ok(u):
			if u.position.distance_to(anchor) > 140.0:
				_ai_move(u, anchor)
			return true
		return false
	# 压力变化后只调走“当前路线超额”的英雄。真正贴脸或残血时先让个人战术脑保命/清敌，脱身后再换路。
	var here := _eco_nearest_lane(u.position, lanes)
	var healthy := u.hp / maxf(u.max_hp, 1.0) > 0.45
	if here != li and float(pressure[li]) > 0.0 and healthy \
			and not _foe_within(u.position, ECO_LANE_TRANSFER_DANGER, u.faction):
		if u.stance != Unit.STANCE_AGGRO:
			u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position
		_ai_move(u, anchor)   # 换线用普通移动，避免被沿途零散敌军反复勾停
		return true
	# 敌军尚在远端时先到自己路线的前置锚点，等进入防线再由各英雄大脑迎击。
	if not _hero_engage_ok(u):
		if u.position.distance_to(anchor) > 140.0:
			_ai_move(u, anchor)
		return true
	return false


## 回身秒杀贴脸弱敌：被一两个能轻松砍死的近敌贴身追打时 → 直接回身普攻它，不绕去远处目标、不空等技能。
## 解决「被一个小兵追着砍、要等半天才放个技能、其实回头一刀就砍死」。成群敌人(>2)交给脑放技能/AoE。
func _kill_close_gnat(u: Unit) -> bool:
	if u.hp / maxf(u.max_hp, 1.0) <= 0.25:
		return false   # 残血走撤退脑，不恋战
	if _foe_count_within(u.position, u.aggro_range, u.faction) > 2:
		return false   # 成群敌人交给脑(放技能/AoE)，这里只清一两个贴脸小兵
	var best: Unit = null
	var best_d := INF
	var reach: float = u.atk_range + u.radius + 60.0   # 贴脸/一两步内
	for v in units:
		if not (is_instance_valid(v) and v.faction != u.faction and not v.is_building \
				and not v.is_resource and not v.garrisoned and not v.is_captive and v.hp > 0.0):
			continue
		var d := u.position.distance_to(v.position)
		if d <= reach and d < best_d:
			best = v
			best_d = d
	if best == null:
		return false
	var my_dps: float = u.atk * maxf(u.buff_atk, 0.1) / maxf(u.atk_cd, 0.3)
	if best.hp > my_dps * 2.0:
		return false   # 不是一两刀能解决的(精锐/厚血) → 交给脑正常应对
	if u._target != best:   # 回身锁定这个贴脸小兵，普攻砍死
		if u.stance != Unit.STANCE_AGGRO:
			u.set_stance(Unit.STANCE_AGGRO)
		u._home = u.position
		u.order_attack(best)
	return true


func _auto_micro_hero(u: Unit) -> void:
	if _kill_close_gnat(u):
		return   # 贴脸弱敌优先回身砍死，别绕远/空等技能
	# 全托管统一进入动态分路：公孙胜不再专职守家；敌多守少的路线自动多派英雄。
	if _full_auto() and _eco_rebalance_hero(u):
		return
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
		var eff: Dictionary = ad.get("effect", {})
		var lp: Vector2 = u.position
		# 通用托管遇到旗阵类技能时，也必须插在己方受压阵线，不能沿用攻击型指向技的敌方落点。
		if String(eff.get("kind", "")) == "ward" and String(eff.get("ward_mode", "")) == "banner":
			lp = _best_banner_pos(u.faction, float(eff.get("ward_radius", r)), 190.0)
			if lp == Vector2.INF or u.position.distance_to(lp) > 560.0:
				continue
			_begin_cast(u, i, lp)
			break
		if bool(ad.get("targeted", false)):
			var fp := _nearest_foe_pos(u.position, u.faction)
			if fp == Vector2.INF or u.position.distance_to(fp) > maxf(r, u.aggro_range):
				continue
			lp = fp
		else:
			var kind := String(eff.get("kind", ""))
			var buff := kind in ["rally", "haste", "self_buff", "rally_heroes", "drunk_buff", "drunk_god", "summon", "shield", "atkspeed"]
			if kind == "global_nuke":
				if _nearest_foe_pos(u.position, u.faction) == Vector2.INF:
					continue   # 全图大招：场上有敌才放
			elif not buff and not _foe_within(u.position, r, u.faction):
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


## 花荣·神射手：R/E 只狙高价值单位；W 用于多人减速；Q 永远朝远离威胁方向闪，落地靠身法增益风筝。
func _brain_hua(u: Unit) -> void:
	if not is_instance_valid(u) or u.hp <= 0.0:
		return
	var hp_frac := u.hp / u.max_hp
	var nf := _nearest_foe_pos(u.position, u.faction)
	if nf == Vector2.INF:
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
	# P1 濒危优先脱身：Q 落地给 5 秒闪避/移速，绝不朝敌群方向使用。
	if hp_frac < 0.40 and dnf < 160.0 and not _brave_retaliate(u):
		if u.slot_ready(0):
			var flee_dir := u.position - nf
			if flee_dir.length() < 1.0:
				flee_dir = Vector2(-1.0 if u.face_left else 1.0, 0.0)
			var away := u.position + flee_dir.normalized() * 330.0
			if _ai_cast_slot(u, 0, away):         # 凌空闪·朝远离方向逃
				return
		if u.stance != Unit.STANCE_PASSIVE:
			u.set_stance(Unit.STANCE_PASSIVE)   # 避战，免得跑到撤退点又自动索敌回冲
		_ai_move(u, _retreat_point(u,260.0))
		return
	# P2 百步穿杨：只给高价值目标。敌将优先，其次投石车、其他攻城器、远程重火力/精锐冲阵单位。
	if u.slot_ready(3):
		var ult_tgt := _hua_high_value_target(u, 760.0 * _hero_rb(u))
		if ult_tgt != null and _ai_cast_slot(u, 3, ult_tgt.position, ult_tgt):
			return
	# P3 定身神箭：全图可见范围找高价值目标；命中后 Unit 会完成五次跨距锁定平攻，托管期间不改令。
	if u.slot_ready(2):
		var pin_tgt := _hua_high_value_target(u, INF)
		if pin_tgt != null and _ai_cast_slot(u, 2, pin_tgt.position, pin_tgt):
			return
	# P4 健康时被普通近战贴脸：E/R 不浪费给杂兵，改用 Q 拉开并吃满落地身法。
	if melee_threat and u.slot_ready(0):
		var cen := _foe_centroid_within(u.position, 200.0, u.faction)
		var fromp: Vector2 = cen if cen != Vector2.INF else nf
		var kite_dir := u.position - fromp
		if kite_dir.length() < 1.0:
			kite_dir = Vector2(-1.0 if u.face_left else 1.0, 0.0)
		if _ai_cast_slot(u, 0, u.position + kite_dir.normalized() * 330.0):
			return
	# P5 箭雨：优先覆盖最密敌群；新增 50% 减速用于稳线，没高价值目标时也可压住单个来敌。
	if u.slot_ready(1):
		var cc := _densest_foe_pos(u.faction, 100.0)
		if cc == Vector2.INF or u.position.distance_to(cc) > 520.0:
			cc = nf
		if cc != Vector2.INF and u.position.distance_to(cc) <= 520.0:
			if _ai_cast_slot(u, 1, cc):
				return
	# P6 默认平 A 也尽量点高价值；没有高价值才找远程脆皮，最后攻击移动压进弓程。
	var focus := _hua_high_value_target(u, maxf(320.0, u.aggro_range))
	if focus == null:
		focus = _nearest_foe_unit(u.position, u.faction, false, true)
	if focus != null and u._target == null and u.position.distance_to(focus.position) <= u.atk_range + 40.0:
		u.order_attack(focus)
		return
	_ai_push_into_range(u, nf, u.atk_range - 20.0)


## 公孙胜·法师：脆皮后排。被贴脸/残血→冰墙横在身前隔挡或撤；交战召金龙；敌成堆放黑雨。
## 全托管时与其他英雄共用动态分路；这里只负责法师自身的保命、施法和远程站位。


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
## W 在交战最密的己方阵线插忠义旗稳阵 / E 火攻砸敌群。残血贴脸→先自救再撤。
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
	# P4 W 忠义双旗：优先插在 560 内正受敌军冲击、友军最密的阵线；无交战不浪费。
	if u.slot_ready(1):
		var bp := _best_banner_pos(u.faction, 130.0, 190.0)
		if bp != Vector2.INF and u.position.distance_to(bp) <= 560.0:
			if _ai_cast_slot(u, 1, bp):
				return
	# P5 E 火攻连营（超视距·有 CD 就放：优先砸最密敌群，太远则砸最近敌，≤520）
	if u.slot_ready(2):
		var fp := _densest_foe_pos(u.faction, 100.0)
		if fp == Vector2.INF or u.position.distance_to(fp) > 520.0:
			fp = _nearest_foe_pos(u.position, u.faction)
		if fp != Vector2.INF and u.position.distance_to(fp) <= 520.0:
			if _ai_cast_slot(u, 2, fp):
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


## ---------- 空间网格（邻近查询加速：把分离/光环/索敌从 O(N²) 降到 O(N·k)） ----------

## 每物理帧重建一次：把所有存活(未驻军)单位按 GRID_CELL 分桶；顺带统计机动单位数。
func _grid_build() -> void:
	_grid.clear()
	_mob_grid.clear()
	_body_grid_liang.clear()
	_body_grid_guan.clear()
	_focus_counts.clear()
	if camera != null:
		var half: Vector2 = get_viewport().get_visible_rect().size * 0.5 / camera.zoom
		_unit_draw_rect = Rect2(camera.position - half, half * 2.0).grow(120.0)
	var mob := 0
	for u in units:
		if not is_instance_valid(u):
			continue
		var render_visible: bool = u.fog_visible and not u.garrisoned \
				and (not _lite_fx or _unit_draw_rect.has_point(to_screen(u.position)))
		if u.visible != render_visible:
			if render_visible:
				u.queue_redraw()
			u.visible = render_visible
		# 等距深度序：屏幕深度 = (x+y)（本作 ISO 投影 screen_y=(x+y)/2）。y_sort 的纯 y 轴在斜投影下会排错——
		# 单位站在建筑东南侧被整个盖住。每帧顺路回填 z_index（含建筑/资源/废墟，靠后=靠前景=盖住身后）。
		u.z_index = clampi(1 + int((u.position.x + u.position.y) * 0.5), 1, 3400)
		if u.hp <= 0.0 or u.garrisoned or u.is_resource:
			continue   # 资源点(金矿/林木)从不是分离/索敌/光环目标 → 不入网格，免得林边把桶撑大拖慢邻近查询
		var k := Vector2i(int(floor(u.position.x / GRID_CELL)), int(floor(u.position.y / GRID_CELL)))
		if not u.is_building:
			mob += 1
			if _mob_grid.has(k):
				_mob_grid[k].append(u)
			else:
				_mob_grid[k] = [u]
			var body_grid: Dictionary = _body_grid_liang if u.faction == Unit.FACTION_LIANG else _body_grid_guan
			if body_grid.has(k):
				body_grid[k].append(u)
			else:
				body_grid[k] = [u]
			var ft = u._target   # 目标可能已在同帧释放；先以 Variant 接住，再做实例有效性检查。
			if ft != null and is_instance_valid(ft):   # 顺路统计「谁被几人锁定」，索敌打分 O(1) 查——别在打分里逐目标扫邻格
				var fid: int = ft.get_instance_id()
				_focus_counts[fid] = int(_focus_counts.get(fid, 0)) + 1
		if _grid.has(k):
			_grid[k].append(u)
		else:
			_grid[k] = [u]
	_mob_count = mob
	_lite_fx = mob > 90
	_impact_fx_frame = 0
	_damage_fx_frame = 0


func unit_visual_active(world_pos: Vector2) -> bool:
	return not _lite_fx or _unit_draw_rect.has_point(to_screen(world_pos))


## 返回 pos 半径 radius 内(按网格粗筛、含相邻格)的候选单位；调用方自行做精确距离判定。
func units_near(pos: Vector2, radius: float) -> Array:
	if _grid.is_empty():
		return units   # 网格尚未构建(自检/首帧)→退回全表，正确性优先(调用方有精确距离判定)
	var out: Array = []
	var rr := int(ceil(radius / GRID_CELL))
	var cx := int(floor(pos.x / GRID_CELL))
	var cy := int(floor(pos.y / GRID_CELL))
	for gy in range(cy - rr, cy + rr + 1):
		for gx in range(cx - rr, cx + rr + 1):
			var k := Vector2i(gx, gy)
			if _grid.has(k):
				out.append_array(_grid[k])
	return out


## 轻量身体阻挡：敌对机动单位不能互相穿身；友军仍交给软分离，避免大编队堵死。
func can_unit_step(mover: Unit, next: Vector2) -> bool:
	if mover == null or not is_instance_valid(mover):
		return false
	if _grid.is_empty():
		for other in units:   # 首帧/自检兜底；正常物理帧都走下方零分配网格查询。
			if other == mover or not is_instance_valid(other) or other.hp <= 0.0 or other.garrisoned \
					or other.is_building or other.is_resource or other.faction == mover.faction:
				continue
			var diff: Vector2 = next - other.position
			var min_d: float = mover.radius + other.radius + 2.0
			if diff.length_squared() < min_d * min_d:
				return false
		return true
	var blockers: Dictionary = _body_grid_guan if mover.faction == Unit.FACTION_LIANG else _body_grid_liang
	if blockers.is_empty():
		return true
	var radius_q := mover.radius + 34.0
	var rr := int(ceil(radius_q / GRID_CELL))
	var cx := int(floor(next.x / GRID_CELL))
	var cy := int(floor(next.y / GRID_CELL))
	for gy in range(cy - rr, cy + rr + 1):
		for gx in range(cx - rr, cx + rr + 1):
			var bucket: Variant = blockers.get(Vector2i(gx, gy))
			if bucket == null:
				continue
			for other in bucket:
				if not is_instance_valid(other) or other.hp <= 0.0 or other.garrisoned:
					continue
				var diff: Vector2 = next - other.position
				var min_d: float = mover.radius + other.radius + 2.0
				if diff.length_squared() < min_d * min_d:
					return false
	return true


func _separation_pass(_delta: float) -> void:
	# 分离是软约束：常规规模逐帧；超过 320 名机动单位后分三组轮询（每组 20Hz）。
	# 位移/攻击仍是 60Hz，这里只给每对重叠单位隔几帧做一次位置校正。
	_sep_phase = (_sep_phase + 1) % 3
	var stagger := _mob_count > 320
	for a: Unit in units:
		if a.is_building or a.is_resource or a.hp <= 0.0 or a.garrisoned:
			continue
		var aid := a.get_instance_id()
		if stagger and aid % 3 != _sep_phase:
			continue
		var a_mv := a._state == Unit.ST_MOVE or a._state == Unit.ST_AMOVE or a._state == Unit.ST_CHASE
		var a_phase := _gold_phasing(a)
		var cx := int(floor(a.position.x / GRID_CELL))
		var cy := int(floor(a.position.y / GRID_CELL))
		# 所有机动单位半径 <=20，两身体的分离距离 < GRID_CELL，查 3×3 桶足够。
		for gy in range(cy - 1, cy + 2):
			for gx in range(cx - 1, cx + 2):
				var bucket_v: Variant = _mob_grid.get(Vector2i(gx, gy))
				if bucket_v == null:
					continue
				var bucket: Array = bucket_v
				for b: Unit in bucket:
					if b.get_instance_id() <= aid:
						continue   # 每对只处理一次；同时跳过自身
					if a_phase and _gold_phasing(b):
						continue
					var diff := a.position - b.position
					var d2 := diff.length_squared()
					var min_d := a.radius + b.radius + 2.0
					if d2 >= min_d * min_d or d2 <= 0.0001:
						continue
					var d := sqrt(d2)
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
	# 桌面端纯键鼠：丢弃一切触摸事件（不切触屏布局、不复位框选/施法）。触摸经鼠标模拟仍当点击用。
	if not _allow_touch and (event is InputEventScreenTouch or event is InputEventScreenDrag):
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
				if _trap_armed != "":
					if _touch_mode:
						_dragging = true
						_drag_from = p
						_drag_cur = p
						_box_mode = false
						_panning = false
						_press_ms = Time.get_ticks_msec()
						overlay.queue_redraw()
					else:
						_try_place_trap(p)
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
				if _patrol_armed:
					_order_patrol_at(p)
					_disarm_patrol()
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
				elif _trap_armed != "" and _touch_mode:
					# 触屏：松手 → 在虚影处布置陷阱（无效则保留 armed，可重选址或点「取消」）
					_try_place_trap(_drag_cur)
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
			if _trap_armed != "":
				_cancel_trap()
				return
			if _ability_armed != "":
				_disarm_ability()
				return
			if _amove_armed:
				_disarm_amove()
				return
			if _patrol_armed:
				_disarm_patrol()
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
		elif kc >= KEY_F1 and kc <= KEY_F4 and (event.ctrl_pressed or event.meta_pressed):
			_save_camera_loc(kc - KEY_F1 + 1)
		elif kc >= KEY_F1 and kc <= KEY_F4 and event.shift_pressed:
			_jump_camera_loc(kc - KEY_F1 + 1)
		elif Settings.key_matches(event, "alert"):
			_jump_alert_or_home()
		elif Settings.key_matches(event, "amove"):
			arm_amove()
		elif Settings.key_matches(event, "stop"):
			_order_stop()
		elif Settings.key_matches(event, "hold"):
			_order_hold_position()
		elif Settings.key_matches(event, "patrol"):
			arm_patrol()
		elif Settings.key_matches(event, "stance"):
			_cycle_stance()
		elif Settings.key_matches(event, "auto"):
			if hud != null and int(Settings.auto_micro_level) > 0:   # 「无托管」档关闭 T 热键
				if event.shift_pressed:
					hud._toggle_all_auto()        # Shift+T：全军托管
				else:
					hud.toggle_auto_selected()    # T：托管选中英雄（单个 / 编队）
		elif Settings.key_matches(event, "demolish") or (Settings.key_for("demolish") == KEY_DELETE and kc == KEY_BACKSPACE):
			delete_selected(event.shift_pressed)   # 拆除选中己方单位/建筑（Mac 上 Delete 即 Backspace；Shift 跳过确认）
		elif Settings.key_matches(event, "command_0"):
			_command_hotkey(0)
		elif Settings.key_matches(event, "command_1"):
			_command_hotkey(1)
		elif Settings.key_matches(event, "command_2"):
			_command_hotkey(2)
		elif Settings.key_matches(event, "command_3"):
			_command_hotkey(3)
		elif Settings.key_matches(event, "select_army") and not event.shift_pressed and not event.ctrl_pressed and not event.meta_pressed:
			select_all_army()
		elif kc >= KEY_F1 and kc <= KEY_F8 and kc != KEY_F2:
			var hidx := kc - KEY_F1
			if kc > KEY_F2:
				hidx -= 1   # F2 留给全军；F3 起顺延选择后续英雄
			_select_hero_by_index(hidx)
		elif Settings.key_matches(event, "subgroup"):
			_cycle_subgroup()
		elif Settings.key_matches(event, "idle_worker") \
				or (Settings.key_for("idle_worker") == KEY_PERIOD and kc == KEY_COMMA):
			_cycle_idle_worker()
		elif kc == KEY_ESCAPE:
			if is_armed():
				cancel_armed()
			elif economy and _worker_cat != "":
				_worker_back()   # 先退回命令卡根页，再按 Esc 才弹暂停菜单
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
	if _ability_armed != "" or _amove_armed or _patrol_armed or _repair_armed or _garrison_armed or _build_armed != "" or _trap_armed != "":
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


func _disarm_patrol() -> void:
	_patrol_armed = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## 武装攻击移动（A 键与触屏「攻击」按钮共用）：随后点地即攻击移动。
func arm_amove() -> void:
	if selection.is_empty():
		return
	_disarm_patrol()
	_disarm_ability()
	_cancel_build()
	_amove_armed = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func arm_patrol() -> void:
	if _selected_movers().filter(func(u: Unit) -> bool: return not u.is_worker).is_empty():
		return
	cancel_armed()
	_patrol_armed = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	msg("巡逻：左键选择另一端", 1.4)


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
	_disarm_patrol()
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
	_disarm_patrol()
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
	_disarm_patrol()
	_disarm_repair()
	_disarm_ability()
	_disarm_garrison()
	_cancel_build()
	_cancel_trap()


## 某编队当前存活成员数（触屏编队 chip 用来判断是否点亮）
func group_size(n: int) -> int:
	if not _groups.has(n):
		return 0
	return (_groups[n] as Array).filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0).size()


## 是否处于待指向态（触屏「取消」键据此显隐）
func is_armed() -> bool:
	return _amove_armed or _patrol_armed or _repair_armed or _garrison_armed or _ability_armed != "" or _build_armed != "" or _trap_armed != ""


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
		if u.faction != Unit.FACTION_LIANG or u.hp <= 0.0 or u.is_building or u.garrisoned:
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= u.radius + _click_tol(10.0) and d < best_d:
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
	if best != null:
		if additive and new_sel.has(best):
			new_sel.erase(best)
		elif not new_sel.has(best):
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
	# 先收集框内己方可选单位
	var hits: Array = []
	for u in units:
		if u.faction != Unit.FACTION_LIANG or u.is_building or u.garrisoned:
			continue
		if rect.has_point(to_screen(u.position)):
			hits.append(u)
	# 框到空地（框内无单位）：保持当前选择不变，不清空（与「单击空地不取消选择」一致）
	if hits.is_empty():
		return
	var new_sel: Array = selection.duplicate() if additive else []
	for u in hits:
		if not new_sel.has(u):
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


func cast_ability(caster: Unit, slot := 0, show_blocked := false) -> void:
	if caster == null or not is_instance_valid(caster) or slot < 0 or slot >= caster.slot_count():
		return
	if not caster.slot_ready(slot):
		if show_blocked:
			_show_cast_blocked(caster, slot)
		return
	var aid: String = caster.ability_slots[slot]["id"]
	var ad: Dictionary = _abilities[aid]
	if ad["targeted"]:
		_disarm_amove()
		_disarm_patrol()
		_cancel_build()
		_ability_caster = caster
		_ability_armed = aid
		_ability_slot = slot
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		var aim_hint := "左键选择目标位置"
		if String(ad.get("target", "point")) == "unit":
			aim_hint = "左键点选目标单位（超射程会自动走近再放）"
		hud.show_message("%s · %s：%s" % [caster.display_name, ad["name"], aim_hint], 2.5)
	else:
		_begin_cast(caster, slot, caster.position)


## 玩家从命令卡/触屏技能轨快速连点时给出真实阻塞原因。多充能技能第一发抬手期间
## 第二次点击不是“没能量”，只是上一发尚未结算；以前这里静默 return，容易误判成只有1点充能。
func _show_cast_blocked(caster: Unit, slot: int) -> void:
	if hud == null or caster == null or not is_instance_valid(caster) or slot < 0 or slot >= caster.slot_count():
		return
	var text := "暂时无法施放"
	if is_cast_pending(caster, slot) or caster._cast_t > 0.0:
		text = "上一发仍在施法，请稍候"
	elif caster.slot_max_charges(slot) > 0 and caster.slot_charges(slot) <= 0:
		text = "能量恢复中"
	elif float(caster.ability_slots[slot].get("cd_t", 0.0)) > 0.0:
		text = "技能冷却中"
	elif caster._silence_t > 0.0:
		text = "沉默中，无法施法"
	elif caster._stun_t > 0.0:
		text = "眩晕中，无法施法"
	hud.show_message("%s：%s" % [caster.display_name, text], 1.2)


## QWER：对「活动英雄」的第 slot 个技能（学习/施放/提示）
## QWER 命令热键：按活动单位上下文分派（英雄技能 / 工人建造 / 建筑训练）
func _command_hotkey(slot: int) -> void:
	var au := active_unit()
	if au == null:
		return
	if au.is_hero and au.slot_count() > 0:
		_cast_ability_slot(slot)
	elif economy and au.is_worker:
		_worker_hotkey(slot)   # 分类页分派（建筑/塔/陷阱/维修）
	elif economy and au.is_building and not au.is_constructing and au.setup_def.has("produces"):
		var tm := train_menu(au)
		if slot < tm.size():
			queue_train_multi(au, String(tm[slot]["key"]))
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
		_show_cast_blocked(h, slot)


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
	if caster == null or not is_instance_valid(caster) or slot >= caster.slot_count() \
			or caster.ability_slots[slot]["id"] != ab or not caster.slot_ready(slot):
		_disarm_ability()
		return
	var ad: Dictionary = _abilities.get(ab, {})
	if String(ad.get("target", "point")) == "unit":
		# 单体指向：必须点到一个合法单位；点空地保持待指向态（可再点/右键取消）
		var tu := _armed_unit_at(p, String(ad.get("unit_team", "enemy")))
		if tu == null:
			hud.show_message("请点选一个目标单位（右键取消）", 1.2)
			return
		if bool(ad.get("combat_only", false)) and (tu.is_building or tu.is_resource or tu.is_captive):
			hud.show_message("该技能只能选择作战单位", 1.2)
			return
		_disarm_ability()
		var rng := ability_cast_range(caster, ad)
		if rng != INF and caster.position.distance_to(tu.position) > rng:
			_queue_walk_cast(caster, slot, tu)   # 超出射程：走近了自动放（DOTA式）
		else:
			_begin_cast(caster, slot, tu.position, tu)
		return
	_disarm_ability()
	var lp := to_logic(p)
	var rng := ability_cast_range(caster, ad)
	if rng != INF and caster.position.distance_to(lp) > rng:
		_queue_walk_cast_point(caster, slot, lp)   # 保留玩家原落点，走进射程后再放
	else:
		_begin_cast(caster, slot, lp)


## 待指向态下点选目标单位：按 unit_team 决定可点敌方（迷雾过滤）/己方/任意。
func _armed_unit_at(p: Vector2, team: String) -> Unit:
	if team == "enemy":
		return _enemy_at(p)
	if team == "ally":
		return _unit_at(p)
	var e := _enemy_at(p)
	return e if e != null else _unit_at(p)


func _disarm_ability() -> void:
	_ability_armed = ""
	_ability_caster = null
	_ability_slot = 0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func cancel_pending_cast(caster: Unit) -> void:
	if caster == null or _pending_casts.is_empty():
		return
	_pending_casts = _pending_casts.filter(func(pc: Dictionary) -> bool: return pc.get("caster") != caster)


## HUD 查询：某个技能是否正在抬手待结算。这与 cd_t 是两个独立状态，不能把抬手误画成「冷却 0」。
func is_cast_pending(caster: Unit, slot: int) -> bool:
	if caster == null or not is_instance_valid(caster):
		return false
	for pc in _pending_casts:
		if pc.get("caster") == caster and int(pc.get("slot", -1)) == slot \
				and int(pc.get("serial", -1)) == caster._cast_serial:
			return true
	return false


## 花荣·切刀/挂弓：在弓与刀之间切换（命令卡按钮触发）。
func toggle_hero_melee(hero) -> void:
	if hero == null or not is_instance_valid(hero) or not hero.can_melee_switch:
		return
	hero.toggle_melee()
	Sfx.play("click")
	hud.show_message("%s · %s" % [hero.display_name, "拔刀近战（+10%% 吸血）" if hero.melee_mode else "挂弓远射"], 1.8)
	hud.refresh_command()   # 刷新命令卡，更新「持刀/持弓」按钮态


## 指向技能施法距离：点目标 AoE 不再全图可放。基础 380px + 技能自身半径（越大的招允许放得越远），
## effect.cast_range 可显式覆写。豁免（返回 INF=全图）：global_nuke 全图轰本来就是设计；
## 宋江/花荣定位就是超视距支援（保持全图）；blink/charge/blink_shot/ice_wall 自带射程/长度自限。
## 钳制沿「施法者→点击点」射线收短：方向型技能（line/fissure/fire_line 等）方向不变，行为零差异。
const DEFAULT_CAST_RANGE := 380.0
const CAST_RANGE_EXEMPT := ["global_nuke", "blink", "charge", "blink_shot", "ice_wall"]
const CAST_RANGE_FREE_HEROES := ["song_jiang", "hua_rong"]

func ability_cast_range(caster: Unit, ad: Dictionary) -> float:
	if not bool(ad.get("targeted", false)):
		return INF
	var eff: Dictionary = ad.get("effect", {})
	var kind := String(eff.get("active_kind", eff.get("kind", "")))
	if kind in CAST_RANGE_EXEMPT:
		return INF
	# 单体狙击类即使属于超远支援英雄，也以技能明写的射程为准；其余花荣/宋江技能保持原全图规则。
	if eff.has("cast_range"):
		return float(eff["cast_range"]) * _hero_rb(caster)
	if caster != null and is_instance_valid(caster) and String(caster.key) in CAST_RANGE_FREE_HEROES:
		return INF
	var base: float = DEFAULT_CAST_RANGE + float(ad.get("radius", 0.0))
	return base * _hero_rb(caster)


func _clamp_cast_point(caster: Unit, ad: Dictionary, lp: Vector2) -> Vector2:
	var rng := ability_cast_range(caster, ad)
	if rng == INF:
		return lp
	var off := lp - caster.position
	if off.length() <= rng:
		return lp
	return caster.position + off.normalized() * rng


## 施法抬手：技能不再瞬发——先让英雄抬手蓄势 CAST_WINDUP 秒（带蓄能辉光），归零后才结算。
## 目标点 lp 在点击瞬间已锁定，抬手只是表演；抬手期间技能仍占「就绪」，靠 _cast_t>0 防连发。
func _begin_cast(caster: Unit, slot: int, lp: Vector2, tgt: Unit = null) -> void:
	if caster == null or not is_instance_valid(caster):
		return
	if caster._cast_t > 0.0:                # 已在抬手中：忽略重复触发
		return
	var aid: String = caster.ability_slots[slot]["id"]
	var ad: Dictionary = _abilities.get(aid, {})
	# 单体指向：AI/兜底路径没显式给目标时，以落点最近的敌方单位为目标（玩家路径由 _cast_armed_at 传入）
	if String(ad.get("target", "point")) == "unit" and (tgt == null or not is_instance_valid(tgt)):
		if String(ad.get("unit_team", "enemy")) != "ally":
			tgt = _nearest_foe_unit(lp, caster.faction)
	if tgt != null and is_instance_valid(tgt):
		lp = tgt.position
	var col: Color = ad.get("color", Color(0.82, 0.86, 1.0))
	if bool(ad.get("targeted", false)):
		var cast_range := ability_cast_range(caster, ad)
		if String(ad.get("target", "point")) == "unit" and tgt != null and cast_range != INF \
				and caster.position.distance_to(tgt.position) > cast_range:
			return   # 单体技能不能像点地技那样把落点钳短后仍隔空命中原目标
		lp = _clamp_cast_point(caster, ad, lp)   # 超出施法距离 → 沿射线收短到最远可放点
		caster._face_dir(lp - caster.position)   # 转身面向施法点：方向型技能抬手更自然
	var windup := float(ad.get("cast_windup", CAST_WINDUP))
	caster.begin_cast_windup(windup, col)
	_pending_casts.append({"caster": caster, "slot": slot, "lp": lp, "tgt": tgt, "serial": caster._cast_serial})
	if aid == "hua_blade" and tgt != null and is_instance_valid(tgt):
		var aim := HuaSnipeAimFx.new()   # R 的 1 秒蓄力全程可见：收束准星 + 单体瞄准线
		aim.caster = caster
		aim.target = tgt
		aim.life = windup
		aim.col = col
		fx_root.add_child(aim)
	Sfx.play("cast", -0.6, 0.05, 90)        # 抬手蓄能轻响（结算时各分支另有命中声）


## 抬手结算：每帧检查待结算队列，施法者抬手归零即真正放招（死亡/失效则丢弃）。
func _tick_pending_casts() -> void:
	if _pending_casts.is_empty():
		return
	var keep: Array = []
	for pc in _pending_casts:
		var c = pc["caster"]
		if c == null or not is_instance_valid(c) or c.hp <= 0.0:
			continue                        # 抬手途中阵亡：取消
		if int(pc.get("serial", -1)) != c._cast_serial:
			continue                        # 被控制/新指令打断，或已被下一次起手替代
		if c._cast_t > 0.0:
			keep.append(pc)                 # 仍在抬手
		else:
			var tgt = pc.get("tgt")
			if tgt != null and (not is_instance_valid(tgt) or tgt.hp <= 0.0 or tgt.garrisoned \
					or not target_visible_to(c, tgt)):
				continue
			_do_ability(c, int(pc["slot"]), pc["lp"], pc.get("tgt"))
	_pending_casts = keep


## 技能音效名：签名 id 优先，否则按 effect.kind，再退 "cast"。
## 数据化技能结算：按 effect.kind 统一处理；伤害/治疗随技能等级缩放。
## 英雄倍率改动 → 实时重算在场你方英雄属性（血量随 n 缩放，保留当前血量百分比）。CD/范围/伤害在施放时即时取值无需重算。
func _hero_boost_refresh() -> void:
	var cur: float = Campaign.hero_mult if Campaign.scale_on else 1.0
	if cur == _last_hb:
		return
	_last_hb = cur
	for u in units:
		if is_instance_valid(u) and u.is_hero and u.faction == Unit.FACTION_LIANG:
			u._recompute_hero_stats()


## 英雄倍率(改变倍率开启 + 你方英雄)：n=clamp(Campaign.hero_mult,1,3)。
## 与 Unit.hero_boost_n 同门禁：仅驻守/自定义据守/竞技场生效（修 1v1 跨模式泄漏）。
func _hero_boost_n(u: Unit) -> float:
	if u == null or not u.is_hero or u.faction != Unit.FACTION_LIANG or not Campaign.scale_on:
		return 1.0
	if not (Campaign.skirmish or Campaign.custom_defense or Campaign.arena):
		return 1.0
	return clampf(float(Campaign.hero_mult), 1.0, 3.0)


func _hero_rb(u: Unit) -> float:   # 范围(半径)倍率 1+(n-1)·0.4（n3=1.8×、面积3.24×）
	return 1.0 + (_hero_boost_n(u) - 1.0) * 0.4


func _hero_db(u: Unit) -> float:   # 伤害倍率 1+(n-1)/4
	return 1.0 + (_hero_boost_n(u) - 1.0) / 4.0


## 敌方倍率 e（改变倍率开启时；1~5）：小兵数量×e；血量×(1+(e-1)/3)、攻击×(1+(e-1)/4)。
func _enemy_e() -> float:
	return clampf(float(Campaign.enemy_mult), 1.0, 5.0) if Campaign.scale_on else 1.0


func enemy_count_mult() -> float:
	return _enemy_e()


func enemy_hp_mult() -> float:
	return 1.0 + (_enemy_e() - 1.0) / 3.0


func enemy_atk_mult() -> float:
	return 1.0 + (_enemy_e() - 1.0) / 4.0


## 给一个已落点的敌方单位按敌方倍率放大 血/攻（小兵+大将都调；数量由出兵处×e）。基/现值同步缩放，兼顾英雄重算。
func apply_enemy_scale(u: Unit) -> void:
	if not Campaign.scale_on or not is_instance_valid(u):
		return
	var hpf := enemy_hp_mult()
	var atkf := enemy_atk_mult()
	if hpf != 1.0:
		u._base_hp *= hpf
		u.max_hp *= hpf
		u.hp = u.max_hp
	if atkf != 1.0:
		u._base_atk *= atkf
		u.atk *= atkf


func _scale_num_arr(a: Array, f: float) -> Array:
	var o: Array = []
	for v in a:
		o.append(float(v) * f)
	return o


## 英雄倍率：返回按 rb(范围:radius/radius_ranks/len/width)、db(伤害:dmg/dps/dps_ranks/impact_ranks/dot_total/total)
## 缩放后的技能 def 深拷贝（不动原表、不缩 heal/slow/dur/atk 等）。rb=db=1 时原样返回（零开销）。
func _scaled_ability(ad: Dictionary, rb: float, db: float) -> Dictionary:
	if rb == 1.0 and db == 1.0:
		return ad
	var out := ad.duplicate(true)
	if out.has("radius"):
		out["radius"] = float(out["radius"]) * rb
	if out.has("radius_ranks"):
		out["radius_ranks"] = _scale_num_arr(out["radius_ranks"], rb)
	var eff: Dictionary = out.get("effect", {})
	for k in ["len", "width"]:
		if eff.has(k):
			eff[k] = float(eff[k]) * rb
	for k in ["dmg", "dps", "dot_total", "total"]:
		if eff.has(k):
			eff[k] = float(eff[k]) * db
	for k in ["dmg_ranks", "dps_ranks", "impact_ranks"]:
		if eff.has(k):
			eff[k] = _scale_num_arr(eff[k], db)
	return out


## 通用「效果骑手」结算（三轴模型的效果轴）：任何 kind 命中一个单位后调它，把 effect 里声明的
## 控制/减益一次性挂上——slow/stun/def_down/blind/silence/amp/root/disarm。新增 kind 不再复制这堆 if。
func _apply_riders(u: Unit, eff: Dictionary, rank: int, caster: Unit = null) -> void:
	if eff.get("slow", 0.0) > 0.0:
		u.apply_slow(eff["slow"], float(eff.get("slow_dur", 2.0)))
	if eff.get("stun", 0.0) > 0.0:
		u.apply_stun(eff["stun"])
	if eff.has("def_down"):
		u.apply_def_down(float(_pick(eff["def_down"], rank)), float(eff.get("def_down_dur", 8.0)))
	if eff.has("blind"):
		u.apply_blind(float(eff["blind"]))
	if eff.get("silence", 0.0) > 0.0:
		u.apply_silence(float(eff["silence"]))
	if eff.get("amp", 0.0) > 0.0:
		u.apply_dmg_amp(float(eff["amp"]), float(eff.get("amp_dur", 6.0)))
	if eff.get("root", 0.0) > 0.0:
		u.apply_root(float(eff["root"]))
	if eff.get("disarm", 0.0) > 0.0:
		u.apply_disarm(float(eff["disarm"]))
	if eff.get("taunt", 0.0) > 0.0 and caster != null and is_instance_valid(caster):
		u.apply_taunt(caster, float(eff["taunt"]))
	if String(eff.get("dispel", "")) == "buffs":
		u.dispel(true)   # 樊瑞·驱敌方增益（命中即抹掉护盾/攻增/加速/隐身）
	if eff.get("hex", 0.0) > 0.0:
		u.apply_hex(float(eff["hex"]))   # 变形术：沉默+缴械+减速的组合软控 + 小猪替身视觉


func _do_ability(caster: Unit, slot: int, lp: Vector2, tgt: Unit = null) -> void:
	if not is_instance_valid(caster) or not caster.slot_ready(slot):
		return
	var aid: String = caster.ability_slots[slot]["id"]
	var ad: Dictionary = _scaled_ability(_abilities[aid], _hero_rb(caster), _hero_db(caster))   # 英雄倍率
	if level.on_ability(self, caster, aid, lp):
		caster.slot_start_cd(slot)
		return
	var rank := int(caster.ability_slots[slot]["rank"])
	var sc := 0.6 + 0.4 * float(rank)     # rank1=1.0 rank2=1.4 rank3=1.8
	var eff: Dictionary = ad.get("effect", {})
	# 单体指向（target:"unit"）：抬手期间跟踪目标（DOTA式），结算时以目标当前位置为落点；
	# 目标在抬手途中阵亡/驻入 → 取消施放（不进 CD 不白费）。AI 的目标兜底解析在 _begin_cast。
	if tgt != null and (not is_instance_valid(tgt) or tgt.hp <= 0.0 or tgt.garrisoned):
		tgt = null
	if String(ad.get("target", "point")) == "unit":
		if tgt == null:
			return
		if bool(ad.get("combat_only", false)) and (tgt.is_building or tgt.is_resource or tgt.is_captive):
			return
		lp = tgt.position
	# 技能专属音：6 将签名音保持既有听感；其余按 id 播种合成——每个技能各有其声（同主题也彼此有别）
	if ABILITY_SFX_ID.has(aid):
		Sfx.play(ABILITY_SFX_ID[aid], 0.0, 0.05, 60)
	else:
		var _sk := String(eff.get("kind", ""))
		Sfx.play_ability(aid, String((ad.get("visual", {}) as Dictionary).get("theme", "")), String(eff.get("active_kind", _sk)))
	# 兼容旧技能数据/模组的武器切换分支；新版花荣 R 已改为 hua_snipe，不再进入这里。
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
					_apply_riders(u, eff, rank, caster)   # slow/stun/削甲/致盲/沉默/易伤/缠绕/缴械/嘲讽 一站式
					u.take_damage(dmg, caster)
					spawn_impact(u.position, true)   # 命中火花
			if eff.get("self_atk", 0.0) > 0.0:
				caster.apply_temp_atk(eff["self_atk"], eff["self_dur"])
			if eff.get("self_lifesteal", 0.0) > 0.0:
				caster.apply_lifesteal(eff["self_lifesteal"], eff["self_lifesteal_dur"])
			if eff.get("self_shield", 0.0) > 0.0:   # 索超急锋叱喝：暴喝后自披硬甲护盾
				caster.apply_shield(float(eff["self_shield"]) * sc, float(eff.get("self_shield_dur", 4.0)))
			if eff.get("amp", 0.0) > 0.0:   # 摄魂咒：一圈紫魂向落点旋拢（易伤标记画在单位身上）
				var amf := AmpCastFx.new()
				amf.position = center
				amf.rad = r
				amf.col = ad["color"]
				fx_root.add_child(amf)
		"hua_pin_target":   # 花荣 E：真正单体定身；后续五次平攻锁定该目标并无视攻击距离
			if tgt != null and is_instance_valid(tgt):
				var pin_dmg := float(_pick(eff.get("dmg_ranks", [24.0, 34.0, 43.0]), rank))
				var pin_root := float(_pick(eff.get("root_ranks", [2.0, 2.5, 3.0]), rank))
				tgt.take_damage(pin_dmg, caster)
				if tgt.hp > 0.0:
					tgt.apply_root(pin_root)
					caster.start_hua_lock(tgt, int(eff.get("lock_shots", 5)))
				var pfx := HuaTargetArrowFx.new()
				pfx.position = caster.position + Vector2(0, -10)
				pfx.end_w = tgt.position
				pfx.col = ad["color"]
				pfx.snipe = false
				pfx.lock_shots = int(eff.get("lock_shots", 5))
				fx_root.add_child(pfx)
				if tgt.hp > 0.0:
					var lock_mark := HuaLockMarkFx.new()
					lock_mark.source = caster
					lock_mark.target = tgt
					lock_mark.col = ad["color"]
					fx_root.add_child(lock_mark)
				spawn_impact(tgt.position, false)
		"hua_snipe":   # 花荣 R·百步穿杨：非敌将处决；敌将吃最大生命百分比爆发 + 5 次逐秒伤害
			if tgt != null and is_instance_valid(tgt):
				var shot_end := tgt.position
				if tgt.is_hero:
					var burst_pct := float(_pick(eff.get("hero_burst_ranks", [0.20, 0.25, 0.30]), rank))
					var dot_pct := float(_pick(eff.get("hero_dot_ranks", [0.03, 0.04, 0.05]), rank))
					tgt.take_damage(tgt.max_hp * burst_pct, caster)
					if tgt.hp > 0.0 and dot_pct > 0.0:
						var dot_dur := float(eff.get("dot_dur", 5.0))
						var dot_tick := float(eff.get("dot_tick", 1.0))
						_hua_snipe_dots.append({"target": tgt, "caster": caster,
							"t": dot_dur, "tick_t": dot_tick, "tick": dot_tick, "pct": dot_pct,
							"ticks_left": maxi(1, int(round(dot_dur / maxf(dot_tick, 0.05))))})
						var mark := HuaSnipeMarkFx.new()
						mark.target = tgt
						mark.life = dot_dur
						fx_root.add_child(mark)
				else:
					# 处决绕过护阵减伤，并把当前护盾也计入斩杀量，确保任何非敌将作战单位真正一箭毙命。
					tgt.take_damage(tgt.hp + tgt._shield + 1.0, caster, false, true)
				var sfx := HuaTargetArrowFx.new()
				sfx.position = caster.position + Vector2(0, -10)
				sfx.end_w = shot_end
				sfx.col = ad["color"]
				sfx.snipe = true
				fx_root.add_child(sfx)
				spawn_impact(shot_end, true)
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
					_apply_riders(u, eff, rank, caster)   # 21 条直线技顺带获得全套骑手（缠绕/缴械/沉默…）
					u.take_damage(float(eff["dmg"]) * sc, caster)
					spawn_impact(u.position, true)
		"blink_shot":   # 花荣 Q·凌空闪：闪现落地，获得 5 秒闪避 + 移速（旧沿路 AoE 已取消）
			var bdir := center - caster.position
			if bdir.length() < 1.0:
				bdir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
			bdir = bdir.normalized()
			var blen := minf(float(eff.get("len", r)), maxf(60.0, caster.position.distance_to(center)))
			var bhw := float(eff.get("width", 42.0)) * 0.5
			var blink_dmg := float(eff.get("dmg", 0.0))
			if blink_dmg > 0.0:   # 兼容旧数据/模组；新版花荣 Q 没有伤害字段，不再扫一路 AoE
				for u in snap:
					if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
							and _in_capsule(caster.position, bdir, blen, bhw + u.radius, u.position):
						u.take_damage(blink_dmg * sc, caster)
						spawn_impact(u.position, true)
			var bstart := caster.position
			var bend := caster.position + bdir * blen
			var bcell := map.nearest_open(map.world_to_cell(bend))
			caster.position = map.cell_to_world(bcell)
			var buff_dur := float(eff.get("buff_dur", 5.0))
			caster.apply_temp_evasion(float(_pick(eff.get("evasion_ranks", [0.30, 0.60, 0.90]), rank)), buff_dur)
			caster.apply_move_boost(float(_pick(eff.get("move_ranks", [1.30, 1.40, 1.50]), rank)), buff_dur)
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
				float(eff.get("slow", 0.0)), float(eff.get("slow_dur", 1.0)), bool(eff.get("phys_immune", false)))
			# kind 级冲刺尾迹（16 个 charge 英雄统一获得残影冲线；旧 2 个 aid 是 smite 走别处，不双份）
			var chfx := ChargeFx.new()
			chfx.position = caster.position
			chfx.rad = maxf(60.0, r)
			chfx.col = ad.get("color", Color("c0a0ff"))
			chfx.dir = -1.0 if cdir.x < 0.0 else 1.0
			fx_root.add_child(chfx)
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
			var orbit_dur := float(eff.get("dur", 3.0))
			_orbit_zones.append({"caster": caster, "foe": foe, "r": r, "t": float(eff.get("dur", 3.0)),
				"tick": float(eff.get("tick", 0.5)), "tick_t": float(eff.get("tick", 0.5)),
				"dmg": float(eff["dmg"]) * sc, "slow": float(eff.get("slow", 0.0)), "slow_dur": float(eff.get("slow_dur", 1.0))})
			if float(eff.get("self_reduction", 0.0)) > 0.0:
				caster.apply_counted_damage_reduction(float(eff["self_reduction"]), orbit_dur, -int(caster.get_instance_id()))
			var oax := OrbitAxesFx.new()
			oax.target = caster
			oax.rad = r
			oax.col = ad["color"]
			oax.life = orbit_dur
			if eff.has("orbit_art"):
				var oa := String(eff["orbit_art"])
				oax.tex = Art.item_texture(oa)   # 手绘环绕物（李逵板斧等旧图）
				if oax.tex == null:
					oax.tex = Art.dota_projectile_texture(oa)   # DOTA 批量视觉新图集
			fx_root.add_child(oax)
		"chrono":   # 林冲 R·时空封印：域内敌军定身；10Hz 续控，避免数百目标每物理帧重复完整重绘
			var cr := r
			if eff.has("radius_ranks"):
				cr = float(_pick(eff["radius_ranks"], rank))
			_chrono_zones.append({"pos": center, "r": cr, "foe": foe, "t": float(eff.get("dur", 10.0)),
				"tick": 0.1, "tick_t": 0.0})
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
		"meteor":
			_do_meteor(caster, eff, rank, center, foe)
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
		"blink":   # DOTA·闪现：朝落点闪现(限 dist)，落点可带小范围伤
			center = _do_blink(caster, eff, sc, center, r, foe, snap, ad)
		"channel":   # DOTA·引导：定身逐 tick 轰击落点区域（凌振轰天连炮）；被眩晕/沉默即止
			_begin_channel(caster, center, eff, sc, rank, ad)
		"invis":   # DOTA·主动隐身：自身隐入（不可被索敌/指向），攻击/施法破隐，破隐首击带加成
			caster.apply_invis(float(eff.get("dur", 8.0)), float(eff.get("strike_bonus", 0.0)) * sc)
		"transform":   # DOTA·变身：临时换形态（燕顺狼形/朱仝龙形）——换攻/攻速/移速/体型/染色，到期还原
			caster.apply_form(eff.get("form", {}), float(eff.get("dur", 15.0)))
		"pull":   # DOTA·钩拉：沿一线把敌人拖向施法者
			_do_pull(caster, eff, sc, center, r, foe, snap)
		"knockback":   # DOTA·击退：推离落点 + 伤害
			_do_knockback(caster, eff, sc, center, r, foe, snap)
		"global_nuke":   # DOTA·全图轰击(或仅敌方英雄)
			_do_global_nuke(caster, eff, sc, foe, snap)
		"chain_nuke":   # DOTA·弹射闪电：逐跳衰减
			_do_chain_nuke(caster, eff, sc, center, foe, snap, ad)
		"shield":   # DOTA·护盾：自身/范围友军吸收盾
			_do_shield(caster, eff, sc, r, ally, snap)
		"atkspeed":   # DOTA·攻速狂暴：自身/范围友军提速
			_do_atkspeed(caster, eff, r, ally, snap)
		"bolt":   # DOTA·单体弹：默认追踪弹（飞向目标单位）；homing:false 变体为非追踪直线弹（可走位躲开）
			if bool(eff.get("homing", true)):
				var bolt_t: Unit = tgt
				if bolt_t == null or not is_instance_valid(bolt_t) or bolt_t.hp <= 0.0:
					bolt_t = _nearest_foe_unit(center, caster.faction)
				if bolt_t != null:
					_spawn_bolt(caster, bolt_t, ad, eff, sc, rank)
			else:
				_spawn_bolt_line(caster, center, ad, eff, sc, rank)   # 直线弹按施法瞬间落点方向飞出
		"hook":   # DOTA·钩镰（方向技）：钩头贯线飞出，钩中第一个敌人拖回身前，链条全程可见
			_spawn_hook(caster, center, ad, eff, sc, rank)
		"swap":   # DOTA·换位（单体指向·敌我皆可点）：与目标瞬间互换位置
			var swap_t: Unit = tgt
			if swap_t == null or not is_instance_valid(swap_t) or swap_t.hp <= 0.0:
				swap_t = _nearest_foe_unit(center, caster.faction)
			if swap_t != null and not swap_t.is_building:
				_do_swap(caster, swap_t, ad, eff, sc, rank)
		"ward":   # DOTA·立桩：在落点插一根「桩」，原地持续脉冲（治疗友军 / 连珠射敌 / 毒射减速）
			_do_ward(caster, eff, rank, center, ally, foe, ad, slot)
		"fissure":   # DOTA·裂地：一线贯穿伤+晕，并沿线裂出一道阻路实墙（鲁智深 Q）
			_do_fissure(caster, eff, sc, center, foe, snap, ad)
		"echo":   # DOTA·回音重踏：敌越密，每个目标受创越重（鲁智深 R）
			_do_echo(caster, eff, sc, center, r, foe, snap)
		"heal_wave":   # DOTA·影波：一道波纹在敌我间往复弹跳——灼伤敌、抚愈友（安道全 E）
			_do_heal_wave(caster, eff, sc, center, ally, foe, snap, ad)
		"fire_line":   # DOTA·一线长焰：沿指向铺一条直线地火（解珍 R）
			_do_fire_line(caster, eff, rank, center, foe)
		"fire_trail":   # DOTA·火径：随身移动，沿途不断在脚下落地火（魏定国 E）
			var ft_dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 6.0))
			var ft_dps := float(_pick(eff["dps_ranks"], rank)) if eff.has("dps_ranks") else float(eff.get("dps", 16.0))
			_fire_trails.append({"caster": caster, "t": ft_dur, "drop_t": 0.0, "drop": float(eff.get("drop", 0.3)),
				"dps": ft_dps, "dot_dur": float(eff.get("patch_dur", 2.0)), "r": float(eff.get("patch_r", 46.0)), "foe": foe})
			var ff := FireflyFx.new()   # 随身飞舞的橙红萤火，存续整段火径
			ff.follow = caster
			ff.life = ft_dur
			ff.col = ad["color"]
			fx_root.add_child(ff)
	if String(eff.get("kind", "")) == "fire_dot":
		var fd_dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 5.0))
		var fd_total := (float(eff["dps"]) * fd_dur) if eff.has("dps") else (float(eff["dmg"]) * sc)
		_spawn_ground_fire(center, r, fd_total, fd_dur, caster, foe)
	if eff.has("dot_total"):   # 普通技附带地面持续伤害（如箭雨钉地续伤），不挂火焰演出，沿用本招演出
		_add_ground_dot(center, r, float(eff["dot_total"]) * sc, float(eff.get("dot_dur", 3.0)), caster, foe)
	# DOTA 批量视觉优先替换默认大光环；没有 visual 的旧技能仍走 smite 分流/通用冲击波。
	var _dota_visual_replaces := _spawn_dota_visual_fx(caster, center, r, ad, eff, cast_kind)
	var _smite_special := false
	if not _dota_visual_replaces:
		_smite_special = String(eff.get("kind", "")) == "smite" and _spawn_smite_variant_fx(center, r, eff, ad)
	if not _dota_visual_replaces and not _smite_special and cast_kind not in ["sector_nuke", "hua_pin_target", "hua_snipe"]:   # 单体神箭/狙击不画 AoE 大光环
		_spawn_ability_fx(center, r, ad["color"])
	_spawn_hero_skill_fx(aid, caster, center, ad)   # 英雄专属华丽演出（花荣箭雨/神箭…）
	if cast_kind != "invis" and caster._invis_t > 0.0:
		caster._break_invis()   # 施法（隐身技本身除外）即现形
	caster.slot_start_cd(slot)
	if caster.slot_max_charges(slot) > 0:
		var remaining := caster.slot_charges(slot)
		var maximum := caster.slot_max_charges(slot)
		var cast_label := String(ad["name"])
		if aid == "song_banner":
			# cast_seq 已在扣能量后 +1；刚刚落下的第奇数面为忠、偶数面为义。
			cast_label = "忠义双旗·%s旗" % ("忠" if caster.slot_cast_sequence(slot) % 2 == 1 else "义")
		hud.show_message("【%s】· 剩余能量 %d/%d" % [cast_label, remaining, maximum], 2.0)
	else:
		hud.show_message("【%s】" % ad["name"], 1.8)
	# 技能音已在函数开头按 id/种类播放，这里不再重复


## 点 p 是否落在「从 origin 沿 dir 长 len、半宽 hw」的胶囊带内（线形/冲锋判定共用）。
func _in_capsule(origin: Vector2, dir: Vector2, length: float, hw: float, p: Vector2) -> bool:
	var rel := p - origin
	var along := rel.dot(dir)
	if along < -hw or along > length + hw:
		return false
	var perp := absf(rel.dot(Vector2(-dir.y, dir.x)))
	return perp <= hw


## 时空封印 + 双斧回旋：每帧推进计时，按各自节拍结算范围目标。
func _zone_pass(delta: float) -> void:
	# 时空封印：10Hz 续 0.22s 晕，持续定身语义不变；施法者/友军不受影响。
	if not _chrono_zones.is_empty():
		for z in _chrono_zones:
			z["t"] = float(z["t"]) - delta
			z["tick_t"] = float(z["tick_t"]) - delta
			if float(z["tick_t"]) <= 0.0:
				z["tick_t"] = float(z["tick_t"]) + float(z["tick"])
				var zp: Vector2 = z["pos"]
				var zr: float = z["r"]
				var zfoe: int = int(z["foe"])
				for u in units_near(zp, zr):
					if is_instance_valid(u) and u.faction == zfoe and u.hp > 0.0 and not u.is_building \
							and not u.is_resource and not u.garrisoned and zp.distance_to(u.position) <= zr:
						u.apply_stun(0.22)
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
				for u in units_near(src.position, zr2):
					if is_instance_valid(u) and u.faction == zfoe2 and u.hp > 0.0 and not u.is_resource \
							and not u.garrisoned and src.position.distance_to(u.position) <= zr2:
						if float(z["slow"]) > 0.0:
							u.apply_slow(float(z["slow"]), float(z["slow_dur"]))
						u.take_damage(float(z["dmg"]), src)
						spawn_impact(u.position, false)
		_orbit_zones = _orbit_zones.filter(func(z): return float(z["t"]) > 0.0)
	# 天降陨石：滚动推进，碾过敌人吃一次冲击伤害，过处地面铺灼烧 DOT
	if not _meteor_zones.is_empty():
		for z in _meteor_zones:
			var step: float = minf(float(z["speed"]) * delta, float(z["remain"]))
			z["remain"] = float(z["remain"]) - step
			z["pos"] = Vector2(z["pos"]) + Vector2(z["dir"]) * step
			var mp: Vector2 = z["pos"]
			var mhw: float = float(z["hw"])
			var mfoe: int = int(z["foe"])
			var src = z["caster"]
			var hit: Dictionary = z["hit"]
			for u in units_near(mp, mhw + 40.0):
				if is_instance_valid(u) and u.faction == mfoe and u.hp > 0.0 and not u.is_resource and not u.garrisoned \
						and not hit.has(u.get_instance_id()) and mp.distance_to(u.position) <= mhw + u.radius:
					hit[u.get_instance_id()] = true
					u.take_damage(float(z["impact"]), src if is_instance_valid(src) else null)
					spawn_impact(u.position, true)
			# 过处地面铺火（每滚约 60px 落一处持续灼烧），用现成地火 DOT 系统
			z["trail"] = float(z["trail"]) + step
			if float(z["trail"]) >= 60.0:
				z["trail"] = 0.0
				var dd: float = float(z["dot_dur"])
				_spawn_ground_fire(mp, mhw, float(z["dps"]) * dd, dd, src if is_instance_valid(src) else null, mfoe)
		_meteor_zones = _meteor_zones.filter(func(z): return float(z["remain"]) > 0.0)


## 宋江 W·天降陨石：宋江脸前召落陨石朝指向滚出，建立滚动伤害区（碾过冲击 + 过处地火 DOT）。
func _do_meteor(caster: Unit, eff: Dictionary, rank: int, center: Vector2, foe: int) -> void:
	var dir := center - caster.position
	if dir.length() < 1.0:
		dir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	dir = dir.normalized()
	var hw := float(eff.get("width", 96.0)) * 0.5
	var llen := float(eff.get("len", 600.0))
	var rspeed := float(eff.get("roll_speed", 320.0))
	var start := caster.position + dir * (caster.radius + 40.0)   # 「脸前」一点落下
	_meteor_zones.append({"pos": start, "dir": dir, "remain": llen, "speed": rspeed, "hw": hw,
		"foe": foe, "caster": caster, "impact": float(_pick(eff["impact_ranks"], rank)),
		"dps": float(_pick(eff["dps_ranks"], rank)), "dot_dur": float(eff.get("dot_dur", 10.0)),
		"hit": {}, "trail": 999.0})   # trail 初值大 → 起手立刻先铺一处火
	var mfx := MeteorFx.new()
	mfx.start_w = start
	mfx.end_w = start + dir * llen
	mfx.rad = hw
	mfx.life = llen / maxf(rspeed, 1.0)
	mfx.col = Color("ff7a2a")
	fx_root.add_child(mfx)
	shake(5.0, start)


## ===== DOTA 式新原语结算（闪现/钩拉/击退/全图/弹射/护盾/攻速）=====
## 闪现：朝落点闪现(限 dist)，落点可带小范围伤；返回闪现后中心(供演出落点)。
func _do_blink(caster: Unit, eff: Dictionary, sc: float, center: Vector2, r: float, foe: int, snap: Array, ad: Dictionary) -> Vector2:
	var from := caster.position
	var dir := center - caster.position
	if dir.length() > 1.0:
		var dist := minf(float(eff.get("dist", 260.0)), caster.position.distance_to(center))
		var cell := map.nearest_open(map.world_to_cell(caster.position + dir.normalized() * dist))
		caster.position = map.cell_to_world(cell)
	# 双端闪（19 个 blink 英雄零演出→有）：起点残影消散 + 落点闪现绽放 + 中间流光带（复用 BlinkShotFx）
	if from.distance_to(caster.position) > 4.0:
		var bfx := BlinkShotFx.new()
		bfx.start_w = from
		bfx.end_w = caster.position
		bfx.position = caster.position
		bfx.col = ad.get("color", Color(0.62, 0.85, 1.0))
		fx_root.add_child(bfx)
	var dmg := float(eff.get("dmg", 0.0)) * sc
	if dmg > 0.0:
		for u in snap:
			if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource and not u.is_building and caster.position.distance_to(u.position) <= r:
				if eff.get("slow", 0.0) > 0.0:
					u.apply_slow(eff["slow"], eff.get("slow_dur", 1.0))
				u.take_damage(dmg, caster)
				spawn_impact(u.position, true)
	return caster.position


## 钩拉：沿 caster→落点一线把敌人拖向施法者 + 伤害(可眩晕)。
func _do_pull(caster: Unit, eff: Dictionary, sc: float, center: Vector2, r: float, foe: int, snap: Array) -> void:
	var dir := center - caster.position
	if dir.length() < 1.0:
		dir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	dir = dir.normalized()
	var llen := float(eff.get("len", r))
	var hw := float(eff.get("width", 70.0)) * 0.5
	var pull := float(eff.get("pull_dist", 120.0))
	for u in snap:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource and not u.is_building and _in_capsule(caster.position, dir, llen, hw + u.radius, u.position):
			var toc: Vector2 = caster.position - u.position
			var np: Vector2 = u.position + toc.normalized() * minf(pull, maxf(0.0, toc.length() - (caster.radius + u.radius)))
			if map.is_open_world(np):
				u.position = np
			if eff.get("stun", 0.0) > 0.0:
				u.apply_stun(eff["stun"])
			u.take_damage(float(eff.get("dmg", 0.0)) * sc, caster)
			spawn_impact(u.position, true)


## ───────────────── 技能弹道系统（bolt 追踪弹 / hook 钩镰拖回）─────────────────
## 弹道条目由 _bolt_pass 逐帧推进；BoltFx 只负责演出（位置由这里驱动），命中/落空即 free。

## 追踪弹：登记一枚飞向目标单位的弹道，命中时结算 dmg×sc + 全套骑手（目标半路死亡则落空消散）。
func _spawn_bolt(caster: Unit, tgt: Unit, ad: Dictionary, eff: Dictionary, sc: float, rank: int) -> void:
	var fx := BoltFx.new()
	fx.position = caster.position + Vector2(0, -10)
	fx.col = ad.get("color", Color(0.8, 0.85, 1.0))
	fx.art = String(eff.get("bolt_art", ""))   # 弹体皮肤：axe/poison/ice/dark/lasso，缺省=程序化光球
	fx_root.add_child(fx)
	_bolts.append({"mode": "bolt", "pos": caster.position + Vector2(0, -10), "tgt": tgt,
		"speed": float(eff.get("proj_speed", 420.0)), "eff": eff, "sc": sc, "rank": rank,
		"caster": caster, "fx": fx})


## 非追踪直线弹（可躲的技能弹）：从施法者朝落点方向直线飞出（len 上限），命中第一个敌人 → 伤害+骑手后消散；
## 飞满 len 无所获则落空——因方向在施法瞬间锁定、途中不追踪，敌人可走位闪开（张清没羽箭）。
func _spawn_bolt_line(caster: Unit, aim: Vector2, ad: Dictionary, eff: Dictionary, sc: float, rank: int) -> void:
	var dir := aim - caster.position
	if dir.length() < 1.0:
		dir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	dir = dir.normalized()
	var fx := BoltFx.new()
	fx.position = caster.position + Vector2(0, -10)
	fx.col = ad.get("color", Color(0.85, 0.85, 1.0))
	fx.art = String(eff.get("bolt_art", ""))
	fx_root.add_child(fx)
	_bolts.append({"mode": "bolt_line", "pos": caster.position + Vector2(0, -10), "dir": dir, "traveled": 0.0,
		"len": float(eff.get("len", 520.0)), "width": float(eff.get("width", 40.0)),
		"speed": float(eff.get("proj_speed", 620.0)), "eff": eff, "sc": sc, "rank": rank,
		"caster": caster, "fx": fx})


## 钩镰（方向技）：钩头沿指向贯线飞出（len 上限），钩中第一个敌人 → 拖回身前结算伤害+骑手。
func _spawn_hook(caster: Unit, at: Vector2, ad: Dictionary, eff: Dictionary, sc: float, rank: int) -> void:
	var dir := at - caster.position
	if dir.length() < 1.0:
		dir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	dir = dir.normalized()
	var fx := BoltFx.new()
	fx.position = caster.position
	fx.col = ad.get("color", Color(0.85, 0.7, 0.4))
	fx.chain = true
	fx.chain_from = caster
	fx_root.add_child(fx)
	_bolts.append({"mode": "hook_out", "pos": caster.position, "dir": dir, "traveled": 0.0,
		"len": float(eff.get("len", 300.0)), "width": float(eff.get("width", 26.0)),
		"speed": float(eff.get("proj_speed", 520.0)), "eff": eff, "sc": sc, "rank": rank,
		"caster": caster, "fx": fx})


## 换位（扈三娘·乾坤挪移）：与目标瞬间互换位置——可点敌将拖入阵，也可点袍泽换其脱险。
## 换到敌人才结算伤害+骑手；两端各留一道残光。
func _do_swap(caster: Unit, tgt: Unit, ad: Dictionary, eff: Dictionary, sc: float, rank: int) -> void:
	var pa := caster.position
	var pb := tgt.position
	caster.position = pb
	tgt.position = pa
	if tgt.faction != caster.faction:
		_apply_riders(tgt, eff, rank, caster)
		if float(eff.get("dmg", 0.0)) > 0.0:
			tgt.take_damage(float(eff["dmg"]) * sc, caster)
	for pair in [[pa, pb], [pb, pa]]:
		var s := BlinkShotFx.new()
		s.start_w = pair[0]
		s.end_w = pair[1]
		s.position = pair[1]
		s.col = ad.get("color", Color(0.62, 0.85, 1.0))
		fx_root.add_child(s)
	_reveal_fog_at(pb, 90.0, 4.0)


func _bolt_pass(delta: float) -> void:
	if _bolts.is_empty():
		return
	var keep: Array = []
	for b in _bolts:
		var fx = b["fx"]
		var caster = b["caster"]
		var alive := true
		match String(b["mode"]):
			"bolt":
				var tgt = b["tgt"]
				if tgt == null or not is_instance_valid(tgt) or tgt.hp <= 0.0 or tgt.garrisoned:
					alive = false   # 目标没了：弹道落空消散
				else:
					var to: Vector2 = tgt.position + Vector2(0, -8) - b["pos"]
					var step: float = float(b["speed"]) * delta
					if to.length() <= step + tgt.radius:
						var beff: Dictionary = b["eff"]
						_apply_riders(tgt, beff, int(b["rank"]), caster)
						if float(beff.get("dmg", 0.0)) > 0.0:
							tgt.take_damage(float(beff["dmg"]) * float(b["sc"]),
								caster if (caster != null and is_instance_valid(caster)) else null)
						spawn_impact(tgt.position, true)
						alive = false
					else:
						b["pos"] = Vector2(b["pos"]) + to.normalized() * step
			"bolt_line":   # 非追踪直线弹：沿锁定方向推进，命中第一个敌人 → 伤害+骑手后消散；飞满 len 落空
				var stepl: float = float(b["speed"]) * delta
				b["pos"] = Vector2(b["pos"]) + Vector2(b["dir"]) * stepl
				b["traveled"] = float(b["traveled"]) + stepl
				var foel := Unit.FACTION_GUAN
				if caster != null and is_instance_valid(caster) and caster.faction == Unit.FACTION_GUAN:
					foel = Unit.FACTION_LIANG
				var hwl: float = float(b["width"]) * 0.5
				var hitl: Unit = null
				for u in units_near(b["pos"], hwl + 40.0):
					if is_instance_valid(u) and u.faction == foel and u.hp > 0.0 and not u.garrisoned \
							and not u.is_building and not u.is_resource \
							and Vector2(b["pos"]).distance_to(u.position) <= hwl + u.radius:
						hitl = u
						break
				if hitl != null:
					var leff: Dictionary = b["eff"]
					_apply_riders(hitl, leff, int(b["rank"]), caster)
					if float(leff.get("dmg", 0.0)) > 0.0:
						hitl.take_damage(float(leff["dmg"]) * float(b["sc"]),
							caster if (caster != null and is_instance_valid(caster)) else null)
					spawn_impact(hitl.position, true)
					alive = false
				elif float(b["traveled"]) >= float(b["len"]):
					alive = false   # 飞满射程无所获 → 消散（被走位躲开了）
			"hook_out":
				var step2: float = float(b["speed"]) * delta
				b["pos"] = Vector2(b["pos"]) + Vector2(b["dir"]) * step2
				b["traveled"] = float(b["traveled"]) + step2
				var foe_f := Unit.FACTION_GUAN
				if caster != null and is_instance_valid(caster) and caster.faction == Unit.FACTION_GUAN:
					foe_f = Unit.FACTION_LIANG
				var hw: float = float(b["width"]) * 0.5
				var hit: Unit = null
				for u in units_near(b["pos"], hw + 40.0):
					if is_instance_valid(u) and u.faction == foe_f and u.hp > 0.0 and not u.garrisoned \
							and not u.is_building and not u.is_resource \
							and Vector2(b["pos"]).distance_to(u.position) <= hw + u.radius:
						hit = u
						break
				if hit != null and caster != null and is_instance_valid(caster):
					b["mode"] = "hook_drag"
					b["victim"] = hit
					hit.apply_stun(1.2)   # 拖拽途中定住（拖回时间通常 <1s，1.2s 稳妥覆盖）
					spawn_impact(hit.position, true)
				elif float(b["traveled"]) >= float(b["len"]) or caster == null or not is_instance_valid(caster):
					alive = false   # 飞满射程没钩到 → 消散
			"hook_drag":
				var v = b["victim"]
				if v == null or not is_instance_valid(v) or v.hp <= 0.0 \
						or caster == null or not is_instance_valid(caster) or caster.hp <= 0.0:
					alive = false
				else:
					var toc2: Vector2 = caster.position - v.position
					var step3: float = float(b["speed"]) * 1.15 * delta
					if toc2.length() <= caster.radius + v.radius + 12.0 or toc2.length() <= step3:
						var heff: Dictionary = b["eff"]
						_apply_riders(v, heff, int(b["rank"]), caster)
						if float(heff.get("dmg", 0.0)) > 0.0:
							v.take_damage(float(heff["dmg"]) * float(b["sc"]), caster)
						# 拖行无视地形（Pudge式）——落点校正到最近可站格，别把人塞进建筑/水里
						v.position = map.cell_to_world(map.nearest_open(map.world_to_cell(v.position)))
						spawn_impact(v.position, true)
						alive = false
					else:
						v.position = v.position + toc2.normalized() * step3
						b["pos"] = v.position
		if alive:
			if fx != null and is_instance_valid(fx):
				fx.position = b["pos"]
			keep.append(b)
		else:
			if fx != null and is_instance_valid(fx):
				fx.queue_free()
	_bolts = keep


## ───────────────── 走近施法（DOTA式）─────────────────
## 单体技能点了超射程的目标 → 自动朝目标走，一进射程就自动施放。
## 玩家中途下达任何新指令（_order_serial 变化）即取消；目标/技能失效也取消。
func _queue_walk_cast(caster: Unit, slot: int, tgt: Unit) -> void:
	for wc in _walk_casts:
		if wc["c"] == caster:
			wc["slot"] = slot
			wc["tgt"] = tgt
			wc["point"] = Vector2.INF
			wc["serial"] = -1
			wc["age"] = 0.0
			return
	_walk_casts.append({"c": caster, "slot": slot, "tgt": tgt, "point": Vector2.INF, "serial": -1, "t": 0.0, "age": 0.0})
	if hud != null:
		hud.show_message("目标超出施法距离——正在接近…", 1.4)


func _queue_walk_cast_point(caster: Unit, slot: int, point: Vector2) -> void:
	for wc in _walk_casts:
		if wc["c"] == caster:
			wc["slot"] = slot
			wc["tgt"] = null
			wc["point"] = point
			wc["serial"] = -1
			wc["age"] = 0.0
			return
	_walk_casts.append({"c": caster, "slot": slot, "tgt": null, "point": point, "serial": -1, "t": 0.0, "age": 0.0})
	if hud != null:
		hud.show_message("落点超出施法距离——正在接近原落点…", 1.4)


func _walk_cast_pass(delta: float) -> void:
	if _walk_casts.is_empty():
		return
	var keep: Array = []
	for wc in _walk_casts:
		var c = wc["c"]
		var tgt = wc.get("tgt")
		if c == null or not is_instance_valid(c) or c.hp <= 0.0:
			continue
		if tgt != null and (not is_instance_valid(tgt) or tgt.hp <= 0.0 or tgt.garrisoned \
				or not target_visible_to(c, tgt)):
			continue
		var slot: int = int(wc["slot"])
		if slot >= c.slot_count() or not c.slot_ready(slot):
			continue
		if int(wc["serial"]) >= 0 and c._order_serial != int(wc["serial"]):
			continue   # 玩家亲自下了新指令 → 让路取消
		wc["age"] = float(wc.get("age", 0.0)) + delta
		if float(wc["age"]) > 15.0:
			if c.faction == Unit.FACTION_LIANG:
				msg("无法接近施法位置，命令已取消", 1.5)
			continue
		var ad: Dictionary = _abilities.get(String(c.ability_slots[slot]["id"]), {})
		var rng := ability_cast_range(c, ad)
		var cast_pos: Vector2 = tgt.position if tgt != null else wc.get("point", Vector2.INF)
		if cast_pos == Vector2.INF:
			continue
		if rng == INF or c.position.distance_to(cast_pos) <= rng:
			_begin_cast(c, slot, cast_pos, tgt)
			continue
		wc["t"] = float(wc["t"]) - delta
		if float(wc["t"]) <= 0.0:
			wc["t"] = 0.4
			c.order_move(cast_pos)   # 单体追移动目标；点地技能始终走向玩家原落点
			wc["serial"] = c._order_serial
			c.manual_order_active = true   # 走近期间托管别插手（这就是玩家的意图）
		keep.append(wc)
	_walk_casts = keep


## ───────────────── 引导施法（channel）─────────────────
## 施法者定身、每 tick 对落点区域结算一轮（伤害+骑手）。被眩晕/沉默/拖走 → unit._break_channel 清零 → 本 pass 停结算。
func _begin_channel(caster: Unit, center: Vector2, eff: Dictionary, sc: float, rank: int, ad: Dictionary) -> void:
	var dur := float(eff.get("dur", 3.0))
	caster._begin_channel_state(dur)
	_channels.append({"caster": caster, "center": center, "eff": eff, "sc": sc, "rank": rank,
		"r": float(ad.get("radius", 110.0)), "tick": float(eff.get("tick", 0.5)), "tick_t": 0.0, "ad": ad})


func _channel_pass(delta: float) -> void:
	if _channels.is_empty():
		return
	var keep: Array = []
	for ch in _channels:
		var caster = ch["caster"]
		# 引导结束/被打断（_channel_t 归零）/施法者阵亡 → 效果停止（不再登记）
		if caster == null or not is_instance_valid(caster) or caster.hp <= 0.0 or caster._channel_t <= 0.0:
			continue
		ch["tick_t"] = float(ch["tick_t"]) - delta
		if ch["tick_t"] <= 0.0:
			ch["tick_t"] = float(ch["tick"])
			_channel_tick(caster, ch)
		keep.append(ch)
	_channels = keep


## 引导单跳结算：对落点半径内敌军结算一轮伤害 + 全套骑手 + 一枚落弹演出。
func _channel_tick(caster: Unit, ch: Dictionary) -> void:
	var eff: Dictionary = ch["eff"]
	var center: Vector2 = ch["center"]
	var r: float = float(ch["r"])
	var sc: float = float(ch["sc"])
	var rank: int = int(ch["rank"])
	var foe := Unit.FACTION_GUAN if caster.faction == Unit.FACTION_LIANG else Unit.FACTION_LIANG
	for u in units_near(center, r + 40.0):
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
				and not u.is_building and center.distance_to(u.position) <= r + u.radius:
			_apply_riders(u, eff, rank, caster)
			if float(eff.get("dmg", 0.0)) > 0.0:
				u.take_damage(float(eff["dmg"]) * sc, caster)
			spawn_impact(u.position, true)
	# 落弹演出：每跳一朵扩散冲击（复用 AbilityFx，落点带随机抖动更像连炮）
	var jx := (float((int(center.x) * 7 + int(ch["tick_t"] * 100.0)) % 100) / 100.0 - 0.5) * r * 0.7
	var jy := (float((int(center.y) * 13 + int(caster.position.x)) % 100) / 100.0 - 0.5) * r * 0.7
	_spawn_ability_fx(center + Vector2(jx, jy), r * 0.5, ch["ad"].get("color", Color("ff7a2a")))


## 击退：范围内敌人被推离落点 + 伤害(可减速/眩晕)。
func _do_knockback(caster: Unit, eff: Dictionary, sc: float, center: Vector2, r: float, foe: int, snap: Array) -> void:
	for u in snap:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource and not u.is_building and center.distance_to(u.position) <= r:
			var away: Vector2 = u.position - center
			if away.length() < 1.0:
				away = Vector2(1, 0)
			var np: Vector2 = u.position + away.normalized() * float(eff.get("push", 90.0))
			if map.is_open_world(np):
				u.position = np
			if eff.get("slow", 0.0) > 0.0:
				u.apply_slow(eff["slow"], eff.get("slow_dur", 1.0))
			if eff.get("stun", 0.0) > 0.0:
				u.apply_stun(eff["stun"])
			u.take_damage(float(eff.get("dmg", 0.0)) * sc, caster)
			spawn_impact(u.position, true)


## 全图轰击：对全场敌军(或仅敌方英雄)结算一次(可减速/眩晕)。
func _do_global_nuke(caster: Unit, eff: Dictionary, sc: float, foe: int, snap: Array) -> void:
	var hero_only := bool(eff.get("heroes_only", false))
	for u in snap:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource and not u.is_building and (not hero_only or u.is_hero):
			_apply_riders(u, eff, 1, caster)   # 全图技也吃全套骑手（裴宣·满堂封口的全场沉默靠它）
			u.take_damage(float(eff.get("dmg", 0.0)) * sc, caster)
			spawn_impact(u.position, true)


## 弹射闪电：从落点最近敌人起跳，逐个弹向最近未命中目标，伤害逐跳衰减。
func _do_chain_nuke(caster: Unit, eff: Dictionary, sc: float, center: Vector2, foe: int, snap: Array, ad: Dictionary) -> void:
	var jumps := int(eff.get("jumps", 4))
	var jrange := float(eff.get("jump", 150.0))
	var dmg := float(eff.get("dmg", 0.0)) * sc
	var fall := float(eff.get("falloff", 0.85))
	var hit := {}
	var cur: Unit = _nearest_foe_to(center, foe, hit, INF, snap)
	var prev := center
	while cur != null and jumps > 0:
		hit[cur.get_instance_id()] = true
		if eff.get("slow", 0.0) > 0.0:
			cur.apply_slow(eff["slow"], eff.get("slow_dur", 1.0))
		if eff.get("stun", 0.0) > 0.0:
			cur.apply_stun(eff["stun"])
		cur.take_damage(dmg, caster)
		spawn_impact(cur.position, true)
		var bolt := BlinkShotFx.new()
		bolt.start_w = prev
		bolt.end_w = cur.position
		bolt.col = ad["color"]
		fx_root.add_child(bolt)
		prev = cur.position
		dmg *= fall
		jumps -= 1
		cur = _nearest_foe_to(prev, foe, hit, jrange, snap)


## chain 用：找离 p 最近、未命中、在 maxd 内的敌军(无则 null)。
func _nearest_foe_to(p: Vector2, foe: int, hit: Dictionary, maxd: float, snap: Array) -> Unit:
	var best: Unit = null
	var bd := maxd
	for u in snap:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource and not u.is_building and not hit.has(u.get_instance_id()):
			var d := p.distance_to(u.position)
			if d <= bd:
				bd = d
				best = u
	return best


## 护盾：给自身(或范围友军)一层吸收盾。
func _do_shield(caster: Unit, eff: Dictionary, sc: float, r: float, ally: int, snap: Array) -> void:
	var amt := float(eff.get("shield", 100.0)) * sc
	var dur := float(eff.get("dur", 8.0))
	var cleanse := String(eff.get("dispel", "")) == "debuffs"   # 安道全·神医解控：护体同时净化友军减益
	if bool(eff.get("allies", false)):
		for u in snap:
			if is_instance_valid(u) and u.faction == ally and not u.is_building and not u.garrisoned and u.hp > 0.0 and caster.position.distance_to(u.position) <= r:
				u.apply_shield(amt, dur)
				if cleanse:
					u.dispel(false)
	else:
		caster.apply_shield(amt, dur)
		if cleanse:
			caster.dispel(false)


## 攻速狂暴：自身(或范围友军)提升攻速(可加移速/平攻)。
func _do_atkspeed(caster: Unit, eff: Dictionary, r: float, ally: int, snap: Array) -> void:
	var asx := float(eff.get("atkspeed", 1.5))
	var dur := float(eff.get("dur", 6.0))
	var spd := float(eff.get("speed_mult", 0.0))
	if bool(eff.get("allies", false)):
		for u in snap:
			if is_instance_valid(u) and u.faction == ally and not u.is_building and not u.garrisoned and u.hp > 0.0 and caster.position.distance_to(u.position) <= r:
				u.apply_atkspeed(asx, dur)
				if spd > 0.0:
					u.apply_slow(spd, dur)
	else:
		caster.apply_atkspeed(asx, dur)
		if spd > 0.0:
			caster.apply_slow(spd, dur)
		if eff.get("self_atk", 0.0) > 0.0:
			caster.apply_temp_atk(eff["self_atk"], dur)


## ===== 第二批「兑现宣称」原语：立桩 / 裂地 / 回音 / 影波 / 一线火 =====
## 立桩：在落点插一根原地不动的桩，登记到 _wards 持续脉冲。mode=heal 给友军续血；
## mode=attack 每跳锁最近敌连射；mode=poison 连射 + 减速；mode=banner 轮换忠/义双旗。
## 桩与旗本身不可被摧毁（限时）。
func _do_ward(caster: Unit, eff: Dictionary, rank: int, center: Vector2, ally: int, foe: int, ad: Dictionary, slot := -1) -> void:
	var mode := String(eff.get("ward_mode", "attack"))
	var dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("ward_dur", 8.0))
	var wr := float(eff.get("ward_radius", 200.0))
	var pulse := float(eff.get("pulse", 1.0))
	var heal := (float(_pick(eff["heal_ranks"], rank)) if eff.has("heal_ranks") else float(eff.get("heal", 0.0)))
	var dmg := (float(_pick(eff["dmg_ranks"], rank)) if eff.has("dmg_ranks") else float(eff.get("dmg", 0.0)))
	var hero_reduction := (float(_pick(eff["hero_reduction_ranks"], rank)) if eff.has("hero_reduction_ranks") else 0.0)
	var troop_reduction := (float(_pick(eff["troop_reduction_ranks"], rank)) if eff.has("troop_reduction_ranks") else 0.0)
	var atkspeed := (float(_pick(eff["atkspeed_ranks"], rank)) if eff.has("atkspeed_ranks") else 1.0)
	var banner_kind := ""
	if mode == "banner":
		var variants: Array = eff.get("banner_variants", ["loyalty", "righteous"])
		var sequence := caster.slot_cast_sequence(slot) if slot >= 0 else 0
		banner_kind = String(variants[sequence % variants.size()]) if not variants.is_empty() else "loyalty"
	var pos := map.cell_to_world(map.nearest_open(map.world_to_cell(center)))
	# 只错开视觉节点，不移动实际光环圆心；避免边缘单位因旗面演出意外进出效果范围。
	var visual_pos := pos
	if banner_kind == "loyalty":
		visual_pos += Vector2(-10, 10)
	elif banner_kind == "righteous":
		visual_pos += Vector2(10, -10)
	var ward_col: Color = Color("4b92df") if banner_kind == "loyalty" else ad["color"]
	_ward_serial += 1
	_wards.append({"pos": pos, "r": wr, "t": dur, "pulse": pulse, "pulse_t": pulse * 0.35, "aura_t": 0.0,
		"mode": mode, "ally": ally, "foe": foe, "caster": caster,
		"heal": heal, "dmg": dmg, "atkspeed": atkspeed, "banner_kind": banner_kind,
		"slow": float(eff.get("slow", 0.0)), "slow_dur": float(eff.get("slow_dur", 1.0)),
		"hero_reduction": hero_reduction, "troop_reduction": troop_reduction, "aura_id": _ward_serial,
		"col": ward_col})
	var wf := WardFx.new()
	wf.position = visual_pos
	wf.rad = wr
	wf.life = dur
	wf.col = ward_col
	wf.style = String(eff.get("ward_style", mode))
	wf.banner_kind = banner_kind
	fx_root.add_child(wf)
	shake(2.0, pos)


## 立桩逐帧：治疗桩抚平友军；攻击/毒桩锁敌；忠义旗 10Hz 刷新共同减伤，忠每秒回血、义持续加攻速。
func _ward_pass(delta: float) -> void:
	if _wards.is_empty():
		return
	for w in _wards:
		w["t"] = float(w["t"]) - delta
		if float(w["t"]) <= 0.0:
			continue
		var mode := String(w["mode"])
		var wp: Vector2 = w["pos"]
		var wr: float = w["r"]
		var src = w["caster"]
		if not is_instance_valid(src):
			src = null
		if mode == "banner":
			# 旗阵减伤不能靠 1 秒回血脉冲刷新，否则进出边界手感迟钝；独立以 10Hz 扫描并留 0.22 秒容差。
			w["aura_t"] = float(w.get("aura_t", 0.0)) - delta
			if float(w["aura_t"]) <= 0.0:
				w["aura_t"] = float(w["aura_t"]) + 0.1
				var afac: int = int(w["ally"])
				for u in units_near(wp, wr):
					if not (is_instance_valid(u) and u.faction == afac and u.hp > 0.0 and not u.is_building \
							and not u.is_resource and not u.garrisoned and not u.is_captive \
							and wp.distance_to(u.position) <= wr):
						continue
					var reduction := float(w["hero_reduction"]) if u.is_hero else float(w["troop_reduction"])
					u.apply_damage_reduction(reduction, 0.22, int(w["aura_id"]))
					if String(w.get("banner_kind", "loyalty")) == "righteous":
						u.apply_aura_atkspeed(float(w.get("atkspeed", 1.0)), 0.22, int(w["aura_id"]))
			if String(w.get("banner_kind", "loyalty")) == "loyalty":
				w["pulse_t"] = float(w["pulse_t"]) - delta
				if float(w["pulse_t"]) <= 0.0:
					w["pulse_t"] = float(w["pulse_t"]) + float(w["pulse"])
					var afac2: int = int(w["ally"])
					for u in units_near(wp, wr):
						if is_instance_valid(u) and u.faction == afac2 and u.hp > 0.0 and not u.is_building \
								and not u.is_resource and not u.garrisoned and not u.is_captive \
								and wp.distance_to(u.position) <= wr:
							u.heal(float(w["heal"]))
			continue
		w["pulse_t"] = float(w["pulse_t"]) - delta
		if float(w["pulse_t"]) > 0.0:
			continue
		w["pulse_t"] = float(w["pulse_t"]) + float(w["pulse"])
		if mode == "heal":
			var hv: float = float(w["heal"])
			var afac: int = int(w["ally"])
			for u in units_near(wp, wr):
				if is_instance_valid(u) and u.faction == afac and not u.is_building and not u.is_resource \
						and not u.garrisoned and u.hp > 0.0 and u.hp < u.max_hp and wp.distance_to(u.position) <= wr:
					u.heal(hv)
					spawn_impact(u.position + Vector2(0, -10), false)
		else:
			var ffac: int = int(w["foe"])
			var best: Unit = null
			var bd := wr
			for u in units_near(wp, wr):
				if is_instance_valid(u) and u.faction == ffac and u.hp > 0.0 and not u.is_resource \
						and not u.garrisoned and not u.is_building:
					var dd := wp.distance_to(u.position)
					if dd <= bd:
						bd = dd
						best = u
			if best != null:
				if float(w["slow"]) > 0.0:
					best.apply_slow(float(w["slow"]), float(w["slow_dur"]))
				best.take_damage(float(w["dmg"]), src)
				spawn_impact(best.position, true)
				var bolt := BlinkShotFx.new()
				bolt.start_w = wp + Vector2(0, -26)
				bolt.end_w = best.position
				bolt.col = w["col"]
				fx_root.add_child(bolt)
	_wards = _wards.filter(func(w): return float(w["t"]) > 0.0)


## 裂地（鲁智深 Q）：朝指向一线贯穿伤+晕，并把沿线格子锁死成一道阻路实墙(复用冰墙解锁过场)。
func _do_fissure(caster: Unit, eff: Dictionary, sc: float, center: Vector2, foe: int, snap: Array, ad: Dictionary) -> void:
	var ldir := center - caster.position
	if ldir.length() < 1.0:
		ldir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	ldir = ldir.normalized()
	var llen := float(eff.get("len", 320.0))
	var lhw := float(eff.get("width", 40.0)) * 0.5
	for u in snap:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
				and _in_capsule(caster.position, ldir, llen, lhw + u.radius, u.position):
			if eff.get("slow", 0.0) > 0.0:
				u.apply_slow(eff["slow"], eff.get("slow_dur", 1.5))
			if eff.get("stun", 0.0) > 0.0:
				u.apply_stun(float(eff["stun"]))
			u.take_damage(float(eff["dmg"]) * sc, caster)
			spawn_impact(u.position, true)
	var cells: Array = []
	var step := float(GameMap.CELL) * 0.85
	var nseg := maxi(2, int(llen / step))
	for i in range(nseg + 1):
		var wp := caster.position + ldir * (float(i) * step)
		var cell := map.world_to_cell(wp)
		if map.is_open_cell(cell) and not _cell_has_unit(wp):
			map.astar.set_point_solid(cell, true)
			cells.append(cell)
	if not cells.is_empty():
		_ice_walls.append({"cells": cells, "t": float(eff.get("wall_dur", 4.0))})
	var ef := EarthCrackFx.new()
	ef.position = caster.position
	ef.dir = ldir
	ef.length = llen
	ef.life = float(eff.get("wall_dur", 4.0))
	ef.col = ad["color"]
	fx_root.add_child(ef)
	shake(4.5, caster.position)


## 回音重踏（鲁智深 R）：圈内敌越多，每个目标受创越重(base + echo×(n-1))，附眩晕。「敌越密则伤越重」。
func _do_echo(caster: Unit, eff: Dictionary, sc: float, center: Vector2, r: float, foe: int, snap: Array) -> void:
	var hits: Array = []
	for u in snap:
		if is_instance_valid(u) and u.faction == foe and u.hp > 0.0 and not u.garrisoned and not u.is_resource \
				and not u.is_building and center.distance_to(u.position) <= r:
			hits.append(u)
	var n := hits.size()
	var per := float(eff.get("dmg", 70.0)) * sc + float(eff.get("echo", 16.0)) * sc * float(maxi(0, n - 1))
	var es := EchoSlamFx.new()   # 中心碎裂 + 多重外扩冲击环 + 放射地裂
	es.position = center
	es.rad = r
	fx_root.add_child(es)
	for u in hits:
		if eff.get("stun", 0.0) > 0.0:
			u.apply_stun(float(eff["stun"]))
		if eff.get("slow", 0.0) > 0.0:
			u.apply_slow(eff["slow"], eff.get("slow_dur", 1.5))
		u.take_damage(per, caster)
		spawn_impact(u.position, true)
		var ep := EchoSlamFx.new()   # 每个被命中敌人脚下再炸一记小回音环（人越密、回音越多）
		ep.position = u.position
		ep.rad = 48.0
		fx_root.add_child(ep)


## 影波（安道全 E）：从施法者起波，在友/敌间往复弹跳——撞到敌人灼伤，撞到友军回血。
func _do_heal_wave(caster: Unit, eff: Dictionary, sc: float, _center: Vector2, ally: int, foe: int, snap: Array, ad: Dictionary) -> void:
	var jumps := int(eff.get("jumps", 5))
	var jrange := float(eff.get("jump", 130.0))
	var dmg := float(eff.get("dmg", 0.0)) * sc
	var heal := float(eff.get("heal", 0.0)) * sc
	var hit := {}
	hit[caster.get_instance_id()] = true
	if heal > 0.0:
		caster.heal(heal)
		spawn_impact(caster.position + Vector2(0, -10), false)
	var prev := caster.position
	var cur: Unit = _nearest_wave_node(prev, ally, foe, hit, jrange, snap)
	while cur != null and jumps > 0:
		hit[cur.get_instance_id()] = true
		var bolt := BlinkShotFx.new()
		bolt.start_w = prev
		bolt.end_w = cur.position
		bolt.col = ad["color"]
		fx_root.add_child(bolt)
		var rip := ShadowWaveFx.new()   # 节点涟漪：治友青绿十字 / 伤敌冷蓝环
		rip.position = cur.position
		if cur.faction == foe:
			rip.col = Color("9fd8ff")
			rip.heal = false
			cur.take_damage(dmg, caster)
			spawn_impact(cur.position, true)
		else:
			rip.col = Color("8fe6a0")
			rip.heal = true
			cur.heal(heal)
			spawn_impact(cur.position + Vector2(0, -10), false)
		fx_root.add_child(rip)
		prev = cur.position
		jumps -= 1
		cur = _nearest_wave_node(prev, ally, foe, hit, jrange, snap)


## 影波弹跳取点：离 p 最近、未命中、在 maxd 内的「友或敌」活体单位(非建筑/资源)。
func _nearest_wave_node(p: Vector2, ally: int, foe: int, hit: Dictionary, maxd: float, snap: Array) -> Unit:
	var best: Unit = null
	var bd := maxd
	for u in snap:
		if is_instance_valid(u) and u.hp > 0.0 and not u.is_resource and not u.is_building and not u.garrisoned \
				and (u.faction == ally or u.faction == foe) and not hit.has(u.get_instance_id()):
			var d := p.distance_to(u.position)
			if d <= bd:
				bd = d
				best = u
	return best


## 一线长焰（解珍 R）：沿指向铺一排互叠的地火，连成「一条长焰」焚尽来路。
func _do_fire_line(caster: Unit, eff: Dictionary, rank: int, center: Vector2, foe: int) -> void:
	var fdir := center - caster.position
	if fdir.length() < 1.0:
		fdir = Vector2(-1.0 if caster.face_left else 1.0, 0.0)
	fdir = fdir.normalized()
	var flen := float(eff.get("len", 300.0))
	var fdur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 8.0))
	var fdps := float(_pick(eff["dps_ranks"], rank)) if eff.has("dps_ranks") else float(eff.get("dps", 22.0))
	var pr := float(eff.get("patch_r", 60.0))
	var n := maxi(2, int(flen / (pr * 0.85)))
	for i in range(n + 1):
		var fp := caster.position + fdir * (float(i) / float(n) * flen)
		_spawn_ground_fire_quiet(fp, pr, fdps * fdur, fdur, caster, foe)
	var flf := FireLineFx.new()   # 火舌沿指向逐段点燃铺过去
	flf.position = caster.position
	flf.dir = fdir
	flf.length = flen
	flf.col = Color("ff5522")
	fx_root.add_child(flf)
	shake(3.0, caster.position)


## 火径逐帧（魏定国 E）：限时内每隔 drop 秒在施法者「当前脚下」落一处地火 → 随移动拖出一条火尾。
func _trail_pass(delta: float) -> void:
	if _fire_trails.is_empty():
		return
	for ftr in _fire_trails:
		ftr["t"] = float(ftr["t"]) - delta
		ftr["drop_t"] = float(ftr["drop_t"]) - delta
		var src = ftr["caster"]
		if not is_instance_valid(src) or src.hp <= 0.0:
			ftr["t"] = 0.0
			continue
		if float(ftr["drop_t"]) <= 0.0:
			ftr["drop_t"] = float(ftr["drop_t"]) + float(ftr["drop"])
			var dd: float = float(ftr["dot_dur"])
			_spawn_ground_fire_quiet(src.position, float(ftr["r"]), float(ftr["dps"]) * dd, dd, src, int(ftr["foe"]))
	_fire_trails = _fire_trails.filter(func(ftr): return float(ftr["t"]) > 0.0)


## 安静版地火（火径/一线火专用）：只登记 DOT + 铺火演出，不附加点燃爆闪与屏震(密集落点不刷屏)。
func _spawn_ground_fire_quiet(center: Vector2, r: float, total: float, dur: float, caster: Unit, foe: int) -> void:
	_add_ground_dot(center, r, total, dur, caster, foe)
	_add_ground_fire_visual(center, r, dur)


func _add_ground_fire_visual(center: Vector2, r: float, dur: float):
	if _lite_fx and _ground_fire_visuals >= LITE_GROUND_FIRE_CAP:
		return null
	var fx := GroundFireFx.new()
	fx.position = center
	fx.rad = r
	fx.life = dur
	fx.lite = _lite_fx
	_ground_fire_visuals += 1
	fx.tree_exited.connect(_on_ground_fire_visual_exited)
	fx_root.add_child(fx)
	return fx


func _on_ground_fire_visual_exited() -> void:
	_ground_fire_visuals = maxi(0, _ground_fire_visuals - 1)


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


## smite 按控制/减益参数分流一个专属演出（替换默认冲击环 AbilityFx，避免双重闪光）。返回 true=已出专属演出。
## 优先级：眩晕(StompFx) > 噤声(SilenceFx) > 削甲(ArmorCrackFx) > 灼烧(FlameburstFx) > 减速(SlashArcFx)。
func _spawn_smite_variant_fx(center: Vector2, r: float, eff: Dictionary, ad: Dictionary) -> bool:
	var col: Color = ad.get("color", Color.WHITE)
	var node: TimedFx = null
	if float(eff.get("stun", 0.0)) > 0.0:
		var st := StompFx.new(); st.rad = r; st.col = col; node = st
	elif float(eff.get("silence", 0.0)) > 0.0:
		var si := SilenceFx.new(); si.rad = r; si.col = col; node = si
	elif eff.has("def_down"):
		var ac := ArmorCrackFx.new(); ac.rad = r; ac.col = col; node = ac
	elif eff.has("dot_total"):
		var fb := FlameburstFx.new(); fb.rad = r; fb.col = col; node = fb
	elif float(eff.get("slow", 0.0)) > 0.0:
		var sa := SlashArcFx.new(); sa.rad = r; sa.col = col; node = sa
	if node == null:
		return false
	node.position = center
	fx_root.add_child(node)
	shake(clampf(r / 16.0, 1.5, 5.0), center)   # 保留原冲击屏震手感
	return true


## 108将 DOTA 批量视觉层：按 DotaVisuals 写入的 visual 字段生成弹体/符文/命中/扫线演出。
## 这里只管表现，不延迟既有结算，避免改变竞技场外 AI/关卡节奏。
func _spawn_dota_visual_fx(caster: Unit, center: Vector2, r: float, ad: Dictionary, eff: Dictionary, cast_kind: String) -> bool:
	var visual: Dictionary = ad.get("visual", {})
	if visual.is_empty():
		return false
	var delivery := String(visual.get("delivery", "impact"))
	var theme := String(visual.get("theme", "stone"))
	var col := _dota_visual_color(theme, ad.get("color", Color.WHITE))
	var projectile := String(visual.get("projectile", "stone"))
	var impact := String(visual.get("impact", "dust_ring"))
	var start := caster.position + Vector2(0, -10)
	var target := center
	match delivery:
		"projectile", "thrown", "lob":
			if cast_kind != "bolt":
				if start.distance_to(target) > 18.0:
					var pfx := DotaProjectileFx.new()
					pfx.position = start
					pfx.end_w = target
					pfx.col = col
					pfx.tex = Art.dota_projectile_texture(projectile)
					pfx.impact_tex = Art.dota_impact_texture(impact)
					pfx.lob = delivery == "lob"
					fx_root.add_child(pfx)
				else:
					_spawn_dota_impact_node(target, r, col, impact, "impact")
		"beam":
			var bfx := DotaBeamFx.new()
			bfx.position = target
			bfx.start_w = start
			bfx.end_w = target
			bfx.col = col
			fx_root.add_child(bfx)
		"sweep":
			var sw := DotaSweepFx.new()
			sw.position = caster.position
			sw.end_w = target
			sw.rad = r
			sw.col = col
			fx_root.add_child(sw)
		"chain":
			if cast_kind != "hook":
				var cfx := DotaBeamFx.new()
				cfx.position = target
				cfx.start_w = start
				cfx.end_w = target
				cfx.col = col
				cfx.chain = true
				fx_root.add_child(cfx)
		"dash":
			if cast_kind != "blink":
				var dfx := DotaBeamFx.new()
				dfx.position = target
				dfx.start_w = caster.position
				dfx.end_w = target
				dfx.col = col
				dfx.dash = true
				fx_root.add_child(dfx)
		"aura":
			_spawn_dota_impact_node(caster.position, r, col, impact, "aura")
		"rune", "manifest", "roar", "impact":
			_spawn_dota_impact_node(target, r, col, impact, delivery)
		_:
			_spawn_dota_impact_node(target, r, col, impact, "impact")
	return bool(visual.get("replace_default", true))


func _spawn_dota_impact_node(pos: Vector2, r: float, col: Color, style: String, mode: String) -> void:
	var fx := DotaImpactFx.new()
	fx.position = pos
	fx.rad = maxf(42.0, r)
	fx.col = col
	fx.tex = Art.dota_impact_texture(style)
	fx.mode = mode
	fx_root.add_child(fx)
	if mode != "aura" and mode != "rune":   # 增益光环/符文域不震屏——放招频繁，逢法必抖会让镜头一直发颤
		shake(clampf(r / 18.0, 1.2, 4.0), pos)


func _dota_visual_color(theme: String, fallback: Color) -> Color:
	var tc := fallback
	match theme:
		"hammer", "stone":
			tc = Color(0.72, 0.66, 0.52)
		"axe", "blade", "spear", "arrow":
			tc = Color(0.88, 0.86, 0.74)
		"fire":
			tc = Color(1.0, 0.38, 0.12)
		"ice":
			tc = Color(0.58, 0.88, 1.0)
		"water":
			tc = Color(0.28, 0.66, 1.0)
		"poison":
			tc = Color(0.34, 0.95, 0.32)
		"thunder":
			tc = Color(0.55, 0.86, 1.0)
		"shadow":
			tc = Color(0.62, 0.38, 0.95)
		"holy":
			tc = Color(1.0, 0.86, 0.36)
		"beast":
			tc = Color(0.95, 0.47, 0.24)
		"chain":
			tc = Color(0.72, 0.68, 0.58)
		"command":
			tc = Color(0.95, 0.76, 0.28)
	return fallback.lerp(tc, 0.65)


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
			if fog and my_fac == Unit.FACTION_LIANG and not is_visible_world(u.position):
				continue   # 托管不开图挂：雾里的敌人对我方 AI 同样不可见
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
				or v.garrisoned or v.is_captive or v.hp <= 0.0 or v._invis_t > 0.0:
			continue
		if fog and my_fac == Unit.FACTION_LIANG and not is_visible_world(v.position):
			continue   # 托管不开图挂
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
		if v._invis_t > 0.0:
			continue   # 主动隐身：集火目标也点不到
		if fog and u.faction == Unit.FACTION_LIANG and not is_visible_world(v.position):
			continue   # 托管不开图挂
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


## 花荣 E/R 专属高价值目标：严格按类别分层，距离只在同一层内比较。
## 敌将 > 投石车 > 其他攻城器 > 高威胁远程/精锐骑兵/战象等精英；普通刀枪兵不会浪费 E/R。
func _hua_high_value_target(u: Unit, reach: float) -> Unit:
	var best: Unit = null
	var best_score := -1.0e20
	for v in units:
		if not (is_instance_valid(v) and v.faction != u.faction and not v.is_building and not v.is_resource \
				and not v.garrisoned and not v.is_captive and v.hp > 0.0 and v._invis_t <= 0.0):
			continue
		if fog and u.faction == Unit.FACTION_LIANG and not is_visible_world(v.position):
			continue
		var d := u.position.distance_to(v.position)
		if d > reach:
			continue
		var tier := -1
		if v.is_hero:
			tier = 5
		elif String(v.key) == "siege_cata":
			tier = 4
		elif String(v.key).begins_with("siege"):
			tier = 3
		elif (v.is_ranged and (v.atk >= 18.0 or v.atk_range >= 200.0)) \
				or (v.is_cavalry and (v.max_hp >= 175.0 or v.atk >= 16.0)) \
				or v.max_hp >= 300.0 or v.atk >= 24.0:
			tier = 2   # 火枪/投弹/远程重火力、精骑/战象，以及其他明显精英
		if tier < 0:
			continue
		var threat: float = v.atk / maxf(v.atk_cd, 0.25) + v.max_hp * 0.025
		var wounded: float = (1.0 - v.hp / maxf(v.max_hp, 1.0)) * 50.0
		var score: float = float(tier) * 100000.0 + threat + wounded - d * 0.02
		if score > best_score:
			best_score = score
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
	for v in units_near(pos, r):
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
	for v in units_near(pos, r):
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
		for b in units_near(a.position, sample_r):
			if b.faction != my_fac and not b.is_building and not b.is_resource \
					and not b.garrisoned and not b.is_captive and b.hp > 0.0 \
					and a.position.distance_to(b.position) <= sample_r:
				n += 1
		if n > bestn:
			bestn = n
			best = a.position
	return best


## 可走的撤退点：朝「远离附近敌群质心」且「偏向聚义厅」的方向退 kite_dist；无敌则退向聚义厅。
## 用质心(而非最近敌)+回家偏置 → 被左右夹击时方向稳定，不会因「最近敌」左右翻转而原地左右横跳被打死。
func _retreat_point(u: Unit, kite_dist: float) -> Vector2:
	var base := main_base(u.faction)
	var home: Vector2 = base.position if (base != null and is_instance_valid(base)) else u.position
	var c := _foe_centroid_within(u.position, maxf(300.0, u.aggro_range), u.faction)
	var dir: Vector2
	if c != Vector2.INF and u.position.distance_to(c) > 1.0:
		dir = (u.position - c).normalized()                 # 远离敌群质心
		var hd := home - u.position
		if hd.length() > 1.0:
			dir = (dir + hd.normalized()).normalized()       # 再朝家方向混合（别往敌后/地图角落撤）
	else:
		var hd2 := home - u.position
		dir = hd2.normalized() if hd2.length() > 1.0 else Vector2(-1, 0)
	var p := u.position + dir * kite_dist
	if not map.is_open_world(p):
		p = map.cell_to_world(map.nearest_open(map.world_to_cell(p)))
	return p


## 半径内敌方单位的位置质心（无则 INF）。用于撤退/走位取「敌群中心」，避免只盯最近敌而方向抖动。
func _foe_centroid_within(pos: Vector2, r: float, my_fac: int) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for v in units:
		if not is_instance_valid(v) or v.faction == my_fac or v.is_building or v.is_resource \
				or v.garrisoned or v.is_captive or v.hp <= 0.0:
			continue
		if pos.distance_to(v.position) <= r:
			sum += v.position
			n += 1
	return (sum / float(n)) if n > 0 else Vector2.INF


## 抬手守卫的单次放招：就绪且未抬手且落点有效→放并返回 true（调用方据此 return）。非指向传 lp=自身位置。
func _ai_cast_slot(u: Unit, slot: int, lp: Vector2, tgt: Unit = null) -> bool:
	if u._cast_t > 0.0 or not u.slot_ready(slot) or lp == Vector2.INF:
		return false
	_begin_cast(u, slot, lp, tgt)
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


## 某名友军是否已经处于本阵营一面有效忠义旗的减伤范围内。
## 忠/义的减伤不叠加，托管若把第二点立刻砸在同一战团，只会让 UI 瞬间从 2/2 变 0/2。
func _active_banner_covers(pos: Vector2, fac: int) -> bool:
	for w in _wards:
		if String(w.get("mode", "")) != "banner" or int(w.get("ally", -1)) != fac \
				or float(w.get("t", 0.0)) <= 0.0:
			continue
		if Vector2(w.get("pos", Vector2.INF)).distance_to(pos) <= float(w.get("r", 0.0)):
			return true
	return false


## 宋江忠义旗落点：只在正在交战的己方作战单位中选点。优先覆盖尚未吃到忠义旗减伤的人，
## 再比较本旗总覆盖人数，最后才用敌军压力破平局。这样第二点会留给另一条受压战线；若所有
## 交战友军都已在旗内则返回 INF，等旧旗到期再补，不把两点无意义地叠在同一处。
## 返回具体友军脚下，避免落在几路部队质心的空地上；无有效战团返回 INF。
func _best_banner_pos(fac: int, banner_r: float, threat_r: float) -> Vector2:
	var allies: Array = []
	for v in units:
		if is_instance_valid(v) and v.faction == fac and v.hp > 0.0 and not v.is_building \
				and not v.is_resource and not v.is_worker and not v.garrisoned and not v.is_captive:
			allies.append(v)
	var best := Vector2.INF
	var best_uncovered := -1
	var best_covered := -1
	var best_foes := -1
	for anchor in allies:
		var foes := _visible_foe_count_within(anchor.position, threat_r, fac)
		if foes <= 0:
			continue
		var covered := 0
		var uncovered := 0
		for friend in units_near(anchor.position, banner_r):
			if is_instance_valid(friend) and friend.faction == fac and friend.hp > 0.0 and not friend.is_building \
					and not friend.is_resource and not friend.is_worker and not friend.garrisoned \
					and anchor.position.distance_to(friend.position) <= banner_r:
				covered += 1
				if not _active_banner_covers(friend.position, fac):
					uncovered += 1
		if uncovered <= 0:
			continue
		if uncovered > best_uncovered \
				or (uncovered == best_uncovered and covered > best_covered) \
				or (uncovered == best_uncovered and covered == best_covered and foes > best_foes):
			best_uncovered = uncovered
			best_covered = covered
			best_foes = foes
			best = anchor.position
	return best


## 忠义旗托管只依据本阵营已掌握的敌情；玩家方绝不因阴影外敌军而提前插旗或顺带开视野。
func _visible_foe_count_within(pos: Vector2, r: float, fac: int) -> int:
	var n := 0
	for v in units_near(pos, r):
		if not (is_instance_valid(v) and v.faction != fac and v.hp > 0.0 and not v.is_building \
				and not v.is_resource and not v.is_worker and not v.garrisoned and not v.is_captive \
				and pos.distance_to(v.position) <= r):
			continue
		if fog and fac == Unit.FACTION_LIANG and not is_visible_world(v.position):
			continue
		n += 1
	return n


## 召唤物（虎/龙）：在施法者周围生成 count 个单位，按 copy_caster 或等级数组定血/攻；dur>0 则限时。
func _do_summon(caster: Unit, eff: Dictionary, rank: int) -> void:
	var skey := String(eff.get("unit", ""))
	var skind := String(eff.get("summon_kind", ""))
	# 真·分身：copy_caster 且种类是「幻象类」→ 用施法者自己的兵种 key 生成，于是分身长得就是英雄本人
	# （替代以往一律生成的猛虎/巨龙，彻底消除「召唤=老虎」的同质化）。
	var illusion := bool(eff.get("copy_caster", false)) and skind in ["image", "clone", "copy", "phantom", "rider", "double"]
	if illusion and caster != null and _defs.has(caster.key):
		skey = caster.key
	if skey == "" or not _defs.has(skey):
		return
	var n := maxi(1, int(eff.get("count", 1)))
	var dur := float(_pick(eff["dur_ranks"], rank)) if eff.has("dur_ranks") else float(eff.get("dur", 0.0))
	var cmult := float(_pick(eff["copy_mult"], rank)) if eff.has("copy_mult") else 1.0   # copy_caster 时按等级取本体血/攻的百分比
	for i in n:
		var ang := TAU * (float(i) / float(n)) + 0.6
		var off := Vector2(cos(ang), sin(ang)) * (34.0 + 8.0 * float(n))
		var pos := map.cell_to_world(map.nearest_open(map.world_to_cell(caster.position + off)))
		var su := spawn_unit(skey, caster.faction, pos)
		su.is_summon = true
		su.summon_kind = skind
		su.stat_owner_key = caster.key   # 驻守战的召唤物/幻象战绩归召唤英雄
		if illusion:
			# 幻象：长得像英雄但不是英雄——不占英雄位、不放技能、不吃英雄增益；半透蓝影标识虚实
			su.is_hero = false
			su.ability = ""
			su.ability_slots.clear()
			su.modulate = Color(0.62, 0.78, 1.25, 0.82)
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
		if illusion:   # 镜分演出：竖向镜光 + 从本体飞来的残影点
			var sm := SplitMirrorFx.new()
			sm.position = pos
			sm.from_w = caster.position
			sm.col = Color("8fd3ff")
			fx_root.add_child(sm)
		else:
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
	u.take_damage(u.hp + 1.0, null, false, true)


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
	var fx = _add_ground_fire_visual(center, r, dur)
	if fx == null:
		return
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


## 花荣 R 敌将持续伤害：固定跟随单个目标，每秒按该目标当前最大生命结算一次，共 5 次。
## 与地面 DOT 分开，目标走出原位置也不会脱离；目标死亡/驻入建筑即停止。
func _hua_snipe_dot_pass(delta: float) -> void:
	if _hua_snipe_dots.is_empty():
		return
	for d in _hua_snipe_dots:
		var target = d.get("target")
		if target == null or not is_instance_valid(target) or target.hp <= 0.0 or target.garrisoned:
			d["t"] = 0.0
			continue
		d["t"] = float(d["t"]) - delta
		d["tick_t"] = float(d["tick_t"]) - delta
		var src = d.get("caster")
		if not is_instance_valid(src):
			src = null
		var guard := 0
		while float(d["tick_t"]) <= 1e-4 and int(d.get("ticks_left", 0)) > 0 and guard < 8:
			guard += 1
			d["tick_t"] = float(d["tick_t"]) + float(d["tick"])
			d["ticks_left"] = int(d["ticks_left"]) - 1
			target.take_damage(target.max_hp * float(d["pct"]), src)
			if target.hp <= 0.0:
				break
	_hua_snipe_dots = _hua_snipe_dots.filter(func(d):
		return float(d["t"]) > 0.0 and int(d.get("ticks_left", 0)) > 0 \
				and d.get("target") != null and is_instance_valid(d.get("target")) and d.get("target").hp > 0.0)


# 技能 id → 招式特效主题。每个英雄技能都按招式归类放一段专属演出（火攻有火、落雷有电、
# 鼓舞金光、神行疾风、横扫刀光、拖人水花、蒙药毒雾、神箭破空、飞石…）。未列者退回通用冲击波。
const ABILITY_FX := {
	"gongsun_thunder": "thunder",
	"song_rally": "rally", "chao_rally": "rally",
	"dai_dash": "haste",
	"lin_sweep": "spear", "lin_charge": "charge", "lin_storm": "stomp",
	"liu_cleave": "slash", "li_berserk": "stomp", "li_whirl": "whirl", "li_rage": "blood",
	"luan_smash": "slash", "hu_whips": "slash", "xu_drill": "slash",
	"lu_sweep": "slash", "wu_kick": "slash", "jiang_smash": "stomp", "shi_spear": "spear",
	"zhang_drag": "water", "bai_drug": "poison",
	"hua_rain": "arrow_rain", "hua_shot": "arrow_shot",
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
		return is_instance_valid(u) and u.hp > 0.0 and not u.is_resource)
	if members.is_empty():
		_groups.erase(n)
		_refresh_group_badges()
		return
	_groups[n] = members.duplicate()
	_refresh_group_badges()
	hud.show_message("编队 [%d]：%d 个单位" % [n, members.size()], 1.4)


func _add_to_group(n: int) -> void:
	var members := selection.filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0 and not u.is_resource)
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


func select_members(members: Array, additive: bool) -> void:
	var valid: Array = members.filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0 and not u.garrisoned)
	if valid.is_empty():
		return
	if not additive:
		_set_selection(valid)
		return
	var out := selection.duplicate()
	var all_selected := valid.all(func(u) -> bool: return out.has(u))
	for u in valid:
		if all_selected:
			out.erase(u)
		elif not out.has(u):
			out.append(u)
	_set_selection(out)


func select_same_in_selection(proto: Unit) -> void:
	if not is_instance_valid(proto):
		return
	var arr: Array = selection.filter(func(u) -> bool:
		return is_instance_valid(u) and u.hp > 0.0 and u.key == proto.key and u.faction == proto.faction)
	if not arr.is_empty():
		_set_selection(arr)


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
	_worker_cat = ""   # 改选单位 → 命令卡回到根页（建筑/塔/陷阱/维修）
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


# 手动指令保护戳：至少保护 5 秒，并持续到整条指令链自然执行完；停止/据守则保持到下一条命令。
const MANUAL_ORDER_PROTECT := 5.0
func _stamp_manual(arr: Array) -> void:
	for u in arr:
		if is_instance_valid(u):
			u.manual_order_t = MANUAL_ORDER_PROTECT
			u.manual_order_active = true


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
	_stamp_manual(movers)
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
			u.order_attack(enemy, queued, true)
		return
	var lp := to_logic(p)
	var targets := _formation_targets(movers, lp, 30.0, _formation_origin(movers, queued))
	var move_cap := _group_speed_cap(movers)
	var repaired := false
	for i in range(movers.size()):
		var u: Unit = movers[i]
		if node != null and u.is_worker:
			u.order_gather(node, queued)        # 工人采集
		elif rep != null and u.is_worker:
			u.order_repair(rep, queued)         # 工人修理受损建筑
			repaired = true
		else:
			u.order_move(targets[i], queued, move_cap)
	if repaired:
		msg("工人前去修缮 %s" % rep.display_name, 1.3)


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
	Sfx.play("order")
	var enemy := _enemy_at(p)
	_stamp_manual(movers)
	if enemy != null:
		for u in movers:
			u.order_attack(enemy, queued, true)   # A+点单位是明确集火，不降级成地面阵型落点
		return
	var lp := to_logic(p)
	var targets := _formation_targets(movers, lp, 30.0, _formation_origin(movers, queued))
	var move_cap := _group_speed_cap(movers)
	for i in range(movers.size()):
		movers[i].order_amove(targets[i], queued, move_cap)


## S：停止/原地待命——清空选中单位的指令、就地驻守
func _order_stop() -> void:
	var movers := _selected_movers()
	if movers.is_empty():
		return
	_stamp_manual(movers)
	for u in movers:
		u.order_stop()
	Sfx.play("order")
	msg("原地待命", 1.2)


## H：原地据守——停止当前命令并切到据守姿态，只攻击进入射程的敌人。
func _order_hold_position() -> void:
	var movers := _selected_movers().filter(func(u: Unit) -> bool: return not u.is_worker)
	if movers.is_empty():
		return
	_stamp_manual(movers)
	for u in movers:
		u.order_hold_position()
	Sfx.play("order")
	msg("原地据守", 1.2)
	_refresh_active_highlight()


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
	_stamp_manual(movers)
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


## 群体目标点：松散保持相对站位；方阵/横列按行军方向旋转并让近战靠前。
func _formation_targets(movers: Array, dest: Vector2, spacing := 30.0, origin := Vector2.INF) -> Array:
	var n := movers.size()
	var res: Array = []
	res.resize(n)
	if n == 0:
		return res
	if n == 1:
		res[0] = dest
		return res
	var c := Vector2.ZERO
	for u in movers:
		c += u.position
	c /= float(n)
	var from: Vector2 = c if origin == Vector2.INF else origin
	var fwd := dest - from
	fwd = fwd.normalized() if fwd.length() > 1.0 else Vector2.RIGHT
	var right := Vector2(-fwd.y, fwd.x)
	var max_r := 0.0
	for u in movers:
		max_r = maxf(max_r, u.radius)
	spacing = maxf(spacing, max_r * 2.0 + 4.0)
	if Settings.formation_mode == "loose":
		# 保留当前相对位置但收紧超大散布，类似星际式松散集结，不强制角色换排。
		for i in range(n):
			var rel: Vector2 = movers[i].position - c
			if rel.length() > 120.0:
				rel = rel.normalized() * 120.0
			var fp := dest + rel * 0.72
			if not map.is_open_world(fp):
				fp = map.cell_to_world(map.nearest_open_from(map.world_to_cell(fp), map.world_to_cell(movers[i].position)))
			res[i] = fp
		return res
	var cols := n if Settings.formation_mode == "line" else int(ceil(sqrt(float(n))))
	if Settings.formation_mode == "line" and n > 10:
		cols = int(ceil(float(n) / 2.0))   # 大队横列自动分两排，避免一字长蛇横跨半张图
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
		var fp := dest + right * cx + fwd * (-cy)   # row 0 = 最前排（朝目标）
		if not map.is_open_world(fp):
			fp = map.cell_to_world(map.nearest_open_from(map.world_to_cell(fp), map.world_to_cell(movers[mi].position)))
		res[mi] = fp
	return res


func _formation_origin(movers: Array, queued: bool) -> Vector2:
	if not queued or movers.is_empty():
		return Vector2.INF
	var c := Vector2.ZERO
	for u: Unit in movers:
		var p := u.position
		if not u._queue.is_empty():
			var last: Dictionary = u._queue[u._queue.size() - 1]
			if last.has("pos"):
				p = last["pos"]
			elif last.has("target") and is_instance_valid(last["target"]):
				p = last["target"].position
		elif not u._path.is_empty():
			p = u._path[u._path.size() - 1]
		c += p
	return c / float(movers.size())


func _form_rank(u: Unit) -> int:
	if u.is_worker:
		return 2
	if u.is_ranged:
		return 1
	return 0


func _group_speed_cap(movers: Array) -> float:
	if movers.size() <= 1:
		return 0.0
	var slow := INF
	for u: Unit in movers:
		slow = minf(slow, u.current_move_speed())
	return slow


## 巡逻等旧入口仍可在下令后直接应用队伍实际速度上限。
func _apply_group_cap(movers: Array) -> void:
	if movers.size() <= 1:
		if movers.size() == 1:
			movers[0]._group_cap = 0.0
		return
	var slow := _group_speed_cap(movers)
	for u in movers:
		u._group_cap = slow


func _enemy_at(p: Vector2) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u.faction != Unit.FACTION_GUAN or u.hp <= 0.0 or u.garrisoned or u._invis_t > 0.0:
			continue
		# 迷雾里的敌人（含只剩记忆轮廓的建筑）不可交互；可攻击地面去探，但不能锁实时目标。
		if fog and not is_visible_world(u.position):
			continue
		var d: float = to_screen(u.position).distance_to(p)
		if d <= u.radius + _click_tol(12.0) and d < best_d:
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
		if d <= u.radius + _click_tol(10.0) and d < best_d:
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
	unregister_building_footprint(bld)
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
		unregister_building_footprint(u)
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

## 驻守战英雄战绩自检（COMBAT_STATS_TEST=1 + SKIRMISH=1）：验证减伤后的实际伤害、
## 护盾、overkill 截断、召唤物归属、击杀归属、数字缩写和头像右侧三行布局。
func _combat_stats_selftest() -> void:
	var saved_tracking := track_hero_combat_stats
	var saved_stats: Dictionary = hero_combat_stats.duplicate(true)
	var saved_kills := kills
	var saved_hero_kills: Dictionary = hero_kills.duplicate(true)
	var saved_progress: Dictionary = hero_progress.duplicate(true)
	track_hero_combat_stats = true
	hero_combat_stats.erase("song_jiang")

	var origin := map.cell_to_world(map.nearest_open(level.camera_start_cell()))
	var hero := spawn_unit("song_jiang", Unit.FACTION_LIANG, origin)
	var foe_a := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(56, 0))
	var foe_b := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(72, 16))
	var foe_attacker := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(-56, 0))
	var summon := spawn_unit("tiger_summon", Unit.FACTION_LIANG, origin + Vector2(16, 48))
	summon.is_summon = true
	summon.stat_owner_key = hero.key
	var tank := spawn_unit("li_kui", Unit.FACTION_LIANG, origin + Vector2(-16, 64))
	hero_combat_stats.erase("li_kui")

	# 第一名敌人：50 护盾 + 300 生命。100 后再打 500，统计必须是实际消耗的 350，而非输入 600。
	foe_a.max_hp = 300.0
	foe_a.hp = 300.0
	foe_a._shield = 50.0
	foe_a.take_damage(100.0, hero)
	foe_a.take_damage(500.0, hero)
	# 第二名敌人由召唤物击杀，120 伤害与这一杀都应归宋江。
	foe_b.max_hp = 120.0
	foe_b.hp = 120.0
	foe_b.take_damage(200.0, summon)
	# 宋江承受 20 护盾 + 80 生命的实际伤害，共 100。
	hero._shield = 20.0
	hero.take_damage(100.0, foe_attacker)
	# 李逵 Q：100 来伤实际只掉50，但承伤记满100；W物免拦80，血不掉、承伤再加80。
	tank.max_hp = 1000.0
	tank.hp = 1000.0
	tank.apply_counted_damage_reduction(0.50, 3.0, -9001)
	tank.take_damage(100.0, foe_attacker)
	var tank_hp_after_reduction := tank.hp
	tank.absorb_physical_damage(80.0, foe_attacker)

	var rec: Dictionary = hero_combat_stat("song_jiang")
	var damage_ok := absf(float(rec.get("damage", 0.0)) - 470.0) < 0.01
	var taken_ok := absf(float(rec.get("taken", 0.0)) - 100.0) < 0.01
	var kills_ok := int(rec.get("kills", 0)) == 2
	var tank_rec: Dictionary = hero_combat_stat("li_kui")
	var mitigation_ok := absf(tank_hp_after_reduction - 950.0) < 0.01 \
			and absf(tank.hp - 950.0) < 0.01 and absf(float(tank_rec.get("taken", 0.0)) - 180.0) < 0.01
	var format_ok := hud._format_combat_stat(999.0) == "999" \
			and hud._format_combat_stat(1000.0) == "1.0k" \
			and hud._format_combat_stat(1250.0) == "1.3k" \
			and hud._format_combat_stat(1000000.0) == "1.0M" \
			and hud._format_combat_stat(12340000.0) == "12.3M"
	hud._refresh_hero_bar()
	var layout_ok := false
	for child in hud._hero_bar.get_children():
		if child.get("hero") == hero:
			layout_ok = bool(child.get("show_combat_stats")) \
					and child.custom_minimum_size.x >= child.custom_minimum_size.y + 100.0
			break
	var all_ok := damage_ok and taken_ok and kills_ok and mitigation_ok and format_ok and layout_ok
	print("[combatstats] damage=%.0f/%s taken=%.0f/%s kills=%d/%s mitigation=%s summon_owner=%s format=%s layout=%s ALL=%s" % [
		float(rec.get("damage", 0.0)), damage_ok, float(rec.get("taken", 0.0)), taken_ok,
		int(rec.get("kills", 0)), kills_ok, mitigation_ok, damage_ok and kills_ok, format_ok, layout_ok, all_ok])
	if OS.get_environment("COMBAT_STATS_KEEP") == "1":
		return   # 有窗口截图时保留非零样例；进程退出即销毁，不影响存档。

	track_hero_combat_stats = false
	for probe in [hero, foe_a, foe_b, foe_attacker, summon, tank]:
		if probe != null and is_instance_valid(probe):
			units.erase(probe)
			probe.queue_free()
	hero_combat_stats = saved_stats
	kills = saved_kills
	hero_kills = saved_hero_kills
	hero_progress = saved_progress
	track_hero_combat_stats = saved_tracking
	hud._hero_keys = []
	hud._refresh_hero_bar()


## 花荣重做确定性自检（HUA_REWORK_TEST=1）：覆盖 Q/W/E/R 数值、E 无限射程五连珠、R 蓄力/处决/DOT 与 AI 目标层级。
func _hua_rework_selftest() -> void:
	var saved_fog := fog
	fog = false
	var origin := map.cell_to_world(map.nearest_open(level.camera_start_cell()))
	var hua := spawn_unit("hua_rong", Unit.FACTION_LIANG, origin)
	var lane := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(150, 0))
	var pin_target := spawn_unit("guan_musket", Unit.FACTION_GUAN, origin + Vector2(280, 20))
	var enemy_hero := spawn_unit("hu_yanzhuo", Unit.FACTION_GUAN, origin + Vector2(360, -20))
	var cata := spawn_unit("siege_cata", Unit.FACTION_GUAN, origin + Vector2(300, 60))
	var probes := [hua, lane, pin_target, enemy_hero, cata]
	for i in hua.ability_slots.size():
		hua.ability_slots[i]["rank"] = 3
		hua.ability_slots[i]["cd_t"] = 0.0
	# Q：穿过敌人也不再造成伤害；落地获得 90% 闪避、1.5× 移速，持续 5 秒。
	lane.max_hp = 1000.0
	lane.hp = 1000.0
	var lane_hp := lane.hp
	_do_ability(hua, 0, origin + Vector2(300, 0))
	var q_ok := absf(lane.hp - lane_hp) < 0.01 and absf(hua.current_evasion() - 0.90) < 0.001 \
			and absf(hua._temp_move_boost - 1.50) < 0.001 and absf(hua._temp_evasion_t - 5.0) < 0.01
	# W：原 100 半径/伤害保留，新增 50% 减速 3 秒。
	hua.position = origin
	hua.ability_slots[1]["cd_t"] = 0.0
	lane.position = origin + Vector2(40, 0)
	lane.temp_speed = 1.0
	var w_before := lane.hp
	_do_ability(hua, 1, lane.position)
	var w_expected := 28.0 * (0.6 + 0.4 * 3.0) * _hero_db(hua)
	var w_ok := absf((w_before - lane.hp) - w_expected) < 0.05 and absf(lane.temp_speed - 0.5) < 0.001 \
			and absf(lane._temp_speed_t - 3.0) < 0.01
	# E：无限施法距离、43 伤/3 秒定身、五次跨距普攻锁定。
	hua.ability_slots[2]["cd_t"] = 0.0
	pin_target.max_hp = 1000.0
	pin_target.hp = 1000.0
	pin_target.position = origin + Vector2(1800, 0)
	var e_before := pin_target.hp
	var e_range_ok := ability_cast_range(hua, _abilities["hua_pin"]) == INF
	_do_ability(hua, 2, pin_target.position, pin_target)
	var e_damage_expected := 43.0 * _hero_db(hua)
	var e_state_ok := absf((e_before - pin_target.hp) - e_damage_expected) < 0.05 \
			and absf(pin_target._root_t - 3.0) < 0.01 and hua._hua_lock_target == pin_target and hua._hua_lock_shots == 5
	hua._cd = 0.0
	hua._lunge = 0.0
	hua._do_chase(0.016)
	var e_cross_range_ok := hua._pending_target == pin_target and hua._lunge > 0.0
	for i in range(5):
		hua._consume_hua_locked_attack(pin_target)
	var e_ok := e_range_ok and e_state_ok and e_cross_range_ok and not hua.hua_lock_active()
	# R：起手恰为 1 秒；敌将先掉 30%，再按 5% 最大生命跳 5 次；投石车直接处决。
	enemy_hero.max_hp = 1000.0
	enemy_hero.hp = 1000.0
	hua.ability_slots[3]["cd_t"] = 0.0
	_begin_cast(hua, 3, enemy_hero.position, enemy_hero)
	var windup_ok := absf(hua._cast_t - 1.0) < 0.01 and _pending_has(hua, 3)
	hua.cancel_cast_windup()
	_pending_casts = _pending_casts.filter(func(pc): return pc.get("caster") != hua)
	hua.ability_slots[3]["cd_t"] = 0.0
	_do_ability(hua, 3, enemy_hero.position, enemy_hero)
	var r_burst_ok := absf(enemy_hero.hp - 700.0) < 0.05 and not _hua_snipe_dots.is_empty()
	for i in range(5):
		_hua_snipe_dot_pass(1.0)
	var r_dot_ok := absf(enemy_hero.hp - 450.0) < 0.1 and _hua_snipe_dots.is_empty()
	# 高价值层级：英雄压过更近的投石车；英雄移走后投石车压过火枪手。
	var ai_origin := origin + Vector2(0, 6000)
	hua.position = ai_origin
	lane.position = ai_origin + Vector2(2000, 0)
	enemy_hero.position = ai_origin + Vector2(500, 0)
	cata.position = ai_origin + Vector2(120, 0)
	pin_target.position = ai_origin + Vector2(80, 0)
	var ai_hero_ok := _hua_high_value_target(hua, INF) == enemy_hero
	enemy_hero.position = ai_origin + Vector2(10000, 0)
	var ai_cata_ok := _hua_high_value_target(hua, 760.0) == cata
	cata.max_hp = 1000.0
	cata.hp = 1000.0
	hua.ability_slots[3]["cd_t"] = 0.0
	_do_ability(hua, 3, cata.position, cata)
	var execute_ok := cata.hp <= 0.0
	var r_cd_ok := absf(float(_abilities["hua_blade"]["cd_ranks"][2]) - 18.0) < 0.001
	var r_ok := windup_ok and r_burst_ok and r_dot_ok and execute_ok and r_cd_ok
	var all_ok := q_ok and w_ok and e_ok and r_ok and ai_hero_ok and ai_cata_ok
	print("[huarework] Q=%s W=%s E(range=%s state=%s five=%s)=%s R(windup=%s burst=%s dot=%s execute=%s cd=%s)=%s AI(hero=%s cata=%s) ALL=%s" % [
		q_ok, w_ok, e_range_ok, e_state_ok, e_cross_range_ok, e_ok, windup_ok, r_burst_ok, r_dot_ok,
		execute_ok, r_cd_ok, r_ok, ai_hero_ok, ai_cata_ok, all_ok])
	_ground_dots = _ground_dots.filter(func(d): return d.get("caster") != hua)
	_hua_snipe_dots = _hua_snipe_dots.filter(func(d): return d.get("caster") != hua)
	_pending_casts = _pending_casts.filter(func(pc): return pc.get("caster") != hua)
	for probe in probes:
		if probe != null and is_instance_valid(probe):
			units.erase(probe)
			probe.queue_free()
	fog = saved_fog


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
	print("[ability] %s slots=%d cd/slot ok=%s order_ok=%s" % [caster.key, caster.slot_count(), cd_started, order_ok])


## 技能系统 V2 自检（KIT2_TEST=1 + ARENA=1）：验证三轴新原语——单体追踪弹(bolt)、钩镰拖回(hook)、
## 换位(swap)、缠绕(root)、缴械(disarm)、走近施法(walk-cast)。弹道用 _bolt_pass 手动步进模拟。
func _kit2_selftest() -> void:
	if map == null:
		print("[kit2] no map")
		return
	var results: Array = []
	# 1) bolt·红锦套索：单体追踪弹命中远敌 → 掉血 + 眩晕（骑手走 _apply_riders）
	var hu := _rwt_hero("hu_sanniang", Vector2i(8, 8))
	var f1 := _rwt_foe(Vector2i(14, 8))
	f1.max_hp = 600.0
	f1.hp = 600.0
	_do_ability(hu, 1, f1.position, f1)
	for i in range(120):
		_bolt_pass(0.05)
	results.append(["bolt_hits", f1.hp < 600.0 and f1._stun_t > 0.0])
	# 2) swap·乾坤挪移：与目标瞬间互换位置
	hu.ability_slots[3]["cd_t"] = 0.0
	f1._stun_t = 0.0
	var pa: Vector2 = hu.position
	var pb: Vector2 = f1.position
	_do_ability(hu, 3, f1.position, f1)
	results.append(["swap_positions", hu.position.distance_to(pb) < 24.0 and f1.position.distance_to(pa) < 24.0])
	# 3) hook·钩镰拖钩：钩头贯线飞出，钩中敌人拖回身前
	var pq := _rwt_hero("peng_qi", Vector2i(24, 8))
	var f2 := _rwt_foe(Vector2i(31, 8))
	f2.max_hp = 600.0
	f2.hp = 600.0
	_grid_build()   # 钩头找目标走 units_near（空间网格）——选测没有引擎帧，手动建一次
	_do_ability(pq, 0, f2.position)
	for i in range(160):
		_bolt_pass(0.05)
	results.append(["hook_drags", f2.position.distance_to(pq.position) < 90.0 and f2.hp < 600.0])
	# 4) root·缠绕：定身不能移动（可反击），_follow_path 原地不动
	var f3 := _rwt_foe(Vector2i(8, 20))
	f3.apply_root(5.0)
	var p0: Vector2 = f3.position
	f3.order_move(p0 + Vector2(160, 0))
	for i in range(10):
		f3._follow_path(0.1)
	results.append(["root_pins", f3.position.distance_to(p0) < 1.0 and f3._root_t > 0.0])
	# 5) disarm·缴械：出不了手（_attack 直接返回，不起挥击）
	var f4 := _rwt_foe(Vector2i(10, 20))
	var vic := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(Vector2i(11, 20))))
	f4.apply_disarm(5.0)
	f4._target = vic
	f4._cd = 0.0
	f4._attack()
	results.append(["disarm_blocks", f4._lunge <= 0.0])
	# 6) walk-cast·走近施法：单体技能点了超射程目标 → 自动接近，进射程后进入抬手
	var hu2 := _rwt_hero("hu_sanniang", Vector2i(8, 30))
	var f5 := _rwt_foe(Vector2i(28, 30))   # 20 格 = 640px，超出 380 施法距离
	hu2.ability_slots[1]["cd_t"] = 0.0
	_queue_walk_cast(hu2, 1, f5)
	var casted := false
	for i in range(600):
		_walk_cast_pass(0.1)
		hu2._physics_process(0.1)
		for pc in _pending_casts:
			if pc["caster"] == hu2:
				casted = true
				break
		if casted:
			break
	results.append(["walk_cast", casted])
	# 7) taunt·嘲讽：索超 Q 强制周围之敌撇下原指令、转火自己（验证压过玩家移动令）
	var suo := _rwt_hero("suo_chao", Vector2i(8, 40))
	var t1 := _rwt_foe(Vector2i(11, 40))   # ≈3 格，在 Q 半径 180 内
	var t2 := _rwt_foe(Vector2i(10, 42))
	t1.order_move(t1.position + Vector2(300, 0))   # 先下走开令，再看嘲讽能否夺回
	t2.order_move(t2.position + Vector2(300, 0))
	suo.ability_slots[0]["cd_t"] = 0.0
	_do_ability(suo, 0, suo.position)   # Q targeted:false → 以自身为圆心
	results.append(["taunt_forces", t1._target == suo and t1._taunt_t > 0.0 and t2._target == suo and t2._taunt_t > 0.0])
	# 8) bolt_line·非追踪直线弹（可躲）：命中弹道上的敌人；偏离弹道者毫发无伤（证明非追踪=可走位躲）
	var zq := _rwt_hero("zhang_qing", Vector2i(8, 50))
	var online := _rwt_foe(Vector2i(16, 50))   # 正前方一线（同行）
	online.max_hp = 800.0; online.hp = 800.0
	var offline := _rwt_foe(Vector2i(16, 45))  # 偏离弹道 5 格（≈160px，远超弹宽）
	offline.max_hp = 800.0; offline.hp = 800.0
	_grid_build()
	zq.ability_slots[0]["cd_t"] = 0.0
	_do_ability(zq, 0, zq.position + Vector2(640, 0))   # 朝正前方（online 所在行）掷石
	for i in range(160):
		_bolt_pass(0.05)
	results.append(["bolt_line_hits", online.hp < 800.0 and online._stun_t > 0.0 and offline.hp >= 800.0])
	# 9) channel·引导施法（凌振轰天连炮）：定身逐 tick 轰击；被眩晕即断→效果停止
	var lz := _rwt_hero("ling_zhen", Vector2i(8, 60))
	var cf := _rwt_foe(Vector2i(11, 60))
	cf.max_hp = 2000.0; cf.hp = 2000.0
	_grid_build()
	lz.ability_slots[0]["cd_t"] = 0.0
	_do_ability(lz, 0, cf.position)     # channel 落点 = 敌处
	for i in range(8):
		_channel_pass(0.25)             # 步进 ~2s：多轮落弹
	var hp_mid := cf.hp
	var channeling := lz._channel_t > 0.0
	lz.apply_stun(1.0)                  # 眩晕打断引导 → _channel_t=0
	var broke := lz._channel_t <= 0.0
	for i in range(8):
		_channel_pass(0.25)             # 断后继续步进：不应再掉血
	results.append(["channel_ticks_breaks", hp_mid < 2000.0 and channeling and broke and absf(cf.hp - hp_mid) < 0.01])
	# 10) invis·主动隐身（时迁化形散身）：隐身后敌方索敌点不到；出手即破隐
	var sq := _rwt_hero("shi_qian", Vector2i(8, 63))
	var seeker := _rwt_foe(Vector2i(10, 63))   # 近处敌人：若非隐身本会索敌到 sq
	_grid_build()
	sq.ability_slots[2]["cd_t"] = 0.0
	_do_ability(sq, 2, sq.position)            # E = invis（targeted:false 自身）
	seeker._target = null
	seeker._acquire(400.0)                      # 敌人尝试索敌
	var unseen := sq._invis_t > 0.0 and seeker._target != sq
	sq._target = seeker                         # 出手破隐：给目标并攻击
	sq._cd = 0.0
	sq._attack()
	results.append(["invis_hides_breaks", unseen and sq._invis_t <= 0.0])
	# 11) aura leveling·光环随技能等级（呼延灼连环马·攻击光环 aura_power_ranks）
	var hy := _rwt_hero("hu_yanzhuo", Vector2i(8, 36))
	hy.ability_slots[1]["rank"] = 1
	hy._recompute_hero_stats()
	var ap1 := hy.aura_power
	hy.ability_slots[1]["rank"] = 3
	hy._recompute_hero_stats()
	results.append(["aura_scales_rank", hy.aura_power > ap1 + 0.05])
	# 12) dispel·净化/驱散（安道全神医解控 + 樊瑞驱敌方增益）
	var an := _rwt_hero("an_daoquan", Vector2i(40, 40))
	var friend := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(Vector2i(41, 40))))
	friend.apply_stun(3.0); friend.apply_root(3.0)
	an.ability_slots[1]["cd_t"] = 0.0
	_do_ability(an, 1, an.position)             # W：护盾 + 净化友军减益
	var cleansed := friend._stun_t <= 0.0 and friend._root_t <= 0.0 and friend._shield > 0.0
	var fr := _rwt_hero("fan_rui", Vector2i(40, 44))
	var foeb := _rwt_foe(Vector2i(41, 44))
	foeb.apply_shield(200.0, 8.0); foeb.apply_temp_atk(1.5, 8.0)
	_grid_build()
	fr.ability_slots[1]["cd_t"] = 0.0
	_do_ability(fr, 1, foeb.position)           # W：smite amp + 驱敌方增益
	var stripped := foeb._shield <= 0.0 and foeb.temp_atk <= 1.01
	results.append(["dispel_cleanse_strip", cleansed and stripped])
	# 13) hex·变形术（童猛妖蜃幻形）：单体点控 = 沉默+缴械+减速+替身；且只变目标一人（旁边的不受影响）
	var tm := _rwt_hero("tong_meng", Vector2i(40, 48))
	var hv := _rwt_foe(Vector2i(41, 48))
	var bystander := _rwt_foe(Vector2i(42, 48))   # 紧挨目标：验证 hex 单体、不波及旁人
	_grid_build()
	tm.ability_slots[1]["cd_t"] = 0.0
	_do_ability(tm, 1, hv.position, hv)          # W = 单体指向 smite + hex
	var hexed := hv._silence_t > 0.0 and hv._disarm_t > 0.0 and hv.temp_speed < 1.0 and hv._hex_t > 0.0
	results.append(["hex_single_target", hexed and bystander._hex_t <= 0.0 and bystander._silence_t <= 0.0])
	# 14) transform·变身（燕顺化身猛虎）：临时换形态提攻/攻速/移速，到期精确还原
	var ys := _rwt_hero("yan_shun", Vector2i(40, 52))
	ys._recompute_hero_stats()                  # 确保基线已含满级被动（再比对还原）
	var atk0 := ys.atk
	var cd0 := ys.atk_cd
	var spd0 := ys.base_speed
	ys.ability_slots[3]["cd_t"] = 0.0
	_do_ability(ys, 3, ys.position)             # R = transform
	var inform := ys.atk > atk0 + 0.5 and ys.atk_cd < cd0 - 0.01 and ys.base_speed > spd0 + 0.5 and ys._form_t > 0.0
	ys._form_t = 0.05
	ys._phys_body(0.1)                          # 步进触发到期还原
	var restored := absf(ys.atk - atk0) < 0.5 and absf(ys.atk_cd - cd0) < 0.01 and absf(ys.base_speed - spd0) < 0.5 and ys._form_t <= 0.0
	results.append(["transform_form_restores", inform and restored])
	var okn := 0
	for rr in results:
		if bool(rr[1]):
			okn += 1
	print("[kit2] %s ALL=%s (%d/%d)" % [str(results), okn == results.size(), okn, results.size()])


## 第二批返工自检（REWORK_TEST=1）：逐一验证 10 个「兑现宣称」机制是否真的生效——
## 不只是「不崩」，而是把效果跑出来后断言血量/区域/分身等状态确有改变。
func _rwt_hero(key: String, cell: Vector2i) -> Unit:
	var h := spawn_unit(key, Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(cell)))
	if h == null:
		return null
	if h.ability_slots.is_empty():
		for aid in Defs.UNITS[key].get("abilities", []):
			var adx: Dictionary = _abilities.get(String(aid), {})
			h.ability_slots.append({"id": String(aid), "rank": 3, "cd_t": 0.0, "passive": bool(adx.get("passive", false))})
	for si in h.slot_count():
		h.ability_slots[si]["rank"] = 3
		h.ability_slots[si]["cd_t"] = 0.0
	return h


func _rwt_foe(cell: Vector2i) -> Unit:
	return spawn_unit("guan_dao", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(cell)))


func _rework_selftest() -> void:
	if map == null:
		print("[rework] no map"); return
	var pass_n := 0
	var fail := []
	# 1) 卢俊义 W·治疗桩：插桩后对受伤友军续血（非一次性）
	var lj := _rwt_hero("lu_junyi", Vector2i(8, 8))
	var ally := spawn_unit("liang_qiang", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(Vector2i(9, 8))))
	if lj != null and ally != null:
		ally.hp = 10.0
		_do_ability(lj, 1, ally.position)
		_ward_pass(1.2)
		_ward_pass(1.2)
		if not _wards.is_empty() and ally.hp > 10.0:
			pass_n += 1
		else:
			fail.append("治疗桩 wards=%d hp=%.0f" % [_wards.size(), ally.hp])
	# 2) 侯健 R·死神之眼：攻击桩连珠射敌
	var hj := _rwt_hero("hou_jian", Vector2i(8, 12))
	var f2 := _rwt_foe(Vector2i(10, 12))
	if hj != null and f2 != null:
		var hp0: float = f2.hp
		_do_ability(hj, 3, f2.position)
		_ward_pass(0.5)
		if f2.hp < hp0:
			pass_n += 1
		else:
			fail.append("死神之眼桩未射敌")
	# 3) 张青(菜)E·毒桩：射敌+减速
	var zqc := _rwt_hero("zhang_qing_cai", Vector2i(8, 16))
	var f3 := _rwt_foe(Vector2i(10, 16))
	if zqc != null and f3 != null:
		var hp0b: float = f3.hp
		_do_ability(zqc, 2, f3.position)
		_ward_pass(0.6)
		if f3.hp < hp0b:
			pass_n += 1
		else:
			fail.append("毒桩未射敌")
	# 4) 董平 R·百枪分身：生成「长得像董平」的幻象(非老虎)
	var dp := _rwt_hero("dong_ping", Vector2i(8, 20))
	if dp != null:
		_do_ability(dp, 3, dp.position)
		var imgs := 0
		for u in units:
			if is_instance_valid(u) and u.key == "dong_ping" and u.is_summon and not u.is_hero:
				imgs += 1
		if imgs >= 1:
			pass_n += 1
		else:
			fail.append("分身非本体形象 imgs=%d" % imgs)
	# 5) 鲁智深 Q·裂地：贯穿伤+晕+生成阻路实墙
	var lz := _rwt_hero("lu_zhishen", Vector2i(14, 8))
	var f5 := _rwt_foe(Vector2i(16, 8))
	if lz != null and f5 != null:
		var walls0 := _ice_walls.size()
		var hp5: float = f5.hp
		_do_ability(lz, 0, f5.position)
		if _ice_walls.size() > walls0 and f5.hp < hp5 and f5._stun_t > 0.0:
			pass_n += 1
		else:
			fail.append("裂地 wall+%d dmg=%.0f stun=%.1f" % [_ice_walls.size() - walls0, hp5 - f5.hp, f5._stun_t])
	# 6) 鲁智深 R·回音：敌越密每人受创越重（4 敌 vs 1 敌对比）
	var lz1 := _rwt_hero("lu_zhishen", Vector2i(14, 12))
	var lone := _rwt_foe(Vector2i(14, 13))
	var dmg_lone := 0.0
	if lz1 != null and lone != null:
		lone.max_hp = 800.0
		lone.hp = 800.0
		var h0: float = lone.hp
		_do_ability(lz1, 3, lz1.position)
		dmg_lone = h0 - lone.hp
	var lz4 := _rwt_hero("lu_zhishen", Vector2i(20, 20))
	var crowd: Array = []
	for ci in range(4):
		var cf := _rwt_foe(Vector2i(20 + ci % 2, 20 + ci / 2))
		if cf != null:
			cf.max_hp = 800.0
			cf.hp = 800.0
			crowd.append(cf)
	if lz4 != null and crowd.size() == 4:
		var hp_before: float = crowd[0].hp
		_do_ability(lz4, 3, lz4.position)
		var dmg_crowd: float = hp_before - crowd[0].hp
		if dmg_crowd > dmg_lone + 1.0:
			pass_n += 1
		else:
			fail.append("回音未随密度增伤 lone=%.0f crowd=%.0f" % [dmg_lone, dmg_crowd])
	# 7) 樊瑞 W·摄魂咒：易伤(受伤大增)
	var fr := _rwt_hero("fan_rui", Vector2i(14, 16))
	var f7 := _rwt_foe(Vector2i(15, 16))
	if fr != null and f7 != null:
		f7.max_hp = 800.0
		f7.hp = 800.0
		_do_ability(fr, 1, f7.position)
		if f7._dmg_amp > 0.0:
			var hpa: float = f7.hp
			f7.take_damage(100.0, fr)
			if (hpa - f7.hp) > 120.0:   # 100×(1+0.3)=130
				pass_n += 1
			else:
				fail.append("易伤未放大伤害 d=%.0f" % (hpa - f7.hp))
		else:
			fail.append("易伤未施加")
	# 8) 安道全 E·影波：伤敌同时愈友
	var adq := _rwt_hero("an_daoquan", Vector2i(14, 20))
	var wally := spawn_unit("liang_qiang", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(Vector2i(15, 20))))
	var f8 := _rwt_foe(Vector2i(16, 20))
	if adq != null and wally != null and f8 != null:
		wally.hp = 20.0
		var fhp: float = f8.hp
		_do_ability(adq, 2, adq.position)
		if wally.hp > 20.0 and f8.hp < fhp:
			pass_n += 1
		else:
			fail.append("影波 heal=%.0f foeDmg=%.0f" % [wally.hp - 20.0, fhp - f8.hp])
	# 9) 魏定国 E·火径：随身落地火（_fire_trails + 推帧后 _ground_dots 增长）
	var wdg := _rwt_hero("wei_dingguo", Vector2i(26, 8))
	if wdg != null:
		var ft0 := _fire_trails.size()
		var gd0 := _ground_dots.size()
		_do_ability(wdg, 2, wdg.position)
		_trail_pass(0.35)
		if _fire_trails.size() > ft0 and _ground_dots.size() > gd0:
			pass_n += 1
		else:
			fail.append("火径未铺地火 trails+%d dots+%d" % [_fire_trails.size() - ft0, _ground_dots.size() - gd0])
	# 10) 解珍 R·一线长焰：沿线铺多处地火
	var xz := _rwt_hero("xie_zhen", Vector2i(26, 12))
	if xz != null:
		var gdl := _ground_dots.size()
		_do_ability(xz, 3, map.cell_to_world(map.nearest_open(Vector2i(31, 12))))
		if _ground_dots.size() - gdl >= 3:
			pass_n += 1
		else:
			fail.append("一线火 patches=%d" % (_ground_dots.size() - gdl))
	print("[rework] %d/10 机制已验证生效" % pass_n)
	if not fail.is_empty():
		print("[rework] FAIL: %s" % ", ".join(fail))


## headless 自检（DOTACAST=1 + SKIRMISH=1）：逐一生成每个 DOTA 英雄、升满 4 技能、
## 朝靶子结算每个技能，确认 _do_ability 不会因缺字段/坏数据崩。跑完打印 OK 即全部通过。
func _dota_cast_selftest() -> void:
	if map == null:
		print("[dota] no map"); return
	var base: Vector2i = map.nearest_open(Vector2i(20, 20))
	var foes: Array = []
	for i in range(6):
		var fu := spawn_unit("guan_dao", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(base + Vector2i(2 + i % 3, 2 + i / 3))))
		if fu != null:
			foes.append(fu)
	var tgt: Vector2 = (foes[0].position if not foes.is_empty() else map.cell_to_world(base))
	var nh := 0
	var ncast := 0
	for key in Defs.UNITS.keys():
		var d: Dictionary = Defs.UNITS[key]
		if not bool(d.get("hero_trainable", false)) or not d.has("abilities"):
			continue
		var h := spawn_unit(String(key), Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-3, 0))))
		if h == null:
			continue
		nh += 1
		if h.ability_slots.is_empty():
			for aid in d["abilities"]:
				var adx: Dictionary = _abilities.get(String(aid), {})
				h.ability_slots.append({"id": String(aid), "rank": 3, "cd_t": 0.0, "passive": bool(adx.get("passive", false))})
		for si in range(h.slot_count()):
			h.ability_slots[si]["rank"] = 3
		for si in range(h.slot_count()):
			h.ability_slots[si]["cd_t"] = 0.0
			_do_ability(h, si, tgt)
			ncast += 1
		h.position = map.cell_to_world(map.nearest_open(base + Vector2i(-8, 0)))   # 挪开堆叠，不释放(避免悬挂引用噪声)
	# 聚义厅点将「分类二级菜单」逻辑自检：直接喂合成英雄表（绕过"在场英雄不显示"过滤，因自检已把 108 将全铺场上）
	var hall := find_unit("hall")
	if hall != null:
		var fake: Array = []
		for st in [5, 20, 50, 90]:   # 天罡×2 / 地煞上×1 / 地煞下×1
			fake.append({"kind": "train", "key": "x", "label": "t", "_star": st, "cost_g": 0, "cost_w": 0, "affordable": true, "bld": hall})
		_hall_cat = ""
		var root_cats := 0
		for e in _hall_cat_menu(hall, [], fake.duplicate()):
			if String(e.get("kind", "")) == "hall_cat":
				root_cats += 1
		_hall_cat = "tiangang"
		var cat_trains := 0
		var has_back := false
		for e in _hall_cat_menu(hall, [], fake.duplicate()):
			if String(e.get("kind", "")) == "train":
				cat_trains += 1
			elif String(e.get("kind", "")) == "hall_cat" and String(e.get("cat", "")) == "":
				has_back = true
		_hall_cat = ""
		_hall_page = 0
		print("[dota] hall cat_menu: root_cats=%d tiangang_trains=%d back=%s (want 3/2/true)" % [root_cats, cat_trains, str(has_back)])
	# 渲染每个技能的「悬浮说明 + 1/2/3级速览」——覆盖 ability_levels/ability_desc 路径(此前漏测，def_down 标量曾在此崩)
	for aid in Defs.ABILITIES.keys():
		var _t1 := Defs.ability_levels(String(aid))
		var _t2 := Defs.ability_desc(String(aid), 3)
	print("[dota] tooltip render OK: %d abilities" % Defs.ABILITIES.size())
	if level != null and level.has_method("arena_spawn_troops"):
		var e0 := enemies_alive()
		arena_spawn_troops()
		arena_spawn_random()
		print("[dota] arena_spawn OK: enemies %d→%d" % [e0, enemies_alive()])
	print("[dota] cast_selftest OK: heroes=%d casts=%d (no crash)" % [nh, ncast])


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
	# 科技互斥 + 马军：有生产队列时应静默拒绝，不能启动研究。
	var research_blocked := hall != null and not queue_research(hall, "tech_gather", false)
	var cav := spawn_unit("liang_ma", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(base + Vector2i(-2, 2))))
	print("[econ] cav liang_ma hp=%d cavalry=%s | production_blocks_research=%s" % [int(cav.max_hp), cav.is_cavalry, research_blocked])
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
	var aggro_sees_far := cu._target != null
	cu.set_stance(Unit.STANCE_DEFEND)
	cu.order_hold_position()
	var hold_cmd := cu._hold_order_active and cu.stance == Unit.STANCE_HOLD
	cu.order_move(cu.position + Vector2(40, 0))
	var hold_releases := not cu._hold_order_active and cu.stance == Unit.STANCE_DEFEND
	cu.order_patrol(map.cell_to_world(map.nearest_open(base + Vector2i(6, 3))))
	print("[command] stop_ok=%s hold_ignores_far=%s aggro_sees_far=%s hold_cmd=%s releases=%s patrol_on=%s state=%d" % [
		stop_ok, hold_ignores_far, aggro_sees_far, hold_cmd, hold_releases, cu._patrolling, cu._state])
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
	var dcell := Vector2i(-1, -1)
	var dhalf := building_footprint_half("depot")
	for r in range(3, 13):
		var cand := base + Vector2i(-r, -5)
		if map.area_buildable(cand, dhalf) and not _building_overlap(cand, dhalf):
			dcell = cand
			break
	if dcell.x < 0:
		for y in range(dhalf + 1, map.h - dhalf - 1, 3):
			for x in range(dhalf + 1, map.w - dhalf - 1, 3):
				var cand := Vector2i(x, y)
				if map.area_buildable(cand, dhalf) and not _building_overlap(cand, dhalf):
					dcell = cand
					break
			if dcell.x >= 0:
				break
	if dcell.x < 0:
		dcell = map.nearest_open(base + Vector2i(-2, -5))
	var dbld := spawn_unit("depot", Unit.FACTION_LIANG, map.cell_to_world(dcell))
	dbld.is_constructing = false
	dbld.hp = dbld.max_hp
	dbld.set_meta("fcell", dcell)
	dbld.set_meta("fhalf", dhalf)
	register_building_footprint(dbld)
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
	var old_form: String = Settings.formation_mode
	Settings.formation_mode = "box"
	var ftargets := _formation_targets(fm, fdest)
	Settings.formation_mode = old_form
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
		slowest = minf(slowest, u.current_move_speed())
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
	# 迷雾自检（仅 fog 开启的模式）：明亮=实时可见、离开立即转阴影、技能侦察到点即退、建筑记忆
	if fog:
		var fc := map.world_to_cell(mu.position)
		var idx := fc.y * map.w + fc.x
		# 强制实时照亮该格：地面明亮，普通敌军也应可见。
		_sight_now.fill(0)
		_sight_now[idx] = 1
		_reveal_t[idx] = 0.0
		_force_fog_decay(FOG_STEP)
		var live_is_bright := is_visible_world(map.cell_to_world(fc)) and is_lit_world(map.cell_to_world(fc))
		# 单位离开：下一拍必须同时失去普通敌军可见性并转为阴影，不能留下“亮地藏人”。
		_sight_now[idx] = 0
		_force_fog_decay(FOG_STEP)
		var leave_is_shadow := not is_visible_world(map.cell_to_world(fc)) \
				and not is_lit_world(map.cell_to_world(fc)) and _vision[idx] == 1
		# 技能临时开视野：持续期内能看见，到点必须立即回阴影。
		_vision[idx] = 0
		_reveal_t[idx] = 0.0
		var p := map.cell_to_world(fc)
		_reveal_fog_at(p, 1.0, 0.30)
		var reveal_now := is_visible_world(p) and _vision[idx] == 2
		_force_fog_decay(FOG_STEP)
		_force_fog_decay(FOG_STEP)
		var reveal_expires := not is_visible_world(p) and not is_lit_world(p) and _vision[idx] == 1
		# 建筑记忆：该格已探明（vision==1）→ 建筑应保留可见、普通敌人应隐去（纯判定，不生成单位）
		var bld_remembered := is_explored_world(p)     # 建筑：探明即保留
		var foe_hidden := not is_visible_world(p)       # 普通敌人：非明亮即隐去
		# 出生帧不能信上一拍缓存：人为制造“缓存说可见、当前没有任何友军视野”，新刷敌军仍必须隐藏。
		var stale_spawn_hidden := false
		var dark_cell := Vector2i(-1, -1)
		for fy in range(0, map.h, 4):
			for fx in range(0, map.w, 4):
				var candidate := Vector2i(fx, fy)
				if not _has_live_sight_at(map.cell_to_world(candidate)):
					dark_cell = candidate
					break
			if dark_cell.x >= 0:
				break
		if dark_cell.x >= 0:
			var didx := dark_cell.y * map.w + dark_cell.x
			var old_sight := _sight_now[didx]
			_sight_now[didx] = 1                      # 故意留下错误的旧缓存
			var cached_claims_visible := is_visible_world(map.cell_to_world(dark_cell))
			var hidden_spawn := spawn_unit("guan_dao", Unit.FACTION_GUAN, map.cell_to_world(dark_cell))
			stale_spawn_hidden = cached_claims_visible and not hidden_spawn.fog_visible and not hidden_spawn.visible
			units.erase(hidden_spawn); hidden_spawn.queue_free()
			_sight_now[didx] = old_sight
		var fog_ok := live_is_bright and leave_is_shadow and reveal_now and reveal_expires \
				and bld_remembered and foe_hidden and stale_spawn_hidden
		print("[fog] sight_unit=%d sight_bld=%d live_bright=%s leave_shadow=%s reveal_now=%s reveal_expires=%s bld_remembered=%s foe_hidden=%s stale_spawn_hidden=%s ALL=%s" % [
			8, 10, live_is_bright, leave_is_shadow, reveal_now, reveal_expires, bld_remembered, foe_hidden,
			stale_spawn_hidden, fog_ok])


## 全托管研究互斥自检（ECO_RESEARCH_TEST=1）：不跑时间，确定性验证双向互斥、重复科技、兵营选择与预算预留。
func _eco_research_selftest() -> void:
	var hall := main_base(Unit.FACTION_LIANG)
	if hall == null:
		print("[ecoresearch] ALL=false reason=no_hall")
		return
	var saved_gold := gold
	var saved_wood := wood
	var saved_pop := pop_cap
	var saved_age := current_age
	var saved_done := _tech_done.duplicate(true)
	var saved_queue := hall._train_queue.duplicate()
	var saved_train_t := hall._train_t
	var saved_research := hall._research_key
	var saved_research_t := hall._research_t
	gold = 1000; wood = 1000; pop_cap = 999; current_age = 1; _tech_done = {}
	hall._train_queue.clear(); hall._research_key = ""; hall._research_t = 0.0

	var trained := queue_train(hall, "lou_luo", false)
	var production_blocks := _research_block_reason(hall, "tech_gather") == "production" \
		and not queue_research(hall, "tech_gather", false)
	hall._train_queue.clear()
	var research_started := queue_research(hall, "tech_gather", false)
	var research_blocks_train := _train_block_reason(hall, "lou_luo") == "researching" \
		and not queue_train(hall, "lou_luo", false)

	var origin := map.world_to_cell(hall.position)
	var hall2 := spawn_unit("hall", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(origin + Vector2i(7, 0))))
	var duplicate_blocks := _research_block_reason(hall2, "tech_gather") == "in_progress" \
		and not queue_research(hall2, "tech_gather", false)
	var bar1 := spawn_unit("barracks", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(origin + Vector2i(8, 3))))
	var bar2 := spawn_unit("barracks", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(origin + Vector2i(10, 3))))
	bar1._train_queue = ["liang_dao", "liang_gong"]
	bar2._train_queue.clear()
	var picked := _eco_research_barracks()
	var picks_shortest := picked != null and picked._train_queue.is_empty()
	var reserved := {}
	if picked != null:
		reserved[picked.get_instance_id()] = true
	var skips_reserved := picked == null or _eco_idle_barracks(reserved) != picked
	gold = 100; wood = 100
	var reserve_blocks_spend := not _eco_can_spend_after_tech(25, 14, {"gold": 80, "wood": 80})
	var all_ok := trained and production_blocks and research_started and research_blocks_train \
		and duplicate_blocks and picks_shortest and skips_reserved and reserve_blocks_spend
	print("[ecoresearch] train=%s prod_blocks=%s research=%s train_blocks=%s duplicate=%s shortest=%s reserved=%s budget=%s ALL=%s" % [
		trained, production_blocks, research_started, research_blocks_train, duplicate_blocks,
		picks_shortest, skips_reserved, reserve_blocks_spend, all_ok])

	for tmp in [hall2, bar1, bar2]:
		units.erase(tmp)
		tmp.queue_free()
	hall._train_queue = saved_queue
	hall._train_t = saved_train_t
	hall._research_key = saved_research
	hall._research_t = saved_research_t
	gold = saved_gold; wood = saved_wood; pop_cap = saved_pop; current_age = saved_age; _tech_done = saved_done
	if hud != null:
		hud.refresh_command()


## A 地板侧向接敌自检（AMOVE_SIDE_TEST=1）：往上 A 移，右侧 165px 的敌人应被收进目标。
func _amove_side_selftest() -> void:
	if map == null:
		print("[amove] side_acquire=false reason=no_map")
		return
	var cell := Vector2i(-1, -1)
	var found := false
	for y in range(4, map.h - 4, 4):
		for x in range(4, map.w - 4, 4):
			var c := Vector2i(x, y)
			if not map.is_open_cell(c):
				continue
			var p := map.cell_to_world(c)
			var clear := true
			for u in units:
				if is_instance_valid(u) and not u.is_resource and u.hp > 0.0 and u.position.distance_to(p) < 420.0:
					clear = false
					break
			if clear:
				cell = c
				found = true
				break
		if found:
			break
	if not found:
		cell = map.nearest_open(level.camera_start_cell() + Vector2i(18, 18))
	var origin := map.cell_to_world(cell)
	var mover := spawn_unit("liang_dao", Unit.FACTION_LIANG, origin)
	var side_foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(165.0, 0.0))
	mover.set_stance(Unit.STANCE_AGGRO)
	side_foe.set_stance(Unit.STANCE_PASSIVE)
	mover.order_amove(map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(0.0, -320.0)))))
	for _i in range(10):
		_grid_build()
		mover._physics_process(0.1)
	var locked := mover._target == side_foe
	var engaged := locked and (mover._state == Unit.ST_CHASE or mover._lunge > 0.0)
	print("[amove] side_acquire=%s locked=%s state=%d dist=%.1f" % [
		engaged, locked, mover._state, mover.position.distance_to(side_foe.position)])
	units.erase(mover)
	units.erase(side_foe)
	mover.queue_free()
	side_foe.queue_free()
	_grid.clear()   # 清掉本测试手动构建的空间网格：残留过期网格会让后续自检(塔类)的 units_near 找不到新靶子


## Shift 连造自检（SHIFTBUILD_TEST=1）：采集中的工人 shift 连放 3 座——
## 首座应立刻开工（打断采集，修「挂在无限采集后永不执行」），其余按放置顺序排队、逐座跟进。
func _shiftbuild_selftest() -> void:
	var origin := map.cell_to_world(map.nearest_open(level.camera_start_cell() + Vector2i(6, 6)))
	var w := spawn_unit("lou_luo", Unit.FACTION_LIANG, origin)
	var tree: Unit = nearest_resource(origin, "wood")
	if tree != null:
		w.order_gather(tree)   # 先进入无限采集循环（用户实际场景）
	var sites: Array = []
	for k in range(3):
		var st := spawn_unit("house", Unit.FACTION_LIANG, origin + Vector2(80.0 + 40.0 * float(k), 40.0))
		st.is_constructing = true
		st._pending_build = true
		st.set_meta("fcell", map.world_to_cell(st.position))
		st.set_meta("fhalf", 1)
		sites.append(st)
		_order_builders_to_site([w], st, true)   # 模拟按住 Shift 连续放置
	var started_first: bool = w._state == Unit.ST_BUILD and w._build_site == sites[0]
	var q_ok: bool = w._queue.size() == 2 \
		and w._queue[0].get("target") == sites[1] and w._queue[1].get("target") == sites[2]
	# 首座完工 → 应自动接第二座；再完 → 第三座（顺序与放置一致）
	sites[0].is_constructing = false
	w._physics_process(0.05)
	var next_is_2: bool = w._build_site == sites[1]
	sites[1].is_constructing = false
	w._physics_process(0.05)
	var next_is_3: bool = w._build_site == sites[2]
	print("[shiftbuild] first_starts_now=%s queue_order_ok=%s then_2nd=%s then_3rd=%s" % [
		started_first, q_ok, next_is_2, next_is_3])
	for st in sites:
		units.erase(st)
		st.queue_free()
	units.erase(w)
	w.queue_free()


## 科技归属自检（TECH_TEST=1）：兵营科技(利刃/坚铠)不加成英雄；基地·时代科技(聚义/替天行道)加成英雄各 ~+10%。
func _tech_selftest() -> void:
	var prev_econ := economy
	economy = true
	tech_atk = 1.0; tech_hp = 1.0; hero_tech_atk = 1.0; hero_tech_hp = 1.0
	_tech_done = {}
	var age0 := current_age
	var origin := map.cell_to_world(map.nearest_open(Vector2i(38, 12)))
	var hero := spawn_unit("lin_chong", Unit.FACTION_LIANG, origin)
	var sol := spawn_unit("liang_dao", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(64, 0)))))
	hero._recompute_hero_stats()
	var h_hp0: float = hero.max_hp
	var s_hp0: float = sol.max_hp
	var res := []
	on_research_done(null, "tech_weapon")   # 兵营·利刃 atk+20%：英雄不受，常备军 ×1.2
	res.append(["weapon_hero_atk_unchanged", absf(hero_tech_atk - 1.0) < 0.001])
	res.append(["weapon_army_atk", absf(tech_atk - 1.2) < 0.001])
	on_research_done(null, "tech_armor")    # 兵营·坚铠 hp+25%：英雄血不变，常备军 ×1.25
	hero._recompute_hero_stats()
	res.append(["armor_hero_hp_unchanged", absf(hero.max_hp - h_hp0) < 0.5])
	res.append(["armor_army_hp", s_hp0 > 0.0 and absf(sol.max_hp / s_hp0 - 1.25) < 0.02])
	on_research_done(null, "tech_age2")     # 基地·聚义时代 hp+10%（含英雄）
	hero._recompute_hero_stats()
	res.append(["age2_hero_hp+10", h_hp0 > 0.0 and absf(hero.max_hp / h_hp0 - 1.1) < 0.02])
	on_research_done(null, "tech_age3")     # 基地·替天行道 atk+10%（含英雄）
	res.append(["age3_hero_atk+10", absf(hero_tech_atk - 1.1) < 0.001])
	res.append(["age3_army_atk", absf(tech_atk - 1.2 * 1.1) < 0.01])
	var all_ok := true
	for r in res:
		if not bool(r[1]):
			all_ok = false
	print("[techtest] %s ALL=%s" % [str(res), all_ok])
	units.erase(hero); hero.queue_free()
	units.erase(sol); sol.queue_free()
	tech_atk = 1.0; tech_hp = 1.0; hero_tech_atk = 1.0; hero_tech_hp = 1.0
	_tech_done = {}
	current_age = age0
	economy = prev_econ


## 防御塔/陷阱自检（TOWERTRAP_TEST=1）：三种新塔开火、法坛优先索敌英雄、三种陷阱触发。确定性、无需推帧。
func _towertrap_selftest() -> void:
	for u in units.duplicate():   # 隔离：清掉场上非建筑官军，免得污染索敌
		if is_instance_valid(u) and u.faction == Unit.FACTION_GUAN and not u.is_building:
			units.erase(u)
			u.queue_free()
	_grid.clear()   # 走「空网格→全表扫描」兜底：前序自检若手动建过网格，新生成的靶子不在里面
	var origin := map.cell_to_world(map.nearest_open(Vector2i(40, 12)))
	var results: Array = []
	# 三种新塔开火（活塔索敌→射出弹体）
	for tkey in ["thunder_tower", "altar_tower", "caltrop_tower"]:
		var tw := spawn_unit(tkey, Unit.FACTION_LIANG, origin)
		tw.is_constructing = false
		tw.hp = tw.max_hp
		var foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(90, 0))
		tw._target = null
		tw._cd = 0.0
		var pj0 := fx_root.get_child_count()
		tw._tower_tick(0.1)
		results.append([tkey + "_shoots", fx_root.get_child_count() > pj0])
		units.erase(tw); tw.queue_free()
		units.erase(foe); foe.queue_free()
	# 法坛优先索敌英雄：近处小兵 + 远处敌将 → 应锁敌将
	var altar := spawn_unit("altar_tower", Unit.FACTION_LIANG, origin)
	altar.is_constructing = false
	altar.hp = altar.max_hp
	var grunt := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(70, 0))
	var ehero := spawn_unit("wang_huan", Unit.FACTION_GUAN, origin + Vector2(0, 150))
	altar._target = null
	altar._tower_tick(0.0)
	results.append(["altar_targets_hero", altar._target != null and altar._target.is_hero])
	units.erase(altar); altar.queue_free()
	units.erase(grunt); grunt.queue_free()
	units.erase(ehero); ehero.queue_free()
	# 三种陷阱触发（布防完成→敌入触发圈→结算并销毁）
	_traps.clear()
	_place_trap("trap_logs", origin, Unit.FACTION_LIANG)
	_traps[-1]["arm_t"] = 0.0
	var v1 := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin)
	var hp_b := v1.hp
	_trap_pass(0.1)
	results.append(["trap_logs_dmg", v1.hp < hp_b and _traps.is_empty()])
	if is_instance_valid(v1): units.erase(v1); v1.queue_free()
	_traps.clear()
	_place_trap("trap_pit", origin, Unit.FACTION_LIANG)
	_traps[-1]["arm_t"] = 0.0
	var v2 := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin)
	_trap_pass(0.1)
	results.append(["trap_pit_stun", v2.is_stunned() and _traps.is_empty()])
	if is_instance_valid(v2): units.erase(v2); v2.queue_free()
	_traps.clear()
	var gd0 := _ground_dots.size()
	_place_trap("trap_oil", origin, Unit.FACTION_LIANG)
	_traps[-1]["arm_t"] = 0.0
	var v3 := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin)
	_trap_pass(0.1)
	results.append(["trap_oil_fire", _ground_dots.size() > gd0 and _traps.is_empty()])
	if is_instance_valid(v3): units.erase(v3); v3.queue_free()
	_traps.clear()
	_ground_dots.clear()
	# 木产策略：木紧(库存 < 金的一半)→金矿工降到3 + 农民上限拉到10(多产去伐木)；充裕→4 + 6。
	var _g0 := gold
	var _w0 := wood
	gold = 400; wood = 100
	var wshort: bool = _eco_wood_short() and _eco_gold_target() == ECO_GOLD_MINERS - 1 and _eco_wcap_dyn() == ECO_WCAP_WOOD
	gold = 400; wood = 320
	var wok: bool = (not _eco_wood_short()) and _eco_gold_target() == ECO_GOLD_MINERS and _eco_wcap_dyn() == ECO_WCAP
	gold = _g0; wood = _w0
	results.append(["wood_short_policy", wshort])
	results.append(["wood_ok_policy", wok])
	# 英雄倍率(改变倍率开启)：n=clamp(hero_mult,1,3)；rb=1+(n-1)·0.4(n3=1.8×)、db=1+(n-1)/4；CD×(1-(n-1)·0.2)(n3=60%)、血量×(1+(n-1)/3)、攻击力×(1+(n-1)·0.1)(n3=1.2×)。
	var _hb0 := Campaign.hero_mult
	var _so0 := Campaign.scale_on
	var _sk0 := Campaign.skirmish
	Campaign.scale_on = true
	Campaign.skirmish = true   # 倍率有模式门禁（仅驻守/据守/竞技场生效）→ 测试期显式置驻守
	Campaign.hero_mult = 2.5
	var hbh := spawn_unit("song_jiang", Unit.FACTION_LIANG, origin)
	var nmath_ok: bool = absf(_hero_boost_n(hbh) - 2.5) < 0.01 and absf(_hero_rb(hbh) - 1.6) < 0.01 and absf(_hero_db(hbh) - 1.375) < 0.01
	Campaign.hero_mult = 4.0   # 封顶 → n=3
	var cap_ok: bool = absf(_hero_boost_n(hbh) - 3.0) < 0.01
	var sa: Dictionary = _scaled_ability(_abilities.get("lin_sweep", {}), _hero_rb(hbh), _hero_db(hbh))   # n=3: 范围×1.8、伤害×1.5
	var scale_ok: bool = absf(float(sa.get("radius", 0.0)) - 180.0) < 1.0 and absf(float(sa.get("effect", {}).get("dmg", 0.0)) - 37.5) < 0.5
	Campaign.hero_mult = 1.0
	hbh._recompute_hero_stats()
	var hp1: float = hbh.max_hp
	var cd1: float = hbh._slot_cd(0)
	var atk1: float = hbh.atk
	Campaign.hero_mult = 4.0   # n=3：血量×1.667、CD×0.6、攻击×1.5（比值约掉科技系数）
	hbh._recompute_hero_stats()
	var hpcd_ok: bool = hp1 > 0.0 and absf(hbh.max_hp / hp1 - 1.6667) < 0.02 and (cd1 <= 0.0 or absf(hbh._slot_cd(0) / cd1 - 0.6) < 0.02) and (atk1 <= 0.0 or absf(hbh.atk / atk1 - 1.2) < 0.02)
	hbh.ability_slots[0]["rank"] = maxi(1, int(hbh.ability_slots[0]["rank"]))   # 确保已学，能真施放
	hbh.slot_start_cd(0)   # 真·施放：cd_t 应被设成缩短后的冷却
	var cdt: float = float(hbh.ability_slots[0]["cd_t"])
	var cast_cd_ok: bool = absf(cdt - hbh._slot_cd(0)) < 0.01
	print("[cdtest] song_rally(slot0): 原cd=%.1f  n=1→cd=%.1f  n=3→cd=%.1f  施放后cd_t=%.1f(应=%.1f)  ok=%s" % [
		float(_abilities.get("song_rally", {}).get("cd", 0.0)), cd1, hbh._slot_cd(0), cdt, hbh._slot_cd(0), cast_cd_ok])
	# UI 时序：抬手阶段 cd_t 本来就应为 0，HUD 必须识别 pending 并显示「施法中」，不能显示「冷却 0」。
	hbh.ability_slots[0]["cd_t"] = 0.0
	_begin_cast(hbh, 0, hbh.position)
	var cast_ui_state_ok := is_cast_pending(hbh, 0) and hbh._cast_t > 0.0 \
			and float(hbh.ability_slots[0]["cd_t"]) <= 0.0
	print("[cdui] pending=%s cd_t=%.1f label=%s ok=%s" % [
		is_cast_pending(hbh, 0), float(hbh.ability_slots[0]["cd_t"]),
		"施法中" if is_cast_pending(hbh, 0) else "冷却", cast_ui_state_ok])
	hbh.cancel_cast_windup()
	# 敌方倍率 e=4：数量×4、血×(1+3/3)=2.0、攻×(1+3/4)=1.75
	var _em0 := Campaign.enemy_mult
	Campaign.enemy_mult = 4.0
	var eg := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(0, 80))
	var ehp0: float = eg.max_hp
	var eatk0: float = eg.atk
	apply_enemy_scale(eg)
	var enemy_ok: bool = absf(enemy_count_mult() - 4.0) < 0.01 \
		and absf(eg.max_hp / ehp0 - 2.0) < 0.02 and absf(eg.atk / eatk0 - 1.75) < 0.02
	units.erase(eg); eg.queue_free()
	Campaign.enemy_mult = _em0
	Campaign.hero_mult = _hb0
	Campaign.scale_on = _so0
	Campaign.skirmish = _sk0
	units.erase(hbh); hbh.queue_free()
	results.append(["hero_boost_math", nmath_ok and cap_ok])
	results.append(["hero_boost_scale", scale_ok])
	results.append(["hero_boost_hp_cd", hpcd_ok])
	results.append(["cast_ui_no_zero", cast_ui_state_ok])
	results.append(["revive_reserve_floor", _eco_revive_reserve() >= 2 * ECO_REVIVE_GOLD])
	# 民居「后方」锚点：在远离前线一侧、离基地够远（别堆采矿角/集结走廊卡住单位）
	var hall_t := main_base(Unit.FACTION_LIANG)
	var hp_t: Vector2 = hall_t.position if hall_t != null else _eco_base_pos()
	var fl_t := _eco_frontline()
	var away_t := hp_t - fl_t
	away_t = away_t.normalized() if away_t.length() > 1.0 else Vector2(-1, 1)
	var back_pos := map.cell_to_world(_eco_anchor("back"))
	results.append(["house_back_anchor", (back_pos - hp_t).dot(away_t) > 1.0 and back_pos.distance_to(hp_t) >= float(GameMap.CELL) * 4.0])
	# 回身秒杀贴脸弱敌：英雄旁放一个残血小兵 → 应回身普攻锁定它（不绕远/不空等技能）
	var gh := spawn_unit("lin_chong", Unit.FACTION_LIANG, origin)
	var gnat := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin + Vector2(40, 0))
	gnat.hp = 20.0
	var gnat_ok: bool = _kill_close_gnat(gh) and gh._target == gnat
	units.erase(gh); gh.queue_free()
	units.erase(gnat); gnat.queue_free()
	results.append(["gnat_kill", gnat_ok])
	results.append(["enemy_scale", enemy_ok])
	# 全托管动态分路：三路锚点/计数有效；无敌 6 将均分；多路来敌会分兵；已有守军的两路让位给薄弱重压路。
	var lanes_t := _eco_lanes()
	var lanes_ok: bool = lanes_t.size() == 3
	var lane_threat_ok := false
	if lanes_ok:
		var lg := spawn_unit("guan_dao", Unit.FACTION_GUAN, lanes_t[0])
		var th_t := _eco_lane_threat(lanes_t)
		lane_threat_ok = int(th_t[0]) >= 1
		units.erase(lg); lg.queue_free()
	results.append(["eco_lanes", lanes_ok])
	results.append(["eco_lane_threat", lane_threat_ok])
	var calm_slots := _eco_lane_allocate([0.0, 0.0, 0.0], [0.0, 0.0, 0.0], 6)
	var calm_split_ok := calm_slots.count(0) == 2 and calm_slots.count(1) == 2 and calm_slots.count(2) == 2
	var multi_slots := _eco_lane_allocate([6.0, 6.0, 18.0], [0.0, 0.0, 0.0], 6)
	var multi_split_ok := multi_slots.count(0) >= 1 and multi_slots.count(1) >= 1 \
			and multi_slots.count(2) >= 3
	var extreme_slots := _eco_lane_allocate([1.0, 1.0, 100.0], [0.0, 0.0, 0.0], 6)
	var uncovered_lane_ok := extreme_slots.count(0) >= 1 and extreme_slots.count(1) >= 1 \
			and extreme_slots.count(2) >= 1
	var weak_slots := _eco_lane_allocate([8.0, 8.0, 16.0], [8.0, 8.0, 0.0], 6)
	var weak_lane_help_ok := weak_slots.count(2) == 6   # 中/右上已有足量守军 → 六将可集中补左下缺口
	var route_gong := spawn_unit("gongsun_sheng", Unit.FACTION_LIANG, lanes_t[0] if lanes_ok else origin)
	route_gong.auto_micro = true
	var gong_joins_routes := _eco_lane_heroes().has(route_gong)
	var gong_cross_lane := false
	var lane_foes: Array = []
	if lanes_ok:
		for fi in range(6):
			lane_foes.append(spawn_unit("guan_dao", Unit.FACTION_GUAN, lanes_t[2] + Vector2(float(fi % 3) * 12.0, float(fi / 3) * 12.0)))
		_eco_lane_cache_bucket = -1
		_eco_lane_cache.clear()
		_eco_rebalance_hero(route_gong)
		gong_cross_lane = route_gong._state == Unit.ST_MOVE and route_gong._ai_dest.distance_to(lanes_t[2]) <= 30.0
	for lf in lane_foes:
		units.erase(lf); lf.queue_free()
	units.erase(route_gong); route_gong.queue_free()
	_eco_lane_cache_bucket = -1
	_eco_lane_cache.clear()
	results.append(["eco_lane_calm_split", calm_split_ok])
	results.append(["eco_lane_multi_split", multi_split_ok])
	results.append(["eco_lane_uncovered_guard", uncovered_lane_ok])
	results.append(["eco_lane_weak_help", weak_lane_help_ok])
	results.append(["gong_joins_routes", gong_joins_routes])
	results.append(["gong_cross_lane", gong_cross_lane])
	# 手动指令保护：玩家下令戳 5 秒保护期；指令执行完队列清空 → 立即解除
	var mh_t := spawn_unit("lin_chong", Unit.FACTION_LIANG, origin)
	_stamp_manual([mh_t])
	var manual_ok: bool = mh_t.manual_order_t > 4.9
	mh_t.order_move(origin + Vector2(10, 0))
	mh_t._done_order()   # 队列空 → 走完即解除
	manual_ok = manual_ok and mh_t.manual_order_t == 0.0
	units.erase(mh_t); mh_t.queue_free()
	results.append(["manual_protect", manual_ok])
	var all_ok := true
	for r in results:
		if not bool(r[1]):
			all_ok = false
	print("[towertrap] %s ALL=%s" % [results, all_ok])


## 末波残敌专项自检：A 移不可达只有限重寻；全托管扫尾能侦察、派兵，并把断路残敌放回进攻线。
func _final_cleanup_selftest() -> void:
	for u in units.duplicate():
		if is_instance_valid(u) and u.faction == Unit.FACTION_GUAN and not u.is_building:
			units.erase(u)
			u.queue_free()
	_grid.clear()
	var results: Array = []
	var hall := main_base(Unit.FACTION_LIANG)
	var origin_c := Vector2i(-1, -1)
	if hall != null:
		# 找一格可走、且离基地足够远的位置；测试期封掉官军寻路图的八邻格，稳定制造“单位活着但无路可走”。
		for y in range(3, map.h - 3):
			for x in range(3, map.w - 3):
				var c := Vector2i(x, y)
				if map.is_open_cell(c) and not map.astar_guan.is_point_solid(c) \
						and map.cell_to_world(c).distance_to(hall.position) > 500.0:
					origin_c = c
					break
			if origin_c.x >= 0:
				break
	var blocked_before := {}
	if origin_c.x >= 0:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nc := origin_c + Vector2i(dx, dy)
				blocked_before[nc] = map.astar_guan.is_point_solid(nc)
				map.astar_guan.set_point_solid(nc, true)
	var origin := map.cell_to_world(origin_c) if origin_c.x >= 0 else map.cell_to_world(map.nearest_open(Vector2i(40, 12)))
	var foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, origin)
	foe.passive = true
	foe._target = null
	foe._amove_dest = hall.position if hall != null else origin + Vector2(800, 0)
	foe._move_retry = 0
	foe._move_retry_pos = foe.position
	foe._state = Unit.ST_AMOVE
	# 每次强制模拟 A* 仍返回空路径；第 4 拍必须结束命令，而不是继续每帧重寻。
	for _i in range(5):
		foe._path = PackedVector2Array()
		foe._phys_body(0.016)
	results.append(["amove_retry_capped", foe._move_retry == 3 and foe._state == Unit.ST_IDLE])
	var hunter := spawn_unit("liang_dao", Unit.FACTION_LIANG, origin + Vector2(320, 0))
	hunter._state = Unit.ST_IDLE
	hunter._target = null
	var prev_ai := ai_friendly
	var prev_micro := int(Settings.auto_micro_level)
	ai_friendly = true
	Settings.auto_micro_level = 3
	foe.passive = false
	foe._target = null
	foe._state = Unit.ST_IDLE
	var before_pos := foe.position
	var stats := final_wave_cleanup()
	results.append(["cleanup_reveals", int(stats["enemies"]) == 1 and int(stats["revealed"]) == 1])
	var cleanup_cell := map.world_to_cell(foe.position)
	var cleanup_idx := cleanup_cell.y * map.w + cleanup_cell.x
	results.append(["cleanup_fog_synced", not fog or (is_visible_world(foe.position) \
			and cleanup_idx >= 0 and cleanup_idx < _vision.size() and _vision[cleanup_idx] == 2)])
	results.append(["cleanup_relocates_unreachable", origin_c.x >= 0 and int(stats["relocated"]) == 1 \
			and foe.position.distance_to(before_pos) > 64.0 and foe._state == Unit.ST_AMOVE])
	results.append(["cleanup_dispatches_hunter", int(stats["hunters"]) >= 1 and hunter._state == Unit.ST_AMOVE])
	var activation_ok := false
	if level.id() == "skirmish":
		var wave_before = level.get("_wave")
		var last_before = level.get("_final_cleanup_last_alive")
		var quiet_before = level.get("_final_cleanup_quiet")
		var active_before = level.get("_final_cleanup_active")
		level.set("_wave", level.call("_waves").size())
		level.set("_final_cleanup_last_alive", 1)
		level.set("_final_cleanup_quiet", 8.0)
		level.set("_final_cleanup_active", false)
		level.set("_final_cleanup_tick", 0.0)
		level.process(self, 0.1)
		activation_ok = bool(level.get("_final_cleanup_active"))
		level.set("_wave", wave_before)
		level.set("_final_cleanup_last_alive", last_before)
		level.set("_final_cleanup_quiet", quiet_before)
		level.set("_final_cleanup_active", active_before)
	results.append(["level_cleanup_activation", activation_ok])
	ai_friendly = prev_ai
	Settings.auto_micro_level = prev_micro
	for nc in blocked_before:
		map.astar_guan.set_point_solid(nc, bool(blocked_before[nc]))
	units.erase(foe); foe.queue_free()
	units.erase(hunter); hunter.queue_free()
	var all_ok := true
	for r in results:
		if not bool(r[1]):
			all_ok = false
	print("[final_cleanup] %s ALL=%s" % [results, all_ok])


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
		if _reveal_t[i] > 0.0:
			_reveal_t[i] = maxf(0.0, _reveal_t[i] - step)
		if _sight_now[i] == 1 or _reveal_t[i] > 0.0:
			_vision[i] = 2
		elif _vision[i] != 0:
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


## 信息抽屉视觉自检（INFO_UI_TEST_DIR=/path）：各拍一张折叠/展开图；TOUCH_UI=1 可验证移动端无键位段。
func _info_ui_selftest(dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[infoui] skipped: headless display has no viewport texture")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	if hud._intro_root != null:
		hud._intro_root.visible = false
	hud.show_message("官军探马杀到——头一拨人马已近寨门！", 8.0)
	hud.show_message("科技研究正在等待生产队列排空", 8.0)
	hud._set_info_expanded(false)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[infoui] help visible=%s rect=%s toggle=%s panel=%s" % [
		hud._control_help.visible, hud._control_help.get_global_rect(),
		hud._info_toggle.get_global_rect(), hud._info_panel.get_global_rect()])
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s/info_collapsed.png" % dir)
	hud._set_info_expanded(true)
	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("%s/info_expanded.png" % dir)
	# 折叠即时消息契约：第 4 条顶掉最旧条，每条 3 秒后离场。
	hud._set_info_expanded(false)
	hud._clear_info_toasts()
	for i in range(4):
		hud._show_info_toast("__toast_probe_%d__" % i)
	var cap3 := hud.msg_box.get_child_count() == 3
	await get_tree().create_timer(3.2).timeout
	var probe_alive := false
	for child in hud.msg_box.get_children():
		if String(child.get_meta("info_text", "")).begins_with("__toast_probe_"):
			probe_alive = true
			break
	print("[infoui] toast_cap3=%s expires_3s=%s" % [cap3, not probe_alive])
	print("[infoui] touch=%s saved=%s" % [hud.touch_ui, dir])


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


## 花荣技能视觉自检：Q/W 整体、E 五连珠单体钉身、R 蓄力准星与贯心箭分别连拍。
func _huarong_test(dir: String) -> void:
	Engine.time_scale = 1.0
	if _fog_layer != null:
		_fog_layer.visible = false
	if hud != null and hud._intro_root != null:
		hud._intro_root.visible = false
	var c := map.cell_to_world(level.camera_start_cell())
	var hr := spawn_unit("hua_rong", Unit.FACTION_LIANG, c)
	var center := c + Vector2(190, 35)
	var hero_tgt := spawn_unit("hu_yanzhuo", Unit.FACTION_GUAN, center)
	hero_tgt.max_hp = 6000.0
	hero_tgt.hp = 6000.0
	hero_tgt.set_stance(Unit.STANCE_PASSIVE)
	for i in range(7):
		var mob := spawn_unit("guan_dao", Unit.FACTION_GUAN, center + Vector2(randf_range(-55, 55), randf_range(-38, 38)))
		mob.set_stance(Unit.STANCE_PASSIVE)
	for s in range(hr.slot_count()):
		hr.ability_slots[s]["rank"] = 2
		hr.ability_slots[s]["cd_t"] = 0.0
	camera.zoom = Vector2(2.3, 2.3)
	camera.position = to_screen((c + center) * 0.5)
	await get_tree().process_frame
	# Q 落地身法、W 箭雨减速：保留整体镜头，各拍三帧。
	for sk in [["hua_blink", 0], ["hua_rain", 1]]:
		var aid: String = sk[0]
		var slot: int = sk[1]
		hr.position = c
		hr.ability_slots[slot]["cd_t"] = 0.0
		_do_ability(hr, slot, center)
		for fi in range(3):
			await get_tree().create_timer([0.06, 0.15, 0.30][fi]).timeout
			camera.position = to_screen((c + center) * 0.5)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/hr_%s_%d.png" % [dir, aid, fi])
		print("[huarong] %s cast + captured" % aid)
	# E：冷蓝单箭飞行、钉身、五枚锁定箭计数。
	hr.position = c
	hr.ability_slots[2]["cd_t"] = 0.0
	_do_ability(hr, 2, hero_tgt.position, hero_tgt)
	for fi in range(4):
		await get_tree().create_timer([0.05, 0.10, 0.16, 0.28][fi]).timeout
		camera.position = to_screen((c + center) * 0.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hr_hua_pin_%d.png" % [dir, fi])
	print("[huarong] hua_pin five-shot mark captured")
	# R：先拍 1 秒蓄力的收束准星，再取消待结算并直接触发箭体，分开观察两段演出。
	hr._clear_hua_lock()
	hr.position = c
	hr.ability_slots[3]["cd_t"] = 0.0
	_begin_cast(hr, 3, hero_tgt.position, hero_tgt)
	for fi in range(3):
		await get_tree().create_timer([0.12, 0.25, 0.30][fi]).timeout
		camera.position = to_screen((c + center) * 0.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hr_hua_snipe_aim_%d.png" % [dir, fi])
	hr.cancel_cast_windup()
	hr.ability_slots[3]["cd_t"] = 0.0
	_do_ability(hr, 3, hero_tgt.position, hero_tgt)
	for fi in range(4):
		await get_tree().create_timer([0.035, 0.06, 0.12, 0.28][fi]).timeout
		camera.position = to_screen((c + center) * 0.5)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hr_hua_snipe_shot_%d.png" % [dir, fi])
	print("[huarong] hua_snipe aim + shot captured; DONE")


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
		# 技能抬手可视回归：槽 0 应显示「施法中」，其余槽不得被误画成冷却 0。
		hero.ability_slots[0]["cd_t"] = 0.0
		_begin_cast(hero, 0, hero.position + Vector2(80, 0))
		total_bad += await _cmdcard_capture(dir, "hero_casting", [hero])
		print("[cmdcard] casting pending=%s cd_t=%.1f" % [
			is_cast_pending(hero, 0), float(hero.ability_slots[0]["cd_t"])])
		hero.cancel_cast_windup()
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
		# 大编队常显几十条线会遮住战场；按住 Shift 时仍完整显示排队意图。
		var detail_orders: bool = b.selection.size() <= 12 or Input.is_key_pressed(KEY_SHIFT)
		if Settings.show_command_queue and detail_orders:
			_draw_selected_orders()
		if Settings.show_target_lines and detail_orders:
			_draw_selected_targets()
		if Settings.show_range_rings:
			_draw_selected_ranges()
		# 指向施法预览：按下技能即在地面显示「作用范围指示器」（跟随鼠标，等距投影）。
		# 形状随技能：闪现/突刺/冲锋=直线箭头(封顶最大射程)；箭雨=前方扇形；其余点目标=圆圈。
		if b._ability_armed != "":
			# 预览也按英雄倍率放大范围，所见即所得
			_draw_cast_indicator(b._scaled_ability(b.ability_def(b._ability_armed), b._hero_rb(b._ability_caster), b._hero_db(b._ability_caster)))
		# 建造放置预览：占地框（绿=可建 / 红=不可）
		if b._build_armed != "":
			var bhalf: int = b.building_footprint_half(b._build_armed)
			# 触屏：虚影跟手指（_drag_cur 在拖动中实时更新，未拖时为视图中心）；桌面跟鼠标。
			var bref: Vector2 = b._drag_cur if b._touch_mode else get_global_mouse_position()
			var bcell: Vector2i = b.map.world_to_cell(b.to_logic(bref))
			var bdef: Dictionary = b._defs.get(b._build_armed, {})
			var bok: bool = b.map.area_buildable(bcell, bhalf) and not b._building_overlap(bcell, bhalf) \
				and not b._resource_overlap(bcell, bhalf) \
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
		# 陷阱布置预览：触发圈（绿=可放 / 红=不可），跟手指/鼠标
		if b._trap_armed != "":
			var td: Dictionary = Defs.TRAPS.get(b._trap_armed, {})
			var tref: Vector2 = b._drag_cur if b._touch_mode else get_global_mouse_position()
			var tcell: Vector2i = b.map.world_to_cell(b.to_logic(tref))
			var tok: bool = b.map.area_buildable(tcell, 0) \
				and b.can_afford(int(td.get("cost_gold", 0)), int(td.get("cost_wood", 0)))
			var tcol := Color(0.4, 1.0, 0.5) if tok else Color(1.0, 0.35, 0.3)
			var tctr: Vector2 = b.to_screen(b.map.cell_to_world(tcell))
			var trr: float = float(td.get("trigger_r", 65.0))
			# 触发圈用等距投影画成贴地椭圆
			var pts := PackedVector2Array()
			for i in range(28):
				var a := TAU * float(i) / 28.0
				pts.append(tctr + GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * trr))
			draw_colored_polygon(pts, Color(tcol.r, tcol.g, tcol.b, 0.16))
			draw_polyline(pts + PackedVector2Array([pts[0]]), tcol, 2.0)
			var tmk: Color = td.get("color", Color("ffaa44"))
			draw_circle(tctr, 6.0, Color(tmk.r, tmk.g, tmk.b, 0.9))

	func _draw_selected_orders() -> void:
		for u in b.selection:
			if not (is_instance_valid(u) and u.hp > 0.0 and not u.is_building and not u.garrisoned):
				continue
			var pts := PackedVector2Array()
			pts.append(b.to_screen(u.position))
			for pi in range(u._path_i, u._path.size()):   # 只画还没走到的路点——从 0 画会拖出一条折回身后的假线
				pts.append(b.to_screen(u._path[pi]))
			if pts.size() >= 2:
				draw_polyline(pts, Color(0.36, 0.95, 0.52, 0.55), 1.4)
				draw_circle(pts[pts.size() - 1], 3.0, Color(0.5, 1.0, 0.6, 0.85))
			var last: Vector2 = u.position
			if u._path.size() > 0:
				last = u._path[u._path.size() - 1]
			var qn := 0
			for o in u._queue:
				var op: Vector2 = _order_world_pos(o)
				if op == Vector2.INF:
					continue
				var a: Vector2 = b.to_screen(last)
				var p: Vector2 = b.to_screen(op)
				draw_dashed_line(a, p, Color(0.5, 0.85, 1.0, 0.58), 1.2, 8.0)
				draw_circle(p, 4.5, Color(0.5, 0.85, 1.0, 0.7))
				var f := ThemeDB.fallback_font
				draw_string(f, p + Vector2(5, -5), str(qn + 1), HORIZONTAL_ALIGNMENT_LEFT, 24, 12, Color("d7f5ff"))
				last = op
				qn += 1


	func _draw_selected_targets() -> void:
		for u in b.selection:
			if not (is_instance_valid(u) and u.hp > 0.0 and not u.is_building and is_instance_valid(u._target)):
				continue
			var tgt = u._target
			if tgt == null or not is_instance_valid(tgt) or tgt.hp <= 0.0:
				continue
			var a: Vector2 = b.to_screen(u.position + Vector2(0, -6))
			var p: Vector2 = b.to_screen(tgt.position + Vector2(0, -6))
			var col := Color(1.0, 0.32, 0.22, 0.7) if tgt.faction != u.faction else Color(0.35, 0.9, 1.0, 0.65)
			draw_line(a, p, col, 1.5)
			draw_arc(p, maxf(8.0, tgt.radius * 0.35), 0.0, TAU, 18, col, 1.6)


	func _draw_selected_ranges() -> void:
		var act = b.active_unit()
		if act == null or not is_instance_valid(act) or act.atk <= 0.0:
			return
		var col := Color(1.0, 0.82, 0.28, 0.72) if act.faction == Unit.FACTION_LIANG else Color(1.0, 0.35, 0.25, 0.7)
		_draw_world_ring(act.position, act.atk_range + act.radius, col, Color(col.r, col.g, col.b, 0.045))


	func _order_world_pos(o: Dictionary) -> Vector2:
		var k := String(o.get("kind", ""))
		if o.has("pos"):
			return o["pos"]
		if o.has("target"):
			var t = o["target"]
			if is_instance_valid(t):
				return t.position
		return Vector2.INF


	func _draw_world_ring(center: Vector2, radius: float, edge: Color, fill: Color) -> void:
		var pts := PackedVector2Array()
		for i in range(48):
			var a := TAU * float(i) / 48.0
			pts.append(b.to_screen(center + Vector2(cos(a), sin(a)) * radius))
		draw_colored_polygon(pts, fill)
		var closed := PackedVector2Array()
		for p in pts:
			closed.append(p)
		closed.append(pts[0])
		draw_polyline(closed, edge, 1.6)

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
		# 施法距离：超射程时预览点沿射线收短到最远可放点，并画「最大可达」淡环——与 _begin_cast 的
		# clamp 完全一致，所见即所得（全图豁免技能 crng=INF，不画环不收短）。
		if caster != null and is_instance_valid(caster):
			var crng: float = b.ability_cast_range(caster, b.ability_def(b._ability_armed))
			if crng != INF:
				var co: Vector2 = caster.position
				var coff := lp - co
				if coff.length() > crng:
					lp = co + coff.normalized() * crng
				var cring := PackedVector2Array()
				for i in range(48):
					var ca := i * TAU / 48.0
					cring.append(b.to_screen(co + Vector2(cos(ca), sin(ca)) * crng))
				draw_polyline(cring + PackedVector2Array([cring[0]]), Color(col.r, col.g, col.b, 0.22), 1.5)
		# 点目标（圆圈 AoE）：在（钳制后的）落点画作用范围环
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


## 花荣 R·百步穿杨蓄力：一秒内瞄准线由虚转实，目标准星逐步收紧；只标一个单位，不画范围圈。
class HuaSnipeAimFx extends TimedFx:
	var caster: Unit = null
	var target: Unit = null
	var life := 1.0
	var col := Color("ffd86a")

	func _ready() -> void:
		dur = maxf(life, 0.05)
		t = dur

	func _process(delta: float) -> void:
		if caster == null or target == null or not is_instance_valid(caster) or not is_instance_valid(target) \
				or caster.hp <= 0.0 or target.hp <= 0.0 or caster._cast_t <= 0.0:
			t = minf(t, 0.02)
		elif is_instance_valid(caster):
			position = caster.position + Vector2(0, -10)
		super._process(delta)

	func _draw() -> void:
		if target == null or not is_instance_valid(target):
			return
		draw_set_transform_matrix(GameMap.ISO_INV)
		var end := GameMap.ISO.basis_xform(target.position - position)
		var p := clampf(1.0 - t / dur, 0.0, 1.0)
		var line_col := Color(col.r, col.g, col.b, 0.18 + 0.62 * p)
		var dist := end.length()
		var dir := end.normalized() if dist > 0.1 else Vector2.RIGHT
		# 虚线瞄准轨迹随蓄力逐段点亮，最后 20% 变为一条稳定亮线。
		var seg := 15.0
		var x := 0.0
		while x < dist:
			var x2 := minf(x + seg * 0.55, dist)
			draw_line(dir * x, dir * x2, line_col, 1.2 + 1.5 * p)
			x += seg
		if p > 0.8:
			draw_line(Vector2.ZERO, end, Color(1.0, 0.97, 0.75, (p - 0.8) * 3.5), 1.5)
		var rr := lerpf(40.0, 13.0, p)
		draw_arc(end, rr, -PI * 0.15, PI * 0.35, 10, line_col, 2.0)
		draw_arc(end, rr, PI * 0.85, PI * 1.35, 10, line_col, 2.0)
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			var rd := Vector2(cos(a), sin(a))
			draw_line(end + rd * (rr + 7.0), end + rd * maxf(4.0, rr - 6.0), line_col, 2.0)
		draw_circle(end, 2.0 + p * 2.0, Color(1.0, 1.0, 0.9, 0.65 + 0.3 * p))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 花荣 E/R 单体箭演出。E 是冷蓝钉身箭并留下三箭锁定标；R 是高速金色贯心箭与单体准星爆闪。
class HuaTargetArrowFx extends TimedFx:
	var end_w := Vector2.ZERO
	var col := Color("8fd3ff")
	var snipe := false
	var lock_shots := 5
	var travel := 0.2
	var _E := Vector2.ZERO

	func _ready() -> void:
		travel = 0.13 if snipe else 0.22
		dur = travel + (0.62 if snipe else 0.72)
		t = dur
		_E = GameMap.ISO.basis_xform(end_w - position)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var elapsed := dur - t
		var p := clampf(elapsed / travel, 0.0, 1.0)
		var dist := _E.length()
		var dir := _E.normalized() if dist > 0.1 else Vector2.RIGHT
		var side := Vector2(-dir.y, dir.x)
		if p < 1.0:
			var head := dir * dist * p
			var tail_len := 145.0 if snipe else 82.0
			for k in range(8):
				var q0 := float(k) / 8.0
				var q1 := float(k + 1) / 8.0
				var a := head - dir * tail_len * q0
				var b := head - dir * tail_len * q1
				if b.dot(dir) < 0.0:
					b = Vector2.ZERO
				draw_line(a, b, Color(col.r, col.g, col.b, (0.72 if snipe else 0.5) * (1.0 - q0)),
					(8.0 if snipe else 5.0) * (1.0 - q0 * 0.72))
				if b == Vector2.ZERO:
					break
			# R 有两道细长平行残光，E 只有单一箭路，辨识度明确。
			if snipe:
				var rail_start := head - dir * 105.0
				if rail_start.dot(dir) < 0.0:
					rail_start = Vector2.ZERO
				draw_line(rail_start + side * 5.0, head + side * 5.0,
					Color(1.0, 0.8, 0.25, 0.45), 1.5)
				draw_line(rail_start - side * 5.0, head - side * 5.0,
					Color(1.0, 0.95, 0.72, 0.4), 1.5)
			var shaft := 34.0 if snipe else 27.0
			draw_line(head - dir * shaft, head, Color(0.25, 0.18, 0.1, 0.95), 7.0 if snipe else 5.0)
			draw_line(head - dir * shaft, head, Color(1.0, 0.98, 0.82, 1.0), 3.2 if snipe else 2.4)
			var tip := 18.0 if snipe else 13.0
			draw_colored_polygon(PackedVector2Array([head + dir * tip, head - dir * 2.0 + side * tip * 0.55,
				head - dir * 2.0 - side * tip * 0.55]), Color(1.0, 0.99, 0.88))
			draw_line(head - dir * shaft, head - dir * (shaft + 9.0) + side * 7.0, col, 2.0)
			draw_line(head - dir * shaft, head - dir * (shaft + 9.0) - side * 7.0, col, 2.0)
		else:
			var q := clampf((elapsed - travel) / maxf(dur - travel, 0.01), 0.0, 1.0)
			var fade := 1.0 - q
			if snipe:
				# 单点贯心：十字裂光和收束准星，没有扩散伤害圆。
				for a in [0.0, PI * 0.5, PI, PI * 1.5]:
					var rd := Vector2(cos(a), sin(a))
					draw_line(_E + rd * 4.0, _E + rd * (48.0 * fade + 12.0),
						Color(col.r, col.g, col.b, 0.9 * fade), 3.0 * fade + 1.0)
				draw_arc(_E, 18.0 - 7.0 * q, 0.0, TAU, 24, Color(1.0, 0.9, 0.35, 0.9 * fade), 2.5)
				draw_circle(_E, 7.0 * fade, Color(1.0, 1.0, 0.86, 0.75 * fade))
			else:
				# 钉身点 + 五枚小箭标，提示接下来五次跨距锁定普攻。
				draw_line(_E + Vector2(0, -28), _E + Vector2(0, 2), Color(0.9, 0.88, 0.7, 0.9 * fade), 3.0)
				draw_arc(_E, 17.0, -PI * 0.2, PI * 1.2, 20, Color(col.r, col.g, col.b, 0.75 * fade), 2.0)
				for i in range(lock_shots):
					var mid := float(lock_shots - 1) * 0.5
					var pp := _E + Vector2((float(i) - mid) * 8.0, -32.0 - absf(float(i) - mid) * 1.8)
					draw_line(pp + Vector2(0, -7), pp, Color(0.86, 0.95, 1.0, 0.9 * fade), 1.8)
					draw_colored_polygon(PackedVector2Array([pp + Vector2(0, 3), pp + Vector2(-3, -2), pp + Vector2(3, -2)]),
						Color(col.r, col.g, col.b, 0.85 * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## R 命中敌将后的五秒单体灼伤标记：跟随目标，不泄露范围，也不会留在原地误导玩家。
class HuaSnipeMarkFx extends TimedFx:
	var target: Unit = null
	var life := 5.0

	func _ready() -> void:
		dur = life
		t = life

	func _process(delta: float) -> void:
		if target == null or not is_instance_valid(target) or target.hp <= 0.0:
			t = minf(t, 0.08)
		else:
			position = target.position
		super._process(delta)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var fade := clampf(minf((dur - t) / 0.2, t / 0.35), 0.0, 1.0)
		var pulse := 0.65 + 0.35 * sin((dur - t) * TAU * 2.0)
		var c := Color(1.0, 0.46, 0.16, 0.55 * fade * pulse)
		draw_arc(Vector2.ZERO, 15.0, -PI * 0.2, PI * 1.2, 20, c, 2.0)
		draw_line(Vector2(-7, -20), Vector2(7, -6), c, 2.5)
		draw_line(Vector2(7, -20), Vector2(-7, -6), c, 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## E 五连珠持续标记：悬在被锁目标头顶的五枚蓝箭会随每次普通攻击逐枚熄灭，直到锁定结束。
class HuaLockMarkFx extends Node2D:
	var source: Unit = null
	var target: Unit = null
	var col := Color("8fd3ff")
	var pulse := 0.0

	func _process(delta: float) -> void:
		if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target) \
				or source.hp <= 0.0 or target.hp <= 0.0 or source._hua_lock_target != target or source._hua_lock_shots <= 0:
			queue_free()
			return
		position = target.position
		pulse += delta
		queue_redraw()

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var count := source._hua_lock_shots if source != null and is_instance_valid(source) else 0
		var glow := 0.72 + 0.28 * sin(pulse * TAU * 2.0)
		var mid := 2.0
		for i in range(5):
			var pp := Vector2((float(i) - mid) * 9.0, -39.0 - absf(float(i) - mid) * 2.0)
			var active := i < count
			var c := Color(col.r, col.g, col.b, (0.9 * glow) if active else 0.16)
			draw_line(pp + Vector2(0, -8), pp, c, 2.0 if active else 1.0)
			draw_colored_polygon(PackedVector2Array([pp + Vector2(0, 3), pp + Vector2(-3, -2), pp + Vector2(3, -2)]), c)
		# 单体锁定符：小号开口环，不画会误读为 AoE 的地面范围圈。
		draw_arc(Vector2(0, -10), 13.0, -PI * 0.15, PI * 1.15, 18, Color(col.r, col.g, col.b, 0.55 * glow), 1.8)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## 天降陨石（宋江 W 演出）：一颗巨型火球从起点滚到终点（life 秒匀速），亮核+不规则外焰+飞火星+地面焦痕。
## 只负责画；碾压/地火伤害在 Battle._zone_pass 的 _meteor_zones 结算（视觉与伤害同速、同向）。
## 陷阱地面标记（持续显示，直到触发被销毁）：贴地暗斑 + 直立机关图标；布防中虚框闪烁。
## 位置=逻辑落点（fx_root 世界画布按等距投影）。只负责画；触发/伤害在 Battle._trap_pass/_trigger_trap。
class TrapMarkerFx extends Node2D:
	var key := ""
	var col := Color("ffaa44")
	var rad := 22.0
	var armed := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2.ZERO, rad, Color(0.08, 0.06, 0.04, 0.30))             # 贴地暗斑
		draw_circle(Vector2.ZERO, rad * 0.66, Color(col.r, col.g, col.b, 0.16))
		if not armed:                                                             # 布防中：虚框闪烁
			draw_arc(Vector2.ZERO, rad * (1.0 + 0.18 * pulse), 0.0, TAU, 28,
				Color(col.r, col.g, col.b, 0.22 + 0.28 * pulse), 2.0)
		draw_set_transform_matrix(GameMap.ISO_INV)                               # 直立图标
		var tex: Texture2D = Art.trap_texture(key)
		if tex != null:                                                         # 有美术：画机关贴图(布防中半透)
			var s := rad * 2.6
			draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.58, s, s), false,
				Color(1, 1, 1, 1.0) if armed else Color(1, 1, 1, 0.72))
		else:
			match key:                                                          # 无美术兜底：程序化简笔
				"trap_logs":   # 滚木礌石：几根横木
					for i in range(3):
						var y := -6.0 + float(i) * 6.0
						draw_line(Vector2(-12, y), Vector2(12, y), Color(0.55, 0.36, 0.18), 4.0)
						draw_line(Vector2(-12, y), Vector2(12, y), Color(0.30, 0.20, 0.10), 1.0)
				"trap_pit":    # 陷坑：黑洞 + 交叉枝
					draw_circle(Vector2(0, -2), 10.0, Color(0.05, 0.04, 0.03, 0.9))
					draw_line(Vector2(-10, -10), Vector2(10, 4), Color(0.4, 0.34, 0.2), 2.0)
					draw_line(Vector2(10, -10), Vector2(-10, 4), Color(0.4, 0.34, 0.2), 2.0)
				"trap_oil":    # 火油：油渍 + 反光
					draw_circle(Vector2(0, -2), 11.0, Color(0.10, 0.07, 0.04, 0.85))
					draw_circle(Vector2(-3, -5), 3.0, Color(1.0, 0.6, 0.2, 0.5))
				_:
					draw_circle(Vector2(0, -2), 8.0, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class MeteorFx extends TimedFx:
	var start_w := Vector2.ZERO
	var end_w := Vector2.ZERO
	var rad := 48.0
	var life := 2.0
	var col := Color("ff7a2a")
	var _roll := 0.0
	var _embers: Array = []

	func _ready() -> void:
		dur = life
		t = life
		position = start_w
		for i in range(14):
			_embers.append({"a": randf() * TAU, "d": randf(), "sp": randf_range(40.0, 95.0), "ph": randf() * TAU})

	func _process(delta: float) -> void:
		t -= delta
		if t <= 0.0:
			queue_free()
			return
		var k := clampf(1.0 - t / maxf(dur, 0.01), 0.0, 1.0)
		position = start_w.lerp(end_w, k)
		_roll += delta * 4.5
		queue_redraw()

	# 卡通滚动火球：粗描边 + 平涂橙 + 钝头火舌；偏心亮斑与深色斑随 _roll 转 → 一眼看出在「滚」。
	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var R := rad
		var k := clampf(1.0 - t / maxf(dur, 0.01), 0.0, 1.0)
		# 入场：从天而降的下坠尾迹（前 0.16 段）
		if k < 0.16:
			var fall := 1.0 - k / 0.16
			draw_line(Vector2(0, -300.0 * fall), Vector2.ZERO, Color(1.0, 0.6, 0.2, 0.5 * fall), R * 0.6)
		# 地面影子（压扁暗椭圆）
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, R * 0.9, Color(0.10, 0.05, 0.02, 0.40))
		draw_set_transform_matrix(GameMap.ISO_INV)
		var OUT := Color(0.22, 0.06, 0.02)   # 卡通粗描边
		var BODY := Color(1.0, 0.42, 0.10)   # 平涂橙
		var HI := Color(1.0, 0.74, 0.24)     # 浅橙高光
		var CORE := Color(1.0, 0.95, 0.66)   # 亮黄核
		# 钝头火舌一圈（描边层 + 亮层），随滚动转
		var n := 9
		for i in range(n):
			var ang := TAU * float(i) / float(n) + _roll
			var dirp := Vector2(cos(ang), sin(ang))
			var perp := Vector2(-dirp.y, dirp.x)
			var tip := dirp * (R * 1.34)
			var b1 := dirp * (R * 0.86) + perp * (R * 0.34)
			var b2 := dirp * (R * 0.86) - perp * (R * 0.34)
			draw_colored_polygon(PackedVector2Array([b1, b2, tip]), OUT)
			draw_colored_polygon(PackedVector2Array([b1 + dirp * 2.0, b2 + dirp * 2.0, tip * 0.9]), BODY)
		# 球体：描边 → 平涂橙
		draw_circle(Vector2.ZERO, R + 3.0, OUT)
		draw_circle(Vector2.ZERO, R, BODY)
		# 滚动标记：偏心亮斑 + 深色斑随 _roll 公转 → 明显在滚
		var off := Vector2(cos(_roll), sin(_roll)) * (R * 0.42)
		draw_circle(off, R * 0.46, HI)
		draw_circle(off + Vector2(cos(_roll), sin(_roll)) * (R * 0.20), R * 0.26, CORE)
		draw_circle(Vector2(cos(_roll + 2.3), sin(_roll + 2.3)) * (R * 0.55), R * 0.14, OUT)
		draw_circle(Vector2(cos(_roll - 1.9), sin(_roll - 1.9)) * (R * 0.60), R * 0.11, OUT)
		# 飞溅火星
		for em in _embers:
			var a: float = float(em["a"]) + _roll * 0.5
			var rr: float = R * (0.7 + 0.55 * float(em["d"]))
			draw_circle(Vector2(cos(a), sin(a)) * rr, 2.6, HI)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 地面烈焰（DOT 区域演出）：半径内持续腾起火舌 + 飞火星，整段 life 秒里反复窜起，
## 首尾各 0.5 秒淡入淡出。只负责画；伤害在 Battle._ground_dot_pass 结算。
class GroundFireFx extends TimedFx:
	var rad := 95.0
	var col := Color("ff7a2a")
	var life := 5.0
	var lite := false
	var _flames: Array = []
	var _embers: Array = []

	func _ready() -> void:
		dur = life
		t = life
		var n := (5 + int(rad / 20.0)) if lite else (10 + int(rad / 10.0))
		for i in range(n):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad
			_flames.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"h": randf_range(20.0, 40.0), "w": randf_range(7.0, 14.0),
				"ph": randf() * TAU, "rate": randf_range(1.4, 2.4)})
		var ember_n := (3 + int(rad / 18.0)) if lite else (int(rad / 8.0) + 6)
		for i in range(ember_n):
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


## 技能弹道通用演出（bolt 追踪弹 / hook 钩头）：发光弹体 + 渐隐尾迹；chain=true 时画回施法者的
## 连节锁链（钩镰）。位置由 battle._bolt_pass 每帧驱动；命中/落空由 pass 负责 queue_free。
class BoltFx extends Node2D:
	var col := Color(0.8, 0.85, 1.0)
	var chain := false
	var chain_from: Unit = null
	var art := ""            # 弹体皮肤（bolt_art）：axe/poison/ice/dark → fx_items；lasso → fx_kit2
	var _trail: Array = []   # 世界坐标尾迹
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		_trail.append(position)
		if _trail.size() > 10:
			_trail.pop_front()
		queue_redraw()

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)   # 切回屏幕空间：弹体画正圆、链条走直线
		if chain and chain_from != null and is_instance_valid(chain_from):
			var back := GameMap.ISO.basis_xform(chain_from.position - position)
			var n := maxi(3, int(back.length() / 13.0))
			for i in range(n + 1):
				var pt := back * (float(i) / float(n))
				var sway := sin(_t * 9.0 + float(i) * 0.9) * 2.0   # 链条轻微垂摆
				draw_arc(pt + Vector2(0, sway), 3.0, 0.0, TAU, 8,
					Color(col.r * 0.75, col.g * 0.72, col.b * 0.6, 0.9), 1.6)
		for i in range(_trail.size()):
			var f := float(i + 1) / float(_trail.size())
			var tp := GameMap.ISO.basis_xform(Vector2(_trail[i]) - position)
			draw_circle(tp, 3.2 * f, Color(col.r, col.g, col.b, 0.28 * f))
		var pu := 1.0 + 0.15 * sin(_t * 18.0)
		draw_circle(Vector2.ZERO, 7.5 * pu, Color(col.r, col.g, col.b, 0.30))
		# 弹体：优先手绘贴图（钩头/皮肤道具/红锦套索），无图退回发光弹珠
		var tex: Texture2D = null
		if chain:
			tex = Art.kit2_texture("hook")
		elif art == "lasso":
			tex = Art.kit2_texture("bolt")
		elif art != "":
			tex = Art.item_texture(art)
			if tex == null:
				tex = Art.dota_projectile_texture(art)
		if tex != null:
			var ts := 34.0 if chain else 28.0
			var spin := sin(_t * 6.0) * 0.25   # 飞行中轻微摇摆
			draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(spin, Vector2.ONE, 0.0, Vector2.ZERO))
			draw_texture_rect(tex, Rect2(Vector2(-ts * 0.5, -ts * 0.5), Vector2(ts, ts)), false)
			draw_set_transform_matrix(GameMap.ISO_INV)
		else:
			draw_circle(Vector2.ZERO, 4.4 * pu, Color(col.r, col.g, col.b, 0.85))
			draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## DOTA 批量技能：一次性投掷/抛射演出（不参与命中判定；真实结算仍由 _do_ability 当帧完成）。
class DotaProjectileFx extends TimedFx:
	var end_w := Vector2.ZERO
	var col := Color(0.85, 0.85, 1.0)
	var tex: Texture2D = null
	var impact_tex: Texture2D = null
	var lob := false
	var _E := Vector2.ZERO
	var _ang := 0.0

	func _ready() -> void:
		dur = 0.62
		t = dur
		_E = GameMap.ISO.basis_xform(end_w - position)
		_ang = _E.angle()

	func _draw() -> void:
		var elapsed := dur - t
		var fly := 0.34
		var p := clampf(elapsed / fly, 0.0, 1.0)
		draw_set_transform_matrix(GameMap.ISO_INV)
		if p < 1.0:
			var pos := _E * p
			if lob:
				pos.y -= sin(p * PI) * 44.0
			for i in range(8):
				var q := maxf(0.0, p - float(i) * 0.045)
				var tp := _E * q
				if lob:
					tp.y -= sin(q * PI) * 44.0
				draw_circle(tp, 5.0 * (1.0 - float(i) / 9.0), Color(col.r, col.g, col.b, 0.28 * (1.0 - float(i) / 8.0)))
			draw_circle(pos, 13.0, Color(col.r, col.g, col.b, 0.22))
			if tex != null:
				var ts := 32.0
				draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_ang + sin(elapsed * 13.0) * 0.18, Vector2.ONE, 0.0, pos))
				draw_texture_rect(tex, Rect2(Vector2(-ts * 0.5, -ts * 0.5), Vector2(ts, ts)), false, Color(1, 1, 1, 0.98))
				draw_set_transform_matrix(GameMap.ISO_INV)
			else:
				draw_circle(pos, 5.2, Color(col.r, col.g, col.b, 0.9))
				draw_circle(pos + Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.9))
		else:
			var k := clampf((elapsed - fly) / maxf(dur - fly, 0.01), 0.0, 1.0)
			var bf := 1.0 - k
			if impact_tex != null:
				var sz := 50.0 + 24.0 * k
				draw_texture_rect(impact_tex, Rect2(_E - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), false, Color(1, 1, 1, 0.9 * bf))
			draw_circle(_E, 16.0 * (0.6 + k), Color(col.r, col.g, col.b, 0.26 * bf))
			draw_arc(_E, 26.0 * (0.5 + k), 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.85 * bf), 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 建筑坍塌演出（AoE2 式碎块）：贴图切成 N×N 小块，底层先垮、上层随后坠落，各块带
## 随机延迟/横漂/翻暗，落地即散；底部腾起尘雾 + 扩散尘环——散尽后不留任何废墟。
class BuildingCollapseFx extends TimedFx:
	var tex: Texture2D = null
	var s := 96.0
	const N := 10   # 10×10 = 100 块碎片：块切得细才有「一块块塌下来」的颗粒感

	func _ready() -> void:
		dur = 1.1
		t = dur

	## 确定性伪随机（按块索引），逐帧重绘不闪变
	func _rnd(i: int, j: int) -> float:
		return absf(fmod(sin(float(i * 73 + j * 131 + 7)) * 43758.5453, 1.0))

	func _draw() -> void:
		var p := 1.0 - clampf(t / dur, 0.0, 1.0)   # 0→1 坍塌进度
		draw_set_transform_matrix(GameMap.ISO_INV)
		# 尘环：向外扩散渐淡
		var dr := s * (0.30 + 0.80 * p)
		draw_arc(Vector2.ZERO, dr, 0.0, TAU, 30, Color(0.58, 0.50, 0.40, (1.0 - p) * 0.5), 1.0 + 6.0 * (1.0 - p))
		draw_circle(Vector2.ZERO, dr * 0.5, Color(0.50, 0.44, 0.36, (1.0 - p) * 0.20))
		if tex != null:
			var tw := float(tex.get_width())
			var th := float(tex.get_height())
			var cw := s / float(N)
			for j in range(N):
				for i in range(N):
					var rnd := _rnd(i, j)
					# 底层(大 j)先垮、上层随后坠落；同层各块随机错峰
					var delay := (1.0 - float(j) / float(N - 1)) * 0.10 + 0.06 + rnd * 0.24
					var lp := clampf((p * 1.5 - delay) / 0.6, 0.0, 1.0)   # 本块坠落进度
					if lp >= 1.0:
						continue   # 已落定消散
					var x0 := -s * 0.5 + float(i) * cw
					var y0 := -s * 0.78 + float(j) * cw
					var ground := s * 0.10 + rnd * s * 0.06          # 落点：基座线附近略散
					var fall := lp * lp * (ground - y0)               # 重力二次加速坠向地面（顶层坠得远）
					var drift := (rnd - 0.5) * s * 0.18 * lp          # 横漂
					var dark := 1.0 - lp * 0.55                       # 坠落中翻暗
					var a := clampf((1.0 - lp) * 1.6, 0.0, 1.0)       # 落地前后淡出
					draw_texture_rect_region(tex,
						Rect2(x0 + drift, y0 + fall, cw, cw),
						Rect2(float(i) * tw / N, float(j) * th / N, tw / N, th / N),
						Color(dark, dark * 0.97, dark * 0.92, a))
		# 底部尘雾：几团灰云自基座腾起、渐大渐淡
		for k in range(5):
			var kr := _rnd(k, 3)
			var kp := clampf(p * 1.4 - kr * 0.3, 0.0, 1.0)
			if kp <= 0.0 or kp >= 1.0:
				continue
			var px := (kr - 0.5) * s * 0.8
			draw_circle(Vector2(px, s * 0.06 - kp * s * 0.28),
				s * (0.07 + kp * 0.13), Color(0.55, 0.49, 0.41, (1.0 - kp) * 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## DOTA 批量技能：符文、命中、变身、吼叫、光环等落点演出。
class DotaImpactFx extends TimedFx:
	var rad := 90.0
	var col := Color(0.85, 0.85, 1.0)
	var tex: Texture2D = null
	var mode := "impact"

	func _ready() -> void:
		dur = 0.78
		t = dur

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		var rr := clampf(rad * (0.35 + 0.55 * grow), 24.0, 125.0)
		if tex != null:
			var sz := clampf(rad * 0.55, 34.0, 82.0) * (0.82 + grow * 0.22)
			draw_texture_rect(tex, Rect2(Vector2(-sz * 0.5, -sz * 0.5), Vector2(sz, sz)), false, Color(1, 1, 1, 0.92 * f))
		match mode:
			"aura":
				for i in range(3):
					var pr := rr * (0.45 + grow * 0.85) - float(i) * 18.0
					if pr > 8.0:
						draw_arc(Vector2.ZERO, pr, 0.0, TAU, 36, Color(col.r, col.g, col.b, f * (0.8 - 0.14 * float(i))), 2.4)
				draw_circle(Vector2.ZERO, rr * 0.35, Color(col.r, col.g, col.b, 0.16 * f))
			"rune":
				var pts := PackedVector2Array([Vector2(0, -rr * 0.42), Vector2(rr * 0.48, 0), Vector2(0, rr * 0.42), Vector2(-rr * 0.48, 0)])
				draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.12 * f))
				var closed := PackedVector2Array()
				for p in pts:
					closed.append(p)
				closed.append(pts[0])
				draw_polyline(closed, Color(col.r, col.g, col.b, 0.92 * f), 2.4)
				draw_arc(Vector2.ZERO, rr * 0.62, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.45 * f), 1.6)
			"manifest":
				for i in range(8):
					var a := float(i) / 8.0 * TAU + grow * 1.8
					var p := Vector2(cos(a), sin(a) * 0.65) * rr * (0.35 + grow * 0.45)
					draw_circle(p + Vector2(0, -18.0 * grow), 4.5 * f, Color(col.r, col.g, col.b, 0.72 * f))
				draw_circle(Vector2.ZERO, 18.0 * (0.5 + grow), Color(1, 1, 1, 0.32 * f))
			"roar":
				for i in range(3):
					var off := float(i) * 14.0
					draw_arc(Vector2(-off, -4.0), rr * (0.35 + 0.22 * float(i) + grow * 0.45), -0.42, 0.42, 18, Color(col.r, col.g, col.b, 0.82 * f), 3.0 - float(i) * 0.5)
					draw_arc(Vector2(off, -4.0), rr * (0.35 + 0.22 * float(i) + grow * 0.45), PI - 0.42, PI + 0.42, 18, Color(col.r, col.g, col.b, 0.82 * f), 3.0 - float(i) * 0.5)
			_:
				draw_circle(Vector2.ZERO, rr * 0.45, Color(col.r, col.g, col.b, 0.16 * f))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.82 * f), 2.6)
				for i in range(10):
					var a := float(i) / 10.0 * TAU
					var d := Vector2(cos(a), sin(a) * 0.62)
					draw_line(d * rr * 0.35, d * rr * (0.62 + grow * 0.38), Color(col.r, col.g, col.b, 0.58 * f), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## DOTA 批量技能：直线光束/链条/冲刺轨迹。
class DotaBeamFx extends TimedFx:
	var start_w := Vector2.ZERO
	var end_w := Vector2.ZERO
	var col := Color(0.85, 0.85, 1.0)
	var chain := false
	var dash := false
	var _S := Vector2.ZERO
	var _E := Vector2.ZERO

	func _ready() -> void:
		dur = 0.46
		t = dur
		_S = GameMap.ISO.basis_xform(start_w - position)
		_E = GameMap.ISO.basis_xform(end_w - position)

	func _draw() -> void:
		draw_set_transform_matrix(GameMap.ISO_INV)
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		var head := _S.lerp(_E, clampf(grow / 0.65, 0.0, 1.0))
		if chain:
			var seg := _E - _S
			var n := maxi(3, int(seg.length() / 15.0))
			for i in range(n + 1):
				var p := _S + seg * (float(i) / float(n))
				if _S.distance_to(p) > _S.distance_to(head):
					break
				draw_arc(p, 4.2, 0.0, TAU, 8, Color(col.r, col.g, col.b, 0.9 * f), 1.6)
		elif dash:
			var segd := head - _S
			for i in range(7):
				var a := float(i) / 7.0
				var p0 := _S + segd * a
				var p1 := _S + segd * minf(1.0, a + 0.08)
				draw_line(p0, p1, Color(col.r, col.g, col.b, f * (0.85 - 0.07 * float(i))), 5.5 - float(i) * 0.45)
		else:
			draw_line(_S, head, Color(col.r, col.g, col.b, 0.38 * f), 9.0)
			draw_line(_S, head, Color(1, 1, 1, 0.82 * f), 2.4)
		draw_circle(_S, 7.0 * f, Color(col.r, col.g, col.b, 0.52 * f))
		draw_arc(_E, 22.0 * grow, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.7 * f), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## DOTA 批量技能：扇形/震击/横扫类演出。
class DotaSweepFx extends TimedFx:
	var end_w := Vector2.ZERO
	var rad := 90.0
	var col := Color(0.85, 0.85, 1.0)
	var _E := Vector2.ZERO
	var _ang := 0.0

	func _ready() -> void:
		dur = 0.42
		t = dur
		_E = GameMap.ISO.basis_xform(end_w - position)
		if _E.length() < 1.0:
			_E = Vector2(rad, 0)
		_ang = _E.angle()

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		var reach := maxf(_E.length(), rad * 0.8)
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(_ang, Vector2.ONE, 0.0, Vector2.ZERO))
		for i in range(3):
			var rr := reach * (0.34 + 0.21 * float(i)) * minf(1.0, grow * 1.65)
			draw_arc(Vector2.ZERO, rr, -0.58, 0.58, 24, Color(col.r, col.g, col.b, f * (0.84 - 0.16 * float(i))), 3.0 - float(i) * 0.45)
		var tip := Vector2(reach * minf(1.0, grow * 1.35), 0)
		draw_line(Vector2.ZERO, tip, Color(1, 1, 1, 0.72 * f), 2.2)
		draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(18, 10), tip - Vector2(18, -10)]), Color(col.r, col.g, col.b, 0.58 * f))
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
	var tex: Texture2D = null   # 手绘环绕物贴图（orbit_art，如李逵板斧）；null=程序化斧刃
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
			if tex != null:
				# 手绘板斧贴图：斧刃朝切线方向随轨道公转 + 自旋（李逵 Q 专属演出）
				var rot := a + PI * 0.5 + _spin * 1.5
				draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(rot, Vector2.ONE, 0.0, c))
				var ts := 34.0
				draw_texture_rect(tex, Rect2(Vector2(-ts * 0.5, -ts * 0.5), Vector2(ts, ts)), false, Color(1, 1, 1, env))
				draw_set_transform_matrix(GameMap.ISO_INV)
			else:
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


## 李逵 E·蛮力：一节点批量绘制/结算本次触发的所有飞斧，密集战斗也不会按目标数创建 Node。
class LiBrawnAxesFx extends Node2D:
	var caster: Unit = null
	var game = null
	var hits: Array = []          # [{target: Unit, dmg: float}]
	var tex: Texture2D = null
	var dur := 0.36
	var elapsed := 0.0
	var resolved := false

	func _process(delta: float) -> void:
		elapsed += delta
		if elapsed >= dur:
			resolve_hits()
			return
		queue_redraw()

	## 命中只造成一次飞斧伤害；不调用普通攻击流程，因此不会递归触发蛮力或附带暴击/攻击特效。
	func resolve_hits() -> void:
		if resolved:
			return
		resolved = true
		var src: Unit = caster if is_instance_valid(caster) else null
		for hit in hits:
			var target: Unit = hit.get("target")
			if not is_instance_valid(target) or target.hp <= 0.0 or target.garrisoned:
				continue
			var dmg := float(hit.get("dmg", 0.0))
			if target.is_phys_immune():
				target.absorb_physical_damage(dmg, src)
			else:
				target.take_damage(dmg, src)
			if game != null and is_instance_valid(game):
				game.spawn_impact(target.position, true)
		queue_free()

	func _draw() -> void:
		var p := clampf(elapsed / maxf(dur, 0.01), 0.0, 1.0)
		var fly := 1.0 - pow(1.0 - p, 2.0)   # 起手快、入靶稍收，飞斧更有重量感
		for hit in hits:
			var target: Unit = hit.get("target")
			if not is_instance_valid(target) or target.hp <= 0.0:
				continue
			var end_screen := GameMap.ISO.basis_xform(target.position - position)
			var axe_pos := end_screen * fly + Vector2(0, -sin(p * PI) * 10.0)
			var angle := end_screen.angle() + elapsed * 18.0
			# 短拖尾：同一 Node 内批量画，不额外分配粒子节点。
			draw_set_transform_matrix(GameMap.ISO_INV)
			for j in range(3):
				var q := maxf(0.0, fly - float(j + 1) * 0.06)
				var trail_pos := end_screen * q + Vector2(0, -sin(q * PI) * 10.0)
				draw_circle(trail_pos, 3.5 - float(j) * 0.8, Color(1.0, 0.38, 0.18, 0.20 - float(j) * 0.045))
			if tex != null:
				draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(angle, Vector2.ONE, 0.0, axe_pos))
				draw_texture_rect(tex, Rect2(Vector2(-15, -15), Vector2(30, 30)), false)
			else:
				draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(angle, Vector2.ONE, 0.0, axe_pos))
				draw_line(Vector2(-10, 0), Vector2(8, 0), Color("8b5a32"), 3.0)
				draw_colored_polygon(PackedVector2Array([Vector2(3, -8), Vector2(12, -5), Vector2(12, 5), Vector2(3, 8)]), Color("d8dce2"))
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


## 立桩演出（治疗桩/死神之眼/毒桩）：地面脉冲光环 + 立着的发光图腾桩。style 决定桩头符号与气质。
class WardFx extends TimedFx:
	var rad := 200.0
	var col := Color("a0e8c0")
	var life := 8.0
	var style := "heal"
	var banner_kind := ""
	var _ph := 0.0

	func _ready() -> void:
		dur = life
		t = life
		_ph = float((int(position.x) * 7 + int(position.y) * 3) % 100) * 0.06

	func _process(delta: float) -> void:
		_ph += delta
		super._process(delta)

	func _draw() -> void:
		var env := clampf((dur - t) / 0.3, 0.0, 1.0) * clampf(t / 0.6, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(_ph * 3.0)
		# 地面光环（default 空间自动等距压扁，贴地）
		draw_circle(Vector2.ZERO, rad, Color(col.r, col.g, col.b, env * 0.06))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 56, Color(col.r, col.g, col.b, env * (0.22 + 0.18 * pulse)), 2.0)
		var pk := fposmod(_ph * 0.5, 1.0)   # 一圈外扩脉冲
		draw_arc(Vector2.ZERO, rad * (0.35 + 0.6 * pk), 0.0, TAU, 48, Color(col.r, col.g, col.b, env * 0.28 * (1.0 - pk)), 1.6)
		# 桩体：有手绘贴图(assets/wards.png)就用贴图，立在中心、底贴地、随脉冲轻起伏；否则程序化发光图腾
		var topp := Vector2(0, -38.0)
		var tex: Texture2D = Art.ward_texture(style)
		var upright_particles := false
		if tex != null:
			var ih := maxf(float(tex.get_height()), 1.0)
			var th := 58.0 + 3.0 * pulse
			var tw := th * (float(tex.get_width()) / ih)
			draw_texture_rect(tex, Rect2(-tw * 0.5, -th + 5.0, tw, th), false, Color(1, 1, 1, clampf(env * 1.3, 0.0, 1.0)))
			draw_circle(Vector2(0, -th * 0.6), 9.0 + 3.0 * pulse, Color(col.r, col.g, col.b, env * 0.20))   # 桩头辉光叠在贴图上
			topp = Vector2(0, -th + 8.0)
		else:
			if style == "banner":
				# 忠义旗没有贴图时直接绘制：抵消世界等距变换，让旗杆保持竖直、旗面文字不歪斜。
				upright_particles = true
				draw_set_transform_matrix(GameMap.ISO_INV)
				topp = Vector2(0, -64.0)
				draw_line(Vector2(0, 4), topp, Color(0.24, 0.15, 0.07, env), 7.0)
				var loyalty := banner_kind == "loyalty"
				var side := -1.0 if loyalty else 1.0   # 忠旗向左、义旗向右，成对落下时交叉展开
				var cloth_col := Color(0.12, 0.43, 0.82, env * 0.96) if loyalty else Color(0.96, 0.69, 0.12, env * 0.96)
				var edge_col := Color(0.06, 0.18, 0.38, env) if loyalty else Color(0.32, 0.19, 0.06, env)
				var text_col := Color(0.90, 0.96, 1.0, env) if loyalty else Color(1.0, 0.93, 0.62, env)
				draw_line(Vector2(-1, 3), topp + Vector2(-1, 0), col.lightened(0.25) * Color(1, 1, 1, env), 2.2)
				var flap := 3.0 * sin(_ph * 3.4)
				var cloth := PackedVector2Array([topp + Vector2(2 * side, 2), topp + Vector2(42 * side, 8 + flap),
					topp + Vector2(34 * side, 30 + flap), topp + Vector2(2 * side, 24)])
				draw_colored_polygon(cloth, cloth_col)
				draw_polyline(PackedVector2Array([cloth[0], cloth[1], cloth[2], cloth[3], cloth[0]]), edge_col, 2.0)
				var font := ThemeDB.fallback_font
				var text_x := -38.0 if loyalty else 8.0
				var glyph := "忠" if loyalty else "义"
				draw_string_outline(font, topp + Vector2(text_x, 22 + flap), glyph, HORIZONTAL_ALIGNMENT_CENTER, 30, 16, 3, edge_col)
				draw_string(font, topp + Vector2(text_x, 22 + flap), glyph, HORIZONTAL_ALIGNMENT_CENTER, 30, 16, text_col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				topp = Vector2(0, -38.0)
				draw_line(Vector2(0, -2), topp, Color(0.30, 0.21, 0.13, env), 7.0)            # 桩身
				draw_line(Vector2(0, -2), topp, Color(col.r * 0.6 + 0.25, col.g * 0.6 + 0.25, col.b * 0.6 + 0.25, env * 0.55), 2.6)
				var head := topp + Vector2(0, -3)
				draw_circle(head, 8.0 + 2.5 * pulse, Color(col.r, col.g, col.b, env * 0.32))   # 桩头辉光
				draw_circle(head, 5.0, Color(minf(col.r + 0.3, 1.0), minf(col.g + 0.3, 1.0), minf(col.b + 0.3, 1.0), env))
				if style == "heal":   # 十字医徽
					draw_line(head + Vector2(-3, 0), head + Vector2(3, 0), Color(1, 1, 1, env * 0.9), 1.6)
					draw_line(head + Vector2(0, -3), head + Vector2(0, 3), Color(1, 1, 1, env * 0.9), 1.6)
				else:   # 凶光眼
					draw_circle(head, 2.0, Color(1.0, 0.92, 0.92, env))
		if upright_particles:
			draw_set_transform_matrix(GameMap.ISO_INV)   # 旗顶坐标在直立空间，粒子必须跟旗使用同一变换
		for i in range(4):   # 桩顶上升的灵气微粒（贴图/程序化通用）
			var k := fposmod(_ph * 0.6 + float(i) * 0.25, 1.0)
			var px := sin((_ph + float(i)) * 2.0) * 6.0
			draw_circle(topp + Vector2(px, -k * 22.0), 1.8 * (1.0 - k), Color(col.r, col.g, col.b, env * (1.0 - k) * 0.8))
		if upright_particles:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 裂地演出（鲁智深 Q）：沿指向一道发光裂缝 + 两侧拱起的碎石，与阻路实墙同寿。default 空间贴地。
class EarthCrackFx extends TimedFx:
	var dir := Vector2.RIGHT
	var length := 320.0
	var col := Color("8a5a2a")
	var life := 4.0
	var _pts: PackedVector2Array
	var _rub: Array = []

	func _ready() -> void:
		dur = life
		t = life
		var perp := Vector2(-dir.y, dir.x)
		var n := maxi(6, int(length / 26.0))
		_pts = PackedVector2Array()
		for i in range(n + 1):
			var f := float(i) / float(n)
			var jit := 0.0
			if i > 0 and i < n:
				jit = float((i * 37) % 100 - 50) / 50.0 * 9.0
			var p: Vector2 = dir * (f * length) + perp * jit
			_pts.append(p)
			if i % 2 == 0:
				_rub.append(p)

	func _draw() -> void:
		var env := clampf((dur - t) / 0.2, 0.0, 1.0) * clampf(t / 0.6, 0.0, 1.0)
		if _pts.size() >= 2:
			draw_polyline(_pts, Color(0.10, 0.07, 0.05, env * 0.9), 10.0)                  # 裂缝黑芯
			var glow := env * 0.7 * (0.55 + 0.45 * sin((dur - t) * 7.0))
			draw_polyline(_pts, Color(1.0, 0.5, 0.16, glow), 3.0)                            # 缝底岩浆辉光
		for p in _rub:
			draw_circle(p + Vector2(0, -2), 2.8, Color(col.r, col.g, col.b, env * 0.85))     # 拱起碎石
			draw_circle(p + Vector2(0, -2), 2.8, Color(col.r * 1.3, col.g * 1.2, col.b, env * 0.3))


## 回音重踏演出（鲁智深 R）：中心碎裂 + 多重外扩冲击环 + 放射地裂；每个被命中的敌人脚下再炸一记小回音环。
class EchoSlamFx extends TimedFx:
	var rad := 280.0
	var col := Color("8a5a2a")

	func _ready() -> void:
		dur = 0.85
		t = 0.85

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0)
		var f := 1.0 - env   # 0→1 推进
		for i in range(3):   # 多重外扩冲击环
			var rr := rad * clampf(f * 1.2 - float(i) * 0.16, 0.0, 1.0)
			if rr > 1.0:
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 52, Color(col.r * 1.4 + 0.2, col.g * 1.2 + 0.1, col.b, env * 0.6 * (1.0 - float(i) * 0.25)), 3.5 - float(i))
		draw_circle(Vector2.ZERO, rad * 0.13 * (1.0 - f), Color(1.0, 0.7, 0.3, env * 0.7))   # 中心碎裂闪
		for k in range(10):   # 放射地裂
			var a := float(k) * TAU / 10.0 + 0.3
			var d := Vector2(cos(a), sin(a))
			var l := rad * minf(1.0, f * 1.3)
			draw_line(d * rad * 0.1, d * l, Color(0.12, 0.08, 0.05, env * 0.7), 3.0)
			draw_line(d * rad * 0.1, d * l, Color(1.0, 0.45, 0.15, env * 0.4), 1.2)


## 镜分演出（董平 R）：每名分身现身处一道竖向镜光 + 一串从本体飞来的残影点（虚实分裂感）。
class SplitMirrorFx extends TimedFx:
	var col := Color("8fd3ff")
	var from_w := Vector2.ZERO

	func _ready() -> void:
		dur = 0.5
		t = 0.5

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0)
		var f := 1.0 - env
		draw_line(Vector2(0, -32), Vector2(0, 6), Color(col.r, col.g, col.b, env * 0.85), 3.0 * env + 1.0)   # 镜面竖光
		draw_line(Vector2(0, -32), Vector2(0, 6), Color(1, 1, 1, env * 0.5), 1.0)
		draw_arc(Vector2.ZERO, 22.0 * f, 0.0, TAU, 20, Color(col.r, col.g, col.b, env * 0.5), 1.5)
		var rel := from_w - position   # 从本体到此处的残影点
		for i in range(5):
			var k := float(i) / 5.0
			draw_circle(rel * (1.0 - f) * (1.0 - k), 3.0 * env * (1.0 - k), Color(col.r, col.g, col.b, env * 0.5 * (1.0 - k)))


## 萤火演出（魏定国 E·火萤流）：随施法者飞舞的一群橙红萤火，存续整段火径时间。
class FireflyFx extends TimedFx:
	var follow: Unit = null
	var life := 6.0
	var col := Color("ff7a2a")
	var _motes: Array = []

	func _ready() -> void:
		dur = life
		t = life
		for i in range(10):
			_motes.append({"a": float(i) * 0.63, "r": 10.0 + float(i % 4) * 5.0, "sp": 1.6 + float(i % 3) * 0.5, "ph": float(i) * 0.9})

	func _process(delta: float) -> void:
		if follow != null and is_instance_valid(follow) and follow.hp > 0.0:
			position = follow.position
		else:
			t = minf(t, 0.1)
		super._process(delta)

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0) * clampf((dur - t) / 0.3, 0.0, 1.0)
		var tt := dur - t
		for m in _motes:
			var a := float(m["a"]) + tt * float(m["sp"])
			var rr := float(m["r"]) * (0.7 + 0.3 * sin(tt * 3.0 + float(m["ph"])))
			var p := Vector2(cos(a) * rr, sin(a) * rr * 0.55 - 9.0 - 4.0 * sin(tt * 2.0 + float(m["ph"])))
			var fl := 0.6 + 0.4 * sin(tt * 8.0 + float(m["ph"]))
			draw_circle(p, 4.0 * fl, Color(1.0, 0.5, 0.15, env * 0.22))
			draw_circle(p, 2.0 * fl, Color(1.0, 0.6 + 0.3 * fl, 0.2, env * 0.9))


## 一线点燃演出（解珍 R）：火舌沿指向「逐段点燃」铺过去，前锋一记亮闪——一线长焰焚来路。
class FireLineFx extends TimedFx:
	var dir := Vector2.RIGHT
	var length := 340.0
	var col := Color("ff5522")

	func _ready() -> void:
		dur = 0.6
		t = 0.6

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0)
		var f := 1.0 - env   # 点燃推进 0→1
		var lit := length * f
		var steps := int(lit / 16.0)
		for i in range(steps + 1):
			var p := dir * (float(i) * 16.0)
			var h := 14.0 * (0.6 + 0.4 * sin(float(i) * 0.7 + (dur - t) * 10.0))
			draw_line(p, p - Vector2(0, h), Color(1.0, 0.5, 0.15, env * 0.8), 2.5)
			draw_line(p, p - Vector2(0, h * 0.5), Color(1.0, 0.85, 0.4, env * 0.7), 1.4)
		draw_circle(dir * lit, 8.0 * env, Color(1.0, 0.8, 0.4, env * 0.85))   # 点燃前锋亮闪


## 影波节点涟漪（安道全 E）：每个被波及单位脚下一记小涟漪；治友为青绿十字、伤敌为冷蓝环。
class ShadowWaveFx extends TimedFx:
	var col := Color("9fd8ff")
	var heal := false

	func _ready() -> void:
		dur = 0.45
		t = 0.45

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0)
		var f := 1.0 - env
		draw_arc(Vector2.ZERO, 26.0 * f, 0.0, TAU, 24, Color(col.r, col.g, col.b, env * 0.8), 2.0)
		if heal:
			draw_line(Vector2(-4, -14), Vector2(4, -14), Color(0.6, 1.0, 0.7, env), 1.8)
			draw_line(Vector2(0, -18), Vector2(0, -10), Color(0.6, 1.0, 0.7, env), 1.8)


## 摄魂演出（樊瑞 W）：一圈紫魂向落点旋拢，烙下易伤咒印（持续标记画在单位身上）。
class AmpCastFx extends TimedFx:
	var rad := 110.0
	var col := Color("6a4fb0")

	func _ready() -> void:
		dur = 0.7
		t = 0.7

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0)
		var f := 1.0 - env
		for i in range(8):
			var a := float(i) * TAU / 8.0 + f * 4.0
			var rr := rad * (1.0 - f)
			var p := Vector2(cos(a) * rr, sin(a) * rr * 0.6)
			draw_circle(p, 3.2 * env, Color(0.72, 0.42, 0.92, env * 0.85))
		draw_circle(Vector2.ZERO, rad * 0.22 * f, Color(0.5, 0.2, 0.7, env * 0.5))


## 噤声(silence)：落点升起数张紫色封口符纸（升起又落下）+ 一圈向内收拢的封印涟漪——禁敌施法的视觉。
class SilenceFx extends TimedFx:
	var rad := 100.0
	var col := Color("9a5fd0")
	var _talismans: Array = []

	func _ready() -> void:
		dur = 0.8
		t = 0.8
		for i in range(4):
			var a := randf() * TAU
			var d := sqrt(randf()) * rad * 0.7
			_talismans.append({"p": GameMap.ISO.basis_xform(Vector2(cos(a), sin(a)) * d),
				"delay": randf() * 0.2, "sway": randf() * TAU, "h": randf_range(20.0, 30.0)})

	func _draw() -> void:
		var env := clampf(t / dur, 0.0, 1.0)
		var f := 1.0 - env
		# 封印涟漪：一圈紫环向内收拢（"封口"，贴地椭圆）
		draw_arc(Vector2.ZERO, rad * (0.2 + 0.8 * env), 0.0, TAU, 40, Color(col.r, col.g, col.b, f * 0.7), 2.6)
		draw_set_transform_matrix(GameMap.ISO_INV)
		var elapsed := dur - t
		for tl in _talismans:
			var lt: float = elapsed - float(tl["delay"])
			if lt < 0.0:
				continue
			var k := clampf(lt / 0.6, 0.0, 1.0)
			var base: Vector2 = tl["p"]
			var rise := float(tl["h"]) * sin(k * PI)   # 升起又回落
			var sway := sin(float(tl["sway"]) + elapsed * 8.0) * 3.0
			var top := base + Vector2(sway, -rise - 16.0)
			var a := 0.9 * (1.0 - k)
			var w := 5.0
			draw_colored_polygon(PackedVector2Array([top + Vector2(-w, -10), top + Vector2(w, -10), top + Vector2(w, 10), top + Vector2(-w, 10)]), Color(col.r, col.g, col.b, a * 0.9))
			draw_line(top + Vector2(0, -9), top + Vector2(0, 9), Color(0.95, 0.3, 0.3, a), 1.4)   # 符纸朱线
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 破甲(def_down)：落点炸开数片灰色甲叶（抛物飞溅+翻转）+ 地面数道银裂纹——削甲的视觉。
class ArmorCrackFx extends TimedFx:
	var rad := 90.0
	var col := Color("b8c0cc")
	var _shards: Array = []
	var _cracks: Array = []

	func _ready() -> void:
		dur = 0.6
		t = 0.6
		for i in range(9):
			var a := randf() * TAU
			_shards.append({"dir": Vector2(cos(a), sin(a) * 0.6), "spd": randf_range(70.0, 150.0), "rot": randf() * TAU, "sz": randf_range(3.0, 5.5)})
		for i in range(5):
			_cracks.append({"a": randf() * TAU, "len": randf_range(0.5, 1.0), "w": randf_range(1.5, 2.6)})

	func _draw() -> void:
		var f := clampf(t / dur, 0.0, 1.0)
		var grow := 1.0 - f
		for cr in _cracks:   # 地面银裂纹
			var a := float(cr["a"])
			var d := Vector2(cos(a), sin(a))
			var L := rad * float(cr["len"]) * clampf(grow * 1.7, 0.0, 1.0)
			draw_line(d * 5.0, d * L, Color(0.72, 0.76, 0.82, f * 0.8), float(cr["w"]))
		draw_arc(Vector2.ZERO, rad * (0.1 + 0.7 * grow), 0.0, TAU, 32, Color(col.r, col.g, col.b, f * 0.55), 2.2)
		draw_set_transform_matrix(GameMap.ISO_INV)
		var elapsed := dur - t
		for sh in _shards:   # 飞溅的甲叶（抛物线，边翻转边落）
			var k := clampf(elapsed / 0.5, 0.0, 1.0)
			if k >= 1.0:
				continue
			var sdir: Vector2 = sh["dir"]
			var horiz := sdir * float(sh["spd"]) * k
			var vert := -float(sh["spd"]) * 1.3 * k + float(sh["spd"]) * 2.0 * k * k
			var p := horiz + Vector2(0, vert)
			var sz: float = float(sh["sz"]) * (1.0 - k * 0.5)
			var rot := float(sh["rot"]) + elapsed * 9.0
			var q := PackedVector2Array([p + Vector2(-sz, -sz).rotated(rot), p + Vector2(sz, -sz).rotated(rot), p + Vector2(sz, sz).rotated(rot), p + Vector2(-sz, sz).rotated(rot)])
			draw_colored_polygon(q, Color(col.r, col.g, col.b, 0.85 * (1.0 - k)))
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


## 新英雄自检（NEWHERO=1）：公孙胜/武松全技能 + 李逵蛮力飞斧 + 召唤/物免/削甲/减速/英雄上限。
func _newhero_selftest() -> void:
	var origin := Vector2.ZERO
	for u in units:
		if is_instance_valid(u) and u.faction == Unit.FACTION_LIANG and u.key == "hall":
			origin = u.position
			break
	if origin == Vector2.ZERO and not units.is_empty():
		origin = units[0].position
	var _eco_was := economy
	economy = true   # 战役条件：升级制英雄才按 def["abilities"] 建满 4 技能槽（非经济场只建单 ability → 多技能英雄零槽，slot[1] 越界）
	var gong := spawn_unit("gongsun_sheng", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(60, 0)))))
	var wus := spawn_unit("wu_song", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(-60, 0)))))
	var lik := spawn_unit("li_kui", Unit.FACTION_LIANG, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(100, -60)))))
	var foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, map.cell_to_world(map.nearest_open(map.world_to_cell(origin + Vector2(0, 64)))))
	foe.defense = 8.0
	foe.max_hp = 9999.0
	foe.hp = 9999.0
	for h in [gong, wus, lik]:
		for i in h.ability_slots.size():
			h.ability_slots[i]["rank"] = 2
			h.ability_slots[i]["cd_t"] = 0.0
		h._recompute_hero_stats()

	# 公孙胜 Q 黑雨 → _ground_dots 增长，且跟随施法者(follow==gong)；
	# 每跳基础 11，还要计入当前存档的英雄伤害倍率，否则开启驻守成长会让自检假失败。
	var d0 := _ground_dots.size()
	_do_ability(gong, 0, foe.position)
	var blackrain_ok := _ground_dots.size() > d0
	var br_follow_ok: bool = not _ground_dots.is_empty() and _ground_dots[-1].get("follow") == gong \
			and absf(float(_ground_dots[-1]["per"]) - 11.0 * _hero_db(gong)) < 0.6

	# 公孙胜 W 冰墙 → _ice_walls 增长且锁了格子
	gong.ability_slots[1]["cd_t"] = 0.0
	var w0 := _ice_walls.size()
	_do_ability(gong, 1, foe.position)
	var icewall_ok := _ice_walls.size() > w0 and not _ice_walls.is_empty() and not (_ice_walls[-1]["cells"] as Array).is_empty()

	# 公孙胜 E 减速光环（被动）→ _aura_pass 后敌人 aura_slow<1（rank2=-20%）
	# 直接放到公孙胜身边；若再走 nearest_open，不同关卡大厅占地会把两者推到光环外。
	foe.position = gong.position + Vector2(64, 0)
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

	# 武松动画形象统一：待机/行走/攻击各有 4 帧，并且状态内确实会切换到不同帧。
	var wu_idle_frames: Array = Art.unit_anim_frames("wu_song", "idle")
	var wu_walk_frames: Array = Art.unit_anim_frames("wu_song", "walk")
	var wu_attack_frames: Array = Art.unit_anim_frames("wu_song", "attack")
	wus._lunge = 0.0
	wus._cast_t = 0.0
	wus._move_blend = 0.0
	wus._idle_t = 0.0
	var wu_idle_a: Texture2D = wus._anim_frame_for_state(Art.unit_texture("wu_song"))
	wus._idle_t = PI / 1.4
	var wu_idle_b: Texture2D = wus._anim_frame_for_state(Art.unit_texture("wu_song"))
	wus._move_blend = 1.0
	wus._anim_t = 0.0
	var wu_walk_a: Texture2D = wus._anim_frame_for_state(Art.unit_texture("wu_song"))
	wus._anim_t = PI
	var wu_walk_b: Texture2D = wus._anim_frame_for_state(Art.unit_texture("wu_song"))
	wus._lunge = 0.99
	var wu_attack_a: Texture2D = wus._anim_frame_for_state(Art.unit_texture("wu_song"))
	wus._lunge = 0.40
	var wu_attack_b: Texture2D = wus._anim_frame_for_state(Art.unit_texture("wu_song"))
	var wu_anim_ok: bool = wu_idle_frames.size() == 4 and wu_walk_frames.size() == 4 \
			and wu_attack_frames.size() == 4 and wu_idle_frames.has(wu_idle_a) \
			and wu_idle_frames.has(wu_idle_b) and wu_idle_a != wu_idle_b \
			and wu_walk_frames.has(wu_walk_a) and wu_walk_frames.has(wu_walk_b) and wu_walk_a != wu_walk_b \
			and wu_attack_frames.has(wu_attack_a) and wu_attack_frames.has(wu_attack_b) and wu_attack_a != wu_attack_b
	wus._lunge = 0.0
	wus._move_blend = 0.0

	# 李逵 E 蛮力：30% 配置正确；一次触发向120内每个敌人各飞一斧，圈外不命中，伤害按各目标普攻独立计算。
	foe.position = lik.position + Vector2(500, 0)
	var axe_near_a := spawn_unit("guan_dao", Unit.FACTION_GUAN, lik.position + Vector2(36, 0))
	var axe_near_b := spawn_unit("guan_qi", Unit.FACTION_GUAN, lik.position + Vector2(92, 0))
	var axe_far := spawn_unit("guan_dao", Unit.FACTION_GUAN, lik.position + Vector2(132, 0))
	for au in [axe_near_a, axe_near_b, axe_far]:
		au.max_hp = 9999.0
		au.hp = 9999.0
		au.defense = 0.0
		au.set_stance(Unit.STANCE_PASSIVE)
	_grid.clear()   # 上面直接摆坐标；清空间缓存让 units_near 本次回退全表精确扫描。
	var brawn_eff: Dictionary = lik._slot_def(2).get("effect", {})
	var brawn_cfg_ok := absf(float(brawn_eff.get("axe_chance", 0.0)) - 0.30) < 0.001 \
			and absf(float(brawn_eff.get("axe_radius", 0.0)) - 120.0) < 0.01
	var expect_a := lik.secondary_basic_damage_against(axe_near_a)
	var expect_b := lik.secondary_basic_damage_against(axe_near_b)
	var hp_a0 := axe_near_a.hp
	var hp_b0 := axe_near_b.hp
	var hp_far0 := axe_far.hp
	var axe_fx = lik._try_li_brawn_axes(0.0)   # 强制本次随机值命中30%门槛，生产路径仍传默认随机。
	var axe_targets_ok := axe_fx != null
	var axe_art_ok := false
	if axe_fx != null:
		var got_a := false
		var got_b := false
		var got_far := false
		for axe_hit in axe_fx.hits:
			got_a = got_a or axe_hit.get("target") == axe_near_a
			got_b = got_b or axe_hit.get("target") == axe_near_b
			got_far = got_far or axe_hit.get("target") == axe_far
		axe_targets_ok = got_a and got_b and not got_far
		axe_art_ok = axe_fx.tex != null
		axe_fx.resolve_hits()
	var brawn_damage_ok := absf((hp_a0 - axe_near_a.hp) - expect_a) < 0.1 \
			and absf((hp_b0 - axe_near_b.hp) - expect_b) < 0.1 and absf(axe_far.hp - hp_far0) < 0.01
	var li_brawn_ok := brawn_cfg_ok and axe_targets_ok and axe_art_ok and brawn_damage_ok
	# 李逵 Q：整个3秒回旋窗50%减伤；W：从1秒蓄力开始至冲锋结束物理免疫，且不累计武松式转血。
	lik.clear_damage_reduction()
	lik.max_hp = 1000.0
	lik.hp = 1000.0
	lik.ability_slots[0]["cd_t"] = 0.0
	_do_ability(lik, 0, lik.position)
	var li_axes_guard_ok := absf(lik._damage_reduction - 0.50) < 0.001 and lik._stats_mitigation_t > 2.9
	lik.take_damage(100.0, null)
	li_axes_guard_ok = li_axes_guard_ok and absf(lik.hp - 950.0) < 0.1
	_orbit_zones = _orbit_zones.filter(func(z): return z.get("caster") != lik)
	lik.clear_damage_reduction()
	lik.ability_slots[1]["cd_t"] = 0.0
	_do_ability(lik, 1, lik.position + Vector2(180, 0))
	var li_charge_immune_ok := lik._charge_t > 0.9 and lik._charge_dash > 0.0 and lik.is_phys_immune()
	var li_absorbed0 := lik._absorbed_phys
	lik.absorb_physical_damage(80.0, axe_near_a)
	li_charge_immune_ok = li_charge_immune_ok and absf(lik.hp - 950.0) < 0.1 \
			and absf(lik._absorbed_phys - li_absorbed0) < 0.01   # 李逵物免只挡伤，不转血
	lik._charge_t = 0.0
	lik._charge_dash = 0.0
	li_charge_immune_ok = li_charge_immune_ok and not lik.is_phys_immune()
	var li_guard_ok := li_axes_guard_ok and li_charge_immune_ok

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

	# 宋江 W 忠义双旗：2点充能顺序插忠/义；两旗同减伤，忠回血、义加攻速，建筑不吃。
	var banner_troop := spawn_unit("liang_dao", Unit.FACTION_LIANG, song.position + Vector2(24, 0))
	var banner_building: Unit = null
	for bu in units:
		if is_instance_valid(bu) and bu.faction == Unit.FACTION_LIANG and bu.is_building and not bu.is_resource and bu.hp > 0.0:
			banner_building = bu
			break
	var bb_pos := banner_building.position if banner_building != null else Vector2.ZERO
	var bb_hp := banner_building.hp if banner_building != null else 0.0
	var bb_max := banner_building.max_hp if banner_building != null else 0.0
	var banner_rank_ok := true
	var banner_reduce_ok := banner_building != null and dragon != null
	var banner_charge_ok := song.slot_max_charges(1) == 2 and song.slot_charges(1) == 2 \
			and absf(song.slot_charge_recovery(1) - 10.0) < 0.01
	var banner_variant_ok := true
	var loyalty_ok := true
	var righteous_ok := true
	var hero_expect := [0.20, 0.30, 0.40]
	var troop_expect := [0.50, 0.70, 0.90]
	var dur_expect := [5.0, 7.0, 9.0]
	var heal_expect := [20.0, 25.0, 30.0]
	var atkspeed_expect := [1.50, 1.70, 1.90]
	_wards.clear()
	for brank in [1, 2, 3]:
		var bi: int = int(brank) - 1
		song.ability_slots[1]["rank"] = brank
		song.ability_slots[1]["cd_t"] = 0.0
		song.ability_slots[1]["charges"] = 2
		song.ability_slots[1]["recharge_t"] = 0.0
		song.ability_slots[1]["cast_seq"] = 0
		_wards.clear()
		# 第一发必为蓝色忠旗；有1点且正在恢复时仍可立即放第二发。
		_do_ability(song, 1, song.position + Vector2(42, 0))
		if _wards.size() != 1:
			banner_rank_ok = false
			banner_reduce_ok = false
			continue
		var loyalty: Dictionary = _wards[0]
		var one_ready := song.slot_charges(1) == 1 and song.slot_ready(1)
		var recharge_before_second := song.slot_recharge_left(1)
		# 第二发必为黄色义旗，不能重置第一点已开始的10秒恢复。
		_do_ability(song, 1, song.position + Vector2(42, 0))
		if _wards.size() != 2:
			banner_variant_ok = false
			continue
		var righteous: Dictionary = _wards[1]
		var recharge_not_reset := absf(song.slot_recharge_left(1) - recharge_before_second) < 0.01
		var wards_before_third := _wards.size()
		_do_ability(song, 1, song.position + Vector2(42, 0))   # 0点时第三发必须被拒绝
		banner_charge_ok = banner_charge_ok and one_ready and recharge_not_reset \
				and song.slot_charges(1) == 0 and not song.slot_ready(1) and _wards.size() == wards_before_third \
				and song.slot_cast_sequence(1) == 2
		banner_variant_ok = banner_variant_ok and String(loyalty["banner_kind"]) == "loyalty" \
				and String(righteous["banner_kind"]) == "righteous" \
				and Color(loyalty["col"]).b > Color(loyalty["col"]).r \
				and Color(righteous["col"]).r > Color(righteous["col"]).b
		for bw in [loyalty, righteous]:
			banner_rank_ok = banner_rank_ok and absf(float(bw["hero_reduction"]) - float(hero_expect[bi])) < 0.001 \
					and absf(float(bw["troop_reduction"]) - float(troop_expect[bi])) < 0.001 \
					and absf(float(bw["t"]) - float(dur_expect[bi])) < 0.01
		# 忠旗：同减伤 + 每秒治疗；不加攻速，也不再伤害敌军。
		_wards = [loyalty]
		var loyalty_pos: Vector2 = loyalty["pos"]
		gong.position = loyalty_pos + Vector2(18, 0)
		banner_troop.position = loyalty_pos + Vector2(-18, 0)
		foe.position = loyalty_pos + Vector2(0, 24)
		if dragon != null:
			dragon.position = loyalty_pos + Vector2(0, 18)
		if banner_building != null:
			banner_building.position = loyalty_pos
		for protected in [gong, banner_troop, dragon]:
			if protected != null:
				protected.max_hp = 1000.0; protected.hp = 1000.0
				protected._shield = 0.0; protected._dmg_amp = 0.0
				protected.clear_damage_reduction(); protected.clear_aura_atkspeed()
		if banner_building != null:
			banner_building.max_hp = 1000.0; banner_building.hp = 1000.0
		_ward_pass(0.11)
		gong.take_damage(100.0, null); banner_troop.take_damage(100.0, null)
		if dragon != null: dragon.take_damage(100.0, null)
		if banner_building != null: banner_building.take_damage(100.0, null)
		banner_reduce_ok = banner_reduce_ok \
				and absf((1000.0 - gong.hp) - 100.0 * (1.0 - float(hero_expect[bi]))) < 0.1 \
				and absf((1000.0 - banner_troop.hp) - 100.0 * (1.0 - float(troop_expect[bi]))) < 0.1 \
				and absf((1000.0 - dragon.hp) - 100.0 * (1.0 - float(troop_expect[bi]))) < 0.1 \
				and absf((1000.0 - banner_building.hp) - 100.0) < 0.1
		gong.hp = 500.0; banner_troop.hp = 500.0; foe.max_hp = 1000.0; foe.hp = 1000.0
		loyalty["pulse_t"] = 0.0
		_ward_pass(0.01)
		loyalty_ok = loyalty_ok and absf(gong.hp - (500.0 + float(heal_expect[bi]))) < 0.1 \
				and absf(banner_troop.hp - (500.0 + float(heal_expect[bi]))) < 0.1 \
				and absf(banner_troop._aura_atkspeed - 1.0) < 0.01 and absf(foe.hp - 1000.0) < 0.1
		# 义旗：同减伤 + 持续攻速；不回血，也不伤害敌军。
		_wards = [righteous]
		var righteous_pos: Vector2 = righteous["pos"]
		gong.position = righteous_pos + Vector2(18, 0)
		banner_troop.position = righteous_pos + Vector2(-18, 0)
		foe.position = righteous_pos + Vector2(0, 24)
		if dragon != null: dragon.position = righteous_pos + Vector2(0, 18)
		for protected in [gong, banner_troop, dragon]:
			if protected != null:
				protected.hp = 1000.0; protected.clear_damage_reduction(); protected.clear_aura_atkspeed()
		_ward_pass(0.11)
		gong.take_damage(100.0, null); banner_troop.take_damage(100.0, null)
		if dragon != null: dragon.take_damage(100.0, null)
		banner_reduce_ok = banner_reduce_ok \
				and absf((1000.0 - gong.hp) - 100.0 * (1.0 - float(hero_expect[bi]))) < 0.1 \
				and absf((1000.0 - banner_troop.hp) - 100.0 * (1.0 - float(troop_expect[bi]))) < 0.1 \
				and absf((1000.0 - dragon.hp) - 100.0 * (1.0 - float(troop_expect[bi]))) < 0.1
		gong.hp = 500.0; banner_troop.hp = 500.0; foe.hp = 1000.0
		_ward_pass(0.11)
		righteous_ok = righteous_ok and absf(gong.hp - 500.0) < 0.1 and absf(banner_troop.hp - 500.0) < 0.1 \
				and absf(gong._aura_atkspeed - float(atkspeed_expect[bi])) < 0.01 \
				and absf(banner_troop._aura_atkspeed - float(atkspeed_expect[bi])) < 0.01 \
				and absf(foe.hp - 1000.0) < 0.1

	# 0点后9.9秒仍无点，第10秒回1点，第20秒回满；下一次成功施放重新轮到忠旗。
	song._tick_ability_slots(9.9)
	banner_charge_ok = banner_charge_ok and song.slot_charges(1) == 0
	song._tick_ability_slots(0.11)
	banner_charge_ok = banner_charge_ok and song.slot_charges(1) == 1 and song.slot_ready(1)
	song._tick_ability_slots(10.0)
	banner_charge_ok = banner_charge_ok and song.slot_charges(1) == 2 and song.slot_recharge_left(1) <= 0.001
	_wards.clear()
	_do_ability(song, 1, song.position + Vector2(42, 0))
	banner_variant_ok = banner_variant_ok and not _wards.is_empty() and String(_wards[-1]["banner_kind"]) == "loyalty"
	# 抬手阶段被眩晕取消：不能扣能量，也不能提前切换下一面旗。
	song.ability_slots[1]["charges"] = 2
	song.ability_slots[1]["recharge_t"] = 0.0
	song.ability_slots[1]["cast_seq"] = 0
	_wards.clear()
	_begin_cast(song, 1, song.position + Vector2(42, 0))
	var interrupt_queued := is_cast_pending(song, 1)
	song.apply_stun(0.2)
	_tick_pending_casts()
	var interrupt_ok := interrupt_queued and not is_cast_pending(song, 1) and _wards.is_empty() \
			and song.slot_charges(1) == 2 and song.slot_cast_sequence(1) == 0
	banner_charge_ok = banner_charge_ok and interrupt_ok
	song._stun_t = 0.0
	song._cast_t = 0.0

	# 多来源减伤/攻速必须取最高；高阶来源到期后降档，义旗离场后恢复原有普通攻速 buff。
	var overlap_ok := true
	banner_troop.max_hp = 1000.0
	banner_troop.hp = 1000.0
	banner_troop.clear_damage_reduction()
	banner_troop.apply_damage_reduction(0.40, 1.0)
	banner_troop.apply_damage_reduction(0.20, 1.0)
	banner_troop.take_damage(100.0, null)
	overlap_ok = absf(banner_troop.hp - 940.0) < 0.1
	# 两面不同等级旗重叠：高阶来源到期后，必须降到仍在场的低阶旗，不能被低阶刷新成永久高减伤。
	banner_troop.clear_damage_reduction()
	banner_troop.hp = 1000.0
	banner_troop.apply_damage_reduction(0.90, 0.10, 9001)
	banner_troop.apply_damage_reduction(0.50, 1.00, 5001)
	banner_troop._physics_process(0.11)
	banner_troop.take_damage(100.0, null)
	var banner_downgrade_ok := absf(banner_troop.hp - 950.0) < 0.1
	banner_troop.clear_aura_atkspeed()
	banner_troop.temp_atkspeed = 1.6; banner_troop._temp_atkspeed_t = 8.0
	banner_troop.apply_aura_atkspeed(1.90, 0.10, 9001)
	banner_troop.apply_aura_atkspeed(1.50, 1.00, 5001)
	var aura_high_ok := absf(banner_troop._aura_atkspeed - 1.90) < 0.01
	banner_troop._physics_process(0.11)
	var aura_restore_ok := aura_high_ok and absf(banner_troop._aura_atkspeed - 1.50) < 0.01 \
			and absf(maxf(banner_troop.temp_atkspeed, banner_troop._aura_atkspeed) - 1.60) < 0.01
	banner_troop.temp_atkspeed = 1.0; banner_troop._temp_atkspeed_t = 0.0
	banner_troop.clear_aura_atkspeed()
	banner_troop.clear_damage_reduction()
	banner_troop.apply_damage_reduction(0.90, 0.22)
	banner_troop.position += Vector2(500, 0)
	banner_troop._physics_process(0.23)
	banner_troop.hp = 1000.0
	banner_troop.take_damage(100.0, null)
	banner_troop.apply_aura_atkspeed(1.90, 0.22, 9002)
	banner_troop._physics_process(0.23)
	var banner_exit_ok := absf(banner_troop.hp - 900.0) < 0.1 \
			and absf(banner_troop._aura_atkspeed - 1.0) < 0.01
	var summon_despawn_ok := dragon != null
	if dragon != null:
		dragon.hp = 100.0
		dragon.clear_damage_reduction()
		dragon.apply_damage_reduction(0.90, 1.0)
		despawn_summon(dragon)
		summon_despawn_ok = dragon.hp <= 0.0
	_wards.clear()
	if banner_building != null:
		banner_building.position = bb_pos
		banner_building.max_hp = bb_max
		banner_building.hp = bb_hp
	# 宋江 E 火攻 → 每秒20·rank2持续8s → 每跳基础 10，再乘英雄伤害倍率。
	song.ability_slots[2]["cd_t"] = 0.0
	var sf0 := _ground_dots.size()
	_do_ability(song, 2, foe.position)
	var song_fire_ok := _ground_dots.size() > sf0 \
			and absf(float(_ground_dots[-1]["per"]) - 10.0 * _hero_db(song)) < 0.6

	# hero_cap 是场景规则（驻守默认4，战役/竞技场为0=不限），单独打印但不影响技能链 ALL。
	var cap_ok := level.hero_cap() == 4
	var all_ok: bool = blackrain_ok and br_follow_ok and icewall_ok and slow_ok and dragon_ok and tigers_ok and drunk_ok and defdown_ok and blind_ok and miss_ok and immune_ok and absorbed_ok and heal_ok and wu_anim_ok and li_brawn_ok and li_guard_ok and song_hybrid_ok and song_rally_ok and banner_charge_ok and banner_variant_ok and banner_rank_ok and banner_reduce_ok and loyalty_ok and righteous_ok and overlap_ok and banner_downgrade_ok and aura_restore_ok and banner_exit_ok and summon_despawn_ok and song_fire_ok
	print("[newhero] blackrain=%s brfollow=%s icewall=%s slowaura=%s dragon=%s tigers=%s drunk=%s defdown=%s blind=%s miss=%s immune=%s absorbed=%s heal=%s wu_anim=%s li_brawn=%s li_guard=%s songhybrid=%s songrally=%s banner(charge=%s variant=%s rank=%s reduce=%s loyalty=%s righteous=%s overlap=%s downgrade=%s aura_restore=%s exit=%s despawn=%s) songfire=%s cap=%s ALL=%s" % [blackrain_ok, br_follow_ok, icewall_ok, slow_ok, dragon_ok, tigers_ok, drunk_ok, defdown_ok, blind_ok, miss_ok, immune_ok, absorbed_ok, heal_ok, wu_anim_ok, li_brawn_ok, li_guard_ok, song_hybrid_ok, song_rally_ok, banner_charge_ok, banner_variant_ok, banner_rank_ok, banner_reduce_ok, loyalty_ok, righteous_ok, overlap_ok, banner_downgrade_ok, aura_restore_ok, banner_exit_ok, summon_despawn_ok, song_fire_ok, cap_ok, all_ok])

	# 清理：移除召唤物与测试单位，避免污染后续
	for u in units.duplicate():
		if is_instance_valid(u) and (u.key == "dragon_summon" or u.key == "tiger_summon" or u == foe or u == gong or u == wus or u == lik or u == axe_near_a or u == axe_near_b or u == axe_far or u == song or u == banner_troop):
			u.take_damage(u.hp + 1.0, null, false, true)
	economy = _eco_was


## 待结算队列里某将是否排了某槽（托管自检用）。
func _pending_has(who: Unit, slot: int) -> bool:
	return is_cast_pending(who, slot)


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
## 不跑帧、不依赖 hud.touch_ui；关闭迷雾并清空空间网格，避免远置靶子和前序缓存污染纯战术断言。
func _automicro_selftest() -> void:
	var saved_fog := fog
	fog = false
	_grid.clear()   # 测试会直接搬动单位且不推帧；空网格让 units_near 正确回退全表扫描
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

	# ───── S7 托管加点优先级：宋江忠义双旗(W=1) / 花荣箭雨(W=1) / 林冲猎骑被动(E=2) 各自先点 ─────
	var learn_prio_ok := true
	for trip in [[song, 1], [hua, 1], [lin, 2]]:
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

	# ───── S8 宋江先在受压友军脚下插旗；W 无能量后仍会对远敌放 E 火攻。花荣箭雨照常。 ─────
	_wards.clear()
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
	var ally_park := park + Vector2(-1200, 0)
	for h in [lin, li, wu, hua, gong]:
		h.position = ally_park       # 与远置敌军分开，免得伪造出一处更密的“交战阵线”
	# 关卡原有的友军也先临时挪开，否则最密战团可能合理地盖过本用例构造的 troop，令断言不确定。
	var displaced_allies: Array = []
	for existing in units:
		if is_instance_valid(existing) and existing.faction == Unit.FACTION_LIANG and not existing.is_building \
				and existing != song and existing != troop and not (existing in heroes):
			displaced_allies.append([existing, existing.position])
			existing.position = ally_park
	song.position = origin
	troop.position = song.position + Vector2(200, 0)
	troop.hp = troop.max_hp
	emel.position = troop.position + Vector2(50, 0)
	_pending_casts.clear()
	_brain_song(song)
	var banner_lp := _pending_lp(song, 1)
	var song_banner_cast := _pending_has(song, 1) and banner_lp.distance_to(troop.position) < 40.0 \
			and banner_lp.distance_to(emel.position) > 35.0   # 必须插友军阵线，不能把保护旗塞到敌脚下
	song._cast_t = 0.0
	song.ability_slots[1]["charges"] = 0            # 旗阵能量耗尽 → 退而超视距放火攻(E)
	song.ability_slots[1]["recharge_t"] = 10.0
	_pending_casts.clear()
	_brain_song(song)
	var song_fire_cast := _pending_has(song, 2) and song_banner_cast
	song.ability_slots[1]["charges"] = 2
	song.ability_slots[1]["recharge_t"] = 0.0
	# 弱托管也应把 W 插在受压友军脚下；压住 Q/E/R，单测 banner 特判。
	song._cast_t = 0.0
	for si in [0, 2, 3]:
		song.ability_slots[si]["cd_t"] = 99.0
	_pending_casts.clear()
	_auto_micro_weak(song)
	var weak_banner_lp := _pending_lp(song, 1)
	var weak_banner_ok := _pending_has(song, 1) and weak_banner_lp.distance_to(troop.position) < 40.0 \
			and weak_banner_lp.distance_to(emel.position) > 35.0
	for si in [0, 2, 3]:
		song.ability_slots[si]["cd_t"] = 0.0
	# 减伤覆盖人数绝对优先：4友军+1敌的战团必须压过2友军+3敌，不能被敌军数或残血权重带偏。
	var density_spawned: Array = []
	var dense_center := origin + Vector2(0, 520)
	var sparse_center := origin + Vector2(620, 520)
	troop.position = dense_center
	for di in range(3):
		var dense_friend := spawn_unit("liang_dao", Unit.FACTION_LIANG,
				map.cell_to_world(map.nearest_open(map.world_to_cell(dense_center + Vector2(20 * (di + 1), 0)))))
		density_spawned.append(dense_friend)
	for si in range(2):
		var sparse_friend := spawn_unit("liang_dao", Unit.FACTION_LIANG,
				map.cell_to_world(map.nearest_open(map.world_to_cell(sparse_center + Vector2(22 * si, 0)))))
		density_spawned.append(sparse_friend)
	ecav.position = dense_center + Vector2(45, 35)
	emel.position = sparse_center + Vector2(35, 30)
	ehero.position = sparse_center + Vector2(55, -20)
	var sparse_foe := spawn_unit("guan_dao", Unit.FACTION_GUAN, sparse_center + Vector2(-35, 25))
	density_spawned.append(sparse_foe)
	var density_pick := _best_banner_pos(song.faction, 130.0, 190.0)
	var banner_density_ok := density_pick != Vector2.INF and density_pick.distance_to(dense_center) < 90.0
	# 第一面旗已经覆盖高密战团后，第二点不能再叠同一处；另一条受压线存在时应转去覆盖它。
	_wards.append({"mode": "banner", "ally": song.faction, "t": 5.0, "pos": dense_center, "r": 130.0})
	var spread_pick := _best_banner_pos(song.faction, 130.0, 190.0)
	var banner_spread_ok := spread_pick != Vector2.INF and spread_pick.distance_to(sparse_center) < 90.0
	# 只剩已被旗覆盖的战团时应保留第二点，等待本旗到期，而非立即把能量打空。
	emel.position = park
	ehero.position = park
	sparse_foe.position = park
	var hold_pick := _best_banner_pos(song.faction, 130.0, 190.0)
	# 走一次真实宋江托管脑：仍有1点时不能排入第二发，充能也必须继续保留。
	song.ability_slots[1]["charges"] = 1
	song.ability_slots[1]["recharge_t"] = 8.0
	song._cast_t = 0.0
	for locked_slot in [0, 2, 3]:
		song.ability_slots[locked_slot]["cd_t"] = 99.0
	_pending_casts.clear()
	_brain_song(song)
	var banner_hold_ok := hold_pick == Vector2.INF and not _pending_has(song, 1) \
			and song.slot_charges(1) == 1
	for locked_slot in [0, 2, 3]:
		song.ability_slots[locked_slot]["cd_t"] = 0.0
	song.ability_slots[1]["charges"] = 2
	song.ability_slots[1]["recharge_t"] = 0.0
	_wards.clear()
	for du in density_spawned:
		if is_instance_valid(du):
			du.take_damage(du.hp + 1.0, null)
	troop.position = song.position + Vector2(200, 0)
	# 场上无交战敌情时绝不空插旗。
	song._cast_t = 0.0
	for f in foes:
		f.position = park
	_pending_casts.clear()
	_brain_song(song)
	var banner_idle_ok := not _pending_has(song, 1)
	hua.position = origin
	hua._cast_t = 0.0
	# E 已是全图五连珠：把远置的骑兵/敌将临时藏起，单独验证“只有普通步兵时 W 仍会放”。
	ecav.garrisoned = true
	ehero.garrisoned = true
	emel.max_hp = 100.0   # 前序测试为防误杀把三敌都设成99999血；此处恢复普通步兵身份，不能被精英阈值选中
	emel.hp = 100.0
	emel.position = hua.position + Vector2(250, 0)
	_pending_casts.clear()
	_brain_hua(hua)
	var hua_rain_cast := _pending_has(hua, 1)
	var lr_cast_ok := song_fire_cast and hua_rain_cast
	for displaced in displaced_allies:
		var restored: Unit = displaced[0]
		if is_instance_valid(restored):
			restored.position = displaced[1]

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
	ecav.garrisoned = false
	ehero.garrisoned = false

	# ───── S8 集火优先：近处小兵 vs 略远敌将 → _focus_target 应挑敌将（敌将集火权重压过距离）─────
	for f in foes:
		f.position = park
	li.position = origin
	li._target = null
	emel.position = li.position + Vector2(60, 0)    # 近处杂兵(步兵)
	ehero.position = li.position + Vector2(210, 0)   # 略远敌将(呼延灼)
	var focus_pick := _focus_target(li, 320.0)
	var focus_ok := focus_pick == ehero             # 该集火敌将而非最近杂兵

	var all_ok := helpers_ok and tiger_gate_ok and weak_tiger_ok and wu_ult_ok and lin_focus_ok and hua_blink_ok and retreat_ok and ult_ok and song_mutex_ok and learn_prio_ok and lr_cast_ok and weak_banner_ok and banner_density_ok and banner_spread_ok and banner_hold_ok and banner_idle_ok and engage_ok and focus_ok
	print("[automicro] helpers=%s tigergate=%s weaktiger=%s wuult=%s linfocus=%s huablink=%s retreat=%s liult=%s songmutex=%s learnprio=%s banner(strong=%s weak=%s density=%s spread=%s hold=%s idle=%s) fire=%s hua=%s lr=%s engage(farW=%s)=%s focus=%s ALL=%s" % [
		helpers_ok, tiger_gate_ok, weak_tiger_ok, wu_ult_ok, lin_focus_ok, hua_blink_ok, retreat_ok, ult_ok, song_mutex_ok, learn_prio_ok, song_banner_cast, weak_banner_ok, banner_density_ok, banner_spread_ok, banner_hold_ok, banner_idle_ok, song_fire_cast, hua_rain_cast, lr_cast_ok, hua_far_w, engage_ok, focus_ok, all_ok])

	# 清理：移除本测试 spawn 的英雄/敌兵/召唤物，避免污染后续 skirmish
	for u in units.duplicate():
		if is_instance_valid(u) and (u in heroes or u in foes or u == troop or u.key == "tiger_summon" or u.key == "dragon_summon"):
			u.take_damage(u.hp + 1.0, null)
	fog = saved_fog
