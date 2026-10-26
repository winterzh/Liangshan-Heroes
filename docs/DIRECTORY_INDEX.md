# 项目目录索引（2026-10-20）

## 当前文档入口

| 用途 | 文件 |
| --- | --- |
| 仓库首页 | [README](../README.md) |
| 版本、交付范围与剩余工作 | [项目总览](PROJECT_STATUS.md) |
| 后续顺序与完整验收条件 | [开发计划](DEVELOPMENT_PLAN.md) |
| 启动、换机、共享引擎与源码同步 | [源码设置](SOURCE_SETUP.md) |
| 按批次记录完成事项 | [开发日志](WORKLOG.md) |
| 本次Steam更新 | [更新文档](STEAM_UPDATE_20261019.md) |
| Steam交付步骤 | [发布指南](STEAM_RELEASE_GUIDE.md) |
| 美术缺口与来源 | [全量美术台账](ART_COMPLETION_20260926.md)及各人物/场景实现说明 |
| 入口文档历史与本次清理 | [QA及恢复说明](../qa/storage_cleanup_20261020/README.md) |

## 运行与资源目录

| 位置 | 用途 |
| --- | --- |
| `project.godot`、`Play.cmd` | Godot工程及本机启动器 |
| `scripts/`、`scenes/`、`assets/` | 运行代码、场景、正式资源及必要来源链 |
| `native/`、`vendor/` | 原生接口、第三方依赖与许可 |
| `tools/` | 构建、检查及受控执行工具 |
| `docs/` | 当前入口及人物/场景/玩法等专题说明 |
| `qa/` | 实际检查、失败记录、候选和来源证据；存在文件不代表已采用 |
| `marketing/` | 平台说明与宣传材料 |
| `.godot/`、`build/`、`scratchpad/` | 本地缓存/产物/临时资料，不据此同步全部文件 |
| `D:/AI项目/水浒/历史资料`、`归档` | 历史材料和可恢复归档 |

## 本批索引与新增规则

`qa/lianhuanma_resume_20261026/`：连环马自然付费训练、同槽同token三进程接续的外部驱动、执行器、成功及失败收据；私有存档与运行缓存留本机，100项只属于内部活动期专项。新的事务集成图在该目录。

`qa/campaign_progress_recovery_20261026/`：重基14文件候选、新context生命周期的135项训练证据、自然终局/重启旧槽拒绝1364项成功与首轮失败；`rebased_candidate/`尚未采用生产，`handoff_candidate/`的23c源码已通过99项模型、尾账/纠正回归、13阶段真实文件专项（含两类预期拒绝）及黄泥冈1386项；同源经典30波六进程443项也已通过。`store_protocol_candidate/`为仅替Store的后继候选和独立原生工具，修复唯一目录释放与首次重试CAS冲突，已另冻导入，14项模型及23进程/370项真实文件专项符合预期，延迟写入首批暴露外部PID判死问题，须先修统一恢复准入，尚无完整恢复或生产资格。当前资格见[本批README](../qa/campaign_progress_recovery_20261026/README.md)。

`qa/huangnigang_production_20261020/`：当前七车十一担生产接入、真实路线和内部冷恢复驱动；源码快照、导出程序及原始运行日志存于被忽略的`.godot`同名批次目录。隔离用户目录使用同盘短路径`D:/CodexQA/hngp/<唯一标识>`，具体位置见每次收据；完成证据以本批README为准。

`qa/storage_cleanup_20261020/`记录六份入口文档归档、哈希、重复缓存映射、实际删除流水和保护后验。10月19日旧缓存清理见[原记录](../qa/storage_cleanup_20261019/README.md)，本次Steam交付见[发布QA](../qa/steam_release_20261019/README.md)。

每类信息只维护一个当前入口，其他文档用链接引用；旧批次PID、命令和状态留对应QA，不再六处复制同一段过程日志。新增实现与QA目录后更新本索引，保留原图/提示/父图/原著依据/失败记录。候选与生产、源码同步与平台交付分别说明。

[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)含整理前完整3,509行索引；旧来源清单绝对路径不批量改写。

## 2026-10-20 待提交来源入库

- `qa/pending_source_sync_20261020/`：原107个文件清单、SHA与只读检查。
- [公孙胜原型](../qa/gongsun_sheng_mounted_draw_20261019/README.md)：补齐剑臂与rig_v1/v2/v3候选源码。
- [杨林连续腿预览](../qa/yang_lin_continuous_leg_preview_20261019/README.md)：补齐构建/诊断/HTML/JS，候选未采用。

## GitHub导航与协作文件

