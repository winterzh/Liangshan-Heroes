# 经典恢复只读计时原件（2026-10-27 03:14:18）

原批次 .godot/classic_recovery_timing_20261027/20261027_031418_1f3a2756，冻结来源 source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac。
宿主 complete=true；实际 Godot PID 71048，exit 0，用时 78.627 秒，原日志无错误。15 项诊断检查全部通过，229 项运行时 pin 逐项核验。来源前后检查、自有引擎/helper 终态、锁归属与释放收据均为 true。

本次只执行四个原 API 计时：

| 调用 | 用时 | 实际结果 |
| --- | ---: | --- |
| independent.inventory | 359.302 ms | 成功 |
| independent._chain | 1479.211 ms | 成功 |
| independent._verified.record1 | 1512.568 ms | 成功 |
| initial.inspect_recovery | 3807.554 ms | PROCESS_LIVENESS_TIMEOUT |

预算保持原 3000 ms。首次 inspect 返回 retryable=true、unsafe=false、restart_required=false、liveness_detail={}。按工具合同停止；preclaim_attempted=false，分项及整段 whole_preclaim_result 都是空字典。没有执行 recover、创建 claim，不能把这一批写成完整整段恢复计时通过。

唯一 helper PID 21436 已实际退出 0，Oracle 确认 cleanup；原 JSON 的 target PID 12488、nonce、provider PID 与 Oracle 观察及宿主副本逐项相等，结果为 dead / PID_ABSENT_87。119 ms 是 Oracle observed_ms 与 started_ms 之差，不是另一次 Win32 精确计时。helper 已产出并被接受的结果，不支持“helper 没有结果或挂死”的描述；也不单凭本批结果给先前 02:37:31 超时定位具体分支。

原目录和新副本完整 continue/v1 各 3 文件、8 目录；归档时再次只读计算字节数、SHA 和目录集合，与本次 original_inventory、原 writer before/after 全部一致。原 3,961,694 字节槽 SHA 为 2a4513329433fa76973cff28fd6d95044d3b9b8e7accb275969a7510580eb1f5；owner 为 7240f05ccdc4176fcf3fc8a575d63720048c52544db389aee9ada3ddc660d60c；LC 为 56a55a073523c561328a6758fbe36f964275c822d416c37f29e5038f89a674c5。原 profile 未传给引擎，仅在新隔离副本运行。详见 inventory_audit.json。

四项计时是独立调用，不是 initial.inspect 的内部逐段测量，不可简单相加来重建该调用。先前读操作可能预热缓存；原 report 保留每次调用外的 inventory guard、provider 采样和摘要开销。complete=true 只表示本次同字节隔离诊断按合同结束、业务原件与副本保持，不授予恢复成功、公开入口、发行 EXE、SDK、OS 键鼠、人工体验、性能或发布资格。

raw 保存真实宿主、全部 workers、provenance、相关源/导入/full-freeze 元数据、原 report/receipt/log 和一份只含查询元数据的原生 IPC JSON。优先使用本批 runner_inputs 原字节；排除其中 external 的 3 份业务载荷和 2 个 EXE，不复制 profile、cache、assets 或其他存档。source_map.json 记录全部映射、229 pins 和排除原因；ipc_index.json 记录原生查询来源；manifest.json 覆盖除自身之外所有归档文件。

归档仅写本目录，不修改源或运行输入，不启动引擎、不操作共享锁或 Git。
