# 陆谦四向待机美术 · 2026-09-15

本批补齐陆谦的 **四向 idle 身体原图**。网页端生成后下载原始 PNG，人工检查确认四格人物完整、方向不镜像、服装与身份统一、背景为真透明；接入只做固定矩形 AtlasTexture 区域和透明补边。

原图 `assets/characters/art_full_20260915/lu_qian_direction4.png` 为 1254×1254 RGBA，2×2 格按左上 SE、右上 SW、左下 NE、右下 NW 固定映射。四份 `assets/anim/lu_qian_idle_*.tres` 都直接引用同一原图，带 `filter_clip=true` 和四向元数据，运行时不会误用临格像素或水平镜像。

来源提示词、会话地址、原图 SHA 和四格区域记录在 `assets/direction4/lu_qian_20260915.json`；静态契约与 Godot 路由收据在 `qa/lu_qian_idle_direction4_20260915/`。

本批刻意只认 idle。陆谦的 walk、attack、hurt、death 仍是开放缺口，不能用这张待机图宣称动作完成；祝朝奉仍需单独身体原图。后续每个状态都要保持陆谦的中年精瘦官吏脸型、深青灰宋代官服、幞头和腰刀识别点，并单独通过原图完整性、方向、脚底和实机渲染检查。
