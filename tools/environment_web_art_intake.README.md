# 网页环境美术验收与导入

`environment_web_art_intake.py` 只检查已经从网页版 ChatGPT 下载的环境 PNG。它不会打开网页、发送提示词、生成图片、运行 Godot 或推测缺失的运行时路由。默认是 dry-run，不写 `assets/`。
运行需要 Python 3、Pillow 和 NumPy。

工具锁定的提示词合同是：

`../implementation_20260902/environment_prompt_drafts_v2/environment_batch_manifest.json`

当前冻结版本为 schema v2，SHA-256 是 `162e74544989ce4b89e32db6d1562e10962a1d58fc1c3d39e30c83abdb9430cf`。同目录 `static_self_check.json` 的 SHA-256 是 `f8e562d4aeebbd64519acf83ecfb54385742b3d7f89dd72684149a953386aa77`，结果为 502/502 PASS、0 个 legacy `code_targets`。工具会同时锁定这两个文件。四张图集的 64 个格子都已逐格声明 `output_id`、`output_path`、`level_scope`、`route_scope`、`reuse_policy`、resolver、route key 和状态，导入映射不得改写这些字段。

## 来源清单

复制 `environment_source_manifest.template.json`，在 `entries` 中填写已经下载的批次。允许先填黄泥冈、梁山样板，不要求一次列齐九张；同一批次只能出现一次。

每项需要：

- `id`：与冻结批次清单一致。
- `source_png`、实际 `source_sha256` 和固定尺寸 `[2048, 2048]`。
- 不带查询参数或 fragment 的 `https://chatgpt.com/c/...` 会话地址。
- 与冻结提示词文件一致的 `prompt_sha256`。
- `decision` 为 `adopt` 或 `reject`，并填写具体 `reason`。
- `human_review.reviewed_at`、`notes` 和对应类别的全部布尔复核项。`reviewed_at` 必须是带 UTC 偏移的 ISO-8601 时间；采用图所有复核项必须为 `true`，淘汰图可以保留失败项和理由。

地表人工项：

- `three_by_three_wrap_has_no_visible_seam_vignette_hotspot_or_directional_band`
- `no_forbidden_scene_content`
- `gameplay_zoom_100_and_150_readable`
- `prompt_specific_acceptance_confirmed`

图集人工项：

- `cell_map_and_scale_confirmed`
- `whole_cell_rectangles_only_confirmed`
- `no_mirror_repaint_synthesis_mask_or_pixel_clear_needed`
- `no_forbidden_base_shadow_text_watermark_or_modern_content`
- `isometric_scale_silhouette_and_anchor_confirmed`
- `prompt_specific_acceptance_confirmed`

## 自动检查

五张地表必须是单帧、原生 PNG color type 6 的 2048×2048 RGBA，且所有 alpha 都是 255。工具虚拟检查 3×3 重复：

- 左右、上下各 16 像素对边带的平均 RGB 差不超过 10/255。
- 跨边界相邻像素 RGB 梯度的 P95，不超过整图内部相邻像素梯度 P95 的 1.25 倍。
- 肉眼无十字缝、暗角、中心热点、方向条带和 32–64 像素规律块仍由人工项负责，程序不冒充视觉结论。

四张 4×4 图集必须是单帧、原生 PNG color type 6 的 2048×2048 RGBA。外圈 24 像素，以及横纵三条 `496..527`、`1008..1039`、`1520..1551` 的 32 像素带，必须全程精确 `alpha=0`；16 格都必须有可见像素。行列与 schema v2 一样按 1 到 4 记录。

## 生产映射

`environment_production_mapping.template.json` 已从冻结 schema v2 生成：

- 64 个图集格子的身份、路径和关卡范围已逐格锁定，不能退回聚合 `town_house`、`zhu_hall`、`tree` 等全局覆盖。
- 当前 `CampaignEnvironmentArt` 静态合同为 785/785 PASS，64 个图集格和 5 张地表都有逐项消费者证据。工具会同时核对 resolver、route key、state、输出路径、关卡范围、消费者文件 SHA 和精确源码行。
- 当前静态报告 SHA-256 为 `16dda6894bfc1bb54584ac90180de2227d6df6a34174192a6638fd8068405f43`，本映射模板 SHA-256 为 `af1204a50a865096be47917440a36c67d9290f295fd5ee1ac2f8e000b1d441f1`。
- `cuiyun_tower` 的 default 与 signal 是两条独立证据；signal 明确绑定 `scripts/levels/level8_dongchangfu.gd:276`，不再因 route key 相同就推定两个状态都已接线。
- 五张地表的精确生产目标、level scope、`CampaignEnvironmentArt.surface` 消费者、shader 开关和安全 fallback 均已绑定。
- 模板的 69 项现在都为 `integration_ready: true`，这个字段只表示消费者接线已被当前 SHA 证据确认。69 张目标 PNG 仍全部缺失，游戏尚未实际绘制这批新网页素材。
- 任一消费者文件在报告后改动，其 SHA 会失配，工具将拒绝 dry-run/commit，直到重跑合同并复核新证据。
- 任一采用图缺少目标、逐格路由或接线证据，dry-run 会列出 `mapping_gaps`，`--commit` 必定拒绝。

图集输出只允许固定 512×512 整格裁切、等比缩放和透明补边。`canvas_size`、正方形 `scaled_size` 与 `offset` 明确记录变换。代码没有组件提取、镜像、补画、方向合成、alpha mask、异物像素清除或阴影修补入口。

## 使用

默认只读检查：

```powershell
py -3 -X utf8 -B tools\environment_web_art_intake.py `
  --source-manifest C:\path\to\environment_sources.json `
  --report qa\environment_art_intake\dry_run.json
```

`decision: reject` 的图片仍会输出来源、哈希和客观失败数据，不会进入生产目标；显式提交时只归档源图、提示词和淘汰记录。采用图客观失败时 dry-run 返回非零。

只有人工看过 dry-run，且 `commit_ready` 为 `true` 后才显式提交：

```powershell
py -3 -X utf8 -B tools\environment_web_art_intake.py `
  --source-manifest C:\path\to\environment_sources.json `
  --mapping-manifest tools\environment_production_mapping.json `
  --report qa\environment_art_intake\commit.json `
  --commit
```

提交顺序固定为：复核输入 SHA → 对所有现有/新增目标做 SHA checkpoint → 在 checkpoint 下的临时目录生成全部输出 → 再次复核输入与目标未变化 → 逐文件 `os.replace`。任何中途错误都会按 checkpoint 恢复已有文件、删除新增文件和本次新建的空目录。源 PNG、精确提示词、三份输入 manifest 和采用/淘汰记录归档在映射指定的 `qa/` 目录，不进入运行时目标。

隔离自测：

```powershell
py -3 -X utf8 -B -m py_compile `
  tools\environment_web_art_intake.py `
  tools\environment_web_art_intake_selftest.py

py -3 -X utf8 -B tools\environment_web_art_intake_selftest.py
```

自测只使用临时工作区，覆盖默认 dry-run、消费者 SHA 漂移、翠云楼状态证据、逐格输出、透明带失败、缺路由拒绝、重复目标拒绝和部分替换后的 SHA 精确回滚。它不运行 Godot，也不写仓库生产素材。
