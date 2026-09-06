# 密集兵群分离的邻居筛选

2026-09-06。算法对照基线 `5457de797678889ce606abb9468a2a994f634d51`；最终验证已整合另一任务的祝家庄门楼提交 `1b9784ae8ebace2b431500a721f242badaa9f665`。生产只改 `scripts/crowd_separation.gd`，使用范围仍是64～320名机动单位且平均每桶超过2人；其他规模、分散队伍及原大规模分组沿用原循环。

此前合并单位重绘后，一次10秒逐帧诊断中分离约1.33秒，仍是物理更新较大的单项。嵌套计时有包装开销和重叠，仅用于选择优化对象，不作正常帧率。

本次把分离过程中不会改变的邻居条件提前处理：按移动类型分桶，省去剧情终态邻居；每桶记录最大实例ID，如果最大ID也不超过当前单位ID，则整桶都符合原先的排除规则，可以跳过。保留桶遍历顺序、桶内剩余条目顺序和重复条目；每对的当前缓冲位置、金矿工人穿行、半径、权重、导航检查与位置写回时机保持原算法。

这些分组只在一次同步调用中使用。下一次重新读取网格、剧情状态和移动类型，不缓存旧阵亡/撤退信息或跨帧网格。仍允许旧网格中的死亡或驻军邻居参与原本允许的处理，没有增加原算法不存在的邻居血量/驻军过滤。

## 验证

`tools/crowd_neighbor_qa.gd` 继承完整兵群回归，以已经采用位置缓冲的旧版本作参照，包含两份冻结源码：原分离派发函数和原完整缓冲求解器。参照辅助加载发生在计时外；派发保留旧条件。两方共享同一实际地图与Unit实例，逐次恢复相同起点再比较。

- 最终99项通过，408次连续步骤、82,968次位置逐值一致，同时核对单位状态、相位及输入桶顺序。
- 覆盖实际6/30/63/64/128/320/321/326/506人数、密集/分散、陆水混合、工人金矿穿行、小数半径、重叠位置、倒序、重复条目、仅在网格内的邻居，以及建网格后发生位移/死亡/驻军/撤退。
- 新增桶内倒序、局部乱序、相邻重复和空桶，跨三次重新建桶检查，防止筛选顺序或上一轮状态泄漏。
- 独立计数运行中，206人单次分离的内层候选访问由12,799降至8,163，两方最终位置相同。计数包装不进入性能窗口。
- 场景、地图与单位确实释放，玩家存档字节保持。导航69项、实际远程通行23项、祝家庄门楼27项及孙立接应22项整合回归通过，合计240项；见[本批QA](../qa/crowd_neighbors_20260906/README.md)。

## 耗时与限制

双方预热，三组交换先后顺序；计时包括完整派发、索引/分组创建、所有碰撞计算和位置发布，不含每次外部起点恢复或网格重建。密集206/128/320人每窗口80次，64人每窗口800次；headless函数计时不代表画面帧率。

| 密集人数 | 旧→新微秒/窗口 | 耗时下降 |
| --- | --- | --- |
| 64 | 541362→527138 | 2.6% |
| 128 | 143454→128400 | 10.5% |
| 206 | 278557→226786 | 18.6% |
| 320 | 445632→373284 | 16.2% |

完整20组人数/密度窗口保留原始结果；未启用缓冲的路径没有生产变更，其独立计时也会波动，不能把这些差值算作本次收益。曾试过相邻桶列表复用及有序前缀二分，两版收益不稳定，最终未采用；相关候选和原结果单列attempts。

最终正常压力窗口367帧/10.011629秒，即36.66FPS，P95 64.368ms、P99 85.986ms，最慢110.573ms；截图末段65FPS为瞬时值。前一批37.27FPS是不同镜头/战损的独立窗口，本批不声称整体FPS已获得稳定增幅。整场压力原始结果另存本批QA。分离只是剩余耗时的一部分，不能用函数下降18.6%推算整体FPS；物理/绘图、长时稳定性及真人验收仍需继续推进。

## 复现

```powershell
$godotExe=(Get-Content -LiteralPath .\godot.local.txt -Raw).Trim()
& $godotExe --headless --path . --script res://tools/crowd_neighbor_qa.gd
& $godotExe --headless --path . --script res://tools/segment_endpoint_qa.gd
$env:RTS_TEST_OUT='res://.godot/crowd_neighbor_regression/ranged'
& $godotExe --headless --path . --script res://tools/ranged_firing_path_test.gd
$env:RTS_TEST_OUT='res://.godot/crowd_neighbor_regression/contact'
& $godotExe --headless --path . --script res://tools/zhujiazhuang_gate_contact_test.gd
$env:GATE_ART_OUT='res://.godot/crowd_neighbor_regression/gate'
$env:GATE_ART_VISUAL='1'
& $godotExe --path . --script res://tools/zhujiazhuang_gate_art_qa.gd
$env:PERF_DEFENSE='1'
$env:PERF_OUT='res://.godot/crowd_neighbor_stress.json'
$env:REDRAW_SCREENSHOT='res://.godot/crowd_neighbor_stress.png'
& $godotExe --path . --script res://tools/unit_redraw_stress.gd
```

压力窗口使用实际1440×900 Forward+、1倍速、预热3秒并采样10秒；不启用计时包装，也不与其他Godot测试并行。运行输出在忽略的 `.godot/`，冻结证据位于 `qa/crowd_neighbors_20260906/`。源码启动配置不变；本次代码同步不涉及导出或发布。
