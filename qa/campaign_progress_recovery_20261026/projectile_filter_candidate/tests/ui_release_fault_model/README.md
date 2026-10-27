# D：永久时钟故障下的 RetryRelease 与退出界面模型

本目录准备两个独立原生进程的外部 QA 工具。编写与封口时只完成源码审查和命名来源绑定，尚未运行本片引擎；实际结果以后续完整 `receipt.json` 为准。工具不修改生产脚本，也不继承 A、B1、B2、C 或历史战役工具的运行资格。

固定工程为 `.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab/project`，完整内容身份为 `source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132`。执行入口要求该工程自身的冷导入收据、26 个候选脚本和 1 个 native 资产、完整 generation/source/engine/pins 准入；不能以祖先项目或本目录静态检查代替。准备与冷导入原件见 [完整冻结归档](../../evidence/full_freeze_20261027_075456/README.md)。

本片明确执行一次真实 `run_battle_clock.abort_step("QA_INJECTED_CLOCK_FAULT")`。这是人工构造的永久故障模型：`fault_model=true`、`no_gameplay_state_injection=false`、`natural_fault_reproduced=false`。不写 HP、位置或资源，不替换生产方法、Clock、Barrier 或 Session，不清除 `_fault`，也不把持续失败伪装成可恢复成功。

## 为什么采用此模型

固定 b22 的 `run_battle_clock.gd:62–64` 只在首次故障时设置 `_fault` 并关闭当前 step；注入前已实际证明 healthy HELD、`in_step=false`。`run_battle_barrier.gd:203–208` 与 Clock 的 `release_source_hold:80–82` 对已有 fault 明确拒绝释放。正常完整 HELD 路径未找到可通过解除外部 I/O 阻塞恢复的成功触发；伪造不匹配的 hold 或偷偷清 fault 都不能证明真实成功分支。

`continue_flow.gd:332–364` 在非 pending 的保存失败后处置 Session，尝试释放并保留原 Battle；`retry_release:399–412` 失败时只更新 `release_error` 与错误界面，不再发 `operation_finished`。`_request_failed_exit/_cancel_failed_exit/_confirm_failed_exit:414–427` 提供原 Leave、取消和确认出口；确认通过原 AppLifecycle 的 `continue_failed` 路径退出。该模型验证这些合法持续失败及退出行为，**不授予 `retry_release_success_qualified`**，也不证明生产中自然发生了故障。

## 两个实际进程

| 顺序 | mode | 实际操作与判据 | 退出 |
|---|---|---|---|
| 0 | `fault_exit` | 原菜单启动经典 30 关，普通 1x/60 Hz 运行至少 120 tick；原暂停与 SaveAndExit；健康 HELD 只注入一次 fault；原 RetryRelease 仍拒绝；Escape 不能关闭被保持的错误；Leave → Cancel 保留同对象与状态，再 Leave → Confirm | 原 AppLifecycle `continue_failed`，宿主必须观察自己的 Popen 正常退出 0 |
| 1 | `restart_no_slot` | 同 profile 的独立正常启动；实际菜单 Continue 返回 `NO_SLOT`、没有 Battle；原 CloseError 回到同一菜单，业务库存与 typed 进度不变 | 测试退出 `ui_release_fault_model_verified`，退出 0；不另行保存 |

两个进程必须有不同 PID 和 process nonce，共享新建私有 profile 与 batch nonce。每个进程只允许一次实际失败 `operation_finished`：第一进程来自原保存失败，RetryRelease/取消/退出不增加信号；第二进程来自实际 NO_SLOT。宿主先确认前驱终态，再向后继传入前驱原报告路径和 SHA。标准输出中的 PASS 不作为完成依据。

首进程在原 SaveAndExit 前注册一次性观察者，记录注册前后完整 `capture_ready.get_connections()` 行：连续 index、实际 Callable、对象 ID、方法、valid、唯一角色和 `CONNECT_ONE_SHOT`。只要求 observer 与原 Flow 回调各一项，**不假定枚举次序**。按钮返回同一同步栈时必须仍为 SAVING / REQUESTED、Session 为空且调用数为零。实际发射时再次证明 healthy HELD、非 physics、原 Clock/Barrier/Battle、Session 尚未建立、观察者已解绑，再调用一次原 abort API。ONE_SHOT 发射期间原 Flow 回调可能已从连接表移除，其布尔值仅记录，不误作必须仍连接的门槛。

故障前后只允许 held observation 的 `clock.fault` 改变。之后每次失败、Escape、Leave 确认和取消都核同一 Battle/Clock/Barrier 实例、原 HELD/paused/input gate、时钟、原 Slot CAS、typed 世界观察、Steam lease 和无 local receipt。取消必须在同一同步帧返回原错误界面。确认后报告不自行 quit、不等待额外帧，原 AppLifecycle 持有三帧释放音频及退出路径。

