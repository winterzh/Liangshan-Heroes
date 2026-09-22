# Steam 云存档与好友状态（2026-09-23 修订）

范围严格限定：只同步已稳定战役进度和个人设置，不含战斗中途续玩档；不创建 Release、不改 Steam 默认构建、不开放工坊。9 月 21 日版本的 11 项 Python 检查只运行重写逻辑，未加载生产 GDScript，不能证明原生接通。9 月 22 日审查发现的编译、SDK 接口和存档隔离问题及修复验证见 [修复 QA](../qa/steam_cloud_safety_20260922/README.md)。

## 实现内容与当前发布状态

2026-09-23，包含本功能的 Windows Build `25460867` / Manifest `2563454806170954821` 继续为 Steam `default`，客户端安装与启动通过。Steam Cloud 已对普通玩家开放、动态云同步已关闭，商店公开页可见“Steam 云”；四语 Rich Presence 映射和公告 `698776157349217400` 已公开。用户启用账号 Cloud 后，03:35 的生产启动已成功上传 `liangshan_profile_v1.json`，客户端日志与 Steam 账号云文件页均确认。跨设备和第二账号读回尚未验收。最新状态见 [发布复查](STEAM_UPDATE_20260922.md)。

- 好友状态包含主菜单、具体战役关卡、据守梁山波次、AI/竞技场/自定义及暂停；据守波次通过关卡事件更新，不每帧扫描战场，不为好友状态重新生成随机波次。
- 文案四语：`status_zh_CN` / `status_zh_TW` / `status_en` / `status_ja`，并写 `status`（当前游戏语言）与 `steam_display=#Status`（供 Steamworks Localization 按好友语言映射）。
- 换电脑后保留战役进度、演义印与个人设置（音频/画面/按键/语言）。

## 实现边界

| 项目 | 约定 |
|---|---|
| 云文件 | `liangshan_profile_v1.json`（JSON UTF-8） |
| 本地镜像 | `user://steam_cloud_profile_<SteamID>.json`；旧 `steam_cloud_profile.json` 保留作受控迁移来源，不进 Git |
| 本机归属 | `steam_cloud_owner.cfg` 与 `campaign.cfg` 的 `progress.owner`；升级前 `steam_legacy_import.cfg` 只读作为历史归属证据 |
| 进度合并 | `cleared`/`story_complete` 取并集；`best_*` 保留单局最优目标集，禁止跨局拼接演义印 |
| 账号隔离 | 校验云文件、镜像与本机进度的账号归属；换账号替换为目标账号状态，不合并上一账号进度 |
| 离线/失败 | 保留本地修改；读取失败先重读，不允许直接覆盖上传；损坏或归属不明的文件拒绝自动修复 |
| 旧档恢复 | 云为空且本地有进度 → 合并后上传 |
| 续玩 | 战斗中途存档/世界恢复不在本批云同步范围 |
| 普通启动 | 无 `steam` 导出特性或测试环境时完全 no-op |

云端读取使用固定 GodotSteam 4.22.1 的 `getFileSize`、`fileRead(name, size)`、返回字节数 `ret` 与 `buf`，拒绝空读、短读、超限和非法 payload。小型 JSON 仅使用同步 `fileWrite`，失败保留待提交状态；不将返回 void 的 `fileWriteAsync` 当作成功布尔值。

下载设置在完整校验后更新运行状态、音频、语言与按键通知，继续经过 F1～F8 保留键和旧 F2 迁移。个人设置的离线变化及本机最新战役记录参与合并，不仅比较旧镜像时间。演义印仍只保留单局目标集，不跨局拼接。

`fileWrite` 成功只代表 Steam 客户端接受本地缓存写入；后续服务器上传由 Steam 客户端管理，不等于已完成双设备回读验证。

### 本地状态需要检查时

账号切换前先保存两方的独立镜像，再写 `pending_owner` 过渡标记；共享设置、进度和最终 owner 提交完成后才清除标记。若本地写盘中断、归属矛盾、镜像损坏或存在无归属的旧账号镜像，将显示「本机云存档需要检查，已停止同步」，停止自动云读写；普通网络读写失败则保留本地修改并按退避重试。

这类本地停止不会自动删除文件或给旧进度改 SteamID。恢复前应关闭游戏，备份上述 owner/进度/镜像及 `settings.cfg`、`language.cfg`，核对每份归属后按同一账号的完整状态恢复。不要只删除 `pending_owner`、owner 文件或改 payload.owner 来绕过检查；本轮没有新增自动修复损坏档的玩家入口。

## Steamworks 后台

- Cloud 配额为每用户 1 GB / 1000 文件；本批使用 ISteamRemoteStorage API，**不**使用 Auto-Cloud 玩家存档规则。正确公开配置见 [cloud_configuration.json](../tools/contracts/steam/cloud_configuration.json)：取消“仅为开发人员”、关闭动态云同步、商店支持功能勾选 Steam 云。
- Rich Presence 语言映射是**必需前置**：上传并发布 [rich_presence.vdf](../tools/contracts/steam/rich_presence.vdf)，四语 `#Status` 分别引用 `status_en` / `status_zh_CN` / `status_zh_TW` / `status_ja`。未配置有效 token 时，好友列表不会自动以 `status` 兜底；该键只是额外游戏信息。参见 [Valve 文档](https://partner.steamgames.com/doc/api/ISteamFriends#SetRichPresence)。
- `rich_presence.vdf` 的四语 token 已在 Steamworks 公开发布；Build 已上线，四语公告 `698776157349217400` 已公开并逐语言回读。真实客户端已验证包下载与启动，当前账号 Cloud 生产上传及服务器文件列表通过；第二账号和跨设备回读继续作为独立验收。

## 复现

```powershell
python -X utf8 -B tools/run_steam_cloud_presence_qa.py --godot <本机Godot可执行文件> --out <新的工程外绝对路径>
# 包含原有 F1～F8、操作/经济/物品/HUD/战役回归：
python -X utf8 -B tools/run_rts_refinement_qa.py --godot <本机Godot可执行文件> --out <另一个新的工程外绝对路径>
```

入口冻结白名单源码、创建全新私有用户目录、先执行真实 Godot 导入，再运行生产 GDScript 与 SDK 契约一致的 `tools/steam_fake_api.gd`。Python 只编排和检查完成收据，不再复制游戏逻辑。测试不加载 Steam DLL、不连接真实账号、不改变 HOME，也不写玩家存档；完成后检查副本与工作区来源漂移。

## 证据

历史纯 Python 证据保留在 [9 月 21 日 QA](../qa/steam_cloud_presence_20260921/README.md)，实际 GDScript 修复证据见 [9 月 22 日 QA](../qa/steam_cloud_safety_20260922/README.md)。不要用历史 11 项通过替代新版本验证。
