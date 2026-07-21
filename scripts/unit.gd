class_name Unit
extends Node2D
## 单位：梁山好汉 / 官军。有图集贴图就用贴图，否则绘制占位图形。

enum { FACTION_LIANG = 0, FACTION_GUAN = 1 }
enum { ST_IDLE, ST_MOVE, ST_AMOVE, ST_CHASE, ST_GATHER, ST_RETURN, ST_BUILD, ST_REPAIR, ST_GARRISON }
enum { STANCE_AGGRO, STANCE_DEFEND, STANCE_HOLD, STANCE_PASSIVE }   # 进攻=追击/守备=守阵/据守=原地/避战=不索敌不还手
enum { CHASE_AUTO, CHASE_AMOVE, CHASE_EXPLICIT, CHASE_FORCED }
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
var _track_combat_stats := false   # 生成时缓存模式开关，受击热路径不做动态属性查询

# 经济（遭遇战）：工人采集 / 资源点
var is_worker := false       # 喽啰：可采集/建造
var is_resource := false     # 资源点（金矿/林木）
var res_kind := ""           # "gold" / "wood"
var res_left := 0.0          # 资源点剩余储量
var _gold_miner: Unit = null # 金矿专用：当前在矿口开采的农民（金矿一次只许一人进，木头不限）
var _gold_waiters: Array = [] # 金矿等待队列：保证多名工人轮流进矿，不让后到者永久饿死
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
var _pending_build := false   # 工地「虚影」态：已下单但工人未到、未真正起建——不挡路、不可被攻击、半透显示；工人到场起第一锤才转实体
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
var fog_visible := true      # 战争迷雾情报可见性；Battle 再与镜头范围合并成 CanvasItem.visible
var passive := false        # 伏击/按兵不动：不主动索敌，待玩家下令或被攻击才出手
var stance := STANCE_AGGRO   # 作战姿态：进攻=追击索敌；守备=守阵地短追；据守=原地只打近敌
var _hold_order_active := false
var _hold_prev_stance := STANCE_AGGRO
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
var _temp_move_boost := 1.0   # 独立于减速的限时移速增益（花荣 Q），两者相乘才不会互相覆盖
var _temp_move_boost_t := 0.0
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
var stat_owner_key := ""    # 驻守战统计归属：召唤物/幻象的伤害与击杀计入召唤英雄 key
# 三碗不过岗（武松 W）：移动/攻速在 [lo,hi] 间随机波动，按 _drunk_reroll 周期重掷
var _drunk_t := 0.0
var _drunk_lo := 1.0
var _drunk_hi := 1.0
var _drunk_reroll := 0.0
var _drunk_move := 1.0      # 当前随机移动倍率
var _drunk_atk := 1.0       # 当前随机攻速倍率
# 醉神大闹快活林（武松 R）：物理免疫 + 有效普攻叠攻/分裂 + 结束转血
var _phys_immune_t := 0.0
var _absorbed_phys := 0.0   # 物免期间被普通攻击「挡下」的累计伤害
var _drunk_god_bonus_per_hit := 0.0
var _drunk_god_stacks := 0
var _drunk_god_max_stacks := 5
var _drunk_god_cleave := 0.0
# 护甲削减（武松 E·双戒刀）：临时降低目标防御
var _def_down := 0.0
var _def_down_t := 0.0
# 致盲（武松 E·双戒刀附带）：>0 时本单位攻击必失（不结算伤害、不吸血）
var _blind_t := 0.0
# 概率障目（公孙胜 Q·黑雨）：与“攻击必失”的完全致盲分开计时，避免两种强度互相覆盖。
var _attack_miss_chance := 0.0
var _attack_miss_t := 0.0
# 通用减速光环：每帧由 _aura_pass 写入；<1 = 受敌方减速光环影响。slow_aura_r>0 时自身画光环环
var aura_slow := 1.0
var slow_aura_r := 0.0
# ===== DOTA 式新原语状态（护盾/沉默/攻速/暴击/闪避/攻击携带）=====
var _shield := 0.0          # 护盾吸收池：take_damage 先扣盾再扣血
var _shield_t := 0.0        # 护盾剩余时长（到点清盾）
var _silence_t := 0.0       # 沉默：>0 时不可主动施法（被动不受影响）
var _root_t := 0.0          # 缠绕：>0 时不能移动，但可以攻击/施法（DOTA root）
var _disarm_t := 0.0        # 缴械：>0 时不能普攻，但可以移动/施法（DOTA disarm）
var _taunt_t := 0.0         # 嘲讽：>0 时被迫攻击 _taunt_src（无视原目标/玩家指令/AI），优先级低于眩晕
var _taunt_src: Unit = null
var _channel_t := 0.0       # 引导施法：>0 时定身、不索敌/不普攻（battle._channel_pass 逐 tick 结算）；被眩晕/沉默打断
var _channel_dur := 0.0     # 引导总时长（画头顶引导进度条用）
var _invis_t := 0.0         # 主动隐身：>0 时不可被索敌/指向（己方半透可见），攻击/施法即破隐
var _invis_strike_bonus := 0.0   # 破隐首击的额外纯伤（进入隐身时设定）
var _invis_strike_pending := 0.0 # 已破隐、待下一击兑现的加成（_attack 设置 → _deal_hit 消费）
var _hex_t := 0.0           # 变形术(hex)：>0 时画"小猪替身"（沉默+缴械+减速由 apply_hex 一并挂上）
var _form_t := 0.0          # 变身(transform)：>0 时处于临时形态（燕顺狼形/朱仝龙形）——换攻/攻速/移速/体型/染色
var _form: Dictionary = {}       # 当前形态修正表（recompute 时叠加 atk/hp/射程；到期还原）
var _form_backup: Dictionary = {} # 进入变身前的原始 atk_cd/base_speed/radius/modulate（到期恢复）
var _order_serial := 0      # 指令序号：每次 _enqueue +1（walk-cast 用它检测「玩家又下了新令」即让路）
var temp_atkspeed := 1.0    # 临时攻速倍率（>1 出手更快），_attack 并入 _cd
var _temp_atkspeed_t := 0.0
var _attack_speed_slow := 1.0   # 敌方攻速压制（<1）；与自身攻速增益相乘，黑雨等控制不会被增益池吃掉
var _attack_speed_slow_t := 0.0
var _aura_atkspeed := 1.0   # 义旗等区域攻速光环；与普通限时攻速取较高者，不相乘
var _aura_atkspeed_sources: Dictionary = {}   # source_id → {mult,t}，重叠旗独立到期并正确降档
# 被动衍生（_recompute_hero_stats 每次先重置再按已学被动累加）
var atkspeed_mult := 1.0    # 被动攻速倍率
var crit_chance_bonus := 0.0
var crit_mult_bonus := 0.0  # 暴击倍率加成（叠加在基础 ×1.8 之上）
var evasion := 0.0          # 闪避概率（被攻击时整下闪开）
var _temp_evasion := 0.0    # 限时闪避（花荣 Q）；与被动闪避相加后封顶 95%
var _temp_evasion_t := 0.0
var bash_chance := 0.0      # 攻击附带眩晕概率
var bash_dur := 0.0
var on_hit_slow := 0.0      # 攻击附带减速（orb）
var on_hit_slow_dur := 0.0
var on_hit_dmg := 0.0       # 攻击附带额外纯伤
# 易伤（樊瑞 W·摄魂咒）：>0 时本单位受到的一切伤害放大 (1+_dmg_amp) 倍，到点失效
var _dmg_amp := 0.0
var _dmg_amp_t := 0.0
# 忠义旗等区域护阵：受到的一切伤害按比例减免；多个来源只取最高值，不叠乘。
var _damage_reduction := 0.0
var _damage_reduction_t := 0.0
var _damage_reduction_sources: Dictionary = {}   # source_id → {amount,t}，高阶旗离开后可正确降到仍生效的低阶旗
var _stats_mitigation_t := 0.0   # >0 时减伤挡下的数值也计入本英雄「承伤」（李逵 Q）
# 冲锋（李逵 W·矢量单击）：蓄力→猛冲，沿途撞伤。窗口期独立于普通状态机。
var _charge_t := 0.0        # 蓄力倒计时（>0 原地不动）
var _charge_dash := 0.0     # 冲刺剩余时长（>0 高速平移）
var _charge_dir := Vector2.ZERO
var _charge_dmg := 0.0
var _charge_slow := 0.0
var _charge_slow_dur := 0.0
var _charge_width := 50.0
var _charge_hit: Array = [] # 本次冲刺已撞过的单位（每人只撞一次）
var _charge_phys_immune := false   # 李逵 W：蓄力+冲刺窗口物理免疫；不复用武松物免转血
# 花荣 E·五连珠：接下来五次平攻锁定该目标并无视攻击距离；玩家下新命令仍可主动打断。
var _hua_lock_target: Unit = null
var _hua_lock_shots := 0
const HERO_MAX_LEVEL := 12   # 满级 12 → 共 12 技能点（4 技能 ×3 级，可全点满）

var _state := ST_IDLE
var _path := PackedVector2Array()
var _path_i := 0
var _amove_dest := Vector2.ZERO
var _resume_amove := false
var _target: Unit = null
var _chase_intent := CHASE_AUTO
var _group_cap := 0.0       # 成队行军时的速度上限（取队伍最慢成员），>0 时生效，让一队人不散开
var _home := Vector2.ZERO   # 玩家单位的驻守点：追击后自动归位
var _has_home := false
var _cd := 0.0
var _repath := 0.0
var _acq_t := 0.0           # 待机索敌限流计时（每 ~0.12s 重扫一次最近敌人，省得兵海每帧全员索敌）
var _flash := 0.0
var _muzzle_t := 0.0        # 防御塔开火闪光剩余时长（转向炮口闪一下）
var _tower_aim := Vector2i(1, 1)   # 防御塔当前朝向格(8 向图)；目标丢失后短暂保持，避免「攻击后朝向闪回正面」
var _tower_aim_hold := 0.0  # 朝向保持计时：>0 时即便暂无目标也维持上次开火方向
var _stuck_t := 0.0
var _idle_push_t := 0.0     # 进攻方(官军)呆住计时：闲置太久没目标 → 重新攻击移动压向聚义厅
var _eject_t := 0.0         # 建筑占地弹出检查限流（10Hz）：兜传送类落点落进占地
var _block_rp := 0.0        # 撞封格重寻节流：路径被新建筑截断时最多每 0.45s 重寻一次
var _burn_t := 0.0          # 建筑受损起火动画计时（血量<65% 起火苗，<35% 大火浓烟）
var manual_order_t := 0.0   # 手动指令保护期(秒)：>0 时托管 AI 不得覆盖玩家刚下的指令
var manual_order_active := false # 手动指令链未完成前，托管不得因固定超时抢回控制
var _move_retry := 0        # ST_MOVE/ST_AMOVE 路径耗尽重寻计数：同一地点反复重寻视为目的地不可达
var _move_retry_pos := Vector2.ZERO
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
var _cast_serial := 0       # 每次起手/打断递增；Battle 用它淘汰同帧迭代中的过期待结算项
var _weapon := -1          # 缓存武器类型
var _idle_t := 0.0         # 待机呼吸相位（恒进）
var _real_frames := false  # 当前状态是否在播放真·逐帧（用于压低程序化叠加）
var _animated_redraw_t := 0.0 # 兵海时受击/状态/死亡动画的重绘节流；移动动画仍逐帧
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
	_track_combat_stats = p_battle != null and bool(p_battle.get("track_hero_combat_stats"))
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
func order_move(pos: Vector2, queued := false, group_cap := 0.0) -> void:
	_enqueue({"kind": "move", "pos": pos, "group_cap": group_cap}, queued)


func order_attack(t: Unit, queued := false, explicit := false) -> void:
	if t == null:
		return
	_enqueue({"kind": "attack", "target": t, "explicit": explicit}, queued)


func order_amove(pos: Vector2, queued := false, group_cap := 0.0) -> void:
	_enqueue({"kind": "amove", "pos": pos, "group_cap": group_cap}, queued)


func order_gather(node: Unit, queued := false) -> void:
	if node == null:
		return
	_enqueue({"kind": "gather", "target": node}, queued)


## 停止/原地待命：清空指令、放弃目标、就地驻守（用于 S 键）
func order_stop() -> void:
	if is_building:
		return
	_cancel_hold_order()
	cancel_cast_windup()
	_queue.clear()
	_patrolling = false
	_target = null
	_clear_hua_lock()
	_resume_amove = false
	_chase_intent = CHASE_AUTO
	_group_cap = 0.0
	_home = position
	_has_home = true
	_path = PackedVector2Array()
	_state = ST_IDLE


## 经典 RTS 的 Hold Position：临时原地据守；下一条明确命令恢复进入 H 前的姿态。
func order_hold_position() -> void:
	if is_building or is_worker:
		return
	_cancel_hold_order()
	order_stop()
	_hold_prev_stance = stance
	stance = STANCE_HOLD
	_home = position
	_has_home = true
	_hold_order_active = true


## 巡逻：在当前位置与 pos 之间用「攻击移动」来回，沿途交战（用于 P 键）
func order_patrol(pos: Vector2) -> void:
	if is_building or is_worker:
		return
	_cancel_hold_order()
	_queue.clear()
	passive = false
	_patrol_a = position
	_patrol_b = pos
	_clear_hua_lock()
	_home = position
	_has_home = true
	_patrolling = true
	_begin_amove(pos)


func set_stance(s: int) -> void:
	if is_building or is_worker:
		return
	_hold_order_active = false
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
	_cancel_hold_order()
	# 普通指令会打断尚未结算的施法抬手；不允许移动后技能仍从原地“幽灵施放”。
	cancel_cast_windup()
	_order_serial += 1   # 新指令序号：walk-cast 据此发现「有人下了新令」而让路
	passive = false
	_patrolling = false   # 任何新明确指令都终止巡逻
	if not queued:
		_clear_hua_lock()   # 新的立即指令覆盖 E 的三箭锁定；Shift 排队不打断当前三箭
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
		manual_order_t = 0.0   # 手动指令自然执行完毕 → 立即解除托管保护，AI 无缝接管
		manual_order_active = false
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


