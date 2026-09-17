# 陆谦四向受击与死亡美术 · 2026-09-16

陆谦的受击和死亡状态已用同一网页原生会话分别出图并接入。受击四帧是警觉、后仰、踉跄、回稳；死亡四帧是站立摇晃、单膝、侧倒、安静倒地。四行 SE/SW/NE/NW 独立绘制，保持中年精瘦官吏脸、深青灰官服、幞头和腰刀，不借用待机、行走、攻击或其他角色动作。

原始 PNG、生产缩放、固定格和 SHA 见 `assets/direction4/lu_qian_{hurt,death}_20260916.json`；TRES 和运行时收据见 `qa/lu_qian_{hurt,death}_direction4_20260916/`。没有镜像、抠除、补画或重着色。

陆谦动作状态已闭合；旧头像背景、其他角色动作和技能实战辨识仍按全库台账排期。

# 陆谦四向待机美术 · 2026-09-15

本批先补齐陆谦的 **四向 idle 身体原图**，随后补入同一身份的四向 walk 原图。网页端生成后下载原始 PNG，人工检查确认身体完整、方向不镜像、服装与身份统一、背景为真透明；接入只做固定矩形 AtlasTexture 区域、透明补边和记录在案的整图缩放。

原图 `assets/characters/art_full_20260915/lu_qian_direction4.png` 为 1254×1254 RGBA，2×2 格按左上 SE、右上 SW、左下 NE、右下 NW 固定映射。四份 `assets/anim/lu_qian_idle_*.tres` 都直接引用同一原图，带 `filter_clip=true` 和四向元数据，运行时不会误用临格像素或水平镜像。

来源提示词、会话地址、原图 SHA 和四格区域记录在 `assets/direction4/lu_qian_20260915.json`；静态契约与 Godot 路由收据在 `qa/lu_qian_idle_direction4_20260915/`。

idle 由 `lu_qian_idle_direction4_20260915/` 收据覆盖；walk 由 `lu_qian_walk_direction4_20260915/` 收据覆盖，四个方向各 4 帧。陆谦的 attack、hurt、death 仍是开放缺口，不能用待机或行走图宣称动作完成；祝朝奉已另有 idle 身体原图，但仍需独立 walk/attack/hurt/death。后续每个状态都要保持陆谦的中年精瘦官吏脸型、深青灰宋代官服、幞头和腰刀识别点，并单独通过原图完整性、方向、脚底和实机渲染检查。
