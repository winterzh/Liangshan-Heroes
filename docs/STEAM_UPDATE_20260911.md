# 2026-09-11 Windows Steam 更新与交接

## 1. 本次玩家可见改动

1. **底部指挥栏智能收起**：无选中单位/建筑时，底部栏收到矮条（小地图+提示），选中后恢复完整头像、属性与命令卡。
2. **祝家庄接应提示**：偏门接应成功时不再堆叠重复提示；键位帮助在提示出现时临时隐藏，避免右侧文字叠字。
3. **战役稳定**：第三章出征黑屏、偏门自动砍门等阻断此前已修；本包为最新源码。

## 2. 构建成品

- 构建工具：`tools/build_steam_release_zip.py`
- ZIP：`D:\CodexTemp\steam_release_20260911\LiangshanHeroes_Steam_build_20260911.zip`
- ZIP 字节数：252,070,601
- ZIP SHA256：`cb1f7a25ed857ab282e4daab87c34b096c927eaaf61fae3ef82b695b768d026b`
- EXE SHA1：`4c25db57fc72111077b922bb9cc8da119b6c27d0`
- Smoke：退出码 0

### 文件清单（6 项）：
| 文件名 | 大小 (Bytes) | SHA1 |
| --- | ---: | --- |
| GODOTSTEAM_LICENSE.txt | 1,110 | 3891aeb1976703fc639c168329d90e27c7680a68 |
| LiangshanHeroes.exe | 320,348,816 | 4c25db57fc72111077b922bb9cc8da119b6c27d0 |
| libgodotsteam.windows.template_release.x86_64.dll | 3,961,344 | c056eb4e85d902bd548dc9efb22a416b9c658dda |
| steam_api64.dll | 319,128 | 05ea59cc2b15a10c66277659d5d0b51750460d28 |
| steam_stats_reader.dll | 352,768 | ac9a932af32cef47cb41a80fc766fd2a401b13ba |
| STEAM_STATS_READER_GODOT_CPP_LICENSE.txt | 1,093 | 0b594319d5af0b833d7c0da47459b7d51e1fdbd2 |

## 3. Steam 上传

- AppID：5088120
- Depot：5088121
- **BuildID：25250466**
- **ManifestID：416479225955196133**
- 上传：SteamCMD SteamPipe，缓存登录 `gaojing666`
- Preview 与 Upload 均 exit 0；实际增量上传约 12.4 MB（仅 EXE chunk）
- **Set Live**：已完成。SteamCMD `app_info_print` 回读 **public buildid = 25250466**
- **公告**：用户已在 Steamworks 发布

## 4. 更新公告草稿

见 `docs/STEAM_ANNOUNCEMENT_20260911_draft.md`
