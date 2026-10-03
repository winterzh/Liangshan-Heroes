# 呼延灼双鞭与原生四向来源

内置 imagegen 模式，共十份原生 RGBA 输出，九份在生产中使用：待机、行走 A/B、攻击起手、攻击打击源、受击、死亡、东北打击补帧及头像。最初密排行走图因邻格重叠被拒绝，原字节保留在 `generated/walk_rejected.png`，不进入游戏来源。PNG 仅逐字节复制，没有本地抠图、去背景、缩放、翻转或像素修复。`generation.json` 保存确切提示、生成标识、输入 SHA 和仓库内引用链；旧身体只提供骑乘画风，旧头像只提供脸部身份。

按[第五十五回原文](https://ctext.org/wiki.pl?chapter=810331&if=en)取冲天角铁幞头、黄罗抹额、皂袍乌油甲、踢雪乌骓与两条八棱钢鞭。游戏画面为原文要素的绘制解释，不声明考古服装复原。

动作共有 32 个独立选取姿势，生成 20 个五状态/四方向资源。攻击候选第三行第二列方向错误，且左列起手姿势邻格相接；这些区域完整保留在原图并列入 manifest 的 unused_regions。实际东北打击与四向起手引用独立重画源。死亡按完整姿势选择区域，未选边缘碎片和空白逐矩形登记；前两行末帧按马头方向选择 SE/SW。没有镜像或改写源图。行走两帧为基本换步，攻击起手/打击/恢复，死亡倾倒/末帧停留；不宣称高帧率连续骨骼动画。

`prepare.py` 只复制原生输出并读取 alpha，生成脚点、区域和来源 JSON；不会写 PNG 像素。Godot 首次隔离导入会分配 import UID，最终描述符从私有导入原字节回写，再冻结复验。已有 PNG 必须与来源 SHA 相同。资源复现：

```powershell
python -B tools/build_directional_spriteframes.py assets/direction4/hu_yanzhuo_20261003.json
```

默认只读比较；需要重新生成 TRES 才加 `--write`。Pillow 来源审计和原生 QA 命令及结果见 [本批 QA](../../../qa/hu_yanzhuo_direction4_20261003/README.md)。正常游戏不依赖生成目录、本机路径或 Pillow。
