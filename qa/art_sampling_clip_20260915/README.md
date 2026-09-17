# 图集采样边界修复 · 2026-09-15

本批处理缩放时的图集邻格串色：`scripts/art_db.gd` 统一为头像、地形和动作条带设置 `AtlasTexture.filter_clip = true`；死亡残留的 4×2 图集在 `scripts/battle.gd` 同样设置。它只改变运行时采样边界，不改任何 PNG 原字节、角色身份、姿态、数值或关卡规则。

## 验证

- `source_selftest.json`：5/5 个动态切片入口均有采样边界保护；脚本不写生产素材、不导出、不调用 Steam。
- `py -3 -X utf8 -B tools/art_full_source_contract.py --output scratchpad/art_full_continue/source_contract.json`：5 张原生来源、32 个资源，来源契约通过。
- `py -3 -X utf8 -B tools/run_art_full_qa.py --run --work-root D:\CodexTemp\art_full_continue_20260915_r3`：按最终源码（含死亡残留切片保护）完成隔离 Godot 4.6.3 导入与库存渲染，`godot_receipt_excerpt.json` 的 `complete=true`、321 项检查通过、退出码均为 0、锁已释放。完整运行目录保留在工程外 `D:\CodexTemp\art_full_continue_20260915_r3\20260915_192217_3f4d8148`。

## 边界

这项修复针对缩放采样造成的白边/串格，不能替代真人目检。全库角色动作缺口、陆谦/祝朝奉身体图、旧头像背景和技能实战辨识仍按 `docs/ART_FULL_20260915.md` 继续；本批没有用别人的素材冒充这些缺口，也没有发布 Steam。
