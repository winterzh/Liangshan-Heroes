# b22 保存与重试界面：三进程外部工具

本目录准备验证统一冻结 b22 的实际 `ContinueFlow` 保存、覆盖取消、同事务重试，以及菜单继续失败后的恢复。当前交付外部 QA 工具正文与静态接口核对；没有本目录的原生执行收据，不表示三阶段通过。默认入口只核命名来源，不启动引擎、不创建 profile。历史通过、静态检查和脚本加载均不替代本目录的实际执行。

固定受测工程是 `.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project`，完整身份为 `source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132`。执行须由 `integration_3365/prepare_projectile.py` 对这个新 run 完整准入：26 脚本、1 原生依赖、完整源码身份和它自己的首次冷导入收据。外部 bootstrap/base/worker/inflight 不覆盖工程脚本；受测源码、旧 runner 和旧证据不修改。

## 本片三个阶段

| 顺序 / mode | 实际操作 | 必须保留的证据 |
| --- | --- | --- |
| 0 `save_initial` | 新私有 profile，正常菜单进入经典战斗，通过实际 `SaveAndExit` 保存并退出 | Slot gen1、完整 typed 保存检查点、LC 原件摘要；真实 `AppLifecycle` 的 `continue_saved` 原因和原 Popen exit0 |
| 1 `retry_save` | 独立进程恢复；已有槽 `SaveAndExit` 出现 `ConfirmSave`/`CancelSave`；先取消，再确认；真实 owner 删除失败后两次点击 `RetrySave` | 从暂停菜单请求保存，取消同栈保留暂停及同 Battle/槽/LC；随后实际 Resume 按钮恢复并观察至少120正常 ticks，再以 viewport Esc 暂停确认。运行段不能要求世界逐字段静止。第一次重试仍受阻，第二次解除宿主句柄后使用同 Session、Store、原 CAS 和 proposal；同一 HELD 检查点、时钟与 lease 不变；只增加一代到 gen2并真正保存退出 |
| 2 `reject_then_resume` | 新进程先在菜单受到真实文件拒绝，点击 `ContinueBattle` 失败，点击 `CloseError`；移除宿主拒绝后再次正常 Continue | 第一次失败前后仍是原菜单、无 Battle、无私有挂载残留，原 Slot/LC 字节不变；恢复后 gen2 与阶段1实际冻结检查点精确匹配，LC/槽无额外代数或重放；最后仅测试退出，不再次保存 |

`cases.json` 是范围和断言契约，不是通过报告。阶段报告中的本地断言、宿主断点/原生句柄证据、实际进程退出及最终来源/锁检查必须一起通过，才可给本片资格。累计检查不得跨报告重复相加；预期拒绝本身不等于整阶段通过。

外部四个 GD 为 `bootstrap.gd`、`base.gd`、`worker.gd`、`inflight.gd`；最后一项复用旧经典夹具的只读 typed 观察，不制造战斗状态。报告 schema 为 `ui_save_retry_three_process_v1`，环境前缀为 `USR_`。当前 gate 顺序为阶段1 `arm_owner_release` → `arm_retry_release` → `release_retry_handles`，阶段2 `arm_record_read` → `release_record_read`；ACK 绑定实际 request SHA、mode/phase/PID、batch/process nonce、profile 和源码/引擎身份，JSON PID 必须逐字段规范为有限整数。运行时生成的 `bindings.json` 是宿主与 worker 的冻结接口，不是开发期来源表。

每次原219行暂停都先移除本次断点再继续，并一直持有原owner句柄。首次实际LOCK_RELEASE及同对象/HELD观察已完成后，worker才发布`arm_retry_release`；宿主核同owner原字节和业务清单，再重新设断点并ACK，随后才由原RetrySave触发独立重试调用栈。不能把尚在首次保存栈内的再次暂停算作重试。

阶段1精确世界比较只用于取消的同栈暂停边界及第二次保存的 HELD 边界；最终恢复基准取实际第二次 HELD 检查点，不能沿用经过120 ticks之前的旧 clock。

## 真正的故障位置

阶段1在冻结 `scripts/run_snapshot_store.gd` 的 `release()` 删除 owner 语句处，用真实 debugger 停住自有 Popen。宿主只打开本 profile 的 `writing/owner.json`，允许读写共享，拒绝删除共享；此时 owner 原字节与实际进程 PID、锁 token、目录和调用栈必须对应。

这必须使实际生产删除返回 `LOCK_RELEASE`，留下可确认归属的 owner 和原 proposal。不得换成锁住 `writing/`：原基类先删除 owner，再删除目录，后者失败可能导致归属丢失及 unsafe 状态，不能冒充同事务成功重试。不得改 Store 返回值、替换 Session/Store、注入一个假的 pending 状态，或通过清除时钟故障制造恢复成功。

宿主不读取或改写 debugger 局部变量：精确源码行和原 Store→Session→Flow 调用栈、实际 owner/记录原字节，以及 GD 只读对象观察互相绑定。

第一次 `RetrySave` 保留宿主句柄，再次真实失败；第二次仅释放该自有句柄，再点实际按钮成功。检查生产 `Session.retry_pending_save()` 仍绑定同 Battle、HELD、完整时钟、Steam lease、Store 原 CAS/proposal。提交后解锁失败的目标记录已经存在，重试不得另写下一代或重复记奖。

阶段2在 startup 已完成、首次 Continue 之前，对实际 gen2 的 `record_0000000002.json` 持 OPEN_EXISTING、只读 access、share=0 的宿主句柄，使生产槽读取实际返回 `READ_OPEN`；不改文件字节、ACL 或 attributes。必须先证明菜单失败和关闭错误，再修复并恢复；不能先成功 Continue 到 Battle，再声称进行了菜单拒绝测试。故障前后的比较基准包含完整 Slot/LC 文件与目录清单，并区分宿主自有控制证据。受阻时 worker 仅核可读 LC 与目录名；宿主释放自有句柄后核完整业务清单及原 record SHA，不能在 share=0 期间另开文件读失败后假称已核全字节。

