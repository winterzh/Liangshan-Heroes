# Receipt journal / fake SDK candidate A1

2026-09-07。隔离候选；尚未通过 Godot 原生验证，不接入生产 SteamService。

`receipt_disk.gd` 是只接受当前测试工程 `res://fixtures/<case>/5088120/<owner>` 的追加式文件账本。每次模型修订对应一个完整 envelope，使用连续修订号、上一个原始文件 SHA-256、UTF-8 字节长度与 payload SHA；payload 必须再通过原 receipt/outbox 的完整验证。两个原模型从已封存合同逐字节复制，不放宽 owner/token/统计/成就/tombstone。

写者先以原子 mkdir 取得 `writing` 锁；宿主在同一个无 await、无信号/任意 Callable/SDK 调用的临界区中 prepare → pending 写入/flush/close/回读 → rename 至新记录 → 完整回读 → model.commit → unlock。SDK 第一条 SetStat 前必须完成 uncertain 记录；假 SDK 每个调用都独立重读完整账本，核对持久 token 和冻结目标。

恢复先保存可复核清单，仅确认原 PID 不存活且完整 pending 形成唯一后继链时向前恢复。坏 pending、未知文件/锁、链断裂、同版本分叉、符号链接、活锁和恢复锁残留均保持失败关闭。恢复计划绑定所有受控文件 SHA；不选择旧记录来继续发布。重启 uncertain 禁止重发，先持久失效、封闭旧 token，再用假权威读精确校正。

`run_matrix.py` 默认只读预检；`--run` 必须先取得 ROOT 的 Godot 运行队列许可。runner 同时使用工程共享引擎锁、启动时实际 HEAD、精确依赖 SHA、私有 APPDATA/LOCALAPPDATA/TEMP、生产及默认测试用户目录前后快照。历史参考 HEAD 不限制后续无关 UI/docs 提交，但单次原生运行中 HEAD 必须保持不变。

```powershell
py -3.14 -X utf8 -B scratchpad/parallel_steam_store_20260907/prepare.py
# 从上一步结果读取 freeze_sha256；冻结后不再修改此包。
py -3.14 -X utf8 -B scratchpad/parallel_steam_store_20260907/run_matrix.py --freeze-sha256 <SHA>
# 获得 ROOT 引擎窗口后，在同一命令末尾添加 --run。
```

`prepare.py` 的 grammar 和结构检查不能替代 Godot 编译/运行。原生矩阵会由外部 Python 父进程等待子进程写出断点及其真实 PID，再调用 kill 并确认退出，重启另一个 Godot 进程验证恢复。每个断点保留完整账户文件、副本 SHA、原始日志和退出收据。正常退出/内存重建不计为强杀证据。

限制：这是有 2,048 条记录上限的 fixture 专用第一批。全链读取的成本、长期压缩/保留策略、双设备同时写、远程回滚、账户切换生命周期、真实 GodotSteam 回调归属/权威读取、进程关闭时 Steam 缓存自动上传、Battle 累计字段均未实现或未验证。flush/关闭回读和 kill 不证明断电原子性。恢复进程本身被杀后的 `recovering` 残留保守阻断，尚无二次自动恢复。存储宿主假定受控目录没有绕过协议的并发恶意改写；跨进程合作写者由 mkdir/CAS 保护，不能宣称是操作系统文件系统安全边界。没有执行 SDK/Steam 账户操作。
