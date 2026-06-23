class_name Unit
extends Node2D
## 单位：梁山好汉 / 官军。有图集贴图就用贴图，否则绘制占位图形。

enum { FACTION_LIANG = 0, FACTION_GUAN = 1 }
enum { ST_IDLE, ST_MOVE, ST_AMOVE, ST_CHASE, ST_GATHER, ST_RETURN, ST_BUILD, ST_REPAIR, ST_GARRISON }
enum { STANCE_AGGRO, STANCE_DEFEND, STANCE_HOLD, STANCE_PASSIVE }   # 进攻=追击/守备=守阵/据守=原地/避战=不索敌不还手
enum WK { SWORD, SPEAR, AXE, BOW }   # 武器类型 → 不同攻击动作

signal died(unit)

var key := ""
var display_name := ""
var faction := FACTION_LIANG
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var atk_cd := 1.0
var atk_range := 24.0
var base_speed := 70.0
var is_ranged := false
var can_melee_switch := false   # 花荣：可在弓/刀间切换
var melee_mode := false         # true=拔刀近战（射程缩短 + 额外吸血）
var is_cavalry := false
var bonus_vs_cav := 1.0
var defense := 0.0            # 防御值：每点 +5% 等效血量，仅减「普通攻击」伤害（技能伤害不受影响）
var is_hero := false
var is_building := false
var is_captive := false     # 被绑缚待救（第2关）
var is_objective := false   # 关卡目标物（如生辰纲宝车）
var is_noncombat := false   # 非战斗单位
var setup_def := {}         # 原始定义（关卡逻辑读标签用）
var aura := ""              # "atk" / "speed"
var aura_radius := 170.0
var aura_power := 1.0
var radius := 11.0
var aggro_range := 200.0

var battle = null           # Battle（不加类型注解避免循环引用）
var map: GameMap = null

# 经济（遭遇战）：工人采集 / 资源点
var is_worker := false       # 喽啰：可采集/建造
var is_resource := false     # 资源点（金矿/林木）
var res_kind := ""           # "gold" / "wood"
var res_left := 0.0          # 资源点剩余储量
var _gold_miner: Unit = null # 金矿专用：当前在矿口开采的农民（金矿一次只许一人进，木头不限）
var _queue: Array = []       # 行动队列（Shift 排队）
var _gather_node: Unit = null
var _drop: Unit = null
var _carry_kind := ""
var _carry_amt := 0.0
var _gather_t := 0.0
const GATHER_CAP := 10.0
const GATHER_PER_TICK := 10.0
const GATHER_TICK := 1.6
# 建造（建筑施工）
var is_constructing := false
var build_progress := 0.0
var build_time := 0.0
var _build_site: Unit = null

# 驻军（经典RTS式 garrison）：单位可进入箭楼/聚义厅躲避并增援（远程兵增加塔的箭量）
var garrisoned := false        # 已驻入某建筑（隐身、不可被选/被打、停止一切活动）
var garrison_holder: Unit = null  # 驻入的建筑
var _garrison_dest: Unit = null   # 正前往驻入的目标建筑
var passengers: Array = []     # 仅建筑：当前驻军单位列表
var garrison_cap := 0          # 仅建筑：驻军容量
# 生产（建筑训练队列）+ 集结点
var _train_queue: Array = []
var _train_t := 0.0
var rally := Vector2.ZERO
var has_rally := false
var rally_node: Unit = null   # 集结点设在资源上时记住该资源点（含种类），新工人自动去采该类资源
var rally_kind := ""          # "gold" / "wood"：集结资源点采空后据此就近补位
var _repair_g := 0.0
var _repair_w := 0.0
var _research_key := ""
var _research_t := 0.0

var selected := false
var is_active := false       # 编队里「活动单位」（命令面板/Tab 指向的那个）
var inspected := false       # 「查看中」的敌方单位（只读高亮：红圈，不可下令）
var passive := false        # 伏击/按兵不动：不主动索敌，待玩家下令或被攻击才出手
var stance := STANCE_AGGRO   # 作战姿态：进攻=追击索敌；守备=守阵地短追；据守=原地只打近敌
var _patrol_a := Vector2.ZERO  # 巡逻端点 A/B（攻击移动来回）
var _patrol_b := Vector2.ZERO
var _patrolling := false
var hidden_in_reeds := false
var buff_atk := 1.0
var buff_speed := 1.0
var face_left := false
var group_nums: Array = []  # 所属编队号（升序，可同属多队），显示在单位右下角

# 主动技能（兼容字段：ability = 第一个技能槽 id）
var ability := ""           # 技能 id，"" = 无
var ability_cd := 0.0       # 冷却时长（槽0）
var _ability_t := 0.0       # 当前剩余冷却（槽0，兼容用）
# 英雄技能槽（多技能 + 经典RTS式升级）：[{id, rank, cd_t, passive}]
var ability_slots: Array = []
var _hero_leveled := false  # 自由模式英雄：经验升级 + 技能点学习
var hero_level := 1
var hero_xp := 0.0
var skill_points := 0
var auto_micro := false      # 托管：自动放招 + 自动加点 + 走位/退守/索敌（per-unit 开关，PC/移动端通用）
var _ai_dest := Vector2.INF  # 托管移动去抖：上次下发的移动落点（同向不重发，免得每次决策都重算路径、朝向抖）
var _base_atk := 0.0
var _base_hp := 0.0
# 技能临时增益
var temp_atk := 1.0
var _temp_atk_t := 0.0
var temp_atk_add := 0.0     # 临时「平攻加成」（李逵暴走 +30 攻击；与 temp_atk 乘区分开，可叠加）
var _temp_atk_add_t := 0.0
var temp_speed := 1.0
var _temp_speed_t := 0.0
var _stun_t := 0.0          # 眩晕（踩地板控制）剩余时长：>0 时本帧不移动/不攻击/不索敌
var temp_lifesteal := 0.0
var _temp_lifesteal_t := 0.0
var cav_ls_chance := 0.0    # 林冲被动·猎骑：击中骑兵触发吸血的概率
var cav_ls_frac := 0.0      # 触发时按伤害多少比例吸血
var _buff_glow := 0.0       # 受增益时的金色辉光
# 召唤物：到期自动消散（>0 时倒计时，归零即消失）。is_summon 标记（不计人口、攻击表演）
var is_summon := false
var summon_kind := ""       # "tiger"/"dragon" → 驱动专属绘制
var _summon_ttl := 0.0      # >0 = 限时召唤物剩余存活；0 = 永久（虎）
# 三碗不过岗（武松 W）：移动/攻速在 [lo,hi] 间随机波动，按 _drunk_reroll 周期重掷
var _drunk_t := 0.0
var _drunk_lo := 1.0
var _drunk_hi := 1.0
var _drunk_reroll := 0.0
var _drunk_move := 1.0      # 当前随机移动倍率
var _drunk_atk := 1.0       # 当前随机攻速倍率
# 醉神大闹快活林（武松 R）：物理免疫 + 结束时把期间所受物理伤害的 50% 转化为回血
var _phys_immune_t := 0.0
var _absorbed_phys := 0.0   # 物免期间被普通攻击「挡下」的累计伤害
# 护甲削减（武松 E·双戒刀）：临时降低目标防御
var _def_down := 0.0
var _def_down_t := 0.0
# 致盲（武松 E·双戒刀附带）：>0 时本单位攻击必失（不结算伤害、不吸血）
var _blind_t := 0.0
# 减速光环（公孙胜 E）：每帧由 _aura_pass 写入；<1 = 受敌方减速光环影响。slow_aura_r>0 时自身画光环环
var aura_slow := 1.0
var slow_aura_r := 0.0
# 冲锋（李逵 W·矢量单击）：蓄力→猛冲，沿途撞伤。窗口期独立于普通状态机。
var _charge_t := 0.0        # 蓄力倒计时（>0 原地不动）
var _charge_dash := 0.0     # 冲刺剩余时长（>0 高速平移）
var _charge_dir := Vector2.ZERO
var _charge_dmg := 0.0
var _charge_slow := 0.0
var _charge_slow_dur := 0.0
var _charge_width := 50.0
var _charge_hit: Array = [] # 本次冲刺已撞过的单位（每人只撞一次）
const HERO_MAX_LEVEL := 12   # 满级 12 → 共 12 技能点（4 技能 ×3 级，可全点满）

var _state := ST_IDLE
var _path := PackedVector2Array()
var _path_i := 0
var _amove_dest := Vector2.ZERO
var _resume_amove := false
var _target: Unit = null
var _group_cap := 0.0       # 成队行军时的速度上限（取队伍最慢成员），>0 时生效，让一队人不散开
var _home := Vector2.ZERO   # 玩家单位的驻守点：追击后自动归位
var _has_home := false
var _cd := 0.0
var _repath := 0.0
var _flash := 0.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _combat_cool := 0.0  # 最近交战计时；梁山兵脱战后回血（主场休整）
var _hit_recent_t := 0.0 # 最近被敌方击中计时（托管磁滞：被打后扩大防区/搜索范围）
# 追击放弃：出攻击范围连续追同一目标却始终够不着(对方更快/在风筝) → 超时放手，改打就近威胁，
# 并在 _giveup_t 秒内不再重新锁定该目标(_giveup_id)，免得脑子立刻又把它锁回来一路追死。
var _chase_t := 0.0        # 当前目标「出范围追击」的累计时长（进入攻击范围即清零）
var _chase_last_id := 0    # 上一次 _do_chase 处理的目标 id（用于换目标时清零 _chase_t）
var _giveup_id := 0        # 刚放弃的目标 instance_id
var _giveup_t := 0.0       # 放弃冷却剩余：>0 时本单位拒绝再锁定 _giveup_id
const CHASE_GIVEUP := 2.2       # 出范围连续追击上限(秒)：超时仍够不着 → 放弃改打就近
const CHASE_GIVEUP_FAST := 1.1  # 目标比自己快(根本追不上) → 更早放弃
const GIVEUP_COOLDOWN := 2.5    # 放弃后多久内不再重锁同一目标

# 程序化动画：行走起伏/摇摆 + 攻击突刺 + 待机呼吸 + 死亡倒地 + 脚步扬尘
var _stepped := false      # 本物理帧是否实际位移
var _move_blend := 0.0     # 行走动画权重（平滑启停）
var _anim_t := 0.0         # 步频相位
var _lunge := 0.0          # 攻击挥击进度（1→0），驱动出招动作
var _lunge_dir := Vector2.RIGHT
var _swing_kind := WK.SWORD
var _swing_speed := 3.6    # 挥击速度（衰减率），随武器不同
var _hit_at := 0.5         # 挥击进度降到此值时结算伤害（命中瞬间）
var _pending_target: Unit = null
var _pending_done := true  # 本次挥击是否已结算
var _flinch := Vector2.ZERO # 受击退缩位移（逐帧衰减）
var _gather_anim_t := 0.0   # 采集挥击节拍：每隔一拍做一次「砍/凿」动作（纯表演不结算）
var _harvest_pulse := 0.0   # 资源点被采时的摇晃强度（被工人凿一下→置 1，逐帧衰减）
var _cast_t := 0.0          # 施法抬手·蓄势倒计时（>0 时播放抬手姿+蓄能辉光）
var _cast_dur := 0.001      # 本次抬手总时长（归一化抬手进度用）
var _cast_color := Color(0.82, 0.86, 1.0)  # 蓄能辉光色（取自技能色）
var _weapon := -1          # 缓存武器类型
var _idle_t := 0.0         # 待机呼吸相位（恒进）
var _real_frames := false  # 当前状态是否在播放真·逐帧（用于压低程序化叠加）
var _dying := false        # 死亡动画进行中（已脱离战斗，待倒地淡出后释放）
var _death_t := 0.0
var _death_lean := 1.0     # 倒地方向（屏幕左右）
var _dust: Array = []      # 脚步扬尘 [{x,y,t}]
const MOVE_SCALE := 0.66      # 全局移动速度系数：放慢行军节奏（不影响任何「走时」/冷却，那些走真实秒）
const DEATH_DUR := 1.4   # 死亡动画时长（秒）：放慢倒地，看清逐帧（原 0.7 太快）
const DUST_DUR := 0.36


