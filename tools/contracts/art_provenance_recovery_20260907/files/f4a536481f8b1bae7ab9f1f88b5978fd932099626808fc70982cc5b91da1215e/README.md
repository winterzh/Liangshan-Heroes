# 大名府囚犯四方向重建批次

日期：2026-09-03

## 范围

本批先重建复用审计中允许 `REBUILD_RECT` 的四项：

- `daming_bound_lu_junyi / idle`
- `daming_bound_shi_xiu / idle`
- `daming_rescued_shi_xiu / idle`
- `daming_rescued_shi_xiu / walk`

`daming_rescued_lu_junyi / idle, walk` 仍按审计结论另行网页重画，不把旧切片直接升级为合规生产素材。

## 原著边界

采用百二十回本第六十六回“大名府元夜月灯，梁山泊好汉劫牢”上下文：卢俊义、石秀先为牢中囚犯，元宵劫牢时被救出。游戏用“戴木枷、旧长袖囚衣”表达被缚状态，解救后去枷去绳但保持同脸同衣；不改成铠甲武将，不画现代服装，不增加原著没有的重伤、断肢或夸张血腥。

## 来源与取舍

- 卢俊义六行源图：`Liangshan-Heroes/assets/campaign/source/web_lu_junyi_states_v1.png`
- 石秀六行源图：`Liangshan-Heroes/assets/campaign/source/web_shi_xiu_states_v1.png`
- 石秀枷囚 NW 修正版：`Liangshan-Heroes/assets/campaign/source/web_shi_xiu_bound_nw_v2b.png`
- 原始提示词、会话地址、源图 SHA-256 与旧验收记录保存在 `assets/campaign/web_art_manifest.json`。

石秀六行源图第1行第4格实际朝 NE，明确判退；NW 只采用有独立来源链的 `v2b`。走路只取原验收确认的第3、4行两张关键姿态，第5、6行不冒充完整四帧循环。

## 本地处理边界

本批只允许：读取既有 RGBA、连续矩形裁切、等比缩放、透明补边、两帧横排、PNG/JSON 编码和逐字节复制。不得镜像、补画、遮罩、按连通域抠图、清除 alpha 像素或重建缺失肢体。石秀独立 NW 补图整张作为一个矩形缩放，不再抠人。

生产接入前必须完成人工候选图检、备份、Godot 导入与运行合约、图形实拍、覆盖审计和文档回写。本批不导出，不修改 Steam 发布目录。
