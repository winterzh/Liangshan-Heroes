# 花荣通用四向来源契约 · 2026-10-04

14 张生产 PNG 保留内置 imagegen 原生 RGBA 字节，32 独立姿态、20 TRES。六张四格来源用于待机、交替步态、受击、倒地和躺卧；八张独立单幅用于四方向的拉弦与松弦。沿用项目银甲白衣对齐头像，不改现有步兵/远程玩法。

- [jobs.json](jobs.json)：全部原始提示、生成输出位置与实际引用。
- [generation.json](generation.json)：生产 SHA、生成标识、接受/拒绝状态与引用链。仅生产引用链需要的拒绝父图在 generated 中保留；无引用的候选另行归档。
- [prepare.py](prepare.py)：复制原生字节、只读 alpha、生成采样/脚点/尺寸元数据，不写图片像素。首次 import UID 在工程外隔离导入。
- [manifest](../../../assets/direction4/hua_rong_20261004.json)：每个原图的尺寸、区域和状态帧序。

西北起手由一次要求东北的编辑产出，但实际画面朝西北，因此按实际方向选入 windup_nw，未把错误朝向写成东北验收。东北起手经独立重画与双臂纠正后另行接入，准确原提示均保留。

复现需要 Pillow，游戏正常启动不需要。执行 prepare 后使用 tools/build_directional_spriteframes.py 默认只读比较；tools/directional_character_sources.py 可检查原字节、引用链与透明采样。当前原生与画面验收进度见 [实现](../../../docs/HUA_RONG_DIRECTION4_20261004.md)。
