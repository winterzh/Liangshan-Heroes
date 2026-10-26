# 唯一 cleanup/marker 原生 I/O 首个切片

本目录从已完成的旧 `handoff_candidate/tests/io` 工具独立复制、适配。首轮 `20261026_214029_e8825c44` 已完成 normal/legacy/write_retry/rename_writing/rename_owner 共132项；第六阶段遇宿主长 marker 路径读取失败，**完整23进程未通过**。原始失败保留在 `../../../evidence/store_protocol_io_host_failed_20261026_214029/`，不回填缺失断点记录。此次只修外部宿主，旧工具、冻结源码、生产和经典回归保持不变。Python AST/`--help` 与宿主 probe 不构成 Store 原生通过。

## 宿主与冻结契约

```powershell
python qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_io.py --base-run <已导入的新冻结目录>
python qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_io.py --base-run <已导入的新冻结目录> --execute --timeout 180 --wait-lane 1800
```

首条仅只读 preflight。`--execute` 默认完整 **23 个独立进程**，每进程最多 180 秒，共用既有引擎锁；未取得锁不启动。base-run 必须在本工程 `.godot/campaign_progress_recovery_20261026/`，实际安装的 `scripts/steam_receipt_store.gd` 必须逐字节等于本候选；旧 23c Store 不符合，不能拿旧通过结果代替。

冻结源码／root source／generation／candidate manifest／实际引擎／本候选 Store／宿主依赖／三个 worker 字节在运行前后核对。外部 worker 是 bootstrap.gd、worker.gd、run_io.py，副本只写新 output。原始报告、日志、controller、prepared 也逐份 pin。每进程检查实际 debugger PID、进程退出、nonce、profile、实际 Provider source identity。这里只通过真实 Store/Ledger 调用操作合成账户 `76561198000000001`；不覆写生产方法，不注入假成功。

输出为 `.godot/campaign_store_protocol_io_20261026/<batch>/`。每案例独立短 profile `D:/CodexQA/campspio/<nonce>/`；同一 crash 案例的第二/第三进程复用原四目录隔离 profile。保留失败目录、原始中断目录副本、owner/marker/record SHA。不要把这些私有 profile、账本副本或二进制加入源码提交。

宿主每完成一组写唯一 `checkpoint_NN.json`，最终 `receipt.json` 仅写一次；保留 helper 的排他创建语义。worker 在真实 I/O 前最多等待四个 process_frame，断言已退出初始 physics frame，不关闭生产物理写保护。

控制通道 ACK 通过共用 `publish_ack` 发布：先用 `helper.save` 在同 stage 排他创建唯一临时 JSON，写完并关闭，再以 Windows 同卷 `os.link` 原子创建正式 ACK 目录项；目标已存在则失败，不覆盖旧 ACK。发布成功后仅删除自己的临时目录项；写入或发布失败保留临时证据。若链接已成功而临时目录项删除失败，错误明确记录 `ACK published=true`，不重发；不支持硬链接时直接失败，不退回原地写 ACK。nonce/PID/index 及 worker 的严格校验不变，worker 不会再因正式 ACK 刚创建但未写完而读取空或半份 JSON。这只修复宿主控制通道，不授予 Store 原生通过。

宿主对账本的实际文件访问统一使用规范 Win32 扩展绝对路径，包括 marker 枚举/类型判断/读取/哈希、原生 `CreateFileW` 和中断副本复制；记录仍保存可读的普通路径。私有根范围比较在同一命名空间进行，原 `no_links` 在扩展路径及祖先上执行，避免长路径 `exists()` 假阴性漏查。复制仍拒绝既有目标。

已匹配的 PID/source/line/function/stack 在取 inventory 前存入 controller 的 `active_breakpoint`，fault 的状态区分仅命中、取证完成、目标解析及实际持有拒绝句柄/终止自有进程；仅命中不算故障已注入。宿主保留最初异常与 traceback，各项自有进程/句柄/socket 清理、日志哈希及后置取证独立收集 `post_errors`。任何后置失败均禁止通过，并尽力排他保存 controller/receipt；原写失败时只新建带唯一名字的备用证据，不覆盖残留。旧失败现场不回填断点或改写结果。

宿主 probe `host_probe_20261026_220422_3703ef68` 的16项检查通过：死 profile 的275字符 marker 可读；原 cleanup/marker 的只读拒 DELETE 句柄可打开关闭；原文件前后逐字节 SHA 相同；新私有目录长路径复制一致且拒绝覆盖；越界路径被拒绝；合成后置异常/证据碰撞保留原错误和备用证据。收据位于 `.godot/campaign_store_protocol_io_20261026/<probe>/receipt.json`，复制仅写新的 `D:/CodexQA/campsp_host_probe/`；未启动 Godot，下一轮仍须新 profile 全23阶段复跑。

## 23 进程范围

