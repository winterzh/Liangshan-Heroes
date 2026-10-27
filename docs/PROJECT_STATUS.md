# 当前项目总览

## 本轮全量测试已按用户要求停止

全量负例按用户要求停止：27个进程39383项通过，1个取消、24个未启动；完整52／61未通过。当前无测试进程，自有锁已释放。后续采用针对修改的必要测试。[本批原件](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md)。当前源码未采用生产，公开战役继续仍关闭。

核对日期：2026-10-27（北京时间）。**10月20日Steam Windows更新及当批GitHub主线合并已交付；当前黄泥冈批次和完整开发计划尚未完成。** 人物、兵器、服饰和剧情状态先核对《水浒传》百二十回本，具体配色、动作编排与招式数值明示为游戏设计。

## 当前版本与交付

| 项目 | 当前状态 |
| --- | --- |
| GitHub | [winterzh/Liangshan-Heroes / stable](https://github.com/winterzh/Liangshan-Heroes/tree/codex/sync-20260905-stable)：前批远端回读`9225c727946a41369b07abe49310b78d2ac7fdb0`；本批用户停止全量测试、27个进程通过结果及QA核验器修正按白名单同步，最终SHA以远端回读为准；main未合并 |
| 主线合并 | 48042d84补齐旧stable合并历史，ffa625de补齐交接文档；本页修订随本次文档提交同步，以分支最新提交为准 |
| Steam Windows | default Build **26048429** / Manifest **697009053566575953**，2026-10-20完成发布验收 |
| 冻结生产来源 | 0083b47abac098c5ebd7231e327085c4ba3299cd；后继QA工具和文档提交未改变游戏包 |
| 补丁说明 | [简中、繁中、英文、日文公开公告](https://steamcommunity.com/games/5088120/announcements/detail/669505296465397048) |
| GitHub Releases / Android | 右侧Android 2.0为历史发布；本次未发布Android或创建新的GitHub Release |

已交付：部分人物的原著形象、兵器及技能图标调整，部分待机/行走/攻击/受击/倒地动作，黄泥冈携车与货物显示、阮小七车轮转动，快活林酒肆/摊位/植被，以及窄窗口技能栏和旧控件残留修正。具体人物和采用范围见[更新文档](STEAM_UPDATE_20261019.md)，未把未采用的美术候选算入发布。

本批原生整合219项、包内1169项、来源及包内身份各10项、实际EXE十一场景通过。服务器六文件、全新下载与Steam客户端安装文件核对一致，实际客户端启动与退出已验收。以上属于本批发布证据，不代表完整通关、长期性能或全库美术完成。[发布收据](../qa/steam_release_20261019/README.md)、[最终交付记录](../qa/steam_release_20261019/delivery_complete.json)。

## 仍未完成

- 全库人物、剧情变体、头像、自然动作、场景、特效及多尺寸UI仍需补齐。杨林、公孙胜骑乘、邹润动作和陶宗旺／李云新头像仍有候选未采用。
- 完整战役续玩尚未开放。当前中途保存/退出/继续仅支持经典固定30波据守；旧恢复测试的局部通过与中断记录不能当完整恢复通过。
- 完整流程与竞技平衡、真人试玩、约10分钟性能/内存和Android真机验收仍待完成；Steam启动通过不能代替这些要求。

## 后续顺序

1. [黄泥冈七车十一担](../qa/huangnigang_production_20261020/README.md)实现及自动证据已同步stable `f5325c25`：最终编译包普通路线1206项、九阶段1768项与四语三尺寸24图目检通过。原版EXE仅启动/退出通过；按用户选择暂不恢复键鼠，完整实操待办。第一批整体未完成，main/Steam未更新，公开战役续玩未开放。
2. 完整战役续玩仍在候选阶段。[b22当前验证](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/VALIDATION.md)已有高俅核心416项、持久化19案566项及保存216／设置406／启动恢复387／终局重试737项通过；释放失败154项是明确QA永久故障模型。大名府153316双角色八进程1398项完整通过，完整来源、子进程和锁后验闭合；52负例执行器162116_c86e8835已通过完整准入并进入原生执行，61尚未取得。连环马七进程、高俅造船／败局各三进程、其余章节、云同步与奖励仅一次仍待验；候选未采用或公开开放。
3. 接续剩余人物/剧情变体、自然动作、六车轮转、场景、特效及界面美术。
4. 回归八章与九玩法完整流程，完成真人试玩、性能/内存、切换清理和设备验收。详细条件保留在[开发计划](DEVELOPMENT_PLAN.md)，不由已发布批次替代。

## 从哪里开始

| 需要做什么 | 入口 |
| --- | --- |
| 本机开发 | `D:/AI项目/水浒/开发工程/project.godot` |
| 本机启动 | `D:/AI项目/水浒/开始游戏.cmd` |
| 启动、换机、分支同步 | [源码设置](SOURCE_SETUP.md) |
| 查询每批记录 | [开发日志](WORKLOG.md)、[目录索引](DIRECTORY_INDEX.md)、`qa/` |
| 查看此次更新 | [Steam更新文档](STEAM_UPDATE_20261019.md) |

桌面旧目录保留历史兼容用途，当前开发入口以D盘工程为准。原107个待提交文件已按用户要求全部补交：81份导入设置、26份候选工具/预览源码；候选仍未采用，详见[入库记录](../qa/pending_source_sync_20261020/README.md)。历史源码、原图、玩家数据、失败证据及可恢复归档保持。


## 历史与恢复

旧批次总览已完整归档，[历史全文与恢复说明](../qa/storage_cleanup_20261020/README.md)；历史版本结论不覆盖本页当前状态。

本次负例状态：52负例首轮162116_c86e8835首Lu world（PID65816）在900.655秒超时，exit1、errors空、无最终报告；来源／私有树／子进程／锁后验闭合，整批未通过。后继仅给QA增加准入／runtime／正例／每行开始与完成的单调耗时标准输出，原负例函数／断言逐字保留，全部52进程及900秒期限保持。新8GD加载PID58156／68.429秒／退出0、错误0／72pins通过；重跑164910_c355d10c已启动，完整来源准入中，52与61仍未授。 失败及加载证据分别见[首轮超时原件](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_timeout_20261027_162116/README.md)、[耗时观测版加载原件](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/daming_negative_timing_load_20261027_164702/README.md)。

最新完整执行：耗时观测批164910首Lu world完成177／264行后在900.252秒达到宿主期限，原两个正例完成、无脚本错误，未生成最终报告，整批失败原件保留。依据实测每行约5秒，172552_ea00c9d2新批采用既有CLI的3600秒有限单进程等待，宿主及8GD原字节、完整52进程与所有断言／游戏时钟保持；完整来源准入已通过，首world PID9808正在执行，52及61尚未通过。 详见[177行后超时原件](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_timed_timeout_20261027_164910/README.md)。

最新负例执行：172552完整预算批首Lu world完成255／264行后被关闭：PID9808、838.227秒、exit0xCFFFFFFF、stopped_for为空，无最终GD报告。Windows事件1002精确匹配PID9808，同ReportId的1001为AppHangB1；同步矩阵长期未让出窗口主循环。后继仅在每个完整正例路由／负例行断言及dispose之后等待一次窗口帧，前后检查游戏仍paused、1x／60Hz不变，完整world／component分别须266／364次；原负例函数逐字保持。8GD新加载PID41148／29.719秒／退出0、错误0／72pins通过，175238_2c6e89e9新完整52批正在来源准入，单进程宿主等待仍3600秒。 52及61尚未通过，原件分别见[Windows无响应原件](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_apphang_20261027_172552/README.md)、[暂停态让帧版加载原件](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/evidence/daming_event_pump_load_20261027_175125/README.md)。
