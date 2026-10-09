## 2026-10-08 11:42：19案真实组件矩阵通过

V4新批 `campaign_19_7aac9db9` 已实际终态：runtime PID43016、退出0，19案全部完成、194检查、零失败，锁已释放。固定坏CFG仅有一条精确预期C++诊断，零SCRIPT ERROR；实际文件消失/只读/语义篡改、ConfigFile.load opener内核等待期间SHA变化均由真实文件操作触发，未替换原生返回值。控制器ACK采用完成写入后同目录rename公布。

原收据SHA `add421fb7b4655a9e70432ef3481a61a1b9e05742e260be1811639a76792ab66`；原收据、导入/原生日志、19案请求确认与报告原字节位于 `actual_matrix_v4/`，汇总见 `ACTUAL_19_COMPONENT_PASS_V4.json`。旧V2/V3失败原样保留，下面“尚未整体资格/仍运行”为历史。

通过范围为私有工程安装v27b Campaign提案的真实持久化组件；正式Campaign/Battle仍未修改。终局gen2→cfg→ack、玩家失败UI/pending锁/安全重试、跨进程恢复及奖励一次性尚未通过。

# 真实 Campaign 写盘故障的调试器准备

当前Godot断点/真实读盘proof通过，19案已原生导入和完整运行过；最新V3整批因确认JSON部分写入被读到而失败，19案尚未整体资格。正式 Campaign/Battle 未修改，v27b 两文件仍是 QA 提案。

## 11:34 当前真实结果

单冒号修正的`debug_probe_3314a8ba`实际PID5900、退出0、源码行22/_run断点stack精确，真实私有文件11→29，真正ConfigFile.load观察到29。原收据/日志/报告/GD位于`actual_debug_probe_v2/`；第一份未命中断点失败保留。

矩阵V2冷导入通过，初始7案通过；第8案动态断点未被主循环及时消费，整批失败。矩阵V3增加正常时钟0.25秒的主循环等待，实际运行全部19案、194检查，所有真实故障（包括cfg.load opener等待期间SHA变化）均命中且结果正确；唯一失败是确认JSON被读到未完整写入，产生额外JSON C++错误。其完整原字节位于`failed_matrix_v2/`、`failed_matrix_v3/`，不改写为通过。

V4保留相同19案/故障和验证，仅将控制器JSON写完flush/close再同目录rename公布，避免部分ACK。`matrix_source_preflight_v4.json`与`matrix_source_snapshot_v4/`封存新来源，使用全新UUID/profile实际启动。当前结果依新批真实终态，旧成功子案不能替代整批。

`failed_debug_probe_v1/` 是实际失败：官方引擎 PID16364 正常退出0，ConfigFile 真正保存/加载，但 CLI 双冒号断点未命中，没有发生控制器文件修改。原日志、收据、报告和执行 GD 均保持原字节；私有工程/profile 留在工程外。不得把退出0计为调试协议资格。

官方 `4.6.3-stable` 标签源码表明 `EngineDebugger::initialize` 按最后一个冒号拆分 `file:line`；CLI 帮助文字写 `source::line`，两者不一致。控制器已改为单冒号，等待完整续玩批次终态后再用新 UUID 独立验证，避免本线程两个原生批次互相竞争。标签源码只作为协议依据，未证明与安装引擎精确源码提交一致；首次精确提交 URI 返回404的原清单也保留。

工具：`tools/godot_debug_wire.py` 是有界、拒绝 Object 的 Variant TCP 编解码；`tools/run_campaign_debug_fault_probe.py` 只控制自己的回环调试连接和私有 cfg，须核验真正的 breakpoint、stack source/function/line、实际 PID/nonce，再改真实文件并继续实际 ConfigFile.load。未修改原生错误码或生产脚本。

离线固定包、拒绝异常包及 TCP 分段超时缓冲验证通过；这不代表原生协议或19案通过。

## 19案与实际 Windows 原生文件等待

`tools/campaign_persistence_fault_matrix.gd`和`tools/run_campaign_persistence_fault_matrix.py`逐案对应原SHA固定的v27b矩阵。使用正式项目资源、实际autoload/SteamCloud，唯独安装独立审查过的v27b Campaign提案到私有工程原路径；正常case没有CAMPAIGN_QA，QA两案明确切换环境并核验文件不写。局部Cloud计数器仅用于观察回调，实际Cloud applying兼容分支另用原SteamCloud。组件身份/cycle/depth拒绝不伪装成真实磁盘序列化成功。

读写故障在精确Campaign源码/行/函数断点进行：已有文件消失、实际Windows只读属性、保存后新load缺文件、第一SHA前修改合法已写进度；SHA案在真实fresh cfg.load的文件opener等待期间追加注释。所有原生返回值保留。坏CFG只允许与固定`[broken`夹具一致的一条准确C++诊断，SCRIPT ERROR始终不允许，不泛忽略ERROR。

`tools/windows_owned_oplock.py`使用原生独占oplock、OVERLAPPED/event和实际WriteFile。已在独立文件上实际验证：真实reader被内核等待、期间追加、释放后reader读到新字节；未触发的请求也完成取消再释放存储。最新实际PID2452/reader thread34796、收据来自`windows_oplock_2c845024`；`windows_actual_v2/`保留原收据和当时工具字节，不复制测试cfg到Git。旧`windows_oplock_f495b09e`仅保留历史收据，旧helper已更新，不作为当前执行准入。Windows文件机制通过不等于Godot调试协议、ConfigFile调用或19案通过。

完整原生运行要求：成功Godot调试proof `--protocol-receipt`，当前helper实际Windows proof `--oplock-receipt`，当前精确源码封存`--source-preflight matrix_source_preflight_v4.json`，实际完成本机基线和同SHA引擎。两个proof已实际通过，V4整批已启动，尚待终态。只读预检为`python -X utf8 -B tools/run_campaign_persistence_fault_matrix.py`。旧v1/v2/v3准备/执行源和失败完整保留，不覆盖。

即使组件19案后续通过，终局→cfg→ack、玩家失败UI/pending锁/安全重试、跨进程恢复、自然战斗与奖励一次性仍需另测。
