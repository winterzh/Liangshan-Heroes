# 原 19 持久化故障迁移到 b22：设计与只读来源绑定

本目录是原 19 持久化故障的独立 synthetic 组件迁移。它不是 `daming_negative_v2` 的 capture 负例。当前已实现外部 `worker.gd` / `bootstrap.gd`、逐案映射、命名来源检查器，以及分工完成的 Python 实际故障宿主和 9/12 协议探针入口；尚未启动 Godot、取得新协议 proof 或通过原生 19 案。默认命令均只读，不能把代码存在当执行通过。

目标固定为 `.godot/campaign_progress_recovery_20261026/20261027_075456_3e4a48ab`，完整内容身份 `source-v1:b22f76f7bf4b8309f9257829364f4afdd6c9262282a25cb6aefacce5aa916132`。默认检查器只读元数据及清单内的脚本/小收据，不重算完整工程、资源或二进制，不把其结果当完整来源准入。实际执行宿主调用 `integration_3365/prepare_projectile.py:500 prepared_state`，核新 run 自身的完整来源、26 脚本 + 1 native 清单和自有冷导入；全 19 还要求同源、同 worker/helper 的新实际 9/12 协议 proof。

## 历史事实

权威原表是 `qa/zhu_wounded_20261005/proposals/campaign_persistence_observability_v27/FAULT_MATRIX_V27B.json`，SHA `83fb60c2569c02f09c74bf8318a09544bcfca1c0650add3c710a953b2ddc9320`。表内未执行字段属于设计时状态；旧实际运行的依据是 `qa/campaign_persistence_faults_20261008/actual_matrix_v4/receipt.json`，SHA `add421fb7b4655a9e70432ef3481a61a1b9e05742e260be1811639a76792ab66`。

V4 是 2026-10-08 的真实 ConfigFile/文件系统组件运行：19/19 案、全局 194 checks、无失败、PID 43016、exit 0、进程终态且共享锁释放。194 是原 report 的全局计数；各 case 的局部 checks 合计 177，不能冒充全局计数，也不能要求迁移后人为凑回 194。其安装的 Campaign 是 v27b `a5ad0a3197274c76c2b1fef8dbabc0371bbe36a480a38b722003bf9e94a9a482`。它不授予 b22、自然战斗、玩家 UI、重启恢复、奖励恰好一次或真实云上传资格。

## 为什么不能直接运行旧宿主

旧 `tools/run_campaign_persistence_fault_matrix.py:19–30,139–154` 固定旧 proposal，并复制根目录依赖到另一个小工程；改 `--baseline` 仍会安装旧 Campaign。其 24–30 行断点、267 行 `_write_config_receipt` 栈要求、137 行固定 userdir 都不能用于 b22。旧 worker `tools/campaign_persistence_fault_matrix.gd:97–126` 每案只删除 campaign.cfg 并复位旧内存字段；b22 有 CFG journal、唯一候选目录、持锁事务、Gate 和 Cloud pending，不能如此复位。

b22 `scripts/campaign.gd:170–188` 在非 QA 下拒绝旧普通进度入口，返回 `CAMPAIGN_COORDINATOR_REQUIRED`。旧 `_last_save_receipt`、`_write_config_receipt`、`_cfg_semantics` 不存在。`CAMPAIGN_QA=1` 只准许内存兼容路径，不能用于让正常持久化案通过。每次真实 CFG/LC/Coordinator 调用前须在非 physics frame；不能因增加一次 gate 等待后恰好处于 physics frame 而把 `CFG_PHYSICS_WRITE` 当故障成功。

## 逐案原意与新入口

`cases.json` 按原表顺序保留全部 19 ID、原 `expected` 原值和来源行号，逐案记录新入口、精确故障点、预期码及不可丢失的断言。全部采用显式 `b22_synthetic_component_v2` oracle，`current_protocol_mapped_unexecuted` 不表示通过，计划的 `passed` 均为 null。根任务已确认以下当前协议映射；不要求用户审批内部 oracle，也不再执行已被移除的旧返回字段断言：

