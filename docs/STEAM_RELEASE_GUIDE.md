# 《水浒英雄传：八幕战役》Steam 发布指南

本文用于本项目的 **Windows 版本更新发布**。它覆盖从冻结源码、生成候选包、上传 Windows Depot，到切换 `default`、发布四语补丁说明和完成公开回验的完整流程。

本指南不是一次发布授权。仅在用户明确要求“更新 Steam / 发布 Steam”后执行上传、切换正式分支或发布公告；“打包一下”“同步源码”只到本地候选或 GitHub，不自动扩大为 Steam 发布。

## 1. 项目固定信息

| 项目 | 值 |
| --- | --- |
| Steam AppID | `5088120` |
| Windows DepotID | `5088121` |
| 玩家正式分支 | `default`（Steam 数据中通常显示为 `public`） |
| 当前发布平台 | Windows 64 位 |
| 正式 EXE | `LiangshanHeroes.exe` |
| 源码分支 | `codex/sync-20260905-stable` |
| Godot | `4.6.3 stable` |

Windows 候选固定为以下六个文件，不能把源码、PDB、登录缓存、`steam_appid.txt`、玩家存档或 QA 临时目录混入 Depot：

1. `LiangshanHeroes.exe`
2. `libgodotsteam.windows.template_release.x86_64.dll`
3. `steam_api64.dll`
4. `steam_stats_reader.dll`
5. `GODOTSTEAM_LICENSE.txt`
6. `STEAM_STATS_READER_GODOT_CPP_LICENSE.txt`

## 2. 什么才算“发布完成”

发布不是一个动作，而是六个彼此独立的状态：

| 阶段 | 合格证据 | 不能替代的事情 |
| --- | --- | --- |
| 本地候选完成 | QA 收据、ZIP 哈希、六成员清单、实际 EXE 短测 | 不代表已上传 |
| Depot 上传完成 | 新 BuildID、ManifestID、服务器六文件清单 | 不代表玩家正式分支已切换 |
| `default` 上线 | Steamworks 构建页回读新 Build 带 `default` 标签，或权威 app info 显示新 BuildID | 不代表客户端已经下载 |
| 补丁说明公开 | 四种语言公开页面的标题、正文和图片回读正确 | 不代表构建上线 |
| 客户端验收 | Steam 客户端完成更新，库内 manifest/文件与目标一致并从“开始游戏”启动 | 不代表真人完整通关 |
| 产品验收 | 真人试玩、完整通关、长跑性能等对应门槛通过 | 不能由自动冒烟或上传成功推导 |

对外可以说“Steam 更新已上线”的最低条件是：**新 Build 已在 `default`，补丁说明已公开，且两者都已回读确认。** 若客户端尚未下载安装，要单独说明。

## 3. 发布前先填一张发布单

每一批发布先确定并记录以下内容；缺一项不要进入上传：

```text
发布日期：
发布授权原话：
源提交 SHA：
相对上一个正式 Build 的实际变化：
不包含的内容 / 仍未开放的功能：
目标 App / Depot / 分支：5088120 / 5088121 / default
成功原生 QA 目录：
唯一候选目录：
唯一 ZIP 路径、字节数、SHA-256：
EXE 字节数、SHA-256：
六成员清单及 SHA-1：
实际 EXE 短测收据：
四语补丁说明文件：
回滚 BuildID：
```

补丁说明只写本次候选确实包含的玩家可见变化。内部接入、隐藏入口、计划功能、候选测试和未验收能力不能写成玩家已经可用。

## 4. 冻结发布来源

在 `D:\AI项目\水浒\开发工程` 执行：

```powershell
git status --short --branch
git fetch origin codex/sync-20260905-stable
git rev-parse HEAD
git rev-parse origin/codex/sync-20260905-stable
git diff --check
```

只有在目标分支正确、工作区来源清楚、没有其他任务的未完成修改，并且本地与远端关系符合预期时才继续。不要为了“变干净”而自动 `stash`、`reset`、覆盖或删除别人的改动。

同时检查：

