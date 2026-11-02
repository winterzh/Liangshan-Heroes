# 生成副本只保留最新有效版

用户于 2026-11-02 明确要求：水浒按同样规则清理，旧版本只留最新的，生成新版后自动淘汰旧副本，不另行归档。

## 保留与淘汰

`tools/generated_artifact_retention.py`按独立产物类型选择最近成功批次，而不是把未完成的新目录当作有效版本。目前覆盖黄泥冈完整测试副本、战役恢复副本、当前来源重基副本、Steam候选和Steam整合测试五类。

- 私有工程须准备成功、真实导入成功且释放自有引擎锁，生成身份中的全部文件和派生provider须逐文件匹配，才可替代同类旧副本。
- Steam候选须完整打包通过，ZIP摘要及清单一致；完整ZIP是有效载荷，旧清理已移除展开目录时仍可验证保留ZIP。
- 旧批次只清理完整`project`、`windows`、`probe_host`、私有`profile`、候选ZIP及`export__*/runtime`；原始报告、日志、截图、清单和源码证据不作为缓存删除。
- 当前项目源码、Git、玩家存档、正式在用发布版以及尚未结束的开发候选不在删除范围。
- 当前暂停候选的`overlay.json`中`baseline_run`和`legacy_run`自动形成依赖保护，不能因有更新目录而删掉。双版本对比前可在本机`.godot/artifact_retention/pins.json`添加`{"runs":[".godot/类型/批次"]}`，用完再撤销保护。
- 不完整/失败的新批次不会淘汰上一份成功版；占用文件、共享引擎通道忙碌、只读、目录联接或身份变化均跳过，不结束其他任务、不改权限。

在已明确退役旧版本后，历史文档和旧恢复映射中的完整副本路径可能不再存在。它们继续表示当时的证据，不能冒称载荷仍可复验；当前必需依赖保持完整。

## 自动触发

为保留当前暂停候选绑定的生成器SHA，自动清理采用独立的本机观察程序，不修改这些冻结的生成/验证脚本。观察程序每60秒检查新完成记录，只在成功批次变化时复核并清理；没有变化时安静等待。发生占用或错误时保留文件并稍后重试。

```powershell
# 预览清单，不删文件
python -X utf8 -B tools/generated_artifact_retention.py
# 手动执行一次；不启动引擎、不复跑游戏矩阵
python -X utf8 -B tools/generated_artifact_retention.py --apply
# 配置当前Windows用户登录后隐藏运行，并立即启动观察程序
powershell.exe -NoProfile -File tools/install_artifact_retention_startup.ps1
```

启动项为当前用户Startup目录下的`WaterMarginArtifactRetention.lnk`，目标是本机`pythonw.exe`，参数为当前仓库工具的`--watch`。无需管理员权限。换机后需在新机器执行安装命令，用户机器路径不提交到Git。观察程序持有独占实例锁，不重复启动多个清理实例；不涉及Steam上传、发布、交易软件或Codex自动聊天任务。

## 安全与记录

先冻结精确允许目录中的文件身份、长度及时间，再逐文件以同一个Windows排他句柄复核并删除。共享硬链接只去除已退役名称，不修改其他链接的内容；分配空间仅按最后一条链接删除计入。目录逐个确认空后移除，不进行递归强删。

本机收据、删除清单和后台状态在`.godot/artifact_retention/`，不提交大清单或二进制。大清单只保存最近一次实际清理，不持续追加堆叠；没有新删除的重复检查不覆盖已有收据。专项目录见`qa/generated_artifact_retention_20261102/README.md`。
