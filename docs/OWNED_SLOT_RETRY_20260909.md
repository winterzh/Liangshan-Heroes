# 2026-09-09 同进程保存事务重试

## 修复范围

先前写槽在提交、文件回读或释放锁失败后直接返回，调用方随后销毁Session。磁盘可能仍保留本进程的`writing/owner.json`；旧的死进程恢复入口正确拒绝`WRITER_ALIVE`，但当前进程已经失去了重试所需对象，修复磁盘后也无法重新保存。

现在Slot取得或实际创建写锁后保留同一次提交的期望revision/SHA、冻结proposal及原对象的随机owner token。当前进程使用独立的同所有者重试接口，死进程恢复的规则保持不变。新对象即使具有相同PID、账号和proposal，也不能接管原事务。

正式玩家入口仍未开放。本变更只处理本地槽事务，不提供Steam服务器写入确认，也不扩展玩法白名单。

## 文件状态与处理

重试先检查用户目录边界、链接、目录结构、锁原文、当前PID、owner、token、完整记录链和冻结目标。允许的处理只有三种：

| 实际文件状态 | 处理 |
| --- | --- |
| 仍为原head，没有pending | 重新提交同一冻结proposal、同一下一代generation |
| 仍为原head，pending完整且与冻结目标逐字节哈希和规范文档一致 | 将该pending推进为对应记录，不创建另一代 |
| 目标记录已经提交，pending不存在 | 验证该目标，完成保留记录整理并重试释放原锁 |

完整但属于其他目标的pending、坏档、链变化、错误token、不同owner、恢复目录或锁身份丢失均拒绝自动处理。不会删除未知或残缺pending，不会覆盖另一写入者的记录，也不会把已有成功提交再增加一代。

首次写锁元数据可能已经完整落盘，但其回读报错；只在原对象确实创建了锁目录、保存原token且后续完整原文验证相等时，才允许该原对象继续。若释放过程已经删掉owner元数据却没能移除锁目录，则原token不能再由磁盘验证，保持`unsafe`，不猜测空目录归属。

## ContinueFlow 接口

`RunWorldSession`新增：

- `has_pending_save()`：原Session是否仍持有未确认的写槽事务。
- `pending_save_status()`：只读检查磁盘是否可由该对象重试，不泄露锁token。
- `retry_pending_save(source)`：要求原Battle仍为当前场景、仍被保存屏障HELD、冻结时钟记录未变且Steam lease相等，然后处理原冻结事务。

`save_held()`失败后，若结果带有`pending_save=true`，Flow必须保留Session和原Battle的HELD状态。不得释放到玩法中再用旧proposal保存退出。成功重试返回原`generation`、`file_sha256`、`source_held=true`、`owned_retry=true`，之后才可退出。

失败结果保留`code`，并提供：

| 字段 | 含义 |
| --- | --- |
| `pending_save` | 仍须保留原Session及其Store |
| `retryable` | 当前状态可处理，或暂时性I/O错误允许原对象在存储恢复后重新检查 |
| `unsafe` | 不具备自动推进或释放所需证据 |
| `restart_required` | 当前流程不能自动继续；不保证重启能修复坏档、缺失token或未知残留 |
| `recovery_code` | 原失败之外，最新只读检查发现的拒绝原因（如有） |

`dispose()`现在返回Dictionary；存在pending事务时返回`PENDING_SAVE_RETAIN_SESSION`而不销毁内部状态。调用方仍必须遵守结果、保留对象引用；直接置空最后一个引用无法由`dispose()`阻止。`unsafe`状态需要保留证据和战斗，离场必须由Flow明确告知并确认，不能暗中清理文件。

Slot层提供对应的`has_pending_write()`、`pending_write_status()`和`retry_pending_write()`。共享Store的`inspect_owned_commit()`与`retry_owned_commit()`始终复核原锁所有权，与`inspect_recovery()/recover()`的死PID流程分开。

## 隔离验证入口与当前证据

