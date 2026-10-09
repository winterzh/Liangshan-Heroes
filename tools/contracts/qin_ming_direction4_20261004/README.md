# 秦明原生四向来源

本批16生产原生RGBA、32姿态、20资源经原生游戏与直接画面验收；见[本批QA](../../../qa/qin_ming_direction4_20261004/README.md)。

沿用现行 aligned 头像的宽脸卷须、红巾红披风、金铜甲及狼牙棒身份。当前 defs 为远程步兵，HP180、攻击14、冷却1.15、射程220、速度80、magic 弹道和四技能不因美术批变更；未增加骑乘。左手前握、右手后握，倒下可放松一手。

待机四向、步态 A/B 八姿态、蓄力/释放八姿态、受击四向、跪倒/末态八姿态，共32独立姿态。恢复复用待机、末态重复只分配时间。逐向检查手臂与交替腿部，不以镜像或重复姿势充数。

`jobs.json`、`generation.json`、`selection.json` 保留提示、原生 SHA、选择及便携引用链。新几何图只定义左右肢体、相机和棒轴；Pillow 在全新画布绘制投影，不读取或变换任何生产位图。实际引用图和生成器 SHA 保留。图集如原生行顺序不同，使用明确的 `atlas_layout` 区域元数据对应实际方向，原生 PNG 不本地翻转、缩放、裁切或重画。

`prepare.py` 只读 alpha 并生成区域、虚拟留白、脚点及 import；隔离导入分配 UID，再冻结游戏验收。游戏运行不依赖 Python、Pillow、原始生成目录或本机绝对路径。

```powershell
python -B tools/contracts/qin_ming_direction4_20261004/prepare.py
python -B tools/build_directional_spriteframes.py assets/direction4/qin_ming_20261004.json
```

祝家庄 `bound_qin_ming` 继续沿用现有“本体造型 + 程序绳索”的登记及绑缚/释放逻辑；验收实际演员、身份路由和释放后身体，不能据此外推整关营救、平衡、性能或平台包验收。
