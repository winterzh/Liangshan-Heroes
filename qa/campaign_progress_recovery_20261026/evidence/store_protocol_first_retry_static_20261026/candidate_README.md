# Steam 唯一目录释放协议草案

仅后继候选，**未编译、未运行、未采用，不可据静态检查替换当前20文件冻结**。唯一拟集成文件是 `scripts/steam_receipt_store.gd`，依赖当前冻结的 Receipt/Ledger 和未修改的生产 `run_snapshot_store.gd`。旧 handoff_candidate、原冻结、生产和当前 tests/io 均未改。

## 本切片实际实现

1. 活 writer 正常释放前，验证自身原 owner 字节/PID/token，整目录 `writing` 原子移至 `cleanup_v1_<PID>_<fresh nonce>`。先保留 owner 文件，再发布释放标记。
2. 原 owner.json 原子移为账号目录内 `release_v1_<claim PID>_<claim nonce>_<cleanup PID>_<cleanup nonce>_<head revision>_<head SHA>.json`，其内容不重写。完整原字节、账号和头链仍可独立核验。
3. 只删除标记绑定的唯一空 cleanup 目录，最后删除标记。**从不以新标记删除固定 writing 或 recovering**。若标记删除前有延迟 writer 新建 writing，保留该新锁。
4. 新 cleanup/marker 的死亡收尾：核验原 writer 与最近 claim PID、完整 inventory/head，使用新的随机 nonce 改名接管唯一源路径。恢复者再死仍保留 owner 原字节和唯一来源；接管不依赖会复用的固定 writing 路径，也不只依赖 PID。
5. acquire 在 mkdir/owner 完成后复查屏障并返回新读 head；commit 同样检查屏障。延迟 acquire 保留原 proposal/owner，屏障存在时返回可重试 WRITER_BUSY。屏障消失后真实 CAS 已改变，则冻结原 CAS/proposal 为 stale-abort scope，先释放本对象仍活着的旧锁再要求重启；释放中途失败仍可用同一 scope 重试，不重算原 proposal。

目录/标记只是事务协议，账本 envelope、Receipt v2/v3 模型和奖励规则不变。新扩展中未知文件、未知目录、额外 marker、owner/head/token 不匹配、非空 cleanup、权威 pending 均拒绝。文件读取/前驱 SHA/revision/CAS 校验沿用基类；`_chain()` 只将严格识别的 marker 从 record 集合分离。

## 明确保留的边界

- **旧 fixed writing/recovering 的 inspect/recover 仍直接调用基类**，保留当前完整 pending 前滚和已提交锁释放范围。本草案没有用直接 rename 固定 writing 的方案接管死亡 writer。
- 旧无标记空 writing 仍拒绝；旧 recovering 无持久 owner、基类恢复中先删 owner 的窗口仍未修。半 pending 仍 ENVELOPE_JSON，不重建、不丢弃，不扩展为 staging。
- 旧固定锁恢复的并发窗口没有在本切片被重新设计。不能把新 unique cleanup 的收尾能力称为整个 Store 恢复过程无缺口。
- 新目录由 nonce 区分代际；以“先读旧 owner，之后 rename 固定 writing”当内容 CAS 的早期草稿已撤回。以旧 marker 重复删除固定 writing 的方案也未采用。
- Campaign CFG 的 `OwnedRelease`、LC 继承的同类窗口仍待办，本切片不能授予整个 gen2→CFG→ledger→gen3 链完整恢复资格。
- 长 marker 文件名、Windows 实际路径长度、DirAccess rename/删除分享权限、GDScript 编译和多进程交错都尚未验证。目录名碰撞、PID复用可能导致保守拒绝；不能为通过测试改成猜测所有权。
- MAX_RUNS256、历史退休、真实 SDK、断电持久性均不在范围。

## 精确集成范围及证据

`source_manifest.json` 记录原 handoff Store、生产 SnapshotStore、当前 handoff Receipt/Ledger 依赖 SHA 和本候选 SHA。此次没有新 base 模块；后续如改变公共基类，需要重新冻结和扩展回归，不能偷偷借此文件放宽 classic/slot/LC。

`static_audit.json` 只记录源码检查，不是 Godot 编译或 I/O 结果。`tests/protocol_model.gd` 是命名/布局合成模型，尚未运行，不能替代原生证明。当前原 I/O runner 的断点仍指向旧协议；不得修改其已固定 README/脚本以冒充此候选验收，应另建后继副本。

## 新原生 I/O 断点与必要负例

新断点（生产 `_checkpoint` 仍为 no-op，由外部 debugger 停在实际语句）：

- `release_directory_claimed`：原完整目录已移到唯一 cleanup。
- `release_marker_published`：原 owner 已移到 marker，cleanup 空。
- `release_directory_removed`：唯一 cleanup 已删，marker仍在。
- `release_marker_removed`：正常释放磁盘终态。
- `unique_release_recovery_claimed`：新进程已接管唯一 cleanup/marker，随后再终止，第三进程收尾。

每一点必须保留实际原 PID、owner/record/marker SHA、终止后完整目录副本，再由新进程调用原 API；完成后核对同 handoff exact proof、原 model generation、一次奖励，不能只看目录消失。

必要真实文件失败：整目录 rename 拒绝、owner→marker rename 拒绝、唯一 cleanup 删除拒绝、marker 删除拒绝；解除原生句柄后用同一对象/原 proposal 重试。

必要交错：A 在旧 open_head 后停住；B 完成提交并进入 cleanup/marker；A 继续 mkdir/owner，必须保持 A 文件不被 B 删除且 A 不得越过屏障写 journal。B 清完后 A 原 CAS 不变则原提案重试，CAS 已变则释放自己的锁并明确 restart。还须测两个 recovery 抢同一 nonce 源，以及首个 recovery 取得新 nonce 后再死亡。

拒绝负例：活原 writer/活 claimant、不同账号、修改原 owner、marker 指向另一 cleanup、cleanup 出现 owner 或子目录、head SHA 漂移、重复 marker、非canonical数字/nonce/哈希、链接、未知文件、旧无标记空 writing、旧 recovering、半 pending。保留旧已通过的完整 pending/record-renamed 恢复案例，确认基类委托未缩小原真实能力。

在上述原生验收及独立复核完成前，此目录仅供代码审阅与下一轮受控冻结。
