# 物品 UID、区域效果与真实付费复活（2026-09-07）

第10、11个正式恢复组件为 [run_item_id_state.gd](../../scripts/run_item_id_state.gd) 和 [run_zone_effects_state.gd](../../scripts/run_zone_effects_state.gd)，分别与受测原型原字节一致。本批同时包含 Battle/Inventory 的物品 UID 窄补丁；新模块数量不是整局恢复完成度。源码与原型对应见 [promotion_verification.json](promotion_verification.json)，逐轮源码身份以原始 manifest 为准。

| 检查 | Run（UTC） | PID / exit | 项数 |
| --- | --- | --- | --- |
| 物品分配器原型 | [20260906T195440680513Z](runs/20260906T195440680513Z/report.json) | 28160 / 0 | 53：16 来源前后 + 37 其余 |
| 区域效果原型 | [20260906T195639137986Z](runs/20260906T195639137986Z/report.json) | 30560 / 0 | 81：42 来源前后 + 39 其余 |
| 区域效果正式路径 | [20260906T195836771214Z](runs/20260906T195836771214Z/report.json) | 17848 / 0 | 同组 81 项 |
| Inventory 修改后原 Unit 回归 | [20260906T200247535257Z](runs/20260906T200247535257Z/report.json) | 34988 / 0 | 原组 149：20 来源前后 + 129 其余 |
| 正式 counter 路径、原物品自检、真实付费复活 | [20260906T200720412333Z](runs/20260906T200720412333Z/report.json) | 37340 / 0 | 231：198 来源前后 + 33 行为/宿主 |

全部轮次均 complete=true、exit 0，实际子进程退出确认，源码/玩家前后摘要一致，共同锁释放。报告与唯一 stdout JSON、实际 PID/user、manifest 和报告 SHA 一致。实际执行命令末尾入口逐轮存在于 manifest 中；最后一轮完整保留99个运行源码映射。正式区域效果与原 Unit 回归复验原矩阵，不累加为新场景。正式 counter 在最后一轮通过真实 JSON→两个空 Battle 后继分配验证，不声称另跑了一次53项负例。

## Battle 物品 UID 与安装顺序

物品新 stack 从所属 Battle 的正 int64 next_item_uid 连续分配，替代 owner ObjectID 与局部序号的计算；换格、同 Battle 转移及可信复活保留原 UID。INT64_MAX 是耗尽哨兵，最后可发出 INT64_MAX-1；损坏/耗尽或缺少 Battle 域时失败，不创建 UID 0。补已有堆叠不申请新号，add_item 返回未接收余量。跨 Battle 转移、满栏或目标重复 UID 在移除源物品前拒绝。旧 _uid_seq 字段保留但不再决定 UID。

counter 通过既有 int64 十进制 codec 跨真实 JSON 保存；调用方必须提供可信内容版本及完整引用图核定的最大已分配 UID。证明范围须包含全部活/死亡 Unit 库存、退休 hero_item_progress、proc/待施放等 UID 别名，不能只取活动六槽最大值；已消费旧号由原 counter 高水位保留。恢复只接受尚未使用的空 Battle，树内必须暂停，先完成所有图验证，再装 counter、库存与别名，最后才允许创建物品。它不从存档自报最大值获取信任，也不回填或重编号。

53项真实对象检查涵盖两 owner 与1201个创建后消费 stack、转移/满栏/跨域、退休别名、JSON 后12次一致后继、2^53+1及耗尽端点、损坏快照原子拒绝。没有真实购买者调用的扣费事务不能由此宣称验收。

## 原物品自检与付费复活实证

最后一轮先在两个空 Battle 验证正式 counter；随后在完整标准驻守 Battle 调用原 _item_selftest 一次。原生唯一输出的 add/stats/full/shared_cd/snapshot/swap/transfer/combat/tally 九项及 ALL 全 true，输出原文在 report.log。该原自检不计作额外231项。第一场完整释放后，另建全新标准 Battle 执行真实 take_damage→死亡回调→物品/成长退休记录→queue_train 付费生产链。

