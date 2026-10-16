# 公孙胜日常原稿来源检查

范围：18份内置 imagegen 原稿、31条引用；160项静态来源检查通过。见 [原始输出](source_check.json) 与 [实现/原著边界](../../docs/GONGSUN_SHENG_DAILY_SOURCES_20261017.md)。

来源/提示词：`assets/characters/gongsun_sheng_daily_sources_20261017/prompt_set.json`。全部原图已逐字节入库，3旧稿明确退回，15当前候选均未生产采用。

复现：`python -X utf8 -B tools/verify_gongsun_sheng_daily_sources_20261017.py`，只读，不生成/修改PNG。

没有本批 Godot、完整PCK、游戏内截图、SDK、Steam或整库美术验收。候选仍待动画/装备连续性、路由和原生验证。
