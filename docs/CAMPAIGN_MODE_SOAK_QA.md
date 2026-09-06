# 30 分钟模式切换稳定性验收

2026-09-06：已适配当前高俅 `gao_lure_side`，并补齐六条路由的实际移动/交战和完整停留证据。120秒预检实际123.91秒、14次切换、88项通过；这次只验证工具，正式1800秒验收仍待重跑。结果及原始证据见[持续打磨基线说明](POLISH_BASELINE_20260906.md)。

2026-09-05 起，Godot 位置由 `tools/resolve_godot.ps1` 解析：可继续传 `-GodotPath`，或配置 `GODOT_PATH` / 根目录 `godot.local.txt`。不再默认访问办公室绝对路径；启动前先用 `tools/run_local.ps1 -Mode import` 准备导入缓存。家里接续只验证路径与启动，未重新运行本页的 30 分钟验收。

入口是 `tools/run_campaign_mode_soak.ps1`。它先确认系统里没有其他 Godot 进程，再用 1280×720、Vulkan、`forward_plus` 启动真实渲染测试。默认运行 1800 秒，实际总耗时通常为 30—32 分钟，另加数秒日志整理时间。

测试循环为：战役 level1 → 竞技场 → 遭遇战 → AI 对战 → 自定义据守 → 战役 level5。每一项都实例化正式 `scenes/main.tscn`，经 HUD 信号进入 `FIGHT`，完成停留后 `queue_free`。竞技场调用已有出兵按钮；据守使首波计时到期，由正常关卡更新派兵；AI 对战只向官军战斗兵下进攻令；level5 实际选阮小七并右键 `gao_lure_side` 旗标，由正常航行触发侧港诱舰。记录移动/伤害和任务进展，不能以短停留未完成的任务冒称完成。每次退出都用弱引用检查 Battle、关卡对象、任务控制器、地图、HUD、世界、相机、单位根节点和一个样本单位已经释放。

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

完整验收要求：实跑不少于 1800 秒；至少 30 个完整分钟桶；各分钟 P95 不超过 16.7ms、P99 不超过 33.3ms；所有关键节点释放；预热后没有超过容差的持续单调增长，结束资源回到预热基线容差内；测试不会调用保存入口，`campaign.cfg` 存在状态和字节必须完全不变；进程退出码为 0，且日志没有匹配到脚本错误、泄漏、孤儿节点、RID、TextureStorage 或 RenderingServer 销毁警告。

只调试工具时可以缩短，但结果不会被记作 30 分钟验收：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_campaign_mode_soak.ps1 -DurationSeconds 90 -AllowShort
```

这项测试只证明真实渲染下的模式切换、资源释放和稳定性，不代替真人试玩，也不产生节奏或平衡结论。
