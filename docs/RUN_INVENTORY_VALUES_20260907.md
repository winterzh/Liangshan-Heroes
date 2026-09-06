# 续玩基础：物品栏局部值（2026-09-07）

HeroInventory 局部采集/验证草稿完成 155 条实机检查，尚未接入生产恢复。显式保存六个槽位的顺序、物品/UID/数量，cooldowns、proc_cooldowns、_uid_seq 与 _periodic_acc 五个本地声明值。owner 及其效果和属性关系仍延期。

现有 `snapshot()` 不含周期累计相位，`restore()` 又会触发 `_notify_changed`、属性与 HUD 更新，不能原样拿来作为精确恢复。草稿直接读取五个值，再通过已测 codec 编码、严格验证和真实 JSON 中转，不调用购买、重算、通知或原 restore。解码结果为独立容器，不与活物品栏共享。

当前物品 UID 来源含 owner 的进程内实例 ID；物品转移保留原 UID，也不会提升接收方的 _uid_seq。因此草稿保留原 UID 与序号，不能用新 owner 的实例 ID 重造，不能要求局部序号大于已有物品 UID。全局 UID 分配与历史身份迁移尚未实施；有效 Defs/业务物品与效果来源也未完成整体验证。

## 实际验证

run `20260906T154102953512Z` 使用实际 Godot 4.6.3 PID 42016、exit 0，共 155 条全部通过：10 条逐文件来源摘要、1 条五源保持不变的聚合检查、144 条其余断言（含夹具和 JSON 辅助检查）。QA 使用真实 HeroInventory，owner 是 TestProbe，未创建运行中的 Battle。

验证默认与非默认六槽数据、两类冷却、周期相位、精确 UID、JSON 后类型和值、独立容器、重复 UID/错误字段/超宽冷却图拒绝。采集和验证不额外消耗 RNG，不调用 owner/效果回调；真实已释放的 owner 仍明确延期。完整工程 2,713 份来源和真实玩家文件前后一致，实际 user://、进程退出和锁释放均已核对，严格日志通过。

报告 SHA：`7e1a2095dba83bbd3944743a115e22f1bb7a08baa0570bd8d48435618a679461`。证据见 [QA 摘要](../qa/run_inventory_values_20260906/current_qa_summary.json)，受测原文及精确复现说明见 [冻结合同](../tools/contracts/run_inventory_values_20260906/README.md)。只复制明确指定的 QA report，没有归档其私有 profile。

本结果仅是 capture/validate：没有赋值恢复、owner 绑定、全局 UID、效果图、磁盘调用或跨进程续玩。下一步与 Unit 引用、Battle 局部状态共同接入完整屏障和恢复事务，完整标准 30 波续玩门槛保持。
