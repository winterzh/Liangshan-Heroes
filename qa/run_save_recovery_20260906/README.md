# R01 只读恢复候选检查

2026-09-06。本目录为第一步 R01 的独立磁盘草稿，已由 root 在 Godot 4.6.3 私有 headless 项目实测通过，并完成独立只读复核；运行收据为 `runs/20260906T113756778956Z/`。不修改已测/待归档的 `../run_save_store/`、生产源或玩家目录。没有 journal、恢复移动、删除、清锁、UI 或 Battle codec。

`store_original.gd` 为 `86619f5cbf87e984ed253d66dddf2b852c8e11fe5e34d256c5a463bef16abca3` 原字节；`store_r01.gd` 由这段完整前缀与 `inspector_methods.gd.in` 相接。原磁盘方法一字不改，新两接口不会调用原写入方法。`prepare.py` 检查原摘要、精确前缀和新增方法无写入/移动/删除调用，再生成 pins。该静态证据不替代 GDScript 编译或真实文件行为。

## 接口与身份

- `inspect_recovery()`：沿用已有 fixture 目录边界和完整 validator，递归读取固定 S/T/B、锁目录及所有未知条目；包含隐藏文件、未知子目录与空目录。坏文件与未知版本仍列出叶名、文件 SHA 和失败码，未通过业务验证的内容不成为可用候选。检查只返回身份与验证状态，不返回 payload 或业务预览字段。
- `read_candidate(candidate_id, inspection_id)`：先完整重新检查目录，匹配旧 inspection_id；候选必须来自检查生成的固定 S/T/B 清单，再重开选定文件并完整验证，最后再次完整检查目录。变化则拒绝并要求刷新；成功仅返回这次复验的精确 payload，不表示正式槽已安装、锁已清理或战斗已恢复。

candidate_id 是版本标记、**叶名与完整原文件 SHA** 的摘要，相同文件内容位于 S/B 时身份不同。inspection_id 包含实际规范化 fixture 目录、每个相对路径的文件/目录类型、文件长度与完整 SHA；不依赖 mtime、文件名排序推测新旧。两个不同目录即使内容相同也不能共用 inspection_id。调用者只提供不透明 ID，不能提供候选路径。

状态区分 `CLEAN_SLOT`、`NO_SLOT`、`CANDIDATE_AVAILABLE`、`NEEDS_CHOICE`、`NO_VALID_CANDIDATE`。只有空锁时为 `NO_SLOT + recovery_required=true`；单个有效候选伴随残留为 `CANDIDATE_AVAILABLE`，绝不是清理成功。I/O 失败、路径失败、链接、预算超限、两次观察变化均为失败，不给出可使用的部分 inspection_id。

根祖先和固定叶沿原 `_guard` 检查，未知目录/文件在打开前检查链接。在已核对的 Windows Godot 4.6 实现中，`is_link` 检查 reparse 属性，涵盖 junction；见 [官方实现](https://github.com/godotengine/godot/blob/4.6/drivers/windows/dir_access_windows.cpp#L406)。扫描限制为 256 个条目、8 层子目录；单文件沿原 MAX_FILE_BYTES，累计至其四倍。未知大文件或深树不会被省略后继续提供候选。

多次完整观察相同不证明期间从未改变，也不提供跨进程独占或原子快照。固定叶 raw SHA 是本步所需的内容身份，不是文件系统 inode 身份或真实性签名；SHA 相同也不证明“最新”。validator 必须保持原合同要求的同步、确定、无 I/O/RNG/场景副作用，否则只读性不成立。没有清锁动作，不能因拿到 payload 而绕过现有保存残留。

## 最小真实 QA 与启动

```powershell
python scratchpad/run_save_recovery_v1/prepare.py
python scratchpad/run_save_recovery_v1/run_qa.py
# 只准备三份 GD + 无 Autoload 项目，不运行引擎：
python scratchpad/run_save_recovery_v1/run_qa.py --prepare
# 仅 root 取得共同独占后执行，明确提供实际非 console.exe：
python scratchpad/run_save_recovery_v1/run_qa.py --run --godot "<本机真实 Godot.exe>"
```

`--run` 新建极小私有项目并运行单个 headless 子进程，默认 120 秒上限；拒绝 console 包装器。`process_runner_original.py` 是已测 `233dcd47…` 原 runner 的精确副本，本入口只复用其中的 `run_process`/独占/退出确认/私有环境助手，不运行旧 catalog。共同锁仍为根工程 `.godot/redraw_rejection_source.lock`；未确认退出或来源冲突时保留锁。各次日志、manifest、报告、来源与退出收据保存在新的 `runs/<UTC>/`，不删除历史结果。

新私有项目不加载任何生产 Autoload，APPDATA/LOCALAPPDATA/TEMP/TMP 仅指向本次 private_profile。GD 启动时核对真实 user://，前后检查四份私有可执行源。输入路径仍为该私有项目的 `res://scratchpad/run_save_store/fixtures/<case>`，没有更改原 fixture 边界来访问玩家目录。

`qa_driver.gd` 通过原 store 的真实保存得到 A/B 封装，然后仅在自有 fixture 布置 S/T/B/L。覆盖干净、无槽、空锁、有效槽加锁、三个候选、相同内容不同叶、正确 SHA 但业务拒绝、未知 schema/format、无效 UTF-8、零字节、候选 raw 改变、隐藏未知项新增、嵌套锁文件改变、删除候选、不同目录相同内容、深度预算拒绝、越界和缺失目录。每次真实 inspect/read 前后对比独立文件清单，Python 再读取各夹具最后记录对应的实际文件验证。没有把 API 返回的 `read_only` 布尔当作无副作用证明。

条目预算在收集名称时即检查已见 entries + names，超过 256 就结束枚举并失败，避免先分配无界名称数组；QA 包含 257 个直接子项的拒绝夹具。

本轮结果为 **1625 条断言通过、0 失败**，包括 1232 条目录快照打开/枚举检查、257 条宽目录布置检查和 136 条其余来源/布置/行为检查，不能计作 1625 个独立功能。共记录 29 次带独立前后快照的只读调用（18 次 inspect、11 次 read），对应 13 个受检 fixture；另外 1 个 oracle_b 目录仅通过原 store 生成 B，还有 2 次越界/缺失路径拒绝检查不在快照 records 中。

独立复核重新读取了全部受检 fixture 的最终实际路径/类型/字节长度/SHA，与最后记录逐项相等；29 次调用各自的前后快照均相等。复核还重算了 16 个完整 inspection_id 和 19 个候选身份，检查原始源码、私有副本、manifest、PID 26940、实际 user:// 与进程退出来源。真实 exe 正常退出 0、退出已确认、无日志错误、无强制中断；receipt 的 complete 和 lock_released 均为 true。深度与 257 项预算拒绝已实际运行通过。

`pins.json` 和 `preparation.json` 的 godot_run=false / gdscript_parse_or_runtime_verified=false 保留的是**准备阶段**事实，未为这次运行改写；本次执行事实以 `receipt.json`、`report_process.json`、`report.json` 和 `report.log` 为准。独立结果摘要见 `result_summary.json`，范围与交接见 `handoff.md`。

真实权限失败/链接、超大文件与并发 ABA 尚未有本轮运行夹具。快照验证路径、类型与内容，不断言访问时间不变。原 store 的 49 案例仍是上一草稿的独立证据，不能转记为本新增方法通过。生产接入仍缺恢复事务、明确选择与清锁流程、真实状态 codec/完整业务 validator、暂停采集和新场景恢复。
