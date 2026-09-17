# 显式时钟与完整步屏障草稿

状态：隔离代码与驱动已准备，只有语法预检，原生待排队。生产 Battle/Unit/root codec、输入入口、保存槽没有修改。生产基线为 ROOT 确认的 `61f8f557cb19e5f6483f468ba3435767a2108584`（已正式接入身份 24 文件及 defense v2）。这两个小模块不是完整 Battle barrier；禁止用其存在或纯数据通过替代整局恢复验收。

## 源码结论与确定的迁移边界

`source_inventory.json` 扫描全部生产 scripts 下 GDScript，并保留所有 Engine 两种帧计数、Time 单调时钟、实际 process/physics 回调及 deferred 调用的位置和源 SHA。当前 Engine 两种帧计数只有四处：

| 来源 | 作用 | 续玩处理 |
|---|---|---|
| Battle._resource_blocked，1258 行 | 每物理帧资源阻挡结果缓存；同拍其他单位共享 | 要移到显式战斗缓存相位，连同 stable-ID 缓存值保留 |
| Battle._eco_lane_runtime_state，3999 行 | 16 帧共享路线规划桶，可能改变实际英雄指令 | 必须保存实际相位和原缓存；不能在恢复时无条件清空，不能等待新进程 Engine 凑 modulo |
| Unit._request_redraw，1082 行 | 一个 process 帧合并多个 physics catch-up 的 Canvas 重绘 | 保留 Engine 全局显示计数，不属于玩法相位；现 Unit schema 已把 _queued_redraw_frame 列入 omitted visual |
| Unit._queue_motion_redraw，1104 行 | 大兵量下每 2/3 帧按 stable ID 限制重绘 | 保留当前显示调度；不影响位移、伤害或寻路，不要求跨进程同模 |

`_ai_tick_frame` 已是显式战斗变量，用于英雄/召唤物 16 拍分相；`_sep_phase` 已保存 3 拍分离相位；冷却、经济、任务、波次和各效果已有 delta 累加/倒计时。不替换这些计时，不插入 RNG 抽样，不改原 pass、Unit root 顺序或技能消费者。60Hz 保持不变，速度依然由原 delta/Settings 机制决定。

不能直接把两个 Engine 查询替成 `_ai_tick_frame`：Battle 在 INTRO 先 return，AI 计数不增；Engine 在用户暂停时也前进；资源查询还可能在输入/初始部署而非物理回调调用。必须先验证 Engine 原帧计数在 physics_frame、父子回调、process_frame 的实际对应，再给新局首次查询和首步制定初始化桥接。草稿时钟的 `initialize_new(first_tick)` 接受显式起点，恢复只使用已保存 next_tick，绝不拿新进程 Engine 计数重定相位。本包没有擅自给生产选 0 起点，也没有声称暂停前后已经与旧缓存命中行为完全一致。

## 已可单独审核的时钟

`run_simulation_clock.gd` 不读 Engine、系统时间或 RNG。begin_step 发出一个整数 tick，end_step 仅在完整步结束后推进 next_tick；步内捕获、未完成过任何步、故障和溢出均拒绝。JSON 内 next_tick 使用规范十进制字符串，拒绝浮点 ID、前导零、指数和越界。最大 int64 仅为耗尽 next 哨兵。暂停期间不调用 begin/end，所以模拟 tick 不前进。

要落入 Battle/root 的最小接口：Battle 持有 `_simulation_clock`；新的根 payload 增加独立 `simulation_clock` record。原 `_res_block_frame`/`_eco_lane_cache_bucket` 归入该显式相位域，并一起保存 `_res_block_cache`/`_eco_lane_cache`，校验它们不超出已完成的逻辑相位。现根 v2 的 `clocks.physics/process`、`ROOT_ECO_CLOCK_PHASE_REQUIRED` 和按新 Engine 原点平移缓存均需在新 schema 中删除，不能把这些旧逻辑与新时钟混用。根字段归属/显式声明清单也要随新增 `_simulation_clock` 和运行期 barrier 重新穷尽检查。当前冻结的根候选没有被改写。

## 为什么物理尾节点仍不是完整保存点

