# 四语公告与商店语言表发布记录

四语公告 **708907988310559012** 已于北京时间（UTC+8）**2026-09-08 16:39** 发布成功，后台状态为公开可见。类型为“小型更新/补丁说明”，关联 **default Build25182453**。[公开公告](https://store.steampowered.com/news/app/5088120/view/708907988310559012) · [发布与验证收据](../qa/steam_localization_announcement_20260908/README.md)。

公告说明在原有简体中文基础上新增繁体中文、英语和日语，以及 108 人图鉴校订和 UI 改进；语言切换入口为主菜单左上角或设置顶部。原著校订依据一百二十回本，文案区分原著记载与游戏改编，没有声称官方授权、无故障或完成玩家继续功能。

## 四语公开回读

| 语言 | 公开页 | 验证结果 |
| --- | --- | --- |
| 简体中文 | [schinese](https://store.steampowered.com/news/app/5088120/view/708907988310559012?l=schinese) | 标题、副标题及 14 个正文文本片段匹配 |
| 英语 | [english](https://store.steampowered.com/news/app/5088120/view/708907988310559012?l=english) | 标题、副标题及 14 个正文文本片段匹配 |
| 繁体中文 | [tchinese](https://store.steampowered.com/news/app/5088120/view/708907988310559012?l=tchinese) | 标题、副标题及 14 个正文文本片段匹配 |
| 日语 | [japanese](https://store.steampowered.com/news/app/5088120/view/708907988310559012?l=japanese) | 标题、副标题及 14 个正文文本片段匹配 |

每语正文均使用相同的四份实机原图：英文主菜单、英文武松生平、日文武松生平、繁体中文武松生平。四语公开页每张图最终均为 `complete=true`，自然尺寸 1280×720。日语页面首次读取时两张图片仍在加载，后续回读确认四张全部完成，不把首读状态当作缺图。

人工目检包括日语预览首屏，简中、英文、日文公开首屏，日语公开页末段及商店四语表。上述文本/图片加载检查不等于逐语逐页所有视觉布局均已人工验收。

## 图片来源与封面边界

正文图片直接复用 `qa/text_review_20260908/screenshots/` 中的四份原件，没有复制或修改像素。原件 SHA256、大小、尺寸及四个 Steam 图片引用见 [images.json](../marketing/steam_localization_announcement_20260908/images.json)。

封面复用 [800×450 无文字水寨图](steam_announcement_20260901/event_cover_800x450_english_v2.png)，已上传并保存到英文语言槽：[Steam 封面](https://clan.fastly.steamstatic.com/images/46272698/2105fa26234a9377723de86a7519262f3f5949cb.png)。Steam 提示另外三种语言没有专属图片，将回退英文；该图没有文字，因此接受共用。这里的依据为后台保存状态和 Steam 官方语言图片回退机制，具体记录见 [publication_receipt.json](../qa/steam_localization_announcement_20260908/publication_receipt.json)。未把这一结果表述为各平台、各推荐位的封面露出均已验证。

## 商店语言支持表

App **5088120** 的商店编辑项 **1280793** 已从 **revision 4 更新并公开为 revision 5**。后台差异仅新增 `english`、`japanese`、`tchinese` 的 `supported=true`，保留已有简体中文界面支持。公开商店语言表已核对如下：

| 语言 | 界面 | 完整音频 | 字幕 |
| --- | --- | --- | --- |
| 简体中文 | 勾选 | 未标注 | 未标注 |
| 英语 | 勾选 | 未标注 | 未标注 |
| 日语 | 勾选 | 未标注 | 未标注 |
| 繁体中文 | 勾选 | 未标注 | 未标注 |

“未标注”描述本次商店表的状态，不把本次语言声明扩展为配音或字幕承诺。游戏二进制仍为已发布的 default Build25182453，本轮没有修改运行代码、重建 EXE 或重跑 Godot。

## 文案与维护文件

- [copy.json](../marketing/steam_localization_announcement_20260908/copy.json)：四语原稿和图片占位符；标题最多 80 字符、副标题最多 120、摘要最多 180。
- [rendered_copy.json](../marketing/steam_localization_announcement_20260908/rendered_copy.json)：已填入四个 Steam 图片引用的四语正文，每语四条实机图说明。
- [images.json](../marketing/steam_localization_announcement_20260908/images.json)：图片来源、哈希、尺寸、上传引用与封面状态。
- [publication_receipt.json](../qa/steam_localization_announcement_20260908/publication_receipt.json)、[validation.json](../qa/steam_localization_announcement_20260908/validation.json)：公告和商店发布、公开回读及文件验证证据。

本轮公开页验证不等于实际客户端下载或玩家推送验收；没有重测通关、长时性能或双机联机。此前正式版打包、同包验证和分支激活仍以[四语正式版记录](STEAM_LOCALIZATION_UPDATE_20260908.md)为准，旧批次说明保留历史语境。
