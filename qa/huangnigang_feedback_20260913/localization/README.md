# 黄泥冈反馈修复：本地化检查

本次仅修改 `assets/localization/campaign.json` 与生成的 `catalog.json`，新增 **25 个中文查询键及其 75 条译文**：3 条新行为提示，22 条同关卡原有缺漏。英文、日文写入既有 campaign 分片；繁中按既定 OpenCC `s2twp` 流程生成并读回。旧查询键保留，不删除仍可能被旧入口引用的译文。

三条新提示对应：基类 `wine_arrival` 目标、short `deploy_hint`、基类 `deploy_hint`。均说明盘问后白胜自行挑酒入松阴、可随时接管；目标提示同时保留接管后右键落担旗标继续的操作说明。后续酒计与搬运仍需玩家指挥。

最终严格合并 **exit 0**：词库 4428 条、campaign 分片 1678 条，11 个既有冲突均由 glossary 解决，未解决冲突为 0。完整脚本扫描的格式/占位符/换行错误为 0；两个黄泥冈脚本的中文显示源均已有译文。

**全库完整覆盖检查仍为 exit 1**：初检 32 条缺漏中，本次补齐 24 条黄泥冈文本，另新增并翻译 1 条基类部署提示；其余 8 条为继续槽确认、城防信息、祝家庄及大名府旧文案，按本轮分工保留，不改 exclusions，不把它们算作已通过。新增基类提示替换了源码中的旧提示，但旧译文保留，所以源字符串总数不变而词库总数增加 25。

记录：

- [coverage_before.json](coverage_before.json)：本轮修改前全库覆盖结果。
- [merge.json](merge.json)：最终 `build_localization.py --strict` 原始报告。
- [coverage_after.json](coverage_after.json)：最终全库完整覆盖结果，原样保留 8 条缺漏。
- [scope_validation.json](scope_validation.json)：本轮 25 键三语译文、两生产文件 SHA/字节数、实际命令与退出码、范围及限制。

本机实际命令：

```powershell
py -3.13 -X utf8 -B tools/build_localization.py --opencc-path E:/CodexTemp/huangnigang_feedback_20260913/localization_deps --strict --report qa/huangnigang_feedback_20260913/localization/merge.json
py -3.13 -X utf8 -B tools/localization_catalog.py --validate assets/localization/catalog.json --require-complete --report qa/huangnigang_feedback_20260913/localization/coverage_after.json
```

构建依赖 `opencc-python-reimplemented==0.1.7` 安装在上述工程外私有路径；其他机器可按项目文档使用自己的依赖目录。没有把依赖包放入生产工程。

本记录只证明翻译内容、严格合并和静态覆盖检查；没有运行 Godot，没有验证原生字体、换行布局或玩家存档，没有操作 Git。运行时及实际行走验证由同轮其他 QA 单独记录。
