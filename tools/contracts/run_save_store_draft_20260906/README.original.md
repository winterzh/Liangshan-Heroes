# RunSaveStore 磁盘层草稿

2026-09-06。独立磁盘层草稿与私有 QA 均位于本目录，依据 `scratchpad/save_resume_architecture_review.md` 与 `scratchpad/defense_resume_schema.md` 的文件事务要求准备。root 已完成当前 49 个目录内磁盘案例；未接入生产、公共工具或玩家目录。当前 `run_save_store.gd` raw SHA 为 `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3`。

**这不是续玩实现，保存/继续按钮未开放。** 没有 Battle 适配、实体 schema、序列化反射、RNG/引用恢复、暂停屏障或跨进程战斗等价结果。这里只接收未来 codec 已编码的 UTF-8 payload 字节，并验证、读取、事务写入单个磁盘槽。

## 接口和文件边界

`run_save_store.gd` 不声明全局 class_name，不依赖 Autoload。未来小夹具通过 `load(...).new(fixture_directory, validator_callable)` 创建。

- `read_slot() -> Dictionary`：不消费、不修复、不迁移文件；原损坏档保持原路径、原字节。
- `save_payload(payload: PackedByteArray) -> Dictionary`：先验证完整 payload，再检查旧档；旧档损坏、未知版本或内容不兼容时拒绝保存，不能用新档掩盖原问题。
- 没有默认玩家目录。调用方必须显式提供已经存在的 `res://scratchpad/run_save_store/fixtures/<case>` 子目录或其绝对路径。目录越界、链接、缺失 validator 都拒绝；本草稿不创建 fixture 根目录，不打开 `user://`。
- 成功返回 `ok=true, code=OK, commit_state=new_verified` 和 payload/file SHA。失败返回稳定 `code`、操作阶段说明、底层 Godot Error；完整验证的失败附 `validation` 或 `cause`。这些诊断字段供未来 UI 映射，不直接作为玩家文案。

validator 签名是 `(payload_bytes: PackedByteArray, schema_version: String) -> Dictionary`，必须返回布尔 `ok`。它负责**完整** payload 的范围、类型、玩法内容指纹、引用图和相互一致性；不能只检查“是 JSON/Dictionary”。本层没有“默认放行” validator，也不实现实体字段白名单。validator 必须纯同步、确定、无 I/O/场景创建/RNG/重入；它会在输入、临时回读、旧档/备份与最终回读时多次调用，不能把调用本身当一次恢复。

本草稿的磁盘封装是 JSON 对象：`magic,format_version,schema_version,payload_bytes,payload_sha256,payload`。六个值都是字符串，版本固定 `"1"`，payload_bytes 为规范十进制字节数。`payload` 存放**已编码 payload 的原 UTF-8 文本字符串**，读取时还原其原字节计算 SHA-256；它不是重新 stringify 的嵌套对象。这样不会因空白、字段排序或 64 位整数转浮点而改变摘要。最终业务文件格式仍待 root 单独评审；这里没有宣布替换既有 schema 草案。业务元数据应由未来 codec 包入并完整验证，不能把文件中的路径加载成脚本。

限制 payload 为 16 MiB，封装长度有独立上界。转换字符串前先检查 UTF-8 字节序列，拒绝截断、错误续字节、过长编码、surrogate、超出 Unicode 上界及 JSON 中非法的原始 NUL，避免坏编码先触发引擎 Unicode 错误；然后确认 UTF-8 往返一致。魔数/版本/字段集合/字节数/摘要全部校验；未知 schema 拒绝，不做猜测或降级写回。SHA 是完整性检查，不是签名或来源认证。

## 写入与失败行为

同目录只使用 `run_continue.json`、`run_continue.pending`、`run_continue.previous` 和空锁目录 `run_continue.writing`。通过 mkdir 获取合作式单写者锁；不偷锁、不自动删残留，不宣称阻止不遵守协议的外部程序改文件。

1. 验证新 payload 及既有完整旧槽。无效输入/损坏旧槽在创建锁或临时文件之前返回。
2. 写入原本不存在的 pending，检查写入位置/错误，flush、关闭；重新打开并检查完整封装、全部 payload 语义与精确原字节。
3. 确認原槽仍与开始时相同。若有旧槽，将其移到原本不存在的 previous，回读并验证其原摘要；不向已有目标 rename。
4. 将 pending 移到空的正式槽。失败时仅当正式槽仍空、previous 完整且摘要仍为旧档时尝试 previous → 正式槽，并回读确认。若有未知文件挡住，保留所有文件，不能覆盖它。
5. 回读新正式槽并完整验证及比对预期文件 SHA。通过后只删除摘要仍匹配的本次 previous，再释放自己的空锁。