func _cancel_hold_order() -> void:
	if not _hold_order_active:
		return
	stance = _hold_prev_stance
	_hold_order_active = false


func _begin_order(o: Dictionary) -> void:
	var kind := String(o.get("kind", ""))
	# 一条新移动命令获得独立的有限重试额度；内部重寻直接调用 _begin_move/_begin_amove，
	# 不会在不可达点每帧把额度重置，避免残兵反复跑 A* 拖垮整局。
	if kind == "move" or kind == "amove":
		_move_retry = 0
		_move_retry_pos = position
	match kind:
		"move": _begin_move(o["pos"])
		"amove": _begin_amove(o["pos"])
		"attack": _begin_attack(o["target"], bool(o.get("explicit", false)))
		"gather": _begin_gather(o["target"])
		"build": _begin_build(o["target"])
		"repair": _begin_repair(o["target"])
		"garrison": _begin_garrison(o["target"])
	if kind == "move" or kind == "amove":
		_group_cap = float(o.get("group_cap", 0.0))


# —— 原始指令（不动队列；供内部重发/回防/续采复用）——
func _begin_move(pos: Vector2) -> void:
	if is_building:
		return
	if _lunge > 0.0 and _pending_done:
		_lunge = 0.0   # 命中后的后摇可被移动取消，提升走A响应；未命中前仍不能白嫖伤害
	_target = null
	_resume_amove = false
	_chase_intent = CHASE_AUTO
	_group_cap = 0.0   # 每次新移动默认解除队伍限速；成队移动时由 _apply_group_cap 在下令后重设
	_home = pos
	_has_home = true
	_path = map.find_path(position, pos, faction)
	_path_i = 0
	_state = ST_MOVE


func _begin_attack(t: Unit, explicit := false) -> void:
	if is_building or t == null:
		return
	_target = t
	_resume_amove = false
	_chase_intent = CHASE_EXPLICIT if explicit else CHASE_AUTO
	_repath = 0.0
	_path = PackedVector2Array()
	_path_i = 0
	_state = ST_CHASE


func _begin_amove(pos: Vector2) -> void:
	if is_building:
		return
	if _lunge > 0.0 and _pending_done:
		_lunge = 0.0
	_target = null
	_amove_dest = pos
	_resume_amove = false
	_chase_intent = CHASE_AMOVE
	_group_cap = 0.0   # 同 _begin_move：默认解除限速，成队由 _apply_group_cap 重设
	_path = map.find_path(position, pos, faction)
	_path_i = 0
	_state = ST_AMOVE


func _begin_gather(node: Unit) -> void:
	if node == null or not is_instance_valid(node):
		_done_order()
		return
	_target = null
	_resume_amove = false
	_chase_intent = CHASE_AUTO
	_group_cap = 0.0   # 采集独立行动，解除队伍限速（与 _begin_move 一致）
	_gather_node = node
	_carry_kind = node.res_kind   # 出发即记住资源种类（节点被别人采空时据此就近补同类，而非乱采）
	if _carry_amt >= GATHER_CAP:
		_begin_return()
	else:
		_repath = 0.0
		_path = map.find_path(position, node.position, faction)
		_path_i = 0
		_state = ST_GATHER


func _begin_return() -> void:
	_drop = battle.nearest_dropoff(position, faction)   # 卸到自己阵营的卸货点
	if _drop == null:
		_done_order()   # 无卸货点（聚义厅/仓库都没了）：收工待命，避免空转
		return
	_repath = 0.0
	_path = map.find_path(position, _drop.position, faction)
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
	_path = map.find_path(position, site.position, faction)
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
	_path = map.find_path(position, bld.position, faction)
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
	_path = map.find_path(position, bld.position, faction)
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
			_path = map.find_path(position, bld.position, faction)
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


func take_damage(d: float, from: Unit = null, crit := false, ignore_reduction := false) -> void:
	if hp <= 0.0:
		return
	if _pending_build:
		return   # 工地虚影：尚未真正起建（工人未到），不可被攻击——「走过去再开始建造」后才挨打
	if garrisoned:
		return   # 驻军中：藏在建筑里受庇护，免疫伤害（飞行中的箭/范围技能也打不到；建筑被毁才弹出）
	var hp_before := hp
	var shield_absorbed := 0.0
	# DOTA 易伤：摄魂咒等令目标「受到伤害大增」——在扣盾/扣血前先把这一击整体放大
	if _dmg_amp > 0.0 and d > 0.0:
		d *= 1.0 + _dmg_amp
	var before_reduction := maxf(0.0, d)
	# 护阵减伤作用于普攻和技能等一切伤害；先结算易伤、再按最高减伤折算，随后才由护盾吸收。
	if not ignore_reduction and _damage_reduction > 0.0 and d > 0.0:
		d *= 1.0 - clampf(_damage_reduction, 0.0, 0.95)
	# DOTA 护盾：先扣吸收盾，剩余才扣血（盾扣空即失效）
	if _shield > 0.0 and d > 0.0:
		var _ab: float = minf(_shield, d)
		shield_absorbed = _ab
		_shield -= _ab
		d -= _ab
		_buff_glow = 1.0
		if _shield <= 0.0:
			_shield_t = 0.0
	# 战斗统计只计减伤后真正打到护盾/生命的数值，且不计溢出死亡血量的 overkill。
	var hp_damage := minf(hp_before, maxf(0.0, d))
	var effective_damage := shield_absorbed + hp_damage
	hp -= d
	if _track_combat_stats and effective_damage > 0.0:
		var attacker_relevant := from != null and is_instance_valid(from) \
				and from.faction == FACTION_LIANG and (from.is_hero or from.stat_owner_key != "")
		var victim_relevant := is_hero and faction == FACTION_LIANG
		if attacker_relevant or victim_relevant:
			battle.record_hero_combat_damage(self, from, effective_damage)
	# 李逵 Q 的承伤口径：实际扣盾/扣血仍按减伤后值；被该状态拦下的部分额外计入李逵承伤。
	# 敌方输出仍只记 effective_damage，避免同一笔免伤同时虚增输出数据。
	var mitigated := maxf(0.0, before_reduction - maxf(0.0, d + shield_absorbed))
	if _track_combat_stats and _stats_mitigation_t > 0.0 and mitigated > 0.0 \
			and is_hero and faction == FACTION_LIANG:
		battle.record_hero_combat_mitigation(self, mitigated)
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
			# 非资源建筑不留废墟：battle._on_unit_died 播放坍塌演出并释放节点，地面恢复如初（星际/红警式）。
			# 资源点（金矿/林木）保留旧染暗表现（枯竭另走 deplete_resource）。
			if is_resource:
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
	# 压测计时(PERF_BENCH)：把单位每帧逻辑耗时回填到 battle._unit_proc_us；正常游玩零开销
	if battle != null and battle._prof_on:
		var __t0 := Time.get_ticks_usec()
		_phys_body(delta)
		battle._unit_proc_us += Time.get_ticks_usec() - __t0
	else:
		_phys_body(delta)


func _queue_animated_redraw(interval := 0.08, force := false) -> void:
	if battle != null and battle._lite_fx and not battle.unit_visual_active(position):
		return
	if not force and battle != null and battle._lite_fx:
		if _animated_redraw_t > 0.0:
			return
		_animated_redraw_t = interval
	queue_redraw()


func _queue_motion_redraw() -> void:
	if battle != null and battle._lite_fx:
		if not battle.unit_visual_active(position):
			return
		if battle._mob_count > 260 and not selected:
			# 按 instance_id 把精灵重画均匀摊到不同物理帧，避免几百个单位同帧重画的尖峰。
			var stride := 3 if battle._mob_count > 500 else 2
			if get_instance_id() % stride != int(Engine.get_physics_frames()) % stride:
				return
			queue_redraw()
			return
	queue_redraw()


func _mass_visuals() -> bool:
	return battle != null and battle._mob_count > 320 and not selected and not is_hero and not is_building and not is_resource


func _ultra_mass_visuals() -> bool:
	return battle != null and battle._mob_count > 500 and not selected and not is_hero and not is_building and not is_resource


func _mass_status_visuals() -> bool:
	return battle != null and battle._lite_fx and not selected and not is_hero and not is_building and not is_resource