这里的 typed 世界观察覆盖实体身份、HP/位置、状态/home、训练队列与进度、经济、击杀、next ID、人口上限和经典关卡时钟等本片状态；它不是完整世界序列化/恢复验收。非 pending Session 已被原 Flow dispose 并置空，工具不持有伪造 Session 作为重试对象。

## 文件、类型和隔离边界

新 profile 必须实际没有 `continue/v1`（因此 Slot 与 LC 均缺失）、`campaign.cfg`、`campaign_cfg_transactions/v1`、`campaign_cfg_candidates`、`steam_receipts/v1`。原 `Slot.inspect_slot()` 必须返回 absent / revision 0 / ZERO SHA；这不代表存在 generation 0 记录。首进程前后及第二进程前后，宿主从磁盘独立观察这些完整有界目录/文件库存，并要求与原缺失状态完全相同。GD 另外用生产 Codec 比较 typed 业务 metadata 与 Campaign/Steam 进度，记录不增、unlocked 仍为 1、没有 credited run。

原 `continue_error.json` 是单列诊断，允许首进程写故障代码、第二进程写 `NO_SLOT`；宿主只接受其原三个字段 `code/restoring/engine`，保存该小诊断原件。不能把它计成业务存档增长。Settings 并非本片承诺的完整磁盘不变范围；本片没有设置保存操作，不将此模型扩大为 Settings 原子事务验收。

跨进程保留原 `checkpoint.exact_business/exact_progress` Codec 值，后继先原 Codec 解码校验，再独立读取当前业务与进度编码比较；不通过原始 JSON Dictionary 的 int/float 差异放宽语义。对象 ID 使用规范非零 signed-int64 十进制字符串；宿主 PID 和实际 Popen 所有权保持独立校验。内部 Viewport Escape 与可见 Button 的原 connected callback 是引擎内 source-private UI 操作，不是桌面鼠标键盘或人工体验资格。

工具只有 `bootstrap.gd/base.gd/worker.gd` 三个 worker。`bindings.json` 由执行宿主生成并逐文件绑定运行副本；环境使用 `URF_`，`CAMPAIGN_QA` 为空，`STEAM_DISABLED=1`，私有 Continue 门闩与 profile 必须匹配，四个 Windows 私有环境目录只创建一次，后继只复制环境字典。没有 debugger、断点、host 业务故障句柄或文件改写；唯一故障注入在上述 GD 同步边界。

宿主从已封口 B1 Python 只复用路径、完整身份、pins、错误保存等 helper，来源清单明确绑定 B1 host 及其 8 个模块；不调用 B1 测试或授予 B1 资格。三份 A GD 只作为改编来源单独 pin，不声称逐字复制或继承 A 的 216 项结果。

## 执行与证据

从项目根目录调用。默认只读取命名文本来源，不扫描完整资源、不创建 profile、不拿引擎锁、不启动 Godot：

```powershell
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_release_fault_model/run_ui_release_fault_model.py
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_release_fault_model/run_ui_release_fault_model.py --help
```

只有独占引擎调度者执行实际两进程：

```powershell
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/ui_release_fault_model/run_ui_release_fault_model.py --run --timeout 360 --wait-lane 0
```

`--full-preflight` 是显式昂贵的完整源只读准入，不启动引擎；不必在 `--run` 前重复执行。360 秒是每个子进程期限，不包含完整源前后验；`--wait-lane 0` 在共享 lane 被占用时直接保留失败结果，不终止其他进程。默认 base run 即上述 b22，另传 `--base-run` 不能绕过固定源和自身冷导入门槛。

输出为 `.godot/ui_release_fault_model_20261027/<batch>/`：冻结 `runner_inputs`、三 worker 与 bindings、每阶段 `native.log/report.json/controller.json/continue_error.json`、批次 `receipt.json`。GD schema 为 `ui_release_fault_model_v1`，整批 schema 为 `ui_release_fault_model_two_process_v1`。仅宿主在两份实际报告通过、不同 PID 均终态、原生错误为空、完整源/引擎/pins 后验通过、自有进程 handle 关闭、共享 lane 无残留且只解除自身锁之后，才可置 `two_process_release_fault_model_qualified=true`。任一失败保留原始异常 traceback 和独立 cleanup 错误，不删除失败目录；清理只操作自己创建的 Popen。

封口清单中的 `native_executed=false` / `passed=null` 是编写时状态，不能作为运行结果。后续资格读取新批完整 receipt，不回写冻结输入。尚未运行时不填写检查通过数。

## 仍不覆盖

本片不验证可解除故障的 RetryRelease 成功分支；当前没有证明可用的合法触发，不能为补成功数字而改生产或清 fault。A 的 SaveConfirm/Cancel/同 proposal RetrySave、B1 设置 CFG 重试、B2 prepared Startup 重试、C 自然 terminal 重试属于各自独立工具，结果不能互相转授。公开 Continue、原生 SDK/Release、桌面输入、人工体验、完整战役、原 19 故障与 61 阶段、发布资格均不由本片建立。
