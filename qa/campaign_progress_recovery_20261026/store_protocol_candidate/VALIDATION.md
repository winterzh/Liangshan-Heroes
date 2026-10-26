# 唯一目录释放候选：本轮运行状态

2026-10-26。此页记录执行状态；`source_manifest.json`、集成manifest及其固定README保留创建时的原字节，不事后重写为通过。

- 当前 Store：`11bf6cae5968baa6c740c3c6be1fc954376048cbbe9a81a77b6cf4588518f9f1`。
- 集成manifest：`8dfa8791b181319179fb27b284c4d5e9e34031d5c616a53616fe2a40da62400f`，精确20文件，19文件与23c候选原字节一致。
- 新冻结：`.godot/campaign_progress_recovery_20261026/20261026_211212_dd3104df`，preparation complete=true；导入完成，exit0/错误0；生成身份为`source-v1:f6ef8398f297af3a9be64ca376b9f2a940951d9b93b0512808e3f4275afc32e4`。
- 24项源码检查、10项宿主静态检查通过；独立代码复核确认首次commit_locked的CAS_CHANGED发生在pending写入前，修复只释放本对象的原锁，不重算旧提案。静态检查不等于原生验证。
- [14项命名/布局合成模型](../evidence/store_protocol_model_20261026_213737/summary.json)已通过；23进程首批`20261026_214029_e8825c44`前5类通过，第6类cleanup删除故障前宿主读取275字符marker路径失败而停止，且finally取证再失败导致该阶段controller未保存；不授予删除断点覆盖。原证据见[宿主失败记录](../evidence/store_protocol_io_host_failed_20261026_214029/summary.json)。外部宿主已修长路径及异常落盘，[16项宿主probe](../evidence/store_protocol_host_probe_20261026_220422/receipt.json)通过且原文件SHA零变化；已启动新profile全23阶段重跑，延迟写入者两种时序尚未执行。两进程工具独立于23阶段工具，不据源码文件存在声称运行通过。
- 旧199c版本冻结`20261026_210350_189c0290`仅完成准备，未导入；其首次重试缺陷、原源码/manifest/静态报告及准备来源见[原始记录](../evidence/store_protocol_first_retry_static_20261026/README.md)。

本版本尚未采用生产。旧无归属writing、旧recovering/owner删除窗口、半pending、Campaign CFG/LC收尾、真实SDK、全61阶段及原版键鼠仍不具完整资格。独立复核还确认：双Ledger并发时，一方正常release后的readback可被另一方活writing挡住，现Ledger可能将RECOVERY_REQUIRED置unsafe；延迟写入者测试的B将使用真实Store+Receipt以单独验证Store分支，这不能算双Ledger并发成功。

原版游戏键鼠按用户选择继续暂停。以上候选和屏幕外原生测试没有恢复桌面键鼠控制。
