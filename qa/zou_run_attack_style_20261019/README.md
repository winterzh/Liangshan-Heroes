# 邹润SE八帧脸甲/材质统一候选

用内置imagegen分别编辑[四主姿势](native_originals/attack_se_v3.png)和[四过渡](native_originals/transition_se_v3.png)，把鲜红布料、光滑脸部和较粗甲片改得更接近既有待机的暗红布/哑光褐皮甲/成熟五官。两份1254×1254原PNG、精确参数/父图哈希均保留在[prompt集合](prompt_set.json)，无本地绘图、裁切、清洗或重编码。

第49回只支持人形、脑后肉瘤、短刀；具体五官/服饰/刀形/编排仍为美术解释，不新增剧情或批准现用骷髅技能。前视可自然遮挡后脑，本批没有解决其圆珠感或新增原著事实。[书证复用](canon_basis.json)含原文行号与哈希。

两图四主分量均归属各自均分格、选定采样边缘原alpha=0；极淡分量仍保留，数量与max alpha见[来源检查](verification.json)。这个范围不证明全背景空、姿势保持或自然动作。编辑实际改变了轮廓和大小，不能把提示里的“保持”当成执行结果。

打开[新旧双列共时钟比较](browser/comparison.html)：左侧旧候选、右侧本轮；可播放/暂停/拖动阶段，下方各列八姿势。为抵消编辑使整组放大，以八个同姿势原alpha身体高度比的中位数[0.9037146998419183](pack_scale_candidate.json)为新攻击/过渡整组共用显示比例，待机仍用原尺度。没有逐帧包围盒缩放，亦不宣称物理体量通过。撤刀高度比偏离较大，经统一比例后仍偏高，详见[各姿势残差](playback_verification.json)。鞋底点重新人工选择，单点对齐不等于整鞋接地。

实际正式段8.4秒，录像预热后共10.573394秒/299帧，正式段最大PTS间距0.038秒；十阶段截图、最终2.55/3.05秒解码图均目检。[实际来源SHA、紧凑逐帧阶段记录、阶段改变时的Canvas矩阵](browser/receipt.json)与[独立复核](playback_verification.json)只证明来源选择、阶段采样、统一比例与人工点的非零舍入误差，不证明每个编码帧与性能时钟精确对应，也不认定自然攻击、握持或体量一致。

[目检](visual_assessment.json)确认风格方向改善，但撤刀偏高、肩手/脚部衔接和离散切换仍待修。仅SE候选；完整四向/其他动作、后脑、小尺寸识别、Unit/HUD、原生/包内/性能尚未完成，生产采用0。

```powershell
python -X utf8 -B qa/zou_run_attack_style_20261019/record_and_check.py --set attack_se --version v4 --original <新内置PNG>
# 四过渡使用 --set transition_se；不得覆盖已有版本。
python -X utf8 -B qa/zou_run_attack_style_20261019/render_compare.py --deps <既有私有Playwright依赖> --output <全新工程外目录> --browser-exe <既有Edge路径>
```

浏览器独立profile和依赖留工程外，自己的进程已结束；ffprobe/ffmpeg只探针/解码录像，不改角色PNG。129生产/16贡车/81无关文件、HUD与26份待验证文件哈希保持。未启动Godot或修改租约/其他进程；[原生只读观察](native_observation.json)记录旧等待PID缺失和观察时外来运行状态，不将陈旧状态文件当存活队列或原生通过。main/Steam未改，全库美术目标继续。
