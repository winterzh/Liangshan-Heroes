# 源码设置与换机（2026-10-30）

连环马当前 worker 策略新增枪兵并行预走位，逆补丁对原司机字节验证通过。诊断工具可读取已验证的尾段再保存报告并复制私有档，完整终局仍由正式验收流程判定。[诱骑诊断与短程复验](../qa/campaign_resume_current_20261116/README.md#诱骑走位短程复验)。


连环马续接工具接受原流程至少一个已通过的保存阶段，下一进程须因引擎占用而未打开日志或报告。后续启动遇相同抢占时等待，已启动的战斗失败继续保留原结果。[来源和首段回执](../qa/campaign_resume_current_20261116/evidence/protected_drill_candidate/)。


2026-11-16 连环马演练骑复用Unit已有的 campaign_no_auto_target 标记。Unit通用元数据保存和恢复按原方式保留该布尔值，无新增结构字段。本次生产内容身份变化，后续续玩验证须绑定当前来源。[教场诊断与定向验证](../qa/campaign_resume_current_20261116/README.md)。


2026-11-16 新增当前玩法续玩整合候选工具。qa/campaign_resume_current_20261116/prepare.py以Git固定blob、当前规范输入、三方合并Battle、11原UID和13明确导入元数据合成无缓存工程；native helper由--native-root指定本机来源并核对源码/构建收据/EXE，不入库二进制。当前合成身份b32972f3已通过自身首次冷导入，生产26模块尚未采用。run_lianhuanma.py绑定新来源使用原四进程完整演义断言，不能沿用旧批资格。[本批来源与记录](../qa/campaign_resume_current_20261116/README.md)。


2026-11-16 高俅第三批原末两船护航座船，角色由原groups/waves/flagship派生；只用普通Unit指令，未新增Level字段/计时器，旧冻结恢复资格不沿用。campaign_flagship_escort.json新增两条四语；QA记录器只监听原船死亡，不修改战斗。[本批来源与限定证据](../qa/campaign_flagship_escort_20261116/README.md)。


2026-11-16 高俅火攻/接应/撤离条件抽出供任务与HUD共用，原边界保持；提示实时派生，无新增Level/Visual字段，生产身份变化不沿用冻结恢复资格。新增campaign_fire_readiness.json七条四语。gao_rts_play故事驾驶增加实际返港阶段，其间专船不混入普通攻击编组；只在QA中生效。[来源与限定验证](../qa/campaign_fire_readiness_20261116/README.md)。


2026-11-16 大名府daming_select_wounded进入Mission官方按钮白名单，沿用Presentation固定回调；成员由原伤员/既有状态实时派生，无新增Level字段。新增campaign_wounded_selection.json四条四语并同步catalog。生产来源变化不沿用冻结恢复候选资格。[本批实现与双路线证据](../qa/campaign_wounded_selection_20261116/README.md)。


2026-11-16 连环马新增raid实跑入口参数；本批未改游戏代码或素材，关卡与e58f3fa3及前批防守来源同SHA。验证记录器改在Unit.died收集原十二骑ID，避免节点释放后的访问；该连接只在QA中安装。[来源与验证边界](../qa/campaign_cavalry_raid_20261116/README.md)。


2026-11-16 连环马护军角色由既有waves/riders/source_lane派生，普通指令仍由Unit保存；Level字段结构保持，生产身份改变，旧候选资格不沿用。新增campaign_cavalry_escort.json三条四语。[本批来源与验证边界](../qa/campaign_cavalry_escort_20261116/README.md)。


2026-11-16 黄泥冈运输分组实时派生，无新增Level/Visual字段；hg_empty_carts、hg_loaded_carts纳入官方按钮白名单。campaign_transport_groups.json新增八条四语并同步catalog；源码身份改变，冻结续玩资格不沿用。[来源与验证边界](../qa/campaign_transport_groups_20261116/README.md)。


2026-11-16 快活林反击标记由原exposed_left等状态在Battle Overlay重绘，不新增Level/Visual字段或节点；profile结构保持，源码身份改变，旧冻结候选资格不沿用。新增campaign_counter_window.json同步catalog。[本批来源与限定验证](../qa/campaign_counter_window_20261116/README.md)。


2026-11-16 野猪林到达反馈由现有位置/指令实时派生，不新增存档字段；pine_waiting登记到Mission官方按钮白名单，沿用固定Presentation回调。四语来源campaign_escort_arrival.json同步catalog。源码身份变化，旧冻结候选不沿用；[来源、定向检查与恢复边界](../qa/campaign_escort_arrival_20261116/README.md)。


2026-11-16 公共HUD与任务布局适配实际底栏，增加生产队列滚动容器；未增加保存字段，但生产身份已变化，旧冻结续玩候选资格不沿用。[定向布局证据与剩余范围](../qa/campaign_overlays_20261116/README.md)。


2026-11-16 高俅保存profile为`campaign_level5_v2`，新增`fire_abandoned`及载客引用一致性约束；生产身份改变，旧候选不沿用。翻译来源`campaign_naval_recovery.json`同步catalog。[本批来源与限定验证](../qa/campaign_naval_recovery_20261116/README.md)。


2026-11-16 大名府接应/撤离反馈新增`assets/localization/campaign_coordination.json`并同步catalog；关卡沿用level8 v1字段结构，状态均实时派生，不新增档案字段。本批源码改变生产身份，旧续玩候选资格不沿用。[定向验证及恢复边界](../qa/campaign_coordination_20261116/README.md)。


2026-11-16 江州新增两路追兵的搜索游标、目击状态、目的地和决策计时，六名追兵固定引用槽，恢复profile为`campaign_level2_v2`。新翻译来源`campaign_pursuit.json`同步catalog。组件往返不授完整恢复资格，冻结候选不原地覆盖；[源码/夹具/单路实战边界](../qa/campaign_pursuit_20261116/README.md)。

2026-11-16 M3首批将连环马原有破阵判定抽为`hook_conditions`，单位查看通过关卡可选接口`unit_tactical_hint`读取，不新增存档字段或改profile结构。`campaign_hooks.json`新增9条四语并同步catalog；公共HUD生产输入有变化，不沿用先前冻结候选资格。[来源与限定渲染结果](../qa/campaign_hooks_20261116/README.md)。

2026-11-16 战役深化按[路线图](CAMPAIGN_ROADMAP_20261116.md)推进。祝家庄小队与入口增援状态已登记到Level组件，当前恢复profile为`campaign_level3_v3`；旧战斗候选不猜测迁移，正式战役续玩仍按独立整合验收开放。运行翻译新增`campaign_tactics.json`、`campaign_siege.json`来源并同步catalog。首次开发使用独立工作树；冻结候选不原地覆盖。

本批[小队与侦察专项](../qa/campaign_squad_20261116/README.md)11项定向夹具通过，范围为决策和Level组件；不继承为整关或完整续玩证明。复跑命令及本机引擎锁约定见该记录。

后继[入口增援与营救交接](../qa/campaign_siege_20261116/README.md)在同一场景增加本批风险检查，共16项通过；范围仍为夹具与Level组件，未替代实际行军验收。

连环马阶段任务文案由关卡脚本提供。翻译维护在 `assets/localization/campaign.json`，运行时加载 `assets/localization/catalog.json`。任务提示改动会改变生产来源，须用新的冻结候选验收。

## 本机生成副本自动淘汰（2026-11-02）

旧生成版本已由用户退役，各类只留最新有效载荷及当前必需依赖。Windows换机后运行`powershell.exe -NoProfile -File tools/install_artifact_retention_startup.ps1`，为当前用户安装隐藏的成功记录观察程序；它每60秒检测新完成批次，按验证结果自动清理，不修改冻结生成器或真实存档。清单预览与手动命令见[规则](GENERATED_ARTIFACT_RETENTION.md)，本机状态在`.godot/artifact_retention/`。历史文档的旧完整副本路径可能已退役，不代表目前仍可复验；暂停的开发状态保持。

本机开发目录为 `D:/AI项目/水浒/开发工程`，打开其中 `project.godot`；桌面旧目录仅为历史兼容入口。当前进度见[项目总览](PROJECT_STATUS.md)，开发顺序及完整要求见[开发计划](DEVELOPMENT_PLAN.md)，逐批证据见[开发日志](WORKLOG.md)和[目录索引](DIRECTORY_INDEX.md)。

## 启动与导入

使用 Godot **4.6.3**。在仓库根目录运行 `Play.cmd`；编辑器用 `Play.cmd -Mode editor`，仅导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器先检查导入缓存。

本机引擎路径依次来自 `-GodotPath`、`GODOT_PATH`、被忽略的 `godot.local.txt` 和 PATH。机器路径、SDK凭据及签名配置不写进生产脚本。81份资源导入配置和26份候选工具/预览源码已补交，详见[入库记录](../qa/pending_source_sync_20261020/README.md)；`.import`设置随资源入库，`.godot`缓存不上传。

## 换机与 Git 同步

在自己的 checkout 开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

目标仓库为 `https://github.com/winterzh/Liangshan-Heroes.git`，开发分支为 `codex/sync-20260905-stable`。工作区干净且未分叉时才 `git pull --ff-only origin codex/sync-20260905-stable`；有本地修改或分叉先核对来源，不自动stash、reset或覆盖。

每轮按实际修改做验证，更新WORKLOG及涉及的文档；检查远端、白名单差异、大小及敏感内容后逐文件提交推送，回读远端SHA。玩家存档、Steam登录/缓存、Godot缓存、安装包及无关历史备份不上传。main合并和平台发布按AGENTS.md及当次授权执行。

## 验证与共享引擎

10月30日运输开发按改动做必要专项，[分批来源与实现](TRIBUTE_CART_WHEEL_UNIT_20261018.md)统一导航；每批同一私有场景取得一次实际来源身份，再交给生产新游戏API，减少重复启动和扫描。最新[原车跟随与轮角接力](../qa/cart_follow_relay_20261030/README.md)只改2个运输脚本，95项/12图及来源/进程后验闭合；原地形/临时阻挡、真实接力/旧缓存夹具与首驱动失败分开记录。公孙胜生产配准仍用其本批`build_registration.py`复验，旧构建器对应原快照。完整美术过渡、续玩和整体验收继续，局部代码验证不等于整关或平台发布。

最新[人物标签联用专项](../qa/person_captions_20261030/README.md)只改共享提示层及Unit原标签资格两个脚本。一个原关卡保留20图与两项过严断言失败，窄英文容量/原白胜选择/消息隐藏只补三图，不重复原场景矩阵；同一来源后验重新闭合。拥挤时无空位收起属于当前设计，不将原失败改写为全通过。复验命令及原始驱动见该QA。

最新[提示布局开销对比](../qa/caption_layout_cost_20261030/README.md)只改一个脚本；同场景原Git模块与新代码45组逐字段一致，173项/6图后验闭合。21候选窄窗配对中位17.840→14.090ms、暂停降23.2%，交付车小增94微秒如实记录，不授正常整帧性能。局部几何memo不跨帧，不需恢复字段。

上批[剧情状态标签专项](../qa/story_captions_20261030/README.md)735项/11图闭合：原入场helper与姿态回退夹具分开记录，首次入口失败保留。21候选拥挤布局单组件20.756ms，显示功能通过但布局开销待优化；只按本次变更复验，不授正常性能。

[枣车四向网页请求](../qa/jujube_cart_fourview_20261030/README.md)目前仅固定参考与接图要求，等当次网页人工验证后生成；无新图或生产接入，不运行引擎。新图定稿且人工目检车架/把手/轴点后再冻结，避免边接图边复制来源。

用户已取消全量52／61测试，后续按修改做必要的针对性检查；不自动恢复全量矩阵。现有27个进程39383项通过、取消及未运行范围见[原始收据](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md)。10月28日用户另行授权发行包验收并更新Steam，已完成必要EXE与键鼠入口检查、Build26260970正式上线、四语公告、下载哈希及Steam库启动／退出验收；人工整关仍未计通过。[发布收据与原件](../qa/steam_release_20261028/README.md)。

调用Godot前检查已有进程和共享锁，等通道自然空闲并串行执行，不控制其他聊天的进程。使用与候选精确绑定的冻结、清单及自己的成功导入；默认命名来源检查只授静态结果。原失败存档和证据保留，复验使用逐字新副本，不把旧冻结的通过转授新源码。当前b22及大名府、持久化与各章节边界统一见[当前验证](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/VALIDATION.md)，具体执行命令留在相应QA目录。

## 旧快照和缓存恢复

本轮12个旧战役快照只去掉与最新b22缓存逐字相同的导入文件；复验前按[本轮映射与恢复器](../qa/storage_cleanup_20261027/README.md)补齐。最新b22缓存是恢复保留副本，后续清理不能直接删除。主缓存、各快照源码、独有缓存和原始QA/存档保留。

10月26日第二轮的三个旧快照按[既有映射](../qa/storage_cleanup_20261026_round2/README.md)恢复；上一轮54快照ZIP及9月7日7z已被用户删除，旧收据不代表当前仍有归档载荷。其他旧缓存按各批恢复说明补齐或用绑定Godot版本重新导入，不覆盖不同文件。

## 发布与历史

当前Steam Windows为Build26260970，冻结生产来源47168f00；见[更新记录](STEAM_UPDATE_20261028.md)及[发布指南](STEAM_RELEASE_GUIDE.md)。公开战役续玩未开放，经典固定30波保存/继续保留。源码同步、发行程序验证、平台上线与人工验收各自记录。

整理前的完整设置和历史工具状态保留于[Git提交5837d1bd](https://github.com/winterzh/Liangshan-Heroes/blob/5837d1bdc769f2847888a074f41b5c3d629c5529/docs/SOURCE_SETUP.md)，原10月20日文档归档说明见[历史全文与恢复](../qa/storage_cleanup_20261020/README.md)。专题入口见[文档导航](README.md)、[QA导航](../qa/README.md)及[GitHub约定](GITHUB_REPOSITORY.md)。
