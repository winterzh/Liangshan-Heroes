# 2026-09-08 Steam 更新公告与实机配图

已按用户“发布”指令发布[9 月 8 日更新：任务面板优化与测试版进展](https://store.steampowered.com/news/app/5088120/view/708907988310558956)。事件 ID `708907988310558956`，分类“小型更新 / 补丁说明”，页面发布时间为 2026-09-08 03:27 CST（UTC+08:00，分钟精度）。后台显示“发布成功完成”和“公开可见”；公开地址的中英文标题、全部正文以及配图均已回读。

公告在编辑器中关联 `steam-integration` / Build **25173165**。文字另行说明公开版任务框热更（default **25164373**），并明确完整保存退出/继续战斗尚未开放。构建依据见[测试更新](STEAM_UPDATE_20260908.md)与[任务框热更](STEAM_MISSION_PANEL_UPDATE_20260907.md)。本轮没有上传游戏包或更换分支构建。

## 配图与检查

正文上传并插入已有[1920×1080 祝家庄任务面板实机截图](../qa/steam_mission_panel_20260907/toggle/level3_1920x1080_expanded.png)，SHA256 `38ab0ca42934d7c2780beebeb71bc1f57f2a225159664467eda00300089dc69e`，来源与原生观察见[原截图记录](../qa/steam_mission_panel_20260907/visual_review.json)。图片来自公开任务框热更，不是新美术候选或续玩截图；没有生成、裁剪或修改像素。

Steam 完整图片 BBCode 为 `{STEAM_CLAN_IMAGE}/46272698/19add50bbf1f5f024e4d147846b911c355b2c29e.png`。公开页实际加载 URL 为 `https://clan.fastly.steamstatic.com/images//46272698/19add50bbf1f5f024e4d147846b911c355b2c29e.png`；中英文页面均读到 complete=true、naturalWidth=1920、naturalHeight=1080。中文显示尺寸为 688×387。

首次直接点击文件输入未触发选择器，改用页面可见“或浏览 选择文件”后上传成功。预览发现画廊 URL 为128×72缩略图，发布前通过“完整大小”获取原图 BBCode，并更新两种语言。Steam 提示未设置自定义活动封面，按既有授权继续使用默认游戏宣传图；正文实机配图已独立上传。没有上传商店封面或视频。

验证使用已登录浏览器打开正式商店新闻地址，未使用预览页代替发布验证；没有另外进行未登录访客测试。平台提示库内展示可能有审核延迟，本轮未验证每个玩家的库推送。发布事实与边界见[收据](../qa/steam_announcement_20260908/publication_receipt.json)。既有上传 QA 中 announcement_published=false 保留为上传阶段历史事实，不覆盖本次后续公告。

## 中文已发布内容

标题：9 月 8 日更新：任务面板优化与测试版进展

副标题：任务目标可随时展开或收起，新的 Windows 测试版已开放。

概述：公开版任务面板支持收起，释放战场视野；steam-integration 分支已更新。完整保存与继续战斗功能仍在开发中。

```bbcode
[h2]公开版：任务面板可收起[/h2]
八个战役的任务目标面板现在默认收起。点击“任务目标”即可展开，再点“收起任务”收回详情，为战场留出更多视野。

收起期间，任务进度与计时照常更新，腾出的区域也可以正常点击和框选。

[img]{STEAM_CLAN_IMAGE}/46272698/19add50bbf1f5f024e4d147846b911c355b2c29e.png[/img]
[i]实机画面：需要查看详情时，点击“任务目标”展开面板。[/i]

[h2]新的 Windows 测试版已开放[/h2]
steam-integration 测试分支已更新至 Build 25173165，包含战斗状态管理与后续续玩功能的基础更新。本轮已通过八关、据守和菜单的自动短测。

完整的“保存退出 / 继续战斗”功能仍在开发中，本次测试版还不能继续上一场战斗。公开版保持当前任务面板热更，想保持原有体验的玩家无需切换分支。

感谢大家的反馈。测试时如遇到问题，欢迎告诉我们所在关卡、操作步骤和是否使用测试分支。
```

## 英文已发布内容

标题：September 8 Update: Mission Panel Improvements and Test Build News

副标题：Expand or collapse mission objectives, and try the new Windows test build.

概述：The public build has a collapsible objective panel. The steam-integration branch is updated; full save and resume is still in development.

```bbcode
[h2]Public build: collapsible mission objectives[/h2]
The objective panel now starts collapsed in all eight campaigns. Click the mission objectives button to expand it, then click again to hide the details and free up your view of the battlefield.

Mission progress and timers keep updating while the panel is collapsed. You can also click and drag-select in the space it previously covered.

[img]{STEAM_CLAN_IMAGE}/46272698/19add50bbf1f5f024e4d147846b911c355b2c29e.png[/img]
[i]In-game screenshot: expand the objective panel whenever you need to check the details.[/i]

[h2]A new Windows test build is available[/h2]
The steam-integration branch has been updated to Build 25173165. It includes foundational work on battle state management and future save/resume support. Automated startup checks passed for all eight campaigns, defense mode and the menu.

Full Save and Exit / Continue Battle is still in development. This test build cannot resume a previous battle. The public branch remains on the current objective-panel hotfix; there is no need to switch branches to keep playing the existing version.

Thanks for your feedback. If you encounter a problem while testing, please tell us the campaign, the steps to reproduce it and whether you are using the test branch.
```
