# 孙立四向基础动作来源

`generation.json`保留既有归档参考链与本轮内置image_gen提示词。11张生产原生RGBA位于`assets/characters/sun_li_direction4_20260913/`，其中6张复用旧RGBA、5张本轮生成。旧36张草稿及姿态参考保留在相邻`sun_li_direction4_draft_20260906/`，没有改写或删除。

`pose_recipe.json`记录32个原生姿态的矩形、地面锚点与排帧依据；实际导入尺寸、运行采样、尺度和状态顺序以`assets/direction4/sun_li_20260913.json`为准。东南同相马步和西南旧串格动作已明确退回；西南、西北仍是前腿变化较弱的低帧基础步态，不按完整高帧跑马宣传。

所有PNG保持原字节。导入缩放、mipmap、AtlasTexture采样与透明留边通过Godot资源元数据实现，没有本地抠图、镜像、绘制或重新编码原图。`generated/`保留本轮记录中的中间/退回输出，其被引用路径与SHA由来源审计核对，不进入游戏取图。

从工程根目录复核：

```powershell
py -3 -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/sun_li_20260913.json
py -3 -X utf8 -B tools/directional_character_sources.py assets/direction4/sun_li_20260913.json tools/contracts/sun_li_direction4_20260913/generation.json
```

第一条只读比对20个TRES；显式追加`--write`才重建清单列出的资源。第二条使用Pillow核验原生来源、透明通道、导入和可见串格；不自动判断人体、武器手和步态。生产结果、原生运行与目检边界见[本批说明](../../../docs/CHARACTER_ART_20260913.md)及[QA](../../../qa/character_art_20260913/README.md)。
