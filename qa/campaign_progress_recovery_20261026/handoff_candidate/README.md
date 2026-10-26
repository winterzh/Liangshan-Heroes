# Steam 持久交接候选

独立20文件候选已修复结算凭据/账本JSON读回、旧局尾账和纠正后启动合并三类问题。当前冻结`20261026_194542_27c8aea9`导入成功，99项纯模型、纠正/尾账逻辑回归、13阶段文件专项及黄泥冈两进程1386项检查已完成；实际源码身份为`source-v1:23c0b07fcba83a9d7938ed338a9775559b6041be61d048db619c31fd5edc2a80`。它是14文件候选之外的新版本，正式源码未采用。

目标与接口见 [交接设计](../STEAM_HANDOFF_DESIGN.md)：同一gen2 intent先完成CFG和同token Steam本地终局回读，再写gen3。实现包含严格v2历史读取、显式v3账本升级、同对象原proposal重试、账号纠正epoch、发布前启动检查和无Battle恢复；战役展示不再二次调用通用settle。

两个原生编译失败保留：`20261026_185359_deec57f1`发现const数组相加写法不受支持；`20261026_190219_ffe6572f`发现旧档profile_id需显式String类型。原已导入811版本的75项模型、135项训练只覆盖该旧源；扩展99项检查实际发现7项失败，分别落在LC凭据和Receipt JSON回读。旧源的成就重解锁与Session尾账丢失也已由独立模型复现。修复后另冻，没有改写原失败工程。

- [当前99项模型及新导入收据](../evidence/handoff_model_fixed_20261026_195458/summary.json)、[逐文件证据](../evidence/handoff_model_fixed_20261026_195458/manifest.json)。
- [旧源99项/7失败](../evidence/handoff_json_receipt_failed_20261026_194345/receipt.json)、[两个逻辑缺陷成功复现](../evidence/handoff_regressions_defects_20261026_194925/receipt.json)。复现成功不等于候选验收通过。
- [被修订四脚本的原811字节](../evidence/source_revision_811c0a12/manifest.json)；其余16脚本可依旧manifest与当前候选核对。当前逐文件清单见[manifest](manifest.json)。底座初始32项静态报告描述其当时SHA，不替代当前运行证据。

外部纯模型、独立尾账/纠正回归、真实文件I/O、经典30波驱动分别在`tests/`、`tests/regressions/`、`tests/io/`、`tests/classic/`。新源尾账/纠正回归通过（8项宿主、14项Receipt、27项Session；内存Ledger夹具），[原始收据](../evidence/handoff_regressions_fixed_20261026_195508/summary.json)；实际I/O已完成[9案例/13阶段/178项断言](../evidence/handoff_io_20261026_200759/summary.json)，其中两类残留按预期拒绝；同版[黄泥冈自然终局/独立重启拒旧槽1386项](../evidence/handoff_terminal_20261026_201649/summary.json)通过（1333+53），包含精确ACKv2和Service独立未记账proof检查；经典30波、连环马完整路线和全61阶段尚未通过。模型及合成账号I/O不能授予真实SDK资格。原版界面键鼠按用户选择暂停，公开战役入口保持关闭。

半份pending及无owner空writing目录当前仍拒绝自动恢复；不能因预期拒绝测试通过就标成已恢复。后继释放/恢复所有权、写入staging与历史退休方案见[后继设计](STORE_RECOVERY_NEXT.md)。

黄泥冈首轮旧驱动仍硬编码ACKv1，579项中3项失败及未运行的后继结果UI/重启阶段已保留于[原失败](../evidence/handoff_terminal_driver_failed_20261026_200641/summary.json)。后继驱动按LCv2/LCv3分别严格要求Intent/ACK对应版本；v3增加完整四字段未记账proof、同token/完整intent SHA及实际Service独立检查，未改路线、布局可见条件或游戏源码。13张本轮截图只留本机，未做新增人工目检；四语内容是实际UI自动断言。
