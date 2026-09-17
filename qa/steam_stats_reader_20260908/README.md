# Steam 只读统计桥接验证

最终运行：`fb95f0f976af`，基础提交 `6fae66693790f440e5d0174e81505e2f1141ac43` 加本批新增源码。**86 项通过**：C++ 假 API 核心 61 项，实际 Godot 缺少 Steam 环境 2 项，实际 DLL＋合成 Steam ABI＋GDScript 完整读取 23 项。来源 SHA 不计入 86 项。

最终编译、两个独立工程的首次导入及两个运行进程均退出 0；编译警告和运行错误均为 0。`receipt.json` 保存受测源码逐字节 SHA、编译器/Godot SHA、依赖归档 SHA、完整命令与各项结果。`absent_report.json`、`mock_report.json` 为实际 Godot 报告，`.log` 为原始输出。

已覆盖：精确 uint64 句柄（超过 int64 正值上限）、同进程多次读取、在途第二次请求拒绝、错误和重复句柄、在途等待、逐项读取失败、合法零/false、int32 最大值、负值拒绝、结果 8、错误 app/user、账号切换后关闭、请求成功但 getter 失败时拒绝整个快照。桥接不提供写 API；合成 DLL 没有 Steam 初始化、成就/统计写入导出，真实 Steam 账号未启用。

最终原生 DLL：352768 字节，SHA256 `c95b9999bbd146abae238cf09f40b036ec1d389f71e9a306d61a07a6920ceab3`，保存于 `vendor/steam_stats_reader/win64/steam_stats_reader.dll`；实际受测 DLL 与归档二进制逐字节一致。vendor 带 `.gdignore`，没有加入正常启动或 Steam 候选安装清单。合成 SDK、测试 EXE、obj/lib、临时工程和真实玩家文件均未纳入 vendor。

## 诊断与复现

初次未预登记扩展的无头导入曾以 0xc0000005 失败，`diagnostic/` 保留其中一次官方 godot-cpp 绑定版本的失败日志和收据，不能当成通过证据。空扩展对照退出 0，同一已有扩展列表的工程再次导入退出 0；现象与 [Godot #111645](https://github.com/godotengine/godot/issues/111645) 的扩展文档首次扫描问题一致，但没有本机符号化调用栈，因此不声称已精确定位该崩溃地址。最终运行在首次导入前登记固定扩展路径，从全新工程验证通过，没有忽略失败退出码或重复失败命令来凑通过。

最初手写 C 绑定未晋级；最终使用固定 Godot 4.4 官方 C++ 绑定。Visual Studio 自带 CMake 在中文源码/构建路径配置时发生 fast-fail，改为 ASCII 短路径独立副本后正常。最终构建对本批源码启用 `/W4 /WX`，选择 release 绑定与静态运行库。

复现：在项目根目录执行 `py -3.14 -X utf8 -B tools/build_steam_stats_reader.py`。详细工具链、隔离目录和 API 合同见 [源码说明](../../native/steam_stats_reader/README.md)。

**验收边界：**合成 ABI 可以核对函数签名、结构布局与参数传递，但不能代替真实 Steam 服务验证。`current_cache` 与 `requested_user_cache` 的返回均不等同于某一 StoreStats 批次的持久确认。真实账号的请求/缓存语义、发布重试、结果 8 的落盘中断窗口及双设备行为仍待验证；本批没有完成持久发送器、玩家保存/继续、完整局或性能验收。
