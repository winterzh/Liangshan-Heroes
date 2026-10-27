# B1设置重试：当前验证状态

2026-10-27。首轮实际两进程在第一阶段停止，整体未通过。观察器及对象ID校验已作最小修复，15命名输入／AST／帮助通过；当前修订已原生加载；新profile两进程`20261027_121110_ffd6005e`正在执行，尚无终态。

首跑`20261027_113510_63e310e9`实际PID25204，100.509秒，退出1。真实设置控件、返回保存、CFG_STAGE_PARENT及同故障下再次RetryCampaignConfig均达到；报告144项中139项通过、5项失败（4次Codec观察拒绝加最终阶段未完成）。宿主只累计成功阶段，故receipt.actual_checks=0；未解除故障并完成事务，第二进程未运行。宿主finally移出自有blocker，子进程／句柄／来源／锁均收尾通过。[失败原件](../../evidence/ui_config_retry_codec_failure_20261027_113510/README.md)不含业务或宿主blocker载荷。

[原生键类型模型](../../evidence/config_active_key_probe_20261027_114911/README.md)证实，新增dot键semantics_sha256为StringName，原生产Codec在$/key5拒绝；这是QA观察范围问题。新专用观察器完整保留6字段原顺序、key类型与文本，逐值继续用原Codec，原字典与is_same约束不变。实际RefCounted ID为负数，宿主另改为规范非零有符号int64校验；PID规则不变。生产Codec和存档协议未改。

[修订组合原生加载](../../evidence/ui_retry_tools_load_20261027_121008/README.md)已通过：PID40988，39.065秒，退出0／错误0；57命名输入、18份Python AST及129运行pins后验通过。12GD只load／can_instantiate，未实例化worker或Battle。

旧[三GD加载](../../evidence/ui_config_retry_load_20261027_111841/README.md)PID28348／32.059秒／退出0属于旧输入，不转授本修订。下一步需完整两进程：解除故障后同writer事务prepared1→applied2，独立重启核原偏好和文件不增长。Settings合法先写与Campaign旧CFG／进度分别核对。

固定b22及自身cold准入保持；未授公开入口、OS键鼠、人工验收、SDK、真实云同步、奖励仅一次、完整61或发布资格。