func _phys_body(delta: float) -> void:
	_animated_redraw_t = maxf(0.0, _animated_redraw_t - delta)
	if is_building:
		if hp <= 0.0:
			return   # 已被摧毁的建筑：停止一切活动（节点随后由主控释放；自检直接置 hp=0 时也安全）
		if not is_resource and not is_constructing and hp < max_hp * 0.65:
			_burn_t += delta   # 受损起火：驱动火苗/浓烟动画（仅受损建筑每帧重绘，常态零开销）
			_queue_animated_redraw()
		if not passengers.is_empty():
			for pg in passengers:   # 驻军缓慢回血（经典RTS式）
				if is_instance_valid(pg) and pg.hp > 0.0 and pg.hp < pg.max_hp:
					pg.hp = minf(pg.max_hp, pg.hp + 9.0 * delta)
		if atk > 0.0 and not is_resource and not is_constructing:
			_tower_tick(delta)   # 防御塔（箭楼）固定索敌射击
		if not is_constructing and not _train_queue.is_empty():
			_production_tick(delta)
		elif not is_constructing and _research_key != "":
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
			_queue_animated_redraw()
		return
	if _dying:
		_death_t += delta
		_queue_animated_redraw()
		if _death_t >= DEATH_DUR:
			queue_free()
		return
	if garrisoned:
		return   # 驻军中：藏在建筑里，停止一切活动（移动/索敌/动画）
	_cd = maxf(0.0, _cd - delta)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_queue_animated_redraw(0.08, _flash <= 0.0)

	# 梁山兵熟悉水泊、补给充足，脱战 6 秒后缓慢回血；官军远征无此待遇
	_combat_cool = maxf(0.0, _combat_cool - delta)
	_hit_recent_t = maxf(0.0, _hit_recent_t - delta)
	var regen := 0.0
	if faction == FACTION_LIANG and _combat_cool <= 0.0:
		regen += 2.5
	var passive_regen := _passive_regen()
	regen += passive_regen    # 被动回血（如宋江·仁义）：战斗中也生效
	if regen > 0.0 and hp < max_hp:
		var hp_before_regen := hp
		hp = minf(max_hp, hp + regen * delta)
		# 只把英雄被动产生的份额计入治疗；通用脱战补给不算英雄战绩。
		if _track_combat_stats and passive_regen > 0.0 and battle != null:
			var effective_regen := hp - hp_before_regen
			battle.record_hero_combat_healing(self, self, effective_regen * passive_regen / regen)
		queue_redraw()

	# 技能冷却/充能（各槽）与临时增益计时
	_tick_ability_slots(delta)
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
	if _temp_move_boost_t > 0.0:
		_temp_move_boost_t -= delta
		if _temp_move_boost_t <= 0.0:
			_temp_move_boost = 1.0
	if _temp_evasion_t > 0.0:
		_temp_evasion_t -= delta
		if _temp_evasion_t <= 0.0:
			_temp_evasion = 0.0
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
				heal(_absorbed_phys * 0.5, self)
				_buff_glow = 1.0
			_absorbed_phys = 0.0
			_drunk_god_bonus_per_hit = 0.0
			_drunk_god_stacks = 0
			_drunk_god_cleave = 0.0
	if _stats_mitigation_t > 0.0:
		_stats_mitigation_t = maxf(0.0, _stats_mitigation_t - delta)
	# 护甲削减计时
	if _def_down_t > 0.0:
		_def_down_t -= delta
		if _def_down_t <= 0.0:
			_def_down = 0.0
	# 致盲计时（武松 E）：期间攻击必失
	if _blind_t > 0.0:
		_blind_t -= delta
	# 概率障目计时（公孙胜 Q）：只影响普攻命中率，离开雨区后很快恢复。
	if _attack_miss_t > 0.0:
		_attack_miss_t -= delta
		if _attack_miss_t <= 0.0:
			_attack_miss_chance = 0.0
	# DOTA 原语计时：护盾 / 沉默 / 临时攻速
	if _shield_t > 0.0:
		_shield_t -= delta
		if _shield_t <= 0.0:
			_shield = 0.0
	if _silence_t > 0.0:
		_silence_t = maxf(0.0, _silence_t - delta)
	if _root_t > 0.0:
		_root_t = maxf(0.0, _root_t - delta)
		_queue_animated_redraw(0.08, _root_t <= 0.0)
	if _disarm_t > 0.0:
		_disarm_t = maxf(0.0, _disarm_t - delta)
		_queue_animated_redraw(0.08, _disarm_t <= 0.0)
	if _taunt_t > 0.0:
		_taunt_t = maxf(0.0, _taunt_t - delta)
		if _taunt_t <= 0.0 or _taunt_src == null or not is_instance_valid(_taunt_src) or _taunt_src.hp <= 0.0:
			_taunt_t = 0.0
			_taunt_src = null
			if _chase_intent == CHASE_FORCED:
				_chase_intent = CHASE_AUTO
		_queue_animated_redraw(0.08, _taunt_t <= 0.0)
	if _channel_t > 0.0:
		_channel_t = maxf(0.0, _channel_t - delta)
		_queue_animated_redraw(0.08, _channel_t <= 0.0)
	if _invis_t > 0.0:
		_invis_t = maxf(0.0, _invis_t - delta)
		if _invis_t <= 0.0:
			modulate.a = 1.0   # 隐身自然结束 → 现形（_stealth_pass 下一帧亦会校正）
		_queue_animated_redraw(0.08, _invis_t <= 0.0)
	if _hex_t > 0.0:
		_hex_t = maxf(0.0, _hex_t - delta)
		_queue_animated_redraw(0.08, _hex_t <= 0.0)
	if _form_t > 0.0:
		_form_t = maxf(0.0, _form_t - delta)
		if _form_t <= 0.0:
			_end_form()   # 变身到期 → 还原形态
		_queue_animated_redraw(0.08, _form_t <= 0.0)
	if _dmg_amp_t > 0.0:
		_dmg_amp_t -= delta
		if _dmg_amp_t <= 0.0:
			_dmg_amp = 0.0
	if not _damage_reduction_sources.is_empty():
		for source_id in _damage_reduction_sources.keys():
			var state: Dictionary = _damage_reduction_sources[source_id]
			state["t"] = float(state["t"]) - delta
			if float(state["t"]) <= 0.0:
				_damage_reduction_sources.erase(source_id)
		_refresh_damage_reduction()
	if _temp_atkspeed_t > 0.0:
		_temp_atkspeed_t -= delta
		if _temp_atkspeed_t <= 0.0:
			temp_atkspeed = 1.0
	if _attack_speed_slow_t > 0.0:
		_attack_speed_slow_t -= delta
		if _attack_speed_slow_t <= 0.0:
			_attack_speed_slow = 1.0
	if not _aura_atkspeed_sources.is_empty():
		for source_id in _aura_atkspeed_sources.keys():
			var aura_state: Dictionary = _aura_atkspeed_sources[source_id]
			aura_state["t"] = float(aura_state["t"]) - delta
			if float(aura_state["t"]) <= 0.0:
				_aura_atkspeed_sources.erase(source_id)
		_refresh_aura_atkspeed()
	# 限时召唤物：寿命到 → 消散
	if _summon_ttl > 0.0:
		_summon_ttl -= delta
		if _summon_ttl <= 0.0 and not _dying and hp > 0.0:
			_summon_ttl = 0.0
			if battle != null and battle.has_method("despawn_summon"):
				battle.despawn_summon(self)
	if _buff_glow > 0.0:
		_buff_glow = maxf(0.0, _buff_glow - delta)
		_queue_animated_redraw(0.08, _buff_glow <= 0.0)
	if _giveup_t > 0.0:
		_giveup_t = maxf(0.0, _giveup_t - delta)   # 追击放弃冷却：到点后可重新锁定旧目标
	if manual_order_t > 0.0:
		manual_order_t = maxf(0.0, manual_order_t - delta)

	# 星际/红警式硬占位兜底：机动单位若被「放」进建筑占地（出生/钩拽/闪现/直点建筑中心），
	# 弹出到占地外沿。寻路层本就把占地当 solid（走不进）；这里只兜传送类落点。10Hz 限流。
	_eject_t -= delta
	if _eject_t <= 0.0:
		_eject_t = 0.1
		if not is_building and not garrisoned and hp > 0.0 and battle != null:
			battle.eject_from_buildings(self)

	if _target != null and (not is_instance_valid(_target) or _target.hp <= 0.0 or _target.garrisoned \
			or _target._invis_t > 0.0 \
			or (battle != null and battle.has_method("target_visible_to") and not battle.target_visible_to(self, _target))):
		_target = null   # 目标若已驻入建筑（隐身无敌）→ 放弃追击
	if _hua_lock_target != null and (not is_instance_valid(_hua_lock_target) or _hua_lock_target.hp <= 0.0 \
			or _hua_lock_target.garrisoned or _hua_lock_target._invis_t > 0.0):
		_clear_hua_lock()
	# 施放其他技能会暂时清掉普通攻击目标；技能结束后若 E 的连珠箭尚未打完，就继续优先射原目标。
	if _target == null and hua_lock_active() and (battle == null or not battle.has_method("target_visible_to") \
			or battle.target_visible_to(self, _hua_lock_target)):
		_begin_attack(_hua_lock_target, false)

	# 引导施法（凌振轰天连炮等）：定身、不索敌/不移动/不普攻，逐 tick 结算由 battle._channel_pass 负责。
	# 计时递减已在上面 timer 段完成；被眩晕/沉默/拖走时 _break_channel 会清零本状态。
	if _channel_t > 0.0:
		_stepped = false
		_queue_animated_redraw()
		return

	# 普通施法抬手是正式动作状态：定身、停攻、停索敌；归零后的技能结算由 Battle 下一物理帧完成。
	if _cast_t > 0.0:
		_cast_t = maxf(0.0, _cast_t - delta)
		_stepped = false
		_queue_animated_redraw(0.08, _cast_t <= 0.0)
		return

	# 冲锋窗口（李逵 W）：优先于普通状态机。蓄力期原地，冲刺期高速平移撞伤。
	if _charge_t > 0.0 or _charge_dash > 0.0:
		_do_charge_step(delta)
		return

	if _stun_t > 0.0:
		_stun_t = maxf(0.0, _stun_t - delta)   # 眩晕（踩地板）：呆立，本帧不索敌/不移动/不攻击
		_queue_animated_redraw(0.08, _stun_t <= 0.0)
	else:
		# 嘲讽(taunt)：dur 内强制锁定并攻击 _taunt_src，压过玩家指令与 AI 大脑（仅上面的眩晕能盖过）
		if _taunt_t > 0.0 and _taunt_src != null and is_instance_valid(_taunt_src) and _taunt_src.hp > 0.0 and _target != _taunt_src:
			_target = _taunt_src
			_chase_intent = CHASE_FORCED
			_state = ST_CHASE
		match _state:
			ST_IDLE:
				if not passive and not is_worker:   # 工人不主动索敌（经典RTS式村民）
					_acq_t -= delta
					if _acq_t <= 0.0:
						_acq_t = 0.04 if (battle != null and battle.selection.has(self)) else 0.12
						_acquire()
				if _target != null:
					_chase_intent = CHASE_AUTO
					if not _has_home:
						_home = position
						_has_home = true
					_repath = 0.0
					_idle_push_t = 0.0
					_state = ST_CHASE
				elif faction == FACTION_GUAN and _amove_dest != Vector2.ZERO and battle != null:
					# 进攻方呆住看门狗：没目标却停在原地超 2.5s → 重新攻击移动压向聚义厅，半路遇我方单位就接着打
					_idle_push_t += delta
					if _idle_push_t > 2.5:
						_idle_push_t = 0.0
						var hall = battle.main_base(FACTION_LIANG)
						var dest: Vector2 = hall.position if (hall != null and is_instance_valid(hall)) else _amove_dest
						order_amove(dest)
			ST_MOVE:
				if _follow_path(delta):
					# 路径提前耗尽但离目的地还远（被挤出路线/跳点吃光路径导致截断）→ 重新寻路续走。
					# 与 ST_AMOVE 同款兜底；否则半路转 IDLE 被待机索敌勾走，表现为「走一半回头打两下」。
					if position.distance_to(_move_retry_pos) > 24.0:
						_move_retry = 0   # 有实际推进 → 重置计数（长途拥挤行军允许多次重寻）
					if _has_home and position.distance_to(_home) > 70.0 and _move_retry < 3:
						_move_retry += 1
						_move_retry_pos = position
						var mh := _home
						_begin_move(mh)
					else:
						_done_order()
			ST_AMOVE:
				if _target == null:
					# A 移动时收紧索敌半径，但保留足够侧翼宽度；否则往一个方向 A 地板时，
					# 侧边敌人擦身接敌却没进窄扫描圈，会表现成“接敌但不打”。
					# 限流 ~8 次/秒：兵海里大量「无目标 A 移动」单位每帧重扫，是索敌开销的最大头。
					_acq_t -= delta
					if (battle != null and battle._no_opt) or _acq_t <= 0.0:
						_acq_t = 0.04 if (battle != null and battle.selection.has(self)) else 0.12
						_acquire(maxf(atk_range + radius + 56.0, 180.0), true)
				if _target != null:
					_resume_amove = true
					_chase_intent = CHASE_AMOVE
					_repath = 0.0
					_state = ST_CHASE
				elif _follow_path(delta):
					# 路径走完但离目的地还远（被挤出路线/目的地不可达）→ 有限重寻。
					# 原逻辑会在空路径时每物理帧重跑 A*；末波几个卡墙残兵就能把帧率压垮。
					if position.distance_to(_move_retry_pos) > 24.0:
						_move_retry = 0
					if position.distance_to(_amove_dest) > 70.0 and _move_retry < 3:
						_move_retry += 1
						_move_retry_pos = position
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
		_queue_motion_redraw()
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
		_queue_animated_redraw(0.08, _flinch == Vector2.ZERO)
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
						# 整体重寻而非跳点：跳点会把路径吃光、半路「视为到达」转 IDLE（回头打的引信）
						if _has_home:
							var wh := _home
							_begin_move(wh)
						else:
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
		# 玩家点名目标结束后直接完成该命令并接下一条队列，不绕回旧驻守点。
		if _chase_intent == CHASE_EXPLICIT or _chase_intent == CHASE_FORCED:
			_chase_intent = CHASE_AUTO
			_done_order()
			return
		# 自动接敌目标没了：A 移动继续前进，普通警戒接敌回驻守点。
		if _resume_amove:
			_begin_amove(_amove_dest)
		elif _chase_intent == CHASE_AUTO and _has_home and position.distance_to(_home) > 30.0:
			var h := _home
			_begin_move(h)
			_home = h
		elif is_worker and _gather_node != null and is_instance_valid(_gather_node) and _gather_node.res_left > 0.0:
			_begin_gather(_gather_node)   # 工人反击退敌后续采
		else:
			_done_order()
		return
	var hua_locked := has_hua_locked_attack(_target)
	# 牵引距离：进攻=320 远追；守备=150 短追；据守=只在攻击范围内（绝不挪）
	var leash := 320.0
	if stance == STANCE_DEFEND:
		leash = 150.0
	elif stance == STANCE_HOLD:
		leash = atk_range + radius + 18.0
	# 玩家单位（或任何非进攻姿态单位）追击过远则脱离、回防，防止被引离阵地
	# 例外：托管(auto_micro)且进攻姿态的英雄不受牵引——主动压上交战、退守交给托管大脑
	if not hua_locked and _chase_intent == CHASE_AUTO and _has_home and not _resume_amove and not (auto_micro and stance == STANCE_AGGRO) \
			and (faction == FACTION_LIANG or stance != STANCE_AGGRO) \
			and position.distance_to(_home) > leash:
		_target = null
		var h2 := _home
		_begin_move(h2)
		_home = h2
		return
	var d := position.distance_to(_target.position)
	var reach := atk_range + radius + _target.radius
	if d <= reach or hua_locked:
		_chase_t = 0.0   # 已进攻击范围（咬住了）：追击计时清零
		_face_dir(_target.position - position)
		if _cd <= 0.0:
			_attack()
	elif stance == STANCE_HOLD and _chase_intent != CHASE_EXPLICIT and _chase_intent != CHASE_FORCED:
		# 据守：目标跑出攻击范围就放手，原地不动，不追
		_target = null
		_done_order()
	else:
		# 追不上判定：连续追同一目标却始终够不着 → 超时放手（对方更快则更早放弃），
		# 拉黑该目标 GIVEUP_COOLDOWN 秒并就近重新索敌，免得一路追死/被旁敌砍死。
		_chase_t += delta
		var can_give_up := _chase_intent == CHASE_AUTO or _chase_intent == CHASE_AMOVE
		var cap: float = CHASE_GIVEUP_FAST if _target.current_move_speed() > current_move_speed() + 1.0 else CHASE_GIVEUP
		# 玩家点名攻击不因“目标更快”自行改令；只有目标连续不可达才结束，避免永远撞墙。
		var unreachable_explicit := _chase_intent == CHASE_EXPLICIT and _path.is_empty() and _chase_t >= 3.5
		if (can_give_up and _chase_t >= cap) or unreachable_explicit:
			_giveup_id = _target.get_instance_id()
			_giveup_t = GIVEUP_COOLDOWN
			_target = null
			_chase_t = 0.0
			if can_give_up and not passive and not is_worker and stance != STANCE_PASSIVE:
				_acquire()   # 立刻改打就近威胁（_acquire 会跳过刚拉黑的目标）
			if _target == null:
				if _resume_amove:
					_begin_amove(_amove_dest)
				else:
					_done_order()
			return
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.4
			_path = map.find_path(position, _target.position, faction)
			_path_i = 0
		_follow_path(delta)


## 采集：走到资源点→采满或采空→回卸货点（ST_RETURN）
## 这座金矿此刻是否正被「别的」农民占用（在矿口实地开采）。自校验：占用者一旦离开矿口
## （转返还/移动/阵亡/改采别处）即自动判定为空——无需在各处显式释放，杜绝占位泄漏。
func gold_busy(w: Unit) -> bool:
	var m := _gold_miner
	var active := m != null and is_instance_valid(m) and m.hp > 0.0 \
		and m._gather_node == self and m._state == ST_GATHER \
		and m.position.distance_to(position) <= radius + m.radius + 14.0
	if not active:
		_gold_miner = null
	while not _gold_waiters.is_empty():
		var q = _gold_waiters[0]
		if q != null and is_instance_valid(q) and q.hp > 0.0 and q._gather_node == self and q._state == ST_GATHER:
			break
		_gold_waiters.pop_front()
	if _gold_miner == w:
		return false
	if not _gold_waiters.has(w):
		_gold_waiters.append(w)
	return _gold_miner != null or (_gold_waiters[0] != w)


