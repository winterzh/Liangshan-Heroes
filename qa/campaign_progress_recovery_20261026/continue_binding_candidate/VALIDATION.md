# 继续入口修复：当前验证状态

2026-10-27。当前生产尚未采用，公开战役续玩仍关闭，原版键鼠验收按用户选择暂缓。README/source_manifest 及工具输入保留准备时原字节；当前资格以本页及独立原件为准。

## 已实现与已导入

三个脚本从 e97a 冻结派生：Flow 将公开 classic 范围交给 Session；Session 对完整已验证恢复候选先核范围、安装和 Steam 身份，再调用原 Store 的 fresh CAS 恢复；CampaignLifecycle 为 credited gen1 采用真实本地记录 SHA，并在 mount 重核。没有 packet 的 rev0 仅允许原始 owner-only 布局回收后返回 NO_SLOT。uncredited 战役 owner 仍由后续原生命周期检查，不声称所有错 owner 情况都在恢复前拒绝。

本次真实菜单继续另暴露连环马 runtime 遗漏。Session 现在对严格 LIAN_CONTEXT 使用固定 Level4Factory.prepare_runtime，按正常内容顺序应用本章招募参数；未改队列、人口、费用、存档或测试阈值。

独立冻结 20261027_013339_8495b720 仅有这三份 GD 与原 7,062 文件基线不同，没有新增或删除来源文件；preimport 与实际 generation 完全相等。实际身份 source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac，完整 manifest SHA 06f2aa5b50e30b4c711a0ea22e1d01253b3fed4d06db47b706abeb74bac771f0。导入进程 46284 正常退出 0、错误 0，共享锁释放。[来源与导入](evidence/full_freeze_20261027_013339/README.md)。

## 已完成的独立磁盘模型

- [旧源对照](evidence/disk_baseline_20261027_014124/README.md)：e97a，进程 36652，3 项夹具前置＋3 项旧 cold binding 缺陷复现，正常退出 0。原 gen1 字节不变，只证明 LOCAL_TOKEN_EXISTS 问题，不授修复资格。
- [新源回归](evidence/disk_fixed_20261027_014439/README.md)：d7f2258b，进程 68316，3 项夹具前置＋3 项旧 cold binding 对照＋30 项修复回归，正常退出 0。实际本地 gen1 只读采用、重复绑定、错误 token/account/context/content/engine、absence→present 变化、空目录以及 gen2/gen3 拒绝均符合预期；前后来源和锁终态核对通过。
- 这使用真实私有文件系统，但 credit、terminal 与 gen3 ACK 为明确的合成模型输入。gen2 由正常 LC API 写入，gen3 是直接 Store 写入的严格数据夹具；不是 Steam 结算、真实账号、自然胜败或公开玩家入口验收。

## 正在推进与未覆盖

[连环马前次真实入口失败](../evidence/lianhuanma_victory_failed_20261027_011539/README.md)保留原件：保存53项通过，恢复40项中2项失败；人口预留2→1为实际缺陷，LC标签失败为测试连带结果，原槽和LC SHA未变。旧训练135项直接提供专用Factory，不能替代真实Flow。

两个自然胜败宿主已通过新冻结的[只读绑定预检](evidence/lhm_binding_preflight_20261027_013339/receipt.json)，九份 GDScript 保持原字节。新源胜利四进程已开始完整重跑；没有完整终态前不授自然胜利资格，失败三进程随后独立执行。

公开 classic 死 writer 恢复、拒绝前字节保护和玩家失败/重试仍需实际验证。源码 QA 的私有入口与发行版 public gate 不等价；任何清 QA 标志后的单分支诊断必须另标范围，不能宣称公开入口或原版键鼠通过。原19类、61阶段、v2超时隔离、Steam SDK/云边界与全游戏验收继续保留。
