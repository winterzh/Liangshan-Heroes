# Slot recovery readset candidate

本文件记录工具准备时状态：候选尚未编译、运行或采用。后续原生结果由独立验证记录记载；此前 d7、组件或恢复测试的资格不转授本候选。这里只替换 d7 的 `scripts/run_snapshot_store.gd`，不修改生产、旧冻结、3000ms 预算或测试阈值。

## 依据与范围

基底为 `.godot/campaign_progress_recovery_20261026/20261027_013339_8495b720`，完整身份 `source-v1:d7f2258b8be6f77e3577ff9c3b018427c805c84385e86f1daa54aaa49cc30dac`，原 Store SHA `7052bc687a26ef9edb155465e070bcedf1ae86a3e8f19b0553bb7757b8ad9b0c`。同字节隔离副本的只读计时批 `031418_1f3a2756` 观察到 inventory 359ms、chain 1479ms、单独 verified 1513ms、原 initial inspect 3808ms 后超时；helper 的真实 dead 查询约119ms。这是重复解析成本的证据，不是新候选性能或恢复成功的证明。

只有运行时 `ResourceLoader.load("res://scripts/run_slot_store.gd", "Script", CACHE_MODE_REUSE)` 返回的原安装 Script 与 `get_script()` 为同一对象时启用证明。运行时查询避免基类 preload 子类的继承循环；此接线仍待实际导入验证。CFG、LC、StartupReader、Steam 及任何 Slot 派生类继续原完整 readback，不继承优化。原 Slot 校验器不读取 `_pending_write` 等可变事务状态；不能把此资格推广到其他校验器。

## 保留的合同

1. 每次完整 inspect 先清理旧证明，保留原完整 inventory、虚拟 `_chain`、pending 校验、owner UTF8/metadata 校验。原 `_verified` 成功时只记录 `_decode` 从实际解析 raw 字节计算的 SHA，不使用随后重读路径取得的 SHA 代替它。
2. 每个实际读取的 record/pending SHA 必须等于初始库存对应项；同路径不同 SHA、owner raw SHA 不符立即拒绝 `RECOVERY_READSET_CHANGED`。全部文件覆盖失败拒绝 `RECOVERY_READSET_INCOMPLETE`，不能静默回退。目录集合保留在完整库存中。
3. 封闭证明只存在该实例私有内存，绑定深拷贝 plan、库存、原 owner raw、directory/owner、实例 ID、原 Script 强引用、scope ID 和 epoch。公开 plan 不携带证书。每次 fresh inspect 重建，最外层 scope 结束清除；跨公开调用不复用。
4. 有证明的 readback 仍检查真实预算，重新检查原路径/链接/目录规则、文件大小与完整原生 SHA 库存，再严格重读 owner raw。只有当前全部字节 SHA 和目录集合与证明完全相同时，跳过重复 `_chain` 的 UTF8/Schema 解析。绑定变更拒绝 `RECOVERY_READSET_SCOPE`；库存或原文变更拒绝 `RECOVERY_CAS_CHANGED`；超时保留原错误。证明不存在或类型不适用时保留原完整路径。
5. `recover`、`_recover_base` 整个函数保持原字节：原 fresh inspect/plan 全等、inspect 与 claim 两次独立进程查询、同一 recover scope 的 3000ms 总预算、claim 前完整 CAS、claim 后 inventory/full chain/prune/final open_head 均保留。无 await、事件泵、时钟替换或外部 head 重定基。

初始库存 A,H（H.previous 指向 B）→校验时临时换成 B,H→还原 A 的 ABA，不能仅靠最后库存相等放行；实际 `_verified` 的 B SHA 在第一次库存绑定处就必须拒绝。当前合同是字节与目录集合 CAS，不声称识别全字节相同的文件或目录替换，也不保证断电耐久性。不得删掉后 claim 校验来追求耗时结果。

## 静态交付与后续验证

`store_changes.diff` 是相对 d7 的精确文本差异；`static_audit.json` 记录来源、改动方法与原恢复函数逐字一致检查；`sources.json` 绑定实际读取的基底及支持文件；`source_manifest.json` 只声明这一项 overlay。根线程独立管理 `prepare_readset.py`，测试作者独立管理 `tests/`，两者不放入本 Store 来源清单或擅改其文件。

需在新冻结验证：编译与 exact Script 匹配、原4MB同字节副本的 pending/record 恢复及真实费用/世界恢复、实际磁盘 ABA、owner/目录/记录变更、假 plan、scope 关闭/过期、派生 Slot 与 CFG/LC 的完整 fallback，以及真实活 PID/未知 PID/超时仍不认领。正常 inspector 返回后证书已清空；恢复中的嵌套 fresh 才能在同 scope 复用。小型模型与合成死锁夹具不授 Flow、公开入口、SDK 或玩家验收资格。

本候选未运行引擎；不宣称超时已修复、恢复性能通过或生产已集成。
