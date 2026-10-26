# 经典续玩修复候选部分结果（2026-10-27 02:37:31 批次）

原批次：.godot/classic_recovery_branch_20261027/20261027_023731_c180a912。
来源 source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac；expected=fixed。宿主最终 exit 1、complete=false，实际成功 cases 只有 pending。最终来源检查、自有锁确认与释放通过，4 个原进程均终态。

两案分别保留：

- pending：writer 54152 在真实 pending_verified 保存栈断点计划退出 1；独立 reader 21868 正常退出 0，21 项 reader 断言通过。实际恢复暂停的 classic30 世界，类型、资源、队列观察精确保持。原 pending SHA 743083a6409d9107ad66f99983ee018d843aee3dc8ba1b83d742fc6f05809256 原字节转为 record，writing 清理，active LC SHA f012ca3269d55f51831d1324f3cc602d2d0a894a0797e9a6c82d51ce73467051 保持。
- record：writer 12488 在 record 写完、release 前计划退出 1；reader 38344 退出 1，16 项中 15 过、candidate branch restores 失败。实际返回 PROCESS_LIVENESS_TIMEOUT，liveness_detail={}、retryable=true、unsafe=false、restart_required=false。恢复未成功，不能把安全拒绝记成通过。

两个 writer 各 23 项准备检查通过；总计执行 83 项，82 通过、1 失败（46 + 21 + 15 通过），并非 83 项全过。运行时 267 个 pins 按冻结输入/原件逐项核验，原宿主、workers、输入与原报告保持原字节。

record 业务安全补核：归档时只读遍历整个原 continue/v1，恰 3 文件、8 目录，与 writer before_termination、after_termination 及 terminated_continue_copy 完全相等，无新增、删除、改写。原槽 SHA 2a4513329433fa76973cff28fd6d95044d3b9b8e7accb275969a7510580eb1f5；owner SHA 7240f05ccdc4176fcf3fc8a575d63720048c52544db389aee9ada3ddc660d60c；active LC SHA 56a55a073523c561328a6758fbe36f964275c822d416c37f29e5038f89a674c5。完整目录比对见 inventory_audit.json。pending 的目录变化是预期原字节提交与释放，不能描述为全部目录不变。

两原 profile 的 process_liveness/v2 共找到并原字节保存 5 份 result.json：pending 3 份 target 54152，provider PID 44852/39468/19536；record 2 份 target 12488，provider PID 47596/9668。均为 windows_process_liveness_v1、dead、PID_ABSENT_87，nonce 与所属目录一致。文件仅含查询 PID、nonce、时间和结果，无凭据或玩家存档。没有独立 native query request 文件；结果内请求字段与来源映射见 ipc_index.json，不能捏造请求原件。

这些结果已经存在，不能说 helper 没有产出结果；它们也不证明 Oracle 在截止时间内完成消费、确认子进程退出或哪一次检查耗尽总预算。当前 timeout 来源未定位，独立 timing 诊断不属于本批结论。安全保留业务数据不等于恢复可用性完成。

新 observer 仍保存发射前真实注册身份与 ONE_SHOT 次序、HELD 类型快照及正式 Flow→Session→Slot 栈；发射时 flow_callback_connected=false 如实保留。reader 先经私有 QA gate 接受实际 Continue，再在同栈清除此 gate 后走真实恢复分支；公开入口、发行 EXE、SDK、OS 键鼠、人工体验及发布资格全部为 false。

raw 保留原始输入、结果和 5 份获准 IPC JSON；排除 6 份 terminated_continue_copy 业务载荷和 3 个冻结 EXE，不复制其他 profile、存档/LC、assets 或 cache。source_map.json 记录全部来源与 pins，manifest.json 覆盖除自身外每个文件。归档全程不改源码、不运行引擎、不操作 Git 或共享锁。
