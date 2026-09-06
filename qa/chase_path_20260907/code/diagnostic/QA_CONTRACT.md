# 窄探针 QA 合同（所有真实引擎项目待测）

本合同限定已有普通与 firing 两条直接调用链，不增加剧情路线或正式性能矩阵。82 项静态结果只证明 Python 可解析、严格来源、变換可逆和原调用数量；没有报告引擎编译成功或返回值等价。任何后续运行都由持有共同 Godot 锁的根任务串行执行，使用真实非 console 引擎句柄、新代私有 profile 和明确输出目录。

## 首次编译及行为复验

先在已审核新代私有工程导入并检查严格 UTF-8 日志；GameMap／Unit 从实际冻结来源加载。引擎应在 Autoload 就绪后实例化地图及 Unit，比较原始和插桩版本的**完整有序 PackedVector2Array**，不能仅比较“可达”。有限夹具使用相同真实地图／nav 设置；插桩启用和关闭分别记录调用与返回，原方法只调用一次。不要通过第二次隐藏寻路来生成一个“预期”标签。

| 边界 | 原行为和最少断言 | 当前状态 |
| --- | --- | --- |
| strict 起点非法／无可用端点 | 原返回空；端点拒绝一次，A* 入口零次 | 待测 |
| strict 同格 | 原单点结果及世界坐标精确一致；A* 零次 | 待测 |
| strict 完整可达 | strict A* 一次；有序点列和平滑末点一致 | 待测 |
| strict A* 空且远程 | 原空结果触发一次真实 fallback，不重置 0.4 秒节拍 | 待测 |
| strict A* 空且近战 | 不进入 fallback | 待测 |
| fallback 起点／reach 前置拒绝 | 保留原 `or` 短路，不访问 A* | 待测 |
| fallback 查询返回空 ids | 不读取 `ids[-1]`；记录 A* 空，原返回空 | 待测 |
| fallback 非空 ids 但端点超射程 | 只按原 `reach - 4.0` 判定；不与 ids 空混并 | 待测 |
| fallback 一节点及多节点结果 | 一节点去起点后最终可空；与 ids 空分开；多节点逐点一致 | 待测 |

`FALLBACK_NO_OPEN_TARGET` 属已有保护分支：从同一同步稳定地图的合法开放起点出发，最近开放格扫描通常必能至少找到起点。若真实 fixture 不能命中，不为凑覆盖改导航实现；标记“真实不可达／未命中”。可另用明确标注的隔离故障 stub 验证该分支的 ledger 分类，但不能把它混为真实 A* 或生产地图覆盖。A* 空的其他不可达边界也须如实区分真实命中与 stub。

在一个直接 `_do_chase` 原调用前后，比较 `_path` 完整点列、`_path_i`、`_repath`、位置、目标、状态、追击意图和放弃／队列推进结果。比较期间不 `await`，除既有方法外不新增 RNG 调用；如跨两个实际 Unit 比较，不篡改 instance ID，说明脚本和 Unit 身份差异。不得为了“恢复状态”改写受测业务字段，反而掩盖观察副作用。真实树生命周期／退出仍由原 M1 `_dispose` 和 battle freed 检查覆盖。

## 每个物理步必须守恒

- `chain_calls = chain_completions = strict_calls = strict_returns`。
- `fallback_calls = fallback_returns = strict_ranged_empty`，且 `strict_ranged_empty <= strict_empty`；每条同步 chain 至多一次 fallback。
- `strict_calls = strict_endpoint_reject + strict_same_cell + strict_astar_enter`。
- `strict_astar_enter = strict_astar_return = strict_astar_empty_reject + strict_smooth_return`；`strict_astar_empty_ids = strict_astar_empty_reject`。
- `strict_empty = strict_endpoint_reject + strict_astar_empty_reject + strict_smooth_empty`。
- `fallback_calls = fallback_precondition_reject + fallback_no_open_target + fallback_astar_enter`。
- `fallback_astar_enter = fallback_astar_return = fallback_astar_empty_reject + fallback_reach_reject + fallback_smooth_return`；`fallback_astar_empty_ids = fallback_astar_empty_reject`。
- `fallback_empty = fallback_precondition_reject + fallback_no_open_target + fallback_astar_empty_reject + fallback_reach_reject + fallback_smooth_empty`。
- timed：所有耗时非负，A* 不超过包含它的完整方法；随后 fallback 那批 strict 耗时分别不超过所有 strict／strict A* 耗时。clockless：六个耗时列恰为 `-1`，计数列仍非负。零次寻路的物理步合法，不强制虚构调用。

`get_id_path` 前后各一次观察，入口与返回必须相等；若引擎中断、作用域未关闭或任何嵌套冲突则整轮无效，不能用不完整计数外推。ledger 不会修复或跳过原导航调用。

## 两个 10 秒入口的资格与离线关联

同一 frozen 源、原 M1 defense200／fixed／1440×900／Forward+／60 Hz／time scale 1／seed 5088120／300 步预热目标，分别设置 `CHASE_PATH_MODE=timed` 和 `clockless`。输出参数是 `CHASE_PATH_OUT`、`CHASE_PATH_OUTPUT_ROOT`、`CHASE_PATH_USER_ROOT`；实际 `user://` 必须在本代本场的新 profile 下，stdout 与 sidecar 都须保留。`POLISH_OUT` 由同一 driver 派生 `m1_10s.json`。

账本物理 tick 从 1 连续到 `m1_end`，每行 44 个整数。测量区间按 `m1_start.m1_tick < tick <= m1_end.m1_tick` 选取，不硬切预热目标数。原 M1 帧数、raw_frame_ms、呈现表行数一致；每个 frame 的微秒差与原 M1 毫秒值一致，frame 链从原 start 时间起连续，测量物理步按已存 begin/end 行范围恰好关联一次；process ID、physics ID、signal/observer 先后有效。最后呈现到 end 锚的短尾部单列，不伪造一帧。

来源／缓存／进程守护由新代 runner 保存前后清单及真实 Popen 退出证据。GD 不自报 PID，不能写成“GD PID 与 runner PID 双重一致”。原日志、失败和原收据不可覆盖；完整分析用新增收据链接原报告 SHA。任何统计只用于定位窄链成本；它与上一轮 whole target／body 是嵌套且不同观测窗口，不能相加或相减，不能转成普通版 FPS 收益。
