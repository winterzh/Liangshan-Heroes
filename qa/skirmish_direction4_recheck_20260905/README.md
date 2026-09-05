# 驻守战四向与死亡残留独立复查（2026-09-05）

## 结论

资源接入有效，但视觉验收不通过。本次复查发现 6 类待修问题；此前动作合同、文件哈希和资源命中检查的通过结果，不能证明朝向语义、动作连贯性和比例正确。

本轮只增加本目录下的诊断脚本、截图、日志和报告，未修改生产脚本或美术，未导出或上传 Steam。历史 QA 记录保留；涉及“助手视觉通过”的判断以本报告所列问题为准。

## 待修问题

### 1. 优先修：弓手 SW 待机与行走朝向错误

`guan_gong_walk_sw.png` 中 idle 和 walk_step 的人物面向屏幕右侧，中间攻击帧却向左射箭。真实 Unit 绘制中可以看到“朝右待机 → 转左射箭 → 转回右侧”。SW 的方向约定应为屏幕左下，不是文件名可以代替的语义验收。

- 证据：[真实弓手状态矩阵](archer_actual_walk_attack.png)，第二列 SW。
- 代码：`scripts/campaign_art.gd:198` 方向映射；`scripts/unit.gd:1800` 攻击朝向、`3520` 攻击取帧。
- 影响范围：SW walk、attack 起止帧、death 首帧共用错误 idle。
- 建议：按既定内置浏览器绘画流程重做 SW idle 和 walk_step，再重组相关条带；不能靠镜像修补。

### 2. 血迹及遗落装备比例过大

真实 Unit 的默认尺寸下，血池明显大于人物，头盔、盾牌残片接近甚至超过整具倒地人物。当前按单位半径统一计算 48–78 的 mark_size，再给头盔 0.96、盾牌 0.92 的系数，没有按实际装备尺寸校准。降低装备出现概率无法修正其单次大小。

- 证据：[弓手死亡矩阵](death_guan_gong.png)、[骑兵死亡矩阵](death_guan_qi.png)。
- 代码：`scripts/battle.gd:106` 类型缩放、`2186` 尺寸计算。
- 建议：分别校准血池、头盔和盾片，不改变单位本体大小；同时检查每方向倒地后的血池落点。当前通用方向偏移没有使用实际倒地贴图的身体中心。
- 注意：矩阵各列是不同受害者，装备类型随种子变化；不能把列间不同残留解释为同一尸体更换装备。

### 3. 帧内锚点不一致，切帧时产生额外偏移

拼图管线为避免越出 256×256 画布，对不同帧施加不同 fit_shift；运行时仍统一使用 `Rect2(-s*0.5, -s*0.82, s, s)`，没有消费逐帧 placed_anchor。

- `guan_gong attack_nw` 中间帧锚点 y=229，idle 为 210，相差 19 源像素；`guan_qi walk_ne` 的锚点 x=112，idle 为 128，相差 16 源像素。
- `guan_gong death_se` 的 fall 与 down placed_anchor 分别为 (86,210)、(166,201)。这表示合成时平移差 (+80,-9)，不应直接当作同一个解剖接触点移动 80 像素；两种姿势的接触部位也不同。
- 证据：本批 `qa/skirmish_direction4_actions_20260905/staging/candidate_manifest.json` 的逐帧放置元数据；本目录动作、死亡截图。
- 代码：`tools/skirmish_direction4_action_pipeline.py:840` 放置逻辑；`scripts/unit.gd:3333` 固定画布。
- 建议：统一可比的承重点与动作轨迹；必要时扩大统一画布或接入逐帧偏移，不能让“塞进画布”的位移变成动画动作。

### 4. 两种持枪骑兵使用了刀剑特效

`guan_qi`、`guan_jingqi` 都没有明确 weapon_profile，range=26，被 `_weapon_kind()` 的射程推断分配为 SWORD。真实攻击贴图上因此叠加白色刀弧及剑类位移/旋转。

- 证据：[骑兵真实武器效果矩阵](cavalry_actual_weapon_route.png)。运行记录两种单位均 `swing_kind=0`，`SWORD=0`，`SPEAR=1`。
- 代码：`scripts/defs.gd:34`、`120`；`scripts/unit.gd:2069` 推断、`3312` 叠加动作、`3360` 光效。
- 建议：显式配置并实现枪类武器路由，不应通过增加攻击距离去改变武器类型；对真实攻击帧另行校准程序化叠加幅度。

### 5. 致死受击亮色冻结

