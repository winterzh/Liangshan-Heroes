# 四语公告与商店语言表 QA

公告 **708907988310559012** 已于北京时间（UTC+8）**2026-09-08 16:39** 发布成功，类型为“小型更新/补丁说明”，关联 default **Build25182453**；后台公开可见。[公开页](https://store.steampowered.com/news/app/5088120/view/708907988310559012) · [完整发布说明](../../docs/STEAM_LOCALIZATION_ANNOUNCEMENT_20260908.md)。

## 证据入口

| 文件 | 内容 |
| --- | --- |
| [copy.json](../../marketing/steam_localization_announcement_20260908/copy.json) | 简中、繁中、英文、日文的标题、副标题、摘要、BBCode 原稿和四图占位符 |
| [rendered_copy.json](../../marketing/steam_localization_announcement_20260908/rendered_copy.json) | 替换 Steam 图片引用后的正文，每语四图及四条图注 |
| [images.json](../../marketing/steam_localization_announcement_20260908/images.json) | 四张原图和封面的来源、大小、尺寸、SHA256、上传引用与状态 |
| [publication_receipt.json](publication_receipt.json) | 公告/商店发布状态、语言页回读、封面保存及回退依据 |
| [validation.json](validation.json) | 本地文件与公开文案、图片、商店语言表检查结果 |

## 本地文案与原图

四语字段齐全，BBCode 配对正确，`rendered_copy.json` 与原稿替换四个图片占位符的结果一致。标题/副标题/摘要字符数分别为：简中 26/18/51，繁中 26/18/51，英文 57/67/147，日文 32/21/71，均满足 80/120/180 的编辑器限制。

四张正文截图的原件哈希、大小和 1280×720 尺寸核对一致；原件位于 `qa/text_review_20260908/screenshots/`，没有复制或修改像素。封面为既有 800×450 无文字水寨图，原件及 SHA256 见 `images.json`。

## 公开回读与人工目检

四个 `?l=schinese`、`?l=english`、`?l=tchinese`、`?l=japanese` 公开页的标题、副标题及每语 **14 个正文文本片段**均匹配。每语四张图片最终全部 `complete=true`，自然尺寸均为 **1280×720**。日语首读两张图片尚在加载，随后四张均加载完成。

已人工目检日语预览首屏，简中、英文、日文公开首屏，日语公开页末段及商店四语表。公开文本匹配和图片完整加载不等于所有语言页面布局均已逐张人工验收。

封面已上传至英文语言槽并由后台保存：[已上传封面](https://clan.fastly.steamstatic.com/images/46272698/2105fa26234a9377723de86a7519262f3f5949cb.png)。Steam 提示其他三语没有专属图片，依据官方机制回退英文；无文字图接受共用。自定义封面的证据范围是后台保存及官方回退机制，未声称各平台或各展示位露出均已验证。

## 商店语言表

App5088120 / 商店编辑项1280793 的 **revision 4→5** 已公开成功。后台差异仅新增英、日、繁中 `supported=true`；公开语言表确认简中、英、日、繁中仅“界面”勾选，音频与字幕均未标注。

本轮没有修改运行代码或 EXE，没有重跑 Godot；未把公告/语言表公开等同于客户端下载、玩家推送、完整通关或性能验收。该目录只存文档与收据，由 `.gdignore` 排除 Godot 扫描；正式版构建和分支身份沿用 [Steam 更新 QA](../steam_localization_update_20260908/README.md)。