锁后任一步失败均保留现场，并返回 `recovery_required=true`。普通写入失败时旧槽仍在原路径；替换失败且安全回滚成功时旧槽恢复原路径。**如果回滚失败、最终回读无法确认或出现未知外部文件，旧槽原字节可能保留在 previous，不能声称原路径已恢复。** 返回的 `had_old_slot` 区分最初有无旧档，`original_slot_state_unchanged` 检查原文件或原本空槽是否保持，`old_slot_at_original_path` 只有最初确有旧档且回读一致才为 true。`commit_state=unknown` 时 UI 不能自行宣布保存成功或失败回滚成功。清理失败可能已存在验证通过的新档，返回 `commit_state=new_verified` 但 `ok=false`，仍不悄悄忽略遗留锁/备份；若 previous 已成功删除而释放锁失败，完整新档仍在，但旧备份不再存在。

中断后 `read_slot` / `save_payload` 返回 RECOVERY_REQUIRED，不自动清空 pending/previous/锁。本稿保留证据并安全拒绝；自动恢复/用户确认恢复/删除槽均尚未实现，不能据此开放按钮。读取未知 schema 或损坏档也不尝试修复。若测试 validator 自身抛脚本错误而中断，完整错误日志同样导致 QA 失败；槽写入过程留下的锁不被自动移除。

