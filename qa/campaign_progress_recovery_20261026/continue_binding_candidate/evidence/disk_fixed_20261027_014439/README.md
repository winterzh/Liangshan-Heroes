# 生命周期显式接管：d7 候选真实磁盘模型

原批 .godot/continue_binding_disk_20261027/20261027_014439_edcfd332，PID 68316，原生退出 0、无引擎错误。36 条检查全过：3 条夹具前置、3 条旧 cold 对照、30 条 fixed 回归。complete=true、fixed_lifecycle_model_passed=true、baseline_defect_reproduced=false。基线对照另见 ../disk_baseline_20261027_014124/。

普通冷对象仍按旧路径返回 LOCAL_TOKEN_EXISTS；显式 prepare_credited_resume 只读接管实际 gen1，绑定本地原 token/SHA，不用合成 Steam digest 冒充。实际 mount-time 复核及重复 binding 不改变文件。11 项 fixed 拒绝断言覆盖 token/account/context/owner/content/engine 六种范围差异、absence→present、空目录、gen2 新对象及原对象、gen3 新对象；加旧 cold 共 12 条拒绝断言。部分原断言仅检查 !ok，没有保存具体 code，归档不杜撰错误码。

真实 terminal API 将本地 gen1 推至 gen2；gen3 是明确 fixture 通过实际 Store acquire/commit/release 写入，ACK/credit/terminal 数据为合成，未执行真实 Steam handoff 或奖励。报告 synthetic_gen3_ack_only=true，campaign_progress_committed=false 保持。gen1/gen2/gen3 原链与目录 SHA 均有报告证据，独立回读一致。

225 个 pin、报告/日志 SHA 及新候选身份/import绑定均核对；子进程终态、终态引擎空闲、首尾身份、自有锁归属及释放均通过。runner_inputs 包含运行时末尾守卫版本 aeacc196…，完整原字节保留。复制纯文本输入、收据、报告、日志与两个 worker；3 个 exe 排除，没有存档/profile、素材、缓存或原生编译产物。C# 源码只是来源材料。

只授生命周期磁盘模型。不授公开 Flow、槽恢复、自然战役、真实 SDK/账号、真实 handoff/ACK/奖励、生产采用或发布。manifest 逐文件记录源路径、大小、SHA 并复制后读回；当前真实 LHM 流程需独立运行结果。
