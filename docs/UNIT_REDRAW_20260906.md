# 合并物理追帧期间的单位重绘

2026-09-06，基线 `57e2512db918498f2950c7669cd2bf6863e2265e`，已包含另一任务的宋江四向站立、行走、攻击与死亡资源。生产只改 `scripts/unit.gd` 的重绘请求调度。

此前在 `8bc2249` 的实际渲染诊断中，慢画面前有7～8次物理更新；单张画面前 Unit 绘图655～774次，累计约28～40ms。Godot会在物理更新间清空延后调用队列，因此反复 `queue_redraw()` 仍可能在一次出画面前重建多遍Canvas命令。诊断计时有包装开销，不作为正常战斗帧率或互斥CPU占比；原始逐帧记录单列于本批QA。

新 `_request_redraw()` 在物理阶段将原生 `queue_redraw` 作为一次性回调连接到 `SceneTree.process_frame`，重复请求共用这一连接；物理更新完成后、该次画面的普通处理开始前，提交最终状态的重绘。非物理阶段或尚未入树的请求沿用原生队列。没有常驻逐帧回调或全局单位引用列表，节点释放由信号连接的对象生命周期处理。

替换52处自身请求及3处搭档/维修建筑请求。战斗运算、命中时点、移动、动画时钟、物理频率、迷雾、现有稀疏重绘条件与实际 `_draw` 内容保持；机械反向还原与基线Unit源码逐字节规范化对照一致。外部直接调用原生 `queue_redraw()` 仍可请求重绘，本改动不承诺所有来源绝对每帧只调用一次。

[SceneTree 4.6文档](https://docs.godotengine.org/en/4.6/classes/class_scenetree.html#class-scenetree-signal-process-frame)说明 `process_frame` 位于节点普通处理前；[CanvasItem 4.6文档](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html#class-canvasitem-method-queue-redraw)说明重绘进入延后队列。本项目的追帧调用次数另以实际引擎测量和回归为据。

## 验证与效果

`tools/unit_redraw_qa.gd` 用两个实际SubViewport逐帧比较同一份Unit绘图代码：参照对象只将新调度入口恢复为原直接队列。15FPS上限用于有意触发60Hz物理追帧；这是可视状态夹具，不是正常游戏性能窗口。

- 42项通过。宋江行走、出剑、死亡、绑缚变体，以及刀兵、花荣、箭楼起火、林木采集8类状态，共64张画面、6,553,600个RGBA像素精确一致。
- 254次实际物理更新中，参照绘图254次，新调度64次。每张画面的最终动画时钟、方向、生命、选中、攻击、死亡和变体状态均即时到达绘图，未沿用上一张画面的状态。
- 暂停时选择、物理请求后立即暂停、隐藏后显示、移出后重新入树、待重绘时释放、入树前请求、整场景释放及玩家存档字节保持均通过。
- 宋江实际四向移动、近战命中、死亡、剧情变体与资源隔离250项通过，并保存真实Unit动作矩阵和近战画面。野猪林四条实际路线及边界107项、真实暂停菜单与场景切换55项通过。本批合计454项；详见[QA收据](../qa/unit_redraw_20260906/README.md)。

在同一基线资源下分别运行未经计时包装的200敌对6英雄实战窗口：1440×900、Forward+、RTX3070Ti、1倍速、预热3秒并采样10秒。前后分别297帧/10.007907秒与373帧/10.007059秒，即29.68→37.27FPS，P95 108.993→67.158ms，P99 165.985→104.512ms，最慢210.584→140.714ms。末段截图75FPS仅为瞬时值。

两场战斗的战损、镜头缩放与调度略有差异，以上是独立窗口观测，不能换算为稳定百分比增幅；全场性能仍不达60FPS目标。动作夹具也不代替真人观感、长时稳定性和完整战役验收。

## 复现

```powershell
$godotExe = (Get-Content -LiteralPath .\godot.local.txt -Raw).Trim()
& $godotExe --path . --script res://tools/unit_redraw_qa.gd
$env:SJ_VISUAL='1'
$env:SJ_QA_OUT='res://.godot/unit_redraw_song'
& $godotExe --path . --script res://tools/song_jiang_direction4_qa.gd
$env:YF_CASE='all'
$env:YF_VISUAL='1'
& $godotExe --path . --script res://tools/yezhulin_short_test.gd
& $godotExe --path . --script res://tools/pause_menu_qa.gd
$env:PERF_DEFENSE='1'
$env:PERF_OUT='res://.godot/unit_redraw_after.json'
$env:REDRAW_SCREENSHOT='res://.godot/unit_redraw_after.png'
& $godotExe --path . --script res://tools/unit_redraw_stress.gd
```

逐帧对照和压力入口拒绝headless及fixed-fps；测试输出在忽略的 `.godot/`，本批冻结证据在 `qa/unit_redraw_20260906/`。运行前检查其他Godot实例，避免压力计时互相干扰。源码启动配置不变；当前增量随既定stable分支同步，不是发行发布。
