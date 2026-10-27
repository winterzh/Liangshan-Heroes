# Daming negative 8 脚本纯加载记录（2026-10-27 08:45）

原运行：`D:\AI项目\水浒\开发工程\.godot\daming_negative_parse_20261027\20261027_084545_37422b03`。本目录仅封存原件及派生索引，不运行引擎或负例。

实际 PID **68484**，退出 **0**，耗时 **38.425 秒**，`errors=[]`；原 receipt `complete=true`，`runtime_qualified=false`、`full_source_qualified=false`，lane idle / owner confirmed / lock released 均为 true。日志 SHA-256 为 `403d4572e8b3cf387863f4015bd4db4693dded58e9d7570af8c96fc0476837ef`。

冻结 loader 的第 5–10 行依次 `load` 并检查八个 Script 的 `can_instantiate()`，未调用 worker `.new()`。这只证明这些精确字节在实际 Godot 4.6.3 的加载/编译通过；没有 fixture admission、World/Component/Capture case 执行或业务恢复，不授予 52、61、原 19 持久化故障、自然 Flow、public 或 SDK 资格。`report_count=0`，不编造 worker report/controller。

原收据共 **39 pins = 30 个 external frozen inputs + 8 个 workers + 1 个 loader**。30 个输入全部从该 run 的 `source_inputs/` 读取，八个实际 workers 与其冻结原件逐字一致；相同字节只存一次。另保留原 receipt、131 B 原日志和真实 `run_parse.py`。`source_map.json` 完整映射每条逻辑 pin 到实际冻结路径和归档原件；`manifest.json` 列出每份原件/派生文件的大小与 SHA，manifest 自身不自列。

原件共 **34 文件 / 667,344 B**。未复制 EXE/DLL、工程资源树、缓存、私有 profile、Slot/LC 载荷。引擎 SHA 仅保留原收据元数据，归档器未读取二进制或重新全树哈希。

实际命令指向 b22 冻结工程，但本纯加载宿主未做完整来源验证；其 `full_source_qualified=false` 原样保留。完整准备及自有冷导入另见 [既有 full-freeze 归档](../../../projectile_filter_candidate/evidence/full_freeze_20261027_075456/README.md)，引用 manifest SHA `08510666a441d7838efa4def710edaa13475aa8c684b6c6f204ca502fb6d50e2`，本包只核该小清单的原字节，不递归复制或转授其运行资格。

`summary.json` 和 `verification.json` 是归档时派生摘要；`raw/` 均为原始字节。源和收据没有被改写。