func _do_gather(delta: float) -> void:
	if _gather_node == null or not is_instance_valid(_gather_node) or _gather_node.res_left <= 0.0:
		var n: Unit = battle.nearest_resource(position, _carry_kind)
		if n != null:
			_gather_node = n
			_repath = 0.0
			_path = map.find_path(position, n.position, faction)
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
				_path = map.find_path(position, other.position, faction)
				_path_i = 0
			else:
				_face_dir(_gather_node.position - position)   # 排队：面向矿口待命
			return
		if _gather_node.res_kind == "gold":
			_gather_node._gold_miner = self   # 占住矿口（独占开采）
			_gather_node._gold_waiters.erase(self)
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
			_path = map.find_path(position, _gather_node.position, faction)
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
		_path = map.find_path(position, _drop.position, faction)
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
			_path = map.find_path(position, _drop.position, faction)
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
			_path = map.find_path(position, _build_site.position, faction)
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
		# 维修费改以木为主（金是全程瓶颈、木后期积压）：金份额只摊造价 15%，省下的 25% 金份额
		# 折成木支付，木本身仍按 40% 摊——总耗材价值不变，大头落在木上，给后期木头一个刚性去向。
		_repair_g += float(bld.setup_def.get("cost_gold", 0)) * 0.15 / maxf(bld.max_hp, 1.0) * dh
		_repair_w += (float(bld.setup_def.get("cost_wood", 0)) * 0.4 + float(bld.setup_def.get("cost_gold", 0)) * 0.25) \
			/ maxf(bld.max_hp, 1.0) * dh
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
			_path = map.find_path(position, bld.position, faction)
			_path_i = 0
		_follow_path(delta)


## 建筑施工推进（在建筑单位上调用；多个工人各加 delta → 经典RTS式加速）
func advance_build(delta: float) -> void:
	if not is_constructing:
		return
	if _pending_build:
		# 工人走到、起第一锤：虚影 → 实体工地。此刻才封路 + 立基（之前都是「虚的」，可被穿过、不可被攻击）。
		_pending_build = false
		if battle != null and battle.has_method("register_building_footprint"):
			battle.register_building_footprint(self)
		hp = max_hp * 0.1
		queue_redraw()
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
			_train_t = battle.train_time_for(_train_queue[0])


## 防御塔：固定索敌，冷却到就开火。读 setup_def 实现各塔特化：
##   target_priority=="hero" → 优先索敌敌方英雄（五雷法坛）；bonus_hero → 命中英雄倍伤；
##   splash → 落点溅射（霹雳炮）；slow_mult/slow_dur → 命中减速（拒马）。
func _tower_tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_muzzle_t = maxf(0.0, _muzzle_t - delta)
	_tower_aim_hold = maxf(0.0, _tower_aim_hold - delta)
	if _target != null and (not is_instance_valid(_target) or _target.hp <= 0.0 or _target.garrisoned \
			or _target._invis_t > 0.0 or position.distance_to(_target.position) > atk_range + 60.0 \
			or (battle != null and battle.has_method("target_visible_to") and not battle.target_visible_to(self, _target))):
		_target = null
	if _target == null:
		if String(setup_def.get("target_priority", "")) == "hero":
			_tower_acquire_hero()   # 法坛：先锁英雄
		if _target == null:
			_acquire()              # 无英雄(或非法坛)→ 取最近
	if _target != null:
		_tower_aim = _dir8_cell(_target.position - position)   # 有目标→朝向跟随
		_tower_aim_hold = 0.55                                  # 持续顶满保持时间；目标丢失后才开始倒数
		var reach := atk_range + _target.radius
		if position.distance_to(_target.position) <= reach and _cd <= 0.0:
			_cd = atk_cd
			var dmg := atk * buff_atk
			if _target.is_hero:
				dmg *= float(setup_def.get("bonus_hero", 1.0))   # 法坛对英雄 3×
			var sp := float(setup_def.get("splash", 0.0))         # 霹雳炮溅射
			var sm := float(setup_def.get("slow_mult", 1.0))      # 拒马减速倍率
			var sd := float(setup_def.get("slow_dur", 0.0))       # 拒马减速时长
			battle.spawn_projectile(self, _target, dmg, false, sp, sm, sd)
			_muzzle_t = 0.18                                       # 炮口闪光（朝目标方向，转向开火感）
			# 驻军增援：每个驻入的远程兵额外放一箭（经典RTS式 garrison-fire）
			for pg in passengers:
				if is_instance_valid(pg) and pg.is_ranged and pg.hp > 0.0:
					battle.spawn_projectile(self, _target, pg.atk * 0.85)


## 五雷法坛专用索敌：警戒范围内优先取最近的「敌方英雄」；无英雄则留空(交回 _acquire 取最近)。
func _tower_acquire_hero() -> void:
	var best: Unit = null
	var best_d := INF
	var cap: float = maxf(aggro_range, atk_range)
	for u in battle.units_near(position, cap):
		if u == self or not is_instance_valid(u) or u.faction == faction or u.hp <= 0.0 \
				or not u.is_hero or u.garrisoned or u.is_captive:
			continue
		var d: float = position.distance_to(u.position)
		if d <= cap and d < best_d:
			best = u
			best_d = d
	_target = best


## 发起一次攻击：起手挥击动画，伤害延后到挥击命中瞬间结算（含起手预备）
func _attack() -> void:
	if _disarm_t > 0.0:
		return   # 缴械：出不了手（可移动/施法；_cd 不重置，解除后立刻能打）
	if _invis_t > 0.0:
		_invis_strike_pending = _invis_strike_bonus   # 破隐突袭：这一击兑现加成
		_break_invis()
	_cd = atk_cd / maxf(_drunk_atk * maxf(temp_atkspeed, _aura_atkspeed) * atkspeed_mult * _attack_speed_slow, 0.1)   # 增益取高值，再乘醉酒/被动与敌方攻速压制
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
	# 近战伤害点到来前目标已经脱离武器范围，则这一刀落空；避免隔着数个身位“粘住”命中。
	if not is_ranged and position.distance_to(t.position) > atk_range + radius + t.radius + 8.0:
		return
	# E 锁定的是「接下来五次普攻」而非五次命中：箭一旦撒放，即使被致盲/闪避也消耗一发。
	_consume_hua_locked_attack(t)
	# 致盲（武松 E·双戒刀）：本单位攻击必失——不结算伤害、不发射弹丸、不吸血，仅一记落空火花
	if _blind_t > 0.0:
		if battle != null and battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position + Vector2(0, -4), false)
		Sfx.play(_attack_sfx_name(), -11.0, 0.2, 45)
		return
	# 黑雨障目：按当前概率令这次普攻落空；技能伤害不受影响。
	if _attack_miss_t > 0.0 and randf() < _attack_miss_chance:
		if battle != null and battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position + Vector2(0, -4), false)
		Sfx.play(_attack_sfx_name(), -11.0, 0.2, 45)
		return
	# 闪避（被动）：目标有几率整下闪开普攻（建筑/资源不闪）
	var target_evasion := t.current_evasion()
	if target_evasion > 0.0 and not t.is_building and not t.is_resource and randf() < target_evasion:
		if battle != null and battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position + Vector2(0, -4), false)
		Sfx.play(_attack_sfx_name(), -10.0, 0.2, 55)
		return
	# 武松 R：只有真正能落到活体战斗单位上的近战普攻才叠层；致盲、闪避、物免和建筑均不叠。
	# 先叠后算，所以当前这一刀立即吃到新增攻击，随后分裂也沿用同一层数。
	var wu_god_hit := key == "wu_song" and _phys_immune_t > 0.0 and not is_ranged \
			and not t.is_building and not t.is_resource and not t.is_captive and not t.is_phys_immune()
	if wu_god_hit:
		_drunk_god_stacks = mini(_drunk_god_max_stacks, _drunk_god_stacks + 1)
		_buff_glow = 1.0
	var dmg := atk * buff_atk * temp_atk + temp_atk_add + _drunk_god_bonus_per_hit * float(_drunk_god_stacks)
	if _invis_strike_pending > 0.0:
		dmg += _invis_strike_pending   # 破隐第一击加成（隐身潜行后突袭）
		_invis_strike_pending = 0.0
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
	var crit := not t.is_building and not t.is_resource and randf() < clampf((0.25 if is_hero else 0.12) + crit_chance_bonus, 0.0, 1.0)
	if crit:
		dmg *= 1.8 + crit_mult_bonus
	# 目标防御值：每点 +5% 等效血量 → 伤害 ÷(1+0.05·防御)。仅普通攻击在此减；技能走 take_damage 不经过这里。
	# 护甲削减（双戒刀）：有效防御 = 防御 − _def_down
	var eff_def := maxf(0.0, t.defense - t._def_down)
	if eff_def > 0.0:
		dmg /= (1.0 + 0.05 * eff_def)
	# 李逵 E·蛮力：每次有效普攻只掷一次概率；飞斧自身直接结算伤害，不会递归触发本被动。
	_try_li_brawn_axes()
	if is_ranged:
		battle.spawn_projectile(self, t, dmg, crit, float(setup_def.get("splash", 0.0)))
		Sfx.play(_attack_sfx_name(), -5.0, 0.14, 95)
	elif t.is_phys_immune():
		# 醉神·物理免疫：普通攻击被挡下，累计转血量；不结算伤害、不吸血
		t.absorb_physical_damage(dmg, self)
		if battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position, false)
		Sfx.play(_attack_sfx_name(), -8.0, 0.14, 60)
	else:
		t.take_damage(dmg, self, crit)
		if wu_god_hit and _drunk_god_cleave > 0.0 and battle.has_method("spawn_wu_cleave"):
			battle.spawn_wu_cleave(self, t, _drunk_god_cleave)
		# 攻击携带（orb/被动）：额外纯伤 / 减速 / 几率眩晕
		if on_hit_dmg > 0.0:
			t.take_damage(on_hit_dmg, self)
		if on_hit_slow > 0.0:
			t.apply_slow(on_hit_slow, on_hit_slow_dur)
		if bash_chance > 0.0 and not t.is_building and not t.is_resource and randf() < bash_chance:
			t.apply_stun(bash_dur)
		var ls := lifesteal_frac()
		if ls > 0.0:
			heal(dmg * ls, self)
		# 林冲·猎骑被动：打骑兵 cav_ls_chance 几率额外吸血 cav_ls_frac×伤害
		if cav_ls_chance > 0.0 and not t.is_building and not t.is_resource and randf() < cav_ls_chance:
			heal(dmg * (cav_ls_frac if t.is_cavalry else cav_ls_frac * 0.5), self)   # 打骑兵满额、非骑兵半额
			_buff_glow = 1.0
		if battle.has_method("spawn_impact"):
			battle.spawn_impact(t.position, _swing_kind == WK.AXE or crit)
		Sfx.play(_attack_sfx_name(), -4.0, 0.14, 75)


## 一次不含暴击/破隐、但包含兵种相克与目标护甲的普通攻击伤害。
## 李逵「蛮力」飞斧对每个目标分别调用，避免拿主目标的骑兵/护甲系数套给整圈敌人。
func secondary_basic_damage_against(t: Unit) -> float:
	if t == null or not is_instance_valid(t):
		return 0.0
	var dmg := atk * buff_atk * temp_atk + temp_atk_add + _drunk_god_bonus_per_hit * float(_drunk_god_stacks)
	if t.is_cavalry:
		dmg *= bonus_vs_cav
	if not t.is_building and not t.is_resource:
		dmg *= _counter_mult(t)
	if t.key == "arrow_tower" and setup_def.has("vs_tower"):
		dmg *= float(setup_def["vs_tower"])
	if t.is_building and setup_def.has("vs_building"):
		dmg *= float(setup_def["vs_building"])
	if t.is_hero and setup_def.has("vs_hero"):
		dmg *= float(setup_def["vs_hero"])
	var eff_def := maxf(0.0, t.defense - t._def_down)
	if eff_def > 0.0:
		dmg /= (1.0 + 0.05 * eff_def)
	return dmg


## 李逵「蛮力」飞斧判定。proc_roll 仅供确定性自检注入；正常攻击传 -1 使用随机数。
func _try_li_brawn_axes(proc_roll := -1.0):
	if battle == null or not battle.has_method("spawn_li_brawn_axes"):
		return null
	for i in ability_slots.size():
		var s: Dictionary = ability_slots[i]
		if String(s.get("id", "")) != "li_brawn" or int(s.get("rank", 0)) <= 0:
			continue
		var eff: Dictionary = _slot_def(i).get("effect", {})
		var chance := float(eff.get("axe_chance", 0.0))
		var roll := randf() if proc_roll < 0.0 else proc_roll
		if chance > 0.0 and roll < chance:
			return battle.spawn_li_brawn_axes(self, float(eff.get("axe_radius", 120.0)), String(eff.get("axe_art", "axe")))
		return null
	return null


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


func _acquire(range_override := -1.0, closest_first := false) -> void:
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
	var best_s := -INF
	# 只在网格邻近格里找(按警戒/据守半径粗筛)——不再每帧全表扫描，是兵海索敌卡顿的主因之一。
	for u in battle.units_near(position, range_cap):
		# 资源点（金矿/林木）不是攻击目标——否则敌人冲过来一直砍树；
		# 被绑缚待救者（captive）亦非攻击目标——否则刽子手会在救援前先把人砍死。
		if u == self or not is_instance_valid(u) or u.faction == faction or u.hp <= 0.0 \
				or u.is_resource or u.garrisoned or u.is_captive or u._pending_build or chase_blocked(u):
			continue
		if u._invis_t > 0.0:
			continue   # 主动隐身：完全不可索敌（出手/施法才现形）
		if battle != null and battle.has_method("target_visible_to") and not battle.target_visible_to(self, u):
			continue
		var d: float = position.distance_to(u.position)
		var limit := range_cap
		if u.hidden_in_reeds:
			limit = minf(limit, 75.0)  # 芦苇荡里的伏兵很难被发现
		if d > limit:
			continue
		var score := (-d + (24.0 if u == _target else 0.0)) if closest_first else _target_score(u, d)
		if score > best_s:
			best = u
			best_s = score
	_target = best


