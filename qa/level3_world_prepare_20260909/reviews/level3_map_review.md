# Level3 世界恢复只读准备审查（2026-09-09）

范围：当前 `D:/AI项目/水浒/开发工程` 的真实祝家庄 RTS、地图/城门/任务界面及终局依赖。未运行 Godot/Git，未修改工程。本文件仅为准备草稿，不是完整世界恢复验收。

受查 `scripts/levels/level3_zhujiazhuang_rts.gd` SHA-256：`7fe40d07350110d2c3f07815fd40819dbe848a8e59b90093955d6a50bf77d248`。

## 1. 关卡字段与外层对象的边界

Level3 共 31 个 `var`，静态逐名核对 `run_campaign_level_state.gd:33-38`，缺失 0、多余 0。包括 8 个单 Unit 引用、7 个 Unit 数组、4 个时钟、4 个计数、7 个布尔状态和 `stage`。基类 LevelBase 无额外声明状态。LevelState 的职责是按 ID 绑定这些字段，**不是创建完整战场**；其 `restore:303-331` 明确只 `.new()` 后赋值，不调用 deploy/on_start。

真实还须另层恢复的内容：

| 内容 | 所有者与当前通道 | 实际限制/要求 |
| --- | --- | --- |
| 所有单位、资源、箭楼、前营兵营、未放入 Level 数组的守军和玩家后建单位 | Unit graph；Level 单引用和数组只是其中子集 | 必须冻结完整 `units_root` 次序、`Battle.units` 成员次序及实体 ID。不能靠 Level 的 15 个引用字段重新枚举部署单位。 |
| 囚徒/获救者/被擒扈三娘/撤离偏门的 Unit 标志 | `run_unit_state.gd` 已列字段，但 `930-934` 明确拒绝 chapter state | 首次开战就因扈三娘 `defeat_outcome=captured`、囚徒 `is_captive=true` 不兼容 classic UnitState。需明确的战役契约，不能简单取消校验且声称全支持。 |
| 地形、导航、占地计数、墙段 metadata、高度、最终装饰数据 | `run_map_state.gd:15-25,185-237` 已保存 | `campaign_wall_segments` 已在白名单，不是 LevelState 漏项。完整地图 display 仍被 SceneryState 的 classic 工厂拒绝。 |
| 城门 art_variant、贴图校准 metadata、真实占地 metadata | UnitState values + 通用 metadata codec (`1192-1223,1357`) 已覆盖值类型 | 恢复现值即可，不需要重跑关卡部署/城门配置。渲染前必须具备正确地图高度和 Art 环境上下文。 |
| 战役环境 `CampaignScenery`、StorySign、木墙、材质/树木/遮挡运行状态 | 独立场景工厂 | `run_scenery_state.gd:63-64` 要求原始 LiangshanScenery；`_kind:225-233` 也不认识 StorySign。仅放宽根类型会在子图继续失败。 |
| Mission action/events/metric/timers 与真实控件、marker、绑定、滚动 | 已有 MissionState + Presentation 组件 | 必须接到同一新 Battle/Level/Unit graph，不能根据布尔状态重新 begin 或再次添加按钮。 |
| MissionMarker 与运行中特效的 `fx_root` 混排次序 | Presentation + Visual graph 的联合所有权契约 | 现 Visual.capture 全树遍历并拒绝未知脚本；不能简单 skip marker，须明确外部 marker token 与混排 child order。 |
| 敌我资源、工人命令、迷雾/临时亮区、选择、人口/科技、ID/RNG/时钟 | BattleRoot、Unit、Fog 等对应模块 | `faction_res`、`lit_cells`、economy 等已有 root 值字段；现 root `389` 仍拒绝非空 mission/非classic level。 |
| 战役编号、官方上下文、继续局 receipt、终局与下一关入口 | 世界事务及 Campaign/Steam 层 | `run_world_session.gd:12,60,174-180`、SlotStore context 仍是固定 classic30；必须明确战役安装/回滚和结算策略。不能沿旧 FLAGS 把恢复的 Level3 置为 skirmish。 |

## 2. 原始构造顺序与不可重放行为

真实 Battle 路线在 `battle.gd:445-538`：

1. 复制 Defs/Abilities/Items → content pack → 设置 Art 环境映射 → `level.apply_overrides` → AbilityVisuals。Level3 覆写 hall 可训练名单、敌兵造价/pop、七囚徒的可训练标记和人口（`level3:81-89`）。这是安装内容契约；后续补兵读取 `b._defs`，只恢复旧 Unit.setup_def 不能代替它。
2. 建立 `world.transform=GameMap.ISO`，建立地图 → init → `level.paint_map` → `CampaignEnvironment.paint` → bake → `level.decorate` → `map.enable_campaign_environment`。
3. 建 `units_root`、`fx_root`、fog、overlay、camera、HUD，并连接 HUD。
4. 创建 Mission → `level.deploy` 部署所有实体、注册占地、设立囚徒和城门视觉。
5. 玩家开战时 `_on_start_battle:2260-2269` 置 FIGHT、configure_campaign，再 `level.on_start`。

