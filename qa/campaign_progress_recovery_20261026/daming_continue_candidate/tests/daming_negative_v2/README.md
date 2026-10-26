# Daming 新 52 负例：夹具准入与入口草案

当前只实现新夹具准入、精确旧用例表提取、52 进程规划及原生 admission worker 源码。没有实现 world/component/capture 的完整新执行宿主或运行循环；没有编译、运行 Godot，也不授 52/61、19 故障、玩家入口或发布资格。目录与运行中的 `tests/daming_flow/` 完全分开，未修改其任何输入。

## 数量与本次实际交付

| 类别 | 每角色 | 两角色进程数 | 严格保留的范围 |
|---|---:|---:|---|
| world | 132 specs × source/json = 264 rows，1 进程 | 2 | 原 `_add`、`_build_specs` 与三份常量原文；完整 Core.prepare 拒绝层和未分配观察必须保留 |
| component | 181 specs × source/json = 362 rows，1 进程 | 2 | 原 `_add`、`_build_specs` 原文；独立 UnitState/Contract/Pair 调用，不能用 Core.prepare 替代 |
| capture | 24 cases，各 1 个独立进程/profile | 48 | 原 24 个名称与精确码，19 个安全状态负例及 5 个 cast 负例；offscreen GL |
| 合计 | 26 进程 | **52** | 不是把检查数组长度当阶段数 |

`case_catalog.gd` 只把原表放入两个独立 RefCounted 类，并保留原 `CAPTURE_CASES`。`plan_negative.py` 从 pinned 历史原文件重新提取、增加同一层缩进后逐字比对生成文件；不是手写一张相似的替代表。GDScript 运行时还会核 132/181/24 及重复 ID。当前这些 native 核对尚未执行。

原 world/component 的每角色最终 row 数为 264/362；两角色共 528/724 个 model rows，另有 48 个 capture 进程。不能把这些模型 rows 宣称为额外原生流程或原 19 故障。

## 新夹具合同

规划器只接受当次 `.godot/daming_flow_20261027/<batch>/receipt.json` 的整体终态成功收据。必须八个独立实际 PID、clean exit0、完整源身份后验、锁释放；角色的 `closed_a_fixture` 引用必须落在该 run 的 `closed_a/<role>/descriptor.json`。正在运行的批次或只有 A 成功，不能生成本 52 阶段执行资格。

descriptor 必须是 `daming_flow_closed_a_fixture_v1`、`actual_host_validated_closed_a`。重新核其完整冻结库存、两原始记录 SHA、原 A 报告/日志/PID/步骤/三个 nonce、同 source/engine/manifest/token。只读冻结副本和报告；不重新读会被 B/C 正常推进的原 profile。沿用当前 hook 的长路径及 reparse 守卫，不加入旧 V16 schema、旧 handoff 或伪造 packet/world 文件。

新 request schema 为 `daming_negative_admission_request_v2`。外部 `fixture_reader.gd` 必须实际调用当前 `Slot._decode` 解码原 slot，取得原 packet/world，再通过生产 Codec 解码 Level/Mission；实际 `Lifecycle._decode` 严格核 LC v3 active gen1、空 Intent/ACK、同 token/context/owner/content/engine。不得把 JSON 原始数字深比较当 typed 一致；目录字节数/PID/gen 使用显式整数范围等值，具体世界字段仍由实际 Slot/Codec/后续原组件负责。

来源 C 报告另 pin，并由当前 LC 验证器只读校验同 token 的 LC3/Intent2/ACK2 gen3；这绑定正向八流程的当前协议，不在负例进程重做终局，也不在 A 夹具里补写 Intent 或 ACK。2026-10-27 编写本草案时，只读 A 真实元数据已见 Lu PID43448、202 checks、2 files/6 dirs；当时该批八流程仍运行，此观察不是整体成功或本目录 native 资格。

未来每个执行进程必须先调用 `integration_941.prepare_daming.prepared_state(base_run)` 完整核 **当前** 25 脚本、helper、generation、独立 import 和 engine；取 `state.run_base/project`，不可误取 941c 祖先 `state.base`。本规划器默认只查小来源，`full_source_verified=false`；不能据 request 或旧 receipt metadata 代替当次完整前后身份核验。若后继统一源增加 overlay，必须显式新增该来源 preparer 的严格绑定，不能放宽当前分支或转授 3365 结果。

## 当前可审入口

```powershell
# 仅命名小文件/精确表/52项计划；无 profile、引擎、共享锁或全项目 hash
python qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/plan_negative.py
python qa/campaign_progress_recovery_20261026/daming_continue_candidate/tests/daming_negative_v2/plan_negative.py --help

# 仅在真实八流程终态后，读取夹具并可选写新 request；仍不启动引擎
python .../plan_negative.py --flow-receipt <原run/receipt.json> --role lu --request-output <已存在输出目录/request.json>
```

`bootstrap.gd` 是未来受控宿主的 `--script` 入口，只加载当前四份 admission GD，不继承缺失的 `res://tools/daming_campaign_durable_cross_process_v1.gd`。request 内绑定四 worker SHA。其 ENV 合同为：

