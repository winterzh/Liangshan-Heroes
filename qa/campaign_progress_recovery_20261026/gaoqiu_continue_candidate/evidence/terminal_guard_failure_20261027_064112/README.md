# 高俅纯 H 策略失败原件归档 — 2026-10-27 06:41:12

原批次：`D:\AI项目\水浒\开发工程\.godot\gaoqiu_terminal_20261027\20261027_064112_9bcaca9b`。本包只归档这次已结束的真实执行，不启动引擎，不修改候选或旧记录。

PID 23040 报告测试失败并退出 1，宿主耗时 424.039 秒，engine errors 为 0。正式报告 90 项检查中 89 项通过、1 项失败：`first natural expedition clears before the second dispatch, without ending the chapter`。这是外部自然玩法策略未达到清场门槛；证据不将其定性为生产缺陷。

首波在 level.elapsed=140.01666666667 时观察到正常派发，陆军 4、水军 3 均存活，此项已通过。最后三次约 240/270/300 秒样本仍有首波陆军 2、水军 0；第二、三波仍分别陆军 6/8、水军 5/6，尚未派发。11 次样本大厅均为 1500 HP，原宋江/大厅存活检查通过。原时钟 1x/60Hz，未注入玩法状态。完整 11 次样本保存在 summary.json；不把最后样本时间当作精确退出模拟时间。

本轮只启动 `save_after_wave1` 一进程。`save_exit_observed=false`，保存及终局 checkpoint 均为空；未保存、未执行后续三进程，不授予恢复、胜利、终局拒槽或完整四进程资格。public/SDK/release/human/credited/defeat 资格均为 false。

初/后完整身份、子进程终态、锁所有权、引擎通道空闲和锁释放均为 true。原 receipt 保留 436 pins；归档只复核选定原件和有界来源，不重新遍历全部资源或声称再次验证全部 436 项。

`raw/` 保留 20 份原字节（827,022 B）：receipt、首阶段 report/log、8 个本轮冻结工具文件、5 个实际 worker 与 bindings、3 个小身份/import 元数据。实际首阶段没有 controller，未构造替代件。8 个工具足以还原本轮策略版本；使用 run/runner_inputs，不取后来变更的工作源码。

verification.json 列出 12 个未变依赖的旧归档精确 SHA 引用，并逐一与本轮冻结输入比对；另核对已归档 full_freeze 的 11 份有界来源及 manifest SHA。完整来源参考 `../full_freeze_20261027_050851/`，不重复复制历史多层 import 日志。旧工具 README/sources 中未执行状态保留原文；它们是准备时元数据，本次实际结果以 receipt/report 为准。

未复制 EXE/DLL、缓存、完整资源树、私有 profile 的 slot/LC/CFG/IPC 载荷。原 report 自带必要 QA 开局状态/typed opening、指令和有限战斗观察，原样保留；它不包含已成功保存的世界档。本包含绝对本机路径及 PID/nonce，用于来源追溯。

manifest.json 覆盖除自身外的全部 23 文件；每份 raw 均逐字核对原 source 和 SHA，所有生成文件另标为 derived_archive_record。README、summary、verification 是派生说明，不冒充原运行输出。
