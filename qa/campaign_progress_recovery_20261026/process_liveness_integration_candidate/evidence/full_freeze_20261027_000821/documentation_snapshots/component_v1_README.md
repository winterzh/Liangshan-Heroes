# 独立进程存活三态候选

本目录只实现 Windows 查询 helper 与独立 Godot 适配器草案。**未集成生产、SnapshotStore、Steam Store 或既有 20 文件候选**；不授予锁恢复、战役、SDK、发布资格。原失败证据与所有冻结保持原样。

## 当前实证

- [构建收据](evidence/build_20261026_231111_062ae286.json)：本机 .NET Framework csc 编译退出 0，warning-as-error；源 SHA `2d01e9ced42ba25b243e79e7f847334eee66f210d5c5fcc916e4eeb00396f8a1`，8,192 字节 exe SHA `012354b1cf0376712f97e19362d91b2ef7f51775c6797c862c513df1e2f1936c`。exe 仅存忽略的 `.artifacts/`，不提交二进制。
- [原生 helper 收据](evidence/native_20261026_231118_bd1dae8d.json)：Python 宿主 13 个实际用例通过，自有子进程全部终态。外部宿主和兄弟 Python 均 alive；持有进程句柄的退出码 7、259 子进程均 dead；释放句柄后的实际原 PID 返回 87/dead；本机 System PID 4 权限不足返回 unknown；5 个非法 PID、已有 pending/final 文件均拒绝，原文件保留。[原始provider报告与碰撞夹具](evidence/native_raw_20261026_231118/README.md)另存原字节与SHA。
- [Godot组件收据](evidence/godot_20261026_232303/summary.json)：最小独立工程编译并退出0，22项报告模型、49项组件检查通过；5次真实helper调用覆盖外部活兄弟进程、保留句柄的exit259死进程、释放后缺失PID、权限不足unknown、创建身份不符unknown。重入begin保留原helper、终态poll非消费、非法PID/错误helper SHA不启动亦已验证。源码/helper/引擎pin不变，目标前后状态与FILETIME实际一致，锁释放。本批没有运行Store或游戏，timeout路径仍未验证。
- [独立超时收据](evidence/timeout_20261026_233903/summary.json)：后继批另通过19项检查，实际3013毫秒后返回unknown，只请求终止自身helper一次，并保留未确认清理状态。宿主通过原持有HANDLE确认helper退出，被查询目标全程存活且创建身份未变，随后自然退出；源码pin不变、共享锁释放。使用只休眠的测试助手，仅验证v1适配器超时控制，不等于真实Win32查询助手故障或Store恢复通过。[首轮宿主失败](evidence/timeout_host_failed_20261026_233720/summary.json)及旧脚本原字节保留；失败原因是宿主在进程退出后查询映像路径，修正宿主观察顺序后另批重跑。

## 查询协议

固定 helper 使用 `OpenProcess(SYNCHRONIZE | PROCESS_QUERY_LIMITED_INFORMATION, false, pid)`，不提权、不枚举、不查询远端、不改变目标。只接受标准十进制 `1..2147483647`。成功持有同一个 HANDLE 后读取 `GetProcessTimes`，再 `WaitForSingleObject(handle, 0)`：

| 证据 | 状态 |
| --- | --- |
| 有效 HANDLE，创建时间有效，`WAIT_TIMEOUT` | alive |
| 有效 HANDLE，创建时间有效，`WAIT_OBJECT_0` | dead |
| 固定合法参数、非零 PID，`OpenProcess` 返回 NULL 且错误 87 | dead / PID_ABSENT_87 |
| 权限不足、其它 OpenProcess 错误、取时间失败、等待失败、关闭 HANDLE 失败 | unknown |
| 缺少 helper、SHA 改变、输出不完整/不匹配、超时、非 Windows | unknown |

