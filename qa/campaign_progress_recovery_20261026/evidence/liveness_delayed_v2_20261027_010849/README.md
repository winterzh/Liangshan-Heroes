# 延迟 acquire 的两种原生时序

来源：.godot/campaign_liveness_io_v2_20261027/20261027_010849_dd205bef。complete/final_identity_passed/lock_released 均为 true。

四个独立 Godot PID 67388、68900、49560、22800 均退出 0。first_after_clear 为 A36+B25=61 条；retry_under_barrier 为 A43+B25=68 条，共 129 条检查通过。两份 case_receipt 与顶层全文一致，四份 report/log 与收据 SHA 一致。

A 在真实 acquire 取 writing 前暂停，B 以真实 Store+Receipt 提交新记录并在 release_marker_published 暂停。A 保留旧 CAS/proposal，遇屏障返回 WRITER_BUSY。第一案在 B 清屏障后直接首次 retry；第二案先在屏障仍存在时 retry，仍 WRITER_BUSY，原 owner/目录/proposal/CAS 不变，再待屏障清除重试。四处断点均核实际源码 SHA、语句、函数、PID 与完整栈。

两案最终 A 均返回 OWNED_HEAD_CHANGED、own_stale_lock_released=true：只释放自身过期锁，保留 pending 原提案并要求重启，不重新计算或偷写。新 Ledger 能打开，B 已提交 envelope 原字节不变；A 原 run 保持 active，累计 5 kills/0 wins，旧 handoff 未应用。结果不是 A 结算成功，也未证明重放 handoff 的 once-only 成功路径。

每案 B 前后各通过真实 Manager/Win32 helper 获得 WRITER_ALIVE，两次 FILETIME 相同。4 份原 result.json 按 receipt pin 原字节保存，严格 11 字段仅含 PID/创建时间/nonce/wait/error/state，无凭据或玩家数据，未使用不可靠的 Godot 外部 PID 布尔。

终态 191 pins 原链已核；归档时当前路径有 190 项一致，唯一 io_v2/README.md 由 root 在终态后追加本轮结果，其旧运行副本仍精确匹配原 pin，已按 runner_inputs 原字节归档。summary 明列旧/新 SHA 和原因，不把后改文档说成运行时来源。

保存冻结 runner_inputs/workers、控制器/请求确认/报告/日志和 provider 原件；不复制 profile、存档、二进制、缓存。重复累计 checkpoint 由终态 receipt 取代。manifest 记录原路径、大小、SHA 并逐份读回；账号与 token 均为明确的合成夹具。

B 不是第二个 Ledger。仅授两个旧 CAS 安全中止及活写者时序，不授双 Ledger 并发、原 19 类/61 阶段、玩家 UI 重试、完整战役续玩、真实 Steam SDK、原版 EXE、人工体验、性能或发布资格。
