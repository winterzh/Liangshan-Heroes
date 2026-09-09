# 2026-09-09 新封面与配套媒体 QA

- `art_review.json`：独立实际目检main/header/small/library hero/16:9配图；root另看两张竖图及其他成品。小图额外看231×87显示预览，英雄横幅检查受工具显示缩放限制，未验收Steam客户端实际叠放。
- `PUBLISH_STATUS.json`：商店旧拖放页面的真实失败、重载确认无改动；最新公告新封面通过普通选择器上传保存，四语公开分享元数据和公开PNG回读。两类结果分开记录。
- `video_review.json`：独立视频联系表/抽帧及五张截图的实际检查范围，以该文件记录为准，不扩大为真人完整试听。
- `upload_bundle.json`：五组22份最终文件复制后逐一SHA一致，仅证明本地上传包，不证明Steam公开投放。
- `../../marketing/steam_store_20260909_female/art_manifest.json`：交付PNG尺寸、SHA与语言副本；原图保持用户上传字节不变。
- `../../marketing/steam_store_20260909_female/video/`：当前已发游戏包录制来源、剪辑时间线、编码/完整解码/音量与截图QA。原始AVI和中间编码被.gitignore排除，不上传Git。

本批不修改游戏运行文件，未为纯营销PNG运行Godot功能回归。视频使用实际已发布包挂载录制；离线MovieWriter的30fps仅是输出帧率，不证明实时性能。

交接见[上传指引](../../marketing/steam_store_20260909_female/UPLOAD_GUIDE.md)。商店媒体未完成上传、转码、排序、发布和公开回读前，状态继续保留pending/blocked，不以本地校验替代。
