# Steam A2 原生记录独立回读

2026-09-07，只读复核 A2 唯一原生运行 `20260907T091322Z_b22324f5`。
本支线没有再次启动 Godot 或调用 SDK；使用同目录
`verify_steam_a2_receipt.ps1` 独立读取原始记录并核对摘要。

运行来源 `f3da82f7452a2164c704c34a97c6b2696e99b9c3`，冻结 SHA
`0b00adc68bf1760c683b008e62aa24116a3133154d07bc1d30fe0ace6f714661`。
最终 receipt SHA
`f159303ab28e2e2a7306c4ce3ecb28da422b93ca2c7be33d1fd7539b4127c960`。

独立回读通过：69 个引擎进程记录，其中 1 次导入、42 份正常 worker
报告、26 次命中具名断点后被父进程终止的 worker。26 份原始 checkpoint
的名称/PID 与各自进程记录完全相同；所有预定强杀均非零退出，其余进程
退出 0；69 份原日志未发现引擎错误或警告。42 份 worker 报告共 293 项
检查且全通过，这包括环境和身份检查，不等于 293 个业务场景。

另外逐条核对 20 份 SDK trace、110 个事件：事件 PID、历史账本原字节
SHA、app/owner/revision、payload 长度/摘要、uncertain token 和确切
统计/成就目标全部匹配。26 组崩溃前证据中 132 个原文件，与 receipt
记录的原始 SHA 全部一致。恢复记录未发生旧 SDK 调用重放；三处半写入
断点保守阻塞且保留损坏证据。10 种坏账本和两种部分 SDK 失败均有通过记录。

`contract.json` 为 33 项检查，PID 12448。包括：A 成功后 B 被进程
lease 拒绝，迟到 A 成功拒绝；换 Host/session 仍无法发送 B；发送期间
新进度 2001 保留，旧发送目标仍为 2000；无归属 result 8 持久失效；
synthetic authority 将统计精确校正到 7，旧 run token 保持终结。

所有 source/head/private-project/player/child-exit/lock 保护均为 true，
运行结束 Godot PID 列表为空。独立回读脚本的首次尝试仅因 Windows 路径
分隔符比较未统一而停止；统一两侧分隔符后通过，未改任何运行证据。

A2 四个语义修订文件与 `STEAM_DISK_REVIEW_A2.md` 的 SHA 相同，冻结输入
及实际私有工程输入也已回读逐项匹配。A1 的重复回调问题在此有限策略下
通过“进程只允许一次发送”被阻止，并未实现普通游戏进程持续发送策略。
真实 Steam 回调、服务器权威读取、关闭进程自动上传、断电持久性、完整
游戏存档接入均仍未验证。此结果是磁盘/假 SDK 的进程强杀矩阵通过。
