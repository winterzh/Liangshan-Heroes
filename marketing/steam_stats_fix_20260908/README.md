# Steam统计修复公告草稿

本目录只提供四语公告初稿，尚未填写Steam后台或发布。发布负责人需在本次更新同包验证、上线状态核验后采用文案。`copy.json`沿用上一批公告格式：`schinese`、`tchinese`、`english`、`japanese`各含`title`、`subtitle`、`summary`、`body_bbcode`。

文案范围：统计读取失败处理、连续游玩时保存状态误判、Steam统计校正后的本局停止集计和重启提示。发行包包含只读桥接属于实现细节，不写进玩家公告。正文明确说明战斗中途保存与继续尚未开放，经典30波及八关仍待统一验收；没有宣称持久云同步、断网重启后补传、统计绝不丢失或续玩已经交付。

复用此前已验收的无文字800×450封面：`docs/steam_announcement_20260901/event_cover_800x450_english_v2.png`。既有Steam封面地址：`https://clan.fastly.steamstatic.com/images/46272698/2105fa26234a9377723de86a7519262f3f5949cb.png`。历史采用记录见`docs/STEAM_LOCALIZATION_ANNOUNCEMENT_20260908.md`；本批未生成、编辑或上传图片。正文没有图片占位符，可直接使用四语BBCode，封面需由发布负责人在本次活动中设置。

字段长度沿用上一批限制：标题最多80字符，副标题最多120字符，摘要最多180字符；正文使用成对的`h2`和`list`标签。四语JSON形状、长度、BBCode标签配对、三条更新项目以及无残留图片占位符均已通过静态检查；该检查不代表Steam后台保存或发布。

| 语言 | 标题 / 80 | 副标题 / 120 | 摘要 / 180 | 正文 |
| --- | ---: | ---: | ---: | ---: |
| schinese | 16 | 15 | 54 | 274 |
| tchinese | 16 | 15 | 54 | 274 |
| english | 44 | 58 | 151 | 847 |
| japanese | 22 | 22 | 76 | 374 |

封面文件的PNG尺寸已回读为800×450，SHA-256为`508a9c882c68579ebdcc4832890f83ccd36448269ade8347b027bfdb035a56da`。`copy.json` SHA-256为`ab474e4029d636eb95229bf091eadbe7c951a658e1c00704396d961fd5054d9c`。未执行浏览器、Godot或Git操作。
