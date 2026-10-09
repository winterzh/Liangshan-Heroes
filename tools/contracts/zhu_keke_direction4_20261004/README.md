# 祝家庄客原生四向契约 · 2026-10-04

祝家庄客完成13张原生RGBA、32独立姿态和20个五状态四向资源的基础验收；按当前portraits5底行右格统一褐头巾、短须、褐衣围领、暗色札甲和右手单刀。所有PNG使用内置imagegen原生生成/编辑，未本地裁切、镜像、缩放或重画。第二步态交换前后腿；蓄势SW/NE、落刀SE/NW及SW倒地/终帧的手臂和朝向问题已返工。两份被后续生成实际引用的父图保留；被替代图集格明确标为未使用。49产物/20TRES字节复现与32留边通过。刀刃高于头部时仅通过只读身体锚点元数据保持身体大小，不改变原生像素。全部提示、原生SHA、实际引用链与选择保留在jobs.json/generation.json/selection.json；生产图13份，实际引用父图2份。

prepare.py只读alpha并写采样/身体比例/脚点元数据，不写生产PNG；运行游戏不依赖本机生成路径。重建：

```powershell
python -X utf8 -B tools/contracts/zhu_keke_direction4_20261004/prepare.py
python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_keke_20261004.json --write
```

最终动作、脚点、真实命中、HUD/图鉴及实际章内演员以[本批QA](../../../qa/zhu_keke_direction4_20261004/README.md)为准。基础原生及画面审核完成，未打包发布。
