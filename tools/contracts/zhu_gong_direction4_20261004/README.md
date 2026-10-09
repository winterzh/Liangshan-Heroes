# 祝家弓手原生四向契约 · 2026-10-04

祝家弓手完成12张原生RGBA、32独立姿态和20个五状态四向资源的基础验收；当前portraits5底行中格褐色头带、束发短须、灰褐棉衣和箭囊身份保留。所有PNG使用内置imagegen原生生成/编辑，未本地裁切、镜像、缩放或重画。SW/NE攻击因左右手互换单独重绘，前摇/释放SE/NW因图集留边不足原生扩大间隔；原始父图及实际引用链保留。NE手臂参考由空白画布绘制，不读取已有图；它仅供生成器参考，不进入游戏。47产物/20TRES字节复现与32留边通过。全部提示、原生SHA、实际引用链与选择保留在jobs.json/generation.json/selection.json；未引用的NE失败稿只记录不上传。生产图12份，必需父图4份，手臂参考及其空白画布生成器1套。

prepare.py只读alpha并写采样/身体比例/脚点元数据，不写生产PNG；运行游戏不依赖本机生成路径。重建：

```powershell
python -X utf8 -B tools/contracts/zhu_gong_direction4_20261004/prepare.py
python -X utf8 -B tools/build_directional_spriteframes.py assets/direction4/zhu_gong_20261004.json --write
```

最终动作、脚点、释放和真实命中、HUD/图鉴及实际章内演员以[本批QA](../../../qa/zhu_gong_direction4_20261004/README.md)为准。已完成基础原生及画面审核，未打包发布。
