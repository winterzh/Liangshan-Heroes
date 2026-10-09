# 卢俊义通用四向 QA · 2026-10-04

中间复验的[剧情演员释放夹具错误](fixture_failure/README.md)及[旧头像策略断言错误](portrait_assertion_failure/README.md)已修正，保留原始失败证据；当前生产战斗及头像路由未因这些夹具错误改动。

19生产原生RGBA、32独立姿态、20TRES，当前指挥官头像与持枪近战步兵玩法沿用。720/720 原生、8/8 公共路由、427 项来源审计通过，3644 冻结输入及私有副本零漂移，28 张截图。

- [最终收据](final/receipt.json)：生产及私有输入零漂移、锁释放。
- [原生报告](final/lu_junyi/report.json)：正常四向移动/近战、受击/死亡、图鉴/HUD及四类剧情外观优先夹具。
- [公共路由](final/routing/report.json)、[盘点](final/inventory/inventory.json)：164个非建筑/资源定义当前四向来源覆盖：待机37、行走21、攻击21、死亡17。
- [直接画面审核](visual_review.json)：矩阵覆盖32姿态及正常游戏截图。
- [首轮占用记录](import_pause/receipt.json)、[自己的锁恢复](import_pause/lock_recovery.json)：导入后引擎存在时退出，等待空闲后重新运行；不操作其他任务。
- [来源](source_audit.json)、[留边](bounds_audit.json)、[复现](reproduction.json)：427项来源、32留边、41产物字节无差异。
- [清理](cleanup.json)：审核后清理5734份本轮重复缓存，共1,004,409,969字节；生产原图、32张参考、失败记录、最新成功工程与缓存保留。

复用同引擎成功缓存后重新导入，非无缓存首启。当前被缚/获救及旧别名的外观夹具不是整关营救验收；基础动作不是平衡、续玩、长测、真机或平台包验收。本轮只同步stable。见[实现](../../docs/LU_JUNYI_DIRECTION4_20261004.md)、[契约](../../tools/contracts/lu_junyi_direction4_20261004/README.md)。
