# Steam Store 恢复协议后继设计

状态：只读设计，不是已实现修复。本次没有修改 20 个候选脚本、冻结工程或 `tests/io`。当前半份 `receipt.pending` 仍以 `ENVELOPE_JSON` 拒绝；owner.json 已删而 writing 仍在时仍以 `UNKNOWN_OR_MISSING_LOCK` 拒绝。两种拒绝诊断通过不能写成完整恢复通过。

## 当前证据与边界

当前 `steam_receipt_store.gd::OwnedRelease.release_store()` 先删 `writing/owner.json`，再删空 `writing`；`_removed/_holder/_head` 只存在于原对象内，因此同对象可以重试，进程死亡后证明消失。

`run_snapshot_store.gd::inspect_recovery()` 要求完整、规范的 owner.json，验证账号、PID、随机 token，并要求原 PID 已退出；完整 pending 另外验证 envelope、payload、前驱 SHA 和连续 revision。`recover()` 使用这些证据前滚或只释放已提交锁。不能削弱这些校验。

**旧无标记空 writing 绝不能自动删除。** 它与另一个 writer 刚成功 mkdir、尚未写 owner.json 的时刻没有可区分的磁盘证据。合法 head、目录为空、等待若干秒或者当前没有已知 Godot PID，都不能补成该锁的所有权证明。旧目录保持拒绝，保留诊断；不把人工维护路径藏进自动恢复。

另外，当前 `recover()` 使用裸 `mkdir recovering` 抢占恢复权，`inspect_recovery()` 对任何 recovering 都拒绝。恢复进程自身死亡也会留下无法辨认所有者的目录。后继若宣称释放/恢复全过程可中断，就必须同时处理这一点，不能只修正常 writer 的最后两次删除。

## 第一小批：改变释放协议，复用原 owner 的完整字节

建议不新增需要先写半份再解释的 release JSON 内容。复用已经闭合并核验的原 owner.json，通过同卷原子 rename 发布释放标记：

1. 原对象验证原 owner 原字节、账号、当前 PID/token 和实际 head；要求没有 `receipt.pending`、未知文件或另一恢复持有者。冻结 head revision/SHA。
2. 将 owner.json 原子 rename 到账号目录内的一个严格命名的 release 标记。内容仍是原 owner.json 的完整字节；标记名编码协议版本、精确清理对象、head revision/SHA、当前 claim PID/token。rename 前后都检查目标不存在、路径无链接，失败保留原 proposal/原所有权。
3. 标记存在期间所有普通 `open_head/acquire` 都报告恢复/释放未完成，不得开启下一笔写入。此时 writing 无 owner 是有标记证明的专用状态，与旧无标记空目录不同。
4. 验证待清理目录确实为空、没有 pending、head 仍与标记绑定；只删除这个精确目录。出现新文件、子目录、owner、未知残留或 head 变化，一律拒绝并保留。
5. 目录已消失后，再验证标记原字节和 head，最后删除 release 标记。最后一步完成才解除阻塞。若进程在最后删除后死亡，磁盘已经完整释放；不存在无证明的空锁目录。

标记命名是新的事务协议，需要实现时固定长度、数值域、小写哈希、唯一性及路径长度限制；不得接受任意目录名或从记录提供的绝对路径。清理对象只能是固定 writing，或按新恢复协议生成的精确 claim 目录。最多一个有效 release 标记；两份标记、写锁与标记的非法组合、名称/内容不匹配都拒绝。账户仍取调用方固定 root/owner，不能取标记覆盖。

普通同对象 retry 继续保留 `_pending.proposal`、head 和原成功结果，不得新建 Ledger 或重新生成 token。释放前的错误仍有原 owner；释放中的错误由标记和对象保留的 claim 共同证明；释放后重复 handoff 依靠原账本精确 descriptor/proof 幂等。

### 标记恢复与并发

只读取标记还不等于有权清理。要验证原 owner 规范字节、标记绑定的实际 head、原 writer 与最近 claim PID 均已退出，以及完整目录 inventory。

