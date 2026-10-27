# B1：设置保存失败、同事务重试与独立读回

本目录准备两个真实进程的外部 QA：在完整 b22 来源下，通过实际菜单中的设置页更改选项，点击“返回（保存）”，让 Campaign 配置事务遇到宿主拥有的真实文件阻塞；保留阻塞点击原重试按钮再次失败，解除同一阻塞后再重试成功，最后用独立进程读回。

当前是工具准备阶段。静态检查、命名来源准入、脚本加载和两个进程的实际流程是不同资格；只有闭合的执行收据才能声明对应结果。计划文件中的 native_executed=false、passed=null 不预填通过。该片不实例化战斗，不授予自然战役、公开 Continue、桌面操作、SDK、人工验收、完整 61 阶段或发布资格。

## 来源和执行边界

- 基底为 .godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab，完整身份为 source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132。
- 执行前复用 integration_3365/prepare_projectile.py 的严格完整准入，要求 26 个脚本、1 个 native 输入及该冻结自身第一次冷导入闭合。来源完整检查不由本片另写一套全树包装器。
- 默认只核本片和命名依赖；不创建 profile、不启动引擎。执行由独占共享引擎锁的宿主显式发起。
- 两进程使用同一个全新隔离 profile。环境只创建一次，第二次复制已有环境；CAMPAIGN_QA 必须清空，禁止以该变量的非持久化分支代替生产保存。此片不需要私有 Continue 门闩。
- 生产脚本、冻结工程、旧 UI Save/Retry 工具均不修改。故障只由宿主在自己的隔离 profile 创建和移除。

## 第一进程：save_retry

1. 等实际启动扫描结束，确认菜单、原 Campaign 内存、文件存在性、配置 journal 和其他业务目录。新 profile 的 campaign.cfg 可以真实不存在；缺失状态必须照实保存，不能写合成初档来假定已有代数。
2. 打开实际设置页，确认初始 loose / normal，通过原控件回调选择“方阵”（Settings.formation_mode=box）和“困难”（Campaign.ai_difficulty=hard）。不用直接写这两个字段替代控件操作。分别记录 UI 编辑前、实际编辑后/提交前、失败及重试各边界：控件回调已合法改变 Settings 和 Campaign 偏好内存，不能要求失败后的完整 Campaign 内存等于 UI 编辑前。
3. 返回按钮仍连接生产 SettingsPanel.close。宿主只在已证明原目标完全不存在的 user://campaign_cfg_candidates 位置以 CREATE_NEW 创建普通文件；文件含本案 nonce，记录路径、类型、原字节 SHA 和长度。拒绝链接、目录、已有文件和 profile 外路径，不创建 v1。
4. 点击实际“返回（保存）”。生产先执行 Settings.save()，再请求 Campaign.save_prefs() 的后续非 physics 帧写入。预期准确错误为 CFG_STAGE_PARENT，显示实际 RetryCampaignConfig 按钮。
5. 只读核同一个 Campaign._cfg_writer、同一个 _frozen_cfg、同一个请求/事务/CAS/owner 与冻结语义。已编辑的 Campaign 偏好应与提交前快照和冻结配置语义一致；unlocked、进度 records、owner 等未编辑进度保持 UI 前原值。此时为 staging、writer busy，未产生 prepared journal，候选文件未写；Campaign 原配置文件或缺失状态不变。Settings 文件在返回时已经合法变化，单独记录，不把它误报为 Campaign 原子性失败。
6. 故障保留时点击实际 RetryCampaignConfig，准确再次得到 CFG_STAGE_PARENT。失败重试不发送 operation_finished；通过实际新 last_result 与原对象/文件状态验证重试，不能等待一个生产代码不会发送的失败信号，也不能只凭同样的旧错误文本判为发生了重试。
7. 宿主再次验证自己的 regular-file blocker 的路径、nonce、SHA、长度、类型与原归属，再只把它按原字节移出到本 stage 的 owned_stage_parent_blocker.json。点击同一个生产重试入口，原 writer 继续原冻结事务；成功后错误层关闭、暂停状态恢复、pending 清空。异常 finally 中只有自有 child 终态确认后才尝试移动 blocker，句柄关闭独立执行；不因原件变更而强制删除或覆盖。
8. 真实 fresh journal 起点必须先观察为 revision 0、没有记录。成功终态应为同一事务的 prepared generation 1、applied generation 2；这两个 journal 阶段只表示一次事务，不能报告为两次设置提交。保存实际配置、journal、设置文件和其他业务元数据，随后测试退出并由宿主验证真实进程终态。

## 第二进程：readback

使用同 profile 独立启动，正常完成启动流程，读取第一进程成功后的配置和设置。核真实 box / hard、Campaign 的全部八个偏好、同一 applied journal generation 2、原 transaction 与语义/文件 SHA，且原成功快照完整保持。

