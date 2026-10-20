# 水浒英雄传：八幕战役

Liangshan Heroes · 基于 Godot 4.6.3 的水浒题材即时战略项目。

人物、兵器、服饰与剧情调整先核对《水浒传》百二十回本，具体动作编排、配色与招式数值属于游戏表现。**游戏已有发布版本，完整开发计划仍在进行。**

## 当前版本（2026-10-20）

| 入口 | 版本与用途 |
| --- | --- |
| [Steam Windows](https://store.steampowered.com/app/5088120/) | 正式 default Build **26048429**；[本次更新](docs/STEAM_UPDATE_20261019.md) · [四语公告](https://steamcommunity.com/games/5088120/announcements/detail/669505296465397048) |
| [main](https://github.com/winterzh/Liangshan-Heroes/tree/main) | GitHub默认源码入口，已包含全部提交；后继QA和文档不等于新的Steam构建 |
| [GitHub Releases](https://github.com/winterzh/Liangshan-Heroes/releases) | 历史安装包；最新Release为 **Android v2.0**，与Steam Windows版本分别记录 |

本次Steam更新涉及部分人物形象、兵器与动作、黄泥冈推车和货物、快活林酒肆/植被，以及窄窗口英雄技能栏。完整战役续玩尚未开放；中途保存/继续仍仅支持经典固定30波据守。

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
