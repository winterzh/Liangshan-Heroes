# 2026-09-07 Steam 商店素材

本目录保存《水浒英雄传：八幕战役》的四种新商店封面、三种游戏库图片、45 秒实机宣传片、五张原生游戏截图、生成提示词、复现脚本，以及中英文商店文案。封面采用宋江、林冲与普通部队的水浒题材插画，标题为“水浒英雄传”，副标题为“八幕战役”。

## 状态与使用范围

2026-09-07 本次状态更新时：四种商店封面和三种游戏库图片已完成本地交付及检查；这些新图片尚未上传或发布。中英文概述和长介绍已由主任务在 Steam revision 4 发布，后台显示 `Successfully published!`，并已从公开中文商店页回读新文案。下文分别记录文字、标签和图片的状态，不以文字发布成功推断图片已替换。

实机宣传视频和五张配套截图已完成本地制作、验证及独立复核。所有新媒体的 Steam 上传、视频转码、排序及公开发布仍为 **pending**，须由主任务另行核实并补充收据。

统一风格的 Steam 游戏库素材由 `store_library_art` 制作，已交付竖版封面、标题图和横幅背景三种，详见下方清单。现有透明库 Logo 经主任务检查 Steam 画面后确认清晰可保留；两次新 Logo 生成结果均不是真透明图，不投放。

封面与游戏库 PNG 是生成式插画，**只作为商店与游戏库展示图使用，不得冒充游戏实机截图或宣传片中的实机画面**。宣传片最后 3 秒使用封面作为明确的插画结束卡，其余部分来自经过验证的游戏包。

## 封面交付清单

| Steam 位置 | 通用文件 | 简体中文文件 | 像素尺寸 | 每份大小 |
| --- | --- | --- | --- | ---: |
| 主宣传图 | `capsules/main.png` | `capsules/main_schinese.png` | 1232 × 706 | 1,769,146 字节 |
| 标题宣传图 | `capsules/header.png` | `capsules/header_schinese.png` | 920 × 430 | 849,836 字节 |
| 小型宣传图 | `capsules/small.png` | `capsules/small_schinese.png` | 462 × 174 | 163,746 字节 |
| 竖版宣传图 | `capsules/vertical.png` | `capsules/vertical_schinese.png` | 748 × 896 | 1,408,604 字节 |

每种 `_schinese` 文件与对应通用文件逐字节相同，均保留正式中文名称。`capsule_manifest.json` 记录四份原生来源与四种交付 PNG 的 SHA-256、尺寸、大小和语言副本对应关系，上传时按位置匹配，不以文件名推断后台已替换成功。

## 游戏库交付清单

| Steam 游戏库位置 | 通用文件 | 简体中文文件 | 像素尺寸 | 每份大小 |
| --- | --- | --- | --- | ---: |
| 游戏库竖版封面 | `library/library_capsule.png` | `library/library_capsule_schinese.png` | 600 × 900 | 1,135,007 字节 |
| 游戏库标题图 | `library/library_header.png` | `library/library_header_schinese.png` | 920 × 430 | 849,836 字节 |
| 游戏详情横幅背景 | `library/library_hero.png` | `library/library_hero_schinese.png` | 3840 × 1240 | 6,931,360 字节 |

`library/library_manifest.json` 记录来源、处理步骤、交付哈希与限制；三组语言副本均逐字节相同。标题图直接复用已验证的商店标题图。竖版来源为 1024 × 1536，按相同比例缩放；横幅来源为 2206 × 713，经普通 Lanczos 等比放大至 3840 × 1241 后去除底部 1 像素以符合交付尺寸，不代表原生 4K 细节。库图提示词见 `library/library_prompts.json`。

主任务已审阅 600 × 900 竖图与 3840 × 1240 横幅并通过。横幅左侧预留现有透明 Logo 的位置，实际 Steam 叠放和不同窗口裁切仍需上传后预览。

上传时只选表格列出的 `capsules/` 或 `library/` 交付 PNG，不整目录拖入。**不要拖入任何 `source/` 原图或 `library/failed_evidence/` 文件**。两份失败 Logo 是 RGB 图片，棋盘格已烘焙进画面，没有透明通道；它们仅作失败证据保存，不能当 Logo 上传。继续保留 Steam 现有透明 Logo。

## 实机视频与截图交付

成片：[LiangshanHeroes-Gameplay-20260907.mp4](video/LiangshanHeroes-Gameplay-20260907.mp4)。视频流为 **45.000 秒、1350 帧、1920 × 1080、30 FPS、H.264 High**，实际视频码率约 6.81 Mbps、容器整体约 7 Mbps；AAC 48 kHz 双声道。文件大小为 **39,460,768 字节**，SHA-256 为 `da79b227c4c37dac558f9d66183f6a7733b9dae8ba024ffab8fe63734f61af41`。容器因音频尾部报告 45.109333 秒，不是缺少或增加了视频帧。

