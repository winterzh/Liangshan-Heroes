# 外部 v25 producer：已写 source，当前 BLOCKED

`run_daming_safe_retreat_v25.py` 是新 sibling，未作为CLI运行、未import r2执行、未调用Godot。采用 `runner_class(base)` 内的 `V25Runner(base.Runner)`，显式读取并核对原r2 SHA，再原路径import；因此旧r2的 `Path(__file__)` 仍指原admit提案目录，旧生产者/原harness都保持原位。只修改imported producer的两个候选集合，不改磁盘上的base或任何生产脚本。

已实现：六项ROOT候选逐SHA桥接（4替换+2添加）；完整5039→5041/5037、5100→5102和88metadata、原source/native/tool guard仍由原r2全量执行；原JSON11、OwnedSlot与admitABC；新v25两变体独立profile guard以及A→negative→B→C→D；严格实际PID/nonce/先辈终结时间、完整22section/packet/settings/options/Root/Mission时钟/绑定必需labels；实际磁盘slot envelope字段/UTF8 payloadbytes/hash/代链；实际local lifecycle1→2终结链及Campaign文件未新增/未改；所有新producer/base/module/scene/negative工具纳入pins。

两个negative native harness和其精确consumer API尚在开发，当前active `NEGATIVE_IMPLEMENTATION_MATRIX_V25.json`不存在。预检必须输出明确 `BLOCKED`，在import base、mkdir batch、cache复制、锁或Godot之前退出；不存在skip或空checks判通过。模板 `NEGATIVE_IMPLEMENTATION_MATRIX_TEMPLATE_V25.json` 是接口合同，不是active通过清单。

新报告API合同目前要求actual source/JSON rows及SHA、受控code、原typed输入不变、零world分配、全部必需labels和flags；若将来native GD使用不同字段，需要实现并独立审查精确adapter，再填 `consumer_schema=v25_producer_negative_descriptor_v1`。不能在虚构report里换字段凑pass。每variant的实际A report/handoff/rawslot/fullpacket/fullworld为5项阳性输入，每项路径/bytes/SHA都要回读；负例子profile不得改A证据。

当前明确未实现/未验证：两个actual native negative实现和report适配审查；active matrix；实际ROOT六项candidate receipt与正式apply；基础admit成功后继修正；native parse/import/全部实际用例。只有AST编译，不声明执行、资格或through。Campaign持久/Steam奖励/公开Continue/发布EXE始终false。未来flags正常私人profile的Campaign写盘验证另批执行。

该source当前需要静态跨审，不能直接起pipeline。静态审查收据记录编译结果、new/base SHA以及现有阻塞；若source再次修改，用新收据记录新SHA，旧收据保留。
