# 最终恢复执行器接入约束

2026-10-08 独立审查员只读核查了旧 full producer、v31 路线与 R9 接入。旧 full 没有最终恢复资格，不能把旧结果或两个来源审查简单相加。

当前新增 `tools/run_campaign_natural_terminal_recovery.py` / `campaign_natural_terminal_probe.gd` 只实现普通黄泥冈自然终局与三组跨进程检查。完整双角色、19故障、52负例、实际Steam奖励仍是最终执行器的必需项。

最终接入必须满足：

1. 绑定实际 R9 六项替换、八项新增及选用的 Core/Contract 完整组合。R9 的原 80 引用核查绑定正式 Core/Contract；旧私有候选的两项补丁是不同字节，须明确重审组合。保留完整运行输入、引擎/native 与冷导入来源闭合。
2. 普通终局、设置和恢复使用空 `CAMPAIGN_QA`，四个用户目录隔离，固定 `user://continue/v1`。旧 custom root 不能搬移成新启动证据；每次手工 Scene/Factory 操作前等待真实 startup/IDLE/Gate 开放。
3. 原 JSON533/OwnedSlot76 可原样作为边界子回归重跑。原半程 ABC39/351/342 及完整 Session 安装断言必须做 v2 构造器后继；不删标签，不沿用 v1 构造器。存档槽 A1→B2 不变，独立生命周期为 active1→terminal/pending2→applied3。
4. 自然 C 保留实际 Mission 冻结、一次通知、确认后 HUD、各报告一次、普通帧不重放、旧槽字节不变等断言，增加实际 CFG fresh-load 和 gen3 确认。D 重新载入已持久化进度，无 Battle/Mission/SDK/指标/展示重放；旧槽必须在 Core/Unit/graph 分配前拒绝。
5. 实际 A 必须成功退出后才冻结。后续仅复制关闭的自有数据树；同时绑定同一 token 的 v2 active journal、源/engine/content/PID/nonce 与完整 typed packet，不导入历史结果或缓存。
6. world132×两路=264/角色可保留纯 DTO 语义和精确 expected_code。component181×两路=362/角色须改正常 root、v2 五参数只读 head/scope；保持全树不变、精确拒绝层及无分配。live24/角色须使用新的固定继承 base，保留全部 mutations、类型/IEEE、HELD 无 tick/no nodes、真实 Core capture 和五项 caster 检查。
7. 聚合仍要求两角色八个 ABC(D) 进程、52个负例阶段，三类矩阵数不变，source/PID/nonce/ERROR/evidence 检查不降。旧 consumer 硬要求 `campaign_persistence=false`，必须建立更严格的 durable consumer，不能豁免旧断言。
8. 原19故障在最终源上、真实 pending 界面/同对象重试、prefs/cloud 写入排他与账号/来源漂移拒绝、credited token 与奖励只一次均需新实际案例。当前三组自然终局检查不承担这些资格。

本文件记录接入核查和未完成范围，不是完整独立准入或原生通过收据。
