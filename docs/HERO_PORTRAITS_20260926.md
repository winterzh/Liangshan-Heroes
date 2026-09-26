# 四名核心英雄独立头像

2026-09-26，按用户“先补充美术资源”补充吴用、花荣、杨志、李逵的通用头像。四人此前走旧头像图集；现在在 `Art.STANDALONE_PORTRAITS` 优先加载独立 PNG，用于图鉴及走 `Art.avatar_texture` 的通用 HUD 入口。

| 角色 | 识别重点 | 生产文件 |
|---|---|---|
| 吴用 | 瘦长脸、尖须、深蓝儒服与羽扇 | `assets/characters/hero_portraits_20260926/wu_yong.png` |
| 花荣 | 年轻无须面貌、蓝白武服与弓箭 | `assets/characters/hero_portraits_20260926/hua_rong.png` |
| 杨志 | 棱角面貌、单侧青记、褐衣与甲片 | `assets/characters/hero_portraits_20260926/yang_zhi.png` |
| 李逵 | 宽脸、蓬乱须发、深色衣装与斧 | `assets/characters/hero_portraits_20260926/li_kui.png` |

使用内置 `image_gen` 逐人生成，以既有晁盖独立头像作为画风参考，统一暖灰褐纸纹、低饱和配色与工笔厚涂。每张原生 1254×1254 PNG 按字节复制入库，无裁切、抠底、镜像、重绘后处理或有损转码。生产图同时就是本批采用的原始来源，不重复保存一套相同 PNG。四份完整提示词、参考图哈希、生成标识与生产图 SHA-256 见 `tools/contracts/hero_portraits_20260926/`。

脸型、衣色及杨志青记位于人物右侧的选择属于本项目美术设计，不能当作原著逐字规定。旧图集继续供其他人物使用；剧情换装专用头像、身体四向动画与战斗规则沿用原资源。本批只覆盖这四名人物的通用头像，普通单位动作、其他旧头像、地形和技能特效仍按原台账处理。

## 复现与验收范围

```powershell
python -X utf8 -B tools/run_hero_portraits_qa.py --work-root <工程外的QA目录> --run
```

不带 `--run` 时只做来源检查与执行预检。工具复用既有共享 Godot 锁和私有用户目录，冻结当前生产输入，新导入后检查原图哈希、头像路由、HUD 通用取图、真实图鉴所选贴图，以及 256/96/64/32 像素引擎渲染。Godot 路径从 `godot.local.txt`、`GODOT_PATH` 或 `--godot` 提供。

Godot 4.6.3 私有导入与 27 项检查全部通过，3,354 个冻结输入无漂移。已直接查看四人的真实图鉴截图和多尺寸合成图；原图完整，路径正确，未发现串图或头部裁断。执行结果、既有 GLES3 MSAA 警告及人工目检范围见 [本批 QA](../qa/hero_portraits_20260926/README.md)。这轮没有发布 Steam 或 Android 更新。
