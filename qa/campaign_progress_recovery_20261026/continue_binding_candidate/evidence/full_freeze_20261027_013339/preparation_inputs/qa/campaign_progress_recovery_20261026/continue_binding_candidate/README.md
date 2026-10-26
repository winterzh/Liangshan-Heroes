# 继续入口与 credited sidejournal 绑定候选

仅从 e97a 冻结工程 `20261027_000821_ba1f231b` 复制三个脚本并作语义补丁。原 20/23 文件候选、生产、当前 I/O 和冻结工程均未改变。来源、字节 SHA 与精确差异见 `source_manifest.json`、`candidate.diff`；旧控制流证据见 `static_findings.json`。**尚未编译或运行，不继承 e97a 的任何通过资格。**

修正范围：

1. Flow 不再在 Session 前执行一个遇死锁就返回的 `read_slot(false)`。它显式传递 `require_classic`；公开入口仍只允许 classic 30，内部默认参数不变。
2. Session 对残留槽先调用原 `inspect_recovery()`，从其绑定的已提交 head 或完整 `receipt.pending` 通过原模型验证器读取候选。检查公开范围、安装 content/engine、当前 Steam account，战役还检查 `Campaign.cloud_owner`；代数、previous、file SHA 与原 plan/inventory 精确对应后，才调用原 `recover(plan)`。原恢复者仍负责 fresh owner/CAS 检查，返回的代数、SHA、完整文档必须等于已授权候选。正常 clean 槽也做相同范围检查，后续 mount 的整包 CAS 保留。
3. LC 新增 `prepare_credited_resume(token, owner)`。它读取严格 gen1 active sidejournal，用**该本地记录自身的 SHA**安装内部三字段 local binding；Steam 槽的六字段 binding、token、account、credited kills 和 Steam ledger SHA 完全不改。Session 准备及 mount 两次调用，首次 marker 的存在状态与 SHA 必须一致。gen2/gen3、scope 不符、marker 新出现/消失/变化均拒绝，不获得奖励或终局许可。
4. 连环马真实 Flow 恢复的 runtime 漏掉章级覆盖：Flow 原仅 base→content_pack→visual，钩镰手恢复后排队人口按 base 的 1 计算，正常开局为 2。Session 仅对已严格验证的 `Profiles.LIAN_CONTEXT` 调固定 `run_level4_world_factory.gd.prepare_runtime(_trusted)`，成功后释放尚未准备的 Core，以正常 base→content_pack→Level4 overrides→visual 的受信字典重建，再恢复原 world。队列、存档数值、训练费用/时长、测试阈值完全不改；不从槽载入脚本路径。此补丁须重跑真实 Flow，以下 LC 磁盘模型不能授训练恢复资格。

边界：

- 首次保存尚无任何 packet 的死锁，仅在 `revision=0/ZERO` 且 inventory 恰为 `writing/` 与 `writing/owner.json` 时，允许原 Store 确认死进程并回收，读回仍必须是空 head，然后返回 `NO_SLOT`；不会留下永久阻挡后续保存的空锁。
- Steam 账号、安装身份或公开玩法范围不符的已验证候选，在业务 claim 前拒绝。uncredited 官方战役的本地 owner 校验仍由后续 LC.prepare_resume 完成，不宣称该 owner 错配在主槽恢复前零变化。检查死亡可能生成独立 helper 证据文件，不计作业务 journal 变化。半 pending、未知 layout、alive/unknown/timeout 保持原字节拒绝。本片不承诺后续完整世界验证失败或任意后置 I/O/CAS 失败都全盘零变化，也不宣称外部 Steam 账号切换具跨进程原子性。
- legacy credited 槽确实没有 sidejournal 时，恢复仍只读、不创建目录、不生成本地记录；mount 仍须不存在。安装后的原保存/终局流程才按原 token 创建 gen1。已存在的空目录不是有效 gen1，明确拒绝；不会用空目录伪造历史绑定。
- 本地 marker 中的 `kind="uncredited"` 是既有 LC 内部句柄格式，不更改 Steam 槽或 credited 奖励来源。原 Steam ledger 恢复、账号校验与终局 handoff/ACK 校验继续执行。此补丁不修改 Outbox、错误 UI、奖励算法、schema 或黄泥冈 contract。

