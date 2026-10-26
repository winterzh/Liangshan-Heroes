# 战役进度恢复：当前生产重基候选

最新后继为[继续入口三脚本修复](continue_binding_candidate/VALIDATION.md)：d7f2258b已独立导入并通过本地绑定模型，连环马真实入口完整重跑中。下方14/20/e97a各批继续按各自来源和范围阅读，不转授后继。

2026-10-26。正式 `scripts/` 未采用本候选，公开战役继续入口仍关闭。`rebased_candidate/` 的14文件已冻结、导入，并通过连环马三个独立进程的135项活动期检查，以及黄泥冈自然终局/重启旧槽拒绝1364项。下一版 `handoff_candidate/` 已独立导入并完成模型与尾账/纠正逻辑回归，真实文件专项13阶段已符合预期（含两类拒绝诊断），同版黄泥冈自然终局/重启拒旧槽1386项通过；不能沿用14文件的通过结果。

| 切片 | 当前证据 |
| --- | --- |
| 14文件重基与导入 | 保留当前黄泥冈七车v2、contract3、完整Mission结算目标、现有Esc与classic30公开门槛；冻结 `20261026_180935_fa774d1f` 导入成功。 |
| 连环马普通训练 | `20261026_181919_3fc4b901`，35/57/43共135项通过。训练中保存→独立进程恢复成军→同token同槽再存→第三进程21秒防重复；正常付费一次、训练20秒、唯一新兵56。 |
| 真实战役生命周期 | 固定 `user://continue/v1`，槽代际1→2→2；lifecycle是`local_campaign_continue_lifecycle_v2`、实际level4 context和本机内容/引擎/离线owner，保持active gen1。 |
| 黄泥冈自然终局 | `20261026_184609_83566d26` 两进程1327/37共1364项通过：普通酒计七车终局、同token gen1→gen2→CFG→gen3、四语完整结算、重启拒绝终态旧槽，CFG/记录/奖励不再增长。 |
| 下一版可靠奖励交接 | 20文件新冻结`20261026_194542_27c8aea9`已导入，99项模型通过；修复JSON重启回读、Session尾账、纠正后自动重解锁。原811源75项模型及135项训练不转授新版；新源实际I/O的9案例/13阶段/178项断言符合预期（包括两类拒绝诊断），同版黄泥冈自然终局/重启拒旧槽1386项通过；尚无SDK、完整战役或生产资格。 |

训练结果只覆盖连环马活动期；黄泥冈覆盖离线正常终局和重启拒绝，**不等于全连环马路线、终局故障恢复、Steam账号/SDK、完整61阶段、公开入口或原版EXE键鼠验收通过**。原版键鼠按用户选择暂停，屏幕外GL测试没有调用桌面键鼠。

