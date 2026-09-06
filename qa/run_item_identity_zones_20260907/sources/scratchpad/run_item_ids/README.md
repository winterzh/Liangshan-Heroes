# Battle 物品 UID 窄补丁

仅准备，未应用生产、未运行 Godot。`candidate.patch` 只改 Battle 和 HeroInventory；`item_id_state.gd` 是独立的计数器运输/校验/安装草稿。它们不等于整局恢复或物品效果图完成。

`build_patch.py` 严格核对两份原始 SHA 和每处唯一原文，默认只生成本目录的 patch 与 source_changes.json；不改生产、不运行引擎。Battle 原文混用 CRLF/LF，builder 保留未改字节及各修改块原有换行。根任务应用时可在既有独占/来源保护下使用 `candidate(relative_path, original_bytes)` 取得精确候选字节，或应用 patch 后核对 source_changes 的候选 SHA；不能全文件换行规范化后冒称同一候选。

运行期约定：Battle 的正 int64 `next_item_uid` 初始为1。`allocate_item_uid()` 成功返回当前值再递增；INT64_MAX 是耗尽计数器，不作为物品UID发出。最后可分配值为INT64_MAX-1，因而next始终严格大于全部已分配UID。耗尽或损坏counter返回0；put_item在写slot前失败，add_item只扣实际插入/补堆叠数量，返回余量，绝不创建uid0。补已有堆叠不分配新UID。局部 `_uid_seq` 保留旧快照字段并在成功分配后饱和递增，但完全不参与UID计算。

没有有效Battle分配域的旧工具/ownerless路径直接分配失败，没有备用UID域。跨Battle转移拒绝；同Battle换格/转移保持UID、数量与共享/实例冷却，转移前还检查目标没有同UID和源UID属于已分配范围。临时别名不能借此进入另一个Battle。满栏、跨域、重复目标UID等拒绝在源物品移除之前发生。

实际生命周期已逐处读取：

- HeroInventory `_new_uid` 原来是 `owner ObjectID * 1000 + _uid_seq`；实际新stack只有 `put_item` 和 `add_item` 两处。已替换为Battle分配。
- `swap_slots` 原样保留；`transfer_slot` 原先复制物品字典后清源位，现加分配域/UID前置检查，仍不发新UID。
- Battle `_on_unit_died` 将物品snapshot保存到 `hero_item_progress`，死亡Node仍可能存活。因此活/死亡库存与退休snapshot可包含同一合法历史别名，不能见重复就全部重编号。
- Battle `spawn_unit` 调用 `inventory.restore` 并清退休snapshot。该可信同Battle复活入口现先检查六槽形状、UID正整数/局部唯一且低于已安装counter；失败不重置已有库存。spawn失败保留退休snapshot、释放本次新节点并返回null，不擦掉待恢复物品。普通成功复活保持原UID；不占新号。
- 正式 `run_unit_state` 的 `instantiate` 直接赋五个库存值，不调用旧 `restore`，这一路保持原文。整局调用方必须完成所有库存与别名验证，再安装本counter；本补丁不在加载时补号或重算UID。
- 当前 `scripts/` 中没有购买/掉落方调用add_item或put_item，调用点是Battle现有item QA；本smoke只证明数量返回/库存不丢失和不修改gold，不声称真实商店扣费事务已验收。未来付款调用方必须按实际接收量结算，并保留add_item余量。

计数器接口：构造 `Counter.new(trusted_codec_script, trusted_battle_script)`，`capture(battle, content_version, verified_allocated_uid_max)`、`validate(snapshot, content_version, verified_allocated_uid_max)`、`restore(fresh_battle, snapshot, content_version, verified_allocated_uid_max)`。快照精确包含schema/content_version/next_item_uid，counter经现有c8c4 codec的int64十进制tag再真实JSON运输；不经float。

`verified_allocated_uid_max` 必须由外层可信完整图验证得到，不能取快照自报的max、活动英雄列表或当前六槽最大值来假装完整。至少覆盖units_root的全部活/死亡Unit库存、hero_item_progress、proc冷却的UID前缀、待施放/走近施放的uid以及其他已验证退休物品别名。已消费、无任何剩余别名的旧号仍由保存counter保留其高水位，不能从现存物品最大值重建counter。校验要求next严格大于可信最大值；若旧数据曾分配INT64_MAX则没有合法后继，拒绝恢复。

restore只接受next仍为1的新Battle；树内则必须暂停。它先全部validate，最后仅赋counter，不安装物品、不启用对象。应在根暂停事务中完成全部图验证/树外构造，安装counter，再安装任何可信复活snapshot并允许物品创建；恢复期间禁止任何入口提前分配。可信内容版本必须包含这一分配规则变更。本模块不能独立证明调用方提供了完整最大值，不能替代整局validator、事务屏障或防回滚存档政策。

真实smoke入口 `res://scratchpad/run_item_ids/item_id_smoke.gd`，采用 `RUN_RESTORE_QA_MANIFEST` 的run_id/private_user/report/source_sha256协议；报告前缀 `[item-id QA] `、suite=`item-id`、实际PID/user、完整checks和source前后检查，与现有小runner可直接衔接，不另建runner。根任务先应用/校对两候选再运行；原生产没有分配方法，不能用原文冒充候选通过。

夹具为实际树外Battle/Unit/Inventory。覆盖两owner连续发号及1201个创建后消费的stack、legacy seq饱和、换格/转移/满栏/跨域、退休库存与别名最大值、真实JSON counter→新Battle后12次同序号续接、2^53+1和耗尽端点、UID域未安装/重复快照原子拒绝、部分堆叠与余量。不会运行Battle._ready，未验证跨进程整局、真实死亡效果、spawn生产调度/扣费回滚、地图/FX/单位顺序/tick、PCK或菜单。
