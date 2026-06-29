class_name LevelBase
extends RefCounted
## 关卡基类。战斗运行器 Battle 通过这些钩子驱动各关内容与机制。
## 各关只需覆盖需要的钩子；通用系统（选取/指挥/技能/编队/动画/光环/隐蔽）由 Battle 统一负责。

# 状态码（关卡 process 中通过 b.win()/b.lose() 结束）
func id() -> String: return "level"
func title() -> String: return ""
func subtitle() -> String: return ""

# 地图
func map_w() -> int: return 60
func map_h() -> int: return 60
func map_theme() -> String: return "marsh"
func map_base() -> int: return GameMap.T.GRASS
func paint_map(_map: GameMap) -> void: pass        # 绘制地形（bake 前）
func decorate(_map: GameMap) -> void: pass         # 装饰物
func camera_start_cell() -> Vector2i: return Vector2i(map_w() / 2, map_h() / 2)

# 剧情与部署
func intro_lines() -> Array: return []
func deploy_hint() -> String: return "查看战场形势与兵力部署，点「开战」开始（开战后方可选取、指挥兵马）。"
func deploy(_b) -> void: pass                       # 部署初始我军（及预置敌军/目标）

# 流程
func on_start(_b) -> void: pass                     # 点「开战」后：启动波次/计时器
func process(_b, _delta: float) -> void: pass       # FIGHT 阶段每帧自定义机制 + 胜负判定
func on_unit_died(_b, _u) -> void: pass             # 单位阵亡钩子（统计英雄存活、营救判定等）
func top_status(_b) -> String: return ""            # 顶栏文字
func on_ability(_b, _caster, _ability_id: String, _lp: Vector2) -> bool: return false  # 关卡自定义技能(如指路)，处理返回 true

# 经济/经营（自由「遭遇战」模式）：默认关闭，战役关卡完全不受影响
func economy_enabled() -> bool: return false
func start_gold() -> int: return 0
func start_wood() -> int: return 0
func base_pop_cap() -> int: return 0
func hero_cap() -> int: return 0           # 英雄总数上限（0=不限）；驻守战覆写为 4
func fog_enabled() -> bool: return false   # 战争迷雾（默认关，战役不受影响）
func start_age() -> int: return 3          # 起始时代：默认 3=全解锁(不分代，据守/战役不受影响)；1v1 覆写为 1 走三代进阶
# 竞技场沙盒专用：聚义厅「点将」列出全部 108 将(DOTA 改版 kit)；即时成军。默认关——
# 故 1v1/驻守战 不受 DOTA 改版影响（仍只有原 6 个可训练英雄）。
func uses_dota_roster() -> bool: return false
func arena_instant_train() -> bool: return false
# 英雄初始技能等级：>0 ⇒ 有 4 技能组者一出场就满配该等级(无需经验加点)。
# 默认 2：战役/剧情(非经济)的英雄换上「对应 DOTA 英雄的 4 技能(2 级)」。
# 经济模式 1v1/驻守战覆写为 0 ⇒ 仍走原来的「升级学技能」(不受 DOTA 改版影响)；竞技场覆写为 3(满级随便放)。
func hero_start_rank() -> int: return 2
