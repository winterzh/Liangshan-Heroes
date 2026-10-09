# 钩镰手原生输入与复现

生产像素均由内置 imagegen 生成并原样复制，13张1254×1254透明RGBA，32独立姿态；未以本地图片处理制造面向或换腿。

完整提示词、原生SHA和实际引用链见 [jobs.json](jobs.json)、[generation.json](generation.json)；选图见 [selection.json](selection.json)，脚点/身体高度声明见 [anchors.json](anchors.json)。五份必需原生父图保留在 generated/，三张从空白画布绘制的解析几何参考及生成器保留在 guides/，所有实际参考列入来源核验。拒绝候选仅保留提示词、SHA、引用与淘汰原因。

用 Python/Pillow 执行 [prepare.py](prepare.py) 只读取原生 alpha、重建元数据；现有通用 SpriteFrames 生成器按清单重建20TRES。不得重新绘制/覆盖生产原图。已执行 [49产物零漂移复现](../../../qa/gou_lian_direction4_20261004/reproduction.json) 与 [301项来源核验](../../../qa/gou_lian_direction4_20261004/source_audit.json)。实际32姿态和33原生截图见 [审核](../../../qa/gou_lian_direction4_20261004/visual_review.json)。
