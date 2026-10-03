# 关胜原生骑乘四向来源

本批使用内置 imagegen 生成原生 RGBA；17生产源、32姿态、20资源经原生游戏与直接画面验收；结果见[本批QA](../../../qa/guan_sheng_direction4_20261004/README.md)。

沿用当前 aligned 头像的红脸长须、绿巾绿袍、金铜甲和青龙偃月刀，以及 defs 的近战骑兵类型、数值与技能。栗色马、绿鞍布与铜饰为游戏骑乘绘制解释，不声明原著马匹考据。旧关胜身体提供身份/画风；呼延灼待机图只提供骑乘相机和绘制风格，不继承其人物或兵器。

待机四向、步态 A/B 八姿态、蓄力/打击八姿态、受击四向、倒下/末态八姿态共 32 姿态。原生候选逐方向审核，不将镜像或同一腿部姿势算作另一独立姿态；攻击恢复复用待机、末态重复只分配时间。左右手定义一致：左手前握、右手后握；倒下允许一手放松。

`jobs.json`、`generation.json` 和 `selection.json` 记录完整提示、原生 SHA、选择及便携引用链。新增数学几何图只是手臂、马腿和相机参考，Pillow 在全新画布上绘制几何投影，不读取或改写任何生产位图；相应生成源码与版本 SHA 随实际引用留存。生产 PNG 只按原字节复制，未本地缩放、翻转、抠图或重画。

`prepare.py` 只读 alpha、生成区域/虚拟留白/脚点元数据及 import 描述符，不修改 PNG 像素；Godot 首次隔离导入后分配 UID，再冻结复验。资源生成/只读复现使用：

```powershell
python -B tools/contracts/guan_sheng_direction4_20261004/prepare.py
python -B tools/build_directional_spriteframes.py assets/direction4/guan_sheng_20261004.json
```

正常游戏不依赖 Python、Pillow、原始生成目录或本机路径。基础低帧动作仍需原生图鉴/HUD、正常战斗及脚点审核，不等于关卡、性能或平台包验收。
