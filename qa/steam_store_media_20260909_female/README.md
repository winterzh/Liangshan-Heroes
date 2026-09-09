# 2026-09-09 新封面与配套媒体 QA

- `art_review.json`：独立实际目检main/header/small/library hero/16:9配图；root另看两张竖图及其他成品。小图额外看231×87显示预览，英雄横幅检查受工具显示缩放限制，未验收Steam客户端实际叠放。
- `PUBLISH_STATUS.json`：商店8张基础/简中封面上传并发布revision6（此前5），两语公开header新资源`df0980e3cc98f86583a5859efd44ae9589b04777`、460×215且加载完成，中文页已截图目检；公告新封面此前已保存并回读四语公开分享元数据。首次拖放受阻和无改动回读保留为历史，其余媒体逐项标明未上传、未发布。
- `video_review.json`：独立视频联系表/抽帧及五张截图的实际检查范围，以该文件记录为准，不扩大为真人完整试听。
- `upload_bundle.json`：五组22份最终文件复制后逐一SHA一致，仅证明本地上传包，不证明Steam公开投放。
- `../../marketing/steam_store_20260909_female/art_manifest.json`：交付PNG尺寸、SHA与语言副本；原图保持用户上传字节不变。
- `../../marketing/steam_store_20260909_female/video/`：当前已发游戏包录制来源、剪辑时间线、编码/完整解码/音量与截图QA。原始AVI和中间编码被.gitignore排除，不上传Git。

本批不修改游戏运行文件，未为纯营销PNG运行Godot功能回归。视频使用实际已发布包挂载录制；离线MovieWriter的30fps仅是输出帧率，不证明实时性能。

上一轮素材提交时，按项目既有规则为本批来源与证据关闭换行转换，日志保留FFmpeg原始空白。首次索引比对发现upload_bundle.json曾被默认转换为LF，随后仅重新暂存该文件恢复原字节；当时62份媒体/证据已再次核对Git索引与本地原字节一致。本次发布收据与交接文档的提交核对另行记录，不沿用该旧批结果。

商店8张封面已发布，公告800×450配图此前已更新；剩余6张库图、5张截图、45秒视频及1920×1080视频配图仍未上传、未发布。后续交接见[上传指引](../../marketing/steam_store_20260909_female/UPLOAD_GUIDE.md)。发布后View Diffs已回读无未发布差异；收据`store_capsules_published=true`与`store_media_published=false`分别表示商店8图完成和全套尚未完成。两语header公共回读不扩大为库Logo叠放、全部商店展示位置或视频真人试听验收；各类媒体继续单独记录。
