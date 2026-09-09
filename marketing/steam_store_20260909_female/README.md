# 2026-09-09 女性前景版 Steam 宣传媒体

主视觉采用用户重新上传并明确说“用这张吧”的封面：女性角色在前景，宋江与林冲在后景，正式标题“水浒英雄传”、副标题“八幕战役”。用户随后要求宣传图、配图和配套视频一起更新。

## 投放状态

商店8张封面已于revision6发布；本轮6张库图和5张新实机截图已于revision7发布，Steam均返回`Successfully published!`。原6张商店截图已替换。新图库实际顺序为01、02、05、03、04（战役、舰队、水战、营寨、建造），公开简中页5张缩略图及1920×1080原尺寸资源全部加载完成，并已目检公开页。两张战斗截图all_ages=0，其余3张=1；不据此宣称获得商店以外的推荐展示资格。

库图英语及简中槽位正确。Steamworks放置工具1231px宽预览中，原透明Logo位于左侧景物区、未遮人物，无黑底或双标题，三位主要人物脸部完整；没有调整Logo位置，未核对实际Steam客户端或窄窗口裁切。

最新公告[任务界面小更新与续玩开发进展](https://store.steampowered.com/news/app/5088120/view/714538122294067212)的800×450分享封面此前已保存并回读四语元数据。当前22份媒体中20份已投放，**只剩45秒视频和1920×1080视频缩略图未上传、未发布**。现有旧视频仍保留，Edge已打开其替换拖放入口。

[操作交接](UPLOAD_GUIDE.md)与[发布收据](../../qa/steam_store_media_20260909_female/PUBLISH_STATUS.json)分项记录当前状态及早先控件受阻历史，不以本地完成代替公开验证。

## 交付

| 用途 | 文件 | 尺寸 |
| --- | --- | --- |
| 主宣传图 | [main.png](capsules/main.png) | 1232×706 |
| 商店标题图 | [header.png](capsules/header.png) | 920×430 |
| 小宣传图 | [small.png](capsules/small.png) | 462×174 |
| 商店竖图 | [vertical.png](capsules/vertical.png) | 748×896 |
| 库竖版封面 | [library_capsule.png](library/library_capsule.png) | 600×900 |
| 库标题图 | [library_header.png](library/library_header.png) | 920×430 |
| 库横幅背景 | [library_hero.png](library/library_hero.png) | 3840×1240 |
| 视频缩略图/宣传配图 | [promo_1920x1080.png](promotional/promo_1920x1080.png) | 1920×1080 |
| 公告配图 | [announcement_800x450.png](promotional/announcement_800x450.png) | 800×450 |

前七种均有逐字节相同的`_schinese`副本。未追加新库Logo，保留既有透明Logo；横幅实际叠放与客户端裁切待上传后核对。横幅从2206×713普通缩放并裁去底部1像素得到目标尺寸，不是原生4K细节。

配套[实机视频和截图](video/README.md)使用当前已发布Build25200149对应游戏包重新录制。最后三秒为本套16:9宣传插画，与实机段落明确分开；插画不进入游戏截图栏。此前尚未发布的城门/攻城和黄泥冈改动不混入当前公开版宣传。具体片长、编码、截图、声音检查及来源以视频子目录收据为准。

## 来源与验证

用户原图逐字节保存于[source/main_approved.png](source/main_approved.png)，SHA256为`543d3b6298be9d49eb00752c7e5d2ac7a797e76e35c180051c4f2a1ae96510de`。主宣传图只规范尺寸，未重画、镜像或更换标题；其他比例通过内置`image_gen`依照定稿重新布局，保留原生输出。它们是生成式布局适配，不能称为无损裁图。

完整提示词与处理链见[主图来源](main_provenance.json)、[横版与小图](header_small_manifest.json)、[两种竖图](vertical_library_manifest.json)、[库横幅](library_hero_manifest.json)、[16:9配图](promotional_manifest.json)。所有当前输出的尺寸、SHA和语言副本对应见[统一素材清单](art_manifest.json)；独立目检见[art_review.json](../../qa/steam_store_media_20260909_female/art_review.json)。小图补看了231×87预览，主标题可读、副标题较小；尚未验收Steam客户端真实显示。

在项目根目录运行`py -3.14 -X utf8 -B marketing/steam_store_20260909_female/prepare_art.py`可核对已交付PNG并刷新清单。显式`--rebuild`才会重做尺寸规范，不调用生成模型、不改原始来源。生成模型再次运行不保证相同画面，FFmpeg版本变化也可能改变PNG哈希。

`build_upload_bundle.py --output-dir <新目录>`把22个最终媒体文件分成五组，并逐一回读SHA；不会包含原生生成图、脚本、拼图或原始AVI。目录已有不同内容的同名文件时拒绝覆盖。本目录由上级`marketing/.gdignore`排除Godot扫描，本批不改变游戏菜单、运行资源或Steam游戏包。