- `DN_WORKERS`：四 GD 的受控冻结副本；`DN_REQUEST`、`DN_REQUEST_SHA256`：精确新 request。
- `DN_PROFILE`：全新四根 profile；APPDATA/LOCALAPPDATA/TEMP/TMP 分别为其对应小写子目录；`STEAM_DISABLED=1`，`CAMPAIGN_QA` 为空。
- `DN_BATCH_NONCE`、`DN_PROCESS_NONCE`：等于 request 的独立 consumer nonces，不能复用 A 的 nonce。
- `DN_OUTPUT`、`DN_REPORT=DN_OUTPUT/report.json`：新报告路径，拒已有文件。

`admission_worker.gd` 等真实 startup ready 与普通非 physics 帧，核 1×/60Hz，然后解码原件、取表并报告。它不构造 Battle、不调用 Core.prepare/capture、不写业务槽，不把 packet/world 全量塞进报告；即使 admission passed，`negative_matrix_passed=false`、`executed_negative_rows=0`。宿主仍需完整 source/engine/pins、共享锁、原生 clean log/exit、独立 PID/nonce/所有权及结束后完整输入库存核验。本次没有实现或运行该原生宿主。

## 后续最小适配顺序与不得删的断言

1. **先独立原生加载/admission。** 根线程持 lane，完整 prepared_state 后在新 profile 验证两个实际 A；按 report 的实际 checks 计数。失败保留，不能因为旧表曾过就跳过新 schema 或类型错误。
2. **world 两进程。** 仅替换旧 worker 的 entry/fixture loading/report provenance，其 `_read_route`、`_positive`、`_mutate`、`_negative` 和 type/IEEE 比较原样移植。保留 JSON Int 特例实际 `Store._decode → NONCANONICAL_RECORD`，不得把未到 Core 的拒绝计为 Core pair 覆盖；保留 dispose 前零分配、输入与缓存网格不变。
3. **component 两进程。** 原八 positive 和 362 rows/role 保留；完整 UnitState、独立 Contract values/parts/membership、Pair 六种模块不得合并。两读取边界、完整 typed/IEEE 输入指纹、节点数、Core 零状态、pre-dispose 观察与所有业务文件/空目录前后不变都保留。禁止为过测删除原 Unit 模型字段。
4. **capture 48 进程。** 每 case/role 从 A 原两份字节克隆到新 profile，offscreen GL；不把旧 handoff 写成新 A 出产物。沿原 Session.prepare_restore/stage_mount/commit_restore_async 与 HELD 骨架做下层 capture QA，明确它不是玩家 Continue 按钮 Flow。真实 Flow 正向资格来自独立八流程。

capture 的首个适配阻断是旧父 `_compare_complete_world` 要求 `_last_group_time/_press_ms/_last_tap_ms` 全为零。新 A 来自真实输入，必须读取其原 typed checkpoint，并按当前生产恢复时钟 rebase/clear 合同精确断言；不能清空字段或编辑夹具。旧 `source_timing.source_stage_age` 可由原 Mission Codec 的 `values.stage_age_ms` 得到新字段，须标“从原记录原生派生”，不能伪造旧 handoff。

capture 的 24 处注入是有意的 QA 负例，不是正常玩法：保持同一同步栈单字段注入、精确拒绝码、原对象/类型/float bits 恢复、全 Core recapture；中途不得 await/tick/造节点/改 identity。完整世界仅允许真实时间边界覆盖的 mission.stage_age_ms/root.clocks.msec，其余逐字段严格相等。五 cast 必须组件自身 capture 接受、最终 Core 在 level8_safe_pair 拒绝并指明对应 array。itemcast 必须使用原已发出 UID，不能补造 next_item_uid。HELD 信号在发射前核真实注册，发射后不误要求 ONE_SHOT 还连接；清理只断开本 observer。

此轮尚未把这些循环移植成可执行 world/component/capture workers。它们是下一次明确代码片，不能把本目录 admission 入口描述成完整 52 runner。

## 冷导入和 61/19 的独立门槛

61 仍为 **1 cold import + 8 正向 Flow + 52 负例**，必须同一最终统一源。当前 3365 的 import 复制了 cache seed，因此不是 61 的 cold 阶段。

后续另建完整 fresh freeze，copy source 与已固定 native assets，**不复制旧 imported/editor/shader/cache/class-cache**；导入前保留完整源码/native 身份与不存在旧缓存的库存，明确 cache copy count=0。如安装器确需产生 `.godot/extension_list.cfg`，只允许已声明、独立 SHA 的注册文件，不能拿它混充旧导入缓存或笼统要求 `.godot` 完全空。随后真实 editor import 与 clean exit/log/独立 generation/全身份后验，才计 cold。不能把旧 61、旧 v25/v34 或本次 seeded import 转授此门槛。

原 19 持久化故障另属 `tools/run_campaign_persistence_fault_matrix.py` 与其 actual_matrix_v4 历史边界，和本 capture 的 19 状态负例没有数量上的替代关系。本目录不执行、取消或新设原 19 的验收条件。
