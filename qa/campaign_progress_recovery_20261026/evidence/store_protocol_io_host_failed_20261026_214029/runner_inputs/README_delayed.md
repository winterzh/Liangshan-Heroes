# Delayed acquire 双进程切片

独立于原23进程工具。本目录新增 delayed_bootstrap.gd、delayed_worker.gd、run_delayed_acquire.py；不修改23阶段设计。**仅完成静态检查和宿主参数入口验证，尚未编译或启动 Godot。**

```powershell
# 只读 source preflight
python qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_delayed_acquire.py --base-run <已导入冻结目录>
# 修复验证：两案例，每案例两个同时受控的自有进程，总4进程
python qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_delayed_acquire.py --base-run <已导入冻结目录> --execute --expect fixed --wait-lane 1800
# 旧冻结缺陷复现：仅first_after_clear两个进程，不授修复通过
python qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/run_delayed_acquire.py --base-run <旧已导入冻结目录> --execute --expect defects --historical-freeze --wait-lane 1800
```

固定冻结根、根来源/generation、实际Provider身份、实际引擎、源语句/函数、worker SHA均核对。historical-freeze显式允许当前候选不同，但旧冻结仍须通过其完整生成身份验证，当前候选和已冻结来源各自前后pin，不把旧结果授予新源。默认每次阶段等待180秒，上限600秒；worker自身gate最多90秒。宿主只在显式execute时取共享锁；成功获锁立即跳出等待。全批持一把锁，允许本宿主持有Popen对象的两个PID同时存在；foreign检测为engines减own_active_pids。任何异常只终止自己的子进程，不按名称杀引擎、不操纵OS键鼠。

每案例使用单独私有四目录profile，同一案例A/B共用其真实账本。A执行实际Ledger.begin/progress/apply_campaign_handoff/retry_campaign_handoff；B执行实际Store.acquire/commit_locked/release及实际Receipt.prepare_begin/commit。B创建的随机token由Crypto产生；没有覆盖生产方法、伪造成功、直接编辑账本或替换生产身份。

## 精确时序

1. A正常创建账本、begin和progress5，冻结原handoff proposal/CAS并写prepared。宿主在新Store.acquire的mkdir writing之前停住A，保证A已经读完旧head。
2. B从同一head用真实Store+Receipt提交一个新run，使head前进一代；在release_marker_published实际断点停住B。
3. 放行A。A创建属于自身PID的writing/owner，看到B屏障后返回可重试WRITER_BUSY；commit_attempted必须仍false，原Store/owner/proposal/CAS保留，未写receipt.pending。
4. `first_after_clear`：直接放B完成释放，A此前绝不额外retry；然后A第一次retry旧CAS。
5. `retry_under_barrier`：B继续暂停，先让A真正retry一次，必须仍WRITER_BUSY并将commit_attempted记为true；随后放B清屏障，再让A retry。
6. fixed两例均须显式OWNED_HEAD_CHANGED、own_stale_lock_released、unsafe/restart_required，旧proposal/CAS保持原样，writing/cleanup/marker全部清除。A另建真实Ledger.open(require_existing=true)，证明B原head/record字节未变、A终局未应用、仍5 kills/0 wins。
7. A停在a_verified gate保持存活；B独立open_head验证，再由宿主放行A结束。defects仅first_after_clear，必须真的得到CAS_CHANGED、永久unsafe且A原owner锁仍在；B在A仍活时证明RECOVERY_REQUIRED和原owner未删。此模式complete表示缺陷复现，不表示修复通过。

原始prepared、a_blocked、barrier_retry（仅第二时序）、a_result、b_committed、双进程report/log/controller与全部断点栈保留。每案例case_receipt唯一创建，checkpoint_NN按案例数量独立创建；总receipt仅finally写一次，未放宽helper排他创建。

两进程的 ACK 均调用 `run_io.publish_ack`：同 stage 唯一临时 JSON 经排他写入并关闭后，以同卷 `os.link` 原子发布正式 ACK，拒绝覆盖已有目标，成功后仅删除自身临时目录项，失败保留证据。nonce/PID/index、严格 worker 校验与 gate 顺序保持不变；没有通过放宽身份校验规避空文件发布竞态。

ENV：DA_PROFILE、DA_PROJECT、DA_WORKERS、DA_WORKER_SHA256、DA_NONCE、DA_MODE(A/B)、DA_CASE、DA_EXPECT、DA_OUTPUT；B另读DA_PREVIOUS/SHA(A原prepared)。STEAM_DISABLED=1、CAMPAIGN_QA为空；保留最多四帧的非physics启动守卫。report schema为handoff_delayed_io_v1；production_qualified始终false，slice_passed只表示fixed本切片；defects明确diagnostic_only。

## 资格边界与待办

这是A真实Ledger＋B真实Store/Receipt的受控交错，**不授双Ledger并发成功**。若B也使用Ledger.begin_run，B清屏障后仍可能被A的活writing阻挡最终open_head：RECOVERY_REQUIRED被当前Ledger标成unsafe，不能在本工具中隐藏或称已修；须独立回归并确定该readback重试政策。

未覆盖双恢复者同nonce竞争、stale-abort释放再次遇I/O失败、完整篡改/活账号/PID复用负例、第三方写入、CFG/LC跨文件协调、真实SDK、断电、GUI/人工/性能与发布。没有对已拒绝的旧handoff再次申请奖励；本切片只验证它从未应用，并保留B已提交记录。
