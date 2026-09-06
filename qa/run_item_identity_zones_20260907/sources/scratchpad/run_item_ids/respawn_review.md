# Inventory.restore 布尔返回值的有界复核

仅源码复核和新增补充QA草稿，未运行Godot/Git、未改生产或原冻结candidate/pins。引用行号为候选所基于的原生产正文；应用后按方法名定位。

结论：没有发现`restore=false`会直接丢退休物品、错误出队或重复扣资源的源码阻断。已付款训练采用现有“保留队列、重试、取消退费”合同，并非失败自动退费。现有item smoke未覆盖真实生产链，应用后必须补下述实际回归，才能把这条失败链写成通过。

精确调用链：

1. `scripts/unit.gd:978` 的真实致死`take_damage`同步发出died信号；`scripts/battle.gd:2021` `_on_unit_died`先保存`hero_item_progress`，再保存可成长英雄的`hero_progress`，从`units`移除。Unit随后进入死亡动画；节点保留1.4秒属于正常行为，不能误判为失败生成的幽灵Unit。
2. `scripts/battle.gd:1740` `queue_train`先做英雄唯一/人口/资源校验，`spend`只在下单时调用一次，再放入`bld._train_queue`。
3. `scripts/unit.gd:1794` `_production_tick`到期调用`Battle.on_unit_trained`；`scripts/battle.gd:1953`中`spawn_unit`为null时已有立即`return false`，不会调用关卡完成hook、恢复/删除英雄成长进度。
4. 本窄补丁的`spawn_unit`在库存restore失败时`queue_free`新Unit并return null；失败发生在`died/story_resolved`连接、AI生成序号递增和`units.append`之前。退休物品进度只在成功restore后erase。清理是帧末队列释放，不能要求返回瞬间units_root就没有暂时的新节点。
5. `_production_tick`收到false后不出队，设置`production_blocked=true`、重试间隔0.5秒。它不会再次调用spend；按候选行为，每次失败会临时创建一个Unit并排队释放，故需真实帧后反复重试检查。
6. `scripts/battle.gd:1794` `cancel_train`全额调用add_resources，移除队列并清blocked/retry/timer；不动退休物品/成长进度。重新安装正确原snapshot后再次下单，成功才消耗队列和两份进度。

一个用户反馈边界：失败目前共用`production_wait_label()`的“等待出口/清开出口”提示，即使实际原因是库存UID域不合法。它不构成物品/资源丢失，但提示不足以指导修复。完整RunSession必须在激活前拒绝坏counter/库存，不能把此重试路径当作自动修复或加载降级。这里未扩改生产提示体系。

最小必要回归组合：

- 保留冻结的`item_id_smoke.gd`：连续发号、1201stack、转移、counter JSON/新Battle、耗尽余量等allocator合同。
- 运行既有`Battle._item_selftest()`，真实标准Battle启动参数组合为`SMOKE_TEST=1`与`ITEM_TEST=1`；必须检查唯一`[item] ... ALL=true`和严格日志。入口在Battle._ready内，仅ITEM_TEST=1不会执行。该测试覆盖真实英雄属性/被动/共享CD、换位转移、主动伤害治疗击杀；它的“snapshot”检查只是`snapshot()`和`tick_snapshot()`，没有调用restore，也没有物品死亡→付费复活链。
- 新`respawn_cases.gd`：在独立、已初始化的标准30波skirmish Battle上`await cases.run(battle, tree)`，把返回的`[{label,passed}]`并入根受控报告。要求是可丢弃QA Battle，函数会暂停树、设置夹具资源、添加一个临时物品定义；不会写存档/生产。根负责加载协议、source前后、PID、私有profile、严格日志和结束dispose。函数返回后树仍暂停。

新补充执行真实`take_damage`→死亡回调/两份进度；随后仅把保存UID改成尚未分配的next值来触发拒绝，用真实`queue_train`、`_production_tick`、`cancel_train`检查保留付费队列、重复失败不再扣费、帧后清掉失败节点、全额退款、两份进度保留；再恢复原snapshot并重练，核对新对象、原UID/数量/CD、英雄成长、一次扣费、一次新AI序号。训练完成时间通过设`_train_t=0`明确加速，不冒称走完正常墙钟训练时长。旧死亡动画节点因暂停仍存活，专门检查它始终不回到活动units。

既有`tools/lianhuanma_drill_test.gd:79-98`确有真实许宁致死、付费queue_train和正常训练计时后新许宁/关卡hook检查，可在已有整套公共QA安排里作为跨关卡回归；无需为此窄补丁重复整场操练。它没有放入物品，也没有坏snapshot、失败重试或退款断言，不能代替新补充。

这里不证明所有spawn_unit调用方、真实购物结算、整局存档恢复或战役平衡。候选的旧`Inventory.restore`仍限定程序内生成的可信同Battle复活snapshot；外部加载继续走严格Unit adapter，不能把它当任意恶意JSON入口。
