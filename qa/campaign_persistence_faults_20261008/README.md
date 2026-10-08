# 真实 Campaign 写盘故障的调试器准备

当前只准备真实 Godot 调试协议；原 19 案矩阵尚未运行。正式 Campaign/Battle 未修改，v27b 两文件仍是 QA 提案。

`failed_debug_probe_v1/` 是实际失败：官方引擎 PID16364 正常退出0，ConfigFile 真正保存/加载，但 CLI 双冒号断点未命中，没有发生控制器文件修改。原日志、收据、报告和执行 GD 均保持原字节；私有工程/profile 留在工程外。不得把退出0计为调试协议资格。

官方 `4.6.3-stable` 标签源码表明 `EngineDebugger::initialize` 按最后一个冒号拆分 `file:line`；CLI 帮助文字写 `source::line`，两者不一致。控制器已改为单冒号，等待完整续玩批次终态后再用新 UUID 独立验证，避免本线程两个原生批次互相竞争。标签源码只作为协议依据，未证明与安装引擎精确源码提交一致；首次精确提交 URI 返回404的原清单也保留。

工具：`tools/godot_debug_wire.py` 是有界、拒绝 Object 的 Variant TCP 编解码；`tools/run_campaign_debug_fault_probe.py` 只控制自己的回环调试连接和私有 cfg，须核验真正的 breakpoint、stack source/function/line、实际 PID/nonce，再改真实文件并继续实际 ConfigFile.load。未修改原生错误码或生产脚本。

离线固定包、拒绝异常包及 TCP 分段超时缓冲验证通过；这不代表原生协议或19案通过。之后必须完成实际断点和真实读盘证明，再建立真实 Campaign 的19案 harness。终局→cfg→ack、玩家失败UI/pending锁/安全重试、跨进程恢复与奖励一次性仍需另测。
