# 保存与重试界面：当前验证状态

2026-10-27。修订后新profile三进程已全部通过：PID37500／75876／73876，30／137／49项，共216项，均退出0。complete与three_process_flow_qualified为true；完整b22、自身cold、来源后验、自有句柄与子进程收尾、锁释放均通过。此页维护实际资格，封定README／cases／sources不承接运行状态。

首轮`20261027_112148_90dff64d`第一进程PID3428真实保存退出30项通过。第二进程PID32836完成独立恢复、覆盖取消、正常推进及再次确认，实际追加gen2并到达原release:219；宿主却把同一初始保存调用栈的再次暂停当作RetrySave链，停止并终止自己的子进程。第二进程无最终报告，第三进程未启动；原句柄、子进程与锁均已正确收尾，来源后验通过。[失败原件](../../evidence/ui_save_retry_breakpoint_failure_20261027_112148/README.md)完整保留，不据此判游戏重试成功或失败。

最小修正只为每次保存／重试独立设断点：初次暂停disable→continue且保留原文件句柄；worker实际观察LOCK_RELEASE及同对象／HELD边界后发布新`arm_retry_release`，宿主核原owner/CAS/文件再rearm并ACK，随后才点击真实RetrySave。两次真实失败、同Session／Store／proposal和最终只增gen2条件不减。18命名输入及11份Python AST通过；宿主SHA`523161e852df363b8f40f18576e0f0a0246e0c40df0ad50cb36b60a2d282c0bf`，sources SHA`7069f813087e3735243c326deff79817553352103ecf2a172ca1d7f2ed51468f`。

[修订四GD加载](../../evidence/ui_save_retry_rearm_load_20261027_114727/README.md)实际PID74964，39.481秒，退出0／错误0，43pins、进程和自有锁后验通过；未实例化worker。旧四GD加载另见[历史原件](../../evidence/ui_save_retry_load_20261027_102958/README.md)。新三进程批`20261027_115057_81aa46a4`以固定b22完整来源／自己的首次cold重新准入，实际验证gen1保存、取消后继续推进、两次真实LOCK_RELEASE失败、解除占用后同Session／Store／proposal只写gen2，以及READ_OPEN拒绝／CloseError／解除后恢复gen2。未从失败profile续跑。

本片保持source-private范围，不授公开入口、OS键鼠、SDK、自然完整战役、完整30波、云服务、19故障或61阶段资格。


[216项完整原件](../../evidence/ui_save_retry_complete_20261027_115057/README.md)：31文件，864运行pins；修订5个输入按此次run冻结原字节保存，历史相同对象指向固定0217595e提交，不将未提交修订冒充旧Git来源。业务profile、存档、CFG及EXE不随证据入库。
