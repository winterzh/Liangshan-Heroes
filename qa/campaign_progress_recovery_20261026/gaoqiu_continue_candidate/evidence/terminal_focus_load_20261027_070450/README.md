# 高俅精确点杀策略：原生加载检查

保存 `20261027_070450_523a5247` 的原始收据、日志、loader、runner 和五份运行时 worker。实际 PID **28052**，89.1 秒，exit0、errors=[]、complete=true；原收据的 owner_confirmed、lane_idle、lock_released 均为 true。

本次固定 policy `382aa213adeccf3f24b388a38340da7f0c2c9aa2e358aba6aea7febcd501597b`、driver `30b32ec83fd9df0580aee05116599ba78b25def2175eae008d33575363e0281d`、sources `38e182c8825c813962bffefd78c2868a3a94515aa99acb0be0ebad0679b1ac5d`。策略以普通 G 切避战，再向已派发、可见原波次单位发精确 A 点目标命令；第三波后通过普通 G 恢复进攻姿态。driver 只增加两处有界只读残兵观察，原波次时间、living-at-dispatch、清场截止、两次保存和四进程门槛保持。

正常 autoload 后，SceneTree deferred loader 仅对 driver 与 bootstrap 做 `load/can_instantiate`，没有 new worker、添加 Battle 或调用玩法 run。**本包只授这些脚本在该环境的原生加载资格，不授点杀策略可达、清场、三波战斗或四进程胜利通过。** 原 runtime_qualified=false / full_source_qualified=false 保留；公开入口、真人键鼠、SDK、EXE及发布资格均未取得。

`manifest.json.files` 记录本包逐字原件及说明文件。31 项实际 receipt pins 中9项由本包解析，其余22项逐 SHA、字节数与原件核对后映射到已提交的 [guard 加载归档](../terminal_guard_load_20261027_063412/manifest.json)及其引用的 [早期加载归档](../terminal_load_check_20261027_061546/manifest.json)，两份 manifest SHA 均固定。`source_map.json` 另列八工具的完整来源与 EXE hash-only 引用，`verification.json` 记录有界核验。

runner 取 root 在原 run 内保留的逐字副本，SHA 与该收据一致；它在本包不是新的运行入口。没有复制工程、缓存、EXE、profile、业务载荷，也没有启动引擎或重新完整工程哈希。旧失败、旧加载批及当前正在运行的完整胜利批互相独立，不混授资格。
