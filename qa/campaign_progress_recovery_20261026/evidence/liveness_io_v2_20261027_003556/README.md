# 三态进程查询接入后的 23 进程存储 I/O 证据

来源：`.godot/campaign_liveness_io_v2_20261027/20261027_003556_2423499b`。终态 receipt 的 complete/io_passed/final_identity_passed/lock_released 均为 true。

独立回读 23 个不同 Godot PID、23 份 controller、14 份 worker report，共 370 条检查通过。14 个进程正常退出 0；9 个在匹配 PID、源码 SHA、语句、函数及调用栈后由宿主按计划终止，退出 1，不能写成自然退出成功。5 类真实 Windows 共享句柄拒绝后原对象重试通过。共 15 次调试停止、14 次实际故障点；多出的 1 次为 write_retry 先在 acquire 写 owner 时停下，实际拒绝在 commit_locked 调用 _write_new:172，二者未混淆。

覆盖正常 handoff、v2 升级、写打开/写锁 rename/owner rename/cleanup 删除/marker 删除故障重试；完整 pending 和 record-renamed 的独立进程恢复；唯一 cleanup/marker 发布及删除窗口，并包含两条恢复者 claim 后再次终止、第三进程续办路线。half 重启后 plan/open 均 ENVELOPE_JSON 且目录与文件 SHA 不变，是安全拒绝通过。marker_removed 后目录已正常清理，plan=UNKNOWN_OR_MISSING_LOCK 而 Ledger 正常 OPENED，不是恢复坏锁。其余恢复分别 forward_pending、release_committed_lock、finish_unique_release。旧无 owner/裸 recovering 遗留、完整异物及变异矩阵仍未覆盖。

235 个终态 pinned_files 重新读取 SHA 一致；controller 与 receipt 对应 stage 全文相等，原日志/报告 SHA 匹配。18 份实际 provider result.json 与观察结果及 receipt SHA 一一对应，均为 PID_ABSENT_87 死进程查询。严格 11 字段仅含 nonce、进程号、FILETIME、wait/error/state，不含账号凭据或玩家存档，因此保留原字节；不重新推断已复用 PID 的当前状态。

`manifest.json` 逐文件记录原路径、大小、SHA 和复制验证；`summary.json` 列出每进程分类、检查数、provider 原路径和资格。保存冻结 workers/runner_inputs、stage 报告/控制/日志/请求确认；不复制 terminated_account_copy、私有 profile、存档、exe、缓存。累计 checkpoint 由完整终态 receipt 取代，避免重复载荷。报告中的账户、token、handoff 是明确标注的合成夹具。

仅授上述原生存储切片，不授 delayed 两案、双 Ledger 并发、原 19 类/61 阶段、玩家失败界面与重试、完整战役续玩、真实 Steam SDK、原版 EXE、人工体验、性能、断电或发布资格。安全拒绝半写和归属丢失符合旧合同，不表示自动恢复已全部闭合。