1. 0/1/2 使用真实 LC3 gen1→gen2、fresh LC 对象及真实 `Coordinator.begin_recovery`，经过 CFG→真实 ACK2/uncredited handoff→Campaign._load。0/1 为两个真实进程共用同 profile，第二案核前报 SHA/原 CFG，并以新 token 再提交，不能用同 token already-applied 短路。2 用四个新 token 保留 A/BC/AC/A 单场序列。3 改为当前 Intent 的三种精确输入拒绝，核内存和命名业务 inventory 不变，不以统一 CoordinatorRequired 代替。
2. `Coordinator:160–162,203–204` 明确让恢复路径不授予现场 settlement。0/1 分别核纯 Projection 的新 seal 布尔值和真实 CFG 的 fullseal/unlock9；实际返回必须 settlement=false，不能伪造旧 `durable_new_story_seal` 字段。16 的旧 LocalCloudCounter 只作本案局部 callback 观测，由真实协调器 ACK 后触发，不能手工发布 Campaign 内存。17 使用真实 SteamCloud applying 分支，由宿主验证实际 mark_dirty 栈，再核 dirty/upload 未打开。
3. 原 18 案旧 worker:281 要求失败后 Campaign 内存已经替换。现采用 b22 `Campaign:325–327,340–350,384–396` 的实际原子边界：bool false、旧 Campaign 内存/CFG 字节保留，同 scope 的事务与 Cloud pending 保留。原 `old_expected` 原样留存用于说明差异，不声称其仍成立。`SteamCloud:410–415` 仍可能先更新 settings/language，单列前后观测；“Campaign 内存不变”不等于全部 profile 零变更。
4. 旧 result 的 a/b/c/d 不是当前合法 level8 goal ID。`Intent:8,17,54–69` 仍要求原六个 result 字段，且只接受三个实际 Daming ID。必须固定一一映射 a/b/c 到 infiltration/signal/response；最后较弱的 d 单项换成合法单项并明确记录，不得加入 `missed_ids` 等额外字段。最佳单场、不合并、同分不替换仍须原样验证。

## 真实文件故障的最小迁移

所有下列行号指目标 b22 的 `scripts/run_campaign_cfg_transaction.gd`。实际宿主须从固定脚本 SHA 和函数范围解析唯一语句，不以裸数字作为授权。`_stable_cfg:146` 同时用于 prior、candidate、installed、final；每次均须验证真实 Popen PID、nonce、case、脚本、函数栈、当前 transaction 和实际 `path`。命中同一行但路径/阶段不同不能算注入。

