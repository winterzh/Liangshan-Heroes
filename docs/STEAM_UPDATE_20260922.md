# 2026-09-22 Steam Build 25460867 与平台配置复查

Windows Build `25460867` / Manifest `2563454806170954821` 已成为 `default`。Steamworks 服务器清单、Steam 客户端下载后的六文件和本地候选三方名称、大小、SHA-1 一致；客户端从 Steam 库启动成功，日志严格问题数为 0。回滚目标保留为 Build `25451455` / Manifest `141439361708043047`。

发布候选基于源码 `729892b0`。原生 Steam QA 185、包检查 1,136、身份检查 20、实际 EXE 烟测 11 项通过。再次独立冻结源码后，完整 RTS 回归 740/740、3347 份来源双侧零漂移，默认主场景 180 帧退出 0、问题行 0。

真实客户端测试没有把 Cloud 失败误判为成功：账号镜像仍保留脏标记。Steamworks 后台回读确认 Cloud 尚为“仅开发人员”，动态云同步被错误勾选，商店支持功能也未声明 Steam 云。正确后台契约已固定在 `tools/contracts/steam/cloud_configuration.json`：取消开发者限制、关闭动态云同步、勾选商店 Steam 云。项目使用 `ISteamRemoteStorage`，未实现动态云同步的写入批次和本地文件变化通知。

Rich Presence 四语映射已经上传成待发布草稿，准确差异仅为四个 `#Status` token；尚未公开。四语公告《Steam 云存档与好友状态更新》已经定稿，但没有发布。只有后台配置公开并完成真实客户端 Cloud 写确认后，才能把 Cloud 和四语好友状态写成玩家已可用功能。

完整收据、公告稿和待处理项见 [本轮 QA](../qa/steam_release_20260922/README.md)。GitHub 源码/证据同步不等于继续修改 Steamworks 或发布公告。
