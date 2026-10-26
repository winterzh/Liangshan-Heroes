# 生命周期冷绑定：原 e97a 基线缺陷复现

原批 .godot/continue_binding_disk_20261027/20261027_014124_f95c72ab，PID 36652，原生 exit 0。6 条检查全部符合预期：3 条夹具前置、3 条原缺陷复现，没有 fixed 回归检查。

真实 Lifecycle.begin 写 gen1；新对象未显式接管同 token 时实际返回 LOCAL_TOKEN_EXISTS。拒绝保持原 gen1 文件及目录 SHA 不变。complete=true 仅表示这次预期基线诊断完成，baseline_defect_reproduced=true、fixed_lifecycle_model_passed=false、fixed_regression_count=0 必须同时保留。

167 个 pin、报告及日志 SHA 已独立回读；初末身份、子进程终态、终态 lane 空闲及自有锁释放均通过。保存 receipt/report/log、两个冻结 worker 和 runner_inputs 纯文本来源；两个 helper exe 明确排除，未复制 profile/存档/素材/缓存。报告内账户与 token 为明确合成夹具。

本结果不授后继修复、公开 Flow、槽恢复、自然战役、真实 SDK、生产采用或发布资格。manifest 逐项记原路径/大小/SHA，并复制后读回一致。