新脚本`tools/owned_slot_retry_qa.gd`使用简化的测试文档验证器，复用实际Slot写入接口和共享envelope、SHA、CAS、写锁、pending、记录链实现。设计覆盖十种场景：提交后解锁失败、有效pending写后失败、未写pending时失败、owner写后回读失败、错误token、不同owner与新对象、残缺pending、结构有效但不同目标的pending、删除owner后的半释放，以及Session拒绝丢弃token和拒绝无关Battle。

每个可恢复场景要求回到同一generation/目标SHA，重复重试不产生另一代，后续同进程保存仍可成功；拒绝场景比较前后目录及文件SHA，验证没有擅自改动。脚本启动前检查隔离变量，拒绝复用已有`user://owned_slot_retry_qa`目录，所有故障注入只在该私有目录执行。

受控入口为`tools/run_owned_slot_retry_qa.py`，默认只读预检，只有`--run`才执行。它使用既有Mission runner的`running_engine()/run_engine()`及项目共享引擎锁：冻结生产文件和本次工具、记录源码与引擎SHA，在全新真实D盘profile先独立导入，再运行错误profile拒绝和正式回归。每阶段保存原始日志，失败也保留源码快照、未完成收据和最终源码检查；不会终止其他进程。

```powershell
py -3.14 -X utf8 -B tools/run_owned_slot_retry_qa.py
py -3.14 -X utf8 -B tools/run_owned_slot_retry_qa.py --run --work-root D:/CodexTemp/owned_slot_retry
```

运行器自动设置`STEAM_DISABLED=1`、`LSH_OWNED_SLOT_RETRY_QA=1`、`LSH_OWNED_SLOT_RETRY_PROFILE=<profile根>`，并将`APPDATA/LOCALAPPDATA/TEMP/TMP`分别指向其小写同名子目录。GDScript底层报告写入`user://owned_slot_retry_qa/report.json`，包含每条断言和受测源码SHA；成功/失败/隔离前置拒绝退出码分别为0/1/2。原始证据归档到`qa/owned_slot_retry_20260909/<批次>/`，目录`.gdignore`阻止Godot扫描；错误profile必须在任何fixture及报告写入前退出2。运行器要求全部76项预期断言、无重复名称、四份引擎回读源码SHA和运行前后路径集合/文件SHA一致，才将收据记为完成。

报告明确`real_steam=false`、`production_slot_document=false`、`full_world_flow=false`，不能将此测试等同于实际战斗流程或真实Steam验收。

主任务已通过受控runner完成原生验证，最终批次`20260909_034724_209b6af2`的76项断言全部通过；独立导入、错误profile拒绝及回归退出码分别为0/2/0，错误均为0。收据`complete=true`，源路径集合、源码和生成场景guard均通过。随后独立回读确认当前2953份源码与冻结2953份源码逐项SHA一致、两批归档共23份源码/场景快照与各自原收据一致，四份引擎内源码SHA及生成`.tscn`与runner固定原文一致。[QA说明](../qa/owned_slot_retry_20260909/README.md) · [独立复审](../qa/owned_slot_retry_20260909/final_review.json)。

首轮`20260909_034414_bd649218`保留为失败证据：导入退出0；使用`--script`启动SceneTree时，Session/Battle/Unit在项目autoload名称注册前被预载，出现`Localize`及`Sfx`未定义错误，profile_guard实际退出1而非预期2，未产生有效回归报告。改用普通Node主场景、`_ready()`延迟执行与`get_tree()`调用后，最终批次通过；没有修改生产三文件来掩盖该QA启动错误。两批原始日志、收据和源快照均未覆盖，失败批次不增加通过项数。

本次独立复审未运行Godot或Git。该76项结果使用测试文档验证器，验证真实槽事务而非完整战斗文档。完整Flow的保存、保持屏障、重试、退出，以及跨进程恢复仍由主任务的正常场景QA分别记录。

本批白名单：`scripts/run_snapshot_store.gd`、`scripts/run_slot_store.gd`、`scripts/run_world_session.gd`、`tools/owned_slot_retry_qa.gd`、`tools/run_owned_slot_retry_qa.py`、本说明，以及主任务实际运行后产生的`qa/owned_slot_retry_20260909/`原始证据。
