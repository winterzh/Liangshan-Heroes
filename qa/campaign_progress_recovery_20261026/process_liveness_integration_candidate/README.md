# 同步恢复准入候选

本切片修改 4 个 GD，并附独立测试宿主和来源证据。2026-10-27 最小组件批 `000715_3a07df82` 已正常导入/运行退出 0：**22 项严格模型、60 项组件检查、7 次真实 helper 查询通过**，全部来源/helper/engine/生成文件前后 pin 不变，自有子进程终态、共享锁释放。[完整收据](evidence/000715_component_pass/receipt.json)、[报告](evidence/000715_component_pass/report.json)。未采用到生产、未改既有 20 文件 manifest 或 f6ef；没有运行完整游戏路线。

本批只授予组件范围：4 文件及真实依赖可编译，v2 模型、真实父链 junction 拒绝、manager alive/dead/unknown、分 scope/phase 缓存、实际预算到期、当前场景替换后对象保持、空 Store 正常读取零 helper，以及正常退出。**真实残留锁的 inspect/recover、活 writer/claimant 业务文件零变更、v2 timeout kill/quarantine 尚未在本批运行**。组件 v1 的旧通过资格没有直接转授。

独立回读已核对 37 个运行 pin、报告 SHA/PID/nonce、7 份原始 helper 结果和前后目标创建时间。场景检查限定于真实 Node 的 current_scene A→B 替换，不是完整游戏场景路线；没有单独验证 post-root 读取 shutdown tombstone 或 quarantine 状态下的退出。

| 文件 | 本切片变更 |
| --- | --- |
| `run_snapshot_store.gd` | 仅恢复 inspect/recover 增加同步 scope、三态准入、claim 前新查询及 raw/head/inventory 重读；正常 open/acquire/commit/release 不启动查询。 |
| `steam_receipt_store.gd` | 在唯一 cleanup/marker 恢复检查原 writer 与最近 claimant，全部确认 dead 才能 rename；原内存 token 的 owned retry 保留，无外部 head 重基。 |
| `run_process_liveness_manager.gd` | SceneTree 根视口 metadata 强持有唯一 manager 和 oracle，跨 current_scene 存活，并在脚本 VM 结束前正常释放。 |
| `process_liveness_oracle.gd` | 从 v1 精确底本改出 v2：外部共享 deadline、显式 cancel、全部父链 reparse 检查；模型/路径/已到期预算已实测，v2 cancel 终止分支仍待另验。 |

来源、原 SHA、目标 SHA 和 helper pin 见 [source_manifest.json](source_manifest.json)（SHA `0149f7a5b41fdfc04362bcf8e6823ed000092b28538ef08c646056b3923d34ac`）。该清单在运行前冻结，内含 native_run=false 等创建时状态保持原字节，后续结果以独立收据为准；它不是完整集成 manifest。

## 完整候选与活写者专项

后继已将旧20文件与这4文件合为23脚本，并复制固定helper到独立冻结`20261027_000821_ba1f231b`。导入exit0/错误0，实际内容身份`source-v1:e97a07b9ff04b677fbc1934a40976cc6e1f82479855cf39f305147ae4f6d1eea`；完整manifest SHA `f4b83220e4990d2823bc2c5393c6383ebec33b06dc6aa9ccd7186ebdccbd1e0d`。helper参与完整source identity，exe仍只留本机忽略产物。[来源与导入原件](evidence/full_freeze_20261027_000821/README.md)。

该新源的双进程批`20261027_001429_a52fb5dc`共45项通过（A24/B21），双exit0、来源后验通过、共享锁释放。A停在真实acquire断点且由宿主持有HANDLE证明存活；B普通Ledger.open明确返回WRITER_ALIVE，可重试且未标unsafe/restart，业务目录和每个文件原字节不变。A原提案随后正常提交，B保留原Ledger/Store重开并得到同一九字段proof；重复handoff不重复计奖或改写文件。[独立活写者收据](../evidence/live_owner_fixed_20261027_001429/README.md)。

这只授予上述时序的活写者保护，不等于活claimant、全部死亡恢复/真实文件故障、v2超时隔离、上层继续流程或游戏通关通过。旧f6ef误清理基线与所有失败记录继续保留，未采用生产。

## 本次实际发现并修复

Engine metadata 持有脚本 RefCounted 会晚于 GDScript VM 释放。独立最小 [3 例对照](evidence/000206_metadata_lifetime_reproducer/receipt.json)确认：Engine 持原生 RefCounted 退出 0；Engine 持脚本 RefCounted 退出 `3221225477`；根视口持脚本 RefCounted 退出 0，均无脚本错误。这是独立诊断，不是接受预期崩溃作为组件通过。

