# 刽子手四向动作来源

本批由内置image_gen生成/编辑。全部提示词、原始输出文件名和参考链保留于`jobs.json`、`jobs_extra.json`及带哈希的`generation.json`；选中原生RGBA位于`assets/characters/guan_zhanzi_direction4_20260915/`，中间与退回稿在本目录`generated/`。原图字节保持不变。

`prepare.py`用于复制本任务imagegen原始输出并重建元数据，依赖原始生成目录；跨设备验证使用已入库的生产PNG及generation.json，不要求该本机目录存在。它不画图，不清alpha，不镜像。已由Godot规范化的import UID保留；所有纹理实际尺寸仍须原生检查。

四张主体atlas加收步/背向落地补充atlas，以及三个独立动作（东北失衡、东南举刀、东南受击），共32个独立姿态。被换下的格子在manifest的unused_regions中保留理由；其非透明前景与采用格子须被完整、不重复地核算。

```powershell
py -3 -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/guan_zhanzi_20260915.json
py -3 -X utf8 -B tools/directional_character_sources.py assets/direction4/guan_zhanzi_20260915.json tools/contracts/guan_zhanzi_direction4_20260915/generation.json --out qa/character_art_20260915/sources.json
```

第一条默认只读比对，`--write`才重建20个TRES。第二条只读核验PNG与资源，写独立JSON；不能代替人体、朝向和实机画面的人工审查。实际结果见[实现](../../../docs/CHARACTER_ART_20260915.md)和[QA](../../../qa/character_art_20260915/README.md)。

独立图鉴/HUD肖像的两次生成与退回原因、参考哈希另见`portrait_jobs.json`和`portrait_lineage.json`。v1因面貌过近林冲退回；v2采用，PNG原字节保留。
