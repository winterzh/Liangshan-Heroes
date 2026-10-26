# 完整 23 脚本候选：冻结与导入证据

候选 `20261027_000821_ba1f231b` 已完成准备和真实 editor import。23 个脚本与 1 个原生 helper 纳入完整身份：

- 内容：`source-v1:e97a07b9ff04b677fbc1934a40976cc6e1f82479855cf39f305147ae4f6d1eea`。
- 候选清单 SHA：`f4b83220e4990d2823bc2c5393c6383ebec33b06dc6aa9ccd7186ebdccbd1e0d`。
- 导入 PID 14468，退出 0、错误 0，40.785 秒，终态记录共享锁已释放。

准备阶段先复制原生产输入、覆盖指定候选并加入固定 helper，再写空的生成身份 stub。后续真实导入结束才生成最终身份；7016 个生产输入变为 7037 个导入前候选输入，导入新增 25 个 `.uid` / `.import` 元数据后共 7062 个输入。未删除或改变已有导入前输入。helper EXE 作为 addons 下的普通文件进入完整 source SHA；归档不复制该二进制。

独立核对 37 项准备 pin、冻结中的 23 脚本与 helper、生成常量及导入日志 SHA 均一致；root / preimport / generation 三份清单的规范身份哈希重新计算一致，expected_identity 与 generation 精确对应。此次归档未重新逐项散列整个 2.4 GB 美术工程。

证据入口为 [summary.json](summary.json)、[逐文件原始来源及 SHA](manifest.json)、[准备收据](preparation.json)、[导入收据](import__20261027_001148_fde2d165/receipt.json) 和 [导入日志](import__20261027_001148_fde2d165/import.log)。保留完整来源清单、preparation_inputs 中原始准备脚本与清单，以及受 pin 的 helper 源码和构建收据。documentation_snapshots 中 README 是归档时的导入后文档快照，未被原准备收据锁定，不冒称冻结时原文。

15 份原字节文件及 summary、manifest、本说明共 18 文件，逐文件复制校验。未复制 project、assets、缓存、EXE、profile 或存档载荷；未改旧冻结或源文件，未为归档启动引擎。

**本档只授冻结与导入完成。** 同期或后继活写者、死写者恢复测试以各自独立收据为准，不转入此档；完整游戏、原版 GUI、真实 Steam SDK、人工体验、性能与发布资格均未授予。
