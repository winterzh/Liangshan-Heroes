# 首用单窗分析只读复核

结论：本次 375 事件、分阶段汇总、sample 85 事件与嵌套去重数值正确，可以作为后续归因实验的依据。没有发现 248 ms 双算。发现一处需要收窄字段/文案口径：`sample_slow_over_100ms_count=41` 只适用于 127 个完整 postdraw 区间，不能称整个样本的慢帧总数；原 M1 的 128 个测量帧间隔中有 42 个超过 100 ms。

只读范围：`scratchpad/analyze_first_use_entry.py`、本次 `report.json`、`completion_receipt.json`、`first_use_analysis.json`，以及完成收据指向的镜像里两个 `_first_use` GD 的有关计时/阶段行。不执行分析原脚本（它会写回分析 JSON），不运行 Godot，不做目录复制或大范围哈希，不修改冻结动画候选/首用工具/pins/原报告。本次唯一文件写入是本 review。

## 独立复算

对 324672 字节原 `report.json` 的 SHA-256 复核为 `cd5dcce98b337ed8eedf205c2833e6397922ac650e8f04afee18bc07ec255926`，与分析记录一致。来源是 `4baafc11af55b0e46a57a48e54df181b8c1917a2` 的诊断镜像，不能当作当前未插桩普通版。

没有调用原脚本的 union；用独立的有序端点覆盖深度积分重算各阶段、各完整 postdraw 区间的区间并集，并重算所有 kind 的 calls/inclusive total/max，全部相等。

| 阶段 | 事件 | 墙钟区间 µs | 去重观测 µs |
| --- | ---: | ---: | ---: |
| autoload_start | 69 | 2528264 | 862753 |
| music_wait | 0 | 2606137 | 0 |
| fixture_setup | 75 | 4000357 | 108838 |
| warmup | 143 | 6589659 | 544322 |
| warmup_post_process | 3 | 68007 | 28162 |
| sample | 85 | 10007194 | 515108 |

六阶段事件总和 375，没有遗漏终止阶段事件（实际 `sample_end` 为 0）。375 是八个插桩入口含嵌套的事件数量，不是 375 次独立磁盘加载。实际每条事件 12 列、point 5 列，kind counts 与原计数一致；所有事件处于对应阶段边界内，父事件索引早于子事件且完整包含子时间，父子阶段相同；所有 3118 个 point 的时间戳单调。

sample 的 85 条组成：36 anim miss、25 directional loader、13 strip region、3 cold play、3 build、3 wav、2 atlas miss。其中 43 条是嵌套子事件，42 条是根事件。去重总额可以另由互不重叠的根事件核对：502750（36 anim miss）+ 9628（3 cold play）+ 2700（独立的 `song_jiang_idle_ne.tres` loader）+ 30（2 atlas miss）= 515108 µs。不能把所有 kind 的 inclusive totals 相加。

李逵原事件 311 是 `unit|li_kui|attack|se`，`[22726665,22974889]`，248224 µs；事件 312 是对应 PNG loader，`[22726836,22974881]`，248045 µs，parent=311。父区间完全包含子区间。其所在 postdraw gap 为 `[22630711,23009066]`，378355 µs，观测并集恰为 248224 µs；脚本没有把它变成 496269 µs，也没有将整个 378355 µs 归到加载。

## 同钟与阶段边界

实际镜像 `_first_use/ledger.gd:66/84/101/112` 的 point、open、close、stage 都用 `Time.get_ticks_usec()`。实际 `_first_use/driver.gd:49–50` 把原 M1 的 `started` 原值作为 sample 边界，64–65 使用原 elapsed 对应的时刻 freeze。分析脚本 59–70 直接用这组时戳求交集，没有用不同帧列表的索引猜对齐。global process/physics frame 只是区间右端附带标记，不能误当 fixture tick。

阶段名称描述钩子范围，不是独占 CPU profiler 分类。例如 `music_wait` 在 `_run` 开头标记，范围也包含配置和检查；0 个观测事件不代表整段没有工作。warmup 目标是至少 300 物理步，本次实际结束在 fixture tick 307；sample 560 步即 9.333333 秒模拟量，对应 10.007194 秒墙钟。不能把这次 warmup 写成恰好 300 步，也不能把墙钟和模拟量互换。

## 一处实质口径问题与最小修正

`analyze_first_use_entry.py:63–65` 要求左右 postdraw 戳均在 sample 边界内。这是合理的“完整区间”选择，然而第 75 行输出名 `sample_slow_over_100ms_count` 没有限定完整区间，易被直接转述成全部样本慢帧。

实际 sample start=20207406 µs，紧邻的前一个 postdraw=20207398 µs，早 8 µs；首个 sample postdraw=20392487 µs。因此首段 185081 µs 因左端点在外被排除，包含 207 µs 的观测事件。原 M1 首个 raw_frame_ms=185.087 ms，仍是其有效样本中的一帧。分析剩余 127 个完整区间合计 9822092 µs、41 个 >100 ms；原 M1 的 128 条测量记录有 42 个 >100 ms。末段 postdraw→capture_end 另有 21 µs。

区间事件核账正确：完整区间并集之和 514901 + 首段 207 + 末段 0 = 全 sample 515108 µs。完整区间总时长 9822092 + 首段 185081 + 末段 21 = 10007194 µs。

最小改法任选其一：

1. 将现字段重命名为 `complete_postdraw_intervals_slow_over_100ms_count`，同时记录 prefix/suffix 时长和观测并集；保留原 M1 的 raw slow count=42 作为另一个口径。
2. 现字段保留兼容时，增加明确 scope 字段并在文稿中写“127 个完整 postdraw 区间中 41 个 >100 ms”；另写整个 M1 样本 42/128，不合并二者。

这不阻断热点定位或正在进行的动画候选入口，但对外结论必须修正此范围。`top_events` 前两条也是同一父子事件，现有 label/parent 足以识别；展示时继续注明包含关系，不能称两次独立 248 ms 卡顿。

## 结论范围

分析现有 `acceptance_eligible=false` 与限制表述合适。去重观测 515108 µs 是已插桩路径的墙钟覆盖，不是纯磁盘 I/O、完整 CPU 忙时、GPU 总时间或必然可节省的时间。单个计时诊断不能证明普通版 FPS 提升；插桩、额外对象及计时本身会扰动时序/身份。无需为本次正确的并集和阶段汇总重跑 Godot。
