# 李逵飞斧待结算效果恢复（2026-09-07）

本归档保留实际 Battle.LiBrawnAxesFx 的原型与正式路径两轮恢复检查。正式模块 [run_li_brawn_axes_state.gd](../../scripts/run_li_brawn_axes_state.gd) 与原型逐字节相同，SHA256 为 cd8662a38012cc4739e403a4b9eb12023c55eb5bf0d750cbf6640b063f591fde，见 [promotion.json](promotion.json)。

| 路径 | Run（UTC） | PID / exit | 检查数 |
| --- | --- | --- | --- |
| 原型 | [20260906T190607921584Z](runs/20260906T190607921584Z/report.json) | 5796 / 0 | 46：16 来源前后 + 30 其余 |
| 正式 | [20260906T191522544612Z](runs/20260906T191522544612Z/report.json) | 30268 / 0 | 同一组 46 项 |

两轮均完成真实 pending 状态经 JSON 重建，保留时钟、Node 状态、caster 与有序 hits/原伤害；纹理仅接受固定可信引用或原始程序绘图标记，不从存档加载路径。恢复对象先禁用、绑定新 Battle/Unit 图后才统一激活。真实原生过程验证首个已释放目标被跳过，后续活目标受一次伤害，新 Battle 只收到一次 impact，重复调用不再次结算，效果实际 queue-free 并退出。

报告与唯一 stdout JSON、PID、manifest、私有 user:// 和报告 SHA 一致；两轮 exit 0，严格日志通过，各自源文件和真实玩家前后摘要一致，子进程退出确认且共同锁释放。相同组件在正式路径复验，不将两次 46 项相加成独立场景数。

## 字节与依赖

[source_index.json](source_index.json) 映射两轮全部 manifest 源码、各自 runner/driver、正式 factory 及固定 SHA helpers。相同既有依赖明确复用已提交的组件 QA 原字节，尤其不重复复制大 Battle 文件；每条 repository_path 是复现时的正确路径。归档/晋级时既有已同步基线为 9bcda9ef510cab041081d0e2bf23addfe0593d02；不据此回写较早原型 run 的 Git 归属，受测版本始终以各 run manifest 为准。

[archive_manifest.json](archive_manifest.json) 保留复制来源、大小与 SHA；[archive_verification.json](archive_verification.json) 记录复制及引用映射复核。GDScript 以末尾 .txt 保存，根目录有 .gdignore。没有复制玩家存档、私有 profile、缓存、引擎、vendor DLL 或资源二进制，也没有为获取 UID 额外启动编辑器。

## 复现与范围

在独立、完整且版本相容的 checkout，按 source index 恢复缺失的忽略目录：GDScript 仅去掉最后 .txt，Python 保持原名。已有源码只核对 SHA、不覆盖；正式 factory 恢复到 scripts/run_li_brawn_axes_state.gd，原型入口则使用其独立 repository_path。引擎身份和固定 helpers 沿用 [组件 QA](../run_resume_components_20260907/README.md)。

正式入口为 python scratchpad/run_axes_production_qa/run_smoke.py --godot "<实际 Godot 路径>" --suite axes；不带 --run 仅预检，实际执行追加 --run，须独占引擎、使用新私有用户目录并产生新的 run。不可直接运行归档 .gd.txt 或回写旧收据。

本组件尚未接入完整 RunSession。M3 的整局顺序、UID/tick、其他持续效果与事件、快照屏障、失败原子性、关闭程序后继续行动，以及菜单与 PCK 续玩仍待验证。该检查不证明整局恢复或视觉截图验收。
