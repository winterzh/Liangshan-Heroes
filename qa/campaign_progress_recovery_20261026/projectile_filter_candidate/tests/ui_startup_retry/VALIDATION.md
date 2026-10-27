# B2启动恢复重试：当前验证状态

2026-10-27。17项命名输入／12份Python AST及三GD原生加载已通过；实际三进程尚未运行。README、cases与sources保留工具封口时状态，本页单独维护后续资格。

实际加载批次`.godot/ui_startup_retry_load_20261027/20261027_111956_bde2d688`：PID23472，37.853秒，退出0，错误0。正常autoload后仅load／can_instantiate三GD，未实例化worker。40运行pins、实际引擎、子进程终态、最终来源与自有锁释放通过。

[原生加载原件](../../evidence/ui_startup_retry_load_20261027_111956/README.md)：26文件／423,485字节，manifest SHA `5671c73b7c451ef3668987e44d7bc2ccb9f98872c668c98db4761ed85bdb5feb`。

待跑实际三进程：第一进程真正设置UI提交，在原`cfg_before_install`断点验证完整prepared1后，由宿主终止自有producer，按受控崩溃故障记录，不能称正常退出。第二进程用可读但不共享删除的candidate句柄触发真实启动恢复`CFG_INSTALL_RENAME`；原RetryCampaignStartup保持故障再拒绝，解除后同对象重试至applied2。第三进程独立启动核原文件／记录／偏好不增长、无恢复重放。

producer到reader的owner变化须按真实恢复核对；reader两次失败间保留同对象、记录scope、owner和CAS。恢复路径的冻结配置按实际candidate与Values核验，不假定有写入路径的内存ConfigFile；unknown不作dead，`settlement_authorized=false`。固定b22、自身cold和共享lane门槛保持；加载不授实际故障恢复、自然奖励、公开入口、OS键鼠、SDK、云同步、完整61阶段或发布资格。
