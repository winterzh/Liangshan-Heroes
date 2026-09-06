# Inventory 实测证据复核

2026-09-06，仅复核 `runs/20260906T154102953512Z`。本次没有运行引擎、修改受测 GD、pins、共享 controller 或生产文件，也没有增加案例。

结论：该轮 Inventory 局部值 capture/validate QA 有完整通过证据。实际 Godot 4.6.3 子进程 PID 42016、exit 0，退出已确认；receipt 的 complete/source_unchanged/lock_released 均为 true。stdout 只有引擎头与一个 `[inventory-state QA]` JSON，逐值等同独立 report；UTF-8 解码及 Unicode parsing error、Parse Error、Parser Error、SCRIPT ERROR、ERROR、WARNING、FAIL 检查均无命中。实际 user 路径、run manifest、configuration、report 和 process PID 一致。

检查计数为 **155 = 10 个逐文件来源摘要检查 + 1 个来源未变化聚合检查 + 144 个其余断言行**。runner 的 other_checks=145 包含这一个聚合检查。144 行还包含重复的 JSON 中转与负例夹具准备检查，不能写成 144 个独立案例；所有检查行 passed=true、failures 为空。controller 指定的 11 个关键功能标签均恰好出现一次。

关键证据包括真实生产 HeroInventory 构造、完整五字段、稀疏和满六槽、大于 2^53 的 UID/序号及 int64 UID 上限、两类冷却字典顺序、接近周期阈值的相位、实际 JSON.stringify/parse 中转、编码位值保持、不消耗额外 RNG、不别名源容器，以及旧 snapshot 缺相位、重复 UID、过宽 proc 表的拒绝。owner/Battle 为回调探针；全部正负例没有重算、重绘、物品定义或周期效果回调。过期 owner 仍明确延期处理。

五个受测运行文件逐个核对 bytes/raw SHA/LF SHA，与 pins、configuration、manifest、report 一致。原 pins、preparation_receipt、README 和 .gdignore 原字节保持。保存的 sources.json 含 2713 文件，重新计算其目录/存在性/路径摘要得到 f12de07498b7074dd1c8fb0edf0bde9bdc5f0dfad5b95d850624b32e2a65fa20，与 run 收据一致；本次没有再对 2713 个生产文件全量哈希。该轮全源前后一致与玩家文件摘要前后相同，以原 controller 收据为证据。

范围仍是六槽与 `slots/cooldowns/proc_cooldowns/_uid_seq/_periodic_acc` 五个局部值。没有 apply/restore、owner 引用恢复、有效物品定义验证、全局 UID 分配器恢复、效果/来源图、Battle 调用、磁盘存档接入或跨进程续玩；没有性能验收结论。构造非默认测试对象时直接写字段是布置输入，不是恢复实现。

归档仅选该轮七个明确证据文件：configuration、manifest、sources、process_receipt、process.log、receipt，以及私有用户目录内**唯一指定的 inventory_report.json**，后者映射为正式 run/report.json。不会归档整个 private_profile、其他配置/玩家文件、fixtures、工程、缓存或引擎。

原 controller、contract、lifecycle 及两个公共 helper 已逐一匹配历史收据/来源账本，并将原字节封存到 archive_prep/frozen_controller；它们不是新 runner。README 受旧 pins 锁定，故保留准备期文字；当前真实状态由 current_qa_summary.json 与本文件补充。
