# 连环马自然终局：下一片接线

2026-10-26只读核对，尚未实现新的完整驱动。先完成当前Store原生专项，再做三进程自然胜利链及独立两进程自然失败链；不以旧训练专项代替终局验收。

1. A从真实菜单启动连环马，普通付费训练钩镰手：36金、24木、2人口预留；训练中保存固定槽并退出。
2. B恢复原槽、同token，正常完成20秒训练并观察21秒无重复，再保存槽代际2。以普通建造、训练、技能、攻击命令完成守两路反攻，等待真实异步终局。教场若纳入范围，需新增正常调度，不能摆位/冻结敌军/注入伤害。
3. C独立重启，验证战役lifecycle gen3及旧活动槽明确拒绝，槽原字节、CFG、奖励和终局记录不再变化。
4. 另一个新profile先保存活动槽，再以普通移动令宋江遭真实敌军击杀；第二进程拒绝旧槽。不得直接调用lose或写血量。

可复用来源：`tools/lianhuanma_rts_test.gd`的普通经济/付费建造/训练及守路反攻策略；本批`tests/training.gd`的实际训练、费用、Codec和同槽交接；`tests/huang/base.gd`与`reject_terminal.gd`的终局事务核对。需要新外部driver和runner，不能修改已冻结worker。旧RTS入口使用4倍速、CAMPAIGN_QA=1并跳过教场，不直接运行它作本轮验收。`tools/level4_world_restore_qa.gd`和`lianhuanma_drill_test.gd`含状态/伤害夹具，也不算自然路线。

当前严格契约：level4 context、campaign_level4_v1、contract2，实际目标为lhm_training/hooks/han/hu。胜利核对真实lhm_victory、十二骑与大营、宋江及原中军存活、ContinueFlow完成、HUD出现；连环马不存在黄泥冈的level.victory字段。保留完整goals/missed，不把Intent六字段投影冒充完整结算或自动补齐未完成可选目标。胜利新profile解锁值为5；失败ACK必须CAMPAIGN_PROGRESS_NOT_REQUIRED、persisted=false、空CFG SHA且不新增通关记录。离线只授uncredited proof及不重放资格，不授真实SDK/credited账本资格。

旧61阶段另属大名府Lu/Shi双角色ABCD和52负例，不能称连环马61阶段。`tools/run_durable_campaign_chain_v16.py`仍固定旧v2 lifecycle/v1 Intent/v1 ACK，其baseline现不存在；原收据仅3阶段成功，后因美术优先停止，host_exit记录退出1。后续需按新契约重新准备，不直接重跑或转授旧结果。
