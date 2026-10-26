# 高俅核心胜利工具首轮解析失败（2026-10-27 06:04:24 批次）

本归档保留 `20261027_060424_187a2a35` 的失败原件。首阶段 `save_after_wave1` 实际启动 PID **68624**，退出 **1**，收据耗时 **30.2 秒**；Godot 在实际 `workers/driver.gd:164` 报 `Expected closing ")" after call arguments.`，随后报告脚本加载失败及 `GAO_TERMINAL_WORKER_SCRIPT_INVALID`。实际日志位于 [raw/save_after_wave1/save_after_wave1.log](raw/save_after_wave1/save_after_wave1.log)。

**complete=false；0 份玩法 report，0 项玩法断言。** 没有 controller 原件，因此没有构造 controller。其余三个阶段没有尝试。原收据的 initial/final identity、child terminal、lane idle、lock ownership/released 均为 true；这些只证明来源与宿主收尾，不授予玩法成功资格。

## 原件与还原

- [raw/receipt.json](raw/receipt.json)：原运行收据，完整保留 435 条运行 pin 元数据；本归档没有重扫全部 pin 或资源树。
- `raw/tool_inputs/`：本次 `runner_inputs` 中的 **8 份冻结工具**，包含 host、5 份 GD、README、sources。还原到原 QA 工具路径的对应关系见 [verification.json](verification.json) 的 `tool_reconstruction_map`。不采用修复后的当前工具。
- `raw/workers/`：实际运行使用的 5 份 GD 与 `bindings.json`，5 份 GD 与冻结工具逐字相等。
- `raw/source_metadata/`：本次冻结输入中的 candidate manifest、expected identity 和新源自身 import receipt。
- [summary.json](summary.json)、[verification.json](verification.json) 是派生说明；[manifest.json](manifest.json) 逐项标明原字节来源、大小和 SHA。清单不包含自身，避免自引用。

冻结 `sources.json` 中的 `engine_started=false` 和工具 README 的准备时描述是**运行前原文**，不改写。实际本批已经启动引擎并在解析时失败，以原 receipt/log 为准。失败行所在 `finish_restored_core` 原本用于后续阶段，但整个 driver 加载即失败；不能把错误位置误记为已经到达第三进程。

## 完整来源引用

本批 source 为 `source-v1:941c4786569d5886efbd3537238df853026cc50d0c98d0a1cdb1516c8a8f7964`，23 个脚本 overlay 与 1 个 native helper 的候选 manifest 为 `c5c1052c4797d760a52d15176c0d79bbc7ea7aaa23003ba429108be507ca753b`。

完整冻结与来源链引用已归档的 [full_freeze_20261027_050851](../full_freeze_20261027_050851/README.md)。本次核对其 manifest 及 11 份有界文本原件（generation、preimport、preparation、候选身份、新源 import receipt/log、4 份 integration 准备器输入）与原 source 字节一致，摘要与路径保留在 verification。没有重复复制大资源树或多层历史 import 日志。

## 资格与排除

本批只证明真实引擎发现该外部 QA 工具的解析错误，以及失败后原宿主完成进程终态和锁释放。**零玩法资格**：未证明首波、保存、恢复、核心胜利、实际收兵按钮、终局拒槽、奖励、Steam SDK、公开 Continue、导出包或人工体验；不得继承训练/失败批或旧 19/61 阶段资格。

仅写此新归档目录。未复制 cache、EXE/DLL、资源树、私有 profile、slot/LC/CFG/IPC 业务载荷；没有启动引擎、修复工具或修改原 run。原件中的私有 profile 路径、PID、nonce、源身份只是运行绑定元数据。