- 本轮生产文件和文档已经提交、推送并回读远端 SHA；
- 上一个正式 BuildID、ManifestID 和发布范围有明确记录；
- 当前变化清单没有凭据、私钥、Steam 登录缓存、玩家目录、导出包或无关历史文件；
- 本轮没有误改 `macOS` Depot、其他测试分支、价格、折扣或商店发行状态；
- 已选定可回滚的上一个正式 BuildID。

## 5. 生成并冻结唯一候选

### 5.1 原生 Steam 整合 QA

选择全新的短路径作为私有 profile 根目录，不复用其他任务正在使用的目录：

```powershell
py -3 -X utf8 -B tools/run_steam_integration_qa.py `
  --native `
  --profile-root "D:\CodexTemp\lsh_steam_qa_<日期批次>" `
  --run
```

若本轮要求图形检查，再按本批 QA 方案增加 `--visual`。成功后检查 `.godot/steam_integration_qa/<批次>/receipt.json`：

- `complete` 为 `true`；
- `native` 为 `true`；
- `source_head` 是发布单记录的提交；
- 源文件哈希、原生依赖和检查数量完整；
- 日志没有被错误、解析失败或未确认退出掩盖。

源码在 QA 后发生任何生产变化，都必须重新 QA，不能沿用旧收据。

### 5.2 从成功 QA 生成候选

```powershell
py -3 -X utf8 -B tools/build_steam_candidate.py `
  --qa-run ".godot\steam_integration_qa\<成功批次>" `
  --profile-root "D:\CodexTemp\lsh_steam_candidate_<日期批次>" `
  --run
```

成功候选位于 `.godot/steam_candidates/<批次>/`。检查 `receipt.json`：

- `complete=true`；
- `uploaded=false`、`live_steam_tested=false` 是正常的本地候选边界；
- `source_head` 与发布单一致；
- 来源身份和包内身份探针都通过；
- ZIP 可重新读取，成员名、字节数和 SHA-256 与收据一致；
- 六个正式成员恰好齐全，没有第七个文件。

候选一旦进入实际 EXE 短测，就把它视为只读。后续上传必须使用这一个 ZIP，不能在上传目录重新导出、替换 DLL、改名后重压或从当前工作区临时拼包。

### 5.3 实际 EXE 短测和证据归档

每个发布批次建立独立目录 `qa/steam_release_<YYYYMMDD>/`。可参考最近成功批次的 `smoke_verified_package.py` 和 `collect_evidence.py`，但必须先核对其中固定的提交 SHA、预期数量、路径和批次名；不能原样复用旧批次的硬编码断言。

最低短测应覆盖：

- 主菜单启动；
- 八关分别启动；
- 据守 / 清敌等当前固定冒烟场景；
- 所有子进程退出并释放构建锁；
- 生产源码、真实玩家目录和候选 EXE 前后哈希不变；
- 日志没有脚本、解析、资源加载或崩溃错误。

将成功原生 QA、候选收据、短测收据和上传副本绑定到同一证据清单。失败批次保留原始失败事实，不覆盖成成功结果。

## 6. 准备四语补丁说明

Steam 构建发布时同步准备并发布以下语言：

- 简体中文
- 繁体中文
- English
- 日本語

推荐使用“小型更新 / 补丁说明”类型。每种语言至少检查：

- 标题、摘要、正文都有内容；
- Build 关联正确；
- 只描述这次实际上线的变化；
- 图片已经上传完成，不是本地路径或 `{STEAM_CLAN_IMAGE}` 占位符；
- 四种语言没有串文、漏段或只保存标题不保存正文；
- 同一 Build 已有公告时优先维护原条目，避免重复发布。

发布说明最好先落到 `marketing/steam_announcement_<批次>/` 或对应 QA 目录，再进入 Steamworks。构建上线和公告公开分别记账。

## 7. 上传方法 A：Steamworks 网页 ZIP

适合网络稳定、网页文件选择器正常的情况。

