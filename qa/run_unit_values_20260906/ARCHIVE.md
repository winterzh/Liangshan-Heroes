# Unit值层实测草稿归档

21份原字节文件共552994字节，映射与SHA见 [archive_manifest.json](archive_manifest.json)，原白名单见 [archive_plan.json](archive_plan.json)。[独立摘要](current_qa_summary.json)核对实际77项检查（12来源、65其余），54个不同label；辅助JSON/负例准备断言会重复，不能当作77个独立场景。

`runs/20260906T150602925243Z/`保存原始报告、日志、进程收据、manifest、配置和来源清单；`draft/`封存实测适配器、QA、runner、冻结pins、完整字段分类、准备历史及静态检查。根`.gdignore`按原1字节保留，GD/IN追加`.txt`后缀；不包含私有用户目录、玩家文件、缓存或工程资源副本。

需要复验时，在另一份已正常导入、Unit和codec源码摘要与pins完全匹配的checkout中新建此前不存在且被忽略的 `scratchpad/run_unit_state_adapter/`。从`draft/`按原名逐字节恢复文件；仅GD/IN移除归档追加的最后一个`.txt`，将根`.gdignore`复制到该草稿目录。校验pins与runner_contract，不直接从QA归档执行脚本，不重新生成或重锁摘要。

QA仍显式加载 `scratchpad/run_state_value_codec/value_codec.gd`。若该路径不存在，可在新的被忽略目录按此名字复制已测生产 `scripts/run_state_value_codec.gd`，先验证raw SHA为c8c4a58d1e68e22abb9f8b1abcb1a9cc1dbaa486e51ea5174dd16984aaa35d15；不要放入三文件codec QA的小项目配置。本测试需要完整生产工程和Autoload。

`prepare.py`依赖另行保留的 `scratchpad/defense_resume_schema.md`，属于历史离线生成工具；复验只恢复已测产物，不运行prepare，也无需复制该索引。默认 `python scratchpad/run_unit_state_adapter/run_qa.py`仅核对来源；主任务取得共同Godot独占后，使用 `--run --godot <实际非console引擎>`运行。它新建隔离APPDATA/LOCALAPPDATA/TEMP/TMP，严格核对实际PID、来源、user目录、非空报告、错误日志与退出，不修改生产文件或复用玩家存档。

来源或换行字节不符合冻结pins时先停止核对，不修改pins把另一个版本冒充本次复验。所有成功仍为`restore_ready=false`；未setup、未入模拟树的Unit值层检查不等于完整战斗恢复。详见 [实现与下一步](../../docs/RUN_UNIT_VALUES_20260906.md)。
