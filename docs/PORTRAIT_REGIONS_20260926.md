# 旧头像图集裁切修正 · 2026-09-26

## 原因与修改

旧头像入口将所有 1200×1200 图集按 400×400 三等分，但部分原图的行列分界并不在 400/800。例如第七张第二行实际从约 414 开始，多幅后期图集第三行从约 778 开始。原裁切因此会包含相邻头像，或切掉本人的头饰上缘。

新增 `scripts/portrait_atlas_regions.gd`，为第 7、10–18 张图集中仍在使用的 81 个头像记录独立区域。`Art.portrait_texture` 在独立头像之后查询此表，保留缓存、边缘过滤裁切和旧图集回退。图鉴与 HUD 继续共用 `ui_portrait_texture`。

十张原 PNG 保持原字节；没有生成、重画或本地加工图片。角色身体、四向动作及世界图集的取图函数没有修改。区域尺寸允许不完全相同，显示沿用居中保留比例，避免拉伸脸型。

## 来源与复验

- `tools/contracts/portrait_regions_20260926/manifest.json`：十张原图哈希、81 个旧区域/修正区域。
- `tools/run_portrait_regions_qa.py`、`tools/portrait_regions_qa.gd`：冻结源码、私有用户目录、串行 Godot 导入及图鉴/HUD 检查。
- 运行：`python -X utf8 -B tools/run_portrait_regions_qa.py --work-root <工程外目录> --run`。可指定来自同工程、同引擎的成功导入批 `--cache-from`，仍执行新导入。
- [QA 记录](../qa/portrait_regions_20260926/README.md)：实际结果、新旧裁切及小尺寸截图、目检范围。

## 边界

本批只修正已有画面的裁切。原图里已经缺失的帽尖、肩部或武器不能靠扩大区域恢复；仍须独立重绘。相似脸型、纸纹与画法差异、头像服饰与四向身体的对应继续按人物逐项处理，不能以区域唯一或自动检查通过代替造型验收。全量进度见 [美术完善记录](ART_COMPLETION_20260926.md)。
