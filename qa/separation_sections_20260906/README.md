# 兵群分离内部诊断：2026-09-06

这份证据来自冻结提交 `4baafc11af55b0e46a57a48e54df181b8c1917a2`，用于选择后续实验。没有新的生产优化或性能门槛通过结论。结果、窗口含义和取舍见[物理成本说明](../../docs/PHYSICS_COST_20260906.md)。

- `completed/receipt.json`：20260906T110413889769Z两场10秒窗口完成，锁已释放；生产11文件与真实玩家配置/章节摘要前后相同。
- `completed/timed/analysis.json`：586物理步，建桶204.841μs、逐对求解1793.343μs/步；不是600步窗口。
- `completed/clockless/analysis.json`：528物理步，无分段计时；它仍有记账成本，不是零开销对照。
- `completed/`：完整原始帧与物理账本、共同时间关联、导入及最终源码/缓存清单。清单记录缓存身份，不包含缓存文件。
- `failed_import/`：原300秒导入超时与真实进程退出收据；不计性能样本。
- `tool_sources/`、`generated/`、`frozen_sources/`：实际准备/运行/分析代码、模板和原文；GD以文本归档。
- `tool_sources/resume_metadata_readonly.json` 等：1182份已有.import精确CRLF→LF变化与限定UID新增政策的审核证据。
- `archive_manifest.json`：75份原始证据、7,535,092字节的raw SHA。另有本说明、`.gdignore`、局部`.gitattributes`和归档清单。

不复制私有工程、590MB冻结tar、fixture/profile、玩家文件、导入缓存或引擎；原报告中的绝对路径只记录当时现场。原工具仍以当时scratchpad布局为前提，不是另一个可直接执行的公共入口。归档保留原始字节和失败，不应改写旧收据以让复现通过。
