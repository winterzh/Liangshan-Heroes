# Steam Build 25460867 发布、平台配置与公告公开

## 2026-09-23 当前账号云上传验收

用户开启 Steam 云偏好后，GodotSteam 探针确认 App 与账号 Cloud 均为 `true`。先将实际玩家目录 172 个文件、13,230,342 字节完整备份并逐文件核对 SHA-256，再从 Steam 库启动 Build `25460867` 至主菜单并正常退出。战役进度等玩家文件未改变；生产云镜像的三项 dirty 标记由 `true` 转为 `false`，远端文件从不存在变为存在、大小 1,395 字节。Steam 客户端 `cloud_log.txt` 记录 `liangshan_profile_v1.json` 上传成功、同步结果 `OK`；Steam 账号[云文件页面](https://store.steampowered.com/account/remotestorageapp/?appid=5088120)也列出了这个 1.36 KB 文件。逐项证据见 `cloud_client_acceptance_20260923.json`。

因此当前账号的生产上传和服务器可见性已验收。跨设备下载后读回、第二账号隔离和读回仍未验收，`publication_receipt.json` 的整体 `complete` 及 `steam_cloud_player_acceptance` 继续为 `false`。下方 01:41 的 Cloud 偏好关闭记录是启用前的历史快照。

源码基线 `729892b0694406e591be585855a4590fd691d134` 已构建为 Windows 候选并上传。Steamworks 权威回读确认 `default` 为 Build `25460867`、Depot `5088121` / Manifest `2563454806170954821`；服务器、候选和 Steam 客户端六文件名称、字节数与 SHA-1 一致，客户端实际启动日志严格问题数为 0。

## 构建与回归

| 验证 | 结果 |
|---|---:|
| 原生 Steam QA | 185 项通过 |
| 包检查 | 1,136 项通过 |
| 来源/内容身份 | 10 + 10 项通过 |
| 实际 EXE 烟测 | 11/11 |
| 完整 RTS 复查 | 740/740 |
| 默认场景 180 帧 | 退出 0，问题行 0 |

完整复查使用工程外冻结副本和私有 profile，设置 `STEAM_DISABLED=1`、`CAMPAIGN_QA=1`，没有加载玩家数据。3347 份来源的冻结副本与工作区漂移均为 0。逐组日志和收据见 `recheck_20260922_233500/`。

## 2026-09-23 平台配置公开

Steamworks 应用配置已发布并回读：Cloud 对普通玩家开放，动态云同步关闭；Rich Presence 的四语 `#Status` 分别映射 `status_en`、`status_zh_CN`、`status_zh_TW`、`status_ja`。商店支持功能已勾选 Steam 云并以商店资料 revision 9 发布，公开商店页可见“Steam 云”。

对应收据：

- `cloud_backend_publication.json`：Cloud 开关、商店 revision 9 与公开商店页回读。
- `rich_presence_publication.json`：四语 token 的公开发布结果。
- `cloud_backend_pending.json`、`rich_presence_pending.json`：发布前历史快照，已标记由上述收据取代。

## 真实客户端 Cloud 复测边界（01:41 历史快照）

发布后 GodotSteam 4.22.1 探针返回 `app_enabled=true`、`account_enabled=false`。这说明 App 侧 Cloud 配置已生效，但当前测试账号/Steam 客户端的全局 Cloud 偏好关闭，无法完成生产 `fileWrite` 与远端回读。生产镜像正确保留 `_local_dirty`、`_settings_dirty`、`_language_dirty`，没有将失败误报为成功。为诊断做的本地配置尝试已恢复，Steam 已重启；详见 `cloud_client_retest.json`。

其后的真实上传结果见本页顶部；当前未完成项为跨设备回读和第二账号隔离回读。这些不影响本次平台配置与公告已经公开，但整体 `steam_cloud_player_acceptance` 仍保持 `false`。

## 四语公告

公告 `698776157349217400` 已关联 Build `25460867`，使用 800×450 无文字活动封面，于 2026-09-23 01:49 CST 公开：

https://store.steampowered.com/news/app/5088120/view/698776157349217400

简体中文、繁体中文、英语和日语页面均回读到对应标题、正文、Steam 客户端 Cloud 提示及“战斗中途续玩不在范围内”的边界。公开回读见 `announcement_publication.json`，最终稿见 `announcement_notes.json`。

本目录不包含候选 ZIP、Steam 登录数据、玩家存档或客户端缓存。工程外备份与实际客户端诊断只保存在 `D:\CodexTemp\steam_release_20260922\` 和 `D:\CodexTemp\steam_release_20260923\`。
