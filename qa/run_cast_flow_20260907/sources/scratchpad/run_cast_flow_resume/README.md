# 施法流程恢复切片（仅准备，未运行 Godot）

仅新增本目录 cast_flow_state.gd 与 cast_flow_restore_smoke.gd；未改生产、Git或共享文档。三个数组是 _walk_casts、_pending_casts、_channels，不包括物品施法、bolts、traps或整局恢复。

固定实际字段：walk为c/slot/tgt/point/serial/t/age；pending为caster/slot/lp/tgt/serial；channel为caster/center/eff/sc/rank/r/tick/tick_t/ad。创建/更新点逐处对应 Battle._queue_walk_cast、_queue_walk_cast_point、_begin_cast、_begin_channel；消费为_walk_cast_pass、_tick_pending_casts、_channel_pass。channel的ad不能按数组旧注释省略；eff/ad整字典经有预算的codec保存，实际消费者字段校验类型，缺失可选键保留缺失，不填null，不丢未知元数据。非法Object/非有限/循环等由codec明确拒绝。

walk单体模式的point=Vector2.INF通过专用unit_target标记保存，点地模式用finite point标记；单体必须有entity/expired目标，点地必须none目标。该例外只属于这个已核实哨兵字段，不放宽普通codec。真实int64 serial/slot/rank、float计时、嵌套定义与数组顺序保留，过期计时或不匹配serial不修正，原consumer决定丢弃。

接口沿现有数组模块：new(codec_script,battle_script,unit_script)，capture/validate/instantiate/bind。传可信content_version和真实稳定Unit ID映射，expired引用绑定到外层identity.expired_unit()返回的活类型墓碑；所有图绑定后才释放。bind只接受树外DISABLED且信号阻断的真实空Battle壳，一次性赋三个数组，缺墓碑等拒绝不留下部分数组。它不下命令、寻路、begin_cast、begin_channel、扣CD、重新解析目标或运行consumer。

required_unit_fields列出外层至少要精确恢复的_order_serial/_cast_serial、_cast_t/_cast_dur/_cast_color、_channel_t/_channel_dur、ability_slots（CD/充能/序列）、原路径/队列/状态/目标与控制状态。这里仅声明依赖，不将匹配entry.serial误当完整Unit验证；旧entry与当前serial不匹配可以是合法待取消状态。完整Unit adapter、地图/导航/视野、能力定义与关卡hooks/其余图由外层先恢复。待抬手时间在Unit中，channel剩余总时长也在Unit中，本模块不能单独恢复这两个倒计时。

smoke入口res://scratchpad/run_cast_flow_resume/cast_flow_restore_smoke.gd，suite=cast-flow-restore，stdout=[cast-flow-restore QA] ，沿RUN_RESTORE_QA_MANIFEST的run_id/private_user/report/source_sha256。pins列直接来源，host仍须全工程/玩家守护、独占锁、实际PID、严格日志、新私有profile与run；本目录没有另建runner，根按现有有限runner适配。

夹具是真实Battle、Unit、GameMap、LevelBase、HUD壳，不运行Battle._ready；两个完整能力QA定义走原smite路径，channel使用实际Defs的ling_zhen_q。先由真实creator创建两个walk模式、抬手和已消耗一跳的channel，另有真实释放目标/施法者。真实JSON后只绑定数组；Unit局部值和原路径由夹具直接供应，未调用创建/施放/寻路重建。25步调用原三个consumer和真实Unit施法/引导计时体，真实order_move与apply_silence验证取消；第3步位置到达由夹具显式供应，不冒称完整移动仿真。预期pending第3步一次、walk第7步一次、channel第4/8/12/16/20步五次，其余过期目标/中断不额外扣冷却；具体项数与结果以根后续实际引擎收据为准。

已有抬手准星/引导特效Node、视觉随机字段、完整Unit/地图恢复、调度顺序、一般未来实体分配、全局RNG隔离、退出重启/菜单/PCK续玩均未验收。当前只完成候选与静态字段核对，没有引擎通过结论。

