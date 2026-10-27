# D释放失败模型：当前验证状态

2026-10-27。两进程工具已完成实现和交叉源码审查，19命名输入／10份Python AST／帮助通过。三GD已原生加载，实际两进程尚未运行；README／cases／sources保存封定契约，本页单独维护执行状态。

[原生纯加载原件](../../evidence/ui_release_fault_load_20261027_122159/README.md)：PID49172，42.018秒，退出0／错误0；含loader共11份Python AST，44运行pins、child终态／engine未变／锁释放均通过。只load及can_instantiate，未实例化worker、Battle，未调用abort_step或执行故障模型。

本片在真实经典菜单与普通120tick运行、原SaveAndExit后的健康HELD信号边界，仅调用一次原clock.abort_step构造永久故障。验证原捕获失败、非pending Session释放、RetryRelease持续拒绝、Leave取消保留原状态及确认后production continue_failed退出；独立第二进程应NO_SLOT／CloseError且业务文件和进度不变。注册枚举不把数组顺序当调用顺序；原same-stack阶段、Session空、健康Clock和两唯一ONE_SHOT连接共同约束注入时机。

明确fault_model=true、no_gameplay_state_injection=false；没有自然玩家故障复现资格，也没有清除永久故障或RetryRelease成功分支。本片不写生产协议，不授公开入口、OS键鼠、SDK、完整战役、19案矩阵、61阶段或发布资格。下一步完整b22及自身cold准入后，另用新profile执行两进程。
