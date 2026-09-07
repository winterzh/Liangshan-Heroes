# 世界核心准备事务 QA

来源e8b4d496acb440d364da04898952cd5f26f7400d。保留五次实际运行：R1无头纹理回读失败，R2真实Vulkan通过，R3驱动解析失败，R4修复驱动通过，R5加强逐ID顺序与迷雾纹理回读后通过。每次目录保存实际生产候选/驱动、执行器、冻结清单、日志、manifest和存在的报告；R3未生成报告，未伪造补档。

`SOURCE_PINS.json`按原路径/SHA记录原字节归档。candidate为最终冻结版本，.gd.txt不参与Godot导入；installation记录生产代码及原生UID安装。QA根有.gdignore，Git属性保持证据原字节。[合同、结果与明确未完成范围](../../docs/WORLD_CORE_PREPARATION_20260908.md)。

R5共5823项=5778来源SHA+45其他断言。正常经典开局120physics观察帧+实际屏障，准备完整核心后额外4process帧保持禁用；14个坏分区、4项跨分区/身份冲突和历史队列编号夹具。窗口最小化，未做截图/可见视觉验收；未挂载新世界，未做跨进程续玩。

## 重现R5

创建上述来源SHA的独立checkout，配置本机Godot4.6.3到忽略的godot.local.txt。核对SOURCE_PINS后，从candidate把run_battle_world_core.gd.txt和driver.gd.txt还原为原名，连同overlay_manifest.json、freeze.json放到scratchpad/world_core_20260908，添加.gdignore。将runs/r5/executed_runner.py.txt恢复到tools/run_stabilization_overlay.py；来源提交中的执行器尚不支持rendered-driver。保留来源提交的guard，并核对其SHA与归档一致。不要复制归档UID进入来源scripts，否则新增路径保护将拒绝运行；UID由隔离原生import生成。

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head e8b4d496acb440d364da04898952cd5f26f7400d --freeze-sha256 578a1770754d93e350a0370ccd7b0e734f7be786ff3bd8545341f0dfc891b930 --candidate scratchpad/world_core_20260908 --expected-files 1 --driver driver.gd --driver-destination tools/world_core/driver.gd --suite world-core-native --prefix "[world core QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可替换为本机受控绝对短路径。不得把旧收据中的绝对路径当新写入目的地；原生执行器负责私有环境、独占Godot、超时/错误清理、全来源及玩家保护。preparation脚本只供审计，不是从QA目录直接运行的入口。
