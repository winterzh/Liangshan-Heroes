## 2026-10-19 本轮新增7原稿，单向四阶段进入原生比较

当前以prompt_set_v2.json为准：12份内置原PNG，SE选contact_a_se_v3/passing_a_se_v4/contact_b_se_v1/passing_b_se_v1进入比较；SW只选contact_a_sw_v1/contact_b_sw_v1继续。共6份原稿退回，SE passing A经历错误前腿、缺腿后修正；SW passing A前腿相位仍反，下一步须返修，passing B仅已准备关节图、未生成。NE/NW仍未资格化。

native_se_v1/actual_failed保存首次默认导入的7项RGBA失败。native_se_v2显式采用项目已用的lossless/fix_alpha_border=false/mipmaps=true设置，PNG与驱动断言保持；导入/原生退出0，45项/4截图全部直接查看，process真实顺序换相16次。对照马与骑手不逐帧包围盒拟合，位置/比例固定，缰绳在运行时使用原绘制带材。只证明单向素材可导入/叠合并循环渲染；自然连续步态、脚滑/接触、骑手起伏、其他方向、实际Unit/章回/PCK与性能仍待做，采用0。129运行/16保护/81外来/HUD保持。下文5份/仅接触姿势为此前历史。

# 公孙胜黄花马：先修正对角支撑，再补连续步态

内置 imagegen 已生成5份1254×1254原始RGBA PNG，均在native_originals/，准确实际工具参数、参考图SHA与原始保存位置见prompt_set.json、tool_prompt_*.json及source_*.json。无本地像素修改。horse_contact_a_v1/v2的支撑仍像同侧前后腿，退回，不能改称侧对步来冒充目标对角小跑。passing_a_se_v1把应前摆屈膝的近前腿画成向下前伸，未按所需对角过渡完成，亦退回。

后继缩小为仅返修左上SE视图。horse_contact_a_se_v3可辨远前腿与近后腿着地、另两腿抬起；horse_contact_b_se_v1改成近前腿与远后腿着地，支持对角互换。两图仅SE进入下一轮比较，不核准其他三个保留视图。头颈、鞍具、躯干及绘画边缘仍需固定坐标叠合检查；未取得原生纹理、骑手/缰绳配合、连续运动或实际Unit资格，也尚未生产采用。

se_contact_a_pose_guide和se_contact_b_pose_guide是代码编写的QA矢量标注，经独立Edge无头档案渲染，作为生成器关节/蹄位置参考。它们不是生产绘画，不得放入游戏；原底图逐字节保持。两份引导图/原SVG/命令回执保留，最终生成图没有引导文字和彩线。

第54回黄花马身份沿用相邻mounted_topology/source_basis.json。小跑、步幅、鞍具色彩是游戏美术解释，不是原文明确步态，不添加剧情、法术或伤亡。后续补SE过渡帧、其余方向及骑乘衔接，并继续所有人物、场景、战船、特效、UI、性能。当前只是单向两接触姿势来源进展。
