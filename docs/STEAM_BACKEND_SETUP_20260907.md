# Steam 后台配置与测试分支准备（2026-09-07）

本页记录本轮后台已保存草稿与尚缺的服务端/实机证据。App 为 `5088120`，Windows Depot 为 `5088121`。用户已确认后台配置发布、独立测试分支上传和双账号联调；该授权继续有效。当前仍未发布后台配置、未上传本轮候选 ZIP，测试分支创建未成功。后台实际回读的 default 仍是 Build `25154403`，其已上线内容见 [最近 Windows 更新](STEAM_UPDATE_20260907.md)。

30 项成就中英文和 Cloud 配额已完成保存后重新导航回读。不能把“已保存草稿”写成已生效或已上线；图标补齐前不提前发布缺图版本。

逐项事实见 [后台状态摘要](../qa/steam_backend_20260907/backend_state.json)。这是交互页面观察记录，不是原始 HTTP 响应或配置发布收据。

## 本轮后台变更

开始检查时无其他尚未发布的 app data 草稿，Stats 为 0 项、Achievements 为 0 项。

| 项目 | 已执行及回读情况 | 仍缺的证据 |
| --- | --- | --- |
| Stats | 已保存 4 项：`TOTAL_WINS`、`TOTAL_KILLS`、`DEFENSE_WINS`、`AI_WINS`；均为 INT、客户端可设置、仅递增、默认 0、最小 0、最大 2147483647、不聚合 global stat | 配置发布收据与客户端读取 |
| Achievements | 已建立 30 项，后台行 ID 为 `a5_0` 至 `a5_29`，与 [唯一清单](../tools/contracts/steam/steamworks_catalog.json) 顺序一一对应；API Name、英文名称/说明及 10 项累计阈值均已 DOM 回读正确。中文逐项保存后重新加载，后台确认 English 和 Simplified Chinese 均已全部本地化，30 项中文完整表已回读 | 60 张图标、发布收据、受控实机验证 |
| Workshop | 初始 developer only、ISteamUGC file transfer 为 0；已保存中英文标题/说明、UGC 为 1、ready-to-use 内容类型，分类 `Content Type / 内容类型` 下使用 `Map` 和 `Defense` | 发布回读、测试组配置、实际上传/订阅/更新 |
| Workshop 可见性 | 保持 developer only；切换 testers 需要 Steam 组 ID，目前尚未提供 | 可用测试组与第二账号的访问验证 |
| Cloud | 原配额为每用户 1,000,000,000 字节、20 个文件，无 AutoCloud 路径，动态同步为 1。保留字节额度与其他现状，仅将文件数保存为 1000；独立重新导航回读确认 `ufsFiles=1000`、`ufsQuota=1000000000` | 配置发布；不新增玩家存档路径 |
| 测试分支 | 拟名 `steam-integration`；新建流程的分支名 prompt 处理超时。随后独立读取 builds 页，仅有 default 和 macos 两个分支，确认本次创建未成功 | 正常创建与分支列表回读；新 BuildID 与该分支激活回读 |
| 候选 ZIP | 已按源码 `df7ed189c1b04a501ca6c3d2fe1c45e781231c18` 重新构建并验证；已打开上传页，Windows Depot `5088121` 的标准上传待选择 ZIP，页面提示有未发布 depot 配置须先发布 | 先补齐图标并发布完整配置，再上传、核对 Depot 文件清单与服务端哈希、启动测试分支 |

## 图标正常上传与手工选择清单

本地 60 张图标已就绪，均为项目生产资源。在首项图标的文件选择流程调用 `filechooser.setFiles` 时返回 `Not allowed`，因此当前没有上传任何一张图标。官方排查说明指向扩展文件 URL 访问权限；该错误不作为内容存在安全风险的证据。没有通过其他端点、脚本或自动化途径绕过文件访问限制。

已阅读 CUA 的 `chrome-file-upload-troubleshooting` 官方排查说明并提示用户：在 Edge 的 `edge://extensions` 页面，进入 ChatGPT 扩展的 Details，开启 `Allow access to file URLs`。该权限由用户在正常扩展设置中操作；开启后可恢复正常文件选择 API 上传。若未开启，则在正常文件选择窗口手工选择下表图标。这属于扩展文件访问条件，不是重新索取已给出的发布授权。

在 Steamworks 的 Achievements 页面逐行核对 API Name，再为该行选择下表对应的已解锁和未解锁 PNG；选择后完成该行的正常上传/保存，回读两张图标的预览。后台行 ID 只用于本次定位；如后台重新排序或重新建项，须以 API Name 为准。仓库图标目录为 `assets/ui/achievements/`，请使用两列给出的准确文件名，避免把成对图片互换。