## 待机自动索敌的软优先级。权重刻意小于一个近战身位，避免越过眼前敌人追远处英雄。
func _target_score(u: Unit, d: float) -> float:
	var s := -d
	if u._target == self:
		s += 52.0   # 正在攻击自己的敌人优先还手
	if u.is_hero:
		s += 28.0
	elif String(u.key).begins_with("siege"):
		s += 34.0
	elif u.is_ranged:
		s += 14.0
	s += (1.0 - clampf(u.hp / maxf(u.max_hp, 1.0), 0.0, 1.0)) * 24.0
	if u == _target:
		s += 30.0
	if battle != null and not u.is_hero:
		# 集火人数走 battle 每帧统计的全局表(O(1))——此前逐候选扫邻格是 O(候选×邻居)，兵海下正是索敌卡顿的老路
		var already := int(battle._focus_counts.get(u.get_instance_id(), 0))
		if u == _target:
			already -= 1   # 自己当前锁定的不算「别人集火」
		s -= float(clampi(already, 0, 6)) * 8.0
	return s


func current_move_speed(at := Vector2.INF) -> float:
	var p: Vector2 = position if at == Vector2.INF else at
	var terrain := map.speed_mult_at(p, faction) if map != null else 1.0
	return base_speed * buff_speed * temp_speed * _temp_move_boost * _drunk_move * aura_slow * MOVE_SCALE * terrain


## 当前普攻闪避率：被动与限时身法相加，统一从这里读取，避免临时效果污染英雄永久属性重算。
func current_evasion() -> float:
	return clampf(evasion + _temp_evasion, 0.0, 0.95)


func _follow_path(delta: float) -> bool:
	if _root_t > 0.0:
		_stepped = false
		return false   # 缠绕：原地定身（不吃掉路点、不算到达），可照常攻击/施法
	if _path_i >= _path.size():
		return true
	var wp := _path[_path_i]
	var dir := wp - position
	var dist := dir.length()
	var sp := current_move_speed()
	if _group_cap > 0.0 and (_state == ST_MOVE or _state == ST_AMOVE):
		sp = minf(sp, _group_cap)   # _group_cap 是下令时队伍最慢成员的实际速度上限
	var step := sp * delta
	# 中间路点到达半径放宽：被挤开时不必精确踩点（精确踩点会和挤开逻辑互相拉锯）
	var arrive := maxf(step, 4.0) if _path_i >= _path.size() - 1 else 14.0
	if dist <= arrive:
		if _path_i >= _path.size() - 1:
			# 终点被敌方身体占住时视作已到邻接位，不把最后几像素硬吸进对方体内。
			if map.is_open_world(wp) and (battle == null or not battle.has_method("can_unit_step") or battle.can_unit_step(self, wp)):
				position = wp
		_path_i += 1
		return _path_i >= _path.size()
	var next := position + dir / dist * step
	_face_dir(dir)
	var next_map_open := map.is_open_world(next)
	var next_body_open: bool = next_map_open and (battle == null or not battle.has_method("can_unit_step") or battle.can_unit_step(self, next))
	if next_body_open:
		position = next
		_stepped = true
	else:
		# 静态封格与动态身体分开处理：都先贴边滑；只有建筑/地形真封路才重算 AStar。
		# 动态单位不在 AStar 里，反复重寻同一条静态路径只会制造 CPU 峰值，交给分离和卡死看门狗即可。
		var nx := Vector2(next.x, position.y)
		var ny := Vector2(position.x, next.y)
		var nx_map_open := absf(dir.x) > 0.5 and map.is_open_world(nx)
		var ny_map_open := absf(dir.y) > 0.5 and map.is_open_world(ny)
		var nx_body_open: bool = nx_map_open and (battle == null or not battle.has_method("can_unit_step") or battle.can_unit_step(self, nx))
		var ny_body_open: bool = ny_map_open and (battle == null or not battle.has_method("can_unit_step") or battle.can_unit_step(self, ny))
		if nx_body_open:
			position = nx
			_stepped = true
		elif ny_body_open:
			position = ny
			_stepped = true
		elif not next_map_open or (not nx_map_open and not ny_map_open):
			_block_rp -= delta
			if _block_rp <= 0.0:
				_block_rp = 0.45   # 重寻节流：封死路段最多每 0.45s 重算一次
				_path = map.find_path(position, _path[_path.size() - 1], faction)
				_path_i = 0
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

## 普通技能走 cd_t；多充能技能另走 charges/recharge_t，保留 cd_t 作为关卡/测试的硬锁。
## 第二次施放不会重置已经进行中的恢复，按标准顺序在第 10/20 秒各补回一点。
func _tick_ability_slots(delta: float) -> void:
	for i in ability_slots.size():
		var s: Dictionary = ability_slots[i]
		if float(s.get("cd_t", 0.0)) > 0.0:
			s["cd_t"] = maxf(0.0, float(s["cd_t"]) - delta)
		var max_charges := slot_max_charges(i)
		if max_charges <= 0:
			continue
		var charges := clampi(int(s.get("charges", max_charges)), 0, max_charges)
		if charges >= max_charges:
			s["charges"] = max_charges
			s["recharge_t"] = 0.0
			continue
		var recovery := slot_charge_recovery(i)
		if recovery <= 0.0:
			continue
		var recharge_t := float(s.get("recharge_t", 0.0))
		if recharge_t <= 0.0:
			recharge_t = recovery
		recharge_t -= delta
		while recharge_t <= 0.0 and charges < max_charges:
			charges += 1
			if charges < max_charges:
				recharge_t += recovery
			else:
				recharge_t = 0.0
		s["charges"] = charges
		s["recharge_t"] = recharge_t


## 建立技能槽：自由模式英雄用 abilities 全套(未学习)；其余用单 ability(默认满级可用)
func _init_ability_slots(def: Dictionary) -> void:
	ability_slots.clear()
	_hero_leveled = battle != null and battle.economy
	# 关卡指定的英雄初始技能等级：>0 且有 4 技能组 ⇒ 一出场满配该等级、无需加点。
	# 战役默认 2(换上对应 DOTA 英雄的 4 技能)、竞技场 3(满级随便放)、1v1/驻守战 0(走原经验加点)。
	var start_rank := 2
	if battle != null and battle.level != null and battle.level.has_method("hero_start_rank"):
		start_rank = int(battle.level.hero_start_rank())
	var fixed_kit: bool = start_rank > 0 and def.has("abilities")
	var ids: Array = []
	if fixed_kit:
		ids = def["abilities"]
		_hero_leveled = false              # 固定等级模式：不走经验加点(即便竞技场是经济模式)
	elif _hero_leveled and def.has("abilities"):
		ids = def["abilities"]             # 1v1/驻守战：经验升级学技能
	elif String(def.get("ability", "")) != "":
		ids = [def["ability"]]
	for id in ids:
		# 优先取本场战斗的(可能被场景/内容包覆盖的)技能表，使本场景新增/改过的技能也能正确建槽
		var ad: Dictionary = (battle._abilities.get(id, {}) if (battle != null and id in battle._abilities) else Defs.ABILITIES.get(id, {}))
		var r := 1
		if fixed_kit:
			r = start_rank
		elif _hero_leveled:
			r = 0
		var max_charges := maxi(0, int(ad.get("max_charges", 0)))
		ability_slots.append({"id": String(id), "rank": r,
			"cd_t": 0.0, "passive": bool(ad.get("passive", false)),
			"charges": max_charges, "recharge_t": 0.0, "cast_seq": 0})
	if _hero_leveled:
		hero_level = 1
		skill_points = 1
		hero_xp = 0.0
	if not ability_slots.is_empty():
		ability = String(ability_slots[0]["id"])
	_recompute_hero_stats()


func slot_count() -> int:
	return ability_slots.size()


## 英雄倍率(改变倍率开启 + 你方英雄)：n=clamp(Campaign.hero_mult,1,3)，1=不变。放大技能范围/CD/伤害/血量。
## 只在会同步放大敌方的模式生效（驻守/自定义据守/竞技场）——修「驻守战开过倍率后进 1v1，
## 玩家英雄仍单方面吃 1~3 倍加成而 AI 不吃」的跨模式泄漏。
func hero_boost_n() -> float:
	if not is_hero or faction != FACTION_LIANG or not Campaign.scale_on:
		return 1.0
	if not (Campaign.skirmish or Campaign.custom_defense or Campaign.arena):
		return 1.0
	return clampf(float(Campaign.hero_mult), 1.0, 3.0)


func _slot_def(i: int) -> Dictionary:
	if i < 0 or i >= ability_slots.size():
		return {}
	var aid := String(ability_slots[i].get("id", ""))
	if battle != null and aid in battle._abilities:
		return battle._abilities[aid]
	return Defs.ABILITIES.get(aid, {})


func slot_max_charges(i: int) -> int:
	return maxi(0, int(_slot_def(i).get("max_charges", 0)))


func slot_charges(i: int) -> int:
	var maximum := slot_max_charges(i)
	if maximum <= 0 or i < 0 or i >= ability_slots.size():
		return 0
	return clampi(int(ability_slots[i].get("charges", maximum)), 0, maximum)


func slot_charge_recovery(i: int) -> float:
	return maxf(0.0, float(_slot_def(i).get("charge_recovery", 0.0)))


func slot_recharge_left(i: int) -> float:
	if slot_max_charges(i) <= 0 or i < 0 or i >= ability_slots.size():
		return 0.0
	return maxf(0.0, float(ability_slots[i].get("recharge_t", 0.0)))


func slot_cast_sequence(i: int) -> int:
	if i < 0 or i >= ability_slots.size():
		return 0
	return maxi(0, int(ability_slots[i].get("cast_seq", 0)))


func _slot_cd(i: int) -> float:
	if i < 0 or i >= ability_slots.size():
		return 0.0
	var ad: Dictionary = _slot_def(i)
	if int(ad.get("max_charges", 0)) > 0:
		return maxf(0.0, float(ad.get("charge_recovery", 0.0)))
	# 冷却可随技能等级缩短（cd_ranks: [1级,2级,3级]），否则用固定 cd
	var cr: Array = ad.get("cd_ranks", [])
	var base: float = float(cr[clampi(int(ability_slots[i]["rank"]), 1, cr.size()) - 1]) if cr.size() > 0 else float(ad.get("cd", 0.0))
	return base * (1.0 - (hero_boost_n() - 1.0) * 0.2)   # 英雄倍率：CD 线性缩短(推荐)，n2=-20%、n3=-40%(=60%)


func slot_ready(i: int) -> bool:
	if i < 0 or i >= ability_slots.size():
		return false
	var s: Dictionary = ability_slots[i]
	if int(s["rank"]) <= 0 or float(s["cd_t"]) > 0.0 or hp <= 0.0 or _silence_t > 0.0 \
			or _stun_t > 0.0 or _channel_t > 0.0 or _cast_t > 0.0 or _charge_t > 0.0 or _charge_dash > 0.0:
		return false
	if slot_max_charges(i) > 0 and slot_charges(i) <= 0:
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
	if float(ability_slots[i].get("cd_t", 0.0)) > 0.0:
		return clampf(float(ability_slots[i]["cd_t"]) / cd, 0.0, 1.0)
	if slot_max_charges(i) > 0 and slot_charges(i) < slot_max_charges(i):
		return clampf(slot_recharge_left(i) / cd, 0.0, 1.0)
	return 0.0


## 该技能槽按当前等级的冷却总时长（cd_ranks 优先），供 UI 显示「CD 多少秒」。
func slot_cd(i: int) -> float:
	return _slot_cd(i)


