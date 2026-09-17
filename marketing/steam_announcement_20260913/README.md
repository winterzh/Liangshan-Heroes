# 2026-09-13 四语更新公告文案

[copy.json](copy.json) 是已公开公告 **714538122294068074** 的四语定稿，类型“小型更新/补丁说明”，关联default **Build25276077**。Steam显示开始时间为 **2026-09-13 06:16 HKT（UTC+8）**。[公开公告](https://store.steampowered.com/news/app/5088120/view/714538122294068074) · [完整交接](../../docs/STEAM_ANNOUNCEMENT_20260913.md)。

顶层为 `schinese`、`tchinese`、`english`、`japanese`，每语固定 `title/subtitle/summary/body`。正文为四个普通段落：Windows更新已上线、原点击任务修复、黄泥冈携担显示与同伴接力、保存/继续尚未开放。无图片、BBCode、QA数字或源码哈希；未加入仅涉及内部实现调整的野猪林按钮说明。

| 语言 | 标题长度 | 副标题长度 | 摘要长度 |
| --- | ---: | ---: | ---: |
| 简体中文 | 16 | 20 | 63 |
| 繁体中文 | 16 | 19 | 62 |
| 英语 | 55 | 79 | 178 |
| 日语 | 21 | 29 | 82 |

保存后16个字段已逐项回读匹配；公开四语标题、副标题与4段正文共24片段精确匹配。[发布收据](../../qa/steam_announcement_20260913/publication_receipt.json) · [验证记录](../../qa/steam_announcement_20260913/validation.json)。人工目检仅简中公开全篇、日文/英文预览首屏。

封面复用服务器已有[800×450无文字图](https://clan.fastly.steamstatic.com/images/46272698/2105fa26234a9377723de86a7519262f3f5949cb.png)，使用英语槽，其他三语由Steam明确回退英语。本目录没有新图片；`.gdignore` 隔离Godot扫描。

维护时继续使用本Event，避免重复建公告。本轮没有修改游戏代码、包或商店语言表，未运行Godot；玩家推送、全部推荐位和退出登录访问没有纳入验证。玩家保存/继续入口仍未开放。
