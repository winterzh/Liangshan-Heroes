# 路径线段检查的重复计算优化

2026-09-06，基线 `7fbdc3a`。本批生产代码只改 `scripts/game_map.gd` 的 `_segment_open`，保持现有分离顺序、碰撞、移动档位与格角遍历。

单位移动、路径平滑和拥挤时的软分离都会调用线段可通行检查。此前先通过 `is_open_world` 分别检查两个端点，再把同一对端点转换成地图格子，重复了坐标转换；同格短位移还会两次读取同一格的阻挡状态。现在先检查两端边界，只转换一次，在同格时复用一次阻挡结果。跨格后的 DDA 遍历及斜角两侧检查没有改动。

## 当前证据

- `tools/segment_navigation_qa.gd`：58项检查通过。八关实际碰撞网格加一张明确障碍夹具，共81,000条长/短/零长度线段，在陆路、水路及原有兜底档位下与冻结旧实现一致。
- 独立边界覆盖负坐标、地图右/下边界、原点、无穷/NaN、同格实心、格边、斜穿格角、船与陆地隔离、动态占地关闭/开放。
- 同一批206个实际Unit实例，在三种间距、三个分组相位及有/无分组分离共18个夹具里，旧新地图检查得到完全相同的Vector2位移。分组阈值由夹具显式注入，未改生产规则。
- 原 `ranged_firing_path_test.gd` 23项通过：实际命令使投石车寻路并隔墙击中塔，墙体保持关闭、近战不穿墙、原地坚守不追敌。
- 配对CPU计时：每窗口10万次短线段查询，双方预热、三组顺序交替。旧实现中位400641微秒，新实现289674微秒，减少27.7%；查询结果计数相同。此值是函数吞吐量，不是整局FPS提升。
- 玩家战役存档字节保持；没有改其他任务的单位或黄泥冈文件。

## 性能范围

当前大名府开局10秒实际渲染样本P95为10.987ms。另用现有 `200敌军对6英雄` 驻守压力夹具发现分离热点；优化前后日志在QA的 `diagnosis/`。该拥挤场景仍严重超出帧率预算。实时战斗损耗、自动镜头和物理追帧数量会改变后续负载，因此这些独立整局窗口只用于发现热点，不能直接以5.65到11.29FPS的差值宣称稳定翻倍。

曾尝试将分离中的距离判断前移，未获得充分稳定收益，已撤回，`battle.gd`与基线一致。最终保留的是端点去重优化。代码改进不等于当前版本30分钟/30波或真人性能验收完成。

## 复现

从工程根目录，用本机 `godot.local.txt` 或启动脚本解析的Godot路径运行：

```powershell
$godotExe = (Get-Content -LiteralPath .\godot.local.txt -Raw).Trim()
& $godotExe --headless --path . --script res://tools/segment_navigation_qa.gd
$env:RTS_TEST_OUT = 'res://.godot/segment_navigation_qa'
& $godotExe --headless --path . --script res://tools/ranged_firing_path_test.gd
```

两项都应退出0。结果在 `.godot/segment_navigation_qa/`，冻结旧函数位于 `tools/contracts/navigation/`。函数QA含主机计时，运行时避免与其他Godot验证并发。

真实渲染诊断入口 `tools/rts_collision_profile.gd` 继承现有RTS探针；不加headless/fixed-fps，使用 `PERF_DEFENSE=1`、`RTS_PROFILE_BENCH=200`、`PERF_OUT=res://.godot/rts_profile_stress.json`，输出13秒预热/采样中的10秒窗口。运行前确认没有其他Godot实例；这是明确的合成压力布局。

[已审核QA](../qa/segment_navigation_20260906/README.md)保留成功日志、结果和源码/证据哈希。初次冻结函数提取及夹具编译失败已修正，不计入成功报告。
