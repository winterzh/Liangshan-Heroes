# 首用分析 V2 修正收据

V2 只明确统计口径，不改变旧证据。新增 `scratchpad/analyze_first_use_entry_v2.py` 和原 run 目录下的 `first_use_analysis_v2.json`；旧 analyzer、旧 analysis、原 report、原 completion receipt 均只读，运行前后逐字节一致。没有运行 Godot、修改生产、改动动画候选 pins 或复制镜像。

执行 `python scratchpad/analyze_first_use_entry_v2.py` 已通过。每个阶段、每个完整区间都同时用独立端点覆盖积分与区间归并计算并集；所有 kind 的计数/包含耗时/max、事件嵌套、阶段边界、point 顺序、V1 数值一致性及下面的两项分区恒等式均通过。

| 范围 | 总数 | >100 ms | 区间墙钟 µs | 观测并集 µs |
| --- | ---: | ---: | ---: | ---: |
| 全部插桩事件 | 375 | 不适用 | 不按事件耗时相加 | 按阶段计算 |
| sample 插桩事件 | 85 | 不适用 | 10007194 | 515108 |
| 完整 postdraw 区间 | 127 | 41 | 9822092 | 514901 |
| sample 起点到首个 postdraw | 1 个边界片段 | 不混入完整区间 | 185081 | 207 |
| 末个 postdraw 到 capture end | 1 个边界片段 | 不适用 | 21 | 0 |
| 原 M1 全样本帧间隔 | 128 | 42 | 保留原 `seconds` / `raw_frame_ms` 口径 | 不冒用另一时点的数值 |

`9822092 + 185081 + 21 = 10007194`；`514901 + 207 + 0 = 515108`。前一个 postdraw 比 sample start 早 8 µs，V1 的完整区间条件因此排除了首段；原 M1 首个帧间隔是 185.087 ms。V2 分为 `complete_postdraw_intervals` 和 `m1_full_sample`，分别记录 127/41 和 128/42，并明确两组 callback 采样时刻有数微秒差异，不直接按索引当作同一时点。

旧字段 `sample_slow_over_100ms_count=41` 的数值未算错，名称容易被误读为整个 10 秒样本。V2 不再提供这一含糊的顶层字段；旧文件保留，供历史核对。

李逵事件 311 的 anim miss 为 248224 µs，子事件 312 的 loader 为 248045 µs。两者只计外层一次；其 378355 µs postdraw 间隔的观测并集为 248224 µs。sample 并集进一步由根事件核账为 `502750 + 9628 + 2700 + 30 = 515108 µs`。这仍是插桩路径的墙钟覆盖，不是纯磁盘 I/O 或可保证节省的时间。

生成 JSON SHA-256：`544c61c79a4f7bc02eebcdc054dafd955de26f718b917d71682aed5b1a7a9d7e`。新 JSON 记录新脚本 SHA、四份原文件 SHA，`acceptance_eligible=false`；来源仍是首用诊断 `4baafc1`，未把它重标为当前普通版。

## 动画预加载单对入口附记

只读 `scratchpad/animation_load_candidate/runs/20260906T144121187083Z/receipt.json`；来源 `06c2c69`，同一 driver/helper、普通效果、固定镜头、各 10 秒，两窗口完整性通过，初始部署/输入摘要一致，来源与玩家配置前后未变。未在此扩展复验。

| 模式 | FPS | P95 ms | P99 ms |
| --- | ---: | ---: | ---: |
| none | 29.57 | 77.461 | 137.648 |
| current_units | 27.98 | 70.556 | 94.951 |

candidate 准备墙钟 655671 µs，调用原 Art API 64 次，纹理监控增量 24284160 字节（约 23.16 MiB）。这些是开战前付出的加载时间和缓存费用，不能从测量窗口里省略后声称免费收益。

本单对只观察到 P95/P99 尾帧指标改善，平均 FPS 未改善；两窗口物理步也不同（605/603）。不能据此证明稳定因果收益，不能据 4baafc1 的旧 248 ms 推断当前普通版已消除全部卡顿。本次不晋级生产、不达性能验收，也不宣称覆盖真实驻守日后招募/召唤/死亡动作的首次加载。
