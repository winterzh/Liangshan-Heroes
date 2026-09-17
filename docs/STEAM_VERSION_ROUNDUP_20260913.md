# 2026-09-13 四语图文版本汇总发布交接

图文汇总公告 **714538122294068076** 已公开，Steam显示活动时间 **2026-09-13 06:49 HKT（UTC+8）**，类型为“重大更新”，关联正式default **Build25276077**。发布界面返回“发布成功完成。”并显示公开可见。[公开公告](https://store.steampowered.com/news/app/5088120/view/714538122294068076) · [发布收据](../qa/steam_version_roundup_20260913/publication_receipt.json)。

本篇汇总截至9月13日近期陆续上线的内容，包含四语界面切换、现有108人生平校订、第三章黑屏与偏门任务修复、指挥栏收起/展开和提示叠字处理、原点击任务认领、黄泥冈携担显示及Steam统计异常提示。公告类型用于这次综合图文介绍，没有新增游戏包、版本号、章节或108人阵容。正文明确战斗中途保存与继续仍在开发，尚未开放。

## 四语正文与配图

四语均有5节正文及3张实机图。保存后的16个字段逐项精确匹配；公开页每语21个可见片段（标题、副标题及19个正文非空段/小标题/图注），合计84片段在去除BBCode图片/格式标签并规范空白后完整匹配。摘要仅在后台核对，不计入公开84片段。[完整验证记录](../qa/steam_version_roundup_20260913/validation.json)。

| 语言 | 公开链接 | 图鉴配图 |
| --- | --- | --- |
| 简体中文 | [schinese](https://store.steampowered.com/news/app/5088120/view/714538122294068076?l=schinese) | 9月8日繁体中文武松生平 |
| 繁体中文 | [tchinese](https://store.steampowered.com/news/app/5088120/view/714538122294068076?l=tchinese) | 9月8日繁体中文武松生平 |
| 英语 | [english](https://store.steampowered.com/news/app/5088120/view/714538122294068076?l=english) | 9月8日英文武松生平 |
| 日语 | [japanese](https://store.steampowered.com/news/app/5088120/view/714538122294068076?l=japanese) | 9月8日日文武松生平 |

各语另共用9月8日英文主菜单和9月9日祝家庄营地画面。四语共12处图片均加载完成，每语自然尺寸依次为1280×720、1280×720、1920×1080。营地图来自已发布Build25200149的商店截图，正文复用Steam现有JPEG；来源PNG的SHA不等于该JPEG的字节哈希。配图用于展示功能和场景，不作为9月13日修复后的现拍对比。[来源、尺寸及引用](../marketing/steam_version_roundup_20260913/images.json)。

人工目检为日语预览首屏与中部（覆盖三图）、简中预览尾部、英文公开首屏（长标题及首图清楚）。这些观察与84片段/12处图片的程序核对分别记录，不声称所有语言整页均已逐屏目检。

封面复用800×450无文字梁山风景图，保存于英语槽，其余三语由Steam明确回退英语；没有生成新图。不将图片加载或英语回退规则扩大为所有推荐位封面露出、全部页面人工目检或玩家推送验证。

## 维护入口与范围

- [copy.json](../marketing/steam_version_roundup_20260913/copy.json)：四语定稿与三个配图占位。
- [rendered_copy.json](../marketing/steam_version_roundup_20260913/rendered_copy.json)：已替换各语实际图片引用的发布正文。
- [transfer_checks.json](../marketing/steam_version_roundup_20260913/transfer_checks.json)：最终字段长度与传输对照值；[文案交接](../marketing/steam_version_roundup_20260913/README.md)列出准确长度。

本轮只发布图文公告和交接记录，没有修改游戏代码、安装包或商店语言表，没有运行Godot测试。原小型修复公告 **714538122294068074** 保留公开与原始证据，[旧公告交接](STEAM_ANNOUNCEMENT_20260913.md)不被本篇替代；Build25276077的正式上线仍以[发布交接](STEAM_UPDATE_20260913.md)为准。后续维护综合图文使用新Event714538122294068076，避免重复创建。客户端更新、真实Steam持久确认、玩家保存/继续开放及其他玩法验收边界没有改变。
