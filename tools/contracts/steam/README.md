# Steamworks 输入来源

`steamworks_catalog.json` 由生产 `SteamAchievementCatalog.entries()` 导出；它是后台逐项配置清单，不宣称 Valve 存在 JSON 直接导入接口。30 个 API 名必须保持稳定。

`icons/` 保存本项目代码绘制的 60 份 SVG 原文。`tools/steam_catalog_export.gd` 用 Godot 的 SVG 栅格化生成 256×256 PNG；生产图在 `assets/ui/achievements/`。已解锁为金红色，未解锁为灰色。复现时给 `STEAM_CATALOG_OUTPUT` 指向新的输出目录，在已导入的隔离项目运行生成器，不覆盖历史 QA。

后台字段、工坊配置、依赖来源与双账号验证步骤见 `docs/STEAM_INTEGRATION_20260907.md`。本目录不包含账号数据或发布凭据。

`rich_presence.vdf` 是好友状态 `#Status` 的四语 Steamworks 本地化输入，使用 english/schinese/tchinese/japanese 映射到游戏上传的对应状态键。必须在 Steamworks 上传并发布后才能验收好友列表显示；文件进入 Git 不代表后台已配置。参见 `docs/STEAM_CLOUD_PRESENCE_20260921.md`。

`cloud_configuration.json` 固定 Steam Cloud 后台契约：普通玩家可用、动态云同步关闭、商店支持功能勾选 Steam 云。项目使用 `ISteamRemoteStorage`，没有实现动态云同步所需的写入批次和本地文件变化回调；不得仅因后台存在该开关就启用。
