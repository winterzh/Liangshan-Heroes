# 高俅核心胜利工具首轮策略失败（2026-10-27 06:16:44 批次）

本包保留 `20261027_061644_5a762cc2` 的首阶段真实失败。实际 PID **57992**，退出 **1**，收据耗时 **243.095 秒**，`errors=[]`、`stopped_for=null`。原 report 有 **69 项检查：67 true、2 false**；日志计数相同。宿主 `complete=false`，但初始/最终完整身份、子进程终态、lane idle、锁所有权及释放均为 true。仅尝试 `save_after_wave1`。

两项原失败标签：

- `original wave 1 naturally dispatches living land and water forces at its normal timer`
- `first natural expedition clears before the second dispatch, without ending the chapter`

## 实际发生的时序

原始采样显示：开始约 0.4833 秒时三陆组存活 `[4,6,8]`；约 **30.5 秒**已为 `[0,6,8]`，60.5167 秒仍为 `[0,6,8]`，120.55 秒为 `[0,4,8]`，而第一波计划派发为 140 秒。首次派发观察在 **140.01666666667 秒 / tick 8420**：第一陆组存活 **0**，第一水组存活 **3**。

这是本轮普通策略与自然接战后未满足“水陆均活着被实际派发”的测试前提。原报告记录 1x/60Hz、233 条 QA 动作、真实支付建造/训练和普通命令；无需也不得把失败放宽为通过。此原件本身不证明生产代码缺陷。第二项失败也不能解释为已经运行到第二波或完成后续恢复。

**没有保存成功**：`save_exit_observed=false`，checkpoint 与 terminal_checkpoint 均为空。`resume_core_save`、`resume_finish`、`reject_terminal` 都未尝试。没有 controller 原件，不编造 controller。67 项局部通过不授首阶段、保存、恢复、核心胜利、收兵按钮、终局拒槽或整条链成功资格。

## 原字节与来源

- [raw/receipt.json](raw/receipt.json)、[raw/save_after_wave1/report.json](raw/save_after_wave1/report.json)、[raw/save_after_wave1/save_after_wave1.log](raw/save_after_wave1/save_after_wave1.log) 为实际原件。report SHA 为 `8faba4266074e439a25852df755accf64cf33433057c16b592aae5f784aab367`。
- `raw/tool_inputs/` 保留本批 runner_inputs 冻结的 **8 份工具**；`raw/workers/` 保留实际 5 GD 与 bindings，5 GD 与冻结工具逐字相等。工具还原映射见 [verification.json](verification.json)。未使用之后修订的当前源。
- `raw/source_metadata/` 仅包含本批冻结的 candidate manifest、expected identity、新源自身 import receipt。
- [summary.json](summary.json)、verification 与本 README 是派生说明；[manifest.json](manifest.json) 标明各原字节的真实 original_source_path、长度、SHA，清单不含自身。

源仍为 `source-v1:941c4786569d5886efbd3537238df853026cc50d0c98d0a1cdb1516c8a8f7964`，23 脚本与 1 native helper。完整来源引用 [full_freeze_20261027_050851](../full_freeze_20261027_050851/README.md)；本包核对其中 11 份有界文本与原 source 相同，不递归复制完整工程或多层历史导入日志。原 receipt 保留 436 pins；本次归档没有重新全扫该集合。

冻结 sources 的 `engine_started=false` 与冻结 README 的准备时描述按原字节保留；这不否定本批实际已运行，运行事实以原 receipt/report/log 为准。本包与前一 parse 失败包独立，不能混用 driver/policy/source SHA。

## 排除与资格

仅写此新归档目录。未复制 EXE/native 二进制、缓存、完整资源树或私有 profile 的 slot/LC/CFG/IPC 载荷。原 report 中动作、初始 typed 角色清单和采样属于本次获准保留的 QA 原报告，不另提取完整存档世界。路径/PID/nonce 是原运行绑定元数据。

归档没有启动/终止引擎或修改测试、生产源、原 run。公开 Continue、Steam SDK、奖励、导出包、人工体验、旧 19/61 阶段以及生产缺陷认定均未授予。
