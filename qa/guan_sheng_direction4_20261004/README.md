# 关胜骑乘四向 QA · 2026-10-04

17生产原生RGBA、32独立姿态、20TRES，当前aligned头像与近战骑兵玩法沿用。578/578 原生、8/8 公共路由、365 项来源审计通过，3699 冻结输入及私有副本零漂移，28 张截图。

- [最终收据](final/receipt.json)：生产及私有输入零漂移、锁释放。
- [原生报告](final/guan_sheng/report.json)：正常四向移动/近战、受击/死亡及实际图鉴/HUD；当前骑兵数值与技能检查。
- [公共路由](final/routing/report.json)、[盘点](final/inventory/inventory.json)：164个非建筑/资源定义当前四向来源覆盖：待机38、行走22、攻击22、死亡18。
- [直接画面审核](visual_review.json)：三个矩阵覆盖32姿态及正常游戏截图。
- [首次占用](import_pause/receipt.json)、[自己的锁恢复](import_pause/lock_recovery.json)：导入前因引擎出现退出，按用户选择等待；保留原始失败，不操作其他任务。
- [公共检查接续](shared_pause/README.md)、[原始收据](shared_pause/receipt.json)：同一冻结工程保留已通过角色步骤，仅在空闲时补齐路由/盘点，原始失败不改写。
- [来源](source_audit.json)、[留边](bounds_audit.json)、[复现](reproduction.json)：365项来源、32留边、39产物字节无差异。
- [清理](cleanup.json)：审核后清理2882份本轮重复缓存，共517,518,044字节；17张生产原图、1张必需父图、15张几何参考、失败记录及最新成功工程与缓存保留。

复用同引擎成功缓存后重新导入，非无缓存首启。基础低帧动作不是平衡、续玩、长测、真机或平台包验收；栗色马为游戏绘制解释。本轮只同步stable。见[实现](../../docs/GUAN_SHENG_DIRECTION4_20261004.md)、[契约](../../tools/contracts/guan_sheng_direction4_20261004/README.md)。
