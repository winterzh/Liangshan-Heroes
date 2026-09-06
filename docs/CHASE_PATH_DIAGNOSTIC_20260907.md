# 追击重寻窄诊断：停止 fallback 假设

本轮真实诊断的结论是 **`stop_no_fallback`**。在约定的两次 M1 窗口内，没有发生“普通寻路失败后进入远程 fallback”的调用链，因此停止把该链作为当前生产优化候选。没有改生产寻路频率、导航规则或性能验收标准。

| 窗口 | 测量物理步 | strict 调用 | fallback 调用 | strict 完整方法观测均值 |
|---|---:|---:|---:|---:|
| timed | 602 | 1,840 | 0 | 185.686 µs/物理步 |
| clockless | 597 | 1,750 | 0 | 不计时，null |

timed 实际测量 tick 为 303–904，排除 302 个预热步；clockless 为 305–901，排除 304 步。两个入口配置都是 10 秒窗口，统计遵循真实 M1 起止锚，没有硬切第 300 行。前 600 物理步代表最多 10 秒模拟量；clockless 只有 597 步，未补造剩余数据。

观测范围仅为冻结 `4baafc1` Unit `_do_chase` 的直接 strict 重寻点及紧邻远程 fallback，排除其他订单、追击退出转换、`_follow_path` 阻挡重寻与 watchdog。timed 的 strict 方法累计 111,783 µs，均值包含探针开销；其中 AStar 累计 16,755 µs 是嵌套部分，不能再相加，也不能把 185.686 µs 当成可全部消除的收益。两个模式都有计数、作用域和时钟锚；不能用其差值扣出正常 FPS。既有约 500 µs/步筛选阈值没有变成游戏性能验收线。

另有两个串行实际 GameMap 进程进行行为对照：baseline 的成功检查计数为 55，candidate 为 88，报告均 complete、failures 为空；离线比较器给出 186 项显式检查通过。两者覆盖同一组 9 个真实地图案例，每个进程执行 13 次原地图方法调用，核对输入、导航/网格状态、返回点顺序与 PackedVector2Array 原始字节。该 candidate 是插桩版本，不是已经实现收益的生产优化。

这份行为证据不等于完整 Unit `_do_chase` 状态等价。仍未独立迫使真实布局进入 `find_firing_path` 的 no_open_target 与 AStar empty ids 两个分支；不得用 stub 补足后宣称真实路径已覆盖。实际 `firing_one_node_final_empty` 案例区分了非空 AStar 节点与最终空路径。

原始 generation 收据记录当时“离线完整分析待完成”，该字段没有回写；之后产生的两份原分析文件和本次独立离线复算分别保留。归档复核确认两份完整分析全部返回字段与现有结果一致，186 项比较也逐字段一致。引擎进程收据、日志、报告/manifest 摘要、记录中的来源/缓存/玩家保护前后关系均已核对；本次归档没有重跑 Godot，也没有重新访问历史私有工程或玩家内容。

证据入口：[归档说明](../qa/chase_path_20260907/README.md)、[结果汇总](../qa/chase_path_20260907/summary.json)、[逐文件哈希清单](../qa/chase_path_20260907/archive_manifest.json)、[归档复核](../qa/chase_path_20260907/archive_verification.json)。原始运行编号为 baseline `20260906T175413610766Z`、generation `20260906T175543040968Z`、candidate `20260906T175746359017Z`。归档不含私有工程、profile、实际玩家文件、缓存二进制和截图。

后续继续处理已有独立性能候选及 M3 基础模块；本轮结果不支持生产 fallback 优化，不构成完整 Unit 状态、正常 FPS 或标准 30 波恢复验收通过。
