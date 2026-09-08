# Steam 真实读取与续玩确认边界

基线 `3f3949f4741d473ee9ad90fca7b9db1c07f52dbc`。按用户授权使用当前已登录账号，独立最小工程初始化 Steam，不加载 Battle 或 SteamService，不调用任何统计、成就写入 API。

## 已修复并实测

首次真实读取暴露 `UserStatsReceived_t` 的 Windows 字段偏移错误：24 字节回调中的 `CSteamID` 从第 12 字节开始，旧桥接误从第 16 字节解析。Steam 实际返回成功后因此被拒绝为 `RESULT_IDENTITY_MISMATCH`。Valve 的 [CSteamID 定义](https://github.com/ValveSoftware/GameNetworkingSockets/blob/master/include/steam/steamclientpublic.h) 使用 1 字节 packing；外层结构的尾部补齐不能移到账号字段之前。

桥接现在先收取 24 字节原始缓冲区，再按 0/8/12 偏移分别复制 game/result/owner，逻辑结果结构不再充当 wire ABI。合成 DLL 也独立构造 wire 字节，并在尾部使用非零填充，避免生产代码和测试同时复制同一个错误结构而误通过。

构建 `a3ac131a2e53`：61 项核心检查、2 项无 Steam 检查、23 项真实 DLL 与合成 ABI 检查通过。修正 DLL 为 352768 字节，SHA256 `be9ea866c3e922fc0ddd40f97dede0bab7fd37a9393ad11307b91bba6e70ce6a`。

最终真实探针 `80fa232c74e5`：初始缓存读取成功，同进程两次异步请求均成功，分别约 413ms/315ms；每次返回 4 项统计、30 项成就，账号一致，内容与前次一致。首次导入和读取进程退出 0、错误 0，运行前后源码与引擎、全部已安装 DLL 摘要匹配。`vendor/steam_stats_reader/provenance.json` 已指向本次证据；旧批次的 86 项隔离通过仍是历史事实，但不再作为真实结构布局已正确的依据。

## 尚不能确认的部分

两次成功读取只证明当前账号的读取链路可用；本轮没有统计写入，不能证明缓存和服务器写入之间的因果关系。读取句柄关联 `RequestUserStats`，不是写入批次号。

[Valve 接口合同](https://partner.steamgames.com/doc/api/ISteamUserStats#UserStatsStored_t) 中 `UserStatsStored_t` 只有 game/result，没有账号、请求句柄或应用发送代际；该回调也可能由成就进度提示触发。`StoreStats` 的成功返回、通知序数、超时后的下一条成功通知以及缓存目标值相等，都不能单独证明某个持久 intent 已获确认。进程退出还可能触发 Steam 自行保存，不能把“应用没有显式调用 StoreStats”当成没有发送过。

**当前写入确认能力仍为未证明。** 持久发送队列必须保留不确定 intent；正式统计续玩继续封闭。后续需要能独立验证具体发送意图的服务器确认方案，再做正常玩法产生统计的真实写入、断网和跨进程验证。不能用假 SDK 的确认器替代此门槛，也不能拿读取成功开放玩家入口。

## 复现和隐私

工程根执行 `py -3.14 -X utf8 -B tools/run_steam_stats_live_read.py` 只检查前置条件；明确 `--run` 才在全新隔离 profile 中初始化当前 Steam。`--reader-build .godot/steam_reader_build/<id>` 可探测已验证候选，工具校验对应构建收据和源码，避免未验证 DLL 晋级。

使用共享 Godot 锁，拒绝同时运行游戏/引擎。原始 Steam 日志可能含账号标识，仅留在工具输出的本机临时目录，不进入 Git。公开收据仅包含计数、时间、布尔状态、源码/二进制 SHA，不包含 SteamID、真实累计值、成就解锁状态或请求句柄。

证据见 [QA](../qa/steam_stats_live_read_20260908/README.md)。本批只同步源码和内部依赖，不构建或发布 Steam 玩家包。
