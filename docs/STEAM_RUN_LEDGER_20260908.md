后续：Steam收据文件事务抽取为run_snapshot_store基类，原v1路径/封套保持兼容；上一批实际两份记录按原SHA打开不改字节，并继续新局/进度通过。完整2100写与7强杀回归重新验证。[单槽与存储证据](WORLD_SLOT_20260908.md)。ledger尚未接到正常SteamService及统一Session。

后续：Battle现已传递可恢复的累计有效击杀，SteamService完成同进程高水位防重，见[实际世界验证](STEAM_BATTLE_COUNTER_20260908.md)。本页持久ledger仍未由服务调用，outbox及Session绑定继续待办。

# Steam 独立持久局记录

三个内部模块已进入生产源码：steam_run_receipt保留严格账号/玩法/局身份、累计击杀高水位与终局一次；steam_receipt_store负责Windows实际文件事务及最近两份完整快照；steam_run_ledger串行完成校验、落盘回读、模型提交和读写新鲜度检查。尚未由SteamService或Battle调用，不会自行创建玩家记录或改变现有成就统计。后续须把此模块接到统一Session、Steam持续同步和玩家继续槽，不能把本批称为完整续玩或真实SDK验收。

## 内部接口与存储

open接收实时账号及首次读取的统计/解锁种子。默认位置为user://steam_receipts/v1/5088120/<账号>，独立于战斗槽；只有空目录初始化才使用种子，已存在记录不能被传入零值覆盖。账号必须是合法十进制SteamID；目录只允许user://子目录并拒绝父级跳转与检测到的链接。begin_run用Crypto产生128位随机局token，调用方只在落盘成功后取得它。progress接收本局累计有效击杀，只加超过历史高水位的差值；settle持久标记胜负，重复结算不再加胜场，失败终局也不能随后改判胜利。can_resume核对实时账号、受信玩法和未终局，调用者不得从槽读取受信账号、路径或玩法来源。

每次修改在mkdir写者锁下比较当前修订与SHA，写pending、flush、close、原字节回读、严格JSON/UTF8/模型验证，rename后再次回读，再提交内存模型。旧宿主发现磁盘修订变化即停止读写，重复低水位事件不写新文件。每份快照含全部局记录和终局墓碑；新快照核验成功后才删除多余旧快照，正常只保留两份。相邻修订和前序SHA仍需匹配，不再有A2的2048次写入上限和随写入次数增长的全链重读。

恢复仅在原写者PID确认不运行时进行，并重新核对完整目录清单。完整pending可向前恢复；半写、错误UTF8、缺失前序、损坏旧/新文件、账号或哈希不匹配、未知文件均阻断并保留原字节，不回退到旧记录继续计数。遇到存储错误，宿主不会返回可用记录。恢复过程本身再次被杀、空/损坏锁的自动修复仍待实现；它们会保留阻断状态。flush及进程强杀不证明断电耐久性；SHA链也不防止用户主动删除/替换整个目录或恶意改档。

## 验证与边界

最终原生8208条记录通过：5826来源SHA和2382功能/环境断言。实际连续2100次更新后只有两份完整快照，重新打开高水位与总击杀均为2100；该循环耗时73476ms，包含同步校验/读写，不能作为每次击杀在物理帧内直接落盘的性能证明。今后应在Session安全边界批量提交累计值，并在保存槽及任何SDK缓存写入前完成持久确认。

7个实进程强杀点：写锁取得、pending半写、pending关闭验证、rename、新文件验证、删除旧快照前、删除旧快照后。每个均由父Godot核对活跃子PID和断点后执行OS.kill并确认终止，再启动新Godot恢复；共14个测试子进程。完整窗口重启后只保留正确的3或11击杀，旧累计2不加数；半写窗口保留损坏文件并阻断。活跃写者时竞争宿主均被拒绝且未修改文件。另有11类坏文件、账号/玩法隔离、旧宿主拒绝、八战役故事成就、20/30/60波据守、AI、胜负终局、整数饱和及服务端校正模型检查。所有账号均为测试常量，未调用真实Steam。

Receipt的invalidate/correct仍是供未来SDK宿主使用的内部模型接口，测试中的校正输入是合成数据。Steam的UserStatsStored_t没有应用批次编号，退出还可能提交缓存；本模块不处理发送、回调归属、离线缓存或真实服务端确认，也不把read generation当SDK回调令牌。[官方API](https://partner.steamgames.com/doc/api/ISteamUserStats#UserStatsStored_t)、[StoreStats](https://partner.steamgames.com/doc/api/ISteamUserStats#StoreStats)。Steam离线缓存及多设备合并语义另见[官方统计说明](https://partner.steamgames.com/doc/features/achievements#offline_mode)。继续集成前必须解决持久outbox、迟到/重复回调和校正崩溃窗口，不能直接重放旧绝对目标。

快照大小仍随局数增长，纯模型保留10000局上限；到限明确拒绝新局，不偷偷删除终局墓碑。长局数压缩及终局索引仍待后续实测。本次未接入A2每进程仅一次发送策略，原候选保留历史证据。[原生QA](../qa/steam_ledger_20260908/README.md)、[受测字节晋级](../qa/steam_ledger_20260908/installation.json)。全项目八关、完整30波、跨进程世界续玩、1800秒、两台Windows、60FPS、美术和真人/真实双账号验收保持开放。
