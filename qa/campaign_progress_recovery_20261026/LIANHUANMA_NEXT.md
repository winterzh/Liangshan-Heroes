# 连环马自然终局：下一片接线

2026-10-26已准备新的外部自然胜利四进程驱动，见`tests/lianhuanma/README.md`；尚未编译或运行。先完成当前Store原生专项，再由主线程串行验证；不以旧训练专项代替终局验收。三进程草稿未运行，现按真实保存退出行为改为四进程。

1. A点击实际剧情模块和连环马卡出征；当前八幕全部可选，不写入解锁或前章记录。普通训练钩镰手扣36金、24木、预留2人口，训练中通过Viewport Esc、SaveAndExit保存固定槽gen1，由AppLifecycle以continue_saved正常退出。
2. B在新进程点击ContinueBattle，原槽同token恢复；正常完成原20秒训练，观察21秒无重复，再通过实际SaveAndExit及覆盖确认保存原槽gen2，生产再次退出。
3. C再独立点击ContinueBattle恢复gen2，以普通教场诱入/撤步/协同攻击、经营、技能和守两路反攻，要求四目标全部完成和自然异步胜利；核对当前LCv3、Intentv2、ACKv2、完整结果、CFG与离线proof。
4. D独立重启并点击实际菜单继续，验证战役lifecycle gen3已应用历史及旧活动槽明确拒绝、可见错误返回菜单；槽原字节、CFG、奖励和终局记录不再变化。保存、继续和拒绝不以直接Session调用代替Flow UI。
5. 独立[自然失败三进程链](tests/lianhuanma_loss/README.md)已完成代码和静态复核，尚未编译或原生执行：新profile实际保存退出，第二进程菜单继续后以普通移动令宋江遭真实敌军击杀，第三进程菜单继续拒旧槽。不能为名义两进程绕过保存后的生产退出，也不得直接调用lose或写血量。

当前先修[Windows外部PID恢复准入](evidence/process_liveness_api_20261026_225300/README.md)，再以新候选清单重新绑定两条路线。四进程驱动的`static_audit.json`记录提交`47849190`时的初始源码/文档快照；本计划后续状态更新不改其六份执行源码，也不转授f6ef预检给后继候选。

复用来源：`tools/lianhuanma_rts_test.gd`的普通经济/付费建造/训练及守路反攻策略；本批`tests/training.gd`的实际训练、费用、Codec；`tests/huang/`的终局读取；`handoff_candidate/tests/classic/driver.gd`的可见按钮、Viewport Esc和生产保存退出观察。新驱动与runner均独立，不修改已冻结worker。旧RTS入口使用4倍速、CAMPAIGN_QA=1并跳过教场，不直接运行它作本轮验收。`tools/level4_world_restore_qa.gd`和`lianhuanma_drill_test.gd`含状态/伤害夹具，也不算自然路线。

当前严格契约：level4 context、campaign_level4_v1、contract2，实际目标为lhm_training/hooks/han/hu。胜利核对真实lhm_victory、十二骑与大营、宋江及原中军存活、ContinueFlow完成、HUD出现；连环马不存在黄泥冈的level.victory字段。保留完整goals/missed，不把Intent六字段投影冒充完整结算或自动补齐未完成可选目标。胜利新profile解锁值为5；失败ACK必须CAMPAIGN_PROGRESS_NOT_REQUIRED、persisted=false、空CFG SHA且不新增通关记录。离线只授uncredited proof及不重放资格，不授真实SDK/credited账本资格。

旧61阶段另属大名府Lu/Shi双角色ABCD和52负例，不能称连环马61阶段。`tools/run_durable_campaign_chain_v16.py`仍固定旧v2 lifecycle/v1 Intent/v1 ACK，其baseline现不存在；原收据仅3阶段成功，后因美术优先停止，host_exit记录退出1。后续需按新契约重新准备，不直接重跑或转授旧结果。
