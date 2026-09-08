# Steam 持久待发送队列：2026-09-08

最终受测批次为 `20260908T103224Z_8a64b1dc/receipt.json`：**221 项原生断言通过，40 个进程均已退出，18 个外部 PID 强杀检查点通过，13 条 fake SDK 调用逐条独立核对。** 引擎为 Godot 4.6.3，完整 SHA-256 见收据。工作版本基于 `21d70bcf85f6cd7c8601dec110a84c54f01f59ba` 加本批未提交源码；实际 12 个输入文件的 SHA-256 见 `freeze.json`，不把基线提交等同于包含本批修改的提交。

**这只验收内部队列组件。生产确认 provider 仍返回 `WRITE_CONFIRMATION_UNPROVEN`，`production_confirmation_blocked=true`，`real_sdk=false`。** 没有调用真实 Steam 写 API，没有确认真实 Steam 服务端批次，没有接通玩家续玩入口，也不代表经典 30 波或八关端到端验收完成。

## 本批修复与验证

- 确认 proof 的 `version/app/generation` 先验证为精确非负整数，再规范化为 int；原生 JSON 重新读取后可验证同一 proof，重复 proof 不会变成冲突确认；小数仍拒绝。
- 磁盘 document 仅接受 `confirmed* → uncertain? → queued*`，累计统计和已解锁成就在相邻 intent 间只能保持或上升。入队发现服务器校正后的较低目标会保留旧 intent 并持久阻断，不能静默覆盖。
- 私有 profile 不匹配时，在创建 fixture 目录、ledger、queue、transaction plan 和报告之前退出 2。单独负例验证 `outbox_qa` 与报告均未写入；引擎自身日志不计为 fixture 写入。
- 同进程连续多局、A 等待时入队 B、A 的迟到通知/重复 proof/重新绑定 proof 均不能误确认 B；重启后不重新授权旧 uncertain 的 SDK targets。
- result 1、只读请求句柄、匹配读取结果和超时均不是写确认。result 8 持久阻断后保持原始 targets，不清空本地 ledger 或改写服务器校正值。

## 强杀与恢复 oracle

每个子进程到达检查点后写入 name/PID 并保持存活；父进程验证 PID 是自己启动且仍存活的子进程后执行 kill，并确认退出，再启动全新进程恢复。

| 操作 | 检查点 | 恢复前固定预期 |
|---|---|---|
| stage | prepared | 保持 revision 2、一个 queued intent |
| stage | pending_half | `ENVELOPE_JSON`，完整旧 head 不变，所有原始文件不变 |
| stage | pending_verified、record_renamed、disk_before_memory、memory_before_unlock、before_sdk、after_sdk | revision 3、一个 uncertain intent；after_sdk 恰好一条 SDK trace，其余零条 |
| confirm | before_notification | revision 3、uncertain；尚未持久确认 |
| confirm | pending_half | `ENVELOPE_JSON`，旧 uncertain head 和原始文件不变 |
| confirm | record_renamed、disk_before_memory | revision 4、confirmed，确认摘要已保存；不能恢复成 uncertain 后再补确认掩盖回退 |
| result8 | before_notification | revision 3、uncertain、correction_required=false |
| result8 | pending_half | `ENVELOPE_JSON`，旧 uncertain head 和原始文件不变；不假称未完整落盘的通知已经持久化 |
| result8 | record_renamed、disk_before_memory | revision 4、uncertain、correction_required=true |
| enqueue | pending_half | `ENVELOPE_JSON`，队列旧 head 不变；独立 ledger 的新进度 21 已落盘 |
| enqueue | pending_verified | revision 3、两个 queued intent，generation 分别 2/3、击杀目标分别 20/21 |

父进程根据最初 seed、请求的操作及固定检查点生成完整预期 document。测试子类在事务写入前保存 proposal witness；父进程只从它提取不可预测的新 intent nonce，并独立验证整份 previous/next 与预期转换一致。**恢复结果不参与选择预期。** 恢复子进程在任何通知或补确认之前比较整份 document；父进程再次独立比较报告中的 `details.before`。每个 `*_expectation.json`、`*_transaction_plan.json` 和原始前后磁盘文件均保留。

13 条 fake SDK trace 均验证：marker 已关闭读回、SHA-256 正确、封套 payload SHA 正确、确切 intent 为 uncertain、账号/AppID/generation/目标摘要/四项统计/30 项成就完全一致、调用 PID 属于本 runner。每个检查点另外约束 trace 精确条数，因此 `after_sdk` 缺失 trace 不能通过。

## 隔离与复现

```powershell
py -3.14 -X utf8 -B tools/run_steam_persistent_outbox_qa.py
py -3.14 -X utf8 -B tools/run_steam_persistent_outbox_qa.py --run
```

默认只预检。可用 `--godot` 指定引擎、`--work-root` 指定 checkout 外的 ASCII 私有目录。默认工作目录位于 `D:/CodexTemp/steam_persistent_outbox`；新的 run 名含时间与随机 ID，不覆写旧收据。

runner 使用独立 APPDATA/LOCALAPPDATA/TEMP/TMP、无生产 autoload/Steam 插件的最小工程，以及 `.godot/redraw_rejection_source.lock` 独占锁。每步核对源文件、复制后的源码、Git HEAD、引擎 SHA 和锁 token；真实玩家 profile 与默认 QA profile 在前后逐文件核对。最终收据中的 source/frozen-input/engine/head/profile/child-exit/lock guards 全部为 true，Godot/game PID 列表为空。

公开证据包含假账号 `76561198000000001` / `76561198000000002` 的 fixture、原始日志、检查点、源码快照及哈希清单。未包含真实玩家存档、真实账号数据、Steam 缓存、私有运行 profile 或 Godot 导入缓存。

## 失败诊断保留

- `diagnostics/initial_proof_json_failure/`：原始 proof JSON 数值类型问题导致重启后 fake proof 不能确认；保留失败收据、旧受测源码、原 runner/freeze 与磁盘证据。
- `diagnostics/r2_superseded_weak_oracle/`：旧 R2 曾通过，但 profile guard 与恢复 oracle 尚不充分；仅供历史诊断，不作为当前验收。其原始 PASS 标签未篡改。
- `20260908T103058Z_9d3bd74d/`：新恢复断言中的 Variant 推断无法通过 Godot 编译；已改为显式 bool。
- `20260908T103121Z_e0b5f990/`：外部 oracle 的 JSON 整数变成 Godot float，字典精确比较误报；已先进行严格整数规范化，父进程仍对原始独立 oracle 再核对。

各批 `evidence_sha256.json` 均已重新逐文件验证。最新批次 supersede 以上历史批次；没有改写原始失败收据。

## 保留的边界

真实 Steam 写确认语义仍未证实；512 intent 容量无自动压缩；uncertain 不自动重发；服务器校正标志不自动清除。故障试验覆盖受控进程强杀、部分 pending 与受控回调，并不证明断电持久性、任意磁盘故障或真实 Steam 断网重连行为。这些边界不能以本批 PASS 覆盖。
