# Steam 统计读取桥接：2026-09-08

按用户“干”继续开发，先完成持久同步所需的读取适配器。固定 GodotSteam 4.22.1 把 `GetUserStatInt32` 的成功布尔值丢弃，脚本不能区分读取失败与真实 0；其读取信号也未携带原始 SteamAPICall_t。本批新增独立只读 GDExtension 和严格 GDScript 门面，保留这两项信息。

## 本批交付

- `native/steam_stats_reader/`：原生状态机、Windows 平面 API 绑定、官方 Godot C++ 注册、编译配置及合成测试。
- `scripts/steam_stats_reader.gd`：`attach(owner)`、`current_snapshot()`、`request()`、`poll(handle)`。成功快照必须完整读取四个统计与30项成就，逐项类型、读取来源、owner/handle 一致；失败不返回部分种子。
- `tools/build_steam_stats_reader.py`：固定依赖来源和哈希、独立目录编译、共享 Godot 锁、实际 DLL 的隔离运行与来源守卫。
- `vendor/steam_stats_reader/`：352768 字节的受测 DLL、MIT 许可和来源清单。保持 `.gdignore`，正常 SteamService 和现有候选打包暂不加载它。

原生 API 只使用已经加载和初始化的 Steam DLL，检查 AppID5088120 和当前账号；不自行加载/初始化/关闭 Steam，不分派回调，也不调用 SetStat、SetAchievement 或 StoreStats。以十六进制字符串保存完整无符号请求句柄，只接受当前在途句柄，完成后允许下一次读取。账号变化则关闭该实例。调用方应在主线程使用。

`current_snapshot` 标记 `current_cache`；异步请求完整成功后的快照标记 `requested_user_cache`，保留该读取句柄。**读取关联不等于写入批次确认。** 当前账号的缓存/服务端语义仍须实测，不能仅凭这些返回值清除持久 outbox。无身份的 UserStatsStored 回调也不能与本地代数强行对应。

## 验证与下一步

[最终 QA](../qa/steam_stats_reader_20260908/README.md) 为86项通过：61项核心、25项实际 Godot 原生交互；两个首次导入及两个运行进程退出0，无编译警告/运行错误。没有连接真实 Steam 账号，也没有重跑完整战役、30波或性能套件。

后续仍依次完成：在真实 SDK 中确认同账号读取与缓存语义；实现持续持久发布器（发起写入前先记录不确定状态、重启恢复、重复/迟到回调、结果8校正），验证后接正常启动和玩家保存退出/继续；再做经典30波与八关、长跑/双机及真人验收。当前普通 SteamService 的旧迟到成功回调问题仍存在，本批读取模块没有被当作该缺陷已经解决。

复现命令及主要来源见 [原生模块说明](../native/steam_stats_reader/README.md)。本批按文件提交并推送既定 GitHub stable；没有合并 main 或更新 Steam 构建。