不要再用一个无所有者的空 recovering 目录接管。标记恢复可以通过 **原子 rename 该精确标记到包含新 claim PID/随机 token 的名称** 抢占；原 owner 字节和 head 绑定保持不变。两个恢复者争同一个原路径，只能一个 rename 成功。活着的 claim 拒绝其他恢复者；该恢复者再死亡时，可以对其精确标记重新进行相同的 dead-PID/rename 接管。清理前再次核对原标记内容哈希、head 和 inventory。

这里的随机 token、canonical 文件与 PID 校验沿用现有本地协议的信任边界，不是防止拥有账户目录写权限的攻击者伪造签名。不能因此省略当前链接检查、前驱链、账号检查或精确 CAS。

现有正常 `recover()` 路径也需要可持久辨认的 claim：建议原子 rename 原 writing 目录为带当前 claim PID/token 的专用恢复目录，保留原 owner.json 与内部文件；普通 writer 把它视为阻塞。接管前后核对原 inventory，仅允许这一个已知路径改名。恢复者死亡后按同样的 dead-PID + 原子 rename 规则接手。恢复完成后，使用上面相同的“owner 原子移到 release 标记 → 删除精确空目录 → 删除标记”顺序。不能继续创建裸 recovering 再声称全部中断点闭合。

## 第二小批：半 pending 不猜测、不当作任意缓存删除

当前 `receipt.pending` 是 canonical 待提交对象；它坏了说明无法确认候选记录，不等于可以忽略。现有 owner 只证明谁持锁，未保存完整 proposal；只凭旧 owner 和合法 head 无法恢复丢掉的后半段。因此以下两条必须分开。

### 对未来写入：先在锁内 staging，闭合后再发布 pending

推荐更小、可解释的长期协议：把真实 envelope 先写入 `writing` 内的、绑定该锁 nonce 的唯一 staging 文件。完成 flush、关闭、原字节读回、严格 envelope/model 校验后，才同卷原子 rename 成账号根目录的 `receipt.pending`；之后复用现有 pending → record 的 CAS/验证/前滚。

- 半写 staging 是新协议明确定义的“未发布提案”，不能获得 Ledger proof，也不能让上层 ACK gen3。
- 只有原持锁者（或验证原 writer 已死后抢占的恢复者）可以处理该锁 nonce 对应的 staging。未知文件、不同 nonce、同时存在 pending 与 staging 的非法组合都拒绝。
- 死亡恢复在没有已发布 pending 的情况下保留当前有效 head。未发布 staging 连同原 owner/claim 的证据移入固定、受控的恢复归档区域；不原地删除字节、不用任意外部路径。归档必须保持原账号、锁身份和文件哈希，且不得进入热 journal 的记录集合。
- claim 与归档转换必须使用可重试的原子 rename，并沿用上一节的持久恢复所有权。归档前后被中断，不得落回无 owner 的空锁，也不得让另一个 writer 在仍有权威 pending 时进入。
- 这只是撤销“未发布提案”，不是撤销已提交业务。战役 gen2 仍保存完整、受信且同 token 的 Intent/credit，启动流程从原 head 重新计算同 handoff；若 head 已包含完全相同的终局，则只给 exact proof。不得回到 Battle/metrics/UI，也不得 clear receipt 或另开 slot。

新协议必须证明故障后的启动确实补完 gen2 handoff，而不能只证明清除了 staging。对于没有持久上层请求的普通 Ledger 调用，尚未返回成功的提案丢失不等于已持久成功；不要借战役的 gen2 保证扩大普通调用的承诺。

### 对现有半 pending：默认仍拒绝，单独设计受信修复入口

不要把旧文件追认为新 staging。若将来要自动修复旧半 pending，需要额外的受信完整请求：严格、已持久的战役 gen2 Intent/credit，经现有账户、correction epoch、token、context、basis、当前 canonical head 校验，重新生成完整目标 proposal/envelope。

只有现有残片是该唯一目标 envelope 的**精确字节前缀**，原 owner/死亡状态有效、head 与预期 CAS 相同、无其他残留时，才可能进入一个独立恢复事务；它仍须原样归档残片，不能先删再尝试猜测。另一 Intent、错误 token/epoch、任意非前缀、head 已变化、只有 slot 自报字段或缺失 gen2，全部拒绝。

