# 2026-09-06 Windows Steam 更新

用户明确授权本轮合并及更新 Steam。PR #1 已合并；Windows 更新已上传并上线 Steam default，BuildID为 **25149197**，Depot Manifest为 **6277611029325164920**。最终状态以[发布收据](../qa/steam_update_20260906/PUBLISH_STATUS.json)为准。

## 源码与成品

- 源提交：`954ffde683e79fe90656e5acba78692bc5de67b8`；PR #1 合并提交：`37d3e363847ff37177ef62ce8927db5f4a270bc6`。Git树均为 `ad61c5533cc6e2b33dc4ede162c0d244ee92c379`，已回读 GitHub 核对。
- 从 Git 对象冻结2462个运行文件，补入当前36个宋江/林冲TRES、角色生产图和UI依赖。排除孙立草稿、开发工具、QA、文档、凭据、存档和缓存；不修改既有商业来源门禁。
- Godot4.6.3标准Windows release导出，嵌入PCK，版本沿用1.8.0.0。EXE为286,979,872字节，SHA256 `f7e7fdabbf3869e56a6b5b0d1869069e89122ccb8dc4c2e091ed16b188e0bcf3`，SHA1 `7862a6ba3adbee4a0c9fd862f34f4c8a12354610`。
- 上传ZIP为217,926,716字节，根目录仅 `LiangshanHeroes.exe`；SHA256 `031b2d01826b9e042015626e59a69f96900145af3eafeb23644a5cd46b6336fb`。CRC及解压后的EXE哈希均通过。

本机产物在被忽略的 `.godot/steam_update_20260906/windows/`，不提交EXE、ZIP、Godot导入目录、用户数据或上传凭据。逐文件来源、构建和测试证据见[包验证](../qa/steam_update_20260906/README.md)。

## 验证

全新导入和导出均退出0、无错误警告。包内437项覆盖36个TRES、100个排帧、22张角色生产源图导入资源及开发文件排除。实际EXE执行八关、驻守、末波清理和菜单共11次短测；驻守9项、末波清理12项通过。相同内嵌PCK的菜单与驻守两张Vulkan画面已目检，冻结输入和成品哈希另经独立复核。

上述检查不替代真人八关/30波、长时稳定性、整体性能或商业美术来源验收。当前未完成项目仍见[项目进度](PROJECT_STATUS.md)与[可售清单](RELEASE_READINESS_20260905.md)。

## Steam 发布步骤与范围

目标应用5088120、Windows Depot5088121、default分支。操作前Steamworks确认default为25136463，Depot Manifest为7280684617482783161，现有Depot也只有根目录EXE。现已完成上传、创建Build25149197与default切换；回读默认分支行显示25149197，新清单仅含286,979,872字节的LiangshanHeroes.exe，SHA1与本地已测成品一致。Steam预览显示从旧构建升级约需20.9MB。

通过Steamworks的SteamPipe→通过网页上传的内容，以“标准”上传已验证ZIP，创建生成版本；核对Depot中的EXE文件名、大小及SHA1后再预览更改并设置default上线。上传与切换已分别核实。未另做完整Steam客户端下载，不将网页清单核对称为已下载试玩。官方流程见[SteamPipe文档](https://partner.steamgames.com/doc/sdk/uploading)。

本轮更新现有Windows构建，不执行首次商店正式发行，不更改macOS Depot或外部更新器。后续按用户要求，已于2026-09-06 14:55 HKT发布[Steam简短公告](https://store.steampowered.com/news/app/5088120/view/708907988310558226)，关联本次Build25149197；中英文正文和记录见[公告文档](UPDATE_ANNOUNCEMENT_20260906.md)、[发布收据](../qa/steam_update_20260906/announcement_receipt.json)。
