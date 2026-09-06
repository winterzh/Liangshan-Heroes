# 持续打磨 M1 验证证据

实现与复跑入口见 [POLISH_BASELINE_20260906](../../docs/POLISH_BASELINE_20260906.md)，持续目标见[完整路线](../../docs/POLISH_ROADMAP_20260906.md)。本目录只归档工具验证和性能测量，没有真人测试结果或新发布产物。

| 路径 | 证据与边界 |
| --- | --- |
| `soak_preflight/` | 123.91秒、14次切换、88项通过；`acceptance_eligible=false`，不能计作正式30分钟验收 |
| `runtime_modes/` | 当前模式返回、移动、释放及存档不变的25项检查通过 |
| `runtime_performance_final/` | 当前祝家庄/高俅有效10秒实战窗口，12/18项通过；两项P95和四项缺失基线仍失败 |
| `superseded_runtime_attempts/` | 较早接战夹具、宋江阵亡导致提前结束，以及误用ST_ATTACK后的无效输出；不得替代最终结果 |
| `harness_preflights/` | 新长窗口工具的短预检，包含初次类型推断错误；所有短预检均不可组成基线 |
| `integration/` | 接入另一任务公告提交时，自有WIP前后原字节保持收据 |
| `archive_manifest.json` | 原始来源路径、归档路径、大小与逐文件SHA256；保留原字节，不混入Godot缓存或玩家数据 |

`baseline_fixed/` 与 `baseline_auto/` 共15个至少60秒窗口、126项完整性检查通过；每组三次初始部署和输入指纹一致。每个样本保留JSON原始帧数据、PNG和控制台；完整配置/来源/重复组判断另存。`baseline_eligible` 表示符合采样要求，不表示通过性能目标。

本目录 `.gdignore` 排除Godot扫描，`.gitattributes` 保留证据原字节。历史失败报告中出现 `passed=true` 不能覆盖日志中的SCRIPT ERROR；只有最终工具的完整样本检查、日志和来源复核共同通过才是有效样本。
