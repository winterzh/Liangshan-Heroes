# 大名府首次真实 Flow 批次失败原件

原批次 `20261027_072035_807401ae` 在 Lu-first 路线第三进程失败，宿主终态 `complete=false`。本目录完整保留本轮 10 个冻结工具/清单、5 个实际加载 worker 及 bindings、3 份原 report/log、原 receipt、闭合 A descriptor 元数据和 3 份小身份元数据。每份 raw 与对应原路径逐字核验；其余有界依赖、完整身份和原导入证据按 `verification.json` 中 24 条精确 SHA 引用既有归档，未递归复制旧工程或原导入日志。

- A / PID 43448：202/202，真实 Lu 单安全撤离后 SaveAndExit，原退出原因 `continue_saved`，slot gen1 / LC gen1。
- B / PID 40420：104/104，独立 Continue 精确恢复、120 个普通 tick 无重复 safe 事件，再次真实 SaveAndExit，slot gen2 / 同 token LC gen1。
- C / PID 28156：66/67，退出 1，无引擎错误。唯一失败为 `actual Level natural victory state`；原证据中 Shi 实体 29 HP=0、dying=true、active=false，Lu 28 保持 retreated/隐藏，营地 HP=1500。C 已恢复 gen2 后走普通护送路线，但没有成功终局。

合计 373 项，372 true / 1 false；不是累计数组重复加总。原 roles.lu.process_ids 只登记两次成功 stage，第三实际 PID 以 receipt.steps 和原 C report 为准。Lu 的拒旧槽阶段与 Shi-first 全部四阶段均未执行。三个 terminal_checkpoint 均空，没有本批 LC terminal/Intent2/ACK2/CFG 成功资格，不能当八进程、52 负例、61 阶段或 19 类故障通过，也不能因此宣称生产恢复代码存在缺陷。

原收据的初/后完整身份、自有子进程终态、lane 空闲、锁归属及释放均 true，cleanup_errors=[]。本归档没有重算全部 546 pins 或资源树，记录该事实与实际有界核验范围。导入本来使用缓存种子，不能从这批继承冷导入资格。

A descriptor 的路径、nonce、token 和业务文件 SHA 保留用于追溯，但 **未读取或复制**实际 Slot/LC 内容及 profile；没有复制 EXE、DLL、缓存、IPC 或玩家载荷。原报告仅按授权原字节保留其 QA 观察与 typed checkpoint。原报告若有非有限诊断值保持原文；summary 是明确派生的有限字段摘要。没有 controller 原件就不编造。

本目录只做失败证据归档，不运行引擎、不修改候选、不回填原收据、不重演玩法。后继策略或源修正不得覆盖本轮工具 SHA 与失败。
