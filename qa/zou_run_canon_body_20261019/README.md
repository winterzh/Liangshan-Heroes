# 邹润四向短刀待机原稿

内置imagegen新增三轮四向原PNG与精确参数，均按原字节保存，没有本地裁切、缩放、镜像、alpha清洗或重编码。姿势只有待机，不是行走或完整动作链。

| 批次 | 原稿 / 精确参数 | 原始检查及结论 |
|---|---|---|
| v1 | [PNG](native_originals/idle_v1.png) / [提示](tool_prompt_idle_v1.json) | 三个方向跨627均分格，另一个采样边界不清；保留失败 |
| v2 | [PNG](native_originals/idle_v2.png) / [提示](tool_prompt_idle_v2.json) | 留白修正，四格完整主体/原alpha采样边界通过；脑后仍像金属珠 |
| v3 | [PNG](native_originals/idle_v3.png) / [提示](tool_prompt_idle_v3.json) | 四格取图通过，后脑颜色改变但形态仍偏圆珠，解剖表现未接受 |

[实际来源比较页](intake/intake.html)、[截图](intake/intake.png)及[三轮历史](intake/history.html)可直接打开。分格线只为浏览器QA叠加，不写进原图。后继结果不补签v1。

## 原著与当前差异

沿用已实际取得的第49回完整文本：邹润为人形、身材长大、与叔叔年纪相仿，**脑后**有肉瘤；叔侄拔短刀。引文/行号与前批原文摘要重新核对，未重新联网抓取，见`canon_basis.json`。

新稿额前无尖角，单手持一把短刀、另一手空，红衣褐甲/绑腿/低鞋与既有身份参考接近。现用走图仍是额前突出、长柄刀，游戏资源没有因此改变。具体衣甲、须发、刀形、肉瘤大小及站姿为美术解释，不把本图当某次剧情事件的精确服装，也不批准当前骷髅/火箭技能或所有章回兵器。

三轮原图与两张实际静态截图已直接目检。后继来源可继续比较单短刀/无额前角，但后脑仍偏独立圆珠，不能称肉瘤解剖已合格。四方向原始脚部像素下界相对各格不一致，尚未脚底配准、接地或体量验收；页面使用同一627方格和48.1像素参考，不用逐方向包围盒缩放掩盖。

## 通过范围

`frame_check_idle_v*.json`按原alpha>0连通主体确认一人一格并检查采样边界。v2/v3通过仅代表完整取图；v3仍有240个极淡额外分量、最大alpha1，原样保留，不称全图完美无杂点。来源资格不证明姿势自然、兵器握持、身体比例或所有动作。

隔离已有Edge/私有Playwright 1.64.0实际显示比较页/历史页，分别解码3原图并核对WebCrypto SHA、DOM11/3显示实例，1800×1200及1800×710截图全目检；页面错误0，本次profile进程已退出。依赖/profile不进Git，没有修改用户登录profile或系统配置。

生产采用0，没有Godot、真实Unit、图鉴/HUD、包内、性能或完整动作资格。129/16/81与HUD及26份其他待验证文件保持，原Godot单一等待队列和外来占用标记未改，全库人物动作/场景/船只/特效/UI/性能继续，main/Steam未操作。

```text
python -X utf8 -B qa/zou_run_canon_body_20261019/render_intake.py --deps <私有Playwright目录> --output <全新工程外目录> --browser-exe <已有Edge路径>
```

需已有Pillow/Playwright；首轮来源检查另用numpy/scipy。`record_and_check.py`为逐原稿首轮入库/诊断入口，拒绝覆盖已有源文件。浏览器重放只写全新工程外目录；原始HTML/截图/收据/执行器按字节归档，见`archive_index.json`。
