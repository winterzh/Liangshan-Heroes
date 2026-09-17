# 陆谦四向待机原图 · 2026-09-15

本批从 Codex 网页端会话生成并下载一张原始 2×2 PNG，经过本地原图检查后接入工程。它只补 **陆谦 idle 四向身体**，不把待机图冒充行走、攻击、受击或死亡。

## 来源与接入

- 原图：`assets/characters/art_full_20260915/lu_qian_direction4.png`
- 同源头像：`assets/characters/art_full_20260915/lu_qian.png`（固定裁剪 SE 格上半身，避免旧灰底头像与新身体风格割裂）
- 切片清单：`assets/direction4/lu_qian_20260915.json`
- 资源：`assets/anim/lu_qian_idle_{se,sw,ne,nw}.tres`
- 提示词：`assets/direction4/web_prompts_20260915/lu_qian_idle_direction4.txt`
- 网页会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`
- 原图 SHA-256：`3f73f999960652ef35b4d3b42b39d43a937989663d8a235a1e989b705f26d8c0`
- 原图为 1254×1254 RGBA，alpha 范围 0–255，透明像素比例 0.7821096891859923；四格按 SE/SW/NE/NW 固定映射。

只使用固定矩形 AtlasTexture 区域与透明补边，保留原始 PNG 字节；没有镜像、抠除、重着色、补画或跨角色借图。`filter_clip=true` 已写进四份 TRES，缩放时不会跨格采样。

## 验证

```powershell
py -3 -X utf8 -B tools/lu_qian_idle_direction4_contract.py --output qa/lu_qian_idle_direction4_20260915/contract.json
# 由隔离 Godot 4.6.3、STEAM_DISABLED=1、私有用户目录运行
# tools/lu_qian_idle_direction4_runtime_qa.gd
py -3 -X utf8 -B tools/run_art_full_qa.py --run --work-root D:\CodexTemp\art_full_continue_20260915_r5
```

- 静态来源/资源契约：53 项通过，见 `contract.json`；同源头像像素与固定裁剪一致。
- Godot 路由运行时：51 项通过，见 `runtime.json`；四个方向均从同一原图 TRES 读取，头像走同源裁剪，死亡状态仍为空。
- 全库库存：321 项通过，导入和库存渲染均退出 0，原始来源未漂移；陆谦记录为四向 idle 精确帧 1，walk/attack/hurt/death 精确帧仍为 0。
- 全库最终收据摘要：`full_qa_receipt_excerpt.json`（运行目录 `D:\CodexTemp\art_full_continue_20260915_r5\20260915_224408_6e4f4683`）。

## 未完成边界

陆谦仍需独立行走、攻击、受击、死亡动作；祝朝奉仍缺身体图。继续补动作时必须保持同一人物脸型、深青灰官服和腰刀识别点，并为每个状态单独出原图与目检，不用别人的动作填空。
