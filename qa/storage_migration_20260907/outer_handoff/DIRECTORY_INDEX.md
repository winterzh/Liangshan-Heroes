## 本机存储位置更新：2026-09-07

当前开发与 Git 提交入口已固定为 `D:\AI项目\水浒\开发工程`，直接打开其中的 `project.godot`，或运行 `D:\AI项目\水浒\开始游戏.cmd`。后续修改、验证和收尾以新开发目录的 `AGENTS.md` 与 `docs/` 为准。

原桌面目录完整内容保存在 `D:\AI项目\水浒\历史资料`。原 C 根因当前会话占用而保留，8 个子目录均为指向 D 历史资料的 junction，只有少量根交接文件留在 C；旧 `D:\CodexTemp\liangshan-github-sync-20260905-5f8a7c2e` 也已成为指向新开发工程的 junction。旧来源清单的绝对路径保持原文，不批量替换。以下旧位置与旧进度属于历史记录，不作为当前开发入口。

迁移时 17,241 个历史文件 SHA-256 全部一致，核验后移除 C 中 17,232 个目录内数据副本，释放约 5.74 GiB；保留全部来源、历史资料与缓存到 D。新开发工程 Godot 4.6.3 导入及隔离 180 帧无头启动均退出 0、错误 0。详见 `D:\AI项目\水浒\开发工程\qa\storage_migration_20260907\README.md`。本轮只变更存储位置、入口说明和文档，不修改游戏内容或发布。

## 公司 Steam 测试分支上传：2026-09-07

- `D:/CodexTemp/liangshan-github-sync-20260905-5f8a7c2e/qa/company_steam_upload_20260907/`：Build `25160280`、Depot `5088121` / Manifest `399339942090359717`、`steam-integration` 分支及服务端四文件核对收据。
- 本历史外层及旧 `Liangshan-Heroes/` 保持交接用途；当前源码、构建与 Git 同步均从上方独立 checkout 执行。

## 本机公司开发入口：2026-09-07

公司当前开发工程已接续到独立 Git checkout：`D:/CodexTemp/liangshan-github-sync-20260905-5f8a7c2e`。Godot 工程在该目录根部，打开 `project.godot`、运行 `Play.cmd`；本机 Godot 4.6.3 已配置并验证主菜单和标准驻守入口。

最新进度见[独立工程当前进度](D:/CodexTemp/liangshan-github-sync-20260905-5f8a7c2e/docs/PROJECT_STATUS.md)，本轮证据见[公司接续 QA](D:/CodexTemp/liangshan-github-sync-20260905-5f8a7c2e/qa/company_handoff_20260907/README.md)。本外层及原 `Liangshan-Heroes/` 保留历史内容；后续修改、验证和 stable 提交以独立 checkout 为准。

# 水浒项目目录索引

更新日期：2026-09-05（Asia/Shanghai）。

## 2026-09-05 测试上传与 GitHub 接入

- `Liangshan-Heroes/qa/steam_test_build_20260905/`：本轮冻结输入清单、成品专项、Steam 上传与 GitHub 同步收据。
- `Liangshan-Heroes/docs/STEAM_TEST_BUILD_20260905.md`：构建 `25136463` 已成为 public/default，SteamCMD 强制刷新回读确认；远端回下载和客户端状态分别记录，不再把旧 `25121101` 当作当前包。
- `D:\SteamBuilds\Liangshan_5088120\server_verify_25136463`：本轮服务器隔离回下载验证目录，appmanifest、EXE 哈希与主菜单启动已通过，证据为 `Liangshan-Heroes/qa/steam_test_build_20260905/server_download_verified.json`；不是玩家 Steam 库或开发主目录。
- `D:\水浒测试构建\steam_test_20260905_110235\project`：2364 文件独立只读测试输入快照；不是新的开发主目录。
- `D:\SteamBuilds\Liangshan_5088120\20260905_110235\windows`：仅一份可上传的游戏 EXE；禁止上传开发工程、QA 或凭据。
- `D:\CodexTemp\liangshan-github-sync-20260905-5f8a7c2e`：本轮 GitHub 同步专用 checkout；开发工程仍保持原位置。目标分支 `codex/sync-20260905-stable`、PR #1，代码/素材提交 `863fcf0` 已回读，main 未变。
- 上一轮临时 Git index 混合状态不作同步依据；没有删除或搬动任何现有工程。

