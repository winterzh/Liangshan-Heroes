# 大名府单人安全撤离：保存与继续设计

当前为未应用、未运行的提案与 QA 接入代码。生产分支未开放战役继续入口；不能把本页或静态审查作为自然通关、独立磁盘续玩或奖励资格。

## 要修复的实际状态

原 Level8 允许已经获救的卢俊义或石秀先抵达出口，调用真实 `resolve_story("retreated")` 后标记本人安全事件。另一人仍存活、仍可护送，战斗仍为 FIGHT。当前 Unit 合同只接受城门退却，因而不能保存这一真实中间状态。

提案只放行原 Level 固定 Lu/Shi 引用，并检查获救身份、出口位置、隐藏状态、停止字段及清空的命令/目标。安全者继续属于原 root/active 图，保留 ID、完整缓存和格点数据。Core 在捕获输出与准备分配前，核对同一 Mission/Presentation token 的 Unit、Level、Mission、Root 和 Presentation：安全事件与退却结果双向一致，另一演员存在且存活，selection/caster 清理与原回调一致。两人安全却仍 FIGHT 的记录继续拒绝。

已纠正初稿 `_queue` 位置（在 references）、另一演员缺失或死亡的漏洞、原 `order_stop` 五字段、Root selection/caster 与五组施法队列，以及五记录身份叶类型比较前的守卫。原 membership 与普通角色规则保留。源码、原字节、diff 和审查收据见 `qa/zhu_wounded_20261005/proposals/daming_safe_retreat_v25/`。

## 实际路线与磁盘流程

路由只发普通选择、移动和攻击移动，观察真实任务变化；不直接补事件、写坐标/生命、调用救出或胜利回调、手动 tick、清缓存或加速。先自然办理入牢、放火、夺门及营救，再护送指定一人到出口。路线和战斗存活仍须运行验证。

Lu 先撤离和 Shi 先撤离使用不同私有 profile，各执行四个独立进程：

| 阶段 | 操作与证据 |
| --- | --- |
| A | 首次完整物理帧后的单人安全状态，真实 HELD、Session 保存世代 1、退出 |
| B | 新进程完整安装，逐项核对 packet、22 sections、所有权/绑定、Mission/Root 时钟，正常 120 物理步后保存世代 2 |
| C | 新进程安装世代 2，以普通指令护送另一人；等待实际 durable terminal、冻结 Mission 结果与终结通知，再观察后续帧无新增效果 |
| D | 新进程回读本地终结链和文件 SHA，实际 Session 拒绝旧活动槽，确认没有准备新 Battle/Unit 图 |

runner 保留 v24o 的完整安装和时钟审计方法。v24o/r2历史失败保留；当前s后继已通过A39/B351/C342和最终源码/原生审计。新四进程runner已采纳通过的监听生命周期修复；自身路线/结算及负例仍未原生，不沿用办理半程资格冒充单人撤离资格。

## 必须分别记录的结算边界

`Phase.END` 不是持久终结完成。恢复局先写本地 terminal，再完成 Mission 结果、Campaign 内存结果和 HUD，最后发出 ContinueFlow 完成通知。测试须等待这一真实顺序，不能看到 END 就通过。

当前私有 QA 使用 `CAMPAIGN_QA=1`，而原 `Campaign._save()` 在该模式直接返回、不写 campaign.cfg。此批只能验证真实内存结果及独立本地终结收据；`campaign_persistence_qualified` 始终为 false。正常私有 profile 的战役进度写盘仍需独立测试。`STEAM_DISABLED` 下 run_id 为 0，也不能证明 Steam 统计、成就或奖励一次。

终结后 Root 逻辑时钟仍可能推进，后续帧应比较事件、结果、终结链和相关本地状态，不能强求整世界时钟停止。相同结果或文件不等于回调调用次数。

## 执行门禁与剩余验证

未来 producer 须保留原 JSON 正负例、原 OwnedSlot 故障事务及办理半程 A/B/C 回归。六项候选是四个既有文件替换、helper 与 UID 两个添加；冻结清单仍为 raw5041、distinct5037、完整 runtime5102，含原合格工程明确绑定的 88 份源码伴随元数据。新增运行身份必须重新计算，不能沿用旧 content version。

单人安全负例从 A 实际 world/packet 取证：queue、停止字段、另一演员生命/图归属、selection/caster、身份类型等均要分别测试 source DTO 与 JSON 后 Core 准备，证实拒绝先于分配、原数据未改。直接 DTO 负例不能替代真实对象 capture 负例。缺失夹具、未实现负例或未经审核的 runner 必须前置阻断，不能跳过而判整体通过。

本页不代替其他动态分支、付费生产、船体/运输、自然结局及奖励一次、同版九玩法/发行 EXE、美术/UI/正常时钟性能或 Android 真机门槛。当前真实进度与办公室操作见 [HANDOFF_20261007_OFFICE.md](HANDOFF_20261007_OFFICE.md)。
