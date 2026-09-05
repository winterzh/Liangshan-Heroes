# 寨墙与造船底层 QA

2026-09-06，输入基线 `3c47af28f4cf4691de3c508b24ff965088d3bddf`，Godot 4.6.3。当前源码和证据哈希见 [receipt.json](receipt.json)，规则及范围见 [实现说明](../../docs/WALL_AND_NAVAL_FOUNDATION_20260906.md)。本批修正实际木墙并加入按关卡启用的船坞底层；高俅菜单仍是旧战役，不能据此认定第四个RTS完成。

## 功能与回归

| 验证 | 最终结果 | 证据 |
|---|---|---|
| 真实岸边建造、付费训练、固定泊位、动态堵口、等待队列、取消退款、集结、维修、毁坏重建、四面岸线、模式隔离 | 57/57 | [船坞日志](naval_console.log) |
| 512px原图端柱脚、6种墙向、柱高、章节权限、真实关卡节点、两门四处接缝、导航阻挡、墙后单位点选与透明恢复、大名府砖墙隔离 | 46/46 | [墙体日志](wall_console.log) |
| 孙立接应：接近、群选、触发及任务回归 | 22/22 | [日志](contact_console.log)、[结果](contact.json) |
| 共享战役核心 | 68/68 | [日志](core_console.log) |
| 祝家庄经营、驻守/电脑对战与章节启动隔离 | 39/39 | [日志](shared_console.log)、[结果](shared.json) |
| 陆水远程进入射程、障碍路径、H据守 | 23/23 | [日志](ranged_console.log)、[结果](ranged.json) |
| 环境实际路由 | 794/794 | [日志](environment_console.log)、[结果](environment_runtime.json) |
| 固定实机镜头保存 | 墙6/6、船坞9/9 | [墙日志](wall_visual_console.log)、[船坞日志](naval_visual_console.log) |
| 全部路由表相对git基线的精确差异、原图SHA、静态工具Python语法 | 7/7 | [路由差异](router_scope_delta.json) |

最后一项只允许 `stockade_segment` 从 `level5` 扩展至 `level3/level5`，其他表、路径和冻结清单ID保持一致。本checkout缺少旧完整静态合同依赖的 `environment_batch_manifest.json`，没有运行或宣称完整历史源素材门禁通过；需恢复历史输入或迁移为当前自包含清单。

## 实机视觉

图像均为Godot Forward+ Vulkan直接输出的1440×900截图，无后期图像编辑。固定相机、停止单位移动并隐藏HUD/迷雾，以便比较端点和转角；并非真人战斗回放。查看了祝家庄门口与远景、梁山墙段和驻守转角，柱脚沿地图墙线排列、木柱竖直，门口接缝连接；原PNG及alpha未改。旧门楼和全关环境美术不在本批完成范围。

| 场景 | 修改前近景 | 最终近景 | 最终远景 |
|---|---|---|---|
| 祝家庄 | [原墙](before/zhu_close.png) | [门墙衔接](walls/zhu_close.png) | [整段墙](walls/zhu_wide.png) |
| 梁山故事 | [原墙](before/liangshan_close.png) | [墙段](walls/liangshan_close.png) | [营寨](walls/liangshan_wide.png) |
| 驻守战 | [原转角](before/defense_close.png) | [双向转角](walls/defense_close.png) | [营寨](walls/defense_wide.png) |

船坞三张图为明确标注“船坞验证场·非战役流程”的受控旧梁山地图夹具，启用新定义后运行真实命令与计时：[施工](naval/construction.png)、[等待下水](naval/waiting.png)、[下水后集结](naval/launched.png)。新船坞叠在旧地图装饰码头位置，只验证共享底层；新高俅地图仍需设计专门岸线和完整经营入口。

## 性能边界

[最终原始采样](performance.json)与[控制台](performance_console.log)：RTX3070Ti、Forward+、1440×900、驻守战 `skirmish`、相机格 `(31,41)`、27单位、游戏1倍速、关闭VSync/帧率上限、预热3秒后采集10.000061秒。880次帧间隔对应879次drawn/process增量和600次physics增量，平均88.0FPS，P95 **15.613ms**、P99 **21.011ms**、最慢 **27.413ms**。

这是非战斗高峰墙角短窗，P99超过16.7ms，不代表稳定60FPS、30波、30分钟或多人/跨硬件性能验收。计时器基于实际 `frame_post_draw`，未使用headless、固定FPS或游戏加速结果。`mean_process_ms`/`mean_physics_ms`是引擎monitor值，不作为可相加的帧开销结论。较早的同场短窗为11.879/14.464ms；加入实际关卡ID元数据后复测变慢，最终记录保留较慢结果，不选较快窗口作收尾结论。

## 未通过的尝试

- [最初船坞脚本日志](attempts/naval_production_1.log)：SceneTree工具预加载依赖触发autoload编译错误，改为场景启动后加载。
- [最初船坞实机日志](attempts/naval_visual_1.log)：夹具对不存在的迷雾节点直接调用hide，增加空值检查。
- [最初墙体日志](attempts/wall_alignment_1.log)：错误假定第7关有墙；查实际场景后移除无消费者的权限和检查，仅保留3/5章节。
- [废弃拉伸版本](attempts/rejected_stretched_atlas.png)及[对应输出日志](attempts/wall_visual_after_v1.log)：放大旧图集条带造成灰色斜坡基座，图片虽然保存成功但视觉不合格；最终祝家庄改用原库已验收木墙来源及正确脚点。

全库角色四向、后续战役趣味性、真人试玩和可售版本尚未完成。本批没有导出、合并main、创建Release或Steam发布。
