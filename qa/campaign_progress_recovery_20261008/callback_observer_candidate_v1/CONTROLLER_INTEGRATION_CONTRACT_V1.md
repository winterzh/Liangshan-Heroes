# 三个真实回调用例的后续接入合同

状态：设计合同，controller/driver 尚未实现，没有原生或执行准入。

## 自有进程与来源

Controller 必须接实际 subprocess.Popen，suite.batch.child 必须就是该对象，实际 poll 为 live 且 PID 与 phase 完整记录相同。每个事件重验上述关系及 suite 来源完整性。JSON 中 PID/identity、set_pid 或 loopback 地址单独均不证明进程所有权。只有来源封存绑定的真实自有子进程可启动该观察器。未知子进程保留 handle/lease，超时不当终态。

在收到唯一实际 set_pid 后设置固定生产 breakpoint。observer ready 必须原包校验且与实际 installed identity 和私有 user 目录一致。实际 debug_enter、stack_dump 必须为同线程；在请求快照前匹配下述生产栈，快照在继续线程前到达。JSON 无 Godot Variant 完整类型保证，完整 CFG/lifecycle 语义验收继续用原 typed record 消费者。

## 实际栈与三种路径

1. callback_sees_new_memory：SteamCloud.mark_dirty:230 为栈顶，直接调用 Campaign.progress_committed:405，其上 Coordinator.retry:189。真实自然终局通过原 Mission/四目标触发，不能 dummy Cloud 或直接伪造回调。观察时 Campaign 进度与刚确认的实际 CFG/ACK 一致；继续后 Cloud 的 dirty/revision 等按实际路径验证。
2. cloud_applying_callback_no_upload_claim：同栈顶，直接调用 Campaign._writer_complete:350；依次 Campaign._write_values:327、Campaign.apply_cloud_progress:396、SteamCloud._apply_profile:415。SDK-disabled 本地数字账号绑定明确为合成输入。由真实 _apply_profile 自行设置 _applying；不能手设 applying 或替换节点。快照中 applying=true、进度已发布；回调前后 dirty/pending_upload/revision 保持，随后 applying=false、实际 pending 清理；无实际上传或账号资格。
3. legacy_real_cloud_apply_failure_boundary：真实 _apply_profile 调 Campaign.apply_cloud_progress/_write_values/commit_prepared，固定真实 CFG 候选读回停点。故障控制器另审，必须只改当前持有 writer 的私有候选原件，并保留原始字节/真实锁/CFG 元数据。实际返回 false、Campaign 进度与公开 CFG 保持旧值、真实 pending writer/shared profile 保留；正常 Settings/Localize 写入可能已经发生，不能声称整个 profile 原子性。修复后同对象重试与重启另验，不能借成功案例资格。

## 包与结果的留存

每次接收先留完整 frame length + 原 packet bytes，所有拒绝包也保留。每次发送留固定命令原包并 fsync；只有 sendall 完成且原请求已闭合才记录请求已发送。read 请求须绑定已进入同一线程的精确栈、PID/nonce/case 和唯一序号。必须保存 ready/debug_enter/stack_dump/request/snapshot/continue 全序与源 pin。CallbackPackets 仅纯解码，不建立任何这些事实；其返回 ownership_proven/native_qualified 必为 false。

完整报告消费者须核对这些原包及实际 retained Popen、整个有序标签、CFG/lifecycle 原件、真实 before/after 状态、私有目录与安装身份。完整 producer 须封存 driver/controller/consumer 的所有依赖后另做独立审查，并接成功完整 V12 前置。当前固定包检查和有限源码预审均不能授予三用例、原19或整体通过资格。
