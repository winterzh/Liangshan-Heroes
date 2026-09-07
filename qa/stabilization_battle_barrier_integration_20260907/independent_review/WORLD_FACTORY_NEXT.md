# 下一批：经典继续本局的统一世界工厂（两页设计稿）

范围：官方经典固定 30 波；接续本轮已验证的 Battle 屏障/时钟和根 v3。
本稿只读设计，未实现或运行。目标先完成独立进程恢复闭环，再接玩家槽与菜单。

## 调用顺序与 19 个已有组件

内容身份 `run_content_identity.resolve_runtime_identity()` 和值 codec 是
共同依赖。下表覆盖 19 个局部组件；根 v3 替换旧根 v2，另加本轮 clock/barrier。
所有 `.new()` 的 Script、纹理与关卡来源由受信宿主提供，存档不能决定加载路径。

| 顺序 | 现有 API 与组件 | 外层必须完成 |
| --- | --- | --- |
| 1 捕获 | 真正 `request_run_capture()` → capture_ready；各模块 `capture/validate` | 同一完整屏障内清点全部节点/引用/顺序与物品 UID；整个复合记录完成前不 await，不写正式槽 |
| 2 私有骨架 | `run_map_state.stage_map_values()`；`run_fog_state.bind()` | 建脱树、禁用、阻塞信号的 Battle/world/map，先绑定实际 map 尺寸、fog/vision；受信 Defs/资源与官方上下文已就绪 |
| 3 单位与身份 | `run_unit_graph.prepare()` 内调 `run_unit_state.instantiate/bind`、`run_graph_identity.declare_entities/configure` | 保留返回的 root_order、active_order、id_to_unit、activation_plan 和共享身份对象；dying Unit 不能因不在 Battle.units 就遗漏 |
| 4 地图显示与关卡 | `run_map_state.finish_display()` 内调 `run_scenery_state.restore_into()`；`run_defense_level_state.restore()` | 已存足迹/五套导航不重复注册；关卡只填值，禁止 deploy/on_start；绑定关卡 RNG owner |
| 5 混合效果图 | `run_visual_graph.validate/prepare`；`run_projectile_state.instantiate/bind`；`run_li_brawn_axes_state.instantiate/bind` | 先补统一 FxRoot 路由/顺序协议，再准备所有节点；13 类 visual 图目前不能直接接收 Projectile/飞斧混合子树 |
| 6 权威效果/队列 | `run_continuous_effect_state`、`run_zone_effects_state`、`run_meteor_wards_state`、`run_remaining_effect_state`、`run_cast_flow_state`、`run_item_cast_flow_state` 各 `validate/bind` | 注入同一 Unit 身份与 Fx token 适配；保留命中集合、剩余时间、排队顺序和过期引用 |
| 7 根与分配器 | 根 v3 `bind()`；`run_item_id_state.restore()`；`Battle.configure_restored_gameplay_rng()` 使用 `run_gameplay_rng.restore` | 根绑定靠近最终安装，遵守同轮激活合同；next_entity_id 与图一致，物品最大已用 UID 含活体/退休库存/队列，禁止复用 |
| 8 挂载与一次激活 | `visual.bind_ground_fire_owner()`；各 `activate()`；clock.`activate_restored()` | 恢复全部信号/父子次序，所有图绑定后释放 Unit/Fx tombstone；共享身份保留供下一次保存；整树暂停中安装，再统一解锁 |

根绑定、后续安装和激活之间不能跨帧。任一准备失败都丢弃整棵私有图，
保留原世界和原槽；不能将“半数模块已成功”暴露给玩家。恢复 `_ready`
入口必须在新时钟创建、随机数初始化、部署和 Steam.begin_run 之前分流；
屏障和 Battle 要引用根 v3 恢复的同一个时钟，激活一次且不受新 Engine 模16影响。

## 首先补齐的外层缺口

当前 13 类 visual 图把未知子节点直接拒绝；必须增加统一 FxRoot 子节点
类型表与原始顺序，显式交给 Projectile/飞斧适配器，不能先删掉这两类再称
整图完成。`BlinkShotFx` 已知可被下一次图腾脉冲创建，必须补适配或整体拒绝；
还要按真实经典节点清单覆盖 `DeathRemains/FadingMark`、英雄其他特效、
WorldShadow.ShadowBatch（含 dying 引用）、水面背景、Dapple/AmbientMotes、
Overlay、镜头、HUD、氛围 CanvasLayer 和鼠标资源。允许重建的显示节点必须
单列受信无玩法副作用的工厂合同，并验证绘制/次序/计时；不能把未知节点当缓存丢掉。

还缺总记录 schema、父子/信号连接清单、物品 UID 全域审计、错误回滚、
UI/Settings/游戏速度策略与退出生命周期。旧 `_steam_run_id` 是运行期编号，
不能照抄或重开一局来凑；Steam 回执桥未完成时，恢复局的发布必须保持待对账，
不假报成就续算已完成。A2 假 SDK 账本不等于这个桥已接入。

必须整体拒绝：身份/引擎/内容版本不符；非经典、AI、自定义、工坊/诊断场；
RNG/时钟故障、非60Hz、开放物理步/队列待删、树外持续写；未知节点/脚本/纹理/
信号、缺实体或 UID 冲突；损坏/超限/不支持的 schema；导航、足迹、地面火计数
等跨模块不一致。当前校验只能证明 Battle 树内范围，未来异步玩法需显式登记。

## 最小跨进程验收矩阵

同一固定源码、引擎和初始状态，A 进程实际捕获后退出；B 进程冷启动读该记录。
与继续运行的基线比较实际事件、RNG 状态、编号及游戏字段；所有差异留证据。

| 场景 | 最小验收 |
| --- | --- |
| 新旧 Engine 计数/模16不同 | 复原同一 cache phase 和 next_tick；不开新局、RNG不多抽、不丢既有缓存；第一批真实回调正常 |
| 行军＋付费生产＋库存冷却 | 位置/订单序列/钱/木/剩余训练时间一致；只产出一次，编号与物品 UID 不复用 |
| Projectile＋飞斧＋持续/图腾效果 | 同时非空恢复；实际 engine 消费后伤害一次、Fx退出一次；未来新特效可再次保存 |
| 单位死亡/英雄退休库存/死亡残留 | 活动表与树顺序分别保留，过期引用语义正确，计数/奖励不重发，下一次保存仍合法 |
| 波次边界与最终清理 | 波次不重开、定时器不归零，清理目标稳定编号保留，完整30波结算另设长程门槛 |
| 拒绝与中断 | 逐模块坏记录/缺引用/未支持 Fx 整体拒绝；私有图释放，原世界/槽未变；写槽被杀的磁盘矩阵另跑 |

完成后再接单继续槽、原子替换、坏档提示和菜单；八关适配、真人试玩、1800秒
持续运行、两机和 Steam 实际客户端仍各自保留验收门槛。
