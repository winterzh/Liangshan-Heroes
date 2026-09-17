# 2026-09-09 女性主视觉配套实机视频与截图

成片：`LiangshanHeroes-Gameplay-20260909.mp4`，45.000 秒视频流／1350 帧，1920×1080、30 FPS、H.264 High、AAC 48 kHz 立体声。标准 yuv420p、BT.709 limited range；视频码率约 6.79 Mbps。文件 39,360,487 字节，SHA256 `74dbdaec8c5bf8d64275ea0a76951ef9b83d1f7cd4739ce67c4a1236b6459657`。音频封装使容器时长为 45.109333 秒。

## 本次实际更新与来源

42 秒实机全部于 2026-09-09 重新录制，未复用或改名沿用 9 月 7 日旧视频。使用当前已发布 Steam Build **25200149**、Depot **5088121**、Manifest **7045932649257457621** 对应的验证包。功能源码提交为 `cf746f1a0864355df7f80cd4f18c6882088f4b7e`，发布 HEAD 为 `1102a9b629142524061a1b1fc005407c8da5fc07`；已发布包身份依据见 [发布记录](../../../docs/STEAM_LATEST_UPDATE_20260909.md)。

EXE SHA256 为 `f22a44e96b7a0f4b42f599b1d9177e53312bcb3cbd5a6c48484172b21369dc2d`。录制器先强制比对这个哈希，再由 Godot 4.6.3 Movie Maker 挂载其内嵌 PCK。当前开发源码 `5910b73` 中尚未发布的城防、快活林和黄泥冈入场改动不进入本片；本片代表上述已发布包的内容。

三个原片为祝家庄 65 秒、三败高太尉 65 秒、标准 30 波驻守的前 205 秒；各原片另有初始化约 4 帧，不选入成片。驻守只录到前几波，不声称完成 30 波。三次正式录制均退出 0，无脚本、资源或扩展加载错误。镜头时间线、原片及操作哈希见 `timeline.json`、`source_capture_summary.json`。

片尾 **42–45 秒**是已批准新女性主图的 16:9 衍生图 [promo_1920x1080.png](../promotional/promo_1920x1080.png)，SHA256 `c819ce62e7d4c9e972981127465256bcefe7ed883655cd0084bdb51eb216dc34`。它是宣传插画，不作为实机截图。插画没有混入前 42 秒的游戏画面；可独立作为本片缩略图。

## 拍摄与剪辑边界

记录器沿用已审查的 9 月 7 日正常指令：移动／攻击、工人付费建造、兵营付费训练、正常技能点学习与施法。驻守使用菜单已有 AI 友好模式。速度为 1，倍率开关关闭，未额外生成军队、补资源、改生命或伤害、移除迷雾、跳过任务。自动英雄到场、升级和托管由原游戏规则发生。独立 APPDATA 隔离本地玩家存档；分辨率、镜头、显示选项及隐藏 FPS 角标属于拍摄控制。原生 HUD、迷雾、正常选中圈和战斗状态均保留。

声音全部来自游戏原有程序音乐与音效，仅做接缝淡入淡出和整体音量规范。剪辑器新增统一 BT.709 limited 色彩转换，避免实机 MJPEG 原片与插画片尾混用色彩范围。没有合成玩法、补帧、外部配乐或配音。

首次试录使用普通 Godot 主机，因缺发行包配套 Steam DLL 出现扩展加载错误，随后中止。该诊断保留在被忽略的 `raw/zhu/`，不贡献任何成品画面或声音。正式三段改用已验证候选的 `probe_host/Godot.exe` 与配套 DLL；正式片源均位于 `raw/verified/`。失败尝试不计入正式通过项。

## 五张未加工实机原图

所有截图都是 1920×1080 viewport 直接保存的 PNG；复制后的 SHA256 与原件一致，没有裁切、调色、加字、增画或修改游戏内容。哈希与来源见 `screenshot_qa.json`。

| 文件 | 实际来源 | 内容 |
| --- | --- | --- |
| `screenshots/01_campaign_army.png` | 祝家庄 40 秒 | 宋江、林冲和部队交战；有小块暗红地面痕迹 |
| `screenshots/02_naval_fleet.png` | 水战 5 秒 | 船队移动，非战斗画面 |
| `screenshots/03_liangshan_base.png` | 驻守 40 秒 | 忠义堂、寨门与基地准备，非战斗画面 |
| `screenshots/04_camp_construction.png` | 祝家庄 10 秒 | 工人建造与营地资源，非战斗画面 |
| `screenshots/05_naval_combat.png` | 水战 35 秒 | 船只交火，有箭矢和伤害数字 |

以上是画面内容描述，不是年龄评级。`contact_sheet.jpg` 是九格审片联系表，不能冒充 Steam 原生实机截图。

## 本地检查与复现

独立复核发现7–13秒段的额外宣传字幕遮住金矿局部信息，已只重编码该6秒段并移除字幕／底板。其他七段MP4的SHA逐一不变，见 `caption_correction.json`；修正版9秒原尺寸抽帧已复核，金矿标签与完整血条恢复可见。旧版MP4、联系表和收据保留在被忽略的 `edit_work/review_before_caption_fix/`。原生界面仍有局部拥挤：第一张截图最右选中头像部分出画，一些世界标签与HUD重叠；不声称所有文字都无遮挡。

完整成片解码退出 0，错误输出为空；视频流严格 45 秒／1350 帧。未检出持续 0.3 秒以上的近全黑序列；开头／结尾短淡入淡出为有意剪辑。实际成片音频约 **−16.25 LUFS、−0.24 dBTP**；`audio_analysis.log` 中的 input 字段才是成品测量值，output 字段只是分析器重新规范后的估计值。音频检查包含完整解码和数值分析，不声称真人完整试听。具体参数见 `ffprobe.json`、`final_qa.json`。

成片联系表秒点为 2、9、16、21、26、32、38、42.5、44 秒。原生帧与联系表已经目检，独立抽样视觉复核已通过，记录见 [video_review.json](../../../qa/steam_store_media_20260909_female/video_review.json)。独立检查包括五张原图、两版九格联系表、初版八个1080p抽帧及修正版9秒帧；未重新播放全部时段。Steam 上传、转码、排序和公开播放由根任务另行核验。

在工程根目录重剪已有原片：

```powershell
py -3 -X utf8 marketing/steam_store_20260909_female/video/edit_trailer.py --timeline marketing/steam_store_20260909_female/video/timeline.json --output marketing/steam_store_20260909_female/video/LiangshanHeroes-Gameplay-20260909.mp4 --source-root . --work-dir marketing/steam_store_20260909_female/video/edit_work
py -3 -X utf8 marketing/steam_store_20260909_female/video/verify_delivery.py
```

复录用本目录 `record_gameplay.py`，必须传入匹配哈希的发行包和带配套 DLL 的 Godot 主机：`--godot`、`--pack`、`--expected-sha256`、`--shot zhu|naval|defense`、`--output-root`。祝家庄本批使用 `--duration 65`，其他两段使用默认时长。相同种子也不承诺重新录制逐字节一致；重录后必须重新做目检。验证脚本只自动判定文件／参数，不自动通过新的人工目检。

`raw/` 与 `edit_work/` 已在本目录忽略，原始 AVI、失败尝试、隔离用户数据和转码中间文件只留本机。上传范围为 MP4 与五张截图；审片图片、收据和脚本供追溯，不作为商店截图上传。本批不修改 runtime、不启动浏览器、不操作 Git 或外部发布。
