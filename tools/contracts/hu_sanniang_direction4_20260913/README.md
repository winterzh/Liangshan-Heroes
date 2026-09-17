# 扈三娘四向基础动作来源与帧配方

本批为 4 个独立朝向、32 个姿态、20 个基础 SpriteFrames 的实际生产资源。使用内置 image_gen 和原生 RGBA 原图，未程序抠图、镜像朝向、改像素或画帧。原著第四十八回明文的红纱、甲胄、金钗与日月双刀优先于旧绿衣参考；棕马毛色属于既有游戏设计，不能说成原著精确色号。

`generation.json` 是标准 `directional_character_sources.py` 输入，包含原身份参考、24 个来源条目（21 次生成与3份额外旧动作参考）、精确提示词、SHA 和可携带的项目内引用链。`native/` 保留非生产生成稿，`references/` 保留5张旧图；选定9张PNG位于 `assets/characters/hu_sanniang_direction4_20260913/`，原字节均未改写。私有工具生成位置仅作为历史来源，不是复现依赖。

`pose_recipe.json` 与 `assets/direction4/hu_sanniang_20260913.json` 保存32个真实原图区划、马脚锚点、实际导入尺寸、方形透明补边与20资源帧序；只构建 AtlasTexture / SpriteFrames 元数据。脚锚点与补图体量是可审的初始配方，实际 Unit 渲染验收见本批QA。

| 状态 | 每向帧配方 |
|---|---|
| idle | idle |
| walk | walk_a / walk_b / walk_a / walk_b |
| attack | windup / windup / strike / strike / idle |
| hurt | hurt |
| death | hurt / fall / ground / ground |

行走只称基础伸收两相；NW 的 A 为较直的支撑姿态、B 为双前腿收起姿态，不称完整四蹄高帧跑步。攻击动作按现有剑类命中阶段 0.52 配置重复帧，不改变技能、伤害或命中时序。无新增 down：祝家庄生擒必须保持活体、原身份与敌队，沿用现有非死亡休息帧，绝不以 death 代替生擒。

九张选定图均已由根任务实际 Godot 导入回读：主四图512×768；SE独立步384×320；SW独立步350×384；SW/NW补图768×384；NE补图739×768。四主图和三排距补图 limit768，两张独立步 limit384，全部 mipmaps=true。

`hu_regions.json` / `hu_regions_supplement1.json` 保存独立只读 alpha>15 区域与初始锚点审查。原 SW 两格、NE 四格与 NW 两格的真实串格被单独排距补图替换；旧格及零散未用像素通过互斥 `unused_regions` 明确保留，选中帧与排除区域合计精确覆盖每个 alpha>15 原像素一次。独立步B补充可辨的伸收相位。标准源码审计实际259项通过，仅代表来源、alpha、采样区和元数据；不替代解剖、朝向与游戏内动作观感。

复现命令（从包含 `project.godot` 的项目根目录；原图无需重新生成）：

```powershell
python tools/build_directional_spriteframes.py assets/direction4/hu_sanniang_20260913.json
python tools/directional_character_sources.py assets/direction4/hu_sanniang_20260913.json tools/contracts/hu_sanniang_direction4_20260913/generation.json --out qa/hu_sanniang_direction4_source_check.json
```

第一个命令只比较资源；需要按既定配方重建 `.tres` 时才加 `--write`。实际 Godot 导入和原生移动/攻击/受击/死亡/生擒验证由根任务串行负责。最终180852批已609项角色检查通过；完整范围见../../../qa/character_art_20260913/README.md。本批没有Steam打包发布。
