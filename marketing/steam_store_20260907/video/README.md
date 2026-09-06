# 2026-09-07 Steam 实机宣传片与截图

成片：`LiangshanHeroes-Gameplay-20260907.mp4`。45秒剪辑、1920×1080、30 FPS、H.264 High / AAC立体声。视频目标7 Mbps，实际视频流约6.81 Mbps、整体约7 Mbps；39,460,768字节（37.63 MiB）。容器因音频封装尾部报告约45.11秒，包含1350张视频帧。

## 来源与范围

- 源码提交：`443e75e887afd76f9569cae17b0527a72408aedc`。
- 本轮验证的Windows EXE SHA256：`dcccc29d6ce880370f43a2d58048e974de7fb65544c2149d84b9abcb7c52b8ae`。录制前强制比对哈希，并由Godot通过`--main-pack`读取该EXE的内嵌PCK。
- Godot 4.6.3 Movie Maker / Vulkan，原片即1920×1080、30 FPS；不采用升频补帧、AI生成玩法或其他游戏画面。
- 拍摄祝家庄、三败高太尉和标准30波驻守。记录器只发正常移动攻击、工人建造、付费兵营排队、花技能点学习和合法施法命令。驻守采用菜单已有的AI友好模式；倍率关闭，速度为1。
- 不生成额外军队，不修改资源、生命、伤害、战争迷雾或任务进度。英雄升级与驻守托管行为由游戏原逻辑产生。
- 镜头构图、显示设置及录制分辨率属于拍摄控制；保留原生HUD，仅隐藏FPS调试角标。用独立APPDATA隔离玩家存档，未修改生产代码。
- 音频全部是游戏原有的程序音乐与音效，做了接缝淡入淡出及音量归一化。最后3秒为本轮生成的宣传插画`../capsules/main.png`，不作为实机截图。

剪辑顺序与时间码见`timeline.json`。原片和逐条真实操作摘要、尺寸/帧数/哈希见`source_capture_summary.json`；成品编码参数见`ffprobe.json`，成品哈希见`video_receipt.json`。

终检见`final_qa.json`：整片解码退出0、无解码错误；视频流45.000秒/1350帧；九格成片联系表已目检，未见FPS、错误窗、贴图缺失或意外黑屏。实测音频约−16.28 LUFS、真峰值−0.58 dBTP，未超0 dBTP。独立复核再次实算MP4和五张PNG的大小/哈希并检查联系表、编码参数，结果通过。音频为完整解码和数值分析，未另做真人完整试听；Steam端转码及播放另验。

## 五张原生截图

所有PNG均为游戏viewport直接保存，复制后与原件SHA256一致，未裁切、调色、增画角色或添加宣传字幕。截图选择经录制任务和独立任务目检；详细判定见`screenshot_qa.json`。

| 文件 | 内容 | 血迹 | 正在发生的战斗/暴力 |
| --- | --- | --- | --- |
| `screenshots/01_campaign_army.png` | 英雄、编队与完成的营地建筑 | 未见 | 无 |
| `screenshots/02_naval_fleet.png` | 梁山寨前船队移动 | 未见 | 无 |
| `screenshots/03_liangshan_base.png` | 山前关、忠义堂与经营区域 | 未见 | 无 |
| `screenshots/04_camp_construction.png` | 工人采集与建民居 | 未见 | 无 |
| `screenshots/05_naval_combat.png` | 梁山船与官船交火，有箭矢和伤害数字 | 未见 | 有 |

前四张为非战斗候选；第五张不归入非战斗截图。以上是画面内容检查，不是正式年龄评级。成片中另含地面交战和少量游戏血迹。

## 复录与重剪

需要Windows、Godot 4.6.3、Python 3、FFmpeg/ffprobe，以及Windows黑体`simhei.ttf`。先准备上述哈希完全一致的EXE；不要用其他包冒充该来源。参数中的本机路径自行提供，不写入游戏启动脚本。

在仓库根目录，用PowerShell运行（原片必须写入被忽略目录）：

```powershell
$godotExe = (Get-Content -LiteralPath godot.local.txt -Raw).Trim()
$releaseExe = '本机已验证的 LiangshanHeroes.exe 完整路径'
foreach ($shot in @('zhu', 'naval', 'defense')) {
    py -3 -X utf8 marketing/steam_store_20260907/video/record_gameplay.py `
        --godot $godotExe --pack $releaseExe `
        --expected-sha256 dcccc29d6ce880370f43a2d58048e974de7fb65544c2149d84b9abcb7c52b8ae `
        --shot $shot --output-root .godot/steam_store_media_20260907/video
}
py -3 -X utf8 marketing/steam_store_20260907/video/edit_trailer.py `
    --timeline marketing/steam_store_20260907/video/timeline.json `
    --output marketing/steam_store_20260907/video/LiangshanHeroes-Gameplay-20260907.mp4 `
    --source-root . --work-dir .godot/steam_store_media_20260907/video/edit_work_final
```

过程音乐和正常战斗调度存在随机性，复录不保证与已保存原片逐字节一致；用已保存且哈希吻合的原片与时间线可以重剪。`record_gameplay.gd`的`_init`设置MovieWriter所需窗口覆盖尺寸，避免MovieWriter在场景初始化前沿用工程720p默认值；仅用`--resolution`不足以设置此版本的电影输出尺寸。依据[Godot Movie Maker说明](https://docs.godotengine.org/en/4.6/tutorials/animation/creating_movies.html)。

原始AVI、试拍、临时转码、导出EXE和独立用户数据均留在`.godot/`，不提交或上传。`contact_sheet.jpg`仅供审片，不作Steam实机截图。此目录准备可上传素材；Steam上传、转码、排序和发布结果由根任务单独记录。
