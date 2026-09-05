# 水浒项目目录索引

2026-09-06 黄泥冈当前短篇新增：`scripts/levels/level1_huangnigang_short.gd`、`tools/huangnigang_short_test.gd`、`tools/huangnigang_short_ui_test.gd`、`docs/HUANGNIGANG_SHORT_20260906.md`、`qa/huangnigang_short_20260906/`。原生透明纲担在 `assets/campaign/objects/tribute_load_alpha_20260906_default.png`，原输出即生产字节；完整提示词与来源在 `tools/contracts/huangnigang_tribute_20260906/`，旧环境图及历史69项清单不覆盖。

暂停操作：`docs/PAUSE_MENU_20260906.md`、`tools/pause_menu_qa.gd`；最终证据在 `qa/pause_menu_20260906/`，重跑输出在 `.godot/pause_menu_qa/`。

地表透明缝：`docs/TERRAIN_ALPHA_SEAMS_20260906.md`、`tools/terrain_alpha_seam_probe.gd` 与 `tools/terrain_alpha_seam_qa.gd`；旧shader原字节固定在 `tools/contracts/terrain_seams/`（`.gdignore`），审核证据在 `qa/terrain_alpha_seams_20260906/`，临时结果在 `.godot/terrain_seam_probe/`、`.godot/terrain_alpha_seam_qa/`。

田地增量：生产图 `assets/campaign/environment/shared/surfaces/surface_field.png`；独立来源在 `tools/contracts/environment/field_20260906/`（原图/提示词/接入/固定SHA审核增量，含 `.gdignore`）。`tools/environment_field_render_qa.gd` 为真实两关对照；`docs/ENVIRONMENT_FIELD_20260906.md` 和 `qa/environment_field_20260906/` 保存说明、证据及失败尝试。

野猪林短篇：`docs/YEZHULIN_SHORT_20260906.md`记录当前合同2；`tools/yezhulin_short_test.gd`覆盖实际四路线及独立边界，旧`campaign_yezhulin_depth_test.gd`为兼容入口。临时结果在`.godot/yezhulin_short/`，本批证据在`qa/yezhulin_short_20260906/`。

江州当前入口：`scripts/levels/level2_jiangzhou_rts.gd`，说明 `docs/JIANGZHOU_RTS_20260906.md`；旧 `level2_jiangzhou.gd`保留地图来源。`tools/jiangzhou_rts_test.gd`、`tools/jiangzhou_rts_play.gd`、`tools/jiangzhou_rts_visual.gd`分别验证边界、真实两路线和界面/地图；临时结果在 `.godot/jiangzhou_rts/`，已审核证据在 `qa/jiangzhou_rts_20260906/`。

更新日期：2026-09-06（Asia/Hong_Kong）。

## Git checkout 目录（家里接续）

Git 克隆版以仓库根目录为工程根：`project.godot`、`assets/`、`scripts/`、`scenes/`、`tools/` 和 `qa/` 直接位于根下，交接文档统一在 `docs/`。下文“根目录约定”和迁移映射记录的是办公室外层工作区，不能照此在 clone 内再建立 `Liangshan-Heroes/`。

