# 同进程保存事务重试 QA：2026-09-09

最终批次 **`20260909_034724_209b6af2`**：`complete=true`，76项断言全部通过，实际执行与独立回读均有记录。本目录只验证本地槽事务及Session保留接口，不计作完整战斗恢复、真实Steam、断电持久性或玩家入口验收。

| 批次 | 导入 | profile_guard | 回归 | 结论 |
| --- | --- | --- | --- | --- |
| `20260909_034414_bd649218` | 退出0，错误0 | 退出1，错误2，预期退出2 | 未进入有效回归 | 原始失败保留，不计通过 |
| `20260909_034724_209b6af2` | 退出0，错误0 | 退出2，错误0；零fixture/报告写入 | 退出0，错误0；76项 | 通过 |

首轮`--script` SceneTree驱动在autoload名称注册前预载Session/Battle/Unit，导致`Localize`及`Sfx`未定义。修复仅改QA启动方式及runner：普通Node主场景，`_ready()`延迟执行，SceneTree操作经`get_tree()`；生成固定`owned_slot_retry_qa.tscn`并归档、记录SHA。生产写槽实现没有为此改变。

最终检查覆盖提交后解锁失败、有效pending后的回读失败、未写pending时失败、写锁元数据回读失败、错误token、不同owner/新对象、坏pending、另一有效目标pending、半释放后token丢失，以及Session拒绝丢失原事务。成功重试必须保持原generation/SHA、重复重试不增加代数、下一次同进程保存仍有效；拒绝路径比较前后目录和文件SHA。fixture使用简化文档验证器，Slot接口、envelope、SHA、CAS、锁和链均为生产实现。

独立复审回读76条通过断言、3个预期退出及日志SHA；确认当前2953份源码与冻结2953份源码一致，两批归档23份快照与各自收据匹配，四份引擎回读源码SHA及生成场景与runner固定原文一致。生成场景SHA256：`1863561b80b2a4642c81f4657769641e4c15fe5927b8b05b65ffee6fb1149007`。这些源码检查不与76项行为断言混加。

- [最终收据](20260909_034724_209b6af2/receipt.json)
- [最终76项报告](20260909_034724_209b6af2/regression_report.json)
- [首轮失败收据](20260909_034414_bd649218/receipt.json)
- [独立复审](final_review.json)
- [文件SHA清单](manifest.json)
- [实现及接口说明](../../docs/OWNED_SLOT_RETRY_20260909.md)

受控入口：

```powershell
py -3.14 -X utf8 -B tools/run_owned_slot_retry_qa.py
py -3.14 -X utf8 -B tools/run_owned_slot_retry_qa.py --run --work-root D:/CodexTemp/owned_slot_retry
```

默认只读预检；`--run`冻结源码、独立导入、使用共享引擎锁及全新私有profile。失败也保留原始日志、未完成收据和源码快照；只终止其自身子进程。`.gdignore`阻止Godot扫描本目录，不同步私有profile、测试槽文件或导入缓存。
