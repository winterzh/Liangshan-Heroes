# 2026-09-07 独立玩法随机流跨进程验证

私有R1草稿完成真实写入、读取两个Godot进程的随机流续接：writer为137项，reader为47项，合计184项检查；其中包含环境、来源、夹具及拒绝路径，不能当作184个独立功能。7个种子各保存中途状态，由新进程继续64次混合调用，共448个后续随机结果逐项一致。实际PID为652和31604，均退出0；原始日志严格复核没有错误或警告。完整事实见[成功收据](../qa/run_gameplay_rng_20260907/runs/r1/receipt.json)。

模块持有独立的原生RandomNumberGenerator，支持randi、randf及两类range调用；保存signed int64的seed/state和调用计数，并核对引擎二进制、版本、平台、浮点精度及模块/codec来源。没有调用生产Battle，也没有迁移现有全局随机调用。

## 原失败与修正

首轮writer PID20576退出1：`Codec.resource_path`将preload常量当作脚本实例读取，导致解析失败及后续new调用失败。该轮只有12项环境/来源检查，未完成随机续接行为，不能记作测试通过。R1改为通过现有codec实例的get_script读取资源路径，保留原7种子合同后重跑成功。原模块、driver、runner、pins和[失败日志](../qa/run_gameplay_rng_20260907/runs/original_failed/writer_report.log)均按原字节保留。

## 范围与后续

本次仅为source-mode私有模块验证；不是生产存档、完整Battle恢复、继续按钮或旧全局随机序列等价性验收。模块依赖源码字节身份，导出PCK中的脚本转换/重映射来源策略仍待解决，当前Steam包不包含此草稿。两进程期间2,713份生产来源及真实玩家目录摘要前后保持一致，独立私有源码与交接输入未变，共享引擎锁已释放。

精确原文、两轮收据和必要helpers在[QA归档](../qa/run_gameplay_rng_20260907/README.md)。冻结pins中的“准备完成、尚未运行”字段保留原历史语义，实际运行状态以本轮成功收据为准。
