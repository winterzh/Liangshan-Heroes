# 高俅 Session：768 完整候选准备入口

本文件记录工具准备时状态：**仅代码和轻量静态检查，未执行完整准备、未创建新冻结、未导入、未运行高俅路线、未采用生产**。既有连环马、classic、readset 或旧 d7 的验证不转授这个组合。父目录的单文件候选与来源记录保留原样。

本入口固定以 `20261027_034810_ed1bdef8` 为底，身份 `source-v1:768b6e5937321126b4c927fce6b5565459610aa13ccb556f695837a814eb74c2`、23 脚本清单 SHA `11c1d813daab8fd9eeaa0e8ed7569deb33da3af243b429c9cffc69c6de74a5e6`。完整源只替换 Session 为父目录原有 `420b5936…` 字节；768 的 Session 仍是与 d7 相同的 `fbea69f2…`，不需要重写补丁。其余 22 项、原 Store `f222e8b3…`、完整资源和固定 native helper 均保持原来源。

改动仍只有固定 Level5Factory preload 与严格 `Profiles.GAO_CONTEXT` 分支：在现有存档/身份/LC 准入后、Core.prepare 前，调用现有工厂装配受信 runtime。旧 Core 仅在工厂成功后释放。没有费用、人口、时间、合同、存档数据、context 准入或公共入口变更。源码已显示通用 runtime 缺少章节装配；**高俅的实际运行影响尚未复现**。

从工程根目录调用：

```powershell
# 轻量只读：核指定元数据、补丁及少量相关源，不扫描整个工程。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/integration_768/prepare_gaoqiu.py

# 以下留待根线程串行安排；本轮未执行。
# 全量只读：完整来源、768 自身导入、全部文件及 helper 验证。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/integration_768/prepare_gaoqiu.py --full-preflight

# 全量核验后只新建独立冻结；不启动 Godot。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/integration_768/prepare_gaoqiu.py --prepare

# 根线程另做该新冻结的独立 import，随后才可检查执行准入。
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/gaoqiu_continue_candidate/integration_768/prepare_gaoqiu.py --check-run <新冻结目录>
```

默认输出明确为 `metadata_and_named_sources_only`、`full_source_verified=false`，不能传作运行资格。`preflight()` 复用 readset 的完整 `prepared_state(768)`，递归核原来源、native helper 的源/构建收据、原完整生成身份和独立 import。`--prepare` 从该已核完整冻结逐文件复制 7062 项，只替换 Session；独立重建 derived identity，完整比对目录集合和全部字节清单，保留准备输入与失败收据，不覆盖旧目录。复制的导入缓存仅是缓存种子，不是新导入资格。

后续驱动只能调用本文件的 `prepared_state(new_run)`：再次验证完整来源与固定组合、该次准备收据、生成身份和所有文件，以及**新冻结自身**的实际 PID / 正常退出 / 日志 SHA / 已释放共享锁的成功 import；旧 768 import 不能替代。完整准备与检查会大量读盘，应由根线程安排在当前 3 秒协议测量之外。本工具不获取或使用引擎通道，也不提供引擎启动功能。

下一片自然高俅保存/恢复驱动尚未实现：必须另绑本入口返回的新 `run_base/project/generation/content_version`，使用正常造船命令、真实费用与人口、同槽实际 SaveAndExit / 独立 Continue、正常完成和防重复证据。最终胜败、旧槽拒绝、SDK、公开入口与原版键鼠资格分别按实际执行另记。