func setup(p_key: String, def: Dictionary, p_faction: int, p_battle, p_map: GameMap) -> void:
	key = p_key
	display_name = def.get("name", p_key)
	faction = p_faction
	max_hp = float(def.get("hp", 100))
	hp = max_hp
	atk = float(def.get("atk", 10))
	atk_cd = float(def.get("cd", 1.0))
	atk_range = float(def.get("range", 24))
	base_speed = float(def.get("speed", 70))
	is_ranged = bool(def.get("ranged", false))
	can_melee_switch = bool(def.get("melee_switch", false))
	is_cavalry = bool(def.get("cavalry", false))
	bonus_vs_cav = float(def.get("bonus_cav", 1.0))
	defense = Defs.armor_for(key, def)   # 护甲：def 显式 > ARMOR 表 > 角色兜底；仅减普通攻击，技能不吃
	is_hero = bool(def.get("hero", false))
	is_building = bool(def.get("building", false))
	is_captive = bool(def.get("captive", false))
	is_objective = bool(def.get("objective", false))
	is_noncombat = bool(def.get("noncombat", false))
	is_worker = bool(def.get("worker", false))
	if is_worker:
		base_speed *= 1.1   # 工人移速 +10%：采集来回更跟脚
	is_resource = def.has("res_kind")
	res_kind = String(def.get("res_kind", ""))
	res_left = float(def.get("res_amount", 0))
	garrison_cap = int(def.get("garrison_cap", 0))
	setup_def = def
	aura = String(def.get("aura", ""))
	aura_radius = float(def.get("aura_r", 170))
	aura_power = float(def.get("aura_p", 1.0))
	ability = String(def.get("ability", ""))
	radius = float(def.get("radius", 13.0 if is_hero else 11.0))
	build_time = float(def.get("build_time", 0))
	# 防御塔=带攻击的建筑：也要索敌；资源点/纯建筑不索敌
	aggro_range = maxf(200.0, atk_range + 50.0) if (not is_building or atk > 0.0) else 0.0
	battle = p_battle
	map = p_map
	_base_atk = atk
	_base_hp = max_hp
	if is_hero:
		_init_ability_slots(def)


func has_target() -> bool:
	return _target != null


## 该目标当前是否被本单位「放弃冷却」拉黑（刚追不上放手，短时间内别再锁它）。
func chase_blocked(v: Unit) -> bool:
	return v != null and _giveup_t > 0.0 and v.get_instance_id() == _giveup_id


func is_idle_worker() -> bool:
	return is_worker and not garrisoned and _state == ST_IDLE and _queue.is_empty() and _target == null


func set_selected(v: bool) -> void:
	if selected != v:
		selected = v
		if not v:
			is_active = false
		queue_redraw()


## 查看高亮：被「查看」的敌方单位画红圈（区别于己方绿圈），只读不可下令。
func set_inspected(v: bool) -> void:
	if inspected != v:
		inspected = v
		queue_redraw()


## 活动单位高亮：Tab/命令面板当前指向的那个（编队里多于一个时才标，便于「确定是哪个」）
func set_active(v: bool) -> void:
	if is_active != v:
		is_active = v
		queue_redraw()


## 公开指令入口：Shift 排队（queued=true 追加队列，否则清空队列立即执行）。
func order_move(pos: Vector2, queued := false) -> void:
	_enqueue({"kind": "move", "pos": pos}, queued)


func order_attack(t: Unit, queued := false) -> void:
	if t == null:
		return
	_enqueue({"kind": "attack", "target": t}, queued)


func order_amove(pos: Vector2, queued := false) -> void:
	_enqueue({"kind": "amove", "pos": pos}, queued)


func order_gather(node: Unit, queued := false) -> void:
	if node == null:
		return
	_enqueue({"kind": "gather", "target": node}, queued)


## 停止/原地待命：清空指令、放弃目标、就地驻守（用于 S 键）
func order_stop() -> void:
	if is_building:
		return
	_queue.clear()
	_patrolling = false
	_target = null
	_resume_amove = false
	_group_cap = 0.0
	_home = position
	_has_home = true
	_path = PackedVector2Array()
	_state = ST_IDLE


## 巡逻：在当前位置与 pos 之间用「攻击移动」来回，沿途交战（用于 P 键）
func order_patrol(pos: Vector2) -> void:
	if is_building or is_worker:
		return
	_queue.clear()
	passive = false
	_patrol_a = position
	_patrol_b = pos
	_home = position
	_has_home = true
	_patrolling = true
	_begin_amove(pos)


func set_stance(s: int) -> void:
	if is_building or is_worker:
		return
	stance = s
	# 切到守备/据守时把当前位置定为阵地锚点，便于短追后归位
	if s != STANCE_AGGRO:
		_home = position
		_has_home = true


func order_build(site: Unit, queued := false) -> void:
	if site == null:
		return
	_enqueue({"kind": "build", "target": site}, queued)


func order_repair(bld: Unit, queued := false) -> void:
	if bld == null:
		return
	_enqueue({"kind": "repair", "target": bld}, queued)


func order_garrison(bld: Unit, queued := false) -> void:
	if bld == null:
		return
	_enqueue({"kind": "garrison", "target": bld}, queued)


func _enqueue(o: Dictionary, queued: bool) -> void:
	if is_building:
		return
	passive = false
	_patrolling = false   # 任何新明确指令都终止巡逻
	if not queued:
		_queue.clear()
		_begin_order(o)
	else:
		_queue.append(o)
		if _state == ST_IDLE and _target == null:
			_done_order()


## 取队首指令执行；队列空则回待机（队列空时等价于原 _state = ST_IDLE，战役行为不变）
func _done_order() -> void:
	# 巡逻：到达一端 → 攻击移动折返另一端（沿途自动交战）。去离当前更远的那个端点。
	if _patrolling and _queue.is_empty():
		var far := _patrol_b if position.distance_to(_patrol_b) >= position.distance_to(_patrol_a) else _patrol_a
		_begin_amove(far)   # _begin_amove 不改 _patrolling，循环保持
		return
	if _queue.is_empty():
		_state = ST_IDLE
		return
	_begin_order(_queue.pop_front())


## 工人完成建造/修理后收尾：有排队指令先执行；否则若之前在采集就自动回去采（经典RTS式自动复工，
## 省去反复手动把建完的工人拉回资源点）。本来就闲着来建的工人则保持待命。
func _finish_worker_task() -> void:
	if not _queue.is_empty():
		_begin_order(_queue.pop_front())
		return
	if is_worker and battle != null:
		if _gather_node != null and is_instance_valid(_gather_node) and _gather_node.res_left > 0.0:
			_begin_gather(_gather_node)
			return
		# 之前在采某类资源就近找同类续采；否则就近找任意资源——建完/修完别杵在仓库边发呆
		# （修「建了仓库后一群农民跑到仓库旁不干活」：来建造的工人收工即自动复工）。
		var n: Unit = null
		if _carry_kind != "":
			n = battle.nearest_resource(position, _carry_kind)
		if n == null:
			n = battle.nearest_resource(position, "")
		if n != null:
			_begin_gather(n)
			return
	_state = ST_IDLE


func _begin_order(o: Dictionary) -> void:
	match String(o.get("kind", "")):
		"move": _begin_move(o["pos"])
		"amove": _begin_amove(o["pos"])
		"attack": _begin_attack(o["target"])
		"gather": _begin_gather(o["target"])
		"build": _begin_build(o["target"])
		"repair": _begin_repair(o["target"])
		"garrison": _begin_garrison(o["target"])


# —— 原始指令（不动队列；供内部重发/回防/续采复用）——
func _begin_move(pos: Vector2) -> void:
	if is_building:
		return
	_target = null
	_resume_amove = false
	_group_cap = 0.0   # 每次新移动默认解除队伍限速；成队移动时由 _apply_group_cap 在下令后重设
	_home = pos
	_has_home = true
	_path = map.find_path(position, pos)
	_path_i = 0
	_state = ST_MOVE


func _begin_attack(t: Unit) -> void:
	if is_building or t == null:
		return
	_target = t
	_resume_amove = false
	_repath = 0.0
	_state = ST_CHASE


func _begin_amove(pos: Vector2) -> void:
	if is_building:
		return
	_target = null
	_amove_dest = pos
	_resume_amove = false
	_group_cap = 0.0   # 同 _begin_move：默认解除限速，成队由 _apply_group_cap 重设
	_path = map.find_path(position, pos)
	_path_i = 0
	_state = ST_AMOVE


func _begin_gather(node: Unit) -> void:
	if node == null or not is_instance_valid(node):
		_done_order()
		return
	_target = null
	_resume_amove = false
	_group_cap = 0.0   # 采集独立行动，解除队伍限速（与 _begin_move 一致）
	_gather_node = node
	_carry_kind = node.res_kind   # 出发即记住资源种类（节点被别人采空时据此就近补同类，而非乱采）
	if _carry_amt >= GATHER_CAP:
		_begin_return()
	else:
		_repath = 0.0
		_path = map.find_path(position, node.position)
		_path_i = 0
		_state = ST_GATHER


func _begin_return() -> void:
	_drop = battle.nearest_dropoff(position, faction)   # 卸到自己阵营的卸货点
	if _drop == null:
		_done_order()   # 无卸货点（聚义厅/仓库都没了）：收工待命，避免空转
		return
	_repath = 0.0
	_path = map.find_path(position, _drop.position)
	_path_i = 0
	_state = ST_RETURN


func _begin_build(site: Unit) -> void:
	if site == null or not is_instance_valid(site):
		_done_order()
		return
	_target = null
	_resume_amove = false
	_group_cap = 0.0
	_build_site = site
	_repath = 0.0
	_path = map.find_path(position, site.position)
	_path_i = 0
	_state = ST_BUILD


func _begin_repair(bld: Unit) -> void:
	if bld == null or not is_instance_valid(bld) or bld.hp >= bld.max_hp:
		_done_order()
		return
	_target = null
	_resume_amove = false
	_group_cap = 0.0
	_build_site = bld
	_repair_g = 0.0
	_repair_w = 0.0
	_repath = 0.0
	_path = map.find_path(position, bld.position)
	_path_i = 0
	_state = ST_REPAIR


func _begin_garrison(bld: Unit) -> void:
	if bld == null or not is_instance_valid(bld) or is_building \
			or bld.garrison_cap <= 0 or bld.faction != faction or bld.is_constructing \
			or bld.passengers.size() >= bld.garrison_cap:
		_done_order()
		return
	_target = null
	_resume_amove = false
	_garrison_dest = bld
	_repath = 0.0
	_path = map.find_path(position, bld.position)
	_path_i = 0
	_state = ST_GARRISON


## ST_GARRISON：走到目标建筑，进入触及半径即驻入
func _do_garrison(delta: float) -> void:
	var bld := _garrison_dest
	if bld == null or not is_instance_valid(bld) or bld.hp <= 0.0 \
			or bld.passengers.size() >= bld.garrison_cap:
		_garrison_dest = null
		_done_order()
		return
	var fhalf := int(bld.get_meta("fhalf", 1))
	var reach := float((fhalf + 1) * GameMap.CELL) + radius + 10.0
	if position.distance_to(bld.position) <= reach:
		_enter_garrison(bld)
	else:
		_repath -= delta
		if _repath <= 0.0 or _path_i >= _path.size():
			_repath = 0.5
			_path = map.find_path(position, bld.position)
			_path_i = 0
		_follow_path(delta)


## 驻入：藏身、停活动、计入建筑 passengers
func _enter_garrison(bld: Unit) -> void:
	# 容量二次确认：两个单位同帧抵达时，避免双双挤入超过上限
	if bld.passengers.size() >= bld.garrison_cap or bld.passengers.has(self):
		_garrison_dest = null
		_done_order()
		return
	garrisoned = true
	garrison_holder = bld
	_garrison_dest = null
	_target = null
	_queue.clear()
	bld.passengers.append(self)
	visible = false
	selected = false
	is_active = false
	_state = ST_IDLE
	position = bld.position
	if battle != null:
		battle.on_garrison_changed(bld)


## 驻出：从建筑弹出到附近空地，恢复活动
func leave_garrison() -> void:
	var bld := garrison_holder
	garrisoned = false
	garrison_holder = null
	visible = true
	if bld != null and is_instance_valid(bld):
		bld.passengers.erase(self)
		var cell := map.nearest_open(map.world_to_cell(bld.position) + Vector2i(randi_range(-2, 2), int(bld.get_meta("fhalf", 1)) + 1))
		position = map.cell_to_world(cell)
		if battle != null:
			battle.on_garrison_changed(bld)
	_state = ST_IDLE


var _killer: Unit = null   # 最后一击的攻击者（战后按英雄统计歼敌）

## 最近是否被敌方击中（托管磁滞：被打后扩大防区/搜索范围）。
func recently_hit() -> bool:
	return _hit_recent_t > 0.0


