# 2026-09-13 四语更新公告发布交接

公告 **714538122294068074** 已公开发布，Steam显示开始时间为 **2026-09-13 06:16 HKT（UTC+8）**，类型为“小型更新/补丁说明”，关联正式default **Build25276077**。[公开公告](https://store.steampowered.com/news/app/5088120/view/714538122294068074) · [发布收据](../qa/steam_announcement_20260913/publication_receipt.json) · [验证记录](../qa/steam_announcement_20260913/validation.json)。

公告说明两项玩家可见修复：任务遵循原点击目标，避免误接途经的相邻任务；黄泥冈挑担人倒下后清理携担显示，落担仍可由同伴接力。四语均明确战斗中途保存与继续仍在开发、本次未开放，没有把内部恢复能力写为玩家可用。

## 四语回读

| 语言 | 公开页面 | 核对结果 |
| --- | --- | --- |
| 简体中文 | [schinese](https://store.steampowered.com/news/app/5088120/view/714538122294068074?l=schinese) | 标题、副标题及4段正文精确匹配 |
| 繁体中文 | [tchinese](https://store.steampowered.com/news/app/5088120/view/714538122294068074?l=tchinese) | 标题、副标题及4段正文精确匹配 |
| 英语 | [english](https://store.steampowered.com/news/app/5088120/view/714538122294068074?l=english) | 标题、副标题及4段正文精确匹配 |
| 日语 | [japanese](https://store.steampowered.com/news/app/5088120/view/714538122294068074?l=japanese) | 标题、副标题及4段正文精确匹配 |

保存后逐语回读 `title/subtitle/summary/body`，共16个字段与[定稿copy.json](../marketing/steam_announcement_20260913/copy.json)全部匹配。公开页每语核对标题、副标题和4段正文，合计24个文本片段精确匹配；不将后台摘要校验算作公开正文。人工目检范围为简中公开全篇、日文和英文预览首屏，没有声称全部语言公开页面均已逐屏目检。

## 封面与范围

复用服务器已有的[800×450无文字封面](https://clan.fastly.steamstatic.com/images/46272698/2105fa26234a9377723de86a7519262f3f5949cb.png)，保存于英语槽，Steam明确提示其余三语回退英语。没有生成新图片，不把英语回退机制扩大为全部推荐位实际露出已验收。

本轮只更新公告及四语文本，没有修改游戏代码、安装包或商店语言表，也未运行Godot测试。公告发布不等于玩家推送、客户端下载、全部推荐位或退出登录访问验证。Build25276077的打包、服务器文件和正式上线证据仍见[Windows发布交接](STEAM_UPDATE_20260913.md)；最初上传阻塞、候选及发布原始JSON保持原样。

维护本公告使用已有Event714538122294068074，文案来源与字段说明见[marketing交接](../marketing/steam_announcement_20260913/README.md)，公开回读证据见[QA目录](../qa/steam_announcement_20260913/README.md)。
