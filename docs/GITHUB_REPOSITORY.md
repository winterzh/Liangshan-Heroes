# GitHub仓库约定（2026-10-20）

## 分支与入口

仓库：[winterzh/Liangshan-Heroes](https://github.com/winterzh/Liangshan-Heroes)。默认分支`main`，开发同步分支`codex/sync-20260905-stable`；本次收尾二者内容一致，实际SHA以分支回读为准。本机当前工作区为main，后续分支选择、合并和发布遵循AGENTS.md及用户当次授权。

保留这两个有明确用途的分支。2026-10-20回读无开放PR或Issue；旧合并记录保留，不以另建空PR或删除历史制造整理结果。

## 版本、标签与Release

- Steam Windows当前交付记录为Build26048429，完整内容与收据从[更新记录](../CHANGELOG.md)进入。
- GitHub有15个历史Release、38个源码标签；现有Latest是Android v2.0，v2.0.1为源码标签，无对应GitHub Release。本次只建索引，不创建新发布或移动标签。
- `qa/`中的候选、保存成功的源码、局部检查和已发布产品分开记录；完整战役续玩仍未开放。

首页负责玩家/开发入口，CHANGELOG负责版本索引，docs/README负责文档导航，qa/README负责证据导航。文件结构保持现有Godot路径，专题和来源不批量迁移。

## 仓库About与管理权限

当前协作者具有push/triage权限，没有admin/maintain。默认分支已是main；About简介、官网和topics目前为空，需要仓库管理员设置，本次未写入。准备的管理字段如下：

| 字段 | 建议内容（尚未应用） |
| --- | --- |
| Description | 基于Godot 4.6.3的水浒题材即时战略游戏，人物与剧情依据《水浒传》百二十回本。 |
| Website | `https://store.steampowered.com/app/5088120/` |
| Topics | `godot`、`gdscript`、`real-time-strategy`、`water-margin` |

当前分支无保护规则。分支保护、协作者和可见性属于管理员设置，本次没有改变这些权限或规则。

## 本次整理与历史

本次更新首页、版本记录、协作说明、文档/QA导航和问题模板，补充当前Build示例、运行来源和原著依据；当前源码与Steam构建保持。[本批仓库快照](../qa/github_organization_20261020/README.md)。旧文档与缓存整理分别见其原收据，历史Release附件与Git历史保留。