Windows 平台依据：Godot 4.6 的 [DirAccessWindows::rename 实现](https://github.com/godotengine/godot/blob/4.6/drivers/windows/dir_access_windows.cpp#L254) 在目标已存在时先删除再 MoveFileW，所以此稿使用“有备份的两次同目录移动”，**没有单次原子替换承诺**。文件关闭及 flush 的公开约定见 [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html#class-fileaccess-method-flush)。没有证明断电/fsync/目录持久性；这些须与目标文件系统一起测试，不能用普通返回 OK 代替。

## 验证记录与剩余 QA

当前已完成以下证据核对，失败尝试不并入通过结果：

- 原稿 `a812ee51ada71837ec8fd238c0786bd60d63e881c4beaa5093df65a81b9f9192` 的 roundtrip 在 [20260906T105022891023Z](runs/20260906T105022891023Z/receipt.json) 通过 22 项检查，覆盖真实新写 A、完整读取、覆写 B 和干净事务收尾。这是原稿的单进程磁盘夹具结果，不是当前修复版的全套回归，也不是战斗续玩结果。
- 首轮 corrupt [20260906T105109305561Z](runs/20260906T105109305561Z/receipt.json) 的前五例通过，但 empty_file 触发 QA 自身 `_hash(empty)` 的引擎错误，整组未完成；[失败日志](runs/20260906T105109305561Z/reports/empty_file_single.log)保留。QA 已改为零字节时跳过 `HashingContext.update`。
- 单独 empty_payload [20260906T105546530306Z](runs/20260906T105546530306Z/receipt.json) 随后复现原稿 `_digest(empty)` 的两条引擎 ERROR；即使报告内 25 项断言为真，严格日志检查仍判该次失败。[原始日志](runs/20260906T105546530306Z/reports/empty_payload_single.log)保留。
- root 仅将原稿 `_digest` 改为零字节时跳过 `update`，保留 `finish` 生成标准空字节 SHA，runner 只同步原稿 PIN；空 payload 仍应由 `PAYLOAD_SIZE` 拒绝。当前原稿 SHA 为 `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3`，runner raw SHA 为 `233dcd47bfe99af5419c38a2a135060860dbf46719683521c8e5610776b73fd2`。[修复收据及修改前原字节](empty_digest_fix/receipt.json)单独保留。
- 修复后五次运行已覆盖当前 49 个 catalog 案例，无重复或缺项；见 [当前汇总](current_qa_summary.json) 和下表。共 54 次子进程执行：50 次普通 exit=0，4 次在准确检查点被启动器终止、exit=1。1,233 次断言是 50 份普通报告的合计，包含重复来源和夹具建立检查，不是 1,233 个独立功能；四份中断 writer 只有检查点收据，没有普通通过报告，也未把其检查点前操作额外加入计数。每个中断案例还要求独立 reader 验证真实残留与拒绝隐式恢复。

| 当前运行 | 案例 | 普通进程 / 预期终止 | 普通报告断言 |
| --- | ---: | ---: | ---: |
| [105745511741Z](runs/20260906T105745511741Z/receipt.json)，corrupt | 14 | 14 / 0 | 350 |
| [110026638765Z](runs/20260906T110026638765Z/receipt.json)，input | 6 | 6 / 0 | 132 |
| [110042779296Z](runs/20260906T110042779296Z/receipt.json)，io | 23 | 23 / 0 | 624 |
| [110241975424Z](runs/20260906T110241975424Z/receipt.json)，roundtrip / restart | 2 | 3 / 0 | 59 |
| [110309704630Z](runs/20260906T110309704630Z/receipt.json)，四个中断重启 | 4 | 4 / 4 | 68 |

独立只读复核已逐一核对五份汇总收据哈希、全部运行源码和副本哈希、报告/manifest/PID 关联、四个 checkpoint→reader 引用链，以及磁盘上四个受控路径的长度/摘要/存在状态，均吻合。原先两次空字节 ERROR 的失败日志与 incomplete 收据保持原样，不因修复后的通过而改写。核查细节和接入边界见 [独立审阅](review.md)。

runner 建立无 Autoload 的极小私有项目，只复制原稿与两个 QA GD 到已核对的相对路径，配置和所有 fixtures/profile 放本 scratchpad 内；子进程 APPDATA/LOCALAPPDATA 指向新私有目录。没有 Battle、Art、Music、玩家 settings/campaign 等启动副作用，也没有大量复制/导入资源。启动器保留完整日志、准确子进程退出和每步产物摘要，不把 Godot 编译/脚本 ERROR 当预期通过。

夹具 validator 只验证一个明确的小假 payload（例如 `kind=disk_fixture, revision=十进制字符串, marker=固定字符串`，精确字段集合），明确不覆盖生产实体 schema。用于验证 Callable 真被调用，不代表完整业务协议已实现。故障注入只在 QA 子类覆盖窄的 `_write_new` / `_read_raw` / `_move_to_empty` 接缝，正常路径继续调用 super 使用真实磁盘；不新增通用文件系统框架。

| 组 | 最小动作 | 必须记录的结果 |
| --- | --- | --- |
| 写读正控制 | 空槽写 A → 完整读取 → 再写 B；输入含中文、换行及 `9223372036854775807` 字符串 | A/B payload 字节完全一致；B 最终摘要匹配；旧槽替换一次；成功后无 pending/previous/锁 |
| 输入/封装拒绝 | 空/超长/无效 UTF-8、新 payload validator false；魔数错误、schema=2、截断、长度错误、改 payload 未改 hash；另设正确 hash 但 validator false | 每类错误码正确；原损坏/未知档始终原路径原字节；失败不产生新槽；验证器缺失/结果无 bool ok 不放行 |
| 临时文件失败 | 已有 A；分别拒绝 open、写到一半后关闭、临时回读截断/摘要失败、完整 validator 在回读阶段拒绝 | A 原字节不变；pending/锁保留；明确错误；重试拒绝残留；日志错误不能忽略 |
| 替换失败 | 已有 A；拒绝 A→previous；另拒绝 pending→slot，允许 previous→slot；再使 rollback 也失败 | 第一种 A 原位；第二种回滚后 A 原位且验证通过；第三种 A 留 previous，返回恢复未确认，三者都保留失败证据 |
| 外部冲突 | 在提交接缝改变原槽或放入未知文件，或改变 previous | 不覆盖/删除未知内容；返回 SLOT_CHANGED / unknown / BACKUP_CHANGED；不假称已回滚 |
| 最终回读/清理 | 新槽移动完成后使回读失败；新槽验证成功后拒绝删除 previous/锁 | 分别返回 unknown 或 new_verified+清理失败；回读失败时旧档留 previous，删备份失败时新旧均留，删锁失败时可能只留已验证新档；不把“新槽已落位”混成完整事务成功 |
| 真正重启 | 进程 W 写 A 并退出；确认 W 已终止，另启动 R 只读 A；再执行两次替换的各个中断点，外部终止准确子进程后新进程读取 | writer/reader 独立进程与精确源码/字节摘要；正常重启读取一致；残留中断一律 RECOVERY_REQUIRED，至少一份完整可验证的 A 或 B 仍在 slot/previous，原残留不自动删除 |

故障日志与修复成功结果分开。中断 QA 只终止被夹具启动器拥有的进程，不能按 Godot 名称全杀。所有测试文件保留在各自全新 case 目录，计划不要求操作真实玩家文件或磁盘填满。断电与真正空间耗尽不能由一个返回错误的 stub 宣称已测。

上表中当前 catalog 的 49 个具体案例已有上述实际收据；这不等于所有可能磁盘故障、生产实体协议或恢复方案均已验证。同次保存失败的受限回滚与跨进程残留拒绝已测，重启后的恢复选择/清理仍未实现。正常重启只验证写进程退出后的读取，不证明同时读写隔离、真实磁盘空间耗尽或断电持久性。

逐项命令、真实引擎参数要求和证据范围见 [QA_USAGE.md](QA_USAGE.md)。默认预检不启动引擎；旧 `handoff.json` / `qa_static_receipt.json` 是各自产生时的静态快照，不能代替新版本的运行来源收据或实际结果。