- `Play.cmd`、`tools/run_local.ps1`：源码游戏、编辑器及导入入口。
- `tools/resolve_godot.ps1`：共享 Godot 4.6.3 路径解析；`godot.local.txt` 为每台电脑独立配置，不入库。
- `qa/home_setup_20260905/`：本机接续日志、动作检查报告和主菜单截图。
- `.godot/`：本机导入缓存及临时验证文件，不入库。
- `tools/environment_art_audit.py`、`tools/environment_validation_selftest.py`、`tools/environment_validation_common.py`：环境生产/来源审计、隔离反例与跨电脑路径处理。
- `tools/contracts/environment/`：生产字节与来源缺口清单；`legacy/`记录待恢复历史原件及哈希，固定证据不按缓存处理。
- `docs/ENVIRONMENT_VALIDATION_PORTABILITY_20260906.md`、`qa/environment_validation_20260906/`：本轮入口、缺口、验证记录和输入收据。
- `docs/WORKLOG.md`、`docs/SOURCE_SETUP.md`：当前 Git 开发进度和跨电脑启动说明。
- `docs/WALL_AND_NAVAL_FOUNDATION_20260906.md`：木墙脚点修正与限定关卡启用的造船底层说明。
- `scripts/naval_production.gd`、`tools/naval_production_test.gd`、`tools/naval_production_visual.gd`：泊位、岸边施工、付费下水及取消/重建验证；高俅当前入口显式启用船坞，驻守不启用。
- `tools/wall_alignment_test.gd`、`tools/wall_alignment_visual.gd`、`tools/rts_performance_probe.gd`：墙脚/门接缝/遮挡与实机对照，正常1倍短窗性能采样。
- `qa/wall_naval_20260906/`：本批墙与船坞的通过日志、失败尝试、前后图和输入哈希。
- `docs/CAMPAIGN_FUN_REWORK_20260905.md`：八关总体设计与官方参考；祝家庄、连环马、大名府、高俅及江州补给关已有样板，三个短篇后续实施。
- `docs/GAO_RTS_20260906.md`、`scripts/levels/level5_gao_rts.gd`：当前高俅入口、持续水陆经营、火攻接应和实际押俘回堂。
- `tools/gao_rts_test.gd`、`tools/gao_capture_test.gd`、`tools/gao_rts_play.gd`、`tools/gao_rts_visual.gd`：经济/来源/结局边界，真实两路线与图形/长任务列表验证。
- `qa/gao_rts_20260906/`：高俅最终结果、失败尝试、两尺寸图、实战图和输入哈希；受控夹具与实战分别记录。
- `docs/DAMING_RTS_20260905.md`、`scripts/levels/level8_daming_rts.gd`：大名府当前入口、经营/潜入/火号/护送说明；旧level8脚本保留地图来源。
- `tools/daming_rts_test.gd`、`tools/daming_infiltration_test.gd`、`tools/ranged_firing_path_test.gd`、`tools/daming_rts_visual.gd`：两条实战、输入边界、隔墙远程接近和图形验证。
- `qa/daming_rts_20260905/`：本轮结果、失败尝试、截图与输入哈希收据，包含其他关卡回归的独立子目录。
- `docs/LIANHUANMA_RTS_20260905.md`、`scripts/levels/level4_lianhuanma_rts.gd`：当前连环马菜单入口、持续经营/反骑/辎重营与教场说明；旧level4脚本保留作历史参考。
- `tools/lianhuanma_rts_test.gd`、`tools/lianhuanma_drill_test.gd`、`tools/lianhuanma_rts_visual.gd`：本关边界、两条实战、教场输入及图形验证。
- `qa/lianhuanma_rts_20260905/`：最终182项、三张图、输入哈希；attempts保留失败尝试，不属于最终通过项。
- `docs/RELEASE_READINESS_20260905.md`：首个可售版本的当前证据、缺口与后续验收，未宣称已经达到发行质量。
- `docs/ZHUJIAZHUANG_RTS_20260905.md`：祝家庄 RTS 样板玩法、实现边界及验证入口。
- `scripts/levels/level3_zhujiazhuang_rts.gd`：当前祝家庄菜单入口；旧 `level3_zhujiazhuang.gd` 保留作原流程参考。
- `tools/zhujiazhuang_rts_test.gd`、`tools/zhujiazhuang_rts_visual.gd`：场内回归、真实自动路线与图形检查。
- `qa/zhujiazhuang_rts_20260905/`：本轮验证结果、图形截图与文件收据。
- `tools/zhujiazhuang_rts_feedback_test.gd`、`tools/zhujiazhuang_rts_gate_visual.gd`：守军接敌/施法回归、双英雄冲关对照及寨门轴向截图。
- `qa/zhujiazhuang_rts_feedback_20260905/`：试玩问题复现与修复后的路线、守军和门体对照记录；不覆盖初版样板证据。
- `scripts/campaign_gate_visual.gd`：按原图墙脚锚定门墙连接与阴影；祝家庄两门和大名府南门分别显式配置，大名府另有关闭门扇。
- `tools/zhujiazhuang_gate_contact_test.gd`、`tools/zhujiazhuang_gate_contact_visual.gd`：群选接应回归与门墙/开门图形检查。
- `qa/zhujiazhuang_gate_contact_20260905/`：本轮门墙、接应、路线与跨模式QA。
- `tools/character_direction4_inventory.gd`、`docs/CHARACTER_DIRECTION4_20260905.md`：全库角色四向清单生成与制作状态。
- `qa/character_direction4_inventory_20260905/`：逐key缺口和首批被拒收候选；候选目录不属于生产素材。

## 2026-09-05 测试上传与 GitHub 接入

- `Liangshan-Heroes/qa/steam_test_build_20260905/`：本轮冻结输入清单、成品专项、Steam 上传与 GitHub 同步收据。
- `Liangshan-Heroes/docs/STEAM_TEST_BUILD_20260905.md`：构建 `25136463` 已成为 public/default，SteamCMD 强制刷新回读确认；远端回下载和客户端状态分别记录，不再把旧 `25121101` 当作当前包。
- `<server_verify>`：本轮服务器隔离回下载验证目录，appmanifest、EXE 哈希与主菜单启动已通过，证据为 `Liangshan-Heroes/qa/steam_test_build_20260905/server_download_verified.json`；不是玩家 Steam 库或开发主目录。
- `<frozen_project_snapshot>`：2364 文件独立只读测试输入快照；不是新的开发主目录。
- `<steam_build>\windows`：仅一份可上传的游戏 EXE；禁止上传开发工程、QA 或凭据。
- `<fresh_clone>`：本轮 GitHub 同步专用 checkout；开发工程仍保持原位置。目标分支 `codex/sync-20260905-stable`、PR #1，代码/素材提交 `863fcf0` 已回读，main 未变。
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