func slot_start_cd(i: int) -> void:
	if i < 0 or i >= ability_slots.size():
		return
	var maximum := slot_max_charges(i)
	if maximum > 0:
		var charges := slot_charges(i)
		if charges <= 0:
			return
		ability_slots[i]["charges"] = charges - 1
		if charges == maximum and float(ability_slots[i].get("recharge_t", 0.0)) <= 0.0:
			ability_slots[i]["recharge_t"] = slot_charge_recovery(i)
		ability_slots[i]["cast_seq"] = slot_cast_sequence(i) + 1
	else:
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
	var was_unlearned := int(ability_slots[i]["rank"]) == 0
	skill_points -= 1
	ability_slots[i]["rank"] = int(ability_slots[i]["rank"]) + 1
	if was_unlearned and slot_max_charges(i) > 0:
		ability_slots[i]["charges"] = slot_max_charges(i)
		ability_slots[i]["recharge_t"] = 0.0
		ability_slots[i]["cast_seq"] = 0
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
	atkspeed_mult = 1.0
	crit_chance_bonus = 0.0
	crit_mult_bonus = 0.0
	evasion = 0.0
	bash_chance = 0.0
	bash_dur = 0.0
	on_hit_slow = 0.0
	on_hit_slow_dur = 0.0
	on_hit_dmg = 0.0
	for s in ability_slots:
		if bool(s["passive"]) and int(s["rank"]) > 0:
			var eff: Dictionary = Defs.ABILITIES.get(s["id"], {}).get("effect", {})
			add_atk += float(eff.get("atk_add", 0.0)) * int(s["rank"])
			add_hp += float(eff.get("hp_add", 0.0)) * int(s["rank"])
			add_range += float(eff.get("range_add", 0.0)) * int(s["rank"])
			add_cav += float(eff.get("bonus_cav", 0.0)) * int(s["rank"])
			# DOTA 被动衍生：攻速 / 暴击 / 闪避 / 攻击携带眩晕·减速·纯伤
			atkspeed_mult += float(eff.get("atkspeed_add", 0.0)) * int(s["rank"])
			crit_chance_bonus += float(eff.get("crit_chance", 0.0)) * int(s["rank"])
			crit_mult_bonus += float(eff.get("crit_mult", 0.0)) * int(s["rank"])
			evasion = minf(0.8, evasion + float(eff.get("evasion", 0.0)) * int(s["rank"]))
			if float(eff.get("bash_chance", 0.0)) > 0.0:
				bash_chance = float(eff.get("bash_chance", 0.0))
				bash_dur = float(eff.get("bash_dur", 0.6))
			if float(eff.get("on_hit_slow", 0.0)) > 0.0:
				on_hit_slow = float(eff.get("on_hit_slow", 0.0))
				on_hit_slow_dur = float(eff.get("on_hit_slow_dur", 1.0))
			on_hit_dmg += float(eff.get("on_hit_dmg", 0.0)) * int(s["rank"])
			# 技能等级化光环（§3d）：被动声明 aura_power_ranks/aura_radius_ranks → 按当前等级写回单位 aura 字段，
			# 令固定光环随该被动升级而增强（宋江 song_lead 的 speed_aura_ranks 是同款思路）。
			if eff.has("aura_power_ranks"):
				var apr: Array = eff["aura_power_ranks"]
				if apr.size() > 0:
					aura_power = float(apr[clampi(int(s["rank"]) - 1, 0, apr.size() - 1)])
			if eff.has("aura_radius_ranks"):
				var arr: Array = eff["aura_radius_ranks"]
				if arr.size() > 0:
					aura_radius = float(arr[clampi(int(s["rank"]) - 1, 0, arr.size() - 1)])
			# 林冲·猎骑：被动学了就启用「打骑兵概率吸血」。frac 可按被动等级取数组 cav_ls_frac_ranks。
			if float(eff.get("cav_ls_chance", 0.0)) > 0.0:
				cav_ls_chance = float(eff.get("cav_ls_chance", 0.0))
				var fr: Array = eff.get("cav_ls_frac_ranks", [])
				if fr.size() > 0:
					cav_ls_frac = float(fr[clampi(int(s["rank"]) - 1, 0, fr.size() - 1)])
				else:
					cav_ls_frac = float(eff.get("cav_ls_frac", 0.0))
	var frac := (hp / max_hp) if max_hp > 0.0 else 1.0
	# 英雄生命只吃「基地(聚义厅)·时代科技」(hero_tech_hp，约+10%)，不吃兵营的坚铠——折进重算保持持久
	var tech_hp_f: float = float(battle.hero_tech_hp) if (battle != null and battle.economy and faction == FACTION_LIANG) else 1.0
	max_hp = (_base_hp * mult + add_hp) * tech_hp_f * (1.0 + (hero_boost_n() - 1.0) / 3.0)   # 英雄倍率：血量×(1+(n-1)/3)
	hp = clampf(max_hp * frac, 1.0, max_hp)
	atk = (_base_atk * mult + add_atk) * (1.0 + (hero_boost_n() - 1.0) * 0.1)   # 英雄倍率：攻击力×(1+(n-1)·0.1)，n3=+20%(普攻不宜过高，技能伤害另算)
	atk_range = float(setup_def.get("range", 24)) + add_range
	bonus_vs_cav = float(setup_def.get("bonus_cav", 1.0)) + add_cav
	if melee_mode:                 # 拔刀近战：射程缩为肉搏（即便升被动也维持近战）
		atk_range = 27.0           # 必须 <28：否则 _weapon_kind/身姿绘制会按「长枪」阈值画成枪而非刀
	# 变身(transform)：形态修正叠加在基础数值之上——变身期间任何 recompute（升级/学技能）都保持形态加成
	if _form_t > 0.0 and not _form.is_empty():
		var ffrac := (hp / max_hp) if max_hp > 0.0 else 1.0
		max_hp *= float(_form.get("hp_mult", 1.0))
		hp = clampf(max_hp * ffrac, 1.0, max_hp)
		atk *= float(_form.get("atk_mult", 1.0))
		if _form.has("range"):
			atk_range = float(_form["range"])


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


func heal(amount: float, healer: Unit = null) -> float:
	if hp <= 0.0 or amount <= 0.0:
		return 0.0
	var hp_before := hp
	hp = minf(max_hp, hp + amount)
	var effective := hp - hp_before
	if effective <= 0.0:
		return 0.0
	if _track_combat_stats and healer != null and battle != null:
		battle.record_hero_combat_healing(self, healer, effective)
	_buff_glow = 0.6
	queue_redraw()
	return effective


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
func _begin_charge(dir: Vector2, dmg: float, windup: float, dist: float, width: float, slow: float, slow_dur: float,
		phys_immune := false) -> void:
	if dir.length() < 0.01:
		dir = Vector2(-1.0 if face_left else 1.0, 0.0)
	_charge_dir = dir.normalized()
	_charge_dmg = dmg
	_charge_t = windup
	_charge_dash = maxf(0.18, dist / 560.0)   # 冲刺时长：约 560px/s
	_charge_width = width
	_charge_slow = slow
	_charge_slow_dur = slow_dur
	_charge_phys_immune = phys_immune
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


## 花荣 Q：移速强化与敌方减速分槽保存，落地后即使中减速也按「强化×减速」正确叠算。
func apply_move_boost(mult: float, dur: float) -> void:
	_temp_move_boost = maxf(_temp_move_boost, mult)
	_temp_move_boost_t = maxf(_temp_move_boost_t, dur)
	_buff_glow = maxf(_buff_glow, 0.7)


## 花荣 Q：限时闪避只影响普攻，持续时间与永久被动分开。
func apply_temp_evasion(chance: float, dur: float) -> void:
	_temp_evasion = maxf(_temp_evasion, chance)
	_temp_evasion_t = maxf(_temp_evasion_t, dur)
	_buff_glow = maxf(_buff_glow, 0.7)


## 花荣 E：建立五箭单体锁定，并立刻把普通攻击目标切到被钉住者。
func start_hua_lock(t: Unit, shots := 5) -> void:
	if t == null or not is_instance_valid(t) or t.hp <= 0.0 or t.is_building or t.is_resource:
		return
	_hua_lock_target = t
	_hua_lock_shots = maxi(0, shots)
	if _hua_lock_shots > 0:
		_begin_attack(t, false)


func hua_lock_active() -> bool:
	return _hua_lock_shots > 0 and _hua_lock_target != null and is_instance_valid(_hua_lock_target) \
			and _hua_lock_target.hp > 0.0 and not _hua_lock_target.garrisoned


func has_hua_locked_attack(t: Unit) -> bool:
	return hua_lock_active() and t == _hua_lock_target


func _consume_hua_locked_attack(t: Unit) -> void:
	if not has_hua_locked_attack(t):
		return
	_hua_lock_shots = maxi(0, _hua_lock_shots - 1)
	if _hua_lock_shots > 0:
		return
	var beyond_normal_range := position.distance_to(t.position) > atk_range + radius + t.radius
	_clear_hua_lock()
	# 最后一箭仍由 _deal_hit 的局部目标继续发出；若目标在常规射程外，发完即停止，不追半张地图。
	if beyond_normal_range and _target == t:
		_target = null
		_state = ST_IDLE


func _clear_hua_lock() -> void:
	_hua_lock_target = null
	_hua_lock_shots = 0


## 三碗不过岗（武松 W）：dur 秒内移动/攻速在 [lo,hi] 间随机波动，立即先掷一次。
func start_drunk(lo: float, hi: float, dur: float) -> void:
	_drunk_lo = lo
	_drunk_hi = hi
	_drunk_t = dur
	_drunk_reroll = 0.0   # 下帧立刻重掷
	_drunk_move = randf_range(lo, hi)
	_drunk_atk = randf_range(lo, hi)
	_buff_glow = 1.0


## 醉神大闹快活林（武松 R）：物免期间每次有效平攻叠 bonus（最多 max_stacks）并触发分裂。
func start_drunk_god(bonus: float, dur: float, cleave := 0.0, max_stacks := 5) -> void:
	_phys_immune_t = dur
	_absorbed_phys = 0.0
	_drunk_god_bonus_per_hit = bonus
	_drunk_god_stacks = 0
	_drunk_god_max_stacks = maxi(1, max_stacks)
	_drunk_god_cleave = clampf(cleave, 0.0, 1.5)
	_buff_glow = 1.0


func is_phys_immune() -> bool:
	return _phys_immune_t > 0.0 or (_charge_phys_immune and (_charge_t > 0.0 or _charge_dash > 0.0))


## 普攻/物理弹道命中物免时的统一入口：武松累计转血；所有英雄都可把拦下值计入承伤。
func absorb_physical_damage(amount: float, from: Unit = null) -> void:
	if amount <= 0.0:
		return
	if _phys_immune_t > 0.0:   # 只有武松 R 的计时物免在结束时转化50%回血；李逵冲锋不回血。
		_absorbed_phys += amount
	_buff_glow = 1.0
	if _track_combat_stats and is_hero and faction == FACTION_LIANG:
		battle.record_hero_combat_mitigation(self, amount)


## 护甲削减（武松 E·双戒刀）：amount 点防御，dur 秒。
func apply_def_down(amount: float, dur: float) -> void:
	_def_down = maxf(_def_down, amount)
	_def_down_t = maxf(_def_down_t, dur)


## 致盲（武松 E·双戒刀附带）：dur 秒内本单位攻击必失（_deal_hit 落空）。
func apply_blind(dur: float) -> void:
	_blind_t = maxf(_blind_t, dur)
	_buff_glow = 0.6


## 概率障目：chance 为 0~1；同一时刻只取更高概率，雨区每跳短暂刷新持续时间。
func apply_attack_miss_chance(chance: float, dur: float) -> void:
	_attack_miss_chance = maxf(_attack_miss_chance, clampf(chance, 0.0, 1.0))
	_attack_miss_t = maxf(_attack_miss_t, dur)
	_buff_glow = 0.35


func is_blinded() -> bool:
	return _blind_t > 0.0


func is_stunned() -> bool:
	return _stun_t > 0.0


## 眩晕（踩地板控制）：取较长者，松开当前目标，呆立挨打。
func apply_stun(dur: float) -> void:
	var entering := _stun_t <= 0.0
	_stun_t = maxf(_stun_t, dur)
	if entering:
		_target = null
		cancel_cast_windup()
		_break_channel()   # 眩晕必断引导
		queue_redraw()
	else:
		_queue_animated_redraw()


## DOTA 护盾：给一层吸收盾（取较大者，dur 秒后清盾）。
func apply_shield(amount: float, dur: float) -> void:
	_shield = maxf(_shield, amount)
	_shield_t = maxf(_shield_t, dur)
	_buff_glow = 1.0
	queue_redraw()


## 区域护阵减伤：同一来源刷新，多个来源只取当前最高比例；来源到期后会正确降档。
## source_id=0 保留给无来源的直接增益，同一批调用仍按最高值合并。
func apply_damage_reduction(amount: float, dur: float, source_id: int = 0) -> void:
	var reduced := clampf(amount, 0.0, 0.95)
	if reduced <= 0.0 or dur <= 0.0:
		return
	if source_id == 0 and _damage_reduction_sources.has(0):
		var prior: Dictionary = _damage_reduction_sources[0]
		reduced = maxf(reduced, float(prior["amount"]))
		dur = maxf(dur, float(prior["t"]))
	_damage_reduction_sources[source_id] = {"amount": reduced, "t": dur}
	_refresh_damage_reduction()
	_buff_glow = maxf(_buff_glow, 0.55)


## 带「拦下伤害也计承伤」口径的减伤（李逵 Q）；减伤数值仍走通用多来源取最高逻辑。
func apply_counted_damage_reduction(amount: float, dur: float, source_id: int = 0) -> void:
	apply_damage_reduction(amount, dur, source_id)
	_stats_mitigation_t = maxf(_stats_mitigation_t, dur)


func clear_damage_reduction() -> void:
	_damage_reduction_sources.clear()
	_damage_reduction = 0.0
	_damage_reduction_t = 0.0
	_stats_mitigation_t = 0.0


func _refresh_damage_reduction() -> void:
	_damage_reduction = 0.0
	_damage_reduction_t = 0.0
	for state_v in _damage_reduction_sources.values():
		var state: Dictionary = state_v
		_damage_reduction = maxf(_damage_reduction, float(state["amount"]))
		_damage_reduction_t = maxf(_damage_reduction_t, float(state["t"]))


## DOTA 沉默：dur 秒内不可主动施法（被动不受影响）。
func apply_silence(dur: float) -> void:
	var entering := _silence_t <= 0.0
	_silence_t = maxf(_silence_t, dur)
	if entering:
		cancel_cast_windup()
		_break_channel()   # 沉默必断引导
		queue_redraw()
	else:
		_queue_animated_redraw()


## DOTA 缠绕(root)：dur 秒内不能移动，但可以攻击/施法——与眩晕互补的软控。
func apply_root(dur: float) -> void:
	var entering := _root_t <= 0.0
	_root_t = maxf(_root_t, dur)
	if entering:
		queue_redraw()
	else:
		_queue_animated_redraw()


## DOTA 缴械(disarm)：dur 秒内不能普攻，但可以移动/施法——克制物理核心的软控。
func apply_disarm(dur: float) -> void:
	var entering := _disarm_t <= 0.0
	_disarm_t = maxf(_disarm_t, dur)
	if entering:
		queue_redraw()
	else:
		_queue_animated_redraw()


## 引导施法开始：定身进入引导态（battle 侧登记 tick 结算）。dur 秒内不可移动/普攻/索敌。
func _begin_channel_state(dur: float) -> void:
	_channel_t = dur
	_channel_dur = dur
	_target = null   # 放下当前目标，就地引导
	queue_redraw()


## 引导被打断（眩晕/沉默/被拖走）：立即中止——battle._channel_pass 下一帧发现 _channel_t<=0 即停止结算。
func _break_channel() -> void:
	if _channel_t > 0.0:
		_channel_t = 0.0
		queue_redraw()


## DOTA 主动隐身：dur 秒内不可被索敌/指向（己方半透可见）；破隐首击带 strike_bonus 纯伤。
func apply_invis(dur: float, strike_bonus: float) -> void:
	_invis_t = maxf(_invis_t, dur)
	_invis_strike_bonus = strike_bonus
	modulate.a = 0.35
	queue_redraw()


## 破隐（攻击/施法即现形）：清隐身，并把破隐加成挂到下一击（由 _deal_hit 兑现）。
func _break_invis() -> void:
	if _invis_t > 0.0:
		_invis_t = 0.0
		modulate.a = 1.0
		queue_redraw()


