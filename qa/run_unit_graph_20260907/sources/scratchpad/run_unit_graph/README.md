# Unit 图组合草稿

准备完成，尚未运行 Godot。只组合已受测的正式 Unit factory 与整数身份模块；没有生产调用方、共享 runner、Battle 全局恢复或菜单入口。

构造器按顺序注入七个可信 Script：`run_unit_state`、`run_graph_identity`、`run_state_value_codec`、`unit`、`hero_inventory`、`battle`、`game_map`。这些 Script 和内容版本来自调用方，任何快照字段都不决定脚本或资源路径。实际文件身份在 `pins.json` 中。

- `capture(battle, object_to_id, content_version, retained_identity = null)` 返回 `{ok, value, identity}`。`value` 包含 schema、可信版本、`root_order`、`active_order` 和同树顺序的 records。实体 ID 必须是调用方分配的唯一规范正 int64 十进制字符串；数组下标、字典插入位置与 native instance ID 都不是本模块的持久 ID 来源。
- `validate(snapshot, content_version)` 先核对完整 ID 集合、两种顺序和每条 Unit record，成功后返回独立快照副本及已知 ID 集。它不创建 Unit 或墓碑。最多4096个节点，每条record继续使用原codec预算；外层必须在JSON解析前和整局保存时约束总字节。
- `prepare(snapshot, content_version, destination_battle, destination_map)` 在所有record验证通过后，按树顺序创建全部新Unit，在完整registry上统一绑定。成功返回 `units_in_root_order`、`active_units`、`id_to_unit`、`object_to_id`、`activation_plan`、仍可绑定后续图的 `identity` 和仍存活的 `expired_unit`，并明确 `tombstones_released=false`。空Unit图的 `expired_unit` 为null；后续图仍可通过identity取得自己的typed墓碑。失败只清理本次创建的节点/墓碑；返回created/freed计数，不写入现有Battle字段或容器。

采集只读真实 `Battle.units_root` 的全部直接子节点（含internal），非Unit和正在排队删除的节点都拒绝，不静默跳过。实际死亡流程会先从 `Battle.units` 移除Unit，节点继续播放死亡动画；因此死亡节点仍在root_order和记录中，active_order则按原Battle.units独立保存。活动列表必须是root集合的无重复子集；矿工等待、驻军、命令等内部引用数组由原Unit模块保留重复和顺序。这里只核对图结构，不补造业务关系或自动修正名单。

在树内的Battle要求tree.paused；完整物理步/呈现边界仍由外层保证，不能把一个paused标志当作整个快照事务完成。root、world及地图的层级/变换、经济、FX、全部运行时顺序、全局UID分配、tick和游戏随机流不在本模块内。Unit图与后续Battle/效果图必须复用同一identity域。prepare不释放墓碑，不关闭后续retired整数token绑定；临时typed引用在此时仍指向真实存活的树外Unit。

成功后所有Unit仍树外禁用并阻断信号。调用方负责先使用返回的同一identity完成全部Battle/FX/整数图绑定，随后显式调用 `identity.release_tombstones()`，让typed引用成为真正已释放对象；再在同一暂停事务中安装所有图、按保存顺序挂接节点、安装活动列表、连接Battle死亡/剧情基础信号与其他系统监听，恢复RNG，最后逐项调用原factory的 `activate(unit, activation)` 并统一恢复运行。禁止仅完成Unit绑定便提前release或activate。成功plan的节点与identity所有权交给调用方；取消提交时显式释放这些新节点并dispose identity，不能将原Battle节点交给清理列表。

后续保存必须将该Battle保留的identity传回capture，以保持历史token。capture不会修改战斗对象；如果传入已有identity，采集中建立的历史token保留项可能在后续record失败时仍留在该上下文中，不回收或重新编号。调用方不应将本上下文当作玩法UID/tick分配器。

## 真实 smoke 接口

`graph_smoke.gd` 是SceneTree入口。采用现有 `RUN_RESTORE_QA_MANIFEST` 协议：`run_id`、`private_user`、`report`、`source_sha256`；唯一stdout前缀为 `[unit-graph QA] `，报告包含实际PID/user目录、全部check标签、来源前后SHA、complete/passed/failures。根runner负责非console引擎身份、私有APPDATA、实际Popen句柄、共享锁、全来源和真实玩家文件保护；这里不另建runner。

夹具使用真实、树外Battle/Map及四个活动Unit加一个死亡动画节点；持久ID与root/active两种顺序刻意不同。经真实JSON验证矿工/等待重复项、驻军双向关系、活着的死亡节点目标、已释放目标、身份池、命令顺序和Inventory UID/相位。最后一条坏record必须在分配任何Unit前拒绝，原图完整重采集仍一致。smoke先核对prepare返回的typed墓碑仍存活，再用同一identity解码此前未见的retired/retired_source token以证明绑定仍开放。模拟外层完成所有绑定后显式release，才核对真实freed引用。成功plan由QA挂到单独暂停staging根，原Battle始终不进树，不运行Battle._ready或新局部署，再调用原factory激活并观察两次暂停帧。

这些检查即使通过，也只证明此Unit图合同。它不证明整个Battle跨进程恢复、持续战斗等价、全部效果/经济/地图恢复、全局UID/tick连续性、PCK或菜单续玩。
