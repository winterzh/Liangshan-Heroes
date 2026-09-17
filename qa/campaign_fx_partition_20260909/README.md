# Level3 MissionMarker / FX 分区组件原生验证

当前回归批 [`20260909_083711_bf4595d7`](20260909_083711_bf4595d7/receipt.json) 在景物显示 v2 修复后的共同生产来源上重新通过 **622 项（593＋29）**。行为进程 37204、43492；8 条阶段守卫通过，真实玩家摘要未变，退出后无引擎且锁释放。2956 当前/私有来源共 5912 次哈希与 40 项归档（2,788,463 字节）由 [independent_readback](20260909_083711_bf4595d7/independent_readback.json)再次核对。fixture SHA 为 `5faba3fc44ce61e93192524219de800b0437b4d2a4a37bd900af2d32cce5218d`，生产者与组件 PID 一致、重启 PID 不同。下面五次尝试与详细表格保留其原批语境；通过数不叠加，实际行为范围未扩展。

本目录保留四次失败与一次通过。最终批 `20260909_082134_a2a621de` 的 `complete=true`，组件进程 593 项、重启进程 29 项，共 **622 项检查通过**。这是两个独立原生进程中的组件恢复证据，完整世界、正常关卡玩法、真实 Steam、人工视觉验收均未通过本批验证；报告明确保留 `component_only=true`、`full_world=false`、`normal_gameplay=false`、`real_steam=false`。622 是断言数，不是 622 个玩法场景。

## 实际范围

驱动使用真实 Battle、Level3、Mission、Presentation、Visual 和普通 Unit 类，在私有暂停壳上构造 `synthetic_fixture=true` 的场景。HUD 为继承实际 CanvasLayer HUD 的 `QuietHUD`，其 `_ready`、选择面板、命令刷新和消息显示由 QA 覆盖。地图是 QA 初始化并 bake 的 64×56 平地，未运行关卡 paint、deploy 或 on_start，未生成祝家庄正常任务世界。

fixture 内实际有一个普通 `liang_dao` 单位，以及 7 个 Visual 记录：2 个 container（含根）、2 个 FloatLabel、2 个真实 MissionMarker、1 个 BoltFx。**Projectile 数量为 0**，不据此声称在途伤害、抛射物命中、技能队列或完整战斗恢复已经通过。

- 标记由真实 Mission API 创建，包含两个 action 和一个地图定位按钮；QA 显式设置数字、旋转、缩放、颜色、优先级、第二标记隐藏和按钮禁用状态。普通单位由 `spawn_at` 创建，恢复为新进程的新对象；本批使用经典普通单位子集，不证明 Level3 特殊角色引用已经整合。
- Visual 只创建其拥有的 5 个节点，两个外部标记由 Presentation 创建并按 token 绑定。验证混排顺序、嵌套关系、对象身份、元数据、激活计划、未完成布局拒绝、跨帧暂停布局、显式激活及失败清理。经典默认路径仍拒绝 MissionMarker，并接受普通效果。
- 非默认标记状态、可选 `render_height` 缺省、真实 CanvasLayer 父节点布局，以及被禁用 ready 信号留下的原生清理连接均在最终批覆盖。错误 ready flags 必须得到 `PRESENTATION_EXTRA_SIGNAL`；未知嵌套子节点必须得到 `VISUAL_ACTIVATION_TOPOLOGY`。
- 报告中的 “restored real action button invokes new Mission” 实际只检查连接 Callable 的对象是新 Mission，未发出 pressed，也未完成真实任务行动。FloatLabel/BoltFx 续时检查由 QA 显式调用 `_process(0.01)`，不是解除暂停后的自然运行。Battle 没有模拟时钟或保存 barrier；固定阶段时间及重基准值只用于组件配对，不证明完整世界时钟恢复。
- 本批未接 ContinueFlow、战斗槽、Root/HUD 整体事务、关卡成绩、终局收益或 Steam 待发送确认；完整世界验收数量为 **0**。无截图，`visual_inspection=false`，图形进程运行不等于人工目检。

## 五次原生尝试

| 批次 | 结果 | 原始失败或通过内容 |
| --- | --- | --- |
| `20260909_080147_f7fd4a1a` | 失败，component exit 1，错误 0 | 4 项中实际 Presentation 捕获失败：`PRESENTATION_UNSUPPORTED_PROPERTY` / `PanelContainer/layout_mode`。真实 CanvasLayer 与旧 Control 模板父节点语义不一致。 |
| `20260909_080518_0aa7f408` | 失败，component exit 1，错误 2 | 平地标记合法缺少 `render_height`；旧读取方式产生两条原生 get_meta 错误，runner 终止。没有完整行为报告或 fixture。 |
| `20260909_080829_329b8cb3` | 失败，component exit 1，错误 1 | QA `record_negatives` 未先检查编码结果就访问 `value`，产生脚本错误；这是测试夹具构造故障，不能算 Visual 正确拒绝。没有完整行为报告或 fixture。 |
| `20260909_081640_9dc16458` | 失败，component exit 1，错误 1 | 保存了 371 项的失败报告和 fixture。16 个正常激活检查被未识别的原生 ready 清理连接拒绝；另有 QA cleanup 对已释放实例作类型赋值的脚本错误。未执行 restart。 |
| `20260909_082134_a2a621de` | 通过，593＋29 项 | 四阶段按预期退出，原生错误 0；完成组件生成、独立进程重启、分区恢复、负向拒绝和清理。 |