## DOTA 变身(transform)：dur 秒内换到临时形态——按 form 表改攻/攻速/移速/体型/染色（到期还原）。
## 无贴图版：靠染色(modulate)+体型(radius)+数值区分形态；atk/hp/射程修正在 _recompute_hero_stats 末尾叠加。
func apply_form(form: Dictionary, dur: float) -> void:
	if _form_t <= 0.0:   # 仅首次进入变身时备份原值（重复施放不叠备份）
		_form_backup = {"atk_cd": atk_cd, "base_speed": base_speed, "radius": radius,
			"mod_r": modulate.r, "mod_g": modulate.g, "mod_b": modulate.b}
	_form = form
	_form_t = dur
	# 不经 recompute 的部分（攻速/移速/体型/染色）在此直接套用
	if form.has("atk_cd_mult"):
		atk_cd = float(_form_backup["atk_cd"]) * float(form["atk_cd_mult"])
	if form.has("speed_mult"):
		base_speed = float(_form_backup["base_speed"]) * float(form["speed_mult"])
	if form.has("radius"):
		radius = float(form["radius"])
	if form.has("tint"):
		var tc: Color = form["tint"]
		modulate = Color(tc.r, tc.g, tc.b, modulate.a)
	_recompute_hero_stats()   # 让 atk/血量/射程叠加 form 修正
	_buff_glow = 1.0
	queue_redraw()


## 变身到期：从备份还原体型/攻速/移速/染色，清形态并重算（recompute 此时不再叠 form 修正）。
func _end_form() -> void:
	if not _form_backup.is_empty():
		atk_cd = float(_form_backup.get("atk_cd", atk_cd))
		base_speed = float(_form_backup.get("base_speed", base_speed))
		radius = float(_form_backup.get("radius", radius))
		modulate = Color(float(_form_backup.get("mod_r", 1.0)), float(_form_backup.get("mod_g", 1.0)), float(_form_backup.get("mod_b", 1.0)), modulate.a)
	_form = {}
	_form_backup = {}
	_form_t = 0.0
	if is_hero:
		_recompute_hero_stats()
	queue_redraw()


## DOTA 变形术(hex)：dur 秒内沉默+缴械+大幅减速（组合软控·可反击），并显示"小猪替身"视觉。
func apply_hex(dur: float) -> void:
	_hex_t = maxf(_hex_t, dur)
	apply_silence(dur)
	apply_disarm(dur)
	apply_slow(0.35, dur)   # 变形期间步履蹒跚
	queue_redraw()


## DOTA 驱散/净化：hostile=true 清自身增益（樊瑞驱敌方 buff）；false 清自身减益（安道全神医解控）。
## buff_atk/aura_slow 由 _aura_pass 每帧重算，清了会立即回填，故不在此处理。
func dispel(hostile: bool) -> void:
	if hostile:
		# 清增益：临时攻/攻速/吸血/护盾/加速/隐身
		temp_atk = 1.0; _temp_atk_t = 0.0
		temp_atk_add = 0.0; _temp_atk_add_t = 0.0
		temp_atkspeed = 1.0; _temp_atkspeed_t = 0.0
		clear_aura_atkspeed()
		temp_lifesteal = 0.0; _temp_lifesteal_t = 0.0
		_shield = 0.0; _shield_t = 0.0
		clear_damage_reduction()
		if temp_speed > 1.0:
			temp_speed = 1.0; _temp_speed_t = 0.0   # 只清加速（减速归净化）
		if _invis_t > 0.0:
			_break_invis()
	else:
		# 净化减益：眩晕/缠绕/缴械/沉默/易伤/嘲讽/致盲/减速
		_stun_t = 0.0
		_root_t = 0.0
		_disarm_t = 0.0
		_silence_t = 0.0
		_dmg_amp = 0.0; _dmg_amp_t = 0.0
		_taunt_t = 0.0; _taunt_src = null
		_blind_t = 0.0
		_attack_miss_chance = 0.0; _attack_miss_t = 0.0
		_attack_speed_slow = 1.0; _attack_speed_slow_t = 0.0
		if temp_speed < 1.0:
			temp_speed = 1.0; _temp_speed_t = 0.0   # 只清减速（加速归驱散）
	queue_redraw()


## 宋江 R 的定向解控：只清说明中承诺的四项，不顺带移除缴械、易伤、嘲讽、致盲等其他减益。
func cleanse_command_control() -> void:
	_stun_t = 0.0
	_root_t = 0.0
	_silence_t = 0.0
	if temp_speed < 1.0:
		temp_speed = 1.0
		_temp_speed_t = 0.0
	queue_redraw()


## DOTA 嘲讽(taunt)：dur 秒内被迫攻击 src（无视原目标/玩家指令/AI 大脑）。优先级低于眩晕。
func apply_taunt(src: Unit, dur: float) -> void:
	_taunt_t = maxf(_taunt_t, dur)
	_taunt_src = src
	if src != null and is_instance_valid(src):
		order_attack(src)   # 立刻转火
		_chase_intent = CHASE_FORCED
	queue_redraw()


## DOTA 易伤：dur 秒内受到的伤害放大 (1+amp) 倍（取较强者）。樊瑞 W·摄魂咒。
func apply_dmg_amp(amp: float, dur: float) -> void:
	_dmg_amp = maxf(_dmg_amp, amp)
	_dmg_amp_t = maxf(_dmg_amp_t, dur)
	queue_redraw()


## DOTA 攻速狂暴：临时攻速倍率（>1 出手更快），取较大者。
func apply_atkspeed(mult: float, dur: float) -> void:
	temp_atkspeed = maxf(temp_atkspeed, mult)
	_temp_atkspeed_t = maxf(_temp_atkspeed_t, dur)
	_buff_glow = 0.6


## 攻速减益独立于增益池：黑雨中即使身上有义旗/狂攻，也会在最终出手速度上正确相乘。
func apply_attack_speed_slow(mult: float, dur: float) -> void:
	_attack_speed_slow = minf(_attack_speed_slow, clampf(mult, 0.1, 1.0))
	_attack_speed_slow_t = maxf(_attack_speed_slow_t, dur)
	_buff_glow = maxf(_buff_glow, 0.35)


## 区域攻速光环：同一来源刷新，多来源取最高倍率；高阶旗到期后自动降到仍生效的低阶旗。
## 与普通限时攻速分池，离开义旗后可恢复原有技能攻速，而不会把旗倍率拖长到普通 buff 的时长。
func apply_aura_atkspeed(mult: float, dur: float, source_id: int) -> void:
	var boosted := maxf(1.0, mult)
	if boosted <= 1.0 or dur <= 0.0:
		return
	_aura_atkspeed_sources[source_id] = {"mult": boosted, "t": dur}
	_refresh_aura_atkspeed()
	_buff_glow = maxf(_buff_glow, 0.45)


func clear_aura_atkspeed() -> void:
	_aura_atkspeed_sources.clear()
	_aura_atkspeed = 1.0


func _refresh_aura_atkspeed() -> void:
	_aura_atkspeed = 1.0
	for state_v in _aura_atkspeed_sources.values():
		var state: Dictionary = state_v
		_aura_atkspeed = maxf(_aura_atkspeed, float(state["mult"]))


func _spawn_dust() -> void:
	if is_cavalry:
		return  # 骑兵用马蹄尘另算；步兵扬尘
	if battle != null and battle._mob_count > 260:
		return  # 兵海不为每名步兵维护独立尘粒数组；技能/地面主特效照常保留。
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
	# 施法替换当前移动/攻击命令并清队列；完成后原地待命，再由玩家或托管下新令。
	_queue.clear()
	_patrolling = false
	_target = null
	_resume_amove = false
	_chase_intent = CHASE_AUTO
	_group_cap = 0.0
	_path = PackedVector2Array()
	_path_i = 0
	_state = ST_IDLE
	manual_order_active = false
	_cast_serial += 1
	_cast_t = dur
	_cast_dur = maxf(dur, 0.001)
	_cast_color = col
	queue_redraw()


func cancel_cast_windup() -> void:
	if _cast_t <= 0.0:
		return
	_cast_serial += 1
	_cast_t = 0.0
	if battle != null and battle.has_method("cancel_pending_cast"):
		battle.cancel_pending_cast(self)
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
	if not _dying and not _ultra_mass_visuals():
		var ow := 1.7
		var ocol := Color(0.05, 0.04, 0.03, 0.5)
		if _mass_visuals():
			draw_texture_rect(frame, Rect2(srect.position + Vector2(ow, ow), srect.size), false, Color(0.05, 0.04, 0.03, 0.42))
		else:
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
	elif not _ultra_mass_visuals():
		var lift := maxf(0.0, -cos(_anim_t * 2.0)) * _move_blend   # 腾空时影子收缩
		var ssc := radius * 0.95 * (1.0 - 0.16 * lift)
		draw_circle(Vector2(2, 3), ssc, Color(0, 0, 0, (0.25 - 0.06 * lift) * (1.0 - death_f)))
	for d in _dust:
		var da: float = d.t / DUST_DUR
		draw_circle(Vector2(d.x, d.y), 2.5 + 5.0 * (1.0 - da), Color(0.62, 0.56, 0.45, da * 0.4))
	if _buff_glow > 0.0:
		draw_circle(Vector2.ZERO, radius + 7.0, Color(1.0, 0.85, 0.35, _buff_glow * 0.5))
	# DOTA 被动/自身增益的持续视觉（只在状态激活时画、粒子≤3，兵海友好）
	if _shield > 0.0 and not _dying:
		# 护盾泡：身体外一圈淡蓝半透椭圆 + 搏动高光弧（take_damage 先扣此盾）
		var shp := 0.55 + 0.45 * sin(_idle_t * 4.0)
		draw_circle(Vector2.ZERO, radius + 5.0, Color(0.45, 0.72, 1.0, 0.10 + 0.05 * shp))
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 30, Color(0.6, 0.85, 1.0, 0.45 + 0.3 * shp), 2.0)
	if (temp_atk > 1.01 or temp_atk_add > 0.0) and not _dying:
		# 临时攻击增益：手部金红辉光粒子（环绕搏动）
		var gp := _idle_t * 3.0
		for gi in range(3):
			var ga := gp + float(gi) * TAU / 3.0
			draw_circle(Vector2(cos(ga), sin(ga) * 0.6) * (radius * 0.95), 2.0, Color(1.0, 0.68, 0.24, 0.6))
	if maxf(temp_atkspeed, _aura_atkspeed) > 1.01 and not _dying:
		# 临时攻速：身侧双手残影短线
		var asx := radius * 0.85
		var aso := sin(_idle_t * 14.0) * 3.0
		draw_line(Vector2(-asx, aso), Vector2(-asx - 6.0, aso), Color(0.8, 0.9, 1.0, 0.5), 1.6)
		draw_line(Vector2(asx, -aso), Vector2(asx + 6.0, -aso), Color(0.8, 0.9, 1.0, 0.5), 1.6)
	# 减速光环（公孙胜 E）：脚下青蓝色范围环
	if slow_aura_r > 0.0 and not _dying:
		var pulse := 0.5 + 0.5 * sin(_idle_t * 2.2)
		draw_arc(Vector2.ZERO, slow_aura_r, 0.0, TAU, 40, Color(0.5, 0.8, 1.0, 0.18 + 0.10 * pulse), 2.0)
		draw_circle(Vector2.ZERO, slow_aura_r, Color(0.4, 0.7, 1.0, 0.05))
	# 醉神·物理免疫（武松 R）：金色护体环
	if is_phys_immune() and not _dying:
		var sp := 0.6 + 0.4 * sin(_idle_t * 7.0)
		draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 28, Color(1.0, 0.82, 0.3, 0.85 * sp), 3.0)
	# 易伤（樊瑞 W·摄魂咒）：脚下暗红咒环 + 体表裂纹红光 + 头顶下垂的摄魂符，标识「受伤大增」
	if _dmg_amp_t > 0.0 and not _dying:
		var ap := 0.5 + 0.5 * sin(_idle_t * 5.0)
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 32, Color(0.9, 0.18, 0.32, 0.45 + 0.4 * ap), 2.4)
		draw_circle(Vector2(0, -radius * 0.45), radius * 0.55, Color(0.75, 0.1, 0.28, 0.16 * ap))
		for ai in range(3):   # 环上三点游走的摄魂火
			var aa := _idle_t * 1.6 + float(ai) * TAU / 3.0
			draw_circle(Vector2(cos(aa), sin(aa)) * (radius + 4.0), 2.2, Color(1.0, 0.5, 0.55, 0.5 + 0.4 * ap))
	if _root_t > 0.0 and not _dying:
		# 缠绕标记：脚下几束藤蔓弧线勾住，随时间轻摆
		if _mass_status_visuals():
			draw_circle(Vector2(0, 2), radius * 0.72, Color(0.3, 0.66, 0.22, 0.34))
		else:
			var rp := sin(_idle_t * 6.0) * 2.0
			for ri in range(4):
				var ra := float(ri) * TAU / 4.0 + 0.4
				var rc := Vector2(cos(ra), sin(ra)) * (radius * 0.8)
				draw_arc(rc + Vector2(0, 2), 5.0 + rp * 0.5, ra + PI * 0.7, ra + PI * 1.7, 8, Color(0.35, 0.72, 0.25, 0.85), 2.2)
			draw_arc(Vector2(0, 2), radius * 0.9, 0.0, TAU, 24, Color(0.3, 0.6, 0.2, 0.5), 1.6)
	if _disarm_t > 0.0 and not _dying:
		# 缴械标记：头顶一把灰色斜杠划掉的小剑
		var dy := -radius - 12.0 + sin(_idle_t * 4.0)
		draw_line(Vector2(-4, dy + 4), Vector2(4, dy - 4), Color(0.75, 0.75, 0.78, 0.9), 2.0)
		draw_line(Vector2(0, dy - 5), Vector2(0, dy + 5), Color(0.6, 0.6, 0.65, 0.9), 2.4)
		draw_line(Vector2(-5, dy - 5), Vector2(5, dy + 5), Color(0.95, 0.3, 0.25, 0.95), 2.0)
	if _taunt_t > 0.0 and not _dying:
		# 嘲讽标记：脚下搏动的红色怒环 + 头顶红色怒气「!」（被迫死战）
		if _mass_status_visuals():
			draw_circle(Vector2(0, -radius - 9.0), 3.2, Color(1.0, 0.24, 0.18, 0.9))
		else:
			var tp := 0.5 + 0.5 * sin(_idle_t * 8.0)
			draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 28, Color(0.95, 0.2, 0.15, 0.4 + 0.4 * tp), 2.6)
			var ty2 := -radius - 12.0 + sin(_idle_t * 5.0)
			draw_line(Vector2(0, ty2 - 6), Vector2(0, ty2 + 1), Color(1.0, 0.25, 0.2, 0.95), 2.8)
			draw_circle(Vector2(0, ty2 + 5), 1.7, Color(1.0, 0.25, 0.2, 0.95))
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
	if _hex_t > 0.0 and not is_building and not _dying:
		_draw_hex_critter()   # 变形术：以小猪替身取代本体立绘
	elif as_sprite:
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

	# 极端兵海下满血普通单位省略血条；受伤/英雄/选中单位仍完整显示，减少每帧上千次矩形绘制。
	if hp > 0.0 and Settings.show_healthbars and (not _mass_visuals() or hp < max_hp - 0.5):
		var w := (radius * 2.6) if (is_hero or is_building) else (radius * 2.1)
		var bh := 5.0 if (is_hero or is_building) else 4.0
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		var hc := Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.85, 0.3), frac)
		if faction == FACTION_GUAN:
			hc = Color(0.6, 0.1, 0.1).lerp(Color(0.9, 0.55, 0.2), frac)
		if not _ultra_mass_visuals():
			draw_rect(Rect2(-w * 0.5 - 1.0, bar_y - 1.0, w + 2.0, bh + 2.0), Color(0, 0, 0, 0.8))
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

	# 引导进度条（凌振轰天连炮等）：头顶一条青蓝色余量条 + 上方脉冲光点（正在引导）
	if _channel_t > 0.0 and _channel_dur > 0.0 and not _dying:
		var cf := clampf(_channel_t / _channel_dur, 0.0, 1.0)
		var cwd := radius * 2.2
		var cyy := bar_y - 11.0
		draw_rect(Rect2(-cwd * 0.5 - 1.0, cyy - 1.0, cwd + 2.0, 5.0), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(-cwd * 0.5, cyy, cwd * cf, 3.0), Color(0.5, 0.82, 1.0, 0.95))
		var cpz := 0.5 + 0.5 * sin(_idle_t * 12.0)
		draw_circle(Vector2(0, cyy - 6.0), 2.0 + cpz, Color(0.7, 0.9, 1.0, 0.5 + 0.4 * cpz))
	# 眩晕：头顶三颗旋转金星（经典「被打懵」标记）
	if _stun_t > 0.0 and not is_building and not _dying:
		var syc := bar_y - 16.0
		if _mass_status_visuals():
			draw_circle(Vector2(0, syc), 3.5, Color(1.0, 0.88, 0.28, 0.95))
		else:
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