这不能塞进当前 `Ledger.open()` 自动路径：它目前没有上层 Intent 授权，也不能在 Service adoption 前凭文件内容制造 credit。需要明确传入受信请求的后继接口与上层启动编排。相较于修复旧残片，先实现新 staging 发布协议范围更小；旧半 pending 保留为拒绝/人工诊断，不声称已经可恢复。

## 精确模块范围

| 模块 | 后继最小责任 |
|---|---|
| `steam_receipt_store.gd` | release 标记、canonical 事务状态识别、持久 claim、同对象 retry、dead-PID 恢复和新 staging 发布；严格读取旧布局；旧无标记空锁保持拒绝 |
| `run_snapshot_store.gd` | 若复用公共机制，只增加默认行为不变的受限扩展点（事务项分类、发布路径/清理），不能让所有未知文件默认可忽略；否则由 Steam specialization 覆盖相关方法，避免把新协议偷偷应用到全部 classic/slot/LC |
| `steam_run_ledger.gd` | 保持原 `_pending` 与 proposal；适配 Store 新阶段。未来“旧半 pending 的受信修复”才需要显式新入口，不能在普通 open 内静默猜测 |
| `steam_service.gd`、`steam_local_run_session.gd`、startup/Coordinator | 只有选择实现旧残片受信修复时才扩展接线；新 staging 的 abort 后必须以已持久 gen2 自动重试原 handoff，不回放 gameplay |
| `steam_run_receipt.gd` | 释放协议本身无需改模型或 v2/v3 领域校验，不新增奖励捷径 |
| `tests/io` 的后继副本 | 新断点/状态 oracle 与跨进程恢复矩阵；当前 runner 与原失败收据保持原样 |

不建议仅给当前 OwnedRelease 增加“空目录可删”的分支。若复用公共基类必须跑普通 Ledger/classic/slot 的对应回归；更窄的第一实现可以先限定 Steam Store，旧 envelope 和模型 schema 不改变，事务协议另行版本化。

## 真实 I/O 复验门槛

先在新的候选/冻结和新的 `tests/io` 副本中进行。所有断点仍来自真实 Store API，继续用外部 debugger、Windows sharing denial、原 PID 终止及新 PID 恢复，不 mock 返回值。

1. 释放：owner rename 前、rename 后、空目录删除前/后、最后标记删除前/后逐一终止；每个有效新协议状态恢复后 exact proof、一次 win、相同 descriptor，不能只判目录消失。
2. 同对象拒绝：拒绝 owner rename、拒绝目录删除、拒绝标记删除，解除原生句柄后用原 proposal 完成；原字节和提案哈希不变。
3. 恢复者中断：第一个 recovery 抢占后、前滚后、prune 后和释放中再次终止；第三进程接管。另测两个活 recovery 竞争，只有一个获得 claim。
4. 所有权负例：活 writer/活 claim、另一账号、token/标记名不一致、不同 head SHA、非法目录项、外来 owner、并存 pending/非法 staging、符号链接与未知文件全部拒绝，原 inventory 不变。
5. 旧兼容：已有 canonical v2/v3 链、旧完整 pending 按原校验恢复；**旧无标记空 writing 仍拒绝**；旧半 pending 未实现明确受信接口前仍拒绝并保留。
6. 新 staging：半写、flush 后、关闭/验证后、发布前后各断点；同时核对归档原字节、canonical head、锁闭合，再由真实启动 gen2 续办证明最终奖励没有漏记。published pending 的完整校验不能因增加 staging 而放宽。

以上只证明受控进程中断与文件 API 结果，不证明断电、存储控制器缓存或真实 Steam SDK 发布。只有最后 gen2→ledger→gen3 的真实跨进程收据才能声明上层交接完成。

## MAX_RUNS 256 留到后继

本批不改上限。直接上调只是延后容量失败，不能解决长期历史体积与幂等性。需要先定义历史退休：哪些 token 已被上层 gen3 确认、哪些旧 slot 仍可引用、哪些 correction tombstone/settlement descriptor 必须永久拒绝重放、如何在不丢 exact proof 的前提下压缩或分层索引，以及退休事务自身的原子性/恢复。不能简单删除最旧 run 或把 terminal 一律视为可丢弃，也不能为了退休将 legacy_unknown/invalidated 重新当成正常结算。
