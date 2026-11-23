# Windows 模式切换稳定性验收

Windows 候选 `bf99bd12` 实跑 602.669 秒，六入口 96 次进出。战斗活动 96/96，关键节点释放 96/96，战役进度字节一致。最差完整分钟 P95/P99 6.071/8.297 ms。十分钟验收未通过，原因保留在收据。结束菜单节点 74 个，较首轮结束 +0 个。孤立节点 0 个。工作集和私有字节分别较首轮结束 +172.9、+174.1 MiB。在隔离 Windows 离线窗口按一倍速进场。Steam 前台与真人体验待验。 [十分钟成品收据](../qa/battle_entry_timing_20261116/windows_mode_soak_600_bf99bd12.json)

Windows 候选 `f6eab724` 实跑 607.780 秒，六入口 95 次进出。战斗活动 95/95，关键节点释放 95/95，战役进度字节一致。最差完整分钟 P95/P99 13.506/27.810 ms。十分钟验收通过。1v1 的最长进场绘制间隔为 463.2 ms，单次峰值继续跟踪。结束菜单节点 74 个，较首轮结束 +0 个。孤立节点 0 个。工作集和私有字节分别较首轮结束 +31.8、+36.6 MiB。在隔离 Windows 离线窗口按一倍速直接进场。同机同期运行祝家庄短时源码检查和下一候选导出。实体操作、真人感受和 Steam 前台待验。 [十分钟成品收据](../qa/battle_entry_timing_20261116/windows_mode_soak_600_f6eab724.json)

Windows 候选 `7ea5b5d3` 实跑 604.218 秒，六入口 96 次进出。战斗活动 96/96，关键节点释放 96/96，隔离档案未写入战役进度。最差完整分钟 P95/P99 7.988/13.760 ms。十分钟验收通过。结束菜单节点 74 个，较首轮结束 +0 个。孤立节点 0 个。工作集和私有字节分别较首轮结束 +40.8、+44.4 MiB。在隔离 Windows 离线窗口按一倍速运行。条件为直接进场，实体操作、真人感受和 Steam 前台待验。 [十分钟成品收据](../qa/battle_entry_timing_20261116/windows_mode_soak_600_7ea5b5d3.json)