## 变形术替身：把被 hex 的目标画成一只蠢萌小猪（沉默+缴械+减速期间）。屏幕空间（调用处已切 ISO_INV）。
func _draw_hex_critter() -> void:
	var bob := sin(_idle_t * 6.0) * 2.0
	var c := Vector2(0, -8 + bob)
	var pink := Color(0.98, 0.66, 0.72)
	draw_circle(c, 9.0, pink)                                        # 身体
	draw_circle(c + Vector2(-4.5, -6.5), 2.6, pink)                  # 左耳
	draw_circle(c + Vector2(4.5, -6.5), 2.6, pink)                   # 右耳
	draw_circle(c + Vector2(0, 1.5), 4.2, Color(0.95, 0.55, 0.62))   # 猪拱嘴
	draw_circle(c + Vector2(-1.4, 1.5), 0.9, Color(0.4, 0.2, 0.25))
	draw_circle(c + Vector2(1.4, 1.5), 0.9, Color(0.4, 0.2, 0.25))
	draw_circle(c + Vector2(-3, -1.5), 1.0, Color(0.15, 0.1, 0.12))  # 眼
	draw_circle(c + Vector2(3, -1.5), 1.0, Color(0.15, 0.1, 0.12))
	for i in range(3):                                              # 头顶变形残光
		var a := _idle_t * 3.0 + float(i) * TAU / 3.0
		draw_circle(c + Vector2(cos(a) * 12.0, sin(a) * 6.0 - 10.0), 1.4, Color(0.7, 0.5, 0.95, 0.7))


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


## 是否为防御塔（可攻击的塔类建筑）：用于转向绘制。
func _is_tower() -> bool:
	return is_building and not is_resource and atk > 0.0 and String(setup_def.get("build_cat", "")) == "tower"


## 逻辑方向 → 3x3 朝向格（中心(1,1)=待机）。0=E 顺时针 8 向。
func _dir8_cell(dlog: Vector2) -> Vector2i:
	var sd := GameMap.ISO.basis_xform(dlog)   # 投影到屏幕方向
	if sd.length() < 0.001:
		return Vector2i(1, 1)
	var sector := int(round(atan2(sd.y, sd.x) / (PI / 4.0)))
	sector = ((sector % 8) + 8) % 8   # 0=E 1=SE 2=S 3=SW 4=W 5=NW 6=N 7=NE
	var cells := [Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2),
		Vector2i(0, 1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	return cells[sector]


## 程序化塔身（新塔暂无美术时的兜底）。当前处于 ISO_INV(直立)空间。
func _draw_tower_proc(tint: Color) -> void:
	var pal := {
		"thunder_tower": [Color("5a554f"), Color("7a3b2a")],
		"altar_tower": [Color("47436a"), Color("8a5cc0")],
		"caltrop_tower": [Color("6b573a"), Color("3a2f20")],
	}
	var cols: Array = pal.get(key, [Color("6a6258"), Color("4a443c")])
	var body: Color = (cols[0] as Color) * tint
	var top: Color = (cols[1] as Color) * tint
	var s := radius * 2.2
	draw_rect(Rect2(-s * 0.32, -s * 0.05, s * 0.64, s * 0.6), body)                    # 塔身
	draw_rect(Rect2(-s * 0.32, -s * 0.05, s * 0.64, s * 0.6), body.darkened(0.4), false, 2.0)
	draw_rect(Rect2(-s * 0.40, -s * 0.22, s * 0.80, s * 0.20), body.lightened(0.06))    # 平台
	for i in range(3):                                                                  # 垛口
		draw_rect(Rect2(-s * 0.40 + s * 0.28 * float(i), -s * 0.32, s * 0.16, s * 0.12), top)


## 会转向的炮管/法杖：从塔顶指向当前目标（无目标朝下）。ISO_INV(直立)空间，方向取屏幕投影。
func _draw_tower_barrel() -> void:
	var dlog := Vector2(0.4, 1.0)
	if _target != null and is_instance_valid(_target):
		dlog = _target.position - position
	var sd := GameMap.ISO.basis_xform(dlog)
	if sd.length() < 0.001:
		sd = Vector2(0, 1)
	sd = sd.normalized()
	var pivot := Vector2(0, -radius * 0.85)
	var col := Color("3a332b")
	match key:
		"altar_tower": col = Color("9a6cd0")
		"thunder_tower": col = Color("4a4540")
		"caltrop_tower": col = Color("6b573a")
	var blen := radius * 1.15
	draw_circle(pivot, radius * 0.34, col.darkened(0.25))           # 炮座
	draw_line(pivot, pivot + sd * blen, col, 4.0)                   # 炮管
	var muzzle := pivot + sd * blen
	draw_circle(muzzle, 3.2, col.lightened(0.25))                  # 口
	if key == "altar_tower" and _target != null:                   # 法坛：口部紫光球
		draw_circle(muzzle, 4.6, Color(0.66, 0.36, 1.0, 0.5))
	if _muzzle_t > 0.0:                                             # 开火闪光（朝目标，转向开火感）
		var fl := _muzzle_t / 0.18
		var fc := Color(1.0, 0.85, 0.4, 0.9 * fl)
		if key == "altar_tower":
			fc = Color(0.8, 0.5, 1.0, 0.9 * fl)
		draw_circle(muzzle, 4.0 + 5.0 * fl, fc)
		draw_circle(muzzle + sd * 4.0, 2.5 + 3.0 * fl, Color(fc.r, fc.g, fc.b, 0.6 * fl))


func _draw_building() -> void:
	if is_resource:
		_draw_resource_node()
		return
	# 防御塔：不能移动 → 用「转向」表达朝向。有 3x3 朝向图集就按对目标的方向取格(含开火朝向)；
	# 无图集则程序化塔身 + 一根会转向瞄准目标的炮管/法杖。
	if _is_tower():
		var ttint := (Color(0.5, 0.72, 1.0, 0.34) if _pending_build else Color(0.62, 0.66, 0.78, 0.82)) if is_constructing else Color.WHITE
		if Art.tower_sheet(key) != null:
			# 用塔自带的 8 向图按对目标方向取格(开火朝向)。朝向表已做过【脚底对齐】处理，
			# 各格塔身位置一致 → 切方向时只武器转、塔身不再移位。
			# 朝向用「保持式」：有目标时跟随，目标刚丢失/被打死的 0.55s 内仍维持上次开火方向，
			# 之后才回正面(待机)——消除「攻击后朝向闪回正面再乱跳」。
			var cell := _tower_aim if _tower_aim_hold > 0.0 else Vector2i(1, 1)
			var dt := Art.tower_dir_texture(key, cell)
			if dt != null:
				var s2 := GameMap.building_visual_px(GameMap.footprint_half_for(radius))
				draw_texture_rect(dt, Rect2(-s2 * 0.5, -s2 * 0.78, s2, s2), false, ttint)
				if is_constructing:
					_draw_build_progress()
				return
		var btex := Art.building_texture(key)
		if btex != null:   # 有静态图集(箭楼/buildings2 新塔)：用其美术当塔身
			var s3 := GameMap.building_visual_px(GameMap.footprint_half_for(radius))
			draw_texture_rect(btex, Rect2(-s3 * 0.5, -s3 * 0.78, s3, s3), false, ttint)
		else:              # 无美术：程序化塔身
			_draw_tower_proc(ttint)
		if not is_constructing:
			_draw_tower_barrel()   # 所有塔都叠「转向炮管/法杖 + 开火闪光」→ 朝当前目标(转向动画)
			if hp < max_hp * 0.65:
				_draw_burning(GameMap.building_visual_px(GameMap.footprint_half_for(radius)))
		if is_constructing:
			_draw_build_progress()
		return
	# 按建筑自身 key 找专属美术：遭遇战建筑在 buildings；treasure_cart 在 units3；其余在 terrain
	var tex: Texture2D = Art.building_texture(key)
	if tex == null:
		tex = Art.unit_texture(key)
	if tex == null:
		tex = Art.terrain_texture(key)
	if tex == null:
		tex = Art.terrain_texture("hall")
	var tint := (Color(0.5, 0.72, 1.0, 0.34) if _pending_build else Color(0.62, 0.66, 0.78, 0.82)) if is_constructing else Color.WHITE
	if tex != null:
		# 视觉尺寸与「建造预览虚影」完全一致（GameMap.building_visual_px）——预览多大、建好就多大，
		# 不再出现「预览很大、落成缩水」的落差。
		var s := GameMap.building_visual_px(GameMap.footprint_half_for(radius))
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.78, s, s), false, tint)
		if not is_constructing and _has_smoke():
			_draw_smoke(s)
		if not is_constructing and hp < max_hp * 0.65:
			_draw_burning(s)   # 受损起火：火苗+浓烟（<35% 更旺）
		if is_constructing:
			_draw_build_progress()
		return
	_draw_building_fallback()


## 建筑受损起火（屏幕空间，紧随建筑贴图同一变换）：血量<65% 两处火苗；<35% 三处大火+滚滚浓烟。
## 纯程序化摆动三角焰（外橙内黄）+ 上升灰烟团，_burn_t 驱动（受损建筑才逐帧重绘）。
func _draw_burning(s: float) -> void:
	var sev := 1.0 - hp / maxf(max_hp, 1.0)   # 损伤度 0.35..1
	var big := sev > 0.65
	var n_f := 3 if big else 2
	for i in range(n_f):
		var ph := _burn_t * (5.0 + float(i) * 1.7) + float(i) * 2.1
		var ax := (float(i) / float(maxi(1, n_f - 1)) - 0.5) * s * 0.46 + sin(ph * 0.7) * 2.0
		var ay := -s * (0.24 + 0.20 * float(i % 2))
		var fh := s * (0.11 + 0.07 * sev) * (0.8 + 0.25 * sin(ph))
		var fw := fh * 0.5
		var sway := sin(ph) * fw * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(ax - fw, ay), Vector2(ax + fw, ay), Vector2(ax + sway, ay - fh)]),
			Color(1.0, 0.42, 0.08, 0.78))
		draw_colored_polygon(PackedVector2Array([
			Vector2(ax - fw * 0.5, ay), Vector2(ax + fw * 0.5, ay), Vector2(ax + sway * 0.7, ay - fh * 0.62)]),
			Color(1.0, 0.86, 0.30, 0.85))
	if big:
		for k in range(3):   # 浓烟：三团循环上升、渐大渐淡
			var sp := fmod(_burn_t * 0.45 + float(k) * 0.33, 1.0)
			draw_circle(Vector2(sin((_burn_t + float(k) * 2.0) * 1.3) * s * 0.08, -s * 0.5 - sp * s * 0.55),
				s * (0.05 + sp * 0.10), Color(0.24, 0.22, 0.21, (1.0 - sp) * 0.42))
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
	if _pending_build:
		return   # 虚影态：尚未起建，不画进度条
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
