# Windows 外部进程存活查询：原生 API 诊断

同一Godot4.6.3引擎运行独立最小脚本，宿主同时持有另一个兄弟Python进程的Popen。探针前后均由Win32 `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` 与 `GetExitCodeProcess` 确认该PID为259/STILL_ACTIVE，Popen亦未退出；Godot对该外部PID的`OS.is_process_running`却返回false，对自身PID返回true。探针exit0、自有子进程已终态、共享锁释放。[原始收据](receipt.json)、[worker报告](report.json)、[来源清单](manifest.json)。

[官方4.6.3实现](https://github.com/godotengine/godot/blob/4.6.3-stable/platform/windows/os_windows.cpp#L1630-L1654)先检查本实例的process_map，不含外部PID就直接false，没有系统查询fallback。抓取文本及来源元数据一并保留。这解释了前一双Godot测试中的B无法确认活A；此最小探针没有执行游戏、存档接管或观察记录丢失。

候选Steam Store及当前基类SnapshotStore据该false判死的路径必须修正。可信查询需区分alive/confirmed-dead/unknown；未知不能改磁盘或接管。只有确认死亡后才可生成恢复计划，并在claim前重新核对原owner/nonce/head/inventory和存活状态。unique恢复还要分别确认原writer和最近claimant均已退出。

23IO/370项中，外部宿主确实终止并wait了前驱进程，故其已退出前提下的恢复结果保留；worker中的同一API不能独立证明死亡，也不能授予活writer保护。新的统一查询候选和活/死/未知矩阵尚未完成。
