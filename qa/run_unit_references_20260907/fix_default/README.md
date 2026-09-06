# 首次默认采集失败：原文封存与窄诊断候选

原运行 `../runs/20260906T153930613198Z` 是真实失败：PID 11812、退出码 1，19 个检查中只有 `default values plus reference layer capture` 为 false，随后原 QA 按现有逻辑早退。源码/玩家/实际退出/锁释放检查通过，日志没有引擎诊断。**这 19 个检查不是完整引用 QA，也不会因后续换源或重跑改写成通过。**

`seal.json` 将 6 份原源码/合同/旧预检收据与 7 份失败运行文件逐项绑定原始字节 SHA。`original/` 和 `failure/` 是精确副本；源目录和历史运行均未改写。封存包含当前引用 adapter、QA、pins、共享 controller/contract/preflight。Inventory 没有改动。

现有报告没有保留 `capture_unit` 的返回 `code/path`，仅凭布尔失败不能确认是值层、注册表、引用形状、codec 或来源合同哪一支。磁盘上的三份 LF SHA 与常量一致，不足以替代实际加载后的源文本与返回码。本轮没有猜测性修改 adapter。

`candidate/qa_driver.gd.txt` 只增加 `result_evidence`：实际加载 Unit/codec/值适配器的 LF SHA，以及 default/all-fields/mixed 三组 capture/validate 的 `ok/code/path/field/restore_ready`。不序列化 Node、注册表或失败 record，不改生产输入、检查表达式、成功条件、早退分支、原采集调用次数。检查调用数量仍与原稿一致；若同一点继续失败，报告应仍失败并给出 `default_capture` 分支证据。

`candidate_manifest.json` 和 `diagnostic.patch` 描述根任务可集成的三项：QA 候选、引用 pins 候选、共享 controller contract 候选。pins 明确标为诊断候选并引用原失败报告 SHA。adapter 和共享 controller 源码保持原字节；Inventory suite 的 pin 保持原值。没有对 live 文件应用这些候选，没有运行 Godot。

下一步由根任务核对每个目标的 before SHA，结束其它 Godot 后应用三份候选，再用原小控制器运行一个全新 `--suite unit-references --run`。保留新失败或成功报告原文，先读 `result_evidence` 定位真实拒绝原因，再决定最小语义修复。这里没有另设宽松启动器、绕过原严格日志/来源/PID检查或重标旧运行。
