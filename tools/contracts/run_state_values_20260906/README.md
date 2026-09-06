# RunStateValueCodec 三文件私有 QA 封存

本目录封存测试原文，用于一个没有 Autoload、Battle 或游戏资源的极小私有项目。生产模块路径为 `scripts/run_state_value_codec.gd`；晋级只换路径，不改 `value_codec.gd` 的被测原字节。文件/报告来源摘要见 `source_pins.json`，通过范围和原 NUL 诊断失败见根工程 `qa/run_state_values_20260906/`。

当前验收为 `20260906T143634734025Z` 的 341 个检查、exit=0，原始日志通过 Unicode/Parse Error 等诊断检查；独立复核同时核对实际 PID 13904、私有 user://、三份源码和报告摘要。原 `20260906T114114538519Z` 虽有 340 个报告检查通过，但包含 Unicode 诊断，继续作为失败尝试封存。

| 封存文件 | 私有项目恢复名称 |
| --- | --- |
| `value_codec.gd.txt` | `value_codec.gd` |
| `qa_driver.gd.txt` | `qa_driver.gd` |
| `project.godot.txt` | `project.godot` |

三个文件必须在同一个全新私有项目根目录。QA 显式加载 `res://value_codec.gd`，所以不能只把晋级文件的 `run_state_value_codec.gd` 名称原样复制进去。若从生产模块取源码，先验证它的 raw SHA 等于本封存 pin，再用私有项目名称写入。不能悄悄重锁新 hash、用旧 QA 配新模块或原地覆盖既有实验。

封存 GD 和 Godot 配置都以 `.txt` 保存，配合 `.gdignore`，不会在原生产工程被自动加载；局部 `.gitattributes` 使用 `-text` 保留原始字节，避免跨机器 checkout 换行改变来源。只恢复三份来源，不复制历史 private_profile、旧 project、报告残留或 `.godot` 缓存。

## 复现步骤

1. 从根源码 checkout 新建一个明确被 Git 忽略的 `scratchpad/` 子目录作为私有项目。目录已存在即停止，使用另一个新名字，不删除、覆盖或复用。先核对三个封存文件的字节数和 raw SHA 与 `source_pins.json` 一致，再按上表逐字节恢复原名。
2. 根任务取得 `.godot/redraw_rejection_source.lock` 的共同独占时段，确认没有其它 Godot。调用实际 Windows Godot 4.6.3 引擎程序，拒绝 `.console.exe` / `_console.exe` / `-console.exe` 转发器；由持有的真实子进程句柄处理退出、超时与中断，不能按名字批量结束进程。
3. 子进程 APPDATA、LOCALAPPDATA 指向本次新私有 profile；保留父进程环境，不接触正常玩家存档。设置 `VALUE_CODEC_QA_OUT=res://qa_report.json` 可输出文件；该文件必须不存在。使用以下命令参数，运行控制继续复用根任务已有的小控制器，不新增公共 runner。

```text
<actual Godot exe> --headless --path <new private project> --script res://qa_driver.gd
```

4. 不能只读 passed：核对非空 `checks[].passed`、check_count、failures、实际 PID、三份 `source_raw_sha256`、实际 `actual_user_dir` 与独占控制器期望目录；退出必须确认且正常为 0。日志除了 SCRIPT ERROR/ERROR/WARNING/FAIL，还必须检查 `Unicode parsing error`、`Parse Error` 等非标准前缀。完成收据、原始日志和来源摘要留在本次 scratchpad，不覆盖本封存历史。

QA 的正例执行真实 JSON.stringify/parse 中转并做类型/位/顺序检查。非法 Object/Resource/Callable 或循环结构不能先 stringify，因此这些拒绝例直接传入有界 codec；不将这两种入口混淆。

原驱动尝试 `String.chr(0)`，Godot 在 codec 收到值以前将其替换并打印 Unicode 诊断；原 340 检查通过收据不能据此算日志全绿。修复仅换用受支持的控制字符，并在 encode 前增加独立 UTF-8 字节 oracle。codec 无法恢复输入前已经替换的数据，任意 JSON 原文的 NUL/重复 object 成员/字节上限政策仍由上层负责。

本模块只是值编码工具：没有 Battle/Unit 调用方、实体 schema、引用图、RNG/计时器快照、场景恢复、磁盘事务或继续按钮。封存 QA 的通过不等于真实战斗续玩通过。