func take_damage(d: float, from: Unit = null, crit := false) -> void:
	if hp <= 0.0:
		return
	if garrisoned:
		return   # 驻军中：藏在建筑里受庇护，免疫伤害（飞行中的箭/范围技能也打不到；建筑被毁才弹出）
	hp -= d
	_flash = 0.30 if crit else 0.18
	_combat_cool = 6.0
	if from != null and is_instance_valid(from) and from.faction != faction:
		_hit_recent_t = 3.0   # 被敌方命中：3 秒内算「最近挨打」（托管磁滞用）

	# 飘字伤害（建筑也显示，资源点不显示）；暴击放大变色 + 轻屏震
	if battle != null and not is_resource:
		battle.spawn_damage(position, d, crit, faction == FACTION_LIANG)
		if crit:
			battle.shake(3.0, position)
	# 己方建筑遭袭 → 告警（小地图闪烁 + 音效，主控内部节流）。
	# 资源点(金矿/林木 building+is_resource)排除：它们挂 LIANG 是中立可争夺，被技能扫到不算「寨子遭袭」。
	if is_building and not is_resource and faction == FACTION_LIANG and from != null and is_instance_valid(from) \
			and from.faction != faction and battle != null:
		battle.alert(position)
	# 受击退缩：朝受击反方向一顿（屏幕空间）
	if from != null and is_instance_valid(from):
		var fd := _screen_dir(position - from.position)
		_flinch = fd * 4.0
	queue_redraw()
	# 被打就还手（仅限当前没有目标的战斗单位）
	if not is_building and from != null and is_instance_valid(from) \
			and from.hp > 0.0 and from.faction != faction:
		passive = false
	# 只有「待命」或「攻击移动」时才自动还手；正在执行移动/采集/建造/返还/修理等
	# 明确命令时，挨一下不回头（移动指令覆盖自动攻击）。
	if not is_building and stance != STANCE_PASSIVE and _target == null and from != null and is_instance_valid(from) \
			and from.hp > 0.0 and from.faction != faction \
			and (_state == ST_IDLE or _state == ST_AMOVE):
		if _state == ST_AMOVE:
			_resume_amove = true
		_target = from
		_repath = 0.0
		_state = ST_CHASE
	if hp <= 0.0:
		hp = 0.0
		_killer = from if (from != null and is_instance_valid(from)) else null
		# 英雄/建筑倒下时给一记屏震，强调份量
		if battle != null and (is_hero or is_building):
			battle.shake(5.0 if is_building else 4.0, position)
		died.emit(self)  # 通知主控（移出 units、计数、血渍标记）
		if is_building:
			# 建筑被摧毁前，把驻军全部弹出（不随建筑陪葬）
			if not passengers.is_empty():
				for pg in passengers.duplicate():
					if is_instance_valid(pg):
						pg.leave_garrison()
				passengers.clear()
			# 建筑不释放节点：留作废墟，主控逻辑还要读它的状态
			modulate = Color(0.45, 0.4, 0.38)
			queue_redraw()
		else:
			# 进入死亡动画：朝受击反方向倒地、淡出后再释放
			Sfx.play("death", -6.0, 0.12, 110)
			_dying = true
			_death_t = 0.0
			selected = false
			var ddir := Vector2.RIGHT
			if from != null and is_instance_valid(from):
				ddir = position - from.position
			_death_lean = 1.0 if (ddir.x - ddir.y) >= 0.0 else -1.0
			queue_redraw()


func _physics_process(delta: float) -> void:
	if is_building:
		if hp <= 0.0:
			return   # 已被摧毁的建筑（废墟）：停止一切活动——箭楼不再射箭、兵营不再生产/研究
		if not passengers.is_empty():
			for pg in passengers:   # 驻军缓慢回血（经典RTS式）
				if is_instance_valid(pg) and pg.hp > 0.0 and pg.hp < pg.max_hp:
					pg.hp = minf(pg.max_hp, pg.hp + 9.0 * delta)
		if atk > 0.0 and not is_resource and not is_constructing:
			_tower_tick(delta)   # 防御塔（箭楼）固定索敌射击
		if not is_constructing and not _train_queue.is_empty():
			_production_tick(delta)
		if not is_constructing and _research_key != "":
			_research_t -= delta
			if _research_t <= 0.0:
				var rk := _research_key
				_research_key = ""
				if battle != null:
					battle.on_research_done(self, rk)
		# 建筑/资源点动画时钟：炊烟·资源被采摇晃（建筑物理在此 return，不走下面的 _idle_t）
		if is_resource or _has_smoke():
			_idle_t += delta
			if _harvest_pulse > 0.0:
				_harvest_pulse = maxf(0.0, _harvest_pulse - delta * 2.0)
			queue_redraw()
		return
	if _dying:
		_death_t += delta
		queue_redraw()
		if _death_t >= DEATH_DUR:
			queue_free()
		return
	if garrisoned:
		return   # 驻军中：藏在建筑里，停止一切活动（移动/索敌/动画）
	_cd = maxf(0.0, _cd - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()

	# 梁山兵熟悉水泊、补给充足，脱战 6 秒后缓慢回血；官军远征无此待遇
	_combat_cool = maxf(0.0, _combat_cool - delta)
	_hit_recent_t = maxf(0.0, _hit_recent_t - delta)
	var regen := 0.0
	if faction == FACTION_LIANG and _combat_cool <= 0.0:
		regen += 2.5
	regen += _passive_regen()    # 被动回血（如宋江·仁义）：战斗中也生效
	if regen > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + regen * delta)
		queue_redraw()

	# 技能冷却（各槽）与临时增益计时
	for s in ability_slots:
		if float(s["cd_t"]) > 0.0:
			s["cd_t"] = maxf(0.0, float(s["cd_t"]) - delta)
	if _temp_atk_t > 0.0:
		_temp_atk_t -= delta
		if _temp_atk_t <= 0.0:
			temp_atk = 1.0
	if _temp_atk_add_t > 0.0:
		_temp_atk_add_t -= delta
		if _temp_atk_add_t <= 0.0:
			temp_atk_add = 0.0
	if _temp_speed_t > 0.0:
		_temp_speed_t -= delta
		if _temp_speed_t <= 0.0:
			temp_speed = 1.0
	if _temp_lifesteal_t > 0.0:
		_temp_lifesteal_t -= delta
		if _temp_lifesteal_t <= 0.0:
			temp_lifesteal = 0.0
	# 三碗不过岗：醉酒期间周期性重掷移动/攻速倍率（醉态飘忽）
	if _drunk_t > 0.0:
		_drunk_t -= delta
		_drunk_reroll -= delta
		if _drunk_reroll <= 0.0:
			_drunk_reroll = 1.4
			_drunk_move = randf_range(_drunk_lo, _drunk_hi)
			_drunk_atk = randf_range(_drunk_lo, _drunk_hi)
			_buff_glow = maxf(_buff_glow, 0.5)
		if _drunk_t <= 0.0:
			_drunk_move = 1.0
			_drunk_atk = 1.0
	# 醉神：物免倒计时；结束瞬间把期间挡下物理伤害的 50% 转化为回血
	if _phys_immune_t > 0.0:
		_phys_immune_t -= delta
		if _phys_immune_t <= 0.0:
			if _absorbed_phys > 0.0:
				heal(_absorbed_phys * 0.5)
				_buff_glow = 1.0
			_absorbed_phys = 0.0
	# 护甲削减计时
	if _def_down_t > 0.0:
		_def_down_t -= delta
		if _def_down_t <= 0.0:
			_def_down = 0.0
	# 致盲计时（武松 E）：期间攻击必失
	if _blind_t > 0.0:
		_blind_t -= delta
	# 限时召唤物：寿命到 → 消散
	if _summon_ttl > 0.0:
		_summon_ttl -= delta
		if _summon_ttl <= 0.0 and not _dying and hp > 0.0:
			_summon_ttl = 0.0
			if battle != null and battle.has_method("despawn_summon"):
				battle.despawn_summon(self)
	if _buff_glow > 0.0:
		_buff_glow = maxf(0.0, _buff_glow - delta)
		queue_redraw()
	if _giveup_t > 0.0:
		_giveup_t = maxf(0.0, _giveup_t - delta)   # 追击放弃冷却：到点后可重新锁定旧目标

	if _target != null and (not is_instance_valid(_target) or _target.hp <= 0.0 or _target.garrisoned):
		_target = null   # 目标若已驻入建筑（隐身无敌）→ 放弃追击

	# 冲锋窗口（李逵 W）：优先于普通状态机。蓄力期原地，冲刺期高速平移撞伤。
	if _charge_t > 0.0 or _charge_dash > 0.0:
		_do_charge_step(delta)
		return

	if _stun_t > 0.0:
		_stun_t = maxf(0.0, _stun_t - delta)   # 眩晕（踩地板）：呆立，本帧不索敌/不移动/不攻击
	else:
		match _state:
			ST_IDLE:
				if not passive and not is_worker:   # 工人不主动索敌（经典RTS式村民）
					_acquire()
				if _target != null:
					if not _has_home:
						_home = position
						_has_home = true
					_repath = 0.0
					_state = ST_CHASE
			ST_MOVE:
				if _follow_path(delta):
					_done_order()
			ST_AMOVE:
				if _target == null:
					# A 移动时收紧索敌半径：近战只打 ~130px 内、远程保留射程，倾向继续奔向目的地
					_acquire(maxf(atk_range + 24.0, 130.0))
				if _target != null:
					_resume_amove = true
					_repath = 0.0
					_state = ST_CHASE
				elif _follow_path(delta):
					# 路径走完但离目的地还远（被挤出路线导致截断）→ 重新寻路
					if position.distance_to(_amove_dest) > 70.0:
						_begin_amove(_amove_dest)
					else:
						_done_order()
			ST_CHASE:
				_do_chase(delta)
			ST_GATHER:
				_do_gather(delta)
			ST_RETURN:
				_do_return(delta)
			ST_BUILD:
				_do_build(delta)
			ST_REPAIR:
				_do_repair(delta)
			ST_GARRISON:
				_do_garrison(delta)

	# 动画状态推进：步频随移速，骑兵更快；停下时平滑收势
	_move_blend = move_toward(_move_blend, 1.0 if _stepped else 0.0, delta * 6.0)
	_stepped = false
	_idle_t += delta
	if _move_blend > 0.01:
		var prev := _anim_t
		# 步频与「实际移速」(含 MOVE_SCALE 减速) 挂钩：腿不再比身体快、不再刨地（原来没乘 MOVE_SCALE→偏快）
		_anim_t += delta * (13.0 if is_cavalry else 9.5) * MOVE_SCALE * (base_speed / 72.0)
		# 每半个步频相位 = 一次落脚 → 扬尘
		if floori(_anim_t / PI) != floori(prev / PI):
			_spawn_dust()
		queue_redraw()
	if not _dust.is_empty():
		for d in _dust:
			d.t -= delta
		_dust = _dust.filter(func(d): return d.t > 0.0)
		queue_redraw()
	if _lunge > 0.0:
		var prev_l := _lunge
		_lunge = maxf(0.0, _lunge - delta * _swing_speed)
		if not _pending_done and prev_l > _hit_at and _lunge <= _hit_at:
			_deal_hit()
		queue_redraw()
	if _flinch != Vector2.ZERO:
		_flinch = _flinch.move_toward(Vector2.ZERO, delta * 90.0)
		queue_redraw()
	if _cast_t > 0.0:                      # 施法抬手：蓄势倒计时（结算由 battle 在归零时触发）
		_cast_t = maxf(0.0, _cast_t - delta)
		queue_redraw()

	# 卡死看门狗：移动状态下长时间原地不动 → 强制重新寻路/跳过路点
	if _state != ST_IDLE:
		if position.distance_to(_last_pos) < 2.0:
			_stuck_t += delta
			if _stuck_t > 1.5:
				_stuck_t = 0.0
				match _state:
					ST_AMOVE:
						_begin_amove(_amove_dest)
					ST_MOVE:
						_path_i = mini(_path_i + 1, _path.size())
					ST_CHASE, ST_GATHER, ST_RETURN:
						_repath = 0.0
		else:
			_stuck_t = 0.0
		_last_pos = position


func _do_chase(delta: float) -> void:
	if _target != null and _target.get_instance_id() != _chase_last_id:
		_chase_last_id = _target.get_instance_id()   # 换了目标 → 追击计时重置
		_chase_t = 0.0
	if _target == null:
		_chase_t = 0.0
		# 目标没了：官军继续压向聚义厅，梁山兵回驻守点
		if _resume_amove:
			_begin_amove(_amove_dest)
		elif _has_home and position.distance_to(_home) > 30.0:
			var h := _home
			_begin_move(h)
			_home = h
		elif is_worker and _gather_node != null and is_instance_valid(_gather_node) and _gather_node.res_left > 0.0:
			_begin_gather(_gather_node)   # 工人反击退敌后续采
		else:
			_done_order()
		return
	# 牵引距离：进攻=320 远追；守备=150 短追；据守=只在攻击范围内（绝不挪）
	var leash := 320.0
	if stance == STANCE_DEFEND:
		leash = 150.0
	elif stance == STANCE_HOLD:
		leash = atk_range + radius + 18.0
	# 玩家单位（或任何非进攻姿态单位）追击过远则脱离、回防，防止被引离阵地
	# 例外：托管(auto_micro)且进攻姿态的英雄不受牵引——主动压上交战、退守交给托管大脑
	if _has_home and not (auto_micro and stance == STANCE_AGGRO) \
			and (faction == FACTION_LIANG or stance != STANCE_AGGRO) \
			and position.distance_to(_home) > leash:
		_target = null
		var h2 := _home
		_begin_move(h2)
		_home = h2
		return
	var d := position.distance_to(_target.position)
	var reach := atk_range + radius + _target.radius
	if d <= reach:
		_chase_t = 0.0   # 已进攻击范围（咬住了）：追击计时清零
		_face_dir(_target.position - position)
		if _cd <= 0.0:
			_attack()
	elif stance == STANCE_HOLD:
		# 据守：目标跑出攻击范围就放手，原地不动，不追
		_target = null
		_done_order()
	else:
		# 追不上判定：连续追同一目标却始终够不着 → 超时放手（对方更快则更早放弃），
		# 拉黑该目标 GIVEUP_COOLDOWN 秒并就近重新索敌，免得一路追死/被旁敌砍死。
		_chase_t += delta
		var cap: float = CHASE_GIVEUP_FAST if _target.base_speed > base_speed + 1.0 else CHASE_GIVEUP
		if _chase_t >= cap:
			_giveup_id = _target.get_instance_id()
			_giveup_t = GIVEUP_COOLDOWN
			_target = null
			_chase_t = 0.0
			if not passive and not is_worker and stance != STANCE_PASSIVE:
				_acquire()   # 立刻改打就近威胁（_acquire 会跳过刚拉黑的目标）
			if _target == null:
				_done_order()
			return
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.4
			_path = map.find_path(position, _target.position)
			_path_i = 0
		_follow_path(delta)


