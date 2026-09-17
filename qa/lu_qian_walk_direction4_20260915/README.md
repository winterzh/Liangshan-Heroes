# 陆谦四向行走原图 · 2026-09-15

本批从 Codex 网页端会话生成并下载一张原始 4×4 PNG，人工检查确认陆谦的中年精瘦官吏身份、深青灰官服、幞头和腰刀在所有方向保持一致；每行四帧脚步有明确变化，NE/NW 为真实背面。它只补 **陆谦 walk 四向身体**，不把行走图冒充攻击、受击或死亡。

## 来源与接入

- 原始网页 PNG：`assets/characters/art_full_20260915/lu_qian_walk_direction4_source.png`
- 生产图：`assets/characters/art_full_20260915/lu_qian_walk_direction4.png`（原图确定性 2× LANCZOS 整图缩放，得到 4×4 的 627px 整数格）
- 切片清单：`assets/direction4/lu_qian_walk_20260915.json`
- 资源：`assets/anim/lu_qian_walk_{se,sw,ne,nw}.tres`
- 提示词：`assets/direction4/web_prompts_20260915/lu_qian_walk_direction4.txt`
- 网页会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`
- 原始网页 SHA-256：`f677fcdbd8c9fcbe7fb26a0e1026d6ce56aef8f8dba86cec846dc19f27238649`
- 生产图 SHA-256：`ea43a2ef4afafd61672e6c25dde237c60161a04559726aa3548a1e0a0522eecf`
- 原图为 1254×1254 RGBA，生产图为 2508×2508 RGBA；生产图四行固定映射 SE/SW/NE/NW，四列为同方向四帧行走循环。

生产图只做整图缩放与固定矩形 AtlasTexture 接入，保留原始网页 PNG；没有镜像、抠除、重着色、重绘或跨角色借图。`filter_clip=true` 已写进四份 TRES，缩放时不会跨格采样。

## 验证

```powershell
py -3 -X utf8 -B tools/lu_qian_walk_atlas_scale.py
py -3 -X utf8 -B tools/lu_qian_walk_direction4_contract.py --output qa/lu_qian_walk_direction4_20260915/contract.json
# 由隔离 Godot 4.6.3、STEAM_DISABLED=1、私有用户目录运行
# tools/lu_qian_walk_direction4_runtime_qa.gd
py -3 -X utf8 -B tools/run_art_full_qa.py --run --work-root D:\CodexTemp\art_full_continue_20260915_r7
```

- 静态来源/资源契约：125 项通过，见 `contract.json`；生产图与原始 PNG 的确定性缩放结果逐字节一致，四行四帧均有可见身体且帧图不同。
- Godot 路由运行时：132 项通过，见 `runtime.json`；四个方向均读取各自 4 帧 TRES，死亡状态仍为空。
- 全库库存：321 项通过，导入和库存进程均退出 0，原始来源未漂移；陆谦记录为四向 idle 精确帧 1、walk 精确帧 4，attack/hurt/death 精确帧仍为 0。
- 全库最终收据摘要：`full_qa_receipt_excerpt.json`（运行目录 `D:\CodexTemp\art_full_continue_20260915_r7\20260915_231508_d9c52083`）。

## 未完成边界

陆谦仍需独立攻击、受击、死亡动作；祝朝奉仍需 walk/attack/hurt/death。旧头像背景、其余角色动作、地形细节和技能实战辨识也不因本批通过而完成。后续补图要继续保持角色身份和原著场景边界。
