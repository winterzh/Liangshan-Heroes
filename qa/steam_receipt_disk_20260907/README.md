# Steam 回执文件事务与假 SDK 原生验证

这是隔离文件事务候选，**未接入生产 SteamService，未调用真实 SDK 或账号**。
执行来源为 `f3da82f7452a2164c704c34a97c6b2696e99b9c3`；A2 freeze 为
`0b00adc68bf1760c683b008e62aa24116a3133154d07bc1d30fe0ace6f714661`。

原始交接为 `NATIVE_HANDOFF.md`（若查看原始归档位置，请按 SOURCE_PINS 的
original_path 检索）。原生 receipt SHA 为
`f159303ab28e2e2a7306c4ce3ecb28da422b93ca2c7be33d1fd7539b4127c960`。

## 结果

69 次真实 Godot 子进程启动：26 次由父进程核对断点/PID 后强制终止，
43 次正常退出0。26个崩溃与新进程恢复窗口、10类坏账本、2类部分SDK失败
均通过；293条原生断言包含环境检查，其中正常宿主合同33条。
源码、HEAD、候选、玩家目录、进程退出和共享锁守护通过。

写者使用 mkdir 锁与修订号/CAS，在不让出执行权的临界区完成 prepare、
pending写入/flush/close/回读、新记录rename/回读、模型commit，再允许假SDK。
第一条SDK缓存写入之前必须已经持久记录 uncertain；runner 又独立核对
每条SDK日志的原始账本SHA、修订、token和实际目标，恢复未新增SDK事件。
半写文件和坏账本保留原字节并阻断，未回退旧账本继续发送。

## 已发现并修复的异步反例

A1 在 A 成功后发送 B，再收到迟到的 A 成功时会误清 B；独立审查发现后保留
A1为未运行失效候选。A2采用全进程只发送一次的保守限制，成功后不重置，
换Host或session不能绕过，本地新进度仍可持久化。正常合同覆盖完整反例。

Steam 的 UserStatsStored_t 只提供游戏ID与结果，没有应用批次token；这里
没有将测试token冒充真实回调字段。[官方回调结构](https://partner.steamgames.com/doc/api/ISteamUserStats#UserStatsStored_t)

## 限制与接续

每进程只能发送一次是本夹具的已测限制，不是已完成的正式持续同步方案。
权威读取输入为synthetic，exact-match门只证明测试发布顺序。真实服务端基线
与本地未确认增量须另行设计，不能把服务端低值直接覆盖到新本地进度。
真实回调归属、SDK缓存退出提交、账号切换、双设备写入、断电、恢复进程再崩溃、
日志长期压缩及Battle累计均未验收。2048条记录上限和全链读取成本也未优化。

`SOURCE_PINS.json` 是实际归档映射，包含每文件大小和SHA；原子代理白名单
另存 `original_archive_inventory.json`。`.gd.txt` 保留原GD字节，在匹配源码的
独立scratchpad按 original_path 恢复名字后复现，不从QA直接执行。
固定SteamID为测试常量，没有实时账号数据；排除了私有profile、Godot缓存、
导入生成物和重复工程源码。A1/A2原freeze和README保留冻结时原文，以本说明
及原始运行receipt判定最终状态。
