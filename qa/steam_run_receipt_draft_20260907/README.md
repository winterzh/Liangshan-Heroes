# 持久局回执候选 QA

Godot4.6.3极小隔离项目，真实Steam禁用。成功批次为`20260907T062516Z_aa40ed01`：88模型检查及七个独立夹具进程合计45检查通过。所有进程退出0，私有用户路径实测正确，真实玩家和源码前后守护通过，共同锁已释放。

- `attempt_1_fixture_comparison_failed/`保留首次夹具比较失败。模型88项通过，恢复阶段只有整数规范化值与JSON浮点值直接比较这一项失败，后续三阶段未运行。
- `attempt_2_passed/`从全新profile和夹具完整重跑。修复测试为模型前后值及磁盘原字节分别不变，纯模型源码没有变化。
- `archive_manifest.json`逐项固定42个原始日志、报告和执行时源码输入；`summary.json`分别记录两次实际进程，不把重复或失败检查累加为通过数。
- 固定草稿和runner位于`tools/contracts/steam_run_receipt_draft_20260907/`，按原名恢复才能复现。

夹具只做flush/close后正常进程退出；不是真实断电、不包含原子文件替换、生产保存入口或Steam账号调用。result8回调收到到失效记录落盘之间的宿主窗口仍未解决。详见[专项说明](../../docs/STEAM_RUN_RECEIPT_DRAFT_20260907.md)。
