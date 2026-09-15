# 陆谦四向受击原图 · 2026-09-16

本批使用 Codex 网页端原生生图会话生成一张 4×4 真透明 PNG，只补陆谦 `hurt` 身体动作。四行固定 SE/SW/NE/NW，四列为 `ready/recoil/stagger/recover`；警觉站稳→被击后仰→侧身踉跄→收回重心。陆谦保持中年精瘦、尖长刻薄脸、深青灰宋代官服、黑色幞头与腰刀，和祝朝奉宽体栗袍区分；没有血液、断肢、场景元素、镜像或跨角色借图。

## 来源与接入

- 原始网页 PNG：`assets/characters/art_full_20260916/lu_qian_hurt_direction4_source.png`
- 生产图：`assets/characters/art_full_20260916/lu_qian_hurt_direction4.png`（确定性整图 2× LANCZOS）
- 切片清单：`assets/direction4/lu_qian_hurt_20260916.json`
- 资源：`assets/anim/lu_qian_hurt_{se,sw,ne,nw}.tres`
- 提示词：`assets/direction4/web_prompts_20260916/lu_qian_hurt_direction4.txt`
- 网页会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`

原图为 1254×1254 RGBA，生产图为 2508×2508 RGBA；TRES 只引用固定 627px 格，启用 `filter_clip=true` 和 `authored_direction4` 元数据。

## 验证

```powershell
py -3 -X utf8 -B tools/lu_qian_hurt_direction4_contract.py --output qa/lu_qian_hurt_direction4_20260916/contract.json
# 私有 Godot 4.6.3、STEAM_DISABLED=1 运行 tools/lu_qian_hurt_direction4_runtime_qa.gd
```

- 静态来源/资源契约：126 项通过。
- Godot 路由运行时：128 项通过；四个方向均读取对应四帧原图，未走镜像或状态回退。
- 全库美术回归：321 项通过，见 `qa/art_full_20260916/receipt.json`；导入和库存进程退出 0。
- 本批没有改玩法数值、玩家存档、导出包或 Steam 状态。

## 未完成边界

陆谦动作状态已闭合；旧头像背景、其余角色动作、地形细节和技能实战辨识仍按 `docs/ART_FULL_20260915.md` 排期。