- [训练原始收据与135项汇总](evidence/training_20261026_181919/summary.json)、[逐文件原始SHA](evidence/training_20261026_181919/manifest.json)。
- [终局成功汇总](evidence/terminal_success_20261026_184609/summary.json)、[原始收据索引](evidence/terminal_success_20261026_184609/manifest.json)。
- [首轮终局失败](evidence/terminal_first_20261026_183614/summary.json)，完整旧驱动和日志保留，不覆盖失败结果。后继驱动只把固定两帧滚动等待改为有界的完整布局稳定等待，原可见条件和真实viewport点击保持；20次布局观测均记录原始矩形和等待耗时。
- [重基实现范围](rebased_candidate/README_campaign_slice.md)、[14文件清单](rebased_candidate/manifest.json)。
- [奖励交接设计](STEAM_HANDOFF_DESIGN.md)、[下一候选说明](handoff_candidate/README.md)。
- [经典30波六进程回归](handoff_candidate/tests/classic/README.md)：首批QA身份JSON类型失败原件保留；外部驱动使用生产无损Codec修正后，新profile从第一阶段重新运行，新批六阶段443项已全部通过，见[完整终态收据](evidence/handoff_classic_20261026_205941/summary.json)；该结果只属于23c源码。
- [唯一目录释放后继候选](store_protocol_candidate/README.md)：19文件保持23c原字节，只替换Steam Store。针对正常释放中断和首次重试CAS冲突，另建独立模型、23进程原生I/O及延迟写入者交错验证；尚无生产采用或完整恢复资格，运行状态见[独立记录](store_protocol_candidate/VALIDATION.md)。
- [连环马下一片接线](LIANHUANMA_NEXT.md)：新增[四进程自然胜利驱动](tests/lianhuanma/README.md)，覆盖两次实际保存退出、两次独立菜单继续、四目标完整自然胜利及终局旧槽拒绝。原f6ef预检仅为历史准备；宿主已显式绑定e97a的23脚本与helper，首批真实菜单继续已发现章节参数遗漏，保存53项通过，恢复阶段2项失败，后两阶段未执行；[失败原件](evidence/lianhuanma_victory_failed_20261027_011539/README.md)保留，修复后必须另冻完整重跑。失败路线按实际保存退出语义另用三进程验证；旧文档中的两进程设想不能绕过Flow。
- [自然失败三进程驱动](tests/lianhuanma_loss/README.md)现已准备，实际保存退出→独立恢复后普通命令令宋江自然阵亡→独立菜单拒旧槽。Python AST/帮助入口及只读复核通过，尚未编译或原生运行；完整四目标保留真实done/missed/pending分类，失败不会擅自全改missed。
- [外部进程存活查询旧缺陷](evidence/process_liveness_api_20261026_225300/README.md)已由后继三态准入候选处理，同一 e97a 源新增[23 进程／370 项故障检查](evidence/liveness_io_v2_20261027_003556/README.md)和[4 进程／129 项交错检查](evidence/liveness_delayed_v2_20261027_010849/README.md)通过。半 pending 安全拒绝，原19类、61阶段、实际失败UI、v2超时隔离与SDK仍未闭合；胜败宿主已显式绑定23脚本＋helper，下一步连环马自然路线。
- 独立[三态查询组件](process_liveness_candidate/README.md)已有13例实际helper、22项报告模型、49项Godot组件及独立19项超时证据。f6ef新批已[实际复现活写者误清理](evidence/live_owner_baseline_20261026_234140/README.md)；基础Store、Steam Store与进程级manager的[恢复桥接候选](process_liveness_integration_candidate/README.md)另行验证，不能据独立组件通过称存档修复完成。
- 后继桥接最小组件22项模型/60项检查、7次真实查询通过；修复退出生命周期后另冻为23脚本e97a源，导入退出0。新源[双进程活写者保护](evidence/live_owner_fixed_20261027_001429/README.md)45项通过：B明确WRITER_ALIVE且业务目录零变更，A正常提交、B同对象重开且无重复奖励。此项不转授全部死亡恢复、活claimant、超时隔离、连环马或完整战役资格。

## 运行与来源

本次测试内容身份为 `source-v1:db6bc7886752137a212a74537751655036ce3885e07aaef11f5920b8e2d6c14c`。宿主真实Godot4.6.3、实际GL、60Hz和正常倍率；`STEAM_DISABLED=1`，`CAMPAIGN_QA`为空，让CFG在全新隔离profile真实写入。原始训练前后源码、驱动、引擎身份均通过，共享锁已释放。profile存档、缓存、截图和二进制留本机；Git保存报告、来源清单与实现。

```powershell
python qa/campaign_progress_recovery_20261026/prepare_candidate.py
python qa/huangnigang_production_20261020/run_batch.py import --run <新冻结根> --wait-lane 1800
python qa/campaign_progress_recovery_20261026/run_training.py --base-run <同一已导入冻结根> --timeout 360 --wait-lane 1800
python qa/campaign_progress_recovery_20261026/run_terminal.py --base-run <同一已导入冻结根> --timeout 900 --wait-lane 1800
```

工具检查实际base identity和逐文件候选清单。测试驱动从工程外冻结，不向canonical输入注入QA；失败停止后继阶段并保留原日志。连环马跨进程对比沿用生产无损Codec，不放宽值精度、费用、正常计时或唯一成军断言。

当前14文件版本仍有已知限制：Steam本地奖励交接晚于gen3、有漏记窗口；启动扫描256个历史journal上限；CFG恢复不证明断电原子性。新交接草稿修第一项，旧v2缺信用信息的pending拒绝并保留，不能猜测补奖。其它缺口与真实故障/账号/SDK验收仍需逐项推进。
