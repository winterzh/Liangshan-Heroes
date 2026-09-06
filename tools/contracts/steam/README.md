# Steamworks 输入来源

`steamworks_catalog.json` 由生产 `SteamAchievementCatalog.entries()` 导出；它是后台逐项配置清单，不宣称 Valve 存在 JSON 直接导入接口。30 个 API 名必须保持稳定。

`icons/` 保存本项目代码绘制的 60 份 SVG 原文。`tools/steam_catalog_export.gd` 用 Godot 的 SVG 栅格化生成 256×256 PNG；生产图在 `assets/ui/achievements/`。已解锁为金红色，未解锁为灰色。复现时给 `STEAM_CATALOG_OUTPUT` 指向新的输出目录，在已导入的隔离项目运行生成器，不覆盖历史 QA。

后台字段、工坊配置、依赖来源与双账号验证步骤见 `docs/STEAM_INTEGRATION_20260907.md`。本目录不包含账号数据或发布凭据。
