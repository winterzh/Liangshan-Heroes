# R01 实测与独立复核交接

2026-09-06，运行 `runs/20260906T113756778956Z`。未发现阻断本步有限结论的问题；只读审查未重跑引擎，未改受测 source/pins 或历史收据。

## 已核实

- Godot 4.6.3 实际非 console exe，PID 26940，普通退出 0 且确认退出；无 checkpoint、无外部强制终止、无错误日志。complete/lock_released 均为 true。
- 1625 条全真断言、0 失败。其中 1232 条为快照目录打开/枚举、257 条为宽目录布置，余下 136 条包括来源、布置及行为；这是断言量，不能称为独立功能数。
- 29 次记录的只读调用：18 inspect + 11 read，13 个受检 fixture。另有 1 个仅生成 B 的 oracle fixture 和 2 次未写入 snapshot records 的路径拒绝 inspect。
- 29 次调用前后完整清单一致；13 个最终 fixture 与实际磁盘路径/类型/长度/SHA 全匹配。实际 14 个夹具目录内共 18 个文件、270 个子目录，其中 257 个空子目录用于条目上限负例。
- 独立按报告前快照重建完整 entries 并重算 16 个 inspection_id，重算 19 个候选 id，全部一致；原 12,878 字节 store 前缀、7 份冻结执行源、4 份私有运行源、manifest SHA、报告 SHA、PID 和私有 user:// 均匹配。

## 案例范围

干净槽、无槽、空锁、有效槽伴锁、多候选、同内容不同叶、精确选择 A/B；有效 SHA 但完整 validator 拒绝、未知 schema/format、坏 UTF-8、零字节；原文件只增加 JSON 尾空白也改变身份；隐藏项新增、嵌套锁目录/文件新增及内容改变、候选删除、同内容不同目录误选；9 层深度及 257 项目录拒绝；现存越界目录和缺失目录拒绝。

11 次 read 中，4 次精确读取成功、1 次坏候选不可用、6 次旧目录身份失效。成功不会安装槽或清锁；空锁与残留仍保留。validator 调用报告为 110 次，该次数不是额外案例量。

## 边界与来源

这是隔离 fixture 的 R01 候选读取，不含 journal/移动/删除/清锁、UI、游戏状态 codec 或 Battle 恢复。多次相同观察不保证独占、原子快照或排除 ABA；未测权限失败、链接/reparse、超大文件和并发变化。两次路径拒绝未带前后快照，不能冒充 31 次都有完整磁盘无副作用证据。原 pins/preparation 的未运行标记是冻结的准备时间事实。

- store_r01.gd：`91df41b7a51870e4fabb81f5f15f4053541e3c8041975943f3c10d0a195acb60`
- qa_driver.gd：`2d65935759c72ffa9508726af8115c75a5e9b8835e516d6c610bb9f89505073f`
- report.json：`ebf10a1193bc83f8c62197f3783296828342d98d1c94ed434dfbee97e6d5f111`
- manifest.json：`9379c8c0718ca82a7f47d1100f1aed4302fd3662bce51123787d967ce589e55d`

`result_summary.json` 保存逐调用摘要和六份运行证据的原字节 SHA；`archive_whitelist.json` 仅列建议保留的精确文件，不执行复制或正式归档。排除 private_profile、私有 project/fixture、Godot 缓存与只准备未运行的旧目录。GDScript 草稿归档时应使用 `.gd.txt` 并保留 `.gdignore`；复现时恢复到本 scratchpad 位置，并恢复对应 `run_save_store` 原始依赖。README/收据中的原相对路径以本目录为语境，归档不能将其误指为线上生产入口。
