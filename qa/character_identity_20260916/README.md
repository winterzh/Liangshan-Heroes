# 梁山核心人物头像统一 QA · 2026-09-16

本批将同一网页原生 2×2 头像图集固定拆为晁盖、鲁智深、武松、公孙胜四张独立图鉴头像。生成图使用北宋工笔与厚涂结合的低饱和暖灰褐纸纹风格；四人用不同脸型、体态、发式和服色区分身份，保留项目现有图鉴的阅读尺度。

## 来源与生产

- 来源：`assets/characters/art_full_20260916/liangshan_core_portraits_source_20260916.png`，1254×1254 RGB，SHA-256 `87d82b36d410ebd50b2af51858d202fb54d2490fc5e4531c8b89d8124e8904c8`。
- 提示词：`assets/characters/art_full_20260916/liangshan_core_portraits_prompt_20260916.txt`，SHA-256 `bc9a093dc5b2dbb9d14732be2fabbc5d992eadd28049ecf2c8d75fb478875dea`。
- `tools/intake_liangshan_core_portraits_20260916.py` 只按固定四象限裁切并用 LANCZOS 放大到 1254×1254；不镜像、不补画、不抹像素、不去背景。
- 四张独立图在 `assets/characters/art_full_20260916/`，生产清单为 `liangshan_core_portraits_manifest_20260916.json`。

## 验证

```powershell
py -3 -X utf8 -B tools/intake_liangshan_core_portraits_20260916.py
py -3 -X utf8 -B tools/liangshan_core_portraits_contract.py
# Godot 4.6.3
Godot_v4.6.3-stable_win64_console.exe --headless --path . --script tools/liangshan_core_portraits_runtime_contract.gd
py -3 -X utf8 -B tools/run_art_full_qa.py --run --work-root D:\CodexTemp\art_full_liangshan_core_portraits_20260916_r3
```

- 素材静态契约：28/28 PASS。
- Godot 运行时路由/尺寸/缺失键回退：13/13 PASS。
- 全库 Godot 导入与库存回归：`complete=true`，321/321，源文件和私有副本零漂移。
- 人工预览：`liangshan_core_portraits_preview.png`；四张脸、体态、服装和背景一致性通过目检。

本批没有新场景窗口截图，也没有改玩法、镜头、存档、导出包或 Steam。普通人物旧头像背景、地表接缝和技能实战辨识仍需后续逐项处理。
