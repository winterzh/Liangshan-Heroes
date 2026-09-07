# HUD 消息恢复原生 QA

来源 `4e713a13145f07d0120204c9c172209c195784e0`，最终原生运行 `overlay_20260907T223414Z_48b826df`，5949项通过：5794项来源SHA、155项其他断言。Windows / Forward+ / Vulkan，独立user://，窗口最小化。消息滚动检查是原生Control属性检查；按钮操作通过真实Button的pressed信号，未声称OS点击或画面布局验收。

runs保留本批所有原始失败和通过记录、实际生产候选、驱动、执行器、manifest/freeze、日志和保护收据。candidate为最后受测输入，preparation仅供审计。SOURCE_PINS记录原字节SHA，installation记录晋级及UID。R1为新增变量类型推导失败，R2误用了没有绑定到GDScript的Tween C++ getter，均已修正。R3逐帧一致，但600帧观察不足以等到真实寿命，导致到期及后续去重夹具失败；驱动改为真实时间上限内等到原生退出。其余结果以各自report和receipt为准，不删除失败证据。

驱动先在真实经典战斗正常推进120个physics观察帧，再设置三条处于淡入/停留/淡出阶段的真实提示Tween，用实际HELD屏障捕获。恢复后短暂只开放源/目标HUD idle消费者及源提示退出信号，以原Tween为对照，逐帧比较文字/计数/透明度/退出；战斗世界和SceneTree始终暂停，结束重新禁用源HUD。这是隔离UI生命周期比较，不是完整战斗激活。

在来源提交的独立checkout核对Godot、runner/guard SHA，将candidate三份生产.gd.txt与driver.gd.txt、driver_cases.gd.txt恢复为.gd原名，连同overlay_manifest.json和freeze.json放到scratchpad/hud_messages_resume_20260908；保留.gdignore，不把归档UID复制进来源scripts。运行：

```text
py -3.14 -X utf8 -B tools/run_stabilization_overlay.py --source-head 4e713a13145f07d0120204c9c172209c195784e0 --freeze-sha256 b9a5d634cf213538c17a9cba954fe93a6a27d1a47003734f5249df253914009f --candidate scratchpad/hud_messages_resume_20260908 --expected-files 3 --driver driver.gd --driver-destination tools/hud_messages_resume/driver.gd --suite hud-messages-resume-native --prefix "[hud messages QA] " --profile-root D:/CodexTemp/lshqa --rendered-driver --run
```

profile-root可改为受控短绝对路径。完整HUD、世界安装、磁盘槽、跨进程、Steam账号、人工和性能验收仍未完成。[合同与后续](../../docs/HUD_MESSAGES_RESUME_20260908.md)。