## 采集：走到资源点→采满或采空→回卸货点（ST_RETURN）
## 这座金矿此刻是否正被「别的」农民占用（在矿口实地开采）。自校验：占用者一旦离开矿口
## （转返还/移动/阵亡/改采别处）即自动判定为空——无需在各处显式释放，杜绝占位泄漏。
func gold_busy(w: Unit) -> bool:
	var m := _gold_miner
	return m != null and m != w and is_instance_valid(m) and m.hp > 0.0 \
		and m._gather_node == self and m._state == ST_GATHER \
		and m.position.distance_to(position) <= radius + m.radius + 14.0


func _do_gather(delta: float) -> void:
	if _gather_node == null or not is_instance_valid(_gather_node) or _gather_node.res_left <= 0.0:
		var n: Unit = battle.nearest_resource(position, _carry_kind)
		if n != null:
			_gather_node = n
			_repath = 0.0
			_path = map.find_path(position, n.position)
			_path_i = 0
		elif _carry_amt > 0.0:
			_begin_return()
		else:
			_done_order()
		return
	var reach := _gather_node.radius + radius + 6.0
	if position.distance_to(_gather_node.position) <= reach:
		# 金矿独占：矿口已有人开采 → 先就近改采别的空金矿，没有就在矿口排队等候（不计 tick）
		if _gather_node.res_kind == "gold" and _gather_node.gold_busy(self):
			var other: Unit = battle.nearest_free_gold(position, _gather_node, self)
			if other != null and other != _gather_node:
				_gather_node = other
				_repath = 0.0
				_path = map.find_path(position, other.position)
				_path_i = 0
			else:
				_face_dir(_gather_node.position - position)   # 排队：面向矿口待命
			return
		if _gather_node.res_kind == "gold":
			_gather_node._gold_miner = self   # 占住矿口（独占开采）
		_carry_kind = _gather_node.res_kind
		_face_dir(_gather_node.position - position)
		_gather_anim_t += delta               # 采集挥击：每 ~0.7s 砍/凿一下（借攻击帧，纯表演）
		if _gather_anim_t >= 0.7 and _lunge <= 0.0:
			_gather_anim_t = 0.0
			_begin_cosmetic_swing(_gather_node.position - position)
		_gather_t += delta
		if _gather_t >= GATHER_TICK:
			_gather_t = 0.0
			var amt: float = minf(GATHER_PER_TICK, minf(GATHER_CAP - _carry_amt, _gather_node.res_left))
			_carry_amt += amt
			_gather_node.res_left -= amt
			if _carry_amt >= GATHER_CAP or _gather_node.res_left <= 0.0:
				if _gather_node.res_left <= 0.0:
					battle.deplete_resource(_gather_node)
					_gather_node = null
				_begin_return()
	elif is_instance_valid(_gather_node):
		_repath -= delta
		if _repath <= 0.0 or _path_i >= _path.size():
			_repath = 0.5
			_path = map.find_path(position, _gather_node.position)
			_path_i = 0
		_follow_path(delta)


## 卸货：回最近卸货点入库→回资源点续采（自动循环）
func _do_return(delta: float) -> void:
	if _drop == null or not is_instance_valid(_drop) or _drop.hp <= 0.0:
		_drop = battle.nearest_dropoff(position, faction)
		if _drop == null:
			_done_order()
			return
		_repath = 0.0
		_path = map.find_path(position, _drop.position)
		_path_i = 0
	# 卸货点占地已封路，工人只能停在外圈。触及半径必须按占地（而非视觉 radius）算，
	# 否则小占地的卸货点（如仓库 radius 20，封 3×3 格）外圈站位离中心 ~2.8 格 ≈ 90px，
	# 远超 radius+6=36，工人永远「到不了」→ 建好仓库后一群农民卡死不动。与 _do_build 同式。
	var fhalf := int(_drop.get_meta("fhalf", 1))
	var reach := maxf(_drop.radius, float((fhalf + 1) * GameMap.CELL) * 1.5) + radius + 8.0
	# 兜底：路已走完（贴到占地外圈、再近不了）即视为抵达——否则占地大/外圈被挤时工人会卡在 ST_RETURN 不卸货。
	var dd := position.distance_to(_drop.position)
	var path_done := _path_i >= _path.size()
	if dd <= reach or (path_done and dd <= reach + GameMap.CELL * 2.0):
		if _carry_amt > 0.0:
			# 玩家吃精耕科技加成；其它阵营吃自家采集系数（难度手感，普通=1 与玩家对等）
			var tg: float = float(battle.tech_gather) if faction == FACTION_LIANG else float(battle.faction_gather_mult.get(faction, 1.0))
			var amt := int(round(_carry_amt * tg))
			if _carry_kind == "gold":
				battle.add_resources(amt, 0, faction)
			else:
				battle.add_resources(0, maxi(1, int(round(amt * 0.5))), faction)   # 木头采集效率减半
		_carry_amt = 0.0
		if _gather_node != null and is_instance_valid(_gather_node) and _gather_node.res_left > 0.0:
			_begin_gather(_gather_node)
		else:
			var n: Unit = battle.nearest_resource(position, _carry_kind)
			if n != null:
				_begin_gather(n)
			else:
				_done_order()
	else:
		_repath -= delta
		if _repath <= 0.0 or _path_i >= _path.size():
			_repath = 0.5
			_path = map.find_path(position, _drop.position)
			_path_i = 0
		_follow_path(delta)


## 工人施工：走到工地→在范围内推进施工进度（建好则收工）
func _do_build(delta: float) -> void:
	if _build_site == null or not is_instance_valid(_build_site) or not _build_site.is_constructing:
		_build_site = null
		_finish_worker_task()   # 建完/工地没了 → 自动回去采集（若之前在采）
		return
	# 工地占地已封路，寻路只能停在外圈；等距投影下「外圈站位」离中心可达 ~2.8 格世界距离，
	# 故触及半径用 1.5× 网格距离来覆盖（否则工人停在够不着的地方，进度永远 0）。
	var fhalf := int(_build_site.get_meta("fhalf", 1))
	var reach := float((fhalf + 1) * GameMap.CELL) * 1.5 + radius + 8.0
	if position.distance_to(_build_site.position) <= reach:
		_face_dir(_build_site.position - position)
		_build_site.advance_build(delta)
	else:
		_repath -= delta
		if _repath <= 0.0 or _path_i >= _path.size():
			_repath = 0.5
			_path = map.find_path(position, _build_site.position)
			_path_i = 0
		_follow_path(delta)


## 工人修理：走到受损建筑→按比例花资源恢复 hp（资源不够则停修）
func _do_repair(delta: float) -> void:
	var bld := _build_site
	if bld == null or not is_instance_valid(bld) or bld.is_constructing or bld.hp <= 0.0 or bld.hp >= bld.max_hp:
		_build_site = null
		_finish_worker_task()
		return
	var fhalf := int(bld.get_meta("fhalf", 1))
	var reach := float((fhalf + 1) * GameMap.CELL) + radius + 6.0
	if position.distance_to(bld.position) <= reach:
		_face_dir(bld.position - position)
		# 维修速度降至原来的 20%（修得更慢；总耗材不变，只是耗时拉长到 5 倍）
		var rate := bld.max_hp / maxf(float(bld.setup_def.get("build_time", 20.0)) * 0.5, 8.0) * 0.2
		var dh := rate * delta
		_repair_g += float(bld.setup_def.get("cost_gold", 0)) * 0.4 / maxf(bld.max_hp, 1.0) * dh
		_repair_w += float(bld.setup_def.get("cost_wood", 0)) * 0.4 / maxf(bld.max_hp, 1.0) * dh
		var sg := int(_repair_g)
		var sw := int(_repair_w)
		if sg > 0 or sw > 0:
			if battle.can_afford(sg, sw):
				battle.spend(sg, sw)
				_repair_g -= sg
				_repair_w -= sw
			else:
				_build_site = null
				_finish_worker_task()   # 没钱修了 → 回去采集攒资源
				return
		bld.hp = minf(bld.max_hp, bld.hp + dh)
		bld.queue_redraw()
		if bld.hp >= bld.max_hp:
			_build_site = null
			_finish_worker_task()
	else:
		_repath -= delta
		if _repath <= 0.0 or _path_i >= _path.size():
			_repath = 0.5
			_path = map.find_path(position, bld.position)
			_path_i = 0
		_follow_path(delta)


## 建筑施工推进（在建筑单位上调用；多个工人各加 delta → 经典RTS式加速）
func advance_build(delta: float) -> void:
	if not is_constructing:
		return
	build_progress += delta
	hp = max_hp * clampf(0.1 + 0.9 * build_progress / maxf(build_time, 0.1), 0.1, 1.0)
	queue_redraw()
	if build_progress >= build_time:
		is_constructing = false
		build_progress = build_time
		hp = max_hp
		if battle != null:
			battle.on_building_complete(self)
		queue_redraw()


## 建筑生产：队列逐个训练，完成即生成（送往集结点）
func _production_tick(delta: float) -> void:
	_train_t -= delta
	if _train_t <= 0.0:
		var key: String = _train_queue.pop_front()
		if battle != null:
			battle.on_unit_trained(self, key)
		if not _train_queue.is_empty():
			_train_t = float(battle._defs.get(_train_queue[0], {}).get("train_time", 12.0))


## 防御塔（箭楼）：固定索敌，冷却到就放箭
func _tower_tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	if _target != null and (not is_instance_valid(_target) or _target.hp <= 0.0 or _target.garrisoned \
			or position.distance_to(_target.position) > atk_range + 60.0):
		_target = null
	if _target == null:
		_acquire()
	if _target != null:
		var reach := atk_range + _target.radius
		if position.distance_to(_target.position) <= reach and _cd <= 0.0:
			_cd = atk_cd
			battle.spawn_projectile(self, _target, atk * buff_atk)
			# 驻军增援：每个驻入的远程兵额外放一箭（经典RTS式 garrison-fire）
			for pg in passengers:
				if is_instance_valid(pg) and pg.is_ranged and pg.hp > 0.0:
					battle.spawn_projectile(self, _target, pg.atk * 0.85)


## 发起一次攻击：起手挥击动画，伤害延后到挥击命中瞬间结算（含起手预备）
func _attack() -> void:
	_cd = atk_cd / maxf(_drunk_atk, 0.1)   # 醉酒攻速：_drunk_atk>1 → 出手更快
	_combat_cool = 6.0
	_lunge = 1.0
	_lunge_dir = (_target.position - position).normalized()
	_swing_kind = _weapon_kind()
	_pending_target = _target
	_pending_done = false
	match _swing_kind:
		WK.SPEAR:
			_swing_speed = 2.8; _hit_at = 0.45   # 突刺（放慢看清，原 4.6）
		WK.AXE:
			_swing_speed = 1.8; _hit_at = 0.35   # 大斧抡砸·命中靠后（放慢，原 2.7）
		WK.BOW:
			_swing_speed = 1.9; _hit_at = 0.42   # 张弓→撒放（放慢，原 2.9）
		_:
			_swing_speed = 2.1; _hit_at = 0.48   # 劈砍（放慢看清，原 3.6）
	queue_redraw()


## 纯表演挥击（采集砍凿等）：只播挥击动作，不结算伤害（_pending_done=true 跳过 _deal_hit）。
func _begin_cosmetic_swing(logic_dir: Vector2) -> void:
	_lunge = 1.0
	_lunge_dir = logic_dir.normalized() if logic_dir.length() > 0.01 else Vector2.RIGHT
	_swing_kind = _weapon_kind()
	_pending_done = true
	_swing_speed = 2.2   # 采集砍凿：放慢看清（与攻击同步）
	_hit_at = 0.5
	queue_redraw()


