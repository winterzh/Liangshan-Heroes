# Readset 组件首次工具失败

原批次 `.godot/recovery_readset_20261027/20261027_040714_122b1aa3` 保持 complete=false。只启动 producer PID66668，退出1；105项中104通过、1项 `exact host gate` 失败。prepared 的102项是此前累计快照，不能再加计。未命中原生产断点，reader 和旧4MB档 clone 阶段都未启动，本批没有 Store 恢复结论。

原 request 与 ACK 的 pid=66668、index=0、nonce、process_nonce 逐值一致。冻结 driver SHA `3ab35682a677fafa3cb6d382bb9eec7bed3bfd38279af44f45d43c6dbf10f77e` 在 gate 中将 JSON 解码字典直接与原生 int 的 pid/index 字典整体比较；JSON 数字浮点 Variant 与该比较产生工具失败。原运行没有额外记录 Variant 类型，归档保留此证据边界，不伪造类型探针或后续成功结果。后续修订驱动绝不替入本批。

338个运行 pins 优先按原 runner_inputs 冻结副本回读一致；保留执行时的5份 QA 输入、3份 workers、原 host/producer 报告、控制器、traceback、日志、请求/ACK/绑定记录及完整冻结来源元数据。原宿主与控制器的错误均为 `Exact producer stop was not observed`。source_map 明列没有复制的祖先来源、EXE、5份 synthetic fixture 及外部 private seed；未复制 profile、业务载荷或工程资源，未重复散列全工程。

原 receipt 的 helpers_terminal_confirmed=false、lock_released=false 原字节保留。另存根线程稍后生成的 postflight_cleanup.json：原 child 已终态，实际 engine/helper 清单为空，worker provider 数0、IPC目录不存在，自有锁名称精确匹配后才释放。该独立清理审计的 lock_released=true 不改写原失败，也不授本批通过资格。

qa_status 在归属消息到达前生成的 QA根 evidence/readset_gate_failed_20261027_040714 旧19文件已只读校验、保持不动；本目录是根指定的 candidate/evidence 归档，并增加独立清理审计与详细来源映射。manifest 覆盖全部本目录文件（自身除外），所有原件写后逐项回读一致。公开入口、SDK、原版EXE、OS键鼠、人工验收、生产采用、性能或发布资格均未授予。
