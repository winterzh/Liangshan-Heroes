# Battle fog 私有 controller 只读复核

2026-09-07。结论：**未发现需要阻止本轮独占引擎检查的适配遗漏**。只读审阅 Python/GDScript 协议、原 lifecycle/guard，使用 Python AST 做语法读取；没有执行 controller、合成报告自检或 Godot，没有修改受测 GD、原 pins 或共享文件。本文件不加入原 pins。

审阅身份：

- `scratchpad/run_battle_fog_qa.py` raw SHA `42e4cd9681606f77a8b8786bf6d21b84500d91b668abea74ab418e127bfc6785`。
- 配套 contract raw SHA `523349d5ee17820904dc83f29f5e722b0f1aa464660a572b2cf3da62a3c61f42`，锁定 13 文件；controller 自身 SHA、Fog pins `d34da511…` 与 24 个强制标签均相符。
- common 源为 `1e11fe77f7fde4d088c71e4e0cf97c6c3278b4690821baf01cd883e23607d573`，lifecycle 为 `ad12b2b4caff9a90d0712031372be6cedb50b869fcc97d2dc02aee11842c7b34`，与被冻结原件相同。

具体核对结果：

1. runner:109–118 创建同一个新 run 下的 private_profile、manifest 和 report 路径，设置 `BATTLE_FOG_QA_MANIFEST`；五项源路径、run_id/run_dir/private_user/report/source_sha256 与 GD 最终协议一致。APPDATA/LOCALAPPDATA/TEMP/TMP 只覆盖子进程 env，没有 HOME 覆盖；原项目名称与 custom-user-dir 检查由 guard.project_name 执行。
2. runner:48–52 对照实际子进程 PID、实际 user 目录、run/manifest SHA 及 before/after 五源字典；122–124 还要求 stdout 恰好一个 `[battle-fog-state QA]` JSON，语义等同独立 report。严格 UTF-8、Unicode parsing error、Parse Error、Parser Error、SCRIPT ERROR、ERROR、WARNING、FAIL 与 exit/cleanup 拒绝保留在原 ad12 lifecycle.run_process 内，不因新 runner 没重写正则而丢失。
3. runner:53–67 的非空检查、passed/failures、check_count、分组和强制标签对齐当前 QA。来源为 10 条逐文件检查，source 分组合计 13（另含精确来源集合、文件聚合及 manifest 不变），不是 13 个功能案例。完整范围的 false 标记与五 Fog 值、两地图维度 coverage 均被验证。
4. runner:92–100 拒绝 `.console/_console/-console.exe` 包装器并以排他新文件拿同一共享锁。新 lifecycle 仍是原原文，只有内存 SCRIPT 选择器改为本次 GD；Popen 使用实际非 console exe 句柄，异常时只处理自己的子进程。guard.ACTIVE_PROCESS 在未确认结束时仍参与 finally 的排他检查，不依赖报告自行声称退出。
5. runner:128–140 在收尾重新检查无运行 Godot、全部冻结文件、完整来源路径/字节账本、真实玩家摘要以及锁 token；任何失败把 complete=false 并保留锁，只有全部通过才 unlink。报告校验失败或引擎诊断失败仍不能留 complete=true；已经确认进程退出且全源/玩家保持时可释放锁，不会把失败结果当作 QA 成功。

尚待根任务实际产生：新 PID 的编译/运行日志、完整非空检查数、真实 manifest/user/source 证据和 source/lock 收尾结果。本文没有提前确认 GD 编译、float32 次正规输入或 freed typed Map 边界通过；原准备收据应保持历史字节。
