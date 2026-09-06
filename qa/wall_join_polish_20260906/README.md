# 祝家庄门墙衔接 QA

2026-09-06。修改前截图来自本轮前一次实际检查的 `bc30ec0`；最终代码基于安全快进后的 `4589c85`，仅改变祝家庄木墙高度/色调。两次之间的远端生产差异为地图线段检查优化，未改变静态门墙渲染。

| 场景 | 修改前 | 修改后 |
|---|---|---|
| 祝家庄门口，1.7倍 | [前](before/zhu_close.png) | [后](after/zhu_close.png) |
| 祝家庄远景，1.1倍 | [前](before/zhu_wide.png) | [后](after/zhu_wide.png) |
| 梁山剧情控制，1/1.7倍 | 本轮不改高度/色调 | [远](after/liangshan_wide.png)、[近](after/liangshan_close.png) |
| 驻守战控制，0.8/1.5倍 | 本轮不改高度/色调 | [远](after/defense_wide.png)、[近](after/defense_close.png) |

图像为Godot4.6.3 Forward+ Vulkan、RTX3070Ti、1440×900直接保存，无后期图像处理。夹具固定相机、部署态停止单位、隐藏HUD/迷雾以检查接缝，不是实际战斗回放。木墙降低后，两座门口的栅顶高差缩小，色调更接近旧门楼；不声称不同素材完全无缝或真人接受。

最终基线上的验证：

- [墙体46/46](geometry.log)：原图SHA、六轴柱脚/竖直、三种地图实例、四处门脚接缝、阻挡与墙后点选/透明恢复、大名府隔离。
- [接应22/22](contact.log)、[结果](contact.json)：孙立定位、33人群选右键旗标、完整5秒计时、H中断、重新下令、开门后可寻路、英雄死亡/门被摧毁反馈。敌人暂停的输入夹具，不能代表实战平衡。
- [六张截图保存6/6](visual.log)：保存成功是技术结果；画面已另行查看，不将它等同艺术质量测试。

复现使用既有 `tools/wall_alignment_test.gd`、`tools/zhujiazhuang_gate_contact_test.gd`、`tools/wall_alignment_visual.gd`。接应请设 `RTS_TEST_OUT=res://.godot/wall_join_contact`，避免覆盖历史QA；截图请设 `WALL_VISUAL_TAG=wall_join_review`。完整实现与范围见 [说明](../../docs/WALL_JOIN_POLISH_20260906.md)。[收据](receipt.json)记录当前关键输入和本批证据原始字节；不代表发行清单完整。
