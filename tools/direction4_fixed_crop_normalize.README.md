# 四向网页原图固定矩形候选管线

`direction4_fixed_crop_normalize.py` 只生成候选，不写生产素材。它支持 4×4 的 `fixed_cell_rect_v1` 和单行四向的 `fixed_direction_row_rect_v1`，只执行四种操作：固定矩形裁切、整单元透明补边、整单元等比缩放、写入候选目录。

工具禁止镜像、连通域归属遮罩、清零或修改格内像素、补画、局部改方向和像素合成。连通域只用于只读检查：每个固定矩形必须完整包含本格的大主体，同时不能包含另一格的大主体。标签不会参与输出像素计算。

规范 JSON 必须记录：

- 原始 PNG SHA-256 和稳定的网页版 ChatGPT 会话地址；
- 基础提示词文件与 SHA-256；
- 可选的纠正提示词文件与 SHA-256；
- 16 个格子的角色、动作、方向、固定 `crop_rect`；
- 每格脚或马蹄的源图语义锚点；
- 画布、缩放、透明补边和只读可见像素阈值。

默认命令只做 dry-run：

```powershell
py -3.14 -X utf8 -B tools\direction4_fixed_crop_normalize.py `
  --source C:\path\raw.png `
  --spec C:\path\fixed_rect.json `
  --output-dir C:\path\candidate_png `
  --manifest C:\path\candidate_manifest.json
```

检查结果合格后，用 `--write-candidate` 写候选。工具拒绝把输出或清单写进 `assets/`、Steamworks 或 `Liangshan_5088120`。已有候选不会覆盖，除非明确加 `--overwrite-candidate`。

候选清单逐帧记录 raw crop RGBA SHA、裁切矩形、行统一缩放倍数、缩放前透明补边、输出尺寸、贴入坐标、最终四边透明补边、源锚点与落点、完整主体像素数、外来大主体像素数。候选通过不等于原著美术通过，也不等于可接入生产。

正式首批入口并列支持两条来源规则，互不放宽：

- `transparent_grid_v1` 继续要求贯穿整图的真透明网格缝，采用后才有生产提交路径；
- `fixed_cell_rect_v1` 要求 16 个独立固定源矩形，矩形可相互重叠，但每张输出不得遮罩、清零或带入另一格大主体。它始终只生成“待人工复核的采用候选”，没有 `--commit` 路径。
- `fixed_direction_row_rect_v1` 要求同一人物与动作的 SE/SW/NE/NW 四格固定矩形，用于替换一个已知基础图集行；同样只有候选路径，不改变战役造型隔离规则。

固定矩形候选的正式来源清单还绑定原始 SHA、网页版会话地址、基础提示词 SHA、可选纠正提示词 SHA、裁切规范 SHA、候选清单 SHA，以及后续动作对已选待机原图 SHA 的引用。逐帧报告会重算输出字节和半透明彩边统计。彩边超过阈值只会标记人工视觉复核，不会自动清除像素或自动采用。

```powershell
py -3.14 -X utf8 -B tools\direction4_first_sample_intake.py `
  --fixed-candidate-manifest C:\path\fixed_cell_rect_candidates.json `
  --report qa\direction4_fixed_crop_20260902\formal_candidate_intake_report.json
```

自测：

```powershell
py -3.14 -X utf8 -B tools\direction4_fixed_crop_normalize_selftest.py
py -3.14 -X utf8 -B tools\direction4_fixed_candidate_intake_selftest.py
```
