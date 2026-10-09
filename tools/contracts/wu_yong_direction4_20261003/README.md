# 吴用通用四向来源契约 · 2026-10-03

八张原生 RGBA 图保留内置 imagegen 的完整字节，采用 2×2 布局；起手原图下半两格持手错误，在 manifest 拒绝采样，由两张单幅 NE/NW 原图替代。十张生产 PNG 共 32 个独立姿势。既有独立头像与旧身体只作为身份、绘画参考，不镜像或旋转角色生成其他方向。

- [jobs.json](jobs.json)、[jobs_extra.json](jobs_extra.json)：完整提示词和生成输出位置；额外来源含两份拒绝候选，原字节在 generated 中保留。
- [generation.json](generation.json)：生成标识、生产路径、SHA256、参考链和身份依据。
- [prepare.py](prepare.py)：只复制原字节、只读检查 alpha，生成 AtlasTexture 区域、脚点和尺寸元数据；不写图片像素。首次导入前建立描述符，隔离 Godot 导入分配 UID。
- [manifest](../../../assets/direction4/wu_yong_20261003.json)：十张来源、32 个独立姿势、20 个五状态四向资源。攻击恢复及死亡末帧有明确重复槽，不称为更多独立姿势。

吴用沿用项目的深色儒服、软头巾、尖须和右手羽扇。原著第十三回（七十回本）写有书生装束及铜链；羽扇是既有项目美术设计，不将其宣称为原著武器。现有远程普攻与投射物、数值、技能及黄泥冈剧情换装均保留。

复现需要 Pillow，游戏正常启动不需要 Pillow。生成目录还在时核对原图；其他电脑按 generation 中保留的 SHA 核对生产 PNG。执行：

```powershell
python -B tools/contracts/wu_yong_direction4_20261003/prepare.py
python -B tools/build_directional_spriteframes.py assets/direction4/wu_yong_20261003.json
python -B tools/directional_character_sources.py assets/direction4/wu_yong_20261003.json tools/contracts/wu_yong_direction4_20261003/generation.json --out <工程外报告路径>
```

姿态、方向与正常战斗目检及限制见 [QA](../../../qa/wu_yong_direction4_20261003/README.md)。