1. 打开 App `5088120` 的 SteamPipe / 构建上传页面。
2. 选择发布单中冻结的唯一 `LiangshanHeroes_Steam_candidate.zip`。
3. 等待 Depot 构建完成，记录页面返回的 BuildID 和 ManifestID。
4. 打开服务器文件清单，逐项核对六个文件的名称、字节数和 SHA-1。
5. 服务器清单与本地不一致时立即停止，不切换 `default`。

网页显示 `Build commit successful` 只表示构建创建成功；在 `default` 标签出现之前，玩家正式分支仍可能是旧版本。

## 8. 上传方法 B：SteamCMD / SteamPipe

当网页 ZIP 出现 `Error 9: Did not receive entire file`、文件选择器受限或需要可审计上传时，使用 SteamCMD。优先使用纯 ASCII 的内容目录、VDF 路径和输出目录；中文路径在交互 PTY 中曾导致乱码和失败。

### 8.1 准备内容目录

把已验证 ZIP 解压到一个全新的 ASCII 目录，例如：

```text
D:\CodexTemp\lsh_steam_upload_<批次>\content
```

解压后重新核对六成员名称、字节数、SHA-256 和 SHA-1。解压只是传输准备，不能修改候选内容。

### 8.2 显式白名单 VDF

Depot VDF 必须逐文件映射六个成员，不使用宽泛的 `*`：

```vdf
"DepotBuild"
{
    "DepotID" "5088121"
    "FileMapping" { "LocalPath" "GODOTSTEAM_LICENSE.txt" "DepotPath" "." "Recursive" "0" }
    "FileMapping" { "LocalPath" "LiangshanHeroes.exe" "DepotPath" "." "Recursive" "0" }
    "FileMapping" { "LocalPath" "STEAM_STATS_READER_GODOT_CPP_LICENSE.txt" "DepotPath" "." "Recursive" "0" }
    "FileMapping" { "LocalPath" "libgodotsteam.windows.template_release.x86_64.dll" "DepotPath" "." "Recursive" "0" }
    "FileMapping" { "LocalPath" "steam_api64.dll" "DepotPath" "." "Recursive" "0" }
    "FileMapping" { "LocalPath" "steam_stats_reader.dll" "DepotPath" "." "Recursive" "0" }
}
```

先准备 `Preview "1"` 的 App VDF：

```vdf
"AppBuild"
{
    "AppID" "5088120"
    "Desc" "<日期、内容摘要、源提交短 SHA>"
    "Preview" "1"
    "ContentRoot" "D:/CodexTemp/lsh_steam_upload_<批次>/content"
    "BuildOutput" "D:/CodexTemp/lsh_steam_upload_<批次>/output_preview"
    "Depots"
    {
        "5088121" "D:/CodexTemp/lsh_steam_upload_<批次>/depot_build_5088121_preview.vdf"
    }
}
```

预览确认只有 Windows Depot `5088121` 和六个白名单文件后，复制为正式 VDF，仅将 `Preview` 改为 `0`，并使用新的 `output_upload` 目录。

### 8.3 先预览，再正式上传

不要把密码、令牌写入脚本、VDF、日志或 Git：

```powershell
steamcmd.exe +login "<Steamworks账号>" `
  +run_app_build "D:\CodexTemp\lsh_steam_upload_<批次>\app_build_preview.vdf" `
  +quit

steamcmd.exe +login "<Steamworks账号>" `
  +run_app_build "D:\CodexTemp\lsh_steam_upload_<批次>\app_build_upload.vdf" `
  +quit
```

必须满足：Preview 退出码为 0、映射范围正确、正式上传退出码为 0，并取得新的 BuildID / ManifestID。上传日志只保留脱敏副本；原始凭据和 Steam 缓存不进 Git。

## 9. 将新 Build 切换到 `default`

1. 打开 Steamworks 的 Builds 页面。
2. 找到刚创建的 BuildID，确认 Windows Depot 对应 ManifestID 正确。
3. 选择 **Set build live on branch**，目标分支为 `default`。
4. 填写内部更新说明。
5. 确认变更预览没有触碰 macOS、测试分支或其他 Depot。
6. 完成网页确认框和 Steam 手机验证器确认。
7. 刷新权威构建页，直到同时看到：
   - 页面提示发布成功；
   - `default` 当前 BuildID 为新值；
   - 新构建行带 `default` 标签；
   - Depot `5088121` 链接到预期 ManifestID。

