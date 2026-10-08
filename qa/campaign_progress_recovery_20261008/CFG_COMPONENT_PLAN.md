# CFG 受控替换组件：待执行矩阵

当前准入为 `CFG_COMPONENT_SOURCE_PREFLIGHT_V5.json`，8项源码SHA；Python解析及本地方法闭合已检查。没有启动此组件的Godot进程，没有组件原生通过、独立审查或玩家恢复资格。完整续玩活批结束前不启动第二个自有原生批次。

真实四案例、八进程：

| 案例 | 实际动作 | 新进程要求 |
|---|---|---|
| 正常写入 | 实际ConfigFile保存临时候选、固定原CFG SHA检查、旧文件移入自有备份、候选安装、完整语义/稳定SHA回读、applied日志；重复同内容 | 所有检查通过、原偏好/未知字段/无关record保留，不叠加fixture计数 |
| backup窗口 | 精确源码/函数/行/thread调试断点，旧CFG已移走、候选与备份真实存在后，只强制结束控制器自己的引擎 | 确认旧PID已终止，再从固定元数据/实际备份与候选恢复，完整CFG读回 |
| install窗口 | CFG已安装、applied确认前，精确断点结束自有引擎 | 真正新PID恢复相同事务，真实语义/哈希一致；不重跑游戏或奖励 |
| 外部CAS | 精确断点前控制器修改自己的真实CFG，后继再次检查原SHA并拒绝 | 外部CFG仍在公开CFG位置，独立恢复也拒绝覆盖，原变更保持 |

Native断点与协议必须使用已实测 `debug_probe_3314a8ba` 收据及本机实际基线，同SHA官方引擎。每个案例使用新UUID/profile；两次中断案例的第二进程故意读取同一个新的故障fixture，以证明跨进程恢复，不复用旧完整续玩失败profile。控制器只改变自己的文件或结束精确Popen子进程，保留原返回值、零source monkey patch。

只读预检：`python -X utf8 -B tools/run_campaign_cfg_transaction_probe.py`。

实际运行需要 `--run --source-preflight qa/campaign_progress_recovery_20261008/CFG_COMPONENT_SOURCE_PREFLIGHT_V5.json --protocol-receipt <实际成功协议收据> --baseline <实际本机基线>`，还须显式提供当前Godot路径。原生每阶段连续自然空闲60秒；启动后外部引擎进入或任何未预期日志错误，整批终止保存。源/安装文件/引擎全程SHA绑定，报告实际PID/nonce/mode与12/8/6/2检查数精确核对。

此为最小原生CFG组件工程，CFG内`component_fixture`是合成数据，不是Mission结果或自然胜利。八章意图、玩家UI、普通fresh/续玩入口、prefs/cloud门禁、gen2→cfg→gen3 ack、Steam奖励与发行/性能/真机仍另需集成和完整验证。

原v1源码/audit和V1—V4准备/源快照保留，不能沿用过期SHA。V1准备发现baseline字段误用，V2/V3加强检查数/PID/thread绑定；后继发现whole-file encode_to_text不转义`]`章节名，改为独立深拷贝ConfigFile真实save；备份前重新读SHA，确保CAS拒绝保留公开CFG。只保留源码标签依据，尚未证明安装二进制与该tag精确源码相同。代码不宣称断电原子性或不合作外部writer的原子CAS。