manager 因此改为根视口持有，新增仅含 primitive 的 Engine 根身份/退出墓碑；worker 没有手动移除 manager 来制造安全退出。[最小修复 diff](evidence/manager_lifetime_fix.diff)。正常导入后重新运行，真实 A→B current_scene 替换保留同一 manager 和已初始化 oracle，最终正常退出。

所有原失败保持：[完整批次索引](evidence/component_runs.json)。`235735` 缺正常 editor 全局类扫描并发生退出崩溃；`235924` 是宿主重复初始化同 profile 失败；`235952` 导入正确但仍退出崩溃；`000537` 修复后已退出 0，但释放 PID 在宿主前后从保留内核对象变为真正缺 PID，严格身份核对拒绝。最终宿主只在有界等待确认错误 87 后建立“absent”测试条件，未放宽前后身份或 helper SHA。

## 同步调用与所有权

保留 Store 现有同步 `inspect_recovery()` / `recover(plan)` API。每次最外层调用建立一个 scope，嵌套的 Steam→base、recover→fresh inspect 复用同一 deadline；总查询/准入预算最多 3 秒，不能每次 nested fresh 重置。独立的外部 inspect 和后续外部 recover 是两次操作，各有自己的预算和 fresh 查询。等待只调用本次自有 helper 的 poll 和最多 5 毫秒 `OS.delay_msec`，不 await、不 pump SceneTree、事件或 Steam callback。Windows 文件/进程创建调用和既有提交 I/O 不是硬实时 API，3 秒不构成整个恢复事务完成耗时的硬保证。

manager 固定存于 SceneTree 的根视口 metadata `_lh_process_liveness_manager_v2`，不是 current_scene。每次访问核对确切 Script、schema、进程 PID、根/SceneTree 实例身份和固定配置；已有不匹配对象拒绝且不覆盖。只接受主线程，无有效 SceneTree/root 时 unknown 且不启动 helper。Engine 只保留 primitive 根 ID 和 shutdown tombstone；原根锚点丢失时不创建新实例绕过 quarantine。Store 临时对象关闭时只移除本次 scope，不能销毁 manager/oracle 或清除 quarantine。

真正根视口 `tree_exiting` 时仅写 primitive shutdown tombstone，晚到的 _instance/query 全部拒绝；根节点析构在 GDScript VM 仍有效时释放 manager，不做第二次 raw-PID kill，也不清除运行期 quarantine。同步 manager 不 pump 场景，因此正常退出不与其正在执行的查询并行；若异常退出时仍记录 pending/quarantine，只保留 primitive 诊断并交进程终止边界，不宣称额外终止已确认。普通 current_scene 退出不触发该 hook。

本轮完成结果按 `{phase, snapshot_binding_sha, pid}` 在 scope 内保留、非消费；phase 只允许 `inspect` 与 `claim`，两阶段不共享结果。下次外部重试使用新 scope，不永久缓存 alive/dead/unknown。恢复 plan 保持原稳定字段，不添加 nonce/helper PID/观测时间。查询证据只留 manager 返回详情中，snapshot binding 包含 directory/owner/raw/source/inventory/head。

超时尝试取消自有 helper 一次；若不能确认子进程终态，则保留 oracle 与 quarantine，后续任何 Store/new scope 都不能再查询/新建 helper。没有可靠句柄重新建立与清理确认前只能要求重启；不以 raw PID 重试 kill。建立一个无查询 scope 不会绕过 quarantine；原内存所有权充分的 owned cleanup/release 仍可继续，其路径本就不需要死亡查询。

## 所有查询先闭合，再改变业务文件

基础恢复先验证原 plan，再做 claim-phase 新死亡查询，随后重读 owner 原始字节及 SHA、完整 inventory 和 head；预算仍有效才创建 `recovering`。旧代码在 mkdir 后查询 PID 的位置已移除，避免 unknown 留下本轮 claim。mkdir 后仍保持原 inventory CAS、转存/prune/readback 与失败保留流程。

unique 恢复在 inspect 和 claim 两阶段都要求原 writer 与最新 claimant confirmed-dead（同 PID 同 binding 可复用本阶段同一次结果），之后再次核对完整 source/raw/layout/head；所有查询已结束才改名到本次唯一 claim。遇 alive、unknown、查询超时或准入错误，不改变 **业务 Store**；独立 provider 证据目录可能已写入。已认领后的原有 I/O/CAS 失败仍保留其所有权和失败现场，不能宣称所有任意错误均全盘零变更。

仅 query 在 main thread、单 scope 内完成；不把 Store metadata 的 PID 假装为 Godot 自有子进程。唯一协议的 owned 路径仍要求原对象内存 `_protocol_owned`、原 token/raw 和本进程 PID，不从磁盘同 PID 推导 owned。