确认框已点、自动化调用超时、手机上刚批准或页面仍显示旧 Build，都不能算已上线。只有刷新后的权威状态回读才算。

如使用 SteamCMD 复核，可执行只读查询：

```powershell
steamcmd.exe +login anonymous +app_info_update 1 +app_info_print 5088120 +quit
```

回读时记录 `branches.public.buildid`。Steam 的玩家正式分支在 app info 中通常以 `public` 表示，与 Steamworks UI 的 `default` 对应。

## 10. 发布并回读四语公告

构建正式上线后，在 Steamworks 的 Events & Announcements 中发布本批补丁说明，并关联正确 Build。

发布后不能只看后台“Published”。至少回读：

1. Steam 新闻列表出现新标题；
2. 简中、繁中、英语、日语公开页面分别打开；
3. 每种语言的标题、正文段落和图片都正确；
4. 图片资源加载完成，不是空白、占位符或仍在处理中；
5. 公开页面关联的游戏卡和 Build 信息正确；
6. 记录 Event ID 和公开 URL。

若某语言只有标题没有正文，或图片尚未完成处理，本批公告不能记为四语验收通过。

## 11. 服务端、客户端和真人验收

### 11.1 服务端交付

有条件时从 Steam 服务器隔离下载 `default`，核对：

- appmanifest 的 BuildID / TargetBuildID；
- Depot `5088121` 的 ManifestID；
- 六成员名称、字节数和哈希；
- 服务器下载版 EXE 能以独立 profile 启动，日志无目标错误。

### 11.2 本机 Steam 客户端

让 Steam 客户端正常刷新并下载更新，不直接覆盖 Steam 管理的安装文件。随后检查：

- 本地 appmanifest 已是目标 BuildID；
- 库内文件与候选 / 服务器版一致；
- 通过 Steam“开始游戏”或 `steam.exe -applaunch 5088120` 启动；
- 实际进程来自 Steam 库目录；
- 窗口、主菜单和启动日志正常。

客户端暂时仍是旧 Build 时，应记录为“服务端已上线，客户端尚未完成更新”，不要重传生成重复 Build。

### 11.3 真人验收

自动合同、包内探针、11 例短测、服务器下载和客户端启动都不能替代完整八关、30 波、难度趣味、长跑性能、双账号或真实 Steam 统计写入。只报告本批真正完成的验收层级。

## 12. 发布收据和文档收尾

每次发布至少保存：

- 源提交 SHA、发布授权和相对上一正式版的变化清单；
- 原生 QA、候选、身份探针和 EXE 短测收据；
- ZIP / EXE / 六成员的字节数和哈希；
- BuildID、ManifestID、目标分支、服务器文件核对；
- `default` 权威回读时间和结果；
- 四语公告 Event ID、公开 URL 和逐语言回读；
- 客户端是否已更新和启动；
- 未完成的真人、性能、双账号等门槛；
- 回滚 BuildID。

同步更新：

- `docs/WORKLOG.md`
- `docs/SOURCE_SETUP.md`
- 本批 `docs/STEAM_UPDATE_<YYYYMMDD>.md`
- 本批 `qa/steam_release_<YYYYMMDD>/README.md` 和机器可读收据
- 有新增目录时更新 `docs/DIRECTORY_INDEX.md`

只把源码、生产资源、脱敏收据和必要文档按白名单提交到 `codex/sync-20260905-stable`。不提交发行 ZIP、Steam 缓存、凭据、玩家数据或无关截图。推送后回读远端 SHA；GitHub 同步与 Steam 发布仍要分别报告。

## 13. 回滚

发现阻断性问题时：

