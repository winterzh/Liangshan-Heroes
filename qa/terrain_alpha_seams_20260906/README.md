# 地表透明缝 QA

基线 `661e8d1`，生产改动仅自然地表shader的8行。旧shader由原Git对象保存，实际图集/地表PNG未编辑。原始图与输入哈希在 `receipt.json`，范围及复现见 [实现说明](../../docs/TERRAIN_ALPHA_SEAMS_20260906.md)。

| 验证 | 结果 | 证据 |
|---|---|---|
| 同场景实机与RGBA透明度 | 86项通过 | `render.json`、`terrain_alpha_seam_qa.log` |
| 八关自然地形/寻路隔离 | 90项通过 | `natural_contract.json`、`terrain_alpha_natural.log` |
| 静态/运行环境路由 | 790/794通过 | `router.json`、`runtime_routes.json` |
| 环境验证器反例 | 40项通过 | `selftest.json`、`terrain_alpha_selftest.log` |
| 生产资源/来源审计 | 37匹配、32缺图、0错误、249缺口，退出1 | `audit.json` |

## 确认根因

`diagnosis/` 是同一祝家庄场景150%缩放的旧shader诊断。只恢复图元alpha，地面上2,676个变化像素全部匹配旧图集alpha下降位置，其他位置0像素改变；结果见 `pixel_analysis.json`。地形网格并没有被扩大来遮缝，也未编辑图片。

- [场景改前](diagnosis/scene_before.png) · [场景修复](diagnosis/scene_after.png)
- [单独地面改前](diagnosis/terrain_before.png) · [单独地面修复](diagnosis/terrain_after.png) · [旧atlas alpha诊断](diagnosis/atlas_alpha.png)

GPU合成透明度夹具在独立128×64透明SubViewport渲染：两组顶点alpha为1/0.5，贴图左右alpha为0.25/1。旧值 `[0.25,1,0.125,0.5]` 复现污染，新值 `[1,1,0.5,0.5]` 消除图集影响；节点alpha设0.6后仍是 `[0.6,0.6,0.3,0.3]`。允许8位alpha量化误差0.02，关闭自然地表时旧/新RGBA逐像素一致。夹具是程序生成测试纹理，不是生产美术。

## 八关真实场景

Forward+ Vulkan、RTX3070Ti、1280×720。场景、人物与镜头冻结，隐藏HUD和迷雾覆盖层；每组旧→新→旧恢复相同像素，draw calls完全一致。田地两关另检查150%缩放。格子、碰撞/动态占地、高度、地表权重和陆地mask及存档均未变化；自然地形90项另核验三类通行配置与寻路权重。

- [黄泥冈改前](level1_100_before.png) · [改后](level1_100_after.png)
- [江州改前](level2_100_before.png) · [改后](level2_100_after.png)
- [祝家庄100%改前](level3_100_before.png) · [改后](level3_100_after.png)；[150%改前](level3_150_before.png) · [改后](level3_150_after.png)
- [连环马改前](level4_100_before.png) · [改后](level4_100_after.png)
- [梁山改前](level5_100_before.png) · [改后](level5_100_after.png)
- [野猪林改前](level6_100_before.png) · [改后](level6_100_after.png)
- [快活林改前](level7_100_before.png) · [改后](level7_100_after.png)
- [大名府100%改前](level8_100_before.png) · [改后](level8_100_after.png)；[150%改前](level8_150_before.png) · [改后](level8_150_after.png)

Codex检查各关画面，地表斜向分块线改善且道路/人物/结构仍可辨。黄泥冈右下白色枣车占位在旧图中也存在，不能计为本批修复。原有场景层细线、个别贴图占位和真人观感仍单独跟进。这些是冻结视图，不是实战帧率或长期性能证明；没有导出、Steam写入或发布。
