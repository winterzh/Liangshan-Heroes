# RunStateValueCodec 验证证据（2026-09-06）

当前验收见 `current_qa_summary.json`：`runs/20260906T143634734025Z` 为 341 个非空检查全部通过、exit=0、实际 PID 13904。原始日志、报告文件、源码摘要、独立私有 user:// 与控制器退出/锁收据均已复核。检查覆盖真实 JSON 中转、类型/位/顺序保真和严格拒绝边界，不代表 341 个独立场景或战斗恢复案例。

`runs/20260906T114114538519Z` 保留为有诊断的原尝试：虽有 340 个报告检查通过且 exit=0，日志第 3 行包含 `Unicode parsing error ... Unexpected NUL character`。原 runner 没有识别该前缀；原 receipt 的 complete=true 不作为无诊断验收。`nul_fixture_fix/` 保存旧驱动字节、独立失败审阅与当时的修正准备收据。修复后的 QA 用支持的控制字符及独立输入字节 oracle，新轮经过增强日志检查；codec 原字节不变。

`preparation_receipt.json` 和 `nul_fixture_fix/receipt.json` 是当时的准备状态，未追改为当前通过结果。`promotion_receipt.json` 记录根任务将受测 codec 原字节复制到生产模块的动作。

本归档只包含白名单报告、原始日志、准备/退出收据、摘要及旧驱动文本；不包含任一次私有 project/profile、玩家数据或 Godot 缓存。全部证据按 raw 字节保存，局部 `.gitattributes` 禁用文本换行转换。逐文件摘要及三文件私有复现说明见 `tools/contracts/run_state_values_20260906/source_pins.json` 和同目录 README。

没有 Battle/Unit 调用方、完整实体 schema、引用恢复、原文 JSON 解析政策、磁盘存取或续玩界面验证。历史收据内的机器绝对路径只记录实际运行身份，不是新机器的复现路径。
