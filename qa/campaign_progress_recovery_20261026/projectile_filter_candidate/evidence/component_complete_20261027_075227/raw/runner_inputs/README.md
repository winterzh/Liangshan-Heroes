# 弹道滤镜存档契约候选

本文件记录准备时状态：候选和组件工具尚未编译、未运行，未采用到生产。高俅 070648 原批已保留：第一波清场通过，真实 SaveAndExit 在 visual/projectile 返回 `TIMED_RENDER_OVERRIDE`，没有得到保存退出资格。

3365 完整源继承 941c 高俅接线并包含大名府安全获救者接线。本候选只替换其中 `scripts/run_visual_graph.gd` 一处校验：确切 `kind == projectile` 必须为 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`，其余种类继续要求 `TEXTURE_FILTER_PARENT_NODE`。原 material、use_parent_material、texture_repeat、light_mask、visibility_layer、clip_children 条件和全部其他方法保持；不能接受两种滤镜任选，更不能关闭渲染校验。

来源冲突有源码及真实失败证据：`projectile.gd:52–54` 的正常 `_ready()` 无条件设置 MIP，Graph 的旧 1043 行却要求 PARENT。`run_projectile_state.instantiate` 不设置滤镜；脱树 prepare 后挂入暂停 SceneTree，原 `_ready()` 应重新设置 MIP。该派生常量不进入存档字段，故不改变 schema、身份、弹道时间、伤害、射手/目标引用、RNG 或载荷。`minimal.diff` 可逆还原 3365 原 Graph 字节。

## 分开的准入边界

- `sources.json` 固定本片源码、实际 3365 元数据、组件命名依赖；这些实际源 SHA 与已保存 generation 对应，未重新哈希完整工程。`source_manifest.json` 只声明这一处 overlay，父清单不纳并行开发的 integration 或真实战斗重跑工具。
- `tests/run_filter_model.py` 默认只检查命名输入，不建 profile、不复制、不启动引擎。`--run` 才在共享锁下使用已独立导入的 3365 工程和外部候选 Graph，创建独立短 profile 与一名真实子进程；固定 worker/candidate/runner 来源，前后核命名 SHA、原生 PID/退出/日志与自有锁。它不等于新的完整冻结、cold import 或组合运行资格。
- `integration_3365/` 的准备器由另一负责人提供：用于后续全新完整冻结及独立 cold import。只有其自身真实收据可以授该项资格，不沿用本组件测试或旧 3365 的编译结论。

默认轻量检查：

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/run_filter_model.py
```

由主线程独占引擎通道后显式运行：

```powershell
C:\Python314\python.exe -B qa/campaign_progress_recovery_20261026/projectile_filter_candidate/tests/run_filter_model.py --run --timeout 300 --wait-lane 60
```

## 组件模型的实际范围

使用真实 `Projectile.new()` 和 `Battle.BlinkShotFx.new()` 加入隔离的 Node2D 夹具，正常 `_ready()` 产生滤镜；不实例化 Battle、不开关卡、不做 SaveAndExit、不写玩家业务文件。弹道使用构造器默认状态和空 shooter/target，明确是合成组件数据，不是自然飞行/伤害证据。暂停仅限此合成夹具，不修改游戏世界。

先用未修改的原 Graph 捕获，必须复现 `TIMED_RENDER_OVERRIDE/projectile`；再用候选完整 capture→validate/prepare→脱树壳→暂停挂载执行 `_ready()`→activate→recapture，严格比较 typed wire 与编码字节，全链同步不等待物理帧。12 个独立负例覆盖 projectile 的 PARENT/NEAREST/LINEAR/nearest MIP、材质、继承材质、repeat、光罩、可见层、裁剪，以及其他 timed kind 的 MIP/材质拒绝；每个负例只扰动合成节点，恢复后必须与原 wire 完全一致。其他种类仅实测代表 BlinkShotFx，全部原拒绝条件另以最小 diff 保持，不声称全特效矩阵。

宿主要求原生退出 0、无引擎脚本错误、完整报告与进程/nonce/源码绑定、12 负例和往返断言均真。超时或编译失败保留原输入/日志/收据；不能以 stdout 单行或基线预期拒绝当候选通过。SDK 禁用、私有战役入口关闭；正常 autoload 后及进程退出后均核没有 continue、campaign.cfg、CFG 事务或 Steam 收据业务路径。

后续仍须全新源独立 cold import、真实高俅四进程 SaveAndExit/Continue 通关，以及自然战斗中的在途弹道保存/恢复。公开入口、SDK、真人键鼠、EXE和发布资格均不在本片。
