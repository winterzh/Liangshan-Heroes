# Inventory 局部值 QA 记录（2026-09-06）

`runs/20260906T154102953512Z` 为真实 Godot 4.6.3 测试，PID 42016、exit 0，155 个检查行通过，严格日志检查无错误，源与锁收尾通过。155 = 10 个逐文件来源检查 + 1 个来源聚合检查 + 144 个其余断言行；其余断言含 JSON/负例准备辅助检查，不等于 144 个独立案例。

原始证据见同目录 runs 下的 report.json、process.log、process_receipt.json、receipt.json、configuration.json、manifest.json、sources.json。report.json 是从该轮私有用户目录单独提取的指定 QA 输出；receipt/configuration 里的历史绝对路径按原文保留，不要求归档目录中仍有该路径。未归档其他用户配置或私有目录。

current_qa_summary.json 记录逐项复核和来源摘要；evidence_review.md 解释计数、验证范围及限制。preparation 下保留受测准备期 README、pins 和 preparation_receipt 的原字节，其中“未运行”描述是历史状态，未被回写成后来的结果。

这证明实际 HeroInventory 的五个局部值可显式捕获、经真实 JSON 中转后严格验证。没有实现赋值恢复、owner/效果引用、业务物品定义、全局 UID 分配器、Battle 或磁盘接入；不等于完整续玩，也不是性能验收。测试原文与复现依赖另存于 tools/contracts/run_inventory_values_20260906。
