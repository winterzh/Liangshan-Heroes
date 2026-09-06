# 宋江通用战斗四向首批

2026-09-06。宋江 `song_jiang` 的站立、行走、攻击、死亡已接入四个实际朝向，供驻守战及使用通用宋江的战役共享。原静态参考是金纹长袍，旧动画却是另一套盔甲；本批统一为金袍、黑披巾、金冠与右手持剑，避免移动或交战时换装。林冲、孙立及其余全库角色继续按缺口表推进。

## 本批内容

- 15张内置 imagegen 输出的原生 RGBA PNG，完整原字节保存在 `assets/characters/song_jiang_direction4_20260906/`。没有本地程序抠图、补画、镜像或重新编码 PNG。
- 16个 `assets/anim/song_jiang_<动作>_<方向>.tres` 通过 SpriteFrames 安排帧顺序。AtlasTexture 只指定采样区域、透明留边与绘制偏移；物理位置、脚底选圈、碰撞与命令不随画面偏移移动。
- 每个方向有5个独立姿态，四向共20个：站立1帧；行走为站立/迈步2帧；攻击为站立/出剑/站立3帧；死亡为站立/跪倒/躺倒/躺倒4帧。这是低帧数动作，不代表20帧连续动画。
- 宋江加入已绘制攻击动作名单，避免再叠整张立绘的旧挥动。数值、伤害、技能及建造训练规则没有调整。
- 原 PNG 动画保持原字节。Art 优先精确方向 PNG，再接受同名有效 SpriteFrames；精确动作仍高于旧同动作，最后才回退同向站姿。`death`、`down` 不互借，也不回退站姿。
- 江州绑缚、获救等剧情变体保留优先级。受击没有新增专用姿态，通用宋江受击沿用同向新站姿和现有闪红/受击位移；不把它计为完整 hurt。

## 透明、方向和导入

行走原图的 SW 格换了持剑手，因此这格完全不被生产帧引用，改用独立的 SW 迈步图。NW 按整个身体及双脚朝向检查，不能只看头朝哪边。死亡按跪倒和躺倒的身体尺寸分别校准，不能把矮的躺姿拉到站立高度。

部分原生 PNG 在 alpha=0 的像素下面仍有有色 RGB，图片预览可能展示这些底色。真实 alpha 检查与 Godot 合成后的不透明截图才是验收依据；本批实际 Unit 矩阵没有棋盘格或背景光晕。源图未被本地清色。标准 Godot 导入将单人图限制为256、图集限制为512，并启用 mipmap；帧资源使用实际导入后的尺寸。高清原图保留，15张导入纹理的 RGBA 基础层合计4,441,088字节，未把原生千像素原图直接作为运行尺寸。

## 复现与证据

通过根目录 `Play.cmd` 启动并重开关卡。首次拉取后由现有启动器检查并补齐 Godot 导入缓存，本机路径继续使用忽略的 `godot.local.txt` 或 `GODOT_PATH`。

```powershell
$godotExe = (Get-Content godot.local.txt -Raw).Trim()
$env:SJ_VISUAL = '1'
& $godotExe --path . --script res://tools/song_jiang_direction4_qa.gd
py -3 tools/song_jiang_direction4_sources.py
& $godotExe --headless --path . --script res://tools/character_direction4_inventory.gd
& $godotExe --headless --path . --script res://tools/skirmish_direction4_contract_test.gd
```

新增工具默认输出 `.godot/`，不会覆盖旧QA。支持 `SJ_QA_OUT`、`DIRECTION4_INVENTORY_OUT`、`DIRECTION4_CONTRACT_OUT`；无图形检查时去掉 `SJ_VISUAL` 并加 `--headless`。Python只读检查需要 Pillow。

最终 Godot 4.6.3 / Vulkan / RTX 3070 Ti：宋江250项，包含实际四向移动、近战伤害与死亡释放；来源/导入195项；驻守路由8项，涵盖452个旧动作优先场景；原四类高频官军动作257项；门墙46项、孙立接应22项通过。实际截图、报告及输入收据见 [QA](../qa/song_jiang_direction4_20260906/README.md)。正常速度的四向短流程是动作接入验证，不是30波或完整战役平衡验收。

本批整合了另一任务的兵群、树冠及芦苇优化，基线为 `8bc2249`。最终本轮提交和远端SHA以同步收据为准。

## 剩余范围

全库164个可移动定义中，四向文件齐全的 idle/walk/attack/death 现为25/8/8/6；驻守敌军 idle 出场实例仍为709/778。当前只新增宋江，未把借图、镜像、剧情变体或站姿回退算作其他角色的完整动作。低帧数动作的真人观感、高缩放细节、其余角色、完整hurt、教程、战斗恢复、性能与首次销售验收继续开放。

本次提示词、15个采用输出、17个被采用图依赖的中间参考和原项目身份参考形成可追溯的新链，见 `tools/contracts/song_jiang_direction4_20260906/generation.json`。这不补写旧参考缺失的早期提示词或授权证据。本批只做源码同步，没有导出安装包或Steam发布。
