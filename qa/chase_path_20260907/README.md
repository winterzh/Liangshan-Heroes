# Chase 寻路诊断实测归档

本批结论为 **`stop_no_fallback`**，没有形成生产优化。真实窗口及 Map 行为结果见 [summary.json](summary.json)，逐文件原始来源、字节数和 raw SHA 见 [archive_manifest.json](archive_manifest.json)，本次复制与离线复算见 [archive_verification.json](archive_verification.json)。

| 证据 | 结果 |
|---|---|
| timed | 602 个测量物理步，1,840 次 strict，fallback 0；含探针 strict 方法平均 185.686 µs/步 |
| clockless | 597 个测量物理步，1,750 次 strict，fallback 0；耗时为 null |
| baseline / candidate | 真实 GameMap 检查计数 55 / 88，分别 PID 15688 / 27328 |
| 离线对照 | 186 项显式检查通过；9 个案例、每进程 13 次原生地图方法调用，逐点和 PackedVector2Array 字节一致 |

这是 `_do_chase` 直接重寻及紧邻远程 fallback 的窄诊断。185.686 µs 包含 observer 开销；AStar 是嵌套子项，不能相加。clockless 不能用于估算固定探针成本或扣出正常 FPS。行为案例调用真实 Map 与 observer，未覆盖完整 Unit `_do_chase` 状态转换。没有完整 Unit 等价、性能验收或 30 波续玩通过的结论。

历史 generation receipt 中 `full_offline_analysis_pending=true` 保持原样；同代的原始 analysis.json 已完成离线分析，本次又从原始 m1/report 重算并逐字段核对一致。不能为了让旧收据看起来“最终通过”改写历史。

目录含 `baseline/`、`candidate/`、`diagnostic/` 原始收据/报告/必要日志和来源清单，`code/` 保留原分析器、比较器、探针及必要参考/运行器源码。GD 以 `.txt` 保存并有根 `.gdignore`。`*_cache.json` 仅为路径、字节数、摘要清单，不含缓存内容。未复制私有项目、profile、玩家文件、缓存二进制或截图。

可从仓库根目录离线复算到全新的输出文件，不启动 Godot：

```text
python qa/chase_path_20260907/code/diagnostic/analyze.py qa/chase_path_20260907/diagnostic/timed/m1_10s.json qa/chase_path_20260907/diagnostic/timed/report.json --out scratchpad/chase_timed_recheck.json
python qa/chase_path_20260907/code/diagnostic/analyze.py qa/chase_path_20260907/diagnostic/clockless/m1_10s.json qa/chase_path_20260907/diagnostic/clockless/report.json --out scratchpad/chase_clockless_recheck.json
python qa/chase_path_20260907/code/behavior/compare.py qa/chase_path_20260907/baseline/report.json qa/chase_path_20260907/candidate/report.json --out scratchpad/chase_behavior_recheck.json
```

原运行器源码用于审查来源与生命周期，不能直接从本归档恢复运行私有工程；收据中的绝对历史路径保留原文，并不代表这些工程或全部上游历史已同步。正式结论见 [设计记录](../../docs/CHASE_PATH_DIAGNOSTIC_20260907.md)。
