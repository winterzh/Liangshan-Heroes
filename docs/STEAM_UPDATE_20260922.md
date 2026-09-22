# 2026-09-23 Steam Build 25460867、Cloud/Rich Presence 与公告公开

Windows Build `25460867` / Manifest `2563454806170954821` 已在 `default`。Steamworks 服务器清单、Steam 客户端安装目录和候选六文件名称、大小、SHA-1 一致；客户端从 Steam 库启动成功，日志严格问题数为 0。回滚目标保留为 Build `25451455` / Manifest `141439361708043047`。

发布候选基于源码 `729892b0`。原生 Steam QA 185、包检查 1,136、身份检查 20、实际 EXE 烟测 11 项通过；独立冻结源码的完整 RTS 回归 740/740、3347 份来源双侧零漂移，默认主场景 180 帧退出 0、问题行 0。

## 平台公开状态

2026-09-23 已发布 Steamworks 应用配置：

- Steam Cloud 取消“仅为开发人员启用”。
- 动态云同步关闭，保持与当前 `ISteamRemoteStorage` 实现一致。
- 商店支持功能新增“Steam 云”，资料 revision 9 发布；公开商店页已回读到该功能。
- Rich Presence 四语 `#Status` 已发布，分别映射 `status_en`、`status_zh_CN`、`status_zh_TW`、`status_ja`。

四语补丁说明 `698776157349217400` 已关联 Build `25460867` 并公开，简体中文、繁体中文、英语和日语标题及完整正文均从公开页面回读：

https://store.steampowered.com/news/app/5088120/view/698776157349217400

## 客户端 Cloud 验收范围

平台发布后，GodotSteam 探针确认 `app_enabled=true`，但当前测试账号/Steam 客户端返回 `account_enabled=false`。因此本次无法完成生产 `fileWrite` 与远端读回；本地镜像正确保留三项 dirty 标记，未误报成功。为诊断做的本地 Steam 配置尝试已经恢复并重启客户端。

本次已经完成构建上线、平台 Cloud 开放、动态 Cloud 关闭、商店功能展示、四语好友状态发布和四语公告公开。当前账号启用 Steam 云后的真实写入、跨设备及第二账号读回仍是独立验收边界，不能从平台开关已发布推导为已完成。

完整收据见 [本轮 QA](../qa/steam_release_20260922/README.md)。