前四批 `receipt.complete=false` 原样保留。第四批部分只检查 `not ok` 的负向断言会因无关 ready 错误而单项通过，但其随后正常激活断言失败，整批始终失败。最终批修复后，突变撤销后的正向激活均通过；编码负向用例先断言编码成功，避免把夹具错误计为拒绝成功。多数负向用例仍只证明“拒绝”，不声称逐条错误码都被验证；仅上述两类有精确错误码断言。

## 最终批证据链

| 阶段 | Popen PID | 退出 / 预期 | 原生错误 | 行为检查 |
| --- | ---: | ---: | ---: | ---: |
| import | 47076 | 0 / 0 | 0 | — |
| profile_guard | 26228 | 2 / 2 | 0 | 私有 profile 故意不匹配，拒绝且不写报告 / fixture |
| component | 20628 | 0 / 0 | 0 | 593 |
| restart | 12660 | 0 / 0 | 0 | 29 |

`component_report.json.pid=20628`、`restart_report.json.pid=12660` 与各自 Popen 记录一致且不同。fixture 的 `producer_pid=20628`；两报告的 `snapshot_producer_pid` 和 `snapshot_sha256` 均指向同一生产者和同一文件。fixture SHA-256：

```text
b1a513aa97f7b86b5b0f798b80b3cd0d4d83168c00e1894aa5bddb6b24658e6f
```

每个阶段前后各有一次 `phase_guards`，共 8 条，检查独占锁归属、没有残留引擎、源码集合一致、当前 / 私有源码哈希、引擎与场景哈希。全部通过。末尾确认 `lock_owned_at_release=true`、`lock_released=true`、`engines_after=[]` 后才写最终 receipt。玩家数据保护只归档前后文件数 / 聚合摘要：APPDATA 167 个文件不变，LOCALAPPDATA 对应目录不存在且不变；未归档真实玩家文件名或内容。

最终 `source_files` 有 2956 条，当前与私有副本共 5912 次核对零差异。`source_snapshot` 保留 32 份关键来源（含生成场景）。`source_head=dca4e4e6a0682edb0336fc9b90c77d6aca3193bc` 是运行时 Git 基线；本批未提交改动的精确来源以清单哈希为准，不能只用 HEAD 复现。

| 受测来源 | SHA-256 |
| --- | --- |
| `scripts/run_campaign_presentation_state.gd` | `f447bae90fea73f64b2c50376c2b470cd1279cff46661275587996820d72c8d7` |
| `scripts/run_visual_graph.gd` | `b365fa28b2e931ab654aa68a3ececfd8138e5a2ed0183003514775b1963f2fb3` |
| `tools/campaign_fx_partition_qa.gd` | `09e6e3874951a3b8bc2b2afd318397476c68e80431e997805d7ac2cfaaff61a1` |
| `tools/run_campaign_fx_partition_qa.py` | `88379331655b9ca9342cb2c1ba3657403c7f3f06eb69e92e82e1a72793ee9c94` |
| Godot 4.6.3 原生引擎 | `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00` |

各批 receipt 的 `files` 清单分别含 37、36、36、38、40 项；独立只读复核共 187 项大小和 SHA 一致，已有报告 / fixture 与私有原件一致。最终清单 40 项合计 2,788,463 字节，不含 receipt 自身及后加的 `independent_readback.json`；这两项不回填或改写历史清单。最终批独立回读摘要见其 [independent_readback.json](20260909_082134_a2a621de/independent_readback.json)，原始结论见 [receipt.json](20260909_082134_a2a621de/receipt.json)。

## 受控复跑

在开发工程根目录运行；默认只预检，不启动引擎：

```powershell
py -3.14 -X utf8 -B tools/run_campaign_fx_partition_qa.py
```

确认全生产来源冻结且共享引擎空闲后，串行执行：

```powershell
py -3.14 -X utf8 -B tools/run_campaign_fx_partition_qa.py --run
```

引擎使用本机配置解析，可通过 `--godot` 明确指定。默认私有工作根为 `D:/CodexTemp/campaign_fx_partition`，可用 `--work-root` 指定受控目录。runner 为每批新建独立 project/profile，设置 `STEAM_DISABLED=1`、`CAMPAIGN_QA=1` 和四个私有系统目录；不会复用真实玩家 profile。import / profile_guard 使用 headless；两个行为进程使用 GL compatibility、1280×720、Dummy 音频。runner 使用共享独占锁，保留失败日志、可用报告、fixture 和来源快照；不能与性能测量或其他 Godot 验证并行。
