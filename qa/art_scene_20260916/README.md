# 场景美术补全：黄泥冈松林（2026-09-16）

本批处理黄泥冈三种松树的旧白边/风格割裂：老松、并生松、斜松。原生图由同一网页端 ChatGPT 会话生成，保留 2×2 原始透明图集；工程内仅做四格裁切、比例缩放和 PNG 导入，未镜像、补画、抹像素或改玩法摆放。

- 原始图集：`assets/campaign/environment/art_scene_20260916/huangnigang_pines_source_20260916.png`
- Intake 脚本：`tools/intake_huangnigang_pines_20260916.py`
- 清单：`qa/art_scene_20260916/huangnigang_pines_manifest.json`
- 会话：`https://chatgpt.com/c/6aa954d2-8d40-83e9-abb6-e30963f8ae3c`
- 原图 SHA-256：`85b73fe79053103168346080f8f3bb933dd69a0fcacfa706f0b2dca7305993c8`

## 接入范围

保持既有运行时路径和 512×512 接口：

- `assets/campaign/environment/level1/huangnigang_pine_old.png`
- `assets/campaign/environment/level1/huangnigang_pine_double.png`
- `assets/campaign/environment/level1/huangnigang_pine_young_lean.png`

新图的树根、树冠和泥褐/暗松绿色阶与现有水浒 RTS 场景一致；黄泥冈作为《水浒传》开篇取生辰纲的荒冈古道，使用老松、并生松和斜松保留山冈古道识别度。旧 PNG 已在 Git 历史中保留，当前路径改为本批透明候选。

## 验证

- Godot 4.6.3 headless import：退出 0，无脚本错误。
- 1 倍速、1280×720、gl_compatibility、独立 APPDATA/LOCALAPPDATA/TEMP 图形捕获：`qa/art_scene_20260916/level1_capture/`。
- Level 1 场景契约：`checks.json` 全部通过（可达、寻路、选择、地表水位、芦苇隐蔽、属性阻挡；静态 FPS 约 222）。
- 人工查看 overview/detail/walk：三类松树均透明、无旧白底矩形；位置、大小和战斗逻辑未改变。

## 未在本批宣称完成

地表纹理接缝、其他旧树边缘、空白牌匾文字和 UI/特效仍按原台账继续排期；本批已关闭黄泥冈松林和梁山三种路由树木的场景缺口。

## 全库回归链接

- 全库美术 QA：`art_full_qa_receipt.json`，隔离导入和库存渲染完成，321 项库存通过。
- 源文件/采样回归：`art_full_source_contract.json`、`art_sampling_clip_selftest.json`。

## 梁山水泊树木场景统一

- 原始图集：`assets/campaign/environment/art_scene_20260916/liangshan_trees_source_20260916.png`；会话仍为同一网页原生生图会话。
- 清单、提示词与来源 SHA：`liangshan_trees_manifest.json`、`liangshan_trees_prompt.txt`。
- 确定性 intake：`tools/intake_liangshan_trees_20260916.py`；素材契约：`liangshan_trees_contract.json`（21/21）。
- 运行时路径：`assets/campaign/environment/level5/tree_broad.png`、`tree_young.png`、`willow_old.png`；三项校准已更新。
- Level 5 实景捕获：`level5_capture/`；可达、寻路、选择、地表、隐蔽、阻挡全部通过，人工检查轮廓/透明和场景协调性。
- 梁山树木运行时路由/脚底校准：`liangshan_trees_runtime.json`，15/15 通过；关卡外访问被拒绝。
