# 祝朝奉四向待机美术 · 2026-09-15

本批补齐祝朝奉的 **四向 idle 身体原图**。提示词锁定他作为祝家庄庄主的身份：年长、宽厚富态、灰黑短须、深栗色乡绅绸袍；这和陆谦的精瘦官吏体态、深青灰官服形成可读区分，也保留宋代地方势力的场景气质。网页端下载的原始 PNG 经目检确认四格完整、背面方向成立、无文字/网格/地面和真透明背景。

原图 `assets/characters/art_full_20260915/zhu_zhaofeng_direction4.png` 为 1254×1254 RGBA，2×2 格固定为左上 SE、右上 SW、左下 NE、右下 NW。四份 `assets/anim/zhu_zhaofeng_idle_*.tres` 仅引用固定格和透明补边，带 `filter_clip=true` 与四向元数据；头像 `zhu_zhaofeng.png` 从同一原图固定裁出，避免身体和图鉴/HUD头像出现画风断裂。

来源提示词、会话地址、原图 SHA 和四格区域记录在 `assets/direction4/zhu_zhaofeng_20260915.json`；静态契约、Godot 路由和全库回归收据在 `qa/zhu_zhaofeng_idle_direction4_20260915/`。

本批只认 idle。祝朝奉的 walk、attack、hurt、death 仍是开放缺口，不能用待机图或别的角色动作填空。后续动作要保持宽体乡绅轮廓、短须、栗袍和黑色幞头这组识别点，并逐状态核对原著身份、方向、脚底锚点、透明边界和实机画面。