2026-11-17 Windows 默认加载上限 72 FPS。实跑 1808.448 秒，109 次进出，关键节点释放 109/109。最差一分钟 P95 14.123 ms、P99 14.371 ms。旧工具把冷启动读数计入内存趋势。修正后从预热快照起算，原数据回放显示私有内存增加 64.41 MiB，低于 128 MiB 门槛。保留实跑原判定。[72 FPS 长测结果](../qa/battle_entry_timing_20261116/README.md#windows-72-fps-模式切换三十分钟)

2026-11-17 首轮六条路线通过当前菜单和真实渲染器；每条路线实际停留至少六秒，原战场关键节点全部释放。完整 1818.864 秒已归档，关键节点释放 70/70。最差一分钟 P95 16.991 ms、P99 17.293 ms。资源与内存回收均在预热基线容差内，未检出持续单调增长。完整长测未通过。[模式切换长测结果](../qa/battle_entry_timing_20261116/README.md#windows-主菜单模式切换三十分钟)当前启动方式要求清除 LEVEL、SKIRMISH、SKIRMISH_AI、SCREENSHOT_DIR 等直入战斗的环境变量，模式由长测脚本负责配置。

2026-09-06：已适配当前高俅 `gao_lure_side`，并补齐六条路由的实际移动/交战和完整停留证据。120秒预检实际123.91秒、14次切换、88项通过；这次只验证工具，正式1800秒验收仍待重跑。结果及原始证据见[持续打磨基线说明](POLISH_BASELINE_20260906.md)。

2026-09-05 起，Godot 位置由 `tools/resolve_godot.ps1` 解析：可继续传 `-GodotPath`，或配置 `GODOT_PATH` / 根目录 `godot.local.txt`。不再默认访问办公室绝对路径；启动前先用 `tools/run_local.ps1 -Mode import` 准备导入缓存。家里接续只验证路径与启动，未重新运行本页的 30 分钟验收。

入口是 `tools/run_campaign_mode_soak.ps1`。它先确认系统里没有其他 Godot 进程，再用 1280×720、Vulkan、`forward_plus` 启动真实渲染测试。当前 PC 计划默认运行 600 秒。启动、完成最后一场并返回菜单及整理日志另计。可用 `-DurationSeconds 1800` 延长采样。

测试循环为：战役 level1 → 竞技场 → 遭遇战 → AI 对战 → 自定义据守 → 战役 level5。每一项先设置该轮模式，再经原主菜单的异步进场入口装载战场。通过 HUD 进入 `FIGHT`，完成停留后调用同一个 HUD 返回菜单信号，等待主菜单重新就绪。单次场景超时会保存失败报告并退出。竞技场调用已有出兵按钮；据守使首波计时到期，由正常关卡更新派兵；AI 对战只向官军战斗兵下进攻令；level5 实际选阮小七并右键 `gao_lure_side` 旗标，由正常航行触发侧港诱舰。记录移动/伤害和任务进展，不能以短停留未完成的任务冒称完成。每次退出都用弱引用检查 Battle、关卡对象、任务控制器、地图、HUD、世界、相机、单位根节点和一个样本单位已经释放。

运行前关闭 Godot 编辑器及其他 Godot 测试，然后在仓库目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_campaign_mode_soak.ps1
```

也可指定输出目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_campaign_mode_soak.ps1 -OutputDirectory .\qa\campaign_mode_soak_release
```

输出目录包含：

- `campaign_mode_soak.json`：逐次场景构建、开战、单位数量、释放检查；逐分钟进程内存、Godot 对象/节点/资源、纹理/显存/缓冲、draw calls、帧时间 P95/P99；预热基线、峰值、结束回落和单调增长判断；`campaign.cfg` 前后字节摘要。
- `godot_console.log`：完整控制台和退出信息。
- `README.md`：本次结果的简表。

完整验收至少实跑 600 秒，包含 10 个完整分钟。每分钟 P95 不超过 16.7 ms，P99 不超过 33.3 ms。每场释放关键节点，首轮六路线完成后从预热快照核对内存回收和持续增长。测试期间 `campaign.cfg` 的存在状态和字节须保持一致。进程须退出 0，日志须通过脚本错误与资源释放警告检查。

工具调试可用 `-AllowShort`。短测结果只记录调试检查。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_campaign_mode_soak.ps1 -DurationSeconds 90 -AllowShort
```


需要定位慢帧时，在同一 PowerShell 中先设 `$env:CAMPAIGN_SOAK_STAGE_TIMING = '1'`，然后运行上述命令。结束后用 `Remove-Item Env:CAMPAIGN_SOAK_STAGE_TIMING` 清除该开关。报告的 `frame_stages` 按路线与阶段提供采样间隔数、超过 16.7 和 33.3 ms 的数量及最大间隔。进场覆盖点击加载至战场初始化完成，开战覆盖解除剧情弹层和启动首帧，随后进入战斗，退出后的间隔归到返回。计数覆盖完整与末尾不足一分钟的采样。每个分钟样本也附 `frame_stages`，用累计计数的差值区分进场、战斗和退出阶段。工具逐分钟检查阶段样本数与渲染样本数相等。测试工具同步读取初始进程内存后再开始首个帧间隔，分钟墙钟和验收门槛照常执行。

设置 `$env:CAMPAIGN_SOAK_MOUNT_TRACE = '1'` 可在报告加入 `mount_traces`。每条记录从菜单发起进场起计微秒，包含加载反馈、战场与地图和 HUD 挂载、首个单位、场景就绪、首帧和最大渲染间隔的起止。工具检查时间点齐全且顺序正确。 工具在正式计时前等待战役启动校验完成。采样用于进一步定位搭建和绘制的耗时。

这项测试只证明真实渲染下的模式切换、资源释放和稳定性，不代替真人试玩，也不产生节奏或平衡结论。