录像来自源码 `443e75e887afd76f9569cae17b0527a72408aedc` 对应的已验证游戏包，Windows EXE SHA-256 为 `dcccc29d6ce880370f43a2d58048e974de7fb65544c2149d84b9abcb7c52b8ae`。拍摄只发正常游戏命令，没有额外生成军队、添加资源、恢复生命或移除战争迷雾；保留正常 HUD，音频来自游戏原生音频，无外部音乐。片尾 3 秒为宣传插画。Godot MovieWriter 离线输出的 30 FPS 是成片帧率，**不能用作实际运行稳定 30 FPS 的性能证明**。

五张截图均为原生 1920 × 1080 PNG，与录制时保存的原件逐字节相同；未裁切、重绘或添加营销字幕。建议在宣传片之后按下列顺序展示：

| 顺序 | 交付文件 | 内容及内容检查 |
| --- | --- | --- |
| 1 | [01_campaign_army.png](video/screenshots/01_campaign_army.png) | 英雄、部队和营地建筑；非战斗，未见血迹 |
| 2 | [02_naval_fleet.png](video/screenshots/02_naval_fleet.png) | 梁山寨前船队移动；非战斗，未见血迹 |
| 3 | [03_liangshan_base.png](video/screenshots/03_liangshan_base.png) | 梁山基地与经营区域；非战斗，未见血迹 |
| 4 | [04_camp_construction.png](video/screenshots/04_camp_construction.png) | 工人采集与建造；非战斗，未见血迹 |
| 5 | [05_naval_combat.png](video/screenshots/05_naval_combat.png) | 船只交火，有暴力内容，未见血迹 |

前四张可作为非战斗截图候选，第五张属于战斗截图；这是画面检查，不是正式年龄评级，不自动把五张或整条视频勾为全龄。成片另有地面交战和少量游戏血迹。只向宣传片位置上传上述 MP4，只向截图位置上传这五份 PNG；`video/contact_sheet.jpg` 是审片拼图，不上传为实机截图。

推荐使用顺序：先核对并上传四种商店封面及三种库图，再上传 MP4 并放在截图之前，随后按表内顺序上传五张截图；等待视频转码完成后检查播放、截图排序、库 Logo 叠放和公开预览，再记录媒体发布结果。完整来源、剪辑时间线、编码与检查见 [视频说明](video/README.md)、[视频收据](video/video_receipt.json)、[最终 QA](video/final_qa.json) 和 [截图 QA](video/screenshot_qa.json)。

## 来源与处理链

- 创作工具：内置 `image_gen`，生成日期为 2026-09-07；完整主图及三种构图变体提示词见 `prompts.json`。
- `source/main_native.png` 为主图；其余三份 `source/*_native.png` 为基于主图风格重新构图的生成结果，分别适配横幅、小图和竖版。
- 人物、背景、书法标题和不同画幅的创意布局均由图像生成工具完成。来源文件纳入本目录保存，不依赖另一台电脑的临时生成目录。
- `prepare_capsules.py` 仅用 FFmpeg Lanczos 缩放到目标尺寸，并复制简体中文副本；脚本不裁切、不重绘、不替换文字，也不合成角色。
- 独立视觉检查见 `../../qa/steam_store_media_20260907/capsule_review.json`；补充结构检查见同目录 `validation.md`。独立检查结论仅覆盖本地 PNG。

## 复现交付 PNG

需要 Python 3 和可从 `PATH` 调用的 FFmpeg。在项目根目录运行：

```powershell
py -3 -X utf8 marketing/steam_store_20260907/prepare_capsules.py
```

默认读取本目录已保存的 `source/*_native.png`，覆盖 `capsules/` 中八份交付图并重新写入 `capsule_manifest.json`。这是交付尺寸处理的复现，不是重新生成插画；再次调用生成模型可能得到不同画面。不同 FFmpeg 版本的编码输出也可能改变文件哈希，重新处理后应复核清单和图片。

若需要从原始图像生成输出目录重新导入来源文件，可额外传入 `--native-dir <目录>`。该目录需包含脚本 `ASSETS` 列出的四个原始 `exec-*.png` 文件。日常交接无需此参数，也不需要办公室机器的绝对路径。

## 商店文案

`store_copy.json` 保存 `short_schinese`、`short_english`、`about_schinese` 和 `about_english`。简体中文短描述以“率领梁山好汉，打八幕经典水浒战役。”开头，当前为 200 个 Unicode 字符；英文为 256 个字符。长描述使用 `[p]` 与 `[h2]` BBCode，列出当前八幕战役、驻守战、单人人机 1v1、竞技场与内置编辑器，英文明确界面语言为简体中文。

主任务已将中英文短、长描述保存并随 Steam revision 4 发布，后台显示 `Successfully published!`；公开中文页已回读新内容。该发布状态来自主任务的实际 Steam 操作与回读反馈，不是由本地 JSON 检查推断。公开英文页面的独立回读未记为已完成。

商店标签也已发布，重新载入标签向导回读为 18 项，前四项依次为“即时战略”“即时战术”“基地建设”“资源管理”；移除了“模拟”“城市营造”“贸易”。公开页面的标签概览已经变化，但“+”打开的社区标签弹窗仍显示旧缓存，因此不声称所有展示入口或缓存均已刷新。
