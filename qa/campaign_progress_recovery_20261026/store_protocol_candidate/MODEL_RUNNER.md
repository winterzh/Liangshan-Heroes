# Unique cleanup 模型运行契约

`run_protocol_model.py` 只提供 `protocol_model` 一个阶段，没有原生 I/O、故障注入或 SDK 模式。输入是合成账号、PID、nonce、目录布局；Store 构造只解析路径，模型不创建账本、锁或记录。报告文件和隔离 profile 是 QA 证据，不能算 Store I/O 验收。

从工程根执行，主线程先以 `integrated_candidate` 建立全新冻结并完成现有导入；然后：

```powershell
python qa/campaign_progress_recovery_20261026/store_protocol_candidate/run_protocol_model.py --base-run <新冻结目录> --timeout 360 --wait-lane 1800
```

只有 `--help`/Python 静态检查在本次执行；上面命令未运行。旧 source23c 冻结因 manifest 不匹配被拒绝。`--wait-lane` 默认为 0（占用立即拒绝），运行时只能取得已有共享锁，绝不终止其他任务进程。

当前集成 revision 为 `first_commit_stale_cas_release_v2_20261026`，修复首次 `commit_locked` 的写前 CAS_CHANGED 释放分支；runner、bootstrap、worker 和 14 项命名/布局模型字节未改变。新清单同时拒绝原 `199c4f92…` 的未导入冻结 `20261026_210350_189c0290`。现有模型不覆盖真实交错或释放失败后的同 scope 重试；须另做原生断点复验，不能将模型成功当作这次竞态修复已验证。

入口沿用已验证 `run_model.py` 的冻结身份、私有 profile、共享锁、精确子进程和前后 SHA 规则，额外绑定新 20 文件 manifest、外部模型/worker SHA。复制三个外部脚本到新证据目录，不修改冻结工程；`--headless --script protocol_bootstrap.gd` 只加载 worker。bootstrap、worker 在任何可能的原生 API 前离开 physics 帧，所有动态 Script load 均检查 `can_instantiate()`，编译失败立即退出 2，宿主同时监测错误日志。

宿主设置 `STEAM_DISABLED=1`、`CAMPAIGN_QA=""`；独立 `D:\CodexQA\stmodel\<nonce>` 内的 appdata/localappdata/temp/tmp 分别绑定四个环境变量。专用环境字段为 `SPM_PROFILE/PROJECT/WORKERS/WORKER_SHA256/MODEL_SHA256/NONCE/MODE/REPORT/CANDIDATE_MANIFEST_SHA256`。不继承旧 `SPM/MR/LR/HG` 值。

新收据位于 `.godot/steam_store_protocol_model_20261026/<run>/`，包含实际 PID、profile、源身份、引擎 SHA、清单/外部脚本/报告 pins 与终态。14 个合成检查全部通过、进程退出 0、最终身份和 pins 不变、精确自有锁已释放，才允许 `complete=true`。如无法证明已启动子进程终态，保留锁并报告失败。失败目录/日志/profile 不删除、不覆写。

模型成功也不能替代下列待验：Windows 真实 rename/删除失败重试、唯一目录死亡收尾、多进程交错、既有完整 pending 恢复不退化、SDK、原版键鼠、公开继续入口及整个 gen2→CFG→ledger→gen3 事务资格。仍存在的旧 fixed writing/recovering、半 pending 及 CFG/LC 窗口见 [README](README.md)。

恢复元数据也没有完整来源认证：首次观察前的合法同账号 owner token 替换无法由当前名字鉴别；非法元数据、账号不符和已观测计划之后的字节变化才属于现有拒绝边界。这个合成模型入口不授予 owner 防篡改或 SDK 信任资格。
