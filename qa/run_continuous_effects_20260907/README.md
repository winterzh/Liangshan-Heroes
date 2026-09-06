# 三数组持续效果恢复（2026-09-07）

本归档仅保留真实 Battle 的 _ground_dots、_hua_snipe_dots、_lin_duels 三数组恢复。正式模块 [run_continuous_effect_state.gd](../../scripts/run_continuous_effect_state.gd) 与原型逐字节相同，SHA256 为 4b1d6214cd760039110b7154555c06a86ffd8ea9dbeb6ca6da8102e24bb2726d，见 [promotion.json](promotion.json)。

| 路径 | Run（UTC） | PID / exit | 结果 |
| --- | --- | --- | --- |
| 原型 | [20260906T191947368450Z](runs/20260906T191947368450Z/report.json) | 40452 / 0 | 52：16 来源前后 + 36 其余，入口完整覆盖 |
| 首轮正式 | [20260906T192154836197Z](runs/20260906T192154836197Z/report.json) | 17704 / 0 | 52 项通过，但存在 manifest coverage gap |
| 修正后正式 | [20260906T192639802801Z](runs/20260906T192639802801Z/report.json) | 40280 / 0 | 同组 52 项，实际入口与 manifest 完全一致 |

原对象先消耗一次地火与一次流血周期，再经真实 JSON 恢复完整剩余字段、时钟、数组顺序和 none/已释放/活对象引用。缺失 tombstone 在任何数组赋值前被拒绝，已有目标数组不得覆盖；恢复本身不造成伤害、治疗或冷却奖励。

实际原生 pass 继续结算剩余三次地火、四次按当前最大生命计算的百分比流血；过期 follow 保持原中心及减速/致盲值。队友真实击杀后直接调用原 _resolve_lin_duel_death 消费者，决斗只回血一次并复位 Q/W 一次，产生一个奖励效果；重复回调、奖励后再保存恢复均不会重新领奖。

## 中间轮的清单覆盖缺口

首轮正式实际执行 res://scratchpad/run_effects_production_qa/effects_restore_smoke.gd，但 runtime manifest 校验的仍是 scratchpad/run_effects_resume/effects_restore_smoke.gd。引擎 exit 0、52 项及原 complete 收据原文保留；分类为 manifest coverage gap，不改为引擎失败，也不能用来证明正式 driver 的精确历史字节。

[旧 runner](runs/20260906T192154836197Z/run_smoke_manifest_gap.py.txt) 与 [修正记录](runs/20260906T192154836197Z/manifest_gap_correction.json) 单列。只修正 runner 的清单目录，正式模块与 driver 不变，再运行最终正式 run。最终 report_process.command 的入口去掉 res:// 后与 manifest 键完全一致，driver 原字节 SHA 也匹配；其版本结论由新 run 提供，不回填中间轮。

三轮报告与唯一 stdout JSON、PID、manifest、私有 user:// 和报告 SHA 均一致，exit 0且严格日志通过，各自源文件和真实玩家前后摘要一致，子进程退出确认且共同锁释放。完整版本证明使用原型与修正后正式两轮，同组 52 项复验不累加成独立场景数。

## 字节、依赖与复现

[source_index.json](source_index.json) 映射三轮 manifest 的全部源码、版本化 runner/driver、正式模块及固定 SHA helpers；相同已提交组件 QA 字节明确复用，不重复大 Battle。每条 repository_path 是正确恢复位置；最终 runner 位于 sources/corrected，原路径副本仍保留旧 runner，不能混用。收尾交接时上一批飞斧已同步至 37066b6a40ca0146b1d3023e8e36e5040a9773e7，不据此回写各 run 的 Git 归属。

[archive_manifest.json](archive_manifest.json) 保存复制来源、大小和 SHA；[archive_verification.json](archive_verification.json) 核对复制与引用原文。GDScript以末尾 .txt 保存，根目录 .gdignore 隔离；没有复制私有 profile、玩家存档、缓存、引擎、vendor DLL 或资源二进制。

复现需独立完整相容 checkout，按最终 run 的 source index 恢复缺失的忽略目录；GDScript去掉最后 .txt，Python保留原名，已有文件只核对、不覆盖。最终入口为 python scratchpad/run_effects_production_qa/run_smoke.py --godot "<实际 Godot 路径>" --suite effects；不带 --run 仅预检，实际执行追加 --run，保持引擎独占、新私有用户目录和新 run。固定引擎/helpers 边界沿用 [组件 QA](../run_resume_components_20260907/README.md)。

## 验证范围

仅覆盖 ground/hua/lin 三数组及直接调用的原决斗死亡消费者，不覆盖其他 14 类效果、完整 _on_unit_died 清理、玩法 RNG 或整个 Battle 恢复。RunSession、顺序/UID/tick、其余效果和事件、快照屏障、失败原子性、关闭程序后的持续战斗、菜单与 PCK 续玩仍待验证。没有进行视觉截图验收。