Battle 的父 `_physics_process` 先跑任务/关卡/17 类数组；子 Unit 回调随后做移动、生产、状态与伤害；Projectile 子节点也会命中并同步触发死亡/统计。父回调返回时它们尚未完成。现 `LiBrawnAxesFx._process`（15415 行）还会按真实 idle delta 在 resolve_hits 结算伤害；不能把所有 _process 都标成显示，也不能在这次改动中顺手改成 physics 消费而改变原顺序。普通 TimedFx 到期 queue_free，GroundFire 的 tree_exited 又修改 Battle 的 _ground_fire_visuals。

关卡也有真实 deferred 玩法：官方快活林 `_verify_hit.call_deferred` 会标记任务命中，旧祝家庄/连环马还有延迟部署；这些语义不是 Node 属性快照能捕获的待执行队列。首次标准30波可限定官方模式健康态，之后按祝家庄、其余八关推进，但不能以首版范围为理由让共享保存入口接受未排空的 deferred 任务。

草稿 `run_step_barrier.gd` 只在隔离 fixture 中观察极早/极晚物理回调，不重排原默认优先级节点。请求先关闭**调用者提供的真实输入闸**；整批 physics 结束后的 process_frame 只暂停，不立即捕获；再经过一整帧暂停的 idle、嵌套 deferred 与队列删除，到下一个 process_frame 开始，重新检查时钟无半步、输入释放、外部健康/待执行队列谓词，才同步提供捕获机会。捕获后继续保持暂停，显式 release 才恢复请求前的暂停状态；中途暂停造成半步时永久 fault，绝不生成保存记录。

仍缺的整局接入工作必须显式完成：Battle/HUD/mission/button/输入信号到命令的闸门，真实 deferred 玩法计数或等价可审计排空证明；当前世界所有运行优先级/线程组与动态新节点的边界检查；Battle 新局时钟起点桥接及 INTRO/DEPLOY/FIGHT 的参与定义；完整世界故障、queued node、ALWAYS UI 回调审计；真正捕获/写入前二次健康检查及旧槽不变；真实 main.tscn 的 Unit/Projectile/LiBrawnAxes/任务案例。这里的 callable 健康谓词是 fixture 的具体证据，不是允许生产传 `{quiescent:true}` 自证。

## 显示与墙钟

AmbientMotes 的 Time 毫秒仅是空气浮尘相位，继续跟随本进程显示。Battle/Unit 的 usec 用于性能探针；Sfx 的 msec 用于声音防连播；HUD/输入 msec 用于长按、双击和编队居中，保存请求必须结束手势并复位短暂输入窗口，不能把按下状态跨进程重放。CampaignMission 的 _stage_started_ms 只生成内存 wall_seconds 诊断，实际任务elapsed走delta；后续任务适配应把已累计墙钟诊断拆开重建，避免读入旧进程绝对ticks，但不把它当玩法计时。

## 原生驱动与边界

`clock_smoke.gd` 延迟加载两模块，不加载 Battle。按与既有 overlay runner 相同的 RUN_RESTORE_QA_MANIFEST 协议接受 run_id/private_user/report/source_sha256，拒绝旧报告并守护全部实际源 SHA。复制为 `tools/stabilization_simulation_clock/clock_smoke.gd`。唯一 overlay 是两个新增小模块；生产保持不动。

驱动先测真实 JSON/int64/连续恢复的 16 拍边界，再由真实 SceneTree 按60Hz运行 parent+mission、两个Unit替身和Projectile替身。第12拍由第一个子节点发起请求，保留后续兄弟执行；有真正的两层call_deferred和queue_free。另有真实 `_process` 回调修改 fixture HP 并安排延迟工作，保存点须包含已完成的 idle 修改；第三次保存请求直接从这个 idle 消费者中发出。渲染仅临时max_fps=15，用实际观察证明一个process帧有多个physics tick（不用--fixed-fps、不直接调用回调）。另测捕获期间持续暂停、恢复运行、已有用户暂停保持、暂停时Engine计数继续而逻辑相位不变、真实子回调中途暂停的故障拒绝。退出恢复Engine测试配置。默认超时30秒足够，失败应保留尝试而非降低判定。

这些替身用来检验引擎调度假设，不是八关/30波真实玩法、已接入完整 barrier 或玩家续玩成功。原生运行仍由ROOT/QA独占Godot槽；本包准备不启动引擎。
