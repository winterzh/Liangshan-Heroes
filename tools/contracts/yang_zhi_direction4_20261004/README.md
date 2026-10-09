# 杨志通用四向原生来源契约 · 2026-10-04

23 张生产原生 RGBA、32 个独立姿态、20 个五状态四向 TRES。沿用当前对齐头像、近战步兵数值和技能。所有 PNG 保留生成器输出原生字节，没有镜像、裁切、缩放、抠图或本地重绘。

- [jobs.json](jobs.json)：每次生成的完整提示、原生 SHA 和引用；拒收未引用图仅保留记录，不是生产素材。
- [generation.json](generation.json)：生产图、6 张必须保留的编辑父图、28 张确定性 3D 姿态参考及其生成源码 SHA 的可移植引用链。3D 参考只定义解剖学左右、步态和相机，不作为生产位图。
- [selection.json](selection.json)：32 个姿态到原图的明确选择；部分四格图的拒收区域由 manifest 单独记录，不能算成新增合格姿态。
- [prepare.py](prepare.py)：只读取原生像素作透明留边核验及采样元数据计算，复现 manifest 和来源链。图集使用真实透明横/竖间隔分格，单图使用原生全画布及虚拟方形留白；不写 PNG。

```powershell
python -X utf8 -B tools/contracts/yang_zhi_direction4_20261004/prepare.py
python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/yang_zhi_20261004.json
python -X utf8 -B tools/directional_character_sources.py assets/direction4/yang_zhi_20261004.json tools/contracts/yang_zhi_direction4_20261004/generation.json
```

日常游戏不依赖 Python、Pillow、Codex 原始生成目录或上述 3D 引擎参考。已保留的仓库字节是复现校验依据；只有仓库输入缺失时才需原始生成路径恢复。本批实际游戏验收状态见 [QA](../../../qa/yang_zhi_direction4_20261004/README.md)。
