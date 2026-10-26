# 当前生产重基候选：战役事务切片

状态：14文件已冻结导入，并在 `20261026_181919_3fc4b901` 通过连环马活动期三进程135项检查、黄泥冈正常离线终局及独立进程旧槽拒绝1364项；正式源码未采用。完整故障资格尚未取得，详见[本批当前证据](../README.md)。初始12文件静态切片与后续Session/Cloud两文件一并冻结，不能将54项静态审查或135项活动期结果转授其它范围。

完整来源见 [source_manifest_campaign_slice.json](source_manifest_campaign_slice.json)：逐文件列出 R12 原始路径/SHA、当前生产底本 SHA、候选 SHA 和修改点；3份事务接线文件还记录了基于当前底本应用的 R12 段落位置。没有把旧 Battle 整份复制覆盖当前。

## 实现

- 8个组件来自 `integrated_v4_r12/scripts/`；只将 Intent 的 `level1` contract 从2改为3，四项演义目标 ID 保持。其余组件逻辑保留，统一 LF 文本换行。除黄泥冈外七章 contract 和目标 ID 已对照当前章节，包括快活林 short 继承目标。
- Battle 只产生4个 diff 段（三个逻辑改动）：barrier 延后到真实 context 分类后配置；所有官方战役终局转交 Coordinator；消费一次性 completion 并比对6个持久结果字段。完整冻结 Mission 快照、`goals`、多语 renderer、Esc、动作和场景效果均保留，原直接 `on_level_won` 进度写入被事务路径替代。
- ContinueFlow 合入启动恢复、异步战役 restore、终局/设置错误重试及单次 claim；保留原 `_player_context_supported` 和非私有 save/restore 两个 classic30闸。公开战役保存/继续仍关闭，已有隔离 QA 路径可测。
- Campaign 偏好/进度/云写入共享事务与 gate，失败保留 owned writer；Menu 待启动恢复确认后才开局。

[static_audit_campaign_slice.json](static_audit_campaign_slice.json) 的54项检查确认：来源及当前生产 SHA 未变、候选 SHA 固定、Battle 变更范围及5个保留函数逐字一致、完整 HUD 参数保留、公开入口条件未放宽、八章版本正确。此检查不是 GDScript 编译或运行测试。

## 接线边界

新事务驱动应使用 `user://continue/v1` 固定槽根和全新隔离 profile；不能拿旧 `user://lian_train/v1` 活动期 token 转作 gen2/gen3 启动恢复证据。旧 uncredited 战役档仍为 classic-context lifecycle，候选明确拒绝 `LEGACY_CAMPAIGN_CONTEXT_UNBOUND`；不清 receipt、不换槽掩盖迁移。

黄泥冈仍依赖当前 `campaign_level1_v2`、`level1_unit_state_v2`、七原车十一担、死亡接力及 short contract3；这些现行生产依赖不从旧候选覆盖。自然有伤亡的核心胜利与可选演义目标要分别验收。

下一次原生验证先做新冻结导入/普通启动、经典30波保存恢复和连环马自然训练同token再存；再做真实终局gen1→gen2→CFG→gen3、重启恢复、旧槽拒绝与真实失败UI重试。`CAMPAIGN_QA` 必须为空；其为1时 CFG 持久写入明确拒绝。旧R12 baseline/bridge和历史审查不能转授。

## 已知未补齐项

1. **Steam可漏结算窗口。** 候选先提交本地gen3，之后才由 `_complete_end` 调 `SteamService.settle`，后者内存排队再延迟持久化。两者之间崩溃会让启动扫描把gen3视作历史，但Steam账本可能仍active。候选只能承诺本地进度幂等/单次live准入，不能承诺平台奖励不漏且不重。
2. **精确补齐方向。** 在gen2冻结真实 credited/uncredited 状态；credited应绑定owner/token/context/击杀高水位，将同token Steam本地账本终局落盘回读置于gen3前。gen2启动恢复只处理该数据事务，不重播Battle/metrics/UI；须区别正确终局与账号纠正墓碑。中断点至少覆盖gen2后、账本完成gen3前、gen3后展示前。当前候选尚未实施该协议或修改Steam相关文件。
3. **启动扫描上限。** `MAX_RUNS=256` 将已applied历史目录也计数，目前没有配套退役流程；第257个合法journal会阻断下次启动。保留明确后续缺口，不声明无限长期运行。
4. **“原子”范围。** CFG候选只针对正常进程中断、owned backup/candidate/回读恢复；不承诺断电原子性或不合作外部writer的原子CAS。

具体合并地图与验收切口另见 [integration_map.md](../../lianhuanma_resume_20261026/integration_map.md)。
