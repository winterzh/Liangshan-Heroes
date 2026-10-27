# 新统一源码的 Daming 八流程重放宿主

这个宿主只给新的 `projectile_3365_integrated_manifest_v1` 完整冻结接线。它独立调用 `integration_3365/prepare_projectile.py.prepared_state(base_run)`，必须通过 26 脚本 + 1 helper 的完整来源、生成身份、初末 SHA 和该冻结自己第一次成功冷导入检查，且 `cold_import_qualified=true`。旧 25 脚本准入没有改动，也不能作为新宿主的通过条件；3365 是祖先，实际运行使用返回的 `run_base/project`。当前 b22 新候选只有在自己的冷导入已终态成功后才可运行；此目录的创建和轻量检查不证明该资格。

完全引用既有 `daming_continue_candidate/tests/daming_flow/` 五份 GD、fixture helper/model 与固定 `sources.json` 原字节；新宿主的来源表同时 pin 原宿主、原来源表及其完整依赖。当前 route SHA 为 `dc3c538f001410bb9dba4db5f9e49c0ad5188f695b075916048ced0ca138467f`，这份修订在原生五 GD 加载片通过，但并未完成新源的两条自然路线。没有复制或修改旧驱动、原宿主、准备器、候选脚本或它们的来源表。

保持两角色各独立 profile、A/B 两次实际 SaveAndExit/AppLifecycle 退出、八个独立 PID、三个层级 nonce、C 自然第二囚撤离、完整 contract2 三目标实际分类、LCv3/Intentv2/ACKv2/CFG 同 token 链，以及 D 实际菜单 LOCAL_RUN_TERMINAL/无 Battle/无奖励或记录增长的全部断言。原 A 退出0且完整验证后、B 启动前的两文件六目录 closed-A 原件冻结逻辑和长期只 pin 冻结副本的规则均保持。共享锁、自有进程、长路径、前后 source/engine/worker pin、主异常与 cleanup 分开保留均沿用原宿主。

输出独立写 `.godot/daming_projectile_flow_20261027/<batch>/`，原业务槽、LC、profile、EXE/cache 不提交 Git。`DF_SOURCES_SHA256` 仍绑定被引用的原 worker 来源表；新 replay host/README/source 表另外进入全局 pins 与运行时 runner_inputs，不能把两种来源标识混为一项。

```powershell
# 只读轻量，不拿锁、不 full hash、不建 profile、不启动引擎
python qa/campaign_progress_recovery_20261026/projectile_filter_candidate/run_daming_flow.py
python qa/campaign_progress_recovery_20261026/projectile_filter_candidate/run_daming_flow.py --help

# 根任务调度且新冻结自有冷导入通过后，才用该新 base-run 显式 --run
# python .../run_daming_flow.py --base-run <new-complete-projectile-freeze> --run --timeout 1320 --wait-lane 1800
```

本目录当前只完成代码、Python AST/help/default-light 检查，未启动 Godot、未完整重哈希或原生执行。默认参数、原路线900秒总界、各步骤时限和B120正常ticks保持原值。即使八流程后续通过，也不授原19故障、全部61阶段、公开Continue、Steam SDK、发行EXE、人工或发布资格。未来52负例的 admission 必须新增显式新源/新schema绑定，并消费本轮实际 closed-A 原件和完整成功八流程收据；现有旧25-source planner不会自动接受此新绑定，不得伪装旧schema或跨源继承结果。