致死伤害将 `_flash` 设为 0.18（暴击 0.30），随后死亡分支提前 return，跳过闪光衰减。死亡绘制继续使用该值，整段倒地都会偏亮。

- 真实同一受害者在死亡 0.71 秒时 `_flash` 仍为 0.18，见 `runtime_observations.json`。
- 代码：`scripts/unit.gd:919` 赋值、`1078` 死亡提前返回、`1087` 衰减、`3678` 着色。
- 建议：死亡期间继续衰减受击闪光，或在进入死亡时明确清理，保留正常死亡淡出。

### 6. 人物尚在倒地，阴影已被移除

`died` 信号使主控立即从 `battle.units` 移除单位；共享阴影批处理只遍历该数组。但 Unit 节点仍在树内，继续播放约 1.4 秒倒地。

- 本次显示 WorldShadowBatch 后，同一受害者的 contact/cast 实例数由存活时的 1/1 变成死亡 0.71 秒的 0/0；此时 `dying_node_still_in_tree=true`、`dying_node_in_battle_units=false`。
- 证据：[存活](slope_same_victim_alive.png)、[死亡 0.71 秒](slope_same_victim_death_071.png)、`runtime_observations.json`。
- 代码：`scripts/battle.gd:1991` 移除；`scripts/world_shadow.gd:145` 批处理；`scripts/unit.gd:1078` 死亡存续。
- 建议：渲染侧单独保留待淡出的死亡单位，随倒地淡出阴影；不能为保留阴影而把死者重新加入战斗索敌数组。

## 需要进一步打磨，但不是本次新增功能故障

- walk 仅 idle/单侧迈步两帧，attack 仅 idle/strike/idle 三帧，动作仍偏跳，尤其骑兵换枪姿态。
- death 的 idle/fall/down/down 按 1.4 秒均分，致死后先站立约 0.35 秒才倒。
- 血迹在 0.35 秒延时后直接全量显示，没有渐显。可考虑保留起点并增加短渐显，需重新视觉校准；不应把原有“延后显现”测试当作“渐显”测试。

## 已排除的问题

- 48 个正式目标的 SHA-256 与生产清单一致，0 个不匹配；管线 dry-run 通过，写入数为 0，现有目标全部 already_identical。
- 当前精确 death 分支没有同时叠加 fallback 的程序旋转；精确四向帧没有运行时水平镜像。
- 高地贴合正常：场景的 `liangshan_scenery.gd` 每帧为单位同步 render_height。所选最高可通行点 height=90.880981，单位 render_height=90.880981，偏移后血迹 render_height=91.098859。
- 诊断中的 `logical_transform_delta_not_rendered_gap=272.6428` 是未考虑 RenderingServer 渲染偏移的逻辑变换差，**不是画面悬空距离**。已核对实际截图，不将这一数值记为漏洞。

## 本次验证及复现

自动检查：48 个目标哈希复核、管线只读 dry-run；Godot 图形诊断 exit 0、8 张截图全部保存成功，日志无脚本报错。

视觉检查：助手检查真实 Unit 渲染快照，1920×1080、zoom=3、Vulkan、RTX 4060 Laptop GPU。它不是用户本人验收，也不是连续人工操作通关。

```powershell
py -3 -X utf8 -B tools/skirmish_direction4_action_pipeline.py dry-run --config qa/skirmish_direction4_actions_20260905/pipeline_config.json
$godotCheck = 'C:\path\to\Godot_v4.6.3-stable_win64_console.exe'
& $godotCheck --path . --script res://qa/skirmish_direction4_recheck_20260905/runtime_probe.gd --log-file qa/skirmish_direction4_recheck_20260905/runtime_probe.log
```

夹具说明：使用真实 Battle、Unit、take_damage 和 DeathRemains，但冻结逻辑并指定动画时刻。隔离矩阵清空高差并隐藏背景和共享阴影，专查帧与比例；独立的同一受害者高地对照恢复真实地形及共享阴影。本测试不测大波敌军性能，不改变生产代码。

未覆盖：真人 30 波游玩、多人/Steam 构建、大兵海帧时和新修复后的回归。本轮未重复计算全战役完成率，也不重新宣称旧的广义 PASS。

复核基线：生产清单 SHA-256 `5f3ec9c6ab3c44ebd5183e64201322581e99c7206bd45eb86a32307449369f9c`；候选清单 SHA-256 `c704e9659320ebd47707bef3ef883dcd8f1918ed0dc309aaefc17dbb642d0651`。
