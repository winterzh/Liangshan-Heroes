# 唯一目录释放候选：本轮运行状态

2026-10-26。此页记录执行状态；`source_manifest.json`、集成manifest及其固定README保留创建时的原字节，不事后重写为通过。

- 当前 Store：`11bf6cae5968baa6c740c3c6be1fc954376048cbbe9a81a77b6cf4588518f9f1`。
- 集成manifest：`8dfa8791b181319179fb27b284c4d5e9e34031d5c616a53616fe2a40da62400f`，精确20文件，19文件与23c候选原字节一致。
- 新冻结：`.godot/campaign_progress_recovery_20261026/20261026_211212_dd3104df`，preparation complete=true；导入完成，exit0/错误0；生成身份为`source-v1:f6ef8398f297af3a9be64ca376b9f2a940951d9b93b0512808e3f4275afc32e4`。
- 24项源码检查、10项宿主静态检查通过；独立代码复核确认首次commit_locked的CAS_CHANGED发生在pending写入前，修复只释放本对象的原锁，不重算旧提案。静态检查不等于原生验证。
- [14项命名/布局合成模型](../evidence/store_protocol_model_20261026_213737/summary.json)已通过。首批原生`20261026_214029_e8825c44`第6类前宿主读取275字符marker路径失败，finally取证再失败导致阶段controller未保存，不授予删除断点覆盖；见[原失败](../evidence/store_protocol_io_host_failed_20261026_214029/summary.json)。宿主修复长路径及异常落盘后，[16项宿主probe](../evidence/store_protocol_host_probe_20261026_220422/receipt.json)通过且原文件SHA零变化。
- 新profile重跑`20261026_220853_bcbb8766`已完整结束：23进程/370项worker断言符合预期，来源/引擎/pin前后通过、宿主exit0、锁释放。包括两类释放中断后恢复者再次中断，以及五种实际文件拒绝重试；半pending仍明确拒绝，不能称自动恢复。见[原生收据](../evidence/store_protocol_io_20261026_220853/README.md)。
- 延迟写入首批`20261026_223919_4ffc4c0b`整体exit1：两种时序均在B的外部活A检查处停止，未进入目标交错。身份值相同，源/引擎/pin后验通过，锁释放；[原始失败](../evidence/store_delayed_first_failed_20261026_223919/README.md)保留。
- 旧199c版本冻结`20261026_210350_189c0290`仅完成准备，未导入；其首次重试缺陷、原源码/manifest/静态报告及准备来源见[原始记录](../evidence/store_protocol_first_retry_static_20261026/README.md)。

当前优先阻断是外部PID判死依据不成立：[官方实现及最小原生探针](../evidence/process_liveness_api_20261026_225300/README.md)证明Godot4.6.3 Windows会把不在本实例process_map中的活兄弟进程查询为false。SnapshotStore的inspect/recover和候选Steam Store的unique接管均使用这个false，存在误接管活所有者的可达风险；CFG、生命周期、继续槽及outbox继承路径也受影响。此处尚未原生执行夺锁或观察数据丢失。必须先实现可信alive/dead/unknown查询及活写者零变更矩阵，unknown拒绝恢复，再另冻结验证。不能只删除QA检查或转授23IO的活writer资格；23IO已有宿主终止并wait的已退出前提仍成立。

本版本尚未采用生产。旧无归属writing、旧recovering/owner删除窗口、半pending、Campaign CFG/LC收尾、真实SDK、全61阶段及原版键鼠仍不具完整资格。独立复核还确认另一项双Ledger问题：一方正常release后的readback可被另一方活writing挡住，现Ledger可能将RECOVERY_REQUIRED置unsafe；延迟写入者测试的B使用真实Store+Receipt单独验证Store分支，不能算双Ledger并发成功。

双Ledger问题当前按P2后继可用性缺口保留：既有设计为单Service唯一Ledger，尚未承诺两个活Ledger都能原对象成功。静态路径显示B已提交模型并释放自有锁，因最终读回受阻而无法确认，尚无该时序的原生丢记录或重复奖证据。不能全局将RECOVERY_REQUIRED改为可重试；后续若支持此交错，只能对已提交/已释放且原written记录链完全一致、同账号已确认活PID完整锁、无pending/marker/恢复锁的读回争用作严格分类，保留原提案和token，只重读不重写/接管。proof前的独立回读也需同样覆盖；未知锁、损坏、head变化继续拒绝。该建议尚未实现或原生验证，不改变本批准入范围。

原版游戏键鼠按用户选择继续暂停。以上候选和屏幕外原生测试没有恢复桌面键鼠控制。
