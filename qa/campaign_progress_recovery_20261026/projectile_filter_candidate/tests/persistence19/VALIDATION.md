# 原19类故障工具：当前验证状态

2026-10-27。当前固定b22的原19类故障已完成19个独立进程／566项组件矩阵，全部通过；实测范围和原件见文末。三个Python入口的AST、默认命名检查和帮助已通过：计划仅核36项命名输入，执行宿主及协议探针核41项；默认不创建profile、不启动引擎、不授完整来源准入。README与sources保持冻结来源绑定，实际资格以本页及原始收据为准。

首次原生加载批`20261027_094230_b03fa2f1`的PID13644退出2，29.883秒。大名府五GD和本工具bootstrap可加载，本工具worker因两处`seed()`调用被解析为Godot内置函数而失败，整个七GD组合未通过，未实例化或执行业务。失败时74个pins、引擎身份、进程终态及自有锁释放通过；[失败输入及原始日志](../../evidence/tools_load_seed_failure_20261027_094230/README.md)完整保留。

最小修正仅将辅助函数定义和两处调用命名为`_seed_private_campaign_fixture`，sources只更新该文件的大小与SHA；逆替换逐字恢复旧worker。新worker 33,101字节，SHA `31c650c5f1ea1b27b8226fe3728981dd15041608bc3db5030da032d55152a48c`；sources SHA `dd78ee15d245fef6763e84bd57560b6e993aeabbf64e72f0e1afd6f6b5cc8608`。本修正已在文末所列批次通过原生加载；故障机制和19案运行结果另行验证。

新GD加载和实际矩阵均已完成。后续重跑仍先用同一工具执行`prove_fault_protocol.py --prove`，以同源、同工具的成功原收据运行`run_persistence19.py --run --protocol-receipt <该原始收据>`。每次实际执行均须完整验证固定b22和自身首次冷导入，不能把命名检查当准入，也不能跳过真实协议证明；工具、worker、来源清单或helper变化后，旧proof不再有效。

原19 ID／顺序与旧预期保留，当前协议和oracle差异在README、cases.json明确记录。此工具不是52负例中的capture19。本次19进程／566项只授组件矩阵，不证明自然战斗、公开入口、桌面键鼠、SDK、云上传、奖励仅一次或完整61阶段。

## 修正后原生加载已通过

批次20261027_101643_6b41c660实际PID512退出0、错误0，39.579秒。七GD全部load/can_instantiate成功，74命名pins／引擎／自有子进程终态和锁释放通过；未实例化worker。[原件及68个固定Git blob引用](../../evidence/tools_load_complete_20261027_101643/README.md)。proof批20261027_101914_d5fdb00e已通过实际9／12验证，详见下段；完整19案仍单独执行。

## 实际9／12协议证明60项通过

[原始协议证据](../../evidence/persistence19_protocol_20261027_101914/README.md)实际两进程PID6324／28424均退出0、错误0，各30项。9案真实candidate_save→save_return期间CREATE_NEW/share0哨兵阻止实际ConfigFile.save，返回CFG_STAGE_WRITE且owned_pending；12案真实candidate_load的oplock收到native opener break后才写语义等价注释，before／after SHA变化而语义保持，返回CFG_READBACK_CHANGED／CFG_STAGE_READBACK。原CFG84字节及SHA保持。41命名来源、完整b22准入、自有cold、873运行pins后验及2子进程／锁终态通过；protocol_proved=true，component_matrix_qualified=false。

完整19案宿主已消费这份精确原收据启动，结果以新矩阵终态为准，不把两项证明当作19案通过。

## 19个独立进程／566项组件矩阵通过

实际批次`.godot/persistence19_b22_20261027/20261027_103731_9d856aa2`：19个distinct PID，566项全部通过、各进程退出0，宿主`complete=true/component_matrix_qualified=true`。完整b22、自身首次cold、41命名输入及960项最终pins闭合，子进程、引擎lane与自有锁均终态释放。

case6只接受本案原坏CFG实际产生的一条`Unexpected EOF while parsing simple tag.`诊断，真实返回`CFG_READBACK_LOAD/native_error=43`；其余18案原生错误0，Script／Parse错误全部拒绝。0／1／2为`settlement_authorized=false`的恢复组件；9／12使用已实际证明的写拒绝／读回变化机制，10／11／12同外码不同原因分别保留；14／15为编码前拒绝；18保持旧Campaign内存，Settings允许的独立写入另行核对。不把这些结果表述成自然终局或奖励仅一次。

[完整紧凑归档](../../evidence/persistence19_matrix_20261027_103731/README.md)为99文件／1,711,797字节，manifest SHA `b800d96a362e7547a7b345319b34ef35a548725bd3d96d160fc6e83da27437dc`。960pins由427外部／525内部／8个EXE仅元数据组成；953条来源映射对应359个原字节对象（265个固定aed8 Git blob、94份raw）。独立回读实际原件、Git blob和来源映射一致，不复制业务载荷或EXE。旧加载失败、9／12协议证明及其当时“矩阵未完成”记录保留历史语境，不追授旧源资格。
