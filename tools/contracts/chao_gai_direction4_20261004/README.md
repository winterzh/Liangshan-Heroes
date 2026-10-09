# 晁盖原生四向来源

本批19生产原生RGBA、32姿态、20资源经原生游戏及直接画面验收；见[本批QA](../../../qa/chao_gai_direction4_20261004/README.md)。

通用身体沿用标准头像的宽脸黑须、棕巾、深青灰衣、胸前打结深色披衣和右手单刀，纠正旧赭黄外袍/铜甲差异。现有近战步兵HP300、攻击19、冷却0.85、射程28、速度80、chao_rally与攻击光环不变。左手空手；不增加骑乘。

待机4、交替步态8、前摇/劈斩8、受击4、跪倒/末态8，共32独立姿态，恢复复用待机、末态重复仅分配时间。PNG由内置imagegen原生生成，完整提示、SHA、选择和必需父图保留；几何参考只在新画布绘制肢体、相机和刀轴，不读取或变换生产位图。

prepare.py只读alpha并生成区域、虚拟留白和脚点；不本地裁切、翻转、缩放或重画PNG。20个TRES使用AtlasTexture坐标和独立方向。游戏不依赖Python/Pillow或原始生成目录。

黄泥岗hn_chao_gai赤膊剧情造型独立保留；实际两章开局检查剧情身体优先级和江州通用身体，标准UI头像与素材来源预览分别核对。仅验收外观，不宣称整章通关、玩法平衡、战役续玩或平台包验收。

```powershell
python -B tools/contracts/chao_gai_direction4_20261004/prepare.py
python -B tools/build_directional_spriteframes.py assets/direction4/chao_gai_20261004.json
```
