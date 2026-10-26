# Slot readset：完整冻结与独立导入证据

新冻结 `.godot/campaign_progress_recovery_20261026/20261027_034810_ed1bdef8` 的 preparation 与 `import__20261027_035209_79e28901` 均完成。导入原生 PID 75344，退出 0，错误列表为空，耗时 51.221 秒，原收据确认共享锁已释放。新内容身份为 `source-v1:768b6e5937321126b4c927fce6b5565459610aa13ccb556f695837a814eb74c2`。

本归档独立重新散列 d7 与新冻结两份实际工程各 7062 个源文件；新树只有 `scripts/run_snapshot_store.gd` 一项与 d7 不同，完整目录集合相同。新 preimport_source 与 generation.identity 全文一致；生成常量规范字节、expected_identity、23 脚本与 1 个原生 helper 身份均已核对。新 manifest SHA 为 `11c1d813daab8fd9eeaa0e8ed7569deb33da3af243b429c9cffc69c6de74a5e6`，Store SHA 为 `f222e8b3798355164ab29da4d0dc534362e2bea680ec7f7dbe7462b86df8959f`。

122 个 preparation pin 全部回读一致，118 个非 EXE 的冻结 preparation_inputs 副本全部与原 pin 相同。归档保留6份原始源清单/准备记录、实际导入日志与收据、7份冻结 Store/说明/差异/静态记录/来源/overlay/准备器原件，以及 helper 的 C# 源和构建收据。所有副本均逐字核对；源映射和未复制的基底依赖见 source_map，逐文件大小和 SHA 见 manifest。没有复制完整工程素材、导入缓存、EXE、玩家存档或 profile，也没有改动已固定的候选或测试输入。

这里只授完整冻结与导入/编译资格。实际恢复、ABA/拒绝矩阵、性能、原 61 阶段、公开入口、Steam SDK、原版 EXE、人工体验、生产采用或发布均不由本归档授予；后续 Flow 或模型结果必须按自己的终态收据独立结算。旧冻结的任何通过不继承给新来源。
