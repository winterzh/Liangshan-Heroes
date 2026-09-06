# 空间网格重建复用单位投影

2026-09-06，冻结参照 `877e713ed9e7aed7a9209ce9d382eee61d8ba336`。最终已快进整合另一任务的 `e2111518319a27f656f2fe1d527b06d1b1f70003`（战役倒地服装保护）。核对 49 个远端路径并逐字保留本任务三个工作文件，未复制对方未提交素材或工具。两提交间的网格函数未改变。

## 实现

生产仅改 `scripts/battle.gd` 的 `_grid_build()`：一次单位更新先计算等距投影，供屏幕裁剪和 z_index 共同使用。若可见性发生变化，重新计算一次投影，保留同步 visibility_changed 回调移动单位后再读取深度的原行为。投影只在这一次循环迭代中复用，不跨物理帧缓存，仍读取地图当前高度。

保留每帧完整清空/重建四个网格与集火计数，保留单位/桶顺序、重复项、负坐标 floor、死亡/驻军/剧情/资源筛选、原本的 z_index 写入，以及 _lite_fx 在本次结束更新、下一次用于裁剪的时机。桶查找候选和额外 z_index 比较没有稳定收益，均未保留。没有修改单位物理、战斗规则、分离或美术资源。

## 对照验证

`tools/contracts/grid_build/before_877e713.txt` 冻结完整旧函数，SHA256 `997bddb65ecfccc6c033ab292eeca006b501337297390af74c4f2a0e47c77d2d`。`tools/grid_build_qa.gd` 在相同真实 Unit/地图上依次执行两方，142 项全部通过，9,438 组单位可视/坐标/层级状态以及 4,018 个邻近/身体阻挡查询结果相同。

覆盖八关真实部署、各关合成 200 敌移动队列、镜头缩放、实际驻守部署与压力队列；也覆盖负数/格线位置、三种阵营、死亡/NaN 血量/驻军/多种剧情终态/建筑/资源、重复/空/已释放引用、同步可见性回调移动、无相机保留裁剪框，以及普通/全托管 90/36 人严格阈值两侧和连续两次更新。场景/地图/单位释放及玩家存档字节不变。

驻守压力全部单位可见时，独立计数记录完整重建的投影 452→226；计数不参加耗时测量。最终整合另通过兵群 99 项（408 步/82,968 次位置一致）、墙体遮挡真实渲染 214 项、战役终态服装真实渲染 286 项，合计 **741 项**。终态服装和墙后部件图为固定检查视图，不代替真人通关、动作观感或长时验收。

## 完整函数计时

每个场景双方预热，三个配对窗口交换先后顺序；每窗口完整执行 200 次重建，包含可见性、投影、层级写入和全部桶分配。以下为三个窗口中位数；八关部署加压力及三种驻守场景共 19 组。单次单位数据共享但模拟冻结，函数时间不能换算正常 FPS。

| 场景 | 旧函数 μs | 本版 μs | 变化 |
| --- | ---: | ---: | ---: |
| level1 original deployment | 19874 | 18243 | -8.2% |
| level1 200 enemy fixture | 225208 | 169391 | -24.8% |
| level2 original deployment | 46856 | 38824 | -17.1% |
| level2 200 enemy fixture | 205855 | 175013 | -15.0% |
| level3 original deployment | 41029 | 40663 | -0.9% |
| level3 200 enemy fixture | 210186 | 165011 | -21.5% |
| level4 original deployment | 38718 | 39353 | +1.6% |
| level4 200 enemy fixture | 166342 | 160143 | -3.7% |
| level5 original deployment | 53168 | 47685 | -10.3% |
| level5 200 enemy fixture | 166018 | 158566 | -4.5% |
| level6 original deployment | 3191 | 3337 | +4.6% |
| level6 200 enemy fixture | 225955 | 153419 | -32.1% |
| level7 original deployment | 5726 | 5319 | -7.1% |
| level7 200 enemy fixture | 221238 | 158509 | -28.4% |
| level8 original deployment | 47356 | 42644 | -10.0% |
| level8 200 enemy fixture | 168228 | 162333 | -3.5% |
| defense deployment | 15014 | 14772 | -1.6% |
| defense 200 enemy fixture | 163846 | 159547 | -2.6% |
| defense stress all visible | 259033 | 174148 | -32.8% |

并非所有场景都有收益：level4 原部署与仅四名角色的 level6 原部署有小幅变慢；具体原始窗口均保留。收益集中在大量已显露单位的重复投影，正常驻守迷雾布置的收益较小。

最终无插桩正常驻守战：267 帧 / 10.012926 秒 = **26.67 FPS**；P95 68.873ms、P99 98.979ms、最慢 116.483ms。Godot 4.6.3 / RTX 3070 Ti / Forward+ / 1440×900 / 1 倍速，200 敌布置，预热 3 秒后采样约 10 秒。结束单位数 140，镜头缩放 (1.15409, 1.15409)。这是独立战斗窗口，单位战损、镜头及特效会变化，不能把与上轮 24.57 FPS 的差值当作配对整体收益；60 FPS 和长时性能验收仍未通过。

## 诊断与复现

本轮基线细分计时中，581 次物理步累计约 7.58 秒，单位物理约 3.81 秒、分离约 2.03 秒、网格重建约 0.78 秒；31.5 万次 Battle 投影约 0.59 秒。探针本身有开销且嵌套时间重叠，不能相加或作为无探针正常帧率。五种网格候选的同场景控制支持只保留投影复用；临时包装均在 finally 中恢复。诊断源、原始逐帧数据及候选控制见[QA](../qa/grid_build_20260906/README.md)。

```powershell
$godotExe=(Get-Content -LiteralPath .\godot.local.txt -Raw).Trim()
& $godotExe --headless --path . --script res://tools/grid_build_qa.gd
& $godotExe --headless --path . --script res://tools/crowd_neighbor_qa.gd
& $godotExe --path . --script res://tools/wall_visibility_qa.gd
$env:TERMINAL_COSTUME_VISUAL='1'
$env:TERMINAL_COSTUME_OUT='res://.godot/grid_build_costume'
& $godotExe --path . --script res://tools/campaign_terminal_costume_qa.gd
$env:PERF_DEFENSE='1'
$env:PERF_OUT='res://.godot/grid_build_stress.json'
$env:REDRAW_SCREENSHOT='res://.godot/grid_build_stress.png'
& $godotExe --path . --script res://tools/unit_redraw_stress.gd
```

专项默认输出 `.godot/grid_build_qa/`，启动方式不变。归档驱动内的本机路径属于历史诊断证据，不是公共启动配置。发布、全库四向、真人八关/驻守与整体性能待办继续保留。