## 根目录约定

| 路径 | 用途 | 处理规则 |
| --- | --- | --- |
| `Liangshan-Heroes/` | 当前 Godot 开发工程 | 保持原路径；源码、生产素材、项目内 QA 均从这里运行 |
| `implementation_20260902/` | 当前工具仍读取的网页来源、候选与改前备份 | 暂不移动；改路径前必须同步工具和清单 |
| `implementation_20260903/` | 9 月 3 日仍被生产清单引用的实施证据 | 暂不移动；完成来源闭环后再归档 |
| `_design/` | 视觉设计源、已批准基线与未接入草稿 | 概念图不直接作生产贴图；接入状态以各批 manifest 为准 |
| `_archive/` | 只读历史快照、基线、旧发布候选和原始包 | 不作为当前生产输入；不得用旧证据宣称当前完成 |
| `_logs/` | 根目录级工具和导入日志 | 可再生成日志可按批次清理 |
| 根目录 `*.md` | 当前交接、进度、设计原则和本索引 | 每轮目录或完成度变化后同步更新 |
| 根目录 `*.cmd` | 当前开发/预览入口 | 必须指向现行目录，不指向已迁移旧路径 |
| `AGENTS.md` | 项目协作与每轮收尾规范 | 开发完成后更新相关项目文档，并向已确认的 GitHub 目标同步；未配置目标时明确报告阻塞 |

## 当前结构

```text
水浒/
├─ Liangshan-Heroes/             当前 Godot 工程
├─ implementation_20260902/      活动实施来源与备份
├─ implementation_20260903/      活动实施证据
├─ _design/
│  └─ ui_design_20260902/        已接入的“克制宋韵”UI视觉基线
├─ _archive/
│  ├─ baselines/                 历史哈希与需求基线
│  ├─ campaign_history/          环境和战役重做历史批次
│  ├─ release_candidates/        旧发布候选
│  ├─ source_packages/           原始下载包
│  └─ visual_samples/            v1-v7 视觉迭代与源码备份
└─ _logs/                         根目录日志
```

## 2026-09-03 迁移映射

- `art_requirements_baseline_20260902_024451/` → `_archive/baselines/art_requirements_baseline_20260902_024451/`
- `campaign_environment_v8_20260831/` → `_archive/campaign_history/campaign_environment_v8_20260831/`
- `campaign_rework_20260831_173850/` → `_archive/campaign_history/campaign_rework_20260831_173850/`
- `release_candidate_20260901_134110/` → `_archive/release_candidates/release_candidate_20260901_134110/`
- `visual_sample_20260831/` 至 `visual_sample_v7_20260831/` → `_archive/visual_samples/`
- `Liangshan-Heroes-0109b6f-complete.zip` → `_archive/source_packages/`
- `ui_design_20260902/` → `_design/ui_design_20260902/`
- `godot-import.log` → `_logs/godot-import.log`

历史 QA 快照中记录的旧绝对路径保持原文，以免篡改当时证据；读取这些快照时按本表转换。当前入口文档、预览启动器和仍会读取战役基线的审计工具已经改为新路径。

## 后续新增规则

1. 当前可执行工程只放在 `Liangshan-Heroes/`，不要在工程内部嵌套另一份 Godot 工程。
2. 新网页原图、候选和改前备份按日期进入一个 `implementation_YYYYMMDD/`，不要散落根目录。
3. 结束且不再被工具读取的实施批次，完整迁入 `_archive/implementation_history/`，同时更新本索引和活动工具路径。
4. 新视觉对比放入 `_archive/visual_samples/<批次名>/`，不要再创建新的根目录 `visual_sample_*`。
5. 新发布候选放入 `_archive/release_candidates/<批次名>/`；Steam 发布目录仍与本工作区隔离。
