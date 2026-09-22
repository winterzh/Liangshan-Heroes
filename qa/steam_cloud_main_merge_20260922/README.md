# Steam Cloud / Rich Presence main 整合与 Windows 验证

2026-09-22 将 `origin/codex/sync-20260905-stable` 的安全修复提交 `0854f07b4de5501e4032e77910134871a18ca4e1` 合入 `main`。冲突处理中采用稳定分支的 `SteamCloud`、`SteamPresence`、HUD 和 `SteamService` 组合，移除 `main` 原有的 HUD → `SteamService.set_presence()` 重复写入链，并注册 `SteamPresence` Autoload。

文档更新前的合并索引树为 `d3326ede1bda200a57925e823ed005692e843de4`，与 `0854f07b` 的树完全一致。也就是说，本次没有把旧版 Cloud 读取、共享镜像或第二套 Presence 写入链带回生产源码。

## Windows 结果

Godot `4.6.3.stable.official.7d41c59c4`，Windows 11，全新工程外冻结目录与唯一私有 profile：

| 组别 | 结果 |
|---|---:|
| F1～F8 与旧 F2 迁移 | 93/93 |
| RTS 基础操作 | 47/47 |
| 经营规则 | 66/66 |
| 英雄与物品 | 64/64 |
| HUD 内部快照 | 38/38 |
| 输入操作 | 122/122 |
| 战斗操作 | 95/95 |
| 战役操作 | 32/32 |
| Steam Cloud | 104/104 |
| Rich Presence | 79/79 |
| **合计** | **740/740** |

新鲜导入与每组进程退出码均为 `0`；全部日志中 `SCRIPT ERROR`、`Parse Error`、`ERROR:`、`WARNING:` 均为 `0`。3347 份受测来源在冻结副本和工作区两侧漂移均为 `0`。随后直接从当前工作区运行隔离的默认主场景 180 帧，退出 `0`、问题行 `0`，见 [startup_180.log](startup_180.log)。

完整来源哈希、隔离参数和每组结果在 [source-receipt.json](source-receipt.json)，简表在 [summary.json](summary.json)。Cloud 与 Presence 逐项断言分别见 [steam-cloud-result.json](steam-cloud-result.json) 和 [steam-presence-result.json](steam-presence-result.json)。

## 隔离与剩余门槛

测试固定 `STEAM_DISABLED=1`、`CAMPAIGN_QA=1`，未复制或加载原生 Steam SDK，未读取真实玩家 profile，也未上传、切换或发布 Steam 构建。Windows 生产脚本与合并链已经通过本地隔离回归；真实 Steam 双账号、跨设备/离线客户端回读，以及 Steamworks 四语 `#Status` 映射发布仍需在打包上线前完成。

本次未构建安装包，未修改版本号，未发布补丁说明。GitHub 最终提交与远端 SHA 以本轮收尾回读为准。
