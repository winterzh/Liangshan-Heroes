# CLOUD-ARM-001 后继源码修复 V2

保留 V1 GD/SOURCE、原链/API有限收据和追加拒绝收据。V1 缺少导出 ready 后、同步真实 `_apply_profile` 前的主机 arm 处理确认；不能授观察执行资格。

V2 增加 QA-only observer 子脚本。只有在原 capture 已安装、SDK-disabled、固定 cloud case、精确 PID/nonce/case/sequence0、同生产对象且尚无 snapshot 时才接受 `lsh_callback19:arm`；它只设置自身 arm 标志并发原始 `lsh_callback19:armed`，不改生产对象。原 read 捕获复用父实现，但需要 arm 已收到。host 必须先发生产断点命令，再在同原 TCP transport 发 arm，并保留原 send_complete/arm reply 字节；尚未实现 host 接入，也未验证当前引擎指令顺序。

driver 导出原 ready 与载荷后，在 30 秒有界 process_frame 等待里检查真实 observer arm_received。然后再次核对原对象、内存、writer/shared pending 与 dirty/pending/revision 均未变化，才调用原正常 `_apply_profile`。不手动触发回调、不改变时钟，不用 host 文件标记或元数据代替 engine dispatcher 收到消息。报告新增原 arm_ack，新 source 合同为完整33/driver-ready20/实际调用前23标签。

请只审查这一有限 source 差异、继承/API、固定命令与顺序接口。不运行 Godot，不做完整模拟，不把新增 arm seam 当原生兼容性或正式断点安装证明。stage=[]，GD_parsed=false。完整新 host packet/controller/publisher/consumer/restart/producer及成功prior、原生执行准入仍未建立；SDK/账号/上传和整个目标未通过。
