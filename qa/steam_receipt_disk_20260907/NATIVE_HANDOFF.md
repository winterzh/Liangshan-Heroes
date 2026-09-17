# Steam receipt 文件事务支线：原生交接

2026-09-07，本支线仅产生隔离候选与真实私有文件夹测试。生产 SteamService、Steam 账号、Battle、Git 分支均未修改。

A2 freeze `0b00adc68bf1760c683b008e62aa24116a3133154d07bc1d30fe0ace6f714661`，实际运行源 HEAD `f3da82f7452a2164c704c34a97c6b2696e99b9c3`，Godot 4.6.3 SHA `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`。

原生收据：`attempt_a2/runs/20260907T091322Z_b22324f5/receipt.json`，原始 SHA `f159303ab28e2e2a7306c4ce3ecb28da422b93ca2c7be33d1fd7539b4127c960`。该收据 passed=true；source/head/frozen input/player/private profile/全部 owned child 退出/共享锁释放检查均通过，最后 Godot PID 列表为空。运行窗口已经还给 ROOT，不再启动引擎。

| 证据 | 实际结果 |
| --- | --- |
| 原生进程 | 共启动 69 次：26 次在父进程核对断点名称和真实 PID 后主动 kill，43 次正常 exit=0；没有错误日志 |
| 原生断言 | 293 条全部通过，包含私有目录、打开状态等环境断言；不能全部称为游戏或统计业务用例 |
| 正常宿主 | `contract.json` 33 条，通过文件 CAS、冻结目标、新进度 2001、旧成功不清新进度、进程级 lease、跨 Host/session 不可绕过、错身份、活锁 |
| 真崩溃 | 12 个发送断点、7 个成功回调断点、7 个结果 8 断点；每次都由另一个新进程验证恢复 |
| 半写文件 | 3 个半写 pending 保留原文件，明确阻断；没有偷偷回退旧 receipt 来发布 |
| SDK 部分失败 | 第二项 SetStat 失败、SetAchievement 后 StoreStats=false，各自新进程恢复且没有重发 |
| 文件反例 | UTF-8、截断、hash、owner、多字段、负数、bool、小数、断链、未知文件共 10 类，原文件 SHA 不变 |
| 独立 SDK 日志核对 | runner 逐条核对实际记录文件 SHA、revision、app/owner、uncertain token 和准确目标；崩溃样本共 96 条事件全部对应有效持久 marker；所有恢复前后日志字节相同 |

第一包 A1 freeze `3b05bcb88b058c92e5db4d9689429d679b7e547e7dae9b6a3e008da5a7c4099e` 仅做语法/结构检查，独立 QA 找出同进程 A 成功后发 B、迟到 A 成功会误清 B 的正常异步反例，因此未原生运行。原包及冻结文件完整保留，详见 `A1_REJECTION.md`。A2 不假造 Steam 批次 token，改用整个进程最多一个 SDK 发布批次的静态 lease；ack 不恢复资格，换 Host 或 session 也不能绕过。本地新进度可以继续保存。

这批只验证 fixture 与 fake SDK。新进程也必须先通过显式 synthetic authority 门，当前 exact-match 输入只是夹具证明入口，不能当生产 clean 合并策略；真实 Steam 新读、初读基线与未确认增量归属、异步 SDK 回调身份、正常持续发布频率仍待设计验证。普通服务器值低于本地新进度不能直接套用失效校正而丢掉新增量。

其余边界保持明确：没有证明断电原子性、真实退出时 Steam 缓存自动提交、多设备写者/回滚、恢复进程再次被杀、MAX_RUNS 边界、长期日志压缩、真实账户切换或 Battle 合格累计。文件账本只开放私有 `res://fixtures/<case>/5088120/<owner>`，上限 2,048 条，全链验证。目录链接防护有代码但本批没有构造 Windows junction 测试；并发恶意绕过文件协议不属于已验证安全边界。

归档按 `archive_inventory.json` 逐文件复制并核对 SHA，不能整目录上传。清单保留 A1/A2 原始候选、原生日志/报告/断点、全部合成账户 fixtures、崩溃前原始副本、SDK trace；5 个实际执行 GD 源与 2 个原模型以及 2 个目录/状态依赖各保留一份。排除 `.godot`/导入缓存、生成 UID、全部私有 profile（含崩溃缓存）、测试工程的重复源码副本。建议目标 QA 根带 `.gdignore`。清单列出的 SteamID 是固定 fixture 常量 `76561198000000001`，未读取任何实时 Steam 账号；凭据、登录缓存、真实玩家存档和账户数据均不在清单中。

运行复现（必须先从 ROOT 获得独占 Godot 窗口）：

```powershell
py -3.14 -X utf8 -B scratchpad/parallel_steam_store_20260907/attempt_a2/run_matrix.py --freeze-sha256 0b00adc68bf1760c683b008e62aa24116a3133154d07bc1d30fe0ace6f714661 --run
```

runner 会在启动时钉住实际 HEAD 并全程回读，同时要求全部候选和 4 个依赖精确 SHA；与本支线无关的新提交不要求改冻结包，运行中变动 HEAD 仍拒绝通过。若未来依赖变化，应建立新尝试并说明变化，不能改原冻结包。
