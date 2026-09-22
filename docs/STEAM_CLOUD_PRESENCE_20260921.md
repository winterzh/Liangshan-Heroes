# Steam 云存档与好友状态（2026-09-21）

本批实现战役进度/个人设置的 Steam Cloud 同步，以及好友列表 Rich Presence。范围严格限定：只同步已稳定进度，不含战斗中途续玩档；不创建 Release、不改 Steam 默认构建、不开放工坊。

## 玩家可见

- 好友列表显示当前状态：主菜单、具体战役关卡、据守梁山波次、遭遇战/AI/竞技场/自定义，以及是否暂停。
- 文案四语：`status_zh_CN` / `status_zh_TW` / `status_en` / `status_ja`，并写 `status`（当前游戏语言）与 `steam_display=#Status`（供 Steamworks Localization 按好友语言映射）。
- 换电脑后保留战役进度、演义印与个人设置（音频/画面/按键/语言）。

## 实现边界

| 项目 | 约定 |
|---|---|
| 云文件 | `liangshan_profile_v1.json`（JSON UTF-8） |
| 本地镜像 | `user://steam_cloud_profile.json`（仅本机，不进 Git） |
| 进度合并 | `cleared`/`story_complete` 取并集；`best_*` 保留单局最优目标集，禁止跨局拼接演义印 |
| 账号隔离 | payload 绑定 SteamID；换账号不写回、不覆盖他档 |
| 离线/失败 | 保留本地 dirty，30 秒后重试；不把失败写成已同步 |
| 旧档恢复 | 云为空且本地有进度 → 合并后上传 |
| 续玩 | 战斗中途存档/世界恢复不在本批云同步范围 |
| 普通启动 | 无 `steam` 导出特性或测试环境时完全 no-op |

## Steamworks 后台

- Cloud 已有工坊配额；本批使用 ISteamRemoteStorage API，**不**配置 Auto-Cloud 玩家存档规则。
- Rich Presence 语言映射（可选）：在 Steamworks 为 token `#Status` 配置四语；未配置时好友看到玩家当前游戏语言的 `status`。

## 复现

```powershell
python -X utf8 -B tools/run_steam_cloud_presence_qa.py
```

自动测试仍走 `tools/steam_fake_api.gd` 的 fileWrite/fileRead/setRichPresence 模拟，不连真实账号。

## 证据

见 [qa/steam_cloud_presence_20260921/README.md](../qa/steam_cloud_presence_20260921/README.md)。
