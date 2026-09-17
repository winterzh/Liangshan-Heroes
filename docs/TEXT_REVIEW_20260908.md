# 游戏文本与图鉴校订

本轮以一百二十回本《忠义水浒全传》为生平依据，按人物相关回目核对身份、入伙经过、代表事迹与结局。采用的公版正文入口为[维基文库一百二十回本](https://zh.wikisource.org/zh-hans/水滸傳_(120回本))。征田虎、王庆等情节属于此版本，不能直接用七十回本或百回本的回次与结局覆盖。

图鉴生平保留有据的经历，删去无依据的身世、绰号词源、心理活动和寿终推断；出处随每篇生平显示。游戏中的战斗能力、数值、扩展兵种，以及关卡组织和对白属于改编，图鉴与选关页均有说明。通行字形与版本异文存在差别的星号在核查记录中注明，不凭单一网页字形直接改名。

## 维护位置

- `scripts/lore_data.gd`：108 人校订生平与 `CHAPTERS` 回目索引。
- `scripts/bios.gd`：简述、备用小传、星号与座次；`scripts/defs.gd` 与关卡脚本保留显示文案的实际使用位置。
- `assets/localization/lore_*.json`：校订生平英日译文。其他译文在原有分片与 `text_review_ui.json` 中；繁体仍由 OpenCC 重建。
- `qa/text_review_20260908/`：每人的核查依据、逐条替换、应用收据、原文来源索引及运行证据。原著整部正文缓存位于忽略的 `scratchpad/`，不随游戏打包。

先核对中文事实，再同步该源字符串对应的英语、日语，最后重建繁体与运行词库。不能只修改生成的 `catalog.json`。人名在长段落与单独标签中使用同一套日文字形；聚义厅的英文统一为 Hall of Brotherhood，忠义堂为 Hall of Loyalty。

本轮批量应用工具要求两份 54 人核查均完整，按 GDScript 字符串解码值精确替换，拒绝来源漂移或占位符变化；默认只读，显式 `--apply` 才写入。再次运行历史替换前需确认它仍适用于当前文本。

```powershell
py -3.14 -X utf8 -B tools/apply_text_review.py
py -3.14 -X utf8 -B tools/apply_text_review.py --apply
py -3.14 -X utf8 -B tools/normalize_localization_names.py --apply --report scratchpad/text_review/names.json
py -3.14 -X utf8 -B tools/build_localization.py --opencc-path scratchpad/localization/deps --strict --report scratchpad/text_review/merge.json
py -3.14 -X utf8 -B tools/localization_catalog.py --validate assets/localization/catalog.json --require-complete --report scratchpad/text_review/coverage.json
```

## 排版与验证

主菜单入口在当前四语窗口下完整排布，并在高度不足时滚动；驻守、选关与自定义配置弹层允许滚动，返回按钮固定在左上角。编辑器顶栏可以换行，场景工具栏独立滚动，名称列固定宽度并换行，避免译名改变每行数值列的位置。场景分类先翻译再拼计数；内建单位名显式翻译，自编名在按钮、下拉和弹出菜单中禁用二次自动翻译。地形、阵营、单位与装饰选择提示分别翻译前缀和名称。结算说明自动换行，战绩列表使用剩余高度，底部操作保持可达。全页弹层使用实色背景以免底层文字干扰阅读。

`run_localization_qa.py --mode review` 检查二级菜单、设置、成就/工坊页面、编辑器、全部图鉴条目宽度并截图；`--mode combat-review` 检查竞技场、驻守和对战 HUD、全部技能说明卡与长结算页。`--resolution 1024x768` 可检查 4:3 窗口；游戏使用原有画布缩放规则。实际截图建议加 `--visible`，所有模式均使用隔离用户目录。

`--mode contract --baseline-revision 675d3d7cff17378e159891cd1c0616200dbaa817` 将当前单位和技能定义与本轮之前的明确 Git 快照比较：忽略显示名和技能说明，逐项比较其余字段；另检查 108 个唯一座次和每人的生平出处。

具体通过项、保留的失败复现、逐张查看的截图与人工审读边界见 [QA 记录](../qa/text_review_20260908/README.md)。本轮源码同步不代表 Steam 包更新。

本机临时目录 `scratchpad/` 由 `.gdignore` 阻止 Godot 扫描，并在导出预设中排除。保留该标记；否则历史脚本可能覆盖当前全局类。Windows PCK 的目录排除与四语启动已验证，详见本批 QA。
