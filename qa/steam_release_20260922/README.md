# Steam Build 25460867 发布、复查与待处理平台配置

源码基线 `729892b0694406e591be585855a4590fd691d134` 已构建为 Windows 候选并上传。Steamworks 权威回读确认 `default` 为 Build `25460867`、Depot `5088121` / Manifest `2563454806170954821`；服务器六文件的名称、字节数和 SHA-1 与候选一致。Steam 客户端随后下载该 Manifest，库目录六文件再次匹配，并通过 Steam 启动实际 EXE，日志严格问题数为 0。

## 本地和包验证

| 验证 | 结果 |
|---|---:|
| 原生 Steam QA | 185 项通过 |
| 包检查 | 1,136 项通过 |
| 来源/内容身份 | 10 + 10 项通过 |
| 实际 EXE 烟测 | 11/11 |
| 完整 RTS 复查 | 740/740 |
| 默认场景 180 帧 | 退出 0，问题行 0 |

完整复查使用新的工程外冻结副本和私有 profile，设置 `STEAM_DISABLED=1`、`CAMPAIGN_QA=1`，没有加载原生 Steam SDK或玩家数据。3347 份来源的冻结副本与工作区漂移均为 0。逐组日志和收据见 `recheck_20260922_233500/`。

## 复查发现及处理

真实客户端测试生成了账号分区镜像，但 `_local_dirty`、`_settings_dirty`、`_language_dirty` 仍为 `true`。代码复查和 104 项 Cloud 回归均确认：失败不会被误报为成功，脏状态会保留并重试；没有理由削弱安全判断。

Steamworks 回读找到了实际阻塞：Cloud 仍勾选“仅为开发人员启用”，同时启用了项目未实现所需 API 的动态云同步；商店“Steam 云”支持功能未勾选。四语 Rich Presence 映射已上传成草稿，但尚未发布。项目新增 `tools/contracts/steam/cloud_configuration.json` 固定正确后台契约，避免后续再次按错误开关发布。

正确目标状态为：普通玩家 Cloud 开启、动态云同步关闭、商店支持功能勾选 Steam 云；Rich Presence 的 `#Status` 分别映射 `status_en`、`status_zh_CN`、`status_zh_TW`、`status_ja`。这些属于 Steamworks 公共配置，当前仍未执行发布。配置公开后必须重启 Steam 客户端，再以同一真实账号确认镜像脏标记清除；双设备和第二账号仍是独立验收边界。

四语公告稿已保存在 `announcement_notes.json`，当前没有公开。`publication_pending_confirmation.json` 是 Build 切换前的历史中间收据；当前权威状态见 `default_live_verification.json` 和 `publication_receipt.json`。

本目录不包含候选 ZIP、Steam 登录数据、玩家存档或客户端缓存。工程外备份与实际玩家测试数据只保存在 `D:\CodexTemp\steam_release_20260922\`。
