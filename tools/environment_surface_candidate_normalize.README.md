# 网页地表原图规范化候选

`environment_surface_candidate_normalize.py` 处理网页版 ChatGPT 下载的正方形地表 PNG。网页可能返回 1254×1254 RGB，而生产导入合同要求 2048×2048、PNG color type 6 的不透明 RGBA。这个工具只生成生产目录外的复核候选，不改 `assets/`、Steam 目录、冻结提示词、映射或既有导入证据。

允许的像素操作只有：

- 对整张 RGB 图追加恒定 `alpha=255`；
- 原图整体失败时，可显式搜索并选取一个连续、轴对齐的正方形原图矩形；
- 对完整原图或选中的单一矩形使用同一横纵倍率等比缩放到 2048×2048；
- 编码成 RGBA PNG；
- 另生成一张仅供查看的 3×3 缩略重复预览。

裁切只允许一个连续正方形矩形；不拼接对边，不 wrap，不 blend，不羽化。搜索使用固定的尺寸与偏移网格，报告明确记录候选数量、精确复核数量、选择矩形和最优失败矩形，不冒充逐像素穷举证明。工具没有镜像、旋转、连通块提取、像素清除、遮罩、补画、无缝修补、局部滤镜或局部调色入口。地表不需要透明补边，所以报告中的补边固定为零。非正方形图、带透明像素的 RGBA 地表和非 RGB/RGBA 图都会拒绝，不能用本地修图补救。

候选报告固定记录原图文件 SHA、原始解码像素 SHA、规范化文件与像素 SHA、稳定网页会话地址、冻结 prompt SHA、可选修正提示词文件与 SHA、输入输出尺寸和模式、缩放倍率、唯一允许的整图操作，以及所有禁用操作均未执行。报告的边缘与 3×3 指标直接复用 `environment_web_art_intake.py` 的 16 像素对边色差和跨边界梯度门槛。

示例：

```powershell
py -3 -X utf8 -B tools\environment_surface_candidate_normalize.py `
  --raw-png C:\path\surface_dry_earth.png `
  --batch-id surface_dry_earth `
  --conversation-url https://chatgpt.com/c/<stable-id> `
  --prompt-sha256 3345a6700ba6cfe38e54c0820d5871be23ad8d249b4b471879feca215431a1e0 `
  --correction-prompt-file C:\path\surface_dry_earth_attempt3_correction.txt `
  --allow-square-crop-search `
  --crop-min-size 896 `
  --candidate-dir C:\path\normalized_candidates\surface_dry_earth `
  --report C:\path\normalized_candidates\surface_dry_earth\report.json
```

边缘客观门槛通过时退出 0；候选和报告已安全生成、但边缘或重复门槛失败时退出 2；来源、合同或写入安全错误时退出 1。退出 0 也只表示候选可进入独立人工复核，不代表已经采用、接入游戏或通过 100%/150% 实机视觉检查。

隔离自测：

```powershell
py -3 -X utf8 -B -m py_compile `
  tools\environment_surface_candidate_normalize.py `
  tools\environment_surface_candidate_normalize_selftest.py

py -3 -X utf8 -B tools\environment_surface_candidate_normalize_selftest.py
```
