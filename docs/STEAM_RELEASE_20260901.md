# Steam Windows 战役更新发布记录（2026-09-01）

## 结论

- 范围严格限定 Windows 64 位；未配置、上传、测试或勾选 macOS。
- SteamPipe 已创建 BuildID `25051529`，Depot `5088121` 的新 manifest 为 `7187332324453458125`。
- `default` 分支已从 BuildID `24651321` 切换到 `25051529`。
- Steamworks 应用主页刷新后仍显示游戏生成版本已通过审核、商店为可见 Coming Soon、最早发行日期为 `2026-09-05`；没有 `Release App` 按钮，本次没有正式发售。
- 对外公告正文见 `STEAM_UPDATE_20260901.txt`；正文为普通中文纯文本，不使用 Markdown 或 BBCode。当前只完成本地定稿，等待发布动作前的最终确认。
- 公告必需的 800×450 封面已经生成并按 Steam 尺寸检查：`steam_announcement_20260901/event_cover_800x450.png`。它只用于本次公告，不替换商店永久素材。

## 成品身份

| 项目 | 值 |
| --- | --- |
| 文件 | `LiangshanHeroes.exe` |
| 文件版本 / 产品版本 | `1.8.0.0` / `1.8.0.0` |
| 大小 | `233,056,016` 字节 |
| SHA-256 | `E75EA39D5EFC9578FF01FDD5372427D4EB23C6A80A9D646CCDC608EE7236B37F` |
| Steam BuildID | `25051529` |
| DepotID | `5088121` |
| Depot manifest | `7187332324453458125` |
| default 更新下载量 | Steamworks 预览显示 `76.9 MB` |

候选目录：

`C:\Users\rsb\Desktop\AI项目\水浒\_archive\release_candidates\release_candidate_20260901_134110`

旧审核版已完整归档到：

`C:\Users\rsb\Documents\Steamworks\Liangshan_5088120\release_archive\pre_campaign_update_20260901_135128`

归档内保留旧的两份 EXE、SteamPipe 脚本、发行文档和更新前后哈希回执。旧版大小为 `215,951,536` 字节，SHA-256 为 `A05D759346FB4093E34653CA4E59E85BB0207C8A7FB46F0816392C284756EF4F`。

## 导出包装

公开版菜单版本字样由“本地开发候选”改为“战役重做 · 八幕战役（v1.8）”。Windows 导出排除了开发期 QA、工具、文档、环境备份、原始图、网页绘图提示词和生成/QA JSON 清单。

最终导出使用物理白名单工程，仅包含：

- `project.godot`、Windows `export_presets.cfg`、图标；
- `scripts/`、`scenes/`；
- 运行实际使用的 PNG 成品与其 Godot 导入描述。

白名单导入前共 `1,659` 个文件、`166,242,849` 字节；不含 `qa/`、`tools/`、`docs/`、`campaign_environment_v8_20260831/`、`assets/campaign/source/`、原始图和战役生成清单。导出日志确认这些路径在成品中均为 0 条。

## 本地与成品验证

- 源工程 Godot 4.6.3 编辑器加载：退出码 0。
- 白名单工程导入：退出码 0，脚本错误 0、解析错误 0、普通错误 0、警告 0。
- Windows release 导出：退出码 0，脚本错误 0、普通错误 0、警告 0。
- 成品 1280×720 主菜单实际渲染 12 帧并检查；公开版本字样、八幕自由通关说明与布局正常。
- 成品 EXE 按旧 `LEVEL=N → levelN` 兼容入口逐关启动 1—8：8/8 退出码 0，脚本错误 0、缺失资源 0、加载失败 0。
- 多数成品启动在退出时仍记录既有 `ObjectDB instances leaked at exit` 清理警告；没有脚本错误或崩溃，未将其表述为长期内存验收。

此前同一运行源码已经通过 21/21 串行回归、公共交互 22/22、前四关 47/47、后四关 69/69、终章六结局 6/6、终章深度 52/52 和 5/5 组 1280×720 战役界面检查。自动化与代理观察仍不等于真人完整试玩、15—25 分钟节奏、拥挤点选或长时间性能验收。

## SteamPipe 与服务器回读

1. SteamPipe preview 于 `2026-09-01 13:52 (UTC+8)` 完成：Depot `5088121` 只映射一份 `LiangshanHeroes.exe`；没有新增或删除文件。
2. 正式上传于 `2026-09-01 13:53 (UTC+8)` 成功，创建 BuildID `25051529` 和 manifest `7187332324453458125`；143 个新分块全部上传。日志中一次分块请求自动重试，最终明确返回 `Success`。
3. Steamworks 切换预览确认旧 manifest `2459427000399860062`、新 manifest `7187332324453458125`，磁盘大小由 216.0 MB 变为 233.1 MB，用户更新下载量为 76.9 MB。
4. `default` 分支刷新后明确指向 BuildID `25051529`，构建历史出现对应上线记录；未选择或修改 `macos` 分支。
5. 使用 SteamCMD 从服务器将 `default` 下载到隔离目录，`appmanifest_5088120.acf` 显示 `StateFlags=4`、`buildid=25051529`、`TargetBuildID=25051529`、Depot manifest `7187332324453458125`。
6. 服务器下载 EXE 的大小和 SHA-256 与本地候选完全一致；实际启动退出码 0，脚本错误 0、普通错误 0，仅保留既有退出清理警告。

## 外部更新清单与平台边界

`2026-09-01` 只读复核 Windows stable manifest：HTTP 200，`platform=windows`、`content_version=1.8`、`patch=null`、完整包仍是旧 v1.8 的 `215,951,536` 字节及 `A05D...EF4F`；签名端点 HTTP 200、512 字节。本轮没有修改外部更新服务器、清单或签名。新 Steam EXE 仍报告内容/文件版本 `1.8`，不会触发版本漂移下载。

本次没有修改原价 `¥59.90`、首发折扣 `40% / 14 天`、AI 披露、评级、语言、商店素材或发行日期，也没有点击正式发行。
