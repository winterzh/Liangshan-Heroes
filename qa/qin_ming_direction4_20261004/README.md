# 秦明通用四向 QA · 2026-10-04

16生产原生RGBA、32独立姿态、20TRES，现行aligned头像与远程步兵/magic玩法沿用。611/611 原生、8/8 公共路由、406 项来源审计通过，3752 冻结输入及私有副本零漂移，38 张截图。

- [最终收据](final/receipt.json)：生产及私有输入零漂移、锁释放。
- [原生报告](final/qin_ming/report.json)：正常四向移动、真实magic弹道/伤害、受击/死亡及实际图鉴/HUD；现有数值、技能和绑缚/释放演员检查。
- [公共路由](final/routing/report.json)、[盘点](final/inventory/inventory.json)：164个非建筑/资源定义当前四向来源覆盖：待机39、行走23、攻击23、死亡19。
- [直接画面审核](visual_review.json)：22张原生截图，三个矩阵覆盖32姿态，含被缚四向及释放后两向。
- [来源](source_audit.json)、[留边](bounds_audit.json)、[复现](reproduction.json)：406项来源、32留边、38产物字节无差异。
- [隔离纹理导入](texture_bootstrap/receipt.json)、[清理](cleanup.json)：审核后清理32份本轮重复缓存，共23,390,268字节；16张生产原图、10张必需父图、25张几何参考及最新成功工程与缓存保留。

等待共享引擎自然空闲后完成一次完整验收，未干预其他任务；复用同引擎成功缓存后重新导入，非无缓存首启。绑缚检查使用章节实际函数及显式演员夹具，不代表整关营救；基础低帧动作不是平衡、续玩、长测、真机或平台包验收。本轮只同步stable。见[实现](../../docs/QIN_MING_DIRECTION4_20261004.md)、[契约](../../tools/contracts/qin_ming_direction4_20261004/README.md)。
