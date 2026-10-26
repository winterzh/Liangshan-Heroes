# Readset 新来源：真实 classic 保存恢复分支

批次 `.godot/classic_readset_branch_20261027/20261027_035441_ec3aea99` 已 complete=true。来源 `source-v1:768b6e5937321126b4c927fce6b5565459610aa13ccb556f695837a814eb74c2`，Store SHA `f222e8b3798355164ab29da4d0dc534362e2bea680ec7f7dbe7462b86df8959f`。四个真实进程均终态：pending writer 14040、reader 19676；record writer 61920、reader 70208。两 writer 在原生产保存栈断点由宿主计划终止并退出1，两 reader 正常退出0。准备/恢复检查分别23+21+23+21，共88项全部通过；宿主断言不另加计数。

两个 reader 均为 `fixed_branch_restored`，恢复暂停的 classic30 世界。同一初始费用、单位/训练队列/资源、时钟和关卡观察保持；原执行断言对 HELD 的完整 typed 快照进行精确比较。归档另从原槽字节独立核对费用后金94/木58、28个单位的关键值和训练队列、关卡状态与时钟；退出后的 reader 世界没有另导出完整快照，完整运行时等式以已固定原 worker 的实际通过断言为据。

pending 原字节 SHA `cebcd8932b381acb33c0e992208c056cb206f2b883c130e19ed5a5bf0abb72c5` 转为 record；record 原 SHA `b63a33a6eb3af76087ef7b4c38b468878afc3a2954c8720a9c927f9f9c6b7372` 保持。两例 writing 均已释放，同 token active LC 原字节保持。原终止前后库存、终止证据副本、当前业务树及预期提交/释放后的完整库存逐项相符，见 inventory_audit；没有把业务载荷或 profile 复制进归档。

357个运行 pins 按原 run 冻结副本优先逐项回读。保留原宿主、全部 workers、运行相关来源、完整准备/导入记录、日志/报告/收据及先前完整冻结归档的元数据。沿原 host 的 final_identity_passed 与已独立核验的 full-freeze 证据绑定完整来源，本次没有重复散列整个工程。所有归档原件写后 SHA 一致，来源映射见 source_map，逐文件清单见 manifest。

两个 profile 各3份真实 helper result（共6）原字节保留，均为 `windows_process_liveness_v1 / dead / PID_ABSENT_87`，target 分别为14040、61920，nonce 与原目录一致。仅复制这些无业务载荷的 IPC 元数据；无独立 request 文件，不伪造请求或 helper 终态收据。其实际消费和恢复成功另由原实现与两 reader 的原生终态支撑。

入口仍是可见按钮的私有 QA gate，原 Continue 请求被接受后同栈清 gate，再进入原 deferred 恢复分支。报告明确 initial_private_gate_used=true、source_restore_branch_only=true；公开入口、原版发行 EXE、真实 SDK、OS 键鼠、人工体验、发布资格均为false。这两例成功不授完整拒绝/ABA矩阵、普遍性能、61阶段或生产采用资格。
