# 祝朝奉四向待机原图 · 2026-09-15

本批从 Codex 网页端会话生成并下载一张原始 2×2 PNG，人工检查确认祝朝奉的年长宽体乡绅身份、灰黑短须、栗色宽袖袍与四个真实方向。它只补 **祝朝奉 idle 四向身体和同源头像**，不把待机图冒充行走、攻击、受击或死亡。

## 来源与接入

- 原图：`assets/characters/art_full_20260915/zhu_zhaofeng_direction4.png`
- 同源头像：`assets/characters/art_full_20260915/zhu_zhaofeng.png`（固定裁剪原图 SE 格上半身）
- 切片清单：`assets/direction4/zhu_zhaofeng_20260915.json`
- 资源：`assets/anim/zhu_zhaofeng_idle_{se,sw,ne,nw}.tres`
- 提示词：`assets/direction4/web_prompts_20260915/zhu_zhaofeng_idle_direction4.txt`
- 网页会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`
- 原图 SHA-256：`046be9f9632628a8d35edad6171e8f24914483adc40e9874e64d7fec5ff178b1`
- 原图为 1254×1254 RGBA，alpha 范围 0–255，透明像素比例 `0.6827765186490948`；四格按 SE/SW/NE/NW 固定映射。

只使用固定矩形 AtlasTexture 区域与透明补边，保留原始 PNG 字节；没有镜像、抠除、重着色、补画或跨角色借图。`filter_clip=true` 已写进四份 TRES，缩放时不会跨格采样。

## 验证

```powershell
py -3 -X utf8 -B tools/zhu_zhaofeng_portrait_crop.py
py -3 -X utf8 -B tools/zhu_zhaofeng_idle_direction4_contract.py --output qa/zhu_zhaofeng_idle_direction4_20260915/contract.json
# 由隔离 Godot 4.6.3、STEAM_DISABLED=1、私有用户目录运行
# tools/zhu_zhaofeng_idle_direction4_runtime_qa.gd
py -3 -X utf8 -B tools/run_art_full_qa.py --run --work-root D:\CodexTemp\art_full_continue_20260915_r6
```

- 静态来源/资源契约：53 项通过，见 `contract.json`；头像像素与固定裁剪一致。
- Godot 路由运行时：51 项通过，见 `runtime.json`；四个方向均从同一原图 TRES 读取，头像走同源裁剪，死亡状态仍为空。
- 全库库存：321 项通过，导入和库存进程均退出 0，原始来源未漂移；祝朝奉记录为四向 idle 精确帧 1，walk/attack/hurt/death 精确帧仍为 0。
- 全库最终收据摘要：`full_qa_receipt_excerpt.json`（运行目录 `D:\CodexTemp\art_full_continue_20260915_r6\20260915_230149_2db3f629`）。

## 未完成边界

祝朝奉仍需独立行走、攻击、受击、死亡动作；全库旧头像背景、其余角色动作、地形细节和技能实战辨识也不因本批通过而完成。后续补动作必须继续区分不同人物脸型、体态和服装，先目检再接入。