| 原案 | 实际注入点及路径 | 新精确结果；额外必须验证 |
|---|---|---|
| 6 坏原 CFG | 调用前私有 campaign.cfg 写 `[broken`；`begin_write:176→_stable_cfg:146` | `CFG_READBACK_LOAD`，native_error 非 OK；原坏 CFG 字节保留、Campaign 内存不变，未保存候选 |
| 7 先存在后消失 | prior `_stable_cfg:146` 之前，已完成 143 的原 SHA 检查，移动实际 campaign.cfg | `CFG_READBACK_LOAD`；没有重建缺失原件或提交候选；备份仅由宿主在证据后处理 |
| 8 真正新缺失 | prior SHA 为 ZERO，175 分支跳过 load | `CAMPAIGN_CFG_READBACK_VERIFIED`；真实新文件/候选/日志提交闭合。不可要求旧 `prior_load_error=ERR_FILE_NOT_FOUND`，此处根本不调用 load |
| 9 保存失败 | `retry_write:292 _frozen_cfg.save(candidate)` 前，288 的不存在检查已过后，对实际候选路径实施写拒绝 | `CFG_STAGE_WRITE` + native_error 非 OK + owned_pending；原 CFG 不变、无读回/ACK。给原 campaign.cfg 设只读已不覆盖这一故障；rename 失败也不等价 |
| 10 保存 OK 后 load 失败 | 保存/294 SHA 已完成，candidate `_stable_cfg:146` 前移走该候选 | 外层精确 `CFG_STAGE_READBACK`；真实 save OK，内层 load 非 OK、原 CFG 不变，事务保留 |
| 11 语义不符 | 保存后、`retry_write:294 _cfg_sha(candidate)` 前改合法候选 unlocked 9→7；当前真实 level8 Projection 需要 9，要求替换唯一、实际字节不同 | 外层 `CFG_STAGE_READBACK`；294/297 看到变更后同一 SHA，298 的语义 SHA 与 frozen 预期不等。若改在 294 后，仅证 SHA 拒绝，不算本案 |
| 12 读区间 SHA 改变 | candidate `_stable_cfg:146` 前持实际 Windows oplock，恢复 Godot 后等待真实 native opener 的 break，再追加等价注释、关闭句柄放行 load | 内层 `CFG_READBACK_CHANGED`、外层 `CFG_STAGE_READBACK`；证明 before SHA != after SHA、语义相同、真实 reader 在 oplock 内阻塞。普通两次定时写不能替代 opener 证据 |
| 18 Cloud 保存后失败 | 从实际 `_apply_profile` 进入 cloud 事务，对 candidate 阶段执行案 10 的真实移走 | 实际 bool false、精确 CFG 错误/retained scope，无持久化或上传声明；按当前边界核旧 Campaign 内存/CFG 保留，并显式保留旧预期差异 |

返回外层码不足以区分 10/11/12。宿主与 worker/report 必须合并保留各阶段真实路径、候选 closed SHA、actual save/load 证据、frozen semantics、before/after SHA；外层不能返回的内部值通过原生产断点 stack/debug variables 或已验证的独立文件观察证明，不能写测试 override 来合成。12 的 `observations.readback_semantics_equal_frozen` 来自实际候选 ConfigFile 与生产 `_frozen_cfg` 的 Values.semantics，而不是宿主声明。worker 的 `passed` 只计它实际运行的断言，宿主必须再验证完整机制 proof 才能授 case complete；其他拒绝、timeout、wrong phase、提前 Gate/owner 拒绝均为该案失败。

案 9 使用 save 前真实 CREATE_NEW/share0 的宿主哨兵，下一行原生产断点才关闭并移入宿主证据目录；保留 288 已检查不存在、实际 ConfigFile.save 返回非 OK/CFG_STAGE_WRITE/owned_pending 的证据，不能把外部哨兵误称生产候选。该机制与 12 的真实 native opener oplock 都必须先通过同源探针；目前尚无新 proof。

## 必保留的实现约束

