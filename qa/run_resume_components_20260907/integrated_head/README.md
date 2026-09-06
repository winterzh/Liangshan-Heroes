# 新 HEAD 整合源集组件兼容复测

受测源集为基础提交 fe1faf5a71b92a81b4404c8f35cce2b648d50a49，加五个当时尚未提交的正式恢复模块，以及导入生成的脚本 UID。五个模块以各 run manifest 的精确 SHA 为准，不能声称所有受测文件均属于该 Git 树。

本子层使用当前 Battle、project 与 Steam/Workshop Autoload 源码，重复正式模块路径的组件检查；原型层及 production_path 原文保持不动，不把重复执行累计为新游戏场景。

| 组件 | Run（UTC） | PID / exit | 检查数 |
| --- | --- | --- | --- |
| Unit | [20260906T190047879205Z](runs/20260906T190047879205Z/report.json) | 13232 / 0 | 149：20 来源前后 + 129 其余，其中身份边界 83 已计入 |
| Projectile | [20260906T190128073061Z](runs/20260906T190128073061Z/report.json) | 14024 / 0 | 54：18 来源前后 + 36 其余 |
| Map v2 | [20260906T190208572861Z](runs/20260906T190208572861Z/report.json) | 36160 / 0 | 63：40 来源前后 + 23 其余 |

三轮报告与唯一 stdout JSON、PID、manifest、私有 user:// 和报告 SHA 一致。全部 exit 0，严格日志无错误或警告；每轮来源及玩家前后摘要逐字节一致，三个完整源基线也相同（2862 文件），进程退出确认且锁释放。玩家摘要没有复制玩家文件内容。

[source_index.json](source_index.json) 映射三个 manifest 的全部源码、当前 runner、四份 driver（含身份边界）、五个正式模块、Battle/project、固定 SHA helpers，以及完整基线中的八份 Steam/Workshop 源码。同 SHA 的旧归档字节通过明确路径复用；改变的 Battle/project 与尚未归档的正式 Map 等新增字节保存在本层 sources。这些源码均有原字节归档映射，没有以外部 Git 依赖代替，也没有重复复制大份未变来源。

## 导入原始记录

[imports/20260906T185810280911Z](imports/20260906T185810280911Z/receipt.json) 是编辑器导入过程，原始 complete: false 与 only_reviewed_import_changes: false 保留；exit 0 不转换为行为检查通过。编辑器为 60 份图片 .import 元数据添加 UID，根任务按导入前后及 HEAD 原文核实后恢复原字节；[import_metadata_review.json](imports/20260906T185810280911Z/import_metadata_review.json) 保留逐项记录。

本层再次核对 60 项 restored SHA 均等于导入前摘要、当前文件及三个行为 run 的基线，generated SHA 均等于导入后摘要；另有 16 份新脚本 .gd.uid 被保留，原文在 source index 中映射。除这些新增 UID 外，清理后行为源基线与导入前完全一致，没有生产逻辑修改。导入 utility 保存的是归档时当前原文，原始 import receipt 未钉住其 runner SHA，不补造历史执行证明。

## 复核与边界

[archive_manifest.json](archive_manifest.json) 记录本层原字节复制；[archive_verification.json](archive_verification.json) 记录复制及引用路径复核，并钉住三个旧 manifest。现有 .gitattributes 的 qa/run_resume_components_20260907/** -text -whitespace 覆盖本层。GDScript、shader、project.godot、UID 以末尾 .txt 存储，根目录有 .gdignore。

复跑需要完整同版本 checkout 和内容资源。按 source index 将 driver、runner、helper 恢复到尚不存在的忽略目录，去掉保存脚本最后的 .txt；已经存在的源码只核对 SHA，不覆盖。生产路径即各条目的 repository_path，不可把复用的旧 scratch 路径误当正式模块恢复路径。实际引擎执行保持独占并生成新 run；入口沿用 [production_path 说明](../production_path/README.md)。

没有复制私有 profile、玩家存档、Godot 缓存、美术二进制、vendor DLL 或引擎。没有证明完整 Battle 保存退出重启续战、菜单继续、PCK 导出、战斗长序列等价、视觉截图验收或 Steam 账号/工坊联网功能；RNG 双进程验证仍是独立证据。
