# 大名府场景恢复接入设计与验收清单

2026-10-07：趁共享引擎被占用完成源码审查。当前仅完成源码契约与检查工具；没有运行 Godot，没有完成场景恢复，没有开放战役继续入口。

## 已确认的生产来源

`Campaign.LEVELS` 与 `run_campaign_level_state.gd` 均指向 `level8_daming_rts.gd`。当前地图为 60×66、town，第八关 RTS 关卡；旧 `level8_dongchangfu.gd` 的 60×52 地图仅提供部分绘制/装饰方法，不能作为恢复时的关卡身份。

构建顺序为 `level.decorate(map)` → `map.enable_campaign_environment(level.id())` → `CampaignEnvironment.decorate` → `CampaignScenery.setup`。恢复的固定工厂必须使用已保存、已变换后的装饰列表，不能再调用 decorate 重复追加灯市、房屋、路面装饰，也不能调用 deploy/Mission/奖励回调。

原生地图位置仍是寻路坐标；`sync_render_position` 仅更改 RenderingServer 变换和高度元数据。墙体与通道恢复后须恢复同样的渲染变换，不能把显示高度写入逻辑位置。

## 场景结构契约

| 内容 | 当前来源契约 | 恢复要求 |
|---|---|---|
| 夜景 | 一个 `CanvasModulate`，名为 LanternNight，颜色 (0.62,0.67,0.79) | 单独的固定节点类型与字段合同；不是地图材质 |
| 地形色调 | scene_tint=(0.72,0.77,0.87) | 与夜景调色独立保存、重捕获 |
| 灯市灯 | (27,12)、(33,20)、(27,27)、(34,33)，energy=0.55 | 四个固定槽位，不套用翠云楼的动态亮度 |
| 翠云楼灯 | (37,15)，初始 energy=0.45，signal 状态=1.15 | `_cuiyun_light` 必须绑定新世界中的对应灯，不能绑定火点 (35,16) 或灯市灯 |
| 光照资源 | 五盏灯共享本场景 `_lantern_texture` | 每个新场景新建一个渐变资源；同场景引用相等，旧新世界资源实例不同 |
| 城墙 | 外城 94 段、封闭偏门 1 段、牢院 18 段，共 113 段 | 这是源码公式推算，尚非 Godot 图形结果；end_local/height_scale/salt 与原固定工厂严格相等 |
| 偏门 | RTS paint_map 设置 campaign_city_wicket_sealed=true，当前是墙 | 禁止创建旧关卡的 (33,39) Passage |
| 牢门 | 一个 Passage，(19,20)，caption=牢门，object_key=prison_gate | map 指向新地图，`_walls` 引用该新节点；不能重复创建静态 prison_gate Sprite |
| 南门 | 原 `zhu_gate` Unit，由建筑占地控制通行 | 不创建额外 Passage；与已有 Unit 图和地图导航一起验收 |
| 人群 | 灯市有 StoryCrowd，固定 variant、方向、贴图 | 现有 adapter 仅允许 level2 StoryCrowd；level8 需独立授权范围与原工厂字段合同 |

渐变固定值为 128×128、WHITE→透明黑、radial、fill_from=(0.5,0.5)、fill_to=(0.5,1.0)。灯的 texture_scale=1.8、color=(1,0.68,0.32)、shadow_enabled=false。实现时还须从原始新建资源核对偏移、插值与其它属性，不能只凭上述数值放行任意 GradientTexture2D。

墙的 `_mesh` 由字段推导，不接受存档中的外部 Mesh/Resource 路径；固定工厂重建，首次绘制生成原几何。现有 factory 没有写入 wall.salt，原值为 0。外城高度 108，牢院 height_override=62；不得统一改成一种高度。

## 动态状态与一致性

