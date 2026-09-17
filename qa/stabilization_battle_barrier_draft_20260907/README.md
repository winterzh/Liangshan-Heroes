# 实际战场屏障候选：未接入交接

2026-09-07 按用户“收个尾同步到 GitHub”停止新开发。候选基于
`2e40c4afd5d3bce22a8204bed2c1f903fc046ff5`，只完成编写和准备期语法检查。
本次封存重新检查 10 个冻结输入、11 份归档原字节和 4 项生产 before 条件。
没有启动 Godot，没有原生通过收据，不能作为实际战场屏障验收。

四个候选文件为 Battle、根状态 v3、run_battle_clock、run_battle_barrier。
正式工程仍保持已验证的根状态 v2；本目录用 .gdignore 和 .gd.txt 隔离。
`original/preparation.json` 是冻结前记录，其 unfrozen 状态按原字节保留；
最后冻结状态以 `original/freeze.json` 的 native_pending 为准。

## 恢复和下一步

1. 使用上述来源提交的独立、干净 checkout；在继续开发的分支上重新冻结时，
   必须先核对来源及 before 条件，不能只改命令中的 SHA。
2. 根据 SOURCE_PINS.json，将 archive 逐文件复制为 restore_name，放入该
   checkout 的全新 `scratchpad/stabilization_battle_barrier_20260907/`。
   恢复 .gd 原名，验证每个 SHA 和 freeze SHA，保留原 manifest 路径。
3. 配置本机 Godot 4.6.3，确认没有其他原生测试占用公共锁。
   以下命令省略 --run 时仅预检；添加 --run 才启动隔离原生运行。

```powershell
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 2e40c4afd5d3bce22a8204bed2c1f903fc046ff5 --freeze-sha256 8c6305d1d26043a3afb940b728ffd78ae8525fa512ce79bd0b465ac3f642b550 --candidate scratchpad/stabilization_battle_barrier_20260907 --expected-files 4 --driver barrier_smoke.gd --driver-destination tools/stabilization_battle_barrier/barrier_smoke.gd --suite actual-classic-battle-barrier-candidate --prefix "[actual classic barrier QA] " --run
```

prepare.py/prepare_driver.py 只封存编写来源；它们依赖原准备环境中的其他
scratchpad 输入，不能作为全新 checkout 的自包含生成入口。应使用已冻结的
候选及驱动，不重新执行准备脚本或改写原 freeze。失败后另建尝试并保留失败。

驱动拟检查真实经典 Battle 120 次物理回调、HUD/镜头关闭、暂停捕获与释放、
根 v3 JSON/脱树绑定、保留原用户暂停。这里描述的是预定测试，尚未实际通过。
无上限 headless FPS 下，5 个 process_frame 不保证物理帧前进；若该断言失败，
须先区分夹具计时和产品故障，再在新尝试中修订。

后续还需真实 Projectile/LiBrawnAxes idle 伤害、延迟任务/清理、跨进程完整
世界恢复、全部效果、磁盘事务和玩家菜单。早先独立调度夹具的通过不能替代它们。