| 后台行 ID | API Name | 中文名称 | 绑定/阈值 | 已解锁图标 | 未解锁图标 |
| --- | --- | --- | --- | --- | --- |
| `a5_0` | `ACH_CLEAR_LEVEL_1` | 智取生辰纲 | 游戏条件解锁 | [ach_clear_level_1.png](../assets/ui/achievements/ach_clear_level_1.png) | [ach_clear_level_1_locked.png](../assets/ui/achievements/ach_clear_level_1_locked.png) |
| `a5_1` | `ACH_STORY_LEVEL_1` | 演义印 · 智取生辰纲 | 游戏条件解锁 | [ach_story_level_1.png](../assets/ui/achievements/ach_story_level_1.png) | [ach_story_level_1_locked.png](../assets/ui/achievements/ach_story_level_1_locked.png) |
| `a5_2` | `ACH_CLEAR_LEVEL_2` | 江州劫法场 | 游戏条件解锁 | [ach_clear_level_2.png](../assets/ui/achievements/ach_clear_level_2.png) | [ach_clear_level_2_locked.png](../assets/ui/achievements/ach_clear_level_2_locked.png) |
| `a5_3` | `ACH_STORY_LEVEL_2` | 演义印 · 江州劫法场 | 游戏条件解锁 | [ach_story_level_2.png](../assets/ui/achievements/ach_story_level_2.png) | [ach_story_level_2_locked.png](../assets/ui/achievements/ach_story_level_2_locked.png) |
| `a5_4` | `ACH_CLEAR_LEVEL_3` | 三打祝家庄 | 游戏条件解锁 | [ach_clear_level_3.png](../assets/ui/achievements/ach_clear_level_3.png) | [ach_clear_level_3_locked.png](../assets/ui/achievements/ach_clear_level_3_locked.png) |
| `a5_5` | `ACH_STORY_LEVEL_3` | 演义印 · 三打祝家庄 | 游戏条件解锁 | [ach_story_level_3.png](../assets/ui/achievements/ach_story_level_3.png) | [ach_story_level_3_locked.png](../assets/ui/achievements/ach_story_level_3_locked.png) |
| `a5_6` | `ACH_CLEAR_LEVEL_4` | 大破连环马 | 游戏条件解锁 | [ach_clear_level_4.png](../assets/ui/achievements/ach_clear_level_4.png) | [ach_clear_level_4_locked.png](../assets/ui/achievements/ach_clear_level_4_locked.png) |
| `a5_7` | `ACH_STORY_LEVEL_4` | 演义印 · 大破连环马 | 游戏条件解锁 | [ach_story_level_4.png](../assets/ui/achievements/ach_story_level_4.png) | [ach_story_level_4_locked.png](../assets/ui/achievements/ach_story_level_4_locked.png) |
| `a5_8` | `ACH_CLEAR_LEVEL_5` | 三败高太尉 | 游戏条件解锁 | [ach_clear_level_5.png](../assets/ui/achievements/ach_clear_level_5.png) | [ach_clear_level_5_locked.png](../assets/ui/achievements/ach_clear_level_5_locked.png) |
| `a5_9` | `ACH_STORY_LEVEL_5` | 演义印 · 三败高太尉 | 游戏条件解锁 | [ach_story_level_5.png](../assets/ui/achievements/ach_story_level_5.png) | [ach_story_level_5_locked.png](../assets/ui/achievements/ach_story_level_5_locked.png) |
| `a5_10` | `ACH_CLEAR_LEVEL_6` | 大闹野猪林 | 游戏条件解锁 | [ach_clear_level_6.png](../assets/ui/achievements/ach_clear_level_6.png) | [ach_clear_level_6_locked.png](../assets/ui/achievements/ach_clear_level_6_locked.png) |
| `a5_11` | `ACH_STORY_LEVEL_6` | 演义印 · 大闹野猪林 | 游戏条件解锁 | [ach_story_level_6.png](../assets/ui/achievements/ach_story_level_6.png) | [ach_story_level_6_locked.png](../assets/ui/achievements/ach_story_level_6_locked.png) |
| `a5_12` | `ACH_CLEAR_LEVEL_7` | 醉打蒋门神 | 游戏条件解锁 | [ach_clear_level_7.png](../assets/ui/achievements/ach_clear_level_7.png) | [ach_clear_level_7_locked.png](../assets/ui/achievements/ach_clear_level_7_locked.png) |
| `a5_13` | `ACH_STORY_LEVEL_7` | 演义印 · 醉打蒋门神 | 游戏条件解锁 | [ach_story_level_7.png](../assets/ui/achievements/ach_story_level_7.png) | [ach_story_level_7_locked.png](../assets/ui/achievements/ach_story_level_7_locked.png) |
| `a5_14` | `ACH_CLEAR_LEVEL_8` | 智取大名府 | 游戏条件解锁 | [ach_clear_level_8.png](../assets/ui/achievements/ach_clear_level_8.png) | [ach_clear_level_8_locked.png](../assets/ui/achievements/ach_clear_level_8_locked.png) |
| `a5_15` | `ACH_STORY_LEVEL_8` | 演义印 · 智取大名府 | 游戏条件解锁 | [ach_story_level_8.png](../assets/ui/achievements/ach_story_level_8.png) | [ach_story_level_8_locked.png](../assets/ui/achievements/ach_story_level_8_locked.png) |
| `a5_16` | `ACH_ALL_CLEAR` | 八幕功成 | 游戏条件解锁 | [ach_all_clear.png](../assets/ui/achievements/ach_all_clear.png) | [ach_all_clear_locked.png](../assets/ui/achievements/ach_all_clear_locked.png) |
| `a5_17` | `ACH_ALL_STORY` | 忠义全书 | 游戏条件解锁 | [ach_all_story.png](../assets/ui/achievements/ach_all_story.png) | [ach_all_story_locked.png](../assets/ui/achievements/ach_all_story_locked.png) |
| `a5_18` | `ACH_DEFENSE_30` | 固守梁山 · 30波 | 游戏条件解锁 | [ach_defense_30.png](../assets/ui/achievements/ach_defense_30.png) | [ach_defense_30_locked.png](../assets/ui/achievements/ach_defense_30_locked.png) |
| `a5_19` | `ACH_DEFENSE_60` | 固守梁山 · 60波 | 游戏条件解锁 | [ach_defense_60.png](../assets/ui/achievements/ach_defense_60.png) | [ach_defense_60_locked.png](../assets/ui/achievements/ach_defense_60_locked.png) |
| `a5_20` | `ACH_WINS_10` | 百战建功 · 10 | `TOTAL_WINS` >= 10 | [ach_wins_10.png](../assets/ui/achievements/ach_wins_10.png) | [ach_wins_10_locked.png](../assets/ui/achievements/ach_wins_10_locked.png) |
| `a5_21` | `ACH_WINS_50` | 百战建功 · 50 | `TOTAL_WINS` >= 50 | [ach_wins_50.png](../assets/ui/achievements/ach_wins_50.png) | [ach_wins_50_locked.png](../assets/ui/achievements/ach_wins_50_locked.png) |
| `a5_22` | `ACH_WINS_100` | 百战建功 · 100 | `TOTAL_WINS` >= 100 | [ach_wins_100.png](../assets/ui/achievements/ach_wins_100.png) | [ach_wins_100_locked.png](../assets/ui/achievements/ach_wins_100_locked.png) |
| `a5_23` | `ACH_KILLS_1000` | 替天行道 · 1000 | `TOTAL_KILLS` >= 1,000 | [ach_kills_1000.png](../assets/ui/achievements/ach_kills_1000.png) | [ach_kills_1000_locked.png](../assets/ui/achievements/ach_kills_1000_locked.png) |
| `a5_24` | `ACH_KILLS_10000` | 替天行道 · 10000 | `TOTAL_KILLS` >= 10,000 | [ach_kills_10000.png](../assets/ui/achievements/ach_kills_10000.png) | [ach_kills_10000_locked.png](../assets/ui/achievements/ach_kills_10000_locked.png) |
| `a5_25` | `ACH_KILLS_100000` | 替天行道 · 100000 | `TOTAL_KILLS` >= 100,000 | [ach_kills_100000.png](../assets/ui/achievements/ach_kills_100000.png) | [ach_kills_100000_locked.png](../assets/ui/achievements/ach_kills_100000_locked.png) |
| `a5_26` | `ACH_DEFENSE_WINS_10` | 水泊坚壁 · 10 | `DEFENSE_WINS` >= 10 | [ach_defense_wins_10.png](../assets/ui/achievements/ach_defense_wins_10.png) | [ach_defense_wins_10_locked.png](../assets/ui/achievements/ach_defense_wins_10_locked.png) |
| `a5_27` | `ACH_DEFENSE_WINS_50` | 水泊坚壁 · 50 | `DEFENSE_WINS` >= 50 | [ach_defense_wins_50.png](../assets/ui/achievements/ach_defense_wins_50.png) | [ach_defense_wins_50_locked.png](../assets/ui/achievements/ach_defense_wins_50_locked.png) |
| `a5_28` | `ACH_AI_WINS_1` | 运筹帷幄 · 1 | `AI_WINS` >= 1 | [ach_ai_wins_1.png](../assets/ui/achievements/ach_ai_wins_1.png) | [ach_ai_wins_1_locked.png](../assets/ui/achievements/ach_ai_wins_1_locked.png) |
| `a5_29` | `ACH_AI_WINS_10` | 运筹帷幄 · 10 | `AI_WINS` >= 10 | [ach_ai_wins_10.png](../assets/ui/achievements/ach_ai_wins_10.png) | [ach_ai_wins_10_locked.png](../assets/ui/achievements/ach_ai_wins_10_locked.png) |