此阶段不再打开设置保存，不调用写事务或人为补恢复。核没有新的 pending、没有额外 journal 代数、没有 Slot/LC 或战役结算写入，再测试退出。两个进程与所有来源后验、锁终态都闭合后，宿主才可授予此 B1 两进程流程资格。

## 进程与证据协议

三个外部 GD 为 bootstrap.gd、base.gd、worker.gd，环境前缀 UCR_，模式严格为 save_retry / readback。报告 schema 为 ui_config_retry_two_process_v1；两个进程均测试退出，exit_reason=ui_config_retry_verified，不声称调用生产 AppLifecycle 退出流程。

第一进程使用 arm_stage_parent / release_stage_parent 两个 gate，schema 为 ui_config_retry_gate_v1 / ui_config_retry_ack_v1。每次请求与 ACK 绑定实际 PID、mode、phase、batch/process nonce、profile、完整 content/engine 身份与请求原 SHA；宿主只响应自己的当前 stage。请求中父路径必须等于上述唯一 user://campaign_cfg_candidates。

checkpoint 保留实际 disk / prefs / journal 及对应 exact_disk / exact_prefs / exact_journal。跨进程对比使用生产 Codec 的 typed 结果和原文件 SHA，不以 JSON int/float 的松散或错误比较代替精确状态。最终 journal 记录真实 prepared1/applied2 和原 transaction；初次失败的 revision 0 不表示存在 generation 0 记录。

宿主独立验证 journal 原 envelope、payload 字节数与 SHA、1→2 前驱关系和同事务字段，并将原 owner 文件/PID、首失败/再次失败对象观察及最后 transaction 交叉绑定。GD 报告不自行授予整链资格；只有两个原 Popen 终态、完整来源后验和本宿主锁释放都成立，host receipt 才可将 two_process_config_retry_qualified 设为 true。

## 命令

从开发工程根目录运行。以下默认命令只核命名来源；第二条仅显示用法：

    python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_config_retry/run_ui_config_retry.py
    python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_config_retry/run_ui_config_retry.py --help

经调度获得引擎车道后，两个实际进程的命令为：

    python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_config_retry/run_ui_config_retry.py --run --timeout 360 --wait-lane 0

只有显式 --run 才会申请共享引擎锁、进行完整来源准入并运行两个进程。--full-preflight 是显式昂贵只读完整准入，不启动引擎；单独 --base-run 不改变默认轻量行为。--timeout 默认每进程 360 秒（不含完整来源前后验），--wait-lane 默认 0，车道被占用时立即失败，不控制他人的引擎。输出独立保存在 .godot/ui_config_retry_20261027/批次目录，失败收据和自有 blocker 原件保留。

## 生产接口依据

以下行号对应固定 b22 工程内脚本：

- settings_panel.gd:142–151：实际返回按钮、Settings.save()、Campaign.save_prefs() 顺序。
- campaign.gd:263–285：请求冻结与延后写；329–338 只在 writer 不 busy 时丢弃对象；356–382 校原 scope 后继续同 writer。
- run_campaign_cfg_transaction.gd:209–220：真实父路径文件拒绝；239–252 构造冻结配置并进入 staging；269–280 返回准确 CFG_STAGE_PARENT；461–462 该 staging 故障不属于可以释放的未准备状态。
- continue_flow.gd:137–143,626–645：实际重试按钮和延后重试；失败保留错误层，成功恢复原暂停状态。

这是 source-private QA 对生产 UI 回调的验证，不等于操作系统桌面键鼠或人工体验验收。宿主故障控制与 GD 业务观察互相绑定；不得用模拟返回值、方法覆盖或输出字符串代替实际文件和对象证据。

## 来源封口

sources.json 在宿主与三个 GD 停改后生成，精确列本目录 README、cases、宿主、bootstrap/base/worker 六个文件和实际 Python 依赖；来源表本身由宿主另行 pin。运行时记录 frozen inputs，后续新版本不得冒用旧成功收据。没有执行收据时不得声称两进程通过。

## 后续未实现

- **B2 Startup retry**：需要真实已闭合 prepared journal 的生产者终止点；下一进程正常 startup 遇到可解除的自有文件拒绝，经实际 RetryCampaignStartup 完成原事务，另重启证明不再恢复。不能把 rev0 owner-only 锁拒绝当成 prepared 事务恢复。
- **C Terminal retry**：实际自然终局后，在真实 CFG/交接故障上保留同 Coordinator、LC、Intent、冻结 proposal；故障仍在时重试失败，解除后同对象完成当前 LC3/Intent2/ACK2，再重启验证无重放。旧 Intent1 工具结果不能直接转授。
- **D RetryRelease 与退出**：完整合法 HELD 释放路径尚未找到可解除的外部 I/O 成功触发。可独立用真实 clock abort_step 的持久故障模型验证实际重试持续失败，以及 LeaveHeldBattle 的取消/确认出口；必须标为故障模型，不偷清 _fault，不为凑成功分支改生产。是否存在适用的成功触发按具体合同另核，不把未找到当成已通过。
