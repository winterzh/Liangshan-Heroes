# 高俅守阵策略：原生加载检查

保存 `20261027_063412_447d56e0` 的原始收据、日志、loader、runner 与五份运行时 worker。PID **8832**，40.313 秒，exit0、errors=[]、complete=true；原收据的 owner_confirmed、lane_idle、lock_released 均为 true。

新策略 `policy.gd` SHA `3a7c68fe36682970fc5d870905aa82a5481e13b0671be8407f2e18e1f180ae8a`，来源清单 SHA `06c7de55458b55a865d35977ae5770dd3991a2bbd83985cbf787df85507e0ee6`。它把第三波派发前的操作改为普通移动到内院/内港后真实 H 据守；原 140/330/540 秒、living-at-dispatch、两次保存与四进程门槛未改。

本次只在正常 autoload 环境后执行 SceneTree deferred `load/can_instantiate`。loader 未 new worker、未添加 Battle、未调用玩法 driver.run。**只授这些脚本在此环境的加载资格，不授守阵策略、三波交战、保存续玩或核心胜利通过。** 原 runtime_qualified=false / full_source_qualified=false 保留；也不授公开入口、真人键鼠、SDK、EXE或发布资格。

`manifest.json.files` 列本包原字节及说明记录。31 项实际 receipt pins 中8项由本包载荷解析，另外23项逐 SHA/字节数映射到已提交的 [前一加载归档](../terminal_load_check_20261027_061546/manifest.json)，未复制其余旧链。`source_map.json` 另逐项列当前八工具的来源，`verification.json` 记录本次有界核验；所有本地原件复制后逐字核对，所有命名来源结束时再次 SHA 一致。前一 manifest 自身 SHA 也固定。

runner 使用 root 随后保留到原 run 的逐字副本，SHA 与原 receipt 相符；归档位置不构成新的可执行入口。没有复制工程、缓存、EXE、private profile 或业务存档。归档没有启动引擎或重新完整工程哈希。此前 `--check-only` 的 autoload 环境失败仍由前一归档原样保留，不与本次合并成玩法通过。