| 案例 | 进程数 | 目标与成功条件 |
|---|---:|---|
| normal | 1 | 实际闭合落盘、独立 Store head、精确九字段 handoff proof、generation 只加一、8 kills/1 win、重复 handoff 文件与计数不变 |
| legacy_upgrade | 1 | 实际 v2 envelope → 明确 v3 upgrade，原前驱 SHA 保留；再次 upgrade 不写 |
| write_retry | 1 | 真实 pending WRITE_OPEN，保持同 Ledger/Store、原 proposal/CAS，解除本控制器拒写句柄并仅移除自己创建的零字节占位后重试 |
| rename_writing_retry | 1 | writing 整目录 rename 前持拒 DELETE 句柄；RENAME 后原 owner 留在 writing，同对象原提案继续 |
| rename_owner_retry | 1 | cleanup/owner.json → marker rename 被真实句柄拒绝；RENAME 后原 owner 字节仍在唯一目录，同对象重试 |
| cleanup_delete_retry | 1 | 唯一空 cleanup 删除被拒；LOCK_RELEASE 后 marker 与目录保留，同对象释放完成 |
| marker_delete_retry | 1 | 最后 marker 删除被拒；LOCK_RELEASE 后无 cleanup，原 marker 保留，同对象释放完成 |
| crash_pending → recover | 2 | 旧闭合 pending 验证后终止；原 fixed-writing 基类恢复仍选择 forward_pending |
| crash_record → recover | 2 | 旧 record rename 后终止；原基类恢复仍选择 release_committed_lock |
| crash_half → recover | 2 | 旧半 pending flush 后终止；精确 ENVELOPE_JSON，保留残留并拒绝 proof；预期拒绝不是可恢复证明 |
| crash_cleanup → recover_claim_crash → recover | 3 | release_directory_claimed 后 writer 死亡；第二进程接管新 nonce 后再死；第三进程验证两 PID、原 owner/raw/SHA、record/head 不变并完成唯一释放 |
| crash_marker → recover_claim_crash → recover | 3 | release_marker_published 后 writer 死亡；marker 被第二进程改名接管后再死；第三进程还须证明原 cleanup 绑定不变 |
| crash_cleanup_removed → recover | 2 | cleanup 已删除而 marker 保留；新进程只收尾该 marker，保持 committed head 与 exact proof |
| crash_marker_removed → recover | 2 | marker 已删除，磁盘已干净；inspect_recovery 精确 UNKNOWN_OR_MISSING_LOCK，实际 Ledger.open 直接成功，不伪造 unique recovery |

所有可成功恢复的终局都必须达到 normal 的 exact proof、一次 generation/奖励与重复零变化条件；不能只看目录消失。四种拒绝由 Windows 原生分享句柄实现，不改 ACL 或源码返回值。断点必须命中真实函数/行/调用栈；SCRIPT/Parse/Compile ERROR 与超时不算故障通过。

`crash_marker_removed` 另在此前真实 `release_marker_published` 断点只读记录原 owner/marker 字节、SHA、PID 和 record 清单，再继续至最终中断点；因此干净终态没有 marker 时仍有原始来源证据，不从已删除文件猜造。

## 精确断点与环境

新 Store：`release()` 的 `release_directory_claimed` / `release_marker_published`；`_finish_release()` 的 `release_directory_removed` / `release_marker_removed`；`recover()` 的 `unique_release_recovery_claimed`。四种拒绝分别在 writing rename、owner rename、cleanup remove、marker remove 的真实 `DirAccess` 语句之前停住。宿主逐一要求源码语句唯一匹配并记录 SHA；旧 SnapshotStore 的 pending_verified/record_renamed/pending_half 原边界仍保留。

环境为 `SP_PROFILE`、`SP_PROJECT`、`SP_WORKERS`、`SP_WORKER_SHA256`、`SP_NONCE`、`SP_MODE`、`SP_OUTPUT`；恢复另有 `SP_PREVIOUS/SP_PREVIOUS_SHA256`。STEAM_DISABLED=1、CAMPAIGN_QA 为空。bootstrap 自身、宿主与 worker 由宿主 pin。JSON gate/worker report 沿用原严谨 schema，新的总 receipt schema 为 `campaign_store_protocol_io_runner_v1`，不混同旧13阶段资格。

第三进程的前驱是第二进程终止前写出的 prepared：冻结原 handoff/basis/identity/profile/nonce，同时记录 origin_writer_pid、origin_mode、predecessor_pid、接管前 claim_plan、原 owner raw/SHA、全部 record SHA。第三进程验证最近 claim_pid 等于第二进程，dead_pid 等于原 writer，两者均已退出；新 claim nonce 不等于旧值。新恢复调用使用原 API，不手工移动协议文件。

## 明确尚未覆盖

- 两个恢复者同时争抢同一 nonce 源；延迟 writer 与另一 cleanup/marker 的并发交错，及 CAS 改变后的 stale-abort/restart 分支。
- 活 writer/claimant、不同账号、owner/marker/head 篡改、额外 marker/目录、非规范名字、链接等全部拒绝矩阵。
- 基类旧 recovering、旧无标记空 writing、旧 owner 删除窗口的协议改造；它们未因本切片获得恢复资格。
- 真实 Steam SDK/账号、战场/GUI/人工体验、Campaign CFG/LC 跨文件终局协调、断电持久性、磁盘耗尽、MAX_RUNS256 与历史退休。

Windows 长 marker 路径与分享权限是否实际可用，仍需首轮原生结果确认。任何通过只适用于明确列出的23进程切片，不是完整并发或全协议验收。
