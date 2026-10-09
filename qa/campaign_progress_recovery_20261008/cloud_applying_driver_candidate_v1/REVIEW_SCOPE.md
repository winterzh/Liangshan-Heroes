# 真实云应用回调驱动源码候选 V1

该 GD 复用已封存父脚本的普通菜单启动/来源身份/私有环境检查，仅覆盖 `_fresh`、原字节 `_write` 和自身报告 `_finish`。它不运行黄泥岗，不声称自然通关，也不替代首次/重复的完整游玩用例。

实际调用链是生产 SteamCloud `_apply_profile` → Campaign `apply_cloud_progress` → 真实 CFG transaction → `_writer_complete` → 生产 `mark_dirty`。不替换节点，不手动切换 `_applying`，不直接改 Campaign 内存。只向真实 Cloud 的内部账号 seam 输入固定数字 `1`，用于 SDK-disabled 本地夹具；不构造账号连接、SDK 上传或奖励资格。

载荷来自生产 `_build_payload`，目标进度是明确的本地输入 `schema=2, unlocked=2, records={}`；它不是玩家自然通关证据。driver-ready 与 apply-ready 在调用前由闭合原件标记导出，含原内存、cloud dirty/pending/revision、CFG SHA、精确载荷和实际对象 ID。实际回调必须后续由真实 owned debugger 在绑定生产栈只读观察一次，原包保留；当前只读观察器的可执行兼容性仍未证明。

调用后检查实际内存与全量公开 CFG 进度语义、同对象、writer/shared pending/applying 关闭、原 dirty/pending/revision 不变及 SDK 保持不可用。旧 dirty/pending 可以是启动写设置的结果，不能强制清零或把保持原值误写成上传状态为 false。

30 个完整 source 标签与调用前 20 标签由已审父 header 和 balanced check parser 组合，尚未实际解析或执行。三份 export 的 publisher/完整原包与 CFG journals 消费者、实际同档案重启、完整 producer 尚未接入。请做有限源码和生产 API 审查，报告确定阻断及未证明项；不启动 Godot，`approved_stages=[]`。另一个实际云文件失败边界、全部其余原19及原目标保留。
