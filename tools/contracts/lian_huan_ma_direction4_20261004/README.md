# 连环马原生输入与复现

16张原生透明RGBA、32独立姿态、20资源，像素由内置imagegen生成并原样保存。15张1254×1254，hurt_sw为1192×1320；元数据保留实际尺寸。

[jobs.json](jobs.json)与[generation.json](generation.json)保留完整提示词、SHA和实际引用链；[selection.json](selection.json)标明32姿态来源，[anchors.json](anchors.json)声明脚点/身体高度。[prepare.py](prepare.py)只读取alpha并生成元数据。6份必需原生父图保留generated/；实际引用的既有解析持械参考和生成器沿原工程路径核验。被拒绝候选的无引用像素不纳入生产，其提示词/引用/SHA与淘汰状态保留。

慢步抬腿方案被拒绝；最终两帧使用现行骑兵疾驰二次运动，伸展接触与后蹄蹬地/前腿收拢。不得根据失败候选宣称额外帧或高帧步态完成。

[来源审计](../../../qa/lian_huan_ma_direction4_20261004/source_audit.json)、[55产物重建](../../../qa/lian_huan_ma_direction4_20261004/reproduction.json)、[原生截图审核](../../../qa/lian_huan_ma_direction4_20261004/visual_review.json)。
