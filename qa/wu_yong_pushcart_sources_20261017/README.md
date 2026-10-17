# 吴用推车来源与选格检查

8份内置imagegen原PNG、24引用SHA及完整提示词在`assets/characters/wu_yong_pushcart_sources_20261017/`，`.gdignore`隔离。5个当前候选提供四向×待机/四阶段步态共20个视图；未选contact A、contact B/v2完整保留。`manual_review.json`记录主代理直接查看原生成图的结论，不声称独立审查。

`report.json`由只读`tools/verify_wu_yong_pushcart_sources_20261017.py`实际生成。它核对原字节、当前可访问的8个外置原始生成文件、24引用、RGBA尺寸、全图及选格角点alpha0、强alpha分隔轴/边界和目检来源绑定。外置生成路径在其他机器不可用时不会冒称已回读原文件；仓库字节/引用仍须核对。

20选格并非等分整图：使用真实透明空隙的Atlas边界。passing B的分格点从低透明污染处移到同一空隙中的零角点，未改PNG。分隔轴仍有alpha1—5的低透明像素，不能宣称所有背景全透明或原生过滤通过。

车体大小和罩布/绳结逐稿变化、四阶段连接/轮转、血条、原任务回调、其他人物隔离及PCK原生效果尚未验收。`runtime_adopted=false`、`native_launched=false`如实保留；本批未修改生产接入、关卡、存档、main或Steam。后续按[来源说明](../../docs/WU_YONG_PUSHCART_SOURCES_20261017.md)继续接入。