## 挥击命中瞬间：结算伤害 / 放箭 + 命中火花
func _deal_hit() -> void:
	_pending_done = true
	var t := _pending_target
	if t == null or not is_instance_valid(t) or t.hp <= 0.0:
		return
	# 致盲（武松 E·双戒刀）：本单位攻击必失——不结算伤害、不发射弹丸、不吸血，仅一记落空火花
	if _blind_t > 0.0:
		if battle != null and battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position + Vector2(0, -4), false)
		Sfx.play(_attack_sfx_name(), -11.0, 0.2, 45)
		return
	var dmg := atk * buff_atk * temp_atk + temp_atk_add
	if t.is_cavalry:
		dmg *= bonus_vs_cav
	# 兵种相克（枪>骑>远>步>枪）：克制目标普攻 +10%、被目标克制 −10%。仅作战单位间生效，建筑/资源不参与。
	if not t.is_building and not t.is_resource:
		dmg *= _counter_mult(t)
	# 投石车·攻城：仅对箭楼额外 ×N 伤害（其余建筑/单位无加成）
	if t.key == "arrow_tower" and setup_def.has("vs_tower"):
		dmg *= float(setup_def["vs_tower"])
	# 撞车·破城：对一切建筑 ×N 巨额伤害（撞车 atk 很低，全靠这个倍率拆楼）
	if t.is_building and setup_def.has("vs_building"):
		dmg *= float(setup_def["vs_building"])
	# 投石车对英雄单位伤害大减（笨重攻城器砸不准灵活英雄）：×vs_hero（如 0.3）
	if t.is_hero and setup_def.has("vs_hero"):
		dmg *= float(setup_def["vs_hero"])
	# 暴击：英雄 25%、普通兵 12%，伤害 ×1.8（建筑/资源不暴击，免得拆墙乱跳）
	var crit := not t.is_building and not t.is_resource and randf() < (0.25 if is_hero else 0.12)
	if crit:
		dmg *= 1.8
	# 目标防御值：每点 +5% 等效血量 → 伤害 ÷(1+0.05·防御)。仅普通攻击在此减；技能走 take_damage 不经过这里。
	# 护甲削减（双戒刀）：有效防御 = 防御 − _def_down
	var eff_def := maxf(0.0, t.defense - t._def_down)
	if eff_def > 0.0:
		dmg /= (1.0 + 0.05 * eff_def)
	if is_ranged:
		battle.spawn_projectile(self, t, dmg, crit, float(setup_def.get("splash", 0.0)))
		Sfx.play(_attack_sfx_name(), -5.0, 0.14, 95)
	elif t._phys_immune_t > 0.0:
		# 醉神·物理免疫：普通攻击被挡下，累计转血量；不结算伤害、不吸血
		t._absorbed_phys += dmg
		t._buff_glow = 1.0
		if battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position, false)
		Sfx.play(_attack_sfx_name(), -8.0, 0.14, 60)
	else:
		t.take_damage(dmg, self, crit)
		var ls := lifesteal_frac()
		if ls > 0.0:
			heal(dmg * ls)
		# 林冲·猎骑被动：打骑兵 cav_ls_chance 几率额外吸血 cav_ls_frac×伤害
		if t.is_cavalry and cav_ls_chance > 0.0 and randf() < cav_ls_chance:
			heal(dmg * cav_ls_frac)
			_buff_glow = 1.0
		if battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position, _swing_kind == WK.AXE or crit)
		Sfx.play(_attack_sfx_name(), -4.0, 0.14, 75)


## 兵种相克环：枪克骑、骑克远、远克步、步克枪（克者攻击 +10%，被克者 −10%）。
const COUNTER_BEATS := {"spear": "cav", "cav": "archer", "archer": "inf", "inf": "spear"}


## 本单位的相克类别：骑兵/远程/枪兵(带克骑)/步兵；攻城器与非作战单位不参与(返回"")。
func _counter_class() -> String:
	if key == "siege_cata" or key == "siege_ram" or not (atk > 0.0) or is_worker:
		return ""
	if is_cavalry:
		return "cav"
	if is_ranged:
		return "archer"   # 弓手/法师（花荣挂弓时也算；拔刀近战则落到步/枪）
	if float(setup_def.get("bonus_cav", 1.0)) > 1.0:
		return "spear"    # 长枪手/林冲（带克骑加成）
	return "inf"


## 普攻对 t 的相克伤害系数：克制 1.1、被克 0.9、其余 1.0。
func _counter_mult(t: Unit) -> float:
	var a := _counter_class()
	var d := t._counter_class()
	if a == "" or d == "":
		return 1.0
	if String(COUNTER_BEATS.get(a, "")) == d:
		return 1.1
	if String(COUNTER_BEATS.get(d, "")) == a:
		return 0.9
	return 1.0


## 该建筑是否冒炊烟（有灶火的据点：聚义厅/民居/兵营）——驱动烟柱动画+保持动画时钟。
func _has_smoke() -> bool:
	return key == "hall" or key == "house" or key == "barracks"


## 攻击音效名：先按特殊单位（投石/弩/双鞭/拳/禅杖），否则按武器类型——让不同兵器各有其声。
func _attack_sfx_name() -> String:
	match key:
		"siege_cata": return "atk_catapult"
		"guan_gong": return "atk_crossbow"   # 弩手
		"hu_yanzhuo": return "atk_mace"       # 双鞭
		"jiang_menshen": return "atk_fist"    # 赤手
		"lu_zhishen": return "atk_staff"      # 禅杖
	match _weapon_kind():
		WK.SPEAR: return "atk_spear"
		WK.AXE: return "atk_axe"
		WK.BOW: return "atk_bow"
		_: return "atk_sword"


func _weapon_kind() -> int:
	if _weapon >= 0:
		return _weapon
	if is_ranged:
		_weapon = WK.BOW
	elif key == "li_kui" or key == "lu_zhishen":
		_weapon = WK.AXE
	elif atk_range >= 28.0:
		_weapon = WK.SPEAR
	else:
		_weapon = WK.SWORD
	return _weapon


func _acquire(range_override := -1.0) -> void:
	if aggro_range <= 0.0:
		return
	if stance == STANCE_PASSIVE:
		return   # 避战姿态：完全不主动索敌（撤退/包抄时不被沿途敌人勾住）
	# 据守姿态：只索取已进入攻击范围的敌人 → 原地开打、绝不挪窝
	var range_cap := aggro_range
	if stance == STANCE_HOLD:
		range_cap = atk_range + radius + 12.0
	if range_override >= 0.0:
		range_cap = minf(range_cap, range_override)   # A 移动时收紧索敌：只打路上近处的敌人，不被远处勾走
	var best: Unit = null
	var best_d := INF
	for u in battle.units:
		# 资源点（金矿/林木）不是攻击目标——否则敌人冲过来一直砍树；
		# 被绑缚待救者（captive）亦非攻击目标——否则刽子手会在救援前先把人砍死。
		if u == self or not is_instance_valid(u) or u.faction == faction or u.hp <= 0.0 \
				or u.is_resource or u.garrisoned or u.is_captive or chase_blocked(u):
			continue
		var d: float = position.distance_to(u.position)
		var limit := range_cap
		if u.hidden_in_reeds:
			limit = minf(limit, 75.0)  # 芦苇荡里的伏兵很难被发现
		if d <= limit and d < best_d:
			best = u
			best_d = d
	_target = best


func _follow_path(delta: float) -> bool:
	if _path_i >= _path.size():
		return true
	var wp := _path[_path_i]
	var dir := wp - position
	var dist := dir.length()
	var bspeed := base_speed
	if _group_cap > 0.0 and (_state == ST_MOVE or _state == ST_AMOVE):
		bspeed = minf(base_speed, _group_cap)   # 成队行军：以最慢成员速度推进，保持队形不散开
	var sp := bspeed * buff_speed * temp_speed * _drunk_move * aura_slow * MOVE_SCALE * map.speed_mult_at(position, faction)
	var step := sp * delta
	# 中间路点到达半径放宽：被挤开时不必精确踩点（精确踩点会和挤开逻辑互相拉锯）
	var arrive := maxf(step, 4.0) if _path_i >= _path.size() - 1 else 14.0
	if dist <= arrive:
		if _path_i >= _path.size() - 1:
			position = wp
		_path_i += 1
		return _path_i >= _path.size()
	var next := position + dir / dist * step
	_face_dir(dir)
	if map.is_open_world(next):
		position = next
		_stepped = true
	else:
		_path_i += 1
	return false


const FACE_FLIP_MIN := 7.0   # 翻面磁滞带：要改朝向必须明确朝反方向超过此屏幕横向量，
                             # 否则目标在正上/正下方(sdx≈0)时微小抖动会让单位左右摇头
func _face_dir(d: Vector2) -> void:
	var sdx := d.x - d.y  # 等距投影下屏幕横向 = 逻辑 x - 逻辑 y
	var f := sdx < 0.0
	if f == face_left:
		return
	if absf(sdx) < FACE_FLIP_MIN:   # 反向但不够明确 → 维持当前朝向（消除摇头）
		return
	face_left = f
	queue_redraw()


## ---------- 技能接口（多槽 + 经典RTS式升级）----------

## 建立技能槽：自由模式英雄用 abilities 全套(未学习)；其余用单 ability(默认满级可用)
func _init_ability_slots(def: Dictionary) -> void:
	ability_slots.clear()
	_hero_leveled = battle != null and battle.economy
	var ids: Array = []
	if _hero_leveled and def.has("abilities"):
		ids = def["abilities"]
	elif String(def.get("ability", "")) != "":
		ids = [def["ability"]]
	for id in ids:
		# 优先取本场战斗的(可能被场景/内容包覆盖的)技能表，使本场景新增/改过的技能也能正确建槽
		var ad: Dictionary = (battle._abilities.get(id, {}) if (battle != null and id in battle._abilities) else Defs.ABILITIES.get(id, {}))
		ability_slots.append({"id": String(id), "rank": (0 if _hero_leveled else 1),
			"cd_t": 0.0, "passive": bool(ad.get("passive", false))})
	if _hero_leveled:
		hero_level = 1
		skill_points = 1
		hero_xp = 0.0
	if not ability_slots.is_empty():
		ability = String(ability_slots[0]["id"])
	_recompute_hero_stats()


func slot_count() -> int:
	return ability_slots.size()


func _slot_cd(i: int) -> float:
	if i < 0 or i >= ability_slots.size():
		return 0.0
	var ad: Dictionary = Defs.ABILITIES.get(ability_slots[i]["id"], {})
	# 冷却可随技能等级缩短（cd_ranks: [1级,2级,3级]），否则用固定 cd
	var cr: Array = ad.get("cd_ranks", [])
	if cr.size() > 0:
		return float(cr[clampi(int(ability_slots[i]["rank"]), 1, cr.size()) - 1])
	return float(ad.get("cd", 0.0))


func slot_ready(i: int) -> bool:
	if i < 0 or i >= ability_slots.size():
		return false
	var s: Dictionary = ability_slots[i]
	if int(s["rank"]) <= 0 or float(s["cd_t"]) > 0.0 or hp <= 0.0:
		return false
	# 普通主动：非被动即可施放；混合型被动（带 active_kind，如宋江 R）也可主动施放
	return (not bool(s["passive"])) or slot_has_active(i)


## 该技能槽是否为「混合被动」：声明了 effect.active_kind ——既常驻被动又能主动施放。
func slot_has_active(i: int) -> bool:
	if i < 0 or i >= ability_slots.size():
		return false
	var eff: Dictionary = Defs.ABILITIES.get(ability_slots[i]["id"], {}).get("effect", {})
	return eff.has("active_kind")


func slot_cd_frac(i: int) -> float:
	var cd := _slot_cd(i)
	if cd <= 0.0 or i < 0 or i >= ability_slots.size():
		return 0.0
	return clampf(float(ability_slots[i]["cd_t"]) / cd, 0.0, 1.0)


## 该技能槽按当前等级的冷却总时长（cd_ranks 优先），供 UI 显示「CD 多少秒」。
func slot_cd(i: int) -> float:
	return _slot_cd(i)


func slot_start_cd(i: int) -> void:
	if i < 0 or i >= ability_slots.size():
		return
	ability_slots[i]["cd_t"] = _slot_cd(i)
	_buff_glow = 0.6
	queue_redraw()


## 升级门槛：当前 rank→下一级需达英雄等级。普通技能 [1,3,5]；
## R 大招（最后一个技能槽）要英雄 6 级起才能学/升：[6,8,10]——大招是后期收益。
func can_learn(i: int) -> bool:
	if not _hero_leveled or skill_points <= 0 or i < 0 or i >= ability_slots.size():
		return false
	var r := int(ability_slots[i]["rank"])
	if r >= 3:
		return false
	var gate: Array = [6, 8, 10] if i == ability_slots.size() - 1 else [1, 3, 5]
	return hero_level >= int(gate[r])


func learn(i: int) -> void:
	if not can_learn(i):
		return
	skill_points -= 1
	ability_slots[i]["rank"] = int(ability_slots[i]["rank"]) + 1
	if bool(ability_slots[i]["passive"]):
		_recompute_hero_stats()
	queue_redraw()


