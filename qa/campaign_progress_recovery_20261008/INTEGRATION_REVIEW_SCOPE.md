## 2026-10-08：当前可证明范围与后继接口

R12＋白胜普通南侧路线的110来源三组已实际complete/zeroerrors：normal fresh/restart、真gen2中断/restart、真CFG确认前ACK中断/restart。仅此范围，final roles/19/52/SDK/UI/perf/devices仍未资格。完整consumer R2有独立静态复核，100原unique labels保留96、4个旧QA-suppression标签在新schema改严格CFG确认，原v1 validator保持，不用旧绿转移资格。完整producer及component/live后继未就绪。

## 当前后继R12范围（2026-10-08）

用户已授权恢复接入与全链后继的独立审查。最新源为`integrated_v4_r12/scripts/`十四脚本，封存`SOURCE_AUDIT_V14.json`；R9/R10/R11及既有spec/收据保留。R11使用实际launch分类上下文创建屏障，测试只读检查而不额外configure，并拒绝空屏障保存/安全disconnect。最终完整执行器尚未就绪；任何R12运行须新producer/spec与独立准入，旧R9 scoped批准不转移。

# 终局恢复接入候选：独立源码审查范围

现有用户授权覆盖旧完整续玩执行器和普通路线来源绑定。本候选涉及新的终局恢复模型、普通 fresh/续玩调用、启动扫描、设置/云写入门禁和玩家错误界面；将其作为完整恢复验收入口前，须完成新的独立源码/API/来源审查。此文件说明项目交接的执行门禁，不把源码或编译通过视为全链资格。

当前候选为 `integrated_v4_r2/scripts/` 的十四个固定脚本。首轮 `integrated_v4/` 使用了与 Godot 内置类型重名的 `Projection` 标识，实际导入拒绝；原候选、原私有工程、失败日志和收据保留。R2 只将其改为 `ProgressProjection`。

真实已验证范围：

- `integration_parse_7cb75b98`：官方 Godot 4.6.3 导入 PID23272、普通菜单180帧 PID40996，两者终态0、零引擎错误，锁释放。
- `integration_startup_8f93ba0c`：导入 PID42372、实际启动/设置探针 PID45576，终态0、零引擎错误、16检查全过。真实根 ContinueFlow 返回 `startup_checked=true`、Gate 开启、无战斗/运行日志；调用正常延后 `Campaign.save_prefs()` 后 ConfigFile fresh-load 读回所选设置，重复保存实际 SHA 不变。

以上只覆盖空档案启动和正常偏好持久化；不覆盖 pending 故障界面、gen2→CFG→gen3 确认/重启、自然战役终局、两角色跨进程续玩、Steam 结算/奖励、最终导出或性能。

源码审查需核对：

1. 真实当前 Battle、Mission、安装身份、owner/context/token 冻结与重复核验；有 Steam 资格的终局与本机真实 Steam run token 关联，本地日志不借此生成 Steam 结算授权。
2. 生命周期严格三代及不可变同局意图；恢复只写进度，不调用战斗工厂、Mission、指标、展示或 SDK。
3. 固定目录下最多256个合法 token 的只读扫描，原 envelope/链/待写/实际 PID 核验。已确认历史记录仅作数据核验，待确认数据需匹配当前安装和档案。
4. CFG 原文/语义/CAS、固定受控备份与空目标替换、保留未确认提案、非 physics 写盘和原对象重试。纯投影/预写拒绝只能释放自有未暂存锁。
5. Campaign/SteamCloud 的所有生产写入门禁、普通设置快照/延后保存/保留错误重试、内存更新和 cloud dirty 的先后顺序；账号变化不得混档。
6. ContinueFlow 的正常 fresh/续玩终局、异步安装、startup 错误与重试界面；实际完成只能消费一次，终局日志确认前不得展示、指标或结算。旧 credited 槽在本地 terminal 后、Core 分配前拒绝。
7. 经典 v1 原脚本/存储保持，后继完整执行器仍须原19持久化故障、双角色自然ABCD及52负例，不能将组件或正常设置探针补成完整资格。

审查员只做固定候选与执行器的源码/API/来源核对，不启动原生进程、不改生产或验证器、不控制其它聊天。任何后继变更都要以新来源快照与具体审查记录准入；真实资格仍以实际完整终态为准。
