# B2：真实设置 prepared 事务的启动恢复与重试

本目录是外部三进程 QA 工具。准备时只完成代码和静态来源准入，尚无本片原生运行、完整恢复或三进程通过资格。后续结果必须引用独立运行收据；本文件、cases.json 和 sources.json 的准备时状态不替代收据。B1 ui_config_retry 已封口，本片不修改或重新授予其资格。

固定完整源为 .godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project，身份 source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132。执行必须通过 integration_3365/prepare_projectile.py 的新冻结与自身首次冷导入完整准入：26 个脚本、1 个 native 输入，cold_import_qualified 必须为 true。来源表只绑定外部测试和实际命名依赖，默认不遍历完整资源树、不创建 profile、不启动引擎。

## 三个真实进程

1. prepare_crash：新私有 profile 正常启动，进入真实设置页，通过原控件修改偏好，再按原返回按钮。Settings.save 的合法先行写入与 Campaign 配置事务分账。宿主预装当前冻结 CFG 脚本的 cfg_before_install 断点；命中后必须核实际源码、函数、栈和原 Popen 身份，读取真实已闭合 prepared revision 1、candidate 原 SHA/语义以及 writing owner 的真实 PID，再受控终止自己的生产者。这里不是正常退出 0，没有完成保存的成功报告；计划终止只说明测试中断点已经成立。
2. startup_retry：在启动第二进程之前，宿主按上一阶段真实事务定位 candidate.cfg，验证文件类型、路径、SHA、字节数和 profile 归属，并持有允许读取但不允许 DELETE sharing 的 Windows HANDLE。正常 autoload 启动恢复已死生产者；真实 candidate→campaign.cfg rename 被拒绝，返回 CFG_INSTALL_RENAME。通过原 RetryCampaignStartup 按钮保持故障再失败；确认同一启动恢复对象和同一提案仍保留后，宿主只关闭自己的 HANDLE，再按原按钮完成该事务。成功后测试退出，不再次保存。
3. readback：同一 profile 的独立新进程正常启动，重新读取真实 CFG、journal、Settings 和 Campaign 偏好，与上一阶段 typed checkpoint 比较；没有新的 journal 代数、事务、奖励、记录、解锁或业务文件变化，然后测试退出。

三阶段只创建一次私有环境，后续进程复制环境字典。每进程有不同 process_nonce，全批 batch_nonce/profile 相同。新进程不能继承上一进程的对象标识；同对象断言只用于第二进程内部两个失败和最终重试。

宿主按 Godot 实际返回值，将 instance_id 严格视为非零 signed-int64 的规范十进制文本；RefCounted ID 可以为负，不能以只准正数误拒真实对象。拒绝 +号、前导零、-0、零及越界，保留同进程同对象检查；PID、provider PID、创建时间的原正数约束不变。此宿主校验修订不改变本片三份 GD、真实 recovery active 结构或 candidate/record 断言，也不继承 B1 失败批次的运行资格。

“三个进程”指三个实际 Godot 主进程；生产恢复链另外启动的原 ProcessLivenessProbe 不冒充这三阶段。宿主保留原生产者的 Popen/HANDLE 至读者完成，并保存真实 process_liveness/v2 查询原件，逐项核 nonce、目标生产者 PID、provider PID 与当前原生 dead 结果。unknown、超时或迟到报告不能当作已接受的死亡证明。第三次启动不得新增这些恢复查询；宿主只观察 helper 终态，不能按外部 PID 强杀它们来制造收尾通过。

## 当前生产链的精确边界

以下行号均指固定 b22 的 scripts/ 下原文件，不是候选覆写。

run_campaign_cfg_transaction.gd:299–310 实际提交 prepared 记录后进入 replacing；363–394 先校验 owner、candidate 的完整 ConfigFile 语义、原目标和 backup，再到 cfg_before_install。394 是最后可观察停点，395–396 才执行安装 rename。新 profile 的原 campaign.cfg 缺失，对应 original_sha256=ZERO；这不代表存在 generation 0 的记录。生产者必须真实产生 generation 1 prepared，不能以空 proposal、手写 journal、手写 candidate 或合成 LC/Intent 替代。

