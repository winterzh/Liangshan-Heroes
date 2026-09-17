# 稳定编号生产接入 QA

本批接入25份脚本，与`accepted_sources/`逐字节一致，生产复制收据为`production_promotion.json`。起点Git提交c663afc；本批原生测试在完整私有工程覆盖明确候选，未在玩家目录测试。

- `world_matrix.json`及`runs/defense30`、`runs/level1`至`runs/level8`：9个正常开局案例均通过，每例独立进程、私有profile和原始报告。包括14秒真实付费生产与连环马两次真实任务替换；不是完整通关。
- `runs/defense_bridge/`：45项行为、1项私有路径、5750次前后源码SHA检查通过；覆盖两类ID碰撞、精确大整数和末波状态继续消费。
- `frozen_packages/`：真实驱动、25文件桥接与24文件世界清单、原冻结SHA和准备说明。旧身份86项行为和首次入口失败位于相邻`qa/stabilization_identity_20260907/`。
- `archive_manifest.json`：122份执行证据与候选的原始路径、大小和SHA；私有工程缓存、测试profile和实际玩家文件不归档。`.gdignore`阻止引擎扫描这些源码副本。

`summary.json`拆开源码摘要和其他检查数；其他检查还包含目录/模式等守卫，不全部称为玩法行为。每份正式报告保留准确scope。9例均至少120实际Battle物理回调；未进行完整30波、战役胜利、跨进程整局恢复、最终性能、PCK或真人验收。

复现需以原基线及冻结清单重新建立独立候选，使用`tools/run_stabilization_overlay.py`；不能直接在此归档内运行，也不能把当前生产v2当作旧before继续套旧清单。原调用命令、实际runner和依赖快照在各run中保留。详见[接入说明](../../docs/STABILIZATION_IDENTITY_INTEGRATION_20260907.md)。