**恢复不可重放 4/5**：deploy 会再次生成实体、增加占地计数；on_start 会重置敌资源为 gold180/wood100、重派工人采集、begin Mission、重复 action 和 marker、重新点亮外营/北矿并发送提示（`level3:281-293`）。`_introduce_sun` 会生成孙立并写 sent_sun；救人 action 改阵营/速度并追加按钮；终局回调会写事件和发奖。全部应恢复已保存的效果而非再次调用。

建议私有恢复依赖序列（不表示现代码已经支持）：

1. 校验可信 Level3/内容/engine/存档身份；构造离树、disabled、blocked Battle，准备本关可信运行定义。
2. 建 world/map，使用 MapState.stage_map_values 还原网格、五套导航、`_block_count`、高度 RF 图/采样、最终 decor、metadata；禁止重新 paint/bake/decorate。
3. 构造完整 Unit shell graph 并绑定引用，保留原 root/active 次序。占地只恢复 metadata，**不能再 register_building_footprint**；MapState:130-132 明确计数已恢复。
4. 用同一 ID 表恢复 Level3 31 字段。Level3 无 UI external 字段，因此可在 Presentation 前恢复；保留 prisoners 的 7 槽和顺序（0 必须仍对应时迁，死亡后缺席是 null 槽而不是数组压缩）。
5. 绑定 Battle fog/vision 与 units 后建 CampaignScenery；其 setup 通过 `map.parent.parent` 保存新 Battle，读取已还原地图元数据、高度、decor。补齐 fx/HUD/camera 等新 owner 依赖。
6. 使用 Presentation + MissionState 创建真实 UI/marker，并把 mission/按钮回调指向新 Battle、Level3、Unit。连接 Unit.died/story_resolved 到新 Battle 的固定处理器；当前 classic worldcore:351-352 已演示这个连接阶段。
7. 采用明确的预布局事务阶段：先安装 Root 值和引用但不 arm clock → 暂停树内挂载并完成 Presentation layout/scroll → 原 nonce 仅最终一次完成 clock 绑定/arm，并在同一最终帧完成 HUD 和各组件激活。现 classic 同帧绑定契约不能直接承受跨帧 layout，详见下节。直到这一步前不能让 level.process、scenery._process 或任务按钮运行。

两个跨组件的硬阻塞也须解决：

- `run_visual_graph.gd:305-323` 从 fx_root 深度遍历所有节点，未知脚本直接 `UNSUPPORTED_VISUAL_SCRIPT`。真实 MissionMarker 是 fx_root 的直接子节点，不能靠修改 effect 白名单后“略过非effect”处理。应提供 exact MissionMarker 外部 token，保存 fx/marker 的整体混排顺序、parent、唯一性和恢复所有权；未声明节点继续拒绝。否则截图层序与整个 root 的激活拓扑校验会不同。
- `run_battle_world_core.gd:300-312` 的 mount 先 Root.bind 并记 bound process/physics frame，随后 `activate_components:339-371` 要求原 clock entry 有效；RootState:590-597 返回同帧安装契约，HUD.finish/activate:184-188 也记 process frame。Presentation.finish_layout:535-552 至少要经过初始化、等待容器布局、再等待滚动布局三个调用帧。直接在旧 mount 和 activate 之间 await 会违反时钟/HUD契约。建议拆成预安装 root 值/引用但不启动 clock、mounted gated layout、原 nonce 最终一次 arm。**Battle._prepared_clock_entry_valid:17261-17264 已允许“无 `_run_core_clock_bound` metadata 且 `_run_clock==null`”；所以无需改 Battle._ready 守卫来允许首次无clock挂载。** 仍需满足 `_ready:407-409` 的 prepared=true、disabled、paused、restored RNG、无barrier、world.parent==Battle。需要改变的是 Core/Root/HUD 的阶段契约，保留一次最终绑定校验。

## 3. 墙体、城门与场景层的确定性陷阱

**实际逻辑墙与视觉墙是两份相关数据。** `level3:101-105` 在 x19..21、y0..55 写 CLIFF，跳过 y17..19、27..29 两个 3×3 门洞；实际 metadata 为三段 `(20,0)-(20,16)`、`(20,20)-(20,26)`、`(20,30)-(20,55)`。`CampaignScenery:85-89` 如果没有 metadata 会回落到旧四段墙，包含横向段，与当前真实通路不一致。必须在 scenery.setup **之前**还原，不是在显示建好后补 metadata。

`CampaignScenery._add_wall:216-243` 对 Level3 使用 `Stockade.panel_count`，其数量和 `end_local` 来自 `map.project`（含高度），墙高52、self_modulate=(.76,.78,.76)、贴图 route=`stockade_segment`、z_as_relative=false、投影深度 z_index。这要求先恢复高度再构造墙。还需重建 `_walls` 实例数组，不是只画相同数量图块；其 `_process:270-276` 遮挡淡化会使用 `_walls`。

