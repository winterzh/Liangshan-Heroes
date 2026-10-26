# Readset 原生组件完整切片（2026-10-27 04:50）

原批 20261027_045053_04fe0749 已终态 complete=true / slice_passed=true。producer 56416 在真实 pending_verified 断点按计划退出 1；reader 14108、clone 74016 均退出 0。三个宿主持有的子进程和全部 helper 均有终态，最终完整源码身份守卫通过且共享锁已释放。

正式检查数是 reader 最终 248 + clone 最终 37 = 285。12 个 case 文件的 checks 是累计快照，不能相加；producer prepared 的夹具检查独立列出，不计入 285。reader 有 9 个真实源码断点/故障记录；25 份实际原生 helper JSON 经原 profile IPC、运行目录副本和报告 SHA 三方比对。它们是固定结构的 PID/nonce/时钟/Win32 查询元数据，不含凭据或玩家数据。case 的拒绝和实际恢复分列在 verification.json。

ABA、内容/待提交文件/文件名/目录集合/owner 替换、真实超时、伪造 plan 与真实活 owner 均按具体拒绝边界验证；正常 record/pending 真实恢复、派生 Slot 和 CFG 旧语义也保留检查。UNKNOWN 未代替 dead 或成功。

旧 3,961,694 字节完整 Slot 的独立 clone 真实 inspect 用时 2,673,640 us，recover 总耗时 11,690,307 us。3000 ms 是原有 mutation 前 liveness scope 的预算，不是完整 recover 总 wall time 上限。claim 后完整链校验、prune 和最终读回仍在执行，不能写成“完整恢复三秒内”。原失败 profile 完整三文件/八目录未变；clone 只移除 writing/owner.json 和 writing 目录，旧 record 与 LC 的 SHA 保持。旧内容身份未改，这只证明 Store 恢复，不转授 Flow/世界挂载或菜单继续资格。

raw 保留实际运行的五份固定输入、三个 worker、宿主终态 receipt、controller、reader/clone 最终 report、12 case、gate/ACK、断点/故障原件、native.log，以及实际 provider JSON。runner_inputs 来自该批运行前冻结副本，包含所需源码和身份/导入元数据；其中 .godot 路径是选定的原始来源元数据与脚本，不是导入缓存。482 个 receipt pins 已逐个实读 SHA 验证，零差异；完整 7062 文件身份的运行时末尾守卫按原 receipt 保留，归档器未冒称重新遍历全部素材。

producer/prepared.json 内嵌合成 variants 的 raw/document，及五个 fixture_*.json，均未复制。producer_prepared_index.json 是明确标注的派生状态索引，原 SHA/绑定仍保留。旧来源 prepared 中的 typed exact_snapshot、私有 seed/业务树、EXE 同样只保留 SHA 与排除记录，不复制载荷。没有裁剪原件后冒称完整 raw；详见 omitted_files.json。

本包只授本候选原生 headless Store 定向切片资格；不代表完整 19 类/61 阶段、SDK、原版 EXE、OS 键鼠、人工体验、生产采用或发布。source_map.json 与 verification.json 提供逐文件来源、全部 pin 去向及未复制原因；manifest.json 覆盖本包除自身的所有文件。归档期间未启动引擎、修改源码或旧运行目录。
