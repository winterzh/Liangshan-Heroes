# 祝家庄与大名府田地地表

后续更新：本批观察到的旧atlas斜向细缝已用独立shader改动修复，见 [地表透明缝](TERRAIN_ALPHA_SEAMS_20260906.md)。下文与原QA保留田地接入当时的事实，源图/提示词/审核增量字节未变。

2026-09-06，从 `f0818c1` 独立制作并验证。新增 `assets/campaign/environment/shared/surfaces/surface_field.png`，沿用已有路由，仅祝家庄 level3 与大名府 level8 加载。关卡脚本、战斗逻辑、地形格、碰撞、高度和着色器均未改动。

## 素材与来源

本次使用 Codex 内置 `image_gen.imagegen` 生成一张收割后田地土质：低对比褐土、细碎秸秆和少量灰绿斑点，无建筑、透视、文字或透明背景。完整实际提示词和生成原图在 `tools/contracts/environment/field_20260906/`，该目录含 `.gdignore`，不会作为运行时素材导入。

请求尺寸为2048×2048，工具实际返回1254×1254 RGB、不透明PNG。生产文件直接逐字节复制原图，没有放大、补alpha、裁切、调色或局部修图。原图与生产SHA256均为 `e1c570c01304fb9c3ad4cc7f0ffde0ab81aaed1d7b3ba15498b417f76439b7d0`。现有shader通过 `textureSize` 按实际尺寸计算半像素边界，因此接入保持原生分辨率，整图映射一次且禁用repeat。

这是本次新生成、独立验收的来源记录；不是恢复出来的9月2日网页原图，不代表通过旧2048 RGBA网页接入合同。`intake.json` 如实记录工具、生成文件ID、提示词哈希、实际尺寸、安装操作和本次检查范围，没有编造网页会话或历史提示词。未使用CLI/API后备。

## 审计增量

原69项目录 `inventory_20260906.json` 的字节和SHA保持不变。`field_20260906/review.json` 是单独固定SHA的审核增量，只补原先缺失的 `surface_field`；工具检查其基线、关卡、目标路径和其他路由字段。其余68项以及13条历史输入原样保留。运行审计不会按当前文件自动刷新哈希。

当前37张生产PNG匹配基线，32个目标仍缺图。新田地的原图、提示词和接入记录已齐；总体逐项缺口253→249，仅关闭本图的1项生产与3项来源。整体审计仍是 `incomplete_evidence`、退出1，不能据此宣称全套素材来源完整。

旧 `environment_map_clamped_contract.py` 保留“四张地表、field仍回退”的历史快照要求；新增田地不使其变绿。其隔离正向测试只在一次性旧快照夹具内移去新图，另有反例确保新图不能冒充旧安装完成。

## 画面与复现

真实Godot4.6.3 Forward+ Vulkan、1280×720下，冻结同一场景、人物和镜头，只切换field sampler。祝家庄与大名府各100%/150%均保存改前、改后、恢复三张图；44项检查通过。恢复后像素与改前完全一致；地形、碰撞、高度、地表权重/陆地mask及战役存档不变。其余六关及arena/skirmish不允许解析该图。

Codex检查原图与四组最终对照：旧田地的重复方块/稻茬纹样变为连续土质，人物、建筑、道路与标记仍可辨。150%下原生纹理较柔和。既有地形网格细缝、城墙占位画面和地图外黑边仍在；本批不声称修复这些问题，也不替代真人美术评价、实战或长期性能验收。

重新运行 `Play.cmd` 并重开“三打祝家庄”或“智取大名府”即可载入。使用 [SOURCE_SETUP](SOURCE_SETUP.md) 配好的Godot路径，首次先执行编辑器导入，然后运行：

```powershell
python -X utf8 -B tools/environment_art_audit.py
python -X utf8 -B tools/environment_validation_selftest.py
& $godotExe --path . --script res://tools/environment_field_render_qa.gd
```

审计预期退出1、隔离自测0、画面对照0；最后一项必须使用真实渲染器，并检查日志无 `SCRIPT ERROR` / `ERROR:`。报告与临时图片在 `.godot/environment_field_qa/`，已审核证据和失败尝试见 [本批QA](../qa/environment_field_20260906/README.md)。本批只同步源码和必要资源，没有导出或发布。

田地提交 `591479d` 已从全新无缓存Git检出复验：27项输入和24份证据字节匹配，静态/审计/自测退出码0/1/0，检出前后干净。另合入已发布野猪林 `fe70c4e`，保留双方文档并在合并源码上重跑44项画面、790/794项路由及40项自测；33个非冲突远端文件保持原内容。合并后29项输入及结果在QA的 `integration/receipt.json` 独立记录，初次快照保留原样。