本片不使用 persistence19 尚未取得本轮证明的 CREATE_NEW 候选写拒绝或 oplock 读区间注入。复用的是已有 debugger/Windows share-delete 拒绝机制；复用代码仍须在本片实际断点、目标文件和进程上重新留下证据。

## 界面与身份边界

真正按钮名称是 `ConfirmSave`，不是 `SaveConfirm`。按钮须可见、启用，并由原连接进入 `ContinueFlow`；菜单、暂停 HUD、提示层及 `AppLifecycle` 均使用受测实现。允许外部 QA 通过引擎 viewport 输入或已验证的真实按钮回调触发控件；报告必须记录具体路径。它不等于操作系统桌面键鼠，也不等于真人验收。

使用隔离 profile、禁用 Steam SDK、显式 private Continue 入口；不授公开玩家入口、真实账号/SDK、完整30波、自然完整战役、19故障、52负例、61阶段、Steam发布或人类验收资格。阶段内 typed 检查点用于核恢复，不是伪造世界或修改生产 gameplay 字段的许可。所有 wider qualification 必须明确 false。

运行期必须共享引擎 lane、只终止宿主创建的 Popen；完整来源/引擎检查、nonce/PID/命令/profile/报告绑定和自有锁终态均保留。每个 profile 的环境目录只创建一次，后续阶段复制环境字典。Windows 长路径使用已有扩展路径助手，所有写入/句柄目标先校验私有路径及 reparse 边界。不清理失败 receipt、日志、控制证据或未知业务文件。

## 入口与来源

`python run_ui_save_retry.py` 为默认命名来源预检；`--help` 只显示参数。`--full-preflight` 才执行显式的完整源码只读准入；`--run` 才取得共享 lane、执行完整 b22/自有冷导入准入并运行三进程。`--timeout` 默认600秒/进程（不含完整来源准入，最小60），`--wait-lane` 默认0，lane被占时不排队。`--base-run` 固定为上方 b22 run，不能切换为旧祖先。参数和输出以实际宿主 receipt 为准；本README中的命令不是已执行记录。

`sources.json` 精确列 README、cases、host 和4GD共7件本片文件；另列实际导入的9个小Python依赖和逐字复用的旧经典 `inflight.gd` 来源。来源表本身由宿主单独 pin，不自引用。仅整条三进程实际终态及所有后验通过，宿主才可给 `three_process_flow_qualified=true`；单stage报告不得替代整链收据。

## 可复用的旧证据，不转授当前通过

旧 `tools/continue_flow_qa.gd` 的确认、取消、菜单错误和独立进程恢复断言可参考。`qa/continue_flow_20260909/20260909_085735_9439525c/receipt.json` 实际为旧源码295检查、11行为进程通过；其 `pending_retry` 使用 `ReleaseFaultSlot` 测试子类及直接安装 Flow Session，不是本片真实文件拒绝。旧 `owned_slot_retry` 的76项使用简化文档验证器，`production_slot_document=false`，也不授本片资格。

## 后续 B / C / D，尚未实现

- **B：Settings/Config 和 Startup retry。** 使用实际“设置→返回（保存）”进入 `Settings.save()` 与 `Campaign.save_prefs()`；隔离空 owner 的本地 prefs 事务受真实 stage-parent 文件阻塞，核 `RetryCampaignConfig` 同 writer/ConfigFile 先失败、修复后成功。Settings 文件合法变更与 Campaign CFG 原子边界分别记录。另在真实 CFG `cfg_before_install` 停止自有 producer，保留完整 prepared journal，下一进程正常 startup 遇可解除的 candidate rename 拒绝，再经 `RetryCampaignStartup` 完成；独立重启不重放。不能把 rev0 的 `CFG_LOCK_WITHOUT_PROPOSAL` 偷换为可恢复正例，也不能把 SDK-disabled synthetic owner 的 Cloud 拒绝当作已授权账号成功重试。
- **C：RetryTerminal 同对象后重启不重放。** 迁移旧 `pending_terminal_ui_candidate_v2` 的实际按钮、Coordinator/CFG writer/ConfigFile/LC/intent 同对象与完整字节断言，接 b22 的真实自然终局流程。真实 stage-parent 故障保持 LC gen2、不发结算；原按钮在故障未解除时再次拒绝，解除后同对象完成 LC3、Intent2、ACK2/真实本地 handoff、原 `_complete_end` 恰好一次。独立同 profile 重启不创建 Battle、不授结算、不重复进度/奖励。旧 V16 宿主依赖旧 all61/Intent1，不能直接作为 b22 准入；直接 `win/lose` 或合成 Mission 只能单独标组件夹具，不能当自然终局。
- **D：RetryRelease。** 旧 `held_error` 注入永久 clock fault，验证重试仍失败、退出确认取消和显式退出。b22 的 `abort_step()` 没有清 fault API；`release_capture()` 遇该故障必须拒绝。可以另立明确的故障模型覆盖失败保持路径，但当前尚无不修改状态/不替身的可修复成功触发方案；不得清 `_fault`、替换 clock 或弱化断言以获得成功。正常完整 HELD 路径没有可解除的外部 I/O 故障，持久 clock fault 和不匹配的 held 状态也不是可自愈条件。因此当前没有可修复成功触发证据；最终依据原要求判断成功分支是否适用，不能为凑不可达成功增加门槛或更改生产。

以上后续要求不因 A 组三阶段完成而关闭，也不计入本片检查数。
