# 卢俊义通用四向原生来源契约 · 2026-10-04

19张生产原生RGBA、32独立姿态、20五状态四向资源。沿用银甲白披风、白羽冠和长须身份，以及当前持枪近战步兵参数。所有PNG保持生成器字节，没有本地像素变换；大名府被缚/获救资源继续独立优先。

- [jobs.json](jobs.json)：各次内置imagegen完整提示、原生SHA、引用及选用状态。未引用拒收图保留记录。
- [generation.json](generation.json)：可移植来源链，包含32张确定性3D参考和生成源码SHA；参考不作为生产素材。
- [selection.json](selection.json)：32姿态明确采样选择，部分图集拒收格在manifest中标明。
- [prepare.py](prepare.py)、[anchors.json](anchors.json)：只读alpha边界、真实透明间隔分格、AtlasTexture虚拟留白和身体/接地点元数据，不写PNG。

```powershell
python -X utf8 -B tools/contracts/lu_junyi_direction4_20261004/prepare.py
python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/lu_junyi_20261004.json
python -X utf8 -B tools/directional_character_sources.py assets/direction4/lu_junyi_20261004.json tools/contracts/lu_junyi_direction4_20261004/generation.json
```

日常运行无需Python、Pillow、原始生成目录或3D参考。仓库已保存原生字节用于复现校验。实际运行与画面验收见[QA](../../../qa/lu_junyi_direction4_20261004/README.md)。