1. 停止继续推广和公告扩散；
2. 在 Builds 页把已验证的上一正式 Build 重新设为 `default`；
3. 完成确认和手机验证；
4. 刷新权威页面，确认旧 Build 重新带 `default` 标签；
5. 记录回滚时间、原因、目标 BuildID / ManifestID；
6. 若玩家已收到问题版本，发布简短更正公告；
7. 修复后生成全新的候选和 Build，不修改历史收据冒充原构建。

不要删除新 Build 来代替回滚，也不要通过覆盖 Steam 客户端文件“验证”回滚。

## 14. 常见故障

| 现象 | 处理 |
| --- | --- |
| 网页 ZIP 返回 `Error 9: Did not receive entire file` | 保留失败记录；改用 ASCII 内容目录和 VDF 的 SteamCMD，先 Preview 再 Upload。 |
| SteamCMD 在中文路径乱码 / 退出 1 | 不重写为成功；迁移上传副本和 VDF 到已核验的 ASCII 路径。 |
| 构建已创建但玩家仍是旧版 | 检查新 Build 是否真正带 `default` 标签；上传成功不等于 Set Live。 |
| 已点 Set Live 但页面仍显示旧 Build | 等待或完成确认 / 手机验证，刷新权威构建页后再判断。 |
| 服务器文件与本地哈希不一致 | 停止 Set Live；核对上传源、解压目录、VDF 映射和候选身份。 |
| 客户端还是旧 Build | 正常刷新 / 重启 Steam 并等待下载；服务端已上线时不要重复上传。 |
| 公告后台显示已发布但公开页缺正文或图片 | 逐语言重新打开编辑和公开页，补齐后再次回读。 |
| 浏览器自动化元素失效或标签页丢失 | 重新获取当前页面状态并打开权威页面；旧元素 ID 不是发布失败证据。 |

## 15. 一页发布检查表

### 发布前

- [ ] 用户已明确授权本次 Steam 发布。
- [ ] 源提交、远端提交、发布范围和上一正式 Build 已记录。
- [ ] 原生 QA 成功，源码在 QA 后未变化。
- [ ] 唯一候选 `complete=true`，六成员和哈希已冻结。
- [ ] 同一实际 EXE 的短测成功，玩家目录和源码未受影响。
- [ ] 四语补丁说明只写实际交付内容。
- [ ] 回滚 BuildID 已确认。

### 上传与上线

- [ ] 网页 ZIP 或 SteamCMD Preview 的范围只有 Depot `5088121` 六文件。
- [ ] 正式上传成功，BuildID / ManifestID 已记录。
- [ ] 服务器六成员名称、大小、SHA-1 与本地一致。
- [ ] 新 Build 已完成确认并在刷新后带 `default` 标签。
- [ ] `branches.public.buildid` 或权威构建页回读正确。

### 公告与验收

- [ ] 四语公告已公开并关联正确 Build。
- [ ] 四种语言的标题、正文和图片均已公开回读。
- [ ] 服务端下载核验结果已记录，或明确标注未执行。
- [ ] 本机 Steam 客户端更新 / 启动结果已记录，或明确标注未执行。
- [ ] 真人完整通关、性能、双账号等未完成门槛没有被误报为通过。
- [ ] 文档、QA、Git 提交和远端 SHA 已收尾。

## 16. 本项目的当前入口

本指南只描述流程，不替代每一批的实时状态。开始操作前，应先读最新的：

- `docs/STEAM_UPDATE_<最近日期>.md`
- `qa/steam_release_<最近日期>/README.md`
- `docs/WORKLOG.md` 顶部记录

截至本指南建立时，最新本地准备记录为 `qa/steam_release_20260916/README.md`；该文件明确把候选准备、Steam 上传、`default` 切换和公告公开分开。后续必须以新的 Steamworks 回读和本批发布收据更新状态，不能仅凭该历史记录判断当前线上版本。

Steam 官方参考：

- SteamPipe 上传：[Uploading to Steam](https://partner.steamgames.com/doc/sdk/uploading)
- 游戏更新：[Updating Your Game](https://partner.steamgames.com/doc/store/updates)
- 活动与公告：[Events and Announcements](https://partner.steamgames.com/doc/marketing/event_tools)
