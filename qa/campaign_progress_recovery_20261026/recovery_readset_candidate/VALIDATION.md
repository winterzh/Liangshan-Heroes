# 恢复读集候选：当前验证状态

2026-10-27。候选尚未采用生产，公开战役继续仍关闭，原版键鼠验收保持暂停。README、source_manifest 和测试输入保留创建时原字节；实际资格以本页及各次原件为准。

## 实现与完整来源

只对运行时加载的原 Slot Script 对象复用完整校验结果；派生 Slot、CFG、LC、StartupReader 等继续使用原路径。每个实际解码的 record/pending 原文 SHA 必须与最初完整文件清单相等，owner 原文单独校验，缺项或变化拒绝；成功证书绑定当前实例、脚本、目录、owner、scope、epoch 及深复制计划。后续仍完整读取文件名、目录与原生 SHA，并再次核对 owner。fresh inspect、完整计划比较、inspect/claim 两次独立存活查询、每个恢复scope原有的3000ms共享预算和claim后的原完整校验全部保留。

这不是新文件锁，也不声称抵御任意外部恶意竞争或证明断电耐久性。原 `recover`、`_recover_base`、`_chain`、`inventory`、`_read`、`_decode`、提交、重试和清理函数原字节保持。

新完整冻结 `20261027_034810_ed1bdef8` 从 d7 的7062文件逐字复制，仅替换一份 Store，没有新增或删除来源文件，目录集一致。实际身份为 `source-v1:768b6e5937321126b4c927fce6b5565459610aa13ccb556f695837a814eb74c2`，完整23脚本＋helper清单SHA为 `11c1d813daab8fd9eeaa0e8ed7569deb33da3af243b429c9cffc69c6de74a5e6`。Store为 `f222e8b3798355164ab29da4d0dc534362e2bea680ec7f7dbe7462b86df8959f`。

独立导入 `import__20261027_035209_79e28901`：实际PID75344，退出0、错误0，用时51.221秒，完整来源后验和共享锁释放通过。[准备与编译原件](evidence/full_freeze_20261027_034810/README.md)。这些只授予准备与编译资格，不继承d7连环马或e97a文件故障的运行结论。

## 运行检查

[原Flow四进程工具](tests/classic_flow/README.md)的新批次 `20261027_035441_ec3aea99` 已完整通过：pending为writer14040/reader19676，record为writer61920/reader70208，两writer在指定真实保存断点计划终止，两个reader正常退出0。检查分别23/21/23/21，共88项；两案均fixed_branch_restored，完整暂停世界、资源、队列、原槽SHA/token和LC一致。宿主complete=true，来源后验、4个实际进程终态和共享锁释放通过。[原始证据](evidence/classic_flow_20261027_035441/README.md)。原d7的record超时仍保留；本批证明新源的两处分支恢复通过，不授公开入口或发行程序资格。

[读集专项工具](tests/readset/README.md)已完成代码和静态检查，原生执行进行中，尚无终态资格。覆盖12个具体case及旧4MB原档逐字clone；合成小夹具只验证文件协议，旧内容identity的clone不改写身份、不授新Flow世界恢复资格。原档仅由宿主只读核对，传给引擎的seed和profile均为新副本。

专项[首轮工具失败](evidence/readset_gate_failed_20261027_040714/README.md)保留：producer66668退出1，105项中104过/1个握手检查失败，零断点，reader和clone均未启动。确认消息四字段值完全一致，原测试却将JSON数值与原生整数直接做字典比较；后继仅修为严格字段/字符串与有界、有限、整值的数值核对，未改游戏源码或恢复断言。旧输入和原收据lock_released=false不变；另存的终态审计确认无引擎/helper、无IPC目录后释放精确自有锁。修订driver为3ce3ab64，已从全新目录重跑，结果另记。

## 剩余范围

本片成功也不能替代完整19类故障、61阶段、实际失败/重试界面、LC/StartupReader专项、未知PID/权限/平台矩阵、v2超时隔离、Steam云与奖励、完整战役和发行程序验收。正常Flow的初始按钮经过私有gate，随后才同步清标志进入原恢复分支；与公开入口、SDK或原版键鼠资格分别记录。
