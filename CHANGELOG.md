# 更新记录与版本入口

Steam Build、Git源码提交、版本标签及GitHub Release各自记账。源码里有新提交或新候选，不代表玩家已收到更新。

## 2026-10-28 · Steam Windows Build26260970

- 完善黄泥冈七辆原车、十一担财物的取车→推空车→装载→交付，以及倒地后幸存者接力和重复交付保护。
- 改善任务面板、队伍选择、多选指令栏、悬浮提示下Esc暂停和四语提示。
- 正式default、四语公告、全新下载／Steam库六文件哈希及实际客户端启动／退出已核验。完整战役续玩候选未采用，未重跑全量测试，人工整关通关未计通过。

[更新与验证范围](docs/STEAM_UPDATE_20261028.md) · [四语公开公告](https://store.steampowered.com/news/app/5088120/view/680765564125184330) · [最终交付收据](qa/steam_release_20261028/delivery_complete.json)

## 2026-10-20 · Steam Windows Build26048429

- 调整部分人物形象、兵器及技能图标，更新部分待机/行走/攻击/受击/倒地动作。
- 改善黄泥冈携车、货物与车轮表现，更新快活林酒肆/摊位/植被。
- 修正窄窗口技能栏及换选时旧控件残留。

[完整更新与实际验证范围](docs/STEAM_UPDATE_20261019.md) · [四语公开公告](https://steamcommunity.com/games/5088120/announcements/detail/669505296465397048) · [发布QA](qa/steam_release_20261019/README.md)

生产冻结来源0083b47a；后继主线提交补QA、候选保存与仓库文档，不改变已发布游戏包。完整战役续玩尚未开放，全库美术、完整流程、真人/性能/设备验收仍待完成。

## 2026-10-20 · 源码与仓库收尾

- 补齐主线合并、发布记录和首页当前状态。
- 精简六份入口文档，完整历史归档；清理有相同保留副本的重复缓存。[清理记录](qa/storage_cleanup_20261020/README.md)
- 原107个待提交文件已全部保存：81份资源导入配置、26份未采用候选工具/预览源码。[入库记录](qa/pending_source_sync_20261020/README.md)
- 整理首页、文档/QA导航、历史版本索引及协作/反馈入口。[仓库约定](docs/GITHUB_REPOSITORY.md)

## GitHub历史安装包

以下按2026-10-20 GitHub API实际回读整理，日期为平台记录的UTC发布日期。15个Release保留原附件与地址；**Android v2.0的Latest标识只针对这些GitHub Release，不表示当前Steam Windows版本。**

| GitHub Release | 发布日期（UTC） | 现有安装包平台 |
| --- | --- | --- |
| [v2.0](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v2.0) | 2026-09-25 | Android |
| [v1.8](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.8) | 2026-08-10 | Android / Windows / macOS |
| [v1.7](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.7) | 2026-07-21 | Android / Windows / macOS |
| [v1.6](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.6) | 2026-07-15 | Android / Windows / macOS |
| [v1.5.2](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.5.2) | 2026-07-13 | Android / Windows / macOS |
| [v1.5](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.5) | 2026-07-13 | Android / Windows / macOS |
| [v1.4.0](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.4.0) | 2026-07-12 | Android |
| [v1.3.5](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.3.5) | 2026-07-10 | Android / Windows / macOS |
| [v1.3.3](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.3.3) | 2026-06-29 | Android / Windows / macOS |
| [v1.3.2](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.3.2) | 2026-06-29 | Android / Windows / macOS |
| [v1.3](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.3) | 2026-06-28 | Android / Windows / macOS |
| [v1.2](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.2) | 2026-06-28 | Android / Windows / macOS |
| [v1.1.1](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.1.1) | 2026-06-25 | Android / Windows / macOS |
| [v1.1](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.1) | 2026-06-25 | Android / Windows / macOS |
| [v1.0](https://github.com/winterzh/Liangshan-Heroes/releases/tag/v1.0) | 2026-06-24 | Android / Windows / macOS |

## 标签与历史源码

仓库现有38个[版本标签](https://github.com/winterzh/Liangshan-Heroes/tags)，本次不移动、重打或删除。`v2.0.1`目前有源码标签，但未出现在上述Release列表，不能据标签宣称新的安装包已发布。当前开发源码从[main](https://github.com/winterzh/Liangshan-Heroes/tree/main)进入，历史全文和旧批次证据仍保留。
