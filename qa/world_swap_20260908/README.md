# 统一世界激活与替换原生 QA

来源`2f2ee3a66de94f7051df70185ed623f8802e64a3`；最终`overlay_20260908T010557Z_e4800944`，freeze`1e377eee78a8ffbd8f02e46f23fca17e367f9170d3a4bbb8ccca323b5451c373`。6633条记录通过=5814来源SHA+817非来源断言+2诊断记录；原776项回归保留。诊断为环境像素与安装时点状态各1，未计入功能断言。新增两次完整实际世界替换、移动/真实付费生产完成/在途投射物13点单次伤害/死亡回调/再次真实屏障，与3种失败回滚。运行方法为Windows Vulkan、主窗口0×0、私有user://；没有跨进程继续、真实Steam账号或真人视觉验收。

本次受测候选只有world_core与新world_swap。前序场景/特效/Unit/Battle直接取已提交源码，原生受测副本及SHA见runs和SOURCE_PINS，晋级文件见installation。R1已完成两次实际替换，但未重新部署组合断言失败：恢复已运行时调用capture_gameplay_rng违反其暂停前置条件，返回PAUSE_REQUIRED。R2保持生产候选字节不变，改在同步调用栈内暂停读取RNG后恢复运行状态，资源/分配器取稳定屏障时点，并拆开各项断言和保留预期/实测诊断。全部实际运行均保留，不以最终通过覆盖失败输入；新脚本UID来自原生隔离导入。

复现时使用来源提交独立checkout，将candidate/*.gd.txt还原原名到scratchpad/world_swap_20260908，保留.gdignore、manifest和freeze；随后执行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 2f2ee3a66de94f7051df70185ed623f8802e64a3 --freeze-sha256 1e377eee78a8ffbd8f02e46f23fca17e367f9170d3a4bbb8ccca323b5451c373 --candidate scratchpad/world_swap_20260908 --expected-files 2 --driver driver.gd --driver-destination tools/world_swap/driver.gd --suite world-swap-native --prefix "[world swap QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可换受控短绝对路径。全目标边界、激活顺序/回滚及待办见[实现说明](../../docs/WORLD_SWAP_20260908.md)。