## 战死英雄在聚义厅重练后恢复原有等级/经验/技能点/已学技能（不再从 1 级重来）。
func restore_progress(level: int, xp: float, sp: int, ranks: Array) -> void:
	if not _hero_leveled:
		return
	hero_level = clampi(level, 1, HERO_MAX_LEVEL)
	hero_xp = xp
	skill_points = sp
	for i in range(mini(ranks.size(), ability_slots.size())):
		ability_slots[i]["rank"] = int(ranks[i])
	if not ability_slots.is_empty():
		ability = String(ability_slots[0]["id"])
	_recompute_hero_stats()
	hp = max_hp


func xp_to_next() -> float:
	return 100.0 + 60.0 * float(hero_level - 1)


func gain_xp(amount: float) -> void:
	if garrisoned:
		return   # 驻军中（藏在建筑里、不可见）不结算升级，避免隐身改属性 + 升级光效跑到建筑上
	if not _hero_leveled or hero_level >= HERO_MAX_LEVEL:
		return
	hero_xp += amount
	while hero_xp >= xp_to_next() and hero_level < HERO_MAX_LEVEL:
		hero_xp -= xp_to_next()
		hero_level += 1
		skill_points += 1
		var prev_max := max_hp
		var prev_hp := hp
		_recompute_hero_stats()
		# 升级不回满：当前血量只按「最大生命的增长量」上调（受伤的还是受伤，但享受到成长）
		hp = clampf(prev_hp + (max_hp - prev_max), 1.0, max_hp)
		_buff_glow = 1.0
		if battle != null and battle.has_method("spawn_levelup"):
			battle.spawn_levelup(position)
	queue_redraw()


## 重算英雄属性：基础 ×等级成长 + 已学被动加成
func _recompute_hero_stats() -> void:
	if not is_hero:
		return
	var mult := 1.0 + 0.12 * float(hero_level - 1)
	var add_atk := 0.0
	var add_hp := 0.0
	var add_range := 0.0
	var add_cav := 0.0
	cav_ls_chance = 0.0
	cav_ls_frac = 0.0
	for s in ability_slots:
		if bool(s["passive"]) and int(s["rank"]) > 0:
			var eff: Dictionary = Defs.ABILITIES.get(s["id"], {}).get("effect", {})
			add_atk += float(eff.get("atk_add", 0.0)) * int(s["rank"])
			add_hp += float(eff.get("hp_add", 0.0)) * int(s["rank"])
			add_range += float(eff.get("range_add", 0.0)) * int(s["rank"])
			add_cav += float(eff.get("bonus_cav", 0.0)) * int(s["rank"])
			# 林冲·猎骑：被动学了就启用「打骑兵概率吸血」。frac 可按被动等级取数组 cav_ls_frac_ranks。
			if float(eff.get("cav_ls_chance", 0.0)) > 0.0:
				cav_ls_chance = float(eff.get("cav_ls_chance", 0.0))
				var fr: Array = eff.get("cav_ls_frac_ranks", [])
				if fr.size() > 0:
					cav_ls_frac = float(fr[clampi(int(s["rank"]) - 1, 0, fr.size() - 1)])
				else:
					cav_ls_frac = float(eff.get("cav_ls_frac", 0.0))
	var frac := (hp / max_hp) if max_hp > 0.0 else 1.0
	# 把全军生命科技(甲胄/时代+10%)折进重算，否则英雄每次升级/学被动都会把科技血量清掉(攻击科技走 buff_atk 不受影响)
	var tech_hp_f: float = float(battle.tech_hp) if (battle != null and battle.economy and faction == FACTION_LIANG) else 1.0
	max_hp = (_base_hp * mult + add_hp) * tech_hp_f
	hp = clampf(max_hp * frac, 1.0, max_hp)
	atk = _base_atk * mult + add_atk
	atk_range = float(setup_def.get("range", 24)) + add_range
	bonus_vs_cav = float(setup_def.get("bonus_cav", 1.0)) + add_cav
	if melee_mode:                 # 拔刀近战：射程缩为肉搏（即便升被动也维持近战）
		atk_range = 27.0           # 必须 <28：否则 _weapon_kind/身姿绘制会按「长枪」阈值画成枪而非刀


## 已学被动提供的持续回血（如宋江·仁义）
func _passive_regen() -> float:
	if not is_hero:
		return 0.0
	var r := 0.0
	for s in ability_slots:
		if bool(s["passive"]) and int(s["rank"]) > 0:
			r += float(Defs.ABILITIES.get(s["id"], {}).get("effect", {}).get("regen", 0.0)) * int(s["rank"])
	return r


## 已学被动提供的吸血比例（+ 临时嗜血 + 近战持刀加成）
func lifesteal_frac() -> float:
	var ls := temp_lifesteal
	for s in ability_slots:
		if bool(s["passive"]) and int(s["rank"]) > 0:
			ls += float(Defs.ABILITIES.get(s["id"], {}).get("effect", {}).get("lifesteal", 0.0))
	if melee_mode:
		# 花荣·拔刀换刀：近战每次吸血在等级区间内随机 —— 1级20~40% / 2级30~50% / 3级40~60%
		var wr := 1
		for s in ability_slots:
			if String(Defs.ABILITIES.get(s["id"], {}).get("effect", {}).get("kind", "")) == "weapon_toggle":
				wr = clampi(int(s["rank"]), 1, 3)
				break
		ls += randf_range(0.10 + 0.10 * float(wr), 0.30 + 0.10 * float(wr))
	return ls


## 花荣·拔刀/挂弓：在远程弓与近战刀之间切换。近战射程缩短、武器改劈砍、并 +10% 吸血。
func toggle_melee() -> void:
	if not can_melee_switch:
		return
	melee_mode = not melee_mode
	is_ranged = (not melee_mode) and bool(setup_def.get("ranged", false))
	_weapon = -1                 # 重算武器：近战→劈砍，远程→弓
	_recompute_hero_stats()      # 内部按 melee_mode 决定射程
	aggro_range = maxf(200.0, atk_range + 50.0)
	_buff_glow = 0.6
	queue_redraw()


# 兼容旧单技能接口（= 槽0）
func ability_ready() -> bool:
	return slot_ready(0)


func ability_cd_frac() -> float:
	return slot_cd_frac(0)


func start_ability_cd() -> void:
	slot_start_cd(0)


func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	_buff_glow = 0.6
	queue_redraw()


func apply_temp_atk(mult: float, dur: float) -> void:
	temp_atk = mult
	_temp_atk_t = dur
	_buff_glow = 0.6
	queue_redraw()


## 临时「平攻加成」（+N 攻击，与乘区 temp_atk 叠加）：李逵暴走用。
func apply_temp_atk_add(add: float, dur: float) -> void:
	temp_atk_add = add
	_temp_atk_add_t = dur
	_buff_glow = 0.6
	queue_redraw()


## 发动冲锋（李逵 W）：蓄力 windup 秒后，朝 dir 高速冲 dist 像素，撞翻沿途敌人。
func _begin_charge(dir: Vector2, dmg: float, windup: float, dist: float, width: float, slow: float, slow_dur: float) -> void:
	if dir.length() < 0.01:
		dir = Vector2(-1.0 if face_left else 1.0, 0.0)
	_charge_dir = dir.normalized()
	_charge_dmg = dmg
	_charge_t = windup
	_charge_dash = maxf(0.18, dist / 560.0)   # 冲刺时长：约 560px/s
	_charge_width = width
	_charge_slow = slow
	_charge_slow_dur = slow_dur
	_charge_hit.clear()
	_target = null
	_state = ST_IDLE
	_queue.clear()
	_face_dir(_charge_dir)
	queue_redraw()


## 冲锋逐帧：蓄力期原地待命；冲刺期沿 dir 平移，扫到的敌人各撞一次。
func _do_charge_step(delta: float) -> void:
	if _charge_t > 0.0:
		_charge_t = maxf(0.0, _charge_t - delta)
		_face_dir(_charge_dir)
		queue_redraw()
		return
	# 冲刺中：高速平移（受阻则停），撞伤沿途敌人
	var step := _charge_dir * 560.0 * delta
	var np := position + step
	if map != null and map.is_open_world(np):
		position = np
		_stepped = true
	else:
		_charge_dash = 0.0   # 撞墙/出界 → 结束冲刺
	if battle != null:
		for u in battle.units:
			if not is_instance_valid(u) or u.faction == faction or u.hp <= 0.0 \
					or u.is_resource or u.garrisoned or _charge_hit.has(u):
				continue
			if position.distance_to(u.position) <= _charge_width * 0.5 + u.radius:
				_charge_hit.append(u)
				if _charge_slow > 0.0:
					u.apply_slow(_charge_slow, _charge_slow_dur)
				u.take_damage(_charge_dmg, self)
				if battle.has_method("spawn_impact"):
					battle.spawn_impact(u.position, true)
	_charge_dash = maxf(0.0, _charge_dash - delta)
	queue_redraw()


func apply_lifesteal(frac: float, dur: float) -> void:
	temp_lifesteal = frac
	_temp_lifesteal_t = dur
	_buff_glow = 0.6


func apply_slow(mult: float, dur: float) -> void:
	temp_speed = mult
	_temp_speed_t = dur


## 三碗不过岗（武松 W）：dur 秒内移动/攻速在 [lo,hi] 间随机波动，立即先掷一次。
func start_drunk(lo: float, hi: float, dur: float) -> void:
	_drunk_lo = lo
	_drunk_hi = hi
	_drunk_t = dur
	_drunk_reroll = 0.0   # 下帧立刻重掷
	_drunk_move = randf_range(lo, hi)
	_drunk_atk = randf_range(lo, hi)
	_buff_glow = 1.0


## 醉神大闹快活林（武松 R）：dur 秒物理免疫 + 每击 +bonus 平攻；结束把挡下物理伤害 50% 转血。
func start_drunk_god(bonus: float, dur: float) -> void:
	_phys_immune_t = dur
	_absorbed_phys = 0.0
	apply_temp_atk_add(bonus, dur)
	_buff_glow = 1.0


func is_phys_immune() -> bool:
	return _phys_immune_t > 0.0


## 护甲削减（武松 E·双戒刀）：amount 点防御，dur 秒。
func apply_def_down(amount: float, dur: float) -> void:
	_def_down = maxf(_def_down, amount)
	_def_down_t = maxf(_def_down_t, dur)


## 致盲（武松 E·双戒刀附带）：dur 秒内本单位攻击必失（_deal_hit 落空）。
func apply_blind(dur: float) -> void:
	_blind_t = maxf(_blind_t, dur)
	_buff_glow = 0.6


func is_blinded() -> bool:
	return _blind_t > 0.0


func is_stunned() -> bool:
	return _stun_t > 0.0


## 眩晕（踩地板控制）：取较长者，松开当前目标，呆立挨打。
func apply_stun(dur: float) -> void:
	_stun_t = maxf(_stun_t, dur)
	_target = null
	queue_redraw()


func _spawn_dust() -> void:
	if is_cavalry:
		return  # 骑兵用马蹄尘另算；步兵扬尘
	if map != null and map.t_world(position) == GameMap.T.WATER:
		return
	var back := 5.0 if face_left else -5.0   # 朝行进反方向向后蹬出
	_dust.append({"x": back + randf_range(-3.0, 3.0), "y": randf_range(1.0, 4.0), "t": DUST_DUR})
	if _dust.size() > 4:
		_dust.pop_front()


## 施法抬手·蓄能辉光（屏幕对齐空间绘制）：头顶光球渐亮、外环向心收束、几点能量丝上升。
func _draw_cast_glow() -> void:
	var w := clampf(1.0 - _cast_t / _cast_dur, 0.0, 1.0)   # 0→1 蓄能进度
	var head := Vector2(0.0, -radius * 1.7)
	var c := _cast_color
	var pulse := 0.65 + 0.35 * sin(w * TAU * 3.0)
	draw_circle(head, radius * (0.26 + 0.40 * w), Color(c.r, c.g, c.b, 0.26 * w))   # 外晕
	draw_circle(head, radius * (0.12 + 0.18 * w), Color(1.0, 1.0, 1.0, 0.55 * w * pulse))  # 亮核
	var rr := radius * (1.55 - 1.15 * w)                    # 收束环：由外向内汇聚
	draw_arc(head, rr, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.5 * w), 2.0)
	for i in range(5):                                      # 上升能量丝
		var ph := fposmod(w * 1.4 + float(i) * 0.2, 1.0)
		var a := float(i) / 5.0 * TAU
		var p := Vector2(cos(a) * radius * 0.7 * (1.0 - ph), -radius * 0.2 - radius * 1.7 * ph)
		draw_circle(p, 2.2 * (1.0 - ph), Color(c.r, c.g, c.b, 0.55 * w * (1.0 - ph)))


## 施法抬手：开始一段蓄势（dur 秒），期间播放抬手姿+蓄能辉光；归零后由 battle 触发技能结算。
func begin_cast_windup(dur: float, col: Color) -> void:
	_cast_t = dur
	_cast_dur = maxf(dur, 0.001)
	_cast_color = col
	queue_redraw()


