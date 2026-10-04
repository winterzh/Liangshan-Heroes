# 投石车四向 QA · 2026-10-04

八份原生RGBA、32个独立采样姿态、16个机械四状态四向资源完成验收；木制刚性底盘、轮辐滚动、带弹抬臂/空勺释放/回落及低矮毁坏残骸一致。552/552原生、8/8公共路由、226项来源通过，3840冻结输入及私有副本零漂移，23张截图全部直接审核。

- [最终认证收据](final/receipt.json)、[原始收尾收据](final/pre_lock_closure_receipt.json)、[原始文件名及SHA对应](final/delivery_normalization.json)、[认证关闭工具](final/harness/close_completed_run.py)：最终四步全部执行通过；原始收据因收尾时出现其他引擎而保留complete=false，随后自然空闲时复核生产/私有源码、QA、驱动、引擎和证据身份，只释放本轮自有锁并生成认证收尾收据，未重写原始结果。
- [原生报告](final/siege_cata/report.json)：真实四向滚动、同物理帧空勺释放、巨石落点掉血、HUD、既有数值与毁坏清理。
- [公共路由](final/routing/report.json)、[盘点](final/inventory/inventory.json)：164个非建筑/资源定义的四向覆盖：待机40、行走25、攻击24、死亡21。投石车30波配置含50个实例，此为配置数量，不是玩家实战频次。
- [全部23张画面审核](visual_review.json)：三矩阵及四向移动、发射、伤害、破裂、末态。
- [来源](source_audit.json)、[留边](bounds_audit.json)、[复现](reproduction.json)：226项来源、32留边、35产物/16TRES零差异。
- [隔离纹理导入](texture_bootstrap/receipt.json)、[首轮失败](attempts/release_timing_01/README.md)、[清理](cleanup.json)：审核后清理2984份本轮重复导入缓存，共586,551,063字节；7683个受保护输入前后SHA一致，八张生产原图、必需父图/轮辐参考及最新成功工程/缓存保留。

首轮480项中四向释放均过早选中回落；修正为八个攻击时间槽，四个独立姿态不变，释放槽覆盖0.5–0.75，实际物理发射相位0.601667落在空勺高臂。伤害、冷却和发射时点未改。仅低帧美术及基础命令/战斗兼容验收。轮辐两帧差异较细，不宣称精确22.5度旋转；血条/旗帜部分遮挡上臂，由矩阵和精确来源检查补充。截图瞬时FPS不作为60FPS性能门槛证据；完整章节、续玩、长测、真机及平台包仍待验收。复用同引擎成功缓存后重新导入；按用户选择自然等待，未干预其他项目。见[实现](../../docs/SIEGE_CATA_DIRECTION4_20261004.md)、[契约](../../tools/contracts/siege_cata_direction4_20261004/README.md)。
