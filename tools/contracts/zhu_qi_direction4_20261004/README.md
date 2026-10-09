# 祝家马军原生四向契约 · 2026-10-04

八份原生RGBA、32姿态、20资源已完成基础原生验收。当前portraits5底行左格身份及普通近战骑兵数值保留；新枪帧不改变range26对应的原有命中时点。全部PNG内置imagegen生成/编辑，不本地变换像素；旧PNG保持来源，TRES专门优先。jobs.json留存全部提示、实际引用和SHA；未用失败步态保留记录但不上传原图。

prepare.py只读alpha和写采样/脚点元数据，不写生产位图。重建：

```powershell
python -X utf8 -B tools/contracts/zhu_qi_direction4_20261004/prepare.py
python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_qi_20261004.json --write
```

最终动作、握点、脚点、命中、HUD/图鉴和实际章节演员以[本批QA](../../../qa/zhu_qi_direction4_20261004/README.md)为准；本批已完成基础原生和32张画面验收；未打包发布。候选记录保留生成时审核状态，最终以QA截图SHA和visual_review为准。
