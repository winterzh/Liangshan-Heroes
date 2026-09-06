# Unit 主体四段诊断原始证据

冻结 4baafc1 私有工程的实际 generation `20260906T153209698572Z` 完成导入、timed/clockless 各 10 秒；运行退出、来源和私有路径核对通过。详见 [四段独立复核](generation/independent_review.md) 与 [项目物理成本](../../docs/PHYSICS_COST_20260906.md)。81 个按清单复制的原始文件总计 8,668,862 字节；本说明与生成的清单/忽略属性不计在原始文件数内。

`generation/` 保存三次实际进程、原始 M1/逐步数据、源/缓存元数据、前置三份小型备份、最终收据及独立复算。初始 receipt 的 `full_offline_analysis_pending=true` 是当时状态，保留不改；后续 `analysis_receipt.json` 和独立审阅明确完成分析。

`tool_sources/` 保存生成器、驱动、ledger、同钟分析器、复用计划和受测输出；GD 用文本名并设置 .gdignore。`frozen_source_contract/` 是 pins 指向的 11 份原始小型源码，raw 字节完整保留，文件名再加 .txt。原完整私有工程、引擎、实际玩家内容和 Godot 缓存不在归档内。清单中的 source 路径仅表示本轮来源。

复现必须另外建立相容的 4baafc1 私有工程；不能直接从本归档执行 run_generation.py。该 runner 的复用前提是原分离诊断完成后的精确 3302 源/2376 缓存清单，本机那个私有工程现已进入本代 3306 源，不能再次套用旧前置条件。新复现应建立新代计划、重新验证前置身份并使用新的运行目录，不能改旧 pins/清单或覆盖原 generation 凑通过。原分离阶段证据在 [先前归档](../separation_sections_20260906/README.md)。

计时含探针成本；clockless 的 -1/null 表示未测时间，不能相减为开销。最后一段还含命中与 watchdog，不是纯绘制。此结果只决定下一步归因，不计作普通版帧率、优化收益或性能门槛通过。