静态来源检查（不启动引擎）：

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/check_sources.py
```

`tests/binding_disk.gd` 是待运行的独立磁盘模型工具：使用正常 `Lifecycle.begin` 生成隔离 gen1，冷对象先展示旧 `LOCAL_TOKEN_EXISTS`，再测试候选只读绑定、重复 binding、token/account/context/content/engine 拒绝、absence→present 竞争、空目录拒绝，以及 gen2/gen3 拒绝。gen2 由正常 LC terminal API 写入，输入 credit/胜败明确是合成模型数据；gen3 是直接 Store 事务写入的严格合成数据夹具，**不是 `ack_progress`、Steam proof、真实结算或自然战斗验收**。工具不调用 Coordinator、Steam 写入、奖励或指标函数。

`prepare_continue.py` 默认仅检查原 e97a 的完整 generation、原 23 文件 manifest、三项 overlay 和固定 helper 的源码/构建收据/实际 EXE。只有 `--prepare` 新建独立冻结：完整 canonical 文件从 e97a 复制，仅覆盖三项；再次核对全部文件、目录和原来源前后 SHA，单独写新 manifest/准备收据。它不启动引擎，也不继承旧导入或测试资格。新工程随后使用既有 `run_batch.py import` 完成单独导入。

`tests/run_disk.py` 默认只读 preflight；必须明确 `--expect baseline|fixed`。baseline 只接受原 e97a，fixed 只接受新组成的精确 23 文件冻结及其成功导入收据。只有 `--execute` 才使用原共享引擎锁、Popen/退出码/日志、独立 profile/nonce/实际 PID、全生成身份及前后逐文件 pins。原失败收据保留，锁只由原 owner 释放。三项旧行为断言归入 `baseline_reproduction`，不计入 `fixed_regression`；两类实际执行数量分开写入收据。fixed 磁盘模型通过也不授 Flow/主槽故障恢复/SDK/自然终局资格。

以下是根线程后续调度命令，本轮只运行不带 `--prepare` / `--execute` 的预检：

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/prepare_continue.py
# 另建冻结，仍不启动引擎；输出路径记为 <NEW_RUN>
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/prepare_continue.py --prepare
# 根线程取得引擎 lane 后单独导入
C:\Python314\python.exe -B qa/huangnigang_production_20261020/run_batch.py import --run <NEW_RUN> --wait-lane 1800
# baseline 与 fixed 各自独立新 profile；先预检，调度时才追加 --execute
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/run_disk.py --base-run .godot/campaign_progress_recovery_20261026/20261027_000821_ba1f231b --expect baseline
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/continue_binding_candidate/tests/run_disk.py --base-run <NEW_RUN> --expect fixed
```

外部 bootstrap 用 `can_instantiate()` 快退编译失败。环境为 `CB_WORKERS`、`CB_WORKER_SHA256`、`CB_PROFILE`（四个 APPDATA/LOCALAPPDATA/TEMP/TMP 子目录）、`CB_OUTPUT`、`CB_NONCE`（32 hex）、`CB_EXPECT`，并要求 `STEAM_DISABLED=1`、`CAMPAIGN_QA` 为空。模型目录固定为 `user://continue_binding_probe/<nonce>`。

仍需原生回归（不由上述模型代替）：

| 场景 | 必需证据 |
|---|---|
| 公开 classic 死 writer 的完整 pending、已提交未释放槽 | 真实拥有者终止；公开入口完成恢复及继续；原 token、head SHA、世界和费用保持 |
| 同样残留中的非 classic、错 account/content/engine | 真实 Schema/Codec 夹具；业务完整 inventory/bytes 前后相同；不创建 Core/claim |
| rev0 + 原始 owner-only 死锁 | 回收后明确 `NO_SLOT`；之后正常新局保存可成功；半 pending/未知额外文件拒绝且保留 |
| 候选预检到 claim 之间原 owner/raw/head/inventory 变化 | 原 recover fresh CAS 拒绝；不重新选新 head、不重算提案 |
| credited gen1 恢复→再次保存→自然终局 | 真正 Steam 资格另验；同 Steam token/account/ledger binding，本地 gen1 SHA 使用正确；gen2→CFG→ledger→gen3 一次性 |
| 连环马菜单继续→恢复付费训练 | 原正常人口预留 2、36金24木20秒、原队列ID/余额均守恒；训练自然完成且21秒不重复；必须复跑原 Flow driver，旧135项直调Factory的训练专项不替代 |
| legacy 无 marker、gen1/absence 变化、终局槽 | 只读恢复不造记录；mount 拒绝变化；gen2/gen3 不恢复战斗、不补发奖励 |

本轮源码可审阅，实际磁盘模型、公开 UI、故障恢复、credited 自然终局和 SDK 均待根线程另冻串行验证。
