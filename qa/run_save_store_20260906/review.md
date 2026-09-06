# 磁盘草稿独立复核

2026-09-06，soak_route_fix。只读核查原始收据、源码和实际夹具；仅更新本目录两份说明及本审阅，不改 store、QA、历史运行记录，不启动引擎。有限磁盘范围内未发现假通过；尚不能接入生产保存/继续按钮。

## 证据核对

`current_qa_summary.json` 所列五份 receipt 的 SHA 均匹配；当前 store `86619f5c…`、runner `233dcd47…` 与每次 preparation/runtime 副本一致。49 个具体案例无重复或遗漏地覆盖当前 catalog。54 次子进程包括 **50 次 exit=0、4 次预期终止 exit=1**；1,233 次断言恰为 50 份普通报告之和，没有把中断 writer 算作普通通过或叠加其未产出的检查数。

全部 54 个阶段逐项核对了 manifest SHA、run/case/phase、实际 PID、错误日志和准确退出确认，以及磁盘上 slot/pending/previous/lock 的存在状态、原字节长度和 SHA。四个中断 checkpoint 与其 process 收据一致，后续 reader 使用相同 references，实际完整 A/B 封装的长度、payload 摘要和 revision/marker 均吻合。中断 writer 无普通报告。四次对应关系为：

| 检查点 | 被终止 PID → 新 reader PID | 留存实物 |
| --- | --- | --- |
| temp_closed | 2324 → 37360 | slot=A，pending=B，锁 |
| backup_moved | 9068 → 36676 | previous=A，pending=B，锁 |
| committed | 29060 → 6476 | slot=B，previous=A，锁 |
| backup_removed | 27216 → 15684 | slot=B，锁 |

四个新 reader 均返回 RECOVERY_REQUIRED，读取/保存重试未改残留。这证明受测中断点保留了完整数据并拒绝猜测恢复，不证明已恢复战斗或实现断电持久性。

挑查异常状态也与实物吻合：replace_no_rollback/rollback_read 的 A 留 previous，未声称原路径恢复；replace_external 保留外来 slot 并报 unknown；final_read 的 B 虽在 slot，仍报 COMMIT_UNVERIFIED/unknown；backup_changed、cleanup_previous、cleanup_lock 为已验证 B + ok=false，其中最后一例旧 previous 已删，只保留 B 和非空锁。new_write_open 正确区分最初无旧槽，不把“空槽保持”说成“旧档恢复”。删除备份失败通过真实 Windows 只读属性触发；其他返回错误接缝清楚标为注入，不当作真实磁盘满或断电。

旧 empty_file 的 QA `_hash(empty)` 错误、旧 empty_payload 的 store `_digest(empty)` 两条 ERROR 仍保留；即使原日志末尾为 failures=0、exit=0，顶层 complete=false，未并入当前 1,233。空摘要修复前后来源链完整。

## 接入生产前的最小缺口

1. **生产路径与调用生命周期。** 当前 `_guard` 只接收已存在的 `res://scratchpad/run_save_store/fixtures/<case>`，没有玩家 user:// 路径契约、初始化或产品入口。需独立明确受控目录、存档归属、权限失败显示，以及单写者/读取序列；当前正常重启不是同时读写隔离证明。现有 49 案例没有真实执行越界路径、缺目录或链接拒绝案例，生产路径改动须针对其实际边界补测。
2. **残留事务恢复。** 现在任何 pending/previous/锁都会阻断。需要对这些实物组合设计可重复执行的恢复决策，完整验证候选后才决定保留/恢复，明确 unknown 与 new_verified+清理失败的产品行为。空锁目录自身不证明旧进程已死，不应直接按时间删除锁或覆盖未知文件。
3. **真实 codec 与场景恢复。** validator 只认识 disk_fixture 的四字段假 payload。完整战斗 schema/内容兼容性、实体稳定 ID 和引用图、RNG/定时器/队列、暂停快照屏障与新场景恢复均未实现。应先选一个明确受支持的战斗阶段，完成完整验证再构建场景，并用独立进程受控快照/恢复验证状态；不能只改 FIXTURE_ROOT 或把 Dictionary 序列化后就开放继续。

普通 flush/关闭、同次失败回滚和进程被杀后的留存均不能推广为掉电、跨文件系统、恶意外部写入或所有平台的持久性。无需为本次有限磁盘证据新增公共 QA 框架；下一工作应先解决上述产品契约与恢复/codec 边界。
