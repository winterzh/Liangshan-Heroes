# Battle Fog 实测证据复核

2026-09-07，复核 run `20260906T162217847550Z`。结论：本轮显式迷雾局部值 QA 的通过证据完整，无阻断。Godot 4.6.3 实际 PID 4652、exit 0、子进程退出已确认；complete/source_unchanged/lock_released 均为 true。report raw SHA `409b4bcf81c0676f466754a0e23eebacb84c32dd561d07842c138ccfdff0013d`。

报告的实际 user 路径位于本 run 的 private_profile，run_id、manifest raw SHA、PID、五源 before/after 与 configuration、process/主 receipt 一致。stdout 只有引擎头和一个 `[battle-fog-state QA]` JSON，该 JSON 与独立 report 逐值相等；严格 UTF-8、Unicode parsing error、Parse Error、Parser Error、SCRIPT ERROR、ERROR、WARNING、FAIL 检查均无命中。

182 条检查全部 passed=true，failures 为空，24 个强制标签均恰好出现一次。分组为 source 13、environment 3、behavior 30、rejection 51、json 31、fixture 54。runner 的 `10 source_hash_checks + 172 other_checks` 计数正确，但 172 内含来源集合、来源聚合、manifest 不变这 3 条 source 检查；排除整个 source 组后是 169 条。JSON/fixture 辅助断言与重复边界都在其中，不能写成 182 个独立案例。另 14 条合成报告拒绝是 controller 准备证据，未加入此计数。

重点复核：

- 第 167 条确实对应真实 `GameMap.new()` 赋给真实 Battle.map 后 free，再调用 adapter；结果为 MAP_INSTANCE，日志没有 typed freed-reference 诊断。这证明捕获前的失效检查，不证明过期引用已经恢复。
- 第 23–24 条先核实输入位值：负零 `00000080`、最小 float32 次正规 `01000000`、0.1 的 `cdcccc3d`、最大有限 `ffff7f7f`，以及 16777217 在 PackedFloat32 输入中已舍入成 16777216；第 22 条随后核对完整 reveal 数组经真实 JSON 后位值相同。没有把输入前丢失的数据误当 codec 成功保存。
- 第 25–26 条保留 `_fog_t` 原生 float64 位值和完整七字段重新编码；0、负零、0.18 的边界另有实测。没有重置/重算相位。
- 第 169/171 条为实际 64×64、4096 格 capture 及真实 JSON validate 成功；原 preparation 中 12,303 节点/820,910 字节仍是静态收费计算，并非本报告新增的实测计数器。
- 标准 60×60 与非方形 7×3 均通过，等格数但转置的期望尺寸被拒。两份 PackedByteArray、独立 PackedFloat32Array、不消耗额外 RNG、解码不别名源缓冲、无 ready/deploy/fog pass/bake 副作用均有明确断言。

本次重新核对 controller 冻结的 13 项输入 raw/bytes，以及五 runtime 源的 LF 摘要；原 GD、README、pins 和合同未变。保存的 2713 文件 sources.json 目录/存在性/摘要重算得 `f12de07498b7074dd1c8fb0edf0bde9bdc5f0dfad5b95d850624b32e2a65fa20`，与 run 收据相符。本复核没有再次全量哈希 2713 份生产源，完整实时前后相同和真实玩家配置摘要相同的证据来自原 controller 收据。

范围仍是五个 Battle 迷雾值和两项实际地图维度；对象始终在模拟树外。没有赋值恢复、Unit 可见性/引用图一致性、地图导航/高亮、纹理资源重建、完整 physics/process 屏障、玩法 RNG 恢复、磁盘接入或跨进程战斗继续；无性能验收结论。queued-deletion 拒绝分支未新增实测，不能因真正 freed Map 通过就宣称它也已测。

已封存原 runner `42e4cd96…`、contract `523349d5…`、common `1e11fe77…`、lifecycle `ad12b2b4…` 和两份公共 helper 的原字节，另保留原 controller 合成预检报告。所有冻结副本在 archive_prep/frozen_runtime；没有修改共享原文件。归档仅限精确白名单，包括 run 根目录的指定 report.json，不复制 private_profile、玩家文件、工程、fixture、缓存或引擎。原准备文档继续保留当时“未运行”的历史文字，真实结果由本文件与 current_qa_summary.json 追加说明。
