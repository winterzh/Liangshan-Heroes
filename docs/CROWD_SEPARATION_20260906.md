# 拥挤分离计算优化

2026-09-06，基线 `3a218f03403b5bb491b98289eb53f7eaaa68e8d5`。生产修改限定为 `scripts/battle.gd` 的 `_separation_pass`。

原循环对每个相邻单位反复读取当前单位的位置、半径和移动类型，并在每次有效分离后更新当前单位的 Node2D 位置。现在复用这些值，每次外层循环结束时写回当前单位的最终位置；相邻单位的位置仍立即写回。处理顺序、实例ID筛选、金工相位、移动/静止权重、障碍检查、320人以上的分组阈值和物理频率保持原样。

当前外层循环的候选单位ID都大于当前单位ID，不会把当前单位作为相邻单位读取。循环内需要的当前坐标均使用本地最新值，下一外层循环开始前发布最终位置。地图线段检查只读取地形和导航网格；Unit没有自定义位置设置器或依赖此中间写入的变换通知。

## 对照与计时

旧函数从基线Git源码提取，统一为LF后完整冻结在 `tools/contracts/separation/before_3a218f0.txt`，由QA校验SHA后原样编译。两种实现共享同一地图、同一批206个实际Unit节点及相同的桶顺序，从完全相同的位置起步。

- 32个明确构造的夹具：移动、静止、陆水混合、携金工人、小数半径、完全重合、倒序单位、网格生成后死亡/撤离/驻守；各有两种间距与分组开关。
- 每个夹具连续9步，每步重建实际网格。288步、59,328次Vector2位置对照完全一致，分组相位和角色状态/路径保持。分组阈值由夹具显式注入，并非326人的实战验收。
- 专项38项通过，包含全部夹具执行完成、场景实际释放与玩家存档字节不变的检查。
- 同一批206单位的密集/分散布局，各预热后进行三组顺序交替的配对计时；每个窗口80次函数调用，重置位置和网格构建不计入耗时。密集中位497990→434088微秒，减少12.8%；分散中位133784→113420微秒，减少15.2%。计时不设跨主机绝对门槛。

这两项是该函数的CPU耗时改善。真实渲染的200敌军对6英雄压力窗口仍只有约13.80FPS，P95为184.119ms，明显未达性能预算；存活人数、技能、自动镜头和物理追帧改变后续负载，不能用不同实战窗口直接计算稳定FPS增幅。最终窗口原日志和逐帧数据保存在QA的 `diagnosis/`。此前临时测量和批处理原型已撤回，生产Unit/HUD没有本批修改。

现有回归还通过：路径专项58项/81,000条旧新线段对照、实际远程寻路23项，以及当前黄泥冈54项（酒计与强夺实际路线、边界、重开和跨模式定义）。加上新专项共173项检查；没有将这些自动回放当作真人平衡、30分钟稳定性或发行验收。

## 复现

使用本机 `godot.local.txt` 或启动脚本解析的Godot4.6.3路径。含CPU计时的验证应逐个运行，避免与其他Godot实例争用资源。

```powershell
$godotExe = (Get-Content -LiteralPath .\godot.local.txt -Raw).Trim()
& $godotExe --headless --path . --script res://tools/crowd_separation_qa.gd
& $godotExe --headless --path . --script res://tools/segment_navigation_qa.gd
$env:RTS_TEST_OUT = 'res://.godot/crowd_separation_qa'
& $godotExe --headless --path . --script res://tools/ranged_firing_path_test.gd
$env:HNS_CASE = 'all'
& $godotExe --headless --path . --script res://tools/huangnigang_short_test.gd
```

成功均退出0。临时输出分别在 `.godot/crowd_separation_qa/`、`.godot/segment_navigation_qa/` 和 `.godot/huangnigang_short/all/`，冻结证据见 [本批QA](../qa/crowd_separation_20260906/README.md)。实际压力测量入口沿用 `tools/rts_collision_profile.gd` 与上一批文档的 `PERF_DEFENSE=1`、`RTS_PROFILE_BENCH=200` 参数。
