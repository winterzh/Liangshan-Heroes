# 源码设置与换机（2026-10-26）

## 当前入口

本机开发目录：`D:/AI项目/水浒/开发工程`；打开其中 `project.godot`。桌面旧目录为历史兼容入口。黄泥冈首批开发已切回 `codex/sync-20260905-stable`，从main/stable同源的1598c7c0开始；已验证实现及证据提交`f5325c25`已推送并回读一致，后续交接文档独立同步，最新SHA仍以Git回读为准。[当前版本](PROJECT_STATUS.md)、[开发计划](DEVELOPMENT_PLAN.md)。

## 启动与导入

需要Godot **4.6.3**。仓库根目录运行 `Play.cmd`；进入编辑器用 `Play.cmd -Mode editor`，仅准备导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器会先检查导入缓存。

本机引擎路径依次来自 `-GodotPath` 参数、`GODOT_PATH` 环境变量、被Git忽略的 `godot.local.txt`，最后查PATH。不要将机器绝对路径、SDK凭据或签名配置写入生产脚本。Steam发布程序与源码启动分开，不能用编辑器启动代替发行包验收。

## 换机与Git同步

在自己的Git checkout开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

核对目标分支和远端后，仅在无未完成修改且可快进时 `git pull --ff-only`。若有分叉或共享修改，先检查来源，不自动stash、reset或覆盖。既定开发同步分支为 `codex/sync-20260905-stable`；本次主线合并有用户明确授权，未来合并和平台发布仍按AGENTS.md与当次授权。

每轮验证后同步更新本文件、WORKLOG及本批文档；按逐文件白名单提交，不用全盘git add、强推或改写历史。推送后读回远端SHA。禁止上传Steam登录/缓存、玩家存档、Godot缓存、安装包、密钥和无关历史备份。

## 验证与共享引擎

新增[继续入口三脚本候选](../qa/campaign_progress_recovery_20261026/continue_binding_candidate/VALIDATION.md)必须用自己的d7f2258b完整冻结与新manifest，不能套用e97a的恢复专项资格。已导入并通过独立本地绑定模型，连环马实际Flow重跑中。prepare_continue默认只读，--prepare只建新目录；磁盘模型的baseline/fixed模式和真实胜败执行器分别记资格，禁止复用同一结果混算。

当前新增[进程存活三态组件](../qa/campaign_progress_recovery_20261026/process_liveness_candidate/README.md)，已有13例原生helper、22项报告模型、49项Godot组件及独立19项超时证据；未集成生产。构建exe只留忽略产物，换机必须按源码构建并核对本次SHA；Godot组件执行器默认只读预检，显式`--execute`才持共享锁运行。[同步恢复桥接](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/README.md)另行验证，不能把独立组件通过当成存档修复完成。

后继23脚本候选已独立冻结/导入，活写者保护双进程45项、同源23进程文件故障370项及两种延迟写入交错4进程129项通过；半 pending 明确安全拒绝，未授完整恢复或双 Ledger 全并发资格。`prepare_liveness.py`默认只读，`--prepare`只准备新私有工程，实际导入及原生运行分别占共享引擎；当前运行命令和精确身份集中在[桥接入口](../qa/campaign_progress_recovery_20261026/process_liveness_integration_candidate/README.md)，不采用到生产或沿用旧冻结资格。

基础[20文件奖励交接候选](../qa/campaign_progress_recovery_20261026/handoff_candidate/README.md)为独立冻结`20261026_194542_27c8aea9`、身份`source-v1:23c0b07fcba83a9d7938ed338a9775559b6041be61d048db619c31fd5edc2a80`，已导入并通过99项模型和纠正/尾账逻辑回归。真实I/O已完成13阶段专项（含两类预期拒绝），同源黄泥冈自然终局/重启拒旧槽另通过1386项，经典30波六进程443项也已通过（30波778敌、三次保存独立恢复、两次终局拒旧槽）；不能把旧811源75/135项或14文件源1364项转授新版。原脚本、原worker和失败证据保留；准备/模型/文件故障/经典30波执行器及未运行范围在该目录说明。

后继[唯一目录释放候选](../qa/campaign_progress_recovery_20261026/store_protocol_candidate/README.md)必须用自己的20文件清单另建冻结；19文件与23c原字节一致，仅替Steam Store。新冻结`20261026_211212_dd3104df`的f6ef源码已导入、14项模型及23进程/370项真实文件专项通过（含半pending预期拒绝），延迟写入首批因外部PID存活查询限制停止，须先修统一恢复准入再另冻验证；旧23c经典通过不授予f6ef完整回归资格。模型、23进程真实文件故障及[两种延迟写入交错](../qa/campaign_progress_recovery_20261026/store_protocol_candidate/tests/io/README_delayed.md)均有独立宿主，不能套用旧23c或旧199c冻结的结果。经典回归运行时固定其外部worker/README；不要边跑边改。

