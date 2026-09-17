# 尘粒筛选候选：仅静态与纯数据阶段

此候选仅将 c0285f91d4131e7631707fa59903d4b61fd460bb 私有完整 M1 基线的 `scripts/unit.gd` 中一行 `_dust.filter(func(d): return d.t > 0.0)` 改为显式筛选。先执行完整的原递减循环，再建立新 Array，并按原顺序追加原 Dictionary 引用；保持原 `_request_redraw()` 调用。没有改健康检查、RNG、粒子数、频率或其他方法。

`source_receipt.json` 记录 Git blob、基线收据、原文件、候选和补丁 SHA；`candidate.patch` 可精确反向复原。`candidate/scripts/unit.gd` 是唯一待覆盖项，其他生产文件来自原基线，不从新 HEAD 混入。根 `.gdignore` 防止普通工程扫描候选。

`pure_data_review.json` 的 1007 个 Python 模型案例均通过，覆盖空 Array、t=0、递减后恰为0、负零、正 epsilon、负值、保留顺序、Dictionary 重复引用、新 Array 身份、保留元素引用以及模型 RNG 状态。负对照证明不能融合两遍：同一 Dictionary 出现两次，t=0.015、delta=0.01，原算法不保留任何元素，融合算法会错误保留一个。

这不是 Godot 原生或游戏性能结果。静态证据只证明替换中没有 RNG/健康调用且相关方法字节不变；Python 的 RNG 检查不能冒充真实游戏 RNG 检查。`data_smoke.gd` 从准确原/新代码块生成，准备在 Godot 上检查 1007 个同类数据案例、真实全局 RNG 后继值、引用/Array 身份及负对照。原生尚未运行。

原生驱动路径建议 `res://tools/stabilization_dust_filter/data_smoke.gd`，接受 `RUN_RESTORE_QA_MANIFEST`，字段 `run_id/private_user/report/source_sha256`；报告必须全新绝对路径，source key 为工程相对路径。stdout 前缀 `[dust-filter data QA] `，suite `dust-filter-data-candidate`。报告明确未执行实际 Unit timestep，不能代替正常 A/B。

`run_data.py --freeze-sha256 <本次冻结SHA> --run` 使用专属锁、短新profile和最小私有工程，只加载纯数据 driver；原始/candidate Unit 文件作为 `.gd.txt` 数据保留并SHA绑定，不加载生产类。这样无需复制/导入完整资产，预计只占数秒 Godot 槽。未加 `--run` 只预检。它验证真实用户、实际PID/日志、源/候选前后与退出/锁收尾；没有运行实际Unit物理步。该专属入口中的 driver 名为 `res://data_smoke.gd`。

后续由根安排 Godot 槽。先通过原生纯数据回归，再同机、固定 defense200、standard 特效、正常 60 秒做三对交替 A/B；每次新进程和私有用户目录，RNG fixture 与初始部署一致。以完整压力段、尾延迟和一致性判断，不用插桩 FPS，不把清场后的帧率当压力性能。若没有可信改善就停止，不跑五组全矩阵，不合入生产。基线三次压力段波动较大，不能在看到结果后放宽采用门槛。

当前过程/物理/绘制 CPU 监测也没有显示 GPU 是首要瓶颈；若这个小候选无效，后续诊断应围绕过程/绘制 CPU 余量。监测 process 包含 physics，且可能滞后一帧，不能相减当独占耗时。具体当前来源见主任务的 `scratchpad/stabilization_delivery_20260907/pressure_monitors.json`。

不得把本候选叠加到稳定身份或视觉图候选后分摊同一个 PASS；它仅与 c028 完整私有基线配对。公共文档和 Git 由根统一收尾。
