# 官方选型与祝家庄工厂组件 QA

最终批次 [`20260909_071356_6defc6ec`](20260909_071356_6defc6ec/receipt.json)通过341项：选型与私有运行定义121项，跨进程Level恢复220项。两个行为进程PID1292/15316读写同一SHA的合成fixture，覆盖scout/contest/siege三阶段、每阶段31字段、单位引用别名、60个身份字段错误类型拒绝及Globals不变。四步按预期退出，引擎错误0，8个阶段边界核对通过，真实玩家目录聚合摘要不变，结束后无引擎残留且锁已释放。

主任务[独立回读](review_071356_6defc6ec.json)重新验证26项归档、两份报告的PID/检查数，以及2956份当前和私有来源，共5912次SHA检查。fixture使用测试内容版本与当前引擎SHA，不能证明真实Steam身份或完整战役续玩。

共享LevelState的坏档身份类型检查修复后，另跑八关组件回归 [`071530_82d33474`](../campaign_level_state_20260908/20260909_071530_82d33474/receipt.json)205项通过。主任务[回读](review_level_state_071530_82d33474.json)确认53项归档、2954份双位置来源和5908次SHA检查；旧运行器只记录单组件报告，不把它表述为双进程验收。

保留失败批：`071004_e4ee6383`在导入时发现Graph直接读取未类型化preload类的resource_path导致解析失败；`071222_4da3dcdc`通过导入后，在场景加载时发现工厂常量Environment与引擎原生类同名。两处均已修复，各批原始日志、来源和收据保留，不累计为通过项。

运行：`py -3.14 -X utf8 -B tools/run_official_restore_profile_qa.py --run`。新D盘私有profile、冻结副本、禁用Steam、共享引擎锁；不加`--run`仅预检。两新模块尚未接入WorldCore/Session，玩家入口不变。