## 逻辑方向 → 直立(屏幕)空间方向，用于攻击突刺/劈砍朝向
func _screen_dir(d: Vector2) -> Vector2:
	return Vector2(d.x - d.y, (d.x + d.y) * 0.5).normalized()


## 直立精灵绘制 + 全部程序化动画（行走步态、待机呼吸、攻击突刺·劈砍、死亡倒地）
func _draw_sprite_animated(tex: Texture2D, tint: Color, death_f: float) -> void:
	var s := radius * 3.7
	var off := Vector2.ZERO
	var ang := 0.0
	var sx := -1.0 if face_left else 1.0
	var sy := 1.0
	var frame := tex

	if _dying:
		var df: Array = Art.unit_anim_frames(_anim_key(), "death")
		if not df.is_empty():
			# 真·死亡逐帧：按死亡进度播一遍、末帧定格在地；后 30% 才淡出（先看清倒地、再消失），不叠程序化倾倒
			_real_frames = true
			frame = df[mini(int(death_f * df.size()), df.size() - 1)]
			tint = Color(tint.r, tint.g, tint.b, 1.0 - clampf((death_f - 0.7) / 0.3, 0.0, 1.0))
		else:
			frame = _rest_frame(tex)               # 无死亡帧：退回程序化倒地（同一套美术，避免跳变）
			ang = _death_lean * death_f * 1.5      # 朝倒地方向旋转 ~86°
			off.y = death_f * radius * 0.55
			off.x += _death_lean * death_f * radius * 0.22
			sy = 1.0 - 0.18 * death_f
			tint = Color(tint.r, tint.g, tint.b, 1.0 - death_f)
	else:
		frame = _anim_frame_for_state(tex)
		# 有真·逐帧（腿部动作已画进帧里）时压低程序化次级运动，避免叠加抖动
		var fdamp := 0.28 if _real_frames else 1.0
		var fwd := -1.0 if face_left else 1.0                # 屏幕前进方向符号
		var gallop := 1.6 if is_cavalry else 1.0
		var mb := _move_blend
		# —— 步态：一个步幅 = 2π，含两次触地（cos(2θ)）——
		var plant := (cos(_anim_t * 2.0) + 1.0) * 0.5        # 1=触地吃重 0=腾空过渡
		var bodydown := cos(_anim_t * 2.0) * 2.2 * gallop * mb * fdamp
		if is_cavalry:
			bodydown += -absf(sin(_anim_t)) * 1.6 * mb       # 奔马腾空上扬
		off.y = bodydown
		var breath := sin(_idle_t * 2.2) * 0.02 * (1.0 - mb) # 待机呼吸
		# 触地压缩 / 腾空拉伸（squash & stretch）
		var sq := (plant - 0.45) * mb * fdamp
		sy = (1.0 - sq * 0.16) + breath
		sx *= (1.0 + sq * 0.11)
		# 重心左右换步 + 躯干侧倾（每步幅一次）
		off.x += sin(_anim_t) * 1.7 * gallop * mb * fdamp
		ang += sin(_anim_t) * 0.06 * mb * fdamp
		# 行进前倾（即便用逐帧也保留，体现冲势）
		ang += fwd * (0.045 + 0.05 * (gallop - 1.0)) * mb
		off.x += fwd * 1.4 * mb
		if is_cavalry and mb > 0.01:                         # 奔马前后涌动
			off.x += fwd * sin(_anim_t * 0.5) * 2.0 * mb
		off += _flinch                                        # 受击退缩
		if _lunge > 0.0:                                      # 武器化挥击
			# 有真·逐帧攻击时，挥击动作已画进帧里 → 压低程序化突刺位移/旋转，避免与帧内动作叠加成双重抖动
			var swdamp := 0.25 if _real_frames else 1.0
			off += _swing_offset() * swdamp
			ang += _swing_rot() * swdamp
		if _cast_t > 0.0:                                     # 施法抬手：起身后仰蓄势，结算瞬间回落=「放招」
			var lift := 1.0 - _cast_t / _cast_dur             # 0→1
			lift = lift * lift * (3.0 - 2.0 * lift)           # smoothstep
			var k := 0.35 if _real_frames else 1.0            # 已有攻击帧表演时压低程序化抬身，避免叠加
			off.y -= 8.0 * lift * k                           # 抬身
			ang += fwd * -0.16 * lift * k                      # 略后仰
			sy += 0.07 * lift * k                              # 上扬拉伸

	draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(ang, Vector2(sx, sy), 0.0, off))
	var srect := Rect2(-s * 0.5, -s * 0.82, s, s)
	# 暗色描边：四方各偏移画成半透黑剪影，叠出轮廓 → 单位从草地/背景里清晰跳出（提升可读性）
	if not _dying:
		var ow := 1.7
		var ocol := Color(0.05, 0.04, 0.03, 0.5)
		draw_texture_rect(frame, Rect2(srect.position + Vector2(ow, 0), srect.size), false, ocol)
		draw_texture_rect(frame, Rect2(srect.position + Vector2(-ow, 0), srect.size), false, ocol)
		draw_texture_rect(frame, Rect2(srect.position + Vector2(0, ow), srect.size), false, ocol)
		draw_texture_rect(frame, Rect2(srect.position + Vector2(0, -ow), srect.size), false, ocol)
	draw_texture_rect(frame, srect, false, tint)
	if not _dying and _lunge > 0.0:
		_draw_swing_fx()
	draw_set_transform_matrix(GameMap.ISO_INV)
	if not _dying and _cast_t > 0.0:
		_draw_cast_glow()


## 挥击位移（直立空间）：按武器类型给不同的起手—出招曲线
func _swing_offset() -> Vector2:
	var sd := _screen_dir(_lunge_dir)
	var ph := 1.0 - _lunge
	var thrust := sin(clampf((ph - 0.15) / 0.6, 0.0, 1.0) * PI)   # 出招主推力 0→1→0
	var anticip := clampf((0.2 - ph) / 0.2, 0.0, 1.0)            # 起手预备 1→0
	match _swing_kind:
		WK.SPEAR:
			return sd * (15.0 * thrust - 2.0 * anticip)
		WK.AXE:
			return sd * (10.0 * thrust - 7.0 * anticip) + Vector2(0.0, -9.0 * anticip + 4.0 * thrust)
		WK.BOW:
			return sd * (-5.0 * (anticip + thrust * 0.4))         # 张弓后拉
		_:
			return sd * (11.0 * thrust - 4.0 * anticip)           # 劈砍
	return Vector2.ZERO


func _swing_rot() -> float:
	var ph := 1.0 - _lunge
	var thrust := sin(clampf((ph - 0.15) / 0.6, 0.0, 1.0) * PI)
	var dir := -1.0 if face_left else 1.0
	match _swing_kind:
		WK.AXE:
			return dir * 0.30 * thrust
		WK.SWORD:
			return dir * 0.18 * thrust
		_:
			return 0.0


## 挥击特效：刀光/斧光弧 / 枪刺线（弓无近战特效，箭矢本身即特效）
func _draw_swing_fx() -> void:
	var dir := -1.0 if face_left else 1.0
	var ph := 1.0 - _lunge
	match _swing_kind:
		WK.SWORD, WK.AXE:
			if _lunge > 0.05 and _lunge < 0.65:
				var a := clampf(sin(ph * PI), 0.0, 1.0)
				var rad := radius * (1.55 if _swing_kind == WK.AXE else 1.3)
				var base := 0.0 if dir > 0.0 else PI
				var spread := 1.25 if _swing_kind == WK.AXE else 1.0
				draw_arc(Vector2(dir * radius * 1.3, -radius * 1.3), rad, base - spread, base + spread, 18,
					Color(1, 1, 1, a * 0.85), 4.0 if _swing_kind == WK.AXE else 3.0)
		WK.SPEAR:
			if _lunge > 0.1 and _lunge < 0.7:
				var a := sin(ph * PI)
				var sd := _screen_dir(_lunge_dir)
				draw_line(Vector2(0.0, -radius * 0.9), Vector2(sd.x * radius * 2.6, -radius * 0.9 + sd.y * radius * 0.9),
					Color(0.92, 0.96, 1.0, a * 0.7), 2.5)


## 当前精灵动画用的美术 key：花荣拔刀近战时切到「<key>_melee」走刀版本（无此美术则回退原 key）。
func _anim_key() -> String:
	if melee_mode and can_melee_switch and not Art.unit_anim_frames(key + "_melee", "walk").is_empty():
		return key + "_melee"
	return key


## 逐帧动画接口：若 assets/anim/<key>_<state>.png 存在则播放帧，否则返回单张立绘。
## 帧数任意：attack 随挥击进度播一遍，walk 按步幅相位均匀映射整条带，idle 缓慢循环。
func _anim_frame_for_state(fallback: Texture2D) -> Texture2D:
	var ak := _anim_key()
	# 出招优先：若有 attack 帧带就同步挥击进度播放
	if _lunge > 0.0:
		# 采矿/采集时：优先用专属「采矿」帧带（如喽啰挥锄凿地），无则退回攻击帧
		if _state == ST_GATHER:
			var gf: Array = Art.unit_anim_frames(ak, "gather")
			if not gf.is_empty():
				_real_frames = true
				var gph := clampf(1.0 - _lunge, 0.0, 0.999)
				return gf[int(gph * gf.size()) % gf.size()]
		var af: Array = Art.unit_anim_frames(ak, "attack")
		if not af.is_empty():
			_real_frames = true
			var ph := clampf(1.0 - _lunge, 0.0, 0.999)       # 0→1 一遍挥击
			return af[int(ph * af.size()) % af.size()]
	# 施法抬手：借用攻击帧带做「抬手蓄势」姿（不结算伤害），停在挥击中段=举起待发
	if _cast_t > 0.0:
		var ac: Array = Art.unit_anim_frames(ak, "attack")
		if not ac.is_empty():
			_real_frames = true
			var cph := clampf(1.0 - _cast_t / _cast_dur, 0.0, 1.0) * 0.55   # 只播到挥击中段
			return ac[int(cph * ac.size()) % ac.size()]
	var moving := _move_blend > 0.3
	var state := "walk" if moving else "idle"
	var frames: Array = Art.unit_anim_frames(ak, state)
	if frames.is_empty() and not moving:
		# 无专门 idle 帧时，用走循环里「双腿并拢」的过渡帧当静止姿，
		# 确保静止与行走是同一套美术（否则会和旧静态图集立绘的大小/画风对不上 → 起停跳变）
		var rf := _rest_frame(fallback)
		_real_frames = rf != fallback
		return rf
	if frames.is_empty():
		_real_frames = false
		return fallback
	_real_frames = true
	var n := frames.size()
	var t := (fposmod(_anim_t, TAU) / TAU) if moving else (fposmod(_idle_t * 1.4, TAU) / TAU)
	return frames[int(t * n) % n]


## 静止姿：有走循环帧时取「双腿并拢」过渡帧（idle/死亡共用，保证全程一套美术），否则退回静态立绘
func _rest_frame(fallback: Texture2D) -> Texture2D:
	var wf: Array = Art.unit_anim_frames(_anim_key(), "walk")
	if not wf.is_empty():
		return wf[1 % wf.size()]
	return fallback


