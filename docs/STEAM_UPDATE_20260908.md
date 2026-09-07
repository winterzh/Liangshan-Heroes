# 2026-09-08 Windows Steam 测试更新

Windows 最新源码 `e3a758b` 已上传为 Steam Build **25173165**，Depot `5088121` / Manifest **2578852481018016286**。用户完成原确认框后，Steamworks canonical builds 页面已回读确认 `steam-integration` 测试分支为 **25173165**，并显示相应上线历史记录。服务端四文件大小与 SHA1 均匹配本地成品。

公开 `default` 仍为 **25164373**。本次测试分支已从25160280更新为25173165，没有重新上传、重复提交分支切换或发布社区公告。完整续玩、真实客户端下载/双账号 Steam 验收和新美术生产验收仍未完成。

本轮全新原生检查182项、实际包65项、source/PCK身份各10项和同EXE串行11个短测通过；六张原生界面已逐张观察。源码/真实玩家/工具保护通过，子进程退出及公共锁释放。最初旧纹理缓存缺失的准备失败已保留，改为完整导入后通过。

本次包括已接入的稳定实体身份、局部恢复模块、Battle时钟/捕获屏障和任务框交互。未晋级的美术和假SDK磁盘回执草稿不进入运行包。

ZIP 221,187,505 bytes，SHA256 `1cf1075302e35934bff76917e696bfb852aa1a57d6e894ef2b04133910fafaff`；仅EXE、两枚release DLL与许可证。[QA及复现](../qa/steam_upload_20260908/README.md)、[服务端收据](../qa/steam_upload_20260908/steam_server_receipt.json)。