坏 UID 快照使 spawn 失败时，付费队列、两份退休进度保留，失败节点帧末释放且不进入活动表、不推进 AI 序号；反复重试不重复扣费、不泄漏 Unit。cancel_train 退款并清阻塞队列，退休进度保留。恢复原 snapshot 再训练，成功创建独立新英雄，消费队列和进度各一次，保留原 UID/数量/实例与共享冷却/旧局部值，恢复成长；旧死亡动画节点保持独立且不回活动表。

战斗保持暂停，训练通过显式 _train_t=0 加速，不代表正常墙钟训练或所有 spawn 调用方验收。Inventory.restore 仍是可信同 Battle 内部 snapshot 入口；任意外部存档必须走严格整图验证。失败共用的生产等待提示没有在本批扩改；完整恢复须在激活前拒绝坏 counter/库存，不将失败重试当自动修复。

## 四数组效果与地图权威

区域组件只恢复 _chrono_zones、_orbit_zones、_fire_trails、_ice_walls 的显式字段、真实数值类型、顺序及活/无/已释放引用。已有三数组地火/流血/决斗组件没有并入本模块。先由 map_state 恢复真实 block_count 与导航，再检查墙格现有计数覆盖全部贡献；bind 不登记墙、不重烘导航。计数超额可来自建筑，完整来源由外层地图事务证明。所有引用图绑定完，才由外层统一释放临时墓碑并启用模拟。

真实原消费者的20组 source/restored pass 对照证明：orbit 只剩两次伤害，trail 依原剩余相位在第2/5/8/11步铺火，重叠墙分别于第3/6步各释放自身计数，独立建筑占地保留；空数组不重复伤害/铺火/释墙。chrono 观察夹具每步独立清除旧 stun，Unit 局部状态和一块既有地火由外层夹具提供，不能当全 Unit 计时或完整地火恢复。原消费者确实创建 HitSpark/GroundFireFx；保存时已存在的视觉 Node、随机视觉字段未由本组件恢复。

## 原文、依赖与复现

[source_index.json](source_index.json)映射全部五轮来源，包含受测 Battle/Inventory 新字节、两正式模块、原 candidate/build_patch/pins/53项 smoke、复活 cases/driver/runner/pins。修改前 Battle/Inventory、旧 Map/Unit 和固定 helpers 按精确 SHA 复用既有 QA 原文；不复制多份大 Battle，也不把当前字节冒充历史。准备 README/pins 中“未运行”状态保持原文，实际通过结果由独立 run 收据证明。

在独立完整相容 checkout 按 source index 恢复缺失忽略路径；GD/Godot场景文本只去掉末尾 .txt，Python保留原名，已有文件先核对SHA而不覆盖。入口分别为 python scratchpad/run_item_ids/run_smoke.py、python scratchpad/run_zone_effects_production_qa/run_smoke.py、python scratchpad/run_item_respawn_qa/run_smoke.py，均传 --godot "<实际 Godot 路径>"；不带 --run 仅预检，实际执行追加 --run，遵守共同引擎锁、新私有用户目录与新 run。原 Unit 回归入口为 python scratchpad/run_resume_production_qa/run_smoke.py --suite unit，同样传 --godot 和实际运行时的 --run。

[archive_manifest.json](archive_manifest.json)记录复制原字节；[archive_verification.json](archive_verification.json)记录原文、依赖与生成摘要的核对。源/玩家文件只有摘要，不含玩家内容、私有 profile、缓存、PCK、安装包或 vendor DLL；完整 checkout 的生产资源仍是复现依赖。本批未实现 RunSession 整局事务、完整视觉恢复、全部效果/游戏随机调用接入、跨进程整局继续、菜单或 PCK 续玩，M3仍未完成。
