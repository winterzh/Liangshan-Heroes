# 邹润后脑返修与四向鞋底参照预览

本轮只交付来源候选和实际静态比较，未替换游戏。书证复用第49回“身材长大”“脑后一个肉瘤”及“邹渊、邹润各拔出短刀在手”；[行号/原文哈希](canon_basis.json)与原始章节保留。准确发式、服饰、肉瘤大小、刀形和站姿为美术解释，不增加剧情或批准现用骷髅等技能。

| 原稿 | 本轮变化 | 完整取图 | 目检结论 |
| --- | --- | --- | --- |
| [v4](native_originals/idle_v4.png) | 编辑v3后脑 | 通过 | 圆珠变发结，解剖未接受 |
| [v5](native_originals/idle_v5.png) | 加头像参照再编辑 | 未过 | 圆珠返回，人物扩大跨格 |
| [v6](native_originals/idle_v6.png) | 不引用旧身体的独立构图 | 未过 | 露出后脑皮肤，四格拥挤 |
| [v7](native_originals/idle_v7.png) | 编辑v6缩小留白 | 通过 | 皮肤轮廓更清楚，仍偏球状 |

四份1254×1254内置imagegen原PNG逐字节复制，没有本地绘图、裁切、清洗或重编码。所有精确参数、父图哈希在[source/prompt集合](prompt_set.json)。工具要求保留区域不构成逐像素不变承诺。`frame_check_idle_v*.json`只检查原alpha>0四主分量归属及所选矩形边缘alpha=0。v7仍有1914个max alpha2的极淡分量，不声称整张背景绝对空；v5/v6失败记录不由后稿补签。

直接打开[原图/头部比较](browser/comparison.html)、[四轮历史](browser/history.html)、[交互鞋底参照预览](browser/registration.html)。[三张实际截图](browser/receipt.json)均已目检，来源在浏览器实际解码并核对SHA；预览实际点击SE/SW/NE/NW四次。[鞋底点](sole_references.json)是人工美术参照，其两点中点只用于平移候选；所有方向使用同一0.45或48.1/627尺度，没有逐方向包围盒归一化。

上排保留统一方格锚，中排平移到鞋底参照中点，下排固定48.1px方格尺度参考；可点按钮放大查看某方向。[实际Canvas矩阵](browser/draw_receipts.json)及[独立复核](registration_verification.json)保留float32误差，不宣称精确零漂移。鞋底参照不是物理地平面、骨骼、接触解算或游戏生产锚。后脑形态、小尺寸身份、体量、真实Unit/HUD、自然动作、完整走/攻/伤/倒地、原生/包内/性能仍未通过；仅四向待机来源。

```powershell
python -X utf8 -B qa/zou_run_canon_body_refine_20261019/record_and_check.py --version v8 --original <全新内置生成PNG>
# 独立构图另传 --intent new_four_direction_short_knife_body；不覆盖已有版本。
python -X utf8 -B qa/zou_run_canon_body_refine_20261019/render_registered.py --deps <既有私有Playwright依赖目录> --output <全新工程外输出目录> --browser-exe <既有Edge路径>
```

浏览器使用独立profile，退出后确认自己的进程已结束，不访问用户登录态；依赖、profile和可执行文件不入Git。129个生产文件、16个贡车文件、81个无关文件、HUD及26份待验证文件哈希保持。Godot单队列和外来占用标记未改，未把静态浏览器结果写成原生通过；[核验范围](verification.json)、[目检边界](visual_assessment.json)与[保护后验](preservation_after.json)分别留档。
