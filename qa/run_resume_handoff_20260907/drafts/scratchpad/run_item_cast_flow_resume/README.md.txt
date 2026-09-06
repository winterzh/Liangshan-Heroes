# 物品施法流程候选（prepared，未运行 Godot）

仅本目录新增 item_cast_flow_state.gd / item_cast_flow_restore_smoke.gd / pins.json / 本说明及.gdignore。未改生产、Git或共享文档，没有runner或引擎通过结论。当前固定Battle为47357265c54a8cd6c2a5fef24998e357773974843559c4e23965ea3e0d51b629，Inventory为ab2d40f51695a4141bea1566a997883cc839f36bf6781fc0977151162d4fc595；后续生产窄修复应保留本基线并新建版本指纹/实际run，不能覆盖原失败证据。

## 两条原生队列

_pending_item_casts来源Battle._begin_item_cast：caster / slot / uid / point / target / serial。Unit.begin_cast_windup提供真实_cast_serial和剩余_cast_t，入队尚未start_cooldown/consume_one。原slot仅是起手时槽位，consumer按uid调用inventory.find_uid定位当前槽；换槽、转移、消费后不允许用旧slot替换UID或丢弃记录。

_walk_item_casts来源Battle._queue_walk_item：c / uid / tgt / point / serial / t / age，原consumer为_walk_item_cast_pass。保留数组顺序、int64 UID/serial、float余时/age、原地面点和引用；新建或替换意图的serial=-1、t=0、age=0与已下过路径命令的序列均可保存。过期age/t、stale serial、库存已无该UID的合法待取消项不修补，原consumer自己决定丢弃。

所有字段必须精确存在，slot为原六槽合法int；UID只能是已发行范围内正int64，拒绝float/0/INT64_MAX耗尽哨兵，不进行数值强转。单体walk的Vector2.INF在该专用字段编码成unit_target，目标必须entity/expired；点地模式要求有限point和none目标。pending.point总为有限Vector2，target可none/entity/expired；caster只接受entity/expired。类型、未注册引用、未知ID、缺字段、非有限值由显式schema与有预算codec拒绝，不用null蒙混。

## 外层依赖

new(codec_script,battle_script,unit_script)，capture / validate / instantiate / bind沿既有组件API。可信content_version和固定Script由调用方提供；模块没有运行时源码读取或存档动态load。bind只接受树外DISABLED、信号阻断、两队列为空的真实Battle壳，完整校验后一次赋值；不下命令、不寻路、不_begin/_do_item、不重新扣冷却/消耗库存/分配UID。

capture/validate/bind返回item_uid_aliases（保留数组名/index/真实int64 UID）与item_uid_alias_max，明确item_uid_max_scope=these_two_queues_only。它们只是两队列的别名输入，不能冒充可信完整图的最大值；外层run_item_id_state所需verified_allocated_uid_max必须再覆盖所有活/死亡库存、hero_item_progress、退休进度、proc及其他效果/队列别名，必须包含已消费/转移或施法者释放后仍在队列的UID。合法重复alias不去重成新物品、重编号或重新分配。

外层先恢复Unit时钟(_cast_t/_cast_dur/_cast_color/_cast_serial等)、order serial/原路径/队列/目标、控制与garrison/story状态、库存slots/count/UID/cooldowns/proc_cooldowns/_uid_seq/_periodic_acc和所属Battle、可信item定义及地图。required_unit_fields/required_inventory_fields只是依赖声明，不证明完整Unit/Inventory恢复层已经接入。库存cooldowns按item_id共享，不能把每个slot分开重启；恢复后的原consumer继续按UID找槽、检查ready与serial、结算一次。expired引用绑定同一开放identity的活类型墓碑，全部图绑定完成才统一释放，随后安装/启用；不能把真实expired当none。

## 未掩饰的生产消费者缺口

当前_tick_pending_item_casts和_walk_item_cast_pass仍以target != null包裹is_instance_valid。已释放Object可能比较为null，前者随后向typed _do_item_active传原target，具备与刚修复技能pending相同的错误路径；walk的单体INF哨兵还可能直接使其丢弃而不明确检查expired。此候选不在smoke中模拟修复consumer、不改保存目标、不省略真实释放对象；根负责真实旧代码实跑、原证据保留及下一批生产窄修复。

## 真实 smoke 入口与范围

入口res://scratchpad/run_item_cast_flow_resume/item_cast_flow_restore_smoke.gd，suite=item-cast-flow-restore，stdout前缀[item-cast-flow-restore QA] ，宿主RUN_RESTORE_QA_MANIFEST沿run_id/private_user/report/source_sha256。pins列17个直接来源；根提供全源码/玩家守护、固定引擎、独占锁、严格日志、新私有用户目录、实际PID和新run。本目录无新runner。

夹具用真实Battle/Unit/HeroInventory/GameMap/LevelBase/HUD壳，所有入队、换槽、消耗、打断/新命令与结算走原API。三种QA物品定义（unit/point/self、0.5秒抬手、8秒共享CD、消耗一份）经真实item效果和heal路径；13个活Unit、真实已释放目标及施法者。有序五条walk/六条pending保存时包含14.875秒age、0.375秒余抬手、已从0换到3槽的UID、已被消费至空的UID、已释放施法者持有的最大UID别名。起始next_item_uid设为9007199254740993作为可信高水位夹具，验证JSON不经float损失精度。

实际JSON→校验→新Battle→正式counter.restore（可信最大仅对这份完整有限夹具成立）→直接供应Unit/库存值→统一identity绑定两队列→释放墓碑→回捕。负例检查缺UID、floatUID、耗尽哨兵、floatserial、错误pointmode、未知引用、版本不匹配、缺墓碑及非空目标；检查拒绝不改变数组/Unit/库存/计数器。原库存冷却/被动时钟不通过restore或_notify重建。

计划12步调用原_walk_item_cast_pass/_tick_pending_item_casts、真实Unit施法计时体或真实Inventory.tick；第2步实际新命令/中断，原age消费者处理超时；第3步显式供应走近位置（非完整移动仿真）。预期pending单位/自身第3步各一次、walk单位/点地第7步各一次；换槽后正确只消耗新槽一份、同名第二stack共享CD、不重复消耗，过期目标/施法者/删除UID/取消/超时不新扣费或CD。最终结果必须看根后续实际运行，不能由此预期文字当成已过。

保存时既存视觉Node、完整UnitGraph/Inventory载入与Battle/地图事务、完整高水位验证器、全部物品定义/用户交互、一般未来实体分配、RNG隔离/迁移、退出重启、菜单/磁盘/PCK续玩均未验收。全局英雄倍率显式关闭作为QA前提；模块本身不改变Campaign或其他生产状态。