场景不仅有墙：最终 `CampaignEnvironment.decorate:197-201` 增加李家庄、扈家庄、祝家庄三个 `StorySign`；`231-232` 增加专用祠堂 scoped object。`CampaignScenery:47-84,115-130` 增加 campaign_object/route/state/fallback metadata。原 SceneryState 只有少数 metadata keys，扩工厂时须逐类对齐，不能悄悄删除这些标记或跳过 StorySign。`_style`、基类 `_sprites/_trees/_ground_shadows/_visibility_tick` 与墙 runtime可见性/alpha 属于场景层状态。

**两个门的准确额外字段**（`campaign_gate_visual.gd:14-23`）：

- `campaign_gate_wall_span=Vector2(0,128)`。
- `art_variant=zhu_gate_native_20260906`。
- `campaign_gate_source_left=(1322/1536,647/1024)`、`campaign_gate_source_right=(230/1536,935/1024)`。
- `campaign_gate_visual_height=180.0`、`campaign_gate_texture_tint=Color(.60,.70,.83)`。
- 通用 Unit 显示名分别为“祝家庄正门/偏门”；占地 `fcell/fhalf/footprint_blocked`，渲染高度 `render_height`，运行中的屋顶遮挡 `environment_roof_alpha` 也必须保留。

开偏门路径 `level3:329-335` 是 `inside_open=true → unregister footprint → resolve_story("retreated")`，**不销毁 Unit**。`unit.gd:4435-4455` 设置 story_outcome、hp至少1、停令/passive/stance、hidden，然后发 story_resolved。`Battle:17156-17176` 清理选择/目标/施法并调用关卡钩子，没有从 units 删除。恢复后应仍有隐藏的 side_gate Unit、同一 Level 引用、`story_outcome=retreated`、`footprint_blocked=false`。按“不可战斗”剔除此节点或重新注册占地都会变更真实世界。

正门/偏门强拆则经过 died：先释放占地并排队释放建筑节点（`Battle:2300-2319`），再触发 Level 的 main_breached/story event/blocked action。稳定屏障后释放引用可编码为 null；不能将尚未排空的 queue_free 半状态判为可恢复。

## 4. Mission 和终局真正依赖的对象身份

- 原始动作顺序：on_start 的 recon/rescue；探索/夺矿/拆外营触发 `_introduce_sun` 追加 inside+actor locator；救人追加两个 Level button 和前营地图 locator；满足时迁回营条件后再追加 finish action。必须以 Presentation 保存的实际顺序/descriptor恢复，不能根据最终 stage 猜排列。
- `_rescued_members:357-361` 每次读取当前 prisoners，检查 `_alive`、faction0、非captive、非garrisoned。`activate_mission_button:368-377` 依赖新 Battle.phase、新地图和新 Unit.position，只选人/镜头不发移动命令。
- 释放囚徒仅设置 faction0、is_captive=false、is_hero=false、speed82、art_variant空；保留原 is_noncombat/passive/atk0/空ability/空slots（`264-279,337-350`）。不能把获救者重新从默认英雄 defs 配置成战斗英雄。
- `_finish_ready:506-507` 依赖 manor_fallen、prisoners_freed、活的 hall、prisoners[0]和距hall<190；finish action还要求 actor与 `song` 是同一实例。on_unit_died 用对象相等判定 hall/song/时迁必败，其他门/外营/大营控制事件和后续路线。因此所有引用必须映射至新 graph，不能保留旧实例或仅按显示名临时搜索。
- Mission 的事件集合和结果冻结状态与 Level 布尔量必须来自同一屏障；不能重放 on_unit_died/on_unit_resolved/on_mission_action 来“补齐”状态。
- `Battle._complete_end:4345-4361` 冻结 Mission.result_snapshot，再依据 `_official_context.mode==campaign` 调 Campaign.on_level_won、Steam.settle，最后任务战报与下一关按钮。`Campaign.on_level_won:161-172` 会更新解锁记录；`Battle.next_campaign_chapter:17179-17184` 依赖全局 Campaign.current。战役恢复事务必须明确同时安装/回滚的上下文与当前关索引，以及继续局的终局闭合/奖励策略；LevelState 的正确性并不能证明该层安全。

## 5. 最小真实世界验收切片（建议）

至少覆盖初始七囚徒+可被擒扈三娘、偏门已开但Unit仍存、正门被毁、孙立已出现/已死、救人后当前选择与撤离命令、外营已断援且已有raid仍在场、大营已毁且finish action已出现等切片。每片验证完整单位ID/Level引用、两条门洞导航与block_count、墙/牌匾场景、按钮指向新实例，并在恢复后的真实FIGHT步骤观察不会重复出兵/发奖/创建动作。现组件 fixture PASS 不能替代这些世界级验收。