连环马新增[四进程自然胜利执行器](../qa/campaign_progress_recovery_20261026/tests/lianhuanma/README.md)：默认只读预检，必须显式`--run`才启动引擎。原f6ef预检保留为历史准备。宿主现已显式支持e97a的23脚本和固定helper，胜利四流程及失败三流程各自串行运行、各自取得资格；实际终态以执行器收据为准，旧源预检不转授新版。保存退出走真实Flow，前两阶段由生产AppLifecycle正常退出，不能用Session直调替代。失败路线将独立验证。

新的[战役context候选](../qa/campaign_progress_recovery_20261026/README.md)有独立准备/导入及训练执行器；连环马135项验证新生命周期活动期，黄泥冈1364项验证正常离线终局和重启旧槽拒绝。使用同一已导入冻结根、外部驱动和新隔离profile，`CAMPAIGN_QA`须为空，不能对旧候选或下一奖励交接草稿转授结果。

连环马新增[三进程训练执行器](../qa/lianhuanma_resume_20261026/README.md)，复用已导入且身份匹配的冻结工程，在独立短profile、屏幕外真实GL上运行，最终100项通过。它只证明旧内部活动期同槽接续；新的战役context事务候选须重新冻结，不能沿用这份结果。真实迷雾存档不能用headless dummy渲染替代，跨进程报告使用无损Codec保留整数类型和浮点位。

黄泥冈当前已接入七车十一担与内部v2存档边界。最终冻结`20261026_162550_230a5af6`的包内普通计时路线1206项和九阶段专项1768项通过；原版EXE启动/退出检查通过，完整键鼠流程待继续。用户暂不恢复界面自动操作，后续代码/文档工作可继续；不得据此标为整批完成或开放战役续玩。复现命令、精确来源及历史失败统一见[本批QA](../qa/huangnigang_production_20261020/README.md)。新生成旧三担夹具时须使用真实旧Git基线；七车实现提交后，当前HEAD不再是旧布局，不能重标v2档作为旧档测试。

依据具体修改选择对应 `qa/` 及实现文档的当前入口。旧harness/producer只证明其绑定的冻结源码，不因为文件仍在就能用于新版本。先检查已有执行器/共享锁及实际进程，等自然空闲，串行使用Godot；不重复启动或控制其他聊天的进程。新执行器按相应审查要求接入，失败原证据保留。

旧私有测试工程的重复缓存已有清理记录；复验前按对应Godot版本重新导入，或按保留副本与SHA映射恢复缺失文件，不能覆盖仍存在的差异缓存。主缓存、源码/原图、发布包、存档和Git对象不在本轮删除范围。

## 发布与历史

当前Steam Build26048429，冻结生产来源0083b47a；[发布指南](STEAM_RELEASE_GUIDE.md)、[本批更新文档](STEAM_UPDATE_20261019.md)。源码同步、上传、default上线、四语公告、客户端下载/启动与真人接受分别记录。完整战役续玩未开放，经典固定30波保存/继续保留。

[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)包含本次整理前全部设置/旧工具说明。临时批次命令留在对应QA，避免再次把历史状态堆入当前启动入口。

## 2026-10-20 待提交候选已全部保存

原81份资源导入配置及26份候选工具/预览源码已补交，详见[入库记录](../qa/pending_source_sync_20261020/README.md)。`.import`设置随原资源入库，`.godot`生成缓存仍不上传；候选绝对路径与冻结绑定只作原批快照，换机执行前重新核对，不据源码同步授予生产资格。

## GitHub入口

当前版本与历史安装包见[更新记录](../CHANGELOG.md)，分支和管理字段见[仓库约定](GITHUB_REPOSITORY.md)，源码参与方式见[协作说明](../CONTRIBUTING.md)。专题资料从[文档导航](README.md)和[QA导航](../qa/README.md)进入，不移动原有工具/素材路径。

## 旧测试工程恢复（2026-10-26）

54 个旧人物测试 project 已转为本机去重归档；历史 receipt/重放需要这些路径时，先按[本批说明](../qa/storage_cleanup_20261026/README.md)恢复所选 prefix，再使用原绑定的引擎与数据。当前游戏启动方式不变；主缓存、旧私有缓存、当前黄泥冈和Steam批次保留。

## 旧快照恢复状态更新（2026-10-26）

上一轮54快照ZIP及9月7日7z已按用户在另一聊天的明确要求删除，不能再依赖旧归档路径恢复。第二轮三个旧快照只去掉与现有文件和Git原始blob一致的副本，按[本轮映射与恢复器](../qa/storage_cleanup_20261026_round2/README.md)补齐；未列入映射的独有文件和私有缓存保持。

连环马[自然失败三进程执行器](../qa/campaign_progress_recovery_20261026/tests/lianhuanma_loss/README.md)已完成代码和静态复核，尚未编译或原生执行；与胜利驱动各自保留独立来源和报告，不共享通过资格。
