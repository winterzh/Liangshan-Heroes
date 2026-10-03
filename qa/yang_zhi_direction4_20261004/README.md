# 杨志通用四向 QA · 2026-10-04

23张生产原生RGBA、32独立姿态、20TRES，当前对齐头像与近战步兵玩法沿用。600/600 原生、8/8 公共路由、467 项来源审计通过，3585 冻结输入及私有副本零漂移，28 张截图。

- [final/receipt.json](final/receipt.json)：来源/私有冻结3585输入零漂移，锁释放，complete=true。
- [原生报告](final/yang_zhi/report.json)：600/600，正常速度四向近战实际伤害、受击、死亡生命周期、图鉴/HUD和28张截图。
- [公共路由](final/routing/report.json)：8/8；[全库盘点](final/inventory/inventory.json)：164 个非建筑/资源定义当前四向来源覆盖：待机 36、行走 20、攻击 20、死亡 16。
- [直接画面审核](visual_review.json)：三页矩阵覆盖32姿态及选取正常游戏截图。
- [首轮目检问题](initial_visual_findings.json)：自动600项通过仍拒收西北高举刀和东南刀尖锚点，重画/调整后重新冻结全套验收。首轮[收据](initial/receipt.json)、[报告](initial/yang_zhi/report.json)、三页矩阵保留；完整初批工程/截图在工程外原路径。
- [第二轮取样失败及修正](sampling_failure/README.md)：实际伤害发生后渲染帧已进入收招；共享QA改为物理帧记录首次HP下降，不放宽动作断言。
- [来源](source_audit.json)467项、[留边](bounds_audit.json)32项通过；[复现](reproduction.json)45产物/20TRES零差异。
- [清理](cleanup.json)：最终审核后清理 101 份本轮重复缓存/已归档无引用候选副本，共 45,408,099 字节；六份必需父图、28张参考及最新成功工程/缓存保留。

同引擎成功imported复用后重新导入，非无缓存启动验收；其他任务未被控制。候选归档在工程外受控路径，原生成器输出保留。基础五状态不能替代完整黄泥冈剧情、战役续玩、性能/设备或平台安装包验收。本轮白名单同步stable，不合并main或发布。来源见[实现](../../docs/YANG_ZHI_DIRECTION4_20261004.md)、[契约](../../tools/contracts/yang_zhi_direction4_20261004/README.md)。
