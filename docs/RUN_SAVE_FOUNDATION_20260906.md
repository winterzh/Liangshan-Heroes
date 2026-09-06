# 续玩基础：磁盘层草稿及验证（2026-09-06）

M3 已完成一个独立磁盘层草稿的有限验证，并保留实测源码和证据；尚未接入生产保存或继续入口。当前 store raw SHA-256 为 `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3`，runner 为 `233dcd47bfe99af5419c38a2a135060860dbf46719683521c8e5610776b73fd2`。被测原文以文本封存在 [tools/contracts/run_save_store_draft_20260906](../tools/contracts/run_save_store_draft_20260906/README.md)，运行证据位于 [qa/run_save_store_20260906](../qa/run_save_store_20260906/current_qa_summary.json)。归档本身不新增 Autoload、生产调用或公共 QA 框架。

## 已验证的范围

当前五次完整运行无重复、无遗漏覆盖 catalog 的 **49 个案例**。共 **54 次子进程阶段 = 50 次正常 exit=0 + 4 次预期终止 exit=1**；**1,233 次断言**是 50 份正常报告的检查总和。四个被终止 writer 只提供检查点和进程退出证据，没有正常检查报告，未计入断言总数。旧版本通过和三次原始失败也未混入当前统计。

| 当前运行 | 范围 | 案例 | 进程阶段 | 断言 |
| --- | --- | ---: | ---: | ---: |
| `20260906T105745511741Z` | 损坏/不支持封装 | 14 | 14 | 350 |
| `20260906T110026638765Z` | payload/validator 输入拒绝 | 6 | 6 | 132 |
| `20260906T110042779296Z` | I/O、冲突、回滚与清理 | 23 | 23 | 624 |
| `20260906T110241975424Z` | 单进程写读、独立进程重启读取 | 2 | 3 | 59 |
| `20260906T110309704630Z` | 四处写入检查点后终止并新进程读取 | 4 | 8 | 68 |

每阶段收据锁定 store、driver、faults、runner 和极小私有项目源码。正常阶段核对 manifest SHA、run/case/phase、实际 PID、完整断言、错误日志与退出状态；Python 另外检查实际文件长度/摘要和明确 A/B payload。独立审阅还逐项复核了当前 54 个阶段的实际夹具状态。原始目录包含私有工程和测试数据，归档仅选择 JSON 报告、日志、准备/完成收据、源码摘要和修复前文本，不复制 `project/`、`private_profile/`、fixture 文件、玩家内容、Godot 缓存或引擎程序。原报告中的本机路径字符串用于追溯，不是可迁移运行路径。

## 磁盘协议与限制

草稿 `read_slot()` 只验证并读取；`save_payload()` 接收已编码 UTF-8 字节和显式完整 validator。封装六字段均为字符串：magic、format_version、schema_version、payload_bytes、payload_sha256、payload；payload 保留原 UTF-8 文本，摘要针对原字节。无效 UTF-8、空/过大输入、类型/版本/字段/长度/摘要/语义错误均拒绝，未知或损坏旧槽不被新档掩盖。SHA 用于完整性检查，没有签名或来源认证承诺。

当前只有明确、已存在的 `res://scratchpad/run_save_store/fixtures/<case>` 子目录可以使用；没有玩家 `user://` 路径或默认创建行为。路径/链接拒绝代码存在，但当前 49 例未实测越界、缺目录或链接边界，不能标成这些边界已通过。validator 只验证精确四字段 `disk_fixture` 假 payload，证明 Callable 参与完整校验；它不等于生产实体 schema 或实际内容兼容验证。

同目录使用正式槽、pending、previous 和 mkdir 合作锁。写入 pending 后关闭并完整回读；再次确认旧槽，移旧槽到空 previous，再将 pending 移到空正式槽；最后回读确认、按摘要清理备份并释放空锁。它是有备份的多阶段事务，未声称单次原子替换或阻止不遵守协议的外部写入。目标空且 previous 完整、仍匹配原摘要时，同次替换失败可以尝试回滚；失败时旧档可能留在 previous，不能笼统称为原路径已恢复。

四个实际终止点及新进程看到的残留：

| 终止检查点 | 保留数据 | 新 reader 行为 |
| --- | --- | --- |
| pending 关闭后 | 正式槽 A、pending B、锁 | RECOVERY_REQUIRED；不改变残留 |
| 旧槽移至 previous 后 | previous A、pending B、锁 | 同上 |
| 新槽已移入后 | 正式槽 B、previous A、锁 | 同上 |
| 新槽验证并清掉旧备份后 | 正式槽 B、锁 | 同上 |

清理失败可能是已验证新槽仍在、`ok=false`；若 previous 已删而锁清理失败，旧 A 不再保留。回滚失败、最终回读不确认或外部冲突返回 unknown，不假报恢复成功。I/O 返回错误有明确窄接缝注入，另有真实截断、关闭重开、rename/rollback、Windows 只读备份删除失败、非空锁删除失败证据；不能据此宣称实际磁盘满、ACL、网络断连、坏扇区或全部 OS 错误都已实测。

## 原始失败与修复来源

原稿 `a812ee51…` 的旧 roundtrip 有 22 次检查通过，单独保留。`20260906T105109305561Z` 因 QA `_hash(empty)` 的引擎错误未完成；`20260906T105546530306Z` 与 `20260906T105642990314Z` 保留 store `_digest(empty)` 的原始 ERROR。即使局部报告显示断言为真、进程 exit=0，整次仍是失败，没有修改历史收据或转记为通过。

[empty_digest_fix/receipt.json](../qa/run_save_store_20260906/empty_digest_fix/receipt.json) 保存修改前 store/runner 原字节摘要及文本。唯一 store 修复是空字节不调用 HashingContext.update，仍调用 finish 得到标准空 SHA；空 payload 继续由 PAYLOAD_SIZE 拒绝。runner 仅同步该 store PIN。当前 49 案例均在修复版本上完成。

## 下一步接入边界

目前没有 Battle 适配、实体 codec、稳定 ID/引用图、RNG/计时器/队列恢复、快照暂停屏障、场景重建、存档兼容迁移或继续按钮。新进程对残留只安全拒绝；没有自动恢复，也不能仅按时间删锁。正常重启证明 writer 已退出后 reader 能读取，不证明同时读写隔离。flush/关闭和精确进程终止测试都不是断电、fsync 或目录持久性保证。

后续应先确定一个受支持战斗阶段的完整 codec/内容兼容契约、生产受控路径和生命周期，以及各残留状态可重复执行的恢复决策，再在创建场景前完整验证引用图。磁盘草稿的通过不能替代实际战斗跨进程恢复的等价性验证。

复现需将封存的 `.gd.txt` 恢复原 `.gd` 名称到另一份新 checkout 中原本不存在的被忽略 `scratchpad/run_save_store/`；原 runner 原文必须放回该位置。存在即停止，不覆盖当前实验。完整摘要核对、恢复与默认预检步骤见[封存说明](../tools/contracts/run_save_store_draft_20260906/README.md)。实际引擎运行由根任务取得共同锁后串行安排。
