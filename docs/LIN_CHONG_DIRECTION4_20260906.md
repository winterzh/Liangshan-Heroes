# 林冲通用战斗四向基础动作

2026-09-06。林冲 `lin_chong` 的站立、行走、攻击、受击、死亡现有东南/西南/东北/西北四向资源，驻守战和使用通用披甲林冲的战役共享。囚服、枷锁与押送等剧情变体继续使用自己的资源，缺专用死亡时保持同造型程序化倒下。

## 画面与接入

7张内置 image_gen 生成的原生RGBA保存在 `assets/characters/lin_chong_direction4_20260906/`，共12,124,187字节；原字节与alpha保留。32个独立姿态通过20个SpriteFrames安排动作。AtlasTexture只指定采样区域、透明留边和绘制偏移，不移动物理位置、碰撞、脚底选圈或命令目标。

| 状态 | 每向帧数 | 顺序 |
|---|---:|---|
| idle | 1 | 站立 |
| walk | 4 | 站立、迈步A、站立、迈步B |
| attack | 5 | 收枪、收枪、刺枪、刺枪、站立 |
| hurt | 1 | 独立受击姿态 |
| death | 4 | 受击、失衡倒下、倒地、倒地 |

重复姿态用于时序，不算新增画稿。长枪伤害触发点落在刺枪帧；林冲加入已有的绘制攻击名单，避免再叠加整张立绘挥动。唯一生产代码改动是 `scripts/unit.gd` 名单新增一行，没有修改属性、技能伤害、经济或地图规则。

东南/西北采用双手预备架势；西南/东北采用右手持枪、左手空出的架势。四向是实际前后视图，没有水平翻图。西南原始收枪格脸朝反方向，已排除并用独立修正图替代；西南/东北原来的重复迈步格全部排除，改用两张三维迈步参照引导生成的新姿态。原区域和替换原因写在清单中。不同方向预备架势、衣甲细节和行走图亮度有轻微差异；这是低帧数基础动作，尚需真人转向和行走观感反馈，不宣称高帧数连续转身动画。

运行图集由Godot标准导入缩放并启用mipmap：四张主图为512×768，西南收枪384×256，东北迈步512×320，西南迈步512×341；RGBA基础层合计8,038,400字节，不含mipmap和引擎开销。实际导入尺寸用于排帧，原图没有本地抠图、裁切保存、补画、镜像或重新编码。

## 当前验证

Godot 4.6.3，实际图形夹具使用Vulkan/RTX 3070 Ti：林冲354、剧情终态286、宋江248、墙46、接应22、门楼30、驻守取图8、战役素材162和只读来源237，共1,393项通过。通用来源工具另用现有宋江素材验证248项，林冲20个和宋江16个排帧资源复现无差异。

林冲验证包含四向真实玩家移动命令、近战命中和命中帧、受击帧、致命伤移出战斗列表、死亡方向与末态释放；32姿态图直接调用真实Unit绘制。来源检查验证原生哈希、透明度、导入、引用链和区域间无可见像素污染；它不自动判断人体结构。已人工查看本轮固定姿态图、出枪截图及剧情服装矩阵，未把图片路径断言当作美术内容验收。

门墙三机位复查柱子竖直、墙脚与门脚相接，未再次修改上轮墙材；孙立接应回归仍通过。工作中核对无重叠后快进整合网格投影69125b3与追击速度9c19c93，素材哈希保留，回归在整合后运行。相关截图、报告、导入输出与输入收据见 [QA](../qa/lin_chong_direction4_20260906/README.md)。

## 复现

普通启动使用根目录 `Play.cmd`，更新后重开关卡；原有启动器检查导入缓存。家里与办公室各自配置忽略的 `godot.local.txt` 或 `GODOT_PATH`。

```powershell
$godotExe=(Get-Content godot.local.txt -Raw).Trim()
$env:LC_VISUAL='1'
& $godotExe --path . --script res://tools/lin_chong_direction4_qa.gd
py -3 tools/build_directional_spriteframes.py assets/direction4/lin_chong_20260906.json
py -3 tools/directional_character_sources.py assets/direction4/lin_chong_20260906.json tools/contracts/lin_chong_direction4_20260906/generation.json
& $godotExe --headless --path . --script res://tools/character_direction4_inventory.gd
```

`LC_QA_OUT`可指定输出目录；默认 `.godot/lin_chong_direction4/runtime/`。去掉 `LC_VISUAL` 并加 `--headless` 可跑无画面检查。Python来源审计需要Pillow，只读比较排帧不需要Pillow；给排帧工具加 `--write` 只重建清单中的20个TRES。

## 剩余范围

全库164个可移动定义中，四向idle/walk/attack/death文件齐全数量更新为26/9/9/7；驻守敌军idle仍是709/778。本批只增加通用林冲，孙立、扈三娘、其他角色和宋江专用hurt继续开放。没有将剧情服装、镜像、旧动作或站姿回退算作新增覆盖。

本次完整提示词与被采用链在 [generation.json](../tools/contracts/lin_chong_direction4_20260906/generation.json)。原项目身份参考更早的来源缺口仍需单独核实。真人八关/30波、教程、战斗快照恢复、拥挤性能、长时稳定性和发行候选验证尚未完成。本轮仅源码/生产素材同步stable和PR #1，没有合并main、导出安装包或执行Steam发布。
