# 吴用通用四向 QA · 2026-10-04

最终批 20261004_003104_6712e30a：**543/543 原生、8/8 公共路由、249 项来源审计通过，3469 冻结输入及私有副本零漂移，32 张截图**。十张原生生产 PNG、32 独立姿势、20 五状态四向资源完成实际移动、投射物释放与飞行后伤害、受击、死亡移除/末帧/释放、图鉴方向选择与 HUD 同头像验收。正常 Engine.time_scale=1，1440×960 Compatibility/OpenGL，所有步骤退出 0、共享锁释放。[最终收据](final/receipt.json) 与 [角色报告](final/wu_yong/report.json) 保留截图 SHA、引擎/驱动/冻结来源链。

164 个非建筑/资源定义当前四向来源覆盖：待机 34、行走 18、攻击 18、死亡 14。覆盖仅表示独立来源；公共 full-action 门槛另含非致命 down，不代表本批五状态或全库已完成。[来源审计](source_audit.json)、[32 采样留边](bounds_audit.json)、[32 产物复现](reproduction.json) 均通过，20 TRES 无差异。

## 失败、保护与纠正

- [编译中止](compile_rejected/receipt.json)：恢复首个最终冻结批后，验收脚本直接引用 Projectile 类型导致依赖脚本在自动加载单例注册前编译，未进入战斗检查；源码零漂移。改为运行时检查精确脚本路径、shooter 与 target，保留原有投射物归属条件，再重新冻结并完整复验通过。
- 最小导入前也曾因其他 Godot 出现而保护中止，未执行导入；各 texture_bootstrap 目录保留收据，失败目录无 import.log。最后两张背面源的 UID 导入通过。最终通过批为重新冻结执行，没有沿用失败批游戏状态。

- [首轮](startup_failure/receipt.json) Godot 启动崩溃，退出 3228369023、日志为空，角色检查 0；生产与私有来源零漂移。
- [第二轮](engine_pause/receipt.json) 导入成功，盲盒项目启动 Godot 后在角色检查前被共享引擎保护中止；两端来源零漂移。该批不含后来重绘的两张背面起手，未当作最终验收。
- 用户选择继续等待，未控制其他项目。稳定空闲后仅释放本任务暂停锁，隔离导入两张新图 UID，并重新冻结最终源码。复用同引擎成功导入缓存并重新导入，不声称无缓存导入。
- 原起手背面换手、未纠正编辑和西北朝向错误经目检拒绝；两份候选在来源契约 generated 保留，原起手下半区域明确拒绝采样，最终 NE/NW 单幅另绘。PNG 无本地像素修改或镜像。

## 画面审核与范围

三页 [姿态矩阵 1](final/wu_yong/unit_pose_matrix_1.png)、[2](final/wu_yong/unit_pose_matrix_2.png)、[3](final/wu_yong/unit_pose_matrix_3.png) 覆盖 32 姿势与四方向。实际目检名单另见 visual_review.json；只在该文件确认后收尾提交。其他截图保留，不称为全部逐像素审核。

本批为低帧数基础动作，未验收完整战役、存档恢复、长时性能、手机/平板、高 DPI 或全库 UI。仅按既定 stable 同步源码、生产素材、来源链及 QA；未打包发布 Steam/Android 或再次合并 main。[实现与限制](../../docs/WU_YONG_DIRECTION4_20261003.md) · [来源契约](../../tools/contracts/wu_yong_direction4_20261003/README.md)。
