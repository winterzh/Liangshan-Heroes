# 源码设置与换机（2026-10-30）

本机开发目录为 `D:/AI项目/水浒/开发工程`，打开其中 `project.godot`；桌面旧目录仅为历史兼容入口。当前进度见[项目总览](PROJECT_STATUS.md)，开发顺序及完整要求见[开发计划](DEVELOPMENT_PLAN.md)，逐批证据见[开发日志](WORKLOG.md)和[目录索引](DIRECTORY_INDEX.md)。

## 启动与导入

使用 Godot **4.6.3**。在仓库根目录运行 `Play.cmd`；编辑器用 `Play.cmd -Mode editor`，仅导入用 `Play.cmd -Mode import`，强制重新导入加 `-Reimport`。启动器先检查导入缓存。

本机引擎路径依次来自 `-GodotPath`、`GODOT_PATH`、被忽略的 `godot.local.txt` 和 PATH。机器路径、SDK凭据及签名配置不写进生产脚本。81份资源导入配置和26份候选工具/预览源码已补交，详见[入库记录](../qa/pending_source_sync_20261020/README.md)；`.import`设置随资源入库，`.godot`缓存不上传。

## 换机与 Git 同步

在自己的 checkout 开发，不嵌套克隆。开工先运行：

```powershell
git status --short --branch
git remote -v
git fetch origin
```

目标仓库为 `https://github.com/winterzh/Liangshan-Heroes.git`，开发分支为 `codex/sync-20260905-stable`。工作区干净且未分叉时才 `git pull --ff-only origin codex/sync-20260905-stable`；有本地修改或分叉先核对来源，不自动stash、reset或覆盖。

每轮按实际修改做验证，更新WORKLOG及涉及的文档；检查远端、白名单差异、大小及敏感内容后逐文件提交推送，回读远端SHA。玩家存档、Steam登录/缓存、Godot缓存、安装包及无关历史备份不上传。main合并和平台发布按AGENTS.md及当次授权执行。

## 验证与共享引擎

10月30日运输开发按改动做必要专项，[分批来源与实现](TRIBUTE_CART_WHEEL_UNIT_20261018.md)统一导航；每批同一私有场景取得一次实际来源身份，再交给生产新游戏API，减少重复启动和扫描。最新[原车跟随与轮角接力](../qa/cart_follow_relay_20261030/README.md)只改2个运输脚本，95项/12图及来源/进程后验闭合；原地形/临时阻挡、真实接力/旧缓存夹具与首驱动失败分开记录。公孙胜生产配准仍用其本批`build_registration.py`复验，旧构建器对应原快照。完整美术过渡、续玩和整体验收继续，局部代码验证不等于整关或平台发布。

最新[人物标签联用专项](../qa/person_captions_20261030/README.md)只改共享提示层及Unit原标签资格两个脚本。一个原关卡保留20图与两项过严断言失败，窄英文容量/原白胜选择/消息隐藏只补三图，不重复原场景矩阵；同一来源后验重新闭合。拥挤时无空位收起属于当前设计，不将原失败改写为全通过。复验命令及原始驱动见该QA。

用户已取消全量52／61测试，后续按修改做必要的针对性检查；不自动恢复全量矩阵。现有27个进程39383项通过、取消及未运行范围见[原始收据](../qa/campaign_progress_recovery_20261026/daming_continue_candidate/evidence/negative_user_stop_20261027_183950/README.md)。10月28日用户另行授权发行包验收并更新Steam，已完成必要EXE与键鼠入口检查、Build26260970正式上线、四语公告、下载哈希及Steam库启动／退出验收；人工整关仍未计通过。[发布收据与原件](../qa/steam_release_20261028/README.md)。

调用Godot前检查已有进程和共享锁，等通道自然空闲并串行执行，不控制其他聊天的进程。使用与候选精确绑定的冻结、清单及自己的成功导入；默认命名来源检查只授静态结果。原失败存档和证据保留，复验使用逐字新副本，不把旧冻结的通过转授新源码。当前b22及大名府、持久化与各章节边界统一见[当前验证](../qa/campaign_progress_recovery_20261026/projectile_filter_candidate/VALIDATION.md)，具体执行命令留在相应QA目录。

## 旧快照和缓存恢复

本轮12个旧战役快照只去掉与最新b22缓存逐字相同的导入文件；复验前按[本轮映射与恢复器](../qa/storage_cleanup_20261027/README.md)补齐。最新b22缓存是恢复保留副本，后续清理不能直接删除。主缓存、各快照源码、独有缓存和原始QA/存档保留。

10月26日第二轮的三个旧快照按[既有映射](../qa/storage_cleanup_20261026_round2/README.md)恢复；上一轮54快照ZIP及9月7日7z已被用户删除，旧收据不代表当前仍有归档载荷。其他旧缓存按各批恢复说明补齐或用绑定Godot版本重新导入，不覆盖不同文件。

## 发布与历史

当前Steam Windows为Build26260970，冻结生产来源47168f00；见[更新记录](STEAM_UPDATE_20261028.md)及[发布指南](STEAM_RELEASE_GUIDE.md)。公开战役续玩未开放，经典固定30波保存/继续保留。源码同步、发行程序验证、平台上线与人工验收各自记录。

整理前的完整设置和历史工具状态保留于[Git提交5837d1bd](https://github.com/winterzh/Liangshan-Heroes/blob/5837d1bdc769f2847888a074f41b5c3d629c5529/docs/SOURCE_SETUP.md)，原10月20日文档归档说明见[历史全文与恢复](../qa/storage_cleanup_20261020/README.md)。专题入口见[文档导航](README.md)、[QA导航](../qa/README.md)及[GitHub约定](GITHUB_REPOSITORY.md)。
