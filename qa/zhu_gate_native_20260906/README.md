# 祝家庄门楼与墙线 QA

旧门对照于57e2512实际运行捕获；最终源码已整合5457de7单位重绘优化，原图不经后处理。Godot4.6.3 Forward+ Vulkan，RTX3070Ti，1440×900，冻结单位并关闭迷雾/HUD。这是画面/交互夹具，不能充当性能或真人战役验收。

| 视角 | 前 | 最终 |
|---|---|---|
| 正门1.7倍同机位 | [旧图](before/zhu_close.png) | [新图](final/zhu_close.png) |
| 两门1.1倍 | — | [远景](final/zhu_wide.png) |
| 两门分别2倍 | — | [正门](runtime/main_close.png)、[偏门](runtime/side_close.png) |
| 梁山/驻守控制 | 本批未替换其门墙 | [梁山](final/liangshan_close.png)、[驻守](final/defense_close.png) |

已查看远、近景：门楼正面方向与墙线一致，门框竖直；木栅侧翼与墙段较连贯，标签/血条未跟随贴图变暗。木墙端部支撑、局部段宽、旧式梁山门和全关风格仍可继续打磨，不能据端点合格声称玩家已接受。

| 验证 | 结果 | 证据 |
|---|---|---|
| 两门实图/锚点/竖直/阴影/阻挡/颜色及大名府隔离 | 27通过 | [日志](gate_art.log)、[报告](runtime/report.json) |
| 原生来源/提示词/alpha/脚点/导入 | 22通过 | [报告](sources.json) |
| 六轴墙体/地图墙脚/遮挡点选/大名府隔离 | 46通过 | [日志](wall.log) |
| 孙立33人群选、5秒、中断、死亡/攻破替代及实际通行 | 22通过，敌人暂停 | [日志](contact.log)、[报告](contact/report.json) |
| 宋江真实四向移动/攻击/死亡和变体路由 | 250通过 | [日志](song.log)、[报告](song/report.json) |
| 三地图六机位保存 | 6成功，另行查看 | [日志](visual_final.log) |

未采用的[旧门仅拉高方案](attempts/rejected_height_only.png)可见比例失真。最初门QA把HUD的`unit_texture`别名误当世界`terrain_texture`，该断言失败保存在[日志](attempts/gate_art_wrong_legacy_assertion.log)；已修为检查实际未启用变体的物件/图集路由，不是放过生产故障。前三次美术输出为棋盘格或碰边轮廓，见[来源链](../../tools/contracts/zhu_gate_native_20260906/generation.json)，没有接入游戏。

[实现、命令与限制](../../docs/ZHU_GATE_NATIVE_20260906.md)。收据记录本轮源码/素材和证据SHA，不表示整体发行验收完成。
