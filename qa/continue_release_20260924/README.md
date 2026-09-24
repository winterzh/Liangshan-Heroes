# 2026-09-24 最终本机功能验收

候选 `20260924_135637_0ef1fc1a` 未上传 Steam；线上仍为 Build 25476210。第二账号、跨设备未测，用户已免除本阶段阻塞。

| 证据 | 结果 |
| --- | --- |
| `../stockade_boundary_20260924/` | 围栏修复后 948 项通过；修复前 70 项失败。 |
| `../classic30_continue_20260909/20260924_125334_7d11f343/` | 346 项、完整 30 波、778 敌军、三次跨进程恢复、两次终局拒绝。 |
| `classic30_wallfix_independent_readback.json` | 13,622 项回读通过，当前/私有源文件与归档一致。 |
| `native_wallfix/` | 最终原生集成 219 项通过；SDK 统计写入使用替身。 |
| `candidate_wallfix/` | 1136 项包检查，3048 份源文件匹配，源/PCK 身份探针通过。 |
| `formal_wallfix_exe_acceptance.json` | 新包真实菜单保存、重启继续、暂停和训练队列恢复、二次覆盖；Steam 绑定一致。 |
| `../workshop_defense_public_20260924/candidate_installation_retest.json` | 新包真实重订阅自动刷新、三文件 SHA 一致、13 敌军胜利；原始截图同目录。 |
| `player_guard_and_settings.json` | 玩家 183 文件不变，测试设置恢复，四次正常启动日志无错误/警告。 |
| `performance/README.md` | 15 有效窗口；最低完整 10 秒 77.65 FPS。压力段 P95/P99 仍未达严格目标。 |
| `soak/README.md` | 用户缩短长测；12 分钟观察、62 切换、253 项运行检查通过，未完成原 30 分钟最终清理门槛。 |

候选 ZIP SHA-256：`e1f061a10053f4eab4fd1b00306f87dce5c96002560164a682186bfdfbfd7653`。实际 ZIP、EXE、完整战斗槽、账号文件和测试用户目录仅保留本机，不进 Git。

较早的 `formal_exe_acceptance.json`、`classic30_independent_readback.json` 等保留各自版本历史。失败候选 101559 / 103128 / 105434、早期安装回调失败及 PowerShell 编码失败均未当作最终通过；最终以本表对应批次为准。
