# assets/

- `*_raw.png` — Imagen 生成的原始图（重画后覆盖这些文件）
- `units_sheet.png` / `terrain_sheet.png` / `portraits_sheet.png` — 处理后游戏实际加载的图集

原始图变更后重跑切片处理：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/process_sheets.gd
```

网格对照表见根目录 ART_PROMPTS.md；图集缺失时游戏自动使用代码占位图形。