- 默认只读。执行开关在完整 `prepared_state` 后获取共享 lane，再建立私有 profile/实际 Popen。每 profile 的 private_environment 只创建一次，后续进程复制环境；清除继承的 QA/Flow/测试控制变量。正常启动后核真实 profile 和 source identity。
- 建议每个独立 fault 使用新 profile；first/repeat 和 best-single-run 所需连续操作只在所属 case 链内保留。失败事务不靠清私有字段、删除生产 journal 或把 live owner 当 dead 来复位。记录 campaign.cfg、CFG journal/candidates、LC 与必要 Cloud 状态的完整受控 inventory；允许的锁/候选/日志变化必须逐案列明，不能混成“全部目录零变更”。
- 旧 `windows_owned_oplock.py` 与 `godot_debug_wire.py` 当前原字节仍匹配 V4 封存 SHA；可复用实际机制和旧协议证据，不能转授新 candidate 路径/阶段协议。长路径使用现有 `store_protocol_candidate/tests/io/run_io.py:88–118` 的 owned/fs_path 边界；原 oplock 内的 Win32 path 仍须扩展路径适配或用验证过的短 profile。
- gate 用该 io helper:180 `publish_ack` 的完整关闭后不可覆盖发布；不复用会读半 JSON 的写法。宿主只终止自有 Popen，只操作当前私有 profile 中逐项获准的真实路径；排 reparse/越界/覆盖现有 evidence。
- malformed-CFG 案仅接纳该案实际预期的精确 ConfigFile 原生错误。任何 SCRIPT/PARSE 错误都失败；不把允许列表扩成忽略所有 ERROR。若新启动链产生额外错误，保留证据并失败，而不是调整计数掩盖。
- CFG `Values.semantics:35–48` 是原 v27b 的 per-value ConfigFile 语义。13 案保留全部 legal Variant/unknown keys；14/15 案在 `commit_prepared:231–232` 拒绝对象、脚本容器、环和超深结构，编码前拒绝且原 alias 输入未改。这里不宣称 IEEE bit 完整世界等价。
- finally 各项独立捕获 cleanup error，保留原 traceback，先确认实际 child terminal，再释放所持 lock，并总能保存 receipt。不能照搬旧宿主:319–326 一处 cleanup 抛错就跳过后续收尾的顺序。
- 新 native 报告保留 19 ID 和 old→new oracle 版本，计实际检查数。原 194、旧 component PASS、b22 冷导入、自然 Flow、奖励交接和 public/SDK/61 项分别报告，互不继承。

## 外部 worker / 宿主协议

每案一个独立 Popen；0/1 共用同一 profile，其余独立。环境为 `P19_CASE/INDEX/PROFILE/OUTPUT/BATCH_NONCE/PROCESS_NONCE/WORKERS/WORKER_SHA256/PLAN_SHA256/CONTENT/ENGINE`，1 另带 `P19_PREVIOUS/PREVIOUS_SHA`。宿主把两 GD 和 cases.json 冻结到 workers/；bootstrap 同时核 worker 和映射 SHA。case 4/5 仅在自己的测试调用期间开启 CAMPAIGN_QA，随后还原；其余正常入口均为空。

每案仅一份 `gate_request.json`，schema `persistence19_gate_v1`，精确 14 字段：schema/pid/index/id/batch_nonce/process_nonce/profile/userdata/output/fault/cfg_path/cfg_source_sha256/phase/cfg_expected_unlock。phase 固定 `before_operation`；6 已先真实写入 `[broken`，原 SHA 为此闭合坏文件的实际值；缺失用空串。ACK 精确六字段 schema=`persistence19_gate_ack_v1`、pid/index/id/batch_nonce/process_nonce，数值严格有限整数。完整 ACK 后等待普通 0.25s timer 消费 debugger 命令，再退出 physics frame；同步生产链中不插 await 或 override。

最终 `report.json` schema=`persistence19_component_v2`，包括实际 pid/case/index/nonces/profile/identity、原 old_expected、oracle_version、checks/failures/result/observations。结果对象来自实际生产方法；Cloud bool 与保留的实际 CFG 错误分开记录。所有宽资格明确 false。业务 inventory 只含 CFG、CFG journal/candidates、continue、settings/language 的元数据和 SHA，不称整个 profile 零变更。

## 当前使用（未执行原生）

```powershell
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/persistence19/plan_persistence19.py
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/persistence19/plan_persistence19.py --case readback_SHA_changed
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/persistence19/run_persistence19.py
python -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/persistence19/prove_fault_protocol.py
```

以上默认只读。plan 检查器没有执行开关；proof 宿主仅显式 `--prove` 执行新 9/12 两案，全矩阵仅显式 `--run --protocol-receipt <同源成功proof>` 执行。`--full-preflight` 是单独昂贵完整只读准入，不由默认触发。本轮没有执行这些原生开关。`sources.json` 固定当前命名文件和历史 proof 字节，`cases.json.old_expected` 必须数据完全等于原权威表。静态/默认成功仅说明命名绑定和计划表一致，不授新协议、19 案或游戏验收资格。
