# 花荣通用四向 QA · 2026-10-04

14 张生产原生 RGBA、32 独立姿态、20 TRES，当前银甲白衣头像及远程步兵玩法沿用。

- [final/receipt.json](final/receipt.json)：恢复原已导入隔离批，3518 生产与私有冻结输入零漂移，脚本/驱动/引擎不变，complete=true 且本任务锁释放。
- [final/hua_rong/report.json](final/hua_rong/report.json)：563/563 原生，正常时间四向移动、真实箭矢释放/飞行后伤害、受击、死亡生命周期、图鉴/HUD及32张截图。
- [final/routing/report.json](final/routing/report.json)：8/8公共路由；[全库盘点](final/inventory/inventory.json)当前164定义，四向待机35/行走19/攻击19/死亡15。
- [visual_review.json](visual_review.json)：三页32姿态矩阵、四向释放和选取战斗/图鉴/HUD/头像共15张原生截图直接审核；未发现需返工问题。
- [source_audit.json](source_audit.json)：290来源、引用链、导入/透明采样通过；[bounds_audit.json](bounds_audit.json)32留边通过；[reproduction.json](reproduction.json)36产物及20TRES复现零差异。
- [engine_pause/receipt.json](engine_pause/receipt.json)：历史3518冻结导入成功后遇其他Godot的暂停证据，0角色检查；最终结果以上述final为准。
- [texture_bootstrap/receipt.json](texture_bootstrap/receipt.json)：14纹理隔离导入UID，0像素修改。
- [cleanup.json](cleanup.json)：最终目检后删除28个与保留最新成功缓存同名/大小/SHA一致的临时imported文件和一份已归档无引用候选，合计16,528,683字节。最新成功缓存及四份必需拒绝父图保留。

共享 imported 复用吴用同引擎成功缓存后重新导入，非全无缓存启动验收。用户选择等待，没有控制其他任务；恢复助手连续30秒空闲后执行各步骤，原冻结来源与私有profile不变。六份无引用拒绝候选ZIP仍在工程外受控位置，SHA和逐项来源见cleanup；Codex原输出保持。

本批按白名单同步stable，不再次合并main、打包或发布Steam/Android。低帧数基础动作不等于完整关卡、性能、真人或设备验收。来源见[实现](../../docs/HUA_RONG_DIRECTION4_20261004.md)、[契约](../../tools/contracts/hua_rong_direction4_20261004/README.md)。
