# 独立 Steam Store 集成候选

本目录精确包含 20 个候选脚本。19 个与 `handoff_candidate` / `20261026_194542_27c8aea9` 的 `source-v1:23c0b07fcba83a9d7938ed338a9775559b6041be61d048db619c31fd5edc2a80` 原字节一致，仅 `scripts/steam_receipt_store.gd` 换为本目录上层的 unique cleanup 候选。

`manifest.json` 逐文件记录当前生产基线、上版候选 SHA、本候选 SHA；绑定上版 manifest `21bfaa75b281b41a09586338a218cb9203977abe806ecd056879be3734687f4b` 和完整生产 snapshot。revision 独立，上版的 99 模型、I/O、战役或 classic 结果仅属来源，**均不转授本候选**。

目前只完成复制及静态核对，未 Godot 编译、未模型运行、未原生 I/O、未采用到生产。新释放协议范围及未修窗口见 [上层说明](../README.md)。它不能授予 CFG/LC/Steam 整条事务完整恢复资格。

本修订 `first_commit_stale_cas_release_v2_20261026` 仅继续修正 Store 首次 `commit_locked` 的写前 CAS_CHANGED→自有锁释放分支。上一集成清单 `8ba0e38c28f83cd8b255bfba1830f4e1eed575ab5da1b04182941332b4792fe2` / Store `199c4f925f3e9d054b50571744d74d14fcf66425d9eade9c95448a682854a864` 保留在独立 evidence 及未导入冻结 `20261026_210350_189c0290`；新清单明确链接上一修订，不覆盖旧证据。此缺陷仅静态确认，修复尚未原生运行。

后续由主线程串行使用现有 `prepare_handoff.py --candidate qa/campaign_progress_recovery_20261026/store_protocol_candidate/integrated_candidate` 新建冻结，再走现有导入流程。不要以旧 `23c` 工程直接运行新模型；独立 runner 会拒绝清单不匹配。运行契约见 [MODEL_RUNNER.md](../MODEL_RUNNER.md)。