以上 10 项累计成就为末尾 10 行；非累计行继续由游戏的对应条件触发。中英文完整说明来自同一 JSON 清单，不用本表的阈值文本替换游戏说明。

## 已验证测试包

构建源码固定为 `df7ed189c1b04a501ca6c3d2fe1c45e781231c18`，分支 `codex/sync-20260905-stable`。本地相对位置为 `.godot/steam_candidates/20260907_034452_e661f0ee/LiangshanHeroes_Steam_candidate.zip`。

- ZIP：219,811,886 字节；SHA-256 `768d1c15dedfd0cd19f89bb3528028171f2abf0115d3ca51a244e90e8f3b44d5`。
- EXE：287,589,608 字节；SHA-256 `2a633b1a7dbf2161e7e5d69410203093668e65553dcbe82dbeb1734518b20c05`。
- ZIP 只含 `LiangshanHeroes.exe`、`libgodotsteam.windows.template_release.x86_64.dll`、`steam_api64.dll` 和 `GODOTSTEAM_LICENSE.txt`，成员大小/哈希见 [交付清单](../qa/steam_backend_20260907/candidate/delivery_manifest.json)。
- 新隔离原生 QA 176 项、实际内嵌 PCK 65 项均通过。真实发行 EXE 正常退出，回读到正确发行 DLL。新增的 8 个续玩基础模块已确认实际入包，但没有菜单/Battle 调用方；不据此宣称完整续玩已接通。