candidate 路径来自真实 document.transaction：user://campaign_cfg_candidates/v1/<transaction>/candidate.cfg。journal 位于 user://campaign_cfg_transactions/v1/5088120/1。宿主只对已验证的现存 candidate 开 HANDLE，不创建 sentinel、不阻父目录、不覆盖或重写业务文件。其缺少 DELETE sharing 只能由实际 Windows rename 结果证明；静态推断、持有 HANDLE 或期望错误码都不能独立充当原生故障通过。

pending_status:405–430 读取 journal；有外来 writing 时先 inspect_recovery。recover_pending:432–459 验证当前 identity、目标 owner、真实 prepared 请求，再经原 _head 恢复死锁并建立 replacing active。ContinueFlow:546–574 先执行正常 catalog/Steam startup 检查，保留 _startup_cfg 和 _startup_cfg_scope，已有 busy 对象重试时调用原 retry_write。此 prefs 事务不进入 progress intent 的 coordinator 分支。

首次恢复会合法移除已死生产者的 writing owner，并为当前读者获取新锁。生产者断点到读者首次安装失败之间因此不要求整个 inventory 完全相等：prepared/candidate/settings/原 CFG 状态必须保持，owner 变化必须明确绑定旧生产者与当前读者。首次安装失败到保持故障的按钮重试之间，才要求同一 reader owner、journal、candidate、公共 CFG 状态与完整业务 inventory 严格不变。

恢复对象的 _active 仅含 stage、transaction 和 record；_frozen_cfg 为 null。不能将它描述为跨进程保留同一个 ConfigFile。不可变提案以实际 candidate 原字节/SHA、Values.semantics、prepared record、transaction 和当前 scope 绑定。同对象重试需保留 _startup_cfg、其 _active、reader lock 和 _startup_cfg_scope；最终成功后原代码清空恢复对象与 scope 是预期行为。

ContinueFlow:519–524 每次 _startup_failed 都替换 last_result 并发出 operation_finished。retry_startup:526–530 先进入 RESTORING，再在原下一 process_frame 执行恢复；物理帧会由原535–539再延迟。这里的失败重试信号与 B1 RetryCampaignConfig 的无新增失败信号不同，不能套用 B1 的计数门槛。最终 startup success:603–614 调用 Campaign._load，完成 gate 并报告 startup_checked=true、progress_recovered=0、settlement_authorized=false；不能把最终结果杜撰为内部 CFG receipt 错误码。

成功 journal 必须是同一事务 prepared generation 1 → applied generation 2，只有 state/generation 和包裹链字段发生预期变化。candidate 被安装到公共 CFG；正常清理移除自己的 stage 和 writing，不能删未知文件。第三进程须独立验证相同 applied 2 和原字节库存，不新增 generation 3。

## UI、状态与证据

设置页走真实菜单、原 seg 控件和返回回调，RetryCampaignStartup 走实际可见错误按钮的原 pressed 回调。这是 source-private 引擎 UI 验证，不是桌面鼠标、真人体验或公开 Steam 构建资格。没有 Battle、剧情推进、终局、奖励或 SDK 调用资格。

UI 修改会合法改变 Settings 与 Campaign 偏好内存。分别记录 UI 前、编辑后/提交前、受控中断、恢复失败、重试成功；不能拿 UI 编辑前的完整 Campaign 内存要求失败后全等。初始进度 records/unlocked/owner 保持，恢复后偏好要等于真实已编辑选择；Settings 文件提前合法落盘单独核对，不能误称整套配置同一原子提交。

producer 的终态须是原 Popen 的实际计划终止，并保留断点/栈/原记录/文件库存；报告未到达最终 finish 不应编造。reader 和 readback 则要求实际退出 0、报告 passed/stage_completed 和全部检查成立。日志无错误或 stdout 单个 PASS 不能代替报告与进程终态。

跨进程数字字段先做有限整数规范；业务 typed checkpoint 用原 Codec 的编码/解码保存类型，不用 JSON 的 int/float Dictionary 全等代替。报告绑定 mode、PID、batch_nonce、process_nonce、profile、真实 identity、candidate manifest SHA 和 sources SHA。请求/ACK 还绑定请求原件 SHA；ACK 原子发布，不以半写入文件放行。

