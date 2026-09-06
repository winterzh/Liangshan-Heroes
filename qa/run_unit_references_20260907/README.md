# Unit 引用/命令队列：162 项实际验证与原始失败

通过轮为 `runs/20260906T160052202189Z`，PID 42344、exit 0、162 条检查全部真。12 条为六源前后 SHA，150 条其余断言包含辅助检查。完整功能范围与实际修复见 [项目说明](../../docs/RUN_UNIT_REFERENCES_20260907.md)。

原轮 `153930613198Z` 与只加诊断轮 `155758109217Z` 均为 19 条后失败、exit 1，保持失败。`fix_default/` 封存第一轮原文和窄诊断候选；`fix_string_keys/` 封存诊断轮原文、五处 String 键修复及四条回归。旧 pins 的 NOT_RUN 状态只代表生成该文件时的状态，不改写为实测收据；当前结论以新 run 为准。

`draft/` 为最终受测适配器、QA、字段合同和原准备说明；`frozen_dependencies/` 是当时七份 pin 依赖（包含生产源原文、Unit 值草稿、字段表与续玩 schema 草稿）；`frozen_controllers/` 保存实际 controller、lifecycle、两个公共 helper 和根任务准备脚本。controller 的旧静态 preflight 也保留原身份，不作为新版已测证明。

仅在独立兼容 checkout 中恢复复验。确认目标路径不存在后，把这些 .txt 原文恢复到清单所示原路径：Unit 引用草稿位于 `scratchpad/run_unit_references/`，Unit 值依赖/字段表与 schema 草稿按 pins 的 `source_files` 放置；原准备 README 必须用 `draft/README.md`，不是本说明。生产源和公共 helper 必须先与冻结 SHA 匹配；不覆盖其他任务正在工作的源码。完整已导入的 Godot 工程及其 QA 合同仍是前提，这不是独立小项目。

配套 controller 与 contract 恢复到 `scratchpad/run_resume_adapters_qa.py` 及其 `.contract.json`，lifecycle 恢复原 `scratchpad/run_unit_state_adapter/run_qa.py`。默认 `--suite unit-references` 只预检；根任务确认无其他 Godot、取得共用锁后，才使用本机配置的真实非 console 引擎加 `--run`。每次创建新 run 和私有用户目录，保留受测代码、原记录和玩家数据。

83 个原始文件共 3,190,240 字节由 archive_manifest 固定；后续独立摘要与本说明单列。所有实际 profile、缓存、引擎与导出包均排除。该适配器从未给 Unit 赋回引用，没有创建跨进程身份或整局恢复，所有成功报告仍为 restore_ready=false。