原始与脱敏收据及复现命令见 [候选 QA](../qa/steam_backend_20260907/candidate/README.md)。这些自动检查强制禁用真实 Steam 初始化，没有使用玩家账号；它们不能替代下面的线上验收。

## 恢复操作与验收顺序

1. 重新打开 App `5088120` 后先读保存状态，确认没有其他任务新加入的未发布 app data。上传并逐项回读 60 张图标，复核 4 项 stats、30 项 API Name、中英文名称/说明及 10 项累计阈值；Cloud 的文件数 1000 与字节数 1000000000 已保存并独立回读，后续继续保持。
2. 保持现有 Cloud 字节额度和无 AutoCloud 路径。核对 UGC、工坊标题/说明及 Map/Defense 分类。提供测试 Steam 组后，再配置 testers 访问并验证第二账号可访问；未具备该条件前保留 developer only。
3. 在正常 UI 中完成测试分支名称 prompt，再回读分支列表，确认 `steam-integration` 实际存在。此前 `getJsDialog.accept` 超时，独立回读已确认仅有 default/macos，创建未成功；后续操作前仍先查当前列表，避免与用户手工操作重复。
4. 对准备好的 app data 差异执行已获授权的正常发布流程，保留发布成功与实际生效回读；如存在其他任务新草稿，先分清范围。不要将尚缺图标或尚未复核的字段当作完整成就配置验收通过。
5. [标准上传页面](https://partner.steamgames.com/apps/depotuploads/5088120) 已打开，Windows Depot `5088121` 待选择上述 ZIP；页面提示存在未发布 depot 配置，须在前一步补齐图标并发布完整配置后再继续上传。扩展文件访问条件未满足时，由用户在正常窗口选择该文件；选择完成后继续上传。记录 BuildID、Depot Manifest、服务端文件名/大小/哈希，与本地清单核对后仅激活已确认的测试分支，再回读分支对应的 BuildID。default 继续保持原值，不在本轮自行切换。
6. 用受控账号 A 从 Steam 测试分支安装并启动，验证 App、初始化、Overlay、30 项后台定义和保存/重启读取。按真实条件或受控测试流程核对解锁与统计，不向玩家账号批量发放进度；补离线回连、保存重试、账号切换、旧档印记迁移的证据。
7. 账号 A 发布场景与自定义据守各一份，记录作品 ID；账号 B 订阅、下载、进入真实战斗。A 更新同一作品 ID，B 取得新版；核对下载更新不替换当前局数据、取消订阅保留本地作品、坏包/未知版本拒绝、首次协议和断网上传重试。缺少第二可用测试账号时，这一组必须保持未验收。
8. 将发布、BuildID/Manifest、两个作品 ID 及双账号结果写入本轮 QA。工坊 Everyone、default 更新、商店宣传或正式发布须依其各自范围推进，不能由本轮保存草稿或离线包验证推定完成。

当前阻塞来自扩展文件访问/手工文件选择、JavaScript prompt 的工具限制，以及测试组/第二账号信息缺失。后台发布和测试分支上传已有授权，不需要再次确认同一授权。公共文档和收据不记录 Steam 登录、缓存、密码、个人账号 ID 或 IP。
