# 公孙胜日常身体原生验收

最终批`20261017_073848_e9c56ef5`：678项/164张原生截图、6548冻结输入零变化、22纹理实际PCK与冷导入一致；34张直接目检。范围为日常身体/肖像及相关图库/HUD、实际移动/发射/受击/倒地，以及登记黄泥冈/第5关装束分离。旧技能/火球与后期旧图不获本批原著认可。

- [原始收据](receipt.json)、[原生断言/截图报告](report.json)、[34图直接目检](direct_review.json)、[全164图SHA](all_screenshots.json)。
- `rejected_parse_20261017_072821/`保留首批解析失败；原因/处理见[runs.json](runs.json)，不混计通过。
- [实现/原著边界](../../docs/GONGSUN_SHENG_DAILY_20261017.md)；原图提示词分别位于两个`gongsun_sheng_daily_*sources_20261017`目录，运行图16张字节完全一致。

复现：`python -X utf8 -B tools/build_gongsun_sheng_daily_20261017.py`只读；完整新批`python -X utf8 -B tools/run_gongsun_sheng_daily_20261017.py --run --work-root <工程外目录>`，本机Godot配置/共享锁/私有档案不变。外部本批根`D:/CodexEvidence/shuihu/gongsun_sheng_daily_20261017/integration/`。

PCK 1212775020字节，SHA `371c8733669bdccd85a56ae91fbe4fa1cb738ea0d05e9b834ebedd972767bed7`，包/缓存/DLL/档案不进Git。共享锁释放。不是整个角色技能/所有UI/完整战役/续玩/平衡/性能/原生SDK/Steam/全部美术验收。
