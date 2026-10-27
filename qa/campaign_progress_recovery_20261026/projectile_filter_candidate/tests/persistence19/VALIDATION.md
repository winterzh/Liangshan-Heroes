# 原19类故障工具：当前验证状态

2026-10-27。当前8份实现文件已完成独立静态审查，三个Python入口的AST、默认轻量检查与帮助均通过。计划器核36个命名输入，执行宿主／协议探针各核41个；默认不创建profile、不启动引擎、不做完整来源准入。README和sources保留设计与输入绑定，实际资格以本页及原始收据为准。

首次原生加载批`20261027_094230_b03fa2f1`的PID13644退出2，29.883秒。大名府五GD和本工具bootstrap可加载，本工具worker因两处`seed()`调用被解析为Godot内置函数而失败，整个七GD组合未通过，未实例化或执行业务。失败时74个pins、引擎身份、进程终态及自有锁释放通过；[失败输入及原始日志](../../evidence/tools_load_seed_failure_20261027_094230/README.md)完整保留。

最小修正仅将辅助函数定义和两处调用命名为`_seed_private_campaign_fixture`，sources只更新该文件的大小与SHA；逆替换逐字恢复旧worker。新worker 33,101字节，SHA `31c650c5f1ea1b27b8226fe3728981dd15041608bc3db5030da032d55152a48c`；sources SHA `dd78ee15d245fef6763e84bd57560b6e993aeabbf64e72f0e1afd6f6b5cc8608`。本修正尚待重新原生加载，静态检查不算编译成功。

接下来由共享引擎的唯一持有者串行执行：新GD加载；`prove_fault_protocol.py --prove`实际9／12案；成功后由`run_persistence19.py --run --protocol-receipt <该原始收据>`运行全部19案。每次实际执行均重新验证固定b22完整来源及其首次冷导入，不能把轻量检查当准入，不能跳过真实协议证明。后续worker、来源清单或helper有变化，旧proof不再有效。

原19 ID／顺序与旧预期保留，当前组件oracle的差异在README和cases.json明确记录。此工具不是52负例中的capture19，不证明自然战斗、公开入口、桌面键鼠、SDK、云上传或奖励仅一次。当前全部运行资格均未授予。
