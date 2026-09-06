# 自然地表图集透明缝修复

2026-09-06，接续 `661e8d1`，在独立worktree处理地面渲染。祝家庄、大名府和其他关卡原图中的周期性斜向细缝来自旧图集的透明边缘，没有修改生产PNG、地图、碰撞、寻路、任务或兵种。

## 原因与修复

自然地表按地图范围采样新材质，但提交地面网格时仍附带旧atlas。Godot4.6的fragment输入 `COLOR` 已乘过默认纹理，包含其透明度；旧shader以 `COLOR.a > 0.99` 决定是否绘制自然地表。图集边缘过滤到透明像素时，地面出现细线并漏出旧图集颜色。相关语义见 [Godot4.6 CanvasItem shader文档](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/canvas_item_shader.html#color-and-texture)。

先在同一祝家庄场景、150%缩放做诊断，只切换“恢复图元透明度”。去掉人物/场景遮挡后的2,676个变化像素全部与旧atlas透明度下降位置重合，透明度正常处0像素改变。原截图中的其他场景细线不在这份地面遮罩里，没有声称全部清除。

生产改动仅 `scripts/liangshan_coast.gdshader` 的8行：vertex保存图元/CanvasItem原本的alpha，fragment只在自然地表开启时恢复该alpha。没有强制所有绘制都变成不透明；顶点半透明和CanvasItem自身淡化仍生效。旧地表模式完全沿用原输入，岸线与人工结构的规则不变；没有增加pass、网格或绘制调用。

## 验证范围

- 实际GPU的RGBA夹具复现旧alpha `[0.25,1,0.125,0.5]`，修复后为 `[1,1,0.5,0.5]`；节点透明度0.6时保持 `[0.6,0.6,0.3,0.3]`（8位量化容差0.02）。关闭自然地表时新旧输出逐像素相同。
- 八关同场景、同镜头旧shader→新shader→恢复，1280×720；祝家庄和大名府额外150%缩放。86项通过，恢复像素一致、draw calls一致、地图/碰撞/占地/高度/地表遮罩和存档不变。
- 原八关自然地表90项契约通过，覆盖三种移动配置、寻路权重、地图遮罩确定性、硬边与高度规则。静态路由790、运行路由794、环境工具40项反例通过；37张已有生产图哈希一致，32缺图和249项素材/来源缺口保持，整体审计仍退出1。

已查看各关画面，地表斜向分块线消失，人物、地形边界与道路保持可辨。黄泥冈冻结夹具边缘的车队白块在旧shader图中也存在，尚未确认普通运行是否复现；本批未改角色/车辆素材。冻结场景、隐藏HUD及迷雾覆盖层的对照不是实战或帧率验收，未代替真人画面评价。

## 复现与证据

本机Godot路径仍按 [SOURCE_SETUP](SOURCE_SETUP.md) 配置，首次完成导入后：

```powershell
& $godotExe --path . --script res://tools/terrain_alpha_seam_probe.gd
& $godotExe --path . --script res://tools/terrain_alpha_seam_qa.gd
$env:NATURAL_TERRAIN_OUT = Join-Path $PWD '.godot/terrain_alpha_seam_qa/natural_contract'
& $godotExe --headless --path . --script res://tools/natural_terrain_contract.gd
```

前两项必须使用真实渲染器，分别输出 `.godot/terrain_seam_probe/`、`.godot/terrain_alpha_seam_qa/`。检查退出码和日志，不能忽略 `SCRIPT ERROR` / `ERROR:`。旧shader来自Git提交 `661e8d1`，冻结于 `tools/contracts/terrain_seams/before_661e8d1.gdshader`，SHA由测试单独固定；不能用当前代码自动重建“改前”条件。该目录含 `.gdignore`，不作为运行时素材导入。

通过日志、八关前后图、原始诊断、输入哈希见 [QA](../qa/terrain_alpha_seams_20260906/README.md)。按既定开发分支同步源码与证据，没有导出、Steam写入或发布。

提交 `a851bb0` 在专用干净Git检出中另行核验42/42输入、41/41证据字节及三个Python入口0/1/0退出码，执行前后工作区干净且没有Godot资源导入缓存。该检查复用本任务创建的验证目录，不删除先前忽略的验证器临时报告；没有在该目录重复GPU验收。