1. `_open_prison` 先写 prison_open，再通过 `block_footprint(PRISON_DOOR,0,false)` 改变实际导航。Passage._process 从地图 land 通行性更新 `_open`，不是从 rescued 判断。入牢已放行而尚未救人的状态必须单独测试。
2. `daming_fire` 将 signaled=true、signal_left=90，并调用 `set_story_object_state(cuiyun_tower,signal)`。process 将 signal_left 降为零并调回守军，但没有熄灭灯光调用。恢复不能把计时到零解释为翠云楼恢复 energy=0.45。
3. 牢门静态 decor 被 setup 跳过，图像由 Passage 按 `_open` 绘制。营救回调中的 prison_gate 状态设置不能替代真实 Passage 导航/缓存恢复。
4. 场景可见缓存更新发生在独立处理回调。捕获点如果位于导航改动与 Passage 刷新之间，必须明确拒绝不稳定时点或保留原缓存，并在最终世界激活策略中验证；禁止为了比较成功而修改原世界 `_open` 或让测试隐式跑物理。
5. 保存 `_walls/_sprites/_trees/_ground_shadows` 的原遍历顺序、引用归属、重复/缺失检查，以及 `_lantern_texture/_cuiyun_light`。不将 Object 实例或运行时 RID 写入持久化值。

## 当前缺口与接入顺序

源码检查确认现有 `run_scenery_state.gd` 的 installed context 未包含 level8、明确拒绝 lantern owner、缺少 CityWall/Passage 类型、StoryCrowd 只允许 level2。这些是尚未接入的功能边界，不是已经修复的运行缺陷。

1. 先完成现有 Gao v20i 实际完整地图复捕获；本轮不改其三个冻结候选源码，不覆盖既有 producer、日志或失败收据。
2. 在新命名候选中加入 level8_scenery_state_v1，绑定真实 RTS script、60×66/town、sealed wicket 及固定原场景工厂。默认上下文、旧版 Level、错误地图/元数据类型均拒绝。
3. 接入上述四类节点、生成渐变的有限专用描述、完整 owner 归属与同步失效清理。保留禁用处理/屏蔽信号的阶段化恢复，先验证全部固定结构再应用动态字段。
4. 完成以下真实原关卡状态的地图/场景捕获→禁用新 owner 重建→精确完整重捕获，并核对五套导航、RNG、经济、Units、Mission 没有工厂副作用。
5. 恢复已有 Gao、classic 标准图与现有 campaign scenery 的回归，随后接 Battle root/core/FX/Mission 和独立进程继续；本组件通过不代表玩家可继续战役。

## 待执行原生测试矩阵

| 用例 | 必须检查 |
|---|---|
| 初始 RTS | 113 墙、1 Passage、5 盏共享纹理灯、牢门关闭、翠云楼 0.45、偏门封墙 |
| 入牢放行但未救人 | prison_open=true、rescued=false，真实牢门导航可通，Passage 缓存与原捕获阶段一致 |
| 举火 | 原 on_mission_action 成功，signaled、计时、楼体贴图及能量 1.15 同步，四灯仍 0.55 |
| 火号计时结束 | 原 process 完成调回守军，楼灯仍为 1.15；不把 signal_left==0 当作熄火 |
| 强攻开门并救人 | 真实南门 Unit 占地解除、牢门导航、伤员状态、贴图、owner 引用恢复一致 |
| 跨场景资源 | 每个新工厂独立渐变实例，场景内五灯共享；新 Passage.map/树/墙/灯不引用旧世界 |
| 损坏快照 | 错关卡、52 行地图、浮点 waves、伪 sealed 元数据、漏灯/重灯/错楼灯、外部纹理、错墙高度、伪 Passage.map、重复 prison sprite、缺少人群均拒绝 |

接触摆位和提前触发任务只可作为显式夹具；单组件测试不能冒充自然通关、独立进程保存继续或发行包验收。

## 本轮可复核产物

- `qa/zhu_wounded_20261005/harness/audit_daming_scenery_source_v21a.py`：仅用 Python 读取固定生产来源，检查真实选择、工厂顺序、灯/墙/通道合同。无需 Godot、无玩家文件写入，不重复覆盖收据。
- `qa/zhu_wounded_20261005/daming_scenery_source_audit_v21a.json`：39 项源码合同检查通过、9 项错误来源变体全部被拒绝，11 个输入前后字节相同，报告记录各文件 SHA。明确 runtime_qualified=false、restore_qualified=false。
- 初次检查工具误用了不存在的 update 名称，实际方法名为 process；原 v21 producer 和失败记录保留，修正工具另存 v21a，没有改生产脚本。

复查命令（`python` 使用本机配置的 Python，输出必须是全新路径）：

```powershell
python -B qa/zhu_wounded_20261005/harness/audit_daming_scenery_source_v21a.py --out E:/ChatGPT/daming-source-audit-new.json
```

该检查是来源审查，不是 GDScript 类型/图形解析或恢复资格验证。全部下一阶段引擎验收仍待执行。
