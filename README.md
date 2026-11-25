# 水浒英雄传：八幕战役

Liangshan Heroes · 基于 Godot 4.6.3 的水浒题材即时战略项目。

人物、兵器、服饰与剧情调整先核对《水浒传》百二十回本，具体动作编排、配色与招式数值属于游戏表现。**游戏已有发布版本，完整开发计划仍在进行。**

## 当前版本（2026-11-24）

| 入口 | 版本与用途 |
| --- | --- |
| [Steam Windows](https://store.steampowered.com/app/5088120/) | 正式 Build **26873421**。[更新详情](docs/STEAM_UPDATE_20261124.md) · [四语公告](https://store.steampowered.com/news/app/5088120/view/680767470935475624) |
| [main](https://github.com/winterzh/Liangshan-Heroes/tree/main) · [开发分支](https://github.com/winterzh/Liangshan-Heroes/tree/codex/sync-20260905-stable) | 正式版生产源码为 `ee9f29f5`，版本说明和验收记录与源码一并维护。 |
| [GitHub Releases](https://github.com/winterzh/Liangshan-Heroes/releases) | GitHub 历史安装包，平台和版本见[更新记录](CHANGELOG.md)。 |

Windows 离线试玩候选 `ee9f29f5`。完整解压，把 EXE 与 PCK 留在同一目录，再双击 `Start Local Playtest.cmd`。[试玩步骤](docs/PLAYTEST_CHECKLIST_20260906.md)

开发分支的 Windows 战役多页开场可点「跳过对话」进入备战。回车每次继续一页，到备战后照常点「开战」。[开发版操作记录](qa/battle_entry_timing_20261116/windows_dialogue_skip_04a227d6.json)

## 从这里开始

| 你要做什么 | 入口 |
| --- | --- |
| 看目前做到哪里 | [项目总览](docs/PROJECT_STATUS.md) |
| 看接下来的工作 | [开发计划](docs/DEVELOPMENT_PLAN.md) |
| 看版本和更新记录 | [更新记录](CHANGELOG.md) |
| 下载源码、启动和换机 | [源码设置](docs/SOURCE_SETUP.md) |
| 查设计、实现和来源 | [文档导航](docs/README.md) |
| 查已验证范围、候选和失败记录 | [QA导航](qa/README.md) |
| 报问题或参与开发 | [Issues](https://github.com/winterzh/Liangshan-Heroes/issues/new/choose) · [协作说明](CONTRIBUTING.md) |

## 源码启动

需要Godot **4.6.3**。在仓库根目录运行 `Play.cmd`，进入编辑器用 `Play.cmd -Mode editor`。引擎路径配置见[源码设置](docs/SOURCE_SETUP.md)。Steam安装包不存放在源码目录。

当前保留 `main`（主线）和 `codex/sync-20260905-stable`（开发同步）两个分支；提交时保留候选与生产的状态区别。分支、标签和Release说明见[仓库约定](docs/GITHUB_REPOSITORY.md)。历史文档全文仍可[查询与恢复](qa/storage_cleanup_20261020/README.md)。