## 固定 helper 与目录

本草稿固定 `res://addons/process_liveness/windows/ProcessLivenessProbe.exe`，SHA `012354b1cf0376712f97e19362d91b2ef7f51775c6797c862c513df1e2f1936c`，对应组件 v1 的已构建 8,192 字节助手。另冻时由 root 从已 pin 忽略产物复制到私有工程该路径；当前内容 identity 已遍历 addons，实际 exe 必须参与新 source identity 和 manifest。二进制不得混进当前 Git 白名单，公开导出/签名/.NET 依赖另验。

私有查询根固定为 `user://process_liveness/v2`。manager 在创建这两个固定子目录前、oracle 配置前、启动前和读取最终报告前检查从驱动器根到目标的完整父链；拒绝 reparse/junction、缺失父级、UNC/设备/不规范路径和变动 SHA。Godot 4.6.3 `DirAccessWindows::is_link` 官方实现检查整个 `FILE_ATTRIBUTE_REPARSE_POINT` 位，[源码摘录](evidence/path_api.json)。这些检查不构成针对同用户恶意并发替换的 handle-relative 路径协议。非 Windows、不支持路径或缺 helper 都 unknown，保留业务锁。

## 错误和仍待上层处理的边界

查询未确定/短暂配置不可用/活 writer：`retryable=true, unsafe=false, restart_required=false`；quarantine 或 manager 身份不符：`retryable=false, unsafe=false, restart_required=true`。unsafe=false 表示未证明业务数据不安全，不表示查询可绕过。成功计划不包含这些临时字段。

当前 Ledger `retry_open` 原样返回 inspect/recover 字典并保留 `_open_scope`；`_retain_failure` 也尊重显式 retryable/unsafe/restart。Slot、Lifecycle、CFG 的这些读取路径直接返回错误，没有在本补丁里伪造 `pending_save`。

仍需上层验收/处理：

- `continue_flow.gd:191/217`、startup Reader 及 Session 早期失败仍可能丢弃临时 Store；manager 能保留 helper，但用户界面是否正确展示可重试/必须重启尚未验证。Flow `_fail` 的落盘诊断目前只保存 code，Session 非 pending_save 会被 dispose。
- `campaign.gd:335` 在 writer 非 busy 时释放 CFG writer；startup Flow 局部 CFG 的早期失败也可能丢对象。manager 消除了子进程所有权丢失，不等于提供了完整上层事务重试。
- `steam_persistent_outbox.gd:39–50` 初始化失败后 `_store` 已非空，没有 retry_open；同对象重调 open 会 ALREADY_OPEN。本轮只做共享恢复准入，不修它的重新打开/发布确认资格。
- `run_world_session.gd` 在部分 scene 复核路径把读取错误转为 `SLOT_CHANGED`；没有把新增 liveness flags 自动贯穿所有 UI。本轮不宣称完整全链集成。

保持既有半 pending、无 owner 的旧空 writing/recovering 等拒绝边界；不实现它们的恢复协议，不处理 MAX_RUNS 退休或双 Ledger release 后 readback 并发问题。

## 可重复入口与下一验收

```powershell
python -B qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/run_component.py
python -B qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/run_component.py --execute
```

默认只 preflight，显式执行才获取共享锁且占用引擎；有其它引擎/锁立即拒绝，不排队。宿主先复制 4 文件、3 个真实 Receipt 依赖、helper、原 manifest 与模型/worker，正常 editor import 后才运行最小工程；编译错误、日志错误、非零退出、fixture 身份变化或任意 pin 变化都会失败。原生进程和 junction 是实际 OS 对象，scope 标签及空 Store owner 是明确合成测试数据，不是 SDK/account 资格。

完整候选入口：`python -B qa/campaign_progress_recovery_20261026/prepare_liveness.py`默认只读，显式`--prepare`才创建新冻结，不启动引擎。随后使用既有`run_batch.py import --run <新冻结>`正常导入，再用`live_owner_candidate_tests/run_live_owner.py --base-run <同一冻结> --execute --expect fixed`执行专项。不能在旧冻结中覆盖源码或helper后沿用身份。

接下来在新源上复验死亡恢复、真实文件故障及延迟写入，并补活claimant、unknown、缺helper/错SHA、真实timeout+Store释放+新Store、两PID与重复fresh共享预算、源raw/head/inventory在查询期间变化、owned retry及正常提交/释放零helper。拒绝前后逐文件内容和目录核对，查询辅助文件与业务journal单独计数。之后串行验证CFG/LC/slot/outbox继承路径及继续流程，不授予旧冻结或新游戏路线通过资格。