三个 GD 为 bootstrap.gd、base.gd、worker.gd，环境前缀 UST_，报告 schema 为 ui_startup_retry_three_process_v1。producer_ready.json 与 producer_submitted.json 使用 ui_startup_producer_observation_v1，分别保留按钮提交前的真实选择和返回按钮同步调用后的观察。第一进程的闭合断点、真实终止及原文件由宿主生成 ui_startup_prepared_fixture_v1，作为第二进程的 UST_PREVIOUS；第三进程的 UST_PREVIOUS 为第二进程实际 report.json。每次另传原件 SHA，不能把前驱报告复制成当前进程的读取结果。

故障请求 ui_startup_retry_gate_v1 使用 prepared_armed 与 release_candidate_install 两个 phase。前者 detail 精确含 stage_parent、cfg_path、journal_directory、producer_ready_sha256；后者精确含 candidate_path、candidate_sha256、journal_directory、transaction、expected_code=CFG_INSTALL_RENAME。公共十字段为 schema/mode/phase/pid/batch_nonce/process_nonce/profile/content_version/engine_sha256/detail；ui_startup_retry_ack_v1 将 detail 换成 request_sha256 与 ok，成为十一字段。宿主在请求绑定正确、原 Popen 和磁盘检查满足之后才发布 ACK。

只终止本宿主启动且仍可由原 Popen/HANDLE 证明归属的进程。HANDLE 清理、源码后验、收据保存和锁释放分别记录异常，不能掩盖首个 traceback；没有确认 child terminal 或共享 lane 空闲时不能释放锁。失败原件保留，不删除 profile 或旧收据。Windows 长路径、no-links、私有边界和不覆盖规则沿已验证 helper 执行。

## 来源与准入

sources.json 精确列 README、cases、宿主和三个 GD；表本身由宿主另行 pin，不循环自哈希。实际依赖包含已封口 B1 宿主的只读通用函数、其八个依赖模块以及 debugger wire。复用 B1 函数不调用 B1 测试入口，也不继承 B1 运行资格。运行时另冻结 bindings 与命名输入；完整执行还须固定新源、engine 和自己的 cold import 收据。

本片采用现有 debugger/文件 no-DELETE 句柄机制，不依赖 persistence19 的 CREATE_NEW sentinel/oplock proof；本片实际调用和失败机制仍必须独立原生证明。三进程总资格只由宿主在三个终态、来源后验和锁收尾都成立后授予，单个 GD、来源准入或纯加载均不授予整链通过。

默认命名输入检查（无 engine、profile 或全源哈希）：

    python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_startup_retry/run_ui_startup_retry.py

显式完整来源只读准入可加 --full-preflight；它会做昂贵的完整源检查，但不运行引擎。实际执行必须在根任务分配共享 lane 后单独调用：

    python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_startup_retry/run_ui_startup_retry.py --run --timeout 360 --wait-lane 0

360 秒是每个进程的限时，不包含完整源前后验证。--wait-lane 0 在 lane 被占用时失败，不后台排队。输出在 .godot/ui_startup_retry_20261027/<batch>/。宿主在该 ignored 目录保存生产者闭合 record/candidate/owner 的私有原件以供后续事务绑定，并逐项标记 private_business_payload=true、git_archive_allowed=false；这些 CFG/owner 载荷不得随公开 QA 归档或 Git 同步。可同步的是工具代码、精确来源表以及排除业务载荷后另行核验的收据和摘要。

## 后续未实现

本片只覆盖 prefs 类型 prepared 事务的启动恢复。progress/Cloud journal、LC/Intent/ACK 交接、自然终局 RetryTerminal 与重启不重放尚未由本片覆盖。

RetryRelease 的合法完整 HELD 路径尚未找到可通过外部可解除 I/O 故障触发的失败。后续可单列真实 Battle/Barrier 的 clock.abort_step 持久故障模型，验证 RetryRelease 持续拒绝与 LeaveHeldBattle 取消/确认；不能偷清 clock fault、放宽状态或宣称已经证明可修复成功分支。

本片不授予 public_continue、desktop_os_input、native SDK、正式 release、human acceptance、完整战役、61 阶段、原19故障、终局重试或发布资格。