func _draw() -> void:
	var tex: Texture2D = Art.unit_texture(key)

	var death_f := clampf(_death_t / DEATH_DUR, 0.0, 1.0) if _dying else 0.0

	# 地面层（逻辑空间直接绘制 → 被等距变换压成贴地椭圆）：投影 + 扬尘 + 增益辉光 + 选择圈
	if is_building:
		draw_circle(Vector2(0, 6), radius * 0.85, Color(0, 0, 0, 0.20))
	else:
		var lift := maxf(0.0, -cos(_anim_t * 2.0)) * _move_blend   # 腾空时影子收缩
		var ssc := radius * 0.95 * (1.0 - 0.16 * lift)
		draw_circle(Vector2(2, 3), ssc, Color(0, 0, 0, (0.25 - 0.06 * lift) * (1.0 - death_f)))
	for d in _dust:
		var da: float = d.t / DUST_DUR
		draw_circle(Vector2(d.x, d.y), 2.5 + 5.0 * (1.0 - da), Color(0.62, 0.56, 0.45, da * 0.4))
	if _buff_glow > 0.0:
		draw_circle(Vector2.ZERO, radius + 7.0, Color(1.0, 0.85, 0.35, _buff_glow * 0.5))
	# 减速光环（公孙胜 E）：脚下青蓝色范围环
	if slow_aura_r > 0.0 and not _dying:
		var pulse := 0.5 + 0.5 * sin(_idle_t * 2.2)
		draw_arc(Vector2.ZERO, slow_aura_r, 0.0, TAU, 40, Color(0.5, 0.8, 1.0, 0.18 + 0.10 * pulse), 2.0)
		draw_circle(Vector2.ZERO, slow_aura_r, Color(0.4, 0.7, 1.0, 0.05))
	# 醉神·物理免疫（武松 R）：金色护体环
	if _phys_immune_t > 0.0 and not _dying:
		var sp := 0.6 + 0.4 * sin(_idle_t * 7.0)
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 28, Color(1.0, 0.82, 0.3, 0.85 * sp), 3.0)
	if inspected and not selected and not _dying:
		# 查看中的敌方单位：红圈（与己方绿圈区分），只读
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 28, Color(1.0, 0.4, 0.32, 0.92), 2.5)
		draw_arc(Vector2.ZERO, radius + 8.0, 0.0, TAU, 32, Color(1.0, 0.5, 0.3, 0.4), 1.5)
	if selected and not _dying:
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 28, Color(0.35, 1.0, 0.45, 0.9), 2.5)
		if is_active:
			# 活动单位：醒目金色双环（地面圈层），在一队绿圈里一眼认出是哪个
			draw_arc(Vector2.ZERO, radius + 8.5, 0.0, TAU, 36, Color(1.0, 0.84, 0.26, 0.98), 3.5)
			draw_arc(Vector2.ZERO, radius + 2.5, 0.0, TAU, 30, Color(1.0, 0.96, 0.62, 0.55), 1.5)

	# 直立层：精灵/血条/名字抵消等距变换，保持竖直
	draw_set_transform_matrix(GameMap.ISO_INV)

	# 没有静态图集格、但放了逐帧走循环的单位（喽啰、梁山马军）也要走精灵绘制，
	# 否则会卡在占位符——_anim_frame_for_state 在 tex 为 null 时用走循环帧当静止/行走姿。
	var has_walk := not Art.unit_anim_frames(_anim_key(), "walk").is_empty()
	var as_sprite := not is_building and (tex != null or has_walk)
	var tint := Color(1.4, 1.2, 1.1) if _flash > 0.0 else Color.WHITE
	if as_sprite:
		_draw_sprite_animated(tex, tint, death_f)
	elif is_building:
		_draw_building()
	else:
		_draw_placeholder()

	var bar_y: float
	if is_building:
		bar_y = -radius * 1.9
	elif as_sprite:
		bar_y = -radius * 3.3
	else:
		bar_y = -radius - 9.0

	# 名字（头领与建筑）
	if (is_hero or is_building) and not _dying:
		var f := ThemeDB.fallback_font
		var ty := bar_y - 6.0
		draw_string(f, Vector2(-49.0, ty + 1.0), display_name, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 13, Color(0, 0, 0, 0.8))
		var nc := Color("ffd866") if faction == FACTION_LIANG else Color("ff8866")
		draw_string(f, Vector2(-50.0, ty), display_name, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 13, nc)
		# 驻军占用徽标：建筑里有兵时在名字上方显示「▣ N/容量」，一眼看出驻军情况
		if is_building and not passengers.is_empty():
			var gt := "▣ %d/%d" % [passengers.size(), garrison_cap]
			var gy := ty - 14.0
			draw_string(f, Vector2(-49.0, gy + 1.0), gt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 12, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(-50.0, gy), gt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 12, Color("9fe8b0"))

	# 血条：常显（阵营色描边——梁山金、官军红）
	if hp > 0.0 and Settings.show_healthbars:
		var w := (radius * 2.6) if (is_hero or is_building) else (radius * 2.1)
		var bh := 5.0 if (is_hero or is_building) else 4.0
		draw_rect(Rect2(-w * 0.5 - 1.0, bar_y - 1.0, w + 2.0, bh + 2.0), Color(0, 0, 0, 0.8))
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var hc := Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.3), frac)
		if faction == FACTION_GUAN:
			hc = Color(0.6, 0.1, 0.1).lerp(Color(0.9, 0.55, 0.2), frac)
		draw_rect(Rect2(-w * 0.5, bar_y, w * frac, bh), hc)

	# 编队号徽标：单位右下角（同属多队 → 逐个号并排显示，如 1 2）
	if not group_nums.is_empty() and not _dying:
		var gf := ThemeDB.fallback_font
		var bx := radius * 0.55
		var by := radius * 0.2
		var cw := 13.0                                   # 每个号一格
		for i in group_nums.size():
			var cx := bx + cw * float(i)
			draw_rect(Rect2(cx, by, cw + 1.0, 16), Color(0.10, 0.08, 0.05, 0.92))
			draw_rect(Rect2(cx, by, cw + 1.0, 16), Color("ffd866"), false, 1.0)
			draw_string(gf, Vector2(cx + 3.0, by + 13.0), str(group_nums[i]), HORIZONTAL_ALIGNMENT_LEFT, cw, 13, Color("ffe9a8"))

	# 眩晕：头顶三颗旋转金星（经典「被打懵」标记）
	if _stun_t > 0.0 and not is_building and not _dying:
		var syc := bar_y - 16.0
		var spin := _idle_t * 6.0
		for i in range(3):
			var a := spin + float(i) * TAU / 3.0
			_draw_star(Vector2(cos(a) * 11.0, sin(a) * 4.0 + syc), 3.2, Color(1.0, 0.9, 0.35))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 一颗五角星（眩晕标记）：c 中心、rad 外径，直立空间内绘制。
func _draw_star(c: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rr := rad if i % 2 == 0 else rad * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)


func _draw_placeholder() -> void:
	var base := Color("e6b84c") if faction == FACTION_LIANG else Color("a03c33")
	if is_hero:
		base = base.lightened(0.15)
	if _flash > 0.0:
		base = base.lightened(0.5)
	var dark := base.darkened(0.45)

	if is_cavalry:
		# 骑兵：马身（横椭圆）+ 骑手
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(0.0, Vector2(1.45, 0.85), 0.0, Vector2.ZERO))
		draw_circle(Vector2.ZERO, radius, base)
		draw_set_transform_matrix(GameMap.ISO_INV)
		draw_circle(Vector2(0, -5), radius * 0.55, base.lightened(0.2))
		draw_arc(Vector2(0, -5), radius * 0.55, 0.0, TAU, 16, dark, 1.5)
	else:
		draw_circle(Vector2.ZERO, radius, base)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, dark, 1.5)
		if is_ranged:
			# 弓手：一张小弓
			draw_arc(Vector2(2, 0), radius * 0.6, -PI / 2.5, PI / 2.5, 10, dark, 2.0)
			draw_line(Vector2(-4, 0), Vector2(6, 0), dark, 1.5)
		elif atk_range >= 28.0:
			# 长枪手：一杆长枪
			draw_line(Vector2(-7, 6), Vector2(8, -8), dark, 2.0)
			draw_line(Vector2(8, -8), Vector2(5, -8), dark, 2.0)
		else:
			# 刀手：一柄朴刀（三角刀头）
			draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(5, 4), Vector2(-5, 4)]), dark)
	if is_hero:
		draw_circle(Vector2(0, 0), 2.5, Color.WHITE)


func _draw_building() -> void:
	if is_resource:
		_draw_resource_node()
		return
	# 按建筑自身 key 找专属美术：遭遇战建筑在 buildings；treasure_cart 在 units3；其余在 terrain
	var tex: Texture2D = Art.building_texture(key)
	if tex == null:
		tex = Art.unit_texture(key)
	if tex == null:
		tex = Art.terrain_texture(key)
	if tex == null:
		tex = Art.terrain_texture("hall")
	var tint := Color(0.62, 0.66, 0.78, 0.82) if is_constructing else Color.WHITE
	if tex != null:
		# 视觉尺寸与「建造预览虚影」完全一致（GameMap.building_visual_px）——预览多大、建好就多大，
		# 不再出现「预览很大、落成缩水」的落差。
		var s := GameMap.building_visual_px(GameMap.footprint_half_for(radius))
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.78, s, s), false, tint)
		if not is_constructing and _has_smoke():
			_draw_smoke(s)
		if is_constructing:
			_draw_build_progress()
		return
	_draw_building_fallback()
	if is_constructing:
		_draw_build_progress()


## 炊烟：从屋顶烟囱升起的几缕半透烟团，循环上飘+横移+渐隐渐大（直立/屏幕对齐空间）。
func _draw_smoke(s: float) -> void:
	var sx := -s * 0.16            # 烟囱大致位置（偏左上）
	var top := -s * 0.46
	for i in range(4):
		var ph := fposmod(_idle_t * 0.35 + float(i) * 0.25, 1.0)   # 0→1 上升相位
		var y := top - ph * s * 0.5
		var x := sx + sin(_idle_t * 1.4 + float(i) * 1.7) * ph * 9.0
		var a := (1.0 - ph) * 0.26
		draw_circle(Vector2(x, y), 3.0 + ph * 7.0, Color(0.72, 0.70, 0.67, a))


## 施工进度条（直立空间）：经典RTS式——黑边底槽 + 黄→绿渐进填充 + 百分比
func _draw_build_progress() -> void:
	var frac := clampf(build_progress / maxf(build_time, 0.1), 0.0, 1.0)
	var bw := maxf(radius * 2.3, 48.0)
	var bh := 8.0
	var by := -radius * 1.4
	draw_rect(Rect2(-bw * 0.5 - 1.0, by - 1.0, bw + 2.0, bh + 2.0), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(-bw * 0.5, by, bw, bh), Color(0.14, 0.14, 0.14, 0.95))
	var fc := Color(0.95, 0.74, 0.24).lerp(Color(0.40, 0.90, 0.45), frac)
	draw_rect(Rect2(-bw * 0.5, by, bw * frac, bh), fc)
	var f := ThemeDB.fallback_font
	var pct := "%d%%" % int(frac * 100.0)
	draw_string(f, Vector2(-14.0, by - 4.0), pct, HORIZONTAL_ALIGNMENT_CENTER, 28.0, 11, Color(0, 0, 0, 0.85))
	draw_string(f, Vector2(-15.0, by - 5.0), pct, HORIZONTAL_ALIGNMENT_CENTER, 28.0, 11, Color(1, 1, 1, 0.95))


## 资源点绘制（直立空间）：有美术贴图则用之（金矿/三种树循环），否则退回程序化占位。
func _draw_resource_node() -> void:
	var okey := "gold_mine"
	if res_kind == "wood":
		# 按节点坐标稳定地在三种树间取一种，让林子有变化
		var variants := ["tree", "tree1", "tree2"]
		okey = variants[int(absf(position.x * 0.13 + position.y * 0.07)) % 3]
	var tex: Texture2D = Art.object_texture(okey)
	if tex == null and res_kind == "wood":
		tex = Art.object_texture("tree")
	if tex != null:
		var s := radius * 3.4
		# 资源点动画：树随风轻摆、被砍时猛晃（绕根部旋转）；金矿被凿时左右震动。
		var piv := Vector2(0.0, s * 0.12)              # 旋转支点≈根部
		var sway := 0.0
		var shk := Vector2.ZERO
		if res_kind == "wood":
			sway = sin(_idle_t * 1.6 + position.x * 0.11) * 0.02 + sin(_idle_t * 22.0) * 0.10 * _harvest_pulse
		else:
			shk = Vector2(sin(_idle_t * 30.0) * 3.5 * _harvest_pulse, 0.0)
		draw_set_transform_matrix(GameMap.ISO_INV * Transform2D(sway, piv + shk) * Transform2D(0.0, -piv))
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.84, s, s), false)
		draw_set_transform_matrix(GameMap.ISO_INV)
		return
	if res_kind == "wood":
		var trunk := Color(0.42, 0.30, 0.18)
		var leaf := Color(0.20, 0.42, 0.20)
		draw_rect(Rect2(-3, -10, 6, 18), trunk)
		draw_circle(Vector2(0, -20), radius * 0.95, leaf.darkened(0.1))
		draw_circle(Vector2(-radius * 0.5, -14), radius * 0.7, leaf)
		draw_circle(Vector2(radius * 0.5, -15), radius * 0.7, leaf.lightened(0.08))
	else:
		var rock := Color(0.5, 0.48, 0.42)
		draw_circle(Vector2(0, -6), radius * 0.9, rock.darkened(0.15))
		draw_circle(Vector2(-radius * 0.4, -2), radius * 0.55, rock)
		draw_circle(Vector2(radius * 0.4, -4), radius * 0.5, rock.lightened(0.1))
		for off in [Vector2(-4, -8), Vector2(5, -5), Vector2(0, -12), Vector2(-8, -2)]:
			draw_circle(off, 2.2, Color(1.0, 0.82, 0.25))
	return


func _draw_building_fallback() -> void:
	# 占位聚义厅：木墙 + 双坡屋顶 + 杏黄旗
	var wall := Color("8a6f4d")
	var roof := Color("5a4632")
	draw_rect(Rect2(-38, -16, 76, 40), wall)
	draw_rect(Rect2(-38, -16, 76, 40), roof.darkened(0.2), false, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-46, -16), Vector2(0, -44), Vector2(46, -16)]), roof)
	draw_rect(Rect2(-8, 6, 16, 18), roof.darkened(0.3))
	# 杏黄旗
	draw_line(Vector2(30, -44), Vector2(30, -70), Color("6b5536"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(30, -70), Vector2(52, -64), Vector2(30, -56)]), Color("e6b84c"))
