# 邹润SE短刀八帧攻击候选

本批是一个方向的动作来源及浏览器预览，未游戏采用。[第49回书证](canon_basis.json)只支持高大人形、脑后肉瘤和短刀；具体招式、步法、节奏、衣甲/发式/刀形均是美术解释，不新增剧情事件，不批准现有火箭/骷髅技能。前视自然遮挡后脑，本批没有解决既有后脑造型问题。

| 原稿 | 内容 | 原alpha完整取图 |
| --- | --- | --- |
| [attack_se_v1](native_originals/attack_se_v1.png) | 预备/蓄势/前切/收招 | 刀尖跨格，未过 |
| [attack_se_v2](native_originals/attack_se_v2.png) | 缩小留白后四主姿势 | 通过 |
| [transition_se_v1](native_originals/transition_se_v1.png) | 下沉/推进/撤刀/起身 | 通过，原稿体量偏大 |
| [transition_se_v2](native_originals/transition_se_v2.png) | 缩小后的四过渡 | 通过 |

四份1254×1254原PNG由内置imagegen生成，精确参数/父图/SHA在[prompt集合](prompt_set.json)。未本地裁切、清洗或重编码；后继不承诺未请求区域逐像素保持。完整取图只证明四个主分量在均分格内及所选采样边缘alpha=0，不证明全背景空：四稿分别保留674/740/1290/1397个极淡分量，max alpha1/2/2/1，不补签首攻击稿。

打开[八帧连播](browser/playback.html)，可播放、暂停、拖动时间；含待机→下沉→预备→蓄势→推进→前切→撤刀→收招→起身→待机。大图同一像素尺度0.7，右侧为48.1px方格尺度参考，下方八姿势静态对照。同一只右手持短刀、左手空；只按[人工后鞋参照点](attack_model_v2.json)平移，不逐帧缩放。后鞋单点对齐不等于完整鞋底接地、重心/体量/握持或方向过渡通过。

首套[四姿势连播](browser_four_pose/playback.html)实际运行6.4秒，录像6.371137秒/166帧。增加过渡后，未预热VP9录像首轮出现0.701秒帧间断，原执行源码/录像/探针及三次工具失败均按[旧批索引](previous_runs.json)保留在工程外受控目录，不当作后继通过。最终VP8先预热约2.2秒，再实际跑8.4秒，录像总长10.567692秒/302帧，正式段最大PTS间距0.038秒；仍不是每个编码帧与性能时钟精确对齐的证明。

最终十阶段截图及历史图与已目检前批逐字节一致，最终视频2.55/3.05秒解码图另已目检。[来源/时序/实际Canvas float32矩阵及媒体复核](playback_verification.json)只覆盖显示选择、阶段采样与人工点的非零舍入误差；没有认定自然攻击或游戏战斗时机。[目检结论](visual_assessment.json)：下沉/起身比四姿势直接切换容易读懂，但服色、脸甲/体量、脚部姿态与离散切换仍需统一。仅SE方向，不能视为完整四向动作链；走路/受击/倒地、后脑、小尺寸身份、Unit/HUD/原生/包内/性能仍待完成。

```powershell
python -X utf8 -B qa/zou_run_short_knife_attack_20261019/record_and_check.py --set attack_se --version v3 --original <新内置PNG>
# 过渡原稿使用 --set transition_se，已有版本不可覆盖。
python -X utf8 -B qa/zou_run_short_knife_attack_20261019/render_attack_with_transitions.py --deps <既有私有Playwright依赖> --output <全新工程外目录> --browser-exe <既有Edge路径>
```

浏览器录画布不依赖Playwright额外ffmpeg下载，系统现有ffprobe/ffmpeg只用于媒体探针和解码QA，不修改角色PNG。浏览器使用独立profile，自己的进程已结束；依赖/profile/可执行文件不入Git。129个生产文件、16个贡车文件、81个无关文件、HUD及26份待验证文件保持原哈希。原Godot单队列与外来占用不动；生产采用0，main/Steam不变，全库美术目标继续。
