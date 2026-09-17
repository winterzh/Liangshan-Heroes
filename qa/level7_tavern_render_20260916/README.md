# Level 7 酒望运行时绘制收据（2026-09-16）

本批修复窗口化 Level 7 中四处酒望被白色方块覆盖的问题。原始 `taverns.png`、四个 `roadside_tavern_{a,b,c,d}.tres` 和四格来源没有改动；问题来自 Godot Unit 画布对带虚拟 margin 的 `AtlasTexture` 的合成路径。实机 Unit 绘制改用项目中已经验收、带真透明的 `assets/campaign/objects/roadside_tavern_default.png`，仍保留四个 route metadata、原生图集和 TRES 供来源追溯及后续变体修复。

- 条件：Godot 4.6.3、窗口化 1280×720、1 倍速、正常迷雾、固定关卡部署态。
- 结果：四处酒望均显示木结构酒肆，酒幌与名称无遮挡，无白色矩形覆盖；周围黄土官道、林地、柳树和市井摊位保持原有宋代水浒场景风格。
- 回归：`tools/run_art_full_qa.py --run` 完成，导入与库存检查 `complete=true`。
- 截图：[`overview.png`](overview.png)、[`detail.png`](detail.png)。机器可读收据：[`render_receipt.json`](render_receipt.json)。

本批没有改玩法数值、任务触发、镜头逻辑、玩家存档或 Steam 发布状态。