87 的适用范围有明确限制：[Microsoft .NET v9.0.0 官方实现](https://github.com/dotnet/runtime/blob/v9.0.0/src/libraries/System.Diagnostics.Process/src/System/Diagnostics/ProcessManager.Windows.cs#L29-L46)在相同固定权限、非零本机 PID 下将此错误判为进程不存在。Win32 OpenProcess 文档同时说明 PID 0 也会产生 87，因此先拒绝 0、负数、分数、非标准/超范围输入；绝不把任意调用的 87 泛化成死亡。所有其它错误没有枚举回退。官方摘录及 blob SHA 见 [API 证据](evidence/api_sources.json)。

创建 FILETIME、PID、Win32 数值在报告里全部是标准十进制字符串，避免 JSON 浮点往返损失。helper 返回固定 11 字段 ASCII canonical JSON；Godot 必须在自己启动的 helper 退出 0 后，核对 schema、nonce、目标 PID、实际 helper PID、结果互斥条件、创建时间和原始 canonical 字节。`expected_creation_filetime` 非空时，所见 HANDLE 创建时间不同一律 unknown；旧元数据没有创建时间时，复用 PID 指向活进程仍保守 alive，不能推定旧所有者死亡。

## Godot API 与所有权

```gdscript
var oracle = load(external_oracle_path).new()
# private_root 必须预先存在；helper_path 是固定文件名的绝对路径，SHA 来自受信构建收据。
var configured = oracle.configure(helper_path, helper_sha256, private_root)
var result = oracle.begin(owner_pid, expected_creation_filetime)
while result.pending:
    await get_tree().process_frame
    result = oracle.poll()
# 只允许 state == "dead" 后进入后续元数据/CAS重新核对；unknown 不接管。
```

`begin` 冻结本次 PID、nonce、独占目录和自己启动的 helper PID。`poll` 只对该 child 使用 Godot `get_process_exit_code`；没有对外部 owner 调用 `is_process_running`。同实例有 pending/未确认清理时，新的 begin/configure 都拒绝替换。不同次查询不能共享报告文件。

采用 `OS.create_process` 固定可执行路径和固定结构 argv；不用 PATH、shell、无超时 execute 或 pipe。helper 使用 `CreateNew` 排他 pending，写入并 `Flush(true)` 后，同目录不覆盖 `File.Move` 到 result。Godot 有 3 秒轮询期限、helper 1 MiB 上限、报告 4 KiB 上限。时间约束不是对 Windows 内核创建/文件系统调用的硬实时保证；调用方必须持续 poll。所有临时文件保留作为证据，不自动清理。

超时只对本次自己 create 的 helper 调用一次 kill，绝不终止被查询的 PID。Godot Windows `kill` 会先移除 process_map 条目，且 TerminateProcess 异步，因此此候选不会再用原 PID 重试 kill 或宣称回收成功；返回 `helper_cleanup_confirmed=false`，实例隔离并拒绝下一次 begin，直到上层生命周期结束/后继可靠清理协议接管。不得遗失该实例后偷偷创建新实例绕过未确认状态。

## 后续接线要求

当前 Store 的 `inspect_recovery`/`recover` 是同步接口。**不能把 begin/poll 当原布尔查询直接替换**。后继[同步恢复桥接](../process_liveness_integration_candidate/README.md)使用进程级manager持有oracle，每次公开恢复操作共享3秒查询预算，不泵事件；unknown期间不得修改业务Store。该后继目录单独验证，不能转授本片v1资格，也不能每次new Store遗失活helper。

计划身份与一次查询证据需要分离：随机 nonce、helper PID、时间不能加入原恢复 plan 的严格字典等式后又每次重建，造成永远不等；同时不能用永久缓存死亡结果代替真正接管前复查。应在 inspect 和 claim 前分别获得 fresh 结果，并重新核对 owner/claimant、nonce、head、inventory/CAS。unique 恢复需要原 writer 和最新 claimant 均确认 dead。后继实现与运行状态以其独立README和收据为准。

## 构建和独立验收入口

```powershell
python -B qa/campaign_progress_recovery_20261026/process_liveness_candidate/build_helper.py --build
python -B qa/campaign_progress_recovery_20261026/process_liveness_candidate/tests/run_native_helper.py --build-receipt <本次build_receipt.json> --run
python -B qa/campaign_progress_recovery_20261026/process_liveness_candidate/tests/run_godot_component.py --build-receipt <同一build_receipt.json> --execute
python -B qa/campaign_progress_recovery_20261026/process_liveness_candidate/tests/run_godot_timeout.py --execute
```

工具不带动作参数时只preflight；构建30秒/子进程回收10秒，原生helper每例5秒，所有宿主子进程由实际Popen持有，隐藏窗口。收据绑定C#源、编译器、构建工具、exe和测试器；每次独立目录，失败原文保留。前两工具不占Godot lane；第三个组件执行器持有共享锁运行最小工程，不加载游戏、Store或真实玩家数据。

后续仍需串行验证：实际适配器查询活外部Godot；报告缺失/半写/非零退出等真实文件故障；再做各Store活owner/claimant业务目录零变更、死者恢复与重查CAS。22项纯报告反例不代替真实文件故障；49项组件正常路径与19项独立超时各自保留来源边界。恢复桥接在独立后继目录验证，不修改本片已验证源码。

部署仍需独立处理 helper 签名、可信二进制 pin、导出携带、Windows 杀软/权限和 .NET Framework 4 依赖。当前 AnyCPU exe 无 NuGet 依赖，但并非 Godot 自带组件。`SystemRoot` 和受信配置必须由宿主控制；SHA 不构成代码签名，当前私有目录不抵抗同用户恶意替换。Linux/Android 等平台暂无可靠后端，只返回 unknown、保留锁，未继承 false→dead 回退。

`tasklist` 不作为死亡后端。CSV 格式、退出 0、自身 PID 锚点不能证明无权限遗漏的完整系统表；Godot 4.6.3 pipe 还将空读/断管/错误合并，`eof_reached` 恒 false。该方向已停止，没有把列表缺行包装成死亡证明。
