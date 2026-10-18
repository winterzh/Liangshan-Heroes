# 杨林普通头像与笔管枪待机来源

2026-10-19内置imagegen制作三份原稿：普通近景头像、两版四向持枪待机。全部1254×1254，头像RGB暖纸背景、身体RGBA真透明；生成原文件与工程副本SHA一致，没有本地绘画、抠图、像素清洗或重采样。精确提示与输入角色见`prompt_set.json`。

原著第44回写杨林“头圆耳大，鼻直口方，眉秀目疏，腰细膀阔”，手提“一根浑铁笔管枪”。沿用已在获救身体上出现的头巾、短须、豹纹褐衣及白边，只是游戏美术解释，不能把“锦豹子”绰号说成原著指定豹皮衣，更不能画成兽人。暖纸纹只参考邓飞的风格，不借邓飞红眼、卷发、长须、铁链或脸型。书证复用已下载的同回原文，没有冒称再次联网核对；路径、SHA与当时获取时间见`canon_basis.json`。

首张`idle_v1`按627均分时可见前景到达中线，且有极淡杂点，不选用。`idle_v2`缩小四个完整人物后，主体已分开；原均分格的原始alpha边缘检查仍未通过。完整源码和失败结果保留在`source_inspection_v1/v2.json`，不回写为成功。

后继取图使用`selected_regions_v3.json`四个明确矩形，保留四个完整主体/枪的所有连通像素，取图区边缘alpha严格为0。初次矩形的两处极淡边缘命中保留在v2，v3将矩形各扩一列纳入原像素后再检查，没有改PNG或按阈值涂掉alpha。取图区之外不采样的408个孤立像素alpha均为1；原PNG仍完整保留，不能宣称整张图完全没有杂点。虚拟margin保持627格尺寸，不按包围盒逐方向改大小。

`review.png`是旧头像、新头像、现用无武器获救身体及四向普通持枪候选对比，`registered.png`进一步用人工双靴底中点作同尺度平移。两图已直接目检；人工点位误差约10源像素，不证明物理接地。后视枪杆下段受身体遮挡，长度连续性与握持还需动作链/原生核对；32px头像细节不作通过结论。

当前无生产采用，ArtDB旧头像、被缚/获救路由和全部玩法保持。普通持枪来源不能给获救状态添武器。现有技能含“手里剑”等词，第44回外貌/枪的书证不足以批准这些设定；见`skill_review_pending.json`，仍需跨章查证与后继修订。本批也没有完成行走、攻击、受击、倒地、实际Unit/图鉴/HUD、原生导入、包内或性能验收。

复现静态浏览器检查（输出目录必须全新，依赖Pillow/本机Edge；组件诊断另需NumPy/SciPy）：

```powershell
python -X utf8 -B qa/yang_lin_canon_sources_20261019/render_review.py D:/CodexEvidence/shuihu/yang_lin_canon_sources_20261019/review_replay
python -X utf8 -B qa/yang_lin_canon_sources_20261019/render_registered.py D:/CodexEvidence/shuihu/yang_lin_canon_sources_20261019/registered_replay
```

这两个工具默认只写新的工程外输出目录，不覆盖工程旧回执/截图；由既有`native_originals`、`selected_regions_v3.json`和项目原图重建来源。显式`--archive-to-project`仅用于首次归档，并拒绝覆盖现有文件。原归档SVG的`images/`相对链接由工具创建在私有输出目录，不能把裸SVG副本当成独立游戏入口。浏览器profile不进入Git。首轮已执行工具的快照保留在工程外`executed_tools_v1/`；当前可重放版本另有独立复现回执，不回写首轮记录。

独立重放的SVG两案相同，注册图PNG字节相同；来源对比图仅新头像32px方框有像素差异，原因尚未确定，整图字节一致性未通过。首个严格记录器`record_replay.py`的断言失败保留，不补签；`replay_result.json`和原样保存的`review_replay.png`记录差异范围。该图已再次目检，32px细节仍不接受；不因此重复生成或声称整图确定性通过。

其余来源/准备/收尾脚本均为单次记录器，禁止覆盖旧结果。`preservation.json`验证129运行文件、16保护文件、81外来文件与HUD未改；本批不影响原有公孙胜唯一原生等待队列。完整人物/场景/船只/特效/UI/性能美术目标继续。
