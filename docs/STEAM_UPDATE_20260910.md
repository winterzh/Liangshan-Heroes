# 2026-09-10 Windows Steam 更新与交接

本轮完成第三章“三打祝家庄”严重阻断问题修复、构建新发行版并更新上线 Steam。

## 1. 核心修复与改进

1. **排除快照类名缓存污染导致黑屏**：
   - 在 `qa/`、`scratchpad/`、`tools/` 根目录补充 `.gdignore`；
   - 修复 `.godot/global_script_class_cache.cfg` 中 `Battle` 全局类被历史快照覆盖导致主场景编译崩溃、屏幕纯黑的问题；
   - 修复开场旁白期间迷雾初始照射问题（`_ready()` 阶段调用 `_fog_pass(0.0)`），确保对话期间背景营地与大军正常呈现。
2. **三打祝家庄偏门内应（孙立/宋江开门）卡死与误攻修复**：
   - 偏门添加元数据 `side_gate.set_meta("campaign_no_auto_target", true)`，彻底避免部队空闲时自动拔刀砍门；
   - 3 号旗标内应任务操作人放宽至 `["sun_li", "song_jiang", "lin_chong", "hua_rong"]`，触发与点击半径扩至 96 像素；
   - 新增右键偏门智能重定向保护：在潜入开门任务激活期间，若选中有英雄右键点击偏门建筑，系统拦截普通攻击指令并转为偏门前接应，弹出指引提示；
   - 旗标交互优化：当玩家右键点击任务旗标但单位不符时，弹出清晰的屏幕提示（Toast）。

## 2. 构建成品与校验

- 构建工具：`tools/build_steam_release_zip.py`
- 上传 ZIP 路径：`D:\CodexTemp\steam_release_20260910\LiangshanHeroes_Steam_build_20260910.zip`
- ZIP 字节数：252,063,949 字节
- ZIP SHA256：`bfa60738c4098eed029c806296288f3c61b3a197055ca8bbd22343cd922740e3`
- 桌面测试包备份：`C:\Users\rsb\Desktop\LiangshanHeroes_Steam_build_20260910.zip`
- 桌面试玩快捷方式：`C:\Users\rsb\Desktop\试玩最新Steam成品.lnk`

### 文件清单（6 项）：
| 文件名 | 大小 (Bytes) | SHA1 | SHA256 |
| --- | ---: | --- | --- |
| `GODOTSTEAM_LICENSE.txt` | 1,110 | `3891aeb1976703fc639c168329d90e27c7680a68` | `4b72012dba000de1e0b4c0183e5ed99f4fe8e949f50e570442f692ce3995bae2` |
| `LiangshanHeroes.exe` | 320,345,760 | `299466629f79665ba9c89a11f6ddfbd623cb1e18` | `b10099c574894e30a07f6ae884ae9f8dd9f841ee216e6ff945af143b72270933` |
| `libgodotsteam.windows.template_release.x86_64.dll` | 3,961,344 | `c056eb4e85d902bd548dc9efb22a416b9c658dda` | `b7a6316bb866691d01d311e181b76b0fe0c38602913725d1589083bee1db7f26` |
| `steam_api64.dll` | 319,128 | `05ea59cc2b15a10c66277659d5d0b51750460d28` | `8de54d32508e216c9135b8bf025749243d44e404c1c22a8e5fe35acecabe7a9c` |
| `steam_stats_reader.dll` | 352,768 | `ac9a932af32cef47cb41a80fc766fd2a401b13ba` | `be9ea866c3e922fc0ddd40f97dede0bab7fd37a9393ad11307b91bba6e70ce6a` |
| `STEAM_STATS_READER_GODOT_CPP_LICENSE.txt` | 1,093 | `0b594319d5af0b833d7c0da47459b7d51e1fdbd2` | `26a5b210d90760156ce886267ce9df235787dcc6cebfd7ecd95ef5b6fdcc95bf` |

## 3. Steam 部署与发布记录

- **目标 AppID**：5088120
- **目标 Depot**：5088121 ("水浒英雄传: 八幕战役 Content")
- **Depot ManifestID**：`4469374751738838844`
- **上传通道**：SteamPipe HTTP Upload（标准模式）
- **上线分支**：`default`
- **更新公告**：
  - 中文标题：`【更新】战役关卡优化与第三章“三打祝家庄”体验修复`
  - 英文标题：`[Patch Notes] Campaign Fixes & Chapter 3 "Zhu Family Manor" Improvements`
  - 公告类型：小型更新 / 补丁说明（Patch Notes）
