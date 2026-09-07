# First native matrix

以下是驱动设计，运行结果以独立 `runs/<id>/receipt.json` 为准，不提前标 PASS。

| 组 | 实际进程与断点 | 验收 |
| --- | --- | --- |
| 发送事务 | 12 个真实强杀：锁落盘、prepare、pending 半写、pending 回读、rename、最终回读、model commit 前、解锁前、SDK 前、首个 SetStat 后、SetAchievement 后、StoreStats 后 | SDK 前断点没有更早 SDK 调用；半文件保留阻断；完整唯一链只向前；恢复不增加 SDK 日志 |
| 成功回调 | 7 个强杀：callback 1 入口、prepare、pending 半写、pending 回读、rename、model commit 前、解锁前 | 未持久 ack 保守失效；持久 ack 可以保持 clean；新进度不被旧 ack 清掉 |
| 结果 8 | 与上组对称的 7 个强杀 | 已有 uncertain 覆盖回调未落盘窗口；恢复不能重发旧高目标；先持久 tombstone 后 exact 校正到 7 |
| 部分 SDK 失败 | 第二项 SetStat 失败、StoreStats false，分别启动新进程恢复 | marker 留存，第一次 SetStat 产生的副作用不被 false 否认，无旧目标重试 |
| 同进程宿主 | 真实账本写入、typed 参数、唯一 pending、超时、错 app/owner/session、发送中新进度、旧实例 CAS、ack、重复成功、无归属 8、活锁 | 目标冻结在 2000，新进度 2001 保留；新会话/旧实例不得清其它发送 |
| 迟到成功跨批次 | A 发送及成功 → 尝试 B → 迟到 A 成功 → 新 Host/session 再尝试 B | 进程级单次 lease 阻止两次 B；迟到 A 无法清新高水位；换 Host/session 不能绕过 |
| 完整文件验证 | 10 个隔离坏账本：UTF-8、截断、hash、owner、多字段、负数、bool、小数、断链、未知文件 | 每份原文件 SHA 不变且拒绝打开；数值反例重新签 envelope，确保触发完整模型验证 |

不在本批：真实服务端拒绝、真实退出自动上传、同 callback 缺失 attempt id 的 SDK 关联能力、实际跨设备并发、MAX_RUNS 边界、二次恢复过程强杀、Windows junction 创建反例、账户目录 OS ACL 与恶意非合作写者、磁盘故障/断电。现有代码含链接祖先/叶检查，但未跑链接构造测试前不报告该类原生通过。