- [CHANGELOG](../CHANGELOG.md)：Steam更新及15个历史GitHub Release索引。
- [CONTRIBUTING](../CONTRIBUTING.md)：协作与反馈入口。
- [docs导航](README.md)、[QA导航](../qa/README.md)：当前文档与证据分工。
- [仓库约定](GITHUB_REPOSITORY.md)：两个分支、38个标签、Release与管理员字段。
- `qa/github_organization_20261020/`：本次平台快照与整理检查。

## 2026-10-26 历史测试快照

`qa/storage_cleanup_20261026/` 保存54个旧project的归档索引、逐文件清单、SHA校验、保护结果和恢复工具；本机ZIP位于外层`归档/`，不入Git。旧批次原目录保留恢复提示及原有`.godot`，需要复验时先按[恢复说明](../qa/storage_cleanup_20261026/README.md)还原对应快照。

## 2026-10-26 第二轮与失效归档入口

`qa/storage_cleanup_20261026_round2/`：三个旧project的重复文件->当前保留文件/Git blob映射、独有文件索引、恢复器和保护检查。上一轮ZIP及9月7日7z已在其他聊天按用户要求删除，旧QA顶部已有现状提示；最新入口见[第二轮说明](../qa/storage_cleanup_20261026_round2/README.md)。

## 2026-10-26 战役奖励交接候选与故障证据

`qa/campaign_progress_recovery_20261026/process_liveness_candidate/`：独立C# Windows进程查询helper、Godot三态适配器和构建/模型/原生组件证据。已有13例helper、22项模型、49项Godot组件及独立19项超时检查通过；exe在忽略产物中，后继Store恢复准入另验。

`qa/campaign_progress_recovery_20261026/live_owner_candidate_tests/`：真实双进程活写者保护驱动；f6ef基线已复现活锁误清理，原始证据见同级`evidence/live_owner_baseline_20261026_234140/`。诊断成功不等于修复通过。

`qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/`：base/Steam Store、进程级manager和oracle v2的独立恢复候选、来源清单及专项验证；资格以该目录实测收据为准，未采用生产。

`qa/campaign_progress_recovery_20261026/prepare_liveness.py`：23脚本及固定native helper的独立冻结入口；默认预检，`--prepare`只创建新的私有工程，不启动引擎或改生产。导入和运行需另占共享通道。

`qa/campaign_progress_recovery_20261026/handoff_candidate/`：20文件独立候选、精确清单、模型/尾账回归/真实I/O/经典30波外部驱动及后继恢复协议设计。`evidence/` 保留每版来源、原始失败和成功worker收据；`generated_uids/` 是绑定冻结身份的少量文本证据，不能作为普通缓存忽略。当前范围和未验证门槛以[候选说明](../qa/campaign_progress_recovery_20261026/handoff_candidate/README.md)为准。

`qa/campaign_progress_recovery_20261026/tests/lianhuanma/`与`run_lianhuanma_terminal.py`：实际菜单/Flow的四进程自然胜利驱动，独立绑定当前20文件候选；只读身份预检通过，尚未编译或原生验收。使用方式及不授予的资格见[执行器说明](../qa/campaign_progress_recovery_20261026/tests/lianhuanma/README.md)。

`qa/campaign_progress_recovery_20261026/tests/lianhuanma_loss/`与`run_lianhuanma_loss.py`：真实Flow自然失败三进程代码，尚未原生运行。`evidence/store_protocol_io_20261026_220853/`保存23进程/370项已退出前提的真实文件证据；`store_delayed_first_failed_20261026_223919/`及`process_liveness_api_20261026_225300/`保留外部PID判断失败、最小原生API复现和官方来源。

## 2026-10-27 存档恢复与交错专项

`qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/tests/io_v2/`：严格23脚本＋helper的独立执行适配；23进程370项文件故障、4进程129项延迟写入已通过。原始输入、宿主、断点、helper JSON与逐文件SHA分别保存在 [文件专项](../qa/campaign_progress_recovery_20261026/evidence/liveness_io_v2_20261027_003556/README.md)、[交错专项](../qa/campaign_progress_recovery_20261026/evidence/liveness_delayed_v2_20261027_010849/README.md)，合成账号目录、exe与缓存留本机。半pending拒绝与成功恢复分别记录，不授全战役或SDK资格。

## 2026-10-27 继续入口三脚本候选

qa/campaign_progress_recovery_20261026/continue_binding_candidate/：Flow/Session/本地生命周期修复、新独立冻结准备器、baseline/fixed真实磁盘模型及来源。当前资格集中于 [VALIDATION](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/VALIDATION.md)，原README与source_manifest保持准备时字节；新增分支诊断工具未运行时仍不得当公开入口验收。
