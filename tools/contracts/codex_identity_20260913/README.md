# 四人图鉴肖像：原生来源合同 · 2026-09-13

四张独立肩胸肖像沿原 `portraits_sheet.png` 手绘历史插画风格：暖灰褐纸底、柔和左上光、略三分之四视角、无文字和边框。内容已由制作代理、原著审查代理与主任务逐张目检接受为接入候选；最终UI裁切、文字遮挡与显示效果由主任务原生验证。

| 人物 | 选定生成稿 | 采用路径 | 已落实身份要点 |
|---|---|---|---|
| 宋江 | song_jiang_v2 | assets/characters/codex_portraits_20260913/song_jiang.png | 深暖褐面、宽额、厚耳垂与短须，金褐衣/黑围巾协调当前战斗 |
| 林冲 | lin_chong_v1 | assets/characters/codex_portraits_20260913/lin_chong.png | 有力宽颌、警觉眼与浓黑髭颏须，当前束发、黑金甲、蓝领巾 |
| 扈三娘 | hu_sanniang_v2 | assets/characters/codex_portraits_20260913/hu_sanniang.png | 较白净面容、双金钗、红纱与银灰金边甲、肩后两刀柄 |
| 孙立 | sun_li_v1 | assets/characters/codex_portraits_20260913/sun_li.png | 宽暖淡黄面、浓黑络腮须、红抹额、黑金甲与刚性分节钢鞭，纠正旧肖像兽角/软鞭（当前战斗硬鞭已正确） |

目标为1024方肖像；内置工具实际均输出1254×1254 RGB原PNG，故保留原字节，由Godot的`process/size_limit=1024`和mipmaps完成导入，不进行程序缩放、抠图、改色或画帧。本合同生成时实际导入尺寸仍待主任务回读，不冒称已得到1024原生输出。

`generation.json` 保留6次内置生成/编辑的精确提示词、原始工具文件路径、PNG SHA、每次引用的source SHA与prior-job链；七份旧图参考复用既有项目路径并锁定SHA，不重复拷贝公共图集。非生产中间稿在 `native/`，只含扈三娘顶发触边的v1和宋江肤色偏浅/须偏厚的v1，供来源追溯；生产仅四张选定PNG。`prompts/`是实际提示词副本，`portrait_manifest.json`声明选定源及1024导入要求。

一手事实与设计分开记录在 `source_identity_review.md/.json`，具体候选目检在 `candidate_portrait_review.md/.json`。宋江金褐衣与黑头巾、林冲本批黑金甲/束发、扈三娘银灰甲材质和刀柄携带布局均是与游戏协调的设计，不称原著唯一装束；孙立的哑光幞头不称精确铁质复原。肖像局部枪杆也不证明整条丈八蛇矛形状。未编造面部伤疤或四人的固定数值年龄、身材数据。

原著依据为百二十回本第7、18、48、49、55、63回；来源链接与原文定位均在上述一手审查记录。本次图像制作没有Godot操作、共享源码修改或发布；由主任务负责实际导入、路由、图鉴介绍和Git收尾。

## 接入回读（2026-09-14）

四图标准导入实际为1024×1024，原图仍为1254原始字节。最终图鉴批20260914_000243_5729cec4已1859项headless及1880项原生通过；具体截图与人工目检见[QA](../../../qa/codex_identity_20260913/README.md)。本目录portrait_manifest中的null/false是生成交接时状态，最终接入状态由此QA收据证明，未回写篡改生成时记录。
