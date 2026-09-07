# Steam 回执与待发送事务草稿

2026-09-07，新 outbox 模型以同一文档保存账户 receipt 和固定待发送批次。Godot 4.6.3 原生 62 项检查通过，依赖 receipt 的原 88 项复跑通过；实际 PID 45096/36860、exit=0，私有目录、源和玩家保护通过。没有修改生产 SteamService、真实账户进度或 SDK。

发送资格必须先经过 prepare、实际关闭文件回读、commit，然后才能一次性取得 SDK 写入目标。它位于第一条 SetStat/SetAchievement 之前：Steam 还可能在进程退出时上传其缓存，不能只在 StoreStats 前设置标记。[Steamworks 官方接口说明](https://partner.steamgames.com/doc/api/ISteamUserStats#StoreStats)

已有批次未确认时禁止第二次发送；本局新高水位可以继续提交，但原发送目标不变。成功只确认该批次；结果 8 关闭发布并终止旧局资格，必须先持久失效，再由实际权威新读精确校正。重启读到 uncertain 不重发旧目标；保留旧局高水位和终局墓碑。读取失败可以取消并使用新 token 重试，已用 token 不能重新关联迟到回调。

宿主必须把 prepare、同步写入/关闭/回读、commit 放在同一个不可重入、无 await 的临界区，期间不得 pump SDK 回调或调用任意外部验证回调。内存 commit 拒绝不能撤回宿主已经写进磁盘的文档。测试中的重入反例仅验证内存拒绝，不能声称解决了一个已写盘又崩溃的窗口。

当前没有账户目录、文件 CAS/残留恢复、假 SDK 杀进程矩阵或真实 GodotSteam 权威读取适配。保守恢复可能丢弃服务器未包含的未确认本地进度；它不承诺同时不重复且不丢失的 exactly-once。当前 Battle.kills 也不能直接充当合格累计：它在 FIGHT 判断前增加，后续须新增独立持久 token 和合格累计字段。

源与可恢复执行说明见 [封存草稿](../tools/contracts/steam_receipt_outbox_draft_20260907/README.md)，原始模型结果见 [原生收据](../qa/stabilization_resume_graph_20260907/outbox_native/receipt.json)，接口、实际生产位置和故障矩阵见 [独立审查](../qa/stabilization_resume_graph_20260907/outbox_draft/REVIEW.md)。后续先完成受控存储/CAS/恢复与假 SDK 宿主，再验证真实客户端读取和回调，之后接入生产。
