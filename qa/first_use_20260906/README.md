# 首次使用诊断证据

本目录按字节封存4baafc1私有副本的准备、导入及完成运行 `20260906T112637549233Z_timed`。40份原始/派生证据共6,440,284字节，文件映射与SHA见 [archive_manifest.json](archive_manifest.json)。不含私有工程、profile、测试缓存或引擎；本机绝对路径仅用于追溯历史，不是跨机器可用的执行路径。

- [原始报告](runs/20260906T112637549233Z_timed/report.json)与[完成收据](runs/20260906T112637549233Z_timed/completion_receipt.json)：375事件、sample 85事件，来源及实际子进程退出检查通过。
- [V2分析](runs/20260906T112637549233Z_timed/first_use_analysis_v2.json)与[范围修正](analysis/first_use_analysis_v2_review.md)：完整postdraw区间127/41与M1全样本128/42分别报告；sample去重首次工作515108µs，嵌套248ms不双算。旧分析与原始文件保持。
- `preparation/`保存来源计划、静态检查、先前准备拒绝与工具；`imports/`为完整私有导入日志/收据；`mirror_receipts/`仅保存物化及导入后来源摘要。`generated/`中的实测GD和配置均为文本，不在本工程执行。

这是短时插桩归因，不代表正常产品FPS或可保证节省的加载时间；资源方法墙钟不等于纯磁盘I/O。完整解释和后续候选取舍见 [实现说明](../../docs/FIRST_USE_20260906.md)。
