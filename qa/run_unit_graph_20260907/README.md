# Unit 顺序图恢复（2026-09-07）

本归档保留完整 Unit 子节点顺序与独立活动顺序的原型、正式路径两轮检查。正式模块 [run_unit_graph.gd](../../scripts/run_unit_graph.gd) 与原型同字节，SHA256 为 633b631234664fb1abf17d738a6be8599d0c1c9eb55620d495cab51da06f6319，见 [promotion.json](promotion.json)。

| 路径 | Run（UTC） | PID / exit | 检查数 |
| --- | --- | --- | --- |
| 原型 | [20260906T192949868331Z](runs/20260906T192949868331Z/report.json) | 41376 / 0 | 73：20 来源前后 + 53 其余 |
| 正式 | [20260906T193154174815Z](runs/20260906T193154174815Z/report.json) | 33580 / 0 | 同组 73 项 |

夹具是真实树外 Battle/Map 下的五个 Unit，四个活动单位加一个仍播放死亡状态、已经离开活动列表的节点。经真实 JSON 保存完整 sibling/root_order 和独立 active_order；持久 ID 顺序不取自字典插入顺序。核对矿工/等待列表、驻军双向关系及重复项、dying 活引用、已释放目标、原生整数身份池、命令顺序和物品 UID/相位。遗漏死亡节点、重复 ID、错误活动 ID或版本、末条坏记录会被拒绝；完整验证在分配新 Unit 前完成，原对象图和值保持不变。

## prepare 的事务交接

prepare 返回全部树外禁用、信号阻断的新 Unit、两份有序列表、激活计划，以及同一份仍开放的 identity 和仍存活的 typed tombstones（用于恢复已释放引用的临时对象）。tombstones_released 明确为 false。它不赋值 Battle 数组、不挂接、不连接系统信号，也不激活模拟。

外层必须将返回的同一 identity 交给后续所有 Battle、FX 和整数引用图，全部绑定完毕后，才统一调用 identity.release_tombstones()，安装图与保存顺序、连接必要监听并激活。禁止仅 Unit 图成功就提前释放临时对象或激活。本次真实检查证明同一 identity 可以继续绑定此前未见的退休目标/来源，显式外层 finish 后引用才成为真正已释放对象；暂停挂接和激活不触发施法、死亡时间步或出现/死亡回调。

后续保存继续传入保留的 identity；它不是整局实体/物品 UID 或 tick 分配器。完整暂停边界、经济/效果/磁盘恢复、信号重连和整局失败原子性仍由尚待接通的外层事务负责。

## 原文与复现

两轮报告、唯一 stdout JSON、PID、manifest、私有 user:// 和报告 SHA 一致，严格日志无错误或警告，exit 0、各自源码/玩家前后摘要一致、进程退出确认且共同锁释放。两份 runner 在启动前要求实际执行入口必须被 manifest 钉住；归档也逐项核对 report_process.command 末尾去掉 res:// 后与 manifest 键及 driver SHA 完全一致。正式路径重复同组检查，不累加为独立场景。

[source_index.json](source_index.json) 映射两轮全部源码、runner/driver、正式模块和精确 helpers。相同已提交组件 QA 的原字节明确复用，不重复大 Battle；原始 [准备 README](sources/scratchpad/run_unit_graph/README.md) 与 [pins](sources/scratchpad/run_unit_graph/pins.json) 的“尚未运行”状态保持原文，实际通过结果只由本层原始 run 证明。交接时上一批持续效果已同步至 4c4b60d5d734286d75e609f85c743eb4702db9ee，不据此回写各 run 的 Git 归属。

在独立完整相容 checkout，按 source index 恢复缺失的忽略目录；GDScript只去掉最后 .txt，Python保持原名，已有文件只核对、不覆盖。入口为 python scratchpad/run_unit_graph_production_qa/run_smoke.py --godot "<实际 Godot 路径>" --suite unit-graph；不带 --run 仅预检，实际执行追加 --run，保持独占引擎、新私有用户目录和新 run。固定引擎/helpers 沿用 [组件 QA](../run_resume_components_20260907/README.md)。不要直接从归档运行 .gd.txt。

[archive_manifest.json](archive_manifest.json) 保存复制原字节，验证见 [archive_verification.json](archive_verification.json)。没有复制私有 profile、玩家存档、缓存、引擎、vendor DLL 或资源二进制。本增量不运行 Battle._ready 或新局部署，不证明整局经济/效果恢复、全局 UID/tick、跨进程持续战斗、菜单 UI 或 PCK 续玩；M3整局保持未完成。
